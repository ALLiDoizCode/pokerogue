-- Integration Tests for Terastalization Battle Integration Engine
-- Tests cross-process communication and battle system integration
-- Uses aos-local testing framework for multi-process scenarios

local aolite = require('aolite')

-- Test configuration
local TEST_CONFIG = {
    processes = {
        battleIntegration = "terastalization-battle-integration-engine.lua",
        teraType = "tera-type-engine.lua",
        stellarTera = "stellar-tera-engine.lua",
        teraCrystal = "tera-crystal-engine.lua"
    },
    testTimeout = 5000, -- 5 seconds
    maxRetries = 3
}

describe("Terastalization Battle Integration - Integration Tests", function()
    
    local processes = {}
    
    before_all(function()
        -- Initialize test processes
        for name, file in pairs(TEST_CONFIG.processes) do
            processes[name] = aolite.spawnProcess("processes/" .. file)
            assert.is_not_nil(processes[name], "Failed to spawn " .. name .. " process")
        end
        
        -- Wait for initialization
        aolite.wait(1000)
    end)
    
    after_all(function()
        -- Cleanup processes
        for name, process in pairs(processes) do
            if process then
                process:kill()
            end
        end
    end)
    
    describe("Cross-Process Coordination", function()
        
        it("should coordinate Terastalization activation across all processes", function()
            local battleData = {
                battleId = "integration_battle_001",
                pokemonId = "pikachu_001",
                teraType = "ELECTRIC",
                trainerId = "trainer_001",
                turn = 1,
                pokemonData = {
                    id = "pikachu_001",
                    speciesId = "PIKACHU",
                    types = {"ELECTRIC"},
                    hp = 100,
                    maxHp = 100,
                    isTerastallized = false
                }
            }
            
            -- Send activation request to battle integration engine
            local response = processes.battleIntegration:send({
                Action = "ProcessTerastalizationBattle",
                Operation = "activate",
                BattleId = battleData.battleId,
                PokemonId = battleData.pokemonId,
                TeraType = battleData.teraType,
                TrainerId = battleData.trainerId,
                TurnNumber = battleData.turn,
                Data = json.encode(battleData.pokemonData)
            })
            
            assert.is_not_nil(response, "Should receive response from battle integration")
            assert.equals("TerastalizationBattleProcessed", response.Action, "Should process battle request")
            assert.equals("true", response.Success, "Activation should succeed")
        end)
        
        it("should validate eligibility with tera-crystal-engine", function()
            -- Test eligibility check coordination
            local eligibilityResponse = processes.teraCrystal:send({
                Action = "CheckTeraEligibility",
                PokemonId = "pikachu_001",
                BattleId = "integration_battle_001"
            })
            
            assert.is_not_nil(eligibilityResponse, "Should receive eligibility response")
            assert.equals("TeraEligibilityChecked", eligibilityResponse.Action, "Should check eligibility")
        end)
        
        it("should coordinate type validation with tera-type-engine", function()
            -- Test type engine coordination
            local typeResponse = processes.teraType:send({
                Action = "ActivateTerastalization",
                Data = json.encode({
                    id = "pikachu_001",
                    speciesId = "PIKACHU",
                    types = {"ELECTRIC"},
                    teraType = "ELECTRIC"
                }),
                BattleId = "integration_battle_001",
                TrainerId = "trainer_001"
            })
            
            assert.is_not_nil(typeResponse, "Should receive type activation response")
            assert.equals("TerastalizationActivated", typeResponse.Action, "Should activate Terastalization")
        end)
        
        it("should handle Stellar Tera coordination", function()
            local stellarData = {
                id = "terapagos_001",
                speciesId = "TERAPAGOS",
                types = {"NORMAL"},
                teraType = "STELLAR",
                isTerastallized = true
            }
            
            -- Test Stellar coordination
            local stellarResponse = processes.stellarTera:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(stellarData),
                BattleId = "integration_battle_001"
            })
            
            assert.is_not_nil(stellarResponse, "Should receive Stellar response")
            assert.equals("StellarTeraProcessed", stellarResponse.Action, "Should process Stellar Tera")
        end)
        
    end)
    
    describe("Battle Timing Integration", function()
        
        it("should coordinate battle phase transitions", function()
            local phases = {"COMMAND_PHASE", "MOVE_EXECUTION_PHASE", "STATUS_PHASE", "END_PHASE"}
            
            for turn = 1, 2 do
                for _, phase in ipairs(phases) do
                    local timingResponse = processes.battleIntegration:send({
                        Action = "BattleTimingCoordination",
                        BattleId = "integration_battle_001",
                        Phase = phase,
                        Turn = turn
                    })
                    
                    assert.is_not_nil(timingResponse, "Should receive timing response for " .. phase)
                    assert.equals("BattleTimingUpdated", timingResponse.Action, "Should update timing")
                    assert.equals(phase, timingResponse.Phase, "Should track correct phase")
                end
            end
        end)
        
        it("should enforce Terastalization timing restrictions", function()
            -- Try to activate in wrong phase
            local wrongPhaseResponse = processes.battleIntegration:send({
                Action = "ProcessTerastalizationBattle",
                Operation = "activate",
                BattleId = "integration_battle_002",
                PokemonId = "charizard_001",
                TeraType = "FIRE",
                BattlePhase = "MOVE_EXECUTION_PHASE"
            })
            
            assert.is_not_nil(wrongPhaseResponse, "Should receive response")
            assert.equals("false", wrongPhaseResponse.Success, "Should reject wrong phase activation")
        end)
        
    end)
    
    describe("Status Effect Integration", function()
        
        it("should integrate status immunity with type changes", function()
            local statusTests = {
                {teraType = "FIRE", status = "BURN", expectedImmune = true},
                {teraType = "POISON", status = "POISON", expectedImmune = true},
                {teraType = "ELECTRIC", status = "PARALYSIS", expectedImmune = true},
                {teraType = "ICE", status = "FREEZE", expectedImmune = true},
                {teraType = "WATER", status = "BURN", expectedImmune = false}
            }
            
            for _, test in ipairs(statusTests) do
                local statusResponse = processes.battleIntegration:send({
                    Action = "StatusEffectInteraction",
                    Data = json.encode({
                        teraType = test.teraType,
                        isTerastallized = true
                    }),
                    StatusEffect = test.status,
                    TeraType = test.teraType
                })
                
                assert.is_not_nil(statusResponse, "Should receive status response")
                assert.equals("StatusEffectInteractionProcessed", statusResponse.Action, "Should process status")
                assert.equals(tostring(test.expectedImmune), statusResponse.Immune, 
                    test.teraType .. " should be " .. (test.expectedImmune and "immune" or "affected") .. " by " .. test.status)
            end
        end)
        
    end)
    
    describe("Weather and Terrain Integration", function()
        
        it("should integrate environmental effects with Tera types", function()
            local environmentalTests = {
                {teraType = "FIRE", weather = "SUN", expectedBoost = true},
                {teraType = "WATER", weather = "RAIN", expectedBoost = true},
                {teraType = "ELECTRIC", terrain = "ELECTRIC_TERRAIN", expectedBoost = true},
                {teraType = "GRASS", terrain = "GRASSY_TERRAIN", expectedBoost = true}
            }
            
            for _, test in ipairs(environmentalTests) do
                local envResponse = processes.battleIntegration:send({
                    Action = "WeatherTerrainIntegration",
                    TeraType = test.teraType,
                    Weather = test.weather,
                    Terrain = test.terrain
                })
                
                assert.is_not_nil(envResponse, "Should receive environmental response")
                assert.equals("WeatherTerrainIntegrationProcessed", envResponse.Action, "Should process environment")
                
                local boost = tonumber(envResponse.EnvironmentalBoost)
                if test.expectedBoost then
                    assert.is_true(boost > 1.0, test.teraType .. " should be boosted by environment")
                else
                    assert.equals(1.0, boost, test.teraType .. " should not be boosted")
                end
            end
        end)
        
    end)
    
    describe("AI Decision Integration", function()
        
        it("should generate AI decisions based on battle context", function()
            local strategies = {"AGGRESSIVE", "DEFENSIVE", "BALANCED"}
            
            for _, strategy in ipairs(strategies) do
                local battleContext = {
                    pokemon = {
                        types = {"WATER"},
                        hp = 75,
                        maxHp = 100
                    },
                    opponent = {
                        types = {"FIRE"},
                        hp = 50,
                        maxHp = 100
                    },
                    weather = "RAIN",
                    turn = 3
                }
                
                local aiResponse = processes.battleIntegration:send({
                    Action = "AIDecisionMaking",
                    Data = json.encode(battleContext),
                    AIStrategy = strategy,
                    Turn = 3,
                    Timestamp = "1234567890"
                })
                
                assert.is_not_nil(aiResponse, "Should receive AI response for " .. strategy)
                assert.equals("AIDecisionMade", aiResponse.Action, "Should make AI decision")
                assert.is_not_nil(aiResponse.ShouldUse, "Should include usage decision")
                assert.is_not_nil(aiResponse.Confidence, "Should include confidence level")
            end
        end)
        
    end)
    
    describe("Complex Scenario Integration", function()
        
        it("should handle multi-effect battle scenarios", function()
            local complexScenario = {
                pokemon = {
                    id = "charizard_001",
                    types = {"FIRE", "FLYING"},
                    teraType = "DRAGON",
                    isTerastallized = true,
                    statusEffect = "BURN",
                    hp = 80,
                    maxHp = 100
                },
                weather = "SUN",
                terrain = "ELECTRIC_TERRAIN",
                moveType = "DRAGON",
                turn = 5
            }
            
            local complexResponse = processes.battleIntegration:send({
                Action = "ComplexScenarioCoordination",
                Data = json.encode(complexScenario),
                ScenarioType = "multi_effect_stacking"
            })
            
            assert.is_not_nil(complexResponse, "Should receive complex scenario response")
            assert.equals("ComplexScenarioProcessed", complexResponse.Action, "Should process complex scenario")
            assert.equals("true", complexResponse.Success, "Complex scenario should succeed")
            
            local result = json.decode(complexResponse.Result)
            assert.is_table(result, "Should return scenario result")
        end)
        
        it("should validate complex interaction consistency", function()
            -- Test interaction between multiple effects
            local validationScenario = {
                pokemon = {
                    teraType = "STEEL",
                    isTerastallized = true,
                    statusEffect = "POISON"
                },
                weather = "SANDSTORM",
                terrain = "MISTY_TERRAIN"
            }
            
            local validationResponse = processes.battleIntegration:send({
                Action = "ComplexScenarioCoordination",
                Data = json.encode(validationScenario),
                ScenarioType = "interaction_validation"
            })
            
            assert.is_not_nil(validationResponse, "Should receive validation response")
            assert.equals("true", validationResponse.Success, "Validation should succeed")
        end)
        
    end)
    
    describe("Error Handling and Recovery", function()
        
        it("should handle process communication timeouts", function()
            -- Simulate timeout by sending to non-existent process
            local timeoutResponse = processes.battleIntegration:send({
                Action = "ProcessTerastalizationBattle",
                Operation = "coordinate",
                BattleId = "timeout_test",
                PokemonId = "test_pokemon"
            }, {timeout = 1000}) -- Short timeout
            
            -- Should still respond even if coordination fails
            assert.is_not_nil(timeoutResponse, "Should handle timeouts gracefully")
        end)
        
        it("should recover from invalid data gracefully", function()
            local invalidResponse = processes.battleIntegration:send({
                Action = "ProcessTerastalizationBattle",
                Operation = "activate",
                -- Missing required fields
                Data = "invalid_json"
            })
            
            assert.is_not_nil(invalidResponse, "Should receive error response")
            assert.equals("false", invalidResponse.Success, "Should fail with invalid data")
            assert.is_not_nil(invalidResponse.Error, "Should include error message")
        end)
        
    end)
    
    describe("Performance and Load Testing", function()
        
        it("should handle multiple concurrent battles", function()
            local concurrentBattles = {}
            local numBattles = 5
            
            -- Start multiple battles concurrently
            for i = 1, numBattles do
                local battleId = "concurrent_battle_" .. i
                local response = processes.battleIntegration:send({
                    Action = "BattleTimingCoordination",
                    BattleId = battleId,
                    Phase = "COMMAND_PHASE",
                    Turn = 1
                })
                
                table.insert(concurrentBattles, response)
            end
            
            -- Verify all battles were handled
            for i, response in ipairs(concurrentBattles) do
                assert.is_not_nil(response, "Battle " .. i .. " should be handled")
                assert.equals("BattleTimingUpdated", response.Action, "Battle " .. i .. " should be updated")
            end
        end)
        
        it("should maintain performance under rapid requests", function()
            local rapidRequests = 10
            local responses = {}
            
            local startTime = os.time()
            
            for i = 1, rapidRequests do
                local response = processes.battleIntegration:send({
                    Action = "StatusEffectInteraction",
                    Data = json.encode({teraType = "FIRE"}),
                    StatusEffect = "BURN",
                    TeraType = "FIRE"
                })
                
                table.insert(responses, response)
            end
            
            local endTime = os.time()
            local duration = endTime - startTime
            
            -- All requests should complete within reasonable time
            assert.is_true(duration < 5, "Rapid requests should complete quickly")
            
            -- All responses should be valid
            for i, response in ipairs(responses) do
                assert.is_not_nil(response, "Request " .. i .. " should get response")
            end
        end)
        
    end)
    
    describe("ADP v1.0 Compliance Integration", function()
        
        it("should respond to Info requests from other processes", function()
            local infoResponse = processes.battleIntegration:send({
                Action = "Info"
            })
            
            assert.is_not_nil(infoResponse, "Should receive Info response")
            
            local info = json.decode(infoResponse.Data)
            assert.is_table(info, "Should return structured info")
            assert.equals("1.0", info.adpVersion, "Should be ADP v1.0 compliant")
            assert.is_table(info.handlers, "Should include handler registry")
            assert.is_table(info.capabilities, "Should include capabilities")
        end)
        
        it("should maintain connectivity with Ping", function()
            local pingResponse = processes.battleIntegration:send({
                Action = "Ping"
            })
            
            assert.is_not_nil(pingResponse, "Should receive Ping response")
            assert.equals("Pong", pingResponse.Action, "Should respond with Pong")
        end)
        
    end)
    
end)

-- Run integration tests
local runner = aolite.TestRunner:new()
runner:run()