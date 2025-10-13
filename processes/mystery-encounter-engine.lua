-- Mystery Encounter Engine Process
-- AO Process for mystery encounter generation, selection, and requirement validation
-- Implements 33+ mystery encounter types with biome-based pools and tier-weighted selection
--
-- AO Compliance: Monolithic design, no external dependencies, deterministic RNG
-- ADP v1.0 Compliance: Self-documenting process with Info handler

local json = require("json")

-- Mock AO environment for testing
if not ao then
    ao = {
        send = function(msg)
            print("Mock ao.send:", json.encode(msg))
        end,
        id = "mystery_encounter_process_id"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    return msg[tagName] == tagValue
                end
            end
        }
    }
end

-- ============================================================================
-- ENUMERATIONS
-- ============================================================================

-- Mystery Encounter Types (33 unique encounters)
local ENCOUNTER_TYPES = {
    MYSTERIOUS_CHALLENGERS = 0,
    MYSTERIOUS_CHEST = 1,
    DARK_DEAL = 2,
    FIGHT_OR_FLIGHT = 3,
    SLUMBERING_SNORLAX = 4,
    TRAINING_SESSION = 5,
    DEPARTMENT_STORE_SALE = 6,
    SHADY_VITAMIN_DEALER = 7,
    FIELD_TRIP = 8,
    SAFARI_ZONE = 9,
    LOST_AT_SEA = 10,
    FIERY_FALLOUT = 11,
    THE_STRONG_STUFF = 12,
    THE_POKEMON_SALESMAN = 13,
    AN_OFFER_YOU_CANT_REFUSE = 14,
    DELIBIRDY = 15,
    ABSOLUTE_AVARICE = 16,
    A_TRAINERS_TEST = 17,
    TRASH_TO_TREASURE = 18,
    BERRIES_ABOUND = 19,
    CLOWNING_AROUND = 20,
    PART_TIMER = 21,
    DANCING_LESSONS = 22,
    WEIRD_DREAM = 23,
    THE_WINSTRATE_CHALLENGE = 24,
    TELEPORTING_HIJINKS = 25,
    BUG_TYPE_SUPERFAN = 26,
    FUN_AND_GAMES = 27,
    UNCOMMON_BREED = 28,
    GLOBAL_TRADE_SYSTEM = 29,
    THE_EXPERT_POKEMON_BREEDER = 30
}

-- Reverse mapping for encounter type names
local ENCOUNTER_TYPE_NAMES = {}
for name, id in pairs(ENCOUNTER_TYPES) do
    ENCOUNTER_TYPE_NAMES[id] = name
end

-- Mystery Encounter Tiers
-- Enum values are base spawn weights targeting 46.25/31.25/18.5/4% spawn ratios
local ENCOUNTER_TIERS = {
    COMMON = 66,
    GREAT = 40,
    ULTRA = 19,
    ROGUE = 3,
    MASTER = 0  -- Not currently used
}

-- Tier name mapping
local TIER_NAMES = {
    [66] = "COMMON",
    [40] = "GREAT",
    [19] = "ULTRA",
    [3] = "ROGUE",
    [0] = "MASTER"
}

-- Biome IDs (matching TypeScript BiomeId enum)
local BIOME_IDS = {
    TOWN = 0,
    PLAINS = 1,
    GRASS = 2,
    TALL_GRASS = 3,
    METROPOLIS = 4,
    FOREST = 5,
    SEA = 6,
    SWAMP = 7,
    BEACH = 8,
    LAKE = 9,
    SEABED = 10,
    MOUNTAIN = 11,
    BADLANDS = 12,
    CAVE = 13,
    DESERT = 14,
    ICE_CAVE = 15,
    MEADOW = 16,
    POWER_PLANT = 17,
    VOLCANO = 18,
    GRAVEYARD = 19,
    DOJO = 20,
    FACTORY = 21,
    RUINS = 22,
    WASTELAND = 23,
    ABYSS = 24,
    SPACE = 25,
    CONSTRUCTION_SITE = 26,
    JUNGLE = 27,
    FAIRY_CAVE = 28,
    TEMPLE = 29,
    SLUM = 30,
    SNOWY_FOREST = 31,
    ISLAND = 32,
    LABORATORY = 33,
    END = 34
}

-- ============================================================================
-- BIOME CATEGORY CONSTANTS
-- ============================================================================

-- Extreme environment biomes
local EXTREME_ENCOUNTER_BIOMES = {
    BIOME_IDS.SEA,
    BIOME_IDS.SEABED,
    BIOME_IDS.BADLANDS,
    BIOME_IDS.DESERT,
    BIOME_IDS.ICE_CAVE,
    BIOME_IDS.VOLCANO,
    BIOME_IDS.WASTELAND,
    BIOME_IDS.ABYSS,
    BIOME_IDS.SPACE,
    BIOME_IDS.END
}

-- Non-extreme biomes (most common biomes)
local NON_EXTREME_ENCOUNTER_BIOMES = {
    BIOME_IDS.TOWN,
    BIOME_IDS.PLAINS,
    BIOME_IDS.GRASS,
    BIOME_IDS.TALL_GRASS,
    BIOME_IDS.METROPOLIS,
    BIOME_IDS.FOREST,
    BIOME_IDS.SWAMP,
    BIOME_IDS.BEACH,
    BIOME_IDS.LAKE,
    BIOME_IDS.MOUNTAIN,
    BIOME_IDS.CAVE,
    BIOME_IDS.MEADOW,
    BIOME_IDS.POWER_PLANT,
    BIOME_IDS.GRAVEYARD,
    BIOME_IDS.DOJO,
    BIOME_IDS.FACTORY,
    BIOME_IDS.RUINS,
    BIOME_IDS.CONSTRUCTION_SITE,
    BIOME_IDS.JUNGLE,
    BIOME_IDS.FAIRY_CAVE,
    BIOME_IDS.TEMPLE,
    BIOME_IDS.SLUM,
    BIOME_IDS.SNOWY_FOREST,
    BIOME_IDS.ISLAND,
    BIOME_IDS.LABORATORY
}

-- Human transitable biomes (NON_EXTREME + BADLANDS, DESERT, ICE_CAVE)
local HUMAN_TRANSITABLE_BIOMES = {
    BIOME_IDS.TOWN,
    BIOME_IDS.PLAINS,
    BIOME_IDS.GRASS,
    BIOME_IDS.TALL_GRASS,
    BIOME_IDS.METROPOLIS,
    BIOME_IDS.FOREST,
    BIOME_IDS.SWAMP,
    BIOME_IDS.BEACH,
    BIOME_IDS.LAKE,
    BIOME_IDS.MOUNTAIN,
    BIOME_IDS.BADLANDS,
    BIOME_IDS.CAVE,
    BIOME_IDS.DESERT,
    BIOME_IDS.ICE_CAVE,
    BIOME_IDS.MEADOW,
    BIOME_IDS.POWER_PLANT,
    BIOME_IDS.GRAVEYARD,
    BIOME_IDS.DOJO,
    BIOME_IDS.FACTORY,
    BIOME_IDS.RUINS,
    BIOME_IDS.CONSTRUCTION_SITE,
    BIOME_IDS.JUNGLE,
    BIOME_IDS.FAIRY_CAVE,
    BIOME_IDS.TEMPLE,
    BIOME_IDS.SLUM,
    BIOME_IDS.SNOWY_FOREST,
    BIOME_IDS.ISLAND,
    BIOME_IDS.LABORATORY
}

-- Civilization biomes (towns/cities)
local CIVILIZATION_ENCOUNTER_BIOMES = {
    BIOME_IDS.TOWN,
    BIOME_IDS.PLAINS,
    BIOME_IDS.GRASS,
    BIOME_IDS.TALL_GRASS,
    BIOME_IDS.METROPOLIS,
    BIOME_IDS.BEACH,
    BIOME_IDS.LAKE,
    BIOME_IDS.MEADOW,
    BIOME_IDS.POWER_PLANT,
    BIOME_IDS.GRAVEYARD,
    BIOME_IDS.DOJO,
    BIOME_IDS.FACTORY,
    BIOME_IDS.CONSTRUCTION_SITE,
    BIOME_IDS.SLUM,
    BIOME_IDS.ISLAND
}

-- ============================================================================
-- ENCOUNTER CATEGORY ARRAYS
-- ============================================================================

-- Encounters available in extreme biomes only
local extremeBiomeEncounters = {}

-- Encounters available in non-extreme biomes
-- Note: FIELD_TRIP is disabled in TypeScript
local nonExtremeBiomeEncounters = {
    ENCOUNTER_TYPES.DANCING_LESSONS  -- Also in BADLANDS, DESERT, VOLCANO, WASTELAND, ABYSS
}

-- Encounters requiring human-transitable biomes
-- Note: AN_OFFER_YOU_CANT_REFUSE is disabled in TypeScript
local humanTransitableBiomeEncounters = {
    ENCOUNTER_TYPES.MYSTERIOUS_CHALLENGERS,
    ENCOUNTER_TYPES.SHADY_VITAMIN_DEALER,
    ENCOUNTER_TYPES.THE_POKEMON_SALESMAN,
    ENCOUNTER_TYPES.THE_WINSTRATE_CHALLENGE,
    ENCOUNTER_TYPES.THE_EXPERT_POKEMON_BREEDER
}

-- Encounters requiring civilization biomes
local civilizationBiomeEncounters = {
    ENCOUNTER_TYPES.DEPARTMENT_STORE_SALE,
    ENCOUNTER_TYPES.PART_TIMER,
    ENCOUNTER_TYPES.FUN_AND_GAMES,
    ENCOUNTER_TYPES.GLOBAL_TRADE_SYSTEM
}

-- Encounters available in ANY biome
local anyBiomeEncounters = {
    ENCOUNTER_TYPES.FIGHT_OR_FLIGHT,
    ENCOUNTER_TYPES.DARK_DEAL,
    ENCOUNTER_TYPES.MYSTERIOUS_CHEST,
    ENCOUNTER_TYPES.TRAINING_SESSION,
    ENCOUNTER_TYPES.DELIBIRDY,
    ENCOUNTER_TYPES.A_TRAINERS_TEST,
    ENCOUNTER_TYPES.TRASH_TO_TREASURE,
    ENCOUNTER_TYPES.BERRIES_ABOUND,
    ENCOUNTER_TYPES.CLOWNING_AROUND,
    ENCOUNTER_TYPES.WEIRD_DREAM,
    ENCOUNTER_TYPES.TELEPORTING_HIJINKS,
    ENCOUNTER_TYPES.BUG_TYPE_SUPERFAN,
    ENCOUNTER_TYPES.UNCOMMON_BREED
}

-- ============================================================================
-- ENCOUNTER DATA STRUCTURES
-- ============================================================================

-- Classic mode mystery encounter wave range constant
local CLASSIC_MODE_MYSTERY_ENCOUNTER_WAVES = {10, 180}

-- Default max encounter limits by tier
local DEFAULT_MAX_ALLOWED_ENCOUNTERS = 2
local DEFAULT_MAX_ALLOWED_ROGUE_ENCOUNTERS = 1

-- Mystery Encounter Definitions
-- Each encounter includes: encounterType, tier, maxAllowedEncounters, requirements, biomeCategories
local MYSTERY_ENCOUNTERS = {
    [ENCOUNTER_TYPES.MYSTERIOUS_CHALLENGERS] = {
        encounterType = ENCOUNTER_TYPES.MYSTERIOUS_CHALLENGERS,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.MYSTERIOUS_CHEST] = {
        encounterType = ENCOUNTER_TYPES.MYSTERIOUS_CHEST,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180},
            {type = "PartySize", minSize = 2}
        }
    },
    [ENCOUNTER_TYPES.DARK_DEAL] = {
        encounterType = ENCOUNTER_TYPES.DARK_DEAL,
        tier = ENCOUNTER_TIERS.ROGUE,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ROGUE_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 30, maxWave = 180},
            {type = "PartySize", minSize = 2}
        }
    },
    [ENCOUNTER_TYPES.FIGHT_OR_FLIGHT] = {
        encounterType = ENCOUNTER_TYPES.FIGHT_OR_FLIGHT,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.SLUMBERING_SNORLAX] = {
        encounterType = ENCOUNTER_TYPES.SLUMBERING_SNORLAX,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 15, maxWave = 150}
        }
    },
    [ENCOUNTER_TYPES.TRAINING_SESSION] = {
        encounterType = ENCOUNTER_TYPES.TRAINING_SESSION,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.DEPARTMENT_STORE_SALE] = {
        encounterType = ENCOUNTER_TYPES.DEPARTMENT_STORE_SALE,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 100}
        }
    },
    [ENCOUNTER_TYPES.SHADY_VITAMIN_DEALER] = {
        encounterType = ENCOUNTER_TYPES.SHADY_VITAMIN_DEALER,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.FIELD_TRIP] = {
        encounterType = ENCOUNTER_TYPES.FIELD_TRIP,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        disabled = true,  -- Disabled in TypeScript
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 100}
        }
    },
    [ENCOUNTER_TYPES.SAFARI_ZONE] = {
        encounterType = ENCOUNTER_TYPES.SAFARI_ZONE,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.LOST_AT_SEA] = {
        encounterType = ENCOUNTER_TYPES.LOST_AT_SEA,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.FIERY_FALLOUT] = {
        encounterType = ENCOUNTER_TYPES.FIERY_FALLOUT,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 40, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.THE_STRONG_STUFF] = {
        encounterType = ENCOUNTER_TYPES.THE_STRONG_STUFF,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.THE_POKEMON_SALESMAN] = {
        encounterType = ENCOUNTER_TYPES.THE_POKEMON_SALESMAN,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.AN_OFFER_YOU_CANT_REFUSE] = {
        encounterType = ENCOUNTER_TYPES.AN_OFFER_YOU_CANT_REFUSE,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        disabled = true,  -- Disabled in TypeScript
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180},
            {type = "PartySize", minSize = 2}
        }
    },
    [ENCOUNTER_TYPES.DELIBIRDY] = {
        encounterType = ENCOUNTER_TYPES.DELIBIRDY,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.ABSOLUTE_AVARICE] = {
        encounterType = ENCOUNTER_TYPES.ABSOLUTE_AVARICE,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 20, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.A_TRAINERS_TEST] = {
        encounterType = ENCOUNTER_TYPES.A_TRAINERS_TEST,
        tier = ENCOUNTER_TIERS.ROGUE,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ROGUE_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 100, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.TRASH_TO_TREASURE] = {
        encounterType = ENCOUNTER_TYPES.TRASH_TO_TREASURE,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.BERRIES_ABOUND] = {
        encounterType = ENCOUNTER_TYPES.BERRIES_ABOUND,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.CLOWNING_AROUND] = {
        encounterType = ENCOUNTER_TYPES.CLOWNING_AROUND,
        tier = ENCOUNTER_TIERS.ULTRA,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 80, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.PART_TIMER] = {
        encounterType = ENCOUNTER_TYPES.PART_TIMER,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.DANCING_LESSONS] = {
        encounterType = ENCOUNTER_TYPES.DANCING_LESSONS,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.WEIRD_DREAM] = {
        encounterType = ENCOUNTER_TYPES.WEIRD_DREAM,
        tier = ENCOUNTER_TIERS.ULTRA,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.THE_WINSTRATE_CHALLENGE] = {
        encounterType = ENCOUNTER_TYPES.THE_WINSTRATE_CHALLENGE,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.TELEPORTING_HIJINKS] = {
        encounterType = ENCOUNTER_TYPES.TELEPORTING_HIJINKS,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.BUG_TYPE_SUPERFAN] = {
        encounterType = ENCOUNTER_TYPES.BUG_TYPE_SUPERFAN,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.FUN_AND_GAMES] = {
        encounterType = ENCOUNTER_TYPES.FUN_AND_GAMES,
        tier = ENCOUNTER_TIERS.GREAT,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.UNCOMMON_BREED] = {
        encounterType = ENCOUNTER_TYPES.UNCOMMON_BREED,
        tier = ENCOUNTER_TIERS.ULTRA,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.GLOBAL_TRADE_SYSTEM] = {
        encounterType = ENCOUNTER_TYPES.GLOBAL_TRADE_SYSTEM,
        tier = ENCOUNTER_TIERS.COMMON,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    },
    [ENCOUNTER_TYPES.THE_EXPERT_POKEMON_BREEDER] = {
        encounterType = ENCOUNTER_TYPES.THE_EXPERT_POKEMON_BREEDER,
        tier = ENCOUNTER_TIERS.ULTRA,
        maxAllowedEncounters = DEFAULT_MAX_ALLOWED_ENCOUNTERS,
        requirements = {
            {type = "WaveRange", minWave = 10, maxWave = 180}
        }
    }
}

-- ============================================================================
-- BIOME MAPPING SYSTEM
-- ============================================================================

-- Biome-specific encounter mappings (initialized to empty tables)
local mysteryEncountersByBiome = {
    [BIOME_IDS.TOWN] = {},
    [BIOME_IDS.PLAINS] = {ENCOUNTER_TYPES.SLUMBERING_SNORLAX},
    [BIOME_IDS.GRASS] = {ENCOUNTER_TYPES.SLUMBERING_SNORLAX, ENCOUNTER_TYPES.ABSOLUTE_AVARICE},
    [BIOME_IDS.TALL_GRASS] = {ENCOUNTER_TYPES.SLUMBERING_SNORLAX, ENCOUNTER_TYPES.ABSOLUTE_AVARICE},
    [BIOME_IDS.METROPOLIS] = {},
    [BIOME_IDS.FOREST] = {ENCOUNTER_TYPES.SAFARI_ZONE, ENCOUNTER_TYPES.ABSOLUTE_AVARICE},
    [BIOME_IDS.SEA] = {ENCOUNTER_TYPES.LOST_AT_SEA},
    [BIOME_IDS.SWAMP] = {ENCOUNTER_TYPES.SAFARI_ZONE},
    [BIOME_IDS.BEACH] = {},
    [BIOME_IDS.LAKE] = {},
    [BIOME_IDS.SEABED] = {},
    [BIOME_IDS.MOUNTAIN] = {},
    [BIOME_IDS.BADLANDS] = {ENCOUNTER_TYPES.DANCING_LESSONS},
    [BIOME_IDS.CAVE] = {ENCOUNTER_TYPES.THE_STRONG_STUFF},
    [BIOME_IDS.DESERT] = {ENCOUNTER_TYPES.DANCING_LESSONS},
    [BIOME_IDS.ICE_CAVE] = {},
    [BIOME_IDS.MEADOW] = {},
    [BIOME_IDS.POWER_PLANT] = {},
    [BIOME_IDS.VOLCANO] = {ENCOUNTER_TYPES.FIERY_FALLOUT, ENCOUNTER_TYPES.DANCING_LESSONS},
    [BIOME_IDS.GRAVEYARD] = {},
    [BIOME_IDS.DOJO] = {},
    [BIOME_IDS.FACTORY] = {},
    [BIOME_IDS.RUINS] = {},
    [BIOME_IDS.WASTELAND] = {ENCOUNTER_TYPES.DANCING_LESSONS},
    [BIOME_IDS.ABYSS] = {ENCOUNTER_TYPES.DANCING_LESSONS},
    [BIOME_IDS.SPACE] = {ENCOUNTER_TYPES.THE_EXPERT_POKEMON_BREEDER},
    [BIOME_IDS.CONSTRUCTION_SITE] = {},
    [BIOME_IDS.JUNGLE] = {ENCOUNTER_TYPES.SAFARI_ZONE},
    [BIOME_IDS.FAIRY_CAVE] = {},
    [BIOME_IDS.TEMPLE] = {},
    [BIOME_IDS.SLUM] = {},
    [BIOME_IDS.SNOWY_FOREST] = {},
    [BIOME_IDS.ISLAND] = {},
    [BIOME_IDS.LABORATORY] = {},
    [BIOME_IDS.END] = {}
}

-- Helper function to check if array contains value
local function arrayContains(arr, value)
    for _, v in ipairs(arr) do
        if v == value then
            return true
        end
    end
    return false
end

-- Initialize biome encounter mappings by adding category-based encounters
local function initBiomeEncounterMappings()
    -- Add extreme biome encounters
    for _, encounterType in ipairs(extremeBiomeEncounters) do
        for _, biomeId in ipairs(EXTREME_ENCOUNTER_BIOMES) do
            local biomeEncounters = mysteryEncountersByBiome[biomeId]
            if biomeEncounters and not arrayContains(biomeEncounters, encounterType) then
                table.insert(biomeEncounters, encounterType)
            end
        end
    end

    -- Add non-extreme biome encounters
    for _, encounterType in ipairs(nonExtremeBiomeEncounters) do
        for _, biomeId in ipairs(NON_EXTREME_ENCOUNTER_BIOMES) do
            local biomeEncounters = mysteryEncountersByBiome[biomeId]
            if biomeEncounters and not arrayContains(biomeEncounters, encounterType) then
                table.insert(biomeEncounters, encounterType)
            end
        end
    end

    -- Add human transitable biome encounters
    for _, encounterType in ipairs(humanTransitableBiomeEncounters) do
        for _, biomeId in ipairs(HUMAN_TRANSITABLE_BIOMES) do
            local biomeEncounters = mysteryEncountersByBiome[biomeId]
            if biomeEncounters and not arrayContains(biomeEncounters, encounterType) then
                table.insert(biomeEncounters, encounterType)
            end
        end
    end

    -- Add civilization biome encounters
    for _, encounterType in ipairs(civilizationBiomeEncounters) do
        for _, biomeId in ipairs(CIVILIZATION_ENCOUNTER_BIOMES) do
            local biomeEncounters = mysteryEncountersByBiome[biomeId]
            if biomeEncounters and not arrayContains(biomeEncounters, encounterType) then
                table.insert(biomeEncounters, encounterType)
            end
        end
    end

    -- Add "any biome" encounters to ALL biomes
    for biomeId, biomeEncounters in pairs(mysteryEncountersByBiome) do
        for _, encounterType in ipairs(anyBiomeEncounters) do
            if not arrayContains(biomeEncounters, encounterType) then
                table.insert(biomeEncounters, encounterType)
            end
        end
    end
end

-- Initialize biome mappings on load
initBiomeEncounterMappings()

-- Get encounters for a specific biome
local function getBiomeEncounters(biomeId)
    return mysteryEncountersByBiome[biomeId] or {}
end

-- ============================================================================
-- ENCOUNTER STATE TRACKING
-- ============================================================================

-- Helper functions for encounter completion tracking
local function createEncountersCompletedState()
    local state = {}
    for encounterType, _ in pairs(MYSTERY_ENCOUNTERS) do
        state[tostring(encounterType)] = 0
    end
    return state
end

local function incrementEncounterCount(encountersCompleted, encounterType)
    local key = tostring(encounterType)
    encountersCompleted[key] = (encountersCompleted[key] or 0) + 1
    return encountersCompleted
end

local function getEncounterCount(encountersCompleted, encounterType)
    local key = tostring(encounterType)
    return encountersCompleted[key] or 0
end

local function isEncounterBlocked(encountersCompleted, encounterType)
    local encounter = MYSTERY_ENCOUNTERS[encounterType]
    if not encounter then
        return true  -- Unknown encounter type
    end

    local currentCount = getEncounterCount(encountersCompleted, encounterType)
    return currentCount >= encounter.maxAllowedEncounters
end

local function getRemainingAllowed(encountersCompleted, encounterType)
    local encounter = MYSTERY_ENCOUNTERS[encounterType]
    if not encounter then
        return 0
    end

    local currentCount = getEncounterCount(encountersCompleted, encounterType)
    return math.max(0, encounter.maxAllowedEncounters - currentCount)
end

-- ============================================================================
-- REQUIREMENT VALIDATION SYSTEM
-- ============================================================================

-- Requirement validator registry
local REQUIREMENT_VALIDATORS = {
    WaveRange = function(req, gameState)
        local wave = gameState.waveIndex or 0
        return wave >= req.minWave and wave <= req.maxWave
    end,

    PartySize = function(req, gameState)
        local party = gameState.party or {}
        local partySize = #party
        return partySize >= req.minSize
    end,

    HealthRatio = function(req, gameState)
        local party = gameState.party or {}
        for _, pokemon in ipairs(party) do
            if pokemon.hp and pokemon.maxHp then
                local ratio = pokemon.hp / pokemon.maxHp
                if req.minRatio and ratio < req.minRatio then
                    return false
                end
                if req.maxRatio and ratio > req.maxRatio then
                    return false
                end
            end
        end
        return true
    end,

    StatusEffect = function(req, gameState)
        local party = gameState.party or {}
        local matchCount = 0
        for _, pokemon in ipairs(party) do
            if pokemon.status and pokemon.status == req.statusEffect then
                matchCount = matchCount + 1
            end
        end
        return matchCount >= (req.minCount or 1)
    end
}

-- Validate a single requirement
local function validateRequirement(requirement, gameState)
    local validator = REQUIREMENT_VALIDATORS[requirement.type]
    if not validator then
        return false  -- Unknown requirement type defaults to invalid
    end
    return validator(requirement, gameState)
end

-- Validate all requirements for an encounter (AND logic by default)
local function validateRequirements(encounter, gameState)
    if not encounter or not encounter.requirements then
        return true  -- No requirements means always valid
    end

    for _, requirement in ipairs(encounter.requirements) do
        if not validateRequirement(requirement, gameState) then
            return false
        end
    end
    return true
end

-- Get detailed requirement validation results
local function getRequirementValidationDetails(encounter, gameState)
    local passed = {}
    local failed = {}

    if not encounter or not encounter.requirements then
        return passed, failed
    end

    for _, requirement in ipairs(encounter.requirements) do
        local reqName = requirement.type
        if requirement.type == "WaveRange" then
            reqName = string.format("WaveRange(%d-%d)", requirement.minWave, requirement.maxWave)
        elseif requirement.type == "PartySize" then
            reqName = string.format("PartySize(min:%d)", requirement.minSize)
        end

        if validateRequirement(requirement, gameState) then
            table.insert(passed, reqName)
        else
            table.insert(failed, reqName)
        end
    end

    return passed, failed
end

-- ============================================================================
-- ENCOUNTER SELECTION ALGORITHM
-- ============================================================================

-- Seeded random number generator (deterministic)
local function seededRandom(seed, min, max)
    -- Simple LCG (Linear Congruential Generator) for deterministic randomness
    local a = 1103515245
    local c = 12345
    local m = 2^31

    local nextSeed = (a * seed + c) % m
    local value = nextSeed / m

    if min and max then
        return min + math.floor(value * (max - min + 1)), nextSeed
    else
        return value, nextSeed
    end
end

-- Filter encounters by biome
local function filterEncountersByBiome(biomeId)
    local biomeEncounters = getBiomeEncounters(biomeId)
    local filtered = {}

    for _, encounterType in ipairs(biomeEncounters) do
        local encounter = MYSTERY_ENCOUNTERS[encounterType]
        if encounter and not encounter.disabled then
            table.insert(filtered, encounterType)
        end
    end

    return filtered
end

-- Filter encounters by game mode
local function filterByGameMode(encounters, gameMode)
    if not gameMode then
        return encounters
    end

    local filtered = {}
    for _, encounterType in ipairs(encounters) do
        local encounter = MYSTERY_ENCOUNTERS[encounterType]
        local allowed = true

        if encounter.disallowedGameModes then
            for _, disallowedMode in ipairs(encounter.disallowedGameModes) do
                if disallowedMode == gameMode then
                    allowed = false
                    break
                end
            end
        end

        if allowed then
            table.insert(filtered, encounterType)
        end
    end

    return filtered
end

-- Filter encounters by requirements
local function filterByRequirements(encounters, gameState)
    local filtered = {}

    for _, encounterType in ipairs(encounters) do
        local encounter = MYSTERY_ENCOUNTERS[encounterType]
        if encounter and validateRequirements(encounter, gameState) then
            table.insert(filtered, encounterType)
        end
    end

    return filtered
end

-- Filter encounters by max encounter limit
local function filterByEncounterLimit(encounters, encountersCompleted)
    local filtered = {}

    for _, encounterType in ipairs(encounters) do
        if not isEncounterBlocked(encountersCompleted, encounterType) then
            table.insert(filtered, encounterType)
        end
    end

    return filtered
end

-- Calculate probability weights for encounters based on tier
local function calculateProbabilities(encounters)
    local probabilities = {}
    local totalWeight = 0

    -- Calculate total weight
    for _, encounterType in ipairs(encounters) do
        local encounter = MYSTERY_ENCOUNTERS[encounterType]
        if encounter then
            totalWeight = totalWeight + encounter.tier
        end
    end

    -- Normalize probabilities
    if totalWeight > 0 then
        for _, encounterType in ipairs(encounters) do
            local encounter = MYSTERY_ENCOUNTERS[encounterType]
            if encounter then
                local probability = encounter.tier / totalWeight
                table.insert(probabilities, {
                    encounterType = encounterType,
                    probability = probability,
                    tier = encounter.tier,
                    tierName = TIER_NAMES[encounter.tier]
                })
            end
        end
    end

    return probabilities, totalWeight
end

-- Weighted random selection using seeded RNG
local function weightedRandomSelection(encounters, seed)
    if #encounters == 0 then
        return nil, "No valid encounters available"
    end

    local probabilities, totalWeight = calculateProbabilities(encounters)
    if totalWeight == 0 then
        return nil, "No weighted encounters available"
    end

    -- Generate random value [0, 1) using seed
    local randomValue, _ = seededRandom(seed, nil, nil)

    -- Select encounter based on cumulative probability
    local cumulativeProbability = 0
    for _, prob in ipairs(probabilities) do
        cumulativeProbability = cumulativeProbability + prob.probability
        if randomValue <= cumulativeProbability then
            return prob.encounterType, nil
        end
    end

    -- Fallback to last encounter (should never happen with proper normalization)
    return probabilities[#probabilities].encounterType, nil
end

-- Main encounter selection function
local function selectEncounter(biomeId, waveIndex, gameMode, gameState, seed)
    -- 1. Filter by biome
    local validEncounters = filterEncountersByBiome(biomeId)

    -- 2. Filter by game mode
    validEncounters = filterByGameMode(validEncounters, gameMode)

    -- 3. Create minimal game state if not provided
    if not gameState then
        gameState = {
            waveIndex = waveIndex,
            party = {},
            encountersCompleted = createEncountersCompletedState()
        }
    end

    if not gameState.waveIndex then
        gameState.waveIndex = waveIndex
    end

    -- 4. Filter by requirements
    validEncounters = filterByRequirements(validEncounters, gameState)

    -- 5. Filter by encounter limit
    local encountersCompleted = gameState.encountersCompleted or createEncountersCompletedState()
    validEncounters = filterByEncounterLimit(validEncounters, encountersCompleted)

    -- 6. Weighted random selection
    if #validEncounters == 0 then
        return nil, "No valid encounters match criteria"
    end

    local selectedType, err = weightedRandomSelection(validEncounters, seed or waveIndex)
    if err then
        return nil, err
    end

    return MYSTERY_ENCOUNTERS[selectedType], nil
end

-- ============================================================================
-- ADP v1.0 INFO HANDLER
-- ============================================================================

Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Mystery Encounter Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    processId = ao.id or "mystery-encounter-engine-adp",
                    description = "Stateless AO process for mystery encounter generation, selection, and requirement validation",
                    capabilities = {
                        "SelectEncounter",
                        "ValidateEncounterRequirements",
                        "GetEncountersByBiome",
                        "TrackEncounterCompletion",
                        "GetEncounterProbabilities"
                    },
                    messageSchemas = {
                        SelectEncounter = {
                            required = {"Action", "BiomeId", "WaveIndex", "GameMode", "Data"},
                            description = "Select a valid mystery encounter based on biome, wave, and game state"
                        },
                        ValidateEncounterRequirements = {
                            required = {"Action", "EncounterType", "Data"},
                            description = "Validate if an encounter's requirements are met by current game state"
                        },
                        GetEncountersByBiome = {
                            required = {"Action", "BiomeId"},
                            optional = {"WaveIndex", "GameMode"},
                            description = "Return all encounters valid for a specific biome"
                        },
                        TrackEncounterCompletion = {
                            required = {"Action", "EncounterType", "Data"},
                            description = "Update encounter completion tracking and check max limits"
                        },
                        GetEncounterProbabilities = {
                            required = {"Action", "BiomeId", "WaveIndex", "Data"},
                            description = "Calculate spawn probabilities for all valid encounters"
                        },
                        Info = {
                            required = {"Action"},
                            description = "Return process metadata and capabilities (ADP v1.0)"
                        }
                    }
                },
                handlers = {
                    "SelectEncounter",
                    "ValidateEncounterRequirements",
                    "GetEncountersByBiome",
                    "TrackEncounterCompletion",
                    "GetEncounterProbabilities",
                    "Info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    encounterCount = 31,  -- 33 total, 2 disabled (FIELD_TRIP, AN_OFFER_YOU_CANT_REFUSE)
                    tierSystem = "COMMON (66), GREAT (40), ULTRA (19), ROGUE (3)",
                    biomeCategories = {
                        "extremeBiomes",
                        "nonExtremeBiomes",
                        "humanTransitableBiomes",
                        "civilizationBiomes",
                        "anyBiomes"
                    }
                }
            })
        })
    end
)

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Handler: SelectEncounter
-- Select a valid mystery encounter based on biome, wave, and game state
Handlers.add("select-encounter",
    Handlers.utils.hasMatchingTag("Action", "SelectEncounter"),
    function(msg)
        local biomeId = tonumber(msg.BiomeId)
        local waveIndex = tonumber(msg.WaveIndex)
        local gameMode = msg.GameMode
        local seed = tonumber(msg.Seed or waveIndex or 0)

        -- Validate required parameters
        if not biomeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "BiomeId required"
            })
            return
        end

        if not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "WaveIndex required"
            })
            return
        end

        -- Parse game state from Data field
        local gameState = nil
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end

        -- Select encounter
        local encounter, err = selectEncounter(biomeId, waveIndex, gameMode, gameState, seed)

        if err then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = err,
                BiomeId = tostring(biomeId),
                WaveIndex = tostring(waveIndex)
            })
            return
        end

        if not encounter then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "false",
                EncounterType = "",
                Data = json.encode(nil)
            })
            return
        end

        -- Return selected encounter
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            EncounterType = tostring(encounter.encounterType),
            EncounterName = ENCOUNTER_TYPE_NAMES[encounter.encounterType],
            Tier = tostring(encounter.tier),
            TierName = TIER_NAMES[encounter.tier],
            Data = json.encode(encounter)
        })
    end
)

-- Handler: ValidateEncounterRequirements
-- Validate if an encounter's requirements are met by current game state
Handlers.add("validate-encounter-requirements",
    Handlers.utils.hasMatchingTag("Action", "ValidateEncounterRequirements"),
    function(msg)
        local encounterType = tonumber(msg.EncounterType)

        -- Validate required parameters
        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "EncounterType required"
            })
            return
        end

        -- Get encounter
        local encounter = MYSTERY_ENCOUNTERS[encounterType]
        if not encounter then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "Unknown encounter type"
            })
            return
        end

        -- Parse game state
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end

        -- Validate requirements
        local passed, failed = getRequirementValidationDetails(encounter, gameState)
        local isValid = (#failed == 0)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Valid = tostring(isValid),
            RequirementsPassed = table.concat(passed, ","),
            RequirementsFailed = table.concat(failed, ","),
            EncounterType = tostring(encounterType)
        })
    end
)

-- Handler: GetEncountersByBiome
-- Return all encounters valid for a specific biome
Handlers.add("get-encounters-by-biome",
    Handlers.utils.hasMatchingTag("Action", "GetEncountersByBiome"),
    function(msg)
        local biomeId = tonumber(msg.BiomeId)

        -- Validate required parameters
        if not biomeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "BiomeId required"
            })
            return
        end

        -- Get encounters for biome
        local encounters = filterEncountersByBiome(biomeId)

        -- Optionally filter by game mode and wave range
        local gameMode = msg.GameMode
        local waveIndex = tonumber(msg.WaveIndex)

        if gameMode then
            encounters = filterByGameMode(encounters, gameMode)
        end

        if waveIndex then
            local gameState = {waveIndex = waveIndex}
            encounters = filterByRequirements(encounters, gameState)
        end

        -- Build result array
        local encounterTypes = {}
        for _, encounterType in ipairs(encounters) do
            table.insert(encounterTypes, {
                encounterType = encounterType,
                encounterName = ENCOUNTER_TYPE_NAMES[encounterType],
                tier = MYSTERY_ENCOUNTERS[encounterType].tier,
                tierName = TIER_NAMES[MYSTERY_ENCOUNTERS[encounterType].tier]
            })
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            EncounterCount = tostring(#encounterTypes),
            BiomeId = tostring(biomeId),
            Data = json.encode(encounterTypes)
        })
    end
)

-- Handler: TrackEncounterCompletion
-- Update encounter completion tracking and check max limits
Handlers.add("track-encounter-completion",
    Handlers.utils.hasMatchingTag("Action", "TrackEncounterCompletion"),
    function(msg)
        local encounterType = tonumber(msg.EncounterType)

        -- Validate required parameters
        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "EncounterType required"
            })
            return
        end

        -- Parse encountersCompleted state
        local encountersCompleted = createEncountersCompletedState()
        if msg.Data and msg.Data ~= "" then
            encountersCompleted = json.decode(msg.Data)
        end

        -- Increment counter
        encountersCompleted = incrementEncounterCount(encountersCompleted, encounterType)

        -- Get updated stats
        local currentCount = getEncounterCount(encountersCompleted, encounterType)
        local remainingAllowed = getRemainingAllowed(encountersCompleted, encounterType)
        local blocked = isEncounterBlocked(encountersCompleted, encounterType)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            EncounterType = tostring(encounterType),
            EncounterCount = tostring(currentCount),
            AllowedRemaining = tostring(remainingAllowed),
            Blocked = tostring(blocked),
            Data = json.encode(encountersCompleted)
        })
    end
)

-- Handler: GetEncounterProbabilities
-- Calculate spawn probabilities for all valid encounters
Handlers.add("get-encounter-probabilities",
    Handlers.utils.hasMatchingTag("Action", "GetEncounterProbabilities"),
    function(msg)
        local biomeId = tonumber(msg.BiomeId)
        local waveIndex = tonumber(msg.WaveIndex)

        -- Validate required parameters
        if not biomeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "BiomeId required"
            })
            return
        end

        if not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Error = "WaveIndex required"
            })
            return
        end

        -- Parse game state
        local gameState = {waveIndex = waveIndex}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end

        if not gameState.waveIndex then
            gameState.waveIndex = waveIndex
        end

        -- Filter encounters
        local validEncounters = filterEncountersByBiome(biomeId)
        validEncounters = filterByRequirements(validEncounters, gameState)

        local encountersCompleted = gameState.encountersCompleted or createEncountersCompletedState()
        validEncounters = filterByEncounterLimit(validEncounters, encountersCompleted)

        -- Calculate probabilities
        local probabilities, totalWeight = calculateProbabilities(validEncounters)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            TotalProbability = tostring(totalWeight),
            EncounterCount = tostring(#probabilities),
            BiomeId = tostring(biomeId),
            WaveIndex = tostring(waveIndex),
            Data = json.encode(probabilities)
        })
    end
)

print("Mystery Encounter Engine Process initialized - ADP v1.0 compliant")
