-- Test file for processes/topology-config.lua
-- Tests topology configuration, process discovery, and ADP v1.0 compliance

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.topology-config"
local processId = "test-topology-config"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Topology Configuration")
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

-- Test 1: Get Complete Topology
print("\n📝 Test 1: Get Complete Topology")
local response = sendMessage("GetTopology", {})

if response and response.Data then
    local topology = json.decode(response.Data)
    if topology.dataLayer and topology.gameLogicLayer and topology.coordinationLayer then
        print("✅ Complete topology structure returned")
    else
        error("Topology structure incomplete")
    end
else
    error("GetTopology failed")
end

-- Test 2: Validate Known Process
print("\n📝 Test 2: Validate Known Process")
response = sendMessage("ValidateProcess", {
    ProcessType = "battle_engine"
})

if response and response.Action == "ProcessValidation" and response.Valid == "true" then
    print("✅ Known process validated")
else
    error("Process validation failed")
end

-- Test 3: Reject Unknown Process
print("\n📝 Test 3: Reject Unknown Process")
response = sendMessage("ValidateProcess", {
    ProcessType = "invalid_process_type"
})

if response and response.Action == "ProcessValidation" and response.Valid == "false" then
    print("✅ Unknown process rejected")
else
    error("Unknown process should be rejected")
end

-- Test 4: Missing ProcessType Parameter
print("\n📝 Test 4: Missing ProcessType Parameter")
response = sendMessage("ValidateProcess", {})

if response and response.Action == "Error" and response.Error then
    print("✅ Missing parameter error handled")
else
    error("Should error on missing parameter")
end

-- Test 5: Get Process Metadata
print("\n📝 Test 5: Get Process Metadata")
response = sendMessage("GetProcessMetadata", {
    ProcessId = "battle_engine"
})

if response and response.Action == "ProcessMetadata" and response.Data then
    local metadata = json.decode(response.Data)
    if metadata.name and metadata.type and metadata.capabilities then
        print("✅ Process metadata retrieved")
    else
        error("Metadata incomplete")
    end
else
    error("GetProcessMetadata failed")
end

-- Test 6: Handle Unknown Process ID
print("\n📝 Test 6: Handle Unknown Process ID")
response = sendMessage("GetProcessMetadata", {
    ProcessId = "nonexistent_process"
})

if response and response.Action == "Error" and response.Error then
    print("✅ Unknown process ID error handled")
else
    error("Should error on unknown process ID")
end

-- Test 7: Discover Processes by Capability
print("\n📝 Test 7: Discover Processes by Capability")
response = sendMessage("DiscoverProcesses", {
    Capability = "calculate_damage"
})

if response and response.Action == "ProcessDiscovery" and response.Data then
    local discovered = json.decode(response.Data)
    if discovered.processes then
        print("✅ Processes discovered by capability")
    else
        error("Discovery result missing processes")
    end
else
    error("DiscoverProcesses failed")
end

-- Test 8: Filter by Process Type
print("\n📝 Test 8: Filter by Process Type")
response = sendMessage("DiscoverProcesses", {
    Type = "data"
})

if response and response.Action == "ProcessDiscovery" and response.Data then
    local discovered = json.decode(response.Data)
    if discovered.processes and #discovered.processes > 0 then
        print("✅ Processes filtered by type")
    else
        error("No processes discovered for type filter")
    end
else
    error("DiscoverProcesses failed")
end

-- Test 9: Health Check
print("\n📝 Test 9: Health Check")
response = sendMessage("HealthCheck", {})

if response and response.Action == "HealthStatus" and response.Status == "healthy" then
    print("✅ Health check passed")
else
    error("Health check failed")
end

-- Test 10: Info Handler (ADP v1.0)
print("\n📝 Test 10: Info Handler (ADP v1.0)")
response = sendMessage("Info", {})

if response and response.Action == "SaveState" and response.Data then
    local info = json.decode(response.Data)
    if info.process and info.process.adpVersion == "1.0" and info.handlers then
        print("✅ ADP v1.0 Info handler working")
    else
        error("ADP info incomplete")
    end
else
    error("Info handler failed")
end

-- Test 11: Verify All Handlers Listed
print("\n📝 Test 11: Verify All Handlers Listed")
if response and response.Data then
    local info = json.decode(response.Data)
    local handlerNames = {}
    for _, handler in ipairs(info.handlers) do
        handlerNames[handler] = true
    end

    if handlerNames["GetTopology"] and handlerNames["ValidateProcess"] and
       handlerNames["GetProcessMetadata"] and handlerNames["DiscoverProcesses"] and
       handlerNames["HealthCheck"] and handlerNames["Info"] then
        print("✅ All handlers listed in Info response")
    else
        error("Some handlers missing from Info response")
    end
else
    error("Cannot verify handlers")
end

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
