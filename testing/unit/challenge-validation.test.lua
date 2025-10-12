-- Unit Tests: Challenge Validation and Unlock Conditions (CORRECT API)
-- Migrated to real aolite framework
-- Tests isUnlocked logic, condition functions, and unlock status validation

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.challenge-framework-engine"
local processId = "test-challenge-framework-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Challenge Validation")
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
print("📝 Test 1: Challenge with no conditions (always unlocked)")
local result1 = sendMessage("ValidateChallenge", {
    ChallengeId = "0"
}, "{}")
if result1 and result1.Action == "SaveState" and result1.Unlocked == "true" then
    print("✅ Test passed: Challenge with no conditions is unlocked")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true for challenge with no conditions")
end

print("\n==================================================")
print("📝 Test 2: Validate SINGLE_TYPE challenge")
local result2 = sendMessage("ValidateChallenge", {
    ChallengeId = "1"
}, "{}")
if result2 and result2.Unlocked == "true" then
    print("✅ Test passed: SINGLE_TYPE challenge validated")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true for SINGLE_TYPE")
end

print("\n==================================================")
print("📝 Test 3: Validate FRESH_START challenge")
local result3 = sendMessage("ValidateChallenge", {
    ChallengeId = "4"
}, "{}")
if result3 and result3.Unlocked == "true" then
    print("✅ Test passed: FRESH_START challenge validated")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true for FRESH_START")
end

print("\n==================================================")
print("📝 Test 4: Validate INVERSE_BATTLE challenge")
local result4 = sendMessage("ValidateChallenge", {
    ChallengeId = "5"
}, "{}")
if result4 and result4.Unlocked == "true" then
    print("✅ Test passed: INVERSE_BATTLE challenge validated")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true for INVERSE_BATTLE")
end

print("\n==================================================")
print("📝 Test 5: Validate HARDCORE challenge")
local result5 = sendMessage("ValidateChallenge", {
    ChallengeId = "9"
}, "{}")
if result5 and result5.Unlocked == "true" then
    print("✅ Test passed: HARDCORE challenge validated")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true for HARDCORE")
end

print("\n==================================================")
print("📝 Test 6: Validate with empty GameData")
local result6 = sendMessage("ValidateChallenge", {
    ChallengeId = "0"
}, "")
if result6 and result6.Unlocked == "true" then
    print("✅ Test passed: Empty GameData handled correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true with empty data")
end

print("\n==================================================")
print("📝 Test 7: Validate with complex GameData")
local gameData = json.encode({
    progression = {
        beatGame = true,
        unlockedAchievements = {1, 2, 3}
    }
})
local result7 = sendMessage("ValidateChallenge", {
    ChallengeId = "0"
}, gameData)
if result7 and result7.Unlocked == "true" then
    print("✅ Test passed: Complex GameData handled correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected Unlocked=true with complex data")
end

print("\n==================================================")
print("📝 Test 8: Error handling - missing ChallengeId")
local result8 = sendMessage("ValidateChallenge", {}, "{}")
if result8 and result8.Action == "Error" and result8.Error:find("ChallengeId required") then
    print("✅ Test passed: Missing ChallengeId returns error")
    passed = passed + 1
else
    error("❌ Test failed: Expected Error action for missing ChallengeId")
end

print("\n==================================================")
print("📝 Test 9: Error handling - invalid ChallengeId")
local result9 = sendMessage("ValidateChallenge", {
    ChallengeId = "999"
}, "{}")
if result9 and result9.Action == "Error" and result9.Error:find("not found") then
    print("✅ Test passed: Invalid ChallengeId returns error")
    passed = passed + 1
else
    error("❌ Test failed: Expected Error action for invalid ChallengeId")
end

print("\n==================================================")
print("📝 Test 10: Validate all 10 challenge types")
local allPassed = true
for i = 0, 9 do
    local result = sendMessage("ValidateChallenge", {
        ChallengeId = tostring(i)
    }, "{}")
    if not (result and result.Unlocked == "true") then
        allPassed = false
        print(string.format("❌ Challenge %d failed validation", i))
        break
    end
end
if allPassed then
    print("✅ Test passed: All 10 challenge types validated successfully")
    passed = passed + 1
else
    error("❌ Test failed: Not all challenge types validated")
end

print("\n==================================================")
print("🎉 All tests completed!")
print("==================================================")
print(string.format("✅ Passed: %d", passed))
print(string.format("❌ Failed: %d", failed))
print(string.format("📊 Total: %d", passed + failed))
print("==================================================")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
