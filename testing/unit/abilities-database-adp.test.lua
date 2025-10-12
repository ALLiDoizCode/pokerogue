-- Aolite Unit Tests for ADP v1.0 Compliant Abilities Database Process
-- Tests ADP compliance, ability queries, and handler functionality
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.abilities-database-adp"
local processId = "test-abilities-database-adp"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Abilities Database (ADP v1.0)")
print("Process ID:", processId)

-- Test utilities
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

-- Test 1: Process Initialization and ADP Compliance
print("📝 Test 1: Process initialization and ADP compliance")
local infoResponse = sendMessage("Info")
if not infoResponse or infoResponse.Action ~= "SaveState" then
    error("❌ Test 1 failed: Expected SaveState action from Info handler")
end
if not infoResponse.Data then
    error("❌ Test 1 failed: No data in Info response")
end
local infoData = json.decode(infoResponse.Data)
if not infoData.process or infoData.process.adpVersion ~= "1.0" then
    error("❌ Test 1 failed: Expected ADP version 1.0")
end
if not infoData.documentation or infoData.documentation.adpCompliance ~= "v1.0" then
    error("❌ Test 1 failed: Expected ADP compliance v1.0")
end
print("✅ Test 1 passed")

-- Test 2: ADP Info Handler Details
if not infoData.process.name or not infoData.handlers then
    error("❌ Test 2 failed: Missing process name or handlers")
end
print("✅ Test 2 passed")

-- Test 3: GetAbility Handler
print("📝 Test 3: GetAbility handler")
local abilityData = json.encode({id = 65}) -- Overgrow
local abilityResponse = sendMessage("GetAbility", nil, abilityData)
if not abilityResponse or abilityResponse.Action ~= "SaveState" then
    error("❌ Test 3 failed: Expected SaveState action")
end
if not abilityResponse.Data then
    error("❌ Test 3 failed: No data in response")
end
print("✅ Test 3 passed")

-- Test 4: GetAbilitiesByTrigger Handler
print("📝 Test 4: GetAbilitiesByTrigger handler")
local triggerData = json.encode({trigger = "on_contact"})
local triggerResponse = sendMessage("GetAbilitiesByTrigger", nil, triggerData)
if not triggerResponse or triggerResponse.Action ~= "SaveState" then
    error("❌ Test 4 failed: Expected SaveState action")
end
if not triggerResponse.Data then
    error("❌ Test 4 failed: No data in response")
end
print("✅ Test 4 passed")

-- Test 5: Health Check Handler
print("📝 Test 5: Health check handler")
local healthResponse = sendMessage("HealthCheck")
if not healthResponse or healthResponse.Action ~= "SaveState" then
    error("❌ Test 5 failed: Expected SaveState action")
end
if not healthResponse.Data then
    error("❌ Test 5 failed: No data in response")
end
local healthData = json.decode(healthResponse.Data)
if healthData.status ~= "healthy" or not healthData.adpCompliant then
    error("❌ Test 5 failed: Expected healthy status and ADP compliance")
end
print("✅ Test 5 passed")

-- Test 6: Error handling
print("📝 Test 6: Error handling for invalid request")
local errorData = json.encode({}) -- Missing required id or name
local errorResponse = sendMessage("GetAbility", nil, errorData)
if not errorResponse then
    error("❌ Test 6 failed: No response received")
end
if not errorResponse.Error then
    error("❌ Test 6 failed: Expected Error field for invalid request")
end
print("✅ Test 6 passed")

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)