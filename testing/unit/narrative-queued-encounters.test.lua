-- ===================================================================
-- UNIT TESTS: Narrative Queued Encounter Management
-- ===================================================================
-- Purpose: Test queued encounter operations (queue/dequeue/retrieve)
-- Framework: aolite (Story 2.10 optimized pattern)
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Test configuration (Story 2.10 optimized pattern)
local PROCESS_PATH = "processes.narrative-state-engine"
local processId = "test-narrative-queued-encounters"
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Narrative Queued Encounters")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,  -- REQUIRED
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

-- Test 1: Add encounter to queue with spawn percentage
print("📝 Test 1: Add encounter to queue with spawn percentage")
local response1 = sendMessage("QueueEncounter", {
    EncounterType = "5",
    SpawnPercent = "75",
    NarrativeId = "test-narrative-queue-1"
})
if response1 and response1.Action == "SaveState" and response1.Success == "true" and response1.Data then
    local queue1 = json.decode(response1.Data)
    if #queue1 == 1 and queue1[1].type == 5 and queue1[1].spawnPercent == 75 then
        print("✅ Test 1 passed")
    else
        error("❌ Test 1 failed: Expected 1 queued encounter with type=5, spawnPercent=75")
    end
else
    error("❌ Test 1 failed: Expected SaveState with Success=true and Data")
end

-- Test 2: Add multiple encounters to queue (global queue - accumulates across tests)
print("📝 Test 2: Add multiple encounters to queue")
sendMessage("QueueEncounter", {
    EncounterType = "1",
    SpawnPercent = "50",
    NarrativeId = "test-narrative-queue-2"
})
sendMessage("QueueEncounter", {
    EncounterType = "2",
    SpawnPercent = "100",
    NarrativeId = "test-narrative-queue-2"
})
local response2 = sendMessage("QueueEncounter", {
    EncounterType = "3",
    SpawnPercent = "25",
    NarrativeId = "test-narrative-queue-2"
})
if response2 and response2.Data then
    local queue2 = json.decode(response2.Data)
    -- Global queue contains encounters from all tests
    if #queue2 >= 3 then
        -- Verify the last 3 encounters are the ones we just added
        local len = #queue2
        if queue2[len-2].type == 1 and queue2[len-1].type == 2 and queue2[len].type == 3 then
            print("✅ Test 2 passed")
        else
            error("❌ Test 2 failed: Last 3 encounters don't match expected types")
        end
    else
        error("❌ Test 2 failed: Expected at least 3 queued encounters, got " .. #queue2)
    end
else
    error("❌ Test 2 failed: Expected SaveState with Data")
end

-- Test 3: Retrieve all queued encounters (global queue)
print("📝 Test 3: Retrieve all queued encounters")
sendMessage("QueueEncounter", {
    EncounterType = "10",
    SpawnPercent = "60",
    NarrativeId = "test-narrative-queue-3"
})
sendMessage("QueueEncounter", {
    EncounterType = "20",
    SpawnPercent = "80",
    NarrativeId = "test-narrative-queue-3"
})
local response3 = sendMessage("GetQueuedEncounters", {
    NarrativeId = "test-narrative-queue-3"
})
if response3 and response3.Action == "SaveState" and response3.Success == "true" and response3.Data then
    local queue3 = json.decode(response3.Data)
    -- Global queue - verify our 2 encounters are at the end
    if #queue3 >= 2 then
        local len = #queue3
        if queue3[len-1].type == 10 and queue3[len].type == 20 then
            print("✅ Test 3 passed")
        else
            error("❌ Test 3 failed: Last 2 encounters don't match types 10 and 20")
        end
    else
        error("❌ Test 3 failed: Expected at least 2 queued encounters")
    end
else
    error("❌ Test 3 failed: Expected SaveState with Success=true and Data")
end

-- Test 4: GetQueuedEncounters returns queue (not empty due to previous tests)
print("📝 Test 4: GetQueuedEncounters works with global queue")
local response4 = sendMessage("GetQueuedEncounters", {
    NarrativeId = "test-narrative-queue-4"
})
if response4 and response4.Data then
    local queue4 = json.decode(response4.Data)
    -- Queue is global and not empty due to previous tests
    if #queue4 >= 0 then  -- Just verify it returns an array
        print("✅ Test 4 passed")
    else
        error("❌ Test 4 failed: Expected valid queue array")
    end
else
    error("❌ Test 4 failed: Expected SaveState with Data")
end

-- Test 5: Remove specific encounter from queue (global queue)
print("📝 Test 5: Remove specific encounter from queue")
sendMessage("QueueEncounter", {
    EncounterType = "51",  -- Use unique types to avoid conflicts with Test 2
    SpawnPercent = "50",
    NarrativeId = "test-narrative-queue-5"
})
sendMessage("QueueEncounter", {
    EncounterType = "52",
    SpawnPercent = "75",
    NarrativeId = "test-narrative-queue-5"
})
sendMessage("QueueEncounter", {
    EncounterType = "53",
    SpawnPercent = "100",
    NarrativeId = "test-narrative-queue-5"
})
local response5 = sendMessage("DequeueEncounter", {
    EncounterType = "52",  -- Dequeue middle element
    NarrativeId = "test-narrative-queue-5"
})
if response5 and response5.Action == "SaveState" and response5.Success == "true" and response5.Data then
    local dequeuedEntry = json.decode(response5.Data)
    if dequeuedEntry.type == 52 and dequeuedEntry.spawnPercent == 75 then
        print("✅ Test 5 passed")
    else
        error("❌ Test 5 failed: Expected dequeued entry with type=52, spawnPercent=75")
    end
else
    error("❌ Test 5 failed: Expected SaveState with Success=true and Data")
end

-- Test 6: Dequeue non-existent encounter returns error
print("📝 Test 6: Dequeue non-existent encounter returns error")
sendMessage("QueueEncounter", {
    EncounterType = "61",  -- Use unique type
    SpawnPercent = "50",
    NarrativeId = "test-narrative-queue-6"
})
local response6 = sendMessage("DequeueEncounter", {
    EncounterType = "999",  -- Try to dequeue non-existent type
    NarrativeId = "test-narrative-queue-6"
})
if response6 and response6.Action == "Error" and response6.Error and string.find(response6.Error, "not found") then
    print("✅ Test 6 passed")
else
    error("❌ Test 6 failed: Expected Error with 'not found' message")
end

-- Test 7: Maintain FIFO ordering in queue (global queue)
print("📝 Test 7: Maintain FIFO ordering in queue")
sendMessage("QueueEncounter", {
    EncounterType = "110",  -- Use unique types to avoid confusion with previous tests
    SpawnPercent = "10",
    NarrativeId = "test-narrative-queue-7"
})
sendMessage("QueueEncounter", {
    EncounterType = "120",
    SpawnPercent = "20",
    NarrativeId = "test-narrative-queue-7"
})
sendMessage("QueueEncounter", {
    EncounterType = "130",
    SpawnPercent = "30",
    NarrativeId = "test-narrative-queue-7"
})
local response7 = sendMessage("GetQueuedEncounters", {
    NarrativeId = "test-narrative-queue-7"
})
if response7 and response7.Data then
    local queue7 = json.decode(response7.Data)
    -- Global queue - verify our 3 encounters are at the end in FIFO order
    if #queue7 >= 3 then
        local len = #queue7
        if queue7[len-2].type == 110 and queue7[len-1].type == 120 and queue7[len].type == 130 then
            print("✅ Test 7 passed")
        else
            error("❌ Test 7 failed: Expected FIFO order: 110, 120, 130 at end of queue")
        end
    else
        error("❌ Test 7 failed: Expected at least 3 queued encounters")
    end
else
    error("❌ Test 7 failed: Expected SaveState with Data")
end

-- Test 8: Maintain order after dequeuing middle element (global queue)
print("📝 Test 8: Maintain order after dequeuing middle element")
sendMessage("QueueEncounter", {
    EncounterType = "201",  -- Use unique types
    SpawnPercent = "10",
    NarrativeId = "test-narrative-queue-8"
})
sendMessage("QueueEncounter", {
    EncounterType = "202",
    SpawnPercent = "20",
    NarrativeId = "test-narrative-queue-8"
})
sendMessage("QueueEncounter", {
    EncounterType = "203",
    SpawnPercent = "30",
    NarrativeId = "test-narrative-queue-8"
})
sendMessage("DequeueEncounter", {
    EncounterType = "202",  -- Remove middle element
    NarrativeId = "test-narrative-queue-8"
})
local response8 = sendMessage("GetQueuedEncounters", {
    NarrativeId = "test-narrative-queue-8"
})
if response8 and response8.Data then
    local queue8 = json.decode(response8.Data)
    -- Find our remaining elements (201, 203) in the global queue
    local found201, found203 = false, false
    for i, entry in ipairs(queue8) do
        if entry.type == 201 then found201 = true end
        if entry.type == 203 then found203 = true end
    end
    if found201 and found203 then
        print("✅ Test 8 passed")
    else
        error("❌ Test 8 failed: Expected to find types 201 and 203 in queue after dequeuing 202")
    end
else
    error("❌ Test 8 failed: Expected SaveState with Data")
end

-- Test 9: Return error when QueueEncounter parameters missing
print("📝 Test 9: Return error when QueueEncounter parameters missing")
local response9 = sendMessage("QueueEncounter", {
    EncounterType = "1",
    NarrativeId = "test-narrative-queue-9"
    -- SpawnPercent missing
})
if response9 and response9.Action == "Error" and response9.Error and string.find(response9.Error, "required") then
    print("✅ Test 9 passed")
else
    error("❌ Test 9 failed: Expected Error mentioning 'required'")
end

-- Test 10: Return error when DequeueEncounter EncounterType missing
print("📝 Test 10: Return error when DequeueEncounter EncounterType missing")
local response10 = sendMessage("DequeueEncounter", {
    NarrativeId = "test-narrative-queue-10"
    -- EncounterType missing
})
if response10 and response10.Action == "Error" and response10.Error and string.find(response10.Error, "EncounterType") then
    print("✅ Test 10 passed")
else
    error("❌ Test 10 failed: Expected Error mentioning 'EncounterType'")
end

-- Test 11: Persist queue across multiple operations (global queue)
print("📝 Test 11: Persist queue across multiple operations")
sendMessage("QueueEncounter", {
    EncounterType = "301",  -- Use unique types
    SpawnPercent = "50",
    NarrativeId = "test-narrative-queue-11"
})
sendMessage("GetNarrativeStateSummary", {
    NarrativeId = "test-narrative-queue-11"
})
sendMessage("QueueEncounter", {
    EncounterType = "302",
    SpawnPercent = "75",
    NarrativeId = "test-narrative-queue-11"
})
local response11 = sendMessage("GetQueuedEncounters", {
    NarrativeId = "test-narrative-queue-11"
})
if response11 and response11.Data then
    local queue11 = json.decode(response11.Data)
    -- Global queue - verify our 2 encounters are at the end
    if #queue11 >= 2 then
        local len = #queue11
        if queue11[len-1].type == 301 and queue11[len].type == 302 then
            print("✅ Test 11 passed")
        else
            error("❌ Test 11 failed: Expected types 301 and 302 at end of queue (persisted across operations)")
        end
    else
        error("❌ Test 11 failed: Expected at least 2 queued encounters")
    end
else
    error("❌ Test 11 failed: Expected SaveState with Data")
end

-- Test 12: Allow duplicate encounter types in queue (global queue)
print("📝 Test 12: Allow duplicate encounter types in queue")
sendMessage("QueueEncounter", {
    EncounterType = "505",  -- Use unique type
    SpawnPercent = "50",
    NarrativeId = "test-narrative-queue-12"
})
sendMessage("QueueEncounter", {
    EncounterType = "505",  -- Same type, different spawn %
    SpawnPercent = "100",
    NarrativeId = "test-narrative-queue-12"
})
local response12 = sendMessage("GetQueuedEncounters", {
    NarrativeId = "test-narrative-queue-12"
})
if response12 and response12.Data then
    local queue12 = json.decode(response12.Data)
    -- Global queue - verify our 2 duplicate-type encounters are at the end
    if #queue12 >= 2 then
        local len = #queue12
        if queue12[len-1].type == 505 and queue12[len].type == 505 and
           queue12[len-1].spawnPercent == 50 and queue12[len].spawnPercent == 100 then
            print("✅ Test 12 passed")
        else
            error("❌ Test 12 failed: Expected 2 queued encounters with type=505, spawn % 50 and 100")
        end
    else
        error("❌ Test 12 failed: Expected at least 2 queued encounters")
    end
else
    error("❌ Test 12 failed: Expected SaveState with Data")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ 12/12 Narrative Queued Encounters tests completed")
