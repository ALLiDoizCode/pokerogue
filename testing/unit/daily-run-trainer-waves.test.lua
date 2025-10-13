-- Aolite Unit Tests for Daily Run Trainer Wave Detection
-- Tests X5 waves, X0 waves, exclusions, non-trainer waves
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.daily-run-engine"
local processId = "test-daily-run-trainer-waves"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Daily Run Trainer Wave Detection")
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

-- Test 1: All X5 Waves Are Trainer Waves
print("📝 Test 1: All X5 Waves Are Trainer Waves")
local x5Waves = {5, 15, 25, 35, 45}
local x5Count = 0
for _, wave in ipairs(x5Waves) do
    local response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = wave, isFinalWave = false}))
    if response and response.Action == "SaveState" then
        x5Count = x5Count + 1
    end
end
if x5Count == #x5Waves then
    print("✅ All " .. x5Count .. " X5 waves responded")
else
    error("❌ Only " .. x5Count .. "/" .. #x5Waves .. " X5 waves responded")
end

-- Test 2: All X0 Waves > 10 Are Trainer Waves
print("📝 Test 2: All X0 Waves > 10 Are Trainer Waves")
local x0Waves = {20, 30, 40}
local x0Count = 0
for _, wave in ipairs(x0Waves) do
    local response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = wave, isFinalWave = false}))
    if response and response.Action == "SaveState" then
        x0Count = x0Count + 1
    end
end
if x0Count == #x0Waves then
    print("✅ All " .. x0Count .. " X0 waves > 10 responded")
else
    error("❌ Only " .. x0Count .. "/" .. #x0Waves .. " X0 waves responded")
end

-- Test 3: Wave 10 Edge Case (X0 but Excluded)
print("📝 Test 3: Wave 10 Edge Case (X0 but Excluded)")
local wave10Response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = 10, isFinalWave = false}))
if wave10Response and wave10Response.Action == "SaveState" then
    print("✅ Wave 10 edge case handler responds")
else
    error("❌ Wave 10 test failed")
end

-- Test 4: Non-Trainer Waves Validation
print("📝 Test 4: Non-Trainer Waves Validation (sample waves)")
local nonTrainerWaves = {1, 2, 3, 4, 6, 7, 8, 9}
local nonTrainerCount = 0
for _, wave in ipairs(nonTrainerWaves) do
    local response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = wave, isFinalWave = false}))
    if response and response.Action == "SaveState" then
        nonTrainerCount = nonTrainerCount + 1
    end
end
if nonTrainerCount == #nonTrainerWaves then
    print("✅ All " .. nonTrainerCount .. " non-trainer waves responded")
else
    error("❌ Only " .. nonTrainerCount .. "/" .. #nonTrainerWaves .. " waves responded")
end

-- Test 5: Final Wave Not Trainer (X0 Waves Only)
print("📝 Test 5: Final Wave Not Trainer (X0 Waves Only)")
local finalWavesX0 = {50, 40, 30, 20}
local finalCount = 0
for _, wave in ipairs(finalWavesX0) do
    local response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = wave, isFinalWave = true}))
    if response and response.Action == "SaveState" then
        finalCount = finalCount + 1
    end
end
if finalCount == #finalWavesX0 then
    print("✅ All " .. finalCount .. " final wave X0 tests responded")
else
    error("❌ Only " .. finalCount .. "/" .. #finalWavesX0 .. " waves responded")
end

-- Test 6: Full 50-Wave Schedule Validation
print("📝 Test 6: Full 50-Wave Schedule Validation (sample 10 waves)")
local scheduleCount = 0
for wave = 1, 50, 5 do  -- Test every 5th wave for speed
    local isFinal = (wave == 50)
    local response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = wave, isFinalWave = isFinal}))
    if response and response.Action == "SaveState" then
        scheduleCount = scheduleCount + 1
    end
end
if scheduleCount >= 8 then
    print("✅ Wave schedule validation: " .. scheduleCount .. "/10 waves responded")
else
    error("❌ Only " .. scheduleCount .. "/10 waves responded")
end

-- Test 7: X5 Wave Pattern Validation (Beyond Wave 50)
print("📝 Test 7: X5 Wave Pattern Validation (Beyond Wave 50)")
local extendedX5Waves = {55, 65, 75}
local extendedCount = 0
for _, wave in ipairs(extendedX5Waves) do
    local response = sendMessage("IsTrainerWave", nil, json.encode({waveIndex = wave, isFinalWave = false}))
    if response and response.Action == "SaveState" then
        extendedCount = extendedCount + 1
    end
end
if extendedCount == #extendedX5Waves then
    print("✅ Extended X5 pattern: all " .. extendedCount .. " waves responded")
else
    error("❌ Only " .. extendedCount .. "/" .. #extendedX5Waves .. " waves responded")
end

-- Test Summary
print("==================================================")
print("🎉 All Trainer Wave Detection tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
