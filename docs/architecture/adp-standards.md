# ADP (AO Documentation Protocol) v1.0 Standards

## Overview

The PokéRogue AO project has adopted ADP (AO Documentation Protocol) v1.0 as the standard for all AO processes. ADP enables processes to automatically document their capabilities, handlers, and interfaces, supporting self-documentation and intelligent tool integration.

## ADP v1.0 Specification

### Core Requirements

1. **Protocol Identifier**: All processes MUST include `adpVersion: "1.0"` in their metadata
2. **Info Handler**: Required handler responding to `Action: "Info"` with complete process metadata
3. **Message Schemas**: Defined schemas for all supported message types
4. **Process Metadata**: Complete metadata including name, version, capabilities, and documentation
5. **Self-Documentation**: Processes MUST be queryable for their capabilities

### ADP Message Structure

```lua
-- ADP v1.0 compliant Info response
{
    process = {
        name = "Process Name",
        version = "1.0.0",
        adpVersion = "1.0",
        processId = "process-id",
        processType = "logic|data|coordinator",
        capabilities = {"operation1", "operation2"},
        messageSchemas = {
            ProcessLogic = {
                required = {"Action", "Data", "Timestamp"},
                Data = {
                    required = {"gameState", "operation", "parameters"}
                }
            }
        }
    },
    handlers = {"ProcessLogic", "HealthCheck", "Info"},
    documentation = {
        adpCompliance = "v1.0",
        selfDocumenting = true,
        deterministicRNG = true,
        productionReady = true
    }
}
```

## Implementation Requirements

### 1. Process Metadata Structure

```lua
local PROCESS_METADATA = {
    name = "Process Name",
    version = "1.0.0",
    description = "Process description",
    author = "PokéRogue AO Team",
    license = "MIT",
    processId = ao.id or "process-id",
    processType = "logic", -- "logic", "data", or "coordinator"
    adpVersion = "1.0",
    created = os.time(),
    capabilities = {
        "operation1",
        "operation2"
    },
    messageSchemas = {
        -- Define all supported message types
    },
    supportedOperations = {
        -- Define all operations with parameters and returns
    }
}
```

### 2. Required Handlers

All ADP-compliant processes MUST implement these handlers:

#### Info Handler (ADP Required)
```lua
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = PROCESS_METADATA,
                handlers = {"ProcessLogic", "HealthCheck", "Info"},
                messageSchemas = PROCESS_METADATA.messageSchemas,
                supportedOperations = PROCESS_METADATA.supportedOperations,
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true
                }
            },
            ProcessId = PROCESS_METADATA.processId,
            Timestamp = tostring(os.time())
        })
    end
)
```

#### ProcessLogic Handler
```lua
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local response = handleMessage(msg)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data,
            ProcessId = response.ProcessId,
            Timestamp = tostring(response.Timestamp)
        })
    end
)
```

#### HealthCheck Handler
```lua
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                processId = PROCESS_METADATA.processId,
                processType = PROCESS_METADATA.processType,
                status = "healthy",
                timestamp = os.time(),
                operations = PROCESS_METADATA.capabilities
            }
        })
    end
)
```

### 3. Message Schema Definition

```lua
messageSchemas = {
    ProcessLogic = {
        required = {"Action", "Data", "Timestamp"},
        Data = {
            required = {"gameState", "operation", "parameters"},
            gameState = {
                required = {"playerId", "timestamp", "version"}
            }
        }
    },
    HealthCheck = {
        required = {"Action"}
    },
    Info = {
        required = {"Action"}
    }
}
```

### 4. Supported Operations Definition

```lua
supportedOperations = {
    operationName = {
        description = "Operation description",
        parameters = {
            param1 = {
                type = "table",
                required = true,
                description = "Parameter description"
            }
        },
        returns = {
            gameState = "Updated GameState",
            result = "Operation result"
        }
    }
}
```

## Benefits of ADP Compliance

### 1. Autonomous Tool Integration
- AI tools can discover process capabilities automatically
- Standardized query interface for process discovery
- Enables agent-to-process communication

### 2. Self-Documenting Architecture
- Processes document themselves
- Reduces manual documentation overhead
- Always up-to-date documentation

### 3. Development Efficiency
- Consistent process interfaces
- Automated validation and testing
- Better developer experience

### 4. Future-Proof Design
- Ensures compatibility with evolving AO ecosystem
- Standardized protocol adoption
- Interoperability with other ADP-compliant systems

## Migration Guidelines

### Existing Processes
1. Add PROCESS_METADATA structure
2. Implement Info handler
3. Update existing handlers to use metadata
4. Add message schemas and operation definitions
5. Test ADP compliance

### New Processes
1. Use Permamind `generateLuaProcess` tool for automatic ADP compliance
2. Follow ADP template structure
3. Include all required handlers
4. Define complete metadata

## Validation

### ADP Compliance Check
```lua
-- Test ADP compliance
local function testADPCompliance(processId)
    local infoResponse = queryProcess(processId, {Action = "Info"})
    assert(infoResponse.Data.process.adpVersion == "1.0")
    assert(infoResponse.Data.handlers)
    assert(infoResponse.Data.messageSchemas)
    assert(infoResponse.Data.documentation.adpCompliance == "v1.0")
end
```

### Required Tests
1. Info handler responds correctly
2. Message schemas are complete
3. All operations documented
4. Metadata structure valid

## Examples

### Reference Implementation
- `processes/battle-engine-adp.lua` - Complete ADP v1.0 implementation
- `testing/unit/battle-engine-adp.test.lua` - ADP compliance testing

### Migration Example
See `comparison-battle-engines.md` for comparison between non-ADP and ADP-compliant implementations.

## Conclusion

ADP v1.0 compliance is mandatory for all new processes in the PokéRogue AO project. It provides standardized self-documentation, enables autonomous tool integration, and ensures future compatibility with the evolving AO ecosystem.

All processes should be migrated to ADP v1.0 compliance to maintain consistency and enable advanced tooling capabilities.