-- Unit tests for Game Mode Engine - Challenge Integration Tests
-- Tests challenge integration functionality

local testMessages, testHandlers = {}, {}
local mockAO = {id = "test-game-mode-process", send = function(msg) table.insert(testMessages, msg); return true end}
local mockHandlers = {add = function(name, matcher, handler) testHandlers[name] = {matcher = matcher, handler = handler} end, utils = {hasMatchingTag = function(tag, value) return function(msg) return msg[tag] == value end end}}
local mockJSON = {encode = function(t) return "{}" end, decode = function(s) return {} end}

local function setupTestEnvironment() _G.ao, _G.Handlers, _G.json = mockAO, mockHandlers, mockJSON end
local function invokeHandler(handlerName, msg) testMessages = {}; local handler = testHandlers[handlerName]; if handler and handler.handler then handler.handler(msg); return testMessages[1] end; return nil end

local function runTests()
    print("Running ADP v1.0 Game Mode Engine Unit Tests - Challenge Integration")
    print("=" .. string.rep("=", 50))

    setupTestEnvironment()
    dofile("processes/game-mode-engine.lua")

    local testsRun, testsPassed = 0, 0

    -- Test: Shop disabled for DAILY
    testsRun = testsRun + 1
    local response = invokeHandler("get-shop-status", {From = "test", Action = "GetShopStatus", ModeId = "3"})
    if response and response.ShopAvailable == "false" then testsPassed = testsPassed + 1; print("✓ DAILY shop disabled") else print("✗ DAILY shop disabled failed") end

    -- Test: Shop enabled for CLASSIC
    testsRun = testsRun + 1
    response = invokeHandler("get-shop-status", {From = "test", Action = "GetShopStatus", ModeId = "0"})
    if response and response.ShopAvailable == "true" then testsPassed = testsPassed + 1; print("✓ CLASSIC shop enabled") else print("✗ CLASSIC shop enabled failed") end

    -- Test: Fixed battle at wave 5
    testsRun = testsRun + 1
    response = invokeHandler("get-fixed-battle-config", {From = "test", Action = "GetFixedBattleConfig", ModeId = "0", WaveIndex = "5"})
    if response and response.HasFixedBattle == "true" then testsPassed = testsPassed + 1; print("✓ Fixed battle wave 5") else print("✗ Fixed battle wave 5 failed") end

    -- Test: Mystery encounter waves for CLASSIC
    testsRun = testsRun + 1
    response = invokeHandler("get-mystery-encounter-waves", {From = "test", Action = "GetMysteryEncounterWaves", ModeId = "0"})
    if response and response.MinWave == "10" and response.MaxWave == "180" then testsPassed = testsPassed + 1; print("✓ CLASSIC mystery waves [10, 180]") else print("✗ CLASSIC mystery waves failed") end

    -- Test: Starting parameters for DAILY
    testsRun = testsRun + 1
    response = invokeHandler("get-starting-parameters", {From = "test", Action = "GetStartingParameters", ModeId = "3"})
    if response and response.StartingLevel == "20" then testsPassed = testsPassed + 1; print("✓ DAILY starting level 20") else print("✗ DAILY starting level failed") end

    print("\n" .. string.rep("=", 50))
    print("Tests run: " .. testsRun .. ", Tests passed: " .. testsPassed)

    if testsPassed == testsRun then
        print("✅ All challenge integration tests passed!")
        return true
    else
        print("❌ Some challenge integration tests failed!")
        return false
    end
end

return {runTests = runTests}
