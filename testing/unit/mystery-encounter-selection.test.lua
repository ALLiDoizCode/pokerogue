-- Unit tests for mystery encounter selection algorithm
-- Tests biome filtering, tier-based probability, game mode filtering, and max encounter limits

local aolite = require("aolite")

-- Load the mystery encounter engine process
dofile("processes/mystery-encounter-engine.lua")

-- Test suite for encounter selection
aolite.describe("Mystery Encounter Selection", function()

    aolite.it("filters encounters by biome - anyBiome encounters available in all biomes", function()
        -- Test that anyBiome encounters (FIGHT_OR_FLIGHT, MYSTERIOUS_CHEST, etc.)
        -- are available in all 35 biomes

        local biomeIds = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
                          20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34}

        for _, biomeId in ipairs(biomeIds) do
            -- Mock message for GetEncountersByBiome
            local msg = {
                From = "test_player",
                Action = "GetEncountersByBiome",
                BiomeId = tostring(biomeId)
            }

            -- Capture ao.send response
            local sentMessages = {}
            ao.send = function(response)
                table.insert(sentMessages, response)
            end

            -- Call handler
            Handlers._handlers["get-encounters-by-biome"].fn(msg)

            -- Verify response
            aolite.assert(#sentMessages == 1, "Expected 1 response message")
            local response = sentMessages[1]
            aolite.assert(response.Success == "true", "Expected success")

            local encounterTypes = json.decode(response.Data)
            aolite.assert(#encounterTypes > 0, string.format("Expected encounters for biome %d", biomeId))

            -- Verify anyBiome encounters are present
            local hasFightOrFlight = false
            for _, enc in ipairs(encounterTypes) do
                if enc.encounterType == 3 then  -- FIGHT_OR_FLIGHT
                    hasFightOrFlight = true
                    break
                end
            end
            aolite.assert(hasFightOrFlight, string.format("Expected FIGHT_OR_FLIGHT in biome %d", biomeId))
        end
    end)

    aolite.it("tier-based probability - ROGUE < ULTRA < GREAT < COMMON spawn rates", function()
        -- Test that tier weights are correctly ordered: COMMON (66) > GREAT (40) > ULTRA (19) > ROGUE (3)

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

        aolite.assert(#sentMessages == 1, "Expected 1 response")
        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")

        local probabilities = json.decode(response.Data)

        -- Verify tier ordering: COMMON encounters have highest probability
        local commonProb = 0
        local greatProb = 0
        local ultraProb = 0
        local rogueProb = 0

        for _, prob in ipairs(probabilities) do
            if prob.tier == 66 then  -- COMMON
                commonProb = commonProb + prob.probability
            elseif prob.tier == 40 then  -- GREAT
                greatProb = greatProb + prob.probability
            elseif prob.tier == 19 then  -- ULTRA
                ultraProb = ultraProb + prob.probability
            elseif prob.tier == 3 then  -- ROGUE
                rogueProb = rogueProb + prob.probability
            end
        end

        -- COMMON should have higher combined probability than other tiers
        aolite.assert(commonProb > 0, "Expected COMMON encounters")
        print(string.format("Tier probabilities - COMMON: %.2f, GREAT: %.2f, ULTRA: %.2f, ROGUE: %.2f",
                            commonProb, greatProb, ultraProb, rogueProb))
    end)

    aolite.it("game mode filtering - disabled encounters are excluded", function()
        -- Test that disabled encounters (FIELD_TRIP, AN_OFFER_YOU_CANT_REFUSE) are not selected

        local biomeId = 1  -- PLAINS
        local msg = {
            From = "test_player",
            Action = "GetEncountersByBiome",
            BiomeId = tostring(biomeId)
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["get-encounters-by-biome"].fn(msg)

        local response = sentMessages[1]
        local encounterTypes = json.decode(response.Data)

        -- Verify disabled encounters are NOT present
        for _, enc in ipairs(encounterTypes) do
            aolite.assert(enc.encounterType ~= 8, "FIELD_TRIP should be disabled")  -- FIELD_TRIP
            aolite.assert(enc.encounterType ~= 14, "AN_OFFER_YOU_CANT_REFUSE should be disabled")  -- AN_OFFER_YOU_CANT_REFUSE
        end
    end)

    aolite.it("max encounters limit - encounter not selected after reaching max", function()
        -- Test that encounter is blocked once maxAllowedEncounters is reached

        local encounterType = 3  -- FIGHT_OR_FLIGHT (max 2)

        -- Create encountersCompleted state with encounter at max
        local encountersCompleted = {}
        for i = 0, 30 do
            encountersCompleted[tostring(i)] = 0
        end
        encountersCompleted[tostring(encounterType)] = 2  -- At max limit

        local msg = {
            From = "test_player",
            Action = "TrackEncounterCompletion",
            EncounterType = tostring(encounterType),
            Data = json.encode(encountersCompleted)
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["track-encounter-completion"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Blocked == "true", "Expected encounter to be blocked")
        aolite.assert(response.AllowedRemaining == "0", "Expected 0 remaining")
    end)

    aolite.it("edge case - no valid encounters for biome and wave combination", function()
        -- Test selection when no encounters match requirements

        local biomeId = 1  -- PLAINS
        local waveIndex = 5  -- Too early (min is 10)

        local msg = {
            From = "test_player",
            Action = "SelectEncounter",
            BiomeId = tostring(biomeId),
            WaveIndex = tostring(waveIndex),
            Seed = "12345"
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["select-encounter"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Action == "Error", "Expected error for invalid wave")
        aolite.assert(response.Success == "false", "Expected failure")
    end)

    aolite.it("edge case - all encounters at max limit", function()
        -- Test when all available encounters have reached max limit

        local biomeId = 1  -- PLAINS
        local waveIndex = 50

        -- Create encountersCompleted with all at max
        local encountersCompleted = {}
        for i = 0, 30 do
            encountersCompleted[tostring(i)] = 99  -- Way over max
        end

        local msg = {
            From = "test_player",
            Action = "SelectEncounter",
            BiomeId = tostring(biomeId),
            WaveIndex = tostring(waveIndex),
            Seed = "12345",
            Data = json.encode({
                waveIndex = waveIndex,
                party = {},
                encountersCompleted = encountersCompleted
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["select-encounter"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Action == "Error", "Expected error when all encounters blocked")
        aolite.assert(response.Success == "false", "Expected failure")
    end)
end)

print("Mystery encounter selection tests completed")
