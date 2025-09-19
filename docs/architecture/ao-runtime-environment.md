# AO Runtime Environment

## Overview

The Arweave AO (Actor Oriented) protocol provides a decentralized compute environment that executes Lua processes in a sandboxed runtime. This document describes the runtime characteristics, available globals, and execution constraints that govern all PokéRogue processes.

## Runtime Characteristics

### Execution Model
- **Process Isolation**: Each process runs in an isolated Lua 5.3 environment
- **Message-Driven**: Processes communicate exclusively through AO messages
- **Deterministic**: All operations must be deterministic for consensus
- **Stateless**: Processes maintain state through message history replay
- **Monolithic**: No external file imports or require() statements allowed

### Performance Constraints
- **Timeout Limit**: 5-second execution limit per message handler
- **Memory Limits**: Constrained by AO network specifications
- **File Size**: Process files should remain under 500KB for efficient distribution
- **CPU Usage**: Limited computational cycles per execution

## Available Globals

### Core AO Globals

#### `ao` - AO Protocol Interface
```lua
ao = {
    -- Send messages to other processes or users
    send = function(message) end,
    
    -- Current process ID
    id = "process_id_string",
    
    -- Environment information
    env = {
        -- Current block height
        ["Block-Height"] = "12345",
        -- Current timestamp
        Timestamp = "1640995200000",
        -- Process owner
        Owner = "owner_address"
    }
}
```

#### `Handlers` - Message Handler Registry
```lua
Handlers = {
    -- Add a new message handler
    add = function(name, matcher, handler) end,
    
    -- Utility functions for message matching
    utils = {
        hasMatchingTag = function(tag, value) end,
        hasMatchingData = function(pattern) end,
        reply = function(data) end
    }
}
```

#### `json` - JSON Utilities
```lua
json = {
    -- Encode Lua table to JSON string
    encode = function(table) end,
    
    -- Decode JSON string to Lua table
    decode = function(string) end
}
```

### Standard Lua Globals
- `string`, `table`, `math`, `os` (limited subset)
- `print`, `type`, `pairs`, `ipairs`, `next`
- `tonumber`, `tostring`, `select`

### Restricted/Unavailable
- `require()` - External module loading forbidden
- `io` - File system access forbidden
- `debug` - Debug library unavailable
- Network functions - Only through `ao.send()`

## Message Structure

### Incoming Messages
```lua
msg = {
    -- Message metadata
    Id = "message_id",
    From = "sender_address", 
    Target = "target_process_id",
    Timestamp = "1640995200000",
    
    -- Message content
    Action = "ProcessLogic",
    Data = "json_encoded_data",
    
    -- Custom tags
    ["Custom-Tag"] = "value"
}
```

### Outgoing Messages
```lua
ao.send({
    Target = msg.From,
    Action = "Response",
    Data = json.encode(response_data),
    Error = error_message, -- Optional
    ["Custom-Tag"] = "value" -- Optional tags
})
```

## Handler Patterns

### Standard Handler Registration
```lua
Handlers.add("handler-name",
    Handlers.utils.hasMatchingTag("Action", "ActionName"),
    function(msg)
        -- Handler logic here
        local result = processMessage(msg)
        
        ao.send({
            Target = msg.From,
            Action = "Response",
            Data = json.encode(result)
        })
    end
)
```

### Error Handling Pattern
```lua
Handlers.add("error-handler",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local success, result = pcall(function()
            return processLogic(msg)
        end)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = "Success",
                Data = json.encode(result)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = result,
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        end
    end
)
```

## Development Constraints

### Monolithic Design Requirements
1. **No External Dependencies**: All logic must be embedded in single file
2. **Self-Contained**: Include all utility functions, data tables, and constants
3. **No File System Access**: No reading from external files or databases
4. **Deterministic Operations**: Use deterministic RNG with seeds from messages

### Testing Considerations
- Use aolite framework for local development and testing
- Mock AO globals when testing outside aolite environment
- Validate deterministic behavior across multiple runs
- Test message flow and handler registration

### Code Organization
```lua
-- Global declarations for AO environment compatibility
local json = json or require('json')  -- Fallback for testing
local ao = ao or { send = function() end, id = "test" }

-- Embedded utility functions
local function validateInput(data)
    -- Validation logic
end

-- Embedded data tables
local CONFIG = {
    MAX_BATTLE_TURNS = 100,
    TIMEOUT_MS = 5000
}

-- Main processing logic
local function processLogic(msg)
    -- Core logic implementation
end

-- Handler registration
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local response = processLogic(msg)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data
        })
    end
)
```

## Security Considerations

### Input Validation
- Validate all incoming message data
- Sanitize user inputs to prevent injection attacks
- Check message sender authorization where required

### State Management
- Never expose sensitive data in outgoing messages
- Use cryptographic techniques for sensitive operations
- Maintain state consistency across message handlers

### Resource Limits
- Implement timeouts for long-running operations
- Limit recursive operations to prevent stack overflow
- Monitor memory usage in data-intensive operations

## Performance Optimization

### Best Practices
- Pre-compute expensive operations where possible
- Use efficient data structures (avoid nested loops)
- Cache frequently accessed data in local variables
- Minimize JSON encoding/decoding operations

### Monitoring
- Track execution time for critical operations
- Log performance metrics for optimization
- Use deterministic timing for reproducible benchmarks

## Integration with PokéRogue Architecture

### Process Types
- **Logic Processes**: Stateless computation (battle, capture, evolution, status)
- **Data Processes**: State management and persistence
- **Coordinator Process**: Process orchestration and routing

### Message Flow
1. Client sends action to Coordinator Process
2. Coordinator routes to appropriate Logic Process
3. Logic Process computes result and responds
4. Coordinator updates Data Processes if needed
5. Final response sent to client

### State Synchronization
- GameState passed through message Data field
- Deterministic transformations ensure consistency
- SaveState protocol for persistent storage