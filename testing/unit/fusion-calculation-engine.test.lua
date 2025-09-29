-- Unit Tests for Fusion Calculation Engine
-- Tests all fusion calculation functionality for mathematical precision

local json = require("json")

-- Test framework setup
local TestFramework = {}
TestFramework.tests = {}
TestFramework.results = {passed = 0, failed = 0, total = 0}

function TestFramework.addTest(name, testFunction)
    table.insert(TestFramework.tests, {name = name, func = testFunction})
end

function TestFramework.runTests()
    print("=== Fusion Calculation Engine Unit Tests ===")
    
    for _, test in ipairs(TestFramework.tests) do
        TestFramework.results.total = TestFramework.results.total + 1
        local success, error = pcall(test.func)
        
        if success then
            TestFramework.results.passed = TestFramework.results.passed + 1
            print("✅ PASS: " .. test.name)
        else
            TestFramework.results.failed = TestFramework.results.failed + 1
            print("❌ FAIL: " .. test.name .. " - " .. tostring(error))
        end
    end
    
    print("\n=== Test Results ===")
    print("Total: " .. TestFramework.results.total)
    print("Passed: " .. TestFramework.results.passed) 
    print("Failed: " .. TestFramework.results.failed)
    print("Success Rate: " .. math.floor((TestFramework.results.passed / TestFramework.results.total) * 100) .. "%")
    
    return TestFramework.results.failed == 0
end

function TestFramework.assertEqual(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. " - Expected: " .. tostring(expected) .. ", Actual: " .. tostring(actual))
    end
end

function TestFramework.assertTrue(condition, message)
    if not condition then
        error(message or "Expected true but got false")
    end
end

function TestFramework.assertNotNil(value, message)
    if value == nil then
        error(message or "Expected non-nil value but got nil")
    end
end

-- Mock AO environment for testing
if not ao then
    ao = {
        send = function(msg) 
            print("Mock ao.send:", json.encode(msg))
        end,
        id = "test_fusion_process_id"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Mock Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- Load the fusion calculation engine
local processCode = io.open("/Users/jonathangreen/Documents/pokerogue/processes/fusion-calculation-engine.lua", "r"):read("*all")
-- Execute in current environment to access functions
load(processCode)()

-- Test Data: Pokemon stat examples (matching TypeScript test cases)
local pikachuStats = {
    HP = 35,
    ATK = 55, 
    DEF = 40,
    SPATK = 50,
    SPDEF = 50,
    SPD = 90
}

local raichuStats = {
    HP = 60,
    ATK = 90,
    DEF = 55, 
    SPATK = 90,
    SPDEF = 80,
    SPD = 110
}

local charizardStats = {
    HP = 78,
    ATK = 84,
    DEF = 78,
    SPATK = 109,
    SPDEF = 85,
    SPD = 100
}

-- Unit Test: Fusion Stat Calculation Mathematical Precision
TestFramework.addTest("Fusion Stat Calculation - Pikachu + Raichu", function()
    local fusionStats, error = calculateFusionStats(pikachuStats, raichuStats)
    
    TestFramework.assertNotNil(fusionStats, "Fusion stats should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    
    -- Expected results using Math.ceil((base + fusion) / 2)
    TestFramework.assertEqual(48, fusionStats.HP, "HP: ceil((35 + 60) / 2) = 48")      -- ceil(47.5) = 48
    TestFramework.assertEqual(73, fusionStats.ATK, "ATK: ceil((55 + 90) / 2) = 73")    -- ceil(72.5) = 73  
    TestFramework.assertEqual(48, fusionStats.DEF, "DEF: ceil((40 + 55) / 2) = 48")    -- ceil(47.5) = 48
    TestFramework.assertEqual(70, fusionStats.SPATK, "SPATK: ceil((50 + 90) / 2) = 70") -- ceil(70) = 70
    TestFramework.assertEqual(65, fusionStats.SPDEF, "SPDEF: ceil((50 + 80) / 2) = 65") -- ceil(65) = 65
    TestFramework.assertEqual(100, fusionStats.SPD, "SPD: ceil((90 + 110) / 2) = 100")  -- ceil(100) = 100
end)

-- Unit Test: Fusion Stat Calculation with Fractional Results
TestFramework.addTest("Fusion Stat Calculation - Edge Case Fractionals", function()
    local oddStats = {HP = 33, ATK = 71, DEF = 45, SPATK = 67, SPDEF = 59, SPD = 83}
    local evenStats = {HP = 66, ATK = 72, DEF = 54, SPATK = 68, SPDEF = 60, SPD = 84}
    
    local fusionStats, error = calculateFusionStats(oddStats, evenStats)
    
    TestFramework.assertNotNil(fusionStats, "Fusion stats should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    
    -- Test Math.ceil behavior on exact halves and fractional values
    TestFramework.assertEqual(50, fusionStats.HP, "HP: ceil((33 + 66) / 2) = ceil(49.5) = 50")
    TestFramework.assertEqual(72, fusionStats.ATK, "ATK: ceil((71 + 72) / 2) = ceil(71.5) = 72")
    TestFramework.assertEqual(50, fusionStats.DEF, "DEF: ceil((45 + 54) / 2) = ceil(49.5) = 50")
    TestFramework.assertEqual(68, fusionStats.SPATK, "SPATK: ceil((67 + 68) / 2) = ceil(67.5) = 68")
    TestFramework.assertEqual(60, fusionStats.SPDEF, "SPDEF: ceil((59 + 60) / 2) = ceil(59.5) = 60")
    TestFramework.assertEqual(84, fusionStats.SPD, "SPD: ceil((83 + 84) / 2) = ceil(83.5) = 84")
end)

-- Unit Test: Fusion Type Determination Priority Rules
TestFramework.addTest("Fusion Type Determination - Priority Logic", function()
    -- Test case: base Electric, fusion Electric/Flying -> should be Electric/Flying
    local baseTypes = {"ELECTRIC"}
    local fusionTypes = {"ELECTRIC", "FLYING"}
    
    local fusionTypes, error = determineFusionTypes(baseTypes, fusionTypes)
    
    TestFramework.assertNotNil(fusionTypes, "Fusion types should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    TestFramework.assertEqual(2, #fusionTypes, "Should have exactly 2 types")
    TestFramework.assertEqual("ELECTRIC", fusionTypes[1], "Primary type should be ELECTRIC from base")
    TestFramework.assertEqual("FLYING", fusionTypes[2], "Secondary type should be FLYING from fusion")
end)

-- Unit Test: Fusion Type Determination - Same Type Priority
TestFramework.addTest("Fusion Type Determination - Same Primary Types", function()
    -- Test case: base Fire/Flying, fusion Fire/Water -> should be Fire/Water  
    local baseTypes = {"FIRE", "FLYING"}
    local fusionTypes = {"FIRE", "WATER"}
    
    local fusionTypes, error = determineFusionTypes(baseTypes, fusionTypes)
    
    TestFramework.assertNotNil(fusionTypes, "Fusion types should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    TestFramework.assertEqual(2, #fusionTypes, "Should have exactly 2 types")
    TestFramework.assertEqual("FIRE", fusionTypes[1], "Primary type should be FIRE from base")
    TestFramework.assertEqual("WATER", fusionTypes[2], "Secondary type should be WATER from fusion (priority over FLYING)")
end)

-- Unit Test: Fusion Type Determination - Monotype Handling
TestFramework.addTest("Fusion Type Determination - Monotype Cases", function()
    -- Test case: base Electric (monotype), fusion Electric (monotype) -> should be Electric only
    local baseTypes = {"ELECTRIC"}
    local fusionTypes = {"ELECTRIC"}
    
    local fusionTypes, error = determineFusionTypes(baseTypes, fusionTypes)
    
    TestFramework.assertNotNil(fusionTypes, "Fusion types should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    TestFramework.assertEqual(1, #fusionTypes, "Should have exactly 1 type")
    TestFramework.assertEqual("ELECTRIC", fusionTypes[1], "Primary type should be ELECTRIC")
end)

-- Unit Test: Fusion Ability Selection - Hidden Ability
TestFramework.addTest("Fusion Ability Selection - Hidden Ability Probability", function()
    local baseAbilities = {"STATIC", "LIGHTNING_ROD"}
    local fusionAbilities = {"STATIC", "LIGHTNING_ROD", "LIGHTNING_ROD"}  -- Hidden ability in position 3
    
    -- Use seed that should trigger hidden ability (deterministic test)
    local battleSeed = 100  -- This should result in hidden ability selection
    local rngCounter = 0
    
    local abilityResult, error = selectFusionAbility(baseAbilities, fusionAbilities, battleSeed, rngCounter)
    
    TestFramework.assertNotNil(abilityResult, "Ability result should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    TestFramework.assertTrue(abilityResult.selectedAbility ~= nil, "Should have selected ability")
    TestFramework.assertTrue(abilityResult.abilityIndex ~= nil, "Should have ability index")
    TestFramework.assertTrue(abilityResult.selectionMethod ~= nil, "Should have selection method")
end)

-- Unit Test: Fusion Ability Selection - Random Selection
TestFramework.addTest("Fusion Ability Selection - Random When Abilities Differ", function()
    local baseAbilities = {"OVERGROW", "CHLOROPHYLL"}
    local fusionAbilities = {"BLAZE", "SOLAR_POWER"}
    
    -- Use seed that should NOT trigger hidden ability
    local battleSeed = 50000  -- High seed to avoid hidden ability trigger
    local rngCounter = 0
    
    local abilityResult, error = selectFusionAbility(baseAbilities, fusionAbilities, battleSeed, rngCounter)
    
    TestFramework.assertNotNil(abilityResult, "Ability result should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    TestFramework.assertTrue(abilityResult.selectedAbility ~= nil, "Should have selected ability")
    TestFramework.assertTrue(abilityResult.selectionMethod == "random" or abilityResult.selectionMethod == "default", "Should use random or default selection")
    TestFramework.assertEqual("boolean", type(abilityResult.probabilityUsed), "Should indicate if probability was used")
end)

-- Unit Test: Fusion Creation Validation - Valid Request
TestFramework.addTest("Fusion Creation Validation - Valid Request", function()
    local validRequest = {
        baseSpecies = {
            id = "PIKACHU",
            baseStats = pikachuStats,
            types = {"ELECTRIC"},
            abilities = {"STATIC", "LIGHTNING_ROD"}
        },
        fusionSpecies = {
            id = "RAICHU", 
            baseStats = raichuStats,
            types = {"ELECTRIC"},
            abilities = {"STATIC", "LIGHTNING_ROD"}
        }
    }
    
    local isValid, error = validateFusionCreation(validRequest)
    
    TestFramework.assertTrue(isValid, "Valid request should pass validation")
    TestFramework.assertEqual(nil, error, "Valid request should not have error")
end)

-- Unit Test: Fusion Creation Validation - Invalid Request
TestFramework.addTest("Fusion Creation Validation - Missing Data", function()
    local invalidRequest = {
        baseSpecies = {
            id = "PIKACHU"
            -- Missing baseStats
        }
    }
    
    local isValid, error = validateFusionCreation(invalidRequest)
    
    TestFramework.assertTrue(not isValid, "Invalid request should fail validation")
    TestFramework.assertNotNil(error, "Invalid request should have error message")
end)

-- Unit Test: Mathematical Precision Tracking
TestFramework.addTest("Mathematical Precision Tracking", function()
    -- Test precision tracking for known fractional results
    local baseStats = {HP = 35, ATK = 55, DEF = 41, SPATK = 51, SPDEF = 51, SPD = 91}
    local fusionStats = {HP = 60, ATK = 90, DEF = 54, SPATK = 89, SPDEF = 79, SPD = 109}
    
    local fusionResult, error = calculateFusionStats(baseStats, fusionStats)
    
    TestFramework.assertNotNil(fusionResult, "Fusion result should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    
    -- Verify exact mathematical precision
    TestFramework.assertEqual(48, fusionResult.HP, "HP precision: ceil((35 + 60) / 2) = ceil(47.5) = 48")
    TestFramework.assertEqual(73, fusionResult.ATK, "ATK precision: ceil((55 + 90) / 2) = ceil(72.5) = 73")
    TestFramework.assertEqual(48, fusionResult.DEF, "DEF precision: ceil((41 + 54) / 2) = ceil(47.5) = 48")
    TestFramework.assertEqual(70, fusionResult.SPATK, "SPATK precision: ceil((51 + 89) / 2) = ceil(70) = 70")
    TestFramework.assertEqual(65, fusionResult.SPDEF, "SPDEF precision: ceil((51 + 79) / 2) = ceil(65) = 65")
    TestFramework.assertEqual(100, fusionResult.SPD, "SPD precision: ceil((91 + 109) / 2) = ceil(100) = 100")
end)

-- Unit Test: Error Handling
TestFramework.addTest("Error Handling - Missing Parameters", function()
    local fusionStats, error = calculateFusionStats(nil, raichuStats)
    
    TestFramework.assertEqual(nil, fusionStats, "Should return nil for missing base stats")
    TestFramework.assertNotNil(error, "Should return error message")
    
    local fusionStats2, error2 = calculateFusionStats(pikachuStats, nil)
    
    TestFramework.assertEqual(nil, fusionStats2, "Should return nil for missing fusion stats")
    TestFramework.assertNotNil(error2, "Should return error message")
end)

-- Unit Test: Deterministic RNG Consistency
TestFramework.addTest("Deterministic RNG Consistency", function()
    local baseAbilities = {"ABILITY_1", "ABILITY_2"}
    local fusionAbilities = {"ABILITY_3", "ABILITY_4", "HIDDEN_ABILITY"}
    
    -- Same seed should produce same results
    local seed = 12345
    local counter = 0
    
    local result1, _ = selectFusionAbility(baseAbilities, fusionAbilities, seed, counter)
    local result2, _ = selectFusionAbility(baseAbilities, fusionAbilities, seed, counter)
    
    TestFramework.assertEqual(result1.selectedAbility, result2.selectedAbility, "Same seed should produce same ability")
    TestFramework.assertEqual(result1.abilityIndex, result2.abilityIndex, "Same seed should produce same index")
    TestFramework.assertEqual(result1.selectionMethod, result2.selectionMethod, "Same seed should produce same method")
end)

-- Run all tests
if TestFramework.runTests() then
    print("\n🎉 All fusion calculation engine unit tests passed!")
    return true
else
    print("\n💥 Some fusion calculation engine unit tests failed!")
    return false
end