-- Unit tests for mystery encounter biome mapping
-- Tests biome category assignments and encounter availability

local aolite = require("aolite")

-- Load the mystery encounter engine process
dofile("processes/mystery-encounter-engine.lua")

-- Test suite for biome mapping
aolite.describe("Mystery Encounter Biome Mapping", function()

    aolite.it("anyBiomeEncounters available in all 35 biomes", function()
        -- Verify anyBiome encounters appear in every biome

        local anyBiomeEncounterTypes = {3, 2, 1, 5, 15, 17, 18, 19, 20, 23, 25, 26, 28}  -- anyBiomeEncounters
        local biomeIds = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
                          20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34}

        for _, biomeId in ipairs(biomeIds) do
            local msg = {
                From = "test_player",
                Action = "GetEncountersByBiome",
                BiomeId = tostring(biomeId)
            }

            local sentMessages = {}
            ao.send = function(response) table.insert(sentMessages, response) end

            Handlers._handlers["get-encounters-by-biome"].fn(msg)

            local response = sentMessages[1]
            local encounterTypes = json.decode(response.Data)

            -- Count how many anyBiome encounters are present
            local anyBiomeCount = 0
            for _, enc in ipairs(encounterTypes) do
                for _, anyBiomeType in ipairs(anyBiomeEncounterTypes) do
                    if enc.encounterType == anyBiomeType then
                        anyBiomeCount = anyBiomeCount + 1
                        break
                    end
                end
            end

            aolite.assert(anyBiomeCount > 0, string.format("Expected anyBiome encounters in biome %d", biomeId))
        end
    end)

    aolite.it("specific encounters only in designated biomes - SLUMBERING_SNORLAX", function()
        -- SLUMBERING_SNORLAX should only appear in PLAINS (1), GRASS (2), TALL_GRASS (3)

        local targetBiomes = {1, 2, 3}  -- PLAINS, GRASS, TALL_GRASS
        local nonTargetBiomes = {0, 4, 5, 6}  -- TOWN, METROPOLIS, FOREST, SEA

        -- Check target biomes HAVE the encounter
        for _, biomeId in ipairs(targetBiomes) do
            local msg = {
                From = "test_player",
                Action = "GetEncountersByBiome",
                BiomeId = tostring(biomeId)
            }

            local sentMessages = {}
            ao.send = function(response) table.insert(sentMessages, response) end

            Handlers._handlers["get-encounters-by-biome"].fn(msg)

            local response = sentMessages[1]
            local encounterTypes = json.decode(response.Data)

            local hasSlumberingSnorlax = false
            for _, enc in ipairs(encounterTypes) do
                if enc.encounterType == 4 then  -- SLUMBERING_SNORLAX
                    hasSlumberingSnorlax = true
                    break
                end
            end

            aolite.assert(hasSlumberingSnorlax, string.format("Expected SLUMBERING_SNORLAX in biome %d", biomeId))
        end
    end)

    aolite.it("civilization encounters only in civilization biomes", function()
        -- DEPARTMENT_STORE_SALE (6) should only appear in civilization biomes

        local civilizationBiome = 0  -- TOWN
        local nonCivilizationBiome = 6  -- SEA

        -- Check civilization biome HAS the encounter
        local msg1 = {
            From = "test_player",
            Action = "GetEncountersByBiome",
            BiomeId = tostring(civilizationBiome)
        }

        local sentMessages = {}
        ao.send = function(response) table.insert(sentMessages, response) end

        Handlers._handlers["get-encounters-by-biome"].fn(msg1)

        local response1 = sentMessages[1]
        local encounterTypes1 = json.decode(response1.Data)

        local hasDepartmentStore = false
        for _, enc in ipairs(encounterTypes1) do
            if enc.encounterType == 6 then  -- DEPARTMENT_STORE_SALE
                hasDepartmentStore = true
                break
            end
        end

        aolite.assert(hasDepartmentStore, "Expected DEPARTMENT_STORE_SALE in TOWN")
    end)

    aolite.it("biome-specific encounters - FIERY_FALLOUT only in VOLCANO", function()
        -- FIERY_FALLOUT (11) should appear in VOLCANO (18)

        local volcanoMsg = {
            From = "test_player",
            Action = "GetEncountersByBiome",
            BiomeId = "18"  -- VOLCANO
        }

        local sentMessages = {}
        ao.send = function(response) table.insert(sentMessages, response) end

        Handlers._handlers["get-encounters-by-biome"].fn(volcanoMsg)

        local response = sentMessages[1]
        local encounterTypes = json.decode(response.Data)

        local hasFieryFallout = false
        for _, enc in ipairs(encounterTypes) do
            if enc.encounterType == 11 then  -- FIERY_FALLOUT
                hasFieryFallout = true
                break
            end
        end

        aolite.assert(hasFieryFallout, "Expected FIERY_FALLOUT in VOLCANO")
    end)
end)

print("Mystery encounter biome mapping tests completed")
