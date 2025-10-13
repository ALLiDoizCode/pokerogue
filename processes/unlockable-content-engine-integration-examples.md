# Unlockable Content Engine - Integration Examples

## Process Coordination Patterns

### 1. Unlock Evaluation on Game Victory Workflow

This workflow demonstrates how the coordinator process triggers unlock evaluation when a player completes Classic mode.

```lua
-- Step 1: Game completion detected (from game-over-phase)
ClientRequest -> coordinator-process {
    Action = "GameOver",
    PlayerId = "player_456",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({
        hasFusion = true,
        hasUnevolved = false,
        partySize = 6
    })
}

-- Step 2: Coordinator requests unlock evaluation
coordinator-process -> unlockable-content-engine {
    Action = "EvaluateUnlocks",
    PlayerId = "player_456",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({
        hasFusion = true,
        hasUnevolved = false,
        partySize = 6
    })
}

-- Step 3: Unlock engine evaluates conditions
unlockable-content-engine -> coordinator-process {
    Action = "UnlockEvaluationResult",
    PlayerId = "player_456",
    Data = json.encode({
        newUnlocks = {
            { unlockableId = 0, name = "Endless Mode" },
            { unlockableId = 1, name = "Mini Black Hole" },
            { unlockableId = 2, name = "Spliced Endless Mode" }
        },
        totalUnlocked = 3,
        allUnlocked = false
    })
}

-- Step 4: Coordinator stores unlock state (if player-progression-engine integration needed)
coordinator-process -> player-progression-engine {
    Action = "UpdatePlayerUnlocks",
    PlayerId = "player_456",
    UnlockData = json.encode({
        unlocks = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = false
        }
    })
}

-- Step 5: State persistence confirmation
player-progression-engine -> coordinator-process {
    Action = "UnlocksUpdated",
    Success = "true"
}

-- Step 6: Coordinator triggers notifications
coordinator-process -> notification-engine {
    Action = "ShowUnlockNotifications",
    PlayerId = "player_456",
    NewUnlocks = json.encode([
        { unlockableId = 0, name = "Endless Mode" },
        { unlockableId = 1, name = "Mini Black Hole" },
        { unlockableId = 2, name = "Spliced Endless Mode" }
    ])
}

-- Step 7: Return to client with results
coordinator-process -> Client {
    Action = "GameOverComplete",
    Data = json.encode({
        victory = true,
        newUnlocks = 3,
        unlockNotifications = [...]
    })
}
```

### 2. Content Availability Check Workflow

This workflow demonstrates how to check if a player has unlocked specific content.

```lua
-- Step 1: Client checks if content is available
ClientRequest -> coordinator-process {
    Action = "CheckContentAvailability",
    PlayerId = "player_456",
    ContentId = "endless_mode"
}

-- Step 2: Coordinator queries unlock status
coordinator-process -> unlockable-content-engine {
    Action = "IsUnlocked",
    PlayerId = "player_456",
    UnlockableId = "0"  -- ENDLESS_MODE
}

-- Step 3: Unlock status returned
unlockable-content-engine -> coordinator-process {
    Action = "UnlockStatus",
    PlayerId = "player_456",
    UnlockableId = "0",
    IsUnlocked = "true",
    UnlockableName = "Endless Mode"
}

-- Step 4: Return availability to client
coordinator-process -> Client {
    Action = "ContentAvailable",
    ContentId = "endless_mode",
    IsAvailable = "true",
    UnlockTimestamp = "..."
}
```

### 3. Direct Unlock Grant (Admin/Override)

This workflow demonstrates how to grant an unlock directly, bypassing conditions.

```lua
-- Step 1: Admin request to grant unlock
AdminRequest -> coordinator-process {
    Action = "GrantPlayerUnlock",
    PlayerId = "player_789",
    UnlockableId = "3",  -- EVIOLITE
    ForceUnlock = "true"
}

-- Step 2: Coordinator forwards to unlock engine
coordinator-process -> unlockable-content-engine {
    Action = "GrantUnlock",
    PlayerId = "player_789",
    UnlockableId = "3",
    ForceUnlock = "true"
}

-- Step 3: Grant confirmation
unlockable-content-engine -> coordinator-process {
    Action = "UnlockGranted",
    PlayerId = "player_789",
    UnlockableId = "3",
    Success = "true",
    UnlockableName = "Eviolite",
    AlreadyUnlocked = "false",
    Forced = "true"
}

-- Step 4: Return to admin
coordinator-process -> AdminClient {
    Action = "UnlockGranted",
    Success = "true",
    Message = "Eviolite granted to player_789"
}
```

### 4. Player Profile Unlock Summary

This workflow demonstrates retrieving complete unlock data for a player profile.

```lua
-- Step 1: Client requests player profile
ClientRequest -> coordinator-process {
    Action = "GetPlayerProfile",
    PlayerId = "player_123"
}

-- Step 2: Coordinator queries unlock data
coordinator-process -> unlockable-content-engine {
    Action = "GetPlayerUnlocks",
    PlayerId = "player_123"
}

-- Step 3: Unlock data returned
unlockable-content-engine -> coordinator-process {
    Action = "PlayerUnlockData",
    PlayerId = "player_123",
    Data = json.encode({
        unlocks = {
            [0] = true,   -- ENDLESS_MODE
            [1] = true,   -- MINI_BLACK_HOLE
            [2] = false,  -- SPLICED_ENDLESS_MODE
            [3] = false   -- EVIOLITE
        },
        unlockedCount = 2,
        totalUnlockables = 4,
        completionPercentage = 50,
        timestamps = {
            [0] = 1234567890,
            [1] = 1234567890
        }
    })
}

-- Step 4: Coordinator assembles profile (may query other processes)
-- ... additional queries for stats, achievements, etc.

-- Step 5: Return complete profile
coordinator-process -> Client {
    Action = "PlayerProfile",
    Data = json.encode({
        playerId = "player_123",
        unlocks = {...},
        stats = {...},
        achievements = {...}
    })
}
```

### 5. Unlock Metadata Discovery

This workflow demonstrates how to discover available unlockables and their requirements.

```lua
-- Step 1: Client requests unlock information
ClientRequest -> coordinator-process {
    Action = "GetUnlockableInfo"
}

-- Step 2: Coordinator queries metadata
coordinator-process -> unlockable-content-engine {
    Action = "GetUnlockMetadata"
}

-- Step 3: Metadata returned
unlockable-content-engine -> coordinator-process {
    Action = "UnlockMetadata",
    Data = json.encode({
        unlockables = [
            {
                id = 0,
                name = "Endless Mode",
                description = "Unlocked after completing Classic mode",
                condition = "classic_victory",
                requiresFusion = false,
                requiresUnevolved = false
            },
            {
                id = 1,
                name = "Mini Black Hole",
                description = "Unlocked after completing Classic mode",
                condition = "classic_victory",
                requiresFusion = false,
                requiresUnevolved = false
            },
            {
                id = 2,
                name = "Spliced Endless Mode",
                description = "Unlocked after Classic victory with fusion Pokemon",
                condition = "classic_victory_with_fusion",
                requiresFusion = true,
                requiresUnevolved = false
            },
            {
                id = 3,
                name = "Eviolite",
                description = "Unlocked after Classic victory with unevolved Pokemon",
                condition = "classic_victory_with_unevolved",
                requiresFusion = false,
                requiresUnevolved = true
            }
        ],
        totalUnlockables = 4
    })
}

-- Step 4: Return to client
coordinator-process -> Client {
    Action = "UnlockablesList",
    Data = json.encode({...})
}
```

## Integration with Player Progression Engine

The unlockable-content-engine can integrate with player-progression-engine for persistent state storage:

### Save Player Unlocks
```lua
-- After unlock evaluation, save state
unlockable-content-engine -> player-progression-engine {
    Action = "SavePlayerProgression",
    PlayerId = "player_456",
    ProgressionType = "unlocks",
    Data = json.encode({
        unlocks = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = false
        },
        timestamps = {
            [0] = 1234567890,
            [1] = 1234567890,
            [2] = 1234567891
        }
    })
}
```

### Load Player Unlocks
```lua
-- On player login, restore unlock state
coordinator-process -> player-progression-engine {
    Action = "LoadPlayerProgression",
    PlayerId = "player_456",
    ProgressionType = "unlocks"
}

-- Progression engine returns saved data
player-progression-engine -> coordinator-process {
    Action = "PlayerProgressionData",
    Data = json.encode({
        unlocks = {...},
        timestamps = {...}
    })
}

-- Coordinator can then initialize unlockable-content-engine state
coordinator-process -> unlockable-content-engine {
    Action = "InitializePlayerUnlocks",
    PlayerId = "player_456",
    UnlockData = json.encode({...})
}
```

## Error Handling Patterns

### Invalid Unlockable ID
```lua
unlockable-content-engine -> coordinator-process {
    Action = "Error",
    Error = "Invalid unlockable ID",
    ProcessId = "unlockable-content-engine-id"
}
```

### Missing Required Parameters
```lua
unlockable-content-engine -> coordinator-process {
    Action = "Error",
    Error = "PlayerId required",
    ProcessId = "unlockable-content-engine-id"
}
```

### Player Not Found (if using persistent storage)
```lua
player-progression-engine -> coordinator-process {
    Action = "Error",
    Error = "Player not found",
    PlayerId = "unknown_player"
}
```

## Performance Considerations

- **Stateless Design**: Unlock state is stored in-memory per process instance. For persistent storage, integrate with player-progression-engine.
- **Idempotent Operations**: Multiple unlock grant calls are safe (already unlocked = no-op).
- **Minimal Data**: Only 4 unlockables, extremely lightweight process (~10-15KB).
- **Fast Evaluation**: Unlock condition evaluation is O(1) for all 4 unlockables.

## Security Notes

- **Authorization**: Coordinator should verify player identity before forwarding unlock operations.
- **Force Unlock**: ForceUnlock flag should only be used by authorized admin processes.
- **State Integrity**: Use player-progression-engine for persistent, secure state storage.
- **Input Validation**: All inputs are validated in the unlockable-content-engine handlers.