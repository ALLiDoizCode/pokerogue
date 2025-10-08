-- Unit tests for Difficulty Scaling (getWaveForDifficulty)
-- Tests wave-to-difficulty mapping for all game modes

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-game-mode-process",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers
local mockHandlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON
local mockJSON = {
    encode = function(t)
        if type(t) == "table" then
            return "{}"
        end
        return tostring(t)
    end,
    decode = function(s)
        return {success = true}
    end
}

-- Setup test environment
local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
end

-- Helper to invoke handler
local function invokeHandler(handlerName, msg)
    testMessages = {}
    local handler = testHandlers[handlerName]
    if handler and handler.handler then
        handler.handler(msg)
        return testMessages[1]
    end
    return nil
end

-- Load the process
local function loadProcess()
    setupTestEnvironment()
    dofile("processes/game-mode-engine.lua")
end

-- Test state
local assertionCount = 0
local failedAssertions = 0

-- Game Mode IDs (must match game-mode-engine.lua)
local GAME_MODES = {
    CLASSIC = 0,
    ENDLESS = 1,
    SPLICED_ENDLESS = 2,
    DAILY = 3,
    CHALLENGE = 4
}

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

-- Helper: Assert response success
local function assertSuccess(response, message)
    assertionCount = assertionCount + 1
    if not response or response.Action ~= "SaveState" then
        failedAssertions = failedAssertions + 1
        print("  ✗ FAIL: " .. message)
        print("    Expected: SaveState action")
        print("    Actual: " .. (response and response.Action or "nil"))
        return false
    else
        print("  ✓ PASS: " .. message)
        return true
    end
end

-- Setup: Load process
print("Setting up Game Mode Engine tests for difficulty scaling...")
loadProcess()
print("✓ Process loaded")
print()

-- Test Suite: Daily Mode Difficulty Scaling
print("========================================")
print("Test Suite: Daily Mode Difficulty Scaling")
print("========================================")

-- Test: wave=1 → result=31 (1+30+0)
local response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "1",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 1 returns response") then
    assertEquals(response.EffectiveDifficulty, "31", "Daily mode wave 1 → 31 (1+30+floor(1/5))")
end

-- Test: wave=5 → result=36 (5+30+1)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "5",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 5 returns response") then
    assertEquals(response.EffectiveDifficulty, "36", "Daily mode wave 5 → 36 (5+30+floor(5/5))")
end

-- Test: wave=10 → result=42 (10+30+2)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "10",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 10 returns response") then
    assertEquals(response.EffectiveDifficulty, "42", "Daily mode wave 10 → 42 (10+30+floor(10/5))")
end

-- Test: wave=50 → result=90 (50+30+10)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "50",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 50 returns response") then
    assertEquals(response.EffectiveDifficulty, "90", "Daily mode wave 50 → 90 (50+30+floor(50/5))")
end

-- Test: wave=100 → result=150 (100+30+20)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "100",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 100 returns response") then
    assertEquals(response.EffectiveDifficulty, "150", "Daily mode wave 100 → 150 (100+30+floor(100/5))")
end

-- Test: wave=200 → result=270 (200+30+40)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "200",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 200 returns response") then
    assertEquals(response.EffectiveDifficulty, "270", "Daily mode wave 200 → 270 (200+30+floor(200/5))")
end

print()

-- Test Suite: Daily Mode with ignoreCurveChanges
print("========================================")
print("Test Suite: Daily Mode (ignoreCurveChanges)")
print("========================================")

-- Test: wave=1, ignoreCurve=true → result=31 (1+30+0)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "1",
    IgnoreCurveChanges = "true"
})
if assertSuccess(response, "Daily mode wave 1 (ignore curve) returns response") then
    assertEquals(response.EffectiveDifficulty, "31", "Daily mode wave 1 (ignore) → 31 (1+30+0)")
end

-- Test: wave=10, ignoreCurve=true → result=40 (10+30+0)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "10",
    IgnoreCurveChanges = "true"
})
if assertSuccess(response, "Daily mode wave 10 (ignore curve) returns response") then
    assertEquals(response.EffectiveDifficulty, "40", "Daily mode wave 10 (ignore) → 40 (10+30+0)")
end

-- Test: wave=50, ignoreCurve=true → result=80 (50+30+0)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "50",
    IgnoreCurveChanges = "true"
})
if assertSuccess(response, "Daily mode wave 50 (ignore curve) returns response") then
    assertEquals(response.EffectiveDifficulty, "80", "Daily mode wave 50 (ignore) → 80 (50+30+0)")
end

print()

-- Test Suite: Classic Mode (Passthrough)
print("========================================")
print("Test Suite: Classic Mode (Passthrough)")
print("========================================")

-- Test: Classic mode, wave=1 → result=1
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "1",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Classic mode wave 1 returns response") then
    assertEquals(response.EffectiveDifficulty, "1", "Classic mode wave 1 → 1 (passthrough)")
end

-- Test: Classic mode, wave=100 → result=100
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "100",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Classic mode wave 100 returns response") then
    assertEquals(response.EffectiveDifficulty, "100", "Classic mode wave 100 → 100 (passthrough)")
end

-- Test: Classic mode, wave=200 → result=200
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "200",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Classic mode wave 200 returns response") then
    assertEquals(response.EffectiveDifficulty, "200", "Classic mode wave 200 → 200 (passthrough)")
end

print()

-- Test Suite: Endless Mode (Passthrough)
print("========================================")
print("Test Suite: Endless Mode (Passthrough)")
print("========================================")

-- Test: Endless mode, wave=50 → result=50
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.ENDLESS),
    WaveIndex = "50",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Endless mode wave 50 returns response") then
    assertEquals(response.EffectiveDifficulty, "50", "Endless mode wave 50 → 50 (passthrough)")
end

-- Test: Endless mode, wave=150 → result=150
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.ENDLESS),
    WaveIndex = "150",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Endless mode wave 150 returns response") then
    assertEquals(response.EffectiveDifficulty, "150", "Endless mode wave 150 → 150 (passthrough)")
end

print()

-- Test Suite: Challenge Mode (Passthrough)
print("========================================")
print("Test Suite: Challenge Mode (Passthrough)")
print("========================================")

-- Test: Challenge mode, wave=25 → result=25
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CHALLENGE),
    WaveIndex = "25",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Challenge mode wave 25 returns response") then
    assertEquals(response.EffectiveDifficulty, "25", "Challenge mode wave 25 → 25 (passthrough)")
end

-- Test: Challenge mode, wave=75 → result=75
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CHALLENGE),
    WaveIndex = "75",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Challenge mode wave 75 returns response") then
    assertEquals(response.EffectiveDifficulty, "75", "Challenge mode wave 75 → 75 (passthrough)")
end

print()

-- Test Suite: Spliced Endless Mode (Passthrough)
print("========================================")
print("Test Suite: Spliced Endless Mode (Passthrough)")
print("========================================")

-- Test: Spliced Endless mode, wave=75 → result=75
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.SPLICED_ENDLESS),
    WaveIndex = "75",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Spliced Endless mode wave 75 returns response") then
    assertEquals(response.EffectiveDifficulty, "75", "Spliced Endless mode wave 75 → 75 (passthrough)")
end

-- Test: Spliced Endless mode, wave=125 → result=125
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.SPLICED_ENDLESS),
    WaveIndex = "125",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Spliced Endless mode wave 125 returns response") then
    assertEquals(response.EffectiveDifficulty, "125", "Spliced Endless mode wave 125 → 125 (passthrough)")
end

print()

-- Test Suite: Edge Cases
print("========================================")
print("Test Suite: Edge Cases")
print("========================================")

-- Test: wave=0 (Daily mode)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "0",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 0 returns response") then
    assertEquals(response.EffectiveDifficulty, "30", "Daily mode wave 0 → 30 (0+30+floor(0/5))")
end

-- Test: wave=0 (Classic mode)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "0",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Classic mode wave 0 returns response") then
    assertEquals(response.EffectiveDifficulty, "0", "Classic mode wave 0 → 0 (passthrough)")
end

-- Test: wave=999 (Daily mode - extreme value)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "999",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Daily mode wave 999 returns response") then
    -- 999 + 30 + floor(999/5) = 999 + 30 + 199 = 1228
    assertEquals(response.EffectiveDifficulty, "1228", "Daily mode wave 999 → 1228 (no overflow)")
end

-- Test: wave=999 (Classic mode - extreme value)
response = invokeHandler("get-wave-for-difficulty", {
    From = "test_sender",
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "999",
    IgnoreCurveChanges = "false"
})
if assertSuccess(response, "Classic mode wave 999 returns response") then
    assertEquals(response.EffectiveDifficulty, "999", "Classic mode wave 999 → 999 (passthrough)")
end

print()

-- Final Results
print("========================================")
print("Test Results Summary")
print("========================================")
print("Total Assertions: " .. assertionCount)
print("Passed: " .. (assertionCount - failedAssertions))
print("Failed: " .. failedAssertions)

if failedAssertions == 0 then
    print("✓ ALL TESTS PASSED")
    return true
else
    print("✗ SOME TESTS FAILED")
    return false
end
