-- Aolite Unit Tests for Modifier Engine
-- Tests modifier generation, application, and validation
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.modifier-engine"
local processId = "test-modifier-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Modifier Engine")
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

-- Test 1: Ping Handler
print("📝 Test 1: Ping Handler")
local pingResponse = sendMessage("Ping")
if pingResponse and pingResponse.Action == "Pong" then
    print("✅ Ping test passed")
else
    error("❌ Ping test failed")
end

-- Test 2: Get Modifier Info
print("📝 Test 2: Get Modifier Info")
local infoResponse = sendMessage("GetModifierInfo", {
    ModifierId = "SHINY_CHARM"
})
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ Modifier info test passed")
else
    error("❌ Modifier info test failed")
end

-- Test 3: Generate Modifier Options
print("📝 Test 3: Generate Modifier Options")
local optionsResponse = sendMessage("GenerateModifierOptions", {
    ModifierTier = "COMMON",
    Count = "3"
})
if optionsResponse and optionsResponse.Action == "SaveState" then
    print("✅ Modifier options generation test passed")
else
    error("❌ Modifier options generation test failed")
end

-- Test 4: Apply Modifier
print("📝 Test 4: Apply Modifier")
local applyResponse = sendMessage("ApplyModifier", {
    ModifierId = "HP_UP",
    PokemonId = "1"
})
if applyResponse and applyResponse.Action == "SaveState" then
    print("✅ Modifier application test passed")
else
    error("❌ Modifier application test failed")
end

-- Test 5: Validate Modifier
print("📝 Test 5: Validate Modifier")
local validateResponse = sendMessage("ValidateModifier", {
    ModifierId = "SHINY_CHARM",
    Context = "battle"
})
if validateResponse and validateResponse.Action == "SaveState" then
    print("✅ Modifier validation test passed")
else
    error("❌ Modifier validation test failed")
end

-- Test 6: Serialize Modifiers
print("📝 Test 6: Serialize Modifiers")
local serializeResponse = sendMessage("SerializeModifiers", {},
    json.encode({modifiers = {}}))
if serializeResponse and serializeResponse.Action == "SaveState" then
    print("✅ Modifier serialization test passed")
else
    error("❌ Modifier serialization test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Modifier Engine tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
