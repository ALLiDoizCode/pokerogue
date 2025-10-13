-- ============================================================================
-- Special Event Encounters Tests
-- ============================================================================
-- Tests event encounter aggregation, mystery encounter changes, music, and species luck
-- Framework: aolite
-- ============================================================================

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.special-event-engine"
local processId = "test-special-event-encounters"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Special Event Encounters")
print("Process ID:", processId)

-- Helper to send message and capture response
local function sendMessage(action, tags)
    local msg = {
        From = processId,
        Target = processId,
        Action = action
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Retrieve event encounters during Winter Holiday
print("📝 Test 1: Retrieve event encounters during Winter Holiday")
local testTime = 1735084800000
local result = sendMessage("GetEventEncounters", {CurrentTime = tostring(testTime)})

if result.Action ~= "SaveState" or result.Success ~= "true" or result.EncounterCount ~= "20" then
    error("❌ Test 1 failed: Expected SaveState with 20 encounters")
end

local encounters = json.decode(result.Data)
if #encounters ~= 20 then
    error("❌ Test 1 failed: Expected 20 encounters in data")
end

-- Verify GIMMIGHOUL has blockEvolution
if encounters[1].species ~= 1002 or not encounters[1].blockEvolution then
    error("❌ Test 1 failed: Expected GIMMIGHOUL with blockEvolution")
end
print("✅ Test 1 passed: Event encounters during Winter Holiday")

-- Test 2: Return empty encounters when no event active
print("📝 Test 2: Return empty encounters when no event active")
testTime = 1736553600000
result = sendMessage("GetEventEncounters", {CurrentTime = tostring(testTime)})

if result.EncounterCount ~= "0" then
    error("❌ Test 2 failed: Expected 0 encounters")
end
print("✅ Test 2 passed: Empty encounters when no event active")

-- Test 3: Retrieve mystery encounter tier changes
print("📝 Test 3: Retrieve mystery encounter tier changes")
testTime = 1735084800000
result = sendMessage("GetMysteryEncounterChanges", {CurrentTime = tostring(testTime)})

if result.Action ~= "SaveState" or result.ChangeCount ~= "5" then
    error("❌ Test 3 failed: Expected SaveState with 5 changes")
end

local changes = json.decode(result.Data)
if #changes ~= 5 then
    error("❌ Test 3 failed: Expected 5 changes in data")
end

-- Verify DELIBIRDY tier change
if changes[1].mysteryEncounter ~= 0 or changes[1].tier ~= 0 then
    error("❌ Test 3 failed: Expected DELIBIRDY tier change")
end

-- Verify disabled encounters
if not changes[2].disable then
    error("❌ Test 3 failed: Expected disabled encounter")
end
print("✅ Test 3 passed: Mystery encounter tier changes")

-- Test 4: Return empty mystery encounter changes when not set
print("📝 Test 4: Return empty mystery encounter changes when not set")
testTime = 1743638400000
result = sendMessage("GetMysteryEncounterChanges", {CurrentTime = tostring(testTime)})

if result.ChangeCount ~= "0" then
    error("❌ Test 4 failed: Expected 0 changes")
end
print("✅ Test 4 passed: Empty mystery encounter changes")

-- Test 5: Retrieve music replacement for April Fools
print("📝 Test 5: Retrieve music replacement for April Fools")
testTime = 1743638400000
result = sendMessage("GetEventMusicReplacement", {BgmKey = "title", CurrentTime = tostring(testTime)})

if result.Action ~= "SaveState" or result.ReplacementBgm ~= "title_afd" then
    error("❌ Test 5 failed: Expected SaveState with title_afd replacement")
end
print("✅ Test 5 passed: Music replacement for April Fools")

-- Test 6: Return original BGM when no replacement
print("📝 Test 6: Return original BGM when no replacement")
testTime = 1743638400000
result = sendMessage("GetEventMusicReplacement", {BgmKey = "some_other_bgm", CurrentTime = tostring(testTime)})

if result.ReplacementBgm ~= "some_other_bgm" then
    error("❌ Test 6 failed: Expected original BGM key")
end
print("✅ Test 6 passed: Original BGM when no replacement")

-- Test 7: Error when BgmKey missing
print("📝 Test 7: Error when BgmKey missing")
testTime = 1743638400000
result = sendMessage("GetEventMusicReplacement", {CurrentTime = tostring(testTime)})

if result.Action ~= "Error" or result.Error ~= "BgmKey parameter required" then
    error("❌ Test 7 failed: Expected Error with BgmKey parameter required message")
end
print("✅ Test 7 passed: Error when BgmKey missing")

-- Test 8: Check species luck boost for Year of the Snake
print("📝 Test 8: Check species luck boost for Year of the Snake")
testTime = 1738368000000
result = sendMessage("CheckSpeciesLuckBoost", {SpeciesId = "23", CurrentTime = tostring(testTime)})

if result.Action ~= "SaveState" or result.HasLuckBoost ~= "true" or result.LuckBoost ~= "1" then
    error("❌ Test 8 failed: Expected SaveState with luck boost for EKANS")
end
print("✅ Test 8 passed: Species luck boost for Year of the Snake")

-- Test 9: Return false for non-luck-boosted species
print("📝 Test 9: Return false for non-luck-boosted species")
testTime = 1738368000000
result = sendMessage("CheckSpeciesLuckBoost", {SpeciesId = "25", CurrentTime = tostring(testTime)})

if result.HasLuckBoost ~= "false" or result.LuckBoost ~= "0" then
    error("❌ Test 9 failed: Expected no luck boost for PIKACHU")
end
print("✅ Test 9 passed: False for non-luck-boosted species")

-- Test 10: Error when SpeciesId missing
print("📝 Test 10: Error when SpeciesId missing")
testTime = 1738368000000
result = sendMessage("CheckSpeciesLuckBoost", {CurrentTime = tostring(testTime)})

if result.Action ~= "Error" or result.Error ~= "SpeciesId parameter required" then
    error("❌ Test 10 failed: Expected Error with SpeciesId parameter required message")
end
print("✅ Test 10 passed: Error when SpeciesId missing")

-- Test 11: Retrieve event challenges for April Fools
print("📝 Test 11: Retrieve event challenges for April Fools")
testTime = 1743638400000
result = sendMessage("GetEventChallenges", {CurrentTime = tostring(testTime)})

if result.Action ~= "SaveState" or result.ChallengeCount ~= "1" then
    error("❌ Test 11 failed: Expected SaveState with 1 challenge")
end

local challenges = json.decode(result.Data)
if #challenges ~= 1 or challenges[1].challenge ~= 0 or challenges[1].value ~= 1 then
    error("❌ Test 11 failed: Expected INVERSE_BATTLE challenge")
end
print("✅ Test 11 passed: Event challenges for April Fools")

-- Test 12: Return empty challenges when not set
print("📝 Test 12: Return empty challenges when not set")
testTime = 1735084800000
result = sendMessage("GetEventChallenges", {CurrentTime = tostring(testTime)})

if result.ChallengeCount ~= "0" then
    error("❌ Test 12 failed: Expected 0 challenges")
end
print("✅ Test 12 passed: Empty challenges when not set")

-- Test 13: Validate event participation when event active
print("📝 Test 13: Validate event participation when event active")
testTime = 1735084800000
result = sendMessage("ValidateEventParticipation", {CurrentTime = tostring(testTime)})

if result.Action ~= "SaveState" or result.Eligible ~= "true" or result.Reason ~= "Event is active" then
    error("❌ Test 13 failed: Expected SaveState with eligible event participation")
end
print("✅ Test 13 passed: Event participation when event active")

-- Test 14: Validate event participation when no event active
print("📝 Test 14: Validate event participation when no event active")
testTime = 1736553600000
result = sendMessage("ValidateEventParticipation", {CurrentTime = tostring(testTime)})

if result.Eligible ~= "false" or result.Reason ~= "No active event" then
    error("❌ Test 14 failed: Expected ineligible event participation")
end
print("✅ Test 14 passed: Event participation when no event active")

-- Test 15: Handle PKMNDAY2025 luck boosted species
print("📝 Test 15: Handle PKMNDAY2025 luck boosted species")
testTime = 1740873600000
result = sendMessage("CheckSpeciesLuckBoost", {SpeciesId = "25", CurrentTime = tostring(testTime)})

-- PKMNDAY2025 is LUCK event but has no luckBoost value (only luckBoostedSpecies)
if result.HasLuckBoost ~= "false" or result.LuckBoost ~= "0" then
    error("❌ Test 15 failed: Expected no luck boost for PKMNDAY2025")
end
print("✅ Test 15 passed: PKMNDAY2025 luck boosted species")

-- Test 16: Handle Valentine luck boosted species
print("📝 Test 16: Handle Valentine luck boosted species")
testTime = 1739664000000
result = sendMessage("CheckSpeciesLuckBoost", {SpeciesId = "370", CurrentTime = tostring(testTime)})

-- Valentine has luckBoostedSpecies but no luckBoost value
if result.HasLuckBoost ~= "false" or result.LuckBoost ~= "0" then
    error("❌ Test 16 failed: Expected no luck boost for Valentine")
end
print("✅ Test 16 passed: Valentine luck boosted species")

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
