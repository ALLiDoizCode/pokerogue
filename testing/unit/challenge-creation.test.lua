-- Unit Tests: Challenge Creation and Modification (CORRECT API)
-- Migrated to real aolite framework
-- Tests challenge factory functions, value/severity bounds, and modification methods

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.challenge-framework-engine"
local processId = "test-challenge-framework-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Challenge Framework Engine")
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
print("📝 Test 1: SINGLE_GENERATION challenge creation")
local result1 = sendMessage("CreateChallenge", {
    ChallengeId = "0"
})
if result1 and result1.Action == "SaveState" and result1.ChallengeId == "0" then
    print("✅ Test passed: SINGLE_GENERATION challenge created")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with ChallengeId=0")
end

print("\n==================================================")
print("📝 Test 2: SINGLE_TYPE challenge creation")
local result2 = sendMessage("CreateChallenge", {
    ChallengeId = "1"
})
if result2 and result2.Action == "SaveState" and result2.ChallengeId == "1" then
    print("✅ Test passed: SINGLE_TYPE challenge created")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with ChallengeId=1")
end

print("\n==================================================")
print("📝 Test 3: FRESH_START challenge creation")
local result3 = sendMessage("CreateChallenge", {
    ChallengeId = "4"
})
if result3 and result3.Action == "SaveState" and result3.ChallengeId == "4" then
    print("✅ Test passed: FRESH_START challenge created")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with ChallengeId=4")
end

print("\n==================================================")
print("📝 Test 4: INVERSE_BATTLE challenge creation")
local result4 = sendMessage("CreateChallenge", {
    ChallengeId = "5"
})
if result4 and result4.Action == "SaveState" and result4.ChallengeId == "5" then
    print("✅ Test passed: INVERSE_BATTLE challenge created")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with ChallengeId=5")
end

print("\n==================================================")
print("📝 Test 5: HARDCORE challenge creation")
local result5 = sendMessage("CreateChallenge", {
    ChallengeId = "9"
})
if result5 and result5.Action == "SaveState" and result5.ChallengeId == "9" then
    print("✅ Test passed: HARDCORE challenge created")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with ChallengeId=9")
end

print("\n==================================================")
print("📝 Test 6: Create challenge with initial value")
local result6 = sendMessage("CreateChallenge", {
    ChallengeId = "0",
    Value = "5"
})
if result6 and result6.Action == "SaveState" and result6.Value == "5" then
    print("✅ Test passed: Challenge created with initial value")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState with Value=5")
end

print("\n==================================================")
print("📝 Test 7: IncreaseValue operation")
-- Create challenge first
sendMessage("CreateChallenge", {ChallengeId = "0"})
-- Increase value
local result7 = sendMessage("ModifyChallenge", {
    ChallengeId = "0",
    Operation = "IncreaseValue"
})
if result7 and result7.Modified == "true" and result7.Value == "1" then
    print("✅ Test passed: Value increased correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected Modified=true with Value=1")
end

print("\n==================================================")
print("📝 Test 8: Value bounds enforcement (at max)")
-- Increase to max value (9 times)
for i = 1, 9 do
    sendMessage("ModifyChallenge", {
        ChallengeId = "0",
        Operation = "IncreaseValue"
    })
end
-- Try to increase beyond max
local result8 = sendMessage("ModifyChallenge", {
    ChallengeId = "0",
    Operation = "IncreaseValue"
})
if result8 and result8.Modified == "false" and result8.Value == "9" then
    print("✅ Test passed: Value cannot exceed maxValue")
    passed = passed + 1
else
    error("❌ Test failed: Expected Modified=false with Value=9")
end

print("\n==================================================")
print("📝 Test 9: Reset operation")
local result9 = sendMessage("ModifyChallenge", {
    ChallengeId = "0",
    Operation = "Reset"
})
if result9 and result9.Modified == "true" and result9.Value == "0" then
    print("✅ Test passed: Challenge reset to default state")
    passed = passed + 1
else
    error("❌ Test failed: Expected Modified=true with Value=0")
end

print("\n==================================================")
print("📝 Test 10: DecreaseValue operation")
-- Set value to 5 first
sendMessage("ModifyChallenge", {ChallengeId = "0", Operation = "Reset"})
for i = 1, 5 do
    sendMessage("ModifyChallenge", {ChallengeId = "0", Operation = "IncreaseValue"})
end
-- Decrease value
local result10 = sendMessage("ModifyChallenge", {
    ChallengeId = "0",
    Operation = "DecreaseValue"
})
if result10 and result10.Modified == "true" and result10.Value == "4" then
    print("✅ Test passed: Value decreased correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected Modified=true with Value=4")
end

print("\n==================================================")
print("📝 Test 11: DecreaseValue at zero")
-- Reset to zero
sendMessage("ModifyChallenge", {ChallengeId = "0", Operation = "Reset"})
-- Try to decrease below zero
local result11 = sendMessage("ModifyChallenge", {
    ChallengeId = "0",
    Operation = "DecreaseValue"
})
if result11 and result11.Modified == "false" and result11.Value == "0" then
    print("✅ Test passed: Value cannot go below zero")
    passed = passed + 1
else
    error("❌ Test failed: Expected Modified=false with Value=0")
end

print("\n==================================================")
print("📝 Test 12: GetChallengeInfo handler")
local result12 = sendMessage("GetChallengeInfo", {
    ChallengeId = "0"
})
if result12 and result12.Action == "SaveState" then
    print("✅ Test passed: GetChallengeInfo returns data")
    passed = passed + 1
else
    error("❌ Test failed: Expected SaveState from GetChallengeInfo")
end

print("\n==================================================")
print("📝 Test 13: getRibbonAwarded for SINGLE_GENERATION")
local result13 = sendMessage("CreateChallenge", {
    ChallengeId = "0",
    Value = "3"
})
local ribbon = tonumber(result13.RibbonAwarded)
if result13 and ribbon == 4 then
    print("✅ Test passed: SINGLE_GENERATION ribbon calculated correctly")
    passed = passed + 1
else
    error("❌ Test failed: Expected RibbonAwarded=4 for Gen 3")
end

print("\n==================================================")
print("📝 Test 14: getRibbonAwarded for HARDCORE")
local result14 = sendMessage("CreateChallenge", {
    ChallengeId = "9",
    Value = "1"
})
if result14 and result14.RibbonAwarded == "65536" then
    print("✅ Test passed: HARDCORE ribbon is correct")
    passed = passed + 1
else
    error("❌ Test failed: Expected RibbonAwarded=65536 for HARDCORE")
end

print("\n==================================================")
print("📝 Test 15: getRibbonAwarded for value = 0")
local result15 = sendMessage("CreateChallenge", {
    ChallengeId = "0",
    Value = "0"
})
if result15 and result15.RibbonAwarded == "0" then
    print("✅ Test passed: Zero value returns zero ribbon")
    passed = passed + 1
else
    error("❌ Test failed: Expected RibbonAwarded=0 when value=0")
end

print("\n==================================================")
print("🎉 All tests completed!")
print("==================================================")
print(string.format("✅ Passed: %d", passed))
print(string.format("❌ Failed: %d", failed))
print(string.format("📊 Total: %d", passed + failed))
print("==================================================")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
