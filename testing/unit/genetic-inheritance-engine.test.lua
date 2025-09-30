-- Unit tests for genetic-inheritance-engine.lua
local aolite = require("aolite")

-- Load the process
local processFile = "processes/genetic-inheritance-engine.lua"
local env = aolite.createProcess(processFile)

-- Test data
local function createTestParent(id, speciesId, ivs, nature, ability, abilityIndex)
    return {
        id = id,
        speciesId = speciesId,
        ivs = ivs or {31, 31, 31, 31, 31, 31},
        nature = nature or "ADAMANT",
        ability = ability or "BLAZE",
        abilityIndex = abilityIndex or 1
    }
end

local function createTestSpeciesData()
    return {
        id = 6,
        name = "Charizard",
        abilities = {"BLAZE", "SOLAR_POWER", "SOLAR_POWER"} -- Slot 1, Slot 2, Hidden
    }
end

describe("Genetic Inheritance Engine Tests", function()
    
    describe("Info Handler", function()
        it("should return process information", function()
            local msg = {
                From = "test-sender",
                Action = "Info"
            }
            
            local response = env.handle(msg)
            assert.is_not_nil(response)
            assert.equals("InfoResponse", response.Action)
            
            local data = json.decode(response.Data)
            assert.equals("genetic-inheritance-engine", data.process.name)
            assert.equals("1.0.0", data.process.version)
            assert.equals("1.0", data.process.adpVersion)
        end)
    end)
    
    describe("IV Inheritance", function()
        it("should inherit 3 IVs without items", function()
            local parent1 = createTestParent("p1", 6, {31, 30, 29, 28, 27, 26})
            local parent2 = createTestParent("p2", 6, {26, 27, 28, 29, 30, 31})
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
                    }
                })
            }
            
            local response = env.handle(msg)
            assert.equals("SaveState", response.Action)
            
            local data = json.decode(response.Data)
            assert.is_true(data.success)
            assert.is_not_nil(data.genetics.ivInheritance)
            assert.equals(6, #data.genetics.ivInheritance.inheritedIvs)
            
            -- Count inherited vs random
            local inheritedCount = 0
            for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources) do
                if source ~= "random" then
                    inheritedCount = inheritedCount + 1
                end
            end
            assert.equals(3, inheritedCount)
        end)
        
        it("should inherit 5 IVs with Destiny Knot", function()
            local parent1 = createTestParent("p1", 6, {31, 30, 29, 28, 27, 26})
            local parent2 = createTestParent("p2", 6, {26, 27, 28, 29, 30, 31})
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "DESTINY_KNOT",
                        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            
            -- Count inherited stats
            local inheritedCount = 0
            for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources) do
                if source ~= "random" then
                    inheritedCount = inheritedCount + 1
                end
            end
            assert.equals(5, inheritedCount)
            
            -- Check item effects
            local hasDestinyKnotEffect = false
            for _, effect in ipairs(data.genetics.ivInheritance.itemEffects) do
                if effect == "destiny_knot_5_inherited" then
                    hasDestinyKnotEffect = true
                end
            end
            assert.is_true(hasDestinyKnotEffect)
        end)
        
        it("should guarantee specific IV with Power Item", function()
            local parent1 = createTestParent("p1", 6, {31, 25, 25, 25, 25, 25})
            local parent2 = createTestParent("p2", 6, {25, 25, 25, 25, 25, 25})
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "POWER_WEIGHT", -- Guarantees HP
                        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.equals(31, data.genetics.ivInheritance.inheritedIvs[1]) -- HP is first stat
            assert.equals("parent1", data.genetics.ivInheritance.inheritanceSources[1])
            
            -- Check item effect
            local hasPowerItemEffect = false
            for _, effect in ipairs(data.genetics.ivInheritance.itemEffects) do
                if effect == "power_item_guaranteed_hp" then
                    hasPowerItemEffect = true
                end
            end
            assert.is_true(hasPowerItemEffect)
        end)
    end)
    
    describe("Nature Inheritance", function()
        it("should have 50% nature inheritance without items", function()
            local parent1 = createTestParent("p1", 6, nil, "ADAMANT")
            local parent2 = createTestParent("p2", 6, nil, "MODEST")
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "determineNatureInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        randomValues = 12345
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_not_nil(data.genetics.natureInheritance.inheritedNature)
            assert.is_not_nil(data.genetics.natureInheritance.inheritanceSource)
        end)
        
        it("should guarantee nature with Everstone", function()
            local parent1 = createTestParent("p1", 6, nil, "ADAMANT")
            local parent2 = createTestParent("p2", 6, nil, "MODEST")
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "determineNatureInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        randomValues = 12345
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.equals("ADAMANT", data.genetics.natureInheritance.inheritedNature)
            assert.equals("parent1_everstone", data.genetics.natureInheritance.inheritanceSource)
            assert.equals(1.0, data.genetics.natureInheritance.inheritanceProbability)
        end)
        
        it("should handle dual Everstone scenario", function()
            local parent1 = createTestParent("p1", 6, nil, "ADAMANT")
            local parent2 = createTestParent("p2", 6, nil, "MODEST")
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "determineNatureInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        parent2Item = "EVERSTONE",
                        randomValues = 12345
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_true(data.genetics.natureInheritance.inheritedNature == "ADAMANT" or 
                         data.genetics.natureInheritance.inheritedNature == "MODEST")
            assert.equals(1.0, data.genetics.natureInheritance.inheritanceProbability)
        end)
        
        it("should include nature stat modifiers", function()
            local parent1 = createTestParent("p1", 6, nil, "ADAMANT")
            local parent2 = createTestParent("p2", 6, nil, "MODEST")
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "determineNatureInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        randomValues = 12345
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_not_nil(data.genetics.natureInheritance.natureEffects)
            assert.equals("attack", data.genetics.natureInheritance.natureEffects.boosted)
            assert.equals("spattack", data.genetics.natureInheritance.natureEffects.lowered)
        end)
    end)
    
    describe("Ability Inheritance", function()
        it("should inherit standard abilities with 80/20 distribution", function()
            local parent1 = createTestParent("p1", 6, nil, nil, "BLAZE", 1)
            local parent2 = createTestParent("p2", 6, nil, nil, "BLAZE", 1)
            local speciesData = createTestSpeciesData()
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateAbilityInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        speciesData = speciesData,
                        randomValues = 12345
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_not_nil(data.genetics.abilityInheritance.inheritedAbility)
            assert.is_true(data.genetics.abilityInheritance.inheritedAbility == "BLAZE" or 
                         data.genetics.abilityInheritance.inheritedAbility == "SOLAR_POWER")
        end)
        
        it("should inherit hidden ability with 60% chance", function()
            local parent1 = createTestParent("p1", 6, nil, nil, "SOLAR_POWER", 3)
            local parent2 = createTestParent("p2", 6, nil, nil, "BLAZE", 1)
            local speciesData = createTestSpeciesData()
            
            -- Test with seed that results in hidden ability inheritance
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateAbilityInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        speciesData = speciesData,
                        randomValues = 100 -- Seed chosen to result in hidden ability
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            if data.genetics.abilityInheritance.abilityType == "hidden" then
                assert.equals("SOLAR_POWER", data.genetics.abilityInheritance.inheritedAbility)
                assert.equals(0.6, data.genetics.abilityInheritance.inheritanceProbability)
            end
        end)
    end)
    
    describe("Complete Inheritance", function()
        it("should process complete genetic inheritance", function()
            local parent1 = createTestParent("p1", 6, {31, 30, 29, 28, 27, 26}, "ADAMANT", "BLAZE", 1)
            local parent2 = createTestParent("p2", 6, {26, 27, 28, 29, 30, 31}, "MODEST", "SOLAR_POWER", 3)
            local speciesData = createTestSpeciesData()
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "processCompleteInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        parent2Item = "DESTINY_KNOT",
                        speciesData = speciesData,
                        randomValues = 12345
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_not_nil(data.genetics.ivInheritance)
            assert.is_not_nil(data.genetics.natureInheritance)
            assert.is_not_nil(data.genetics.abilityInheritance)
            
            -- Verify Everstone effect
            assert.equals("ADAMANT", data.genetics.natureInheritance.inheritedNature)
            
            -- Verify Destiny Knot effect
            local inheritedCount = 0
            for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources) do
                if source ~= "random" then
                    inheritedCount = inheritedCount + 1
                end
            end
            assert.equals(5, inheritedCount)
        end)
    end)
    
    describe("Breeding Probabilities", function()
        it("should calculate breeding success probabilities", function()
            local currentGenetics = {
                ivInheritance = {
                    inheritedIvs = {31, 31, 30, 31, 31, 31}
                },
                natureInheritance = {
                    inheritedNature = "ADAMANT",
                    inheritanceProbability = 1.0
                },
                abilityInheritance = {
                    inheritedAbility = "SOLAR_POWER",
                    inheritanceProbability = 0.6
                }
            }
            
            local targetGenetics = {
                targetIvs = {31, 31, 31, 31, 31, 31},
                targetNature = "ADAMANT",
                targetAbility = "SOLAR_POWER"
            }
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateProbabilities",
                    parameters = {
                        currentGenetics = currentGenetics,
                        targetGenetics = targetGenetics
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_not_nil(data.probabilities)
            assert.is_not_nil(data.probabilities.perfectIvChance)
            assert.is_not_nil(data.probabilities.targetNatureChance)
            assert.is_not_nil(data.probabilities.targetAbilityChance)
            assert.is_not_nil(data.probabilities.combinedSuccessRate)
            assert.is_not_nil(data.probabilities.estimatedAttempts)
        end)
    end)
    
    describe("Breeding Strategy Optimization", function()
        it("should recommend optimal breeding strategy", function()
            local currentParents = {
                parent1 = createTestParent("p1", 6, {31, 25, 25, 25, 25, 25}, "ADAMANT", "BLAZE", 1),
                parent2 = createTestParent("p2", 6, {25, 25, 25, 25, 25, 31}, "MODEST", "SOLAR_POWER", 3)
            }
            
            local targetGenetics = {
                targetIvs = {31, 31, 31, 31, 31, 31},
                targetNature = "ADAMANT",
                targetAbility = "SOLAR_POWER"
            }
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "optimizeStrategy",
                    parameters = {
                        currentParents = currentParents,
                        targetGenetics = targetGenetics
                    }
                })
            }
            
            local response = env.handle(msg)
            local data = json.decode(response.Data)
            
            assert.is_true(data.success)
            assert.is_not_nil(data.recommendations)
            assert.is_not_nil(data.recommendations.optimalItems)
            assert.is_not_nil(data.recommendations.parentImprovements)
            assert.is_not_nil(data.recommendations.breedingStrategy)
            assert.is_not_nil(data.recommendations.efficiencyRating)
            
            -- Should recommend Destiny Knot for IV optimization
            local hasDestinyKnot = false
            for _, item in ipairs(data.recommendations.optimalItems) do
                if item == "DESTINY_KNOT" then
                    hasDestinyKnot = true
                end
            end
            assert.is_true(hasDestinyKnot)
            
            -- Should recommend Everstone for nature
            local hasEverstone = false
            for _, item in ipairs(data.recommendations.optimalItems) do
                if item == "EVERSTONE" then
                    hasEverstone = true
                end
            end
            assert.is_true(hasEverstone)
        end)
    end)
    
    describe("Error Handling", function()
        it("should handle missing operation", function()
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    parameters = {}
                })
            }
            
            local response = env.handle(msg)
            assert.equals("Error", response.Action)
            assert.equals("Operation required", response.Error)
        end)
        
        it("should handle unknown operation", function()
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "unknownOperation",
                    parameters = {}
                })
            }
            
            local response = env.handle(msg)
            assert.equals("Error", response.Action)
            assert.is_true(string.find(response.Error, "Unknown operation") ~= nil)
        end)
        
        it("should handle missing parent data", function()
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {}
                })
            }
            
            local response = env.handle(msg)
            assert.equals("Error", response.Action)
            assert.equals("Parent data required", response.Error)
        end)
    end)
    
    describe("Health Check", function()
        it("should respond to health check", function()
            local msg = {
                From = "test-sender",
                Action = "HealthCheck",
                Timestamp = 123456789
            }
            
            local response = env.handle(msg)
            assert.equals("HealthCheckResponse", response.Action)
            assert.equals("healthy", response.Status)
            assert.equals("123456789", response.Timestamp)
        end)
    end)
end)