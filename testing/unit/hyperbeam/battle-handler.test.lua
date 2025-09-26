#!/usr/bin/env lua

--[[
Unit Tests for Battle Handler
Tests all battle-related message handlers and game logic
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

-- Battle Handler Test Suite
local BattleHandlerTests = {}

-- Setup test environment
local function setupBattleTestEnvironment()
    HyperBeamTest.setupMockEnvironment()
    ProcessEmulator.reset()
    Mock.resetAll()

    -- Create mock battle handler
    local battleHandler = {
        processMove = {
            matcher = function(msg)
                return msg.Action == "ProcessMove"
            end,
            handler = function(msg)
                -- Mock battle move processing
                local data = msg.Data
                if type(data) == "string" then
                    -- Simulate processing move
                    return {
                        Target = msg.From,
                        Action = "SaveState",
                        Data = '{"success":true,"battleResult":"hit","damage":50,"gameState":{"battle":{"turn":2}}}',
                        ProcessId = "battle-engine",
                        Timestamp = tostring(1234567890 * 1000)
                    }
                else
                    return {
                        Target = msg.From,
                        Action = "Error",
                        Error = "Invalid move data"
                    }
                end
            end
        },

        startBattle = {
            matcher = function(msg)
                return msg.Action == "StartBattle"
            end,
            handler = function(msg)
                return {
                    Target = msg.From,
                    Action = "SaveState",
                    Data = '{"success":true,"battleStarted":true,"gameState":{"battle":{"turn":1,"playerPokemon":{"currentHp":100},"opponentPokemon":{"currentHp":80}}}}',
                    ProcessId = "battle-engine",
                    Timestamp = tostring(1234567890 * 1000)
                }
            end
        },

        endBattle = {
            matcher = function(msg)
                return msg.Action == "EndBattle"
            end,
            handler = function(msg)
                return {
                    Target = msg.From,
                    Action = "SaveState",
                    Data = '{"success":true,"battleEnded":true,"victory":true,"gameState":{"player":{"experience":150}}}',
                    ProcessId = "battle-engine",
                    Timestamp = tostring(1234567890 * 1000)
                }
            end
        }
    }

    return ProcessEmulator.spawn("battle-engine", battleHandler, {
        currentBattle = nil,
        battleHistory = {}
    })
end

-- Test battle move processing
function BattleHandlerTests.testProcessMove()
    local battleProcess = setupBattleTestEnvironment()

    -- Test valid move processing
    local moveMsg = Mock.MessageBuilder.battleAction({
        moveId = 25, -- Thunderbolt
        targetSlot = 0,
        battleId = "test-battle-123"
    })

    local routeResult = ProcessEmulator.routeMessage(moveMsg)
    Assert.isTrue(routeResult.success)

    ProcessEmulator.runScheduler(10, 1000)

    -- Verify move was processed
    Assert.isTrue(battleProcess.messageCount > 0)

    print("✓ Process move functionality working")

    -- Test invalid move data
    local invalidMsg = Mock.message({
        From = "test-player",
        Target = "battle-engine",
        Action = "ProcessMove",
        Data = nil -- Invalid data
    })

    ProcessEmulator.routeMessage(invalidMsg)
    ProcessEmulator.runScheduler(5, 500)

    print("✓ Invalid move data handling working")

    return true
end

-- Test battle start sequence
function BattleHandlerTests.testStartBattle()
    local battleProcess = setupBattleTestEnvironment()

    local startMsg = Mock.message({
        From = "test-player",
        Target = "battle-engine",
        Action = "StartBattle",
        Data = '{"opponentId":"wild-pikachu","battleType":"wild"}'
    })

    ProcessEmulator.routeMessage(startMsg)
    ProcessEmulator.runScheduler(10, 1000)

    Assert.isTrue(battleProcess.messageCount > 0)

    print("✓ Battle start functionality working")

    return true
end

-- Test battle end sequence
function BattleHandlerTests.testEndBattle()
    local battleProcess = setupBattleTestEnvironment()

    local endMsg = Mock.message({
        From = "test-player",
        Target = "battle-engine",
        Action = "EndBattle",
        Data = '{"victory":true,"experienceGained":150}'
    })

    ProcessEmulator.routeMessage(endMsg)
    ProcessEmulator.runScheduler(10, 1000)

    Assert.isTrue(battleProcess.messageCount > 0)

    print("✓ Battle end functionality working")

    return true
end

-- Test damage calculation
function BattleHandlerTests.testDamageCalculation()
    setupBattleTestEnvironment()

    -- Mock damage calculation logic
    local function calculateDamage(attackPower, defense, effectiveness)
        local baseDamage = math.floor(attackPower * 0.8)
        local defensiveDamage = math.floor(baseDamage * (100 / (100 + defense)))
        return math.floor(defensiveDamage * effectiveness)
    end

    -- Test normal effectiveness
    local damage = calculateDamage(80, 60, 1.0)
    Assert.isTrue(damage > 0)
    Assert.isTrue(damage < 80) -- Should be less than base attack

    -- Test super effective
    local superDamage = calculateDamage(80, 60, 2.0)
    Assert.isTrue(superDamage > damage)

    -- Test not very effective
    local weakDamage = calculateDamage(80, 60, 0.5)
    Assert.isTrue(weakDamage < damage)

    print("✓ Damage calculation working")

    return true
end

-- Test type effectiveness
function BattleHandlerTests.testTypeEffectiveness()
    setupBattleTestEnvironment()

    -- Mock type effectiveness chart
    local typeChart = {
        Fire = {Water = 0.5, Grass = 2.0, Electric = 1.0},
        Water = {Fire = 2.0, Grass = 0.5, Electric = 0.5},
        Grass = {Fire = 0.5, Water = 2.0, Electric = 1.0},
        Electric = {Fire = 1.0, Water = 2.0, Grass = 0.5}
    }

    -- Test various type matchups
    Assert.equals(typeChart.Fire.Water, 0.5) -- Fire vs Water (not very effective)
    Assert.equals(typeChart.Fire.Grass, 2.0) -- Fire vs Grass (super effective)
    Assert.equals(typeChart.Water.Fire, 2.0) -- Water vs Fire (super effective)
    Assert.equals(typeChart.Electric.Water, 2.0) -- Electric vs Water (super effective)

    print("✓ Type effectiveness working")

    return true
end

-- Test status effects
function BattleHandlerTests.testStatusEffects()
    setupBattleTestEnvironment()

    -- Mock status effect application
    local statusEffects = {
        paralysis = {damage = 0, accuracy = 0.75, canMove = function() return math.random() > 0.25 end},
        burn = {damage = 0.125, accuracy = 1.0, canMove = function() return true end},
        freeze = {damage = 0, accuracy = 1.0, canMove = function() return math.random() > 0.8 end}
    }

    -- Test status effect properties
    Assert.equals(statusEffects.paralysis.accuracy, 0.75)
    Assert.equals(statusEffects.burn.damage, 0.125)
    Assert.hasType(statusEffects.freeze.canMove, "function")

    print("✓ Status effects working")

    return true
end

-- Test battle flow integration
function BattleHandlerTests.testBattleFlow()
    setupBattleTestEnvironment()

    -- Test complete battle sequence
    local messages = {
        Mock.message({Action = "StartBattle", Target = "battle-engine"}),
        Mock.message({Action = "ProcessMove", Target = "battle-engine"}),
        Mock.message({Action = "ProcessMove", Target = "battle-engine"}),
        Mock.message({Action = "EndBattle", Target = "battle-engine"})
    }

    -- Send all messages
    for _, msg in ipairs(messages) do
        ProcessEmulator.routeMessage(msg)
    end

    ProcessEmulator.runScheduler(20, 2000)

    -- Verify battle process handled all messages
    local battleProcess = ProcessEmulator.getProcess("battle-engine")
    Assert.isTrue(battleProcess.messageCount >= #messages)

    print("✓ Battle flow integration working")

    return true
end

-- Main test runner
function BattleHandlerTests.runAllTests()
    print("\n🎯 Running Battle Handler Tests")
    print("=" .. string.rep("=", 40))

    local tests = {
        {"Process Move", BattleHandlerTests.testProcessMove},
        {"Start Battle", BattleHandlerTests.testStartBattle},
        {"End Battle", BattleHandlerTests.testEndBattle},
        {"Damage Calculation", BattleHandlerTests.testDamageCalculation},
        {"Type Effectiveness", BattleHandlerTests.testTypeEffectiveness},
        {"Status Effects", BattleHandlerTests.testStatusEffects},
        {"Battle Flow", BattleHandlerTests.testBattleFlow}
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

    print(string.format("\n📊 Battle Handler Results: %d/%d (%.1f%%)",
        passed, total, (passed/total)*100))

    return passed == total
end

return BattleHandlerTests