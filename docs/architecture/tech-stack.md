# Tech Stack

## Cloud Infrastructure
- **Provider:** Arweave Network (AO Protocol)
- **Key Services:** AO process hosting, embedded data storage, AOConnect for Phase 2 integration  
- **Deployment Regions:** Global (decentralized AO network)
- **Runtime Environment:** Lua 5.3 sandboxed execution with 5-second timeout limits
- **Process Architecture:** Monolithic design with embedded dependencies, no external imports
- **Message Protocol:** JSON-encoded AO messages with cryptographic verification

## Technology Stack Table

| Category | Technology | Version | Purpose | Rationale |
|----------|------------|---------|---------|-----------|
| **Process Runtime** | AO (ArOS) | Latest | Lua execution environment for 26 processes | Standard AO runtime with message passing support |
| **Process Language** | Lua | 5.3+ | All 26 processes implemented in pure Lua | Native AO language, sandboxed execution, deterministic |
| **Message Coordination** | AO Messages (JSON) | - | Inter-process communication and orchestration | Native AO async message passing with operation tracking |
| **State Serialization** | JSON | - | GameState serialization between processes | Efficient cross-process data transfer, human-readable |
| **Data Storage** | Embedded Lua Tables | - | Pokemon/move/item databases embedded in processes | Zero external dependencies, sub-millisecond access |
| **Process Orchestration** | coordinator-process.lua | - | Async workflow coordination and state management | Central orchestration with distributed execution |
| **RNG System** | Deterministic Seeded RNG | - | Passed as message data, no process-local randomness | Reproducible game behavior, cross-process consistency |
| **Development Tools** | aolite + aos-local | Latest | Local AO process testing and deployment | Official AO development toolchain |
| **Testing Framework** | aolite + Jest + Custom Lua | Latest | Multi-level testing (unit, integration, parity, chaos) | Comprehensive validation including TypeScript parity |
| **Process Discovery** | Fixed Process Topology | - | Predefined process addresses, no dynamic discovery | Eliminates discovery overhead, predictable routing |
| **Size Validation** | Custom Lua Linter | - | 500KB constraint enforcement and AO sandbox validation | Prevents deployment of oversized or incompatible processes |
| **Error Handling** | Client-Side Timeout Management | - | Process failure detection and retry logic | Leverages client capabilities, maintains stateless design |

## AO Runtime Specifications

### Process Implementation Requirements
- **Monolithic Design**: All dependencies embedded in single file, no require() statements
- **Handler Pattern**: Use `Handlers.add()` with tag matching, not direct assignment
- **Error Handling**: All operations wrapped in pcall with structured error responses
- **Performance Monitoring**: Built-in timeout detection and execution time tracking
- **Deterministic Execution**: Seeded RNG, no process-local randomness or external I/O

### Available AO Globals
| Global | Purpose | Usage Pattern |
|--------|---------|---------------|
| `ao.send()` | Message transmission | Send responses and notifications to other processes |
| `ao.id` | Process identifier | Include in response metadata for debugging |
| `Handlers` | Message routing | Register handlers with `Handlers.add(name, matcher, handler)` |
| `json` | Data serialization | Encode/decode message data and GameState objects |
| Standard Lua | Core operations | string, table, math, os (limited subset) |

### Process Communication Protocol
```lua
-- Incoming Message Structure
msg = {
    Id = "message_id",
    From = "sender_address", 
    Target = "target_process_id",
    Action = "ProcessLogic",
    Data = "json_encoded_data",
    GameState = "json_encoded_gamestate"
}

-- Outgoing Response Structure  
ao.send({
    Target = msg.From,
    Action = "Success|Error",
    Data = json.encode(result_data),
    Error = error_message, -- Optional
    GameState = json.encode(updated_gamestate),
    ProcessId = ao.id,
    Timestamp = tostring(os.time())
})
```

### Development and Testing Stack
| Tool | Purpose | Usage |
|------|---------|-------|
| **aolite** | Local AO emulation | `npm run test:aolite` - Unit testing with AO globals |
| **aos-local** | Integration testing | `npm run test:aos-local` - Multi-process message flow |
| **AO Sandbox Validator** | Compliance checking | `npm run lint:ao-sandbox` - Verify AO compatibility |
| **Size Validator** | File size limits | `npm run validate:size` - Enforce 500KB process limit |

### Performance Constraints
- **Execution Timeout**: 5-second limit per message handler
- **File Size Limit**: 500KB maximum per process file
- **Memory Constraints**: Limited by AO network specifications
- **CPU Cycles**: Bounded computational resources per execution
- **Message Size**: Practical limits on JSON payload size

### Security and Validation
- **Input Sanitization**: All external data validated and sanitized
- **Deterministic Behavior**: No access to system time, filesystem, or network
- **Process Isolation**: Each process runs in isolated Lua environment
- **Message Authentication**: AO protocol handles cryptographic verification
- **State Integrity**: GameState validation prevents corruption across processes
