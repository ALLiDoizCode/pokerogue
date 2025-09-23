-- Pokemon Capture Engine Process for PokéRogue AO
-- ADP v1.0 Compliant Process for capture probability calculations and mechanics
-- Handles deterministic capture attempts, Pokeball effectiveness, and status modifiers
-- Monolithic design - all dependencies embedded (no external imports)

-- ====================================
-- AO ENVIRONMENT GLOBALS
-- ====================================

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "capture-engine" }

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

-- ====================================
-- PROCESS CONFIGURATION
-- ====================================

local PROCESS_INFO = {
    name = "Pokemon Capture Engine",
    version = "1.0.0",
    adpVersion = "1.0",
    processId = "capture-engine",
    capabilities = {
        "calculateCaptureRate",
        "processCaptureAttempt", 
        "validateCaptureConditions",
        "deterministic_rng"
    },
    messageSchemas = {
        ProcessLogic = {
            required = {"Action", "Data", "Timestamp"},
            dataFields = {"gameState", "operation", "parameters"}
        },
        Info = {
            required = {"Action"},
            response = "process_metadata"
        },
        HealthCheck = {
            required = {"Action"},
            response = "status_report"
        }
    }
}

-- Performance and rate limiting
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}
local performanceStartTime = nil

-- ====================================
-- POKEBALL DATA AND CONSTANTS
-- ====================================

local POKEBALL_DATA = {
    pokeball = {
        name = "Poke Ball",
        catchRate = 1.0,
        bonusConditions = {}
    },
    greatball = {
        name = "Great Ball", 
        catchRate = 1.5,
        bonusConditions = {}
    },
    ultraball = {
        name = "Ultra Ball",
        catchRate = 2.0,
        bonusConditions = {}
    },
    masterball = {
        name = "Master Ball",
        catchRate = 255.0, -- Guaranteed catch
        bonusConditions = {}
    },
    netball = {
        name = "Net Ball",
        catchRate = 3.5,
        bonusConditions = {waterBug = true}
    },
    diveball = {
        name = "Dive Ball",
        catchRate = 3.5,
        bonusConditions = {underwater = true}
    },
    timerball = {
        name = "Timer Ball",
        catchRate = 1.0,
        bonusConditions = {timer = true}
    },
    quickball = {
        name = "Quick Ball",
        catchRate = 5.0,
        bonusConditions = {firstTurn = true}
    },
    duskball = {
        name = "Dusk Ball",
        catchRate = 3.5,
        bonusConditions = {darkTime = true}
    },
    repeatball = {
        name = "Repeat Ball",
        catchRate = 3.5,
        bonusConditions = {alreadyCaught = true}
    },
    luxuryball = {
        name = "Luxury Ball",
        catchRate = 1.0,
        bonusConditions = {friendship = true}
    },
    premierball = {
        name = "Premier Ball",
        catchRate = 1.0,
        bonusConditions = {}
    },
    healball = {
        name = "Heal Ball",
        catchRate = 1.0,
        bonusConditions = {heal = true}
    }
}

-- Status effect multipliers for capture rate
local STATUS_EFFECT_MULTIPLIERS = {
    none = 1.0,
    sleep = 2.5,
    freeze = 2.5,
    paralysis = 1.5,
    burn = 1.5,
    poison = 1.5,
    badly_poison = 1.5,
    confusion = 1.0, -- Confusion doesn't affect capture rate
    faint = 0.0 -- Cannot catch fainted Pokemon
}

-- ====================================
-- UTILITY FUNCTIONS
-- ====================================

-- Deep copy utility for immutable state management
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

-- Input validation for capture operations
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
        return false, "Data.gameState is required for capture operations"
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

-- Rate limiting protection
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

-- ====================================
-- DETERMINISTIC RNG SYSTEM
-- ====================================

-- Initialize deterministic RNG using battle seed
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

-- Generate next deterministic random number
local function nextRandom(rngState, min, max)
    if not rngState then
        error("RNG state is required for deterministic random generation")
    end
    
    rngState.counter = rngState.counter + 1
    
    -- Linear congruential generator parameters
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
-- CAPTURE ENGINE CORE LOGIC
-- ====================================

local CaptureEngine = {}

-- Calculate comprehensive capture rate based on all factors
function CaptureEngine.calculateCaptureRate(pokemon, pokeballType, battleConditions, rngState)
    local baseRate = pokemon.catchRate or 45 -- Default catch rate
    local ballData = POKEBALL_DATA[pokeballType] or POKEBALL_DATA.pokeball
    
    -- Core HP calculation using official Pokemon formula
    -- Rate = (HP_max * 3 - HP_current * 2) * species_rate * ball_rate / (HP_max * 3)
    local currentHp = math.max(1, pokemon.hp) -- Prevent division by zero
    local maxHp = pokemon.maxHp or 100
    local hpFactor = ((maxHp * 3 - currentHp * 2) * baseRate) / (maxHp * 3)
    
    -- Apply pokeball base modifier
    local ballModifier = ballData.catchRate
    
    -- Apply pokeball-specific bonuses
    if ballData.bonusConditions then
        -- Net Ball bonus for Water/Bug types
        if ballData.bonusConditions.waterBug and (
            pokemon.type1 == "water" or pokemon.type1 == "bug" or 
            pokemon.type2 == "water" or pokemon.type2 == "bug") then
            ballModifier = ballModifier * 1.5
        end
        
        -- Quick Ball bonus on first turn
        if ballData.bonusConditions.firstTurn and battleConditions.turn == 1 then
            ballModifier = ballModifier * 2.0
        end
        
        -- Timer Ball bonus increases with turn count
        if ballData.bonusConditions.timer and battleConditions.turn then
            local timerBonus = math.min(4.0, 1.0 + (battleConditions.turn * 0.3))
            ballModifier = ballModifier * timerBonus
        end
        
        -- Dusk Ball bonus in caves or at night
        if ballData.bonusConditions.darkTime and 
           (battleConditions.environment == "cave" or battleConditions.timeOfDay == "night") then
            ballModifier = ballModifier * 1.5
        end
        
        -- Repeat Ball bonus if species already caught
        if ballData.bonusConditions.alreadyCaught and battleConditions.pokedexCaught then
            ballModifier = ballModifier * 1.5
        end
        
        -- Dive Ball bonus for underwater encounters
        if ballData.bonusConditions.underwater and battleConditions.environment == "underwater" then
            ballModifier = ballModifier * 1.5
        end
    end
    
    -- Apply status effect multiplier
    local statusMultiplier = STATUS_EFFECT_MULTIPLIERS[pokemon.statusEffect] or STATUS_EFFECT_MULTIPLIERS.none
    
    -- Calculate final capture rate
    local finalRate = hpFactor * ballModifier * statusMultiplier
    
    -- Convert to capture value (0-255 scale)
    local captureValue = math.min(255, finalRate * 255 / 100)
    
    return {
        captureValue = captureValue,
        probability = captureValue / 255,
        hpFactor = hpFactor,
        ballModifier = ballModifier,
        statusMultiplier = statusMultiplier,
        finalRate = finalRate,
        pokeball = pokeballType,
        validCapture = statusMultiplier > 0
    }
end

-- Process capture attempt with shake mechanics
function CaptureEngine.attemptCapture(captureRate, rngState)
    local captureValue = captureRate.captureValue
    
    -- Master Ball always succeeds
    if captureValue >= 255 then
        return {
            success = true,
            criticalCapture = false,
            shakeCount = 0,
            captureValue = captureValue,
            guaranteed = true
        }
    end
    
    -- Check for critical capture (rare occurrence that skips shakes)
    local criticalCaptureChance = math.max(0, (captureValue - 100) / 6)
    local criticalRoll = nextRandom(rngState, 0, 255)
    local criticalCapture = criticalRoll < criticalCaptureChance
    
    if criticalCapture then
        local finalCaptureRoll = nextRandom(rngState, 0, 255)
        return {
            success = finalCaptureRoll < captureValue,
            criticalCapture = true,
            shakeCount = finalCaptureRoll < captureValue and 1 or 0,
            captureValue = captureValue,
            guaranteed = false
        }
    end
    
    -- Normal capture with shake calculation (up to 3 shakes)
    local shakeCount = 0
    local success = true
    
    for shake = 1, 3 do
        -- Calculate shake probability using standard formula
        local shakeValue = (65536 * math.sqrt(math.sqrt(captureValue / 255))) / 255
        local shakeRoll = nextRandom(rngState, 0, 65535)
        
        if shakeRoll < shakeValue then
            shakeCount = shake
        else
            success = false
            break
        end
        
        -- If we reach 3 shakes, capture succeeds
        if shake == 3 then
            shakeCount = 3
            success = true
        end
    end
    
    return {
        success = success,
        criticalCapture = false,
        shakeCount = shakeCount,
        captureValue = captureValue,
        guaranteed = false
    }
end

-- Validate capture conditions before attempt
function CaptureEngine.validateCaptureConditions(pokemon, gameState, battleConditions)
    local errors = {}
    
    -- Check if Pokemon is fainted
    if pokemon.hp <= 0 then
        table.insert(errors, "Cannot capture a fainted Pokemon")
    end
    
    -- Check if it's a trainer Pokemon
    if pokemon.isTrainerPokemon then
        table.insert(errors, "Cannot capture trainer Pokemon")
    end
    
    -- Check if player has pokeballs
    if gameState.player and gameState.player.inventory then
        local hasPokeballs = false
        for item, count in pairs(gameState.player.inventory) do
            if POKEBALL_DATA[item] and count > 0 then
                hasPokeballs = true
                break
            end
        end
        if not hasPokeballs then
            table.insert(errors, "No pokeballs available in inventory")
        end
    end
    
    -- Check battle state
    if battleConditions and battleConditions.battleEnded then
        table.insert(errors, "Cannot capture Pokemon after battle has ended")
    end
    
    return #errors == 0, errors
end

-- Add captured Pokemon to party or PC storage
function CaptureEngine.addPokemonToParty(gameState, capturedPokemon)
    local newGameState = deepCopy(gameState)
    
    -- Ensure player structure exists
    if not newGameState.player then
        newGameState.player = {party = {}}
    end
    if not newGameState.player.party then
        newGameState.player.party = {}
    end
    
    -- Check if party has space (max 6 Pokemon)
    if #newGameState.player.party < 6 then
        table.insert(newGameState.player.party, capturedPokemon)
        return newGameState, "party"
    else
        -- Add to PC storage
        if not newGameState.player.pcStorage then
            newGameState.player.pcStorage = {}
        end
        table.insert(newGameState.player.pcStorage, capturedPokemon)
        return newGameState, "pc"
    end
end

-- Process complete capture attempt with all mechanics
function CaptureEngine.processCaptureAttempt(gameState, pokeballType, targetPokemon, battleConditions, rngState)
    -- Validate capture conditions
    local isValid, validationErrors = CaptureEngine.validateCaptureConditions(targetPokemon, gameState, battleConditions)
    if not isValid then
        error("Capture validation failed: " .. table.concat(validationErrors, ", "))
    end
    
    -- Calculate capture rate with all modifiers
    local captureRate = CaptureEngine.calculateCaptureRate(targetPokemon, pokeballType, battleConditions, rngState)
    
    -- Attempt capture with shake mechanics
    local captureResult = CaptureEngine.attemptCapture(captureRate, rngState)
    
    if captureResult.success then
        -- Create captured Pokemon with metadata
        local capturedPokemon = deepCopy(targetPokemon)
        capturedPokemon.originalTrainer = gameState.playerId
        capturedPokemon.captureDate = msg and msg.Timestamp or 0
        capturedPokemon.pokeball = pokeballType
        capturedPokemon.captureLocation = battleConditions.location or "unknown"
        capturedPokemon.captureLevel = targetPokemon.level
        
        -- Add to party or PC
        local updatedGameState, location = CaptureEngine.addPokemonToParty(gameState, capturedPokemon)
        
        -- Update player inventory (remove used pokeball)
        if updatedGameState.player.inventory and updatedGameState.player.inventory[pokeballType] then
            updatedGameState.player.inventory[pokeballType] = 
                math.max(0, updatedGameState.player.inventory[pokeballType] - 1)
        end
        
        return {
            gameState = updatedGameState,
            captureSuccess = true,
            captureResult = captureResult,
            captureRate = captureRate,
            storageLocation = location,
            capturedPokemon = capturedPokemon
        }
    else
        -- Failed capture - only remove pokeball from inventory
        local updatedGameState = deepCopy(gameState)
        if updatedGameState.player.inventory and updatedGameState.player.inventory[pokeballType] then
            updatedGameState.player.inventory[pokeballType] = 
                math.max(0, updatedGameState.player.inventory[pokeballType] - 1)
        end
        
        return {
            gameState = updatedGameState,
            captureSuccess = false,
            captureResult = captureResult,
            captureRate = captureRate,
            storageLocation = nil,
            capturedPokemon = nil
        }
    end
end

-- Main operation handler
function CaptureEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "calculateCaptureRate" then
        local pokemon = parameters.pokemon
        local pokeballType = parameters.pokeballType
        local battleConditions = parameters.battleConditions or {}
        
        if not pokemon or not pokeballType then
            error("pokemon and pokeballType parameters are required for calculateCaptureRate operation")
        end
        
        local captureRate = CaptureEngine.calculateCaptureRate(pokemon, pokeballType, battleConditions, rngState)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            captureRate = captureRate
        }
        
    elseif operation == "processCaptureAttempt" then
        local pokeballType = parameters.pokeballType
        local targetPokemon = parameters.targetPokemon
        local battleConditions = parameters.battleConditions or {}
        
        if not pokeballType or not targetPokemon then
            error("pokeballType and targetPokemon parameters are required for processCaptureAttempt operation")
        end
        
        return CaptureEngine.processCaptureAttempt(gameState, pokeballType, targetPokemon, battleConditions, rngState)
        
    elseif operation == "validateCaptureConditions" then
        local pokemon = parameters.pokemon
        local battleConditions = parameters.battleConditions or {}
        
        if not pokemon then
            error("pokemon parameter is required for validateCaptureConditions operation")
        end
        
        local isValid, errors = CaptureEngine.validateCaptureConditions(pokemon, gameState, battleConditions)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            validationResult = {
                isValid = isValid,
                errors = errors
            }
        }
        
    else
        error("Unknown capture engine operation: " .. operation)
    end
end

-- ====================================
-- MESSAGE PROCESSING
-- ====================================

local function handleMessage(message)
    startPerformanceMonitoring()
    
    local isValid, validationError = validateInput(message)
    if not isValid then
        return {
            Action = "SaveState",
            Error = validationError,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
    
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
    if not rateLimitOk then
        return {
            Action = "SaveState",
            Error = rateLimitError,
            GameState = message.Data.gameState,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
    
    local originalGameState = message.Data.gameState
    local operation = message.Data.operation
    local parameters = message.Data.parameters or {}
    
    -- Initialize deterministic RNG if battle seed available
    local rngState = nil
    if originalGameState.battle and originalGameState.battle.battleSeed then
        local rngInitSuccess, rngError = initializeRNG(originalGameState.battle.battleSeed)
        if not rngInitSuccess then
            return {
                Action = "SaveState",
                Error = "RNG initialization failed: " .. rngError,
                GameState = originalGameState,
                ProcessId = PROCESS_INFO.processId,
                Timestamp = msg and msg.Timestamp or 0
            }
        end
        rngState = rngInitSuccess
    end
    
    local success, result = pcall(function()
        return CaptureEngine.handleLogicOperation(originalGameState, operation, parameters, rngState)
    end)
    
    local responseTime = endPerformanceMonitoring()
    if responseTime and responseTime > LOGIC_OPERATION_TIMEOUT then
        return {
            Action = "SaveState",
            Error = "Logic operation exceeded " .. LOGIC_OPERATION_TIMEOUT .. "ms timeout (took " .. responseTime .. "ms)",
            GameState = originalGameState,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
    
    if success then
        if result and result.gameState then
            result.gameState.timestamp = msg and msg.Timestamp or 0
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
            Timestamp = msg and msg.Timestamp or 0,
            ProcessId = PROCESS_INFO.processId
        }
    else
        return {
            Action = "SaveState",
            Error = "Logic operation failed: " .. tostring(result),
            GameState = originalGameState,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
end

-- ====================================
-- AO MESSAGE HANDLERS (ADP v1.0 COMPLIANT)
-- ====================================

-- ADP v1.0 Info Handler (REQUIRED)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = PROCESS_INFO.name,
                    version = PROCESS_INFO.version,
                    adpVersion = PROCESS_INFO.adpVersion,
                    processId = ao.id,
                    capabilities = PROCESS_INFO.capabilities,
                    messageSchemas = PROCESS_INFO.messageSchemas
                },
                handlers = {"ProcessLogic", "HealthCheck", "Info"},
                pokeballs = {
                    supported = {},
                    statusEffects = {}
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Pokemon capture engine with comprehensive mechanics including HP, status effects, pokeball modifiers, and deterministic RNG"
                }
            }
        })
        
        -- Populate pokeball data for documentation
        local response = {
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = PROCESS_INFO.name,
                    version = PROCESS_INFO.version,
                    adpVersion = PROCESS_INFO.adpVersion,
                    processId = ao.id,
                    capabilities = PROCESS_INFO.capabilities,
                    messageSchemas = PROCESS_INFO.messageSchemas
                },
                handlers = {"ProcessLogic", "HealthCheck", "Info"},
                pokeballs = {
                    supported = {},
                    statusEffects = {}
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Pokemon capture engine with comprehensive mechanics"
                }
            }
        }
        
        -- Add pokeball data
        for ballType, ballData in pairs(POKEBALL_DATA) do
            response.Data.pokeballs.supported[ballType] = {
                name = ballData.name,
                catchRate = ballData.catchRate,
                bonusConditions = ballData.bonusConditions
            }
        end
        
        -- Add status effect data
        for status, multiplier in pairs(STATUS_EFFECT_MULTIPLIERS) do
            response.Data.pokeballs.statusEffects[status] = multiplier
        end
        
        ao.send(response)
    end
)

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

-- Health Check Handler
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
                timestamp = msg and msg.Timestamp or 0,
                operations = PROCESS_INFO.capabilities,
                adpCompliance = PROCESS_INFO.adpVersion
            },
            ProcessId = PROCESS_INFO.processId,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- AO processes should not return module exports
-- All data is handled through message passing via ao.send()
print("Process initialization complete.")