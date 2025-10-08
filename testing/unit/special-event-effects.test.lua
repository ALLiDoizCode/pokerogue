-- Unit Tests for Special Event Effects
-- Tests event effect calculations (shiny multiplier, luck boost, etc.)

-- Add development-tools to package path
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

-- Setup: Load process
print("Setting up Special Event Effects tests...")
processId = aolite.spawnProcess("special-event-engine", "./processes/special-event-engine.lua")

if not processId then
    error("Failed to spawn special-event-engine process")
end

print("Process spawned with ID: " .. processId)

-- ============================================================================
-- TEST SUITE 1: Shiny Multiplier
-- ============================================================================

print("\n=== TEST SUITE 1: Shiny Multiplier ===")

local function testShinyMultiplier()
    print("Test 1.1: Shiny multiplier for Winter Holiday (SHINY event)")
    local result = sendMessage("GetShinyMultiplier", {CurrentTime = "1735084800000"})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.ShinyMultiplier, "2", "Shiny multiplier should be 2")

    print("Test 1.2: Default multiplier when no event active")
    result = sendMessage("GetShinyMultiplier", {CurrentTime = "1736553600000"})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.ShinyMultiplier, "1", "Default shiny multiplier should be 1")
end

testShinyMultiplier()

-- ============================================================================
-- TEST SUITE 2: Luck Boost
-- ============================================================================

print("\n=== TEST SUITE 2: Luck Boost ===")

local function testLuckBoost()
    print("Test 2.1: Luck boost for Year of the Snake (LUCK event)")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1738368000000"})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.LuckBoost, "1", "Luck boost should be 1")

    print("Test 2.2: Zero luck boost during SHINY event")
    result = sendMessage("GetEventEffects", {CurrentTime = "1735084800000"})
    assertEquals(result.LuckBoost, "0", "Luck boost should be 0 during SHINY event")
end

testLuckBoost()

-- ============================================================================
-- TEST SUITE 3: Friendship Multiplier
-- ============================================================================

print("\n=== TEST SUITE 3: Friendship Multiplier ===")

local function testFriendshipMultiplier()
    print("Test 3.1: Highest friendship multiplier (PKMNDAY2025)")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1740873600000"})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.FriendshipMultiplier, "4", "Friendship multiplier should be 4")

    print("Test 3.2: Default friendship multiplier (no custom value)")
    result = sendMessage("GetEventEffects", {CurrentTime = "1738368000000"})
    assertEquals(result.FriendshipMultiplier, "2.5", "Default friendship multiplier should be 2.5")
end

testFriendshipMultiplier()

-- ============================================================================
-- TEST SUITE 4: Voucher Upgrade
-- ============================================================================

print("\n=== TEST SUITE 4: Voucher Upgrade ===")

local function testVoucherUpgrade()
    print("Test 4.1: Voucher upgrade flag enabled (Winter Holiday)")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1735084800000"})
    assertEquals(result.UpgradeVouchers, "true", "Voucher upgrade should be enabled")

    print("Test 4.2: Voucher upgrade flag disabled (Year of the Snake)")
    result = sendMessage("GetEventEffects", {CurrentTime = "1738368000000"})
    assertEquals(result.UpgradeVouchers, "false", "Voucher upgrade should be disabled")
end

testVoucherUpgrade()

-- ============================================================================
-- TEST SUITE 5: Trainer Shiny Chance
-- ============================================================================

print("\n=== TEST SUITE 5: Trainer Shiny Chance ===")

local function testTrainerShinyChance()
    print("Test 5.1: Trainer shiny chance (April Fools)")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1743638400000"})
    assertEquals(result.TrainerShinyChance, "13107", "Trainer shiny chance should be 13107")

    print("Test 5.2: Zero trainer shiny chance (Winter Holiday)")
    result = sendMessage("GetEventEffects", {CurrentTime = "1735084800000"})
    assertEquals(result.TrainerShinyChance, "0", "Trainer shiny chance should be 0")
end

testTrainerShinyChance()

-- ============================================================================
-- TEST SUITE 6: Aggregated Effects
-- ============================================================================

print("\n=== TEST SUITE 6: Aggregated Effects ===")

local function testAggregatedEffects()
    print("Test 6.1: All effects aggregated (Winter Holiday)")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1735084800000"})
    assertEquals(result.Action, "SaveState", "Action should be SaveState")
    assertEquals(result.Success, "true", "Success should be true")
    assertEquals(result.ShinyMultiplier, "2", "Shiny multiplier should be 2")
    assertEquals(result.LuckBoost, "0", "Luck boost should be 0")
    assertEquals(result.FriendshipMultiplier, "2.5", "Friendship multiplier should be 2.5")
    assertEquals(result.UpgradeVouchers, "true", "Voucher upgrade should be true")
    assertEquals(result.TrainerShinyChance, "0", "Trainer shiny chance should be 0")

    local effectData = json.decode(result.Data)
    assertEquals(tostring(effectData.shinyMultiplier), "2", "Data shiny multiplier should be 2")
    assertEquals(tostring(effectData.luckBoost), "0", "Data luck boost should be 0")
    assertEquals(tostring(effectData.friendshipMultiplier), "2.5", "Data friendship multiplier should be 2.5")
    assertTrue(effectData.upgradeVouchers, "Data voucher upgrade should be true")
    assertEquals(tostring(effectData.trainerShinyChance), "0", "Data trainer shiny chance should be 0")
end

testAggregatedEffects()

-- ============================================================================
-- TEST SUITE 7: Specific Event Effects
-- ============================================================================

print("\n=== TEST SUITE 7: Specific Event Effects ===")

local function testValentineBoostFusions()
    print("Test 7.1: Valentine boost fusions flag")
    local result = sendMessage("GetActiveEvent", {CurrentTime = "1739664000000"})
    local eventData = json.decode(result.Data)
    assertTrue(eventData.boostFusions, "Valentine should have boost fusions enabled")
end

local function testShiningSpringEffects()
    print("Test 7.2: Shining Spring effects")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1746662400000"})
    assertEquals(result.ShinyMultiplier, "2", "Shining Spring shiny multiplier should be 2")
    assertEquals(result.UpgradeVouchers, "true", "Shining Spring should upgrade vouchers")
end

local function testPride25Effects()
    print("Test 7.3: Pride 25 effects")
    local result = sendMessage("GetEventEffects", {CurrentTime = "1750464000000"})
    assertEquals(result.ShinyMultiplier, "2", "Pride 25 shiny multiplier should be 2")
    assertEquals(result.UpgradeVouchers, "false", "Pride 25 should not upgrade vouchers")
end

testValentineBoostFusions()
testShiningSpringEffects()
testPride25Effects()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n=== SPECIAL EVENT EFFECTS TEST RESULTS ===")
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
