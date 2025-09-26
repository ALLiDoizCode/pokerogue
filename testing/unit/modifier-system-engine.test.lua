-- Unit Tests for Modifier System Engine
-- Tests modifier lookup, effect calculations, usage validation, and consumption mechanics

local aolite = require('aolite')

-- Test Suite Configuration
local testSuite = {
    processPath = 'processes/modifier-system-engine.lua',
    processId = 'modifier-system-test',
    tests = {}
}

-- Helper function to create test Pokemon data
local function createTestPokemon(overrides)
    local defaults = {
        id = 1,
        level = 50,
        currentHP = 150,
        maxHP = 200,
        status = "NONE",
        isFainted = false,
        canEvolve = true,
        isConfused = false,
        statStages = {
            attack = 0,
            defense = 0,
            special_attack = 0,
            special_defense = 0,
            speed = 0
        },
        critBoost = false,
        moves = {
            {index = 1, id = 1, name = "Tackle", currentPP = 15, maxPP = 20},
            {index = 2, id = 2, name = "Scratch", currentPP = 0, maxPP = 10},
            {index = 3, id = 3, name = "Quick Attack", currentPP = 25, maxPP = 25},
            {index = 4, id = 4, name = "Growl", currentPP = 5, maxPP = 15}
        }
    }

    if overrides then
        for k, v in pairs(overrides) do
            defaults[k] = v
        end
    end

    return defaults
end

-- Helper function to create battle context
local function createBattleContext(overrides)
    local defaults = {
        hitBySuperEffective = false,
        wouldKO = false,
        moveFirst = false,
        berryThreshold = nil,
        doubleBerryEffect = false,
        randomSeed = 1
    }

    if overrides then
        for k, v in pairs(overrides) do
            defaults[k] = v
        end
    end

    return defaults
end

-- Test 1: Modifier Information Retrieval
function testSuite.tests.test_modifier_info_retrieval()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test valid modifier lookup
    local result = ao.send({
        Target = testSuite.processId,
        Action = "GetModifierInfo",
        ModifierId = "POTION"
    })

    assert(result.Success == "true", "Should successfully retrieve POTION info")
    local data = json.decode(result.Data)
    assert(data.modifierId == "POTION", "Should return correct modifier ID")
    assert(data.name == "Potion", "Should return correct name")
    assert(data.effectType == "healing", "Should return correct effect type")
    assert(data.consumable == true, "Should indicate consumable")

    -- Test invalid modifier lookup
    local errorResult = ao.send({
        Target = testSuite.processId,
        Action = "GetModifierInfo",
        ModifierId = "INVALID_MODIFIER"
    })

    assert(errorResult.Action == "Error", "Should return error for invalid modifier")
    assert(string.find(errorResult.Error, "not found"), "Should indicate modifier not found")

    -- Test held item lookup
    local heldResult = ao.send({
        Target = testSuite.processId,
        Action = "GetModifierInfo",
        ModifierId = "EVIOLITE"
    })

    assert(heldResult.Success == "true", "Should successfully retrieve EVIOLITE info")
    local heldData = json.decode(heldResult.Data)
    assert(heldData.isHeldItem == true, "Should indicate held item")
    assert(heldData.category == "HELD_ITEM", "Should have correct category")

    print("✓ Modifier information retrieval tests passed")
end

-- Test 2: Held Item Stat Effect Calculations
function testSuite.tests.test_held_item_stat_calculations()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Eviolite defense boost for unevolved Pokemon
    local pokemon = createTestPokemon({canEvolve = true})
    local result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(result.Success == "true", "Should calculate Eviolite effect")
    assert(result.StatMultiplier == "1.5", "Should boost defense by 1.5x for unevolved")

    -- Test Eviolite with evolved Pokemon (no boost)
    local evolvedPokemon = createTestPokemon({canEvolve = false})
    local evolvedResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({pokemonData = evolvedPokemon})
    })

    assert(evolvedResult.Success == "true", "Should calculate for evolved Pokemon")
    assert(evolvedResult.StatMultiplier == "1.0", "Should not boost evolved Pokemon")

    -- Test Eviolite special defense boost
    local spdefResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "special_defense",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(spdefResult.Success == "true", "Should calculate special defense boost")
    assert(spdefResult.StatMultiplier == "1.5", "Should boost special defense by 1.5x")

    -- Test non-boosted stat
    local atkResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "attack",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(atkResult.Success == "true", "Should process non-boosted stat")
    assert(atkResult.StatMultiplier == "1.0", "Should not boost attack")

    print("✓ Held item stat calculation tests passed")
end

-- Test 3: Usage Restriction Validation
function testSuite.tests.test_usage_restriction_validation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test valid potion usage on injured Pokemon
    local injuredPokemon = createTestPokemon({currentHP = 100, maxHP = 200, isFainted = false})
    local validResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "POTION",
        Context = "battle",
        Data = json.encode({pokemonData = injuredPokemon})
    })

    assert(validResult.Success == "true", "Should validate potion usage")
    assert(validResult.Valid == "true", "Should allow potion on injured Pokemon")

    -- Test invalid potion usage on full HP Pokemon
    local healthyPokemon = createTestPokemon({currentHP = 200, maxHP = 200, isFainted = false})
    local invalidResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "POTION",
        Context = "battle",
        Data = json.encode({pokemonData = healthyPokemon})
    })

    assert(invalidResult.Success == "true", "Should process validation")
    assert(invalidResult.Valid == "false", "Should reject potion on full HP Pokemon")
    assert(string.find(invalidResult.Reason, "full HP"), "Should indicate full HP reason")

    -- Test revive on fainted Pokemon
    local faintedPokemon = createTestPokemon({currentHP = 0, isFainted = true})
    local reviveResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "REVIVE",
        Context = "battle",
        Data = json.encode({pokemonData = faintedPokemon})
    })

    assert(reviveResult.Success == "true", "Should validate revive usage")
    assert(reviveResult.Valid == "true", "Should allow revive on fainted Pokemon")

    -- Test revive on conscious Pokemon
    local consciousPokemon = createTestPokemon({currentHP = 100, isFainted = false})
    local invalidReviveResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "REVIVE",
        Context = "battle",
        Data = json.encode({pokemonData = consciousPokemon})
    })

    assert(invalidReviveResult.Success == "true", "Should process revive validation")
    assert(invalidReviveResult.Valid == "false", "Should reject revive on conscious Pokemon")

    -- Test context validation
    local wrongContextResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "RARE_CANDY",
        Context = "battle",
        Data = json.encode({pokemonData = injuredPokemon})
    })

    assert(wrongContextResult.Success == "true", "Should process context validation")
    assert(wrongContextResult.Valid == "false", "Should reject wrong context usage")
    assert(string.find(wrongContextResult.Reason, "Invalid usage context"), "Should indicate context error")

    print("✓ Usage restriction validation tests passed")
end

-- Test 4: Modifier Consumption Mechanics
function testSuite.tests.test_modifier_consumption_mechanics()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test potion consumption and healing
    local pokemon = createTestPokemon({currentHP = 100, maxHP = 200})
    local consumeResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "POTION",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(consumeResult.Success == "true", "Should process potion consumption")
    assert(consumeResult.Consumed == "true", "Should indicate item consumed")

    local resultData = json.decode(consumeResult.Data)
    assert(resultData.pokemonChanges.currentHP == 120, "Should heal 20 HP")
    assert(#resultData.effects == 1, "Should have one effect")
    assert(resultData.effects[1].type == "heal", "Should be healing effect")
    assert(resultData.effects[1].amount == 20, "Should heal correct amount")

    -- Test Max Potion full heal
    local maxPotionResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "MAX_POTION",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(maxPotionResult.Success == "true", "Should process Max Potion")
    local maxData = json.decode(maxPotionResult.Data)
    assert(maxData.pokemonChanges.currentHP == 200, "Should fully heal Pokemon")
    assert(maxData.effects[1].amount == 100, "Should heal remaining HP")

    -- Test Revive consumption
    local faintedPokemon = createTestPokemon({currentHP = 0, maxHP = 200, isFainted = true})
    local reviveResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "REVIVE",
        Data = json.encode({pokemonData = faintedPokemon})
    })

    assert(reviveResult.Success == "true", "Should process revive")
    local reviveData = json.decode(reviveResult.Data)
    assert(reviveData.pokemonChanges.currentHP == 100, "Should revive with 50% HP")
    assert(reviveData.pokemonChanges.isFainted == false, "Should un-faint Pokemon")
    assert(reviveData.effects[1].type == "revive", "Should be revive effect")

    -- Test PP restoration
    local ppMove = {currentPP = 5, maxPP = 20}
    local etherResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "ETHER",
        Data = json.encode({
            pokemonData = pokemon,
            targetData = ppMove
        })
    })

    assert(etherResult.Success == "true", "Should process ether")
    local etherData = json.decode(etherResult.Data)
    assert(etherData.targetChanges.currentPP == 15, "Should restore 10 PP")
    assert(etherData.effects[1].type == "pp_restore", "Should be PP restore effect")

    -- Test level increment
    local lowLevelPokemon = createTestPokemon({level = 25})
    local candyResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "RARE_CANDY",
        Data = json.encode({pokemonData = lowLevelPokemon})
    })

    assert(candyResult.Success == "true", "Should process Rare Candy")
    local candyData = json.decode(candyResult.Data)
    assert(candyData.pokemonChanges.level == 26, "Should increase level by 1")
    assert(candyData.effects[1].type == "level_up", "Should be level up effect")

    print("✓ Modifier consumption mechanics tests passed")
end

-- Test 5: Held Item Trigger Conditions
function testSuite.tests.test_held_item_triggers()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Sitrus Berry trigger (HP < 50%)
    local lowHPPokemon = createTestPokemon({currentHP = 80, maxHP = 200}) -- 40% HP
    local sitrusResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = lowHPPokemon})
    })

    assert(sitrusResult.Success == "true", "Should check Sitrus trigger")
    assert(sitrusResult.ShouldTrigger == "true", "Should trigger at low HP")
    assert(string.find(sitrusResult.TriggerReason, "HP below 50%"), "Should indicate HP trigger")

    -- Test Sitrus Berry no trigger (HP > 50%)
    local highHPPokemon = createTestPokemon({currentHP = 120, maxHP = 200}) -- 60% HP
    local noTriggerResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = highHPPokemon})
    })

    assert(noTriggerResult.Success == "true", "Should check Sitrus no trigger")
    assert(noTriggerResult.ShouldTrigger == "false", "Should not trigger at high HP")

    -- Test Lum Berry trigger (has status)
    local statusPokemon = createTestPokemon({status = "POISON"})
    local lumResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "LUM_BERRY",
        Data = json.encode({pokemonData = statusPokemon})
    })

    assert(lumResult.Success == "true", "Should check Lum trigger")
    assert(lumResult.ShouldTrigger == "true", "Should trigger with status")
    assert(string.find(lumResult.TriggerReason, "status condition"), "Should indicate status trigger")

    -- Test Leppa Berry trigger (move out of PP)
    local pokemon = createTestPokemon() -- Has move with 0 PP
    local leppaResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "LEPPA_BERRY",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(leppaResult.Success == "true", "Should check Leppa trigger")
    assert(leppaResult.ShouldTrigger == "true", "Should trigger with 0 PP move")
    assert(string.find(leppaResult.TriggerReason, "out of PP"), "Should indicate PP trigger")

    -- Test Leftovers trigger (HP not full)
    local injuredPokemon = createTestPokemon({currentHP = 150, maxHP = 200})
    local leftoversResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "LEFTOVERS",
        Data = json.encode({pokemonData = injuredPokemon})
    })

    assert(leftoversResult.Success == "true", "Should check Leftovers trigger")
    assert(leftoversResult.ShouldTrigger == "true", "Should trigger when injured")

    print("✓ Held item trigger condition tests passed")
end

-- Test 6: Modifier Stacking and Interactions
function testSuite.tests.test_modifier_stacking_interactions()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test multiple held items stacking
    local modifierList = {
        {id = "EVIOLITE", stackCount = 1},
        {id = "SCOPE_LENS", stackCount = 1},
        {id = "CHARCOAL", stackCount = 1}
    }

    local pokemon = createTestPokemon({canEvolve = true})
    local stackResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateModifierInteractions",
        Data = json.encode({
            modifierList = modifierList,
            pokemonData = pokemon
        })
    })

    assert(stackResult.Success == "true", "Should calculate stacking effects")
    local stackData = json.decode(stackResult.Data)
    assert(stackData.modifierCount == 3, "Should process all modifiers")
    assert(stackData.stackEffects.statMultipliers.defense == 1.5, "Should include Eviolite defense boost")
    assert(stackData.stackEffects.specialEffects.critBoost == 1, "Should include Scope Lens crit boost")
    assert(stackData.stackEffects.damageMultipliers.FIRE == 1.2, "Should include Charcoal fire boost")

    print("✓ Modifier stacking and interaction tests passed")
end

-- Test 7: ADP Compliance - Info Handler
function testSuite.tests.test_adp_compliance()
    local ao = aolite.spawn(testSuite.processPath)

    local infoResult = ao.send({
        Target = testSuite.processId,
        Action = "Info"
    })

    assert(infoResult.Success == nil and infoResult.Action == "SaveState", "Should use SaveState action")
    local infoData = json.decode(infoResult.Data)
    assert(infoData.process.name == "Modifier System Engine", "Should have correct process name")
    assert(infoData.process.adpVersion == "1.0", "Should declare ADP v1.0 compliance")
    assert(type(infoData.handlers) == "table", "Should list handlers")
    assert(type(infoData.capabilities) == "table", "Should list capabilities")
    assert(type(infoData.messageSchemas) == "table", "Should provide message schemas")
    assert(infoData.database.totalModifiers > 0, "Should report modifier count")

    -- Verify all expected handlers are documented
    local expectedHandlers = {
        "GetModifierInfo", "CalculateHeldModifierEffects", "ValidateModifierUsage",
        "ProcessModifierConsumption", "CalculateModifierInteractions",
        "CheckHeldItemTriggers", "Info"
    }

    for _, handler in ipairs(expectedHandlers) do
        local found = false
        for _, docHandler in ipairs(infoData.handlers) do
            if docHandler == handler then
                found = true
                break
            end
        end
        assert(found, "Should document handler: " .. handler)
    end

    print("✓ ADP v1.0 compliance tests passed")
end

-- Test 8: Error Handling
function testSuite.tests.test_error_handling()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test missing ModifierId parameter
    local missingIdResult = ao.send({
        Target = testSuite.processId,
        Action = "GetModifierInfo"
    })

    assert(missingIdResult.Action == "Error", "Should return error for missing ID")
    assert(string.find(missingIdResult.Error, "required"), "Should indicate required parameter")

    -- Test invalid modifier calculation
    local invalidCalcResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "INVALID_ITEM",
        Data = "{}"
    })

    assert(invalidCalcResult.Action == "Error", "Should return error for invalid modifier")

    -- Test malformed JSON
    local malformedResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "POTION",
        Data = "invalid json"
    })

    -- Should handle malformed JSON gracefully (empty object fallback)
    assert(malformedResult.Success == "true" or malformedResult.Action == "Error",
        "Should handle malformed JSON")

    print("✓ Error handling tests passed")
end

-- ============================================================================
-- BERRY SYSTEM UNIT TESTS
-- ============================================================================

-- Test: Berry Information Retrieval
function testSuite.tests.test_berry_info_retrieval()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test all berry types
    local berryIds = {
        "SITRUS_BERRY", "ENIGMA_BERRY", "LUM_BERRY", "LIECHI_BERRY",
        "GANLON_BERRY", "PETAYA_BERRY", "APICOT_BERRY", "SALAC_BERRY",
        "LANSAT_BERRY", "STARF_BERRY", "LEPPA_BERRY"
    }

    for _, berryId in ipairs(berryIds) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "GetBerryInfo",
            BerryId = berryId
        })

        assert(result.Success == "true", "Should successfully retrieve " .. berryId .. " info")
        local data = aolite.json.decode(result.Data)
        assert(data.berryId == berryId, "Should return correct berry ID")
        assert(data.name ~= nil, "Should have berry name")
        assert(data.description ~= nil, "Should have berry description")
        assert(data.effectType ~= nil, "Should have effect type")
        assert(data.triggerCondition ~= nil, "Should have trigger condition")
    end

    -- Test invalid berry
    local invalidResult = ao.send({
        Target = testSuite.processId,
        Action = "GetBerryInfo",
        BerryId = "INVALID_BERRY"
    })

    assert(invalidResult.Action == "Error", "Should return error for invalid berry")

    print("✓ Berry information retrieval tests passed")
end

-- Test: Berry Trigger Condition Evaluation
function testSuite.tests.test_berry_trigger_evaluation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Sitrus Berry (HP below 50%)
    local lowHpPokemon = createTestPokemon({currentHP = 80, maxHP = 200}) -- 40% HP
    local result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = lowHpPokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.Success == "true", "Should evaluate Sitrus Berry trigger")
    assert(result.ShouldTrigger == "true", "Should trigger at 40% HP")

    -- Test with high HP (shouldn't trigger)
    local highHpPokemon = createTestPokemon({currentHP = 150, maxHP = 200}) -- 75% HP
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = highHpPokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.ShouldTrigger == "false", "Should not trigger at 75% HP")

    -- Test Lum Berry (status condition)
    local poisonedPokemon = createTestPokemon({status = "POISON"})
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LUM_BERRY",
        Data = aolite.json.encode({
            pokemonData = poisonedPokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.ShouldTrigger == "true", "Should trigger for poisoned Pokemon")

    -- Test Lum Berry (confusion)
    local confusedPokemon = createTestPokemon({isConfused = true})
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LUM_BERRY",
        Data = aolite.json.encode({
            pokemonData = confusedPokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.ShouldTrigger == "true", "Should trigger for confused Pokemon")

    -- Test Leppa Berry (PP depleted)
    local noPpPokemon = createTestPokemon()
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LEPPA_BERRY",
        Data = aolite.json.encode({
            pokemonData = noPpPokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.ShouldTrigger == "true", "Should trigger for move with 0 PP")

    -- Test Liechi Berry with ability threshold modification
    local lowHpPokemonForStat = createTestPokemon({currentHP = 40, maxHP = 200}) -- 20% HP
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = lowHpPokemonForStat,
            battleContext = createBattleContext()
        })
    })

    assert(result.ShouldTrigger == "true", "Should trigger at 20% HP")

    -- Test with Gluttony ability (modified threshold)
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = createTestPokemon({currentHP = 120, maxHP = 200}), -- 60% HP
            battleContext = createBattleContext({berryThreshold = 0.75}) -- Gluttony effect
        })
    })

    assert(result.ShouldTrigger == "true", "Should trigger with ability threshold modification")

    print("✓ Berry trigger evaluation tests passed")
end

-- Test: Berry Effect Calculations
function testSuite.tests.test_berry_effect_calculations()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Sitrus Berry healing
    local pokemon = createTestPokemon({currentHP = 80, maxHP = 200})
    local result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = pokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.Success == "true", "Should consume Sitrus Berry")
    local data = aolite.json.decode(result.Data)
    assert(data.consumed == true, "Berry should be consumed")
    assert(#data.effects == 1, "Should have one effect")
    assert(data.effects[1].type == "berry_heal", "Should be healing effect")
    assert(data.effects[1].amount == 50, "Should heal 50 HP (25% of 200)")
    assert(data.pokemonChanges.currentHP == 130, "Should update HP to 130")

    -- Test with Double Berry Effect
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = pokemon,
            battleContext = createBattleContext({doubleBerryEffect = true})
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.effects[1].amount == 100, "Should heal 100 HP with double effect")

    -- Test Lum Berry status cure
    local poisonedPokemon = createTestPokemon({status = "POISON", isConfused = true})
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LUM_BERRY",
        Data = aolite.json.encode({
            pokemonData = poisonedPokemon,
            battleContext = createBattleContext()
        })
    })

    data = aolite.json.decode(result.Data)
    assert(#data.effects >= 1, "Should have at least one effect")
    assert(data.pokemonChanges.status == "NONE", "Should cure status")
    assert(data.pokemonChanges.isConfused == false, "Should cure confusion")

    -- Test Liechi Berry stat boost
    local lowHpPokemon = createTestPokemon({currentHP = 40, maxHP = 200})
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = lowHpPokemon,
            battleContext = createBattleContext()
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.effects[1].type == "stat_boost", "Should be stat boost effect")
    assert(data.effects[1].stat == "attack", "Should boost attack")
    assert(data.effects[1].stages == 1, "Should boost by 1 stage")
    assert(data.pokemonChanges.statStages.attack == 1, "Should update stat stage")

    -- Test Starf Berry random stat boost
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "STARF_BERRY",
        Data = aolite.json.encode({
            pokemonData = lowHpPokemon,
            battleContext = createBattleContext()
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.effects[1].type == "random_stat_boost", "Should be random stat boost")
    assert(data.effects[1].stages == 2, "Should boost by 2 stages")

    -- Test Lansat Berry crit boost
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LANSAT_BERRY",
        Data = aolite.json.encode({
            pokemonData = lowHpPokemon,
            battleContext = createBattleContext()
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.effects[1].type == "crit_boost", "Should be crit boost effect")
    assert(data.pokemonChanges.critBoost == true, "Should enable crit boost")

    -- Test Leppa Berry PP restoration
    local pokemon2 = createTestPokemon()
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LEPPA_BERRY",
        Data = aolite.json.encode({
            pokemonData = pokemon2,
            battleContext = createBattleContext()
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.effects[1].type == "pp_restore", "Should be PP restore effect")
    assert(data.effects[1].amount == 10, "Should restore 10 PP")

    print("✓ Berry effect calculation tests passed")
end

-- Test: Berry Ability Interactions
function testSuite.tests.test_berry_ability_interactions()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test berry threshold modification (Gluttony)
    local pokemon = createTestPokemon({currentHP = 120, maxHP = 200}) -- 60% HP
    local result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = pokemon,
            battleContext = createBattleContext({berryThreshold = 0.75}) -- Gluttony effect
        })
    })

    assert(result.ShouldTrigger == "true", "Gluttony should modify threshold")

    -- Test double berry effect (Ripen)
    local lowHpPokemon = createTestPokemon({currentHP = 80, maxHP = 200})
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = lowHpPokemon,
            battleContext = createBattleContext({doubleBerryEffect = true})
        })
    })

    local data = aolite.json.decode(result.Data)
    assert(data.effects[1].percentage == 50, "Should double the healing percentage")

    print("✓ Berry ability interaction tests passed")
end

-- Test: Berry Preservation
function testSuite.tests.test_berry_preservation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test without Berry Pouch
    local result = ao.send({
        Target = testSuite.processId,
        Action = "CheckBerryPreservation",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = createTestPokemon(),
            modifierList = {}
        })
    })

    assert(result.Success == "true", "Should check preservation")
    assert(result.Preserved == "false", "Should not preserve without Berry Pouch")

    -- Test with Berry Pouch (using AMULET_COIN as placeholder)
    result = ao.send({
        Target = testSuite.processId,
        Action = "CheckBerryPreservation",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = createTestPokemon(),
            modifierList = {{id = "AMULET_COIN"}} -- Berry Pouch placeholder
        })
    })

    assert(result.Preserved == "true", "Should preserve with Berry Pouch")

    print("✓ Berry preservation tests passed")
end

-- Test: Complex Berry Scenarios
function testSuite.tests.test_complex_berry_scenarios()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test max stat stage prevention
    local maxedPokemon = createTestPokemon({
        currentHP = 40,
        maxHP = 200,
        statStages = {
            attack = 6, -- Already maxed
            defense = 0,
            special_attack = 0,
            special_defense = 0,
            speed = 0
        }
    })

    local result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = maxedPokemon,
            battleContext = createBattleContext()
        })
    })

    assert(result.ShouldTrigger == "false", "Should not trigger when stat is maxed")

    -- Test multiple move PP scenarios for Leppa
    local multiPpPokemon = createTestPokemon({
        moves = {
            {index = 1, id = 1, name = "Tackle", currentPP = 0, maxPP = 20}, -- Fully depleted
            {index = 2, id = 2, name = "Scratch", currentPP = 5, maxPP = 10}, -- Partially depleted
            {index = 3, id = 3, name = "Quick Attack", currentPP = 25, maxPP = 25}, -- Full
            {index = 4, id = 4, name = "Growl", currentPP = 15, maxPP = 15} -- Full
        }
    })

    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LEPPA_BERRY",
        Data = aolite.json.encode({
            pokemonData = multiPpPokemon,
            battleContext = createBattleContext()
        })
    })

    local data = aolite.json.decode(result.Data)
    assert(data.effects[1].moveName == "Tackle", "Should restore first depleted move")

    -- Test Enigma Berry with super effective hit
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "ENIGMA_BERRY",
        Data = aolite.json.encode({
            pokemonData = createTestPokemon(),
            battleContext = createBattleContext({hitBySuperEffective = true})
        })
    })

    assert(result.ShouldTrigger == "true", "Should trigger after super effective hit")

    print("✓ Complex berry scenario tests passed")
end

-- Test: Berry Error Handling
function testSuite.tests.test_berry_error_handling()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test invalid berry ID
    local result = ao.send({
        Target = testSuite.processId,
        Action = "GetBerryInfo",
        BerryId = "INVALID_BERRY"
    })

    assert(result.Action == "Error", "Should return error for invalid berry")

    -- Test missing berry ID
    result = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        Data = aolite.json.encode({
            pokemonData = createTestPokemon(),
            battleContext = createBattleContext()
        })
    })

    assert(result.Action == "Error", "Should return error for missing berry ID")

    -- Test malformed data
    result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = "invalid json"
    })

    -- Should handle malformed JSON gracefully
    assert(result.Success == "true" or result.Action == "Error", "Should handle malformed JSON")

    print("✓ Berry error handling tests passed")
end

-- Test: Shop Generation
function testSuite.tests.test_shop_generation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test wave 1 shop generation
    local result = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = "1",
        BaseCost = "100"
    })

    assert(result.Success == "true", "Should generate shop successfully")
    local data = aolite.json.decode(result.Data)
    assert(data.shopInventory ~= nil, "Should have shop inventory")
    assert(#data.shopInventory == 3, "Wave 1 should have 3 items (Potion, Ether, Revive)")

    -- Test boss wave (no shop)
    result = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = "10"
    })

    data = aolite.json.decode(result.Data)
    assert(data.bossWave == true, "Should identify boss wave")
    assert(#data.shopInventory == 0, "Boss wave should have no shop")

    -- Test wave 95 shop (more items unlocked)
    result = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = "95",
        BaseCost = "500"
    })

    data = aolite.json.decode(result.Data)
    assert(#data.shopInventory > 3, "Higher waves should have more items")

    print("✓ Shop generation tests passed")
end

-- Test: Reroll Cost Calculation
function testSuite.tests.test_reroll_cost_calculation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test base reroll cost
    local result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateRerollCost",
        WaveIndex = "1",
        RerollCount = "0"
    })

    assert(result.Success == "true", "Should calculate reroll cost")
    local data = aolite.json.decode(result.Data)
    assert(data.rerollCost == 250, "Base reroll cost should be 250")

    -- Test reroll cost with count
    result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateRerollCost",
        WaveIndex = "1",
        RerollCount = "2"
    })

    data = aolite.json.decode(result.Data)
    assert(data.rerollCost == 1000, "Reroll cost should increase with count (250 * 2^2)")

    -- Test with lock rarities
    result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateRerollCost",
        WaveIndex = "1",
        RerollCount = "0",
        LockRarities = "true",
        Data = aolite.json.encode({
            currentTypeOptions = {
                {tier = "COMMON"},
                {tier = "GREAT"},
                {tier = "ULTRA"}
            }
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.rerollCost == 475, "Lock rarities cost should be sum of tier values")

    print("✓ Reroll cost calculation tests passed")
end

-- Test: Purchase Validation
function testSuite.tests.test_purchase_validation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test valid purchase
    local result = ao.send({
        Target = testSuite.processId,
        Action = "ValidatePurchase",
        ItemId = "POTION",
        PlayerMoney = "100",
        Cost = "50"
    })

    assert(result.Success == "true", "Should validate valid purchase")
    local data = aolite.json.decode(result.Data)
    assert(data.valid == true, "Purchase should be valid")

    -- Test insufficient funds
    result = ao.send({
        Target = testSuite.processId,
        Action = "ValidatePurchase",
        ItemId = "POTION",
        PlayerMoney = "30",
        Cost = "50"
    })

    data = aolite.json.decode(result.Data)
    assert(data.valid == false, "Should reject insufficient funds")
    assert(data.reason == "Insufficient funds", "Should specify insufficient funds")

    -- Test invalid item
    result = ao.send({
        Target = testSuite.processId,
        Action = "ValidatePurchase",
        ItemId = "INVALID_ITEM",
        PlayerMoney = "100",
        Cost = "50"
    })

    data = aolite.json.decode(result.Data)
    assert(data.valid == false, "Should reject invalid item")

    print("✓ Purchase validation tests passed")
end

-- Test: Purchase Item
function testSuite.tests.test_purchase_item()
    local ao = aolite.spawn(testSuite.processPath)

    local gameState = {
        player = {
            inventory = {
                money = 500,
                items = {}
            }
        }
    }

    -- Test successful purchase
    local result = ao.send({
        Target = testSuite.processId,
        Action = "PurchaseItem",
        ItemId = "POTION",
        Cost = "50",
        Data = aolite.json.encode({
            gameState = gameState
        })
    })

    assert(result.Success == "true", "Should complete purchase")
    assert(result.NewMoney == "450", "Money should be deducted")

    local data = aolite.json.decode(result.Data)
    assert(data.purchased == true, "Purchase should be successful")
    assert(#data.gameState.player.inventory.items == 1, "Item should be added to inventory")

    -- Test failed purchase (insufficient funds)
    gameState.player.inventory.money = 20
    result = ao.send({
        Target = testSuite.processId,
        Action = "PurchaseItem",
        ItemId = "POTION",
        Cost = "50",
        Data = aolite.json.encode({
            gameState = gameState
        })
    })

    assert(result.Action == "Error", "Should reject insufficient funds purchase")

    print("✓ Purchase item tests passed")
end

-- Test: Reroll Shop
function testSuite.tests.test_reroll_shop()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test successful reroll
    local result = ao.send({
        Target = testSuite.processId,
        Action = "RerollShop",
        WaveIndex = "5",
        RerollCount = "0",
        PlayerMoney = "500"
    })

    assert(result.Success == "true", "Should reroll shop")
    local data = aolite.json.decode(result.Data)
    assert(data.rerolled == true, "Shop should be rerolled")
    assert(data.shopInventory ~= nil, "Should have new inventory")
    assert(data.newMoney == 250, "Money should be deducted (500 - 250)")
    assert(data.rerollCount == 1, "Reroll count should increment")

    -- Test failed reroll (insufficient funds)
    result = ao.send({
        Target = testSuite.processId,
        Action = "RerollShop",
        WaveIndex = "5",
        RerollCount = "0",
        PlayerMoney = "100"
    })

    assert(result.Action == "Error", "Should reject insufficient funds reroll")

    print("✓ Reroll shop tests passed")
end

-- Test: Money Reward Calculation
function testSuite.tests.test_money_reward_calculation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test basic money reward
    local result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateMoneyReward",
        WaveIndex = "10",
        Multiplier = "1"
    })

    assert(result.Success == "true", "Should calculate money reward")
    local data = aolite.json.decode(result.Data)
    assert(data.moneyReward > 0, "Should have positive reward")

    -- Test with multiplier
    result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateMoneyReward",
        WaveIndex = "10",
        Multiplier = "2.5"
    })

    data = aolite.json.decode(result.Data)
    local doubleReward = data.moneyReward

    -- Test with money multiplier modifiers (Amulet Coin)
    result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateMoneyReward",
        WaveIndex = "10",
        Multiplier = "1",
        MoneyMultiplierModifiers = "2"
    })

    data = aolite.json.decode(result.Data)
    assert(data.moneyReward > 0, "Should apply money multipliers")

    print("✓ Money reward calculation tests passed")
end

-- Test: Format Money
function testSuite.tests.test_format_money()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test full format
    local result = ao.send({
        Target = testSuite.processId,
        Action = "FormatMoney",
        Amount = "1234",
        Format = "full"
    })

    assert(result.FormattedMoney == "1234", "Full format should show exact amount")

    -- Test abbreviated format (thousands)
    result = ao.send({
        Target = testSuite.processId,
        Action = "FormatMoney",
        Amount = "1500",
        Format = "abbreviated"
    })

    assert(result.FormattedMoney == "1.5K", "Should abbreviate thousands")

    -- Test abbreviated format (millions)
    result = ao.send({
        Target = testSuite.processId,
        Action = "FormatMoney",
        Amount = "2500000",
        Format = "abbreviated"
    })

    assert(result.FormattedMoney == "2.5M", "Should abbreviate millions")

    print("✓ Format money tests passed")
end

-- Test: Economic Progression
function testSuite.tests.test_economic_progression()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test wave 1 progression
    local result = ao.send({
        Target = testSuite.processId,
        Action = "CheckEconomicProgression",
        WaveIndex = "1",
        Data = aolite.json.encode({
            playerStats = {
                totalMoneyEarned = 0,
                totalMoneySpent = 0,
                itemsPurchased = 0,
                rerollsUsed = 0
            }
        })
    })

    assert(result.Success == "true", "Should check progression")
    local data = aolite.json.decode(result.Data)
    assert(data.milestones.firstShop == true, "Should have first shop unlocked")
    assert(data.milestones.superPotionsUnlocked == false, "Should not have super potions yet")

    -- Test wave 95 progression
    result = ao.send({
        Target = testSuite.processId,
        Action = "CheckEconomicProgression",
        WaveIndex = "95",
        Data = aolite.json.encode({
            playerStats = {
                totalMoneyEarned = 15000,
                totalMoneySpent = 11000,
                itemsPurchased = 55,
                rerollsUsed = 25
            }
        })
    })

    data = aolite.json.decode(result.Data)
    assert(data.milestones.hyperPotionsUnlocked == true, "Should have hyper potions unlocked")
    assert(data.achievements.bigSpender == true, "Should have big spender achievement")
    assert(data.achievements.shopaholic == true, "Should have shopaholic achievement")

    print("✓ Economic progression tests passed")
end

-- Test: Process Economic Event
function testSuite.tests.test_process_economic_event()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test battle victory reward
    local result = ao.send({
        Target = testSuite.processId,
        Action = "ProcessEconomicEvent",
        EventType = "battle_victory",
        WaveIndex = "10"
    })

    assert(result.Success == "true", "Should process event")
    local data = aolite.json.decode(result.Data)
    assert(data.moneyReward > 0, "Should have money reward")
    assert(data.eventDescription == "Battle victory reward", "Should have correct description")

    -- Test trainer defeat (higher multiplier)
    result = ao.send({
        Target = testSuite.processId,
        Action = "ProcessEconomicEvent",
        EventType = "trainer_defeat",
        WaveIndex = "10"
    })

    data = aolite.json.decode(result.Data)
    local trainerReward = data.moneyReward

    -- Test boss defeat (even higher multiplier)
    result = ao.send({
        Target = testSuite.processId,
        Action = "ProcessEconomicEvent",
        EventType = "boss_defeat",
        WaveIndex = "10"
    })

    data = aolite.json.decode(result.Data)
    assert(data.moneyReward > trainerReward, "Boss should give more than trainer")

    print("✓ Process economic event tests passed")
end

-- Test: Item Rarity Calculation
function testSuite.tests.test_item_rarity_calculation()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test base rarity
    local result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateItemRarity",
        ItemId = "POTION",
        WaveIndex = "1"
    })

    assert(result.Success == "true", "Should calculate rarity")
    assert(result.Tier == "COMMON", "Potion should be common tier")

    -- Test with luck modifiers
    result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateItemRarity",
        ItemId = "GREAT_BALL",
        WaveIndex = "50",
        LuckModifiers = "10",
        RngSeed = "12345"
    })

    local data = aolite.json.decode(result.Data)
    assert(data.tier ~= nil, "Should have tier with luck calculation")

    print("✓ Item rarity calculation tests passed")
end

-- Test: Tier Probabilities
function testSuite.tests.test_tier_probabilities()
    local ao = aolite.spawn(testSuite.processPath)

    local result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateTierProbabilities",
        RerollCount = "0"
    })

    assert(result.Success == "true", "Should calculate probabilities")
    local data = aolite.json.decode(result.Data)
    assert(#data.probabilities == 5, "Should have 5 tiers")
    assert(data.probabilities[1].tier == "COMMON", "First tier should be common")
    assert(data.probabilities[1].probability > 0.7, "Common should be most likely")

    print("✓ Tier probabilities tests passed")
end

-- Test: Roll Modifier Tier
function testSuite.tests.test_roll_modifier_tier()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test with fixed seed for deterministic result
    local result = ao.send({
        Target = testSuite.processId,
        Action = "RollModifierTier",
        RngSeed = "100",
        WaveIndex = "1",
        RerollCount = "0"
    })

    assert(result.Success == "true", "Should roll tier")
    local data = aolite.json.decode(result.Data)
    assert(data.tierName ~= nil, "Should have tier name")
    assert(data.tierIndex >= 1 and data.tierIndex <= 5, "Should have valid tier index")

    print("✓ Roll modifier tier tests passed")
end

-- Run all tests
function testSuite.runTests()
    print("Starting Modifier System Engine Unit Tests...")
    print("=" .. string.rep("=", 50))

    local passCount = 0
    local totalTests = 0

    for testName, testFunc in pairs(testSuite.tests) do
        totalTests = totalTests + 1
        print("\nRunning " .. testName .. "...")

        local success, error = pcall(testFunc)
        if success then
            passCount = passCount + 1
        else
            print("✗ " .. testName .. " FAILED: " .. tostring(error))
        end
    end

    print("\n" .. string.rep("=", 50))
    print("Test Results: " .. passCount .. "/" .. totalTests .. " passed")

    if passCount == totalTests then
        print("🎉 All modifier system engine tests passed!")
        return true
    else
        print("❌ Some tests failed")
        return false
    end
end

-- Export test suite
return testSuite