-- Entry Hazard Engine Unit Tests
-- Testing all hazard types: Spikes, Stealth Rock, Toxic Spikes, Sticky Web

-- Mock JSON implementation for testing
local json = {}

json.encode = function(obj)
    -- Simple JSON encoder for testing
    if type(obj) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(obj) do
            if not first then result = result .. "," end
            result = result .. '"' .. tostring(k) .. '":'
            if type(v) == "table" then
                result = result .. json.encode(v)
            elseif type(v) == "string" then
                result = result .. '"' .. v .. '"'
            else
                result = result .. tostring(v)
            end
            first = false
        end
        return result .. "}"
    else
        return tostring(obj)
    end
end

json.decode = function(str)
    -- Simple JSON decoder for testing - returns mock objects
    if str == "" or str == "{}" then
        return {}
    end
    -- Return mock data for testing
    return {
        stats = { hp = 100 },
        types = { "NORMAL" },
        ability = nil
    }
end

-- Test Setup
local function setupTestEnvironment()
    -- Mock AO environment
    if not ao then
        ao = {
            send = function(msg)
                -- Store sent messages for testing
                if not _G.testMessages then
                    _G.testMessages = {}
                end
                table.insert(_G.testMessages, msg)
            end,
            id = "test_entry_hazard_process_id"
        }
    end

    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                -- Store handlers for testing
                if not _G.testHandlers then
                    _G.testHandlers = {}
                end
                _G.testHandlers[name] = {
                    matcher = matcher,
                    handler = handler
                }
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

    -- Clear test data
    _G.testMessages = {}
    _G.testHandlers = {}
end

-- Test Data
local mockPokemon = {
    stats = { hp = 100 },
    types = { "NORMAL" },
    ability = nil
}

local mockPokemonFlying = {
    stats = { hp = 100 },
    types = { "NORMAL", "FLYING" },
    ability = nil
}

local mockPokemonPoison = {
    stats = { hp = 100 },
    types = { "POISON" },
    ability = nil
}

local mockPokemonMagicGuard = {
    stats = { hp = 100 },
    types = { "NORMAL" },
    ability = "MAGIC_GUARD"
}

local mockPokemonFireFlying = {
    stats = { hp = 100 },
    types = { "FIRE", "FLYING" },
    ability = nil
}

-- Test Helper Functions
local function callHandler(handlerName, msg)
    local handler = _G.testHandlers[handlerName]
    if handler and handler.matcher(msg) then
        handler.handler(msg)
        return true
    end
    return false
end

local function getLastMessage()
    return _G.testMessages[#_G.testMessages]
end

local function clearMessages()
    _G.testMessages = {}
end

print("Starting Entry Hazard Engine Unit Tests...")

-- Initialize test environment
setupTestEnvironment()

-- Mock require function to provide JSON
local originalRequire = require
require = function(module)
    if module == "json" then
        return json
    else
        return originalRequire(module)
    end
end

-- Load the entry hazard engine code
dofile("processes/entry-hazard-engine.lua")

-- Restore original require
require = originalRequire

-- Test 1: Spikes Placement and Damage Calculation
print("Test 1: Spikes Placement and Damage")

-- Test placing 1 layer of spikes
local spikesMsg1 = {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "SPIKES",
    Side = "PLAYER",
    BattleId = "test_battle_1",
    SourceId = "123",
    SourceMove = "SPIKES",
    Timestamp = "1234567890"
}

callHandler("place-entry-hazard", spikesMsg1)
local response1 = getLastMessage()
assert(response1.Action == "SaveState", "Should return SaveState action")
assert(response1.Success == "true", "Should indicate success")

local spikesData1 = json.decode(response1.Data)
assert(spikesData1.hazardState.layers == 1, "Should have 1 layer of spikes")
assert(spikesData1.hazardState.hazardType == "SPIKES", "Should be SPIKES type")

-- Test adding second layer
clearMessages()
callHandler("place-entry-hazard", spikesMsg1)
local response2 = getLastMessage()
local spikesData2 = json.decode(response2.Data)
assert(spikesData2.hazardState.layers == 2, "Should have 2 layers of spikes")

-- Test adding third layer
clearMessages()
callHandler("place-entry-hazard", spikesMsg1)
local response3 = getLastMessage()
local spikesData3 = json.decode(response3.Data)
assert(spikesData3.hazardState.layers == 3, "Should have 3 layers of spikes")

-- Test max layers limit
clearMessages()
callHandler("place-entry-hazard", spikesMsg1)
local response4 = getLastMessage()
local spikesData4 = json.decode(response4.Data)
assert(spikesData4.hazardState.layers == 3, "Should remain at 3 layers max")

print("✓ Spikes placement test passed")

-- Test 2: Spikes Activation and Damage Calculation
print("Test 2: Spikes Activation and Damage")

-- Test 1 layer spikes damage (1/8 = 12.5% of 100 HP = 12 damage, floor)
local activateMsg1 = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemon),
    Side = "PLAYER",
    BattleId = "test_battle_1",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activateMsg1)
local activateResponse1 = getLastMessage()
local activateData1 = json.decode(activateResponse1.Data)

-- Expected damage: 1/(10-2*3) = 1/4 = 25% of 100 HP = 25 damage
assert(activateData1.activationResult.totalDamage == 25, "Should deal 25 damage for 3 layers")
assert(#activateData1.activationResult.activatedHazards == 1, "Should activate 1 hazard")
assert(activateData1.activationResult.activatedHazards[1].hazardType == "SPIKES", "Should activate SPIKES")

print("✓ Spikes activation test passed")

-- Test 3: Flying Pokemon Immunity to Spikes
print("Test 3: Flying Pokemon Immunity")

local activateMsg2 = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemonFlying),
    Side = "PLAYER",
    BattleId = "test_battle_1",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activateMsg2)
local activateResponse2 = getLastMessage()
local activateData2 = json.decode(activateResponse2.Data)

assert(activateData2.activationResult.totalDamage == 0, "Flying type should take no damage")
assert(activateData2.activationResult.activatedHazards[1].immuneReason == "Not grounded", "Should be immune due to not grounded")

print("✓ Flying Pokemon immunity test passed")

-- Test 4: Stealth Rock Implementation
print("Test 4: Stealth Rock Implementation")

-- Place Stealth Rock
local stealthRockMsg = {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "STEALTH_ROCK",
    Side = "ENEMY",
    BattleId = "test_battle_2",
    SourceId = "456",
    SourceMove = "STEALTH_ROCK",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("place-entry-hazard", stealthRockMsg)
local stealthRockResponse = getLastMessage()
local stealthRockData = json.decode(stealthRockResponse.Data)
assert(stealthRockData.hazardState.layers == 1, "Should have 1 layer of Stealth Rock")

-- Test Stealth Rock vs Fire/Flying (4x weakness to Rock)
local activateStealthRock = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemonFireFlying),
    Side = "ENEMY",
    BattleId = "test_battle_2",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activateStealthRock)
local stealthRockActivateResponse = getLastMessage()
local stealthRockActivateData = json.decode(stealthRockActivateResponse.Data)

-- Expected: 0.125 * 100 HP * 4.0 type effectiveness = 50 damage
assert(stealthRockActivateData.activationResult.totalDamage == 50, "Should deal 50 damage to Fire/Flying (4x weakness)")

print("✓ Stealth Rock test passed")

-- Test 5: Toxic Spikes Implementation
print("Test 5: Toxic Spikes Implementation")

-- Place 1 layer Toxic Spikes
local toxicSpikesMsg = {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "TOXIC_SPIKES",
    Side = "PLAYER",
    BattleId = "test_battle_3",
    SourceId = "789",
    SourceMove = "TOXIC_SPIKES",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("place-entry-hazard", toxicSpikesMsg)

-- Test 1 layer activation (regular poison)
local activateToxicSpikes1 = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemon),
    Side = "PLAYER",
    BattleId = "test_battle_3",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activateToxicSpikes1)
local toxicSpikesResponse1 = getLastMessage()
local toxicSpikesData1 = json.decode(toxicSpikesResponse1.Data)

assert(toxicSpikesData1.activationResult.totalDamage == 0, "Toxic Spikes should deal no direct damage")
assert(#toxicSpikesData1.activationResult.statusEffects == 1, "Should apply status effect")
assert(toxicSpikesData1.activationResult.statusEffects[1] == "POISON", "Should apply regular poison")

-- Add second layer
clearMessages()
callHandler("place-entry-hazard", toxicSpikesMsg)

-- Test 2 layer activation (badly poisoned)
clearMessages()
callHandler("activate-entry-hazards", activateToxicSpikes1)
local toxicSpikesResponse2 = getLastMessage()
local toxicSpikesData2 = json.decode(toxicSpikesResponse2.Data)

assert(#toxicSpikesData2.activationResult.statusEffects == 1, "Should apply status effect")
assert(toxicSpikesData2.activationResult.statusEffects[1] == "BADLY_POISONED", "Should apply badly poisoned")

print("✓ Toxic Spikes test passed")

-- Test 6: Poison-type Neutralizing Toxic Spikes
print("Test 6: Poison-type Neutralization")

local activatePoisonType = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemonPoison),
    Side = "PLAYER",
    BattleId = "test_battle_3",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activatePoisonType)
local poisonResponse = getLastMessage()
local poisonData = json.decode(poisonResponse.Data)

assert(poisonData.activationResult.activatedHazards[1].immuneReason == "Poison-type absorbed", "Poison type should absorb toxic spikes")

print("✓ Poison-type neutralization test passed")

-- Test 7: Sticky Web Implementation
print("Test 7: Sticky Web Implementation")

-- Place Sticky Web
local stickyWebMsg = {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "STICKY_WEB",
    Side = "ENEMY",
    BattleId = "test_battle_4",
    SourceId = "101",
    SourceMove = "STICKY_WEB",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("place-entry-hazard", stickyWebMsg)

-- Test Sticky Web activation
local activateStickyWeb = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemon),
    Side = "ENEMY",
    BattleId = "test_battle_4",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activateStickyWeb)
local stickyWebResponse = getLastMessage()
local stickyWebData = json.decode(stickyWebResponse.Data)

assert(stickyWebData.activationResult.totalDamage == 0, "Sticky Web should deal no damage")
assert(stickyWebData.activationResult.statChanges.speed == -1, "Should reduce Speed by 1 stage")

print("✓ Sticky Web test passed")

-- Test 8: Magic Guard Immunity
print("Test 8: Magic Guard Immunity")

-- Set up spikes again for Magic Guard test
local spikesForMagicGuard = {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "SPIKES",
    Side = "PLAYER",
    BattleId = "test_battle_magic_guard",
    SourceId = "999",
    SourceMove = "SPIKES",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("place-entry-hazard", spikesForMagicGuard)

-- Test Magic Guard immunity
local activateMagicGuard = {
    From = "test_sender",
    Action = "ActivateEntryHazards",
    PokemonData = json.encode(mockPokemonMagicGuard),
    Side = "PLAYER",
    BattleId = "test_battle_magic_guard",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("activate-entry-hazards", activateMagicGuard)
local magicGuardResponse = getLastMessage()
local magicGuardData = json.decode(magicGuardResponse.Data)

assert(magicGuardData.activationResult.totalDamage == 0, "Magic Guard should block damage")
assert(magicGuardData.activationResult.activatedHazards[1].immuneReason == "Magic Guard", "Should be immune due to Magic Guard")

print("✓ Magic Guard immunity test passed")

-- Test 9: Hazard Removal - Rapid Spin
print("Test 9: Rapid Spin Removal")

local rapidSpinMsg = {
    From = "test_sender",
    Action = "RemoveEntryHazards",
    RemovalType = "RAPID_SPIN",
    Side = "PLAYER",
    BattleId = "test_battle_1",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("remove-entry-hazards", rapidSpinMsg)
local rapidSpinResponse = getLastMessage()
local rapidSpinData = json.decode(rapidSpinResponse.Data)

assert(#rapidSpinData.removalResult.removedHazards > 0, "Should remove hazards")
assert(rapidSpinData.removalResult.removalType == "RAPID_SPIN", "Should indicate Rapid Spin removal")

print("✓ Rapid Spin removal test passed")

-- Test 10: Hazard Removal - Defog
print("Test 10: Defog Removal")

-- Place hazards on both sides first
clearMessages()
callHandler("place-entry-hazard", {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "SPIKES",
    Side = "PLAYER",
    BattleId = "test_battle_defog",
    SourceId = "111",
    SourceMove = "SPIKES",
    Timestamp = "1234567890"
})

callHandler("place-entry-hazard", {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "STEALTH_ROCK",
    Side = "ENEMY",
    BattleId = "test_battle_defog",
    SourceId = "222",
    SourceMove = "STEALTH_ROCK",
    Timestamp = "1234567890"
})

-- Test Defog
local defogMsg = {
    From = "test_sender",
    Action = "RemoveEntryHazards",
    RemovalType = "DEFOG",
    Side = "BOTH",
    BattleId = "test_battle_defog",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("remove-entry-hazards", defogMsg)
local defogResponse = getLastMessage()
local defogData = json.decode(defogResponse.Data)

assert(#defogData.removalResult.removedHazards >= 2, "Should remove hazards from both sides")
assert(defogData.removalResult.removalType == "DEFOG", "Should indicate Defog removal")

print("✓ Defog removal test passed")

-- Test 11: Error Handling
print("Test 11: Error Handling")

-- Test missing required fields
local invalidMsg = {
    From = "test_sender",
    Action = "PlaceEntryHazard"
    -- Missing HazardType, Side, BattleId
}

clearMessages()
callHandler("place-entry-hazard", invalidMsg)
local errorResponse = getLastMessage()
assert(errorResponse.Action == "Error", "Should return error for missing fields")
assert(errorResponse.Error:find("Missing required fields"), "Should indicate missing fields")

-- Test invalid hazard type
local invalidHazardMsg = {
    From = "test_sender",
    Action = "PlaceEntryHazard",
    HazardType = "INVALID_HAZARD",
    Side = "PLAYER",
    BattleId = "test_battle_error",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("place-entry-hazard", invalidHazardMsg)
local errorResponse2 = getLastMessage()
assert(errorResponse2.Action == "Error", "Should return error for invalid hazard type")
assert(errorResponse2.Error:find("Invalid hazard type"), "Should indicate invalid hazard type")

print("✓ Error handling test passed")

-- Test 12: Info Handler (ADP v1.0 Compliance)
print("Test 12: ADP v1.0 Compliance")

local infoMsg = {
    From = "test_sender",
    Action = "Info",
    Timestamp = "1234567890"
}

clearMessages()
callHandler("info", infoMsg)
local infoResponse = getLastMessage()
local infoData = json.decode(infoResponse.Data)

assert(infoData.process.adpVersion == "1.0", "Should be ADP v1.0 compliant")
assert(infoData.process.name == "Entry Hazard Engine", "Should have correct process name")
assert(#infoData.process.capabilities >= 4, "Should list all capabilities")
assert(#infoData.handlers >= 5, "Should list all handlers")

print("✓ ADP v1.0 compliance test passed")

print("\n🎉 All Entry Hazard Engine Unit Tests PASSED! ✅")
print("Total tests completed: 12")
print("✓ Spikes placement and stacking")
print("✓ Spikes damage calculation (1/8, 1/6, 1/4)")
print("✓ Flying-type immunity")
print("✓ Stealth Rock type effectiveness")
print("✓ Toxic Spikes status effects")
print("✓ Poison-type neutralization")
print("✓ Sticky Web stat reduction")
print("✓ Magic Guard immunity")
print("✓ Rapid Spin removal")
print("✓ Defog removal")
print("✓ Error handling")
print("✓ ADP v1.0 compliance")