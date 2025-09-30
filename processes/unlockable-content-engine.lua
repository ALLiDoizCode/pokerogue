-- ========================================
-- Unlockable Content Engine
-- AO Process for managing unlockable content progression
-- ========================================
-- Version: 1.0.0
-- ADP Compliance: v1.0
-- Description: Manages unlock conditions, state tracking, and content availability
-- ========================================

local json = require("json")

-- ========================================
-- UNLOCKABLES ENUM
-- ========================================
-- Matching TypeScript enum values from typescript-reference/src/enums/unlockables.ts
local Unlockables = {
    ENDLESS_MODE = 0,            -- Unlocked after Classic mode victory
    MINI_BLACK_HOLE = 1,         -- Unlocked after Classic mode victory
    SPLICED_ENDLESS_MODE = 2,    -- Unlocked after Classic victory with fusion Pokemon
    EVIOLITE = 3                 -- Unlocked after Classic victory with unevolved Pokemon
}

-- ========================================
-- UNLOCK METADATA
-- ========================================
-- Unlock names, descriptions, and trigger conditions
local UnlockMetadata = {
    [Unlockables.ENDLESS_MODE] = {
        id = Unlockables.ENDLESS_MODE,
        name = "Endless Mode",
        description = "Unlocked after completing Classic mode",
        condition = "classic_victory",
        requiresFusion = false,
        requiresUnevolved = false
    },
    [Unlockables.MINI_BLACK_HOLE] = {
        id = Unlockables.MINI_BLACK_HOLE,
        name = "Mini Black Hole",
        description = "Unlocked after completing Classic mode",
        condition = "classic_victory",
        requiresFusion = false,
        requiresUnevolved = false
    },
    [Unlockables.SPLICED_ENDLESS_MODE] = {
        id = Unlockables.SPLICED_ENDLESS_MODE,
        name = "Spliced Endless Mode",
        description = "Unlocked after Classic victory with fusion Pokemon",
        condition = "classic_victory_with_fusion",
        requiresFusion = true,
        requiresUnevolved = false
    },
    [Unlockables.EVIOLITE] = {
        id = Unlockables.EVIOLITE,
        name = "Eviolite",
        description = "Unlocked after Classic victory with unevolved Pokemon",
        condition = "classic_victory_with_unevolved",
        requiresFusion = false,
        requiresUnevolved = true
    }
}

-- ========================================
-- PLAYER UNLOCK STATE STORAGE
-- ========================================
-- In-memory storage for player unlock progression
-- Structure: playerUnlockData[playerId] = { unlocks = {[unlockableId] = boolean}, unlockPity = {}, timestamps = {} }
local playerUnlockData = {}

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Get unlock metadata for a specific unlockable or all unlockables
local function getUnlockMetadata(unlockableId)
    if unlockableId then
        local id = tonumber(unlockableId)
        return UnlockMetadata[id]
    else
        -- Return all metadata
        local allMetadata = {}
        for id, metadata in pairs(UnlockMetadata) do
            table.insert(allMetadata, metadata)
        end
        return allMetadata
    end
end

-- Get unlock name (matching TypeScript getUnlockableName)
local function getUnlockableName(unlockableId)
    local id = tonumber(unlockableId)
    local metadata = UnlockMetadata[id]
    return metadata and metadata.name or "Unknown"
end

-- Validate unlockable ID
local function isValidUnlockableId(unlockableId)
    local id = tonumber(unlockableId)
    return id ~= nil and id >= 0 and id <= 3
end

-- Initialize player unlock state if not exists
local function initializePlayerUnlocks(playerId)
    if not playerUnlockData[playerId] then
        playerUnlockData[playerId] = {
            unlocks = {
                [Unlockables.ENDLESS_MODE] = false,
                [Unlockables.MINI_BLACK_HOLE] = false,
                [Unlockables.SPLICED_ENDLESS_MODE] = false,
                [Unlockables.EVIOLITE] = false
            },
            unlockPity = {0, 0, 0, 0},  -- Pity system for unlock retries (currently unused)
            timestamps = {}
        }
    end
end

-- Get player unlock state
local function getPlayerUnlocks(playerId)
    initializePlayerUnlocks(playerId)
    return playerUnlockData[playerId]
end

-- Set specific unlock for player
local function setPlayerUnlock(playerId, unlockableId, timestamp)
    initializePlayerUnlocks(playerId)
    local id = tonumber(unlockableId)
    playerUnlockData[playerId].unlocks[id] = true
    playerUnlockData[playerId].timestamps[id] = timestamp or 0
end

-- Check if player has unlocked specific content
local function isUnlocked(playerId, unlockableId)
    local playerData = getPlayerUnlocks(playerId)
    local id = tonumber(unlockableId)
    return playerData.unlocks[id] == true
end

-- Calculate completion percentage
local function getCompletionPercentage(playerId)
    local playerData = getPlayerUnlocks(playerId)
    local unlockedCount = 0
    for _, unlocked in pairs(playerData.unlocks) do
        if unlocked then
            unlockedCount = unlockedCount + 1
        end
    end
    return math.floor((unlockedCount / 4) * 100)
end

-- Count unlocked content
local function countUnlocked(playerId)
    local playerData = getPlayerUnlocks(playerId)
    local count = 0
    for _, unlocked in pairs(playerData.unlocks) do
        if unlocked then
            count = count + 1
        end
    end
    return count
end

-- ========================================
-- UNLOCK CONDITION EVALUATION
-- ========================================
-- Port of handleUnlocks() from typescript-reference/src/phases/game-over-phase.ts#L287-308

local function evaluateUnlockConditions(playerId, gameMode, isVictory, partyData, timestamp)
    -- Only Classic mode victories trigger unlocks
    if gameMode ~= "classic" or isVictory ~= true then
        return {}
    end

    local newUnlocks = {}

    -- ENDLESS_MODE - Always unlocked on Classic victory
    if not isUnlocked(playerId, Unlockables.ENDLESS_MODE) then
        setPlayerUnlock(playerId, Unlockables.ENDLESS_MODE, timestamp)
        table.insert(newUnlocks, {
            unlockableId = Unlockables.ENDLESS_MODE,
            name = getUnlockableName(Unlockables.ENDLESS_MODE)
        })
    end

    -- MINI_BLACK_HOLE - Always unlocked on Classic victory
    if not isUnlocked(playerId, Unlockables.MINI_BLACK_HOLE) then
        setPlayerUnlock(playerId, Unlockables.MINI_BLACK_HOLE, timestamp)
        table.insert(newUnlocks, {
            unlockableId = Unlockables.MINI_BLACK_HOLE,
            name = getUnlockableName(Unlockables.MINI_BLACK_HOLE)
        })
    end

    -- SPLICED_ENDLESS_MODE - Requires fusion Pokemon in party
    if partyData.hasFusion and not isUnlocked(playerId, Unlockables.SPLICED_ENDLESS_MODE) then
        setPlayerUnlock(playerId, Unlockables.SPLICED_ENDLESS_MODE, timestamp)
        table.insert(newUnlocks, {
            unlockableId = Unlockables.SPLICED_ENDLESS_MODE,
            name = getUnlockableName(Unlockables.SPLICED_ENDLESS_MODE)
        })
    end

    -- EVIOLITE - Requires unevolved Pokemon in party
    if partyData.hasUnevolved and not isUnlocked(playerId, Unlockables.EVIOLITE) then
        setPlayerUnlock(playerId, Unlockables.EVIOLITE, timestamp)
        table.insert(newUnlocks, {
            unlockableId = Unlockables.EVIOLITE,
            name = getUnlockableName(Unlockables.EVIOLITE)
        })
    end

    return newUnlocks
end

-- ========================================
-- AO MESSAGE HANDLERS
-- ========================================

-- Handler: Info (ADP v1.0 required handler)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                name = "Unlockable Content Engine",
                version = "1.0.0",
                adpVersion = "1.0",
                description = "Manages unlockable content conditions, state tracking, and availability",
                capabilities = {
                    "IsUnlocked",
                    "EvaluateUnlocks",
                    "GrantUnlock",
                    "GetPlayerUnlocks",
                    "GetUnlockMetadata"
                },
                handlers = {
                    {
                        action = "IsUnlocked",
                        description = "Check if specific unlockable is unlocked for player",
                        required = {"PlayerId", "UnlockableId"}
                    },
                    {
                        action = "EvaluateUnlocks",
                        description = "Evaluate unlock conditions after game completion",
                        required = {"PlayerId", "GameMode", "IsVictory", "PartyData"}
                    },
                    {
                        action = "GrantUnlock",
                        description = "Grant specific unlockable to player",
                        required = {"PlayerId", "UnlockableId"}
                    },
                    {
                        action = "GetPlayerUnlocks",
                        description = "Get all unlock states for player",
                        required = {"PlayerId"}
                    },
                    {
                        action = "GetUnlockMetadata",
                        description = "Get unlock metadata and descriptions",
                        required = {}
                    }
                },
                unlockables = {
                    {id = 0, name = "Endless Mode"},
                    {id = 1, name = "Mini Black Hole"},
                    {id = 2, name = "Spliced Endless Mode"},
                    {id = 3, name = "Eviolite"}
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: IsUnlocked
Handlers.add("is-unlocked",
    Handlers.utils.hasMatchingTag("Action", "IsUnlocked"),
    function(msg)
        local playerId = msg.PlayerId
        local unlockableId = msg.UnlockableId

        -- Validate required parameters
        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                ProcessId = ao.id
            })
            return
        end

        if not unlockableId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "UnlockableId required",
                ProcessId = ao.id
            })
            return
        end

        -- Validate unlockable ID
        if not isValidUnlockableId(unlockableId) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid unlockable ID",
                ProcessId = ao.id
            })
            return
        end

        -- Check unlock status
        local unlocked = isUnlocked(playerId, unlockableId)

        ao.send({
            Target = msg.From,
            Action = "UnlockStatus",
            PlayerId = playerId,
            UnlockableId = unlockableId,
            IsUnlocked = tostring(unlocked),
            UnlockableName = getUnlockableName(unlockableId),
            Timestamp = tostring(msg.Timestamp or 0),
            ProcessId = ao.id
        })
    end
)

-- Handler: EvaluateUnlocks
Handlers.add("evaluate-unlocks",
    Handlers.utils.hasMatchingTag("Action", "EvaluateUnlocks"),
    function(msg)
        local playerId = msg.PlayerId
        local gameMode = msg.GameMode
        local isVictory = msg.IsVictory == "true"
        local partyDataStr = msg.PartyData

        -- Validate required parameters
        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                ProcessId = ao.id
            })
            return
        end

        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "GameMode required",
                ProcessId = ao.id
            })
            return
        end

        if not msg.IsVictory then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "IsVictory required",
                ProcessId = ao.id
            })
            return
        end

        -- Parse party data
        local partyData = {}
        if partyDataStr and partyDataStr ~= "" then
            partyData = json.decode(partyDataStr)
        end

        -- Validate party data structure
        if not partyData.hasFusion and not partyData.hasUnevolved then
            -- Default to false if not provided
            partyData.hasFusion = false
            partyData.hasUnevolved = false
        end

        -- Evaluate unlock conditions
        local timestamp = tonumber(msg.Timestamp or 0)
        local newUnlocks = evaluateUnlockConditions(playerId, gameMode, isVictory, partyData, timestamp)

        -- Count total unlocked
        local totalUnlocked = countUnlocked(playerId)
        local allUnlocked = totalUnlocked == 4

        ao.send({
            Target = msg.From,
            Action = "UnlockEvaluationResult",
            PlayerId = playerId,
            Data = json.encode({
                newUnlocks = newUnlocks,
                totalUnlocked = totalUnlocked,
                allUnlocked = allUnlocked
            }),
            Timestamp = tostring(msg.Timestamp or 0),
            ProcessId = ao.id
        })
    end
)

-- Handler: GrantUnlock
Handlers.add("grant-unlock",
    Handlers.utils.hasMatchingTag("Action", "GrantUnlock"),
    function(msg)
        local playerId = msg.PlayerId
        local unlockableId = msg.UnlockableId
        local forceUnlock = msg.ForceUnlock == "true"

        -- Validate required parameters
        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                ProcessId = ao.id
            })
            return
        end

        if not unlockableId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "UnlockableId required",
                ProcessId = ao.id
            })
            return
        end

        -- Validate unlockable ID
        if not isValidUnlockableId(unlockableId) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid unlockable ID",
                ProcessId = ao.id
            })
            return
        end

        -- Check if already unlocked
        local alreadyUnlocked = isUnlocked(playerId, unlockableId)

        -- Grant unlock (idempotent operation)
        if not alreadyUnlocked then
            local timestamp = tonumber(msg.Timestamp or 0)
            setPlayerUnlock(playerId, unlockableId, timestamp)
        end

        ao.send({
            Target = msg.From,
            Action = "UnlockGranted",
            PlayerId = playerId,
            UnlockableId = unlockableId,
            Success = "true",
            UnlockableName = getUnlockableName(unlockableId),
            AlreadyUnlocked = tostring(alreadyUnlocked),
            Forced = tostring(forceUnlock),
            Timestamp = tostring(msg.Timestamp or 0),
            ProcessId = ao.id
        })
    end
)

-- Handler: GetPlayerUnlocks
Handlers.add("get-player-unlocks",
    Handlers.utils.hasMatchingTag("Action", "GetPlayerUnlocks"),
    function(msg)
        local playerId = msg.PlayerId

        -- Validate required parameters
        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                ProcessId = ao.id
            })
            return
        end

        -- Get player unlock data
        local playerData = getPlayerUnlocks(playerId)
        local unlockedCount = countUnlocked(playerId)
        local completionPercentage = getCompletionPercentage(playerId)

        ao.send({
            Target = msg.From,
            Action = "PlayerUnlockData",
            PlayerId = playerId,
            Data = json.encode({
                unlocks = playerData.unlocks,
                unlockedCount = unlockedCount,
                totalUnlockables = 4,
                completionPercentage = completionPercentage,
                timestamps = playerData.timestamps
            }),
            Timestamp = tostring(msg.Timestamp or 0),
            ProcessId = ao.id
        })
    end
)

-- Handler: GetUnlockMetadata
Handlers.add("get-unlock-metadata",
    Handlers.utils.hasMatchingTag("Action", "GetUnlockMetadata"),
    function(msg)
        local unlockableId = msg.UnlockableId

        -- Get metadata for specific unlockable or all
        local metadata = getUnlockMetadata(unlockableId)

        if unlockableId and not metadata then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid unlockable ID",
                ProcessId = ao.id
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "UnlockMetadata",
            Data = json.encode({
                unlockables = type(metadata) == "table" and (#metadata > 0 and metadata or {metadata}),
                totalUnlockables = 4
            }),
            Timestamp = tostring(msg.Timestamp or 0),
            ProcessId = ao.id
        })
    end
)

-- ========================================
-- PROCESS INITIALIZATION
-- ========================================
print("Unlockable Content Engine initialized (v1.0.0, ADP v1.0)")
print("Handlers registered: Info, IsUnlocked, EvaluateUnlocks, GrantUnlock, GetPlayerUnlocks, GetUnlockMetadata")