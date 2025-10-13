#!/usr/bin/env lua

--[[
Message Volume Testing for AO Process Communication
High-volume message processing validation and stress testing:
- Burst message handling with rate limiting validation
- Message queue depth and processing order verification
- Process communication reliability under load
- Message routing performance and integrity testing
- Error recovery and message retry mechanisms
]]

-- Load testing frameworks
local CoordinationTesting = require('testing.aolite.coordination-testing')
local AdvancedBenchmarks = require('testing.aolite.advanced-benchmarks')

-- Message volume testing configuration
local MessageVolumeConfig = {
  burstSize = 1000,
  sustainedRate = 500, -- messages per second
  testDuration = 10,   -- seconds
  maxQueueDepth = 5000,
  timeoutThreshold = 5000, -- ms
  integrityCheckInterval = 100,
  retryAttempts = 3
}

-- Message tracking and metrics
local MessageMetrics = {
  sentMessages = 0,
  receivedMessages = 0,
  processedMessages = 0,
  droppedMessages = 0,
  duplicateMessages = 0,
  outOfOrderMessages = 0,
  averageLatency = 0,
  peakLatency = 0,
  queueDepths = {},
  errorCounts = {}
}

-- Message volume test scenarios
local MessageVolumeTests = {}

function MessageVolumeTests.testBurstMessageHandling()
  print("💥 Testing burst message handling")

  local processes = {}
  local processCount = 5

  -- Spawn message handling processes
  for i = 1, processCount do
    processes[string.format("handler_%d", i)] = CoordinationTesting.spawnProcess("message-handler", {
      burstCapacity = MessageVolumeConfig.burstSize / processCount,
      queueSize = 1000
    })
  end

  -- Add burst handling capability to processes
  for processName, process in pairs(processes) do
    process.Handlers.add("HandleBurst",
      function(msg) return msg.Tags and msg.Tags.Action == "HandleBurst" end,
      function(msg)
        local data = json.decode(msg.Data)
        local sequenceNumber = data.sequenceNumber

        -- Simulate processing time proportional to message complexity
        local processingTime = math.random(1, 10) / 1000 -- 1-10ms
        local startTime = os.clock()
        while os.clock() - startTime < processingTime do
          -- Busy wait to simulate processing
        end

        ao.send({
          Target = msg.From,
          Action = "SaveState",
          Data = json.encode({
            success = true,
            sequenceNumber = sequenceNumber,
            processId = ao.id,
            processedAt = os.time()
          })
        })
      end
    )
  end

  local startTime = os.clock()
  local burstSize = MessageVolumeConfig.burstSize
  local sentMessages = {}
  local receivedResponses = {}

  print(string.format("  Sending burst of %d messages...", burstSize))

  -- Send burst of messages
  local burstStart = os.clock()
  for i = 1, burstSize do
    local targetProcess = processes[string.format("handler_%d", ((i - 1) % processCount) + 1)]

    local message = {
      Target = targetProcess.id,
      Action = "HandleBurst",
      Data = json.encode({
        sequenceNumber = i,
        complexity = math.random(1, 10),
        timestamp = os.time()
      }),
      Tags = {Action = "HandleBurst", Sequence = tostring(i)}
    }

    sentMessages[i] = {
      sequenceNumber = i,
      sentAt = os.clock(),
      targetProcess = targetProcess.id
    }

    local result = CoordinationTesting.routeMessage("burst_sender", message)
    if not result.success then
      MessageMetrics.droppedMessages = MessageMetrics.droppedMessages + 1
    end
  end
  local burstEnd = os.clock()

  MessageMetrics.sentMessages = burstSize
  local burstTime = burstEnd - burstStart
  local burstRate = burstSize / burstTime

  print(string.format("  Burst sent in %.3fs (%.0f msg/sec)", burstTime, burstRate))

  -- Wait for processing and collect metrics
  local processingTimeout = 30 -- seconds
  local waitStart = os.clock()

  while os.clock() - waitStart < processingTimeout do
    -- Process message queues
    local processedCount = CoordinationTesting.processMessageQueues()
    if processedCount == 0 then
      os.execute("sleep 0.1") -- Brief pause if no messages processed
    end

    -- Check if all messages processed
    local totalProcessed = 0
    for _, process in pairs(processes) do
      totalProcessed = totalProcessed + (process.stats and process.stats.messagesReceived or 0)
    end

    if totalProcessed >= burstSize * 0.95 then -- 95% processed threshold
      break
    end
  end

  local endTime = os.clock()
  local totalTime = endTime - startTime

  -- Calculate final metrics
  local processedCount = 0
  local totalLatency = 0
  local maxLatency = 0

  for _, process in pairs(processes) do
    if process.stats then
      processedCount = processedCount + process.stats.messagesReceived
    end
  end

  MessageMetrics.processedMessages = processedCount
  MessageMetrics.averageLatency = processedCount > 0 and totalLatency / processedCount or 0
  MessageMetrics.peakLatency = maxLatency

  local processingRate = processedCount / totalTime
  local successRate = processedCount / burstSize

  print(string.format("  📊 Burst Test Results:"))
  print(string.format("    Messages sent: %d", burstSize))
  print(string.format("    Messages processed: %d", processedCount))
  print(string.format("    Success rate: %.2f%%", successRate * 100))
  print(string.format("    Processing rate: %.0f msg/sec", processingRate))
  print(string.format("    Total time: %.2fs", totalTime))
  print(string.format("    Dropped messages: %d", MessageMetrics.droppedMessages))

  return {
    success = successRate >= 0.95,
    burstSize = burstSize,
    processedCount = processedCount,
    successRate = successRate,
    processingRate = processingRate,
    totalTime = totalTime,
    droppedMessages = MessageMetrics.droppedMessages
  }
end

function MessageVolumeTests.testSustainedMessageRate()
  print("📡 Testing sustained message rate")

  local processes = {}
  local processCount = 3

  -- Spawn sustained rate handling processes
  for i = 1, processCount do
    processes[string.format("sustained_%d", i)] = CoordinationTesting.spawnProcess("sustained-handler", {
      rateLimit = MessageVolumeConfig.sustainedRate / processCount
    })
  end

  -- Add sustained rate handling
  for processName, process in pairs(processes) do
    process.messageCount = 0
    process.lastProcessTime = os.clock()

    process.Handlers.add("HandleSustained",
      function(msg) return msg.Tags and msg.Tags.Action == "HandleSustained" end,
      function(msg)
        local data = json.decode(msg.Data)
        process.messageCount = process.messageCount + 1

        -- Rate limiting simulation
        local currentTime = os.clock()
        local timeSinceLastProcess = currentTime - process.lastProcessTime
        local expectedInterval = processCount / MessageVolumeConfig.sustainedRate

        if timeSinceLastProcess < expectedInterval then
          -- Simulate rate limiting delay
          local sleepTime = expectedInterval - timeSinceLastProcess
          os.execute(string.format("sleep %.3f", sleepTime))
        end

        process.lastProcessTime = os.clock()

        ao.send({
          Target = msg.From,
          Action = "SaveState",
          Data = json.encode({
            success = true,
            messageId = data.messageId,
            processId = ao.id,
            messageCount = process.messageCount
          })
        })
      end
    )
  end

  local testDuration = MessageVolumeConfig.testDuration
  local targetRate = MessageVolumeConfig.sustainedRate
  local messageInterval = 1.0 / targetRate

  local startTime = os.clock()
  local endTime = startTime + testDuration
  local messageId = 1
  local sentMessages = 0
  local lastSendTime = startTime

  print(string.format("  Sustaining %d msg/sec for %ds...", targetRate, testDuration))

  while os.clock() < endTime do
    local currentTime = os.clock()

    -- Send message if enough time has passed
    if currentTime - lastSendTime >= messageInterval then
      local targetProcess = processes[string.format("sustained_%d", ((messageId - 1) % processCount) + 1)]

      local message = {
        Target = targetProcess.id,
        Action = "HandleSustained",
        Data = json.encode({
          messageId = messageId,
          timestamp = currentTime
        }),
        Tags = {Action = "HandleSustained", MessageId = tostring(messageId)}
      }

      local result = CoordinationTesting.routeMessage("sustained_sender", message)
      if result.success then
        sentMessages = sentMessages + 1
      end

      messageId = messageId + 1
      lastSendTime = currentTime
    else
      -- Brief sleep to prevent busy waiting
      os.execute("sleep 0.001")
    end
  end

  -- Allow processing to complete
  os.execute("sleep 1")
  CoordinationTesting.processMessageQueues()

  local actualDuration = os.clock() - startTime

  -- Collect final metrics
  local totalProcessed = 0
  for _, process in pairs(processes) do
    totalProcessed = totalProcessed + process.messageCount
  end

  local actualRate = sentMessages / actualDuration
  local processedRate = totalProcessed / actualDuration
  local rateAccuracy = actualRate / targetRate
  local processingEfficiency = totalProcessed / sentMessages

  print(string.format("  📊 Sustained Rate Results:"))
  print(string.format("    Target rate: %d msg/sec", targetRate))
  print(string.format("    Actual send rate: %.2f msg/sec", actualRate))
  print(string.format("    Processed rate: %.2f msg/sec", processedRate))
  print(string.format("    Rate accuracy: %.2f%%", rateAccuracy * 100))
  print(string.format("    Processing efficiency: %.2f%%", processingEfficiency * 100))
  print(string.format("    Messages sent: %d", sentMessages))
  print(string.format("    Messages processed: %d", totalProcessed))
  print(string.format("    Duration: %.2fs", actualDuration))

  return {
    success = rateAccuracy >= 0.9 and processingEfficiency >= 0.95,
    targetRate = targetRate,
    actualRate = actualRate,
    processedRate = processedRate,
    rateAccuracy = rateAccuracy,
    processingEfficiency = processingEfficiency,
    sentMessages = sentMessages,
    processedMessages = totalProcessed,
    duration = actualDuration
  }
end

function MessageVolumeTests.testMessageIntegrityUnderLoad()
  print("🔒 Testing message integrity under load")

  local messageCount = 2000
  local processCount = 4
  local processes = {}
  local sentMessages = {}
  local receivedMessages = {}

  -- Spawn integrity testing processes
  for i = 1, processCount do
    processes[string.format("integrity_%d", i)] = CoordinationTesting.spawnProcess("integrity-checker", {
      checksumValidation = true
    })
  end

  -- Add integrity checking handlers
  for processName, process in pairs(processes) do
    process.receivedSequences = {}

    process.Handlers.add("CheckIntegrity",
      function(msg) return msg.Tags and msg.Tags.Action == "CheckIntegrity" end,
      function(msg)
        local data = json.decode(msg.Data)
        local sequenceNumber = data.sequenceNumber
        local checksum = data.checksum
        local payload = data.payload

        -- Verify checksum
        local expectedChecksum = string.len(payload) % 1000 -- Simple checksum
        local checksumValid = checksum == expectedChecksum

        -- Track sequence
        table.insert(process.receivedSequences, sequenceNumber)

        -- Track received message
        receivedMessages[sequenceNumber] = {
          processId = ao.id,
          receivedAt = os.clock(),
          checksumValid = checksumValid,
          payload = payload
        }

        ao.send({
          Target = msg.From,
          Action = "SaveState",
          Data = json.encode({
            success = checksumValid,
            sequenceNumber = sequenceNumber,
            processId = ao.id,
            checksumValid = checksumValid
          })
        })
      end
    )
  end

  local startTime = os.clock()

  print(string.format("  Sending %d messages with integrity checking...", messageCount))

  -- Send messages with integrity data
  for i = 1, messageCount do
    local payload = string.format("Message_%d_%s", i, string.rep("x", math.random(50, 200)))
    local checksum = string.len(payload) % 1000

    local targetProcess = processes[string.format("integrity_%d", ((i - 1) % processCount) + 1)]

    local message = {
      Target = targetProcess.id,
      Action = "CheckIntegrity",
      Data = json.encode({
        sequenceNumber = i,
        checksum = checksum,
        payload = payload,
        timestamp = os.clock()
      }),
      Tags = {Action = "CheckIntegrity", Sequence = tostring(i)}
    }

    sentMessages[i] = {
      sequenceNumber = i,
      checksum = checksum,
      payload = payload,
      sentAt = os.clock()
    }

    CoordinationTesting.routeMessage("integrity_sender", message)
  end

  -- Allow processing
  os.execute("sleep 3")
  CoordinationTesting.processMessageQueues()

  local endTime = os.clock()

  -- Analyze integrity results
  local corruptedMessages = 0
  local missingMessages = 0
  local duplicateMessages = 0
  local outOfOrderCount = 0

  -- Check for missing messages
  for i = 1, messageCount do
    if not receivedMessages[i] then
      missingMessages = missingMessages + 1
    elseif not receivedMessages[i].checksumValid then
      corruptedMessages = corruptedMessages + 1
    end
  end

  -- Check for duplicates and order
  local allReceivedSequences = {}
  for _, process in pairs(processes) do
    for _, seq in ipairs(process.receivedSequences) do
      if allReceivedSequences[seq] then
        duplicateMessages = duplicateMessages + 1
      else
        allReceivedSequences[seq] = true
      end
    end

    -- Check order within each process
    for j = 2, #process.receivedSequences do
      if process.receivedSequences[j] < process.receivedSequences[j-1] then
        outOfOrderCount = outOfOrderCount + 1
      end
    end
  end

  local totalReceived = 0
  for _ in pairs(receivedMessages) do
    totalReceived = totalReceived + 1
  end

  local integrityRate = (totalReceived - corruptedMessages) / messageCount
  local completionRate = totalReceived / messageCount
  local totalTime = endTime - startTime

  print(string.format("  📊 Integrity Test Results:"))
  print(string.format("    Messages sent: %d", messageCount))
  print(string.format("    Messages received: %d", totalReceived))
  print(string.format("    Completion rate: %.2f%%", completionRate * 100))
  print(string.format("    Integrity rate: %.2f%%", integrityRate * 100))
  print(string.format("    Corrupted messages: %d", corruptedMessages))
  print(string.format("    Missing messages: %d", missingMessages))
  print(string.format("    Duplicate messages: %d", duplicateMessages))
  print(string.format("    Out-of-order messages: %d", outOfOrderCount))
  print(string.format("    Total time: %.2fs", totalTime))

  return {
    success = integrityRate >= 0.99 and completionRate >= 0.98,
    messageCount = messageCount,
    totalReceived = totalReceived,
    completionRate = completionRate,
    integrityRate = integrityRate,
    corruptedMessages = corruptedMessages,
    missingMessages = missingMessages,
    duplicateMessages = duplicateMessages,
    outOfOrderCount = outOfOrderCount,
    totalTime = totalTime
  }
end

function MessageVolumeTests.testErrorRecoveryMechanisms()
  print("🔄 Testing error recovery mechanisms")

  local messageCount = 500
  local errorRate = 0.1 -- 10% simulated error rate
  local maxRetries = MessageVolumeConfig.retryAttempts

  local processes = {}
  local processCount = 3

  -- Spawn error-prone processes
  for i = 1, processCount do
    processes[string.format("recovery_%d", i)] = CoordinationTesting.spawnProcess("error-recovery", {
      errorRate = errorRate,
      maxRetries = maxRetries
    })
  end

  -- Add error recovery handlers
  for processName, process in pairs(processes) do
    process.errorCount = 0
    process.retryCount = 0
    process.successCount = 0

    process.Handlers.add("ProcessWithRecovery",
      function(msg) return msg.Tags and msg.Tags.Action == "ProcessWithRecovery" end,
      function(msg)
        local data = json.decode(msg.Data)
        local messageId = data.messageId
        local retryAttempt = data.retryAttempt or 0

        -- Simulate random errors
        local shouldError = math.random() < errorRate

        if shouldError and retryAttempt < maxRetries then
          process.errorCount = process.errorCount + 1

          ao.send({
            Target = msg.From,
            Action = "Error",
            Data = json.encode({
              error = "Simulated processing error",
              messageId = messageId,
              retryAttempt = retryAttempt,
              canRetry = true
            })
          })
        else
          process.successCount = process.successCount + 1

          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              messageId = messageId,
              processId = ao.id,
              retryAttempt = retryAttempt
            })
          })
        end
      end
    )
  end

  local startTime = os.clock()
  local sentMessages = {}
  local finalResults = {}
  local totalRetries = 0

  print(string.format("  Sending %d messages with %.0f%% error simulation...",
    messageCount, errorRate * 100))

  -- Send messages with retry logic
  for i = 1, messageCount do
    local targetProcess = processes[string.format("recovery_%d", ((i - 1) % processCount) + 1)]
    local retryAttempt = 0
    local success = false

    while not success and retryAttempt <= maxRetries do
      local message = {
        Target = targetProcess.id,
        Action = "ProcessWithRecovery",
        Data = json.encode({
          messageId = i,
          retryAttempt = retryAttempt,
          timestamp = os.clock()
        }),
        Tags = {Action = "ProcessWithRecovery", MessageId = tostring(i)}
      }

      local result = CoordinationTesting.routeMessage("recovery_sender", message)

      if result.success and result.response and result.response.success then
        if result.response.result and result.response.result.Action == "SaveState" then
          success = true
          finalResults[i] = {
            messageId = i,
            success = true,
            retryAttempt = retryAttempt,
            finalAttempt = retryAttempt
          }
        elseif result.response.result and result.response.result.Action == "Error" then
          retryAttempt = retryAttempt + 1
          totalRetries = totalRetries + 1

          -- Brief delay before retry
          os.execute("sleep 0.01")
        end
      else
        retryAttempt = retryAttempt + 1
        totalRetries = totalRetries + 1
      end
    end

    if not success then
      finalResults[i] = {
        messageId = i,
        success = false,
        retryAttempt = retryAttempt,
        finalAttempt = retryAttempt
      }
    end

    sentMessages[i] = {
      messageId = i,
      finalSuccess = success,
      totalRetries = retryAttempt
    }
  end

  local endTime = os.clock()

  -- Analyze recovery results
  local successfulMessages = 0
  local failedMessages = 0
  local messagesWithRetries = 0
  local totalAttempts = messageCount

  for _, result in pairs(finalResults) do
    if result.success then
      successfulMessages = successfulMessages + 1
    else
      failedMessages = failedMessages + 1
    end

    if result.retryAttempt > 0 then
      messagesWithRetries = messagesWithRetries + 1
    end

    totalAttempts = totalAttempts + result.retryAttempt
  end

  local recoveryRate = successfulMessages / messageCount
  local retryEffectiveness = messagesWithRetries > 0 and
    (successfulMessages - (messageCount * (1 - errorRate))) / messagesWithRetries or 0
  local totalTime = endTime - startTime

  print(string.format("  📊 Error Recovery Results:"))
  print(string.format("    Messages sent: %d", messageCount))
  print(string.format("    Successful messages: %d", successfulMessages))
  print(string.format("    Failed messages: %d", failedMessages))
  print(string.format("    Recovery rate: %.2f%%", recoveryRate * 100))
  print(string.format("    Total retries: %d", totalRetries))
  print(string.format("    Messages requiring retry: %d", messagesWithRetries))
  print(string.format("    Retry effectiveness: %.2f%%", retryEffectiveness * 100))
  print(string.format("    Total attempts: %d", totalAttempts))
  print(string.format("    Total time: %.2fs", totalTime))

  return {
    success = recoveryRate >= 0.95,
    messageCount = messageCount,
    successfulMessages = successfulMessages,
    failedMessages = failedMessages,
    recoveryRate = recoveryRate,
    totalRetries = totalRetries,
    messagesWithRetries = messagesWithRetries,
    retryEffectiveness = retryEffectiveness,
    totalTime = totalTime
  }
end

-- Main message volume testing execution
local function runMessageVolumeTests()
  print("📨 Running Message Volume Testing Scenarios")
  print(string.rep("=", 60))

  local results = {}

  -- Burst message handling
  print("\n💥 Burst Message Handling")
  results.burstHandling = MessageVolumeTests.testBurstMessageHandling()

  -- Sustained message rate
  print("\n📡 Sustained Message Rate")
  results.sustainedRate = MessageVolumeTests.testSustainedMessageRate()

  -- Message integrity under load
  print("\n🔒 Message Integrity Under Load")
  results.messageIntegrity = MessageVolumeTests.testMessageIntegrityUnderLoad()

  -- Error recovery mechanisms
  print("\n🔄 Error Recovery Mechanisms")
  results.errorRecovery = MessageVolumeTests.testErrorRecoveryMechanisms()

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
  print(string.format("📊 Message Volume Testing Summary: %d/%d tests passed",
    passedTests, totalTests))

  if passedTests == totalTests then
    print("🎉 All message volume tests passed!")
  else
    print("⚠️  Some message volume tests failed - check thresholds")
  end

  return results
end

-- Export message volume testing functions
return {
  runMessageVolumeTests = runMessageVolumeTests,
  MessageVolumeTests = MessageVolumeTests,
  MessageVolumeConfig = MessageVolumeConfig
}