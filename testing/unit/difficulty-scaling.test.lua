-- Unit tests for Difficulty Scaling (getWaveForDifficulty) (CORRECT API)
-- Tests wave-to-difficulty mapping for all game modes

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.game-mode-engine"
local processId = "test-game-mode-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Difficulty Scaling")
print("Process ID:", processId)

-- Test utilities
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

-- Game Mode IDs (must match game-mode-engine.lua)
local GAME_MODES = {
    CLASSIC = 0,
    ENDLESS = 1,
    SPLICED_ENDLESS = 2,
    DAILY = 3,
    CHALLENGE = 4
}

-- ============================================================================
-- TEST SUITE: Daily Mode Difficulty Scaling
-- ============================================================================

print("\n=== Daily Mode Difficulty Scaling Tests ===\n")

-- Test: wave=1 → result=31 (1+30+0)
print("📝 Test: Daily mode wave 1 → 31")
local response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "1",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "31" then
    error("❌ Test failed: Expected 31, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- Test: wave=5 → result=36 (5+30+1)
print("📝 Test: Daily mode wave 5 → 36")
response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "5",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "36" then
    error("❌ Test failed: Expected 36, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- Test: wave=50 → result=90 (50+30+10)
print("📝 Test: Daily mode wave 50 → 90")
response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "50",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "90" then
    error("❌ Test failed: Expected 90, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUITE: Classic Mode (Passthrough)
-- ============================================================================

print("\n=== Classic Mode (Passthrough) Tests ===\n")

-- Test: Classic mode, wave=1 → result=1
print("📝 Test: Classic mode wave 1 → 1")
response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "1",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "1" then
    error("❌ Test failed: Expected 1, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- Test: Classic mode, wave=100 → result=100
print("📝 Test: Classic mode wave 100 → 100")
response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "100",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "100" then
    error("❌ Test failed: Expected 100, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUITE: Edge Cases
-- ============================================================================

print("\n=== Edge Cases Tests ===\n")

-- Test: wave=0 (Daily mode)
print("📝 Test: Daily mode wave 0 → 30")
response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.DAILY),
    WaveIndex = "0",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "30" then
    error("❌ Test failed: Expected 30, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- Test: wave=0 (Classic mode)
print("📝 Test: Classic mode wave 0 → 0")
response = sendMessage("GetWaveForDifficulty", {
    ModeId = tostring(GAME_MODES.CLASSIC),
    WaveIndex = "0",
    IgnoreCurveChanges = "false"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.EffectiveDifficulty ~= "0" then
    error("❌ Test failed: Expected 0, got " .. tostring(response.EffectiveDifficulty))
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
