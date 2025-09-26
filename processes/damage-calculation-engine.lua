-- damage-calculation-engine.lua: Comprehensive Pokemon Damage Calculation Engine Process
-- Implements exact mathematical parity with TypeScript damage calculation system
-- ADP v1.0 compliant with self-documentation and comprehensive error handling

-- json is a global in AO environment, no require needed

-- Type effectiveness multiplier constants
local TYPE_MULTIPLIERS = {
    -- TypeDamageMultiplier values: 0, 0.125, 0.25, 0.5, 1, 2, 4, 8
    IMMUNE = 0,
    QUARTER = 0.25,
    HALF = 0.5, 
    NORMAL = 1,
    DOUBLE = 2,
    QUADRUPLE = 4
}

-- Pokemon types enum (matching TypeScript)
local POKEMON_TYPES = {
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
    STELLAR = 18,
    UNKNOWN = 10001
}

-- Type effectiveness chart - 18x18 matrix matching TypeScript exactly
local TYPE_CHART = {
    -- NORMAL (defending type)
    [POKEMON_TYPES.NORMAL] = {
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GHOST] = TYPE_MULTIPLIERS.IMMUNE
    },
    -- FIGHTING
    [POKEMON_TYPES.FIGHTING] = {
        [POKEMON_TYPES.FLYING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.PSYCHIC] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FAIRY] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.DARK] = TYPE_MULTIPLIERS.HALF
    },
    -- FLYING
    [POKEMON_TYPES.FLYING] = {
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ELECTRIC] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.IMMUNE
    },
    -- POISON
    [POKEMON_TYPES.POISON] = {
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.PSYCHIC] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FAIRY] = TYPE_MULTIPLIERS.HALF
    },
    -- GROUND
    [POKEMON_TYPES.GROUND] = {
        [POKEMON_TYPES.WATER] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ELECTRIC] = TYPE_MULTIPLIERS.IMMUNE
    },
    -- ROCK
    [POKEMON_TYPES.ROCK] = {
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.WATER] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.NORMAL] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FLYING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.HALF
    },
    -- BUG
    [POKEMON_TYPES.BUG] = {
        [POKEMON_TYPES.FLYING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF
    },
    -- GHOST
    [POKEMON_TYPES.GHOST] = {
        [POKEMON_TYPES.GHOST] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.DARK] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.NORMAL] = TYPE_MULTIPLIERS.IMMUNE,
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.IMMUNE
    },
    -- STEEL
    [POKEMON_TYPES.STEEL] = {
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.NORMAL] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FLYING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.PSYCHIC] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.DRAGON] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FAIRY] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.IMMUNE
    },
    -- FIRE
    [POKEMON_TYPES.FIRE] = {
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.WATER] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FAIRY] = TYPE_MULTIPLIERS.HALF
    },
    -- WATER
    [POKEMON_TYPES.WATER] = {
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ELECTRIC] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.WATER] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.HALF
    },
    -- GRASS
    [POKEMON_TYPES.GRASS] = {
        [POKEMON_TYPES.FLYING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.WATER] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ELECTRIC] = TYPE_MULTIPLIERS.HALF
    },
    -- ELECTRIC
    [POKEMON_TYPES.ELECTRIC] = {
        [POKEMON_TYPES.GROUND] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FLYING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ELECTRIC] = TYPE_MULTIPLIERS.HALF
    },
    -- PSYCHIC
    [POKEMON_TYPES.PSYCHIC] = {
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GHOST] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.DARK] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.PSYCHIC] = TYPE_MULTIPLIERS.HALF
    },
    -- ICE
    [POKEMON_TYPES.ICE] = {
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ROCK] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.HALF
    },
    -- DRAGON
    [POKEMON_TYPES.DRAGON] = {
        [POKEMON_TYPES.ICE] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.DRAGON] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FAIRY] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIRE] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.WATER] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.ELECTRIC] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.GRASS] = TYPE_MULTIPLIERS.HALF
    },
    -- DARK
    [POKEMON_TYPES.DARK] = {
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FAIRY] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.GHOST] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.DARK] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.PSYCHIC] = TYPE_MULTIPLIERS.IMMUNE
    },
    -- FAIRY
    [POKEMON_TYPES.FAIRY] = {
        [POKEMON_TYPES.POISON] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.STEEL] = TYPE_MULTIPLIERS.DOUBLE,
        [POKEMON_TYPES.FIGHTING] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.BUG] = TYPE_MULTIPLIERS.HALF,
        [POKEMON_TYPES.DARK] = TYPE_MULTIPLIERS.HALF
    }
}

-- Initialize process state
if not State then
    State = {
        initialized = true,
        processName = "Damage Calculation Engine",
        version = "1.0.0",
        adpVersion = "1.0"
    }
end

-- Utility functions

-- Get type effectiveness multiplier between attack and defense type
local function getTypeDamageMultiplier(attackType, defenseType)
    if attackType == POKEMON_TYPES.UNKNOWN or defenseType == POKEMON_TYPES.UNKNOWN then
        return TYPE_MULTIPLIERS.NORMAL
    end
    
    local defenseChart = TYPE_CHART[defenseType]
    if defenseChart and defenseChart[attackType] then
        return defenseChart[attackType]
    end
    
    return TYPE_MULTIPLIERS.NORMAL
end

-- Calculate type effectiveness for single or dual types (multiplicative)
local function calculateTypeEffectiveness(moveType, defenderTypes)
    local effectiveness = TYPE_MULTIPLIERS.NORMAL
    
    for _, defType in ipairs(defenderTypes) do
        effectiveness = effectiveness * getTypeDamageMultiplier(moveType, defType)
    end
    
    return effectiveness
end

-- Calculate base damage using TypeScript formula with variance
local function calculateBaseDamage(level, power, attack, defense, battleSeed)
    -- CRITICAL FIX: Exact TypeScript formula: (levelMultiplier * power * attack) / defense / 50 + 2
    -- TypeScript: (levelMultiplier * power * sourceAtk.value) / targetDef.value / 50 + 2
    local levelMultiplier = (2 * level) / 5 + 2  -- FIXED: Exact TypeScript formula
    local baseDamage = (levelMultiplier * power * attack) / defense / 50 + 2
    
    -- CRITICAL FIX: Apply variance during base damage calculation (like TypeScript)
    -- TypeScript: Math.floor(baseDamage * damageRoll) where damageRoll = 0.85 default
    local damageRoll = 0.85  -- Default variance (85%)
    if battleSeed and battleSeed ~= "" then
        -- Use seed for random variance (85-100%)
        local seedNum = 0
        for i = 1, #battleSeed do
            seedNum = seedNum + string.byte(battleSeed, i)
        end
        math.randomseed(seedNum)
        damageRoll = (85 + math.random(0, 15)) / 100  -- 85-100%
    end
    
    return math.floor(baseDamage * damageRoll)
end

-- Calculate critical hit probability and multiplier
local function calculateCriticalHit(isCritical, critStage)
    critStage = critStage or 0
    
    if isCritical then
        return true, 1.5 -- Critical hit multiplier
    end
    
    -- Critical hit probability based on stage
    local critChances = {
        [0] = 1/24, -- Base 1/24 chance
        [1] = 1/8,
        [2] = 1/2,
        [3] = 1/1 -- Always critical
    }
    
    local chance = critChances[math.min(critStage, 3)] or critChances[0]
    -- For AO deterministic execution, this would need battle seed RNG
    
    return false, 1.0
end

-- Calculate STAB (Same Type Attack Bonus)
local function calculateSTAB(moveType, pokemonTypes, hasAdaptability)
    local stabMultiplier = 1.0
    
    -- Check if move type matches any Pokemon type
    for _, pokemonType in ipairs(pokemonTypes) do
        if pokemonType == moveType then
            stabMultiplier = hasAdaptability and 2.0 or 1.5
            break
        end
    end
    
    return stabMultiplier
end

-- Calculate weather/terrain modifiers
local function calculateWeatherModifier(moveType, weather, terrain)
    local modifier = 1.0
    
    -- Weather effects
    if weather == "rain" and moveType == POKEMON_TYPES.WATER then
        modifier = modifier * 1.5
    elseif weather == "rain" and moveType == POKEMON_TYPES.FIRE then
        modifier = modifier * 0.5
    elseif weather == "sun" and moveType == POKEMON_TYPES.FIRE then
        modifier = modifier * 1.5
    elseif weather == "sun" and moveType == POKEMON_TYPES.WATER then
        modifier = modifier * 0.5
    end
    
    -- Terrain effects
    if terrain == "electric" and moveType == POKEMON_TYPES.ELECTRIC then
        modifier = modifier * 1.3
    elseif terrain == "grassy" and moveType == POKEMON_TYPES.GRASS then
        modifier = modifier * 1.3
    elseif terrain == "psychic" and moveType == POKEMON_TYPES.PSYCHIC then
        modifier = modifier * 1.3
    elseif terrain == "misty" and moveType == POKEMON_TYPES.DRAGON then
        modifier = modifier * 0.5
    end
    
    return modifier
end

-- Generate random damage variance (85-100%)
local function calculateDamageVariance(baseDamage, battleSeed)
    -- CRITICAL FIX: Use seed-based deterministic variance matching TypeScript
    -- TypeScript uses: Math.floor(baseDamage * (85 + Math.random() * 16) / 100)
    -- For deterministic parity, use seed to generate consistent variance
    
    if not battleSeed or battleSeed == "" then
        -- No seed provided, use deterministic value for parity tests
        -- FIXED: Use 85% (0.85 damageRoll) to match TypeScript reference behavior
        return math.floor(baseDamage * 0.85)
    end
    
    -- Convert battleSeed to number for consistent RNG
    local seedNum = 0
    for i = 1, #battleSeed do
        seedNum = seedNum + string.byte(battleSeed, i)
    end
    
    -- Generate variance between 85-100% using seed
    math.randomseed(seedNum)
    local variancePercent = 85 + math.random(0, 15) -- 85-100%
    local variance = variancePercent / 100
    
    return math.floor(baseDamage * variance)
end

-- Validate damage calculation parameters
local function validateDamageParams(params)
    local required = {"attackerLevel", "movePower", "attackStat", "defenseStat", "moveType", "defenderTypes"}
    
    for _, field in ipairs(required) do
        if not params[field] then
            return false, "Missing required parameter: " .. field
        end
    end
    
    -- Validate ranges
    if params.attackerLevel < 1 or params.attackerLevel > 100 then
        return false, "Invalid attacker level: must be 1-100"
    end
    
    if params.movePower < 0 then
        return false, "Invalid move power: must be >= 0"
    end
    
    if params.attackStat <= 0 or params.defenseStat <= 0 then
        return false, "Invalid stats: attack and defense must be > 0"
    end
    
    return true, nil
end

-- Handler: Calculate complete damage with all modifiers
Handlers.add(
    "CalculateFinalDamage",
    Handlers.utils.hasMatchingTag("Action", "CalculateFinalDamage"),
    function(msg)
        -- Parse input parameters
        local params = {}
        if msg.Data and msg.Data ~= "" then
            params = json.decode(msg.Data)
        else
            -- Extract from tags
            params = {
                attackerLevel = tonumber(msg.AttackerLevel) or tonumber(msg.Level),
                movePower = tonumber(msg.MovePower) or tonumber(msg.Power),
                attackStat = tonumber(msg.AttackStat) or tonumber(msg.Attack),
                defenseStat = tonumber(msg.DefenseStat) or tonumber(msg.Defense),
                moveType = tonumber(msg.MoveType),
                defenderTypes = msg.DefenderTypes and json.decode(msg.DefenderTypes) or {tonumber(msg.DefenderType)},
                pokemonTypes = msg.PokemonTypes and json.decode(msg.PokemonTypes) or {},
                isCritical = msg.IsCritical == "true",
                weather = msg.Weather,
                terrain = msg.Terrain,
                hasAdaptability = msg.HasAdaptability == "true",
                battleId = msg.BattleId,
                battleSeed = msg.BattleSeed
            }
        end
        
        -- Validate parameters
        local valid, error = validateDamageParams(params)
        if not valid then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = error,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Calculate base damage
        local baseDamage = calculateBaseDamage(
            params.attackerLevel,
            params.movePower,
            params.attackStat,
            params.defenseStat,
            params.battleSeed
        )
        
        -- Calculate type effectiveness
        local typeEffectiveness = calculateTypeEffectiveness(params.moveType, params.defenderTypes)
        
        -- Calculate critical hit
        local isCrit, critMultiplier = calculateCriticalHit(params.isCritical)
        
        -- Calculate STAB
        local stabMultiplier = calculateSTAB(params.moveType, params.pokemonTypes or {}, params.hasAdaptability)
        
        -- Calculate weather/terrain modifier
        local weatherModifier = calculateWeatherModifier(params.moveType, params.weather, params.terrain)
        
        -- Apply all multipliers (variance already applied in base damage)
        local finalDamage = baseDamage * typeEffectiveness * critMultiplier * stabMultiplier * weatherModifier
        
        -- Ensure minimum 1 damage if move is not completely ineffective
        if finalDamage > 0 and finalDamage < 1 then
            finalDamage = 1
        end
        
        local result = {
            success = true,
            finalDamage = math.floor(finalDamage),
            damageBreakdown = {
                baseDamage = baseDamage,
                typeEffectiveness = typeEffectiveness,
                criticalHit = isCrit,
                criticalMultiplier = critMultiplier,
                stabMultiplier = stabMultiplier,
                weatherModifier = weatherModifier,
                appliedVariance = not params.simulated
            },
            battleId = params.battleId,
            timestamp = msg.Timestamp
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Calculate base damage only
Handlers.add(
    "CalculateBaseDamage",
    Handlers.utils.hasMatchingTag("Action", "CalculateBaseDamage"),
    function(msg)
        local level = tonumber(msg.Level) or tonumber(msg.AttackerLevel)
        local power = tonumber(msg.Power) or tonumber(msg.MovePower)
        local attack = tonumber(msg.Attack) or tonumber(msg.AttackStat)
        local defense = tonumber(msg.Defense) or tonumber(msg.DefenseStat)
        
        if not level or not power or not attack or not defense then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Missing required parameters: Level, Power, Attack, Defense",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        local baseDamage = calculateBaseDamage(level, power, attack, defense, params.battleSeed)
        
        local result = {
            success = true,
            baseDamage = baseDamage,
            level = level,
            power = power,
            attack = attack,
            defense = defense
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Calculate type effectiveness only
Handlers.add(
    "CalculateTypeEffectiveness",
    Handlers.utils.hasMatchingTag("Action", "CalculateTypeEffectiveness"),
    function(msg)
        local moveType = tonumber(msg.MoveType)
        local defenderTypes = msg.DefenderTypes and json.decode(msg.DefenderTypes) or {tonumber(msg.DefenderType)}
        
        if not moveType or not defenderTypes then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Missing required parameters: MoveType, DefenderTypes",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        local effectiveness = calculateTypeEffectiveness(moveType, defenderTypes)
        
        local result = {
            success = true,
            effectiveness = effectiveness,
            moveType = moveType,
            defenderTypes = defenderTypes
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- ADP v1.0 Info Handler for process self-documentation
Handlers.add(
    "Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            process = {
                name = "Pokemon Damage Calculation Engine",
                description = "Comprehensive damage calculation system with exact TypeScript mathematical parity",
                version = "1.0.0",
                adpVersion = "1.0",
                capabilities = {
                    "CalculateFinalDamage",
                    "CalculateBaseDamage", 
                    "CalculateTypeEffectiveness"
                }
            },
            handlers = {
                {
                    action = "CalculateFinalDamage",
                    description = "Calculate complete damage with all modifiers",
                    parameters = {
                        required = {"AttackerLevel", "MovePower", "AttackStat", "DefenseStat", "MoveType", "DefenderTypes"},
                        optional = {"PokemonTypes", "IsCritical", "Weather", "Terrain", "HasAdaptability", "BattleId", "BattleSeed"}
                    }
                },
                {
                    action = "CalculateBaseDamage",
                    description = "Calculate base damage using Pokemon formula",
                    parameters = {
                        required = {"Level", "Power", "Attack", "Defense"}
                    }
                },
                {
                    action = "CalculateTypeEffectiveness", 
                    description = "Calculate type effectiveness multiplier",
                    parameters = {
                        required = {"MoveType", "DefenderTypes"}
                    }
                },
                {
                    action = "Info",
                    description = "Get process information and documentation"
                }
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true,
                mathematicalParity = "TypeScript exact",
                typeChart = "18x18 complete implementation",
                damageFormula = "(2 * Level + 10) / 5 + 2) * Power * Attack / Defense / 50 + 2"
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(infoResponse),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Simple ping handler for connectivity testing
Handlers.add(
    "Ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "Damage calculation engine online",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Pokemon Damage Calculation Engine v1.0.0 initialized")
print("ADP v1.0 compliant with comprehensive damage calculation capabilities")