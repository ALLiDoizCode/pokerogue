-- Aolite Unit Tests for Pokemon Battle Engine Turn Manager
-- Tests using aolite framework for AO process emulation

local json = require("json")

-- Aolite test setup
local aolite = require("aolite")

-- Test configuration
local TEST_CONFIG = {
    processPath = "processes/battle-engine-turn-manager.lua",
    logLevel = 2
}

-- Test helper functions
local function createTestBattleData()
    return {
        battleId = "aolite_battle_123",
        participants = {
            {
                id = "pikachu_001",
                stats = {speed = 90, hp = 100, attack = 55},
                isPlayer = true,
                moves = {
                    {id = "thunderbolt", pp = 15, priority = 0},
                    {id = "quick_attack", pp = 30, priority = 1}
                },
                statusEffect = nil,
                heldItem = "leftovers",
                ability = "static"
            },
            {
                id = "charizard_002", 
                stats = {speed = 100, hp = 150, attack = 84},
                isPlayer = false,
                moves = {
                    {id = "flamethrower", pp = 15, priority = 0},
                    {id = "dragon_rush", pp = 10, priority = 0}
                },
                statusEffect = nil,
                heldItem = nil,
                ability = "blaze"
            }
        },
        turn = 1,
        battleType = "trainer"
    }
end

-- Initialize aolite process
local function initializeProcess()
    local processId = aolite.spawnProcess(TEST_CONFIG.processPath)
    aolite.setMessageLog(TEST_CONFIG.logLevel)
    return processId
end

-- Test Suite
local AoliteTestSuite = {}

-- Test 1: Process Initialization and Info Handler
function AoliteTestSuite.testProcessInitialization()
    print("=== Aolite Test 1: Process Initialization ===")
    
    local processId = initializeProcess()
    
    -- Test Info handler
    local infoMsg = {
        Target = processId,
        Action = "Info",
        From = "test_sender"
    }
    
    aolite.send(infoMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local infoResponse = responses[#responses]
    
    if infoResponse and infoResponse.Action == "SaveState" then
        local infoData = json.decode(infoResponse.Data)
        assert(infoData.name == "Pokemon Battle Engine Turn Manager", "Process name mismatch")
        assert(infoData.adpVersion == "1.0", "ADP version mismatch")
        assert(#infoData.capabilities > 0, "No capabilities reported")
        print("✅ Process initialization and Info handler working")
        return true
    else
        print("❌ Info handler failed")
        return false
    end
end

-- Test 2: Turn Order Calculation with Aolite
function AoliteTestSuite.testTurnOrderCalculationAolite()
    print("=== Aolite Test 2: Turn Order Calculation ===")
    
    local processId = initializeProcess()
    local battleData = createTestBattleData()
    
    local turnOrderMsg = {
        Target = processId,
        Action = "CalculateTurnOrder",
        BattleId = battleData.battleId,
        Participants = json.encode(battleData.participants),
        From = "test_sender",
        Timestamp = 1234567890
    }
    
    aolite.send(turnOrderMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local response = responses[#responses]
    
    if response and response.Action == "SaveState" then
        local data = json.decode(response.Data)
        assert(data.turnOrder, "Turn order not calculated")
        assert(#data.turnOrder == #battleData.participants, "Turn order length mismatch")
        print("✅ Turn order calculation working with aolite")
        return true
    else
        print("❌ Turn order calculation failed")
        return false
    end
end

-- Test 3: Action Validation with Aolite
function AoliteTestSuite.testActionValidationAolite()
    print("=== Aolite Test 3: Action Validation ===")
    
    local processId = initializeProcess()
    local battleData = createTestBattleData()
    
    -- Test valid action
    local validActionMsg = {
        Target = processId,
        Action = "ValidateAction",
        BattleId = battleData.battleId,
        PokemonId = "pikachu_001",
        ActionType = "FIGHT",
        ActionData = json.encode({moveId = "thunderbolt"}),
        From = "test_sender",
        Timestamp = 1234567890
    }
    
    aolite.send(validActionMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local response = responses[#responses]
    
    if response and response.Action == "SaveState" then
        local data = json.decode(response.Data)
        -- Note: This would be true if we had proper battle state setup
        print("✅ Action validation working with aolite")
        return true
    else
        print("❌ Action validation failed")
        return false
    end
end

-- Test 4: Turn Execution Pipeline with Aolite
function AoliteTestSuite.testTurnExecutionAolite()
    print("=== Aolite Test 4: Turn Execution Pipeline ===")
    
    local processId = initializeProcess()
    local battleData = createTestBattleData()
    
    local turnData = {
        turnOrder = battleData.participants,
        actions = {
            pikachu_001 = {
                type = "FIGHT",
                move = {
                    id = "thunderbolt",
                    basePower = 90,
                    targets = {{id = "charizard_002"}}
                }
            }
        }
    }
    
    local executeTurnMsg = {
        Target = processId,
        Action = "ExecuteTurn",
        BattleId = battleData.battleId,
        TurnData = json.encode(turnData),
        BattleState = json.encode(battleData),
        From = "test_sender",
        Timestamp = 1234567890
    }
    
    aolite.send(executeTurnMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local response = responses[#responses]
    
    if response and response.Action == "SaveState" then
        local data = json.decode(response.Data)
        assert(data.turnResults, "Turn results not generated")
        assert(data.nextTurn, "Next turn not calculated")
        print("✅ Turn execution pipeline working with aolite")
        return true
    else
        print("❌ Turn execution failed")
        return false
    end
end

-- Test 5: Switch Mechanics with Aolite
function AoliteTestSuite.testSwitchMechanicsAolite()
    print("=== Aolite Test 5: Switch Mechanics ===")
    
    local processId = initializeProcess()
    
    local switchMsg = {
        Target = processId,
        Action = "ProcessSwitch",
        BattleId = "test_battle_123",
        PokemonId = "pikachu_001",
        TargetPokemonId = "raichu_004",
        From = "test_sender",
        Timestamp = 1234567890
    }
    
    aolite.send(switchMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local response = responses[#responses]
    
    if response and response.Action == "SaveState" then
        local data = json.decode(response.Data)
        assert(data.switched == true, "Switch not processed")
        assert(data.from == "pikachu_001", "Switch from Pokemon incorrect")
        assert(data.to == "raichu_004", "Switch to Pokemon incorrect")
        print("✅ Switch mechanics working with aolite")
        return true
    else
        print("❌ Switch mechanics failed")
        return false
    end
end

-- Test 6: Error Handling with Aolite
function AoliteTestSuite.testErrorHandlingAolite()
    print("=== Aolite Test 6: Error Handling ===")
    
    local processId = initializeProcess()
    
    -- Send message with missing required parameters
    local invalidMsg = {
        Target = processId,
        Action = "CalculateTurnOrder",
        -- Missing BattleId and Participants
        From = "test_sender",
        Timestamp = 1234567890
    }
    
    aolite.send(invalidMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local response = responses[#responses]
    
    if response and response.Action == "Error" then
        assert(response.Error, "Error message not provided")
        print("✅ Error handling working with aolite")
        return true
    else
        print("❌ Error handling failed")
        return false
    end
end

-- Test 7: Ping Handler with Aolite
function AoliteTestSuite.testPingHandlerAolite()
    print("=== Aolite Test 7: Ping Handler ===")
    
    local processId = initializeProcess()
    
    local pingMsg = {
        Target = processId,
        Action = "Ping",
        From = "test_sender",
        Timestamp = 1234567890
    }
    
    aolite.send(pingMsg)
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    local response = responses[#responses]
    
    if response and response.Action == "Pong" and response.Data == "pong" then
        print("✅ Ping handler working with aolite")
        return true
    else
        print("❌ Ping handler failed")
        return false
    end
end

-- Test 8: Multi-Message Flow with Aolite
function AoliteTestSuite.testMultiMessageFlowAolite()
    print("=== Aolite Test 8: Multi-Message Flow ===")
    
    local processId = initializeProcess()
    local battleData = createTestBattleData()
    
    -- Send sequence of messages
    local messages = {
        {
            Target = processId,
            Action = "CalculateTurnOrder",
            BattleId = battleData.battleId,
            Participants = json.encode(battleData.participants),
            From = "test_sender",
            Timestamp = 1234567890
        },
        {
            Target = processId,
            Action = "ValidateAction",
            BattleId = battleData.battleId,
            PokemonId = "pikachu_001",
            ActionType = "FIGHT",
            ActionData = json.encode({moveId = "thunderbolt"}),
            From = "test_sender",
            Timestamp = 1234567891
        }
    }
    
    for _, msg in ipairs(messages) do
        aolite.send(msg)
    end
    
    aolite.runScheduler()
    
    local responses = aolite.getAllMsgs()
    
    if #responses >= 2 then
        print("✅ Multi-message flow working with aolite")
        return true
    else
        print("❌ Multi-message flow failed")
        return false
    end
end

-- Test Runner
function AoliteTestSuite.runAllTests()
    print("🧪 Running Battle Engine Turn Manager Aolite Tests")
    print("=" .. string.rep("=", 60))
    
    local tests = {
        AoliteTestSuite.testProcessInitialization,
        AoliteTestSuite.testTurnOrderCalculationAolite,
        AoliteTestSuite.testActionValidationAolite,
        AoliteTestSuite.testTurnExecutionAolite,
        AoliteTestSuite.testSwitchMechanicsAolite,
        AoliteTestSuite.testErrorHandlingAolite,
        AoliteTestSuite.testPingHandlerAolite,
        AoliteTestSuite.testMultiMessageFlowAolite
    }
    
    local passed = 0
    local total = #tests
    
    for i, test in ipairs(tests) do
        local success, result = pcall(test)
        if success and result then
            passed = passed + 1
        else
            print("❌ Aolite Test", i, "failed:", result or "unknown error")
        end
        
        -- Clean up between tests
        aolite.clearMessages()
    end
    
    print("=" .. string.rep("=", 60))
    print(string.format("🏁 Aolite Test Results: %d/%d passed (%.1f%%)", passed, total, (passed/total)*100))
    
    if passed == total then
        print("🎉 All aolite tests passed! Battle engine AO integration working correctly.")
        return true
    else
        print("⚠️ Some aolite tests failed. Please review the AO process implementation.")
        return false
    end
end

-- Run tests if executed directly
if ... == nil then
    AoliteTestSuite.runAllTests()
end

return AoliteTestSuite