-- ============================================================================
-- Coordinator Process - Primary orchestration process for async workflow coordination
-- AO Process Implementation for PokéRogue
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or {
  encode = function(t) return "encoded_json" end,
  decode = function(s) return {} end
}

local ao = ao or {
  send = function(msg) 
    -- Mock implementation for testing
    return true 
  end,
  id = "coordinator-process"
}

-- Process topology configuration
local function loadTopology()
  local success, result = pcall(dofile, "processes/topology-config.lua")
  if success and result then
    return result
  end
  
  -- Fallback topology if file not found
  return {
  coordinator = {
    ProcessType = "coordinator",
    ProcessId = "coordinator-process", 
    Address = "TBD"
  },
  data = {
    { ProcessType = "data", ProcessId = "pokemon-species-db", Address = "TBD" },
    { ProcessType = "data", ProcessId = "moves-database", Address = "TBD" },
    { ProcessType = "data", ProcessId = "items-database", Address = "TBD" },
    { ProcessType = "data", ProcessId = "abilities-database", Address = "TBD" }
  },
  logic = {
    { ProcessType = "logic", ProcessId = "battle-engine", Address = "TBD" },
    { ProcessType = "logic", ProcessId = "evolution-engine", Address = "TBD" },
    { ProcessType = "logic", ProcessId = "capture-engine", Address = "TBD" },
    { ProcessType = "logic", ProcessId = "status-effects-engine", Address = "TBD" }
  }
  }
end

local TOPOLOGY = loadTopology()

-- Operation state management
local operations = {}
local OPERATION_TIMEOUT = 30000 -- 30 seconds in milliseconds

-- Operation state lifecycle: pending → active → completed
local OPERATION_STATES = {
  PENDING = "pending",
  ACTIVE = "active", 
  COMPLETED = "completed",
  FAILED = "failed",
  TIMEOUT = "timeout"
}

-- Initialize coordinator process
local function initializeCoordinator()
  return {
    processType = "coordinator",
    processId = "coordinator-process",
    operationCount = 0,
    activeOperations = {},
    timestamp = os.time()
  }
end

-- Generate unique operation ID
local function generateOperationId()
  local timestamp = tostring(os.time())
  local random = tostring(math.random(1000, 9999))
  return "op_" .. timestamp .. "_" .. random
end

-- Operation state management functions
local function createOperation(operationId, processTargets, requestData)
  operations[operationId] = {
    operationId = operationId,
    status = OPERATION_STATES.PENDING,
    processTargets = processTargets,
    requestData = requestData,
    responseData = {},
    timestamp = os.time(),
    timeout = os.time() + (OPERATION_TIMEOUT / 1000),
    completedProcesses = {},
    failedProcesses = {}
  }
  return operations[operationId]
end

local function updateOperationStatus(operationId, status, processId, responseData, error)
  if not operations[operationId] then
    return false
  end
  
  local operation = operations[operationId]
  
  if processId and responseData then
    operation.responseData[processId] = responseData
    table.insert(operation.completedProcesses, processId)
  elseif processId and error then
    table.insert(operation.failedProcesses, processId)
    operation.responseData[processId] = { error = error }
  end
  
  -- Update overall operation status
  if status then
    operation.status = status
  end
  
  return true
end

local function getOperation(operationId)
  return operations[operationId]
end

-- Check for timed out operations
local function checkOperationTimeouts()
  local currentTime = os.time()
  local timedOutOperations = {}
  
  for operationId, operation in pairs(operations) do
    if operation.status == OPERATION_STATES.ACTIVE and currentTime > operation.timeout then
      operation.status = OPERATION_STATES.TIMEOUT
      table.insert(timedOutOperations, operationId)
    end
  end
  
  return timedOutOperations
end

-- Process discovery and routing functions
local function getProcessAddress(processId)
  -- Check coordinator
  if TOPOLOGY.coordinator.ProcessId == processId then
    return TOPOLOGY.coordinator.Address
  end
  
  -- Check data processes
  for _, process in ipairs(TOPOLOGY.data) do
    if process.ProcessId == processId then
      return process.Address
    end
  end
  
  -- Check logic processes  
  for _, process in ipairs(TOPOLOGY.logic) do
    if process.ProcessId == processId then
      return process.Address
    end
  end
  
  -- Check specialized processes
  for _, process in ipairs(TOPOLOGY.specialized) do
    if process.ProcessId == processId then
      return process.Address
    end
  end
  
  return nil
end

-- Route message to target process
local function routeMessage(processId, message)
  local address = getProcessAddress(processId)
  if not address then
    return false, "Process address not found or not configured: " .. processId
  end
  
  -- In real AO environment, this would use ao.send()
  -- For now, we simulate the routing
  local routedMessage = {
    Target = address,
    Action = message.Action,
    Data = message.Data,
    OperationId = message.OperationId,
    Timestamp = os.time()
  }
  
  return true, routedMessage
end

-- Input validation function
local function validateInput(message)
  if not message then
    return false, "Message is required"
  end
  
  if not message.Action then
    return false, "Action field is required"
  end
  
  if not message.Data then
    return false, "Data field is required"
  end
  
  if not message.Timestamp then
    return false, "Timestamp field is required"  
  end
  
  return true, nil
end

-- Health check function
local function performHealthCheck()
  local timedOutOperations = checkOperationTimeouts()
  
  return {
    processId = "coordinator-process",
    status = "healthy",
    timestamp = os.time(),
    activeOperations = #operations,
    timedOutOperations = #timedOutOperations,
    processTopology = {
      coordinator = 1,
      dataProcesses = #TOPOLOGY.data,
      logicProcesses = #TOPOLOGY.logic,
      specializedProcesses = #TOPOLOGY.specialized,
      totalProcesses = 1 + #TOPOLOGY.data + #TOPOLOGY.logic + #TOPOLOGY.specialized
    }
  }
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Coordinate Operation Handler
Handlers.add("coordinate-operation",
    Handlers.utils.hasMatchingTag("Action", "CoordinateOperation"),
    function(msg)
  local valid, error = validateInput(msg)
  if not valid then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = error,
      ProcessId = ao.id,
      Timestamp = os.time()
    })
    return
  end
  
  local data = msg.Data
  if not data.ProcessTargets or not data.RequestData then
    ao.send({
      Target = msg.From,
      Action = "SaveState", 
      Error = "ProcessTargets and RequestData are required",
      ProcessId = ao.id,
      Timestamp = os.time()
    })
    return
  end
  
  -- Generate operation ID
  local operationId = generateOperationId()
  
  -- Create operation state
  local operation = createOperation(operationId, data.ProcessTargets, data.RequestData)
  operation.status = OPERATION_STATES.ACTIVE
  
  -- Route messages to target processes
  local routingResults = {}
  for _, processId in ipairs(data.ProcessTargets) do
    local success, result = routeMessage(processId, {
      Action = data.RequestData.Action or "ProcessRequest",
      Data = data.RequestData,
      OperationId = operationId
    })
    
    if success then
      table.insert(routingResults, {
        processId = processId,
        status = "routed",
        message = result
      })
    else
      table.insert(routingResults, {
        processId = processId, 
        status = "failed",
        error = result
      })
      table.insert(operation.failedProcesses, processId)
    end
  end
  
  -- Send response
  ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = {
      operationId = operationId,
      status = operation.status,
      routingResults = routingResults,
      processTargets = data.ProcessTargets
    },
    ProcessId = ao.id,
    Timestamp = os.time()
  })
    end
)

-- Operation Status Query Handler
Handlers.add("query-operation-status",
    Handlers.utils.hasMatchingTag("Action", "QueryOperationStatus"),
    function(msg)
  local valid, error = validateInput(msg)
  if not valid then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = error,
      ProcessId = ao.id, 
      Timestamp = os.time()
    })
    return
  end
  
  local operationId = msg.Data.OperationId
  if not operationId then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = "OperationId is required",
      ProcessId = ao.id,
      Timestamp = os.time()
    })
    return
  end
  
  local operation = getOperation(operationId)
  if not operation then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = "Operation not found: " .. operationId,
      ProcessId = ao.id,
      Timestamp = os.time()
    })
    return
  end
  
  ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = operation,
    ProcessId = ao.id,
    Timestamp = os.time()
  })
    end
)

-- Health Check Handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
  local healthData = performHealthCheck()
  
  ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = healthData,
    ProcessId = ao.id,
    Timestamp = os.time()
  })
    end
)

-- Process Response Handler (receives responses from other processes)
Handlers.add("process-response",
    Handlers.utils.hasMatchingTag("Action", "ProcessResponse"),
    function(msg)
  local valid, error = validateInput(msg)
  if not valid then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = error,
      ProcessId = ao.id,
      Timestamp = os.time()
    })
    return
  end
  
  local data = msg.Data
  local operationId = data.OperationId
  local processId = data.ProcessId
  
  if not operationId or not processId then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = "OperationId and ProcessId are required",
      ProcessId = ao.id,
      Timestamp = os.time()
    })
    return
  end
  
  local operation = getOperation(operationId)
  if not operation then
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Error = "Operation not found: " .. operationId,
      ProcessId = ao.id, 
      Timestamp = os.time()
    })
    return
  end
  
  -- Update operation with process response
  if data.Error then
    updateOperationStatus(operationId, nil, processId, nil, data.Error)
  else
    updateOperationStatus(operationId, nil, processId, data.Data, nil)
  end
  
  -- Check if operation is complete
  local completedCount = #operation.completedProcesses + #operation.failedProcesses
  if completedCount >= #operation.processTargets then
    if #operation.failedProcesses > 0 then
      operation.status = OPERATION_STATES.FAILED
    else
      operation.status = OPERATION_STATES.COMPLETED
    end
  end
  
  ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = {
      operationId = operationId,
      status = operation.status,
      acknowledged = true
    },
    ProcessId = ao.id,
    Timestamp = os.time()
  })
    end
)

-- Initialize coordinator on startup
local coordinatorState = initializeCoordinator()

-- Export functions for testing
return {
  initializeCoordinator = initializeCoordinator,
  generateOperationId = generateOperationId,
  createOperation = createOperation,
  updateOperationStatus = updateOperationStatus,
  getOperation = getOperation,
  checkOperationTimeouts = checkOperationTimeouts,
  getProcessAddress = getProcessAddress,
  routeMessage = routeMessage,
  validateInput = validateInput,
  performHealthCheck = performHealthCheck,
  OPERATION_STATES = OPERATION_STATES
}