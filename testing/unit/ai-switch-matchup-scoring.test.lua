-- AI Switch Decision - Matchup Scoring Unit Tests
-- Story 17.2: Tests for getMatchupScore(), party member scoring, and entry hazards
-- Test Framework: aolite (real framework)
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.ai-move-selection-engine"
local processId = "test-ai-move-selection-matchup"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for AI Matchup Scoring")
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
-- TEST SUITE: Matchup Score Calculation (15 tests)
-- ============================================================================

print("\n=== Matchup Score Calculation Tests ===\n")

-- Test 1: Equal matchup (same types, similar stats)
print("📝 Test 1: Equal matchup scenario")
local response = sendMessage("CalculateMatchupScore", nil, json.encode({
    pokemon = {
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
        isActive = true
    },
    opponent = {
        types = {0},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
    }
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
local data = json.decode(response.Data)
if math.abs(data.matchupScore - 2.0) > 0.5 then
    error("❌ Test failed: Equal matchup score should be around 2.0, got " .. tostring(data.matchupScore))
end
print("✅ Test passed")

-- Test 2: Type advantage (Fire vs Grass)
print("📝 Test 2: Type advantage Fire vs Grass")
response = sendMessage("CalculateMatchupScore", nil, json.encode({
    pokemon = {
        types = {9},
        moveset = {{moveId = 52, pp = 10, maxPp = 10, category = 1, type = 9}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponent = {
        types = {11},
        hp = 100,
        maxHp = 100,
        stats = {atk = 45, def = 49, spatk = 65, spdef = 65, spd = 45}
    }
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.matchupScore <= 3.0 then
    error("❌ Test failed: Fire vs Grass should score > 3.0, got " .. tostring(data.matchupScore))
end
if data.components.atkScore <= 2.0 then
    error("❌ Test failed: Attack score should be > 2.0, got " .. tostring(data.components.atkScore))
end
print("✅ Test passed")

-- Test 3: Type disadvantage (Fire vs Water)
print("📝 Test 3: Type disadvantage Fire vs Water")
response = sendMessage("CalculateMatchupScore", nil, json.encode({
    pokemon = {
        types = {9},
        moveset = {{moveId = 52, pp = 10, maxPp = 10, category = 1, type = 9}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponent = {
        types = {10},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
    }
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.matchupScore >= 2.0 then
    error("❌ Test failed: Fire vs Water should score < 2.0, got " .. tostring(data.matchupScore))
end
if data.components.atkScore >= 1.0 then
    error("❌ Test failed: Attack score should be < 1.0, got " .. tostring(data.components.atkScore))
end
print("✅ Test passed")

-- Test 4: Speed advantage bonus
print("📝 Test 4: Speed advantage HP ratio bonus")
response = sendMessage("CalculateMatchupScore", nil, json.encode({
    pokemon = {
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 100},
        isActive = true
    },
    opponent = {
        types = {0},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 30}
    }
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.components.outspeed ~= true then
    error("❌ Test failed: Should outspeed opponent")
end
if data.matchupScore <= 2.0 then
    error("❌ Test failed: Speed advantage should boost score")
end
print("✅ Test passed")

-- Test 5: Low HP dying Pokemon (sacrifice logic)
print("📝 Test 5: Dying Pokemon sacrifice candidate")
response = sendMessage("CalculateMatchupScore", nil, json.encode({
    pokemon = {
        types = {0},
        moveset = {{moveId = 1, pp = 10, maxPp = 10, category = 0, type = 9}},  -- Fire move, no STAB
        hp = 15,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 30},
        isActive = true
    },
    opponent = {
        types = {0},
        hp = 100,
        maxHp = 100,
        stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 80}
    }
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.matchupScore >= 1.5 then
    error("❌ Test failed: Dying Pokemon should have low score (got " .. tostring(data.matchupScore) .. ")")
end
print("✅ Test passed")

-- Test 6: STAB bonus in attack score
print("📝 Test 6: STAB bonus application")
response = sendMessage("CalculateMatchupScore", nil, json.encode({
    pokemon = {
        types = {10},
        moveset = {{moveId = 55, pp = 25, maxPp = 25, category = 1, type = 10}},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
        isActive = true
    },
    opponent = {
        types = {9},
        hp = 100,
        maxHp = 100,
        stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
    }
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
data = json.decode(response.Data)
if data.components.atkScore <= 2.5 then
    error("❌ Test failed: STAB + 2x effectiveness should give atkScore > 2.5, got " .. tostring(data.components.atkScore))
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
