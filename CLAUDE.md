# Claude Development Notes

This file contains information and commands for Claude to help with development tasks.

## Project Information
- Project: PokéRogue Stateless AO Processes
- Architecture: 26-Process Stateless Architecture with Async Coordination
- Main branch: beta
- Current branch: ECS

## Development Commands
### Process Development
- Test processes (unit): `npm run test:aolite`
- Test processes (integration): `npm run test:aos-local`
- Test parity: `npm run test:parity`
- Validate AO sandbox: `npm run lint:ao-sandbox`
- Validate process sizes: `npm run validate:size`
- Full test suite: `npm run test:all`

### Legacy Commands (Archived)
- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`
- Type check: `npm run typecheck`

## MCP Servers Available
The following MCP servers are configured and available through the Model Context Protocol:

### permamind
- **Type**: Local MCP server (Permanent AI Memory System)
- **Command**: `npx permamind`
- **Repository**: https://github.com/ALLiDoizCode/Permamind
- **Purpose**: Permanent, decentralized AI memory system built on Arweave and AO

#### Available Tools:

**1. Memory Management Tools**
- AI memory management for persistent storage and retrieval
- Store and query information permanently across sessions
- Create knowledge relationships

**2. Process Tools**
- `generateLuaProcess`: Generate Lua code for AO processes with documentation-informed best practices
  - Parameters: `userRequest` (required), `domains` (optional), `includeExplanation` (optional)
  - Usage: `"Generate a token transfer process"`
- `spawnProcess`: Spawn new AO processes with optional template support
- `evalProcess`: Deploy Lua code to processes (handlers, modules)
- `executeAction`: Send messages to processes using natural language
- `queryAOProcessMessages`: Query process message history and communication logs
- `validateDeployment`: Validate deployed process functionality
- `rollbackDeployment`: Rollback failed deployments
- `analyzeProcessArchitecture`: Analyze process architecture and structure

**3. Token Tools**
- Token operations for balance, transfer, and info queries
- Advanced minting strategies
- Credit notice detection

**4. Documentation Tools**
- Permaweb documentation, file storage, and deployment tools
- Access to decentralized documentation systems

**5. Contact Tools**
- Contact and address management tools
- Manage decentralized identity and addresses

**6. Hub Tools**
- Hub creation and management tools for Velocity protocol
- Decentralized hub discovery and management

**7. User Tools**
- User information tools for getting public key and hub ID
- Identity management and credentials

**8. ArNS Tools**
- ArNS name system operations for decentralized domains
- Domain name registration and management

#### Usage Instructions:
- **Memory Storage**: Simply tell Claude to remember something - it will be stored permanently
- **Process Queries**: Ask about AO process capabilities using natural language
- **Token Operations**: Use conversational commands for blockchain operations
- **Zero Configuration**: All tools work automatically without setup

#### Benefits:
- Permanent memory (never forgets across sessions)
- Self-documenting AO processes
- Natural language blockchain interactions
- Automatic process discovery

### aolite Docs  
- **Type**: SSE (Server-Sent Events) documentation server
- **URL**: https://gitmcp.io/perplex-labs/aolite
- **Repository**: https://github.com/perplex-labs/aolite
- **Purpose**: Local, concurrent emulation of the Arweave AO protocol for testing Lua processes
- **Key Features**:
  - **Local AO Environment**: Simulates AO protocol without network deployment
  - **Concurrent Process Emulation**: Uses coroutines for process management
  - **Message Passing**: Send messages between processes with queue management
  - **Direct Process State Access**: Inspect process state during development
  - **Flexible Scheduler Control**: Manual or automatic message scheduling
  - **Configurable Logging**: Multiple log levels (0-3) with optional output capture
- **Core API Methods**:
  - `spawnProcess()`: Load and spawn processes from string or file
  - `send()`: Send messages between processes
  - `eval()`: Evaluate code in process context
  - `getAllMsgs()`: Retrieve messages by various criteria
  - `runScheduler()`: Execute message scheduling
  - `setMessageLog()`: Configure message logging
- **Usage**: 
  - Test AO processes locally before deployment
  - Debug process interactions and message flows
  - Develop Lua handlers with AO-compatible globals (`ao`, `Handlers`)
- **Requirements**: Lua 5.3

### harlequin-toolkit Docs
- **Type**: SSE (Server-Sent Events) documentation server  
- **URL**: https://gitmcp.io/the-permaweb-harlequin/harlequin-toolkit
- **Repository**: https://github.com/the-permaweb-harlequin/harlequin-toolkit
- **Purpose**: Web development toolkit for Permaweb applications using Rspress
- **Key Features**:
  - **Rspress Website Framework**: Modern web development with TypeScript support
  - **Multi-Component Architecture**: Includes CLI, SDK, server, and app components
  - **Development Tools Integration**: Pre-configured with Nx, ESLint, Prettier
  - **TypeScript Support**: Full TypeScript development environment
- **Components**:
  - **CLI**: Command-line interface tools
  - **SDK**: Software development kit for Permaweb integration
  - **Server**: Backend server components
  - **App**: Frontend application framework
- **Development Commands**:
  - `npm install`: Install dependencies
  - `npm run dev`: Start development server
  - `npm run build`: Build for production
  - `npm run preview`: Preview production build
- **CLI Commands**:
  - `harlequin`: Launch interactive TUI (Terminal User Interface)
  - `harlequin build`: Interactive build mode for Arweave projects
  - `harlequin build ./my-project`: Direct CLI build mode (for automation)
  - `harlequin build --entrypoint <file>`: Build with specific entry point
  - `harlequin lua-utils bundle --entrypoint main.lua`: Bundle Lua files
  - `harlequin version` / `-v`: Display version information
  - `harlequin help` / `-h`: Show usage instructions
- **CLI Features**:
  - 🎨 Beautiful Terminal UI with Charm Bubble Tea
  - 📁 Smart File Discovery
  - ⚙️ Configuration Management (YAML-based)
  - 🚀 Real-time Progress Tracking
  - 🔧 Clear Error Handling
- **Usage**:
  - Build modern web applications for the Permaweb
  - Develop decentralized applications with TypeScript
  - Create permanent web content and interfaces
- **Context**: The Permaweb is Arweave's permanent, censorship-resistant web infrastructure
- **Status**: Early development stage (no releases yet)

## ECS Architecture References
Core Entity-Component-System architecture documentation for development guidance:

### Bevy ECS Reference
- **Repository**: https://github.com/bevyengine/bevy/tree/main/crates/bevy_ecs
  - **Architecture**: Archetype-based ECS with data-oriented design patterns
  - **Core Components**: World (container), Entities (identifiers), Components (data), Systems (logic)
  - **Key Features**: Change detection, parallel system execution, resource management, event handling
  - **Performance**: Cache-friendly data layout, SIMD optimization support, sparse/dense storage hybrid
  - **Query System**: Type-safe entity queries with filters and combinators
  - **System Scheduling**: Dependency resolution, parallel execution with conflict detection
  - **Storage Types**: Table storage (dense), SparseSet storage (sparse), optimized for different access patterns

### Quick Reference Commands
Access Bevy ECS documentation:
```bash
# Bevy ECS crate
WebFetch: https://github.com/bevyengine/bevy/tree/main/crates/bevy_ecs
# Bevy ECS examples
WebFetch: https://github.com/bevyengine/bevy/tree/main/examples/ecs
```

## HyperBeam Documentation Resources
Core HyperBeam technical documentation available for all Claude sessions:

### Primary HyperBeam References
- **Official Documentation**: https://hyperbeam.arweave.net/build/introduction/what-is-hyperbeam.html
  - **Architecture**: Erlang/OTP framework implementation of AO-Core protocol
  - **Core Components**: Messages (cryptographically-linked data), Devices (modular Erlang modules), Paths (HTTP API interactions)
  - **Key Features**: Exceptional concurrency via BEAM VM, high fault tolerance, scalable distributed architecture
  - **Purpose**: Decentralized operating system for AO Computer, trust-minimized distributed supercomputer

- **Rust NIF Implementation Tutorial**: https://blog.decent.land/rust-hb-tutorial/
  - **NIF Details**: Rustler crate for native functions, DirtyCpu scheduler for network I/O
  - **Performance**: Uses blocking I/O with ureq HTTP client, modular device architecture
  - **Integration**: Dynamic NIF loading, Erlang wrapper modules, compiled .so libraries
  - **Key Dependencies**: rustler, ureq, serde, anyhow

- **Development Workshop**: https://hackmd.io/BHDsFUVLQSuVUXVJoaGSEQ  
  - **Agent Implementation**: Lua scripting, process-based computation, trading simulation patterns
  - **Workflow**: NodeJS setup, aos command-line spawning, modular code loading
  - **Patterns**: Event-driven handlers, state management, SMA trading strategies

- **Core Repository**: https://github.com/permaweb/HyperBEAM
  - **Technical Stack**: Erlang OTP 27, 25 preloaded devices, WebAssembly execution support
  - **Key Devices**: ~meta@1.0 (configuration), ~relay@1.0 (messaging), ~wasm64@1.0 (execution), ~snp@1.0 (TEE proofs)
  - **Message Model**: Binary terms/function maps, lazy evaluation, cross-node sharding support
  - **Build Profiles**: genesis_wasm, rocksdb, http3 QUIC support

### HyperBeam vs Current Implementation
**Current PokéRogue HyperBeam Process**: Pure Lua ECS implementation without NIFs
**Official HyperBeam**: Erlang-based with Rust NIF support for performance-critical operations

### Quick Reference Commands
Access these resources anytime with WebFetch:
```bash
# Primary docs
WebFetch: https://hyperbeam.arweave.net/build/introduction/what-is-hyperbeam.html
# Rust NIF tutorial  
WebFetch: https://blog.decent.land/rust-hb-tutorial/
# Development workshop
WebFetch: https://hackmd.io/BHDsFUVLQSuVUXVJoaGSEQ
# Core repository
WebFetch: https://github.com/permaweb/HyperBEAM
```

## MCP Best Practices
- **Memory Management**: Use permamind or similar memory servers to maintain context across sessions
- **Documentation Access**: Leverage the documentation servers for real-time access to technical documentation
- **HyperBeam Resources**: Reference the HyperBeam documentation section above for architecture and implementation details
- **Permanent Storage**: Use aolite documentation for implementing permanent storage solutions
- **Decentralized Development**: Use harlequin-toolkit docs for building on the Permaweb

## AO Process Implementation Guidelines

### CRITICAL: AO + ADP Compliance Requirements
All Lua processes MUST follow these patterns to comply with AO runtime and ADP (AO Documentation Protocol) v1.0 specification:

#### 1. Monolithic Design (REQUIRED)
```lua
-- ❌ FORBIDDEN: External dependencies
local utils = require('utils')

-- ✅ REQUIRED: Embed all dependencies
local function validateInput(data)
    -- Embedded utility function
end
```

#### 2. Handler Pattern (REQUIRED)
```lua
-- ❌ FORBIDDEN: Direct assignment
Handlers["ProcessLogic"] = function(msg) end

-- ❌ FORBIDDEN: Multi-action handlers (won't work in AO runtime)
Handlers.add("multi-handler",
    Handlers.utils.hasMatchingTag("Action", {"Action1", "Action2", "Action3"}),
    function(msg) end
)

-- ✅ REQUIRED: Individual handlers for each action
Handlers.add("action-one",
    Handlers.utils.hasMatchingTag("Action", "Action1"),
    function(msg)
        local response = processAction1(msg)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data
        })
    end
)

Handlers.add("action-two",
    Handlers.utils.hasMatchingTag("Action", "Action2"),
    function(msg)
        local response = processAction2(msg)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data
        })
    end
)
```

#### 3. Error Handling Pattern (REQUIRED)
**CRITICAL: Avoid unnecessary pcall usage** - pcall should ONLY be used for operations that genuinely might fail:

```lua
-- ❌ FORBIDDEN: Unnecessary pcall for simple data access
local success, result = pcall(function()
    return getSpeciesById(id)  -- Simple table lookup never fails
end)

-- ❌ FORBIDDEN: Wrapping entire handler logic in pcall
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local success, response = pcall(function()
            -- ... handler logic ...
            return processLogic(msg)
        end)
        if success then
            ao.send(response)
        else
            ao.send({Target = msg.From, Action = "Error", Error = response})
        end
    end
)

-- ✅ REQUIRED: Direct access with proper validation
local speciesId = msg.SpeciesId or msg.Id
if not speciesId then
    ao.send({
        Target = msg.From,
        Action = "Error", 
        Error = "SpeciesId required"
    })
    return
end

local result = getSpeciesById(tonumber(speciesId))
if result then
    ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode(result)
    })
else
    ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Species not found"
    })
end

-- ✅ ACCEPTABLE: Use pcall ONLY for operations that genuinely might fail
local success, gameState = pcall(json.decode, msg.Data)  -- JSON parsing can fail
if not success then
    ao.send({Target = msg.From, Action = "Error", Error = "Invalid JSON"})
    return
end
```

**When to use pcall (VERY LIMITED):**
- JSON parsing of untrusted external input (`json.decode` from untrusted sources)
- File I/O operations (if available)
- Mathematical operations that might overflow/underflow
- Calling external modules that might not exist

**When NOT to use pcall (MOST CASES):**
- Simple table lookups from embedded data
- Basic parameter validation  
- Simple arithmetic operations
- Accessing msg tags or known data structures
- Handler logic that should fail fast
- Any operation where you control the inputs
- **JSON parsing of AO message data** (`msg.Data`, `msg.Tags` - these are controlled inputs)
- **Entire handler function wrapping** (masks real errors and prevents debugging)
- **Simple validation functions** (should return boolean/error directly)
- **Database lookups from embedded tables** (predictable operations)

**CRITICAL ANTI-PATTERNS TO AVOID:**
```lua
-- ❌ FORBIDDEN: Generic handler wrapper functions
local function safeHandler(handlerFn)
    return function(msg)
        local success, result = pcall(handlerFn, msg)
        if not success then
            ao.send({Target = msg.From, Error = "Handler failed"})
        end
    end
end

-- ❌ FORBIDDEN: Wrapping entire handler body in pcall
Handlers.add("my-handler", pattern, function(msg)
    local success, result = pcall(function()
        -- ... entire handler logic ...
        return { success = true, data = ... }
    end)
    -- Error handling...
end)

-- ❌ FORBIDDEN: Unnecessary pcall for AO message parsing
local success, data = pcall(json.decode, msg.Data)  -- msg.Data is controlled
```

**✅ CORRECT PATTERN: Direct error handling**
```lua
Handlers.add("my-handler", pattern, function(msg)
    -- Direct parameter validation
    if not msg.RequiredParam then
        ao.send({Target = msg.From, Action = "Error", Error = "RequiredParam missing"})
        return
    end
    
    -- Direct data access (no pcall needed for controlled inputs)
    local data = json.decode(msg.Data or "{}")
    local result = processData(data)
    
    -- Direct response
    ao.send({Target = msg.From, Action = "SaveState", Data = json.encode(result)})
end)
```

**AO Best Practice**: Let processes fail fast with clear error messages rather than masking issues with pcall. Use direct error handling with `ao.send()` and `return` statements.

#### 4. Timestamp Handling (REQUIRED)
```lua
-- ❌ FORBIDDEN: os.time() in AO processes
local timestamp = os.time()

-- ✅ REQUIRED: Use msg.Timestamp in handlers
local timestamp = msg.Timestamp or 0

-- ✅ TESTING: Mock timestamp for test files
local mockTimestamp = 1234567890
```

#### 5. Available AO Globals
- `ao.send()` - Send messages to other processes
- `ao.id` - Current process ID
- `Handlers` - Message handler registry
- `json` - JSON encode/decode utilities
- Standard Lua: string, table, math, os (limited subset)

#### 6. Forbidden Operations
- `require()` - No external module loading
- `io` - No file system access
- `debug` - Debug library unavailable
- `os.time()` - Use `msg.Timestamp` instead
- Network operations (only through ao.send)

#### 8. CRITICAL: No Module-Level Returns (REQUIRED)
AO processes MUST NOT use module-level return statements. All data exchange happens through message passing:

```lua
-- ❌ FORBIDDEN: Module-level returns
return {
    handler = someHandler,
    data = someData
}

-- ✅ REQUIRED: Use ao.send() only
-- AO processes should not return module exports
-- All data is handled through message passing via ao.send()
print("Process initialization complete.")
```

**Why this matters:**
- AO runtime doesn't support module returns
- Breaks AO process isolation model
- Prevents proper message-based communication
- Causes deployment failures in AO environment

#### 9. CRITICAL: Tags vs Data Field Usage (REQUIRED)
Use the right approach for the right data: tags for simple parameters, Data field for complex structures and large blobs:

```lua
-- ✅ REQUIRED: Use tags for simple parameters
local speciesId = msg.SpeciesId or msg.Id
local operation = msg.Operation
if speciesId then
    processSpecies(tonumber(speciesId))
end

-- ✅ REQUIRED: Use Data field for complex structures
local gameState = nil
if msg.Data and msg.Data ~= "" then
    gameState = json.decode(msg.Data)
end

-- ✅ REQUIRED: Use Data field for large blobs (images, files, etc.)
local imageData = msg.Data  -- Raw binary or base64 data
local documentContent = msg.Data  -- Large text content

-- ❌ FORBIDDEN: Simple parameters in Data
local data = json.decode(msg.Data or "{}")
local id = data.id  -- Should be msg.Id tag instead
```

**When to use Tags:**
- Simple identifiers: `SpeciesId`, `PlayerId`, `BattleId`
- Enum-like values: `Operation`, `Type`, `Category`
- Small strings/numbers: `Name`, `Level`, `Generation`
- Flags: `Confirmed`, `Force`, `Override`

**When to use Data field:**
- Complex objects: `gameState`, `pokemonData`, `battleResult`
- Large text content: documentation, descriptions, logs
- Binary data: images, files, encrypted payloads
- Arrays/lists: multiple items, batch operations
- Nested structures: configuration objects, schemas

**Response patterns:**
```lua
-- ✅ CORRECT: Simple response with individual tags (all values as strings)
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Success = "true",
    SpeciesId = tostring(result.id),
    SpeciesName = result.name,
    HP = tostring(result.baseStats.hp),
    Attack = tostring(result.baseStats.attack),
    Type1 = tostring(result.types[1]),
    Type2 = result.types[2] and tostring(result.types[2]) or "",
    Generation = tostring(result.generation)
})

-- ✅ CORRECT: Complex response using Data field for nested structures
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = json.encode({
        species = speciesData,
        stats = baseStats,
        moves = availableMoves
    })
})

-- ❌ FORBIDDEN: Don't send simple data as JSON in Data field
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = json.encode({
        speciesId = 123,
        name = "Pikachu",
        found = true
    })
})
```

**Tag naming conventions:**
- Use PascalCase: `SpeciesId`, `PlayerName`, `BattleId`
- Provide alternatives: `msg.SpeciesId or msg.Id`
- Convert strings to numbers: `tonumber(msg.SpeciesId)`
- Boolean flags: `msg.Confirmed == "true"`
- **CRITICAL**: All tag values MUST be strings: `tostring(number)`, `"true"/"false"` for booleans
- Empty optional values: use `""` instead of `nil` for optional tags

**Why this matters:**
- Tags are native to AO message system
- Data field optimized for large payloads
- Better performance and readability
- Follows AO architectural patterns

#### 10. ADP v1.0 Compliance (REQUIRED)
```lua
-- ✅ REQUIRED: Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = "Process Name",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {"operation1", "operation2"},
                    messageSchemas = {
                        ProcessLogic = {
                            required = {"Action", "Data", "Timestamp"}
                        }
                    }
                },
                handlers = {"ProcessLogic", "HealthCheck", "Info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true
                }
            }
        })
    end
)
```

#### 11. Testing Pattern for AO Processes
```lua
-- Mock AO environment for testing
local function setupTestEnvironment()
    if not ao then
        ao = {
            send = function(msg) print("Mock send:", json.encode(msg)) end,
            id = "test_process_id"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
            end
        }
    end
end
```

## ADP (AO Documentation Protocol) v1.0 Standards

### What is ADP?
ADP (AO Documentation Protocol) v1.0 is a standardized protocol that enables AO processes to automatically document their capabilities, handlers, and interfaces. This enables self-documentation and intelligent tool integration.

### ADP Core Requirements
1. **Protocol Identifier**: `adpVersion: "1.0"`
2. **Info Handler**: Required handler that responds to `Action: "Info"` with process metadata
3. **Message Schemas**: Defined schemas for all supported message types
4. **Process Metadata**: Name, version, capabilities, and documentation
5. **Self-Documentation**: Processes can be queried for their capabilities

### ADP Benefits
- **Autonomous Tool Integration**: AI tools can discover and interact with processes automatically
- **Self-Documenting Architecture**: Reduces maintenance overhead
- **Standardized Discovery**: Consistent way to query process capabilities
- **Future-Proof**: Ensures compatibility with evolving AO ecosystem

### ADP Implementation Example
See `processes/battle-engine-adp.lua` for a complete ADP v1.0 compliant implementation.

### Process Development Standard: Permamind-First Approach
**ALL new AO processes MUST be generated using Permamind** for ADP v1.0 compliance:

```bash
# Generate ADP-compliant process using Permamind
mcp://permamind/generateLuaProcess {
    "userRequest": "Create a [process description with functionality]",
    "includeExplanation": true
}
```

#### Why Permamind-First?
- **ADP v1.0 Compliance**: Automatic compliance with self-documentation standards
- **Production-Ready**: Complete game mechanics and error handling
- **Consistent Quality**: Standardized structure and validation
- **Future-Proof**: Compatible with autonomous AI agents
- **Development Speed**: Instant generation vs manual template development

#### Manual Templates Deprecated
Manual templates have been archived to `archive/templates/` as they are superseded by Permamind's superior output quality and ADP compliance.

## Notes
- **Project Status**: Stateless AO Process Architecture (Phase 1-2 Complete)
- **Architecture**: 26-Process Stateless AO with Async Coordination
- **Performance**: Sub-5-second execution with 500KB process limits
- **Platform**: Arweave AO with monolithic process design
- **ADP Compliance**: All new processes MUST implement ADP v1.0 for future compatibility
- **Development Standard**: Permamind-first approach for all process generation
- **Legacy Archive**: Previous implementation and manual templates archived in `archive/` directory
- **AO Compliance**: All processes now follow monolithic design with proper handler patterns
- MCP servers provide additional capabilities for memory management and documentation access

## AO Compliance Validation System

**CRITICAL**: Enhanced AO compliance validation implemented to prevent deployment-blocking violations.

### Automated Validation
- **Pre-commit Hook**: `ao-compliance` in lefthook.yml automatically validates process files
- **Manual Command**: `npm run lint:ao-sandbox` 
- **Direct Tool**: `lua tools/ao-sandbox-validator.lua`

### Enhanced Validation Features
- ✅ **Strict Forbidden Pattern Detection**: require(), unnecessary pcall, os.time()
- ✅ **Anti-Pattern Detection**: pcall(json.decode, msg.Data), handler wrappers
- ✅ **Best Practice Validation**: Error handling patterns, timestamp usage
- ✅ **100% Compliance Required**: No tolerance for critical violations
- ✅ **Detailed Reporting**: Specific violations with fix suggestions

### Developer Resources
- **📚 Full Guidelines**: `docs/architecture/ao-compliance-guidelines.md`
- **⚡ Quick Reference**: `docs/architecture/ao-quick-reference.md` 
- **🔧 Validation Tool**: Enhanced `tools/ao-sandbox-validator.lua`
- **🎯 Pre-commit Integration**: Automatic validation in development workflow

### Common Violations Fixed
Based on Story 13.3 review findings and validation system improvements:
- ✅ `require("json")` is PERMITTED in AO (only JSON require allowed)
- ❌ `pcall(json.decode, msg.Data)` → ✅ Direct `json.decode(msg.Data)`
- ❌ `os.time()` → ✅ `msg.Timestamp`
- ❌ `require("./utils")` → ✅ Embed utilities in process file

The validation system ensures these critical issues are caught during development rather than at review stage.

## Automated README Updates
The project includes automated README Migration Parity Checklist updates:
- `scripts/update-progress-checklist.sh` - Scans completed stories and updates checklist
- `.git/hooks/pre-push` - Automatically runs checklist update before pushes
- Checklist items are marked ✅ when corresponding stories show "Done" or "PASS" status