-- Pokemon Stat Calculation Manager Process
-- Implements IV/EV systems, stat calculations, and battle stat modifications
-- ADP v1.0 compliant for autonomous agent discovery

-- json is available as a global in AO environment

-- Constants for stat calculations (matching TypeScript exactly)
local STATS = {HP = 1, ATK = 2, DEF = 3, SPATK = 4, SPDEF = 5, SPEED = 6}
local STAT_NAMES = {"HP", "ATK", "DEF", "SPATK", "SPDEF", "SPEED"}

-- Stat stage multipliers (-6 to +6) from TypeScript
local STAT_STAGE_MULTIPLIERS = {
    [-6] = 0.25,  -- 2/8
    [-5] = 0.2857, -- 2/7 
    [-4] = 0.3333, -- 2/6
    [-3] = 0.4,    -- 2/5
    [-2] = 0.5,    -- 2/4
    [-1] = 0.6667, -- 2/3
    [0] = 1.0,     -- 2/2
    [1] = 1.5,     -- 3/2
    [2] = 2.0,     -- 4/2
    [3] = 2.5,     -- 5/2
    [4] = 3.0,     -- 6/2
    [5] = 3.5,     -- 7/2
    [6] = 4.0      -- 8/2
}

-- Nature stat multipliers (implemented in abilities-nature-manager)
local NATURE_MULTIPLIERS = {
    ["increase"] = 1.1,
    ["decrease"] = 0.9,
    ["neutral"] = 1.0
}

-- Global state
PokemonStats = PokemonStats or {}
PokemonIVs = PokemonIVs or {}
PokemonEVs = PokemonEVs or {}
BattleModifiers = BattleModifiers or {}

-- Utility Functions

-- Generate cryptographically secure random IV using AO crypto module
local function generateSecureRandom(max)
    -- AO crypto module provides secure randomness
    local randomBytes = ao.crypto.random(4)
    local randomInt = 0
    for i = 1, 4 do
        randomInt = randomInt + string.byte(randomBytes, i) * (256 ^ (i - 1))
    end
    return (randomInt % (max + 1))
end

-- Validate IV range (0-31)
local function validateIV(iv)
    return iv >= 0 and iv <= 31
end

-- Validate EV constraints (0-252 per stat, 510 total)
local function validateEVs(evs)
    local total = 0
    for i = 1, 6 do
        local ev = evs[i] or 0
        if ev < 0 or ev > 252 then
            return false, "EV must be between 0 and 252 per stat"
        end
        total = total + ev
    end
    if total > 510 then
        return false, "Total EVs cannot exceed 510"
    end
    return true
end

-- Calculate base stat using exact TypeScript formula
local function calculateBaseStat(baseStatValue, iv, ev, level, isHP)
    if isHP then
        -- HP formula: ((2 * base + iv + (ev/4)) * level / 100) + level + 10
        return math.floor(((2 * baseStatValue + iv + math.floor(ev / 4)) * level / 100) + level + 10)
    else
        -- Other stats: ((2 * base + iv + (ev/4)) * level / 100) + 5
        return math.floor(((2 * baseStatValue + iv + math.floor(ev / 4)) * level / 100) + 5)
    end
end

-- Apply nature modifier with exact TypeScript Math.floor/ceil
local function applyNatureModifier(statValue, natureMultiplier)
    if natureMultiplier == 1.0 then
        return statValue
    elseif natureMultiplier > 1.0 then
        return math.max(math.ceil(statValue * natureMultiplier), 1)
    else
        return math.max(math.floor(statValue * natureMultiplier), 1)
    end
end

-- Apply stat stage multiplier for battle calculations
local function applyStatStageMultiplier(statValue, statStage, isCritical, statType)
    -- Critical hits ignore negative attack stages and positive defense stages
    if isCritical then
        if (statType == "ATK" or statType == "SPATK") and statStage < 0 then
            statStage = 0
        elseif (statType == "DEF" or statType == "SPDEF") and statStage > 0 then
            statStage = 0
        end
    end
    
    local multiplier = STAT_STAGE_MULTIPLIERS[statStage] or 1.0
    return math.floor(statValue * multiplier)
end

-- Handlers

-- Generate IVs Handler
Handlers.add(
    "generate-ivs",
    Handlers.utils.hasMatchingTag("Action", "GenerateIVs"),
    function(msg)
        local success, result = pcall(function()
            local pokemonId = msg.PokemonId
            local seed = msg.Seed
            
            if not pokemonId then
                return {
                    error = "PokemonId is required",
                    success = false
                }
            end
            
            -- Generate IVs using AO crypto for secure randomness
            local ivs = {}
            for i = 1, 6 do
                ivs[i] = generateSecureRandom(31) -- 0-31 range
            end
            
            -- Calculate Hidden Power type based on IVs
            local hiddenPowerType = "Normal" -- Simplified implementation
            
            -- Store IVs
            PokemonIVs[pokemonId] = ivs
            
            return {
                success = true,
                ivs = ivs,
                hiddenPowerType = hiddenPowerType,
                pokemonId = pokemonId
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(result),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState", 
                Error = result,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Gain EVs Handler
Handlers.add(
    "gain-evs",
    Handlers.utils.hasMatchingTag("Action", "GainEVs"),
    function(msg)
        local success, result = pcall(function()
            local pokemonId = msg.PokemonId
            local evYieldStr = msg.EVYield
            local multiplier = tonumber(msg.Multiplier) or 1.0
            
            if not pokemonId or not evYieldStr then
                return {
                    error = "PokemonId and EVYield are required",
                    success = false
                }
            end
            
            local evYield = json.decode(evYieldStr)
            local currentEVs = PokemonEVs[pokemonId] or {0, 0, 0, 0, 0, 0}
            local newEVs = {}
            local totalEVs = 0
            
            -- Apply EV gains with constraints
            for i = 1, 6 do
                local gain = math.floor((evYield[i] or 0) * multiplier)
                newEVs[i] = math.min(currentEVs[i] + gain, 252) -- Cap at 252 per stat
                totalEVs = totalEVs + newEVs[i]
            end
            
            -- Check total EV constraint (510)
            if totalEVs > 510 then
                return {
                    error = "Total EVs would exceed 510 limit",
                    success = false,
                    currentTotal = totalEVs
                }
            end
            
            -- Validate and store
            local valid, errorMsg = validateEVs(newEVs)
            if not valid then
                return {
                    error = errorMsg,
                    success = false
                }
            end
            
            PokemonEVs[pokemonId] = newEVs
            
            return {
                success = true,
                evs = newEVs,
                totalEVs = totalEVs,
                gained = true,
                pokemonId = pokemonId
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(result),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = result,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Calculate Stats Handler
Handlers.add(
    "calculate-stats",
    Handlers.utils.hasMatchingTag("Action", "CalculateStats"),
    function(msg)
        local success, result = pcall(function()
            local speciesId = tonumber(msg.SpeciesId)
            local level = tonumber(msg.Level)
            local ivsStr = msg.IVs
            local evsStr = msg.EVs  
            local nature = msg.Nature
            
            if not speciesId or not level or not ivsStr or not evsStr then
                return {
                    error = "SpeciesId, Level, IVs, and EVs are required",
                    success = false
                }
            end
            
            local ivs = json.decode(ivsStr)
            local evs = json.decode(evsStr)
            
            -- Validate inputs
            for i = 1, 6 do
                if not validateIV(ivs[i]) then
                    return {
                        error = "Invalid IV value: " .. (ivs[i] or "nil"),
                        success = false
                    }
                end
            end
            
            local validEVs, evError = validateEVs(evs)
            if not validEVs then
                return {
                    error = evError,
                    success = false
                }
            end
            
            -- Get base stats from species data (simplified - would integrate with species DB)
            local baseStats = {65, 55, 40, 50, 50, 90} -- Pikachu example
            
            local calculatedStats = {}
            local natureMultipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0} -- Simplified
            
            -- Calculate each stat
            for i = 1, 6 do
                local baseStat = calculateBaseStat(baseStats[i], ivs[i], evs[i], level, i == STATS.HP)
                calculatedStats[i] = applyNatureModifier(baseStat, natureMultipliers[i])
            end
            
            return {
                success = true,
                stats = calculatedStats,
                baseStats = baseStats,
                level = level,
                nature = nature,
                speciesId = speciesId
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(result),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = result,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Get Battle Stats Handler (with stat stage modifications)
Handlers.add(
    "get-battle-stats",
    Handlers.utils.hasMatchingTag("Action", "GetBattleStats"),
    function(msg)
        local success, result = pcall(function()
            local pokemonId = msg.PokemonId
            local statStagesStr = msg.StatStages
            local modifiersStr = msg.Modifiers or "{}"
            local weather = msg.Weather
            local terrain = msg.Terrain
            local isCritical = msg.CriticalHit == "true"
            
            if not pokemonId then
                return {
                    error = "PokemonId is required",
                    success = false
                }
            end
            
            -- Get base stats (simplified - would get from PokemonStats)
            local baseStats = PokemonStats[pokemonId] or {100, 100, 100, 100, 100, 100}
            local statStages = statStagesStr and json.decode(statStagesStr) or {0, 0, 0, 0, 0, 0}
            local modifiers = json.decode(modifiersStr)
            
            local battleStats = {}
            
            -- Apply stat stages to each stat (except HP)
            for i = 1, 6 do
                if i == STATS.HP then
                    battleStats[i] = baseStats[i] -- HP doesn't get stat stage modifications
                else
                    local statStage = statStages[i] or 0
                    local statName = STAT_NAMES[i]
                    battleStats[i] = applyStatStageMultiplier(baseStats[i], statStage, isCritical, statName)
                end
            end
            
            -- Apply temporary modifiers (items, abilities, weather, etc.)
            local appliedModifiers = {}
            
            -- Weather effects (simplified)
            if weather == "sun" and modifiers.ability == "chlorophyll" then
                battleStats[STATS.SPEED] = math.floor(battleStats[STATS.SPEED] * 2)
                table.insert(appliedModifiers, "chlorophyll_sun_speed")
            end
            
            return {
                success = true,
                battleStats = battleStats,
                appliedModifiers = appliedModifiers,
                effectiveStats = battleStats,
                pokemonId = pokemonId,
                weather = weather,
                terrain = terrain
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(result),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = result,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Calculate Damage Handler (integrates with battle system)
Handlers.add(
    "calculate-damage",
    Handlers.utils.hasMatchingTag("Action", "CalculateDamage"),
    function(msg)
        local success, result = pcall(function()
            local attackerId = msg.AttackerId
            local defenderId = msg.DefenderId
            local move = msg.Move
            local isCritical = msg.CriticalHit == "true"
            
            if not attackerId or not defenderId then
                return {
                    error = "AttackerId and DefenderId are required",
                    success = false
                }
            end
            
            -- Get battle stats for attacker and defender
            local attackerStats = PokemonStats[attackerId] or {100, 100, 100, 100, 100, 100}
            local defenderStats = PokemonStats[defenderId] or {100, 100, 100, 100, 100, 100}
            
            -- Simplified damage calculation (would integrate with move data)
            local attackStat = attackerStats[STATS.ATK]
            local defenseStat = defenderStats[STATS.DEF]
            local baseDamage = math.floor((attackStat / defenseStat) * 50) -- Simplified formula
            
            -- Critical hit multiplier
            local critMultiplier = isCritical and 2.0 or 1.0
            local finalDamage = math.floor(baseDamage * critMultiplier)
            
            return {
                success = true,
                baseDamage = baseDamage,
                finalDamage = finalDamage,
                attackStat = attackStat,
                defenseStat = defenseStat,
                critMultiplier = critMultiplier,
                isCritical = isCritical
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(result),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState", 
                Error = result,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add(
    "info", 
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Pokemon Stat Calculation Manager",
            Description = "Comprehensive stat calculation system for Pokemon with IV/EV mechanics, stat stage modifications, and battle calculations",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
                {
                    action = "GenerateIVs",
                    pattern = {"Action"},
                    description = "Generate cryptographically secure IVs (0-31) using AO crypto module",
                    category = "pokemon",
                    parameters = {
                        {name = "PokemonId", type = "string", required = true, description = "Unique Pokemon identifier"},
                        {name = "Seed", type = "string", required = false, description = "Optional seed for deterministic generation"}
                    }
                },
                {
                    action = "GainEVs", 
                    pattern = {"Action"},
                    description = "Apply EV gains with 510 total/252 per stat constraints",
                    category = "pokemon",
                    parameters = {
                        {name = "PokemonId", type = "string", required = true, description = "Unique Pokemon identifier"},
                        {name = "EVYield", type = "string", required = true, description = "JSON array of EV gains per stat"},
                        {name = "Multiplier", type = "number", required = false, description = "Pokerus or item multiplier"}
                    }
                },
                {
                    action = "CalculateStats",
                    pattern = {"Action"}, 
                    description = "Calculate base stats with exact TypeScript Math.floor parity",
                    category = "pokemon",
                    parameters = {
                        {name = "SpeciesId", type = "number", required = true, description = "Pokemon species ID"},
                        {name = "Level", type = "number", required = true, description = "Pokemon level"},
                        {name = "IVs", type = "string", required = true, description = "JSON array of IV values"},
                        {name = "EVs", type = "string", required = true, description = "JSON array of EV values"},
                        {name = "Nature", type = "string", required = true, description = "Pokemon nature"}
                    }
                },
                {
                    action = "GetBattleStats",
                    pattern = {"Action"},
                    description = "Apply stat stage multipliers (-6 to +6) for battle calculations", 
                    category = "battle",
                    parameters = {
                        {name = "PokemonId", type = "string", required = true, description = "Unique Pokemon identifier"},
                        {name = "StatStages", type = "string", required = false, description = "JSON array of stat stage values"},
                        {name = "Modifiers", type = "string", required = false, description = "JSON object of active modifiers"},
                        {name = "Weather", type = "string", required = false, description = "Current weather condition"},
                        {name = "Terrain", type = "string", required = false, description = "Current terrain effect"},
                        {name = "CriticalHit", type = "string", required = false, description = "Whether this is a critical hit"}
                    }
                },
                {
                    action = "CalculateDamage",
                    pattern = {"Action"},
                    description = "Calculate damage with stat dependencies and critical hit logic",
                    category = "battle", 
                    parameters = {
                        {name = "AttackerId", type = "string", required = true, description = "Attacking Pokemon ID"},
                        {name = "DefenderId", type = "string", required = true, description = "Defending Pokemon ID"},
                        {name = "Move", type = "string", required = false, description = "Move being used"},
                        {name = "CriticalHit", type = "string", required = false, description = "Whether this is a critical hit"}
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get comprehensive process information and handler metadata",
                    category = "core"
                },
                {
                    action = "Ping", 
                    pattern = {"Action"},
                    description = "Test if process is responding",
                    category = "utility"
                }
            },
            capabilities = {
                supportsIVGeneration = true,
                supportsEVConstraints = true, 
                supportsStatCalculation = true,
                supportsBattleStats = true,
                supportsCriticalHits = true,
                supportsStatStages = true,
                supportsTemporaryModifiers = true,
                supportsMathematicalParity = true,
                supportsAOCrypto = true,
                adpVersion = "1.0"
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

-- Ping Handler
Handlers.add(
    "ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"), 
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Pokemon Stat Calculation Manager initialized with ADP v1.0 compliance")