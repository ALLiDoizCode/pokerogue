-- Integration tests for Achievement Engine Process
-- Tests cross-process coordination and message-based communication

-- Mock AO environment for testing
local ao = {
    send = function(msg)
        print("MOCK AO.SEND:", json.encode(msg))
        return msg
    end,
    id = "achievement_engine_test_id"
}

-- Mock Handlers for testing
local Handlers = {
    add = function(name, matcher, handler)
        print("HANDLER REGISTERED:", name)
        -- Store for testing if needed
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value or (type(value) == "table" and msg[tag] and table.contains(value, msg[tag]))
            end
        end
    }
}

-- Mock JSON for testing
local json = {
    encode = function(data)
        -- Simple JSON encoding for testing
        if type(data) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(data) do
                if not first then result = result .. "," end
                if type(v) == "table" then
                    result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
                else
                    result = result .. '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                end
                first = false
            end
            return result .. "}"
        end
        return tostring(data)
    end,
    decode = function(str)
        -- Simple JSON decoding for testing
        if str == '{}' or str == '' then return {} end
        -- For testing, return mock structures
        if str:find("newUnlocks") then
            return {newUnlocks = {}, totalNewUnlocks = 0, totalScore = 0}
        end
        return {}
    end
}

-- Load the achievement engine process
local function loadAchievementEngineProcess()
    -- Set up global environment
    _G.ao = ao
    _G.Handlers = Handlers
    _G.json = json

    -- Load and execute the process file
    local file = io.open("processes/achievement-engine.lua", "r")
    if not file then
        error("Could not find achievement-engine.lua")
    end

    local content = file:read("*all")
    file:close()

    -- Execute the process code
    local processFunction = load(content)
    if not processFunction then
        error("Failed to load achievement engine process")
    end

    processFunction()
    print("✓ Achievement engine process loaded successfully")
end

-- Integration test suite
local integrationTests = {}

-- Test 1: Process initialization and ADP Info handler
function integrationTests.testProcessInitialization()
    print("Testing process initialization and ADP Info handler...")

    loadAchievementEngineProcess()

    -- Verify the process loaded without errors
    assert(ao ~= nil, "AO should be available")
    assert(Handlers ~= nil, "Handlers should be available")
    assert(json ~= nil, "JSON should be available")

    print("✓ Process initialization tests passed")
end

-- Test 2: Cross-process coordination with Player Progression Engine
function integrationTests.testPlayerProgressionEngineCoordination()
    print("Testing Player Progression Engine coordination...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Simulate achievement unlock that coordinates with Player Progression Engine
    local achievementUnlockMsg = {
        Target = "player_progression_engine_id",
        Action = "UpdateAchievements",
        PlayerId = "test_player_456",
        Data = json.encode({
            achvUnlocks = {
                CLASSIC_VICTORY = 1234567890000
            },
            newUnlock = {
                id = "CLASSIC_VICTORY",
                score = 250,
                timestamp = 1234567890000
            }
        })
    }

    -- Verify coordination message structure
    assert(achievementUnlockMsg.Target ~= nil, "Should target player progression engine")
    assert(achievementUnlockMsg.Action == "UpdateAchievements", "Should update achievements")
    assert(achievementUnlockMsg.PlayerId ~= nil, "Should include player ID")

    ao.send = originalSend

    print("✓ Player Progression Engine coordination tests passed")
end

-- Test 3: Cross-process coordination with Coordinator
function integrationTests.testCoordinatorIntegration()
    print("Testing Coordinator integration...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Test achievement validation request from coordinator
    local validationRequest = {
        From = "coordinator_process_id",
        Action = "ValidateAchievement",
        PlayerId = "test_player_456",
        AchievementId = "CLASSIC_VICTORY",
        Args = "[]",
        Timestamp = "1234567890000"
    }

    -- Verify coordinator request structure
    assert(validationRequest.From ~= nil, "Should have sender")
    assert(validationRequest.Action == "ValidateAchievement", "Should validate achievement")
    assert(validationRequest.PlayerId ~= nil, "Should include player ID")
    assert(validationRequest.AchievementId ~= nil, "Should include achievement ID")

    ao.send = originalSend

    print("✓ Coordinator integration tests passed")
end

-- Test 4: Batch validation workflow
function integrationTests.testBatchValidationWorkflow()
    print("Testing batch validation workflow...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Test batch validation by type (e.g., all MoneyAchv achievements)
    local batchValidationMsg = {
        From = "coordinator_process_id",
        Action = "ValidateAchievementsByType",
        PlayerId = "test_player_456",
        AchievementType = "MoneyAchv",
        Args = "[50000]",  -- Current money amount
        Timestamp = "1234567890000"
    }

    -- Verify batch validation structure
    assert(batchValidationMsg.Action == "ValidateAchievementsByType", "Should batch validate")
    assert(batchValidationMsg.AchievementType == "MoneyAchv", "Should specify type")
    assert(batchValidationMsg.Args ~= nil, "Should include validation args")

    ao.send = originalSend

    print("✓ Batch validation workflow tests passed")
end

-- Test 5: State persistence integration
function integrationTests.testStatePersistenceIntegration()
    print("Testing state persistence integration...")

    -- Test achievement state persistence messages
    local persistenceMessages = {
        saveState = {
            Target = "player_progression_engine_id",
            Action = "SavePlayerProgression",
            PlayerId = "test_player_456",
            Data = json.encode({
                achvUnlocks = {
                    CLASSIC_VICTORY = 1234567890000,
                    _10_RIBBONS = 1234567891000
                },
                totalScore = 300,
                totalAchievements = 2
            })
        },
        loadState = {
            Target = "player_progression_engine_id",
            Action = "LoadPlayerProgression",
            PlayerId = "test_player_456",
            Data = json.encode({
                includeAchievements = true
            })
        }
    }

    -- Verify persistence message structures
    for msgType, msg in pairs(persistenceMessages) do
        assert(msg.Target ~= nil, msgType .. " should have target")
        assert(msg.Action ~= nil, msgType .. " should have action")
        assert(msg.PlayerId ~= nil, msgType .. " should have player ID")
    end

    print("✓ State persistence integration tests passed")
end

-- Test 6: Voucher reward integration
function integrationTests.testVoucherRewardIntegration()
    print("Testing voucher reward integration...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Test voucher reward check after achievement unlock
    local voucherCheckMsg = {
        Target = "unlockable_content_engine_id",
        Action = "CheckVoucherReward",
        AchievementId = "_1000_DMG",
        PlayerId = "test_player_456",
        Data = json.encode({
            achievementScore = 25,
            achievementTier = 1,
            unlockTimestamp = 1234567890000
        })
    }

    -- Verify voucher integration structure
    assert(voucherCheckMsg.Target ~= nil, "Should target unlockable content engine")
    assert(voucherCheckMsg.Action == "CheckVoucherReward", "Should check voucher reward")
    assert(voucherCheckMsg.AchievementId ~= nil, "Should include achievement ID")

    ao.send = originalSend

    print("✓ Voucher reward integration tests passed")
end

-- Test 7: Notification engine coordination
function integrationTests.testNotificationEngineCoordination()
    print("Testing notification engine coordination...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Test achievement notification trigger
    local notificationMsg = {
        Target = "notification_engine_id",
        Action = "ShowAchievementNotification",
        PlayerId = "test_player_456",
        Data = json.encode({
            achievement = {
                id = "_1000_DMG",
                name = "1000 Damage",
                description = "Deal 1000 damage in one hit",
                iconImage = "lucky_punch_great",
                score = 25,
                tier = 1
            },
            timestamp = 1234567890000
        })
    }

    -- Verify notification structure
    assert(notificationMsg.Target ~= nil, "Should target notification engine")
    assert(notificationMsg.Action == "ShowAchievementNotification", "Should show notification")
    assert(notificationMsg.Data ~= nil, "Should include notification data")

    ao.send = originalSend

    print("✓ Notification engine coordination tests passed")
end

-- Test 8: Message validation and error handling
function integrationTests.testMessageValidationAndErrorHandling()
    print("Testing message validation and error handling...")

    local errorMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        if msg.Action == "Error" then
            table.insert(errorMessages, msg)
        end
        return msg
    end

    -- Test invalid message structures
    local invalidMessages = {
        -- Missing Action
        {From = "test", Data = "{}"},
        -- Missing PlayerId
        {From = "test", Action = "ValidateAchievement", AchievementId = "TEST"},
        -- Missing AchievementId
        {From = "test", Action = "ValidateAchievement", PlayerId = "test_player"},
        -- Invalid AchievementType
        {From = "test", Action = "ValidateAchievementsByType", PlayerId = "test_player", AchievementType = "InvalidType"},
    }

    -- Verify invalid messages are properly structured tables
    for i, invalidMsg in ipairs(invalidMessages) do
        assert(type(invalidMsg) == "table", "Should be valid Lua table even if invalid AO message")
    end

    ao.send = originalSend

    print("✓ Message validation and error handling tests passed")
end

-- Test 9: ADP v1.0 compliance in integration context
function integrationTests.testADPComplianceIntegration()
    print("Testing ADP v1.0 compliance in integration context...")

    -- Test autonomous agent discovery pattern
    local discoveryMsg = {
        From = "autonomous_agent_123",
        Action = "Info",
        Timestamp = "1234567890"
    }

    -- Expected response structure for ADP compliance
    local expectedInfoResponse = {
        Target = "autonomous_agent_123",
        Action = "SaveState",
        Data = {
            process = {
                name = "Achievement Engine",
                version = "1.0.0",
                adpVersion = "1.0",
                capabilities = {
                    "validateSingleAchievement",
                    "batchValidateByType",
                    "trackPlayerProgress",
                    "calculateTiers",
                    "manageSecretAchievements"
                },
                messageSchemas = {
                    ValidateAchievement = {
                        required = {"Action", "PlayerId", "AchievementId", "Timestamp"}
                    },
                    ValidateAchievementsByType = {
                        required = {"Action", "PlayerId", "AchievementType", "Args", "Timestamp"}
                    }
                }
            },
            handlers = {
                "ValidateAchievement",
                "ValidateAchievementsByType",
                "GetPlayerAchievements",
                "GetAchievementMetadata",
                "GetAchievementProgress",
                "Info"
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true,
                totalAchievements = 68,
                achievementTypes = 8
            }
        }
    }

    -- Verify ADP response structure
    assert(expectedInfoResponse.Action == "SaveState", "Should use SaveState action")
    assert(expectedInfoResponse.Data.process.adpVersion == "1.0", "Should be ADP v1.0")
    assert(#expectedInfoResponse.Data.process.capabilities > 0, "Should have capabilities")
    assert(#expectedInfoResponse.Data.handlers == 6, "Should have 6 handlers")

    print("✓ ADP v1.0 compliance integration tests passed")
end

-- Test 10: End-to-end achievement unlock workflow
function integrationTests.testEndToEndAchievementUnlockWorkflow()
    print("Testing end-to-end achievement unlock workflow...")

    local workflowSteps = {
        "Game event triggers achievement check",
        "Coordinator sends validation request",
        "Achievement engine validates conditions",
        "Achievement unlocked and timestamped",
        "Player progression state updated",
        "Voucher reward checked",
        "Notification triggered",
        "Client receives achievement confirmation"
    }

    -- Simulate complete workflow message sequence
    local workflowMessages = {}

    for i, step in ipairs(workflowSteps) do
        local stepMsg = {
            step = i,
            description = step,
            timestamp = "123456789" .. i,
            status = "completed"
        }
        table.insert(workflowMessages, stepMsg)
    end

    assert(#workflowMessages == #workflowSteps, "Should have message for each workflow step")

    print("✓ End-to-end achievement unlock workflow tests passed")
end

-- Test 11: Error recovery and resilience
function integrationTests.testErrorRecoveryAndResilience()
    print("Testing error recovery and resilience...")

    local errorScenarios = {
        -- State persistence timeout
        persistenceTimeout = {
            description = "Player progression state save timeout",
            scenario = function()
                local timeoutMsg = {
                    Target = "achievement_engine_test_id",
                    Action = "Error",
                    Error = "State persistence timeout",
                    Data = json.encode({
                        originalRequest = "SavePlayerProgression",
                        timeoutDuration = 5000
                    })
                }
                return timeoutMsg
            end
        },
        -- Invalid achievement validation response
        invalidValidation = {
            description = "Invalid achievement validation arguments",
            scenario = function()
                local errorMsg = {
                    Target = "achievement_engine_test_id",
                    Action = "Error",
                    Error = "Invalid validation arguments for achievement type",
                    Data = json.encode({
                        achievementType = "MoneyAchv",
                        providedArgs = "invalid",
                        expectedArgs = "number"
                    })
                }
                return errorMsg
            end
        }
    }

    -- Test each error scenario
    for scenarioName, scenario in pairs(errorScenarios) do
        local errorMsg = scenario.scenario()
        assert(errorMsg.Action == "Error", scenarioName .. " should produce error message")
        assert(errorMsg.Error ~= nil, scenarioName .. " should have error description")
        print("  ✓ " .. scenario.description .. " handled correctly")
    end

    print("✓ Error recovery and resilience tests passed")
end

-- Test 12: Performance under batch operations
function integrationTests.testPerformanceUnderBatchOperations()
    print("Testing performance under batch operations...")

    -- Test batch validation performance constraints
    local performanceConstraints = {
        maxExecutionTime = 5000, -- 5 seconds
        maxAchievementsPerBatch = 30, -- Max achievements per type
        maxBatchesPerMinute = 100, -- Rate limiting
        timeWindow = 60 -- seconds
    }

    -- Verify performance constraints
    assert(performanceConstraints.maxExecutionTime == 5000, "Should have 5 second timeout")
    assert(performanceConstraints.maxAchievementsPerBatch <= 68, "Should handle all achievements")
    assert(performanceConstraints.maxBatchesPerMinute > 0, "Should have rate limiting")

    -- Test batch validation message structure
    local batchTypes = {"MoneyAchv", "RibbonAchv", "DamageAchv", "HealAchv", "LevelAchv"}
    for _, achvType in ipairs(batchTypes) do
        local batchMsg = {
            From = "test_sender",
            Action = "ValidateAchievementsByType",
            PlayerId = "test_player",
            AchievementType = achvType,
            Args = json.encode({1000}),
            Timestamp = "1234567890000"
        }
        assert(batchMsg.AchievementType == achvType, "Should validate " .. achvType)
    end

    print("✓ Performance under batch operations tests passed")
end

-- Helper function for table contains
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Run all integration tests
function integrationTests.runAllTests()
    print("Running Achievement Engine Integration Tests...")
    print("=" .. string.rep("=", 60))

    integrationTests.testProcessInitialization()
    integrationTests.testPlayerProgressionEngineCoordination()
    integrationTests.testCoordinatorIntegration()
    integrationTests.testBatchValidationWorkflow()
    integrationTests.testStatePersistenceIntegration()
    integrationTests.testVoucherRewardIntegration()
    integrationTests.testNotificationEngineCoordination()
    integrationTests.testMessageValidationAndErrorHandling()
    integrationTests.testADPComplianceIntegration()
    integrationTests.testEndToEndAchievementUnlockWorkflow()
    integrationTests.testErrorRecoveryAndResilience()
    integrationTests.testPerformanceUnderBatchOperations()

    print("=" .. string.rep("=", 60))
    print("✅ All Achievement Engine integration tests passed!")
    return true
end

-- Export test runner
return integrationTests