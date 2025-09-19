#!/usr/bin/env lua

-- Standalone test runner for GameState Validator
-- This script loads the validator and runs comprehensive tests

-- Setup the environment first
local function setupTestEnvironment()
    -- Mock JSON
    _G.json = {
        encode = function(obj) 
            if type(obj) == "table" then
                return "json_encoded_table"
            else
                return tostring(obj)
            end
        end,
        decode = function(str) 
            if str == "{}" then return {} end
            return {decoded = true}
        end
    }
    
    -- Mock AO
    _G.ao = {
        send = function(msg) 
            print("Mock AO send called")
        end,
        id = "test_gamestate_validator"
    }
    
    -- Mock Handlers
    _G.Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    return msg.Tags and msg.Tags[tagName] == tagValue
                end
            end
        }
    }
end

-- Load the validator by executing the file
local function loadValidator()
    setupTestEnvironment()
    
    -- Load the validator process
    local validatorPath = "processes/security/gamestate-validator.lua"
    local success, err = pcall(dofile, validatorPath)
    
    if not success then
        print("❌ Failed to load validator:", err)
        os.exit(1)
    end
    
    -- Ensure the validator was loaded
    if not _G.GameStateValidator then
        print("❌ GameStateValidator not found in global scope")
        os.exit(1)
    end
    
    print("✅ GameState Validator loaded successfully")
    return _G.GameStateValidator
end

-- Test data factories
local function createValidPokemon()
    return {
        id = 1,
        species = "BULBASAUR",
        level = 5,
        hp = 20,
        maxHp = 20,
        ivs = {
            hp = 15,
            attack = 12,
            defense = 13,
            spAttack = 16,
            spDefense = 14,
            speed = 11
        },
        status = "NONE",
        moves = {
            {id = 1, name = "TACKLE", pp = 35, maxPp = 35},
            {id = 2, name = "GROWL", pp = 40, maxPp = 40}
        }
    }
end

local function createValidBattleState()
    return {
        turn = 1,
        phase = "COMMAND_SELECT",
        playerPokemon = createValidPokemon(),
        enemyPokemon = createValidPokemon(),
        weather = {
            type = "NONE",
            turnsLeft = 0
        }
    }
end

local function createValidInventory()
    return {
        money = 3000,
        items = {
            POTION = 5,
            POKEBALL = 10
        },
        keyItems = {"POKEDEX", "TOWN_MAP"}
    }
end

local function createValidProgression()
    return {
        exp = 1000,
        badges = {"BOULDER_BADGE"},
        unlockedAreas = {"PALLET_TOWN", "ROUTE_1"}
    }
end

local function createValidGameState()
    return {
        party = {createValidPokemon()},
        battleState = createValidBattleState(),
        inventory = createValidInventory(),
        progression = createValidProgression()
    }
end

-- Test functions
local function testPokemonStatsValidation(validator)
    print("  🧪 Testing Pokemon stats validation...")
    
    -- Valid Pokemon should pass
    local validPokemon = createValidPokemon()
    local success, error = validator.validatePokemonStats(validPokemon)
    assert(success == true, "Valid Pokemon should pass validation")
    assert(error == nil, "Valid Pokemon should not have errors")
    
    -- Invalid level should fail
    local invalidLevel = createValidPokemon()
    invalidLevel.level = 101
    success, error = validator.validatePokemonStats(invalidLevel)
    assert(success == false, "Pokemon with level 101 should fail")
    assert(string.find(error, "level"), "Error should mention level")
    
    -- Invalid IVs should fail
    local invalidIV = createValidPokemon()
    invalidIV.ivs.hp = 32
    success, error = validator.validatePokemonStats(invalidIV)
    assert(success == false, "Pokemon with IV > 31 should fail")
    assert(string.find(error, "IV"), "Error should mention IV")
    
    -- Invalid HP should fail
    local invalidHP = createValidPokemon()
    invalidHP.hp = invalidHP.maxHp + 1
    success, error = validator.validatePokemonStats(invalidHP)
    assert(success == false, "Pokemon with HP > maxHP should fail")
    assert(string.find(error, "HP"), "Error should mention HP")
    
    -- Invalid status should fail
    local invalidStatus = createValidPokemon()
    invalidStatus.status = "INVALID_STATUS"
    success, error = validator.validatePokemonStats(invalidStatus)
    assert(success == false, "Pokemon with invalid status should fail")
    assert(string.find(error, "status"), "Error should mention status")
    
    print("    ✅ Pokemon stats validation tests passed")
end

local function testBattleStateValidation(validator)
    print("  🧪 Testing battle state validation...")
    
    -- Valid battle state should pass
    local validBattle = createValidBattleState()
    local success, error = validator.validateBattleState(validBattle)
    assert(success == true, "Valid battle state should pass validation")
    
    -- Invalid turn should fail
    local invalidTurn = createValidBattleState()
    invalidTurn.turn = 1001
    success, error = validator.validateBattleState(invalidTurn)
    assert(success == false, "Battle with turn > 1000 should fail")
    
    -- Invalid phase should fail
    local invalidPhase = createValidBattleState()
    invalidPhase.phase = "INVALID_PHASE"
    success, error = validator.validateBattleState(invalidPhase)
    assert(success == false, "Battle with invalid phase should fail")
    
    -- Invalid weather should fail
    local invalidWeather = createValidBattleState()
    invalidWeather.weather.type = "INVALID_WEATHER"
    success, error = validator.validateBattleState(invalidWeather)
    assert(success == false, "Battle with invalid weather should fail")
    
    print("    ✅ Battle state validation tests passed")
end

local function testInventoryValidation(validator)
    print("  🧪 Testing inventory validation...")
    
    -- Valid inventory should pass
    local validInventory = createValidInventory()
    local success, error = validator.validateInventory(validInventory)
    assert(success == true, "Valid inventory should pass validation")
    
    -- Negative money should fail
    local negativeMoney = createValidInventory()
    negativeMoney.money = -100
    success, error = validator.validateInventory(negativeMoney)
    assert(success == false, "Negative money should fail")
    
    -- Excessive money should fail
    local excessiveMoney = createValidInventory()
    excessiveMoney.money = 1000000000
    success, error = validator.validateInventory(excessiveMoney)
    assert(success == false, "Money > 999999999 should fail")
    
    -- Invalid item quantity should fail
    local invalidQuantity = createValidInventory()
    invalidQuantity.items.POTION = 1000
    success, error = validator.validateInventory(invalidQuantity)
    assert(success == false, "Item quantity > 999 should fail")
    
    print("    ✅ Inventory validation tests passed")
end

local function testProgressionValidation(validator)
    print("  🧪 Testing progression validation...")
    
    -- Valid progression should pass
    local validProgression = createValidProgression()
    local success, error = validator.validateProgression(validProgression)
    assert(success == true, "Valid progression should pass validation")
    
    -- Excessive experience should fail
    local excessiveExp = createValidProgression()
    excessiveExp.exp = 1000001
    success, error = validator.validateProgression(excessiveExp)
    assert(success == false, "Experience > 1000000 should fail")
    
    -- Too many badges should fail
    local tooManyBadges = createValidProgression()
    tooManyBadges.badges = {"B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9"}
    success, error = validator.validateProgression(tooManyBadges)
    assert(success == false, "More than 8 badges should fail")
    
    print("    ✅ Progression validation tests passed")
end

local function testGameStateValidation(validator)
    print("  🧪 Testing complete GameState validation...")
    
    -- Valid GameState should pass
    local validGameState = createValidGameState()
    local success, errors = validator.validateGameState(validGameState)
    assert(success == true, "Valid GameState should pass validation")
    
    -- GameState with multiple errors should fail
    local invalidGameState = createValidGameState()
    invalidGameState.party[1].level = 101  -- Invalid level
    invalidGameState.inventory.money = -100  -- Invalid money
    
    success, errors = validator.validateGameState(invalidGameState)
    assert(success == false, "Invalid GameState should fail validation")
    assert(type(errors) == "table", "Errors should be returned as table")
    assert(#errors >= 2, "Should have multiple validation errors")
    
    print("    ✅ GameState validation tests passed")
end

local function testProcessBoundaryValidation(validator)
    print("  🧪 Testing process boundary validation...")
    
    -- Valid operation should pass
    local validGameState = createValidGameState()
    local result = validator.validateAtProcessBoundary(validGameState, "BattleAction")
    
    assert(result ~= nil, "Result should not be nil")
    assert(result.valid == true, "Valid operation should pass boundary validation, got: " .. tostring(result.valid))
    assert(result.operationType == "BattleAction", "Operation type should be preserved")
    assert(result.timestamp ~= nil, "Timestamp should be included")
    
    -- Invalid operation should fail
    local invalidGameState = createValidGameState()
    invalidGameState.party[1].level = 101
    result = validator.validateAtProcessBoundary(invalidGameState, "InvalidAction")
    
    assert(result ~= nil, "Result should not be nil for invalid state")
    assert(result.valid == false, "Invalid operation should fail boundary validation")
    assert(result.violations ~= nil, "Violations should be included")
    assert(result.operationType == "InvalidAction", "Operation type should be preserved")
    
    print("    ✅ Process boundary validation tests passed")
end

local function testPerformance(validator)
    print("  🧪 Testing validation performance...")
    
    -- Test with large GameState
    local largeGameState = createValidGameState()
    
    -- Add full party
    for i = 2, 6 do
        largeGameState.party[i] = createValidPokemon()
    end
    
    -- Add many items
    for i = 1, 50 do
        largeGameState.inventory.items["ITEM_" .. i] = 10
    end
    
    local startTime = os.clock()
    local success, error = validator.validateGameState(largeGameState)
    local endTime = os.clock()
    local duration = endTime - startTime
    
    assert(success == true, "Large GameState should validate successfully")
    assert(duration < 0.05, "Validation should complete within 50ms (actual: " .. duration .. "s)")
    
    print("    ✅ Performance tests passed - validation completed in " .. string.format("%.3f", duration) .. "s")
end

-- Main test runner
local function runAllTests()
    print("🚀 GameState Validator Test Suite")
    print("="..string.rep("=", 50))
    
    local validator = loadValidator()
    
    testPokemonStatsValidation(validator)
    testBattleStateValidation(validator)
    testInventoryValidation(validator)
    testProgressionValidation(validator)
    testGameStateValidation(validator)
    testProcessBoundaryValidation(validator)
    testPerformance(validator)
    
    print("="..string.rep("=", 50))
    print("🎉 All GameState Validator tests passed!")
    return true
end

-- Run the tests
local success = pcall(runAllTests)
if not success then
    print("❌ Test execution failed")
    os.exit(1)
end

print("✅ GameState Validator test suite completed successfully")