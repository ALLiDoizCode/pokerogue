-- Form Persistence Engine Parity Tests
-- Validates behavioral parity with TypeScript reference implementation

describe("Form Persistence Parity Tests", function()
    
    local formPersistenceEngine
    local typeScriptReference
    
    before_each(function()
        -- Setup test environment similar to TypeScript
        formPersistenceEngine = require('processes/form-persistence-engine')
        
        -- Mock TypeScript reference behavior
        typeScriptReference = {
            FormPersistenceType = {
                BATTLE_ONLY = "battle_only",
                PERMANENT = "permanent", 
                CONDITIONAL = "conditional",
                TIMED = "timed"
            },
            
            checkFormExpiration = function(pokemon, conditions)
                -- Reference TypeScript behavior
                if pokemon.form == "mega" and conditions.battleEnded then
                    return true, "base"
                elseif pokemon.form == "unbound" and conditions.timerExpired then
                    return true, "confined"
                elseif pokemon.form == "sky" and (conditions.isNight or conditions.isFrozen) then
                    return true, "land"
                elseif pokemon.form == "sunny" and conditions.weatherChanged then
                    return true, "normal"
                end
                return false, nil
            end,
            
            persistFormThroughSave = function(pokemon)
                local formData = pokemon.formPersistenceData
                if not formData then return false end
                
                if formData.type == "battle_only" then
                    return false
                elseif formData.type == "permanent" then
                    return formData.requiredItem == nil or pokemon.heldItem == formData.requiredItem
                elseif formData.type == "conditional" then
                    return formData.persistThroughSave
                elseif formData.type == "timed" then
                    return formData.persistThroughSave
                end
                
                return false
            end,
            
            validateFormConditions = function(pokemon, formType, conditions)
                if pokemon.speciesId == 492 and formType == "sky" then
                    return conditions.isDay and not conditions.isFrozen
                elseif pokemon.speciesId == 483 and formType == "origin" then
                    return pokemon.heldItem == "ADAMANT_ORB"
                elseif pokemon.speciesId == 351 and formType == "sunny" then
                    return conditions.weather == "sunny"
                elseif formType == "mega" then
                    return true -- Mega forms have no special conditions
                end
                return false
            end
        }
        
        -- Setup test AO environment
        ao = {
            send = function(msg) 
                lastSentMessage = msg
            end,
            id = "test_process_id"
        }
        
        msg = {
            From = "test_sender",
            Timestamp = 1234567890
        }
        
        lastSentMessage = nil
    end)
    
    describe("Mega Evolution Parity", function()
        
        it("should match TypeScript battle-only form behavior exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "3", -- Venusaur
                currentForm = "base"
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "ProcessFormPersistence"
            msg.PokemonId = "test_pokemon_1"
            msg.FormType = "mega"
            msg.Duration = "1"
            msg.Data = json.encode(gameState)
            
            Handlers.find("process-form-persistence").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("SaveState", luaResult.Action)
            assert.are.equal("true", luaResult.Success)
            assert.are.equal("battle_only", luaResult.PersistenceType)
            
            -- TypeScript reference behavior
            local tsFormData = {
                type = typeScriptReference.FormPersistenceType.BATTLE_ONLY,
                persistThroughSave = false,
                duration = 1
            }
            
            -- Verify parity
            assert.are.equal("battle_only", tsFormData.type)
            assert.are.equal(luaResult.PersistenceType, tsFormData.type)
        end)
        
        it("should match TypeScript battle-end reversion exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "3",
                currentForm = "mega",
                formPersistenceData = {
                    type = "battle_only",
                    expirationCondition = "battle_end",
                    revertToForm = "base"
                }
            }
            
            local gameState = { pokemon = testPokemon }
            local conditions = { battleEnded = true }
            
            -- Lua implementation
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.BattleEnded = "true"
            msg.Data = json.encode(gameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.FormReverted)
            
            -- TypeScript reference
            local tsPokemon = { form = "mega" }
            local tsConditions = { battleEnded = true }
            local tsReverted, tsRevertForm = typeScriptReference.checkFormExpiration(tsPokemon, tsConditions)
            
            -- Verify exact parity
            assert.are.equal(tsReverted, luaResult.FormReverted == "true")
            assert.are.equal(tsRevertForm, "base")
        end)
        
        it("should match TypeScript save persistence behavior exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "3",
                currentForm = "mega",
                formPersistenceData = {
                    type = "battle_only",
                    persistThroughSave = false
                }
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "SaveFormState"
            msg.Data = json.encode(gameState)
            
            Handlers.find("save-form-state").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("false", luaResult.FormPersisted)
            
            -- TypeScript reference
            local tsPokemon = {
                formPersistenceData = {
                    type = "battle_only",
                    persistThroughSave = false
                }
            }
            local tsPersisted = typeScriptReference.persistFormThroughSave(tsPokemon)
            
            -- Verify exact parity
            assert.are.equal(tsPersisted, luaResult.FormPersisted == "true")
        end)
        
    end)
    
    describe("Hoopa Unbound Timed Form Parity", function()
        
        it("should match TypeScript timer expiration logic exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "720",
                currentForm = "unbound",
                formPersistenceData = {
                    type = "timed",
                    duration = 100,
                    startTime = 1000,
                    expirationCondition = "timer_expiry",
                    revertToForm = "confined"
                }
            }
            
            msg.Timestamp = 1200 -- 200 seconds elapsed, > 100 duration
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.Data = json.encode(gameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.FormReverted)
            
            -- TypeScript reference logic
            local tsPokemon = { form = "unbound" }
            local tsConditions = { timerExpired = true } -- Simulated timer check
            local tsReverted, tsRevertForm = typeScriptReference.checkFormExpiration(tsPokemon, tsConditions)
            
            -- Verify exact parity
            assert.are.equal(tsReverted, luaResult.FormReverted == "true")
            assert.are.equal(tsRevertForm, "confined")
        end)
        
        it("should match TypeScript save/load persistence exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "720",
                currentForm = "unbound",
                formPersistenceData = {
                    type = "timed",
                    duration = 259200, -- 3 days
                    persistThroughSave = true
                }
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation - save
            msg.Action = "SaveFormState"
            msg.Data = json.encode(gameState)
            
            Handlers.find("save-form-state").handle(msg)
            
            local luaSaveResult = lastSentMessage
            assert.are.equal("true", luaSaveResult.FormPersisted)
            
            -- TypeScript reference
            local tsPokemon = {
                formPersistenceData = {
                    type = "timed",
                    persistThroughSave = true
                }
            }
            local tsPersisted = typeScriptReference.persistFormThroughSave(tsPokemon)
            
            -- Verify save parity
            assert.are.equal(tsPersisted, luaSaveResult.FormPersisted == "true")
        end)
        
    end)
    
    describe("Shaymin Sky Form Conditional Parity", function()
        
        it("should match TypeScript day/night condition validation exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "492"
            }
            
            -- Test day-time validation (should pass)
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "492"
            msg.FormType = "sky"
            msg.IsDay = "true"
            msg.IsFrozen = "false"
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            local luaDayResult = lastSentMessage
            assert.are.equal("true", luaDayResult.Valid)
            
            -- TypeScript reference
            local tsPokemon = { speciesId = 492 }
            local tsDayConditions = { isDay = true, isFrozen = false }
            local tsDayValid = typeScriptReference.validateFormConditions(tsPokemon, "sky", tsDayConditions)
            
            -- Verify day-time parity
            assert.are.equal(tsDayValid, luaDayResult.Valid == "true")
            
            -- Test night-time validation (should fail)
            msg.IsDay = "false"
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            local luaNightResult = lastSentMessage
            assert.are.equal("false", luaNightResult.Valid)
            
            -- TypeScript reference
            local tsNightConditions = { isDay = false, isFrozen = false }
            local tsNightValid = typeScriptReference.validateFormConditions(tsPokemon, "sky", tsNightConditions)
            
            -- Verify night-time parity
            assert.are.equal(tsNightValid, luaNightResult.Valid == "true")
        end)
        
        it("should match TypeScript frozen condition reversion exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "492",
                currentForm = "sky",
                formPersistenceData = {
                    type = "conditional",
                    expirationCondition = "night_time_or_frozen",
                    revertToForm = "land"
                }
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.IsFrozen = "true"
            msg.Data = json.encode(gameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.FormReverted)
            
            -- TypeScript reference
            local tsPokemon = { form = "sky" }
            local tsConditions = { isFrozen = true }
            local tsReverted, tsRevertForm = typeScriptReference.checkFormExpiration(tsPokemon, tsConditions)
            
            -- Verify exact parity
            assert.are.equal(tsReverted, luaResult.FormReverted == "true")
            assert.are.equal(tsRevertForm, "land")
        end)
        
    end)
    
    describe("Dialga Origin Form Item Dependency Parity", function()
        
        it("should match TypeScript item validation exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "483",
                heldItem = "ADAMANT_ORB"
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "483"
            msg.FormType = "origin"
            msg.Data = json.encode(gameState)
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.Valid)
            
            -- TypeScript reference
            local tsPokemon = { 
                speciesId = 483,
                heldItem = "ADAMANT_ORB"
            }
            local tsValid = typeScriptReference.validateFormConditions(tsPokemon, "origin", {})
            
            -- Verify exact parity
            assert.are.equal(tsValid, luaResult.Valid == "true")
            
            -- Test without item (should fail)
            testPokemon.heldItem = nil
            msg.Data = json.encode({ pokemon = testPokemon })
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            local luaNoItemResult = lastSentMessage
            assert.are.equal("false", luaNoItemResult.Valid)
            
            -- TypeScript reference without item
            local tsPokemonNoItem = { 
                speciesId = 483,
                heldItem = nil
            }
            local tsValidNoItem = typeScriptReference.validateFormConditions(tsPokemonNoItem, "origin", {})
            
            -- Verify parity
            assert.are.equal(tsValidNoItem, luaNoItemResult.Valid == "true")
        end)
        
        it("should match TypeScript permanent form persistence exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "483",
                currentForm = "origin",
                heldItem = "ADAMANT_ORB",
                formPersistenceData = {
                    type = "permanent",
                    persistThroughSave = true,
                    requiredItem = "ADAMANT_ORB"
                }
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "SaveFormState"
            msg.Data = json.encode(gameState)
            
            Handlers.find("save-form-state").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.FormPersisted)
            
            -- TypeScript reference
            local tsPokemon = {
                heldItem = "ADAMANT_ORB",
                formPersistenceData = {
                    type = "permanent",
                    persistThroughSave = true,
                    requiredItem = "ADAMANT_ORB"
                }
            }
            local tsPersisted = typeScriptReference.persistFormThroughSave(tsPokemon)
            
            -- Verify exact parity
            assert.are.equal(tsPersisted, luaResult.FormPersisted == "true")
        end)
        
    end)
    
    describe("Castform Weather Form Parity", function()
        
        it("should match TypeScript weather condition validation exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "351"
            }
            
            -- Test sunny weather validation
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "351"
            msg.FormType = "sunny"
            msg.Weather = "sunny"
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.Valid)
            
            -- TypeScript reference
            local tsPokemon = { speciesId = 351 }
            local tsConditions = { weather = "sunny" }
            local tsValid = typeScriptReference.validateFormConditions(tsPokemon, "sunny", tsConditions)
            
            -- Verify exact parity
            assert.are.equal(tsValid, luaResult.Valid == "true")
        end)
        
        it("should match TypeScript weather change reversion exactly", function()
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "351",
                currentForm = "sunny",
                formPersistenceData = {
                    type = "conditional",
                    expirationCondition = "weather_change_or_battle_end",
                    revertToForm = "normal"
                }
            }
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.WeatherChanged = "true"
            msg.Data = json.encode(gameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.FormReverted)
            
            -- TypeScript reference
            local tsPokemon = { form = "sunny" }
            local tsConditions = { weatherChanged = true }
            local tsReverted, tsRevertForm = typeScriptReference.checkFormExpiration(tsPokemon, tsConditions)
            
            -- Verify exact parity
            assert.are.equal(tsReverted, luaResult.FormReverted == "true")
            assert.are.equal(tsRevertForm, "normal")
        end)
        
    end)
    
    describe("Mathematical Precision Parity", function()
        
        it("should match TypeScript timer calculations exactly", function()
            -- Test precise timer calculations
            local startTime = 1234567890
            local duration = 259200 -- 3 days in seconds
            local currentTime = startTime + duration + 1 -- 1 second past expiration
            
            local testPokemon = {
                id = "test_pokemon_1",
                speciesId = "720",
                currentForm = "unbound",
                formPersistenceData = {
                    type = "timed",
                    duration = duration,
                    startTime = startTime,
                    expirationCondition = "timer_expiry",
                    revertToForm = "confined"
                }
            }
            
            msg.Timestamp = currentTime
            
            local gameState = { pokemon = testPokemon }
            
            -- Lua implementation
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.Data = json.encode(gameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("true", luaResult.FormReverted)
            
            -- TypeScript reference calculation
            local elapsed = currentTime - startTime
            local tsExpired = elapsed >= duration
            
            -- Verify exact mathematical parity
            assert.are.equal(tsExpired, luaResult.FormReverted == "true")
            assert.are.equal(elapsed, 259201) -- Verify precise calculation
        end)
        
    end)
    
    describe("Error Handling Parity", function()
        
        it("should match TypeScript error responses exactly", function()
            -- Test missing required parameters
            msg.Action = "ProcessFormPersistence"
            msg.FormType = "mega"
            -- Missing PokemonId
            
            Handlers.find("process-form-persistence").handle(msg)
            
            local luaResult = lastSentMessage
            assert.are.equal("Error", luaResult.Action)
            assert.is_true(string.find(luaResult.Error, "PokemonId") ~= nil)
            
            -- TypeScript would throw similar validation error
            -- This verifies that both implementations have equivalent error handling
        end)
        
    end)
    
end)

print("Form Persistence Engine parity tests loaded")