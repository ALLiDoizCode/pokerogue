#!/usr/bin/env lua

--[[
Multi-Process Coordination Testing Framework
Extends Enhanced Aolite Framework for complex multi-process scenarios:
- Process spawning and lifecycle management
- Inter-process message routing and validation
- Async coordination pattern testing
- Process state synchronization verification
- Complex scenario orchestration
]]

local CoordinationTesting = {}

-- Process registry for multi-process tests
local ProcessRegistry = {
  processes = {},
  messageLog = {},
  routingTable = {},
  nextProcessId = 1
}

-- Mock process spawning system
local function spawnMockProcess(processType, processConfig)
  local processId = "process-" .. ProcessRegistry.nextProcessId
  ProcessRegistry.nextProcessId = ProcessRegistry.nextProcessId + 1
  
  local process = {
    id = processId,
    type = processType,
    config = processConfig or {},
    state = "running",
    handlers = {},
    messageQueue = {},
    lastActivity = os.time(),
    stats = {
      messagesReceived = 0,
      messagesSent = 0,
      errors = 0,
      avgResponseTime = 0
    }
  }
  
  -- Setup process-specific AO environment
  process.ao = {
    id = processId,
    send = function(message)
      return CoordinationTesting.routeMessage(processId, message)
    end,
    env = {
      Process = {
        Id = processId,
        Owner = "test-owner",
        Tags = { Type = processType }
      }
    }
  }
  
  -- Mock Handlers for this process
  process.Handlers = {
    _handlers = {},
    add = function(name, matcher, handler)
      process.handlers[name] = {
        name = name,
        matcher = matcher,
        handler = handler,
        callCount = 0,
        avgExecutionTime = 0
      }
    end,
    receive = function(msg)
      process.stats.messagesReceived = process.stats.messagesReceived + 1
      process.lastActivity = os.time()
      
      for name, handler in pairs(process.handlers) do
        if handler.matcher(msg) then
          local startTime = os.clock()
          handler.callCount = handler.callCount + 1
          
          local success, result = pcall(handler.handler, msg)
          
          local endTime = os.clock()
          local executionTime = endTime - startTime
          handler.avgExecutionTime = (handler.avgExecutionTime + executionTime) / 2
          
          if not success then
            process.stats.errors = process.stats.errors + 1
          end
          
          return { 
            success = success, 
            result = result, 
            handler = name,
            executionTime = executionTime
          }
        end
      end
      return { success = false, error = "No matching handler" }
    end
  }
  
  ProcessRegistry.processes[processId] = process
  ProcessRegistry.routingTable[processId] = process
  
  print(string.format("✅ Spawned mock process: %s (%s)", processId, processType))
  return process
end

-- Message routing between processes
function CoordinationTesting.routeMessage(fromProcessId, message)
  local messageId = "msg-" .. math.random(10000, 99999)
  local timestamp = os.time()
  
  local routedMessage = {
    Id = messageId,
    From = fromProcessId,
    Target = message.Target,
    Action = message.Action,
    Data = message.Data,
    Tags = message.Tags or {},
    Timestamp = timestamp,
    RoutingInfo = {
      source = fromProcessId,
      destination = message.Target,
      routed_at = timestamp
    }
  }
  
  -- Log the message
  table.insert(ProcessRegistry.messageLog, routedMessage)
  
  -- Route to target process
  local targetProcess = ProcessRegistry.routingTable[message.Target]
  if targetProcess then
    table.insert(targetProcess.messageQueue, routedMessage)
    targetProcess.stats.messagesSent = targetProcess.stats.messagesSent + 1
    
    -- Immediate delivery for testing
    local response = targetProcess.Handlers.receive(routedMessage)
    return { success = true, messageId = messageId, response = response }
  else
    print(string.format("❌ Route failed: Target process %s not found", message.Target))
    return { success = false, error = "Target process not found" }
  end
end

-- Process message queue processing
function CoordinationTesting.processMessageQueues()
  local processedCount = 0
  
  for processId, process in pairs(ProcessRegistry.processes) do
    while #process.messageQueue > 0 do
      local message = table.remove(process.messageQueue, 1)
      local response = process.Handlers.receive(message)
      processedCount = processedCount + 1
      
      print(string.format("📨 Processed message %s in %s", message.Id, processId))
    end
  end
  
  return processedCount
end

-- Multi-process scenario testing
function CoordinationTesting.testCoordinationScenario(scenarioName, processes, messages, validations)
  print(string.format("\n🎭 Testing coordination scenario: %s", scenarioName))
  print(string.rep("-", 50))
  
  local scenarioStart = os.clock()
  
  -- Reset registry for clean test
  ProcessRegistry.processes = {}
  ProcessRegistry.messageLog = {}
  ProcessRegistry.routingTable = {}
  ProcessRegistry.nextProcessId = 1
  
  -- Spawn required processes
  local spawnedProcesses = {}
  for _, processSpec in ipairs(processes) do
    local process = spawnMockProcess(processSpec.type, processSpec.config)
    spawnedProcesses[processSpec.name] = process
    
    -- Load process handlers if specified
    if processSpec.handlers then
      for handlerName, handlerConfig in pairs(processSpec.handlers) do
        process.Handlers.add(
          handlerName,
          handlerConfig.matcher,
          handlerConfig.handler
        )
      end
    end
  end
  
  -- Execute message sequence
  for i, messageSpec in ipairs(messages) do
    local fromProcess = spawnedProcesses[messageSpec.from]
    local toProcess = spawnedProcesses[messageSpec.to]
    
    if fromProcess and toProcess then
      local message = {
        Target = toProcess.id,
        Action = messageSpec.action,
        Data = messageSpec.data,
        Tags = messageSpec.tags or {}
      }
      
      local result = CoordinationTesting.routeMessage(fromProcess.id, message)
      print(string.format("  📤 Step %d: %s -> %s (%s)", 
        i, messageSpec.from, messageSpec.to, messageSpec.action))
      
      if not result.success then
        error(string.format("Message routing failed at step %d: %s", i, result.error))
      end
    else
      error(string.format("Invalid process reference in step %d", i))
    end
  end
  
  -- Process any remaining queued messages
  CoordinationTesting.processMessageQueues()
  
  -- Run validations
  local validationsPassed = 0
  local validationsTotal = #validations
  
  for i, validation in ipairs(validations) do
    local success, result = pcall(validation, spawnedProcesses, ProcessRegistry.messageLog)
    if success then
      validationsPassed = validationsPassed + 1
      print(string.format("  ✅ Validation %d passed", i))
    else
      print(string.format("  ❌ Validation %d failed: %s", i, result))
    end
  end
  
  local scenarioEnd = os.clock()
  local scenarioTime = scenarioEnd - scenarioStart
  
  print(string.format("📊 Scenario results: %d/%d validations passed (%.2fms)", 
    validationsPassed, validationsTotal, scenarioTime * 1000))
  
  return {
    success = validationsPassed == validationsTotal,
    validationsPassed = validationsPassed,
    validationsTotal = validationsTotal,
    executionTime = scenarioTime,
    processes = spawnedProcesses,
    messageLog = ProcessRegistry.messageLog
  }
end

-- Process state validation
function CoordinationTesting.validateProcessState(processId, expectedState)
  local process = ProcessRegistry.processes[processId]
  if not process then
    return false, "Process not found"
  end
  
  for key, expectedValue in pairs(expectedState) do
    if process.state[key] ~= expectedValue then
      return false, string.format("State mismatch for %s: expected %s, got %s", 
        key, tostring(expectedValue), tostring(process.state[key]))
    end
  end
  
  return true, "State validation passed"
end

-- Message integrity validation
function CoordinationTesting.validateMessageIntegrity(messageLog, expectedPatterns)
  local validationResults = {}
  
  for i, pattern in ipairs(expectedPatterns) do
    local found = false
    
    for _, message in ipairs(messageLog) do
      local matches = true
      
      for field, expectedValue in pairs(pattern) do
        if message[field] ~= expectedValue then
          matches = false
          break
        end
      end
      
      if matches then
        found = true
        break
      end
    end
    
    validationResults[i] = {
      pattern = pattern,
      found = found,
      description = pattern.description or string.format("Pattern %d", i)
    }
  end
  
  return validationResults
end

-- Performance monitoring for coordination
function CoordinationTesting.monitorCoordinationPerformance(testFunction, iterations)
  iterations = iterations or 100
  
  local performanceData = {
    iterations = iterations,
    totalTime = 0,
    avgTime = 0,
    minTime = math.huge,
    maxTime = 0,
    messageStats = {
      totalMessages = 0,
      avgMessagesPerIteration = 0,
      routingErrors = 0
    }
  }
  
  print(string.format("⏱️  Monitoring coordination performance (%d iterations)", iterations))
  
  for i = 1, iterations do
    -- Clear state for clean test
    ProcessRegistry.messageLog = {}
    
    local iterationStart = os.clock()
    local iterationResult = testFunction()
    local iterationEnd = os.clock()
    
    local iterationTime = iterationEnd - iterationStart
    performanceData.totalTime = performanceData.totalTime + iterationTime
    performanceData.minTime = math.min(performanceData.minTime, iterationTime)
    performanceData.maxTime = math.max(performanceData.maxTime, iterationTime)
    
    -- Collect message statistics
    performanceData.messageStats.totalMessages = 
      performanceData.messageStats.totalMessages + #ProcessRegistry.messageLog
  end
  
  performanceData.avgTime = performanceData.totalTime / iterations
  performanceData.messageStats.avgMessagesPerIteration = 
    performanceData.messageStats.totalMessages / iterations
  
  print(string.format("   Total time: %.4fs", performanceData.totalTime))
  print(string.format("   Avg per iteration: %.6fs", performanceData.avgTime))
  print(string.format("   Min time: %.6fs", performanceData.minTime))
  print(string.format("   Max time: %.6fs", performanceData.maxTime))
  print(string.format("   Avg messages/iteration: %.2f", 
    performanceData.messageStats.avgMessagesPerIteration))
  
  return performanceData
end

-- Stress testing for process coordination
function CoordinationTesting.stressTestCoordination(processes, messageVolume, duration)
  print(string.format("🔥 Stress testing coordination (%d processes, %d msg/sec, %ds)", 
    #processes, messageVolume, duration))
  
  local stressResults = {
    totalMessages = 0,
    successfulMessages = 0,
    failedMessages = 0,
    avgResponseTime = 0,
    peakMemoryUsage = 0,
    errors = {}
  }
  
  local startTime = os.clock()
  local endTime = startTime + duration
  local messageInterval = 1.0 / messageVolume
  
  -- Spawn stress test processes
  local stressProcesses = {}
  for i, processSpec in ipairs(processes) do
    stressProcesses[i] = spawnMockProcess(processSpec.type, processSpec.config)
  end
  
  while os.clock() < endTime do
    -- Send messages at specified rate
    for i = 1, messageVolume do
      local fromProcess = stressProcesses[math.random(1, #stressProcesses)]
      local toProcess = stressProcesses[math.random(1, #stressProcesses)]
      
      if fromProcess.id ~= toProcess.id then
        local message = {
          Target = toProcess.id,
          Action = "StressTest",
          Data = string.format("stress-test-%d", stressResults.totalMessages),
          Tags = { Type = "StressTest" }
        }
        
        local messageStart = os.clock()
        local result = CoordinationTesting.routeMessage(fromProcess.id, message)
        local messageEnd = os.clock()
        
        stressResults.totalMessages = stressResults.totalMessages + 1
        
        if result.success then
          stressResults.successfulMessages = stressResults.successfulMessages + 1
          local responseTime = messageEnd - messageStart
          stressResults.avgResponseTime = 
            (stressResults.avgResponseTime + responseTime) / 2
        else
          stressResults.failedMessages = stressResults.failedMessages + 1
          table.insert(stressResults.errors, result.error)
        end
      end
    end
    
    -- Brief pause to maintain message rate
    local elapsed = os.clock() - startTime
    local expectedMessages = math.floor(elapsed * messageVolume)
    if stressResults.totalMessages < expectedMessages then
      -- Catch up
    else
      -- Small delay to maintain rate
      os.execute("sleep 0.01")
    end
  end
  
  local actualDuration = os.clock() - startTime
  stressResults.actualDuration = actualDuration
  stressResults.actualMessageRate = stressResults.totalMessages / actualDuration
  
  print(string.format("📊 Stress test results:"))
  print(string.format("   Messages: %d total, %d success, %d failed", 
    stressResults.totalMessages, stressResults.successfulMessages, stressResults.failedMessages))
  print(string.format("   Success rate: %.2f%%", 
    (stressResults.successfulMessages / math.max(stressResults.totalMessages, 1)) * 100))
  print(string.format("   Avg response time: %.6fs", stressResults.avgResponseTime))
  print(string.format("   Actual message rate: %.2f msg/sec", stressResults.actualMessageRate))
  
  return stressResults
end

-- Export coordination testing functions
CoordinationTesting.spawnProcess = spawnMockProcess
CoordinationTesting.validateState = validateProcessState
CoordinationTesting.validateMessages = validateMessageIntegrity
CoordinationTesting.monitorPerformance = monitorCoordinationPerformance
CoordinationTesting.stressTest = stressTestCoordination

return CoordinationTesting