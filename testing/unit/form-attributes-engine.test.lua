-- Unit Tests for Form Attributes Engine
-- Tests form-specific stat calculations, ability activation, type changes,
-- move availability, item interactions, and resistance calculations

local aolite = require('aolite')
local json = require('json')

-- Test configuration
local PROCESS_PATH = "processes.form-attributes-engine"
local processId = "test-form-attributes-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Form Attributes Engine")
print("Process ID:", processId)

-- Test Helper Functions
local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: Expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

local function assertTableEquals(actual, expected, message)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        error(string.format("%s: Both values must be tables", message or "Table assertion failed"))
    end

    for k, v in pairs(expected) do
        if actual[k] ~= v then
            error(string.format("%s: Key %s - Expected %s, got %s", message or "Table assertion failed", tostring(k), tostring(v), tostring(actual[k])))
        end
    end
end

local function sendMessage(action, data, tags)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test Data
local aegislashShieldForm = {
    speciesId = 681,
    currentForm = "shield",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "ADAMANT",
    types = {"STEEL", "GHOST"},
    currentAbility = "STANCE_CHANGE"
}

local aegislashBladeForm = {
    speciesId = 681,
    currentForm = "blade",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "ADAMANT",
    types = {"STEEL", "GHOST"},
    currentAbility = "STANCE_CHANGE"
}

local darmanitanStandardForm = {
    speciesId = 555,
    currentForm = "standard",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "JOLLY",
    types = {"FIRE"},
    currentAbility = "SHEER_FORCE"
}

local darmanitanZenForm = {
    speciesId = 555,
    currentForm = "zen",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "JOLLY",
    types = {"FIRE", "PSYCHIC"},
    currentAbility = "ZEN_MODE"
}

local castformNormalForm = {
    speciesId = 351,
    currentForm = "normal",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "MODEST",
    types = {"NORMAL"},
    currentAbility = "FORECAST"
}

local rotomHeatForm = {
    speciesId = 479,
    currentForm = "heat",
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "MODEST",
    types = {"ELECTRIC", "FIRE"},
    currentAbility = "LEVITATE"
}

-- Test Suite 1: Form Stat Calculations
print("=== Testing Form Stat Calculations ===")

-- Test 1.1: Aegislash Shield Form Stats
print("Test 1.1: Aegislash Shield Form Stats")
local response = sendMessage("CalculateFormStats", json.encode(aegislashShieldForm))
local result = json.decode(response.Data)

-- Expected Shield Form stats: 60/50/140/50/140/60 at level 50
-- HP: ((2*60+31)*50/100)+50+10 = 165
-- ATK: (((2*50+31)*50/100)+5)*1.1 = 127 (Adamant +10% ATK)
-- DEF: ((2*140+31)*50/100)+5 = 160
-- SPATK: (((2*50+31)*50/100)+5)*0.9 = 104 (Adamant -10% SPATK)
-- SPDEF: ((2*140+31)*50/100)+5 = 160  
-- SPEED: ((2*60+31)*50/100)+5 = 80

assertEquals(result.calculatedStats[1], 165, "Aegislash Shield HP stat")
assertEquals(result.calculatedStats[2], 127, "Aegislash Shield ATK stat")
assertEquals(result.calculatedStats[3], 160, "Aegislash Shield DEF stat")
assertEquals(result.calculatedStats[4], 104, "Aegislash Shield SPATK stat")
assertEquals(result.calculatedStats[5], 160, "Aegislash Shield SPDEF stat")
assertEquals(result.calculatedStats[6], 80, "Aegislash Shield SPEED stat")

-- Test 1.2: Aegislash Blade Form Stats
print("Test 1.2: Aegislash Blade Form Stats")
response = sendMessage("CalculateFormStats", json.encode(aegislashBladeForm))
result = json.decode(response.Data)

-- Expected Blade Form stats: 60/140/50/140/50/60 at level 50
-- HP: 165 (same)
-- ATK: (((2*140+31)*50/100)+5)*1.1 = 176 (Adamant +10% ATK)
-- DEF: ((2*50+31)*50/100)+5 = 70
-- SPATK: (((2*140+31)*50/100)+5)*0.9 = 144 (Adamant -10% SPATK)
-- SPDEF: ((2*50+31)*50/100)+5 = 70
-- SPEED: ((2*60+31)*50/100)+5 = 80

assertEquals(result.calculatedStats[1], 165, "Aegislash Blade HP stat")
assertEquals(result.calculatedStats[2], 176, "Aegislash Blade ATK stat")
assertEquals(result.calculatedStats[3], 70, "Aegislash Blade DEF stat")
assertEquals(result.calculatedStats[4], 144, "Aegislash Blade SPATK stat")
assertEquals(result.calculatedStats[5], 70, "Aegislash Blade SPDEF stat")
assertEquals(result.calculatedStats[6], 80, "Aegislash Blade SPEED stat")

-- Test 1.3: Darmanitan Standard vs Zen Mode Stats
print("Test 1.3: Darmanitan Standard Form Stats")
response = sendMessage("CalculateFormStats", json.encode(darmanitanStandardForm))
result = json.decode(response.Data)

-- Expected Standard Mode stats: 105/140/55/30/55/95 at level 50
-- HP: ((2*105+31)*50/100)+50+10 = 180
-- ATK: ((2*140+31)*50/100)+5 = 160 (Jolly nature neutral on ATK)
-- DEF: ((2*55+31)*50/100)+5 = 75
-- SPATK: (((2*30+31)*50/100)+5)*0.9 = 40 (Jolly -10% SPATK)
-- SPDEF: ((2*55+31)*50/100)+5 = 75
-- SPEED: (((2*95+31)*50/100)+5)*1.1 = 116 (Jolly +10% SPEED)

assertEquals(result.calculatedStats[1], 180, "Darmanitan Standard HP stat")
assertEquals(result.calculatedStats[2], 160, "Darmanitan Standard ATK stat")
assertEquals(result.calculatedStats[6], 116, "Darmanitan Standard SPEED stat")

print("Test 1.4: Darmanitan Zen Mode Stats")
response = sendMessage("CalculateFormStats", json.encode(darmanitanZenForm))
result = json.decode(response.Data)

-- Expected Zen Mode stats: 105/30/105/140/105/55 at level 50
-- HP: 180 (same)
-- ATK: ((2*30+31)*50/100)+5 = 40 (Jolly nature neutral)
-- DEF: ((2*105+31)*50/100)+5 = 115  
-- SPATK: (((2*140+31)*50/100)+5)*0.9 = 144 (Jolly -10% SPATK)
-- SPDEF: ((2*105+31)*50/100)+5 = 115
-- SPEED: (((2*55+31)*50/100)+5)*1.1 = 82 (Jolly +10% SPEED)

assertEquals(result.calculatedStats[1], 180, "Darmanitan Zen HP stat")
assertEquals(result.calculatedStats[2], 40, "Darmanitan Zen ATK stat") 
assertEquals(result.calculatedStats[3], 115, "Darmanitan Zen DEF stat")
assertEquals(result.calculatedStats[6], 82, "Darmanitan Zen SPEED stat")

-- Test Suite 2: Form Type Changes
print("=== Testing Form Type Changes ===")

-- Test 2.1: Castform Weather Form Type Changes
print("Test 2.1: Castform Type Changes")
response = sendMessage("UpdateFormTypes", json.encode(castformNormalForm), {NewForm = "sunny"})
result = json.decode(response.Data)

assertEquals(result.success, true, "Castform type change success")
assertEquals(result.newForm, "sunny", "Castform new form")

-- Test 2.2: Darmanitan Type Change to Zen Mode
print("Test 2.2: Darmanitan Type Changes")
response = sendMessage("UpdateFormTypes", json.encode(darmanitanStandardForm), {NewForm = "zen"})
result = json.decode(response.Data)

assertEquals(result.success, true, "Darmanitan type change success")
assertEquals(result.newForm, "zen", "Darmanitan new form")

-- Test Suite 3: Form Ability Activation
print("=== Testing Form Ability Activation ===")

-- Test 3.1: Aegislash Stance Change Ability
print("Test 3.1: Aegislash Stance Change Ability")
response = sendMessage("ActivateFormAbilities", json.encode(aegislashShieldForm), {TriggerContext = "move_use"})
result = json.decode(response.Data)

assertEquals(result.success, true, "Aegislash ability activation success")
assertEquals(result.currentAbility, "STANCE_CHANGE", "Aegislash current ability")

-- Test 3.2: Darmanitan Zen Mode Ability
print("Test 3.2: Darmanitan Zen Mode Ability")
response = sendMessage("ActivateFormAbilities", json.encode(darmanitanZenForm), {TriggerContext = "hp_threshold"})
result = json.decode(response.Data)

assertEquals(result.success, true, "Darmanitan ability activation success")
assertEquals(result.currentAbility, "ZEN_MODE", "Darmanitan current ability")

-- Test Suite 4: Move Availability Validation
print("=== Testing Move Availability Validation ===")

-- Test 4.1: Rotom Heat Form Exclusive Move
print("Test 4.1: Rotom Heat Form Overheat Availability")
response = sendMessage("ValidateMoveAvailability", json.encode(rotomHeatForm), {MoveId = "OVERHEAT"})
result = json.decode(response.Data)

assertEquals(result.isAvailable, true, "Rotom Heat Overheat availability")
assertEquals(result.success, true, "Move validation success")

-- Test 4.2: Rotom Base Form Cannot Use Overheat
print("Test 4.2: Rotom Base Form Overheat Restriction")
local rotomBaseForm = {
    speciesId = 479,
    currentForm = "normal",
    level = 50,
    types = {"ELECTRIC", "GHOST"},
    currentAbility = "LEVITATE"
}
response = sendMessage("ValidateMoveAvailability", json.encode(rotomBaseForm), {MoveId = "OVERHEAT"})
result = json.decode(response.Data)

assertEquals(result.isAvailable, false, "Rotom Base Overheat restriction")
assertEquals(result.success, true, "Move validation success")

-- Test Suite 5: Form Resistance Calculations
print("=== Testing Form Resistance Calculations ===")

-- Test 5.1: Aegislash Steel/Ghost Resistances
print("Test 5.1: Aegislash Fire Resistance")
response = sendMessage("CalculateFormResistances", json.encode(aegislashShieldForm), {AttackType = "FIRE"})
result = json.decode(response.Data)

assertEquals(result.multiplier, 2.0, "Aegislash Fire weakness")
assertEquals(result.success, true, "Resistance calculation success")

print("Test 5.2: Aegislash Fighting Resistance")
response = sendMessage("CalculateFormResistances", json.encode(aegislashShieldForm), {AttackType = "FIGHTING"})
result = json.decode(response.Data)

assertEquals(result.multiplier, 0.5, "Aegislash Fighting resistance")

-- Test 5.3: Darmanitan Zen Mode Fire/Psychic Resistances
print("Test 5.3: Darmanitan Zen Mode Fire Resistance")
response = sendMessage("CalculateFormResistances", json.encode(darmanitanZenForm), {AttackType = "FIRE"})
result = json.decode(response.Data)

assertEquals(result.multiplier, 0.5, "Darmanitan Zen Fire resistance")

-- Test Suite 6: Form Attribute Retrieval
print("=== Testing Form Attribute Retrieval ===")

-- Test 6.1: Get Aegislash Shield Form Attributes
print("Test 6.1: Aegislash Shield Form Attributes")
response = sendMessage("GetFormAttributes", "", {SpeciesId = "681", FormName = "shield"})
result = json.decode(response.Data)

assertEquals(result.success, true, "Form attributes retrieval success")
assertEquals(result.speciesId, 681, "Species ID match")
assertEquals(result.formName, "shield", "Form name match")
assertTableEquals(result.attributes.stats, {60, 50, 140, 50, 140, 60}, "Shield form stats")
assertTableEquals(result.attributes.types, {"STEEL", "GHOST"}, "Shield form types")

-- Test 6.2: Get Rotom Heat Form Attributes
print("Test 6.2: Rotom Heat Form Attributes")
response = sendMessage("GetFormAttributes", "", {SpeciesId = "479", FormName = "heat"})
result = json.decode(response.Data)

assertEquals(result.success, true, "Rotom attributes retrieval success")
assertTableEquals(result.attributes.stats, {50, 65, 107, 105, 107, 86}, "Heat form stats")
assertTableEquals(result.attributes.types, {"ELECTRIC", "FIRE"}, "Heat form types")

-- Test Suite 7: Form Item Interactions
print("=== Testing Form Item Interactions ===")

-- Test 7.1: Basic Item Interaction Processing
print("Test 7.1: Form Item Interaction Processing")
local itemData = {id = "CHOICE_BAND", name = "Choice Band"}
response = sendMessage("ProcessFormItemInteraction", json.encode(aegislashShieldForm), {
    ItemData = json.encode(itemData),
    Context = "battle"
})
result = json.decode(response.Data)

assertEquals(result.success, true, "Item interaction processing success")
assertEquals(result.itemId, "CHOICE_BAND", "Item ID match")

-- Test Suite 8: Error Handling
print("=== Testing Error Handling ===")

-- Test 8.1: Missing Required Parameters
print("Test 8.1: Missing Parameters Error Handling")
response = sendMessage("CalculateFormStats", "")
result = json.decode(response.Data)

-- Should receive error response
assertEquals(response.Action, "Error", "Error response action")

-- Test 8.2: Invalid Species ID
print("Test 8.2: Invalid Species ID Handling")
local invalidPokemon = {speciesId = 99999, currentForm = "invalid"}
response = sendMessage("CalculateFormStats", json.encode(invalidPokemon))
result = json.decode(response.Data)

-- Should handle gracefully
assertEquals(result.success, true, "Invalid species handling")

-- Test Suite 9: ADP Compliance
print("=== Testing ADP v1.0 Compliance ===")

-- Test 9.1: Info Handler
print("Test 9.1: ADP Info Handler")
response = sendMessage("Info", "")
result = json.decode(response.Data)

assertEquals(result.Name, "Form Attributes Engine", "Process name")
assertEquals(result.protocolVersion, "1.0", "ADP protocol version")
assert(#result.handlers > 0, "Handlers array populated")

-- Test 9.2: Ping Handler
print("Test 9.2: ADP Ping Handler")
response = sendMessage("Ping", "")

assertEquals(response.Action, "Pong", "Ping response action")
assertEquals(response.Data, "pong", "Ping response data")

print("=== All Form Attributes Engine Tests Completed Successfully ===")
print("✅ Form stat calculations working correctly")
print("✅ Form type changes working correctly") 
print("✅ Form ability activation working correctly")
print("✅ Move availability validation working correctly")
print("✅ Form resistance calculations working correctly")
print("✅ Form attribute retrieval working correctly")
print("✅ Form item interactions working correctly")
print("✅ Error handling working correctly")
print("✅ ADP v1.0 compliance verified")
print("")
print("Total test cases: 25+")
print("All tests passed - Form Attributes Engine ready for deployment")