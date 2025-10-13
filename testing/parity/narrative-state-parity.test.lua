-- ===================================================================
-- PARITY TESTS: Narrative State TypeScript Behavioral Comparison
-- ===================================================================
-- Purpose: Validate Lua implementation matches TypeScript behavior exactly
-- Framework: Mathematical proof approach (Story 19.1/19.2/19.3 pattern)
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Test suite for narrative state parity
describe("Narrative State Parity", function()
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
    -- PARITY: SeenEncounterData Structure
    -- ===================================================================
    it("should match TypeScript SeenEncounterData structure exactly", function()
        -- TypeScript: class SeenEncounterData { type, tier, waveIndex, selectedOption }
        -- Source: src/data/mystery-encounters/mystery-encounter-save-data.ts:6-18

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "5",
            Tier = "2",
            WaveIndex = "42",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local history = json.decode(response.Data)

        -- Validate structure matches TypeScript exactly
        assert.are.equal(1, #history)
        assert.are.equal(5, history[1].type)
        assert.are.equal(2, history[1].tier)
        assert.are.equal(42, history[1].waveIndex)
        assert.are.equal(1, history[1].selectedOption)

        -- Verify all fields present (no extra, no missing)
        local fieldCount = 0
        for _ in pairs(history[1]) do
            fieldCount = fieldCount + 1
        end
        assert.are.equal(4, fieldCount)
    end)

    -- ===================================================================
    -- PARITY: QueuedEncounter Structure
    -- ===================================================================
    it("should match TypeScript QueuedEncounter structure exactly", function()
        -- TypeScript: interface QueuedEncounter { type, spawnPercent }
        -- Source: src/data/mystery-encounters/mystery-encounter-save-data.ts:20-23

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "10",
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local queue = json.decode(response.Data)

        -- Validate structure matches TypeScript exactly
        assert.are.equal(1, #queue)
        assert.are.equal(10, queue[1].type)
        assert.are.equal(75, queue[1].spawnPercent)

        -- Verify all fields present (no extra, no missing)
        local fieldCount = 0
        for _ in pairs(queue[1]) do
            fieldCount = fieldCount + 1
        end
        assert.are.equal(2, fieldCount)
    end)

    -- ===================================================================
    -- PARITY: MysteryEncounterSaveData Structure
    -- ===================================================================
    it("should match TypeScript MysteryEncounterSaveData structure exactly", function()
        -- TypeScript: class MysteryEncounterSaveData {
        --   encounteredEvents, encounterSpawnChance, queuedEncounters
        -- }
        -- Source: src/data/mystery-encounters/mystery-encounter-save-data.ts:25-38

        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local state = json.decode(response.Data)

        -- Validate top-level structure
        assert.is_not_nil(state.encounteredEvents)
        assert.is_not_nil(state.encounterSpawnChance)
        assert.is_not_nil(state.queuedEncounters)

        -- Validate types
        assert.are.equal("table", type(state.encounteredEvents))
        assert.are.equal("number", type(state.encounterSpawnChance))
        assert.are.equal("table", type(state.queuedEncounters))
    end)

    -- ===================================================================
    -- PARITY: BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT Constant
    -- ===================================================================
    it("should initialize spawn chance to BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT (3)", function()
        -- TypeScript: BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT = 3
        -- Source: src/constants.ts:61

        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.SpawnChance)
    end)

    -- ===================================================================
    -- PARITY: Spawn Probability Clamping (0-256)
    -- ===================================================================
    it("should clamp spawn chance to MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT (256)", function()
        -- TypeScript: MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT = 256
        -- Source: src/constants.ts:60

        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "1000"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("256", response.NewSpawnChance)
    end)

    -- ===================================================================
    -- PARITY: Default SelectedOption (-1)
    -- ===================================================================
    it("should default selectedOption to -1 when not provided", function()
        -- TypeScript: selectedOption defaults to -1 if not set
        -- Source: mystery-encounter-save-data.ts:6-18

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10"
            -- SelectedOption omitted
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local history = json.decode(response.Data)

        assert.are.equal(-1, history[1].selectedOption)
    end)

    -- ===================================================================
    -- PARITY: Encounter History Filtering
    -- ===================================================================
    it("should filter encounter history by type like TypeScript", function()
        -- Record multiple encounter types
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
        local history = json.decode(response.Data)

        -- Should return only type 1 encounters
        assert.are.equal(2, #history)
        assert.are.equal(1, history[1].type)
        assert.are.equal(1, history[2].type)
    end)

    -- ===================================================================
    -- PARITY: Queue FIFO Ordering
    -- ===================================================================
    it("should maintain FIFO ordering like TypeScript array", function()
        -- Queue three encounters
        for i = 1, 3 do
            aolite.send({
                Target = processId,
                Action = "QueueEncounter",
                EncounterType = tostring(i * 10),
                SpawnPercent = tostring(i * 25)
            })

            aolite.runScheduler()
        end

        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local queue = json.decode(response.Data)

        -- Verify insertion order preserved (FIFO)
        assert.are.equal(3, #queue)
        assert.are.equal(10, queue[1].type)
        assert.are.equal(20, queue[2].type)
        assert.are.equal(30, queue[3].type)
    end)

    -- ===================================================================
    -- PARITY: Dequeue Removes First Match
    -- ===================================================================
    it("should remove first matching encounter from queue like TypeScript", function()
        -- Queue duplicate types
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
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        -- Dequeue should remove first match
        aolite.send({
            Target = processId,
            Action = "DequeueEncounter",
            EncounterType = "5"
        })

        aolite.runScheduler()

        -- Verify remaining queue has only second entry
        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local queue = json.decode(response.Data)

        assert.are.equal(1, #queue)
        assert.are.equal(75, queue[1].spawnPercent)  -- Second entry remains
    end)

    -- ===================================================================
    -- PARITY: Frequency Validation Counting
    -- ===================================================================
    it("should count encounter frequency like TypeScript", function()
        -- Record same type multiple times
        for i = 1, 3 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = "7",
                Tier = "1",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Validate frequency
        aolite.send({
            Target = processId,
            Action = "ValidateEncounterFrequency",
            EncounterType = "7",
            MaxAllowed = "2"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.CurrentCount)
        assert.are.equal("2", response.MaxCount)
        assert.are.equal("false", response.CanSpawn)  -- 3 >= 2
    end)

    -- ===================================================================
    -- PARITY: State Serialization/Deserialization
    -- ===================================================================
    it("should serialize state to JSON matching TypeScript", function()
        -- Record data
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
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "5"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "2",
            SpawnPercent = "50"
        })

        aolite.runScheduler()

        -- Get full state
        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]
        local state = json.decode(response.Data)

        -- Verify serialization integrity
        assert.are.equal(1, #state.encounteredEvents)
        assert.are.equal(8, state.encounterSpawnChance)  -- 3 + 5
        assert.are.equal(1, #state.queuedEncounters)

        -- Verify nested structure
        assert.are.equal(1, state.encounteredEvents[1].type)
        assert.are.equal(2, state.queuedEncounters[1].type)
    end)

    -- ===================================================================
    -- PARITY: Empty State Initialization
    -- ===================================================================
    it("should initialize empty state like TypeScript constructor", function()
        -- TypeScript: new MysteryEncounterSaveData() initializes empty arrays
        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("0", response.TotalEncounters)
        assert.are.equal("3", response.SpawnChance)
        assert.are.equal("0", response.QueuedCount)

        local state = json.decode(response.Data)
        assert.are.equal(0, #state.encounteredEvents)
        assert.are.equal(0, #state.queuedEncounters)
    end)

    -- ===================================================================
    -- MATHEMATICAL PROOF: Spawn Probability Accumulation
    -- ===================================================================
    it("should accumulate spawn probability adjustments deterministically", function()
        -- Mathematical proof: Verify exact calculation
        local adjustments = {10, -3, 5, -2, 8}
        local expectedFinal = 3  -- BASE

        for _, adj in ipairs(adjustments) do
            expectedFinal = expectedFinal + adj
            aolite.send({
                Target = processId,
                Action = "UpdateSpawnProbability",
                AdjustmentAmount = tostring(adj)
            })

            aolite.runScheduler()
        end

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        -- Verify final value matches mathematical proof
        assert.are.equal(tostring(expectedFinal), response.NewSpawnChance)
    end)

    -- ===================================================================
    -- MATHEMATICAL PROOF: Frequency Percentage Calculation
    -- ===================================================================
    it("should calculate frequency percentage exactly like TypeScript", function()
        -- Record 3 out of max 5
        for i = 1, 3 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = "1",
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "40",
            ValidationType = "frequency",
            Data = json.encode({
                encounterType = 1,
                maxAllowed = 5
            })
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        -- Mathematical proof: 3/5 * 100 = 60%
        assert.are.equal("60", response.ProgressPercentage)
    end)
end)
