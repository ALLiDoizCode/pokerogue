--[[
Unit Tests: Community Contribution Tracking
Tests contribution validation, aggregation, duplicate prevention, and participant tracking
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
  name = "Community Contribution Tracking Tests",
  tests = {}
}

-- Test: Track valid contribution
table.insert(testSuite.tests, {
  name = "should track valid contribution and update goal progress",
  fn = function()
    local event = {
      eventId = "test-event",
      name = "Test Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {
        {
          goalId = "test-event-goal-1",
          goalType = "CUMULATIVE_TOTAL",
          targetValue = 100000,
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
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "150",
      Timestamp = "1735000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(mockMsg)

    assert(capturedResponse ~= nil, "Response should be sent")
    assert(capturedResponse.Action == "SaveState", "Should return SaveState")
    assert(capturedResponse.Success == "true", "Should succeed")

    local responseData = json.decode(capturedResponse.Data)
    assert(responseData.result.newValue == 150, "Goal progress should be 150")
    assert(responseData.result.contributionValue == 150, "Contribution value should match")
    assert(responseData.result.isNewParticipant == true, "Should be new participant")

    local updatedGameState = json.decode(capturedResponse.GameState)
    assert(#updatedGameState.communityContributions == 1, "Should have 1 contribution")

    print("✓ Track valid contribution")
  end
})

-- Test: Reject contribution to inactive event
table.insert(testSuite.tests, {
  name = "should reject contribution to PENDING event",
  fn = function()
    local event = {
      eventId = "pending-event",
      name = "Pending Event",
      startDate = 1800000000000, -- Future
      endDate = 1900000000000,
      status = "PENDING",
      goals = {
        {goalId = "pending-event-goal-1", goalType = "CUMULATIVE_TOTAL", targetValue = 100000, currentValue = 0, milestones = {}}
      },
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {}
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "pending-event",
      GoalId = "pending-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "100",
      Timestamp = "1735000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "Error", "Should return error")
    assert(capturedResponse.Success == "false", "Should fail")
    assert(string.match(capturedResponse.Error, "not active"), "Error should mention event status")

    print("✓ Reject contribution to inactive event")
  end
})

-- Test: Duplicate contribution prevention (rate limiting)
table.insert(testSuite.tests, {
  name = "should reject duplicate contribution within rate limit window",
  fn = function()
    local event = {
      eventId = "test-event",
      name = "Test Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {
        {goalId = "test-event-goal-1", goalType = "CUMULATIVE_TOTAL", targetValue = 100000, currentValue = 100, milestones = {}}
      },
      participants = {totalCount = 1, uniquePlayers = {"player-1"}}
    }

    local existingContribution = {
      eventId = "test-event",
      goalId = "test-event-goal-1",
      playerId = "player-1",
      contributionValue = 100,
      timestamp = 1735000000000,
      validated = true
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {existingContribution}
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "50",
      Timestamp = "1735000030000", -- 30 seconds later (within 1 minute window)
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "Error", "Should return error")
    assert(string.match(capturedResponse.Error, "Duplicate"), "Error should mention duplicate")

    print("✓ Duplicate contribution prevention works")
  end
})

-- Test: Allow contribution after rate limit window
table.insert(testSuite.tests, {
  name = "should allow contribution after rate limit window expires",
  fn = function()
    local event = {
      eventId = "test-event",
      name = "Test Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {
        {goalId = "test-event-goal-1", goalType = "CUMULATIVE_TOTAL", targetValue = 100000, currentValue = 100, milestones = {}}
      },
      participants = {totalCount = 1, uniquePlayers = {"player-1"}}
    }

    local existingContribution = {
      eventId = "test-event",
      goalId = "test-event-goal-1",
      playerId = "player-1",
      contributionValue = 100,
      timestamp = 1735000000000,
      validated = true
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {existingContribution}
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "75",
      Timestamp = "1735000070000", -- 70 seconds later (after 1 minute window)
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "SaveState", "Should succeed after rate limit window")
    assert(capturedResponse.Success == "true", "Should succeed")

    local responseData = json.decode(capturedResponse.Data)
    assert(responseData.result.newValue == 175, "Progress should be 100 + 75")

    print("✓ Contribution allowed after rate limit window")
  end
})

-- Test: Track unique participants
table.insert(testSuite.tests, {
  name = "should track unique participants correctly",
  fn = function()
    local event = {
      eventId = "test-event",
      name = "Test Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {
        {goalId = "test-event-goal-1", goalType = "CUMULATIVE_TOTAL", targetValue = 100000, currentValue = 0, milestones = {}}
      },
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {}
    }

    -- First contribution from player-1
    local msg1 = {
      From = "test-sender",
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "100",
      Timestamp = "1735000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(msg1)

    local responseData1 = json.decode(capturedResponse.Data)
    assert(responseData1.result.isNewParticipant == true, "First contribution should be new participant")
    assert(responseData1.updatedEvent.participants.totalCount == 1, "Total count should be 1")

    -- Update game state with first contribution
    gameState = json.decode(capturedResponse.GameState)
    gameState.communityEvents[1] = responseData1.updatedEvent

    -- Second contribution from player-1 (after rate limit)
    local msg2 = {
      From = "test-sender",
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "50",
      Timestamp = "1735000070000",
      GameState = json.encode(gameState)
    }

    ao.send = function(msg) capturedResponse = msg end
    handler.handler(msg2)

    local responseData2 = json.decode(capturedResponse.Data)
    assert(responseData2.result.isNewParticipant == false, "Second contribution from same player should not be new")
    assert(responseData2.updatedEvent.participants.totalCount == 1, "Total count should still be 1")

    print("✓ Unique participant tracking works")
  end
})

-- Test: Milestone unlocking on contribution
table.insert(testSuite.tests, {
  name = "should unlock milestones when threshold reached",
  fn = function()
    local event = {
      eventId = "test-event",
      name = "Test Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {
        {
          goalId = "test-event-goal-1",
          goalType = "CUMULATIVE_TOTAL",
          targetValue = 100000,
          currentValue = 24900,
          milestones = {
            {threshold = 25000, rewards = {{type = "SHINY_CHARM", quantity = 1}}, unlocked = false},
            {threshold = 50000, rewards = {{type = "ABILITY_CHARM", quantity = 1}}, unlocked = false}
          }
        }
      },
      participants = {totalCount = 10, uniquePlayers = {}}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {}
    }

    local mockMsg = {
      From = "test-sender",
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-new",
      ContributionValue = "200", -- This pushes progress to 25100
      Timestamp = "1735000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(mockMsg)

    local responseData = json.decode(capturedResponse.Data)
    assert(#responseData.result.milestonesUnlocked == 1, "Should unlock 1 milestone")
    assert(responseData.result.milestonesUnlocked[1].threshold == 25000, "Should unlock 25000 milestone")

    print("✓ Milestone unlocking on contribution")
  end
})

-- Test: Invalid contribution value
table.insert(testSuite.tests, {
  name = "should reject invalid contribution values",
  fn = function()
    local event = {
      eventId = "test-event",
      name = "Test Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {
        {goalId = "test-event-goal-1", goalType = "CUMULATIVE_TOTAL", targetValue = 100000, currentValue = 0, milestones = {}}
      },
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local gameState = {
      communityEvents = {event},
      communityContributions = {}
    }

    -- Test negative value
    local mockMsg = {
      From = "test-sender",
      EventId = "test-event",
      GoalId = "test-event-goal-1",
      PlayerId = "player-1",
      ContributionValue = "-50",
      Timestamp = "1735000000000",
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["track-contribution"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "Error", "Should reject negative value")
    assert(string.match(capturedResponse.Error, "Valid ContributionValue"), "Error should mention invalid value")

    print("✓ Reject invalid contribution values")
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
