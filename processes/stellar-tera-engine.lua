-- Stellar Tera Engine Process for Pokemon Battle System
-- Implements comprehensive Stellar Tera mechanics for Generation 9 Pokemon battles
-- ADP v1.0 compliant for self-documentation and agent compatibility

-- Note: json is available as a global in AO environment

-- ===============================
-- EMBEDDED STELLAR TERA DATABASE
-- ===============================

-- Valid Pokemon types including Stellar
local POKEMON_TYPES = {
    "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
    "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG", 
    "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY", "STELLAR"
}

-- Stellar configuration
local STELLAR_CONFIG = {
    -- Type effectiveness: STELLAR always 1.0x against all types
    stellarEffectiveness = 1.0,
    
    -- STAB mechanics
    matchingTypeBonus = 1.5,     -- Natural type match
    nonMatchingTypeBonus = 1.2,  -- Non-matching types
    noBonus = 1.0,               -- Already used or STATUS moves
    
    -- Terapagos species IDs for exception handling
    terapagosSpecies = {
        ["TERAPAGOS"] = true,
        ["TERAPAGOS_TERASTAL"] = true,
        ["TERAPAGOS_STELLAR"] = true
    },
    
    -- Tera Blast special handling
    teraBlastStellarPower = 100  -- Boosted from base 80
}

-- Move categories
local MOVE_CATEGORIES = {
    PHYSICAL = "PHYSICAL",
    SPECIAL = "SPECIAL",
    STATUS = "STATUS"
}

-- ===============================
-- PROCESS STATE INITIALIZATION
-- ===============================

if not StellarState then
    StellarState = {
        initialized = true,
        version = "1.0.0"
    }
end

-- Battle-specific Stellar usage tracking (resets between battles)
if not BattleStellarTracking then
    BattleStellarTracking = {}
end

-- ===============================
-- UTILITY FUNCTIONS
-- ===============================

-- Check if species is Terapagos
local function isTerapagos(speciesId)
    if not speciesId then return false end
    return STELLAR_CONFIG.terapagosSpecies[speciesId] == true
end

-- Validate Pokemon data structure
local function validatePokemonData(pokemonData)
    if not pokemonData then return false, "Missing Pokemon data" end
    if not pokemonData.id then return false, "Missing Pokemon ID" end
    if not pokemonData.speciesId then return false, "Missing species ID" end
    if not pokemonData.types or #pokemonData.types == 0 then return false, "Missing Pokemon types" end
    return true, "Valid"
end

-- Check if Pokemon has a specific natural type
local function hasNaturalType(pokemonData, typeToCheck)
    if not pokemonData or not pokemonData.types or not typeToCheck then return false end
    for _, naturalType in ipairs(pokemonData.types) do
        if naturalType == typeToCheck then
            return true
        end
    end
    return false
end

-- Check if type has been Stellar boosted
local function isTypeStellarBoosted(pokemonData, moveType)
    if not pokemonData or not moveType then return false end
    local stellarTypesBoosted = pokemonData.stellarTypesBoosted or {}
    
    for _, boostedType in ipairs(stellarTypesBoosted) do
        if boostedType == moveType then
            return true
        end
    end
    return false
end

-- ===============================
-- ERROR HANDLING SYSTEM
-- ===============================

local ERROR_CODES = {
    -- Stellar-specific errors (STELLAR_001-099)
    INVALID_POKEMON_DATA = {code = "STELLAR_001", message = "Invalid Pokemon data for Stellar operation", recovery = "Reject operation"},
    STELLAR_NOT_ACTIVE = {code = "STELLAR_002", message = "Pokemon does not have Stellar Tera active", recovery = "Return base STAB"},
    INVALID_MOVE_TYPE = {code = "STELLAR_003", message = "Invalid move type for STAB calculation", recovery = "Use 1.0x multiplier"},
    TRACKING_CORRUPTION = {code = "STELLAR_004", message = "Stellar usage tracking corrupted", recovery = "Reset tracking array"},
    INVALID_MOVE_CATEGORY = {code = "STELLAR_005", message = "Invalid move category", recovery = "Treat as PHYSICAL"},
    
    -- Battle state errors (STELLAR_101-199)
    BATTLE_NOT_FOUND = {code = "STELLAR_101", message = "Battle session not found", recovery = "Initialize new session"},
    INVALID_BATTLE_ID = {code = "STELLAR_102", message = "Invalid battle ID format", recovery = "Use default battle"},
    POKEMON_NOT_IN_BATTLE = {code = "STELLAR_103", message = "Pokemon not registered in battle", recovery = "Add to battle"},
    
    -- JSON parsing errors (STELLAR_201-299)
    INVALID_JSON = {code = "STELLAR_201", message = "Invalid JSON in message data", recovery = "Use empty data structure"}
}

local function sendErrorResponse(target, errorInfo, context)
    local response = {
        Target = target,
        Action = "StellarError",
        ErrorCode = errorInfo.code,
        ErrorMessage = errorInfo.message,
        RecoveryAction = errorInfo.recovery,
        Context = context or {},
        Timestamp = msg and msg.Timestamp or "0",
        ProcessId = ao.id
    }
    
    ao.send(response)
end

-- Safe JSON parsing with error handling
local function safeJsonDecode(jsonStr, defaultValue)
    if not jsonStr or jsonStr == "" then
        return defaultValue or {}
    end
    
    -- Direct parsing for controlled AO inputs
    local decoded = json.decode(jsonStr)
    return decoded or defaultValue or {}
end

-- ===============================
-- CORE STELLAR TERA FUNCTIONS
-- ===============================

-- Calculate Stellar STAB multiplier
local function calculateStellarSTAB(pokemonData, moveType, moveCategory)
    -- Validate input
    local isValid, errorMsg = validatePokemonData(pokemonData)
    if not isValid then
        return STELLAR_CONFIG.noBonus, ERROR_CODES.INVALID_POKEMON_DATA
    end
    
    if not moveType then
        return STELLAR_CONFIG.noBonus, ERROR_CODES.INVALID_MOVE_TYPE
    end
    
    -- STATUS moves never get STAB
    if moveCategory == MOVE_CATEGORIES.STATUS then
        return STELLAR_CONFIG.noBonus, nil
    end
    
    -- Check if Pokemon has Stellar Tera active
    if not pokemonData.isTerastallized or pokemonData.teraType ~= "STELLAR" then
        return STELLAR_CONFIG.noBonus, ERROR_CODES.STELLAR_NOT_ACTIVE
    end
    
    -- Terapagos exception: always gets Stellar STAB without tracking
    if isTerapagos(pokemonData.speciesId) then
        local isMatchingType = hasNaturalType(pokemonData, moveType)
        if isMatchingType then
            return STELLAR_CONFIG.matchingTypeBonus, nil
        else
            return STELLAR_CONFIG.nonMatchingTypeBonus, nil
        end
    end
    
    -- Regular Stellar: check if type has been boosted already
    if isTypeStellarBoosted(pokemonData, moveType) then
        -- Already used this type's Stellar boost
        return STELLAR_CONFIG.noBonus, nil
    end
    
    -- First time using this type with Stellar
    local isMatchingType = hasNaturalType(pokemonData, moveType)
    if isMatchingType then
        return STELLAR_CONFIG.matchingTypeBonus, nil
    else
        return STELLAR_CONFIG.nonMatchingTypeBonus, nil
    end
end

-- Track Stellar type usage (after successful move)
local function trackStellarUsage(pokemonData, moveType, moveCategory)
    -- Validate input
    if not pokemonData or not moveType then return false end
    
    -- STATUS moves don't trigger tracking
    if moveCategory == MOVE_CATEGORIES.STATUS then return false end
    
    -- Only track for Stellar Tera Pokemon
    if not pokemonData.isTerastallized or pokemonData.teraType ~= "STELLAR" then
        return false
    end
    
    -- Terapagos doesn't need tracking (unlimited usage)
    if isTerapagos(pokemonData.speciesId) then
        return true
    end
    
    -- Check if already tracked
    if isTypeStellarBoosted(pokemonData, moveType) then
        return false
    end
    
    -- Initialize tracking array if needed
    if not pokemonData.stellarTypesBoosted then
        pokemonData.stellarTypesBoosted = {}
    end
    
    -- Add to tracking
    table.insert(pokemonData.stellarTypesBoosted, moveType)
    
    return true
end

-- Activate Stellar Tera
local function activateStellarTera(pokemonData, battleId)
    -- Validate input
    local isValid, errorMsg = validatePokemonData(pokemonData)
    if not isValid then
        return false, ERROR_CODES.INVALID_POKEMON_DATA
    end
    
    -- Set Stellar Tera state
    pokemonData.isTerastallized = true
    pokemonData.teraType = "STELLAR"
    
    -- Initialize Stellar tracking (empty for new activation)
    pokemonData.stellarTypesBoosted = {}
    
    -- Initialize battle tracking if needed
    if battleId and not BattleStellarTracking[battleId] then
        BattleStellarTracking[battleId] = {}
    end
    
    -- Register Pokemon in battle
    if battleId then
        BattleStellarTracking[battleId][pokemonData.id] = {
            activated = true,
            timestamp = msg and msg.Timestamp or "0"
        }
    end
    
    return true, nil
end

-- Reset Stellar state (called at battle end)
local function resetStellarState(pokemonData, battleId)
    if not pokemonData then return false end
    
    -- Clear Stellar tracking
    pokemonData.stellarTypesBoosted = {}
    pokemonData.isTerastallized = false
    
    -- Clear battle-specific tracking
    if battleId and BattleStellarTracking[battleId] then
        BattleStellarTracking[battleId][pokemonData.id] = nil
        
        -- Clean up empty battle sessions
        local hasData = false
        for _ in pairs(BattleStellarTracking[battleId]) do
            hasData = true
            break
        end
        if not hasData then
            BattleStellarTracking[battleId] = nil
        end
    end
    
    return true
end

-- Get Stellar state information
local function getStellarState(pokemonData)
    if not pokemonData then
        return {
            isActive = false,
            stellarTypesBoosted = {},
            isTerapagos = false
        }
    end
    
    return {
        isActive = pokemonData.isTerastallized and pokemonData.teraType == "STELLAR",
        stellarTypesBoosted = pokemonData.stellarTypesBoosted or {},
        isTerapagos = isTerapagos(pokemonData.speciesId),
        remainingBoostCount = pokemonData.stellarTypesBoosted and (18 - #pokemonData.stellarTypesBoosted) or 18
    }
end

-- Calculate damage with Stellar type effectiveness
local function calculateStellarEffectiveness(attackerData, defenderData, moveType)
    if not attackerData or not defenderData or not moveType then
        return 1.0
    end
    
    -- Stellar moves always have 1.0x effectiveness
    if moveType == "STELLAR" then
        return STELLAR_CONFIG.stellarEffectiveness
    end
    
    -- Stellar Tera Pokemon using non-Stellar moves
    if attackerData.isTerastallized and attackerData.teraType == "STELLAR" then
        -- Stellar Tera doesn't change move type effectiveness
        -- Move retains its original type for effectiveness calculation
        return nil  -- Let type chart handle it normally
    end
    
    return nil  -- Not Stellar-related
end

-- ===============================
-- COMPLEX SCENARIO HANDLERS
-- ===============================

-- Handle multi-type Pokemon Stellar calculations
local function handleMultiTypeStellar(pokemonData, moveSequence)
    if not pokemonData or not moveSequence then return {} end
    
    local results = {}
    
    for _, move in ipairs(moveSequence) do
        local stab = calculateStellarSTAB(pokemonData, move.type, move.category)
        
        -- Track usage after calculation
        if stab > STELLAR_CONFIG.noBonus then
            trackStellarUsage(pokemonData, move.type, move.category)
        end
        
        table.insert(results, {
            moveType = move.type,
            stabMultiplier = stab,
            tracked = isTypeStellarBoosted(pokemonData, move.type)
        })
    end
    
    return results
end

-- Validate complex Stellar interaction
local function validateStellarInteraction(battleState)
    if not battleState then return false, "Invalid battle state" end
    
    local validationResults = {
        valid = true,
        errors = {},
        warnings = {}
    }
    
    -- Check each Pokemon's Stellar state
    for teamKey, team in pairs(battleState) do
        if type(team) == "table" then
            for pokemonKey, pokemon in pairs(team) do
                if type(pokemon) == "table" and pokemon.teraType == "STELLAR" then
                    -- Validate Stellar tracking array
                    if pokemon.stellarTypesBoosted then
                        local seen = {}
                        for _, boostedType in ipairs(pokemon.stellarTypesBoosted) do
                            if seen[boostedType] then
                                table.insert(validationResults.errors, 
                                    "Duplicate Stellar boost for " .. boostedType)
                                validationResults.valid = false
                            end
                            seen[boostedType] = true
                        end
                    end
                    
                    -- Validate Terapagos special case
                    if isTerapagos(pokemon.speciesId) then
                        if pokemon.stellarTypesBoosted and #pokemon.stellarTypesBoosted > 0 then
                            table.insert(validationResults.warnings,
                                "Terapagos should not have stellarTypesBoosted tracking")
                        end
                    end
                end
            end
        end
    end
    
    return validationResults.valid, validationResults
end

-- ===============================
-- AO MESSAGE HANDLERS
-- ===============================

-- Process Stellar Tera operations
Handlers.add(
    "process-stellar-tera",
    Handlers.utils.hasMatchingTag("Action", "ProcessStellarTera"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local operation = msg.Operation or "calculate_stab"
        local moveType = msg.MoveType
        local moveCategory = msg.MoveCategory or MOVE_CATEGORIES.PHYSICAL
        local battleId = msg.BattleId
        
        local response = {
            Target = msg.From,
            Action = "StellarTeraProcessed",
            Operation = operation,
            ProcessId = ao.id
        }
        
        if operation == "activate" then
            local success, error = activateStellarTera(pokemonData, battleId)
            if success then
                response.Success = "true"
                response.Data = json.encode(pokemonData)
                response.Message = "Stellar Tera activated successfully"
            else
                sendErrorResponse(msg.From, error, {
                    operation = operation,
                    pokemonId = pokemonData.id
                })
                return
            end
            
        elseif operation == "calculate_stab" then
            local stabMultiplier, error = calculateStellarSTAB(pokemonData, moveType, moveCategory)
            response.STABMultiplier = tostring(stabMultiplier)
            response.MoveType = moveType
            response.IsTerapagos = tostring(isTerapagos(pokemonData.speciesId))
            response.AlreadyBoosted = tostring(isTypeStellarBoosted(pokemonData, moveType))
            
        elseif operation == "track_usage" then
            local tracked = trackStellarUsage(pokemonData, moveType, moveCategory)
            response.Tracked = tostring(tracked)
            response.Data = json.encode(pokemonData)
            response.StellarTypesBoosted = json.encode(pokemonData.stellarTypesBoosted or {})
            
        elseif operation == "reset" then
            local success = resetStellarState(pokemonData, battleId)
            response.Success = tostring(success)
            response.Data = json.encode(pokemonData)
            
        elseif operation == "get_state" then
            local state = getStellarState(pokemonData)
            response.StellarState = json.encode(state)
            
        else
            response.Error = "Unknown operation: " .. operation
        end
        
        ao.send(response)
    end
)

-- Calculate Stellar STAB only
Handlers.add(
    "calculate-stellar-stab",
    Handlers.utils.hasMatchingTag("Action", "CalculateStellarSTAB"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local moveType = msg.MoveType or "NORMAL"
        local moveCategory = msg.MoveCategory or MOVE_CATEGORIES.PHYSICAL
        
        local stabMultiplier, error = calculateStellarSTAB(pokemonData, moveType, moveCategory)
        
        ao.send({
            Target = msg.From,
            Action = "StellarSTABCalculated",
            STABMultiplier = tostring(stabMultiplier),
            MoveType = moveType,
            MoveCategory = moveCategory,
            IsTerapagos = tostring(isTerapagos(pokemonData.speciesId)),
            IsFirstUsage = tostring(not isTypeStellarBoosted(pokemonData, moveType)),
            ProcessId = ao.id
        })
    end
)

-- Track Stellar usage after move execution
Handlers.add(
    "track-stellar-usage",
    Handlers.utils.hasMatchingTag("Action", "TrackStellarUsage"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local moveType = msg.MoveType or "NORMAL"
        local moveCategory = msg.MoveCategory or MOVE_CATEGORIES.PHYSICAL
        
        local tracked = trackStellarUsage(pokemonData, moveType, moveCategory)
        
        ao.send({
            Target = msg.From,
            Action = "StellarUsageTracked",
            Tracked = tostring(tracked),
            MoveType = moveType,
            Data = json.encode(pokemonData),
            StellarTypesBoosted = json.encode(pokemonData.stellarTypesBoosted or {}),
            RemainingBoosts = tostring(18 - #(pokemonData.stellarTypesBoosted or {})),
            ProcessId = ao.id
        })
    end
)

-- Handle complex multi-type scenarios
Handlers.add(
    "process-multi-type-stellar",
    Handlers.utils.hasMatchingTag("Action", "ProcessMultiTypeStellar"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local moveSequence = safeJsonDecode(msg.MoveSequence, {})
        
        local results = handleMultiTypeStellar(pokemonData, moveSequence)
        
        ao.send({
            Target = msg.From,
            Action = "MultiTypeStellarProcessed",
            Results = json.encode(results),
            UpdatedPokemonData = json.encode(pokemonData),
            ProcessId = ao.id
        })
    end
)

-- Validate Stellar battle state
Handlers.add(
    "validate-stellar-state",
    Handlers.utils.hasMatchingTag("Action", "ValidateStellarState"),
    function(msg)
        local battleState = safeJsonDecode(msg.Data, {})
        
        local valid, validationResults = validateStellarInteraction(battleState)
        
        ao.send({
            Target = msg.From,
            Action = "StellarStateValidated",
            Valid = tostring(valid),
            ValidationResults = json.encode(validationResults),
            ProcessId = ao.id
        })
    end
)

-- Reset battle Stellar tracking
Handlers.add(
    "reset-battle-stellar",
    Handlers.utils.hasMatchingTag("Action", "ResetBattleStellar"),
    function(msg)
        local battleId = msg.BattleId
        local pokemonList = safeJsonDecode(msg.PokemonList, {})
        
        -- Reset each Pokemon's Stellar state
        for _, pokemonData in ipairs(pokemonList) do
            resetStellarState(pokemonData, battleId)
        end
        
        -- Clear battle tracking
        if battleId and BattleStellarTracking[battleId] then
            BattleStellarTracking[battleId] = nil
        end
        
        ao.send({
            Target = msg.From,
            Action = "BattleStellarReset",
            BattleId = battleId or "unknown",
            PokemonCount = tostring(#pokemonList),
            ProcessId = ao.id
        })
    end
)

-- Get Stellar effectiveness (always 1.0x)
Handlers.add(
    "get-stellar-effectiveness",
    Handlers.utils.hasMatchingTag("Action", "GetStellarEffectiveness"),
    function(msg)
        local attackerData = safeJsonDecode(msg.AttackerData, {})
        local defenderData = safeJsonDecode(msg.DefenderData, {})
        local moveType = msg.MoveType or "NORMAL"
        
        local effectiveness = calculateStellarEffectiveness(attackerData, defenderData, moveType)
        
        ao.send({
            Target = msg.From,
            Action = "StellarEffectivenessRetrieved",
            Effectiveness = tostring(effectiveness or 1.0),
            IsStellarMove = tostring(moveType == "STELLAR"),
            Message = "Stellar moves always have 1.0x effectiveness",
            ProcessId = ao.id
        })
    end
)

-- Health check handler
Handlers.add(
    "health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        local battleCount = 0
        for _ in pairs(BattleStellarTracking) do
            battleCount = battleCount + 1
        end
        
        ao.send({
            Target = msg.From,
            Action = "HealthCheckResponse",
            Status = "healthy",
            Version = StellarState.version,
            ActiveBattles = tostring(battleCount),
            ProcessId = ao.id
        })
    end
)

-- ===============================
-- ADP v1.0 COMPLIANCE
-- ===============================

-- Enhanced Info handler for ADP v1.0 compliance
Handlers.add(
    "info", 
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Stellar Tera Engine",
            Description = "Comprehensive Stellar Tera mechanics engine for Pokemon Generation 9 battles. Implements Stellar-specific STAB calculations with one-time per-type bonuses, Terapagos unlimited usage exceptions, usage tracking arrays, and complex multi-type Pokemon scenarios.",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            adpVersion = "1.0",
            version = StellarState.version,
            handlers = {
                {
                    action = "ProcessStellarTera",
                    pattern = {"Action"},
                    description = "Main Stellar Tera operation handler supporting multiple operations",
                    category = "core",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "Operation", type = "string", required = true, description = "Operation type: activate|calculate_stab|track_usage|reset|get_state"},
                        {name = "MoveType", type = "string", required = false, description = "Move type for STAB calculations"},
                        {name = "MoveCategory", type = "string", required = false, description = "Move category: PHYSICAL|SPECIAL|STATUS"},
                        {name = "BattleId", type = "string", required = false, description = "Battle session identifier"}
                    }
                },
                {
                    action = "CalculateStellarSTAB",
                    pattern = {"Action"},
                    description = "Calculate Stellar STAB multiplier with first-time usage bonuses",
                    category = "calculation",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "MoveType", type = "string", required = true, description = "Move type for STAB calculation"},
                        {name = "MoveCategory", type = "string", required = false, description = "Move category (defaults to PHYSICAL)"}
                    }
                },
                {
                    action = "TrackStellarUsage",
                    pattern = {"Action"},
                    description = "Track Stellar type usage after successful move execution",
                    category = "tracking",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "MoveType", type = "string", required = true, description = "Move type that was used"},
                        {name = "MoveCategory", type = "string", required = false, description = "Move category (STATUS moves not tracked)"}
                    }
                },
                {
                    action = "ProcessMultiTypeStellar",
                    pattern = {"Action"},
                    description = "Handle complex multi-type Pokemon Stellar scenarios",
                    category = "complex",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "MoveSequence", type = "json", required = true, description = "Array of moves with type and category"}
                    }
                },
                {
                    action = "ValidateStellarState",
                    pattern = {"Action"},
                    description = "Validate Stellar state consistency across battle",
                    category = "validation",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Complete battle state object"}
                    }
                },
                {
                    action = "ResetBattleStellar",
                    pattern = {"Action"},
                    description = "Reset all Stellar tracking at battle end",
                    category = "state",
                    parameters = {
                        {name = "BattleId", type = "string", required = false, description = "Battle session identifier"},
                        {name = "PokemonList", type = "json", required = true, description = "Array of Pokemon to reset"}
                    }
                },
                {
                    action = "GetStellarEffectiveness",
                    pattern = {"Action"},
                    description = "Get Stellar type effectiveness (always 1.0x)",
                    category = "calculation",
                    parameters = {
                        {name = "AttackerData", type = "json", required = true, description = "Attacking Pokemon data"},
                        {name = "DefenderData", type = "json", required = true, description = "Defending Pokemon data"},
                        {name = "MoveType", type = "string", required = true, description = "Move type"}
                    }
                },
                {
                    action = "HealthCheck",
                    pattern = {"Action"},
                    description = "Process health and status check",
                    category = "utility"
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
                supportsHandlerRegistry = true,
                supportsStellarSTAB = true,
                supportsTerapagosException = true,
                supportsUsageTracking = true,
                supportsMultiTypeScenarios = true,
                supportsStateValidation = true,
                supportsErrorHandling = true,
                adpCompliant = true
            },
            constants = {
                stellarMatchingBonus = STELLAR_CONFIG.matchingTypeBonus,
                stellarNonMatchingBonus = STELLAR_CONFIG.nonMatchingTypeBonus,
                stellarEffectiveness = STELLAR_CONFIG.stellarEffectiveness,
                terapagosSpecies = STELLAR_CONFIG.terapagosSpecies,
                maxTypesTrackable = 18
            },
            documentation = {
                stellarMechanics = "Stellar Tera provides one-time STAB bonus per type per battle",
                terapagosException = "Terapagos species get unlimited Stellar STAB without tracking",
                stabCalculation = "1.5x for matching natural types, 1.2x for non-matching types",
                typeEffectiveness = "Stellar moves always deal 1.0x damage to all types",
                defensiveBehavior = "Stellar Pokemon retain natural types for defense"
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
        
        print("Sent ADP v1.0 compliant Stellar Tera Info response to " .. msg.From)
    end
)

-- Basic Ping handler for ADP testing
Handlers.add(
    "ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong",
            ProcessType = "StellarTeraEngine",
            ProcessId = ao.id
        })
    end
)

-- ===============================
-- INITIALIZATION COMPLETE
-- ===============================

print("Stellar Tera Engine Process initialized successfully")
print("ADP v1.0 compliant with Stellar-specific mechanics")
print("Process ID: " .. (ao.id or "unknown"))