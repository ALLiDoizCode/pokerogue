-- Unit tests for Game Mode Engine - Wave Detection Tests
-- Tests wave classification logic for all game modes

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.game-mode-engine"
local processId = "test-game-mode-wave-detection"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Game Mode Engine - Wave Detection")
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

-- Test 1: IsWaveFinal for CLASSIC (wave 200)
testsRun = testsRun + 1
print("\n📝 Test 1: CLASSIC final wave 200")
local response = sendMessage("IsWaveFinal", {ModeId = "0", WaveIndex = "200"})
if response and response.IsWaveFinal == "true" then
    print("✅ CLASSIC final wave 200")
    testsPassed = testsPassed + 1
else
    error("❌ CLASSIC final wave 200 failed")
end

-- Test 2: IsWaveFinal for ENDLESS (wave 250)
testsRun = testsRun + 1
print("\n📝 Test 2: ENDLESS final wave 250")
response = sendMessage("IsWaveFinal", {ModeId = "1", WaveIndex = "250"})
if response and response.IsWaveFinal == "true" then
    print("✅ ENDLESS final wave 250")
    testsPassed = testsPassed + 1
else
    error("❌ ENDLESS final wave 250 failed")
end

-- Test 3: IsWaveFinal for DAILY (wave 50)
testsRun = testsRun + 1
print("\n📝 Test 3: DAILY final wave 50")
response = sendMessage("IsWaveFinal", {ModeId = "3", WaveIndex = "50"})
if response and response.IsWaveFinal == "true" then
    print("✅ DAILY final wave 50")
    testsPassed = testsPassed + 1
else
    error("❌ DAILY final wave 50 failed")
end

-- Test 4: Boss wave detection (wave 10)
testsRun = testsRun + 1
print("\n📝 Test 4: Boss wave 10 detected")
response = sendMessage("GetWaveClassification", {ModeId = "0", WaveIndex = "10"})
if response and response.IsBoss == "true" then
    print("✅ Boss wave 10 detected")
    testsPassed = testsPassed + 1
else
    error("❌ Boss wave 10 failed")
end

-- Test 5: GetWaveForDifficulty DAILY
testsRun = testsRun + 1
print("\n📝 Test 5: DAILY difficulty calculation")
response = sendMessage("GetWaveForDifficulty", {ModeId = "3", WaveIndex = "10"})
if response and response.EffectiveDifficulty == "42" then
    print("✅ DAILY difficulty calculation")
    testsPassed = testsPassed + 1
else
    error("❌ DAILY difficulty failed")
end

-- Results summary
print("\n" .. string.rep("=", 50))
print("Tests run: " .. testsRun)
print("Tests passed: " .. testsPassed)
print("Tests failed: " .. (testsRun - testsPassed))

if testsPassed == testsRun then
    print("✅ All wave detection tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
    return true
else
    print("❌ Some wave detection tests failed!")
    return false
end
