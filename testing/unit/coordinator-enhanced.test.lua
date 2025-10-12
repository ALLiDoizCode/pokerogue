-- Enhanced Coordinator Process Unit Tests
-- Tests for Story 1.4: Async Coordination & State Management
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.coordinator-enhanced"
local processId = "test-coordinator-enhanced"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Enhanced Coordinator")
print("Process ID:", processId)

local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

local testsPassed = 0
local testsFailed = 0

-- Test 1: Workflow Creation
print("📝 Test 1: Workflow Creation")
local workflowResult = sendMessage("CreateWorkflow", {
    WorkflowId = "test_workflow_1",
    Priority = "high",
    Steps = json.encode({"step1", "step2", "step3"})
})
if workflowResult and workflowResult.Action == "SaveState" then
    local workflowData = json.decode(workflowResult.Data or "{}")
    if workflowData.workflowId and workflowData.status == "created" then
        print("✅ Test passed: Workflow created successfully")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Workflow creation incorrect")
    end
else
    error("❌ Test failed: CreateWorkflow handler failed")
end

-- Test 2: Process Discovery
print("📝 Test 2: Process Discovery")
local discoveryResult = sendMessage("DiscoverProcesses", {
    ProcessType = "logic"
})
if discoveryResult and discoveryResult.Action == "SaveState" then
    local discoveryData = json.decode(discoveryResult.Data or "{}")
    if discoveryData.processes then
        print("✅ Test passed: Process discovery works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Process discovery incomplete")
    end
else
    error("❌ Test failed: DiscoverProcesses handler failed")
end

-- Test 3: Message Routing
print("📝 Test 3: Message Routing")
local routingResult = sendMessage("RouteMessage", {
    TargetProcess = "battle-engine",
    MessageAction = "ProcessMove",
    LoadBalancing = "health_score"
})
if routingResult and routingResult.Action == "SaveState" then
    local routingData = json.decode(routingResult.Data or "{}")
    if routingData.routedTo then
        print("✅ Test passed: Message routing works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Message routing incomplete")
    end
else
    error("❌ Test failed: RouteMessage handler failed")
end

-- Test 4: Timeout Management
print("📝 Test 4: Timeout Management")
local timeoutResult = sendMessage("SetTimeout", {
    WorkflowId = "test_workflow_1",
    TimeoutMs = "5000"
})
if timeoutResult and timeoutResult.Action == "SaveState" then
    local timeoutData = json.decode(timeoutResult.Data or "{}")
    if timeoutData.timeoutSet == true then
        print("✅ Test passed: Timeout management works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Timeout management incorrect")
    end
else
    error("❌ Test failed: SetTimeout handler failed")
end

-- Test 5: GameState Validation
print("📝 Test 5: GameState Validation")
local validationResult = sendMessage("ValidateGameState", nil, json.encode({
    player = {id = "player1", name = "Ash", money = 1000},
    party = {{species = "Pikachu", level = 25}},
    scene = "town",
    timestamp = os.time() * 1000
}))
if validationResult and validationResult.Action == "SaveState" then
    local validationData = json.decode(validationResult.Data or "{}")
    if validationData.valid == true then
        print("✅ Test passed: GameState validation works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: GameState validation incorrect")
    end
else
    error("❌ Test failed: ValidateGameState handler failed")
end

-- Test 6: Priority Queue Processing
print("📝 Test 6: Priority Queue Processing")
local priorityResult = sendMessage("ProcessQueue", {
    QueueType = "priority"
})
if priorityResult and priorityResult.Action == "SaveState" then
    local priorityData = json.decode(priorityResult.Data or "{}")
    if priorityData.processed ~= nil then
        print("✅ Test passed: Priority queue processing works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Priority queue processing incomplete")
    end
else
    error("❌ Test failed: ProcessQueue handler failed")
end

-- Test 7: Error Handling
print("📝 Test 7: Error Handling")
local errorResult = sendMessage("CreateWorkflow", {}) -- Missing required fields
if errorResult and errorResult.Action == "Error" then
    print("✅ Test passed: Error handling works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Error handling not working")
end

print("==================================================")
print("Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. (testsPassed + testsFailed))

if testsFailed == 0 then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n❌ Some tests failed!")
end
