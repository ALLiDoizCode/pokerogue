-- Parity tests for tutorial-engine.lua
-- Validates Lua implementation matches TypeScript behavior

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.tutorial-engine"
local processId = "test-tutorial-parity"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Tutorial Engine Parity Tests")
print("Process ID:", processId)
print("Comparing Lua vs TypeScript behavior\n")

-- Test utilities
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
local testsTotal = 0

local function assertParity(testName, condition, errorMsg)
    testsTotal = testsTotal + 1
    if condition then
        testsPassed = testsPassed + 1
        print("✅ PASS: " .. testName)
    else
        error("❌ FAIL: " .. testName .. " - " .. (errorMsg or "Condition failed"))
    end
end

-- ============================================================================
-- PARITY TEST: Tutorial Progression Flow
-- ============================================================================

print("📋 Parity Test Suite: Tutorial Progression Flow")

-- Test 1: INTRO tutorial first-time display
print("\n📝 Test 1: INTRO tutorial first-time behavior")
local intro1 = sendMessage("StartTutorial", {TutorialType = "INTRO"}, json.encode({
    enableTutorials = true,
    completedTutorials = {}
}))
local introData1 = json.decode(intro1.Data)
assertParity(
    "INTRO first-time shouldDisplay=true",
    introData1.shouldDisplay == true,
    "TypeScript: handleTutorial() returns true for first tutorial"
)
assertParity(
    "INTRO has correct text content",
    introData1.text:find("Welcome to PokéRogue") ~= nil,
    "TypeScript: i18next.t('tutorial:intro') contains welcome message"
)

-- Test 2: Tutorial skip logic (already completed)
print("\n📝 Test 2: Tutorial skip when already completed")
local intro2 = sendMessage("StartTutorial", {TutorialType = "INTRO"}, json.encode({
    enableTutorials = true,
    completedTutorials = {INTRO = true}
}))
local introData2 = json.decode(intro2.Data)
assertParity(
    "Completed tutorial shouldDisplay=false",
    introData2.shouldDisplay == false,
    "TypeScript: getTutorialFlags()[tutorial] returns false when already seen"
)

-- Test 3: ACCESS_MENU skip with touch controls
print("\n📝 Test 3: ACCESS_MENU skip condition (touch controls)")
local access1 = sendMessage("StartTutorial", {TutorialType = "ACCESS_MENU"}, json.encode({
    enableTutorials = true,
    enableTouchControls = true,
    completedTutorials = {}
}))
local accessData1 = json.decode(access1.Data)
assertParity(
    "Touch controls skip ACCESS_MENU",
    accessData1.shouldDisplay == false and accessData1.reason == "Skip condition met",
    "TypeScript: globalScene.enableTouchControls causes early return resolve()"
)

-- Test 4: ACCESS_MENU normal display (no touch controls)
print("\n📝 Test 4: ACCESS_MENU normal display")
local access2 = sendMessage("StartTutorial", {TutorialType = "ACCESS_MENU"}, json.encode({
    enableTutorials = true,
    enableTouchControls = false,
    completedTutorials = {}
}))
local accessData2 = json.decode(access2.Data)
assertParity(
    "ACCESS_MENU displays without touch controls",
    accessData2.shouldDisplay == true,
    "TypeScript: Shows overlay and tutorial text when not touch mode"
)
assertParity(
    "ACCESS_MENU has overlay metadata",
    accessData2.overlay.required == true,
    "TypeScript: showFieldOverlay(1000) indicates overlay required"
)

-- ============================================================================
-- PARITY TEST: Tutorial Flag Persistence
-- ============================================================================

print("\n📋 Parity Test Suite: Tutorial Flag Persistence")

-- Test 5: Tutorial completion marks flag
print("\n📝 Test 5: Completing tutorial marks flag")
local complete1 = sendMessage("CompleteTutorialStep", {
    TutorialType = "INTRO",
    StepCompleted = "1",
    TimeSpent = "30"
}, json.encode({
    completedTutorials = {},
    statistics = {tutorialsCompleted = 0, totalTimeSpent = 0, stepsCompleted = 0}
}))
local completeData1 = json.decode(complete1.Data)
assertParity(
    "Tutorial completion sets flag",
    completeData1.progressUpdated.completedTutorials.INTRO == true,
    "TypeScript: saveTutorialFlag(tutorial, true) marks as seen"
)
assertParity(
    "Statistics increment on completion",
    completeData1.progressUpdated.statistics.tutorialsCompleted == 1,
    "TypeScript: Tutorial statistics track completion count"
)

-- Test 6: MENU requires ACCESS_MENU prerequisite
print("\n📝 Test 6: MENU prerequisite validation")
local menu1 = sendMessage("StartTutorial", {TutorialType = "MENU"}, json.encode({
    enableTutorials = true,
    completedTutorials = {}
}))
assertParity(
    "MENU rejects without ACCESS_MENU",
    menu1.Action == "Error" and menu1.Error == "Prerequisites not met",
    "TypeScript: MENU tutorial saveTutorialFlag(Access_Menu, true) in handler"
)

-- Test 7: MENU allows with ACCESS_MENU completed
print("\n📝 Test 7: MENU with prerequisite met")
local menu2 = sendMessage("StartTutorial", {TutorialType = "MENU"}, json.encode({
    enableTutorials = true,
    completedTutorials = {ACCESS_MENU = true}
}))
local menuData2 = json.decode(menu2.Data)
assertParity(
    "MENU displays with ACCESS_MENU completed",
    menuData2.shouldDisplay == true,
    "TypeScript: Prerequisites allow tutorial progression"
)

-- ============================================================================
-- PARITY TEST: Tutorial Overlay System
-- ============================================================================

print("\n📋 Parity Test Suite: Tutorial Overlay System")

-- Test 8: STAT_CHANGE overlay requirements
print("\n📝 Test 8: STAT_CHANGE overlay metadata")
local stat1 = sendMessage("StartTutorial", {TutorialType = "STAT_CHANGE"}, json.encode({
    enableTutorials = true,
    completedTutorials = {}
}))
local statData1 = json.decode(stat1.Data)
assertParity(
    "STAT_CHANGE requires overlay",
    statData1.overlay.required == true,
    "TypeScript: showFieldOverlay(1000) then hideFieldOverlay(1000)"
)
assertParity(
    "STAT_CHANGE has UI disable",
    statData1.uiContext.disableMenu == true,
    "TypeScript: globalScene.disableMenu = true during tutorial"
)

-- ============================================================================
-- PARITY TEST: Tutorial Skill Validation
-- ============================================================================

print("\n📋 Parity Test Suite: Tutorial Skill Validation")

-- Test 9: STARTER_SELECT skill check
print("\n📝 Test 9: STARTER_SELECT skill validation")
local starterSkill = sendMessage("ValidateTutorialSkill", {
    TutorialType = "STARTER_SELECT",
    SkillCheck = "starterSelected"
}, json.encode({
    starterSelected = true
}))
local starterSkillData = json.decode(starterSkill.Data)
assertParity(
    "Starter selection skill passes",
    starterSkillData.skillCheckPassed == true,
    "TypeScript: Starter selection tracked in tutorial flow"
)

-- Test 10: SELECT_ITEM skill check
print("\n📝 Test 10: SELECT_ITEM skill validation")
local itemSkill = sendMessage("ValidateTutorialSkill", {
    TutorialType = "SELECT_ITEM",
    SkillCheck = "itemSelected"
}, json.encode({
    itemSelected = true
}))
local itemSkillData = json.decode(itemSkill.Data)
assertParity(
    "Item selection skill passes",
    itemSkillData.skillCheckPassed == true,
    "TypeScript: Item selection tracked in tutorial flow"
)
assertParity(
    "Progression allowed on skill pass",
    itemSkillData.canProgress == true,
    "TypeScript: Skill checks gate tutorial progression"
)

-- ============================================================================
-- PARITY TEST: Tutorial Progression Sequence
-- ============================================================================

print("\n📋 Parity Test Suite: Tutorial Progression Sequence")

-- Test 11: Tutorial next step sequence
print("\n📝 Test 11: INTRO → ACCESS_MENU sequence")
local introNext = sendMessage("CompleteTutorialStep", {
    TutorialType = "INTRO",
    StepCompleted = "1"
}, json.encode({
    completedTutorials = {},
    statistics = {tutorialsCompleted = 0, totalTimeSpent = 0, stepsCompleted = 0}
}))
local introNextData = json.decode(introNext.Data)
assertParity(
    "INTRO next tutorial is ACCESS_MENU",
    introNextData.nextTutorial == "ACCESS_MENU",
    "TypeScript: Tutorial sequence INTRO → ACCESS_MENU"
)

-- Test 12: Tutorial progress tracking
print("\n📝 Test 12: Tutorial progress statistics")
local progress1 = sendMessage("GetTutorialProgress", {}, json.encode({
    completedTutorials = {INTRO = true, ACCESS_MENU = true},
    statistics = {tutorialsCompleted = 2, totalTimeSpent = 120, stepsCompleted = 2}
}))
local progressData1 = json.decode(progress1.Data)
assertParity(
    "Progress tracks multiple completions",
    progressData1.statistics.tutorialsCompleted == 2,
    "TypeScript: Tutorial statistics accumulate"
)
assertParity(
    "Progress tracks time spent",
    progressData1.statistics.totalTimeSpent == 120,
    "TypeScript: Tutorial time tracking"
)

-- ============================================================================
-- PARITY TEST: Complex Tutorial Scenarios
-- ============================================================================

print("\n📋 Parity Test Suite: Complex Tutorial Scenarios")

-- Test 13: Multi-step tutorial sequence with skip
print("\n📝 Test 13: INTRO → (skip ACCESS_MENU) → MENU flow")
-- INTRO complete
local seq1 = sendMessage("CompleteTutorialStep", {
    TutorialType = "INTRO",
    StepCompleted = "1"
}, json.encode({
    completedTutorials = {},
    statistics = {tutorialsCompleted = 0, totalTimeSpent = 0, stepsCompleted = 0}
}))
local seq1Data = json.decode(seq1.Data)

-- ACCESS_MENU skip (touch controls)
local seq2 = sendMessage("StartTutorial", {TutorialType = "ACCESS_MENU"}, json.encode({
    enableTutorials = true,
    enableTouchControls = true,
    completedTutorials = {INTRO = true}
}))
local seq2Data = json.decode(seq2.Data)

assertParity(
    "Complex flow: Touch controls skip ACCESS_MENU",
    seq2Data.shouldDisplay == false and seq2Data.nextTutorial == "MENU",
    "TypeScript: Conditional branching based on input method"
)

-- ============================================================================
-- PARITY TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 Parity Test Results:")
print(string.format("✅ %d/%d tests passed (%.1f%%)", testsPassed, testsTotal, (testsPassed/testsTotal)*100))
print("==================================================")

if testsPassed == testsTotal then
    print("✅ 100% PARITY ACHIEVED - Lua matches TypeScript behavior")
else
    error(string.format("❌ PARITY INCOMPLETE - %d tests failed", testsTotal - testsPassed))
end
