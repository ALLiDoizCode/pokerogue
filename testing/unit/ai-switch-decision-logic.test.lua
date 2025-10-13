-- AI Switch Decision Logic Unit Tests
-- Story 17.2: Tests for switch decision evaluation, dampening, and thresholds
-- Test Framework: aolite (real framework)
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.ai-move-selection-engine"
local processId = "test-ai-move-selection-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for AI Switch Decision Logic")
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

-- ============================================================================
-- TEST SUITE: Switch Decision Logic (15 tests)
-- ============================================================================

print("\n=== Switch Decision Logic Tests ===\n")

-- Test 1: Normal trainer 3x threshold - should not switch
print("📝 Test 1: Normal trainer 3x threshold blocks switch")
local response = sendMessage("EvaluateSwitchDecision", nil, json.encode({
    hasTrainer = true,
    hasMoveQueue = false,
    isTrapped = false,
    currentPokemon = {
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
        isActive = true
    },
    opponents = {{
        types = {0},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
    }},
    partyMembers = {{
        partyIndex = 2,
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 60}
    }},
    isBoss = false,
    enemySwitchCounter = 1,
    battleSeed = 12345,
    battleTurn = 1
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
local data = json.decode(response.Data)
if data.shouldSwitch ~= false then
    error("❌ Test failed: Normal trainer should not switch with moderate advantage")
end
if data.threshold ~= 3 then
    error("❌ Test failed: Normal trainer threshold should be 3")
end
print("✅ Test passed")

-- Test 2: Boss trainer 2x threshold - should switch
print("📝 Test 2: Boss trainer 2x threshold allows switch")
response = sendMessage("EvaluateSwitchDecision", nil, json.encode({
    hasTrainer = true,
    hasMoveQueue = false,
    isTrapped = false,
    currentPokemon = {
        types = {9},
        moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
        hp = 50,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponents = {{
        types = {10},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
    }},
    partyMembers = {{
        partyIndex = 2,
        types = {11},
        moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
    }},
    isBoss = true,
    enemySwitchCounter = 1,
    battleSeed = 12345,
    battleTurn = 1
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.shouldSwitch ~= true then
    error("❌ Test failed: Boss trainer should switch with type advantage")
end
if data.threshold ~= 2 then
    error("❌ Test failed: Boss trainer threshold should be 2")
end
print("✅ Test passed")

-- Test 3: First switch (counter=1) no dampening
print("📝 Test 3: First switch no dampening multiplier")
response = sendMessage("EvaluateSwitchDecision", nil, json.encode({
    hasTrainer = true,
    hasMoveQueue = false,
    isTrapped = false,
    currentPokemon = {
        types = {9},
        moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponents = {{
        types = {10},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
    }},
    partyMembers = {{
        partyIndex = 2,
        types = {11},
        moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
    }},
    isBoss = true,
    enemySwitchCounter = 0,  -- TypeScript enemySwitchCounter starts at 0
    battleSeed = 12345,
    battleTurn = 1
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if math.abs(data.switchMultiplier - 1.0) > 0.01 then
    error("❌ Test failed: Counter=0 (no switches) should have multiplier 1.0, got " .. tostring(data.switchMultiplier))
end
print("✅ Test passed")

-- Test 4: First switch (counter=1) ~0.9 dampening
print("📝 Test 4: First switch dampening ~0.9")
response = sendMessage("EvaluateSwitchDecision", nil, json.encode({
    hasTrainer = true,
    hasMoveQueue = false,
    isTrapped = false,
    currentPokemon = {
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
        isActive = true
    },
    opponents = {{
        types = {0},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
    }},
    partyMembers = {{
        partyIndex = 2,
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 60}
    }},
    isBoss = false,
    enemySwitchCounter = 1,  -- TypeScript: first switch has counter=1
    battleSeed = 12345,
    battleTurn = 1
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if math.abs(data.switchMultiplier - 0.9) > 0.05 then
    error("❌ Test failed: First switch (counter=1) should have multiplier ~0.9, got " .. tostring(data.switchMultiplier))
end
print("✅ Test passed")

-- Test 5: Trapped Pokemon blocks switch
print("📝 Test 5: Trapped Pokemon cannot switch")
response = sendMessage("EvaluateSwitchDecision", nil, json.encode({
    hasTrainer = true,
    hasMoveQueue = false,
    isTrapped = true,
    currentPokemon = {
        types = {9},
        moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
        hp = 50,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponents = {{
        types = {10},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
    }},
    partyMembers = {{
        partyIndex = 2,
        types = {11},
        moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
    }},
    isBoss = true,
    enemySwitchCounter = 1,
    battleSeed = 12345,
    battleTurn = 1
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.shouldSwitch ~= false then
    error("❌ Test failed: Trapped Pokemon cannot switch")
end
print("✅ Test passed")

-- Test 6: Wild Pokemon never switches
print("📝 Test 6: Wild Pokemon never switch")
response = sendMessage("EvaluateSwitchDecision", nil, json.encode({
    hasTrainer = false,
    hasMoveQueue = false,
    isTrapped = false,
    currentPokemon = {
        types = {9},
        moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
        hp = 10,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponents = {{
        types = {10},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
    }},
    partyMembers = {},
    isBoss = false,
    enemySwitchCounter = 0,
    battleSeed = 12345,
    battleTurn = 1
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.shouldSwitch ~= false then
    error("❌ Test failed: Wild Pokemon should never switch")
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
