-- ===================================================================
-- UNIT TESTS: Narrative Spawn Probability Management
-- ===================================================================
-- Purpose: Test spawn probability adjustment and clamping
-- Framework: aolite
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Test suite for spawn probability management
describe("Narrative Spawn Probability", function()
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
    -- Test: Initial Spawn Chance Matches BASE Weight
    -- ===================================================================
    it("should initialize spawn chance to BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT", function()
        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("3", response.SpawnChance)  -- BASE weight is 3
    end)

    -- ===================================================================
    -- Test: Positive Adjustment Increases Spawn Chance
    -- ===================================================================
    it("should increase spawn chance with positive adjustment", function()
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "5"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("SaveState", response.Action)
        assert.are.equal("true", response.Success)
        assert.are.equal("3", response.PreviousSpawnChance)
        assert.are.equal("8", response.NewSpawnChance)  -- 3 + 5 = 8
    end)

    -- ===================================================================
    -- Test: Negative Adjustment Decreases Spawn Chance
    -- ===================================================================
    it("should decrease spawn chance with negative adjustment", function()
        -- First increase to 10
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "7"
        })

        aolite.runScheduler()

        -- Then decrease by 3
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "-3"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("10", response.PreviousSpawnChance)
        assert.are.equal("7", response.NewSpawnChance)  -- 10 - 3 = 7
    end)

    -- ===================================================================
    -- Test: Spawn Chance Clamped to Minimum (0)
    -- ===================================================================
    it("should clamp spawn chance to minimum 0", function()
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "-10"  -- Would result in -7
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.PreviousSpawnChance)
        assert.are.equal("0", response.NewSpawnChance)  -- Clamped to 0
    end)

    -- ===================================================================
    -- Test: Spawn Chance Clamped to Maximum (256)
    -- ===================================================================
    it("should clamp spawn chance to maximum 256", function()
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "300"  -- Would result in 303
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.PreviousSpawnChance)
        assert.are.equal("256", response.NewSpawnChance)  -- Clamped to 256
    end)

    -- ===================================================================
    -- Test: Multiple Adjustments Accumulate Correctly
    -- ===================================================================
    it("should accumulate multiple adjustments correctly", function()
        -- Adjustment 1: +10
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "10"
        })

        aolite.runScheduler()

        -- Adjustment 2: +5
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "5"
        })

        aolite.runScheduler()

        -- Adjustment 3: -3
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "-3"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        -- Final: 3 + 10 + 5 - 3 = 15
        assert.are.equal("15", response.NewSpawnChance)
    end)

    -- ===================================================================
    -- Test: Zero Adjustment Does Not Change Spawn Chance
    -- ===================================================================
    it("should not change spawn chance with zero adjustment", function()
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "0"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.PreviousSpawnChance)
        assert.are.equal("3", response.NewSpawnChance)
    end)

    -- ===================================================================
    -- Test: Validate Required Parameters
    -- ===================================================================
    it("should return error when AdjustmentAmount missing", function()
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability"
            -- AdjustmentAmount missing
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("Error", response.Action)
        assert.is_not_nil(response.Error)
        assert.is_truthy(string.find(response.Error, "AdjustmentAmount"))
    end)

    -- ===================================================================
    -- Test: Spawn Probability Persists Across Calls
    -- ===================================================================
    it("should persist spawn probability across multiple calls", function()
        -- Adjustment 1
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "10"
        })

        aolite.runScheduler()

        -- Get summary
        aolite.send({
            Target = processId,
            Action = "GetNarrativeStateSummary"
        })

        aolite.runScheduler()

        -- Adjustment 2
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "5"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        -- Should be 13 + 5 = 18
        assert.are.equal("13", response.PreviousSpawnChance)
        assert.are.equal("18", response.NewSpawnChance)
    end)

    -- ===================================================================
    -- Test: Typical Missed Spawn Scenario (+1 increment)
    -- ===================================================================
    it("should handle typical missed spawn scenario with +1 increment", function()
        -- Simulate 5 missed spawns (WEIGHT_INCREMENT_ON_SPAWN_MISS = 1)
        for i = 1, 5 do
            aolite.send({
                Target = processId,
                Action = "UpdateSpawnProbability",
                AdjustmentAmount = "1"
            })

            aolite.runScheduler()
        end

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        -- 3 + (1 * 5) = 8
        assert.are.equal("8", response.NewSpawnChance)
    end)

    -- ===================================================================
    -- Test: Spawn Probability Reset After Successful Spawn
    -- ===================================================================
    it("should allow manual reset to base weight after successful spawn", function()
        -- Increase to 20
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "17"
        })

        aolite.runScheduler()

        -- Reset to base (3) by subtracting 17
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "-17"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("3", response.NewSpawnChance)
    end)

    -- ===================================================================
    -- Test: Large Positive Adjustment Clamped to Max
    -- ===================================================================
    it("should handle very large positive adjustments", function()
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
    -- Test: Large Negative Adjustment Clamped to Min
    -- ===================================================================
    it("should handle very large negative adjustments", function()
        aolite.send({
            Target = processId,
            Action = "UpdateSpawnProbability",
            AdjustmentAmount = "-1000"
        })

        aolite.runScheduler()

        local messages = aolite.getAllMsgs(processId)
        local response = messages[#messages]

        assert.are.equal("0", response.NewSpawnChance)
    end)
end)
