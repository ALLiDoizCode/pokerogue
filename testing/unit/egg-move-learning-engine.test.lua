-- Unit tests for egg-move-learning-engine.lua using aolite
-- Tests core functions: move validation, priority calculation, slot management

local test = require("testing.unit-test-helper")
local json = require("json")

-- Mock AO environment
local function setupAOEnvironment()
    if not _G.ao then
        _G.ao = {
            id = "test_process_id",
            send = function(msg)
                -- Capture sent messages for testing
                test.lastSentMessage = msg
            end
        }
    end
    
    if not _G.Handlers then
        _G.Handlers = {
            handlers = {},
            add = function(name, matcher, handler)
                _G.Handlers.handlers[name] = {
                    matcher = matcher,
                    handler = handler
                }
            end,
            utils = {
                hasMatchingTag = function(tagName, tagValue)
                    return function(msg)
                        return msg[tagName] == tagValue
                    end
                end
            }
        }
    end
end

-- Load process file
setupAOEnvironment()
dofile("processes/egg-move-learning-engine.lua")

-- Test suite
test.describe("Egg Move Learning Engine", function()
    
    test.beforeEach(function()
        -- Reset test state
        test.lastSentMessage = nil
    end)
    
    test.describe("Info Handler", function()
        test.it("should return process capabilities", function()
            local handler = Handlers.handlers["info"]
            test.assert(handler ~= nil, "Info handler should exist")
            
            -- Simulate Info message
            local msg = {
                From = "test_sender",
                Action = "Info"
            }
            
            handler.handler(msg)
            
            -- Check response
            test.assert(test.lastSentMessage ~= nil, "Should send response")
            test.assert(test.lastSentMessage.Target == "test_sender", "Should target sender")
            test.assert(test.lastSentMessage.Action == "SaveState", "Should use SaveState action")
            
            local data = json.decode(test.lastSentMessage.Data)
            test.assert(data.process.name == "Egg Move Learning Engine", "Should have correct name")
            test.assert(data.process.version == "1.0.0", "Should have version")
            test.assert(data.process.adpVersion == "1.0", "Should be ADP compliant")
        end)
    end)
    
    test.describe("InheritEggMoves Handler", function()
        test.it("should validate player ID", function()
            local handler = Handlers.handlers["inherit-egg-moves"]
            test.assert(handler ~= nil, "InheritEggMoves handler should exist")
            
            -- Test with missing player ID
            local msg = {
                From = "test_sender",
                Action = "InheritEggMoves",
                Parent1Id = "parent1",
                Parent2Id = "parent2",
                OffspringSpeciesId = "1"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "Error", "Should return error")
            test.assert(test.lastSentMessage.Error == "Invalid player ID", "Should have error message")
        end)
        
        test.it("should validate parent IDs", function()
            local handler = Handlers.handlers["inherit-egg-moves"]
            
            -- Test with invalid parent1
            local msg = {
                From = "test_sender",
                Action = "InheritEggMoves",
                PlayerId = "player123",
                Parent1Id = "",
                Parent2Id = "parent2",
                OffspringSpeciesId = "1"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "Error", "Should return error")
            test.assert(test.lastSentMessage.Error == "Invalid Parent1Id", "Should have error message")
        end)
        
        test.it("should inherit moves successfully", function()
            local handler = Handlers.handlers["inherit-egg-moves"]
            
            -- Valid request
            local msg = {
                From = "test_sender",
                Action = "InheritEggMoves",
                PlayerId = "player123",
                Parent1Id = "parent1",
                Parent2Id = "parent2",
                OffspringSpeciesId = "1"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "SaveState", "Should save state")
            test.assert(test.lastSentMessage.Success == "true", "Should succeed")
            test.assert(test.lastSentMessage.InheritedMoves ~= nil, "Should have inherited moves")
            
            local moves = json.decode(test.lastSentMessage.InheritedMoves)
            test.assert(type(moves) == "table", "Moves should be a table")
            test.assert(#moves <= 4, "Should not exceed 4 moves")
        end)
    end)
    
    test.describe("ValidateMoveLearn Handler", function()
        test.it("should validate move ID", function()
            local handler = Handlers.handlers["validate-move-learn"]
            test.assert(handler ~= nil, "ValidateMoveLearn handler should exist")
            
            -- Test with invalid move ID
            local msg = {
                From = "test_sender",
                Action = "ValidateMoveLearn",
                PlayerId = "player123",
                PokemonId = "pokemon1",
                MoveId = "invalid"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "Error", "Should return error")
            test.assert(test.lastSentMessage.Error == "Invalid move ID", "Should have error message")
        end)
        
        test.it("should validate slot number if provided", function()
            local handler = Handlers.handlers["validate-move-learn"]
            
            -- Test with invalid slot
            local msg = {
                From = "test_sender",
                Action = "ValidateMoveLearn",
                PlayerId = "player123",
                PokemonId = "pokemon1",
                MoveId = "1",
                SlotToReplace = "5"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "Error", "Should return error")
            test.assert(test.lastSentMessage.Error == "Invalid slot number (must be 1-4)", "Should have error message")
        end)
        
        test.it("should validate move learning successfully", function()
            local handler = Handlers.handlers["validate-move-learn"]
            
            -- Valid request
            local msg = {
                From = "test_sender",
                Action = "ValidateMoveLearn",
                PlayerId = "player123",
                PokemonId = "pokemon1",
                MoveId = "14"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "MoveLearnValidated", "Should validate")
            test.assert(test.lastSentMessage.Valid == "true", "Should be valid")
            test.assert(test.lastSentMessage.Success == "true", "Should succeed")
        end)
    end)
    
    test.describe("GetEggMovePool Handler", function()
        test.it("should get egg move pool for species", function()
            local handler = Handlers.handlers["get-egg-move-pool"]
            test.assert(handler ~= nil, "GetEggMovePool handler should exist")
            
            -- Test valid request
            local msg = {
                From = "test_sender",
                Action = "GetEggMovePool",
                PlayerId = "player123",
                SpeciesId = "1"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "EggMovePool", "Should return pool")
            test.assert(test.lastSentMessage.SpeciesId == "1", "Should have species ID")
            
            local data = json.decode(test.lastSentMessage.Data)
            test.assert(type(data.availableMoves) == "table", "Should have available moves")
            test.assert(type(data.priority) == "table", "Should have priority info")
        end)
        
        test.it("should include parent contributions if provided", function()
            local handler = Handlers.handlers["get-egg-move-pool"]
            
            -- Test with parents
            local msg = {
                From = "test_sender",
                Action = "GetEggMovePool",
                PlayerId = "player123",
                SpeciesId = "1",
                Parent1Id = "parent1",
                Parent2Id = "parent2"
            }
            
            handler.handler(msg)
            
            local data = json.decode(test.lastSentMessage.Data)
            test.assert(data.parentMoves ~= nil, "Should have parent moves")
            test.assert(data.parentMoves.parent1 ~= nil, "Should have parent1 moves")
            test.assert(data.parentMoves.parent2 ~= nil, "Should have parent2 moves")
        end)
    end)
    
    test.describe("ManageMoveSlots Handler", function()
        test.it("should validate operation type", function()
            local handler = Handlers.handlers["manage-move-slots"]
            test.assert(handler ~= nil, "ManageMoveSlots handler should exist")
            
            -- Test with invalid operation
            local msg = {
                From = "test_sender",
                Action = "ManageMoveSlots",
                PlayerId = "player123",
                PokemonId = "pokemon1",
                Operation = "invalid"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "Error", "Should return error")
            test.assert(string.find(test.lastSentMessage.Error, "Invalid operation") ~= nil, "Should have error message")
        end)
        
        test.it("should manage move slots successfully", function()
            local handler = Handlers.handlers["manage-move-slots"]
            
            -- Valid request
            local msg = {
                From = "test_sender",
                Action = "ManageMoveSlots",
                PlayerId = "player123",
                PokemonId = "pokemon1",
                Operation = "add",
                MoveId = "14"
            }
            
            handler.handler(msg)
            
            test.assert(test.lastSentMessage.Action == "MoveSlotsUpdated", "Should update slots")
            test.assert(test.lastSentMessage.Success == "true", "Should succeed")
            
            local moves = json.decode(test.lastSentMessage.CurrentMoves)
            test.assert(type(moves) == "table", "Should have moves table")
            test.assert(#moves == 4, "Should have 4 move slots")
        end)
    end)
    
    test.describe("Edge Cases", function()
        test.it("should handle empty species egg moves", function()
            local handler = Handlers.handlers["get-egg-move-pool"]
            
            -- Request for species with no egg moves
            local msg = {
                From = "test_sender",
                Action = "GetEggMovePool",
                PlayerId = "player123",
                SpeciesId = "99999"
            }
            
            handler.handler(msg)
            
            local data = json.decode(test.lastSentMessage.Data)
            test.assert(#data.availableMoves == 0, "Should have empty move list")
        end)
        
        test.it("should handle max move slots", function()
            local handler = Handlers.handlers["inherit-egg-moves"]
            
            -- Request that would generate many moves
            local msg = {
                From = "test_sender",
                Action = "InheritEggMoves",
                PlayerId = "player123",
                Parent1Id = "parent1",
                Parent2Id = "parent2",
                OffspringSpeciesId = "1"
            }
            
            handler.handler(msg)
            
            local moves = json.decode(test.lastSentMessage.InheritedMoves)
            test.assert(#moves <= 4, "Should never exceed 4 moves")
        end)
    end)
    
end)

-- Run tests
test.run()