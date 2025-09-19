-- Logic Process Template for PokéRogue AO
-- Provides standardized framework for stateless logic processes performing GameState transformations
-- Version: 2.0 - AO Compliance Enhanced
--
-- AO COMPLIANCE REQUIREMENTS:
-- 1. MONOLITHIC DESIGN: All dependencies must be embedded (no require() statements)
-- 2. HANDLER PATTERN: Use Handlers.add() with proper tag matching
-- 3. ERROR HANDLING: Wrap all operations in pcall
-- 4. TIMEOUT MONITORING: 5-second execution limit enforcement
-- 5. AO GLOBALS ONLY: Use ao.send(), ao.id, Handlers, json, standard Lua only
--
-- USAGE EXAMPLE:
-- Handlers.add("process-logic",
--     Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
--     function(msg)
--         local response = LogicProcessTemplate.handleMessage(msg, ao.id, myLogicHandler)
--         ao.send({
--             Target = msg.From,
--             Action = response.Action,
--             Data = response.Data,
--             Error = response.Error,
--             GameState = response.GameState,
--             ProcessId = response.ProcessId,
--             Timestamp = response.Timestamp
--         })
--     end
-- )

local LogicProcessTemplate = {}

-- Performance monitoring configuration (5 second limit for logic operations)
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local performanceStartTime = nil

-- Rate limiting configuration
local RATE_LIMIT_MAX = 50 -- operations per minute per address (lower than data processes)
local rateLimitCounters = {}

-- GameState integrity validation
function LogicProcessTemplate.validateGameState(gameState)
    if type(gameState) ~= "table" then
        return false, "GameState must be a table"
    end

    -- Required top-level fields for GameState
    local requiredFields = {
        "playerId", "timestamp", "version"
    }

    for _, field in ipairs(requiredFields) do
        if not gameState[field] then
            return false, "GameState missing required field: " .. field
        end
    end

    -- Validate player data structure if present
    if gameState.player then
        if not gameState.player.party or type(gameState.player.party) ~= "table" then
            return false, "GameState.player.party must be a table"
        end
    end

    -- Validate battle data structure if present
    if gameState.battle then
        if not gameState.battle.battleId or not gameState.battle.battleSeed then
            return false, "GameState.battle must have battleId and battleSeed"
        end
    end

    return true, nil
end

-- Input validation framework for logic process messages
function LogicProcessTemplate.validateInput(message)
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

    -- Validate required Data fields for logic operations
    if not message.Data.gameState then
        return false, "Data.gameState is required for logic operations"
    end

    if not message.Data.operation or type(message.Data.operation) ~= "string" then
        return false, "Data.operation is required and must be a string"
    end

    -- Validate GameState structure
    local gameStateValid, gameStateError = LogicProcessTemplate.validateGameState(message.Data.gameState)
    if not gameStateValid then
        return false, "Invalid GameState: " .. gameStateError
    end

    return true, nil
end

-- Rate limiting implementation (stricter for logic processes)
function LogicProcessTemplate.checkRateLimit(address)
    local currentTime = os.time()
    local currentMinute = math.floor(currentTime / 60)

    if not rateLimitCounters[address] then
        rateLimitCounters[address] = {
            minute = currentMinute,
            count = 0
        }
    end

    local counter = rateLimitCounters[address]

    -- Reset counter if we're in a new minute
    if counter.minute ~= currentMinute then
        counter.minute = currentMinute
        counter.count = 0
    end

    -- Check if rate limit exceeded
    if counter.count >= RATE_LIMIT_MAX then
        return false, "Rate limit exceeded: maximum " .. RATE_LIMIT_MAX .. " operations per minute"
    end

    -- Increment counter
    counter.count = counter.count + 1
    return true, nil
end

-- Performance monitoring for 5-second operation tracking
function LogicProcessTemplate.startPerformanceMonitoring()
    performanceStartTime = os.clock()
end

function LogicProcessTemplate.endPerformanceMonitoring()
    if performanceStartTime then
        local responseTime = (os.clock() - performanceStartTime) * 1000 -- Convert to milliseconds
        performanceStartTime = nil
        return responseTime
    end
    return nil
end

-- Deterministic RNG handling using AO crypto module
function LogicProcessTemplate.initializeRNG(battleSeed)
    -- In real AO environment, this would use the AO crypto module
    -- For now, we create a deterministic RNG state from the battle seed
    if not battleSeed or type(battleSeed) ~= "string" then
        return nil, "Battle seed is required for deterministic RNG"
    end

    -- Create deterministic seed from battle seed string
    local seedValue = 0
    for i = 1, #battleSeed do
        seedValue = seedValue + string.byte(battleSeed, i) * i
    end

    -- Initialize RNG state
    local rngState = {
        seed = seedValue,
        counter = 0
    }

    return rngState, nil
end

-- Generate deterministic random number
function LogicProcessTemplate.nextRandom(rngState, min, max)
    if not rngState then
        error("RNG state is required for deterministic random generation")
    end

    -- Increment counter for reproducible sequence
    rngState.counter = rngState.counter + 1

    -- Simple linear congruential generator for deterministic results
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

-- GameState transformation integrity validation
function LogicProcessTemplate.validateGameStateTransformation(originalState, transformedState)
    -- Check that transformed state maintains required structure
    local isValid, error = LogicProcessTemplate.validateGameState(transformedState)
    if not isValid then
        return false, "Transformed GameState is invalid: " .. error
    end

    -- Check that player ID hasn't changed
    if originalState.playerId ~= transformedState.playerId then
        return false, "Player ID cannot be modified during logic operations"
    end

    -- Check that version has been updated
    if originalState.version and transformedState.version and transformedState.version <= originalState.version then
        return false, "GameState version must be incremented after transformation"
    end

    return true, nil
end

-- Standard SaveState response protocol for logic processes
function LogicProcessTemplate.createSuccessResponse(gameState, result, processId)
    return {
        Action = "SaveState",
        Data = {
            gameState = gameState,
            result = result or {}
        },
        Timestamp = os.time(),
        ProcessId = processId or "logic-process"
    }
end

-- Error response with original GameState preservation
function LogicProcessTemplate.createErrorResponse(errorMessage, originalGameState, processId)
    return {
        Action = "SaveState",
        Error = errorMessage,
        GameState = originalGameState, -- Preserve original state on error
        ProcessId = processId or "logic-process",
        Timestamp = os.time()
    }
end

-- Main logic process message handler template
function LogicProcessTemplate.handleMessage(message, processId, logicHandler)
    -- Start performance monitoring
    LogicProcessTemplate.startPerformanceMonitoring()

    -- Input validation
    local isValid, validationError = LogicProcessTemplate.validateInput(message)
    if not isValid then
        return LogicProcessTemplate.createErrorResponse(validationError, nil, processId)
    end

    -- Rate limiting check
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = LogicProcessTemplate.checkRateLimit(senderAddress)
    if not rateLimitOk then
        return LogicProcessTemplate.createErrorResponse(rateLimitError, message.Data.gameState, processId)
    end

    -- Extract operation data
    local originalGameState = message.Data.gameState
    local operation = message.Data.operation
    local parameters = message.Data.parameters or {}

    -- Initialize RNG if battle seed is provided
    local rngState = nil
    if originalGameState.battle and originalGameState.battle.battleSeed then
        local rngInitSuccess, rngError = LogicProcessTemplate.initializeRNG(originalGameState.battle.battleSeed)
        if not rngInitSuccess then
            return LogicProcessTemplate.createErrorResponse("RNG initialization failed: " .. rngError, originalGameState, processId)
        end
        rngState = rngInitSuccess
    end

    -- Process the logic operation using provided handler
    local success, result = pcall(function()
        return logicHandler(originalGameState, operation, parameters, rngState)
    end)

    -- Check performance requirement (5 second limit)
    local responseTime = LogicProcessTemplate.endPerformanceMonitoring()
    if responseTime and responseTime > LOGIC_OPERATION_TIMEOUT then
        return LogicProcessTemplate.createErrorResponse(
            "Logic operation exceeded " .. LOGIC_OPERATION_TIMEOUT .. "ms timeout (took " .. responseTime .. "ms)",
            originalGameState,
            processId
        )
    end

    if success then
        -- Validate the transformation if result contains gameState
        if result and result.gameState then
            local transformationValid, transformationError = LogicProcessTemplate.validateGameStateTransformation(
                originalGameState,
                result.gameState
            )
            if not transformationValid then
                return LogicProcessTemplate.createErrorResponse(
                    "GameState transformation validation failed: " .. transformationError,
                    originalGameState,
                    processId
                )
            end

            -- Update timestamp and version
            result.gameState.timestamp = os.time()
            if originalGameState.version then
                result.gameState.version = (originalGameState.version or 0) + 1
            end
        end

        return LogicProcessTemplate.createSuccessResponse(
            result and result.gameState or originalGameState,
            result,
            processId
        )
    else
        return LogicProcessTemplate.createErrorResponse(
            "Logic operation failed: " .. tostring(result),
            originalGameState,
            processId
        )
    end
end

-- Utility functions for common logic operations
LogicProcessTemplate.Utils = {
    -- Deep copy table to avoid mutation of original GameState
    deepCopy = function(original)
        if type(original) ~= "table" then
            return original
        end
        local copy = {}
        for key, value in pairs(original) do
            copy[key] = LogicProcessTemplate.Utils.deepCopy(value)
        end
        return copy
    end,

    -- Calculate stat with nature modifier (exact 0.9, 1.0, 1.1 values)
    calculateStatWithNature = function(baseStat, natureMod)
        if natureMod == 0.9 then
            return math.floor(baseStat * 0.9)
        elseif natureMod == 1.1 then
            return math.floor(baseStat * 1.1)
        else
            return baseStat -- nature modifier is 1.0
        end
    end,

    -- Validate Pokemon data structure
    validatePokemon = function(pokemon)
        if type(pokemon) ~= "table" then
            return false, "Pokemon must be a table"
        end

        local requiredFields = {
            "speciesId", "level", "hp", "maxHp", "stats"
        }

        for _, field in ipairs(requiredFields) do
            if not pokemon[field] then
                return false, "Pokemon missing required field: " .. field
            end
        end

        if type(pokemon.stats) ~= "table" then
            return false, "Pokemon.stats must be a table"
        end

        return true, nil
    end,

    -- Validate battle data structure
    validateBattle = function(battle)
        if type(battle) ~= "table" then
            return false, "Battle must be a table"
        end

        local requiredFields = {
            "battleId", "battleSeed", "turn"
        }

        for _, field in ipairs(requiredFields) do
            if not battle[field] then
                return false, "Battle missing required field: " .. field
            end
        end

        return true, nil
    end
}

return LogicProcessTemplate