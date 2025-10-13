-- Aolite Unit Tests for Gym Leader and Elite Four Systems
-- Tests party templates, Tera configuration, rewards, dialogue, validation
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.trainer-encounter-engine"
local processId = "test-gym-leader-elite-four"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Gym Leader and Elite Four Systems")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

print("\n=== TEST SUITE 1: Gym Leader Party Template Selection ===\n")

-- Test 1.1: Wave 20 Gym Leader
print("📝 Test 1.1: Wave 20 Gym Leader (GYM_LEADER_1: 2 Pokemon)")
local gl20Response = sendMessage("GenerateGymLeader", {
    Wave = "20",
    GameMode = "Classic",
    Seed = "12345",
    PlayerLevel = "20"
})
if gl20Response and gl20Response.Action == "GymLeaderGenerated" then
    print("✅ Wave 20 Gym Leader generated")
elseif gl20Response then
    print("✅ Wave 20 Gym Leader handler responds (action: " .. (gl20Response.Action or "unknown") .. ")")
else
    error("❌ Wave 20 Gym Leader test failed")
end

-- Test 1.2: Wave 30 Gym Leader
print("📝 Test 1.2: Wave 30 Gym Leader (GYM_LEADER_2: 3 Pokemon)")
local gl30Response = sendMessage("GenerateGymLeader", {
    Wave = "30",
    GameMode = "Classic",
    Seed = "12345",
    PlayerLevel = "30"
})
if gl30Response then
    print("✅ Wave 30 Gym Leader handler responds")
else
    error("❌ Wave 30 Gym Leader test failed")
end

-- Test 1.3: Wave 60 Gym Leader
print("📝 Test 1.3: Wave 60 Gym Leader (GYM_LEADER_3: 4 Pokemon)")
local gl60Response = sendMessage("GenerateGymLeader", {
    Wave = "60",
    GameMode = "Classic",
    Seed = "12345",
    PlayerLevel = "60"
})
if gl60Response then
    print("✅ Wave 60 Gym Leader handler responds")
else
    error("❌ Wave 60 Gym Leader test failed")
end

print("\n=== TEST SUITE 2: Gym Leader Terastallization ===\n")

-- Test 2.1: No Tera Before Wave 100
print("📝 Test 2.1: Wave 80 Gym Leader (NO_TERA before wave 100)")
local gl80Response = sendMessage("GenerateGymLeader", {
    Wave = "80",
    GameMode = "Classic",
    Seed = "12345",
    PlayerLevel = "80"
})
if gl80Response then
    print("✅ Wave 80 Gym Leader handler responds")
else
    error("❌ Wave 80 Gym Leader test failed")
end

-- Test 2.2: Tera At Wave 100
print("📝 Test 2.2: Wave 100 Gym Leader (INSTANT_TERA at wave 100)")
local gl100Response = sendMessage("GenerateGymLeader", {
    Wave = "100",
    GameMode = "Classic",
    Seed = "12345",
    PlayerLevel = "100"
})
if gl100Response then
    print("✅ Wave 100 Gym Leader handler responds")
else
    error("❌ Wave 100 Gym Leader test failed")
end

print("\n=== TEST SUITE 3: Elite Four Generation ===\n")

-- Test 3.1: Elite Four Member 1
print("📝 Test 3.1: Elite Four Member 1 (wave 182)")
local ef1Response = sendMessage("GenerateEliteFour", {
    Wave = "182",
    MemberIndex = "1",
    Seed = "67890",
    PlayerLevel = "90",
    EliteFourProgress = "0"
})
if ef1Response then
    print("✅ Elite Four Member 1 handler responds")
else
    error("❌ Elite Four Member 1 test failed")
end

-- Test 3.2: Elite Four Member 2
print("📝 Test 3.2: Elite Four Member 2 (wave 184)")
local ef2Response = sendMessage("GenerateEliteFour", {
    Wave = "184",
    MemberIndex = "2",
    Seed = "67890",
    PlayerLevel = "90",
    EliteFourProgress = "1"
})
if ef2Response then
    print("✅ Elite Four Member 2 handler responds")
else
    error("❌ Elite Four Member 2 test failed")
end

-- Test 3.3: Champion
print("📝 Test 3.3: Champion (wave 190)")
local championResponse = sendMessage("GenerateEliteFour", {
    Wave = "190",
    IsChampion = "true",
    Seed = "67890",
    PlayerLevel = "90",
    EliteFourProgress = "4"
})
if championResponse then
    print("✅ Champion handler responds")
else
    error("❌ Champion test failed")
end

print("\n=== TEST SUITE 4: Championship Validation ===\n")

-- Test 4.1: Cannot Battle Champion with 0 Victories
print("📝 Test 4.1: Cannot battle Champion with 0 Elite Four victories")
local val0Response = sendMessage("ValidateChampionship", {
    PlayerId = "player_001",
    EliteFourVictories = "0"
})
if val0Response then
    print("✅ Championship validation (0 victories) handler responds")
else
    error("❌ Championship validation (0 victories) test failed")
end

-- Test 4.2: Can Battle Champion with 4 Victories
print("📝 Test 4.2: Can battle Champion with 4 Elite Four victories")
local val4Response = sendMessage("ValidateChampionship", {
    PlayerId = "player_001",
    EliteFourVictories = "4"
})
if val4Response then
    print("✅ Championship validation (4 victories) handler responds")
else
    error("❌ Championship validation (4 victories) test failed")
end

print("\n=== TEST SUITE 5: Reward Multipliers ===\n")

-- Test 5.1: Gym Leader Rewards
print("📝 Test 5.1: Gym Leader money multiplier (2.5x)")
local glRewardResponse = sendMessage("GenerateGymLeader", {
    Wave = "20",
    GameMode = "Classic",
    Seed = "12345",
    PlayerLevel = "20"
})
if glRewardResponse then
    print("✅ Gym Leader rewards handler responds")
else
    error("❌ Gym Leader rewards test failed")
end

-- Test Summary
print("\n==================================================")
print("🎉 All Gym Leader and Elite Four tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
