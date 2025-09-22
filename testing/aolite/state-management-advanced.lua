#!/usr/bin/env lua

--[[
Advanced ECS State Management Testing Framework
Provides comprehensive state validation and consistency testing:
- ECS world state tracking and validation
- State persistence across process restarts
- Multi-process state synchronization testing
- State mutation detection and rollback
- Memory-efficient state comparison and diffing
]]

local StateManagementAdvanced = {}

-- State tracking configuration
local StateConfig = {
  enableSnapshots = true,
  maxSnapshots = 100,
  compressionEnabled = false,
  validationLevel = "strict", -- strict, normal, relaxed
  autoCleanup = true
}

-- State storage and tracking
local StateData = {
  snapshots = {},
  mutations = {},
  validationRules = {},
  stateHistory = {},
  currentSnapshot = nil
}

-- ECS world state structure
local function createEmptyWorldState()
  return {
    entities = {},
    components = {},
    systems = {},
    resources = {},
    metadata = {
      version = 1,
      timestamp = os.time(),
      entityCount = 0,
      componentCount = 0
    }
  }
end

-- State snapshot management
function StateManagementAdvanced.createSnapshot(worldState, label)
  label = label or string.format("snapshot_%d", os.time())
  
  local snapshot = {
    id = label,
    timestamp = os.time(),
    state = StateManagementAdvanced.deepCopy(worldState),
    checksum = StateManagementAdvanced.calculateChecksum(worldState),
    metadata = {
      entityCount = StateManagementAdvanced.countEntities(worldState),
      componentCount = StateManagementAdvanced.countComponents(worldState),
      memoryUsage = StateManagementAdvanced.estimateMemoryUsage(worldState)
    }
  }
  
  -- Store snapshot
  table.insert(StateData.snapshots, snapshot)
  StateData.currentSnapshot = snapshot
  
  -- Cleanup old snapshots if needed
  if StateConfig.autoCleanup and #StateData.snapshots > StateConfig.maxSnapshots then
    table.remove(StateData.snapshots, 1) -- Remove oldest
  end
  
  print(string.format("📸 Created state snapshot: %s (entities: %d, components: %d)", 
    label, snapshot.metadata.entityCount, snapshot.metadata.componentCount))
  
  return snapshot
end

-- Deep copy function for state preservation
function StateManagementAdvanced.deepCopy(original)
  if type(original) ~= "table" then
    return original
  end
  
  local copy = {}
  for key, value in pairs(original) do
    copy[StateManagementAdvanced.deepCopy(key)] = StateManagementAdvanced.deepCopy(value)
  end
  
  return copy
end

-- State checksum calculation for integrity verification
function StateManagementAdvanced.calculateChecksum(state)
  local function serializeValue(value, seen)
    seen = seen or {}
    
    if seen[value] then
      return "circular_ref"
    end
    
    local valueType = type(value)
    if valueType == "nil" then
      return "nil"
    elseif valueType == "boolean" then
      return tostring(value)
    elseif valueType == "number" then
      return string.format("%.10f", value)
    elseif valueType == "string" then
      return value
    elseif valueType == "table" then
      seen[value] = true
      local parts = {}
      for k, v in pairs(value) do
        table.insert(parts, string.format("%s:%s", 
          serializeValue(k, seen), serializeValue(v, seen)))
      end
      seen[value] = nil
      table.sort(parts)
      return "{" .. table.concat(parts, ",") .. "}"
    else
      return tostring(value)
    end
  end
  
  local serialized = serializeValue(state)
  
  -- Simple hash function (for demonstration - would use proper hash in production)
  local hash = 0
  for i = 1, #serialized do
    hash = (hash * 31 + string.byte(serialized, i)) % 2147483647
  end
  
  return hash
end

-- Entity and component counting
function StateManagementAdvanced.countEntities(worldState)
  if not worldState.entities then return 0 end
  
  local count = 0
  for _ in pairs(worldState.entities) do
    count = count + 1
  end
  return count
end

function StateManagementAdvanced.countComponents(worldState)
  if not worldState.components then return 0 end
  
  local count = 0
  for _, componentType in pairs(worldState.components) do
    if type(componentType) == "table" then
      for _ in pairs(componentType) do
        count = count + 1
      end
    end
  end
  return count
end

-- Memory usage estimation
function StateManagementAdvanced.estimateMemoryUsage(state)
  local function estimateSize(value, seen)
    seen = seen or {}
    
    if seen[value] then
      return 0 -- Avoid circular references
    end
    
    local valueType = type(value)
    if valueType == "nil" then
      return 0
    elseif valueType == "boolean" then
      return 1
    elseif valueType == "number" then
      return 8
    elseif valueType == "string" then
      return #value + 16
    elseif valueType == "table" then
      seen[value] = true
      local size = 16 -- Base table overhead
      for k, v in pairs(value) do
        size = size + estimateSize(k, seen) + estimateSize(v, seen) + 8 -- Entry overhead
      end
      seen[value] = nil
      return size
    else
      return 8 -- Default for unknown types
    end
  end
  
  return estimateSize(state)
end

-- State comparison and diffing
function StateManagementAdvanced.compareStates(state1, state2, path)
  path = path or "root"
  local differences = {}
  
  local function addDifference(diffPath, diffType, oldValue, newValue)
    table.insert(differences, {
      path = diffPath,
      type = diffType,
      oldValue = oldValue,
      newValue = newValue
    })
  end
  
  local function compareValues(v1, v2, currentPath)
    if type(v1) ~= type(v2) then
      addDifference(currentPath, "type_change", type(v1), type(v2))
      return
    end
    
    if type(v1) == "table" then
      -- Compare table contents
      local seen = {}
      
      for k, value1 in pairs(v1) do
        seen[k] = true
        local value2 = v2[k]
        if value2 == nil then
          addDifference(currentPath .. "." .. tostring(k), "removed", value1, nil)
        else
          compareValues(value1, value2, currentPath .. "." .. tostring(k))
        end
      end
      
      for k, value2 in pairs(v2) do
        if not seen[k] then
          addDifference(currentPath .. "." .. tostring(k), "added", nil, value2)
        end
      end
    else
      if v1 ~= v2 then
        addDifference(currentPath, "value_change", v1, v2)
      end
    end
  end
  
  compareValues(state1, state2, path)
  return differences
end

-- State validation rules
function StateManagementAdvanced.addValidationRule(ruleName, validator)
  StateData.validationRules[ruleName] = validator
  print(string.format("✅ Added validation rule: %s", ruleName))
end

function StateManagementAdvanced.validateState(worldState, rules)
  rules = rules or StateData.validationRules
  local validationResults = {}
  
  for ruleName, validator in pairs(rules) do
    local success, result = pcall(validator, worldState)
    validationResults[ruleName] = {
      passed = success and result,
      error = success and nil or result,
      ruleName = ruleName
    }
    
    if not (success and result) then
      print(string.format("❌ Validation failed: %s - %s", 
        ruleName, success and "Rule returned false" or result))
    end
  end
  
  return validationResults
end

-- Multi-process state synchronization testing
function StateManagementAdvanced.testStateSynchronization(processes, stateUpdates)
  print("🔄 Testing multi-process state synchronization")
  
  local syncResults = {
    processes = {},
    conflicts = {},
    resolutions = {},
    finalState = nil
  }
  
  -- Initialize process states
  for processId, process in pairs(processes) do
    process.state = StateManagementAdvanced.deepCopy(createEmptyWorldState())
    syncResults.processes[processId] = {
      initialChecksum = StateManagementAdvanced.calculateChecksum(process.state),
      updates = {},
      finalChecksum = nil
    }
  end
  
  -- Apply state updates sequentially
  for i, update in ipairs(stateUpdates) do
    local targetProcess = processes[update.processId]
    if targetProcess then
      -- Record update
      table.insert(syncResults.processes[update.processId].updates, {
        operation = update.operation,
        timestamp = os.time(),
        data = update.data
      })
      
      -- Apply update to process state
      local success, error = pcall(update.operation, targetProcess.state, update.data)
      if not success then
        table.insert(syncResults.conflicts, {
          processId = update.processId,
          updateIndex = i,
          error = error
        })
      end
    end
  end
  
  -- Calculate final checksums and detect conflicts
  local checksums = {}
  for processId, process in pairs(processes) do
    local finalChecksum = StateManagementAdvanced.calculateChecksum(process.state)
    syncResults.processes[processId].finalChecksum = finalChecksum
    
    if checksums[finalChecksum] then
      -- States match - good synchronization
    else
      checksums[finalChecksum] = processId
    end
  end
  
  local uniqueStates = 0
  for _ in pairs(checksums) do
    uniqueStates = uniqueStates + 1
  end
  
  syncResults.synchronizationSuccessful = uniqueStates == 1
  syncResults.uniqueStates = uniqueStates
  
  print(string.format("   Processes: %d", table.getn(processes)))
  print(string.format("   Updates: %d", #stateUpdates))
  print(string.format("   Conflicts: %d", #syncResults.conflicts))
  print(string.format("   Unique final states: %d", uniqueStates))
  print(string.format("   Synchronization: %s", 
    syncResults.synchronizationSuccessful and "✅ Success" or "❌ Failed"))
  
  return syncResults
end

-- State persistence testing
function StateManagementAdvanced.testStatePersistence(worldState, persistenceFunction, loadFunction)
  print("💾 Testing state persistence")
  
  local originalChecksum = StateManagementAdvanced.calculateChecksum(worldState)
  local originalSnapshot = StateManagementAdvanced.createSnapshot(worldState, "pre_persistence")
  
  -- Test persistence
  local persistenceStart = os.clock()
  local persistenceResult = persistenceFunction(worldState)
  local persistenceTime = os.clock() - persistenceStart
  
  -- Test loading
  local loadStart = os.clock()
  local loadedState = loadFunction()
  local loadTime = os.clock() - loadStart
  
  local loadedChecksum = StateManagementAdvanced.calculateChecksum(loadedState)
  local loadedSnapshot = StateManagementAdvanced.createSnapshot(loadedState, "post_persistence")
  
  -- Compare states
  local differences = StateManagementAdvanced.compareStates(worldState, loadedState)
  
  local persistenceTestResult = {
    originalChecksum = originalChecksum,
    loadedChecksum = loadedChecksum,
    checksumMatch = originalChecksum == loadedChecksum,
    differences = differences,
    persistenceTime = persistenceTime,
    loadTime = loadTime,
    totalTime = persistenceTime + loadTime,
    dataIntegrity = #differences == 0
  }
  
  print(string.format("   Persistence time: %.3fms", persistenceTime * 1000))
  print(string.format("   Load time: %.3fms", loadTime * 1000))
  print(string.format("   Checksum match: %s", 
    persistenceTestResult.checksumMatch and "✅ Yes" or "❌ No"))
  print(string.format("   Data integrity: %s (%d differences)", 
    persistenceTestResult.dataIntegrity and "✅ Preserved" or "❌ Corrupted", 
    #differences))
  
  return persistenceTestResult
end

-- State rollback testing
function StateManagementAdvanced.testStateRollback(worldState, mutationFunction, rollbackFunction)
  print("↩️  Testing state rollback")
  
  local preState = StateManagementAdvanced.createSnapshot(worldState, "pre_mutation")
  
  -- Apply mutations
  local mutationSuccess, mutationError = pcall(mutationFunction, worldState)
  local postMutationState = StateManagementAdvanced.createSnapshot(worldState, "post_mutation")
  
  -- Perform rollback
  local rollbackSuccess, rollbackError = pcall(rollbackFunction, worldState, preState.state)
  local postRollbackState = StateManagementAdvanced.createSnapshot(worldState, "post_rollback")
  
  -- Verify rollback
  local rollbackChecksum = StateManagementAdvanced.calculateChecksum(worldState)
  local rollbackSuccessful = rollbackChecksum == preState.checksum
  
  local rollbackResult = {
    mutationSuccessful = mutationSuccess,
    mutationError = mutationError,
    rollbackSuccessful = rollbackSuccess,
    rollbackError = rollbackError,
    stateRestored = rollbackSuccessful,
    preChecksum = preState.checksum,
    postRollbackChecksum = rollbackChecksum
  }
  
  print(string.format("   Mutation: %s", mutationSuccess and "✅ Success" or "❌ Failed"))
  print(string.format("   Rollback: %s", rollbackSuccess and "✅ Success" or "❌ Failed"))
  print(string.format("   State restored: %s", 
    rollbackResult.stateRestored and "✅ Yes" or "❌ No"))
  
  return rollbackResult
end

-- Configuration and utility functions
function StateManagementAdvanced.configure(config)
  for key, value in pairs(config) do
    StateConfig[key] = value
  end
  print("🔧 Advanced state management testing configured")
end

function StateManagementAdvanced.getSnapshotHistory()
  return StateData.snapshots
end

function StateManagementAdvanced.clearHistory()
  StateData.snapshots = {}
  StateData.mutations = {}
  StateData.stateHistory = {}
  print("🧹 State history cleared")
end

-- Export state management functions
StateManagementAdvanced.createEmptyWorld = createEmptyWorldState

return StateManagementAdvanced