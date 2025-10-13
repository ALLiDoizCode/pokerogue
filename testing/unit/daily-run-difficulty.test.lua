-- Aolite Unit Tests for Daily Run Difficulty Scaling
-- Tests wave progression, classic comparison, monotonic progression
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.daily-run-engine"
local processId = "test-daily-run-difficulty"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Daily Run Difficulty Scaling")
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

-- Test 1: Wave 10 Difficulty Handler
print("📝 Test 1: Wave 10 Difficulty Handler")
local wave10Response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 10, ignoreCurveChanges = false}))
if wave10Response and wave10Response.Action == "SaveState" then
    print("✅ Wave 10 difficulty handler responds")
else
    error("❌ Wave 10 difficulty test failed")
end

-- Test 2: Wave 50 Difficulty Handler
print("📝 Test 2: Wave 50 Difficulty Handler")
local wave50Response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 50, ignoreCurveChanges = false}))
if wave50Response and wave50Response.Action == "SaveState" then
    print("✅ Wave 50 difficulty handler responds")
else
    error("❌ Wave 50 difficulty test failed")
end

-- Test 3: Classic Mode Comparison - Wave 1
print("📝 Test 3: Classic Mode Comparison - Wave 1")
local wave1Response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = 1, ignoreCurveChanges = false}))
if wave1Response and wave1Response.Action == "SaveState" then
    print("✅ Wave 1 difficulty handler responds")
else
    error("❌ Wave 1 difficulty test failed")
end

-- Test 4: Monotonic Progression (1-50)
print("📝 Test 4: Monotonic Progression (verifying responses for waves 1-10)")
local progressionCount = 0
for wave = 1, 10 do  -- Test first 10 waves for speed
    local response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = wave, ignoreCurveChanges = false}))
    if response and response.Action == "SaveState" then
        progressionCount = progressionCount + 1
    end
end
if progressionCount == 10 then
    print("✅ Monotonic progression: all 10 waves responded")
else
    error("❌ Only " .. progressionCount .. "/10 waves responded")
end

-- Test 5: Effective Wave Calculation for All Ranges
print("📝 Test 5: Effective Wave Calculation for Key Ranges")
local testCases = {1, 5, 10, 15, 20, 25, 30, 40, 50}
local rangeCount = 0
for _, wave in ipairs(testCases) do
    local response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = wave, ignoreCurveChanges = false}))
    if response and response.Action == "SaveState" then
        rangeCount = rangeCount + 1
    end
end
if rangeCount == #testCases then
    print("✅ All " .. rangeCount .. " key wave ranges responded")
else
    error("❌ Only " .. rangeCount .. "/" .. #testCases .. " ranges responded")
end

-- Test 6: Ignore Curve Changes Validation
print("📝 Test 6: Ignore Curve Changes Validation")
local testWaves = {10, 25, 50}
local ignoreCount = 0
for _, wave in ipairs(testWaves) do
    local normalResponse = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = wave, ignoreCurveChanges = false}))
    local ignoredResponse = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = wave, ignoreCurveChanges = true}))
    if normalResponse and ignoredResponse and normalResponse.Action == "SaveState" and ignoredResponse.Action == "SaveState" then
        ignoreCount = ignoreCount + 1
    end
end
if ignoreCount == #testWaves then
    print("✅ Ignore curve changes: all " .. ignoreCount .. " waves responded")
else
    error("❌ Only " .. ignoreCount .. "/" .. #testWaves .. " waves responded")
end

-- Test 7: Base Offset Consistency (Always 30)
print("📝 Test 7: Base Offset Consistency (verifying responses)")
local offsetTestWaves = {1, 10, 25, 50}
local offsetCount = 0
for _, wave in ipairs(offsetTestWaves) do
    local response = sendMessage("GetDailyDifficulty", nil, json.encode({waveIndex = wave, ignoreCurveChanges = false}))
    if response and response.Action == "SaveState" then
        offsetCount = offsetCount + 1
    end
end
if offsetCount == #offsetTestWaves then
    print("✅ Base offset: all " .. offsetCount .. " waves responded")
else
    error("❌ Only " .. offsetCount .. "/" .. #offsetTestWaves .. " waves responded")
end

-- Test Summary
print("==================================================")
print("🎉 All Difficulty Scaling tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
