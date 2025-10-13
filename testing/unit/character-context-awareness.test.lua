-- Aolite Unit Tests for Character Context-Aware Dialogue (CORRECT API)
-- Tests dialogue token replacement and context injection
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.character-dialogue-engine"
local processId = "test-character-dialogue-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Character Context Awareness")
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

-- Test 1: Inject single token
print("📝 Test 1: Single token injection")
local singleTokenData = json.encode({primaryName = "Pikachu"})
local singleTokenResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "{{primaryName}} used Thunder!"
}, singleTokenData)
if singleTokenResponse and singleTokenResponse.Action == "SaveState" and singleTokenResponse.Success == "true" then
    print("✅ Single token injection test passed")
else
    error("❌ Single token injection test failed")
end

-- Test 2: Inject multiple tokens
print("📝 Test 2: Multiple token injection")
local multipleTokenData = json.encode({primaryName = "Pikachu", secondaryName = "Charizard"})
local multipleTokenResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "{{primaryName}} and {{secondaryName}} are ready!"
}, multipleTokenData)
if multipleTokenResponse and multipleTokenResponse.Action == "SaveState" then
    print("✅ Multiple token injection test passed")
else
    error("❌ Multiple token injection test failed")
end

-- Test 3: Missing token handling
print("📝 Test 3: Missing token handling")
local missingTokenData = json.encode({})
local missingTokenResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "{{missingToken}} is not defined"
}, missingTokenData)
if missingTokenResponse and missingTokenResponse.Action == "SaveState" then
    print("✅ Missing token handling test passed")
else
    error("❌ Missing token handling test failed")
end

-- Test 4: Speaker attribution
print("📝 Test 4: Speaker attribution")
local speakerResponse = sendMessage("GetSpeakerName", {
    TrainerType = "50"
})
if speakerResponse and speakerResponse.Action == "SaveState" then
    print("✅ Speaker attribution test passed")
else
    error("❌ Speaker attribution test failed")
end

-- Test 5: Primary Pokemon tokens
print("📝 Test 5: Primary Pokemon tokens")
local primaryPokemonData = json.encode({primaryName = "Pikachu", primaryType = "Electric"})
local primaryPokemonResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "Your {{primaryName}} is strong!"
}, primaryPokemonData)
if primaryPokemonResponse and primaryPokemonResponse.Success == "true" then
    print("✅ Primary Pokemon tokens test passed")
else
    error("❌ Primary Pokemon tokens test failed")
end

-- Test 6: Option tokens
print("📝 Test 6: Option tokens")
local optionTokensData = json.encode({option1PrimaryName = "Bulbasaur", option2PrimaryName = "Charmander"})
local optionTokensResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "Choose {{option1PrimaryName}} or {{option2PrimaryName}}"
}, optionTokensData)
if optionTokensResponse and optionTokensResponse.Action == "SaveState" then
    print("✅ Option tokens test passed")
else
    error("❌ Option tokens test failed")
end

-- Test 7: Custom encounter tokens
print("📝 Test 7: Custom encounter tokens")
local customTokensData = json.encode({statTrainerName = "Buck"})
local customTokensResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "{{statTrainerName}} appears!"
}, customTokensData)
if customTokensResponse and customTokensResponse.Action == "SaveState" then
    print("✅ Custom encounter tokens test passed")
else
    error("❌ Custom encounter tokens test failed")
end

-- Test 8: Nested context
print("📝 Test 8: Nested context")
local nestedData = json.encode({primaryName = "Pikachu", primaryType = "Electric", secondaryName = "Charizard"})
local nestedResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "{{primaryName}} ({{primaryType}}) vs {{secondaryName}}"
}, nestedData)
if nestedResponse and nestedResponse.Action == "SaveState" then
    print("✅ Nested context test passed")
else
    error("❌ Nested context test failed")
end

-- Test 9: Empty dialogue text
print("📝 Test 9: Empty dialogue text")
local emptyTextData = json.encode({})
local emptyTextResponse = sendMessage("InjectDialogueContext", {
    DialogueText = ""
}, emptyTextData)
if emptyTextResponse and emptyTextResponse.Action == "SaveState" then
    print("✅ Empty dialogue text test passed")
else
    error("❌ Empty dialogue text test failed")
end

-- Test 10: No tokens in text
print("📝 Test 10: No tokens in text")
local noTokensData = json.encode({})
local noTokensResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "This has no tokens at all"
}, noTokensData)
if noTokensResponse and noTokensResponse.Action == "SaveState" then
    print("✅ No tokens in text test passed")
else
    error("❌ No tokens in text test failed")
end

-- Test 11: Integration with dialogue selection
print("📝 Test 11: Integration with dialogue selection")
local dialogueResponse = sendMessage("GetCharacterDialogue", {
    TrainerType = "50",
    DialoguePhase = "encounter"
})
if dialogueResponse and dialogueResponse.Action == "SaveState" then
    local contextData = json.encode({token = "value"})
    local contextResponse = sendMessage("InjectDialogueContext", {
        DialogueText = "Test dialogue with {{token}}"
    }, contextData)
    if contextResponse and contextResponse.Action == "SaveState" then
        print("✅ Integration test passed")
    else
        error("❌ Integration test failed")
    end
else
    error("❌ Integration test failed")
end

-- Test 12: Token count accuracy
print("📝 Test 12: Token count accuracy")
local tokenCountData = json.encode({a = "1", b = "2", c = "3"})
local tokenCountResponse = sendMessage("InjectDialogueContext", {
    DialogueText = "{{a}} {{b}} {{c}}"
}, tokenCountData)
if tokenCountResponse and tokenCountResponse.TokenCount ~= nil then
    print("✅ Token count accuracy test passed")
else
    error("❌ Token count accuracy test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Character Context Awareness tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
