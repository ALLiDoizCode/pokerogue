-- Unit tests for Game Mode Engine - Rewards Tests
-- Tests reward calculation for all game modes

local testMessages, testHandlers = {}, {}
local mockAO = {id = "test-game-mode-process", send = function(msg) table.insert(testMessages, msg); return true end}
local mockHandlers = {add = function(name, matcher, handler) testHandlers[name] = {matcher = matcher, handler = handler} end, utils = {hasMatchingTag = function(tag, value) return function(msg) return msg[tag] == value end end}}
local mockJSON = {encode = function(t) return "{}" end, decode = function(s) return {} end}

local function setupTestEnvironment() _G.ao, _G.Handlers, _G.json = mockAO, mockHandlers, mockJSON end
local function invokeHandler(handlerName, msg) testMessages = {}; local handler = testHandlers[handlerName]; if handler and handler.handler then handler.handler(msg); return testMessages[1] end; return nil end

local function runTests()
    print("Running ADP v1.0 Game Mode Engine Unit Tests - Rewards")
    print("=" .. string.rep("=", 50))

    setupTestEnvironment()
    dofile("processes/game-mode-engine.lua")

    local testsRun, testsPassed = 0, 0

    -- Test: Clear bonus for CLASSIC
    testsRun = testsRun + 1
    local response = invokeHandler("get-mode-rewards", {From = "test", Action = "GetModeRewards", ModeId = "0"})
    if response and response.ClearScoreBonus == "5000" then testsPassed = testsPassed + 1; print("✓ CLASSIC clear bonus 5000") else print("✗ CLASSIC clear bonus failed") end

    -- Test: Clear bonus for DAILY
    testsRun = testsRun + 1
    response = invokeHandler("get-mode-rewards", {From = "test", Action = "GetModeRewards", ModeId = "3"})
    if response and response.ClearScoreBonus == "2500" then testsPassed = testsPassed + 1; print("✓ DAILY clear bonus 2500") else print("✗ DAILY clear bonus failed") end

    -- Test: Enemy modifier chance CLASSIC non-boss
    testsRun = testsRun + 1
    response = invokeHandler("get-mode-rewards", {From = "test", Action = "GetModeRewards", ModeId = "0", IsBoss = "false"})
    if response and response.EnemyModifierChance == "18" then testsPassed = testsPassed + 1; print("✓ CLASSIC non-boss modifier 18") else print("✗ CLASSIC non-boss modifier failed") end

    -- Test: Override species for DAILY final wave
    testsRun = testsRun + 1
    response = invokeHandler("get-override-species", {From = "test", Action = "GetOverrideSpecies", ModeId = "3", WaveIndex = "50"})
    if response and response.HasOverride == "true" then testsPassed = testsPassed + 1; print("✓ DAILY override species") else print("✗ DAILY override species failed") end

    print("\n" .. string.rep("=", 50))
    print("Tests run: " .. testsRun .. ", Tests passed: " .. testsPassed)

    if testsPassed == testsRun then
        print("✅ All rewards tests passed!")
        return true
    else
        print("❌ Some rewards tests failed!")
        return false
    end
end

return {runTests = runTests}
