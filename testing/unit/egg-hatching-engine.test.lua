-- Unit Tests for Egg Hatching Engine
-- Tests egg step progression, hatching probability, and incubation modifiers
-- Rewritten from describe/it to linear execution for aolite framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.egg-hatching-engine"
local processId = "test-egg-hatching-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Egg Hatching Engine")
print("Process ID:", processId)

-- Test utility function
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

-- ============================================================================
-- Test 1: Info Handler (ADP v1.0 Compliance)
-- ============================================================================
print("📝 Test 1: Process info handler")
local infoResponse = sendMessage("Info")
if not infoResponse or infoResponse.Action ~= "Info-Response" then
    error("❌ Test 1 failed: Expected Info-Response action, got " .. tostring(infoResponse and infoResponse.Action or "nil"))
end
local infoData = json.decode(infoResponse.Data or "{}")
if not infoData.process or infoData.process.name ~= "Egg Hatching Engine" then
    error("❌ Test 1 failed: Expected process name 'Egg Hatching Engine'")
end
print("✅ Test 1 passed - Info handler returns process metadata")

-- ============================================================================
-- Test 2: Health Check Handler
-- ============================================================================
print("📝 Test 2: Health check handler")
local healthResponse = sendMessage("HealthCheck")
if not healthResponse or healthResponse.Action ~= "HealthCheckResponse" then
    error("❌ Test 2 failed: Expected HealthCheckResponse action")
end
if healthResponse.Status ~= "healthy" then
    error("❌ Test 2 failed: Expected healthy status")
end
print("✅ Test 2 passed - Health check returns healthy status")

-- ============================================================================
-- Test 3: Progress Steps - Basic Egg Progression
-- ============================================================================
print("📝 Test 3: Progress egg steps without modifiers")
local eggData = {
    eggId = "test-egg-1",
    species = 25, -- Pikachu
    steps = 0,
    requiredSteps = 2560, -- Common egg
    eggType = "COMMON"
}

local progressResponse = sendMessage("ProgressSteps", {
    StepsToAdd = "100"
}, json.encode(eggData))

if not progressResponse or progressResponse.Action ~= "SaveState" then
    error("❌ Test 3 failed: Expected SaveState action")
end

local progressData = json.decode(progressResponse.Data or "{}")
if not progressData.eggData or progressData.eggData.steps ~= 100 then
    error("❌ Test 3 failed: Expected 100 steps, got " .. tostring(progressData.eggData and progressData.eggData.steps or "nil"))
end
if progressData.readyToHatch ~= false then
    error("❌ Test 3 failed: Egg should not be ready to hatch yet")
end
print("✅ Test 3 passed - Egg steps progressed correctly")

-- ============================================================================
-- Test 4: Progress Steps with Flame Body Modifier (2x speed)
-- ============================================================================
print("📝 Test 4: Progress egg steps with Flame Body modifier")
local eggData2 = {
    eggId = "test-egg-2",
    species = 25,
    steps = 0,
    requiredSteps = 2560,
    eggType = "COMMON"
}

local modifiedProgressResponse = sendMessage("ProgressSteps", {
    StepsToAdd = "100"
}, json.encode({
    eggData = eggData2,
    modifiers = { FLAME_BODY = true }
}))

local modifiedData = json.decode(modifiedProgressResponse.Data or "{}")
if not modifiedData.eggData or modifiedData.eggData.steps ~= 200 then
    error("❌ Test 4 failed: Expected 200 steps (100 * 2x), got " .. tostring(modifiedData.eggData and modifiedData.eggData.steps or "nil"))
end
print("✅ Test 4 passed - Flame Body modifier doubles step progression")

-- ============================================================================
-- Test 5: Egg Ready to Hatch
-- ============================================================================
print("📝 Test 5: Egg becomes ready to hatch when steps >= required")
local eggData3 = {
    eggId = "test-egg-3",
    species = 25,
    steps = 2500,
    requiredSteps = 2560,
    eggType = "COMMON"
}

local hatchReadyResponse = sendMessage("ProgressSteps", {
    StepsToAdd = "100"
}, json.encode(eggData3))

local hatchReadyData = json.decode(hatchReadyResponse.Data or "{}")
if hatchReadyData.readyToHatch ~= true then
    error("❌ Test 5 failed: Egg should be ready to hatch (steps: " .. tostring(hatchReadyData.eggData.steps) .. ")")
end
print("✅ Test 5 passed - Egg marked as ready to hatch")

-- ============================================================================
-- Test 6: Hatch Egg Handler
-- ============================================================================
print("📝 Test 6: Hatch egg and generate Pokemon")
local hatchableEgg = {
    eggId = "test-egg-hatch",
    species = 25,
    steps = 2560,
    requiredSteps = 2560,
    eggType = "COMMON",
    sourceType = "WILD"
}

local hatchResponse = sendMessage("HatchEgg", {}, json.encode(hatchableEgg))

if not hatchResponse or hatchResponse.Action ~= "SaveState" then
    error("❌ Test 6 failed: Expected SaveState action for hatching")
end

local hatchData = json.decode(hatchResponse.Data or "{}")
if not hatchData.pokemon or not hatchData.pokemon.speciesId then
    error("❌ Test 6 failed: Expected hatched Pokemon data")
end
if hatchData.pokemon.speciesId ~= 25 then
    error("❌ Test 6 failed: Expected species 25, got " .. tostring(hatchData.pokemon.speciesId))
end
print("✅ Test 6 passed - Egg hatched successfully")

-- ============================================================================
-- Test 7: Error Handling - Missing Egg Data
-- ============================================================================
print("📝 Test 7: Error handling for missing egg data")
local errorResponse = sendMessage("ProgressSteps", {
    StepsToAdd = "100"
}, "")

if not errorResponse or errorResponse.Action ~= "Error" then
    error("❌ Test 7 failed: Expected Error action for missing data")
end
print("✅ Test 7 passed - Error handling works for missing data")

-- ============================================================================
-- Test 8: Get Hatch Timing
-- ============================================================================
print("📝 Test 8: Get hatch animation timing")
local timingResponse = sendMessage("GetHatchTiming", {
    EggType = "COMMON"
})

if not timingResponse or timingResponse.Action ~= "SaveState" then
    error("❌ Test 8 failed: Expected SaveState action")
end

local timingData = json.decode(timingResponse.Data or "{}")
if not timingData.timing or not timingData.timing.totalDuration then
    error("❌ Test 8 failed: Expected timing data")
end
print("✅ Test 8 passed - Hatch timing returned correctly")

-- ============================================================================
-- Test 9: Rare Egg Step Requirements
-- ============================================================================
print("📝 Test 9: Rare egg requires more steps")
local rareEgg = {
    eggId = "test-rare-egg",
    species = 147, -- Dratini
    steps = 0,
    requiredSteps = 6400, -- Rare egg
    eggType = "RARE"
}

local rareProgressResponse = sendMessage("ProgressSteps", {
    StepsToAdd = "2560"
}, json.encode(rareEgg))

local rareProgressData = json.decode(rareProgressResponse.Data or "{}")
if rareProgressData.readyToHatch == true then
    error("❌ Test 9 failed: Rare egg should not hatch with only 2560 steps")
end
if rareProgressData.eggData.steps ~= 2560 then
    error("❌ Test 9 failed: Expected 2560 steps")
end
print("✅ Test 9 passed - Rare egg requires more steps than common")

-- ============================================================================
-- Test 10: Epic Egg Step Requirements
-- ============================================================================
print("📝 Test 10: Epic egg requires even more steps")
local epicEgg = {
    eggId = "test-epic-egg",
    species = 443, -- Gible
    steps = 0,
    requiredSteps = 12800, -- Epic egg
    eggType = "EPIC"
}

local epicProgressResponse = sendMessage("ProgressSteps", {
    StepsToAdd = "6400"
}, json.encode(epicEgg))

local epicProgressData = json.decode(epicProgressResponse.Data or "{}")
if epicProgressData.readyToHatch == true then
    error("❌ Test 10 failed: Epic egg should not hatch with only 6400 steps")
end
print("✅ Test 10 passed - Epic egg requires 12800 steps")

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("")
print("Coverage Summary:")
print("  - ADP v1.0 compliance (Info handler)")
print("  - Health check handler")
print("  - Basic step progression")
print("  - Incubation modifiers (Flame Body)")
print("  - Hatch readiness detection")
print("  - Egg hatching and Pokemon generation")
print("  - Error handling")
print("  - Animation timing")
print("  - Egg tier step requirements (Common, Rare, Epic)")
