-- Status Effects Engine Process for PokéRogue AO
-- ADP v1.0 Compliant Pokemon Status Effects Management System
-- Handles comprehensive status effect application, turn processing, interactions, and removal
-- Monolithic process - all dependencies embedded (no external imports)

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "status-effects-engine" }

-- Process metadata for ADP v1.0 compliance
local PROCESS_METADATA = {
    name = "Status Effects Engine",
    version = "1.0.0",
    adpVersion = "1.0",
    description = "Comprehensive Pokemon status effects management system with damage calculations, probability checks, and interaction rules",
    capabilities = {
        "applyStatusEffect",
        "processStatusTurn", 
        "removeStatusEffect",
        "checkStatusInteractions",
        "validateStatusImmunity",
        "calculateStatusDamage",
        "processEnvironmentalEffects"
    },
    messageSchemas = {
        ProcessLogic = {
            required = {"Action", "Data", "Timestamp"},
            properties = {
                Action = {type = "string", value = "ProcessLogic"},
                Data = {
                    type = "object",
                    required = {"gameState", "operation", "parameters"},
                    properties = {
                        gameState = {type = "object", description = "Current game state"},
                        operation = {type = "string", enum = {"applyStatusEffect", "processStatusTurn", "removeStatusEffect", "checkStatusInteractions", "validateStatusImmunity", "calculateStatusDamage", "processEnvironmentalEffects"}},
                        parameters = {type = "object", description = "Operation-specific parameters"}
                    }
                },
                Timestamp = {type = "number", description = "Unix timestamp"}
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
    }
}

-- Performance monitoring (5 second limit for operations)
local OPERATION_TIMEOUT = 5000
local performanceStartTime = nil

-- Rate limiting (50 operations per minute per address)
local RATE_LIMIT_MAX = 50
local rateLimitCounters = {}

-- Comprehensive status effects database with detailed mechanics
local STATUS_EFFECTS = {
    none = {
        name = "None",
        category = "normal",
        duration = 0,
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {},
        immunities = {},
        interactions = {}
    },
    burn = {
        name = "Burn",
        category = "major",
        duration = -1, -- Permanent until cured
        damageOverTime = true,
        damagePercent = 0.0625, -- 1/16 max HP per turn
        statModifiers = {attack = 0.5}, -- 50% attack reduction
        moveRestrictions = {},
        immunities = {"fire"},
        interactions = {
            curedBy = {"switch", "heal", "waterMove", "rain"},
            preventedBy = {"fireType", "waterVeil", "magmaArmor"},
            damageBoostedBy = {"sunny"},
            damageReducedBy = {"rain"}
        },
        turnEndEffect = "applyBurnDamage",
        description = "Deals 1/16 max HP damage per turn and halves Attack stat"
    },
    poison = {
        name = "Poison",
        category = "major", 
        duration = -1,
        damageOverTime = true,
        damagePercent = 0.125, -- 1/8 max HP per turn
        statModifiers = {},
        moveRestrictions = {},
        immunities = {"poison", "steel"},
        interactions = {
            curedBy = {"switch", "heal", "aromatherapy", "healBell"},
            preventedBy = {"poisonType", "steelType", "immunity", "limber"},
            upgradedBy = {"toxicSpikes2"}
        },
        turnEndEffect = "applyPoisonDamage",
        description = "Deals 1/8 max HP damage per turn"
    },
    toxic = {
        name = "Toxic",
        category = "major",
        duration = -1,
        damageOverTime = true,
        damagePercent = 0.0625, -- Base 1/16, multiplied by toxicTurnCount
        statModifiers = {},
        moveRestrictions = {},
        immunities = {"poison", "steel"},
        interactions = {
            curedBy = {"switch", "heal", "aromatherapy", "healBell"},
            preventedBy = {"poisonType", "steelType", "immunity"},
            resetOnSwitch = true
        },
        turnEndEffect = "applyToxicDamage",
        description = "Deals increasing damage each turn (1/16 * toxicTurnCount)"
    },
    paralysis = {
        name = "Paralysis", 
        category = "major",
        duration = -1,
        damageOverTime = false,
        statModifiers = {speed = 0.25}, -- 75% speed reduction
        moveRestrictions = {chanceToNotMove = 0.25}, -- 25% full paralysis chance
        immunities = {"electric"},
        interactions = {
            curedBy = {"switch", "heal", "aromatherapy", "healBell"},
            preventedBy = {"electricType", "limber", "groundType"},
            bypassedBy = {"sleepTalk", "snore"}
        },
        turnEndEffect = nil,
        description = "Reduces Speed by 75% and 25% chance to be unable to move"
    },
    sleep = {
        name = "Sleep",
        category = "major", 
        duration = -1, -- Managed by sleepTurnsRemaining
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true},
        immunities = {},
        interactions = {
            curedBy = {"damage", "switch", "aromatherapy", "healBell"},
            preventedBy = {"insomnia", "vitalSpirit"},
            allowedMoves = {"sleepTalk", "snore"},
            wakenBy = {"uproar"}
        },
        turnEndEffect = "checkWakeUp",
        description = "Cannot move until sleepTurnsRemaining reaches 0"
    },
    freeze = {
        name = "Freeze",
        category = "major",
        duration = -1,
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true},
        immunities = {"ice"},
        interactions = {
            curedBy = {"fireMove", "switch", "aromatherapy", "healBell"},
            preventedBy = {"iceType", "magmaArmor"},
            thawChance = 0.2 -- 20% chance per turn
        },
        turnEndEffect = "checkThaw",
        description = "Cannot move until thawed by fire moves or luck"
    },
    confused = {
        name = "Confused",
        category = "minor",
        duration = {min = 1, max = 4}, -- 1-4 turns
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {chanceToHurtSelf = 0.33}, -- 33% self-hit chance
        immunities = {},
        interactions = {
            curedBy = {"switch"},
            preventedBy = {"ownTempo"},
            selfDamagePercent = 0.125 -- 1/8 max HP confusion damage
        },
        turnEndEffect = "checkConfusion",
        description = "33% chance to hurt self instead of using move"
    },
    flinch = {
        name = "Flinch",
        category = "minor",
        duration = 1, -- Only current turn
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true},
        immunities = {},
        interactions = {
            preventedBy = {"innerFocus"},
            onlyIfNotMoved = true
        },
        turnEndEffect = "removeFlinch",
        description = "Cannot move this turn only"
    },
    infatuation = {
        name = "Infatuation",
        category = "minor",
        duration = -1,
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {chanceToNotMove = 0.5}, -- 50% immobilization
        immunities = {},
        interactions = {
            curedBy = {"switch"},
            preventedBy = {"oblivious", "sameGender"},
            requiresOppositeGender = true
        },
        turnEndEffect = nil,
        description = "50% chance to be immobilized by attraction"
    },
    faint = {
        name = "Faint",
        category = "critical",
        duration = -1,
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true, cannotBeTargeted = true},
        immunities = {},
        interactions = {
            curedBy = {"revive", "reviveHalf", "maxRevive"}
        },
        turnEndEffect = nil,
        description = "Pokemon has 0 HP and cannot battle"
    }
}

-- Environmental effects that modify status calculations
local ENVIRONMENTAL_EFFECTS = {
    none = {name = "None", effects = {}},
    sunny = {
        name = "Sunny Day",
        duration = 5,
        effects = {
            statusModifications = {
                burn = {damageReduced = true, healChance = 0.1},
                freeze = {preventApplication = true}
            }
        }
    },
    rain = {
        name = "Rain", 
        duration = 5,
        effects = {
            statusModifications = {
                burn = {cureChance = 0.2},
                paralysis = {thunderWaveBoost = 1.2}
            }
        }
    },
    sandstorm = {
        name = "Sandstorm",
        duration = 5,
        effects = {
            statusModifications = {
                poison = {damageToNonGroundRockSteel = 0.0625}
            }
        }
    },
    hail = {
        name = "Hail",
        duration = 5,
        effects = {
            statusModifications = {
                freeze = {preventThaw = true},
                burn = {damageToNonIce = 0.0625}
            }
        }
    }
}

-- Type immunities and resistances
local TYPE_IMMUNITIES = {
    fire = {"burn"},
    electric = {"paralysis"},
    poison = {"poison", "toxic"},
    steel = {"poison", "toxic"},
    ice = {"freeze"},
    psychic = {"confusion"} -- Only from other Psychic types
}

-- Ability-based immunities
local ABILITY_IMMUNITIES = {
    immunity = {"poison", "toxic"},
    limber = {"paralysis"},
    insomnia = {"sleep"},
    vitalSpirit = {"sleep"},
    waterVeil = {"burn"},
    magmaArmor = {"freeze"},
    ownTempo = {"confused"},
    innerFocus = {"flinch"},
    oblivious = {"infatuation"}
}

-- ====================================
-- UTILITY FUNCTIONS
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

-- Deterministic RNG using battle seed
local function initializeRNG(battleSeed, turnCounter)
    if not battleSeed or type(battleSeed) ~= "string" then
        return nil, "Battle seed is required for deterministic RNG"
    end
    
    local seedValue = 0
    for i = 1, #battleSeed do
        seedValue = seedValue + string.byte(battleSeed, i) * i
    end
    
    -- Include turn counter for turn-specific randomness
    seedValue = seedValue + (turnCounter or 0) * 1000
    
    return {seed = seedValue, counter = 0}, nil
end

local function nextRandom(rngState, min, max)
    if not rngState then
        error("RNG state is required for deterministic random generation")
    end
    
    rngState.counter = rngState.counter + 1
    
    local a = 1664525
    local c = 1013904223
    local m = 2^32
    
    rngState.seed = (a * rngState.seed + c + rngState.counter) % m
    local random = rngState.seed / m
    
    if min and max then
        return math.floor(random * (max - min + 1)) + min
    else
        return random
    end
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

-- Rate limiting check
local function checkRateLimit(address)
    local currentTime = msg and msg.Timestamp or 0
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

-- Input validation
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

-- ====================================
-- MESSAGE GENERATION (TypeScript Parity)
-- ====================================

-- Get status effect message key for i18n compatibility
local function getStatusEffectMessageKey(statusEffect)
    local messageKeys = {
        poison = "statusEffect:poison",
        toxic = "statusEffect:toxic",
        paralysis = "statusEffect:paralysis",
        sleep = "statusEffect:sleep",
        freeze = "statusEffect:freeze",
        burn = "statusEffect:burn",
        none = "statusEffect:none"
    }
    return messageKeys[statusEffect] or "statusEffect:none"
end

-- Generate obtain message
local function getStatusEffectObtainText(statusEffect, pokemonName, sourceText)
    if statusEffect == "none" then
        return ""
    end
    
    local messages = {
        poison = pokemonName .. " was poisoned!",
        toxic = pokemonName .. " was badly poisoned!",
        paralysis = pokemonName .. " is paralyzed! It may be unable to move!",
        sleep = pokemonName .. " fell asleep!",
        freeze = pokemonName .. " was frozen solid!",
        burn = pokemonName .. " was burned!"
    }
    
    if sourceText then
        messages.poison = pokemonName .. " was poisoned by " .. sourceText .. "!"
        messages.toxic = pokemonName .. " was badly poisoned by " .. sourceText .. "!"
        messages.paralysis = pokemonName .. " is paralyzed by " .. sourceText .. "! It may be unable to move!"
        messages.sleep = pokemonName .. " fell asleep from " .. sourceText .. "!"
        messages.freeze = pokemonName .. " was frozen solid by " .. sourceText .. "!"
        messages.burn = pokemonName .. " was burned by " .. sourceText .. "!"
    end
    
    return messages[statusEffect] or ""
end

-- Generate activation message
local function getStatusEffectActivationText(statusEffect, pokemonName)
    if statusEffect == "none" then
        return ""
    end
    
    local messages = {
        poison = pokemonName .. " is hurt by poison!",
        toxic = pokemonName .. " is hurt by poison!",
        paralysis = pokemonName .. " is paralyzed and can't move!",
        sleep = pokemonName .. " is fast asleep.",
        freeze = pokemonName .. " is frozen solid!",
        burn = pokemonName .. " is hurt by its burn!"
    }
    
    return messages[statusEffect] or ""
end

-- Generate overlap message
local function getStatusEffectOverlapText(statusEffect, pokemonName)
    if statusEffect == "none" then
        return ""
    end
    
    local messages = {
        poison = pokemonName .. " is already poisoned!",
        toxic = pokemonName .. " is already badly poisoned!",
        paralysis = pokemonName .. " is already paralyzed!",
        sleep = pokemonName .. " is already asleep!",
        freeze = pokemonName .. " is already frozen!",
        burn = pokemonName .. " is already burned!"
    }
    
    return messages[statusEffect] or ""
end

-- Generate heal message
local function getStatusEffectHealText(statusEffect, pokemonName)
    if statusEffect == "none" then
        return ""
    end
    
    local messages = {
        poison = pokemonName .. " was cured of its poisoning!",
        toxic = pokemonName .. " was cured of its poisoning!",
        paralysis = pokemonName .. " was cured of paralysis!",
        sleep = pokemonName .. " woke up!",
        freeze = pokemonName .. " thawed out!",
        burn = pokemonName .. " was healed of its burn!"
    }
    
    return messages[statusEffect] or ""
end

-- Get catch rate multiplier for status
local function getStatusEffectCatchRateMultiplier(statusEffect)
    if statusEffect == "poison" or statusEffect == "toxic" or 
       statusEffect == "paralysis" or statusEffect == "burn" then
        return 1.5
    elseif statusEffect == "sleep" or statusEffect == "freeze" then
        return 2.5
    else
        return 1.0
    end
end

-- ====================================
-- STATUS EFFECTS ENGINE CORE
-- ====================================

local StatusEffectsEngine = {}

-- Check if Pokemon has immunity to status effect
function StatusEffectsEngine.checkStatusImmunity(pokemon, statusEffect)
    local effect = STATUS_EFFECTS[statusEffect]
    if not effect then
        return false, "Unknown status effect: " .. statusEffect
    end
    
    -- Check type immunities
    if pokemon.types then
        for _, pokemonType in ipairs(pokemon.types) do
            local typeImmunities = TYPE_IMMUNITIES[pokemonType]
            if typeImmunities then
                for _, immunity in ipairs(typeImmunities) do
                    if immunity == statusEffect then
                        return true, "Type immunity: " .. pokemonType .. " type immune to " .. statusEffect
                    end
                end
            end
        end
    end
    
    -- Check ability immunities
    if pokemon.ability then
        local abilityImmunities = ABILITY_IMMUNITIES[pokemon.ability]
        if abilityImmunities then
            for _, immunity in ipairs(abilityImmunities) do
                if immunity == statusEffect then
                    return true, "Ability immunity: " .. pokemon.ability .. " prevents " .. statusEffect
                end
            end
        end
    end
    
    return false, nil
end

-- Check status effect interactions and conflicts
function StatusEffectsEngine.checkStatusInteractions(currentStatus, newStatus)
    if currentStatus == "none" or not currentStatus then
        return true, "No current status to conflict with"
    end
    
    if currentStatus == newStatus then
        return false, "Pokemon already has " .. newStatus
    end
    
    local currentEffect = STATUS_EFFECTS[currentStatus]
    local newEffect = STATUS_EFFECTS[newStatus]
    
    if not currentEffect or not newEffect then
        return false, "Invalid status effect"
    end
    
    -- Major statuses generally cannot be replaced
    if currentEffect.category == "major" and newEffect.category == "major" then
        return false, "Cannot replace major status " .. currentStatus .. " with " .. newStatus
    end
    
    -- Minor statuses can be replaced by major ones
    if currentEffect.category == "minor" and newEffect.category == "major" then
        return true, "Major status replaces minor status"
    end
    
    -- Some specific replacements allowed
    local allowedReplacements = {
        sleep = {"paralysis"}, -- Thunder Wave can wake up sleeping Pokemon
        freeze = {"burn"} -- Burn thaws frozen Pokemon
    }
    
    local allowed = allowedReplacements[currentStatus]
    if allowed then
        for _, replacement in ipairs(allowed) do
            if replacement == newStatus then
                return true, "Specific interaction: " .. newStatus .. " replaces " .. currentStatus
            end
        end
    end
    
    return false, "Status effects conflict: " .. currentStatus .. " and " .. newStatus
end

-- Apply status effect with comprehensive checks
function StatusEffectsEngine.applyStatusEffect(pokemon, statusEffect, rngState, environmentalEffect)
    local newPokemon = deepCopy(pokemon)
    
    -- Check immunity first
    local immune, immunityReason = StatusEffectsEngine.checkStatusImmunity(pokemon, statusEffect)
    if immune then
        return newPokemon, false, immunityReason
    end
    
    -- Check interactions with current status
    local canApply, interactionResult = StatusEffectsEngine.checkStatusInteractions(
        pokemon.statusEffect or "none", 
        statusEffect
    )
    if not canApply then
        return newPokemon, false, interactionResult
    end
    
    local effectData = STATUS_EFFECTS[statusEffect]
    if not effectData then
        return newPokemon, false, "Unknown status effect: " .. statusEffect
    end
    
    -- Apply environmental modifications
    if environmentalEffect and environmentalEffect.effects and environmentalEffect.effects.statusModifications then
        local envMod = environmentalEffect.effects.statusModifications[statusEffect]
        if envMod and envMod.preventApplication then
            return newPokemon, false, "Environmental effect prevents " .. statusEffect
        end
    end
    
    -- Set status effect
    newPokemon.statusEffect = statusEffect
    newPokemon.statusEffectData = deepCopy(effectData)
    
    -- Initialize TOXIC turn counter
    if statusEffect == "toxic" then
        newPokemon.toxicTurnCount = 1
    end
    
    -- Initialize SLEEP turns remaining (1-3 turns)
    if statusEffect == "sleep" then
        local sleepDuration = nextRandom(rngState, 1, 3)
        newPokemon.sleepTurnsRemaining = sleepDuration
    end
    
    -- Set duration if applicable (for other status effects)
    if effectData.duration and type(effectData.duration) == "table" then
        local duration = nextRandom(rngState, effectData.duration.min, effectData.duration.max)
        newPokemon.statusEffectData.remainingDuration = duration
    elseif effectData.duration and effectData.duration > 0 then
        newPokemon.statusEffectData.remainingDuration = effectData.duration
    end
    
    return newPokemon, true, "Status effect applied: " .. effectData.name
end

-- Calculate status damage with environmental modifiers
function StatusEffectsEngine.calculateStatusDamage(pokemon, statusData, environmentalEffect)
    if not statusData.damageOverTime then
        return 0
    end
    
    local baseDamage = 0
    local damagePercent = statusData.damagePercent or 0
    
    if statusData.name == "Toxic" then
        -- Toxic damage: 1/16 max HP * toxicTurnCount
        local toxicTurnCount = pokemon.toxicTurnCount or 1
        baseDamage = math.floor(pokemon.maxHp * damagePercent * toxicTurnCount)
    elseif statusData.name == "Poison" then
        -- Poison damage: Fixed 1/8 max HP per turn
        baseDamage = math.floor(pokemon.maxHp * 0.125)
    elseif statusData.name == "Burn" then
        -- Burn damage: Fixed 1/16 max HP per turn
        baseDamage = math.floor(pokemon.maxHp * 0.0625)
    else
        baseDamage = math.floor(pokemon.maxHp * damagePercent)
    end
    
    -- Apply environmental modifications
    if environmentalEffect and environmentalEffect.effects and environmentalEffect.effects.statusModifications then
        local envMod = environmentalEffect.effects.statusModifications[statusData.name:lower()]
        if envMod then
            if envMod.damageReduced then
                baseDamage = math.floor(baseDamage * 0.5)
            elseif envMod.damageBoosted then
                baseDamage = math.floor(baseDamage * 1.5)
            end
        end
    end
    
    return baseDamage
end

-- Process turn-based status effects
function StatusEffectsEngine.processStatusTurn(pokemon, rngState, environmentalEffect, turnNumber)
    local newPokemon = deepCopy(pokemon)
    local effects = {}
    
    if not newPokemon.statusEffect or newPokemon.statusEffect == "none" then
        return newPokemon, effects
    end
    
    local statusData = newPokemon.statusEffectData
    if not statusData then
        return newPokemon, effects
    end
    
    -- Process damage over time effects
    if statusData.damageOverTime then
        local damage = StatusEffectsEngine.calculateStatusDamage(newPokemon, statusData, environmentalEffect)
        if damage > 0 then
            newPokemon.hp = math.max(0, newPokemon.hp - damage)
            table.insert(effects, {
                type = "damage",
                source = statusData.name,
                damage = damage,
                message = newPokemon.name .. " is hurt by " .. statusData.name:lower() .. "!"
            })
            
            -- Increment toxicTurnCount for toxic status
            if statusData.name == "Toxic" then
                newPokemon.toxicTurnCount = (newPokemon.toxicTurnCount or 1) + 1
            end
        end
    end
    
    -- Process turn-end effects
    if statusData.turnEndEffect then
        if statusData.turnEndEffect == "checkWakeUp" then
            -- Decrement sleepTurnsRemaining
            if newPokemon.sleepTurnsRemaining then
                newPokemon.sleepTurnsRemaining = newPokemon.sleepTurnsRemaining - 1
                if newPokemon.sleepTurnsRemaining <= 0 then
                    newPokemon.statusEffect = "none"
                    newPokemon.statusEffectData = nil
                    newPokemon.sleepTurnsRemaining = nil
                    table.insert(effects, {
                        type = "cure",
                        source = "naturalRecovery",
                        message = newPokemon.name .. " woke up!"
                    })
                end
            end
            
        elseif statusData.turnEndEffect == "checkThaw" then
            local thawChance = statusData.interactions and statusData.interactions.thawChance or 0.2
            local thawRoll = nextRandom(rngState, 1, 100) / 100
            if thawRoll <= thawChance then
                newPokemon.statusEffect = "none"
                newPokemon.statusEffectData = nil
                table.insert(effects, {
                    type = "cure",
                    source = "naturalThaw",
                    message = newPokemon.name .. " thawed out!"
                })
            end
            
        elseif statusData.turnEndEffect == "checkConfusion" then
            if statusData.remainingDuration and statusData.remainingDuration <= 1 then
                newPokemon.statusEffect = "none"
                newPokemon.statusEffectData = nil
                table.insert(effects, {
                    type = "cure",
                    source = "naturalRecovery",
                    message = newPokemon.name .. " snapped out of confusion!"
                })
            end
            
        elseif statusData.turnEndEffect == "removeFlinch" then
            newPokemon.statusEffect = "none"
            newPokemon.statusEffectData = nil
        end
    end
    
    -- Decrease duration for timed effects
    if statusData.remainingDuration and statusData.remainingDuration > 0 then
        newPokemon.statusEffectData.remainingDuration = statusData.remainingDuration - 1
    end
    
    -- Check for fainting
    if newPokemon.hp <= 0 then
        newPokemon.hp = 0
        newPokemon.statusEffect = "faint"
        newPokemon.statusEffectData = deepCopy(STATUS_EFFECTS.faint)
        table.insert(effects, {
            type = "faint",
            source = "statusDamage",
            message = newPokemon.name .. " fainted!"
        })
    end
    
    return newPokemon, effects
end

-- Remove status effect with method validation
function StatusEffectsEngine.removeStatusEffect(pokemon, cureMethod, rngState)
    local newPokemon = deepCopy(pokemon)
    
    if not newPokemon.statusEffect or newPokemon.statusEffect == "none" then
        return newPokemon, false, "Pokemon has no status effect to cure"
    end
    
    local statusData = newPokemon.statusEffectData
    if not statusData then
        return newPokemon, false, "No status data found"
    end
    
    -- Check if cure method is valid for this status
    if statusData.interactions and statusData.interactions.curedBy then
        for _, cureCondition in ipairs(statusData.interactions.curedBy) do
            if cureCondition == cureMethod then
                local oldStatus = newPokemon.statusEffect
                newPokemon.statusEffect = "none"
                newPokemon.statusEffectData = nil
                -- Reset toxic turn counter
                if oldStatus == "toxic" then
                    newPokemon.toxicTurnCount = nil
                end
                -- Reset sleep turns remaining
                if oldStatus == "sleep" then
                    newPokemon.sleepTurnsRemaining = nil
                end
                return newPokemon, true, "Status effect " .. oldStatus .. " cured by " .. cureMethod
            end
        end
    end
    
    return newPokemon, false, "Cannot cure " .. newPokemon.statusEffect .. " with method: " .. cureMethod
end

-- Check move restrictions from status effects
function StatusEffectsEngine.checkMoveRestrictions(pokemon, move, rngState)
    if not pokemon.statusEffect or pokemon.statusEffect == "none" then
        return true, nil, nil
    end
    
    local statusData = pokemon.statusEffectData
    if not statusData or not statusData.moveRestrictions then
        return true, nil, nil
    end
    
    local restrictions = statusData.moveRestrictions
    
    -- Check if Pokemon cannot move at all
    if restrictions.cannotMove then
        -- Check for allowed moves (like Sleep Talk during sleep)
        if statusData.interactions and statusData.interactions.allowedMoves then
            for _, allowedMove in ipairs(statusData.interactions.allowedMoves) do
                if move and move.name == allowedMove then
                    return true, nil, nil
                end
            end
        end
        return false, pokemon.name .. " is " .. statusData.name:lower() .. " and cannot move!"
    end
    
    -- Check chance-based restrictions
    if restrictions.chanceToNotMove then
        local moveRoll = nextRandom(rngState, 1, 100) / 100
        if moveRoll <= restrictions.chanceToNotMove then
            local message = pokemon.name .. " is fully paralyzed and cannot move!"
            if statusData.name == "Infatuation" then
                message = pokemon.name .. " is immobilized by love!"
            end
            return false, message
        end
    end
    
    -- Check chance to hurt self (confusion)
    if restrictions.chanceToHurtSelf then
        local confusionRoll = nextRandom(rngState, 1, 100) / 100
        if confusionRoll <= restrictions.chanceToHurtSelf then
            local selfDamagePercent = statusData.interactions and statusData.interactions.selfDamagePercent or 0.125
            local confusionDamage = math.floor(pokemon.maxHp * selfDamagePercent)
            return false, pokemon.name .. " hurt itself in its confusion!", confusionDamage
        end
    end
    
    return true, nil, nil
end

-- Apply stat modifiers from status effects
function StatusEffectsEngine.applyStatModifiers(pokemon)
    if not pokemon.statusEffect or pokemon.statusEffect == "none" then
        return pokemon.stats or {}
    end
    
    local statusData = pokemon.statusEffectData
    if not statusData or not statusData.statModifiers then
        return pokemon.stats or {}
    end
    
    local modifiedStats = deepCopy(pokemon.stats or {})
    
    for stat, modifier in pairs(statusData.statModifiers) do
        if modifiedStats[stat] then
            modifiedStats[stat] = math.floor(modifiedStats[stat] * modifier)
        end
    end
    
    return modifiedStats
end

-- Process environmental effects on status conditions
function StatusEffectsEngine.processEnvironmentalEffects(gameState, environmentalEffectType, duration)
    local newGameState = deepCopy(gameState)
    
    if not newGameState.battle then
        return newGameState, false, "No battle in progress"
    end
    
    local effectData = ENVIRONMENTAL_EFFECTS[environmentalEffectType]
    if not effectData then
        return newGameState, false, "Unknown environmental effect: " .. environmentalEffectType
    end
    
    newGameState.battle.environmentalEffect = {
        type = environmentalEffectType,
        name = effectData.name,
        effects = deepCopy(effectData.effects),
        remainingDuration = duration or effectData.duration or 5,
        turnApplied = newGameState.battle.turnNumber or 1
    }
    
    return newGameState, true, "Environmental effect applied: " .. effectData.name
end

-- Main operation handler
function StatusEffectsEngine.handleOperation(gameState, operation, parameters, rngState)
    if operation == "applyStatusEffect" then
        local pokemonIndex = parameters.pokemonIndex
        local statusEffect = parameters.statusEffect
        local environmentalEffect = gameState.battle and gameState.battle.environmentalEffect
        
        if not pokemonIndex or not statusEffect then
            error("pokemonIndex and statusEffect parameters are required")
        end
        
        local newGameState = deepCopy(gameState)
        local pokemon = newGameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local modifiedPokemon, success, message = StatusEffectsEngine.applyStatusEffect(
            pokemon, statusEffect, rngState, environmentalEffect
        )
        
        newGameState.player.party[pokemonIndex] = modifiedPokemon
        
        return {
            gameState = newGameState,
            success = success,
            message = message,
            appliedEffect = success and statusEffect or nil
        }
        
    elseif operation == "processStatusTurn" then
        local pokemonIndex = parameters.pokemonIndex
        local turnNumber = parameters.turnNumber or 1
        local environmentalEffect = gameState.battle and gameState.battle.environmentalEffect
        
        if not pokemonIndex then
            error("pokemonIndex parameter is required")
        end
        
        local newGameState = deepCopy(gameState)
        local pokemon = newGameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local modifiedPokemon, effects = StatusEffectsEngine.processStatusTurn(
            pokemon, rngState, environmentalEffect, turnNumber
        )
        
        newGameState.player.party[pokemonIndex] = modifiedPokemon
        
        return {
            gameState = newGameState,
            effects = effects,
            pokemon = modifiedPokemon
        }
        
    elseif operation == "removeStatusEffect" then
        local pokemonIndex = parameters.pokemonIndex
        local cureMethod = parameters.cureMethod
        
        if not pokemonIndex or not cureMethod then
            error("pokemonIndex and cureMethod parameters are required")
        end
        
        local newGameState = deepCopy(gameState)
        local pokemon = newGameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local modifiedPokemon, success, message = StatusEffectsEngine.removeStatusEffect(
            pokemon, cureMethod, rngState
        )
        
        newGameState.player.party[pokemonIndex] = modifiedPokemon
        
        return {
            gameState = newGameState,
            success = success,
            message = message
        }
        
    elseif operation == "checkStatusInteractions" then
        local pokemonIndex = parameters.pokemonIndex
        local newStatusEffect = parameters.newStatusEffect
        
        if not pokemonIndex or not newStatusEffect then
            error("pokemonIndex and newStatusEffect parameters are required")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local immune, immunityReason = StatusEffectsEngine.checkStatusImmunity(pokemon, newStatusEffect)
        local canApply, interactionResult = StatusEffectsEngine.checkStatusInteractions(
            pokemon.statusEffect or "none", newStatusEffect
        )
        
        return {
            gameState = gameState,
            immune = immune,
            immunityReason = immunityReason,
            canApply = canApply,
            interactionResult = interactionResult
        }
        
    elseif operation == "validateStatusImmunity" then
        local pokemonIndex = parameters.pokemonIndex
        local statusEffect = parameters.statusEffect
        
        if not pokemonIndex or not statusEffect then
            error("pokemonIndex and statusEffect parameters are required")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local immune, reason = StatusEffectsEngine.checkStatusImmunity(pokemon, statusEffect)
        
        return {
            gameState = gameState,
            immune = immune,
            reason = reason
        }
        
    elseif operation == "calculateStatusDamage" then
        local pokemonIndex = parameters.pokemonIndex
        local environmentalEffect = gameState.battle and gameState.battle.environmentalEffect
        
        if not pokemonIndex then
            error("pokemonIndex parameter is required")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        if not pokemon.statusEffectData then
            return {
                gameState = gameState,
                damage = 0,
                message = "No status effect to calculate damage for"
            }
        end
        
        local damage = StatusEffectsEngine.calculateStatusDamage(pokemon, pokemon.statusEffectData, environmentalEffect)
        
        return {
            gameState = gameState,
            damage = damage,
            statusEffect = pokemon.statusEffect
        }
        
    elseif operation == "processEnvironmentalEffects" then
        local effectType = parameters.effectType
        local duration = parameters.duration
        
        if not effectType then
            error("effectType parameter is required")
        end
        
        local newGameState, success, message = StatusEffectsEngine.processEnvironmentalEffects(
            gameState, effectType, duration
        )
        
        return {
            gameState = newGameState,
            success = success,
            message = message
        }
        
    else
        error("Unknown operation: " .. operation)
    end
end

-- ====================================
-- MESSAGE HANDLERS (ADP v1.0 COMPLIANT)
-- ====================================

-- Main process logic handler
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        startPerformanceMonitoring()
        
        local isValid, validationError = validateInput(msg)
        if not isValid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = validationError,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
            return
        end
        
        local senderAddress = msg.From or "unknown"
        local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
        if not rateLimitOk then
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = rateLimitError,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
            return
        end
        
        -- Extract simple operation from tag, complex data from JSON
        local operation = msg.Operation
        local data = json.decode(msg.Data or "{}")
        local gameState = data.gameState
        local parameters = data.parameters or {}
        
        if not operation then
            error("Operation tag is required")
        end
        
        -- Initialize RNG with battle seed and turn number
        local turnNumber = (gameState.battle and gameState.battle.turnNumber) or 1
        local rngState = nil
        if gameState.battle and gameState.battle.battleSeed then
            local rngInitSuccess, rngError = initializeRNG(gameState.battle.battleSeed, turnNumber)
            if not rngInitSuccess then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "RNG initialization failed: " .. rngError,
                    Timestamp = tostring(msg and msg.Timestamp or 0)
                })
                return
            end
            rngState = rngInitSuccess
        end
        
        local success, result = pcall(function()
            return StatusEffectsEngine.handleOperation(gameState, operation, parameters, rngState)
        end)
        
        local responseTime = endPerformanceMonitoring()
        if responseTime and responseTime > OPERATION_TIMEOUT then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Operation exceeded " .. OPERATION_TIMEOUT .. "ms timeout",
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
            return
        end
        
        if success then
            if result and result.gameState then
                result.gameState.timestamp = msg and msg.Timestamp or 0
                result.gameState.version = (gameState.version or 0) + 1
            end
            
            ao.send({
                Target = msg.From,
                Action = "ProcessResult",
                Data = result,
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Operation failed: " .. tostring(result),
                Timestamp = tostring(msg and msg.Timestamp or 0)
            })
        end
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus",
            Data = {
                processId = ao.id,
                processType = "status-effects-engine",
                status = "healthy",
                timestamp = msg and msg.Timestamp or 0,
                capabilities = PROCESS_METADATA.capabilities,
                version = PROCESS_METADATA.version
            },
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- Info handler for ADP v1.0 compliance
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = {
                process = PROCESS_METADATA,
                handlers = {
                    "ProcessLogic",
                    "HealthCheck", 
                    "Info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Comprehensive Pokemon status effects management system with damage calculations, probability checks, and interaction rules supporting all major and minor status conditions"
                }
            },
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- AO processes should not return module exports
-- All data is handled through message passing via ao.send()
print("Status Effects Engine initialization complete.")