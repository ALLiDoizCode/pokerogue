-- egg-hatching-engine-integration.test.lua
-- Integration tests for Egg Hatching Engine with aos-local
-- Tests cross-process communication and coordinator integration

local aosLocal = require("aos-local")
local json = require("json")

-- Test configuration
local PROCESS_FILES = {
    eggHatching = "../../processes/egg-hatching-engine.lua",
    coordinator = "../../processes/coordinator-process.lua",
    speciesDb = "../../processes/pokemon-species-db.lua",
    geneticInheritance = "../../processes/genetic-inheritance-engine.lua",
    eggMoveLearning = "../../processes/egg-move-learning-engine.lua",
    instanceManager = "../../processes/pokemon-instance-manager.lua"
}

-- Test suite
describe("Egg Hatching Engine Integration Tests", function()
    local processes = {}
    local processIds = {}
    
    before(function()
        -- Initialize aos-local environment
        aosLocal.init()
        
        -- Spawn all required processes
        for name, file in pairs(PROCESS_FILES) do
            local process = aosLocal.spawnProcess(file)
            processes[name] = process
            processIds[name] = process.id
        end
        
        -- Configure process IDs in each process
        for name, process in pairs(processes) do
            aosLocal.send(process.id, {
                Action = "ConfigureProcessIds",
                Data = json.encode({
                    eggHatchingProcess = processIds.eggHatching,
                    coordinatorProcess = processIds.coordinator,
                    speciesDbProcess = processIds.speciesDb,
                    geneticInheritanceProcess = processIds.geneticInheritance,
                    eggMoveLearningProcess = processIds.eggMoveLearning,
                    instanceManagerProcess = processIds.instanceManager
                })
            })
        end
    end)
    
    after(function()
        -- Clean up processes
        for _, process in pairs(processes) do
            aosLocal.terminateProcess(process.id)
        end
    end)
    
    describe("Complete Hatching Workflow", function()
        it("should coordinate hatching through multiple processes", function()
            -- Prepare egg data
            local eggData = {
                eggId = "integration_egg_1",
                species = 25, -- Pikachu
                steps = 2560,
                requiredSteps = 2560,
                eggType = "common",
                sourceType = "breeding",
                parentData = {
                    parent1 = {
                        id = "parent1",
                        species = 25,
                        ivs = {hp = 31, attack = 31, defense = 25, spAttack = 28, spDefense = 30, speed = 31},
                        nature = "adamant",
                        ability = "static",
                        moves = {"thunderbolt", "fake_out", "encore", "wish"}
                    },
                    parent2 = {
                        id = "parent2",
                        species = 26, -- Raichu
                        ivs = {hp = 28, attack = 25, defense = 31, spAttack = 31, spDefense = 27, speed = 29},
                        nature = "modest",
                        ability = "lightning_rod",
                        moves = {"thunder", "focus_punch", "volt_tackle", "yawn"}
                    }
                }
            }
            
            -- Step 1: Request hatching through coordinator
            local hatchRequest = aosLocal.send(processIds.coordinator, {
                Action = "HatchEgg",
                EggId = eggData.eggId,
                PlayerId = "test_player",
                Data = json.encode(eggData),
                Timestamp = "1234567890"
            })
            
            -- Allow message processing
            aosLocal.processMessages(10)
            
            -- Check coordinator initiated species lookup
            local speciesMessages = aosLocal.getMessages(processIds.speciesDb)
            local speciesRequest = nil
            for _, msg in ipairs(speciesMessages) do
                if msg.Action == "GetSpecies" then
                    speciesRequest = msg
                    break
                end
            end
            assert.is_not_nil(speciesRequest)
            assert.equals(speciesRequest.SpeciesId, "25")
            
            -- Check genetic inheritance calculation was requested
            local inheritanceMessages = aosLocal.getMessages(processIds.geneticInheritance)
            local inheritanceRequest = nil
            for _, msg in ipairs(inheritanceMessages) do
                if msg.Action == "CalculateInheritance" then
                    inheritanceRequest = msg
                    break
                end
            end
            assert.is_not_nil(inheritanceRequest)
            
            -- Check egg move learning was requested
            local eggMoveMessages = aosLocal.getMessages(processIds.eggMoveLearning)
            local eggMoveRequest = nil
            for _, msg in ipairs(eggMoveMessages) do
                if msg.Action == "GetEggMoves" then
                    eggMoveRequest = msg
                    break
                end
            end
            assert.is_not_nil(eggMoveRequest)
            
            -- Verify final response
            local coordinatorResponses = aosLocal.getResponses(processIds.coordinator)
            local hatchComplete = nil
            for _, response in ipairs(coordinatorResponses) do
                if response.Action == "HatchComplete" then
                    hatchComplete = response
                    break
                end
            end
            assert.is_not_nil(hatchComplete)
            assert.equals(hatchComplete.Success, "true")
            
            local responseData = json.decode(hatchComplete.Data)
            assert.equals(responseData.pokemon.species, 25)
            assert.equals(responseData.pokemon.level, 1)
            assert.is_not_nil(responseData.pokemon.ivs)
            assert.is_not_nil(responseData.pokemon.moves)
        end)
    end)
    
    describe("Step Progression Coordination", function()
        it("should handle step progression across processes", function()
            local eggData = {
                eggId = "integration_egg_2",
                species = 4, -- Charmander
                steps = 0,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            -- Progress steps multiple times
            for i = 1, 5 do
                local response = aosLocal.send(processIds.eggHatching, {
                    Action = "ProgressSteps",
                    EggId = eggData.eggId,
                    Steps = "1000",
                    Data = json.encode(eggData),
                    Timestamp = tostring(1000000 + i * 1000)
                })
                
                aosLocal.processMessages(5)
                
                -- Update egg data for next iteration
                local messages = aosLocal.getResponses(processIds.eggHatching)
                for _, msg in ipairs(messages) do
                    if msg.Action == "StepProgressUpdate" and msg.EggId == eggData.eggId then
                        eggData.steps = tonumber(msg.CurrentSteps)
                        break
                    end
                end
            end
            
            -- Check final state
            assert.equals(eggData.steps, 5000)
            
            -- Progress remaining steps to make ready
            local finalResponse = aosLocal.send(processIds.eggHatching, {
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = "1400",
                Data = json.encode(eggData)
            })
            
            aosLocal.processMessages(5)
            
            local responses = aosLocal.getResponses(processIds.eggHatching)
            local finalUpdate = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "StepProgressUpdate" and msg.IsReady == "true" then
                    finalUpdate = msg
                    break
                end
            end
            
            assert.is_not_nil(finalUpdate)
            assert.equals(finalUpdate.CurrentSteps, "6400")
            assert.equals(finalUpdate.IsReady, "true")
        end)
    end)
    
    describe("Mass Hatching Coordination", function()
        it("should process mass hatching with coordinator", function()
            local eggDataMap = {
                mass_egg_1 = {
                    eggId = "mass_egg_1",
                    species = 25,
                    steps = 2560,
                    requiredSteps = 2560,
                    eggType = "common"
                },
                mass_egg_2 = {
                    eggId = "mass_egg_2",
                    species = 4,
                    steps = 6400,
                    requiredSteps = 6400,
                    eggType = "rare"
                },
                mass_egg_3 = {
                    eggId = "mass_egg_3",
                    species = 1,
                    steps = 2560,
                    requiredSteps = 2560,
                    eggType = "common"
                }
            }
            
            -- Request mass hatching
            local massHatchRequest = aosLocal.send(processIds.eggHatching, {
                Action = "MassHatch",
                Data = json.encode({
                    eggIds = {"mass_egg_1", "mass_egg_2", "mass_egg_3"},
                    eggDataMap = eggDataMap
                }),
                Timestamp = "2000000000"
            })
            
            aosLocal.processMessages(15)
            
            -- Check response
            local responses = aosLocal.getResponses(processIds.eggHatching)
            local massHatchResponse = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "MassHatchComplete" then
                    massHatchResponse = msg
                    break
                end
            end
            
            assert.is_not_nil(massHatchResponse)
            assert.equals(massHatchResponse.Success, "true")
            assert.equals(massHatchResponse.SuccessCount, "3")
            assert.equals(massHatchResponse.FailureCount, "0")
            
            local data = json.decode(massHatchResponse.Data)
            assert.equals(#data.hatched, 3)
            assert.equals(#data.failed, 0)
        end)
        
        it("should handle partial failures in mass hatching", function()
            local eggDataMap = {
                ready_egg = {
                    eggId = "ready_egg",
                    species = 25,
                    steps = 2560,
                    requiredSteps = 2560
                },
                not_ready_egg = {
                    eggId = "not_ready_egg",
                    species = 4,
                    steps = 1000,
                    requiredSteps = 6400
                }
            }
            
            local response = aosLocal.send(processIds.eggHatching, {
                Action = "MassHatch",
                Data = json.encode({
                    eggIds = {"ready_egg", "not_ready_egg", "invalid_egg"},
                    eggDataMap = eggDataMap
                })
            })
            
            aosLocal.processMessages(10)
            
            local responses = aosLocal.getResponses(processIds.eggHatching)
            local massHatchResponse = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "MassHatchComplete" then
                    massHatchResponse = msg
                    break
                end
            end
            
            assert.is_not_nil(massHatchResponse)
            assert.equals(massHatchResponse.SuccessCount, "1")
            assert.equals(massHatchResponse.FailureCount, "2")
            
            local data = json.decode(massHatchResponse.Data)
            assert.equals(data.hatched[1].eggId, "ready_egg")
            assert.equals(data.failed[1].eggId, "not_ready_egg")
            assert.equals(data.failed[1].reason, "Not ready to hatch")
            assert.equals(data.failed[2].eggId, "invalid_egg")
            assert.equals(data.failed[2].reason, "Egg not found")
        end)
    end)
    
    describe("Incubation Modifier Coordination", function()
        it("should apply and track incubation modifiers", function()
            local eggData = {
                eggId = "incubation_egg",
                species = 7, -- Squirtle
                steps = 0,
                requiredSteps = 6400,
                eggType = "rare"
            }
            
            -- Apply Flame Body modifier
            local applyResponse = aosLocal.send(processIds.eggHatching, {
                Action = "ApplyIncubator",
                EggId = eggData.eggId,
                IncubatorType = "FLAME_BODY"
            })
            
            aosLocal.processMessages(5)
            
            local responses = aosLocal.getResponses(processIds.eggHatching)
            local incubationUpdate = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "IncubationUpdate" then
                    incubationUpdate = msg
                    break
                end
            end
            
            assert.is_not_nil(incubationUpdate)
            assert.equals(incubationUpdate.NewMultiplier, "2")
            assert.equals(incubationUpdate.EffectiveStepsPerTick, "20") -- Base 10 * 2
            
            -- Progress with modifier active
            local progressResponse = aosLocal.send(processIds.eggHatching, {
                Action = "ProgressSteps",
                EggId = eggData.eggId,
                Steps = "100",
                Modifiers = json.encode({FLAME_BODY = true}),
                Data = json.encode(eggData)
            })
            
            aosLocal.processMessages(5)
            
            responses = aosLocal.getResponses(processIds.eggHatching)
            local progressUpdate = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "StepProgressUpdate" then
                    progressUpdate = msg
                    break
                end
            end
            
            assert.is_not_nil(progressUpdate)
            assert.equals(progressUpdate.StepsAdded, "200") -- 100 * 2
            
            -- Remove modifier
            aosLocal.send(processIds.eggHatching, {
                Action = "RemoveIncubator",
                EggId = eggData.eggId
            })
            
            aosLocal.processMessages(5)
            
            responses = aosLocal.getResponses(processIds.eggHatching)
            local removeUpdate = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "IncubationUpdate" and msg.NewMultiplier == "1" then
                    removeUpdate = msg
                    break
                end
            end
            
            assert.is_not_nil(removeUpdate)
            assert.equals(removeUpdate.EffectiveStepsPerTick, "10") -- Back to base
        end)
    end)
    
    describe("Error Recovery", function()
        it("should handle process communication failures gracefully", function()
            -- Simulate coordinator being unavailable
            aosLocal.pauseProcess(processIds.coordinator)
            
            local eggData = {
                eggId = "error_test_egg",
                species = 150, -- Mewtwo
                steps = 25600,
                requiredSteps = 25600,
                eggType = "legendary"
            }
            
            -- Attempt to hatch (coordinator paused)
            local response = aosLocal.send(processIds.eggHatching, {
                Action = "HatchEgg",
                EggId = eggData.eggId,
                Data = json.encode(eggData),
                Timeout = "1000" -- 1 second timeout
            })
            
            aosLocal.processMessages(5)
            
            -- Should still complete locally even if coordinator is down
            local responses = aosLocal.getResponses(processIds.eggHatching)
            local hatchResponse = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "HatchComplete" then
                    hatchResponse = msg
                    break
                end
            end
            
            assert.is_not_nil(hatchResponse)
            assert.equals(hatchResponse.Success, "true")
            
            -- Resume coordinator
            aosLocal.resumeProcess(processIds.coordinator)
        end)
    end)
    
    describe("Inventory Management Integration", function()
        it("should manage egg inventory with filtering and sorting", function()
            local eggs = {
                {
                    eggId = "inv_egg_1",
                    species = 25,
                    steps = 2560,
                    requiredSteps = 2560,
                    eggType = "common"
                },
                {
                    eggId = "inv_egg_2",
                    species = 150,
                    steps = 10000,
                    requiredSteps = 25600,
                    eggType = "legendary"
                },
                {
                    eggId = "inv_egg_3",
                    species = 4,
                    steps = 3000,
                    requiredSteps = 6400,
                    eggType = "rare"
                },
                {
                    eggId = "inv_egg_4",
                    species = 131,
                    steps = 12800,
                    requiredSteps = 12800,
                    eggType = "epic"
                }
            }
            
            -- List all eggs
            local listResponse = aosLocal.send(processIds.eggHatching, {
                Action = "ListEggs",
                Filter = "all",
                Data = json.encode({eggs = eggs})
            })
            
            aosLocal.processMessages(5)
            
            local responses = aosLocal.getResponses(processIds.eggHatching)
            local inventoryResponse = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "EggInventory" then
                    inventoryResponse = msg
                    break
                end
            end
            
            assert.is_not_nil(inventoryResponse)
            local data = json.decode(inventoryResponse.Data)
            assert.equals(data.totalCount, 4)
            assert.equals(data.readyCount, 2) -- egg 1 and 4 are ready
            
            -- Filter ready eggs
            listResponse = aosLocal.send(processIds.eggHatching, {
                Action = "ListEggs",
                Filter = "ready",
                Data = json.encode({eggs = eggs})
            })
            
            aosLocal.processMessages(5)
            
            responses = aosLocal.getResponses(processIds.eggHatching)
            local readyResponse = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "EggInventory" and msg.Timestamp then
                    readyResponse = msg
                    break
                end
            end
            
            data = json.decode(readyResponse.Data)
            assert.equals(data.totalCount, 2)
            
            -- Sort by type
            local sortResponse = aosLocal.send(processIds.eggHatching, {
                Action = "SortEggs",
                SortBy = "type",
                Data = json.encode({eggs = eggs})
            })
            
            aosLocal.processMessages(5)
            
            responses = aosLocal.getResponses(processIds.eggHatching)
            local sortedResponse = nil
            for _, msg in ipairs(responses) do
                if msg.Action == "EggsSorted" then
                    sortedResponse = msg
                    break
                end
            end
            
            data = json.decode(sortedResponse.Data)
            assert.equals(data.eggs[1].eggType, "legendary")
            assert.equals(data.eggs[2].eggType, "epic")
            assert.equals(data.eggs[3].eggType, "rare")
            assert.equals(data.eggs[4].eggType, "common")
        end)
    end)
end)