-- Test file for processes/environmental-interaction-engine.lua
-- Tests weather-terrain interactions, effect stacking, and environmental coordination

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.environmental-interaction-engine"
local processId = "test-environmental-interaction-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Environmental Interaction Engine")
print("Process ID:", processId)

local function sendMessage(action, tags, data)
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

local testsPassed = 0
local testsFailed = 0

-- Test 1: Process Weather-Terrain Interactions
print("📝 Test 1: Weather-Terrain Interactions")
local interactionResult = sendMessage("ProcessEnvironmentalInteraction", nil, json.encode({
    weather = { type = "RAIN", turnsLeft = 5 },
    terrain = { type = "GRASSY", turnsLeft = 5 },
    activePokemon = {
        { speciesId = 25, types = { "ELECTRIC" }, hp = 100, maxHp = 100 }
    }
}))
if interactionResult and interactionResult.Action == "SaveState" then
    local interactionData = json.decode(interactionResult.Data or "{}")
    if interactionData.interactions then
        print("✅ Test passed: Weather-terrain interactions processed")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Interactions missing")
    end
else
    error("❌ Test failed: ProcessEnvironmentalInteraction handler failed")
end

-- Test 2: Check Weather-Terrain Combo
print("📝 Test 2: Weather-Terrain Combo Detection")
local comboResult = sendMessage("CheckWeatherTerrainCombo", {
    Weather = "RAIN",
    Terrain = "ELECTRIC"
})
if comboResult and comboResult.Action == "SaveState" then
    local comboData = json.decode(comboResult.Data or "{}")
    if comboData.hasCombo ~= nil then
        print("✅ Test passed: Weather-terrain combo checked")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Combo detection incomplete")
    end
else
    error("❌ Test failed: CheckWeatherTerrainCombo handler failed")
end

-- Test 3: Process Environmental Turn
print("📝 Test 3: Environmental Turn Processing")
local turnResult = sendMessage("ProcessEnvironmentalTurn", nil, json.encode({
    weather = { type = "SANDSTORM", turnsLeft = 3 },
    terrain = { type = "PSYCHIC", turnsLeft = 4 },
    activePokemon = {
        { speciesId = 1, types = { "GRASS", "POISON" }, hp = 100, maxHp = 100 }
    }
}))
if turnResult and turnResult.Action == "SaveState" then
    local turnData = json.decode(turnResult.Data or "{}")
    if turnData.effects then
        print("✅ Test passed: Environmental turn processing works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Turn effects missing")
    end
else
    error("❌ Test failed: ProcessEnvironmentalTurn handler failed")
end

-- Test 4: Healing Terrain Effects
print("📝 Test 4: Healing Terrain Effects")
local healingResult = sendMessage("ProcessEnvironmentalTurn", nil, json.encode({
    weather = { type = "NONE" },
    terrain = { type = "GRASSY", turnsLeft = 5 },
    activePokemon = {
        { speciesId = 25, types = { "ELECTRIC" }, hp = 50, maxHp = 100, isGrounded = true }
    }
}))
if healingResult and healingResult.Action == "SaveState" then
    local healingData = json.decode(healingResult.Data or "{}")
    if healingData.effects then
        print("✅ Test passed: Healing terrain effects processed")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Healing effects missing")
    end
else
    error("❌ Test failed: Healing terrain test failed")
end

-- Test 5: Damage-Dealing Weather
print("📝 Test 5: Damage-Dealing Weather")
local damageResult = sendMessage("ProcessEnvironmentalTurn", nil, json.encode({
    weather = { type = "HAIL", turnsLeft = 5 },
    terrain = { type = "NONE" },
    activePokemon = {
        { speciesId = 4, types = { "FIRE" }, hp = 100, maxHp = 100 }
    }
}))
if damageResult and damageResult.Action == "SaveState" then
    local damageData = json.decode(damageResult.Data or "{}")
    if damageData.effects then
        print("✅ Test passed: Damage-dealing weather processed")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Weather damage effects missing")
    end
else
    error("❌ Test failed: Damage weather test failed")
end

-- Test 6: Resolve Environmental Conflicts
print("📝 Test 6: Environmental Conflicts Resolution")
local conflictResult = sendMessage("ResolveEnvironmentalConflicts", nil, json.encode({
    { type = "weather", current = "RAIN", new = "SUN" },
    { type = "terrain", current = "ELECTRIC", new = "GRASSY" }
}))
if conflictResult and conflictResult.Action == "SaveState" then
    local conflictData = json.decode(conflictResult.Data or "{}")
    if conflictData.resolutions then
        print("✅ Test passed: Environmental conflicts resolved")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Conflict resolutions missing")
    end
else
    error("❌ Test failed: ResolveEnvironmentalConflicts handler failed")
end

-- Test 7: Info Handler
print("📝 Test 7: Info Handler (ADP v1.0)")
local infoResult = sendMessage("Info")
if infoResult and infoResult.Action == "SaveState" then
    local infoData = json.decode(infoResult.Data or "{}")
    if infoData.process and infoData.process.adpVersion == "1.0" then
        print("✅ Test passed: ADP v1.0 compliant")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: ADP compliance incorrect")
    end
else
    error("❌ Test failed: Info handler failed")
end

-- Test 8: Ping Handler
print("📝 Test 8: Ping Handler")
local pingResult = sendMessage("Ping")
if pingResult and pingResult.Action == "Pong" then
    print("✅ Test passed: Ping handler works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Ping handler failed")
end

-- Test 9: Error Handling
print("📝 Test 9: Error Handling")
local errorResult = sendMessage("ProcessEnvironmentalInteraction", nil, "invalid json")
if errorResult and errorResult.Action == "Error" then
    print("✅ Test passed: Error handling works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Error handling not working")
end

print("==================================================")
print("Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. (testsPassed + testsFailed))

if testsFailed == 0 then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n❌ Some tests failed!")
end
