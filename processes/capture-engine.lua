-- Capture Engine Process for PokéRogue AO
-- Handles capture probability calculation, success determination, and Pokemon storage logic
-- Implements pure computation on GameState with capture mechanics
-- Monolithic process - all dependencies embedded (no external imports)

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end }

-- Capture Engine process identifier
local PROCESS_ID = "capture-engine"

-- Performance monitoring configuration (5 second limit for logic operations)
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local performanceStartTime = nil

-- Rate limiting configuration (stricter for logic processes)
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}

-- Pokeball types and their catch rates (embedded data)
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
        bonusConditions = {waterBug = true} -- Bonus for Water/Bug types
    },
    diveball = {
        name = "Dive Ball",
        catchRate = 3.5,
        bonusConditions = {underwater = true} -- Bonus for underwater encounters
    },
    timerball = {
        name = "Timer Ball",
        catchRate = 1.0, -- Base rate, increases with turn count
        bonusConditions = {timer = true}
    },
    quickball = {
        name = "Quick Ball",
        catchRate = 5.0,
        bonusConditions = {firstTurn = true} -- Bonus on first turn
    },
    duskball = {
        name = "Dusk Ball",
        catchRate = 3.5,
        bonusConditions = {darkTime = true} -- Bonus at night or in caves
    },
    repeatball = {
        name = "Repeat Ball",
        catchRate = 3.5,
        bonusConditions = {alreadyCaught = true} -- Bonus if species already caught
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
    faint = 0.0 -- Cannot catch fainted Pokemon
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
-- CAPTURE ENGINE CORE FUNCTIONS
-- ====================================

local CaptureEngine = {}

-- Calculate capture probability based on Pokemon stats, ball type, and conditions
function CaptureEngine.calculateCaptureRate(pokemon, pokeballType, battleConditions, rngState)
    local baseRate = pokemon.catchRate or 45 -- Default catch rate if not specified
    local ballData = POKEBALL_DATA[pokeballType] or POKEBALL_DATA.pokeball
    
    -- Base capture calculation using standard Pokemon formula
    -- Rate = (HP_max * 3 - HP_current * 2) * species_rate * ball_rate / (HP_max * 3)
    local currentHp = pokemon.hp
    local maxHp = pokemon.maxHp
    local hpFactor = ((maxHp * 3 - currentHp * 2) * baseRate) / (maxHp * 3)
    
    -- Apply pokeball modifier
    local ballModifier = ballData.catchRate
    
    -- Apply pokeball-specific bonuses
    if ballData.bonusConditions then
        if ballData.bonusConditions.waterBug and (pokemon.type1 == "water" or pokemon.type1 == "bug" or 
           pokemon.type2 == "water" or pokemon.type2 == "bug") then
            ballModifier = ballModifier * 1.5
        end
        
        if ballData.bonusConditions.firstTurn and battleConditions.turn == 1 then
            ballModifier = ballModifier * 2.0
        end
        
        if ballData.bonusConditions.timer and battleConditions.turn then
            local timerBonus = math.min(4.0, 1.0 + (battleConditions.turn * 0.3))
            ballModifier = ballModifier * timerBonus
        end
        
        if ballData.bonusConditions.darkTime and battleConditions.environment == "cave" then
            ballModifier = ballModifier * 1.5
        end
        
        if ballData.bonusConditions.alreadyCaught and battleConditions.pokedexCaught then
            ballModifier = ballModifier * 1.5
        end
    end
    
    -- Apply status effect multiplier
    local statusMultiplier = STATUS_EFFECT_MULTIPLIERS[pokemon.statusEffect] or STATUS_EFFECT_MULTIPLIERS.none
    
    -- Calculate final capture rate
    local finalRate = hpFactor * ballModifier * statusMultiplier
    
    -- Apply capture formula: rate = (rate * 1048560) / 16711680
    -- Simplified for AO implementation
    local captureValue = math.min(255, finalRate * 255 / 100)
    
    return {
        captureValue = captureValue,
        probability = captureValue / 255,
        hpFactor = hpFactor,
        ballModifier = ballModifier,
        statusMultiplier = statusMultiplier,
        finalRate = finalRate
    }
end

-- Determine capture success using deterministic RNG
function CaptureEngine.attemptCapture(captureRate, rngState)
    local captureValue = captureRate.captureValue
    
    -- Master Ball always succeeds
    if captureValue >= 255 then
        return {
            success = true,
            criticalCapture = false,
            shakeCount = 0,
            captureValue = captureValue
        }
    end
    
    -- Check for critical capture (rare occurrence)
    local criticalCaptureChance = math.max(0, (captureValue - 100) / 6)
    local criticalRoll = nextRandom(rngState, 0, 255)
    local criticalCapture = criticalRoll < criticalCaptureChance
    
    if criticalCapture then
        local finalCaptureRoll = nextRandom(rngState, 0, 255)
        return {
            success = finalCaptureRoll < captureValue,
            criticalCapture = true,
            shakeCount = finalCaptureRoll < captureValue and 1 or 0,
            captureValue = captureValue
        }
    end
    
    -- Normal capture with shake calculation
    local shakeCount = 0
    local success = true
    
    for shake = 1, 3 do
        local shakeValue = (65536 * math.sqrt(math.sqrt(captureValue / 255))) / 255
        local shakeRoll = nextRandom(rngState, 0, 65535)
        
        if shakeRoll < shakeValue then
            shakeCount = shake
        else
            success = false
            break
        end
        
        if shake == 3 then
            shakeCount = 3
        end
    end
    
    return {
        success = success,
        criticalCapture = false,
        shakeCount = shakeCount,
        captureValue = captureValue
    }
end

-- Add captured Pokemon to party or PC
function CaptureEngine.addPokemonToParty(gameState, capturedPokemon)
    local newGameState = deepCopy(gameState)
    
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

-- Process capture attempt with full mechanics
function CaptureEngine.processCaptureAttempt(gameState, pokeballType, targetPokemon, battleConditions, rngState)
    -- Validate that Pokemon can be captured
    if targetPokemon.hp <= 0 then
        error("Cannot capture a fainted Pokemon")
    end
    
    if targetPokemon.isTrainerPokemon then
        error("Cannot capture trainer Pokemon")
    end
    
    -- Calculate capture rate
    local captureRate = CaptureEngine.calculateCaptureRate(targetPokemon, pokeballType, battleConditions, rngState)
    
    -- Attempt capture
    local captureResult = CaptureEngine.attemptCapture(captureRate, rngState)
    
    if captureResult.success then
        -- Create captured Pokemon copy
        local capturedPokemon = deepCopy(targetPokemon)
        capturedPokemon.originalTrainer = gameState.playerId
        capturedPokemon.captureDate = os.time()
        capturedPokemon.pokeball = pokeballType
        
        -- Add to party or PC
        local updatedGameState, location = CaptureEngine.addPokemonToParty(gameState, capturedPokemon)
        
        return {
            gameState = updatedGameState,
            captureSuccess = true,
            captureResult = captureResult,
            storageLocation = location,
            capturedPokemon = capturedPokemon
        }
    else
        return {
            gameState = gameState, -- No state change on failed capture
            captureSuccess = false,
            captureResult = captureResult,
            storageLocation = nil,
            capturedPokemon = nil
        }
    end
end

-- Main logic handler for capture operations
function CaptureEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "attemptCapture" then
        local pokeballType = parameters.pokeballType
        local targetPokemon = parameters.targetPokemon
        local battleConditions = parameters.battleConditions or {}
        
        if not pokeballType or not targetPokemon then
            error("pokeballType and targetPokemon parameters are required for attemptCapture operation")
        end
        
        return CaptureEngine.processCaptureAttempt(gameState, pokeballType, targetPokemon, battleConditions, rngState)
        
    elseif operation == "calculateCaptureRate" then
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
        
    else
        error("Unknown capture engine operation: " .. operation)
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
        return CaptureEngine.handleLogicOperation(originalGameState, operation, parameters, rngState)
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
                    "attemptCapture",
                    "calculateCaptureRate"
                }
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export for testing
return {
    CaptureEngine = CaptureEngine,
    PROCESS_ID = PROCESS_ID,
    POKEBALL_DATA = POKEBALL_DATA,
    STATUS_EFFECT_MULTIPLIERS = STATUS_EFFECT_MULTIPLIERS
}