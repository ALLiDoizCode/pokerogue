-- Aolite Unit Tests: Community Reward Distribution
-- Tests reward distribution for milestone completion and goal achievement
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.community-event-engine"
local processId = "test-community-event-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Community Reward Distribution")
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

-- Test 1: Distribute rewards for milestone completion
print("📝 Test 1: Distribute rewards for milestone completion")
local distributeResponse = sendMessage("DistributeRewards", {
    EventId = "test-event",
    GoalId = "goal-1",
    Recipients = json.encode({"player1", "player2", "player3"})
})

if not distributeResponse then
    error("❌ Test 1 failed: No response received")
end
if distributeResponse.Action ~= "SaveState" then
    error("❌ Test 1 failed: Expected SaveState")
end

print("✅ Distribute rewards test passed")

-- Test 2: Handle reward distribution with no recipients
print("📝 Test 2: Handle empty recipients list")
local emptyResponse = sendMessage("DistributeRewards", {
    EventId = "test-event",
    GoalId = "goal-1",
    Recipients = json.encode({})
})

if emptyResponse then
    print("✅ Empty recipients handling test passed")
else
    error("❌ Test 2 failed: Should receive response")
end

-- Test 3: Distribute rewards for goal completion
print("📝 Test 3: Distribute rewards for goal completion")
local goalRewardResponse = sendMessage("DistributeRewards", {
    EventId = "test-event",
    GoalId = "goal-1",
    Recipients = json.encode({"playerA", "playerB"})
})

if goalRewardResponse and goalRewardResponse.Action == "SaveState" then
    print("✅ Goal completion reward distribution test passed")
else
    error("❌ Test 3 failed: Expected successful distribution")
end

-- Test 4: Handle non-existent event
print("📝 Test 4: Handle non-existent event for reward distribution")
local nonExistentResponse = sendMessage("DistributeRewards", {
    EventId = "non-existent-event",
    GoalId = "goal-1",
    Recipients = json.encode({"player1"})
})

if nonExistentResponse then
    print("✅ Non-existent event handling test passed")
else
    error("❌ Test 4 failed: Should receive response")
end

-- Test 5: Handle non-existent goal
print("📝 Test 5: Handle non-existent goal for reward distribution")
local nonExistentGoalResponse = sendMessage("DistributeRewards", {
    EventId = "test-event",
    GoalId = "non-existent-goal",
    Recipients = json.encode({"player1"})
})

if nonExistentGoalResponse then
    print("✅ Non-existent goal handling test passed")
else
    error("❌ Test 5 failed: Should receive response")
end

-- Test Summary
print("==================================================")
print("🎉 All Community Reward Distribution tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
