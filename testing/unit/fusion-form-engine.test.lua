-- Unit Tests for Fusion Form Engine Process
-- Tests fusion appearance generation functionality

local aolite = require('aolite')
local json = require('json')

-- Initialize test environment
aolite.start()

-- Load the fusion form engine process
local fusion_form_engine = aolite.load('./processes/fusion-form-engine.lua')

describe("Fusion Form Engine Tests", function()
    
    beforeEach(function()
        -- Reset process state before each test
        aolite.reset(fusion_form_engine)
    end)
    
    describe("Process Initialization", function()
        it("should initialize with correct state", function()
            assert.is_not_nil(fusion_form_engine)
            -- Process should load without errors
        end)
        
        it("should respond to Ping", function()
            local result = aolite.send(fusion_form_engine, {
                Action = "Ping",
                From = "test_sender"
            })
            
            assert.is_equal("Pong", result.Action)
            assert.is_not_nil(result.Data)
        end)
        
        it("should provide ADP v1.0 Info", function()
            local result = aolite.send(fusion_form_engine, {
                Action = "Info",
                From = "test_sender"
            })
            
            assert.is_equal("SaveState", result.Action)
            local info = json.decode(result.Data)
            assert.is_equal("1.0", info.process.adpVersion)
            assert.is_equal("Fusion Form Engine", info.process.name)
        end)
    end)
    
    describe("Fusion Appearance Generation", function()
        it("should generate fusion appearance for basic Pokemon", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    formIndex = 0,
                    shiny = false,
                    variant = 0,
                    gender = "MALE",
                    fusionSpecies = "RAICHU",
                    fusionFormIndex = 0,
                    fusionShiny = false,
                    fusionVariant = 0,
                    fusionGender = "MALE"
                },
                battle = {
                    battleSeed = "12345",
                    rngCounter = 0
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "GenerateFusionAppearance",
                From = "test_sender",
                Data = json.encode({
                    gameState = gameState,
                    parameters = {
                        appearanceType = "full",
                        generationMethod = "palette_blend",
                        precisionLevel = "exact"
                    }
                })
            })
            
            assert.is_equal("SaveState", result.Action)
            assert.is_equal("true", result.Success)
            
            local data = json.decode(result.Data)
            assert.is_not_nil(data.fusionAppearance)
            assert.is_not_nil(data.fusionAppearance.spriteKeys)
            assert.is_not_nil(data.fusionAppearance.colorPalettes)
            
            -- Check sprite key generation
            assert.is_equal("pkmn__PIKACHU", data.fusionAppearance.spriteKeys.base)
            assert.is_equal("pkmn__back__PIKACHU", data.fusionAppearance.spriteKeys.baseBack)
            assert.is_equal("pkmn__RAICHU", data.fusionAppearance.spriteKeys.fusion)
            assert.is_equal("pkmn__back__RAICHU", data.fusionAppearance.spriteKeys.fusionBack)
        end)
        
        it("should handle shiny and variant sprites correctly", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    shiny = true,
                    variant = 1,
                    gender = "FEMALE",
                    fusionSpecies = "RAICHU", 
                    fusionShiny = true,
                    fusionVariant = 2,
                    fusionGender = "FEMALE"
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "GenerateFusionAppearance",
                From = "test_sender",
                Data = json.encode({
                    gameState = gameState,
                    parameters = {}
                })
            })
            
            local data = json.decode(result.Data)
            local spriteKeys = data.fusionAppearance.spriteKeys
            
            -- Check shiny and gender differences
            assert.is_string(spriteKeys.base)
            assert.is_string(spriteKeys.fusion)
            -- Should contain female and shiny indicators
            assert.is_true(string.find(spriteKeys.base, "female__") ~= nil or 
                          string.find(spriteKeys.base, "shiny__") ~= nil)
        end)
        
        it("should include color palette data", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU"
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "GenerateFusionAppearance",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            local colorPalettes = data.fusionAppearance.colorPalettes
            
            assert.is_not_nil(colorPalettes.spriteColors)
            assert.is_not_nil(colorPalettes.fusionSpriteColors)
            assert.is_not_nil(colorPalettes.paletteDeltas)
            assert.is_true(#colorPalettes.spriteColors > 0)
        end)
    end)
    
    describe("Fusion Form Determination", function()
        it("should determine valid fusion form", function()
            local gameState = {
                pokemon = {
                    fusionSpecies = "RAICHU",
                    fusionFormIndex = 1
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "DetermineFusionForm",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            assert.is_equal("SaveState", result.Action)
            local data = json.decode(result.Data)
            
            assert.is_true(data.formValid)
            assert.is_equal("RAICHU", data.fusionSpecies)
            assert.is_number(data.formIndex)
        end)
        
        it("should handle missing fusion species", function()
            local gameState = {
                pokemon = {}
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "DetermineFusionForm", 
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_false(data.formValid)
            assert.is_not_nil(data.error)
        end)
        
        it("should normalize invalid form indices", function()
            local gameState = {
                pokemon = {
                    fusionSpecies = "RAICHU",
                    fusionFormIndex = 99 -- Invalid high form index
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "DetermineFusionForm",
                From = "test_sender", 
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_true(data.formValid)
            assert.is_equal(0, data.formIndex) -- Should normalize to 0
        end)
    end)
    
    describe("Fusion Appearance Validation", function()
        it("should validate complete fusion data", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU",
                    formIndex = 0,
                    fusionFormIndex = 0,
                    variant = 1,
                    fusionVariant = 2
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "ValidateFusionAppearance",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_true(data.appearanceValid)
            assert.is_true(data.constraintsValid)
            assert.is_true(data.precisionAchieved)
            assert.is_equal(0, #data.errors)
        end)
        
        it("should detect missing required fields", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU"
                    -- Missing fusionSpecies
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "ValidateFusionAppearance",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_false(data.appearanceValid)
            assert.is_true(#data.errors > 0)
        end)
        
        it("should detect invalid variant values", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU",
                    variant = -1, -- Invalid
                    fusionVariant = 5 -- Invalid
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "ValidateFusionAppearance",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_false(data.constraintsValid)
            assert.is_true(#data.errors >= 2) -- Both variant errors
        end)
    end)
    
    describe("Complex Appearance Scenario Resolution", function()
        it("should resolve form conflicts", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU"
                }
            }
            
            local complexScenarios = {
                {
                    id = "form_conflict_1",
                    type = "form_conflict",
                    primaryFormIndex = 1
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "ResolveFusionVisuals",
                From = "test_sender",
                Data = json.encode({
                    gameState = gameState,
                    parameters = {complexScenarios = complexScenarios}
                })
            })
            
            local data = json.decode(result.Data)
            assert.is_equal(1, data.scenariosResolved)
            assert.is_equal(1, data.totalScenarios)
            assert.is_equal("primary_form_priority", data.resolutionResults[1].method)
        end)
        
        it("should resolve color conflicts", function()
            local complexScenarios = {
                {
                    type = "color_conflict"
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "ResolveFusionVisuals",
                From = "test_sender",
                Data = json.encode({
                    gameState = {pokemon = {}},
                    parameters = {complexScenarios = complexScenarios}
                })
            })
            
            local data = json.decode(result.Data)
            assert.is_equal("balanced_blend", data.resolutionResults[1].method)
            assert.is_equal(0.5, data.resolutionResults[1].appliedValues.blendRatio)
        end)
    end)
    
    describe("Visual Precision Tracking", function()
        it("should calculate appearance precision", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU"
                },
                battle = {
                    battleSeed = "12345"
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "CalculateAppearancePrecision",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_number(data.colorPrecision)
            assert.is_number(data.formPrecision) 
            assert.is_number(data.overallPrecision)
            assert.is_true(data.colorPrecision >= 0 and data.colorPrecision <= 1)
            assert.is_true(data.formPrecision >= 0 and data.formPrecision <= 1)
            assert.is_not_nil(data.precisionMetrics)
            assert.is_not_nil(data.trackingData)
        end)
        
        it("should track precision history", function()
            local gameState = {
                pokemon = {
                    species = "PIKACHU",
                    fusionSpecies = "RAICHU"
                }
            }
            
            local result = aolite.send(fusion_form_engine, {
                Action = "CalculateAppearancePrecision",
                From = "test_sender",
                Data = json.encode({gameState = gameState, parameters = {}})
            })
            
            local data = json.decode(result.Data)
            assert.is_not_nil(data.trackingData.precisionHistory)
            assert.is_true(#data.trackingData.precisionHistory > 0)
            assert.is_true(data.trackingData.trackingEnabled)
        end)
    end)
    
    describe("Error Handling", function()
        it("should handle malformed JSON data", function()
            local result = aolite.send(fusion_form_engine, {
                Action = "GenerateFusionAppearance",
                From = "test_sender",
                Data = "invalid json"
            })
            
            -- Should not crash, should handle gracefully
            assert.is_not_nil(result)
        end)
        
        it("should handle empty message data", function()
            local result = aolite.send(fusion_form_engine, {
                Action = "GenerateFusionAppearance",
                From = "test_sender"
                -- No Data field
            })
            
            assert.is_equal("SaveState", result.Action)
            -- Should process with empty/default data
        end)
    end)
end)

print("Fusion Form Engine unit tests completed")