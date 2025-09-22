#!/usr/bin/env lua

--[[
Assertion Library for HyperBeam Testing Framework
Provides comprehensive assertion utilities for AO message validation,
state comparison, and game-specific validations
Version: 1.0.0
]]

local Assert = {}

-- Basic assertion functions
function Assert.equals(actual, expected, message)
    message = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
    if actual ~= expected then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.notEquals(actual, expected, message)
    message = message or string.format("Expected not %s, got %s", tostring(expected), tostring(actual))
    if actual == expected then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.isTrue(value, message)
    message = message or "Expected condition to be true"
    if not value then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.isFalse(value, message)
    message = message or "Expected condition to be false"
    if value then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.isNil(value, message)
    message = message or "Expected value to be nil"
    if value ~= nil then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.notNil(value, message)
    message = message or "Expected value to not be nil"
    if value == nil then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.hasType(value, expectedType, message)
    message = message or string.format("Expected type %s, got %s", expectedType, type(value))
    if type(value) ~= expectedType then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

function Assert.contains(table, value, message)
    message = message or string.format("Expected table to contain %s", tostring(value))
    if type(table) ~= "table" then
        error("Assertion failed: First argument must be a table", 2)
    end
    
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    error("Assertion failed: " .. message, 2)
end

function Assert.hasKey(table, key, message)
    message = message or string.format("Expected table to have key %s", tostring(key))
    if type(table) ~= "table" then
        error("Assertion failed: First argument must be a table", 2)
    end
    
    if table[key] == nil then
        error("Assertion failed: " .. message, 2)
    end
    return true
end

-- AO Message-specific assertions
function Assert.messageEquals(actualMsg, expectedMsg)
    Assert.hasType(actualMsg, "table", "Actual message must be a table")
    Assert.hasType(expectedMsg, "table", "Expected message must be a table")
    
    -- Compare core message properties
    local coreFields = {"From", "Target", "Action", "Data"}
    for _, field in ipairs(coreFields) do
        if expectedMsg[field] ~= nil then
            Assert.equals(actualMsg[field], expectedMsg[field], 
                string.format("Message field %s should match", field))
        end
    end
    
    -- Compare Tags if present
    if expectedMsg.Tags then
        Assert.notNil(actualMsg.Tags, "Actual message should have Tags")
        for tagName, tagValue in pairs(expectedMsg.Tags) do
            Assert.equals(actualMsg.Tags[tagName], tagValue,
                string.format("Tag %s should match", tagName))
        end
    end
    
    return true
end

function Assert.hasAction(msg, action)
    Assert.hasType(msg, "table", "Message must be a table")
    
    -- Check both direct Action field and Tags.Action
    local hasDirectAction = msg.Action == action
    local hasTagAction = msg.Tags and msg.Tags.Action == action
    
    if not (hasDirectAction or hasTagAction) then
        error(string.format("Assertion failed: Message should have Action '%s', got Action='%s', Tags.Action='%s'",
            action, tostring(msg.Action), 
            msg.Tags and tostring(msg.Tags.Action) or "nil"), 2)
    end
    
    return true
end

function Assert.hasTag(msg, tagName, tagValue)
    Assert.hasType(msg, "table", "Message must be a table")
    Assert.notNil(msg.Tags, "Message must have Tags")
    
    if tagValue then
        Assert.equals(msg.Tags[tagName], tagValue,
            string.format("Tag %s should equal %s", tagName, tostring(tagValue)))
    else
        Assert.notNil(msg.Tags[tagName],
            string.format("Tag %s should exist", tagName))
    end
    
    return true
end

function Assert.isSuccessResponse(msg)
    Assert.hasType(msg, "table", "Response must be a table")
    
    -- Check for success indicators
    local isSuccess = false
    
    -- Look for various success patterns
    if msg.Action == "Success" or msg.Action == "SaveState" then
        isSuccess = true
    elseif msg.Tags and (msg.Tags.Action == "Success" or msg.Tags.Action == "SaveState") then
        isSuccess = true
    elseif msg.success == true then
        isSuccess = true
    elseif msg.Data and type(msg.Data) == "string" then
        local decoded = json and json.decode(msg.Data)
        if decoded and decoded.success == true then
            isSuccess = true
        end
    end
    
    if not isSuccess then
        error("Assertion failed: Response should indicate success", 2)
    end
    
    return true
end

function Assert.isErrorResponse(msg)
    Assert.hasType(msg, "table", "Response must be a table")
    
    -- Check for error indicators
    local isError = false
    
    if msg.Action == "Error" then
        isError = true
    elseif msg.Tags and msg.Tags.Action == "Error" then
        isError = true
    elseif msg.Error then
        isError = true
    elseif msg.success == false then
        isError = true
    end
    
    if not isError then
        error("Assertion failed: Response should indicate error", 2)
    end
    
    return true
end

function Assert.hasGameState(msg)
    Assert.hasType(msg, "table", "Message must be a table")
    
    local hasGameState = false
    
    if msg.GameState then
        hasGameState = true
    elseif msg.Data then
        local data = msg.Data
        if type(data) == "string" then
            -- Simple check for gameState in JSON string
            hasGameState = string.find(data, "gameState") ~= nil
        elseif type(data) == "table" and data.gameState then
            hasGameState = true
        end
    end
    
    if not hasGameState then
        error("Assertion failed: Message should contain GameState", 2)
    end
    
    return true
end

-- Game State assertions
function Assert.stateEquals(actualState, expectedState, path)
    path = path or "root"
    
    if type(expectedState) ~= type(actualState) then
        error(string.format("Assertion failed: Type mismatch at %s - expected %s, got %s",
            path, type(expectedState), type(actualState)), 2)
    end
    
    if type(expectedState) == "table" then
        for key, expectedValue in pairs(expectedState) do
            local newPath = path .. "." .. tostring(key)
            local actualValue = actualState[key]
            
            if actualValue == nil then
                error(string.format("Assertion failed: Missing key at %s", newPath), 2)
            end
            
            Assert.stateEquals(actualValue, expectedValue, newPath)
        end
    else
        if actualState ~= expectedState then
            error(string.format("Assertion failed: Value mismatch at %s - expected %s, got %s",
                path, tostring(expectedState), tostring(actualState)), 2)
        end
    end
    
    return true
end

function Assert.stateContains(state, expectedSubset, path)
    path = path or "root"
    
    Assert.hasType(state, "table", "State must be a table")
    Assert.hasType(expectedSubset, "table", "Expected subset must be a table")
    
    for key, expectedValue in pairs(expectedSubset) do
        local newPath = path .. "." .. tostring(key)
        local actualValue = state[key]
        
        if actualValue == nil then
            error(string.format("Assertion failed: Missing key at %s", newPath), 2)
        end
        
        if type(expectedValue) == "table" then
            Assert.stateContains(actualValue, expectedValue, newPath)
        else
            Assert.equals(actualValue, expectedValue,
                string.format("Value mismatch at %s", newPath))
        end
    end
    
    return true
end

function Assert.validPokemon(pokemon)
    Assert.hasType(pokemon, "table", "Pokemon must be a table")
    
    -- Required Pokemon fields
    local requiredFields = {"id", "speciesId", "level", "currentHp", "stats"}
    for _, field in ipairs(requiredFields) do
        Assert.notNil(pokemon[field], string.format("Pokemon must have %s field", field))
    end
    
    -- Validate stats structure
    Assert.hasType(pokemon.stats, "table", "Pokemon stats must be a table")
    local requiredStats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
    for _, stat in ipairs(requiredStats) do
        Assert.hasType(pokemon.stats[stat], "number", 
            string.format("Pokemon stat %s must be a number", stat))
        Assert.isTrue(pokemon.stats[stat] >= 0, 
            string.format("Pokemon stat %s must be non-negative", stat))
    end
    
    -- Validate level
    Assert.hasType(pokemon.level, "number", "Pokemon level must be a number")
    Assert.isTrue(pokemon.level >= 1 and pokemon.level <= 100, 
        "Pokemon level must be between 1 and 100")
    
    -- Validate current HP
    Assert.hasType(pokemon.currentHp, "number", "Pokemon currentHp must be a number")
    Assert.isTrue(pokemon.currentHp >= 0, "Pokemon currentHp must be non-negative")
    Assert.isTrue(pokemon.currentHp <= pokemon.stats.hp, 
        "Pokemon currentHp must not exceed max HP")
    
    return true
end

function Assert.validBattleState(battleState)
    Assert.hasType(battleState, "table", "Battle state must be a table")
    
    -- Required battle state fields
    local requiredFields = {"turn", "playerPokemon", "opponentPokemon"}
    for _, field in ipairs(requiredFields) do
        Assert.notNil(battleState[field], string.format("Battle state must have %s field", field))
    end
    
    -- Validate turn
    Assert.hasType(battleState.turn, "number", "Battle turn must be a number")
    Assert.isTrue(battleState.turn >= 1, "Battle turn must be positive")
    
    -- Validate Pokemon
    if battleState.playerPokemon then
        Assert.validPokemon(battleState.playerPokemon)
    end
    if battleState.opponentPokemon then
        Assert.validPokemon(battleState.opponentPokemon)
    end
    
    return true
end

-- Error assertion functions
function Assert.throws(func, expectedError)
    Assert.hasType(func, "function", "First argument must be a function")
    
    local success, actualError = pcall(func)
    
    if success then
        error("Assertion failed: Function should have thrown an error", 2)
    end
    
    if expectedError then
        local errorMatches = string.find(tostring(actualError), expectedError, 1, true)
        if not errorMatches then
            error(string.format("Assertion failed: Error should contain '%s', got '%s'",
                expectedError, tostring(actualError)), 2)
        end
    end
    
    return true
end

function Assert.doesNotThrow(func)
    Assert.hasType(func, "function", "Argument must be a function")
    
    local success, err = pcall(func)
    
    if not success then
        error(string.format("Assertion failed: Function should not throw an error, got: %s",
            tostring(err)), 2)
    end
    
    return true
end

-- Performance assertions
function Assert.executesWithin(func, maxTime, message)
    Assert.hasType(func, "function", "First argument must be a function")
    Assert.hasType(maxTime, "number", "Max time must be a number")
    
    local startTime = os.clock()
    func()
    local endTime = os.clock()
    
    local actualTime = (endTime - startTime) * 1000 -- Convert to milliseconds
    
    if actualTime > maxTime then
        error(string.format("Assertion failed: %s - expected execution within %dms, took %dms",
            message or "Function should execute within time limit", maxTime, actualTime), 2)
    end
    
    return true
end

-- Collection-specific assertions
function Assert.hasLength(collection, expectedLength)
    Assert.hasType(collection, "table", "Collection must be a table")
    Assert.hasType(expectedLength, "number", "Expected length must be a number")
    
    local actualLength = #collection
    if actualLength ~= expectedLength then
        error(string.format("Assertion failed: Expected length %d, got %d",
            expectedLength, actualLength), 2)
    end
    
    return true
end

function Assert.isEmpty(collection)
    Assert.hasType(collection, "table", "Collection must be a table")
    
    local isEmpty = next(collection) == nil
    if not isEmpty then
        error("Assertion failed: Collection should be empty", 2)
    end
    
    return true
end

function Assert.isNotEmpty(collection)
    Assert.hasType(collection, "table", "Collection must be a table")
    
    local isEmpty = next(collection) == nil
    if isEmpty then
        error("Assertion failed: Collection should not be empty", 2)
    end
    
    return true
end

return Assert