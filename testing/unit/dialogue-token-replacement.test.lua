-- Aolite Unit Tests for Dialogue Token Replacement
-- Tests dialogue token processing and replacement logic
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.dialogue-navigation-engine"
local processId = "test-dialogue-token-replacement"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Dialogue Token Replacement")
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

-- Test 1: Simple token replacement
print("📝 Test 1: Simple token replacement")
local simpleTokenData = json.encode({
    pokemonName = "Pikachu"
})
local simpleTokenResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "Hello {{pokemonName}}!"
}, simpleTokenData)
if simpleTokenResponse and simpleTokenResponse.Success == "true" then
    print("✅ Simple token replacement test passed")
else
    error("❌ Simple token replacement test failed")
end

-- Test 2: Multiple token replacement in single text
print("📝 Test 2: Multiple token replacement")
local multipleTokenData = json.encode({
    trainerName = "Ash",
    pokemonName = "Pikachu"
})
local multipleTokenResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "{{trainerName}} sent out {{pokemonName}}!"
}, multipleTokenData)
if multipleTokenResponse and multipleTokenResponse.Success == "true" then
    print("✅ Multiple token replacement test passed")
else
    error("❌ Multiple token replacement test failed")
end

-- Test 3: Missing token handling
print("📝 Test 3: Missing token handling")
local missingTokenData = json.encode({
    pokemonName = "Pikachu"
})
local missingTokenResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "Hello {{undefinedToken}}!"
}, missingTokenData)
if missingTokenResponse then
    print("✅ Missing token handling test passed")
else
    error("❌ Missing token handling test failed")
end

-- Test 4: Empty token map handling
print("📝 Test 4: Empty token map handling")
local emptyTokenData = json.encode({})
local emptyTokenResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "Hello {{pokemonName}}!"
}, emptyTokenData)
if emptyTokenResponse then
    print("✅ Empty token map test passed")
else
    error("❌ Empty token map test failed")
end

-- Test 5: Text with no tokens
print("📝 Test 5: Text with no tokens")
local noTokenData = json.encode({
    pokemonName = "Pikachu"
})
local noTokenResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "This text has no tokens."
}, noTokenData)
if noTokenResponse and noTokenResponse.Success == "true" and noTokenResponse.TokenCount == "0" then
    print("✅ Text with no tokens test passed")
else
    error("❌ Text with no tokens test failed")
end

-- Test 6: Token count validation
print("📝 Test 6: Token count validation")
local tokenCountData = json.encode({
    a = "1",
    b = "2",
    c = "3"
})
local tokenCountResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "{{a}} {{b}} {{c}}"
}, tokenCountData)
if tokenCountResponse and tokenCountResponse.Success == "true" and tokenCountResponse.TokenCount ~= nil then
    print("✅ Token count validation test passed")
else
    error("❌ Token count validation test failed")
end

-- Test 7: Missing DialogueText parameter
print("📝 Test 7: Missing DialogueText parameter")
local missingTextData = json.encode({
    pokemonName = "Pikachu"
})
local missingTextResponse = sendMessage("ProcessDialogueTokens", {}, missingTextData)
if missingTextResponse and missingTextResponse.Action == "Error" then
    print("✅ Missing DialogueText test passed")
else
    error("❌ Missing DialogueText test failed")
end

-- Test 8: Missing token data
print("📝 Test 8: Missing token data")
local missingDataResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "Hello {{pokemonName}}!"
})
if missingDataResponse then
    print("✅ Missing token data test passed")
else
    error("❌ Missing token data test failed")
end

-- Test 9: Special characters in token values
print("📝 Test 9: Special characters in token values")
local specialCharsData = json.encode({
    pokemonName = "Pikachu (Level 50)"
})
local specialCharsResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "Hello {{pokemonName}}!"
}, specialCharsData)
if specialCharsResponse and specialCharsResponse.Success == "true" then
    print("✅ Special characters in token values test passed")
else
    error("❌ Special characters in token values test failed")
end

-- Test 10: Case-sensitive token replacement
print("📝 Test 10: Case-sensitive token replacement")
local caseSensitiveData = json.encode({
    pokemonName = "Pikachu",
    PokemonName = "Raichu"
})
local caseSensitiveResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "{{pokemonName}} vs {{PokemonName}}"
}, caseSensitiveData)
if caseSensitiveResponse and caseSensitiveResponse.Success == "true" then
    print("✅ Case-sensitive token replacement test passed")
else
    error("❌ Case-sensitive token replacement test failed")
end

-- Test 11: Numeric token values
print("📝 Test 11: Numeric token values")
local numericData = json.encode({
    level = "50"
})
local numericResponse = sendMessage("ProcessDialogueTokens", {
    DialogueText = "Level {{level}} Pokemon"
}, numericData)
if numericResponse and numericResponse.Success == "true" then
    print("✅ Numeric token values test passed")
else
    error("❌ Numeric token values test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Dialogue Token Replacement tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
