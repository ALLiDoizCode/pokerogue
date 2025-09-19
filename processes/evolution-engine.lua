-- Evolution Engine Process for PokéRogue AO (ADP v1.0 Compliant)
-- Handles Pokemon evolution logic, stat recalculation, and form change handling
-- Implements pure computation on GameState with evolution transformations
-- Monolithic process - all dependencies embedded (no external imports)

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "evolution-engine" }

-- Handlers global (AO runtime provides this)
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- Evolution Engine process identifier
local PROCESS_ID = "evolution-engine"
local PROCESS_VERSION = "1.0.0"
local ADP_VERSION = "1.0"

-- Performance monitoring configuration (5 second limit for logic operations)
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local performanceStartTime = nil

-- Rate limiting configuration (stricter for logic processes)
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}

-- Evolution types (embedded data)
local EVOLUTION_TYPES = {
    LEVEL = "level",
    STONE = "stone", 
    TRADE = "trade",
    HAPPINESS = "happiness",
    TIME = "time",
    LOCATION = "location",
    CONDITION = "condition",
    FRIENDSHIP = "friendship",
    ITEM = "item",
    MOVE = "move",
    GENDER = "gender",
    STATS = "stats",
    WEATHER = "weather"
}

-- Comprehensive evolution chains (embedded data for all generations)
local EVOLUTION_CHAINS = {
    -- Gen 1 Starters
    [1] = { -- Bulbasaur
        {toSpecies = 2, level = 16, type = EVOLUTION_TYPES.LEVEL}, -- to Ivysaur
    },
    [2] = { -- Ivysaur
        {toSpecies = 3, level = 32, type = EVOLUTION_TYPES.LEVEL}, -- to Venusaur
    },
    [4] = { -- Charmander
        {toSpecies = 5, level = 16, type = EVOLUTION_TYPES.LEVEL}, -- to Charmeleon
    },
    [5] = { -- Charmeleon
        {toSpecies = 6, level = 36, type = EVOLUTION_TYPES.LEVEL}, -- to Charizard
    },
    [7] = { -- Squirtle
        {toSpecies = 8, level = 16, type = EVOLUTION_TYPES.LEVEL}, -- to Wartortle
    },
    [8] = { -- Wartortle
        {toSpecies = 9, level = 36, type = EVOLUTION_TYPES.LEVEL}, -- to Blastoise
    },
    
    -- Classic Stone Evolutions
    [25] = { -- Pikachu
        {toSpecies = 26, type = EVOLUTION_TYPES.STONE, item = "thunder_stone"}, -- to Raichu
    },
    [37] = { -- Vulpix
        {toSpecies = 38, type = EVOLUTION_TYPES.STONE, item = "fire_stone"}, -- to Ninetales
    },
    [61] = { -- Poliwhirl
        {toSpecies = 62, type = EVOLUTION_TYPES.STONE, item = "water_stone"}, -- to Poliwrath
        {toSpecies = 186, type = EVOLUTION_TYPES.TRADE, item = "kings_rock"}, -- to Politoed
    },
    
    -- Trade Evolutions
    [64] = { -- Kadabra
        {toSpecies = 65, type = EVOLUTION_TYPES.TRADE}, -- to Alakazam
    },
    [67] = { -- Machoke
        {toSpecies = 68, type = EVOLUTION_TYPES.TRADE}, -- to Machamp
    },
    [75] = { -- Graveler
        {toSpecies = 76, type = EVOLUTION_TYPES.TRADE}, -- to Golem
    },
    [93] = { -- Haunter
        {toSpecies = 94, type = EVOLUTION_TYPES.TRADE}, -- to Gengar
    },
    
    -- Eevee Evolution Family
    [133] = { -- Eevee
        {toSpecies = 134, type = EVOLUTION_TYPES.STONE, item = "water_stone"}, -- to Vaporeon
        {toSpecies = 135, type = EVOLUTION_TYPES.STONE, item = "thunder_stone"}, -- to Jolteon
        {toSpecies = 136, type = EVOLUTION_TYPES.STONE, item = "fire_stone"}, -- to Flareon
        {toSpecies = 196, type = EVOLUTION_TYPES.FRIENDSHIP, timeOfDay = "day"}, -- to Espeon
        {toSpecies = 197, type = EVOLUTION_TYPES.FRIENDSHIP, timeOfDay = "night"}, -- to Umbreon
        {toSpecies = 470, type = EVOLUTION_TYPES.LOCATION, location = "moss_rock"}, -- to Leafeon
        {toSpecies = 471, type = EVOLUTION_TYPES.LOCATION, location = "ice_rock"}, -- to Glaceon
        {toSpecies = 700, type = EVOLUTION_TYPES.FRIENDSHIP, affection = 2}, -- to Sylveon
    },
    
    -- Gen 2 Special Cases
    [179] = { -- Mareep
        {toSpecies = 180, level = 15, type = EVOLUTION_TYPES.LEVEL}, -- to Flaaffy
    },
    [180] = { -- Flaaffy
        {toSpecies = 181, level = 30, type = EVOLUTION_TYPES.LEVEL}, -- to Ampharos
    },
    
    -- Gen 3 Complex Evolutions
    [265] = { -- Wurmple (split evolution)
        {toSpecies = 266, level = 7, type = EVOLUTION_TYPES.CONDITION, condition = "personality_silcoon"}, -- to Silcoon
        {toSpecies = 268, level = 7, type = EVOLUTION_TYPES.CONDITION, condition = "personality_cascoon"}, -- to Cascoon
    },
    [287] = { -- Slakoth
        {toSpecies = 288, level = 18, type = EVOLUTION_TYPES.LEVEL}, -- to Vigoroth
    },
    [288] = { -- Vigoroth
        {toSpecies = 289, level = 36, type = EVOLUTION_TYPES.LEVEL}, -- to Slaking
    },
    
    -- Weather-based evolution
    [351] = { -- Castform (form changes based on weather)
        {toSpecies = 351, type = EVOLUTION_TYPES.WEATHER, weather = "sunny"}, -- to Sunny Form
        {toSpecies = 351, type = EVOLUTION_TYPES.WEATHER, weather = "rainy"}, -- to Rainy Form
        {toSpecies = 351, type = EVOLUTION_TYPES.WEATHER, weather = "snowy"}, -- to Snowy Form
    },
    
    -- Gen 4 Method Evolutions
    [446] = { -- Munchlax
        {toSpecies = 143, type = EVOLUTION_TYPES.FRIENDSHIP}, -- to Snorlax
    },
    [449] = { -- Hippopotas
        {toSpecies = 450, level = 34, type = EVOLUTION_TYPES.LEVEL}, -- to Hippowdon
    },
    
    -- Move-based evolution
    [458] = { -- Mantyke
        {toSpecies = 226, type = EVOLUTION_TYPES.MOVE, move = "remoraid_party"}, -- to Mantine
    }
}

-- Comprehensive base stats for stat recalculation
local SPECIES_BASE_STATS = {
    -- Gen 1 Starters
    [1] = {hp = 45, attack = 49, defense = 49, spAttack = 65, spDefense = 65, speed = 45}, -- Bulbasaur
    [2] = {hp = 60, attack = 62, defense = 63, spAttack = 80, spDefense = 80, speed = 60}, -- Ivysaur
    [3] = {hp = 80, attack = 82, defense = 83, spAttack = 100, spDefense = 100, speed = 80}, -- Venusaur
    [4] = {hp = 39, attack = 52, defense = 43, spAttack = 60, spDefense = 50, speed = 65}, -- Charmander
    [5] = {hp = 58, attack = 64, defense = 58, spAttack = 80, spDefense = 65, speed = 80}, -- Charmeleon
    [6] = {hp = 78, attack = 84, defense = 78, spAttack = 109, spDefense = 85, speed = 100}, -- Charizard
    [7] = {hp = 44, attack = 48, defense = 65, spAttack = 50, spDefense = 64, speed = 43}, -- Squirtle
    [8] = {hp = 59, attack = 63, defense = 80, spAttack = 65, spDefense = 80, speed = 58}, -- Wartortle
    [9] = {hp = 79, attack = 83, defense = 100, spAttack = 85, spDefense = 105, speed = 78}, -- Blastoise
    
    -- Popular Pokemon
    [25] = {hp = 35, attack = 55, defense = 40, spAttack = 50, spDefense = 50, speed = 90}, -- Pikachu
    [26] = {hp = 60, attack = 90, defense = 55, spAttack = 90, spDefense = 80, speed = 110}, -- Raichu
    [37] = {hp = 38, attack = 41, defense = 40, spAttack = 50, spDefense = 65, speed = 65}, -- Vulpix
    [38] = {hp = 73, attack = 76, defense = 75, spAttack = 81, spDefense = 100, speed = 100}, -- Ninetales
    
    -- Trade Evolutions
    [64] = {hp = 40, attack = 35, defense = 30, spAttack = 120, spDefense = 70, speed = 105}, -- Kadabra
    [65] = {hp = 55, attack = 50, defense = 45, spAttack = 135, spDefense = 95, speed = 120}, -- Alakazam
    [67] = {hp = 80, attack = 100, defense = 70, spAttack = 50, spDefense = 60, speed = 45}, -- Machoke
    [68] = {hp = 90, attack = 130, defense = 80, spAttack = 65, spDefense = 85, speed = 55}, -- Machamp
    [75] = {hp = 55, attack = 95, defense = 115, spAttack = 45, spDefense = 45, speed = 35}, -- Graveler
    [76] = {hp = 80, attack = 120, defense = 130, spAttack = 55, spDefense = 65, speed = 45}, -- Golem
    [93] = {hp = 45, attack = 50, defense = 45, spAttack = 115, spDefense = 55, speed = 95}, -- Haunter
    [94] = {hp = 60, attack = 65, defense = 60, spAttack = 130, spDefense = 75, speed = 110}, -- Gengar
    
    -- Eevee Family
    [133] = {hp = 55, attack = 55, defense = 50, spAttack = 45, spDefense = 65, speed = 55}, -- Eevee
    [134] = {hp = 130, attack = 65, defense = 60, spAttack = 110, spDefense = 95, speed = 65}, -- Vaporeon
    [135] = {hp = 65, attack = 65, defense = 60, spAttack = 110, spDefense = 95, speed = 130}, -- Jolteon
    [136] = {hp = 65, attack = 130, defense = 60, spAttack = 95, spDefense = 110, speed = 65}, -- Flareon
    [196] = {hp = 65, attack = 65, defense = 60, spAttack = 130, spDefense = 95, speed = 110}, -- Espeon
    [197] = {hp = 95, attack = 65, defense = 110, spAttack = 60, spDefense = 130, speed = 65}, -- Umbreon
    [470] = {hp = 65, attack = 110, defense = 130, spAttack = 60, spDefense = 65, speed = 95}, -- Leafeon
    [471] = {hp = 65, attack = 60, defense = 110, spAttack = 130, spDefense = 95, speed = 65}, -- Glaceon
    [700] = {hp = 95, attack = 65, defense = 65, spAttack = 110, spDefense = 130, speed = 60}, -- Sylveon
    
    -- Gen 2
    [179] = {hp = 55, attack = 40, defense = 40, spAttack = 65, spDefense = 45, speed = 35}, -- Mareep
    [180] = {hp = 70, attack = 55, defense = 55, spAttack = 80, spDefense = 60, speed = 45}, -- Flaaffy
    [181] = {hp = 90, attack = 75, defense = 85, spAttack = 115, spDefense = 90, speed = 55}, -- Ampharos
    
    -- Additional species
    [265] = {hp = 45, attack = 45, defense = 35, spAttack = 20, spDefense = 30, speed = 20}, -- Wurmple
    [266] = {hp = 50, attack = 35, defense = 55, spAttack = 25, spDefense = 25, speed = 15}, -- Silcoon
    [268] = {hp = 50, attack = 35, defense = 55, spAttack = 25, spDefense = 25, speed = 15}, -- Cascoon
}

-- Evolution stones and items
local EVOLUTION_ITEMS = {
    ["fire_stone"] = {name = "Fire Stone", type = "stone"},
    ["water_stone"] = {name = "Water Stone", type = "stone"},
    ["thunder_stone"] = {name = "Thunder Stone", type = "stone"},
    ["leaf_stone"] = {name = "Leaf Stone", type = "stone"},
    ["moon_stone"] = {name = "Moon Stone", type = "stone"},
    ["sun_stone"] = {name = "Sun Stone", type = "stone"},
    ["shiny_stone"] = {name = "Shiny Stone", type = "stone"},
    ["dusk_stone"] = {name = "Dusk Stone", type = "stone"},
    ["dawn_stone"] = {name = "Dawn Stone", type = "stone"},
    ["ice_stone"] = {name = "Ice Stone", type = "stone"},
    ["kings_rock"] = {name = "King's Rock", type = "hold_item"},
    ["metal_coat"] = {name = "Metal Coat", type = "hold_item"},
    ["dragon_scale"] = {name = "Dragon Scale", type = "hold_item"},
    ["upgrade"] = {name = "Up-Grade", type = "hold_item"},
    ["dubious_disc"] = {name = "Dubious Disc", type = "hold_item"},
    ["prism_scale"] = {name = "Prism Scale", type = "hold_item"},
    ["reaper_cloth"] = {name = "Reaper Cloth", type = "hold_item"},
    ["electirizer"] = {name = "Electirizer", type = "hold_item"},
    ["magmarizer"] = {name = "Magmarizer", type = "hold_item"},
    ["protector"] = {name = "Protector", type = "hold_item"},
    ["oval_stone"] = {name = "Oval Stone", type = "hold_item"}
}

-- ====================================
-- EMBEDDED LOGIC TEMPLATE FUNCTIONS
-- ====================================

-- Deep copy utility
local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = deepCopy(value)
    end
    return copy
end

-- GameState integrity validation
local function validateGameState(gameState)
    if type(gameState) ~= "table" then
        return false, "GameState must be a table"
    end
    
    local requiredFields = {"playerId", "timestamp", "version"}
    for _, field in ipairs(requiredFields) do
        if not gameState[field] then
            return false, "GameState missing required field: " .. field
        end
    end
    
    if gameState.player then
        if not gameState.player.party or type(gameState.player.party) ~= "table" then
            return false, "GameState.player.party must be a table"
        end
    end
    
    if gameState.battle then
        if not gameState.battle.battleId or not gameState.battle.battleSeed then
            return false, "GameState.battle must have battleId and battleSeed"
        end
    end
    
    return true, nil
end

-- Input validation for logic process messages
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
    
    if not message.Data.gameState then
        return false, "Data.gameState is required for logic operations"
    end
    
    if not message.Data.operation or type(message.Data.operation) ~= "string" then
        return false, "Data.operation is required and must be a string"
    end
    
    local gameStateValid, gameStateError = validateGameState(message.Data.gameState)
    if not gameStateValid then
        return false, "Invalid GameState: " .. gameStateError
    end
    
    return true, nil
end

-- Rate limiting check
local function checkRateLimit(address)
    local currentTime = os.time()
    local currentMinute = math.floor(currentTime / 60)
    
    if not rateLimitCounters[address] then
        rateLimitCounters[address] = {minute = currentMinute, count = 0}
    end
    
    local counter = rateLimitCounters[address]
    
    if counter.minute ~= currentMinute then
        counter.minute = currentMinute
        counter.count = 0
    end
    
    if counter.count >= RATE_LIMIT_MAX then
        return false, "Rate limit exceeded: maximum " .. RATE_LIMIT_MAX .. " operations per minute"
    end
    
    counter.count = counter.count + 1
    return true, nil
end

-- Performance monitoring
local function startPerformanceMonitoring()
    performanceStartTime = os.clock()
end

local function endPerformanceMonitoring()
    if performanceStartTime then
        local responseTime = (os.clock() - performanceStartTime) * 1000
        performanceStartTime = nil
        return responseTime
    end
    return nil
end

-- Calculate stat with nature modifier (exact 0.9, 1.0, 1.1 values)
local function calculateStatWithNature(baseStat, natureMod)
    if natureMod == 0.9 then
        return math.floor(baseStat * 0.9)
    elseif natureMod == 1.1 then
        return math.floor(baseStat * 1.1)
    else
        return baseStat -- nature modifier is 1.0
    end
end

-- ====================================
-- EVOLUTION ENGINE CORE FUNCTIONS
-- ====================================

local EvolutionEngine = {}

-- Check if Pokemon meets evolution requirements
function EvolutionEngine.checkEvolutionRequirements(pokemon, evolutionData, evolutionContext)
    if evolutionData.type == EVOLUTION_TYPES.LEVEL then
        return pokemon.level >= evolutionData.level
        
    elseif evolutionData.type == EVOLUTION_TYPES.STONE then
        return evolutionContext.item == evolutionData.item
        
    elseif evolutionData.type == EVOLUTION_TYPES.TRADE then
        local tradeValid = evolutionContext.tradeEvolution == true
        if evolutionData.item then
            return tradeValid and evolutionContext.heldItem == evolutionData.item
        end
        return tradeValid
        
    elseif evolutionData.type == EVOLUTION_TYPES.HAPPINESS or evolutionData.type == EVOLUTION_TYPES.FRIENDSHIP then
        local happiness = pokemon.happiness or pokemon.friendship or 0
        local happinessThreshold = evolutionData.happiness or evolutionData.friendship or 220
        local timeCondition = true
        
        if evolutionData.timeOfDay then
            timeCondition = evolutionContext.timeOfDay == evolutionData.timeOfDay
        end
        
        if evolutionData.affection then
            local affection = pokemon.affection or 0
            return affection >= evolutionData.affection and timeCondition
        end
        
        return happiness >= happinessThreshold and timeCondition
        
    elseif evolutionData.type == EVOLUTION_TYPES.TIME then
        return evolutionContext.timeOfDay == evolutionData.timeOfDay
        
    elseif evolutionData.type == EVOLUTION_TYPES.LOCATION then
        return evolutionContext.location == evolutionData.location
        
    elseif evolutionData.type == EVOLUTION_TYPES.CONDITION then
        -- Custom condition checking (personality-based, stats-based, etc.)
        if evolutionData.condition == "personality_silcoon" then
            local personality = pokemon.personality or 0
            return (personality % 10) < 5
        elseif evolutionData.condition == "personality_cascoon" then
            local personality = pokemon.personality or 0
            return (personality % 10) >= 5
        end
        return evolutionContext.specialCondition == evolutionData.condition
        
    elseif evolutionData.type == EVOLUTION_TYPES.ITEM then
        return evolutionContext.usedItem == evolutionData.item
        
    elseif evolutionData.type == EVOLUTION_TYPES.MOVE then
        if evolutionData.move == "remoraid_party" then
            return evolutionContext.hasRemorkaidInParty == true
        end
        local knowsMove = false
        if pokemon.moveset then
            for _, move in ipairs(pokemon.moveset) do
                if move.moveId == evolutionData.move or move.name == evolutionData.move then
                    knowsMove = true
                    break
                end
            end
        end
        return knowsMove
        
    elseif evolutionData.type == EVOLUTION_TYPES.GENDER then
        return pokemon.gender == evolutionData.gender
        
    elseif evolutionData.type == EVOLUTION_TYPES.STATS then
        if evolutionData.statCondition == "attack_greater_defense" then
            return (pokemon.stats.attack or 0) > (pokemon.stats.defense or 0)
        elseif evolutionData.statCondition == "defense_greater_attack" then
            return (pokemon.stats.defense or 0) > (pokemon.stats.attack or 0)
        elseif evolutionData.statCondition == "attack_equals_defense" then
            return (pokemon.stats.attack or 0) == (pokemon.stats.defense or 0)
        end
        return false
        
    elseif evolutionData.type == EVOLUTION_TYPES.WEATHER then
        return evolutionContext.weather == evolutionData.weather
    end
    
    return false
end

-- Validate evolution data structure
function EvolutionEngine.validateEvolutionData(evolutionData)
    if type(evolutionData) ~= "table" then
        return false, "Evolution data must be a table"
    end
    
    if not evolutionData.toSpecies or type(evolutionData.toSpecies) ~= "number" then
        return false, "Evolution data must have valid toSpecies (number)"
    end
    
    if not evolutionData.type or not EVOLUTION_TYPES[evolutionData.type] then
        return false, "Evolution data must have valid type"
    end
    
    -- Type-specific validations
    if evolutionData.type == EVOLUTION_TYPES.LEVEL then
        if not evolutionData.level or type(evolutionData.level) ~= "number" or evolutionData.level < 1 then
            return false, "Level evolution must have valid level (number >= 1)"
        end
    elseif evolutionData.type == EVOLUTION_TYPES.STONE or evolutionData.type == EVOLUTION_TYPES.ITEM then
        if not evolutionData.item or type(evolutionData.item) ~= "string" then
            return false, "Stone/Item evolution must have valid item (string)"
        end
    elseif evolutionData.type == EVOLUTION_TYPES.FRIENDSHIP or evolutionData.type == EVOLUTION_TYPES.HAPPINESS then
        if evolutionData.friendship and type(evolutionData.friendship) ~= "number" then
            return false, "Friendship value must be a number"
        end
        if evolutionData.happiness and type(evolutionData.happiness) ~= "number" then
            return false, "Happiness value must be a number"
        end
    end
    
    return true, nil
end

-- Calculate evolved Pokemon stats
function EvolutionEngine.calculateEvolvedStats(pokemon, newSpeciesId)
    local newBaseStats = SPECIES_BASE_STATS[newSpeciesId]
    if not newBaseStats then
        error("Missing base stats for species " .. newSpeciesId)
    end
    
    local level = pokemon.level
    local ivs = pokemon.ivs or {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0}
    local evs = pokemon.evs or {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0}
    local nature = pokemon.nature or "hardy"
    
    -- Nature modifiers (comprehensive list)
    local natureModifiers = {
        hardy = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        lonely = {attack = 1.1, defense = 0.9, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        brave = {attack = 1.1, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 0.9},
        adamant = {attack = 1.1, defense = 1.0, spAttack = 0.9, spDefense = 1.0, speed = 1.0},
        naughty = {attack = 1.1, defense = 1.0, spAttack = 1.0, spDefense = 0.9, speed = 1.0},
        bold = {attack = 0.9, defense = 1.1, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        docile = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        relaxed = {attack = 1.0, defense = 1.1, spAttack = 1.0, spDefense = 1.0, speed = 0.9},
        impish = {attack = 1.0, defense = 1.1, spAttack = 0.9, spDefense = 1.0, speed = 1.0},
        lax = {attack = 1.0, defense = 1.1, spAttack = 1.0, spDefense = 0.9, speed = 1.0},
        timid = {attack = 0.9, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.1},
        hasty = {attack = 1.0, defense = 0.9, spAttack = 1.0, spDefense = 1.0, speed = 1.1},
        serious = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        jolly = {attack = 1.0, defense = 1.0, spAttack = 0.9, spDefense = 1.0, speed = 1.1},
        naive = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 0.9, speed = 1.1},
        modest = {attack = 0.9, defense = 1.0, spAttack = 1.1, spDefense = 1.0, speed = 1.0},
        mild = {attack = 1.0, defense = 0.9, spAttack = 1.1, spDefense = 1.0, speed = 1.0},
        bashful = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        rash = {attack = 1.0, defense = 1.0, spAttack = 1.1, spDefense = 0.9, speed = 1.0},
        quiet = {attack = 1.0, defense = 1.0, spAttack = 1.1, spDefense = 1.0, speed = 0.9},
        calm = {attack = 0.9, defense = 1.0, spAttack = 1.0, spDefense = 1.1, speed = 1.0},
        gentle = {attack = 1.0, defense = 0.9, spAttack = 1.0, spDefense = 1.1, speed = 1.0},
        quirky = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        sassy = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.1, speed = 0.9},
        careful = {attack = 1.0, defense = 1.0, spAttack = 0.9, spDefense = 1.1, speed = 1.0}
    }
    
    local natureStats = natureModifiers[nature] or natureModifiers.hardy
    
    -- Calculate new stats using Pokemon formula with EVs
    local newStats = {}
    
    -- HP calculation: floor(((2 * base + iv + floor(ev/4)) * level / 100) + level + 10)
    newStats.hp = math.floor(((2 * newBaseStats.hp + ivs.hp + math.floor(evs.hp / 4)) * level / 100) + level + 10)
    
    -- Other stats: floor((floor(((2 * base + iv + floor(ev/4)) * level / 100) + 5) * nature))
    newStats.attack = calculateStatWithNature(
        math.floor(((2 * newBaseStats.attack + ivs.attack + math.floor(evs.attack / 4)) * level / 100) + 5),
        natureStats.attack
    )
    newStats.defense = calculateStatWithNature(
        math.floor(((2 * newBaseStats.defense + ivs.defense + math.floor(evs.defense / 4)) * level / 100) + 5),
        natureStats.defense
    )
    newStats.spAttack = calculateStatWithNature(
        math.floor(((2 * newBaseStats.spAttack + ivs.spAttack + math.floor(evs.spAttack / 4)) * level / 100) + 5),
        natureStats.spAttack
    )
    newStats.spDefense = calculateStatWithNature(
        math.floor(((2 * newBaseStats.spDefense + ivs.spDefense + math.floor(evs.spDefense / 4)) * level / 100) + 5),
        natureStats.spDefense
    )
    newStats.speed = calculateStatWithNature(
        math.floor(((2 * newBaseStats.speed + ivs.speed + math.floor(evs.speed / 4)) * level / 100) + 5),
        natureStats.speed
    )
    
    return newStats
end

-- Process Pokemon evolution
function EvolutionEngine.evolvePokemon(pokemon, targetSpeciesId, evolutionContext)
    local evolvedPokemon = deepCopy(pokemon)
    
    -- Update species
    evolvedPokemon.speciesId = targetSpeciesId
    
    -- Recalculate stats with new base stats
    local newStats = EvolutionEngine.calculateEvolvedStats(pokemon, targetSpeciesId)
    
    -- Update stats while preserving HP ratio
    local hpRatio = pokemon.hp / pokemon.maxHp
    evolvedPokemon.stats = newStats
    evolvedPokemon.maxHp = newStats.hp
    evolvedPokemon.hp = math.floor(newStats.hp * hpRatio)
    
    -- Update evolution metadata
    evolvedPokemon.evolutionLevel = pokemon.level
    evolvedPokemon.evolutionMethod = evolutionContext.method or "unknown"
    evolvedPokemon.evolvedAt = os.time()
    evolvedPokemon.preEvolutionSpecies = pokemon.speciesId
    
    -- Preserve important data
    evolvedPokemon.exp = pokemon.exp
    evolvedPokemon.moveset = pokemon.moveset or {}
    evolvedPokemon.nature = pokemon.nature
    evolvedPokemon.ivs = pokemon.ivs
    evolvedPokemon.evs = pokemon.evs or {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0}
    evolvedPokemon.originalTrainer = pokemon.originalTrainer
    evolvedPokemon.personality = pokemon.personality
    evolvedPokemon.pokeball = pokemon.pokeball
    evolvedPokemon.friendship = pokemon.friendship or pokemon.happiness
    evolvedPokemon.ability = pokemon.ability -- Note: might change based on species
    
    -- Handle potential ability changes (simplified)
    if evolutionContext.newAbility then
        evolvedPokemon.ability = evolutionContext.newAbility
    end
    
    return evolvedPokemon
end

-- Get available evolutions for a Pokemon
function EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
    local evolutions = EVOLUTION_CHAINS[pokemon.speciesId] or {}
    local availableEvolutions = {}
    
    for _, evolutionData in ipairs(evolutions) do
        local validData, dataError = EvolutionEngine.validateEvolutionData(evolutionData)
        if validData and EvolutionEngine.checkEvolutionRequirements(pokemon, evolutionData, evolutionContext) then
            table.insert(availableEvolutions, {
                toSpecies = evolutionData.toSpecies,
                type = evolutionData.type,
                requirements = evolutionData,
                canEvolve = true
            })
        elseif validData then
            table.insert(availableEvolutions, {
                toSpecies = evolutionData.toSpecies,
                type = evolutionData.type,
                requirements = evolutionData,
                canEvolve = false,
                reason = "Requirements not met"
            })
        end
    end
    
    return availableEvolutions
end

-- Check evolution conditions comprehensively
function EvolutionEngine.checkEvolutionConditions(pokemon, evolutionContext)
    local availableEvolutions = EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
    local conditions = {
        canEvolve = #availableEvolutions > 0,
        evolutionCount = #availableEvolutions,
        conditions = {}
    }
    
    -- Analyze each possible evolution path
    for _, evolution in ipairs(availableEvolutions) do
        local conditionDetail = {
            targetSpecies = evolution.toSpecies,
            type = evolution.type,
            canEvolve = evolution.canEvolve,
            requirements = {}
        }
        
        local req = evolution.requirements
        if req.level then
            conditionDetail.requirements.level = {
                required = req.level,
                current = pokemon.level,
                met = pokemon.level >= req.level
            }
        end
        
        if req.item then
            conditionDetail.requirements.item = {
                required = req.item,
                available = evolutionContext.item == req.item,
                met = evolutionContext.item == req.item
            }
        end
        
        if req.friendship or req.happiness then
            local threshold = req.friendship or req.happiness or 220
            local current = pokemon.friendship or pokemon.happiness or 0
            conditionDetail.requirements.friendship = {
                required = threshold,
                current = current,
                met = current >= threshold
            }
        end
        
        if req.timeOfDay then
            conditionDetail.requirements.timeOfDay = {
                required = req.timeOfDay,
                current = evolutionContext.timeOfDay,
                met = evolutionContext.timeOfDay == req.timeOfDay
            }
        end
        
        table.insert(conditions.conditions, conditionDetail)
    end
    
    return conditions
end

-- Process evolution attempt
function EvolutionEngine.processEvolution(gameState, pokemonIndex, targetSpeciesId, evolutionContext)
    local newGameState = deepCopy(gameState)
    
    -- Get Pokemon from party
    if not newGameState.player.party[pokemonIndex] then
        error("Pokemon not found at index " .. pokemonIndex)
    end
    
    local pokemon = newGameState.player.party[pokemonIndex]
    
    -- Validate evolution is possible
    local availableEvolutions = EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
    local validEvolution = false
    local evolutionData = nil
    
    for _, evolution in ipairs(availableEvolutions) do
        if evolution.toSpecies == targetSpeciesId and evolution.canEvolve then
            validEvolution = true
            evolutionData = evolution.requirements
            break
        end
    end
    
    if not validEvolution then
        error("Pokemon cannot evolve to species " .. targetSpeciesId .. " under current conditions")
    end
    
    -- Perform evolution
    local evolvedPokemon = EvolutionEngine.evolvePokemon(pokemon, targetSpeciesId, evolutionContext)
    newGameState.player.party[pokemonIndex] = evolvedPokemon
    
    return {
        gameState = newGameState,
        evolutionSuccess = true,
        originalSpecies = pokemon.speciesId,
        newSpecies = targetSpeciesId,
        evolvedPokemon = evolvedPokemon,
        evolutionData = evolutionData
    }
end

-- Handle form changes (alternate forms, regional variants)
function EvolutionEngine.processFormChange(gameState, pokemonIndex, newForm, formContext)
    local newGameState = deepCopy(gameState)
    
    if not newGameState.player.party[pokemonIndex] then
        error("Pokemon not found at index " .. pokemonIndex)
    end
    
    local pokemon = newGameState.player.party[pokemonIndex]
    local changedPokemon = deepCopy(pokemon)
    
    -- Update form data
    changedPokemon.form = newForm
    changedPokemon.formChangeMethod = formContext.method or "unknown"
    changedPokemon.formChangedAt = os.time()
    changedPokemon.previousForm = pokemon.form
    
    -- Form changes might affect stats, types, abilities
    if formContext.statChanges then
        for stat, value in pairs(formContext.statChanges) do
            if changedPokemon.stats[stat] then
                changedPokemon.stats[stat] = value
            end
        end
    end
    
    if formContext.typeChanges then
        changedPokemon.type1 = formContext.typeChanges.type1 or changedPokemon.type1
        changedPokemon.type2 = formContext.typeChanges.type2 or changedPokemon.type2
    end
    
    if formContext.abilityChange then
        changedPokemon.ability = formContext.abilityChange
    end
    
    newGameState.player.party[pokemonIndex] = changedPokemon
    
    return {
        gameState = newGameState,
        formChangeSuccess = true,
        originalForm = pokemon.form,
        newForm = newForm,
        changedPokemon = changedPokemon
    }
end

-- Main logic handler for evolution operations
function EvolutionEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "processEvolution" then
        local pokemonIndex = parameters.pokemonIndex
        local targetSpeciesId = parameters.targetSpeciesId
        local evolutionContext = parameters.evolutionContext or {}
        
        if not pokemonIndex or not targetSpeciesId then
            error("pokemonIndex and targetSpeciesId parameters are required for processEvolution operation")
        end
        
        return EvolutionEngine.processEvolution(gameState, pokemonIndex, targetSpeciesId, evolutionContext)
        
    elseif operation == "checkEvolutionConditions" then
        local pokemonIndex = parameters.pokemonIndex
        local evolutionContext = parameters.evolutionContext or {}
        
        if not pokemonIndex then
            error("pokemonIndex parameter is required for checkEvolutionConditions operation")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local conditions = EvolutionEngine.checkEvolutionConditions(pokemon, evolutionContext)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            evolutionConditions = conditions
        }
        
    elseif operation == "getAvailableEvolutions" then
        local pokemonIndex = parameters.pokemonIndex
        local evolutionContext = parameters.evolutionContext or {}
        
        if not pokemonIndex then
            error("pokemonIndex parameter is required for getAvailableEvolutions operation")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local availableEvolutions = EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            availableEvolutions = availableEvolutions
        }
        
    elseif operation == "processFormChange" then
        local pokemonIndex = parameters.pokemonIndex
        local newForm = parameters.newForm
        local formContext = parameters.formContext or {}
        
        if not pokemonIndex or not newForm then
            error("pokemonIndex and newForm parameters are required for processFormChange operation")
        end
        
        return EvolutionEngine.processFormChange(gameState, pokemonIndex, newForm, formContext)
        
    elseif operation == "validateEvolutionData" then
        local evolutionData = parameters.evolutionData
        
        if not evolutionData then
            error("evolutionData parameter is required for validateEvolutionData operation")
        end
        
        local isValid, validationError = EvolutionEngine.validateEvolutionData(evolutionData)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            isValid = isValid,
            validationError = validationError,
            evolutionData = evolutionData
        }
        
    else
        error("Unknown evolution engine operation: " .. operation)
    end
end

-- ====================================
-- MESSAGE PROCESSING LOGIC
-- ====================================

local function handleMessage(message)
    startPerformanceMonitoring()
    
    local isValid, validationError = validateInput(message)
    if not isValid then
        return {
            Action = "SaveState",
            Error = validationError,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
    
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
    if not rateLimitOk then
        return {
            Action = "SaveState",
            Error = rateLimitError,
            GameState = message.Data.gameState,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
    
    local originalGameState = message.Data.gameState
    local operation = message.Data.operation
    local parameters = message.Data.parameters or {}
    
    local success, result = pcall(function()
        return EvolutionEngine.handleLogicOperation(originalGameState, operation, parameters, nil)
    end)
    
    local responseTime = endPerformanceMonitoring()
    if responseTime and responseTime > LOGIC_OPERATION_TIMEOUT then
        return {
            Action = "SaveState",
            Error = "Logic operation exceeded " .. LOGIC_OPERATION_TIMEOUT .. "ms timeout (took " .. responseTime .. "ms)",
            GameState = originalGameState,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
    
    if success then
        if result and result.gameState then
            result.gameState.timestamp = os.time()
            if originalGameState.version then
                result.gameState.version = (originalGameState.version or 0) + 1
            end
        end
        
        return {
            Action = "SaveState",
            Data = {
                gameState = result and result.gameState or originalGameState,
                result = result
            },
            Timestamp = os.time(),
            ProcessId = PROCESS_ID
        }
    else
        return {
            Action = "SaveState",
            Error = "Logic operation failed: " .. tostring(result),
            GameState = originalGameState,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
end

-- ====================================
-- AO MESSAGE HANDLERS (ADP v1.0 COMPLIANT)
-- ====================================

-- Process Logic Handler (main entry point)
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local response = handleMessage(msg)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data,
            Error = response.Error,
            GameState = response.GameState,
            ProcessId = response.ProcessId,
            Timestamp = tostring(response.Timestamp)
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                processId = ao.id,
                processType = "logic",
                status = "healthy",
                timestamp = os.time(),
                operations = {
                    "processEvolution",
                    "checkEvolutionConditions",
                    "getAvailableEvolutions",
                    "processFormChange",
                    "validateEvolutionData"
                }
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

-- ADP v1.0 Compliant Info Handler (REQUIRED)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = "Evolution Engine",
                    version = PROCESS_VERSION,
                    adpVersion = ADP_VERSION,
                    processId = ao.id,
                    capabilities = {
                        "processEvolution",
                        "checkEvolutionConditions", 
                        "getAvailableEvolutions",
                        "processFormChange",
                        "validateEvolutionData"
                    },
                    messageSchemas = {
                        ProcessLogic = {
                            required = {"Action", "Data", "Timestamp"},
                            properties = {
                                Action = {type = "string", value = "ProcessLogic"},
                                Data = {
                                    type = "object",
                                    required = {"gameState", "operation"},
                                    properties = {
                                        gameState = {type = "object", description = "Current game state"},
                                        operation = {type = "string", enum = {"processEvolution", "checkEvolutionConditions", "getAvailableEvolutions", "processFormChange", "validateEvolutionData"}},
                                        parameters = {type = "object", description = "Operation-specific parameters"}
                                    }
                                },
                                Timestamp = {type = "number"}
                            }
                        },
                        HealthCheck = {
                            required = {"Action"},
                            properties = {
                                Action = {type = "string", value = "HealthCheck"}
                            }
                        },
                        Info = {
                            required = {"Action"},
                            properties = {
                                Action = {type = "string", value = "Info"}
                            }
                        }
                    },
                    evolutionTypes = EVOLUTION_TYPES,
                    supportedSpecies = (function()
                        local count = 0
                        for _ in pairs(EVOLUTION_CHAINS) do count = count + 1 end
                        return count
                    end)(),
                    features = {
                        "Level-based evolution",
                        "Stone evolution", 
                        "Trade evolution",
                        "Friendship/Happiness evolution",
                        "Time-based evolution",
                        "Location-based evolution",
                        "Item-based evolution",
                        "Move-based evolution",
                        "Gender-based evolution",
                        "Stats-based evolution",
                        "Weather-based evolution",
                        "Form changes",
                        "Stat recalculation",
                        "Nature considerations",
                        "EV/IV preservation",
                        "Comprehensive validation"
                    }
                },
                handlers = {"process-logic", "health-check", "info"},
                documentation = {
                    adpCompliance = ADP_VERSION,
                    selfDocumenting = true,
                    description = "Advanced Pokemon evolution engine with comprehensive evolution type support, stat recalculation, and form change management for all Pokemon generations",
                    usage = {
                        processEvolution = "Evolve a Pokemon: {pokemonIndex, targetSpeciesId, evolutionContext}",
                        checkEvolutionConditions = "Check evolution requirements: {pokemonIndex, evolutionContext}",
                        getAvailableEvolutions = "Get possible evolutions: {pokemonIndex, evolutionContext}",
                        processFormChange = "Change Pokemon form: {pokemonIndex, newForm, formContext}",
                        validateEvolutionData = "Validate evolution data structure: {evolutionData}"
                    }
                }
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

-- Process initialization complete
-- Evolution Engine is now ready to handle AO messages
-- All functions and data are embedded in the global scope for AO runtime