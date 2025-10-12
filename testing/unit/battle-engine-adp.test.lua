-- Unit Tests for ADP-Compliant Battle Engine Process
-- Validates ADP v1.0 compliance, deterministic RNG, and battle mechanics
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.battle-engine-adp"
local processId = "test-battle-engine-adp"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Battle Engine ADP")
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

-- Test counter
local tests_passed = 0
local tests_failed = 0

-- Test ADP v1.0 Info Handler
print("📝 Test 1: ADP v1.0 Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    local infoData = json.decode(infoResponse.Data or "{}")
    if infoData.process and infoData.process.adpVersion == "1.0" and infoData.process.name == "Battle Engine ADP" then
        print("✅ Test passed: ADP metadata structure valid")
        tests_passed = tests_passed + 1
    else
        error("❌ Test failed: ADP metadata structure invalid")
    end
else
    error("❌ Test failed: Info handler did not return SaveState")
end

-- Test type effectiveness calculation
print("📝 Test 2: Type Effectiveness Calculation")
local effectiveness = sendMessage("GetTypeEffectiveness", {
    AttackType = "fire",
    DefendType1 = "grass"
})
if effectiveness and effectiveness.Action == "SaveState" then
    local effectData = json.decode(effectiveness.Data or "{}")
    if effectData.effectiveness == 2 then
        print("✅ Test passed: Fire vs Grass = 2x effective")
        tests_passed = tests_passed + 1
    else
        error("❌ Test failed: Fire vs Grass effectiveness incorrect")
    end
else
    error("❌ Test failed: GetTypeEffectiveness handler failed")
end

-- Test dual-type effectiveness
print("📝 Test 3: Dual-Type Effectiveness")
local dualEffect = sendMessage("GetTypeEffectiveness", {
    AttackType = "fighting",
    DefendType1 = "normal",
    DefendType2 = "flying"
})
if dualEffect and dualEffect.Action == "SaveState" then
    local dualData = json.decode(dualEffect.Data or "{}")
    if dualData.effectiveness == 1.0 then
        print("✅ Test passed: Fighting vs Normal/Flying = neutral (2x * 0.5x)")
        tests_passed = tests_passed + 1
    else
        error("❌ Test failed: Dual-type effectiveness incorrect")
    end
else
    error("❌ Test failed: Dual-type effectiveness handler failed")
end

-- Test damage calculation
print("📝 Test 4: Damage Calculation")
local damageCalc = sendMessage("CalculateDamage", nil, json.encode({
    attacker = {
        level = 50,
        type1 = "fire",
        stats = { attack = 100, spAttack = 90 }
    },
    defender = {
        type1 = "grass",
        stats = { defense = 80, spDefense = 85 }
    },
    move = {
        type = "fire",
        category = "physical",
        power = 80,
        accuracy = 100
    },
    battleConditions = {},
    rngState = { seed = 54321, counter = 0 }
}))
if damageCalc and damageCalc.Action == "SaveState" then
    local damageData = json.decode(damageCalc.Data or "{}")
    if damageData.damage and damageData.damage > 0 and damageData.effectiveness == 2 and damageData.stab == true then
        print("✅ Test passed: Damage calculation correct")
        tests_passed = tests_passed + 1
    else
        error("❌ Test failed: Damage calculation incorrect")
    end
else
    error("❌ Test failed: CalculateDamage handler failed")
end

-- Test status effect damage
print("📝 Test 5: Status Effect Damage")
local statusDamage = sendMessage("ApplyStatusDamage", nil, json.encode({
    pokemon = {
        hp = 100,
        maxHp = 100,
        statusEffect = "burn"
    },
    turn = 1
}))
if statusDamage and statusDamage.Action == "SaveState" then
    local statusData = json.decode(statusDamage.Data or "{}")
    if statusData.hp and statusData.hp < 100 and statusData.hp >= 0 then
        print("✅ Test passed: Burn causes damage")
        tests_passed = tests_passed + 1
    else
        error("❌ Test failed: Status effect damage incorrect")
    end
else
    error("❌ Test failed: ApplyStatusDamage handler failed")
end

-- Test battle turn processing
print("📝 Test 6: Battle Turn Processing")
local turnResult = sendMessage("ProcessBattleTurn", nil, json.encode({
    gameState = {
        playerId = "test-player",
        timestamp = 1234567890,
        version = 1,
        player = {
            party = {{
                hp = 100,
                maxHp = 100,
                level = 50,
                type1 = "normal",
                stats = { speed = 50, attack = 70, defense = 60, spAttack = 65, spDefense = 55 }
            }}
        },
        battle = {
            battleId = "test-battle",
            battleSeed = "test-seed-123",
            turn = 1,
            status = "active",
            enemyParty = {{
                hp = 80,
                maxHp = 80,
                level = 45,
                type1 = "normal",
                stats = { speed = 45, attack = 60, defense = 55, spAttack = 55, spDefense = 50 }
            }},
            conditions = {}
        }
    },
    battleCommand = {
        action = "attack",
        moveId = 1
    },
    rngState = { seed = 12345, counter = 0 }
}))
if turnResult and turnResult.Action == "SaveState" then
    local turnData = json.decode(turnResult.Data or "{}")
    if turnData.gameState and turnData.turnResults and turnData.battleEnded ~= nil then
        print("✅ Test passed: Battle turn processing complete")
        tests_passed = tests_passed + 1
    else
        error("❌ Test failed: Battle turn processing incomplete")
    end
else
    error("❌ Test failed: ProcessBattleTurn handler failed")
end

-- Test error handling
print("📝 Test 7: Error Handling")
local errorTest = sendMessage("ProcessBattleTurn", nil, json.encode({}))
if errorTest and errorTest.Action == "Error" then
    print("✅ Test passed: Error handling for missing battleCommand")
    tests_passed = tests_passed + 1
else
    error("❌ Test failed: Error handling not working")
end

print("==================================================")
print("Test Results:")
print("  Passed: " .. tests_passed)
print("  Failed: " .. tests_failed)
print("  Total:  " .. (tests_passed + tests_failed))

if tests_failed == 0 then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n❌ Some tests failed!")
end
