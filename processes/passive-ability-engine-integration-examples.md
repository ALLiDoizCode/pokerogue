# Passive Ability Engine - Process Integration Examples

## Overview
This document provides examples of how `passive-ability-engine.lua` integrates with other AO processes in the 26-process stateless architecture.

## 1. Ability Effect Resolution (with abilities-nature-manager)

### Workflow
```
Client/Battle → passive-ability-engine → abilities-nature-manager → Response
```

### Step 1: Check if Passive Can Apply
```lua
-- Client sends to passive-ability-engine
{
    Action = "CanApplyPassive",
    PokemonId = "pokemon_123",
    PlayerId = "player_456",
    SpeciesId = "CHARIZARD",
    From = "client_address"
}

-- Response from passive-ability-engine
{
    Action = "PassiveApplicationResult",
    CanApply = "true",
    PokemonId = "pokemon_123",
    Success = "true"
}
```

### Step 2: Calculate Passive Effect
```lua
-- Client sends to passive-ability-engine
{
    Action = "CalculatePassiveEffect",
    PokemonId = "pokemon_123",
    PlayerId = "player_456",
    SpeciesId = "CHARIZARD",
    AbilityId = "BEAST_BOOST",
    Data = json.encode({
        event = "defeated_opponent",
        battleContext = {battleId = "battle_789"}
    }),
    From = "client_address"
}

-- Response from passive-ability-engine
{
    Action = "PassiveEffectResult",
    PokemonId = "pokemon_123",
    AbilityId = "BEAST_BOOST",
    TriggerEvent = "defeated_opponent",
    Data = json.encode({
        coordinationRequired = {
            targetProcess = "abilities-nature-manager",
            action = "TriggerAbility",
            messageData = {
                PokemonId = "pokemon_123",
                AbilityId = "BEAST_BOOST",
                TriggerEvent = "defeated_opponent",
                BattleContext = {battleId = "battle_789"}
            }
        }
    }),
    Success = "true"
}
```

### Step 3: Trigger Ability Effect (client forwards to abilities-nature-manager)
```lua
-- Client extracts coordinationRequired and sends to abilities-nature-manager
{
    Action = "TriggerAbility",
    PokemonId = "pokemon_123",
    AbilityId = "BEAST_BOOST",
    TriggerEvent = "defeated_opponent",
    BattleContext = json.encode({battleId = "battle_789"}),
    From = "client_address"
}

-- Response from abilities-nature-manager
{
    Action = "AbilityTriggered",
    Data = json.encode({
        success = true,
        pokemonId = 123,
        abilityId = "BEAST_BOOST",
        abilityName = "Beast Boost",
        effects = [
            {type = "STAT_CHANGE", data = {attack = 1}}
        ],
        triggeredAt = 1234567890
    }),
    Success = "true"
}
```

## 2. Passive Unlock via Coordinator (Future Implementation)

### Workflow
```
Client → coordinator-process → [player-progression-engine → passive-ability-engine] → Response
```

### Coordinator Workflow Message
```lua
-- Client sends to coordinator-process
{
    Action = "CoordinateWorkflow",
    WorkflowType = "UnlockPassive",
    Steps = json.encode({
        {
            stepNumber = 1,
            process = "player-progression-engine",
            action = "CheckResource",
            data = {
                playerId = "player_456",
                resourceType = "starter_candy",
                amount = 50
            }
        },
        {
            stepNumber = 2,
            process = "passive-ability-engine",
            action = "UnlockPassive",
            data = {
                playerId = "player_456",
                speciesId = "BULBASAUR",
                cost = 50
            }
        },
        {
            stepNumber = 3,
            process = "player-progression-engine",
            action = "DeductResource",
            data = {
                playerId = "player_456",
                resourceType = "starter_candy",
                amount = 50
            }
        }
    }),
    Data = json.encode({
        playerId = "player_456",
        speciesId = "BULBASAUR"
    }),
    From = "client_address"
}

-- Coordinator orchestrates all steps and returns final result
{
    Action = "WorkflowComplete",
    WorkflowId = "workflow_123",
    Status = "completed",
    Data = json.encode({
        success = true,
        speciesId = "BULBASAUR",
        passiveUnlocked = true,
        remainingCandy = 70
    })
}
```

## 3. Direct Passive Unlock (Current Implementation)

### Simple Unlock Workflow
```lua
-- Client sends directly to passive-ability-engine
{
    Action = "UnlockPassive",
    PlayerId = "player_456",
    SpeciesId = "BULBASAUR",
    Cost = "50",
    From = "client_address"
}

-- Response from passive-ability-engine
{
    Action = "PassiveUnlocked",
    SpeciesId = "BULBASAUR",
    Success = "true",
    NewTier = "0",
    CostApplied = "50"
}
```

Note: Resource validation is currently handled within passive-ability-engine itself. Future integration with player-progression-engine would provide centralized resource management.

## 4. Battle Integration (Future Implementation)

### Workflow
```
battle-engine → passive-ability-engine → abilities-nature-manager → battle-engine
```

### Battle Passive Trigger
```lua
-- battle-engine detects trigger event and queries passive-ability-engine
{
    Action = "CanApplyPassive",
    PokemonId = "pokemon_123",
    PlayerId = "player_456",
    SpeciesId = "CHARIZARD",
    Data = json.encode({
        battleContext = {
            battleId = "battle_789",
            activeAbilities = ["BLAZE"]
        }
    }),
    From = "battle-engine"
}

-- passive-ability-engine validates and responds
{
    Action = "PassiveApplicationResult",
    CanApply = "true",
    Success = "true"
}

-- battle-engine calculates effect
{
    Action = "CalculatePassiveEffect",
    PokemonId = "pokemon_123",
    PlayerId = "player_456",
    SpeciesId = "CHARIZARD",
    Data = json.encode({
        event = "on_switch_in",
        battleContext = {battleId = "battle_789"}
    }),
    From = "battle-engine"
}

-- battle-engine receives coordination instructions and forwards to abilities-nature-manager
-- ... (see Example 1, Step 3)
```

## 5. Ability Stacking Check

### Workflow
```lua
-- battle-engine checks if passive and active abilities can coexist
{
    Action = "CheckAbilityStacking",
    PassiveAbilityId = "BEAST_BOOST",
    ActiveAbilityId = "BLAZE",
    Data = json.encode({
        battleContext = {battleId = "battle_789"}
    }),
    From = "battle-engine"
}

-- Response from passive-ability-engine
{
    Action = "AbilityStackingResult",
    PassiveAbilityId = "BEAST_BOOST",
    ActiveAbilityId = "BLAZE",
    CanStack = "true",
    BlockedReason = "",
    Success = "true"
}
```

## Integration Status

### ✅ Implemented
- Direct passive unlock/upgrade operations
- Passive state management (enable/disable)
- Passive trigger validation (CanApplyPassive)
- Effect calculation coordination pattern
- Ability stacking validation
- Priority coordination for battle queues

### ⏸️ Pending (Requires Other Process Implementation)
- Coordinator-based unlock workflow
- Battle-engine trigger integration
- Player-progression-engine resource management
- Cross-process integration tests
- Parity tests with TypeScript reference

## Design Notes

1. **Stateless Design**: passive-ability-engine maintains no persistent state. All passive unlock/upgrade data is passed in messages and returned to callers for storage.

2. **Coordination Pattern**: Rather than directly calling other processes, passive-ability-engine returns `coordinationRequired` objects that instruct callers on the next message to send.

3. **Self-Contained Resource Validation**: Currently handles cost validation internally. Future versions may delegate to player-progression-engine for centralized resource management.

4. **Battle Integration Ready**: All necessary handlers and validation logic are in place. Battle-engine can immediately start using these handlers once it implements passive ability trigger detection.