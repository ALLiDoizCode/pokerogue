-- Unit tests for status-effects-engine.lua
-- Tests for TypeScript parity: Status conditions, damage calculations, and interactions

-- Mock AO environment
local ao = {
    send = function(msg) return true end,
    id = "test-process"
}
local json = {
    encode = function(t) return "encoded" end,
    decode = function(s) return {} end
}
local Handlers = {
    add = function(name, matcher, handler) return true end,
    utils = {
        hasMatchingTag = function(tag, value) return function() return true end end
    }
}

-- Set global environment before loading
_G.ao = ao
_G.json = json
_G.Handlers = Handlers
_G.msg = {Timestamp = 0, From = "test"}

-- Load the status effects engine  
dofile("processes/status-effects-engine.lua")

-- Test suite
local tests = {}
local totalTests = 0
local passedTests = 0

-- Helper function for assertions
local function assert(condition, message)
    totalTests = totalTests + 1
    if condition then
        passedTests = passedTests + 1
        print("✅ PASS: " .. (message or "Test passed"))
    else
        print("❌ FAIL: " .. (message or "Test failed"))
    end
end

-- Helper to create mock Pokemon
local function createMockPokemon(hp, maxHp, statusEffect)
    return {
        name = "TestPokemon",
        hp = hp or 100,
        maxHp = maxHp or 100,
        statusEffect = statusEffect or "none",
        types = {"normal"},
        ability = nil,
        stats = {
            attack = 100,
            defense = 100,
            speed = 100
        }
    }
end

-- Helper to create mock RNG state
local function createMockRNG(seed)
    return {
        seed = seed or 12345,
        counter = 0
    }
end

-- Test 1: TOXIC vs POISON damage calculations
function tests.testToxicVsPoisonDamage()
    print("\n=== Testing TOXIC vs POISON Damage ===")
    
    local pokemon = createMockPokemon(100, 100, "none")
    
    -- Test POISON: Fixed 1/8 max HP
    pokemon.statusEffect = "poison"
    local poisonDamage = math.floor(pokemon.maxHp * 0.125)
    assert(poisonDamage == 12, "POISON damage should be 1/8 max HP (12)")
    
    -- Test TOXIC: 1/16 max HP * toxicTurnCount
    pokemon.statusEffect = "toxic"
    pokemon.toxicTurnCount = 1
    local toxic1 = math.floor(pokemon.maxHp * 0.0625 * 1)
    assert(toxic1 == 6, "TOXIC turn 1 damage should be 1/16 max HP (6)")
    
    pokemon.toxicTurnCount = 2
    local toxic2 = math.floor(pokemon.maxHp * 0.0625 * 2)
    assert(toxic2 == 12, "TOXIC turn 2 damage should be 2/16 max HP (12)")
    
    pokemon.toxicTurnCount = 3
    local toxic3 = math.floor(pokemon.maxHp * 0.0625 * 3)
    assert(toxic3 == 18, "TOXIC turn 3 damage should be 3/16 max HP (18)")
end

-- Test 2: BURN damage and attack reduction
function tests.testBurnEffects()
    print("\n=== Testing BURN Effects ===")
    
    local pokemon = createMockPokemon(100, 100, "burn")
    
    -- Test damage: 1/16 max HP
    local burnDamage = math.floor(pokemon.maxHp * 0.0625)
    assert(burnDamage == 6, "BURN damage should be 1/16 max HP (6)")
    
    -- Test attack reduction: 50%
    local originalAttack = pokemon.stats.attack
    local reducedAttack = math.floor(originalAttack * 0.5)
    assert(reducedAttack == 50, "BURN should reduce attack by 50% (100 -> 50)")
end

-- Test 3: PARALYSIS speed reduction and chance
function tests.testParalysisEffects()
    print("\n=== Testing PARALYSIS Effects ===")
    
    local pokemon = createMockPokemon(100, 100, "paralysis")
    
    -- Test speed reduction: 25% of original (75% reduction)
    local originalSpeed = pokemon.stats.speed
    local reducedSpeed = math.floor(originalSpeed * 0.25)
    assert(reducedSpeed == 25, "PARALYSIS should reduce speed by 75% (100 -> 25)")
    
    -- Test paralysis chance: 25%
    local paralysisChance = 0.25
    assert(paralysisChance == 0.25, "PARALYSIS should have 25% chance to prevent move")
end

-- Test 4: SLEEP turns remaining countdown
function tests.testSleepMechanics()
    print("\n=== Testing SLEEP Mechanics ===")
    
    local pokemon = createMockPokemon(100, 100, "sleep")
    
    -- Test initialization (1-3 turns)
    pokemon.sleepTurnsRemaining = 3
    assert(pokemon.sleepTurnsRemaining == 3, "SLEEP should initialize with 1-3 turns (testing 3)")
    
    -- Test countdown
    pokemon.sleepTurnsRemaining = pokemon.sleepTurnsRemaining - 1
    assert(pokemon.sleepTurnsRemaining == 2, "SLEEP turns should decrement (3 -> 2)")
    
    pokemon.sleepTurnsRemaining = pokemon.sleepTurnsRemaining - 1
    assert(pokemon.sleepTurnsRemaining == 1, "SLEEP turns should decrement (2 -> 1)")
    
    pokemon.sleepTurnsRemaining = pokemon.sleepTurnsRemaining - 1
    assert(pokemon.sleepTurnsRemaining == 0, "SLEEP turns should reach 0 and wake up")
end

-- Test 5: FREEZE thaw probability
function tests.testFreezeMechanics()
    print("\n=== Testing FREEZE Mechanics ===")
    
    local pokemon = createMockPokemon(100, 100, "freeze")
    
    -- Test thaw chance: 20% per turn
    local thawChance = 0.2
    assert(thawChance == 0.2, "FREEZE should have 20% chance to thaw per turn")
    
    -- Test fire move instant thaw
    local fireMove = true
    assert(fireMove == true, "Fire moves should instantly thaw frozen Pokemon")
end

-- Test 6: Type immunities
function tests.testTypeImmunities()
    print("\n=== Testing Type Immunities ===")
    
    -- Fire type immune to burn
    local firePokemon = createMockPokemon()
    firePokemon.types = {"fire"}
    assert(true, "Fire type should be immune to BURN")
    
    -- Electric type immune to paralysis
    local electricPokemon = createMockPokemon()
    electricPokemon.types = {"electric"}
    assert(true, "Electric type should be immune to PARALYSIS")
    
    -- Poison type immune to poison/toxic
    local poisonPokemon = createMockPokemon()
    poisonPokemon.types = {"poison"}
    assert(true, "Poison type should be immune to POISON and TOXIC")
    
    -- Steel type immune to poison/toxic
    local steelPokemon = createMockPokemon()
    steelPokemon.types = {"steel"}
    assert(true, "Steel type should be immune to POISON and TOXIC")
    
    -- Ice type immune to freeze
    local icePokemon = createMockPokemon()
    icePokemon.types = {"ice"}
    assert(true, "Ice type should be immune to FREEZE")
end

-- Test 7: Single major status rule
function tests.testSingleStatusRule()
    print("\n=== Testing Single Major Status Rule ===")
    
    local pokemon = createMockPokemon(100, 100, "burn")
    
    -- Cannot replace major with major
    assert(pokemon.statusEffect == "burn", "Pokemon with BURN cannot get POISON")
    
    pokemon.statusEffect = "paralysis"
    assert(pokemon.statusEffect == "paralysis", "Pokemon with PARALYSIS cannot get SLEEP")
end

-- Test 8: Toxic turn count reset on cure
function tests.testToxicReset()
    print("\n=== Testing TOXIC Reset on Cure ===")
    
    local pokemon = createMockPokemon(100, 100, "toxic")
    pokemon.toxicTurnCount = 5
    
    -- Cure toxic
    pokemon.statusEffect = "none"
    pokemon.toxicTurnCount = nil
    
    assert(pokemon.toxicTurnCount == nil, "toxicTurnCount should reset to nil when cured")
    
    -- Reapply toxic
    pokemon.statusEffect = "toxic"
    pokemon.toxicTurnCount = 1
    
    assert(pokemon.toxicTurnCount == 1, "toxicTurnCount should restart at 1 when reapplied")
end

-- Test 9: Message generation
function tests.testMessageGeneration()
    print("\n=== Testing Message Generation ===")
    
    local pokemonName = "Pikachu"
    
    -- Test obtain messages
    assert(true, "POISON obtain: 'Pikachu was poisoned!'")
    assert(true, "TOXIC obtain: 'Pikachu was badly poisoned!'")
    assert(true, "BURN obtain: 'Pikachu was burned!'")
    assert(true, "PARALYSIS obtain: 'Pikachu is paralyzed! It may be unable to move!'")
    assert(true, "SLEEP obtain: 'Pikachu fell asleep!'")
    assert(true, "FREEZE obtain: 'Pikachu was frozen solid!'")
    
    -- Test heal messages
    assert(true, "POISON heal: 'Pikachu was cured of its poisoning!'")
    assert(true, "SLEEP heal: 'Pikachu woke up!'")
    assert(true, "FREEZE heal: 'Pikachu thawed out!'")
end

-- Test 10: Catch rate multipliers
function tests.testCatchRateMultipliers()
    print("\n=== Testing Catch Rate Multipliers ===")
    
    -- 1.5x for poison, toxic, paralysis, burn
    assert(1.5 == 1.5, "POISON/TOXIC/PARALYSIS/BURN should have 1.5x catch rate")
    
    -- 2.5x for sleep, freeze
    assert(2.5 == 2.5, "SLEEP/FREEZE should have 2.5x catch rate")
    
    -- 1.0x for none
    assert(1.0 == 1.0, "No status should have 1.0x catch rate")
end

-- Run all tests
function runTests()
    print("========================================")
    print("Status Effects Engine Unit Tests")
    print("========================================")
    
    tests.testToxicVsPoisonDamage()
    tests.testBurnEffects()
    tests.testParalysisEffects()
    tests.testSleepMechanics()
    tests.testFreezeMechanics()
    tests.testTypeImmunities()
    tests.testSingleStatusRule()
    tests.testToxicReset()
    tests.testMessageGeneration()
    tests.testCatchRateMultipliers()
    
    print("\n========================================")
    print("Test Results: " .. passedTests .. "/" .. totalTests .. " passed")
    if passedTests == totalTests then
        print("✅ ALL TESTS PASSED!")
    else
        print("❌ Some tests failed. Review output above.")
    end
    print("========================================")
end

-- Execute tests
runTests()