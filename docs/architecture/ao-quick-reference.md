# AO Quick Reference Card

**🚀 Fast Reference for AO Process Development**

## ❌ Don't Use These (Will Break)
```lua
require("./utils")           // No external modules (except json)
pcall(json.decode, msg.Data) // No pcall for controlled data  
os.time()                    // Use msg.Timestamp
io.open()                    // No file system access
debug.getinfo()              // No debug operations
```

## ✅ Use These Instead
```lua
// JSON handling (require allowed):
local json = require("json")   // JSON require is permitted
json.encode(data)              // JSON encode
json.decode(data)              // JSON decode

// AO Globals Available:
ao.send({Target, Action, Data}) // Send messages
ao.id                          // Process ID
Handlers.add(name, pattern, fn) // Register handlers
msg.Timestamp                  // Deterministic time
```

## 🎯 Handler Pattern
```lua
Handlers.add("action-name",
    Handlers.utils.hasMatchingTag("Action", "ActionName"),
    function(msg)
        // Direct error handling:
        if not msg.RequiredParam then
            ao.send({Target = msg.From, Action = "Error", Error = "Missing param"})
            return
        end
        
        // Process and respond:
        local result = processData(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState", 
            Data = json.encode(result)
        })
    end
)
```

## 📨 Message Structure
```lua
// Incoming message access:
local param = msg.ParamName        // Simple parameters (strings)
local data = json.decode(msg.Data) // Complex data structures

// Outgoing message format:
ao.send({
    Target = msg.From,
    Action = "SaveState",           // or "Error"
    Success = "true",               // Always include
    Data = json.encode(response),   // Complex data
    ProcessId = ao.id,              // Process identification
    Timestamp = tostring(msg.Timestamp or 0)
})
```

## 🧪 Testing Setup
```lua
// Mock AO environment:
ao = {
    messages = {},
    id = "test_process_id",
    send = function(msg) table.insert(ao.messages, msg) end
}

Handlers = {
    add = function(name, matcher, handler) 
        // Store for testing
    end
}

// Load your process:
dofile("processes/your-process.lua")
```

## 🔧 Validation Commands
```bash
npm run lint:ao-sandbox    # Validate all processes
lua tools/ao-sandbox-validator.lua  # Direct validation
```

## ⚡ Performance Tips
- Store Pokemon by ID reference only: `{party: {pokemon: {[1]: "pokemon_id_123"}}}`
- Use deterministic execution: `msg.Timestamp` not `os.time()`
- Keep processes under 500KB, aim for ~25-30KB
- Implement rate limiting: 50 operations/minute/player

## 🎯 ADP v1.0 Required
```lua
// Must have Info handler:
Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
    ao.send({Target = msg.From, Action = "SaveState", Data = json.encode({
        name = "Process Name", version = "1.0.0", adpVersion = "1.0"
    })})
end)
```

## 🚨 Emergency Debug
```lua
// Add temporary logging:
print("Debug:", json.encode(msg))

// Check what handlers are registered:
print("Handler registered: " .. handlerName)

// Validate message structure:
if not msg.Action then print("Missing Action tag") end
```

**🔗 Full Guide**: `docs/architecture/ao-compliance-guidelines.md`