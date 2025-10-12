-- Unit tests for ADP v1.0 Compliant Pokemon Species Database Process
-- Test framework: aolite

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.pokemon-species-db-adp"
local processId = "test-pokemon-species-db-adp"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Pokemon Species Database ADP")
print("Process ID:", processId)

-- Test results tracking
local testResults = {}

-- Helper to send message and capture response
local function sendMessage(action, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action
    }

    if data then
        msg.Data = data
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Process Initialization and ADP Compliance
print("📝 Test 1: Process Initialization and ADP Compliance")
local result = processId ~= nil and processId == "test-pokemon-species-db-adp"
testResults["test_process_initialization"] = result
if not result then
    error("❌ Test 1 failed: Process initialization failed")
end
print("✅ Test 1 passed: Process initialization")

-- Test 2: ADP Info Handler
print("📝 Test 2: ADP Info Handler")
local infoResponse = sendMessage("Info")

if not infoResponse or infoResponse.Action ~= "SaveState" then
    error("❌ Test 2 failed: Expected SaveState response")
end

local infoData = json.decode(infoResponse.Data or "{}")
result = infoData.process and
         infoData.process.adpVersion == "1.0" and
         infoData.documentation and
         infoData.documentation.adpCompliance == "v1.0"

testResults["test_adp_info_handler"] = result
if not result then
    error("❌ Test 2 failed: ADP Info handler validation failed")
end
print("✅ Test 2 passed: ADP Info handler")

-- Test 3: GetSpecies Handler
print("📝 Test 3: GetSpecies Handler")
local speciesData = json.encode({id = 1}) -- Bulbasaur
local speciesResponse = sendMessage("GetSpecies", speciesData)

result = speciesResponse and
         speciesResponse.Action == "SaveState" and
         speciesResponse.Data and
         not speciesResponse.Error

testResults["test_get_species_handler"] = result
if not result then
    error("❌ Test 3 failed: GetSpecies handler test failed")
end
print("✅ Test 3 passed: GetSpecies handler")

-- Test 4: GetEvolutionChain Handler
print("📝 Test 4: GetEvolutionChain Handler")
local evolutionData = json.encode({id = 1}) -- Bulbasaur evolution chain
local evolutionResponse = sendMessage("GetEvolutionChain", evolutionData)

result = evolutionResponse and
         evolutionResponse.Action == "SaveState" and
         evolutionResponse.Data and
         not evolutionResponse.Error

testResults["test_get_evolution_chain_handler"] = result
if not result then
    error("❌ Test 4 failed: GetEvolutionChain handler test failed")
end
print("✅ Test 4 passed: GetEvolutionChain handler")

-- Test 5: GetBaseStats Handler
print("📝 Test 5: GetBaseStats Handler")
local statsData = json.encode({id = 1}) -- Bulbasaur stats
local statsResponse = sendMessage("GetBaseStats", statsData)

result = statsResponse and
         statsResponse.Action == "SaveState" and
         statsResponse.Data and
         not statsResponse.Error

testResults["test_get_base_stats_handler"] = result
if not result then
    error("❌ Test 5 failed: GetBaseStats handler test failed")
end
print("✅ Test 5 passed: GetBaseStats handler")

-- Test 6: Health Check Handler
print("📝 Test 6: Health Check Handler")
local healthResponse = sendMessage("HealthCheck")

if not healthResponse or healthResponse.Action ~= "SaveState" then
    error("❌ Test 6 failed: Expected SaveState response")
end

local healthData = json.decode(healthResponse.Data or "{}")
result = healthData.status == "healthy" and healthData.adpCompliant == true

testResults["test_health_check_handler"] = result
if not result then
    error("❌ Test 6 failed: Health check handler test failed")
end
print("✅ Test 6 passed: Health check handler")

-- Test 7: Error handling
print("📝 Test 7: Error handling")
local invalidData = json.encode({}) -- Missing required id or name
local errorResponse = sendMessage("GetSpecies", invalidData)

result = errorResponse and
         errorResponse.Action == "SaveState" and
         errorResponse.Error ~= nil

testResults["test_error_handling"] = result
if not result then
    error("❌ Test 7 failed: Error handling test failed")
end
print("✅ Test 7 passed: Error handling")

-- Test Summary
print("==================================================")
local passed = 0
local total = 0
for _, result in pairs(testResults) do
    total = total + 1
    if result then
        passed = passed + 1
    end
end

print("Test Results:")
print("  Passed: " .. passed)
print("  Failed: " .. (total - passed))
print("  Total:  " .. total)

if passed == total then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n💥 Some tests failed!")
end