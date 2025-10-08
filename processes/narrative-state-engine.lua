-- ===================================================================
-- NARRATIVE STATE ENGINE (AO Process)
-- ===================================================================
-- Purpose: Story state and narrative progress tracking for mystery encounters
-- Architecture: Stateless AO process with embedded data structures
-- ADP Version: 1.0 (AO Documentation Protocol compliant)
-- ===================================================================

-- Mock AO environment for testing
if not ao then
    ao = {
        send = function(msg)
            print("Mock ao.send:", require("json").encode(msg))
        end,
        id = "narrative_state_process_test_id"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    return msg[tagName] == tagValue
                end
            end
        }
    }
end

-- JSON library (allowed in AO)
local json = require("json")

-- ===================================================================
-- CONSTANTS
-- ===================================================================

-- Base spawn weight for mystery encounters
-- Source: src/constants.ts:61 (BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT)
local BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT = 3

-- Maximum spawn weight (MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT from constants.ts:60)
local MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT = 256

-- Weight increment on spawn miss (from constants.ts)
local WEIGHT_INCREMENT_ON_SPAWN_MISS = 1

-- Default max allowed encounters per run by tier
-- Source: src/data/mystery-encounters/mystery-encounter.ts:39-40, 285-289
local DEFAULT_MAX_ALLOWED_ROGUE_ENCOUNTERS = 1  -- ROGUE tier
local DEFAULT_MAX_ALLOWED_ENCOUNTERS = 2         -- COMMON/GREAT/ULTRA tiers

-- ===================================================================
-- NARRATIVE STATE DATA STRUCTURE
-- ===================================================================

-- Global narrative state (persisted across handler calls within process lifecycle)
-- Source: src/data/mystery-encounters/mystery-encounter-save-data.ts:25-38
local narrativeState = {
    encounteredEvents = {},  -- Array of SeenEncounterData
    encounterSpawnChance = BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT,
    queuedEncounters = {}    -- Array of QueuedEncounter
}

-- ===================================================================
-- ENCOUNTER HISTORY TRACKING FUNCTIONS
-- ===================================================================

-- Record completed encounter in history
-- Source: mystery-encounter-save-data.ts:6-18 (SeenEncounterData structure)
local function recordEncounterCompletion(encounterType, tier, waveIndex, selectedOption)
    local encounterData = {
        type = encounterType,
        tier = tier,
        waveIndex = waveIndex,
        selectedOption = selectedOption or -1  -- -1 if no option selected
    }

    table.insert(narrativeState.encounteredEvents, encounterData)

    return {
        success = true,
        encounterCount = #narrativeState.encounteredEvents,
        updatedState = narrativeState
    }
end

-- Get encounter history (optionally filtered by type)
local function getEncounterHistory(filterType)
    if not filterType then
        return narrativeState.encounteredEvents
    end

    local filtered = {}
    for _, event in ipairs(narrativeState.encounteredEvents) do
        if event.type == filterType then
            table.insert(filtered, event)
        end
    end

    return filtered
end

-- ===================================================================
-- FREQUENCY VALIDATION LOGIC
-- ===================================================================

-- Validate encounter frequency against max allowed
-- Source: mystery-encounter.ts:39-40, 285-289 (frequency limits)
local function validateEncounterFrequency(encounterType, maxAllowed)
    local currentCount = 0

    for _, event in ipairs(narrativeState.encounteredEvents) do
        if event.type == encounterType then
            currentCount = currentCount + 1
        end
    end

    local canSpawn = currentCount < maxAllowed

    return {
        success = true,
        currentCount = currentCount,
        maxCount = maxAllowed,
        canSpawn = canSpawn
    }
end

-- ===================================================================
-- SPAWN PROBABILITY MANAGEMENT
-- ===================================================================

-- Update spawn probability with adjustment
-- Source: TypeScript dynamic spawn chance adjustment logic
local function updateSpawnProbability(adjustmentAmount)
    local previousChance = narrativeState.encounterSpawnChance

    -- Apply adjustment
    narrativeState.encounterSpawnChance = narrativeState.encounterSpawnChance + adjustmentAmount

    -- Clamp to valid range (0 to MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT)
    if narrativeState.encounterSpawnChance < 0 then
        narrativeState.encounterSpawnChance = 0
    elseif narrativeState.encounterSpawnChance > MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT then
        narrativeState.encounterSpawnChance = MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT
    end

    return {
        success = true,
        newSpawnChance = narrativeState.encounterSpawnChance,
        previousSpawnChance = previousChance
    }
end

-- ===================================================================
-- QUEUED ENCOUNTER MANAGEMENT
-- ===================================================================

-- Add encounter to queue (FIFO insertion at end)
-- Source: mystery-encounter-save-data.ts:20-23 (QueuedEncounter structure)
local function queueEncounter(encounterType, spawnPercent)
    local queuedEntry = {
        type = encounterType,
        spawnPercent = spawnPercent
    }

    -- Append to end of queue for FIFO ordering
    table.insert(narrativeState.queuedEncounters, queuedEntry)

    return {
        success = true,
        queuedCount = #narrativeState.queuedEncounters,
        updatedQueue = narrativeState.queuedEncounters
    }
end

-- Remove encounter from queue (first matching type)
local function dequeueEncounter(encounterType)
    local found = false
    local dequeuedEntry = nil

    for i, entry in ipairs(narrativeState.queuedEncounters) do
        if entry.type == encounterType then
            dequeuedEntry = table.remove(narrativeState.queuedEncounters, i)
            found = true
            break
        end
    end

    return {
        success = found,
        dequeuedEntry = dequeuedEntry,
        remainingQueued = #narrativeState.queuedEncounters
    }
end

-- Get all queued encounters
local function getQueuedEncounters()
    return narrativeState.queuedEncounters
end

-- ===================================================================
-- PROGRESS VALIDATION LOGIC
-- ===================================================================

-- Validate narrative progress based on validation type
local function validateNarrativeProgress(currentWave, validationType, criteria)
    local result = {
        success = true,
        valid = true,
        progressPercentage = 0
    }

    if validationType == "frequency" then
        -- Frequency validation: Check if encounter types within frequency limits
        local encounterType = criteria.encounterType
        local maxAllowed = criteria.maxAllowed or DEFAULT_MAX_ALLOWED_ENCOUNTERS

        local freqCheck = validateEncounterFrequency(encounterType, maxAllowed)
        result.valid = freqCheck.canSpawn
        result.currentCount = freqCheck.currentCount
        result.maxCount = freqCheck.maxCount
        result.progressPercentage = math.floor((freqCheck.currentCount / freqCheck.maxCount) * 100)

    elseif validationType == "progression" then
        -- Progression validation: Wave-based milestone checking
        local totalEncounters = #narrativeState.encounteredEvents
        local expectedEncountersAtWave = math.floor(currentWave / 10)  -- Roughly 1 per 10 waves

        result.valid = totalEncounters >= expectedEncountersAtWave
        result.totalEncounters = totalEncounters
        result.expectedEncounters = expectedEncountersAtWave
        result.progressPercentage = math.min(100, math.floor((totalEncounters / math.max(1, expectedEncountersAtWave)) * 100))

    elseif validationType == "continuity" then
        -- Continuity validation: State consistency checks
        local hasValidState = narrativeState.encounterSpawnChance >= 0 and
                              narrativeState.encounterSpawnChance <= MYSTERY_ENCOUNTER_SPAWN_MAX_WEIGHT
        local hasValidHistory = #narrativeState.encounteredEvents >= 0

        result.valid = hasValidState and hasValidHistory
        result.spawnChanceValid = hasValidState
        result.historyValid = hasValidHistory
        result.progressPercentage = (hasValidState and hasValidHistory) and 100 or 0

    else
        result.success = false
        result.valid = false
        result.error = "Unknown validation type: " .. tostring(validationType)
    end

    return result
end

-- ===================================================================
-- STATE MANAGEMENT UTILITIES
-- ===================================================================

-- Reset narrative state (full or partial)
local function resetNarrativeState(resetType)
    resetType = resetType or "full"

    if resetType == "full" then
        -- Full reset: Clear everything
        narrativeState.encounteredEvents = {}
        narrativeState.encounterSpawnChance = BASE_MYSTERY_ENCOUNTER_SPAWN_WEIGHT
        narrativeState.queuedEncounters = {}

    elseif resetType == "partial" then
        -- Partial reset: Clear only queue
        narrativeState.queuedEncounters = {}

    else
        return {
            success = false,
            cleared = false,
            error = "Unknown reset type: " .. tostring(resetType)
        }
    end

    return {
        success = true,
        cleared = true,
        resetType = resetType,
        updatedState = narrativeState
    }
end

-- Get complete narrative state summary
local function getNarrativeStateSummary()
    return {
        success = true,
        totalEncounters = #narrativeState.encounteredEvents,
        spawnChance = narrativeState.encounterSpawnChance,
        queuedCount = #narrativeState.queuedEncounters,
        fullState = narrativeState
    }
end

-- ===================================================================
-- AO MESSAGE HANDLERS
-- ===================================================================

-- Handler: RecordEncounterCompletion
Handlers.add("record-encounter-completion",
    Handlers.utils.hasMatchingTag("Action", "RecordEncounterCompletion"),
    function(msg)
        local encounterType = tonumber(msg.EncounterType)
        local tier = tonumber(msg.Tier)
        local waveIndex = tonumber(msg.WaveIndex)
        local selectedOption = tonumber(msg.SelectedOption)

        if not encounterType or not tier or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType, Tier, and WaveIndex required"
            })
            return
        end

        local result = recordEncounterCompletion(encounterType, tier, waveIndex, selectedOption)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            EncounterCount = tostring(result.encounterCount),
            Data = json.encode(result.updatedState)
        })
    end
)

-- Handler: GetEncounterHistory
Handlers.add("get-encounter-history",
    Handlers.utils.hasMatchingTag("Action", "GetEncounterHistory"),
    function(msg)
        local filterType = tonumber(msg.EncounterType)
        local history = getEncounterHistory(filterType)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            HistoryCount = tostring(#history),
            Data = json.encode(history)
        })
    end
)

-- Handler: ValidateEncounterFrequency
Handlers.add("validate-encounter-frequency",
    Handlers.utils.hasMatchingTag("Action", "ValidateEncounterFrequency"),
    function(msg)
        local encounterType = tonumber(msg.EncounterType)
        local maxAllowed = tonumber(msg.MaxAllowed)

        if not encounterType or not maxAllowed then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType and MaxAllowed required"
            })
            return
        end

        local result = validateEncounterFrequency(encounterType, maxAllowed)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            CurrentCount = tostring(result.currentCount),
            MaxCount = tostring(result.maxCount),
            CanSpawn = tostring(result.canSpawn),
            Data = json.encode(result)
        })
    end
)

-- Handler: UpdateSpawnProbability
Handlers.add("update-spawn-probability",
    Handlers.utils.hasMatchingTag("Action", "UpdateSpawnProbability"),
    function(msg)
        local adjustmentAmount = tonumber(msg.AdjustmentAmount)

        if not adjustmentAmount then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "AdjustmentAmount required"
            })
            return
        end

        local result = updateSpawnProbability(adjustmentAmount)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            NewSpawnChance = tostring(result.newSpawnChance),
            PreviousSpawnChance = tostring(result.previousSpawnChance),
            Data = json.encode(result)
        })
    end
)

-- Handler: QueueEncounter
Handlers.add("queue-encounter",
    Handlers.utils.hasMatchingTag("Action", "QueueEncounter"),
    function(msg)
        local encounterType = tonumber(msg.EncounterType)
        local spawnPercent = tonumber(msg.SpawnPercent)

        if not encounterType or not spawnPercent then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType and SpawnPercent required"
            })
            return
        end

        local result = queueEncounter(encounterType, spawnPercent)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            QueuedCount = tostring(result.queuedCount),
            Data = json.encode(result.updatedQueue)
        })
    end
)

-- Handler: GetQueuedEncounters
Handlers.add("get-queued-encounters",
    Handlers.utils.hasMatchingTag("Action", "GetQueuedEncounters"),
    function(msg)
        local queuedEncounters = getQueuedEncounters()

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            QueuedCount = tostring(#queuedEncounters),
            Data = json.encode(queuedEncounters)
        })
    end
)

-- Handler: DequeueEncounter
Handlers.add("dequeue-encounter",
    Handlers.utils.hasMatchingTag("Action", "DequeueEncounter"),
    function(msg)
        local encounterType = tonumber(msg.EncounterType)

        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType required"
            })
            return
        end

        local result = dequeueEncounter(encounterType)

        if not result.success then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Encounter type not found in queue"
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            RemainingQueued = tostring(result.remainingQueued),
            Data = json.encode(result.dequeuedEntry)
        })
    end
)

-- Handler: ValidateNarrativeProgress
Handlers.add("validate-narrative-progress",
    Handlers.utils.hasMatchingTag("Action", "ValidateNarrativeProgress"),
    function(msg)
        local currentWave = tonumber(msg.CurrentWave)
        local validationType = msg.ValidationType

        if not currentWave or not validationType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "CurrentWave and ValidationType required"
            })
            return
        end

        -- Parse criteria from Data field
        local criteria = {}
        if msg.Data and msg.Data ~= "" then
            criteria = json.decode(msg.Data)
        end

        local result = validateNarrativeProgress(currentWave, validationType, criteria)

        if not result.success then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error or "Validation failed"
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Valid = tostring(result.valid),
            ProgressPercentage = tostring(result.progressPercentage),
            Data = json.encode(result)
        })
    end
)

-- Handler: ResetNarrativeState
Handlers.add("reset-narrative-state",
    Handlers.utils.hasMatchingTag("Action", "ResetNarrativeState"),
    function(msg)
        -- CRITICAL: Confirmation safety check to prevent accidental resets
        if msg.Confirmed ~= "true" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Confirmation required: Set Confirmed='true' to reset narrative state"
            })
            return
        end

        local resetType = msg.ResetType or "full"
        local result = resetNarrativeState(resetType)

        if not result.success then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error or "Reset failed"
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            StateCleared = tostring(result.cleared),
            Data = json.encode(result)
        })
    end
)

-- Handler: GetNarrativeStateSummary
Handlers.add("get-narrative-state-summary",
    Handlers.utils.hasMatchingTag("Action", "GetNarrativeStateSummary"),
    function(msg)
        local summary = getNarrativeStateSummary()

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            TotalEncounters = tostring(summary.totalEncounters),
            SpawnChance = tostring(summary.spawnChance),
            QueuedCount = tostring(summary.queuedCount),
            Data = json.encode(summary.fullState)
        })
    end
)

-- ===================================================================
-- ADP v1.0 COMPLIANCE: INFO HANDLER
-- ===================================================================

Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Narrative State Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    processId = ao.id or "narrative-state-engine-adp",
                    description = "Story state and narrative progress tracking for mystery encounters",
                    capabilities = {
                        "RecordEncounterCompletion",
                        "GetEncounterHistory",
                        "ValidateEncounterFrequency",
                        "UpdateSpawnProbability",
                        "QueueEncounter",
                        "GetQueuedEncounters",
                        "DequeueEncounter",
                        "ValidateNarrativeProgress",
                        "ResetNarrativeState",
                        "GetNarrativeStateSummary"
                    },
                    messageSchemas = {
                        RecordEncounterCompletion = {
                            required = {"Action", "EncounterType", "Tier", "WaveIndex"},
                            optional = {"SelectedOption"}
                        },
                        GetEncounterHistory = {
                            required = {"Action"},
                            optional = {"EncounterType"}
                        },
                        ValidateEncounterFrequency = {
                            required = {"Action", "EncounterType", "MaxAllowed"}
                        },
                        UpdateSpawnProbability = {
                            required = {"Action", "AdjustmentAmount"}
                        },
                        QueueEncounter = {
                            required = {"Action", "EncounterType", "SpawnPercent"}
                        },
                        GetQueuedEncounters = {
                            required = {"Action"}
                        },
                        DequeueEncounter = {
                            required = {"Action", "EncounterType"}
                        },
                        ValidateNarrativeProgress = {
                            required = {"Action", "CurrentWave", "ValidationType"},
                            optional = {"Data"}
                        },
                        ResetNarrativeState = {
                            required = {"Action", "Confirmed"},
                            optional = {"ResetType"}
                        },
                        GetNarrativeStateSummary = {
                            required = {"Action"}
                        }
                    }
                },
                handlers = {
                    "record-encounter-completion",
                    "get-encounter-history",
                    "validate-encounter-frequency",
                    "update-spawn-probability",
                    "queue-encounter",
                    "get-queued-encounters",
                    "dequeue-encounter",
                    "validate-narrative-progress",
                    "reset-narrative-state",
                    "get-narrative-state-summary",
                    "info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    source = "Story 19.4: Story State & Narrative Progress Migration"
                }
            })
        })
    end
)

-- Process initialization complete
print("Narrative State Engine v1.0.0 initialized (ADP v1.0 compliant)")
