-- JSON module (available in AO environment, mocked for testing)
local json = json or {
    encode = function(obj) 
        return "encoded_json_table" 
    end,
    decode = function(str) 
        return {} 
    end
}

-- Side Effect Engine Process
-- Handles team-based field effects: Reflect, Light Screen, Safeguard, Mist
-- Follows TypeScript parity from arena-tag.ts implementation

-- Initialize side effect state
if not SideEffectState then
    SideEffectState = {
        playerSideEffects = {}, -- Effects on player side
        enemySideEffects = {}   -- Effects on enemy side
    }
end

-- Side effect types
local SIDE_EFFECT_TYPES = {
    REFLECT = "REFLECT",
    LIGHT_SCREEN = "LIGHT_SCREEN", 
    SAFEGUARD = "SAFEGUARD",
    MIST = "MIST"
}

-- Battle sides
local BATTLE_SIDES = {
    PLAYER = "PLAYER",
    ENEMY = "ENEMY"
}

-- Move categories for screen effects
local MOVE_CATEGORIES = {
    PHYSICAL = "PHYSICAL",
    SPECIAL = "SPECIAL"
}

-- Status types protected by Safeguard
local PROTECTED_STATUS_TYPES = {
    "SLEEP", "PARALYSIS", "POISON", "BURN", "FREEZE", "CONFUSION"
}

-- Stat types protected by Mist
local PROTECTED_STAT_TYPES = {
    "ATTACK", "DEFENSE", "SPECIAL_ATTACK", "SPECIAL_DEFENSE", "SPEED", "ACCURACY", "EVASION"
}

-- Helper function to get side effects table
local function getSideEffectsTable(side)
    if side == BATTLE_SIDES.PLAYER then
        return SideEffectState.playerSideEffects
    elseif side == BATTLE_SIDES.ENEMY then
        return SideEffectState.enemySideEffects
    end
    return nil
end

-- Helper function to calculate damage reduction
local function calculateDamageReduction(isDoubleBattle)
    if isDoubleBattle then
        return 2.0 / 3.0  -- 0.667 in double battles
    else
        return 0.5        -- 0.5 in single battles
    end
end

-- Helper function to get effect duration
local function getEffectDuration(hasLightClay)
    if hasLightClay then
        return 8  -- Extended by Light Clay
    else
        return 5  -- Default duration
    end
end

-- Helper function to validate status protection
local function isStatusProtected(statusType)
    for _, protectedStatus in ipairs(PROTECTED_STATUS_TYPES) do
        if statusType == protectedStatus then
            return true
        end
    end
    return false
end

-- Helper function to validate stat protection
local function isStatProtected(statType)
    for _, protectedStat in ipairs(PROTECTED_STAT_TYPES) do
        if statType == protectedStat then
            return true
        end
    end
    return false
end

-- Apply Side Effect Handler
Handlers.add("apply-side-effect",
    Handlers.utils.hasMatchingTag("Action", "ApplySideEffect"),
    function(msg)
        local effectType = msg.EffectType
        local side = msg.Side
        local sourceId = tonumber(msg.SourceId)
        local sourceMove = msg.SourceMove
        local isDoubleBattle = msg.IsDoubleBattle == "true"
        local hasLightClay = msg.HasLightClay == "true"
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Validate input parameters
        if not effectType or not SIDE_EFFECT_TYPES[effectType] then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid or missing EffectType"
            })
            return
        end
        
        if not side or not BATTLE_SIDES[side] then
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = "Invalid or missing Side"
            })
            return
        end
        
        if not sourceId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SourceId required"
            })
            return
        end
        
        -- Get side effects table
        local sideEffects = getSideEffectsTable(side)
        if not sideEffects then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid side specified"
            })
            return
        end
        
        -- Check for existing effect of same type (replacement behavior)
        local overwritten = sideEffects[effectType] ~= nil
        
        -- Create new side effect
        local newEffect = {
            effectType = effectType,
            side = side,
            turnsRemaining = getEffectDuration(hasLightClay),
            sourceId = sourceId,
            sourceMove = sourceMove or effectType,
            isExtended = hasLightClay,
            appliedAt = timestamp
        }
        
        -- Apply the effect (replaces existing effect of same type)
        sideEffects[effectType] = newEffect
        
        -- Calculate damage reduction for screen effects
        local damageReduction = 1.0
        if effectType == SIDE_EFFECT_TYPES.REFLECT or effectType == SIDE_EFFECT_TYPES.LIGHT_SCREEN then
            damageReduction = calculateDamageReduction(isDoubleBattle)
        end
        
        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                sideEffectState = newEffect,
                applicationResult = {
                    applied = true,
                    damageReduction = damageReduction,
                    bypassedReason = "",
                    protected = effectType == SIDE_EFFECT_TYPES.SAFEGUARD or effectType == SIDE_EFFECT_TYPES.MIST,
                    overwritten = overwritten
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp),
            BattleId = battleId or ""
        })
    end
)

-- Check Side Effect Protection Handler
Handlers.add("check-side-effect-protection",
    Handlers.utils.hasMatchingTag("Action", "CheckSideEffectProtection"),
    function(msg)
        local effectType = msg.EffectType
        local side = msg.Side
        local moveCategory = msg.MoveCategory
        local attackerHasInfiltrator = msg.AttackerHasInfiltrator == "true"
        local statusType = msg.StatusType
        local statType = msg.StatType
        local isDoubleBattle = msg.IsDoubleBattle == "true"
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Validate basic parameters
        if not side or not BATTLE_SIDES[side] then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid or missing Side"
            })
            return
        end
        
        -- Get side effects table
        local sideEffects = getSideEffectsTable(side)
        if not sideEffects then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid side specified"
            })
            return
        end
        
        local damageReduction = 1.0
        local bypassedReason = ""
        local protected = false
        
        -- Check specific effect or all effects
        if effectType and SIDE_EFFECT_TYPES[effectType] then
            local effect = sideEffects[effectType]
            if effect and effect.turnsRemaining > 0 then
                -- Screen effects (Reflect/Light Screen)
                if effectType == SIDE_EFFECT_TYPES.REFLECT and moveCategory == MOVE_CATEGORIES.PHYSICAL then
                    if attackerHasInfiltrator then
                        bypassedReason = "Infiltrator ability"
                    else
                        damageReduction = calculateDamageReduction(isDoubleBattle)
                        protected = true
                    end
                elseif effectType == SIDE_EFFECT_TYPES.LIGHT_SCREEN and moveCategory == MOVE_CATEGORIES.SPECIAL then
                    if attackerHasInfiltrator then
                        bypassedReason = "Infiltrator ability"
                    else
                        damageReduction = calculateDamageReduction(isDoubleBattle)
                        protected = true
                    end
                -- Protection effects
                elseif effectType == SIDE_EFFECT_TYPES.SAFEGUARD and statusType then
                    protected = isStatusProtected(statusType)
                elseif effectType == SIDE_EFFECT_TYPES.MIST and statType then
                    protected = isStatProtected(statType)
                end
            end
        else
            -- Check all relevant effects
            -- Screen effects
            local reflectEffect = sideEffects[SIDE_EFFECT_TYPES.REFLECT]
            local lightScreenEffect = sideEffects[SIDE_EFFECT_TYPES.LIGHT_SCREEN]
            
            if moveCategory == MOVE_CATEGORIES.PHYSICAL and reflectEffect and reflectEffect.turnsRemaining > 0 then
                if attackerHasInfiltrator then
                    bypassedReason = "Infiltrator ability"
                else
                    damageReduction = calculateDamageReduction(isDoubleBattle)
                    protected = true
                end
            elseif moveCategory == MOVE_CATEGORIES.SPECIAL and lightScreenEffect and lightScreenEffect.turnsRemaining > 0 then
                if attackerHasInfiltrator then
                    bypassedReason = "Infiltrator ability"
                else
                    damageReduction = calculateDamageReduction(isDoubleBattle)
                    protected = true
                end
            end
            
            -- Protection effects
            local safeguardEffect = sideEffects[SIDE_EFFECT_TYPES.SAFEGUARD]
            local mistEffect = sideEffects[SIDE_EFFECT_TYPES.MIST]
            
            if statusType and safeguardEffect and safeguardEffect.turnsRemaining > 0 then
                protected = protected or isStatusProtected(statusType)
            end
            
            if statType and mistEffect and mistEffect.turnsRemaining > 0 then
                protected = protected or isStatProtected(statType)
            end
        end
        
        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                protectionResult = {
                    protected = protected,
                    damageReduction = damageReduction,
                    bypassedReason = bypassedReason
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp),
            BattleId = battleId or ""
        })
    end
)

-- Remove Side Effects Handler
Handlers.add("remove-side-effects",
    Handlers.utils.hasMatchingTag("Action", "RemoveSideEffects"),
    function(msg)
        local removalType = msg.RemovalType
        local effectTypesStr = msg.EffectTypes or ""
        local side = msg.Side
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Parse effect types to remove
        local effectTypesToRemove = {}
        if effectTypesStr ~= "" then
            for effectType in effectTypesStr:gmatch("[^,]+") do
                effectType = effectType:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
                if SIDE_EFFECT_TYPES[effectType] then
                    table.insert(effectTypesToRemove, effectType)
                end
            end
        end
        
        local removedEffects = {}
        
        -- Handle different removal types
        if removalType == "BRICK_BREAK" or removalType == "PSYCHIC_FANGS" then
            -- Only removes screen effects
            local screenEffects = {SIDE_EFFECT_TYPES.REFLECT, SIDE_EFFECT_TYPES.LIGHT_SCREEN}
            local sidesToProcess = {}
            
            if side == "BOTH" then
                sidesToProcess = {BATTLE_SIDES.PLAYER, BATTLE_SIDES.ENEMY}
            elseif BATTLE_SIDES[side] then
                table.insert(sidesToProcess, side)
            end
            
            for _, processSide in ipairs(sidesToProcess) do
                local sideEffects = getSideEffectsTable(processSide)
                if sideEffects then
                    for _, effectType in ipairs(screenEffects) do
                        if sideEffects[effectType] then
                            table.insert(removedEffects, {
                                side = processSide,
                                effectType = effectType,
                                effect = sideEffects[effectType]
                            })
                            sideEffects[effectType] = nil
                        end
                    end
                end
            end
            
        elseif removalType == "DEFOG" then
            -- Removes all side effects
            local sidesToProcess = {}
            
            if side == "BOTH" then
                sidesToProcess = {BATTLE_SIDES.PLAYER, BATTLE_SIDES.ENEMY}
            elseif BATTLE_SIDES[side] then
                table.insert(sidesToProcess, side)
            end
            
            for _, processSide in ipairs(sidesToProcess) do
                local sideEffects = getSideEffectsTable(processSide)
                if sideEffects then
                    for effectType, effect in pairs(sideEffects) do
                        table.insert(removedEffects, {
                            side = processSide,
                            effectType = effectType,
                            effect = effect
                        })
                    end
                    -- Clear all effects
                    if processSide == BATTLE_SIDES.PLAYER then
                        SideEffectState.playerSideEffects = {}
                    else
                        SideEffectState.enemySideEffects = {}
                    end
                end
            end
            
        elseif removalType == "TURN_EXPIRY" then
            -- Remove effects that have expired (turnsRemaining <= 0)
            local sidesToProcess = {}
            
            if side == "BOTH" then
                sidesToProcess = {BATTLE_SIDES.PLAYER, BATTLE_SIDES.ENEMY}
            elseif BATTLE_SIDES[side] then
                table.insert(sidesToProcess, side)
            else
                -- Process all sides if no specific side given
                sidesToProcess = {BATTLE_SIDES.PLAYER, BATTLE_SIDES.ENEMY}
            end
            
            for _, processSide in ipairs(sidesToProcess) do
                local sideEffects = getSideEffectsTable(processSide)
                if sideEffects then
                    for effectType, effect in pairs(sideEffects) do
                        if effect.turnsRemaining <= 0 then
                            table.insert(removedEffects, {
                                side = processSide,
                                effectType = effectType,
                                effect = effect
                            })
                            sideEffects[effectType] = nil
                        end
                    end
                end
            end
        end
        
        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                removalResult = {
                    removalType = removalType,
                    removedEffects = removedEffects,
                    effectsRemoved = #removedEffects
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp),
            BattleId = battleId or ""
        })
    end
)

-- Turn Decrement Handler
Handlers.add("turn-decrement",
    Handlers.utils.hasMatchingTag("Action", "TurnDecrement"),
    function(msg)
        local side = msg.Side
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        local sidesToProcess = {}
        if side == "BOTH" then
            sidesToProcess = {BATTLE_SIDES.PLAYER, BATTLE_SIDES.ENEMY}
        elseif BATTLE_SIDES[side] then
            table.insert(sidesToProcess, side)
        else
            -- Process all sides if no specific side given
            sidesToProcess = {BATTLE_SIDES.PLAYER, BATTLE_SIDES.ENEMY}
        end
        
        local updatedEffects = {}
        local expiredEffects = {}
        
        -- Decrement turn counters for all effects
        for _, processSide in ipairs(sidesToProcess) do
            local sideEffects = getSideEffectsTable(processSide)
            if sideEffects then
                for effectType, effect in pairs(sideEffects) do
                    effect.turnsRemaining = effect.turnsRemaining - 1
                    
                    if effect.turnsRemaining <= 0 then
                        table.insert(expiredEffects, {
                            side = processSide,
                            effectType = effectType,
                            effect = effect
                        })
                        sideEffects[effectType] = nil
                    else
                        table.insert(updatedEffects, {
                            side = processSide,
                            effectType = effectType,
                            effect = effect
                        })
                    end
                end
            end
        end
        
        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                turnDecrementResult = {
                    updatedEffects = updatedEffects,
                    expiredEffects = expiredEffects,
                    effectsUpdated = #updatedEffects,
                    effectsExpired = #expiredEffects
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp),
            BattleId = battleId or ""
        })
    end
)

-- Get Side Effects Handler  
Handlers.add("get-side-effects",
    Handlers.utils.hasMatchingTag("Action", "GetSideEffects"),
    function(msg)
        local side = msg.Side
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        local result = {}
        
        if side and BATTLE_SIDES[side] then
            -- Get effects for specific side
            local sideEffects = getSideEffectsTable(side)
            if sideEffects then
                result[side:lower()] = sideEffects
            end
        else
            -- Get effects for all sides
            result.player = SideEffectState.playerSideEffects
            result.enemy = SideEffectState.enemySideEffects
        end
        
        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState", 
            Data = json.encode({
                sideEffectsState = result
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp),
            BattleId = battleId or ""
        })
    end
)

-- ADP v1.0 Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Side Effect Engine",
            Description = "Pokemon battle side effect engine handling team-based field effects including Reflect, Light Screen, Safeguard, and Mist with precise TypeScript parity",
            Owner = Owner or (ao.env and ao.env.Process and ao.env.Process.Owner) or "test_owner",
            ProcessId = ao.id,
            adpVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
                {
                    action = "ApplySideEffect",
                    pattern = {"Action"},
                    description = "Apply new side effect to specified battle side",
                    category = "core",
                    parameters = {
                        {
                            name = "EffectType",
                            type = "string",
                            required = true,
                            description = "Effect type: REFLECT, LIGHT_SCREEN, SAFEGUARD, MIST"
                        },
                        {
                            name = "Side", 
                            type = "string",
                            required = true,
                            description = "Battle side: PLAYER or ENEMY"
                        },
                        {
                            name = "SourceId",
                            type = "string",
                            required = true, 
                            description = "Pokemon ID that created the effect"
                        },
                        {
                            name = "SourceMove",
                            type = "string",
                            required = false,
                            description = "Move that created the effect"
                        },
                        {
                            name = "IsDoubleBattle",
                            type = "string",
                            required = false,
                            description = "Battle format affects damage reduction (true/false)"
                        },
                        {
                            name = "HasLightClay",
                            type = "string", 
                            required = false,
                            description = "Item extends duration (true/false)"
                        }
                    }
                },
                {
                    action = "CheckSideEffectProtection",
                    pattern = {"Action"},
                    description = "Check damage reduction or status/stat protection from side effects",
                    category = "core",
                    parameters = {
                        {
                            name = "Side",
                            type = "string",
                            required = true,
                            description = "Battle side to check: PLAYER or ENEMY"
                        },
                        {
                            name = "EffectType",
                            type = "string",
                            required = false,
                            description = "Specific effect to check or empty for all"
                        },
                        {
                            name = "MoveCategory",
                            type = "string",
                            required = false,
                            description = "Move category: PHYSICAL or SPECIAL"
                        },
                        {
                            name = "AttackerHasInfiltrator", 
                            type = "string",
                            required = false,
                            description = "Infiltrator ability bypass (true/false)"
                        },
                        {
                            name = "StatusType",
                            type = "string",
                            required = false,
                            description = "Status type for Safeguard protection check"
                        },
                        {
                            name = "StatType",
                            type = "string", 
                            required = false,
                            description = "Stat type for Mist protection check"
                        }
                    }
                },
                {
                    action = "RemoveSideEffects",
                    pattern = {"Action"},
                    description = "Remove side effects via moves or expiry",
                    category = "core",
                    parameters = {
                        {
                            name = "RemovalType",
                            type = "string",
                            required = true,
                            description = "Removal type: BRICK_BREAK, PSYCHIC_FANGS, DEFOG, TURN_EXPIRY"
                        },
                        {
                            name = "Side",
                            type = "string",
                            required = false,
                            description = "Side to remove from: PLAYER, ENEMY, or BOTH"
                        },
                        {
                            name = "EffectTypes",
                            type = "string",
                            required = false,
                            description = "Comma-separated effect types to remove"
                        }
                    }
                },
                {
                    action = "TurnDecrement",
                    pattern = {"Action"},
                    description = "Decrement turn counters and expire effects",
                    category = "core",
                    parameters = {
                        {
                            name = "Side",
                            type = "string",
                            required = false,
                            description = "Side to process: PLAYER, ENEMY, or BOTH"
                        }
                    }
                },
                {
                    action = "GetSideEffects",
                    pattern = {"Action"},
                    description = "Get current side effect state",
                    category = "utility",
                    parameters = {
                        {
                            name = "Side",
                            type = "string",
                            required = false,
                            description = "Specific side or empty for all sides"
                        }
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get process information and handler documentation",
                    category = "core"
                }
            },
            capabilities = {
                screenEffects = true,
                protectionEffects = true,
                turnBasedDuration = true,
                infiltratorBypass = true,
                lightClayExtension = true,
                doubleBattleSupport = true,
                effectStacking = true,
                removalMechanics = true
            },
            messageSchemas = {
                ApplySideEffect = {
                    required = {"Action", "EffectType", "Side", "SourceId"}
                },
                CheckSideEffectProtection = {
                    required = {"Action", "Side"}
                },
                RemoveSideEffects = {
                    required = {"Action", "RemovalType"}
                },
                TurnDecrement = {
                    required = {"Action"}
                },
                GetSideEffects = {
                    required = {"Action"}
                }
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(infoResponse),
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
            Data = "pong"
        })
    end
)

print("Side Effect Engine Process initialized with ADP v1.0 compliance")