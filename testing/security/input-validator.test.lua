-- Input Validator Unit Tests
-- Comprehensive test suite for input validation and sanitization system

-- Test data factories
local function createValidMessage(action, data)
    return {
        From = "test_process_123",
        Action = action or "ValidateGameState",
        Data = data and json.encode(data) or '{"test": "data"}'
    }
end

local function createValidPokemon()
    return {
        id = 1,
        species = "BULBASAUR",
        level = 5,
        hp = 20,
        maxHp = 20,
        status = "NONE",
        ivs = {
            hp = 15,
            attack = 12,
            defense = 13,
            spAttack = 16,
            spDefense = 14,
            speed = 11
        },
        moves = {
            {id = 1, name = "TACKLE", pp = 35, maxPp = 35}
        }
    }
end

local function createValidGameState()
    return {
        party = {createValidPokemon()},
        inventory = {
            money = 3000,
            items = {POTION = 5},
            keyItems = {"POKEDEX"}
        },
        progression = {
            exp = 1000,
            badges = {"BOULDER_BADGE"},
            unlockedAreas = {"PALLET_TOWN"}
        }
    }
end

-- Test functions
local function testBasicFieldValidation(validator)
    print("  🧪 Testing basic field validation...")
    
    -- Test type validation
    local valid, err = validator.validateField("test", {type = "string"}, "testField")
    assert(valid == true, "Valid string should pass type validation")
    
    valid, err = validator.validateField(123, {type = "string"}, "testField")
    assert(valid == false, "Number should fail string type validation")
    assert(string.find(err, "type"), "Error should mention type")
    
    -- Test range validation
    valid, err = validator.validateField(5, {type = "number", min = 1, max = 10}, "testField")
    assert(valid == true, "Number in range should pass validation")
    
    valid, err = validator.validateField(15, {type = "number", min = 1, max = 10}, "testField")
    assert(valid == false, "Number out of range should fail validation")
    assert(string.find(err, "between"), "Error should mention range")
    
    -- Test string length validation
    valid, err = validator.validateField("test", {type = "string", minLength = 1, maxLength = 10}, "testField")
    assert(valid == true, "String in length range should pass validation")
    
    valid, err = validator.validateField("very_long_string_that_exceeds_limit", {type = "string", minLength = 1, maxLength = 10}, "testField")
    assert(valid == false, "String exceeding max length should fail validation")
    
    -- Test pattern validation
    valid, err = validator.validateField("ABC123", {type = "string", pattern = "^[A-Z0-9]+$"}, "testField")
    assert(valid == true, "String matching pattern should pass validation")
    
    valid, err = validator.validateField("abc123", {type = "string", pattern = "^[A-Z0-9]+$"}, "testField")
    assert(valid == false, "String not matching pattern should fail validation")
    
    -- Test whitelist validation
    valid, err = validator.validateField("ATTACK", {type = "string", allowedValues = {"ATTACK", "DEFEND", "RUN"}}, "testField")
    assert(valid == true, "Value in whitelist should pass validation")
    
    valid, err = validator.validateField("INVALID", {type = "string", allowedValues = {"ATTACK", "DEFEND", "RUN"}}, "testField")
    assert(valid == false, "Value not in whitelist should fail validation")
    
    print("    ✅ Basic field validation tests passed")
end

local function testArrayValidation(validator)
    print("  🧪 Testing array validation...")
    
    -- Test basic array validation
    local arraySchema = {type = "table", isArray = true, maxItems = 3}
    local valid, err = validator.validateField({"a", "b", "c"}, arraySchema, "testArray")
    assert(valid == true, "Valid array should pass validation")
    
    valid, err = validator.validateField({"a", "b", "c", "d"}, arraySchema, "testArray")
    assert(valid == false, "Array exceeding max length should fail validation")
    
    -- Test array with item schema
    local typedArraySchema = {
        type = "table",
        isArray = true,
        maxItems = 3,
        itemSchema = {type = "number", min = 1, max = 10}
    }
    
    valid, err = validator.validateField({1, 5, 10}, typedArraySchema, "testArray")
    assert(valid == true, "Valid typed array should pass validation")
    
    valid, err = validator.validateField({1, 5, 15}, typedArraySchema, "testArray")
    assert(valid == false, "Typed array with invalid item should fail validation")
    assert(string.find(err, "testArray%[3%]"), "Error should indicate array index")
    
    print("    ✅ Array validation tests passed")
end

local function testObjectValidation(validator)
    print("  🧪 Testing object validation...")
    
    -- Test basic object validation
    local objectSchema = {
        type = "table",
        objectSchema = {
            required = {"name", "level"},
            fields = {
                name = {type = "string", minLength = 1, maxLength = 20},
                level = {type = "number", min = 1, max = 100},
                optional = {type = "string"}
            }
        }
    }
    
    local validObject = {name = "Pikachu", level = 25, optional = "test"}
    local valid, err = validator.validateField(validObject, objectSchema, "testObject")
    assert(valid == true, "Valid object should pass validation")
    
    -- Test missing required field
    local invalidObject = {level = 25}
    valid, err = validator.validateField(invalidObject, objectSchema, "testObject")
    assert(valid == false, "Object missing required field should fail validation")
    assert(string.find(err, "required field"), "Error should mention required field")
    
    -- Test invalid field type
    invalidObject = {name = "Pikachu", level = "invalid"}
    valid, err = validator.validateField(invalidObject, objectSchema, "testObject")
    assert(valid == false, "Object with invalid field type should fail validation, error: " .. tostring(err))
    
    print("    ✅ Object validation tests passed")
end

local function testPokemonSchemaValidation(validator)
    print("  🧪 Testing Pokemon schema validation...")
    
    -- Test valid Pokemon
    local validPokemon = createValidPokemon()
    local valid, err = validator.validateField(validPokemon, validator.pokemonSchema, "pokemon")
    assert(valid == true, "Valid Pokemon should pass schema validation")
    
    -- Test invalid Pokemon - missing required field
    local invalidPokemon = {species = "BULBASAUR", level = 5} -- Missing id
    valid, err = validator.validateField(invalidPokemon, validator.pokemonSchema, "pokemon")
    assert(valid == false, "Pokemon missing required field should fail validation")
    
    -- Test invalid Pokemon - invalid level
    invalidPokemon = createValidPokemon()
    invalidPokemon.level = 150
    valid, err = validator.validateField(invalidPokemon, validator.pokemonSchema, "pokemon")
    assert(valid == false, "Pokemon with invalid level should fail validation")
    
    -- Test invalid Pokemon - invalid status
    invalidPokemon = createValidPokemon()
    invalidPokemon.status = "INVALID_STATUS"
    valid, err = validator.validateField(invalidPokemon, validator.pokemonSchema, "pokemon")
    assert(valid == false, "Pokemon with invalid status should fail validation")
    
    -- Test invalid Pokemon - invalid IV
    invalidPokemon = createValidPokemon()
    invalidPokemon.ivs.hp = 35
    valid, err = validator.validateField(invalidPokemon, validator.pokemonSchema, "pokemon")
    assert(valid == false, "Pokemon with invalid IV should fail validation")
    
    -- Test invalid Pokemon - too many moves
    invalidPokemon = createValidPokemon()
    for i = 2, 6 do
        table.insert(invalidPokemon.moves, {id = i, name = "MOVE_" .. i, pp = 10, maxPp = 10})
    end
    valid, err = validator.validateField(invalidPokemon, validator.pokemonSchema, "pokemon")
    assert(valid == false, "Pokemon with too many moves should fail validation")
    
    print("    ✅ Pokemon schema validation tests passed")
end

local function testGameStateSchemaValidation(validator)
    print("  🧪 Testing GameState schema validation...")
    
    -- Test valid GameState
    local validGameState = createValidGameState()
    local valid, err = validator.validateField(validGameState, validator.gameStateSchema, "gameState")
    assert(valid == true, "Valid GameState should pass schema validation")
    
    -- Test invalid party size
    local invalidGameState = createValidGameState()
    for i = 2, 7 do
        table.insert(invalidGameState.party, createValidPokemon())
    end
    valid, err = validator.validateField(invalidGameState, validator.gameStateSchema, "gameState")
    assert(valid == false, "GameState with too many party members should fail validation")
    
    -- Test invalid money
    invalidGameState = createValidGameState()
    invalidGameState.inventory.money = -100
    valid, err = validator.validateField(invalidGameState, validator.gameStateSchema, "gameState")
    assert(valid == false, "GameState with negative money should fail validation")
    
    print("    ✅ GameState schema validation tests passed")
end

local function testMessageStructureValidation(validator)
    print("  🧪 Testing message structure validation...")
    
    -- Test valid message
    local validMessage = createValidMessage()
    local valid, errors = validator.validateMessageStructure(validMessage)
    assert(valid == true, "Valid message should pass structure validation")
    assert(#errors == 0, "Valid message should have no errors")
    
    -- Test missing required fields
    local invalidMessage = {Action = "Test"}
    valid, errors = validator.validateMessageStructure(invalidMessage)
    assert(valid == false, "Message missing From field should fail validation")
    assert(#errors > 0, "Should have validation errors")
    
    invalidMessage = {From = "test_process"}
    valid, errors = validator.validateMessageStructure(invalidMessage)
    assert(valid == false, "Message missing Action field should fail validation")
    
    -- Test invalid field types
    invalidMessage = {From = 123, Action = "Test"}
    valid, errors = validator.validateMessageStructure(invalidMessage)
    assert(valid == false, "Message with invalid From type should fail validation")
    
    -- Test invalid From format
    invalidMessage = {From = "invalid format!", Action = "Test"}
    valid, errors = validator.validateMessageStructure(invalidMessage)
    assert(valid == false, "Message with invalid From format should fail validation")
    
    -- Test invalid Action format
    invalidMessage = {From = "test_process", Action = "123InvalidAction"}
    valid, errors = validator.validateMessageStructure(invalidMessage)
    assert(valid == false, "Message with invalid Action format should fail validation")
    
    print("    ✅ Message structure validation tests passed")
end

local function testComprehensiveMessageValidation(validator)
    print("  🧪 Testing comprehensive message validation...")
    
    -- Test valid GameState validation message
    local gameStateData = createValidGameState()
    local validMessage = createValidMessage("ValidateGameState", gameStateData)
    
    local result = validator.validateMessage(validMessage)
    assert(result.valid == true, "Valid GameState message should pass validation")
    assert(#result.errors == 0, "Valid message should have no errors")
    assert(result.sanitizedData ~= nil, "Valid message should have sanitized data")
    
    -- Test invalid JSON in data
    local invalidJsonMessage = createValidMessage("ValidateGameState")
    invalidJsonMessage.Data = "invalid json {"
    
    result = validator.validateMessage(invalidJsonMessage)
    assert(result.valid == false, "Message with invalid JSON should fail validation")
    assert(#result.errors > 0, "Should have JSON parsing error")
    
    -- Test data that doesn't match schema
    local invalidDataMessage = createValidMessage("ValidateGameState", {invalid = "data"})
    result = validator.validateMessage(invalidDataMessage)
    if result.valid then
        print("    Debug: Validation result:", result.valid)
        print("    Debug: Errors:", #result.errors)
        for i, error in ipairs(result.errors) do
            print("      Error " .. i .. ":", error)
        end
    end
    assert(result.valid == false, "Message with invalid data should fail validation")
    
    -- Test unknown action type (should generate warning but not fail)
    local unknownActionMessage = createValidMessage("UnknownAction")
    result = validator.validateMessage(unknownActionMessage)
    assert(result.valid == true, "Message with unknown action should pass basic validation")
    assert(#result.warnings > 0, "Should have warning for unknown action")
    
    print("    ✅ Comprehensive message validation tests passed")
end

local function testInputSanitization(validator)
    print("  🧪 Testing input sanitization...")
    
    -- Test string sanitization
    local sanitized = validator.sanitizeString("  test\nstring\twith\rcontrol  ", 25)
    assert(sanitized == "test string with control", "String should be sanitized")
    
    -- Test string truncation
    sanitized = validator.sanitizeString("very long string that should be truncated", 10)
    assert(string.len(sanitized) == 10, "String should be truncated to max length")
    
    -- Test number sanitization
    sanitized = validator.sanitizeNumber(5.7, 1, 10)
    assert(sanitized == 5.7, "Valid number should remain unchanged")
    
    sanitized = validator.sanitizeNumber(15, 1, 10)
    assert(sanitized == 10, "Number above max should be clamped")
    
    sanitized = validator.sanitizeNumber(-5, 1, 10)
    assert(sanitized == 1, "Number below min should be clamped")
    
    -- Test NaN and infinity handling
    sanitized = validator.sanitizeNumber(0/0) -- NaN
    assert(sanitized == 0, "NaN should be converted to 0")
    
    sanitized = validator.sanitizeNumber(math.huge)
    assert(sanitized == 0, "Infinity should be converted to 0")
    
    print("    ✅ Input sanitization tests passed")
end

local function testSpecificMessageSchemas(validator)
    print("  🧪 Testing specific message schemas...")
    
    -- Test BattleAction schema
    local battleActionData = {
        actionType = "ATTACK",
        pokemonIndex = 0,
        moveIndex = 1
    }
    local battleMessage = createValidMessage("BattleAction", battleActionData)
    local result = validator.validateMessage(battleMessage)
    assert(result.valid == true, "Valid BattleAction should pass validation")
    
    -- Test invalid BattleAction
    local invalidBattleActionData = {
        actionType = "INVALID_ACTION",
        pokemonIndex = 0,
        moveIndex = 1
    }
    battleMessage = createValidMessage("BattleAction", invalidBattleActionData)
    result = validator.validateMessage(battleMessage)
    assert(result.valid == false, "Invalid BattleAction should fail validation")
    
    -- Test AuthenticatePlayer schema
    local authData = {
        walletAddress = "test_wallet_address_12345_longname_40chars",
        signature = "valid_signature",
        timestamp = 1234567890
    }
    local authMessage = createValidMessage("AuthenticatePlayer", authData)
    result = validator.validateMessage(authMessage)
    assert(result.valid == true, "Valid AuthenticatePlayer should pass validation")
    
    -- Test invalid authentication data
    local invalidAuthData = {
        walletAddress = "invalid wallet address!", -- Contains invalid characters
        signature = "valid_signature",
        timestamp = 1234567890
    }
    authMessage = createValidMessage("AuthenticatePlayer", invalidAuthData)
    result = validator.validateMessage(authMessage)
    assert(result.valid == false, "Invalid wallet address should fail validation")
    
    print("    ✅ Specific message schema tests passed")
end

local function testEdgeCases(validator)
    print("  🧪 Testing edge cases...")
    
    -- Test nil inputs
    local valid, err = validator.validateField(nil, {type = "string"}, "testField")
    assert(valid == false, "Nil input should fail validation")
    
    -- Test empty objects
    valid, err = validator.validateField({}, {type = "table"}, "testField")
    assert(valid == true, "Empty object should pass basic table validation")
    
    -- Test circular references (should not crash)
    local circularRef = {}
    circularRef.self = circularRef
    
    -- This might not validate cleanly but shouldn't crash
    local success = pcall(validator.validateField, circularRef, {type = "table"}, "testField")
    assert(success == true, "Circular reference should not crash validator")
    
    -- Test extremely large numbers
    valid, err = validator.validateField(math.huge, {type = "number", max = 1000}, "testField")
    assert(valid == false, "Infinity should fail range validation")
    
    print("    ✅ Edge case tests passed")
end

local function testPerformance(validator)
    print("  🧪 Testing validation performance...")
    
    -- Create complex nested data structure
    local complexGameState = createValidGameState()
    
    -- Add full party
    for i = 2, 6 do
        complexGameState.party[i] = createValidPokemon()
    end
    
    -- Add many items and key items
    for i = 1, 50 do
        complexGameState.inventory.items["ITEM_" .. i] = 10
        table.insert(complexGameState.inventory.keyItems, "KEY_ITEM_" .. i)
    end
    
    local complexMessage = createValidMessage("ValidateGameState", complexGameState)
    
    local startTime = os.clock()
    local result = validator.validateMessage(complexMessage)
    local endTime = os.clock()
    local duration = endTime - startTime
    
    assert(result.valid == true, "Complex valid message should pass validation")
    assert(duration < 0.1, "Validation should complete within 100ms (actual: " .. duration .. "s)")
    
    print("    ✅ Performance tests passed - validation completed in " .. string.format("%.3f", duration) .. "s")
end

-- Main test runner
local function runAllTests()
    -- Setup environment
    _G.json = {
        encode = function(obj)
            if type(obj) == "table" then
                if obj.invalid == "data" then
                    return '{"invalid": "data"}'
                elseif obj.test == "data" then
                    return '{"test": "data"}'
                elseif obj.party then
                    return "gamestate_json"
                elseif obj.actionType == "ATTACK" then
                    return "battleaction_json"
                elseif obj.actionType == "INVALID_ACTION" then
                    return "invalid_battleaction_json"
                elseif obj.walletAddress == "test_wallet_address_12345_longname_40chars" then
                    return "auth_json"
                elseif obj.walletAddress == "invalid wallet address!" then
                    return "invalid_auth_json"
                else
                    return "json_encoded_table"
                end
            else
                return tostring(obj)
            end
        end,
        decode = function(str)
            if str == '{"test": "data"}' then
                return {test = "data"}
            elseif str == '{"invalid": "data"}' then
                return {invalid = "data"}
            elseif str == "gamestate_json" then
                return createValidGameState()
            elseif str == "battleaction_json" then
                return {actionType = "ATTACK", pokemonIndex = 0, moveIndex = 1}
            elseif str == "invalid_battleaction_json" then
                return {actionType = "INVALID_ACTION", pokemonIndex = 0, moveIndex = 1}
            elseif str == "auth_json" then
                return {walletAddress = "test_wallet_address_12345_longname_40chars", signature = "valid_signature", timestamp = 1234567890}
            elseif str == "invalid_auth_json" then
                return {walletAddress = "invalid wallet address!", signature = "valid_signature", timestamp = 1234567890}
            elseif string.find(str, "invalid json") then
                error("Invalid JSON")
            else
                -- Simple JSON decode simulation for other cases
                return {decoded = true}
            end
        end
    }
    _G.ao = {
        send = function(msg) end,
        id = "test_input_validator"
    }
    _G.Handlers = {
        add = function(name, matcher, handler) end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg) return true end
            end
        }
    }
    
    -- Load the validator
    dofile("processes/security/input-validator.lua")
    local validator = _G.InputValidator
    
    print("🚀 Input Validator Test Suite")
    print("="..string.rep("=", 50))
    
    testBasicFieldValidation(validator)
    testArrayValidation(validator)
    testObjectValidation(validator)
    testPokemonSchemaValidation(validator)
    testGameStateSchemaValidation(validator)
    testMessageStructureValidation(validator)
    testComprehensiveMessageValidation(validator)
    testInputSanitization(validator)
    testSpecificMessageSchemas(validator)
    testEdgeCases(validator)
    testPerformance(validator)
    
    print("="..string.rep("=", 50))
    print("🎉 All Input Validator tests passed!")
    return true
end

-- Export test runner
return {
    runAllTests = runAllTests
}