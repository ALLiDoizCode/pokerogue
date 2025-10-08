-- ===================================================================
-- UNIT TESTS: Narrative Encounter History Tracking
-- ===================================================================
-- Purpose: Test encounter history recording and retrieval
-- Framework: Mock-based testing (Story 19.2/19.3 pattern)
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-narrative-state-engine",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers
local mockHandlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON
local mockJSON = {
    encode = function(t)
        if type(t) ~= "table" then
            return tostring(t)
        end
        -- Simple array check
        local isArray = #t > 0
        if isArray then
            local parts = {}
            for i, v in ipairs(t) do
                if type(v) == "table" then
                    table.insert(parts, mockJSON.encode(v))
                else
                    table.insert(parts, tostring(v))
                end
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        return "{...}"
    end,
    decode = function(str)
        return {}  -- Simplified for testing
    end
}

-- Set up global mocks
_G.ao = mockAO
_G.Handlers = mockHandlers
_G.json = mockJSON

-- Helper to clear test state
local function resetTestState()
    testMessages = {}
end

-- Helper to simulate sending a message
local function sendTestMessage(msg)
    resetTestState()
    local handler = testHandlers[msg.handlerName]
    if handler and handler.matcher(msg) then
        handler.handler(msg)
    end
end

-- Load the process
dofile("processes/narrative-state-engine.lua")

    -- ===================================================================
    -- Test: Record New Encounter Completion
    -- ===================================================================
    it("should record new encounter completion", function()
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.is_not_nil(response, "Should receive response")
        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("1", response.EncounterCount)

        local stateData = json.decode(response.Data)
        assert.are.equal(1, #stateData.encounteredEvents)
        assert.are.equal(1, stateData.encounteredEvents[1].type)
        assert.are.equal(0, stateData.encounteredEvents[1].tier)
        assert.are.equal(10, stateData.encounteredEvents[1].waveIndex)
        assert.are.equal(0, stateData.encounteredEvents[1].selectedOption)
    end)

    -- ===================================================================
    -- Test: Record Multiple Encounters
    -- ===================================================================
    it("should record multiple encounters sequentially", function()
        -- Record first encounter
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        -- Record second encounter
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "2",
            Tier = "1",
            WaveIndex = "20",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("2", response.EncounterCount)

        local stateData = json.decode(response.Data)
        assert.are.equal(2, #stateData.encounteredEvents)
    end)

    -- ===================================================================
    -- Test: Retrieve Full Encounter History
    -- ===================================================================
    it("should retrieve full encounter history", function()
        -- Record two encounters
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "2",
            Tier = "1",
            WaveIndex = "20",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        -- Retrieve history
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("2", response.HistoryCount)

        local history = json.decode(response.Data)
        assert.are.equal(2, #history)
    end)

    -- ===================================================================
    -- Test: Filter History by Encounter Type
    -- ===================================================================
    it("should filter history by encounter type", function()
        -- Record three encounters (two of type 1, one of type 2)
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "2",
            Tier = "1",
            WaveIndex = "20",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "30",
            SelectedOption = "2"
        })

        aolite.runScheduler()

        -- Filter by type 1
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory",
            EncounterType = "1"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("2", response.HistoryCount)

        local history = json.decode(response.Data)
        assert.are.equal(2, #history)
        assert.are.equal(1, history[1].type)
        assert.are.equal(1, history[2].type)
    end)

    -- ===================================================================
    -- Test: Empty History Returns Empty Array
    -- ===================================================================
    it("should return empty array for empty history", function()
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("0", response.HistoryCount)

        local history = json.decode(response.Data)
        assert.are.equal(0, #history)
    end)

    -- ===================================================================
    -- Test: Handle Missing SelectedOption (Default to -1)
    -- ===================================================================
    it("should default SelectedOption to -1 when not provided", function()
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10"
            -- SelectedOption omitted
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        local stateData = json.decode(response.Data)
        assert.are.equal(-1, stateData.encounteredEvents[1].selectedOption)
    end)

    -- ===================================================================
    -- Test: Validate Required Parameters
    -- ===================================================================
    it("should return error when required parameters missing", function()
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1"
            -- Tier and WaveIndex missing
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "required"))
    end)

    -- ===================================================================
    -- Test: History Persistence Across Multiple Calls
    -- ===================================================================
    it("should persist history across multiple handler calls", function()
        -- Record first encounter
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        -- Get history
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        -- Record second encounter
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "2",
            Tier = "1",
            WaveIndex = "20",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        -- Get history again
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("2", response.HistoryCount)

        local history = json.decode(response.Data)
        assert.are.equal(2, #history)
        assert.are.equal(1, history[1].type)
        assert.are.equal(2, history[2].type)
    end)

    -- ===================================================================
    -- Test: Duplicate Encounter Records (Idempotency Check)
    -- ===================================================================
    it("should allow duplicate encounter records (multiple encounters of same type)", function()
        -- Record same encounter type twice
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "30",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        -- Get history
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("2", response.HistoryCount)

        local history = json.decode(response.Data)
        assert.are.equal(2, #history)
        assert.are.equal(1, history[1].type)
        assert.are.equal(1, history[2].type)
        assert.are.equal(10, history[1].waveIndex)
        assert.are.equal(30, history[2].waveIndex)
    end)
end)
