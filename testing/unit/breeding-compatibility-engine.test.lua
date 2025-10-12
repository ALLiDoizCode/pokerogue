-- Aolite Unit Tests for Breeding Compatibility Engine
-- Tests breeding compatibility validation, success rate calculation, and breeding time estimation
-- Migrated to correct aolite API pattern

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.breeding-compatibility-engine"
local processId = "test-breeding-compatibility-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Breeding Compatibility Engine")
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

-- Test 1: Basic Breeding Compatibility Validation
print("📝 Test 1: Basic Breeding Compatibility Validation")
local compatResponse = sendMessage("ValidateBreedingPair", {
    Pokemon1Id = "pokemon_bulbasaur_001",
    Pokemon2Id = "pokemon_charmander_002",
    PlayerId = "test_player_001"
})
if compatResponse and compatResponse.Action == "BreedingCompatibilityResult" then
    if compatResponse.Success == "true" and compatResponse.EggGroupMatch == "true" then
        print("✅ Basic breeding compatibility validation passed")
    else
        error("❌ Expected compatible breeding pair")
    end
else
    error("❌ Basic breeding compatibility validation failed")
end

-- Test 2: Success Rate Calculation
print("📝 Test 2: Success Rate Calculation")
local rateResponse = sendMessage("CalculateSuccessRate", {
    Pokemon1Id = "pokemon_bulbasaur_001",
    Pokemon2Id = "pokemon_charmander_002",
    OvalCharm = "true"
})
if rateResponse and rateResponse.Action == "SuccessRateResult" then
    local rate = tonumber(rateResponse.SuccessRate)
    if rate and rate > 0 and rate <= 1 then
        print("✅ Success rate calculation passed")
    else
        error("❌ Invalid success rate value")
    end
else
    error("❌ Success rate calculation failed")
end

-- Test 3: Breeding Time Calculation
print("📝 Test 3: Breeding Time Calculation")
local timeResponse = sendMessage("CalculateBreedingTime", {
    Species1Id = "1",
    Species2Id = "4",
    OvalCharm = "true",
    FlameBody = "false"
})
if timeResponse and timeResponse.Action == "BreedingTimeResult" then
    local duration = tonumber(timeResponse.BreedingDuration)
    if duration and duration > 0 and duration <= 256 then
        print("✅ Breeding time calculation passed")
    else
        error("❌ Invalid breeding duration")
    end
else
    error("❌ Breeding time calculation failed")
end

-- Test 4: Ditto Special Case Compatibility
print("📝 Test 4: Ditto Special Case Compatibility")
local dittoResponse = sendMessage("ValidateBreedingPair", {
    Pokemon1Id = "pokemon_ditto_001",
    Pokemon2Id = "pokemon_pikachu_002",
    PlayerId = "test_player_001"
})
if dittoResponse and dittoResponse.Action == "BreedingCompatibilityResult" then
    print("✅ Ditto special case compatibility passed")
else
    error("❌ Ditto special case compatibility failed")
end

-- Test 5: Breeding Statistics Tracking
print("📝 Test 5: Breeding Statistics Tracking")
-- First record a breeding attempt
local recordResponse = sendMessage("RecordBreedingAttempt", {
    Pokemon1Id = "pokemon_bulbasaur_001",
    Pokemon2Id = "pokemon_charmander_002",
    Success = "true",
    SuccessRate = "0.65",
    PlayerId = "test_player_stats"
})
if recordResponse and recordResponse.Action == "BreedingAttemptRecorded" then
    -- Then get statistics
    local statsResponse = sendMessage("GetBreedingStatistics", {
        PlayerId = "test_player_stats"
    })
    if statsResponse and statsResponse.Action == "BreedingStatistics" then
        local attempts = tonumber(statsResponse.TotalAttempts)
        local successes = tonumber(statsResponse.SuccessfulBreedings)
        if attempts and successes and attempts >= 1 and successes >= 1 then
            print("✅ Breeding statistics tracking passed")
        else
            error("❌ Invalid breeding statistics")
        end
    else
        error("❌ Failed to get breeding statistics")
    end
else
    error("❌ Failed to record breeding attempt")
end

-- Test 6: Breeding Restrictions Validation
print("📝 Test 6: Breeding Restrictions Validation")
local restrictResponse = sendMessage("ValidateBreedingRestrictions", {
    Pokemon1Id = "pokemon_mewtwo_001",
    Pokemon2Id = "pokemon_pikachu_002",
    Species1Id = "150",
    Species2Id = "25"
})
if restrictResponse and restrictResponse.Action == "BreedingRestrictionsResult" then
    print("✅ Breeding restrictions validation passed")
else
    error("❌ Breeding restrictions validation failed")
end

-- Test 7: Health Check
print("📝 Test 7: Health Check")
local healthResponse = sendMessage("HealthCheck")
if healthResponse and healthResponse.Action == "HealthStatus" then
    if healthResponse.Status == "healthy" and healthResponse.Version == "1.0" then
        print("✅ Health check passed")
    else
        error("❌ Invalid health status")
    end
else
    error("❌ Health check failed")
end

-- Test 8: ADP v1.0 Info Handler
print("📝 Test 8: ADP v1.0 Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    if infoResponse.Data then
        local infoData = json.decode(infoResponse.Data)
        if infoData.Name == "Breeding Compatibility Engine" and infoData.protocolVersion == "1.0" then
            print("✅ ADP v1.0 Info handler passed")
        else
            error("❌ Invalid ADP info data")
        end
    else
        error("❌ Missing info data")
    end
else
    error("❌ ADP v1.0 Info handler failed")
end

-- Test 9: Error Handling for Missing Parameters
print("📝 Test 9: Error Handling for Missing Parameters")
local errorResponse = sendMessage("ValidateBreedingPair")
if errorResponse and errorResponse.Action == "Error" then
    if errorResponse.Error and string.find(errorResponse.Error, "Missing required parameters") then
        print("✅ Error handling for missing parameters passed")
    else
        error("❌ Invalid error message")
    end
else
    error("❌ Error handling for missing parameters failed")
end

-- Test 10: Edge Case - Same Pokemon Breeding
print("📝 Test 10: Edge Case - Same Pokemon Breeding")
local sameResponse = sendMessage("ValidateBreedingPair", {
    Pokemon1Id = "pokemon_same_001",
    Pokemon2Id = "pokemon_same_001",
    PlayerId = "test_player_001"
})
if sameResponse and sameResponse.Action == "BreedingCompatibilityResult" then
    print("✅ Edge case same Pokemon breeding passed")
else
    error("❌ Edge case same Pokemon breeding failed")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
print("📊 Test Summary:")
print("- ✅ Basic breeding compatibility validation")
print("- ✅ Success rate calculation with modifiers")
print("- ✅ Breeding time calculation")
print("- ✅ Ditto special case handling")
print("- ✅ Breeding statistics tracking")
print("- ✅ Breeding restrictions validation")
print("- ✅ Process health monitoring")
print("- ✅ ADP v1.0 compliance")
print("- ✅ Error handling")
print("- ✅ Edge case validation")
