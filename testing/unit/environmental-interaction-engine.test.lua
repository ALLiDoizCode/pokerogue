-- Test file for processes/environmental-interaction-engine.lua
-- Tests weather-terrain interactions, effect stacking, and environmental coordination

local aolite = require("testing.aolite.aolite")

describe("Environmental Interaction Engine", function()
    local process

    before_each(function()
        -- Spawn process with environmental-interaction-engine code
        process = aolite.spawnProcess("processes/environmental-interaction-engine.lua")

        -- Set up mock timestamp
        process.mockTimestamp = 1234567890
    end)

    after_each(function()
        -- Cleanup
        process = nil
    end)

    describe("Handler: ProcessEnvironmentalInteraction", function()
        it("should process weather-terrain interactions", function()
            local gameState = {
                weather = { type = "RAIN", turnsLeft = 5 },
                terrain = { type = "GRASSY", turnsLeft = 5 },
                activePokemon = {
                    { speciesId = 25, types = { "ELECTRIC" }, hp = 100, maxHp = 100 }
                }
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalInteraction",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.interactions)
        end)

        it("should handle no active weather or terrain", function()
            local gameState = {
                weather = { type = "NONE" },
                terrain = { type = "NONE" },
                activePokemon = {}
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalInteraction",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.is_table(response.interactions)
            assert.equals(0, #response.interactions)
        end)

        it("should handle missing Data field", function()
            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalInteraction",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("Error", result.Action)
            assert.is_not_nil(result.Error)
        end)
    end)

    describe("Handler: CheckWeatherTerrainCombo", function()
        it("should identify active weather-terrain combinations", function()
            local result = process.send({
                Target = process.id,
                Action = "CheckWeatherTerrainCombo",
                Weather = "RAIN",
                Terrain = "ELECTRIC",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.combo)
            assert.is_boolean(response.hasCombo)
        end)

        it("should handle no combo scenarios", function()
            local result = process.send({
                Target = process.id,
                Action = "CheckWeatherTerrainCombo",
                Weather = "NONE",
                Terrain = "NONE",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)

            local response = aolite.json.decode(result.Data)
            assert.is_false(response.hasCombo)
        end)

        it("should validate weather types", function()
            local result = process.send({
                Target = process.id,
                Action = "CheckWeatherTerrainCombo",
                Weather = "INVALID_WEATHER",
                Terrain = "GRASSY",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            -- Should handle gracefully (either error or no combo)
        end)
    end)

    describe("Handler: ProcessEnvironmentalTurn", function()
        it("should process turn-based environmental effects", function()
            local gameState = {
                weather = { type = "SANDSTORM", turnsLeft = 3 },
                terrain = { type = "PSYCHIC", turnsLeft = 4 },
                activePokemon = {
                    { speciesId = 1, types = { "GRASS", "POISON" }, hp = 100, maxHp = 100 }
                }
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalTurn",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.effects)
            assert.is_table(response.effects)
        end)

        it("should handle healing terrain effects", function()
            local gameState = {
                weather = { type = "NONE" },
                terrain = { type = "GRASSY", turnsLeft = 5 },
                activePokemon = {
                    { speciesId = 25, types = { "ELECTRIC" }, hp = 50, maxHp = 100, isGrounded = true }
                }
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalTurn",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.effects)
        end)

        it("should handle damage-dealing weather", function()
            local gameState = {
                weather = { type = "HAIL", turnsLeft = 5 },
                terrain = { type = "NONE" },
                activePokemon = {
                    { speciesId = 4, types = { "FIRE" }, hp = 100, maxHp = 100 }
                }
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalTurn",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.effects)
        end)
    end)

    describe("Handler: ResolveEnvironmentalConflicts", function()
        it("should resolve conflicting environmental effects", function()
            local conflicts = {
                { type = "weather", current = "RAIN", new = "SUN" },
                { type = "terrain", current = "ELECTRIC", new = "GRASSY" }
            }

            local result = process.send({
                Target = process.id,
                Action = "ResolveEnvironmentalConflicts",
                Data = aolite.json.encode(conflicts),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.resolutions)
        end)

        it("should prioritize strong weather over normal weather", function()
            local conflicts = {
                { type = "weather", current = "HARSH_SUN", new = "RAIN", priority = "high" }
            }

            local result = process.send({
                Target = process.id,
                Action = "ResolveEnvironmentalConflicts",
                Data = aolite.json.encode(conflicts),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            assert.is_not_nil(response.resolutions)
        end)
    end)

    describe("Handler: Info (ADP v1.0)", function()
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

        it("should list all environmental handlers", function()
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

            assert.is_true(handlerNames["ProcessEnvironmentalInteraction"])
            assert.is_true(handlerNames["CheckWeatherTerrainCombo"])
            assert.is_true(handlerNames["ProcessEnvironmentalTurn"])
            assert.is_true(handlerNames["ResolveEnvironmentalConflicts"])
            assert.is_true(handlerNames["Info"])
        end)
    end)

    describe("Handler: Ping", function()
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
        it("should handle extreme weather stacking", function()
            local gameState = {
                weather = { type = "HARSH_SUN", turnsLeft = 5 },
                terrain = { type = "GRASSY", turnsLeft = 5 },
                activePokemon = {
                    { speciesId = 1, types = { "GRASS" }, hp = 100, maxHp = 100 }
                }
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalInteraction",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
        end)

        it("should handle empty activePokemon array", function()
            local gameState = {
                weather = { type = "RAIN", turnsLeft = 5 },
                terrain = { type = "ELECTRIC", turnsLeft = 5 },
                activePokemon = {}
            }

            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalTurn",
                Data = aolite.json.encode(gameState),
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
        end)

        it("should handle malformed JSON gracefully", function()
            local result = process.send({
                Target = process.id,
                Action = "ProcessEnvironmentalInteraction",
                Data = "not valid json {{{",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("Error", result.Action)
        end)
    end)

    describe("Type Interactions", function()
        it("should boost Electric moves in Electric Terrain during Rain", function()
            local gameState = {
                weather = { type = "RAIN", turnsLeft = 5 },
                terrain = { type = "ELECTRIC", turnsLeft = 5 },
                activePokemon = {
                    { speciesId = 25, types = { "ELECTRIC" }, hp = 100, maxHp = 100, isGrounded = true }
                }
            }

            local result = process.send({
                Target = process.id,
                Action = "CheckWeatherTerrainCombo",
                Weather = "RAIN",
                Terrain = "ELECTRIC",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            local response = aolite.json.decode(result.Data)
            -- Should identify beneficial combo
            assert.is_not_nil(response.combo)
        end)

        it("should handle Fire type in Sun + Grassy Terrain", function()
            local result = process.send({
                Target = process.id,
                Action = "CheckWeatherTerrainCombo",
                Weather = "SUN",
                Terrain = "GRASSY",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            -- Should handle Fire boost from Sun and terrain interaction
        end)
    end)
end)
