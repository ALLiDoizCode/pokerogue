-- Unit Tests for Stellar Tera Engine
-- Tests Stellar-specific STAB calculations, usage tracking, and Terapagos exceptions

local aolite = require("aolite")
local json = require("json")

-- Test Constants
local TEST_POKEMON = {
    charizard = {
        id = "charizard_001",
        speciesId = "CHARIZARD",
        types = {"FIRE", "FLYING"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    pikachu = {
        id = "pikachu_001",
        speciesId = "PIKACHU",
        types = {"ELECTRIC"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    terapagos = {
        id = "terapagos_001",
        speciesId = "TERAPAGOS",
        types = {"NORMAL"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    terapagos_stellar = {
        id = "terapagos_stellar_001",
        speciesId = "TERAPAGOS_STELLAR",
        types = {"NORMAL"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    }
}

-- Initialize AO environment
local ao = aolite.new()

-- Load Stellar Tera Engine process
local stellarTeraProcess = ao:spawn("../../processes/stellar-tera-engine.lua")

-- Test Suite
describe("Stellar Tera Engine Unit Tests", function()
    
    -- ===============================
    -- STELLAR ACTIVATION TESTS
    -- ===============================
    
    describe("Stellar Tera Activation", function()
        
        it("should activate Stellar Tera for regular Pokemon", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            
            local response = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon),
                BattleId = "battle_001"
            })
            
            assert.equals(response.Success, "true")
            
            local updatedPokemon = json.decode(response.Data)
            assert.equals(updatedPokemon.isTerastallized, true)
            assert.equals(updatedPokemon.teraType, "STELLAR")
            assert.is_table(updatedPokemon.stellarTypesBoosted)
            assert.equals(#updatedPokemon.stellarTypesBoosted, 0)
        end)
        
        it("should activate Stellar Tera for Terapagos", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.terapagos))
            
            local response = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode(pokemon),
                BattleId = "battle_002"
            })
            
            assert.equals(response.Success, "true")
            
            local updatedPokemon = json.decode(response.Data)
            assert.equals(updatedPokemon.isTerastallized, true)
            assert.equals(updatedPokemon.teraType, "STELLAR")
            assert.is_table(updatedPokemon.stellarTypesBoosted)
            assert.equals(#updatedPokemon.stellarTypesBoosted, 0)
        end)
        
        it("should handle invalid Pokemon data", function()
            local response = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "activate",
                Data = json.encode({invalid = true}),
                BattleId = "battle_003"
            })
            
            -- Should receive error response
            assert.is_nil(response.Success)
            assert.is_not_nil(response.ErrorCode)
        end)
        
    end)
    
    -- ===============================
    -- STAB CALCULATION TESTS
    -- ===============================
    
    describe("Stellar STAB Calculations", function()
        
        it("should calculate 1.5x STAB for matching natural type (first use)", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.STABMultiplier, "1.5")
            assert.equals(response.IsFirstUsage, "true")
            assert.equals(response.IsTerapagos, "false")
        end)
        
        it("should calculate 1.2x STAB for non-matching type (first use)", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "ELECTRIC",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.STABMultiplier, "1.2")
            assert.equals(response.IsFirstUsage, "true")
            assert.equals(response.IsTerapagos, "false")
        end)
        
        it("should return 1.0x STAB for already boosted type", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {"FIRE"}
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.STABMultiplier, "1")
            assert.equals(response.IsFirstUsage, "false")
        end)
        
        it("should return 1.0x STAB for STATUS moves", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "STATUS"
            })
            
            assert.equals(response.STABMultiplier, "1")
        end)
        
        it("should return 1.0x STAB when not terastallized", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = false
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.STABMultiplier, "1")
        end)
        
    end)
    
    -- ===============================
    -- TERAPAGOS EXCEPTION TESTS
    -- ===============================
    
    describe("Terapagos Exception Handling", function()
        
        it("should give Terapagos unlimited 1.5x STAB for matching types", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.terapagos))
            pokemon.isTerastallized = true
            
            -- First use
            local response1 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "NORMAL",
                MoveCategory = "PHYSICAL"
            })
            assert.equals(response1.STABMultiplier, "1.5")
            assert.equals(response1.IsTerapagos, "true")
            
            -- Track usage (shouldn't affect Terapagos)
            stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon),
                MoveType = "NORMAL",
                MoveCategory = "PHYSICAL"
            })
            
            -- Second use - should still get bonus
            local response2 = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "NORMAL",
                MoveCategory = "PHYSICAL"
            })
            assert.equals(response2.STABMultiplier, "1.5")
            assert.equals(response2.IsTerapagos, "true")
        end)
        
        it("should give Terapagos unlimited 1.2x STAB for non-matching types", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.terapagos))
            pokemon.isTerastallized = true
            
            -- Multiple uses of non-matching type
            for i = 1, 3 do
                local response = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(pokemon),
                    MoveType = "WATER",
                    MoveCategory = "SPECIAL"
                })
                assert.equals(response.STABMultiplier, "1.2")
                assert.equals(response.IsTerapagos, "true")
                
                -- Track usage (shouldn't affect Terapagos)
                stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(pokemon),
                    MoveType = "WATER",
                    MoveCategory = "SPECIAL"
                })
            end
        end)
        
        it("should recognize all Terapagos forms", function()
            local forms = {"TERAPAGOS", "TERAPAGOS_TERASTAL", "TERAPAGOS_STELLAR"}
            
            for _, form in ipairs(forms) do
                local pokemon = {
                    id = "test_" .. form,
                    speciesId = form,
                    types = {"NORMAL"},
                    hp = 100,
                    teraType = "STELLAR",
                    isTerastallized = true,
                    stellarTypesBoosted = {}
                }
                
                local response = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(pokemon),
                    MoveType = "NORMAL",
                    MoveCategory = "PHYSICAL"
                })
                
                assert.equals(response.IsTerapagos, "true")
                assert.equals(response.STABMultiplier, "1.5")
            end
        end)
        
    end)
    
    -- ===============================
    -- USAGE TRACKING TESTS
    -- ===============================
    
    describe("Stellar Usage Tracking", function()
        
        it("should track first-time type usage", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.pikachu))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local response = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon),
                MoveType = "ELECTRIC",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.Tracked, "true")
            
            local boostedTypes = json.decode(response.StellarTypesBoosted)
            assert.equals(#boostedTypes, 1)
            assert.equals(boostedTypes[1], "ELECTRIC")
            assert.equals(response.RemainingBoosts, "17")
        end)
        
        it("should not track duplicate type usage", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.pikachu))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {"ELECTRIC"}
            
            local response = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon),
                MoveType = "ELECTRIC",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.Tracked, "false")
            
            local boostedTypes = json.decode(response.StellarTypesBoosted)
            assert.equals(#boostedTypes, 1)
        end)
        
        it("should not track STATUS moves", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.pikachu))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local response = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon),
                MoveType = "ELECTRIC",
                MoveCategory = "STATUS"
            })
            
            assert.equals(response.Tracked, "false")
            
            local boostedTypes = json.decode(response.StellarTypesBoosted)
            assert.equals(#boostedTypes, 0)
        end)
        
        it("should not track usage for Terapagos", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.terapagos))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local response = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon),
                MoveType = "NORMAL",
                MoveCategory = "PHYSICAL"
            })
            
            assert.equals(response.Tracked, "true") -- Success but no tracking
            
            local boostedTypes = json.decode(response.StellarTypesBoosted)
            assert.equals(#boostedTypes, 0) -- Should remain empty for Terapagos
        end)
        
    end)
    
    -- ===============================
    -- MULTI-TYPE SCENARIO TESTS
    -- ===============================
    
    describe("Multi-Type Pokemon Scenarios", function()
        
        it("should handle Charizard multi-type sequence correctly", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local moveSequence = {
                {type = "FIRE", category = "SPECIAL"},      -- Matching: 1.5x
                {type = "FLYING", category = "PHYSICAL"},   -- Matching: 1.5x
                {type = "ELECTRIC", category = "SPECIAL"},  -- Non-matching: 1.2x
                {type = "FIRE", category = "SPECIAL"}       -- Already used: 1.0x
            }
            
            local response = stellarTeraProcess:send({
                Action = "ProcessMultiTypeStellar",
                Data = json.encode(pokemon),
                MoveSequence = json.encode(moveSequence)
            })
            
            local results = json.decode(response.Results)
            assert.equals(results[1].stabMultiplier, 1.5)
            assert.equals(results[1].tracked, true)
            
            assert.equals(results[2].stabMultiplier, 1.5)
            assert.equals(results[2].tracked, true)
            
            assert.equals(results[3].stabMultiplier, 1.2)
            assert.equals(results[3].tracked, true)
            
            assert.equals(results[4].stabMultiplier, 1)
            assert.equals(results[4].tracked, true)
            
            local updatedPokemon = json.decode(response.UpdatedPokemonData)
            assert.equals(#updatedPokemon.stellarTypesBoosted, 3)
        end)
        
        it("should filter STATUS moves from tracking", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            local moveSequence = {
                {type = "FIRE", category = "STATUS"},
                {type = "FIRE", category = "SPECIAL"},
                {type = "FLYING", category = "STATUS"},
                {type = "FLYING", category = "PHYSICAL"}
            }
            
            local response = stellarTeraProcess:send({
                Action = "ProcessMultiTypeStellar",
                Data = json.encode(pokemon),
                MoveSequence = json.encode(moveSequence)
            })
            
            local results = json.decode(response.Results)
            assert.equals(results[1].stabMultiplier, 1)  -- STATUS: no STAB
            assert.equals(results[2].stabMultiplier, 1.5) -- First FIRE attack
            assert.equals(results[3].stabMultiplier, 1)  -- STATUS: no STAB
            assert.equals(results[4].stabMultiplier, 1.5) -- First FLYING attack
            
            local updatedPokemon = json.decode(response.UpdatedPokemonData)
            assert.equals(#updatedPokemon.stellarTypesBoosted, 2) -- Only FIRE and FLYING
        end)
        
    end)
    
    -- ===============================
    -- STATE MANAGEMENT TESTS
    -- ===============================
    
    describe("Stellar State Management", function()
        
        it("should reset Stellar state correctly", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.pikachu))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {"ELECTRIC", "WATER", "FIRE"}
            
            local response = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "reset",
                Data = json.encode(pokemon),
                BattleId = "battle_004"
            })
            
            assert.equals(response.Success, "true")
            
            local updatedPokemon = json.decode(response.Data)
            assert.equals(updatedPokemon.isTerastallized, false)
            assert.equals(#updatedPokemon.stellarTypesBoosted, 0)
        end)
        
        it("should get Stellar state information", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {"FIRE", "WATER"}
            
            local response = stellarTeraProcess:send({
                Action = "ProcessStellarTera",
                Operation = "get_state",
                Data = json.encode(pokemon)
            })
            
            local state = json.decode(response.StellarState)
            assert.equals(state.isActive, true)
            assert.equals(#state.stellarTypesBoosted, 2)
            assert.equals(state.isTerapagos, false)
            assert.equals(state.remainingBoostCount, 16)
        end)
        
        it("should reset battle-wide Stellar tracking", function()
            local pokemonList = {
                json.decode(json.encode(TEST_POKEMON.charizard)),
                json.decode(json.encode(TEST_POKEMON.pikachu))
            }
            
            for _, pokemon in ipairs(pokemonList) do
                pokemon.isTerastallized = true
                pokemon.stellarTypesBoosted = {"FIRE", "WATER"}
            end
            
            local response = stellarTeraProcess:send({
                Action = "ResetBattleStellar",
                BattleId = "battle_005",
                PokemonList = json.encode(pokemonList)
            })
            
            assert.equals(response.BattleId, "battle_005")
            assert.equals(response.PokemonCount, "2")
        end)
        
    end)
    
    -- ===============================
    -- STATE VALIDATION TESTS
    -- ===============================
    
    describe("Stellar State Validation", function()
        
        it("should validate correct Stellar state", function()
            local battleState = {
                playerTeam = {
                    pokemon1 = {
                        teraType = "STELLAR",
                        stellarTypesBoosted = {"FIRE", "WATER"},
                        speciesId = "CHARIZARD"
                    }
                },
                enemyTeam = {
                    pokemon1 = {
                        teraType = "STELLAR",
                        stellarTypesBoosted = {"DARK"},
                        speciesId = "UMBREON"
                    }
                }
            }
            
            local response = stellarTeraProcess:send({
                Action = "ValidateStellarState",
                Data = json.encode(battleState)
            })
            
            assert.equals(response.Valid, "true")
        end)
        
        it("should detect duplicate Stellar boosts", function()
            local battleState = {
                playerTeam = {
                    pokemon1 = {
                        teraType = "STELLAR",
                        stellarTypesBoosted = {"FIRE", "WATER", "FIRE"}, -- Duplicate
                        speciesId = "CHARIZARD"
                    }
                }
            }
            
            local response = stellarTeraProcess:send({
                Action = "ValidateStellarState",
                Data = json.encode(battleState)
            })
            
            assert.equals(response.Valid, "false")
            
            local results = json.decode(response.ValidationResults)
            assert.is_true(#results.errors > 0)
        end)
        
        it("should warn about Terapagos with tracking", function()
            local battleState = {
                playerTeam = {
                    pokemon1 = {
                        teraType = "STELLAR",
                        stellarTypesBoosted = {"NORMAL"}, -- Shouldn't have tracking
                        speciesId = "TERAPAGOS"
                    }
                }
            }
            
            local response = stellarTeraProcess:send({
                Action = "ValidateStellarState",
                Data = json.encode(battleState)
            })
            
            local results = json.decode(response.ValidationResults)
            assert.is_true(#results.warnings > 0)
        end)
        
    end)
    
    -- ===============================
    -- TYPE EFFECTIVENESS TESTS
    -- ===============================
    
    describe("Stellar Type Effectiveness", function()
        
        it("should return 1.0x effectiveness for Stellar moves", function()
            local attacker = json.decode(json.encode(TEST_POKEMON.charizard))
            attacker.isTerastallized = true
            
            local defender = {
                types = {"WATER", "GROUND"}
            }
            
            local response = stellarTeraProcess:send({
                Action = "GetStellarEffectiveness",
                AttackerData = json.encode(attacker),
                DefenderData = json.encode(defender),
                MoveType = "STELLAR"
            })
            
            assert.equals(response.Effectiveness, "1")
            assert.equals(response.IsStellarMove, "true")
        end)
        
        it("should not affect non-Stellar move effectiveness", function()
            local attacker = json.decode(json.encode(TEST_POKEMON.charizard))
            attacker.isTerastallized = true
            
            local defender = {
                types = {"GRASS"}
            }
            
            local response = stellarTeraProcess:send({
                Action = "GetStellarEffectiveness",
                AttackerData = json.encode(attacker),
                DefenderData = json.encode(defender),
                MoveType = "FIRE"
            })
            
            -- Should return nil/1.0 to let normal type chart handle it
            assert.equals(response.Effectiveness, "1")
            assert.equals(response.IsStellarMove, "false")
        end)
        
    end)
    
    -- ===============================
    -- ERROR HANDLING TESTS
    -- ===============================
    
    describe("Error Handling", function()
        
        it("should handle missing Pokemon data", function()
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(nil),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(response.STABMultiplier, "1")
        end)
        
        it("should handle missing move type", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon)
                -- Missing MoveType
            })
            
            assert.equals(response.STABMultiplier, "1")
        end)
        
        it("should handle corrupted stellarTypesBoosted array", function()
            local pokemon = json.decode(json.encode(TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = "not_an_array" -- Corrupted
            
            local response = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            -- Should handle gracefully
            assert.is_not_nil(response.STABMultiplier)
        end)
        
    end)
    
    -- ===============================
    -- ADP COMPLIANCE TESTS
    -- ===============================
    
    describe("ADP v1.0 Compliance", function()
        
        it("should respond to Info action with complete metadata", function()
            local response = stellarTeraProcess:send({
                Action = "Info"
            })
            
            local info = json.decode(response.Data)
            assert.equals(info.Name, "Stellar Tera Engine")
            assert.equals(info.adpVersion, "1.0")
            assert.is_table(info.handlers)
            assert.is_true(#info.handlers > 0)
            assert.is_table(info.capabilities)
            assert.is_true(info.capabilities.adpCompliant)
            assert.is_table(info.constants)
            assert.equals(info.constants.stellarMatchingBonus, 1.5)
            assert.equals(info.constants.stellarNonMatchingBonus, 1.2)
        end)
        
        it("should respond to Ping action", function()
            local response = stellarTeraProcess:send({
                Action = "Ping"
            })
            
            assert.equals(response.Action, "Pong")
            assert.equals(response.Data, "pong")
            assert.equals(response.ProcessType, "StellarTeraEngine")
        end)
        
        it("should respond to HealthCheck action", function()
            local response = stellarTeraProcess:send({
                Action = "HealthCheck"
            })
            
            assert.equals(response.Action, "HealthCheckResponse")
            assert.equals(response.Status, "healthy")
            assert.is_not_nil(response.Version)
            assert.is_not_nil(response.ActiveBattles)
        end)
        
    end)
    
end)

-- Run tests
print("Starting Stellar Tera Engine unit tests...")
print("Testing Stellar-specific STAB calculations, usage tracking, and Terapagos exceptions")
print("Total test suites: 10")
print("================================")