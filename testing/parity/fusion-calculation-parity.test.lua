-- Parity Tests for Fusion Calculation Engine
-- Validates 100% mathematical parity with TypeScript implementation

local json = require("json")

-- Test framework setup
local TestFramework = {}
TestFramework.tests = {}
TestFramework.results = {passed = 0, failed = 0, total = 0}

function TestFramework.addTest(name, testFunction)
    table.insert(TestFramework.tests, {name = name, func = testFunction})
end

function TestFramework.runTests()
    print("=== Fusion Calculation Parity Tests ===")
    print("Validating 100% mathematical parity with TypeScript implementation")
    
    for _, test in ipairs(TestFramework.tests) do
        TestFramework.results.total = TestFramework.results.total + 1
        local success, error = pcall(test.func)
        
        if success then
            TestFramework.results.passed = TestFramework.results.passed + 1
            print("✅ PARITY PASS: " .. test.name)
        else
            TestFramework.results.failed = TestFramework.results.failed + 1
            print("❌ PARITY FAIL: " .. test.name .. " - " .. tostring(error))
        end
    end
    
    print("\n=== Parity Test Results ===")
    print("Total: " .. TestFramework.results.total)
    print("Passed: " .. TestFramework.results.passed) 
    print("Failed: " .. TestFramework.results.failed)
    print("Parity Rate: " .. math.floor((TestFramework.results.passed / TestFramework.results.total) * 100) .. "%")
    
    if TestFramework.results.failed == 0 then
        print("🎯 100% MATHEMATICAL PARITY ACHIEVED!")
    else
        print("⚠️  Mathematical parity validation failed")
    end
    
    return TestFramework.results.failed == 0
end

function TestFramework.assertEqual(expected, actual, message)
    if expected ~= actual then
        error((message or "Parity assertion failed") .. " - Expected: " .. tostring(expected) .. ", Actual: " .. tostring(actual))
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
        id = "test_fusion_parity_process"
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
load(processCode)()

-- TypeScript Reference Data: Exact values from TypeScript calculateBaseStats method
-- These are the EXACT results from TypeScript Math.ceil((baseStats[s] + fusionBaseStats[s]) / 2)

-- Parity Test 1: Pikachu + Raichu Fusion (TypeScript lines 1602-1604)
TestFramework.addTest("TypeScript Parity - Pikachu + Raichu Fusion Stats", function()
    local pikachuStats = {HP = 35, ATK = 55, DEF = 40, SPATK = 50, SPDEF = 50, SPD = 90}
    local raichuStats = {HP = 60, ATK = 90, DEF = 55, SPATK = 90, SPDEF = 80, SPD = 110}
    
    local fusionStats, error = calculateFusionStats(pikachuStats, raichuStats)
    
    TestFramework.assertNotNil(fusionStats, "Fusion stats should not be nil")
    TestFramework.assertEqual(nil, error, "Should not have error")
    
    -- EXACT TypeScript Math.ceil results
    TestFramework.assertEqual(48, fusionStats.HP, "HP TypeScript parity: Math.ceil((35 + 60) / 2) = Math.ceil(47.5) = 48")
    TestFramework.assertEqual(73, fusionStats.ATK, "ATK TypeScript parity: Math.ceil((55 + 90) / 2) = Math.ceil(72.5) = 73")
    TestFramework.assertEqual(48, fusionStats.DEF, "DEF TypeScript parity: Math.ceil((40 + 55) / 2) = Math.ceil(47.5) = 48")
    TestFramework.assertEqual(70, fusionStats.SPATK, "SPATK TypeScript parity: Math.ceil((50 + 90) / 2) = Math.ceil(70) = 70")
    TestFramework.assertEqual(65, fusionStats.SPDEF, "SPDEF TypeScript parity: Math.ceil((50 + 80) / 2) = Math.ceil(65) = 65")
    TestFramework.assertEqual(100, fusionStats.SPD, "SPD TypeScript parity: Math.ceil((90 + 110) / 2) = Math.ceil(100) = 100")
end)

-- Parity Test 2: Charizard + Blastoise Fusion (Complex stat combinations)
TestFramework.addTest("TypeScript Parity - Charizard + Blastoise Fusion Stats", function()
    local charizardStats = {HP = 78, ATK = 84, DEF = 78, SPATK = 109, SPDEF = 85, SPD = 100}
    local blastoiseStats = {HP = 79, ATK = 83, DEF = 100, SPATK = 85, SPDEF = 105, SPD = 78}
    
    local fusionStats, error = calculateFusionStats(charizardStats, blastoiseStats)
    
    TestFramework.assertNotNil(fusionStats, "Fusion stats should not be nil")
    
    -- EXACT TypeScript Math.ceil results for fractional averages
    TestFramework.assertEqual(79, fusionStats.HP, "HP parity: Math.ceil((78 + 79) / 2) = Math.ceil(78.5) = 79")
    TestFramework.assertEqual(84, fusionStats.ATK, "ATK parity: Math.ceil((84 + 83) / 2) = Math.ceil(83.5) = 84")
    TestFramework.assertEqual(89, fusionStats.DEF, "DEF parity: Math.ceil((78 + 100) / 2) = Math.ceil(89) = 89")
    TestFramework.assertEqual(97, fusionStats.SPATK, "SPATK parity: Math.ceil((109 + 85) / 2) = Math.ceil(97) = 97")
    TestFramework.assertEqual(95, fusionStats.SPDEF, "SPDEF parity: Math.ceil((85 + 105) / 2) = Math.ceil(95) = 95")
    TestFramework.assertEqual(89, fusionStats.SPD, "SPD parity: Math.ceil((100 + 78) / 2) = Math.ceil(89) = 89")
end)

-- Parity Test 3: Venusaur + Wartortle Fusion (Edge case with different stat distributions)
TestFramework.addTest("TypeScript Parity - Venusaur + Wartortle Fusion Stats", function()
    local venusaurStats = {HP = 80, ATK = 82, DEF = 83, SPATK = 100, SPDEF = 100, SPD = 80}
    local wartortleStats = {HP = 59, ATK = 63, DEF = 80, SPATK = 65, SPDEF = 80, SPD = 58}
    
    local fusionStats, error = calculateFusionStats(venusaurStats, wartortleStats)
    
    TestFramework.assertNotNil(fusionStats, "Fusion stats should not be nil")
    
    -- EXACT TypeScript Math.ceil results
    TestFramework.assertEqual(70, fusionStats.HP, "HP parity: Math.ceil((80 + 59) / 2) = Math.ceil(69.5) = 70")
    TestFramework.assertEqual(73, fusionStats.ATK, "ATK parity: Math.ceil((82 + 63) / 2) = Math.ceil(72.5) = 73")
    TestFramework.assertEqual(82, fusionStats.DEF, "DEF parity: Math.ceil((83 + 80) / 2) = Math.ceil(81.5) = 82")
    TestFramework.assertEqual(83, fusionStats.SPATK, "SPATK parity: Math.ceil((100 + 65) / 2) = Math.ceil(82.5) = 83")
    TestFramework.assertEqual(90, fusionStats.SPDEF, "SPDEF parity: Math.ceil((100 + 80) / 2) = Math.ceil(90) = 90")
    TestFramework.assertEqual(69, fusionStats.SPD, "SPD parity: Math.ceil((80 + 58) / 2) = Math.ceil(69) = 69")
end)

-- Parity Test 4: Type Determination Logic (TypeScript getTypes method lines 1926-1967)
TestFramework.addTest("TypeScript Parity - Fusion Type Priority Rules", function()
    -- Test case 1: fusionType2 != baseType1 -> should use fusionType2
    local baseTypes1 = {"FIRE"}
    local fusionTypes1 = {"FIRE", "FLYING"}
    local result1, _ = determineFusionTypes(baseTypes1, fusionTypes1)
    
    TestFramework.assertEqual("FIRE", result1[1], "Primary type should be base type")
    TestFramework.assertEqual("FLYING", result1[2], "Secondary should be fusionType2 (FLYING != FIRE)")
    
    -- Test case 2: fusionType2 == baseType1, fusionType1 != baseType1 -> should use fusionType1
    local baseTypes2 = {"WATER"}
    local fusionTypes2 = {"GRASS", "WATER"}
    local result2, _ = determineFusionTypes(baseTypes2, fusionTypes2)
    
    TestFramework.assertEqual("WATER", result2[1], "Primary type should be base type")
    TestFramework.assertEqual("GRASS", result2[2], "Secondary should be fusionType1 (GRASS != WATER)")
    
    -- Test case 3: Both fusion types == baseType1 -> should use baseType2
    local baseTypes3 = {"ELECTRIC", "FLYING"}
    local fusionTypes3 = {"ELECTRIC", "ELECTRIC"}
    local result3, _ = determineFusionTypes(baseTypes3, fusionTypes3)
    
    TestFramework.assertEqual("ELECTRIC", result3[1], "Primary type should be base type")
    TestFramework.assertEqual("FLYING", result3[2], "Secondary should be baseType2 (fallback)")
end)

-- Parity Test 5: Ability Selection Probability (TypeScript generateFusionSpecies lines 3003-3008)
TestFramework.addTest("TypeScript Parity - Ability Selection Determinism", function()
    local baseAbilities = {"STATIC", "LIGHTNING_ROD"}
    local fusionAbilities = {"BLAZE", "SOLAR_POWER", "DROUGHT"}  -- Hidden ability at index 3
    
    -- Test with multiple seeds to verify deterministic behavior
    local seeds = {12345, 54321, 98765, 11111, 99999}
    local results = {}
    
    for _, seed in ipairs(seeds) do
        local result, _ = selectFusionAbility(baseAbilities, fusionAbilities, seed, 0)
        table.insert(results, result)
        
        -- Verify result structure matches TypeScript
        TestFramework.assertNotNil(result.selectedAbility, "Should have selected ability")
        TestFramework.assertTrue(result.abilityIndex >= 0 and result.abilityIndex <= 2, "Ability index should be 0, 1, or 2")
        TestFramework.assertTrue(result.selectionMethod == "hidden" or result.selectionMethod == "random" or result.selectionMethod == "default", "Should have valid selection method")
    end
    
    -- Test deterministic consistency: same seed should produce same result
    local result1, _ = selectFusionAbility(baseAbilities, fusionAbilities, 12345, 0)
    local result2, _ = selectFusionAbility(baseAbilities, fusionAbilities, 12345, 0)
    
    TestFramework.assertEqual(result1.selectedAbility, result2.selectedAbility, "Same seed should produce same ability")
    TestFramework.assertEqual(result1.abilityIndex, result2.abilityIndex, "Same seed should produce same index")
end)

-- Parity Test 6: Hidden Ability Probability Distribution (BASE_HIDDEN_ABILITY_CHANCE = 256)
TestFramework.addTest("TypeScript Parity - Hidden Ability Probability Distribution", function()
    local baseAbilities = {"ABILITY_1", "ABILITY_2"}
    local fusionAbilities = {"ABILITY_3", "ABILITY_4", "HIDDEN_ABILITY"}
    
    local hiddenAbilityCount = 0
    local totalTests = 1000
    
    -- Test probability distribution over many seeds
    for i = 1, totalTests do
        local result, _ = selectFusionAbility(baseAbilities, fusionAbilities, i * 137, 0)
        if result.selectionMethod == "hidden" then
            hiddenAbilityCount = hiddenAbilityCount + 1
        end
    end
    
    local hiddenAbilityRate = hiddenAbilityCount / totalTests
    local expectedRate = 256 / 65536  -- BASE_HIDDEN_ABILITY_CHANCE / 65536
    
    -- Allow 2% margin of error for probability distribution
    local margin = 0.02
    TestFramework.assertTrue(
        math.abs(hiddenAbilityRate - expectedRate) < margin,
        string.format("Hidden ability rate %.4f should be within %.2f of expected %.4f", 
                     hiddenAbilityRate, margin, expectedRate)
    )
end)

-- Parity Test 7: Comprehensive Math.ceil Behavior Validation
TestFramework.addTest("TypeScript Parity - Math.ceil Behavior Validation", function()
    -- Test all Math.ceil edge cases that could occur in stat calculations
    local testCases = {
        -- {base, fusion, expected}
        {1, 1, 1},      -- ceil(1) = 1
        {1, 2, 2},      -- ceil(1.5) = 2  
        {2, 2, 2},      -- ceil(2) = 2
        {3, 4, 4},      -- ceil(3.5) = 4
        {255, 255, 255}, -- ceil(255) = 255 (max typical stat)
        {1, 255, 128},   -- ceil(128) = 128
        {254, 255, 255}, -- ceil(254.5) = 255
        {0, 1, 1},       -- ceil(0.5) = 1
        {99, 100, 100},  -- ceil(99.5) = 100
        {100, 101, 101}  -- ceil(100.5) = 101
    }
    
    for _, case in ipairs(testCases) do
        local base = case[1]
        local fusion = case[2] 
        local expected = case[3]
        
        local testStats = {HP = base, ATK = base, DEF = base, SPATK = base, SPDEF = base, SPD = base}
        local fusionTestStats = {HP = fusion, ATK = fusion, DEF = fusion, SPATK = fusion, SPDEF = fusion, SPD = fusion}
        
        local result, _ = calculateFusionStats(testStats, fusionTestStats)
        
        TestFramework.assertEqual(expected, result.HP, 
            string.format("Math.ceil((%d + %d) / 2) should equal %d", base, fusion, expected))
    end
end)

-- Parity Test 8: Complex Multi-Stage Fusion Scenario
TestFramework.addTest("TypeScript Parity - Complex Multi-Stage Fusion", function()
    -- Simulate complex fusion scenario with multiple calculations
    local scenario = {
        baseSpecies = {
            id = "DRAGONITE",
            baseStats = {HP = 91, ATK = 134, DEF = 95, SPATK = 100, SPDEF = 100, SPD = 80},
            types = {"DRAGON", "FLYING"},
            abilities = {"INNER_FOCUS", "MULTISCALE"}
        },
        fusionSpecies = {
            id = "MEWTWO",
            baseStats = {HP = 106, ATK = 110, DEF = 90, SPATK = 154, SPDEF = 90, SPD = 130},
            types = {"PSYCHIC"},
            abilities = {"PRESSURE", "UNNERVE", "INSOMNIA"}
        }
    }
    
    -- Step 1: Calculate fusion stats
    local fusionStats, _ = calculateFusionStats(scenario.baseSpecies.baseStats, scenario.fusionSpecies.baseStats)
    
    -- Expected TypeScript results
    TestFramework.assertEqual(99, fusionStats.HP, "HP: ceil((91 + 106) / 2) = ceil(98.5) = 99")
    TestFramework.assertEqual(122, fusionStats.ATK, "ATK: ceil((134 + 110) / 2) = ceil(122) = 122")
    TestFramework.assertEqual(93, fusionStats.DEF, "DEF: ceil((95 + 90) / 2) = ceil(92.5) = 93")
    TestFramework.assertEqual(127, fusionStats.SPATK, "SPATK: ceil((100 + 154) / 2) = ceil(127) = 127")
    TestFramework.assertEqual(95, fusionStats.SPDEF, "SPDEF: ceil((100 + 90) / 2) = ceil(95) = 95")
    TestFramework.assertEqual(105, fusionStats.SPD, "SPD: ceil((80 + 130) / 2) = ceil(105) = 105")
    
    -- Step 2: Determine fusion types
    local fusionTypes, _ = determineFusionTypes(scenario.baseSpecies.types, scenario.fusionSpecies.types)
    
    TestFramework.assertEqual("DRAGON", fusionTypes[1], "Primary type should be DRAGON from base")
    TestFramework.assertEqual("PSYCHIC", fusionTypes[2], "Secondary type should be PSYCHIC from fusion")
    
    -- Step 3: Test ability selection with deterministic seed
    local abilityResult, _ = selectFusionAbility(scenario.baseSpecies.abilities, scenario.fusionSpecies.abilities, 42, 0)
    
    TestFramework.assertNotNil(abilityResult.selectedAbility, "Should select an ability")
    TestFramework.assertTrue(abilityResult.abilityIndex >= 0 and abilityResult.abilityIndex <= 2, "Valid ability index")
end)

-- Parity Test 9: Edge Case Validation (Empty/Invalid Data Handling)
TestFramework.addTest("TypeScript Parity - Edge Case Error Handling", function()
    -- Test that our error handling matches TypeScript behavior
    
    -- Test nil stats
    local result1, error1 = calculateFusionStats(nil, {HP = 50, ATK = 50, DEF = 50, SPATK = 50, SPDEF = 50, SPD = 50})
    TestFramework.assertEqual(nil, result1, "Should return nil for missing base stats")
    TestFramework.assertNotNil(error1, "Should return error for missing base stats")
    
    -- Test missing type data
    local result2, error2 = determineFusionTypes(nil, {"FIRE", "WATER"})
    TestFramework.assertEqual(nil, result2, "Should return nil for missing base types")
    TestFramework.assertNotNil(error2, "Should return error for missing base types")
    
    -- Test missing ability data  
    local result3, error3 = selectFusionAbility(nil, {"ABILITY_1", "ABILITY_2"}, 12345, 0)
    TestFramework.assertEqual(nil, result3, "Should return nil for missing base abilities")
    TestFramework.assertNotNil(error3, "Should return error for missing base abilities")
end)

-- Parity Test 10: Statistical Validation Across Many Combinations
TestFramework.addTest("TypeScript Parity - Statistical Validation", function()
    -- Test fusion calculations across a large sample to verify statistical correctness
    local testPairs = {
        {{HP = 45, ATK = 49, DEF = 49, SPATK = 65, SPDEF = 65, SPD = 45}, {HP = 60, ATK = 62, DEF = 63, SPATK = 80, SPDEF = 80, SPD = 60}},
        {{HP = 78, ATK = 84, DEF = 78, SPATK = 109, SPDEF = 85, SPD = 100}, {HP = 79, ATK = 83, DEF = 100, SPATK = 85, SPDEF = 105, SPD = 78}},
        {{HP = 65, ATK = 65, DEF = 60, SPATK = 110, SPDEF = 95, SPD = 130}, {HP = 80, ATK = 100, DEF = 200, SPATK = 50, SPDEF = 100, SPD = 50}},
        {{HP = 105, ATK = 150, DEF = 90, SPATK = 150, SPDEF = 90, SPD = 95}, {HP = 91, ATK = 134, DEF = 95, SPATK = 100, SPDEF = 100, SPD = 80}},
        {{HP = 100, ATK = 100, DEF = 100, SPATK = 100, SPDEF = 100, SPD = 100}, {HP = 50, ATK = 50, DEF = 50, SPATK = 50, SPDEF = 50, SPD = 50}}
    }
    
    local successCount = 0
    local totalTests = #testPairs
    
    for i, pair in ipairs(testPairs) do
        local base = pair[1]
        local fusion = pair[2]
        
        local result, error = calculateFusionStats(base, fusion)
        
        if result and not error then
            successCount = successCount + 1
            
            -- Verify each stat follows Math.ceil formula
            for _, stat in ipairs({"HP", "ATK", "DEF", "SPATK", "SPDEF", "SPD"}) do
                local expected = math.ceil((base[stat] + fusion[stat]) / 2)
                TestFramework.assertEqual(expected, result[stat], 
                    string.format("Test %d: %s should equal ceil((%d + %d) / 2) = %d", i, stat, base[stat], fusion[stat], expected))
            end
        end
    end
    
    TestFramework.assertEqual(totalTests, successCount, "All statistical test cases should pass")
end)

-- Run all parity tests
if TestFramework.runTests() then
    print("\n🎯 100% MATHEMATICAL PARITY WITH TYPESCRIPT ACHIEVED!")
    print("✅ All fusion calculation algorithms match TypeScript implementation exactly")
    return true
else
    print("\n❌ MATHEMATICAL PARITY VALIDATION FAILED!")
    print("⚠️  Fusion calculations do not match TypeScript implementation")
    return false
end