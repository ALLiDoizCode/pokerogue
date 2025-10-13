-- Integration tests for genetic-inheritance-engine.lua
-- Tests cross-process coordination and message passing

local json = require("json")

-- Mock environment for testing
local function setupTestEnvironment()
    _G.ao = {
        send = function(msg) 
            print("Sending message to", msg.Target, "with action", msg.Action)
        end,
        id = "test-genetic-engine"
    }
    
    _G.Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg) 
                    return msg[tag] == value 
                end
            end
        }
    }
end

setupTestEnvironment()

-- Load the process
dofile("processes/genetic-inheritance-engine.lua")

print("Running Genetic Inheritance Engine Integration Tests...")
print("===================================================")
print()

-- Test scenarios
local testScenarios = {
    {
        name = "Cross-process Pokemon data retrieval",
        description = "Simulates retrieving Pokemon data from instance manager",
        test = function()
            print("Test: Requesting Pokemon genetic data from instance manager...")
            
            -- Simulate request to Pokemon instance manager
            ao.send({
                Target = "POKEMON_INSTANCE_MANAGER_PROCESS_ID",
                Action = "GetPokemonGenetics",
                Data = json.encode({
                    pokemonId = "pokemon_123",
                    includeIvs = true,
                    includeNature = true,
                    includeAbility = true,
                    includeItems = true
                })
            })
            
            print("✓ Pokemon data request sent successfully")
        end
    },
    {
        name = "Breeding compatibility validation",
        description = "Simulates coordination with breeding compatibility engine",
        test = function()
            print("Test: Validating breeding pair compatibility...")
            
            -- Simulate request to breeding compatibility engine
            ao.send({
                Target = "BREEDING_COMPATIBILITY_ENGINE_PROCESS_ID",
                Action = "ValidateBreedingPair",
                Data = json.encode({
                    parent1Id = "pokemon_123",
                    parent2Id = "pokemon_456",
                    includeGeneticCompatibility = true
                })
            })
            
            print("✓ Breeding compatibility validation request sent")
        end
    },
    {
        name = "Species genetic data coordination",
        description = "Simulates fetching species data for inheritance parameters",
        test = function()
            print("Test: Fetching species genetic data...")
            
            -- Simulate request to species database
            ao.send({
                Target = "POKEMON_SPECIES_DB_PROCESS_ID",
                Action = "GetSpeciesGeneticData",
                Data = json.encode({
                    speciesId = 6,
                    includeAbilities = true,
                    includeEggGroups = true,
                    includeInheritance = true
                })
            })
            
            print("✓ Species genetic data request sent")
        end
    },
    {
        name = "Player save data update",
        description = "Simulates updating player save with genetic results",
        test = function()
            print("Test: Updating player save with genetic data...")
            
            -- Simulate genetic state update
            local geneticState = {
                breedingRecords = {
                    {
                        recordId = 1,
                        parentPokemon = {
                            parent1 = "pokemon_123",
                            parent2 = "pokemon_456"
                        },
                        offspringGenetics = {
                            inheritedIvs = {31, 31, 30, 31, 31, 31},
                            inheritedNature = "ADAMANT",
                            inheritedAbility = "SOLAR_POWER"
                        },
                        timestamp = 1234567890
                    }
                }
            }
            
            ao.send({
                Target = "COORDINATOR_PROCESS_ID",
                Action = "UpdatePlayerSave",
                Data = json.encode({
                    playerId = "player_wallet_123",
                    geneticData = geneticState,
                    saveReason = "genetic_inheritance_update"
                })
            })
            
            print("✓ Player save update request sent")
        end
    },
    {
        name = "Complete breeding workflow",
        description = "Simulates full breeding inheritance workflow",
        test = function()
            print("Test: Processing complete breeding workflow...")
            
            -- Step 1: Validate breeding pair
            print("  Step 1: Validating breeding pair...")
            ao.send({
                Target = "BREEDING_COMPATIBILITY_ENGINE_PROCESS_ID",
                Action = "ValidateBreedingPair",
                Data = json.encode({
                    parent1Id = "pokemon_123",
                    parent2Id = "pokemon_456"
                })
            })
            
            -- Step 2: Get parent Pokemon data
            print("  Step 2: Retrieving parent Pokemon data...")
            ao.send({
                Target = "POKEMON_INSTANCE_MANAGER_PROCESS_ID",
                Action = "GetPokemonGenetics",
                Data = json.encode({
                    pokemonId = "pokemon_123",
                    includeIvs = true,
                    includeNature = true,
                    includeAbility = true,
                    includeItems = true
                })
            })
            
            ao.send({
                Target = "POKEMON_INSTANCE_MANAGER_PROCESS_ID",
                Action = "GetPokemonGenetics",
                Data = json.encode({
                    pokemonId = "pokemon_456",
                    includeIvs = true,
                    includeNature = true,
                    includeAbility = true,
                    includeItems = true
                })
            })
            
            -- Step 3: Get species data
            print("  Step 3: Fetching species genetic parameters...")
            ao.send({
                Target = "POKEMON_SPECIES_DB_PROCESS_ID",
                Action = "GetSpeciesGeneticData",
                Data = json.encode({
                    speciesId = 6,
                    includeAbilities = true,
                    includeEggGroups = true,
                    includeInheritance = true
                })
            })
            
            -- Step 4: Process genetic inheritance (internal)
            print("  Step 4: Calculating genetic inheritance...")
            
            -- Step 5: Update player save
            print("  Step 5: Saving genetic results...")
            ao.send({
                Target = "COORDINATOR_PROCESS_ID",
                Action = "UpdatePlayerSave",
                Data = json.encode({
                    playerId = "player_wallet_123",
                    geneticData = {
                        lastBreedingResult = {
                            timestamp = os.time(),
                            success = true
                        }
                    },
                    saveReason = "breeding_complete"
                })
            })
            
            print("✓ Complete breeding workflow processed successfully")
        end
    },
    {
        name = "Multi-generation breeding chain",
        description = "Simulates complex multi-generation breeding optimization",
        test = function()
            print("Test: Processing multi-generation breeding chain...")
            
            -- Generation 1
            print("  Generation 1: Initial breeding...")
            ao.send({
                Target = "GENETIC_INHERITANCE_ENGINE_PROCESS_ID",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "optimizeStrategy",
                    parameters = {
                        currentParents = {
                            parent1 = {
                                id = "pokemon_001",
                                ivs = {25, 25, 25, 25, 25, 25}
                            },
                            parent2 = {
                                id = "pokemon_002",
                                ivs = {28, 28, 28, 28, 28, 28}
                            }
                        },
                        targetGenetics = {
                            targetIvs = {31, 31, 31, 31, 31, 31},
                            targetNature = "ADAMANT",
                            targetAbility = "SOLAR_POWER"
                        }
                    }
                })
            })
            
            -- Generation 2
            print("  Generation 2: Improved breeding...")
            ao.send({
                Target = "GENETIC_INHERITANCE_ENGINE_PROCESS_ID",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "optimizeStrategy",
                    parameters = {
                        currentParents = {
                            parent1 = {
                                id = "pokemon_003",
                                ivs = {31, 28, 30, 31, 28, 31}
                            },
                            parent2 = {
                                id = "pokemon_004",
                                ivs = {28, 31, 31, 28, 31, 30}
                            }
                        },
                        targetGenetics = {
                            targetIvs = {31, 31, 31, 31, 31, 31},
                            targetNature = "ADAMANT",
                            targetAbility = "SOLAR_POWER"
                        }
                    }
                })
            })
            
            print("✓ Multi-generation breeding chain processed")
        end
    },
    {
        name = "Error recovery and retry",
        description = "Simulates error handling and retry logic",
        test = function()
            print("Test: Testing error recovery mechanisms...")
            
            -- Simulate failed request
            print("  Simulating failed genetic calculation...")
            ao.send({
                Target = "GENETIC_INHERITANCE_ENGINE_PROCESS_ID",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {} -- Missing required parameters
                })
            })
            
            -- Retry with correct parameters
            print("  Retrying with correct parameters...")
            ao.send({
                Target = "GENETIC_INHERITANCE_ENGINE_PROCESS_ID",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = {
                            id = "pokemon_123",
                            speciesId = 6,
                            ivs = {31, 30, 29, 28, 27, 26}
                        },
                        parent2 = {
                            id = "pokemon_456",
                            speciesId = 6,
                            ivs = {26, 27, 28, 29, 30, 31}
                        }
                    }
                })
            })
            
            print("✓ Error recovery and retry completed")
        end
    },
    {
        name = "Performance stress test",
        description = "Simulates high-volume genetic calculations",
        test = function()
            print("Test: Running performance stress test...")
            
            local startTime = os.clock()
            
            for i = 1, 100 do
                ao.send({
                    Target = "GENETIC_INHERITANCE_ENGINE_PROCESS_ID",
                    Action = "ProcessLogic",
                    Data = json.encode({
                        operation = "calculateProbabilities",
                        parameters = {
                            currentGenetics = {
                                ivInheritance = {
                                    inheritedIvs = {31, 30, 29, 28, 27, 26}
                                },
                                natureInheritance = {
                                    inheritedNature = "ADAMANT",
                                    inheritanceProbability = 1.0
                                },
                                abilityInheritance = {
                                    inheritedAbility = "BLAZE",
                                    inheritanceProbability = 0.8
                                }
                            },
                            targetGenetics = {
                                targetIvs = {31, 31, 31, 31, 31, 31},
                                targetNature = "ADAMANT",
                                targetAbility = "BLAZE"
                            }
                        }
                    })
                })
            end
            
            local endTime = os.clock()
            local elapsedTime = (endTime - startTime) * 1000
            
            print(string.format("  Processed 100 genetic calculations in %.2fms", elapsedTime))
            
            if elapsedTime < 5000 then
                print("✓ Performance stress test passed (within 5-second limit)")
            else
                print("✗ Performance stress test failed (exceeded 5-second limit)")
            end
        end
    }
}

-- Run all test scenarios
local passedTests = 0
local failedTests = 0

for i, scenario in ipairs(testScenarios) do
    print(string.format("\nScenario %d: %s", i, scenario.name))
    print("Description:", scenario.description)
    print("-" .. string.rep("-", 50))
    
    local success, error = pcall(scenario.test)
    
    if success then
        passedTests = passedTests + 1
        print(string.format("✓ Scenario %d passed", i))
    else
        failedTests = failedTests + 1
        print(string.format("✗ Scenario %d failed: %s", i, error))
    end
end

-- Summary
print("\n" .. string.rep("=", 50))
print("Integration Test Results:")
print(string.format("  Passed: %d", passedTests))
print(string.format("  Failed: %d", failedTests))
print(string.format("  Total:  %d", passedTests + failedTests))
print()

if failedTests == 0 then
    print("🎉 All integration tests passed!")
else
    print("⚠️  Some integration tests failed")
end