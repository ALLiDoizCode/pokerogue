-- Unit tests for coordinator-process.lua using aolite framework

-- Mock aolite if not available
local aolite = package.loaded.aolite or {
  spawnProcess = function(code) 
    return { id = "test-process-" .. math.random(1000, 9999) }
  end,
  send = function(processId, action, data)
    return { success = true, response = data }
  end,
  eval = function(processId, code)
    return { success = true, result = "eval complete" }
  end
}

-- Set up AO environment before loading process
if not ao then
  ao = {
    send = function(msg) 
      print("Mock AO send:", json and json.encode(msg) or "no json")
    end,
    id = "coordinator-process"
  }
end

if not Handlers then
  Handlers = {
    add = function(name, matcher, handler)
      print("Handler registered:", name)
    end,
    utils = {
      hasMatchingTag = function(tag, value)
        return function(msg)
          return msg[tag] == value
        end
      end
    }
  }
end

if not json then
  json = {
    encode = function(t) return "mock_json" end,
    decode = function(s) return {} end
  }
end

-- Load coordinator process
local coordinator = dofile("processes/coordinator-process.lua")

-- Test suite for Coordinator Process
local function testCoordinatorProcess()
  local tests = {}
  
  -- Test 1: Initialize Coordinator
  tests["test_initialize_coordinator"] = function()
    local state = coordinator.initializeCoordinator()
    
    assert(state.processType == "coordinator", "Process type should be coordinator")
    assert(state.processId == "coordinator-process", "Process ID should be coordinator-process")
    assert(state.operationCount == 0, "Operation count should start at 0")
    assert(type(state.activeOperations) == "table", "Active operations should be a table")
    assert(type(state.timestamp) == "number", "Timestamp should be a number")
    
    print("✓ Initialize coordinator test passed")
    return true
  end
  
  -- Test 2: Generate Operation ID
  tests["test_generate_operation_id"] = function()
    local id1 = coordinator.generateOperationId()
    local id2 = coordinator.generateOperationId()
    
    assert(type(id1) == "string", "Operation ID should be a string")
    assert(string.match(id1, "^op_%d+_%d+$"), "Operation ID should match pattern op_timestamp_random")
    assert(id1 ~= id2, "Operation IDs should be unique")
    
    print("✓ Generate operation ID test passed")
    return true
  end
  
  -- Test 3: Create Operation
  tests["test_create_operation"] = function()
    local operationId = "test_op_123"
    local processTargets = {"battle-engine", "pokemon-species-db"}
    local requestData = {Action = "ProcessBattle", battleData = {}}
    
    local operation = coordinator.createOperation(operationId, processTargets, requestData)
    
    assert(operation.operationId == operationId, "Operation ID should match")
    assert(operation.status == coordinator.OPERATION_STATES.PENDING, "Initial status should be pending")
    assert(#operation.processTargets == 2, "Should have 2 process targets")
    assert(operation.processTargets[1] == "battle-engine", "First target should be battle-engine")
    assert(operation.processTargets[2] == "pokemon-species-db", "Second target should be pokemon-species-db")
    assert(type(operation.responseData) == "table", "Response data should be table")
    assert(type(operation.timestamp) == "number", "Timestamp should be number")
    assert(type(operation.timeout) == "number", "Timeout should be number")
    assert(#operation.completedProcesses == 0, "Completed processes should start empty")
    assert(#operation.failedProcesses == 0, "Failed processes should start empty")
    
    print("✓ Create operation test passed")
    return true
  end
  
  -- Test 4: Update Operation Status
  tests["test_update_operation_status"] = function()
    local operationId = "test_op_456"
    local processTargets = {"battle-engine"}
    local requestData = {Action = "ProcessBattle"}
    
    -- Create operation first
    local operation = coordinator.createOperation(operationId, processTargets, requestData)
    
    -- Test successful response
    local success = coordinator.updateOperationStatus(
      operationId, 
      coordinator.OPERATION_STATES.ACTIVE, 
      "battle-engine", 
      {result = "success"}, 
      nil
    )
    
    assert(success == true, "Update should succeed")
    
    local updatedOperation = coordinator.getOperation(operationId)
    assert(updatedOperation.status == coordinator.OPERATION_STATES.ACTIVE, "Status should be active")
    assert(#updatedOperation.completedProcesses == 1, "Should have 1 completed process")
    assert(updatedOperation.completedProcesses[1] == "battle-engine", "Completed process should be battle-engine")
    assert(updatedOperation.responseData["battle-engine"].result == "success", "Response data should be stored")
    
    print("✓ Update operation status test passed")
    return true
  end
  
  -- Test 5: Update Operation Status with Error
  tests["test_update_operation_status_error"] = function()
    local operationId = "test_op_789"
    local processTargets = {"invalid-process"}
    local requestData = {Action = "ProcessBattle"}
    
    -- Create operation first
    coordinator.createOperation(operationId, processTargets, requestData)
    
    -- Test error response
    local success = coordinator.updateOperationStatus(
      operationId,
      coordinator.OPERATION_STATES.FAILED,
      "invalid-process",
      nil,
      "Process not found"
    )
    
    assert(success == true, "Update should succeed")
    
    local updatedOperation = coordinator.getOperation(operationId)
    assert(updatedOperation.status == coordinator.OPERATION_STATES.FAILED, "Status should be failed")
    assert(#updatedOperation.failedProcesses == 1, "Should have 1 failed process")
    assert(updatedOperation.failedProcesses[1] == "invalid-process", "Failed process should be invalid-process")
    assert(updatedOperation.responseData["invalid-process"].error == "Process not found", "Error should be stored")
    
    print("✓ Update operation status error test passed")
    return true
  end
  
  -- Test 6: Get Process Address
  tests["test_get_process_address"] = function()
    -- Test coordinator address
    local coordAddress = coordinator.getProcessAddress("coordinator-process")
    assert(coordAddress == "TBD", "Coordinator address should be TBD (not deployed)")
    
    -- Test data process address
    local dataAddress = coordinator.getProcessAddress("pokemon-species-db")
    assert(dataAddress == "TBD", "Data process address should be TBD (not deployed)")
    
    -- Test logic process address
    local logicAddress = coordinator.getProcessAddress("battle-engine")
    assert(logicAddress == "TBD", "Logic process address should be TBD (not deployed)")
    
    -- Test invalid process
    local invalidAddress = coordinator.getProcessAddress("invalid-process")
    assert(invalidAddress == nil, "Invalid process should return nil")
    
    print("✓ Get process address test passed")
    return true
  end
  
  -- Test 7: Route Message
  tests["test_route_message"] = function()
    local processId = "battle-engine"
    local message = {
      Action = "ProcessBattle",
      Data = {battleData = {}},
      OperationId = "test_op_route"
    }
    
    local success, result = coordinator.routeMessage(processId, message)
    
    assert(success == true, "Routing should succeed for valid process")
    assert(result.Target == "TBD", "Target should be TBD (not deployed)")
    assert(result.Action == "ProcessBattle", "Action should be preserved")
    assert(result.OperationId == "test_op_route", "Operation ID should be preserved")
    assert(type(result.Timestamp) == "number", "Timestamp should be added")
    
    -- Test invalid process
    local failSuccess, failResult = coordinator.routeMessage("invalid-process", message)
    assert(failSuccess == false, "Routing should fail for invalid process")
    assert(type(failResult) == "string", "Error should be returned as string")
    
    print("✓ Route message test passed")
    return true
  end
  
  -- Test 8: Input Validation
  tests["test_input_validation"] = function()
    -- Test valid input
    local validMessage = {
      Action = "CoordinateOperation",
      Data = {ProcessTargets = {"battle-engine"}},
      Timestamp = os.time()
    }
    
    local valid, error = coordinator.validateInput(validMessage)
    assert(valid == true, "Valid message should pass validation")
    assert(error == nil, "No error should be returned for valid message")
    
    -- Test missing Action
    local invalidMessage1 = {
      Data = {ProcessTargets = {"battle-engine"}},
      Timestamp = os.time()
    }
    
    local valid1, error1 = coordinator.validateInput(invalidMessage1)
    assert(valid1 == false, "Message without Action should fail validation")
    assert(error1 == "Action field is required", "Should return Action required error")
    
    -- Test missing Data
    local invalidMessage2 = {
      Action = "CoordinateOperation",
      Timestamp = os.time()
    }
    
    local valid2, error2 = coordinator.validateInput(invalidMessage2)
    assert(valid2 == false, "Message without Data should fail validation")
    assert(error2 == "Data field is required", "Should return Data required error")
    
    -- Test missing Timestamp
    local invalidMessage3 = {
      Action = "CoordinateOperation",
      Data = {ProcessTargets = {"battle-engine"}}
    }
    
    local valid3, error3 = coordinator.validateInput(invalidMessage3)
    assert(valid3 == false, "Message without Timestamp should fail validation")
    assert(error3 == "Timestamp field is required", "Should return Timestamp required error")
    
    print("✓ Input validation test passed")
    return true
  end
  
  -- Test 9: Health Check
  tests["test_health_check"] = function()
    local healthData = coordinator.performHealthCheck()
    
    assert(healthData.processId == "coordinator-process", "Process ID should be coordinator-process")
    assert(healthData.status == "healthy", "Status should be healthy")
    assert(type(healthData.timestamp) == "number", "Timestamp should be number")
    assert(type(healthData.activeOperations) == "number", "Active operations should be number")
    assert(type(healthData.timedOutOperations) == "number", "Timed out operations should be number")
    assert(type(healthData.processTopology) == "table", "Process topology should be table")
    assert(healthData.processTopology.coordinator == 1, "Should have 1 coordinator")
    assert(healthData.processTopology.dataProcesses == 8, "Should have 8 data processes")
    assert(healthData.processTopology.logicProcesses == 12, "Should have 12 logic processes")
    assert(healthData.processTopology.specializedProcesses == 5, "Should have 5 specialized processes")
    assert(healthData.processTopology.totalProcesses == 26, "Should have 26 total processes")
    
    print("✓ Health check test passed")
    return true
  end
  
  -- Test 10: Operation States Constants
  tests["test_operation_states"] = function()
    assert(coordinator.OPERATION_STATES.PENDING == "pending", "PENDING state should be 'pending'")
    assert(coordinator.OPERATION_STATES.ACTIVE == "active", "ACTIVE state should be 'active'")
    assert(coordinator.OPERATION_STATES.COMPLETED == "completed", "COMPLETED state should be 'completed'")
    assert(coordinator.OPERATION_STATES.FAILED == "failed", "FAILED state should be 'failed'")
    assert(coordinator.OPERATION_STATES.TIMEOUT == "timeout", "TIMEOUT state should be 'timeout'")
    
    print("✓ Operation states test passed")
    return true
  end
  
  return tests
end

-- Run all tests
local function runTests()
  print("Running Coordinator Process Unit Tests...")
  print("=" .. string.rep("=", 50))
  
  local tests = testCoordinatorProcess()
  local passed = 0
  local failed = 0
  
  for testName, testFunc in pairs(tests) do
    print("\nRunning: " .. testName)
    
    local success, error = pcall(testFunc)
    if success then
      passed = passed + 1
    else
      failed = failed + 1
      print("✗ " .. testName .. " FAILED: " .. tostring(error))
    end
  end
  
  print("\n" .. string.rep("=", 50))
  print("Test Results:")
  print("  Passed: " .. passed)
  print("  Failed: " .. failed)
  print("  Total:  " .. (passed + failed))
  
  if failed == 0 then
    print("\n🎉 All tests passed!")
    return true
  else
    print("\n❌ Some tests failed!")
    return false
  end
end

-- Export for aolite framework
return {
  runTests = runTests,
  testCoordinatorProcess = testCoordinatorProcess
}