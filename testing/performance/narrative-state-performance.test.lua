-- ===================================================================
-- PERFORMANCE TESTS: Narrative State Engine Benchmarks
-- ===================================================================
-- Purpose: Validate execution time targets for all handlers
-- Framework: aolite with timing measurements
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Utility: Get current time in milliseconds
local function getCurrentTimeMs()
    return os.clock() * 1000
end

-- Test suite for performance benchmarks
describe("Narrative State Performance", function()
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
    -- BENCHMARK: RecordEncounterCompletion (<3ms)
    -- ===================================================================
    it("should complete RecordEncounterCompletion in <3ms", function()
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 3, "RecordEncounterCompletion took " .. tostring(executionTime) .. "ms (target: <3ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: GetEncounterHistory (<5ms)
    -- ===================================================================
    it("should complete GetEncounterHistory in <5ms", function()
        -- Pre-populate history with 10 encounters
        for i = 1, 10 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i),
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure retrieval time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 5, "GetEncounterHistory took " .. tostring(executionTime) .. "ms (target: <5ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: ValidateEncounterFrequency (<2ms)
    -- ===================================================================
    it("should complete ValidateEncounterFrequency in <2ms", function()
        -- Record some encounters
        for i = 1, 5 do
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

        -- Measure validation time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "ValidateEncounterFrequency",
            EncounterType = "1",
            MaxAllowed = "10"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 2, "ValidateEncounterFrequency took " .. tostring(executionTime) .. "ms (target: <2ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: UpdateSpawnProbability (<2ms)
    -- ===================================================================
    it("should complete UpdateSpawnProbability in <2ms", function()
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "10"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 2, "UpdateSpawnProbability took " .. tostring(executionTime) .. "ms (target: <2ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: QueueEncounter (<2ms)
    -- ===================================================================
    it("should complete QueueEncounter in <2ms", function()
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "5",
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 2, "QueueEncounter took " .. tostring(executionTime) .. "ms (target: <2ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: GetQueuedEncounters (<2ms)
    -- ===================================================================
    it("should complete GetQueuedEncounters in <2ms", function()
        -- Pre-populate queue with 10 encounters
        for i = 1, 10 do
            aolite.send({
                Target = processId,
                Action = "QueueEncounter",
                EncounterType = tostring(i),
                SpawnPercent = tostring(i * 10)
            })

            aolite.runScheduler()
        end

        -- Measure retrieval time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 2, "GetQueuedEncounters took " .. tostring(executionTime) .. "ms (target: <2ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: DequeueEncounter (<2ms)
    -- ===================================================================
    it("should complete DequeueEncounter in <2ms", function()
        -- Queue encounter first
        aolite.send({
            Target = processId,
            Action = "QueueEncounter",
            EncounterType = "5",
            SpawnPercent = "75"
        })

        aolite.runScheduler()

        -- Measure dequeue time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "DequeueEncounter",
            EncounterType = "5"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 2, "DequeueEncounter took " .. tostring(executionTime) .. "ms (target: <2ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: ValidateNarrativeProgress (<3ms)
    -- ===================================================================
    it("should complete ValidateNarrativeProgress in <3ms", function()
        -- Record some encounters
        for i = 1, 5 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i),
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure validation time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "50",
            ValidationType = "progression",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 3, "ValidateNarrativeProgress took " .. tostring(executionTime) .. "ms (target: <3ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: GetNarrativeStateSummary (<3ms)
    -- ===================================================================
    it("should complete GetNarrativeStateSummary in <3ms", function()
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 3, "GetNarrativeStateSummary took " .. tostring(executionTime) .. "ms (target: <3ms)")
    end)

    -- ===================================================================
    -- BENCHMARK: ResetNarrativeState (<3ms)
    -- ===================================================================
    it("should complete ResetNarrativeState in <3ms", function()
        -- Populate state first
        for i = 1, 10 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i),
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure reset time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "ResetNarrativeState",
            ResetType = "full",
            Confirmed = "true"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 3, "ResetNarrativeState took " .. tostring(executionTime) .. "ms (target: <3ms)")
    end)

    -- ===================================================================
    -- STRESS TEST: Batch Processing (100 history lookups in <500ms)
    -- ===================================================================
    it("should complete 100 history lookups in <500ms", function()
        -- Pre-populate history with 20 encounters
        for i = 1, 20 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(math.floor(i / 4) + 1),  -- 5 types
                Tier = "0",
                WaveIndex = tostring(i * 5),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure batch lookup time
        local startTime = getCurrentTimeMs()

        for i = 1, 100 do
            aolite.send({
                Target = processId,
                Action = "GetEncounterHistory"
            })

            aolite.runScheduler()
        end

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 500, "100 history lookups took " .. tostring(executionTime) .. "ms (target: <500ms)")
    end)

    -- ===================================================================
    -- STRESS TEST: Large History Performance
    -- ===================================================================
    it("should handle large encounter history efficiently", function()
        -- Record 50 encounters
        for i = 1, 50 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i % 10 + 1),
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure retrieval time for large history
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 10, "Large history retrieval took " .. tostring(executionTime) .. "ms (target: <10ms)")
    end)

    -- ===================================================================
    -- STRESS TEST: Large Queue Performance
    -- ===================================================================
    it("should handle large queued encounter list efficiently", function()
        -- Queue 50 encounters
        for i = 1, 50 do
            aolite.send({
                Target = processId,
                Action = "QueueEncounter",
                EncounterType = tostring(i),
                SpawnPercent = tostring((i % 4 + 1) * 25)
            })

            aolite.runScheduler()
        end

        -- Measure retrieval time for large queue
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "GetQueuedEncounters"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 10, "Large queue retrieval took " .. tostring(executionTime) .. "ms (target: <10ms)")
    end)

    -- ===================================================================
    -- STRESS TEST: Frequency Validation with Large History
    -- ===================================================================
    it("should validate frequency efficiently with large history", function()
        -- Record 100 encounters (mix of types)
        for i = 1, 100 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i % 5 + 1),
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure frequency validation time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "ValidateEncounterFrequency",
            EncounterType = "1",
            MaxAllowed = "50"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 5, "Frequency validation with large history took " .. tostring(executionTime) .. "ms (target: <5ms)")
    end)

    -- ===================================================================
    -- STRESS TEST: Filtered History Lookup Performance
    -- ===================================================================
    it("should filter history efficiently", function()
        -- Record 100 encounters (mix of types)
        for i = 1, 100 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i % 10 + 1),
                Tier = "0",
                WaveIndex = tostring(i * 10),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Measure filtered retrieval time
        local startTime = getCurrentTimeMs()

        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory",
            EncounterType = "5"
        })

        aolite.runScheduler()

        local endTime = getCurrentTimeMs()
        local executionTime = endTime - startTime

        assert.is_true(executionTime < 10, "Filtered history retrieval took " .. tostring(executionTime) .. "ms (target: <10ms)")
    end)
end)
