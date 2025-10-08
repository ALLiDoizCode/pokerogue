-- Unit Tests: Encounter Reward Calculation
-- Tests reward calculation logic for mystery encounters with various outcomes

-- Load test framework
package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

-- Test state
local tests = {}
local currentTest = ""

-- Test helper functions
local function assert(condition, message)
    if not condition then
        error(currentTest .. " FAILED: " .. message)
    end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(currentTest .. " FAILED: " .. message .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end
end

local function assertNotNil(value, message)
    if value == nil then
        error(currentTest .. " FAILED: " .. message .. " (value is nil)")
    end
end

-- Setup test environment
local function setup()
    -- Load the process
    local process = aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
    return process
end

-- ============================================================================
-- Test Suite: Reward Calculation with Success Outcome
-- ============================================================================

tests["reward calculation with success outcome"] = function()
    currentTest = "reward calculation with success outcome"
    local process = setup()

    -- Send CalculateRewards message with success outcome
    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "success",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    assertNotNil(responses[1], "Should receive response")

    local response = responses[1]
    assertEquals(response.Action, "SaveState", "Response should be SaveState")
    assertEquals(response.Success, "true", "Success should be true")
    assertEquals(response.HasRewards, "true", "Should have rewards for success")

    -- Parse response data
    local data = aolite.json.decode(response.Data)
    assertNotNil(data.customShopRewards, "Should have customShopRewards")
    assertEquals(data.customShopRewards.allowLuckUpgrades, true, "Should allow luck upgrades on success")
    assertEquals(data.customShopRewards.rerollMultiplier, 1, "Should have normal reroll cost on success")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test Suite: Reward Calculation with Failure Outcome
-- ============================================================================

tests["reward calculation with failure outcome"] = function()
    currentTest = "reward calculation with failure outcome"
    local process = setup()

    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "failure",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.Success, "true", "Request should succeed")
    assertEquals(response.HasRewards, "false", "Should have no rewards for failure")

    local data = aolite.json.decode(response.Data)
    assertEquals(data.customShopRewards, nil, "Should have no customShopRewards on failure")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test Suite: Reward Calculation with Partial Outcome
-- ============================================================================

tests["reward calculation with partial outcome"] = function()
    currentTest = "reward calculation with partial outcome"
    local process = setup()

    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "partial",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.HasRewards, "true", "Should have some rewards for partial success")

    local data = aolite.json.decode(response.Data)
    assertNotNil(data.customShopRewards, "Should have customShopRewards")
    assertEquals(data.customShopRewards.allowLuckUpgrades, false, "Should not allow luck upgrades on partial")
    assertEquals(data.customShopRewards.rerollMultiplier, 2, "Should have increased reroll cost on partial")

    local tiers = data.customShopRewards.guaranteedModifierTiers
    assert(#tiers == 2, "Should have 2 guaranteed tiers for partial success")
    assertEquals(tiers[1], "COMMON", "First tier should be COMMON")
    assertEquals(tiers[2], "UNCOMMON", "Second tier should be UNCOMMON")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test Suite: Guaranteed Modifier Inclusion
-- ============================================================================

tests["guaranteed modifier inclusion"] = function()
    currentTest = "guaranteed modifier inclusion"
    local process = setup()

    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "success",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]
    local data = aolite.json.decode(response.Data)

    local guaranteedModifiers = data.customShopRewards.guaranteedModifierTypeFuncs
    assertNotNil(guaranteedModifiers, "Should have guaranteed modifiers")
    assert(#guaranteedModifiers > 0, "Should have at least one guaranteed modifier for MYSTERIOUS_CHEST")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test Suite: Egg Reward Generation
-- ============================================================================

tests["egg reward generation"] = function()
    currentTest = "egg reward generation"
    local process = setup()

    -- Test encounter with egg reward
    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        EncounterType = "POKEMON_BREEDER",
        OptionIndex = "0",
        Outcome = "success",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]
    local data = aolite.json.decode(response.Data)

    assertNotNil(data.eggRewards, "Should have egg rewards for POKEMON_BREEDER")
    assert(#data.eggRewards > 0, "Should have at least one egg")

    local egg = data.eggRewards[1]
    assertNotNil(egg.tier, "Egg should have tier")
    assertNotNil(egg.sourceType, "Egg should have sourceType")
    assertNotNil(egg.hatchWaves, "Egg should have hatchWaves")
    assertEquals(egg.pulled, false, "Egg should not be pulled initially")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test Suite: Reward Configuration Validity
-- ============================================================================

tests["reward configuration validity"] = function()
    currentTest = "reward configuration validity"
    local process = setup()

    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "success",
        WaveIndex = "50"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    -- Validate response structure
    assertNotNil(response.Action, "Response should have Action")
    assertNotNil(response.Success, "Response should have Success")
    assertNotNil(response.HasRewards, "Response should have HasRewards")
    assertNotNil(response.HasExp, "Response should have HasExp")
    assertNotNil(response.Data, "Response should have Data")

    -- Validate data structure
    local data = aolite.json.decode(response.Data)
    assert(type(data) == "table", "Data should be a table")
    assert(data.customShopRewards ~= nil or data.eggRewards ~= nil or response.HasRewards == "false",
        "Should have rewards or HasRewards should be false")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test Suite: Missing Parameters Error
-- ============================================================================

tests["missing parameters error"] = function()
    currentTest = "missing parameters error"
    local process = setup()

    -- Missing EncounterType
    local msg = {
        From = "test_player",
        Action = "CalculateRewards",
        OptionIndex = "0",
        Outcome = "success"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.Action, "Error", "Should return Error for missing parameters")
    assertNotNil(response.Error, "Should have error message")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Run all tests
-- ============================================================================

local function runTests()
    local passed = 0
    local failed = 0

    print("\n=== Encounter Reward Calculation Tests ===\n")

    for name, test in pairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ " .. name .. ": " .. err)
        end
    end

    print("\n=== Test Summary ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))

    if failed == 0 then
        print("\n✓ All tests passed!")
        return 0
    else
        print("\n✗ Some tests failed")
        return 1
    end
end

-- Run tests
return runTests()
