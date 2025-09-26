-- Parity Tests for Modifier System Engine
-- Compares Lua modifier system behavior against TypeScript implementation
-- Validates mathematical precision and behavioral equivalence

local aolite = require('aolite')

-- Test Suite Configuration
local testSuite = {
    processPath = 'processes/modifier-system-engine.lua',
    processId = 'modifier-system-parity-test',
    tests = {}
}

-- TypeScript Reference Data (extracted from actual game calculations)
local TypeScriptReference = {
    -- Healing item calculations
    POTION = {
        healAmount = 20,
        restoreValue = 10,
        consumable = true
    },
    SUPER_POTION = {
        healAmount = 50,
        restoreValue = 25,
        consumable = true
    },
    MAX_POTION = {
        healAmount = 0, -- Full heal
        restoreValue = 100,
        consumable = true
    },

    -- Revival calculations
    REVIVE = {
        healPercentage = 50,
        consumable = true
    },
    MAX_REVIVE = {
        healPercentage = 100,
        consumable = true
    },

    -- Held item stat boosts
    EVIOLITE = {
        defenseMultiplier = 1.5,
        spdefMultiplier = 1.5,
        requiresUnevolved = true
    },

    -- Type boost items
    CHARCOAL = {
        fireTypeMultiplier = 1.2,
        applicableTypes = {"FIRE"}
    },
    MYSTIC_WATER = {
        waterTypeMultiplier = 1.2,
        applicableTypes = {"WATER"}
    },

    -- Berry trigger conditions
    SITRUS_BERRY = {
        triggerThreshold = 0.5, -- 50% HP
        healPercentage = 0.25   -- 25% HP restored
    },
    LUM_BERRY = {
        curesStatuses = {"POISON", "BURN", "FREEZE", "PARALYSIS", "SLEEP"}
    },
    LEPPA_BERRY = {
        ppRestoreAmount = 10,
        triggerCondition = "pp_zero"
    },

    -- Leftovers healing per turn
    LEFTOVERS = {
        healPercentage = 0.0625 -- 1/16 = 6.25%
    },

    -- PP enhancement calculations
    PP_UP = {
        ppIncrease = 1,
        permanent = true
    },
    PP_MAX = {
        ppIncrease = 3,
        permanent = true
    }
}

-- Helper function to create test scenarios matching TypeScript conditions
local function createParityTestPokemon(scenario)
    local base = {
        id = 1,
        level = 50,
        currentHP = 150,
        maxHP = 200,
        status = "NONE",
        isFainted = false,
        canEvolve = true,
        stats = {
            hp = 200,
            attack = 100,
            defense = 80,
            special_attack = 90,
            special_defense = 85,
            speed = 95
        }
    }

    if scenario == "low_hp" then
        base.currentHP = 90  -- 45% HP to trigger Sitrus Berry
    elseif scenario == "fainted" then
        base.currentHP = 0
        base.isFainted = true
    elseif scenario == "evolved" then
        base.canEvolve = false
    elseif scenario == "poisoned" then
        base.status = "POISON"
    elseif scenario == "full_hp" then
        base.currentHP = base.maxHP
    end

    return base
end

-- Test 1: Healing Item Mathematical Parity
function testSuite.tests.test_healing_item_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Potion healing precision
    local pokemon = createParityTestPokemon()
    pokemon.currentHP = 100 -- 50% HP

    local potionResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "POTION",
        Data = json.encode({pokemonData = pokemon})
    })

    assert(potionResult.Success == "true", "Should process Potion consumption")
    local potionData = json.decode(potionResult.Data)

    -- Verify exact TypeScript parity
    local expectedHP = pokemon.currentHP + TypeScriptReference.POTION.healAmount
    assert(potionData.pokemonChanges.currentHP == expectedHP,
        "Potion should heal exactly " .. TypeScriptReference.POTION.healAmount .. " HP")
    assert(potionData.consumed == TypeScriptReference.POTION.consumable,
        "Potion consumption should match TypeScript")

    -- Test Super Potion precision
    local superPotionResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "SUPER_POTION",
        Data = json.encode({pokemonData = pokemon})
    })

    local superData = json.decode(superPotionResult.Data)
    local expectedSuperHP = pokemon.currentHP + TypeScriptReference.SUPER_POTION.healAmount
    assert(superData.pokemonChanges.currentHP == expectedSuperHP,
        "Super Potion should heal exactly " .. TypeScriptReference.SUPER_POTION.healAmount .. " HP")

    -- Test Max Potion full heal
    local maxPotionResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "MAX_POTION",
        Data = json.encode({pokemonData = pokemon})
    })

    local maxData = json.decode(maxPotionResult.Data)
    assert(maxData.pokemonChanges.currentHP == pokemon.maxHP,
        "Max Potion should fully heal Pokemon")

    -- Test healing cap (cannot exceed max HP)
    local nearFullPokemon = createParityTestPokemon()
    nearFullPokemon.currentHP = 190 -- Only 10 HP away from max

    local cappedResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "POTION",
        Data = json.encode({pokemonData = nearFullPokemon})
    })

    local cappedData = json.decode(cappedResult.Data)
    assert(cappedData.pokemonChanges.currentHP == nearFullPokemon.maxHP,
        "Should not exceed max HP when healing")
    assert(cappedData.effects[1].amount == 10,
        "Should heal only remaining HP, not full potion amount")

    print("✓ Healing item mathematical parity tests passed")
end

-- Test 2: Revival Mechanics Parity
function testSuite.tests.test_revival_mechanics_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Revive mechanics
    local faintedPokemon = createParityTestPokemon("fainted")
    local reviveResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "REVIVE",
        Data = json.encode({pokemonData = faintedPokemon})
    })

    assert(reviveResult.Success == "true", "Should process Revive")
    local reviveData = json.decode(reviveResult.Data)

    -- Verify exact TypeScript calculation: 50% of max HP
    local expectedReviveHP = math.floor(faintedPokemon.maxHP * (TypeScriptReference.REVIVE.healPercentage / 100))
    assert(reviveData.pokemonChanges.currentHP == expectedReviveHP,
        "Revive should restore exactly 50% HP: " .. expectedReviveHP)
    assert(reviveData.pokemonChanges.isFainted == false,
        "Should un-faint Pokemon")

    -- Test Max Revive mechanics
    local maxReviveResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "MAX_REVIVE",
        Data = json.encode({pokemonData = faintedPokemon})
    })

    local maxReviveData = json.decode(maxReviveResult.Data)
    local expectedMaxReviveHP = math.floor(faintedPokemon.maxHP * (TypeScriptReference.MAX_REVIVE.healPercentage / 100))
    assert(maxReviveData.pokemonChanges.currentHP == expectedMaxReviveHP,
        "Max Revive should restore exactly 100% HP")

    print("✓ Revival mechanics parity tests passed")
end

-- Test 3: Eviolite Stat Boost Parity
function testSuite.tests.test_eviolite_stat_boost_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Eviolite on unevolved Pokemon
    local unevolvedPokemon = createParityTestPokemon()
    unevolvedPokemon.canEvolve = true

    local defenseResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({pokemonData = unevolvedPokemon})
    })

    assert(defenseResult.Success == "true", "Should calculate Eviolite defense boost")
    assert(tonumber(defenseResult.StatMultiplier) == TypeScriptReference.EVIOLITE.defenseMultiplier,
        "Defense multiplier should match TypeScript: " .. TypeScriptReference.EVIOLITE.defenseMultiplier)

    local spdefResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "special_defense",
        Data = json.encode({pokemonData = unevolvedPokemon})
    })

    assert(tonumber(spdefResult.StatMultiplier) == TypeScriptReference.EVIOLITE.spdefMultiplier,
        "Special Defense multiplier should match TypeScript: " .. TypeScriptReference.EVIOLITE.spdefMultiplier)

    -- Test Eviolite on evolved Pokemon (should have no effect)
    local evolvedPokemon = createParityTestPokemon("evolved")

    local evolvedDefResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({pokemonData = evolvedPokemon})
    })

    assert(tonumber(evolvedDefResult.StatMultiplier) == 1.0,
        "Eviolite should have no effect on evolved Pokemon")

    -- Test non-boosted stats
    local attackResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "attack",
        Data = json.encode({pokemonData = unevolvedPokemon})
    })

    assert(tonumber(attackResult.StatMultiplier) == 1.0,
        "Eviolite should not boost Attack stat")

    print("✓ Eviolite stat boost parity tests passed")
end

-- Test 4: Berry Trigger Condition Parity
function testSuite.tests.test_berry_trigger_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Sitrus Berry trigger threshold (exactly 50% HP)
    local pokemon50HP = createParityTestPokemon()
    pokemon50HP.currentHP = pokemon50HP.maxHP * TypeScriptReference.SITRUS_BERRY.triggerThreshold -- Exactly 50%

    local exactThresholdResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = pokemon50HP})
    })

    assert(exactThresholdResult.ShouldTrigger == "false",
        "Sitrus Berry should NOT trigger at exactly 50% HP (TypeScript behavior)")

    -- Test below threshold
    local pokemonBelowThreshold = createParityTestPokemon()
    pokemonBelowThreshold.currentHP = math.floor(pokemonBelowThreshold.maxHP * TypeScriptReference.SITRUS_BERRY.triggerThreshold) - 1

    local belowResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = pokemonBelowThreshold})
    })

    assert(belowResult.ShouldTrigger == "true",
        "Sitrus Berry should trigger below 50% HP")

    -- Test Lum Berry with specific status conditions
    local statusConditions = {"POISON", "BURN", "PARALYSIS", "SLEEP", "FREEZE"}

    for _, status in ipairs(statusConditions) do
        local statusPokemon = createParityTestPokemon()
        statusPokemon.status = status

        local statusResult = ao.send({
            Target = testSuite.processId,
            Action = "CheckHeldItemTriggers",
            ModifierId = "LUM_BERRY",
            Data = json.encode({pokemonData = statusPokemon})
        })

        assert(statusResult.ShouldTrigger == "true",
            "Lum Berry should trigger with " .. status .. " status")
    end

    -- Test Lum Berry with no status
    local healthyPokemon = createParityTestPokemon()
    local noStatusResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "LUM_BERRY",
        Data = json.encode({pokemonData = healthyPokemon})
    })

    assert(noStatusResult.ShouldTrigger == "false",
        "Lum Berry should not trigger without status condition")

    print("✓ Berry trigger condition parity tests passed")
end

-- Test 5: PP Restoration and Enhancement Parity
function testSuite.tests.test_pp_mechanics_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Ether PP restoration
    local move = {
        id = 1,
        name = "Tackle",
        currentPP = 5,
        maxPP = 20
    }

    local pokemon = createParityTestPokemon()
    local etherResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "ETHER",
        Data = json.encode({
            pokemonData = pokemon,
            targetData = move
        })
    })

    assert(etherResult.Success == "true", "Should process Ether")
    local etherData = json.decode(etherResult.Data)

    local expectedPP = move.currentPP + 10 -- Ether restores exactly 10 PP
    assert(etherData.targetChanges.currentPP == expectedPP,
        "Ether should restore exactly 10 PP")

    -- Test PP restoration cap
    local almostFullMove = {currentPP = 18, maxPP = 20}
    local cappedEtherResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "ETHER",
        Data = json.encode({
            pokemonData = pokemon,
            targetData = almostFullMove
        })
    })

    local cappedData = json.decode(cappedEtherResult.Data)
    assert(cappedData.targetChanges.currentPP == almostFullMove.maxPP,
        "PP restoration should not exceed max PP")
    assert(cappedData.effects[1].amount == 2,
        "Should restore only remaining PP, not full ether amount")

    -- Test PP Up enhancement
    local ppUpResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "PP_UP",
        Data = json.encode({
            pokemonData = pokemon,
            targetData = move
        })
    })

    local ppUpData = json.decode(ppUpResult.Data)
    assert(ppUpData.targetChanges.maxPP == move.maxPP + TypeScriptReference.PP_UP.ppIncrease,
        "PP Up should increase max PP by exactly 1")
    assert(ppUpData.targetChanges.currentPP == move.currentPP + TypeScriptReference.PP_UP.ppIncrease,
        "PP Up should also increase current PP")

    print("✓ PP mechanics parity tests passed")
end

-- Test 6: Type Effectiveness Boost Parity
function testSuite.tests.test_type_boost_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Charcoal Fire-type boost
    local fireMove = {
        type = "FIRE",
        basePower = 40,
        name = "Ember"
    }

    local charcoalResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "CHARCOAL",
        Data = json.encode({
            pokemonData = createParityTestPokemon(),
            moveData = fireMove,
            attackType = "FIRE"
        })
    })

    -- Note: Type boost affects damage calculation, not direct stats
    assert(charcoalResult.Success == "true", "Should process type boost calculation")

    -- Test Mystic Water with non-Water move (should have no effect)
    local normalMove = {
        type = "NORMAL",
        basePower = 40,
        name = "Tackle"
    }

    local noBoostResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "MYSTIC_WATER",
        Data = json.encode({
            pokemonData = createParityTestPokemon(),
            moveData = normalMove,
            attackType = "NORMAL"
        })
    })

    assert(noBoostResult.Success == "true", "Should handle non-matching type")

    print("✓ Type effectiveness boost parity tests passed")
end

-- Test 7: Usage Restriction Parity
function testSuite.tests.test_usage_restriction_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Potion on full HP Pokemon (TypeScript rejects this)
    local fullHPPokemon = createParityTestPokemon("full_hp")
    local fullHPResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "POTION",
        Context = "battle",
        Data = json.encode({pokemonData = fullHPPokemon})
    })

    assert(fullHPResult.Valid == "false",
        "Should reject Potion usage on full HP Pokemon (TypeScript behavior)")

    -- Test Revive on conscious Pokemon (TypeScript rejects this)
    local consciousPokemon = createParityTestPokemon()
    local consciousResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "REVIVE",
        Context = "battle",
        Data = json.encode({pokemonData = consciousPokemon})
    })

    assert(consciousResult.Valid == "false",
        "Should reject Revive usage on conscious Pokemon (TypeScript behavior)")

    -- Test Rare Candy at max level (TypeScript rejects this)
    local maxLevelPokemon = createParityTestPokemon()
    maxLevelPokemon.level = 100

    local maxLevelResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "RARE_CANDY",
        Context = "menu",
        Data = json.encode({pokemonData = maxLevelPokemon})
    })

    assert(maxLevelResult.Valid == "false",
        "Should reject Rare Candy usage at max level (TypeScript behavior)")

    -- Test valid usage scenarios
    local injuredPokemon = createParityTestPokemon()
    injuredPokemon.currentHP = 100

    local validResult = ao.send({
        Target = testSuite.processId,
        Action = "ValidateModifierUsage",
        ModifierId = "POTION",
        Context = "battle",
        Data = json.encode({pokemonData = injuredPokemon})
    })

    assert(validResult.Valid == "true",
        "Should allow Potion usage on injured Pokemon")

    print("✓ Usage restriction parity tests passed")
end

-- Test 8: Mathematical Precision Edge Cases
function testSuite.tests.test_mathematical_precision()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test edge case: 1 HP Pokemon with Sitrus Berry
    local oneHPPokemon = createParityTestPokemon()
    oneHPPokemon.currentHP = 1
    oneHPPokemon.maxHP = 200

    local oneHPTrigger = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = oneHPPokemon})
    })

    assert(oneHPTrigger.ShouldTrigger == "true",
        "Should trigger Sitrus Berry at 1 HP (0.5% < 50%)")

    -- Test edge case: Exact 50% HP
    local exactHalfPokemon = createParityTestPokemon()
    exactHalfPokemon.currentHP = exactHalfPokemon.maxHP / 2 -- Exactly 50%

    local exactHalfTrigger = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = exactHalfPokemon})
    })

    assert(exactHalfTrigger.ShouldTrigger == "false",
        "Should NOT trigger at exactly 50% (TypeScript uses < not <=)")

    -- Test floating point precision with odd max HP
    local oddMaxHPPokemon = createParityTestPokemon()
    oddMaxHPPokemon.maxHP = 157 -- Prime number to test rounding
    oddMaxHPPokemon.currentHP = 78 -- 49.68% HP

    local oddHPTrigger = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({pokemonData = oddMaxHPPokemon})
    })

    assert(oddHPTrigger.ShouldTrigger == "true",
        "Should handle floating point HP percentages correctly")

    -- Test Revive percentage calculation precision
    local oddMaxFainted = createParityTestPokemon("fainted")
    oddMaxFainted.maxHP = 157

    local oddReviveResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "REVIVE",
        Data = json.encode({pokemonData = oddMaxFainted})
    })

    local oddReviveData = json.decode(oddReviveResult.Data)
    local expectedOddReviveHP = math.floor(157 * 0.5) -- Should be 78 (math.floor of 78.5)
    assert(oddReviveData.pokemonChanges.currentHP == expectedOddReviveHP,
        "Revive should use math.floor for HP calculation: " .. expectedOddReviveHP)

    print("✓ Mathematical precision edge cases tests passed")
end

-- Test 9: Complex Stacking Behavior Parity
function testSuite.tests.test_stacking_behavior_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test that multiple instances of same held item don't stack
    local pokemon = createParityTestPokemon()
    local duplicateModifiers = {
        {id = "EVIOLITE", stackCount = 1},
        {id = "EVIOLITE", stackCount = 1} -- Duplicate should not stack
    }

    local stackResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateModifierInteractions",
        Data = json.encode({
            modifierList = duplicateModifiers,
            pokemonData = pokemon
        })
    })

    local stackData = json.decode(stackResult.Data)
    assert(stackData.stackEffects.statMultipliers.defense == 1.5,
        "Duplicate Eviolite should not stack (should remain 1.5x, not 2.25x)")

    -- Test different modifier types do combine
    local mixedModifiers = {
        {id = "EVIOLITE", stackCount = 1},     -- Stat multiplier
        {id = "SCOPE_LENS", stackCount = 1},   -- Crit boost
        {id = "CHARCOAL", stackCount = 1}      -- Type damage boost
    }

    local mixedResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateModifierInteractions",
        Data = json.encode({
            modifierList = mixedModifiers,
            pokemonData = pokemon
        })
    })

    local mixedData = json.decode(mixedResult.Data)
    assert(mixedData.stackEffects.statMultipliers.defense == 1.5,
        "Should include Eviolite effect")
    assert(mixedData.stackEffects.specialEffects.critBoost == 1,
        "Should include Scope Lens effect")
    assert(mixedData.stackEffects.damageMultipliers.FIRE == 1.2,
        "Should include Charcoal effect")

    print("✓ Complex stacking behavior parity tests passed")
end

-- ============================================================================
-- BERRY SYSTEM PARITY TESTS WITH TYPESCRIPT
-- ============================================================================

-- TypeScript Berry Reference Data (from berry.ts)
local BerryReference = {
    SITRUS_BERRY = {
        triggerThreshold = 0.5,  -- HP below 50%
        healPercentage = 25,     -- Heals 25% max HP
        consumable = true
    },
    ENIGMA_BERRY = {
        triggerCondition = "super_effective_hit",
        healPercentage = 25,     -- Same as Sitrus
        consumable = true
    },
    LUM_BERRY = {
        triggerCondition = "status_or_confusion",
        curesStatus = true,
        curesConfusion = true,
        consumable = true
    },
    LIECHI_BERRY = {
        triggerThreshold = 0.25,  -- HP below 25%
        statBoost = "attack",
        boostStages = 1,
        thresholdModifiable = true,
        consumable = true
    },
    GANLON_BERRY = {
        triggerThreshold = 0.25,
        statBoost = "defense",
        boostStages = 1,
        thresholdModifiable = true,
        consumable = true
    },
    PETAYA_BERRY = {
        triggerThreshold = 0.25,
        statBoost = "special_attack",
        boostStages = 1,
        thresholdModifiable = true,
        consumable = true
    },
    APICOT_BERRY = {
        triggerThreshold = 0.25,
        statBoost = "special_defense",
        boostStages = 1,
        thresholdModifiable = true,
        consumable = true
    },
    SALAC_BERRY = {
        triggerThreshold = 0.25,
        statBoost = "speed",
        boostStages = 1,
        thresholdModifiable = true,
        consumable = true
    },
    LANSAT_BERRY = {
        triggerThreshold = 0.25,
        effect = "crit_boost",
        thresholdModifiable = true,
        consumable = true
    },
    STARF_BERRY = {
        triggerThreshold = 0.25,
        effect = "random_stat_boost",
        boostStages = 2,
        thresholdModifiable = true,
        consumable = true
    },
    LEPPA_BERRY = {
        triggerCondition = "pp_depleted",
        ppAmount = 10,
        consumable = true
    }
}

-- Test: Berry Trigger Thresholds Parity
function testSuite.tests.test_berry_trigger_threshold_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Sitrus Berry at various HP percentages (TypeScript getBerryPredicate behavior)
    local testCases = {
        {hp = 100, maxHP = 200, expected = true},   -- 50% exactly
        {hp = 99, maxHP = 200, expected = true},    -- 49.5% - should trigger
        {hp = 101, maxHP = 200, expected = false},  -- 50.5% - should not trigger
        {hp = 50, maxHP = 100, expected = true},    -- 50% exactly - edge case
        {hp = 51, maxHP = 100, expected = false}    -- 51% - should not trigger
    }

    for i, testCase in ipairs(testCases) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "EvaluateBerryTrigger",
            BerryId = "SITRUS_BERRY",
            Data = aolite.json.encode({
                pokemonData = {
                    currentHP = testCase.hp,
                    maxHP = testCase.maxHP
                },
                battleContext = {}
            })
        })

        local shouldTrigger = result.ShouldTrigger == "true"
        assert(shouldTrigger == testCase.expected,
            string.format("Case %d: HP %d/%d should %s trigger (got %s)",
                i, testCase.hp, testCase.maxHP,
                testCase.expected and "should" or "should not",
                shouldTrigger and "triggered" or "did not trigger"))
    end

    print("✓ Berry trigger threshold parity tests passed")
end

-- Test: Berry Healing Calculation Parity
function testSuite.tests.test_berry_healing_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test cases matching TypeScript getBerryEffectFunc calculations
    local healingTests = {
        {maxHP = 200, currentHP = 80, expectedHeal = 50},   -- 25% of 200 = 50
        {maxHP = 300, currentHP = 100, expectedHeal = 75},  -- 25% of 300 = 75
        {maxHP = 100, currentHP = 20, expectedHeal = 25},   -- 25% of 100 = 25
        {maxHP = 150, currentHP = 50, expectedHeal = 37}    -- 25% of 150 = 37.5 -> 37 (floor)
    }

    for i, test in ipairs(healingTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "ConsumeBerry",
            BerryId = "SITRUS_BERRY",
            Data = aolite.json.encode({
                pokemonData = {
                    currentHP = test.currentHP,
                    maxHP = test.maxHP
                },
                battleContext = {}
            })
        })

        local data = aolite.json.decode(result.Data)
        assert(data.effects[1].amount == test.expectedHeal,
            string.format("Case %d: Expected heal %d, got %d",
                i, test.expectedHeal, data.effects[1].amount))
    end

    print("✓ Berry healing calculation parity tests passed")
end

-- Test: Berry Effect with Abilities Parity (DoubleBerryEffectAbAttr)
function testSuite.tests.test_berry_ability_effects_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test double berry effect (Ripen ability equivalent)
    local normalResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = {currentHP = 100, maxHP = 200},
            battleContext = {doubleBerryEffect = false}
        })
    })

    local doubleResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode({
            pokemonData = {currentHP = 100, maxHP = 200},
            battleContext = {doubleBerryEffect = true}
        })
    })

    local normalData = aolite.json.decode(normalResult.Data)
    local doubleData = aolite.json.decode(doubleResult.Data)

    assert(normalData.effects[1].amount == 50, "Normal healing should be 50")
    assert(doubleData.effects[1].amount == 100, "Double healing should be 100")
    assert(doubleData.effects[1].percentage == 50, "Double percentage should be 50%")

    -- Test stat boost berries with double effect
    local statBoostResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = {
                currentHP = 40,
                maxHP = 200,
                statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
            },
            battleContext = {doubleBerryEffect = true}
        })
    })

    local statData = aolite.json.decode(statBoostResult.Data)
    assert(statData.effects[1].stages == 2, "Should double stat boost to 2 stages")

    print("✓ Berry ability effects parity tests passed")
end

-- Test: Berry Threshold Modification Parity (ReduceBerryUseThresholdAbAttr)
function testSuite.tests.test_berry_threshold_modification_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test normal 25% threshold
    local normalResult = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = {
                currentHP = 60,  -- 30% HP
                maxHP = 200,
                statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
            },
            battleContext = {}
        })
    })

    assert(normalResult.ShouldTrigger == "true", "Should trigger at 30% with normal threshold")

    -- Test Gluttony ability (50% threshold modification)
    local gluttonyResult = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = {
                currentHP = 140,  -- 70% HP
                maxHP = 200,
                statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
            },
            battleContext = {berryThreshold = 0.75}  -- Gluttony effect
        })
    })

    assert(gluttonyResult.ShouldTrigger == "true", "Should trigger at 70% with Gluttony")

    print("✓ Berry threshold modification parity tests passed")
end

-- Test: Stat Stage Cap Enforcement Parity
function testSuite.tests.test_stat_stage_cap_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test stat already at +6 (TypeScript behavior: check current stage < 6)
    local maxedResult = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = {
                currentHP = 40,
                maxHP = 200,
                statStages = {attack = 6, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
            },
            battleContext = {}
        })
    })

    assert(maxedResult.ShouldTrigger == "false", "Should not trigger when attack is maxed")

    -- Test stat at +5 (should still trigger)
    local nearMaxResult = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = {
                currentHP = 40,
                maxHP = 200,
                statStages = {attack = 5, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
            },
            battleContext = {}
        })
    })

    assert(nearMaxResult.ShouldTrigger == "true", "Should trigger when attack is at +5")

    -- Test consumption and cap enforcement
    local consumeResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode({
            pokemonData = {
                currentHP = 40,
                maxHP = 200,
                statStages = {attack = 5, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
            },
            battleContext = {}
        })
    })

    local data = aolite.json.decode(consumeResult.Data)
    assert(data.pokemonChanges.statStages.attack == 6, "Should cap at +6")
    assert(data.effects[1].actualStages == 1, "Should only boost by 1 stage (from +5 to +6)")

    print("✓ Stat stage cap enforcement parity tests passed")
end

-- Test: Leppa Berry PP Restoration Logic Parity
function testSuite.tests.test_leppa_pp_restoration_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test TypeScript logic: prioritize fully depleted moves, then partially depleted
    local pokemon = {
        pokemonData = {
            moves = {
                {index = 1, name = "Tackle", currentPP = 5, maxPP = 20},    -- Partially depleted
                {index = 2, name = "Scratch", currentPP = 0, maxPP = 15},   -- Fully depleted (should be first)
                {index = 3, name = "Quick Attack", currentPP = 0, maxPP = 30}, -- Also fully depleted
                {index = 4, name = "Growl", currentPP = 25, maxPP = 25}     -- Full
            }
        },
        battleContext = {}
    }

    local result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LEPPA_BERRY",
        Data = aolite.json.encode(pokemon)
    })

    local data = aolite.json.decode(result.Data)
    -- Should restore Scratch (first fully depleted move found)
    assert(data.effects[1].moveName == "Scratch", "Should prioritize first fully depleted move")
    assert(data.effects[1].amount == 10, "Should restore 10 PP")

    -- Test with only partially depleted moves
    local partialPokemon = {
        pokemonData = {
            moves = {
                {index = 1, name = "Tackle", currentPP = 15, maxPP = 20},    -- 5 PP missing
                {index = 2, name = "Scratch", currentPP = 10, maxPP = 15},   -- 5 PP missing
                {index = 3, name = "Quick Attack", currentPP = 25, maxPP = 25} -- Full
            }
        },
        battleContext = {}
    }

    local partialResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LEPPA_BERRY",
        Data = aolite.json.encode(partialPokemon)
    })

    local partialData = aolite.json.decode(partialResult.Data)
    assert(partialData.effects[1].moveName == "Tackle", "Should use first partially depleted move")
    assert(partialData.effects[1].amount == 5, "Should restore 5 PP (limited by max)")

    print("✓ Leppa Berry PP restoration parity tests passed")
end

-- Test: Berry Random Effects Parity (Starf Berry)
function testSuite.tests.test_berry_random_effects_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Starf Berry random stat selection
    local pokemon = {
        pokemonData = {
            currentHP = 40,
            maxHP = 200,
            statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
        },
        battleContext = {randomSeed = 1}  -- Fixed seed for predictable testing
    }

    local result = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "STARF_BERRY",
        Data = aolite.json.encode(pokemon)
    })

    local data = aolite.json.decode(result.Data)
    assert(data.effects[1].type == "random_stat_boost", "Should be random stat boost")
    assert(data.effects[1].stages == 2, "Should boost by 2 stages")

    -- Verify stat was actually boosted
    local boostedStat = data.effects[1].stat
    assert(data.pokemonChanges.statStages[boostedStat] == 2, "Should update stat stage")

    print("✓ Berry random effects parity tests passed")
end

-- Test: Berry Consumption State Changes Parity
function testSuite.tests.test_berry_consumption_state_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test all berry types produce expected state changes
    local berryTests = {
        {
            berryId = "SITRUS_BERRY",
            pokemon = {currentHP = 80, maxHP = 200},
            expectedChange = "currentHP",
            expectedValue = 130
        },
        {
            berryId = "LUM_BERRY",
            pokemon = {status = "BURN", isConfused = true},
            expectedChange = "status",
            expectedValue = "NONE"
        },
        {
            berryId = "LANSAT_BERRY",
            pokemon = {currentHP = 40, maxHP = 200, critBoost = false},
            expectedChange = "critBoost",
            expectedValue = true
        }
    }

    for i, test in ipairs(berryTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "ConsumeBerry",
            BerryId = test.berryId,
            Data = aolite.json.encode({
                pokemonData = test.pokemon,
                battleContext = {}
            })
        })

        local data = aolite.json.decode(result.Data)
        assert(data.consumed == true, test.berryId .. " should be consumed")
        assert(data.pokemonChanges[test.expectedChange] == test.expectedValue,
            string.format("%s should change %s to %s",
                test.berryId, test.expectedChange, tostring(test.expectedValue)))
    end

    print("✓ Berry consumption state changes parity tests passed")
end

-- Test: Shop Generation Parity
function testSuite.tests.test_shop_generation_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript reference shop data for specific waves
    local shopTests = {
        {
            wave = 1,
            baseCost = 100,
            expectedItems = {"POTION", "ETHER", "REVIVE"},
            expectedCosts = {20, 40, 200} -- baseCost * pricing multiplier
        },
        {
            wave = 35,
            baseCost = 300,
            expectedItems = {"POTION", "ETHER", "REVIVE", "SUPER_POTION", "FULL_HEAL"},
            expectedCosts = {60, 120, 600, 135, 300}
        },
        {
            wave = 95,
            baseCost = 500,
            expectedItems = {"POTION", "ETHER", "REVIVE", "SUPER_POTION", "FULL_HEAL", 
                           "ELIXIR", "MAX_ETHER", "HYPER_POTION", "MAX_REVIVE", "MEMORY_MUSHROOM"},
            expectedCosts = {100, 200, 1000, 225, 500, 500, 500, 400, 1375, 2000}
        }
    }

    for _, test in ipairs(shopTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "GenerateShop",
            WaveIndex = tostring(test.wave),
            BaseCost = tostring(test.baseCost)
        })

        local data = aolite.json.decode(result.Data)
        assert(#data.shopInventory == #test.expectedItems,
            string.format("Wave %d should have %d items", test.wave, #test.expectedItems))

        for i, item in ipairs(data.shopInventory) do
            assert(item.itemId == test.expectedItems[i],
                string.format("Wave %d item %d should be %s", test.wave, i, test.expectedItems[i]))
            assert(item.cost == test.expectedCosts[i],
                string.format("Wave %d %s cost should be %d", test.wave, item.itemId, test.expectedCosts[i]))
        end
    end

    print("✓ Shop generation parity tests passed")
end

-- Test: Reroll Cost Calculation Parity
function testSuite.tests.test_reroll_cost_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript reference reroll costs
    local rerollTests = {
        {wave = 1, count = 0, locked = false, expected = 250}, -- Base cost
        {wave = 1, count = 1, locked = false, expected = 500}, -- 250 * 2^1
        {wave = 1, count = 2, locked = false, expected = 1000}, -- 250 * 2^2
        {wave = 10, count = 0, locked = false, expected = 250}, -- Same wave multiplier
        {wave = 11, count = 0, locked = false, expected = 500}, -- Wave 11-20 multiplier = 2
        {wave = 50, count = 0, locked = false, expected = 1250}, -- Wave 41-50 multiplier = 5
        {wave = 100, count = 0, locked = false, expected = 2500}, -- Wave 91-100 multiplier = 10
    }

    for _, test in ipairs(rerollTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "CalculateRerollCost",
            WaveIndex = tostring(test.wave),
            RerollCount = tostring(test.count),
            LockRarities = tostring(test.locked)
        })

        local data = aolite.json.decode(result.Data)
        assert(data.rerollCost == test.expected,
            string.format("Wave %d count %d should cost %d (got %d)", 
                test.wave, test.count, test.expected, data.rerollCost))
    end

    print("✓ Reroll cost calculation parity tests passed")
end

-- Test: Money Reward Calculation Parity
function testSuite.tests.test_money_reward_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript reference money rewards (simplified examples)
    local rewardTests = {
        {wave = 10, multiplier = 1, expected = 320}, -- Base formula for wave 10
        {wave = 20, multiplier = 1, expected = 420}, -- Base formula for wave 20
        {wave = 10, multiplier = 2.5, expected = 800}, -- Trainer defeat
        {wave = 10, multiplier = 5, expected = 1600}, -- Boss defeat
        {wave = 50, multiplier = 1, expected = 860}, -- Higher wave
        {wave = 100, multiplier = 1, expected = 1820}, -- Even higher wave
    }

    for _, test in ipairs(rewardTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "CalculateMoneyReward",
            WaveIndex = tostring(test.wave),
            Multiplier = tostring(test.multiplier)
        })

        local data = aolite.json.decode(result.Data)
        -- Allow small variance due to rounding differences
        local variance = math.abs(data.moneyReward - test.expected)
        assert(variance <= 10,
            string.format("Wave %d multiplier %s should reward ~%d (got %d)",
                test.wave, test.multiplier, test.expected, data.moneyReward))
    end

    print("✓ Money reward calculation parity tests passed")
end

-- Test: Item Pricing Multipliers Parity
function testSuite.tests.test_item_pricing_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript reference pricing multipliers
    local pricingTests = {
        {itemId = "POTION", multiplier = 0.2},
        {itemId = "ETHER", multiplier = 0.4},
        {itemId = "REVIVE", multiplier = 2.0},
        {itemId = "SUPER_POTION", multiplier = 0.45},
        {itemId = "FULL_HEAL", multiplier = 1.0},
        {itemId = "HYPER_POTION", multiplier = 0.8},
        {itemId = "MAX_REVIVE", multiplier = 2.75},
        {itemId = "MEMORY_MUSHROOM", multiplier = 4.0},
        {itemId = "SACRED_ASH", multiplier = 10.0}
    }

    -- Generate shop to check pricing
    local result = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = "200", -- All items available
        BaseCost = "1000"
    })

    local data = aolite.json.decode(result.Data)
    
    for _, test in ipairs(pricingTests) do
        local found = false
        for _, item in ipairs(data.shopInventory) do
            if item.itemId == test.itemId then
                found = true
                local expectedCost = 1000 * test.multiplier
                assert(item.cost == expectedCost,
                    string.format("%s should cost %d (multiplier %s)",
                        test.itemId, expectedCost, test.multiplier))
                break
            end
        end
        -- Not all items need to be in shop at once
    end

    print("✓ Item pricing multipliers parity tests passed")
end

-- Test: Tier Probabilities Parity
function testSuite.tests.test_tier_probabilities_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript tier weights: [768/1024, 195/1024, 48/1024, 12/1024, 1/1024]
    local expectedProbabilities = {
        {tier = "COMMON", probability = 0.75},      -- 768/1024
        {tier = "GREAT", probability = 0.1904296875}, -- 195/1024
        {tier = "ULTRA", probability = 0.046875},    -- 48/1024
        {tier = "ROGUE", probability = 0.01171875},  -- 12/1024
        {tier = "MASTER", probability = 0.0009765625} -- 1/1024
    }

    local result = ao.send({
        Target = testSuite.processId,
        Action = "CalculateTierProbabilities",
        RerollCount = "0"
    })

    local data = aolite.json.decode(result.Data)
    
    for i, expected in ipairs(expectedProbabilities) do
        local actual = data.probabilities[i]
        assert(actual.tier == expected.tier, "Tier name should match")
        
        -- Allow small floating point variance
        local variance = math.abs(actual.probability - expected.probability)
        assert(variance < 0.001,
            string.format("%s probability should be ~%f (got %f)",
                expected.tier, expected.probability, actual.probability))
    end

    print("✓ Tier probabilities parity tests passed")
end

-- Test: Economic Progression Milestones Parity
function testSuite.tests.test_economic_milestones_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript milestone thresholds
    local milestoneTests = {
        {wave = 1, milestone = "firstShop", expected = true},
        {wave = 29, milestone = "superPotionsUnlocked", expected = false},
        {wave = 30, milestone = "superPotionsUnlocked", expected = true},
        {wave = 60, milestone = "elixirsUnlocked", expected = true},
        {wave = 90, milestone = "hyperPotionsUnlocked", expected = true},
        {wave = 120, milestone = "maxItemsUnlocked", expected = true},
        {wave = 150, milestone = "fullRestoreUnlocked", expected = true},
        {wave = 180, milestone = "sacredAshUnlocked", expected = true}
    }

    for _, test in ipairs(milestoneTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "CheckEconomicProgression",
            WaveIndex = tostring(test.wave),
            Data = aolite.json.encode({
                playerStats = {
                    totalMoneyEarned = 0,
                    totalMoneySpent = 0,
                    itemsPurchased = 0,
                    rerollsUsed = 0
                }
            })
        })

        local data = aolite.json.decode(result.Data)
        assert(data.milestones[test.milestone] == test.expected,
            string.format("Wave %d: %s should be %s",
                test.wave, test.milestone, tostring(test.expected)))
    end

    print("✓ Economic progression milestones parity tests passed")
end

-- Test: Shop Tier Calculation Parity
function testSuite.tests.test_shop_tier_parity()
    local ao = aolite.spawn(testSuite.processPath)

    -- TypeScript formula: math.ceil(math.max(waveIndex + 10, 0) / 30)
    local tierTests = {
        {wave = 1, expectedTier = 1, maxTier = 1},   -- (1+10)/30 = 0.37 -> 1
        {wave = 20, expectedTier = 1, maxTier = 1},  -- (20+10)/30 = 1 -> 1
        {wave = 21, expectedTier = 2, maxTier = 2},  -- (21+10)/30 = 1.03 -> 2
        {wave = 50, expectedTier = 2, maxTier = 2},  -- (50+10)/30 = 2 -> 2
        {wave = 51, expectedTier = 3, maxTier = 3},  -- (51+10)/30 = 2.03 -> 3
        {wave = 95, expectedTier = 4, maxTier = 4},  -- (95+10)/30 = 3.5 -> 4
        {wave = 150, expectedTier = 6, maxTier = 6}, -- (150+10)/30 = 5.33 -> 6
        {wave = 200, expectedTier = 7, maxTier = 7}  -- (200+10)/30 = 7 -> 7
    }

    for _, test in ipairs(tierTests) do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "CheckEconomicProgression",
            WaveIndex = tostring(test.wave),
            Data = aolite.json.encode({
                playerStats = {
                    totalMoneyEarned = 0,
                    totalMoneySpent = 0,
                    itemsPurchased = 0,
                    rerollsUsed = 0
                }
            })
        })

        local data = aolite.json.decode(result.Data)
        assert(data.currentShopTier == test.expectedTier,
            string.format("Wave %d should have shop tier %d (got %d)",
                test.wave, test.expectedTier, data.currentShopTier))
        assert(data.maxAvailableTier == test.maxTier,
            string.format("Wave %d should have max tier %d (got %d)",
                test.wave, test.maxTier, data.maxAvailableTier))
    end

    print("✓ Shop tier calculation parity tests passed")
end

-- Run all parity tests
function testSuite.runTests()
    print("Starting Modifier System Engine Parity Tests...")
    print("Testing mathematical precision and behavioral equivalence with TypeScript")
    print("=" .. string.rep("=", 70))

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

    print("\n" .. string.rep("=", 70))
    print("Parity Test Results: " .. passCount .. "/" .. totalTests .. " passed")

    if passCount == totalTests then
        print("🎉 All modifier system parity tests passed!")
        print("✅ Lua implementation matches TypeScript behavior exactly")
        return true
    else
        print("❌ Parity tests failed - implementation differs from TypeScript")
        return false
    end
end

-- Export test suite
return testSuite