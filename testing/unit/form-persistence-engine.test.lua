-- Form Persistence Engine Unit Tests
-- Tests for duration tracking, save/load persistence, reversion logic, and priority resolution

-- Mock testing framework to be compatible with aolite
local function describe(name, fn)
    print("🧪 Running test suite: " .. name)
    print("--------------------------------------------------")
    fn()
    print("")
end

local function it(name, fn) 
    local success, err = pcall(fn)
    if success then
        print("  ✅ " .. name)
    else
        print("  ❌ " .. name .. " - " .. tostring(err))
    end
end

local function before_each(fn)
    setupFn = fn
end

-- Basic assertion library
local assert = {
    is_not_nil = function(val)
        if val == nil then error("Expected value to not be nil") end
    end,
    are = {
        equal = function(expected, actual)
            if expected ~= actual then 
                error("Expected " .. tostring(expected) .. " but got " .. tostring(actual))
            end
        end
    }
}

describe("Form Persistence Engine", function()
    
    local formPersistenceEngine
    local testGameState
    local testPokemon
    
    before_each(function()
        -- Reset test environment
        ao = {
            send = function(msg) 
                print("Test send:", msg.Action, msg.Target)
                lastSentMessage = msg
            end,
            id = "test_process_id"
        }
        
        msg = {
            From = "test_sender",
            Timestamp = 1234567890
        }
        
        json = {
            encode = function(obj)
                return "{\"encoded\":true}"
            end,
            decode = function(str)
                if str == "" or str == "{}" then
                    return {}
                end
                return {decoded = true, data = str}
            end
        }
        
        State = {
            initialized = true,
            formPersistenceTracking = {},
            activeTimers = {},
            persistentForms = {}
        }
        
        testPokemon = {
            id = "test_pokemon_1",
            speciesId = "492", -- Shaymin
            currentForm = "land",
            heldItem = nil
        }
        
        testGameState = {
            pokemon = testPokemon,
            persistentForms = {}
        }
        
        lastSentMessage = nil
        
        -- Load the process
        local file = io.open("processes/form-persistence-engine.lua", "r")
        if file then
            local content = file:read("*all")
            file:close()
            load(content)()
        end
    end)
    
    describe("Duration Tracking", function()
        
        it("should track temporary battle-only forms", function()
            msg.Action = "ProcessFormPersistence"
            msg.PokemonId = "test_pokemon_1"
            msg.FormType = "mega"
            msg.Duration = "1"
            msg.Data = json.encode(testGameState)
            
            -- Trigger mega evolution persistence
            Handlers.find("process-form-persistence").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.Success)
            assert.are.equal("battle_only", lastSentMessage.PersistenceType)
        end)
        
        it("should track timed forms with precise duration", function()
            msg.Action = "ProcessFormPersistence"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "720" -- Hoopa
            msg.FormType = "unbound"
            msg.Duration = "259200" -- 3 days
            msg.Data = json.encode(testGameState)
            
            -- Trigger Hoopa Unbound form
            Handlers.find("process-form-persistence").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.Success)
            assert.are.equal("259200", lastSentMessage.Duration)
        end)
        
        it("should track conditional forms with weather dependency", function()
            msg.Action = "ProcessFormPersistence"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "351" -- Castform
            msg.FormType = "sunny"
            msg.Data = json.encode(testGameState)
            
            -- Trigger sunny Castform form
            Handlers.find("process-form-persistence").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.Success)
        end)
        
        it("should reject invalid form types", function()
            msg.Action = "ProcessFormPersistence"
            msg.PokemonId = "test_pokemon_1"
            msg.FormType = "invalid_form"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("process-form-persistence").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("Error", lastSentMessage.Action)
        end)
        
    end)
    
    describe("Expiration Logic", function()
        
        it("should detect battle-end expiration for Mega Evolution", function()
            -- Set up pokemon with mega form
            testPokemon.currentForm = "mega"
            testPokemon.formPersistenceData = {
                type = "battle_only",
                expirationCondition = "battle_end",
                revertToForm = "base"
            }
            
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.BattleEnded = "true"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormReverted)
        end)
        
        it("should detect timer expiration for Hoopa Unbound", function()
            -- Set up pokemon with expired timed form
            testPokemon.currentForm = "unbound"
            testPokemon.formPersistenceData = {
                type = "timed",
                duration = 10, -- Short duration for test
                startTime = 1000,
                expirationCondition = "timer_expiry",
                revertToForm = "confined"
            }
            
            msg.Timestamp = 2000 -- Time passed > duration
            
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormReverted)
        end)
        
        it("should detect night-time reversion for Shaymin Sky", function()
            testPokemon.currentForm = "sky"
            testPokemon.formPersistenceData = {
                type = "conditional",
                expirationCondition = "night_time_or_frozen",
                revertToForm = "land"
            }
            
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.IsNight = "true"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormReverted)
        end)
        
        it("should detect weather change for Castform", function()
            testPokemon.speciesId = "351"
            testPokemon.currentForm = "sunny"
            testPokemon.formPersistenceData = {
                type = "conditional",
                expirationCondition = "weather_change_or_battle_end",
                revertToForm = "normal"
            }
            
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "test_pokemon_1"
            msg.WeatherChanged = "true"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("check-form-expiration").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormReverted)
        end)
        
    end)
    
    describe("Save/Load Persistence", function()
        
        it("should persist permanent forms through save", function()
            testPokemon.speciesId = "483" -- Dialga
            testPokemon.currentForm = "origin"
            testPokemon.heldItem = "ADAMANT_ORB"
            testPokemon.formPersistenceData = {
                type = "permanent",
                persistThroughSave = true,
                requiredItem = "ADAMANT_ORB"
            }
            
            msg.Action = "SaveFormState"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("save-form-state").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormPersisted)
        end)
        
        it("should revert non-persistent forms during save", function()
            testPokemon.currentForm = "mega"
            testPokemon.formPersistenceData = {
                type = "battle_only",
                persistThroughSave = false
            }
            
            msg.Action = "SaveFormState"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("save-form-state").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("false", lastSentMessage.FormPersisted)
        end)
        
        it("should restore persistent forms on load", function()
            testGameState.persistentForms = {
                ["test_pokemon_1"] = {
                    form = "origin",
                    persistenceData = {
                        type = "permanent",
                        requiredItem = "ADAMANT_ORB"
                    },
                    timestamp = 1234567800
                }
            }
            testPokemon.heldItem = "ADAMANT_ORB"
            
            msg.Action = "LoadFormState"
            msg.PokemonId = "test_pokemon_1"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("load-form-state").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormRestored)
        end)
        
        it("should fail to restore forms when required item missing", function()
            testGameState.persistentForms = {
                ["test_pokemon_1"] = {
                    form = "origin",
                    persistenceData = {
                        type = "permanent",
                        requiredItem = "ADAMANT_ORB"
                    },
                    timestamp = 1234567800
                }
            }
            testPokemon.heldItem = nil -- Missing required item
            
            msg.Action = "LoadFormState"
            msg.PokemonId = "test_pokemon_1"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("load-form-state").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("false", lastSentMessage.FormRestored)
            assert.are.equal("Required item missing", lastSentMessage.Reason)
        end)
        
    end)
    
    describe("Form Reversion", function()
        
        it("should manually revert forms", function()
            testPokemon.currentForm = "sky"
            testPokemon.formPersistenceData = {
                revertToForm = "land"
            }
            
            msg.Action = "RevertForm"
            msg.PokemonId = "test_pokemon_1"
            msg.CancellationTrigger = "manual"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("revert-form").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.FormReverted)
            assert.are.equal("manual", lastSentMessage.CancellationTrigger)
        end)
        
        it("should handle reversion when no active form", function()
            testPokemon.currentForm = "base"
            testPokemon.formPersistenceData = nil
            
            msg.Action = "RevertForm"
            msg.PokemonId = "test_pokemon_1"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("revert-form").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.are.equal("false", lastSentMessage.FormReverted)
            assert.are.equal("No active form to revert", lastSentMessage.Reason)
        end)
        
    end)
    
    describe("Condition Validation", function()
        
        it("should validate Shaymin Sky form day-time requirement", function()
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "492"
            msg.FormType = "sky"
            msg.IsDay = "true"
            msg.IsFrozen = "false"
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("ValidationResult", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.Valid)
        end)
        
        it("should reject Shaymin Sky form at night", function()
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "492"
            msg.FormType = "sky"
            msg.IsDay = "false"
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("ValidationResult", lastSentMessage.Action)
            assert.are.equal("false", lastSentMessage.Valid)
        end)
        
        it("should validate Dialga Origin form with Adamant Orb", function()
            testPokemon.speciesId = "483"
            testPokemon.heldItem = "ADAMANT_ORB"
            
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "483"
            msg.FormType = "origin"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("ValidationResult", lastSentMessage.Action)
            assert.are.equal("true", lastSentMessage.Valid)
        end)
        
        it("should reject Dialga Origin form without Adamant Orb", function()
            testPokemon.speciesId = "483"
            testPokemon.heldItem = nil
            
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "483"
            msg.FormType = "origin"
            msg.Data = json.encode(testGameState)
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("ValidationResult", lastSentMessage.Action)
            assert.are.equal("false", lastSentMessage.Valid)
        end)
        
    end)
    
    describe("Priority Resolution", function()
        
        it("should return priority information in validation", function()
            msg.Action = "ValidateFormConditions"
            msg.PokemonId = "test_pokemon_1"
            msg.SpeciesId = "492"
            msg.FormType = "sky"
            msg.IsDay = "true"
            msg.IsFrozen = "false"
            
            Handlers.find("validate-form-conditions").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("ValidationResult", lastSentMessage.Action)
            assert.are.equal("conditional", lastSentMessage.PersistenceType)
            assert.are.equal("3", lastSentMessage.Priority)
        end)
        
    end)
    
    describe("Error Handling", function()
        
        it("should require PokemonId for persistence", function()
            msg.Action = "ProcessFormPersistence"
            msg.FormType = "mega"
            
            Handlers.find("process-form-persistence").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("Error", lastSentMessage.Action)
            assert.is_true(string.find(lastSentMessage.Error, "PokemonId") ~= nil)
        end)
        
        it("should require FormType for persistence", function()
            msg.Action = "ProcessFormPersistence"
            msg.PokemonId = "test_pokemon_1"
            
            Handlers.find("process-form-persistence").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("Error", lastSentMessage.Action)
            assert.is_true(string.find(lastSentMessage.Error, "FormType") ~= nil)
        end)
        
        it("should handle missing pokemon data gracefully", function()
            msg.Action = "CheckFormExpiration"
            msg.PokemonId = "missing_pokemon"
            msg.Data = json.encode({})
            
            Handlers.find("check-form-expiration").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("Error", lastSentMessage.Action)
        end)
        
    end)
    
    describe("ADP v1.0 Compliance", function()
        
        it("should respond to Info handler", function()
            msg.Action = "Info"
            
            Handlers.find("info").handle(msg)
            
            assert.is_not_nil(lastSentMessage)
            assert.are.equal("SaveState", lastSentMessage.Action)
            assert.is_not_nil(lastSentMessage.Data)
        end)
        
    end)
    
end)

print("Form Persistence Engine unit tests loaded")