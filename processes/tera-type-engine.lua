-- Tera Type Engine Process for Pokemon Battle System
-- Implements comprehensive Tera type mechanics for Generation 9 Pokemon battles
-- ADP v1.0 compliant for self-documentation and agent compatibility

-- Note: json is available as a global in AO environment

-- ===============================
-- EMBEDDED TERA TYPE DATABASE
-- ===============================

-- Valid Pokemon types including Stellar
local POKEMON_TYPES = {
    "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
    "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG", 
    "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY", "STELLAR"
}

-- Type effectiveness matrix (attacking type -> defending type -> multiplier)
local TYPE_CHART = {
    NORMAL = {ROCK = 0.5, GHOST = 0, STEEL = 0.5, FIGHTING = 2.0},
    FIRE = {FIRE = 0.5, WATER = 2.0, GRASS = 0.5, ICE = 0.5, BUG = 0.5, ROCK = 2.0, DRAGON = 0.5, STEEL = 0.5, GROUND = 2.0},
    WATER = {FIRE = 0.5, WATER = 0.5, GRASS = 2.0, ICE = 0.5, GROUND = 0.5, ROCK = 0.5, DRAGON = 0.5, STEEL = 0.5, ELECTRIC = 2.0},
    ELECTRIC = {WATER = 0.5, ELECTRIC = 0.5, GRASS = 0.5, GROUND = 0, FLYING = 0.5, DRAGON = 0.5, STEEL = 0.5},
    GRASS = {FIRE = 2.0, WATER = 0.5, ELECTRIC = 0.5, GRASS = 0.5, POISON = 2.0, GROUND = 0.5, FLYING = 2.0, BUG = 2.0, ROCK = 0.5, DRAGON = 0.5, STEEL = 2.0, ICE = 2.0},
    ICE = {FIRE = 2.0, WATER = 0.5, GRASS = 0.5, ICE = 0.5, FIGHTING = 2.0, ROCK = 2.0, STEEL = 2.0},
    FIGHTING = {NORMAL = 0.5, ICE = 0.5, POISON = 0.5, FLYING = 2.0, PSYCHIC = 2.0, BUG = 0.5, ROCK = 0.5, GHOST = 0, DARK = 0.5, STEEL = 0.5, FAIRY = 2.0},
    POISON = {GRASS = 0.5, FIGHTING = 0.5, POISON = 0.5, GROUND = 2.0, PSYCHIC = 2.0, BUG = 0.5, ROCK = 2.0, GHOST = 2.0, STEEL = 0, FAIRY = 0.5},
    GROUND = {FIRE = 0.5, WATER = 2.0, ELECTRIC = 0.5, GRASS = 2.0, ICE = 2.0, POISON = 0.5, FLYING = 0, BUG = 0.5, ROCK = 0.5, STEEL = 0.5},
    FLYING = {ELECTRIC = 2.0, GRASS = 0.5, ICE = 2.0, FIGHTING = 0.5, GROUND = 0, BUG = 0.5, ROCK = 2.0, STEEL = 2.0},
    PSYCHIC = {FIGHTING = 0.5, POISON = 0.5, PSYCHIC = 0.5, DARK = 2.0, STEEL = 2.0},
    BUG = {FIRE = 2.0, GRASS = 0.5, FIGHTING = 0.5, POISON = 0.5, FLYING = 2.0, PSYCHIC = 0.5, ROCK = 2.0, GHOST = 2.0, DARK = 0.5, STEEL = 2.0, FAIRY = 2.0},
    ROCK = {FIRE = 0.5, WATER = 2.0, GRASS = 2.0, ICE = 0.5, FIGHTING = 2.0, POISON = 0.5, GROUND = 2.0, FLYING = 0.5, BUG = 0.5, STEEL = 2.0},
    GHOST = {NORMAL = 0, PSYCHIC = 0.5, BUG = 0.5, GHOST = 0.5, DARK = 2.0, STEEL = 2.0},
    DRAGON = {FIRE = 0.5, WATER = 0.5, ELECTRIC = 0.5, GRASS = 0.5, ICE = 2.0, DRAGON = 0.5, STEEL = 2.0, FAIRY = 2.0},
    DARK = {FIGHTING = 2.0, PSYCHIC = 0.5, BUG = 2.0, GHOST = 0.5, DARK = 0.5, STEEL = 2.0, FAIRY = 2.0},
    STEEL = {FIRE = 2.0, WATER = 2.0, ELECTRIC = 2.0, ICE = 0.5, POISON = 0, GROUND = 2.0, FLYING = 0.5, PSYCHIC = 0.5, BUG = 0.5, ROCK = 0.5, GHOST = 2.0, DRAGON = 0.5, STEEL = 0.5, FAIRY = 0.5},
    FAIRY = {FIRE = 2.0, FIGHTING = 0.5, POISON = 2.0, DRAGON = 0.5, DARK = 0.5, STEEL = 2.0},
    STELLAR = {} -- Stellar type has neutral effectiveness against all types
}

-- Special species that always return STELLAR type
local STELLAR_SPECIES = {
    ["TERAPAGOS"] = true,
    ["TERAPAGOS_TERASTAL"] = true, 
    ["TERAPAGOS_STELLAR"] = true
}

-- STAB calculation constants
local STAB_CONSTANTS = {
    NATURAL_BONUS = 0.5, -- 1.5x multiplier for natural type matches
    TERA_BONUS = 0.5, -- 1.5x multiplier for Tera type matches
    STELLAR_MATCHING_BONUS = 0.5, -- 1.5x for matching types with Stellar
    STELLAR_NON_MATCHING_BONUS = 0.2, -- 1.2x for non-matching types with Stellar
    MAX_STAB_MULTIPLIER = 2.25 -- Hard cap on total STAB multiplier
}

-- ===============================
-- PROCESS STATE INITIALIZATION
-- ===============================

if not TeraState then
    TeraState = {
        initialized = true,
        version = "1.0.0"
    }
end

-- Battle-specific Tera usage tracking (resets between battles)
if not BattleTeraUsage then
    BattleTeraUsage = {}
end

-- ===============================
-- UTILITY FUNCTIONS
-- ===============================

-- Validate if a type is a valid Pokemon type
local function isValidTeraType(teraType)
    if not teraType then return false end
    for _, validType in ipairs(POKEMON_TYPES) do
        if validType == teraType then return true end
    end
    return false
end

-- Get type effectiveness multiplier
local function getTypeEffectiveness(attackingType, defendingType)
    if not attackingType or not defendingType then return 1.0 end
    
    local attackChart = TYPE_CHART[attackingType]
    if not attackChart then return 1.0 end
    
    return attackChart[defendingType] or 1.0
end

-- Validate Pokemon data structure
local function validatePokemonData(pokemonData)
    if not pokemonData then return false, "Missing Pokemon data" end
    if not pokemonData.speciesId then return false, "Missing species ID" end
    if not pokemonData.types or #pokemonData.types == 0 then return false, "Missing Pokemon types" end
    return true, "Valid"
end

-- Generate deterministic random selection from Pokemon's natural types
local function selectRandomTeraType(naturalTypes, seed)
    if not naturalTypes or #naturalTypes == 0 then return "NORMAL" end
    
    -- Use seed for deterministic randomness (replace with AO crypto module in production)
    local index = (seed or 1) % #naturalTypes + 1
    return naturalTypes[index]
end

-- ===============================
-- ERROR HANDLING SYSTEM
-- ===============================

local ERROR_CODES = {
    -- Assignment errors (TERA_001-099)
    INVALID_SPECIES_ID = {code = "TERA_001", message = "Invalid species ID provided", recovery = "Use default NORMAL type"},
    INVALID_TERA_TYPE = {code = "TERA_002", message = "Invalid Tera type specified", recovery = "Fall back to random from natural types"},
    MISSING_NATURAL_TYPES = {code = "TERA_003", message = "Pokemon natural types not found", recovery = "Assign NORMAL type"},
    ASSIGNMENT_ALREADY_SET = {code = "TERA_004", message = "Tera type already assigned", recovery = "Return existing assignment"},
    
    -- Activation errors (TERA_101-199)
    ALREADY_TERASTALLIZED = {code = "TERA_101", message = "Pokemon is already terastallized", recovery = "Return current state"},
    USAGE_LIMIT_EXCEEDED = {code = "TERA_102", message = "Trainer already used terastalization", recovery = "Reject activation"},
    INVALID_BATTLE_PHASE = {code = "TERA_103", message = "Invalid battle phase for terastalization", recovery = "Queue for valid phase"},
    POKEMON_FAINTED = {code = "TERA_104", message = "Cannot terastalize fainted Pokemon", recovery = "Reject activation"},
    INVALID_BATTLE_STATE = {code = "TERA_105", message = "Invalid battle state", recovery = "Defer activation"},
    
    -- STAB calculation errors (TERA_201-299)
    MISSING_POKEMON_DATA = {code = "TERA_201", message = "Missing Pokemon data for STAB", recovery = "Use 1.0x multiplier"},
    INVALID_MOVE_TYPE = {code = "TERA_202", message = "Invalid move type", recovery = "Treat as NORMAL type"},
    STELLAR_TRACKING_CORRUPTION = {code = "TERA_203", message = "Stellar usage tracking corrupted", recovery = "Reset tracking array"},
    STAB_OVERFLOW = {code = "TERA_204", message = "STAB multiplier exceeds maximum", recovery = "Cap at 2.25x"},
    
    -- Type effectiveness errors (TERA_301-399)
    UNKNOWN_TYPE_MATCHUP = {code = "TERA_301", message = "Type effectiveness not found", recovery = "Use 1.0x neutral"},
    TERA_TYPE_MISMATCH = {code = "TERA_302", message = "Tera type mismatch", recovery = "Use natural types"},
    TYPE_CHART_CORRUPTION = {code = "TERA_303", message = "Type chart data corrupted", recovery = "Reload embedded chart"},
    
    -- JSON parsing errors (TERA_350-399)
    INVALID_JSON = {code = "TERA_350", message = "Invalid JSON in message data", recovery = "Use empty data structure"},
    
    -- Visual state errors (TERA_401-499)
    PIPELINE_UPDATE_FAILED = {code = "TERA_401", message = "Sprite pipeline update failed", recovery = "Continue without effects"},
    COLOR_MAPPING_MISSING = {code = "TERA_402", message = "Tera color mapping missing", recovery = "Use default white glow"},
    VISUAL_SYNC_FAILURE = {code = "TERA_403", message = "Visual state sync failed", recovery = "Force refresh"}
}

local function sendErrorResponse(target, errorInfo, context)
    local response = {
        Target = target,
        Action = "TeraError",
        ErrorCode = errorInfo.code,
        ErrorMessage = errorInfo.message,
        RecoveryAction = errorInfo.recovery,
        Context = context or {},
        Timestamp = msg.Timestamp or "0",
        ProcessId = ao.id
    }
    
    ao.send(response)
end

-- Direct JSON parsing for AO messages (controlled input)
local function safeJsonDecode(jsonStr, defaultValue)
    if not jsonStr or jsonStr == "" then
        return defaultValue or {}
    end

    -- Direct decode - msg.Data is controlled input from AO
    return json.decode(jsonStr) or defaultValue or {}
end

-- ===============================
-- CORE TERA TYPE FUNCTIONS
-- ===============================

-- Assign Tera type to Pokemon
local function assignTeraType(pokemonData, preferredType, seed)
    local isValid, errorMsg = validatePokemonData(pokemonData)
    if not isValid then
        return false, ERROR_CODES.INVALID_SPECIES_ID, nil
    end
    
    -- Check if already assigned
    if pokemonData.teraType then
        return false, ERROR_CODES.ASSIGNMENT_ALREADY_SET, pokemonData.teraType
    end
    
    local assignedType
    
    -- Special case: Terapagos always gets STELLAR
    if STELLAR_SPECIES[pokemonData.speciesId] then
        assignedType = "STELLAR"
    elseif preferredType and isValidTeraType(preferredType) then
        assignedType = preferredType
    else
        -- Default: random from natural types
        assignedType = selectRandomTeraType(pokemonData.types, seed)
    end
    
    if not isValidTeraType(assignedType) then
        return false, ERROR_CODES.INVALID_TERA_TYPE, "NORMAL"
    end
    
    pokemonData.teraType = assignedType
    pokemonData.isTerastallized = false
    pokemonData.stellarTypesBoosted = {}
    
    return true, nil, assignedType
end

-- Get Pokemon's current Tera type
local function getTeraType(pokemonData)
    if not pokemonData then return "NORMAL" end
    
    -- Special case: Terapagos always returns STELLAR
    if STELLAR_SPECIES[pokemonData.speciesId] then
        return "STELLAR"
    end
    
    return pokemonData.teraType or "NORMAL"
end

-- Activate terastalization
local function activateTerastalization(pokemonData, battleContext, trainerId)
    if not pokemonData then
        return false, ERROR_CODES.MISSING_POKEMON_DATA
    end
    
    if pokemonData.hp and pokemonData.hp <= 0 then
        return false, ERROR_CODES.POKEMON_FAINTED
    end
    
    if pokemonData.isTerastallized then
        return false, ERROR_CODES.ALREADY_TERASTALLIZED
    end
    
    -- Check usage limits
    local battleId = battleContext.battleId or "default"
    local usage = BattleTeraUsage[battleId] or {}
    local trainerUsage = usage[trainerId] or 0
    
    if trainerUsage >= 1 then
        return false, ERROR_CODES.USAGE_LIMIT_EXCEEDED
    end
    
    -- Activate terastalization
    pokemonData.isTerastallized = true
    pokemonData.teraActivationTurn = battleContext.turn or 1
    
    -- Update usage tracking
    if not BattleTeraUsage[battleId] then
        BattleTeraUsage[battleId] = {}
    end
    BattleTeraUsage[battleId][trainerId] = 1
    
    return true, nil
end

-- Calculate STAB multiplier with Tera types
local function calculateTeraSTAB(pokemonData, moveType)
    if not pokemonData or not moveType then
        return 1.0
    end
    
    local naturalTypes = pokemonData.types or {}
    local teraType = getTeraType(pokemonData)
    local stabMultiplier = 1.0
    
    -- Natural type STAB (excluding STELLAR moves)
    if moveType ~= "STELLAR" then
        for _, naturalType in ipairs(naturalTypes) do
            if naturalType == moveType then
                stabMultiplier = stabMultiplier + STAB_CONSTANTS.NATURAL_BONUS
                break
            end
        end
    end
    
    -- Tera type STAB when terastallized
    if pokemonData.isTerastallized then
        if teraType == "STELLAR" then
            -- Stellar type special mechanics
            local stellarBoosted = pokemonData.stellarTypesBoosted or {}
            local alreadyBoosted = false
            
            for _, boostedType in ipairs(stellarBoosted) do
                if boostedType == moveType then
                    alreadyBoosted = true
                    break
                end
            end
            
            -- Terapagos exception: always gets Stellar STAB
            if not alreadyBoosted or STELLAR_SPECIES[pokemonData.speciesId] then
                local isMatchingType = false
                for _, naturalType in ipairs(naturalTypes) do
                    if naturalType == moveType then
                        isMatchingType = true
                        break
                    end
                end
                
                if isMatchingType then
                    stabMultiplier = stabMultiplier + STAB_CONSTANTS.STELLAR_MATCHING_BONUS
                else
                    stabMultiplier = stabMultiplier + STAB_CONSTANTS.STELLAR_NON_MATCHING_BONUS
                end
            end
        elseif teraType == moveType and moveType ~= "STELLAR" then
            -- Standard Tera type STAB
            stabMultiplier = stabMultiplier + STAB_CONSTANTS.TERA_BONUS
        end
    end
    
    -- Apply maximum STAB cap
    return math.min(stabMultiplier, STAB_CONSTANTS.MAX_STAB_MULTIPLIER)
end

-- Track Stellar type usage
local function trackStellarUsage(pokemonData, moveType)
    if not pokemonData or not moveType or moveType == "STATUS" then return end
    if not pokemonData.isTerastallized or getTeraType(pokemonData) ~= "STELLAR" then return end
    
    local stellarBoosted = pokemonData.stellarTypesBoosted or {}
    
    -- Check if already tracked
    for _, boostedType in ipairs(stellarBoosted) do
        if boostedType == moveType then return end
    end
    
    -- Add to tracking
    table.insert(stellarBoosted, moveType)
    pokemonData.stellarTypesBoosted = stellarBoosted
end

-- Reset Tera state (called at battle end)
local function resetTeraState(pokemonData)
    if not pokemonData then return end
    
    local wasTerastallized = pokemonData.isTerastallized
    pokemonData.isTerastallized = false
    pokemonData.stellarTypesBoosted = {}
    
    return wasTerastallized
end

-- Calculate type effectiveness with Tera considerations
local function calculateTeraTypeEffectiveness(attackerData, defenderData, moveType)
    if not attackerData or not defenderData or not moveType then return 1.0 end
    
    local attackingType = moveType
    
    -- Offensive: Use Tera type when terastallized
    if attackerData.isTerastallized then
        local teraType = getTeraType(attackerData)
        if teraType ~= "STELLAR" then
            attackingType = teraType
        end
    end
    
    -- Defensive: Use natural types (Stellar exception uses both)
    local defenderTypes = defenderData.types or {"NORMAL"}
    
    if defenderData.isTerastallized then
        local defenderTeraType = getTeraType(defenderData)
        if defenderTeraType ~= "STELLAR" then
            -- For non-Stellar Tera, replace natural types
            defenderTypes = {defenderTeraType}
        end
        -- For Stellar Tera, keep natural types (defensive behavior)
    end
    
    -- Calculate total effectiveness
    local totalEffectiveness = 1.0
    for _, defenderType in ipairs(defenderTypes) do
        local effectiveness = getTypeEffectiveness(attackingType, defenderType)
        totalEffectiveness = totalEffectiveness * effectiveness
    end
    
    return totalEffectiveness
end

-- ===============================
-- AO MESSAGE HANDLERS
-- ===============================

-- Assign Tera type to Pokemon
Handlers.add(
    "assign-tera-type",
    Handlers.utils.hasMatchingTag("Action", "AssignTeraType"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local preferredType = msg.TeraType
        local seed = tonumber(msg.Seed) or tonumber(msg.Timestamp) or 1
        
        local success, error, assignedType = assignTeraType(pokemonData, preferredType, seed)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "TeraTypeAssigned",
                Data = json.encode(pokemonData),
                TeraType = assignedType,
                Success = "true",
                ProcessId = ao.id
            })
        else
            sendErrorResponse(msg.From, error, {
                operation = "AssignTeraType",
                pokemonId = pokemonData.id,
                preferredType = preferredType
            })
        end
    end
)

-- Activate terastalization
Handlers.add(
    "activate-terastalization",
    Handlers.utils.hasMatchingTag("Action", "ActivateTerastalization"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local battleContext = {
            battleId = msg.BattleId or "default",
            turn = tonumber(msg.Turn) or 1,
            phase = msg.Phase or "COMMAND_PHASE"
        }
        local trainerId = msg.TrainerId or msg.From
        
        local success, error = activateTerastalization(pokemonData, battleContext, trainerId)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "TerastalizationActivated",
                Data = json.encode(pokemonData),
                Success = "true",
                TeraType = getTeraType(pokemonData),
                ProcessId = ao.id
            })
        else
            sendErrorResponse(msg.From, error, {
                operation = "ActivateTerastalization",
                pokemonId = pokemonData.id,
                battleId = battleContext.battleId,
                trainerId = trainerId
            })
        end
    end
)

-- Calculate Tera STAB multiplier
Handlers.add(
    "calculate-tera-stab",
    Handlers.utils.hasMatchingTag("Action", "CalculateTeraSTAB"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local moveType = msg.MoveType or "NORMAL"
        
        local stabMultiplier = calculateTeraSTAB(pokemonData, moveType)
        
        ao.send({
            Target = msg.From,
            Action = "TeraSTABCalculated",
            STABMultiplier = tostring(stabMultiplier),
            MoveType = moveType,
            IsTerastallized = tostring(pokemonData.isTerastallized or false),
            TeraType = getTeraType(pokemonData),
            ProcessId = ao.id
        })
    end
)

-- Calculate type effectiveness with Tera
Handlers.add(
    "calculate-tera-effectiveness",
    Handlers.utils.hasMatchingTag("Action", "CalculateTeraEffectiveness"),
    function(msg)
        local attackerData = safeJsonDecode(msg.AttackerData, {})
        local defenderData = safeJsonDecode(msg.DefenderData, {})
        local moveType = msg.MoveType or "NORMAL"
        
        local effectiveness = calculateTeraTypeEffectiveness(attackerData, defenderData, moveType)
        
        ao.send({
            Target = msg.From,
            Action = "TeraEffectivenessCalculated",
            Effectiveness = tostring(effectiveness),
            MoveType = moveType,
            AttackerTeraType = getTeraType(attackerData),
            DefenderTeraType = getTeraType(defenderData),
            ProcessId = ao.id
        })
    end
)

-- Track Stellar type usage
Handlers.add(
    "track-stellar-usage",
    Handlers.utils.hasMatchingTag("Action", "TrackStellarUsage"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local moveType = msg.MoveType or "NORMAL"
        
        trackStellarUsage(pokemonData, moveType)
        
        ao.send({
            Target = msg.From,
            Action = "StellarUsageTracked",
            Data = json.encode(pokemonData),
            MoveType = moveType,
            StellarTypesBoosted = json.encode(pokemonData.stellarTypesBoosted or {}),
            ProcessId = ao.id
        })
    end
)

-- Get Pokemon's Tera type
Handlers.add(
    "get-tera-type",
    Handlers.utils.hasMatchingTag("Action", "GetTeraType"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local teraType = getTeraType(pokemonData)
        
        ao.send({
            Target = msg.From,
            Action = "TeraTypeRetrieved",
            TeraType = teraType,
            IsTerastallized = tostring(pokemonData.isTerastallized or false),
            SpeciesId = pokemonData.speciesId or "UNKNOWN",
            ProcessId = ao.id
        })
    end
)

-- Reset Tera state (battle end)
Handlers.add(
    "reset-tera-state",
    Handlers.utils.hasMatchingTag("Action", "ResetTeraState"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local battleId = msg.BattleId
        
        local wasTerastallized = resetTeraState(pokemonData)
        
        -- Clear battle usage tracking
        if battleId and BattleTeraUsage[battleId] then
            BattleTeraUsage[battleId] = nil
        end
        
        ao.send({
            Target = msg.From,
            Action = "TeraStateReset",
            Data = json.encode(pokemonData),
            WasTerastallized = tostring(wasTerastallized),
            BattleId = battleId or "unknown",
            ProcessId = ao.id
        })
    end
)

-- Health check handler
Handlers.add(
    "health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthCheckResponse",
            Status = "healthy",
            Version = TeraState.version,
            BattleCount = table.getn(BattleTeraUsage),
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
            Name = "Tera Type Engine",
            Description = "Comprehensive Tera type mechanics engine for Pokemon Generation 9 battles. Implements Tera type assignment, terastalization activation, STAB calculations with Stellar type mechanics, type effectiveness, and comprehensive error handling.",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
                {
                    action = "AssignTeraType",
                    pattern = {"Action"},
                    description = "Assign Tera type to Pokemon with validation and special cases",
                    category = "core",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "TeraType", type = "string", required = false, description = "Preferred Tera type"},
                        {name = "Seed", type = "number", required = false, description = "Random seed for deterministic assignment"}
                    }
                },
                {
                    action = "ActivateTerastalization", 
                    pattern = {"Action"},
                    description = "Activate terastalization with usage restrictions and validation",
                    category = "core",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "BattleId", type = "string", required = true, description = "Battle session identifier"},
                        {name = "TrainerId", type = "string", required = true, description = "Trainer identifier"},
                        {name = "Turn", type = "number", required = false, description = "Current battle turn"}
                    }
                },
                {
                    action = "CalculateTeraSTAB",
                    pattern = {"Action"},
                    description = "Calculate STAB multiplier with Tera type and Stellar mechanics",
                    category = "calculation", 
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "MoveType", type = "string", required = true, description = "Move type for STAB calculation"}
                    }
                },
                {
                    action = "CalculateTeraEffectiveness",
                    pattern = {"Action"},
                    description = "Calculate type effectiveness with Tera type considerations",
                    category = "calculation",
                    parameters = {
                        {name = "AttackerData", type = "json", required = true, description = "Attacking Pokemon data"},
                        {name = "DefenderData", type = "json", required = true, description = "Defending Pokemon data"},
                        {name = "MoveType", type = "string", required = true, description = "Move type for effectiveness calculation"}
                    }
                },
                {
                    action = "TrackStellarUsage",
                    pattern = {"Action"},
                    description = "Track Stellar type STAB usage per type per battle",
                    category = "tracking",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "MoveType", type = "string", required = true, description = "Move type used"}
                    }
                },
                {
                    action = "GetTeraType",
                    pattern = {"Action"},
                    description = "Retrieve Pokemon's current Tera type with special case handling",
                    category = "query",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"}
                    }
                },
                {
                    action = "ResetTeraState",
                    pattern = {"Action"},
                    description = "Reset Tera state at battle end and clear usage tracking",
                    category = "state",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "BattleId", type = "string", required = false, description = "Battle session identifier"}
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
                supportsTagValidation = true,
                supportsTeraTypes = true,
                supportsStellarMechanics = true,
                supportsErrorHandling = true,
                supportsUsageTracking = true
            },
            constants = {
                validTypes = POKEMON_TYPES,
                maxStabMultiplier = STAB_CONSTANTS.MAX_STAB_MULTIPLIER,
                stellarSpecies = STELLAR_SPECIES
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
        
        print("Sent ADP v1.0 compliant Info response to " .. msg.From)
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
            ProcessType = "TeraTypeEngine",
            ProcessId = ao.id
        })
    end
)

-- ===============================
-- INITIALIZATION COMPLETE
-- ===============================

print("Tera Type Engine Process initialized successfully")
print("ADP v1.0 compliant with " .. #POKEMON_TYPES .. " supported types")
print("Process ID: " .. (ao.id or "unknown"))