--[[
Community Event Engine - AO Process
ADP v1.0 Compliant

Purpose: Manages community event coordination, participation tracking, milestone detection, and reward distribution

Handlers:
- Info: Returns process metadata and ADP compliance information
- CreateCommunityEvent: Initialize new community event with goals and milestones
- GetCommunityEvent: Retrieve event details and current state
- GetActiveCommunityEvents: List all active events at timestamp
- TrackContribution: Record player contribution to community goal
- GetCommunityProgress: Retrieve current goal progress and milestones
- DistributeRewards: Allocate rewards based on participation tiers
- SyncCommunityEvent: Synchronize event state across participants

Message Schemas:
- All handlers accept Action tag and relevant parameters
- Responses use Action = "SaveState" for success, "Error" for failures
- All tag values must be strings (use tostring() for numbers/booleans)
- Complex data structures use Data field with JSON encoding

AO Compliance:
- Monolithic design with all logic embedded (no external require except json)
- Individual handlers per action (no multi-action handlers)
- Direct error handling (no unnecessary pcall usage)
- Uses msg.Timestamp for all timing
- Deterministic execution (seeded RNG for any randomness)
]]

local json = require("json")

-- ============================================================================
-- CONSTANTS AND ENUMS
-- ============================================================================

local EventStatus = {
  PENDING = "PENDING",
  ACTIVE = "ACTIVE",
  COMPLETED = "COMPLETED",
  EXPIRED = "EXPIRED"
}

local GoalType = {
  CUMULATIVE_TOTAL = "CUMULATIVE_TOTAL",
  UNIQUE_PARTICIPANTS = "UNIQUE_PARTICIPANTS",
  TIME_BASED = "TIME_BASED"
}

local RewardTier = {
  HIGH = "HIGH",     -- Top 10%
  MEDIUM = "MEDIUM", -- 11-50%
  LOW = "LOW"        -- 51-100%
}

-- Validation constants
local MAX_EVENT_ID_LENGTH = 100
local MAX_PLAYER_ID_LENGTH = 100
local MAX_EVENT_NAME_LENGTH = 200
local MIN_EVENT_DURATION = 3600000 -- 1 hour in milliseconds
local MAX_CONTRIBUTION_VALUE = 1000000

-- ============================================================================
-- IN-MEMORY STORAGE (Stateless - reconstructed from messages)
-- ============================================================================

-- Community events are stored client-side in GameState
-- This process is stateless and reconstructs state from incoming messages

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Generate unique event ID from name and timestamp
---@param name string Event name
---@param timestamp number Creation timestamp
---@return string eventId
local function generateEventId(name, timestamp)
  local cleanName = string.gsub(name, "[^%w%-]", "-")
  cleanName = string.lower(cleanName)
  return cleanName .. "-" .. tostring(timestamp)
end

--- Validate event ID format
---@param eventId string Event identifier
---@return boolean valid
local function isValidEventId(eventId)
  if not eventId or type(eventId) ~= "string" then
    return false
  end
  if #eventId == 0 or #eventId > MAX_EVENT_ID_LENGTH then
    return false
  end
  -- Only alphanumeric, hyphens, and underscores
  return string.match(eventId, "^[%w%-_]+$") ~= nil
end

--- Validate player ID format (wallet address)
---@param playerId string Player identifier
---@return boolean valid
local function isValidPlayerId(playerId)
  if not playerId or type(playerId) ~= "string" then
    return false
  end
  if #playerId == 0 or #playerId > MAX_PLAYER_ID_LENGTH then
    return false
  end
  return true
end

--- Validate timestamp value
---@param timestamp number Timestamp in milliseconds
---@return boolean valid
local function isValidTimestamp(timestamp)
  if not timestamp or type(timestamp) ~= "number" then
    return false
  end
  -- Reasonable range: after 2020-01-01 and before 2100-01-01
  return timestamp >= 1577836800000 and timestamp <= 4102444800000
end

--- Determine event status based on timestamps
---@param event table Community event
---@param currentTimestamp number Current timestamp
---@return string status EventStatus constant
local function determineEventStatus(event, currentTimestamp)
  if event.status == EventStatus.COMPLETED then
    return EventStatus.COMPLETED
  end

  if currentTimestamp < event.startDate then
    return EventStatus.PENDING
  elseif currentTimestamp >= event.endDate then
    -- Check if all goals completed
    local allGoalsCompleted = true
    for _, goal in ipairs(event.goals) do
      if goal.currentValue < goal.targetValue then
        allGoalsCompleted = false
        break
      end
    end

    if allGoalsCompleted then
      return EventStatus.COMPLETED
    else
      return EventStatus.EXPIRED
    end
  else
    return EventStatus.ACTIVE
  end
end

--- Find event by ID in event list
---@param events table List of community events
---@param eventId string Event identifier
---@return table|nil event Found event or nil
local function findEventById(events, eventId)
  for _, event in ipairs(events) do
    if event.eventId == eventId then
      return event
    end
  end
  return nil
end

--- Find goal by ID in event
---@param event table Community event
---@param goalId string Goal identifier
---@return table|nil goal Found goal or nil
local function findGoalById(event, goalId)
  for _, goal in ipairs(event.goals) do
    if goal.goalId == goalId then
      return goal
    end
  end
  return nil
end

--- Calculate progress percentage
---@param currentValue number Current progress value
---@param targetValue number Target goal value
---@return number percentage Progress percentage (0-100)
local function calculateProgressPercentage(currentValue, targetValue)
  if targetValue <= 0 then
    return 0
  end
  local percentage = (currentValue / targetValue) * 100
  return math.min(100, math.max(0, percentage))
end

--- Find next milestone for goal
---@param goal table Community goal
---@return table|nil nextMilestone Next unachieved milestone
local function findNextMilestone(goal)
  for _, milestone in ipairs(goal.milestones) do
    if not milestone.unlocked and goal.currentValue < milestone.threshold then
      return milestone
    end
  end
  return nil
end

--- Check if contribution value is within valid range
---@param value number Contribution value
---@return boolean valid
local function isValidContributionValue(value)
  return type(value) == "number" and value > 0 and value <= MAX_CONTRIBUTION_VALUE
end

--- Calculate reward tier based on contribution percentage
---@param contributionPercentile number Player's percentile rank (0-100)
---@return string tier RewardTier constant
local function calculateRewardTier(contributionPercentile)
  if contributionPercentile >= 90 then
    return RewardTier.HIGH
  elseif contributionPercentile >= 50 then
    return RewardTier.MEDIUM
  else
    return RewardTier.LOW
  end
end

--- Sort participants by contribution value (descending)
---@param participants table List of participant objects
---@return table sorted Sorted participant list
local function sortParticipantsByContribution(participants)
  local sorted = {}
  for _, participant in ipairs(participants) do
    table.insert(sorted, participant)
  end

  table.sort(sorted, function(a, b)
    return a.totalContribution > b.totalContribution
  end)

  return sorted
end

--- Check if player has already contributed to goal (duplicate prevention)
---@param contributions table List of contributions
---@param playerId string Player identifier
---@param goalId string Goal identifier
---@param timestamp number Contribution timestamp
---@param rateLimitWindow number Time window in ms for rate limiting (default: 60000)
---@return boolean isDuplicate
local function isDuplicateContribution(contributions, playerId, goalId, timestamp, rateLimitWindow)
  rateLimitWindow = rateLimitWindow or 60000 -- Default: 1 minute

  for _, contribution in ipairs(contributions) do
    if contribution.playerId == playerId and contribution.goalId == goalId then
      -- Check if within rate limit window
      if math.abs(timestamp - contribution.timestamp) < rateLimitWindow then
        return true
      end
    end
  end

  return false
end

-- ============================================================================
-- EVENT CREATION AND MANAGEMENT
-- ============================================================================

--- Create new community event from configuration
---@param config table Event configuration
---@param timestamp number Creation timestamp
---@return table|nil event Created event or nil if invalid
---@return string|nil error Error message if creation failed
local function createCommunityEvent(config, timestamp)
  -- Validate required fields
  if not config.name or type(config.name) ~= "string" or #config.name == 0 then
    return nil, "Event name is required"
  end

  if #config.name > MAX_EVENT_NAME_LENGTH then
    return nil, "Event name exceeds maximum length"
  end

  if not config.startDate or not isValidTimestamp(config.startDate) then
    return nil, "Valid startDate timestamp required"
  end

  if not config.endDate or not isValidTimestamp(config.endDate) then
    return nil, "Valid endDate timestamp required"
  end

  if config.endDate <= config.startDate then
    return nil, "endDate must be after startDate"
  end

  local duration = config.endDate - config.startDate
  if duration < MIN_EVENT_DURATION then
    return nil, "Event duration must be at least 1 hour"
  end

  if not config.goals or type(config.goals) ~= "table" or #config.goals == 0 then
    return nil, "At least one goal is required"
  end

  -- Generate event ID
  local eventId = generateEventId(config.name, timestamp)

  -- Initialize event structure
  local event = {
    eventId = eventId,
    name = config.name,
    description = config.description or "",
    startDate = config.startDate,
    endDate = config.endDate,
    status = EventStatus.PENDING,
    goals = {},
    participants = {
      totalCount = 0,
      uniquePlayers = {}
    }
  }

  -- Process goals
  for i, goalConfig in ipairs(config.goals) do
    local goalId = eventId .. "-goal-" .. tostring(i)

    -- Validate goal configuration
    if not goalConfig.goalType or not GoalType[goalConfig.goalType] then
      return nil, "Invalid goal type: " .. tostring(goalConfig.goalType)
    end

    if not goalConfig.targetValue or type(goalConfig.targetValue) ~= "number" or goalConfig.targetValue <= 0 then
      return nil, "Goal targetValue must be positive number"
    end

    local goal = {
      goalId = goalId,
      goalType = goalConfig.goalType,
      targetValue = goalConfig.targetValue,
      currentValue = 0,
      description = goalConfig.description or "",
      milestones = goalConfig.milestones or {}
    }

    -- Validate and sort milestones
    for _, milestone in ipairs(goal.milestones) do
      if not milestone.threshold or milestone.threshold <= 0 or milestone.threshold > goal.targetValue then
        return nil, "Invalid milestone threshold"
      end
      milestone.unlocked = false
    end

    table.sort(goal.milestones, function(a, b)
      return a.threshold < b.threshold
    end)

    table.insert(event.goals, goal)
  end

  return event, nil
end

--- Get active events at given timestamp
---@param events table List of all events
---@param timestamp number Current timestamp
---@return table activeEvents List of active events
local function getActiveEvents(events, timestamp)
  local active = {}

  for _, event in ipairs(events) do
    local status = determineEventStatus(event, timestamp)
    if status == EventStatus.ACTIVE then
      table.insert(active, event)
    end
  end

  return active
end

-- ============================================================================
-- CONTRIBUTION TRACKING
-- ============================================================================

--- Track player contribution to community goal
---@param event table Community event
---@param goalId string Goal identifier
---@param playerId string Player identifier
---@param contributionValue number Contribution amount
---@param timestamp number Contribution timestamp
---@param contributions table List of all contributions (for duplicate checking)
---@return table|nil result Updated goal state or nil
---@return string|nil error Error message if tracking failed
local function trackContribution(event, goalId, playerId, contributionValue, timestamp, contributions)
  -- Validate event is active
  local status = determineEventStatus(event, timestamp)
  if status ~= EventStatus.ACTIVE then
    return nil, "Event is not active (status: " .. status .. ")"
  end

  -- Find goal
  local goal = findGoalById(event, goalId)
  if not goal then
    return nil, "Goal not found: " .. goalId
  end

  -- Validate contribution value
  if not isValidContributionValue(contributionValue) then
    return nil, "Invalid contribution value"
  end

  -- Check for duplicate contribution (rate limiting)
  if isDuplicateContribution(contributions, playerId, goalId, timestamp, 60000) then
    return nil, "Duplicate contribution detected (rate limit: 1 minute)"
  end

  -- Update goal progress
  local previousValue = goal.currentValue
  goal.currentValue = goal.currentValue + contributionValue

  -- Check for milestone unlocks
  local milestonesUnlocked = {}
  for _, milestone in ipairs(goal.milestones) do
    if not milestone.unlocked and goal.currentValue >= milestone.threshold then
      milestone.unlocked = true
      table.insert(milestonesUnlocked, milestone)
    end
  end

  -- Track unique participant
  local isNewParticipant = true
  for _, existingPlayer in ipairs(event.participants.uniquePlayers) do
    if existingPlayer == playerId then
      isNewParticipant = false
      break
    end
  end

  if isNewParticipant then
    table.insert(event.participants.uniquePlayers, playerId)
    event.participants.totalCount = event.participants.totalCount + 1
  end

  -- Return result
  return {
    goalId = goalId,
    previousValue = previousValue,
    newValue = goal.currentValue,
    contributionValue = contributionValue,
    milestonesUnlocked = milestonesUnlocked,
    isNewParticipant = isNewParticipant
  }, nil
end

-- ============================================================================
-- PROGRESS AND MILESTONE TRACKING
-- ============================================================================

--- Get community progress for event
---@param event table Community event
---@param timestamp number Current timestamp
---@return table progress Progress information
local function getCommunityProgress(event, timestamp)
  local goalProgress = {}

  for _, goal in ipairs(event.goals) do
    local progressPercentage = calculateProgressPercentage(goal.currentValue, goal.targetValue)
    local nextMilestone = findNextMilestone(goal)

    local milestonesUnlocked = {}
    for _, milestone in ipairs(goal.milestones) do
      if milestone.unlocked then
        table.insert(milestonesUnlocked, {
          threshold = milestone.threshold,
          rewards = milestone.rewards,
          unlocked = true
        })
      end
    end

    table.insert(goalProgress, {
      goalId = goal.goalId,
      goalType = goal.goalType,
      description = goal.description,
      currentValue = goal.currentValue,
      targetValue = goal.targetValue,
      progressPercentage = progressPercentage,
      nextMilestone = nextMilestone and {
        threshold = nextMilestone.threshold,
        rewards = nextMilestone.rewards,
        remainingProgress = nextMilestone.threshold - goal.currentValue
      } or nil,
      milestonesUnlocked = milestonesUnlocked,
      isCompleted = goal.currentValue >= goal.targetValue
    })
  end

  local timeRemaining = math.max(0, event.endDate - timestamp)

  return {
    eventId = event.eventId,
    name = event.name,
    status = determineEventStatus(event, timestamp),
    goalProgress = goalProgress,
    participantCount = event.participants.totalCount,
    timeRemaining = timeRemaining,
    startDate = event.startDate,
    endDate = event.endDate
  }
end

-- ============================================================================
-- REWARD DISTRIBUTION
-- ============================================================================

--- Calculate reward distribution for all participants
---@param event table Community event
---@param participantContributions table Map of playerId -> total contribution
---@return table distribution Reward distribution results
---@return string|nil error Error message if distribution failed
local function distributeRewards(event, participantContributions)
  -- Validate event is completed or expired
  if event.status ~= EventStatus.COMPLETED and event.status ~= EventStatus.EXPIRED then
    return nil, "Event must be completed or expired for reward distribution"
  end

  -- Build participant list
  local participants = {}
  for playerId, contribution in pairs(participantContributions) do
    table.insert(participants, {
      playerId = playerId,
      totalContribution = contribution,
      percentile = 0,
      tier = RewardTier.LOW,
      rewardsEarned = {},
      claimed = false
    })
  end

  -- Sort by contribution (descending)
  local sortedParticipants = sortParticipantsByContribution(participants)

  -- Calculate percentiles and assign tiers
  local totalParticipants = #sortedParticipants
  for i, participant in ipairs(sortedParticipants) do
    -- Percentile: percentage of participants with lower contribution
    participant.percentile = ((totalParticipants - i) / totalParticipants) * 100
    participant.tier = calculateRewardTier(participant.percentile)

    -- Assign rewards based on tier and unlocked milestones
    for _, goal in ipairs(event.goals) do
      for _, milestone in ipairs(goal.milestones) do
        if milestone.unlocked then
          -- Determine reward quantity based on tier
          local rewardMultiplier = 1.0
          if participant.tier == RewardTier.HIGH then
            rewardMultiplier = 2.0
          elseif participant.tier == RewardTier.MEDIUM then
            rewardMultiplier = 1.5
          end

          for _, reward in ipairs(milestone.rewards or {}) do
            table.insert(participant.rewardsEarned, {
              type = reward.type,
              quantity = math.floor(reward.quantity * rewardMultiplier),
              source = "milestone-" .. tostring(milestone.threshold)
            })
          end
        end
      end
    end
  end

  return {
    eventId = event.eventId,
    participants = sortedParticipants,
    distributionFairness = {
      highTier = 0.10,
      mediumTier = 0.40,
      lowTier = 0.50
    },
    totalParticipants = totalParticipants
  }, nil
end

-- ============================================================================
-- AO MESSAGE HANDLERS
-- ============================================================================

--- Info Handler - ADP v1.0 Compliance
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        process = {
          name = "Community Event Engine",
          version = "1.0.0",
          adpVersion = "1.0",
          processId = ao.id,
          capabilities = {
            "CreateCommunityEvent",
            "GetCommunityEvent",
            "GetActiveCommunityEvents",
            "TrackContribution",
            "GetCommunityProgress",
            "DistributeRewards",
            "SyncCommunityEvent"
          },
          messageSchemas = {
            CreateCommunityEvent = {
              required = {"Action", "EventConfig"},
              optional = {"Timestamp"}
            },
            GetCommunityEvent = {
              required = {"Action", "EventId", "GameState"},
              optional = {"Timestamp"}
            },
            GetActiveCommunityEvents = {
              required = {"Action", "GameState", "Timestamp"}
            },
            TrackContribution = {
              required = {"Action", "EventId", "GoalId", "PlayerId", "ContributionValue", "GameState", "Timestamp"}
            },
            GetCommunityProgress = {
              required = {"Action", "EventId", "GameState", "Timestamp"}
            },
            DistributeRewards = {
              required = {"Action", "EventId", "GameState", "Timestamp"}
            },
            SyncCommunityEvent = {
              required = {"Action", "EventId", "GameState"}
            }
          }
        },
        handlers = {
          "Info",
          "CreateCommunityEvent",
          "GetCommunityEvent",
          "GetActiveCommunityEvents",
          "TrackContribution",
          "GetCommunityProgress",
          "DistributeRewards",
          "SyncCommunityEvent"
        },
        documentation = {
          adpCompliance = "v1.0",
          selfDocumenting = true,
          description = "Manages community event coordination, participation tracking, milestone detection, and reward distribution"
        }
      }),
      Success = "true"
    })
  end
)

--- CreateCommunityEvent Handler
Handlers.add("create-community-event",
  Handlers.utils.hasMatchingTag("Action", "CreateCommunityEvent"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp) or 0

    if not isValidTimestamp(timestamp) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Timestamp required",
        Success = "false"
      })
      return
    end

    if not msg.EventConfig then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "EventConfig required",
        Success = "false"
      })
      return
    end

    local eventConfig = json.decode(msg.EventConfig or "{}")
    local event, error = createCommunityEvent(eventConfig, timestamp)

    if error then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = error,
        Success = "false"
      })
      return
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        event = event,
        message = "Community event created successfully"
      }),
      EventId = event.eventId,
      Success = "true"
    })
  end
)

--- GetCommunityEvent Handler
Handlers.add("get-community-event",
  Handlers.utils.hasMatchingTag("Action", "GetCommunityEvent"),
  function(msg)
    local eventId = msg.EventId

    if not isValidEventId(eventId) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid EventId required",
        Success = "false"
      })
      return
    end

    if not msg.GameState then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GameState required",
        Success = "false"
      })
      return
    end

    local gameState = json.decode(msg.GameState or "{}")
    local events = gameState.communityEvents or {}

    local event = findEventById(events, eventId)

    if not event then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Event not found: " .. eventId,
        Success = "false"
      })
      return
    end

    local timestamp = tonumber(msg.Timestamp) or 0
    local status = determineEventStatus(event, timestamp)
    event.status = status

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        event = event
      }),
      EventId = eventId,
      Success = "true"
    })
  end
)

--- GetActiveCommunityEvents Handler
Handlers.add("get-active-community-events",
  Handlers.utils.hasMatchingTag("Action", "GetActiveCommunityEvents"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp) or 0

    if not isValidTimestamp(timestamp) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Timestamp required",
        Success = "false"
      })
      return
    end

    if not msg.GameState then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GameState required",
        Success = "false"
      })
      return
    end

    local gameState = json.decode(msg.GameState or "{}")
    local events = gameState.communityEvents or {}

    local activeEvents = getActiveEvents(events, timestamp)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        activeEvents = activeEvents,
        count = #activeEvents,
        timestamp = timestamp
      }),
      Success = "true"
    })
  end
)

--- TrackContribution Handler
Handlers.add("track-contribution",
  Handlers.utils.hasMatchingTag("Action", "TrackContribution"),
  function(msg)
    local eventId = msg.EventId
    local goalId = msg.GoalId
    local playerId = msg.PlayerId
    local contributionValue = tonumber(msg.ContributionValue)
    local timestamp = tonumber(msg.Timestamp) or 0

    -- Validate inputs
    if not isValidEventId(eventId) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid EventId required",
        Success = "false"
      })
      return
    end

    if not goalId or #goalId == 0 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GoalId required",
        Success = "false"
      })
      return
    end

    if not isValidPlayerId(playerId) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid PlayerId required",
        Success = "false"
      })
      return
    end

    if not isValidContributionValue(contributionValue) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid ContributionValue required (positive number <= 1000000)",
        Success = "false"
      })
      return
    end

    if not isValidTimestamp(timestamp) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Timestamp required",
        Success = "false"
      })
      return
    end

    if not msg.GameState then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GameState required",
        Success = "false"
      })
      return
    end

    local gameState = json.decode(msg.GameState or "{}")
    local events = gameState.communityEvents or {}
    local contributions = gameState.communityContributions or {}

    local event = findEventById(events, eventId)

    if not event then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Event not found: " .. eventId,
        Success = "false"
      })
      return
    end

    local result, error = trackContribution(event, goalId, playerId, contributionValue, timestamp, contributions)

    if error then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = error,
        Success = "false"
      })
      return
    end

    -- Add contribution record
    table.insert(contributions, {
      eventId = eventId,
      goalId = goalId,
      playerId = playerId,
      contributionValue = contributionValue,
      timestamp = timestamp,
      validated = true
    })

    -- Update game state
    gameState.communityContributions = contributions

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        result = result,
        updatedEvent = event,
        message = "Contribution tracked successfully"
      }),
      GameState = json.encode(gameState),
      EventId = eventId,
      Success = "true"
    })
  end
)

--- GetCommunityProgress Handler
Handlers.add("get-community-progress",
  Handlers.utils.hasMatchingTag("Action", "GetCommunityProgress"),
  function(msg)
    local eventId = msg.EventId
    local timestamp = tonumber(msg.Timestamp) or 0

    if not isValidEventId(eventId) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid EventId required",
        Success = "false"
      })
      return
    end

    if not isValidTimestamp(timestamp) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Timestamp required",
        Success = "false"
      })
      return
    end

    if not msg.GameState then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GameState required",
        Success = "false"
      })
      return
    end

    local gameState = json.decode(msg.GameState or "{}")
    local events = gameState.communityEvents or {}

    local event = findEventById(events, eventId)

    if not event then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Event not found: " .. eventId,
        Success = "false"
      })
      return
    end

    local progress = getCommunityProgress(event, timestamp)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode(progress),
      EventId = eventId,
      Success = "true"
    })
  end
)

--- DistributeRewards Handler
Handlers.add("distribute-rewards",
  Handlers.utils.hasMatchingTag("Action", "DistributeRewards"),
  function(msg)
    local eventId = msg.EventId
    local timestamp = tonumber(msg.Timestamp) or 0

    if not isValidEventId(eventId) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid EventId required",
        Success = "false"
      })
      return
    end

    if not isValidTimestamp(timestamp) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Timestamp required",
        Success = "false"
      })
      return
    end

    if not msg.GameState then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GameState required",
        Success = "false"
      })
      return
    end

    local gameState = json.decode(msg.GameState or "{}")
    local events = gameState.communityEvents or {}
    local contributions = gameState.communityContributions or {}

    local event = findEventById(events, eventId)

    if not event then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Event not found: " .. eventId,
        Success = "false"
      })
      return
    end

    -- Update event status
    event.status = determineEventStatus(event, timestamp)

    -- Aggregate contributions by player
    local participantContributions = {}
    for _, contribution in ipairs(contributions) do
      if contribution.eventId == eventId then
        participantContributions[contribution.playerId] = (participantContributions[contribution.playerId] or 0) + contribution.contributionValue
      end
    end

    local distribution, error = distributeRewards(event, participantContributions)

    if error then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = error,
        Success = "false"
      })
      return
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode(distribution),
      EventId = eventId,
      Success = "true"
    })
  end
)

--- SyncCommunityEvent Handler
Handlers.add("sync-community-event",
  Handlers.utils.hasMatchingTag("Action", "SyncCommunityEvent"),
  function(msg)
    local eventId = msg.EventId

    if not isValidEventId(eventId) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid EventId required",
        Success = "false"
      })
      return
    end

    if not msg.GameState then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GameState required",
        Success = "false"
      })
      return
    end

    local gameState = json.decode(msg.GameState or "{}")
    local events = gameState.communityEvents or {}

    local event = findEventById(events, eventId)

    if not event then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Event not found: " .. eventId,
        Success = "false"
      })
      return
    end

    -- In stateless design, synchronization is client-driven
    -- This handler validates and returns the current event state
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        syncedEvent = event,
        conflictsResolved = 0,
        message = "Event state synchronized"
      }),
      EventId = eventId,
      Success = "true"
    })
  end
)

print("Community Event Engine initialized - ADP v1.0 compliant")
