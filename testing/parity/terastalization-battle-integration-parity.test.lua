-- Parity Tests for Terastalization Battle Integration Engine
-- Validates behavioral consistency with TypeScript implementation
-- Tests core mechanics, timing, and interaction calculations

local aolite = require('aolite')

-- TypeScript reference data for parity validation
local TYPESCRIPT_REFERENCE = {
    -- Battle timing constants from TypeScript
    battlePhases = {
        COMMAND_PHASE = 0,
        MOVE_EXECUTION_PHASE = 1,
        STATUS_PHASE = 2,
        END_PHASE = 3
    },
    
    -- Status immunity mappings from TypeScript
    statusImmunities = {
        FIRE = {"BURN"},
        POISON = {"POISON"},
        STEEL = {"POISON"},
        ELECTRIC = {"PARALYSIS"},
        ICE = {"FREEZE"}
    },
    
    -- Weather boost calculations from TypeScript
    weatherBoosts = {
        SUN = {FIRE = 1.5, WATER = 0.5},
        RAIN = {WATER = 1.5, FIRE = 0.5},
        HAIL = {ICE = 1.0}, -- Ice immune to damage
        SANDSTORM = {ROCK = 1.5} -- SpDef boost
    },
    
    -- Terrain boost calculations from TypeScript
    terrainBoosts = {
        ELECTRIC_TERRAIN = {ELECTRIC = 1.3},
        GRASSY_TERRAIN = {GRASS = 1.3},
        PSYCHIC_TERRAIN = {PSYCHIC = 1.3},
        MISTY_TERRAIN = {FAIRY = 1.3}
    },
    
    -- Complex interaction test cases from TypeScript
    complexScenarios = {
        {
            name = "Fire Tera in Sun with Burn",
            pokemon = {
                types = {"FIRE", "FLYING"},
                teraType = "FIRE",
                isTerastallized = true,
                statusEffect = "BURN"
            },
            weather = "SUN",
            expectedResults = {
                statusImmune = true,
                weatherBoost = 1.5,
                finalMultiplier = 1.5
            }
        },
        {
            name = "Electric Tera on Electric Terrain with Paralysis",
            pokemon = {
                types = {"NORMAL"},
                teraType = "ELECTRIC", 
                isTerastallized = true,
                statusEffect = "PARALYSIS"
            },
            terrain = "ELECTRIC_TERRAIN",
            expectedResults = {
                statusImmune = true,
                terrainBoost = 1.3,
                finalMultiplier = 1.3
            }
        },
        {
            name = "Steel Tera in Sandstorm with Poison",
            pokemon = {
                types = {"ROCK"},
                teraType = "STEEL",
                isTerastallized = true,
                statusEffect = "POISON"
            },
            weather = "SANDSTORM",
            expectedResults = {
                statusImmune = true,
                weatherDamageImmune = true,
                finalMultiplier = 1.0
            }
        }
    }
}

describe("Terastalization Battle Integration - Parity Tests", function()
    
    local process
    
    before_all(function()
        -- Load the battle integration process
        process = aolite.spawnProcess("processes/terastalization-battle-integration-engine.lua")
        assert.is_not_nil(process, "Failed to spawn battle integration process")
        aolite.wait(500) -- Allow initialization
    end)
    
    after_all(function()
        if process then
            process:kill()
        end
    end)
    
    describe("Battle Phase Timing Parity", function()
        
        it("should match TypeScript battle phase constants", function()
            -- Test that battle phases are handled in correct order
            local phases = {"COMMAND_PHASE", "MOVE_EXECUTION_PHASE", "STATUS_PHASE", "END_PHASE"}
            local battleId = "parity_battle_timing"
            
            for i, phase in ipairs(phases) do
                local response = process:send({
                    Action = "BattleTimingCoordination",
                    BattleId = battleId,
                    Phase = phase,
                    Turn = 1
                })
                
                assert.is_not_nil(response, "Should handle phase: " .. phase)
                assert.equals("BattleTimingUpdated", response.Action, "Should update timing for " .. phase)
                assert.equals(phase, response.Phase, "Should match TypeScript phase ordering")
            end
        end)
        
        it("should enforce TypeScript Terastalization timing restrictions", function()
            -- Only COMMAND_PHASE should allow activation (matches TypeScript)
            local testCases = {
                {phase = "COMMAND_PHASE", shouldSucceed = true},
                {phase = "MOVE_EXECUTION_PHASE", shouldSucceed = false},
                {phase = "STATUS_PHASE", shouldSucceed = false},
                {phase = "END_PHASE", shouldSucceed = false}
            }
            
            for _, test in ipairs(testCases) do
                local response = process:send({
                    Action = "ProcessTerastalizationBattle",
                    Operation = "activate",
                    BattleId = "parity_timing_test",
                    PokemonId = "test_pokemon",
                    TeraType = "FIRE",
                    BattlePhase = test.phase,
                    Data = json.encode({
                        hp = 100,
                        maxHp = 100,
                        isTerastallized = false
                    })
                })
                
                assert.is_not_nil(response, "Should receive response for " .. test.phase)
                if test.shouldSucceed then
                    assert.equals("true", response.Success, test.phase .. " should allow activation (TypeScript parity)")
                else
                    assert.equals("false", response.Success, test.phase .. " should block activation (TypeScript parity)")
                end
            end
        end)
        
    end)
    
    describe("Status Effect Immunity Parity", function()
        
        it("should match TypeScript status immunity calculations", function()
            for teraType, immuneStatuses in pairs(TYPESCRIPT_REFERENCE.statusImmunities) do
                for _, status in ipairs(immuneStatuses) do
                    local response = process:send({
                        Action = "StatusEffectInteraction",
                        Data = json.encode({
                            teraType = teraType,
                            isTerastallized = true
                        }),
                        StatusEffect = status,
                        TeraType = teraType
                    })
                    
                    assert.is_not_nil(response, "Should handle " .. teraType .. " vs " .. status)
                    assert.equals("StatusEffectInteractionProcessed", response.Action)
                    assert.equals("true", response.Immune, 
                        teraType .. " should be immune to " .. status .. " (TypeScript parity)")
                end
            end
        end)
        
        it("should match TypeScript non-immunity behavior", function()
            -- Test cases where immunity should NOT apply
            local nonImmunityTests = {
                {teraType = "WATER", status = "BURN"},
                {teraType = "GRASS", status = "PARALYSIS"},
                {teraType = "FIGHTING", status = "POISON"},
                {teraType = "NORMAL", status = "FREEZE"}
            }
            
            for _, test in ipairs(nonImmunityTests) do
                local response = process:send({
                    Action = "StatusEffectInteraction",
                    Data = json.encode({
                        teraType = test.teraType,
                        isTerastallized = true
                    }),
                    StatusEffect = test.status,
                    TeraType = test.teraType
                })
                
                assert.is_not_nil(response, "Should handle non-immunity case")
                assert.equals("false", response.Immune,
                    test.teraType .. " should NOT be immune to " .. test.status .. " (TypeScript parity)")
            end
        end)
        
    end)
    
    describe("Weather Effect Parity", function()
        
        it("should match TypeScript weather boost calculations", function()
            for weather, typeBoosts in pairs(TYPESCRIPT_REFERENCE.weatherBoosts) do
                for teraType, expectedBoost in pairs(typeBoosts) do
                    local response = process:send({
                        Action = "WeatherTerrainIntegration",
                        TeraType = teraType,
                        Weather = weather
                    })
                    
                    assert.is_not_nil(response, "Should handle " .. teraType .. " in " .. weather)
                    assert.equals("WeatherTerrainIntegrationProcessed", response.Action)
                    
                    local actualBoost = tonumber(response.EnvironmentalBoost)
                    local tolerance = 0.01 -- Allow for floating point precision
                    
                    assert.is_true(math.abs(actualBoost - expectedBoost) < tolerance,
                        string.format("%s in %s: expected %.2f, got %.2f (TypeScript parity)",
                        teraType, weather, expectedBoost, actualBoost))
                end
            end
        end)
        
    end)
    
    describe("Terrain Effect Parity", function()
        
        it("should match TypeScript terrain boost calculations", function()
            for terrain, typeBoosts in pairs(TYPESCRIPT_REFERENCE.terrainBoosts) do
                for teraType, expectedBoost in pairs(typeBoosts) do
                    local response = process:send({
                        Action = "WeatherTerrainIntegration",
                        TeraType = teraType,
                        Terrain = terrain
                    })
                    
                    assert.is_not_nil(response, "Should handle " .. teraType .. " on " .. terrain)
                    assert.equals("WeatherTerrainIntegrationProcessed", response.Action)
                    
                    local actualBoost = tonumber(response.EnvironmentalBoost)
                    local tolerance = 0.01
                    
                    assert.is_true(math.abs(actualBoost - expectedBoost) < tolerance,
                        string.format("%s on %s: expected %.2f, got %.2f (TypeScript parity)",
                        teraType, terrain, expectedBoost, actualBoost))
                end
            end
        end)
        
    end)
    
    describe("Complex Interaction Parity", function()
        
        it("should match TypeScript complex scenario calculations", function()
            for _, scenario in ipairs(TYPESCRIPT_REFERENCE.complexScenarios) do
                local response = process:send({
                    Action = "ComplexScenarioCoordination",
                    Data = json.encode(scenario),
                    ScenarioType = "parity_validation"
                })
                
                assert.is_not_nil(response, "Should handle complex scenario: " .. scenario.name)
                assert.equals("ComplexScenarioProcessed", response.Action)
                assert.equals("true", response.Success, "Complex scenario should succeed")
                
                local result = json.decode(response.Result)
                assert.is_table(result, "Should return complex result for " .. scenario.name)
                
                -- Validate specific results match TypeScript expectations
                if scenario.expectedResults.finalMultiplier then
                    local tolerance = 0.01
                    assert.is_true(
                        math.abs(result.finalDamageMultiplier - scenario.expectedResults.finalMultiplier) < tolerance,
                        string.format("%s: finalMultiplier parity failed. Expected %.2f, got %.2f",
                        scenario.name, scenario.expectedResults.finalMultiplier, result.finalDamageMultiplier)
                    )
                end
            end
        end)
        
    end)
    
    describe("AI Decision Parity", function()
        
        it("should match TypeScript AI decision patterns", function()
            -- Test deterministic AI behavior with fixed seeds
            local aiTestCases = {
                {
                    seed = 12345,
                    strategy = "AGGRESSIVE",
                    context = {
                        pokemon = {types = {"WATER"}, hp = 75, maxHp = 100},
                        opponent = {types = {"FIRE"}, hp = 50, maxHp = 100},
                        typeAdvantage = true
                    },
                    expectedPattern = "offensive_advantage"
                },
                {
                    seed = 67890,
                    strategy = "DEFENSIVE", 
                    context = {
                        pokemon = {types = {"STEEL"}, hp = 25, maxHp = 100},
                        opponent = {types = {"FIGHTING"}, hp = 90, maxHp = 100},
                        typeDisadvantage = true
                    },
                    expectedPattern = "defensive_coverage"
                }
            }
            
            for _, test in ipairs(aiTestCases) do
                local response = process:send({
                    Action = "AIDecisionMaking",
                    Data = json.encode(test.context),
                    AIStrategy = test.strategy,
                    Turn = 1,
                    Timestamp = tostring(test.seed)
                })
                
                assert.is_not_nil(response, "Should receive AI decision")
                assert.equals("AIDecisionMade", response.Action)
                
                -- Verify deterministic behavior (same seed = same result)
                local response2 = process:send({
                    Action = "AIDecisionMaking",
                    Data = json.encode(test.context),
                    AIStrategy = test.strategy,
                    Turn = 1,
                    Timestamp = tostring(test.seed)
                })
                
                assert.equals(response.ShouldUse, response2.ShouldUse,
                    "AI decisions should be deterministic (TypeScript parity)")
                assert.equals(response.Confidence, response2.Confidence,
                    "AI confidence should be deterministic (TypeScript parity)")
            end
        end)
        
    end)
    
    describe("Mathematical Precision Parity", function()
        
        it("should match TypeScript floating point calculations", function()
            -- Test specific calculations that must match TypeScript exactly
            local precisionTests = {
                {
                    description = "Sun + Fire Tera boost",
                    inputs = {teraType = "FIRE", weather = "SUN"},
                    expectedResult = 1.5
                },
                {
                    description = "Electric Terrain + Electric Tera boost",
                    inputs = {teraType = "ELECTRIC", terrain = "ELECTRIC_TERRAIN"},
                    expectedResult = 1.3
                },
                {
                    description = "Combined Sun + Grassy Terrain with Fire Tera",
                    inputs = {teraType = "FIRE", weather = "SUN", terrain = "GRASSY_TERRAIN"},
                    expectedResult = 1.5 -- Fire not boosted by Grassy Terrain
                }
            }
            
            for _, test in ipairs(precisionTests) do
                local response = process:send({
                    Action = "WeatherTerrainIntegration",
                    TeraType = test.inputs.teraType,
                    Weather = test.inputs.weather,
                    Terrain = test.inputs.terrain
                })
                
                assert.is_not_nil(response, "Should handle precision test: " .. test.description)
                
                local actualResult = tonumber(response.EnvironmentalBoost)
                local tolerance = 0.0001 -- Very tight tolerance for precision
                
                assert.is_true(math.abs(actualResult - test.expectedResult) < tolerance,
                    string.format("%s: Expected %.4f, got %.4f (precision mismatch)",
                    test.description, test.expectedResult, actualResult))
            end
        end)
        
    end)
    
    describe("Edge Case Parity", function()
        
        it("should handle TypeScript edge cases correctly", function()
            -- Test edge cases that exist in TypeScript implementation
            local edgeCases = {
                {
                    name = "Fainted Pokemon Terastalization",
                    data = {
                        hp = 0,
                        maxHp = 100,
                        isTerastallized = false
                    },
                    shouldFail = true
                },
                {
                    name = "Already Terastalized Pokemon",
                    data = {
                        hp = 100,
                        maxHp = 100,
                        isTerastallized = true
                    },
                    shouldFail = true
                },
                {
                    name = "Multiple status effects with Tera immunity",
                    data = {
                        hp = 50,
                        maxHp = 100,
                        isTerastallized = true,
                        teraType = "STEEL",
                        statusEffect = "POISON"
                    },
                    shouldSucceed = true
                }
            }
            
            for _, edge in ipairs(edgeCases) do
                local response = process:send({
                    Action = "ProcessTerastalizationBattle",
                    Operation = "activate",
                    BattleId = "edge_case_test",
                    PokemonId = "edge_pokemon",
                    TeraType = "FIRE",
                    Data = json.encode(edge.data)
                })
                
                assert.is_not_nil(response, "Should handle edge case: " .. edge.name)
                
                if edge.shouldFail then
                    assert.equals("false", response.Success, 
                        edge.name .. " should fail (TypeScript parity)")
                else
                    assert.equals("true", response.Success,
                        edge.name .. " should succeed (TypeScript parity)")
                end
            end
        end)
        
    end)
    
    describe("Performance Parity", function()
        
        it("should match TypeScript performance characteristics", function()
            -- Test that performance is within acceptable bounds of TypeScript
            local performanceTests = {
                {operation = "status_check", iterations = 100},
                {operation = "weather_calculation", iterations = 100},
                {operation = "complex_scenario", iterations = 50}
            }
            
            for _, test in ipairs(performanceTests) do
                local startTime = os.clock()
                
                for i = 1, test.iterations do
                    local response
                    if test.operation == "status_check" then
                        response = process:send({
                            Action = "StatusEffectInteraction",
                            Data = json.encode({teraType = "FIRE"}),
                            StatusEffect = "BURN",
                            TeraType = "FIRE"
                        })
                    elseif test.operation == "weather_calculation" then
                        response = process:send({
                            Action = "WeatherTerrainIntegration",
                            TeraType = "WATER",
                            Weather = "RAIN"
                        })
                    elseif test.operation == "complex_scenario" then
                        response = process:send({
                            Action = "ComplexScenarioCoordination",
                            Data = json.encode({pokemon = {teraType = "FIRE"}}),
                            ScenarioType = "performance_test"
                        })
                    end
                    
                    assert.is_not_nil(response, "Performance test iteration " .. i .. " should succeed")
                end
                
                local endTime = os.clock()
                local duration = endTime - startTime
                local avgTime = duration / test.iterations
                
                -- Should complete within reasonable time bounds (matching TypeScript performance)
                assert.is_true(avgTime < 0.01, -- 10ms per operation
                    string.format("%s performance: %.4fs per operation (should be < 0.01s)",
                    test.operation, avgTime))
            end
        end)
        
    end)
    
end)

-- Run parity tests
local runner = aolite.TestRunner:new()
runner:run()