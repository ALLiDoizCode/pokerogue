-- Unit tests for Game Mode Engine - Rewards Tests
-- Tests reward calculation for all game modes

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.game-mode-engine"
local processId = "test-game-mode-rewards"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Game Mode Engine - Rewards")
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

-- Test 1: Clear bonus for CLASSIC
testsRun = testsRun + 1
print("\n📝 Test 1: CLASSIC clear bonus 5000")
local response = sendMessage("GetModeRewards", {ModeId = "0"})
if response and response.ClearScoreBonus == "5000" then
    print("✅ CLASSIC clear bonus 5000")
    testsPassed = testsPassed + 1
else
    error("❌ CLASSIC clear bonus failed")
end

-- Test 2: Clear bonus for DAILY
testsRun = testsRun + 1
print("\n📝 Test 2: DAILY clear bonus 2500")
response = sendMessage("GetModeRewards", {ModeId = "3"})
if response and response.ClearScoreBonus == "2500" then
    print("✅ DAILY clear bonus 2500")
    testsPassed = testsPassed + 1
else
    error("❌ DAILY clear bonus failed")
end

-- Test 3: Enemy modifier chance CLASSIC non-boss
testsRun = testsRun + 1
print("\n📝 Test 3: CLASSIC non-boss modifier 18")
response = sendMessage("GetModeRewards", {ModeId = "0", IsBoss = "false"})
if response and response.EnemyModifierChance == "18" then
    print("✅ CLASSIC non-boss modifier 18")
    testsPassed = testsPassed + 1
else
    error("❌ CLASSIC non-boss modifier failed")
end

-- Test 4: Override species for DAILY final wave
testsRun = testsRun + 1
print("\n📝 Test 4: DAILY override species")
response = sendMessage("GetOverrideSpecies", {ModeId = "3", WaveIndex = "50"})
if response and response.HasOverride == "true" then
    print("✅ DAILY override species")
    testsPassed = testsPassed + 1
else
    error("❌ DAILY override species failed")
end

-- Results summary
print("\n" .. string.rep("=", 50))
print("Tests run: " .. testsRun)
print("Tests passed: " .. testsPassed)
print("Tests failed: " .. (testsRun - testsPassed))

if testsPassed == testsRun then
    print("✅ All rewards tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
    return true
else
    print("❌ Some rewards tests failed!")
    return false
end
