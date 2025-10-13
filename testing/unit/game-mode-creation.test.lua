-- Unit tests for Game Mode Engine - Creation Tests
-- Tests game mode factory functions

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.game-mode-engine"
local processId = "test-game-mode-creation-v2"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Game Mode Engine - Creation")
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

-- Test 0: Try GetModeRewards (also uses getGameMode)
testsRun = testsRun + 1
print("\n📝 Test 0: GetModeRewards for CLASSIC (also uses getGameMode)")
local response = sendMessage("GetModeRewards", {ModeId = "0"})
print("DEBUG GetModeRewards: response.Action =", response and response.Action or "nil")
print("DEBUG GetModeRewards: response.ClearScoreBonus =", response and response.ClearScoreBonus or "nil")
if response and response.ClearScoreBonus == "5000" then
    print("✅ GetModeRewards works!")
    testsPassed = testsPassed + 1
else
    error("❌ GetModeRewards failed - getGameMode() issue confirmed")
end

-- Test 1: Create CLASSIC mode
testsRun = testsRun + 1
print("\n📝 Test 1: Create CLASSIC mode (ModeId = 0)")
response = sendMessage("CreateGameMode", {ModeId = "0"})
if response and response.Action == "SaveState" and response.Data then
    print("✅ CLASSIC mode created")
    testsPassed = testsPassed + 1
else
    error("❌ CreateGameMode failed for CLASSIC")
end

-- Test 2: Create ENDLESS mode
testsRun = testsRun + 1
print("\n📝 Test 2: Create ENDLESS mode (ModeId = 1)")
response = sendMessage("CreateGameMode", {ModeId = "1"})
if response and response.Action == "SaveState" and response.Data then
    print("✅ ENDLESS mode created")
    testsPassed = testsPassed + 1
else
    error("❌ CreateGameMode failed for ENDLESS")
end

-- Test 3: Create DAILY mode
testsRun = testsRun + 1
print("\n📝 Test 3: Create DAILY mode (ModeId = 3)")
response = sendMessage("CreateGameMode", {ModeId = "3"})
if response and response.Action == "SaveState" and response.Data then
    print("✅ DAILY mode created")
    testsPassed = testsPassed + 1
else
    error("❌ CreateGameMode failed for DAILY")
end

-- Test 4: Invalid ModeId
testsRun = testsRun + 1
print("\n📝 Test 4: Invalid ModeId rejection")
response = sendMessage("CreateGameMode", {ModeId = "99"})
if response and response.Action == "Error" then
    print("✅ Invalid ModeId rejected")
    testsPassed = testsPassed + 1
else
    error("❌ Should reject invalid ModeId")
end

-- Test 5: GetGameModeInfo
testsRun = testsRun + 1
print("\n📝 Test 5: GetGameModeInfo for all modes")
response = sendMessage("GetGameModeInfo", {})
if response and response.Action == "SaveState" and response.Data then
    print("✅ GetGameModeInfo returned data")
    testsPassed = testsPassed + 1
else
    error("❌ GetGameModeInfo failed")
end

-- Results summary
print("\n" .. string.rep("=", 50))
print("Tests run: " .. testsRun)
print("Tests passed: " .. testsPassed)
print("Tests failed: " .. (testsRun - testsPassed))

if testsPassed == testsRun then
    print("✅ All game mode creation tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
    return true
else
    print("❌ Some game mode creation tests failed!")
    return false
end
