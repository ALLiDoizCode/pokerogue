#!/usr/bin/env lua

--[[
Unit Tests for State Handler
Tests Pokemon state management operations and data persistence
Version: 1.0.0
]]

-- Load testing framework
local function loadModule(path)
    local f = assert(loadfile(path))
    return f()
end

local HyperBeamTest = loadModule("testing/aolite/hyperbeam-test-framework.lua")
local Assert = loadModule("testing/aolite/assertion-library.lua")
local Mock = loadModule("testing/aolite/mock-system.lua")
local ProcessEmulator = loadModule("testing/aolite/process-emulator.lua")
local StateInspector = loadModule("testing/aolite/state-inspector.lua")

-- State Handler Test Suite
local StateHandlerTests = {}

-- Setup test environment
local function setupStateTestEnvironment()
    HyperBeamTest.setupMockEnvironment()
    ProcessEmulator.reset()
    StateInspector.reset()
    Mock.resetAll()
    
    -- Create mock state handler
    local stateHandler = {
        updatePokemonStats = {
            matcher = function(msg)
                return msg.Action == "UpdatePokemonStats"
            end,
            handler = function(msg)
                return {
                    Target = msg.From,
                    Action = "SaveState",
                    Data = '{"success":true,"pokemonUpdated":true,"gameState":{"party":[{"speciesId":25,"level":26,"stats":{"hp":95}}]}}',
                    ProcessId = "state-handler",
                    Timestamp = tostring(1234567890 * 1000)
                }
            end
        },
        
        evolvePokemon = {
            matcher = function(msg)
                return msg.Action == "EvolvePokemon"
            end,
            handler = function(msg)
                return {
                    Target = msg.From,
                    Action = "SaveState",
                    Data = '{"success":true,"evolved":true,"gameState":{"party":[{"speciesId":26,"level":25}]}}',
                    ProcessId = "state-handler",
                    Timestamp = tostring(1234567890 * 1000)
                }
            end
        },
        
        healPokemon = {
            matcher = function(msg)
                return msg.Action == "HealPokemon"
            end,
            handler = function(msg)
                return {
                    Target = msg.From,
                    Action = "SaveState",
                    Data = '{"success":true,"healed":true,"gameState":{"party":[{"currentHp":100,"stats":{"hp":100}}]}}',
                    ProcessId = "state-handler",
                    Timestamp = tostring(1234567890 * 1000)
                }
            end
        }
    }
    
    return ProcessEmulator.spawn("state-handler", stateHandler, {
        pokemonParty = {},
        playerData = {},
        gameProgress = {}
    })
end

-- Test Pokemon stat updates
function StateHandlerTests.testUpdatePokemonStats()
    local stateProcess = setupStateTestEnvironment()
    
    -- Take initial state snapshot
    StateInspector.takeSnapshot("state-handler", "initial")
    
    local updateMsg = Mock.message({
        From = "test-player",
        Target = "state-handler",
        Action = "UpdatePokemonStats",
        Data = '{"pokemonId":"pokemon-123","newStats":{"level":26,"hp":95}}'
    })
    
    ProcessEmulator.routeMessage(updateMsg)
    ProcessEmulator.runScheduler(10, 1000)
    
    Assert.isTrue(stateProcess.messageCount > 0)
    
    -- Take state snapshot after update
    StateInspector.takeSnapshot("state-handler", "after-update")
    
    print("✓ Pokemon stats update working")
    
    return true
end

-- Test Pokemon evolution
function StateHandlerTests.testEvolvePokemon()
    local stateProcess = setupStateTestEnvironment()
    
    local evolveMsg = Mock.MessageBuilder.pokemonOperation({
        action = "EvolvePokemon",
        pokemonId = "pokemon-123",
        evolutionData = {newSpeciesId = 26, trigger = "level"}
    })
    
    ProcessEmulator.routeMessage(evolveMsg)
    ProcessEmulator.runScheduler(10, 1000)
    
    Assert.isTrue(stateProcess.messageCount > 0)
    
    print("✓ Pokemon evolution working")
    
    return true
end

-- Test Pokemon healing
function StateHandlerTests.testHealPokemon()
    local stateProcess = setupStateTestEnvironment()
    
    local healMsg = Mock.message({
        From = "test-player",
        Target = "state-handler",
        Action = "HealPokemon",
        Data = '{"pokemonId":"pokemon-123","healAmount":50}'
    })
    
    ProcessEmulator.routeMessage(healMsg)
    ProcessEmulator.runScheduler(10, 1000)
    
    Assert.isTrue(stateProcess.messageCount > 0)
    
    print("✓ Pokemon healing working")
    
    return true
end

-- Test state validation
function StateHandlerTests.testStateValidation()
    setupStateTestEnvironment()
    
    -- Test valid Pokemon structure
    local validPokemon = {
        id = "pokemon-123",
        speciesId = 25,
        level = 50,
        currentHp = 95,
        stats = {
            hp = 100,
            attack = 85,
            defense = 70,
            spAttack = 90,
            spDefense = 75,
            speed = 105
        }
    }
    
    Assert.validPokemon(validPokemon)
    
    print("✓ Valid Pokemon structure validation working")
    
    -- Test invalid Pokemon structure
    local invalidPokemon = {
        id = "pokemon-456",
        level = 50
        -- Missing required fields
    }
    
    Assert.throws(function()
        Assert.validPokemon(invalidPokemon)
    end, "missing")
    
    print("✓ Invalid Pokemon structure validation working")
    
    return true
end

-- Test state persistence
function StateHandlerTests.testStatePersistence()
    setupStateTestEnvironment()
    
    -- Create test state
    local testState = {
        player = {
            id = "player-123",
            name = "Ash",
            money = 1500
        },
        party = {
            {
                id = "pokemon-1",
                speciesId = 25,
                level = 25,
                currentHp = 85,
                stats = {hp = 90, attack = 60, defense = 50, spAttack = 70, spDefense = 60, speed = 95}
            }
        },
        scene = "pokecenter"
    }
    
    -- Validate the state structure
    local validationResults = StateInspector.validateState(testState)
    
    -- Check that validation passed
    local allPassed = true
    for _, result in ipairs(validationResults) do
        if not result.success then
            allPassed = false
            break
        end
    end
    
    Assert.isTrue(allPassed, "State validation should pass")
    
    print("✓ State persistence validation working")
    
    return true
end

-- Test state comparison
function StateHandlerTests.testStateComparison()
    setupStateTestEnvironment()
    
    local state1 = {
        player = {money = 1000},
        party = {{level = 25}}
    }
    
    local state2 = {
        player = {money = 1500}, -- Changed
        party = {{level = 25}}
    }
    
    local equal, differences = StateInspector.statesEqual(state1, state2)
    Assert.isFalse(equal, "States should not be equal")
    Assert.isTrue(#differences > 0, "Should have differences")
    
    print("✓ State comparison working")
    
    -- Test equal states
    local state3 = {
        player = {money = 1000},
        party = {{level = 25}}
    }
    
    local equal2, differences2 = StateInspector.statesEqual(state1, state3)
    Assert.isTrue(equal2, "Identical states should be equal")
    Assert.equals(#differences2, 0, "Should have no differences")
    
    print("✓ Equal state comparison working")
    
    return true
end

-- Test state snapshots
function StateHandlerTests.testStateSnapshots()
    local stateProcess = setupStateTestEnvironment()
    
    -- Take initial snapshot
    local snapshot1 = StateInspector.takeSnapshot("state-handler", "test-snapshot-1")
    Assert.notNil(snapshot1)
    Assert.equals(snapshot1.label, "test-snapshot-1")
    
    -- Modify state (simulate processing a message)
    stateProcess.state.testValue = "modified"
    
    -- Take another snapshot
    local snapshot2 = StateInspector.takeSnapshot("state-handler", "test-snapshot-2")
    Assert.notNil(snapshot2)
    
    -- Compare snapshots
    local differences = StateInspector.compareSnapshots("state-handler", "test-snapshot-1", "test-snapshot-2")
    Assert.notNil(differences)
    
    print("✓ State snapshots working")
    
    return true
end

-- Test state watching
function StateHandlerTests.testStateWatching()
    setupStateTestEnvironment()
    
    local changeDetected = false
    
    -- Setup state watcher
    StateInspector.watchState("state-handler", function(processId, oldState, newState)
        changeDetected = true
    end)
    
    -- Simulate state change
    local oldState = {value = 1}
    local newState = {value = 2}
    StateInspector.notifyStateChange("state-handler", oldState, newState)
    
    Assert.isTrue(changeDetected, "State change should be detected")
    
    print("✓ State watching working")
    
    return true
end

-- Main test runner
function StateHandlerTests.runAllTests()
    print("\n🏗️ Running State Handler Tests")
    print("=" .. string.rep("=", 40))
    
    local tests = {
        {"Update Pokemon Stats", StateHandlerTests.testUpdatePokemonStats},
        {"Evolve Pokemon", StateHandlerTests.testEvolvePokemon},
        {"Heal Pokemon", StateHandlerTests.testHealPokemon},
        {"State Validation", StateHandlerTests.testStateValidation},
        {"State Persistence", StateHandlerTests.testStatePersistence},
        {"State Comparison", StateHandlerTests.testStateComparison},
        {"State Snapshots", StateHandlerTests.testStateSnapshots},
        {"State Watching", StateHandlerTests.testStateWatching}
    }
    
    local passed = 0
    local total = #tests
    
    for _, test in ipairs(tests) do
        local testName, testFunc = test[1], test[2]
        local success, err = pcall(testFunc)
        
        if success then
            passed = passed + 1
            print("✅ " .. testName .. " - PASSED")
        else
            print("❌ " .. testName .. " - FAILED: " .. tostring(err))
        end
    end
    
    print(string.format("\n📊 State Handler Results: %d/%d (%.1f%%)", 
        passed, total, (passed/total)*100))
    
    return passed == total
end

return StateHandlerTests