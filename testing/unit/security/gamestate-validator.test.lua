-- GameState Validator Test Suite
-- Unit tests for the GameState validation framework

-- Mock AO environment for testing
local ao = {
    send = function(msg)
        table.insert(_G.testResults or {}, msg)
        _G.lastSentMessage = msg
        return msg
    end,
    id = "test_gamestate_validator_id"
}

-- Mock Handlers for testing
local Handlers = {
    list = {},
    add = function(name, matcher, handler)
        table.insert(Handlers.list, {name = name, matcher = matcher, handle = handler})
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON for testing
local json = {
    encode = function(data)
        if type(data) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(data) do
                if not first then result = result .. "," end
                if type(v) == "table" then
                    result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
                else
                    result = result .. '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                end
                first = false
            end
            return result .. "}"
        end
        return tostring(data)
    end,
    decode = function(str)
        if str == '{}' or str == '' then return {} end
        -- Parse basic JSON for testing
        local result = {}
        return result
    end
}

-- Initialize test results
_G.testResults = {}

-- Set global environment for process
_G.ao = ao
_G.Handlers = Handlers
_G.json = json

-- Load the gamestate validator
local validatorPath = "processes/security/gamestate-validator.lua"
dofile(validatorPath)

-- Test counter
local testsRun = 0
local testsPassed = 0
local testsFailed = 0

local function assert_equal(actual, expected, message)
    testsRun = testsRun + 1
    if actual == expected then
        testsPassed = testsPassed + 1
        print("✓ " .. message)
        return true
    else
        testsFailed = testsFailed + 1
        print("✗ " .. message)
        print("  Expected: " .. tostring(expected))
        print("  Got: " .. tostring(actual))
        return false
    end
end

local function assert_true(condition, message)
    return assert_equal(condition, true, message)
end

local function assert_false(condition, message)
    return assert_equal(condition, false, message)
end

local function assert_not_nil(value, message)
    testsRun = testsRun + 1
    if value ~= nil then
        testsPassed = testsPassed + 1
        print("✓ " .. message)
        return true
    else
        testsFailed = testsFailed + 1
        print("✗ " .. message .. " (got nil)")
        return false
    end
end

print("🧪 GameState Validator Test Suite")
print("=" .. string.rep("=", 50))

-- Test Suite 1: Pokemon Validation
print("\n=== Test Suite 1: Pokemon Stats Validation ===")

-- Test valid pokemon
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
        { name = "Tackle", pp = 35, maxPp = 35 },
        { name = "Thunderbolt", pp = 15, maxPp = 15 }
    }
}

local isValid, err = GameStateValidator.validatePokemonStats(validPokemon)
assert_true(isValid, "Valid Pokemon should pass validation")
assert_equal(err, nil, "Valid Pokemon should have no errors")

-- Test invalid level
local invalidLevel = {
    level = 150,
    hp = 100,
    maxHp = 100
}
isValid, err = GameStateValidator.validatePokemonStats(invalidLevel)
assert_false(isValid, "Pokemon with level > 100 should fail")
assert_not_nil(err, "Invalid level should return error message")

-- Test invalid IV
local invalidIV = {
    level = 50,
    hp = 100,
    maxHp = 100,
    ivs = {
        hp = 35  -- Invalid: max is 31
    }
}
isValid, err = GameStateValidator.validatePokemonStats(invalidIV)
assert_false(isValid, "Pokemon with IV > 31 should fail")
assert_not_nil(err, "Invalid IV should return error message")

-- Test invalid status
local invalidStatus = {
    level = 50,
    hp = 100,
    maxHp = 100,
    status = "INVALID_STATUS"
}
isValid, err = GameStateValidator.validatePokemonStats(invalidStatus)
assert_false(isValid, "Pokemon with invalid status should fail")
assert_not_nil(err, "Invalid status should return error message")

-- Test HP exceeds maxHP
local invalidHP = {
    level = 50,
    hp = 250,
    maxHp = 200
}
isValid, err = GameStateValidator.validatePokemonStats(invalidHP)
assert_false(isValid, "Pokemon with HP > maxHP should fail")
assert_not_nil(err, "HP exceeding maxHP should return error message")

-- Test Suite 2: Battle State Validation
print("\n=== Test Suite 2: Battle State Validation ===")

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

isValid, err = GameStateValidator.validateBattleState(validBattle)
assert_true(isValid, "Valid battle state should pass validation")
assert_equal(err, nil, "Valid battle state should have no errors")

-- Test invalid turn
local invalidTurn = {
    turn = 1500,
    phase = "TURN_RESOLVE"
}
isValid, err = GameStateValidator.validateBattleState(invalidTurn)
assert_false(isValid, "Battle with turn > 1000 should fail")
assert_not_nil(err, "Invalid turn should return error message")

-- Test invalid phase
local invalidPhase = {
    turn = 5,
    phase = "INVALID_PHASE"
}
isValid, err = GameStateValidator.validateBattleState(invalidPhase)
assert_false(isValid, "Battle with invalid phase should fail")
assert_not_nil(err, "Invalid phase should return error message")

-- Test invalid weather
local invalidWeather = {
    turn = 5,
    phase = "TURN_RESOLVE",
    weather = {
        type = "METEOR_SHOWER",  -- Invalid weather
        turnsLeft = 3
    }
}
isValid, err = GameStateValidator.validateBattleState(invalidWeather)
assert_false(isValid, "Battle with invalid weather should fail")
assert_not_nil(err, "Invalid weather should return error message")

-- Test Suite 3: Inventory Validation
print("\n=== Test Suite 3: Inventory Validation ===")

local validInventory = {
    money = 10000,
    items = {
        ["potion"] = 5,
        ["pokeball"] = 10
    },
    keyItems = {"bicycle", "fishing_rod"}
}

isValid, err = GameStateValidator.validateInventory(validInventory)
assert_true(isValid, "Valid inventory should pass validation")
assert_equal(err, nil, "Valid inventory should have no errors")

-- Test invalid money
local invalidMoney = {
    money = 1000000000  -- Exceeds max
}
isValid, err = GameStateValidator.validateInventory(invalidMoney)
assert_false(isValid, "Inventory with excessive money should fail")
assert_not_nil(err, "Invalid money should return error message")

-- Test invalid item quantity
local invalidQuantity = {
    money = 1000,
    items = {
        ["potion"] = 1000  -- Exceeds max of 999
    }
}
isValid, err = GameStateValidator.validateInventory(invalidQuantity)
assert_false(isValid, "Inventory with excessive item quantity should fail")
assert_not_nil(err, "Invalid quantity should return error message")

-- Test Suite 4: Progression Validation
print("\n=== Test Suite 4: Progression Validation ===")

local validProgression = {
    exp = 5000,
    badges = {"boulder_badge", "cascade_badge"},
    unlockedAreas = {"viridian_city", "pewter_city"}
}

isValid, err = GameStateValidator.validateProgression(validProgression)
assert_true(isValid, "Valid progression should pass validation")
assert_equal(err, nil, "Valid progression should have no errors")

-- Test invalid experience
local invalidExp = {
    exp = 2000000  -- Exceeds max
}
isValid, err = GameStateValidator.validateProgression(invalidExp)
assert_false(isValid, "Progression with excessive exp should fail")
assert_not_nil(err, "Invalid exp should return error message")

-- Test Suite 5: Party Validation
print("\n=== Test Suite 5: Party Validation ===")

local validParty = {validPokemon, validPokemon}

isValid, err = GameStateValidator.validateParty(validParty)
assert_true(isValid, "Valid party should pass validation")
assert_equal(err, nil, "Valid party should have no errors")

-- Test party size exceeds limit
local oversizedParty = {
    validPokemon, validPokemon, validPokemon,
    validPokemon, validPokemon, validPokemon,
    validPokemon  -- 7 Pokemon, exceeds max of 6
}
isValid, err = GameStateValidator.validateParty(oversizedParty)
assert_false(isValid, "Party with > 6 Pokemon should fail")
assert_not_nil(err, "Oversized party should return error message")

-- Test Suite 6: Full GameState Validation
print("\n=== Test Suite 6: Full GameState Validation ===")

local validGameState = {
    party = validParty,
    battleState = validBattle,
    inventory = validInventory,
    progression = validProgression
}

isValid, err = GameStateValidator.validateGameState(validGameState)
assert_true(isValid, "Valid full GameState should pass validation")
assert_equal(err, nil, "Valid GameState should have no errors")

-- Test GameState with multiple errors
local invalidGameState = {
    party = oversizedParty,
    inventory = invalidMoney,
    progression = invalidExp
}

isValid, err = GameStateValidator.validateGameState(invalidGameState)
assert_false(isValid, "Invalid GameState should fail validation")
assert_not_nil(err, "Invalid GameState should return errors")

-- Test Suite 7: Handler Integration
print("\n=== Test Suite 7: Handler Integration ===")

-- Test direct validation function calls instead of full handler integration
-- since our mock JSON doesn't handle complex nested structures
local validationResult = GameStateValidator.validateAtProcessBoundary(validGameState, "BattleStart")
assert_true(validationResult.valid, "Valid GameState should pass boundary validation")
assert_equal(validationResult.operationType, "BattleStart", "Should track operation type")

local invalidResult = GameStateValidator.validateAtProcessBoundary(invalidGameState, "BattleStart")
assert_false(invalidResult.valid, "Invalid GameState should fail boundary validation")
assert_not_nil(invalidResult.violations, "Invalid GameState should include violations")

-- Test handler registration
local handlerFound = false
for i, handler in ipairs(Handlers.list) do
    if handler.name == "validate-gamestate" then
        handlerFound = true
        break
    end
end
assert_true(handlerFound, "validate-gamestate handler should be registered")

-- Test info handler registration
handlerFound = false
for i, handler in ipairs(Handlers.list) do
    if handler.name == "info" then
        handlerFound = true
        break
    end
end
assert_true(handlerFound, "info handler should be registered")

-- Test health-check handler registration
handlerFound = false
for i, handler in ipairs(Handlers.list) do
    if handler.name == "health-check" then
        handlerFound = true
        break
    end
end
assert_true(handlerFound, "health-check handler should be registered")

-- Print test results
print("\n" .. string.rep("=", 50))
print("📊 Test Results:")
print(string.format("  Total: %d", testsRun))
print(string.format("  Passed: %d", testsPassed))
print(string.format("  Failed: %d", testsFailed))

if testsFailed == 0 then
    print("\n✅ All GameState Validator tests passed!")
    os.exit(0)
else
    print("\n❌ Some tests failed!")
    os.exit(1)
end
