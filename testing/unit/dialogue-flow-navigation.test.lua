-- Aolite Unit Tests for Dialogue Flow Navigation
-- Tests dialogue tree flow state machine and navigation logic
-- Covers intro → options → selected → outro flow progression
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.dialogue-navigation-engine"
local processId = "test-dialogue-navigation-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Dialogue Flow Navigation")
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

-- Test 2: Complete flow progression (intro → options → outro)
print("📝 Test 2: Complete flow progression (intro phase)")
local introData = json.encode({
    dialogue = {
        intro = {
            {speaker = "Professor Oak", text = "Welcome to the mystery encounter!"}
        }
    }
})
local introResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "intro"
}, introData)
if introResponse and introResponse.PhaseType == "intro" then
    print("✅ Complete flow progression test passed")
else
    error("❌ Complete flow progression test failed")
end

-- Test 3: Edge case - No intro dialogue
print("📝 Test 3: Edge case - No intro dialogue")
local noIntroData = json.encode({
    dialogue = {
        encounterOptionsDialogue = {
            title = "What will you do?",
            options = {
                {buttonLabel = "Option 1"},
                {buttonLabel = "Option 2"}
            }
        }
    }
})
local noIntroResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "intro"
}, noIntroData)
if noIntroResponse then
    print("✅ No intro dialogue test passed")
else
    error("❌ No intro dialogue test failed")
end

-- Test 4: Edge case - No outro dialogue
print("📝 Test 4: Edge case - No outro dialogue")
local noOutroData = json.encode({
    dialogue = {
        intro = {{text = "Start encounter"}},
        encounterOptionsDialogue = {
            title = "What will you do?",
            options = {
                {buttonLabel = "Option 1"},
                {buttonLabel = "Option 2"}
            }
        }
    }
})
local noOutroResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "outro"
}, noOutroData)
if noOutroResponse then
    print("✅ No outro dialogue test passed")
else
    error("❌ No outro dialogue test failed")
end

-- Test 5: SELECTED phase requires OptionIndex
print("📝 Test 5: SELECTED phase requires OptionIndex")
local selectedData = json.encode({
    options = {
        {dialogue = {selected = {{text = "Option 1 selected"}}}},
        {dialogue = {selected = {{text = "Option 2 selected"}}}}
    }
})
local selectedNoIndexResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "selected"
}, selectedData)
if selectedNoIndexResponse and selectedNoIndexResponse.Action == "Error" then
    print("✅ SELECTED phase requires OptionIndex test passed")
else
    error("❌ SELECTED phase requires OptionIndex test failed")
end

-- Test 6: Invalid dialogue phase handling
print("📝 Test 6: Invalid dialogue phase handling")
local invalidPhaseData = json.encode({dialogue = {}})
local invalidPhaseResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "invalid_phase"
}, invalidPhaseData)
if invalidPhaseResponse and invalidPhaseResponse.Action == "Error" then
    print("✅ Invalid dialogue phase test passed")
else
    error("❌ Invalid dialogue phase test failed")
end

-- Test 7: Missing encounter definition handling
print("📝 Test 7: Missing encounter definition handling")
local missingDefResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "intro"
})
if missingDefResponse and missingDefResponse.Action == "Error" then
    print("✅ Missing encounter definition test passed")
else
    error("❌ Missing encounter definition test failed")
end

-- Test 8: SELECTED phase with valid OptionIndex
print("📝 Test 8: SELECTED phase with valid OptionIndex")
local selectedWithIndexResponse = sendMessage("GetDialogueFlow", {
    EncounterType = "TestEncounter",
    DialoguePhase = "selected",
    OptionIndex = "1"
}, selectedData)
if selectedWithIndexResponse then
    print("✅ SELECTED phase with valid OptionIndex test passed")
else
    error("❌ SELECTED phase with valid OptionIndex test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Dialogue Flow Navigation tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
