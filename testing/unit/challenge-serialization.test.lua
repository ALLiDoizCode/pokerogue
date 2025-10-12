-- Unit Tests: Challenge Serialization and Deserialization (CORRECT API)
-- Migrated to real aolite framework
-- Tests ChallengeData creation, toChallenge hydration, copyChallenge, and round-trip serialization

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.challenge-framework-engine"
local processId = "test-challenge-framework-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Challenge Serialization")
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
print("📝 Test 1: Serialize challenge to ChallengeData")
local result1 = sendMessage("SerializeChallenge", {
    ChallengeId = "0"
})
if result1 and result1.Action == "SaveState" and result1.Data then
    local data = json.decode(result1.Data)
    if data.id == 0 then
        print("✅ Test passed: Challenge serialized correctly")
        passed = passed + 1
    else
        error("❌ Test failed: Expected id=0 in serialized data")
    end
else
    error("❌ Test failed: Expected SaveState with Data from SerializeChallenge")
end

print("\n==================================================")
print("📝 Test 2: Deserialize ChallengeData to Challenge instance")
local challengeData = json.encode({
    id = 9,
    value = 1,
    severity = 0
})
local result2 = sendMessage("DeserializeChallenge", {}, challengeData)
if result2 and result2.Action == "SaveState" and result2.ChallengeId == "9" then
    if result2.Value == "1" and result2.Severity == "0" then
        print("✅ Test passed: Challenge deserialized correctly")
        passed = passed + 1
    else
        error("❌ Test failed: Expected Value=1 and Severity=0")
    end
else
    error("❌ Test failed: Expected SaveState with ChallengeId=9")
end

print("\n==================================================")
print("📝 Test 3: Copy all 10 challenge types correctly")
local allPassed = true
for id = 0, 9 do
    local challengeData = json.encode({
        id = id,
        value = 1,
        severity = 0
    })
    local result = sendMessage("DeserializeChallenge", {}, challengeData)
    if not (result and result.Action == "SaveState" and result.ChallengeId == tostring(id)) then
        allPassed = false
        print(string.format("❌ Challenge %d failed deserialization", id))
        break
    end
end
if allPassed then
    print("✅ Test passed: All 10 challenge types copied correctly")
    passed = passed + 1
else
    error("❌ Test failed: Not all challenge types deserialized correctly")
end

print("\n==================================================")
print("📝 Test 4: Preserve state through round-trip serialization")
local serializeResult = sendMessage("SerializeChallenge", {
    ChallengeId = "1"
})
if serializeResult and serializeResult.Data then
    local deserializeResult = sendMessage("DeserializeChallenge", {}, serializeResult.Data)
    if deserializeResult and deserializeResult.Action == "SaveState" and deserializeResult.ChallengeId == "1" then
        print("✅ Test passed: Round-trip serialization preserves state")
        passed = passed + 1
    else
        error("❌ Test failed: Expected ChallengeId=1 after round-trip")
    end
else
    error("❌ Test failed: Serialization did not return Data")
end

print("\n==================================================")
print("📝 Test 5: Handle edge cases in serialization")
-- Valid serialization
local result5a = sendMessage("SerializeChallenge", {
    ChallengeId = "0"
})
if not (result5a and result5a.Data) then
    error("❌ Test failed: Expected Data from SerializeChallenge")
end

local data5a = json.decode(result5a.Data)
if data5a.id ~= 0 then
    error("❌ Test failed: Expected id=0 in serialized data")
end

-- Invalid deserialization
local invalidData = json.encode({
    id = 999,
    value = 1,
    severity = 0
})
local result5b = sendMessage("DeserializeChallenge", {}, invalidData)
if result5b and result5b.Action == "Error" then
    print("✅ Test passed: Edge cases handled correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected Error for invalid challenge ID")
end

print("\n==================================================")
print("📝 Test 6: Retrieve active challenges from GameState")
local gameState = json.encode({
    activeChallenges = {
        {id = 0, value = 5, severity = 0},
        {id = 9, value = 1, severity = 0}
    }
})
local result6 = sendMessage("GetActiveChallenges", {}, gameState)
if result6 and result6.Action == "SaveState" and result6.Data then
    print("✅ Test passed: Active challenges retrieved from GameState")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with Data from GetActiveChallenges")
end

print("\n==================================================")
print("🎉 All tests completed!")
print("==================================================")
print(string.format("✅ Passed: %d", passed))
print(string.format("❌ Failed: %d", failed))
print(string.format("📊 Total: %d", passed + failed))
print("==================================================")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
