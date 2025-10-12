-- Collection Tracker Unit Tests (CORRECT API)
-- Tests all core collection operations, achievement system, and analytics

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.collection-tracker"
local processId = "test-collection-tracker"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Collection Tracker")
print("Process ID:", processId)

local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
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

local testsPassed = 0
local testsFailed = 0
local testPlayerId = "test_player_123"

-- Test 1: Collection State Creation
print("📝 Test 1: Collection State Creation")
local captureResult = sendMessage("RecordCapture", {
    PlayerId = testPlayerId,
    PokemonId = "pokemon_1",
    SpeciesId = "1",
    Level = "5",
    Location = "Route 1",
    Method = "pokeball",
    Attempts = "1",
    Critical = "false"
})
if captureResult and captureResult.Action == "SaveState" then
    local captureData = json.decode(captureResult.Data or "{}")
    if captureData.success == true and captureData.wasNewSpecies == true then
        print("✅ Test passed: Collection state created successfully")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Collection state creation incorrect")
    end
else
    error("❌ Test failed: RecordCapture handler failed")
end

-- Test 2: Pokedex Progress Tracking
print("📝 Test 2: Pokedex Progress Tracking")
-- Capture multiple species
for i = 2, 5 do
    sendMessage("RecordCapture", {
        PlayerId = testPlayerId,
        PokemonId = "pokemon_" .. i,
        SpeciesId = tostring(i),
        Level = "5",
        Location = "Route 1"
    })
end

local completion = sendMessage("CalculateCompletion", {
    PlayerId = testPlayerId,
    Scope = "all"
})
if completion and completion.Action == "SaveState" then
    local compData = json.decode(completion.Data or "{}")
    if compData.completion and compData.completion.caught == 5 then
        print("✅ Test passed: Pokedex progress tracking works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Progress tracking incorrect")
    end
else
    error("❌ Test failed: CalculateCompletion handler failed")
end

-- Test 3: Achievement System
print("📝 Test 3: Achievement System")
local achievement = sendMessage("CheckAchievements", {
    PlayerId = testPlayerId,
    TriggerType = "capture",
    SpeciesId = "1"
})
if achievement and achievement.Action == "SaveState" then
    local achData = json.decode(achievement.Data or "{}")
    if achData.newAchievements and #achData.newAchievements >= 1 then
        print("✅ Test passed: Achievement system works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Achievement not unlocked")
    end
else
    error("❌ Test failed: CheckAchievements handler failed")
end

-- Test 4: Statistics Generation
print("📝 Test 4: Statistics Generation")
local stats = sendMessage("GenerateStatistics", {
    PlayerId = testPlayerId,
    Period = "all_time",
    Categories = json.encode({"capture", "progress"})
})
if stats and stats.Action == "SaveState" then
    local statsData = json.decode(stats.Data or "{}")
    if statsData.statistics and statsData.statistics.capture then
        print("✅ Test passed: Statistics generation works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Statistics generation incomplete")
    end
else
    error("❌ Test failed: GenerateStatistics handler failed")
end

-- Test 5: Encounter Tracking
print("📝 Test 5: Encounter Tracking")
local encounter = sendMessage("RecordEncounter", {
    PlayerId = testPlayerId,
    SpeciesId = "25",
    Location = "Route 2",
    Level = "3"
})
if encounter and encounter.Action == "SaveState" then
    local encounterData = json.decode(encounter.Data or "{}")
    if encounterData.wasNewSighting == true then
        print("✅ Test passed: Encounter tracking works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Encounter tracking incorrect")
    end
else
    error("❌ Test failed: RecordEncounter handler failed")
end

-- Test 6: Collection Export
print("📝 Test 6: Collection Export")
local export = sendMessage("ExportCollection", {
    PlayerId = testPlayerId,
    Format = "json"
})
if export and export.Action == "SaveState" then
    local exportData = json.decode(export.Data or "{}")
    if exportData.format == "json" and exportData.exportData then
        print("✅ Test passed: Collection export works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Collection export incomplete")
    end
else
    error("❌ Test failed: ExportCollection handler failed")
end

-- Test 7: Input Validation
print("📝 Test 7: Input Validation")
local invalidCapture = sendMessage("RecordCapture", {
    PlayerId = testPlayerId,
    PokemonId = "pokemon_999",
    SpeciesId = "9999"
})
if invalidCapture and invalidCapture.Action == "Error" then
    print("✅ Test passed: Input validation works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Input validation not working")
end

print("==================================================")
print("Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. (testsPassed + testsFailed))

if testsFailed == 0 then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n❌ Some tests failed!")
end
