--[[
Unit Tests: Community Reward Distribution
Tests reward tier calculation, fairness allocation, and distribution logic
]]

local json = require("json")

-- Mock AO environment
if not ao then
  ao = {
    send = function(msg) end,
    id = "test_process_id"
  }
end

if not Handlers then
  Handlers = {
    _handlers = {},
    utils = {
      hasMatchingTag = function(tag, value)
        return function(msg)
          return msg[tag] == value
        end
      end
    },
    add = function(name, matcher, handler)
      Handlers._handlers[name] = {matcher = matcher, handler = handler}
    end
  }
end

-- Load the community event engine process
dofile("processes/community-event-engine.lua")

local testSuite = {
  name = "Community Reward Distribution Tests",
  tests = {}
}

-- Test: Distribute rewards with tier-based allocation
table.insert(testSuite.tests, {
  name = "should distribute rewards with correct tier allocations",
  fn = function()
    local event = {
      eventId = "completed-event",
      name = "Completed Event",
      startDate = 1000000000000,
      endDate = 1100000000000,
      status = "COMPLETED",
      goals = {
        {
          goalId = "completed-event-goal-1",
          goalType = "CUMULATIVE_TOTAL",
          targetValue = 10000,
          currentValue = 10000,
          milestones = {
            {
              threshold = 5000,
              rewards = {{type = "SHINY_CHARM", quantity = 1}},
              unlocked = true
            },
            {
              threshold = 10000,
              rewards = {{type = "MASTER_BALL", quantity = 1}},
              unlocked = true
            }
          }
        }
      },
      participants = {totalCount = 10, uniquePlayers = {}}
    }

    local contributions = {
      {eventId = "completed-event", playerId = "player-1", contributionValue = 3000},
      {eventId = "completed-event", playerId = "player-2", contributionValue = 2500},
      {eventId = "completed-event", playerId = "player-3", contributionValue = 2000},
      {eventId = "completed-event", playerId = "player-4", contributionValue = 1000},
      {eventId = "completed-event", playerId = "player-5", contributionValue = 800},
      {eventId = "completed-event", playerId = "player-6", contributionValue = 300},
      {eventId = "completed-event", playerId = "player-7", contributionValue = 200},
      {eventId = "completed-event", playerId = "player-8", contributionValue = 100},
      {eventId = "completed-event", playerId = "player-9", contributionValue = 50},
      {eventId = "completed-event", playerId = "player-10", contributionValue = 50}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = contributions
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "completed-event",
      Timestamp = "1200000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["distribute-rewards"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "SaveState", "Should return SaveState")
    assert(capturedResponse.Success == "true", "Should succeed")

    local responseData = json.decode(capturedResponse.Data)
    assert(responseData.totalParticipants == 10, "Should have 10 participants")

    -- Check tier assignments
    local highTier = 0
    local mediumTier = 0
    local lowTier = 0

    for _, participant in ipairs(responseData.participants) do
      if participant.tier == "HIGH" then
        highTier = highTier + 1
      elseif participant.tier == "MEDIUM" then
        mediumTier = mediumTier + 1
      elseif participant.tier == "LOW" then
        lowTier = lowTier + 1
      end
    end

    -- With 10 participants: HIGH = top 10% (1 player), MEDIUM = 11-50% (4 players), LOW = 51-100% (5 players)
    assert(highTier == 1, "Should have 1 HIGH tier participant (top 10%)")
    assert(mediumTier >= 4, "Should have at least 4 MEDIUM tier participants")

    print("✓ Reward distribution with tier allocation")
  end
})

-- Test: Reward multiplier based on tier
table.insert(testSuite.tests, {
  name = "should apply reward multiplier based on tier (HIGH=2x, MEDIUM=1.5x, LOW=1x)",
  fn = function()
    local event = {
      eventId = "completed-event",
      name = "Completed Event",
      startDate = 1000000000000,
      endDate = 1100000000000,
      status = "COMPLETED",
      goals = {
        {
          goalId = "completed-event-goal-1",
          goalType = "CUMULATIVE_TOTAL",
          targetValue = 1000,
          currentValue = 1000,
          milestones = {
            {
              threshold = 1000,
              rewards = {{type = "SHINY_CHARM", quantity = 10}},
              unlocked = true
            }
          }
        }
      },
      participants = {totalCount = 3, uniquePlayers = {}}
    }

    local contributions = {
      {eventId = "completed-event", playerId = "top-player", contributionValue = 600},
      {eventId = "completed-event", playerId = "mid-player", contributionValue = 300},
      {eventId = "completed-event", playerId = "low-player", contributionValue = 100}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = contributions
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "completed-event",
      Timestamp = "1200000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["distribute-rewards"]
    handler.handler(mockMsg)

    local responseData = json.decode(capturedResponse.Data)

    -- Find participants by ID
    local topPlayer = nil
    local midPlayer = nil
    local lowPlayer = nil

    for _, p in ipairs(responseData.participants) do
      if p.playerId == "top-player" then topPlayer = p end
      if p.playerId == "mid-player" then midPlayer = p end
      if p.playerId == "low-player" then lowPlayer = p end
    end

    assert(topPlayer ~= nil, "Top player should exist")
    assert(midPlayer ~= nil, "Mid player should exist")
    assert(lowPlayer ~= nil, "Low player should exist")

    -- Check reward quantities based on tier multipliers
    -- Base reward: 10 SHINY_CHARM
    -- HIGH tier (top 10%+): 2x = 20
    -- MEDIUM tier (11-50%): 1.5x = 15
    -- LOW tier (51-100%): 1x = 10

    local topReward = topPlayer.rewardsEarned[1].quantity
    local midReward = midPlayer.rewardsEarned[1].quantity
    local lowReward = lowPlayer.rewardsEarned[1].quantity

    assert(topReward == 20, "Top player should receive 2x multiplier (20)")
    assert(midReward == 15, "Mid player should receive 1.5x multiplier (15)")
    assert(lowReward == 10, "Low player should receive 1x multiplier (10)")

    print("✓ Reward multiplier based on tier")
  end
})

-- Test: Reject distribution for non-completed events
table.insert(testSuite.tests, {
  name = "should reject reward distribution for active events",
  fn = function()
    local event = {
      eventId = "active-event",
      name = "Active Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {},
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {}
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "active-event",
      Timestamp = "1735000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["distribute-rewards"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "Error", "Should return error")
    assert(string.match(capturedResponse.Error, "completed or expired"), "Error should mention event status")

    print("✓ Reject distribution for active events")
  end
})

-- Test: Handle zero participants
table.insert(testSuite.tests, {
  name = "should handle event with zero participants",
  fn = function()
    local event = {
      eventId = "empty-event",
      name = "Empty Event",
      startDate = 1000000000000,
      endDate = 1100000000000,
      status = "EXPIRED",
      goals = {
        {
          goalId = "empty-event-goal-1",
          goalType = "CUMULATIVE_TOTAL",
          targetValue = 10000,
          currentValue = 0,
          milestones = {}
        }
      },
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {}
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "empty-event",
      Timestamp = "1200000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["distribute-rewards"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "SaveState", "Should succeed with empty list")

    local responseData = json.decode(capturedResponse.Data)
    assert(responseData.totalParticipants == 0, "Should have 0 participants")
    assert(#responseData.participants == 0, "Participants list should be empty")

    print("✓ Handle zero participants")
  end
})

-- Test: Percentile calculation accuracy
table.insert(testSuite.tests, {
  name = "should calculate percentiles correctly for sorted participants",
  fn = function()
    local event = {
      eventId = "percentile-event",
      name = "Percentile Test",
      startDate = 1000000000000,
      endDate = 1100000000000,
      status = "COMPLETED",
      goals = {
        {
          goalId = "percentile-event-goal-1",
          goalType = "CUMULATIVE_TOTAL",
          targetValue = 1000,
          currentValue = 1000,
          milestones = {
            {threshold = 1000, rewards = {{type = "TEST_REWARD", quantity = 1}}, unlocked = true}
          }
        }
      },
      participants = {totalCount = 10, uniquePlayers = {}}
    }

    -- 10 participants with different contributions
    local contributions = {}
    for i = 1, 10 do
      table.insert(contributions, {
        eventId = "percentile-event",
        playerId = "player-" .. i,
        contributionValue = (11 - i) * 100 -- Descending: 1000, 900, 800, ...
      })
    end

    local gameState = {
      communityEvents = {event},
      communityContributions = contributions
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "percentile-event",
      Timestamp = "1200000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["distribute-rewards"]
    handler.handler(mockMsg)

    local responseData = json.decode(capturedResponse.Data)

    -- First participant should have highest percentile (90th)
    assert(responseData.participants[1].percentile >= 90, "Top contributor should be in 90+ percentile")

    -- Last participant should have lowest percentile (0th)
    assert(responseData.participants[10].percentile == 0, "Last contributor should be in 0 percentile")

    print("✓ Percentile calculation accuracy")
  end
})

-- Run all tests
local function runTests()
  print("\n=== " .. testSuite.name .. " ===\n")

  local passed = 0
  local failed = 0

  for _, test in ipairs(testSuite.tests) do
    local success, error = pcall(test.fn)
    if success then
      passed = passed + 1
    else
      failed = failed + 1
      print("✗ " .. test.name)
      print("  Error: " .. tostring(error))
    end
  end

  print("\n=== Results ===")
  print("Passed: " .. passed)
  print("Failed: " .. failed)
  print("Total: " .. (passed + failed))

  return failed == 0
end

local success = runTests()
os.exit(success and 0 or 1)
