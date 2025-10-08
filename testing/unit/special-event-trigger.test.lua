-- Unit Tests for Special Event Engine - Event Trigger Logic
-- Tests event activation logic with boundary conditions

-- Use mock aolite for unit testing
package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")
local json = require("json")

-- Test state
local processId = nil
local testMessages = {}
local assertionCount = 0
local failedAssertions = 0

-- Helper to send message and capture response
local function sendMessage(action, tags, data)
    local msg = {
        Action = action,
        From = "test_sender",
        Target = processId,
        Timestamp = os.time() * 1000
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    if data then
        msg.Data = type(data) == "table" and json.encode(data) or data
    end

    local result = aolite.send(msg)
    table.insert(testMessages, result)
    return result
end

-- Helper: Assert equals
local function assertEquals(actual, expected, message)
    assertionCount = assertionCount + 1
    if actual ~= expected then
        failedAssertions = failedAssertions + 1
        print("  ✗ FAIL: " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual: " .. tostring(actual))
        return false
    else
        print("  ✓ PASS: " .. message)
        return true
    end
end

-- Helper: Assert true
local function assertTrue(condition, message)
    assertionCount = assertionCount + 1
    if not condition then
        failedAssertions = failedAssertions + 1
        print("  ✗ FAIL: " .. message)
        print("    Expected: true")
        print("    Actual: false")
        return false
    else
        print("  ✓ PASS: " .. message)
        return true
    end
end

-- Setup: Load process
print("Setting up Special Event Engine tests...")
processId = aolite.spawnProcess("special-event-engine", "./processes/special-event-engine.lua")

if not processId then
    error("Failed to spawn special-event-engine process")
end

print("Process spawned with ID: " .. processId)

-- ============================================================================
-- TEST SUITE 1: Event Activation During Active Period
-- ============================================================================

print("\n=== TEST SUITE 1: Event Activation During Active Period ===")

local function testActiveEventDetection()
    print("Test 1.1: Winter Holiday Update active during event period")
    -- Winter Holiday Update: 2024-12-21 to 2025-01-04
    -- Test time: 2024-12-25 (during event)
    local testTime = 1735084800000 -- 2024-12-25T00:00:00Z

    local result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "true", "IsActive should be true")
    assertEquals(result.EventName, "Winter Holiday Update", "EventName should be Winter Holiday Update")

    print("Test 1.2: Year of the Snake active during event period")
    -- Year of the Snake: 2025-01-29 to 2025-02-03
    -- Test time: 2025-02-01 (during event)
    testTime = 1738368000000 -- 2025-02-01T00:00:00Z

    result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "true", "IsActive should be true")
    assertEquals(result.EventName, "Year of the Snake", "EventName should be Year of the Snake")

    print("Test 1.3: GetActiveEvent returns full event details")
    -- Valentine event: 2025-02-10 to 2025-02-21
    -- Test time: 2025-02-15 (during event)
    testTime = 1739664000000 -- 2025-02-15T00:00:00Z

    result = sendMessage("GetActiveEvent", {CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.HasActiveEvent, "true", "HasActiveEvent should be true")

    local eventData = json.decode(result.Data)
    assertEquals(eventData.name, "Valentine", "Event name should be Valentine")
    assertEquals(eventData.eventType, "SHINY", "Event type should be SHINY")
    assertEquals(tostring(eventData.shinyMultiplier), "2", "Shiny multiplier should be 2")
    assertTrue(eventData.boostFusions, "boostFusions should be true")

    print("Test 1.4: April Fools event with LUCK type")
    -- April Fools 2025: 2025-03-31 to 2025-04-03
    -- Test time: 2025-04-01 (during event)
    testTime = 1743552000000 -- 2025-04-01T00:00:00Z

    result = sendMessage("GetActiveEvent", {CurrentTime = tostring(testTime)})
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.HasActiveEvent, "true", "HasActiveEvent should be true")

    eventData = json.decode(result.Data)
    assertEquals(eventData.name, "April Fools 2025", "Event name should be April Fools 2025")
    assertEquals(eventData.eventType, "LUCK", "Event type should be LUCK")
    assertEquals(tostring(eventData.trainerShinyChance), "13107", "Trainer shiny chance should be 13107")
end

testActiveEventDetection()

-- ============================================================================
-- TEST SUITE 2: Event Boundaries (Start and End Times)
-- ============================================================================

print("\n=== TEST SUITE 2: Event Boundaries (Start and End Times) ===")

local function testEventBoundaries()
    print("Test 2.1: No active event before start time")
    -- Winter Holiday Update starts: 2024-12-21
    -- Test time: 2024-12-20 (before event)
    local testTime = 1734652800000 -- 2024-12-20T00:00:00Z

    local result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "false", "IsActive should be false")
    assertEquals(result.EventName, "", "EventName should be empty")

    print("Test 2.2: No active event after end time")
    -- Winter Holiday Update ends: 2025-01-04
    -- Test time: 2025-01-05 (after event)
    testTime = 1736035200000 -- 2025-01-05T00:00:00Z

    result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "false", "IsActive should be false")
    assertEquals(result.EventName, "", "EventName should be empty")

    print("Test 2.3: Active event at exact start time boundary + 1ms")
    -- Winter Holiday Update starts: 2024-12-21T00:00:00Z
    testTime = 1734739200001 -- 1ms after start

    result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "true", "IsActive should be true")

    print("Test 2.4: No active event at exact end time boundary")
    -- Winter Holiday Update ends: 2025-01-04T00:00:00Z
    testTime = 1735948800000 -- Exact end time

    result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "false", "IsActive should be false (endDate is exclusive)")
end

testEventBoundaries()

-- ============================================================================
-- TEST SUITE 3: No Active Event Scenarios
-- ============================================================================

print("\n=== TEST SUITE 3: No Active Event Scenarios ===")

local function testNoActiveEvent()
    print("Test 3.1: No active event between events")
    -- Test time between events (2025-02-05)
    local testTime = 1738713600000 -- 2025-02-05T00:00:00Z

    local result = sendMessage("GetActiveEvent", {CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.HasActiveEvent, "false", "HasActiveEvent should be false")

    local eventData = json.decode(result.Data)
    assertEquals(type(eventData), "table", "Data should be empty table")
    assertEquals(next(eventData), nil, "Data should be empty")

    print("Test 3.2: CheckEventActive returns false with empty EventName")
    result = sendMessage("CheckEventActive", {CurrentTime = tostring(testTime)})
    assertEquals(result.IsActive, "false", "IsActive should be false")
    assertEquals(result.EventName, "", "EventName should be empty string")
end

testNoActiveEvent()

-- ============================================================================
-- TEST SUITE 4: Timestamp Fallback Behavior
-- ============================================================================

print("\n=== TEST SUITE 4: Timestamp Fallback Behavior ===")

local function testTimestampFallback()
    print("Test 4.1: Use msg.Timestamp when CurrentTime not provided")
    -- Use process message timestamp as fallback
    local testTime = 1735084800000 -- 2024-12-25T00:00:00Z

    local msg = {
        Action = "CheckEventActive",
        From = "test_sender",
        Target = processId,
        Timestamp = testTime
        -- Note: No CurrentTime provided
    }

    local result = aolite.send(msg)
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "true", "IsActive should be true")
    assertEquals(result.EventName, "Winter Holiday Update", "EventName should be Winter Holiday Update")
end

testTimestampFallback()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n=== SPECIAL EVENT TRIGGER TEST RESULTS ===")
print("Total Assertions: " .. assertionCount)
print("Failed Assertions: " .. failedAssertions)
print("Passed Assertions: " .. (assertionCount - failedAssertions))
print("Success Rate: " .. string.format("%.1f%%", ((assertionCount - failedAssertions) / assertionCount) * 100))

if failedAssertions == 0 then
    print("\n✓ ALL TESTS PASSED!")
else
    print("\n✗ SOME TESTS FAILED")
end

-- Return success status for test runner
return failedAssertions == 0
