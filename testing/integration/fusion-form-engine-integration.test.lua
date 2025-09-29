-- Integration Tests for Fusion Form Engine Process
-- Tests cross-process fusion appearance coordination

local aosLocal = require('aos-local')
local json = require('json')

-- Test configuration
local testConfig = {
    timeout = 30000,
    maxRetries = 3
}

describe("Fusion Form Engine Integration Tests", function()
    
    local processes = {}
    
    before(function()
        -- Initialize aos-local environment
        aosLocal.start()
        
        -- Load required processes
        processes.coordinator = aosLocal.spawn('./processes/coordinator-process.lua')
        processes.fusionForm = aosLocal.spawn('./processes/fusion-form-engine.lua')
        processes.pokemonState = aosLocal.spawn('./processes/pokemon-state-manager.lua')
        processes.fusionCalc = aosLocal.spawn('./processes/fusion-calculation-engine.lua')
        
        -- Wait for initialization
        aosLocal.wait(1000)
    end)
    
    after(function()
        aosLocal.stop()
    end)
    
    describe("Process Communication", function()
        it("should coordinate with Pokemon State Manager", function()
            -- Create Pokemon with fusion data
            local pokemonData = {
                species = "PIKACHU",
                level = 50,
                formIndex = 0,
                shiny = false,
                variant = 0,
                gender = "MALE",
                fusionSpecies = "RAICHU",
                fusionFormIndex = 0,
                fusionShiny = true,
                fusionVariant = 1,
                fusionGender = "FEMALE"
            }
            
            -- Send to Pokemon State Manager first
            local stateResult = aosLocal.send(processes.pokemonState, {
                Action = "CreatePokemon",
                Data = json.encode({
                    operation = "create",
                    pokemonData = pokemonData
                })
            })
            
            assert.is_not_nil(stateResult)
            
            -- Then generate fusion appearance
            local gameState = {
                pokemon = pokemonData,
                battle = {
                    battleSeed = "integration_test_12345",
                    rngCounter = 0
                }
            }
            
            local fusionResult = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance",
                Data = json.encode({
                    gameState = gameState,
                    parameters = {
                        appearanceType = "full",
                        generationMethod = "palette_blend"
                    }
                })
            })
            
            assert.is_equal("SaveState", fusionResult.Action)
            local fusionData = json.decode(fusionResult.Data)
            
            -- Verify fusion appearance includes expected sprite keys
            assert.is_not_nil(fusionData.fusionAppearance.spriteKeys)
            assert.is_string(fusionData.fusionAppearance.spriteKeys.base)
            assert.is_string(fusionData.fusionAppearance.spriteKeys.fusion)
        end)
        
        it("should coordinate with Fusion Calculation Engine", function()
            -- First calculate fusion stats
            local fusionCalcResult = aosLocal.send(processes.fusionCalc, {
                Action = "CalculateFusionStats",
                Data = json.encode({
                    operation = "calculateFusionStats",
                    gameState = {
                        pokemon = {
                            species = "PIKACHU",
                            fusionSpecies = "RAICHU",
                            level = 50
                        }
                    }
                })
            })
            
            assert.is_not_nil(fusionCalcResult)
            
            -- Then generate appearance with calculated data
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU",
                    level = 50,
                    stats = {hp = 150, attack = 120} -- From calculation
                },
                battle = {battleSeed = "calc_test_123"}
            }
            
            local appearanceResult = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            assert.is_equal("SaveState", appearanceResult.Action)
            local data = json.decode(appearanceResult.Data)
            assert.is_true(data.validation.appearanceValid)
        end)
        
        it("should coordinate with Game State Coordinator", function()
            -- Create a complete game state through coordinator
            local coordinatorResult = aosLocal.send(processes.coordinator, {
                Action = "ProcessWorkflow",
                Data = json.encode({
                    operation = "fusionAppearanceWorkflow",
                    gameState = {
                        player = {
                            id = "integration_test_player",
                            party = {
                                {
                                    species = "PIKACHU",
                                    fusionSpecies = "RAICHU",
                                    level = 50
                                }
                            }
                        },
                        battle = {
                            battleId = "integration_battle_123",
                            battleSeed = "coord_test_456"
                        }
                    },
                    workflows = {
                        {
                            processId = processes.fusionForm.id,
                            action = "GenerateFusionAppearance",
                            priority = 1
                        }
                    }
                })
            })
            
            -- Wait for workflow completion
            aosLocal.wait(2000)
            
            -- Coordinator should handle the workflow
            assert.is_not_nil(coordinatorResult)
        end)
    end)
    
    describe("Message Handler Workflow", function()
        it("should validate complete fusion appearance workflow", function()
            local testGameState = {
                pokemon = {
                    species = "CHARIZARD",
                    formIndex = 0,
                    shiny = false,
                    variant = 0,
                    gender = "MALE",
                    fusionSpecies = "BLASTOISE",
                    fusionFormIndex = 0, 
                    fusionShiny = true,
                    fusionVariant = 2,
                    fusionGender = "FEMALE"
                },
                battle = {
                    battleSeed = "workflow_test_789",
                    rngCounter = 5
                }
            }
            
            -- Step 1: Validate appearance data
            local validationResult = aosLocal.send(processes.fusionForm, {
                Action = "ValidateFusionAppearance",
                Data = json.encode({gameState = testGameState, parameters = {}})
            })
            
            local validation = json.decode(validationResult.Data)
            assert.is_true(validation.appearanceValid)
            
            -- Step 2: Determine fusion form
            local formResult = aosLocal.send(processes.fusionForm, {
                Action = "DetermineFusionForm", 
                Data = json.encode({gameState = testGameState, parameters = {}})
            })
            
            local formData = json.decode(formResult.Data)
            assert.is_true(formData.formValid)
            
            -- Step 3: Generate fusion appearance
            local appearanceResult = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance",
                Data = json.encode({gameState = testGameState, parameters = {}})
            })
            
            local appearance = json.decode(appearanceResult.Data)
            assert.is_not_nil(appearance.fusionAppearance)
            
            -- Step 4: Calculate precision 
            local precisionResult = aosLocal.send(processes.fusionForm, {
                Action = "CalculateAppearancePrecision",
                Data = json.encode({gameState = testGameState, parameters = {}})
            })
            
            local precision = json.decode(precisionResult.Data)
            assert.is_number(precision.overallPrecision)
            
            -- Step 5: Resolve any complex scenarios
            local resolutionResult = aosLocal.send(processes.fusionForm, {
                Action = "ResolveFusionVisuals",
                Data = json.encode({
                    gameState = testGameState,
                    parameters = {
                        complexScenarios = {
                            {type = "color_conflict", id = "test_conflict"}
                        }
                    }
                })
            })
            
            local resolution = json.decode(resolutionResult.Data)
            assert.is_equal(1, resolution.scenariosResolved)
        end)
        
        it("should handle concurrent fusion appearance requests", function()
            local promises = {}
            
            -- Send multiple concurrent requests
            for i = 1, 5 do
                local gameState = {
                    pokemon = {
                        species = "POKEMON_" .. i,
                        fusionSpecies = "FUSION_" .. i,
                        level = 40 + i
                    },
                    battle = {
                        battleSeed = "concurrent_" .. i,
                        rngCounter = i
                    }
                }
                
                table.insert(promises, {
                    id = i,
                    request = aosLocal.sendAsync(processes.fusionForm, {
                        Action = "GenerateFusionAppearance",
                        Data = json.encode({gameState = gameState, parameters = {}})
                    })
                })
            end
            
            -- Wait for all responses
            local results = {}
            for _, promise in ipairs(promises) do
                local result = aosLocal.await(promise.request, testConfig.timeout)
                assert.is_not_nil(result)
                assert.is_equal("SaveState", result.Action)
                table.insert(results, {id = promise.id, result = result})
            end
            
            assert.is_equal(5, #results)
        end)
    end)
    
    describe("Fusion Appearance Persistence", function()
        it("should persist fusion appearance across save/load cycles", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU", 
                    fusionSpecies = "RAICHU",
                    customAppearanceData = {
                        savedSprites = true,
                        colorProfile = "test_profile"
                    }
                },
                battle = {battleSeed = "persistence_test"}
            }
            
            -- Generate initial appearance
            local appearanceResult = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local initialAppearance = json.decode(appearanceResult.Data)
            
            -- Save game state through coordinator
            local saveResult = aosLocal.send(processes.coordinator, {
                Action = "SaveGameState",
                Data = json.encode({
                    gameState = gameState,
                    saveData = {
                        fusionAppearance = initialAppearance.fusionAppearance
                    }
                })
            })
            
            assert.is_not_nil(saveResult)
            
            -- Load game state 
            local loadResult = aosLocal.send(processes.coordinator, {
                Action = "LoadGameState",
                Data = json.encode({
                    saveId = "persistence_test"
                })
            })
            
            assert.is_not_nil(loadResult)
            
            -- Regenerate appearance and verify consistency
            local regenResult = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local regenAppearance = json.decode(regenResult.Data)
            
            -- Sprite keys should be consistent
            assert.is_equal(
                initialAppearance.fusionAppearance.spriteKeys.base,
                regenAppearance.fusionAppearance.spriteKeys.base
            )
        end)
    end)
    
    describe("Complex Multi-System Scenarios", function()
        it("should handle fusion Pokemon in battle scenarios", function()
            -- Create a complex battle scenario with fusion Pokemon
            local battleSetup = {
                battle = {
                    battleId = "complex_battle_123",
                    battleSeed = "complex_seed_456",
                    playerParty = {
                        {
                            species = "CHARIZARD",
                            fusionSpecies = "TYPHLOSION",
                            level = 55,
                            shiny = true
                        }
                    },
                    enemyParty = {
                        {
                            species = "BLASTOISE", 
                            fusionSpecies = "FERALIGATR",
                            level = 58,
                            shiny = false
                        }
                    }
                }
            }
            
            -- Process both Pokemon through fusion appearance
            local playerAppearance = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance",
                Data = json.encode({
                    gameState = {
                        pokemon = battleSetup.battle.playerParty[1],
                        battle = battleSetup.battle
                    },
                    parameters = {appearanceType = "battle"}
                })
            })
            
            local enemyAppearance = aosLocal.send(processes.fusionForm, {
                Action = "GenerateFusionAppearance", 
                Data = json.encode({
                    gameState = {
                        pokemon = battleSetup.battle.enemyParty[1],
                        battle = battleSetup.battle
                    },
                    parameters = {appearanceType = "battle"}
                })
            })
            
            assert.is_equal("SaveState", playerAppearance.Action)
            assert.is_equal("SaveState", enemyAppearance.Action)
            
            local playerData = json.decode(playerAppearance.Data)
            local enemyData = json.decode(enemyAppearance.Data)
            
            -- Both should have valid battle appearance data
            assert.is_not_nil(playerData.fusionAppearance.spriteKeys)
            assert.is_not_nil(enemyData.fusionAppearance.spriteKeys)
        end)
        
        it("should coordinate with multiple fusion processes", function()
            -- Test scenario with multiple fusion operations
            local fusionQueue = {
                {
                    operation = "appearance",
                    pokemon = {species = "PIKACHU", fusionSpecies = "RAICHU"}
                },
                {
                    operation = "calculation", 
                    pokemon = {species = "CHARIZARD", fusionSpecies = "DRAGONITE"}
                },
                {
                    operation = "appearance",
                    pokemon = {species = "BULBASAUR", fusionSpecies = "VENOMOTH"}
                }
            }
            
            local results = {}
            
            for i, fusion in ipairs(fusionQueue) do
                local gameState = {
                    pokemon = fusion.pokemon,
                    battle = {battleSeed = "queue_test_" .. i}
                }
                
                if fusion.operation == "appearance" then
                    local result = aosLocal.send(processes.fusionForm, {
                        Action = "GenerateFusionAppearance",
                        Data = json.encode({gameState = gameState, parameters = {}})
                    })
                    table.insert(results, result)
                elseif fusion.operation == "calculation" then
                    local result = aosLocal.send(processes.fusionCalc, {
                        Action = "CalculateFusionStats",
                        Data = json.encode({gameState = gameState, parameters = {}})
                    })
                    table.insert(results, result)
                end
            end
            
            -- All operations should complete successfully
            assert.is_equal(3, #results)
            for _, result in ipairs(results) do
                assert.is_not_nil(result)
            end
        end)
    end)
    
    describe("Performance and Load Testing", function()
        it("should handle high-volume fusion appearance requests", function()
            local startTime = os.clock()
            local requestCount = 20
            local successCount = 0
            
            for i = 1, requestCount do
                local gameState = {
                    pokemon = {
                        species = "SPECIES_" .. (i % 10),
                        fusionSpecies = "FUSION_" .. (i % 8),
                        level = 50
                    },
                    battle = {battleSeed = "load_test_" .. i}
                }
                
                local result = aosLocal.send(processes.fusionForm, {
                    Action = "GenerateFusionAppearance",
                    Data = json.encode({gameState = gameState, parameters = {}})
                })
                
                if result and result.Action == "SaveState" then
                    successCount = successCount + 1
                end
            end
            
            local endTime = os.clock()
            local totalTime = endTime - startTime
            
            -- Should complete all requests successfully
            assert.is_equal(requestCount, successCount)
            
            -- Should complete within reasonable time (less than 10 seconds)
            assert.is_true(totalTime < 10)
            
            print(string.format("Processed %d requests in %.2f seconds (%.2f req/sec)", 
                requestCount, totalTime, requestCount / totalTime))
        end)
    end)
end)

print("Fusion Form Engine integration tests completed")