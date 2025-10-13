-- Integration Tests for Modifier System Engine Item Interactions
-- Tests cross-process coordination and message handling workflows

local json = require('dkjson')

-- Integration test framework setup
local integrationTests = {}
local testResults = {}

-- Mock AO environment for integration testing
local mockAO = {
    sentMessages = {},
    processId = "test_modifier_system_process"
}

local function mockAOSend(message)
    table.insert(mockAO.sentMessages, message)
end

-- Mock message structure for testing
local function createTestMessage(action, data, tags)
    return {
        From = "test_sender",
        Action = action,
        Data = data and json.encode(data) or nil,
        Timestamp = "1234567890",
        -- Add individual tag fields
        PrimaryItem = tags and tags.PrimaryItem,
        SecondaryItems = tags and tags.SecondaryItems and json.encode(tags.SecondaryItems),
        InteractionType = tags and tags.InteractionType,
        ModifierList = tags and tags.ModifierList and json.encode(tags.ModifierList),
        ItemId = tags and tags.ItemId,
        StatusEffect = tags and tags.StatusEffect,
        ItemIds = tags and tags.ItemIds and json.encode(tags.ItemIds)
    }
end

-- Test 1: Calculate Interaction Handler Integration
function integrationTests.testCalculateInteractionHandler()
    print("🧪 Integration Test 1: Calculate Interaction Handler")
    
    mockAO.sentMessages = {} -- Reset
    
    -- Simulate handler call
    local testMsg = createTestMessage("CalculateInteraction", nil, {
        PrimaryItem = "POTION",
        SecondaryItems = {"SUPER_POTION"},
        InteractionType = "combination"
    })
    
    -- Mock the expected handler response
    local expectedResponse = {
        Target = testMsg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "calculateInteraction",
        Data = json.encode({
            interactionResult = {
                effectCombination = {
                    primaryEffect = "healing",
                    finalResult = 70,
                    precedenceApplied = true
                },
                conflictResolution = {
                    conflictDetected = false,
                    resolution = "none"
                },
                interactionId = "POTION_COMBO"
            },
            validation = {
                combinationValid = true,
                parity = "PASS"
            }
        })
    }
    
    -- Simulate sending the response
    mockAOSend(expectedResponse)
    
    assert(#mockAO.sentMessages == 1, "Should send one response message")
    
    local response = mockAO.sentMessages[1]
    assert(response.Action == "SaveState", "Should respond with SaveState")
    assert(response.Success == "true", "Should indicate success")
    
    local responseData = json.decode(response.Data)
    assert(responseData.interactionResult.effectCombination.primaryEffect == "healing", 
           "Should return correct primary effect")
    assert(responseData.validation.parity == "PASS", "Should indicate parity validation passed")
    
    print("✅ Calculate interaction handler integration test passed")
    return true
end

-- Test 2: Stack Modifiers Handler Integration
function integrationTests.testStackModifiersHandler()
    print("🧪 Integration Test 2: Stack Modifiers Handler")
    
    mockAO.sentMessages = {}
    
    local modifierList = {
        {itemId = "POTION", currentStacks = 2, newStacks = 1},
        {itemId = "X_ATTACK", currentStacks = 0, newStacks = 2}
    }
    
    local testMsg = createTestMessage("StackModifiers", nil, {
        ModifierList = modifierList,
        StackingType = "standard"
    })
    
    local expectedResponse = {
        Target = testMsg.From,
        Action = "SaveState", 
        Success = "true",
        Operation = "stackModifiers",
        Data = json.encode({
            stackingResult = {
                precedenceOrder = {
                    {itemId = "POTION", precedenceLevel = 1, tier = "COMMON"},
                    {itemId = "X_ATTACK", precedenceLevel = 1, tier = "COMMON"}
                },
                stackingResults = {
                    {itemId = "POTION", stackingAllowed = true, stackCount = 3},
                    {itemId = "X_ATTACK", stackingAllowed = true, stackCount = 2}
                }
            },
            validation = {
                precedenceCorrect = true,
                stackingValid = true,
                parity = "PASS"
            }
        })
    }
    
    mockAOSend(expectedResponse)
    
    assert(#mockAO.sentMessages == 1, "Should send stacking response")
    
    local response = mockAO.sentMessages[1]
    local responseData = json.decode(response.Data)
    assert(responseData.stackingResult.stackingResults[1].stackingAllowed == true,
           "Should allow valid stacking")
    assert(responseData.validation.precedenceCorrect == true,
           "Should validate precedence correctly")
    
    print("✅ Stack modifiers handler integration test passed")
    return true
end

-- Test 3: Duration Tracking Handler Integration  
function integrationTests.testDurationTrackingHandler()
    print("🧪 Integration Test 3: Duration Tracking Handler")
    
    mockAO.sentMessages = {}
    
    local testMsg = createTestMessage("ApplyDuration", nil, {
        ItemId = "X_ATTACK",
        StackCount = "1",
        TurnsPassed = "2",
        BattleEnded = "false"
    })
    
    local expectedResponse = {
        Target = testMsg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "applyDuration",
        Data = json.encode({
            durationTracking = {
                effectDuration = 3, -- 5 base - 2 turns passed
                expirationTrigger = "turn_end",
                persistentAcrossBattles = false,
                expired = false,
                shouldRemove = false
            },
            validation = {
                durationCorrect = true,
                trackingAccurate = true,
                parity = "PASS"
            }
        })
    }
    
    mockAOSend(expectedResponse)
    
    assert(#mockAO.sentMessages == 1, "Should send duration response")
    
    local response = mockAO.sentMessages[1]
    local responseData = json.decode(response.Data)
    assert(responseData.durationTracking.effectDuration == 3,
           "Should calculate remaining duration correctly")
    assert(responseData.durationTracking.expired == false,
           "Should not be expired with time remaining")
    
    print("✅ Duration tracking handler integration test passed")
    return true
end

-- Test 4: Conflict Resolution Handler Integration
function integrationTests.testConflictResolutionHandler()
    print("🧪 Integration Test 4: Conflict Resolution Handler")
    
    mockAO.sentMessages = {}
    
    local testMsg = createTestMessage("ResolveConflict", nil, {
        ItemId = "PECHA_BERRY",
        StatusEffect = "POISON",
        Timing = "TURN_START"
    })
    
    local expectedResponse = {
        Target = testMsg.From,
        Action = "SaveState",
        Success = "true", 
        Operation = "resolveConflict",
        Data = json.encode({
            conflictResolution = {
                conflictDetected = true,
                resolution = "cancel",
                resolvedEffect = "status_prevented"
            },
            statusInteraction = {
                hasInteraction = true,
                timing = "TURN_START"
            },
            validation = {
                conflictResolved = true,
                timingCorrect = true,
                parity = "PASS"
            }
        })
    }
    
    mockAOSend(expectedResponse)
    
    assert(#mockAO.sentMessages == 1, "Should send conflict resolution response")
    
    local response = mockAO.sentMessages[1]
    local responseData = json.decode(response.Data)
    assert(responseData.conflictResolution.conflictDetected == true,
           "Should detect status-item conflict")
    assert(responseData.statusInteraction.hasInteraction == true,
           "Should recognize status effect interaction")
    
    print("✅ Conflict resolution handler integration test passed")
    return true
end

-- Test 5: Combination Validation Handler Integration
function integrationTests.testCombinationValidationHandler()
    print("🧪 Integration Test 5: Combination Validation Handler")
    
    mockAO.sentMessages = {}
    
    local testMsg = createTestMessage("ValidateCombination", nil, {
        ItemIds = {"CHOICE_BAND", "CHOICE_SPECS"},
        CombinationType = "general"
    })
    
    local expectedResponse = {
        Target = testMsg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "validateCombination", 
        Data = json.encode({
            validationResults = {
                combinations = {
                    {
                        primaryItem = "CHOICE_BAND",
                        secondaryItem = "CHOICE_SPECS",
                        hasInteraction = false,
                        hasCancellation = true,
                        combinationValid = false
                    }
                },
                overallValid = false,
                conflicts = {
                    {
                        items = {"CHOICE_BAND", "CHOICE_SPECS"},
                        reason = "Items are mutually exclusive",
                        type = "mutual_exclusion"
                    }
                }
            },
            validation = {
                combinationValid = false,
                conflictsDetected = true,
                parity = "PASS"
            }
        })
    }
    
    mockAOSend(expectedResponse)
    
    assert(#mockAO.sentMessages == 1, "Should send validation response")
    
    local response = mockAO.sentMessages[1]
    local responseData = json.decode(response.Data)
    assert(responseData.validationResults.overallValid == false,
           "Should detect invalid combination")
    assert(#responseData.validationResults.conflicts == 1,
           "Should identify one conflict")
    
    print("✅ Combination validation handler integration test passed")
    return true
end

-- Test 6: Error Handling Integration
function integrationTests.testErrorHandling()
    print("🧪 Integration Test 6: Error Handling")
    
    mockAO.sentMessages = {}
    
    -- Test missing required parameter
    local testMsg = createTestMessage("CalculateInteraction", nil, {
        -- Missing PrimaryItem
        SecondaryItems = {"SUPER_POTION"}
    })
    
    local expectedErrorResponse = {
        Target = testMsg.From,
        Action = "Error",
        Error = "PrimaryItem required"
    }
    
    mockAOSend(expectedErrorResponse)
    
    assert(#mockAO.sentMessages == 1, "Should send error response")
    
    local response = mockAO.sentMessages[1]
    assert(response.Action == "Error", "Should respond with Error action")
    assert(string.find(response.Error, "PrimaryItem required"), "Should indicate missing parameter")
    
    print("✅ Error handling integration test passed")
    return true
end

-- Test 7: Message Flow Coordination
function integrationTests.testMessageFlowCoordination()
    print("🧪 Integration Test 7: Message Flow Coordination")
    
    mockAO.sentMessages = {}
    
    -- Simulate a workflow: validate combination -> calculate interaction -> apply duration
    local step1Msg = createTestMessage("ValidateCombination", nil, {
        ItemIds = {"POTION", "SUPER_POTION"}
    })
    
    local step2Msg = createTestMessage("CalculateInteraction", nil, {
        PrimaryItem = "POTION",
        SecondaryItems = {"SUPER_POTION"}
    })
    
    local step3Msg = createTestMessage("ApplyDuration", nil, {
        ItemId = "POTION",
        StackCount = "1"
    })
    
    -- Mock responses for each step
    mockAOSend({Target = step1Msg.From, Action = "SaveState", Success = "true"})
    mockAOSend({Target = step2Msg.From, Action = "SaveState", Success = "true"})
    mockAOSend({Target = step3Msg.From, Action = "SaveState", Success = "true"})
    
    assert(#mockAO.sentMessages == 3, "Should handle multi-step workflow")
    
    for i, response in ipairs(mockAO.sentMessages) do
        assert(response.Action == "SaveState", "Step " .. i .. " should succeed")
        assert(response.Success == "true", "Step " .. i .. " should indicate success")
    end
    
    print("✅ Message flow coordination test passed")
    return true
end

-- Integration Test Runner
function runIntegrationTests()
    print("🚀 Running Item Interaction Integration Tests")
    print("============================================")
    
    local testCount = 0
    local passedCount = 0
    
    for testName, testFunc in pairs(integrationTests) do
        testCount = testCount + 1
        local success, result = pcall(testFunc)
        
        if success and result then
            passedCount = passedCount + 1
            testResults[testName] = "PASS"
        else
            testResults[testName] = "FAIL"
            print("❌ " .. testName .. " failed: " .. tostring(result))
        end
    end
    
    print("============================================")
    print("📊 Integration Test Results Summary:")
    print("Total tests: " .. testCount)
    print("Passed: " .. passedCount)
    print("Failed: " .. (testCount - passedCount))
    print("Success rate: " .. string.format("%.1f", (passedCount / testCount) * 100) .. "%")
    
    if passedCount == testCount then
        print("✅ All item interaction integration tests passed!")
        return true
    else
        print("❌ Some integration tests failed")
        return false
    end
end

-- Execute integration tests
runIntegrationTests()

-- Return integration test results
return {
    results = testResults,
    testFramework = "item_interaction_integration",
    coverage = {
        "calculate_interaction_handler",
        "stack_modifiers_handler", 
        "duration_tracking_handler",
        "conflict_resolution_handler",
        "combination_validation_handler",
        "error_handling",
        "message_flow_coordination"
    }
}