-- Parity Tests for Stellar Tera Engine
-- Validates against TypeScript reference implementation for mathematical precision

local aos = require("aos-local")
local json = require("json")
local math = require("math")

-- TypeScript Reference Values (extracted from PokéRogue source)
local TYPESCRIPT_REFERENCE = {
    -- STAB multipliers from TypeScript implementation
    stellarMatchingBonus = 1.5,  -- From src/field/pokemon.ts:3714
    stellarNonMatchingBonus = 1.2,  -- From src/field/pokemon.ts:3715
    noBonus = 1.0,
    
    -- Type effectiveness values
    stellarTypeEffectiveness = 1.0,  -- STELLAR vs all types
    
    -- Terapagos species IDs from TypeScript
    terapagosSpecies = {
        "TERAPAGOS",
        "TERAPAGOS_TERASTAL", 
        "TERAPAGOS_STELLAR"
    },
    
    -- Move categories from TypeScript
    moveCategories = {
        PHYSICAL = 0,
        SPECIAL = 1,
        STATUS = 2
    },
    
    -- Sample calculation results from TypeScript
    expectedResults = {
        -- Charizard (Fire/Flying) with Stellar Tera
        charizardFireFirst = 1.5,     -- First Fire move gets 1.5x
        charizardFlyingFirst = 1.5,   -- First Flying move gets 1.5x
        charizardElectricFirst = 1.2, -- First Electric move gets 1.2x
        charizardFireSecond = 1.0,    -- Second Fire move gets 1.0x
        charizardStatusMove = 1.0,    -- STATUS moves never get STAB
        
        -- Terapagos unlimited STAB
        terapagosNormalFirst = 1.5,   -- Natural type match
        terapagosNormalSecond = 1.5,  -- Should still get bonus
        terapagosWaterFirst = 1.2,    -- Non-natural type
        terapagosWaterSecond = 1.2,   -- Should still get bonus
        
        -- Type effectiveness
        stellarVsWater = 1.0,         -- STELLAR vs Water
        stellarVsFire = 1.0,          -- STELLAR vs Fire
        stellarVsDragon = 1.0,        -- STELLAR vs Dragon
        stellarVsWaterGround = 1.0    -- STELLAR vs Water/Ground
    }
}

-- Test Pokemon data matching TypeScript structure
local PARITY_TEST_POKEMON = {
    charizard = {
        id = "parity_charizard_001",
        speciesId = "CHARIZARD",
        species = 6, -- TypeScript species enum value
        types = {"FIRE", "FLYING"},
        level = 100,
        hp = 297,
        maxHp = 297,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {},
        -- TypeScript equivalent properties
        fusionSpecies = nil,
        fusionFormIndex = nil,
        fusionAbilityIndex = 0,
        fusionShiny = false,
        fusionVariant = 0
    },
    pikachu = {
        id = "parity_pikachu_001", 
        speciesId = "PIKACHU",
        species = 25,
        types = {"ELECTRIC"},
        level = 100,
        hp = 274,
        maxHp = 274,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    terapagos = {
        id = "parity_terapagos_001",
        speciesId = "TERAPAGOS",
        species = 1024, -- Hypothetical species number
        types = {"NORMAL"},
        level = 100,
        hp = 290,
        maxHp = 290,
        teraType = "STELLAR", 
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    venusaur = {
        id = "parity_venusaur_001",
        speciesId = "VENUSAUR",
        species = 3,
        types = {"GRASS", "POISON"},
        level = 100,
        hp = 299,
        maxHp = 299,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    }
}

-- Initialize AOS environment
local aosEnv = aos.new()
local stellarTeraProcess = aosEnv:spawn("../../processes/stellar-tera-engine.lua")

-- Parity Test Suite
describe("Stellar Tera Engine Parity Tests", function()
    
    -- ===============================
    -- STAB CALCULATION PARITY
    -- ===============================
    
    describe("STAB Calculation Parity", function()
        
        it("should match TypeScript STAB values for Charizard Fire sequence", function()
            local charizard = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            charizard.isTerastallized = true
            charizard.stellarTypesBoosted = {}
            
            -- First Fire move (should match TypeScript 1.5x)
            local firstFireStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            local actualSTAB1 = tonumber(firstFireStab.STABMultiplier)
            assert.equals(actualSTAB1, TYPESCRIPT_REFERENCE.expectedResults.charizardFireFirst,
                "First Fire STAB should match TypeScript reference")
            
            -- Track the usage
            local trackResponse = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            charizard = json.decode(trackResponse.Data)
            
            -- Second Fire move (should match TypeScript 1.0x)
            local secondFireStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE", 
                MoveCategory = "SPECIAL"
            })
            
            local actualSTAB2 = tonumber(secondFireStab.STABMultiplier)
            assert.equals(actualSTAB2, TYPESCRIPT_REFERENCE.expectedResults.charizardFireSecond,
                "Second Fire STAB should match TypeScript reference")
        end)
        
        it("should match TypeScript STAB values for multi-type sequence", function()
            local charizard = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            charizard.isTerastallized = true
            charizard.stellarTypesBoosted = {}
            
            -- Test sequence matching TypeScript behavior
            local testSequence = {
                {type = "FIRE", expected = TYPESCRIPT_REFERENCE.expectedResults.charizardFireFirst},
                {type = "FLYING", expected = TYPESCRIPT_REFERENCE.expectedResults.charizardFlyingFirst},
                {type = "ELECTRIC", expected = TYPESCRIPT_REFERENCE.expectedResults.charizardElectricFirst}
            }
            
            for i, test in ipairs(testSequence) do
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(charizard),
                    MoveType = test.type,
                    MoveCategory = "SPECIAL"
                })
                
                local actualSTAB = tonumber(stabResponse.STABMultiplier)
                assert.equals(actualSTAB, test.expected,
                    "STAB for " .. test.type .. " should match TypeScript reference")
                
                -- Track usage
                local trackResponse = stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(charizard),
                    MoveType = test.type,
                    MoveCategory = "SPECIAL"
                })
                
                charizard = json.decode(trackResponse.Data)
            end
        end)
        
        it("should match TypeScript STATUS move handling", function()
            local charizard = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            charizard.isTerastallized = true
            charizard.stellarTypesBoosted = {}
            
            local statusStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(charizard),
                MoveType = "FIRE",
                MoveCategory = "STATUS"
            })
            
            local actualSTAB = tonumber(statusStab.STABMultiplier)
            assert.equals(actualSTAB, TYPESCRIPT_REFERENCE.expectedResults.charizardStatusMove,
                "STATUS move STAB should match TypeScript reference")
        end)
        
    end)
    
    -- ===============================
    -- TERAPAGOS EXCEPTION PARITY
    -- ===============================
    
    describe("Terapagos Exception Parity", function()
        
        it("should match TypeScript unlimited STAB for Terapagos", function()
            local terapagos = json.decode(json.encode(PARITY_TEST_POKEMON.terapagos))
            terapagos.isTerastallized = true
            terapagos.stellarTypesBoosted = {}
            
            -- Test natural type (NORMAL) unlimited usage
            for i = 1, 3 do
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(terapagos),
                    MoveType = "NORMAL",
                    MoveCategory = "PHYSICAL"
                })
                
                local actualSTAB = tonumber(stabResponse.STABMultiplier)
                assert.equals(actualSTAB, TYPESCRIPT_REFERENCE.expectedResults.terapagosNormalFirst,
                    "Terapagos NORMAL STAB iteration " .. i .. " should match TypeScript")
                assert.equals(stabResponse.IsTerapagos, "true")
                
                -- Track usage (should not affect Terapagos)
                stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(terapagos),
                    MoveType = "NORMAL",
                    MoveCategory = "PHYSICAL"
                })
            end
            
            -- Test non-natural type unlimited usage
            for i = 1, 3 do
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(terapagos),
                    MoveType = "WATER",
                    MoveCategory = "SPECIAL"
                })
                
                local actualSTAB = tonumber(stabResponse.STABMultiplier)
                assert.equals(actualSTAB, TYPESCRIPT_REFERENCE.expectedResults.terapagosWaterFirst,
                    "Terapagos WATER STAB iteration " .. i .. " should match TypeScript")
            end
        end)
        
        it("should recognize all Terapagos forms like TypeScript", function()
            for _, speciesId in ipairs(TYPESCRIPT_REFERENCE.terapagosSpecies) do
                local pokemon = {
                    id = "test_" .. speciesId,
                    speciesId = speciesId,
                    types = {"NORMAL"},
                    isTerastallized = true,
                    teraType = "STELLAR",
                    stellarTypesBoosted = {}
                }
                
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(pokemon),
                    MoveType = "NORMAL",
                    MoveCategory = "PHYSICAL"
                })
                
                assert.equals(stabResponse.IsTerapagos, "true",
                    speciesId .. " should be recognized as Terapagos")
                assert.equals(tonumber(stabResponse.STABMultiplier), 1.5,
                    speciesId .. " should get matching type STAB")
            end
        end)
        
    end)
    
    -- ===============================
    -- USAGE TRACKING PARITY
    -- ===============================
    
    describe("Usage Tracking Parity", function()
        
        it("should track types exactly like TypeScript stellarTypesBoosted array", function()
            local venusaur = json.decode(json.encode(PARITY_TEST_POKEMON.venusaur))
            venusaur.isTerastallized = true
            venusaur.stellarTypesBoosted = {}
            
            -- Sequence of types to test (matches TypeScript test scenarios)
            local typeSequence = {"GRASS", "POISON", "WATER", "FIRE", "ELECTRIC"}
            
            for i, moveType in ipairs(typeSequence) do
                -- Calculate STAB first
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(venusaur),
                    MoveType = moveType,
                    MoveCategory = "SPECIAL"
                })
                
                -- Verify STAB matches expected
                local expectedSTAB = (moveType == "GRASS" or moveType == "POISON") and 1.5 or 1.2
                assert.equals(tonumber(stabResponse.STABMultiplier), expectedSTAB)
                
                -- Track usage
                local trackResponse = stellarTeraProcess:send({
                    Action = "TrackStellarUsage",
                    Data = json.encode(venusaur),
                    MoveType = moveType,
                    MoveCategory = "SPECIAL"
                })
                
                venusaur = json.decode(trackResponse.Data)
                
                -- Verify tracking array matches TypeScript behavior
                assert.equals(#venusaur.stellarTypesBoosted, i,
                    "Tracking array length should match TypeScript after " .. i .. " types")
                
                -- Verify the specific type was added
                local found = false
                for _, trackedType in ipairs(venusaur.stellarTypesBoosted) do
                    if trackedType == moveType then
                        found = true
                        break
                    end
                end
                assert.is_true(found, moveType .. " should be in tracking array")
            end
        end)
        
        it("should handle duplicate prevention like TypeScript", function()
            local pikachu = json.decode(json.encode(PARITY_TEST_POKEMON.pikachu))
            pikachu.isTerastallized = true
            pikachu.stellarTypesBoosted = {"ELECTRIC"} -- Pre-populate
            
            -- Try to track ELECTRIC again
            local trackResponse = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pikachu),
                MoveType = "ELECTRIC",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(trackResponse.Tracked, "false")
            
            local updatedPikachu = json.decode(trackResponse.Data)
            assert.equals(#updatedPikachu.stellarTypesBoosted, 1,
                "Should not add duplicate types like TypeScript")
        end)
        
        it("should exclude STATUS moves from tracking like TypeScript", function()
            local charizard = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            charizard.isTerastallized = true
            charizard.stellarTypesBoosted = {}
            
            -- Try to track STATUS move
            local trackResponse = stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(charizard),
                MoveType = "FLYING",
                MoveCategory = "STATUS"
            })
            
            assert.equals(trackResponse.Tracked, "false")
            
            local updatedCharizard = json.decode(trackResponse.Data)
            assert.equals(#updatedCharizard.stellarTypesBoosted, 0,
                "STATUS moves should not be tracked like TypeScript")
        end)
        
    end)
    
    -- ===============================
    -- TYPE EFFECTIVENESS PARITY
    -- ===============================
    
    describe("Type Effectiveness Parity", function()
        
        it("should match TypeScript STELLAR type effectiveness values", function()
            local attacker = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            attacker.isTerastallized = true
            
            -- Test against various defender types
            local defenderTypes = {
                {types = {"WATER"}, expected = TYPESCRIPT_REFERENCE.expectedResults.stellarVsWater},
                {types = {"FIRE"}, expected = TYPESCRIPT_REFERENCE.expectedResults.stellarVsFire},
                {types = {"DRAGON"}, expected = TYPESCRIPT_REFERENCE.expectedResults.stellarVsDragon},
                {types = {"WATER", "GROUND"}, expected = TYPESCRIPT_REFERENCE.expectedResults.stellarVsWaterGround}
            }
            
            for _, defenderTest in ipairs(defenderTypes) do
                local response = stellarTeraProcess:send({
                    Action = "GetStellarEffectiveness",
                    AttackerData = json.encode(attacker),
                    DefenderData = json.encode({types = defenderTest.types}),
                    MoveType = "STELLAR"
                })
                
                local actualEffectiveness = tonumber(response.Effectiveness)
                assert.equals(actualEffectiveness, defenderTest.expected,
                    "STELLAR vs " .. table.concat(defenderTest.types, "/") .. " should match TypeScript")
            end
        end)
        
    end)
    
    -- ===============================
    -- MATHEMATICAL PRECISION PARITY
    -- ===============================
    
    describe("Mathematical Precision Parity", function()
        
        it("should use exact floating point values like TypeScript", function()
            -- Test precise STAB multiplier values
            local pokemon = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {}
            
            -- Matching type STAB (should be exactly 1.5)
            local matchingStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            local actualMatching = tonumber(matchingStab.STABMultiplier)
            assert.equals(actualMatching, 1.5)
            assert.is_true(math.abs(actualMatching - 1.5) < 0.0001, "Exact 1.5 precision required")
            
            -- Non-matching type STAB (should be exactly 1.2)
            local nonMatchingStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "WATER",
                MoveCategory = "SPECIAL"
            })
            
            local actualNonMatching = tonumber(nonMatchingStab.STABMultiplier)
            assert.equals(actualNonMatching, 1.2)
            assert.is_true(math.abs(actualNonMatching - 1.2) < 0.0001, "Exact 1.2 precision required")
        end)
        
        it("should handle edge case calculations like TypeScript", function()
            -- Test maximum tracking scenario
            local pokemon = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            pokemon.isTerastallized = true
            pokemon.stellarTypesBoosted = {
                "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
                "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG",
                "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY"
            }
            
            -- Should return 1.0 for any type now
            local stabResponse = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(tonumber(stabResponse.STABMultiplier), 1.0,
                "All types exhausted should return 1.0 like TypeScript")
        end)
        
    end)
    
    -- ===============================
    -- COMPLEX SCENARIO PARITY
    -- ===============================
    
    describe("Complex Scenario Parity", function()
        
        it("should handle TypeScript battle scenario exactly", function()
            -- Recreate complex scenario from TypeScript tests
            local charizard = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            charizard.isTerastallized = true
            charizard.stellarTypesBoosted = {}
            
            -- Simulate TypeScript moveEffectPhase sequence
            local moveSequence = {
                {type = "FIRE", category = "SPECIAL", turnOrder = 1},
                {type = "FLYING", category = "PHYSICAL", turnOrder = 2},
                {type = "ELECTRIC", category = "SPECIAL", turnOrder = 3},
                {type = "FIRE", category = "SPECIAL", turnOrder = 4}, -- Repeat
                {type = "ROOST", category = "STATUS", turnOrder = 5}   -- STATUS move
            }
            
            local expectedResults = {1.5, 1.5, 1.2, 1.0, 1.0}
            
            for i, move in ipairs(moveSequence) do
                local stabResponse = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(charizard),
                    MoveType = move.type,
                    MoveCategory = move.category
                })
                
                assert.equals(tonumber(stabResponse.STABMultiplier), expectedResults[i],
                    "Turn " .. move.turnOrder .. " STAB should match TypeScript sequence")
                
                -- Track if not STATUS
                if move.category ~= "STATUS" then
                    local trackResponse = stellarTeraProcess:send({
                        Action = "TrackStellarUsage",
                        Data = json.encode(charizard),
                        MoveType = move.type,
                        MoveCategory = move.category
                    })
                    
                    charizard = json.decode(trackResponse.Data)
                end
            end
            
            -- Final tracking should match TypeScript
            assert.equals(#charizard.stellarTypesBoosted, 3, 
                "Final tracking count should match TypeScript")
        end)
        
        it("should handle multi-Pokemon battle like TypeScript", function()
            local pokemon1 = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
            local pokemon2 = json.decode(json.encode(PARITY_TEST_POKEMON.venusaur))
            
            pokemon1.isTerastallized = true
            pokemon1.stellarTypesBoosted = {}
            pokemon2.isTerastallized = true  
            pokemon2.stellarTypesBoosted = {}
            
            -- Independent tracking like TypeScript
            local p1FireStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon1),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            local p2GrassStab = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB", 
                Data = json.encode(pokemon2),
                MoveType = "GRASS",
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(tonumber(p1FireStab.STABMultiplier), 1.5)
            assert.equals(tonumber(p2GrassStab.STABMultiplier), 1.5)
            
            -- Track for both
            stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon1),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            stellarTeraProcess:send({
                Action = "TrackStellarUsage",
                Data = json.encode(pokemon2),
                MoveType = "GRASS",
                MoveCategory = "SPECIAL"
            })
            
            -- Cross-pokemon usage should be independent
            local p1FireSecond = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon1),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
            
            local p2GrassSecond = stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon2),
                MoveType = "GRASS", 
                MoveCategory = "SPECIAL"
            })
            
            assert.equals(tonumber(p1FireSecond.STABMultiplier), 1.0) -- Used by P1
            assert.equals(tonumber(p2GrassSecond.STABMultiplier), 1.0) -- Used by P2
        end)
        
    end)
    
    -- ===============================
    -- REGRESSION PREVENTION PARITY
    -- ===============================
    
    describe("Regression Prevention Parity", function()
        
        it("should maintain exact TypeScript behavior after updates", function()
            -- Comprehensive regression test against known TypeScript values
            local testCases = {
                {
                    name = "Charizard Fire first use",
                    pokemon = {speciesId = "CHARIZARD", types = {"FIRE", "FLYING"}, isTerastallized = true, stellarTypesBoosted = {}},
                    moveType = "FIRE",
                    expected = 1.5
                },
                {
                    name = "Pikachu Electric non-matching",
                    pokemon = {speciesId = "PIKACHU", types = {"ELECTRIC"}, isTerastallized = true, stellarTypesBoosted = {}},
                    moveType = "WATER",
                    expected = 1.2
                },
                {
                    name = "Terapagos unlimited normal",
                    pokemon = {speciesId = "TERAPAGOS", types = {"NORMAL"}, isTerastallized = true, stellarTypesBoosted = {"NORMAL"}},
                    moveType = "NORMAL", 
                    expected = 1.5
                },
                {
                    name = "Used type no bonus",
                    pokemon = {speciesId = "CHARIZARD", types = {"FIRE", "FLYING"}, isTerastallized = true, stellarTypesBoosted = {"FIRE"}},
                    moveType = "FIRE",
                    expected = 1.0
                }
            }
            
            for _, testCase in ipairs(testCases) do
                local response = stellarTeraProcess:send({
                    Action = "CalculateStellarSTAB",
                    Data = json.encode(testCase.pokemon),
                    MoveType = testCase.moveType,
                    MoveCategory = "SPECIAL"
                })
                
                assert.equals(tonumber(response.STABMultiplier), testCase.expected,
                    testCase.name .. " should match TypeScript reference")
            end
        end)
        
    end)
    
end)

-- Performance Benchmarking (optional for parity validation)
describe("Performance Parity Benchmarks", function()
    
    it("should execute STAB calculations within TypeScript performance bounds", function()
        local pokemon = json.decode(json.encode(PARITY_TEST_POKEMON.charizard))
        pokemon.isTerastallized = true
        pokemon.stellarTypesBoosted = {}
        
        local startTime = os.clock()
        
        -- Perform 1000 STAB calculations
        for i = 1, 1000 do
            stellarTeraProcess:send({
                Action = "CalculateStellarSTAB",
                Data = json.encode(pokemon),
                MoveType = "FIRE",
                MoveCategory = "SPECIAL"
            })
        end
        
        local endTime = os.clock()
        local duration = endTime - startTime
        
        -- Should complete within reasonable time (TypeScript typically < 10ms for 1000 calcs)
        assert.is_true(duration < 1.0, "Performance should be comparable to TypeScript")
    end)
    
end)

-- Run parity tests
print("Starting Stellar Tera Engine parity tests...")
print("Validating against TypeScript reference implementation")
print("Focus: Mathematical precision, STAB calculations, usage tracking")
print("Total test suites: 8")
print("================================")