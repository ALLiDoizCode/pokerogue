-- Unit Tests for Side Effect Engine
-- Tests screen effects, protection mechanics, duration tracking, and removal systems

-- Mock JSON implementation for testing
local json = {}

json.encode = function(obj)
    -- Simple JSON encoder for testing
    if type(obj) == "table" then
        return "encoded_json_table"
    else
        return tostring(obj)
    end
end

json.decode = function(str)
    -- Return empty table for testing - we'll test behavior via state changes
    return {}
end

-- Mock AO environment for testing
if not ao then
    ao = {
        send = function(msg) 
            -- Store last sent message for test assertions
            _G.lastSentMessage = msg
            
            -- Store success status for validation
            if msg.Success then
                _G.lastTestSuccess = (msg.Success == "true")
            end
        end,
        id = "test_side_effect_process_id"
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

-- Test helper functions
local function createTestMessage(action, tags, data)
    local msg = {
        From = "test_sender",
        Action = action,
        Data = data or "",
        Timestamp = "1234567890"
    }
    
    -- Add tag fields directly to message
    if tags then
        for key, value in pairs(tags) do
            msg[key] = value
        end
    end
    
    return msg
end

local function resetTestEnvironment()
    _G.lastSentMessage = nil
    _G.lastTestSuccess = nil
    -- Reset side effect state
    _G.SideEffectState = {
        playerSideEffects = {},
        enemySideEffects = {}
    }
end

print("Starting Side Effect Engine Unit Tests...")

-- Test 1: Apply Reflect (Screen Effect)
print("Test 1: Apply Reflect to Player Side")
resetTestEnvironment()

local reflectMsg = createTestMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "PLAYER", 
    SourceId = "123",
    SourceMove = "REFLECT",
    IsDoubleBattle = "false",
    HasLightClay = "false",
    BattleId = "battle_001"
})

_G.handler_apply_side_effect(reflectMsg)

assert(_G.lastSentMessage, "Should send a response message")
assert(_G.lastSentMessage.Action == "SaveState", "Should send SaveState action")
assert(_G.lastTestSuccess == true, "Should be successful")

-- Verify state was updated
assert(_G.SideEffectState.playerSideEffects.REFLECT, "Reflect should be applied to player side")
assert(_G.SideEffectState.playerSideEffects.REFLECT.effectType == "REFLECT", "Effect type should be REFLECT")
assert(_G.SideEffectState.playerSideEffects.REFLECT.side == "PLAYER", "Side should be PLAYER")
assert(_G.SideEffectState.playerSideEffects.REFLECT.turnsRemaining == 5, "Default turns should be 5")
assert(_G.SideEffectState.playerSideEffects.REFLECT.sourceId == 123, "Source ID should match")

print("✓ Reflect application test passed")

-- Test 2: Apply Light Screen with Light Clay Extension
print("Test 2: Apply Light Screen with Light Clay Extension")
resetTestEnvironment()

local lightScreenMsg = createTestMessage("ApplySideEffect", {
    EffectType = "LIGHT_SCREEN",
    Side = "ENEMY",
    SourceId = "456", 
    SourceMove = "LIGHT_SCREEN",
    IsDoubleBattle = "true",
    HasLightClay = "true",
    BattleId = "battle_002"
})

_G.handler_apply_side_effect(lightScreenMsg)

assert(_G.lastTestSuccess == true, "Should be successful")

-- Verify Light Clay extension
assert(_G.SideEffectState.enemySideEffects.LIGHT_SCREEN, "Light Screen should be applied to enemy side")
assert(_G.SideEffectState.enemySideEffects.LIGHT_SCREEN.turnsRemaining == 8, "Light Clay should extend to 8 turns")
assert(_G.SideEffectState.enemySideEffects.LIGHT_SCREEN.isExtended == true, "Should be marked as extended")

print("✓ Light Screen with Light Clay test passed")

-- Test 3: Apply Safeguard (Protection Effect)
print("Test 3: Apply Safeguard Protection Effect")
resetTestEnvironment()

local safeguardMsg = createTestMessage("ApplySideEffect", {
    EffectType = "SAFEGUARD", 
    Side = "PLAYER",
    SourceId = "789",
    SourceMove = "SAFEGUARD",
    IsDoubleBattle = "false",
    HasLightClay = "false",
    BattleId = "battle_003"
})

_G.handler_apply_side_effect(safeguardMsg)

assert(_G.lastTestSuccess == true, "Should be successful")

-- Verify Safeguard state
assert(_G.SideEffectState.playerSideEffects.SAFEGUARD, "Safeguard should be applied")
assert(_G.SideEffectState.playerSideEffects.SAFEGUARD.effectType == "SAFEGUARD", "Effect type should be SAFEGUARD")

print("✓ Safeguard application test passed")

-- Test 4: Apply Mist (Stat Protection)
print("Test 4: Apply Mist Stat Protection")
resetTestEnvironment()

local mistMsg = createTestMessage("ApplySideEffect", {
    EffectType = "MIST",
    Side = "ENEMY",
    SourceId = "101112", 
    SourceMove = "MIST",
    IsDoubleBattle = "false",
    HasLightClay = "false",
    BattleId = "battle_004"
})

_G.handler_apply_side_effect(mistMsg)

assert(_G.lastTestSuccess == true, "Should be successful")

-- Verify Mist state
assert(_G.SideEffectState.enemySideEffects.MIST, "Mist should be applied")
assert(_G.SideEffectState.enemySideEffects.MIST.effectType == "MIST", "Effect type should be MIST")

print("✓ Mist application test passed")

-- Test 5: Effect Overwriting (Stacking Rules)
print("Test 5: Effect Overwriting Behavior")
resetTestEnvironment()

-- Apply first Reflect
local firstReflectMsg = createTestMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    SourceId = "111",
    SourceMove = "REFLECT",
    IsDoubleBattle = "false",
    HasLightClay = "false",
    BattleId = "battle_005"
})

_G.handler_apply_side_effect(firstReflectMsg)
assert(_G.lastTestSuccess == true, "First application should succeed")

-- Apply second Reflect with Light Clay (should overwrite)
local secondReflectMsg = createTestMessage("ApplySideEffect", {
    EffectType = "REFLECT", 
    Side = "PLAYER",
    SourceId = "222",
    SourceMove = "REFLECT",
    IsDoubleBattle = "false", 
    HasLightClay = "true",
    BattleId = "battle_005"
})

_G.handler_apply_side_effect(secondReflectMsg)
assert(_G.lastTestSuccess == true, "Second application should succeed")

-- Verify overwriting behavior
assert(_G.SideEffectState.playerSideEffects.REFLECT.sourceId == 222, "Source ID should be from second application")
assert(_G.SideEffectState.playerSideEffects.REFLECT.turnsRemaining == 8, "Duration should be from Light Clay extension")
assert(_G.SideEffectState.playerSideEffects.REFLECT.isExtended == true, "Should be marked as extended")

print("✓ Effect overwriting test passed")

-- Test 6: Check Screen Protection
print("Test 6: Check Screen Protection")
resetTestEnvironment()

-- First apply Reflect
local reflectMsg = createTestMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    SourceId = "333",
    SourceMove = "REFLECT",
    IsDoubleBattle = "false",
    HasLightClay = "false",
    BattleId = "battle_006"
})

_G.handler_apply_side_effect(reflectMsg)

-- Check protection without Infiltrator
local checkMsg = createTestMessage("CheckSideEffectProtection", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    MoveCategory = "PHYSICAL",
    AttackerHasInfiltrator = "false",
    IsDoubleBattle = "false",
    BattleId = "battle_006"
})

_G.handler_check_side_effect_protection(checkMsg)
assert(_G.lastTestSuccess == true, "Protection check should succeed")

-- Check protection with Infiltrator
local checkInfiltratorMsg = createTestMessage("CheckSideEffectProtection", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    MoveCategory = "PHYSICAL", 
    AttackerHasInfiltrator = "true",
    IsDoubleBattle = "false",
    BattleId = "battle_006"
})

_G.handler_check_side_effect_protection(checkInfiltratorMsg)
assert(_G.lastTestSuccess == true, "Infiltrator check should succeed")

print("✓ Screen protection check test passed")

-- Test 7: Turn Decrement and Expiry
print("Test 7: Turn Decrement and Effect Expiry")
resetTestEnvironment()

-- Apply effect with 1 turn remaining (simulate near expiry)
_G.SideEffectState.playerSideEffects["REFLECT"] = {
    effectType = "REFLECT",
    side = "PLAYER",
    turnsRemaining = 1,
    sourceId = 666,
    sourceMove = "REFLECT",
    isExtended = false
}

-- Decrement turns
local decrementMsg = createTestMessage("TurnDecrement", {
    Side = "PLAYER",
    BattleId = "battle_009"
})

_G.handler_turn_decrement(decrementMsg)
assert(_G.lastTestSuccess == true, "Turn decrement should succeed")

-- Verify effect was removed after expiry
assert(_G.SideEffectState.playerSideEffects["REFLECT"] == nil, "Effect should be removed after expiry")

print("✓ Turn decrement and expiry test passed")

-- Test 8: Brick Break Screen Removal
print("Test 8: Brick Break Screen Removal")
resetTestEnvironment()

-- Apply both screen effects and Safeguard
_G.SideEffectState.playerSideEffects["REFLECT"] = {
    effectType = "REFLECT",
    side = "PLAYER",
    turnsRemaining = 3,
    sourceId = 777,
    sourceMove = "REFLECT",
    isExtended = false
}

_G.SideEffectState.playerSideEffects["LIGHT_SCREEN"] = {
    effectType = "LIGHT_SCREEN", 
    side = "PLAYER",
    turnsRemaining = 4,
    sourceId = 888,
    sourceMove = "LIGHT_SCREEN",
    isExtended = false
}

_G.SideEffectState.playerSideEffects["SAFEGUARD"] = {
    effectType = "SAFEGUARD",
    side = "PLAYER",
    turnsRemaining = 2,
    sourceId = 999,
    sourceMove = "SAFEGUARD",
    isExtended = false
}

-- Use Brick Break (should only remove screens)
local brickBreakMsg = createTestMessage("RemoveSideEffects", {
    RemovalType = "BRICK_BREAK",
    Side = "PLAYER",
    BattleId = "battle_010"
})

_G.handler_remove_side_effects(brickBreakMsg)
assert(_G.lastTestSuccess == true, "Brick Break removal should succeed")

-- Verify only screens were removed
assert(_G.SideEffectState.playerSideEffects["REFLECT"] == nil, "Reflect should be removed")
assert(_G.SideEffectState.playerSideEffects["LIGHT_SCREEN"] == nil, "Light Screen should be removed")
assert(_G.SideEffectState.playerSideEffects["SAFEGUARD"] ~= nil, "Safeguard should remain")

print("✓ Brick Break screen removal test passed")

-- Test 9: Defog Complete Removal
print("Test 9: Defog Complete Effect Removal")
resetTestEnvironment()

-- Apply multiple effects on both sides
_G.SideEffectState.playerSideEffects = {
    REFLECT = {effectType = "REFLECT", side = "PLAYER", turnsRemaining = 3},
    SAFEGUARD = {effectType = "SAFEGUARD", side = "PLAYER", turnsRemaining = 2}
}

_G.SideEffectState.enemySideEffects = {
    LIGHT_SCREEN = {effectType = "LIGHT_SCREEN", side = "ENEMY", turnsRemaining = 4},
    MIST = {effectType = "MIST", side = "ENEMY", turnsRemaining = 1}
}

-- Use Defog (should remove all effects from both sides)
local defogMsg = createTestMessage("RemoveSideEffects", {
    RemovalType = "DEFOG",
    Side = "BOTH",
    BattleId = "battle_011"
})

_G.handler_remove_side_effects(defogMsg)
assert(_G.lastTestSuccess == true, "Defog removal should succeed")

-- Verify all effects were removed
local playerEmpty = true
local enemyEmpty = true

for _ in pairs(_G.SideEffectState.playerSideEffects) do
    playerEmpty = false
    break
end

for _ in pairs(_G.SideEffectState.enemySideEffects) do
    enemyEmpty = false
    break
end

assert(playerEmpty, "Player side effects should be empty")
assert(enemyEmpty, "Enemy side effects should be empty")

print("✓ Defog complete removal test passed")

-- Test 10: Get Side Effects State
print("Test 10: Get Side Effects State")
resetTestEnvironment()

-- Set up test state
_G.SideEffectState.playerSideEffects = {
    REFLECT = {effectType = "REFLECT", side = "PLAYER", turnsRemaining = 3}
}

_G.SideEffectState.enemySideEffects = {
    LIGHT_SCREEN = {effectType = "LIGHT_SCREEN", side = "ENEMY", turnsRemaining = 5}
}

-- Get all side effects
local getMsg = createTestMessage("GetSideEffects", {
    BattleId = "battle_012"
})

_G.handler_get_side_effects(getMsg)
assert(_G.lastTestSuccess == true, "Get side effects should succeed")

print("✓ Get side effects state test passed")

-- Test 11: Invalid Parameter Handling
print("Test 11: Invalid Parameter Handling")
resetTestEnvironment()

-- Test missing effect type
local invalidMsg = createTestMessage("ApplySideEffect", {
    Side = "PLAYER",
    SourceId = "123",
    BattleId = "battle_013"
})

_G.handler_apply_side_effect(invalidMsg)
assert(_G.lastSentMessage.Action == "Error", "Should return error for missing effect type")

-- Test invalid side
local invalidSideMsg = createTestMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "INVALID_SIDE",
    SourceId = "123", 
    BattleId = "battle_013"
})

_G.handler_apply_side_effect(invalidSideMsg)
assert(_G.lastSentMessage.Action == "Error", "Should return error for invalid side")

-- Test missing source ID
local missingSourceMsg = createTestMessage("ApplySideEffect", {
    EffectType = "REFLECT",
    Side = "PLAYER",
    BattleId = "battle_013"
})

_G.handler_apply_side_effect(missingSourceMsg)
assert(_G.lastSentMessage.Action == "Error", "Should return error for missing source ID")

print("✓ Invalid parameter handling test passed")

-- Test 12: ADP Info Handler
print("Test 12: ADP Info Handler")
resetTestEnvironment()

local infoMsg = createTestMessage("Info", {})

_G.handler_info(infoMsg)
assert(_G.lastSentMessage.Action == "SaveState", "Info should return SaveState")
assert(_G.lastTestSuccess == true, "Info should be successful")

print("✓ ADP Info handler test passed")

-- Test 13: Ping Handler
print("Test 13: Ping Handler")
resetTestEnvironment()

local pingMsg = createTestMessage("Ping", {})

_G.handler_ping(pingMsg)
assert(_G.lastSentMessage.Action == "Pong", "Ping should return Pong")

print("✓ Ping handler test passed")

print("\n🎉 All Side Effect Engine Unit Tests Passed!")
print("Total tests: 13")
print("Coverage: Screen effects, protection mechanics, duration tracking, removal systems, error handling, and ADP compliance")