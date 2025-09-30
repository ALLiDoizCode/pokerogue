-- Positional Battle Mechanics Process
-- Handles battlefield positioning effects including delayed attacks (Future Sight, Doom Desire)
-- and position-based healing (Wish) with precise TypeScript behavioral parity

local json = json

-- Positional Battle State Management
PositionalTags = PositionalTags or {}
BattlefieldPositions = BattlefieldPositions or {}
BattleState = BattleState or {}

-- BattlerIndex enumeration (matches TypeScript)
local BATTLER_INDEX = {
    ATTACKER = -1,  -- Special value for self-targeting
    PLAYER = 0,     -- Player's Pokemon (position 0)
    PLAYER_2 = 1,   -- Player's second Pokemon in double battles (position 1)
    ENEMY = 2,      -- Enemy Pokemon (position 2)
    ENEMY_2 = 3     -- Enemy second Pokemon in double battles (position 3)
}

-- Positional tag types enumeration
local TAG_TYPES = {
    DELAYED_ATTACK = "DELAYED_ATTACK",
    WISH = "WISH"
}

-- Delayed attack move types
local DELAYED_ATTACK_MOVES = {
    FUTURE_SIGHT = "FUTURE_SIGHT",
    DOOM_DESIRE = "DOOM_DESIRE"
}

-- Range types for position targeting
local RANGE_TYPES = {
    ADJACENT = "ADJACENT",
    ALL = "ALL", 
    OPPOSITE = "OPPOSITE",
    SINGLE = "SINGLE"
}

-- Utility function to validate BattlerIndex
local function isValidBattlerIndex(index)
    local indexNum = tonumber(index)
    return indexNum == BATTLER_INDEX.ATTACKER or 
           (indexNum >= BATTLER_INDEX.PLAYER and indexNum <= BATTLER_INDEX.ENEMY_2)
end

-- Utility function to validate tag type
local function isValidTagType(tagType)
    return TAG_TYPES[tagType] ~= nil
end

-- Utility function to validate delayed attack move
local function isValidDelayedAttackMove(moveId)
    return DELAYED_ATTACK_MOVES[moveId] ~= nil
end

-- Get battle-specific positional tags
local function getBattlePositionalTags(battleId)
    if not PositionalTags[battleId] then
        PositionalTags[battleId] = {}
    end
    return PositionalTags[battleId]
end

-- Get battle-specific battlefield positions
local function getBattlefieldPositions(battleId)
    if not BattlefieldPositions[battleId] then
        BattlefieldPositions[battleId] = {
            [BATTLER_INDEX.PLAYER] = nil,
            [BATTLER_INDEX.PLAYER_2] = nil,
            [BATTLER_INDEX.ENEMY] = nil,
            [BATTLER_INDEX.ENEMY_2] = nil
        }
    end
    return BattlefieldPositions[battleId]
end

-- Validate position has active Pokemon
local function hasValidPokemonAtPosition(battlefieldPositions, targetIndex)
    local pokemon = battlefieldPositions[targetIndex]
    return pokemon ~= nil and pokemon.hp > 0 and not pokemon.fainted
end

-- Generate unique tag ID
local function generateTagId(battleId, tagType, targetIndex)
    local timestamp = tostring((msg.Timestamp or 0))
    return battleId .. "_" .. tagType .. "_" .. targetIndex .. "_" .. timestamp
end

-- Check if position already has tag of same type (for non-stacking tags)
local function hasTagAtPosition(battleTags, tagType, targetIndex)
    for _, tag in pairs(battleTags) do
        if tag.tagType == tagType and tag.targetIndex == targetIndex then
            return true
        end
    end
    return false
end

-- Calculate adjacent positions for targeting
local function getAdjacentPositions(sourceIndex, isDoubleBattle)
    local adjacents = {}
    
    if not isDoubleBattle then
        -- Single battle: only opposite position is "adjacent"
        if sourceIndex == BATTLER_INDEX.PLAYER then
            adjacents[#adjacents + 1] = BATTLER_INDEX.ENEMY
        elseif sourceIndex == BATTLER_INDEX.ENEMY then
            adjacents[#adjacents + 1] = BATTLER_INDEX.PLAYER
        end
    else
        -- Double battle: adjacent based on position proximity
        if sourceIndex == BATTLER_INDEX.PLAYER then
            adjacents[#adjacents + 1] = BATTLER_INDEX.PLAYER_2
            adjacents[#adjacents + 1] = BATTLER_INDEX.ENEMY
        elseif sourceIndex == BATTLER_INDEX.PLAYER_2 then
            adjacents[#adjacents + 1] = BATTLER_INDEX.PLAYER
            adjacents[#adjacents + 1] = BATTLER_INDEX.ENEMY_2
        elseif sourceIndex == BATTLER_INDEX.ENEMY then
            adjacents[#adjacents + 1] = BATTLER_INDEX.ENEMY_2
            adjacents[#adjacents + 1] = BATTLER_INDEX.PLAYER
        elseif sourceIndex == BATTLER_INDEX.ENEMY_2 then
            adjacents[#adjacents + 1] = BATTLER_INDEX.ENEMY
            adjacents[#adjacents + 1] = BATTLER_INDEX.PLAYER_2
        end
    end
    
    return adjacents
end

-- Get all valid target positions based on range type
local function getValidTargetPositions(sourceIndex, rangeType, isDoubleBattle, battlefieldPositions)
    local validTargets = {}
    
    if rangeType == RANGE_TYPES.SINGLE then
        -- Single target - validate specific target
        return validTargets
    elseif rangeType == RANGE_TYPES.ADJACENT then
        validTargets = getAdjacentPositions(sourceIndex, isDoubleBattle)
    elseif rangeType == RANGE_TYPES.OPPOSITE then
        -- Opposite side positions
        if sourceIndex <= BATTLER_INDEX.PLAYER_2 then
            -- Player side, target enemy side
            validTargets[#validTargets + 1] = BATTLER_INDEX.ENEMY
            if isDoubleBattle then
                validTargets[#validTargets + 1] = BATTLER_INDEX.ENEMY_2
            end
        else
            -- Enemy side, target player side
            validTargets[#validTargets + 1] = BATTLER_INDEX.PLAYER
            if isDoubleBattle then
                validTargets[#validTargets + 1] = BATTLER_INDEX.PLAYER_2
            end
        end
    elseif rangeType == RANGE_TYPES.ALL then
        -- All positions except self
        for i = BATTLER_INDEX.PLAYER, BATTLER_INDEX.ENEMY_2 do
            if i ~= sourceIndex then
                validTargets[#validTargets + 1] = i
            end
        end
    end
    
    -- Filter to only include positions with valid Pokemon
    local filteredTargets = {}
    for _, targetIndex in ipairs(validTargets) do
        if hasValidPokemonAtPosition(battlefieldPositions, targetIndex) then
            filteredTargets[#filteredTargets + 1] = targetIndex
        end
    end
    
    return filteredTargets
end

-- Apply positional effect to battlefield
local function applyPositionalEffect(battleId, tagType, targetIndex, turnsRemaining, parameters)
    local battleTags = getBattlePositionalTags(battleId)
    local battlefieldPositions = getBattlefieldPositions(battleId)
    
    -- Validate target position
    if not isValidBattlerIndex(targetIndex) then
        return {
            applied = false,
            error = "Invalid target index: " .. tostring(targetIndex)
        }
    end
    
    -- Check if target position has valid Pokemon (for immediate validation)
    local targetHasValidPokemon = hasValidPokemonAtPosition(battlefieldPositions, targetIndex)
    
    -- For DELAYED_ATTACK, we allow targeting empty positions (Pokemon may switch in)
    -- For WISH, we require a valid Pokemon at time of application
    if tagType == TAG_TYPES.WISH and not targetHasValidPokemon then
        return {
            applied = false,
            error = "No valid Pokemon at target position for Wish"
        }
    end
    
    -- Check if position already has tag of same type (non-stacking)
    if hasTagAtPosition(battleTags, tagType, targetIndex) then
        return {
            applied = false,
            error = "Position already has active " .. tagType .. " tag"
        }
    end
    
    -- Create new positional tag
    local tagId = generateTagId(battleId, tagType, targetIndex)
    local tag = {
        tagId = tagId,
        tagType = tagType,
        targetIndex = targetIndex,
        turnsRemaining = turnsRemaining,
        parameters = parameters or {},
        createdTurn = parameters.currentTurn or 0
    }
    
    -- Add tag-specific data
    if tagType == TAG_TYPES.DELAYED_ATTACK then
        tag.sourceId = parameters.sourceId
        tag.sourceMove = parameters.sourceMove
        tag.damage = parameters.damage or 0
    elseif tagType == TAG_TYPES.WISH then
        tag.healHp = parameters.healHp
        tag.pokemonName = parameters.pokemonName
    end
    
    battleTags[tagId] = tag
    
    return {
        applied = true,
        tagId = tagId,
        targetPosition = targetIndex,
        activationTurn = (parameters.currentTurn or 0) + turnsRemaining,
        effectType = tagType,
        canStack = false,
        validTarget = targetHasValidPokemon
    }
end

-- Process turn effects for all positional tags
local function processPositionalTurnEffects(battleId, currentTurn)
    local battleTags = getBattlePositionalTags(battleId)
    local battlefieldPositions = getBattlefieldPositions(battleId)
    local activatedTags = {}
    local expiredTags = {}
    
    -- Process tags in creation order (not current speed order)
    local sortedTags = {}
    for tagId, tag in pairs(battleTags) do
        sortedTags[#sortedTags + 1] = {tagId = tagId, tag = tag}
    end
    
    -- Sort by creation turn and tag ID for consistent ordering
    table.sort(sortedTags, function(a, b)
        if a.tag.createdTurn == b.tag.createdTurn then
            return a.tagId < b.tagId
        end
        return a.tag.createdTurn < b.tag.createdTurn
    end)
    
    -- Process each tag
    for _, entry in ipairs(sortedTags) do
        local tagId = entry.tagId
        local tag = entry.tag
        
        -- Decrement turn counter
        tag.turnsRemaining = tag.turnsRemaining - 1
        
        -- Check if tag should activate
        if tag.turnsRemaining <= 0 then
            -- Validate target still exists
            local targetHasValidPokemon = hasValidPokemonAtPosition(battlefieldPositions, tag.targetIndex)
            
            if targetHasValidPokemon then
                -- Tag activates
                activatedTags[#activatedTags + 1] = {
                    tagId = tagId,
                    tag = tag,
                    effect = processTagActivation(tag, battlefieldPositions[tag.targetIndex])
                }
            else
                -- Tag expires without activation
                expiredTags[#expiredTags + 1] = {
                    tagId = tagId,
                    tag = tag,
                    reason = "No valid target Pokemon"
                }
            end
            
            -- Remove tag from active tags
            battleTags[tagId] = nil
        end
    end
    
    return {
        activatedTags = activatedTags,
        expiredTags = expiredTags,
        remainingTags = battleTags
    }
end

-- Process individual tag activation
local function processTagActivation(tag, targetPokemon)
    if tag.tagType == TAG_TYPES.DELAYED_ATTACK then
        -- Calculate and apply delayed attack damage
        local damage = tag.damage or 0
        local newHp = math.max(0, targetPokemon.hp - damage)
        
        return {
            effectType = "DAMAGE",
            damage = damage,
            newHp = newHp,
            moveId = tag.sourceMove,
            sourceId = tag.sourceId
        }
    elseif tag.tagType == TAG_TYPES.WISH then
        -- Calculate and apply Wish healing
        local healAmount = math.min(tag.healHp, targetPokemon.maxHp - targetPokemon.hp)
        local newHp = targetPokemon.hp + healAmount
        
        return {
            effectType = "HEAL",
            healAmount = healAmount,
            newHp = newHp,
            pokemonName = tag.pokemonName
        }
    end
    
    return {
        effectType = "UNKNOWN",
        error = "Unknown tag type: " .. tostring(tag.tagType)
    }
end

-- Update battlefield positions
local function updateBattlefieldPositions(battleId, positionData)
    local battlefieldPositions = getBattlefieldPositions(battleId)
    
    -- Update each position with new Pokemon data
    for positionStr, pokemonData in pairs(positionData) do
        local position = tonumber(positionStr)
        if isValidBattlerIndex(position) then
            battlefieldPositions[position] = pokemonData
        end
    end
    
    return battlefieldPositions
end

-- Validate position targeting for moves
local function validatePositionTargeting(sourceIndex, targetIndices, moveId, rangeType, battlefieldPositions, isDoubleBattle)
    local results = {
        validTargets = {},
        invalidTargets = {},
        rangeValid = true,
        moveTargeting = {
            moveId = moveId,
            rangeType = rangeType,
            sourceIndex = sourceIndex,
            isDoubleBattle = isDoubleBattle
        }
    }
    
    -- Parse target indices
    local targets = {}
    if type(targetIndices) == "string" then
        for indexStr in targetIndices:gmatch("[^,]+") do
            local index = tonumber(indexStr)
            if index then
                targets[#targets + 1] = index
            end
        end
    elseif type(targetIndices) == "number" then
        targets[#targets + 1] = targetIndices
    end
    
    -- Get valid targets based on range type
    local validRangeTargets = getValidTargetPositions(sourceIndex, rangeType, isDoubleBattle, battlefieldPositions)
    
    -- Validate each target
    for _, targetIndex in ipairs(targets) do
        local isValidRange = false
        for _, validIndex in ipairs(validRangeTargets) do
            if targetIndex == validIndex then
                isValidRange = true
                break
            end
        end
        
        if isValidRange and hasValidPokemonAtPosition(battlefieldPositions, targetIndex) then
            results.validTargets[#results.validTargets + 1] = targetIndex
        else
            results.invalidTargets[#results.invalidTargets + 1] = {
                index = targetIndex,
                reason = isValidRange and "No valid Pokemon at position" or "Out of range"
            }
        end
    end
    
    results.rangeValid = #results.invalidTargets == 0
    
    return results
end

-- Clean up expired battle data
local function cleanupBattleData(battleId)
    PositionalTags[battleId] = nil
    BattlefieldPositions[battleId] = nil
    BattleState[battleId] = nil
end

-- Handler: Apply Positional Effect
Handlers.add("apply-positional-effect",
    Handlers.utils.hasMatchingTag("Action", "ApplyPositionalEffect"),
    function(msg)
        local tagType = msg.TagType
        local targetIndex = tonumber(msg.TargetIndex)
        local turnsRemaining = tonumber(msg.TurnsRemaining) or 2
        local battleId = msg.BattleId
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BattleId required",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        if not isValidTagType(tagType) then
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = "Invalid tag type: " .. tostring(tagType),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        if not isValidBattlerIndex(targetIndex) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid target index: " .. tostring(targetIndex),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Parse parameters
        local parameters = {}
        if msg.Parameters and msg.Parameters ~= "" then
            parameters = json.decode(msg.Parameters)
        end
        
        -- Add message data to parameters
        parameters.sourceId = tonumber(msg.SourceId)
        parameters.sourceMove = msg.SourceMove
        parameters.currentTurn = tonumber(msg.Timestamp or 0)
        
        -- Apply the positional effect
        local result = applyPositionalEffect(battleId, tagType, targetIndex, turnsRemaining, parameters)
        
        if result.applied then
            local battleTags = getBattlePositionalTags(battleId)
            local battlefieldPositions = getBattlefieldPositions(battleId)
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    positionalMechanicState = {
                        tagType = tagType,
                        targetIndex = targetIndex,
                        turnsRemaining = turnsRemaining,
                        sourceId = parameters.sourceId,
                        sourceMove = parameters.sourceMove,
                        parameters = parameters
                    },
                    mechanicResult = result,
                    activeTags = battleTags,
                    positionStates = battlefieldPositions
                }),
                Success = "true",
                TagId = result.tagId,
                TargetPosition = tostring(result.targetPosition),
                ActivationTurn = tostring(result.activationTurn),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Check Positional Targeting
Handlers.add("check-positional-targeting",
    Handlers.utils.hasMatchingTag("Action", "CheckPositionalTargeting"),
    function(msg)
        local sourceIndex = tonumber(msg.SourceIndex)
        local targetIndices = msg.TargetIndices
        local moveId = msg.MoveId
        local rangeType = msg.RangeType or RANGE_TYPES.SINGLE
        local battleId = msg.BattleId
        local isDoubleBattle = msg.IsDoubleBattle == "true"
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BattleId required",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        if not isValidBattlerIndex(sourceIndex) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid source index: " .. tostring(sourceIndex),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        local battlefieldPositions = getBattlefieldPositions(battleId)
        local validation = validatePositionTargeting(sourceIndex, targetIndices, moveId, rangeType, battlefieldPositions, isDoubleBattle)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                targetingValidation = validation,
                battlefieldPositions = battlefieldPositions
            }),
            Success = "true",
            ValidTargets = json.encode(validation.validTargets),
            InvalidTargets = json.encode(validation.invalidTargets),
            RangeValid = tostring(validation.rangeValid),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Process Positional Turn Effects  
Handlers.add("process-positional-turn-effects",
    Handlers.utils.hasMatchingTag("Action", "ProcessPositionalTurnEffects"),
    function(msg)
        local battleId = msg.BattleId
        local currentTurn = tonumber(msg.CurrentTurn) or 0
        local turnPhase = msg.TurnPhase or "START"
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BattleId required",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Process turn effects
        local results = processPositionalTurnEffects(battleId, currentTurn)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState", 
            Data = json.encode({
                turnEffects = results,
                currentTurn = currentTurn,
                turnPhase = turnPhase,
                activeTags = results.remainingTags
            }),
            Success = "true",
            ActivatedTags = tostring(#results.activatedTags),
            ExpiredTags = tostring(#results.expiredTags),
            RemainingTags = tostring(#results.remainingTags or 0),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Update Battlefield Positions
Handlers.add("update-battlefield-positions", 
    Handlers.utils.hasMatchingTag("Action", "UpdateBattlefieldPositions"),
    function(msg)
        local battleId = msg.BattleId
        local positionData = {}
        local switchEvents = {}
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BattleId required",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Parse position data
        if msg.PositionData and msg.PositionData ~= "" then
            positionData = json.decode(msg.PositionData)
        end
        
        -- Parse switch events
        if msg.SwitchEvents and msg.SwitchEvents ~= "" then
            switchEvents = json.decode(msg.SwitchEvents)
        end
        
        -- Update battlefield positions
        local updatedPositions = updateBattlefieldPositions(battleId, positionData)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                battlefieldPositions = updatedPositions,
                switchEvents = switchEvents,
                positionUpdate = {
                    battleId = battleId,
                    timestamp = msg.Timestamp
                }
            }),
            Success = "true",
            UpdatedPositions = tostring(#positionData),
            SwitchEvents = tostring(#switchEvents),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Health Check
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        local activeBattles = 0
        local totalTags = 0
        
        for battleId, tags in pairs(PositionalTags) do
            activeBattles = activeBattles + 1
            for _ in pairs(tags) do
                totalTags = totalTags + 1
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                processHealth = {
                    status = "healthy",
                    activeBattles = activeBattles,
                    totalActiveTags = totalTags,
                    memoryUsage = "low"
                }
            }),
            Success = "true",
            ActiveBattles = tostring(activeBattles),
            TotalTags = tostring(totalTags),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Cleanup Battle Data
Handlers.add("cleanup-battle-data",
    Handlers.utils.hasMatchingTag("Action", "CleanupBattleData"),
    function(msg)
        local battleId = msg.BattleId
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = "BattleId required",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        cleanupBattleData(battleId)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                cleanup = {
                    battleId = battleId,
                    cleaned = true
                }
            }),
            Success = "true",
            BattleId = battleId,
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Info (ADP v1.0 compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Positional Battle Mechanics Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "ApplyPositionalEffect",
                        "CheckPositionalTargeting", 
                        "ProcessPositionalTurnEffects",
                        "UpdateBattlefieldPositions"
                    },
                    messageSchemas = {
                        ApplyPositionalEffect = {
                            required = {"Action", "TagType", "TargetIndex", "BattleId"},
                            optional = {"TurnsRemaining", "SourceId", "SourceMove", "Parameters"}
                        },
                        CheckPositionalTargeting = {
                            required = {"Action", "SourceIndex", "TargetIndices", "MoveId", "BattleId"},
                            optional = {"RangeType", "IsDoubleBattle"}
                        },
                        ProcessPositionalTurnEffects = {
                            required = {"Action", "BattleId"},
                            optional = {"CurrentTurn", "TurnPhase"}
                        },
                        UpdateBattlefieldPositions = {
                            required = {"Action", "BattleId"},
                            optional = {"PositionData", "SwitchEvents"}
                        }
                    }
                },
                handlers = {
                    "ApplyPositionalEffect",
                    "CheckPositionalTargeting",
                    "ProcessPositionalTurnEffects", 
                    "UpdateBattlefieldPositions",
                    "HealthCheck",
                    "CleanupBattleData",
                    "Info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Handles battlefield positioning effects including delayed attacks and position-based healing with precise TypeScript behavioral parity"
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Positional Battle Mechanics Engine initialized successfully")