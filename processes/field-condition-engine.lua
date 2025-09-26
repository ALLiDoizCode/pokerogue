-- Field Condition Management Process
-- Handles complex field conditions for Pokemon battles including room effects,
-- gravity, imprison, and future attacks with priority resolution and state persistence

local json = json

-- Field Condition State Management
FieldConditions = FieldConditions or {}
FutureAttacks = FutureAttacks or {}
BattleState = BattleState or {}

-- Field condition types enumeration
local CONDITION_TYPES = {
    TRICK_ROOM = "TRICK_ROOM",
    WONDER_ROOM = "WONDER_ROOM", 
    MAGIC_ROOM = "MAGIC_ROOM",
    GRAVITY = "GRAVITY",
    IMPRISON = "IMPRISON"
}

-- Future attack types enumeration
local FUTURE_ATTACK_TYPES = {
    FUTURE_SIGHT = "FUTURE_SIGHT",
    DOOM_DESIRE = "DOOM_DESIRE"
}

-- Default condition durations
local DEFAULT_DURATIONS = {
    [CONDITION_TYPES.TRICK_ROOM] = 5,
    [CONDITION_TYPES.WONDER_ROOM] = 5,
    [CONDITION_TYPES.MAGIC_ROOM] = 5,
    [CONDITION_TYPES.GRAVITY] = 5,
    [CONDITION_TYPES.IMPRISON] = 999, -- Until source Pokemon switches out
}

-- Condition priority for resolution order (higher = resolved first)
local CONDITION_PRIORITIES = {
    [CONDITION_TYPES.TRICK_ROOM] = 100,
    [CONDITION_TYPES.WONDER_ROOM] = 90,
    [CONDITION_TYPES.MAGIC_ROOM] = 80,
    [CONDITION_TYPES.GRAVITY] = 70,
    [CONDITION_TYPES.IMPRISON] = 60
}

-- Room effects that replace each other
local ROOM_EFFECTS = {
    [CONDITION_TYPES.TRICK_ROOM] = true,
    [CONDITION_TYPES.WONDER_ROOM] = true,
    [CONDITION_TYPES.MAGIC_ROOM] = true
}

-- Utility function to validate condition type
local function isValidConditionType(conditionType)
    return CONDITION_TYPES[conditionType] ~= nil
end

-- Utility function to validate future attack type
local function isValidFutureAttackType(attackType)
    return FUTURE_ATTACK_TYPES[attackType] ~= nil
end

-- Get battle-specific field conditions
local function getBattleConditions(battleId)
    if not FieldConditions[battleId] then
        FieldConditions[battleId] = {}
    end
    return FieldConditions[battleId]
end

-- Get battle-specific future attacks
local function getBattleFutureAttacks(battleId)
    if not FutureAttacks[battleId] then
        FutureAttacks[battleId] = {}
    end
    return FutureAttacks[battleId]
end

-- Remove room effects when a new room is applied
local function removeExistingRoomEffects(battleConditions, newConditionType)
    if not ROOM_EFFECTS[newConditionType] then
        return {}
    end
    
    local removedConditions = {}
    for conditionId, condition in pairs(battleConditions) do
        if ROOM_EFFECTS[condition.conditionType] and condition.conditionType ~= newConditionType then
            removedConditions[#removedConditions + 1] = {
                conditionType = condition.conditionType,
                conditionId = conditionId
            }
            battleConditions[conditionId] = nil
        end
    end
    
    return removedConditions
end

-- Check if Pokemon is affected by Imprison
local function isPokemonImprisoned(battleConditions, pokemonId, moveId)
    for _, condition in pairs(battleConditions) do
        if condition.conditionType == CONDITION_TYPES.IMPRISON and condition.sourceId ~= pokemonId then
            if condition.affectedPokemon and condition.affectedPokemon[pokemonId] then
                for _, restrictedMove in ipairs(condition.affectedPokemon[pokemonId].restrictedMoves or {}) do
                    if restrictedMove == moveId then
                        return true, condition.sourceId
                    end
                end
            end
        end
    end
    return false, nil
end

-- Apply field condition handler
Handlers.add("apply-field-condition",
    Handlers.utils.hasMatchingTag("Action", "ApplyFieldCondition"),
    function(msg)
        local conditionType = msg.ConditionType
        local sourceId = msg.SourceId
        local sourceMove = msg.SourceMove
        local side = msg.Side or "BOTH"
        local duration = tonumber(msg.Duration) or DEFAULT_DURATIONS[conditionType]
        local battleId = msg.BattleId
        local timestamp = msg.Timestamp or 0
        
        -- Validate required parameters
        if not conditionType or not isValidConditionType(conditionType) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid or missing ConditionType",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        if not sourceId or not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = "Missing required parameters: SourceId and BattleId required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleConditions = getBattleConditions(battleId)
        
        -- Handle room effect replacement
        local removedConditions = removeExistingRoomEffects(battleConditions, conditionType)
        
        -- Create new condition
        local conditionId = conditionType .. "_" .. sourceId .. "_" .. timestamp
        local newCondition = {
            conditionType = conditionType,
            turnsRemaining = duration,
            sourceId = tonumber(sourceId),
            sourceMove = sourceMove,
            side = side,
            priority = CONDITION_PRIORITIES[conditionType] or 50,
            appliedAt = timestamp,
            parameters = msg.Parameters and json.decode(msg.Parameters) or {},
            affectedPokemon = {}
        }
        
        -- Special handling for Imprison
        if conditionType == CONDITION_TYPES.IMPRISON then
            newCondition.affectedPokemon = msg.Parameters and json.decode(msg.Parameters).affectedPokemon or {}
        end
        
        battleConditions[conditionId] = newCondition
        
        -- Calculate priority adjustment for speed-based effects
        local priorityAdjustment = 0
        if conditionType == CONDITION_TYPES.TRICK_ROOM then
            priorityAdjustment = -1 -- Reverses speed priority
        end
        
        -- Prepare result data
        local conditionResult = {
            applied = true,
            replaced = #removedConditions > 0,
            priorityAdjustment = priorityAdjustment,
            removedConditions = removedConditions,
            conditionId = conditionId,
            groundedPokemon = conditionType == CONDITION_TYPES.GRAVITY and msg.Parameters and json.decode(msg.Parameters).groundedPokemon or {},
            imprisonedMoves = conditionType == CONDITION_TYPES.IMPRISON and msg.Parameters and json.decode(msg.Parameters).restrictedMoves or {}
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                fieldConditionState = newCondition,
                conditionResult = conditionResult,
                activeConditions = battleConditions
            }),
            Success = "true",
            ConditionType = conditionType,
            ConditionId = conditionId,
            Applied = "true",
            Replaced = tostring(conditionResult.replaced),
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Apply future attack handler
Handlers.add("apply-future-attack",
    Handlers.utils.hasMatchingTag("Action", "ApplyFutureAttack"), 
    function(msg)
        local attackType = msg.AttackType
        local sourceId = msg.SourceId
        local targetId = msg.TargetId
        local damage = tonumber(msg.Damage) or 0
        local delayTurns = tonumber(msg.DelayTurns) or 2
        local battleId = msg.BattleId
        local timestamp = msg.Timestamp or 0
        
        -- Validate required parameters
        if not attackType or not isValidFutureAttackType(attackType) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid or missing AttackType",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        if not sourceId or not targetId or not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: SourceId, TargetId, and BattleId required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleFutureAttacks = getBattleFutureAttacks(battleId)
        
        -- Create future attack
        local attackId = attackType .. "_" .. sourceId .. "_" .. targetId .. "_" .. timestamp
        local futureAttack = {
            attackType = attackType,
            sourceId = tonumber(sourceId),
            targetId = tonumber(targetId),
            damage = damage,
            turnsRemaining = delayTurns,
            appliedAt = timestamp,
            attackData = msg.AttackData and json.decode(msg.AttackData) or {}
        }
        
        battleFutureAttacks[attackId] = futureAttack
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                futureAttack = futureAttack,
                attackId = attackId,
                activeAttacks = battleFutureAttacks
            }),
            Success = "true",
            AttackType = attackType,
            AttackId = attackId,
            Scheduled = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Check field condition effects handler
Handlers.add("check-field-condition-effects",
    Handlers.utils.hasMatchingTag("Action", "CheckFieldConditionEffects"),
    function(msg)
        local checkType = msg.CheckType
        local pokemonId = msg.PokemonId
        local moveId = msg.MoveId
        local battleId = msg.BattleId
        local timestamp = msg.Timestamp or 0
        
        if not checkType or not pokemonId or not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: CheckType, PokemonId, and BattleId required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleConditions = getBattleConditions(battleId)
        local effectResults = {}
        
        if checkType == "SPEED_PRIORITY" then
            local speedModifier = 1
            for _, condition in pairs(battleConditions) do
                if condition.conditionType == CONDITION_TYPES.TRICK_ROOM then
                    speedModifier = -1
                    break
                end
            end
            effectResults.speedPriorityModifier = speedModifier
            
        elseif checkType == "GROUNDING" then
            local isGrounded = false
            for _, condition in pairs(battleConditions) do
                if condition.conditionType == CONDITION_TYPES.GRAVITY then
                    isGrounded = true
                    break
                end
            end
            effectResults.isGrounded = isGrounded
            
        elseif checkType == "MOVE_RESTRICTION" then
            if moveId then
                local imprisoned, imprisonSource = isPokemonImprisoned(battleConditions, tonumber(pokemonId), moveId)
                effectResults.moveRestricted = imprisoned
                effectResults.imprisonSource = imprisonSource
            else
                effectResults.moveRestricted = false
            end
            
        elseif checkType == "ITEM_RESTRICTION" then
            local itemsDisabled = false
            for _, condition in pairs(battleConditions) do
                if condition.conditionType == CONDITION_TYPES.MAGIC_ROOM then
                    itemsDisabled = true
                    break
                end
            end
            effectResults.itemsDisabled = itemsDisabled
            
        elseif checkType == "STAT_SWAP" then
            local statsSwapped = false
            for _, condition in pairs(battleConditions) do
                if condition.conditionType == CONDITION_TYPES.WONDER_ROOM then
                    statsSwapped = true
                    break
                end
            end
            effectResults.statsSwapped = statsSwapped
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                effectResults = effectResults,
                checkType = checkType,
                pokemonId = pokemonId,
                activeConditions = battleConditions
            }),
            Success = "true",
            CheckType = checkType,
            PokemonId = pokemonId,
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Process field condition interactions handler
Handlers.add("process-field-condition-interactions",
    Handlers.utils.hasMatchingTag("Action", "ProcessFieldConditionInteractions"),
    function(msg)
        local interactionType = msg.InteractionType
        local battleId = msg.BattleId
        local timestamp = msg.Timestamp or 0
        
        if not interactionType or not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: InteractionType and BattleId required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleConditions = getBattleConditions(battleId)
        local interactionResults = {}
        
        if interactionType == "OVERLAP" then
            -- Handle room effect overlaps (newer replaces older)
            local activeRoomEffects = {}
            for conditionId, condition in pairs(battleConditions) do
                if ROOM_EFFECTS[condition.conditionType] then
                    activeRoomEffects[#activeRoomEffects + 1] = {
                        conditionId = conditionId,
                        conditionType = condition.conditionType,
                        appliedAt = condition.appliedAt
                    }
                end
            end
            
            interactionResults.activeRoomEffects = activeRoomEffects
            interactionResults.roomEffectCount = #activeRoomEffects
            
        elseif interactionType == "CASCADE" then
            -- Handle cascade removal effects
            local removedConditions = {}
            if msg.NewCondition then
                local newCondition = json.decode(msg.NewCondition)
                if ROOM_EFFECTS[newCondition.conditionType] then
                    removedConditions = removeExistingRoomEffects(battleConditions, newCondition.conditionType)
                end
            end
            
            interactionResults.removedConditions = removedConditions
            interactionResults.cascadeCount = #removedConditions
            
        elseif interactionType == "PRIORITY" then
            -- Sort active conditions by priority
            local sortedConditions = {}
            for conditionId, condition in pairs(battleConditions) do
                sortedConditions[#sortedConditions + 1] = {
                    conditionId = conditionId,
                    conditionType = condition.conditionType,
                    priority = condition.priority
                }
            end
            
            table.sort(sortedConditions, function(a, b)
                return a.priority > b.priority
            end)
            
            interactionResults.sortedConditions = sortedConditions
            interactionResults.resolutionOrder = sortedConditions
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                interactionResults = interactionResults,
                interactionType = interactionType,
                activeConditions = battleConditions
            }),
            Success = "true",
            InteractionType = interactionType,
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Turn advance handler for condition management
Handlers.add("advance-turn",
    Handlers.utils.hasMatchingTag("Action", "AdvanceTurn"),
    function(msg)
        local battleId = msg.BattleId
        local timestamp = msg.Timestamp or 0
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameter: BattleId",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleConditions = getBattleConditions(battleId)
        local battleFutureAttacks = getBattleFutureAttacks(battleId)
        local expiredConditions = {}
        local executedAttacks = {}
        
        -- Decrement condition turn counters and remove expired
        for conditionId, condition in pairs(battleConditions) do
            if condition.turnsRemaining > 0 then
                condition.turnsRemaining = condition.turnsRemaining - 1
                if condition.turnsRemaining <= 0 then
                    expiredConditions[#expiredConditions + 1] = {
                        conditionId = conditionId,
                        conditionType = condition.conditionType
                    }
                    battleConditions[conditionId] = nil
                end
            end
        end
        
        -- Decrement future attack counters and execute ready attacks
        for attackId, attack in pairs(battleFutureAttacks) do
            if attack.turnsRemaining > 0 then
                attack.turnsRemaining = attack.turnsRemaining - 1
                if attack.turnsRemaining <= 0 then
                    executedAttacks[#executedAttacks + 1] = {
                        attackId = attackId,
                        attackType = attack.attackType,
                        sourceId = attack.sourceId,
                        targetId = attack.targetId,
                        damage = attack.damage
                    }
                    battleFutureAttacks[attackId] = nil
                end
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                expiredConditions = expiredConditions,
                executedAttacks = executedAttacks,
                activeConditions = battleConditions,
                activeFutureAttacks = battleFutureAttacks
            }),
            Success = "true",
            BattleId = battleId,
            ExpiredCount = tostring(#expiredConditions),
            ExecutedCount = tostring(#executedAttacks),
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- AO Documentation Protocol (ADP) v1.0 Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Field Condition Engine",
            Description = "Pokemon battle field condition management process handling room effects, gravity, imprison, and future attacks with priority resolution and state persistence",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
                {
                    action = "ApplyFieldCondition",
                    pattern = {"Action"},
                    description = "Apply field condition with priority resolution and room effect replacement",
                    category = "core",
                    parameters = {
                        {
                            name = "ConditionType",
                            type = "string", 
                            required = true,
                            description = "Field condition type (TRICK_ROOM, WONDER_ROOM, MAGIC_ROOM, GRAVITY, IMPRISON)"
                        },
                        {
                            name = "SourceId",
                            type = "string",
                            required = true,
                            description = "Pokemon ID that created the condition"
                        },
                        {
                            name = "BattleId",
                            type = "string",
                            required = true,
                            description = "Battle identifier"
                        },
                        {
                            name = "Duration",
                            type = "string",
                            required = false,
                            description = "Condition duration in turns (defaults to 5)"
                        }
                    }
                },
                {
                    action = "ApplyFutureAttack",
                    pattern = {"Action"},
                    description = "Schedule future attack with delayed execution",
                    category = "core",
                    parameters = {
                        {
                            name = "AttackType",
                            type = "string",
                            required = true,
                            description = "Future attack type (FUTURE_SIGHT, DOOM_DESIRE)"
                        },
                        {
                            name = "SourceId", 
                            type = "string",
                            required = true,
                            description = "Attacking Pokemon ID"
                        },
                        {
                            name = "TargetId",
                            type = "string", 
                            required = true,
                            description = "Target Pokemon ID"
                        },
                        {
                            name = "BattleId",
                            type = "string",
                            required = true,
                            description = "Battle identifier"
                        }
                    }
                },
                {
                    action = "CheckFieldConditionEffects",
                    pattern = {"Action"},
                    description = "Check field condition effects on speed, moves, items, and stats",
                    category = "query",
                    parameters = {
                        {
                            name = "CheckType",
                            type = "string",
                            required = true,
                            description = "Type of check (SPEED_PRIORITY, GROUNDING, MOVE_RESTRICTION, ITEM_RESTRICTION, STAT_SWAP)"
                        },
                        {
                            name = "PokemonId",
                            type = "string",
                            required = true,
                            description = "Pokemon ID to check"
                        },
                        {
                            name = "BattleId",
                            type = "string",
                            required = true,
                            description = "Battle identifier"
                        }
                    }
                },
                {
                    action = "ProcessFieldConditionInteractions", 
                    pattern = {"Action"},
                    description = "Process complex field condition interactions and priority resolution",
                    category = "core",
                    parameters = {
                        {
                            name = "InteractionType",
                            type = "string",
                            required = true,
                            description = "Interaction type (OVERLAP, CASCADE, PRIORITY)"
                        },
                        {
                            name = "BattleId",
                            type = "string",
                            required = true,
                            description = "Battle identifier"
                        }
                    }
                },
                {
                    action = "AdvanceTurn",
                    pattern = {"Action"},
                    description = "Advance turn counter for conditions and execute ready future attacks",
                    category = "core",
                    parameters = {
                        {
                            name = "BattleId",
                            type = "string",
                            required = true,
                            description = "Battle identifier"
                        }
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get comprehensive process information and handler metadata",
                    category = "utility"
                },
                {
                    action = "Ping",
                    pattern = {"Action"},
                    description = "Test if process is responding",
                    category = "utility"
                }
            },
            capabilities = {
                supportsHandlerRegistry = true,
                supportsTagValidation = true,
                supportsExamples = true,
                supportsFieldConditions = true,
                supportsFutureAttacks = true,
                supportsPriorityResolution = true
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse),
            Action = "SaveState",
            Success = "true",
            ProcessId = ao.id
        })
    end
)

-- Basic Ping handler for ADP testing
Handlers.add("ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong",
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Field Condition Engine loaded successfully with ADP v1.0 compliance")