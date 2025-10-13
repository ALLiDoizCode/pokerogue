-- Aolite Unit Tests for Character Dialogue Selection (CORRECT API)
-- Tests dialogue variant selection, bounds checking, and edge cases
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.character-dialogue-engine"
local processId = "test-character-dialogue-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Character Dialogue Selection")
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

-- Test 1: ADP Info Handler
print("📝 Test 1: ADP Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ ADP Info handler test passed")
else
    error("❌ ADP Info handler test failed")
end

-- Test 2: GetCharacterDialogue - retrieve all variants
print("📝 Test 2: Get all dialogue variants")
local allVariantsResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter"
})
if allVariantsResponse and allVariantsResponse.Action == "SaveState" and allVariantsResponse.Success == "true" then
    print("✅ Get all dialogue variants test passed")
else
    error("❌ Get all dialogue variants test failed")
end

-- Test 3: GetCharacterDialogue - retrieve specific variant by index
print("📝 Test 3: Get specific variant by index")
local specificVariantResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "1",
    DialoguePhase = "encounter",
    VariantIndex = "1"
})
if specificVariantResponse and specificVariantResponse.Action == "SaveState" and specificVariantResponse.Success == "true" then
    print("✅ Get specific variant test passed")
else
    error("❌ Get specific variant test failed")
end

-- Test 4: GetCharacterDialogue - invalid trainer type
print("📝 Test 4: Invalid trainer type")
local invalidTrainerResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "999",
    DialoguePhase = "encounter"
})
if invalidTrainerResponse and invalidTrainerResponse.Action == "Error" then
    print("✅ Invalid trainer type test passed")
else
    error("❌ Invalid trainer type test failed")
end

-- Test 5: GetCharacterDialogue - missing trainer type
print("📝 Test 5: Missing trainer type")
local missingTrainerResponse = sendMessage("GetCharacterDialogue", {
    DialoguePhase = "encounter"
})
if missingTrainerResponse and missingTrainerResponse.Action == "Error" then
    print("✅ Missing trainer type test passed")
else
    error("❌ Missing trainer type test failed")
end

-- Test 6: SelectRandomDialogue - deterministic selection
print("📝 Test 6: Deterministic selection with same seed")
local seed = "12345"
local deterministicResponse1 = sendMessage("SelectRandomDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter",
    Seed = seed
})
local deterministicResponse2 = sendMessage("SelectRandomDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter",
    Seed = seed
})
if deterministicResponse1 and deterministicResponse2 and
   deterministicResponse1.VariantIndex == deterministicResponse2.VariantIndex then
    print("✅ Deterministic selection test passed")
else
    error("❌ Deterministic selection test failed")
end

-- Test 7: SelectRandomDialogue - different seeds
print("📝 Test 7: Different seeds produce results")
local diffSeedResponse1 = sendMessage("SelectRandomDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter",
    Seed = "11111"
})
local diffSeedResponse2 = sendMessage("SelectRandomDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter",
    Seed = "99999"
})
if diffSeedResponse1 and diffSeedResponse2 and
   diffSeedResponse1.Action == "SaveState" and diffSeedResponse2.Action == "SaveState" then
    print("✅ Different seeds test passed")
else
    error("❌ Different seeds test failed")
end

-- Test 8: SelectRandomDialogue - variants within bounds
print("📝 Test 8: Variants within bounds")
local boundsResponse = sendMessage("SelectRandomDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter",
    Seed = "54321"
})
if boundsResponse and boundsResponse.Action == "SaveState" and boundsResponse.Success == "true" then
    local variantIndex = tonumber(boundsResponse.VariantIndex)
    local variantCount = tonumber(boundsResponse.VariantCount)
    if variantIndex >= 1 and variantIndex <= variantCount then
        print("✅ Variants within bounds test passed")
    else
        error("❌ Variants within bounds test failed: index out of range")
    end
else
    error("❌ Variants within bounds test failed")
end

-- Test 9: SelectRandomDialogue - invalid trainer type
print("📝 Test 9: Select with invalid trainer type")
local invalidSelectResponse = sendMessage("SelectRandomDialogue", {
    TrainerType = "888",
    DialoguePhase = "encounter",
    Seed = "12345"
})
if invalidSelectResponse and invalidSelectResponse.Action == "Error" then
    print("✅ Select invalid trainer test passed")
else
    error("❌ Select invalid trainer test failed")
end

-- Test 10: SelectRandomDialogue - missing seed
print("📝 Test 10: Missing seed parameter")
local missingSeedResponse = sendMessage("SelectRandomDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter"
})
if missingSeedResponse and missingSeedResponse.Action == "Error" then
    print("✅ Missing seed test passed")
else
    error("❌ Missing seed test failed")
end

-- Test 11: Gender/sub-type variants - Breeder
print("📝 Test 11: Gender variants (Breeder)")
local breederResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "9",
    DialoguePhase = "encounter"
})
if breederResponse and breederResponse.Action == "SaveState" and breederResponse.Success == "true" then
    print("✅ Gender variants (Breeder) test passed")
else
    error("❌ Gender variants (Breeder) test failed")
end

-- Test 12: GetSpeakerName - Youngster/Lass
print("📝 Test 12: Gender variants (Youngster)")
local youngsterSpeakerResponse = sendMessage("GetSpeakerName", {
    TrainerType = "50",
    VariantIndex = "1"
})
if youngsterSpeakerResponse and youngsterSpeakerResponse.Action == "SaveState" and youngsterSpeakerResponse.Success == "true" then
    print("✅ Gender variants (Youngster) test passed")
else
    error("❌ Gender variants (Youngster) test failed")
end

-- Test 13: Edge case - single dialogue variant
print("📝 Test 13: Single dialogue variant")
local scientistResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "40",
    DialoguePhase = "encounter"
})
if scientistResponse and scientistResponse.Action == "SaveState" then
    print("✅ Single variant test passed")
else
    error("❌ Single variant test failed")
end

-- Test 14: Edge case - missing dialogue phase
print("📝 Test 14: Missing dialogue phase")
local missingPhaseResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "40",
    DialoguePhase = "defeat"
})
if missingPhaseResponse then
    print("✅ Missing phase test passed")
else
    error("❌ Missing phase test failed")
end

-- Test 15: Edge case - default to encounter phase
print("📝 Test 15: Default phase")
local defaultPhaseResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "50"
})
if defaultPhaseResponse and defaultPhaseResponse.Action == "SaveState" and defaultPhaseResponse.Success == "true" then
    print("✅ Default phase test passed")
else
    error("❌ Default phase test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Character Dialogue Selection tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
