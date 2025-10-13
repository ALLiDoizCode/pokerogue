-- GameState Validator Test Suite
-- Unit tests for the GameState validation framework

local aolite = require("aolite")
local json = require("json")

local TEST_TIMEOUT = 30000
local PROCESS_PATH = "processes/security/gamestate-validator.lua"

local process = aolite.spawnProcess(PROCESS_PATH)
if not process then
    error("Failed to spawn process from " .. PROCESS_PATH)
end

print("🧪 Starting Aolite Tests for GameState Validator")
print("Process ID:", process.id)

local function sendMessage(action, tags, data, timeout)
    local msg = {
        Target = process.id,
        Action = action,
        Data = data or "",
        Timestamp = tostring(os.time() * 1000)
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    return aolite.send(msg, timeout or TEST_TIMEOUT)
end

-- Test Suite 1: Pokemon Validation
print("\n=== Test Suite 1: Pokemon Stats Validation ===")

-- Test 1: Valid Pokemon
print("\n📝 Test 1: Valid Pokemon")
local validPokemon = {
    level = 50,
    hp = 150,
    maxHp = 200,
    status = "NONE",
    ivs = {
        hp = 31,
        attack = 28,
        defense = 25,
        spAttack = 30,
        spDefense = 27,
        speed = 29
    },
    moves = {
        {name = "Tackle", pp = 35, maxPp = 35},
        {name = "Thunderbolt", pp = 15, maxPp = 15}
    }
}

local response = sendMessage("ValidatePokemonStats", nil, json.encode(validPokemon))

if response and response.Action == "ValidationResult" and response.IsValid == "true" then
    print("✅ Valid Pokemon passed validation")
else
    error("Valid Pokemon should pass validation")
end

-- Test 2: Invalid Level
print("\n📝 Test 2: Invalid Level")
local invalidLevel = {
    level = 150,
    hp = 100,
    maxHp = 100
}

response = sendMessage("ValidatePokemonStats", nil, json.encode(invalidLevel))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Pokemon with level > 100 rejected")
else
    error("Invalid level should be rejected")
end

-- Test 3: Invalid IV
print("\n📝 Test 3: Invalid IV")
local invalidIV = {
    level = 50,
    hp = 100,
    maxHp = 100,
    ivs = {
        hp = 35
    }
}

response = sendMessage("ValidatePokemonStats", nil, json.encode(invalidIV))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Pokemon with IV > 31 rejected")
else
    error("Invalid IV should be rejected")
end

-- Test 4: Invalid Status
print("\n📝 Test 4: Invalid Status")
local invalidStatus = {
    level = 50,
    hp = 100,
    maxHp = 100,
    status = "INVALID_STATUS"
}

response = sendMessage("ValidatePokemonStats", nil, json.encode(invalidStatus))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Pokemon with invalid status rejected")
else
    error("Invalid status should be rejected")
end

-- Test 5: HP Exceeds maxHP
print("\n📝 Test 5: HP Exceeds maxHP")
local invalidHP = {
    level = 50,
    hp = 250,
    maxHp = 200
}

response = sendMessage("ValidatePokemonStats", nil, json.encode(invalidHP))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Pokemon with HP > maxHP rejected")
else
    error("HP exceeding maxHP should be rejected")
end

-- Test Suite 2: Battle State Validation
print("\n=== Test Suite 2: Battle State Validation ===")

-- Test 6: Valid Battle
print("\n📝 Test 6: Valid Battle")
local validBattle = {
    turn = 5,
    phase = "TURN_RESOLVE",
    playerPokemon = validPokemon,
    enemyPokemon = validPokemon,
    weather = {
        type = "RAIN",
        turnsLeft = 3
    }
}

response = sendMessage("ValidateBattleState", nil, json.encode(validBattle))

if response and response.Action == "ValidationResult" and response.IsValid == "true" then
    print("✅ Valid battle state passed validation")
else
    error("Valid battle state should pass validation")
end

-- Test 7: Invalid Turn
print("\n📝 Test 7: Invalid Turn")
local invalidTurn = {
    turn = 1500,
    phase = "TURN_RESOLVE"
}

response = sendMessage("ValidateBattleState", nil, json.encode(invalidTurn))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Battle with turn > 1000 rejected")
else
    error("Invalid turn should be rejected")
end

-- Test 8: Invalid Phase
print("\n📝 Test 8: Invalid Phase")
local invalidPhase = {
    turn = 5,
    phase = "INVALID_PHASE"
}

response = sendMessage("ValidateBattleState", nil, json.encode(invalidPhase))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Battle with invalid phase rejected")
else
    error("Invalid phase should be rejected")
end

-- Test Suite 3: Inventory Validation
print("\n=== Test Suite 3: Inventory Validation ===")

-- Test 9: Valid Inventory
print("\n📝 Test 9: Valid Inventory")
local validInventory = {
    money = 10000,
    items = {
        ["potion"] = 5,
        ["pokeball"] = 10
    },
    keyItems = {"bicycle", "fishing_rod"}
}

response = sendMessage("ValidateInventory", nil, json.encode(validInventory))

if response and response.Action == "ValidationResult" and response.IsValid == "true" then
    print("✅ Valid inventory passed validation")
else
    error("Valid inventory should pass validation")
end

-- Test 10: Invalid Money
print("\n📝 Test 10: Invalid Money")
local invalidMoney = {
    money = 1000000000
}

response = sendMessage("ValidateInventory", nil, json.encode(invalidMoney))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Inventory with excessive money rejected")
else
    error("Invalid money should be rejected")
end

-- Test 11: Invalid Item Quantity
print("\n📝 Test 11: Invalid Item Quantity")
local invalidQuantity = {
    money = 1000,
    items = {
        ["potion"] = 1000
    }
}

response = sendMessage("ValidateInventory", nil, json.encode(invalidQuantity))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Inventory with excessive item quantity rejected")
else
    error("Invalid quantity should be rejected")
end

-- Test Suite 4: Full GameState Validation
print("\n=== Test Suite 4: Full GameState Validation ===")

-- Test 12: Valid Full GameState
print("\n📝 Test 12: Valid Full GameState")
local validGameState = {
    party = {validPokemon, validPokemon},
    battleState = validBattle,
    inventory = validInventory,
    progression = {
        exp = 5000,
        badges = {"boulder_badge", "cascade_badge"},
        unlockedAreas = {"viridian_city", "pewter_city"}
    }
}

response = sendMessage("ValidateGameState", nil, json.encode(validGameState))

if response and response.Action == "ValidationResult" and response.IsValid == "true" then
    print("✅ Valid full GameState passed validation")
else
    error("Valid GameState should pass validation")
end

-- Test 13: Invalid GameState with Multiple Errors
print("\n📝 Test 13: Invalid GameState with Multiple Errors")
local invalidGameState = {
    party = {validPokemon, validPokemon, validPokemon, validPokemon, validPokemon, validPokemon, validPokemon},
    inventory = invalidMoney,
    progression = {exp = 2000000}
}

response = sendMessage("ValidateGameState", nil, json.encode(invalidGameState))

if response and response.Action == "ValidationResult" and response.IsValid == "false" then
    print("✅ Invalid GameState rejected")
else
    error("Invalid GameState should be rejected")
end

-- Test Suite 5: Handler Integration
print("\n=== Test Suite 5: Handler Integration ===")

-- Test 14: Info Handler
print("\n📝 Test 14: Info Handler")
response = sendMessage("Info", {})

if response and response.Data then
    local info = type(response.Data) == "table" and response.Data or json.decode(response.Data)
    if info.name or info.process then
        print("✅ Info handler working")
    else
        error("Info response incomplete")
    end
else
    error("Info handler failed")
end

-- Test 15: Health Check Handler
print("\n📝 Test 15: Health Check Handler")
response = sendMessage("HealthCheck", {})

if response and (response.Action == "HealthCheckResponse" or response.Status) then
    print("✅ Health check handler working")
else
    error("Health check handler failed")
end

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
