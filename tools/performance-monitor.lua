-- Performance Monitoring Tool for Process Coordination
-- Measures <5 second completion for coordinated operations
-- Validates <500ms process-to-process latency

local function measureLatency(startTime, endTime)
  return (endTime - startTime) * 1000 -- Convert to milliseconds
end

local function validateCoordinationPerformance(operationStartTime, operationEndTime)
  local totalTime = (operationEndTime - operationStartTime)
  local maxCoordinationTime = 5 -- 5 seconds
  
  if totalTime > maxCoordinationTime then
    return false, string.format("Coordination exceeded 5s limit: %.2fs", totalTime)
  end
  
  return true, string.format("Coordination completed within limits: %.2fs", totalTime)
end

local function validateProcessLatency(processStartTime, processEndTime)
  local latency = measureLatency(processStartTime, processEndTime)
  local maxLatency = 500 -- 500ms
  
  if latency > maxLatency then
    return false, string.format("Process latency exceeded 500ms limit: %.2fms", latency)
  end
  
  return true, string.format("Process latency within limits: %.2fms", latency)
end

-- Performance test runner
local function runPerformanceTest(testName, testFunction)
  local startTime = os.clock()
  local success, result = pcall(testFunction)
  local endTime = os.clock()
  
  return {
    testName = testName,
    success = success,
    result = result,
    duration = endTime - startTime,
    timestamp = os.time()
  }
end

return {
  measureLatency = measureLatency,
  validateCoordinationPerformance = validateCoordinationPerformance,
  validateProcessLatency = validateProcessLatency,
  runPerformanceTest = runPerformanceTest
}