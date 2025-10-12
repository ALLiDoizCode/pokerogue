# Action Naming Patterns for 11 Direct Mapping Processes
Generated: Fri Oct 10 10:13:10 EDT 2025

## egg-hatching-engine
Process: processes/egg-hatching-engine.lua

### Handlers:
- "info"
- "configure-process-ids"
- "progress-steps"
- "hatch-egg"
- "mass-hatch"
- "list-eggs"
- "get-egg-details"
- "sort-eggs"
- "apply-incubator"
- "remove-incubator"
- "get-hatch-timing"
- "health-check"

### Action Patterns:
```lua
            Action = "Info-Response",
                Action = "Error",
                Action = "Error",
                Action = "Error",
                Action = "Error",
            Action = "HealthCheck-Response",
```

## friendship-engine
Process: processes/friendship-engine.lua

### Handlers:
- "calculate-friendship"
- "check-friendship-evolution"
- "calculate-friendship-move-effects"
- "get-friendship-status"
- "info"

### Action Patterns:
```lua
            Action = "SaveState",
```

## genetic-inheritance-engine
Process: processes/genetic-inheritance-engine.lua

### Handlers:
- "info"
- "fetch-pokemon-data"
- "breeding-compatibility-response"
- "process-logic"
- "health-check"

### Action Patterns:
```lua
            Action = "InfoResponse",
            Action = "HealthCheckResponse",
```

## field-condition-engine
Process: processes/field-condition-engine.lua

### Handlers:
- "apply-field-condition"
- "apply-future-attack"
- "check-field-condition-effects"
- "process-field-condition-interactions"
- "advance-turn"
- "info"
- "ping"

### Action Patterns:
```lua
            Action = "Pong",
```

## battle-engine-turn-manager
Process: processes/battle-engine-turn-manager.lua

### Handlers:
- "calculate-turn-order"
- "validate-action"
- "execute-turn"
- "process-switch"
- "info"
- "ping"

### Action Patterns:
```lua
            Action = "Pong",
```

## positional-battle-mechanics-engine
Process: processes/positional-battle-mechanics-engine.lua

### Handlers:
- "apply-positional-effect"
- "check-positional-targeting"
- "process-positional-turn-effects"
- "update-battlefield-positions", 
- "health-check"
- "cleanup-battle-data"
- "info"

### Action Patterns:
```lua
                Action = "Error", 
            Action = "SaveState",
```

## stellar-tera-engine
Process: processes/stellar-tera-engine.lua

### Handlers:
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 

### Action Patterns:
```lua
            Action = "Pong",
```

## terastalization-battle-integration-engine
Process: processes/terastalization-battle-integration-engine.lua

### Handlers:
- 
- 
- 
- 
- 
- 
- 
- 
- 

### Action Patterns:
```lua
            Action = "Pong",
```

## fusion-content-engine
Process: processes/fusion-content-engine.lua

### Handlers:
- "generateFusionName"
- "generateFusionMovePool"
- "validateFusionContent"
- "resolveFusionContentConflicts"
- "calculateContentPrecision"
- "info"

### Action Patterns:
```lua
            Action = "SaveState",
            Action = "SaveState",
            Action = "SaveState",
```

## fusion-form-engine
Process: processes/fusion-form-engine.lua

### Handlers:
- "generate-fusion-appearance"
- "determine-fusion-form"
- "validate-fusion-appearance"
- "resolve-fusion-visuals"
- "calculate-appearance-precision"
- "info"
- "ping"

### Action Patterns:
```lua
            Action = "SaveState",
            Action = "Pong",
```

## wild-encounter-engine
Process: processes/wild-encounter-engine.lua

### Handlers:
- "info"
- "health-check"
- "process-wild-encounter"

### Action Patterns:
```lua
            Action = "SaveState",
            Action = "SaveState",
```

