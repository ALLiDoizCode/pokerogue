#!/usr/bin/env lua

--[[
Property-Based Tests for Pokemon Statistics Calculations
Comprehensive property testing using custom Lua generators:
- Stat calculation formula invariants and properties
- Nature modifier validation across all combinations
- IV/EV boundary testing and constraint validation
- Cross-generation stat formula consistency
- Performance property validation under load
]]

-- Load testing frameworks
local PropertyBasedTesting = require('testing.aolite.property-based-testing')
local AdvancedBenchmarks = require('testing.aolite.advanced-benchmarks')

-- Pokemon stat calculation implementation for testing
local StatCalculator = {}

function StatCalculator.calculateStat(base, iv, ev, level, natureMultiplier, isHP)
  -- Generation 8 stat calculation formula
  if isHP then
    return math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + level + 10)
  else
    local stat = math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + 5)
    return math.floor(stat * natureMultiplier)
  end
end

function StatCalculator.calculateAllStats(baseStats, ivs, evs, level, nature)
  local natureMultipliers = StatCalculator.getNatureMultipliers(nature)
  local finalStats = {}
  
  for i = 1, 6 do
    finalStats[i] = StatCalculator.calculateStat(
      baseStats[i], ivs[i], evs[i], level, 
      natureMultipliers[i], i == 1 -- First stat is HP
    )
  end
  
  return finalStats
end

function StatCalculator.getNatureMultipliers(nature)
  local multipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
  
  local natureEffects = {
    Lonely = {attack = 1.1, defense = 0.9},
    Brave = {attack = 1.1, speed = 0.9},
    Adamant = {attack = 1.1, specialAttack = 0.9},
    Naughty = {attack = 1.1, specialDefense = 0.9},
    Bold = {defense = 1.1, attack = 0.9},
    Relaxed = {defense = 1.1, speed = 0.9},
    Impish = {defense = 1.1, specialAttack = 0.9},
    Lax = {defense = 1.1, specialDefense = 0.9},
    Timid = {speed = 1.1, attack = 0.9},
    Hasty = {speed = 1.1, defense = 0.9},
    Jolly = {speed = 1.1, specialAttack = 0.9},
    Naive = {speed = 1.1, specialDefense = 0.9},
    Modest = {specialAttack = 1.1, attack = 0.9},
    Mild = {specialAttack = 1.1, defense = 0.9},
    Quiet = {specialAttack = 1.1, speed = 0.9},
    Rash = {specialAttack = 1.1, specialDefense = 0.9},
    Calm = {specialDefense = 1.1, attack = 0.9},
    Gentle = {specialDefense = 1.1, defense = 0.9},
    Sassy = {specialDefense = 1.1, speed = 0.9},
    Careful = {specialDefense = 1.1, specialAttack = 0.9}
  }
  
  local effect = natureEffects[nature]
  if effect then
    local statIndices = {hp = 1, attack = 2, defense = 3, specialAttack = 4, specialDefense = 5, speed = 6}
    for stat, multiplier in pairs(effect) do
      local index = statIndices[stat]
      if index then
        multipliers[index] = multiplier
      end
    end
  end
  
  return multipliers
end

-- Enhanced Pokemon data generators
local function createAdvancedPokemonGenerators()
  local generators = {}
  
  -- Valid Pokemon species data generator
  generators.validPokemonSpecies = function()
    local speciesData = {
      {id = 1, name = "Bulbasaur", baseStats = {45, 49, 49, 65, 65, 45}, types = {"Grass", "Poison"}},
      {id = 25, name = "Pikachu", baseStats = {35, 55, 40, 50, 50, 90}, types = {"Electric"}},
      {id = 150, name = "Mewtwo", baseStats = {106, 110, 90, 154, 90, 130}, types = {"Psychic"}},
      {id = 144, name = "Articuno", baseStats = {90, 85, 100, 95, 125, 85}, types = {"Ice", "Flying"}},
      {id = 493, name = "Arceus", baseStats = {120, 120, 120, 120, 120, 120}, types = {"Normal"}}
    }
    
    return function()
      return speciesData[math.random(1, #speciesData)]
    end
  end
  
  -- Competitive Pokemon build generator
  generators.competitivePokemonBuild = function()
    return function()
      local species = generators.validPokemonSpecies()()
      
      return {
        species = species,
        level = math.random(50, 100), -- Competitive levels
        ivs = {
          PropertyBasedTesting.generators.integer(25, 31)(), -- High IVs
          PropertyBasedTesting.generators.integer(25, 31)(),
          PropertyBasedTesting.generators.integer(25, 31)(),
          PropertyBasedTesting.generators.integer(25, 31)(),
          PropertyBasedTesting.generators.integer(25, 31)(),
          PropertyBasedTesting.generators.integer(25, 31)()
        },
        evs = generators.validEVSpread()(),
        nature = PropertyBasedTesting.generators.pokemonNature()()
      }
    end
  end
  
  -- Valid EV spread generator (must total ≤ 510, each stat ≤ 252)
  generators.validEVSpread = function()
    return function()
      local evs = {0, 0, 0, 0, 0, 0}
      local totalEVs = 0
      local maxTotal = 510
      
      -- Distribute EVs randomly but within constraints
      for i = 1, 6 do
        local maxForStat = math.min(252, maxTotal - totalEVs)
        if maxForStat > 0 then
          evs[i] = math.random(0, maxForStat)
          totalEVs = totalEVs + evs[i]
        end
      end
      
      return evs
    end
  end
  
  -- Edge case generator for boundary testing
  generators.edgeCasePokemon = function()
    return function()
      local edgeCases = {
        -- Minimum values
        {
          baseStats = {1, 1, 1, 1, 1, 1},
          level = 1,
          ivs = {0, 0, 0, 0, 0, 0},
          evs = {0, 0, 0, 0, 0, 0},
          nature = "Hardy"
        },
        -- Maximum values
        {
          baseStats = {255, 255, 255, 255, 255, 255},
          level = 100,
          ivs = {31, 31, 31, 31, 31, 31},
          evs = {252, 252, 6, 0, 0, 0}, -- Valid EV spread
          nature = "Adamant"
        },
        -- Shuckle (extreme defense)
        {
          baseStats = {20, 10, 230, 10, 230, 5},
          level = 50,
          ivs = {31, 0, 31, 0, 31, 0},
          evs = {252, 0, 252, 0, 6, 0},
          nature = "Bold"
        }
      }
      
      return edgeCases[math.random(1, #edgeCases)]
    end
  end
  
  return generators
end

-- Core property tests for stat calculations
local function createStatCalculationProperties()
  local generators = createAdvancedPokemonGenerators()
  
  return {
    -- Property: All calculated stats must be positive
    statsAlwaysPositive = {
      generator = generators.competitivePokemonBuild,
      predicate = function(pokemon)
        local finalStats = StatCalculator.calculateAllStats(
          pokemon.species.baseStats,
          pokemon.ivs,
          pokemon.evs,
          pokemon.level,
          pokemon.nature
        )
        
        for i = 1, 6 do
          if finalStats[i] <= 0 then
            return false
          end
        end
        
        return true
      end,
      config = {iterations = 200}
    },
    
    -- Property: HP stat must always be at least 1
    hpAlwaysAtLeastOne = {
      generator = generators.edgeCasePokemon,
      predicate = function(pokemon)
        local hpStat = StatCalculator.calculateStat(
          pokemon.baseStats[1], pokemon.ivs[1], pokemon.evs[1], 
          pokemon.level, 1.0, true -- HP calculation
        )
        
        return hpStat >= 1
      end,
      config = {iterations = 100}
    },
    
    -- Property: Higher level always results in higher stats (with same other parameters)
    levelScalingProperty = {
      generator = function()
        local basePokemon = generators.competitivePokemonBuild()()
        return {
          pokemon = basePokemon,
          level1 = math.random(1, 50),
          level2 = math.random(51, 100)
        }
      end,
      predicate = function(testData)
        local pokemon = testData.pokemon
        
        local stats1 = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs, 
          testData.level1, pokemon.nature
        )
        
        local stats2 = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
          testData.level2, pokemon.nature
        )
        
        -- All stats should be higher at higher level
        for i = 1, 6 do
          if stats2[i] <= stats1[i] then
            return false
          end
        end
        
        return true
      end,
      config = {iterations = 150}
    },
    
    -- Property: Nature multipliers are exactly 0.9, 1.0, or 1.1
    natureMultiplierPrecision = {
      generator = PropertyBasedTesting.generators.pokemonNature,
      predicate = function(nature)
        local multipliers = StatCalculator.getNatureMultipliers(nature)
        
        for i = 1, 6 do
          local mult = multipliers[i]
          if mult ~= 0.9 and mult ~= 1.0 and mult ~= 1.1 then
            return false
          end
        end
        
        -- Exactly one stat should be boosted and one lowered (or neutral nature)
        local boosted = 0
        local lowered = 0
        for i = 2, 6 do -- Skip HP (never affected by nature)
          if multipliers[i] == 1.1 then boosted = boosted + 1 end
          if multipliers[i] == 0.9 then lowered = lowered + 1 end
        end
        
        -- Either neutral (0 boosted, 0 lowered) or exactly 1 boosted and 1 lowered
        return (boosted == 0 and lowered == 0) or (boosted == 1 and lowered == 1)
      end,
      config = {iterations = 25} -- Test all natures
    },
    
    -- Property: EV constraint validation (total ≤ 510, each ≤ 252)
    evConstraintValidation = {
      generator = function()
        return {
          evs = createAdvancedPokemonGenerators().validEVSpread()(),
          baseStats = PropertyBasedTesting.generators.pokemonStats()(),
          level = PropertyBasedTesting.generators.integer(1, 100)(),
          ivs = PropertyBasedTesting.generators.pokemonIVs()()
        }
      end,
      predicate = function(testData)
        local evs = testData.evs
        
        -- Check individual EV constraints
        for i = 1, 6 do
          if evs[i] < 0 or evs[i] > 252 then
            return false
          end
        end
        
        -- Check total EV constraint
        local totalEVs = 0
        for i = 1, 6 do
          totalEVs = totalEVs + evs[i]
        end
        
        if totalEVs > 510 then
          return false
        end
        
        -- Verify stats can be calculated without error
        local success, _ = pcall(function()
          StatCalculator.calculateAllStats(
            testData.baseStats, testData.ivs, evs, testData.level, "Hardy"
          )
        end)
        
        return success
      end,
      config = {iterations = 300}
    },
    
    -- Property: IV scaling effect (higher IVs = higher stats)
    ivScalingProperty = {
      generator = function()
        local basePokemon = generators.competitivePokemonBuild()()
        return {
          pokemon = basePokemon,
          lowIVs = {0, 0, 0, 0, 0, 0},
          highIVs = {31, 31, 31, 31, 31, 31}
        }
      end,
      predicate = function(testData)
        local pokemon = testData.pokemon
        
        local lowIVStats = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, testData.lowIVs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
        
        local highIVStats = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, testData.highIVs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
        
        -- All stats should be higher with higher IVs
        for i = 1, 6 do
          if highIVStats[i] <= lowIVStats[i] then
            return false
          end
        end
        
        return true
      end,
      config = {iterations = 100}
    },
    
    -- Property: Stat calculation is deterministic
    deterministicCalculation = {
      generator = generators.competitivePokemonBuild,
      predicate = function(pokemon)
        local stats1 = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
        
        local stats2 = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
        
        -- Results should be identical
        for i = 1, 6 do
          if stats1[i] ~= stats2[i] then
            return false
          end
        end
        
        return true
      end,
      config = {iterations = 50}
    }
  }
end

-- Performance property tests
local function createPerformanceProperties()
  local generators = createAdvancedPokemonGenerators()
  
  return {
    -- Property: Stat calculation performance is consistent
    statCalculationPerformance = {
      generator = generators.competitivePokemonBuild,
      predicate = function(pokemon)
        local startTime = os.clock()
        
        local finalStats = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
        
        local endTime = os.clock()
        local executionTime = endTime - startTime
        
        -- Should complete within 1ms (very generous for Lua)
        return executionTime < 0.001
      end,
      config = {iterations = 1000}
    },
    
    -- Property: Bulk stat calculations maintain performance
    bulkCalculationPerformance = {
      generator = function()
        local pokemonList = {}
        for i = 1, 100 do
          pokemonList[i] = generators.competitivePokemonBuild()()
        end
        return pokemonList
      end,
      predicate = function(pokemonList)
        local startTime = os.clock()
        
        for _, pokemon in ipairs(pokemonList) do
          StatCalculator.calculateAllStats(
            pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
            pokemon.level, pokemon.nature
          )
        end
        
        local endTime = os.clock()
        local totalTime = endTime - startTime
        local avgTimePerCalculation = totalTime / #pokemonList
        
        -- Average should be under 0.1ms per calculation
        return avgTimePerCalculation < 0.0001
      end,
      config = {iterations = 10}
    }
  }
end

-- Cross-generation consistency tests (future expansion)
local function createCrossGenerationProperties()
  return {
    -- Property: Generation differences are documented and controlled
    generationConsistency = {
      generator = createAdvancedPokemonGenerators().competitivePokemonBuild,
      predicate = function(pokemon)
        -- For now, we only implement Gen 8 formula
        -- This property ensures we're consistent with our implementation
        local stats = StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
        
        -- Basic sanity check: all stats should be reasonable
        for i = 1, 6 do
          if stats[i] < 1 or stats[i] > 1000 then -- Very generous bounds
            return false
          end
        end
        
        return true
      end,
      config = {iterations = 100}
    }
  }
end

-- Main property test execution
local function runPokemonStatPropertyTests()
  print("🎯 Running Pokemon Stat Calculation Property Tests")
  print(string.rep("=", 60))
  
  -- Initialize property testing framework
  PropertyBasedTesting.initialize({
    iterations = 100,
    seed = 42,
    shrinkingAttempts = 25
  })
  
  local allResults = {}
  
  -- Run core stat calculation properties
  print("\n📊 Core Stat Calculation Properties")
  allResults.coreProperties = PropertyBasedTesting.runPropertySuite(
    "coreStatCalculation",
    createStatCalculationProperties()
  )
  
  -- Run performance properties
  print("\n⚡ Performance Properties")
  allResults.performanceProperties = PropertyBasedTesting.runPropertySuite(
    "statCalculationPerformance", 
    createPerformanceProperties()
  )
  
  -- Run cross-generation properties
  print("\n🌍 Cross-Generation Properties")
  allResults.crossGenProperties = PropertyBasedTesting.runPropertySuite(
    "crossGenerationConsistency",
    createCrossGenerationProperties()
  )
  
  -- Generate comprehensive statistics
  PropertyBasedTesting.generateStatistics()
  
  return allResults
end

-- Benchmark stat calculation performance
local function benchmarkStatCalculations()
  print("\n⏱️  Benchmarking Pokemon Stat Calculations")
  
  local generators = createAdvancedPokemonGenerators()
  
  -- Basic stat calculation benchmark
  local basicBenchmark = AdvancedBenchmarks.benchmarkFunction(
    "basicStatCalculation",
    function()
      local pokemon = generators.competitivePokemonBuild()()
      StatCalculator.calculateAllStats(
        pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
        pokemon.level, pokemon.nature
      )
    end,
    {iterations = 10000, warmup = 1000}
  )
  
  -- Bulk calculation benchmark
  local bulkBenchmark = AdvancedBenchmarks.benchmarkFunction(
    "bulkStatCalculation",
    function()
      for i = 1, 100 do
        local pokemon = generators.competitivePokemonBuild()()
        StatCalculator.calculateAllStats(
          pokemon.species.baseStats, pokemon.ivs, pokemon.evs,
          pokemon.level, pokemon.nature
        )
      end
    end,
    {iterations = 100, warmup = 10}
  )
  
  return {
    basic = basicBenchmark,
    bulk = bulkBenchmark
  }
end

-- Export test functions
return {
  runPokemonStatPropertyTests = runPokemonStatPropertyTests,
  benchmarkStatCalculations = benchmarkStatCalculations,
  createStatCalculationProperties = createStatCalculationProperties,
  createPerformanceProperties = createPerformanceProperties,
  StatCalculator = StatCalculator
}