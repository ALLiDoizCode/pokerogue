-- Integration Tests for Modifier System Engine
-- Tests modifier system integration with Pokemon stat management and battle systems

local aolite = require('aolite')

-- Test Suite Configuration
local testSuite = {
    processPath = 'processes/modifier-system-engine.lua',
    processId = 'modifier-system-integration-test',
    tests = {}
}

-- Helper functions for test data
local function createBattleScenario()
    return {
        battleSeed = "test-battle-123",
        turnCount = 1,
        playerParty = {
            {
                id = 1,
                level = 50,
                currentHP = 120,
                maxHP = 200,
                status = "NONE",
                isFainted = false,
                canEvolve = true,
                heldItem = "EVIOLITE",
                stats = {
                    hp = 200,
                    attack = 100,
                    defense = 80,
                    special_attack = 90,
                    special_defense = 85,
                    speed = 95
                },
                moves = {
                    {id = 1, name = "Tackle", currentPP = 20, maxPP = 20, type = "NORMAL"},
                    {id = 2, name = "Ember", currentPP = 15, maxPP = 20, type = "FIRE"}
                }
            }
        },
        enemyParty = {
            {
                id = 2,
                level = 50,
                currentHP = 180,
                maxHP = 180,
                status = "NONE",
                isFainted = false,
                stats = {
                    hp = 180,
                    attack = 110,
                    defense = 70,
                    special_attack = 85,
                    special_defense = 75,
                    speed = 100
                }
            }
        }
    }
end

local function createPlayerInventory()
    return {
        modifiers = {
            {id = "POTION", quantity = 5, stackCount = 1},
            {id = "SUPER_POTION", quantity = 3, stackCount = 1},
            {id = "REVIVE", quantity = 2, stackCount = 1},
            {id = "RARE_CANDY", quantity = 1, stackCount = 1},
            {id = "FULL_HEAL", quantity = 2, stackCount = 1}
        },
        heldItems = {
            {pokemonId = 1, modifierId = "EVIOLITE", stackCount = 1},
            {pokemonId = 1, modifierId = "SITRUS_BERRY", stackCount = 1}
        }
    }
end

-- Test 1: Modifier System in Battle Context
function testSuite.tests.test_battle_context_integration()
    local ao = aolite.spawn(testSuite.processPath)
    local battleData = createBattleScenario()
    local inventory = createPlayerInventory()

    -- Test held item stat calculations in battle
    local pokemon = battleData.playerParty[1]
    local statResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({
            pokemonData = pokemon,
            battleContext = battleData
        })
    })

    assert(statResult.Success == "true", "Should calculate held item effects in battle")
    assert(statResult.StatMultiplier == "1.5", "Should boost defense for unevolved Pokemon")

    -- Test type boost calculation
    local fireMove = {
        type = "FIRE",
        basePower = 40,
        name = "Ember"
    }

    -- Simulate Charcoal held item
    local charcoalResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "CHARCOAL",
        Data = json.encode({
            pokemonData = pokemon,
            moveData = fireMove,
            attackType = "FIRE"
        })
    })

    assert(charcoalResult.Success == "true", "Should process type boost calculation")

    -- Test berry trigger during battle
    local lowHPPokemon = {
        id = 1,
        currentHP = 80, -- 40% HP
        maxHP = 200,
        heldItem = "SITRUS_BERRY"
    }

    local berryTriggerResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode({
            pokemonData = lowHPPokemon,
            battleContext = {
                turnCount = 3,
                lastDamage = 40
            }
        })
    })

    assert(berryTriggerResult.Success == "true", "Should check berry trigger in battle")
    assert(berryTriggerResult.ShouldTrigger == "true", "Should trigger berry at low HP")

    print("✓ Battle context integration tests passed")
end

-- Test 2: Multi-Modifier Interactions
function testSuite.tests.test_multi_modifier_interactions()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Pokemon with multiple held items
    local pokemon = createBattleScenario().playerParty[1]
    local modifierList = {
        {id = "EVIOLITE", stackCount = 1},
        {id = "SCOPE_LENS", stackCount = 1},
        {id = "LEFTOVERS", stackCount = 1},
        {id = "CHARCOAL", stackCount = 1}
    }

    local multiModResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateModifierInteractions",
        Data = json.encode({
            modifierList = modifierList,
            pokemonData = pokemon
        })
    })

    assert(multiModResult.Success == "true", "Should calculate multiple modifier interactions")
    local multiData = json.decode(multiModResult.Data)

    -- Verify stacking effects
    assert(multiData.stackEffects.statMultipliers.defense == 1.5, "Should include Eviolite defense boost")
    assert(multiData.stackEffects.statMultipliers.special_defense == 1.5, "Should include Eviolite sp.def boost")
    assert(multiData.stackEffects.specialEffects.critBoost == 1, "Should include Scope Lens crit boost")
    assert(multiData.stackEffects.damageMultipliers.FIRE == 1.2, "Should include Charcoal fire boost")

    -- Test that multiple stat boosts don't stack (should be replaced, not multiplied)
    local sameTypeModifiers = {
        {id = "EVIOLITE", stackCount = 1},
        {id = "EVIOLITE", stackCount = 1} -- Duplicate should not double-stack
    }

    local duplicateResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateModifierInteractions",
        Data = json.encode({
            modifierList = sameTypeModifiers,
            pokemonData = pokemon
        })
    })

    assert(duplicateResult.Success == "true", "Should handle duplicate modifiers")
    local dupData = json.decode(duplicateResult.Data)
    assert(dupData.stackEffects.statMultipliers.defense == 1.5, "Should not double-stack same modifier")

    print("✓ Multi-modifier interaction tests passed")
end

-- Test 3: Inventory Management Integration
function testSuite.tests.test_inventory_management_integration()
    local ao = aolite.spawn(testSuite.processPath)
    local inventory = createPlayerInventory()

    -- Test modifier usage that affects inventory
    local pokemon = createBattleScenario().playerParty[1]
    pokemon.currentHP = 100 -- Injured

    local consumeResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "SUPER_POTION",
        Data = json.encode({
            pokemonData = pokemon,
            inventoryData = inventory
        })
    })

    assert(consumeResult.Success == "true", "Should process inventory consumption")
    assert(consumeResult.Consumed == "true", "Should consume Super Potion")

    local consumeData = json.decode(consumeResult.Data)
    assert(consumeData.pokemonChanges.currentHP == 150, "Should heal 50 HP")
    assert(consumeData.effects[1].type == "heal", "Should apply healing effect")

    -- Test non-consumable modifier (held item)
    local heldItemResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "EVIOLITE",
        Data = json.encode({
            pokemonData = pokemon
        })
    })

    assert(heldItemResult.Success == "true", "Should process held item")
    local heldData = json.decode(heldItemResult.Data)
    assert(heldData.consumed == false, "Should not consume held item")

    -- Test PP item integration with move data
    local ppMove = pokemon.moves[2] -- Ember with reduced PP
    ppMove.currentPP = 5

    local etherResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "ETHER",
        Data = json.encode({
            pokemonData = pokemon,
            targetData = ppMove,
            inventoryData = inventory
        })
    })

    assert(etherResult.Success == "true", "Should process PP restoration")
    local etherData = json.decode(etherResult.Data)
    assert(etherData.targetChanges.currentPP == 15, "Should restore 10 PP")

    print("✓ Inventory management integration tests passed")
end

-- Test 4: Status Effect and Berry Integration
function testSuite.tests.test_status_effect_berry_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Lum Berry with poisoned Pokemon
    local poisonedPokemon = {
        id = 1,
        level = 50,
        currentHP = 150,
        maxHP = 200,
        status = "POISON",
        isFainted = false,
        heldItem = "LUM_BERRY"
    }

    -- Check if berry should trigger
    local triggerResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "LUM_BERRY",
        Data = json.encode({
            pokemonData = poisonedPokemon,
            battleContext = {
                statusApplied = true
            }
        })
    })

    assert(triggerResult.Success == "true", "Should check Lum Berry trigger")
    assert(triggerResult.ShouldTrigger == "true", "Should trigger on poison status")

    -- Test Full Heal item on status
    local fullHealResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "FULL_HEAL",
        Data = json.encode({
            pokemonData = poisonedPokemon
        })
    })

    assert(fullHealResult.Success == "true", "Should process Full Heal")
    local healData = json.decode(fullHealResult.Data)
    assert(healData.pokemonChanges.status == "NONE", "Should cure status condition")
    assert(healData.effects[1].type == "cure_status", "Should apply status cure effect")

    print("✓ Status effect and berry integration tests passed")
end

-- Test 5: Battle Damage and Survival Integration
function testSuite.tests.test_battle_damage_survival_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Focus Band survival mechanism
    local focusBandPokemon = {
        id = 1,
        currentHP = 50,
        maxHP = 200,
        heldItem = "FOCUS_BAND"
    }

    local battleContext = {
        wouldKO = true,
        incomingDamage = 60
    }

    local survivalResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "FOCUS_BAND",
        Data = json.encode({
            pokemonData = focusBandPokemon,
            battleContext = battleContext
        })
    })

    assert(survivalResult.Success == "true", "Should check Focus Band survival")
    assert(survivalResult.ShouldTrigger == "true", "Should trigger on fatal damage")

    -- Test Quick Claw speed bypass
    local quickClawPokemon = {
        id = 1,
        stats = {speed = 80},
        heldItem = "QUICK_CLAW"
    }

    local speedContext = {
        moveFirst = false,
        opponentSpeed = 100
    }

    local speedResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "QUICK_CLAW",
        Data = json.encode({
            pokemonData = quickClawPokemon,
            battleContext = speedContext
        })
    })

    assert(speedResult.Success == "true", "Should check Quick Claw speed bypass")
    assert(speedResult.ShouldTrigger == "true", "Should trigger when moving second")

    print("✓ Battle damage and survival integration tests passed")
end

-- Test 6: Evolution and Level Integration
function testSuite.tests.test_evolution_level_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Rare Candy level up integration
    local lowLevelPokemon = {
        id = 1,
        level = 15,
        exp = 3000,
        expToNext = 500,
        canEvolve = true,
        evolutionLevel = 16
    }

    local candyResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessModifierConsumption",
        ModifierId = "RARE_CANDY",
        Data = json.encode({
            pokemonData = lowLevelPokemon
        })
    })

    assert(candyResult.Success == "true", "Should process Rare Candy")
    local candyData = json.decode(candyResult.Data)
    assert(candyData.pokemonChanges.level == 16, "Should increase level to evolution threshold")

    -- Test Eviolite effectiveness before and after evolution
    local unevolved = {canEvolve = true}
    local evolved = {canEvolve = false}

    local unevolvedResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({pokemonData = unevolved})
    })

    local evolvedResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode({pokemonData = evolved})
    })

    assert(unevolvedResult.StatMultiplier == "1.5", "Should boost unevolved Pokemon")
    assert(evolvedResult.StatMultiplier == "1.0", "Should not boost evolved Pokemon")

    print("✓ Evolution and level integration tests passed")
end

-- Test 7: Cross-Process Message Flow Simulation
function testSuite.tests.test_cross_process_message_flow()
    local ao = aolite.spawn(testSuite.processPath)

    -- Simulate battle coordinator requesting modifier effects
    local battleRequest = {
        operation = "calculateModifierEffects",
        battleId = "battle-123",
        pokemonData = {
            id = 1,
            level = 50,
            currentHP = 120,
            maxHP = 200,
            heldItems = {"EVIOLITE", "SITRUS_BERRY"},
            canEvolve = true
        },
        requestedStats = {"defense", "special_defense"}
    }

    -- Process multiple stat calculations
    local defenseResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "defense",
        Data = json.encode(battleRequest)
    })

    local spdefResult = ao.send({
        Target = testSuite.processId,
        Action = "CalculateHeldModifierEffects",
        ModifierId = "EVIOLITE",
        Stat = "special_defense",
        Data = json.encode(battleRequest)
    })

    assert(defenseResult.Success == "true", "Should handle defense calculation")
    assert(spdefResult.Success == "true", "Should handle special defense calculation")
    assert(defenseResult.StatMultiplier == "1.5", "Should boost defense")
    assert(spdefResult.StatMultiplier == "1.5", "Should boost special defense")

    -- Simulate berry consumption during battle
    local berryConsumption = {
        pokemonData = battleRequest.pokemonData,
        battleContext = {
            turnCount = 5,
            damageReceived = 80
        }
    }

    berryConsumption.pokemonData.currentHP = 80 -- Trigger Sitrus Berry

    local berryResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckHeldItemTriggers",
        ModifierId = "SITRUS_BERRY",
        Data = json.encode(berryConsumption)
    })

    assert(berryResult.Success == "true", "Should process berry trigger check")
    assert(berryResult.ShouldTrigger == "true", "Should trigger berry consumption")

    print("✓ Cross-process message flow simulation tests passed")
end

-- Test 8: Performance and Concurrency
function testSuite.tests.test_performance_concurrency()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test rapid sequential requests
    local startTime = os.clock()
    local requestCount = 100
    local successCount = 0

    for i = 1, requestCount do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "GetModifierInfo",
            ModifierId = "POTION"
        })

        if result.Success == "true" then
            successCount = successCount + 1
        end
    end

    local endTime = os.clock()
    local avgResponseTime = (endTime - startTime) / requestCount * 1000 -- ms

    assert(successCount == requestCount, "Should handle all concurrent requests")
    assert(avgResponseTime < 50, "Should maintain sub-50ms response time: " .. avgResponseTime .. "ms")

    -- Test complex calculations under load
    local complexStartTime = os.clock()
    local complexRequestCount = 50
    local complexSuccessCount = 0

    for i = 1, complexRequestCount do
        local pokemon = {
            id = i,
            level = 50,
            canEvolve = (i % 2 == 0),
            currentHP = 100 + i,
            maxHP = 200
        }

        local result = ao.send({
            Target = testSuite.processId,
            Action = "CalculateModifierInteractions",
            Data = json.encode({
                modifierList = {
                    {id = "EVIOLITE", stackCount = 1},
                    {id = "SCOPE_LENS", stackCount = 1},
                    {id = "LEFTOVERS", stackCount = 1}
                },
                pokemonData = pokemon
            })
        })

        if result.Success == "true" then
            complexSuccessCount = complexSuccessCount + 1
        end
    end

    local complexEndTime = os.clock()
    local complexAvgTime = (complexEndTime - complexStartTime) / complexRequestCount * 1000

    assert(complexSuccessCount == complexRequestCount, "Should handle complex calculations")
    assert(complexAvgTime < 100, "Should maintain reasonable response time for complex ops: " .. complexAvgTime .. "ms")

    print("✓ Performance and concurrency tests passed")
    print("  - Simple requests: " .. avgResponseTime .. "ms avg")
    print("  - Complex requests: " .. complexAvgTime .. "ms avg")
end

-- ============================================================================
-- BERRY SYSTEM INTEGRATION TESTS
-- ============================================================================

-- Test: Berry Battle Integration
function testSuite.tests.test_berry_battle_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Create battle scenario with berry consumption
    local battleData = {
        pokemonData = {
            id = 1,
            currentHP = 75,  -- 37.5% HP to trigger Sitrus
            maxHP = 200,
            status = "NONE",
            heldItem = "SITRUS_BERRY"
        },
        battleContext = {
            hitBySuperEffective = false,
            turnPhase = "post_damage"
        }
    }

    -- Test berry trigger evaluation
    local triggerResult = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode(battleData)
    })

    assert(triggerResult.Success == "true", "Should evaluate berry trigger")
    assert(triggerResult.ShouldTrigger == "true", "Should trigger at 37.5% HP")

    -- Test berry consumption
    local consumeResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode(battleData)
    })

    assert(consumeResult.Success == "true", "Should consume berry")
    local consumeData = aolite.json.decode(consumeResult.Data)
    assert(consumeData.consumed == true, "Berry should be consumed")
    assert(#consumeData.effects == 1, "Should have healing effect")
    assert(consumeData.pokemonChanges.currentHP == 125, "Should heal to 125 HP")

    print("✓ Berry battle integration test passed")
end

-- Test: Multi-Berry Workflow Integration
function testSuite.tests.test_multi_berry_workflow()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Lum Berry for status cure
    local poisonedPokemon = {
        pokemonData = {
            id = 1,
            currentHP = 150,
            maxHP = 200,
            status = "POISON",
            isConfused = true
        },
        battleContext = {}
    }

    local lumResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LUM_BERRY",
        Data = aolite.json.encode(poisonedPokemon)
    })

    assert(lumResult.Success == "true", "Should consume Lum Berry")
    local lumData = aolite.json.decode(lumResult.Data)
    assert(lumData.pokemonChanges.status == "NONE", "Should cure poison")
    assert(lumData.pokemonChanges.isConfused == false, "Should cure confusion")

    -- Test Leppa Berry for PP restoration
    local lowPpPokemon = {
        pokemonData = {
            id = 2,
            currentHP = 200,
            maxHP = 200,
            moves = {
                {index = 1, name = "Tackle", currentPP = 0, maxPP = 20},
                {index = 2, name = "Quick Attack", currentPP = 15, maxPP = 25}
            }
        },
        battleContext = {}
    }

    local leppaResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LEPPA_BERRY",
        Data = aolite.json.encode(lowPpPokemon)
    })

    assert(leppaResult.Success == "true", "Should consume Leppa Berry")
    local leppaData = aolite.json.decode(leppaResult.Data)
    assert(leppaData.effects[1].amount == 10, "Should restore 10 PP")
    assert(leppaData.effects[1].moveName == "Tackle", "Should restore depleted move")

    print("✓ Multi-berry workflow integration test passed")
end

-- Test: Berry Ability Interaction Integration
function testSuite.tests.test_berry_ability_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test Gluttony ability effect (early berry trigger)
    local gluttonyPokemon = {
        pokemonData = {
            id = 1,
            currentHP = 140, -- 70% HP, normally wouldn't trigger
            maxHP = 200,
            statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
        },
        battleContext = {
            berryThreshold = 0.75  -- Gluttony raises threshold to 75%
        }
    }

    local gluttonyTrigger = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode(gluttonyPokemon)
    })

    assert(gluttonyTrigger.ShouldTrigger == "true", "Should trigger with Gluttony")

    -- Test Ripen ability effect (double berry power)
    local ripenPokemon = {
        pokemonData = {
            id = 2,
            currentHP = 80,
            maxHP = 200
        },
        battleContext = {
            doubleBerryEffect = true  -- Ripen doubles effect
        }
    }

    local ripenResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode(ripenPokemon)
    })

    local ripenData = aolite.json.decode(ripenResult.Data)
    assert(ripenData.effects[1].percentage == 50, "Should double healing percentage")
    assert(ripenData.effects[1].amount == 100, "Should heal 100 HP with Ripen")

    print("✓ Berry ability integration test passed")
end

-- Test: Berry Preservation Integration
function testSuite.tests.test_berry_preservation_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test without Berry Pouch
    local preservationTest = {
        pokemonData = {
            id = 1,
            currentHP = 80,
            maxHP = 200
        },
        modifierList = {} -- No preservation item
    }

    local noPreservation = ao.send({
        Target = testSuite.processId,
        Action = "CheckBerryPreservation",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode(preservationTest)
    })

    assert(noPreservation.Preserved == "false", "Should not preserve without Berry Pouch")

    -- Test with Berry Pouch equivalent
    preservationTest.modifierList = {{id = "AMULET_COIN"}} -- Berry Pouch placeholder

    local withPreservation = ao.send({
        Target = testSuite.processId,
        Action = "CheckBerryPreservation",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode(preservationTest)
    })

    assert(withPreservation.Preserved == "true", "Should preserve with Berry Pouch")

    print("✓ Berry preservation integration test passed")
end

-- Test: Complex Berry Scenario Integration
function testSuite.tests.test_complex_berry_scenarios()
    local ao = aolite.spawn(testSuite.processPath)

    -- Scenario 1: Stat-boosting berry with stat cap
    local maxedStatPokemon = {
        pokemonData = {
            id = 1,
            currentHP = 40,
            maxHP = 200,
            statStages = {
                attack = 6, -- Already at +6 cap
                defense = 0,
                special_attack = 0,
                special_defense = 0,
                speed = 0
            }
        },
        battleContext = {}
    }

    -- Should not trigger when stat is maxed
    local maxStatResult = ao.send({
        Target = testSuite.processId,
        Action = "EvaluateBerryTrigger",
        BerryId = "LIECHI_BERRY",
        Data = aolite.json.encode(maxedStatPokemon)
    })

    assert(maxStatResult.ShouldTrigger == "false", "Should not trigger with maxed stat")

    -- Scenario 2: Multiple berries in sequence
    local multiTestPokemon = {
        pokemonData = {
            id = 2,
            currentHP = 50,
            maxHP = 200,
            status = "BURN",
            statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
        },
        battleContext = {}
    }

    -- First consume Sitrus for healing
    local sitrusResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "SITRUS_BERRY",
        Data = aolite.json.encode(multiTestPokemon)
    })

    local sitrusData = aolite.json.decode(sitrusResult.Data)
    assert(sitrusData.pokemonChanges.currentHP == 100, "Should heal to 100 HP")

    -- Then Lum for status
    local lumResult = ao.send({
        Target = testSuite.processId,
        Action = "ConsumeBerry",
        BerryId = "LUM_BERRY",
        Data = aolite.json.encode(multiTestPokemon)
    })

    local lumData = aolite.json.decode(lumResult.Data)
    assert(lumData.pokemonChanges.status == "NONE", "Should cure burn")

    print("✓ Complex berry scenario integration test passed")
end

-- Test: Berry System Performance Integration
function testSuite.tests.test_berry_performance_integration()
    local ao = aolite.spawn(testSuite.processPath)

    local testPokemon = {
        pokemonData = {
            id = 1,
            currentHP = 80,
            maxHP = 200,
            status = "POISON",
            statStages = {attack = 0, defense = 0, special_attack = 0, special_defense = 0, speed = 0}
        },
        battleContext = {}
    }

    -- Performance test: Multiple berry evaluations
    local startTime = os.clock()
    local testCount = 50
    local successCount = 0

    local berryTypes = {"SITRUS_BERRY", "LUM_BERRY", "LEPPA_BERRY", "LIECHI_BERRY", "GANLON_BERRY"}

    for i = 1, testCount do
        local berryId = berryTypes[(i % #berryTypes) + 1]
        local result = ao.send({
            Target = testSuite.processId,
            Action = "EvaluateBerryTrigger",
            BerryId = berryId,
            Data = aolite.json.encode(testPokemon)
        })

        if result.Success == "true" then
            successCount = successCount + 1
        end
    end

    local endTime = os.clock()
    local avgTime = (endTime - startTime) / testCount * 1000

    assert(successCount == testCount, "All berry evaluations should succeed")
    assert(avgTime < 50, "Berry evaluation should be under 50ms avg: " .. avgTime .. "ms")

    -- Performance test: Berry consumption
    local consumeStartTime = os.clock()
    local consumeCount = 25
    local consumeSuccessCount = 0

    for i = 1, consumeCount do
        local berryId = berryTypes[(i % #berryTypes) + 1]
        local result = ao.send({
            Target = testSuite.processId,
            Action = "ConsumeBerry",
            BerryId = berryId,
            Data = aolite.json.encode(testPokemon)
        })

        if result.Success == "true" then
            consumeSuccessCount = consumeSuccessCount + 1
        end
    end

    local consumeEndTime = os.clock()
    local consumeAvgTime = (consumeEndTime - consumeStartTime) / consumeCount * 1000

    assert(consumeSuccessCount == consumeCount, "All berry consumptions should succeed")
    assert(consumeAvgTime < 100, "Berry consumption should be under 100ms avg: " .. consumeAvgTime .. "ms")

    print("✓ Berry performance integration test passed")
    print("  - Evaluation: " .. avgTime .. "ms avg")
    print("  - Consumption: " .. consumeAvgTime .. "ms avg")
end

-- Test: Shop and Purchase Integration
function testSuite.tests.test_shop_purchase_integration()
    local ao = aolite.spawn(testSuite.processPath)

    local gameState = {
        player = {
            inventory = {
                money = 1000,
                items = {}
            },
            progression = {
                wave = 35
            }
        }
    }

    -- Generate shop for wave 35
    local shopResult = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = "35",
        BaseCost = "300"
    })

    assert(shopResult.Success == "true", "Should generate shop")
    local shopData = aolite.json.decode(shopResult.Data)
    assert(#shopData.shopInventory > 3, "Wave 35 should have multiple items")

    -- Purchase multiple items
    local itemsPurchased = 0
    local totalSpent = 0

    for i, item in ipairs(shopData.shopInventory) do
        if i > 3 then break end -- Purchase first 3 items

        local purchaseResult = ao.send({
            Target = testSuite.processId,
            Action = "PurchaseItem",
            ItemId = item.itemId,
            Cost = tostring(item.cost),
            Data = aolite.json.encode({
                gameState = gameState
            })
        })

        if purchaseResult.Success == "true" then
            itemsPurchased = itemsPurchased + 1
            totalSpent = totalSpent + item.cost
            gameState.player.inventory.money = gameState.player.inventory.money - item.cost
        end
    end

    assert(itemsPurchased > 0, "Should purchase at least one item")
    assert(gameState.player.inventory.money == 1000 - totalSpent, "Money should be correctly deducted")

    print("✓ Shop and purchase integration test passed")
    print("  - Items purchased: " .. itemsPurchased)
    print("  - Total spent: " .. totalSpent)
end

-- Test: Economic Progression Integration
function testSuite.tests.test_economic_progression_integration()
    local ao = aolite.spawn(testSuite.processPath)

    -- Simulate game progression with economic events
    local waveProgression = {1, 10, 25, 50, 75, 100, 150, 200}
    local totalEarned = 0
    local totalSpent = 0

    for _, wave in ipairs(waveProgression) do
        -- Process battle victory reward
        local battleResult = ao.send({
            Target = testSuite.processId,
            Action = "ProcessEconomicEvent",
            EventType = "battle_victory",
            WaveIndex = tostring(wave)
        })

        local battleData = aolite.json.decode(battleResult.Data)
        totalEarned = totalEarned + battleData.moneyReward

        -- Check shop generation for this wave
        if wave % 10 ~= 0 then
            local shopResult = ao.send({
                Target = testSuite.processId,
                Action = "GenerateShop",
                WaveIndex = tostring(wave),
                BaseCost = tostring(100 + wave * 5)
            })

            local shopData = aolite.json.decode(shopResult.Data)
            
            -- Simulate purchase if money available
            if shopData.shopInventory[1] and totalEarned - totalSpent > shopData.shopInventory[1].cost then
                totalSpent = totalSpent + shopData.shopInventory[1].cost
            end
        end

        -- Check progression milestones
        local progressResult = ao.send({
            Target = testSuite.processId,
            Action = "CheckEconomicProgression",
            WaveIndex = tostring(wave),
            Data = aolite.json.encode({
                playerStats = {
                    totalMoneyEarned = totalEarned,
                    totalMoneySpent = totalSpent,
                    itemsPurchased = math.floor(totalSpent / 100),
                    rerollsUsed = math.floor(wave / 20)
                }
            })
        })

        local progressData = aolite.json.decode(progressResult.Data)
        
        -- Verify milestones are unlocked appropriately
        if wave >= 150 then
            assert(progressData.milestones.fullRestoreUnlocked == true, "Full Restore should be unlocked at wave 150+")
        end
        if wave >= 90 then
            assert(progressData.milestones.hyperPotionsUnlocked == true, "Hyper Potions should be unlocked at wave 90+")
        end
    end

    assert(totalEarned > 0, "Should earn money through progression")

    print("✓ Economic progression integration test passed")
    print("  - Total earned: " .. totalEarned)
    print("  - Total spent: " .. totalSpent)
end

-- Test: Reroll and Tier System Integration
function testSuite.tests.test_reroll_tier_integration()
    local ao = aolite.spawn(testSuite.processPath)

    local playerMoney = 5000
    local waveIndex = 50
    local rerollCount = 0

    -- Generate initial shop
    local shopResult = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = tostring(waveIndex),
        BaseCost = "400"
    })

    local initialShop = aolite.json.decode(shopResult.Data).shopInventory

    -- Test multiple rerolls
    for i = 1, 3 do
        -- Calculate reroll cost
        local costResult = ao.send({
            Target = testSuite.processId,
            Action = "CalculateRerollCost",
            WaveIndex = tostring(waveIndex),
            RerollCount = tostring(rerollCount)
        })

        local rerollCost = aolite.json.decode(costResult.Data).rerollCost

        if playerMoney >= rerollCost then
            -- Perform reroll
            local rerollResult = ao.send({
                Target = testSuite.processId,
                Action = "RerollShop",
                WaveIndex = tostring(waveIndex),
                RerollCount = tostring(rerollCount),
                PlayerMoney = tostring(playerMoney)
            })

            if rerollResult.Success == "true" then
                local rerollData = aolite.json.decode(rerollResult.Data)
                playerMoney = rerollData.newMoney
                rerollCount = rerollData.rerollCount

                -- Verify shop changed
                assert(#rerollData.shopInventory > 0, "Rerolled shop should have items")
            end
        end
    end

    assert(rerollCount > 0, "Should have performed at least one reroll")

    -- Test tier rolling
    local tierResult = ao.send({
        Target = testSuite.processId,
        Action = "RollModifierTier",
        RngSeed = "12345",
        WaveIndex = tostring(waveIndex),
        RerollCount = tostring(rerollCount)
    })

    assert(tierResult.Success == "true", "Should roll tier")
    local tierData = aolite.json.decode(tierResult.Data)
    assert(tierData.tierName ~= nil, "Should have tier name")

    print("✓ Reroll and tier system integration test passed")
    print("  - Rerolls performed: " .. rerollCount)
    print("  - Money spent on rerolls: " .. (5000 - playerMoney))
end

-- Test: Complete Shop Transaction Flow
function testSuite.tests.test_complete_shop_transaction()
    local ao = aolite.spawn(testSuite.processPath)

    -- Initialize comprehensive game state
    local gameState = {
        player = {
            inventory = {
                money = 2000,
                items = {},
                modifiers = {}
            },
            progression = {
                wave = 65,
                unlocks = {}
            }
        },
        battle = {
            waveIndex = 65,
            conditions = {},
            rewardMultipliers = {}
        }
    }

    -- 1. Process battle victory reward
    local victoryResult = ao.send({
        Target = testSuite.processId,
        Action = "ProcessEconomicEvent",
        EventType = "battle_victory",
        WaveIndex = "65",
        MoneyMultiplierModifiers = "1.5"
    })

    local victoryData = aolite.json.decode(victoryResult.Data)
    gameState.player.inventory.money = gameState.player.inventory.money + victoryData.moneyReward

    -- 2. Generate shop
    local shopResult = ao.send({
        Target = testSuite.processId,
        Action = "GenerateShop",
        WaveIndex = "65",
        BaseCost = "350"
    })

    local shopData = aolite.json.decode(shopResult.Data)

    -- 3. Attempt purchases until money runs low
    local purchaseCount = 0
    local purchaseHistory = {}

    for _, item in ipairs(shopData.shopInventory) do
        -- Validate purchase first
        local validateResult = ao.send({
            Target = testSuite.processId,
            Action = "ValidatePurchase",
            ItemId = item.itemId,
            PlayerMoney = tostring(gameState.player.inventory.money),
            Cost = tostring(item.cost)
        })

        local validateData = aolite.json.decode(validateResult.Data)

        if validateData.valid then
            -- Execute purchase
            local purchaseResult = ao.send({
                Target = testSuite.processId,
                Action = "PurchaseItem",
                ItemId = item.itemId,
                Cost = tostring(item.cost),
                Data = aolite.json.encode({
                    gameState = gameState
                })
            })

            if purchaseResult.Success == "true" then
                local purchaseData = aolite.json.decode(purchaseResult.Data)
                gameState = purchaseData.gameState
                purchaseCount = purchaseCount + 1
                table.insert(purchaseHistory, {
                    itemId = item.itemId,
                    cost = item.cost
                })
            end
        end
    end

    -- 4. Check final economic progression
    local progressResult = ao.send({
        Target = testSuite.processId,
        Action = "CheckEconomicProgression",
        WaveIndex = "65",
        Data = aolite.json.encode({
            playerStats = {
                totalMoneyEarned = victoryData.moneyReward,
                totalMoneySpent = (function()
                    local total = 0
                    for _, purchase in ipairs(purchaseHistory) do
                        total = total + purchase.cost
                    end
                    return total
                end)(),
                itemsPurchased = purchaseCount,
                rerollsUsed = 0
            }
        })
    })

    local progressData = aolite.json.decode(progressResult.Data)
    assert(progressData.milestones.elixirsUnlocked == true, "Elixirs should be unlocked at wave 65")
    assert(progressData.currentShopTier >= 3, "Shop tier should be at least 3")

    print("✓ Complete shop transaction flow test passed")
    print("  - Money earned: " .. victoryData.moneyReward)
    print("  - Items purchased: " .. purchaseCount)
    print("  - Final money: " .. gameState.player.inventory.money)
end

-- Test: Economic System Performance
function testSuite.tests.test_economic_performance()
    local ao = aolite.spawn(testSuite.processPath)

    -- Test shop generation performance
    local shopGenCount = 50
    local shopStartTime = os.clock()

    for i = 1, shopGenCount do
        local waveIndex = math.random(1, 200)
        local result = ao.send({
            Target = testSuite.processId,
            Action = "GenerateShop",
            WaveIndex = tostring(waveIndex),
            BaseCost = tostring(100 + waveIndex * 2)
        })

        assert(result.Success == "true", "Shop generation should succeed")
    end

    local shopEndTime = os.clock()
    local shopAvgTime = (shopEndTime - shopStartTime) / shopGenCount * 1000

    -- Test reroll cost calculation performance
    local rerollCount = 100
    local rerollStartTime = os.clock()

    for i = 1, rerollCount do
        local result = ao.send({
            Target = testSuite.processId,
            Action = "CalculateRerollCost",
            WaveIndex = tostring(math.random(1, 200)),
            RerollCount = tostring(math.random(0, 5))
        })

        assert(result.Success == "true", "Reroll calculation should succeed")
    end

    local rerollEndTime = os.clock()
    local rerollAvgTime = (rerollEndTime - rerollStartTime) / rerollCount * 1000

    assert(shopAvgTime < 50, "Shop generation should be under 50ms avg: " .. shopAvgTime .. "ms")
    assert(rerollAvgTime < 10, "Reroll calculation should be under 10ms avg: " .. rerollAvgTime .. "ms")

    print("✓ Economic system performance test passed")
    print("  - Shop generation: " .. shopAvgTime .. "ms avg")
    print("  - Reroll calculation: " .. rerollAvgTime .. "ms avg")
end

-- Run all integration tests
function testSuite.runTests()
    print("Starting Modifier System Engine Integration Tests...")
    print("=" .. string.rep("=", 60))

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

    print("\n" .. string.rep("=", 60))
    print("Integration Test Results: " .. passCount .. "/" .. totalTests .. " passed")

    if passCount == totalTests then
        print("🎉 All modifier system engine integration tests passed!")
        return true
    else
        print("❌ Some integration tests failed")
        return false
    end
end

-- Export test suite
return testSuite