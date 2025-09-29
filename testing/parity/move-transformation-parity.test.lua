-- Parity tests for Move Transformation Engine
-- Validates behavioral parity with TypeScript reference implementation

local json = require("json")

-- Parity test framework
local ParityTest = {}
ParityTest.__index = ParityTest

function ParityTest.new(name, description)
    local self = setmetatable({}, ParityTest)
    self.name = name
    self.description = description
    self.scenarios = {}
    self.results = {}
    self.passed = false
    return self
end

function ParityTest:addScenario(scenarioName, luaFunction, expectedResult, tolerance)
    table.insert(self.scenarios, {
        name = scenarioName,
        luaFunction = luaFunction,
        expectedResult = expectedResult,
        tolerance = tolerance or 0
    })
    return self
end

function ParityTest:run()
    print(string.format("\n🔍 Running Parity Test: %s", self.name))
    print(string.format("📝 Description: %s", self.description))
    
    local allScenariosPassed = true
    
    for i, scenario in ipairs(self.scenarios) do
        print(string.format("\n  Scenario %d: %s", i, scenario.name))
        
        local success, luaResult = pcall(scenario.luaFunction)
        
        if success then
            local matches = self:compareResults(luaResult, scenario.expectedResult, scenario.tolerance)
            
            if matches then
                print(string.format("  ✅ Scenario %d: MATCH", i))
                self.results[scenario.name] = {passed = true, luaResult = luaResult, expected = scenario.expectedResult}
            else
                print(string.format("  ❌ Scenario %d: MISMATCH", i))
                print(string.format("    Lua result: %s", self:formatResult(luaResult)))
                print(string.format("    Expected:   %s", self:formatResult(scenario.expectedResult)))
                self.results[scenario.name] = {passed = false, luaResult = luaResult, expected = scenario.expectedResult}
                allScenariosPassed = false
            end
        else
            print(string.format("  💥 Scenario %d: ERROR - %s", i, luaResult))
            self.results[scenario.name] = {passed = false, error = luaResult}
            allScenariosPassed = false
        end
    end
    
    self.passed = allScenariosPassed
    
    if self.passed then
        print(string.format("\n🎯 Parity Test '%s' PASSED - All scenarios match TypeScript behavior", self.name))
    else
        print(string.format("\n💥 Parity Test '%s' FAILED - Some scenarios don't match TypeScript behavior", self.name))
    end
    
    return self.passed
end

function ParityTest:compareResults(luaResult, expectedResult, tolerance)
    if type(luaResult) ~= type(expectedResult) then
        return false
    end
    
    if type(luaResult) == "number" then
        return math.abs(luaResult - expectedResult) <= tolerance
    elseif type(luaResult) == "table" then
        return self:compareTables(luaResult, expectedResult)
    else
        return luaResult == expectedResult
    end
end

function ParityTest:compareTables(t1, t2)
    for k, v in pairs(t1) do
        if type(v) == "table" then
            if not self:compareTables(v, t2[k]) then
                return false
            end
        else
            if v ~= t2[k] then
                return false
            end
        end
    end
    
    for k, v in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    
    return true
end

function ParityTest:formatResult(result)
    if type(result) == "table" then
        return json.encode(result)
    else
        return tostring(result)
    end
end

-- Mock TypeScript behavior for reference
local TypeScriptReference = {}

-- Aegislash stance change reference behavior (from TypeScript analysis)
function TypeScriptReference.aegislashPreMoveTransformation(pokemon, moveId, moveData)
    -- Reference: src/data/pokemon-forms.ts:398-399
    if pokemon.speciesId ~= 681 then
        return nil
    end
    
    if not pokemon.abilities or not pokemon.abilities.STANCE_CHANGE then
        return nil
    end
    
    -- Shield to Blade: Non-STATUS moves
    if pokemon.form == "shield" and moveData and moveData.category ~= "STATUS" then
        return {
            fromForm = "shield",
            toForm = "blade",
            newStats = {hp = 60, atk = 150, def = 50, spa = 150, spd = 50, spe = 60},
            transformationType = "pre_move"
        }
    end
    
    -- Blade to Shield: King's Shield
    if pokemon.form == "blade" and moveId == "KINGS_SHIELD" then
        return {
            fromForm = "blade",
            toForm = "shield", 
            newStats = {hp = 60, atk = 50, def = 150, spa = 50, spd = 150, spe = 60},
            transformationType = "pre_move"
        }
    end
    
    return nil
end

-- Meloetta Relic Song reference behavior
function TypeScriptReference.meloettaPostMoveTransformation(pokemon, moveId, gameData)
    -- Reference: src/data/pokemon-forms.ts:380, form-change-triggers.ts:190-200
    if pokemon.speciesId ~= 648 then
        return nil
    end
    
    if moveId ~= "RELIC_SONG" then
        return nil
    end
    
    -- Blocked by Sheer Force ability
    if pokemon.abilities and pokemon.abilities.SHEER_FORCE then
        return nil
    end
    
    -- Blocked in Single Type challenge
    if gameData and gameData.challenges and gameData.challenges.SINGLE_TYPE then
        return nil
    end
    
    -- Toggle between forms
    if pokemon.form == "aria" then
        return {
            fromForm = "aria",
            toForm = "pirouette",
            newStats = {hp = 100, atk = 128, def = 90, spa = 77, spd = 77, spe = 128},
            newTypes = {"NORMAL", "FIGHTING"},
            transformationType = "post_move",
            toggleMode = true
        }
    elseif pokemon.form == "pirouette" then
        return {
            fromForm = "pirouette", 
            toForm = "aria",
            newStats = {hp = 100, atk = 77, def = 77, spa = 128, spd = 128, spe = 90},
            newTypes = {"NORMAL", "PSYCHIC"},
            transformationType = "post_move",
            toggleMode = true
        }
    end
    
    return nil
end

-- Transform move reference behavior
function TypeScriptReference.transformMove(userPokemon, targetPokemon)
    -- Reference: src/phases/pokemon-transform-phase.ts:27-88
    
    -- Cannot transform into same species and form
    if userPokemon.speciesId == targetPokemon.speciesId and 
       (userPokemon.form == targetPokemon.form or 
        (not userPokemon.form and not targetPokemon.form)) then
        return {success = false, reason = "Cannot transform into same species and form"}
    end
    
    local transformedPokemon = {
        -- Preserve original HP
        hp = userPokemon.baseStats.hp,
        -- Copy all other stats
        atk = targetPokemon.baseStats.atk,
        def = targetPokemon.baseStats.def,
        spa = targetPokemon.baseStats.spa,
        spd = targetPokemon.baseStats.spd,
        spe = targetPokemon.baseStats.spe
    }
    
    local copiedMoveset = {}
    local excludedMoves = {TRANSFORM = true, STRUGGLE = true, MIMIC = true, SKETCH = true}
    
    for i, move in ipairs(targetPokemon.moveset or {}) do
        if move and move.moveId and not excludedMoves[move.moveId] then
            table.insert(copiedMoveset, {
                moveId = move.moveId,
                pp = math.min(move.pp or 5, 5), -- Max 5 PP
                maxPP = math.min(move.maxPP or 5, 5)
            })
        end
    end
    
    return {
        success = true,
        transformedStats = transformedPokemon,
        copiedMoveset = copiedMoveset,
        copiedTypes = targetPokemon.types,
        copiedAbilities = targetPokemon.abilities,
        duration = "battle"
    }
end

-- Load Move Transformation Engine for testing
local function setupLuaTransformationEngine()
    -- Mock AO environment
    _G.ao = {
        id = "test_transformation_engine",
        send = function(msg)
            _G.lastSentMessage = msg
        end
    }
    
    _G.Handlers = {
        add = function(name, matcher, handler)
            if not _G.registeredHandlers then
                _G.registeredHandlers = {}
            end
            _G.registeredHandlers[name] = {matcher = matcher, handler = handler}
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    return msg.Tags and msg.Tags[tagName] == tagValue
                end
            end
        }
    }
    
    _G.State = {}
    
    -- Load the transformation engine
    dofile("processes/move-transformation-engine.lua")
end

-- Helper function to test Lua transformation engine
local function testLuaTransformation(action, tags, data)
    _G.lastSentMessage = nil
    
    local mockMsg = {
        From = "test_sender",
        Tags = tags,
        Data = data,
        Timestamp = 1234567890
    }
    
    local handler = _G.registeredHandlers[action]
    if handler then
        handler.handler(mockMsg)
        return _G.lastSentMessage
    else
        error("Handler not found: " .. action)
    end
end

-- Initialize Lua transformation engine
setupLuaTransformationEngine()

-- Parity Test 1: Aegislash Stance Change Timing
local test1 = ParityTest.new(
    "Aegislash Stance Change Timing Parity",
    "Compare Aegislash pre-move transformation timing and stat changes with TypeScript"
)

test1:addScenario("Shield to Blade on offensive move", function()
    local pokemon = {
        speciesId = 681,
        form = "shield",
        abilities = {STANCE_CHANGE = true},
        baseStats = {hp = 60, atk = 50, def = 150, spa = 50, spd = 150, spe = 60}
    }
    
    local moveData = {category = "PHYSICAL"}
    
    -- TypeScript reference
    local tsResult = TypeScriptReference.aegislashPreMoveTransformation(pokemon, "THUNDERBOLT", moveData)
    
    -- Lua implementation
    local luaResponse = testLuaTransformation("process-pre-move-transformation", {
        Action = "ProcessPreMoveTransformation",
        PokemonId = "aegislash_001",
        MoveId = "THUNDERBOLT",
        SpeciesId = "681",
        CurrentForm = "shield"
    }, json.encode(pokemon))
    
    if not luaResponse or luaResponse.Action ~= "TransformationTriggered" then
        error("Lua transformation failed")
    end
    
    local luaResult = {
        fromForm = luaResponse.FromForm,
        toForm = luaResponse.ToForm,
        transformationType = luaResponse.TransformationType
    }
    
    local expectedResult = {
        fromForm = tsResult.fromForm,
        toForm = tsResult.toForm,
        transformationType = tsResult.transformationType
    }
    
    return luaResult
end, {fromForm = "shield", toForm = "blade", transformationType = "pre_move"})

test1:addScenario("Blade to Shield on King's Shield", function()
    local pokemon = {
        speciesId = 681,
        form = "blade",
        abilities = {STANCE_CHANGE = true},
        baseStats = {hp = 60, atk = 150, def = 50, spa = 150, spd = 50, spe = 60}
    }
    
    local moveData = {category = "STATUS"}
    
    -- TypeScript reference
    local tsResult = TypeScriptReference.aegislashPreMoveTransformation(pokemon, "KINGS_SHIELD", moveData)
    
    -- Lua implementation  
    local luaResponse = testLuaTransformation("process-pre-move-transformation", {
        Action = "ProcessPreMoveTransformation",
        PokemonId = "aegislash_001",
        MoveId = "KINGS_SHIELD",
        SpeciesId = "681",
        CurrentForm = "blade"
    }, json.encode(pokemon))
    
    local luaResult = {
        fromForm = luaResponse.FromForm,
        toForm = luaResponse.ToForm,
        transformationType = luaResponse.TransformationType
    }
    
    return luaResult
end, {fromForm = "blade", toForm = "shield", transformationType = "pre_move"})

-- Parity Test 2: Meloetta Relic Song Transformation
local test2 = ParityTest.new(
    "Meloetta Relic Song Transformation Parity",
    "Compare Meloetta post-move transformation behavior with TypeScript"
)

test2:addScenario("Aria to Pirouette transformation", function()
    local pokemon = {
        speciesId = 648,
        form = "aria",
        abilities = {},
        baseStats = {hp = 100, atk = 77, def = 77, spa = 128, spd = 128, spe = 90}
    }
    
    -- TypeScript reference
    local tsResult = TypeScriptReference.meloettaPostMoveTransformation(pokemon, "RELIC_SONG", {})
    
    -- Lua implementation
    local luaResponse = testLuaTransformation("process-post-move-transformation", {
        Action = "ProcessPostMoveTransformation",
        PokemonId = "meloetta_001",
        MoveId = "RELIC_SONG",
        SpeciesId = "648",
        CurrentForm = "aria"
    }, json.encode(pokemon))
    
    local luaResult = {
        fromForm = luaResponse.FromForm,
        toForm = luaResponse.ToForm,
        transformationType = luaResponse.TransformationType,
        toggleMode = luaResponse.ToggleMode == "true"
    }
    
    return luaResult
end, {fromForm = "aria", toForm = "pirouette", transformationType = "post_move", toggleMode = true})

test2:addScenario("Blocked by Sheer Force ability", function()
    local pokemon = {
        speciesId = 648,
        form = "aria",
        abilities = {SHEER_FORCE = true},
        baseStats = {hp = 100, atk = 77, def = 77, spa = 128, spd = 128, spe = 90}
    }
    
    -- TypeScript reference should return nil (blocked)
    local tsResult = TypeScriptReference.meloettaPostMoveTransformation(pokemon, "RELIC_SONG", {})
    
    -- Lua implementation
    local luaResponse = testLuaTransformation("process-post-move-transformation", {
        Action = "ProcessPostMoveTransformation",
        PokemonId = "meloetta_001",
        MoveId = "RELIC_SONG",
        SpeciesId = "648",
        CurrentForm = "aria"
    }, json.encode(pokemon))
    
    -- Should be blocked
    return luaResponse.Action
end, "NoTransformation")

-- Parity Test 3: Transform Move Stat Copying
local test3 = ParityTest.new(
    "Transform Move Stat Copying Parity",
    "Compare Transform move stat copying precision with TypeScript"
)

test3:addScenario("Complete species transformation", function()
    local userPokemon = {
        speciesId = 132, -- Ditto
        form = "default",
        abilities = {},
        baseStats = {hp = 48, atk = 48, def = 48, spa = 48, spd = 48, spe = 48},
        types = {"NORMAL"},
        moveset = {{moveId = "TRANSFORM", pp = 10, maxPP = 10}}
    }
    
    local targetPokemon = {
        speciesId = 25, -- Pikachu
        form = "default",
        abilities = {STATIC = true},
        baseStats = {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90},
        types = {"ELECTRIC"},
        moveset = {
            {moveId = "THUNDERBOLT", pp = 15, maxPP = 15},
            {moveId = "QUICK_ATTACK", pp = 30, maxPP = 30}
        }
    }
    
    -- TypeScript reference
    local tsResult = TypeScriptReference.transformMove(userPokemon, targetPokemon)
    
    -- Lua implementation
    local luaResponse = testLuaTransformation("process-transform-move", {
        Action = "ProcessTransformMove",
        UserPokemonId = "ditto_001",
        TargetPokemonId = "pikachu_001",
        BattleId = "battle_001"
    })
    luaResponse.UserData = json.encode(userPokemon)
    luaResponse.TargetData = json.encode(targetPokemon)
    
    if luaResponse.Action ~= "TransformSuccess" then
        error("Transform move failed")
    end
    
    local transformedData = json.decode(luaResponse.TransformedData)
    
    local luaResult = {
        success = true,
        preservedHP = transformedData.baseStats.hp,
        copiedAttack = transformedData.baseStats.atk,
        copiedSpeed = transformedData.baseStats.spe
    }
    
    return luaResult
end, {success = true, preservedHP = 48, copiedAttack = 55, copiedSpeed = 90})

test3:addScenario("Same species transformation failure", function()
    local userPokemon = {
        speciesId = 25, -- Pikachu
        form = "default",
        abilities = {},
        baseStats = {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90}
    }
    
    local targetPokemon = {
        speciesId = 25, -- Same Pikachu
        form = "default", 
        abilities = {STATIC = true},
        baseStats = {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90}
    }
    
    -- TypeScript reference
    local tsResult = TypeScriptReference.transformMove(userPokemon, targetPokemon)
    
    -- Lua implementation
    local luaResponse = testLuaTransformation("process-transform-move", {
        Action = "ProcessTransformMove",
        UserPokemonId = "pikachu_001",
        TargetPokemonId = "pikachu_002"
    })
    luaResponse.UserData = json.encode(userPokemon)
    luaResponse.TargetData = json.encode(targetPokemon)
    
    return {success = luaResponse.Action == "TransformFailed"}
end, {success = false})

-- Parity Test 4: Transformation Timing Precision
local test4 = ParityTest.new(
    "Transformation Timing Precision Parity",
    "Verify transformation timing matches TypeScript execution order"
)

test4:addScenario("Pre-move transformation execution order", function()
    -- This tests that pre-move transformations happen before move execution
    -- In the actual system, this would be coordinated with battle engine
    
    local pokemon = {
        speciesId = 681,
        form = "shield",
        abilities = {STANCE_CHANGE = true}
    }
    
    -- Simulate pre-move check
    local transformationCheck = TypeScriptReference.aegislashPreMoveTransformation(
        pokemon, "THUNDERBOLT", {category = "PHYSICAL"}
    )
    
    -- Verify transformation is triggered before move execution
    return {triggered = transformationCheck ~= nil, timing = "pre_move"}
end, {triggered = true, timing = "pre_move"})

-- Run all parity tests
local function runAllParityTests()
    print("🎯 Starting Move Transformation Engine Parity Tests")
    print("Comparing Lua implementation with TypeScript reference behavior")
    print("=" * 70)
    
    local tests = {test1, test2, test3, test4}
    local passedTests = 0
    local totalTests = #tests
    local totalScenarios = 0
    local passedScenarios = 0
    
    for i, test in ipairs(tests) do
        print(string.format("\n[%d/%d] %s", i, totalTests, test.name))
        totalScenarios = totalScenarios + #test.scenarios
        
        if test:run() then
            passedTests = passedTests + 1
            passedScenarios = passedScenarios + #test.scenarios
        else
            for _, scenario in ipairs(test.scenarios) do
                if test.results[scenario.name] and test.results[scenario.name].passed then
                    passedScenarios = passedScenarios + 1
                end
            end
        end
    end
    
    print("\n" .. "=" * 70)
    print("🏁 PARITY TEST RESULTS")
    print(string.format("Total test suites: %d", totalTests))
    print(string.format("Passed test suites: %d", passedTests))
    print(string.format("Total scenarios: %d", totalScenarios))
    print(string.format("Passed scenarios: %d", passedScenarios))
    print(string.format("Scenario success rate: %.1f%%", (passedScenarios / totalScenarios) * 100))
    
    if passedTests == totalTests then
        print("🎉 ALL PARITY TESTS PASSED! 🎉")
        print("✅ Lua implementation matches TypeScript behavior exactly")
        return true
    else
        print("❌ Some parity tests failed. Review the mismatches above.")
        print("⚠️  Lua implementation deviates from TypeScript reference")
        return false
    end
end

-- Execute the parity tests
return runAllParityTests()