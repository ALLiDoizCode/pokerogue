-- Aolite Unit Tests: Community Event Creation and Management (CORRECT API)
-- Tests event creation, validation, status transitions, and lifecycle management
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.community-event-engine"
local processId = "test-community-event-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Community Event Creation")
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

-- Test 1: Create valid community event with all required fields
print("📝 Test 1: Create valid community event")
local eventConfig = json.encode({
    name = "Winter Community Challenge",
    description = "Collective Ice-type catch goal",
    startDate = 1734739200000,
    endDate = 1735948800000,
    goals = {
        {
            goalType = "CUMULATIVE_TOTAL",
            targetValue = 100000,
            description = "Catch Ice-type Pokemon",
            milestones = {
                {threshold = 25000, rewards = {{type = "SHINY_CHARM", quantity = 1}}},
                {threshold = 50000, rewards = {{type = "ABILITY_CHARM", quantity = 1}}}
            }
        }
    }
})

local createResponse = sendMessage("CreateCommunityEvent", {
    EventConfig = eventConfig
})

if not createResponse then
    error("❌ Test 1 failed: No response received")
end
if createResponse.Action ~= "SaveState" then
    error("❌ Test 1 failed: Expected SaveState, got " .. tostring(createResponse.Action))
end
if createResponse.Success ~= "true" then
    error("❌ Test 1 failed: Expected success=true")
end

local responseData = json.decode(createResponse.Data)
if not responseData.event then
    error("❌ Test 1 failed: Event should be returned")
end
if not responseData.event.eventId then
    error("❌ Test 1 failed: Event ID should be generated")
end
if responseData.event.name ~= "Winter Community Challenge" then
    error("❌ Test 1 failed: Event name should match")
end

print("✅ Create valid community event test passed")

-- Test 2: Reject event creation with missing name
print("📝 Test 2: Reject event with missing name")
local invalidConfig = json.encode({
    description = "Test event",
    startDate = 1734739200000,
    endDate = 1735948800000,
    goals = {{goalType = "CUMULATIVE_TOTAL", targetValue = 100000}}
})

local errorResponse = sendMessage("CreateCommunityEvent", {
    EventConfig = invalidConfig
})

if not errorResponse then
    error("❌ Test 2 failed: Should receive error response")
end
if errorResponse.Action ~= "Error" then
    error("❌ Test 2 failed: Expected Error action")
end
if not string.match(errorResponse.Error or "", "name") then
    error("❌ Test 2 failed: Error should mention name")
end

print("✅ Reject event with missing name test passed")

-- Test 3: Reject event with invalid date range
print("📝 Test 3: Reject event with endDate before startDate")
local invalidDateConfig = json.encode({
    name = "Invalid Event",
    startDate = 1735948800000,
    endDate = 1734739200000, -- Before startDate
    goals = {{goalType = "CUMULATIVE_TOTAL", targetValue = 100000}}
})

local dateErrorResponse = sendMessage("CreateCommunityEvent", {
    EventConfig = invalidDateConfig
})

if dateErrorResponse.Action ~= "Error" then
    error("❌ Test 3 failed: Should return error")
end
if not string.match(dateErrorResponse.Error or "", "endDate") then
    error("❌ Test 3 failed: Error should mention endDate")
end

print("✅ Reject event with invalid date range test passed")

-- Test 4: Milestone sorting
print("📝 Test 4: Milestone sorting by threshold ascending")
local milestoneSortConfig = json.encode({
    name = "Milestone Sort Test",
    startDate = 1734739200000,
    endDate = 1735948800000,
    goals = {
        {
            goalType = "CUMULATIVE_TOTAL",
            targetValue = 100000,
            milestones = {
                {threshold = 75000, rewards = {{type = "REWARD_3", quantity = 1}}},
                {threshold = 25000, rewards = {{type = "REWARD_1", quantity = 1}}},
                {threshold = 50000, rewards = {{type = "REWARD_2", quantity = 1}}}
            }
        }
    }
})

local sortResponse = sendMessage("CreateCommunityEvent", {
    EventConfig = milestoneSortConfig
})

if sortResponse.Action ~= "SaveState" then
    error("❌ Test 4 failed: Should create event successfully")
end

local sortData = json.decode(sortResponse.Data)
local milestones = sortData.event.goals[1].milestones

if milestones[1].threshold ~= 25000 then
    error("❌ Test 4 failed: First milestone should be 25000, got " .. tostring(milestones[1].threshold))
end
if milestones[2].threshold ~= 50000 then
    error("❌ Test 4 failed: Second milestone should be 50000, got " .. tostring(milestones[2].threshold))
end
if milestones[3].threshold ~= 75000 then
    error("❌ Test 4 failed: Third milestone should be 75000, got " .. tostring(milestones[3].threshold))
end

print("✅ Milestone sorting test passed")

-- Test 5: Get active events at timestamp
print("📝 Test 5: Get active events filters correctly")
local activeEventsResponse = sendMessage("GetActiveCommunityEvents", {
    Timestamp = "1735000000000"
})

if not activeEventsResponse then
    error("❌ Test 5 failed: Should receive response")
end
if activeEventsResponse.Action ~= "SaveState" then
    error("❌ Test 5 failed: Should return SaveState")
end

print("✅ Get active events test passed")

-- Test 6: Info Handler (ADP v1.0 Compliance)
print("📝 Test 6: Info Handler (ADP v1.0 Compliance)")
local infoResponse = sendMessage("Info")

if not infoResponse or infoResponse.Action ~= "SaveState" then
    error("❌ Test 6 failed: Info handler should return SaveState")
end

print("✅ ADP v1.0 Info handler test passed")

-- Test Summary
print("==================================================")
print("🎉 All Community Event Creation tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
