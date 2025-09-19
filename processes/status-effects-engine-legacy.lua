-- Status Effects Engine Process for PokéRogue AO
-- Handles status condition application, environmental effects, and battle condition management
-- Implements pure computation on GameState with status effect logic
-- Monolithic process - all dependencies embedded (no external imports)

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end }

-- Status Effects Engine process identifier
local PROCESS_ID = "status-effects-engine"

-- Performance monitoring configuration (5 second limit for logic operations)
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local performanceStartTime = nil

-- Rate limiting configuration (stricter for logic processes)
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}

-- Status effect types and their properties (embedded data)
local STATUS_EFFECTS = {
    none = {
        name = "None",
        duration = 0,
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {},
        turnEndEffect = nil
    },
    sleep = {
        name = "Sleep",
        duration = {min = 1, max = 3}, -- 1-3 turns
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true},
        turnEndEffect = "checkWakeUp",
        cureConditions = {"damage", "switch"}
    },
    paralysis = {
        name = "Paralysis",
        duration = -1, -- Permanent until cured
        damageOverTime = false,
        statModifiers = {speed = 0.25}, -- 75% speed reduction
        moveRestrictions = {chanceToNotMove = 0.25}, -- 25% chance to be fully paralyzed
        turnEndEffect = nil,
        cureConditions = {"switch", "heal"}
    },
    burn = {
        name = "Burn",
        duration = -1, -- Permanent until cured
        damageOverTime = true,
        damagePercent = 0.0625, -- 1/16 of max HP per turn
        statModifiers = {attack = 0.5}, -- 50% attack reduction
        moveRestrictions = {},
        turnEndEffect = "applyBurnDamage",
        cureConditions = {"switch", "heal"}
    },
    poison = {
        name = "Poison",
        duration = -1, -- Permanent until cured
        damageOverTime = true,
        damagePercent = 0.125, -- 1/8 of max HP per turn
        statModifiers = {},
        moveRestrictions = {},
        turnEndEffect = "applyPoisonDamage",
        cureConditions = {"switch", "heal"}
    },
    badlyPoisoned = {
        name = "Badly Poisoned",
        duration = -1, -- Permanent until cured
        damageOverTime = true,
        damagePercent = 0.0625, -- Starts at 1/16, increases each turn
        statModifiers = {},
        moveRestrictions = {},
        turnEndEffect = "applyBadPoisonDamage",
        cureConditions = {"switch", "heal"},
        counter = 1 -- Tracks turns for increasing damage
    },
    freeze = {
        name = "Freeze",
        duration = -1, -- Until thawed
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true},
        turnEndEffect = "checkThaw",
        cureConditions = {"fireMove", "switch"},
        thawChance = 0.2 -- 20% chance to thaw each turn
    },
    confused = {
        name = "Confused",
        duration = {min = 1, max = 4}, -- 1-4 turns
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {chanceToHurtSelf = 0.33}, -- 33% chance to hurt self
        turnEndEffect = "checkConfusion",
        cureConditions = {"switch"}
    },
    faint = {
        name = "Faint",
        duration = -1, -- Until revived
        damageOverTime = false,
        statModifiers = {},
        moveRestrictions = {cannotMove = true, cannotBeTargeted = true},
        turnEndEffect = nil,
        cureConditions = {"revive"}
    }
}

-- Environmental effects and field conditions
local ENVIRONMENTAL_EFFECTS = {
    none = {
        name = "None",
        effects = {}
    },
    sunny = {
        name = "Sunny Day",
        duration = 5,
        effects = {
            fireMovePowerBoost = 1.5,
            waterMovePowerReduction = 0.5,
            solarBeamNoCharge = true,
            synthesisBoosted = true
        }
    },
    rain = {
        name = "Rain",
        duration = 5,
        effects = {
            waterMovePowerBoost = 1.5,
            fireMovePowerReduction = 0.5,
            thunderAlwaysHits = true,
            synthesiisReduced = true
        }
    },
    sandstorm = {
        name = "Sandstorm",
        duration = 5,
        effects = {
            rockTypeSpDefBoost = 1.5,
            damageNonGroundRockSteel = 0.0625, -- 1/16 max HP
            weatherBallPower = 100,
            weatherBallType = "rock"
        }
    },
    hail = {
        name = "Hail",
        duration = 5,
        effects = {
            damageNonIce = 0.0625, -- 1/16 max HP
            blizzardAlwaysHits = true,
            weatherBallPower = 100,
            weatherBallType = "ice"
        }
    }
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

-- Deterministic RNG using battle seed
local function initializeRNG(battleSeed)
    if not battleSeed or type(battleSeed) ~= "string" then
        return nil, "Battle seed is required for deterministic RNG"
    end
    
    local seedValue = 0
    for i = 1, #battleSeed do
        seedValue = seedValue + string.byte(battleSeed, i) * i
    end
    
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

-- ====================================
-- STATUS EFFECTS ENGINE CORE FUNCTIONS
-- ====================================

local StatusEffectsEngine = {}

-- Apply status effect to Pokemon
function StatusEffectsEngine.applyStatusEffect(pokemon, statusEffect, rngState)
    local newPokemon = deepCopy(pokemon)
    local effectData = STATUS_EFFECTS[statusEffect]
    
    if not effectData then
        error("Unknown status effect: " .. statusEffect)
    end
    
    -- Cannot apply status if already has one (except for certain combinations)
    if newPokemon.statusEffect and newPokemon.statusEffect ~= "none" then
        if not StatusEffectsEngine.canReplaceStatus(newPokemon.statusEffect, statusEffect) then
            return newPokemon, false, "Pokemon already has status effect: " .. newPokemon.statusEffect
        end
    end
    
    -- Set status effect
    newPokemon.statusEffect = statusEffect
    newPokemon.statusEffectData = deepCopy(effectData)
    
    -- Set duration if applicable
    if effectData.duration and type(effectData.duration) == "table" then
        local duration = nextRandom(rngState, effectData.duration.min, effectData.duration.max)
        newPokemon.statusEffectData.remainingDuration = duration
    elseif effectData.duration and effectData.duration > 0 then
        newPokemon.statusEffectData.remainingDuration = effectData.duration
    end
    
    -- Initialize counters for effects like badly poisoned
    if effectData.counter then
        newPokemon.statusEffectData.counter = effectData.counter
    end
    
    return newPokemon, true, "Status effect applied: " .. effectData.name
end

-- Check if one status can replace another
function StatusEffectsEngine.canReplaceStatus(currentStatus, newStatus)
    -- Generally, status effects cannot be replaced
    -- Exceptions: sleep can be replaced by paralysis from certain moves
    local replacements = {
        sleep = {"paralysis"}, -- Sleep can be replaced by some moves
        none = {"sleep", "paralysis", "burn", "poison", "badlyPoisoned", "freeze", "confused"}
    }
    
    local allowedReplacements = replacements[currentStatus] or {}
    for _, allowed in ipairs(allowedReplacements) do
        if allowed == newStatus then
            return true
        end
    end
    
    return false
end

-- Process turn-end status effects
function StatusEffectsEngine.processTurnEndEffects(pokemon, rngState)
    local newPokemon = deepCopy(pokemon)
    local effects = {}
    
    if not newPokemon.statusEffect or newPokemon.statusEffect == "none" then
        return newPokemon, effects
    end
    
    local statusData = newPokemon.statusEffectData
    if not statusData then
        return newPokemon, effects
    end
    
    -- Process specific turn-end effects
    if statusData.turnEndEffect == "applyBurnDamage" then
        local damage = math.floor(newPokemon.maxHp * (statusData.damagePercent or 0.0625))
        newPokemon.hp = math.max(0, newPokemon.hp - damage)
        table.insert(effects, {
            type = "damage",
            source = "burn",
            damage = damage,
            message = newPokemon.name .. " is hurt by its burn!"
        })
        
    elseif statusData.turnEndEffect == "applyPoisonDamage" then
        local damage = math.floor(newPokemon.maxHp * (statusData.damagePercent or 0.125))
        newPokemon.hp = math.max(0, newPokemon.hp - damage)
        table.insert(effects, {
            type = "damage",
            source = "poison",
            damage = damage,
            message = newPokemon.name .. " is hurt by poison!"
        })
        
    elseif statusData.turnEndEffect == "applyBadPoisonDamage" then
        local counter = statusData.counter or 1
        local damage = math.floor(newPokemon.maxHp * (statusData.damagePercent or 0.0625) * counter)
        newPokemon.hp = math.max(0, newPokemon.hp - damage)
        newPokemon.statusEffectData.counter = counter + 1
        table.insert(effects, {
            type = "damage",
            source = "badlyPoisoned",
            damage = damage,
            message = newPokemon.name .. " is hurt by poison!"
        })
        
    elseif statusData.turnEndEffect == "checkWakeUp" then
        -- Sleep naturally ends after duration
        if statusData.remainingDuration and statusData.remainingDuration <= 1 then
            newPokemon.statusEffect = "none"
            newPokemon.statusEffectData = nil
            table.insert(effects, {
                type = "cure",
                source = "naturalRecovery",
                message = newPokemon.name .. " woke up!"
            })
        end
        
    elseif statusData.turnEndEffect == "checkThaw" then
        -- Chance to thaw from freeze
        local thawChance = statusData.thawChance or 0.2
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
        -- Confusion duration countdown
        if statusData.remainingDuration and statusData.remainingDuration <= 1 then
            newPokemon.statusEffect = "none"
            newPokemon.statusEffectData = nil
            table.insert(effects, {
                type = "cure",
                source = "naturalRecovery",
                message = newPokemon.name .. " snapped out of confusion!"
            })
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

-- Apply environmental effect to battle
function StatusEffectsEngine.applyEnvironmentalEffect(gameState, effectType, duration)
    local newGameState = deepCopy(gameState)
    
    if not newGameState.battle then
        error("No battle in progress")
    end
    
    local effectData = ENVIRONMENTAL_EFFECTS[effectType]
    if not effectData then
        error("Unknown environmental effect: " .. effectType)
    end
    
    -- Set environmental effect
    newGameState.battle.environmentalEffect = {
        type = effectType,
        name = effectData.name,
        effects = deepCopy(effectData.effects),
        remainingDuration = duration or effectData.duration or 5
    }
    
    return newGameState
end

-- Check move restrictions due to status effects
function StatusEffectsEngine.checkMoveRestrictions(pokemon, move, rngState)
    if not pokemon.statusEffect or pokemon.statusEffect == "none" then
        return true, nil -- No restrictions
    end
    
    local statusData = pokemon.statusEffectData
    if not statusData or not statusData.moveRestrictions then
        return true, nil
    end
    
    local restrictions = statusData.moveRestrictions
    
    -- Check if Pokemon cannot move at all
    if restrictions.cannotMove then
        return false, pokemon.name .. " is " .. (statusData.name or "unable to move") .. " and cannot move!"
    end
    
    -- Check chance-based restrictions
    if restrictions.chanceToNotMove then
        local moveRoll = nextRandom(rngState, 1, 100) / 100
        if moveRoll <= restrictions.chanceToNotMove then
            return false, pokemon.name .. " is fully paralyzed and cannot move!"
        end
    end
    
    -- Check chance to hurt self (confusion)
    if restrictions.chanceToHurtSelf then
        local confusionRoll = nextRandom(rngState, 1, 100) / 100
        if confusionRoll <= restrictions.chanceToHurtSelf then
            -- Calculate confusion damage
            local confusionDamage = math.floor(pokemon.maxHp * 0.125) -- 1/8 max HP
            return false, pokemon.name .. " hurt itself in its confusion!", confusionDamage
        end
    end
    
    return true, nil
end

-- Apply stat modifiers from status effects
function StatusEffectsEngine.applyStatModifiers(pokemon)
    if not pokemon.statusEffect or pokemon.statusEffect == "none" then
        return pokemon.stats
    end
    
    local statusData = pokemon.statusEffectData
    if not statusData or not statusData.statModifiers then
        return pokemon.stats
    end
    
    local modifiedStats = deepCopy(pokemon.stats)
    
    for stat, modifier in pairs(statusData.statModifiers) do
        if modifiedStats[stat] then
            modifiedStats[stat] = math.floor(modifiedStats[stat] * modifier)
        end
    end
    
    return modifiedStats
end

-- Cure status effects
function StatusEffectsEngine.cureStatusEffect(pokemon, cureMethod)
    local newPokemon = deepCopy(pokemon)
    
    if not newPokemon.statusEffect or newPokemon.statusEffect == "none" then
        return newPokemon, false, "Pokemon has no status effect to cure"
    end
    
    local statusData = newPokemon.statusEffectData
    if statusData and statusData.cureConditions then
        for _, condition in ipairs(statusData.cureConditions) do
            if condition == cureMethod then
                newPokemon.statusEffect = "none"
                newPokemon.statusEffectData = nil
                return newPokemon, true, "Status effect cured"
            end
        end
    end
    
    return newPokemon, false, "Cannot cure status effect with method: " .. cureMethod
end

-- Main logic handler for status effects operations
function StatusEffectsEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "applyStatusEffect" then
        local pokemonIndex = parameters.pokemonIndex
        local statusEffect = parameters.statusEffect
        
        if not pokemonIndex or not statusEffect then
            error("pokemonIndex and statusEffect parameters are required for applyStatusEffect operation")
        end
        
        local newGameState = deepCopy(gameState)
        if not newGameState.player.party[pokemonIndex] then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local modifiedPokemon, success, message = StatusEffectsEngine.applyStatusEffect(
            newGameState.player.party[pokemonIndex], 
            statusEffect, 
            rngState
        )
        
        newGameState.player.party[pokemonIndex] = modifiedPokemon
        
        return {
            gameState = newGameState,
            success = success,
            message = message
        }
        
    elseif operation == "processTurnEndEffects" then
        local pokemonIndex = parameters.pokemonIndex
        
        if not pokemonIndex then
            error("pokemonIndex parameter is required for processTurnEndEffects operation")
        end
        
        local newGameState = deepCopy(gameState)
        if not newGameState.player.party[pokemonIndex] then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local modifiedPokemon, effects = StatusEffectsEngine.processTurnEndEffects(
            newGameState.player.party[pokemonIndex], 
            rngState
        )
        
        newGameState.player.party[pokemonIndex] = modifiedPokemon
        
        return {
            gameState = newGameState,
            effects = effects
        }
        
    elseif operation == "applyEnvironmentalEffect" then
        local effectType = parameters.effectType
        local duration = parameters.duration
        
        if not effectType then
            error("effectType parameter is required for applyEnvironmentalEffect operation")
        end
        
        local newGameState = StatusEffectsEngine.applyEnvironmentalEffect(gameState, effectType, duration)
        
        return {
            gameState = newGameState,
            effectApplied = effectType
        }
        
    elseif operation == "checkMoveRestrictions" then
        local pokemonIndex = parameters.pokemonIndex
        local move = parameters.move
        
        if not pokemonIndex or not move then
            error("pokemonIndex and move parameters are required for checkMoveRestrictions operation")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local canMove, message, selfDamage = StatusEffectsEngine.checkMoveRestrictions(pokemon, move, rngState)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            canMove = canMove,
            message = message,
            selfDamage = selfDamage
        }
        
    elseif operation == "cureStatusEffect" then
        local pokemonIndex = parameters.pokemonIndex
        local cureMethod = parameters.cureMethod
        
        if not pokemonIndex or not cureMethod then
            error("pokemonIndex and cureMethod parameters are required for cureStatusEffect operation")
        end
        
        local newGameState = deepCopy(gameState)
        if not newGameState.player.party[pokemonIndex] then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local modifiedPokemon, success, message = StatusEffectsEngine.cureStatusEffect(
            newGameState.player.party[pokemonIndex], 
            cureMethod
        )
        
        newGameState.player.party[pokemonIndex] = modifiedPokemon
        
        return {
            gameState = newGameState,
            success = success,
            message = message
        }
        
    else
        error("Unknown status effects engine operation: " .. operation)
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
    
    local rngState = nil
    if originalGameState.battle and originalGameState.battle.battleSeed then
        local rngInitSuccess, rngError = initializeRNG(originalGameState.battle.battleSeed)
        if not rngInitSuccess then
            return {
                Action = "SaveState",
                Error = "RNG initialization failed: " .. rngError,
                GameState = originalGameState,
                ProcessId = PROCESS_ID,
                Timestamp = os.time()
            }
        end
        rngState = rngInitSuccess
    end
    
    local success, result = pcall(function()
        return StatusEffectsEngine.handleLogicOperation(originalGameState, operation, parameters, rngState)
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
-- AO MESSAGE HANDLERS
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
                processId = PROCESS_ID,
                processType = "logic",
                status = "healthy",
                timestamp = os.time(),
                operations = {
                    "applyStatusEffect",
                    "processTurnEndEffects",
                    "applyEnvironmentalEffect",
                    "checkMoveRestrictions",
                    "cureStatusEffect"
                }
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export for testing
return {
    StatusEffectsEngine = StatusEffectsEngine,
    PROCESS_ID = PROCESS_ID,
    STATUS_EFFECTS = STATUS_EFFECTS,
    ENVIRONMENTAL_EFFECTS = ENVIRONMENTAL_EFFECTS
}