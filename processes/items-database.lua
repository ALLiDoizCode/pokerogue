-- ============================================================================
-- Items Database Process - Item data including berries, held items, and consumables with sub-100ms performance
-- AO Process Implementation for PokéRogue
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "items-database" }

-- Embedded template functions
local RATE_LIMIT_MAX = 100
local rateLimitCounters = {}
local function validateInput(message)
    if type(message) ~= "table" then return false, "Message must be a table" end
    if not message.Action or type(message.Action) ~= "string" then return false, "Action field is required" end
    if not message.Data or type(message.Data) ~= "table" then return false, "Data field is required" end
    if not message.Timestamp or type(message.Timestamp) ~= "number" then return false, "Timestamp field is required" end
    return true, nil
end
local function checkRateLimit(address)
    local currentTime = os.time()
    local currentMinute = math.floor(currentTime / 60)
    if not rateLimitCounters[address] then rateLimitCounters[address] = { minute = currentMinute, count = 0 } end
    local counter = rateLimitCounters[address]
    if counter.minute ~= currentMinute then counter.minute = currentMinute; counter.count = 0 end
    if counter.count >= RATE_LIMIT_MAX then return false, "Rate limit exceeded" end
    counter.count = counter.count + 1
    return true, nil
end
local function createSuccessResponse(data, processId)
    return { Action = "SaveState", Data = data, Timestamp = os.time(), ProcessId = processId or ao.id }
end
local function createErrorResponse(errorMessage, processId)
    return { Action = "SaveState", Error = errorMessage, ProcessId = processId or ao.id, Timestamp = os.time() }
end
local function handleMessage(message, processId, queryHandler)
    local isValid, validationError = validateInput(message)
    if not isValid then return createErrorResponse(validationError, processId) end
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
    if not rateLimitOk then return createErrorResponse(rateLimitError, processId) end
    local success, result = pcall(function() return queryHandler(message) end)
    if success then return createSuccessResponse(result, processId) else return createErrorResponse("Query processing failed: " .. tostring(result), processId) end
end
local QueryOptimizations = { createIndex = function(dataTable, keyField) local index = {} for i, item in ipairs(dataTable) do if item[keyField] then index[item[keyField]] = item end end return index end }

local ItemsDatabase = {}
local PROCESS_ID = ao.id

-- Item Constants
local ITEM = {
    NONE = 0,
    MASTER_BALL = 1,
    ULTRA_BALL = 2,
    GREAT_BALL = 3,
    POKE_BALL = 4,
    SAFARI_BALL = 5,
    NET_BALL = 6,
    DIVE_BALL = 7,
    NEST_BALL = 8,
    REPEAT_BALL = 9,
    TIMER_BALL = 10,
    LUXURY_BALL = 11,
    PREMIER_BALL = 12,
    DUSK_BALL = 13,
    HEAL_BALL = 14,
    QUICK_BALL = 15,
    CHERISH_BALL = 16,
    POTION = 17,
    ANTIDOTE = 18,
    BURN_HEAL = 19,
    ICE_HEAL = 20,
    AWAKENING = 21,
    PARALYZE_HEAL = 22,
    FULL_RESTORE = 23,
    MAX_POTION = 24,
    HYPER_POTION = 25,
    SUPER_POTION = 26,
    FULL_HEAL = 27,
    REVIVE = 28,
    MAX_REVIVE = 29,
    FRESH_WATER = 30,
    SODA_POP = 31,
    LEMONADE = 32,
    MOOMOO_MILK = 33,
    ENERGY_POWDER = 34,
    ENERGY_ROOT = 35,
    HEAL_POWDER = 36,
    REVIVAL_HERB = 37,
    ETHER = 38,
    MAX_ETHER = 39,
    ELIXIR = 40,
    MAX_ELIXIR = 41,
    LAVA_COOKIE = 42,
    BERRY_JUICE = 43,
    SACRED_ASH = 44,
    HP_UP = 45,
    PROTEIN = 46,
    IRON = 47,
    CARBOS = 48,
    CALCIUM = 49,
    RARE_CANDY = 50,
    PP_UP = 51,
    ZINC = 52,
    PP_MAX = 53,
    OLD_GATEAU = 54,
    GUARD_SPEC = 55,
    DIRE_HIT = 56,
    X_ATTACK = 57,
    X_DEFENSE = 58,
    X_SPEED = 59,
    X_ACCURACY = 60,
    X_SP_ATK = 61,
    X_SP_DEF = 62,
    POKE_DOLL = 63,
    FLUFFY_TAIL = 64,
    BLUE_FLUTE = 65,
    YELLOW_FLUTE = 66,
    RED_FLUTE = 67,
    BLACK_FLUTE = 68,
    WHITE_FLUTE = 69,
    SHOAL_SALT = 70,
    SHOAL_SHELL = 71,
    RED_SHARD = 72,
    BLUE_SHARD = 73,
    YELLOW_SHARD = 74,
    GREEN_SHARD = 75,
    SUPER_REPEL = 76,
    MAX_REPEL = 77,
    ESCAPE_ROPE = 78,
    REPEL = 79,
    SUN_STONE = 80,
    MOON_STONE = 81,
    FIRE_STONE = 82,
    THUNDER_STONE = 83,
    WATER_STONE = 84,
    LEAF_STONE = 85,
    TINY_MUSHROOM = 86,
    BIG_MUSHROOM = 87,
    PEARL = 88,
    BIG_PEARL = 89,
    STARDUST = 90,
    STAR_PIECE = 91,
    NUGGET = 92,
    HEART_SCALE = 93,
    HONEY = 94,
    GROWTH_MULCH = 95,
    DAMP_MULCH = 96,
    STABLE_MULCH = 97,
    GOOEY_MULCH = 98,
    ROOT_FOSSIL = 99,
    CLAW_FOSSIL = 100,
    HELIX_FOSSIL = 101,
    DOME_FOSSIL = 102,
    OLD_AMBER = 103,
    ARMOR_FOSSIL = 104,
    SKULL_FOSSIL = 105,
    RARE_BONE = 106,
    SHINY_STONE = 107,
    DUSK_STONE = 108,
    DAWN_STONE = 109,
    OVAL_STONE = 110,
    ODD_KEYSTONE = 111,
    GRISEOUS_ORB = 112,
    -- Berries start at 149
    CHERI_BERRY = 149,
    CHESTO_BERRY = 150,
    PECHA_BERRY = 151,
    RAWST_BERRY = 152,
    ASPEAR_BERRY = 153,
    LEPPA_BERRY = 154,
    ORAN_BERRY = 155,
    PERSIM_BERRY = 156,
    LUM_BERRY = 157,
    SITRUS_BERRY = 158,
    FIGY_BERRY = 159,
    WIKI_BERRY = 160,
    MAGO_BERRY = 161,
    AGUAV_BERRY = 162,
    IAPAPA_BERRY = 163,
    RAZZ_BERRY = 164,
    BLUK_BERRY = 165,
    NANAB_BERRY = 166,
    WEPEAR_BERRY = 167,
    PINAP_BERRY = 168,
    POMEG_BERRY = 169,
    KELPSY_BERRY = 170,
    QUALOT_BERRY = 171,
    HONDEW_BERRY = 172,
    GREPA_BERRY = 173,
    TAMATO_BERRY = 174,
    CORNN_BERRY = 175,
    MAGOST_BERRY = 176,
    RABUTA_BERRY = 177,
    NOMEL_BERRY = 178,
    SPELON_BERRY = 179,
    PAMTRE_BERRY = 180,
    WATMEL_BERRY = 181,
    DURIN_BERRY = 182,
    BELUE_BERRY = 183,
    LIECHI_BERRY = 184,
    GANLON_BERRY = 185,
    SALAC_BERRY = 186,
    PETAYA_BERRY = 187,
    APICOT_BERRY = 188,
    LANSAT_BERRY = 189,
    STARF_BERRY = 190,
    ENIGMA_BERRY = 191,
    MICLE_BERRY = 192,
    CUSTAP_BERRY = 193,
    JABOCA_BERRY = 194,
    ROWAP_BERRY = 195
}

local ITEM_CATEGORY = {
    POKEBALL = 0,
    HEALING = 1,
    STATUS_CURE = 2,
    REVIVAL = 3,
    STAT_BOOST = 4,
    EVOLUTION = 5,
    BERRY = 6,
    HELD_ITEM = 7,
    KEY_ITEM = 8,
    BATTLE_ITEM = 9,
    VALUABLE = 10,
    FOSSIL = 11
}

-- Embedded Items Database (Optimized for size and performance)
local ItemsDB = {
    -- Pokeballs
    [ITEM.MASTER_BALL] = {
        id = 1, n = "Master Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Catches any Pokemon without fail", val = 0, stack = 999
    },
    [ITEM.ULTRA_BALL] = {
        id = 2, n = "Ultra Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "2x catch rate multiplier", val = 1200, stack = 999
    },
    [ITEM.GREAT_BALL] = {
        id = 3, n = "Great Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "1.5x catch rate multiplier", val = 600, stack = 999
    },
    [ITEM.POKE_BALL] = {
        id = 4, n = "Poke Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Standard catch rate", val = 200, stack = 999
    },
    [ITEM.SAFARI_BALL] = {
        id = 5, n = "Safari Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Special ball for Safari Zone", val = 0, stack = 30
    },
    [ITEM.NET_BALL] = {
        id = 6, n = "Net Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "3x rate on Bug/Water types", val = 1000, stack = 999
    },
    [ITEM.DIVE_BALL] = {
        id = 7, n = "Dive Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "3.5x rate when underwater", val = 1000, stack = 999
    },
    [ITEM.NEST_BALL] = {
        id = 8, n = "Nest Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Better on lower level Pokemon", val = 1000, stack = 999
    },
    [ITEM.REPEAT_BALL] = {
        id = 9, n = "Repeat Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "3x rate on owned species", val = 1000, stack = 999
    },
    [ITEM.TIMER_BALL] = {
        id = 10, n = "Timer Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Rate increases with turn count", val = 1000, stack = 999
    },
    [ITEM.LUXURY_BALL] = {
        id = 11, n = "Luxury Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Pokemon becomes more friendly", val = 1000, stack = 999
    },
    [ITEM.PREMIER_BALL] = {
        id = 12, n = "Premier Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Same as Poke Ball but commemorative", val = 20, stack = 999
    },
    [ITEM.DUSK_BALL] = {
        id = 13, n = "Dusk Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "3x rate in caves/at night", val = 1000, stack = 999
    },
    [ITEM.HEAL_BALL] = {
        id = 14, n = "Heal Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Fully heals caught Pokemon", val = 300, stack = 999
    },
    [ITEM.QUICK_BALL] = {
        id = 15, n = "Quick Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "5x rate on first turn", val = 1000, stack = 999
    },
    [ITEM.CHERISH_BALL] = {
        id = 16, n = "Cherish Ball", cat = ITEM_CATEGORY.POKEBALL,
        eff = "Special ball for events", val = 200, stack = 999
    },

    -- Healing Items
    [ITEM.POTION] = {
        id = 17, n = "Potion", cat = ITEM_CATEGORY.HEALING,
        eff = "Restores 20 HP", val = 300, stack = 999, heal = 20
    },
    [ITEM.SUPER_POTION] = {
        id = 26, n = "Super Potion", cat = ITEM_CATEGORY.HEALING,
        eff = "Restores 50 HP", val = 700, stack = 999, heal = 50
    },
    [ITEM.HYPER_POTION] = {
        id = 25, n = "Hyper Potion", cat = ITEM_CATEGORY.HEALING,
        eff = "Restores 200 HP", val = 1200, stack = 999, heal = 200
    },
    [ITEM.MAX_POTION] = {
        id = 24, n = "Max Potion", cat = ITEM_CATEGORY.HEALING,
        eff = "Restores all HP", val = 2500, stack = 999, heal = 999
    },
    [ITEM.FULL_RESTORE] = {
        id = 23, n = "Full Restore", cat = ITEM_CATEGORY.HEALING,
        eff = "Restores all HP and status", val = 3000, stack = 999, heal = 999
    },

    -- Status Cure Items
    [ITEM.ANTIDOTE] = {
        id = 18, n = "Antidote", cat = ITEM_CATEGORY.STATUS_CURE,
        eff = "Cures poison", val = 100, stack = 999, cures = {"poison"}
    },
    [ITEM.BURN_HEAL] = {
        id = 19, n = "Burn Heal", cat = ITEM_CATEGORY.STATUS_CURE,
        eff = "Cures burn", val = 250, stack = 999, cures = {"burn"}
    },
    [ITEM.ICE_HEAL] = {
        id = 20, n = "Ice Heal", cat = ITEM_CATEGORY.STATUS_CURE,
        eff = "Cures freeze", val = 250, stack = 999, cures = {"freeze"}
    },
    [ITEM.AWAKENING] = {
        id = 21, n = "Awakening", cat = ITEM_CATEGORY.STATUS_CURE,
        eff = "Cures sleep", val = 250, stack = 999, cures = {"sleep"}
    },
    [ITEM.PARALYZE_HEAL] = {
        id = 22, n = "Paralyze Heal", cat = ITEM_CATEGORY.STATUS_CURE,
        eff = "Cures paralysis", val = 200, stack = 999, cures = {"paralysis"}
    },
    [ITEM.FULL_HEAL] = {
        id = 27, n = "Full Heal", cat = ITEM_CATEGORY.STATUS_CURE,
        eff = "Cures all status conditions", val = 600, stack = 999, cures = {"all"}
    },

    -- Revival Items
    [ITEM.REVIVE] = {
        id = 28, n = "Revive", cat = ITEM_CATEGORY.REVIVAL,
        eff = "Revives with 50% HP", val = 1500, stack = 999, revive = 0.5
    },
    [ITEM.MAX_REVIVE] = {
        id = 29, n = "Max Revive", cat = ITEM_CATEGORY.REVIVAL,
        eff = "Revives with full HP", val = 4000, stack = 999, revive = 1.0
    },
    [ITEM.SACRED_ASH] = {
        id = 44, n = "Sacred Ash", cat = ITEM_CATEGORY.REVIVAL,
        eff = "Revives entire party to full HP", val = 200, stack = 999, revive = 1.0
    },

    -- Evolution Stones
    [ITEM.FIRE_STONE] = {
        id = 82, n = "Fire Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Fire-type Pokemon", val = 2100, stack = 999
    },
    [ITEM.WATER_STONE] = {
        id = 84, n = "Water Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Water-type Pokemon", val = 2100, stack = 999
    },
    [ITEM.THUNDER_STONE] = {
        id = 83, n = "Thunder Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Electric-type Pokemon", val = 2100, stack = 999
    },
    [ITEM.LEAF_STONE] = {
        id = 85, n = "Leaf Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Grass-type Pokemon", val = 2100, stack = 999
    },
    [ITEM.MOON_STONE] = {
        id = 81, n = "Moon Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Pokemon", val = 2100, stack = 999
    },
    [ITEM.SUN_STONE] = {
        id = 80, n = "Sun Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Pokemon", val = 2100, stack = 999
    },
    [ITEM.SHINY_STONE] = {
        id = 107, n = "Shiny Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Pokemon", val = 2100, stack = 999
    },
    [ITEM.DUSK_STONE] = {
        id = 108, n = "Dusk Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Pokemon", val = 2100, stack = 999
    },
    [ITEM.DAWN_STONE] = {
        id = 109, n = "Dawn Stone", cat = ITEM_CATEGORY.EVOLUTION,
        eff = "Evolves certain Pokemon", val = 2100, stack = 999
    },

    -- Berries (Status Cure)
    [ITEM.CHERI_BERRY] = {
        id = 149, n = "Cheri Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures paralysis when held", val = 20, stack = 999, 
        cures = {"paralysis"}, berry = true, natural = true
    },
    [ITEM.CHESTO_BERRY] = {
        id = 150, n = "Chesto Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures sleep when held", val = 20, stack = 999,
        cures = {"sleep"}, berry = true, natural = true
    },
    [ITEM.PECHA_BERRY] = {
        id = 151, n = "Pecha Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures poison when held", val = 20, stack = 999,
        cures = {"poison"}, berry = true, natural = true
    },
    [ITEM.RAWST_BERRY] = {
        id = 152, n = "Rawst Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures burn when held", val = 20, stack = 999,
        cures = {"burn"}, berry = true, natural = true
    },
    [ITEM.ASPEAR_BERRY] = {
        id = 153, n = "Aspear Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures freeze when held", val = 20, stack = 999,
        cures = {"freeze"}, berry = true, natural = true
    },
    [ITEM.LEPPA_BERRY] = {
        id = 154, n = "Leppa Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores 10 PP to a move", val = 20, stack = 999,
        berry = true, natural = true, ppRestore = 10
    },
    [ITEM.ORAN_BERRY] = {
        id = 155, n = "Oran Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores 10 HP when held", val = 20, stack = 999,
        berry = true, natural = true, heal = 10
    },
    [ITEM.PERSIM_BERRY] = {
        id = 156, n = "Persim Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures confusion when held", val = 20, stack = 999,
        cures = {"confusion"}, berry = true, natural = true
    },
    [ITEM.LUM_BERRY] = {
        id = 157, n = "Lum Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Cures all status conditions", val = 20, stack = 999,
        cures = {"all"}, berry = true, natural = true
    },
    [ITEM.SITRUS_BERRY] = {
        id = 158, n = "Sitrus Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores 25% HP when held", val = 20, stack = 999,
        berry = true, natural = true, healPercent = 0.25
    },

    -- Stat Boost Berries (Pinch berries)
    [ITEM.FIGY_BERRY] = {
        id = 159, n = "Figy Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores HP if HP low, confuses if disliked", val = 20, stack = 999,
        berry = true, natural = true, pinch = true, flavor = "spicy"
    },
    [ITEM.WIKI_BERRY] = {
        id = 160, n = "Wiki Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores HP if HP low, confuses if disliked", val = 20, stack = 999,
        berry = true, natural = true, pinch = true, flavor = "dry"
    },
    [ITEM.MAGO_BERRY] = {
        id = 161, n = "Mago Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores HP if HP low, confuses if disliked", val = 20, stack = 999,
        berry = true, natural = true, pinch = true, flavor = "sweet"
    },
    [ITEM.AGUAV_BERRY] = {
        id = 162, n = "Aguav Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores HP if HP low, confuses if disliked", val = 20, stack = 999,
        berry = true, natural = true, pinch = true, flavor = "bitter"
    },
    [ITEM.IAPAPA_BERRY] = {
        id = 163, n = "Iapapa Berry", cat = ITEM_CATEGORY.BERRY,
        eff = "Restores HP if HP low, confuses if disliked", val = 20, stack = 999,
        berry = true, natural = true, pinch = true, flavor = "sour"
    },

    -- Valuable Items
    [ITEM.NUGGET] = {
        id = 92, n = "Nugget", cat = ITEM_CATEGORY.VALUABLE,
        eff = "A nugget of pure gold, sell for high price", val = 10000, stack = 999
    },
    [ITEM.PEARL] = {
        id = 88, n = "Pearl", cat = ITEM_CATEGORY.VALUABLE,
        eff = "A beautiful pearl, can be sold", val = 1400, stack = 999
    },
    [ITEM.BIG_PEARL] = {
        id = 89, n = "Big Pearl", cat = ITEM_CATEGORY.VALUABLE,
        eff = "A big, beautiful pearl", val = 7500, stack = 999
    },
    [ITEM.STARDUST] = {
        id = 90, n = "Stardust", cat = ITEM_CATEGORY.VALUABLE,
        eff = "Lovely red sand, can be sold", val = 2000, stack = 999
    },
    [ITEM.STAR_PIECE] = {
        id = 91, n = "Star Piece", cat = ITEM_CATEGORY.VALUABLE,
        eff = "A red gem shard, very valuable", val = 9800, stack = 999
    },

    -- Rare Items
    [ITEM.RARE_CANDY] = {
        id = 50, n = "Rare Candy", cat = ITEM_CATEGORY.STAT_BOOST,
        eff = "Raises a Pokemon's level by 1", val = 4800, stack = 999
    },
    [ITEM.HEART_SCALE] = {
        id = 93, n = "Heart Scale", cat = ITEM_CATEGORY.VALUABLE,
        eff = "A lovely scale, used to remember moves", val = 100, stack = 999
    }
}

-- Create optimized indexes
local itemIndex = QueryOptimizations.createIndex(ItemsDB, "id")
local nameIndex = {}
local categoryIndex = {}

for itemId, data in pairs(ItemsDB) do
    nameIndex[data.n:lower()] = data
    
    if not categoryIndex[data.cat] then
        categoryIndex[data.cat] = {}
    end
    table.insert(categoryIndex[data.cat], data)
end

-- Query handlers
local function getItemById(itemId)
    return ItemsDB[itemId]
end

local function getItemByName(name)
    return nameIndex[name:lower()]
end

local function getItemsByCategory(category)
    return categoryIndex[category] or {}
end

local function getBerryEffect(itemId)
    local item = ItemsDB[itemId]
    if not item or not item.berry then
        return nil
    end
    
    local effect = {
        name = item.n,
        effect = item.eff,
        natural = item.natural or false
    }
    
    if item.heal then
        effect.healAmount = item.heal
    end
    
    if item.healPercent then
        effect.healPercent = item.healPercent
    end
    
    if item.cures then
        effect.statusCure = item.cures
    end
    
    if item.ppRestore then
        effect.ppRestore = item.ppRestore
    end
    
    if item.pinch then
        effect.pinchBerry = true
        effect.flavor = item.flavor
    end
    
    return effect
end

local function getItemEffect(itemId)
    local item = ItemsDB[itemId]
    if not item then
        return nil
    end
    
    local effect = {
        name = item.n,
        category = item.cat,
        effect = item.eff,
        value = item.val,
        stackable = item.stack
    }
    
    -- Add specific effect properties
    if item.heal then
        effect.healAmount = item.heal
    end
    
    if item.cures then
        effect.statusCure = item.cures
    end
    
    if item.revive then
        effect.revivePercent = item.revive
    end
    
    return effect
end

-- Main query handler for items database
local function handleItemsQuery(message)
    local action = message.Action
    local data = message.Data
    
    if action == "GetItem" then
        if data.id then
            return getItemById(data.id)
        elseif data.name then
            return getItemByName(data.name)
        else
            error("GetItem requires either 'id' or 'name' in Data")
        end
    elseif action == "GetItemsByCategory" then
        if not data.category then
            error("GetItemsByCategory requires 'category' in Data")
        end
        return getItemsByCategory(data.category)
    elseif action == "GetBerryEffect" then
        if not data.id then
            error("GetBerryEffect requires 'id' in Data")
        end
        return getBerryEffect(data.id)
    elseif action == "GetItemEffect" then
        if not data.id then
            error("GetItemEffect requires 'id' in Data")
        end
        return getItemEffect(data.id)
    else
        error("Unknown action: " .. action)
    end
end

-- AO Message Handlers
Handlers.add("items-query", 
    Handlers.utils.hasMatchingTag("Action", {"GetItem", "GetItemsByCategory", "GetBerryEffect", "GetItemEffect"}),
    function(msg)
        local response = handleMessage(msg, PROCESS_ID, handleItemsQuery)
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
        local itemCount = 0
        local berryCount = 0
        
        for _, item in pairs(ItemsDB) do
            itemCount = itemCount + 1
            if item.berry then
                berryCount = berryCount + 1
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                status = "healthy",
                processId = PROCESS_ID,
                itemCount = itemCount,
                berryCount = berryCount,
                categoriesLoaded = true,
                version = "1.0"
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

return ItemsDatabase