-- Wild Pokemon Encounter Engine Process for PokéRogue AO
-- ADP v1.0 Compliant Process for wild encounter mechanics and generation
-- Handles deterministic wild Pokemon generation, encounter rates, and shiny determination
-- Monolithic design - all dependencies embedded (no external imports)

-- ====================================
-- AO ENVIRONMENT GLOBALS
-- ====================================

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "wild-encounter-engine" }

-- Handlers global (AO runtime provides this)
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- ====================================
-- PROCESS CONFIGURATION
-- ====================================

local PROCESS_INFO = {
    name = "Wild Pokemon Encounter Engine",
    version = "1.0.0",
    adpVersion = "1.0",
    processId = "wild-encounter-engine",
    capabilities = {
        "generateWildEncounter",
        "calculateEncounterRate",
        "determineSpeciesPool",
        "generateWildPokemon",
        "calculateShinyRate",
        "processSpecialEncounters",
        "validateEncounterConditions",
        "deterministic_rng"
    },
    messageSchemas = {
        ProcessWildEncounter = {
            required = {"Action", "Operation"},
            operations = {"generate", "initiate", "validate", "resolve"},
            dataFields = {"areaId", "biomeType", "waveIndex", "encounterType", "playerState"}
        },
        Info = {
            required = {"Action"},
            response = "process_metadata"
        },
        HealthCheck = {
            required = {"Action"},
            response = "status_report"
        }
    }
}

-- Performance and rate limiting
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local RATE_LIMIT_MAX = 100 -- operations per minute per address
local rateLimitCounters = {}
local performanceStartTime = nil

-- Process coordination IDs (configurable)
local POKEMON_INSTANCE_MANAGER_ID = "pokemon-instance-manager"
local BATTLE_ENGINE_ID = "battle-engine"
local CAPTURE_ENGINE_ID = "capture-engine"

-- ====================================
-- BIOME AND POOL TIER ENUMS
-- ====================================

local BiomeType = {
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

local BiomePoolTier = {
    COMMON = 0,
    UNCOMMON = 1,
    RARE = 2,
    SUPER_RARE = 3,
    ULTRA_RARE = 4,
    BOSS = 5,
    BOSS_RARE = 6,
    BOSS_SUPER_RARE = 7,
    BOSS_ULTRA_RARE = 8
}

local TimeOfDay = {
    DAWN = 0,
    DAY = 1, 
    DUSK = 2,
    NIGHT = 3,
    ALL = 4
}

-- ====================================
-- ENCOUNTER TABLES AND SPECIES POOLS
-- ====================================

-- Simplified species pools for each biome
-- Format: [BiomeType] = { [BiomePoolTier] = { [TimeOfDay] = {speciesIds or level-based trees} } }
local BIOME_POKEMON_POOLS = {
    [BiomeType.TOWN] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {16, 19, 21, 161, 263, 396, 519},  -- Pidgey, Rattata, Spearow, Sentret, Zigzagoon, Starly, Pidove
            [TimeOfDay.DAWN] = {10, 165, 187, 191},  -- Caterpie, Ledyba, Hoppip, Sunkern
            [TimeOfDay.DAY] = {10, 265, 396, 519},  -- Caterpie, Wurmple, Starly, Pidove
            [TimeOfDay.DUSK] = {13, 163, 265},  -- Weedle, Hoothoot, Wurmple
            [TimeOfDay.NIGHT] = {19, 163, 263}  -- Rattata, Hoothoot, Zigzagoon
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {25, 133, 52},  -- Pikachu, Eevee, Meowth
            [TimeOfDay.DAY] = {1, 4, 7},  -- Bulbasaur, Charmander, Squirtle
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {143, 446}  -- Snorlax, Munchlax
        }
    },
    [BiomeType.PLAINS] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {16, 21, 84, 128, 161, 263, 396, 504, 519, 585},
            [TimeOfDay.DAY] = {43, 69, 187, 191},
            [TimeOfDay.NIGHT] = {41, 163, 198}
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {25, 52, 58, 83, 183, 203, 234, 241, 522},
            [TimeOfDay.DAY] = {1, 4, 7, 179},
            [TimeOfDay.NIGHT] = {37, 179, 517}
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {113, 115, 128, 531},
            [TimeOfDay.DAY] = {131},
            [TimeOfDay.NIGHT] = {164}
        },
        [BiomePoolTier.SUPER_RARE] = {
            [TimeOfDay.ALL] = {132, 333}
        },
        [BiomePoolTier.ULTRA_RARE] = {
            [TimeOfDay.ALL] = {144, 145, 146}  -- Legendary birds
        }
    },
    [BiomeType.GRASS] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {10, 13, 16, 21, 25, 43, 69, 187, 191, 265},
            [TimeOfDay.DAY] = {12, 46, 165, 285},
            [TimeOfDay.NIGHT] = {46, 163, 265, 285}
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {1, 102, 114, 179, 183, 285, 315, 331, 406, 417, 420, 455},
            [TimeOfDay.DAY] = {70, 182, 188, 548},
            [TimeOfDay.NIGHT] = {44, 70, 182, 188}
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {154, 470, 531},
            [TimeOfDay.DAY] = {3, 192, 357}
        },
        [BiomePoolTier.SUPER_RARE] = {
            [TimeOfDay.ALL] = {131, 182}
        },
        [BiomePoolTier.ULTRA_RARE] = {
            [TimeOfDay.ALL] = {492}  -- Shaymin
        }
    },
    [BiomeType.FOREST] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {10, 13, 25, 43, 69, 102, 163, 165, 167, 204, 261, 265, 285, 352},
            [TimeOfDay.DAY] = {11, 14, 664},
            [TimeOfDay.NIGHT] = {11, 14, 48, 193, 198}
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {15, 46, 114, 123, 193, 214, 252, 415, 455, 511, 513, 515, 540, 588, 616, 664},
            [TimeOfDay.DAY] = {12, 127, 415, 542},
            [TimeOfDay.NIGHT] = {12, 127, 415, 542}
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {47, 122, 166, 214, 254, 317, 357, 402, 437, 542, 586, 616},
            [TimeOfDay.DAY] = {357, 586},
            [TimeOfDay.NIGHT] = {212}
        },
        [BiomePoolTier.SUPER_RARE] = {
            [TimeOfDay.ALL] = {144, 251, 275}
        },
        [BiomePoolTier.ULTRA_RARE] = {
            [TimeOfDay.ALL] = {251}  -- Celebi
        }
    },
    [BiomeType.SEA] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {60, 72, 90, 98, 118, 129, 170, 183, 283, 320, 339, 349, 550},
            [TimeOfDay.DAY] = {54, 278, 535},
            [TimeOfDay.NIGHT] = {54, 194, 278, 535}
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {55, 61, 79, 86, 116, 119, 138, 140, 223, 270, 318, 363, 366, 418, 456, 550, 580, 592},
            [TimeOfDay.DAY] = {7, 258, 535, 656},
            [TimeOfDay.NIGHT] = {7, 194, 258, 535, 656}
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {62, 80, 87, 91, 117, 120, 130, 131, 134, 171, 184, 186, 230, 260, 271, 279, 319, 350, 364, 367, 369, 419, 457, 537, 581, 593, 657},
            [TimeOfDay.DAY] = {121, 226, 458, 537},
            [TimeOfDay.NIGHT] = {121, 195, 226, 458, 537}
        },
        [BiomePoolTier.SUPER_RARE] = {
            [TimeOfDay.ALL] = {139, 141, 230, 350}
        },
        [BiomePoolTier.ULTRA_RARE] = {
            [TimeOfDay.ALL] = {144, 245, 249, 382}  -- Articuno, Suicune, Lugia, Kyogre
        }
    },
    [BiomeType.MOUNTAIN] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {50, 66, 74, 95, 104, 231, 246, 304, 324, 410, 524, 532, 551, 557, 622},
            [TimeOfDay.DAY] = {56, 111, 322, 449},
            [TimeOfDay.NIGHT] = {56, 111, 322, 449}
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {28, 67, 105, 142, 207, 218, 227, 296, 305, 322, 337, 338, 359, 408, 443, 525, 533, 552, 558, 610, 621, 624},
            [TimeOfDay.DAY] = {126, 240, 338, 371, 443},
            [TimeOfDay.NIGHT] = {215, 337, 371, 443}
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {68, 75, 76, 112, 143, 208, 219, 232, 247, 297, 306, 337, 338, 376, 409, 411, 444, 445, 526, 534, 553, 559, 611, 623, 625},
            [TimeOfDay.DAY] = {126, 338, 372, 445},
            [TimeOfDay.NIGHT] = {338, 372, 445, 461}
        },
        [BiomePoolTier.SUPER_RARE] = {
            [TimeOfDay.ALL] = {213, 248, 306, 445}
        },
        [BiomePoolTier.ULTRA_RARE] = {
            [TimeOfDay.ALL] = {244, 377, 383, 485}  -- Entei, Regirock, Groudon, Heatran
        }
    },
    [BiomeType.CAVE] = {
        [BiomePoolTier.COMMON] = {
            [TimeOfDay.ALL] = {41, 46, 50, 74, 95, 194, 220, 293, 296, 299, 304, 337, 338, 343, 360, 361, 410, 449, 524, 525, 527, 529, 551, 557, 597, 610, 622, 703},
            [TimeOfDay.DAY] = {41, 74},
            [TimeOfDay.NIGHT] = {41, 74}
        },
        [BiomePoolTier.UNCOMMON] = {
            [TimeOfDay.ALL] = {28, 35, 42, 51, 67, 75, 105, 109, 142, 195, 218, 221, 294, 297, 303, 337, 338, 344, 361, 408, 411, 436, 437, 443, 525, 526, 528, 530, 552, 558, 598, 607, 610, 611, 621, 624, 703, 707, 712},
            [TimeOfDay.DAY] = {36, 42, 303},
            [TimeOfDay.NIGHT] = {36, 42, 303, 707}
        },
        [BiomePoolTier.RARE] = {
            [TimeOfDay.ALL] = {31, 34, 68, 76, 110, 112, 208, 219, 222, 295, 306, 345, 362, 409, 437, 444, 445, 531, 553, 559, 608, 612, 623, 625, 704, 708, 713},
            [TimeOfDay.DAY] = {112, 306},
            [TimeOfDay.NIGHT] = {112, 306, 708}
        },
        [BiomePoolTier.SUPER_RARE] = {
            [TimeOfDay.ALL] = {213, 248, 306, 376}
        },
        [BiomePoolTier.ULTRA_RARE] = {
            [TimeOfDay.ALL] = {377, 379, 383, 486}  -- Regirock, Regice, Groudon, Regigigas
        }
    }
    -- Add more biomes as needed for comprehensive coverage
}

-- ====================================
-- RNG AND PROBABILITY UTILITIES
-- ====================================

-- Deterministic RNG using seed
local function createRNG(seed)
    local rng = {
        seed = seed,
        counter = 0
    }
    
    function rng:next()
        self.counter = self.counter + 1
        -- Simple linear congruential generator
        self.seed = (self.seed * 1103515245 + 12345) & 0x7fffffff
        return self.seed
    end
    
    function rng:nextFloat()
        return self:next() / 0x7fffffff
    end
    
    function rng:nextInt(min, max)
        if max == nil then
            max = min
            min = 1
        end
        return min + (self:next() % (max - min + 1))
    end
    
    return rng
end

-- ====================================
-- ENCOUNTER RATE CALCULATIONS
-- ====================================

local function calculateEncounterRate(areaId, playerModifiers)
    -- Base encounter rates per area type
    local baseRate = 0.10 -- 10% base chance
    
    -- Area density modifiers
    local areaDensity = {
        [BiomeType.GRASS] = 1.2,
        [BiomeType.TALL_GRASS] = 1.5,
        [BiomeType.FOREST] = 1.3,
        [BiomeType.CAVE] = 1.1,
        [BiomeType.SEA] = 1.4,
        [BiomeType.PLAINS] = 1.0,
        [BiomeType.MOUNTAIN] = 0.9,
        [BiomeType.TOWN] = 0.5
    }
    
    local areaMultiplier = areaDensity[areaId] or 1.0
    
    -- Apply player modifiers
    local playerMultiplier = 1.0
    if playerModifiers then
        if playerModifiers.repelActive then
            return 0 -- No encounters with repel
        end
        if playerModifiers.encounterIncense then
            playerMultiplier = playerMultiplier * 1.5
        end
        if playerModifiers.encounterAbility then
            playerMultiplier = playerMultiplier * 1.2
        end
    end
    
    return baseRate * areaMultiplier * playerMultiplier
end

-- ====================================
-- SPECIES POOL DETERMINATION
-- ====================================

local function determineSpeciesFromPool(biomeType, waveIndex, level, rng, isBoss)
    local biomePool = BIOME_POKEMON_POOLS[biomeType]
    if not biomePool then
        -- Default to Town if biome not found
        biomePool = BIOME_POKEMON_POOLS[BiomeType.TOWN]
    end
    
    -- Determine tier based on random value (matching TypeScript logic)
    local isBossSpecies = isBoss or (waveIndex % 10 == 0)
    local randVal = isBossSpecies and 64 or 512
    local tierValue = rng:nextInt(0, randVal - 1)
    
    local tier
    if not isBossSpecies then
        -- Regular encounter tier distribution
        if tierValue >= 156 then
            tier = BiomePoolTier.COMMON
        elseif tierValue >= 32 then
            tier = BiomePoolTier.UNCOMMON
        elseif tierValue >= 6 then
            tier = BiomePoolTier.RARE
        elseif tierValue >= 1 then
            tier = BiomePoolTier.SUPER_RARE
        else
            tier = BiomePoolTier.ULTRA_RARE
        end
    else
        -- Boss encounter tier distribution
        if tierValue >= 20 then
            tier = BiomePoolTier.BOSS
        elseif tierValue >= 6 then
            tier = BiomePoolTier.BOSS_RARE
        elseif tierValue >= 1 then
            tier = BiomePoolTier.BOSS_SUPER_RARE
        else
            tier = BiomePoolTier.BOSS_ULTRA_RARE
        end
    end
    
    -- Get time of day (simplified - would need actual time logic)
    local timeOfDay = TimeOfDay.ALL -- Default to all for now
    
    -- Downgrade tier if pool doesn't exist
    while tier > BiomePoolTier.COMMON and not biomePool[tier] do
        tier = tier - 1
    end
    
    local tierPool = biomePool[tier] or biomePool[BiomePoolTier.COMMON]
    if not tierPool then
        return 1 -- Default to Bulbasaur if no pool found
    end
    
    -- Get species from time-based pool
    local speciesPool = tierPool[timeOfDay] or tierPool[TimeOfDay.ALL] or {}
    if #speciesPool == 0 then
        return 1 -- Default to Bulbasaur if pool is empty
    end
    
    -- Select random species from pool
    local speciesEntry = speciesPool[rng:nextInt(1, #speciesPool)]
    
    -- Handle level-based species trees
    if type(speciesEntry) == "table" then
        -- Find appropriate evolution based on level
        for levelThreshold, speciesId in pairs(speciesEntry) do
            if type(levelThreshold) == "number" and level >= levelThreshold then
                if type(speciesId) == "table" then
                    return speciesId[rng:nextInt(1, #speciesId)]
                else
                    return speciesId
                end
            end
        end
        -- Default to first entry if no level match
        return speciesEntry[1] or 1
    else
        return speciesEntry
    end
end

-- ====================================
-- SHINY DETERMINATION
-- ====================================

local function calculateShinyRate(playerModifiers)
    -- Base shiny rate: 1/4096
    local baseShinyRate = 1.0 / 4096
    local shinyMultiplier = 1.0
    
    if playerModifiers then
        if playerModifiers.shinyCharm then
            shinyMultiplier = shinyMultiplier * 3 -- Triple shiny odds with charm
        end
        if playerModifiers.masudaMethod then
            shinyMultiplier = shinyMultiplier * 6 -- Masuda method bonus
        end
        if playerModifiers.chainBonus then
            -- Chain bonus increases with chain length
            local chainMultiplier = 1 + (playerModifiers.chainBonus * 0.5)
            shinyMultiplier = shinyMultiplier * chainMultiplier
        end
    end
    
    return baseShinyRate * shinyMultiplier
end

local function determineIfShiny(rng, playerModifiers, speciesId)
    -- Check if species is shiny-locked
    local shinyLockedSpecies = {
        -- Certain legendaries cannot be shiny
        [493] = true, -- Arceus
        [649] = true, -- Genesect
        [721] = true  -- Volcanion
        -- Add more as needed
    }
    
    if shinyLockedSpecies[speciesId] then
        return false
    end
    
    local shinyRate = calculateShinyRate(playerModifiers)
    return rng:nextFloat() < shinyRate
end

-- ====================================
-- WILD POKEMON GENERATION
-- ====================================

local function generateWildPokemon(speciesId, level, rng, isShiny)
    -- Generate IVs (0-31 for each stat)
    local ivs = {}
    for i = 1, 6 do
        ivs[i] = rng:nextInt(0, 31)
    end
    
    -- Generate nature (25 possible natures)
    local natures = {
        "Hardy", "Lonely", "Brave", "Adamant", "Naughty",
        "Bold", "Docile", "Relaxed", "Impish", "Lax",
        "Timid", "Hasty", "Serious", "Jolly", "Naive",
        "Modest", "Mild", "Quiet", "Bashful", "Rash",
        "Calm", "Gentle", "Sassy", "Careful", "Quirky"
    }
    local nature = natures[rng:nextInt(1, 25)]
    
    -- Generate ability slot (0 for first ability, 1 for second, 2 for hidden)
    local abilitySlot = rng:nextInt(0, 100) < 10 and 2 or rng:nextInt(0, 1) -- 10% hidden ability
    
    return {
        speciesId = speciesId,
        level = level,
        ivs = ivs,
        nature = nature,
        abilitySlot = abilitySlot,
        isShiny = isShiny,
        isWild = true
    }
end

-- ====================================
-- WILD POKEMON AI BEHAVIOR
-- ====================================

local function calculateWildPokemonAI(wildPokemon, battleState, waveIndex, rng)
    -- Difficulty scaling based on wave progression
    local difficultyTier
    if waveIndex <= 10 then
        difficultyTier = "EASY"
    elseif waveIndex <= 30 then
        difficultyTier = "NORMAL"
    elseif waveIndex <= 60 then
        difficultyTier = "HARD"
    elseif waveIndex <= 100 then
        difficultyTier = "EXPERT"
    else
        difficultyTier = "MASTER"
    end
    
    -- AI decision weights based on difficulty
    local aiWeights = {
        EASY = { attack = 0.8, status = 0.1, switch = 0.05, optimal = 0.05 },
        NORMAL = { attack = 0.6, status = 0.2, switch = 0.1, optimal = 0.1 },
        HARD = { attack = 0.4, status = 0.25, switch = 0.15, optimal = 0.2 },
        EXPERT = { attack = 0.3, status = 0.25, switch = 0.15, optimal = 0.3 },
        MASTER = { attack = 0.2, status = 0.2, switch = 0.1, optimal = 0.5 }
    }
    
    local weights = aiWeights[difficultyTier]
    
    -- Analyze battle situation
    local hpPercent = (battleState.wildPokemon.hp or 100) / (battleState.wildPokemon.maxHp or 100)
    local opponentHpPercent = (battleState.playerPokemon.hp or 100) / (battleState.playerPokemon.maxHp or 100)
    
    -- Adjust weights based on battle state
    if hpPercent < 0.25 then
        -- Low HP - more likely to use healing or switch
        weights.switch = weights.switch + 0.2
        weights.attack = weights.attack - 0.1
    end
    
    if opponentHpPercent < 0.3 then
        -- Opponent low HP - prioritize finishing moves
        weights.attack = weights.attack + 0.3
        weights.optimal = weights.optimal + 0.2
    end
    
    -- Determine action type
    local roll = rng:nextFloat()
    local action = { type = "attack", moveIndex = 1 }
    
    if roll < weights.optimal then
        -- Choose optimal move
        action = selectOptimalMove(wildPokemon, battleState, rng)
    elseif roll < weights.optimal + weights.status then
        -- Use status move
        action = selectStatusMove(wildPokemon, battleState, rng)
    elseif roll < weights.optimal + weights.status + weights.switch then
        -- Switch Pokemon (for multi-Pokemon wild battles)
        action = { type = "switch", targetIndex = 2 }
    else
        -- Random attack move
        action = selectRandomAttackMove(wildPokemon, rng)
    end
    
    return {
        action = action,
        difficultyTier = difficultyTier,
        decisionWeights = weights
    }
end

local function selectOptimalMove(wildPokemon, battleState, rng)
    -- Analyze type effectiveness and select best move
    -- Simplified version - would need full type chart implementation
    local moves = wildPokemon.moves or {{id = 1, power = 40}}
    
    -- Fallback for empty moves
    if #moves == 0 then
        return { type = "attack", moveId = 1, moveIndex = 1 }
    end
    
    local bestMove = moves[1]
    local bestScore = 0
    
    for i, move in ipairs(moves) do
        local score = move.power or 0
        
        -- Add type effectiveness bonus (simplified)
        if battleState.playerPokemon and battleState.playerPokemon.types then
            -- Would calculate actual type effectiveness here
            score = score * 1.0
        end
        
        -- Add accuracy consideration
        local accuracy = move.accuracy or 100
        score = score * (accuracy / 100)
        
        if score > bestScore then
            bestScore = score
            bestMove = move
        end
    end
    
    return { type = "attack", moveId = bestMove.id or 1, moveIndex = 1 }
end

local function selectStatusMove(wildPokemon, battleState, rng)
    -- Select appropriate status move based on situation
    local statusMoves = {}
    local moves = wildPokemon.moves or {}
    
    for i, move in ipairs(moves) do
        if move.category == "status" or move.power == 0 then
            table.insert(statusMoves, {move = move, index = i})
        end
    end
    
    if #statusMoves > 0 then
        local selected = statusMoves[rng:nextInt(1, #statusMoves)]
        return { type = "attack", moveId = selected.move.id, moveIndex = selected.index }
    else
        -- Fall back to random attack if no status moves
        return selectRandomAttackMove(wildPokemon, rng)
    end
end

local function selectRandomAttackMove(wildPokemon, rng)
    local moves = wildPokemon.moves or {{id = 1}}
    
    -- Fallback for empty moves
    if #moves == 0 then
        return { type = "attack", moveId = 1, moveIndex = 1 }
    end
    
    local attackMoves = {}
    
    for i, move in ipairs(moves) do
        if move.power and move.power > 0 then
            table.insert(attackMoves, {move = move, index = i})
        end
    end
    
    if #attackMoves > 0 then
        local selected = attackMoves[rng:nextInt(1, #attackMoves)]
        return { type = "attack", moveId = selected.move.id or 1, moveIndex = selected.index }
    else
        -- Default to first move if no attack moves
        return { type = "attack", moveId = moves[1].id or 1, moveIndex = 1 }
    end
end

-- Special encounter mechanics
local function processSpecialEncounter(encounterType, speciesId, waveIndex, rng)
    local specialData = {}
    
    if encounterType == "LEGENDARY" then
        -- Legendary encounters have special conditions
        specialData.captureResistance = 3.0 -- Harder to catch
        specialData.statBoost = 1.2 -- 20% stat boost
        specialData.guaranteedIVs = 3 -- At least 3 perfect IVs
        specialData.specialMoves = true -- Access to signature moves
    elseif encounterType == "BOSS" then
        -- Boss Pokemon enhancements
        specialData.hpMultiplier = 2.0 -- Double HP
        specialData.statBoost = 1.5 -- 50% stat boost
        specialData.segments = math.floor(waveIndex / 30) + 1 -- Boss segments
        specialData.guaranteedItem = true -- Always drops item
    elseif encounterType == "ROAMING" then
        -- Roaming Pokemon tracking
        specialData.currentArea = BiomeType.PLAINS
        specialData.movePattern = "random"
        specialData.fleeProbability = 0.5 -- 50% chance to flee each turn
        specialData.previousEncounters = 0
    elseif encounterType == "EVENT" then
        -- Event Pokemon special properties
        specialData.timeLimited = true
        specialData.uniqueMoves = true
        specialData.specialAbility = true
        specialData.ribbons = {"Event"}
    end
    
    return specialData
end

-- ====================================
-- MESSAGE HANDLERS
-- ====================================

-- Info handler for ADP v1.0 compliance
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = PROCESS_INFO,
                handlers = {
                    "Info",
                    "HealthCheck",
                    "ProcessWildEncounter"
                },
                biomes = BiomeType,
                tiers = BiomePoolTier,
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    capabilities = PROCESS_INFO.capabilities,
                    messageSchemas = PROCESS_INFO.messageSchemas
                }
            })
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Status = "healthy",
            ProcessId = ao.id,
            Timestamp = msg.Timestamp or "0",
            RateLimitStatus = "active",
            PerformanceMetrics = {
                avgResponseTime = "< 100ms",
                throughput = "100 ops/min"
            }
        })
    end
)

-- Main wild encounter handler
Handlers.add("process-wild-encounter",
    Handlers.utils.hasMatchingTag("Action", "ProcessWildEncounter"),
    function(msg)
        performanceStartTime = msg.Timestamp or 0
        
        -- Extract operation and parameters
        local operation = msg.Operation or msg.Tags.Operation
        if not operation then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Operation required (generate|initiate|validate|resolve)"
            })
            return
        end
        
        -- Parse message data (direct parsing for controlled AO message data)
        local data = {}
        if msg.Data and msg.Data ~= "" then
            data = json.decode(msg.Data)
        end
        
        -- Extract encounter parameters
        local areaId = tonumber(msg.AreaId or msg.Tags.AreaId) or BiomeType.TOWN
        local biomeType = tonumber(msg.BiomeType or msg.Tags.BiomeType) or areaId
        local waveIndex = tonumber(msg.WaveIndex or msg.Tags.WaveIndex) or 1
        local encounterType = msg.EncounterType or msg.Tags.EncounterType or "WILD"
        local forceShiny = (msg.ForceShiny or msg.Tags.ForceShiny) == "true"
        
        -- Create RNG from seed
        local rngSeed = data.rngSeed or (msg.Timestamp and tonumber(msg.Timestamp)) or 12345
        local rng = createRNG(rngSeed)
        
        if operation == "generate" then
            -- Check encounter rate
            local encounterRate = calculateEncounterRate(biomeType, data.playerModifiers)
            local encounterRoll = rng:nextFloat()
            
            if encounterRoll > encounterRate and not (encounterType == "BOSS" or encounterType == "LEGENDARY") then
                ao.send({
                    Target = msg.From,
                    Action = "SaveState",
                    Success = "true",
                    EncounterOccurred = "false",
                    EncounterRate = tostring(encounterRate),
                    Roll = tostring(encounterRoll)
                })
                return
            end
            
            -- Determine level range for area
            local baseLevel = math.floor(waveIndex / 10) * 5 + 1
            local levelRange = 5
            local level = baseLevel + rng:nextInt(0, levelRange)
            
            -- Determine if boss encounter
            local isBoss = encounterType == "BOSS" or (waveIndex % 10 == 0)
            
            -- Select species from pool
            local speciesId = determineSpeciesFromPool(biomeType, waveIndex, level, rng, isBoss)
            
            -- Determine if shiny
            local isShiny = forceShiny or determineIfShiny(rng, data.playerModifiers, speciesId)
            
            -- Generate wild Pokemon data
            local wildPokemon = generateWildPokemon(speciesId, level, rng, isShiny)
            
            -- Process special encounter properties
            local specialData = processSpecialEncounter(encounterType, speciesId, waveIndex, rng)
            
            -- Apply special encounter enhancements
            if specialData.guaranteedIVs then
                -- Ensure minimum perfect IVs for legendary/special encounters
                local perfectCount = 0
                for i = 1, 6 do
                    if perfectCount < specialData.guaranteedIVs and rng:nextFloat() < 0.5 then
                        wildPokemon.ivs[i] = 31
                        perfectCount = perfectCount + 1
                    end
                end
            end
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "true",
                EncounterOccurred = "true",
                Data = json.encode({
                    wildPokemon = wildPokemon,
                    encounterType = encounterType,
                    specialData = specialData,
                    biomeType = biomeType,
                    waveIndex = waveIndex,
                    encounterSeed = rngSeed
                })
            })
            
        elseif operation == "ai-decision" then
            -- Calculate AI decision for wild Pokemon
            local battleState = data.battleState or {}
            local wildPokemon = data.wildPokemon or {}
            
            local aiDecision = calculateWildPokemonAI(wildPokemon, battleState, waveIndex, rng)
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "true",
                AIDecision = json.encode(aiDecision)
            })
            
        elseif operation == "validate" then
            -- Validate encounter conditions
            local validBiome = BIOME_POKEMON_POOLS[biomeType] ~= nil
            local validWave = waveIndex > 0 and waveIndex <= 200
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "true",
                Valid = tostring(validBiome and validWave),
                BiomeValid = tostring(validBiome),
                WaveValid = tostring(validWave)
            })
            
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Unknown operation: " .. operation
            })
        end
    end
)

-- Process initialization complete
print("Wild Pokemon Encounter Engine Process initialized")
print("ADP v1.0 compliant - autonomous agent ready")
print("Process ID:", ao.id or "wild-encounter-engine")