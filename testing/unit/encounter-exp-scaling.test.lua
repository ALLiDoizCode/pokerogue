-- Unit Tests: Encounter Experience Scaling
-- Tests experience reward calculation and wave scaling logic

package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

local tests = {}
local currentTest = ""

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
        error(currentTest .. " FAILED: " .. message)
    end
end

local function setup()
    local process = aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
    return process
end

-- ============================================================================
-- Test: Exp Scaling with Wave Index
-- ============================================================================

tests["exp scaling with wave index enabled"] = function()
    currentTest = "exp scaling with wave index enabled"
    local process = setup()

    local baseExp = 100
    local waveIndex = 50

    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        BaseExpValue = tostring(baseExp),
        WaveIndex = tostring(waveIndex),
        UseWaveIndex = "true"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.Action, "SaveState", "Response should be SaveState")
    assertEquals(response.Success, "true", "Success should be true")

    local totalExp = tonumber(response.TotalExp)
    assertNotNil(totalExp, "TotalExp should be present")

    -- Expected calculation: baseExp * (1 + waveIndex / 50)
    -- 100 * (1 + 50/50) = 100 * 2 = 200
    local expectedExp = baseExp * (1 + (waveIndex / 50))
    assertEquals(totalExp, expectedExp, "Scaled exp should match formula")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Direct Exp Value (No Wave Scaling)
-- ============================================================================

tests["direct exp value without wave scaling"] = function()
    currentTest = "direct exp value without wave scaling"
    local process = setup()

    local baseExp = 150
    local waveIndex = 50

    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        BaseExpValue = tostring(baseExp),
        WaveIndex = tostring(waveIndex),
        UseWaveIndex = "false"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    local totalExp = tonumber(response.TotalExp)
    assertEquals(totalExp, baseExp, "Exp should equal base value when UseWaveIndex is false")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Participant ID Filtering
-- ============================================================================

tests["participant id filtering"] = function()
    currentTest = "participant id filtering"
    local process = setup()

    local participantIds = "1,3,5"

    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        BaseExpValue = "100",
        ParticipantIds = participantIds,
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.ParticipantIds, participantIds, "Should preserve participant IDs")

    local data = aolite.json.decode(response.Data)
    assertNotNil(data.participantIds, "Data should contain participantIds")
    assertEquals(#data.participantIds, 3, "Should have 3 participants")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Base Exp Value Guidelines
-- ============================================================================

tests["base exp value guidelines range"] = function()
    currentTest = "base exp value guidelines range"
    local process = setup()

    -- Test various base exp values from guidelines
    local testValues = {
        36,   -- Sunkern (lowest)
        62,   -- Regional starter
        100,  -- Scyther
        170,  -- Spiritomb
        250,  -- Gengar
        290,  -- Trio legendary
        340,  -- Box legendary
        608   -- Blissey (highest)
    }

    for _, baseExp in ipairs(testValues) do
        local msg = {
            From = "test_player",
            Action = "CalculateExpReward",
            BaseExpValue = tostring(baseExp),
            WaveIndex = "0",
            UseWaveIndex = "false"
        }

        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]

        assertEquals(response.Success, "true", "Should succeed with base exp " .. baseExp)
        local totalExp = tonumber(response.TotalExp)
        assertEquals(totalExp, baseExp, "Should return correct base exp value")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Wave Scaling Formula
-- ============================================================================

tests["wave scaling formula correctness"] = function()
    currentTest = "wave scaling formula correctness"
    local process = setup()

    local baseExp = 100

    -- Test at various wave indices
    local testCases = {
        {wave = 0, expectedMultiplier = 1.0},
        {wave = 25, expectedMultiplier = 1.5},
        {wave = 50, expectedMultiplier = 2.0},
        {wave = 100, expectedMultiplier = 3.0},
        {wave = 200, expectedMultiplier = 5.0}
    }

    for _, testCase in ipairs(testCases) do
        local msg = {
            From = "test_player",
            Action = "CalculateExpReward",
            BaseExpValue = tostring(baseExp),
            WaveIndex = tostring(testCase.wave),
            UseWaveIndex = "true"
        }

        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]

        local totalExp = tonumber(response.TotalExp)
        local expectedExp = baseExp * testCase.expectedMultiplier
        assertEquals(totalExp, expectedExp,
            "Wave " .. testCase.wave .. " should produce " .. expectedExp .. " exp")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Default UseWaveIndex Behavior
-- ============================================================================

tests["default use wave index behavior"] = function()
    currentTest = "default use wave index behavior"
    local process = setup()

    local baseExp = 100
    local waveIndex = 50

    -- Message without UseWaveIndex (should default to true)
    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        BaseExpValue = tostring(baseExp),
        WaveIndex = tostring(waveIndex)
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    local totalExp = tonumber(response.TotalExp)
    local expectedExp = baseExp * (1 + (waveIndex / 50))

    assertEquals(totalExp, expectedExp, "Should use wave scaling by default")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Encounter Type Base Exp Derivation
-- ============================================================================

tests["encounter type base exp derivation"] = function()
    currentTest = "encounter type base exp derivation"
    local process = setup()

    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        EncounterType = "MYSTERIOUS_CHEST",
        WaveIndex = "0",
        UseWaveIndex = "false"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.Success, "true", "Should succeed with EncounterType")
    assertNotNil(response.TotalExp, "Should derive base exp from encounter type")

    local totalExp = tonumber(response.TotalExp)
    assert(totalExp > 0, "Derived exp should be positive")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Missing Base Exp Error
-- ============================================================================

tests["missing base exp value error"] = function()
    currentTest = "missing base exp value error"
    local process = setup()

    -- Message without BaseExpValue or valid EncounterType
    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    -- Should either error or provide default value
    assert(response.Action == "Error" or response.Success == "true",
        "Should handle missing base exp gracefully")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Empty Participant IDs
-- ============================================================================

tests["empty participant ids"] = function()
    currentTest = "empty participant ids"
    local process = setup()

    local msg = {
        From = "test_player",
        Action = "CalculateExpReward",
        BaseExpValue = "100",
        ParticipantIds = "",
        WaveIndex = "10"
    }

    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]

    assertEquals(response.Success, "true", "Should handle empty participant IDs")
    assertEquals(response.ParticipantIds, "", "Should preserve empty participant IDs")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Run all tests
-- ============================================================================

local function runTests()
    local passed = 0
    local failed = 0

    print("\n=== Encounter Exp Scaling Tests ===\n")

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

return runTests()
