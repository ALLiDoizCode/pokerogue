--[[
Unit Tests: Community Event Creation and Management
Tests event creation, validation, status transitions, and lifecycle management
]]

local json = require("json")

-- Mock AO environment
if not ao then
  ao = {
    send = function(msg)
      print("Mock ao.send:", json.encode(msg))
    end,
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

-- Test suite
local testSuite = {
  name = "Community Event Creation Tests",
  tests = {}
}

-- Test: Create valid community event
table.insert(testSuite.tests, {
  name = "should create valid community event with all required fields",
  fn = function()
    local mockMsg = {
      From = "test-sender",
      Timestamp = "1734739200000",
      EventConfig = json.encode({
        name = "Winter Community Challenge",
        description = "Collective Ice-type catch goal",
        startDate = 1734739200000,
        endDate = 1735948800000,
        goals = {
          {
            goalType = "CUMULATIVE_TOTAL",
            targetValue = 100000,
            description = "Catch Ice-type Pokemon",
            milestones = {
              {threshold = 25000, rewards = {{type = "SHINY_CHARM", quantity = 1}}},
              {threshold = 50000, rewards = {{type = "ABILITY_CHARM", quantity = 1}}}
            }
          }
        }
      })
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["create-community-event"]
    handler.handler(mockMsg)

    assert(capturedResponse ~= nil, "Response should be sent")
    assert(capturedResponse.Action == "SaveState", "Action should be SaveState")
    assert(capturedResponse.Success == "true", "Success should be true")

    local responseData = json.decode(capturedResponse.Data)
    assert(responseData.event ~= nil, "Event should be returned")
    assert(responseData.event.eventId ~= nil, "Event ID should be generated")
    assert(responseData.event.name == "Winter Community Challenge", "Event name should match")
    assert(responseData.event.status == "PENDING", "New event should be PENDING")
    assert(#responseData.event.goals == 1, "Event should have one goal")
    assert(responseData.event.goals[1].currentValue == 0, "Initial progress should be 0")

    print("✓ Create valid community event")
  end
})

-- Test: Reject event with missing required fields
table.insert(testSuite.tests, {
  name = "should reject event creation with missing name",
  fn = function()
    local mockMsg = {
      From = "test-sender",
      Timestamp = "1734739200000",
      EventConfig = json.encode({
        description = "Test event",
        startDate = 1734739200000,
        endDate = 1735948800000,
        goals = {{goalType = "CUMULATIVE_TOTAL", targetValue = 100000}}
      })
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["create-community-event"]
    handler.handler(mockMsg)

    assert(capturedResponse ~= nil, "Error response should be sent")
    assert(capturedResponse.Action == "Error", "Action should be Error")
    assert(capturedResponse.Success == "false", "Success should be false")
    assert(string.match(capturedResponse.Error, "name"), "Error should mention name")

    print("✓ Reject event with missing name")
  end
})

-- Test: Reject event with invalid date range
table.insert(testSuite.tests, {
  name = "should reject event with endDate before startDate",
  fn = function()
    local mockMsg = {
      From = "test-sender",
      Timestamp = "1734739200000",
      EventConfig = json.encode({
        name = "Invalid Event",
        startDate = 1735948800000,
        endDate = 1734739200000, -- Before startDate
        goals = {{goalType = "CUMULATIVE_TOTAL", targetValue = 100000}}
      })
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["create-community-event"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "Error", "Should return error")
    assert(string.match(capturedResponse.Error, "endDate"), "Error should mention endDate")

    print("✓ Reject event with invalid date range")
  end
})

-- Test: Event status transitions based on timestamp
table.insert(testSuite.tests, {
  name = "should transition event status from PENDING to ACTIVE to EXPIRED",
  fn = function()
    -- Create event
    local createMsg = {
      From = "test-sender",
      Timestamp = "1734739000000", -- Before startDate
      EventConfig = json.encode({
        name = "Status Test Event",
        startDate = 1734739200000,
        endDate = 1735948800000,
        goals = {{goalType = "CUMULATIVE_TOTAL", targetValue = 100000}}
      })
    }

    local capturedCreate = nil
    ao.send = function(msg) capturedCreate = msg end

    local createHandler = Handlers._handlers["create-community-event"]
    createHandler.handler(createMsg)

    local createData = json.decode(capturedCreate.Data)
    local eventId = createData.event.eventId

    -- Check PENDING status
    assert(createData.event.status == "PENDING", "Event should start as PENDING")

    -- Check ACTIVE status (during event)
    local gameState = {communityEvents = {createData.event}}
    local activeMsg = {
      From = "test-sender",
      EventId = eventId,
      Timestamp = "1735000000000", -- During event
      GameState = json.encode(gameState)
    }

    local capturedActive = nil
    ao.send = function(msg) capturedActive = msg end

    local getHandler = Handlers._handlers["get-community-event"]
    getHandler.handler(activeMsg)

    local activeData = json.decode(capturedActive.Data)
    assert(activeData.event.status == "ACTIVE", "Event should be ACTIVE during event period")

    -- Check EXPIRED status (after event)
    local expiredMsg = {
      From = "test-sender",
      EventId = eventId,
      Timestamp = "1736000000000", -- After endDate
      GameState = json.encode(gameState)
    }

    local capturedExpired = nil
    ao.send = function(msg) capturedExpired = msg end

    getHandler.handler(expiredMsg)

    local expiredData = json.decode(capturedExpired.Data)
    assert(expiredData.event.status == "EXPIRED", "Event should be EXPIRED after endDate")

    print("✓ Event status transitions work correctly")
  end
})

-- Test: Get active events at timestamp
table.insert(testSuite.tests, {
  name = "should return only active events at given timestamp",
  fn = function()
    -- Create multiple events
    local event1 = {
      eventId = "event-1",
      name = "Past Event",
      startDate = 1000000000000,
      endDate = 1100000000000,
      status = "EXPIRED",
      goals = {},
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local event2 = {
      eventId = "event-2",
      name = "Active Event",
      startDate = 1734739200000,
      endDate = 1735948800000,
      status = "ACTIVE",
      goals = {},
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local event3 = {
      eventId = "event-3",
      name = "Future Event",
      startDate = 1800000000000,
      endDate = 1900000000000,
      status = "PENDING",
      goals = {},
      participants = {totalCount = 0, uniquePlayers = {}}
    }

    local gameState = {communityEvents = {event1, event2, event3}}

    local mockMsg = {
      From = "test-sender",
      Timestamp = "1735000000000", -- During event2
      GameState = json.encode(gameState)
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["get-active-community-events"]
    handler.handler(mockMsg)

    assert(capturedResponse.Action == "SaveState", "Should return success")

    local responseData = json.decode(capturedResponse.Data)
    assert(responseData.count == 1, "Should return 1 active event")
    assert(responseData.activeEvents[1].eventId == "event-2", "Should return event-2")

    print("✓ Get active events filters correctly")
  end
})

-- Test: Milestone sorting
table.insert(testSuite.tests, {
  name = "should sort milestones by threshold ascending",
  fn = function()
    local mockMsg = {
      From = "test-sender",
      Timestamp = "1734739200000",
      EventConfig = json.encode({
        name = "Milestone Sort Test",
        startDate = 1734739200000,
        endDate = 1735948800000,
        goals = {
          {
            goalType = "CUMULATIVE_TOTAL",
            targetValue = 100000,
            milestones = {
              {threshold = 75000, rewards = {{type = "REWARD_3", quantity = 1}}},
              {threshold = 25000, rewards = {{type = "REWARD_1", quantity = 1}}},
              {threshold = 50000, rewards = {{type = "REWARD_2", quantity = 1}}}
            }
          }
        }
      })
    }

    local capturedResponse = nil
    ao.send = function(msg) capturedResponse = msg end

    local handler = Handlers._handlers["create-community-event"]
    handler.handler(mockMsg)

    local responseData = json.decode(capturedResponse.Data)
    local milestones = responseData.event.goals[1].milestones

    assert(milestones[1].threshold == 25000, "First milestone should be 25000")
    assert(milestones[2].threshold == 50000, "Second milestone should be 50000")
    assert(milestones[3].threshold == 75000, "Third milestone should be 75000")

    print("✓ Milestones sorted correctly")
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

-- Execute tests
local success = runTests()
os.exit(success and 0 or 1)
