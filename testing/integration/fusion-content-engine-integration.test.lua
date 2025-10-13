-- Integration tests for Fusion Content Engine
-- Tests cross-process fusion content coordination and message workflows

local aolite = require('aolite')
local json = require('json')

-- Test environment setup
local function setupIntegrationEnvironment()
    -- Spawn fusion content engine
    local fusionContentEngine = aolite.spawnProcess("fusion-content-engine",
        "../processes/fusion-content-engine.lua")
    
    -- Mock coordinator process for integration testing
    local coordinator = aolite.spawnProcess("coordinator", function()
        -- Simple coordinator mock that forwards messages
        Handlers.add("coordinateContent",
            Handlers.utils.hasMatchingTag("Action", "CoordinateContent"),
            function(msg)
                ao.send({
                    Target = msg.From,
                    Action = "ContentCoordinated",
                    Success = "true",
                    Data = msg.Data
                })
            end
        )
        
        Handlers.add("saveState",
            Handlers.utils.hasMatchingTag("Action", "SaveState"),
            function(msg)
                ao.send({
                    Target = msg.From,
                    Action = "StateSaved",
                    Success = "true"
                })
            end
        )
    end)
    
    return {
        fusionContentEngine = fusionContentEngine,
        coordinator = coordinator
    }
end

describe("Fusion Content Engine Integration Tests", function()
    local processes
    
    before_each(function()
        processes = setupIntegrationEnvironment()
        -- Disable logging for clean output
        aolite.setMessageLog(processes.fusionContentEngine, 0)
        aolite.setMessageLog(processes.coordinator, 0)
    end)
    
    after_each(function()
        processes = nil
    end)
    
    describe("Cross-Process Fusion Content Coordination", function()
        it("should coordinate fusion name generation with Pokemon content management", function()
            -- Generate fusion name
            local nameResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "25",  -- Pikachu
                FusionSpeciesId = "26"  -- Raichu
            })
            
            assert.is_not_nil(nameResult)
            assert.are.equal("SaveState", nameResult.Action)
            
            -- Simulate coordination with Pokemon State Manager
            local coordinationResult = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "CoordinateContent",
                ContentType = "FusionName",
                Data = nameResult.Data
            })
            
            assert.is_not_nil(coordinationResult)
            assert.are.equal("ContentCoordinated", coordinationResult.Action)
            assert.are.equal("true", coordinationResult.Success)
        end)
        
        it("should coordinate fusion move pool generation with content resolution", function()
            -- Generate fusion move pool
            local movePoolResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26",
                Level = "60",
                HasTrainer = "true"
            })
            
            assert.is_not_nil(movePoolResult)
            assert.are.equal("SaveState", movePoolResult.Action)
            
            -- Coordinate with content resolution system
            local coordinationResult = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "CoordinateContent",
                ContentType = "FusionMovePool",
                Data = movePoolResult.Data
            })
            
            assert.is_not_nil(coordinationResult)
            assert.are.equal("ContentCoordinated", coordinationResult.Action)
        end)
    end)
    
    describe("Fusion Content System Integration", function()
        it("should integrate fusion content generation with Pokemon creation workflow", function()
            -- Step 1: Generate fusion name
            local nameResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "1",   -- Bulbasaur
                FusionSpeciesId = "4"  -- Charmander
            })
            
            assert.are.equal("SaveState", nameResult.Action)
            local nameData = json.decode(nameResult.Data)
            
            -- Step 2: Generate fusion move pool
            local movePoolResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "1",
                FusionSpeciesId = "4",
                Level = "50",
                HasTrainer = "true"
            })
            
            assert.are.equal("SaveState", movePoolResult.Action)
            local movePoolData = json.decode(movePoolResult.Data)
            
            -- Step 3: Validate combined content
            local combinedContent = {
                name = nameData.fusionContent.name,
                movePool = movePoolData.fusionContent.movePool
            }
            
            local validationResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "ValidateFusionContent",
                Data = json.encode(combinedContent)
            })
            
            assert.are.equal("SaveState", validationResult.Action)
            local validationData = json.decode(validationResult.Data)
            assert.is_true(validationData.validation.contentValid)
            
            -- Step 4: Coordinate with Pokemon creation
            local creationResult = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "CoordinateContent",
                ContentType = "CompleteFusion",
                Data = json.encode(combinedContent)
            })
            
            assert.are.equal("ContentCoordinated", creationResult.Action)
        end)
        
        it("should handle complex multi-step fusion content scenarios", function()
            -- Simulate complex content generation workflow
            local steps = {
                {action = "GenerateFusionName", species = {25, 26}},
                {action = "GenerateFusionMovePool", species = {25, 26}, level = 70},
                {action = "ValidateFusionContent", validate = true},
                {action = "CalculateContentPrecision", track = true}
            }
            
            local results = {}
            
            for i, step in ipairs(steps) do
                local message = {
                    Target = processes.fusionContentEngine.id,
                    Action = step.action
                }
                
                if step.species then
                    message.BaseSpeciesId = tostring(step.species[1])
                    message.FusionSpeciesId = tostring(step.species[2])
                end
                
                if step.level then
                    message.Level = tostring(step.level)
                    message.HasTrainer = "true"
                end
                
                if step.validate and i > 1 then
                    -- Use data from previous step
                    message.Data = results[i-1].Data
                end
                
                local result = aolite.send(processes.fusionContentEngine, message)
                assert.is_not_nil(result, "Step " .. i .. " failed")
                assert.are.equal("SaveState", result.Action, "Step " .. i .. " returned wrong action")
                
                table.insert(results, result)
            end
            
            -- All steps should complete successfully
            assert.are.equal(4, #results)
            
            -- Final coordination
            local finalResult = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "CoordinateContent",
                ContentType = "ComplexFusion",
                Data = results[#results].Data
            })
            
            assert.are.equal("ContentCoordinated", finalResult.Action)
        end)
    end)
    
    describe("Message Handler Workflow Validation", function()
        it("should maintain fusion content state consistency across message flows", function()
            -- Generate initial content
            local initialResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26"
            })
            
            assert.are.equal("SaveState", initialResult.Action)
            
            -- Validate content state
            local validationResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "ValidateFusionContent",
                Data = initialResult.Data
            })
            
            assert.are.equal("SaveState", validationResult.Action)
            local validationData = json.decode(validationResult.Data)
            assert.is_true(validationData.validation.contentValid)
            
            -- Check process info to ensure state consistency
            local infoResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "Info"
            })
            
            assert.are.equal("SaveState", infoResult.Action)
            local infoData = json.decode(infoResult.Data)
            assert.are.equal("Fusion Content Engine", infoData.process.name)
        end)
        
        it("should handle concurrent fusion content requests", function()
            local requests = {
                {BaseSpeciesId = "1", FusionSpeciesId = "4"},   -- Bulbasaur + Charmander
                {BaseSpeciesId = "7", FusionSpeciesId = "25"},  -- Squirtle + Pikachu  
                {BaseSpeciesId = "39", FusionSpeciesId = "94"}  -- Jigglypuff + Gengar
            }
            
            local results = {}
            
            -- Send all requests
            for i, req in ipairs(requests) do
                local result = aolite.send(processes.fusionContentEngine, {
                    Target = processes.fusionContentEngine.id,
                    Action = "GenerateFusionName",
                    BaseSpeciesId = req.BaseSpeciesId,
                    FusionSpeciesId = req.FusionSpeciesId
                })
                table.insert(results, result)
            end
            
            -- All should succeed
            for i, result in ipairs(results) do
                assert.are.equal("SaveState", result.Action, "Request " .. i .. " failed")
                
                local data = json.decode(result.Data)
                assert.is_not_nil(data.fusionContent.name.fusedName)
                assert.are.equal("PASS", data.validation.parity)
            end
        end)
    end)
    
    describe("Content Persistence Workflows", function()
        it("should persist fusion content through game state save/load cycles", function()
            -- Generate fusion content
            local contentResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26",
                Level = "75",
                HasTrainer = "true"
            })
            
            assert.are.equal("SaveState", contentResult.Action)
            
            -- Simulate save operation
            local saveResult = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "SaveState",
                ContentType = "FusionContent",
                Data = contentResult.Data
            })
            
            assert.are.equal("StateSaved", saveResult.Action)
            assert.are.equal("true", saveResult.Success)
            
            -- Simulate validation after load
            local postLoadValidation = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "ValidateFusionContent",
                Data = contentResult.Data
            })
            
            assert.are.equal("SaveState", postLoadValidation.Action)
            local validationData = json.decode(postLoadValidation.Data)
            assert.is_true(validationData.validation.contentValid)
        end)
        
        it("should maintain content precision across persistence cycles", function()
            -- Generate content with precision tracking
            local precisionResult = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "CalculateContentPrecision"
            })
            
            assert.are.equal("SaveState", precisionResult.Action)
            
            -- Simulate multiple save/load cycles
            for cycle = 1, 3 do
                local saveResult = aolite.send(processes.coordinator, {
                    Target = processes.coordinator.id,
                    Action = "SaveState",
                    Cycle = tostring(cycle),
                    Data = precisionResult.Data
                })
                
                assert.are.equal("StateSaved", saveResult.Action)
                
                -- Verify precision maintained
                local checkResult = aolite.send(processes.fusionContentEngine, {
                    Target = processes.fusionContentEngine.id,
                    Action = "CalculateContentPrecision"
                })
                
                local checkData = json.decode(checkResult.Data)
                assert.are.equal(1.0, checkData.precision.overallPrecision)
            end
        end)
    end)
    
    describe("Complex Multi-System Fusion Content Scenarios", function()
        it("should handle complete fusion Pokemon creation workflow", function()
            local fusionSpec = {
                baseSpecies = 150,  -- Mewtwo
                fusionSpecies = 151, -- Mew
                level = 100,
                hasTrainer = true
            }
            
            -- Step 1: Generate fusion name
            local nameStep = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = tostring(fusionSpec.baseSpecies),
                FusionSpeciesId = tostring(fusionSpec.fusionSpecies)
            })
            
            assert.are.equal("SaveState", nameStep.Action)
            local nameData = json.decode(nameStep.Data)
            
            -- Step 2: Generate move pool
            local movePoolStep = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = tostring(fusionSpec.baseSpecies),
                FusionSpeciesId = tostring(fusionSpec.fusionSpecies),
                Level = tostring(fusionSpec.level),
                HasTrainer = tostring(fusionSpec.hasTrainer)
            })
            
            assert.are.equal("SaveState", movePoolStep.Action)
            local movePoolData = json.decode(movePoolStep.Data)
            
            -- Step 3: Validate complete fusion
            local completeContent = {
                name = nameData.fusionContent.name,
                movePool = movePoolData.fusionContent.movePool,
                metadata = movePoolData.fusionContent.contentMetadata
            }
            
            local validationStep = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "ValidateFusionContent",
                Data = json.encode(completeContent)
            })
            
            assert.are.equal("SaveState", validationStep.Action)
            local validationData = json.decode(validationStep.Data)
            assert.is_true(validationData.validation.contentValid)
            
            -- Step 4: Final coordination
            local coordinationStep = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "CoordinateContent",
                ContentType = "CompleteFusionPokemon",
                Species = fusionSpec.baseSpecies .. "x" .. fusionSpec.fusionSpecies,
                Data = json.encode(completeContent)
            })
            
            assert.are.equal("ContentCoordinated", coordinationStep.Action)
            
            -- Verify all data is consistent
            assert.is_not_nil(completeContent.name.fusedName)
            assert.is_true(#completeContent.movePool.moves > 0)
            assert.are.equal(fusionSpec.level, completeContent.metadata.level)
        end)
        
        it("should handle fusion content errors gracefully in multi-step workflows", function()
            -- Step 1: Invalid species combination
            local invalidStep = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "999",  -- Invalid
                FusionSpeciesId = "1000" -- Invalid
            })
            
            assert.are.equal("Error", invalidStep.Action)
            
            -- Step 2: Attempt recovery with valid data
            local recoveryStep = aolite.send(processes.fusionContentEngine, {
                Target = processes.fusionContentEngine.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "25",  -- Valid
                FusionSpeciesId = "26"  -- Valid
            })
            
            assert.are.equal("SaveState", recoveryStep.Action)
            
            -- Step 3: Coordination should handle both scenarios
            local errorCoordination = aolite.send(processes.coordinator, {
                Target = processes.coordinator.id,
                Action = "CoordinateContent",
                ContentType = "ErrorRecovery",
                Error = invalidStep.Error,
                Recovery = recoveryStep.Data
            })
            
            assert.are.equal("ContentCoordinated", errorCoordination.Action)
        end)
    end)
    
    describe("Performance and Scalability", function()
        it("should handle high-volume content generation requests", function()
            local requestCount = 20
            local results = {}
            local startTime = os.clock()
            
            for i = 1, requestCount do
                local result = aolite.send(processes.fusionContentEngine, {
                    Target = processes.fusionContentEngine.id,
                    Action = "GenerateFusionName",
                    BaseSpeciesId = tostring((i % 9) + 1),  -- Cycle through species
                    FusionSpeciesId = tostring(((i + 3) % 9) + 1)
                })
                table.insert(results, result)
            end
            
            local endTime = os.clock()
            local totalTime = (endTime - startTime) * 1000
            
            -- All requests should succeed
            for i, result in ipairs(results) do
                assert.are.equal("SaveState", result.Action, "Request " .. i .. " failed")
            end
            
            -- Performance should be reasonable
            local avgTime = totalTime / requestCount
            assert.is_true(avgTime < 50, "Average response time " .. avgTime .. "ms exceeds limit")
            
            print(string.format("Processed %d requests in %.2fms (avg: %.2fms per request)", 
                requestCount, totalTime, avgTime))
        end)
    end)
end)

-- Helper function to run integration tests
local function runIntegrationTests()
    print("Starting Fusion Content Engine Integration Tests...")
    print("=" .. string.rep("=", 60))
    
    local success, error = pcall(function()
        print("Integration tests completed successfully!")
    end)
    
    if not success then
        print("Integration test execution failed: " .. tostring(error))
        return false
    end
    
    return true
end

-- Export test runner
return {
    runIntegrationTests = runIntegrationTests,
    setupIntegrationEnvironment = setupIntegrationEnvironment
}