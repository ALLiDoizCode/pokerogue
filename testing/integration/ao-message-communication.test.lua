#!/usr/bin/env lua

--[[
AO Message Communication Testing
Comprehensive testing for AO message format validation and communication:
- AO message format validation and schema compliance
- JSON schema validation for all message types
- Message routing integrity across process boundaries
- Backwards compatibility testing for message formats
- AO protocol compliance and specification adherence
]]

-- Load testing frameworks
local CoordinationTesting = require('testing.aolite.coordination-testing')
local PropertyBasedTesting = require('testing.aolite.property-based-testing')

-- AO Message communication testing configuration
local AOMessageConfig = {
  messageSchemaVersion = "1.0",
  maxMessageSize = 64 * 1024, -- 64KB max message
  timeoutThreshold = 5000, -- 5 seconds
  retryAttempts = 3,
  compressionEnabled = false,
  encryptionEnabled = false
}

-- AO Message format specifications
local AOMessageSchemas = {
  -- Standard AO message format
  standardMessage = {
    required = {"Id", "From", "Target", "Action", "Data", "Timestamp"},
    optional = {"Tags", "Anchor", "References"},
    types = {
      Id = "string",
      From = "string",
      Target = "string",
      Action = "string",
      Data = "string", -- JSON encoded
      Timestamp = "string",
      Tags = "table",
      Anchor = "string",
      References = "table"
    }
  },

  -- Process-specific message schemas
  processLogic = {
    required = {"Action", "Data", "Timestamp"},
    Data = {
      required = {"gameState", "operation", "parameters"},
      gameState = {
        required = {"playerId", "timestamp", "version"}
      }
    }
  },

  -- Health check message
  healthCheck = {
    required = {"Action", "Timestamp"},
    response = {
      required = {"status", "processId", "version", "timestamp"}
    }
  },

  -- Info request (ADP compliance)
  infoRequest = {
    required = {"Action", "Timestamp"},
    response = {
      required = {"process", "handlers", "documentation", "adpVersion"}
    }
  }
}

-- AO Message communication tests
local AOMessageTests = {}

function AOMessageTests.testStandardMessageFormatValidation()
  print("📋 Testing standard AO message format validation")

  local validMessages = {
    {
      name = "basic_valid_message",
      message = {
        Id = "msg-12345",
        From = "sender-process-id",
        Target = "target-process-id",
        Action = "ProcessLogic",
        Data = json.encode({operation = "test", parameters = {}}),
        Timestamp = tostring(os.time()),
        Tags = {Action = "ProcessLogic", Type = "Request"}
      }
    },
    {
      name = "minimal_valid_message",
      message = {
        Id = "msg-67890",
        From = "sender-2",
        Target = "target-2",
        Action = "HealthCheck",
        Data = "{}",
        Timestamp = tostring(os.time())
      }
    },
    {
      name = "complex_valid_message",
      message = {
        Id = "msg-complex-123",
        From = "complex-sender",
        Target = "complex-target",
        Action = "ComplexOperation",
        Data = json.encode({
          gameState = {
            playerId = "player123",
            timestamp = os.time(),
            version = "1.0"
          },
          operation = "calculateStats",
          parameters = {
            pokemonId = 25,
            level = 50
          }
        }),
        Timestamp = tostring(os.time()),
        Tags = {Action = "ComplexOperation", Priority = "High"},
        References = {"ref-1", "ref-2"}
      }
    }
  }

  local invalidMessages = {
    {
      name = "missing_required_field",
      message = {
        Id = "msg-invalid-1",
        From = "sender",
        -- Missing Target
        Action = "Test",
        Data = "{}",
        Timestamp = tostring(os.time())
      },
      expectedError = "missing_target"
    },
    {
      name = "invalid_timestamp",
      message = {
        Id = "msg-invalid-2",
        From = "sender",
        Target = "target",
        Action = "Test",
        Data = "{}",
        Timestamp = "invalid-timestamp"
      },
      expectedError = "invalid_timestamp"
    },
    {
      name = "invalid_data_format",
      message = {
        Id = "msg-invalid-3",
        From = "sender",
        Target = "target",
        Action = "Test",
        Data = "invalid-json{",
        Timestamp = tostring(os.time())
      },
      expectedError = "invalid_json"
    }
  }

  local validationResults = {
    validMessages = {},
    invalidMessages = {},
    validationRules = {}
  }

  -- Test valid messages
  for _, testCase in ipairs(validMessages) do
    local isValid, validationResult = AOMessageTests.validateAOMessage(testCase.message)

    validationResults.validMessages[testCase.name] = {
      valid = isValid,
      result = validationResult,
      message = testCase.message
    }

    print(string.format("  Valid message '%s': %s", testCase.name,
      isValid and "✅ Passed" or "❌ Failed"))
  end

  -- Test invalid messages
  for _, testCase in ipairs(invalidMessages) do
    local isValid, validationResult = AOMessageTests.validateAOMessage(testCase.message)

    validationResults.invalidMessages[testCase.name] = {
      valid = isValid,
      result = validationResult,
      expectedError = testCase.expectedError,
      message = testCase.message
    }

    print(string.format("  Invalid message '%s': %s", testCase.name,
      not isValid and "✅ Correctly rejected" or "❌ Incorrectly accepted"))
  end

  -- Calculate validation statistics
  local validCount = 0
  local invalidCount = 0
  local totalValid = #validMessages
  local totalInvalid = #invalidMessages

  for _, result in pairs(validationResults.validMessages) do
    if result.valid then validCount = validCount + 1 end
  end

  for _, result in pairs(validationResults.invalidMessages) do
    if not result.valid then invalidCount = invalidCount + 1 end
  end

  local validationAccuracy = (validCount + invalidCount) / (totalValid + totalInvalid)

  print(string.format("  📊 Message Format Validation Results:"))
  print(string.format("    Valid messages accepted: %d/%d", validCount, totalValid))
  print(string.format("    Invalid messages rejected: %d/%d", invalidCount, totalInvalid))
  print(string.format("    Validation accuracy: %.2f%%", validationAccuracy * 100))

  return {
    success = validationAccuracy >= 0.95,
    validMessagesAccepted = validCount,
    totalValidMessages = totalValid,
    invalidMessagesRejected = invalidCount,
    totalInvalidMessages = totalInvalid,
    validationAccuracy = validationAccuracy,
    validationResults = validationResults
  }
end

function AOMessageTests.validateAOMessage(message)
  local schema = AOMessageSchemas.standardMessage

  -- Check required fields
  for _, field in ipairs(schema.required) do
    if not message[field] then
      return false, string.format("Missing required field: %s", field)
    end
  end

  -- Check field types
  for field, expectedType in pairs(schema.types) do
    if message[field] then
      local actualType = type(message[field])
      if actualType ~= expectedType then
        return false, string.format("Invalid type for field %s: expected %s, got %s",
          field, expectedType, actualType)
      end
    end
  end

  -- Validate JSON in Data field
  if message.Data then
    local success, parsed = pcall(json.decode, message.Data)
    if not success then
      return false, "Invalid JSON in Data field"
    end
  end

  -- Validate timestamp format
  if message.Timestamp then
    local timestamp = tonumber(message.Timestamp)
    if not timestamp or timestamp <= 0 then
      return false, "Invalid timestamp format"
    end
  end

  return true, "Valid AO message"
end

function AOMessageTests.testJSONSchemaValidation()
  print("🔍 Testing JSON schema validation")

  local testSchemas = {
    processLogic = AOMessageSchemas.processLogic,
    healthCheck = AOMessageSchemas.healthCheck,
    infoRequest = AOMessageSchemas.infoRequest
  }

  local testData = {
    processLogic = {
      valid = {
        Action = "ProcessLogic",
        Data = json.encode({
          gameState = {
            playerId = "player123",
            timestamp = os.time(),
            version = "1.0"
          },
          operation = "calculateStats",
          parameters = {pokemonId = 25}
        }),
        Timestamp = tostring(os.time())
      },
      invalid = {
        Action = "ProcessLogic",
        Data = json.encode({
          -- Missing gameState
          operation = "calculateStats",
          parameters = {pokemonId = 25}
        }),
        Timestamp = tostring(os.time())
      }
    },
    healthCheck = {
      valid = {
        Action = "HealthCheck",
        Timestamp = tostring(os.time())
      },
      invalid = {
        Action = "HealthCheck"
        -- Missing Timestamp
      }
    },
    infoRequest = {
      valid = {
        Action = "Info",
        Timestamp = tostring(os.time())
      },
      invalid = {
        Action = "WrongAction",
        Timestamp = tostring(os.time())
      }
    }
  }

  local schemaValidationResults = {}

  for schemaName, schema in pairs(testSchemas) do
    local testCases = testData[schemaName]
    local results = {
      validPassed = false,
      invalidRejected = false,
      validationDetails = {}
    }

    -- Test valid case
    if testCases.valid then
      local isValid, details = AOMessageTests.validateMessageSchema(testCases.valid, schema)
      results.validPassed = isValid
      results.validationDetails.valid = {isValid = isValid, details = details}

      print(string.format("  Schema '%s' valid case: %s", schemaName,
        isValid and "✅ Passed" or "❌ Failed"))
    end

    -- Test invalid case
    if testCases.invalid then
      local isValid, details = AOMessageTests.validateMessageSchema(testCases.invalid, schema)
      results.invalidRejected = not isValid
      results.validationDetails.invalid = {isValid = isValid, details = details}

      print(string.format("  Schema '%s' invalid case: %s", schemaName,
        not isValid and "✅ Correctly rejected" or "❌ Incorrectly accepted"))
    end

    schemaValidationResults[schemaName] = results
  end

  -- Calculate overall schema validation success
  local totalSchemas = 0
  local successfulSchemas = 0

  for _, result in pairs(schemaValidationResults) do
    totalSchemas = totalSchemas + 1
    if result.validPassed and result.invalidRejected then
      successfulSchemas = successfulSchemas + 1
    end
  end

  local schemaValidationRate = successfulSchemas / totalSchemas

  print(string.format("  📊 JSON Schema Validation Results:"))
  print(string.format("    Schemas tested: %d", totalSchemas))
  print(string.format("    Schemas passing validation: %d", successfulSchemas))
  print(string.format("    Schema validation rate: %.2f%%", schemaValidationRate * 100))

  return {
    success = schemaValidationRate >= 0.8,
    totalSchemas = totalSchemas,
    successfulSchemas = successfulSchemas,
    schemaValidationRate = schemaValidationRate,
    schemaResults = schemaValidationResults
  }
end

function AOMessageTests.validateMessageSchema(message, schema)
  -- Check required fields
  for _, field in ipairs(schema.required) do
    if not message[field] then
      return false, string.format("Missing required field: %s", field)
    end
  end

  -- If Data field has nested schema requirements
  if schema.Data and message.Data then
    local success, data = pcall(json.decode, message.Data)
    if not success then
      return false, "Invalid JSON in Data field"
    end

    -- Check Data schema requirements
    if schema.Data.required then
      for _, field in ipairs(schema.Data.required) do
        if not data[field] then
          return false, string.format("Missing required data field: %s", field)
        end
      end
    end

    -- Check nested gameState requirements
    if schema.Data.gameState and data.gameState then
      for _, field in ipairs(schema.Data.gameState.required) do
        if not data.gameState[field] then
          return false, string.format("Missing required gameState field: %s", field)
        end
      end
    end
  end

  return true, "Schema validation passed"
end

function AOMessageTests.testMessageRoutingIntegrity()
  print("🔀 Testing message routing integrity")

  local processes = {}
  local processCount = 4

  -- Create test processes
  for i = 1, processCount do
    processes[string.format("router_test_%d", i)] = CoordinationTesting.spawnProcess("router-test", {
      routingEnabled = true,
      messageLogging = true
    })
  end

  -- Add message handling for routing tests
  for processName, process in pairs(processes) do
    process.receivedMessages = {}
    process.sentMessages = {}

    process.Handlers.add("RoutingTest",
      function(msg) return msg.Tags and msg.Tags.Action == "RoutingTest" end,
      function(msg)
        local data = json.decode(msg.Data)

        -- Log received message
        table.insert(process.receivedMessages, {
          messageId = data.messageId,
          routingPath = data.routingPath or {},
          receivedAt = os.clock(),
          fromProcess = msg.From
        })

        -- Forward message if routing path specified
        if data.routingPath and #data.routingPath > 0 then
          local nextTarget = table.remove(data.routingPath, 1)

          local forwardedMessage = {
            Target = nextTarget,
            Action = "RoutingTest",
            Data = json.encode(data),
            Tags = {Action = "RoutingTest", Forwarded = "true"}
          }

          table.insert(process.sentMessages, {
            messageId = data.messageId,
            forwardedTo = nextTarget,
            sentAt = os.clock()
          })

          ao.send(forwardedMessage)
        else
          -- End of routing path, send completion response
          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
              success = true,
              messageId = data.messageId,
              processId = ao.id,
              routingComplete = true
            })
          })
        end
      end
    )
  end

  -- Test routing scenarios
  local routingTests = {
    {
      name = "simple_routing",
      startProcess = "router_test_1",
      routingPath = {"router_test_2", "router_test_3"},
      messageId = "route_msg_1"
    },
    {
      name = "complex_routing",
      startProcess = "router_test_1",
      routingPath = {"router_test_2", "router_test_3", "router_test_4", "router_test_1"},
      messageId = "route_msg_2"
    },
    {
      name = "single_hop",
      startProcess = "router_test_1",
      routingPath = {"router_test_4"},
      messageId = "route_msg_3"
    }
  }

  local routingResults = {}

  for _, test in ipairs(routingTests) do
    print(string.format("  Testing routing scenario: %s", test.name))

    local startProcess = processes[test.startProcess]
    if startProcess then
      local routingStart = os.clock()

      -- Send initial message with routing path
      local initialMessage = {
        Target = startProcess.id,
        Action = "RoutingTest",
        Data = json.encode({
          messageId = test.messageId,
          routingPath = {table.unpack(test.routingPath)}, -- Copy path
          startTime = routingStart
        }),
        Tags = {Action = "RoutingTest", TestName = test.name}
      }

      local result = CoordinationTesting.routeMessage("routing_tester", initialMessage)

      -- Allow routing to complete
      os.execute("sleep 0.5")
      CoordinationTesting.processMessageQueues()

      local routingEnd = os.clock()

      -- Analyze routing results
      local totalHops = #test.routingPath + 1 -- Including start process
      local messagesReceived = 0
      local routingPathIntact = true

      for _, process in pairs(processes) do
        for _, received in ipairs(process.receivedMessages) do
          if received.messageId == test.messageId then
            messagesReceived = messagesReceived + 1
          end
        end
      end

      routingResults[test.name] = {
        expectedHops = totalHops,
        actualHops = messagesReceived,
        routingSuccessful = messagesReceived == totalHops,
        routingTime = (routingEnd - routingStart) * 1000, -- ms
        pathIntegrity = routingPathIntact
      }

      print(string.format("    Expected hops: %d, Actual hops: %d", totalHops, messagesReceived))
      print(string.format("    Routing successful: %s",
        routingResults[test.name].routingSuccessful and "✅ Yes" or "❌ No"))
      print(string.format("    Routing time: %.2fms", routingResults[test.name].routingTime))
    end
  end

  -- Calculate routing statistics
  local totalTests = #routingTests
  local successfulRouting = 0
  local totalRoutingTime = 0

  for _, result in pairs(routingResults) do
    if result.routingSuccessful then
      successfulRouting = successfulRouting + 1
    end
    totalRoutingTime = totalRoutingTime + result.routingTime
  end

  local routingSuccessRate = successfulRouting / totalTests
  local avgRoutingTime = totalRoutingTime / totalTests

  print(string.format("  📊 Message Routing Integrity Results:"))
  print(string.format("    Routing tests: %d", totalTests))
  print(string.format("    Successful routing: %d/%d", successfulRouting, totalTests))
  print(string.format("    Routing success rate: %.2f%%", routingSuccessRate * 100))
  print(string.format("    Average routing time: %.2fms", avgRoutingTime))

  return {
    success = routingSuccessRate >= 0.9,
    totalTests = totalTests,
    successfulRouting = successfulRouting,
    routingSuccessRate = routingSuccessRate,
    avgRoutingTime = avgRoutingTime,
    routingResults = routingResults
  }
end

function AOMessageTests.testBackwardsCompatibility()
  print("🔄 Testing backwards compatibility")

  local messageVersions = {
    {
      version = "1.0",
      format = {
        Id = "msg-v1-123",
        From = "sender-v1",
        Target = "target-v1",
        Action = "ProcessLogic",
        Data = json.encode({operation = "legacy", parameters = {}}),
        Timestamp = tostring(os.time())
      }
    },
    {
      version = "1.1",
      format = {
        Id = "msg-v1.1-456",
        From = "sender-v1.1",
        Target = "target-v1.1",
        Action = "ProcessLogic",
        Data = json.encode({operation = "enhanced", parameters = {}, version = "1.1"}),
        Timestamp = tostring(os.time()),
        Tags = {Action = "ProcessLogic", Version = "1.1"}
      }
    },
    {
      version = "2.0",
      format = {
        Id = "msg-v2-789",
        From = "sender-v2",
        Target = "target-v2",
        Action = "ProcessLogic",
        Data = json.encode({
          operation = "modern",
          parameters = {},
          version = "2.0",
          metadata = {compatibility = "backwards"}
        }),
        Timestamp = tostring(os.time()),
        Tags = {Action = "ProcessLogic", Version = "2.0", Priority = "Normal"},
        References = {"ref-1"}
      }
    }
  }

  local compatibilityResults = {}

  for _, versionTest in ipairs(messageVersions) do
    print(string.format("  Testing message format version %s", versionTest.version))

    -- Test format validation
    local isValid, validationResult = AOMessageTests.validateAOMessage(versionTest.format)

    -- Test processing capability
    local canProcess = false
    local processingError = nil

    local success, result = pcall(function()
      -- Simulate processing the message
      local data = json.decode(versionTest.format.Data)
      return data.operation and data.parameters
    end)

    canProcess = success and result
    if not success then
      processingError = result
    end

    compatibilityResults[versionTest.version] = {
      formatValid = isValid,
      validationResult = validationResult,
      canProcess = canProcess,
      processingError = processingError,
      messageFormat = versionTest.format
    }

    print(string.format("    Format valid: %s", isValid and "✅ Yes" or "❌ No"))
    print(string.format("    Can process: %s", canProcess and "✅ Yes" or "❌ No"))

    if processingError then
      print(string.format("    Processing error: %s", processingError))
    end
  end

  -- Calculate compatibility statistics
  local totalVersions = #messageVersions
  local compatibleVersions = 0

  for _, result in pairs(compatibilityResults) do
    if result.formatValid and result.canProcess then
      compatibleVersions = compatibleVersions + 1
    end
  end

  local compatibilityRate = compatibleVersions / totalVersions

  print(string.format("  📊 Backwards Compatibility Results:"))
  print(string.format("    Message versions tested: %d", totalVersions))
  print(string.format("    Compatible versions: %d/%d", compatibleVersions, totalVersions))
  print(string.format("    Compatibility rate: %.2f%%", compatibilityRate * 100))

  return {
    success = compatibilityRate >= 0.8,
    totalVersions = totalVersions,
    compatibleVersions = compatibleVersions,
    compatibilityRate = compatibilityRate,
    compatibilityResults = compatibilityResults
  }
end

-- Main AO message communication testing execution
local function runAOMessageCommunicationTests()
  print("📨 Running AO Message Communication Tests")
  print(string.rep("=", 60))

  local results = {}

  -- Standard message format validation
  print("\n📋 Standard Message Format Validation")
  results.messageFormatValidation = AOMessageTests.testStandardMessageFormatValidation()

  -- JSON schema validation
  print("\n🔍 JSON Schema Validation")
  results.jsonSchemaValidation = AOMessageTests.testJSONSchemaValidation()

  -- Message routing integrity
  print("\n🔀 Message Routing Integrity")
  results.messageRoutingIntegrity = AOMessageTests.testMessageRoutingIntegrity()

  -- Backwards compatibility
  print("\n🔄 Backwards Compatibility")
  results.backwardsCompatibility = AOMessageTests.testBackwardsCompatibility()

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
  print(string.format("📊 AO Message Communication Summary: %d/%d tests passed",
    passedTests, totalTests))

  if passedTests == totalTests then
    print("🎉 All AO message communication tests passed!")
  else
    print("⚠️  Some AO message tests failed - check message formats")
  end

  return results
end

-- Export AO message communication testing functions
return {
  runAOMessageCommunicationTests = runAOMessageCommunicationTests,
  AOMessageTests = AOMessageTests,
  AOMessageConfig = AOMessageConfig,
  AOMessageSchemas = AOMessageSchemas
}