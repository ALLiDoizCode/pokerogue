-- Side Effect Engine Integration Tests
-- Tests complex battle scenarios with multiple effects, battle coordination, and cross-process communication

-- Mock JSON implementation for testing
local json = {}

json.encode = function(obj)
    if type(obj) == "table" then
        return "encoded_json_table"
    else
        return tostring(obj)
    end
end

json.decode = function(str)
    return {}
end

-- Mock AO environment for multi-process testing
if not ao then
    ao = {
        send = function(msg)
            -- Store messages for integration test validation
            if not _G.integrationMessages then
                _G.integrationMessages = {}
            end
            table.insert(_G.integrationMessages, {
                timestamp = os.time(),
                message = msg
            })
            
            _G.lastSentMessage = msg
            if msg.Success then
                _G.lastTestSuccess = (msg.Success == "true")
            end
        end,
        id = "side_effect_process_123"
    }
end

-- Mock Handlers for testing
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            _G["handler_" .. name:gsub("-", "_")] = handler
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg[tag] == value
                end
            end
        }
    }
end

-- Load the side effect engine
dofile("processes/side-effect-engine.lua")

-- Integration test helper functions
local function createBattleMessage(action, tags, data, battleId)
    local msg = {
        From = "battle_coordinator_process",
        Action = action,
        Data = data or "",
        Timestamp = tostring(os.time()),
        BattleId = battleId or "integration_battle_001"
    }
    
    if tags then
        for key, value in pairs(tags) do
            msg[key] = value
        end
    end
    
    return msg
end

local function resetIntegrationEnvironment()
    _G.lastSentMessage = nil
    _G.lastTestSuccess = nil
    _G.integrationMessages = {}
    
    -- Reset side effect state
    _G.SideEffectState = {
        playerSideEffects = {},
        enemySideEffects = {}
    }
end

local function countActiveEffects()
    local playerCount = 0
    local enemyCount = 0
    
    for _ in pairs(_G.SideEffectState.playerSideEffects) do
        playerCount = playerCount + 1
    end
    
    for _ in pairs(_G.SideEffectState.enemySideEffects) do
        enemyCount = enemyCount + 1
    end
    
    return playerCount, enemyCount
end

print("Starting Side Effect Engine Integration Tests...")

-- Integration Test 1: Complex Multi-Effect Battle Setup
print("Integration Test 1: Complex Multi-Effect Battle Setup")
resetIntegrationEnvironment()

local battleId = "complex_battle_001"

-- Player uses Reflect
local playerReflectMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    SourceId = "001",  -- Numeric string for tonumber() compatibility
    SourceMove = "REFLECT",
    IsDoubleBattle = "true",  -- Double battle format
    HasLightClay = "true",    -- Player has Light Clay
}, nil, battleId)

_G.handler_apply_side_effect(playerReflectMsg)
assert(_G.lastTestSuccess == true, "Player Reflect should be applied")

-- Enemy uses Light Screen
local enemyLightScreenMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "LIGHT_SCREEN",
    Side = "ENEMY",
    SourceId = "002", 
    SourceMove = "LIGHT_SCREEN",
    IsDoubleBattle = "true",
    HasLightClay = "false",   -- Enemy doesn't have Light Clay
    BattleId = battleId
})

_G.handler_apply_side_effect(enemyLightScreenMsg)
assert(_G.lastTestSuccess == true, "Enemy Light Screen should be applied")

-- Player uses Safeguard
local playerSafeguardMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "SAFEGUARD",
    Side = "PLAYER",
    SourceId = "003",
    SourceMove = "SAFEGUARD",
    IsDoubleBattle = "true",
    HasLightClay = "false",
    BattleId = battleId
})

_G.handler_apply_side_effect(playerSafeguardMsg)
assert(_G.lastTestSuccess == true, "Player Safeguard should be applied")

-- Enemy uses Mist
local enemyMistMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "MIST",
    Side = "ENEMY",
    SourceId = "004",
    SourceMove = "MIST",
    IsDoubleBattle = "true",
    HasLightClay = "false",
    BattleId = battleId
})

_G.handler_apply_side_effect(enemyMistMsg)
assert(_G.lastTestSuccess == true, "Enemy Mist should be applied")

-- Verify all effects are active
local playerCount, enemyCount = countActiveEffects()
assert(playerCount == 2, "Player should have 2 active effects (Reflect + Safeguard)")
assert(enemyCount == 2, "Enemy should have 2 active effects (Light Screen + Mist)")

-- Verify Light Clay extension only affected player's Reflect
assert(_G.SideEffectState.playerSideEffects.REFLECT.turnsRemaining == 8, "Player Reflect should have 8 turns (Light Clay)")
assert(_G.SideEffectState.enemySideEffects.LIGHT_SCREEN.turnsRemaining == 5, "Enemy Light Screen should have 5 turns (no Light Clay)")

print("✓ Complex multi-effect battle setup test passed")

-- Integration Test 2: Battle Turn Sequence with Multiple Effects
print("Integration Test 2: Battle Turn Sequence with Multiple Effects")
-- Continue from previous battle state

-- Turn 1: Physical attack against player (should be reduced by Reflect)
local physicalAttackMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "PLAYER",
    MoveCategory = "PHYSICAL",
    AttackerHasInfiltrator = "false",
    IsDoubleBattle = "true",
    BattleId = battleId
})

_G.handler_check_side_effect_protection(physicalAttackMsg)
assert(_G.lastTestSuccess == true, "Physical attack protection check should succeed")

-- Turn 1: Special attack against enemy (should be reduced by Light Screen)
local specialAttackMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "ENEMY",
    MoveCategory = "SPECIAL",
    AttackerHasInfiltrator = "false",
    IsDoubleBattle = "true",
    BattleId = battleId
})

_G.handler_check_side_effect_protection(specialAttackMsg)
assert(_G.lastTestSuccess == true, "Special attack protection check should succeed")

-- Turn 1: Status move against player (should be blocked by Safeguard)
local statusAttackMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "PLAYER",
    StatusType = "BURN",
    BattleId = battleId
})

_G.handler_check_side_effect_protection(statusAttackMsg)
assert(_G.lastTestSuccess == true, "Status move protection check should succeed")

-- Turn 1: Stat reduction against enemy (should be blocked by Mist)
local statReductionMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "ENEMY",
    StatType = "ATTACK",
    BattleId = battleId
})

_G.handler_check_side_effect_protection(statReductionMsg)
assert(_G.lastTestSuccess == true, "Stat reduction protection check should succeed")

-- End of turn 1: Decrement all effect durations
local turn1DecrementMsg = createBattleMessage("TurnDecrement", {
    Side = "BOTH",
    BattleId = battleId
})

_G.handler_turn_decrement(turn1DecrementMsg)
assert(_G.lastTestSuccess == true, "Turn 1 decrement should succeed")

-- Verify turn counts after turn 1
assert(_G.SideEffectState.playerSideEffects.REFLECT.turnsRemaining == 7, "Player Reflect should have 7 turns remaining")
assert(_G.SideEffectState.playerSideEffects.SAFEGUARD.turnsRemaining == 4, "Player Safeguard should have 4 turns remaining")
assert(_G.SideEffectState.enemySideEffects.LIGHT_SCREEN.turnsRemaining == 4, "Enemy Light Screen should have 4 turns remaining")
assert(_G.SideEffectState.enemySideEffects.MIST.turnsRemaining == 4, "Enemy Mist should have 4 turns remaining")

print("✓ Battle turn sequence with multiple effects test passed")

-- Integration Test 3: Infiltrator Ability vs Screen Effects
print("Integration Test 3: Infiltrator Ability vs Screen Effects")

-- Physical attack with Infiltrator against player's Reflect
local infiltratorAttackMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "PLAYER",
    MoveCategory = "PHYSICAL",
    AttackerHasInfiltrator = "true",
    IsDoubleBattle = "true", 
    BattleId = battleId
})

_G.handler_check_side_effect_protection(infiltratorAttackMsg)
assert(_G.lastTestSuccess == true, "Infiltrator attack should succeed")

-- Special attack with Infiltrator against enemy's Light Screen
local infiltratorSpecialMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "ENEMY",
    MoveCategory = "SPECIAL",
    AttackerHasInfiltrator = "true",
    IsDoubleBattle = "true",
    BattleId = battleId
})

_G.handler_check_side_effect_protection(infiltratorSpecialMsg)
assert(_G.lastTestSuccess == true, "Infiltrator special attack should succeed")

-- Verify Infiltrator doesn't affect non-screen effects (Safeguard/Mist)
local infiltratorStatusMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "PLAYER",
    StatusType = "POISON",
    BattleId = battleId
})

_G.handler_check_side_effect_protection(infiltratorStatusMsg)
assert(_G.lastTestSuccess == true, "Status protection should still work against Infiltrator")

print("✓ Infiltrator ability vs screen effects test passed")

-- Integration Test 4: Brick Break Move Interaction
print("Integration Test 4: Brick Break Move Interaction")

-- Player uses Brick Break (should remove enemy's Light Screen but not Mist)
local brickBreakMsg = createBattleMessage("RemoveSideEffects", {
    RemovalType = "BRICK_BREAK",
    Side = "ENEMY",
    BattleId = battleId
})

_G.handler_remove_side_effects(brickBreakMsg)
assert(_G.lastTestSuccess == true, "Brick Break should succeed")

-- Verify selective removal
assert(_G.SideEffectState.enemySideEffects.LIGHT_SCREEN == nil, "Enemy Light Screen should be removed")
assert(_G.SideEffectState.enemySideEffects.MIST ~= nil, "Enemy Mist should remain")
assert(_G.SideEffectState.playerSideEffects.REFLECT ~= nil, "Player Reflect should remain (wrong side)")
assert(_G.SideEffectState.playerSideEffects.SAFEGUARD ~= nil, "Player Safeguard should remain")

print("✓ Brick Break move interaction test passed")

-- Integration Test 5: Multi-Turn Effect Expiry
print("Integration Test 5: Multi-Turn Effect Expiry") 

-- Simulate 4 more turns to test expiry patterns
for turn = 2, 5 do
    local turnDecrementMsg = createBattleMessage("TurnDecrement", {
        Side = "BOTH",
        BattleId = battleId .. "_turn_" .. turn
    })
    
    _G.handler_turn_decrement(turnDecrementMsg)
    assert(_G.lastTestSuccess == true, "Turn " .. turn .. " decrement should succeed")
end

-- After 5 turns total, check what should remain:
-- Player Reflect: 8 - 5 = 3 turns remaining
-- Player Safeguard: 5 - 5 = 0 turns (should be expired)
-- Enemy Mist: 5 - 5 = 0 turns (should be expired)

local playerCount, enemyCount = countActiveEffects()
assert(playerCount == 1, "Player should have 1 active effect remaining (only Reflect)")
assert(enemyCount == 0, "Enemy should have 0 active effects remaining")

assert(_G.SideEffectState.playerSideEffects.REFLECT ~= nil, "Player Reflect should still be active")
assert(_G.SideEffectState.playerSideEffects.REFLECT.turnsRemaining == 3, "Player Reflect should have 3 turns remaining")
assert(_G.SideEffectState.playerSideEffects.SAFEGUARD == nil, "Player Safeguard should be expired")

print("✓ Multi-turn effect expiry test passed")

-- Integration Test 6: Defog Complete Field Reset
print("Integration Test 6: Defog Complete Field Reset")

-- Add some new effects first
local newReflectMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "LIGHT_SCREEN", 
    Side = "ENEMY",
    SourceId = "005",
    SourceMove = "LIGHT_SCREEN",
    IsDoubleBattle = "true",
    HasLightClay = "false",
    BattleId = battleId
})

_G.handler_apply_side_effect(newReflectMsg)

-- Now both sides have at least one effect
local playerCountBefore, enemyCountBefore = countActiveEffects()
assert(playerCountBefore > 0, "Player should have effects before Defog")
assert(enemyCountBefore > 0, "Enemy should have effects before Defog")

-- Player uses Defog (should remove all side effects from both sides)
local defogMsg = createBattleMessage("RemoveSideEffects", {
    RemovalType = "DEFOG",
    Side = "BOTH",
    BattleId = battleId
})

_G.handler_remove_side_effects(defogMsg)
assert(_G.lastTestSuccess == true, "Defog should succeed")

-- Verify complete field reset
local playerCountAfter, enemyCountAfter = countActiveEffects()
assert(playerCountAfter == 0, "Player should have no effects after Defog")
assert(enemyCountAfter == 0, "Enemy should have no effects after Defog")

print("✓ Defog complete field reset test passed")

-- Integration Test 7: Effect State Persistence and Retrieval
print("Integration Test 7: Effect State Persistence and Retrieval")
resetIntegrationEnvironment()

-- Set up a complex battle state
local stateTestBattleId = "state_persistence_battle"

-- Apply various effects
local effectsToApply = {
    {effectType = "REFLECT", side = "PLAYER", sourceId = "001", hasLightClay = true},
    {effectType = "SAFEGUARD", side = "PLAYER", sourceId = "002", hasLightClay = false},
    {effectType = "LIGHT_SCREEN", side = "ENEMY", sourceId = "003", hasLightClay = false},
    {effectType = "MIST", side = "ENEMY", sourceId = "004", hasLightClay = false}
}

for _, effect in ipairs(effectsToApply) do
    local applyMsg = createBattleMessage("ApplySideEffect", {
        EffectType = effect.effectType,
        Side = effect.side,
        SourceId = effect.sourceId,
        SourceMove = effect.effectType,
        IsDoubleBattle = "false",
        HasLightClay = tostring(effect.hasLightClay),
        BattleId = stateTestBattleId
    })
    
    _G.handler_apply_side_effect(applyMsg)
    assert(_G.lastTestSuccess == true, "Effect " .. effect.effectType .. " should be applied")
end

-- Retrieve all side effects
local getStateMsg = createBattleMessage("GetSideEffects", {
    BattleId = stateTestBattleId
})

_G.handler_get_side_effects(getStateMsg)
assert(_G.lastTestSuccess == true, "Get side effects should succeed")

-- Retrieve player-specific effects
local getPlayerStateMsg = createBattleMessage("GetSideEffects", {
    Side = "PLAYER",
    BattleId = stateTestBattleId
})

_G.handler_get_side_effects(getPlayerStateMsg)
assert(_G.lastTestSuccess == true, "Get player side effects should succeed")

-- Retrieve enemy-specific effects
local getEnemyStateMsg = createBattleMessage("GetSideEffects", {
    Side = "ENEMY",
    BattleId = stateTestBattleId
})

_G.handler_get_side_effects(getEnemyStateMsg)
assert(_G.lastTestSuccess == true, "Get enemy side effects should succeed")

print("✓ Effect state persistence and retrieval test passed")

-- Integration Test 8: Performance Under Complex Scenarios
print("Integration Test 8: Performance Under Complex Scenarios")

local performanceBattleId = "performance_test_battle"
local startTime = os.clock()

-- Apply 100 rapid effect operations
for i = 1, 50 do
    -- Apply effect
    local applyMsg = createBattleMessage("ApplySideEffect", {
        EffectType = (i % 2 == 0) and "REFLECT" or "LIGHT_SCREEN",
        Side = (i % 2 == 0) and "PLAYER" or "ENEMY",
        SourceId = tostring(i),
        SourceMove = "RAPID_TEST",
        IsDoubleBattle = tostring(i % 2 == 0),
        HasLightClay = tostring(i % 3 == 0),
        BattleId = performanceBattleId .. "_" .. i
    })
    
    _G.handler_apply_side_effect(applyMsg)
    
    -- Check protection
    local checkMsg = createBattleMessage("CheckSideEffectProtection", {
        Side = (i % 2 == 0) and "PLAYER" or "ENEMY",
        MoveCategory = (i % 2 == 0) and "PHYSICAL" or "SPECIAL",
        AttackerHasInfiltrator = tostring(i % 4 == 0),
        IsDoubleBattle = tostring(i % 2 == 0),
        BattleId = performanceBattleId .. "_" .. i
    })
    
    _G.handler_check_side_effect_protection(checkMsg)
end

local endTime = os.clock()
local executionTime = endTime - startTime

assert(executionTime < 1.0, "100 operations should complete in under 1 second")
assert(#_G.integrationMessages >= 100, "Should have processed at least 100 messages from performance test")

print("✓ Performance test passed (100 operations in " .. string.format("%.3f", executionTime) .. " seconds)")

-- Integration Test 9: Error Recovery and Battle Continuity
print("Integration Test 9: Error Recovery and Battle Continuity")
resetIntegrationEnvironment()

local errorBattleId = "error_recovery_battle"

-- Apply a valid effect first
local validMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    SourceId = "100",
    SourceMove = "REFLECT",
    IsDoubleBattle = "false",
    HasLightClay = "false",
    BattleId = errorBattleId
})

_G.handler_apply_side_effect(validMsg)
assert(_G.lastTestSuccess == true, "Valid effect should be applied")

-- Try invalid operations
local invalidEffectMsg = createBattleMessage("ApplySideEffect", {
    EffectType = "INVALID_EFFECT",
    Side = "PLAYER",
    SourceId = "101",
    BattleId = errorBattleId
})

_G.handler_apply_side_effect(invalidEffectMsg)
assert(_G.lastSentMessage.Action == "Error", "Invalid effect should return error")

-- Verify battle state is still intact after error
assert(_G.SideEffectState.playerSideEffects.REFLECT ~= nil, "Valid effect should remain after error")

-- Continue with valid operations
local continueMsg = createBattleMessage("CheckSideEffectProtection", {
    Side = "PLAYER",
    MoveCategory = "PHYSICAL",
    AttackerHasInfiltrator = "false",
    IsDoubleBattle = "false",
    BattleId = errorBattleId
})

_G.handler_check_side_effect_protection(continueMsg)
assert(_G.lastTestSuccess == true, "Battle should continue normally after error")

print("✓ Error recovery and battle continuity test passed")

print("\n🎉 All Side Effect Engine Integration Tests Passed!")
print("Total integration tests: 9") 
print("Coverage: Multi-effect battles, turn sequences, ability interactions, move effects, field resets, state management, performance, and error recovery")
print("Total messages processed: " .. #_G.integrationMessages)