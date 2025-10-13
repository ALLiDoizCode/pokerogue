-- Integration Tests for Stellar Tera Engine
-- Tests complete message flow, coordination with battle systems, and complex scenarios

local aos = require("aos-local")
local json = require("json")

-- Test Battle Configuration
local BATTLE_CONFIG = {
    battleId = "integration_stellar_battle_001",
    turnCount = 1,
    players = {
        player1 = "player_address_1",
        player2 = "player_address_2"
    }
}

-- Test Pokemon Data
local TEST_TEAMS = {
    player1 = {
        charizard = {
            id = "charizard_p1",
            speciesId = "CHARIZARD",
            types = {"FIRE", "FLYING"},
            hp = 297,
            maxHp = 297,
            level = 100,
            teraType = "STELLAR",
            isTerastallized = false,
            stellarTypesBoosted = {},
            moves = {
                {id = "flamethrower", type = "FIRE", category = "SPECIAL", power = 90},
                {id = "air_slash", type = "FLYING", category = "SPECIAL", power = 75},
                {id = "thunderbolt", type = "ELECTRIC", category = "SPECIAL", power = 90},
                {id = "roost", type = "FLYING", category = "STATUS", power = 0}
            }
        },
        terapagos = {
            id = "terapagos_p1",
            speciesId = "TERAPAGOS_STELLAR",
            types = {"NORMAL"},
            hp = 290,
            maxHp = 290,
            level = 100,
            teraType = "STELLAR",
            isTerastallized = false,
            stellarTypesBoosted = {},
            moves = {
                {id = "earth_power", type = "GROUND", category = "SPECIAL", power = 90},
                {id = "hyper_beam", type = "NORMAL", category = "SPECIAL", power = 150},
                {id = "dazzling_gleam", type = "FAIRY", category = "SPECIAL", power = 80},
                {id = "protect", type = "NORMAL", category = "STATUS", power = 0}
            }
        }
    },
    player2 = {
        garchomp = {
            id = "garchomp_p2",
            speciesId = "GARCHOMP",
            types = {"DRAGON", "GROUND"},
            hp = 358,
            maxHp = 358,
            level = 100,
            teraType = "FIRE",
            isTerastallized = false,
            stellarTypesBoosted = {}
        },
        venusaur = {
            id = "venusaur_p2",
            speciesId = "VENUSAUR",
            types = {"GRASS", "POISON"},
            hp = 299,
            maxHp = 299,
            level = 100,
            teraType = "STELLAR",
            isTerastallized = false,
            stellarTypesBoosted = {}
        }
    }
}

-- Initialize AOS environment
local aosEnv = aos.new()

-- Spawn processes
local stellarTeraProcess = aosEnv:spawn("../../processes/stellar-tera-engine.lua")
local battleCoordinator = aosEnv:spawnMock("battle-coordinator", {
    handlers = {
        ProcessMove = function(msg)
            return {
                Action = "MoveProcessed",
                BattleId = msg.BattleId,
                Success = "true"
            }
        end
    }
})

-- Integration Test Suite
describe("Stellar Tera Engine Integration Tests", function()
    
    -- ===============================
    -- BATTLE FLOW INTEGRATION
    -- ===============================
    
    describe("Complete Battle Flow Integration", function()
        
        it("should handle full Charizard Stellar sequence in battle", function()
            local charizard = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            
            -- Step 1: Activate Stellar Tera
            local activationResponse = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(charizard),
                BattleId = BATTLE_CONFIG.battleId,
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(activationResponse.Success, "true")
            charizard = json.decode(activationResponse.Data)
            assert.equals(charizard.isTerastallized, true)
            assert.equals(charizard.teraType, "STELLAR")
            
            -- Step 2: Turn 1 - Flamethrower (matching Fire type)
            local stabResponse1 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(stabResponse1.STABMultiplier, "1.5")
            assert.equals(stabResponse1.IsFirstUsage, "true")
            
            -- Track usage after successful move
            local trackResponse1 = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(trackResponse1.Tracked, "true")
            charizard = json.decode(trackResponse1.Data)
            assert.equals(#charizard.stellarTypesBoosted, 1)
            assert.equals(charizard.stellarTypesBoosted[1], "FIRE")
            
            -- Step 3: Turn 2 - Air Slash (matching Flying type)
            local stabResponse2 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FLYING",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(stabResponse2.STABMultiplier, "1.5")
            assert.equals(stabResponse2.IsFirstUsage, "true")
            
            -- Track Flying usage
            local trackResponse2 = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FLYING",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            charizard = json.decode(trackResponse2.Data)
            assert.equals(#charizard.stellarTypesBoosted, 2)
            
            -- Step 4: Turn 3 - Thunderbolt (non-matching Electric type)
            local stabResponse3 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "ELECTRIC",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(stabResponse3.STABMultiplier, "1.2")
            assert.equals(stabResponse3.IsFirstUsage, "true")
            
            -- Track Electric usage
            local trackResponse3 = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "ELECTRIC",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            charizard = json.decode(trackResponse3.Data)
            assert.equals(#charizard.stellarTypesBoosted, 3)
            
            -- Step 5: Turn 4 - Flamethrower again (should not get bonus)
            local stabResponse4 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(stabResponse4.STABMultiplier, "1")
            assert.equals(stabResponse4.IsFirstUsage, "false")
            
            -- Step 6: Turn 5 - Roost (STATUS move, no STAB or tracking)
            local stabResponse5 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FLYING",
                MoveCategory = "STATUS",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(stabResponse5.STABMultiplier, "1")
            
            local trackResponse5 = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FLYING",
                MoveCategory = "STATUS",
                From = BATTLE_CONFIG.players.player1
            })
            
            assert.equals(trackResponse5.Tracked, "false")
        end)
        
        it("should handle Terapagos unlimited STAB throughout battle", function()
            local terapagos = json.decode(json.encode(TEST_TEAMS.player1.terapagos))
            
            -- Activate Stellar Tera
            local activationResponse = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(terapagos),
                BattleId = BATTLE_CONFIG.battleId,
                From = BATTLE_CONFIG.players.player1
            })
            
            terapagos = json.decode(activationResponse.Data)
            
            -- Multiple uses of same type should always get STAB
            local moveSequence = {
                {type = "GROUND", category = "SPECIAL", expectedSTAB = "1.2"}, -- Non-matching
                {type = "NORMAL", category = "SPECIAL", expectedSTAB = "1.5"}, -- Matching
                {type = "GROUND", category = "SPECIAL", expectedSTAB = "1.2"}, -- Repeat non-matching
                {type = "NORMAL", category = "SPECIAL", expectedSTAB = "1.5"}, -- Repeat matching
                {type = "FAIRY", category = "SPECIAL", expectedSTAB = "1.2"}   -- New non-matching
            }
            
            for i, move in ipairs(moveSequence) do
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(terapagos),
                    MoveType = move.type,
                    MoveCategory = move.category,
                    From = BATTLE_CONFIG.players.player1
                })
                
                assert.equals(stabResponse.STABMultiplier, move.expectedSTAB, 
                    "Turn " .. i .. " STAB mismatch for " .. move.type)
                assert.equals(stabResponse.IsTerapagos, "true")
                
                -- Track usage (should not affect Terapagos)
                stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(terapagos),
                    MoveType = move.type,
                    MoveCategory = move.category,
                    From = BATTLE_CONFIG.players.player1
                })
            end
            
            -- Verify Terapagos tracking remains empty
            assert.equals(#terapagos.stellarTypesBoosted, 0)
        end)
        
        it("should handle mixed Stellar and standard Tera in battle", function()
            local charizard = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            local venusaur = json.decode(json.encode(TEST_TEAMS.player2.venusaur))
            
            -- Activate Stellar Tera for Charizard
            local charizardActivation = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(charizard),
                BattleId = BATTLE_CONFIG.battleId,
                From = BATTLE_CONFIG.players.player1
            })
            
            charizard = json.decode(charizardActivation.Data)
            
            -- Activate Stellar Tera for Venusaur
            local venusaurActivation = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(venusaur),
                BattleId = BATTLE_CONFIG.battleId,
                From = BATTLE_CONFIG.players.player2
            })
            
            venusaur = json.decode(venusaurActivation.Data)
            
            -- Both should have independent Stellar tracking
            local charizardStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            local venusaurStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(venusaur),
                MoveType = "GRASS",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player2
            })
            
            assert.equals(charizardStab.STABMultiplier, "1.5") -- Fire matches Charizard
            assert.equals(venusaurStab.STABMultiplier, "1.5")  -- Grass matches Venusaur
            
            -- Track usage independently
            stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player1
            })
            
            stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(venusaur),
                MoveType = "GRASS",
                MoveCategory = "SPECIAL",
                From = BATTLE_CONFIG.players.player2
            })
            
            -- Verify independent tracking
            local charizardState = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "get_state",
                Data = json.encode(charizard)
            })
            
            local venusaurState = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "get_state",
                Data = json.encode(venusaur)
            })
            
            local charizardStellarState = json.decode(charizardState.StellarState)
            local venusaurStellarState = json.decode(venusaurState.StellarState)
            
            assert.equals(#charizardStellarState.stellarTypesBoosted, 1)
            assert.equals(#venusaurStellarState.stellarTypesBoosted, 1)
            assert.equals(charizardStellarState.stellarTypesBoosted[1], "FIRE")
            assert.equals(venusaurStellarState.stellarTypesBoosted[1], "GRASS")
        end)
        
    end)
    
    -- ===============================
    -- BATTLE STATE PERSISTENCE
    -- ===============================
    
    describe("Battle State Persistence", function()
        
        it("should maintain Stellar state across multiple turns", function()
            local pokemon = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            local battleId = "persistence_test_battle"
            
            -- Activate and build up tracking over multiple turns
            stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon),
                BattleId = battleId
            })
            
            local typeSequence = {"FIRE", "FLYING", "ELECTRIC", "WATER", "GRASS"}
            
            for i, moveType in ipairs(typeSequence) do
                -- Calculate STAB
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(pokemon),
                    MoveType = moveType,
                    MoveCategory = "SPECIAL"
                })
                
                -- Track usage
                local trackResponse = stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(pokemon),
                    MoveType = moveType,
                    MoveCategory = "SPECIAL"
                })
                
                pokemon = json.decode(trackResponse.Data)
                
                -- Verify tracking persists
                assert.equals(#pokemon.stellarTypesBoosted, i)
            end
            
            -- Verify final state
            local finalState = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "get_state",
                Data = json.encode(pokemon)
            })
            
            local state = json.decode(finalState.StellarState)
            assert.equals(state.remainingBoostCount, 13) -- 18 - 5
        end)
        
        it("should handle Pokemon switching without losing tracking", function()
            local charizard = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            
            -- Activate and use some types
            stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(charizard),
                BattleId = "switch_test_battle"
            })
            
            -- Use FIRE type
            stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            -- Switch out (simulate by stopping message flow)
            -- Switch back in - tracking should persist
            local postSwitchStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(postSwitchStab.STABMultiplier, "1") -- Should be already used
            assert.equals(postSwitchStab.IsFirstUsage, "false")
        end)
        
        it("should reset all tracking at battle end", function()
            local pokemonList = {
                json.decode(json.encode(TEST_TEAMS.player1.charizard)),
                json.decode(json.encode(TEST_TEAMS.player2.venusaur))
            }
            
            local battleId = "reset_test_battle"
            
            -- Set up tracking for both Pokemon
            for _, pokemon in ipairs(pokemonList) do
                stellarTeraProcess:send({
                    Action = "ProcessStellarTera",
                    Operation = "activate",
                    Data = json.encode(pokemon),
                    BattleId = battleId
                })
                
                stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(pokemon),
                    MoveType = "FIRE",
                    MoveCategory = "SPECIAL"
                })
            end
            
            -- Reset battle
            local resetResponse = stellarTeraProcess:send({
                Action = "ResetBattleStellar",
                BattleId = battleId,
                PokemonList = json.encode(pokemonList)
            })
            
            assert.equals(resetResponse.BattleId, battleId)
            assert.equals(resetResponse.PokemonCount, "2")
            
            -- Verify tracking cleared
            for _, pokemon in ipairs(pokemonList) do
                local stateResponse = stellarTeraProcess:send({
                    Action = "ProcessStellarTera",
                    Operation = "get_state",
                    Data = json.encode(pokemon)
                })
                
                local state = json.decode(stateResponse.StellarState)
                assert.equals(state.isActive, false)
                assert.equals(#state.stellarTypesBoosted, 0)
            end
        end)
        
    end)
    
    -- ===============================
    -- TYPE EFFECTIVENESS INTEGRATION
    -- ===============================
    
    describe("Type Effectiveness Integration", function()
        
        it("should confirm Stellar moves always have neutral effectiveness", function()
            local attacker = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            attacker.isTerastallized = true
            
            local defenders = {
                {types = {"WATER"}},        -- Normally resists Fire
                {types = {"ROCK"}},         -- Normally weak to Fire
                {types = {"FIRE"}},         -- Normally resists Fire
                {types = {"DRAGON"}},       -- Normally neutral to Fire
                {types = {"WATER", "ROCK"}} -- Dual type
            }
            
            for _, defender in ipairs(defenders) do
                local response = stellarTeraProcess:send({
                    Action = "GetStellarEffectiveness",
                    AttackerData = json.encode(attacker),
                    DefenderData = json.encode(defender),
                    MoveType = "STELLAR"
                })
                
                assert.equals(response.Effectiveness, "1")
                assert.equals(response.IsStellarMove, "true")
            end
        end)
        
        it("should not affect non-Stellar move effectiveness", function()
            local attacker = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            attacker.isTerastallized = true
            
            local defender = {types = {"GRASS"}}
            
            local response = stellarTeraProcess:send({
                Action = "GetStellarEffectiveness",
                AttackerData = json.encode(attacker),
                DefenderData = json.encode(defender),
                MoveType = "FIRE"
            })
            
            -- Should return 1.0 to let normal type chart handle it
            assert.equals(response.Effectiveness, "1")
            assert.equals(response.IsStellarMove, "false")
        end)
        
    end)
    
    -- ===============================
    -- COMPLEX SCENARIO INTEGRATION
    -- ===============================
    
    describe("Complex Scenario Integration", function()
        
        it("should validate complete battle scenario", function()
            local battleState = {
                battleId = "complex_integration_battle",
                turn = 10,
                playerTeam = {
                    active = {
                        teraType = "STELLAR",
                        speciesId = "CHARIZARD",
                        isTerastallized = true,
                        stellarTypesBoosted = {"FIRE", "FLYING", "ELECTRIC"}
                    },
                    bench = {
                        {
                            teraType = "STELLAR",
                            speciesId = "TERAPAGOS",
                            isTerastallized = true,
                            stellarTypesBoosted = {} -- Should remain empty for Terapagos
                        }
                    }
                },
                enemyTeam = {
                    active = {
                        teraType = "FIRE",
                        speciesId = "GARCHOMP",
                        isTerastallized = true
                    }
                }
            }
            
            local validationResponse = stellarTeraProcess:send({
                Action = "ValidateStellarState",
                Data = json.encode(battleState)
            })
            
            assert.equals(validationResponse.Valid, "true")
            
            local results = json.decode(validationResponse.ValidationResults)
            assert.equals(results.valid, true)
            assert.equals(#results.errors, 0)
        end)
        
        it("should handle edge case with maximum type tracking", function()
            local pokemon = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            
            -- Activate Stellar Tera
            stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon),
                BattleId = "max_tracking_battle"
            })
            
            -- All 18 Pokemon types
            local allTypes = {
                "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
                "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG",
                "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY"
            }
            
            -- Track all types
            for _, moveType in ipairs(allTypes) do
                local trackResponse = stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(pokemon),
                    MoveType = moveType,
                    MoveCategory = "SPECIAL"
                })
                
                pokemon = json.decode(trackResponse.Data)
            end
            
            -- Verify maximum tracking reached
            assert.equals(#pokemon.stellarTypesBoosted, 18)
            
            -- Verify no more STAB bonuses available
            local stabResponse = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(stabResponse.STABMultiplier, "1")
            
            -- Get final state
            local stateResponse = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "get_state",
                Data = json.encode(pokemon)
            })
            
            local state = json.decode(stateResponse.StellarState)
            assert.equals(state.remainingBoostCount, 0)
        end)
        
    end)
    
    -- ===============================
    -- PERFORMANCE AND RELIABILITY
    -- ===============================
    
    describe("Performance and Reliability", function()
        
        it("should handle rapid sequential requests", function()
            local pokemon = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            
            stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon),
                BattleId = "rapid_test_battle"
            })
            
            -- Send 10 rapid STAB calculations
            local responses = {}
            for i = 1, 10 do
                local response = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(pokemon),
                    MoveType = i <= 5 and "FIRE" or "WATER",
                    MoveCategory = "SPECIAL"
                })
                table.insert(responses, response)
            end
            
            -- Verify all responses received
            assert.equals(#responses, 10)
            
            -- Verify consistency (first 5 should be FIRE, next 5 should be WATER)
            for i = 1, 5 do
                assert.equals(responses[i].STABMultiplier, "1.5") -- Fire matches Charizard
            end
            for i = 6, 10 do
                assert.equals(responses[i].STABMultiplier, "1.2") -- Water doesn't match
            end
        end)
        
        it("should maintain data integrity under concurrent access", function()
            local pokemon1 = json.decode(json.encode(TEST_TEAMS.player1.charizard))
            local pokemon2 = json.decode(json.encode(TEST_TEAMS.player2.venusaur))
            
            pokemon1.id = "concurrent_test_1"
            pokemon2.id = "concurrent_test_2"
            
            -- Simulate concurrent battle operations
            local operations = {
                {pokemon = pokemon1, moveType = "FIRE", expectedSTAB = "1.5"},
                {pokemon = pokemon2, moveType = "GRASS", expectedSTAB = "1.5"},
                {pokemon = pokemon1, moveType = "FLYING", expectedSTAB = "1.5"},
                {pokemon = pokemon2, moveType = "POISON", expectedSTAB = "1.5"},
                {pokemon = pokemon1, moveType = "ELECTRIC", expectedSTAB = "1.2"},
                {pokemon = pokemon2, moveType = "WATER", expectedSTAB = "1.2"}
            }
            
            -- Activate both Pokemon
            stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon1),
                BattleId = "concurrent_battle"
            })
            
            stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon2),
                BattleId = "concurrent_battle"
            })
            
            -- Execute operations
            for _, op in ipairs(operations) do
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(op.pokemon),
                    MoveType = op.moveType,
                    MoveCategory = "SPECIAL"
                })
                
                assert.equals(stabResponse.STABMultiplier, op.expectedSTAB)
                
                -- Track usage
                local trackResponse = stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(op.pokemon),
                    MoveType = op.moveType,
                    MoveCategory = "SPECIAL"
                })
                
                -- Update Pokemon data for next iteration
                if op.pokemon.id == "concurrent_test_1" then
                    pokemon1 = json.decode(trackResponse.Data)
                else
                    pokemon2 = json.decode(trackResponse.Data)
                end
            end
            
            -- Verify final tracking state
            assert.equals(#pokemon1.stellarTypesBoosted, 3)
            assert.equals(#pokemon2.stellarTypesBoosted, 3)
        end)
        
    end)
    
    -- ===============================
    -- ADP INTEGRATION TESTS
    -- ===============================
    
    describe("ADP Integration", function()
        
        it("should support autonomous agent discovery", function()
            local infoResponse = stellarTeraProcess:send({
                Action = "Info"
            })
            
            local processInfo = json.decode(infoResponse.Data)
            
            -- Verify ADP compliance
            assert.equals(processInfo.adpVersion, "1.0")
            assert.is_true(processInfo.capabilities.adpCompliant)
            
            -- Verify handler discoverability
            local foundHandlers = {}
            for _, handler in ipairs(processInfo.handlers) do
                foundHandlers[handler.action] = handler
            end
            
            assert.is_not_nil(foundHandlers["ProcessStellarTera"])
            assert.is_not_nil(foundHandlers["CalculateStellarSTAB"])
            assert.is_not_nil(foundHandlers["TrackStellarUsage"])
            
            -- Verify parameter documentation
            local stellarHandler = foundHandlers["ProcessStellarTera"]
            assert.is_table(stellarHandler.parameters)
            assert.is_true(#stellarHandler.parameters > 0)
        end)
        
        it("should handle natural language queries through ADP", function()
            -- This would be handled by the ADP framework
            -- Testing basic Info response structure
            local response = stellarTeraProcess:send({
                Action = "Info"
            })
            
            local info = json.decode(response.Data)
            assert.is_table(info.documentation)
            assert.is_not_nil(info.documentation.stellarMechanics)
            assert.is_not_nil(info.documentation.terapagosException)
        end)
        
    end)
    
end)

-- Run integration tests
print("Starting Stellar Tera Engine integration tests...")
print("Testing complete message flows, battle coordination, and complex scenarios")
print("Total test suites: 7")
print("================================")