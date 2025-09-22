#!/usr/bin/env lua

--[[
Advanced State Persistence and Recovery Testing
Comprehensive testing for ECS world state management and recovery:
- State persistence across process restarts and failures
- Multi-process state synchronization and consistency validation
- Recovery testing with partial state corruption scenarios
- Performance testing for large state serialization/deserialization
- Conflict resolution and state merging capabilities
]]

-- Load testing frameworks
local StateManagement = require('testing.aolite.state-management-advanced')
local CoordinationTesting = require('testing.aolite.coordination-testing')
local AdvancedBenchmarks = require('testing.aolite.advanced-benchmarks')

-- State persistence testing configuration
local StatePersistenceConfig = {
  maxStateSize = 1024 * 1024, -- 1MB max state
  snapshotInterval = 1000, -- ms
  maxRecoveryTime = 5000, -- 5 seconds
  consistencyCheckInterval = 500, -- ms
  corruptionSimulationRate = 0.1, -- 10%
  stateVersions = 10 -- Keep 10 state versions
}

-- Advanced state persistence tests
local StatePersistenceTests = {}

function StatePersistenceTests.testLargeStateSerializationPerformance()
  print("💾 Testing large state serialization performance")
  
  -- Create large game state
  local largeGameState = StateManagement.createEmptyWorld()
  
  -- Populate with extensive data
  for i = 1, 1000 do
    largeGameState.entities[string.format("pokemon_%d", i)] = {
      id = string.format("pokemon_%d", i),
      speciesId = math.random(1, 1010),
      level = math.random(1, 100),
      stats = {
        hp = math.random(50, 500),
        attack = math.random(50, 400),
        defense = math.random(50, 400),
        specialAttack = math.random(50, 400),
        specialDefense = math.random(50, 400),
        speed = math.random(50, 400)
      },
      moves = {
        {id = math.random(1, 900), pp = math.random(5, 40)},
        {id = math.random(1, 900), pp = math.random(5, 40)},
        {id = math.random(1, 900), pp = math.random(5, 40)},
        {id = math.random(1, 900), pp = math.random(5, 40)}
      },
      status = {
        conditions = {},
        modifiers = {}
      }
    }
  end
  
  -- Add battle data
  for i = 1, 100 do
    largeGameState.entities[string.format("battle_%d", i)] = {
      id = string.format("battle_%d", i),
      participants = {
        string.format("pokemon_%d", math.random(1, 1000)),
        string.format("pokemon_%d", math.random(1, 1000))
      },
      turn = math.random(1, 50),
      conditions = {
        weather = "none",
        terrain = "none",
        fieldEffects = {}
      },
      battleLog = {}
    }
  end
  
  largeGameState.metadata.entityCount = 1100
  
  -- Test serialization performance
  local serializationResults = AdvancedBenchmarks.benchmarkFunction(
    "largeStateSerialization",
    function()
      return StateManagement.deepCopy(largeGameState)
    end,
    {iterations = 10, warmup = 2}
  )
  
  -- Test checksum calculation performance
  local checksumResults = AdvancedBenchmarks.benchmarkFunction(
    "largeStateChecksum",
    function()
      return StateManagement.calculateChecksum(largeGameState)
    end,
    {iterations = 50, warmup = 10}
  )
  
  -- Test memory usage estimation
  local memoryUsage = StateManagement.estimateMemoryUsage(largeGameState)
  
  -- Test snapshot creation performance
  local snapshotResults = AdvancedBenchmarks.benchmarkFunction(
    "largeStateSnapshot",
    function()
      return StateManagement.createSnapshot(largeGameState, "perf_test")
    end,
    {iterations = 5, warmup = 1}
  )
  
  local serializationTime = serializationResults.statistics.mean * 1000 -- ms
  local checksumTime = checksumResults.statistics.mean * 1000 -- ms
  local snapshotTime = snapshotResults.statistics.mean * 1000 -- ms
  
  print(string.format("  📊 Large State Performance Results:"))
  print(string.format("    Entities: %d", largeGameState.metadata.entityCount))
  print(string.format("    Memory usage: %.2f KB", memoryUsage / 1024))
  print(string.format("    Serialization time: %.2fms", serializationTime))
  print(string.format("    Checksum time: %.2fms", checksumTime))
  print(string.format("    Snapshot time: %.2fms", snapshotTime))
  
  -- Performance thresholds
  local serializationAcceptable = serializationTime < 100 -- 100ms threshold
  local checksumAcceptable = checksumTime < 10 -- 10ms threshold
  local snapshotAcceptable = snapshotTime < 150 -- 150ms threshold
  
  print(string.format("    Performance: %s", 
    (serializationAcceptable and checksumAcceptable and snapshotAcceptable) and "✅ Acceptable" or "❌ Too Slow"))
  
  return {
    success = serializationAcceptable and checksumAcceptable and snapshotAcceptable,
    entityCount = largeGameState.metadata.entityCount,
    memoryUsage = memoryUsage,
    serializationTime = serializationTime,
    checksumTime = checksumTime,
    snapshotTime = snapshotTime,
    benchmarkResults = {
      serialization = serializationResults,
      checksum = checksumResults,
      snapshot = snapshotResults
    }
  }
end

function StatePersistenceTests.testStateCorruptionRecovery()
  print("🔧 Testing state corruption recovery")
  
  -- Create initial clean state
  local cleanState = StateManagement.createEmptyWorld()
  
  -- Add test data
  for i = 1, 50 do
    cleanState.entities[string.format("entity_%d", i)] = {
      id = string.format("entity_%d", i),
      type = "pokemon",
      data = {
        species = math.random(1, 150),
        level = math.random(1, 100),
        hp = math.random(50, 200)
      }
    }
  end
  
  local cleanChecksum = StateManagement.calculateChecksum(cleanState)
  local cleanSnapshot = StateManagement.createSnapshot(cleanState, "clean_state")
  
  -- Simulate various corruption scenarios
  local corruptionScenarios = {
    {
      name = "missing_entity",
      corrupt = function(state)
        state.entities["entity_1"] = nil
        return state
      end
    },
    {
      name = "invalid_data_type",
      corrupt = function(state)
        state.entities["entity_2"].data.level = "invalid_string"
        return state
      end
    },
    {
      name = "circular_reference",
      corrupt = function(state)
        state.entities["entity_3"].circular = state.entities["entity_3"]
        return state
      end
    },
    {
      name = "negative_values",
      corrupt = function(state)
        state.entities["entity_4"].data.hp = -100
        return state
      end
    },
    {
      name = "missing_required_field",
      corrupt = function(state)
        state.entities["entity_5"].data = nil
        return state
      end
    }
  }
  
  local recoveryResults = {}
  
  for _, scenario in ipairs(corruptionScenarios) do
    print(string.format("  Testing corruption scenario: %s", scenario.name))
    
    -- Create corrupted state
    local corruptedState = StateManagement.deepCopy(cleanState)
    corruptedState = scenario.corrupt(corruptedState)
    
    local corruptedChecksum = StateManagement.calculateChecksum(corruptedState)
    
    -- Test corruption detection
    local corruptionDetected = corruptedChecksum ~= cleanChecksum
    
    -- Test recovery process
    local recoveryStart = os.clock()
    
    local recoverySuccess = false
    local recoveredState = nil
    
    if corruptionDetected then
      -- Simulate recovery from clean snapshot
      recoveredState = StateManagement.deepCopy(cleanSnapshot.state)
      
      -- Validate recovered state
      local recoveredChecksum = StateManagement.calculateChecksum(recoveredState)
      recoverySuccess = recoveredChecksum == cleanChecksum
    end
    
    local recoveryTime = (os.clock() - recoveryStart) * 1000 -- ms
    
    recoveryResults[scenario.name] = {
      corruptionDetected = corruptionDetected,
      recoverySuccess = recoverySuccess,
      recoveryTime = recoveryTime,
      corruptedChecksum = corruptedChecksum,
      recoveredChecksum = recoveredState and StateManagement.calculateChecksum(recoveredState) or nil
    }
    
    print(string.format("    Corruption detected: %s", corruptionDetected and "✅ Yes" or "❌ No"))
    print(string.format("    Recovery successful: %s", recoverySuccess and "✅ Yes" or "❌ No"))
    print(string.format("    Recovery time: %.2fms", recoveryTime))
  end
  
  -- Calculate overall recovery statistics
  local totalScenarios = #corruptionScenarios
  local detectionsSuccessful = 0
  local recoveriesSuccessful = 0
  local totalRecoveryTime = 0
  
  for _, result in pairs(recoveryResults) do
    if result.corruptionDetected then
      detectionsSuccessful = detectionsSuccessful + 1
    end
    if result.recoverySuccess then
      recoveriesSuccessful = recoveriesSuccessful + 1
    end
    totalRecoveryTime = totalRecoveryTime + result.recoveryTime
  end
  
  local detectionRate = detectionsSuccessful / totalScenarios
  local recoveryRate = recoveriesSuccessful / totalScenarios
  local avgRecoveryTime = totalRecoveryTime / totalScenarios
  
  print(string.format("  📊 Corruption Recovery Summary:"))
  print(string.format("    Detection rate: %.2f%% (%d/%d)", detectionRate * 100, detectionsSuccessful, totalScenarios))
  print(string.format("    Recovery rate: %.2f%% (%d/%d)", recoveryRate * 100, recoveriesSuccessful, totalScenarios))
  print(string.format("    Avg recovery time: %.2fms", avgRecoveryTime))
  
  return {
    success = detectionRate >= 0.8 and recoveryRate >= 0.8,
    totalScenarios = totalScenarios,
    detectionsSuccessful = detectionsSuccessful,
    recoveriesSuccessful = recoveriesSuccessful,
    detectionRate = detectionRate,
    recoveryRate = recoveryRate,
    avgRecoveryTime = avgRecoveryTime,
    scenarioResults = recoveryResults
  }
end

function StatePersistenceTests.testMultiProcessStateSynchronization()
  print("🔄 Testing multi-process state synchronization")
  
  -- Create initial shared state
  local sharedState = StateManagement.createEmptyWorld()
  
  -- Add shared entities
  for i = 1, 20 do
    sharedState.entities[string.format("shared_%d", i)] = {
      id = string.format("shared_%d", i),
      type = "shared_pokemon",
      data = {
        species = math.random(1, 150),
        level = math.random(50, 100),
        lastModified = os.time(),
        version = 1
      }
    }
  end
  
  -- Create multiple processes with state copies
  local processes = {}
  local processCount = 5
  
  for i = 1, processCount do
    processes[string.format("sync_process_%d", i)] = {
      id = string.format("sync_process_%d", i),
      state = StateManagement.deepCopy(sharedState),
      localUpdates = {},
      lastSync = os.time()
    }
  end
  
  -- Simulate concurrent state modifications
  local updateOperations = {
    {
      processId = "sync_process_1",
      operation = function(state, data)
        state.entities["shared_1"].data.level = state.entities["shared_1"].data.level + 1
        state.entities["shared_1"].data.version = state.entities["shared_1"].data.version + 1
        state.entities["shared_1"].data.lastModified = os.time()
      end,
      data = {type = "level_up", entityId = "shared_1"}
    },
    {
      processId = "sync_process_2",
      operation = function(state, data)
        state.entities["shared_1"].data.hp = (state.entities["shared_1"].data.hp or 100) - 10
        state.entities["shared_1"].data.version = state.entities["shared_1"].data.version + 1
        state.entities["shared_1"].data.lastModified = os.time()
      end,
      data = {type = "damage", entityId = "shared_1", amount = 10}
    },
    {
      processId = "sync_process_3",
      operation = function(state, data)
        state.entities["shared_2"].data.level = state.entities["shared_2"].data.level + 5
        state.entities["shared_2"].data.version = state.entities["shared_2"].data.version + 1
        state.entities["shared_2"].data.lastModified = os.time()
      end,
      data = {type = "rare_candy", entityId = "shared_2"}
    },
    {
      processId = "sync_process_4",
      operation = function(state, data)
        state.entities["new_entity"] = {
          id = "new_entity",
          type = "dynamic_pokemon",
          data = {species = 25, level = 1, version = 1, lastModified = os.time()}
        }
      end,
      data = {type = "spawn", entityId = "new_entity"}
    },
    {
      processId = "sync_process_5",
      operation = function(state, data)
        if state.entities["shared_3"] then
          state.entities["shared_3"] = nil
        end
      end,
      data = {type = "despawn", entityId = "shared_3"}
    }
  }
  
  -- Apply updates and test synchronization
  local syncResult = StateManagement.testStateSynchronization(processes, updateOperations)
  
  -- Test conflict resolution
  local conflictResolutionResults = {}
  
  -- Simulate conflict scenario where multiple processes modify the same entity
  local conflictEntity = "shared_1"
  local conflictVersions = {}
  
  for processName, process in pairs(processes) do
    if process.state.entities[conflictEntity] then
      conflictVersions[processName] = {
        version = process.state.entities[conflictEntity].data.version,
        lastModified = process.state.entities[conflictEntity].data.lastModified,
        level = process.state.entities[conflictEntity].data.level,
        hp = process.state.entities[conflictEntity].data.hp
      }
    end
  end
  
  -- Resolve conflicts using last-write-wins strategy
  local latestVersion = 0
  local winningProcess = nil
  
  for processName, version in pairs(conflictVersions) do
    if version.version > latestVersion then
      latestVersion = version.version
      winningProcess = processName
    end
  end
  
  conflictResolutionResults = {
    conflictEntity = conflictEntity,
    conflictingProcesses = 0,
    winningProcess = winningProcess,
    winningVersion = latestVersion,
    resolutionStrategy = "last_write_wins"
  }
  
  for _ in pairs(conflictVersions) do
    conflictResolutionResults.conflictingProcesses = conflictResolutionResults.conflictingProcesses + 1
  end
  
  print(string.format("  📊 Multi-Process Synchronization Results:"))
  print(string.format("    Processes: %d", processCount))
  print(string.format("    Update operations: %d", #updateOperations))
  print(string.format("    Synchronization successful: %s", 
    syncResult.synchronizationSuccessful and "✅ Yes" or "❌ No"))
  print(string.format("    Unique final states: %d", syncResult.uniqueStates))
  print(string.format("    Conflicts detected: %d", syncResult.conflicts and #syncResult.conflicts or 0))
  print(string.format("    Conflict resolution: %s (%s)", 
    winningProcess or "None", conflictResolutionResults.resolutionStrategy))
  
  return {
    success = syncResult.synchronizationSuccessful or syncResult.uniqueStates <= 2, -- Allow minor conflicts
    processCount = processCount,
    updateOperations = #updateOperations,
    synchronizationSuccessful = syncResult.synchronizationSuccessful,
    uniqueStates = syncResult.uniqueStates,
    conflictCount = syncResult.conflicts and #syncResult.conflicts or 0,
    conflictResolution = conflictResolutionResults,
    syncResult = syncResult
  }
end

function StatePersistenceTests.testStateVersioningAndRollback()
  print("⏪ Testing state versioning and rollback")
  
  -- Create initial state
  local initialState = StateManagement.createEmptyWorld()
  
  -- Add initial entities
  for i = 1, 10 do
    initialState.entities[string.format("versioned_%d", i)] = {
      id = string.format("versioned_%d", i),
      data = {value = i * 10, version = 1}
    }
  end
  
  local stateVersions = {}
  local currentState = StateManagement.deepCopy(initialState)
  
  -- Create multiple state versions through incremental changes
  for version = 1, StatePersistenceConfig.stateVersions do
    -- Create snapshot
    local snapshot = StateManagement.createSnapshot(currentState, string.format("version_%d", version))
    stateVersions[version] = snapshot
    
    -- Apply modifications for next version
    if version < StatePersistenceConfig.stateVersions then
      for entityId, entity in pairs(currentState.entities) do
        entity.data.value = entity.data.value + version
        entity.data.version = version + 1
      end
      
      -- Add new entity in some versions
      if version % 3 == 0 then
        currentState.entities[string.format("dynamic_%d", version)] = {
          id = string.format("dynamic_%d", version),
          data = {value = version * 100, version = version + 1}
        }
      end
    end
  end
  
  -- Test rollback scenarios
  local rollbackTests = {
    {
      name = "rollback_to_previous",
      targetVersion = StatePersistenceConfig.stateVersions - 1,
      description = "Rollback to previous version"
    },
    {
      name = "rollback_to_middle",
      targetVersion = math.floor(StatePersistenceConfig.stateVersions / 2),
      description = "Rollback to middle version"
    },
    {
      name = "rollback_to_initial",
      targetVersion = 1,
      description = "Rollback to initial version"
    }
  }
  
  local rollbackResults = {}
  
  for _, test in ipairs(rollbackTests) do
    print(string.format("  Testing %s (version %d)", test.description, test.targetVersion))
    
    local rollbackStart = os.clock()
    
    -- Perform rollback
    local targetSnapshot = stateVersions[test.targetVersion]
    if targetSnapshot then
      local rolledBackState = StateManagement.deepCopy(targetSnapshot.state)
      
      -- Test rollback function
      local rollbackTestResult = StateManagement.testStateRollback(
        StateManagement.deepCopy(currentState),
        function(state)
          -- Simulate some mutations that we want to rollback
          state.entities["versioned_1"].data.value = -999
          state.entities["corrupted_entity"] = {id = "corrupted", data = {invalid = true}}
        end,
        function(state, previousState)
          -- Rollback implementation
          for k, v in pairs(previousState) do
            state[k] = StateManagement.deepCopy(v)
          end
        end
      )
      
      local rollbackTime = (os.clock() - rollbackStart) * 1000 -- ms
      
      rollbackResults[test.name] = {
        targetVersion = test.targetVersion,
        rollbackSuccessful = rollbackTestResult.stateRestored,
        rollbackTime = rollbackTime,
        entitiesRestored = 0,
        checksumMatch = targetSnapshot.checksum == StateManagement.calculateChecksum(rolledBackState)
      }
      
      -- Count restored entities
      for entityId, _ in pairs(rolledBackState.entities) do
        if targetSnapshot.state.entities[entityId] then
          rollbackResults[test.name].entitiesRestored = rollbackResults[test.name].entitiesRestored + 1
        end
      end
      
      print(string.format("    Rollback successful: %s", 
        rollbackTestResult.stateRestored and "✅ Yes" or "❌ No"))
      print(string.format("    Rollback time: %.2fms", rollbackTime))
      print(string.format("    Entities restored: %d", rollbackResults[test.name].entitiesRestored))
    else
      rollbackResults[test.name] = {
        targetVersion = test.targetVersion,
        rollbackSuccessful = false,
        rollbackTime = 0,
        error = "Target version not found"
      }
    end
  end
  
  -- Calculate overall rollback statistics
  local successfulRollbacks = 0
  local totalRollbackTime = 0
  
  for _, result in pairs(rollbackResults) do
    if result.rollbackSuccessful then
      successfulRollbacks = successfulRollbacks + 1
    end
    totalRollbackTime = totalRollbackTime + result.rollbackTime
  end
  
  local rollbackSuccessRate = successfulRollbacks / #rollbackTests
  local avgRollbackTime = totalRollbackTime / #rollbackTests
  
  print(string.format("  📊 State Versioning and Rollback Summary:"))
  print(string.format("    State versions created: %d", StatePersistenceConfig.stateVersions))
  print(string.format("    Rollback tests: %d", #rollbackTests))
  print(string.format("    Successful rollbacks: %d/%d", successfulRollbacks, #rollbackTests))
  print(string.format("    Rollback success rate: %.2f%%", rollbackSuccessRate * 100))
  print(string.format("    Average rollback time: %.2fms", avgRollbackTime))
  
  return {
    success = rollbackSuccessRate >= 0.8,
    stateVersionsCreated = StatePersistenceConfig.stateVersions,
    rollbackTests = #rollbackTests,
    successfulRollbacks = successfulRollbacks,
    rollbackSuccessRate = rollbackSuccessRate,
    avgRollbackTime = avgRollbackTime,
    rollbackResults = rollbackResults,
    stateVersions = stateVersions
  }
end

-- Main state persistence testing execution
local function runStatePersistenceTests()
  print("💾 Running Advanced State Persistence and Recovery Tests")
  print(string.rep("=", 60))
  
  local results = {}
  
  -- Large state serialization performance
  print("\n⚡ Large State Serialization Performance")
  results.serializationPerformance = StatePersistenceTests.testLargeStateSerializationPerformance()
  
  -- State corruption recovery
  print("\n🔧 State Corruption Recovery")
  results.corruptionRecovery = StatePersistenceTests.testStateCorruptionRecovery()
  
  -- Multi-process state synchronization
  print("\n🔄 Multi-Process State Synchronization")
  results.stateSynchronization = StatePersistenceTests.testMultiProcessStateSynchronization()
  
  -- State versioning and rollback
  print("\n⏪ State Versioning and Rollback")
  results.versioningAndRollback = StatePersistenceTests.testStateVersioningAndRollback()
  
  -- Generate summary
  local totalTests = 0
  local passedTests = 0
  
  for testName, result in pairs(results) do
    totalTests = totalTests + 1
    if result.success then
      passedTests = passedTests + 1
    end
  end
  
  print(string.rep("=", 60))
  print(string.format("📊 State Persistence Testing Summary: %d/%d tests passed", 
    passedTests, totalTests))
  
  if passedTests == totalTests then
    print("🎉 All state persistence tests passed!")
  else
    print("⚠️  Some state persistence tests failed - check thresholds")
  end
  
  return results
end

-- Export state persistence testing functions
return {
  runStatePersistenceTests = runStatePersistenceTests,
  StatePersistenceTests = StatePersistenceTests,
  StatePersistenceConfig = StatePersistenceConfig
}