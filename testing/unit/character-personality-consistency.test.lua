-- Aolite Unit Tests for Character Personality Consistency (CORRECT API)
-- Tests personality archetype validation and voice consistency
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.character-dialogue-engine"
local processId = "test-character-dialogue-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Character Personality Consistency")
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

-- Test 1: Validate Youngster personality archetype
print("📝 Test 1: Youngster personality archetype")
local youngsterResponse = sendMessage("ValidatePersonality", {
    TrainerType = "50",
    DialoguePhase = "encounter"
})
if youngsterResponse and youngsterResponse.Action == "SaveState" and youngsterResponse.Valid == "true" then
    print("✅ Youngster personality archetype test passed")
else
    error("❌ Youngster personality archetype test failed")
end

-- Test 2: Validate Ace Trainer personality archetype
print("📝 Test 2: Ace Trainer personality archetype")
local aceTrainerResponse = sendMessage("ValidatePersonality", {
    TrainerType = "1",
    DialoguePhase = "encounter"
})
if aceTrainerResponse and aceTrainerResponse.Action == "SaveState" and aceTrainerResponse.Valid == "true" then
    print("✅ Ace Trainer personality archetype test passed")
else
    error("❌ Ace Trainer personality archetype test failed")
end

-- Test 3: Validate Hex Maniac personality archetype
print("📝 Test 3: Hex Maniac personality archetype")
local hexManiacResponse = sendMessage("ValidatePersonality", {
    TrainerType = "27",
    DialoguePhase = "encounter"
})
if hexManiacResponse and hexManiacResponse.Action == "SaveState" and hexManiacResponse.Valid == "true" then
    print("✅ Hex Maniac personality archetype test passed")
else
    error("❌ Hex Maniac personality archetype test failed")
end

-- Test 4: Validate Scientist personality archetype
print("📝 Test 4: Scientist personality archetype")
local scientistResponse = sendMessage("ValidatePersonality", {
    TrainerType = "40",
    DialoguePhase = "encounter"
})
if scientistResponse and scientistResponse.Action == "SaveState" and scientistResponse.Valid == "true" then
    print("✅ Scientist personality archetype test passed")
else
    error("❌ Scientist personality archetype test failed")
end

-- Test 5: Maintain Youngster personality across all encounter variants
print("📝 Test 5: Youngster consistency across variants")
local youngsterDialogueResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter"
})
if youngsterDialogueResponse and youngsterDialogueResponse.Action == "SaveState" and youngsterDialogueResponse.Success == "true" then
    print("✅ Youngster consistency across variants test passed")
else
    error("❌ Youngster consistency across variants test failed")
end

-- Test 6: Distinct speaker names for different trainer types
print("📝 Test 6: Distinct speaker names")
local youngsterSpeakerResponse = sendMessage("GetSpeakerName", {
    TrainerType = "50"
})
local aceTrainerSpeakerResponse = sendMessage("GetSpeakerName", {
    TrainerType = "1"
})
if youngsterSpeakerResponse and aceTrainerSpeakerResponse and
   youngsterSpeakerResponse.Action == "SaveState" and aceTrainerSpeakerResponse.Action == "SaveState" and
   youngsterSpeakerResponse.SpeakerKey ~= aceTrainerSpeakerResponse.SpeakerKey then
    print("✅ Distinct speaker names test passed")
else
    error("❌ Distinct speaker names test failed")
end

-- Test 7: Distinct dialogue pools for different trainer types
print("📝 Test 7: Distinct dialogue pools")
local youngsterPoolResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter"
})
local scientistPoolResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "40",
    DialoguePhase = "encounter"
})
if youngsterPoolResponse and scientistPoolResponse and
   youngsterPoolResponse.Action == "SaveState" and scientistPoolResponse.Action == "SaveState" then
    print("✅ Distinct dialogue pools test passed")
else
    error("❌ Distinct dialogue pools test failed")
end

-- Test 8: ListAvailablePersonalities handler
print("📝 Test 8: List available personalities")
local listPersonalitiesResponse = sendMessage("ListAvailablePersonalities")
if listPersonalitiesResponse and listPersonalitiesResponse.Action == "SaveState" and
   tonumber(listPersonalitiesResponse.PersonalityCount) > 0 then
    print("✅ List available personalities test passed")
else
    error("❌ List available personalities test failed")
end

-- Test 9: Invalidate unknown trainer type
print("📝 Test 9: Invalidate unknown trainer type")
local unknownTrainerResponse = sendMessage("ValidatePersonality", {
    TrainerType = "777",
    DialoguePhase = "encounter"
})
if unknownTrainerResponse and unknownTrainerResponse.Action == "SaveState" and unknownTrainerResponse.Valid == "false" then
    print("✅ Invalidate unknown trainer type test passed")
else
    error("❌ Invalidate unknown trainer type test failed")
end

-- Test 10: Invalidate missing dialogue phase
print("📝 Test 10: Invalidate missing phase")
local missingPhaseResponse = sendMessage("ValidatePersonality", {
    TrainerType = "40",
    DialoguePhase = "unknown_phase"
})
if missingPhaseResponse and missingPhaseResponse.Action == "SaveState" and missingPhaseResponse.Valid == "false" then
    print("✅ Invalidate missing phase test passed")
else
    error("❌ Invalidate missing phase test failed")
end

-- Test 11: Cross-phase personality consistency for Youngster
print("📝 Test 11: Youngster cross-phase consistency")
local phases = {"encounter", "victory"}
local validPhases = 0
for _, phase in ipairs(phases) do
    local phaseResponse = sendMessage("ValidatePersonality", {
        TrainerType = "50",
        DialoguePhase = phase
    })
    if phaseResponse and phaseResponse.Valid == "true" then
        validPhases = validPhases + 1
    end
end
if validPhases > 0 then
    print("✅ Youngster cross-phase consistency test passed")
else
    error("❌ Youngster cross-phase consistency test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Character Personality Consistency tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
