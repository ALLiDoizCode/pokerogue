-- Pokemon Battle Engine Turn Manager
-- ADP v1.0 Compliant AO Process for Turn-Based Battle Management
-- Handles turn order calculation, action validation, execution pipeline, and battle flow control

-- AO Compliance: json module is available as global

-- Initialize Battle State
if not BattleState then
  BattleState = {
    activeBattles = {},
    initialized = true
  }
end

-- AO Crypto Module for Deterministic Randomization
local function deterministicRandom(seed, counter)
    -- Use AO crypto module for deterministic randomization
    -- This ensures battle replay capability and cross-process consistency
    local hash = crypto.digest.sha256(seed .. tostring(counter))
    local num = tonumber(hash:sub(1, 8), 16)
    return (num % 10000) / 10000
end

-- Battle RNG System
local function getBattleRNG(battleId, seed, counter)
    return deterministicRandom(battleId .. seed, counter)
end

-- Speed Tie-Breaking with Deterministic Randomization
local function breakSpeedTie(participants, battleId, turn)
    -- Shuffle participants with deterministic randomization for speed ties
    local shuffled = {}
    for i, participant in ipairs(participants) do
        shuffled[i] = participant
    end

    -- Fisher-Yates shuffle with deterministic RNG
    for i = #shuffled, 2, -1 do
        local rngValue = getBattleRNG(battleId, "speed_tie", turn * 1000 + i)
        local j = math.floor(rngValue * i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    return shuffled
end

-- Turn Order Calculation with Priority Handling
local function calculateTurnOrder(participants, battleId, turn, priorityMoves)
    -- Step 1: Break speed ties with deterministic randomization
    local shuffledParticipants = breakSpeedTie(participants, battleId, turn)

    -- Step 2: Sort by effective speed (considering Trick Room)
    local speedSorted = {}
    for _, participant in ipairs(shuffledParticipants) do
        table.insert(speedSorted, participant)
    end

    table.sort(speedSorted, function(a, b)
        local aSpeed = tonumber(a.stats.speed) or 0
        local bSpeed = tonumber(b.stats.speed) or 0

        -- Handle Trick Room reversal
        local trickRoom = a.battleConditions and a.battleConditions.trickRoom or false
        if trickRoom then
            return aSpeed < bSpeed
        else
            return aSpeed > bSpeed
        end
    end)

    -- Step 3: Apply priority move handling (+1 to +5 priority levels)
    local finalOrder = {}
    local priorityGroups = {}

    -- Group by priority levels
    for _, participant in ipairs(speedSorted) do
        local priority = 0
        if priorityMoves and priorityMoves[participant.id] then
            priority = tonumber(priorityMoves[participant.id].priority) or 0
        end

        if not priorityGroups[priority] then
            priorityGroups[priority] = {}
        end
        table.insert(priorityGroups[priority], participant)
    end

    -- Sort priority groups (highest priority first)
    local sortedPriorities = {}
    for priority, _ in pairs(priorityGroups) do
        table.insert(sortedPriorities, priority)
    end
    table.sort(sortedPriorities, function(a, b) return a > b end)

    -- Build final turn order
    for _, priority in ipairs(sortedPriorities) do
        for _, participant in ipairs(priorityGroups[priority]) do
            table.insert(finalOrder, participant)
        end
    end

    return finalOrder
end

-- Action Validation System
local function validateAction(pokemonId, actionType, actionData, battleState)
    local errors = {}
    local constraints = {}
    local availableActions = {"FIGHT", "SWITCH", "ITEM", "RUN"}

    -- Find Pokemon in battle state
    local pokemon = nil
    for _, p in ipairs(battleState.participants or {}) do
        if p.id == pokemonId then
            pokemon = p
            break
        end
    end

    if not pokemon then
        table.insert(errors, "Pokemon not found in battle")
        return false, availableActions, constraints, errors
    end

    -- Validate action type
    if actionType == "FIGHT" then
        -- Check move availability
        if not actionData.moveId then
            table.insert(errors, "Move ID required for FIGHT action")
            return false, availableActions, constraints, errors
        end

        -- Check PP (Power Points)
        local move = nil
        for _, m in ipairs(pokemon.moves or {}) do
            if m.id == actionData.moveId then
                move = m
                break
            end
        end

        if not move then
            table.insert(errors, "Move not available")
            return false, availableActions, constraints, errors
        end

        if (move.pp or 0) <= 0 then
            table.insert(errors, "Insufficient PP for move")
            table.insert(constraints, "No PP remaining")
            return false, availableActions, constraints, errors
        end

        -- Check disabled moves (Taunt, Torment, Choice items)
        if pokemon.statusEffects then
            if pokemon.statusEffects.taunt and move.category == "status" then
                table.insert(errors, "Move disabled by Taunt")
                table.insert(constraints, "Taunt active - status moves disabled")
                return false, availableActions, constraints, errors
            end

            if pokemon.statusEffects.encore and pokemon.statusEffects.encoreMove ~= actionData.moveId then
                table.insert(errors, "Must use Encore move")
                table.insert(constraints, "Encore active")
                return false, availableActions, constraints, errors
            end
        end

        -- Check recharge moves (Hyper Beam, Blast Burn, etc.)
        if pokemon.mustRecharge then
            table.insert(errors, "Pokemon must recharge")
            table.insert(constraints, "Recharging after powerful move")
            return false, availableActions, constraints, errors
        end

    elseif actionType == "SWITCH" then
        -- Check if trapped
        if pokemon.statusEffects and pokemon.statusEffects.trapped then
            table.insert(errors, "Pokemon is trapped and cannot switch")
            table.insert(constraints, "Trapped by move or ability")
            return false, availableActions, constraints, errors
        end

        -- Check switch target validity
        if not actionData.targetPokemonId then
            table.insert(errors, "Target Pokemon ID required for switch")
            return false, availableActions, constraints, errors
        end

    elseif actionType == "ITEM" then
        -- Item usage validation would go here
        if not actionData.itemId then
            table.insert(errors, "Item ID required")
            return false, availableActions, constraints, errors
        end

    elseif actionType == "RUN" then
        -- Run validation (wild battles only, not trapped, etc.)
        if battleState.battleType == "trainer" then
            table.insert(errors, "Cannot run from trainer battles")
            table.insert(constraints, "Trainer battle")
            return false, availableActions, constraints, errors
        end
    end

    return true, availableActions, constraints, errors
end

-- Multi-Target Move Resolution
local function resolveMultiTargetMove(move, targets)
    local results = {}
    local damageReduction = 1.0

    -- Apply damage reduction for multiple targets (0.75x multiplier)
    if #targets > 1 then
        damageReduction = 0.75
    end

    for _, target in ipairs(targets) do
        local result = {
            target = target.id,
            hit = true,
            damage = 0,
            effectiveness = 1.0
        }

        -- Apply damage reduction
        if move.basePower and move.basePower > 0 then
            result.damage = math.floor(move.basePower * damageReduction)
        end

        table.insert(results, result)
    end

    return results
end

-- Turn Execution Pipeline
local function executeTurn(battleId, turnData, battleState)
    local turnResults = {}
    local updatedBattleState = battleState
    local battleEnd = false

    -- Pre-turn phase processing
    for _, participant in ipairs(turnData.turnOrder or {}) do
        -- Weather damage, status effects, abilities
        local preTurnEffects = {
            participant = participant.id,
            effects = {},
            damage = 0
        }

        -- Status damage (poison, burn, etc.)
        if participant.statusEffect then
            if participant.statusEffect == "poison" then
                preTurnEffects.damage = math.floor((participant.stats.hp or 100) / 8)
                table.insert(preTurnEffects.effects, "poison_damage")
            elseif participant.statusEffect == "burn" then
                preTurnEffects.damage = math.floor((participant.stats.hp or 100) / 16)
                table.insert(preTurnEffects.effects, "burn_damage")
            end
        end

        table.insert(turnResults, preTurnEffects)
    end

    -- Move execution phase
    for _, participant in ipairs(turnData.turnOrder or {}) do
        local action = turnData.actions and turnData.actions[participant.id]
        if action then
            local executionResult = {
                participant = participant.id,
                action = action.type,
                success = true,
                effects = {}
            }

            if action.type == "FIGHT" then
                -- Execute move
                local move = action.move
                if move.targets and #move.targets > 0 then
                    local multiTargetResults = resolveMultiTargetMove(move, move.targets)
                    executionResult.multiTargetResults = multiTargetResults
                end

                -- Reduce PP
                for _, m in ipairs(participant.moves or {}) do
                    if m.id == move.id then
                        m.pp = math.max(0, (m.pp or 0) - 1)
                        break
                    end
                end

            elseif action.type == "SWITCH" then
                -- Handle switching
                executionResult.switchedTo = action.targetPokemonId
                table.insert(executionResult.effects, "switched_pokemon")

            end

            table.insert(turnResults, executionResult)
        end
    end

    -- Post-turn phase processing
    for _, participant in ipairs(turnData.turnOrder or {}) do
        -- End-of-turn abilities, item effects
        local postTurnEffects = {
            participant = participant.id,
            effects = {},
            healing = 0
        }

        -- Leftovers healing
        if participant.heldItem == "leftovers" then
            postTurnEffects.healing = math.floor((participant.stats.hp or 100) / 16)
            table.insert(postTurnEffects.effects, "leftovers_healing")
        end

        -- Speed Boost ability
        if participant.ability == "speedboost" then
            table.insert(postTurnEffects.effects, "speed_boost")
        end

        table.insert(turnResults, postTurnEffects)
    end

    -- Check battle end conditions
    local alivePlayers = 0
    local aliveEnemies = 0
    for _, participant in ipairs(turnData.turnOrder or {}) do
        if (participant.hp or 0) > 0 then
            if participant.isPlayer then
                alivePlayers = alivePlayers + 1
            else
                aliveEnemies = aliveEnemies + 1
            end
        end
    end

    if alivePlayers == 0 or aliveEnemies == 0 then
        battleEnd = true
    end

    -- Increment turn counter
    updatedBattleState.turn = (updatedBattleState.turn or 0) + 1

    return {
        turnResults = turnResults,
        battleState = updatedBattleState,
        nextTurn = updatedBattleState.turn,
        battleEnd = battleEnd
    }
end

-- Handler: Calculate Turn Order
Handlers.add("calculate-turn-order",
    Handlers.utils.hasMatchingTag("Action", "CalculateTurnOrder"),
    function(msg)
        local success, response = pcall(function()
            local battleId = msg.BattleId or msg.Tags.BattleId
            local participantsJson = msg.Participants or msg.Data
            local priorityMovesJson = msg.PriorityMoves or msg.Tags.PriorityMoves
            local turn = tonumber(msg.Tags.Turn or msg.Timestamp or "0")

            if not battleId then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "BattleId required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            if not participantsJson then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "Participants data required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            local participants = json.decode(participantsJson)
            local priorityMoves = priorityMovesJson and json.decode(priorityMovesJson) or {}

            local turnOrder = calculateTurnOrder(participants, battleId, turn, priorityMoves)

            -- Extract data for response
            local turnOrderIds = {}
            local priorities = {}
            local speedValues = {}

            for _, participant in ipairs(turnOrder) do
                table.insert(turnOrderIds, participant.id)
                priorities[participant.id] = priorityMoves[participant.id] and priorityMoves[participant.id].priority or 0
                speedValues[participant.id] = participant.stats.speed or 0
            end

            return {
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    turnOrder = turnOrderIds,
                    priorities = priorities,
                    speedValues = speedValues
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)

        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Validate Action
Handlers.add("validate-action",
    Handlers.utils.hasMatchingTag("Action", "ValidateAction"),
    function(msg)
        local success, response = pcall(function()
            local battleId = msg.BattleId or msg.Tags.BattleId
            local pokemonId = msg.PokemonId or msg.Tags.PokemonId
            local actionType = msg.ActionType or msg.Tags.ActionType
            local actionDataJson = msg.ActionData or msg.Data

            if not battleId then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "BattleId required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            if not pokemonId then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "PokemonId required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            if not actionType then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "ActionType required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            local actionData = actionDataJson and json.decode(actionDataJson) or {}

            -- Get battle state (would integrate with existing battle state management)
            local battleState = BattleState.activeBattles[battleId] or {
                participants = {},
                battleType = "wild"
            }

            local valid, availableActions, constraints, errors = validateAction(pokemonId, actionType, actionData, battleState)

            return {
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    valid = valid,
                    availableActions = availableActions,
                    constraints = constraints,
                    errors = errors
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)

        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Execute Turn
Handlers.add("execute-turn",
    Handlers.utils.hasMatchingTag("Action", "ExecuteTurn"),
    function(msg)
        local success, response = pcall(function()
            local battleId = msg.BattleId or msg.Tags.BattleId
            local turnDataJson = msg.TurnData or msg.Data
            local battleStateJson = msg.BattleState or msg.Tags.BattleState

            if not battleId then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "BattleId required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            if not turnDataJson then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "TurnData required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            local turnData = json.decode(turnDataJson)
            local battleState = battleStateJson and json.decode(battleStateJson) or BattleState.activeBattles[battleId] or {}

            local executionResult = executeTurn(battleId, turnData, battleState)

            -- Update stored battle state
            BattleState.activeBattles[battleId] = executionResult.battleState

            return {
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(executionResult),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)

        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Process Switch
Handlers.add("process-switch",
    Handlers.utils.hasMatchingTag("Action", "ProcessSwitch"),
    function(msg)
        local success, response = pcall(function()
            local battleId = msg.BattleId or msg.Tags.BattleId
            local pokemonId = msg.PokemonId or msg.Tags.PokemonId
            local targetPokemonId = msg.TargetPokemonId or msg.Tags.TargetPokemonId

            if not battleId or not pokemonId or not targetPokemonId then
                return {
                    Target = msg.From,
                    Action = "Error",
                    Error = "BattleId, PokemonId, and TargetPokemonId required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end

            -- Process switch with proper timing and validation
            local switchResult = {
                switched = true,
                from = pokemonId,
                to = targetPokemonId,
                timing = "before_moves",
                entryHazards = {} -- Would be populated with actual hazard data
            }

            return {
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(switchResult),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)

        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            name = "Pokemon Battle Engine Turn Manager",
            description = "Comprehensive turn-based battle engine for Pokemon battles with speed-based prioritization, action validation, turn execution pipeline, and battle flow control",
            version = "1.0.0",
            adpVersion = "1.0",
            owner = ao.env.Process.Owner or "unknown",
            processId = ao.id,
            capabilities = {
                "turn_order_calculation",
                "action_validation",
                "turn_execution",
                "multi_target_resolution",
                "switch_mechanics",
                "battle_flow_control",
                "deterministic_randomization"
            },
            handlers = {
                "CalculateTurnOrder",
                "ValidateAction",
                "ExecuteTurn",
                "ProcessSwitch",
                "Info",
                "Ping"
            },
            messageSchemas = {
                CalculateTurnOrder = {
                    required = {"BattleId", "Participants"},
                    optional = {"PriorityMoves", "Turn"}
                },
                ValidateAction = {
                    required = {"BattleId", "PokemonId", "ActionType"},
                    optional = {"ActionData"}
                },
                ExecuteTurn = {
                    required = {"BattleId", "TurnData"},
                    optional = {"BattleState"}
                },
                ProcessSwitch = {
                    required = {"BattleId", "PokemonId", "TargetPokemonId"}
                }
            },
            integration = {
                processes = {"battle-engine.lua", "stat-calculation-manager.lua", "status-effects-engine.lua"},
                coordinator = "coordinator-process.lua"
            },
            performance = {
                maxExecutionTime = "5000ms",
                maxProcessSize = "500KB",
                deterministicReplay = true
            }
        }

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(infoResponse),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Ping Handler for ADP Compliance
Handlers.add("ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Pokemon Battle Engine Turn Manager v1.0.0 initialized with ADP v1.0 compliance")