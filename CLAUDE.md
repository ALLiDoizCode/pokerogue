# Claude Development Notes

This file contains essential information for Claude to assist with PokéRogue AO process development.

## Quick Start

### Project Information
- **Project**: PokéRogue Stateless AO Processes
- **Architecture**: 26-Process Stateless Architecture with Async Coordination
- **Platform**: Arweave AO with monolithic process design
- **Main branch**: beta
- **Current branch**: ECS

### Essential Commands
```bash
# Testing
npm run test:aolite          # Unit tests (Lua/aolite)
npm run test:parity          # Parity tests (Lua vs TS)
npm run test:aos-local       # Integration tests
npm run test:all             # Full test suite

# Validation
npm run lint:ao-sandbox      # AO compliance check
npm run validate:size        # Process size limits
```

---

## Testing Guide

### Test File Requirements

**⚠️ ALL TEST FILES MUST BE LUA FORMAT (.test.lua), NOT TYPESCRIPT**

- **Unit tests**: `testing/unit/*.test.lua` (using aolite framework)
- **Parity tests**: `testing/parity/*-parity.test.lua` (Lua vs TS comparison)
- **Integration tests**: `testing/integration/*.test.js` (Node.js/aos-local)

**Examples:**
- ✅ `testing/unit/my-process.test.lua`
- ✅ `testing/parity/my-feature-parity.test.lua`
- ❌ `testing/unit/my-process.test.ts` (causes CI failures)

### Aolite Test Pattern

**All unit tests MUST use the real aolite framework.** See `.ai/patterns/aolite-test-pattern.lua` for the authoritative pattern.

**Quick Pattern:**
```lua
local aolite = require("aolite")
local json = require("json")

-- Module path (recommended)
local PROCESS_PATH = "processes.my-process"
local processId = "test-my-process"
aolite.spawnProcess(processId, PROCESS_PATH)

-- Send messages
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }
    if tags then
        for k, v in pairs(tags) do msg[k] = tostring(v) end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test
local response = sendMessage("Info")
if response and response.Action == "InfoResponse" then
    print("✅ Test passed")
else
    error("❌ Test failed")
end
```

**Key Requirements:**
1. Use `require("aolite")` from real framework
2. `processId` is a string (e.g., "test-my-process")
3. Include `From: processId` in all messages
4. Use `aolite.send(msg)` then `aolite.getLastMsg(processId)`
5. Use `error()` for test failures
6. Linear execution (no describe/it blocks)

**Reference Files:**
- ✅ `.ai/patterns/aolite-test-pattern.lua` (authoritative)
- ✅ `testing/unit/pokemon-species-db.test.lua` (example)

**TDD Validation:**
- Process file: `processes/X.lua` requires test: `testing/unit/X.test.lua`
- Test must execute successfully with `npm run test:aolite`

---

## AO Process Implementation Guidelines

All Lua processes must comply with AO runtime and ADP v1.0 specification.

### Core Requirements

#### 1. Monolithic Design
```lua
-- ❌ FORBIDDEN: External dependencies
local utils = require('utils')

-- ✅ REQUIRED: Embed all dependencies
local function validateInput(data)
    -- Embedded utility function
end
```

#### 2. Handler Pattern
**Each action needs its own handler.** See `.ai/patterns/ao-handler-pattern.lua` for full examples.

```lua
-- ✅ REQUIRED: Individual handler per action
Handlers.add("action-one",
    Handlers.utils.hasMatchingTag("Action", "Action1"),
    function(msg)
        if not msg.RequiredParam then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "RequiredParam required"
            })
            return
        end

        local result = processAction(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result)
        })
    end
)

-- ❌ FORBIDDEN: Multi-action handlers
Handlers.add("multi",
    Handlers.utils.hasMatchingTag("Action", {"Action1", "Action2"}),
    function(msg) end
)
```

#### 3. Error Handling
**⚠️ Avoid unnecessary pcall** - Only use for operations that genuinely might fail.

See `.ai/patterns/ao-error-handling.lua` for complete patterns.

```lua
-- ✅ CORRECT: Direct validation
if not msg.RequiredParam then
    ao.send({Target = msg.From, Action = "Error", Error = "Missing param"})
    return
end

-- ❌ FORBIDDEN: Unnecessary pcall
local success, result = pcall(function()
    return getSpeciesById(id)  -- Simple lookup never fails
end)
```

**When to use pcall:**
- JSON parsing of untrusted external input
- File I/O operations (if available)
- Mathematical operations that might overflow

**When NOT to use pcall:**
- Simple table lookups
- Parameter validation
- Accessing msg tags
- JSON parsing of AO message data (controlled inputs)
- Entire handler wrapping

#### 4. Message Structure: Tags vs Data

See `.ai/patterns/ao-message-patterns.lua` for complete examples.

**Use Tags for:**
- Simple identifiers: `SpeciesId`, `PlayerId`
- Enums: `Operation`, `Type`, `Category`
- Small values: `Name`, `Level`, `Generation`
- Flags: `Confirmed`, `Force`

**Use Data field for:**
- Complex objects: `gameState`, `pokemonData`
- Large text: documentation, logs
- Binary data: images, files
- Arrays/lists
- Nested structures

**Tag Conventions:**
```lua
-- ✅ All tag values MUST be strings
ao.send({
    Target = msg.From,
    Action = "SaveState",
    SpeciesId = tostring(result.id),  -- Convert numbers
    Success = "true",                  -- Booleans as strings
    OptionalField = ""                 -- Empty string for nil
})
```

#### 5. Timestamp Handling
```lua
-- ❌ FORBIDDEN: os.time() in AO processes
local timestamp = os.time()

-- ✅ REQUIRED: Use msg.Timestamp
local timestamp = msg.Timestamp or 0
```

#### 6. Available AO Globals
- `ao.send()` - Send messages
- `ao.id` - Process ID
- `Handlers` - Handler registry
- `json` - JSON utilities
- Standard Lua: string, table, math (limited)

#### 7. Forbidden Operations
- `require()` - No external modules (except `json`)
- `io` - No file system access
- `debug` - Unavailable
- `os.time()` - Use `msg.Timestamp`
- Network operations (only through ao.send)
- Module-level returns

#### 8. ADP v1.0 Compliance

All processes must include an Info handler for self-documentation:

```lua
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Process Name",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {"operation1", "operation2"}
                },
                handlers = {"handler1", "handler2", "info"}
            })
        })
    end
)
```

### Process Development Standard

**Use Permamind for all new AO processes** (ensures ADP v1.0 compliance):

```bash
mcp://permamind/generateLuaProcess {
    "userRequest": "Create a [process description]",
    "includeExplanation": true
}
```

**Benefits:**
- Automatic ADP v1.0 compliance
- Production-ready code
- Consistent quality
- Instant generation

---

## MCP Servers

### Available Servers

| Server | Purpose | Key Tools |
|--------|---------|-----------|
| **permamind** | Permanent AI memory & AO process tools | `generateLuaProcess`, `spawnProcess`, `evalProcess`, `executeAction` |
| **aolite Docs** | Local AO protocol emulation docs | Testing guidance, API reference |
| **harlequin-toolkit** | Permaweb development toolkit | Build tools, deployment utilities |

### Permamind

**Type**: Local MCP server (Permanent AI Memory System)
**Repository**: https://github.com/ALLiDoizCode/Permamind

**Core Capabilities:**
1. **Memory Management** - Permanent storage across sessions
2. **Process Tools** - Generate, spawn, deploy, and query AO processes
3. **Token Operations** - Balance checks, transfers, minting
4. **Documentation** - Permaweb docs and file storage
5. **ArNS** - Decentralized domain management
6. **Hub & Contact Tools** - Identity and address management

**Usage:**
- Memory: Tell Claude to remember something - stored permanently
- Process queries: Ask about AO capabilities using natural language
- Token operations: Conversational blockchain commands
- Zero configuration required

### aolite Docs

**Type**: SSE documentation server
**URL**: https://gitmcp.io/perplex-labs/aolite
**Repository**: https://github.com/perplex-labs/aolite

**Purpose**: Local AO protocol emulation for testing Lua processes

**Key Features:**
- Local AO environment (no network deployment)
- Concurrent process emulation (coroutines)
- Message passing with queue management
- Direct process state inspection
- Flexible scheduler control
- Configurable logging (levels 0-3)

**Core API:**
- `spawnProcess()` - Load and spawn processes
- `send()` - Send messages between processes
- `eval()` - Evaluate code in process context
- `getAllMsgs()` - Retrieve messages
- `runScheduler()` - Execute message scheduling

**Requirements**: Lua 5.3

### harlequin-toolkit Docs

**Type**: SSE documentation server
**URL**: https://gitmcp.io/the-permaweb-harlequin/harlequin-toolkit
**Repository**: https://github.com/the-permaweb-harlequin/harlequin-toolkit

**Purpose**: Web development toolkit for Permaweb applications

**Components:**
- CLI (command-line tools)
- SDK (Permaweb integration)
- Server (backend components)
- App (frontend framework)

**CLI Commands:**
```bash
harlequin                              # Interactive TUI
harlequin build                        # Interactive build mode
harlequin build ./my-project           # Direct build
harlequin lua-utils bundle --entrypoint main.lua
```

**Features:**
- Beautiful Terminal UI (Charm Bubble Tea)
- Smart file discovery
- YAML-based configuration
- Real-time progress tracking
- TypeScript support

---

## Development Resources

### AO Compliance Validation

**Automated validation prevents deployment-blocking violations.**

**Commands:**
```bash
npm run lint:ao-sandbox              # Run validation
lua tools/ao-sandbox-validator.lua   # Direct tool
```

**Pre-commit Hook:** `ao-compliance` in lefthook.yml runs automatically

**Validation Features:**
- ✅ Forbidden pattern detection: `require()`, unnecessary `pcall`, `os.time()`
- ✅ Anti-pattern detection: `pcall(json.decode, msg.Data)`, handler wrappers
- ✅ Best practice validation: Error handling, timestamps
- ✅ 100% compliance required

**Resources:**
- 📚 `docs/architecture/ao-compliance-guidelines.md` (full guidelines)
- ⚡ `docs/architecture/ao-quick-reference.md` (quick reference)
- 🔧 `tools/ao-sandbox-validator.lua` (validation tool)

**Common Violations:**
- ✅ `require("json")` is PERMITTED
- ❌ `pcall(json.decode, msg.Data)` → ✅ Direct `json.decode(msg.Data)`
- ❌ `os.time()` → ✅ `msg.Timestamp`
- ❌ `require("./utils")` → ✅ Embed utilities in process

### Pattern Reference Files

All pattern files are located in `.ai/patterns/`:

| File | Purpose |
|------|---------|
| `aolite-test-pattern.lua` | Authoritative test pattern |
| `ao-handler-pattern.lua` | Proper handler implementation |
| `ao-error-handling.lua` | Error handling best practices |
| `ao-message-patterns.lua` | Tags vs Data field usage |

### Automated Tools

**README Updates:**
- `scripts/update-progress-checklist.sh` - Updates migration checklist
- `.git/hooks/pre-push` - Runs checklist update before pushes

### Architecture Status

- **Phase 1-2**: Complete
- **Performance**: Sub-5-second execution
- **Process Limits**: 500KB max size
- **Design**: Monolithic, stateless AO processes
- **Compliance**: ADP v1.0 for all new processes

---

## Notes

- Use Permamind-first approach for process generation
- All processes require ADP v1.0 compliance (Info handler)
- Legacy templates archived in `archive/templates/`
- Test files must be Lua (.test.lua) not TypeScript
- MCP servers provide memory, docs, and tooling capabilities
