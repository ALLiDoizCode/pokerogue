-- Aolite Unit Tests for Capture Engine Process
-- Tests capture probability calculation, success determination, and Pokemon storage
-- Migrated to correct aolite API pattern

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.capture-engine"
local processId = "test-capture-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Capture Engine")
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

-- Test data fixtures
local mockWildPokemon = {
    speciesId = 25, -- Pikachu
    level = 10,
    hp = 30,
    maxHp = 35,
    catchRate = 190,
    stats = {hp = 35, attack = 30, defense = 25, spAttack = 30, spDefense = 25, speed = 45},
    type1 = "electric",
    type2 = nil,
    statusEffect = "none",
    abilities = {"static"},
    weight = 60,
    baseSpeed = 90,
    originalTrainer = "wild"
}

local mockLowHPPokemon = {
    speciesId = 1, -- Bulbasaur
    level = 5,
    hp = 2,
    maxHp = 20,
    catchRate = 45,
    stats = {hp = 20, attack = 15, defense = 15, spAttack = 20, spDefense = 20, speed = 15},
    type1 = "grass",
    type2 = "poison",
    statusEffect = "sleep",
    originalTrainer = "wild"
}

local mockGameState = {
    playerId = "test-player-123",
    timestamp = 1695123456,
    version = 1,
    player = {
        party = {},
        pc = {},
        pokedex = {
            seen = {},
            caught = 5,
            species = {}
        }
    }
}

-- Test 1: Process Ping
print("📝 Test 1: Process Ping")
local pingResponse = sendMessage("Ping")
if pingResponse and pingResponse.Action == "Pong" then
    print("✅ Ping test passed")
else
    error("❌ Ping test failed")
end

-- Test 2: Calculate Capture Rate
print("📝 Test 2: Calculate Capture Rate")
local captureRateData = {
    pokemon = mockWildPokemon,
    ballType = "pokeball",
    captureContext = {},
    gameState = mockGameState
}
local captureRateResponse = sendMessage("ProcessLogic", {
    Operation = "calculateCaptureRate"
}, json.encode(captureRateData))

if captureRateResponse and captureRateResponse.Action == "SaveState" then
    local data = json.decode(captureRateResponse.Data)
    if data and data.captureData then
        if type(data.captureData.captureRate) ~= "number" then
            error("❌ Capture rate test failed - captureRate is not a number")
        end
        if data.captureData.captureRate < 0 or data.captureData.captureRate > 1 then
            error("❌ Capture rate test failed - captureRate out of bounds (0-1)")
        end
        print("✅ Capture rate calculation test passed - Rate: " .. string.format("%.2f", data.captureData.captureRate))
    else
        error("❌ Capture rate test failed - missing capture data")
    end
else
    error("❌ Capture rate test failed - no valid response")
end

-- Test 3: Calculate Capture Rate with Better Conditions
print("📝 Test 3: Capture Rate with Better Conditions")
local betterCaptureData = {
    pokemon = mockLowHPPokemon,
    ballType = "ultraball",
    captureContext = {},
    gameState = mockGameState
}
local betterCaptureResponse = sendMessage("ProcessLogic", {
    Operation = "calculateCaptureRate"
}, json.encode(betterCaptureData))

if betterCaptureResponse and betterCaptureResponse.Action == "SaveState" then
    local data = json.decode(betterCaptureResponse.Data)
    if data and data.captureData then
        if data.captureData.statusModifier <= 1.0 then
            error("❌ Better conditions test failed - sleep should increase capture rate")
        end
        if data.captureData.ballModifier ~= 2.0 then
            error("❌ Better conditions test failed - Ultra Ball should have 2.0x modifier")
        end
        print("✅ Better conditions test passed - Status: " .. data.captureData.statusModifier .. "x, Ball: " .. data.captureData.ballModifier .. "x")
    else
        error("❌ Better conditions test failed - missing capture data")
    end
else
    error("❌ Better conditions test failed - no valid response")
end

-- Test 4: Master Ball Guaranteed Capture
print("📝 Test 4: Master Ball Guaranteed Capture")
local masterBallData = {
    pokemon = mockWildPokemon,
    ballType = "masterball",
    captureContext = {},
    gameState = mockGameState
}
local masterBallResponse = sendMessage("ProcessLogic", {
    Operation = "calculateCaptureRate"
}, json.encode(masterBallData))

if masterBallResponse and masterBallResponse.Action == "SaveState" then
    local data = json.decode(masterBallResponse.Data)
    if data and data.captureData then
        if data.captureData.captureRate ~= 1.0 then
            error("❌ Master Ball test failed - should guarantee capture (rate = 1.0)")
        end
        print("✅ Master Ball test passed - Guaranteed capture")
    else
        error("❌ Master Ball test failed - missing capture data")
    end
else
    error("❌ Master Ball test failed - no valid response")
end

-- Test 5: Attempt Capture Success
print("📝 Test 5: Attempt Capture")
local attemptCaptureData = {
    pokemon = mockWildPokemon,
    ballType = "masterball",
    captureContext = {location = "route1"},
    gameState = mockGameState
}
local attemptResponse = sendMessage("ProcessLogic", {
    Operation = "attemptCapture"
}, json.encode(attemptCaptureData))

if attemptResponse and attemptResponse.Action == "SaveState" then
    local data = json.decode(attemptResponse.Data)
    if data and data.captureResult then
        if data.captureResult.captureSuccess ~= true then
            error("❌ Attempt capture test failed - Master Ball should guarantee success")
        end
        if not data.captureResult.capturedPokemon then
            error("❌ Attempt capture test failed - missing captured Pokemon")
        end
        print("✅ Attempt capture test passed - Success: " .. tostring(data.captureResult.captureSuccess))
    else
        error("❌ Attempt capture test failed - missing capture result")
    end
else
    error("❌ Attempt capture test failed - no valid response")
end

-- Test 6: Validate Capture - Valid Case
print("📝 Test 6: Validate Capture - Valid")
local validateValidData = {
    pokemon = mockWildPokemon,
    ballType = "pokeball",
    captureContext = {}
}
local validateValidResponse = sendMessage("ProcessLogic", {
    Operation = "validateCapture"
}, json.encode(validateValidData))

if validateValidResponse and validateValidResponse.Action == "SaveState" then
    local data = json.decode(validateValidResponse.Data)
    if data and data.validationResult then
        if data.validationResult.valid ~= true then
            error("❌ Validate capture (valid) test failed - should be valid")
        end
        print("✅ Validate capture (valid) test passed")
    else
        error("❌ Validate capture (valid) test failed - missing validation result")
    end
else
    error("❌ Validate capture (valid) test failed - no valid response")
end

-- Test 7: Validate Capture - Fainted Pokemon
print("📝 Test 7: Validate Capture - Fainted Pokemon")
local faintedPokemon = json.decode(json.encode(mockWildPokemon))
faintedPokemon.hp = 0

local validateFaintedData = {
    pokemon = faintedPokemon,
    ballType = "pokeball",
    captureContext = {}
}
local validateFaintedResponse = sendMessage("ProcessLogic", {
    Operation = "validateCapture"
}, json.encode(validateFaintedData))

if validateFaintedResponse and validateFaintedResponse.Action == "SaveState" then
    local data = json.decode(validateFaintedResponse.Data)
    if data and data.validationResult then
        if data.validationResult.valid ~= false then
            error("❌ Validate capture (fainted) test failed - should be invalid")
        end
        print("✅ Validate capture (fainted) test passed - Correctly rejected fainted Pokemon")
    else
        error("❌ Validate capture (fainted) test failed - missing validation result")
    end
else
    error("❌ Validate capture (fainted) test failed - no valid response")
end

-- Test 8: Validate Capture - Invalid Ball
print("📝 Test 8: Validate Capture - Invalid Ball")
local validateInvalidBallData = {
    pokemon = mockWildPokemon,
    ballType = "invalidball",
    captureContext = {}
}
local validateInvalidBallResponse = sendMessage("ProcessLogic", {
    Operation = "validateCapture"
}, json.encode(validateInvalidBallData))

if validateInvalidBallResponse and validateInvalidBallResponse.Action == "SaveState" then
    local data = json.decode(validateInvalidBallResponse.Data)
    if data and data.validationResult then
        if data.validationResult.valid ~= false then
            error("❌ Validate capture (invalid ball) test failed - should be invalid")
        end
        print("✅ Validate capture (invalid ball) test passed - Correctly rejected invalid ball")
    else
        error("❌ Validate capture (invalid ball) test failed - missing validation result")
    end
else
    error("❌ Validate capture (invalid ball) test failed - no valid response")
end

-- Test 9: Validate Capture - Trainer Pokemon
print("📝 Test 9: Validate Capture - Trainer Pokemon")
local trainerPokemon = json.decode(json.encode(mockWildPokemon))
trainerPokemon.originalTrainer = "gym-leader-brock"

local validateTrainerData = {
    pokemon = trainerPokemon,
    ballType = "pokeball",
    captureContext = {}
}
local validateTrainerResponse = sendMessage("ProcessLogic", {
    Operation = "validateCapture"
}, json.encode(validateTrainerData))

if validateTrainerResponse and validateTrainerResponse.Action == "SaveState" then
    local data = json.decode(validateTrainerResponse.Data)
    if data and data.validationResult then
        if data.validationResult.valid ~= false then
            error("❌ Validate capture (trainer) test failed - should be invalid")
        end
        print("✅ Validate capture (trainer) test passed - Correctly rejected trainer Pokemon")
    else
        error("❌ Validate capture (trainer) test failed - missing validation result")
    end
else
    error("❌ Validate capture (trainer) test failed - no valid response")
end

-- Test 10: Invalid Operation Handling
print("📝 Test 10: Invalid Operation Handling")
local invalidResponse = sendMessage("ProcessLogic", {
    Operation = "invalidOperation"
}, json.encode({}))

if invalidResponse and invalidResponse.Action == "Error" then
    print("✅ Invalid operation handling test passed")
else
    error("❌ Invalid operation handling test failed - expected error response")
end

-- Test 11: ADP Info Handler
print("📝 Test 11: ADP Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    local data = json.decode(infoResponse.Data)
    if data and data.process then
        print("✅ ADP Info handler test passed - Process: " .. (data.process.name or "unknown"))
    else
        error("❌ ADP Info handler test failed - missing process metadata")
    end
else
    error("❌ ADP Info handler test failed - no valid response")
end

-- Test Summary
print("==================================================")
print("🎉 All Capture Engine tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
