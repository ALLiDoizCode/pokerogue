-- Form Persistence Engine Integration Tests
-- Tests multi-process coordination and complete workflow scenarios

describe("Form Persistence Engine Integration", function()
    
    local aolite
    local formPersistenceProcess
    local formChangeProcess
    local moveTransformationProcess
    
    before_each(function()
        aolite = require('aolite')
        
        -- Spawn test processes
        formPersistenceProcess = aolite.spawnProcess("processes/form-persistence-engine.lua")
        
        -- Mock other processes for integration testing
        formChangeProcess = aolite.spawnProcess(function()
            Handlers.add("form-change-response", 
                Handlers.utils.hasMatchingTag("Action", "FormChangeRequest"),
                function(msg)
                    ao.send({
                        Target = msg.From,
                        Action = "FormChangeResult",
                        Success = "true",
                        FormType = msg.FormType
                    })
                end
            )
        end)
        
        moveTransformationProcess = aolite.spawnProcess(function()
            Handlers.add("move-transformation-response",
                Handlers.utils.hasMatchingTag("Action", "MoveTransformationRequest"),
                function(msg)
                    ao.send({
                        Target = msg.From,
                        Action = "MoveTransformationResult", 
                        Success = "true",
                        TransformationType = msg.TransformationType
                    })
                end
            )
        end)
    end)
    
    after_each(function()
        if aolite then
            aolite.killProcess(formPersistenceProcess)
            aolite.killProcess(formChangeProcess)
            aolite.killProcess(moveTransformationProcess)
        end
    end)
    
    describe("Complete Form Persistence Workflow", function()
        
        it("should handle full Mega Evolution persistence cycle", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "3", -- Venusaur
                    currentForm = "base"
                }
            }
            
            -- Step 1: Process Mega Evolution form
            local result1 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "mega",
                Duration = "1",
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result1)
            assert.are.equal("SaveState", result1.Action)
            assert.are.equal("true", result1.Success)
            assert.are.equal("battle_only", result1.PersistenceType)
            
            -- Step 2: Check expiration at battle end
            local updatedGameState = json.decode(result1.Data)
            local result2 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "CheckFormExpiration",
                PokemonId = "test_pokemon_1",
                BattleEnded = "true",
                Data = result1.Data
            })
            
            assert.is_not_nil(result2)
            assert.are.equal("SaveState", result2.Action)
            assert.are.equal("true", result2.FormReverted)
            
            -- Step 3: Save state should revert non-persistent forms
            local result3 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "SaveFormState",
                Data = result1.Data
            })
            
            assert.is_not_nil(result3)
            assert.are.equal("SaveState", result3.Action)
            assert.are.equal("false", result3.FormPersisted)
        end)
        
        it("should handle Hoopa Unbound timed form persistence", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "720", -- Hoopa
                    currentForm = "confined"
                }
            }
            
            -- Step 1: Transform to Unbound form
            local result1 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "unbound",
                Duration = "259200", -- 3 days
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result1)
            assert.are.equal("SaveState", result1.Action)
            assert.are.equal("true", result1.Success)
            assert.are.equal("259200", result1.Duration)
            
            -- Step 2: Save form state (should persist)
            local result2 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "SaveFormState",
                Data = result1.Data
            })
            
            assert.is_not_nil(result2)
            assert.are.equal("SaveState", result2.Action)
            assert.are.equal("true", result2.FormPersisted)
            
            -- Step 3: Load form state (should restore)
            local result3 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "LoadFormState",
                PokemonId = "test_pokemon_1",
                Data = result2.Data
            })
            
            assert.is_not_nil(result3)
            assert.are.equal("SaveState", result3.Action)
            assert.are.equal("true", result3.FormRestored)
            assert.are.equal("unbound", result3.RestoredForm)
        end)
        
        it("should handle Shaymin Sky form conditional persistence", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "492", -- Shaymin
                    currentForm = "land"
                }
            }
            
            -- Step 1: Validate Sky form conditions (day time)
            local result1 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ValidateFormConditions",
                PokemonId = "test_pokemon_1",
                SpeciesId = "492",
                FormType = "sky",
                IsDay = "true",
                IsFrozen = "false"
            })
            
            assert.is_not_nil(result1)
            assert.are.equal("ValidationResult", result1.Action)
            assert.are.equal("true", result1.Valid)
            assert.are.equal("conditional", result1.PersistenceType)
            
            -- Step 2: Process Sky form change
            local result2 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "sky",
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result2)
            assert.are.equal("SaveState", result2.Action)
            assert.are.equal("true", result2.Success)
            
            -- Step 3: Check expiration at night
            local result3 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "CheckFormExpiration",
                PokemonId = "test_pokemon_1",
                IsNight = "true",
                Data = result2.Data
            })
            
            assert.is_not_nil(result3)
            assert.are.equal("SaveState", result3.Action)
            assert.are.equal("true", result3.FormReverted)
        end)
        
        it("should handle Dialga Origin form item dependency", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "483", -- Dialga
                    currentForm = "altered",
                    heldItem = "ADAMANT_ORB"
                }
            }
            
            -- Step 1: Validate Origin form with Adamant Orb
            local result1 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ValidateFormConditions",
                PokemonId = "test_pokemon_1",
                SpeciesId = "483",
                FormType = "origin",
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result1)
            assert.are.equal("ValidationResult", result1.Action)
            assert.are.equal("true", result1.Valid)
            assert.are.equal("permanent", result1.PersistenceType)
            
            -- Step 2: Process Origin form
            local result2 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "origin",
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result2)
            assert.are.equal("SaveState", result2.Action)
            assert.are.equal("true", result2.Success)
            
            -- Step 3: Save and load cycle
            local result3 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "SaveFormState",
                Data = result2.Data
            })
            
            assert.is_not_nil(result3)
            assert.are.equal("SaveState", result3.Action)
            assert.are.equal("true", result3.FormPersisted)
            
            local result4 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "LoadFormState",
                PokemonId = "test_pokemon_1",
                Data = result3.Data
            })
            
            assert.is_not_nil(result4)
            assert.are.equal("SaveState", result4.Action)
            assert.are.equal("true", result4.FormRestored)
            assert.are.equal("origin", result4.RestoredForm)
        end)
        
        it("should handle Castform weather form transitions", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "351", -- Castform
                    currentForm = "normal"
                }
            }
            
            -- Step 1: Validate sunny form conditions
            local result1 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ValidateFormConditions",
                PokemonId = "test_pokemon_1",
                SpeciesId = "351",
                FormType = "sunny",
                Weather = "sunny"
            })
            
            assert.is_not_nil(result1)
            assert.are.equal("ValidationResult", result1.Action)
            assert.are.equal("true", result1.Valid)
            
            -- Step 2: Process sunny form
            local result2 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "sunny",
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result2)
            assert.are.equal("SaveState", result2.Action)
            assert.are.equal("true", result2.Success)
            
            -- Step 3: Weather change should trigger reversion
            local result3 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "CheckFormExpiration",
                PokemonId = "test_pokemon_1",
                WeatherChanged = "true",
                Data = result2.Data
            })
            
            assert.is_not_nil(result3)
            assert.are.equal("SaveState", result3.Action)
            assert.are.equal("true", result3.FormReverted)
        end)
        
    end)
    
    describe("Cross-Process Integration", function()
        
        it("should coordinate with Form Change Engine", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "492",
                    currentForm = "land"
                }
            }
            
            -- Step 1: Request form change through persistence engine
            local persistenceResult = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ValidateFormConditions",
                PokemonId = "test_pokemon_1",
                SpeciesId = "492",
                FormType = "sky",
                IsDay = "true",
                IsFrozen = "false"
            })
            
            assert.are.equal("ValidationResult", persistenceResult.Action)
            assert.are.equal("true", persistenceResult.Valid)
            
            -- Step 2: Mock coordination with Form Change Engine
            local formChangeResult = aolite.send({
                Process = formChangeProcess,
                Target = formChangeProcess,
                Action = "FormChangeRequest",
                FormType = "sky",
                ValidationResult = persistenceResult.Valid
            })
            
            assert.are.equal("FormChangeResult", formChangeResult.Action)
            assert.are.equal("true", formChangeResult.Success)
        end)
        
        it("should coordinate with Move Transformation Engine", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "681", -- Aegislash
                    currentForm = "shield"
                }
            }
            
            -- Step 1: Validate battle-only form through persistence engine
            local persistenceResult = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "blade",
                Duration = "1",
                Data = json.encode(gameState)
            })
            
            assert.are.equal("SaveState", persistenceResult.Action)
            assert.are.equal("true", persistenceResult.Success)
            
            -- Step 2: Mock coordination with Move Transformation Engine
            local transformationResult = aolite.send({
                Process = moveTransformationProcess,
                Target = moveTransformationProcess,
                Action = "MoveTransformationRequest",
                TransformationType = "stance_change",
                PersistenceData = persistenceResult.Data
            })
            
            assert.are.equal("MoveTransformationResult", transformationResult.Action)
            assert.are.equal("true", transformationResult.Success)
        end)
        
    end)
    
    describe("Error Recovery and Edge Cases", function()
        
        it("should handle corrupted persistence data gracefully", function()
            local result = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "LoadFormState",
                PokemonId = "test_pokemon_1",
                Data = "invalid_json_data"
            })
            
            assert.is_not_nil(result)
            assert.are.equal("Error", result.Action)
        end)
        
        it("should handle timer expiration edge cases", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "720",
                    currentForm = "unbound",
                    formPersistenceData = {
                        type = "timed",
                        duration = 0, -- Already expired
                        startTime = 1000,
                        expirationCondition = "timer_expiry",
                        revertToForm = "confined"
                    }
                }
            }
            
            local result = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "CheckFormExpiration",
                PokemonId = "test_pokemon_1",
                Data = json.encode(gameState)
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            assert.are.equal("true", result.FormReverted)
        end)
        
        it("should handle simultaneous form change conflicts", function()
            local gameState = {
                pokemon = {
                    id = "test_pokemon_1",
                    speciesId = "492",
                    currentForm = "land"
                }
            }
            
            -- Attempt multiple form changes simultaneously
            local result1 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "sky",
                Data = json.encode(gameState)
            })
            
            local result2 = aolite.send({
                Process = formPersistenceProcess,
                Target = formPersistenceProcess,
                Action = "ProcessFormPersistence",
                PokemonId = "test_pokemon_1",
                FormType = "mega",
                Data = json.encode(gameState)
            })
            
            -- Both should succeed but with different priorities
            assert.is_not_nil(result1)
            assert.is_not_nil(result2)
            assert.are.equal("SaveState", result1.Action)
            assert.are.equal("SaveState", result2.Action)
        end)
        
    end)
    
    describe("Performance and Scale", function()
        
        it("should handle multiple Pokemon form persistence efficiently", function()
            local startTime = os.clock()
            
            for i = 1, 10 do
                local gameState = {
                    pokemon = {
                        id = "test_pokemon_" .. i,
                        speciesId = "492",
                        currentForm = "land"
                    }
                }
                
                local result = aolite.send({
                    Process = formPersistenceProcess,
                    Target = formPersistenceProcess,
                    Action = "ProcessFormPersistence",
                    PokemonId = "test_pokemon_" .. i,
                    FormType = "sky",
                    Data = json.encode(gameState)
                })
                
                assert.are.equal("SaveState", result.Action)
                assert.are.equal("true", result.Success)
            end
            
            local endTime = os.clock()
            local executionTime = endTime - startTime
            
            -- Should complete within reasonable time (5 seconds as per requirements)
            assert.is_true(executionTime < 5.0)
        end)
        
    end)
    
end)

print("Form Persistence Engine integration tests loaded")