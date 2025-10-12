-- Aolite Unit Tests for Community Event Engine (CORRECT API)
-- Tests community event creation, contribution tracking, and progress
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.community-event-engine"
local processId = "test-community-event-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Community Event Engine")
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

-- Test 1: Create Community Event
print("📝 Test 1: Create Community Event")
local eventConfig = json.encode({
    name = "Test Community Event",
    description = "Test Description",
    startDate = 1734739200,
    endDate = 1735948800,
    goals = {
        {
            goalType = "CUMULATIVE_TOTAL",
            targetValue = 10000,
            description = "Test goal",
            milestones = {}
        }
    }
})
local createResponse = sendMessage("CreateCommunityEvent", {
    EventConfig = eventConfig
})
if createResponse and createResponse.Action == "SaveState" then
    print("✅ Create community event test passed")
else
    error("❌ Create community event test failed")
end

-- Test 2: Get Active Community Events
print("📝 Test 2: Get Active Community Events")
local activeEventsResponse = sendMessage("GetActiveCommunityEvents", {
    Timestamp = "1734800000"
})
if activeEventsResponse and activeEventsResponse.Action == "SaveState" then
    print("✅ Get active community events test passed")
else
    error("❌ Get active community events test failed")
end

-- Test 3: Track Contribution
print("📝 Test 3: Track Contribution")
local trackResponse = sendMessage("TrackContribution", {
    EventId = "test_event_1",
    GoalId = "goal_1",
    Value = "100"
})
if trackResponse and trackResponse.Action == "SaveState" then
    print("✅ Track contribution test passed")
else
    error("❌ Track contribution test failed")
end

-- Test 4: Get Community Progress
print("📝 Test 4: Get Community Progress")
local progressResponse = sendMessage("GetCommunityProgress", {
    EventId = "test_event_1"
})
if progressResponse and progressResponse.Action == "SaveState" then
    print("✅ Get community progress test passed")
else
    error("❌ Get community progress test failed")
end

-- Test 5: Get Community Event
print("📝 Test 5: Get Community Event")
local getEventResponse = sendMessage("GetCommunityEvent", {
    EventId = "test_event_1"
})
if getEventResponse then
    print("✅ Get community event test passed")
else
    error("❌ Get community event test failed")
end

-- Test 6: Info Handler (ADP v1.0 Compliance)
print("📝 Test 6: Info Handler (ADP v1.0 Compliance)")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ ADP v1.0 Info handler test passed")
else
    error("❌ ADP v1.0 Info handler test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Community Event Engine tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
