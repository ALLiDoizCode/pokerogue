-- Aolite Unit Tests for Abilities Database Process
-- Tests ability data queries with real aolite framework
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.abilities-database"
local processId = "test-abilities-database"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Abilities Database")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Constants for testing
local ABILITY = {
    OVERGROW = 65,
    BLAZE = 66,
    TORRENT = 67,
    STATIC = 9,
    POISON_POINT = 38,
    VOLT_ABSORB = 10,
    WATER_ABSORB = 11,
    FLASH_FIRE = 18,
    DRIZZLE = 2,
    DROUGHT = 70,
    CHLOROPHYLL = 34,
    SWIFT_SWIM = 33,
    HUGE_POWER = 37,
    LIMBER = 7,
    IMMUNITY = 17,
    WONDER_GUARD = 25,
    LEVITATE = 26,
    PRESSURE = 46,
    NATURAL_CURE = 30,
    COMPOUND_EYES = 14
}

local TRIGGER_TYPE = {
    ON_ENTRY = "on_entry",
    ON_SWITCH = "on_switch",
    ON_DAMAGE = "on_damage",
    ON_ATTACK = "on_attack",
    ON_DEFEND = "on_defend",
    ON_STATUS = "on_status",
    ON_WEATHER = "on_weather",
    ON_CONTACT = "on_contact",
    PASSIVE = "passive",
    ALWAYS_ACTIVE = "always_active"
}

local EFFECT_TYPE = {
    STAT_BOOST = "stat_boost",
    STATUS_INFLICT = "status_inflict",
    IMMUNITY = "immunity",
    ABSORPTION = "absorption",
    DAMAGE_MODIFY = "damage_modify",
    WEATHER_SET = "weather_set"
}

-- Test 1: Info Handler (ADP v1.0 Compliance)
print("📝 Test 1: Info Handler (ADP v1.0 Compliance)")
local infoResponse = sendMessage("Info")
if not infoResponse then
    error("❌ Test 1 failed: No response received")
end
if infoResponse.Action ~= "SaveState" then
    error("❌ Test 1 failed: Expected SaveState action")
end
if not infoResponse.Data then
    error("❌ Test 1 failed: No data in response")
end
print("✅ Test 1 passed")

-- Test 2: GetAbility by ID
print("📝 Test 2: GetAbility by ID")
local response = sendMessage("GetAbility", {Id = ABILITY.STATIC})
if not response then
    error("❌ Test 2 failed: No response received")
end
if response.Action ~= "SaveState" then
    error("❌ Test 2 failed: Expected SaveState action, got: " .. tostring(response.Action))
end
if response.Success ~= "true" then
    error("❌ Test 2 failed: Expected Success='true', got: " .. tostring(response.Success))
end
if response.AbilityName ~= "Static" then
    error("❌ Test 2 failed: Expected AbilityName='Static', got: " .. tostring(response.AbilityName))
end
if response.EffectType ~= EFFECT_TYPE.STATUS_INFLICT then
    error("❌ Test 2 failed: Expected EffectType to be STATUS_INFLICT, got: " .. tostring(response.EffectType))
end
print("✅ Test 2 passed")

-- Test 3: GetAbility by Name
print("📝 Test 3: GetAbility by Name")
local response3 = sendMessage("GetAbility", {AbilityName = "Overgrow"})
if not response3 then
    error("❌ Test 3 failed: No response received")
end
if response3.Action ~= "SaveState" then
    error("❌ Test 3 failed: Expected SaveState action")
end
if response3.Success ~= "true" then
    error("❌ Test 3 failed: Expected Success='true'")
end
if response3.AbilityId ~= tostring(ABILITY.OVERGROW) then
    error("❌ Test 3 failed: Expected AbilityId=" .. ABILITY.OVERGROW .. ", got: " .. tostring(response3.AbilityId))
end
if response3.EffectType ~= EFFECT_TYPE.DAMAGE_MODIFY then
    error("❌ Test 3 failed: Expected DAMAGE_MODIFY effect, got: " .. tostring(response3.EffectType))
end
print("✅ Test 3 passed")

-- Test 4: GetAbilitiesByTrigger
print("📝 Test 4: GetAbilitiesByTrigger")
local response4 = sendMessage("GetAbilitiesByTrigger", {Trigger = TRIGGER_TYPE.ON_CONTACT})
if not response4 then
    error("❌ Test 4 failed: No response received")
end
if response4.Action ~= "SaveState" then
    error("❌ Test 4 failed: Expected SaveState action")
end
if not response4.Data then
    error("❌ Test 4 failed: Expected Data field")
end
local triggerData = json.decode(response4.Data)
if type(triggerData) ~= "table" then
    error("❌ Test 4 failed: Expected table of abilities")
end
print("✅ Test 4 passed")

-- Test 5: Starter Abilities (Overgrow, Blaze, Torrent)
print("📝 Test 5: Starter Abilities")
local starterAbilities = {
    {id = ABILITY.OVERGROW, name = "Overgrow"},
    {id = ABILITY.BLAZE, name = "Blaze"},
    {id = ABILITY.TORRENT, name = "Torrent"}
}
for _, ability in ipairs(starterAbilities) do
    local resp = sendMessage("GetAbility", {Id = ability.id})
    if not resp or resp.Success ~= "true" then
        error("❌ Test 5 failed: Could not get " .. ability.name)
    end
    if resp.EffectType ~= EFFECT_TYPE.DAMAGE_MODIFY then
        error("❌ Test 5 failed: " .. ability.name .. " should be DAMAGE_MODIFY")
    end
end
print("✅ Test 5 passed")

-- Test 6: Contact Abilities
print("📝 Test 6: Contact Abilities")
local contactAbilities = {
    {id = ABILITY.STATIC, name = "Static"},
    {id = ABILITY.POISON_POINT, name = "Poison Point"}
}
for _, ability in ipairs(contactAbilities) do
    local resp = sendMessage("GetAbility", {Id = ability.id})
    if not resp or resp.Success ~= "true" then
        error("❌ Test 6 failed: Could not get " .. ability.name)
    end
    if resp.EffectType ~= EFFECT_TYPE.STATUS_INFLICT then
        error("❌ Test 6 failed: " .. ability.name .. " should be STATUS_INFLICT")
    end
end
print("✅ Test 6 passed")

-- Test 7: Absorption Abilities
print("📝 Test 7: Absorption Abilities")
local absorptionAbilities = {
    {id = ABILITY.VOLT_ABSORB, name = "Volt Absorb"},
    {id = ABILITY.WATER_ABSORB, name = "Water Absorb"},
    {id = ABILITY.FLASH_FIRE, name = "Flash Fire"}
}
for _, ability in ipairs(absorptionAbilities) do
    local resp = sendMessage("GetAbility", {Id = ability.id})
    if not resp or resp.Success ~= "true" then
        error("❌ Test 7 failed: Could not get " .. ability.name)
    end
    if resp.EffectType ~= EFFECT_TYPE.ABSORPTION then
        error("❌ Test 7 failed: " .. ability.name .. " should be ABSORPTION")
    end
end
print("✅ Test 7 passed")

-- Test 8: Weather Abilities
print("📝 Test 8: Weather Abilities")
local weatherAbilities = {
    {id = ABILITY.DRIZZLE, name = "Drizzle", effect = EFFECT_TYPE.WEATHER_SET},
    {id = ABILITY.DROUGHT, name = "Drought", effect = EFFECT_TYPE.WEATHER_SET},
    {id = ABILITY.CHLOROPHYLL, name = "Chlorophyll", effect = EFFECT_TYPE.STAT_BOOST},
    {id = ABILITY.SWIFT_SWIM, name = "Swift Swim", effect = EFFECT_TYPE.STAT_BOOST}
}
for _, ability in ipairs(weatherAbilities) do
    local resp = sendMessage("GetAbility", {Id = ability.id})
    if not resp or resp.Success ~= "true" then
        error("❌ Test 8 failed: Could not get " .. ability.name)
    end
    if resp.EffectType ~= ability.effect then
        error("❌ Test 8 failed: " .. ability.name .. " should be " .. ability.effect)
    end
end
print("✅ Test 8 passed")

-- Test 9: Immunity Abilities
print("📝 Test 9: Immunity Abilities")
local immunityAbilities = {
    {id = ABILITY.LIMBER, name = "Limber"},
    {id = ABILITY.IMMUNITY, name = "Immunity"},
    {id = ABILITY.LEVITATE, name = "Levitate"}
}
for _, ability in ipairs(immunityAbilities) do
    local resp = sendMessage("GetAbility", {Id = ability.id})
    if not resp or resp.Success ~= "true" then
        error("❌ Test 9 failed: Could not get " .. ability.name)
    end
    if resp.EffectType ~= EFFECT_TYPE.IMMUNITY then
        error("❌ Test 9 failed: " .. ability.name .. " should be IMMUNITY")
    end
end
print("✅ Test 9 passed")

-- Test 10: Stat Boost Abilities
print("📝 Test 10: Stat Boost Abilities")
local resp10 = sendMessage("GetAbility", {Id = ABILITY.HUGE_POWER})
if not resp10 or resp10.Success ~= "true" then
    error("❌ Test 10 failed: Could not get Huge Power")
end
if resp10.EffectType ~= EFFECT_TYPE.STAT_BOOST then
    error("❌ Test 10 failed: Huge Power should be STAT_BOOST")
end
if not resp10.Description or not string.find(resp10.Description, "Doubles") then
    error("❌ Test 10 failed: Description should mention doubling")
end
print("✅ Test 10 passed")

-- Test 11: Special Abilities
print("📝 Test 11: Special Abilities")
local specialAbilities = {
    {id = ABILITY.WONDER_GUARD, name = "Wonder Guard"},
    {id = ABILITY.PRESSURE, name = "Pressure"}
}
for _, ability in ipairs(specialAbilities) do
    local resp = sendMessage("GetAbility", {Id = ability.id})
    if not resp or resp.Success ~= "true" then
        error("❌ Test 11 failed: Could not get " .. ability.name)
    end
    if resp.AbilityName ~= ability.name then
        error("❌ Test 11 failed: Expected " .. ability.name)
    end
end
print("✅ Test 11 passed")

-- Test 12: GetAbilityActivation
print("📝 Test 12: GetAbilityActivation")
local resp12 = sendMessage("GetAbilityActivation", {Id = ABILITY.STATIC, Context = "contact"})
if not resp12 then
    error("❌ Test 12 failed: No response received")
end
if resp12.Action ~= "SaveState" then
    error("❌ Test 12 failed: Expected SaveState action")
end
if not resp12.Data then
    error("❌ Test 12 failed: Expected Data field")
end
local activationData = json.decode(resp12.Data)
if activationData.name ~= "Static" then
    error("❌ Test 12 failed: Expected Static ability activation")
end
if type(activationData.triggers) ~= "table" then
    error("❌ Test 12 failed: Expected triggers array")
end
print("✅ Test 12 passed")

-- Test 13: Invalid Queries - Missing required parameter
print("📝 Test 13: Invalid Queries - Missing Parameter")
local resp13 = sendMessage("GetAbility", {}) -- No Id or Name
if not resp13 then
    error("❌ Test 13 failed: No response received")
end
if not resp13.Error then
    error("❌ Test 13 failed: Expected Error field for invalid query")
end
print("✅ Test 13 passed")

-- Test 14: HealthCheck Handler
print("📝 Test 14: HealthCheck Handler")
local resp14 = sendMessage("HealthCheck")
if not resp14 then
    error("❌ Test 14 failed: No response received")
end
if resp14.Action ~= "SaveState" then
    error("❌ Test 14 failed: Expected SaveState action")
end
if not resp14.Data then
    error("❌ Test 14 failed: Expected Data field")
end
local healthData = resp14.Data
if healthData.status ~= "healthy" then
    error("❌ Test 14 failed: Expected healthy status")
end
print("✅ Test 14 passed")

-- Test 15: Response Format Compliance
print("📝 Test 15: Response Format Compliance")
local resp15 = sendMessage("GetAbility", {Id = ABILITY.COMPOUND_EYES})
if not resp15 then
    error("❌ Test 15 failed: No response received")
end
if resp15.Action ~= "SaveState" then
    error("❌ Test 15 failed: Response must use SaveState action")
end
if resp15.Success ~= "true" then
    error("❌ Test 15 failed: Successful query should have Success='true'")
end
print("✅ Test 15 passed")

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
print("Tests completed:")
print("  ✅ ADP v1.0 Compliance")
print("  ✅ GetAbility by ID")
print("  ✅ GetAbility by Name")
print("  ✅ GetAbilitiesByTrigger")
print("  ✅ Starter Abilities")
print("  ✅ Contact Abilities")
print("  ✅ Absorption Abilities")
print("  ✅ Weather Abilities")
print("  ✅ Immunity Abilities")
print("  ✅ Stat Boost Abilities")
print("  ✅ Special Abilities")
print("  ✅ GetAbilityActivation")
print("  ✅ Invalid Query Handling")
print("  ✅ HealthCheck Handler")
print("  ✅ Response Format Compliance")
