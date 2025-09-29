-- Unit tests for Move Transformation Engine
-- Tests transformation timing logic, stat copying, ability interactions, and duration tracking

-- Simple JSON implementation for testing
local json = {
    encode = function(obj)
        if type(obj) == "table" then
            local items = {}
            for k, v in pairs(obj) do
                if type(v) == "string" then
                    table.insert(items, string.format('"%s":"%s"', k, v))
                elseif type(v) == "number" then
                    table.insert(items, string.format('"%s":%s', k, v))
                elseif type(v) == "boolean" then
                    table.insert(items, string.format('"%s":%s', k, v and "true" or "false"))
                elseif type(v) == "table" then
                    table.insert(items, string.format('"%s":"%s"', k, tostring(v)))
                end
            end
            return "{" .. table.concat(items, ",") .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj .. '"'
        else
            return tostring(obj)
        end
    end,
    decode = function(str)
        -- Simple JSON decode for testing - just return a table
        return {decoded = true, original = str}
    end
}

-- Mock AO environment
local function setupTestEnvironment()
    if not ao then
        ao = {
            send = function(msg) 
                lastSentMessage = msg
                print("Mock send:", json.encode(msg)) 
            end,
            id = "test_move_transformation_engine"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                if not registeredHandlers then
                    registeredHandlers = {}
                end
                registeredHandlers[name] = {matcher = matcher, handler = handler}
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
end

-- Test utilities
local function createMockMessage(action, tags, data)
    return {
        From = "test_sender",
        Tags = tags or {},
        Data = data,
        Timestamp = 1234567890,
        Action = action
    }
end

local function createMockPokemon(speciesId, form, abilities, stats)
    return {
        speciesId = speciesId,
        form = form or "default",
        abilities = abilities or {},
        baseStats = stats or {hp = 100, atk = 100, def = 100, spa = 100, spd = 100, spe = 100},
        types = {"NORMAL"},
        moveset = {}
    }
end

-- Initialize test environment
setupTestEnvironment()

-- Global test state
local testResults = {}
local testCount = 0
local passedTests = 0

-- Test framework functions
local function startTest(testName)
    testCount = testCount + 1
    print(string.format("\n=== Test %d: %s ===", testCount, testName))
end

local function assertEqual(expected, actual, message)
    if expected == actual then
        print("✓ " .. (message or "Assertion passed"))
        return true
    else
        print("✗ " .. (message or "Assertion failed"))
        print("  Expected:", expected)
        print("  Actual:", actual)
        return false
    end
end

local function assertNotNil(value, message)
    if value ~= nil then
        print("✓ " .. (message or "Value is not nil"))
        return true
    else
        print("✗ " .. (message or "Value should not be nil"))
        return false
    end
end

local function assertTrue(condition, message)
    if condition then
        print("✓ " .. (message or "Condition is true"))
        return true
    else
        print("✗ " .. (message or "Condition should be true"))
        return false
    end
end

local function assertFalse(condition, message)
    if not condition then
        print("✓ " .. (message or "Condition is false"))
        return true
    else
        print("✗ " .. (message or "Condition should be false"))
        return false
    end
end

local function endTest(passed)
    if passed then
        passedTests = passedTests + 1
        print("✓ Test PASSED")
    else
        print("✗ Test FAILED")
    end
end

-- Load the move transformation engine
local function loadTransformationEngine()
    local success, err = pcall(function()
        dofile("processes/move-transformation-engine.lua")
    end)
    if not success then
        print("Warning: Could not load move-transformation-engine.lua:", err)
        return false
    end
    return true
end

if not loadTransformationEngine() then
    print("Skipping tests - transformation engine not available")
    return
end

-- Test 1: Aegislash pre-move transformation (Shield to Blade)
startTest("Aegislash Shield to Blade transformation on offensive move")
do
    local mockMsg = createMockMessage("ProcessPreMoveTransformation", {
        Action = "ProcessPreMoveTransformation",
        PokemonId = "aegislash_001",
        MoveId = "THUNDERBOLT", -- Non-STATUS move
        SpeciesId = "681",
        CurrentForm = "shield"
    }, json.encode(createMockPokemon(681, "shield", {STANCE_CHANGE = true})))
    
    -- Reset last sent message
    lastSentMessage = nil
    
    -- Execute handler
    local handler = registeredHandlers["process-pre-move-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformationTriggered", lastSentMessage.Action, "Transformation triggered")
    passed = passed and assertEqual("shield", lastSentMessage.FromForm, "Correct from form")
    passed = passed and assertEqual("blade", lastSentMessage.ToForm, "Correct to form")
    passed = passed and assertEqual("pre_move", lastSentMessage.TransformationType, "Correct transformation type")
    
    endTest(passed)
end

-- Test 2: Aegislash pre-move transformation (Blade to Shield with King's Shield)
startTest("Aegislash Blade to Shield transformation on King's Shield")
do
    local mockMsg = createMockMessage("ProcessPreMoveTransformation", {
        Action = "ProcessPreMoveTransformation",
        PokemonId = "aegislash_001",
        MoveId = "KINGS_SHIELD", -- Specific move trigger
        SpeciesId = "681",
        CurrentForm = "blade"
    }, json.encode(createMockPokemon(681, "blade", {STANCE_CHANGE = true})))
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-pre-move-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformationTriggered", lastSentMessage.Action, "Transformation triggered")
    passed = passed and assertEqual("blade", lastSentMessage.FromForm, "Correct from form")
    passed = passed and assertEqual("shield", lastSentMessage.ToForm, "Correct to form")
    
    endTest(passed)
end

-- Test 3: Aegislash transformation blocked without Stance Change ability
startTest("Aegislash transformation blocked without required ability")
do
    local mockMsg = createMockMessage("ProcessPreMoveTransformation", {
        Action = "ProcessPreMoveTransformation",
        PokemonId = "aegislash_001",
        MoveId = "THUNDERBOLT",
        SpeciesId = "681",
        CurrentForm = "shield"
    }, json.encode(createMockPokemon(681, "shield", {}))) -- No Stance Change ability
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-pre-move-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("NoTransformation", lastSentMessage.Action, "Transformation blocked")
    
    endTest(passed)
end

-- Test 4: Meloetta post-move transformation (Aria to Pirouette)
startTest("Meloetta Aria to Pirouette transformation on Relic Song")
do
    local mockMsg = createMockMessage("ProcessPostMoveTransformation", {
        Action = "ProcessPostMoveTransformation",
        PokemonId = "meloetta_001",
        MoveId = "RELIC_SONG",
        SpeciesId = "648",
        CurrentForm = "aria"
    }, json.encode(createMockPokemon(648, "aria", {})))
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-post-move-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformationTriggered", lastSentMessage.Action, "Transformation triggered")
    passed = passed and assertEqual("aria", lastSentMessage.FromForm, "Correct from form")
    passed = passed and assertEqual("pirouette", lastSentMessage.ToForm, "Correct to form")
    passed = passed and assertEqual("post_move", lastSentMessage.TransformationType, "Correct transformation type")
    passed = passed and assertEqual("true", lastSentMessage.ToggleMode, "Toggle mode enabled")
    
    endTest(passed)
end

-- Test 5: Meloetta transformation blocked by Sheer Force
startTest("Meloetta transformation blocked by Sheer Force ability")
do
    local mockMsg = createMockMessage("ProcessPostMoveTransformation", {
        Action = "ProcessPostMoveTransformation",
        PokemonId = "meloetta_001",
        MoveId = "RELIC_SONG",
        SpeciesId = "648",
        CurrentForm = "aria"
    }, json.encode(createMockPokemon(648, "aria", {SHEER_FORCE = true})))
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-post-move-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("NoTransformation", lastSentMessage.Action, "Transformation blocked by Sheer Force")
    
    endTest(passed)
end

-- Test 6: Transform move success
startTest("Transform move complete species transformation")
do
    local userPokemon = createMockPokemon(132, "default", {}, {hp = 48, atk = 48, def = 48, spa = 48, spd = 48, spe = 48})
    local targetPokemon = createMockPokemon(25, "default", {STATIC = true}, {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90})
    targetPokemon.types = {"ELECTRIC"}
    targetPokemon.moveset = {
        {moveId = "THUNDERBOLT", pp = 15, maxPP = 15},
        {moveId = "QUICK_ATTACK", pp = 30, maxPP = 30}
    }
    
    local mockMsg = createMockMessage("ProcessTransformMove", {
        Action = "ProcessTransformMove",
        UserPokemonId = "ditto_001",
        TargetPokemonId = "pikachu_001",
        BattleId = "battle_001"
    })
    mockMsg.UserData = json.encode(userPokemon)
    mockMsg.TargetData = json.encode(targetPokemon)
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-transform-move"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformSuccess", lastSentMessage.Action, "Transform succeeded")
    passed = passed and assertEqual("ditto_001", lastSentMessage.UserPokemonId, "Correct user Pokemon ID")
    passed = passed and assertEqual("battle", lastSentMessage.Duration, "Correct duration")
    
    -- Check transformed data
    if lastSentMessage.TransformedData then
        local transformedData = json.decode(lastSentMessage.TransformedData)
        passed = passed and assertEqual(25, transformedData.speciesId, "Species copied correctly")
        passed = passed and assertEqual(55, transformedData.baseStats.atk, "Attack stat copied correctly")
        passed = passed and assertEqual(48, transformedData.baseStats.hp, "HP stat preserved")
    end
    
    endTest(passed)
end

-- Test 7: Transform move failure (same species)
startTest("Transform move fails on same species")
do
    local userPokemon = createMockPokemon(25, "default", {}, {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90})
    local targetPokemon = createMockPokemon(25, "default", {STATIC = true}, {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90})
    
    local mockMsg = createMockMessage("ProcessTransformMove", {
        Action = "ProcessTransformMove",
        UserPokemonId = "pikachu_001",
        TargetPokemonId = "pikachu_002"
    })
    mockMsg.UserData = json.encode(userPokemon)
    mockMsg.TargetData = json.encode(targetPokemon)
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-transform-move"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformFailed", lastSentMessage.Action, "Transform failed correctly")
    
    endTest(passed)
end

-- Test 8: Transformation reversion on switch out
startTest("Transform reversion on switch out")
do
    -- First setup a transformation in battle state
    State.battleTransformations = {
        battle_001 = {
            ditto_001 = {
                originalData = {speciesId = 132, baseStats = {hp = 48, atk = 48, def = 48, spa = 48, spd = 48, spe = 48}},
                transformationType = "transform_move",
                duration = "battle"
            }
        }
    }
    
    local mockMsg = createMockMessage("RevertTransformation", {
        Action = "RevertTransformation",
        PokemonId = "ditto_001",
        BattleId = "battle_001",
        RevertType = "switch_out"
    })
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["revert-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformationReverted", lastSentMessage.Action, "Transformation reverted")
    passed = passed and assertEqual("ditto_001", lastSentMessage.PokemonId, "Correct Pokemon ID")
    
    endTest(passed)
end

-- Test 9: Move learned transformation (Keldeo)
startTest("Keldeo transformation on Secret Sword learned")
do
    local mockMsg = createMockMessage("ProcessMoveLearnedTransformation", {
        Action = "ProcessMoveLearnedTransformation",
        PokemonId = "keldeo_001",
        MoveId = "SECRET_SWORD",
        SpeciesId = "647",
        CurrentForm = "ordinary"
    }, json.encode(createMockPokemon(647, "ordinary", {})))
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["process-move-learned-transformation"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformationTriggered", lastSentMessage.Action, "Transformation triggered")
    passed = passed and assertEqual("ordinary", lastSentMessage.FromForm, "Correct from form")
    passed = passed and assertEqual("resolute", lastSentMessage.ToForm, "Correct to form")
    passed = passed and assertEqual("move_learned", lastSentMessage.TransformationType, "Correct transformation type")
    
    endTest(passed)
end

-- Test 10: Get transformation info
startTest("Get transformation info for Aegislash")
do
    local mockMsg = createMockMessage("GetTransformationInfo", {
        Action = "GetTransformationInfo",
        SpeciesId = "681"
    })
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["get-transformation-info"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("TransformationInfo", lastSentMessage.Action, "Info retrieved")
    passed = passed and assertEqual("681", lastSentMessage.SpeciesId, "Correct species ID")
    passed = passed and assertEqual("Aegislash", lastSentMessage.SpeciesName, "Correct species name")
    
    endTest(passed)
end

-- Test 11: ADP Info handler
startTest("ADP Info handler returns comprehensive process information")
do
    local mockMsg = createMockMessage("Info", {
        Action = "Info"
    })
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["info"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("SaveState", lastSentMessage.Action, "Correct action")
    
    if lastSentMessage.Data then
        local infoData = json.decode(lastSentMessage.Data)
        passed = passed and assertEqual("Move Transformation Engine", infoData.Name, "Correct process name")
        passed = passed and assertEqual("1.0", infoData.adpVersion, "ADP version 1.0")
        passed = passed and assertNotNil(infoData.handlers, "Handlers documented")
        passed = passed and assertNotNil(infoData.capabilities, "Capabilities listed")
    end
    
    endTest(passed)
end

-- Test 12: Ping handler
startTest("Ping handler responds correctly")
do
    local mockMsg = createMockMessage("Ping", {
        Action = "Ping"
    })
    
    lastSentMessage = nil
    
    local handler = registeredHandlers["ping"]
    if handler then
        handler.handler(mockMsg)
    end
    
    local passed = true
    passed = passed and assertNotNil(lastSentMessage, "Response message sent")
    passed = passed and assertEqual("Pong", lastSentMessage.Action, "Correct pong response")
    passed = passed and assertEqual("pong", lastSentMessage.Data, "Correct pong data")
    
    endTest(passed)
end

-- Print test results
print(string.format("\n=== TEST RESULTS ==="))
print(string.format("Total tests: %d", testCount))
print(string.format("Passed: %d", passedTests))
print(string.format("Failed: %d", testCount - passedTests))
print(string.format("Success rate: %.1f%%", (passedTests / testCount) * 100))

if passedTests == testCount then
    print("🎉 ALL TESTS PASSED! 🎉")
else
    print("❌ Some tests failed. Review the output above.")
end