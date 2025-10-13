-- GameState Validation Framework
-- Comprehensive validation system for maintaining GameState integrity at process boundaries
-- ADP v1.0 Compliant Process

-- Core validation utilities
local function validateNumericRange(value, min, max, fieldName)
    if type(value) ~= "number" then
        return false, fieldName .. " must be a number"
    end
    if value < min or value > max then
        return false, fieldName .. " must be between " .. min .. " and " .. max
    end
    return true, nil
end

local function validateEnum(value, validValues, fieldName)
    if type(validValues) ~= "table" then
        return false, fieldName .. " validation error: invalid enum definition"
    end
    for _, validValue in ipairs(validValues) do
        if value == validValue then
            return true, nil
        end
    end
    return false, fieldName .. " must be one of: " .. table.concat(validValues, ", ")
end

local function validateArray(arr, maxLength, fieldName)
    if type(arr) ~= "table" then
        return false, fieldName .. " must be an array"
    end
    if #arr > maxLength then
        return false, fieldName .. " exceeds maximum length of " .. maxLength
    end
    return true, nil
end

-- Pokemon stat validation
local function validatePokemonStats(pokemon)
    if type(pokemon) ~= "table" then
        return false, "Pokemon must be a table"
    end
    
    -- Validate basic fields
    local valid, err = validateNumericRange(pokemon.level or 1, 1, 100, "Pokemon level")
    if not valid then return false, err end
    
    -- Validate IVs (Individual Values)
    if pokemon.ivs then
        local ivStats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
        for _, stat in ipairs(ivStats) do
            if pokemon.ivs[stat] then
                valid, err = validateNumericRange(pokemon.ivs[stat], 0, 31, "IV " .. stat)
                if not valid then return false, err end
            end
        end
    end
    
    -- Validate current HP
    if pokemon.hp then
        valid, err = validateNumericRange(pokemon.hp, 0, pokemon.maxHp or 999, "Pokemon HP")
        if not valid then return false, err end
    end
    
    -- Validate status conditions
    if pokemon.status then
        local validStatuses = {"NONE", "SLEEP", "POISON", "BURN", "FREEZE", "PARALYSIS", "BADLY_POISONED"}
        valid, err = validateEnum(pokemon.status, validStatuses, "Pokemon status")
        if not valid then return false, err end
    end
    
    -- Validate moveset
    if pokemon.moves then
        valid, err = validateArray(pokemon.moves, 4, "Pokemon moves")
        if not valid then return false, err end
        
        for i, move in ipairs(pokemon.moves) do
            if move.pp then
                valid, err = validateNumericRange(move.pp, 0, move.maxPp or 64, "Move " .. i .. " PP")
                if not valid then return false, err end
            end
        end
    end
    
    return true, nil
end

-- Battle state validation
local function validateBattleState(battleState)
    if type(battleState) ~= "table" then
        return false, "Battle state must be a table"
    end
    
    -- Validate turn count
    if battleState.turn then
        local valid, err = validateNumericRange(battleState.turn, 1, 1000, "Battle turn")
        if not valid then return false, err end
    end
    
    -- Validate battle phase
    if battleState.phase then
        local validPhases = {"INIT", "COMMAND_SELECT", "TURN_RESOLVE", "BATTLE_END"}
        local valid, err = validateEnum(battleState.phase, validPhases, "Battle phase")
        if not valid then return false, err end
    end
    
    -- Validate active Pokemon
    if battleState.playerPokemon then
        local valid, err = validatePokemonStats(battleState.playerPokemon)
        if not valid then return false, "Player Pokemon: " .. err end
    end
    
    if battleState.enemyPokemon then
        local valid, err = validatePokemonStats(battleState.enemyPokemon)
        if not valid then return false, "Enemy Pokemon: " .. err end
    end
    
    -- Validate weather conditions
    if battleState.weather then
        local validWeather = {"NONE", "RAIN", "SUN", "SANDSTORM", "HAIL", "FOG", "HEAVY_RAIN", "HARSH_SUN", "STRONG_WINDS"}
        local valid, err = validateEnum(battleState.weather.type, validWeather, "Weather type")
        if not valid then return false, err end
        
        if battleState.weather.turnsLeft then
            valid, err = validateNumericRange(battleState.weather.turnsLeft, 0, 8, "Weather turns left")
            if not valid then return false, err end
        end
    end
    
    return true, nil
end

-- Inventory validation
local function validateInventory(inventory)
    if type(inventory) ~= "table" then
        return false, "Inventory must be a table"
    end
    
    -- Validate money
    if inventory.money then
        local valid, err = validateNumericRange(inventory.money, 0, 999999999, "Money")
        if not valid then return false, err end
    end
    
    -- Validate items
    if inventory.items then
        for itemId, quantity in pairs(inventory.items) do
            if type(quantity) ~= "number" or quantity < 0 or quantity > 999 then
                return false, "Item " .. tostring(itemId) .. " has invalid quantity"
            end
        end
    end
    
    -- Validate key items
    if inventory.keyItems then
        local valid, err = validateArray(inventory.keyItems, 50, "Key items")
        if not valid then return false, err end
    end
    
    return true, nil
end

-- Progression validation
local function validateProgression(progression)
    if type(progression) ~= "table" then
        return false, "Progression must be a table"
    end
    
    -- Validate experience
    if progression.exp then
        local valid, err = validateNumericRange(progression.exp, 0, 1000000, "Experience")
        if not valid then return false, err end
    end
    
    -- Validate badges
    if progression.badges then
        local valid, err = validateArray(progression.badges, 8, "Badges")
        if not valid then return false, err end
    end
    
    -- Validate unlocked areas
    if progression.unlockedAreas then
        local valid, err = validateArray(progression.unlockedAreas, 100, "Unlocked areas")
        if not valid then return false, err end
    end
    
    return true, nil
end

-- Party validation
local function validateParty(party)
    if type(party) ~= "table" then
        return false, "Party must be a table"
    end
    
    local valid, err = validateArray(party, 6, "Party")
    if not valid then return false, err end
    
    for i, pokemon in ipairs(party) do
        if pokemon then
            valid, err = validatePokemonStats(pokemon)
            if not valid then return false, "Party Pokemon " .. i .. ": " .. err end
        end
    end
    
    return true, nil
end

-- Comprehensive GameState validation
local function validateGameState(gameState)
    if type(gameState) ~= "table" then
        return false, "GameState must be a table"
    end
    
    local validationResults = {}
    
    -- Validate party
    if gameState.party then
        local valid, err = validateParty(gameState.party)
        if not valid then
            table.insert(validationResults, {field = "party", error = err})
        end
    end
    
    -- Validate battle state
    if gameState.battleState then
        local valid, err = validateBattleState(gameState.battleState)
        if not valid then
            table.insert(validationResults, {field = "battleState", error = err})
        end
    end
    
    -- Validate inventory
    if gameState.inventory then
        local valid, err = validateInventory(gameState.inventory)
        if not valid then
            table.insert(validationResults, {field = "inventory", error = err})
        end
    end
    
    -- Validate progression
    if gameState.progression then
        local valid, err = validateProgression(gameState.progression)
        if not valid then
            table.insert(validationResults, {field = "progression", error = err})
        end
    end
    
    -- Return results
    if #validationResults == 0 then
        return true, nil
    else
        return false, validationResults
    end
end

-- Process boundary validation (direct call - no pcall wrapper)
local function validateAtProcessBoundary(gameState, operationType)
    -- Direct validation - let it fail fast with clear errors
    local isValid, validationErrors = validateGameState(gameState)

    if not isValid then
        return {
            valid = false,
            violations = validationErrors,
            operationType = operationType,
            timestamp = tostring(msg and msg.Timestamp or 0)
        }
    end
    
    return {
        valid = true,
        operationType = operationType,
        timestamp = tostring(msg and msg.Timestamp or 0)
    }
end

-- AO Message Handlers
Handlers.add("validate-gamestate",
    Handlers.utils.hasMatchingTag("Action", "ValidateGameState"),
    function(msg)
        -- Direct JSON decode - msg.Data is controlled input from AO
        local gameState = json.decode(msg.Data or "{}")

        if not gameState then
            ao.send({
                Target = msg.From,
                Action = "ValidationError",
                Error = "Invalid JSON in GameState data",
                ProcessId = ao.id,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
            return
        end

        local validationResult = validateAtProcessBoundary(gameState, msg.OperationType or "Unknown")
        
        ao.send({
            Target = msg.From,
            Action = "ValidationResult",
            Data = json.encode(validationResult),
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus",
            Data = json.encode({
                status = "healthy",
                service = "GameState Validator",
                version = "1.0.0",
                capabilities = {
                    "pokemon-validation",
                    "battle-state-validation", 
                    "inventory-validation",
                    "progression-validation",
                    "party-validation"
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- ADP v1.0 Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = "GameState Validator",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "validateGameState",
                        "validatePokemonStats",
                        "validateBattleState",
                        "validateInventory",
                        "validateProgression",
                        "validateParty"
                    },
                    messageSchemas = {
                        ValidateGameState = {
                            required = {"Action", "Data"},
                            optional = {"OperationType"}
                        },
                        HealthCheck = {
                            required = {"Action"}
                        }
                    }
                },
                handlers = {"validate-gamestate", "health-check", "info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    purpose = "Comprehensive GameState validation at process boundaries",
                    securityFeatures = {
                        "pokemonStatValidation",
                        "battleStateIntegrity", 
                        "inventoryConstraints",
                        "progressionValidation",
                        "partyValidation"
                    }
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- Export validation functions for testing
_G.GameStateValidator = {
    validatePokemonStats = validatePokemonStats,
    validateBattleState = validateBattleState,
    validateInventory = validateInventory,
    validateProgression = validateProgression,
    validateParty = validateParty,
    validateGameState = validateGameState,
    validateAtProcessBoundary = validateAtProcessBoundary
}