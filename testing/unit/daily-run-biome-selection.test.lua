-- Unit tests for Daily Run Biome Selection
-- Tests deterministic biome selection using RNG seeding
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.daily-run-engine"
local processId = "test-daily-run-biome-selection"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Daily Run Biome Selection")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test counter
local testsRun = 0
local testsPassed = 0

-- Test 1: Biome selection determinism (same seed = same biome)
testsRun = testsRun + 1
print("\n📝 Test 1: Biome selection determinism with identical seeds")
local seed1 = "20250103biometest123456789012"  -- 30 characters (>= 24 required)
local response1 = sendMessage("GenerateDailyRun", nil, json.encode({seed = seed1}))

if not response1 or (response1.Action ~= "SaveState" and response1.Action ~= "DailyRunGenerated") then
    error("❌ Test 1 failed: GenerateDailyRun handler not working (Action=" .. tostring(response1 and response1.Action or "nil") .. ", Error=" .. tostring(response1 and response1.Error or "nil") .. ")")
end

-- Parse response data to get biome
local data1 = response1.Data and json.decode(response1.Data) or {}
local biome1 = data1.biome or data1.startingBiome or data1.biomeId

-- Second generation with same seed
local response2 = sendMessage("GenerateDailyRun", nil, json.encode({seed = seed1}))
local data2 = response2.Data and json.decode(response2.Data) or {}
local biome2 = data2.biome or data2.startingBiome or data2.biomeId

if biome1 and biome2 and biome1 == biome2 then
    print("✅ Test 1 passed: Same seed produces same biome (biome=" .. tostring(biome1) .. ")")
    testsPassed = testsPassed + 1
else
    error("❌ Test 1 failed: Same seed produced different biomes (biome1=" .. tostring(biome1) .. ", biome2=" .. tostring(biome2) .. ")")
end

-- Test 2: Different seeds produce potentially different biomes
testsRun = testsRun + 1
print("\n📝 Test 2: Different seeds can produce different biomes")
local seed3 = "20250104differentbio456789012"  -- 30 characters
local response3 = sendMessage("GenerateDailyRun", nil, json.encode({seed = seed3}))
local data3 = response3.Data and json.decode(response3.Data) or {}
local biome3 = data3.biome or data3.startingBiome or data3.biomeId

if biome3 then
    print("✅ Test 2 passed: Different seed produced biome (biome=" .. tostring(biome3) .. ")")
    testsPassed = testsPassed + 1
else
    error("❌ Test 2 failed: Failed to get biome for different seed")
end

-- Test 3: Biome is within valid range (1-33, excluding TOWN=0 and END=34)
testsRun = testsRun + 1
print("\n📝 Test 3: Biome ID is within valid range (1-33)")
if biome1 and biome1 >= 1 and biome1 <= 33 then
    print("✅ Test 3 passed: Biome ID is valid (biome=" .. tostring(biome1) .. ")")
    testsPassed = testsPassed + 1
else
    error("❌ Test 3 failed: Biome ID out of range (biome=" .. tostring(biome1) .. ")")
end

-- Test 4: Multiple generations with same seed all produce same biome
testsRun = testsRun + 1
print("\n📝 Test 4: Multiple generations with same seed (3 iterations)")
local biomes = {}
local testSeed = "20250105consisttest789012345"  -- 30 characters
for i = 1, 3 do
    local response = sendMessage("GenerateDailyRun", nil, json.encode({seed = testSeed}))
    local data = response.Data and json.decode(response.Data) or {}
    local biome = data.biome or data.startingBiome or data.biomeId
    table.insert(biomes, biome)
end

if biomes[1] == biomes[2] and biomes[2] == biomes[3] then
    print("✅ Test 4 passed: All 3 iterations produced same biome (biome=" .. tostring(biomes[1]) .. ")")
    testsPassed = testsPassed + 1
else
    error("❌ Test 4 failed: Inconsistent biomes (biomes=" .. table.concat(biomes, ", ") .. ")")
end

-- Test 5: Info Handler (ADP v1.0 compliance check)
testsRun = testsRun + 1
print("\n📝 Test 5: Info Handler (ADP v1.0 compliance)")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ Test 5 passed: Info handler works")
    testsPassed = testsPassed + 1
else
    error("❌ Test 5 failed: Info handler not working")
end

-- Results summary
print("\n" .. string.rep("=", 50))
print("Tests run: " .. testsRun)
print("Tests passed: " .. testsPassed)
print("Tests failed: " .. (testsRun - testsPassed))

if testsPassed == testsRun then
    print("✅ All daily run biome selection tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
    return true
else
    print("❌ Some daily run biome selection tests failed!")
    return false
end
