-- Aolite Unit Tests for Abilities and Nature Manager
-- Tests nature multipliers and ability system with exact TypeScript parity
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local TEST_TIMEOUT = 30000 -- 30 seconds
local PROCESS_PATH = "processes/abilities-nature-manager.lua"

-- Initialize test process
local process = aolite.spawnProcess(PROCESS_PATH)
if not process then
    error("Failed to spawn process from " .. PROCESS_PATH)
end

print("🧪 Starting Aolite Tests for Abilities and Nature Manager")
print("Process ID:", process.id)

-- Test utilities
local function sendMessage(action, tags, data, timeout)
    local msg = {
        Target = process.id,
        Action = action,
        Data = data or "",
        Timestamp = os.time() * 1000
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    return aolite.send(msg, timeout or TEST_TIMEOUT)
end

local function assertSuccess(response, testName)
    if not response then
        error(testName .. ": No response received")
    end

    if response.Error then
        error(testName .. ": " .. response.Error)
    end

    local data = response.Data and json.decode(response.Data) or {}
    if not data.success then
        error(testName .. ": Expected success=true, got " .. tostring(data.success))
    end

    return data
end

-- Test 1: Process Ping
print("📝 Test 1: Process Ping")
local pingResponse = sendMessage("Ping")
if pingResponse and pingResponse.Action == "Pong" then
    print("✅ Ping test passed")
else
    error("❌ Ping test failed")
end

-- Test 2: Nature Generation and Assignment
print("📝 Test 2: Nature Generation and Assignment")
local natureResponse = sendMessage("GenerateNature", {
    PokemonId = "1",
    Species = "25" -- Pikachu
})
local natureData = assertSuccess(natureResponse, "Generate Nature")
if natureData.nature and natureData.nature.name then
    print("✅ Nature generation test passed - Nature: " .. natureData.nature.name)
else
    error("❌ Nature generation test failed - missing nature data")
end

-- Test 3: Nature Stat Multiplier Calculation
print("📝 Test 3: Nature Stat Multiplier Calculation")
local multiplierResponse = sendMessage("CalculateNatureMultiplier", {
    Nature = "Adamant",
    Stat = "ATK"
})
local multiplierData = assertSuccess(multiplierResponse, "Calculate Nature Multiplier")
if multiplierData.multiplier == 1.1 then
    print("✅ Nature multiplier test passed - Adamant ATK: " .. multiplierData.multiplier)
else
    error("❌ Nature multiplier test failed - expected 1.1, got " .. tostring(multiplierData.multiplier))
end

-- Test 4: Ability Assignment
print("📝 Test 4: Ability Assignment")
local abilityResponse = sendMessage("AssignAbility", {
    PokemonId = "1",
    AbilitySlot = "1",
    Species = "25" -- Pikachu
})
local abilityData = assertSuccess(abilityResponse, "Assign Ability")
if abilityData.ability and abilityData.ability.name then
    print("✅ Ability assignment test passed - Ability: " .. abilityData.ability.name)
else
    error("❌ Ability assignment test failed - missing ability data")
end

-- Test 5: Ability Effect Processing
print("📝 Test 5: Ability Effect Processing")
local effectResponse = sendMessage("ProcessAbilityEffect", {
    PokemonId = "1",
    Ability = "Static",
    Context = "contact",
    Data = json.encode({damage = 100})
})
local effectData = assertSuccess(effectResponse, "Process Ability Effect")
if effectData then
    print("✅ Ability effect processing test passed")
else
    error("❌ Ability effect processing test failed")
end

-- Test 6: Info Handler (ADP v1.0 Compliance)
print("📝 Test 6: Info Handler (ADP v1.0 Compliance)")
local infoResponse = sendMessage("Info")
local infoData = assertSuccess(infoResponse, "Info Handler")
if infoData.Name and infoData.handlers then
    print("✅ ADP v1.0 Info handler test passed")
else
    error("❌ ADP v1.0 Info handler test failed")
end

-- Test 7: Neutral Nature Test
print("📝 Test 7: Neutral Nature Test")
local neutralResponse = sendMessage("CalculateNatureMultiplier", {
    Nature = "Hardy",
    Stat = "ATK"
})
local neutralData = assertSuccess(neutralResponse, "Neutral Nature")
if neutralData.multiplier == 1.0 then
    print("✅ Neutral nature test passed - Hardy ATK: " .. neutralData.multiplier)
else
    error("❌ Neutral nature test failed - expected 1.0, got " .. tostring(neutralData.multiplier))
end

-- Test 8: Decreased Stat Nature Test
print("📝 Test 8: Decreased Stat Nature Test")
local decreaseResponse = sendMessage("CalculateNatureMultiplier", {
    Nature = "Adamant",
    Stat = "SPATK"
})
local decreaseData = assertSuccess(decreaseResponse, "Decreased Stat Nature")
if decreaseData.multiplier == 0.9 then
    print("✅ Decreased stat nature test passed - Adamant SPATK: " .. decreaseData.multiplier)
else
    error("❌ Decreased stat nature test failed - expected 0.9, got " .. tostring(decreaseData.multiplier))
end

-- Test Summary
print("==================================================")
print("🎉 All Abilities and Nature Manager tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)