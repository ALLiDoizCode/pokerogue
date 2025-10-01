-- trainer-encounter-engine.lua
-- AO Process: Trainer Encounter Logic Engine
-- Purpose: Trainer generation algorithms, AI logic, matchup scoring, reward calculation
-- ADP v1.0 Compliant - Self-documenting process
-- Size Target: ~100-150KB (logic-heavy, data-light)

local json = require("json")

-- ============================================================================
-- PROCESS CONFIGURATION
-- ============================================================================

-- Reference to external processes (to be configured at deployment)
local TRAINER_DATA_ENGINE_PROCESS = "TRAINER_DATA_ENGINE_ID" -- Replace with actual process ID
local POKEMON_SPECIES_DB_PROCESS = "pokemon-species-db" -- Species database process
local MOVES_DATABASE_PROCESS = "moves-database-adp" -- Moves database process

-- ============================================================================
-- CONSTANTS AND ENUMS
-- ============================================================================

-- PartyMemberStrength multipliers
local STRENGTH_MULTIPLIERS = {
    [0] = 0.90,  -- WEAKEST
    [1] = 0.95,  -- WEAKER
    [2] = 1.00,  -- WEAK
    [3] = 1.10,  -- AVERAGE
    [4] = 1.20,  -- STRONG
    [5] = 1.25   -- STRONGER
}

-- Progressive scaling constants
local PROGRESSIVE_SCALE_START = 2  -- Start at strength 2 (WEAK)
local PROGRESSIVE_SCALE_BONUS = 0.025
local PROGRESSIVE_SCALE_MAX = 1.2

-- Money reward base constants
local MONEY_BASE_MULTIPLIER = 10

-- Item modifier chance constants
local BASE_MODIFIER_CHANCE = 0.75
local MODIFIER_CHANCE_REDUCTION = 0.75

-- AI switch threshold multipliers
local REGULAR_TRAINER_SWITCH_MULTIPLIER = 3
local BOSS_TRAINER_SWITCH_MULTIPLIER = 2
local SWITCH_COUNTER_PENALTY = 0.1

-- Speed multiplier for matchup score
local SPEED_ADVANTAGE_MULTIPLIER = 1.25

-- Trainer pool tier weights (512 total)
local TIER_WEIGHTS = {
    [0] = 356,  -- COMMON: 69.5%
    [1] = 124,  -- UNCOMMON: 24.2%
    [2] = 26,   -- RARE: 5.1%
    [3] = 5,    -- SUPER_RARE: 1.0%
    [4] = 1     -- ULTRA_RARE: 0.2%
}

-- Biome pool distribution weights
local BIOME_POOL_WEIGHTS = {
    common = 80,      -- 80%
    rare = 15,        -- 15%
    superRare = 5     -- 5%
}

-- Gym Leader and Elite Four constants
local GYM_LEADER_TERA_WAVE = 100  -- Wave threshold for gym leader Terastallization
local ELITE_FOUR_MINIMUM_BST = 460  -- Minimum base stat total for Elite Four Pokemon

-- Gym Leader money multipliers (from TypeScript trainer-config.ts line 677)
local GYM_LEADER_MONEY_MULTIPLIER = 2.5
local ELITE_FOUR_MONEY_MULTIPLIER = 3.25
local CHAMPION_MONEY_MULTIPLIER = 10.0

-- PartyMemberStrength enum mapping (for compound templates)
local PartyMemberStrength = {
    WEAKEST = 0,
    WEAKER = 1,
    WEAK = 2,
    AVERAGE = 3,
    STRONG = 4,
    STRONGER = 5
}

-- Pokemon Type IDs (from TypeScript type enum)
local PokemonType = {
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 9,
    WATER = 10,
    GRASS = 11,
    ELECTRIC = 12,
    PSYCHIC = 13,
    ICE = 14,
    DRAGON = 15,
    DARK = 16,
    FAIRY = 17
}

-- Fixed Gym Leader Encounters (from story requirements)
-- Kanto gym leaders appearing at specific waves with specialty types
local GYM_LEADER_ENCOUNTERS = {
    [20] = {name = "Brock", specialtyType = PokemonType.ROCK},
    [30] = {name = "Misty", specialtyType = PokemonType.WATER},
    [40] = {name = "Lt. Surge", specialtyType = PokemonType.ELECTRIC},
    [50] = {name = "Erika", specialtyType = PokemonType.GRASS},
    [60] = {name = "Janine", specialtyType = PokemonType.POISON},
    [80] = {name = "Sabrina", specialtyType = PokemonType.PSYCHIC},
    [100] = {name = "Blaine", specialtyType = PokemonType.FIRE},
    [120] = {name = "Giovanni", specialtyType = PokemonType.GROUND},
    [140] = {name = "Whitney", specialtyType = PokemonType.NORMAL},
    [160] = {name = "Clair", specialtyType = PokemonType.DRAGON}
}

-- Fixed Elite Four Encounters (from TypeScript fixed-boss-waves.ts)
-- Elite Four members with randomized specialty types
local ELITE_FOUR_ENCOUNTERS = {
    [182] = {
        memberIndex = 1,
        possibleMembers = {
            {name = "Will", specialtyType = PokemonType.PSYCHIC},
            {name = "Lorelei", specialtyType = PokemonType.ICE},
            {name = "Sidney", specialtyType = PokemonType.DARK}
        }
    },
    [184] = {
        memberIndex = 2,
        possibleMembers = {
            {name = "Bruno", specialtyType = PokemonType.FIGHTING},
            {name = "Koga", specialtyType = PokemonType.POISON},
            {name = "Phoebe", specialtyType = PokemonType.GHOST}
        }
    },
    [186] = {
        memberIndex = 3,
        possibleMembers = {
            {name = "Agatha", specialtyType = PokemonType.GHOST},
            {name = "Bruno", specialtyType = PokemonType.FIGHTING},
            {name = "Glacia", specialtyType = PokemonType.ICE}
        }
    },
    [188] = {
        memberIndex = 4,
        possibleMembers = {
            {name = "Lance", specialtyType = PokemonType.DRAGON},
            {name = "Karen", specialtyType = PokemonType.DARK},
            {name = "Drake", specialtyType = PokemonType.DRAGON}
        }
    }
}

-- Champion encounter (wave 190)
local CHAMPION_WAVE = 190
local CHAMPION_NAMES = {"Lance", "Blue", "Steven", "Cynthia", "Alder", "Iris", "Diantha", "Leon"}

-- Party Template Definitions (from TypeScript trainer-party-template.ts)
-- Gym Leader templates scale with wave progression
local PARTY_TEMPLATES = {
    GYM_LEADER_1 = {
        size = 2,
        composition = {
            {count = 1, strength = PartyMemberStrength.AVERAGE},
            {count = 1, strength = PartyMemberStrength.STRONG}
        }
    },
    GYM_LEADER_2 = {
        size = 3,
        composition = {
            {count = 1, strength = PartyMemberStrength.AVERAGE},
            {count = 1, strength = PartyMemberStrength.STRONG},
            {count = 1, strength = PartyMemberStrength.STRONGER}
        }
    },
    GYM_LEADER_3 = {
        size = 4,
        composition = {
            {count = 2, strength = PartyMemberStrength.AVERAGE},
            {count = 1, strength = PartyMemberStrength.STRONG},
            {count = 1, strength = PartyMemberStrength.STRONGER}
        }
    },
    GYM_LEADER_4 = {
        size = 5,
        composition = {
            {count = 3, strength = PartyMemberStrength.AVERAGE},
            {count = 1, strength = PartyMemberStrength.STRONG},
            {count = 1, strength = PartyMemberStrength.STRONGER}
        }
    },
    GYM_LEADER_5 = {
        size = 6,
        composition = {
            {count = 3, strength = PartyMemberStrength.AVERAGE},
            {count = 2, strength = PartyMemberStrength.STRONG},
            {count = 1, strength = PartyMemberStrength.STRONGER}
        }
    },
    ELITE_FOUR = {
        size = 6,
        composition = {
            {count = 2, strength = PartyMemberStrength.AVERAGE},
            {count = 3, strength = PartyMemberStrength.STRONG},
            {count = 1, strength = PartyMemberStrength.STRONGER}
        }
    },
    CHAMPION = {
        size = 6,
        composition = {
            {count = 4, strength = PartyMemberStrength.STRONG},
            {count = 2, strength = PartyMemberStrength.STRONGER}
        },
        balanced = true
    }
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Deterministic RNG using Linear Congruential Generator (LCG)
-- Uses constants from Numerical Recipes for high-quality pseudo-random sequences
-- This ensures deterministic, reproducible trainer generation across AO processes
local rngState = 0
local RNG_MULTIPLIER = 1664525
local RNG_INCREMENT = 1013904223
local RNG_MODULUS = 2^32

-- Linear Congruential Generator for deterministic random numbers
local function deterministicRandom()
    rngState = (rngState * RNG_MULTIPLIER + RNG_INCREMENT) % RNG_MODULUS
    return rngState / RNG_MODULUS
end

-- Seed the RNG with trainer context for reproducible results
local function setSeed(seed)
    rngState = tonumber(seed) or 0
    if rngState == 0 then
        rngState = 12345 -- Default seed if none provided
    end
    rngState = rngState % RNG_MODULUS
end

-- Get deterministic random number in range [min, max] (integer)
local function randomRange(min, max)
    return math.floor(deterministicRandom() * (max - min + 1)) + min
end

-- Get deterministic random float [0.0, 1.0)
local function randomFloat()
    return deterministicRandom()
end

-- Get deterministic random boolean with given probability (0.0 to 1.0)
local function randomBool(probability)
    return deterministicRandom() < (probability or 0.5)
end

-- Legacy wrapper for compatibility (use randomRange instead)
local function random(min, max)
    if max then
        return randomRange(min, max)
    elseif min then
        return randomRange(1, min)
    else
        return randomFloat()
    end
end

-- Calculate seed offset for deterministic party generation
local function getSeedOffset(partyIndex, waveIndex)
    return (partyIndex * 1000) + (waveIndex or 0)
end

-- ============================================================================
-- EXTERNAL PROCESS COMMUNICATION
-- ============================================================================

-- Retry configuration for external process calls
local MAX_RETRIES = 3
local RETRY_DELAYS = { 100, 200, 400 } -- milliseconds (exponential backoff)
local REQUEST_TIMEOUT = 3000 -- 3 seconds per attempt
local FAILURE_CACHE_TTL = 60 -- Cache failures for 60 seconds

-- Failure cache to avoid repeated failed lookups
local failureCache = {}

-- Check if a lookup recently failed
local function isRecentFailure(cacheKey, currentTime)
    local cachedFailure = failureCache[cacheKey]
    if cachedFailure and (currentTime - cachedFailure.timestamp) < FAILURE_CACHE_TTL then
        return true, cachedFailure.error
    end
    return false, nil
end

-- Cache a failed lookup
local function cacheFailure(cacheKey, errorMessage, currentTime)
    failureCache[cacheKey] = {
        timestamp = currentTime,
        error = errorMessage
    }
end

-- Send async message to external process with retry logic
-- Returns: success (boolean), data (table or nil), error (string or nil)
local function callExternalProcess(processId, action, requestData, retryCount)
    retryCount = retryCount or 0

    -- Check failure cache first
    local cacheKey = processId .. ":" .. action .. ":" .. json.encode(requestData)
    -- Use msg.Timestamp for deterministic execution (AO compliance)
    -- In production, timestamp would be passed from handler context
    local currentTime = 0 -- Placeholder - would use msg.Timestamp in handlers
    local isFailed, cachedError = isRecentFailure(cacheKey, currentTime)

    if isFailed then
        return false, nil, "Cached failure: " .. cachedError
    end

    -- Send message to external process
    ao.send({
        Target = processId,
        Action = action,
        Data = json.encode(requestData),
        Timestamp = tostring(currentTime)
    })

    -- NOTE: In production AO environment, this would use async message passing
    -- with inbox polling or callback handlers. For now, we structure the code
    -- to support both sync (testing) and async (production) patterns.

    -- Placeholder for response handling - will be implemented with proper
    -- inbox management in production deployment
    return true, nil, nil
end

-- Lookup species data from pokemon-species-db
local function lookupSpecies(speciesId)
    local success, data, error = callExternalProcess(
        POKEMON_SPECIES_DB_PROCESS,
        "get-species",
        { speciesId = speciesId }
    )

    if not success then
        return nil, error or "Species lookup failed"
    end

    return data, nil
end

-- Lookup moves for a species at a given level
local function lookupLevelMoves(speciesId, level)
    local success, data, error = callExternalProcess(
        POKEMON_SPECIES_DB_PROCESS,
        "get-level-moves",
        { speciesId = speciesId, level = level }
    )

    if not success then
        return nil, error or "Level moves lookup failed"
    end

    return data, nil
end

-- Lookup move data from moves-database
local function lookupMove(moveId)
    local success, data, error = callExternalProcess(
        MOVES_DATABASE_PROCESS,
        "get-move",
        { moveId = moveId }
    )

    if not success then
        return nil, error or "Move lookup failed"
    end

    return data, nil
end

-- Lookup moves by type from moves-database
local function lookupMovesByType(typeId)
    local success, data, error = callExternalProcess(
        MOVES_DATABASE_PROCESS,
        "get-moves-by-type",
        { type = typeId }
    )

    if not success then
        return nil, error or "Moves by type lookup failed"
    end

    return data, nil
end

-- ============================================================================
-- SPECIES SELECTION SYSTEM
-- ============================================================================

-- Select species from tier-based pool (512-weighted distribution)
-- Tiers: COMMON (356/512), UNCOMMON (124/512), RARE (26/512), SUPER_RARE (5/512), ULTRA_RARE (1/512)
local function selectSpeciesFromTierPool(speciesPool, seed)
    if not speciesPool or #speciesPool == 0 then
        return nil, "Empty species pool"
    end

    -- Set deterministic seed for this selection
    if seed then
        setSeed(seed)
    end

    -- Generate random value [0, 512) for tier selection
    local roll = randomRange(0, 511)

    -- Determine tier based on weights
    local selectedTier = 0 -- COMMON
    if roll >= 356 and roll < 480 then
        selectedTier = 1 -- UNCOMMON
    elseif roll >= 480 and roll < 506 then
        selectedTier = 2 -- RARE
    elseif roll >= 506 and roll < 511 then
        selectedTier = 3 -- SUPER_RARE
    elseif roll >= 511 then
        selectedTier = 4 -- ULTRA_RARE
    end

    -- Build species list for selected tier
    local tierSpecies = {}
    for _, species in ipairs(speciesPool) do
        if species.tier == selectedTier then
            table.insert(tierSpecies, species.id)
        end
    end

    -- Fallback to common tier if selected tier is empty
    if #tierSpecies == 0 then
        for _, species in ipairs(speciesPool) do
            if species.tier == 0 then
                table.insert(tierSpecies, species.id)
            end
        end
    end

    -- Select random species from tier
    if #tierSpecies > 0 then
        local index = randomRange(1, #tierSpecies)
        return tierSpecies[index], nil
    end

    return nil, "No species found in tier pool"
end

-- Select signature species for named trainers (gym leaders, elite four)
-- Signature species are predefined in trainer config
local function selectSignatureSpecies(signatureList, partyIndex, seed)
    if not signatureList or #signatureList == 0 then
        return nil, "No signature species defined"
    end

    -- Use party index to select from signature list (deterministic)
    local speciesIndex = ((partyIndex - 1) % #signatureList) + 1
    local speciesEntry = signatureList[speciesIndex]

    -- Handle choice arrays (e.g., {Omanyte, Kabuto} - random pick)
    if type(speciesEntry) == "table" then
        if seed then
            setSeed(seed)
        end
        local choiceIndex = randomRange(1, #speciesEntry)
        return speciesEntry[choiceIndex], nil
    end

    return speciesEntry, nil
end

-- Select random species (for generic trainers without signature species)
local function selectRandomSpecies(speciesPool, seed)
    if not speciesPool or #speciesPool == 0 then
        return nil, "Empty species pool"
    end

    if seed then
        setSeed(seed)
    end

    -- Flatten pool to simple array of species IDs
    local allSpecies = {}
    for _, species in ipairs(speciesPool) do
        table.insert(allSpecies, species.id)
    end

    if #allSpecies == 0 then
        return nil, "No species in pool"
    end

    local index = randomRange(1, #allSpecies)
    return allSpecies[index], nil
end

-- Check if species is already in party (for duplicate prevention)
local function isDuplicate(speciesId, party)
    for _, member in ipairs(party) do
        if member.speciesId == speciesId then
            return true
        end
    end
    return false
end

-- Check if adding species would violate type balance requirements
-- Type-balanced parties should not have more than 2 Pokemon of same type
local function violatesTypeBalance(speciesId, party, speciesData)
    if not speciesData or not speciesData.t then
        return false -- Can't determine type, allow it
    end

    local primaryType = speciesData.t[1]
    local typeCount = 0

    for _, member in ipairs(party) do
        if member.primaryType == primaryType then
            typeCount = typeCount + 1
        end
    end

    -- Allow max 2 Pokemon of same type in balanced parties
    return typeCount >= 2
end

-- Check if species matches specialty type requirement (for gym leaders)
-- Gym leaders specialize in specific types (e.g., Brock = Rock, Misty = Water)
local function matchesSpecialtyType(speciesId, specialtyType, speciesData)
    if not specialtyType then
        return true -- No specialty requirement
    end

    if not speciesData or not speciesData.t then
        return false -- Can't determine type, reject it
    end

    -- Check if species has specialty type (primary or secondary)
    for _, typeId in ipairs(speciesData.t) do
        if typeId == specialtyType then
            return true
        end
    end

    return false
end

-- Select species with validation (duplicate/type/specialty checks with reroll)
local function selectSpeciesWithValidation(
    selectionMethod,
    selectionData,
    party,
    partyIndex,
    seed,
    requireTypeBalance,
    specialtyType
)
    local maxAttempts = 10 -- Reroll up to 10 times
    local seedOffset = getSeedOffset(partyIndex, seed)

    for attempt = 1, maxAttempts do
        local attemptSeed = seedOffset + attempt
        local valid = true

        -- Select species based on method
        local speciesId, error
        if selectionMethod == "signature" then
            speciesId, error = selectSignatureSpecies(selectionData, partyIndex, attemptSeed)
        elseif selectionMethod == "tier" then
            speciesId, error = selectSpeciesFromTierPool(selectionData, attemptSeed)
        elseif selectionMethod == "random" then
            speciesId, error = selectRandomSpecies(selectionData, attemptSeed)
        else
            return nil, "Unknown selection method: " .. tostring(selectionMethod)
        end

        if not speciesId then
            return nil, error
        end

        -- Check duplicate
        if isDuplicate(speciesId, party) then
            valid = false
        end

        -- Lookup species data for type validation (if required)
        if valid and (requireTypeBalance or specialtyType) then
            local speciesData, lookupError = lookupSpecies(speciesId)
            if not speciesData then
                -- If lookup fails, skip validation and allow species
                return speciesId, nil
            end

            -- Check type balance
            if requireTypeBalance and violatesTypeBalance(speciesId, party, speciesData) then
                valid = false
            end

            -- Check specialty type
            if valid and specialtyType and not matchesSpecialtyType(speciesId, specialtyType, speciesData) then
                valid = false
            end
        end

        -- If all validations passed, return species
        if valid then
            return speciesId, nil
        end
    end

    -- Failed after max attempts
    return nil, "Could not find valid species after " .. maxAttempts .. " attempts"
end

-- ============================================================================
-- PARTY GENERATION SYSTEM
-- ============================================================================

-- Pokemon nature modifiers (affects stats)
local NATURES = {
    { name = "Hardy", stats = {} },
    { name = "Lonely", stats = { atk = 1.1, def = 0.9 } },
    { name = "Brave", stats = { atk = 1.1, spd = 0.9 } },
    { name = "Adamant", stats = { atk = 1.1, spatk = 0.9 } },
    { name = "Naughty", stats = { atk = 1.1, spdef = 0.9 } },
    { name = "Bold", stats = { def = 1.1, atk = 0.9 } },
    { name = "Docile", stats = {} },
    { name = "Relaxed", stats = { def = 1.1, spd = 0.9 } },
    { name = "Impish", stats = { def = 1.1, spatk = 0.9 } },
    { name = "Lax", stats = { def = 1.1, spdef = 0.9 } },
    { name = "Timid", stats = { spd = 1.1, atk = 0.9 } },
    { name = "Hasty", stats = { spd = 1.1, def = 0.9 } },
    { name = "Serious", stats = {} },
    { name = "Jolly", stats = { spd = 1.1, spatk = 0.9 } },
    { name = "Naive", stats = { spd = 1.1, spdef = 0.9 } },
    { name = "Modest", stats = { spatk = 1.1, atk = 0.9 } },
    { name = "Mild", stats = { spatk = 1.1, def = 0.9 } },
    { name = "Quiet", stats = { spatk = 1.1, spd = 0.9 } },
    { name = "Bashful", stats = {} },
    { name = "Rash", stats = { spatk = 1.1, spdef = 0.9 } },
    { name = "Calm", stats = { spdef = 1.1, atk = 0.9 } },
    { name = "Gentle", stats = { spdef = 1.1, def = 0.9 } },
    { name = "Sassy", stats = { spdef = 1.1, spd = 0.9 } },
    { name = "Careful", stats = { spdef = 1.1, spatk = 0.9 } },
    { name = "Quirky", stats = {} }
}

-- Calculate evolution for level-based species selection
-- If Pokemon evolves before target level, return evolved form
local function calculateEvolution(speciesId, targetLevel)
    -- Lookup species data to check evolution requirements
    local speciesData, error = lookupSpecies(speciesId)
    if not speciesData then
        return speciesId -- Can't check evolution, return original
    end

    -- Check if species has evolution data
    if not speciesData.evo then
        return speciesId -- No evolution
    end

    -- Check level-based evolution
    if speciesData.evo.level and targetLevel >= speciesData.evo.level then
        -- Recursively check evolved form
        local evolvedId = speciesData.evo.to or speciesData.id + 1
        return calculateEvolution(evolvedId, targetLevel)
    end

    return speciesId
end

-- Generate random gender (true = male, false = female)
local function generateGender(seed)
    if seed then
        setSeed(seed)
    end
    return randomBool(0.5)
end

-- Generate random ability index (0 = ability 1, 1 = ability 2, 2 = hidden ability)
local function generateAbilityIndex(seed, allowHidden)
    if seed then
        setSeed(seed)
    end

    if allowHidden and randomBool(0.1) then
        return 2 -- Hidden ability (10% chance)
    end

    return randomBool(0.5) and 0 or 1 -- 50/50 for ability 1 or 2
end

-- Generate random nature
local function generateNature(seed)
    if seed then
        setSeed(seed)
    end
    local index = randomRange(1, #NATURES)
    return NATURES[index]
end

-- Generate random IVs (Individual Values) - 0-31 range
local function generateIVs(seed, minIV)
    if seed then
        setSeed(seed)
    end

    minIV = minIV or 0

    return {
        hp = randomRange(minIV, 31),
        atk = randomRange(minIV, 31),
        def = randomRange(minIV, 31),
        spatk = randomRange(minIV, 31),
        spdef = randomRange(minIV, 31),
        spd = randomRange(minIV, 31)
    }
end

-- Generate moveset for party member
local function generateMoveset(speciesId, level, seed)
    -- Lookup level-up moves for species
    local movesData, error = lookupLevelMoves(speciesId, level)
    if not movesData or not movesData.moves then
        -- Fallback: Return empty moveset (will use species' default moves)
        return {}
    end

    -- Take up to 4 most recent moves learned by level
    local moves = movesData.moves
    local moveCount = math.min(4, #moves)
    local moveset = {}

    for i = (#moves - moveCount + 1), #moves do
        table.insert(moveset, moves[i])
    end

    return moveset
end

-- Generate complete party member
local function generatePartyMember(
    speciesId,
    level,
    partyIndex,
    seed,
    minIV,
    allowHiddenAbility
)
    local memberSeed = getSeedOffset(partyIndex, seed)

    -- Check for evolution
    local finalSpeciesId = calculateEvolution(speciesId, level)

    -- Generate attributes
    local gender = generateGender(memberSeed + 1)
    local abilityIndex = generateAbilityIndex(memberSeed + 2, allowHiddenAbility)
    local nature = generateNature(memberSeed + 3)
    local ivs = generateIVs(memberSeed + 4, minIV)
    local moves = generateMoveset(finalSpeciesId, level, memberSeed + 5)

    -- Lookup final species data for type information
    local speciesData, lookupError = lookupSpecies(finalSpeciesId)
    local primaryType = speciesData and speciesData.t and speciesData.t[1] or nil

    return {
        speciesId = finalSpeciesId,
        level = level,
        gender = gender,
        abilityIndex = abilityIndex,
        nature = nature.name,
        ivs = ivs,
        moves = moves,
        primaryType = primaryType,
        originalSpeciesId = speciesId -- Track pre-evolution form
    }
end

-- Generate complete trainer party
local function generateTrainerParty(
    partyTemplate,
    levels,
    selectionMethod,
    selectionData,
    seed,
    specialtyType
)
    local party = {}
    local requireTypeBalance = partyTemplate.balanced or false
    local minIV = partyTemplate.minIV or 0
    local allowHiddenAbility = partyTemplate.allowHidden or false

    for i = 1, partyTemplate.size do
        local level = levels[i] or levels[1]

        -- Select species with validation
        local speciesId, error = selectSpeciesWithValidation(
            selectionMethod,
            selectionData,
            party,
            i,
            seed,
            requireTypeBalance,
            specialtyType
        )

        if not speciesId then
            return nil, "Failed to select species for party member " .. i .. ": " .. error
        end

        -- Generate party member
        local member = generatePartyMember(
            speciesId,
            level,
            i,
            seed,
            minIV,
            allowHiddenAbility
        )

        table.insert(party, member)
    end

    return party, nil
end

-- ============================================================================
-- AI CONFIGURATION SYSTEM
-- ============================================================================

-- Tera AI modes
local TeraMode = {
    NO_TERA = 0,        -- Trainer doesn't have Tera ability
    INSTANT_TERA = 1,   -- Tera immediately when possible
    SMART_TERA = 2      -- Tera strategically based on matchup
}

-- Trainer AI configuration structure
local function createTrainerAI(isBoss, hasTeraAccess, party)
    local ai = {
        isBoss = isBoss or false,
        hasTeraAccess = hasTeraAccess or false,
        teraMode = TeraMode.NO_TERA,
        instantTeraIndex = nil,
        switchThreshold = isBoss and BOSS_TRAINER_SWITCH_MULTIPLIER or REGULAR_TRAINER_SWITCH_MULTIPLIER
    }

    -- Configure Tera mode for boss trainers
    if isBoss and hasTeraAccess then
        -- Boss trainers use SMART_TERA by default
        ai.teraMode = TeraMode.SMART_TERA

        -- Elite Four and Champions use INSTANT_TERA on their ace Pokemon
        -- Select strongest party member (highest level + best stats)
        if party and #party > 0 then
            local aceIndex = #party -- Last Pokemon is usually the ace
            ai.instantTeraIndex = aceIndex
        end
    end

    return ai
end

-- Generate AI configuration for specific trainer types
local function generateAIConfig(trainerType, party, waveIndex)
    local isBoss = false
    local hasTeraAccess = false

    -- Determine boss status and Tera access based on trainer type
    -- Boss trainers: Gym leaders (20, 30, 40...), Elite Four (165+), Champions (182+)
    if waveIndex >= 160 then
        isBoss = true
        hasTeraAccess = true
    elseif waveIndex % 20 == 0 and waveIndex >= 20 then
        isBoss = true
        hasTeraAccess = waveIndex >= 100 -- Later gym leaders have Tera
    end

    return createTrainerAI(isBoss, hasTeraAccess, party)
end

-- ============================================================================
-- FIXED TRAINER ENCOUNTERS
-- ============================================================================

-- Fixed boss waves for Classic game mode
-- Maps wave numbers to specific trainers (gym leaders, elite four, champions)
local ClassicFixedBossWaves = {
    [20] = { type = "GYM_LEADER", name = "Brock", specialtyType = 5 },  -- ROCK
    [30] = { type = "GYM_LEADER", name = "Misty", specialtyType = 10 }, -- WATER
    [40] = { type = "GYM_LEADER", name = "Lt. Surge", specialtyType = 12 }, -- ELECTRIC
    [50] = { type = "GYM_LEADER", name = "Erika", specialtyType = 11 }, -- GRASS
    [60] = { type = "GYM_LEADER", name = "Janine", specialtyType = 3 }, -- POISON
    [80] = { type = "GYM_LEADER", name = "Sabrina", specialtyType = 13 }, -- PSYCHIC
    [100] = { type = "GYM_LEADER", name = "Blaine", specialtyType = 9 }, -- FIRE
    [120] = { type = "GYM_LEADER", name = "Giovanni", specialtyType = 4 }, -- GROUND
    [140] = { type = "GYM_LEADER", name = "Whitney", specialtyType = 0 }, -- NORMAL
    [160] = { type = "GYM_LEADER", name = "Clair", specialtyType = 15 }, -- DRAGON
    [165] = { type = "ELITE_FOUR", name = "Will", specialtyType = 13 }, -- PSYCHIC
    [170] = { type = "ELITE_FOUR", name = "Koga", specialtyType = 3 }, -- POISON
    [175] = { type = "ELITE_FOUR", name = "Bruno", specialtyType = 1 }, -- FIGHTING
    [180] = { type = "ELITE_FOUR", name = "Karen", specialtyType = 16 }, -- DARK
    [182] = { type = "CHAMPION", name = "Lance", specialtyType = 15 }, -- DRAGON
    [195] = { type = "RIVAL", name = "Red", specialtyType = nil } -- No specialty (balanced party)
}

-- Get fixed trainer for wave (Classic mode)
local function getFixedTrainer(waveIndex, gameMode)
    if gameMode ~= "classic" then
        return nil -- Fixed encounters only in Classic mode
    end

    local wave = tonumber(waveIndex)
    return ClassicFixedBossWaves[wave]
end

-- Check if wave has fixed trainer encounter
local function isFixedTrainerWave(waveIndex, gameMode)
    local trainer = getFixedTrainer(waveIndex, gameMode)
    return trainer ~= nil
end

-- Validate fixed trainer eligibility for wave
local function validateFixedTrainer(waveIndex, gameMode)
    if gameMode ~= "classic" then
        return false, "Fixed trainers only available in Classic mode"
    end

    local trainer = getFixedTrainer(waveIndex, gameMode)
    if not trainer then
        return false, "No fixed trainer for wave " .. tostring(waveIndex)
    end

    return true, trainer
end

-- ============================================================================
-- LEVEL CALCULATION SYSTEM
-- ============================================================================

-- Calculate base level for wave
-- Formula: 1 + (wave/2) + (wave/25)^2
local function calculateBaseLevel(waveIndex)
    local wave = tonumber(waveIndex) or 1
    local baseLevel = 1 + (wave / 2) + math.pow(wave / 25, 2)
    return math.floor(baseLevel)
end

-- Calculate level with strength multiplier
local function calculateLevelWithStrength(baseLevel, strength)
    local strengthId = tonumber(strength) or 2
    local multiplier = STRENGTH_MULTIPLIERS[strengthId] or 1.0

    -- Apply progressive scaling for weak Pokemon (catch-up mechanic)
    if strengthId < PROGRESSIVE_SCALE_START then
        local waveRatio = math.floor(baseLevel / 25) -- Rough wave estimation
        local progressiveBonus = math.min(
            PROGRESSIVE_SCALE_BONUS * waveRatio,
            PROGRESSIVE_SCALE_MAX - multiplier
        )
        multiplier = multiplier + progressiveBonus
    end

    return math.ceil(baseLevel * multiplier)
end

-- Calculate level offset for weaker Pokemon
local function calculateLevelOffset(baseLevel, strength)
    local strengthId = tonumber(strength) or 2
    if strengthId >= PROGRESSIVE_SCALE_START then
        return 0
    end

    local waveRatio = math.floor(baseLevel / 25)
    local offsetAmount = PROGRESSIVE_SCALE_START - strengthId
    return -math.floor(waveRatio * offsetAmount)
end

-- Calculate party levels
local function calculatePartyLevels(waveIndex, partyTemplate)
    local baseLevel = calculateBaseLevel(waveIndex)
    local levels = {}

    local size = partyTemplate.size or 1
    local strength = partyTemplate.strength or 2

    for i = 1, size do
        local level = calculateLevelWithStrength(baseLevel, strength)
        local offset = calculateLevelOffset(baseLevel, strength)
        local finalLevel = level + offset

        -- Add slight variance for variety (±1 level)
        local variance = random(-1, 1)
        finalLevel = math.max(1, finalLevel + variance)

        table.insert(levels, finalLevel)
    end

    return {
        baseLevel = baseLevel,
        levels = levels,
        difficultyWaveIndex = tonumber(waveIndex)
    }
end

-- ============================================================================
-- GYM LEADER AND ELITE FOUR PARTY TEMPLATES
-- ============================================================================

-- Get gym leader party template based on wave and game mode
-- Matches TypeScript logic from trainer-party-template.ts lines 250-285
local function getGymLeaderPartyTemplate(wave, gameMode)
    local waveIndex = tonumber(wave) or 1
    local mode = gameMode or "Classic"

    -- Daily mode logic (from TypeScript lines 253-257)
    if mode == "Daily" then
        if waveIndex <= 20 then
            return PARTY_TEMPLATES.GYM_LEADER_2
        end
        return PARTY_TEMPLATES.GYM_LEADER_3
    end

    -- Classic and Challenge mode logic (from TypeScript lines 259-275)
    if mode == "Classic" or mode == "Challenge" then
        if waveIndex <= 20 then
            return PARTY_TEMPLATES.GYM_LEADER_1  -- 1 avg, 1 strong
        end
        if waveIndex <= 30 then
            return PARTY_TEMPLATES.GYM_LEADER_2  -- 1 avg, 1 strong, 1 stronger
        end
        if waveIndex <= 60 then
            return PARTY_TEMPLATES.GYM_LEADER_3  -- 2 avg, 1 strong, 1 stronger
        end
        if waveIndex <= 90 then
            return PARTY_TEMPLATES.GYM_LEADER_4  -- 3 avg, 1 strong, 1 stronger
        end
        -- Wave >90 (110+)
        return PARTY_TEMPLATES.GYM_LEADER_5  -- 3 avg, 2 strong, 1 stronger
    end

    -- Default fallback (wave-based template selection)
    if waveIndex <= 20 then
        return PARTY_TEMPLATES.GYM_LEADER_1
    elseif waveIndex <= 30 then
        return PARTY_TEMPLATES.GYM_LEADER_2
    elseif waveIndex <= 60 then
        return PARTY_TEMPLATES.GYM_LEADER_3
    elseif waveIndex <= 90 then
        return PARTY_TEMPLATES.GYM_LEADER_4
    else
        return PARTY_TEMPLATES.GYM_LEADER_5
    end
end

-- Expand party template composition into individual strength values
-- Converts compound template format to flat array of strength values
local function expandPartyComposition(template)
    local strengths = {}

    for _, component in ipairs(template.composition) do
        for i = 1, component.count do
            table.insert(strengths, component.strength)
        end
    end

    return strengths
end

-- Get Elite Four party template
-- Returns the fixed Elite Four template with BST filtering requirement
local function getEliteFourPartyTemplate()
    return PARTY_TEMPLATES.ELITE_FOUR
end

-- Get Champion party template
-- Returns the balanced Champion template
local function getChampionPartyTemplate()
    return PARTY_TEMPLATES.CHAMPION
end

-- Filter species by Base Stat Total (BST)
-- Used for Elite Four Pokemon selection (minimum BST of 460)
local function filterSpeciesByBST(speciesPool, minBST)
    if not speciesPool or not minBST then
        return speciesPool
    end

    local filtered = {}
    for _, species in ipairs(speciesPool) do
        if species.baseStatTotal and species.baseStatTotal >= minBST then
            table.insert(filtered, species)
        end
    end

    return filtered
end

-- Get gym leader configuration for a given wave
-- Returns gym leader data if wave matches a fixed gym leader encounter
local function getGymLeaderForWave(wave)
    local waveIndex = tonumber(wave)
    if not waveIndex then
        return nil
    end

    return GYM_LEADER_ENCOUNTERS[waveIndex]
end

-- Get Elite Four member for a given wave (with randomization)
-- Returns randomized Elite Four member based on wave and seed
local function getEliteFourMemberForWave(wave, seed)
    local waveIndex = tonumber(wave)
    if not waveIndex then
        return nil
    end

    local encounterData = ELITE_FOUR_ENCOUNTERS[waveIndex]
    if not encounterData then
        return nil
    end

    -- Use seed to select random member from pool
    setSeed(seed or (waveIndex * 1000))
    local memberIndex = randomRange(1, #encounterData.possibleMembers)
    local selectedMember = encounterData.possibleMembers[memberIndex]

    return {
        name = selectedMember.name,
        specialtyType = selectedMember.specialtyType,
        memberIndex = encounterData.memberIndex,
        wave = waveIndex
    }
end

-- Get Champion configuration for wave 190
-- Returns randomized Champion name
local function getChampionForWave(wave, seed)
    local waveIndex = tonumber(wave)
    if not waveIndex or waveIndex ~= CHAMPION_WAVE then
        return nil
    end

    -- Use seed to select random Champion
    setSeed(seed or (waveIndex * 1000))
    local championIndex = randomRange(1, #CHAMPION_NAMES)

    return {
        name = CHAMPION_NAMES[championIndex],
        wave = waveIndex,
        isChampion = true
    }
end

-- Filter species by specialty type
-- Used for gym leaders and Elite Four members with type specialization
local function filterSpeciesByType(speciesPool, specialtyType)
    if not speciesPool or not specialtyType then
        return speciesPool
    end

    local filtered = {}
    for _, species in ipairs(speciesPool) do
        -- Check if species has primary or secondary type matching specialty
        if species.type1 == specialtyType or species.type2 == specialtyType then
            table.insert(filtered, species)
        end
    end

    return filtered
end

-- ============================================================================
-- TERASTALLIZATION SYSTEM
-- ============================================================================

-- Tera Mode enum
local TeraMode = {
    NO_TERA = 0,
    INSTANT_TERA = 1,
    SMART_TERA = 2
}

-- Configure Gym Leader Terastallization
-- Wave <100: NO_TERA, Wave ≥100: INSTANT_TERA on ace Pokemon (last party member)
local function configureGymLeaderTera(wave, partySize)
    local waveIndex = tonumber(wave)
    if not waveIndex then
        return {teraMode = TeraMode.NO_TERA, teraSlot = nil}
    end

    if waveIndex < GYM_LEADER_TERA_WAVE then
        return {teraMode = TeraMode.NO_TERA, teraSlot = nil}
    else
        -- INSTANT_TERA on last party member (ace Pokemon)
        -- Slot is 0-indexed, so last slot = partySize - 1
        return {teraMode = TeraMode.INSTANT_TERA, teraSlot = (partySize - 1)}
    end
end

-- Configure Elite Four Terastallization
-- Uses SMART_TERA mode with strategic timing based on matchup
local function configureEliteFourTera(partySize, memberIndex)
    -- Elite Four uses SMART_TERA mode (intelligent timing)
    -- Tera slot is based on member index (from TypeScript line 744)
    -- Slot value matches the member index (1-4) but 0-indexed for party slots
    local teraSlot = (memberIndex or 2) % partySize

    return {teraMode = TeraMode.SMART_TERA, teraSlot = teraSlot}
end

-- Configure Champion Terastallization
-- Uses SMART_TERA mode with balanced team strategy
local function configureChampionTera(partySize)
    -- Champion uses SMART_TERA with random tera slot
    -- TypeScript uses setRandomTeraModifiers for Champion
    local teraSlot = randomRange(0, partySize - 1)

    return {teraMode = TeraMode.SMART_TERA, teraSlot = teraSlot}
end

-- ============================================================================
-- CHAMPIONSHIP VALIDATION SYSTEM
-- ============================================================================

-- Validate Elite Four progression
-- Ensures players cannot skip Elite Four members and must defeat sequentially
local function validateEliteFourProgression(wave, eliteFourVictories)
    local waveIndex = tonumber(wave)
    local victories = tonumber(eliteFourVictories) or 0

    -- Determine required victories for this wave
    local requiredVictories = 0
    if waveIndex == 182 then requiredVictories = 0      -- First member
    elseif waveIndex == 184 then requiredVictories = 1  -- Second member (need 1 victory)
    elseif waveIndex == 186 then requiredVictories = 2  -- Third member (need 2 victories)
    elseif waveIndex == 188 then requiredVictories = 3  -- Fourth member (need 3 victories)
    elseif waveIndex == 190 then requiredVictories = 4  -- Champion (need all 4 victories)
    else
        return {valid = false, reason = "Not an Elite Four/Champion wave"}
    end

    if victories < requiredVictories then
        return {
            valid = false,
            reason = "Must defeat Elite Four members sequentially",
            currentVictories = victories,
            requiredVictories = requiredVictories
        }
    end

    return {valid = true, currentVictories = victories, requiredVictories = requiredVictories}
end

-- Validate Championship eligibility
-- Returns true if player has defeated all 4 Elite Four members
local function validateChampionshipEligibility(eliteFourVictories)
    local victories = tonumber(eliteFourVictories) or 0
    return victories >= 4
end

-- ============================================================================
-- DIALOGUE SYSTEM
-- ============================================================================

-- Generate dialogue keys for gym leaders
-- Returns encounter, victory, and defeat dialogue keys
local function generateGymLeaderDialogue(gymLeaderName, wave)
    local name = gymLeaderName or "Gym Leader"
    local waveIndex = tonumber(wave)

    return {
        encounter = name .. ".encounter.gym.wave" .. waveIndex,
        victory = name .. ".victory.badge",
        defeat = name .. ".defeat"
    }
end

-- Generate dialogue keys for Elite Four members
-- Returns encounter, victory, and defeat dialogue keys
local function generateEliteFourDialogue(memberName, memberIndex)
    local name = memberName or "Elite Four"
    local index = tonumber(memberIndex) or 1

    return {
        encounter = name .. ".encounter.eliteFour.member" .. index,
        victory = name .. ".victory.eliteFour",
        defeat = name .. ".defeat"
    }
end

-- Generate dialogue keys for Champion
-- Returns encounter, victory, and defeat dialogue keys
local function generateChampionDialogue(championName)
    local name = championName or "Champion"

    return {
        encounter = name .. ".encounter.champion",
        victory = name .. ".victory.championship",
        defeat = name .. ".defeat"
    }
end

-- ============================================================================
-- SPECIES SELECTION SYSTEM
-- ============================================================================

-- Select species from tier pool (weighted random)
local function selectSpeciesFromTier()
    -- NOTE: This is a placeholder - actual implementation requires
    -- integration with species-lookup process
    -- For now, returning mock species ID
    local totalWeight = 0
    for _, weight in pairs(TIER_WEIGHTS) do
        totalWeight = totalWeight + weight
    end

    local roll = random(1, totalWeight)
    local currentWeight = 0

    for tier, weight in pairs(TIER_WEIGHTS) do
        currentWeight = currentWeight + weight
        if roll <= currentWeight then
            return tier
        end
    end

    return 0 -- COMMON tier as fallback
end

-- Check if species is duplicate in party
local function isDuplicateSpecies(speciesId, existingParty)
    -- NOTE: Requires evolution chain lookup from species-lookup process
    -- For now, simple ID comparison
    for _, member in ipairs(existingParty) do
        if member.speciesId == speciesId then
            return true
        end
    end
    return false
end

-- ============================================================================
-- MATCHUP SCORE CALCULATION
-- ============================================================================

-- Calculate defensive score (type effectiveness)
local function calculateDefensiveScore(attackerTypes, opponentTypes)
    -- NOTE: Requires type effectiveness chart lookup
    -- Placeholder implementation
    local defensiveScore = 1.0

    -- Mock calculation - actual implementation needs type chart
    -- defensiveScore = 1 / (total type effectiveness)

    return defensiveScore
end

-- Calculate offensive score (attack move effectiveness with STAB)
local function calculateOffensiveScore(attackerTypes, attackerMoves, opponentTypes)
    -- NOTE: Requires move type lookup and type effectiveness chart
    -- Placeholder implementation
    local offensiveScore = 1.0

    -- Mock calculation - actual implementation needs:
    -- 1. Move type lookup
    -- 2. Type effectiveness calculation
    -- 3. STAB application (1.5x for same-type moves)

    return offensiveScore
end

-- Calculate speed multiplier
local function calculateSpeedMultiplier(attackerSpeed, opponentSpeed)
    if attackerSpeed > opponentSpeed then
        return SPEED_ADVANTAGE_MULTIPLIER
    end
    return 1.0
end

-- Calculate complete matchup score
local function calculateMatchupScore(attackerData, opponentData)
    local defScore = calculateDefensiveScore(attackerData.types, opponentData.types)
    local atkScore = calculateOffensiveScore(
        attackerData.types,
        attackerData.moveset,
        opponentData.types
    )
    local speedMult = calculateSpeedMultiplier(attackerData.speed, opponentData.speed)

    local totalScore = defScore * atkScore * speedMult

    return {
        defensiveScore = defScore,
        offensiveScore = atkScore,
        speedMultiplier = speedMult,
        totalScore = totalScore
    }
end

-- ============================================================================
-- AI SWITCH DECISION LOGIC
-- ============================================================================

-- Evaluate whether trainer should switch Pokemon
local function evaluateSwitchDecision(currentPokemon, opponents, trainerParty, isBoss, switchCounter)
    -- Calculate current matchup score
    local currentMatchup = calculateMatchupScore(currentPokemon, opponents[1])

    -- Find best switch candidate
    local bestSwitchScore = 0
    local bestSwitchIndex = nil

    for i, partyMember in ipairs(trainerParty) do
        if not partyMember.fainted then
            local switchMatchup = calculateMatchupScore(partyMember, opponents[1])
            if switchMatchup.totalScore > bestSwitchScore then
                bestSwitchScore = switchMatchup.totalScore
                bestSwitchIndex = i
            end
        end
    end

    -- Calculate switch threshold
    local thresholdMultiplier = isBoss and BOSS_TRAINER_SWITCH_MULTIPLIER or REGULAR_TRAINER_SWITCH_MULTIPLIER
    local threshold = currentMatchup.totalScore * thresholdMultiplier

    -- Apply switch counter penalty
    local switchPenalty = 1.0 - (switchCounter * SWITCH_COUNTER_PENALTY)
    local adjustedBestScore = bestSwitchScore * switchPenalty

    -- Determine switch decision
    local shouldSwitch = adjustedBestScore >= threshold

    return {
        shouldSwitch = shouldSwitch,
        bestSwitchIndex = bestSwitchIndex,
        currentMatchupScore = currentMatchup.totalScore,
        bestSwitchScore = bestSwitchScore,
        threshold = threshold
    }
end

-- ============================================================================
-- REWARD CALCULATION SYSTEM
-- ============================================================================

-- Calculate money reward for trainer battle
local function calculateMoneyReward(waveIndex, moneyMultiplier)
    local wave = tonumber(waveIndex) or 1
    local multiplier = tonumber(moneyMultiplier) or 1.0

    -- Base money calculation
    local baseAmount = math.floor(math.pow(wave, 2) * MONEY_BASE_MULTIPLIER)
    local totalReward = math.floor(baseAmount * multiplier)

    return totalReward
end

-- Calculate item modifier chances per party member
local function calculateModifierChances(partyStrengths)
    local chances = {}

    for _, strength in ipairs(partyStrengths) do
        -- Higher strength = lower item chance
        local strengthId = tonumber(strength) or 2
        local reduction = math.pow(MODIFIER_CHANCE_REDUCTION, strengthId)
        local chance = BASE_MODIFIER_CHANCE * reduction
        table.insert(chances, chance)
    end

    return chances
end

-- Calculate complete rewards
local function calculateRewards(waveIndex, moneyMultiplier, partyStrengths, hasVoucher)
    local money = calculateMoneyReward(waveIndex, moneyMultiplier)
    local itemChances = calculateModifierChances(partyStrengths)

    return {
        moneyReward = money,
        itemChances = itemChances,
        hasVoucher = hasVoucher or false,
        modifierRewards = {}
    }
end

-- ============================================================================
-- ENCOUNTER PROBABILITY SYSTEM
-- ============================================================================

-- Select trainer from biome pool
local function selectTrainerFromBiomePool(biomePool, seed)
    setSeed(seed)

    -- Roll for pool tier
    local totalWeight = BIOME_POOL_WEIGHTS.common + BIOME_POOL_WEIGHTS.rare + BIOME_POOL_WEIGHTS.superRare
    local roll = random(1, totalWeight)

    local selectedPool
    if roll <= BIOME_POOL_WEIGHTS.superRare then
        selectedPool = biomePool.superRarePool
    elseif roll <= (BIOME_POOL_WEIGHTS.superRare + BIOME_POOL_WEIGHTS.rare) then
        selectedPool = biomePool.rarePool
    else
        selectedPool = biomePool.commonPool
    end

    -- Select random trainer from pool
    if selectedPool and #selectedPool > 0 then
        local index = random(1, #selectedPool)
        return selectedPool[index]
    end

    return nil
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
                    name = "Trainer Encounter Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    purpose = "Trainer generation algorithms and AI logic",
                    capabilities = {
                        "trainer_generation",
                        "level_calculation",
                        "species_selection",
                        "party_generation",
                        "ai_matchup_scoring",
                        "switch_decision_logic",
                        "reward_calculation",
                        "encounter_probability"
                    },
                    messageSchemas = {
                        CalculatePartyLevels = {
                            required = {"Action", "WaveIndex", "PartyTemplate"}
                        },
                        CalculateMatchupScore = {
                            required = {"Action", "AttackerData", "OpponentData"}
                        },
                        EvaluateSwitchDecision = {
                            required = {"Action", "CurrentPokemon", "Opponents", "TrainerParty"}
                        },
                        CalculateRewards = {
                            required = {"Action", "WaveIndex", "MoneyMultiplier", "PartyStrengths"}
                        }
                    }
                },
                handlers = {
                    "Info",
                    "CalculatePartyLevels",
                    "CalculateMatchupScore",
                    "EvaluateSwitchDecision",
                    "CalculateRewards",
                    "SelectTrainerFromBiome"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    processType = "logic_engine",
                    dataEngine = TRAINER_DATA_ENGINE_PROCESS
                }
            }),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- CalculatePartyLevels Handler
Handlers.add("calculate-party-levels",
    Handlers.utils.hasMatchingTag("Action", "CalculatePartyLevels"),
    function(msg)
        local waveIndex = msg.WaveIndex
        local partyTemplateJson = msg.PartyTemplate

        if not waveIndex or not partyTemplateJson then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "WaveIndex and PartyTemplate required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local partyTemplate = json.decode(partyTemplateJson)
        local result = calculatePartyLevels(waveIndex, partyTemplate)

        ao.send({
            Target = msg.From,
            Action = "PartyLevelsCalculated",
            Data = json.encode(result),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- CalculateMatchupScore Handler
Handlers.add("calculate-matchup-score",
    Handlers.utils.hasMatchingTag("Action", "CalculateMatchupScore"),
    function(msg)
        local attackerDataJson = msg.AttackerData
        local opponentDataJson = msg.OpponentData

        if not attackerDataJson or not opponentDataJson then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "AttackerData and OpponentData required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local attackerData = json.decode(attackerDataJson)
        local opponentData = json.decode(opponentDataJson)
        local result = calculateMatchupScore(attackerData, opponentData)

        ao.send({
            Target = msg.From,
            Action = "MatchupScoreCalculated",
            DefensiveScore = tostring(result.defensiveScore),
            OffensiveScore = tostring(result.offensiveScore),
            SpeedMultiplier = tostring(result.speedMultiplier),
            TotalScore = tostring(result.totalScore),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- EvaluateSwitchDecision Handler
Handlers.add("evaluate-switch-decision",
    Handlers.utils.hasMatchingTag("Action", "EvaluateSwitchDecision"),
    function(msg)
        local currentPokemonJson = msg.CurrentPokemon
        local opponentsJson = msg.Opponents
        local trainerPartyJson = msg.TrainerParty
        local isBoss = msg.IsBoss == "true"
        local switchCounter = tonumber(msg.SwitchCounter) or 0

        if not currentPokemonJson or not opponentsJson or not trainerPartyJson then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "CurrentPokemon, Opponents, and TrainerParty required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local currentPokemon = json.decode(currentPokemonJson)
        local opponents = json.decode(opponentsJson)
        local trainerParty = json.decode(trainerPartyJson)

        local result = evaluateSwitchDecision(
            currentPokemon,
            opponents,
            trainerParty,
            isBoss,
            switchCounter
        )

        ao.send({
            Target = msg.From,
            Action = "SwitchDecisionEvaluated",
            ShouldSwitch = tostring(result.shouldSwitch),
            BestSwitchIndex = result.bestSwitchIndex and tostring(result.bestSwitchIndex) or "",
            CurrentMatchupScore = tostring(result.currentMatchupScore),
            BestSwitchScore = tostring(result.bestSwitchScore),
            Threshold = tostring(result.threshold),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- CalculateRewards Handler
Handlers.add("calculate-rewards",
    Handlers.utils.hasMatchingTag("Action", "CalculateRewards"),
    function(msg)
        local waveIndex = msg.WaveIndex
        local moneyMultiplier = msg.MoneyMultiplier
        local partyStrengthsJson = msg.PartyStrengths
        local hasVoucher = msg.HasVoucher == "true"

        if not waveIndex or not moneyMultiplier or not partyStrengthsJson then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "WaveIndex, MoneyMultiplier, and PartyStrengths required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local partyStrengths = json.decode(partyStrengthsJson)
        local result = calculateRewards(waveIndex, moneyMultiplier, partyStrengths, hasVoucher)

        ao.send({
            Target = msg.From,
            Action = "RewardsCalculated",
            Data = json.encode(result),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- GenerateTrainer Handler (Main Entry Point)
Handlers.add("generate-trainer",
    Handlers.utils.hasMatchingTag("Action", "GenerateTrainer"),
    function(msg)
        local waveIndex = tonumber(msg.WaveIndex)
        local gameMode = msg.GameMode or "classic"
        local biomeType = tonumber(msg.BiomeType) or 1
        local seed = tonumber(msg.Seed) or (waveIndex * 12345)

        if not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "WaveIndex required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        -- Check for fixed trainer encounter
        local isFixed = isFixedTrainerWave(waveIndex, gameMode)
        local fixedTrainer = getFixedTrainer(waveIndex, gameMode)

        -- Placeholder: This would lookup trainer config from trainer-data-engine
        local trainerConfig = {
            partyTemplate = {
                size = fixedTrainer and 6 or 3,
                strength = 3, -- AVERAGE
                balanced = true,
                minIV = isFixed and 20 or 10,
                allowHidden = isFixed
            },
            specialtyType = fixedTrainer and fixedTrainer.specialtyType or nil,
            name = fixedTrainer and fixedTrainer.name or "Trainer"
        }

        -- Calculate party levels
        local partyLevels = calculatePartyLevels(waveIndex, trainerConfig.partyTemplate)

        -- Generate trainer party (would use species pool from trainer-data-engine)
        -- For now, using placeholder selection method
        local selectionMethod = fixedTrainer and "signature" or "random"
        local selectionData = {} -- Would come from trainer-data-engine

        -- Note: In production, this would call generateTrainerParty with real data
        -- For now, we return a structured placeholder

        -- Generate AI configuration
        local aiConfig = generateAIConfig(0, nil, waveIndex)

        -- Calculate rewards
        local partyStrengths = {}
        for i = 1, trainerConfig.partyTemplate.size do
            partyStrengths[i] = trainerConfig.partyTemplate.strength
        end
        local rewards = calculateRewards(waveIndex, 1.0, partyStrengths, false)

        -- Generate dialogue keys
        local dialogueKeys = {
            encounter = trainerConfig.name .. ".encounter." .. (fixedTrainer and "boss" or "standard"),
            victory = trainerConfig.name .. ".victory",
            defeat = trainerConfig.name .. ".defeat"
        }

        -- Return complete trainer data
        ao.send({
            Target = msg.From,
            Action = "TrainerGenerated",
            Data = json.encode({
                trainerName = trainerConfig.name,
                waveIndex = waveIndex,
                isFixed = isFixed,
                specialtyType = trainerConfig.specialtyType,
                partySize = trainerConfig.partyTemplate.size,
                levels = partyLevels.levels,
                aiConfig = aiConfig,
                rewards = rewards,
                dialogueKeys = dialogueKeys
            }),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- ValidateTrainerType Handler
Handlers.add("validate-trainer-type",
    Handlers.utils.hasMatchingTag("Action", "ValidateTrainerType"),
    function(msg)
        local trainerType = tonumber(msg.TrainerType)
        local biomeType = tonumber(msg.BiomeType)
        local waveIndex = tonumber(msg.WaveIndex)

        if not trainerType or not biomeType or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TrainerType, BiomeType, and WaveIndex required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        -- Validation logic (would check against biome pools from trainer-data-engine)
        local isValid = true
        local reason = nil

        -- Check wave eligibility (basic validation)
        if waveIndex < 1 or waveIndex > 200 then
            isValid = false
            reason = "Wave index out of range (1-200)"
        end

        ao.send({
            Target = msg.From,
            Action = "TrainerTypeValidated",
            IsValid = tostring(isValid),
            Reason = reason or "",
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- GenerateGymLeader Handler
Handlers.add("generate-gym-leader",
    Handlers.utils.hasMatchingTag("Action", "GenerateGymLeader"),
    function(msg)
        -- Input validation
        local wave = tonumber(msg.Wave)
        if not wave then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Wave parameter required"
            })
            return
        end

        -- Check if this is a gym leader wave
        local gymLeader = getGymLeaderForWave(wave)
        if not gymLeader then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "No gym leader at wave " .. tostring(wave)
            })
            return
        end

        -- Get game mode and seed
        local gameMode = msg.GameMode or "Classic"
        local seed = tonumber(msg.Seed) or (wave * 1000)
        setSeed(seed)

        -- Select party template based on wave
        local partyTemplate = getGymLeaderPartyTemplate(wave, gameMode)
        local partyStrengths = expandPartyComposition(partyTemplate)

        -- Calculate party levels
        local baseLevel = calculateBaseLevel(wave)
        local partyLevels = {}
        for i, strength in ipairs(partyStrengths) do
            local level = calculateLevelWithStrength(baseLevel, strength)
            local offset = calculateLevelOffset(baseLevel, strength)
            local finalLevel = math.max(1, level + offset)
            table.insert(partyLevels, finalLevel)
        end

        -- Configure Terastallization
        local teraConfig = configureGymLeaderTera(wave, partyTemplate.size)

        -- Calculate rewards (gym leader multiplier = 2.5x)
        local rewards = calculateRewards(wave, GYM_LEADER_MONEY_MULTIPLIER, partyStrengths, true)

        -- Generate dialogue keys
        local dialogueKeys = generateGymLeaderDialogue(gymLeader.name, wave)

        -- Generate AI configuration
        local aiConfig = {
            switchThreshold = BOSS_TRAINER_SWITCH_MULTIPLIER,
            teraMode = teraConfig.teraMode,
            teraSlot = teraConfig.teraSlot
        }

        -- Return gym leader data
        ao.send({
            Target = msg.From,
            Action = "GymLeaderGenerated",
            Success = "true",
            Wave = tostring(wave),
            TrainerType = "GYM_LEADER",
            TrainerName = gymLeader.name,
            SpecialtyType = tostring(gymLeader.specialtyType),
            PartySize = tostring(partyTemplate.size),
            MoneyReward = tostring(rewards.moneyReward),
            HasBadge = "true",
            BadgeName = gymLeader.name .. " Badge",
            TeraSlot = teraConfig.teraSlot and tostring(teraConfig.teraSlot) or "",
            Data = json.encode({
                party = {size = partyTemplate.size, levels = partyLevels, strengths = partyStrengths},
                ai = aiConfig,
                rewards = rewards,
                dialogue = dialogueKeys,
                specialtyType = gymLeader.specialtyType
            })
        })
    end
)

-- GenerateEliteFour Handler
Handlers.add("generate-elite-four",
    Handlers.utils.hasMatchingTag("Action", "GenerateEliteFour"),
    function(msg)
        -- Input validation
        local wave = tonumber(msg.Wave)
        if not wave then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Wave parameter required"
            })
            return
        end

        -- Check if this is Champion or Elite Four wave
        local isChampion = (wave == CHAMPION_WAVE)
        local seed = tonumber(msg.Seed) or (wave * 1000)

        -- Validate Elite Four progression
        local eliteFourVictories = tonumber(msg.EliteFourProgress) or 0
        local progressValidation = validateEliteFourProgression(wave, eliteFourVictories)
        if not progressValidation.valid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = progressValidation.reason,
                CurrentVictories = tostring(progressValidation.currentVictories),
                RequiredVictories = tostring(progressValidation.requiredVictories)
            })
            return
        end

        local trainerData
        local partyTemplate
        local moneyMultiplier
        local minBST

        if isChampion then
            -- Champion configuration
            trainerData = getChampionForWave(wave, seed)
            partyTemplate = getChampionPartyTemplate()
            moneyMultiplier = CHAMPION_MONEY_MULTIPLIER
            minBST = nil  -- Champion has no BST filter
        else
            -- Elite Four member configuration
            trainerData = getEliteFourMemberForWave(wave, seed)
            if not trainerData then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "No Elite Four member at wave " .. tostring(wave)
                })
                return
            end
            partyTemplate = getEliteFourPartyTemplate()
            moneyMultiplier = ELITE_FOUR_MONEY_MULTIPLIER
            minBST = ELITE_FOUR_MINIMUM_BST
        end

        -- Expand party composition
        local partyStrengths = expandPartyComposition(partyTemplate)

        -- Calculate party levels
        local baseLevel = calculateBaseLevel(wave)
        local partyLevels = {}
        for i, strength in ipairs(partyStrengths) do
            local level = calculateLevelWithStrength(baseLevel, strength)
            local offset = calculateLevelOffset(baseLevel, strength)
            local finalLevel = math.max(1, level + offset)
            table.insert(partyLevels, finalLevel)
        end

        -- Configure Terastallization
        local teraConfig
        if isChampion then
            teraConfig = configureChampionTera(partyTemplate.size)
        else
            teraConfig = configureEliteFourTera(partyTemplate.size, trainerData.memberIndex)
        end

        -- Calculate rewards
        local rewards = calculateRewards(wave, moneyMultiplier, partyStrengths, true)

        -- Generate dialogue keys
        local dialogueKeys
        if isChampion then
            dialogueKeys = generateChampionDialogue(trainerData.name)
        else
            dialogueKeys = generateEliteFourDialogue(trainerData.name, trainerData.memberIndex)
        end

        -- Generate AI configuration (Elite Four/Champion use SMART_TERA)
        local aiConfig = {
            switchThreshold = BOSS_TRAINER_SWITCH_MULTIPLIER,
            teraMode = teraConfig.teraMode,
            teraSlot = teraConfig.teraSlot
        }

        -- Return Elite Four/Champion data
        ao.send({
            Target = msg.From,
            Action = isChampion and "ChampionGenerated" or "EliteFourGenerated",
            Success = "true",
            Wave = tostring(wave),
            TrainerType = isChampion and "CHAMPION" or "ELITE_FOUR",
            TrainerName = trainerData.name,
            MemberIndex = isChampion and "" or tostring(trainerData.memberIndex),
            SpecialtyType = (trainerData.specialtyType and tostring(trainerData.specialtyType)) or "",
            PartySize = tostring(partyTemplate.size),
            MoneyReward = tostring(rewards.moneyReward),
            MinBST = minBST and tostring(minBST) or "",
            TeraSlot = tostring(teraConfig.teraSlot),
            Data = json.encode({
                party = {size = partyTemplate.size, levels = partyLevels, strengths = partyStrengths},
                ai = aiConfig,
                rewards = rewards,
                dialogue = dialogueKeys,
                specialtyType = trainerData.specialtyType,
                minBST = minBST,
                isChampion = isChampion
            })
        })
    end
)

-- ValidateChampionship Handler
Handlers.add("validate-championship",
    Handlers.utils.hasMatchingTag("Action", "ValidateChampionship"),
    function(msg)
        local eliteFourVictories = tonumber(msg.EliteFourVictories) or 0
        local canBattleChampion = validateChampionshipEligibility(eliteFourVictories)

        local nextRequirement
        if eliteFourVictories < 4 then
            local waves = {182, 184, 186, 188}
            nextRequirement = "EliteFour" .. tostring(eliteFourVictories + 1) .. " (Wave " .. tostring(waves[eliteFourVictories + 1]) .. ")"
        else
            nextRequirement = "Champion (Wave 190)"
        end

        ao.send({
            Target = msg.From,
            Action = "ChampionshipValidated",
            Success = "true",
            CanBattleChampion = tostring(canBattleChampion),
            EliteFourComplete = tostring(eliteFourVictories >= 4),
            CurrentVictories = tostring(eliteFourVictories),
            NextRequirement = nextRequirement
        })
    end
)

-- Process initialization
print("Trainer Encounter Engine initialized - ADP v1.0 compliant")
print("Logic engine ready - data lookups via: " .. TRAINER_DATA_ENGINE_PROCESS)
print("Handlers registered: Info, CalculatePartyLevels, CalculateMatchupScore, EvaluateSwitchDecision, CalculateRewards, GenerateTrainer, ValidateTrainerType, GenerateGymLeader, GenerateEliteFour, ValidateChampionship")
print("Handlers: Level calculation, matchup scoring, AI decisions, rewards, gym leaders, Elite Four, championship validation")
