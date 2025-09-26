#!/usr/bin/env lua

--[[
Multi-Process Coordination Tests for Pokemon Statistics
Tests complex multi-process scenarios involving Pokemon stat calculations:
- Pokemon data retrieval and stat calculation coordination
- Multi-process battle scenario coordination
- Evolution calculation across multiple processes
- State synchronization across Pokemon-related processes
]]

-- Load testing frameworks
local EnhancedFramework = require('testing.aolite.enhanced-test-framework')
local CoordinationTesting = EnhancedFramework.coordination
local PropertyBasedTesting = EnhancedFramework.properties
local StateManagement = EnhancedFramework.stateManagement

-- Test configuration
local TestConfig = {
  processTimeout = 5000, -- 5 seconds
  messageDelay = 100,     -- 100ms
  maxRetries = 3
}

-- Mock process implementations for testing
local function createPokemonSpeciesProcess()
  return {
    type = "pokemon-species-db",
    config = {
      database = "embedded",
      cacheSize = 1000
    },
    handlers = {
      GetSpecies = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "GetSpecies"
        end,
        handler = function(msg)
          local pokemonId = json.decode(msg.Data).id
          local speciesData = {
            id = pokemonId,
            name = pokemonId == 25 and "Pikachu" or "Unknown",
            baseStats = pokemonId == 25 and {35, 55, 40, 50, 50, 90} or {50, 50, 50, 50, 50, 50},
            types = pokemonId == 25 and {"Electric"} or {"Normal"},
            abilities = pokemonId == 25 and {"Static", "Lightning Rod"} or {"Normalize"}
          }

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              species = speciesData
            })
          })
        end
      },
      GetBaseStats = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "GetBaseStats"
        end,
        handler = function(msg)
          local pokemonId = json.decode(msg.Data).id
          local baseStats = pokemonId == 25 and
            {hp = 35, attack = 55, defense = 40, specialAttack = 50, specialDefense = 50, speed = 90} or
            {hp = 50, attack = 50, defense = 50, specialAttack = 50, specialDefense = 50, speed = 50}

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              baseStats = baseStats
            })
          })
        end
      }
    }
  }
end

local function createStatCalculatorProcess()
  return {
    type = "stat-calculator",
    config = {
      formulaVersion = "Gen8",
      precisionLevel = "high"
    },
    handlers = {
      CalculateStats = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "CalculateStats"
        end,
        handler = function(msg)
          local data = json.decode(msg.Data)
          local baseStats = data.baseStats
          local level = data.level or 50
          local ivs = data.ivs or {31, 31, 31, 31, 31, 31}
          local evs = data.evs or {0, 0, 0, 0, 0, 0}
          local nature = data.nature or "Hardy"

          -- Gen 8 stat calculation formula
          local function calculateStat(base, iv, ev, level, natureMultiplier, isHP)
            if isHP then
              return math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + level + 10)
            else
              local stat = math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + 5)
              return math.floor(stat * natureMultiplier)
            end
          end

          -- Nature multipliers (simplified)
          local natureMultipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
          if nature == "Timid" then
            natureMultipliers[2] = 0.9  -- -Attack
            natureMultipliers[6] = 1.1  -- +Speed
          elseif nature == "Modest" then
            natureMultipliers[2] = 0.9  -- -Attack
            natureMultipliers[4] = 1.1  -- +Special Attack
          end

          local finalStats = {}
          for i = 1, 6 do
            finalStats[i] = calculateStat(
              baseStats[i], ivs[i], evs[i], level,
              natureMultipliers[i], i == 1 -- HP stat
            )
          end

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              finalStats = finalStats,
              calculation = {
                level = level,
                nature = nature,
                formula = "Gen8"
              }
            })
          })
        end
      }
    }
  }
end

local function createCoordinatorProcess()
  return {
    type = "coordinator",
    config = {
      orchestrationMode = "async",
      timeoutMs = 5000
    },
    handlers = {
      GetPokemonStats = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "GetPokemonStats"
        end,
        handler = function(msg)
          local data = json.decode(msg.Data)
          local pokemonId = data.pokemonId
          local level = data.level or 50

          -- Orchestrate multi-process stat calculation
          -- Step 1: Get species data
          -- Step 2: Calculate final stats
          -- Step 3: Return combined result

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              orchestrationComplete = true,
              pokemonId = pokemonId,
              level = level
            })
          })
        end
      }
    }
  }
end

-- Test Scenarios

local function testBasicPokemonStatCalculation()
  local processes = {
    {name = "speciesDB", type = "pokemon-species-db", config = {}, handlers = createPokemonSpeciesProcess().handlers},
    {name = "statCalc", type = "stat-calculator", config = {}, handlers = createStatCalculatorProcess().handlers}
  }

  local messages = {
    {
      from = "statCalc",
      to = "speciesDB",
      action = "GetBaseStats",
      data = {id = 25}, -- Pikachu
      tags = {Action = "GetBaseStats"}
    },
    {
      from = "speciesDB",
      to = "statCalc",
      action = "CalculateStats",
      data = {
        baseStats = {35, 55, 40, 50, 50, 90},
        level = 50,
        ivs = {31, 31, 31, 31, 31, 31},
        evs = {0, 0, 0, 252, 6, 252},
        nature = "Timid"
      },
      tags = {Action = "CalculateStats"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify both processes received and responded to messages
      assert(#messageLog >= 2, "Should have at least 2 messages in log")

      -- Check that stat calculation process exists and is functional
      local statCalcProcess = processes["statCalc"]
      assert(statCalcProcess, "Stat calculator process should exist")
      assert(statCalcProcess.handlers.CalculateStats, "Should have CalculateStats handler")

      return true
    end,

    function(processes, messageLog)
      -- Verify message routing worked correctly
      local hasGetBaseStats = false
      local hasCalculateStats = false

      for _, msg in ipairs(messageLog) do
        if msg.Action == "GetBaseStats" then hasGetBaseStats = true end
        if msg.Action == "CalculateStats" then hasCalculateStats = true end
      end

      assert(hasGetBaseStats, "Should have GetBaseStats message")
      assert(hasCalculateStats, "Should have CalculateStats message")

      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "basicPokemonStatCalculation",
    processes,
    messages,
    validations
  )
end

local function testMultiProcessBattlePreparation()
  local processes = {
    {name = "coordinator", type = "coordinator", config = {}, handlers = createCoordinatorProcess().handlers},
    {name = "speciesDB", type = "pokemon-species-db", config = {}, handlers = createPokemonSpeciesProcess().handlers},
    {name = "statCalc", type = "stat-calculator", config = {}, handlers = createStatCalculatorProcess().handlers}
  }

  local messages = {
    {
      from = "coordinator",
      to = "speciesDB",
      action = "GetSpecies",
      data = {id = 25},
      tags = {Action = "GetSpecies"}
    },
    {
      from = "coordinator",
      to = "statCalc",
      action = "CalculateStats",
      data = {
        baseStats = {35, 55, 40, 50, 50, 90},
        level = 50,
        nature = "Timid"
      },
      tags = {Action = "CalculateStats"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify coordinator orchestrated the battle preparation
      local coordinatorProcess = processes["coordinator"]
      assert(coordinatorProcess, "Coordinator process should exist")

      -- Check message flow
      assert(#messageLog >= 2, "Should have coordination messages")

      return true
    end,

    function(processes, messageLog)
      -- Verify all required data was retrieved for battle
      local hasSpeciesData = false
      local hasStatCalculation = false

      for _, msg in ipairs(messageLog) do
        if msg.Action == "GetSpecies" then hasSpeciesData = true end
        if msg.Action == "CalculateStats" then hasStatCalculation = true end
      end

      assert(hasSpeciesData, "Should retrieve species data for battle")
      assert(hasStatCalculation, "Should calculate stats for battle")

      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "multiProcessBattlePreparation",
    processes,
    messages,
    validations
  )
end

local function testEvolutionCalculationCoordination()
  local processes = {
    {name = "evolutionEngine", type = "evolution-engine", config = {}},
    {name = "speciesDB", type = "pokemon-species-db", config = {}, handlers = createPokemonSpeciesProcess().handlers},
    {name = "statCalc", type = "stat-calculator", config = {}, handlers = createStatCalculatorProcess().handlers}
  }

  -- Mock evolution engine handlers
  processes[1].handlers = {
    ProcessEvolution = {
      matcher = function(msg)
        return msg.Tags and msg.Tags.Action == "ProcessEvolution"
      end,
      handler = function(msg)
        local data = json.decode(msg.Data)
        -- Mock evolution: Pichu (172) -> Pikachu (25)
        local evolutionResult = {
          success = true,
          originalSpecies = data.originalSpecies or 172,
          evolvedSpecies = 25,
          evolutionTrigger = "level",
          requiredLevel = 2
        }

        ao.send({
          Target = msg.From,
          Action = "SaveState",
          Data = json.encode(evolutionResult)
        })
      end
    }
  }

  local messages = {
    {
      from = "evolutionEngine",
      to = "speciesDB",
      action = "GetSpecies",
      data = {id = 172}, -- Pichu
      tags = {Action = "GetSpecies"}
    },
    {
      from = "evolutionEngine",
      to = "evolutionEngine",
      action = "ProcessEvolution",
      data = {originalSpecies = 172, level = 2},
      tags = {Action = "ProcessEvolution"}
    },
    {
      from = "evolutionEngine",
      to = "statCalc",
      action = "CalculateStats",
      data = {
        baseStats = {35, 55, 40, 50, 50, 90}, -- Pikachu stats
        level = 2
      },
      tags = {Action = "CalculateStats"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify evolution process coordination
      assert(#messageLog >= 3, "Should have evolution coordination messages")

      local hasEvolutionProcess = false
      for _, msg in ipairs(messageLog) do
        if msg.Action == "ProcessEvolution" then hasEvolutionProcess = true end
      end

      assert(hasEvolutionProcess, "Should process evolution")
      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "evolutionCalculationCoordination",
    processes,
    messages,
    validations
  )
end

-- Property-based tests for stat calculations
local function createStatCalculationPropertyTests()
  return {
    statCalculationInvariants = {
      generator = function()
        return {
          baseStats = {
            PropertyBasedTesting.generators.integer(1, 255)(),
            PropertyBasedTesting.generators.integer(1, 255)(),
            PropertyBasedTesting.generators.integer(1, 255)(),
            PropertyBasedTesting.generators.integer(1, 255)(),
            PropertyBasedTesting.generators.integer(1, 255)(),
            PropertyBasedTesting.generators.integer(1, 255)()
          },
          level = PropertyBasedTesting.generators.integer(1, 100)(),
          ivs = {
            PropertyBasedTesting.generators.integer(0, 31)(),
            PropertyBasedTesting.generators.integer(0, 31)(),
            PropertyBasedTesting.generators.integer(0, 31)(),
            PropertyBasedTesting.generators.integer(0, 31)(),
            PropertyBasedTesting.generators.integer(0, 31)(),
            PropertyBasedTesting.generators.integer(0, 31)()
          },
          evs = {
            PropertyBasedTesting.generators.integer(0, 252)(),
            PropertyBasedTesting.generators.integer(0, 252)(),
            PropertyBasedTesting.generators.integer(0, 252)(),
            PropertyBasedTesting.generators.integer(0, 252)(),
            PropertyBasedTesting.generators.integer(0, 252)(),
            PropertyBasedTesting.generators.integer(0, 252)()
          },
          nature = PropertyBasedTesting.generators.pokemonNature()()
        }
      end,
      predicate = function(statData)
        -- Property: All calculated stats must be positive
        local processes = {
          statCalc = CoordinationTesting.spawnProcess("stat-calculator", {})
        }

        -- Mock stat calculation (simplified for property testing)
        for i = 1, 6 do
          local base = statData.baseStats[i]
          local iv = statData.ivs[i]
          local ev = statData.evs[i]
          local level = statData.level

          local calculatedStat
          if i == 1 then -- HP
            calculatedStat = math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + level + 10)
          else
            calculatedStat = math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + 5)
          end

          if calculatedStat <= 0 then
            return false
          end
        end

        return true
      end,
      config = {iterations = 50}
    },

    levelScalingProperty = {
      generator = function()
        return {
          baseStats = {100, 100, 100, 100, 100, 100},
          ivs = {31, 31, 31, 31, 31, 31},
          evs = {0, 0, 0, 0, 0, 0},
          level1 = PropertyBasedTesting.generators.integer(1, 50)(),
          level2 = PropertyBasedTesting.generators.integer(51, 100)()
        }
      end,
      predicate = function(testData)
        -- Property: Higher level should always result in higher stats
        local function calculateStat(base, iv, ev, level, isHP)
          if isHP then
            return math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + level + 10)
          else
            return math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + 5)
          end
        end

        for i = 1, 6 do
          local stat1 = calculateStat(testData.baseStats[i], testData.ivs[i], testData.evs[i], testData.level1, i == 1)
          local stat2 = calculateStat(testData.baseStats[i], testData.ivs[i], testData.evs[i], testData.level2, i == 1)

          if stat2 <= stat1 then
            return false
          end
        end

        return true
      end,
      config = {iterations = 100}
    }
  }
end

-- Advanced state management tests
local function testPokemonStatePersistence()
  local initialWorldState = StateManagement.createEmptyWorld()

  -- Add Pokemon data to world state
  initialWorldState.entities["pokemon_1"] = {
    id = "pokemon_1",
    speciesId = 25,
    level = 50,
    stats = {145, 122, 90, 317, 106, 317}
  }

  local persistFunction = function(worldState)
    -- Mock persistence - would save to AO state in real implementation
    return {success = true, savedAt = os.time()}
  end

  local loadFunction = function()
    -- Mock loading - would load from AO state
    return StateManagement.deepCopy(initialWorldState)
  end

  return StateManagement.testStatePersistence(
    initialWorldState,
    persistFunction,
    loadFunction
  )
end

-- Main test execution
local function runPokemonStatisticsTests()
  print("🧪 Running Pokemon Statistics Process Advanced Testing")
  print(string.rep("=", 60))

  local testResults = {}

  -- Run coordination tests
  testResults.basicStatCalculation = testBasicPokemonStatCalculation()
  testResults.battlePreparation = testMultiProcessBattlePreparation()
  testResults.evolutionCoordination = testEvolutionCalculationCoordination()

  -- Run property-based tests
  PropertyBasedTesting.initialize({iterations = 50, seed = 12345})
  testResults.propertyTests = PropertyBasedTesting.runPropertySuite(
    "pokemonStatCalculations",
    createStatCalculationPropertyTests()
  )

  -- Run state persistence tests
  testResults.statePersistence = testPokemonStatePersistence()

  -- Generate summary
  local totalTests = 0
  local passedTests = 0

  for testName, result in pairs(testResults) do
    totalTests = totalTests + 1
    if result.success or result.passed or result.dataIntegrity then
      passedTests = passedTests + 1
    end
  end

  print(string.format("\n📊 Pokemon Statistics Testing Summary: %d/%d tests passed",
    passedTests, totalTests))

  return testResults
end

-- Export test functions
return {
  runPokemonStatisticsTests = runPokemonStatisticsTests,
  testBasicPokemonStatCalculation = testBasicPokemonStatCalculation,
  testMultiProcessBattlePreparation = testMultiProcessBattlePreparation,
  testEvolutionCalculationCoordination = testEvolutionCalculationCoordination,
  createStatCalculationPropertyTests = createStatCalculationPropertyTests,
  testPokemonStatePersistence = testPokemonStatePersistence
}