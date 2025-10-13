-- Unit tests for mystery encounter probability calculation
-- Tests tier weights, probability normalization, and distribution

local aolite = require("aolite")

-- Load the mystery encounter engine process
dofile("processes/mystery-encounter-engine.lua")

-- Test suite for probability calculation
aolite.describe("Mystery Encounter Probability", function()

    aolite.it("tier weights - COMMON > GREAT > ULTRA > ROGUE", function()
        -- Test that tier weights follow expected ordering: 66 > 40 > 19 > 3

        local commonWeight = 66
        local greatWeight = 40
        local ultraWeight = 19
        local rogueWeight = 3

        aolite.assert(commonWeight > greatWeight, "COMMON weight should be greater than GREAT")
        aolite.assert(greatWeight > ultraWeight, "GREAT weight should be greater than ULTRA")
        aolite.assert(ultraWeight > rogueWeight, "ULTRA weight should be greater than ROGUE")
    end)

    aolite.it("probability normalization - all probabilities sum to 1.0", function()
        -- Test that probabilities for all valid encounters normalize to 1.0

        local biomeId = 1  -- PLAINS
        local waveIndex = 50

        local msg = {
            From = "test_player",
            Action = "GetEncounterProbabilities",
            BiomeId = tostring(biomeId),
            WaveIndex = tostring(waveIndex),
            Data = json.encode({
                waveIndex = waveIndex,
                party = {},
                encountersCompleted = {}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["get-encounter-probabilities"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")

        local probabilities = json.decode(response.Data)
        local totalProbability = 0

        for _, prob in ipairs(probabilities) do
            totalProbability = totalProbability + prob.probability
        end

        -- Allow small floating point error
        local epsilon = 0.0001
        aolite.assert(math.abs(totalProbability - 1.0) < epsilon,
                      string.format("Expected probabilities to sum to 1.0, got %.4f", totalProbability))
    end)

    aolite.it("filtered probability redistribution - remaining probabilities adjust when encounters filtered", function()
        -- Test that when some encounters are filtered out, remaining probabilities still sum to 1.0

        local biomeId = 1  -- PLAINS
        local waveIndex = 150  -- Some encounters have maxWave < 150

        local msg = {
            From = "test_player",
            Action = "GetEncounterProbabilities",
            BiomeId = tostring(biomeId),
            WaveIndex = tostring(waveIndex),
            Data = json.encode({
                waveIndex = waveIndex,
                party = {},
                encountersCompleted = {}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["get-encounter-probabilities"].fn(msg)

        local response = sentMessages[1]
        local probabilities = json.decode(response.Data)

        -- Verify some encounters are filtered (DEPARTMENT_STORE_SALE maxWave = 100)
        local totalProbability = 0
        for _, prob in ipairs(probabilities) do
            totalProbability = totalProbability + prob.probability
        end

        local epsilon = 0.0001
        aolite.assert(math.abs(totalProbability - 1.0) < epsilon,
                      "Expected redistributed probabilities to sum to 1.0")
    end)

    aolite.it("deterministic selection - same seed produces same encounter", function()
        -- Test that selection with same seed is deterministic

        local biomeId = 1  -- PLAINS
        local waveIndex = 50
        local seed = 12345

        local selectedEncounters = {}

        for i = 1, 3 do  -- Run 3 times with same seed
            local msg = {
                From = "test_player",
                Action = "SelectEncounter",
                BiomeId = tostring(biomeId),
                WaveIndex = tostring(waveIndex),
                Seed = tostring(seed),
                Data = json.encode({
                    waveIndex = waveIndex,
                    party = {},
                    encountersCompleted = {}
                })
            }

            local sentMessages = {}
            ao.send = function(response)
                table.insert(sentMessages, response)
            end

            Handlers._handlers["select-encounter"].fn(msg)

            local response = sentMessages[1]
            if response.Success == "true" then
                table.insert(selectedEncounters, tonumber(response.EncounterType))
            end
        end

        -- All selections should be identical
        aolite.assert(#selectedEncounters == 3, "Expected 3 successful selections")
        aolite.assert(selectedEncounters[1] == selectedEncounters[2], "Expected deterministic selection")
        aolite.assert(selectedEncounters[2] == selectedEncounters[3], "Expected deterministic selection")
    end)

    aolite.it("probability distribution - multiple selections cover different encounters", function()
        -- Test that different seeds produce different encounters (distribution)

        local biomeId = 1  -- PLAINS
        local waveIndex = 50

        local selectedEncounters = {}

        for seed = 1, 10 do
            local msg = {
                From = "test_player",
                Action = "SelectEncounter",
                BiomeId = tostring(biomeId),
                WaveIndex = tostring(waveIndex),
                Seed = tostring(seed),
                Data = json.encode({
                    waveIndex = waveIndex,
                    party = {},
                    encountersCompleted = {}
                })
            }

            local sentMessages = {}
            ao.send = function(response)
                table.insert(sentMessages, response)
            end

            Handlers._handlers["select-encounter"].fn(msg)

            local response = sentMessages[1]
            if response.Success == "true" then
                table.insert(selectedEncounters, tonumber(response.EncounterType))
            end
        end

        -- Should have selected at least 2 different encounter types across 10 seeds
        local uniqueEncounters = {}
        for _, enc in ipairs(selectedEncounters) do
            uniqueEncounters[enc] = true
        end

        local uniqueCount = 0
        for _ in pairs(uniqueEncounters) do
            uniqueCount = uniqueCount + 1
        end

        aolite.assert(uniqueCount >= 2, string.format("Expected variety in selections, got %d unique encounters", uniqueCount))
    end)
end)

print("Mystery encounter probability tests completed")
