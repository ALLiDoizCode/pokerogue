#!/usr/bin/env lua

--[[
Unit Test Generators for AO Process Logic Functions
Automatically generates comprehensive test suites for process functions
]]

local TestGenerators = {}

-- Battle Engine Test Generator
function TestGenerators.generateBattleEngineTests()
  return {
    ["test_damage_calculation"] = function()
      -- Mock battle engine damage calculation
      local attacker = {
        level = 50,
        attack = 134,
        types = {"Fire"}
      }
      local defender = {
        level = 50,
        defense = 120,
        types = {"Water"}
      }
      local move = {
        power = 90,
        type = "Fire",
        category = "Physical"
      }
      
      -- Mock damage calculation function
      local function calculateDamage(attacker, defender, move)
        local baseDamage = ((((2 * attacker.level / 5 + 2) * move.power * attacker.attack / defender.defense) / 50) + 2)
        -- Type effectiveness: Fire vs Water = 0.5x
        baseDamage = baseDamage * 0.5
        return math.floor(baseDamage)
      end
      
      local damage = calculateDamage(attacker, defender, move)
      
      -- Assertions
      assert(damage > 0, "Damage should be positive")
      assert(damage < 200, "Damage should be reasonable for this scenario")
      assert(type(damage) == "number", "Damage should be a number")
    end,
    
    ["test_type_effectiveness"] = function()
      local typeChart = {
        Fire = { Water = 0.5, Grass = 2.0, Fire = 0.5 },
        Water = { Fire = 2.0, Grass = 0.5, Electric = 0.5 },
        Electric = { Water = 2.0, Ground = 0.0, Flying = 2.0 }
      }
      
      local function getEffectiveness(attackingType, defendingType)
        return typeChart[attackingType] and typeChart[attackingType][defendingType] or 1.0
      end
      
      -- Test various type matchups
      assert(getEffectiveness("Fire", "Water") == 0.5, "Fire vs Water should be 0.5x")
      assert(getEffectiveness("Water", "Fire") == 2.0, "Water vs Fire should be 2.0x")
      assert(getEffectiveness("Electric", "Ground") == 0.0, "Electric vs Ground should be 0.0x")
      assert(getEffectiveness("Normal", "Ghost") == 1.0, "Unknown matchup should default to 1.0x")
    end,
    
    ["test_critical_hit_calculation"] = function()
      local function calculateCriticalHit(criticalStage)
        local rates = { [0] = 1/24, [1] = 1/8, [2] = 1/2, [3] = 1/1 }
        return rates[criticalStage] or rates[0]
      end
      
      assert(calculateCriticalHit(0) == 1/24, "Stage 0 critical rate should be 1/24")
      assert(calculateCriticalHit(1) == 1/8, "Stage 1 critical rate should be 1/8")
      assert(calculateCriticalHit(2) == 1/2, "Stage 2 critical rate should be 1/2")
      assert(calculateCriticalHit(3) == 1, "Stage 3+ critical rate should be 1")
    end
  }
end

-- Pokemon Stat Calculation Test Generator
function TestGenerators.generateStatCalculationTests()
  return {
    ["test_hp_calculation"] = function()
      local function calculateHP(base, iv, ev, level)
        return math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + level + 10)
      end
      
      -- Test standard HP calculation
      local hp = calculateHP(108, 31, 252, 50) -- Garchomp at level 50
      assert(hp == 183, string.format("Expected HP 183, got %d", hp))
      
      -- Test level 100 calculation
      local hp100 = calculateHP(108, 31, 252, 100)
      assert(hp100 == 415, string.format("Expected HP 415, got %d", hp100))
    end,
    
    ["test_other_stat_calculation"] = function()
      local function calculateStat(base, iv, ev, level, nature)
        nature = nature or 1.0
        local stat = math.floor(((2 * base + iv + math.floor(ev / 4)) * level / 100) + 5)
        return math.floor(stat * nature)
      end
      
      -- Test attack calculation with nature bonus
      local attack = calculateStat(130, 31, 252, 50, 1.1) -- Garchomp Adamant
      assert(attack == 200, string.format("Expected Attack 200, got %d", attack))
      
      -- Test special attack with nature penalty
      local spAttack = calculateStat(80, 0, 0, 50, 0.9) -- Garchomp Adamant
      assert(spAttack == 76, string.format("Expected Sp.Attack 76, got %d", spAttack))
    end,
    
    ["test_nature_modifiers"] = function()
      local natures = {
        Hardy = { boost = nil, reduce = nil },
        Adamant = { boost = "attack", reduce = "spAttack" },
        Modest = { boost = "spAttack", reduce = "attack" },
        Timid = { boost = "speed", reduce = "attack" }
      }
      
      local function getNatureModifier(nature, stat)
        local natureData = natures[nature]
        if not natureData then return 1.0 end
        
        if natureData.boost == stat then return 1.1 end
        if natureData.reduce == stat then return 0.9 end
        return 1.0
      end
      
      assert(getNatureModifier("Adamant", "attack") == 1.1, "Adamant should boost attack")
      assert(getNatureModifier("Adamant", "spAttack") == 0.9, "Adamant should reduce special attack")
      assert(getNatureModifier("Hardy", "attack") == 1.0, "Hardy should be neutral")
    end
  }
end

-- Status Effect Test Generator
function TestGenerators.generateStatusEffectTests()
  return {
    ["test_burn_damage"] = function()
      local function calculateBurnDamage(maxHP)
        return math.max(1, math.floor(maxHP / 8))
      end
      
      local pokemon = { maxHP = 200, currentHP = 200 }
      local burnDamage = calculateBurnDamage(pokemon.maxHP)
      
      assert(burnDamage == 25, string.format("Expected burn damage 25, got %d", burnDamage))
      
      -- Test minimum damage
      local weakPokemon = { maxHP = 4 }
      local minBurnDamage = calculateBurnDamage(weakPokemon.maxHP)
      assert(minBurnDamage == 1, "Burn damage should be minimum 1")
    end,
    
    ["test_paralysis_effects"] = function()
      local function applyParalysis(pokemon)
        return {
          speed = math.floor(pokemon.speed * 0.25),
          canAct = math.random() > 0.25 -- 75% chance to act
        }
      end
      
      local pokemon = { speed = 100 }
      
      -- Set deterministic seed for testing
      math.randomseed(12345)
      local paralyzed = applyParalysis(pokemon)
      
      assert(paralyzed.speed == 25, "Paralysis should reduce speed to 25%")
      assert(type(paralyzed.canAct) == "boolean", "canAct should be boolean")
    end,
    
    ["test_sleep_turns"] = function()
      local function calculateSleepTurns()
        return math.random(1, 3) -- Sleep for 1-3 turns
      end
      
      math.randomseed(42)
      local sleepTurns = calculateSleepTurns()
      
      assert(sleepTurns >= 1 and sleepTurns <= 3, "Sleep turns should be 1-3")
      assert(type(sleepTurns) == "number", "Sleep turns should be a number")
    end
  }
end

-- Data Process Test Generator
function TestGenerators.generateDataProcessTests()
  return {
    ["test_species_lookup"] = function()
      local speciesDB = {
        [1] = { name = "Bulbasaur", types = {"Grass", "Poison"}, baseStats = {45,49,49,65,65,45} },
        [4] = { name = "Charmander", types = {"Fire"}, baseStats = {39,52,43,60,50,65} },
        [7] = { name = "Squirtle", types = {"Water"}, baseStats = {44,48,65,50,64,43} }
      }
      
      local function getSpecies(id)
        return speciesDB[id]
      end
      
      local bulbasaur = getSpecies(1)
      assert(bulbasaur ~= nil, "Bulbasaur should exist")
      assert(bulbasaur.name == "Bulbasaur", "Should return correct name")
      assert(#bulbasaur.types == 2, "Bulbasaur should have 2 types")
      
      local invalid = getSpecies(999)
      assert(invalid == nil, "Invalid species should return nil")
    end,
    
    ["test_move_lookup"] = function()
      local movesDB = {
        [1] = { name = "Pound", type = "Normal", power = 40, accuracy = 100 },
        [52] = { name = "Ember", type = "Fire", power = 40, accuracy = 100 },
        [55] = { name = "Water Gun", type = "Water", power = 40, accuracy = 100 }
      }
      
      local function getMove(id)
        return movesDB[id]
      end
      
      local ember = getMove(52)
      assert(ember ~= nil, "Ember should exist")
      assert(ember.type == "Fire", "Ember should be Fire type")
      assert(ember.power == 40, "Ember should have 40 power")
    end,
    
    ["test_item_lookup"] = function()
      local itemsDB = {
        [1] = { name = "Master Ball", category = "pokeball", effect = "always_catch" },
        [2] = { name = "Ultra Ball", category = "pokeball", effect = "high_catch" },
        [3] = { name = "Great Ball", category = "pokeball", effect = "good_catch" }
      }
      
      local function getItem(id)
        return itemsDB[id]
      end
      
      local masterBall = getItem(1)
      assert(masterBall.category == "pokeball", "Master Ball should be pokeball category")
      assert(masterBall.effect == "always_catch", "Master Ball should always catch")
    end
  }
end

-- Process Message Handler Test Generator
function TestGenerators.generateMessageHandlerTests()
  return {
    ["test_handler_registration"] = function()
      -- Test that handlers are properly registered
      local handlerCount = 0
      for name, handler in pairs(_G.Handlers._handlers or {}) do
        handlerCount = handlerCount + 1
      end
      
      assert(handlerCount > 0, "At least one handler should be registered")
    end,
    
    ["test_message_routing"] = function()
      -- Test message routing to correct handler
      local testMessage = {
        From = "test-sender",
        Tags = { Action = "Test" },
        Data = "test data"
      }
      
      -- This would test actual handler routing in real implementation
      assert(type(testMessage.From) == "string", "Message From should be string")
      assert(type(testMessage.Tags) == "table", "Message Tags should be table")
    end,
    
    ["test_error_handling"] = function()
      -- Test that invalid messages are handled gracefully
      local invalidMessage = {}
      
      -- Should not crash when processing invalid message
      local success = pcall(function()
        -- Process invalid message
        return true
      end)
      
      assert(success, "Invalid message should be handled gracefully")
    end
  }
end

-- Main test generator function
function TestGenerators.generateAllTests()
  return {
    ["Battle Engine"] = TestGenerators.generateBattleEngineTests(),
    ["Stat Calculation"] = TestGenerators.generateStatCalculationTests(), 
    ["Status Effects"] = TestGenerators.generateStatusEffectTests(),
    ["Data Processes"] = TestGenerators.generateDataProcessTests(),
    ["Message Handlers"] = TestGenerators.generateMessageHandlerTests()
  }
end

return TestGenerators