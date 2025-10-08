-- Unit tests for Game Mode Engine - Wave Detection Tests
-- Tests wave classification logic for all game modes

-- [Using same mock setup as game-mode-creation.test.lua]
local testMessages = {}
local testHandlers = {}

local mockAO = {
    id = "test-game-mode-process",
    send = function(msg) table.insert(testMessages, msg); return true end
}

local mockHandlers = {
    add = function(name, matcher, handler) testHandlers[name] = {matcher = matcher, handler = handler} end,
    utils = {hasMatchingTag = function(tag, value) return function(msg) return msg[tag] == value end end}
}

local mockJSON = {
    encode = function(t) return "{}" end,
    decode = function(s) return {} end
}

local function setupTestEnvironment()
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
end

local function invokeHandler(handlerName, msg)
    testMessages = {}
    local handler = testHandlers[handlerName]
    if handler and handler.handler then
        handler.handler(msg)
        return testMessages[1]
    end
    return nil
end

local function runTests()
    print("Running ADP v1.0 Game Mode Engine Unit Tests - Wave Detection")
    print("=" .. string.rep("=", 50))

    setupTestEnvironment()
    dofile("processes/game-mode-engine.lua")

    local testsRun, testsPassed = 0, 0

    -- Test: IsWaveFinal for CLASSIC (wave 200)
    testsRun = testsRun + 1
    local response = invokeHandler("is-wave-final", {From = "test", Action = "IsWaveFinal", ModeId = "0", WaveIndex = "200"})
    if response and response.IsWaveFinal == "true" then testsPassed = testsPassed + 1; print("✓ CLASSIC final wave 200") else print("✗ CLASSIC final wave 200 failed") end

    -- Test: IsWaveFinal for ENDLESS (wave 250)
    testsRun = testsRun + 1
    response = invokeHandler("is-wave-final", {From = "test", Action = "IsWaveFinal", ModeId = "1", WaveIndex = "250"})
    if response and response.IsWaveFinal == "true" then testsPassed = testsPassed + 1; print("✓ ENDLESS final wave 250") else print("✗ ENDLESS final wave 250 failed") end

    -- Test: IsWaveFinal for DAILY (wave 50)
    testsRun = testsRun + 1
    response = invokeHandler("is-wave-final", {From = "test", Action = "IsWaveFinal", ModeId = "3", WaveIndex = "50"})
    if response and response.IsWaveFinal == "true" then testsPassed = testsPassed + 1; print("✓ DAILY final wave 50") else print("✗ DAILY final wave 50 failed") end

    -- Test: Boss wave detection (wave 10)
    testsRun = testsRun + 1
    response = invokeHandler("get-wave-classification", {From = "test", Action = "GetWaveClassification", ModeId = "0", WaveIndex = "10"})
    if response and response.IsBoss == "true" then testsPassed = testsPassed + 1; print("✓ Boss wave 10 detected") else print("✗ Boss wave 10 failed") end

    -- Test: GetWaveForDifficulty DAILY
    testsRun = testsRun + 1
    response = invokeHandler("get-wave-for-difficulty", {From = "test", Action = "GetWaveForDifficulty", ModeId = "3", WaveIndex = "10"})
    if response and response.EffectiveDifficulty == "42" then testsPassed = testsPassed + 1; print("✓ DAILY difficulty calculation") else print("✗ DAILY difficulty failed") end

    print("\n" .. string.rep("=", 50))
    print("Tests run: " .. testsRun .. ", Tests passed: " .. testsPassed)

    if testsPassed == testsRun then
        print("✅ All wave detection tests passed!")
        return true
    else
        print("❌ Some wave detection tests failed!")
        return false
    end
end

return {runTests = runTests}
