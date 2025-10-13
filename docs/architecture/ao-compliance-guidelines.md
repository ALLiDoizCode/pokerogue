# AO Compliance Guidelines

**Critical Reference for AO Process Development**

## 🚨 Critical Violations (Will Block Deployment)

### ❌ FORBIDDEN: External Dependencies (JSON Exception)
```lua
-- ✅ ALLOWED: JSON require is specifically permitted in AO
local json = require("json")

-- ❌ FORBIDDEN: Other external modules not supported
local utils = require("./utils")
local fs = require("fs")
local http = require("http")

-- ✅ CORRECT: Embed dependencies or use AO-provided functionality
-- All utility functions must be embedded within the process file
local function myUtilityFunction()
    -- Embedded utility code
end
```

### ❌ FORBIDDEN: Unnecessary pcall for Controlled Data
```lua
-- ❌ FORBIDDEN: Don't wrap controlled AO message data in pcall
local success, data = pcall(json.decode, msg.Data)  -- msg.Data is controlled!

-- ❌ FORBIDDEN: Don't wrap entire handlers in pcall
Handlers.add("handler", pattern, function(msg)
    local success, result = pcall(function()
        -- ... entire handler logic ...
        return processLogic(msg)
    end)
end)

-- ✅ CORRECT: Direct handling for controlled inputs
local data = json.decode(msg.Data or "{}")

-- ✅ CORRECT: Direct error responses
if not requiredParam then
    ao.send({Target = msg.From, Action = "Error", Error = "Parameter required"})
    return
end
```

### ❌ FORBIDDEN: Non-Deterministic Operations
```lua
-- ❌ FORBIDDEN: Non-deterministic time functions
local timestamp = os.time()
local random = math.random()

-- ✅ CORRECT: Use deterministic AO message data
local timestamp = tonumber(msg.Timestamp or 0)
-- For randomness, use AO crypto module when available
```

### ❌ FORBIDDEN: System Operations
```lua
-- ❌ FORBIDDEN: File system and debug operations
local file = io.open("file.txt")
debug.getinfo()
loadfile("script.lua")

-- ✅ CORRECT: AO processes are sandboxed - use message passing only
ao.send({Target = "other-process", Action = "GetData"})
```

## ✅ Required Patterns

### Handler Registration Pattern
```lua
-- ✅ REQUIRED: Use Handlers.add() with proper pattern matching
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        -- Handler implementation
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(response)
        })
    end
)

-- ❌ FORBIDDEN: Direct handler assignment
Handlers["ProcessLogic"] = function(msg) end
```

### Message Response Pattern
```lua
-- ✅ REQUIRED: Proper AO message structure
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Success = "true",
    Data = json.encode(result),
    ProcessId = ao.id,
    Timestamp = tostring(msg.Timestamp or 0)
})

-- ✅ REQUIRED: Error response structure
ao.send({
    Target = msg.From,
    Action = "Error",
    Success = "false",
    Error = "Descriptive error message",
    ProcessId = ao.id
})
```

### Data Structure Patterns
```lua
-- ✅ REQUIRED: Use tags for simple parameters
local pokemonId = msg.PokemonId or msg.Id
local operation = msg.Operation

-- ✅ REQUIRED: Use Data field for complex structures
local gameState = json.decode(msg.Data or "{}")

-- ✅ REQUIRED: Convert tag values (always strings) to proper types
local level = tonumber(msg.Level)
local confirmed = msg.Confirmed == "true"
```

## 🔧 Development Workflow

### Pre-Development Checklist
- [ ] Review this compliance guide
- [ ] Understand AO runtime constraints
- [ ] Plan monolithic architecture (no external deps)
- [ ] Design proper handler patterns

### During Development
- [ ] Use only AO globals: `ao.send()`, `ao.id`, `Handlers`, `json`
- [ ] Test with deterministic timestamps
- [ ] Validate with `npm run lint:ao-sandbox`
- [ ] Use direct error handling patterns

### Pre-Commit Validation
```bash
# Automatic validation in git hooks
npm run lint:ao-sandbox

# Manual validation during development
lua tools/ao-sandbox-validator.lua
```

## 📋 AO Runtime Environment

### Available Globals
- `ao.send()` - Send messages to other processes
- `ao.id` - Current process identifier  
- `Handlers` - Message handler registry with utils
- `json` - JSON encode/decode utilities
- Standard Lua: `string`, `table`, `math` (limited subset)

### Constraints
- **File Size**: 500KB maximum per process
- **Execution Time**: 5-second timeout
- **Memory**: Efficient state management required
- **Architecture**: Monolithic design (no external modules)

## 🎯 ADP v1.0 Compliance

### Required Info Handler
```lua
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                name = "Process Name",
                version = "1.0.0",
                adpVersion = "1.0",
                capabilities = ["capability1", "capability2"],
                handlers = [
                    {
                        action = "ProcessLogic",
                        description = "Main processing handler"
                    }
                ]
            })
        })
    end
)
```

## 🚀 Performance Best Practices

### Memory Efficiency
```lua
-- ✅ Store references, not full objects
storage = {
    party = {
        pokemon = {
            [1] = "pokemon_instance_id_1",  -- ID reference only
            [2] = "pokemon_instance_id_2"
        }
    }
}

-- ✅ Use table recycling for large operations
local function processLargeDataset(items)
    local result = {}  -- Reuse this table pattern
    for _, item in ipairs(items) do
        -- Process efficiently
    end
    return result
end
```

### Rate Limiting Pattern
```lua
-- ✅ Implement rate limiting for abuse prevention
local RATE_LIMIT = 50  -- operations per minute
local rateLimiting = {}  -- [playerId] = {operations: [], lastCleanup: timestamp}

local function checkRateLimit(playerId, timestamp)
    -- Implementation pattern for preventing abuse
    cleanupOldOperations(playerId, timestamp)
    if #rateLimiting[playerId].operations >= RATE_LIMIT then
        return false, "Rate limit exceeded"
    end
    table.insert(rateLimiting[playerId].operations, timestamp)
    return true, nil
end
```

## 🔍 Testing Patterns

### Unit Test Setup
```lua
-- ✅ Mock AO environment for testing
local MockAO = {
    messages = {},
    id = "test_process_id"
}

function MockAO.send(message)
    table.insert(MockAO.messages, message)
end

-- Setup globals
ao = MockAO
Handlers = {
    add = function(name, matcher, handler)
        -- Test handler registration
    end
}

-- Load process
dofile("processes/your-process.lua")
```

### Deterministic Testing
```lua
-- ✅ Use fixed timestamps in tests
local msg = {
    Action = "ProcessLogic",
    From = "test_player",
    Timestamp = "1234567890",  -- Fixed timestamp
    Data = json.encode(testData)
}
```

## 🛠️ Validation Tools

### Automated Validation
```bash
# Pre-commit hook automatically runs:
lua tools/ao-sandbox-validator.lua

# Manual validation:
npm run lint:ao-sandbox
```

### IDE Integration
Add to your IDE's build tasks:
```json
{
    "label": "AO Compliance Check",
    "type": "shell", 
    "command": "lua tools/ao-sandbox-validator.lua",
    "group": "build"
}
```

## 📚 Additional Resources

- **AO Documentation**: Official AO runtime documentation
- **Process Templates**: Use Permamind for ADP-compliant generation
- **Testing Framework**: aolite for local development
- **Architecture Guidelines**: `docs/architecture/coding-standards.md`

## 🚨 When Compliance Fails

If `npm run lint:ao-sandbox` fails:

1. **Fix Critical Violations**: require(), forbidden operations
2. **Review Error Messages**: Tool provides specific guidance
3. **Test Locally**: `lua tools/ao-sandbox-validator.lua`
4. **Re-run Validation**: Ensure 100% compliance before commit

Remember: **AO compliance violations will block deployment**. Address all issues before code review.