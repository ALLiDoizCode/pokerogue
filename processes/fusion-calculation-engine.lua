-- JSON library is provided by AO runtime environment

-- Pokemon Fusion Calculation Engine AO Process
-- Implements exact TypeScript fusion calculation algorithms
-- ADP v1.0 compliant with monolithic design

-- Embedded Database: Pokemon Stat Constants (matching TypeScript PERMANENT_STATS)
local STAT_INDICES = {
    HP = 1,      -- Stat.HP = 0 (Lua uses 1-based indexing)
    ATK = 2,     -- Stat.ATK = 1  
    DEF = 3,     -- Stat.DEF = 2
    SPATK = 4,   -- Stat.SPATK = 3
    SPDEF = 5,   -- Stat.SPDEF = 4
    SPD = 6      -- Stat.SPD = 5
}

local PERMANENT_STATS = {"HP", "ATK", "DEF", "SPATK", "SPDEF", "SPD"}

-- Embedded Database: Pokemon Type Constants
local POKEMON_TYPES = {
    "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST",
    "STEEL", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON",
    "DARK", "FAIRY", "UNKNOWN"
}

-- Embedded Database: Ability Selection Constants (from TypeScript rates.ts)
local BASE_HIDDEN_ABILITY_CHANCE = 256  -- 256/65536 = 1/256 probability

-- Initialize process state
if not FusionCalculationState then
    FusionCalculationState = {
        initialized = true,
        processVersion = "1.0.0",
        calculationsPerformed = 0
    }
end

-- Utility Functions for Deterministic RNG (matching TypeScript randSeedInt behavior)
local function deterministicRng(seed, max)
    -- Simple deterministic RNG based on seed (matching TypeScript behavior)
    if not seed or not max then return 0 end
    local rngValue = ((seed * 9301 + 49297) % 233280) / 233280
    return math.floor(rngValue * max)
end

-- Core Fusion Stat Calculation (exact TypeScript Math.ceil((baseStats[s] + fusionBaseStats[s]) / 2))
local function calculateFusionStats(baseStats, fusionStats)
    if not baseStats or not fusionStats then
        return nil, "Missing base stats or fusion stats"
    end
    
    local fusionResult = {}
    
    -- Apply fusion stat averaging formula for all PERMANENT_STATS
    for _, statName in ipairs(PERMANENT_STATS) do
        local baseValue = tonumber(baseStats[statName]) or 0
        local fusionValue = tonumber(fusionStats[statName]) or 0
        
        -- Exact TypeScript formula: Math.ceil((baseStats[s] + fusionBaseStats[s]) / 2)
        fusionResult[statName] = math.ceil((baseValue + fusionValue) / 2)
    end
    
    return fusionResult, nil
end

-- Core Fusion Type Determination (exact TypeScript priority logic)
local function determineFusionTypes(baseTypes, fusionTypes)
    if not baseTypes or not fusionTypes then
        return nil, "Missing base types or fusion types"
    end
    
    local resultTypes = {}
    
    -- Primary type from base Pokemon (always first)
    local baseType1 = baseTypes[1]
    if baseType1 then
        table.insert(resultTypes, baseType1)
    else
        return nil, "Missing base primary type"
    end
    
    -- Secondary type logic: fusionType2 != baseType1 ? fusionType2 : fusionType1 != baseType1 ? fusionType1 : baseType2
    local fusionType1 = fusionTypes[1]
    local fusionType2 = fusionTypes[2]
    local baseType2 = baseTypes[2]
    
    local secondaryType = nil
    
    -- Priority: fusionType2 if different from baseType1
    if fusionType2 and fusionType2 ~= baseType1 then
        secondaryType = fusionType2
    -- Next: fusionType1 if different from baseType1
    elseif fusionType1 and fusionType1 ~= baseType1 then
        secondaryType = fusionType1
    -- Finally: baseType2 if exists
    elseif baseType2 then
        secondaryType = baseType2
    end
    
    if secondaryType then
        table.insert(resultTypes, secondaryType)
    end
    
    return resultTypes, nil
end

-- Core Fusion Ability Selection (exact TypeScript probability logic)
local function selectFusionAbility(baseAbilities, fusionAbilities, battleSeed, rngCounter)
    if not baseAbilities or not fusionAbilities then
        return nil, "Missing base abilities or fusion abilities"
    end
    
    local seed = tonumber(battleSeed) or 0
    local counter = tonumber(rngCounter) or 0
    local combinedSeed = seed + counter
    
    -- Hidden ability probability check (BASE_HIDDEN_ABILITY_CHANCE = 256/65536)
    local hiddenAbilityRoll = deterministicRng(combinedSeed, 65536)
    local hasHiddenAbility = hiddenAbilityRoll < BASE_HIDDEN_ABILITY_CHANCE
    
    local ability1 = baseAbilities[1] or fusionAbilities[1]
    local ability2 = baseAbilities[2] or fusionAbilities[2]
    local hiddenAbility = fusionAbilities[3] or baseAbilities[3]
    
    -- Exact TypeScript formula: fusionAbilityIndex = hasHiddenAbility ? 2 : (ability2 != ability1 ? randAbilityIndex : 0)
    if hasHiddenAbility and hiddenAbility then
        return {
            selectedAbility = hiddenAbility,
            abilityIndex = 2,
            selectionMethod = "hidden",
            probabilityUsed = true
        }, nil
    elseif ability2 and ability2 ~= ability1 then
        -- Random selection between ability1 and ability2
        local randAbilityIndex = deterministicRng(combinedSeed + 1, 2)
        local selectedAbility = randAbilityIndex == 0 and ability1 or ability2
        return {
            selectedAbility = selectedAbility,
            abilityIndex = randAbilityIndex,
            selectionMethod = "random",
            probabilityUsed = true
        }, nil
    else
        -- Default to first ability
        return {
            selectedAbility = ability1,
            abilityIndex = 0,
            selectionMethod = "default",
            probabilityUsed = false
        }, nil
    end
end

-- Fusion Creation Validation
local function validateFusionCreation(fusionRequest)
    if not fusionRequest then
        return false, "Missing fusion request data"
    end
    
    local errors = {}
    
    -- Validate base species data
    if not fusionRequest.baseSpecies then
        table.insert(errors, "Missing baseSpecies data")
    elseif not fusionRequest.baseSpecies.baseStats then
        table.insert(errors, "Missing baseSpecies.baseStats")
    end
    
    -- Validate fusion species data
    if not fusionRequest.fusionSpecies then
        table.insert(errors, "Missing fusionSpecies data")
    elseif not fusionRequest.fusionSpecies.baseStats then
        table.insert(errors, "Missing fusionSpecies.baseStats")
    end
    
    -- Validate stat values are numeric
    if fusionRequest.baseSpecies and fusionRequest.baseSpecies.baseStats then
        for _, statName in ipairs(PERMANENT_STATS) do
            local value = fusionRequest.baseSpecies.baseStats[statName]
            if not value or not tonumber(value) then
                table.insert(errors, "Invalid " .. statName .. " value in baseSpecies")
            end
        end
    end
    
    if fusionRequest.fusionSpecies and fusionRequest.fusionSpecies.baseStats then
        for _, statName in ipairs(PERMANENT_STATS) do
            local value = fusionRequest.fusionSpecies.baseStats[statName]
            if not value or not tonumber(value) then
                table.insert(errors, "Invalid " .. statName .. " value in fusionSpecies")
            end
        end
    end
    
    if #errors > 0 then
        return false, table.concat(errors, "; ")
    end
    
    return true, nil
end

-- Handler: Calculate Fusion Stats
Handlers.add("calculateFusionStats",
    Handlers.utils.hasMatchingTag("Action", "calculateFusionStats"),
    function(msg)
        local gameData = msg.Data and json.decode(msg.Data) or {}
        
        if not gameData.baseSpecies or not gameData.fusionSpecies then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing baseSpecies or fusionSpecies data"
            })
            return
        end
        
        local fusionStats, error = calculateFusionStats(
            gameData.baseSpecies.baseStats,
            gameData.fusionSpecies.baseStats
        )
        
        if error then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error
            })
            return
        end
        
        FusionCalculationState.calculationsPerformed = FusionCalculationState.calculationsPerformed + 1
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Operation = "calculateFusionStats",
            Data = json.encode({
                fusionStats = fusionStats,
                calculationMethod = "averaging",
                mathematicalPrecision = "exact"
            })
        })
    end
)

-- Handler: Determine Fusion Type
Handlers.add("determineFusionType",
    Handlers.utils.hasMatchingTag("Action", "determineFusionType"),
    function(msg)
        local gameData = msg.Data and json.decode(msg.Data) or {}
        
        if not gameData.baseTypes or not gameData.fusionTypes then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing baseTypes or fusionTypes data"
            })
            return
        end
        
        local fusionTypes, error = determineFusionTypes(gameData.baseTypes, gameData.fusionTypes)
        
        if error then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Operation = "determineFusionType",
            Data = json.encode({
                fusionTypes = fusionTypes,
                typeMethod = "priority",
                priorityLogic = "fusionType2 -> fusionType1 -> baseType2"
            })
        })
    end
)

-- Handler: Select Fusion Ability
Handlers.add("selectFusionAbility",
    Handlers.utils.hasMatchingTag("Action", "selectFusionAbility"),
    function(msg)
        local gameData = msg.Data and json.decode(msg.Data) or {}
        
        if not gameData.baseAbilities or not gameData.fusionAbilities then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing baseAbilities or fusionAbilities data"
            })
            return
        end
        
        local battleSeed = gameData.battleSeed or msg.Timestamp or 0
        local rngCounter = gameData.rngCounter or 0
        
        local abilityResult, error = selectFusionAbility(
            gameData.baseAbilities,
            gameData.fusionAbilities,
            battleSeed,
            rngCounter
        )
        
        if error then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Operation = "selectFusionAbility",
            Data = json.encode(abilityResult)
        })
    end
)

-- Handler: Validate Fusion Creation
Handlers.add("validateFusionCreation",
    Handlers.utils.hasMatchingTag("Action", "validateFusionCreation"),
    function(msg)
        local gameData = msg.Data and json.decode(msg.Data) or {}
        
        local isValid, error = validateFusionCreation(gameData)
        
        if not isValid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Operation = "validateFusionCreation",
            Data = json.encode({
                valid = true,
                constraintsChecked = true,
                validationLevel = "strict"
            })
        })
    end
)

-- Handler: Calculate Fusion Precision (mathematical precision tracking)
Handlers.add("calculateFusionPrecision",
    Handlers.utils.hasMatchingTag("Action", "calculateFusionPrecision"),
    function(msg)
        local gameData = msg.Data and json.decode(msg.Data) or {}
        
        -- Perform comprehensive fusion calculation with precision tracking
        local baseStats = gameData.baseSpecies and gameData.baseSpecies.baseStats
        local fusionStats = gameData.fusionSpecies and gameData.fusionSpecies.baseStats
        
        if not baseStats or not fusionStats then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing base or fusion stats for precision calculation"
            })
            return
        end
        
        local precisionResults = {}
        
        -- Calculate precision for each stat
        for _, statName in ipairs(PERMANENT_STATS) do
            local baseValue = tonumber(baseStats[statName]) or 0
            local fusionValue = tonumber(fusionStats[statName]) or 0
            local average = (baseValue + fusionValue) / 2
            local ceiledResult = math.ceil(average)
            
            precisionResults[statName] = {
                baseValue = baseValue,
                fusionValue = fusionValue,
                exactAverage = average,
                ceiledResult = ceiledResult,
                precisionLoss = ceiledResult - average,
                mathematicalAccuracy = "exact"
            }
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Operation = "calculateFusionPrecision",
            Data = json.encode({
                precisionResults = precisionResults,
                overallPrecision = "exact",
                formulaUsed = "Math.ceil((baseStats[s] + fusionBaseStats[s]) / 2)"
            })
        })
    end
)

-- ADP v1.0 Compliant Info Handler
Handlers.add("Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Pokemon Fusion Calculation Engine",
            Description = "AO process for Pokemon fusion stat, type, and ability calculations with exact TypeScript parity",
            Version = FusionCalculationState.processVersion,
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            calculationsPerformed = FusionCalculationState.calculationsPerformed,
            handlers = {
                {
                    action = "calculateFusionStats",
                    pattern = {"Action"},
                    description = "Calculate fusion base stats using averaging formula: Math.ceil((baseStats + fusionStats) / 2)",
                    category = "fusion",
                    parameters = {
                        {name = "baseSpecies", type = "object", required = true, description = "Base Pokemon species data with baseStats"},
                        {name = "fusionSpecies", type = "object", required = true, description = "Fusion Pokemon species data with baseStats"}
                    }
                },
                {
                    action = "determineFusionType",
                    pattern = {"Action"},
                    description = "Determine fusion types using priority rules: fusionType2 -> fusionType1 -> baseType2",
                    category = "fusion",
                    parameters = {
                        {name = "baseTypes", type = "array", required = true, description = "Base Pokemon type array"},
                        {name = "fusionTypes", type = "array", required = true, description = "Fusion Pokemon type array"}
                    }
                },
                {
                    action = "selectFusionAbility",
                    pattern = {"Action"},
                    description = "Select fusion ability using probability: hasHiddenAbility ? 2 : (ability2 != ability1 ? randIndex : 0)",
                    category = "fusion",
                    parameters = {
                        {name = "baseAbilities", type = "array", required = true, description = "Base Pokemon ability array"},
                        {name = "fusionAbilities", type = "array", required = true, description = "Fusion Pokemon ability array"},
                        {name = "battleSeed", type = "number", required = false, description = "Battle seed for deterministic RNG"},
                        {name = "rngCounter", type = "number", required = false, description = "RNG counter for reproducible results"}
                    }
                },
                {
                    action = "validateFusionCreation",
                    pattern = {"Action"},
                    description = "Validate fusion creation parameters and constraints",
                    category = "fusion",
                    parameters = {
                        {name = "fusionRequest", type = "object", required = true, description = "Complete fusion request data for validation"}
                    }
                },
                {
                    action = "calculateFusionPrecision",
                    pattern = {"Action"},
                    description = "Calculate and track mathematical precision for fusion calculations",
                    category = "fusion",
                    parameters = {
                        {name = "baseSpecies", type = "object", required = true, description = "Base species for precision tracking"},
                        {name = "fusionSpecies", type = "object", required = true, description = "Fusion species for precision tracking"}
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
                supportsFusionCalculations = true,
                supportsStatCalculations = true,
                supportsTypeCalculations = true,
                supportsAbilitySelection = true,
                supportsPrecisionTracking = true,
                supportsValidation = true,
                adpCompliant = true,
                mathematicalParity = true
            },
            embeddedDatabases = {
                statIndices = STAT_INDICES,
                permanentStats = PERMANENT_STATS,
                pokemonTypes = POKEMON_TYPES,
                abilityChance = BASE_HIDDEN_ABILITY_CHANCE
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(infoResponse)
        })
    end
)

-- Basic Ping handler for ADP testing
Handlers.add("Ping",
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

print("Pokemon Fusion Calculation Engine initialized - ADP v1.0 compliant")