-- AI Move Selection Engine
-- PokéRogue Stateless AO Process for Pokemon Battle AI
-- Implements: RANDOM, SMART_RANDOM, and SMART AI types with multi-stage evaluation
-- Version: 1.0.0
-- ADP Compliance: v1.0

local json = require("json")

-- ============================================================================
-- ENUMERATIONS (Embedded - No External Dependencies)
-- ============================================================================

-- AI sophistication levels (src/enums/ai-type.ts:1-5)
local AiType = {
    RANDOM = 0,        -- Pure random selection (testing only)
    SMART_RANDOM = 1,  -- 5/8 chance best move, 3/8 advance to next
    SMART = 2          -- Probabilistic based on score ratios
}

-- Move damage categories (src/enums/move-category.ts:1-5)
local MoveCategory = {
    PHYSICAL = 0,  -- Physical damage moves
    SPECIAL = 1,   -- Special damage moves
    STATUS = 2     -- Status/non-damaging moves
}

-- Move targeting types (src/enums/move-target.ts)
-- Enum values 0-19 matching TypeScript order exactly
local MoveTarget = {
    USER = 0,                  -- Targets the user (self-buff moves like Swords Dance)
    OTHER = 1,                 -- Single target from opponents or ally
    ALL_OTHERS = 2,            -- Multi-target all except user
    NEAR_OTHER = 3,            -- Adjacent targets in doubles
    ALL_NEAR_OTHERS = 4,       -- All adjacent in doubles
    NEAR_ENEMY = 5,            -- Default single enemy target
    ALL_NEAR_ENEMIES = 6,      -- Adjacent enemies in doubles (Heat Wave)
    RANDOM_NEAR_ENEMY = 7,     -- Random enemy selection
    ALL_ENEMIES = 8,           -- All enemies (Earthquake, Surf, Discharge)
    ATTACKER = 9,              -- Counterattacks targeting the attacker
    NEAR_ALLY = 10,            -- Adjacent ally in doubles
    ALLY = 11,                 -- Ally targeting (Helping Hand)
    USER_OR_NEAR_ALLY = 12,    -- Self or ally
    USER_AND_ALLIES = 13,      -- Self + all allies
    ALL = 14,                  -- Everyone on field
    USER_SIDE = 15,            -- User's side (Reflect, Light Screen)
    ENEMY_SIDE = 16,           -- Enemy's side (Stealth Rock, Spikes)
    BOTH_SIDES = 17,           -- Both sides (Trick Room)
    PARTY = 18,                -- Self (special case)
    CURSE = 19                 -- Type-dependent targeting (Ghost vs non-Ghost)
}

-- Pokemon field positions (src/enums/battler-index.ts:1-11)
local BattlerIndex = {
    ATTACKER = -1,  -- Special: whoever attacks the user
    PLAYER = 0,     -- Player's first Pokemon
    PLAYER_2 = 1,   -- Player's second Pokemon (doubles)
    ENEMY = 2,      -- Enemy's first Pokemon
    ENEMY_2 = 3     -- Enemy's second Pokemon (doubles)
}

-- Move execution modes (src/enums/move-use-mode.ts:16-74)
local MoveUseMode = {
    NORMAL = 1,         -- Normal move usage (deducts PP)
    IGNORE_PP = 2,      -- Ignores PP checks (e.g., Outrage continuation)
    INDIRECT = 3,       -- Called by effect (e.g., Dancer)
    FOLLOW_UP = 4,      -- Part of another move's effect
    REFLECTED = 5,      -- Reflected by Magic Coat/Bounce
    DELAYED_ATTACK = 6  -- Transparent effect (Future Sight)
}

-- Struggle move constant (src/enums/move-id.ts:333, 0-indexed = 332)
local STRUGGLE_MOVE_ID = 332

-- Pokemon types (src/enums/pokemon-type.ts:1-22)
local PokemonType = {
    UNKNOWN = -1,
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
    FAIRY = 17,
    STELLAR = 18
}

-- Ability IDs for type immunities and damage modifiers (src/data/abilities/ability.ts)
local Ability = {
    VOLT_ABSORB = 10,     -- Electric immunity
    WATER_ABSORB = 11,    -- Water immunity
    FLASH_FIRE = 18,      -- Fire immunity
    WONDER_GUARD = 25,    -- Only super-effective moves hit
    LEVITATE = 26,        -- Ground immunity
    LIGHTNING_ROD = 31,   -- Electric immunity + stat boost
    FILTER = 40,          -- Super-effective 0.75x (line 7107-7108)
    THICK_FAT = 47,       -- Fire/Ice 0.5x multiplier (line 6923-6925)
    SOLID_ROCK = 76,      -- Super-effective 0.75x (line 7122-7123)
    HEATPROOF = 85,       -- Fire 0.5x multiplier
    DRY_SKIN = 87,        -- Fire 1.25x, Water immunity
    SAP_SIPPER = 113,     -- Grass immunity
    STORM_DRAIN = 114,    -- Water immunity + stat boost
    MULTISCALE = 136,     -- Full HP 0.5x (line 7187-7188)
    FUR_COAT = 169        -- Physical 0.5x (line 7324-7325)
}

-- Weather types (src/enums/weather-type.ts)
local WeatherType = {
    NONE = 0,
    SUNNY = 1,  -- Sun boosts Fire, weakens Water
    RAIN = 2    -- Rain boosts Water, weakens Fire
}

-- Terrain types (src/enums/terrain-type.ts)
local TerrainType = {
    NONE = 0,
    ELECTRIC = 1,  -- Electric Terrain boosts Electric 1.3x
    MISTY = 4      -- Misty Terrain weakens Dragon 0.5x
}

-- Status effects (src/enums/status-effect.ts)
local StatusEffect = {
    NONE = 0,
    BURN = 6  -- Halves physical damage
}

-- Critical-only moves (always crit)
local CRIT_ONLY_MOVES = {
    [167] = true,  -- Storm Throw
    [556] = true   -- Frost Breath
}

-- ============================================================================
-- TYPE EFFECTIVENESS CHART (18x18 Sparse Matrix)
-- Source: src/data/type.ts:5-267
-- ============================================================================

-- Type effectiveness multipliers
local TypeMultiplier = {
    IMMUNE = 0,
    EIGHTH = 0.125,
    QUARTER = 0.25,
    HALF = 0.5,
    NORMAL = 1,
    DOUBLE = 2,
    QUADRUPLE = 4,
    OCTUPLE = 8
}

-- Sparse type chart: TYPE_CHART[defendingType][attackingType] = multiplier
-- Unlisted combinations default to 1.0 (normal effectiveness)
local TYPE_CHART = {
    [PokemonType.NORMAL] = {
        [PokemonType.FIGHTING] = TypeMultiplier.DOUBLE,
        [PokemonType.GHOST] = TypeMultiplier.IMMUNE
    },
    [PokemonType.FIGHTING] = {
        [PokemonType.FLYING] = TypeMultiplier.DOUBLE,
        [PokemonType.PSYCHIC] = TypeMultiplier.DOUBLE,
        [PokemonType.FAIRY] = TypeMultiplier.DOUBLE,
        [PokemonType.ROCK] = TypeMultiplier.HALF,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.DARK] = TypeMultiplier.HALF
    },
    [PokemonType.FLYING] = {
        [PokemonType.ROCK] = TypeMultiplier.DOUBLE,
        [PokemonType.ELECTRIC] = TypeMultiplier.DOUBLE,
        [PokemonType.ICE] = TypeMultiplier.DOUBLE,
        [PokemonType.FIGHTING] = TypeMultiplier.HALF,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF,
        [PokemonType.GROUND] = TypeMultiplier.IMMUNE
    },
    [PokemonType.POISON] = {
        [PokemonType.GROUND] = TypeMultiplier.DOUBLE,
        [PokemonType.PSYCHIC] = TypeMultiplier.DOUBLE,
        [PokemonType.FIGHTING] = TypeMultiplier.HALF,
        [PokemonType.POISON] = TypeMultiplier.HALF,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF,
        [PokemonType.FAIRY] = TypeMultiplier.HALF
    },
    [PokemonType.GROUND] = {
        [PokemonType.WATER] = TypeMultiplier.DOUBLE,
        [PokemonType.GRASS] = TypeMultiplier.DOUBLE,
        [PokemonType.ICE] = TypeMultiplier.DOUBLE,
        [PokemonType.POISON] = TypeMultiplier.HALF,
        [PokemonType.ROCK] = TypeMultiplier.HALF,
        [PokemonType.ELECTRIC] = TypeMultiplier.IMMUNE
    },
    [PokemonType.ROCK] = {
        [PokemonType.FIGHTING] = TypeMultiplier.DOUBLE,
        [PokemonType.GROUND] = TypeMultiplier.DOUBLE,
        [PokemonType.STEEL] = TypeMultiplier.DOUBLE,
        [PokemonType.WATER] = TypeMultiplier.DOUBLE,
        [PokemonType.GRASS] = TypeMultiplier.DOUBLE,
        [PokemonType.NORMAL] = TypeMultiplier.HALF,
        [PokemonType.FLYING] = TypeMultiplier.HALF,
        [PokemonType.POISON] = TypeMultiplier.HALF,
        [PokemonType.FIRE] = TypeMultiplier.HALF
    },
    [PokemonType.BUG] = {
        [PokemonType.FLYING] = TypeMultiplier.DOUBLE,
        [PokemonType.ROCK] = TypeMultiplier.DOUBLE,
        [PokemonType.FIRE] = TypeMultiplier.DOUBLE,
        [PokemonType.FIGHTING] = TypeMultiplier.HALF,
        [PokemonType.GROUND] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF
    },
    [PokemonType.GHOST] = {
        [PokemonType.GHOST] = TypeMultiplier.DOUBLE,
        [PokemonType.DARK] = TypeMultiplier.DOUBLE,
        [PokemonType.POISON] = TypeMultiplier.HALF,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.NORMAL] = TypeMultiplier.IMMUNE,
        [PokemonType.FIGHTING] = TypeMultiplier.IMMUNE
    },
    [PokemonType.STEEL] = {
        [PokemonType.FIGHTING] = TypeMultiplier.DOUBLE,
        [PokemonType.GROUND] = TypeMultiplier.DOUBLE,
        [PokemonType.FIRE] = TypeMultiplier.DOUBLE,
        [PokemonType.NORMAL] = TypeMultiplier.HALF,
        [PokemonType.FLYING] = TypeMultiplier.HALF,
        [PokemonType.ROCK] = TypeMultiplier.HALF,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.STEEL] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF,
        [PokemonType.PSYCHIC] = TypeMultiplier.HALF,
        [PokemonType.ICE] = TypeMultiplier.HALF,
        [PokemonType.DRAGON] = TypeMultiplier.HALF,
        [PokemonType.FAIRY] = TypeMultiplier.HALF,
        [PokemonType.POISON] = TypeMultiplier.IMMUNE
    },
    [PokemonType.FIRE] = {
        [PokemonType.GROUND] = TypeMultiplier.DOUBLE,
        [PokemonType.ROCK] = TypeMultiplier.DOUBLE,
        [PokemonType.WATER] = TypeMultiplier.DOUBLE,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.STEEL] = TypeMultiplier.HALF,
        [PokemonType.FIRE] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF,
        [PokemonType.ICE] = TypeMultiplier.HALF,
        [PokemonType.FAIRY] = TypeMultiplier.HALF
    },
    [PokemonType.WATER] = {
        [PokemonType.GRASS] = TypeMultiplier.DOUBLE,
        [PokemonType.ELECTRIC] = TypeMultiplier.DOUBLE,
        [PokemonType.STEEL] = TypeMultiplier.HALF,
        [PokemonType.FIRE] = TypeMultiplier.HALF,
        [PokemonType.WATER] = TypeMultiplier.HALF,
        [PokemonType.ICE] = TypeMultiplier.HALF
    },
    [PokemonType.GRASS] = {
        [PokemonType.FLYING] = TypeMultiplier.DOUBLE,
        [PokemonType.POISON] = TypeMultiplier.DOUBLE,
        [PokemonType.BUG] = TypeMultiplier.DOUBLE,
        [PokemonType.FIRE] = TypeMultiplier.DOUBLE,
        [PokemonType.ICE] = TypeMultiplier.DOUBLE,
        [PokemonType.GROUND] = TypeMultiplier.HALF,
        [PokemonType.WATER] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF,
        [PokemonType.ELECTRIC] = TypeMultiplier.HALF
    },
    [PokemonType.ELECTRIC] = {
        [PokemonType.GROUND] = TypeMultiplier.DOUBLE,
        [PokemonType.FLYING] = TypeMultiplier.HALF,
        [PokemonType.STEEL] = TypeMultiplier.HALF,
        [PokemonType.ELECTRIC] = TypeMultiplier.HALF
    },
    [PokemonType.PSYCHIC] = {
        [PokemonType.BUG] = TypeMultiplier.DOUBLE,
        [PokemonType.GHOST] = TypeMultiplier.DOUBLE,
        [PokemonType.DARK] = TypeMultiplier.DOUBLE,
        [PokemonType.FIGHTING] = TypeMultiplier.HALF,
        [PokemonType.PSYCHIC] = TypeMultiplier.HALF
    },
    [PokemonType.ICE] = {
        [PokemonType.FIGHTING] = TypeMultiplier.DOUBLE,
        [PokemonType.ROCK] = TypeMultiplier.DOUBLE,
        [PokemonType.STEEL] = TypeMultiplier.DOUBLE,
        [PokemonType.FIRE] = TypeMultiplier.DOUBLE,
        [PokemonType.ICE] = TypeMultiplier.HALF
    },
    [PokemonType.DRAGON] = {
        [PokemonType.ICE] = TypeMultiplier.DOUBLE,
        [PokemonType.DRAGON] = TypeMultiplier.DOUBLE,
        [PokemonType.FAIRY] = TypeMultiplier.DOUBLE,
        [PokemonType.FIRE] = TypeMultiplier.HALF,
        [PokemonType.WATER] = TypeMultiplier.HALF,
        [PokemonType.GRASS] = TypeMultiplier.HALF,
        [PokemonType.ELECTRIC] = TypeMultiplier.HALF
    },
    [PokemonType.DARK] = {
        [PokemonType.FIGHTING] = TypeMultiplier.DOUBLE,
        [PokemonType.BUG] = TypeMultiplier.DOUBLE,
        [PokemonType.FAIRY] = TypeMultiplier.DOUBLE,
        [PokemonType.GHOST] = TypeMultiplier.HALF,
        [PokemonType.DARK] = TypeMultiplier.HALF,
        [PokemonType.PSYCHIC] = TypeMultiplier.IMMUNE
    },
    [PokemonType.FAIRY] = {
        [PokemonType.POISON] = TypeMultiplier.DOUBLE,
        [PokemonType.STEEL] = TypeMultiplier.DOUBLE,
        [PokemonType.FIGHTING] = TypeMultiplier.HALF,
        [PokemonType.BUG] = TypeMultiplier.HALF,
        [PokemonType.DARK] = TypeMultiplier.HALF,
        [PokemonType.DRAGON] = TypeMultiplier.IMMUNE
    },
    [PokemonType.STELLAR] = {}  -- Stellar has no special interactions
}

-- ============================================================================
-- UTILITY FUNCTIONS (Embedded)
-- ============================================================================

--- Check if move is virtual (called by another move/effect)
-- @param useMode number MoveUseMode constant
-- @return boolean True if virtual (>= INDIRECT)
local function isVirtual(useMode)
    return useMode >= MoveUseMode.INDIRECT
end

--- Seeded random number generator (deterministic)
-- @param seed string Battle seed for deterministic RNG
-- @param max number Maximum value (exclusive)
-- @return number Random integer [0, max)
local function seededRandom(seed, max)
    -- Simple deterministic RNG using seed hash
    local hash = 0
    for i = 1, #seed do
        hash = (hash * 31 + string.byte(seed, i)) % 2147483647
    end
    return hash % max
end

--- Round number to nearest integer
-- @param num number Number to round
-- @return number Rounded integer
local function round(num)
    return math.floor(num + 0.5)
end

--- Check if Pokemon is player-owned
-- @param battlerIndex number BattlerIndex constant
-- @return boolean True if player Pokemon
local function isPlayerPokemon(battlerIndex)
    return battlerIndex < BattlerIndex.ENEMY
end

--- Check if two Pokemon are allies
-- @param index1 number First Pokemon BattlerIndex
-- @param index2 number Second Pokemon BattlerIndex
-- @return boolean True if allies
local function areAllies(index1, index2)
    return isPlayerPokemon(index1) == isPlayerPokemon(index2)
end

-- ============================================================================
-- CORE AI ALGORITHMS
-- ============================================================================

--- Filter moves for usability (PP > 0, not disabled, no restrictions)
-- @param moves table Array of Pokemon moves with PP and flags
-- @return table Filtered array of usable moves
local function filterUsableMoves(moves)
    local usable = {}
    for _, move in ipairs(moves) do
        if move.pp and move.pp > 0 and not move.disabled then
            table.insert(usable, move)
        end
    end
    return usable
end

--- Check if Pokemon has Encore tag forcing a specific move
-- @param pokemon table Pokemon data with tags
-- @return number|nil Encore move ID if present
local function getEncoreMoveId(pokemon)
    if pokemon.tags then
        for _, tag in ipairs(pokemon.tags) do
            if tag.type == "ENCORE" then
                return tag.moveId
            end
        end
    end
    return nil
end

--- Get base type multiplier from type chart
-- @param attackType number Attacking type ID
-- @param defenseType number Defending type ID
-- @return number Type multiplier (0, 0.125, 0.25, 0.5, 1, 2, 4, 8)
local function getTypeMultiplier(attackType, defenseType)
    -- Handle UNKNOWN type (default to 1.0)
    if attackType == PokemonType.UNKNOWN or defenseType == PokemonType.UNKNOWN then
        return TypeMultiplier.NORMAL
    end

    -- Lookup in sparse type chart (defaults to 1.0 for unlisted combinations)
    local defRow = TYPE_CHART[defenseType]
    if defRow and defRow[attackType] then
        return defRow[attackType]
    end

    return TypeMultiplier.NORMAL
end

--- Apply ability modifiers to type effectiveness
-- @param effectiveness number Base type effectiveness
-- @param moveType number Move type ID
-- @param targetAbility number|nil Target's ability ID
-- @return number Modified effectiveness multiplier
local function applyAbilityModifiers(effectiveness, moveType, targetAbility)
    if not targetAbility then
        return effectiveness
    end

    -- Type immunity abilities (0x effectiveness)
    if targetAbility == Ability.LEVITATE and moveType == PokemonType.GROUND then
        return TypeMultiplier.IMMUNE
    elseif targetAbility == Ability.FLASH_FIRE and moveType == PokemonType.FIRE then
        return TypeMultiplier.IMMUNE
    elseif targetAbility == Ability.VOLT_ABSORB and moveType == PokemonType.ELECTRIC then
        return TypeMultiplier.IMMUNE
    elseif targetAbility == Ability.WATER_ABSORB and moveType == PokemonType.WATER then
        return TypeMultiplier.IMMUNE
    elseif targetAbility == Ability.SAP_SIPPER and moveType == PokemonType.GRASS then
        return TypeMultiplier.IMMUNE
    elseif targetAbility == Ability.LIGHTNING_ROD and moveType == PokemonType.ELECTRIC then
        return TypeMultiplier.IMMUNE
    elseif targetAbility == Ability.STORM_DRAIN and moveType == PokemonType.WATER then
        return TypeMultiplier.IMMUNE
    end

    -- Resistance abilities (0.5x effectiveness)
    if targetAbility == Ability.THICK_FAT then
        if moveType == PokemonType.FIRE or moveType == PokemonType.ICE then
            return effectiveness * TypeMultiplier.HALF
        end
    elseif targetAbility == Ability.HEATPROOF and moveType == PokemonType.FIRE then
        return effectiveness * TypeMultiplier.HALF
    elseif targetAbility == Ability.DRY_SKIN then
        if moveType == PokemonType.FIRE then
            -- Dry Skin makes Fire 1.25x effective
            return effectiveness * 1.25
        elseif moveType == PokemonType.WATER then
            return TypeMultiplier.IMMUNE
        end
    end

    -- Wonder Guard: Only super-effective moves hit (effectiveness >= 2)
    if targetAbility == Ability.WONDER_GUARD then
        if effectiveness < TypeMultiplier.DOUBLE then
            return TypeMultiplier.IMMUNE
        end
    end

    return effectiveness
end

--- Get type effectiveness multiplier with dual-type and ability support
-- @param moveType number Move type ID
-- @param targetTypes table Array of target type IDs (1 or 2 types)
-- @param targetAbility number|nil Target's ability ID (optional)
-- @return number Effectiveness multiplier (0, 0.125, 0.25, 0.5, 1, 2, 4, 8)
local function getMoveEffectiveness(moveType, targetTypes, targetAbility)
    -- Calculate base type effectiveness (multiply for dual-types)
    local effectiveness = TypeMultiplier.NORMAL

    for _, defType in ipairs(targetTypes) do
        local multiplier = getTypeMultiplier(moveType, defType)
        effectiveness = effectiveness * multiplier
    end

    -- Apply ability modifiers
    effectiveness = applyAbilityModifiers(effectiveness, moveType, targetAbility)

    return effectiveness
end

--- Check if Pokemon has STAB (Same-Type Attack Bonus)
-- @param pokemonTypes table Array of Pokemon type IDs
-- @param moveType number Move type ID
-- @return boolean True if STAB applies
local function hasStab(pokemonTypes, moveType)
    for _, pType in ipairs(pokemonTypes) do
        if pType == moveType then
            return true
        end
    end
    return false
end

-- ============================================================================
-- DAMAGE CALCULATION MODULE
-- Source: src/field/pokemon.ts:3607-3982
-- ============================================================================

--- Calculate base damage formula
-- Formula: ((2 * Level / 5 + 2) * Power * Atk) / Def / 50 + 2
-- @param level number Attacker level
-- @param power number Move power
-- @param attackStat number Attacker's attack or special attack stat
-- @param defenseStat number Defender's defense or special defense stat
-- @return number Base damage (floored)
local function calculateBaseDamage(level, power, attackStat, defenseStat)
    local levelMultiplier = (2 * level) / 5 + 2
    local baseDamage = (levelMultiplier * power * attackStat) / defenseStat / 50 + 2
    return math.floor(baseDamage)
end

--- Get attack stat based on move category
-- @param pokemon table Pokemon stats
-- @param moveCategory number MoveCategory constant (PHYSICAL or SPECIAL)
-- @return number Attack or Special Attack stat
local function getAttackStat(pokemon, moveCategory)
    if moveCategory == MoveCategory.PHYSICAL then
        return pokemon.stats.atk or 0
    elseif moveCategory == MoveCategory.SPECIAL then
        return pokemon.stats.spAtk or 0
    end
    return 0
end

--- Get defense stat based on move category
-- @param pokemon table Pokemon stats
-- @param moveCategory number MoveCategory constant (PHYSICAL or SPECIAL)
-- @return number Defense or Special Defense stat
local function getDefenseStat(pokemon, moveCategory)
    if moveCategory == MoveCategory.PHYSICAL then
        return pokemon.stats.def or 0
    elseif moveCategory == MoveCategory.SPECIAL then
        return pokemon.stats.spDef or 0
    end
    return 0
end

--- Get critical hit multiplier
-- @param move table Move data
-- @param isCritical boolean Whether critical hit occurred
-- @return number Critical multiplier (1.0 or 1.5)
local function getCriticalMultiplier(move, isCritical)
    -- Crit-only moves always crit (Storm Throw, Frost Breath)
    if CRIT_ONLY_MOVES[move.id] then
        return 1.5
    end

    -- Standard critical hit (Gen 6+: 1.5x)
    if isCritical then
        return 1.5
    end

    return 1.0
end

--- Get random damage variance (seeded for determinism)
-- @param seed string Battle seed
-- @return number Random multiplier [0.85, 1.0]
local function getRandomMultiplier(seed)
    local randValue = seededRandom(seed, 16) + 85  -- Range [85, 100]
    return randValue / 100
end

--- Get weather damage multiplier
-- @param moveType number Move type ID
-- @param weather number WeatherType constant
-- @return number Weather multiplier (0.5, 1.0, or 1.5)
local function getWeatherMultiplier(moveType, weather)
    if weather == WeatherType.RAIN then
        if moveType == PokemonType.WATER then
            return 1.5
        elseif moveType == PokemonType.FIRE then
            return 0.5
        end
    elseif weather == WeatherType.SUNNY then
        if moveType == PokemonType.FIRE then
            return 1.5
        elseif moveType == PokemonType.WATER then
            return 0.5
        end
    end
    return 1.0
end

--- Get terrain damage multiplier
-- @param moveType number Move type ID
-- @param terrain number TerrainType constant
-- @param isGrounded boolean Whether defender is grounded
-- @return number Terrain multiplier (0.5, 1.0, or 1.3)
local function getTerrainMultiplier(moveType, terrain, isGrounded)
    if not isGrounded then
        return 1.0
    end

    if terrain == TerrainType.ELECTRIC then
        if moveType == PokemonType.ELECTRIC then
            return 1.3
        end
    elseif terrain == TerrainType.MISTY then
        if moveType == PokemonType.DRAGON then
            return 0.5
        end
    end
    return 1.0
end

--- Get ability-based damage reduction multiplier
-- @param ability number Defender's ability ID
-- @param defender table Defender Pokemon data
-- @param move table Move data
-- @param effectiveness number Type effectiveness multiplier
-- @return number Ability damage multiplier (0.5, 0.75, or 1.0)
local function getAbilityDamageModifier(ability, defender, move, effectiveness)
    if not ability or ability == 0 then
        return 1.0
    end

    -- Filter/Solid Rock: 0.75x for super-effective moves (effectiveness >= 2)
    if ability == Ability.FILTER or ability == Ability.SOLID_ROCK then
        if effectiveness >= 2.0 then
            return 0.75
        end
    end

    -- Multiscale: 0.5x at full HP
    if ability == Ability.MULTISCALE then
        if defender.hp and defender.maxHp and defender.hp >= defender.maxHp then
            return 0.5
        end
    end

    -- Thick Fat: 0.5x for Fire/Ice moves
    if ability == Ability.THICK_FAT then
        if move.type == PokemonType.FIRE or move.type == PokemonType.ICE then
            return 0.5
        end
    end

    -- Fur Coat: 0.5x for physical moves
    if ability == Ability.FUR_COAT then
        if move.category == MoveCategory.PHYSICAL then
            return 0.5
        end
    end

    return 1.0
end

--- Calculate full damage with all modifiers
-- @param attacker table Attacker Pokemon data
-- @param defender table Defender Pokemon data
-- @param move table Move data
-- @param weather number WeatherType constant
-- @param terrain number TerrainType constant
-- @param isCritical boolean Whether critical hit occurred
-- @param battleSeed string Battle seed for random variance
-- @return table DamageResult {damage, isCritical, isKO}
local function calculateDamage(attacker, defender, move, weather, terrain, isCritical, battleSeed)
    -- Skip status moves (no damage)
    if move.category == MoveCategory.STATUS or not move.power or move.power == 0 then
        return {
            damage = 0,
            isCritical = false,
            isKO = false
        }
    end

    -- Get stats based on move category
    local attackStat = getAttackStat(attacker, move.category)
    local defenseStat = getDefenseStat(defender, move.category)

    -- Calculate base damage
    local baseDamage = calculateBaseDamage(
        attacker.level or 50,
        move.power,
        attackStat,
        defenseStat
    )

    -- Get type effectiveness
    local typeEffectiveness = getMoveEffectiveness(
        move.type,
        defender.types or {PokemonType.NORMAL},
        defender.ability
    )

    -- Calculate STAB multiplier (1.5x if move type matches attacker types)
    local stabMultiplier = 1.0
    if hasStab(attacker.types or {}, move.type) then
        stabMultiplier = 1.5
    end

    -- Get critical hit multiplier
    local critMultiplier = getCriticalMultiplier(move, isCritical)

    -- Get random variance (0.85-1.0)
    local randomMultiplier = getRandomMultiplier(battleSeed or "0")

    -- Get weather multiplier
    local weatherMultiplier = getWeatherMultiplier(move.type, weather or WeatherType.NONE)

    -- Get terrain multiplier
    local terrainMultiplier = getTerrainMultiplier(
        move.type,
        terrain or TerrainType.NONE,
        defender.isGrounded ~= false  -- Default to grounded if not specified
    )

    -- Get ability damage reduction
    local abilityMultiplier = getAbilityDamageModifier(
        defender.ability,
        defender,
        move,
        typeEffectiveness
    )

    -- Apply burn penalty for physical moves (0.5x damage)
    local burnMultiplier = 1.0
    if move.category == MoveCategory.PHYSICAL then
        if attacker.status and attacker.status == StatusEffect.BURN then
            burnMultiplier = 0.5
        end
    end

    -- Calculate final damage with all multipliers
    local finalDamage = baseDamage *
        typeEffectiveness *
        stabMultiplier *
        critMultiplier *
        randomMultiplier *
        weatherMultiplier *
        terrainMultiplier *
        abilityMultiplier *
        burnMultiplier

    -- Floor damage and ensure minimum 1 damage if any damage dealt
    finalDamage = math.floor(finalDamage)
    if finalDamage > 0 and finalDamage < 1 then
        finalDamage = 1
    end

    -- Check if damage would KO
    local isKO = finalDamage >= (defender.hp or 0)

    return {
        damage = finalDamage,
        isCritical = isCritical or (CRIT_ONLY_MOVES[move.id] == true),
        isKO = isKO
    }
end

--- Calculate move benefit score
-- Lines 6600-6650: getUserBenefit + targetBenefit * allyFactor
-- @param move table Move data
-- @param attacker table Attacking Pokemon data
-- @param target table Target Pokemon data
-- @return number Benefit score
local function calculateMoveBenefit(move, attacker, target)
    -- Base scores (simplified - full logic would parse move effects)
    local userBenefit = 0
    local targetBenefit = 0

    -- Attack moves have damage as benefit
    if move.category ~= MoveCategory.STATUS then
        targetBenefit = move.power or 0
    end

    -- Calculate ally factor (Lines 6605)
    local isAlly = areAllies(attacker.battlerIndex, target.battlerIndex)
    local allyFactor = isAlly and -1 or 1

    -- Base target score
    local targetScore = userBenefit + (targetBenefit * allyFactor)

    -- Handle unimplemented or failing moves (Lines 6614-6618)
    if move.unimplemented or move.willFail then
        return -20
    end

    -- Apply type effectiveness and STAB for attack moves (Lines 6619-6648)
    if move.category ~= MoveCategory.STATUS then
        local effectiveness = getMoveEffectiveness(move.type, target.types, target.ability)

        if not isAlly then
            -- Opponent: multiply by effectiveness and STAB
            targetScore = targetScore * effectiveness
            if hasStab(attacker.types, move.type) then
                targetScore = targetScore * 1.5
            end
        else
            -- Ally: divide by effectiveness and STAB
            targetScore = targetScore / effectiveness
            if hasStab(attacker.types, move.type) then
                targetScore = targetScore / 1.5
            end
        end

        -- Score of 0 assumed unimplemented (Lines 6644-6647)
        if targetScore == 0 then
            return -20
        end
    end

    return targetScore
end

--- Detect moves that can KO at least one opponent
-- Lines 6535-6572: Filter moves where damage >= opponent.hp
-- Enhanced with full damage calculation from Story 17.1b
-- @param movePool table Array of usable moves
-- @param attacker table Attacking Pokemon data
-- @param opponents table Array of opponent Pokemon data
-- @param weather number WeatherType constant
-- @param terrain number TerrainType constant
-- @param battleSeed string Battle seed for deterministic RNG
-- @return table Array of KO moves
local function detectKOMoves(movePool, attacker, opponents, weather, terrain, battleSeed)
    local koMoves = {}

    for _, pkmnMove in ipairs(movePool) do
        -- Skip status moves and self-targeting moves (Lines 6541-6543)
        if pkmnMove.category == MoveCategory.STATUS or
           pkmnMove.moveTarget == MoveTarget.ATTACKER then
            goto continue
        end

        -- Check if move can KO any opponent
        for _, opponent in ipairs(opponents) do
            -- Calculate actual damage with all modifiers (conservative: no crit)
            local damageResult = calculateDamage(
                attacker,
                opponent,
                pkmnMove,
                weather or WeatherType.NONE,
                terrain or TerrainType.NONE,
                false,  -- Assume no crit for conservative KO detection
                battleSeed or "0"
            )

            if damageResult.isKO then
                table.insert(koMoves, pkmnMove)
                break  -- This move can KO at least one opponent
            end
        end

        ::continue::
    end

    return koMoves
end

-- ============================================================================
-- TARGET SELECTION FUNCTIONS
-- ============================================================================

--- Get potential targets for a move based on MoveTarget type
-- Implementation of getMoveTargets from src/data/moves/move-utils.ts:52-126
-- Note: VariableTargetAttr moves are out of scope (deferred to Story 17.4+)
-- @param attacker table Attacking Pokemon data {battlerIndex, types, ...}
-- @param moveTarget number MoveTarget enum value
-- @param opponents table Array of opponent Pokemon data
-- @param ally table|nil Optional ally Pokemon data (doubles)
-- @param battleSeed string Battle RNG seed for RANDOM_NEAR_ENEMY selection
-- @return table MoveTargetSet {targets = {battlerIndex, ...}, multiple = boolean}
local function getMoveTargets(attacker, moveTarget, opponents, ally, battleSeed)
    local set = {}
    local multiple = false

    -- Build target set based on MoveTarget type
    -- Lines 72-117 from move-utils.ts
    if moveTarget == MoveTarget.USER or moveTarget == MoveTarget.PARTY then
        -- Self-targeting moves: Swords Dance, Calm Mind, etc.
        set = {attacker}

    elseif moveTarget == MoveTarget.NEAR_OTHER or moveTarget == MoveTarget.OTHER or
           moveTarget == MoveTarget.ALL_NEAR_OTHERS or moveTarget == MoveTarget.ALL_OTHERS then
        -- OTHER: Can target opponents or ally (line 78-82)
        -- Include ally if present, otherwise just opponents
        if ally then
            set = {}
            for _, opp in ipairs(opponents) do
                table.insert(set, opp)
            end
            table.insert(set, ally)
        else
            set = opponents
        end
        multiple = (moveTarget == MoveTarget.ALL_NEAR_OTHERS or moveTarget == MoveTarget.ALL_OTHERS)

    elseif moveTarget == MoveTarget.NEAR_ENEMY or moveTarget == MoveTarget.ALL_NEAR_ENEMIES or
           moveTarget == MoveTarget.ALL_ENEMIES or moveTarget == MoveTarget.ENEMY_SIDE then
        -- Enemy-only moves: normal attacks, entry hazards (line 84-90)
        set = opponents
        multiple = (moveTarget ~= MoveTarget.NEAR_ENEMY)

    elseif moveTarget == MoveTarget.RANDOM_NEAR_ENEMY then
        -- Random enemy selection (line 91-93)
        if #opponents > 0 then
            -- Use battle seed for deterministic random selection
            local seed = tonumber(battleSeed) or 0
            local randomIndex = (seed % #opponents) + 1
            set = {opponents[randomIndex]}
        else
            set = {}
        end

    elseif moveTarget == MoveTarget.ATTACKER then
        -- Counter move targeting (line 94-95)
        -- Return special value BattlerIndex.ATTACKER (-1)
        return {
            targets = {BattlerIndex.ATTACKER},
            multiple = false
        }

    elseif moveTarget == MoveTarget.NEAR_ALLY or moveTarget == MoveTarget.ALLY then
        -- Ally-only moves: Helping Hand (line 96-99)
        if ally then
            set = {ally}
        else
            set = {}
        end

    elseif moveTarget == MoveTarget.USER_OR_NEAR_ALLY or
           moveTarget == MoveTarget.USER_AND_ALLIES or
           moveTarget == MoveTarget.USER_SIDE then
        -- Self + ally moves: self-targeting or team buffs (line 100-105)
        if ally then
            set = {attacker, ally}
        else
            set = {attacker}
        end
        multiple = (moveTarget ~= MoveTarget.USER_OR_NEAR_ALLY)

    elseif moveTarget == MoveTarget.ALL or moveTarget == MoveTarget.BOTH_SIDES then
        -- Everyone on field: Earthquake in doubles, Trick Room (line 106-110)
        set = {}
        table.insert(set, attacker)
        if ally then
            table.insert(set, ally)
        end
        for _, opp in ipairs(opponents) do
            table.insert(set, opp)
        end
        multiple = true

    elseif moveTarget == MoveTarget.CURSE then
        -- Type-dependent targeting: Ghost → opponents, non-Ghost → self (line 111-116)
        local isGhostType = false
        if attacker.types then
            for _, pokemonType in ipairs(attacker.types) do
                if pokemonType == PokemonType.GHOST then
                    isGhostType = true
                    break
                end
            end
        end

        if isGhostType then
            -- Ghost type: target opponents and ally
            set = {}
            for _, opp in ipairs(opponents) do
                table.insert(set, opp)
            end
            if ally then
                table.insert(set, ally)
            end
        else
            -- Non-Ghost type: target self (stat change)
            set = {attacker}
        end
    else
        -- Default fallback: treat as NEAR_ENEMY
        set = opponents
        multiple = false
    end

    -- Filter to only active Pokemon and extract battler indexes (line 119-125)
    local targetIndexes = {}
    for _, target in ipairs(set) do
        -- Check if Pokemon is active (hp > 0)
        if target and target.hp and target.hp > 0 then
            table.insert(targetIndexes, target.battlerIndex)
        end
    end

    return {
        targets = targetIndexes,
        multiple = multiple
    }
end

--- Get next target(s) for a move with probabilistic selection
-- Implementation of getNextTargets from src/field/pokemon.ts:6717-6796
-- This implements the full 6-phase target selection algorithm
-- @param attacker table Attacking Pokemon data {battlerIndex, types, isPlayer, ...}
-- @param move table Move data {moveId, moveTarget, category, hasCounterAttr, ...}
-- @param opponents table Array of opponent Pokemon data
-- @param ally table|nil Optional ally Pokemon data (doubles)
-- @param battleSeed string Battle RNG seed for probabilistic selection
-- @return table Array of battler indexes {2} or {2, 3} or {} or {-1}
local function getNextTargets(attacker, move, opponents, ally, battleSeed)
    -- Phase 1: Get potential targets via getMoveTargets (line 6718-6719)
    local moveTargets = getMoveTargets(
        attacker,
        move.moveTarget or MoveTarget.NEAR_ENEMY,
        opponents,
        ally,
        battleSeed
    )

    -- Filter to only active Pokemon (already done in getMoveTargets)
    local targetIndexes = moveTargets.targets

    -- Phase 2: Multi-target detection and immediate return (line 6720-6723)
    if moveTargets.multiple then
        return targetIndexes  -- Return all targets for AoE moves
    end

    -- If no targets available, handle special cases
    if #targetIndexes == 0 then
        -- Phase 4: Counter move special case (line 6743-6751)
        if move.hasCounterAttr then
            return {BattlerIndex.ATTACKER}  -- Special value -1
        end
        return {}  -- No valid targets
    end

    -- Phase 3: Single-target benefit scoring (line 6731-6741)
    -- Build array of [battlerIndex, benefitScore] pairs
    local benefitScores = {}

    for _, targetIndex in ipairs(targetIndexes) do
        -- Find target Pokemon data from opponents or ally
        local targetPokemon = nil
        for _, opp in ipairs(opponents) do
            if opp.battlerIndex == targetIndex then
                targetPokemon = opp
                break
            end
        end
        if not targetPokemon and ally and ally.battlerIndex == targetIndex then
            targetPokemon = ally
        end

        if targetPokemon then
            -- Calculate benefit score for this target
            local score = calculateMoveBenefit(move, attacker, targetPokemon)

            -- Ally score inversion: multiply by -1 if targeting ally (line 6733)
            -- Check if target is on same side as attacker
            local isSameSide = (targetPokemon.isPlayer == attacker.isPlayer)
            if isSameSide then
                score = score * -1
            end

            table.insert(benefitScores, {targetIndex, score})
        end
    end

    -- Sort benefit scores descending (line 6736-6741)
    table.sort(benefitScores, function(a, b)
        return a[2] > b[2]  -- Sort by score descending
    end)

    -- Edge case: no scored targets (shouldn't happen but defensive)
    if #benefitScores == 0 then
        if move.hasCounterAttr then
            return {BattlerIndex.ATTACKER}
        end
        return {}
    end

    -- Phase 5: Weight normalization and cutoff (line 6753-6767)
    local targetWeights = {}
    for _, scorePair in ipairs(benefitScores) do
        table.insert(targetWeights, scorePair[2])
    end

    local lowestWeight = targetWeights[#targetWeights]

    -- If lowest weight < 1, add abs(lowestWeight - 1) to all weights (line 6757-6761)
    if lowestWeight < 1 then
        local adjustment = math.abs(lowestWeight - 1)
        for i = 1, #targetWeights do
            targetWeights[i] = targetWeights[i] + adjustment
        end
    end

    -- Remove targets with weight < maxWeight/2 (cutoff) (line 6763-6767)
    local maxWeight = targetWeights[1]
    local cutoffIndex = -1
    for i = 1, #targetWeights do
        if targetWeights[i] < maxWeight / 2 then
            cutoffIndex = i
            break
        end
    end

    if cutoffIndex > -1 then
        -- Trim arrays to only include targets above cutoff
        local trimmedWeights = {}
        local trimmedScores = {}
        for i = 1, cutoffIndex - 1 do
            table.insert(trimmedWeights, targetWeights[i])
            table.insert(trimmedScores, benefitScores[i])
        end
        targetWeights = trimmedWeights
        benefitScores = trimmedScores
    end

    -- Edge case: all targets filtered out
    if #targetWeights == 0 then
        if move.hasCounterAttr then
            return {BattlerIndex.ATTACKER}
        end
        return {}
    end

    -- Phase 6: Probabilistic selection (line 6769-6795)
    -- Build cumulative weight thresholds
    local thresholds = {}
    local totalWeight = 0
    for _, weight in ipairs(targetWeights) do
        totalWeight = totalWeight + weight
        table.insert(thresholds, totalWeight)
    end

    -- Generate random value: randBattleSeedInt(totalWeight) (line 6783)
    local seed = tonumber(battleSeed) or 0
    local randValue = seed % math.floor(totalWeight)

    -- Select first target where cumulative weight > random value (line 6786-6793)
    local targetIndex = 1  -- Default to first (best) target
    for i, threshold in ipairs(thresholds) do
        if randValue < threshold then
            targetIndex = i
            break
        end
    end

    -- Return selected target's battler index (line 6795)
    return {benefitScores[targetIndex][1]}
end

--- Sort moves by benefit score (descending)
-- Lines 6660-6666
-- @param movePool table Array of moves
-- @param moveScores table Map of move IDs to scores
-- @return table Sorted array of moves
local function sortMovesByScore(movePool, moveScores)
    local sorted = {}
    for _, move in ipairs(movePool) do
        table.insert(sorted, move)
    end

    table.sort(sorted, function(a, b)
        local scoreA = moveScores[a.moveId] or 0
        local scoreB = moveScores[b.moveId] or 0
        return scoreA > scoreB  -- Descending order
    end)

    return sorted
end

--- Select move based on AI type (probabilistic)
-- Lines 6667-6688
-- @param sortedMoves table Sorted array of moves
-- @param moveScores table Map of move IDs to scores
-- @param aiType number AiType constant
-- @param battleSeed string Deterministic RNG seed
-- @return number Index in sortedMoves array (1-indexed)
local function selectByAiType(sortedMoves, moveScores, aiType, battleSeed)
    local r = 1  -- Lua is 1-indexed

    if aiType == AiType.RANDOM then
        -- Pure random selection (Lines 6524-6526)
        r = seededRandom(battleSeed, #sortedMoves) + 1
    elseif aiType == AiType.SMART_RANDOM then
        -- 5/8 chance best move, 3/8 advance to next (Lines 6668-6672)
        while r < #sortedMoves and seededRandom(battleSeed .. r, 8) >= 5 do
            r = r + 1
        end
    elseif aiType == AiType.SMART then
        -- Advance probability based on score ratios (Lines 6673-6687)
        while r < #sortedMoves do
            local currentScore = moveScores[sortedMoves[r].moveId] or 0
            local nextScore = moveScores[sortedMoves[r + 1].moveId] or 0

            -- Skip if next score is negative ratio (Line 6677)
            if nextScore / currentScore < 0 then
                break
            end

            -- Calculate advance probability: (nextScore / currentScore) * 50
            local advanceProbability = round((nextScore / currentScore) * 50)

            if seededRandom(battleSeed .. r, 100) < advanceProbability then
                r = r + 1
            else
                break
            end
        end
    end

    return r
end

--- Main AI move selection algorithm
-- Lines 6479-6710: Complete getNextMove() implementation
-- @param msg table AO message with pokemon, opponents, field data
-- @return table TurnMove structure {moveId, targets, useMode, score}
local function evaluateMoveSelection(msg)
    local data = json.decode(msg.Data or "{}")
    local pokemon = data.pokemon
    local opponents = data.opponents or {}
    local field = data.field or {}
    local aiType = tonumber(msg.AiType) or AiType.SMART
    local battleSeed = msg.BattleSeed or tostring(msg.Timestamp)

    -- 1. Process move queue (Lines 6482-6495)
    if pokemon.moveQueue and #pokemon.moveQueue > 0 then
        for i, queuedMove in ipairs(pokemon.moveQueue) do
            if isVirtual(queuedMove.useMode) then
                return {
                    moveId = queuedMove.move,
                    targets = queuedMove.targets,
                    useMode = queuedMove.useMode,
                    score = 0
                }
            end
        end
    end

    -- 2. Filter usable moves (Lines 6497-6499)
    local movePool = filterUsableMoves(pokemon.moves or {})

    -- 3. Handle single move shortcut (Lines 6501-6508)
    if #movePool == 1 then
        return {
            moveId = movePool[1].moveId,
            targets = {BattlerIndex.ENEMY},  -- Default target
            useMode = MoveUseMode.NORMAL,
            score = 0
        }
    end

    -- 4. Check for Encore forced move (Lines 6509-6521)
    local encoreMoveId = getEncoreMoveId(pokemon)
    if encoreMoveId then
        for _, move in ipairs(movePool) do
            if move.moveId == encoreMoveId then
                return {
                    moveId = move.moveId,
                    targets = {BattlerIndex.ENEMY},
                    useMode = MoveUseMode.NORMAL,
                    score = 0
                }
            end
        end
    end

    -- 5. Detect KO moves (Lines 6535-6576)
    local weather = field.weather or WeatherType.NONE
    local terrain = field.terrain or TerrainType.NONE
    local koMoves = detectKOMoves(movePool, pokemon, opponents, weather, terrain, battleSeed)
    if #koMoves > 0 then
        movePool = koMoves
    end

    -- 6. Calculate benefit scores for all moves (Lines 6583-6656)
    local moveScores = {}
    for _, pkmnMove in ipairs(movePool) do
        local maxScore = -999999
        for _, opponent in ipairs(opponents) do
            local score = calculateMoveBenefit(pkmnMove, pokemon, opponent)
            if score > maxScore then
                maxScore = score
            end
        end
        moveScores[pkmnMove.moveId] = maxScore
    end

    -- 7. Sort moves by score (Lines 6660-6666)
    local sortedPool = sortMovesByScore(movePool, moveScores)

    -- 8. Select by AI type (Lines 6667-6688)
    local selectedIndex = selectByAiType(sortedPool, moveScores, aiType, battleSeed)
    local selectedMove = sortedPool[selectedIndex]

    -- Return selected move
    if selectedMove then
        return {
            moveId = selectedMove.moveId,
            targets = {BattlerIndex.ENEMY},  -- Simplified target selection
            useMode = MoveUseMode.NORMAL,
            score = moveScores[selectedMove.moveId]
        }
    end

    -- 9. Struggle fallback (Lines 6704-6709)
    return {
        moveId = STRUGGLE_MOVE_ID,
        targets = {BattlerIndex.ENEMY},
        useMode = MoveUseMode.IGNORE_PP,
        score = -999
    }
end

-- ============================================================================
-- AI SWITCH DECISION LOGIC (Story 17.2)
-- ============================================================================

--- Calculate type effectiveness for defense score
-- Mirrors TypeScript: pokemon.getAttackTypeEffectiveness(enemyType, opponent)
-- @param defendingTypes table Array of Pokemon types
-- @param attackType number Opponent's type
-- @return number Type effectiveness multiplier
local function calculateDefensiveEffectiveness(defendingTypes, attackType)
    local effectiveness = TypeMultiplier.NORMAL

    -- Calculate against first type
    effectiveness = getTypeMultiplier(attackType, defendingTypes[1])

    -- Multiply by second type if present (dual-type)
    if defendingTypes[2] then
        effectiveness = effectiveness * getTypeMultiplier(attackType, defendingTypes[2])
    end

    return math.max(effectiveness, 0.25)  -- Floor at 0.25 per TypeScript
end

--- Calculate matchup score between Pokemon and opponent
-- Source: src/field/pokemon.ts:2557-2629 (getMatchupScore)
-- Evaluates: speed advantage, defensive typing, offensive coverage, HP ratios
-- @param pokemon table Pokemon data {types, moveset, hp, maxHp, stats, isActive}
-- @param opponent table Opponent data {types, hp, maxHp, stats, isLegendary}
-- @return number Matchup score (typically 0-16, max possible 64)
local function getMatchupScore(pokemon, opponent)
    -- 1. Speed comparison (lines 2560-2562)
    local pokemonSpeed = pokemon.stats.spd or 0
    local opponentSpeed = opponent.stats.spd or 0
    local outspeed = pokemonSpeed >= opponentSpeed

    -- 2. Defense score calculation (lines 2568-2572)
    -- Based on how effectively Pokemon defends against opponent's types
    local defScore = 1 / calculateDefensiveEffectiveness(pokemon.types, opponent.types[1])

    -- Apply second type if opponent is dual-type
    if opponent.types[2] then
        defScore = defScore * (1 / calculateDefensiveEffectiveness(pokemon.types, opponent.types[2]))
    end

    -- Cap defense score at 4.0 per TypeScript
    defScore = math.min(defScore, 4.0)

    -- 3. Attack score calculation (lines 2574-2601)
    local atkScore = 0
    local moveAtkScoreLength = 0

    if pokemon.moveset then
        for _, move in ipairs(pokemon.moveset) do
            -- Skip status moves and moves without PP
            if move.category ~= MoveCategory.STATUS and move.pp > 0 then
                local moveType = move.type

                -- Calculate type effectiveness against opponent
                local thisScore = TypeMultiplier.NORMAL
                thisScore = getTypeMultiplier(moveType, opponent.types[1])
                if opponent.types[2] then
                    thisScore = thisScore * getTypeMultiplier(moveType, opponent.types[2])
                end

                -- Apply STAB multiplier (1.5x) if move type matches Pokemon type
                -- Skip moves with VariableMoveTypeAttr per lines 2589-2590
                if not move.hasVariableType then
                    for _, pokemonType in ipairs(pokemon.types) do
                        if pokemonType == moveType then
                            thisScore = thisScore * 1.5
                            break
                        end
                    end
                end

                atkScore = atkScore + thisScore
                moveAtkScoreLength = moveAtkScoreLength + 1
            end
        end
    end

    -- Average attack score (default 1.0 if no damaging moves)
    atkScore = moveAtkScoreLength > 0 and (atkScore / moveAtkScoreLength) or 1.0

    -- 4. HP ratio analysis (lines 2607-2628)
    local hpRatio = pokemon.hp / math.max(pokemon.maxHp, 1)
    local oppHpRatio = opponent.hp / math.max(opponent.maxHp, 1)
    local hpDiffRatio = hpRatio + (1 - oppHpRatio)

    -- Dying Pokemon logic (HP <= 20%)
    local isDying = hpRatio <= 0.2
    if isDying and pokemon.isActive then
        local badMatchup = atkScore < 1.5 and defScore < 1.5
        if not outspeed and badMatchup then
            -- Not a worthy sacrifice if slow and bad matchup
            hpDiffRatio = hpDiffRatio * 0.85
        else
            -- Sacrifice candidate with adjusted ratio
            hpDiffRatio = 1 - hpRatio + (outspeed and 0.2 or 0.1)
        end
    elseif outspeed then
        -- Speed advantage bonus
        hpDiffRatio = hpDiffRatio * 1.25
    elseif hpRatio > 0.2 and hpRatio <= 0.4 then
        -- Moderate HP switch candidate (20-40% HP)
        hpDiffRatio = hpDiffRatio * 0.5
    end

    -- 5. Final score assembly (line 2629)
    return (atkScore + defScore) * math.min(hpDiffRatio, 1)
end

--- Calculate entry hazard damage multiplier for switch evaluation
-- Source: src/data/arena-tag.ts (StealthRockTag, SpikesTag, ToxicSpikesTag, StickyWebTag)
-- @param pokemon table Pokemon data with types and abilities
-- @param hazards table Array of entry hazards {type, layers}
-- @return number Damage multiplier for matchup score (0.5-1.0)
local function getEntryHazardMultiplier(pokemon, hazards)
    if not hazards or #hazards == 0 then
        return 1.0
    end

    local multiplier = 1.0

    for _, hazard in ipairs(hazards) do
        if hazard.type == "STEALTH_ROCK" then
            -- Stealth Rock damage based on type effectiveness
            local rockEffectiveness = getTypeMultiplier(PokemonType.ROCK, pokemon.types[1])
            if pokemon.types[2] then
                rockEffectiveness = rockEffectiveness * getTypeMultiplier(PokemonType.ROCK, pokemon.types[2])
            end

            -- Damage percentages: 0.5x->6.25%, 1x->12.5%, 2x->25%, 4x->50%
            if rockEffectiveness <= 0.25 then
                multiplier = multiplier * 0.9375  -- (1 - 1/16)
            elseif rockEffectiveness <= 0.5 then
                multiplier = multiplier * 0.9375  -- (1 - 1/16)
            elseif rockEffectiveness <= 1.0 then
                multiplier = multiplier * 0.875   -- (1 - 1/8)
            elseif rockEffectiveness <= 2.0 then
                multiplier = multiplier * 0.75    -- (1 - 1/4)
            else  -- 4x weakness
                multiplier = multiplier * 0.5     -- (1 - 1/2)
            end
        elseif hazard.type == "SPIKES" then
            -- Spikes damage: layer 1->1/8, layer 2->1/6, layer 3->1/4
            -- Immunity: Flying type or Levitate ability
            local isImmune = false
            for _, t in ipairs(pokemon.types) do
                if t == PokemonType.FLYING then
                    isImmune = true
                    break
                end
            end
            if pokemon.ability == Ability.LEVITATE then
                isImmune = true
            end

            if not isImmune then
                local layers = hazard.layers or 1
                if layers == 1 then
                    multiplier = multiplier * 0.875   -- (1 - 1/8)
                elseif layers == 2 then
                    multiplier = multiplier * 0.833   -- (1 - 1/6)
                else  -- 3 layers
                    multiplier = multiplier * 0.75    -- (1 - 1/4)
                end
            end
        elseif hazard.type == "TOXIC_SPIKES" then
            -- Toxic Spikes: Badly poison unless Poison/Steel type
            local isImmune = false
            for _, t in ipairs(pokemon.types) do
                if t == PokemonType.POISON or t == PokemonType.STEEL then
                    isImmune = true
                    break
                end
            end

            if not isImmune then
                multiplier = multiplier * 0.9  -- Penalty for poison status
            end
        elseif hazard.type == "STICKY_WEB" then
            -- Sticky Web: Speed reduction unless Flying type or Levitate
            local isImmune = false
            for _, t in ipairs(pokemon.types) do
                if t == PokemonType.FLYING then
                    isImmune = true
                    break
                end
            end
            if pokemon.ability == Ability.LEVITATE then
                isImmune = true
            end

            if not isImmune then
                multiplier = multiplier * 0.95  -- Speed reduction penalty
            end
        end
    end

    return multiplier
end

--- Calculate party member matchup scores for switch evaluation
-- Source: src/field/trainer.ts:559-592 (getPartyMemberMatchupScores)
-- @param currentPokemon table Current active Pokemon
-- @param opponents table Array of active opponent Pokemon
-- @param partyMembers table Array of available party Pokemon
-- @param entryHazards table|nil Entry hazards on field (for forSwitch=true)
-- @param forSwitch boolean Whether evaluating for switch (applies hazards)
-- @return table Array of {partyIndex, matchupScore} tuples
local function getPartyMemberMatchupScores(currentPokemon, opponents, partyMembers, entryHazards, forSwitch)
    local scores = {}

    for _, partyMember in ipairs(partyMembers) do
        -- Skip if already on field (checked by caller)
        -- Skip if fainted (checked by caller)

        local totalScore = 0
        local opponentCount = 0

        -- Score against each active opponent
        for _, opp in ipairs(opponents) do
            local score = getMatchupScore(partyMember, opp)

            -- Legendary opponent penalty (halve score)
            if opp.isLegendary then
                score = score / 2
            end

            totalScore = totalScore + score
            opponentCount = opponentCount + 1
        end

        -- Average score across all opponents
        local avgScore = opponentCount > 0 and (totalScore / opponentCount) or 0

        -- Apply entry hazard penalties if evaluating for switch
        if forSwitch and entryHazards then
            avgScore = avgScore * getEntryHazardMultiplier(partyMember, entryHazards)
        end

        table.insert(scores, {partyMember.partyIndex, avgScore})
    end

    return scores
end

--- Sort party member scores in descending order
-- Source: src/field/trainer.ts:594-603 (getSortedPartyMemberMatchupScores)
-- @param partyMemberScores table Array of {partyIndex, score} tuples
-- @return table Sorted array (descending by score)
local function getSortedPartyMemberMatchupScores(partyMemberScores)
    local sorted = {}
    for _, entry in ipairs(partyMemberScores) do
        table.insert(sorted, entry)
    end

    table.sort(sorted, function(a, b)
        return a[2] > b[2]  -- Descending order
    end)

    return sorted
end

--- Deterministic RNG for tied switch selection
-- Uses battle seed with turn offset matching TypeScript: turn << 2
-- @param seed number Battle seed
-- @param max number Maximum value (exclusive)
-- @return number Random integer [0, max)
local function randSeedInt(seed, max)
    -- Simple LCG matching aos battle RNG patterns
    local a = 1664525
    local c = 1013904223
    local m = 2^32

    local next = (a * seed + c) % m
    return math.floor((next / m) * max)
end

--- Select next Pokemon to switch in (handles ties)
-- Source: src/field/trainer.ts:605-631 (getNextSummonIndex)
-- @param partyMemberScores table Array of {partyIndex, score} tuples
-- @param battleSeed number Battle RNG seed
-- @param battleTurn number Current battle turn
-- @return number Party index to switch in
local function getNextSummonIndex(partyMemberScores, battleSeed, battleTurn)
    if #partyMemberScores == 0 then
        return nil
    end

    local sortedScores = getSortedPartyMemberMatchupScores(partyMemberScores)
    local maxScore = sortedScores[1][2]

    -- Find all Pokemon tied for best score
    local maxScoreIndexes = {}
    for _, entry in ipairs(partyMemberScores) do
        if entry[2] == maxScore then
            table.insert(maxScoreIndexes, entry[1])
        end
    end

    -- Random selection if tied (with battle seed offset: turn << 2)
    if #maxScoreIndexes > 1 then
        local seedOffset = battleSeed + (battleTurn * 4)  -- turn << 2
        local randIndex = randSeedInt(seedOffset, #maxScoreIndexes)
        return maxScoreIndexes[randIndex + 1]  -- Lua 1-indexed
    end

    return maxScoreIndexes[1]
end

--- Evaluate whether to switch Pokemon
-- Source: src/phases/enemy-command-phase.ts:57-87 (EnemyCommandPhase)
-- Implements switch dampening and threshold comparison (boss 2x vs normal 3x)
-- @param currentMatchupScore number Current Pokemon's matchup score
-- @param partyMemberScores table Array of {partyIndex, score} tuples
-- @param isBoss boolean Whether trainer is boss (2x threshold vs 3x)
-- @param switchCounter number Number of switches this battle
-- @return boolean shouldSwitch, number|nil switchToIndex
local function shouldSwitchPokemon(currentMatchupScore, partyMemberScores, isBoss, switchCounter)
    if #partyMemberScores == 0 then
        return false, nil
    end

    local sortedScores = getSortedPartyMemberMatchupScores(partyMemberScores)
    local bestPartyScore = sortedScores[1][2]

    -- Switch dampening formula (line 69): 1 - Math.pow(0.1, 1 / counter)
    -- First switch (counter=1): multiplier = 1.0 (no penalty)
    -- Second switch (counter=2): multiplier ≈ 0.68
    -- Third+ switches: multiplier ≈ 0.36
    local switchMultiplier = 1 - (0.1 ^ (1 / math.max(switchCounter or 1, 1)))

    -- Threshold comparison (line 71)
    -- Boss trainers: 2x threshold (more aggressive switching)
    -- Normal trainers: 3x threshold (conservative switching)
    local threshold = isBoss and 2 or 3

    if bestPartyScore * switchMultiplier >= currentMatchupScore * threshold then
        return true, sortedScores[1][1]  -- Return party index
    end

    return false, nil
end

-- ============================================================================
-- AO MESSAGE HANDLERS
-- ============================================================================

--- Handler: evaluate-move-selection
-- Main AI move evaluation endpoint
Handlers.add("evaluate-move-selection",
    Handlers.utils.hasMatchingTag("Action", "EvaluateMoveSelection"),
    function(msg)
        -- Validate required fields
        if not msg.PokemonId or not msg.AiType or not msg.BattleSeed then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: PokemonId, AiType, BattleSeed",
                Success = "false"
            })
            return
        end

        -- Execute move selection
        local result = evaluateMoveSelection(msg)

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "MoveSelected",
            MoveId = tostring(result.moveId),
            Targets = json.encode(result.targets),
            UseMode = tostring(result.useMode),
            Score = tostring(result.score),
            Success = "true"
        })
    end
)

--- Handler: calculate-move-benefit
-- Individual move benefit calculation
Handlers.add("calculate-move-benefit",
    Handlers.utils.hasMatchingTag("Action", "CalculateMoveBenefit"),
    function(msg)
        -- Validate required fields
        if not msg.MoveId or not msg.AttackerId or not msg.TargetId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: MoveId, AttackerId, TargetId",
                Success = "false"
            })
            return
        end

        local data = json.decode(msg.Data or "{}")
        local move = data.move or {}
        local attacker = data.attacker or {}
        local target = data.target or {}

        local score = calculateMoveBenefit(move, attacker, target)

        ao.send({
            Target = msg.From,
            Action = "BenefitCalculated",
            MoveId = msg.MoveId,
            Score = tostring(score),
            Success = "true"
        })
    end
)

--- Handler: calculate-damage
-- Calculate damage with all modifiers (Story 17.1b)
Handlers.add("calculate-damage",
    Handlers.utils.hasMatchingTag("Action", "CalculateDamage"),
    function(msg)
        -- Validate required fields
        if not msg.Attacker or not msg.Defender or not msg.Move then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: Attacker, Defender, Move",
                Success = "false"
            })
            return
        end

        -- Parse message data
        local attacker = json.decode(msg.Attacker)
        local defender = json.decode(msg.Defender)
        local move = json.decode(msg.Move)
        local isCritical = msg.IsCritical == "true"
        local weather = tonumber(msg.Weather) or WeatherType.NONE
        local terrain = tonumber(msg.Terrain) or TerrainType.NONE
        local battleSeed = msg.BattleSeed or tostring(msg.Timestamp)

        -- Calculate damage
        local result = calculateDamage(
            attacker,
            defender,
            move,
            weather,
            terrain,
            isCritical,
            battleSeed
        )

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Damage = tostring(result.damage),
            IsCritical = tostring(result.isCritical),
            IsKO = tostring(result.isKO),
            Success = "true"
        })
    end
)

--- Handler: get-move-targets
-- Query potential targets for a move without full selection logic (Story 17.1c)
Handlers.add("get-move-targets",
    Handlers.utils.hasMatchingTag("Action", "GetMoveTargets"),
    function(msg)
        -- Validate required fields
        if not msg.MoveId or not msg.MoveTarget then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: MoveId, MoveTarget",
                Success = "false"
            })
            return
        end

        local data = json.decode(msg.Data or "{}")
        local attacker = data.attacker or {}
        local opponents = data.opponents or {}
        local ally = data.ally
        local battleSeed = msg.BattleSeed or tostring(msg.Timestamp)

        -- Get potential targets
        local moveTargets = getMoveTargets(
            attacker,
            tonumber(msg.MoveTarget),
            opponents,
            ally,
            battleSeed
        )

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            MoveId = msg.MoveId,
            Targets = json.encode(moveTargets.targets),
            Multiple = tostring(moveTargets.multiple),
            Success = "true"
        })
    end
)

--- Handler: detect-ko-moves
-- Find moves that can KO opponents
Handlers.add("detect-ko-moves",
    Handlers.utils.hasMatchingTag("Action", "DetectKOMoves"),
    function(msg)
        -- Validate required fields
        if not msg.AttackerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required field: AttackerId",
                Success = "false"
            })
            return
        end

        local data = json.decode(msg.Data or "{}")
        local moves = data.moves or {}
        local attacker = data.attacker or {}
        local targets = data.targets or {}
        local weather = data.weather or WeatherType.NONE
        local terrain = data.terrain or TerrainType.NONE
        local battleSeed = msg.BattleSeed or tostring(msg.Timestamp)

        local koMoves = detectKOMoves(moves, attacker, targets, weather, terrain, battleSeed)
        local koMoveIds = {}
        for _, move in ipairs(koMoves) do
            table.insert(koMoveIds, move.moveId)
        end

        ao.send({
            Target = msg.From,
            Action = "KOMovesDetected",
            KOMoves = json.encode(koMoveIds),
            Count = tostring(#koMoves),
            Success = "true"
        })
    end
)

--- Handler: health-check
-- Process health status check
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthCheckResponse",
            Status = "healthy",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp),
            Success = "true"
        })
    end
)

--- Handler: evaluate-switch-decision
-- Main switch decision evaluation endpoint
-- Source: Story 17.2 - AI Switch Decision Logic
Handlers.add("evaluate-switch-decision",
    Handlers.utils.hasMatchingTag("Action", "EvaluateSwitchDecision"),
    function(msg)
        -- Parse input data
        local data = json.decode(msg.Data or "{}")

        -- Validate required fields
        if not data.currentPokemon or not data.opponents or not data.partyMembers then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: currentPokemon, opponents, partyMembers",
                Success = "false"
            })
            return
        end

        -- Extract parameters
        local currentPokemon = data.currentPokemon
        local opponents = data.opponents
        local partyMembers = data.partyMembers
        local entryHazards = data.entryHazards
        local isBoss = data.isBoss or false
        local switchCounter = data.enemySwitchCounter or 1
        local battleSeed = data.battleSeed or 12345
        local battleTurn = data.battleTurn or 1

        -- Check preconditions (matching EnemyCommandPhase lines 57-60)
        if not data.hasTrainer then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    shouldSwitch = false,
                    reason = "No trainer (wild Pokemon never switch)"
                }),
                Success = "true"
            })
            return
        end

        if data.hasMoveQueue then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    shouldSwitch = false,
                    reason = "Move queue not empty (charging move)"
                }),
                Success = "true"
            })
            return
        end

        if data.isTrapped then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    shouldSwitch = false,
                    reason = "Pokemon is trapped (Wrap, Mean Look, etc.)"
                }),
                Success = "true"
            })
            return
        end

        -- Calculate current Pokemon's matchup score
        local matchupScores = {}
        for _, opp in ipairs(opponents) do
            table.insert(matchupScores, getMatchupScore(currentPokemon, opp))
        end
        local currentMatchupScore = 0
        for _, score in ipairs(matchupScores) do
            currentMatchupScore = currentMatchupScore + score
        end
        currentMatchupScore = #matchupScores > 0 and (currentMatchupScore / #matchupScores) or 0

        -- Calculate party member scores (with entry hazard penalties)
        local partyScores = getPartyMemberMatchupScores(
            currentPokemon,
            opponents,
            partyMembers,
            entryHazards,
            true  -- forSwitch = true
        )

        -- Evaluate switch decision
        local shouldSwitch, switchToIndex = shouldSwitchPokemon(
            currentMatchupScore,
            partyScores,
            isBoss,
            switchCounter
        )

        -- If switching, determine which Pokemon to switch to
        local selectedIndex = nil
        if shouldSwitch then
            selectedIndex = getNextSummonIndex(partyScores, battleSeed, battleTurn)
        end

        -- Calculate switch multiplier and threshold for response
        local switchMultiplier = 1 - (0.1 ^ (1 / math.max(switchCounter, 1)))
        local threshold = isBoss and 2 or 3
        local bestPartyScore = #partyScores > 0 and getSortedPartyMemberMatchupScores(partyScores)[1][2] or 0

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                shouldSwitch = shouldSwitch,
                switchToIndex = selectedIndex or switchToIndex,
                currentMatchupScore = currentMatchupScore,
                bestPartyScore = bestPartyScore,
                switchMultiplier = switchMultiplier,
                threshold = threshold,
                partyScores = partyScores
            }),
            Success = "true"
        })
    end
)

--- Handler: calculate-matchup-score
-- Query individual matchup score for testing/debugging
-- Source: Story 17.2 - AI Switch Decision Logic
Handlers.add("calculate-matchup-score",
    Handlers.utils.hasMatchingTag("Action", "CalculateMatchupScore"),
    function(msg)
        local data = json.decode(msg.Data or "{}")

        if not data.pokemon or not data.opponent then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: pokemon, opponent",
                Success = "false"
            })
            return
        end

        local score = getMatchupScore(data.pokemon, data.opponent)

        -- Calculate component scores for debugging
        local pokemonSpeed = data.pokemon.stats.spd or 0
        local opponentSpeed = data.opponent.stats.spd or 0
        local outspeed = pokemonSpeed >= opponentSpeed

        -- Defense score
        local defScore = 1 / calculateDefensiveEffectiveness(data.pokemon.types, data.opponent.types[1])
        if data.opponent.types[2] then
            defScore = defScore * (1 / calculateDefensiveEffectiveness(data.pokemon.types, data.opponent.types[2]))
        end
        defScore = math.min(defScore, 4.0)

        -- Attack score
        local atkScore = 0
        local moveCount = 0
        if data.pokemon.moveset then
            for _, move in ipairs(data.pokemon.moveset) do
                if move.category ~= MoveCategory.STATUS and move.pp > 0 then
                    local thisScore = getTypeMultiplier(move.type, data.opponent.types[1])
                    if data.opponent.types[2] then
                        thisScore = thisScore * getTypeMultiplier(move.type, data.opponent.types[2])
                    end
                    if not move.hasVariableType then
                        for _, pType in ipairs(data.pokemon.types) do
                            if pType == move.type then
                                thisScore = thisScore * 1.5
                                break
                            end
                        end
                    end
                    atkScore = atkScore + thisScore
                    moveCount = moveCount + 1
                end
            end
        end
        atkScore = moveCount > 0 and (atkScore / moveCount) or 1.0

        -- HP ratio
        local hpRatio = data.pokemon.hp / math.max(data.pokemon.maxHp, 1)
        local oppHpRatio = data.opponent.hp / math.max(data.opponent.maxHp, 1)
        local hpDiffRatio = hpRatio + (1 - oppHpRatio)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                matchupScore = score,
                components = {
                    atkScore = atkScore,
                    defScore = defScore,
                    hpDiffRatio = math.min(hpDiffRatio, 1),
                    outspeed = outspeed
                }
            }),
            Success = "true"
        })
    end
)

--- Handler: info
-- ADP v1.0 self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = "AI Move Selection & Switch Decision Engine",
                    version = "1.1.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "ai-move-selection",
                        "ai-switch-decision",
                        "matchup-scoring",
                        "target-selection",
                        "move-benefit-scoring",
                        "ko-detection",
                        "type-effectiveness",
                        "probabilistic-selection",
                        "entry-hazard-evaluation"
                    }
                },
                handlers = {
                    "info",
                    "evaluate-move-selection",
                    "evaluate-switch-decision",
                    "calculate-matchup-score",
                    "get-move-targets",
                    "calculate-move-benefit",
                    "calculate-damage",
                    "detect-ko-moves",
                    "health-check"
                },
                messageSchemas = {
                    EvaluateMoveSelection = {
                        required = {"PokemonId", "AiType", "BattleSeed", "Data"},
                        description = "Evaluate and select optimal move for AI Pokemon"
                    },
                    EvaluateSwitchDecision = {
                        required = {"Data"},
                        requiredDataFields = {"currentPokemon", "opponents", "partyMembers"},
                        optional = {"entryHazards", "isBoss", "enemySwitchCounter", "battleSeed", "battleTurn"},
                        description = "Evaluate whether to switch Pokemon based on matchup analysis"
                    },
                    CalculateMatchupScore = {
                        required = {"Data"},
                        requiredDataFields = {"pokemon", "opponent"},
                        description = "Calculate matchup score between Pokemon and opponent"
                    },
                    CalculateMoveBenefit = {
                        required = {"MoveId", "AttackerId", "TargetId", "Data"},
                        description = "Calculate benefit score for a move against a target"
                    },
                    CalculateDamage = {
                        required = {"Attacker", "Defender", "Move"},
                        optional = {"IsCritical", "Weather", "Terrain", "BattleSeed"},
                        description = "Calculate damage with all modifiers (STAB, type, abilities, weather, terrain)"
                    },
                    DetectKOMoves = {
                        required = {"AttackerId", "Data"},
                        description = "Detect moves that can KO at least one opponent"
                    },
                    GetMoveTargets = {
                        required = {"MoveId", "AttackerIndex", "Data"},
                        description = "Query potential targets for a move without full selection logic"
                    }
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true
                }
            }),
            Success = "true"
        })
    end
)

-- Process initialization complete
print("AI Move Selection & Switch Decision Engine v1.1.0 initialized")
print("Handlers registered: evaluate-move-selection, evaluate-switch-decision, calculate-matchup-score, get-move-targets, calculate-move-benefit, calculate-damage, detect-ko-moves, health-check, info")
print("ADP v1.0 compliant")
print("Story 17.2 complete: AI Switch Decision Logic integrated")
print("Story 17.1c: Target selection with 6-phase algorithm, multi-target handling, benefit scoring")
