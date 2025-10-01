-- trainer-data-engine.lua
-- AO Process: Trainer Configuration Data Repository
-- Purpose: Embedded trainer data, signature species, biome pools, party templates
-- ADP v1.0 Compliant - Self-documenting process
-- Size Target: ~300-350KB (data-heavy, logic-light)

local json = require("json")

-- ============================================================================
-- ENUMS AND CONSTANTS
-- ============================================================================

-- TrainerType Enum (300+ trainer types)
local TrainerType = {
    UNKNOWN = 0,
    ACE_TRAINER = 1,
    ARTIST = 2,
    BACKPACKER = 3,
    BAKER = 4,
    BATTLE_GIRL = 5,
    BEAUTY = 6,
    BIKER = 7,
    BLACK_BELT = 8,
    BREEDER = 9,
    CLERK = 10,
    CYCLIST = 11,
    DANCER = 12,
    DEPOT_AGENT = 13,
    DOCTOR = 14,
    FISHERMAN = 15,
    GUITARIST = 16,
    HARLEQUIN = 17,
    HIKER = 18,
    HOOLIGANS = 19,
    HOOPSTER = 20,
    INFIELDER = 21,
    JANITOR = 22,
    LASS = 23,
    LINEBACKER = 24,
    MAID = 25,
    MUSICIAN = 26,
    NURSE = 27,
    OFFICER = 28,
    PARASOL_LADY = 29,
    PILOT = 30,
    POKEFAN = 31,
    PRESCHOOLER = 32,
    PSYCHIC = 33,
    RANGER = 34,
    RICH = 35,
    RICH_KID = 36,
    ROUGHNECK = 37,
    SCIENTIST = 38,
    SMASHER = 39,
    SNOW_WORKER = 40,
    STRIKER = 41,
    SCHOOL_KID = 42,
    SWIMMER = 43,
    TWINS = 44,
    VETERAN = 45,
    WAITER = 46,
    WAITRESS = 47,
    WORKER = 48,
    YOUNGSTER = 49,
    HEX_MANIAC = 50,
    PSYCHIC_F = 51,
    CAMPER = 52,
    PICNICKER = 53,
    BUG_CATCHER = 54,
    SAILOR = 55,
    COLLECTOR = 56,
    SUPER_NERD = 57,
    CHANNELER = 58,
    TUBER_F = 59,
    TUBER_M = 60,
    AROMA_LADY = 61,
    RUIN_MANIAC = 62,
    LADY = 63,
    PAINTER = 64,
    GENTLEMAN = 65,
    INTERVIEWER = 66,
    BIRD_KEEPER = 67,
    DRAGON_TAMER = 68,
    POKEMON_RANGER = 69,
    POKEMON_BREEDER = 70,
    -- Gym Leaders
    BROCK = 201,
    MISTY = 202,
    LT_SURGE = 203,
    ERIKA = 204,
    SABRINA = 205,
    KOGA = 206,
    BLAINE = 207,
    GIOVANNI = 208,
    FALKNER = 209,
    BUGSY = 210,
    WHITNEY = 211,
    MORTY = 212,
    CHUCK = 213,
    JASMINE = 214,
    PRYCE = 215,
    CLAIR = 216,
    ROXANNE = 217,
    BRAWLY = 218,
    WATTSON = 219,
    FLANNERY = 220,
    NORMAN = 221,
    WINONA = 222,
    TATE = 223,
    LIZA = 224,
    JUAN = 225,
    ROARK = 226,
    GARDENIA = 227,
    MAYLENE = 228,
    CRASHER_WAKE = 229,
    FANTINA = 230,
    BYRON = 231,
    CANDICE = 232,
    VOLKNER = 233,
    CILAN = 234,
    CHILI = 235,
    CRESS = 236,
    CHEREN = 237,
    LENORA = 238,
    ROXIE = 239,
    BURGH = 240,
    ELESA = 241,
    CLAY = 242,
    SKYLA = 243,
    BRYCEN = 244,
    DRAYDEN = 245,
    MARLON = 246,
    VIOLA = 247,
    GRANT = 248,
    KORRINA = 249,
    RAMOS = 250,
    CLEMONT = 251,
    VALERIE = 252,
    OLYMPIA = 253,
    WULFRIC = 254,
    MILO = 255,
    NESSA = 256,
    KABU = 257,
    BEA = 258,
    ALLISTER = 259,
    OPAL = 260,
    GORDIE = 261,
    MELONY = 262,
    PIERS = 263,
    RAIHAN = 264,
    -- Elite Four
    LORELEI = 301,
    BRUNO = 302,
    AGATHA = 303,
    LANCE = 304,
    WILL = 305,
    KOGA_ELITE = 306,
    KAREN = 307,
    SIDNEY = 308,
    PHOEBE = 309,
    GLACIA = 310,
    DRAKE = 311,
    AARON = 312,
    BERTHA = 313,
    FLINT = 314,
    LUCIAN = 315,
    SHAUNTAL = 316,
    GRIMSLEY = 317,
    CAITLIN = 318,
    MARSHAL = 319,
    MALVA = 320,
    SIEBOLD = 321,
    WIKSTROM = 322,
    DRASNA = 323,
    -- Champions
    BLUE = 401,
    RED = 402,
    LANCE_CHAMPION = 403,
    STEVEN = 404,
    WALLACE = 405,
    CYNTHIA = 406,
    ALDER = 407,
    IRIS = 408,
    DIANTHA = 409,
    HAU = 410,
    LEON = 411,
    -- Evil Team
    ROCKET_GRUNT = 501,
    ROCKET_GRUNT_F = 502,
    MAGMA_GRUNT = 503,
    MAGMA_GRUNT_F = 504,
    AQUA_GRUNT = 505,
    AQUA_GRUNT_F = 506,
    GALACTIC_GRUNT = 507,
    GALACTIC_GRUNT_F = 508,
    PLASMA_GRUNT = 509,
    PLASMA_GRUNT_F = 510,
    FLARE_GRUNT = 511,
    FLARE_GRUNT_F = 512,
    -- Evil Team Admins
    ARCHER = 601,
    ARIANA = 602,
    PROTON = 603,
    PETREL = 604,
    TABITHA = 605,
    COURTNEY = 606,
    SHELLY = 607,
    MATT = 608,
    MARS = 609,
    JUPITER = 610,
    SATURN = 611,
    -- Evil Team Bosses
    GIOVANNI_BOSS = 701,
    MAXIE = 702,
    ARCHIE = 703,
    CYRUS = 704,
    GHETSIS = 705,
    LYSANDRE = 706
}

-- TrainerPoolTier Enum (Rarity tiers for species selection)
local TrainerPoolTier = {
    COMMON = 0,      -- 69.5% (356/512 weighted)
    UNCOMMON = 1,    -- 24.2% (124/512)
    RARE = 2,        --  5.1% (26/512)
    SUPER_RARE = 3,  --  1.0% (5/512)
    ULTRA_RARE = 4   --  0.2% (1/512)
}

-- TrainerVariant Enum
local TrainerVariant = {
    DEFAULT = 0,   -- Male or genderless
    FEMALE = 1,    -- Female variant
    DOUBLE = 2     -- Double battle
}

-- PartyMemberStrength Enum
local PartyMemberStrength = {
    WEAKEST = 0,   -- 0.90x multiplier
    WEAKER = 1,    -- 0.95x multiplier
    WEAK = 2,      -- 1.00x multiplier (base)
    AVERAGE = 3,   -- 1.10x multiplier
    STRONG = 4,    -- 1.20x multiplier
    STRONGER = 5   -- 1.25x multiplier
}

-- TeraAIMode Enum
local TeraAIMode = {
    NO_TERA = 0,      -- Cannot terastallize
    INSTANT_TERA = 1, -- Immediately tera on first move
    SMART_TERA = 2    -- Strategic tera based on matchup
}

-- BiomeId Enum (subset for trainer pools)
local BiomeId = {
    PLAINS = 0,
    GRASS = 1,
    TALL_GRASS = 2,
    METROPOLIS = 3,
    FOREST = 4,
    SEA = 5,
    SWAMP = 6,
    BEACH = 7,
    LAKE = 8,
    SEABED = 9,
    MOUNTAIN = 10,
    BADLANDS = 11,
    CAVE = 12,
    DESERT = 13,
    ICE_CAVE = 14,
    MEADOW = 15,
    POWER_PLANT = 16,
    VOLCANO = 17,
    GRAVEYARD = 18,
    DOJO = 19,
    FACTORY = 20,
    RUINS = 21,
    WASTELAND = 22,
    ABYSS = 23,
    SPACE = 24,
    CONSTRUCTION_SITE = 25,
    JUNGLE = 26,
    FAIRY_CAVE = 27,
    TEMPLE = 28,
    SLUM = 29,
    SNOWY_FOREST = 30,
    ISLAND = 31,
    LABORATORY = 32,
    END = 33
}

-- ============================================================================
-- TRAINER CONFIGURATION DATABASE
-- ============================================================================

-- TrainerConfig data structure
-- NOTE: This will be populated with 300+ trainer configurations
-- For now, implementing core structure with sample data
local trainerConfigs = {
    [TrainerType.ACE_TRAINER] = {
        trainerType = TrainerType.ACE_TRAINER,
        name = "Ace Trainer",
        hasGenders = true,
        moneyMultiplier = 2.5,
        isBoss = false,
        hasStaticParty = false,
        partyTemplates = {
            {size = 3, strength = PartyMemberStrength.AVERAGE, sameSpecies = false, balanced = false}
        },
        speciesPools = {
            [TrainerPoolTier.COMMON] = {},
            [TrainerPoolTier.UNCOMMON] = {},
            [TrainerPoolTier.RARE] = {},
            [TrainerPoolTier.SUPER_RARE] = {},
            [TrainerPoolTier.ULTRA_RARE] = {}
        },
        trainerAI = {
            teraMode = TeraAIMode.NO_TERA,
            instantTeras = {}
        }
    },

    [TrainerType.BROCK] = {
        trainerType = TrainerType.BROCK,
        name = "Gym Leader Brock",
        title = "Gym Leader",
        hasGenders = false,
        moneyMultiplier = 10.0,
        isBoss = true,
        hasStaticParty = true,
        specialtyType = 6, -- ROCK type
        partyTemplates = {
            {size = 4, strength = PartyMemberStrength.STRONG, sameSpecies = false, balanced = false}
        },
        trainerAI = {
            teraMode = TeraAIMode.SMART_TERA,
            instantTeras = {}
        }
    },

    [TrainerType.YOUNGSTER] = {
        trainerType = TrainerType.YOUNGSTER,
        name = "Youngster",
        hasGenders = false,
        moneyMultiplier = 0.5,
        isBoss = false,
        hasStaticParty = false,
        partyTemplates = {
            {size = 1, strength = PartyMemberStrength.WEAK, sameSpecies = false, balanced = false},
            {size = 2, strength = PartyMemberStrength.WEAK, sameSpecies = false, balanced = false}
        },
        trainerAI = {
            teraMode = TeraAIMode.NO_TERA,
            instantTeras = {}
        }
    }

    -- NOTE: 297+ more trainer configs will be added in Task 2A
}

-- ============================================================================
-- SIGNATURE SPECIES DATABASE
-- ============================================================================

-- Signature species for gym leaders, elite four, champions
local signatureSpecies = {
    [TrainerType.BROCK] = {
        95,  -- Onix
        74,  -- Geodude
        {138, 140}, -- {Omanyte, Kabuto} - choice array
        142  -- Aerodactyl
    },

    [TrainerType.MISTY] = {
        120, -- Staryu
        54,  -- Psyduck
        {90, 98}, -- {Shellder, Krabby}
        121  -- Starmie
    },

    [TrainerType.RED] = {
        25,  -- Pikachu
        196, -- Espeon
        143, -- Snorlax
        3,   -- Venusaur
        6,   -- Charizard
        9    -- Blastoise
    }

    -- NOTE: 47+ more signature species mappings will be added in Task 2A
}

-- ============================================================================
-- BIOME TRAINER POOLS DATABASE
-- ============================================================================

-- Trainer pools per biome with rarity tiers
local biomeTrainerPools = {
    [BiomeId.PLAINS] = {
        commonPool = {
            TrainerType.YOUNGSTER,
            TrainerType.LASS,
            TrainerType.SCHOOL_KID,
            TrainerType.BREEDER,
            TrainerType.CAMPER,
            TrainerType.PICNICKER
        },
        rarePool = {
            TrainerType.ACE_TRAINER,
            TrainerType.VETERAN
        },
        superRarePool = {}
    },

    [BiomeId.FOREST] = {
        commonPool = {
            TrainerType.BUG_CATCHER,
            TrainerType.RANGER,
            TrainerType.TWINS,
            TrainerType.POKEMON_RANGER
        },
        rarePool = {
            TrainerType.ACE_TRAINER,
            TrainerType.HEX_MANIAC
        },
        superRarePool = {}
    },

    [BiomeId.METROPOLIS] = {
        commonPool = {
            TrainerType.CLERK,
            TrainerType.GUITARIST,
            TrainerType.BAKER,
            TrainerType.OFFICER
        },
        rarePool = {
            TrainerType.ACE_TRAINER,
            TrainerType.VETERAN
        },
        superRarePool = {}
    }

    -- NOTE: 30+ more biome pools will be added in Task 2A
}

-- ============================================================================
-- PARTY TEMPLATE DEFINITIONS
-- ============================================================================

-- Named party templates for consistent trainer party structures
local partyTemplates = {
    TWO_WEAK = {size = 2, strength = PartyMemberStrength.WEAK},
    TWO_AVG = {size = 2, strength = PartyMemberStrength.AVERAGE},
    THREE_WEAK = {size = 3, strength = PartyMemberStrength.WEAK},
    THREE_AVG = {size = 3, strength = PartyMemberStrength.AVERAGE},
    FOUR_WEAK_BALANCED = {size = 4, strength = PartyMemberStrength.WEAK, balanced = true},
    FOUR_AVG = {size = 4, strength = PartyMemberStrength.AVERAGE},
    FIVE_AVG = {size = 5, strength = PartyMemberStrength.AVERAGE},
    SIX_AVG = {size = 6, strength = PartyMemberStrength.AVERAGE},
    SIX_STRONG = {size = 6, strength = PartyMemberStrength.STRONG},

    -- Gym Leader templates
    GYM_LEADER_1 = {size = 2, strength = PartyMemberStrength.AVERAGE},
    GYM_LEADER_2 = {size = 3, strength = PartyMemberStrength.AVERAGE},
    GYM_LEADER_3 = {size = 4, strength = PartyMemberStrength.STRONG},
    GYM_LEADER_4 = {size = 5, strength = PartyMemberStrength.STRONG},
    GYM_LEADER_5 = {size = 6, strength = PartyMemberStrength.STRONGER},

    -- Elite Four templates
    ELITE_FOUR = {size = 6, strength = PartyMemberStrength.STRONGER},

    -- Champion templates
    CHAMPION = {size = 6, strength = PartyMemberStrength.STRONGER}
}

-- ============================================================================
-- LOOKUP FUNCTIONS
-- ============================================================================

-- Get trainer configuration by type
local function getTrainerConfig(trainerTypeId)
    if not trainerTypeId then
        return nil, "TrainerType required"
    end

    local config = trainerConfigs[tonumber(trainerTypeId)]
    if not config then
        return nil, "Trainer config not found for type: " .. tostring(trainerTypeId)
    end

    return config, nil
end

-- Get signature species for trainer
local function getSignatureSpecies(trainerTypeId)
    if not trainerTypeId then
        return nil, "TrainerType required"
    end

    local species = signatureSpecies[tonumber(trainerTypeId)]
    return species, nil -- Can be nil for non-signature trainers
end

-- Get biome trainer pool
local function getBiomeTrainerPool(biomeId)
    if not biomeId then
        return nil, "BiomeId required"
    end

    local pool = biomeTrainerPools[tonumber(biomeId)]
    if not pool then
        return nil, "Biome pool not found for biome: " .. tostring(biomeId)
    end

    return pool, nil
end

-- Get party template by name
local function getPartyTemplate(templateName)
    if not templateName then
        return nil, "Template name required"
    end

    local template = partyTemplates[templateName]
    if not template then
        return nil, "Party template not found: " .. tostring(templateName)
    end

    return template, nil
end

-- Validate trainer type exists
local function validateTrainerType(trainerTypeId, biomeId)
    if not trainerTypeId then
        return false, "TrainerType required"
    end

    local config, err = getTrainerConfig(trainerTypeId)
    if err then
        return false, err
    end

    -- If biome provided, check if trainer appears in that biome
    if biomeId then
        local pool, poolErr = getBiomeTrainerPool(biomeId)
        if poolErr then
            return false, poolErr
        end

        -- Check all pools for trainer type
        local typeId = tonumber(trainerTypeId)
        for _, trainerType in ipairs(pool.commonPool or {}) do
            if trainerType == typeId then
                return true, nil, TrainerPoolTier.COMMON
            end
        end
        for _, trainerType in ipairs(pool.rarePool or {}) do
            if trainerType == typeId then
                return true, nil, TrainerPoolTier.UNCOMMON
            end
        end
        for _, trainerType in ipairs(pool.superRarePool or {}) do
            if trainerType == typeId then
                return true, nil, TrainerPoolTier.RARE
            end
        end

        return false, "Trainer type not in biome pool"
    end

    return true, nil, nil
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Info Handler (ADP v1.0 Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    id = ao.id,
                    name = "Trainer Data Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    purpose = "Trainer configuration data repository",
                    capabilities = {
                        "trainer_config_lookup",
                        "signature_species_lookup",
                        "biome_trainer_pools",
                        "party_template_lookup",
                        "trainer_validation"
                    },
                    messageSchemas = {
                        GetTrainerConfig = {
                            required = {"Action", "TrainerType"}
                        },
                        GetSignatureSpecies = {
                            required = {"Action", "TrainerType"}
                        },
                        GetBiomeTrainerPool = {
                            required = {"Action", "BiomeType"}
                        },
                        ValidateTrainerType = {
                            required = {"Action", "TrainerType"}
                        }
                    }
                },
                handlers = {
                    "Info",
                    "GetTrainerConfig",
                    "GetSignatureSpecies",
                    "GetBiomeTrainerPool",
                    "GetPartyTemplate",
                    "ValidateTrainerType"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    processType = "data_repository",
                    dataSize = "~300-350KB",
                    trainerTypes = "300+",
                    biomes = "33+"
                }
            }),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- GetTrainerConfig Handler
Handlers.add("get-trainer-config",
    Handlers.utils.hasMatchingTag("Action", "GetTrainerConfig"),
    function(msg)
        local trainerType = msg.TrainerType

        if not trainerType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TrainerType required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local config, err = getTrainerConfig(trainerType)

        if err then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err,
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "TrainerConfigResponse",
            Data = json.encode(config),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- GetSignatureSpecies Handler
Handlers.add("get-signature-species",
    Handlers.utils.hasMatchingTag("Action", "GetSignatureSpecies"),
    function(msg)
        local trainerType = msg.TrainerType

        if not trainerType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TrainerType required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local species, err = getSignatureSpecies(trainerType)

        if err then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err,
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SignatureSpeciesResponse",
            Data = json.encode({signatureSpecies = species}),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- GetBiomeTrainerPool Handler
Handlers.add("get-biome-trainer-pool",
    Handlers.utils.hasMatchingTag("Action", "GetBiomeTrainerPool"),
    function(msg)
        local biomeType = msg.BiomeType

        if not biomeType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BiomeType required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local pool, err = getBiomeTrainerPool(biomeType)

        if err then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err,
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "BiomeTrainerPoolResponse",
            Data = json.encode(pool),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- GetPartyTemplate Handler
Handlers.add("get-party-template",
    Handlers.utils.hasMatchingTag("Action", "GetPartyTemplate"),
    function(msg)
        local templateName = msg.TemplateName

        if not templateName then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TemplateName required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local template, err = getPartyTemplate(templateName)

        if err then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err,
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "PartyTemplateResponse",
            Data = json.encode(template),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- ValidateTrainerType Handler
Handlers.add("validate-trainer-type",
    Handlers.utils.hasMatchingTag("Action", "ValidateTrainerType"),
    function(msg)
        local trainerType = msg.TrainerType
        local biomeType = msg.BiomeType

        if not trainerType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TrainerType required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local valid, err, tier = validateTrainerType(trainerType, biomeType)

        if err then
            ao.send({
                Target = msg.From,
                Action = "ValidationResponse",
                Valid = "false",
                Error = err,
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "ValidationResponse",
            Valid = tostring(valid),
            Tier = tier and tostring(tier) or "",
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- Process initialization
print("Trainer Data Engine initialized - ADP v1.0 compliant")
print("Embedded trainer configs: " .. tostring(#trainerConfigs or 3) .. " (partial - awaiting Task 2A)")
print("Ready to serve trainer configuration data")
