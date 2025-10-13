-- Achievement Engine Unit Tests
-- Migrated to real aolite framework
-- Tests achievement validation, metadata queries, and progress tracking
-- Compatible with aolite testing framework (CORRECT API)

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.achievement-engine"
local processId = "test-achievement-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Achievement Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
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
local passed = 0
local failed = 0

print("\n==================================================")
print("📝 Test 1: Info handler (ADP v1.0)")
local info = sendMessage("Info")
if info and info.Action == "SaveState" and info.Data then
    print("✅ Test passed: Info handler responds with SaveState and data")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState action with data from Info handler")
end

print("\n==================================================")
print("📝 Test 2: ValidateAchievement - money achievement")
local validate = sendMessage("ValidateAchievement", {
    PlayerId = "player1",
    AchievementId = "_10K_MONEY",
    Args = json.encode({15000})
})
if validate and validate.Action == "AchievementValidated" and validate.Success == "true" then
    print("✅ Test passed: Money achievement validated successfully")
    passed = passed + 1
else
    error("❌ Test failed: Expected AchievementValidated with Success=true")
end

print("\n==================================================")
print("📝 Test 3: Error handling - missing PlayerId")
local noPlayer = sendMessage("ValidateAchievement", {
    AchievementId = "_10K_MONEY"
})
if noPlayer and noPlayer.Action == "Error" then
    print("✅ Test passed: Missing PlayerId returns Error")
    passed = passed + 1
else
    error("❌ Test failed: Expected Error action for missing PlayerId")
end

print("\n==================================================")
print("📝 Test 4: Error handling - missing AchievementId")
local noAchv = sendMessage("ValidateAchievement", {
    PlayerId = "player2"
})
if noAchv and noAchv.Action == "Error" then
    print("✅ Test passed: Missing AchievementId returns Error")
    passed = passed + 1
else
    error("❌ Test failed: Expected Error action for missing AchievementId")
end

print("\n==================================================")
print("📝 Test 5: Error handling - invalid achievement")
local invalidAchv = sendMessage("ValidateAchievement", {
    PlayerId = "player3",
    AchievementId = "INVALID_ACHIEVEMENT",
    Args = json.encode({})
})
if invalidAchv and invalidAchv.Action == "Error" then
    print("✅ Test passed: Invalid achievement returns Error")
    passed = passed + 1
else
    error("❌ Test failed: Expected Error action for invalid achievement")
end

print("\n==================================================")
print("📝 Test 6: ValidateAchievementsByType - batch validation")
local batch = sendMessage("ValidateAchievementsByType", {
    PlayerId = "player4",
    AchievementType = "DamageAchv",
    Args = json.encode({3000})
})
if batch and batch.Action == "AchievementsBatchValidated" then
    print("✅ Test passed: Batch validation responds correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected AchievementsBatchValidated action")
end

print("\n==================================================")
print("📝 Test 7: GetPlayerAchievements query")
local player = sendMessage("GetPlayerAchievements", {
    PlayerId = "player1",
    IncludeSecrets = "false"
})
if player and player.Action == "PlayerAchievementData" then
    print("✅ Test passed: Player achievements query succeeds")
    passed = passed + 1
else
    error("❌ Test failed: Expected PlayerAchievementData action")
end

print("\n==================================================")
print("📝 Test 8: GetAchievementMetadata query")
local metadata = sendMessage("GetAchievementMetadata")
if metadata and metadata.Action == "AchievementMetadata" then
    print("✅ Test passed: Metadata query succeeds")
    passed = passed + 1
else
    error("❌ Test failed: Expected AchievementMetadata action")
end

print("\n==================================================")
print("📝 Test 9: GetAchievementProgress - progress tracking")
local progress = sendMessage("GetAchievementProgress", {
    PlayerId = "player5",
    AchievementId = "_100_RIBBONS",
    CurrentValue = "75"
})
if progress and progress.Action == "AchievementProgress" then
    print("✅ Test passed: Progress tracking responds correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected AchievementProgress action")
end

print("\n==================================================")
print("📝 Test 10: ValidateAchievement - damage achievement")
local damageAchv = sendMessage("ValidateAchievement", {
    PlayerId = "player6",
    AchievementId = "_250_DMG",
    Args = json.encode({300})
})
if damageAchv and damageAchv.Action == "AchievementValidated" then
    print("✅ Test passed: Damage achievement validation works")
    passed = passed + 1
else
    error("❌ Test failed: Expected AchievementValidated for damage achievement")
end

print("\n==================================================")
print("🎉 All tests completed!")
print("==================================================")
print(string.format("✅ Passed: %d", passed))
print(string.format("❌ Failed: %d", failed))
print(string.format("📊 Total: %d", passed + failed))
print("==================================================")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
