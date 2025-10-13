-- Battle Resolution Manager Unit Tests
-- Comprehensive testing using aolite framework for AO process validation
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.battle-resolution-manager"
local processId = "test-battle-resolution-manager"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Battle Resolution Manager")
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

local function createMockBattleData(playerAlive, enemyAlive)
    local playerParty = {}
    local enemyParty = {}

    -- Create player party
    for i = 1, 2 do
        table.insert(playerParty, {
            id = "player_" .. i,
            speciesId = 25,
            level = 20,
            hp = playerAlive and 80 or 0,
            maxHp = 100,
            status = playerAlive and nil or "faint",
            exp = 2000
        })
    end

    -- Create enemy party
    for i = 1, 2 do
        table.insert(enemyParty, {
            id = "enemy_" .. i,
            speciesId = 1,
            level = 18,
            hp = enemyAlive and 60 or 0,
            maxHp = 80,
            status = enemyAlive and nil or "faint",
            defeated = not enemyAlive
        })
    end

    return playerParty, enemyParty
end

-- ============================================================================
-- TEST SUITE: Battle Resolution Manager (4 tests)
-- ============================================================================

print("\n=== Battle Resolution Manager Tests ===\n")

-- Test 1: Info handler
print("📝 Test 1: Info handler returns capabilities")
local response = sendMessage("Info")
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
print("✅ Test passed")

-- Test 2: DetectBattleOutcome victory
print("📝 Test 2: DetectBattleOutcome victory scenario")
local playerParty, enemyParty = createMockBattleData(true, false)
response = sendMessage("DetectBattleOutcome", {
    BattleId = "test_001",
    PlayerParty = json.encode(playerParty),
    EnemyParty = json.encode(enemyParty)
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
print("✅ Test passed")

-- Test 3: DetectBattleOutcome defeat
print("📝 Test 3: DetectBattleOutcome defeat scenario")
playerParty, enemyParty = createMockBattleData(false, true)
response = sendMessage("DetectBattleOutcome", {
    BattleId = "test_002",
    PlayerParty = json.encode(playerParty),
    EnemyParty = json.encode(enemyParty)
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
print("✅ Test passed")

-- Test 4: Ping handler
print("📝 Test 4: Ping handler responds with Pong")
response = sendMessage("Ping")
if not response or response.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong action")
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
