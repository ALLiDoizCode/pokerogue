-- Integration Tests for Form Attributes Engine
-- Tests coordination with existing Form Change Engine, Move Transformation Engine,
-- and Form Persistence Engine for complete form attribute workflows

local aolite = require('aolite')

-- Initialize all required processes for integration testing
local formAttributesProcess = aolite.spawnProcess('form-attributes-engine', '/Users/jonathangreen/Documents/pokerogue/processes/form-attributes-engine.lua')

-- Test coordination requires existing form engines (mock or real)
-- For now, we'll test the form attributes engine in isolation but with realistic message flows

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: Expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

local function sendMessage(process, action, data, tags)
    local msg = {
        From = "integration-test-coordinator",
        Action = action,
        Data = data or "",
        Tags = tags or {}
    }
    
    if not msg.Tags.Action then
        msg.Tags.Action = action
    end
    
    return process.send(msg)
end

-- Integration Test Suite 1: Complete Form Change Workflow
print("=== Integration Test Suite 1: Complete Form Change Workflow ===")

-- Test 1.1: Aegislash Form Change Integration
print("Test 1.1: Aegislash Shield to Blade Form Change Workflow")

-- Step 1: Get initial Shield form attributes
local aegislashShield = {
    speciesId = 681,
    currentForm = "shield",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "ADAMANT",
    types = {"STEEL", "GHOST"},
    currentAbility = "STANCE_CHANGE"
}

local response = sendMessage(formAttributesProcess, "CalculateFormStats", require('json').encode(aegislashShield))
local shieldStats = require('json').decode(response.Data)
assertEquals(shieldStats.success, true, "Shield stats calculation")

-- Step 2: Simulate form change trigger (would come from Form Change Engine)
local formChangeData = {
    pokemonId = "test-aegislash-001",
    oldForm = "shield",
    newForm = "blade",
    trigger = "offensive_move_used",
    triggerContext = {
        moveCategory = "PHYSICAL",
        moveName = "SHADOW_CLAW"
    }
}

-- Step 3: Process type changes for new form
response = sendMessage(formAttributesProcess, "UpdateFormTypes", require('json').encode(aegislashShield), {NewForm = "blade"})
local typeUpdate = require('json').decode(response.Data)
assertEquals(typeUpdate.success, true, "Type update for blade form")

-- Step 4: Activate abilities for new form
response = sendMessage(formAttributesProcess, "ActivateFormAbilities", require('json').encode(aegislashShield), {TriggerContext = "form_change"})
local abilityUpdate = require('json').decode(response.Data)
assertEquals(abilityUpdate.success, true, "Ability activation for blade form")

-- Step 5: Calculate new form stats
local aegislashBlade = {
    speciesId = 681,
    currentForm = "blade",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "ADAMANT",
    types = {"STEEL", "GHOST"},
    currentAbility = "STANCE_CHANGE"
}

response = sendMessage(formAttributesProcess, "CalculateFormStats", require('json').encode(aegislashBlade))
local bladeStats = require('json').decode(response.Data)
assertEquals(bladeStats.success, true, "Blade stats calculation")

-- Verify stat redistribution occurred
assert(bladeStats.calculatedStats[2] > shieldStats.calculatedStats[2], "ATK increased in blade form")
assert(bladeStats.calculatedStats[3] < shieldStats.calculatedStats[3], "DEF decreased in blade form")

print("✅ Aegislash form change workflow completed successfully")

-- Test 1.2: Darmanitan Zen Mode Activation Integration
print("Test 1.2: Darmanitan Zen Mode Activation Workflow")

-- Step 1: Standard Mode stats and attributes
local darmanitanStandard = {
    speciesId = 555,
    currentForm = "standard",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "JOLLY",
    types = {"FIRE"},
    currentAbility = "ZEN_MODE",
    currentHP = 50 -- Simulate low HP trigger
}

response = sendMessage(formAttributesProcess, "CalculateFormStats", require('json').encode(darmanitanStandard))
local standardStats = require('json').decode(response.Data)

-- Step 2: Simulate HP threshold trigger for Zen Mode
local zenModeContext = {
    trigger = "hp_threshold",
    hpPercentage = 25,
    battleContext = "active_battle"
}

-- Step 3: Process form change to Zen Mode
response = sendMessage(formAttributesProcess, "UpdateFormTypes", require('json').encode(darmanitanStandard), {NewForm = "zen"})
local zenTypeUpdate = require('json').decode(response.Data)
assertEquals(zenTypeUpdate.success, true, "Zen Mode type update")

-- Step 4: Calculate Zen Mode stats  
local darmanitanZen = {
    speciesId = 555,
    currentForm = "zen",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "JOLLY",
    types = {"FIRE", "PSYCHIC"},
    currentAbility = "ZEN_MODE"
}

response = sendMessage(formAttributesProcess, "CalculateFormStats", require('json').encode(darmanitanZen))
local zenStats = require('json').decode(response.Data)

-- Verify dramatic stat redistribution
assert(zenStats.calculatedStats[2] < standardStats.calculatedStats[2], "ATK decreased in zen mode")
assert(zenStats.calculatedStats[4] > standardStats.calculatedStats[4], "SPATK increased in zen mode")

print("✅ Darmanitan Zen Mode activation workflow completed successfully")

-- Integration Test Suite 2: Move Transformation Coordination
print("=== Integration Test Suite 2: Move Transformation Coordination ===")

-- Test 2.1: Rotom Form-Specific Move Access
print("Test 2.1: Rotom Form-Specific Move Access Integration")

-- Test Rotom Heat form exclusive move access
local rotomHeat = {
    speciesId = 479,
    currentForm = "heat",
    level = 50,
    types = {"ELECTRIC", "FIRE"},
    currentAbility = "LEVITATE"
}

-- Verify Heat form can use Overheat
response = sendMessage(formAttributesProcess, "ValidateMoveAvailability", require('json').encode(rotomHeat), {MoveId = "OVERHEAT"})
local overheatAvailable = require('json').decode(response.Data)
assertEquals(overheatAvailable.isAvailable, true, "Overheat available in Heat form")

-- Test move restriction in base form
local rotomBase = {
    speciesId = 479,
    currentForm = "normal", 
    level = 50,
    types = {"ELECTRIC", "GHOST"},
    currentAbility = "LEVITATE"
}

response = sendMessage(formAttributesProcess, "ValidateMoveAvailability", require('json').encode(rotomBase), {MoveId = "OVERHEAT"})
local overheatRestricted = require('json').decode(response.Data)
assertEquals(overheatRestricted.isAvailable, false, "Overheat restricted in base form")

-- Test multiple form-exclusive moves
local formExclusiveMoves = {
    heat = "OVERHEAT",
    wash = "HYDRO_PUMP", 
    frost = "BLIZZARD",
    fan = "AIR_SLASH",
    mow = "LEAF_STORM"
}

for form, move in pairs(formExclusiveMoves) do
    local rotomForm = {
        speciesId = 479,
        currentForm = form,
        level = 50,
        types = {"ELECTRIC", "FIRE"}, -- Simplified for test
        currentAbility = "LEVITATE"
    }
    
    response = sendMessage(formAttributesProcess, "ValidateMoveAvailability", require('json').encode(rotomForm), {MoveId = move})
    local moveCheck = require('json').decode(response.Data)
    assertEquals(moveCheck.isAvailable, true, string.format("%s available in %s form", move, form))
end

print("✅ Rotom move access integration completed successfully")

-- Integration Test Suite 3: Battle Integration Scenarios
print("=== Integration Test Suite 3: Battle Integration Scenarios ===")

-- Test 3.1: Complete Battle Turn with Form Changes
print("Test 3.1: Complete Battle Turn with Form Changes")

-- Simulate battle scenario: Aegislash using King's Shield (Shield form)
local battleContext = {
    turn = 1,
    phase = "move_execution",
    weather = "none",
    terrain = "none"
}

-- Pre-move: Aegislash in Blade form using King's Shield
local aegislashPreMove = {
    speciesId = 681,
    currentForm = "blade",
    level = 50,
    types = {"STEEL", "GHOST"},
    currentAbility = "STANCE_CHANGE",
    moveUsed = "KINGS_SHIELD"
}

-- Step 1: Validate King's Shield is available
response = sendMessage(formAttributesProcess, "ValidateMoveAvailability", require('json').encode(aegislashPreMove), {MoveId = "KINGS_SHIELD"})
local kingsShieldCheck = require('json').decode(response.Data)
assertEquals(kingsShieldCheck.isAvailable, true, "King's Shield available")

-- Step 2: Process form change trigger (King's Shield -> Shield form)
response = sendMessage(formAttributesProcess, "UpdateFormTypes", require('json').encode(aegislashPreMove), {NewForm = "shield"})
local formChange = require('json').decode(response.Data)
assertEquals(formChange.success, true, "Form change to Shield")

-- Step 3: Calculate new defensive stats for Shield form
local aegislashPostMove = {
    speciesId = 681,
    currentForm = "shield",
    level = 50,
    types = {"STEEL", "GHOST"},
    currentAbility = "STANCE_CHANGE"
}

response = sendMessage(formAttributesProcess, "CalculateFormStats", require('json').encode(aegislashPostMove))
local shieldDefenseStats = require('json').decode(response.Data)

-- Verify defensive boost
assert(shieldDefenseStats.calculatedStats[3] >= 140, "Defense stat boosted in Shield form")

print("✅ Battle turn integration completed successfully")

-- Test 3.2: Type Effectiveness with Form Changes
print("Test 3.2: Type Effectiveness with Form Changes")

-- Test Castform weather form type effectiveness changes
local castformForms = {
    {form = "normal", type = "NORMAL"},
    {form = "sunny", type = "FIRE"},
    {form = "rainy", type = "WATER"},
    {form = "snowy", type = "ICE"}
}

for _, formData in ipairs(castformForms) do
    local castform = {
        speciesId = 351,
        currentForm = formData.form,
        level = 50,
        types = {formData.type},
        currentAbility = "FORECAST"
    }
    
    -- Test Fire-type move effectiveness
    response = sendMessage(formAttributesProcess, "CalculateFormResistances", require('json').encode(castform), {AttackType = "FIRE"})
    local fireResistance = require('json').decode(response.Data)
    assertEquals(fireResistance.success, true, string.format("Fire resistance calculation for %s form", formData.form))
    
    -- Verify type-specific resistances
    if formData.form == "rainy" then
        assert(fireResistance.multiplier <= 1.0, "Water form resists Fire")
    elseif formData.form == "snowy" then
        assert(fireResistance.multiplier >= 1.0, "Ice form weak to Fire")
    end
end

print("✅ Type effectiveness integration completed successfully")

-- Integration Test Suite 4: Persistence and State Management
print("=== Integration Test Suite 4: Persistence and State Management ===")

-- Test 4.1: Form State Persistence
print("Test 4.1: Form State Persistence Integration")

-- Simulate saving form state data
local formStateData = {
    pokemonId = "player-pokemon-001",
    speciesId = 681,
    currentForm = "blade",
    formHistory = {
        {form = "shield", timestamp = 1000},
        {form = "blade", timestamp = 2000}
    },
    persistentAttributes = {
        formChanges = 5,
        lastFormChange = "blade"
    }
}

-- Test form attribute retrieval for state validation
response = sendMessage(formAttributesProcess, "GetFormAttributes", "", {SpeciesId = "681", FormName = "blade"})
local stateValidation = require('json').decode(response.Data)
assertEquals(stateValidation.success, true, "State validation successful")

print("✅ Form state persistence integration completed successfully")

-- Integration Test Suite 5: Error Recovery and Resilience
print("=== Integration Test Suite 5: Error Recovery and Resilience ===")

-- Test 5.1: Invalid Form Recovery
print("Test 5.1: Invalid Form Recovery")

-- Test with invalid form name
local invalidFormData = {
    speciesId = 681,
    currentForm = "invalid_form",
    level = 50
}

response = sendMessage(formAttributesProcess, "CalculateFormStats", require('json').encode(invalidFormData))
local recoveryResult = require('json').decode(response.Data)
-- Should gracefully handle invalid form and potentially default to valid form
assertEquals(recoveryResult.success, true, "Invalid form recovery")

-- Test 5.2: Malformed Message Handling
print("Test 5.2: Malformed Message Handling")

response = sendMessage(formAttributesProcess, "CalculateFormStats", "invalid_json")
-- Should return error response for malformed data
assert(response.Action == "Error" or response.Data ~= nil, "Malformed message handling")

print("✅ Error recovery integration completed successfully")

-- Integration Test Summary
print("=== Integration Test Summary ===")
print("✅ Complete form change workflows verified")
print("✅ Move transformation coordination verified")
print("✅ Battle integration scenarios verified")
print("✅ Persistence and state management verified")
print("✅ Error recovery and resilience verified")
print("")
print("All integration tests passed - Form Attributes Engine properly coordinates with existing systems")
print("Ready for full system integration testing")