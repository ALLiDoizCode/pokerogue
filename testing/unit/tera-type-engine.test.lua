-- Unit Tests for Tera Type Engine Process
-- Tests all core Tera type mechanics and error handling

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.tera-type-engine"
local processId = "test-tera-type-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Tera Type Engine")
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

-- Helper function to create test Pokemon data
local function createTestPokemon(overrides)
    local defaultPokemon = {
        id = "test-pokemon-1",
        speciesId = "PIKACHU",
        types = {"ELECTRIC"},
        hp = 100,
        maxHp = 100,
        level = 50,
        isTerastallized = false,
        stellarTypesBoosted = {}
    }

    if overrides then
        for key, value in pairs(overrides) do
            defaultPokemon[key] = value
        end
    end

    return defaultPokemon
end

-- Test 1: Tera Type Assignment - Default Random Selection
print("\n📝 Test 1: Tera Type Assignment - Default Random Selection")
local pokemon = createTestPokemon({types = {"ELECTRIC", "NORMAL"}})

local response = sendMessage("AssignTeraType", nil, json.encode(pokemon))

if response.Action == "TeraTypeAssigned" and response.Success == "true" then
    local assignedPokemon = json.decode(response.Data)
    if assignedPokemon.teraType == "ELECTRIC" or assignedPokemon.teraType == "NORMAL" then
        print("✅ Tera type assigned from natural types")
    else
        error("Tera type should be one of natural types")
    end
else
    error("Tera type assignment failed")
end

-- Test 2: Terapagos Special Case
print("\n📝 Test 2: Terapagos Special Case")
local terapagos = createTestPokemon({
    speciesId = "TERAPAGOS",
    types = {"NORMAL"}
})

response = sendMessage("AssignTeraType", nil, json.encode(terapagos))

if response.Action == "TeraTypeAssigned" and response.TeraType == "STELLAR" then
    local assignedPokemon = json.decode(response.Data)
    if assignedPokemon.teraType == "STELLAR" then
        print("✅ Terapagos assigned STELLAR type")
    else
        error("Terapagos should have STELLAR type")
    end
else
    error("Terapagos special case failed")
end

-- Test 3: Preferred Type Assignment
print("\n📝 Test 3: Preferred Type Assignment")
pokemon = createTestPokemon({types = {"ELECTRIC"}})

response = sendMessage("AssignTeraType", {TeraType = "FIRE"}, json.encode(pokemon))

if response.Action == "TeraTypeAssigned" and response.TeraType == "FIRE" then
    local assignedPokemon = json.decode(response.Data)
    if assignedPokemon.teraType == "FIRE" then
        print("✅ Preferred Tera type assigned")
    else
        error("Preferred type assignment failed")
    end
else
    error("Preferred type assignment failed")
end

-- Test 4: Invalid Type Rejection
print("\n📝 Test 4: Invalid Type Rejection")
pokemon = createTestPokemon()

response = sendMessage("AssignTeraType", {TeraType = "INVALID_TYPE"}, json.encode(pokemon))

if response.Action == "TeraError" and response.ErrorCode == "TERA_002" then
    print("✅ Invalid type rejected")
else
    error("Invalid type should be rejected")
end

-- Test 5: Already Assigned Error
print("\n📝 Test 5: Already Assigned Error")
pokemon = createTestPokemon({teraType = "FIRE"})

response = sendMessage("AssignTeraType", nil, json.encode(pokemon))

if response.Action == "TeraError" and response.ErrorCode == "TERA_004" then
    print("✅ Already assigned error")
else
    error("Should error when already assigned")
end

-- Test 6: Terastallization Activation - Success
print("\n📝 Test 6: Terastallization Activation - Success")
pokemon = createTestPokemon({teraType = "FIRE"})

response = sendMessage("ActivateTerastalization", {
    BattleId = "test-battle-1",
    TrainerId = "trainer-1",
    Turn = "1"
}, json.encode(pokemon))

if response.Action == "TerastalizationActivated" and response.Success == "true" and response.TeraType == "FIRE" then
    local activatedPokemon = json.decode(response.Data)
    if activatedPokemon.isTerastallized then
        print("✅ Terastallization activated successfully")
    else
        error("Pokemon should be terastallized")
    end
else
    error("Terastallization activation failed")
end

-- Test 7: Usage Limit Exceeded
print("\n📝 Test 7: Usage Limit Exceeded")
local pokemon2 = createTestPokemon({teraType = "WATER", id = "pokemon-2"})

response = sendMessage("ActivateTerastalization", {
    BattleId = "test-battle-1",
    TrainerId = "trainer-1"
}, json.encode(pokemon2))

if response.Action == "TeraError" and response.ErrorCode == "TERA_102" then
    print("✅ Usage limit enforced")
else
    error("Usage limit should be enforced")
end

-- Test 8: Already Terastallized Error
print("\n📝 Test 8: Already Terastallized Error")
pokemon = createTestPokemon({
    teraType = "FIRE",
    isTerastallized = true
})

response = sendMessage("ActivateTerastalization", {
    BattleId = "test-battle-2",
    TrainerId = "trainer-2"
}, json.encode(pokemon))

if response.Action == "TeraError" and response.ErrorCode == "TERA_101" then
    print("✅ Already terastallized error")
else
    error("Should error when already terastallized")
end

-- Test 9: Fainted Pokemon Error
print("\n📝 Test 9: Fainted Pokemon Error")
pokemon = createTestPokemon({
    teraType = "FIRE",
    hp = 0
})

response = sendMessage("ActivateTerastalization", {
    BattleId = "test-battle-3",
    TrainerId = "trainer-3"
}, json.encode(pokemon))

if response.Action == "TeraError" and response.ErrorCode == "TERA_104" then
    print("✅ Fainted Pokemon error")
else
    error("Should error for fainted Pokemon")
end

-- Test 10: STAB Calculation - Natural Type
print("\n📝 Test 10: STAB Calculation - Natural Type")
pokemon = createTestPokemon({
    types = {"ELECTRIC"},
    teraType = "FIRE",
    isTerastallized = false
})

response = sendMessage("CalculateTeraSTAB", {MoveType = "ELECTRIC"}, json.encode(pokemon))

if response.Action == "TeraSTABCalculated" then
    local multiplier = tonumber(response.STABMultiplier)
    if math.abs(multiplier - 1.5) < 0.01 then
        print("✅ Natural type STAB calculated correctly (1.5x)")
    else
        error("Expected 1.5x STAB, got " .. multiplier)
    end
else
    error("STAB calculation failed")
end

-- Test 11: STAB Calculation - Tera Type
print("\n📝 Test 11: STAB Calculation - Tera Type")
pokemon = createTestPokemon({
    types = {"ELECTRIC"},
    teraType = "FIRE",
    isTerastallized = true
})

response = sendMessage("CalculateTeraSTAB", {MoveType = "FIRE"}, json.encode(pokemon))

if response.Action == "TeraSTABCalculated" then
    local multiplier = tonumber(response.STABMultiplier)
    if math.abs(multiplier - 1.5) < 0.01 then
        print("✅ Tera type STAB calculated correctly (1.5x)")
    else
        error("Expected 1.5x STAB, got " .. multiplier)
    end
else
    error("STAB calculation failed")
end

-- Test 12: STAB Calculation - Stellar First Use
print("\n📝 Test 12: STAB Calculation - Stellar First Use")
pokemon = createTestPokemon({
    types = {"ELECTRIC"},
    teraType = "STELLAR",
    isTerastallized = true,
    stellarTypesBoosted = {}
})

response = sendMessage("CalculateTeraSTAB", {MoveType = "ELECTRIC"}, json.encode(pokemon))

if response.Action == "TeraSTABCalculated" then
    local multiplier = tonumber(response.STABMultiplier)
    if math.abs(multiplier - 2.0) < 0.01 then
        print("✅ Stellar matching type STAB calculated correctly (2.0x)")
    else
        error("Expected 2.0x STAB, got " .. multiplier)
    end
else
    error("STAB calculation failed")
end

-- Test 13: Type Effectiveness - Normal Case
print("\n📝 Test 13: Type Effectiveness - Normal Case")
local attacker = createTestPokemon({types = {"ELECTRIC"}})
local defender = createTestPokemon({types = {"WATER"}})

response = sendMessage("CalculateTeraEffectiveness", {
    AttackerData = json.encode(attacker),
    DefenderData = json.encode(defender),
    MoveType = "ELECTRIC"
})

if response.Action == "TeraEffectivenessCalculated" then
    local effectiveness = tonumber(response.Effectiveness)
    if math.abs(effectiveness - 2.0) < 0.01 then
        print("✅ Type effectiveness calculated correctly (2.0x)")
    else
        error("Expected 2.0x effectiveness, got " .. effectiveness)
    end
else
    error("Type effectiveness calculation failed")
end

-- Test 14: Get Tera Type
print("\n📝 Test 14: Get Tera Type")
pokemon = createTestPokemon({teraType = "FIRE"})

response = sendMessage("GetTeraType", nil, json.encode(pokemon))

if response.Action == "TeraTypeRetrieved" and response.TeraType == "FIRE" and response.IsTerastallized == "false" then
    print("✅ Tera type retrieved correctly")
else
    error("Tera type retrieval failed")
end

-- Test 15: Reset Tera State
print("\n📝 Test 15: Reset Tera State")
pokemon = createTestPokemon({
    teraType = "FIRE",
    isTerastallized = true,
    stellarTypesBoosted = {"WATER", "GRASS"}
})

response = sendMessage("ResetTeraState", {BattleId = "test-battle-1"}, json.encode(pokemon))

if response.Action == "TeraStateReset" and response.WasTerastallized == "true" then
    local resetPokemon = json.decode(response.Data)
    if not resetPokemon.isTerastallized and #resetPokemon.stellarTypesBoosted == 0 then
        print("✅ Tera state reset successfully")
    else
        error("Tera state not properly reset")
    end
else
    error("Tera state reset failed")
end

-- Test 16: Health Check
print("\n📝 Test 16: Health Check")

response = sendMessage("HealthCheck")

if response.Action == "HealthCheckResponse" and response.Status == "healthy" then
    print("✅ Health check passed")
else
    error("Health check failed")
end

-- Test 17: ADP Compliance - Info Handler
print("\n📝 Test 17: ADP Compliance - Info Handler")

response = sendMessage("Info")

if response.Data then
    local info = json.decode(response.Data)
    if info.Name and info.protocolVersion == "1.0" and info.handlers then
        print("✅ ADP v1.0 Info handler working")
    else
        error("ADP info incomplete")
    end
else
    error("ADP Info handler failed")
end

-- Test 18: Ping Handler
print("\n📝 Test 18: Ping Handler")

response = sendMessage("Ping")

if response.Action == "Pong" and response.Data == "pong" and response.ProcessType == "TeraTypeEngine" then
    print("✅ Ping handler working")
else
    error("Ping handler failed")
end

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
