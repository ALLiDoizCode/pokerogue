#!/usr/bin/env lua

--[[
Comprehensive Nature, IV, and EV Validation Tests
Exhaustive testing of Pokemon stat calculation components:
- All 25 nature combinations with exact multiplier validation
- IV boundary testing (0-31 for all stats)
- EV constraint validation (individual ≤252, total ≤510)
- Cross-combination testing of nature + IV + EV interactions
- Parity validation against TypeScript reference calculations
]]

-- Load testing frameworks and data
local PropertyBasedTesting = require('testing.aolite.property-based-testing')
local AdvancedPokemonData = require('testing.fixtures.advanced-pokemon-data')
local StatCalculator = require('testing.integration.pokemon-stat-property-tests').StatCalculator

-- Nature validation test suite
local NatureValidationTests = {}

function NatureValidationTests.testAllNatureMultipliers()
  print("🧬 Testing all nature multiplier combinations")
  
  local allNatures = AdvancedPokemonData.getAllNatures()
  local failures = {}
  
  for _, natureName in ipairs(allNatures) do
    local natureData = AdvancedPokemonData.natureDatabase[natureName]
    local multipliers = StatCalculator.getNatureMultipliers(natureName)
    
    -- Verify multipliers match expected values
    local expectedMultipliers = natureData.multipliers
    for i = 1, 6 do
      if math.abs(multipliers[i] - expectedMultipliers[i]) > 0.001 then
        table.insert(failures, {
          nature = natureName,
          stat = i,
          expected = expectedMultipliers[i],
          actual = multipliers[i]
        })
      end
    end
    
    -- Verify nature properties
    if natureData.boosted and natureData.lowered then
      -- Non-neutral nature should have exactly one 1.1 and one 0.9
      local boosted = 0
      local lowered = 0
      for i = 2, 6 do -- Skip HP (never affected)
        if multipliers[i] == 1.1 then boosted = boosted + 1 end
        if multipliers[i] == 0.9 then lowered = lowered + 1 end
      end
      
      if boosted ~= 1 or lowered ~= 1 then
        table.insert(failures, {
          nature = natureName,
          issue = "incorrect_boost_pattern",
          boosted = boosted,
          lowered = lowered
        })
      end
    else
      -- Neutral nature should have all 1.0 multipliers
      for i = 1, 6 do
        if multipliers[i] ~= 1.0 then
          table.insert(failures, {
            nature = natureName,
            issue = "neutral_nature_not_neutral",
            stat = i,
            multiplier = multipliers[i]
          })
        end
      end
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ Nature validation failed: %d issues found", #failures))
    for _, failure in ipairs(failures) do
      print(string.format("  - %s: %s", failure.nature, failure.issue or "multiplier_mismatch"))
    end
    return false
  else
    print(string.format("✅ All %d natures validated successfully", #allNatures))
    return true
  end
end

function NatureValidationTests.testNatureStatMapping()
  print("🎯 Testing nature stat boost/lower mapping")
  
  local testCases = {
    {nature = "Adamant", boosted = 2, lowered = 4}, -- +Atk, -SpA
    {nature = "Modest", boosted = 4, lowered = 2},  -- +SpA, -Atk
    {nature = "Timid", boosted = 6, lowered = 2},   -- +Spe, -Atk
    {nature = "Bold", boosted = 3, lowered = 2},    -- +Def, -Atk
    {nature = "Calm", boosted = 5, lowered = 2},    -- +SpD, -Atk
    {nature = "Jolly", boosted = 6, lowered = 4},   -- +Spe, -SpA
    {nature = "Impish", boosted = 3, lowered = 4},  -- +Def, -SpA
    {nature = "Careful", boosted = 5, lowered = 4}, -- +SpD, -SpA
    {nature = "Hardy", boosted = nil, lowered = nil} -- Neutral
  }
  
  local failures = {}
  
  for _, testCase in ipairs(testCases) do
    local multipliers = StatCalculator.getNatureMultipliers(testCase.nature)
    
    if testCase.boosted then
      if multipliers[testCase.boosted] ~= 1.1 then
        table.insert(failures, {
          nature = testCase.nature,
          issue = "boosted_stat_incorrect",
          expected = 1.1,
          actual = multipliers[testCase.boosted]
        })
      end
    end
    
    if testCase.lowered then
      if multipliers[testCase.lowered] ~= 0.9 then
        table.insert(failures, {
          nature = testCase.nature,
          issue = "lowered_stat_incorrect", 
          expected = 0.9,
          actual = multipliers[testCase.lowered]
        })
      end
    end
    
    if not testCase.boosted and not testCase.lowered then
      -- Neutral nature
      for i = 1, 6 do
        if multipliers[i] ~= 1.0 then
          table.insert(failures, {
            nature = testCase.nature,
            issue = "neutral_nature_has_modification",
            stat = i,
            multiplier = multipliers[i]
          })
        end
      end
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ Nature mapping failed: %d issues", #failures))
    return false
  else
    print("✅ Nature stat mapping validated")
    return true
  end
end

-- IV validation test suite
local IVValidationTests = {}

function IVValidationTests.testIVBoundaries()
  print("📊 Testing IV boundary values (0-31)")
  
  local baseStats = {100, 100, 100, 100, 100, 100}
  local level = 50
  local evs = {0, 0, 0, 0, 0, 0}
  local nature = "Hardy"
  
  local failures = {}
  
  -- Test each stat with min and max IVs
  for statIndex = 1, 6 do
    -- Test minimum IV (0)
    local minIVs = {15, 15, 15, 15, 15, 15} -- Base IVs
    minIVs[statIndex] = 0
    
    local minStats = StatCalculator.calculateAllStats(baseStats, minIVs, evs, level, nature)
    
    -- Test maximum IV (31)
    local maxIVs = {15, 15, 15, 15, 15, 15}
    maxIVs[statIndex] = 31
    
    local maxStats = StatCalculator.calculateAllStats(baseStats, maxIVs, evs, level, nature)
    
    -- Higher IV should result in higher stat
    if maxStats[statIndex] <= minStats[statIndex] then
      table.insert(failures, {
        stat = statIndex,
        issue = "iv_scaling_failed",
        minStat = minStats[statIndex],
        maxStat = maxStats[statIndex]
      })
    end
    
    -- Check expected IV difference (approximately 15.5 at level 50)
    local expectedDifference = math.floor((31 - 0) * level / 100)
    local actualDifference = maxStats[statIndex] - minStats[statIndex]
    
    if math.abs(actualDifference - expectedDifference) > 2 then -- Allow small rounding differences
      table.insert(failures, {
        stat = statIndex,
        issue = "iv_difference_incorrect",
        expected = expectedDifference,
        actual = actualDifference
      })
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ IV boundary testing failed: %d issues", #failures))
    return false
  else
    print("✅ IV boundary validation passed")
    return true
  end
end

function IVValidationTests.testIVScalingProperty()
  print("📈 Testing IV scaling property across all stats")
  
  local testIterations = 50
  local failures = {}
  
  for iteration = 1, testIterations do
    local baseStats = {
      math.random(50, 150), math.random(50, 150), math.random(50, 150),
      math.random(50, 150), math.random(50, 150), math.random(50, 150)
    }
    local level = math.random(1, 100)
    local evs = {0, 0, 0, 0, 0, 0}
    local nature = "Hardy"
    
    for statIndex = 1, 6 do
      local iv1 = math.random(0, 15)
      local iv2 = math.random(16, 31)
      
      local ivs1 = {15, 15, 15, 15, 15, 15}
      local ivs2 = {15, 15, 15, 15, 15, 15}
      ivs1[statIndex] = iv1
      ivs2[statIndex] = iv2
      
      local stats1 = StatCalculator.calculateAllStats(baseStats, ivs1, evs, level, nature)
      local stats2 = StatCalculator.calculateAllStats(baseStats, ivs2, evs, level, nature)
      
      if stats2[statIndex] <= stats1[statIndex] then
        table.insert(failures, {
          iteration = iteration,
          stat = statIndex,
          iv1 = iv1,
          iv2 = iv2,
          stat1 = stats1[statIndex],
          stat2 = stats2[statIndex]
        })
      end
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ IV scaling property failed: %d/%d tests", #failures, testIterations * 6))
    return false
  else
    print(string.format("✅ IV scaling property validated (%d tests)", testIterations * 6))
    return true
  end
end

-- EV validation test suite
local EVValidationTests = {}

function EVValidationTests.testEVConstraints()
  print("⚖️  Testing EV constraint validation")
  
  local failures = {}
  
  -- Test individual EV limits (0-252)
  local testCases = {
    {evs = {253, 0, 0, 0, 0, 0}, shouldFail = true, reason = "individual_ev_over_252"},
    {evs = {252, 252, 7, 0, 0, 0}, shouldFail = true, reason = "total_ev_over_510"},
    {evs = {252, 252, 6, 0, 0, 0}, shouldFail = false, reason = "valid_max_spread"},
    {evs = {0, 0, 0, 0, 0, 0}, shouldFail = false, reason = "all_zero_valid"},
    {evs = {85, 85, 85, 85, 85, 85}, shouldFail = false, reason = "equal_spread_valid"},
    {evs = {-1, 0, 0, 0, 0, 0}, shouldFail = true, reason = "negative_ev_invalid"}
  }
  
  for i, testCase in ipairs(testCases) do
    local isValid, errorMessage = AdvancedPokemonData.validateEVSpread(testCase.evs)
    
    if testCase.shouldFail and isValid then
      table.insert(failures, {
        testCase = i,
        issue = "should_have_failed",
        reason = testCase.reason,
        evs = testCase.evs
      })
    elseif not testCase.shouldFail and not isValid then
      table.insert(failures, {
        testCase = i,
        issue = "should_have_passed",
        reason = testCase.reason,
        evs = testCase.evs,
        error = errorMessage
      })
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ EV constraint validation failed: %d issues", #failures))
    return false
  else
    print("✅ EV constraint validation passed")
    return true
  end
end

function EVValidationTests.testEVEffectiveness()
  print("💪 Testing EV effectiveness (4 EVs = 1 stat point at level 100)")
  
  local baseStats = {100, 100, 100, 100, 100, 100}
  local level = 100
  local ivs = {31, 31, 31, 31, 31, 31}
  local nature = "Hardy"
  
  local failures = {}
  
  for statIndex = 1, 6 do
    -- Test with 0 EVs
    local evs0 = {0, 0, 0, 0, 0, 0}
    local stats0 = StatCalculator.calculateAllStats(baseStats, ivs, evs0, level, nature)
    
    -- Test with 4 EVs in one stat
    local evs4 = {0, 0, 0, 0, 0, 0}
    evs4[statIndex] = 4
    local stats4 = StatCalculator.calculateAllStats(baseStats, ivs, evs4, level, nature)
    
    -- Should be exactly 1 point difference (except for HP which may round differently)
    local expectedDifference = 1
    local actualDifference = stats4[statIndex] - stats0[statIndex]
    
    if actualDifference ~= expectedDifference then
      table.insert(failures, {
        stat = statIndex,
        expectedDiff = expectedDifference,
        actualDiff = actualDifference,
        isHP = (statIndex == 1)
      })
    end
    
    -- Test with 252 EVs (should be 63 points at level 100)
    local evs252 = {0, 0, 0, 0, 0, 0}
    evs252[statIndex] = 252
    local stats252 = StatCalculator.calculateAllStats(baseStats, ivs, evs252, level, nature)
    
    local expectedMax = math.floor(252 / 4)
    local actualMax = stats252[statIndex] - stats0[statIndex]
    
    if actualMax ~= expectedMax then
      table.insert(failures, {
        stat = statIndex,
        test = "max_ev_effect",
        expectedMax = expectedMax,
        actualMax = actualMax
      })
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ EV effectiveness testing failed: %d issues", #failures))
    return false
  else
    print("✅ EV effectiveness validated")
    return true
  end
end

-- Comprehensive cross-combination testing
local CrossCombinationTests = {}

function CrossCombinationTests.testNatureIVEVInteractions()
  print("🔗 Testing nature + IV + EV interaction combinations")
  
  local testCases = AdvancedPokemonData.ivEvCombinations.perfectIVs.variants
  local natures = {"Adamant", "Modest", "Timid", "Bold", "Calm", "Hardy"}
  local species = AdvancedPokemonData.getSpeciesById(25) -- Pikachu
  
  local failures = {}
  local totalTests = 0
  
  for _, ivEvCombo in ipairs(testCases) do
    for _, nature in ipairs(natures) do
      totalTests = totalTests + 1
      
      local stats = StatCalculator.calculateAllStats(
        species.baseStats,
        {31, 31, 31, 31, 31, 31}, -- Perfect IVs
        ivEvCombo.evs,
        50, -- Standard level
        nature
      )
      
      -- Validate stats are reasonable
      for i = 1, 6 do
        if stats[i] <= 0 or stats[i] > 1000 then
          table.insert(failures, {
            combo = ivEvCombo.spread,
            nature = nature,
            stat = i,
            value = stats[i],
            issue = "stat_out_of_range"
          })
        end
      end
      
      -- Validate nature effects are applied correctly
      local natureData = AdvancedPokemonData.natureDatabase[nature]
      if natureData.boosted and natureData.lowered then
        local statIndices = {hp = 1, attack = 2, defense = 3, specialAttack = 4, specialDefense = 5, speed = 6}
        local boostedIndex = statIndices[natureData.boosted]
        local loweredIndex = statIndices[natureData.lowered]
        
        -- Calculate what stats would be with neutral nature
        local neutralStats = StatCalculator.calculateAllStats(
          species.baseStats, {31, 31, 31, 31, 31, 31}, ivEvCombo.evs, 50, "Hardy"
        )
        
        -- Check if nature effect is visible in final stats
        local boostedRatio = stats[boostedIndex] / neutralStats[boostedIndex]
        local loweredRatio = stats[loweredIndex] / neutralStats[loweredIndex]
        
        if math.abs(boostedRatio - 1.1) > 0.02 then -- Allow small rounding errors
          table.insert(failures, {
            combo = ivEvCombo.spread,
            nature = nature,
            issue = "boosted_ratio_incorrect",
            expected = 1.1,
            actual = boostedRatio
          })
        end
        
        if math.abs(loweredRatio - 0.9) > 0.02 then
          table.insert(failures, {
            combo = ivEvCombo.spread,
            nature = nature,
            issue = "lowered_ratio_incorrect",
            expected = 0.9,
            actual = loweredRatio
          })
        end
      end
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ Cross-combination testing failed: %d/%d tests", #failures, totalTests))
    return false
  else
    print(string.format("✅ Cross-combination testing passed (%d tests)", totalTests))
    return true
  end
end

function CrossCombinationTests.testEdgeCaseInteractions()
  print("🎯 Testing edge case interactions")
  
  local edgeCases = {
    AdvancedPokemonData.edgeCases.minimumValues,
    AdvancedPokemonData.edgeCases.maximumValues,
    AdvancedPokemonData.edgeCases.shedinja
  }
  
  local failures = {}
  
  for _, edgeCase in ipairs(edgeCases) do
    local calculatedStats = StatCalculator.calculateAllStats(
      edgeCase.species.baseStats,
      edgeCase.ivs,
      edgeCase.evs,
      edgeCase.level,
      edgeCase.nature
    )
    
    -- Compare with expected stats
    for i = 1, 6 do
      local expected = edgeCase.expectedStats[i]
      local actual = calculatedStats[i]
      
      -- Special case for Shedinja HP
      if edgeCase.specialCase == "hp_always_one" and i == 1 then
        if actual ~= 1 then
          table.insert(failures, {
            case = edgeCase.species.name,
            stat = "HP",
            expected = 1,
            actual = actual,
            issue = "shedinja_hp_not_one"
          })
        end
      else
        -- Allow small differences due to rounding
        if math.abs(actual - expected) > 1 then
          table.insert(failures, {
            case = edgeCase.species.name,
            stat = i,
            expected = expected,
            actual = actual,
            issue = "stat_calculation_mismatch"
          })
        end
      end
    end
  end
  
  if #failures > 0 then
    print(string.format("❌ Edge case testing failed: %d issues", #failures))
    return false
  else
    print("✅ Edge case interactions validated")
    return true
  end
end

-- Main test execution function
local function runNatureIVEVValidationTests()
  print("🧪 Running Comprehensive Nature/IV/EV Validation Tests")
  print(string.rep("=", 60))
  
  local results = {}
  
  -- Nature validation tests
  print("\n🧬 Nature Validation Tests")
  results.allNatureMultipliers = NatureValidationTests.testAllNatureMultipliers()
  results.natureStatMapping = NatureValidationTests.testNatureStatMapping()
  
  -- IV validation tests
  print("\n📊 IV Validation Tests")
  results.ivBoundaries = IVValidationTests.testIVBoundaries()
  results.ivScalingProperty = IVValidationTests.testIVScalingProperty()
  
  -- EV validation tests
  print("\n⚖️  EV Validation Tests")
  results.evConstraints = EVValidationTests.testEVConstraints()
  results.evEffectiveness = EVValidationTests.testEVEffectiveness()
  
  -- Cross-combination tests
  print("\n🔗 Cross-Combination Tests")
  results.natureIVEVInteractions = CrossCombinationTests.testNatureIVEVInteractions()
  results.edgeCaseInteractions = CrossCombinationTests.testEdgeCaseInteractions()
  
  -- Calculate overall results
  local totalTests = 0
  local passedTests = 0
  
  for testName, passed in pairs(results) do
    totalTests = totalTests + 1
    if passed then
      passedTests = passedTests + 1
    end
  end
  
  print(string.rep("=", 60))
  print(string.format("📊 Nature/IV/EV Validation Summary: %d/%d tests passed", passedTests, totalTests))
  
  if passedTests == totalTests then
    print("🎉 All validation tests passed!")
  else
    print("⚠️  Some validation tests failed - check output above")
  end
  
  return results
end

-- Export test functions
return {
  runNatureIVEVValidationTests = runNatureIVEVValidationTests,
  NatureValidationTests = NatureValidationTests,
  IVValidationTests = IVValidationTests,
  EVValidationTests = EVValidationTests,
  CrossCombinationTests = CrossCombinationTests
}