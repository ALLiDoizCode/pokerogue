-- Unit Tests for Special Event Rewards
-- Tests event reward distribution and Delibirdy buffs

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
        return false
    else
        print("  ✓ PASS: " .. message)
        return true
    end
end

-- Setup: Load process
print("Setting up Special Event Rewards tests...")
processId = aolite.spawnProcess("special-event-engine", "./processes/special-event-engine.lua")

if not processId then
    error("Failed to spawn special-event-engine process")
end

print("Process spawned with ID: " .. processId)

-- ============================================================================
-- TEST SUITE 1: Wave Rewards
-- ============================================================================

print("\n=== TEST SUITE 1: Wave Rewards ===")

local function testWave8Rewards()
    print("Test 1.1: Retrieve wave 8 rewards during Winter Holiday event")
    local testTime = 1735084800000 -- 2024-12-25

    local result = sendMessage("GetEventRewards", {Wave = "8", CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.RewardCount, "3", "Should have 3 rewards")

    local rewards = json.decode(result.Data or "[]")
    assertEquals(#rewards, 3, "Decoded rewards should have 3 items")
end

local function testWave25Rewards()
    print("Test 1.2: Retrieve wave 25 rewards during event")
    local testTime = 1735084800000

    local result = sendMessage("GetEventRewards", {Wave = "25", CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.RewardCount, "1", "Should have 1 reward")
end

local function testEmptyRewards()
    print("Test 1.3: No rewards for non-event wave")
    local testTime = 1735084800000

    local result = sendMessage("GetEventRewards", {Wave = "100", CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.RewardCount, "0", "Should have 0 rewards")
end

local function testMissingWaveParameter()
    print("Test 1.4: Error when Wave parameter missing")
    local testTime = 1735084800000

    local result = sendMessage("GetEventRewards", {CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "Error", "Action should be Error")
    assertTrue(result.Error ~= nil, "Error message should be present")
end

testWave8Rewards()
testWave25Rewards()
testEmptyRewards()
testMissingWaveParameter()

-- ============================================================================
-- TEST SUITE 2: Event Effects
-- ============================================================================

print("\n=== TEST SUITE 2: Event Effects ===")

local function testShinyMultiplierInEffects()
    print("Test 2.1: GetEventEffects includes shiny multiplier")
    -- Valentine event: 2025-02-10 to 2025-02-21 (shinyMultiplier: 2)
    local testTime = 1739145600000 + (86400000 * 5) -- 2025-02-15 (middle of Valentine event)

    local result = sendMessage("GetEventEffects", {CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.ShinyMultiplier, "2", "Shiny multiplier should be 2")
end

local function testFriendshipMultiplier()
    print("Test 2.2: GetEventEffects includes friendship multiplier")
    -- PKMNDAY2025 event: 2025-02-27 to 2025-03-04 (classicFriendshipMultiplier: 4)
    local testTime = 1740614400000 + (86400000 * 2) -- 2025-03-01 (middle of PKMNDAY2025 event)

    local result = sendMessage("GetEventEffects", {CurrentTime = tostring(testTime)})
    assertEquals(result.FriendshipMultiplier, "4", "Friendship multiplier should be 4")
end

local function testLuckBoost()
    print("Test 2.3: GetEventEffects includes luck boost")
    -- Year of the Snake event: 2025-01-29 to 2025-02-03 (luckBoost: 1)
    local testTime = 1738108800000 + (86400000 * 2) -- 2025-01-31 (middle of Year of Snake event)

    local result = sendMessage("GetEventEffects", {CurrentTime = tostring(testTime)})
    assertEquals(result.LuckBoost, "1", "Luck boost should be 1")
end

testShinyMultiplierInEffects()
testFriendshipMultiplier()
testLuckBoost()

-- ============================================================================
-- TEST SUITE 3: No Active Event
-- ============================================================================

print("\n=== TEST SUITE 3: No Active Event ===")

local function testNoActiveEventEffects()
    print("Test 3.1: GetEventEffects returns defaults when no event active")
    local testTime = 1704067200000 -- 2024-01-01 (no active events)

    local result = sendMessage("GetEventEffects", {CurrentTime = tostring(testTime)})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.ShinyMultiplier, "1", "Default shiny multiplier should be 1")
    assertEquals(result.LuckBoost, "0", "Default luck boost should be 0")
    assertEquals(result.FriendshipMultiplier, "2.5", "Default friendship multiplier should be 2.5 (CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER)")
end

testNoActiveEventEffects()

-- ============================================================================
-- RESULTS
-- ============================================================================

print("\n=== SPECIAL EVENT REWARDS TEST RESULTS ===")
print("Total Assertions: " .. assertionCount)
print("Failed Assertions: " .. failedAssertions)
print("Passed Assertions: " .. (assertionCount - failedAssertions))
print("Success Rate: " .. string.format("%.1f", (assertionCount - failedAssertions) / assertionCount * 100) .. "%")

if failedAssertions == 0 then
    print("\n✓ ALL TESTS PASSED!")
    os.exit(0)
else
    print("\n✗ SOME TESTS FAILED!")
    os.exit(1)
end
