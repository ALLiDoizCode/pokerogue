-- Battle State Manager: Comprehensive Pokemon Battle State Tracking Process
-- ADP v1.0 Compliant AO Process for Battle State Management
-- Handles Pokemon state, field conditions, participants, move history, event logging, and serialization

-- AO Compliance: json module is available as global

-- Initialize Battle State Storage
if not BattleStateManager then
    BattleStateManager = {
        activeBattles = {},
        pokemonStates = {},
        fieldConditions = {},
        participants = {},
        moveHistory = {},
        eventLog = {},
        serializedStates = {},
        initialized = true
    }
end

-- Utility Functions for State Management
local function validateBattleId(battleId)
    return battleId and type(battleId) == "string" and #battleId > 0
end

local function createTimestamp(msg)
    -- AO Compliance: Use msg.Timestamp instead of (msg.Timestamp or 0) for deterministic behavior
    return msg and (msg.Timestamp or tostring((msg.Timestamp or 0))) or tostring((msg.Timestamp or 0))
end

local function validatePokemonState(stateData)
    if not stateData then return false, "Pokemon state data is required" end
    
    local pokemon = json.decode(stateData)
    if not pokemon then return false, "Invalid Pokemon state JSON" end
    
    -- Validate required fields
    if not pokemon.id then return false, "Pokemon ID is required" end
    if not pokemon.hp or pokemon.hp < 0 then return false, "Valid HP is required" end
    if not pokemon.maxHp or pokemon.maxHp <= 0 then return false, "Valid max HP is required" end
    
    return true, pokemon
end

local function validateFieldConditions(conditionData)
    if not conditionData then return false, "Field condition data is required" end
    
    local conditions = json.decode(conditionData)
    if not conditions then return false, "Invalid field condition JSON" end
    
    return true, conditions
end

-- Pokemon Active State Tracking Handler
Handlers.add(
    "update-pokemon-state",
    Handlers.utils.hasMatchingTag("Action", "UpdatePokemonState"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local pokemonId = msg.PokemonId or msg.Tags.PokemonId
        local stateUpdates = msg.StateUpdates or msg.Data
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        if not pokemonId then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "PokemonId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        local valid, pokemonData = validatePokemonState(stateUpdates)
        if not valid then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = pokemonData,
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Initialize battle states if needed
        if not BattleStateManager.pokemonStates[battleId] then
            BattleStateManager.pokemonStates[battleId] = {}
        end
        
        -- Store previous state for change tracking
        local previousState = BattleStateManager.pokemonStates[battleId][pokemonId]
        
        -- Update Pokemon state
        BattleStateManager.pokemonStates[battleId][pokemonId] = {
            id = pokemonData.id,
            hp = pokemonData.hp,
            maxHp = pokemonData.maxHp,
            status = pokemonData.status,
            stats = pokemonData.stats or {},
            battleData = pokemonData.battleData or {},
            moveset = pokemonData.moveset or {},
            temporaryModifications = pokemonData.temporaryModifications or {},
            lastUpdated = timestamp
        }
        
        -- Track state changes
        local stateChanges = {}
        if previousState then
            if previousState.hp ~= pokemonData.hp then
                table.insert(stateChanges, {
                    field = "hp",
                    from = previousState.hp,
                    to = pokemonData.hp
                })
            end
            if previousState.status ~= pokemonData.status then
                table.insert(stateChanges, {
                    field = "status",
                    from = previousState.status,
                    to = pokemonData.status
                })
            end
        end
        
        local result = {
            success = true,
            pokemonState = BattleStateManager.pokemonStates[battleId][pokemonId],
            stateChanges = stateChanges,
            validation = {
                valid = true,
                timestamp = timestamp
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            PokemonId = tostring(msg.PokemonId or msg.Tags.PokemonId),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Field Condition Management Handler
Handlers.add(
    "manage-field-conditions",
    Handlers.utils.hasMatchingTag("Action", "ManageFieldConditions"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local conditionUpdates = msg.ConditionUpdates or msg.Data
        local turnNumber = tonumber(msg.TurnNumber or msg.Tags.TurnNumber) or 0
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        local valid, conditions = validateFieldConditions(conditionUpdates)
        if not valid then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = conditions,
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Initialize field conditions if needed
        if not BattleStateManager.fieldConditions[battleId] then
            BattleStateManager.fieldConditions[battleId] = {
                weather = nil,
                terrain = nil,
                effects = {},
                hazards = {},
                screens = {},
                history = {}
            }
        end
        
        local fieldState = BattleStateManager.fieldConditions[battleId]
        
        -- Update conditions
        if conditions.weather then
            fieldState.weather = {
                type = conditions.weather.type,
                turnsRemaining = conditions.weather.turnsRemaining or -1,
                setOnTurn = turnNumber
            }
        end
        
        if conditions.terrain then
            fieldState.terrain = {
                type = conditions.terrain.type,
                turnsRemaining = conditions.terrain.turnsRemaining or -1,
                setOnTurn = turnNumber
            }
        end
        
        -- Update effects, hazards, and screens
        fieldState.effects = conditions.effects or fieldState.effects
        fieldState.hazards = conditions.hazards or fieldState.hazards
        fieldState.screens = conditions.screens or fieldState.screens
        
        -- Track condition history
        table.insert(fieldState.history, {
            turn = turnNumber,
            changes = conditions,
            timestamp = timestamp
        })
        
        -- Calculate upcoming expirations
        local expirations = {}
        if fieldState.weather and fieldState.weather.turnsRemaining > 0 then
            table.insert(expirations, {
                type = "weather",
                expiresOnTurn = turnNumber + fieldState.weather.turnsRemaining
            })
        end
        if fieldState.terrain and fieldState.terrain.turnsRemaining > 0 then
            table.insert(expirations, {
                type = "terrain",
                expiresOnTurn = turnNumber + fieldState.terrain.turnsRemaining
            })
        end
        
        local result = {
            success = true,
            fieldConditions = fieldState,
            conditionHistory = fieldState.history,
            expirations = expirations
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            TurnNumber = tostring(msg.TurnNumber or msg.Tags.TurnNumber or 0),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Battle Participants Management Handler
Handlers.add(
    "manage-battle-participants",
    Handlers.utils.hasMatchingTag("Action", "ManageBattleParticipants"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local participantData = msg.ParticipantData or msg.Data
        local operation = msg.Operation or msg.Tags.Operation or "update"
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        if not participantData then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Participant data is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        local participants = json.decode(participantData)
        if not participants then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Invalid participant data JSON",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Initialize participants if needed
        if not BattleStateManager.participants[battleId] then
            BattleStateManager.participants[battleId] = {
                active = {},
                party = {},
                bench = {},
                substitutes = {},
                trainers = {}
            }
        end
        
        local battleParticipants = BattleStateManager.participants[battleId]
        
        -- Update participants based on operation
        if operation == "switch" then
            -- Handle Pokemon switching
            if participants.switchOut and participants.switchIn then
                battleParticipants.active[participants.switchOut.position] = participants.switchIn
                -- Move switched out Pokemon to bench
                table.insert(battleParticipants.bench, participants.switchOut)
            end
        elseif operation == "update" then
            -- Update participant data
            battleParticipants.active = participants.active or battleParticipants.active
            battleParticipants.party = participants.party or battleParticipants.party
            battleParticipants.bench = participants.bench or battleParticipants.bench
        end
        
        battleParticipants.lastUpdated = timestamp
        
        local result = {
            success = true,
            participants = battleParticipants,
            operation = operation,
            timestamp = timestamp
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            Operation = tostring(msg.Operation or msg.Tags.Operation or "update"),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Move History Tracking Handler
Handlers.add(
    "track-move-history",
    Handlers.utils.hasMatchingTag("Action", "TrackMoveHistory"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local moveData = msg.MoveData or msg.Data
        local turnNumber = tonumber(msg.TurnNumber or msg.Tags.TurnNumber) or 0
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        if not moveData then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Move data is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        local move = json.decode(moveData)
        if not move then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Invalid move data JSON",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Initialize move history if needed
        if not BattleStateManager.moveHistory[battleId] then
            BattleStateManager.moveHistory[battleId] = {
                moves = {},
                ppTracking = {},
                restrictions = {},
                lastMoveUsed = {}
            }
        end
        
        local history = BattleStateManager.moveHistory[battleId]
        
        -- Record move usage
        table.insert(history.moves, {
            turn = turnNumber,
            pokemonId = move.pokemonId,
            moveId = move.moveId,
            moveName = move.moveName,
            targets = move.targets or {},
            result = move.result,
            ppUsed = move.ppUsed or 1,
            timestamp = timestamp
        })
        
        -- Update PP tracking
        if move.pokemonId and move.moveId then
            local pokemonKey = move.pokemonId
            if not history.ppTracking[pokemonKey] then
                history.ppTracking[pokemonKey] = {}
            end
            
            local currentPP = history.ppTracking[pokemonKey][move.moveId] or move.maxPP or 0
            history.ppTracking[pokemonKey][move.moveId] = math.max(0, currentPP - (move.ppUsed or 1))
            
            -- Track last move used for Copycat, Mirror Move, etc.
            history.lastMoveUsed[pokemonKey] = {
                moveId = move.moveId,
                turn = turnNumber,
                targets = move.targets
            }
        end
        
        -- Update move restrictions (Disable, Encore, etc.)
        if move.restrictions then
            for pokemonId, restriction in pairs(move.restrictions) do
                history.restrictions[pokemonId] = restriction
            end
        end
        
        local result = {
            success = true,
            moveHistory = history.moves,
            ppTracking = history.ppTracking,
            restrictions = history.restrictions,
            lastMoveUsed = history.lastMoveUsed
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            TurnNumber = tostring(msg.TurnNumber or msg.Tags.TurnNumber or 0),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Battle Event Logging Handler
Handlers.add(
    "log-battle-events",
    Handlers.utils.hasMatchingTag("Action", "LogBattleEvents"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local eventData = msg.EventData or msg.Data
        local eventType = msg.EventType or msg.Tags.EventType
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        if not eventData then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Event data is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        local event = json.decode(eventData)
        if not event then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Invalid event data JSON",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Initialize event log if needed
        if not BattleStateManager.eventLog[battleId] then
            BattleStateManager.eventLog[battleId] = {
                events = {},
                damageCalculations = {},
                statusEffects = {},
                switches = {},
                criticalDecisions = {}
            }
        end
        
        local log = BattleStateManager.eventLog[battleId]
        
        -- Create comprehensive event entry
        local eventEntry = {
            id = #log.events + 1,
            type = eventType or event.type or "general",
            turn = event.turn or 0,
            pokemonId = event.pokemonId,
            data = event,
            timestamp = timestamp,
            timing = event.timing or "during-turn"
        }
        
        -- Add to main event log
        table.insert(log.events, eventEntry)
        
        -- Categorize events for specialized tracking
        if eventType == "damage" then
            table.insert(log.damageCalculations, {
                eventId = eventEntry.id,
                attacker = event.attacker,
                defender = event.defender,
                damage = event.damage,
                moveId = event.moveId,
                critical = event.critical or false,
                effectiveness = event.effectiveness or 1,
                breakdown = event.breakdown or {}
            })
        elseif eventType == "status" then
            table.insert(log.statusEffects, {
                eventId = eventEntry.id,
                pokemonId = event.pokemonId,
                status = event.status,
                action = event.action, -- "apply" or "remove"
                source = event.source
            })
        elseif eventType == "switch" then
            table.insert(log.switches, {
                eventId = eventEntry.id,
                switchOut = event.switchOut,
                switchIn = event.switchIn,
                forced = event.forced or false
            })
        elseif eventType == "decision" then
            table.insert(log.criticalDecisions, {
                eventId = eventEntry.id,
                decisionType = event.decisionType,
                options = event.options or {},
                chosen = event.chosen,
                reasoning = event.reasoning
            })
        end
        
        local result = {
            success = true,
            eventId = eventEntry.id,
            totalEvents = #log.events,
            categorizedCounts = {
                damage = #log.damageCalculations,
                status = #log.statusEffects,
                switches = #log.switches,
                decisions = #log.criticalDecisions
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            EventType = tostring(msg.EventType or msg.Tags.EventType or "general"),
            EventId = tostring(result.eventId),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Battle State Serialization Handler
Handlers.add(
    "serialize-battle-state",
    Handlers.utils.hasMatchingTag("Action", "SerializeBattleState"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local includeHistory = (msg.IncludeHistory or msg.Tags.IncludeHistory) == "true"
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Collect all battle state data
        local completeState = {
            battleId = battleId,
            pokemonStates = BattleStateManager.pokemonStates[battleId] or {},
            fieldConditions = BattleStateManager.fieldConditions[battleId] or {},
            participants = BattleStateManager.participants[battleId] or {},
            serializedAt = timestamp,
            version = "1.0"
        }
        
        -- Include history if requested
        if includeHistory then
            completeState.moveHistory = BattleStateManager.moveHistory[battleId] or {}
            completeState.eventLog = BattleStateManager.eventLog[battleId] or {}
        end
        
        -- Serialize to JSON
        local serializedState = json.encode(completeState)
        if not serializedState then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Failed to serialize battle state",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Generate checksum for data integrity
        local checksum = crypto and crypto.digest and crypto.digest.sha256(serializedState) or "no-checksum-available"
        
        -- Store serialized state
        if not BattleStateManager.serializedStates[battleId] then
            BattleStateManager.serializedStates[battleId] = {}
        end
        
        BattleStateManager.serializedStates[battleId][timestamp] = {
            data = serializedState,
            checksum = checksum,
            includeHistory = includeHistory,
            size = #serializedState
        }
        
        local result = {
            success = true,
            serializedState = serializedState,
            checksum = checksum,
            version = "1.0",
            compressed = false,
            size = #serializedState,
            includeHistory = includeHistory
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            Checksum = tostring(result.checksum),
            Size = tostring(result.size),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Battle State Deserialization Handler
Handlers.add(
    "deserialize-battle-state",
    Handlers.utils.hasMatchingTag("Action", "DeserializeBattleState"),
    function(msg)
        local battleId = msg.BattleId or msg.Tags.BattleId
        local serializedData = msg.Data
        local expectedChecksum = msg.Checksum or msg.Tags.Checksum
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        -- Validate parameters
        if not validateBattleId(battleId) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Valid BattleId is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        if not serializedData then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Serialized state data is required",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Verify data integrity if checksum provided
        if expectedChecksum and crypto and crypto.digest then
            local actualChecksum = crypto.digest.sha256(serializedData)
            if actualChecksum ~= expectedChecksum then
                ao.send({
                    Target = msg.From,
                    Action = "SaveState",
                    Error = "Data integrity check failed: checksum mismatch",
                    Success = "false",
                    ProcessId = tostring(ao.id),
                    Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
                })
                return
            end
        end
        
        -- Deserialize state data
        local battleState = json.decode(serializedData)
        if not battleState then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Failed to deserialize battle state data",
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Validate version compatibility
        if battleState.version and battleState.version ~= "1.0" then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Incompatible state version: " .. tostring(battleState.version),
                Success = "false",
                ProcessId = tostring(ao.id),
                Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
            })
            return
        end
        
        -- Restore battle state
        if battleState.pokemonStates then
            BattleStateManager.pokemonStates[battleId] = battleState.pokemonStates
        end
        if battleState.fieldConditions then
            BattleStateManager.fieldConditions[battleId] = battleState.fieldConditions
        end
        if battleState.participants then
            BattleStateManager.participants[battleId] = battleState.participants
        end
        if battleState.moveHistory then
            BattleStateManager.moveHistory[battleId] = battleState.moveHistory
        end
        if battleState.eventLog then
            BattleStateManager.eventLog[battleId] = battleState.eventLog
        end
        
        local result = {
            success = true,
            restoredComponents = {
                pokemonStates = battleState.pokemonStates ~= nil,
                fieldConditions = battleState.fieldConditions ~= nil,
                participants = battleState.participants ~= nil,
                moveHistory = battleState.moveHistory ~= nil,
                eventLog = battleState.eventLog ~= nil
            },
            version = battleState.version or "1.0",
            originalTimestamp = battleState.serializedAt,
            restoredAt = timestamp
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            BattleId = tostring(msg.BattleId or msg.Tags.BattleId),
            Version = tostring(result.version),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- Memory Management and Cleanup Handler
Handlers.add(
    "manage-memory",
    Handlers.utils.hasMatchingTag("Action", "ManageMemory"),
    function(msg)
        local operation = msg.Operation or msg.Tags.Operation or "cleanup"
        local battleId = msg.BattleId or msg.Tags.BattleId
        local timestamp = msg.Timestamp or createTimestamp(msg)
        
        local stats = {
            before = {
                activeBattles = 0,
                totalMemoryUsage = 0
            },
            after = {
                activeBattles = 0,
                totalMemoryUsage = 0
            }
        }
        
        -- Count current usage
        for _, _ in pairs(BattleStateManager.pokemonStates) do
            stats.before.activeBattles = stats.before.activeBattles + 1
        end
        
        if operation == "cleanup" then
            -- Clean up expired battle states (battles older than 24 hours without updates)
            local cutoff = tonumber(timestamp) - 86400 -- 24 hours ago
            local cleaned = 0
            
            for id, pokemonStates in pairs(BattleStateManager.pokemonStates) do
                local shouldClean = true
                
                -- Check if any Pokemon was updated recently
                for _, pokemon in pairs(pokemonStates) do
                    if pokemon.lastUpdated and tonumber(pokemon.lastUpdated) > cutoff then
                        shouldClean = false
                        break
                    end
                end
                
                if shouldClean then
                    BattleStateManager.pokemonStates[id] = nil
                    BattleStateManager.fieldConditions[id] = nil
                    BattleStateManager.participants[id] = nil
                    BattleStateManager.moveHistory[id] = nil
                    BattleStateManager.eventLog[id] = nil
                    BattleStateManager.serializedStates[id] = nil
                    cleaned = cleaned + 1
                end
            end
            
            stats.cleaned = cleaned
        elseif operation == "validate" then
            -- Validate state consistency
            local issues = {}
            
            for id, pokemonStates in pairs(BattleStateManager.pokemonStates) do
                for pokemonId, pokemon in pairs(pokemonStates) do
                    -- Validate HP consistency
                    if pokemon.hp > pokemon.maxHp then
                        table.insert(issues, {
                            battleId = id,
                            pokemonId = pokemonId,
                            issue = "HP exceeds max HP",
                            current = pokemon.hp,
                            max = pokemon.maxHp
                        })
                    end
                    
                    -- Validate status consistency
                    if pokemon.status and pokemon.hp <= 0 then
                        table.insert(issues, {
                            battleId = id,
                            pokemonId = pokemonId,
                            issue = "Status on fainted Pokemon",
                            status = pokemon.status,
                            hp = pokemon.hp
                        })
                    end
                end
            end
            
            stats.validationIssues = issues
        elseif operation == "clear" and battleId then
            -- Clear specific battle state
            if BattleStateManager.pokemonStates[battleId] then
                BattleStateManager.pokemonStates[battleId] = nil
                BattleStateManager.fieldConditions[battleId] = nil
                BattleStateManager.participants[battleId] = nil
                BattleStateManager.moveHistory[battleId] = nil
                BattleStateManager.eventLog[battleId] = nil
                BattleStateManager.serializedStates[battleId] = nil
                stats.cleared = battleId
            end
        end
        
        -- Count final usage
        for _, _ in pairs(BattleStateManager.pokemonStates) do
            stats.after.activeBattles = stats.after.activeBattles + 1
        end
        
        local result = {
            success = true,
            operation = operation,
            stats = stats,
            timestamp = timestamp
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result),
            Success = "true",
            Operation = tostring(msg.Operation or msg.Tags.Operation or "cleanup"),
            ProcessId = tostring(ao.id),
            Timestamp = tostring(msg.Timestamp or createTimestamp(msg))
        })
    end
)

-- AO Documentation Protocol (ADP) v1.0 - Info Handler
Handlers.add(
    "info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Battle State Manager",
            Description = "Comprehensive Pokemon battle state tracking process for HP, status, field conditions, participants, move history, and event logging with replay functionality",
            Owner = ao.env and ao.env.Process and ao.env.Process.Owner or "Unknown",
            ProcessId = ao.id,
            protocolVersion = "1.0",
            adpVersion = "1.0",
            lastUpdated = "2024-09-24T19:20:00.000Z",
            capabilities = {
                "Pokemon active state tracking",
                "Field condition management",
                "Battle participant coordination", 
                "Move history tracking",
                "Battle event logging",
                "State serialization/deserialization",
                "Memory management and cleanup"
            },
            handlers = {
                {
                    action = "UpdatePokemonState",
                    pattern = {"Action"},
                    description = "Track Pokemon HP, status, and temporary modifications",
                    category = "state-management",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "PokemonId", type = "string", required = true, description = "Pokemon identifier"},
                        {name = "StateUpdates", type = "json", required = true, description = "Pokemon state data including HP, status, modifications"}
                    }
                },
                {
                    action = "ManageFieldConditions", 
                    pattern = {"Action"},
                    description = "Manage weather, terrain, and field effects",
                    category = "state-management",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "ConditionUpdates", type = "json", required = true, description = "Field condition data"},
                        {name = "TurnNumber", type = "number", required = false, description = "Current turn number"}
                    }
                },
                {
                    action = "ManageBattleParticipants",
                    pattern = {"Action"},
                    description = "Track active, party, and bench Pokemon states",
                    category = "state-management",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "ParticipantData", type = "json", required = true, description = "Participant state data"},
                        {name = "Operation", type = "string", required = false, description = "Operation type (switch, update)"}
                    }
                },
                {
                    action = "TrackMoveHistory",
                    pattern = {"Action"},
                    description = "Track move usage, PP, and restrictions",
                    category = "state-management",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "MoveData", type = "json", required = true, description = "Move execution data"},
                        {name = "TurnNumber", type = "number", required = false, description = "Turn when move was used"}
                    }
                },
                {
                    action = "LogBattleEvents",
                    pattern = {"Action"},
                    description = "Log battle events for replay and analysis",
                    category = "logging",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "EventData", type = "json", required = true, description = "Event data to log"},
                        {name = "EventType", type = "string", required = false, description = "Event category (damage, status, switch, decision)"}
                    }
                },
                {
                    action = "SerializeBattleState",
                    pattern = {"Action"},
                    description = "Serialize complete battle state with integrity validation",
                    category = "serialization",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "IncludeHistory", type = "boolean", required = false, description = "Include move and event history"}
                    }
                },
                {
                    action = "DeserializeBattleState",
                    pattern = {"Action"},
                    description = "Restore battle state from serialized data",
                    category = "serialization", 
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Unique battle identifier"},
                        {name = "Data", type = "json", required = true, description = "Serialized battle state"},
                        {name = "Checksum", type = "string", required = false, description = "Data integrity checksum"}
                    }
                },
                {
                    action = "ManageMemory",
                    pattern = {"Action"},
                    description = "Memory management and state cleanup",
                    category = "maintenance",
                    parameters = {
                        {name = "Operation", type = "string", required = false, description = "Operation type (cleanup, validate, clear)"},
                        {name = "BattleId", type = "string", required = false, description = "Battle ID for clear operation"}
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get process information and capabilities",
                    category = "core"
                }
            },
            messageSchemas = {
                UpdatePokemonState = {
                    required = {"Action", "BattleId", "PokemonId", "StateUpdates"},
                    optional = {"Timestamp"}
                },
                ManageFieldConditions = {
                    required = {"Action", "BattleId", "ConditionUpdates"},
                    optional = {"TurnNumber", "Timestamp"}
                },
                SerializeBattleState = {
                    required = {"Action", "BattleId"},
                    optional = {"IncludeHistory", "Timestamp"}
                }
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true,
                integratesWith = {"battle-engine-turn-manager", "damage-calculation-engine", "status-effects-engine"}
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode(infoResponse)
        })
    end
)

print("Battle State Manager Process initialized successfully with ADP v1.0 compliance")