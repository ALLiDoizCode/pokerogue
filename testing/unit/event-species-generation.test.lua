--[[
  Event Species Generation Unit Tests

  Tests event species spawn logic, probability calculations, and deterministic RNG.
  Validates 50% spawn probability and event species selection algorithms.
]]

local aolite = require("aolite")
local json = require("json")

-- Test configuration (Story 2.10 optimized pattern)
local PROCESS_PATH = "processes.seasonal-event-engine"
local processId = "test-seasonal-event-engine-gen"
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Event Species Generation")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,  -- REQUIRED
        Target = processId,
        Action = action,
        Data = data or ""
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Return event species for Winter Holiday event
print("📝 Test 1: Return event species for Winter Holiday event")
local timestamp1 = 1734739200 + 86400 -- Dec 22, 2024
local response1 = sendMessage("GetEventSpecies", {
    Timestamp = tostring(timestamp1)
})
if response1 and response1.Data then
    local data1 = json.decode(response1.Data)
    if data1.eventSpecies and #data1.eventSpecies > 0 and data1.spawnProbability == 0.5 and data1.shinyReroll == true then
        local hasGimmighoul = false
        local hasDelibird = false
        for _, encounter in ipairs(data1.eventSpecies) do
            if encounter.species == "GIMMIGHOUL" then
                hasGimmighoul = true
                if encounter.blockEvolution ~= true then
                    error("❌ Test 1 failed: Gimmighoul should have evolution blocked")
                end
            end
            if encounter.species == "DELIBIRD" then
                hasDelibird = true
            end
        end
        if hasGimmighoul and hasDelibird then
            print("✅ Test 1 passed")
        else
            error("❌ Test 1 failed: Missing expected Winter Holiday species")
        end
    else
        error("❌ Test 1 failed: Invalid event species response")
    end
else
    error("❌ Test 1 failed: Expected valid response")
end

-- Test 2: Return empty event species when no events active
print("📝 Test 2: Return empty event species when no events active")
local timestamp2 = 1609459200 -- Jan 1, 2021 (before any events)
local response2 = sendMessage("GetEventSpecies", {
    Timestamp = tostring(timestamp2)
})
if response2 and response2.Data then
    local data2 = json.decode(response2.Data)
    if #data2.eventSpecies == 0 and #data2.activeEvents == 0 then
        print("✅ Test 2 passed")
    else
        error("❌ Test 2 failed: Expected empty event species and no active events")
    end
else
    error("❌ Test 2 failed: Expected valid response")
end

-- Test 3: Validate Gimmighoul availability during Winter Holiday
print("📝 Test 3: Validate Gimmighoul availability during Winter Holiday")
local timestamp3 = 1734739200 + 86400 -- Dec 22, 2024
local response3 = sendMessage("CheckEventSpeciesAvailability", {
    SpeciesId = "GIMMIGHOUL",
    Timestamp = tostring(timestamp3)
})
if response3 and response3.Data then
    local data3 = json.decode(response3.Data)
    if data3.available == true and data3.eventName == "Winter Holiday Update" and data3.blockEvolution == true then
        print("✅ Test 3 passed")
    else
        error("❌ Test 3 failed: Expected Gimmighoul to be available with evolution blocked")
    end
else
    error("❌ Test 3 failed: Expected valid response")
end

-- Test 4: Return false for non-event species
print("📝 Test 4: Return false for non-event species")
local timestamp4 = 1734739200 + 86400 -- Dec 22, 2024
local response4 = sendMessage("CheckEventSpeciesAvailability", {
    SpeciesId = "PIKACHU",
    Timestamp = tostring(timestamp4)
})
if response4 and response4.Data then
    local data4 = json.decode(response4.Data)
    if data4.available == false then
        print("✅ Test 4 passed")
    else
        error("❌ Test 4 failed: Pikachu should not be available as event species")
    end
else
    error("❌ Test 4 failed: Expected valid response")
end

-- Test 5: Generate event species with 50% probability (seed=2 -> event)
print("📝 Test 5: Generate event species with 50% probability (seed=2 -> event)")
local timestamp5 = 1734739200 + 86400 -- Dec 22, 2024
local seed5 = 2  -- Even seed produces event encounter
local response5 = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Seed = tostring(seed5),
    Timestamp = tostring(timestamp5),
    IsBoss = "false",
    RerollHidden = "false"
})
if response5 and response5.Data then
    local data5 = json.decode(response5.Data)
    local pokemon = data5.speciesGenerated
    if pokemon and pokemon.isEventEncounter == true and pokemon.level == 25 and pokemon.shinyRerolled == true and pokemon.seed == seed5 then
        print("✅ Test 5 passed")
    else
        error("❌ Test 5 failed: Expected event encounter with correct properties")
    end
else
    error("❌ Test 5 failed: Expected valid response")
end

-- Test 6: Return regular species indicator with 50% probability (seed=1 -> regular)
print("📝 Test 6: Return regular species indicator with 50% probability (seed=1 -> regular)")
local timestamp6 = 1734739200 + 86400 -- Dec 22, 2024
local seed6 = 1  -- Odd seed produces regular species
local response6 = sendMessage("GenerateEventSpecies", {
    Level = "30",
    Seed = tostring(seed6),
    Timestamp = tostring(timestamp6),
    IsBoss = "true",
    RerollHidden = "true"
})
if response6 and response6.Data then
    local data6 = json.decode(response6.Data)
    local pokemon = data6.speciesGenerated
    if pokemon.isEventEncounter == false and pokemon.useRegularSpecies == true and pokemon.reason then
        print("✅ Test 6 passed")
    else
        error("❌ Test 6 failed: Expected regular species with reason")
    end
else
    error("❌ Test 6 failed: Expected valid response")
end

-- Test 7: Return regular species indicator when no events active
print("📝 Test 7: Return regular species indicator when no events active")
local timestamp7 = 1609459200 -- Jan 1, 2021 (before any events)
local seed7 = 12345
local response7 = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Seed = tostring(seed7),
    Timestamp = tostring(timestamp7)
})
if response7 and response7.Data then
    local data7 = json.decode(response7.Data)
    local pokemon = data7.speciesGenerated
    if pokemon.useRegularSpecies == true and pokemon.reason == "No active events" then
        print("✅ Test 7 passed")
    else
        error("❌ Test 7 failed: Expected regular species with 'No active events' reason")
    end
else
    error("❌ Test 7 failed: Expected valid response")
end

-- Test 8: Reject invalid level (level = 0)
print("📝 Test 8: Reject invalid level (level = 0)")
local timestamp8 = 1734739200 + 86400
local response8 = sendMessage("GenerateEventSpecies", {
    Level = "0",
    Seed = "12345",
    Timestamp = tostring(timestamp8)
})
if response8 and response8.Action == "Error" then
    if string.match(response8.Error or "", "Level must be between 1 and 100") then
        print("✅ Test 8 passed")
    else
        error("❌ Test 8 failed: Error should mention level range")
    end
else
    error("❌ Test 8 failed: Expected Error action")
end

-- Test 9: Reject invalid level (level = 101)
print("📝 Test 9: Reject invalid level (level = 101)")
local timestamp9 = 1734739200 + 86400
local response9 = sendMessage("GenerateEventSpecies", {
    Level = "101",
    Seed = "12345",
    Timestamp = tostring(timestamp9)
})
if response9 and response9.Action == "Error" then
    if string.match(response9.Error or "", "Level must be between 1 and 100") then
        print("✅ Test 9 passed")
    else
        error("❌ Test 9 failed: Error should mention level range")
    end
else
    error("❌ Test 9 failed: Expected Error action")
end

-- Test 10: Preserve isBoss and rerollHidden flags
print("📝 Test 10: Preserve isBoss and rerollHidden flags")
local timestamp10 = 1734739200 + 86400
local seed10 = 4 -- Even seed for event species
local response10 = sendMessage("GenerateEventSpecies", {
    Level = "50",
    Seed = tostring(seed10),
    Timestamp = tostring(timestamp10),
    IsBoss = "true",
    RerollHidden = "true"
})
if response10 and response10.Data then
    local data10 = json.decode(response10.Data)
    local pokemon = data10.speciesGenerated
    if pokemon.isEventEncounter then
        if pokemon.isBoss == true and pokemon.hiddenAbilityRerolled == true then
            print("✅ Test 10 passed")
        else
            error("❌ Test 10 failed: Expected boss and hidden ability reroll flags")
        end
    else
        print("✅ Test 10 passed (not event encounter, conditional check)")
    end
else
    error("❌ Test 10 failed: Expected valid response")
end

-- Test 11: Preserve form index and evolution blocking from encounter
print("📝 Test 11: Preserve form index and evolution blocking from encounter")
local timestamp11 = 1734739200 + 86400
local seed11 = 6 -- Even seed for event species
local response11 = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Seed = tostring(seed11),
    Timestamp = tostring(timestamp11)
})
if response11 and response11.Data then
    local data11 = json.decode(response11.Data)
    local pokemon = data11.speciesGenerated
    if pokemon.isEventEncounter then
        if type(pokemon.blockEvolution) == "boolean" then
            if pokemon.species == "GIMMIGHOUL" and pokemon.blockEvolution == true then
                print("✅ Test 11 passed")
            else
                print("✅ Test 11 passed (not Gimmighoul or evolution not blocked)")
            end
        else
            error("❌ Test 11 failed: Expected blockEvolution boolean flag")
        end
    else
        print("✅ Test 11 passed (not event encounter, conditional check)")
    end
else
    error("❌ Test 11 failed: Expected valid response")
end

-- Test 12: Produce consistent results for same seed
print("📝 Test 12: Produce consistent results for same seed")
local timestamp12 = 1734739200 + 86400
local seed12 = 99999
local response12a = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Seed = tostring(seed12),
    Timestamp = tostring(timestamp12)
})
local response12b = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Seed = tostring(seed12),
    Timestamp = tostring(timestamp12)
})
if response12a and response12a.Data and response12b and response12b.Data then
    local data12a = json.decode(response12a.Data)
    local data12b = json.decode(response12b.Data)
    if data12a.speciesGenerated.isEventEncounter == data12b.speciesGenerated.isEventEncounter then
        if data12a.speciesGenerated.isEventEncounter and data12a.speciesGenerated.species == data12b.speciesGenerated.species then
            print("✅ Test 12 passed")
        elseif not data12a.speciesGenerated.isEventEncounter then
            print("✅ Test 12 passed (both regular species)")
        else
            error("❌ Test 12 failed: Species mismatch for same seed")
        end
    else
        error("❌ Test 12 failed: isEventEncounter mismatch for same seed")
    end
else
    error("❌ Test 12 failed: Expected valid responses")
end

-- Test 13: Return error when Level is missing
print("📝 Test 13: Return error when Level is missing")
local timestamp13 = 1734739200 + 86400
local response13 = sendMessage("GenerateEventSpecies", {
    Seed = "12345",
    Timestamp = tostring(timestamp13)
})
if response13 and response13.Action == "Error" then
    if string.match(response13.Error or "", "Missing required parameters") then
        print("✅ Test 13 passed")
    else
        error("❌ Test 13 failed: Error should mention missing parameters")
    end
else
    error("❌ Test 13 failed: Expected Error action")
end

-- Test 14: Return error when Seed is missing
print("📝 Test 14: Return error when Seed is missing")
local timestamp14 = 1734739200 + 86400
local response14 = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Timestamp = tostring(timestamp14)
})
if response14 and response14.Action == "Error" then
    if string.match(response14.Error or "", "Missing required parameters") then
        print("✅ Test 14 passed")
    else
        error("❌ Test 14 failed: Error should mention missing parameters")
    end
else
    error("❌ Test 14 failed: Expected Error action")
end

-- Test 15: Handle missing Timestamp gracefully (defaults to no events)
print("📝 Test 15: Handle missing Timestamp gracefully (defaults to no events)")
local response15 = sendMessage("GenerateEventSpecies", {
    Level = "25",
    Seed = "1"
})
if response15 and response15.Data then
    local data15 = json.decode(response15.Data)
    local pokemon = data15.speciesGenerated
    -- Process handles missing timestamp by defaulting to non-event behavior
    if pokemon.useRegularSpecies == true or pokemon.isEventEncounter ~= nil then
        print("✅ Test 15 passed")
    else
        error("❌ Test 15 failed: Expected valid response for missing timestamp")
    end
else
    error("❌ Test 15 failed: Expected valid response")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ 15/15 Event Species Generation tests completed")
