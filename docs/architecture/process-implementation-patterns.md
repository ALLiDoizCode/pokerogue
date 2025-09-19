# Process Implementation Patterns

## Overview

This document defines the standardized patterns and best practices for implementing AO processes in the PokéRogue architecture. These patterns ensure consistency, maintainability, and AO protocol compliance across all 26 processes.

## Process Categories

### Logic Processes (Stateless)
Processes that perform pure computation without persisting state:
- `battle-engine.lua` - Combat calculations and turn resolution
- `capture-engine.lua` - Pokémon capture mechanics  
- `evolution-engine.lua` - Evolution and form changes
- `status-effects-engine.lua` - Status effects and environmental conditions

### Data Processes (Stateful)
Processes that manage and persist game state:
- Player data, Pokémon collections, inventory, progress tracking
- World state, NPCs, locations, events

### Coordinator Process
Central orchestration process that routes messages and coordinates workflows

## Core Implementation Pattern

### File Structure Template
```lua
-- ============================================================================
-- [Process Name] - [Brief Description]
-- AO Process Implementation for PokéRogue
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { 
    encode = function(t) return "encoded_json" end, 
    decode = function(s) return {} end 
}
local ao = ao or { 
    send = function(msg) return true end,
    id = "test_process"
}

-- Performance monitoring
local PERFORMANCE_CONFIG = {
    MAX_EXECUTION_TIME_MS = 5000,
    ENABLE_MONITORING = true
}

-- ============================================================================
-- EMBEDDED UTILITIES
-- ============================================================================

local function validateInput(data, schema)
    -- Input validation logic
    if not data then return false, "No data provided" end
    -- Additional validation based on schema
    return true, nil
end

local function createPerformanceMonitor()
    return {
        startTime = os.clock() * 1000,
        checkTimeout = function(self)
            local elapsed = (os.clock() * 1000) - self.startTime
            if elapsed > PERFORMANCE_CONFIG.MAX_EXECUTION_TIME_MS then
                error("Operation exceeded timeout limit: " .. elapsed .. "ms")
            end
            return elapsed
        end
    }
end

local function createResponse(action, data, error, gameState)
    return {
        Action = action or "Response",
        Data = data and json.encode(data) or nil,
        Error = error,
        GameState = gameState and json.encode(gameState) or nil,
        ProcessId = ao.id,
        Timestamp = tostring(os.time())
    }
end

-- ============================================================================
-- EMBEDDED DATA AND CONFIGURATION
-- ============================================================================

local CONFIG = {
    -- Process-specific configuration
}

local DATA_TABLES = {
    -- Embedded data tables specific to process function
}

-- ============================================================================
-- CORE LOGIC IMPLEMENTATION
-- ============================================================================

local function processLogic(msg)
    local monitor = createPerformanceMonitor()
    
    -- Parse input data
    local inputData = json.decode(msg.Data or "{}")
    local gameState = json.decode(msg.GameState or "{}")
    
    -- Validate input
    local isValid, validationError = validateInput(inputData, {})
    if not isValid then
        return createResponse("Error", nil, validationError)
    end
    
    -- Check timeout periodically during processing
    monitor:checkTimeout()
    
    -- Core processing logic here
    local result = {
        success = true,
        -- Add result data
    }
    
    -- Validate and transform game state if needed
    local updatedGameState = gameState -- or transformation logic
    
    return createResponse("Success", result, nil, updatedGameState)
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local success, response = pcall(processLogic, msg)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                Error = response.Error,
                GameState = response.GameState,
                ProcessId = response.ProcessId,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = response, -- pcall error message
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
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
            Action = "HealthCheck",
            Data = json.encode({
                status = "healthy",
                processId = ao.id,
                timestamp = os.time()
            })
        })
    end
)
```

## Specialized Patterns

### Logic Process Pattern
For stateless computation processes:

```lua
-- Core logic focused on pure computation
local function processLogic(msg)
    local inputData = json.decode(msg.Data or "{}")
    local gameState = json.decode(msg.GameState or "{}")
    
    -- Perform stateless computation
    local result = computeResult(inputData, gameState)
    
    -- Return result without modifying persistent state
    return createResponse("Success", result, nil, gameState)
end
```

### Data Process Pattern
For stateful data management processes:

```lua
-- Persistent state management
local PROCESS_STATE = {
    initialized = false,
    data = {}
}

local function initializeState()
    if not PROCESS_STATE.initialized then
        PROCESS_STATE.data = loadInitialData()
        PROCESS_STATE.initialized = true
    end
end

local function processLogic(msg)
    initializeState()
    
    local inputData = json.decode(msg.Data or "{}")
    local action = msg.Action
    
    -- Modify persistent state based on action
    if action == "Save" then
        PROCESS_STATE.data = updateData(PROCESS_STATE.data, inputData)
        return createResponse("SaveSuccess", { saved = true })
    elseif action == "Load" then
        return createResponse("LoadSuccess", PROCESS_STATE.data)
    end
end
```

### Coordinator Process Pattern
For process orchestration:

```lua
-- Process routing and coordination
local PROCESS_MAP = {
    ["battle"] = "battle_process_id",
    ["capture"] = "capture_process_id",
    ["evolution"] = "evolution_process_id"
}

local function routeMessage(msg)
    local action = msg.Action
    local targetProcess = determineTargetProcess(action)
    
    if not targetProcess then
        return createResponse("Error", nil, "Unknown action: " .. action)
    end
    
    -- Forward to appropriate process
    ao.send({
        Target = PROCESS_MAP[targetProcess],
        Action = "ProcessLogic",
        Data = msg.Data,
        GameState = msg.GameState,
        OriginalSender = msg.From
    })
    
    return createResponse("Routed", { target = targetProcess })
end
```

## Error Handling Patterns

### Standard Error Handling
```lua
local function safeProcessLogic(msg)
    local success, result = pcall(function()
        return processLogic(msg)
    end)
    
    if success then
        return result
    else
        return createResponse("Error", nil, "Processing failed: " .. result)
    end
end
```

### Validation Error Handling
```lua
local function validateAndProcess(msg)
    -- Input validation
    local inputData = json.decode(msg.Data or "{}")
    
    if not inputData.requiredField then
        return createResponse("ValidationError", nil, "Missing required field")
    end
    
    -- Range validation
    if inputData.value < 0 or inputData.value > 1000 then
        return createResponse("ValidationError", nil, "Value out of range")
    end
    
    -- Process if validation passes
    return processLogic(msg)
end
```

## Performance Patterns

### Timeout Monitoring
```lua
local function processWithTimeout(msg)
    local startTime = os.clock() * 1000
    local maxTime = 5000 -- 5 seconds
    
    local function checkTimeout()
        local elapsed = (os.clock() * 1000) - startTime
        if elapsed > maxTime then
            error("Operation timed out after " .. elapsed .. "ms")
        end
    end
    
    -- Check timeout at key points
    local data = parseInput(msg)
    checkTimeout()
    
    local result = performComputation(data)
    checkTimeout()
    
    return createResponse("Success", result)
end
```

### Memory Optimization
```lua
-- Reuse tables to minimize garbage collection
local REUSABLE_TABLES = {
    temp = {},
    result = {},
    state = {}
}

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function processEfficiently(msg)
    -- Clear and reuse tables
    clearTable(REUSABLE_TABLES.temp)
    clearTable(REUSABLE_TABLES.result)
    
    -- Use reusable tables for processing
    local result = REUSABLE_TABLES.result
    result.success = true
    result.data = computeData(msg, REUSABLE_TABLES.temp)
    
    return createResponse("Success", result)
end
```

## Testing Patterns

### Mock Environment Setup
```lua
-- Testing environment setup
local function setupTestEnvironment()
    -- Mock AO globals for testing
    if not ao then
        ao = {
            send = function(msg) 
                print("Mock send:", json.encode(msg))
            end,
            id = "test_process_id"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
            end,
            utils = {
                hasMatchingTag = function(tag, value)
                    return function(msg)
                        return msg[tag] == value
                    end
                end
            }
        }
    end
end
```

### Unit Test Pattern
```lua
-- Unit testing framework
local function runTests()
    setupTestEnvironment()
    
    local tests = {
        {
            name = "Test valid input",
            input = { Data = '{"test": true}' },
            expected = "Success"
        },
        {
            name = "Test invalid input", 
            input = { Data = '{}' },
            expected = "ValidationError"
        }
    }
    
    for _, test in ipairs(tests) do
        print("Running:", test.name)
        local result = processLogic(test.input)
        local response = json.decode(result.Data or "{}")
        
        if result.Action == test.expected then
            print("✓ PASS")
        else
            print("✗ FAIL - Expected:", test.expected, "Got:", result.Action)
        end
    end
end
```

## Integration Patterns

### Message Flow Pattern
```lua
-- Standard message flow between processes
local function handleCoordinatedAction(msg)
    -- Step 1: Validate request
    local isValid, error = validateRequest(msg)
    if not isValid then
        return createResponse("ValidationError", nil, error)
    end
    
    -- Step 2: Process logic
    local result = processLogic(msg)
    
    -- Step 3: Send to next process if needed
    if result.Action == "Success" and msg.NextProcess then
        ao.send({
            Target = msg.NextProcess,
            Action = "ProcessLogic",
            Data = result.Data,
            GameState = result.GameState,
            OriginalSender = msg.From
        })
    end
    
    return result
end
```

### State Synchronization Pattern
```lua
-- Synchronize state across multiple processes
local function synchronizeState(gameState, updates)
    local updatedState = deepCopy(gameState)
    
    -- Apply updates atomically
    for key, value in pairs(updates) do
        updatedState[key] = value
    end
    
    -- Validate state consistency
    local isValid, error = validateGameState(updatedState)
    if not isValid then
        return gameState, error -- Return original state on validation failure
    end
    
    return updatedState, nil
end
```

## Security Patterns

### Input Sanitization
```lua
local function sanitizeInput(data)
    -- Remove potentially dangerous fields
    local sanitized = {}
    local allowedFields = { "action", "value", "id", "params" }
    
    for _, field in ipairs(allowedFields) do
        if data[field] then
            sanitized[field] = data[field]
        end
    end
    
    return sanitized
end
```

### Authorization Pattern
```lua
local function authorizeRequest(msg, requiredRole)
    local sender = msg.From
    local userRole = getUserRole(sender)
    
    if not hasPermission(userRole, requiredRole) then
        return false, "Insufficient permissions"
    end
    
    return true, nil
end
```

## Deployment Checklist

Before deploying any process, verify:

1. ✅ **Monolithic Design**: No require() statements, all dependencies embedded
2. ✅ **Handler Pattern**: Using Handlers.add() with proper tag matching
3. ✅ **Error Handling**: All functions wrapped in pcall with error responses
4. ✅ **Performance**: Timeout monitoring and efficient data structures
5. ✅ **Testing**: Unit tests pass with mock environment
6. ✅ **Validation**: Input validation and sanitization implemented
7. ✅ **Documentation**: Code comments and function descriptions
8. ✅ **AO Compliance**: Compatible with AO runtime environment globals

## Common Pitfalls

### Avoid These Patterns
```lua
-- ❌ DON'T: Use require statements
local utils = require('utils')

-- ❌ DON'T: Direct handler assignment
Handlers["ProcessLogic"] = function(msg) end

-- ❌ DON'T: Blocking operations without timeout
while condition do
    -- Long running loop without timeout check
end

-- ❌ DON'T: Global state mutations without protection
GLOBAL_STATE.value = newValue

-- ❌ DON'T: Unhandled errors
local result = riskyOperation() -- May throw error
```

### Use These Patterns Instead
```lua
-- ✅ DO: Embed all dependencies
local function utilityFunction() end

-- ✅ DO: Use Handlers.add pattern
Handlers.add("process-logic", matcher, handler)

-- ✅ DO: Monitor execution time
local monitor = createPerformanceMonitor()
monitor:checkTimeout()

-- ✅ DO: Protected state mutations
local function updateStateSafely(newState)
    -- Validation and atomic update
end

-- ✅ DO: Handle all errors
local success, result = pcall(riskyOperation)
if not success then
    return createResponse("Error", nil, result)
end
```