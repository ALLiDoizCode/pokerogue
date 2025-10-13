-- Unit tests for Game Mode Engine - Challenge Integration Tests (CORRECT API)
-- Tests challenge integration functionality

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.game-mode-engine"
local processId = "test-game-mode-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Game Mode Engine - Challenge Integration")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags)
    local msg = {
        From = processId,
        Target = processId,
        Action = action
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test counter
local testsRun = 0
local testsPassed = 0

-- Test 1: Shop disabled for DAILY
testsRun = testsRun + 1
print("\n📝 Test 1: DAILY shop disabled")
local response = sendMessage("GetShopStatus", {ModeId = "3"})
if response and response.ShopAvailable == "false" then
    print("✅ DAILY shop disabled")
    testsPassed = testsPassed + 1
else
    error("❌ DAILY shop disabled failed")
end

-- Test 2: Shop enabled for CLASSIC
testsRun = testsRun + 1
print("\n📝 Test 2: CLASSIC shop enabled")
response = sendMessage("GetShopStatus", {ModeId = "0"})
if response and response.ShopAvailable == "true" then
    print("✅ CLASSIC shop enabled")
    testsPassed = testsPassed + 1
else
    error("❌ CLASSIC shop enabled failed")
end

-- Test 3: Fixed battle at wave 5
testsRun = testsRun + 1
print("\n📝 Test 3: Fixed battle wave 5")
response = sendMessage("GetFixedBattleConfig", {ModeId = "0", WaveIndex = "5"})
if response and response.HasFixedBattle == "true" then
    print("✅ Fixed battle wave 5")
    testsPassed = testsPassed + 1
else
    error("❌ Fixed battle wave 5 failed")
end

-- Test 4: Mystery encounter waves for CLASSIC
testsRun = testsRun + 1
print("\n📝 Test 4: CLASSIC mystery waves [10, 180]")
response = sendMessage("GetMysteryEncounterWaves", {ModeId = "0"})
if response and response.MinWave == "10" and response.MaxWave == "180" then
    print("✅ CLASSIC mystery waves [10, 180]")
    testsPassed = testsPassed + 1
else
    error("❌ CLASSIC mystery waves failed")
end

-- Test 5: Starting parameters for DAILY
testsRun = testsRun + 1
print("\n📝 Test 5: DAILY starting level 20")
response = sendMessage("GetStartingParameters", {ModeId = "3"})
if response and response.StartingLevel == "20" then
    print("✅ DAILY starting level 20")
    testsPassed = testsPassed + 1
else
    error("❌ DAILY starting level failed")
end

-- Results summary
print("\n" .. string.rep("=", 50))
print("Tests run: " .. testsRun)
print("Tests passed: " .. testsPassed)
print("Tests failed: " .. (testsRun - testsPassed))

if testsPassed == testsRun then
    print("✅ All challenge integration tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
    return true
else
    print("❌ Some challenge integration tests failed!")
    return false
end
