-- Unit tests for Status Effects Engine Process
-- Tests status effect application, turn processing, removal, and interactions
-- Includes ADP v1.0 compliance validation

-- Add processes directory to package path for module loading
package.path = './?.lua;' .. package.path

-- Set up global AO environment for testing
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            -- Mock handler registration for testing
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

if not ao then
    ao = {
        send = function(msg)
            -- Mock ao.send for testing
        end,
        id = "test-status-effects-engine"
    }
end

if not json then
    json = {
        encode = function(t) return "encoded_json" end,
        decode = function(s) return {} end
    }
end

local StatusEffectsEngineModule = require("processes.status-effects-engine")
local StatusEffectsEngine = StatusEffectsEngineModule.StatusEffectsEngine
local STATUS_EFFECTS = StatusEffectsEngineModule.STATUS_EFFECTS

-- Test data fixtures
local mockHealthyPokemon = {
    speciesId = 25, -- Pikachu
    level = 10,
    hp = 30,
    maxHp = 35,
    stats = {hp = 35, attack = 30, defense = 25, spAttack = 30, spDefense = 25, speed = 45},
    type1 = "electric",
    type2 = nil,
    statusEffect = "none",
    statusTurns = 0,
    statusData = {}
}

local mockBurnedPokemon = {
    speciesId = 6, -- Charizard
    level = 50,
    hp = 150,
    maxHp = 160,
    stats = {hp = 160, attack = 100, defense = 90, spAttack = 120, spDefense = 90, speed = 110},
    type1 = "fire",
    type2 = "flying",
    statusEffect = "burn",
    statusTurns = 1,
    statusData = {severity = 1.0}
}

local mockPoisonedPokemon = {
    speciesId = 1, -- Bulbasaur
    level = 15,
    hp = 40,
    maxHp = 45,
    stats = {hp = 45, attack = 25, defense = 25, spAttack = 30, spDefense = 30, speed = 20},
    type1 = "grass",
    type2 = "poison",
    statusEffect = "poison",
    statusTurns = 2,
    statusData = {severity = 1.0}
}

local mockGameState = {
    playerId = "test-player-123",
    timestamp = 1695123456,
    version = 1,
    rng = {
        battleSeed = 12345,
        turnCounter = 1
    },
    battle = {
        turn = 1,
        weather = "none",
        environment = "normal"
    }
}

-- Test Suite
local tests = {}
local testCount = 0
local passedCount = 0

-- Helper function for running tests
local function runTest(name, testFunc)
    testCount = testCount + 1
    print("Running test " .. testCount .. ": " .. name)

    local success, result = pcall(testFunc)
    if success and result then
        passedCount = passedCount + 1
        print("  ✅ PASS")
    else
        print("  ❌ FAIL: " .. tostring(result or "Unknown error"))
    end
    print()
end

-- Helper function for deep copy
local function deepCopy(original)
    if type(original) ~= 'table' then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = deepCopy(value)
    end
    return copy
end

-- Test 1: Apply Burn Status Effect
tests.applyBurnStatusEffect = function()
    local pokemon = deepCopy(mockHealthyPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.applyStatusEffect(pokemon, "burn", rngState)

    assert(result.success, "Burn application should succeed")
    assert(result.statusEffect == "burn", "Pokemon should have burn status")
    assert(result.statusTurns == -1, "Burn should have permanent duration")
    assert(result.statusData.severity, "Burn should have severity data")

    return true
end

-- Test 2: Apply Poison Status Effect
tests.applyPoisonStatusEffect = function()
    local pokemon = deepCopy(mockHealthyPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.applyStatusEffect(pokemon, "poison", rngState)

    assert(result.success, "Poison application should succeed")
    assert(result.statusEffect == "poison", "Pokemon should have poison status")
    assert(result.statusTurns == -1, "Poison should have permanent duration")
    assert(result.statusData.severity, "Poison should have severity data")

    return true
end

-- Test 3: Apply Sleep Status Effect
tests.applySleepStatusEffect = function()
    local pokemon = deepCopy(mockHealthyPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.applyStatusEffect(pokemon, "sleep", rngState)

    assert(result.success, "Sleep application should succeed")
    assert(result.statusEffect == "sleep", "Pokemon should have sleep status")
    assert(result.statusTurns >= 1 and result.statusTurns <= 4, "Sleep should have 1-4 turn duration")

    return true
end

-- Test 4: Status Effect Immunity (Fire type immune to burn)
tests.testStatusImmunity = function()
    local pokemon = deepCopy(mockBurnedPokemon) -- Fire type
    pokemon.statusEffect = "none"
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.applyStatusEffect(pokemon, "burn", rngState)

    -- Fire types should be immune to burn
    assert(not result.success, "Fire type should be immune to burn")
    assert(result.reason and string.find(result.reason, "immune"), "Should indicate immunity")

    return true
end

-- Test 5: Process Burn Turn Damage
tests.processBurnTurnDamage = function()
    local pokemon = deepCopy(mockBurnedPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.processStatusTurn(pokemon, rngState, "none", 1)

    assert(result.success, "Burn turn processing should succeed")
    assert(result.damageDealt > 0, "Burn should deal damage")
    -- Burn should deal 1/16 max HP damage
    local expectedDamage = math.floor(pokemon.maxHp / 16)
    assert(result.damageDealt == expectedDamage, "Burn damage should be 1/16 max HP")
    assert(result.newHp < pokemon.hp, "HP should decrease")

    return true
end

-- Test 6: Process Poison Turn Damage
tests.processPoisonTurnDamage = function()
    local pokemon = deepCopy(mockPoisonedPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.processStatusTurn(pokemon, rngState, "none", 1)

    assert(result.success, "Poison turn processing should succeed")
    assert(result.damageDealt > 0, "Poison should deal damage")
    -- Poison should deal 1/8 max HP damage
    local expectedDamage = math.floor(pokemon.maxHp / 8)
    assert(result.damageDealt == expectedDamage, "Poison damage should be 1/8 max HP")
    assert(result.newHp < pokemon.hp, "HP should decrease")

    return true
end

-- Test 7: Remove Status Effect
tests.removeStatusEffect = function()
    local pokemon = deepCopy(mockBurnedPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.removeStatusEffect(pokemon, "heal", rngState)

    assert(result.success, "Status removal should succeed")
    assert(result.statusEffect == "none", "Pokemon should have no status effect")
    assert(result.statusTurns == 0, "Status turns should be reset")

    return true
end

-- Test 8: Check Status Interactions
tests.checkStatusInteractions = function()
    local pokemon = deepCopy(mockHealthyPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.checkStatusInteractions(pokemon, "burn", "none", rngState)

    assert(result.success, "Status interaction check should succeed")
    assert(result.canApply ~= nil, "Should indicate if status can be applied")
    assert(result.interactions, "Should provide interaction details")

    return true
end

-- Test 9: Validate Status Immunity Check
tests.validateStatusImmunity = function()
    local pokemon = deepCopy(mockBurnedPokemon) -- Fire type
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.validateStatusImmunity(pokemon, "burn", rngState)

    assert(result.success, "Immunity validation should succeed")
    assert(result.isImmune, "Fire type should be immune to burn")
    assert(result.immunityType, "Should specify immunity type")

    return true
end

-- Test 10: Calculate Status Damage
tests.calculateStatusDamage = function()
    local pokemon = deepCopy(mockBurnedPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.calculateStatusDamage(pokemon, "burn", 1, rngState)

    assert(result.success, "Damage calculation should succeed")
    assert(result.damage > 0, "Should calculate positive damage")
    assert(result.damage == math.floor(pokemon.maxHp / 16), "Burn damage should be 1/16 max HP")

    return true
end

-- Test 11: Sleep Turn Processing (Should Wake Up Eventually)
tests.processSleepTurns = function()
    local pokemon = deepCopy(mockHealthyPokemon)
    pokemon.statusEffect = "sleep"
    pokemon.statusTurns = 1
    pokemon.statusData = {turnsRemaining = 1}

    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.processStatusTurn(pokemon, rngState, "none", 1)

    assert(result.success, "Sleep turn processing should succeed")
    assert(result.statusEffect == "none", "Pokemon should wake up when turns remaining is 1")
    assert(result.statusTurns == 0, "Status turns should be reset")

    return true
end

-- Test 12: Environmental Effects Processing
tests.processEnvironmentalEffects = function()
    local pokemon = deepCopy(mockBurnedPokemon)
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.processEnvironmentalEffects(pokemon, "rain", rngState)

    assert(result.success, "Environmental effects processing should succeed")
    assert(result.effects, "Should provide environmental effects data")

    return true
end

-- Test 13: Check Move Restrictions
tests.checkMoveRestrictions = function()
    local pokemon = deepCopy(mockHealthyPokemon)
    pokemon.statusEffect = "sleep"
    pokemon.statusData = {turnsRemaining = 2}

    local mockMove = {name = "Tackle", type = "normal"}
    local rngState = {seed = 12345, counter = 1}

    local result = StatusEffectsEngine.checkMoveRestrictions(pokemon, mockMove, rngState)

    assert(result.success, "Move restriction check should succeed")
    assert(result.canUseMove ~= nil, "Should indicate if move can be used")

    return true
end

-- ADP v1.0 Compliance Tests
local adpTests = {}

-- Test ADP Info Handler Response
adpTests.testInfoHandler = function()
    local mockMessage = {
        Action = "Info",
        Data = {},
        Timestamp = 1234567890,
        From = "test-client"
    }

    -- In a real test environment, we would test the actual handler
    -- For now, we validate the metadata structure exists
    local metadata = StatusEffectsEngineModule.PROCESS_METADATA

    assert(metadata, "Process metadata should exist")
    assert(metadata.adpVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(metadata.name, "Should have process name")
    assert(metadata.capabilities, "Should have capabilities list")
    assert(metadata.messageSchemas, "Should have message schemas")

    -- Validate required capabilities
    local requiredCapabilities = {
        "applyStatusEffect",
        "processStatusTurn",
        "removeStatusEffect",
        "checkStatusInteractions"
    }

    for _, capability in ipairs(requiredCapabilities) do
        local found = false
        for _, existing in ipairs(metadata.capabilities) do
            if existing == capability then
                found = true
                break
            end
        end
        assert(found, "Should have capability: " .. capability)
    end

    return true
end

-- Test Message Schema Validation
adpTests.testMessageSchemas = function()
    local metadata = StatusEffectsEngineModule.PROCESS_METADATA
    local schemas = metadata.messageSchemas

    assert(schemas.ProcessLogic, "Should have ProcessLogic schema")
    assert(schemas.HealthCheck, "Should have HealthCheck schema")
    assert(schemas.Info, "Should have Info schema")

    -- Validate ProcessLogic schema structure
    local processLogicSchema = schemas.ProcessLogic
    assert(processLogicSchema.required, "ProcessLogic should have required fields")
    assert(processLogicSchema.properties, "ProcessLogic should have properties")

    -- Check required fields
    local requiredFields = {"Action", "Data", "Timestamp"}
    for _, field in ipairs(requiredFields) do
        local found = false
        for _, existing in ipairs(processLogicSchema.required) do
            if existing == field then
                found = true
                break
            end
        end
        assert(found, "ProcessLogic should require field: " .. field)
    end

    return true
end

-- Run all core functionality tests
print("=== Status Effects Engine Unit Tests ===")
print()

for testName, testFunc in pairs(tests) do
    runTest(testName, testFunc)
end

-- Run ADP compliance tests
print("=== ADP v1.0 Compliance Tests ===")
print()

for testName, testFunc in pairs(adpTests) do
    runTest(testName, testFunc)
end

-- Test results summary
print("=== Test Results Summary ===")
print("Total tests: " .. testCount)
print("Passed: " .. passedCount)
print("Failed: " .. (testCount - passedCount))
print()

if passedCount == testCount then
    print("✅ All tests passed! Status Effects Engine is working correctly.")
    os.exit(0)
else
    print("❌ Some tests failed. Review the failures above.")
    os.exit(1)
end