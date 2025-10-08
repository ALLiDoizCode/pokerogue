-- ===================================================================
-- UNIT TESTS: Narrative Progress Validation
-- ===================================================================
-- Purpose: Test progress validation logic (frequency, progression, continuity)
-- Framework: aolite
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Test suite for progress validation
describe("Narrative Progress Validation", function()
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
    -- Test: Frequency Validation - Within Limits
    -- ===================================================================
    it("should validate frequency within limits", function()
        -- Record one encounter of type 1
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        -- Validate frequency (max 2 allowed)
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "20",
            ValidationType = "frequency",
            Data = json.encode({
                encounterType = 1,
                maxAllowed = 2
            })
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("true", response.Valid)  -- 1 < 2, valid
        assert.are.equal("50", response.ProgressPercentage)  -- 1/2 = 50%
    end)

    -- ===================================================================
    -- Test: Frequency Validation - At Limit
    -- ===================================================================
    it("should invalidate frequency at limit", function()
        -- Record two encounters of type 1
        for i = 1, 2 do
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

        -- Validate frequency (max 2 allowed)
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "30",
            ValidationType = "frequency",
            Data = json.encode({
                encounterType = 1,
                maxAllowed = 2
            })
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("false", response.Valid)  -- 2 >= 2, invalid
        assert.are.equal("100", response.ProgressPercentage)  -- 2/2 = 100%
    end)

    -- ===================================================================
    -- Test: Progression Validation - Ahead of Expected
    -- ===================================================================
    it("should validate progression when ahead of expected encounters", function()
        -- Record 5 encounters (expected: ~3 at wave 30)
        for i = 1, 5 do
            aolite.send({
                Target = processId,
                Action = "RecordEncounterCompletion",
                EncounterType = tostring(i),
                Tier = "0",
                WaveIndex = tostring(i * 5),
                SelectedOption = "0"
            })

            aolite.runScheduler()
        end

        -- Validate progression at wave 30
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "30",
            ValidationType = "progression",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("true", response.Valid)  -- 5 >= 3, valid
        local progressPct = tonumber(response.ProgressPercentage)
        assert.is_true(progressPct > 100)  -- Ahead of expected
    end)

    -- ===================================================================
    -- Test: Progression Validation - Behind Expected
    -- ===================================================================
    it("should invalidate progression when behind expected encounters", function()
        -- Record 1 encounter (expected: ~5 at wave 50)
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "1",
            Tier = "0",
            WaveIndex = "10",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        -- Validate progression at wave 50
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "50",
            ValidationType = "progression",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("false", response.Valid)  -- 1 < 5, invalid
        assert.are.equal("20", response.ProgressPercentage)  -- 1/5 = 20%
    end)

    -- ===================================================================
    -- Test: Continuity Validation - Valid State
    -- ===================================================================
    it("should validate continuity with valid state", function()
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "20",
            ValidationType = "continuity",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Valid)
        assert.are.equal("100", response.ProgressPercentage)  -- All checks pass
    end)

    -- ===================================================================
    -- Test: Continuity Validation After Spawn Chance Manipulation
    -- ===================================================================
    it("should maintain continuity after spawn chance adjustments", function()
        -- Adjust spawn chance within valid range
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "50"
        })

        aolite.runScheduler()

        -- Validate continuity
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "30",
            ValidationType = "continuity",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("true", response.Valid)
        assert.are.equal("100", response.ProgressPercentage)
    end)

    -- ===================================================================
    -- Test: Unknown Validation Type Returns Error
    -- ===================================================================
    it("should return error for unknown validation type", function()
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "20",
            ValidationType = "unknown_type",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "Unknown validation type"))
    end)

    -- ===================================================================
    -- Test: Validate Required Parameters
    -- ===================================================================
    it("should return error when required parameters missing", function()
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "20"
            -- ValidationType missing
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "required"))
    end)

    -- ===================================================================
    -- Test: Frequency Validation with Custom Max Allowed
    -- ===================================================================
    it("should respect custom maxAllowed in frequency validation", function()
        -- Record 3 encounters of type 1
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

        -- Validate with maxAllowed = 5
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

        assert.are.equal("true", response.Valid)  -- 3 < 5, valid
        assert.are.equal("60", response.ProgressPercentage)  -- 3/5 = 60%
    end)

    -- ===================================================================
    -- Test: Complex Multi-Part Encounter Tracking
    -- ===================================================================
    it("should track multi-part encounter with option selections", function()
        -- Record multi-part encounter (same type, different waves, different options)
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "10",
            Tier = "2",
            WaveIndex = "15",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "10",
            Tier = "2",
            WaveIndex = "25",
            SelectedOption = "1"
        })

        aolite.runScheduler()

        -- Validate frequency (should count both)
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "30",
            ValidationType = "frequency",
            Data = json.encode({
                encounterType = 10,
                maxAllowed = 3
            })
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        local result = json.decode(response.Data)
        assert.are.equal(2, result.currentCount)
        assert.are.equal(3, result.maxCount)
        assert.are.equal(true, result.valid)
    end)

    -- ===================================================================
    -- Test: Option Selection Persistence Validation
    -- ===================================================================
    it("should persist option selections across encounters", function()
        -- Record encounters with different option selections
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "5",
            Tier = "1",
            WaveIndex = "10",
            SelectedOption = "2"
        })

        aolite.runScheduler()

        -- Retrieve history and verify option persisted
        aolite.send({
            Target = processId,
            Action = "GetEncounterHistory"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        local history = json.decode(response.Data)
        assert.are.equal(1, #history)
        assert.are.equal(2, history[1].selectedOption)
    end)

    -- ===================================================================
    -- Test: Progression Validation at Wave 0
    -- ===================================================================
    it("should handle progression validation at wave 0", function()
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "0",
            ValidationType = "progression",
            Data = json.encode({})
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("true", response.Valid)  -- 0 >= 0, valid
    end)

    -- ===================================================================
    -- Test: Frequency Validation with Default Max Allowed
    -- ===================================================================
    it("should use default maxAllowed (2) when not specified", function()
        -- Record 1 encounter
        aolite.send({
            Target = processId,
            Action = "RecordEncounterCompletion",
            EncounterType = "7",
            Tier = "1",
            WaveIndex = "15",
            SelectedOption = "0"
        })

        aolite.runScheduler()

        -- Validate with default maxAllowed
        aolite.send({
            Target = processId,
            Action = "ValidateNarrativeProgress",
            CurrentWave = "20",
            ValidationType = "frequency",
            Data = json.encode({
                encounterType = 7
                -- maxAllowed not specified, should default to 2
            })
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        local result = json.decode(response.Data)
        assert.are.equal(2, result.maxCount)  -- Default value
        assert.are.equal(true, result.valid)
    end)
end)
