-- ============================================================================
-- Abilities Database Process - ADP v1.0 Compliant
-- Pokemon ability data queries with self-documentation protocol
-- Supports GetAbility, GetAbilitiesByTrigger, GetAbilityActivation operations
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "abilities-database-adp" }

-- Process metadata for ADP v1.0 compliance
local PROCESS_METADATA = {
    name = "Abilities Database",
    version = "1.0.0",
    adpVersion = "1.0",
    description = "Pokemon ability database with trigger conditions and effect mechanics",
    capabilities = {"GetAbility", "GetAbilitiesByTrigger", "GetAbilityActivation", "HealthCheck", "Info"},
    messageSchemas = {
        GetAbility = {
            required = {"Action", "Data", "Timestamp"},
            dataFields = {
                oneOf = {
                    {required = {"id"}},
                    {required = {"name"}}
                }
            }
        },
        GetAbilitiesByTrigger = {
            required = {"Action", "Data", "Timestamp"},
            dataFields = {required = {"trigger"}}
        },
        GetAbilityActivation = {
            required = {"Action", "Data", "Timestamp"},
            dataFields = {required = {"id"}, optional = {"context"}}
        },
        HealthCheck = {
            required = {"Action", "Timestamp"}
        },
        Info = {
            required = {"Action", "Timestamp"}
        }
    }
}

-- Embedded utility functions for AO compliance
local RATE_LIMIT_MAX = 100
local rateLimitCounters = {}

local function validateInput(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    if not message.Action or type(message.Action) ~= "string" then
        return false, "Action field is required"
    end
    if message.Action ~= "HealthCheck" and message.Action ~= "Info" then
        if not message.Data or type(message.Data) ~= "table" then
            return false, "Data field is required for this action"
        end
    end
    if not message.Timestamp or type(message.Timestamp) ~= "number" then
        return false, "Timestamp field is required"
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
        return false, "Rate limit exceeded"
    end
    
    counter.count = counter.count + 1
    return true, nil
end

local function createSuccessResponse(data, processId, responseType)
    local response = {
        Action = "SaveState",
    }
    
    -- For single ability objects, use individual tags
    if responseType == "single_ability" and data and type(data) == "table" and data.id then
        response.Success = "true"
        response.AbilityId = tostring(data.id)
        response.AbilityName = data.n or ""
        response.Description = data.desc or ""
        response.TriggerType = data.trig and tostring(data.trig[1]) or ""
        response.EffectType = tostring(data.eff or "")
    else
        -- For complex data (arrays, activation results, etc.), use Data field
        response.Data = data
    end
    
    return response
end

local function createErrorResponse(errorMessage, processId)
    return {
        Action = "SaveState",
        Error = errorMessage,
    }
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
    
    local success, result = pcall(function()
        return queryHandler(message)
    end)
    
    if success then
        -- Determine response type based on action
        local responseType = nil
        if message.Action == "GetAbility" then
            responseType = "single_ability"
        end
        return createSuccessResponse(result, processId, responseType)
    else
        return createErrorResponse("Query processing failed: " .. tostring(result), processId)
    end
end

-- Query optimization utilities
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

-- Process configuration
local AbilitiesDatabase = {}
local PROCESS_ID = ao.id

-- Ability Constants
local ABILITY = {
    NONE = 0,
    STENCH = 1,
    DRIZZLE = 2,
    SPEED_BOOST = 3,
    BATTLE_ARMOR = 4,
    STURDY = 5,
    DAMP = 6,
    LIMBER = 7,
    SAND_VEIL = 8,
    STATIC = 9,
    VOLT_ABSORB = 10,
    WATER_ABSORB = 11,
    OBLIVIOUS = 12,
    CLOUD_NINE = 13,
    COMPOUND_EYES = 14,
    INSOMNIA = 15,
    COLOR_CHANGE = 16,
    IMMUNITY = 17,
    FLASH_FIRE = 18,
    SHIELD_DUST = 19,
    OWN_TEMPO = 20,
    SUCTION_CUPS = 21,
    INTIMIDATE = 22,
    SHADOW_TAG = 23,
    ROUGH_SKIN = 24,
    WONDER_GUARD = 25,
    LEVITATE = 26,
    EFFECT_SPORE = 27,
    SYNCHRONIZE = 28,
    CLEAR_BODY = 29,
    NATURAL_CURE = 30,
    LIGHTNING_ROD = 31,
    SERENE_GRACE = 32,
    SWIFT_SWIM = 33,
    CHLOROPHYLL = 34,
    ILLUMINATE = 35,
    TRACE = 36,
    HUGE_POWER = 37,
    POISON_POINT = 38,
    INNER_FOCUS = 39,
    MAGMA_ARMOR = 40,
    WATER_VEIL = 41,
    MAGNET_PULL = 42,
    SOUNDPROOF = 43,
    RAIN_DISH = 44,
    SAND_STREAM = 45,
    PRESSURE = 46,
    THICK_FAT = 47,
    EARLY_BIRD = 48,
    FLAME_BODY = 49,
    RUN_AWAY = 50,
    KEEN_EYE = 51,
    HYPER_CUTTER = 52,
    PICKUP = 53,
    TRUANT = 54,
    HUSTLE = 55,
    CUTE_CHARM = 56,
    PLUS = 57,
    MINUS = 58,
    FORECAST = 59,
    STICKY_HOLD = 60,
    SHED_SKIN = 61,
    GUTS = 62,
    MARVEL_SCALE = 63,
    LIQUID_OOZE = 64,
    OVERGROW = 65,
    BLAZE = 66,
    TORRENT = 67,
    SWARM = 68,
    ROCK_HEAD = 69,
    DROUGHT = 70,
    ARENA_TRAP = 71,
    VITAL_SPIRIT = 72,
    WHITE_SMOKE = 73,
    PURE_POWER = 74,
    SHELL_ARMOR = 75,
    AIR_LOCK = 76,
    TANGLED_FEET = 77,
    MOTOR_DRIVE = 78,
    RIVALRY = 79,
    STEADFAST = 80,
    SNOW_CLOAK = 81,
    GLUTTONY = 82,
    ANGER_POINT = 83,
    UNBURDEN = 84,
    HEATPROOF = 85,
    SIMPLE = 86,
    DRY_SKIN = 87,
    DOWNLOAD = 88,
    IRON_FIST = 89,
    POISON_HEAL = 90,
    ADAPTABILITY = 91,
    SKILL_LINK = 92,
    HYDRATION = 93,
    SOLAR_POWER = 94,
    QUICK_FEET = 95,
    NORMALIZE = 96,
    SNIPER = 97,
    MAGIC_GUARD = 98,
    NO_GUARD = 99,
    STALL = 100,
    TECHNICIAN = 101,
    LEAF_GUARD = 102,
    KLUTZ = 103,
    MOLD_BREAKER = 104,
    SUPER_LUCK = 105,
    AFTERMATH = 106,
    ANTICIPATION = 107,
    FOREWARN = 108,
    UNAWARE = 109,
    TINTED_LENS = 110,
    FILTER = 111,
    SLOW_START = 112,
    SCRAPPY = 113,
    STORM_DRAIN = 114,
    ICE_BODY = 115,
    SOLID_ROCK = 116,
    SNOW_WARNING = 117,
    HONEY_GATHER = 118,
    FRISK = 119,
    RECKLESS = 120,
    MULTITYPE = 121,
    FLOWER_GIFT = 122,
    BAD_DREAMS = 123
}

-- Trigger Types
local TRIGGER_TYPE = {
    ON_ENTRY = "on_entry",
    ON_SWITCH = "on_switch",
    ON_DAMAGE = "on_damage",
    ON_ATTACK = "on_attack",
    ON_DEFEND = "on_defend",
    ON_STATUS = "on_status",
    ON_WEATHER = "on_weather",
    ON_TERRAIN = "on_terrain",
    PASSIVE = "passive",
    ON_CRITICAL = "on_critical",
    ON_FAINT = "on_faint",
    ON_HEAL = "on_heal",
    ON_STAT_CHANGE = "on_stat_change",
    ON_MOVE_USE = "on_move_use",
    ON_CONTACT = "on_contact",
    ALWAYS_ACTIVE = "always_active"
}

-- Effect Types
local EFFECT_TYPE = {
    STAT_BOOST = "stat_boost",
    STAT_REDUCTION = "stat_reduction",
    IMMUNITY = "immunity",
    ABSORPTION = "absorption",
    STATUS_INFLICT = "status_inflict",
    STATUS_CURE = "status_cure",
    DAMAGE_MODIFY = "damage_modify",
    ACCURACY_MODIFY = "accuracy_modify",
    WEATHER_SET = "weather_set",
    TYPE_CHANGE = "type_change",
    MOVE_CHANGE = "move_change",
    PREVENT_ACTION = "prevent_action",
    HEAL = "heal",
    DAMAGE = "damage",
    PROTECTION = "protection"
}

-- Embedded Abilities Database (Optimized for size and performance)
local AbilitiesDB = {
    -- Starter Abilities
    [ABILITY.OVERGROW] = {
        id = 65, n = "Overgrow", 
        trig = {TRIGGER_TYPE.ON_ATTACK}, eff = EFFECT_TYPE.DAMAGE_MODIFY,
        desc = "Boosts Grass moves by 50% when HP is below 1/3",
        mech = "When user's HP <= 33%, Grass-type move power * 1.5",
        cond = "user.hp <= user.maxHp * 0.33 and move.type == GRASS"
    },
    [ABILITY.BLAZE] = {
        id = 66, n = "Blaze",
        trig = {TRIGGER_TYPE.ON_ATTACK}, eff = EFFECT_TYPE.DAMAGE_MODIFY,
        desc = "Boosts Fire moves by 50% when HP is below 1/3",
        mech = "When user's HP <= 33%, Fire-type move power * 1.5",
        cond = "user.hp <= user.maxHp * 0.33 and move.type == FIRE"
    },
    [ABILITY.TORRENT] = {
        id = 67, n = "Torrent",
        trig = {TRIGGER_TYPE.ON_ATTACK}, eff = EFFECT_TYPE.DAMAGE_MODIFY,
        desc = "Boosts Water moves by 50% when HP is below 1/3",
        mech = "When user's HP <= 33%, Water-type move power * 1.5",
        cond = "user.hp <= user.maxHp * 0.33 and move.type == WATER"
    },

    -- Contact Abilities
    [ABILITY.STATIC] = {
        id = 9, n = "Static",
        trig = {TRIGGER_TYPE.ON_CONTACT}, eff = EFFECT_TYPE.STATUS_INFLICT,
        desc = "30% chance to paralyze attackers on contact",
        mech = "When hit by contact move, 30% chance to paralyze attacker",
        cond = "move.contact == true and random(100) <= 30"
    },
    [ABILITY.POISON_POINT] = {
        id = 38, n = "Poison Point",
        trig = {TRIGGER_TYPE.ON_CONTACT}, eff = EFFECT_TYPE.STATUS_INFLICT,
        desc = "30% chance to poison attackers on contact",
        mech = "When hit by contact move, 30% chance to poison attacker",
        cond = "move.contact == true and random(100) <= 30"
    },
    [ABILITY.FLAME_BODY] = {
        id = 49, n = "Flame Body",
        trig = {TRIGGER_TYPE.ON_CONTACT}, eff = EFFECT_TYPE.STATUS_INFLICT,
        desc = "30% chance to burn attackers on contact",
        mech = "When hit by contact move, 30% chance to burn attacker",
        cond = "move.contact == true and random(100) <= 30"
    },
    [ABILITY.ROUGH_SKIN] = {
        id = 24, n = "Rough Skin",
        trig = {TRIGGER_TYPE.ON_CONTACT}, eff = EFFECT_TYPE.DAMAGE,
        desc = "Damages attackers by 1/8 max HP on contact",
        mech = "When hit by contact move, attacker loses 1/8 max HP",
        cond = "move.contact == true"
    },

    -- Absorption Abilities
    [ABILITY.VOLT_ABSORB] = {
        id = 10, n = "Volt Absorb",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.ABSORPTION,
        desc = "Heals 25% max HP when hit by Electric moves",
        mech = "Electric moves heal instead of damage, restore 25% max HP",
        cond = "move.type == ELECTRIC"
    },
    [ABILITY.WATER_ABSORB] = {
        id = 11, n = "Water Absorb",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.ABSORPTION,
        desc = "Heals 25% max HP when hit by Water moves",
        mech = "Water moves heal instead of damage, restore 25% max HP",
        cond = "move.type == WATER"
    },
    [ABILITY.FLASH_FIRE] = {
        id = 18, n = "Flash Fire",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.ABSORPTION,
        desc = "Absorbs Fire moves and boosts own Fire moves by 50%",
        mech = "Fire moves have no effect, next Fire move power * 1.5",
        cond = "move.type == FIRE"
    },

    -- Weather Abilities
    [ABILITY.DRIZZLE] = {
        id = 2, n = "Drizzle",
        trig = {TRIGGER_TYPE.ON_ENTRY}, eff = EFFECT_TYPE.WEATHER_SET,
        desc = "Summons rain when entering battle",
        mech = "Sets weather to rain for 5 turns on switch-in",
        cond = "always"
    },
    [ABILITY.DROUGHT] = {
        id = 70, n = "Drought",
        trig = {TRIGGER_TYPE.ON_ENTRY}, eff = EFFECT_TYPE.WEATHER_SET,
        desc = "Summons harsh sunlight when entering battle",
        mech = "Sets weather to sun for 5 turns on switch-in",
        cond = "always"
    },
    [ABILITY.SAND_STREAM] = {
        id = 45, n = "Sand Stream",
        trig = {TRIGGER_TYPE.ON_ENTRY}, eff = EFFECT_TYPE.WEATHER_SET,
        desc = "Summons sandstorm when entering battle",
        mech = "Sets weather to sandstorm for 5 turns on switch-in",
        cond = "always"
    },
    [ABILITY.SNOW_WARNING] = {
        id = 117, n = "Snow Warning",
        trig = {TRIGGER_TYPE.ON_ENTRY}, eff = EFFECT_TYPE.WEATHER_SET,
        desc = "Summons hail when entering battle",
        mech = "Sets weather to hail for 5 turns on switch-in",
        cond = "always"
    },

    -- Speed Abilities
    [ABILITY.CHLOROPHYLL] = {
        id = 34, n = "Chlorophyll",
        trig = {TRIGGER_TYPE.ON_WEATHER}, eff = EFFECT_TYPE.STAT_BOOST,
        desc = "Doubles Speed in harsh sunlight",
        mech = "Speed stat * 2 when weather is sun",
        cond = "weather == SUN"
    },
    [ABILITY.SWIFT_SWIM] = {
        id = 33, n = "Swift Swim",
        trig = {TRIGGER_TYPE.ON_WEATHER}, eff = EFFECT_TYPE.STAT_BOOST,
        desc = "Doubles Speed in rain",
        mech = "Speed stat * 2 when weather is rain",
        cond = "weather == RAIN"
    },
    [ABILITY.SAND_VEIL] = {
        id = 8, n = "Sand Veil",
        trig = {TRIGGER_TYPE.ON_WEATHER}, eff = EFFECT_TYPE.ACCURACY_MODIFY,
        desc = "Boosts evasion by 25% in sandstorm",
        mech = "Evasion * 1.25 when weather is sandstorm",
        cond = "weather == SANDSTORM"
    },

    -- Stat Boost Abilities
    [ABILITY.HUGE_POWER] = {
        id = 37, n = "Huge Power",
        trig = {TRIGGER_TYPE.ALWAYS_ACTIVE}, eff = EFFECT_TYPE.STAT_BOOST,
        desc = "Doubles Attack stat",
        mech = "Attack stat * 2 in all calculations",
        cond = "always"
    },
    [ABILITY.PURE_POWER] = {
        id = 74, n = "Pure Power",
        trig = {TRIGGER_TYPE.ALWAYS_ACTIVE}, eff = EFFECT_TYPE.STAT_BOOST,
        desc = "Doubles Attack stat",
        mech = "Attack stat * 2 in all calculations",
        cond = "always"
    },
    [ABILITY.THICK_FAT] = {
        id = 47, n = "Thick Fat",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.DAMAGE_MODIFY,
        desc = "Halves damage from Fire and Ice moves",
        mech = "Fire and Ice move damage * 0.5",
        cond = "move.type == FIRE or move.type == ICE"
    },

    -- Status Immunity Abilities
    [ABILITY.LIMBER] = {
        id = 7, n = "Limber",
        trig = {TRIGGER_TYPE.PASSIVE}, eff = EFFECT_TYPE.IMMUNITY,
        desc = "Prevents paralysis",
        mech = "Cannot be paralyzed, cures existing paralysis",
        cond = "status != PARALYSIS"
    },
    [ABILITY.IMMUNITY] = {
        id = 17, n = "Immunity",
        trig = {TRIGGER_TYPE.PASSIVE}, eff = EFFECT_TYPE.IMMUNITY,
        desc = "Prevents poison and bad poison",
        mech = "Cannot be poisoned, cures existing poison",
        cond = "status != POISON and status != BAD_POISON"
    },
    [ABILITY.INSOMNIA] = {
        id = 15, n = "Insomnia",
        trig = {TRIGGER_TYPE.PASSIVE}, eff = EFFECT_TYPE.IMMUNITY,
        desc = "Prevents sleep",
        mech = "Cannot fall asleep",
        cond = "status != SLEEP"
    },
    [ABILITY.WATER_VEIL] = {
        id = 41, n = "Water Veil",
        trig = {TRIGGER_TYPE.PASSIVE}, eff = EFFECT_TYPE.IMMUNITY,
        desc = "Prevents burn",
        mech = "Cannot be burned, cures existing burn",
        cond = "status != BURN"
    },
    [ABILITY.MAGMA_ARMOR] = {
        id = 40, n = "Magma Armor",
        trig = {TRIGGER_TYPE.PASSIVE}, eff = EFFECT_TYPE.IMMUNITY,
        desc = "Prevents freeze",
        mech = "Cannot be frozen",
        cond = "status != FREEZE"
    },

    -- Critical Hit Abilities
    [ABILITY.BATTLE_ARMOR] = {
        id = 4, n = "Battle Armor",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.PROTECTION,
        desc = "Prevents critical hits",
        mech = "Opponent moves cannot score critical hits",
        cond = "always"
    },
    [ABILITY.SHELL_ARMOR] = {
        id = 75, n = "Shell Armor",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.PROTECTION,
        desc = "Prevents critical hits",
        mech = "Opponent moves cannot score critical hits",
        cond = "always"
    },
    [ABILITY.SUPER_LUCK] = {
        id = 105, n = "Super Luck",
        trig = {TRIGGER_TYPE.ON_ATTACK}, eff = EFFECT_TYPE.STAT_BOOST,
        desc = "Heightens critical hit ratio",
        mech = "Critical hit ratio increased by 1 stage",
        cond = "always"
    },

    -- Special Abilities
    [ABILITY.WONDER_GUARD] = {
        id = 25, n = "Wonder Guard",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.PROTECTION,
        desc = "Only super effective moves deal damage",
        mech = "Takes damage only from super effective moves",
        cond = "typeEffectiveness > 1.0"
    },
    [ABILITY.LEVITATE] = {
        id = 26, n = "Levitate",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.IMMUNITY,
        desc = "Immune to Ground-type moves",
        mech = "Ground-type moves have no effect",
        cond = "move.type != GROUND"
    },
    [ABILITY.PRESSURE] = {
        id = 46, n = "Pressure",
        trig = {TRIGGER_TYPE.ON_DEFEND}, eff = EFFECT_TYPE.MOVE_CHANGE,
        desc = "Increases PP consumption of opponent's moves",
        mech = "Opponent moves consume 2 PP instead of 1",
        cond = "always"
    },

    -- Healing Abilities
    [ABILITY.NATURAL_CURE] = {
        id = 30, n = "Natural Cure",
        trig = {TRIGGER_TYPE.ON_SWITCH}, eff = EFFECT_TYPE.STATUS_CURE,
        desc = "Cures status conditions when switching out",
        mech = "All status conditions removed when switching out",
        cond = "always"
    },
    [ABILITY.SHED_SKIN] = {
        id = 61, n = "Shed Skin",
        trig = {TRIGGER_TYPE.ON_HEAL}, eff = EFFECT_TYPE.STATUS_CURE,
        desc = "33% chance to cure status each turn",
        mech = "1/3 chance to remove status condition each turn",
        cond = "hasStatus == true and random(100) <= 33"
    },

    -- Accuracy Abilities
    [ABILITY.COMPOUND_EYES] = {
        id = 14, n = "Compound Eyes",
        trig = {TRIGGER_TYPE.ON_ATTACK}, eff = EFFECT_TYPE.ACCURACY_MODIFY,
        desc = "Boosts accuracy by 30%",
        mech = "Move accuracy * 1.3",
        cond = "always"
    },
    [ABILITY.NO_GUARD] = {
        id = 99, n = "No Guard",
        trig = {TRIGGER_TYPE.ALWAYS_ACTIVE}, eff = EFFECT_TYPE.ACCURACY_MODIFY,
        desc = "All moves used by or against this Pokemon hit",
        mech = "All moves have 100% accuracy",
        cond = "always"
    }
}

-- Create optimized indexes
local abilityIndex = QueryOptimizations.createIndex(AbilitiesDB, "id")
local nameIndex = {}
local triggerIndex = {}

for abilityId, data in pairs(AbilitiesDB) do
    nameIndex[data.n:lower()] = data
    
    for _, trigger in ipairs(data.trig) do
        if not triggerIndex[trigger] then
            triggerIndex[trigger] = {}
        end
        table.insert(triggerIndex[trigger], data)
    end
end

-- Query handlers
local function getAbilityById(abilityId)
    return AbilitiesDB[abilityId]
end

local function getAbilityByName(name)
    return nameIndex[name:lower()]
end

local function getAbilitiesByTrigger(triggerType)
    return triggerIndex[triggerType] or {}
end

local function getAbilityActivation(abilityId, context)
    local ability = AbilitiesDB[abilityId]
    if not ability then
        return nil
    end
    
    return {
        name = ability.n,
        triggers = ability.trig,
        effect = ability.eff,
        description = ability.desc,
        mechanics = ability.mech,
        condition = ability.cond,
        context = context or {}
    }
end

-- Main query handler for abilities database
local function handleAbilitiesQuery(message)
    local action = message.Action
    
    if action == "GetAbility" then
        local abilityId = message.AbilityId or message.Id
        local abilityName = message.AbilityName or message.Name
        
        if abilityId then
            return getAbilityById(tonumber(abilityId))
        elseif abilityName then
            return getAbilityByName(abilityName)
        else
            error("GetAbility requires either 'AbilityId'/'Id' or 'AbilityName'/'Name' tag")
        end
    elseif action == "GetAbilitiesByTrigger" then
        local trigger = message.Trigger
        if not trigger then
            error("GetAbilitiesByTrigger requires 'Trigger' tag")
        end
        return getAbilitiesByTrigger(trigger)
    elseif action == "GetAbilityActivation" then
        local abilityId = message.AbilityId or message.Id
        local context = message.Context
        if not abilityId then
            error("GetAbilityActivation requires 'AbilityId' or 'Id' tag")
        end
        return getAbilityActivation(tonumber(abilityId), context)
    else
        error("Unknown action: " .. action)
    end
end

-- ADP v1.0 REQUIRED: Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local success, result = pcall(function()
            local abilityCount = 0
            local triggerCount = 0
            local effectTypes = {}
            
            for _ in pairs(AbilitiesDB) do
                abilityCount = abilityCount + 1
            end
            
            for trigger in pairs(triggerIndex) do
                triggerCount = triggerCount + 1
            end
            
            for _, ability in pairs(AbilitiesDB) do
                effectTypes[ability.eff] = true
            end
            
            local effectTypeCount = 0
            for _ in pairs(effectTypes) do
                effectTypeCount = effectTypeCount + 1
            end
            
            return {
                process = PROCESS_METADATA,
                handlers = PROCESS_METADATA.capabilities,
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    performanceTarget = "sub-100ms",
                    rateLimiting = {
                        enabled = true,
                        limit = RATE_LIMIT_MAX,
                        window = "per-minute"
                    }
                },
                statistics = {
                    abilityCount = abilityCount,
                    triggerTypeCount = triggerCount,
                    effectTypeCount = effectTypeCount,
                    indexesBuilt = 3,
                    embeddedData = true
                },
                constants = {
                    ABILITY = "Embedded ability ID constants",
                    TRIGGER_TYPE = "Trigger condition types",
                    EFFECT_TYPE = "Effect mechanism types"
                }
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = result,
                ProcessId = PROCESS_ID,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Info query failed: " .. tostring(result),
                ProcessId = PROCESS_ID,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
        end
    end
)

-- AO Message Handlers
Handlers.add("abilities-query", 
    Handlers.utils.hasMatchingTag("Action", {"GetAbility", "GetAbilitiesByTrigger", "GetAbilityActivation"}),
    function(msg)
        local response = handleMessage(msg, PROCESS_ID, handleAbilitiesQuery)
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
        local success, result = pcall(function()
            local abilityCount = 0
            local triggerCount = 0
            
            for _ in pairs(AbilitiesDB) do
                abilityCount = abilityCount + 1
            end
            
            for _ in pairs(triggerIndex) do
                triggerCount = triggerCount + 1
            end
            
            return {
                status = "healthy",
                processId = PROCESS_ID,
                abilityCount = abilityCount,
                triggerTypes = triggerCount,
                mechanicsLoaded = true,
                version = "1.0",
                adpCompliant = true,
                adpVersion = "1.0"
            }
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = result,
                ProcessId = PROCESS_ID,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Health check failed: " .. tostring(result),
                ProcessId = PROCESS_ID,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
        end
    end
)

return AbilitiesDatabase