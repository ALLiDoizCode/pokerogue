#!/usr/bin/env lua

--[[
Battle Engine Process Coordination Tests
Advanced multi-process testing for battle engine coordination:
- Battle engine + data process integration testing
- Complex damage calculation across multiple processes
- Turn resolution with multi-process state management
- Status effects and weather coordination
- Performance testing under battle load scenarios
]]

-- Load testing frameworks
local CoordinationTesting = require('testing.aolite.coordination-testing')
local AdvancedBenchmarks = require('testing.aolite.advanced-benchmarks')
local StateManagement = require('testing.aolite.state-management-advanced')
local AdvancedPokemonData = require('testing.fixtures.advanced-pokemon-data')

-- Battle engine test configuration
local BattleTestConfig = {
  maxTurnTime = 5000,  -- 5 seconds per turn
  maxBattleTime = 300000, -- 5 minutes max battle
  damageVariance = 0.15, -- 15% damage variance
  criticalHitRate = 0.0625 -- 1/16 critical hit rate
}

-- Mock battle engine process implementation
local function createBattleEngineProcess()
  return {
    type = "battle-engine",
    config = {
      version = "1.0.0-adp",
      deterministic = true,
      timeout = 5000
    },
    handlers = {
      ProcessBattleTurn = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "ProcessBattleTurn"
        end,
        handler = function(msg)
          local data = json.decode(msg.Data)
          local gameState = data.gameState
          local battleCommand = data.battleCommand

          -- Process battle turn logic
          local turnResult = {
            success = true,
            turnNumber = gameState.battle.turn + 1,
            action = battleCommand.action,
            timestamp = os.time(),
            processId = ao.id
          }

          if battleCommand.action == "attack" then
            turnResult.damageDealt = math.random(50, 100)
            turnResult.accuracy = true
            turnResult.criticalHit = math.random() < 0.0625
            turnResult.effectiveness = 1.0
          end

          -- Update game state
          gameState.battle.turn = turnResult.turnNumber
          gameState.battle.lastAction = turnResult

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              gameState = gameState,
              turnResult = turnResult
            })
          })
        end
      },

      CalculateDamage = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "CalculateDamage"
        end,
        handler = function(msg)
          local data = json.decode(msg.Data)
          local attacker = data.attacker
          local defender = data.defender
          local move = data.move
          local conditions = data.conditions or {}

          -- Damage calculation formula (simplified)
          local baseDamage = math.floor(
            ((2 * attacker.level + 10) / 250) *
            (attacker.attack / defender.defense) *
            move.power + 2
          )

          -- Apply type effectiveness
          local effectiveness = 1.0
          if move.type == "Electric" and defender.types[1] == "Water" then
            effectiveness = 2.0 -- Super effective
          elseif move.type == "Electric" and defender.types[1] == "Ground" then
            effectiveness = 0.0 -- No effect
          end

          local finalDamage = math.floor(baseDamage * effectiveness)

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              damage = finalDamage,
              effectiveness = effectiveness,
              baseDamage = baseDamage,
              criticalHit = math.random() < 0.0625
            })
          })
        end
      },

      CheckAccuracy = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "CheckAccuracy"
        end,
        handler = function(msg)
          local data = json.decode(msg.Data)
          local move = data.move
          local attacker = data.attacker
          local defender = data.defender

          -- Accuracy calculation
          local moveAccuracy = move.accuracy or 100
          local accuracyStage = attacker.accuracyStage or 0
          local evasionStage = defender.evasionStage or 0

          local stageMultiplier = math.max(1, accuracyStage - evasionStage + 3) / 3
          local finalAccuracy = moveAccuracy * stageMultiplier

          local hit = math.random(1, 100) <= finalAccuracy

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              hit = hit,
              finalAccuracy = finalAccuracy,
              roll = math.random(1, 100)
            })
          })
        end
      }
    }
  }
end

-- Mock moves database process
local function createMoveDatabaseProcess()
  return {
    type = "moves-database",
    config = {
      version = "1.0.0",
      embedded = true
    },
    handlers = {
      GetMove = {
        matcher = function(msg)
          return msg.Tags and msg.Tags.Action == "GetMove"
        end,
        handler = function(msg)
          local data = json.decode(msg.Data)
          local moveId = data.id

          -- Mock move data
          local moves = {
            [85] = {id = 85, name = "Thunderbolt", type = "Electric", power = 90, accuracy = 100, category = "special"},
            [34] = {id = 34, name = "Normal Attack", type = "Normal", power = 80, accuracy = 100, category = "physical"},
            [98] = {id = 98, name = "Quick Attack", type = "Normal", power = 40, accuracy = 100, category = "physical", priority = 1}
          }

          local move = moves[moveId] or {id = moveId, name = "Unknown", type = "Normal", power = 50, accuracy = 100, category = "physical"}

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              move = move
            })
          })
        end
      }
    }
  }
end

-- Battle coordination test scenarios
local BattleCoordinationTests = {}

function BattleCoordinationTests.testBasicBattleTurnCoordination()
  local processes = {
    {name = "battleEngine", type = "battle-engine", config = {}, handlers = createBattleEngineProcess().handlers},
    {name = "movesDB", type = "moves-database", config = {}, handlers = createMoveDatabaseProcess().handlers},
    {name = "pokemonDB", type = "pokemon-species-db", config = {}, handlers = {
      GetSpecies = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "GetSpecies" end,
        handler = function(msg)
          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              species = {id = 25, name = "Pikachu", baseStats = {35, 55, 40, 50, 50, 90}}
            })
          })
        end
      }
    }}
  }

  local messages = {
    {
      from = "battleEngine",
      to = "movesDB",
      action = "GetMove",
      data = {id = 85}, -- Thunderbolt
      tags = {Action = "GetMove"}
    },
    {
      from = "battleEngine",
      to = "pokemonDB",
      action = "GetSpecies",
      data = {id = 25}, -- Pikachu
      tags = {Action = "GetSpecies"}
    },
    {
      from = "battleEngine",
      to = "battleEngine",
      action = "ProcessBattleTurn",
      data = {
        gameState = {
          battle = {
            battleId = "test_battle_1",
            turn = 0,
            battleSeed = 12345
          }
        },
        battleCommand = {
          action = "attack",
          moveId = 85,
          targetId = "opponent_pokemon_1"
        }
      },
      tags = {Action = "ProcessBattleTurn"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify battle turn was processed
      local hasBattleTurn = false
      for _, msg in ipairs(messageLog) do
        if msg.Action == "ProcessBattleTurn" then hasBattleTurn = true end
      end

      assert(hasBattleTurn, "Should process battle turn")
      return true
    end,

    function(processes, messageLog)
      -- Verify data dependencies were resolved
      local hasMove = false
      local hasSpecies = false

      for _, msg in ipairs(messageLog) do
        if msg.Action == "GetMove" then hasMove = true end
        if msg.Action == "GetSpecies" then hasSpecies = true end
      end

      assert(hasMove, "Should retrieve move data")
      assert(hasSpecies, "Should retrieve species data")
      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "basicBattleTurnCoordination",
    processes,
    messages,
    validations
  )
end

function BattleCoordinationTests.testDamageCalculationCoordination()
  local processes = {
    {name = "battleEngine", type = "battle-engine", config = {}, handlers = createBattleEngineProcess().handlers},
    {name = "statCalc", type = "stat-calculator", config = {}, handlers = {
      CalculateStats = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "CalculateStats" end,
        handler = function(msg)
          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              finalStats = {145, 122, 90, 317, 106, 317} -- Pikachu level 50
            })
          })
        end
      }
    }}
  }

  local messages = {
    {
      from = "battleEngine",
      to = "statCalc",
      action = "CalculateStats",
      data = {
        baseStats = {35, 55, 40, 50, 50, 90},
        level = 50,
        nature = "Timid"
      },
      tags = {Action = "CalculateStats"}
    },
    {
      from = "battleEngine",
      to = "battleEngine",
      action = "CalculateDamage",
      data = {
        attacker = {
          level = 50,
          attack = 317, -- Special Attack for Thunderbolt
          types = {"Electric"}
        },
        defender = {
          defense = 180, -- Special Defense
          types = {"Water"}
        },
        move = {
          power = 90,
          type = "Electric",
          category = "special"
        }
      },
      tags = {Action = "CalculateDamage"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify damage calculation coordination
      local hasStatCalc = false
      local hasDamageCalc = false

      for _, msg in ipairs(messageLog) do
        if msg.Action == "CalculateStats" then hasStatCalc = true end
        if msg.Action == "CalculateDamage" then hasDamageCalc = true end
      end

      assert(hasStatCalc, "Should calculate stats before damage")
      assert(hasDamageCalc, "Should calculate damage")
      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "damageCalculationCoordination",
    processes,
    messages,
    validations
  )
end

function BattleCoordinationTests.testStatusEffectCoordination()
  local processes = {
    {name = "battleEngine", type = "battle-engine", config = {}, handlers = createBattleEngineProcess().handlers},
    {name = "statusEngine", type = "status-effects-engine", config = {}, handlers = {
      ApplyStatusEffect = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "ApplyStatusEffect" end,
        handler = function(msg)
          local data = json.decode(msg.Data)

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              statusEffect = {
                type = data.statusType,
                duration = data.duration or 3,
                applied = true
              }
            })
          })
        end
      },
      ProcessStatusDamage = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "ProcessStatusDamage" end,
        handler = function(msg)
          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              damage = 25, -- Poison damage
              statusActive = true
            })
          })
        end
      }
    }}
  }

  local messages = {
    {
      from = "battleEngine",
      to = "statusEngine",
      action = "ApplyStatusEffect",
      data = {
        statusType = "poison",
        targetId = "pokemon_1",
        duration = 3
      },
      tags = {Action = "ApplyStatusEffect"}
    },
    {
      from = "battleEngine",
      to = "statusEngine",
      action = "ProcessStatusDamage",
      data = {
        pokemonId = "pokemon_1",
        statusType = "poison"
      },
      tags = {Action = "ProcessStatusDamage"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify status effect coordination
      local hasApplyStatus = false
      local hasProcessDamage = false

      for _, msg in ipairs(messageLog) do
        if msg.Action == "ApplyStatusEffect" then hasApplyStatus = true end
        if msg.Action == "ProcessStatusDamage" then hasProcessDamage = true end
      end

      assert(hasApplyStatus, "Should apply status effect")
      assert(hasProcessDamage, "Should process status damage")
      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "statusEffectCoordination",
    processes,
    messages,
    validations
  )
end

-- Complex battle scenario testing
function BattleCoordinationTests.testComplexBattleScenario()
  local scenario = AdvancedPokemonData.battleScenarios.typeEffectivenessScenario

  local processes = {
    {name = "battleEngine", type = "battle-engine", config = {}, handlers = createBattleEngineProcess().handlers},
    {name = "coordinator", type = "coordinator", config = {}, handlers = {
      OrchestrateBattle = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "OrchestrateBattle" end,
        handler = function(msg)
          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              battleOrchestrated = true,
              complexity = "high"
            })
          })
        end
      }
    }}
  }

  local messages = {
    {
      from = "coordinator",
      to = "battleEngine",
      action = "CalculateDamage",
      data = {
        attacker = scenario.pokemon1,
        defender = scenario.pokemon2,
        move = scenario.move
      },
      tags = {Action = "CalculateDamage"}
    },
    {
      from = "coordinator",
      to = "coordinator",
      action = "OrchestrateBattle",
      data = {
        scenario = scenario.description,
        complexity = "type_effectiveness"
      },
      tags = {Action = "OrchestrateBattle"}
    }
  }

  local validations = {
    function(processes, messageLog)
      -- Verify complex scenario handling
      assert(#messageLog >= 2, "Should handle complex battle scenario")
      return true
    end
  }

  return CoordinationTesting.testCoordinationScenario(
    "complexBattleScenario",
    processes,
    messages,
    validations
  )
end

-- Performance testing for battle coordination
function BattleCoordinationTests.benchmarkBattleCoordination()
  print("⏱️  Benchmarking battle coordination performance")

  local function battleCoordinationTest()
    local processes = {
      battleEngine = CoordinationTesting.spawnProcess("battle-engine", {}),
      movesDB = CoordinationTesting.spawnProcess("moves-database", {}),
      statCalc = CoordinationTesting.spawnProcess("stat-calculator", {})
    }

    -- Simulate battle turn coordination
    for i = 1, 10 do
      CoordinationTesting.routeMessage(processes.battleEngine.id, {
        Target = processes.movesDB.id,
        Action = "GetMove",
        Data = json.encode({id = 85}),
        Tags = {Action = "GetMove"}
      })

      CoordinationTesting.routeMessage(processes.battleEngine.id, {
        Target = processes.statCalc.id,
        Action = "CalculateStats",
        Data = json.encode({baseStats = {35, 55, 40, 50, 50, 90}}),
        Tags = {Action = "CalculateStats"}
      })
    end
  end

  return AdvancedBenchmarks.benchmarkFunction(
    "battleCoordination",
    battleCoordinationTest,
    {iterations = 100, warmup = 10}
  )
end

-- State management testing for battles
function BattleCoordinationTests.testBattleStateManagement()
  local initialBattleState = {
    battle = {
      battleId = "test_battle_coordination",
      turn = 1,
      participants = {
        player1 = {pokemon = {id = "pikachu_1", hp = 145}},
        player2 = {pokemon = {id = "charizard_1", hp = 153}}
      },
      status = "active"
    }
  }

  local stateUpdates = {
    {
      processId = "battleEngine",
      operation = function(state, data)
        state.battle.turn = state.battle.turn + 1
        state.battle.participants.player1.pokemon.hp =
          state.battle.participants.player1.pokemon.hp - 50
      end,
      data = {damage = 50, target = "player1"}
    },
    {
      processId = "statusEngine",
      operation = function(state, data)
        state.battle.participants.player1.pokemon.status = "poisoned"
      end,
      data = {statusEffect = "poison"}
    }
  }

  local processes = {
    battleEngine = {state = initialBattleState},
    statusEngine = {state = initialBattleState}
  }

  return StateManagement.testStateSynchronization(processes, stateUpdates)
end

-- Main test execution
local function runBattleEngineCoordinationTests()
  print("⚔️  Running Battle Engine Coordination Tests")
  print(string.rep("=", 60))

  local results = {}

  -- Basic coordination tests
  print("\n🎮 Basic Battle Coordination")
  results.basicTurnCoordination = BattleCoordinationTests.testBasicBattleTurnCoordination()

  print("\n💥 Damage Calculation Coordination")
  results.damageCoordination = BattleCoordinationTests.testDamageCalculationCoordination()

  print("\n🩹 Status Effect Coordination")
  results.statusCoordination = BattleCoordinationTests.testStatusEffectCoordination()

  print("\n🌟 Complex Battle Scenario")
  results.complexScenario = BattleCoordinationTests.testComplexBattleScenario()

  -- Performance benchmarks
  print("\n⚡ Performance Benchmarks")
  results.performanceBenchmark = BattleCoordinationTests.benchmarkBattleCoordination()

  -- State management testing
  print("\n🏛️  Battle State Management")
  results.stateManagement = BattleCoordinationTests.testBattleStateManagement()

  -- Generate summary
  local totalTests = 0
  local passedTests = 0

  for testName, result in pairs(results) do
    totalTests = totalTests + 1
    if result.success or result.passed or result.synchronizationSuccessful then
      passedTests = passedTests + 1
    end
  end

  print(string.rep("=", 60))
  print(string.format("📊 Battle Engine Coordination Summary: %d/%d tests passed",
    passedTests, totalTests))

  return results
end

-- Export test functions
return {
  runBattleEngineCoordinationTests = runBattleEngineCoordinationTests,
  BattleCoordinationTests = BattleCoordinationTests,
  createBattleEngineProcess = createBattleEngineProcess,
  createMoveDatabaseProcess = createMoveDatabaseProcess
}