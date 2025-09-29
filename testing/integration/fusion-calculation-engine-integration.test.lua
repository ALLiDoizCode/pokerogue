-- Integration Tests for Fusion Calculation Engine
-- Tests complete fusion calculation workflows with AO message patterns

local json = require("json")

-- Test framework setup
local TestFramework = {}
TestFramework.tests = {}
TestFramework.results = {passed = 0, failed = 0, total = 0}

function TestFramework.addTest(name, testFunction)
    table.insert(TestFramework.tests, {name = name, func = testFunction})
end

function TestFramework.runTests()
    print("=== Fusion Calculation Engine Integration Tests ===")
    
    for _, test in ipairs(TestFramework.tests) do
        TestFramework.results.total = TestFramework.results.total + 1
        local success, error = pcall(test.func)
        
        if success then
            TestFramework.results.passed = TestFramework.results.passed + 1
            print("✅ PASS: " .. test.name)
        else
            TestFramework.results.failed = TestFramework.results.failed + 1
            print("❌ FAIL: " .. test.name .. " - " .. tostring(error))
        end
    end
    
    print("\n=== Integration Test Results ===")
    print("Total: " .. TestFramework.results.total)
    print("Passed: " .. TestFramework.results.passed) 
    print("Failed: " .. TestFramework.results.failed)
    print("Success Rate: " .. math.floor((TestFramework.results.passed / TestFramework.results.total) * 100) .. "%")
    
    return TestFramework.results.failed == 0
end

function TestFramework.assertEqual(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. " - Expected: " .. tostring(expected) .. ", Actual: " .. tostring(actual))
    end
end

function TestFramework.assertTrue(condition, message)
    if not condition then
        error(message or "Expected true but got false")
    end
end

function TestFramework.assertNotNil(value, message)
    if value == nil then
        error(message or "Expected non-nil value but got nil")
    end
end

-- Mock AO environment with message capture
local sentMessages = {}
if not ao then
    ao = {
        send = function(msg) 
            table.insert(sentMessages, msg)
            print("AO Message Sent:", json.encode(msg))
        end,
        id = "test_fusion_process_id"
    }
end

-- Mock handlers for testing
local registeredHandlers = {}
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            registeredHandlers[name] = {matcher = matcher, handler = handler}
            print("Handler registered:", name)
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

-- Load the fusion calculation engine
dofile("/Users/jonathangreen/Documents/pokerogue/processes/fusion-calculation-engine.lua")

-- Helper function to simulate message handling
local function simulateMessage(action, data, tags)
    local msg = {
        From = "test_sender",
        Tags = tags or {},
        Data = data and json.encode(data) or nil,
        Timestamp = 1234567890
    }
    msg.Tags.Action = action
    
    sentMessages = {}  -- Clear previous messages
    
    local handler = registeredHandlers[action]
    if handler and handler.handler then
        handler.handler(msg)
        return sentMessages[1]  -- Return first sent message
    else
        error("Handler not found for action: " .. action)
    end
end

-- Integration Test: Complete Fusion Stat Calculation Workflow
TestFramework.addTest("Complete Fusion Stat Calculation Workflow", function()
    local gameData = {
        baseSpecies = {
            id = "PIKACHU",
            baseStats = {
                HP = 35, ATK = 55, DEF = 40, SPATK = 50, SPDEF = 50, SPD = 90
            }
        },
        fusionSpecies = {
            id = "RAICHU", 
            baseStats = {
                HP = 60, ATK = 90, DEF = 55, SPATK = 90, SPDEF = 80, SPD = 110
            }
        }
    }
    
    local response = simulateMessage("calculateFusionStats", gameData)
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("test_sender", response.Target, "Response should target original sender")
    TestFramework.assertEqual("SaveState", response.Action, "Should have SaveState action")
    TestFramework.assertEqual("true", response.Success, "Should indicate success")
    TestFramework.assertEqual("calculateFusionStats", response.Operation, "Should specify operation")
    
    local responseData = json.decode(response.Data)
    TestFramework.assertNotNil(responseData.fusionStats, "Should contain fusion stats")
    TestFramework.assertEqual(48, responseData.fusionStats.HP, "HP should be calculated correctly")
    TestFramework.assertEqual(73, responseData.fusionStats.ATK, "ATK should be calculated correctly")
    TestFramework.assertEqual("exact", responseData.mathematicalPrecision, "Should indicate exact precision")
end)

-- Integration Test: Complete Fusion Type Determination Workflow  
TestFramework.addTest("Complete Fusion Type Determination Workflow", function()
    local gameData = {
        baseTypes = {"FIRE", "FLYING"},
        fusionTypes = {"FIRE", "WATER"}
    }
    
    local response = simulateMessage("determineFusionType", gameData)
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("SaveState", response.Action, "Should have SaveState action")
    TestFramework.assertEqual("true", response.Success, "Should indicate success")
    
    local responseData = json.decode(response.Data)
    TestFramework.assertNotNil(responseData.fusionTypes, "Should contain fusion types")
    TestFramework.assertEqual(2, #responseData.fusionTypes, "Should have exactly 2 types")
    TestFramework.assertEqual("FIRE", responseData.fusionTypes[1], "Primary type should be FIRE")
    TestFramework.assertEqual("WATER", responseData.fusionTypes[2], "Secondary type should be WATER")
    TestFramework.assertEqual("priority", responseData.typeMethod, "Should indicate priority method")
end)

-- Integration Test: Complete Fusion Ability Selection Workflow
TestFramework.addTest("Complete Fusion Ability Selection Workflow", function()
    local gameData = {
        baseAbilities = {"STATIC", "LIGHTNING_ROD"},
        fusionAbilities = {"STATIC", "LIGHTNING_ROD", "LIGHTNING_ROD"},
        battleSeed = 12345,
        rngCounter = 0
    }
    
    local response = simulateMessage("selectFusionAbility", gameData)
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("SaveState", response.Action, "Should have SaveState action")
    TestFramework.assertEqual("true", response.Success, "Should indicate success")
    
    local responseData = json.decode(response.Data)
    TestFramework.assertNotNil(responseData.selectedAbility, "Should contain selected ability")
    TestFramework.assertNotNil(responseData.abilityIndex, "Should contain ability index")
    TestFramework.assertNotNil(responseData.selectionMethod, "Should contain selection method")
    TestFramework.assertTrue(type(responseData.probabilityUsed) == "boolean", "Should indicate probability usage")
end)

-- Integration Test: Fusion Creation Validation Workflow
TestFramework.addTest("Fusion Creation Validation Workflow", function()
    local gameData = {
        baseSpecies = {
            id = "CHARIZARD",
            baseStats = {HP = 78, ATK = 84, DEF = 78, SPATK = 109, SPDEF = 85, SPD = 100}
        },
        fusionSpecies = {
            id = "BLASTOISE",
            baseStats = {HP = 79, ATK = 83, DEF = 100, SPATK = 85, SPDEF = 105, SPD = 78}
        }
    }
    
    local response = simulateMessage("validateFusionCreation", gameData)
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("SaveState", response.Action, "Should have SaveState action")
    TestFramework.assertEqual("true", response.Success, "Should indicate success")
    
    local responseData = json.decode(response.Data)
    TestFramework.assertEqual(true, responseData.valid, "Should indicate validation passed")
    TestFramework.assertEqual(true, responseData.constraintsChecked, "Should indicate constraints were checked")
    TestFramework.assertEqual("strict", responseData.validationLevel, "Should indicate strict validation")
end)

-- Integration Test: Mathematical Precision Tracking Workflow
TestFramework.addTest("Mathematical Precision Tracking Workflow", function()
    local gameData = {
        baseSpecies = {
            baseStats = {HP = 35, ATK = 55, DEF = 41, SPATK = 51, SPDEF = 51, SPD = 91}
        },
        fusionSpecies = {
            baseStats = {HP = 60, ATK = 90, DEF = 54, SPATK = 89, SPDEF = 79, SPD = 109}
        }
    }
    
    local response = simulateMessage("calculateFusionPrecision", gameData)
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("SaveState", response.Action, "Should have SaveState action")
    TestFramework.assertEqual("true", response.Success, "Should indicate success")
    
    local responseData = json.decode(response.Data)
    TestFramework.assertNotNil(responseData.precisionResults, "Should contain precision results")
    TestFramework.assertEqual("exact", responseData.overallPrecision, "Should indicate exact precision")
    TestFramework.assertNotNil(responseData.formulaUsed, "Should specify formula used")
    
    -- Verify precision tracking for HP
    local hpPrecision = responseData.precisionResults.HP
    TestFramework.assertEqual(35, hpPrecision.baseValue, "Should track base HP value")
    TestFramework.assertEqual(60, hpPrecision.fusionValue, "Should track fusion HP value")
    TestFramework.assertEqual(47.5, hpPrecision.exactAverage, "Should track exact average")
    TestFramework.assertEqual(48, hpPrecision.ceiledResult, "Should track ceiled result")
end)

-- Integration Test: Error Handling in Message Workflow
TestFramework.addTest("Error Handling in Message Workflow", function()
    local invalidGameData = {
        baseSpecies = {
            id = "PIKACHU"
            -- Missing baseStats
        }
    }
    
    local response = simulateMessage("calculateFusionStats", invalidGameData)
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("Error", response.Action, "Should have Error action")
    TestFramework.assertNotNil(response.Error, "Should contain error message")
end)

-- Integration Test: ADP Info Handler Integration
TestFramework.addTest("ADP Info Handler Integration", function()
    local response = simulateMessage("Info")
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("SaveState", response.Action, "Should have SaveState action")
    
    local responseData = json.decode(response.Data)
    TestFramework.assertEqual("Pokemon Fusion Calculation Engine", responseData.Name, "Should have correct process name")
    TestFramework.assertEqual("1.0", responseData.protocolVersion, "Should indicate ADP v1.0 compliance")
    TestFramework.assertNotNil(responseData.handlers, "Should contain handler information")
    TestFramework.assertTrue(#responseData.handlers >= 5, "Should have at least 5 handlers registered")
    
    -- Verify fusion-specific capabilities
    TestFramework.assertEqual(true, responseData.capabilities.supportsFusionCalculations, "Should support fusion calculations")
    TestFramework.assertEqual(true, responseData.capabilities.adpCompliant, "Should be ADP compliant")
    TestFramework.assertEqual(true, responseData.capabilities.mathematicalParity, "Should have mathematical parity")
end)

-- Integration Test: Ping Handler Integration
TestFramework.addTest("Ping Handler Integration", function()
    local response = simulateMessage("Ping")
    
    TestFramework.assertNotNil(response, "Should receive response message")
    TestFramework.assertEqual("Pong", response.Action, "Should respond with Pong")
    TestFramework.assertEqual("pong", response.Data, "Should contain pong data")
    TestFramework.assertEqual("test_fusion_process_id", response.ProcessId, "Should include process ID")
end)

-- Integration Test: Cross-Handler Data Consistency
TestFramework.addTest("Cross-Handler Data Consistency", function()
    -- Test that state persists across handler calls
    local statsData = {
        baseSpecies = {baseStats = {HP = 50, ATK = 50, DEF = 50, SPATK = 50, SPDEF = 50, SPD = 50}},
        fusionSpecies = {baseStats = {HP = 60, ATK = 60, DEF = 60, SPATK = 60, SPDEF = 60, SPD = 60}}
    }
    
    local typesData = {
        baseTypes = {"NORMAL"},
        fusionTypes = {"NORMAL", "FLYING"}
    }
    
    -- Execute multiple operations
    local statsResponse = simulateMessage("calculateFusionStats", statsData)
    local typesResponse = simulateMessage("determineFusionType", typesData)
    local infoResponse = simulateMessage("Info")
    
    -- Verify all operations succeeded
    TestFramework.assertEqual("SaveState", statsResponse.Action, "Stats calculation should succeed")
    TestFramework.assertEqual("SaveState", typesResponse.Action, "Type determination should succeed")
    TestFramework.assertEqual("SaveState", infoResponse.Action, "Info should succeed")
    
    -- Verify state consistency (calculations performed counter should increment)
    local infoData = json.decode(infoResponse.Data)
    TestFramework.assertTrue(infoData.calculationsPerformed >= 1, "Should track calculations performed")
end)

-- Integration Test: Multi-Operation Fusion Workflow
TestFramework.addTest("Multi-Operation Fusion Workflow", function()
    local completeGameData = {
        baseSpecies = {
            id = "VENUSAUR",
            baseStats = {HP = 80, ATK = 82, DEF = 83, SPATK = 100, SPDEF = 100, SPD = 80},
            types = {"GRASS", "POISON"},
            abilities = {"OVERGROW", "CHLOROPHYLL"}
        },
        fusionSpecies = {
            id = "CHARIZARD",
            baseStats = {HP = 78, ATK = 84, DEF = 78, SPATK = 109, SPDEF = 85, SPD = 100},
            types = {"FIRE", "FLYING"},
            abilities = {"BLAZE", "SOLAR_POWER"}
        },
        battleSeed = 54321,
        rngCounter = 1
    }
    
    -- Step 1: Validate fusion creation
    local validationResponse = simulateMessage("validateFusionCreation", completeGameData)
    TestFramework.assertEqual("SaveState", validationResponse.Action, "Validation should succeed")
    
    -- Step 2: Calculate fusion stats
    local statsResponse = simulateMessage("calculateFusionStats", completeGameData)
    TestFramework.assertEqual("SaveState", statsResponse.Action, "Stats calculation should succeed")
    
    -- Step 3: Determine fusion types
    local typeData = {baseTypes = completeGameData.baseSpecies.types, fusionTypes = completeGameData.fusionSpecies.types}
    local typesResponse = simulateMessage("determineFusionType", typeData)
    TestFramework.assertEqual("SaveState", typesResponse.Action, "Type determination should succeed")
    
    -- Step 4: Select fusion ability
    local abilityData = {
        baseAbilities = completeGameData.baseSpecies.abilities,
        fusionAbilities = completeGameData.fusionSpecies.abilities,
        battleSeed = completeGameData.battleSeed,
        rngCounter = completeGameData.rngCounter
    }
    local abilityResponse = simulateMessage("selectFusionAbility", abilityData)
    TestFramework.assertEqual("SaveState", abilityResponse.Action, "Ability selection should succeed")
    
    -- Verify complete workflow results
    local statsData = json.decode(statsResponse.Data)
    local typesData = json.decode(typesResponse.Data)
    local abilityData = json.decode(abilityResponse.Data)
    
    -- Expected fusion stats: ceil((base + fusion) / 2)
    TestFramework.assertEqual(79, statsData.fusionStats.HP, "HP: ceil((80 + 78) / 2) = 79")
    TestFramework.assertEqual(83, statsData.fusionStats.ATK, "ATK: ceil((82 + 84) / 2) = 83")
    TestFramework.assertEqual(81, statsData.fusionStats.DEF, "DEF: ceil((83 + 78) / 2) = 81")
    TestFramework.assertEqual(105, statsData.fusionStats.SPATK, "SPATK: ceil((100 + 109) / 2) = 105")
    TestFramework.assertEqual(93, statsData.fusionStats.SPDEF, "SPDEF: ceil((100 + 85) / 2) = 93")
    TestFramework.assertEqual(90, statsData.fusionStats.SPD, "SPD: ceil((80 + 100) / 2) = 90")
    
    -- Expected fusion types: GRASS primary, FLYING secondary (priority rules)
    TestFramework.assertEqual("GRASS", typesData.fusionTypes[1], "Primary type should be GRASS from base")
    TestFramework.assertEqual("FLYING", typesData.fusionTypes[2], "Secondary type should be FLYING from fusion")
    
    -- Verify ability selection contains required fields
    TestFramework.assertNotNil(abilityData.selectedAbility, "Should have selected ability")
    TestFramework.assertNotNil(abilityData.selectionMethod, "Should have selection method")
end)

-- Run all integration tests
if TestFramework.runTests() then
    print("\n🎉 All fusion calculation engine integration tests passed!")
    return true
else
    print("\n💥 Some fusion calculation engine integration tests failed!")
    return false
end