-- Unit Tests for Tera Crystal Resource Engine
-- Tests drop rate calculations, type generation algorithms, and usage tracking

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.tera-crystal-engine"
local processId = "test-tera-crystal-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Tera Crystal Resource Engine")
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

-- Test 1: Drop Rate Calculation Algorithm
print("\n📝 Test 1: Tera Orb Drop Rate Calculation")

local testCases = {
    {wave = 1, expected = 1},
    {wave = 25, expected = 1},
    {wave = 49, expected = 1},
    {wave = 50, expected = 2},
    {wave = 75, expected = 2},
    {wave = 100, expected = 4},
    {wave = 150, expected = 4},
    {wave = 200, expected = 4}
}

for i, testCase in ipairs(testCases) do
    local response = sendMessage("GenerateTeraCrystal", {
        WaveIndex = tostring(testCase.wave),
        GameMode = "CLASSIC",
        CrystalType = "orb",
        Guaranteed = "true"
    })

    if response and response.DropWeight then
        local actualWeight = tonumber(response.DropWeight)
        if actualWeight == testCase.expected then
            print(string.format("✅ Wave %d: Expected %d, Got %d", testCase.wave, testCase.expected, actualWeight))
        else
            error(string.format("Wave %d: Expected %d, Got %d", testCase.wave, testCase.expected, actualWeight))
        end
    else
        error(string.format("Wave %d: No DropWeight in response", testCase.wave))
    end
end

-- Test 2: Classic Mode Wave Restriction
print("\n📝 Test 2: Classic Mode Wave Restriction")

local response = sendMessage("GenerateTeraCrystal", {
    WaveIndex = "25",
    GameMode = "CLASSIC",
    CrystalType = "orb"
})

if response and response.Success == "false" and response.Reason and string.find(response.Reason, "Wave too early") then
    print("✅ Classic mode wave restriction working correctly")
else
    error("Classic mode wave restriction failed")
end

response = sendMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC",
    CrystalType = "orb",
    Guaranteed = "true"
})

if response and response.Success == "true" then
    print("✅ Wave 50+ Classic mode generation working correctly")
else
    error("Wave 50+ Classic mode generation failed")
end

-- Test 3: Tera Shard Type Generation
print("\n📝 Test 3: Tera Shard Type Generation")

response = sendMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC",
    CrystalType = "shard"
})

if response and response.Success == "true" and response.TeraType then
    local validTypes = {
        "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
        "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC",
        "BUG", "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY", "STELLAR"
    }

    local isValid = false
    for _, validType in ipairs(validTypes) do
        if response.TeraType == validType then
            isValid = true
            break
        end
    end

    if isValid then
        print("✅ Tera Shard generation successful: " .. response.TeraType)
    else
        error("Invalid Tera type generated: " .. response.TeraType)
    end
else
    error("Tera Shard generation failed")
end

-- Test 4: Party Type Exclusion Logic
print("\n📝 Test 4: Party Type Exclusion Logic")

local uniformParty = {"FIRE", "FIRE", "FIRE", "FIRE", "FIRE", "FIRE"}

response = sendMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC",
    CrystalType = "shard",
    PartyTeraTypes = json.encode(uniformParty)
})

if response and response.Success == "true" and response.TeraType ~= "FIRE" then
    print("✅ Party exclusion logic working: Generated " .. response.TeraType .. " (excluded FIRE)")
else
    error("Party exclusion logic failed")
end

-- Test 5: Tera Shard Application
print("\n📝 Test 5: Tera Shard Application")

response = sendMessage("ApplyTeraShard", {
    PokemonId = "pikachu_001",
    TeraType = "WATER"
})

if response and response.Success == "true" and response.PokemonId == "pikachu_001" and response.TeraType == "WATER" then
    print("✅ Tera Shard application successful")
else
    error("Tera Shard application failed")
end

-- Test 6: Invalid Tera Type Validation
print("\n📝 Test 6: Invalid Tera Type Validation")

response = sendMessage("ApplyTeraShard", {
    PokemonId = "pikachu_001",
    TeraType = "INVALID_TYPE"
})

if response and response.Action == "Error" and string.find(response.Error, "Invalid TeraType") then
    print("✅ Invalid Tera type validation working")
else
    error("Invalid Tera type validation failed")
end

-- Test 7: Terastallization Eligibility Check
print("\n📝 Test 7: Terastallization Eligibility Check")

response = sendMessage("CheckTeraEligibility", {
    PokemonId = "pikachu_001",
    BattleId = "battle_001"
})

if response and response.Success == "true" and response.Eligible == "true" then
    print("✅ Terastallization eligibility check passed")
else
    error("Terastallization eligibility check failed")
end

-- Test 8: Battle Usage Tracking
print("\n📝 Test 8: Battle Usage Tracking")

response = sendMessage("UseTerastallization", {
    PokemonId = "pikachu_001",
    BattleId = "battle_001"
})

if response and response.Success == "true" and response.TerasUsed == "1" then
    print("✅ First Terastallization usage tracked")
else
    error("First Terastallization usage tracking failed")
end

response = sendMessage("UseTerastallization", {
    PokemonId = "pikachu_001",
    BattleId = "battle_001"
})

if response and response.Action == "Error" and string.find(response.Error, "Already used") then
    print("✅ Per-battle usage limitation working")
else
    error("Per-battle usage limitation failed")
end

-- Test 9: Battle Usage Reset
print("\n📝 Test 9: Battle Usage Reset")

response = sendMessage("ResetBattleUsage", {
    BattleId = "battle_002"
})

if response and response.Success == "true" and response.TerasUsed == "0" then
    print("✅ Battle usage reset successful")
else
    error("Battle usage reset failed")
end

response = sendMessage("UseTerastallization", {
    PokemonId = "pikachu_001",
    BattleId = "battle_002"
})

if response and response.Success == "true" then
    print("✅ Terastallization available after battle reset")
else
    error("Terastallization not available after battle reset")
end

-- Test 10: Player State Retrieval
print("\n📝 Test 10: Player State Retrieval")

response = sendMessage("GetTeraState", {})

if response and response.Success == "true" and response.Data then
    local stateData = json.decode(response.Data)
    if stateData and stateData.hasTeraOrb and stateData.pokemonTeraTypes then
        print("✅ Player state retrieval successful")
    else
        error("Player state data incomplete")
    end
else
    error("Player state retrieval failed")
end

-- Test 11: ADP v1.0 Info Handler
print("\n📝 Test 11: ADP v1.0 Info Handler")

response = sendMessage("Info", {})

if response and response.Action == "InfoResponse" and response.Data then
    local infoData = json.decode(response.Data)
    if infoData and infoData.process and infoData.handlers and infoData.process.adpVersion == "1.0" then
        print("✅ ADP v1.0 Info handler working")
    else
        error("ADP v1.0 Info response incomplete")
    end
else
    error("ADP v1.0 Info handler failed")
end

-- Test 12: Ping Handler
print("\n📝 Test 12: Ping Handler")

response = sendMessage("Ping", {})

if response and response.Action == "Pong" and response.Data then
    print("✅ Ping handler working: " .. response.Data)
else
    error("Ping handler failed")
end

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
