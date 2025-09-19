-- Unit tests for Battle Engine Process
-- Tests damage calculation, turn resolution, and battle state transitions

-- Add processes directory to package path for module loading
package.path = './?.lua;' .. package.path

local BattleEngineModule = require("processes.battle-engine")
local BattleEngine = BattleEngineModule.BattleEngine
local LogicProcessTemplate = require("processes.templates.logic-process-template")

-- Test data fixtures
local mockPlayerPokemon = {
    speciesId = 1,
    level = 50,
    hp = 150,
    maxHp = 150,
    stats = {
        hp = 150,
        attack = 100,
        defense = 90,
        spAttack = 85,
        spDefense = 85,
        speed = 95
    },
    type1 = "normal",
    type2 = nil
}

local mockEnemyPokemon = {
    speciesId = 7,
    level = 50,
    hp = 140,
    maxHp = 140,
    stats = {
        hp = 140,
        attack = 85,
        defense = 100,
        spAttack = 90,
        spDefense = 95,
        speed = 80
    },
    type1 = "water",
    type2 = nil
}

local mockGameState = {
    playerId = "test-player-123",
    timestamp = 1695123456,
    version = 1,
    player = {
        party = {mockPlayerPokemon}
    },
    battle = {
        battleId = "battle-test-123",
        battleSeed = "test-battle-seed-456",
        turn = 1,
        status = "active",
        enemyParty = {mockEnemyPokemon},
        conditions = {}
    }
}

local mockMove = {
    id = 1,
    name = "Tackle",
    type = "normal",
    category = "physical",
    power = 40,
    accuracy = 100
}

local mockSpecialMove = {
    id = 2,
    name = "Water Gun",
    type = "water",
    category = "special",
    power = 40,
    accuracy = 100
}

-- Test suite
local tests = {}

-- Test 1: Type effectiveness calculation
function tests.testTypeEffectiveness()
    print("Testing type effectiveness calculation...")
    
    -- Test super effective
    local effectiveness1 = BattleEngine.getTypeEffectiveness("water", "fire", nil)
    assert(effectiveness1 == 2.0, "Water vs Fire should be super effective (2.0)")
    
    -- Test not very effective
    local effectiveness2 = BattleEngine.getTypeEffectiveness("water", "grass", nil)
    assert(effectiveness2 == 0.5, "Water vs Grass should be not very effective (0.5)")
    
    -- Test normal effectiveness
    local effectiveness3 = BattleEngine.getTypeEffectiveness("normal", "water", nil)
    assert(effectiveness3 == 1.0, "Normal vs Water should be normal effectiveness (1.0)")
    
    -- Test dual type effectiveness
    local effectiveness4 = BattleEngine.getTypeEffectiveness("electric", "water", "flying")
    assert(effectiveness4 == 4.0, "Electric vs Water/Flying should be 4x effective (2.0 * 2.0)")
    
    -- Test immunity
    local effectiveness5 = BattleEngine.getTypeEffectiveness("ground", "flying", nil)
    assert(effectiveness5 == 0, "Ground vs Flying should be immune (0)")
    
    print("✓ Type effectiveness tests passed")
end

-- Test 2: Critical hit calculation
function tests.testCriticalHit()
    print("Testing critical hit calculation...")
    
    local rngState, _ = LogicProcessTemplate.initializeRNG("crit-test-seed")
    
    -- Test multiple critical hit calculations for consistency
    local critCount = 0
    local totalTests = 100
    
    for i = 1, totalTests do
        local critMultiplier = BattleEngine.calculateCriticalHit(mockPlayerPokemon, rngState)
        if critMultiplier > 1.0 then
            critCount = critCount + 1
            assert(critMultiplier == 2.0, "Critical hit multiplier should be 2.0")
        else
            assert(critMultiplier == 1.0, "Non-critical multiplier should be 1.0")
        end
    end
    
    -- Critical hits should be deterministic with same seed
    local rngState2, _ = LogicProcessTemplate.initializeRNG("crit-test-seed")
    local firstCrit = BattleEngine.calculateCriticalHit(mockPlayerPokemon, rngState2)
    
    local rngState3, _ = LogicProcessTemplate.initializeRNG("crit-test-seed")
    local secondCrit = BattleEngine.calculateCriticalHit(mockPlayerPokemon, rngState3)
    
    assert(firstCrit == secondCrit, "Same seed should produce same critical hit result")
    
    print("✓ Critical hit tests passed")
end

-- Test 3: Accuracy check
function tests.testAccuracyCheck()
    print("Testing accuracy check...")
    
    local rngState, _ = LogicProcessTemplate.initializeRNG("accuracy-test-seed")
    
    -- Test 100% accuracy move
    local accurate = BattleEngine.checkAccuracy(mockMove, mockPlayerPokemon, mockEnemyPokemon, rngState)
    assert(type(accurate) == "boolean", "Accuracy check should return boolean")
    
    -- Test deterministic behavior
    local rngState2, _ = LogicProcessTemplate.initializeRNG("accuracy-test-seed")
    local accurate2 = BattleEngine.checkAccuracy(mockMove, mockPlayerPokemon, mockEnemyPokemon, rngState2)
    
    assert(accurate == accurate2, "Same seed should produce same accuracy result")
    
    -- Test low accuracy move
    local lowAccuracyMove = {
        id = 99,
        name = "Thunder",
        type = "electric",
        power = 110,
        accuracy = 70
    }
    
    local missCount = 0
    local totalAccuracyTests = 100
    
    for i = 1, totalAccuracyTests do
        local rngStateLoop, _ = LogicProcessTemplate.initializeRNG("accuracy-loop-" .. i)
        local hit = BattleEngine.checkAccuracy(lowAccuracyMove, mockPlayerPokemon, mockEnemyPokemon, rngStateLoop)
        if not hit then
            missCount = missCount + 1
        end
    end
    
    -- Should have some misses with 70% accuracy over 100 tests
    assert(missCount > 0, "70% accuracy move should miss occasionally")
    
    print("✓ Accuracy check tests passed")
end

-- Test 4: Damage calculation
function tests.testDamageCalculation()
    print("Testing damage calculation...")
    
    local rngState, _ = LogicProcessTemplate.initializeRNG("damage-test-seed")
    
    -- Test physical attack damage
    local damageResult = BattleEngine.calculateDamage(
        mockPlayerPokemon,
        mockEnemyPokemon,
        mockMove,
        {},
        rngState
    )
    
    assert(type(damageResult) == "table", "Damage result should be a table")
    assert(type(damageResult.damage) == "number", "Damage should be a number")
    assert(damageResult.damage >= 0, "Damage should be non-negative")
    assert(type(damageResult.effectiveness) == "number", "Effectiveness should be a number")
    assert(type(damageResult.criticalHit) == "boolean", "Critical hit should be boolean")
    
    -- Test special attack damage
    local rngState2, _ = LogicProcessTemplate.initializeRNG("damage-test-seed-2")
    local specialDamageResult = BattleEngine.calculateDamage(
        mockPlayerPokemon,
        mockEnemyPokemon,
        mockSpecialMove,
        {},
        rngState2
    )
    
    assert(type(specialDamageResult.damage) == "number", "Special damage should be a number")
    
    -- Test deterministic behavior
    local rngState3, _ = LogicProcessTemplate.initializeRNG("damage-test-seed")
    local damageResult2 = BattleEngine.calculateDamage(
        mockPlayerPokemon,
        mockEnemyPokemon,
        mockMove,
        {},
        rngState3
    )
    
    assert(damageResult.damage == damageResult2.damage, "Same seed should produce same damage")
    assert(damageResult.criticalHit == damageResult2.criticalHit, "Same seed should produce same critical hit")
    
    -- Test super effective damage
    local fireMove = {
        id = 3,
        name = "Ember",
        type = "fire",
        category = "special",
        power = 40,
        accuracy = 100
    }
    
    local grassPokemon = LogicProcessTemplate.Utils.deepCopy(mockEnemyPokemon)
    grassPokemon.type1 = "grass"
    
    local rngState4, _ = LogicProcessTemplate.initializeRNG("fire-vs-grass-seed")
    local superEffectiveDamage = BattleEngine.calculateDamage(
        mockPlayerPokemon,
        grassPokemon,
        fireMove,
        {},
        rngState4
    )
    
    assert(superEffectiveDamage.effectiveness == 2.0, "Fire vs Grass should be super effective")
    
    print("✓ Damage calculation tests passed")
end

-- Test 5: Apply damage to Pokemon
function tests.testApplyDamage()
    print("Testing apply damage to Pokemon...")
    
    local originalPokemon = LogicProcessTemplate.Utils.deepCopy(mockPlayerPokemon)
    
    -- Test normal damage
    local damagedPokemon = BattleEngine.applyDamage(originalPokemon, 50)
    assert(damagedPokemon.hp == 100, "Pokemon HP should be reduced by damage amount")
    assert(originalPokemon.hp == 150, "Original Pokemon should not be modified")
    
    -- Test overkill damage (causes fainting)
    local faintedPokemon = BattleEngine.applyDamage(originalPokemon, 200)
    assert(faintedPokemon.hp == 0, "Pokemon HP should not go below 0")
    assert(faintedPokemon.statusEffect == "faint", "Pokemon should have faint status")
    
    -- Test exact damage to reach 0 HP
    local exactFaintPokemon = BattleEngine.applyDamage(originalPokemon, 150)
    assert(exactFaintPokemon.hp == 0, "Pokemon should have exactly 0 HP")
    assert(exactFaintPokemon.statusEffect == "faint", "Pokemon should faint at 0 HP")
    
    print("✓ Apply damage tests passed")
end

-- Test 6: Battle turn processing
function tests.testBattleTurnProcessing()
    print("Testing battle turn processing...")
    
    local testGameState = LogicProcessTemplate.Utils.deepCopy(mockGameState)
    local rngState, _ = LogicProcessTemplate.initializeRNG(testGameState.battle.battleSeed)
    
    local battleCommand = {
        action = "attack",
        moveId = 1
    }
    
    -- Test successful battle turn
    local turnResult = BattleEngine.processBattleTurn(testGameState, battleCommand, rngState)
    
    assert(type(turnResult) == "table", "Turn result should be a table")
    assert(turnResult.gameState ~= nil, "Turn result should contain gameState")
    assert(turnResult.turnResults ~= nil, "Turn result should contain turnResults")
    assert(type(turnResult.battleEnded) == "boolean", "Turn result should contain battleEnded boolean")
    
    -- Check that turn counter incremented
    assert(turnResult.gameState.battle.turn == 2, "Turn counter should increment")
    
    -- Check that actions were recorded
    assert(type(turnResult.turnResults.actions) == "table", "Turn results should contain actions")
    assert(#turnResult.turnResults.actions > 0, "Should have at least one action")
    
    -- Check turn results structure
    local firstAction = turnResult.turnResults.actions[1]
    assert(firstAction.actor ~= nil, "Action should have actor")
    assert(firstAction.action ~= nil, "Action should have action type")
    
    print("✓ Battle turn processing tests passed")
end

-- Test 7: Battle end conditions
function tests.testBattleEndConditions()
    print("Testing battle end conditions...")
    
    local testGameState = LogicProcessTemplate.Utils.deepCopy(mockGameState)
    -- Set enemy Pokemon to very low HP
    testGameState.battle.enemyParty[1].hp = 1
    testGameState.battle.enemyParty[1].maxHp = 140
    
    local rngState, _ = LogicProcessTemplate.initializeRNG(testGameState.battle.battleSeed)
    
    local battleCommand = {
        action = "attack",
        moveId = 1
    }
    
    -- Process turn that should end the battle
    local turnResult = BattleEngine.processBattleTurn(testGameState, battleCommand, rngState)
    
    -- Battle should end if enemy Pokemon faints
    if turnResult.gameState.battle.enemyParty[1].hp <= 0 then
        assert(turnResult.battleEnded == true, "Battle should end when Pokemon faints")
        assert(turnResult.winner == "player", "Player should win when enemy faints")
        assert(turnResult.gameState.battle.status == "completed", "Battle status should be completed")
        assert(turnResult.gameState.battle.result == "victory", "Battle result should be victory")
    end
    
    print("✓ Battle end condition tests passed")
end

-- Test 8: Logic operation handling
function tests.testLogicOperationHandling()
    print("Testing logic operation handling...")
    
    local rngState, _ = LogicProcessTemplate.initializeRNG("logic-test-seed")
    
    -- Test calculateDamage operation
    local damageParams = {
        attacker = mockPlayerPokemon,
        defender = mockEnemyPokemon,
        move = mockMove,
        battleConditions = {}
    }
    
    local damageOpResult = BattleEngine.handleLogicOperation(mockGameState, "calculateDamage", damageParams, rngState)
    assert(damageOpResult.gameState ~= nil, "Damage operation should return gameState")
    assert(damageOpResult.damageResult ~= nil, "Damage operation should return damageResult")
    assert(type(damageOpResult.damageResult.damage) == "number", "Damage result should contain damage number")
    
    -- Test processBattleTurn operation
    local turnParams = {
        battleCommand = {
            action = "attack",
            moveId = 1
        }
    }
    
    local turnOpResult = BattleEngine.handleLogicOperation(mockGameState, "processBattleTurn", turnParams, rngState)
    assert(turnOpResult.gameState ~= nil, "Turn operation should return gameState")
    assert(turnOpResult.turnResults ~= nil, "Turn operation should return turnResults")
    
    -- Test checkAccuracy operation
    local accuracyParams = {
        move = mockMove,
        attacker = mockPlayerPokemon,
        defender = mockEnemyPokemon
    }
    
    local accuracyOpResult = BattleEngine.handleLogicOperation(mockGameState, "checkAccuracy", accuracyParams, rngState)
    assert(accuracyOpResult.gameState ~= nil, "Accuracy operation should return gameState")
    assert(type(accuracyOpResult.accuracyResult) == "boolean", "Accuracy operation should return boolean result")
    
    -- Test invalid operation
    local success, error = pcall(function()
        BattleEngine.handleLogicOperation(mockGameState, "invalidOperation", {}, rngState)
    end)
    assert(success == false, "Invalid operation should throw error")
    assert(string.find(error, "Unknown"), "Error should mention unknown operation")
    
    print("✓ Logic operation handling tests passed")
end

-- Test 9: Message handling integration
function tests.testMessageHandling()
    print("Testing message handling integration...")
    
    local message = {
        Action = "ProcessLogic",
        Data = {
            gameState = mockGameState,
            operation = "calculateDamage",
            parameters = {
                attacker = mockPlayerPokemon,
                defender = mockEnemyPokemon,
                move = mockMove
            }
        },
        Timestamp = os.time(),
        From = "test-sender"
    }
    
    -- Test message handling through template
    local response = LogicProcessTemplate.handleMessage(message, "battle-engine", BattleEngine.handleLogicOperation)
    
    assert(response.Action == "SaveState", "Response should use SaveState action")
    assert(response.ProcessId == "battle-engine", "Response should include correct process ID")
    assert(response.Data ~= nil, "Response should contain data")
    assert(response.Data.result ~= nil, "Response should contain result")
    assert(response.Data.result.damageResult ~= nil, "Response should contain damage result")
    
    print("✓ Message handling integration tests passed")
end

-- Test 10: Performance requirements
function tests.testPerformanceRequirements()
    print("Testing performance requirements...")
    
    local rngState, _ = LogicProcessTemplate.initializeRNG("performance-test-seed")
    
    -- Test that battle turn processing completes quickly
    local startTime = os.clock()
    
    local battleCommand = {
        action = "attack",
        moveId = 1
    }
    
    local turnResult = BattleEngine.processBattleTurn(mockGameState, battleCommand, rngState)
    
    local endTime = os.clock()
    local executionTime = (endTime - startTime) * 1000 -- Convert to milliseconds
    
    assert(executionTime < 5000, "Battle turn should complete in under 5 seconds")
    assert(turnResult ~= nil, "Performance test should still return valid result")
    
    print("Battle turn execution time: " .. string.format("%.2f", executionTime) .. "ms")
    print("✓ Performance requirements tests passed")
end

-- Run all tests
function tests.runAllTests()
    print("Running Battle Engine unit tests...")
    print("=" .. string.rep("=", 50))
    
    tests.testTypeEffectiveness()
    tests.testCriticalHit()
    tests.testAccuracyCheck()
    tests.testDamageCalculation()
    tests.testApplyDamage()
    tests.testBattleTurnProcessing()
    tests.testBattleEndConditions()
    tests.testLogicOperationHandling()
    tests.testMessageHandling()
    tests.testPerformanceRequirements()
    
    print("=" .. string.rep("=", 50))
    print("✅ All Battle Engine tests passed!")
    return true
end

-- Export test runner
return tests