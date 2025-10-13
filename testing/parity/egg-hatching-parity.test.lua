-- egg-hatching-parity.test.lua
-- Parity tests comparing Egg Hatching Engine against TypeScript reference
-- Ensures exact mechanical and timing parity

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_FILE = "../../processes/egg-hatching-engine.lua"

-- TypeScript reference values from src/data/egg.ts and src/balance/rates.ts
local TypeScriptReference = {
    -- Wave to step conversion
    STEPS_PER_WAVE = 256,
    
    -- Hatch waves by tier
    HATCH_WAVES = {
        COMMON = 10,
        RARE = 25,
        EPIC = 50,
        LEGENDARY = 100,
        MANAPHY = 50
    },
    
    -- Step requirements (waves * steps per wave)
    STEP_REQUIREMENTS = {
        COMMON = 2560,   -- 10 * 256
        RARE = 6400,     -- 25 * 256
        EPIC = 12800,    -- 50 * 256
        LEGENDARY = 25600, -- 100 * 256
        MANAPHY = 12800  -- 50 * 256
    },
    
    -- Incubation modifiers
    INCUBATION = {
        FLAME_BODY = 2.0,
        OVAL_CHARM = 1.5,
        HATCHING_POWER = {
            [1] = 1.2,
            [2] = 1.5,
            [3] = 2.0
        }
    },
    
    -- Special rates
    MANAPHY_EGG_MANAPHY_RATE = 8, -- 1/8 chance
    SAME_SPECIES_EGG_HA_RATE = 10, -- 1/10 chance
    GACHA_EGG_HA_RATE = 192, -- 1/192 chance
    
    -- Base friendship for hatched Pokemon
    BASE_FRIENDSHIP = 70,
    
    -- Animation timing (milliseconds)
    ANIMATION = {
        PRE_HATCH_DURATION = 1000,
        CRACK_SEQUENCE = {500, 300, 200},
        REVEAL_DURATION = 2000,
        TOTAL_DURATION = 4000
    }
}

-- Test suite
describe("Egg Hatching Engine Parity Tests", function()
    local env
    
    beforeEach(function()
        env = aolite.createEnvironment()
        aolite.loadProcess(env, PROCESS_FILE)
    end)
    
    describe("Step Requirements Parity", function()
        it("should match TypeScript common egg steps", function()
            local eggData = {
                eggId = "parity_common",
                species = 25, -- Pikachu
                steps = 0,
                requiredSteps = TypeScriptReference.STEP_REQUIREMENTS.COMMON,
                eggType = "common"
            }
            
            -- Progress exact amount needed
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(TypeScriptReference.STEP_REQUIREMENTS.COMMON),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.CurrentSteps, tostring(TypeScriptReference.STEP_REQUIREMENTS.COMMON))
            assert.equals(response.IsReady, "true")
        end)
        
        it("should match TypeScript rare egg steps", function()
            local eggData = {
                eggId = "parity_rare",
                species = 4, -- Charmander
                steps = 0,
                requiredSteps = TypeScriptReference.STEP_REQUIREMENTS.RARE,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(TypeScriptReference.STEP_REQUIREMENTS.RARE - 1),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.IsReady, "false") -- One step short
            
            -- Add final step
            eggData.steps = TypeScriptReference.STEP_REQUIREMENTS.RARE - 1
            msg.Steps = "1"
            msg.Data = json.encode(eggData)
            
            response = aolite.send(env, msg)
            assert.equals(response.IsReady, "true")
        end)
        
        it("should match TypeScript epic egg steps", function()
            local eggData = {
                eggId = "parity_epic",
                species = 131, -- Lapras
                steps = 0,
                requiredSteps = TypeScriptReference.STEP_REQUIREMENTS.EPIC,
                eggType = "epic"
            }
            
            -- Test wave-based progression
            local wavesToProgress = 25 -- Half way
            local stepsToAdd = wavesToProgress * TypeScriptReference.STEPS_PER_WAVE
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(stepsToAdd),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.CurrentSteps, tostring(stepsToAdd))
            assert.equals(response.PercentComplete, "50") -- Exactly half way
        end)
        
        it("should match TypeScript legendary egg steps", function()
            local eggData = {
                eggId = "parity_legendary",
                species = 150, -- Mewtwo
                steps = 0,
                requiredSteps = TypeScriptReference.STEP_REQUIREMENTS.LEGENDARY,
                eggType = "legendary"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(TypeScriptReference.STEP_REQUIREMENTS.LEGENDARY),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.CurrentSteps, tostring(TypeScriptReference.STEP_REQUIREMENTS.LEGENDARY))
            assert.equals(response.IsReady, "true")
        end)
        
        it("should match TypeScript Manaphy/Phione egg steps", function()
            local eggData = {
                eggId = "parity_phione",
                species = 489, -- Phione
                steps = 0,
                requiredSteps = TypeScriptReference.STEP_REQUIREMENTS.MANAPHY,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(TypeScriptReference.STEP_REQUIREMENTS.MANAPHY),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.RequiredSteps, tostring(TypeScriptReference.STEP_REQUIREMENTS.MANAPHY))
            assert.equals(response.IsReady, "true")
        end)
    end)
    
    describe("Incubation Modifier Parity", function()
        it("should match TypeScript Flame Body modifier", function()
            local baseSteps = 100
            local expectedSteps = baseSteps * TypeScriptReference.INCUBATION.FLAME_BODY
            
            local eggData = {
                eggId = "parity_flame_body",
                species = 4,
                steps = 0,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(baseSteps),
                Modifiers = json.encode({FLAME_BODY = true}),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.StepsAdded, tostring(expectedSteps))
        end)
        
        it("should match TypeScript Oval Charm modifier", function()
            local baseSteps = 200
            local expectedSteps = math.floor(baseSteps * TypeScriptReference.INCUBATION.OVAL_CHARM)
            
            local eggData = {
                eggId = "parity_oval_charm",
                species = 1,
                steps = 0,
                requiredSteps = 2560
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(baseSteps),
                Modifiers = json.encode({OVAL_CHARM = true}),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.StepsAdded, tostring(expectedSteps))
        end)
        
        it("should match TypeScript stacked modifiers", function()
            local baseSteps = 100
            -- TypeScript applies modifiers multiplicatively
            local expectedSteps = math.floor(
                baseSteps * 
                TypeScriptReference.INCUBATION.FLAME_BODY * 
                TypeScriptReference.INCUBATION.OVAL_CHARM
            )
            
            local eggData = {
                eggId = "parity_stacked",
                species = 7,
                steps = 0,
                requiredSteps = 6400
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = tostring(baseSteps),
                Modifiers = json.encode({
                    FLAME_BODY = true,
                    OVAL_CHARM = true
                }),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.StepsAdded, tostring(expectedSteps))
        end)
        
        it("should match TypeScript Hatching Power levels", function()
            for level, multiplier in pairs(TypeScriptReference.INCUBATION.HATCHING_POWER) do
                local baseSteps = 100
                local expectedSteps = math.floor(baseSteps * multiplier)
                
                local eggData = {
                    eggId = "parity_hatch_power_" .. level,
                    species = 25,
                    steps = 0,
                    requiredSteps = 2560
                }
                
                local msg = {
                    From = "test_sender",
                    Action = "ProgressSteps",
                    EggId = eggData.eggId,
                    Steps = tostring(baseSteps),
                    Modifiers = json.encode({
                        ["HATCHING_POWER_" .. level] = true
                    }),
                    Data = json.encode(eggData)
                }
                
                local response = aolite.send(env, msg)
                assert.equals(
                    response.StepsAdded,
                    tostring(expectedSteps),
                    "Hatching Power " .. level .. " should give " .. multiplier .. "x"
                )
            end
        end)
    end)
    
    describe("Pokemon Generation Parity", function()
        it("should match TypeScript base friendship", function()
            local eggData = {
                eggId = "parity_friendship",
                species = 25,
                steps = 2560,
                requiredSteps = 2560,
                eggType = "common"
            }
            
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = eggData.eggId,
                Data = json.encode(eggData),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            assert.equals(data.pokemon.friendship, TypeScriptReference.BASE_FRIENDSHIP)
        end)
        
        it("should match TypeScript hatched Pokemon level", function()
            local eggData = {
                eggId = "parity_level",
                species = 4,
                steps = 6400,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = eggData.eggId,
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            assert.equals(data.pokemon.level, 1) -- Always level 1 as per TypeScript
            assert.equals(data.pokemon.experience, 0) -- Zero experience
        end)
        
        it("should match TypeScript egg tier IV bonuses", function()
            -- TypeScript gives bonus IVs based on tier
            local tiers = {
                {type = "common", bonus = 0},
                {type = "rare", bonus = 10},
                {type = "epic", bonus = 15},
                {type = "legendary", bonus = 20}
            }
            
            for _, tier in ipairs(tiers) do
                local eggData = {
                    eggId = "parity_iv_" .. tier.type,
                    species = 25,
                    steps = 99999,
                    requiredSteps = 99999,
                    eggType = tier.type
                }
                
                local msg = {
                    From = "test_sender",
                    Action = "HatchEgg",
                    EggId = eggData.eggId,
                    Data = json.encode(eggData),
                    Timestamp = "1000000000"
                }
                
                local response = aolite.send(env, msg)
                local data = json.decode(response.Data)
                
                -- Check all IVs have appropriate bonus
                for stat, value in pairs(data.pokemon.ivs) do
                    assert.is_true(
                        value >= (1 + tier.bonus),
                        tier.type .. " egg should have minimum IV of " .. (1 + tier.bonus)
                    )
                    assert.is_true(
                        value <= 31,
                        "IV should not exceed 31"
                    )
                end
            end
        end)
    end)
    
    describe("Special Mechanics Parity", function()
        it("should match TypeScript Phione/Manaphy rate", function()
            local manaphyCount = 0
            local phioneCount = 0
            local testRuns = 80 -- Multiple of 8 for clean testing
            
            for i = 0, testRuns - 1 do
                local timestamp = i * TypeScriptReference.MANAPHY_EGG_MANAPHY_RATE
                
                local eggData = {
                    eggId = "manaphy_test_" .. i,
                    species = 489, -- Phione
                    steps = 12800,
                    requiredSteps = 12800,
                    sourceType = "same_species_egg"
                }
                
                local msg = {
                    From = "test_sender",
                    Action = "HatchEgg",
                    EggId = eggData.eggId,
                    Data = json.encode(eggData),
                    Timestamp = tostring(timestamp)
                }
                
                local response = aolite.send(env, msg)
                local data = json.decode(response.Data)
                
                if data.pokemon.species == 490 then
                    manaphyCount = manaphyCount + 1
                else
                    phioneCount = phioneCount + 1
                end
            end
            
            -- Should get exactly 1/8 Manaphy rate
            local expectedManaphy = testRuns / TypeScriptReference.MANAPHY_EGG_MANAPHY_RATE
            assert.equals(manaphyCount, expectedManaphy)
        end)
        
        it("should match TypeScript step overflow capping", function()
            local eggData = {
                eggId = "parity_overflow",
                species = 25,
                steps = 2500,
                requiredSteps = 2560
            }
            
            -- Add way more steps than needed
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = "999999999",
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            -- Should cap at required, not overflow
            assert.equals(response.CurrentSteps, "2560")
            assert.equals(response.PercentComplete, "100")
        end)
    end)
    
    describe("Animation Timing Parity", function()
        it("should match TypeScript animation timings", function()
            local msg = {
                From = "test_sender",
                Action = "GetHatchTiming",
                EggId = "parity_timing"
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            
            assert.equals(
                data.preHatchDuration,
                TypeScriptReference.ANIMATION.PRE_HATCH_DURATION
            )
            
            assert.equals(
                #data.crackSequence,
                #TypeScriptReference.ANIMATION.CRACK_SEQUENCE
            )
            
            for i, timing in ipairs(TypeScriptReference.ANIMATION.CRACK_SEQUENCE) do
                assert.equals(data.crackSequence[i], timing)
            end
            
            assert.equals(
                data.revealDuration,
                TypeScriptReference.ANIMATION.REVEAL_DURATION
            )
            
            assert.equals(
                data.totalDuration,
                TypeScriptReference.ANIMATION.TOTAL_DURATION
            )
        end)
    end)
    
    describe("Mass Hatching Parity", function()
        it("should match TypeScript batch processing behavior", function()
            -- TypeScript processes eggs individually but returns batch results
            local eggDataMap = {}
            local expectedHatched = 0
            local expectedFailed = 0
            
            -- Create mix of ready and not ready eggs
            for i = 1, 10 do
                local isReady = (i % 2 == 0) -- Even eggs are ready
                local steps = isReady and 2560 or 1000
                
                eggDataMap["batch_egg_" .. i] = {
                    eggId = "batch_egg_" .. i,
                    species = 25,
                    steps = steps,
                    requiredSteps = 2560,
                    eggType = "common"
                }
                
                if isReady then
                    expectedHatched = expectedHatched + 1
                else
                    expectedFailed = expectedFailed + 1
                end
            end
            
            local eggIds = {}
            for id, _ in pairs(eggDataMap) do
                table.insert(eggIds, id)
            end
            
            local msg = {
                From = "test_sender",
                Action = "MassHatch",
                Data = json.encode({
                    eggIds = eggIds,
                    eggDataMap = eggDataMap
                }),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.SuccessCount, tostring(expectedHatched))
            assert.equals(response.FailureCount, tostring(expectedFailed))
            
            local data = json.decode(response.Data)
            
            -- Verify each hatched Pokemon has correct properties
            for _, result in ipairs(data.hatched) do
                assert.equals(result.pokemon.level, 1)
                assert.equals(result.pokemon.friendship, TypeScriptReference.BASE_FRIENDSHIP)
                assert.is_true(result.pokemon.eggHatched)
            end
            
            -- Verify failure reasons match TypeScript
            for _, failure in ipairs(data.failed) do
                assert.equals(failure.reason, "Not ready to hatch")
                assert.is_not_nil(failure.currentSteps)
                assert.is_not_nil(failure.requiredSteps)
            end
        end)
    end)
    
    describe("Wave to Step Conversion Parity", function()
        it("should match TypeScript wave calculations", function()
            -- Test wave-based progression matches TypeScript exactly
            local testCases = {
                {waves = 1, expectedSteps = 256},
                {waves = 5, expectedSteps = 1280},
                {waves = 10, expectedSteps = 2560},
                {waves = 25, expectedSteps = 6400},
                {waves = 50, expectedSteps = 12800},
                {waves = 100, expectedSteps = 25600}
            }
            
            for _, testCase in ipairs(testCases) do
                local eggData = {
                    eggId = "wave_test_" .. testCase.waves,
                    species = 25,
                    steps = 0,
                    requiredSteps = testCase.expectedSteps
                }
                
                local msg = {
                    From = "test_sender",
                    Action = "ProgressSteps",
                    EggId = eggData.eggId,
                    Steps = tostring(testCase.expectedSteps),
                    Data = json.encode(eggData)
                }
                
                local response = aolite.send(env, msg)
                assert.equals(
                    response.CurrentSteps,
                    tostring(testCase.expectedSteps),
                    "Wave " .. testCase.waves .. " should equal " .. testCase.expectedSteps .. " steps"
                )
            end
        end)
    end)
end)