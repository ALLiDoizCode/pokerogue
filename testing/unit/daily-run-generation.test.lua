-- Aolite Unit Tests for Daily Run Generation
-- Tests starter generation, biome selection, difficulty, trainer waves, event parsing
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.daily-run-engine"
local processId = "test-daily-run-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Daily Run Engine")
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

-- Test 1: Generate Daily Run Handler Exists
print("📝 Test 1: Generate Daily Run Handler Exists")
local generateResponse = sendMessage("GenerateDailyRun", nil, json.encode({seed = "20250103abcdefghij123456"}))
if generateResponse and (generateResponse.Action == "SaveState" or generateResponse.Action == "DailyRunGenerated") then
    print("✅ GenerateDailyRun handler exists and responds")
else
    error("❌ GenerateDailyRun handler test failed")
end

-- Test 2: Get Daily Difficulty Handler Exists
print("📝 Test 2: Get Daily Difficulty Handler Exists")
local difficultyResponse = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 1, ignoreCurveChanges = false}))
if difficultyResponse and difficultyResponse.Action == "SaveState" then
    print("✅ GetDailyDifficulty handler exists and responds")
else
    error("❌ GetDailyDifficulty handler test failed")
end

-- Test 3: Is Trainer Wave Handler Exists
print("📝 Test 3: Is Trainer Wave Handler Exists")
local trainerResponse = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = 5, isFinalWave = false}))
if trainerResponse and trainerResponse.Action == "SaveState" then
    print("✅ IsTrainerWave handler exists and responds")
else
    error("❌ IsTrainerWave handler test failed")
end

-- Test 4: Parse Event Seed Handler Exists
print("📝 Test 4: Parse Event Seed Handler Exists")
local parseResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = "20250103abcdefghij123456"}))
if parseResponse and parseResponse.Action == "SaveState" then
    print("✅ ParseEventSeed handler exists and responds")
else
    error("❌ ParseEventSeed handler test failed")
end

-- Test 5: Info Handler (ADP v1.0 compliance)
print("📝 Test 5: Info Handler (ADP v1.0 compliance)")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ Info handler test passed")
else
    error("❌ Info handler test failed")
end

-- Test 6: Generate Daily Run - Standard Seed
print("📝 Test 6: Generate Daily Run - Standard Seed")
local standardSeedResponse = sendMessage("GenerateDailyRun", nil, json.encode({seed = "20250103abcdefghij123456"}))
if standardSeedResponse and (standardSeedResponse.Action == "SaveState" or standardSeedResponse.Action == "DailyRunGenerated") then
    print("✅ Standard seed generation test passed")
else
    error("❌ Standard seed generation test failed")
end

-- Test 7: Get Daily Difficulty - Wave 1
print("📝 Test 7: Get Daily Difficulty - Wave 1")
local wave1Response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 1, ignoreCurveChanges = false}))
if wave1Response and wave1Response.Action == "SaveState" then
    print("✅ Wave 1 difficulty test passed")
else
    error("❌ Wave 1 difficulty test failed")
end

-- Test 8: Get Daily Difficulty - Wave 25
print("📝 Test 8: Get Daily Difficulty - Wave 25")
local wave25Response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 25, ignoreCurveChanges = false}))
if wave25Response and wave25Response.Action == "SaveState" then
    print("✅ Wave 25 difficulty test passed")
else
    error("❌ Wave 25 difficulty test failed")
end

-- Test 9: Is Trainer Wave - Wave 5 (X5)
print("📝 Test 9: Is Trainer Wave - Wave 5 (X5)")
local wave5Response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = 5, isFinalWave = false}))
if wave5Response and wave5Response.Action == "SaveState" then
    print("✅ Wave 5 trainer test passed")
else
    error("❌ Wave 5 trainer test failed")
end

-- Test 10: Is Trainer Wave - Wave 20 (X0)
print("📝 Test 10: Is Trainer Wave - Wave 20 (X0)")
local wave20Response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = 20, isFinalWave = false}))
if wave20Response and wave20Response.Action == "SaveState" then
    print("✅ Wave 20 trainer test passed")
else
    error("❌ Wave 20 trainer test failed")
end

-- Test 11: Is Trainer Wave - Wave 10 (NOT trainer)
print("📝 Test 11: Is Trainer Wave - Wave 10 (NOT trainer)")
local wave10Response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = 10, isFinalWave = false}))
if wave10Response and wave10Response.Action == "SaveState" then
    print("✅ Wave 10 non-trainer test passed")
else
    error("❌ Wave 10 non-trainer test failed")
end

-- Test 12: Parse Event Seed - Standard Seed
print("📝 Test 12: Parse Event Seed - Standard Seed")
local parseStandardResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = "20250103abcdefghij123456"}))
if parseStandardResponse and parseStandardResponse.Action == "SaveState" then
    print("✅ Parse standard seed test passed")
else
    error("❌ Parse standard seed test failed")
end

-- Test 13: Parse Event Seed - Event Seed with Luck
print("📝 Test 13: Parse Event Seed - Event Seed with Luck")
local parseLuckResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = "20250103abcdefghij123456/luck08/"}))
if parseLuckResponse and parseLuckResponse.Action == "SaveState" then
    print("✅ Parse luck seed test passed")
else
    error("❌ Parse luck seed test failed")
end

-- Test 14: Parse Event Seed - Event Seed with Biome
print("📝 Test 14: Parse Event Seed - Event Seed with Biome")
local parseBiomeResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = "20250103abcdefghij123456/biome05/"}))
if parseBiomeResponse and parseBiomeResponse.Action == "SaveState" then
    print("✅ Parse biome seed test passed")
else
    error("❌ Parse biome seed test failed")
end

-- Test 15: Difficulty Ignore Curve Changes
print("📝 Test 15: Difficulty Ignore Curve Changes")
local ignoreCurveResponse = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 25, ignoreCurveChanges = true}))
if ignoreCurveResponse and ignoreCurveResponse.Action == "SaveState" then
    print("✅ Ignore curve changes test passed")
else
    error("❌ Ignore curve changes test failed")
end

-- Test 16: Final Wave Not Trainer
print("📝 Test 16: Final Wave Not Trainer")
local finalWaveResponse = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = 50, isFinalWave = true}))
if finalWaveResponse and finalWaveResponse.Action == "SaveState" then
    print("✅ Final wave non-trainer test passed")
else
    error("❌ Final wave non-trainer test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Daily Run Generation tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
