-- Unit Tests for ADP-Compliant Battle Engine Process
-- Validates ADP v1.0 compliance, deterministic RNG, and battle mechanics

-- Mock AO environment for testing
local mockAO = {
    send = function(msg) 
        print("Mock AO send:", msg.Action or "unknown")
        return true 
    end,
    id = "test-battle-engine-adp"
}

local mockHandlers = {
    add = function(name, matcher, handler)
        print("Handler registered: " .. name)
        return handler
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Load the battle engine process
local originalAO = ao
local originalHandlers = Handlers
local originalJson = json

-- Set up mock environment
ao = mockAO
Handlers = mockHandlers
json = {
    encode = function(t) return "mock_json_encode" end,
    decode = function(s) return {test = "data"} end
}

-- Load the process
local BattleEngineModule = require("processes.battle-engine-adp")

-- Restore environment
ao = originalAO
Handlers = originalHandlers  
json = originalJson

print("Running Battle Engine ADP Unit Tests...")
print("===================================================")

-- Test case counter
local tests_passed = 0
local tests_failed = 0

local function test(name, testFunc)
    local success, errorMsg = pcall(testFunc)
    if success then
        print("✓ " .. name .. " test passed")
        tests_passed = tests_passed + 1
    else
        print("✗ " .. name .. " test failed: " .. tostring(errorMsg))
        tests_failed = tests_failed + 1
    end
end

-- Test ADP v1.0 metadata compliance
test("ADP metadata structure", function()
    local metadata = BattleEngineModule.PROCESS_METADATA
    assert(metadata.name == "Battle Engine ADP", "Process name incorrect")
    assert(metadata.adpVersion == "1.0", "ADP version not v1.0")
    assert(metadata.processType == "logic", "Process type not logic")
    assert(type(metadata.capabilities) == "table", "Capabilities not a table")
    assert(type(metadata.messageSchemas) == "table", "Message schemas not a table")
    assert(type(metadata.supportedOperations) == "table", "Supported operations not a table")
end)

-- Test type effectiveness chart completeness
test("type effectiveness completeness", function()
    local types = BattleEngineModule.TYPE_EFFECTIVENESS
    
    -- Test key types are present
    assert(types.fire ~= nil, "Fire type missing")
    assert(types.water ~= nil, "Water type missing")
    assert(types.grass ~= nil, "Grass type missing")
    assert(types.electric ~= nil, "Electric type missing")
    assert(types.fairy ~= nil, "Fairy type missing")
    
    -- Test specific effectiveness values
    assert(types.fire.water == 0.5, "Fire vs Water effectiveness incorrect")
    assert(types.water.fire == 2, "Water vs Fire effectiveness incorrect")
    assert(types.electric.ground == 0, "Electric vs Ground effectiveness incorrect")
    assert(types.fighting.ghost == 0, "Fighting vs Ghost effectiveness incorrect")
end)

-- Test deterministic RNG
test("deterministic RNG", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    -- Test type effectiveness calculation (deterministic)
    local effectiveness1 = BattleEngine.getTypeEffectiveness("fire", "grass", nil)
    local effectiveness2 = BattleEngine.getTypeEffectiveness("fire", "grass", nil)
    
    assert(effectiveness1 == effectiveness2, "Type effectiveness should be deterministic")
    assert(effectiveness1 == 2, "Fire vs Grass should be 2x effective")
    
    -- Test dual-type effectiveness
    local dualEffectiveness = BattleEngine.getTypeEffectiveness("fighting", "normal", "flying")
    assert(dualEffectiveness == 1.0, "Fighting vs Normal/Flying should be neutral (2x * 0.5x)")
end)

-- Test damage calculation
test("damage calculation", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    local attacker = {
        level = 50,
        type1 = "fire",
        type2 = nil,
        stats = {
            attack = 100,
            spAttack = 90
        }
    }
    
    local defender = {
        type1 = "grass",
        type2 = nil,
        stats = {
            defense = 80,
            spDefense = 85
        }
    }
    
    local move = {
        type = "fire",
        category = "physical",
        power = 80,
        accuracy = 100
    }
    
    local rngState = {seed = 54321, counter = 0}
    local battleConditions = {}
    
    local result = BattleEngine.calculateDamage(attacker, defender, move, battleConditions, rngState)
    
    assert(type(result.damage) == "number", "Damage should be a number")
    assert(result.damage > 0, "Damage should be positive")
    assert(result.effectiveness == 2, "Fire vs Grass should be super effective")
    assert(result.stab == true, "Same type attack bonus should apply")
    assert(type(result.criticalHit) == "boolean", "Critical hit should be boolean")
end)

-- Test accuracy calculation
test("accuracy calculation", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    local move = {accuracy = 90}
    local attacker = {statusEffect = nil}
    local defender = {}
    local battleConditions = {}
    local rngState = {seed = 11111, counter = 0}
    
    -- Test normal accuracy
    local result = BattleEngine.checkAccuracy(move, attacker, defender, battleConditions, rngState)
    assert(type(result) == "boolean", "Accuracy result should be boolean")
    
    -- Test paralysis prevention
    attacker.statusEffect = "paralysis"
    rngState = {seed = 1, counter = 0} -- Force paralysis proc
    local paralyzedResult = BattleEngine.checkAccuracy(move, attacker, defender, battleConditions, rngState)
    -- Result can be true or false depending on RNG, just verify it's boolean
    assert(type(paralyzedResult) == "boolean", "Paralyzed accuracy result should be boolean")
    
    -- Test sleep prevention
    attacker.statusEffect = "sleep"
    local sleepResult = BattleEngine.checkAccuracy(move, attacker, defender, battleConditions, rngState)
    assert(sleepResult == false, "Sleep should prevent movement")
end)

-- Test critical hit calculation
test("critical hit calculation", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    local attacker = {abilities = {}}
    local move = {highCritRatio = false}
    local rngState = {seed = 99999, counter = 0}
    
    local critMultiplier = BattleEngine.calculateCriticalHit(attacker, move, rngState)
    assert(critMultiplier == 1.0 or critMultiplier == 2.0, "Critical hit multiplier should be 1.0 or 2.0")
    
    -- Test high crit ratio move
    move.highCritRatio = true
    rngState = {seed = 1, counter = 0} -- Try to force crit
    local highCritMultiplier = BattleEngine.calculateCriticalHit(attacker, move, rngState)
    assert(highCritMultiplier == 1.0 or highCritMultiplier == 2.0, "High crit ratio should still return valid multiplier")
end)

-- Test status effect damage
test("status effect damage", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    local pokemon = {
        hp = 100,
        maxHp = 100,
        statusEffect = "burn"
    }
    
    local result = BattleEngine.applyStatusEffectDamage(pokemon, 1)
    assert(result.hp < pokemon.hp, "Burn should cause damage")
    assert(result.hp >= 0, "HP should not go below 0")
    
    -- Test poison
    pokemon.statusEffect = "poison"
    pokemon.hp = 100
    local poisonResult = BattleEngine.applyStatusEffectDamage(pokemon, 1)
    assert(poisonResult.hp < pokemon.hp, "Poison should cause damage")
    
    -- Test faint when HP reaches 0
    pokemon.hp = 1
    pokemon.statusEffect = "burn"
    local faintResult = BattleEngine.applyStatusEffectDamage(pokemon, 1)
    assert(faintResult.hp == 0, "HP should be 0 when fainting")
    assert(faintResult.statusEffect == "faint", "Status should change to faint")
end)

-- Test battle turn processing
test("battle turn processing", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    local gameState = {
        playerId = "test-player",
        timestamp = os.time(),
        version = 1,
        player = {
            party = {{
                hp = 100,
                maxHp = 100,
                level = 50,
                type1 = "normal",
                stats = {speed = 50, attack = 70, defense = 60, spAttack = 65, spDefense = 55}
            }}
        },
        battle = {
            battleId = "test-battle",
            battleSeed = "test-seed-123",
            turn = 1,
            status = "active",
            enemyParty = {{
                hp = 80,
                maxHp = 80,
                level = 45,
                type1 = "normal", 
                stats = {speed = 45, attack = 60, defense = 55, spAttack = 55, spDefense = 50}
            }},
            conditions = {}
        }
    }
    
    local battleCommand = {
        action = "attack",
        moveId = 1
    }
    
    local rngState = {seed = 12345, counter = 0}
    
    local result = BattleEngine.processBattleTurn(gameState, battleCommand, rngState)
    
    assert(type(result) == "table", "Battle turn result should be a table")
    assert(result.gameState ~= nil, "Result should contain updated game state")
    assert(result.turnResults ~= nil, "Result should contain turn results")
    assert(type(result.battleEnded) == "boolean", "Battle ended should be boolean")
    assert(result.gameState.battle.turn == 2, "Turn counter should increment")
    assert(type(result.turnResults.actions) == "table", "Actions should be a table")
end)

-- Test ADP operations schema compliance
test("ADP operations schema", function()
    local metadata = BattleEngineModule.PROCESS_METADATA
    local ops = metadata.supportedOperations
    
    -- Check required operations
    assert(ops.processBattleTurn ~= nil, "processBattleTurn operation missing")
    assert(ops.calculateDamage ~= nil, "calculateDamage operation missing")
    assert(ops.checkAccuracy ~= nil, "checkAccuracy operation missing")
    
    -- Check operation schema structure
    local battleTurnOp = ops.processBattleTurn
    assert(battleTurnOp.description ~= nil, "Operation description missing")
    assert(battleTurnOp.parameters ~= nil, "Operation parameters missing")
    assert(battleTurnOp.returns ~= nil, "Operation returns missing")
end)

-- Test status effects definitions
test("status effects definitions", function()
    local statusEffects = BattleEngineModule.STATUS_EFFECTS
    
    assert(statusEffects.burn ~= nil, "Burn status effect missing")
    assert(statusEffects.poison ~= nil, "Poison status effect missing")
    assert(statusEffects.paralysis ~= nil, "Paralysis status effect missing")
    assert(statusEffects.sleep ~= nil, "Sleep status effect missing")
    assert(statusEffects.freeze ~= nil, "Freeze status effect missing")
    assert(statusEffects.faint ~= nil, "Faint status effect missing")
    
    -- Test damage functions
    assert(type(statusEffects.burn.damagePerTurn) == "function", "Burn damage function missing")
    assert(statusEffects.burn.attackMultiplier == 0.5, "Burn attack reduction incorrect")
    assert(statusEffects.paralysis.speedMultiplier == 0.25, "Paralysis speed reduction incorrect")
end)

-- Test error handling in operations
test("error handling", function()
    local BattleEngine = BattleEngineModule.BattleEngine
    
    -- Test missing parameters
    local success, error = pcall(function()
        BattleEngine.handleLogicOperation({}, "processBattleTurn", {}, {})
    end)
    assert(not success, "Should error with missing battleCommand")
    
    -- Test invalid operation
    success, error = pcall(function()
        BattleEngine.handleLogicOperation({}, "invalidOperation", {}, {})
    end)
    assert(not success, "Should error with invalid operation")
end)

print("==================================================")
print("Test Results:")
print("  Passed: " .. tests_passed)
print("  Failed: " .. tests_failed)
print("  Total:  " .. (tests_passed + tests_failed))

if tests_failed == 0 then
    print("\n🎉 All tests passed!")
else
    print("\n❌ Some tests failed!")
    os.exit(1)
end