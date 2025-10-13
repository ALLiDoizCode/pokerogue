-- Unit Tests for Special Event Duration
-- Tests event duration tracking and time boundary conditions

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.special-event-engine"
local processId = "test-special-event-duration"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

-- Test state
local testMessages = {}
local assertionCount = 0
local failedAssertions = 0

-- Helper to send message and capture response
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    if data then
        msg.Data = type(data) == "table" and json.encode(data) or data
    end

    aolite.send(msg)
    local result = aolite.getLastMsg(processId)
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
local function assertTrue(value, message)
    assertionCount = assertionCount + 1
    if not value then
        failedAssertions = failedAssertions + 1
        print("  ✗ FAIL: " .. message)
        print("    Expected: true")
        print("    Actual: " .. tostring(value))
        return false
    else
        print("  ✓ PASS: " .. message)
        return true
    end
end

print("🧪 Starting Aolite Tests for Special Event Duration")
print("Process ID:", processId)

-- ============================================================================
-- TEST SUITE 1: Multi-Day Event Duration
-- ============================================================================

print("\n=== TEST SUITE 1: Multi-Day Event Duration ===")

local function testMultiDayEventActive()
    print("Test 1.1: Event active at start + 1ms")
    local result = sendMessage("CheckEventActive", {CurrentTime = "1734739200001"})
    assertEquals(result.IsActive, "true", "Event should be active at start + 1ms")
    assertEquals(result.EventName, "Winter Holiday Update", "Event name should be Winter Holiday Update")

    print("Test 1.2: Event active at middle (Dec 25)")
    result = sendMessage("CheckEventActive", {CurrentTime = "1735084800000"})
    assertEquals(result.IsActive, "true", "Event should be active at middle")
    assertEquals(result.EventName, "Winter Holiday Update", "Event name should be Winter Holiday Update")

    print("Test 1.3: Event active at end - 1ms")
    result = sendMessage("CheckEventActive", {CurrentTime = "1735948799999"})
    assertEquals(result.IsActive, "true", "Event should be active at end - 1ms")
    assertEquals(result.EventName, "Winter Holiday Update", "Event name should be Winter Holiday Update")
end

local function testShortDurationEvent()
    print("Test 1.4: April Fools event active (3 days)")
    local result = sendMessage("CheckEventActive", {CurrentTime = "1743638400000"})
    assertEquals(result.IsActive, "true", "April Fools should be active")
    assertEquals(result.EventName, "April Fools 2025", "Event name should be April Fools 2025")
end

testMultiDayEventActive()
testShortDurationEvent()

-- ============================================================================
-- TEST SUITE 2: Event Transitions
-- ============================================================================

print("\n=== TEST SUITE 2: Event Transitions ===")

local function testEventBoundaries()
    print("Test 2.1: Just before Winter Holiday ends")
    local result = sendMessage("CheckEventActive", {CurrentTime = "1735948799999"})
    assertEquals(result.IsActive, "true", "Event should be active just before end")
    assertEquals(result.EventName, "Winter Holiday Update", "Event name should be Winter Holiday Update")

    print("Test 2.2: Exactly at Winter Holiday end")
    result = sendMessage("CheckEventActive", {CurrentTime = "1735948800000"})
    assertEquals(result.IsActive, "false", "Event should not be active at exact end")

    print("Test 2.3: Gap between events (no active event)")
    result = sendMessage("CheckEventActive", {CurrentTime = "1736553600000"})
    assertEquals(result.IsActive, "false", "No event should be active in gap")

    print("Test 2.4: Year of the Snake starts")
    result = sendMessage("CheckEventActive", {CurrentTime = "1738108800001"})
    assertEquals(result.IsActive, "true", "Year of the Snake should be active")
    assertEquals(result.EventName, "Year of the Snake", "Event name should be Year of the Snake")
end

testEventBoundaries()

-- ============================================================================
-- TEST SUITE 3: Event Filtering
-- ============================================================================

print("\n=== TEST SUITE 3: Event Filtering ===")

local function testExpiredEvents()
    print("Test 3.1: Filter out expired events (far future)")
    local result = sendMessage("CheckEventActive", {CurrentTime = "1780000000000"})
    assertEquals(result.IsActive, "false", "No event should be active in far future")
    assertEquals(result.EventName, "", "Event name should be empty")
end

local function testFutureEvents()
    print("Test 3.2: Filter out future events (before start)")
    local result = sendMessage("CheckEventActive", {CurrentTime = "1700000000000"})
    assertEquals(result.IsActive, "false", "No event should be active before first event")
    assertEquals(result.EventName, "", "Event name should be empty")
end

testExpiredEvents()
testFutureEvents()

-- ============================================================================
-- TEST SUITE 4: Millisecond Precision
-- ============================================================================

print("\n=== TEST SUITE 4: Millisecond Precision ===")

local function testMillisecondBoundaries()
    print("Test 4.1: 1ms before Valentine start")
    local result = sendMessage("CheckEventActive", {CurrentTime = "1739145599999"})
    assertEquals(result.IsActive, "false", "Event should not be active 1ms before start")

    print("Test 4.2: Exactly at Valentine start")
    result = sendMessage("CheckEventActive", {CurrentTime = "1739145600000"})
    assertEquals(result.IsActive, "false", "Event should not be active at exact start (exclusive)")

    print("Test 4.3: 1ms after Valentine start")
    result = sendMessage("CheckEventActive", {CurrentTime = "1739145600001"})
    assertEquals(result.IsActive, "true", "Event should be active 1ms after start")
    assertEquals(result.EventName, "Valentine", "Event name should be Valentine")
end

local function testZeroTimestamp()
    print("Test 4.4: Zero timestamp (epoch)")
    local result = sendMessage("CheckEventActive", {CurrentTime = "0"})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.IsActive, "false", "No event should be active at epoch")
end

testMillisecondBoundaries()
testZeroTimestamp()

-- ============================================================================
-- TEST SUITE 5: Cross-Handler Consistency
-- ============================================================================

print("\n=== TEST SUITE 5: Cross-Handler Consistency ===")

local function testHandlerConsistency()
    print("Test 5.1: Same event detected by CheckEventActive and GetActiveEvent")
    local result1 = sendMessage("CheckEventActive", {CurrentTime = "1750464000000"})
    assertEquals(result1.IsActive, "true", "CheckEventActive should detect Pride 25")
    assertEquals(result1.EventName, "Pride 25", "Event name should be Pride 25")

    local result2 = sendMessage("GetActiveEvent", {CurrentTime = "1750464000000"})
    assertEquals(result2.HasActiveEvent, "true", "GetActiveEvent should detect Pride 25")

    local eventData = json.decode(result2.Data)
    assertEquals(eventData.name, "Pride 25", "GetActiveEvent event name should be Pride 25")
end

testHandlerConsistency()

-- ============================================================================
-- TEST SUITE 6: Specific Event Tests
-- ============================================================================

print("\n=== TEST SUITE 6: Specific Event Tests ===")

local function testPKMNDAY2025Event()
    print("Test 6.1: PKMNDAY2025 event active and has correct multiplier")
    local result = sendMessage("GetActiveEvent", {CurrentTime = "1740873600000"})
    assertEquals(result.HasActiveEvent, "true", "PKMNDAY2025 should be active")

    local eventData = json.decode(result.Data)
    assertEquals(eventData.name, "PKMNDAY2025", "Event name should be PKMNDAY2025")
    assertEquals(tostring(eventData.classicFriendshipMultiplier), "4", "Friendship multiplier should be 4")
end

local function testShiningSpringEvent()
    print("Test 6.2: Shining Spring event active with correct properties")
    local result = sendMessage("GetActiveEvent", {CurrentTime = "1746662400000"})
    assertEquals(result.HasActiveEvent, "true", "Shining Spring should be active")

    local eventData = json.decode(result.Data)
    assertEquals(eventData.name, "Shining Spring", "Event name should be Shining Spring")
    assertEquals(eventData.eventType, "SHINY", "Event type should be SHINY")
    assertEquals(tostring(eventData.shinyMultiplier), "2", "Shiny multiplier should be 2")
    assertTrue(eventData.upgradeUnlockedVouchers, "Should upgrade unlocked vouchers")
end

testPKMNDAY2025Event()
testShiningSpringEvent()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n=== SPECIAL EVENT DURATION TEST RESULTS ===")
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
