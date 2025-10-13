-- Integration tests for Move Transformation Engine
-- Tests multi-process coordination and complete workflows

local json = require("json")

-- Test configuration
local TEST_CONFIG = {
    processFile = "processes/move-transformation-engine.lua",
    timeout = 30000, -- 30 seconds
    maxRetries = 3
}

-- Integration test framework
local IntegrationTest = {}
IntegrationTest.__index = IntegrationTest

function IntegrationTest.new(name, description)
    local self = setmetatable({}, IntegrationTest)
    self.name = name
    self.description = description
    self.steps = {}
    self.results = {}
    self.passed = false
    return self
end

function IntegrationTest:addStep(stepName, stepFunction)
    table.insert(self.steps, {name = stepName, func = stepFunction})
    return self
end

function IntegrationTest:run()
    print(string.format("\n🧪 Running Integration Test: %s", self.name))
    print(string.format("📝 Description: %s", self.description))
    
    local allStepsPassed = true
    
    for i, step in ipairs(self.steps) do
        print(string.format("\n  Step %d: %s", i, step.name))
        
        local success, result = pcall(step.func, self)
        
        if success and result then
            print(string.format("  ✅ Step %d passed", i))
            self.results[step.name] = {passed = true, result = result}
        else
            print(string.format("  ❌ Step %d failed: %s", i, result or "Unknown error"))
            self.results[step.name] = {passed = false, error = result}
            allStepsPassed = false
            break
        end
    end
    
    self.passed = allStepsPassed
    
    if self.passed then
        print(string.format("\n🎉 Integration Test '%s' PASSED", self.name))
    else
        print(string.format("\n💥 Integration Test '%s' FAILED", self.name))
    end
    
    return self.passed
end

-- Mock AOS environment for integration testing
local function createMockAOSEnvironment()
    local environment = {
        processes = {},
        messageQueue = {},
        currentTime = 1234567890
    }
    
    function environment:spawnProcess(processId, code)
        local process = {
            id = processId,
            code = code,
            state = {},
            handlers = {},
            messageHistory = {}
        }
        
        -- Execute the process code to register handlers
        local processEnv = {
            ao = {
                id = processId,
                send = function(msg)
                    msg.From = processId
                    msg.Timestamp = environment.currentTime
                    table.insert(environment.messageQueue, msg)
                    print(string.format("📤 Process %s sent message: %s", processId, json.encode(msg)))
                end
            },
            Handlers = {
                add = function(name, matcher, handler)
                    process.handlers[name] = {matcher = matcher, handler = handler}
                    print(string.format("🔧 Handler '%s' registered in process %s", name, processId))
                end,
                utils = {
                    hasMatchingTag = function(tagName, tagValue)
                        return function(msg)
                            return msg.Tags and msg.Tags[tagName] == tagValue
                        end
                    end
                }
            },
            json = json,
            print = print,
            State = {},
            require = function(module) return json end
        }
        
        -- Load the process code in the process environment
        local processCode = load(code, "process_" .. processId, "t", processEnv)
        if processCode then
            local success, error = pcall(processCode)
            if not success then
                error("Failed to initialize process: " .. error)
            end
        else
            error("Failed to compile process code")
        end
        
        self.processes[processId] = process
        return process
    end
    
    function environment:sendMessage(targetProcessId, message)
        local targetProcess = self.processes[targetProcessId]
        if not targetProcess then
            error("Target process not found: " .. targetProcessId)
        end
        
        message.Timestamp = self.currentTime
        table.insert(targetProcess.messageHistory, message)
        
        -- Find matching handler
        for handlerName, handler in pairs(targetProcess.handlers) do
            if handler.matcher(message) then
                print(string.format("📥 Process %s handling message with handler '%s'", targetProcessId, handlerName))
                handler.handler(message)
                break
            end
        end
    end
    
    function environment:getLastMessage()
        return self.messageQueue[#self.messageQueue]
    end
    
    function environment:clearMessageQueue()
        self.messageQueue = {}
    end
    
    function environment:advanceTime(seconds)
        self.currentTime = self.currentTime + seconds
    end
    
    return environment
end

-- Helper function to read process file
local function readProcessFile(filename)
    local file = io.open(filename, "r")
    if not file then
        error("Could not read process file: " .. filename)
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Integration Test 1: Basic Process Initialization
local test1 = IntegrationTest.new(
    "Process Initialization",
    "Test that the Move Transformation Engine process initializes correctly and registers all handlers"
)

test1:addStep("Load process code", function(self)
    local processCode = readProcessFile(TEST_CONFIG.processFile)
    self.processCode = processCode
    return processCode and true or false
end)

test1:addStep("Spawn process", function(self)
    self.environment = createMockAOSEnvironment()
    local process = self.environment:spawnProcess("move_transformation_engine", self.processCode)
    self.process = process
    return process ~= nil
end)

test1:addStep("Verify handlers registered", function(self)
    local expectedHandlers = {
        "process-pre-move-transformation",
        "process-post-move-transformation", 
        "process-transform-move",
        "process-move-learned-transformation",
        "revert-transformation",
        "cleanup-battle-transformations",
        "get-transformation-info",
        "info",
        "ping"
    }
    
    local handlersFound = 0
    for _, handlerName in ipairs(expectedHandlers) do
        if self.process.handlers[handlerName] then
            handlersFound = handlersFound + 1
        else
            print(string.format("  ⚠️  Handler '%s' not found", handlerName))
        end
    end
    
    print(string.format("  📊 Found %d/%d expected handlers", handlersFound, #expectedHandlers))
    return handlersFound == #expectedHandlers
end)

-- Integration Test 2: Aegislash Pre-Move Transformation Workflow
local test2 = IntegrationTest.new(
    "Aegislash Pre-Move Transformation Workflow",
    "Test complete Aegislash stance change workflow from shield to blade form"
)

test2:addStep("Initialize environment", function(self)
    self.environment = createMockAOSEnvironment()
    local processCode = readProcessFile(TEST_CONFIG.processFile)
    self.process = self.environment:spawnProcess("move_transformation_engine", processCode)
    return self.process ~= nil
end)

test2:addStep("Send pre-move transformation request", function(self)
    local message = {
        From = "battle_engine",
        Tags = {
            Action = "ProcessPreMoveTransformation",
            PokemonId = "aegislash_001",
            MoveId = "THUNDERBOLT",
            SpeciesId = "681",
            CurrentForm = "shield"
        },
        Data = json.encode({
            speciesId = 681,
            form = "shield",
            abilities = {STANCE_CHANGE = true},
            baseStats = {hp = 60, atk = 50, def = 150, spa = 50, spd = 150, spe = 60}
        })
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    return true
end)

test2:addStep("Verify transformation response", function(self)
    local response = self.environment:getLastMessage()
    
    if not response then
        return false, "No response received"
    end
    
    if response.Action ~= "TransformationTriggered" then
        return false, "Expected TransformationTriggered, got " .. (response.Action or "nil")
    end
    
    if response.FromForm ~= "shield" or response.ToForm ~= "blade" then
        return false, "Incorrect form transformation"
    end
    
    if response.TransformationType ~= "pre_move" then
        return false, "Incorrect transformation type"
    end
    
    print("  📋 Transformation details:", json.encode(response))
    return true
end)

-- Integration Test 3: Meloetta Post-Move Transformation Workflow
local test3 = IntegrationTest.new(
    "Meloetta Post-Move Transformation Workflow", 
    "Test complete Meloetta Relic Song transformation workflow"
)

test3:addStep("Initialize environment", function(self)
    self.environment = createMockAOSEnvironment()
    local processCode = readProcessFile(TEST_CONFIG.processFile)
    self.process = self.environment:spawnProcess("move_transformation_engine", processCode)
    return self.process ~= nil
end)

test3:addStep("Send post-move transformation request", function(self)
    local message = {
        From = "battle_engine",
        Tags = {
            Action = "ProcessPostMoveTransformation",
            PokemonId = "meloetta_001", 
            MoveId = "RELIC_SONG",
            SpeciesId = "648",
            CurrentForm = "aria"
        },
        Data = json.encode({
            speciesId = 648,
            form = "aria",
            abilities = {},
            baseStats = {hp = 100, atk = 77, def = 77, spa = 128, spd = 128, spe = 90}
        })
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    return true
end)

test3:addStep("Verify toggle transformation", function(self)
    local response = self.environment:getLastMessage()
    
    if not response then
        return false, "No response received"
    end
    
    if response.Action ~= "TransformationTriggered" then
        return false, "Expected TransformationTriggered, got " .. (response.Action or "nil")
    end
    
    if response.ToggleMode ~= "true" then
        return false, "Toggle mode not enabled"
    end
    
    if response.FromForm ~= "aria" or response.ToForm ~= "pirouette" then
        return false, "Incorrect form transformation"
    end
    
    return true
end)

test3:addStep("Test blocked by Sheer Force", function(self)
    local message = {
        From = "battle_engine",
        Tags = {
            Action = "ProcessPostMoveTransformation",
            PokemonId = "meloetta_002",
            MoveId = "RELIC_SONG", 
            SpeciesId = "648",
            CurrentForm = "aria"
        },
        Data = json.encode({
            speciesId = 648,
            form = "aria",
            abilities = {SHEER_FORCE = true}, -- Blocked ability
            baseStats = {hp = 100, atk = 77, def = 77, spa = 128, spd = 128, spe = 90}
        })
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    
    local response = self.environment:getLastMessage()
    return response and response.Action == "NoTransformation"
end)

-- Integration Test 4: Transform Move Complete Workflow
local test4 = IntegrationTest.new(
    "Transform Move Complete Workflow",
    "Test complete Transform move workflow with stat copying and reversion"
)

test4:addStep("Initialize environment", function(self)
    self.environment = createMockAOSEnvironment()
    local processCode = readProcessFile(TEST_CONFIG.processFile)
    self.process = self.environment:spawnProcess("move_transformation_engine", processCode)
    return self.process ~= nil
end)

test4:addStep("Execute Transform move", function(self)
    local userPokemon = {
        speciesId = 132, -- Ditto
        form = "default",
        abilities = {},
        baseStats = {hp = 48, atk = 48, def = 48, spa = 48, spd = 48, spe = 48},
        types = {"NORMAL"},
        moveset = {{moveId = "TRANSFORM", pp = 10, maxPP = 10}}
    }
    
    local targetPokemon = {
        speciesId = 25, -- Pikachu
        form = "default", 
        abilities = {STATIC = true},
        baseStats = {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90},
        types = {"ELECTRIC"},
        moveset = {
            {moveId = "THUNDERBOLT", pp = 15, maxPP = 15},
            {moveId = "QUICK_ATTACK", pp = 30, maxPP = 30}
        }
    }
    
    local message = {
        From = "battle_engine",
        Tags = {
            Action = "ProcessTransformMove",
            UserPokemonId = "ditto_001",
            TargetPokemonId = "pikachu_001",
            BattleId = "battle_001"
        },
        UserData = json.encode(userPokemon),
        TargetData = json.encode(targetPokemon)
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    return true
end)

test4:addStep("Verify transformation success", function(self)
    local response = self.environment:getLastMessage()
    
    if not response then
        return false, "No response received"
    end
    
    if response.Action ~= "TransformSuccess" then
        return false, "Expected TransformSuccess, got " .. (response.Action or "nil")
    end
    
    -- Verify transformed data
    if response.TransformedData then
        local transformedData = json.decode(response.TransformedData)
        if transformedData.speciesId ~= 25 then
            return false, "Species not copied correctly"
        end
        if transformedData.baseStats.hp ~= 48 then
            return false, "HP should be preserved"
        end
        if transformedData.baseStats.atk ~= 55 then
            return false, "Attack stat not copied correctly"
        end
    end
    
    self.transformResponse = response
    return true
end)

test4:addStep("Test transformation reversion", function(self)
    local message = {
        From = "battle_engine",
        Tags = {
            Action = "RevertTransformation",
            PokemonId = "ditto_001",
            BattleId = "battle_001",
            RevertType = "switch_out"
        }
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    
    local response = self.environment:getLastMessage()
    return response and response.Action == "TransformationReverted"
end)

-- Integration Test 5: ADP Compliance Test
local test5 = IntegrationTest.new(
    "ADP Compliance Test",
    "Test AO Documentation Protocol v1.0 compliance"
)

test5:addStep("Initialize environment", function(self)
    self.environment = createMockAOSEnvironment()
    local processCode = readProcessFile(TEST_CONFIG.processFile)
    self.process = self.environment:spawnProcess("move_transformation_engine", processCode)
    return self.process ~= nil
end)

test5:addStep("Test Info handler", function(self)
    local message = {
        From = "test_client",
        Tags = {Action = "Info"}
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    return true
end)

test5:addStep("Verify ADP compliance", function(self)
    local response = self.environment:getLastMessage()
    
    if not response or response.Action ~= "SaveState" then
        return false, "Expected SaveState response from Info handler"
    end
    
    local infoData = json.decode(response.Data)
    
    -- Check required ADP fields
    if not infoData.adpVersion then
        return false, "Missing adpVersion field"
    end
    
    if infoData.adpVersion ~= "1.0" then
        return false, "Incorrect ADP version: " .. infoData.adpVersion
    end
    
    if not infoData.handlers then
        return false, "Missing handlers documentation"
    end
    
    if not infoData.capabilities then
        return false, "Missing capabilities list"
    end
    
    -- Verify handler documentation
    local handlerCount = 0
    for _, handler in ipairs(infoData.handlers) do
        handlerCount = handlerCount + 1
        if not handler.action or not handler.description then
            return false, "Handler missing required fields"
        end
    end
    
    print(string.format("  📊 Found %d documented handlers", handlerCount))
    return handlerCount >= 7 -- Expect at least 7 core handlers
end)

test5:addStep("Test Ping handler", function(self)
    local message = {
        From = "test_client",
        Tags = {Action = "Ping"}
    }
    
    self.environment:clearMessageQueue()
    self.environment:sendMessage("move_transformation_engine", message)
    
    local response = self.environment:getLastMessage()
    return response and response.Action == "Pong" and response.Data == "pong"
end)

-- Run all integration tests
local function runAllIntegrationTests()
    print("🚀 Starting Move Transformation Engine Integration Tests")
    print("=" * 60)
    
    local tests = {test1, test2, test3, test4, test5}
    local passedTests = 0
    local totalTests = #tests
    
    for i, test in ipairs(tests) do
        print(string.format("\n[%d/%d] %s", i, totalTests, test.name))
        if test:run() then
            passedTests = passedTests + 1
        end
    end
    
    print("\n" .. "=" * 60)
    print("🏁 INTEGRATION TEST RESULTS")
    print(string.format("Total tests: %d", totalTests))
    print(string.format("Passed: %d", passedTests))
    print(string.format("Failed: %d", totalTests - passedTests))
    print(string.format("Success rate: %.1f%%", (passedTests / totalTests) * 100))
    
    if passedTests == totalTests then
        print("🎉 ALL INTEGRATION TESTS PASSED! 🎉")
        return true
    else
        print("❌ Some integration tests failed. Review the output above.")
        return false
    end
end

-- Execute the integration tests
return runAllIntegrationTests()