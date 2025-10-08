-- ===================================================================
-- UNIT TESTS: Narrative Queued Encounter Management
-- ===================================================================
-- Purpose: Test queued encounter operations (queue/dequeue/retrieve)
-- Framework: aolite
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Test suite for queued encounter management
describe("Narrative Queued Encounters", function()
    local processId

    -- Setup: Spawn process before each test
    before_each(function()
        processId = aolite.spawnProcess("processes/narrative-state-engine.lua")
    end)

    -- Cleanup: Clear messages after each test
    after_each(function()
        aolite.clearMessages()
    end)

    -- ===================================================================
    -- Test: Add Encounter to Queue
    -- ===================================================================
    it("should add encounter to queue with spawn percentage", function()
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "5",
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("1", response.QueuedCount)

        local queue = json.decode(response.Data)
        assert.are.equal(1, #queue)
        assert.are.equal(5, queue[1].type)
        assert.are.equal(75, queue[1].spawnPercent)
    end)

    -- ===================================================================
    -- Test: Add Multiple Encounters to Queue
    -- ===================================================================
    it("should add multiple encounters to queue", function()
        -- Queue first encounter
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "1",
            SpawnPercent = "50"
        })

        aolite.runScheduler()

        -- Queue second encounter
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "2",
            SpawnPercent = "100"
        })

        aolite.runScheduler()

        -- Queue third encounter
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "3",
            SpawnPercent = "25"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.QueuedCount)

        local queue = json.decode(response.Data)
        assert.are.equal(3, #queue)
    end)

    -- ===================================================================
    -- Test: Retrieve All Queued Encounters
    -- ===================================================================
    it("should retrieve all queued encounters", function()
        -- Queue two encounters
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "10",
            SpawnPercent = "60"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "20",
            SpawnPercent = "80"
        })

        aolite.runScheduler()

        -- Retrieve queue
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("2", response.QueuedCount)

        local queue = json.decode(response.Data)
        assert.are.equal(2, #queue)
        assert.are.equal(10, queue[1].type)
        assert.are.equal(20, queue[2].type)
    end)

    -- ===================================================================
    -- Test: Empty Queue Returns Empty Array
    -- ===================================================================
    it("should return empty array for empty queue", function()
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("0", response.QueuedCount)

        local queue = json.decode(response.Data)
        assert.are.equal(0, #queue)
    end)

    -- ===================================================================
    -- Test: Remove Specific Encounter from Queue
    -- ===================================================================
    it("should remove specific encounter from queue", function()
        -- Queue three encounters
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "1",
            SpawnPercent = "50"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "2",
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "3",
            SpawnPercent = "100"
        })

        aolite.runScheduler()

        -- Dequeue type 2
        aolite.send({
            Target = processId,
            Action = "DequeueEncounter",
            EncounterType = "2"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("2", response.RemainingQueued)

        local dequeuedEntry = json.decode(response.Data)
        assert.are.equal(2, dequeuedEntry.type)
        assert.are.equal(75, dequeuedEntry.spawnPercent)
    end)

    -- ===================================================================
    -- Test: Dequeue Non-Existent Encounter Returns Error
    -- ===================================================================
    it("should return error when dequeuing non-existent encounter", function()
        -- Queue one encounter
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "1",
            SpawnPercent = "50"
        })

        aolite.runScheduler()

        -- Try to dequeue different type
        aolite.send({
            Target = processId,
            Action = "DequeueEncounter",
            EncounterType = "99"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "not found"))
    end)

    -- ===================================================================
    -- Test: Queue Ordering (FIFO Validation)
    -- ===================================================================
    it("should maintain FIFO ordering in queue", function()
        -- Queue encounters in specific order
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "10",
            SpawnPercent = "10"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "20",
            SpawnPercent = "20"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "30",
            SpawnPercent = "30"
        })

        aolite.runScheduler()

        -- Retrieve queue
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        local queue = json.decode(response.Data)
        assert.are.equal(3, #queue)

        -- Verify FIFO order
        assert.are.equal(10, queue[1].type)
        assert.are.equal(20, queue[2].type)
        assert.are.equal(30, queue[3].type)
    end)

    -- ===================================================================
    -- Test: Dequeue Maintains Remaining Order
    -- ===================================================================
    it("should maintain order after dequeuing middle element", function()
        -- Queue three encounters
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "1",
            SpawnPercent = "10"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "2",
            SpawnPercent = "20"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "3",
            SpawnPercent = "30"
        })

        aolite.runScheduler()

        -- Dequeue middle element (type 2)
        aolite.send({
            Target = processId,
            Action = "DequeueEncounter",
            EncounterType = "2"
        })

        aolite.runScheduler()

        -- Retrieve remaining queue
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        local queue = json.decode(response.Data)
        assert.are.equal(2, #queue)
        assert.are.equal(1, queue[1].type)
        assert.are.equal(3, queue[2].type)
    end)

    -- ===================================================================
    -- Test: Validate Required Parameters for QueueEncounter
    -- ===================================================================
    it("should return error when QueueEncounter parameters missing", function()
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "1"
            -- SpawnPercent missing
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "required"))
    end)

    -- ===================================================================
    -- Test: Validate Required Parameters for DequeueEncounter
    -- ===================================================================
    it("should return error when DequeueEncounter EncounterType missing", function()
        aolite.send({
            Target = processId,
            Action = "DequeueEncounter"
            -- EncounterType missing
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "EncounterType"))
    end)

    -- ===================================================================
    -- Test: Queue Persistence Across Multiple Operations
    -- ===================================================================
    it("should persist queue across multiple operations", function()
        -- Queue encounter
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "1",
            SpawnPercent = "50"
        })

        aolite.runScheduler()

        -- Get summary (unrelated operation)
        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        -- Queue another encounter
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "2",
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        -- Retrieve queue
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("2", response.QueuedCount)

        local queue = json.decode(response.Data)
        assert.are.equal(2, #queue)
    end)

    -- ===================================================================
    -- Test: Duplicate Encounter Types Allowed in Queue
    -- ===================================================================
    it("should allow duplicate encounter types in queue", function()
        -- Queue same type twice with different spawn percentages
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "5",
            SpawnPercent = "50"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "5",
            SpawnPercent = "100"
        })

        aolite.runScheduler()

        -- Retrieve queue
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("2", response.QueuedCount)

        local queue = json.decode(response.Data)
        assert.are.equal(2, #queue)
        assert.are.equal(5, queue[1].type)
        assert.are.equal(5, queue[2].type)
        assert.are.equal(50, queue[1].spawnPercent)
        assert.are.equal(100, queue[2].spawnPercent)
    end)
end)
