-- ============================================================================
-- Moves Database Process - Move data with type effectiveness integration and sub-100ms performance
-- AO Process Implementation for PokéRogue
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { 
    encode = function(t) return "encoded_json" end, 
    decode = function(s) return {} end 
}
local ao = ao or { 
    send = function(msg) return true end,
    id = "moves-database"
}

-- ============================================================================
-- EMBEDDED DATA PROCESS TEMPLATE
-- ============================================================================

-- Rate limiting configuration
local RATE_LIMIT_MAX = 100
local rateLimitCounters = {}

-- Performance monitoring
local performanceStartTime = nil

local function validateInput(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    if not message.Action or type(message.Action) ~= "string" then
        return false, "Action field is required and must be a string"
    end
    if not message.Data or type(message.Data) ~= "table" then
        return false, "Data field is required and must be a table"
    end
    if not message.Timestamp or type(message.Timestamp) ~= "number" then
        return false, "Timestamp field is required and must be a number"
    end
    return true, nil
end

local function checkRateLimit(address)
    local currentTime = os.time()
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

local function createSuccessResponse(data, processId)
    return {
        Action = "SaveState",
        Data = data,
        Timestamp = os.time(),
        ProcessId = processId or ao.id
    }
end

local function createErrorResponse(errorMessage, processId)
    return {
        Action = "SaveState",
        Error = errorMessage,
        ProcessId = processId or ao.id,
        Timestamp = os.time()
    }
end

local function handleMessage(message, processId, queryHandler)
    local isValid, validationError = validateInput(message)
    if not isValid then
        return createErrorResponse(validationError, processId)
    end
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
    if not rateLimitOk then
        return createErrorResponse(rateLimitError, processId)
    end
    local success, result = pcall(function()
        return queryHandler(message)
    end)
    if success then
        return createSuccessResponse(result, processId)
    else
        return createErrorResponse("Query processing failed: " .. tostring(result), processId)
    end
end

local QueryOptimizations = {
    createIndex = function(dataTable, keyField)
        local index = {}
        for i, item in ipairs(dataTable) do
            if item[keyField] then
                index[item[keyField]] = item
            end
        end
        return index
    end
}

-- ============================================================================
-- PROCESS SPECIFIC CODE
-- ============================================================================

local MovesDatabase = {}
local PROCESS_ID = ao.id

-- Move and Type Constants
local MOVE = {
    NONE = 0,
    POUND = 1,
    KARATE_CHOP = 2,
    DOUBLE_SLAP = 3,
    COMET_PUNCH = 4,
    MEGA_PUNCH = 5,
    PAY_DAY = 6,
    FIRE_PUNCH = 7,
    ICE_PUNCH = 8,
    THUNDER_PUNCH = 9,
    SCRATCH = 10,
    VINE_WHIP = 22,
    TACKLE = 33,
    BODY_SLAM = 34,
    WRAP = 35,
    TAKE_DOWN = 36,
    THRASH = 37,
    DOUBLE_EDGE = 38,
    TAIL_WHIP = 39,
    POISON_STING = 40,
    TWINEEDLE = 41,
    PIN_MISSILE = 42,
    LEER = 43,
    BITE = 44,
    GROWL = 45,
    ROAR = 46,
    SING = 47,
    SUPERSONIC = 48,
    SONIC_BOOM = 49,
    DISABLE = 50,
    ACID = 51,
    EMBER = 52,
    FLAMETHROWER = 53,
    MIST = 54,
    WATER_GUN = 55,
    HYDRO_PUMP = 56,
    SURF = 57,
    ICE_BEAM = 58,
    BLIZZARD = 59,
    PSYBEAM = 60,
    BUBBLE_BEAM = 61,
    AURORA_BEAM = 62,
    HYPER_BEAM = 63,
    PECK = 64,
    DRILL_PECK = 65,
    SUBMISSION = 66,
    LOW_KICK = 67,
    COUNTER = 68,
    SEISMIC_TOSS = 69,
    STRENGTH = 70,
    ABSORB = 71,
    MEGA_DRAIN = 72,
    LEECH_SEED = 73,
    GROWTH = 74,
    RAZOR_LEAF = 75,
    SOLAR_BEAM = 76,
    POISON_POWDER = 77,
    STUN_SPORE = 78,
    SLEEP_POWDER = 79,
    PETAL_DANCE = 80,
    STRING_SHOT = 81,
    DRAGON_RAGE = 82,
    FIRE_SPIN = 83,
    THUNDER_SHOCK = 84,
    THUNDERBOLT = 85,
    THUNDER_WAVE = 86,
    THUNDER = 87,
    ROCK_THROW = 88,
    EARTHQUAKE = 89,
    FISSURE = 90,
    DIG = 91,
    TOXIC = 92,
    CONFUSION = 93,
    PSYCHIC = 94,
    HYPNOSIS = 95,
    MEDITATE = 96,
    AGILITY = 97,
    QUICK_ATTACK = 98,
    RAGE = 99,
    TELEPORT = 100,
    NIGHT_SHADE = 101,
    MIMIC = 102,
    SCREECH = 103,
    DOUBLE_TEAM = 104,
    RECOVER = 105,
    HARDEN = 106,
    MINIMIZE = 107,
    SMOKESCREEN = 108,
    CONFUSE_RAY = 109,
    WITHDRAW = 110,
    DEFENSE_CURL = 111,
    BARRIER = 112,
    LIGHT_SCREEN = 113,
    HAZE = 114,
    REFLECT = 115,
    FOCUS_ENERGY = 116,
    BIDE = 117,
    METRONOME = 118,
    MIRROR_MOVE = 119,
    SELF_DESTRUCT = 120,
    EGG_BOMB = 121,
    LICK = 122,
    SMOG = 123,
    SLUDGE = 124,
    BONE_CLUB = 125,
    FIRE_BLAST = 126,
    WATERFALL = 127,
    CLAMP = 128,
    SWIFT = 129,
    SKULL_BASH = 130,
    SPIKE_CANNON = 131,
    CONSTRICT = 132,
    AMNESIA = 133,
    KINESIS = 134,
    SOFT_BOILED = 135,
    HIGH_JUMP_KICK = 136,
    GLARE = 137,
    DREAM_EATER = 138,
    POISON_GAS = 139,
    BARRAGE = 140,
    LEECH_LIFE = 141,
    LOVELY_KISS = 142,
    SKY_ATTACK = 143,
    TRANSFORM = 144,
    BUBBLE = 145,
    DIZZY_PUNCH = 146,
    SPORE = 147,
    FLASH = 148,
    PSYWAVE = 149,
    SPLASH = 150,
    ACID_ARMOR = 151,
    CRABHAMMER = 152,
    EXPLOSION = 153,
    FURY_SWIPES = 154,
    BONEMERANG = 155,
    REST = 156,
    ROCK_SLIDE = 157,
    HYPER_FANG = 158,
    SHARPEN = 159,
    CONVERSION = 160,
    TRI_ATTACK = 161,
    SUPER_FANG = 162,
    SLASH = 163,
    SUBSTITUTE = 164,
    STRUGGLE = 165
}

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

-- Embedded Moves Database (Optimized for size and performance)
local MovesDB = {
    [MOVE.TACKLE] = {
        id = 33, n = "Tackle", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 40, acc = 100, pp = 35, pri = 0, eff = "Normal attack with no additional effects"
    },
    [MOVE.SCRATCH] = {
        id = 10, n = "Scratch", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 40, acc = 100, pp = 35, pri = 0, eff = "Normal attack with no additional effects"
    },
    [MOVE.GROWL] = {
        id = 45, n = "Growl", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.STATUS,
        pwr = 0, acc = 100, pp = 40, pri = 0, eff = "Lowers target's Attack by 1 stage"
    },
    [MOVE.VINE_WHIP] = {
        id = 22, n = "Vine Whip", t = POKEMON_TYPE.GRASS, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 45, acc = 100, pp = 25, pri = 0, eff = "Grass-type physical attack"
    },
    [MOVE.LEECH_SEED] = {
        id = 73, n = "Leech Seed", t = POKEMON_TYPE.GRASS, cat = MOVE_CATEGORY.STATUS,
        pwr = 0, acc = 90, pp = 10, pri = 0, eff = "Plants seed that drains HP each turn"
    },
    [MOVE.RAZOR_LEAF] = {
        id = 75, n = "Razor Leaf", t = POKEMON_TYPE.GRASS, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 55, acc = 95, pp = 25, pri = 0, eff = "High critical hit ratio"
    },
    [MOVE.SOLAR_BEAM] = {
        id = 76, n = "Solar Beam", t = POKEMON_TYPE.GRASS, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 120, acc = 100, pp = 10, pri = 0, eff = "Charges first turn, attacks second turn"
    },
    [MOVE.EMBER] = {
        id = 52, n = "Ember", t = POKEMON_TYPE.FIRE, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 40, acc = 100, pp = 25, pri = 0, eff = "10% chance to burn target"
    },
    [MOVE.FLAMETHROWER] = {
        id = 53, n = "Flamethrower", t = POKEMON_TYPE.FIRE, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 90, acc = 100, pp = 15, pri = 0, eff = "10% chance to burn target"
    },
    [MOVE.FIRE_BLAST] = {
        id = 126, n = "Fire Blast", t = POKEMON_TYPE.FIRE, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 110, acc = 85, pp = 5, pri = 0, eff = "10% chance to burn target"
    },
    [MOVE.WATER_GUN] = {
        id = 55, n = "Water Gun", t = POKEMON_TYPE.WATER, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 40, acc = 100, pp = 25, pri = 0, eff = "Basic Water-type attack"
    },
    [MOVE.HYDRO_PUMP] = {
        id = 56, n = "Hydro Pump", t = POKEMON_TYPE.WATER, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 110, acc = 80, pp = 5, pri = 0, eff = "High-power Water attack"
    },
    [MOVE.SURF] = {
        id = 57, n = "Surf", t = POKEMON_TYPE.WATER, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 90, acc = 100, pp = 15, pri = 0, eff = "Hits all adjacent Pokemon"
    },
    [MOVE.THUNDER_SHOCK] = {
        id = 84, n = "Thunder Shock", t = POKEMON_TYPE.ELECTRIC, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 40, acc = 100, pp = 30, pri = 0, eff = "10% chance to paralyze target"
    },
    [MOVE.THUNDERBOLT] = {
        id = 85, n = "Thunderbolt", t = POKEMON_TYPE.ELECTRIC, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 90, acc = 100, pp = 15, pri = 0, eff = "10% chance to paralyze target"
    },
    [MOVE.THUNDER] = {
        id = 87, n = "Thunder", t = POKEMON_TYPE.ELECTRIC, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 110, acc = 70, pp = 10, pri = 0, eff = "30% chance to paralyze target"
    },
    [MOVE.PSYCHIC] = {
        id = 94, n = "Psychic", t = POKEMON_TYPE.PSYCHIC, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 90, acc = 100, pp = 10, pri = 0, eff = "10% chance to lower Special Defense"
    },
    [MOVE.ICE_BEAM] = {
        id = 58, n = "Ice Beam", t = POKEMON_TYPE.ICE, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 90, acc = 100, pp = 10, pri = 0, eff = "10% chance to freeze target"
    },
    [MOVE.BLIZZARD] = {
        id = 59, n = "Blizzard", t = POKEMON_TYPE.ICE, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 110, acc = 70, pp = 5, pri = 0, eff = "10% chance to freeze target"
    },
    [MOVE.EARTHQUAKE] = {
        id = 89, n = "Earthquake", t = POKEMON_TYPE.GROUND, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 100, acc = 100, pp = 10, pri = 0, eff = "Hits all adjacent Pokemon"
    },
    [MOVE.ROCK_SLIDE] = {
        id = 157, n = "Rock Slide", t = POKEMON_TYPE.ROCK, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 75, acc = 90, pp = 10, pri = 0, eff = "30% chance to flinch, hits all foes"
    },
    [MOVE.HYPER_BEAM] = {
        id = 63, n = "Hyper Beam", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 150, acc = 90, pp = 5, pri = 0, eff = "User must recharge next turn"
    },
    [MOVE.QUICK_ATTACK] = {
        id = 98, n = "Quick Attack", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.PHYSICAL,
        pwr = 40, acc = 100, pp = 30, pri = 1, eff = "Always goes first"
    },
    [MOVE.SWIFT] = {
        id = 129, n = "Swift", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.SPECIAL,
        pwr = 60, acc = 999, pp = 20, pri = 0, eff = "Never misses"
    },
    [MOVE.RECOVER] = {
        id = 105, n = "Recover", t = POKEMON_TYPE.NORMAL, cat = MOVE_CATEGORY.STATUS,
        pwr = 0, acc = 100, pp = 5, pri = 0, eff = "Restores 50% of max HP"
    },
    [MOVE.REST] = {
        id = 156, n = "Rest", t = POKEMON_TYPE.PSYCHIC, cat = MOVE_CATEGORY.STATUS,
        pwr = 0, acc = 100, pp = 10, pri = 0, eff = "Fully heals HP, sleeps for 2 turns"
    }
}

-- Create optimized indexes
local moveIndex = QueryOptimizations.createIndex(MovesDB, "id")
local nameIndex = {}
local typeIndex = {}

for moveId, data in pairs(MovesDB) do
    nameIndex[data.n:lower()] = data
    
    if not typeIndex[data.t] then
        typeIndex[data.t] = {}
    end
    table.insert(typeIndex[data.t], data)
end

-- Helper function to get type effectiveness
local function getTypeEffectiveness(attackingType, defendingType)
    if TypeEffectiveness[attackingType] and TypeEffectiveness[attackingType][defendingType] then
        return TypeEffectiveness[attackingType][defendingType]
    end
    return 1.0 -- Normal effectiveness
end

-- Query handlers
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

-- Main query handler for moves database
local function handleMovesQuery(message)
    local action = message.Action
    local data = message.Data
    
    if action == "GetMove" then
        if data.id then
            return getMoveById(data.id)
        elseif data.name then
            return getMoveByName(data.name)
        else
            error("GetMove requires either 'id' or 'name' in Data")
        end
    elseif action == "GetMovesByType" then
        if not data.type then
            error("GetMovesByType requires 'type' in Data")
        end
        return getMovesByType(data.type)
    elseif action == "GetTypeEffectiveness" then
        if data.attackingType and data.defendingTypes then
            return {
                effectiveness = calculateTypeEffectiveness(data.attackingType, data.defendingTypes)
            }
        elseif data.attackingType then
            return {
                chart = getMoveEffectivenessChart(data.attackingType)
            }
        else
            error("GetTypeEffectiveness requires 'attackingType' in Data")
        end
    else
        error("Unknown action: " .. action)
    end
end

-- AO Message Handlers
Handlers.add("moves-query", 
    Handlers.utils.hasMatchingTag("Action", {"GetMove", "GetMovesByType", "GetTypeEffectiveness"}),
    function(msg)
        local response = handleMessage(msg, PROCESS_ID, handleMovesQuery)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data,
            Error = response.Error,
            ProcessId = response.ProcessId,
            Timestamp = tostring(response.Timestamp)
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
                processId = PROCESS_ID,
                moveCount = moveCount,
                typeEffectivenessLoaded = true,
                version = "1.0"
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

return MovesDatabase