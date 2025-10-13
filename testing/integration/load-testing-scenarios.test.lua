#!/usr/bin/env lua

--[[
Load Testing Scenarios for AO Process Scalability
Comprehensive load testing framework for process performance validation:
- High-volume message processing across multiple processes
- Concurrent battle scenarios with realistic load patterns
- Memory usage and resource consumption monitoring
- Process scaling validation under stress conditions
- Performance degradation detection and analysis
]]

-- Load testing frameworks
local CoordinationTesting = require('testing.aolite.coordination-testing')
local AdvancedBenchmarks = require('testing.aolite.advanced-benchmarks')
local PropertyBasedTesting = require('testing.aolite.property-based-testing')

-- Load testing configuration
local LoadTestConfig = {
  concurrentUsers = 100,
  messagesTotalTarget = 10000,
  messagesPerSecond = 1000,
  testDurationSeconds = 30,
  memoryThresholdMB = 100,
  responseTimeThresholdMs = 1000,
  errorRateThreshold = 0.05 -- 5% max error rate
}

-- Load testing metrics collection
local LoadMetrics = {
  totalMessages = 0,
  successfulMessages = 0,
  failedMessages = 0,
  averageResponseTime = 0,
  peakResponseTime = 0,
  memoryUsage = {},
  processStats = {},
  errorTypes = {}
}

-- Mock high-performance process implementations
local function createLoadTestProcess(processType, config)
  local process = {
    type = processType,
    config = config or {},
    stats = {
      messagesProcessed = 0,
      totalProcessingTime = 0,
      errors = 0,
      startTime = os.clock()
    },
    handlers = {}
  }

  if processType == "coordinator-load" then
    process.handlers = {
      CoordinateLoad = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "CoordinateLoad" end,
        handler = function(msg)
          local startTime = os.clock()
          local data = json.decode(msg.Data)

          -- Simulate coordination overhead
          for i = 1, data.complexity or 10 do
            math.sqrt(i * 1000) -- CPU work simulation
          end

          process.stats.messagesProcessed = process.stats.messagesProcessed + 1
          process.stats.totalProcessingTime = process.stats.totalProcessingTime + (os.clock() - startTime)

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              coordinated = true,
              processId = ao.id,
              messageCount = process.stats.messagesProcessed
            })
          })
        end
      }
    }
  elseif processType == "battle-load" then
    process.handlers = {
      ProcessBattleLoad = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "ProcessBattleLoad" end,
        handler = function(msg)
          local startTime = os.clock()
          local data = json.decode(msg.Data)

          -- Simulate battle calculation load
          local damage = 0
          for i = 1, 50 do -- Simulate complex damage calculation
            damage = damage + math.floor(math.random(1, 100) * data.power * 0.01)
          end

          process.stats.messagesProcessed = process.stats.messagesProcessed + 1
          process.stats.totalProcessingTime = process.stats.totalProcessingTime + (os.clock() - startTime)

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              damage = damage,
              processId = ao.id,
              battleProcessed = true
            })
          })
        end
      }
    }
  elseif processType == "data-load" then
    process.handlers = {
      GetDataLoad = {
        matcher = function(msg) return msg.Tags and msg.Tags.Action == "GetDataLoad" end,
        handler = function(msg)
          local startTime = os.clock()
          local data = json.decode(msg.Data)

          -- Simulate database lookup with varying complexity
          local results = {}
          for i = 1, data.recordCount or 10 do
            results[i] = {
              id = i,
              name = string.format("Record_%d", i),
              data = string.rep("x", data.recordSize or 100)
            }
          end

          process.stats.messagesProcessed = process.stats.messagesProcessed + 1
          process.stats.totalProcessingTime = process.stats.totalProcessingTime + (os.clock() - startTime)

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              results = results,
              processId = ao.id,
              recordCount = #results
            })
          })
        end
      }
    }
  end

  return process
end

-- Load testing scenarios
local LoadTestScenarios = {}

function LoadTestScenarios.testHighVolumeMessageProcessing()
  print("📈 Testing high-volume message processing")

  local processes = {}
  local processCount = 10

  -- Spawn multiple processes of different types
  for i = 1, processCount do
    local processType = (i % 3 == 0) and "coordinator-load" or
                      (i % 3 == 1) and "battle-load" or "data-load"
    processes[string.format("process_%d", i)] = CoordinationTesting.spawnProcess(processType, {
      loadTesting = true,
      processIndex = i
    })
  end

  -- Load process handlers
  for processName, process in pairs(processes) do
    local handlers = createLoadTestProcess(process.type, {}).handlers
    for handlerName, handler in pairs(handlers) do
      process.Handlers.add(handlerName, handler.matcher, handler.handler)
    end
  end

  local startTime = os.clock()
  local messageCount = LoadTestConfig.messagesTotalTarget
  local messagesPerBatch = 100
  local successCount = 0
  local errorCount = 0

  print(string.format("  Sending %d messages across %d processes...", messageCount, processCount))

  for batch = 1, math.ceil(messageCount / messagesPerBatch) do
    local batchStart = os.clock()

    for i = 1, messagesPerBatch do
      if (batch - 1) * messagesPerBatch + i <= messageCount then
        -- Select random target process
        local targetIndex = math.random(1, processCount)
        local targetProcess = processes[string.format("process_%d", targetIndex)]

        if targetProcess then
          local messageData = {
            complexity = math.random(5, 15),
            power = math.random(50, 150),
            recordCount = math.random(1, 20),
            recordSize = math.random(50, 200)
          }

          local action = (targetProcess.type == "coordinator-load") and "CoordinateLoad" or
                        (targetProcess.type == "battle-load") and "ProcessBattleLoad" or "GetDataLoad"

          local messageStart = os.clock()
          local result = CoordinationTesting.routeMessage("load_tester", {
            Target = targetProcess.id,
            Action = action,
            Data = json.encode(messageData),
            Tags = {Action = action}
          })
          local messageEnd = os.clock()

          if result.success then
            successCount = successCount + 1
          else
            errorCount = errorCount + 1
          end

          -- Track response time
          local responseTime = (messageEnd - messageStart) * 1000 -- ms
          LoadMetrics.averageResponseTime = (LoadMetrics.averageResponseTime + responseTime) / 2
          LoadMetrics.peakResponseTime = math.max(LoadMetrics.peakResponseTime, responseTime)
        end
      end
    end

    local batchTime = os.clock() - batchStart

    -- Progress update
    if batch % 10 == 0 then
      print(string.format("  Batch %d/%d completed (%.2fs)",
        batch, math.ceil(messageCount / messagesPerBatch), batchTime))
    end
  end

  local endTime = os.clock()
  local totalTime = endTime - startTime

  LoadMetrics.totalMessages = messageCount
  LoadMetrics.successfulMessages = successCount
  LoadMetrics.failedMessages = errorCount

  local throughput = messageCount / totalTime
  local errorRate = errorCount / messageCount

  print(string.format("  📊 Results:"))
  print(string.format("    Total time: %.2fs", totalTime))
  print(string.format("    Throughput: %.2f msg/sec", throughput))
  print(string.format("    Success rate: %.2f%% (%d/%d)",
    (successCount / messageCount) * 100, successCount, messageCount))
  print(string.format("    Error rate: %.2f%%", errorRate * 100))
  print(string.format("    Avg response time: %.2fms", LoadMetrics.averageResponseTime))
  print(string.format("    Peak response time: %.2fms", LoadMetrics.peakResponseTime))

  return {
    success = errorRate < LoadTestConfig.errorRateThreshold,
    throughput = throughput,
    errorRate = errorRate,
    averageResponseTime = LoadMetrics.averageResponseTime,
    totalTime = totalTime,
    processCount = processCount
  }
end

function LoadTestScenarios.testConcurrentBattleScenarios()
  print("⚔️  Testing concurrent battle scenarios")

  local battleCount = 50
  local battlesPerSecond = 10
  local maxConcurrentBattles = 25

  local activeBattles = {}
  local completedBattles = {}
  local battleResults = {}

  local startTime = os.clock()

  for battleId = 1, battleCount do
    -- Rate limiting
    while #activeBattles >= maxConcurrentBattles do
      -- Wait for battles to complete (simulated)
      os.execute("sleep 0.1")

      -- Simulate battle completion
      if #activeBattles > 0 and math.random() > 0.7 then
        local completedBattle = table.remove(activeBattles, 1)
        table.insert(completedBattles, completedBattle)
      end
    end

    -- Start new battle
    local battle = {
      id = battleId,
      startTime = os.clock(),
      participants = {
        {species = math.random(1, 150), level = math.random(50, 100)},
        {species = math.random(1, 150), level = math.random(50, 100)}
      },
      turns = 0,
      status = "active"
    }

    table.insert(activeBattles, battle)

    -- Simulate battle processing
    local battleProcess = CoordinationTesting.spawnProcess("battle-load", {})
    local battleHandlers = createLoadTestProcess("battle-load", {}).handlers
    for handlerName, handler in pairs(battleHandlers) do
      battleProcess.Handlers.add(handlerName, handler.matcher, handler.handler)
    end

    -- Process battle turns
    for turn = 1, math.random(3, 10) do
      local turnStart = os.clock()

      local result = CoordinationTesting.routeMessage("battle_coordinator", {
        Target = battleProcess.id,
        Action = "ProcessBattleLoad",
        Data = json.encode({
          battleId = battleId,
          turn = turn,
          power = math.random(80, 120)
        }),
        Tags = {Action = "ProcessBattleLoad"}
      })

      local turnTime = os.clock() - turnStart
      battle.turns = turn

      if not result.success then
        battle.status = "error"
        break
      end

      if turnTime > 0.1 then -- 100ms threshold
        battle.status = "slow"
      end
    end

    battle.endTime = os.clock()
    battle.duration = battle.endTime - battle.startTime
    battleResults[battleId] = battle

    -- Rate limiting delay
    local expectedTime = battleId / battlesPerSecond
    local actualTime = os.clock() - startTime
    if actualTime < expectedTime then
      local sleepTime = expectedTime - actualTime
      os.execute(string.format("sleep %.3f", sleepTime))
    end
  end

  -- Wait for remaining battles to complete
  while #activeBattles > 0 do
    local completedBattle = table.remove(activeBattles, 1)
    table.insert(completedBattles, completedBattle)
  end

  local endTime = os.clock()
  local totalTime = endTime - startTime

  -- Analyze results
  local totalTurns = 0
  local slowBattles = 0
  local errorBattles = 0
  local totalBattleDuration = 0

  for _, battle in pairs(battleResults) do
    totalTurns = totalTurns + battle.turns
    totalBattleDuration = totalBattleDuration + battle.duration

    if battle.status == "slow" then
      slowBattles = slowBattles + 1
    elseif battle.status == "error" then
      errorBattles = errorBattles + 1
    end
  end

  local avgBattleDuration = totalBattleDuration / battleCount
  local avgTurnsPerBattle = totalTurns / battleCount
  local battleThroughput = battleCount / totalTime

  print(string.format("  📊 Concurrent Battle Results:"))
  print(string.format("    Total battles: %d", battleCount))
  print(string.format("    Total time: %.2fs", totalTime))
  print(string.format("    Battle throughput: %.2f battles/sec", battleThroughput))
  print(string.format("    Avg battle duration: %.3fs", avgBattleDuration))
  print(string.format("    Avg turns per battle: %.1f", avgTurnsPerBattle))
  print(string.format("    Slow battles: %d (%.1f%%)", slowBattles, (slowBattles / battleCount) * 100))
  print(string.format("    Error battles: %d (%.1f%%)", errorBattles, (errorBattles / battleCount) * 100))

  return {
    success = errorBattles < (battleCount * 0.05), -- <5% error rate
    battleCount = battleCount,
    battleThroughput = battleThroughput,
    avgBattleDuration = avgBattleDuration,
    slowBattles = slowBattles,
    errorBattles = errorBattles,
    totalTime = totalTime
  }
end

function LoadTestScenarios.testMemoryUsageUnderLoad()
  print("💾 Testing memory usage under load")

  local memorySnapshots = {}
  local processCount = 20
  local messagesPerProcess = 500

  -- Initial memory snapshot
  local initialMemory = collectgarbage("count")
  table.insert(memorySnapshots, {time = 0, memory = initialMemory, phase = "initial"})

  local processes = {}

  -- Spawn processes
  for i = 1, processCount do
    processes[i] = CoordinationTesting.spawnProcess("data-load", {
      memoryIntensive = true,
      dataSize = "large"
    })

    local handlers = createLoadTestProcess("data-load", {}).handlers
    for handlerName, handler in pairs(handlers) do
      processes[i].Handlers.add(handlerName, handler.matcher, handler.handler)
    end
  end

  local postSpawnMemory = collectgarbage("count")
  table.insert(memorySnapshots, {
    time = os.clock(),
    memory = postSpawnMemory,
    phase = "post_spawn",
    memoryIncrease = postSpawnMemory - initialMemory
  })

  local startTime = os.clock()

  -- Generate load with increasing data sizes
  for round = 1, 5 do
    local roundStart = os.clock()

    for i = 1, processCount do
      for msg = 1, messagesPerProcess / 5 do
        local dataSize = round * 50 -- Increasing data size

        CoordinationTesting.routeMessage("memory_tester", {
          Target = processes[i].id,
          Action = "GetDataLoad",
          Data = json.encode({
            recordCount = dataSize,
            recordSize = round * 20
          }),
          Tags = {Action = "GetDataLoad"}
        })
      end
    end

    -- Memory snapshot after each round
    local roundMemory = collectgarbage("count")
    table.insert(memorySnapshots, {
      time = os.clock() - startTime,
      memory = roundMemory,
      phase = string.format("round_%d", round),
      memoryIncrease = roundMemory - initialMemory
    })

    print(string.format("  Round %d completed: %.1f KB memory", round, roundMemory))
  end

  -- Force garbage collection
  collectgarbage("collect")
  local postGCMemory = collectgarbage("count")
  table.insert(memorySnapshots, {
    time = os.clock() - startTime,
    memory = postGCMemory,
    phase = "post_gc",
    memoryIncrease = postGCMemory - initialMemory
  })

  local endTime = os.clock()
  local totalTime = endTime - startTime

  -- Analyze memory usage
  local peakMemory = 0
  local memoryGrowth = 0

  for _, snapshot in ipairs(memorySnapshots) do
    peakMemory = math.max(peakMemory, snapshot.memory)
    if snapshot.phase == "post_gc" then
      memoryGrowth = snapshot.memoryIncrease
    end
  end

  local memoryEfficient = memoryGrowth < (LoadTestConfig.memoryThresholdMB * 1024) -- Convert MB to KB

  print(string.format("  📊 Memory Usage Results:"))
  print(string.format("    Initial memory: %.1f KB", initialMemory))
  print(string.format("    Peak memory: %.1f KB", peakMemory))
  print(string.format("    Memory growth: %.1f KB", memoryGrowth))
  print(string.format("    Memory efficient: %s", memoryEfficient and "✅ Yes" or "❌ No"))
  print(string.format("    Total time: %.2fs", totalTime))

  return {
    success = memoryEfficient,
    initialMemory = initialMemory,
    peakMemory = peakMemory,
    memoryGrowth = memoryGrowth,
    memorySnapshots = memorySnapshots,
    totalTime = totalTime
  }
end

function LoadTestScenarios.testProcessScalingLimits()
  print("📊 Testing process scaling limits")

  local maxProcesses = 100
  local incrementStep = 10
  local messagesPerProcess = 50

  local scalingResults = {}

  for processCount = incrementStep, maxProcesses, incrementStep do
    print(string.format("  Testing with %d processes...", processCount))

    local testStart = os.clock()
    local processes = {}
    local spawnFailures = 0

    -- Spawn processes
    for i = 1, processCount do
      local success, process = pcall(function()
        return CoordinationTesting.spawnProcess("coordinator-load", {
          scalingTest = true,
          processIndex = i
        })
      end)

      if success then
        processes[i] = process
        local handlers = createLoadTestProcess("coordinator-load", {}).handlers
        for handlerName, handler in pairs(handlers) do
          process.Handlers.add(handlerName, handler.matcher, handler.handler)
        end
      else
        spawnFailures = spawnFailures + 1
      end
    end

    local actualProcesses = processCount - spawnFailures

    -- Send test messages
    local messageStart = os.clock()
    local successCount = 0
    local errorCount = 0

    for i = 1, actualProcesses do
      if processes[i] then
        for msg = 1, messagesPerProcess do
          local result = CoordinationTesting.routeMessage("scaling_tester", {
            Target = processes[i].id,
            Action = "CoordinateLoad",
            Data = json.encode({complexity = 5}),
            Tags = {Action = "CoordinateLoad"}
          })

          if result.success then
            successCount = successCount + 1
          else
            errorCount = errorCount + 1
          end
        end
      end
    end

    local messageEnd = os.clock()
    local testEnd = os.clock()

    local totalMessages = actualProcesses * messagesPerProcess
    local messageTime = messageEnd - messageStart
    local totalTime = testEnd - testStart
    local throughput = totalMessages / messageTime
    local errorRate = errorCount / totalMessages

    local result = {
      processCount = processCount,
      actualProcesses = actualProcesses,
      spawnFailures = spawnFailures,
      totalMessages = totalMessages,
      successCount = successCount,
      errorCount = errorCount,
      throughput = throughput,
      errorRate = errorRate,
      messageTime = messageTime,
      totalTime = totalTime,
      successful = spawnFailures < processCount * 0.1 and errorRate < 0.05
    }

    table.insert(scalingResults, result)

    print(string.format("    Processes: %d/%d spawned", actualProcesses, processCount))
    print(string.format("    Throughput: %.2f msg/sec", throughput))
    print(string.format("    Error rate: %.2f%%", errorRate * 100))

    -- Stop if we hit scaling limits
    if spawnFailures > processCount * 0.1 or errorRate > 0.1 then
      print(string.format("  ⚠️  Scaling limit reached at %d processes", processCount))
      break
    end
  end

  -- Find optimal process count
  local optimalCount = 0
  local maxThroughput = 0

  for _, result in ipairs(scalingResults) do
    if result.successful and result.throughput > maxThroughput then
      maxThroughput = result.throughput
      optimalCount = result.processCount
    end
  end

  print(string.format("  📊 Scaling Results:"))
  print(string.format("    Optimal process count: %d", optimalCount))
  print(string.format("    Max throughput: %.2f msg/sec", maxThroughput))
  print(string.format("    Scaling tests: %d", #scalingResults))

  return {
    success = optimalCount > 0,
    optimalProcessCount = optimalCount,
    maxThroughput = maxThroughput,
    scalingResults = scalingResults
  }
end

-- Main load testing execution
local function runLoadTestingScenarios()
  print("🔥 Running Load Testing and Process Scaling Scenarios")
  print(string.rep("=", 60))

  local results = {}

  -- High-volume message processing
  print("\n📈 High-Volume Message Processing")
  results.highVolumeMessages = LoadTestScenarios.testHighVolumeMessageProcessing()

  -- Concurrent battle scenarios
  print("\n⚔️  Concurrent Battle Scenarios")
  results.concurrentBattles = LoadTestScenarios.testConcurrentBattleScenarios()

  -- Memory usage under load
  print("\n💾 Memory Usage Under Load")
  results.memoryUsage = LoadTestScenarios.testMemoryUsageUnderLoad()

  -- Process scaling limits
  print("\n📊 Process Scaling Limits")
  results.scalingLimits = LoadTestScenarios.testProcessScalingLimits()

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
  print(string.format("📊 Load Testing Summary: %d/%d tests passed", passedTests, totalTests))

  if passedTests == totalTests then
    print("🎉 All load tests passed!")
  else
    print("⚠️  Some load tests failed - check performance thresholds")
  end

  return results
end

-- Export load testing functions
return {
  runLoadTestingScenarios = runLoadTestingScenarios,
  LoadTestScenarios = LoadTestScenarios,
  LoadTestConfig = LoadTestConfig,
  createLoadTestProcess = createLoadTestProcess
}