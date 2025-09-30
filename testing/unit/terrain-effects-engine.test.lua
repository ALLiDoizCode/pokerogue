-- Test file for processes/terrain-effects-engine.lua
-- Tests terrain type mechanics, move blocking, and type multipliers

local aolite = require("testing.aolite.aolite")

describe("Terrain Effects Engine", function()
    local process

    before_each(function()
        -- Spawn process with terrain-effects-engine code
        process = aolite.spawnProcess("processes/terrain-effects-engine.lua")

        -- Set up mock timestamp
        process.mockTimestamp = 1234567890
    end)

    after_each(function()
        -- Cleanup
        process = nil
    end)

    describe("Handler: set-terrain", function()
        it("should set Electric Terrain", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2", -- ELECTRIC = 2
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local response = aolite.json.decode(result.Data)
            assert.equals(2, response.terrain)
            assert.equals(5, response.turnsLeft)
            assert.is_true(response.isActive)
        end)

        it("should set Grassy Terrain", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "3", -- GRASSY = 3
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(3, response.terrain)
            assert.is_true(response.isActive)
        end)

        it("should set Misty Terrain", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "1", -- MISTY = 1
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(1, response.terrain)
            assert.is_true(response.isActive)
        end)

        it("should set Psychic Terrain", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "4", -- PSYCHIC = 4
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(4, response.terrain)
            assert.is_true(response.isActive)
        end)

        it("should handle missing TerrainType parameter", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("Error", result.Action)
            assert.is_not_nil(result.Error)
        end)

        it("should use default duration when not specified", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(5, response.turnsLeft) -- Default is 5
        end)
    end)

    describe("Handler: process-terrain-turn", function()
        it("should decrement terrain duration", function()
            -- First set terrain
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "3",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Process turn
            local result = process.send({
                Target = process.id,
                Action = "ProcessTerrainTurn",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.equals(2, response.turnsLeft) -- 3 - 1 = 2
            assert.is_true(response.isActive)
        end)

        it("should clear terrain when duration expires", function()
            -- Set terrain with 1 turn
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "1",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Process turn
            local result = process.send({
                Target = process.id,
                Action = "ProcessTerrainTurn",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(0, response.terrain) -- NONE
            assert.is_false(response.isActive)
        end)

        it("should handle turn processing with no active terrain", function()
            local result = process.send({
                Target = process.id,
                Action = "ProcessTerrainTurn",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.is_false(response.isActive)
        end)
    end)

    describe("Handler: clear-terrain", function()
        it("should clear active terrain", function()
            -- Set terrain first
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "3",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Clear terrain
            local result = process.send({
                Target = process.id,
                Action = "ClearTerrain",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.equals(0, response.terrain)
            assert.is_false(response.isActive)
        end)

        it("should handle clearing when no terrain is active", function()
            local result = process.send({
                Target = process.id,
                Action = "ClearTerrain",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
        end)
    end)

    describe("Handler: get-terrain-info", function()
        it("should return current terrain information", function()
            -- Set terrain
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Get info
            local result = process.send({
                Target = process.id,
                Action = "GetTerrainInfo",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.equals(2, response.terrain)
            assert.equals(5, response.turnsLeft)
            assert.is_true(response.isActive)
        end)

        it("should return NONE when no terrain is active", function()
            local result = process.send({
                Target = process.id,
                Action = "GetTerrainInfo",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(0, response.terrain)
            assert.is_false(response.isActive)
        end)
    end)

    describe("Handler: check-move-blocking", function()
        it("should check if Psychic Terrain blocks priority moves", function()
            -- Set Psychic Terrain
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "4",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Check move blocking
            local result = process.send({
                Target = process.id,
                Action = "CheckMoveBlocking",
                MoveId = "quick-attack",
                Priority = "1",
                IsGrounded = "true",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.blocked)
        end)

        it("should not block moves on non-grounded Pokemon", function()
            -- Set Psychic Terrain
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "4",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Check for flying/levitating Pokemon
            local result = process.send({
                Target = process.id,
                Action = "CheckMoveBlocking",
                MoveId = "quick-attack",
                Priority = "1",
                IsGrounded = "false",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_false(response.blocked)
        end)

        it("should not block non-priority moves", function()
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "4",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local result = process.send({
                Target = process.id,
                Action = "CheckMoveBlocking",
                MoveId = "tackle",
                Priority = "0",
                IsGrounded = "true",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_false(response.blocked)
        end)
    end)

    describe("Handler: calculate-type-multiplier", function()
        it("should boost Electric moves in Electric Terrain", function()
            -- Set Electric Terrain
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Calculate multiplier for Electric move
            local result = process.send({
                Target = process.id,
                Action = "CalculateTypeMultiplier",
                MoveType = "12", -- ELECTRIC = 12
                IsGrounded = "true",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.is_true(response.multiplier > 1.0) -- Should be boosted (1.3x typically)
        end)

        it("should boost Grass moves in Grassy Terrain", function()
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "3",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local result = process.send({
                Target = process.id,
                Action = "CalculateTypeMultiplier",
                MoveType = "11", -- GRASS = 11
                IsGrounded = "true",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_true(response.multiplier > 1.0)
        end)

        it("should boost Psychic moves in Psychic Terrain", function()
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "4",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local result = process.send({
                Target = process.id,
                Action = "CalculateTypeMultiplier",
                MoveType = "13", -- PSYCHIC = 13
                IsGrounded = "true",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_true(response.multiplier > 1.0)
        end)

        it("should not boost non-matching types", function()
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2", -- Electric Terrain
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local result = process.send({
                Target = process.id,
                Action = "CalculateTypeMultiplier",
                MoveType = "9", -- FIRE = 9
                IsGrounded = "true",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(1.0, response.multiplier) -- No boost
        end)

        it("should not boost moves for non-grounded Pokemon", function()
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local result = process.send({
                Target = process.id,
                Action = "CalculateTypeMultiplier",
                MoveType = "12", -- ELECTRIC
                IsGrounded = "false",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(1.0, response.multiplier) -- No boost for flying Pokemon
        end)
    end)

    describe("Handler: info (ADP v1.0)", function()
        it("should return process information with ADP compliance", function()
            local result = process.send({
                Target = process.id,
                Action = "Info",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local info = aolite.json.decode(result.Data)
            assert.is_not_nil(info.process)
            assert.equals("1.0", info.process.adpVersion)
            assert.is_not_nil(info.handlers)
            assert.is_table(info.handlers)
        end)

        it("should list all terrain handlers", function()
            local result = process.send({
                Target = process.id,
                Action = "Info",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local info = aolite.json.decode(result.Data)
            local handlerNames = {}
            for _, handler in ipairs(info.handlers) do
                handlerNames[handler] = true
            end

            assert.is_true(handlerNames["SetTerrain"])
            assert.is_true(handlerNames["ProcessTerrainTurn"])
            assert.is_true(handlerNames["ClearTerrain"])
            assert.is_true(handlerNames["GetTerrainInfo"])
            assert.is_true(handlerNames["CheckMoveBlocking"])
            assert.is_true(handlerNames["CalculateTypeMultiplier"])
            assert.is_true(handlerNames["Info"])
        end)
    end)

    describe("Handler: ping", function()
        it("should respond to ping requests", function()
            local result = process.send({
                Target = process.id,
                Action = "Ping",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("Pong", result.Action)
        end)
    end)

    describe("Edge Cases", function()
        it("should handle rapid terrain switching", function()
            -- Set Electric Terrain
            process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            -- Immediately switch to Grassy Terrain
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "3",
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 1
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.equals(3, response.terrain) -- Should be Grassy now
        end)

        it("should handle invalid terrain type gracefully", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "99", -- Invalid type
                Duration = "5",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            -- Should handle gracefully (error or default to NONE)
        end)

        it("should handle zero duration", function()
            local result = process.send({
                Target = process.id,
                Action = "SetTerrain",
                TerrainType = "2",
                Duration = "0",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            -- Should either reject or immediately clear
        end)
    end)

    describe("Terrain Interactions", function()
        it("should handle all four terrain types in sequence", function()
            local terrains = { "1", "2", "3", "4" } -- Misty, Electric, Grassy, Psychic

            for _, terrainType in ipairs(terrains) do
                local result = process.send({
                    Target = process.id,
                    Action = "SetTerrain",
                    TerrainType = terrainType,
                    Duration = "5",
                    From = "test-sender",
                    Timestamp = process.mockTimestamp
                })

                assert.is_not_nil(result)
                assert.equals("SaveState", result.Action)

                local response = aolite.json.decode(result.Data)
                assert.equals(tonumber(terrainType), response.terrain)
            end
        end)
    end)
end)
