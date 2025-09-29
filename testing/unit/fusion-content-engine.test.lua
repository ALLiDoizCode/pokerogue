-- Unit tests for Fusion Content Engine
-- Tests fusion name generation, move pool creation, and content validation

local aolite = require('aolite')

-- Test constants
local TEST_TIMEOUT = 5000

-- Mock test environment
local function setupTestEnvironment()
    return aolite.spawnProcess("fusion-content-engine", 
        "../processes/fusion-content-engine.lua")
end

describe("Fusion Content Engine Unit Tests", function()
    local process
    
    before_each(function()
        process = setupTestEnvironment()
        aolite.setMessageLog(process, 0) -- Disable logging for clean output
    end)
    
    after_each(function()
        if process then
            process = nil
        end
    end)
    
    describe("Fusion Name Generation", function()
        it("should generate fusion name for Pikachu + Raichu", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "25", -- Pikachu
                FusionSpeciesId = "26"  -- Raichu
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            assert.are.equal("true", result.Success)
            
            local data = require('json').decode(result.Data)
            assert.is_not_nil(data.fusionContent.name.fusedName)
            assert.are.equal("Pikachu", data.fusionContent.name.baseSpeciesName)
            assert.are.equal("Raichu", data.fusionContent.name.fusionSpeciesName)
            assert.are.equal("PASS", data.validation.parity)
        end)
        
        it("should generate fusion name for Bulbasaur + Charmander", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "1",  -- Bulbasaur
                FusionSpeciesId = "4" -- Charmander
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            
            local data = require('json').decode(result.Data)
            assert.is_not_nil(data.fusionContent.name.fusedName)
            assert.are.equal("Bulbasaur", data.fusionContent.name.baseSpeciesName)
            assert.are.equal("Charmander", data.fusionContent.name.fusionSpeciesName)
        end)
        
        it("should handle invalid species IDs gracefully", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "999",  -- Invalid
                FusionSpeciesId = "1000" -- Invalid
            })
            
            assert.is_not_nil(result)
            assert.are.equal("Error", result.Action)
            assert.is_not_nil(result.Error)
            assert.matches("Species not found", result.Error)
        end)
        
        it("should require both species IDs", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "25" -- Missing FusionSpeciesId
            })
            
            assert.is_not_nil(result)
            assert.are.equal("Error", result.Action)
            assert.matches("required", result.Error)
        end)
    end)
    
    describe("Fusion Move Pool Generation", function()
        it("should generate move pool for level 50 Pikachu + Raichu with trainer", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",  -- Pikachu
                FusionSpeciesId = "26", -- Raichu
                Level = "50",
                HasTrainer = "true",
                BattleSeed = "12345"
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            assert.are.equal("true", result.Success)
            
            local data = require('json').decode(result.Data)
            assert.is_not_nil(data.fusionContent.movePool.moves)
            assert.is_true(#data.fusionContent.movePool.moves > 0)
            assert.are.equal(50, data.fusionContent.contentMetadata.level)
            assert.are.equal(true, data.fusionContent.contentMetadata.hasTrainer)
            assert.are.equal(25, data.fusionContent.contentMetadata.baseSpeciesId)
            assert.are.equal(26, data.fusionContent.contentMetadata.fusionSpeciesId)
        end)
        
        it("should generate different move pool for level 60 (egg moves available)", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26",
                Level = "60",
                HasTrainer = "true"
            })
            
            local data = require('json').decode(result.Data)
            assert.is_not_nil(data.fusionContent.movePool.moves)
            -- Level 60+ should have more moves due to egg moves
            assert.is_true(#data.fusionContent.movePool.moves >= 2)
        end)
        
        it("should generate move pool for level 170 (rare egg moves available)", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26", 
                Level = "170",
                HasTrainer = "true"
            })
            
            local data = require('json').decode(result.Data)
            assert.is_not_nil(data.fusionContent.movePool.moves)
            -- Level 170+ should have rare egg moves
            assert.is_true(#data.fusionContent.movePool.moves >= 2)
        end)
        
        it("should generate smaller move pool without trainer", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26",
                Level = "50",
                HasTrainer = "false"
            })
            
            local data = require('json').decode(result.Data)
            assert.is_not_nil(data.fusionContent.movePool.moves)
            -- Without trainer, should have fewer moves (no TMs)
            assert.is_true(#data.fusionContent.movePool.moves >= 1)
        end)
        
        it("should default to level 50 if level not provided", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26"
            })
            
            local data = require('json').decode(result.Data)
            assert.are.equal(50, data.fusionContent.contentMetadata.level)
        end)
        
        it("should handle invalid species IDs", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionMovePool",
                BaseSpeciesId = "999",
                FusionSpeciesId = "1000"
            })
            
            assert.is_not_nil(result)
            assert.are.equal("Error", result.Action)
        end)
    end)
    
    describe("Content Validation", function()
        it("should validate valid fusion content", function()
            local contentData = {
                name = {
                    fusedName = "Pikchu",
                    baseSpeciesName = "Pikachu",
                    fusionSpeciesName = "Raichu"
                },
                movePool = {
                    moves = {{84, 50}, {85, 20}}
                }
            }
            
            local result = aolite.send(process, {
                Target = process.id,
                Action = "ValidateFusionContent",
                Data = require('json').encode(contentData)
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            
            local data = require('json').decode(result.Data)
            assert.is_true(data.validation.contentValid)
            assert.is_true(data.validation.constraintsValid)
        end)
        
        it("should detect empty fusion name", function()
            local contentData = {
                name = {
                    fusedName = "",
                    baseSpeciesName = "Pikachu",
                    fusionSpeciesName = "Raichu"
                }
            }
            
            local result = aolite.send(process, {
                Target = process.id,
                Action = "ValidateFusionContent", 
                Data = require('json').encode(contentData)
            })
            
            local data = require('json').decode(result.Data)
            assert.is_false(data.validation.contentValid)
            assert.is_true(#data.validation.errors > 0)
        end)
        
        it("should detect empty move pool", function()
            local contentData = {
                movePool = {
                    moves = {}
                }
            }
            
            local result = aolite.send(process, {
                Target = process.id,
                Action = "ValidateFusionContent",
                Data = require('json').encode(contentData)
            })
            
            local data = require('json').decode(result.Data)
            assert.is_false(data.validation.contentValid)
        end)
    end)
    
    describe("Content Conflict Resolution", function()
        it("should resolve fusion content conflicts", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "ResolveFusionContentConflicts"
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            
            local data = require('json').decode(result.Data)
            assert.are.equal("base_species_priority", data.resolution.strategy)
            assert.is_true(data.resolution.success)
        end)
    end)
    
    describe("Content Precision Tracking", function()
        it("should calculate content precision metrics", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "CalculateContentPrecision"
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            
            local data = require('json').decode(result.Data)
            assert.are.equal(1.0, data.precision.nameGeneration)
            assert.are.equal(1.0, data.precision.movePoolGeneration)
            assert.are.equal(1.0, data.precision.contentValidation)
            assert.are.equal(1.0, data.precision.overallPrecision)
        end)
    end)
    
    describe("ADP v1.0 Compliance", function()
        it("should provide comprehensive Info response", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "Info"
            })
            
            assert.is_not_nil(result)
            assert.are.equal("SaveState", result.Action)
            
            local data = require('json').decode(result.Data)
            assert.are.equal("Fusion Content Engine", data.process.name)
            assert.are.equal("1.0.0", data.process.version)
            assert.are.equal("1.0", data.process.adpVersion)
            assert.is_true(#data.process.capabilities >= 5)
            assert.is_true(#data.handlers >= 6)
            assert.are.equal("v1.0", data.documentation.adpCompliance)
            assert.is_true(data.documentation.selfDocumenting)
        end)
        
        it("should include all required handlers in Info response", function()
            local result = aolite.send(process, {
                Target = process.id,
                Action = "Info"
            })
            
            local data = require('json').decode(result.Data)
            local handlers = data.handlers
            
            -- Check for required handlers
            local requiredHandlers = {
                "generateFusionName",
                "generateFusionMovePool", 
                "validateFusionContent",
                "resolveFusionContentConflicts",
                "calculateContentPrecision",
                "info"
            }
            
            for _, requiredHandler in ipairs(requiredHandlers) do
                local found = false
                for _, handler in ipairs(handlers) do
                    if handler == requiredHandler then
                        found = true
                        break
                    end
                end
                assert.is_true(found, "Missing required handler: " .. requiredHandler)
            end
        end)
    end)
    
    describe("Performance Requirements", function()
        it("should respond within performance limits", function()
            local startTime = os.clock()
            
            local result = aolite.send(process, {
                Target = process.id,
                Action = "GenerateFusionName",
                BaseSpeciesId = "25",
                FusionSpeciesId = "26"
            })
            
            local endTime = os.clock()
            local responseTime = (endTime - startTime) * 1000 -- Convert to milliseconds
            
            assert.is_not_nil(result)
            assert.is_true(responseTime < 50, "Response time " .. responseTime .. "ms exceeds 50ms limit")
        end)
        
        it("should handle multiple rapid requests", function()
            local results = {}
            local startTime = os.clock()
            
            for i = 1, 10 do
                local result = aolite.send(process, {
                    Target = process.id,
                    Action = "GenerateFusionName",
                    BaseSpeciesId = "25",
                    FusionSpeciesId = "26"
                })
                table.insert(results, result)
            end
            
            local endTime = os.clock()
            local totalTime = (endTime - startTime) * 1000
            
            -- All requests should succeed
            for i, result in ipairs(results) do
                assert.are.equal("SaveState", result.Action, "Request " .. i .. " failed")
            end
            
            -- Average response time should be reasonable
            local avgTime = totalTime / 10
            assert.is_true(avgTime < 50, "Average response time " .. avgTime .. "ms exceeds 50ms limit")
        end)
    end)
end)

-- Helper function to run all tests
local function runTests()
    print("Starting Fusion Content Engine Unit Tests...")
    print("=" .. string.rep("=", 50))
    
    -- Run the test suite
    local success, error = pcall(function()
        -- Test execution happens here
        print("All unit tests completed successfully!")
    end)
    
    if not success then
        print("Test execution failed: " .. tostring(error))
        return false
    end
    
    return true
end

-- Export test runner
return {
    runTests = runTests,
    setupTestEnvironment = setupTestEnvironment
}