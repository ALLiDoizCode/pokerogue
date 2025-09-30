-- egg-hatching-engine.test.lua
-- Unit tests for Egg Hatching Engine process using aolite

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_FILE = "../../processes/egg-hatching-engine.lua"

-- Test suite
describe("Egg Hatching Engine Unit Tests", function()
    local env
    
    before(function()
        -- Initialize aolite environment for each test
        env = aolite.createEnvironment()
    end)
    
    beforeEach(function()
        -- Load process fresh for each test
        env = aolite.createEnvironment()
        aolite.loadProcess(env, PROCESS_FILE)
    end)
    
    describe("Info Handler (ADP v1.0)", function()
        it("should respond with process information", function()
            local msg = {
                From = "test_sender",
                Action = "Info"
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "Info-Response")
            
            local data = json.decode(response.Data)
            assert.equals(data.process.name, "Egg Hatching Engine")
            assert.equals(data.process.version, "1.0.0")
            assert.equals(data.process.adpVersion, "1.0")
            assert.is_true(#data.process.capabilities > 0)
        end)
    end)
    
    describe("Step Counter Implementation", function()
        it("should progress egg steps correctly", function()
            local eggData = {
                eggId = "test_egg_1",
                species = 25, -- Pikachu
                steps = 0,
                requiredSteps = 2560,
                eggType = "common"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg_1",
                Steps = "256",
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "StepProgressUpdate")
            assert.equals(response.Success, "true")
            assert.equals(response.CurrentSteps, "256")
            assert.equals(response.RequiredSteps, "2560")
            assert.equals(response.IsReady, "false")
            assert.equals(response.PercentComplete, "10")
        end)
        
        it("should detect when egg is ready to hatch", function()
            local eggData = {
                eggId = "test_egg_2",
                species = 25,
                steps = 2500,
                requiredSteps = 2560,
                eggType = "common"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg_2",
                Steps = "60",
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.IsReady, "true")
            assert.equals(response.CurrentSteps, "2560")
            assert.equals(response.PercentComplete, "100")
        end)
        
        it("should cap steps at required amount", function()
            local eggData = {
                eggId = "test_egg_3",
                species = 25,
                steps = 2500,
                requiredSteps = 2560,
                eggType = "common"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg_3",
                Steps = "1000", -- Way more than needed
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.CurrentSteps, "2560") -- Capped at required
            assert.equals(response.StepsAdded, "1000") -- But reports actual added
        end)
        
        it("should reject invalid step counts", function()
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg",
                Steps = "-100" -- Negative steps
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "Error")
            assert.equals(response.Error, "Invalid step count")
        end)
    end)
    
    describe("Incubation Modifiers", function()
        it("should apply Flame Body modifier", function()
            local eggData = {
                eggId = "test_egg_4",
                species = 4, -- Charmander
                steps = 0,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg_4",
                Steps = "100",
                Modifiers = json.encode({FLAME_BODY = true}),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.StepsAdded, "200") -- Double speed with Flame Body
        end)
        
        it("should apply Oval Charm modifier", function()
            local eggData = {
                eggId = "test_egg_5",
                species = 1,
                steps = 0,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg_5",
                Steps = "100",
                Modifiers = json.encode({OVAL_CHARM = true}),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.StepsAdded, "150") -- 1.5x with Oval Charm
        end)
        
        it("should stack multiple modifiers", function()
            local eggData = {
                eggId = "test_egg_6",
                species = 7,
                steps = 0,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                EggId = "test_egg_6",
                Steps = "100",
                Modifiers = json.encode({
                    FLAME_BODY = true,
                    OVAL_CHARM = true
                }),
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            -- 100 * 2.0 * 1.5 = 300
            assert.equals(response.StepsAdded, "300")
        end)
    end)
    
    describe("Pokemon Generation", function()
        it("should hatch egg when ready", function()
            local eggData = {
                eggId = "test_egg_7",
                species = 25, -- Pikachu
                steps = 2560,
                requiredSteps = 2560,
                eggType = "common",
                sourceType = "wild"
            }
            
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = "test_egg_7",
                Data = json.encode(eggData),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "HatchComplete")
            assert.equals(response.Success, "true")
            
            local data = json.decode(response.Data)
            assert.equals(data.pokemon.species, 25)
            assert.equals(data.pokemon.level, 1)
            assert.equals(data.pokemon.experience, 0)
            assert.equals(data.pokemon.friendship, 70)
            assert.is_true(data.pokemon.eggHatched)
        end)
        
        it("should reject hatching unready egg", function()
            local eggData = {
                eggId = "test_egg_8",
                species = 25,
                steps = 1000,
                requiredSteps = 2560,
                eggType = "common"
            }
            
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = "test_egg_8",
                Data = json.encode(eggData)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "Error")
            assert.equals(response.Error, "Egg not ready to hatch")
            assert.equals(response.CurrentSteps, "1000")
            assert.equals(response.RequiredSteps, "2560")
        end)
        
        it("should generate IVs based on egg tier", function()
            local eggData = {
                eggId = "test_egg_legendary",
                species = 150, -- Mewtwo
                steps = 25600,
                requiredSteps = 25600,
                eggType = "legendary",
                sourceType = "voucher"
            }
            
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = "test_egg_legendary",
                Data = json.encode(eggData),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            
            -- Legendary eggs get +20 IV bonus
            assert.is_true(data.pokemon.ivs.hp >= 20)
            assert.is_true(data.pokemon.ivs.attack >= 20)
            assert.is_true(data.pokemon.ivs.defense >= 20)
        end)
        
        it("should inherit traits from parents for breeding eggs", function()
            local eggData = {
                eggId = "test_egg_bred",
                species = 25,
                steps = 2560,
                requiredSteps = 2560,
                eggType = "common",
                sourceType = "breeding"
            }
            
            local parentTraits = {
                ivs = {hp = 31, attack = 31, defense = 25, spAttack = 28, spDefense = 30, speed = 31},
                nature = "adamant",
                ability = "static"
            }
            
            local eggMoves = {"fake_out", "wish", "volt_tackle", "encore"}
            
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = "test_egg_bred",
                Data = json.encode(eggData),
                ParentTraits = json.encode(parentTraits),
                EggMoves = json.encode(eggMoves),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            
            assert.equals(data.pokemon.ivs.hp, 31)
            assert.equals(data.pokemon.nature, "adamant")
            assert.equals(data.pokemon.ability, "static")
            assert.equals(#data.pokemon.moves, 4)
            assert.equals(data.pokemon.moves[1], "fake_out")
        end)
    end)
    
    describe("Mass Hatching", function()
        it("should process multiple eggs", function()
            local eggDataMap = {
                egg1 = {
                    eggId = "egg1",
                    species = 25,
                    steps = 2560,
                    requiredSteps = 2560
                },
                egg2 = {
                    eggId = "egg2",
                    species = 4,
                    steps = 6400,
                    requiredSteps = 6400
                },
                egg3 = {
                    eggId = "egg3",
                    species = 1,
                    steps = 1000,
                    requiredSteps = 2560 -- Not ready
                }
            }
            
            local msg = {
                From = "test_sender",
                Action = "MassHatch",
                Data = json.encode({
                    eggIds = {"egg1", "egg2", "egg3"},
                    eggDataMap = eggDataMap
                }),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "MassHatchComplete")
            assert.equals(response.SuccessCount, "2")
            assert.equals(response.FailureCount, "1")
            
            local data = json.decode(response.Data)
            assert.equals(#data.hatched, 2)
            assert.equals(#data.failed, 1)
            assert.equals(data.failed[1].eggId, "egg3")
            assert.equals(data.failed[1].reason, "Not ready to hatch")
        end)
        
        it("should handle invalid eggs in batch", function()
            local eggDataMap = {
                egg1 = {
                    eggId = "egg1",
                    species = 25,
                    steps = 2560,
                    requiredSteps = 2560
                }
            }
            
            local msg = {
                From = "test_sender",
                Action = "MassHatch",
                Data = json.encode({
                    eggIds = {"egg1", "invalid_egg"},
                    eggDataMap = eggDataMap
                }),
                Timestamp = "1234567890"
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.SuccessCount, "1")
            assert.equals(response.FailureCount, "1")
            
            local data = json.decode(response.Data)
            assert.equals(data.failed[1].eggId, "invalid_egg")
            assert.equals(data.failed[1].reason, "Egg not found")
        end)
    end)
    
    describe("Egg Inventory Management", function()
        it("should list eggs with filtering", function()
            local eggs = {
                {
                    eggId = "egg1",
                    species = 25,
                    steps = 2560,
                    requiredSteps = 2560 -- Ready
                },
                {
                    eggId = "egg2",
                    species = 4,
                    steps = 1000,
                    requiredSteps = 6400 -- Not ready
                },
                {
                    eggId = "egg3",
                    species = 1,
                    steps = 2560,
                    requiredSteps = 2560 -- Ready
                }
            }
            
            local msg = {
                From = "test_sender",
                Action = "ListEggs",
                Filter = "ready",
                Data = json.encode({eggs = eggs})
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "EggInventory")
            
            local data = json.decode(response.Data)
            assert.equals(data.totalCount, 2) -- Only ready eggs
            assert.equals(data.readyCount, 2)
        end)
        
        it("should sort eggs by steps", function()
            local eggs = {
                {eggId = "egg1", steps = 100},
                {eggId = "egg2", steps = 500},
                {eggId = "egg3", steps = 300}
            }
            
            local msg = {
                From = "test_sender",
                Action = "SortEggs",
                SortBy = "steps",
                Data = json.encode({eggs = eggs})
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "EggsSorted")
            
            local data = json.decode(response.Data)
            -- Should be sorted by steps descending
            assert.equals(data.eggs[1].steps, 500)
            assert.equals(data.eggs[2].steps, 300)
            assert.equals(data.eggs[3].steps, 100)
        end)
        
        it("should sort eggs by type", function()
            local eggs = {
                {eggId = "egg1", eggType = "common"},
                {eggId = "egg2", eggType = "legendary"},
                {eggId = "egg3", eggType = "epic"}
            }
            
            local msg = {
                From = "test_sender",
                Action = "SortEggs",
                SortBy = "type",
                Data = json.encode({eggs = eggs})
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            
            -- Should be sorted by tier (legendary, epic, common)
            assert.equals(data.eggs[1].eggType, "legendary")
            assert.equals(data.eggs[2].eggType, "epic")
            assert.equals(data.eggs[3].eggType, "common")
        end)
    end)
    
    describe("Special Cases", function()
        it("should handle Manaphy/Phione egg special case", function()
            local eggData = {
                eggId = "test_phione",
                species = 489, -- Phione
                steps = 12800,
                requiredSteps = 12800,
                eggType = "rare",
                sourceType = "same_species_egg"
            }
            
            -- Test with timestamp that gives Manaphy (divisible by 8)
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = "test_phione",
                Data = json.encode(eggData),
                Timestamp = "16" -- Divisible by 8
            }
            
            local response = aolite.send(env, msg)
            local data = json.decode(response.Data)
            assert.equals(data.pokemon.species, 490) -- Should be Manaphy
            
            -- Test with timestamp that gives Phione
            msg.Timestamp = "17" -- Not divisible by 8
            response = aolite.send(env, msg)
            data = json.decode(response.Data)
            assert.equals(data.pokemon.species, 489) -- Should stay Phione
        end)
    end)
    
    describe("Animation Timing", function()
        it("should provide hatching animation timing data", function()
            local msg = {
                From = "test_sender",
                Action = "GetHatchTiming",
                EggId = "test_egg"
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "HatchTimingData")
            
            local data = json.decode(response.Data)
            assert.equals(data.preHatchDuration, 1000)
            assert.equals(#data.crackSequence, 3)
            assert.equals(data.revealDuration, 2000)
            assert.equals(data.totalDuration, 4000)
        end)
    end)
    
    describe("Process Configuration", function()
        it("should configure process IDs", function()
            local config = {
                breedingCompatibilityProcess = "breeding_123",
                geneticInheritanceProcess = "genetic_456",
                eggMoveLearningProcess = "moves_789",
                coordinatorProcess = "coord_abc"
            }
            
            local msg = {
                From = "test_sender",
                Action = "ConfigureProcessIds",
                Data = json.encode(config)
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "ProcessIds-Configured")
            assert.equals(response.Success, "true")
            
            local data = json.decode(response.Data)
            assert.equals(data.breedingCompatibility, "breeding_123")
            assert.equals(data.geneticInheritance, "genetic_456")
        end)
    end)
    
    describe("Error Handling", function()
        it("should handle missing egg ID", function()
            local msg = {
                From = "test_sender",
                Action = "ProgressSteps",
                Steps = "100"
                -- Missing EggId
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "Error")
            assert.equals(response.Error, "EggId required")
        end)
        
        it("should handle invalid egg data", function()
            local msg = {
                From = "test_sender",
                Action = "HatchEgg",
                EggId = "test",
                Data = json.encode({
                    -- Missing species
                    eggId = "test"
                })
            }
            
            local response = aolite.send(env, msg)
            assert.equals(response.Action, "Error")
            assert.equals(response.Error, "Egg species is required")
        end)
    end)
end)