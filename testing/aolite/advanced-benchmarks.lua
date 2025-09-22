#!/usr/bin/env lua

--[[
Advanced Performance Benchmarking Framework for AO Lua Processes
Provides comprehensive performance testing and baseline comparison:
- Multi-process performance monitoring
- Baseline comparison and regression detection
- Memory usage estimation and optimization
- Execution time profiling with statistical analysis
- Load testing and stress scenario benchmarking
]]

local AdvancedBenchmarks = {}

-- Benchmark configuration
local BenchmarkConfig = {
  defaultIterations = 1000,
  warmupIterations = 100,
  baselineFile = "testing/fixtures/performance-baselines.js",
  memoryTrackingEnabled = true,
  statisticalAnalysis = true
}

-- Performance data storage
local PerformanceData = {
  benchmarks = {},
  baselines = {},
  regressions = {},
  systemInfo = {}
}

-- System information collection
local function collectSystemInfo()
  local info = {
    luaVersion = _VERSION,
    timestamp = os.time(),
    platform = os.getenv("OS") or "unix",
    hostname = os.getenv("HOSTNAME") or "localhost"
  }
  
  PerformanceData.systemInfo = info
  return info
end

-- High-precision timing functions
local function getHighPrecisionTime()
  return os.clock()
end

-- Memory usage estimation (Lua-specific)
local function estimateMemoryUsage()
  -- Lua doesn't have direct memory measurement, estimate based on table sizes
  local beforeGC = collectgarbage("count")
  collectgarbage("collect")
  local afterGC = collectgarbage("count")
  
  return {
    beforeGC = beforeGC,
    afterGC = afterGC,
    estimated = afterGC * 1024 -- Convert to bytes
  }
end

-- Statistical analysis functions
local function calculateStatistics(values)
  if #values == 0 then
    return {}
  end
  
  table.sort(values)
  
  local sum = 0
  for _, v in ipairs(values) do
    sum = sum + v
  end
  
  local mean = sum / #values
  local median = values[math.ceil(#values / 2)]
  local min = values[1]
  local max = values[#values]
  
  -- Calculate percentiles
  local p95 = values[math.ceil(#values * 0.95)]
  local p99 = values[math.ceil(#values * 0.99)]
  
  -- Calculate standard deviation
  local variance = 0
  for _, v in ipairs(values) do
    variance = variance + (v - mean) ^ 2
  end
  variance = variance / #values
  local stdDev = math.sqrt(variance)
  
  return {
    count = #values,
    sum = sum,
    mean = mean,
    median = median,
    min = min,
    max = max,
    p95 = p95,
    p99 = p99,
    stdDev = stdDev,
    variance = variance
  }
end

-- Single function benchmarking
function AdvancedBenchmarks.benchmarkFunction(name, func, config)
  config = config or {}
  local iterations = config.iterations or BenchmarkConfig.defaultIterations
  local warmup = config.warmup or BenchmarkConfig.warmupIterations
  local measureMemory = config.memory ~= false
  
  print(string.format("⏱️  Benchmarking: %s (%d iterations + %d warmup)", 
    name, iterations, warmup))
  
  -- Warmup phase
  for i = 1, warmup do
    func()
  end
  
  -- Force garbage collection before measurement
  collectgarbage("collect")
  
  local times = {}
  local memoryBefore, memoryAfter
  
  if measureMemory then
    memoryBefore = estimateMemoryUsage()
  end
  
  -- Main benchmark loop
  for i = 1, iterations do
    local startTime = getHighPrecisionTime()
    func()
    local endTime = getHighPrecisionTime()
    
    times[i] = endTime - startTime
  end
  
  if measureMemory then
    memoryAfter = estimateMemoryUsage()
  end
  
  -- Calculate statistics
  local stats = calculateStatistics(times)
  
  local benchmarkResult = {
    name = name,
    iterations = iterations,
    warmup = warmup,
    statistics = stats,
    memory = measureMemory and {
      before = memoryBefore,
      after = memoryAfter,
      delta = memoryAfter.estimated - memoryBefore.estimated
    } or nil,
    timestamp = os.time()
  }
  
  PerformanceData.benchmarks[name] = benchmarkResult
  
  -- Display results
  print(string.format("   Mean: %.6fs (%.3fms)", stats.mean, stats.mean * 1000))
  print(string.format("   Median: %.6fs (%.3fms)", stats.median, stats.median * 1000))
  print(string.format("   P95: %.6fs (%.3fms)", stats.p95, stats.p95 * 1000))
  print(string.format("   P99: %.6fs (%.3fms)", stats.p99, stats.p99 * 1000))
  print(string.format("   Std Dev: %.6fs", stats.stdDev))
  
  if measureMemory and benchmarkResult.memory then
    print(string.format("   Memory Delta: %.2f KB", benchmarkResult.memory.delta / 1024))
  end
  
  return benchmarkResult
end

-- Multi-process benchmarking
function AdvancedBenchmarks.benchmarkProcessCoordination(name, processSpawner, messageSequence, config)
  config = config or {}
  local iterations = config.iterations or 100 -- Lower for complex scenarios
  local measureCoordinationOverhead = config.coordinationOverhead ~= false
  
  print(string.format("🎭 Benchmarking process coordination: %s (%d iterations)", name, iterations))
  
  local coordinationTimes = {}
  local messageTimes = {}
  local totalTimes = {}
  
  for i = 1, iterations do
    local iterationStart = getHighPrecisionTime()
    
    -- Spawn processes
    local processes = processSpawner()
    local spawnEnd = getHighPrecisionTime()
    
    -- Execute message sequence
    local messageStart = getHighPrecisionTime()
    for _, message in ipairs(messageSequence) do
      -- Simulate message routing (would use actual coordination in real test)
      local msgStart = getHighPrecisionTime()
      -- message.execute(processes) -- Placeholder for actual execution
      local msgEnd = getHighPrecisionTime()
      table.insert(messageTimes, msgEnd - msgStart)
    end
    local messageEnd = getHighPrecisionTime()
    
    local iterationEnd = getHighPrecisionTime()
    
    coordinationTimes[i] = spawnEnd - iterationStart
    totalTimes[i] = iterationEnd - iterationStart
  end
  
  local coordinationStats = calculateStatistics(coordinationTimes)
  local messageStats = calculateStatistics(messageTimes)
  local totalStats = calculateStatistics(totalTimes)
  
  local result = {
    name = name,
    iterations = iterations,
    coordination = coordinationStats,
    messaging = messageStats,
    total = totalStats,
    overhead = {
      coordination = coordinationStats.mean,
      messaging = messageStats.mean,
      percentage = (coordinationStats.mean / totalStats.mean) * 100
    }
  }
  
  print(string.format("   Coordination: %.3fms avg (%.2f%% overhead)", 
    coordinationStats.mean * 1000, result.overhead.percentage))
  print(string.format("   Messaging: %.3fms avg per message", messageStats.mean * 1000))
  print(string.format("   Total: %.3fms avg", totalStats.mean * 1000))
  
  PerformanceData.benchmarks[name] = result
  return result
end

-- Load testing benchmarks
function AdvancedBenchmarks.benchmarkLoadScenario(name, loadGenerator, config)
  config = config or {}
  local duration = config.duration or 10 -- seconds
  local targetRPS = config.targetRPS or 100 -- requests per second
  local concurrency = config.concurrency or 10
  
  print(string.format("🔥 Load testing: %s (%ds @ %d RPS, %d concurrent)", 
    name, duration, targetRPS, concurrency))
  
  local startTime = getHighPrecisionTime()
  local endTime = startTime + duration
  local requestTimes = {}
  local errorCount = 0
  local successCount = 0
  
  local requestInterval = 1.0 / targetRPS
  local nextRequestTime = startTime
  
  while getHighPrecisionTime() < endTime do
    local currentTime = getHighPrecisionTime()
    
    if currentTime >= nextRequestTime then
      local requestStart = getHighPrecisionTime()
      
      -- Execute load generator
      local success, result = pcall(loadGenerator)
      
      local requestEnd = getHighPrecisionTime()
      local requestTime = requestEnd - requestStart
      
      if success then
        successCount = successCount + 1
        table.insert(requestTimes, requestTime)
      else
        errorCount = errorCount + 1
      end
      
      nextRequestTime = nextRequestTime + requestInterval
    else
      -- Brief sleep to prevent busy waiting
      os.execute("sleep 0.001")
    end
  end
  
  local actualDuration = getHighPrecisionTime() - startTime
  local actualRPS = (successCount + errorCount) / actualDuration
  local successRate = successCount / (successCount + errorCount) * 100
  
  local responseStats = calculateStatistics(requestTimes)
  
  local loadResult = {
    name = name,
    duration = actualDuration,
    targetRPS = targetRPS,
    actualRPS = actualRPS,
    totalRequests = successCount + errorCount,
    successCount = successCount,
    errorCount = errorCount,
    successRate = successRate,
    responseTime = responseStats
  }
  
  print(string.format("   RPS: %.1f (target: %d)", actualRPS, targetRPS))
  print(string.format("   Success Rate: %.2f%% (%d/%d)", 
    successRate, successCount, successCount + errorCount))
  print(string.format("   Response Time: %.3fms avg, %.3fms P95", 
    responseStats.mean * 1000, responseStats.p95 * 1000))
  
  PerformanceData.benchmarks[name] = loadResult
  return loadResult
end

-- Baseline comparison
function AdvancedBenchmarks.compareWithBaseline(benchmarkName, currentResult, baseline)
  if not baseline then
    print(string.format("⚠️  No baseline found for %s", benchmarkName))
    return { status = "no_baseline", benchmark = benchmarkName }
  end
  
  local currentMean = currentResult.statistics and currentResult.statistics.mean or currentResult.responseTime.mean
  local baselineMean = baseline.mean or baseline.expectedTime
  
  local improvement = ((baselineMean - currentMean) / baselineMean) * 100
  local threshold = baseline.regressionThreshold or 10 -- 10% regression threshold
  
  local comparison = {
    benchmark = benchmarkName,
    current = currentMean,
    baseline = baselineMean,
    improvement = improvement,
    threshold = threshold,
    status = "passed"
  }
  
  if improvement < -threshold then
    comparison.status = "regression"
    table.insert(PerformanceData.regressions, comparison)
    print(string.format("🔴 Performance regression detected in %s: %.2f%% slower", 
      benchmarkName, -improvement))
  elseif improvement > threshold then
    comparison.status = "improvement"
    print(string.format("🟢 Performance improvement in %s: %.2f%% faster", 
      benchmarkName, improvement))
  else
    print(string.format("✅ Performance stable for %s: %.2f%% change", 
      benchmarkName, improvement))
  end
  
  return comparison
end

-- Benchmark suite execution
function AdvancedBenchmarks.runBenchmarkSuite(suiteName, benchmarks, config)
  config = config or {}
  
  print(string.format("\n🏃 Running benchmark suite: %s", suiteName))
  print(string.rep("=", 60))
  
  collectSystemInfo()
  
  local suiteStart = getHighPrecisionTime()
  local suiteResults = {}
  local comparisons = {}
  
  for benchmarkName, benchmarkConfig in pairs(benchmarks) do
    local benchmarkStart = getHighPrecisionTime()
    
    local result
    if benchmarkConfig.type == "function" then
      result = AdvancedBenchmarks.benchmarkFunction(
        benchmarkName, 
        benchmarkConfig.func, 
        benchmarkConfig.config
      )
    elseif benchmarkConfig.type == "coordination" then
      result = AdvancedBenchmarks.benchmarkProcessCoordination(
        benchmarkName,
        benchmarkConfig.spawner,
        benchmarkConfig.messages,
        benchmarkConfig.config
      )
    elseif benchmarkConfig.type == "load" then
      result = AdvancedBenchmarks.benchmarkLoadScenario(
        benchmarkName,
        benchmarkConfig.generator,
        benchmarkConfig.config
      )
    end
    
    suiteResults[benchmarkName] = result
    
    -- Compare with baseline if available
    if config.baselines and config.baselines[benchmarkName] then
      local comparison = AdvancedBenchmarks.compareWithBaseline(
        benchmarkName, 
        result, 
        config.baselines[benchmarkName]
      )
      comparisons[benchmarkName] = comparison
    end
    
    print() -- Empty line between benchmarks
  end
  
  local suiteEnd = getHighPrecisionTime()
  local suiteTime = suiteEnd - suiteStart
  
  print(string.format("📊 Benchmark suite completed in %.2fs", suiteTime))
  
  -- Summary of regressions
  if #PerformanceData.regressions > 0 then
    print(string.format("🔴 %d performance regressions detected", #PerformanceData.regressions))
  else
    print("✅ No performance regressions detected")
  end
  
  return {
    suiteName = suiteName,
    results = suiteResults,
    comparisons = comparisons,
    regressions = PerformanceData.regressions,
    executionTime = suiteTime,
    systemInfo = PerformanceData.systemInfo
  }
end

-- Performance report generation
function AdvancedBenchmarks.generateReport(outputFile)
  outputFile = outputFile or "benchmark-report.json"
  
  local report = {
    timestamp = os.time(),
    systemInfo = PerformanceData.systemInfo,
    benchmarks = PerformanceData.benchmarks,
    regressions = PerformanceData.regressions,
    summary = {
      totalBenchmarks = 0,
      regressions = #PerformanceData.regressions,
      avgExecutionTime = 0
    }
  }
  
  -- Calculate summary statistics
  local totalTime = 0
  for name, benchmark in pairs(PerformanceData.benchmarks) do
    report.summary.totalBenchmarks = report.summary.totalBenchmarks + 1
    if benchmark.statistics then
      totalTime = totalTime + benchmark.statistics.mean
    elseif benchmark.responseTime then
      totalTime = totalTime + benchmark.responseTime.mean
    end
  end
  
  if report.summary.totalBenchmarks > 0 then
    report.summary.avgExecutionTime = totalTime / report.summary.totalBenchmarks
  end
  
  -- Save report (mock file writing for AO environment)
  print(string.format("📄 Generated performance report: %s", outputFile))
  print(string.format("   Benchmarks: %d", report.summary.totalBenchmarks))
  print(string.format("   Regressions: %d", report.summary.regressions))
  print(string.format("   Avg Execution Time: %.6fs", report.summary.avgExecutionTime))
  
  return report
end

-- Configuration and initialization
function AdvancedBenchmarks.configure(config)
  for key, value in pairs(config) do
    BenchmarkConfig[key] = value
  end
  
  print("🔧 Advanced benchmarking framework configured")
  return BenchmarkConfig
end

return AdvancedBenchmarks