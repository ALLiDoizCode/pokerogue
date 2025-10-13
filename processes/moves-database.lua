-- ============================================================================
-- Moves Database Process - ADP v1.0 Compliant Implementation
-- Pokemon move data with type effectiveness integration and self-documentation
-- AO Process Implementation for PokéRogue with ADP (AO Documentation Protocol) v1.0
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { 
    encode = function(t) return "encoded_json" end, 
    decode = function(s) return {} end 
}
local ao = ao or { 
    send = function(msg) return true end,
    id = "moves-database-adp"
}

-- Rate limiting configuration
local RATE_LIMIT_MAX = 100
local rateLimitCounters = {}

-- Performance monitoring
local performanceStartTime = nil

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function validateInput(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    if not message.Action or type(message.Action) ~= "string" then
        return false, "Action field is required and must be a string"
    end
    if message.Action ~= "Info" and message.Action ~= "HealthCheck" then
        if not message.Data or type(message.Data) ~= "table" then
            return false, "Data field is required and must be a table"
        end
        if not message.Timestamp or type(message.Timestamp) ~= "number" then
            return false, "Timestamp field is required and must be a number"
        end
    end
    return true, nil
end

local function checkRateLimit(address, msg)
    local currentTime = msg and msg.Timestamp or 0
    local currentMinute = math.floor(currentTime / 60)
    if not rateLimitCounters[address] then
        rateLimitCounters[address] = { minute = currentMinute, count = 0 }
    end
    local counter = rateLimitCounters[address]
    if counter.minute ~= currentMinute then
        counter.minute = currentMinute
        counter.count = 0
    end
    if counter.count >= RATE_LIMIT_MAX then
        return false, "Rate limit exceeded: maximum " .. RATE_LIMIT_MAX .. " queries per minute"
    end
    counter.count = counter.count + 1
    return true, nil
end

local function createSuccessResponse(data, processId, responseType)
    local response = {
        Action = "SaveState",
    }
    
    -- For single move objects, use individual tags
    if responseType == "single_move" and data and type(data) == "table" and data.id then
        response.Success = "true"
        response.MoveId = tostring(data.id)
        response.MoveName = data.name or ""
        response.Type = tostring(data.type or "")
        response.Category = tostring(data.category or "")
        response.Power = tostring(data.power or 0)
        response.Accuracy = tostring(data.accuracy or 0)
        response.PP = tostring(data.pp or 0)
        response.Priority = tostring(data.priority or 0)
        response.Effects = data.effects or ""
    else
        -- For complex data (arrays, multiple moves, etc.), use Data field
        response.Data = data
    end
    
    return response
end

local function createErrorResponse(errorMessage, processId)
    return {
        Action = "Error",
                Error = errorMessage,
    }
end

-- ============================================================================
-- POKEMON TYPES AND CONSTANTS
-- ============================================================================

local POKEMON_TYPE = {
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

local MOVE_CATEGORY = {
    PHYSICAL = 0,
    SPECIAL = 1,
    STATUS = 2
}

-- Move constants
local MOVE = {
    NONE = 0,
    POUND = 1,
    KARATE_CHOP = 2,
    TACKLE = 33,
    SCRATCH = 10,
    GROWL = 45,
    VINE_WHIP = 22,
    LEECH_SEED = 73,
    RAZOR_LEAF = 75,
    SOLAR_BEAM = 76,
    EMBER = 52,
    FLAMETHROWER = 53,
    FIRE_BLAST = 126,
    WATER_GUN = 55,
    HYDRO_PUMP = 56,
    SURF = 57,
    THUNDER_SHOCK = 84,
    THUNDERBOLT = 85,
    THUNDER = 87,
    PSYCHIC = 94,
    ICE_BEAM = 58,
    BLIZZARD = 59,
    EARTHQUAKE = 89,
    ROCK_SLIDE = 157,
    HYPER_BEAM = 63,
    QUICK_ATTACK = 98,
    SWIFT = 129,
    RECOVER = 105,
    REST = 156
}

-- ============================================================================
-- TYPE EFFECTIVENESS MATRIX
-- ============================================================================

-- Type Effectiveness Matrix (attacking type vs defending type)
-- 0 = no effect, 0.5 = not very effective, 1 = normal, 2 = super effective
local TypeEffectiveness = {
    [POKEMON_TYPE.NORMAL] = {
        [POKEMON_TYPE.ROCK] = 0.5,
        [POKEMON_TYPE.GHOST] = 0,
        [POKEMON_TYPE.STEEL] = 0.5
    },
    [POKEMON_TYPE.FIGHTING] = {
        [POKEMON_TYPE.NORMAL] = 2,
        [POKEMON_TYPE.FLYING] = 0.5,
        [POKEMON_TYPE.POISON] = 0.5,
        [POKEMON_TYPE.ROCK] = 2,
        [POKEMON_TYPE.BUG] = 0.5,
        [POKEMON_TYPE.GHOST] = 0,
        [POKEMON_TYPE.STEEL] = 2,
        [POKEMON_TYPE.PSYCHIC] = 0.5,
        [POKEMON_TYPE.ICE] = 2,
        [POKEMON_TYPE.DARK] = 2,
        [POKEMON_TYPE.FAIRY] = 0.5
    },
    [POKEMON_TYPE.FLYING] = {
        [POKEMON_TYPE.FIGHTING] = 2,
        [POKEMON_TYPE.ROCK] = 0.5,
        [POKEMON_TYPE.BUG] = 2,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.GRASS] = 2,
        [POKEMON_TYPE.ELECTRIC] = 0.5
    },
    [POKEMON_TYPE.POISON] = {
        [POKEMON_TYPE.POISON] = 0.5,
        [POKEMON_TYPE.GROUND] = 0.5,
        [POKEMON_TYPE.ROCK] = 0.5,
        [POKEMON_TYPE.GHOST] = 0.5,
        [POKEMON_TYPE.STEEL] = 0,
        [POKEMON_TYPE.GRASS] = 2,
        [POKEMON_TYPE.FAIRY] = 2
    },
    [POKEMON_TYPE.GROUND] = {
        [POKEMON_TYPE.FLYING] = 0,
        [POKEMON_TYPE.POISON] = 2,
        [POKEMON_TYPE.BUG] = 0.5,
        [POKEMON_TYPE.STEEL] = 2,
        [POKEMON_TYPE.FIRE] = 2,
        [POKEMON_TYPE.GRASS] = 0.5,
        [POKEMON_TYPE.ELECTRIC] = 2
    },
    [POKEMON_TYPE.ROCK] = {
        [POKEMON_TYPE.FIGHTING] = 0.5,
        [POKEMON_TYPE.FLYING] = 2,
        [POKEMON_TYPE.GROUND] = 0.5,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.FIRE] = 2,
        [POKEMON_TYPE.BUG] = 2,
        [POKEMON_TYPE.ICE] = 2
    },
    [POKEMON_TYPE.BUG] = {
        [POKEMON_TYPE.FIGHTING] = 0.5,
        [POKEMON_TYPE.FLYING] = 0.5,
        [POKEMON_TYPE.POISON] = 0.5,
        [POKEMON_TYPE.GHOST] = 0.5,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.FIRE] = 0.5,
        [POKEMON_TYPE.GRASS] = 2,
        [POKEMON_TYPE.PSYCHIC] = 2,
        [POKEMON_TYPE.DARK] = 2,
        [POKEMON_TYPE.FAIRY] = 0.5
    },
    [POKEMON_TYPE.GHOST] = {
        [POKEMON_TYPE.NORMAL] = 0,
        [POKEMON_TYPE.GHOST] = 2,
        [POKEMON_TYPE.PSYCHIC] = 2,
        [POKEMON_TYPE.DARK] = 0.5
    },
    [POKEMON_TYPE.STEEL] = {
        [POKEMON_TYPE.ROCK] = 2,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.FIRE] = 0.5,
        [POKEMON_TYPE.WATER] = 0.5,
        [POKEMON_TYPE.ELECTRIC] = 0.5,
        [POKEMON_TYPE.ICE] = 2,
        [POKEMON_TYPE.FAIRY] = 2
    },
    [POKEMON_TYPE.FIRE] = {
        [POKEMON_TYPE.ROCK] = 0.5,
        [POKEMON_TYPE.BUG] = 2,
        [POKEMON_TYPE.STEEL] = 2,
        [POKEMON_TYPE.FIRE] = 0.5,
        [POKEMON_TYPE.WATER] = 0.5,
        [POKEMON_TYPE.GRASS] = 2,
        [POKEMON_TYPE.ICE] = 2,
        [POKEMON_TYPE.DRAGON] = 0.5
    },
    [POKEMON_TYPE.WATER] = {
        [POKEMON_TYPE.GROUND] = 2,
        [POKEMON_TYPE.ROCK] = 2,
        [POKEMON_TYPE.FIRE] = 2,
        [POKEMON_TYPE.WATER] = 0.5,
        [POKEMON_TYPE.GRASS] = 0.5,
        [POKEMON_TYPE.DRAGON] = 0.5
    },
    [POKEMON_TYPE.GRASS] = {
        [POKEMON_TYPE.FLYING] = 0.5,
        [POKEMON_TYPE.POISON] = 0.5,
        [POKEMON_TYPE.GROUND] = 2,
        [POKEMON_TYPE.ROCK] = 2,
        [POKEMON_TYPE.BUG] = 0.5,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.FIRE] = 0.5,
        [POKEMON_TYPE.WATER] = 2,
        [POKEMON_TYPE.GRASS] = 0.5,
        [POKEMON_TYPE.DRAGON] = 0.5
    },
    [POKEMON_TYPE.ELECTRIC] = {
        [POKEMON_TYPE.FLYING] = 2,
        [POKEMON_TYPE.GROUND] = 0,
        [POKEMON_TYPE.WATER] = 2,
        [POKEMON_TYPE.GRASS] = 0.5,
        [POKEMON_TYPE.ELECTRIC] = 0.5,
        [POKEMON_TYPE.DRAGON] = 0.5
    },
    [POKEMON_TYPE.PSYCHIC] = {
        [POKEMON_TYPE.FIGHTING] = 2,
        [POKEMON_TYPE.POISON] = 2,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.PSYCHIC] = 0.5,
        [POKEMON_TYPE.DARK] = 0
    },
    [POKEMON_TYPE.ICE] = {
        [POKEMON_TYPE.FLYING] = 2,
        [POKEMON_TYPE.GROUND] = 2,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.FIRE] = 0.5,
        [POKEMON_TYPE.WATER] = 0.5,
        [POKEMON_TYPE.GRASS] = 2,
        [POKEMON_TYPE.ICE] = 0.5,
        [POKEMON_TYPE.DRAGON] = 2
    },
    [POKEMON_TYPE.DRAGON] = {
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.DRAGON] = 2,
        [POKEMON_TYPE.FAIRY] = 0
    },
    [POKEMON_TYPE.DARK] = {
        [POKEMON_TYPE.FIGHTING] = 0.5,
        [POKEMON_TYPE.GHOST] = 2,
        [POKEMON_TYPE.PSYCHIC] = 2,
        [POKEMON_TYPE.DARK] = 0.5,
        [POKEMON_TYPE.FAIRY] = 0.5
    },
    [POKEMON_TYPE.FAIRY] = {
        [POKEMON_TYPE.FIGHTING] = 2,
        [POKEMON_TYPE.POISON] = 0.5,
        [POKEMON_TYPE.STEEL] = 0.5,
        [POKEMON_TYPE.FIRE] = 0.5,
        [POKEMON_TYPE.DRAGON] = 2,
        [POKEMON_TYPE.DARK] = 2
    }
}

-- ============================================================================
-- EMBEDDED MOVES DATABASE
-- ============================================================================

-- Embedded Moves Database (Optimized for size and performance)
local MovesDB = {
    [MOVE.TACKLE] = {
        id = 33, name = "Tackle", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.PHYSICAL,
        power = 40, accuracy = 100, pp = 35, priority = 0, effects = "Normal attack with no additional effects"
    },
    [MOVE.SCRATCH] = {
        id = 10, name = "Scratch", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.PHYSICAL,
        power = 40, accuracy = 100, pp = 35, priority = 0, effects = "Normal attack with no additional effects"
    },
    [MOVE.GROWL] = {
        id = 45, name = "Growl", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.STATUS,
        power = 0, accuracy = 100, pp = 40, priority = 0, effects = "Lowers target's Attack by 1 stage"
    },
    [MOVE.VINE_WHIP] = {
        id = 22, name = "Vine Whip", type = POKEMON_TYPE.GRASS, category = MOVE_CATEGORY.PHYSICAL,
        power = 45, accuracy = 100, pp = 25, priority = 0, effects = "Grass-type physical attack"
    },
    [MOVE.LEECH_SEED] = {
        id = 73, name = "Leech Seed", type = POKEMON_TYPE.GRASS, category = MOVE_CATEGORY.STATUS,
        power = 0, accuracy = 90, pp = 10, priority = 0, effects = "Plants seed that drains HP each turn"
    },
    [MOVE.RAZOR_LEAF] = {
        id = 75, name = "Razor Leaf", type = POKEMON_TYPE.GRASS, category = MOVE_CATEGORY.PHYSICAL,
        power = 55, accuracy = 95, pp = 25, priority = 0, effects = "High critical hit ratio"
    },
    [MOVE.SOLAR_BEAM] = {
        id = 76, name = "Solar Beam", type = POKEMON_TYPE.GRASS, category = MOVE_CATEGORY.SPECIAL,
        power = 120, accuracy = 100, pp = 10, priority = 0, effects = "Charges first turn, attacks second turn"
    },
    [MOVE.EMBER] = {
        id = 52, name = "Ember", type = POKEMON_TYPE.FIRE, category = MOVE_CATEGORY.SPECIAL,
        power = 40, accuracy = 100, pp = 25, priority = 0, effects = "10% chance to burn target"
    },
    [MOVE.FLAMETHROWER] = {
        id = 53, name = "Flamethrower", type = POKEMON_TYPE.FIRE, category = MOVE_CATEGORY.SPECIAL,
        power = 90, accuracy = 100, pp = 15, priority = 0, effects = "10% chance to burn target"
    },
    [MOVE.FIRE_BLAST] = {
        id = 126, name = "Fire Blast", type = POKEMON_TYPE.FIRE, category = MOVE_CATEGORY.SPECIAL,
        power = 110, accuracy = 85, pp = 5, priority = 0, effects = "10% chance to burn target"
    },
    [MOVE.WATER_GUN] = {
        id = 55, name = "Water Gun", type = POKEMON_TYPE.WATER, category = MOVE_CATEGORY.SPECIAL,
        power = 40, accuracy = 100, pp = 25, priority = 0, effects = "Basic Water-type attack"
    },
    [MOVE.HYDRO_PUMP] = {
        id = 56, name = "Hydro Pump", type = POKEMON_TYPE.WATER, category = MOVE_CATEGORY.SPECIAL,
        power = 110, accuracy = 80, pp = 5, priority = 0, effects = "High-power Water attack"
    },
    [MOVE.SURF] = {
        id = 57, name = "Surf", type = POKEMON_TYPE.WATER, category = MOVE_CATEGORY.SPECIAL,
        power = 90, accuracy = 100, pp = 15, priority = 0, effects = "Hits all adjacent Pokemon"
    },
    [MOVE.THUNDER_SHOCK] = {
        id = 84, name = "Thunder Shock", type = POKEMON_TYPE.ELECTRIC, category = MOVE_CATEGORY.SPECIAL,
        power = 40, accuracy = 100, pp = 30, priority = 0, effects = "10% chance to paralyze target"
    },
    [MOVE.THUNDERBOLT] = {
        id = 85, name = "Thunderbolt", type = POKEMON_TYPE.ELECTRIC, category = MOVE_CATEGORY.SPECIAL,
        power = 90, accuracy = 100, pp = 15, priority = 0, effects = "10% chance to paralyze target"
    },
    [MOVE.THUNDER] = {
        id = 87, name = "Thunder", type = POKEMON_TYPE.ELECTRIC, category = MOVE_CATEGORY.SPECIAL,
        power = 110, accuracy = 70, pp = 10, priority = 0, effects = "30% chance to paralyze target"
    },
    [MOVE.PSYCHIC] = {
        id = 94, name = "Psychic", type = POKEMON_TYPE.PSYCHIC, category = MOVE_CATEGORY.SPECIAL,
        power = 90, accuracy = 100, pp = 10, priority = 0, effects = "10% chance to lower Special Defense"
    },
    [MOVE.ICE_BEAM] = {
        id = 58, name = "Ice Beam", type = POKEMON_TYPE.ICE, category = MOVE_CATEGORY.SPECIAL,
        power = 90, accuracy = 100, pp = 10, priority = 0, effects = "10% chance to freeze target"
    },
    [MOVE.BLIZZARD] = {
        id = 59, name = "Blizzard", type = POKEMON_TYPE.ICE, category = MOVE_CATEGORY.SPECIAL,
        power = 110, accuracy = 70, pp = 5, priority = 0, effects = "10% chance to freeze target"
    },
    [MOVE.EARTHQUAKE] = {
        id = 89, name = "Earthquake", type = POKEMON_TYPE.GROUND, category = MOVE_CATEGORY.PHYSICAL,
        power = 100, accuracy = 100, pp = 10, priority = 0, effects = "Hits all adjacent Pokemon"
    },
    [MOVE.ROCK_SLIDE] = {
        id = 157, name = "Rock Slide", type = POKEMON_TYPE.ROCK, category = MOVE_CATEGORY.PHYSICAL,
        power = 75, accuracy = 90, pp = 10, priority = 0, effects = "30% chance to flinch, hits all foes"
    },
    [MOVE.HYPER_BEAM] = {
        id = 63, name = "Hyper Beam", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.SPECIAL,
        power = 150, accuracy = 90, pp = 5, priority = 0, effects = "User must recharge next turn"
    },
    [MOVE.QUICK_ATTACK] = {
        id = 98, name = "Quick Attack", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.PHYSICAL,
        power = 40, accuracy = 100, pp = 30, priority = 1, effects = "Always goes first"
    },
    [MOVE.SWIFT] = {
        id = 129, name = "Swift", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.SPECIAL,
        power = 60, accuracy = 999, pp = 20, priority = 0, effects = "Never misses"
    },
    [MOVE.RECOVER] = {
        id = 105, name = "Recover", type = POKEMON_TYPE.NORMAL, category = MOVE_CATEGORY.STATUS,
        power = 0, accuracy = 100, pp = 5, priority = 0, effects = "Restores 50% of max HP"
    },
    [MOVE.REST] = {
        id = 156, name = "Rest", type = POKEMON_TYPE.PSYCHIC, category = MOVE_CATEGORY.STATUS,
        power = 0, accuracy = 100, pp = 10, priority = 0, effects = "Fully heals HP, sleeps for 2 turns"
    }
}

-- ============================================================================
-- OPTIMIZED INDEXES AND HELPER FUNCTIONS
-- ============================================================================

-- Create optimized indexes for fast lookups
local nameIndex = {}
local typeIndex = {}

for moveId, data in pairs(MovesDB) do
    nameIndex[data.name:lower()] = data
    
    if not typeIndex[data.type] then
        typeIndex[data.type] = {}
    end
    table.insert(typeIndex[data.type], data)
end

-- Helper function to get type effectiveness
local function getTypeEffectiveness(attackingType, defendingType)
    if TypeEffectiveness[attackingType] and TypeEffectiveness[attackingType][defendingType] then
        return TypeEffectiveness[attackingType][defendingType]
    end
    return 1.0 -- Normal effectiveness
end

-- ============================================================================
-- QUERY HANDLERS
-- ============================================================================

local function getMoveById(moveId)
    return MovesDB[moveId]
end

local function getMoveByName(name)
    return nameIndex[name:lower()]
end

local function getMovesByType(pokemonType)
    return typeIndex[pokemonType] or {}
end

local function calculateTypeEffectiveness(attackingType, defendingTypes)
    local effectiveness = 1.0
    
    for _, defendingType in ipairs(defendingTypes) do
        effectiveness = effectiveness * getTypeEffectiveness(attackingType, defendingType)
    end
    
    return effectiveness
end

local function getMoveEffectivenessChart(pokemonType)
    local chart = {}
    
    for defendingType = 0, 17 do
        chart[defendingType] = getTypeEffectiveness(pokemonType, defendingType)
    end
    
    return chart
end

-- ============================================================================
-- MAIN QUERY HANDLER
-- ============================================================================

local function handleMovesQuery(message)
    local action = message.Action
    
    if action == "GetMove" then
        local moveId = message.MoveId or message.Id
        local moveName = message.MoveName or message.Name
        
        if moveId then
            return getMoveById(tonumber(moveId))
        elseif moveName then
            return getMoveByName(moveName)
        else
            error("GetMove requires either 'MoveId'/'Id' or 'MoveName'/'Name' tag")
        end
    elseif action == "GetMovesByType" then
        local moveType = message.MoveType or message.Type
        if not moveType then
            error("GetMovesByType requires 'MoveType' or 'Type' tag")
        end
        return getMovesByType(moveType)
    elseif action == "GetTypeEffectiveness" then
        local attackingType = message.AttackingType
        local defendingTypes = message.DefendingTypes
        
        if attackingType and defendingTypes then
            return {
                effectiveness = calculateTypeEffectiveness(attackingType, defendingTypes)
            }
        elseif attackingType then
            return {
                chart = getMoveEffectivenessChart(attackingType)
            }
        else
            error("GetTypeEffectiveness requires 'AttackingType' tag")
        end
    else
        error("Unknown action: " .. action)
    end
end

local function handleMessage(message, processId, queryHandler)
    local isValid, validationError = validateInput(message)
    if not isValid then
        return createErrorResponse(validationError, processId)
    end
    
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress, message)
    if not rateLimitOk then
        return createErrorResponse(rateLimitError, processId)
    end
    
    local result = queryHandler(message)
    
    -- Determine response type based on action
    local responseType = nil
    if message.Action == "GetMove" then
        responseType = "single_move"
    end
    return createSuccessResponse(result, processId, responseType)
end

-- ============================================================================
-- AO MESSAGE HANDLERS WITH ADP v1.0 COMPLIANCE
-- ============================================================================

-- ADP v1.0 REQUIRED: Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local moveCount = 0
        for _ in pairs(MovesDB) do
            moveCount = moveCount + 1
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = "Moves Database Process",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "GetMove", 
                        "GetMovesByType", 
                        "GetTypeEffectiveness", 
                        "HealthCheck",
                        "Info"
                    },
                    messageSchemas = {
                        GetMove = {
                            required = {"Action", "Data"},
                            dataFields = {"id OR name"},
                            description = "Retrieve move data by ID or name"
                        },
                        GetMovesByType = {
                            required = {"Action", "Data", "Timestamp"},
                            dataFields = {"type"},
                            description = "Get all moves of a specific type"
                        },
                        GetTypeEffectiveness = {
                            required = {"Action", "Data", "Timestamp"},
                            dataFields = {"attackingType", "defendingTypes (optional)"},
                            description = "Calculate type effectiveness or get effectiveness chart"
                        },
                        HealthCheck = {
                            required = {"Action"},
                            description = "Check process health and status"
                        }
                    },
                    performance = {
                        rateLimit = RATE_LIMIT_MAX .. " queries per minute",
                        targetResponseTime = "< 100ms",
                        moveCount = moveCount
                    },
                    typeSystem = {
                        supportedTypes = 18,
                        typeEffectivenessMatrix = "Complete Gen 1-8 compatibility"
                    }
                },
                handlers = {"GetMove", "GetMovesByType", "GetTypeEffectiveness", "HealthCheck", "Info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Pokemon moves database with type effectiveness calculations and sub-100ms performance",
                    usage = "Send messages with Action field matching supported capabilities"
                }
            },
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- GetMove handler - Retrieve move data by ID or name
Handlers.add("get-move",
    Handlers.utils.hasMatchingTag("Action", "GetMove"),
    function(msg)
        local moveId = msg.MoveId or msg.Id
        local moveName = msg.MoveName or msg.Name
        if not moveId and not moveName then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "GetMove requires either 'MoveId'/'Id' or 'MoveName'/'Name' tag",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        local result = nil
        if moveName then
            result = getMoveByName(moveName)
        elseif moveId then
            result = getMoveById(tonumber(moveId))
        end
        
        if result then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "true",
                MoveId = tostring(result.id),
                MoveName = result.name or "",
                Type = tostring(result.type or ""),
                Category = tostring(result.category or ""),
                Power = tostring(result.power or 0),
                Accuracy = tostring(result.accuracy or 0),
                PP = tostring(result.pp or 0),
                Priority = tostring(result.priority or 0),
                Effects = result.effects or "",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Move not found",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- GetMovesByType handler - Get all moves of a specific type
Handlers.add("get-moves-by-type",
    Handlers.utils.hasMatchingTag("Action", "GetMovesByType"),
    function(msg)
        local moveType = msg.MoveType or msg.Type
        if not moveType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "GetMovesByType requires 'MoveType' or 'Type' tag",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        local result = getMovesByType(tonumber(moveType))
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- GetTypeEffectiveness handler - Calculate type effectiveness or get effectiveness chart
Handlers.add("get-type-effectiveness",
    Handlers.utils.hasMatchingTag("Action", "GetTypeEffectiveness"),
    function(msg)
        local attackingType = msg.AttackingType
        if not attackingType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "GetTypeEffectiveness requires 'AttackingType' tag",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        local defendingTypes = msg.DefendingTypes
        local result = nil
        
        if defendingTypes then
            -- Calculate effectiveness against specific defending types
            local effectiveness = calculateTypeEffectiveness(tonumber(attackingType), defendingTypes)
            result = { effectiveness = effectiveness }
        else
            -- Return full effectiveness chart
            local chart = getMoveEffectivenessChart(tonumber(attackingType))
            result = { chart = chart }
        end
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        local moveCount = 0
        for _ in pairs(MovesDB) do
            moveCount = moveCount + 1
        end
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                status = "healthy",
                processId = ao.id,
                moveCount = moveCount,
                typeEffectivenessLoaded = true,
                version = "1.0.0",
                adpVersion = "1.0",
                capabilities = {"GetMove", "GetMovesByType", "GetTypeEffectiveness", "HealthCheck", "Info"},
                performance = {
                    rateLimit = RATE_LIMIT_MAX .. " queries per minute",
                    targetResponseTime = "< 100ms"
                }
            },
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- AO processes should not return module exports
-- All data is handled through message passing via ao.send()
print("Moves Database initialization complete.")