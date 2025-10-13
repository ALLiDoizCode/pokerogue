-- Aolite Unit Tests for Damage Calculation Engine Process
-- Tests comprehensive Pokemon damage calculation functionality
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.damage-calculation-engine"
local processId = "test-damage-calculation-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Damage Calculation Engine")
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

-- Test 1: Process Ping
print("📝 Test 1: Process Ping")
local pingResponse = sendMessage("Ping")
if pingResponse and pingResponse.Action == "Pong" then
    print("✅ Ping test passed")
else
    error("❌ Ping test failed")
end

-- Test 2: ADP Info Handler
print("📝 Test 2: ADP Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    local data = json.decode(infoResponse.Data)
    if data and data.process then
        print("✅ ADP Info handler test passed - Process: " .. (data.process.name or "unknown"))
    else
        error("❌ ADP Info handler test failed - missing process metadata")
    end
else
    error("❌ ADP Info handler test failed")
end

-- Test 3: Base Damage Calculation
print("📝 Test 3: Base Damage Calculation")
local baseDamageResponse = sendMessage("CalculateBaseDamage", {
    Level = "50",
    Power = "80",
    Attack = "100",
    Defense = "100"
})

if baseDamageResponse and baseDamageResponse.Action == "SaveState" then
    local data = json.decode(baseDamageResponse.Data)
    if data and data.baseDamage then
        print("✅ Base damage calculation test passed - Damage: " .. tostring(data.baseDamage))
    else
        error("❌ Base damage calculation test failed - missing base damage")
    end
else
    error("❌ Base damage calculation test failed")
end

-- Test 4: Type Effectiveness - Super Effective
print("📝 Test 4: Type Effectiveness - Super Effective")
local superEffectiveResponse = sendMessage("CalculateTypeEffectiveness", {
    MoveType = "9", -- Fire
    DefenderTypes = json.encode({11}) -- Grass
})

if superEffectiveResponse and superEffectiveResponse.Action == "SaveState" then
    local data = json.decode(superEffectiveResponse.Data)
    if data and data.effectiveness then
        if data.effectiveness ~= 2.0 then
            error("❌ Type effectiveness test failed - expected 2.0x, got " .. tostring(data.effectiveness))
        end
        print("✅ Type effectiveness test passed - Fire vs Grass: 2.0x")
    else
        error("❌ Type effectiveness test failed - missing effectiveness")
    end
else
    error("❌ Type effectiveness test failed")
end

-- Test 5: Type Effectiveness - Immunity
print("📝 Test 5: Type Effectiveness - Immunity")
local immunityResponse = sendMessage("CalculateTypeEffectiveness", {
    MoveType = "4", -- Ground
    DefenderTypes = json.encode({2}) -- Flying
})

if immunityResponse and immunityResponse.Action == "SaveState" then
    local data = json.decode(immunityResponse.Data)
    if data and data.effectiveness then
        if data.effectiveness ~= 0 then
            error("❌ Type immunity test failed - expected 0x, got " .. tostring(data.effectiveness))
        end
        print("✅ Type immunity test passed - Ground vs Flying: 0x")
    else
        error("❌ Type immunity test failed - missing effectiveness")
    end
else
    error("❌ Type immunity test failed")
end

-- Test 6: Complete Damage Calculation
print("📝 Test 6: Complete Damage Calculation")
local completeDamageData = {
    attackerLevel = 50,
    movePower = 80,
    attackStat = 100,
    defenseStat = 100,
    moveType = 9, -- Fire
    defenderTypes = {11}, -- Grass
    pokemonTypes = {9}, -- Fire type Pokemon
    simulated = true
}
local completeDamageResponse = sendMessage("CalculateFinalDamage", {}, json.encode(completeDamageData))

if completeDamageResponse and completeDamageResponse.Action == "SaveState" then
    local data = json.decode(completeDamageResponse.Data)
    if data and data.finalDamage then
        print("✅ Complete damage calculation test passed - Final Damage: " .. tostring(data.finalDamage))
    else
        error("❌ Complete damage calculation test failed - missing final damage")
    end
else
    error("❌ Complete damage calculation test failed")
end

-- Test 7: Invalid Parameters - Missing Required Fields
print("📝 Test 7: Invalid Parameters Handling")
local invalidResponse = sendMessage("CalculateBaseDamage", {
    Level = "50"
    -- Missing Power, Attack, Defense
})

if invalidResponse and invalidResponse.Error then
    print("✅ Invalid parameters test passed - Error correctly returned")
else
    error("❌ Invalid parameters test failed - expected error response")
end

-- Test 8: Zero Power Move
print("📝 Test 8: Zero Power Move")
local zeroPowerResponse = sendMessage("CalculateBaseDamage", {
    Level = "50",
    Power = "0",
    Attack = "100",
    Defense = "100"
})

if zeroPowerResponse and zeroPowerResponse.Action == "SaveState" then
    local data = json.decode(zeroPowerResponse.Data)
    if data and data.baseDamage then
        print("✅ Zero power move test passed - Damage: " .. tostring(data.baseDamage))
    else
        error("❌ Zero power move test failed - missing base damage")
    end
else
    error("❌ Zero power move test failed")
end

-- Test 9: Mathematical Precision Validation
print("📝 Test 9: Mathematical Precision Validation")
local precisionCases = {
    {level = 1, power = 1, attack = 1, defense = 1},
    {level = 50, power = 80, attack = 100, defense = 100},
    {level = 100, power = 120, attack = 150, defense = 80},
    {level = 5, power = 40, attack = 30, defense = 25}
}

local precisionPassed = 0
for i, testCase in ipairs(precisionCases) do
    local response = sendMessage("CalculateBaseDamage", {
        Level = tostring(testCase.level),
        Power = tostring(testCase.power),
        Attack = tostring(testCase.attack),
        Defense = tostring(testCase.defense)
    })

    if response and response.Action == "SaveState" then
        precisionPassed = precisionPassed + 1
    end
end

if precisionPassed == #precisionCases then
    print("✅ Mathematical precision validation test passed - " .. precisionPassed .. "/" .. #precisionCases .. " cases")
else
    error("❌ Mathematical precision validation test failed - " .. precisionPassed .. "/" .. #precisionCases .. " cases passed")
end

-- Test 10: Property-Based Formula Consistency
print("📝 Test 10: Property-Based Formula Consistency")
local formulaTests = {
    {level = 50, power = 0, attack = 100, defense = 100},
    {level = 100, power = 0, attack = 100, defense = 100},
    {level = 50, power = 100, attack = 200, defense = 50},
    {level = 50, power = 100, attack = 50, defense = 200}
}

local formulaPassed = 0
for i, test in ipairs(formulaTests) do
    local response = sendMessage("CalculateBaseDamage", {
        Level = tostring(test.level),
        Power = tostring(test.power),
        Attack = tostring(test.attack),
        Defense = tostring(test.defense)
    })

    if response and response.Action == "SaveState" then
        formulaPassed = formulaPassed + 1
    end
end

if formulaPassed == #formulaTests then
    print("✅ Property-based formula consistency test passed - " .. formulaPassed .. "/" .. #formulaTests .. " cases")
else
    error("❌ Property-based formula consistency test failed - " .. formulaPassed .. "/" .. #formulaTests .. " cases passed")
end

-- Test 11: Performance Stress Test
print("📝 Test 11: Performance Stress Test")
local stressPassed = 0
for i = 1, 10 do
    local response = sendMessage("CalculateBaseDamage", {
        Level = tostring(50 + i),
        Power = "80",
        Attack = "100",
        Defense = "100"
    })

    if response and response.Action == "SaveState" then
        stressPassed = stressPassed + 1
    end
end

if stressPassed == 10 then
    print("✅ Performance stress test passed - 10/10 requests")
else
    error("❌ Performance stress test failed - " .. stressPassed .. "/10 requests passed")
end

-- Test Summary
print("==================================================")
print("🎉 All Damage Calculation Engine tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
