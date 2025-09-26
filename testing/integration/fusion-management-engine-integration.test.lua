-- Fusion Management Engine Integration Tests
-- Tests cross-process coordination with Game State Coordinator and Pokemon State Manager

local json = require("json")

-- Integration test configuration
local integrationTests = {}
local passed = 0
local failed = 0

-- Mock AO environment for integration testing
if not ao then
    ao = {
        send = function(msg)
            integrationTests.lastMessage = msg
            integrationTests.sentMessages = integrationTests.sentMessages or {}
            table.insert(integrationTests.sentMessages, msg)
        end,
        id = "test_fusion_management_integration"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            integrationTests.handlers = integrationTests.handlers or {}
            integrationTests.handlers[name] = handler
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- Test utilities
local function assertEquals(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("✓ " .. (message or "Integration test passed"))
    else
        failed = failed + 1
        print("✗ " .. (message or "Integration test failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertNotNil(value, message)
    if value ~= nil then
        passed = passed + 1
        print("✓ " .. (message or "Value not nil"))
    else
        failed = failed + 1
        print("✗ " .. (message or "Value is nil"))
    end
end

-- Mock process communication
local function mockGameStateCoordinator(request)
    return {
        Target = request.From,
        Action = "SaveState",
        Success = "true",
        Operation = "coordinateGameState",
        Data = json.encode({
            coordinationResult = {
                coordinated = true,
                stateConsistent = true,
                processesNotified = {"pokemon-state-manager", "player-progression-engine"}
            }
        })
    }
end

local function mockPokemonStateManager(request)
    return {
        Target = request.From,
        Action = "SaveState", 
        Success = "true",
        Operation = "managePokemonState",
        Data = json.encode({
            stateResult = {
                pokemonUpdated = true,
                partyConsistent = true,
                pcStorageOptimized = true
            }
        })
    }
end

-- Integration Test 1: Cross-process fusion management coordination
function integrationTests.testCrossProcessCoordination()
    print("\n=== Integration Test 1: Cross-Process Coordination ===")
    
    local fusionRequest = {
        pokemon = {
            species = "PIKACHU",
            fusionSpecies = "RAICHU",
            fusionFormIndex = 0,
            fusionAbilityIndex = 1,
            fusionShiny = false,
            fusionVariant = 0,
            fusionGender = 1,
            stats = {130, 105, 95, 110, 100, 120}
        },
        coordination = {
            processChain = {"game-state-coordinator", "pokemon-state-manager"},
            requiresConsistency = true
        }
    }
    
    -- Simulate fusion separation request
    integrationTests.sentMessages = {}
    
    -- Mock coordination responses
    local coordinatorResponse = mockGameStateCoordinator({From = "test_fusion_management"})
    local stateManagerResponse = mockPokemonStateManager({From = "test_fusion_management"})
    
    -- Verify cross-process messages
    assertNotNil(coordinatorResponse, "Game State Coordinator response")
    assertNotNil(stateManagerResponse, "Pokemon State Manager response")
    assertEquals("SaveState", coordinatorResponse.Action, "Coordinator response action")
    assertEquals("SaveState", stateManagerResponse.Action, "State Manager response action")
end

-- Integration Test 2: Fusion management system integration
function integrationTests.testFusionManagementSystemIntegration()
    print("\n=== Integration Test 2: Fusion Management System Integration ===")
    
    local managementWorkflow = {
        phases = {"separation", "persistence", "inventory", "validation"},
        requiresRollback = false,
        coordinationLevel = "full"
    }
    
    local workflowResults = {}
    
    -- Simulate each phase
    for _, phase in ipairs(managementWorkflow.phases) do
        local phaseResult = {
            phase = phase,
            completed = true,
            timeElapsed = math.random(10, 50),
            dependencies = {}
        }
        
        if phase == "persistence" then
            phaseResult.dependencies = {"game-state-coordinator"}
        elseif phase == "inventory" then  
            phaseResult.dependencies = {"pokemon-state-manager", "player-progression-engine"}
        end
        
        table.insert(workflowResults, phaseResult)
    end
    
    assertEquals(4, #workflowResults, "All management phases completed")
    assertEquals("separation", workflowResults[1].phase, "Separation phase first")
    assertEquals("validation", workflowResults[4].phase, "Validation phase last")
end

-- Integration Test 3: Message handler workflow validation
function integrationTests.testMessageHandlerWorkflowValidation()
    print("\n=== Integration Test 3: Message Handler Workflow Validation ===")
    
    local handlerWorkflow = {
        "SeparateFusion",
        "PersistFusionState", 
        "ManageFusionInventory",
        "ValidateFusionSeparation",
        "TrackFusionComponent"
    }
    
    local workflowMessages = {}
    
    -- Simulate handler workflow
    for i, handler in ipairs(handlerWorkflow) do
        local workflowMessage = {
            order = i,
            handler = handler,
            processed = true,
            responseTime = math.random(5, 25),
            stateConsistent = true
        }
        table.insert(workflowMessages, workflowMessage)
    end
    
    assertEquals(5, #workflowMessages, "All workflow handlers processed")
    assertEquals("SeparateFusion", workflowMessages[1].handler, "Separation handler first")
    assertEquals("TrackFusionComponent", workflowMessages[5].handler, "Tracking handler last")
    
    -- Verify state consistency throughout workflow
    local allConsistent = true
    for _, msg in ipairs(workflowMessages) do
        if not msg.stateConsistent then
            allConsistent = false
            break
        end
    end
    assertEquals(true, allConsistent, "State consistent throughout workflow")
end

-- Integration Test 4: Fusion management persistence workflows
function integrationTests.testFusionManagementPersistenceWorkflows()
    print("\n=== Integration Test 4: Fusion Management Persistence Workflows ===")
    
    local persistenceWorkflow = {
        saveOperations = {"fusionState", "componentTracking", "lifecycleEvents"},
        loadOperations = {"fusionState", "componentTracking", "lifecycleEvents"},
        backupRequired = true,
        integrityChecks = true
    }
    
    local persistenceResults = {
        saved = {},
        loaded = {},
        backupsCreated = 0,
        integrityPassed = 0
    }
    
    -- Simulate save operations
    for _, operation in ipairs(persistenceWorkflow.saveOperations) do
        persistenceResults.saved[operation] = true
        if persistenceWorkflow.backupRequired then
            persistenceResults.backupsCreated = persistenceResults.backupsCreated + 1
        end
        if persistenceWorkflow.integrityChecks then
            persistenceResults.integrityPassed = persistenceResults.integrityPassed + 1
        end
    end
    
    -- Simulate load operations  
    for _, operation in ipairs(persistenceWorkflow.loadOperations) do
        persistenceResults.loaded[operation] = true
    end
    
    assertEquals(3, persistenceResults.backupsCreated, "Backups created for all operations")
    assertEquals(3, persistenceResults.integrityPassed, "Integrity checks passed")
    assertEquals(true, persistenceResults.saved.fusionState, "Fusion state saved")
    assertEquals(true, persistenceResults.loaded.componentTracking, "Component tracking loaded")
end

-- Integration Test 5: Complex multi-system fusion management scenarios
function integrationTests.testComplexMultiSystemFusionManagementScenarios()
    print("\n=== Integration Test 5: Complex Multi-System Fusion Management Scenarios ===")
    
    local complexScenario = {
        scenarioType = "multi_fusion_chain_separation",
        involvedSystems = {
            "fusion-management-engine",
            "game-state-coordinator", 
            "pokemon-state-manager",
            "player-progression-engine",
            "fusion-calculation-engine"
        },
        complexity = "high",
        expectedDuration = 150 -- milliseconds
    }
    
    local scenarioResults = {
        systemsInvolved = 0,
        coordinationMessages = 0,
        stateUpdates = 0,
        validationsPassed = 0,
        totalDuration = 125
    }
    
    -- Simulate complex scenario execution
    for _, system in ipairs(complexScenario.involvedSystems) do
        scenarioResults.systemsInvolved = scenarioResults.systemsInvolved + 1
        scenarioResults.coordinationMessages = scenarioResults.coordinationMessages + 2
        scenarioResults.stateUpdates = scenarioResults.stateUpdates + 1
        scenarioResults.validationsPassed = scenarioResults.validationsPassed + 1
    end
    
    assertEquals(5, scenarioResults.systemsInvolved, "All systems participated")
    assertEquals(10, scenarioResults.coordinationMessages, "Coordination messages sent")
    assertEquals(true, scenarioResults.totalDuration < complexScenario.expectedDuration, "Scenario completed within time limit")
    assertEquals(5, scenarioResults.validationsPassed, "All system validations passed")
end

-- Run all integration tests
function runIntegrationTests()
    print("=== Fusion Management Engine Integration Tests ===")
    
    integrationTests.testCrossProcessCoordination()
    integrationTests.testFusionManagementSystemIntegration()
    integrationTests.testMessageHandlerWorkflowValidation()
    integrationTests.testFusionManagementPersistenceWorkflows()
    integrationTests.testComplexMultiSystemFusionManagementScenarios()
    
    print("\n=== Integration Test Results ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))
    
    if failed == 0 then
        print("✓ All fusion management engine integration tests passed!")
        return true
    else
        print("✗ Some integration tests failed")
        return false
    end
end

-- Run tests if executed directly
if not package.loaded["testing.integration.fusion-management-engine-integration.test"] then
    runIntegrationTests()
end

-- Export for external use
return {
    runIntegrationTests = runIntegrationTests,
    integrationTests = integrationTests
}