-- ========================================
-- Unlockable Content Engine - Unit Tests
-- Testing unlock condition evaluation, state management, and queries
-- ========================================

-- ========================================
-- TEST SETUP - Mock JSON Module
-- ========================================

-- Mock JSON module BEFORE loading process (process requires json)
-- For testing, keep tables as tables (don't actually serialize)
local json = {
    encode = function(t)
        -- In test environment, just return the table itself
        -- This makes it easier to inspect results
        return t
    end,
    decode = function(s)
        -- In test environment, if it's already a table, return it
        if type(s) == "table" then
            return s
        end
        -- Otherwise return empty table
        return {}
    end
}

-- Make json available globally for process loading
_G.json = json
package.loaded.json = json

-- ========================================
-- TEST SETUP - Mock AO Environment
-- ========================================
local MockAO = {
    messages = {},
    id = "test_unlockable_content_engine"
}

function MockAO.send(message)
    table.insert(MockAO.messages, message)
end

function MockAO.clearMessages()
    MockAO.messages = {}
end

function MockAO.getLastMessage()
    return MockAO.messages[#MockAO.messages]
end

function MockAO.getMessageCount()
    return #MockAO.messages
end

-- Setup AO globals
ao = MockAO

-- Mock Handlers
Handlers = {
    _handlers = {},
    add = function(name, matcher, handler)
        Handlers._handlers[name] = {
            name = name,
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tagName, tagValue)
            return function(msg)
                return msg[tagName] == tagValue
            end
        end
    }
}

-- Helper to invoke handlers
local function invokeHandler(handlerName, msg)
    local handler = Handlers._handlers[handlerName]
    if handler then
        handler.handler(msg)
    else
        error("Handler not found: " .. handlerName)
    end
end

-- Load the process
dofile("processes/unlockable-content-engine.lua")

-- ========================================
-- TEST UTILITIES
-- ========================================
local testsPassed = 0
local testsFailed = 0
local totalTests = 0

local function assert_equals(actual, expected, message)
    totalTests = totalTests + 1
    if actual == expected then
        testsPassed = testsPassed + 1
        print("✓ " .. message)
        return true
    else
        testsFailed = testsFailed + 1
        print("✗ " .. message)
        print("  Expected: " .. tostring(expected))
        print("  Actual: " .. tostring(actual))
        return false
    end
end

local function assert_true(condition, message)
    return assert_equals(condition, true, message)
end

local function assert_false(condition, message)
    return assert_equals(condition, false, message)
end

local function assert_not_nil(value, message)
    totalTests = totalTests + 1
    if value ~= nil then
        testsPassed = testsPassed + 1
        print("✓ " .. message)
        return true
    else
        testsFailed = testsFailed + 1
        print("✗ " .. message)
        print("  Expected: non-nil value")
        print("  Actual: nil")
        return false
    end
end

-- ========================================
-- TEST SUITE 1: ADP v1.0 Info Handler
-- ========================================
print("\n=== Test Suite 1: ADP v1.0 Info Handler ===")

MockAO.clearMessages()
invokeHandler("info", {
    Action = "Info",
    From = "test_client",
    Timestamp = 1234567890
})

local infoMsg = MockAO.getLastMessage()
assert_not_nil(infoMsg, "Info handler should send response")
assert_equals(infoMsg.Action, "SaveState", "Info response should have SaveState action")

-- In test environment, Data is already a table (json.encode returns table)
local infoData = infoMsg.Data
assert_equals(infoData.name, "Unlockable Content Engine", "Info should include process name")
assert_equals(infoData.version, "1.0.0", "Info should include version")
assert_equals(infoData.adpVersion, "1.0", "Info should include ADP version")
assert_not_nil(infoData.capabilities, "Info should include capabilities")
assert_not_nil(infoData.handlers, "Info should include handler descriptions")
assert_not_nil(infoData.unlockables, "Info should include unlockables list")

-- ========================================
-- TEST SUITE 2: IsUnlocked Handler
-- ========================================
print("\n=== Test Suite 2: IsUnlocked Handler ===")

-- Test: Check unlock status for new player (should be false)
MockAO.clearMessages()
invokeHandler("is-unlocked", {
    Action = "IsUnlocked",
    From = "test_client",
    PlayerId = "player_001",
    UnlockableId = "0",  -- ENDLESS_MODE
    Timestamp = 1234567890
})

local unlockStatus = MockAO.getLastMessage()
assert_equals(unlockStatus.Action, "UnlockStatus", "Should return UnlockStatus action")
assert_equals(unlockStatus.IsUnlocked, "false", "New player should not have unlocks")
assert_equals(unlockStatus.UnlockableName, "Endless Mode", "Should return correct unlock name")

-- Test: Missing PlayerId
MockAO.clearMessages()
invokeHandler("is-unlocked", {
    Action = "IsUnlocked",
    From = "test_client",
    UnlockableId = "0",
    Timestamp = 1234567890
})

local errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Missing PlayerId should return error")
assert_true(errorMsg.Error:find("PlayerId required") ~= nil, "Error should mention PlayerId")

-- Test: Missing UnlockableId
MockAO.clearMessages()
invokeHandler("is-unlocked", {
    Action = "IsUnlocked",
    From = "test_client",
    PlayerId = "player_001",
    Timestamp = 1234567890
})

errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Missing UnlockableId should return error")
assert_true(errorMsg.Error:find("UnlockableId required") ~= nil, "Error should mention UnlockableId")

-- Test: Invalid UnlockableId
MockAO.clearMessages()
invokeHandler("is-unlocked", {
    Action = "IsUnlocked",
    From = "test_client",
    PlayerId = "player_001",
    UnlockableId = "99",
    Timestamp = 1234567890
})

errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Invalid UnlockableId should return error")
assert_true(errorMsg.Error:find("Invalid unlockable ID") ~= nil, "Error should mention invalid ID")

-- ========================================
-- TEST SUITE 3: EvaluateUnlocks Handler
-- ========================================
print("\n=== Test Suite 3: EvaluateUnlocks Handler ===")

-- Test: Basic Classic victory (unlocks ENDLESS_MODE and MINI_BLACK_HOLE)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_002",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({  -- json.encode returns table in test env
        hasFusion = false,
        hasUnevolved = false,
        partySize = 6
    }),
    Timestamp = 1234567890
})

local evalResult = MockAO.getLastMessage()
assert_equals(evalResult.Action, "UnlockEvaluationResult", "Should return UnlockEvaluationResult action")

-- Data is already a table in test environment
local evalData = evalResult.Data
assert_equals(#evalData.newUnlocks, 2, "Basic Classic victory should unlock 2 items")
assert_equals(evalData.totalUnlocked, 2, "Total unlocked should be 2")
assert_equals(evalData.allUnlocked, false, "Should not have all unlocked")

-- Verify unlock names
local unlockNames = {}
for _, unlock in ipairs(evalData.newUnlocks) do
    unlockNames[unlock.name] = true
end
assert_true(unlockNames["Endless Mode"], "Should unlock Endless Mode")
assert_true(unlockNames["Mini Black Hole"], "Should unlock Mini Black Hole")

-- Test: Classic victory with fusion (adds SPLICED_ENDLESS_MODE)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_003",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({
        hasFusion = true,
        hasUnevolved = false,
        partySize = 6
    }),
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 3, "Classic victory with fusion should unlock 3 items")

unlockNames = {}
for _, unlock in ipairs(evalData.newUnlocks) do
    unlockNames[unlock.name] = true
end
assert_true(unlockNames["Spliced Endless Mode"], "Should unlock Spliced Endless Mode with fusion")

-- Test: Classic victory with unevolved (adds EVIOLITE)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_004",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({
        hasFusion = false,
        hasUnevolved = true,
        partySize = 6
    }),
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 3, "Classic victory with unevolved should unlock 3 items")

unlockNames = {}
for _, unlock in ipairs(evalData.newUnlocks) do
    unlockNames[unlock.name] = true
end
assert_true(unlockNames["Eviolite"], "Should unlock Eviolite with unevolved Pokemon")

-- Test: Classic victory with both fusion and unevolved (all 4 unlocks)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_005",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({
        hasFusion = true,
        hasUnevolved = true,
        partySize = 6
    }),
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 4, "Classic victory with both should unlock all 4 items")
assert_equals(evalData.totalUnlocked, 4, "Total unlocked should be 4")
assert_equals(evalData.allUnlocked, true, "Should have all unlocked")

-- Test: Endless mode victory (no unlocks)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_006",
    GameMode = "endless",
    IsVictory = "true",
    PartyData = json.encode({
        hasFusion = true,
        hasUnevolved = true
    }),
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 0, "Endless mode victory should not unlock content")

-- Test: Classic defeat (no unlocks)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_007",
    GameMode = "classic",
    IsVictory = "false",
    PartyData = json.encode({
        hasFusion = true,
        hasUnevolved = true
    }),
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 0, "Classic defeat should not unlock content")

-- Test: Missing required parameters
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    Timestamp = 1234567890
})

errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Missing parameters should return error")

-- ========================================
-- TEST SUITE 4: GrantUnlock Handler
-- ========================================
print("\n=== Test Suite 4: GrantUnlock Handler ===")

-- Test: Grant unlock to new player
MockAO.clearMessages()
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_008",
    UnlockableId = "0",
    ForceUnlock = "false",
    Timestamp = 1234567890
})

local grantMsg = MockAO.getLastMessage()
assert_equals(grantMsg.Action, "UnlockGranted", "Should return UnlockGranted action")
assert_equals(grantMsg.Success, "true", "Grant should be successful")
assert_equals(grantMsg.AlreadyUnlocked, "false", "Should not be already unlocked")
assert_equals(grantMsg.UnlockableName, "Endless Mode", "Should return unlock name")

-- Test: Verify unlock persists (check with IsUnlocked)
MockAO.clearMessages()
invokeHandler("is-unlocked", {
    Action = "IsUnlocked",
    From = "test_client",
    PlayerId = "player_008",
    UnlockableId = "0",
    Timestamp = 1234567890
})

unlockStatus = MockAO.getLastMessage()
assert_equals(unlockStatus.IsUnlocked, "true", "Unlock should persist after grant")

-- Test: Idempotent grant (grant same unlock again)
MockAO.clearMessages()
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_008",
    UnlockableId = "0",
    ForceUnlock = "false",
    Timestamp = 1234567891
})

grantMsg = MockAO.getLastMessage()
assert_equals(grantMsg.AlreadyUnlocked, "true", "Should detect already unlocked")
assert_equals(grantMsg.Success, "true", "Idempotent grant should still succeed")

-- Test: Force unlock
MockAO.clearMessages()
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_009",
    UnlockableId = "3",
    ForceUnlock = "true",
    Timestamp = 1234567890
})

grantMsg = MockAO.getLastMessage()
assert_equals(grantMsg.Forced, "true", "Should indicate forced unlock")
assert_equals(grantMsg.Success, "true", "Force unlock should succeed")

-- Test: Invalid unlock ID
MockAO.clearMessages()
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_010",
    UnlockableId = "99",
    Timestamp = 1234567890
})

errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Invalid unlock ID should return error")

-- ========================================
-- TEST SUITE 5: GetPlayerUnlocks Handler
-- ========================================
print("\n=== Test Suite 5: GetPlayerUnlocks Handler ===")

-- Test: Get unlocks for player with some unlocks
MockAO.clearMessages()
invokeHandler("get-player-unlocks", {
    Action = "GetPlayerUnlocks",
    From = "test_client",
    PlayerId = "player_008",  -- Has ENDLESS_MODE unlocked from earlier test
    Timestamp = 1234567890
})

local playerData = MockAO.getLastMessage()
assert_equals(playerData.Action, "PlayerUnlockData", "Should return PlayerUnlockData action")

local unlockData = json.decode(playerData.Data)
assert_equals(unlockData.unlockedCount, 1, "Should have 1 unlock")
assert_equals(unlockData.totalUnlockables, 4, "Should report 4 total unlockables")
assert_equals(unlockData.completionPercentage, 25, "Should have 25% completion")
assert_true(unlockData.unlocks[0], "Should have ENDLESS_MODE unlocked")

-- Test: Get unlocks for new player (no unlocks)
MockAO.clearMessages()
invokeHandler("get-player-unlocks", {
    Action = "GetPlayerUnlocks",
    From = "test_client",
    PlayerId = "player_new",
    Timestamp = 1234567890
})

playerData = MockAO.getLastMessage()
unlockData = json.decode(playerData.Data)
assert_equals(unlockData.unlockedCount, 0, "New player should have 0 unlocks")
assert_equals(unlockData.completionPercentage, 0, "New player should have 0% completion")

-- Test: Missing PlayerId
MockAO.clearMessages()
invokeHandler("get-player-unlocks", {
    Action = "GetPlayerUnlocks",
    From = "test_client",
    Timestamp = 1234567890
})

errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Missing PlayerId should return error")

-- ========================================
-- TEST SUITE 6: GetUnlockMetadata Handler
-- ========================================
print("\n=== Test Suite 6: GetUnlockMetadata Handler ===")

-- Test: Get all metadata
MockAO.clearMessages()
invokeHandler("get-unlock-metadata", {
    Action = "GetUnlockMetadata",
    From = "test_client",
    Timestamp = 1234567890
})

local metadataMsg = MockAO.getLastMessage()
assert_equals(metadataMsg.Action, "UnlockMetadata", "Should return UnlockMetadata action")

local metadataData = json.decode(metadataMsg.Data)
assert_equals(metadataData.totalUnlockables, 4, "Should report 4 unlockables")
assert_equals(#metadataData.unlockables, 4, "Should return 4 metadata entries")

-- Verify metadata structure
local firstMeta = metadataData.unlockables[1]
assert_not_nil(firstMeta.id, "Metadata should include id")
assert_not_nil(firstMeta.name, "Metadata should include name")
assert_not_nil(firstMeta.description, "Metadata should include description")
assert_not_nil(firstMeta.condition, "Metadata should include condition")

-- Test: Get specific metadata
MockAO.clearMessages()
invokeHandler("get-unlock-metadata", {
    Action = "GetUnlockMetadata",
    From = "test_client",
    UnlockableId = "2",  -- SPLICED_ENDLESS_MODE
    Timestamp = 1234567890
})

metadataMsg = MockAO.getLastMessage()
metadataData = json.decode(metadataMsg.Data)
assert_equals(#metadataData.unlockables, 1, "Should return single metadata entry")

local splicedMeta = metadataData.unlockables[1]
assert_equals(splicedMeta.name, "Spliced Endless Mode", "Should return correct metadata")
assert_equals(splicedMeta.requiresFusion, true, "Should indicate fusion requirement")

-- Test: Invalid unlock ID
MockAO.clearMessages()
invokeHandler("get-unlock-metadata", {
    Action = "GetUnlockMetadata",
    From = "test_client",
    UnlockableId = "99",
    Timestamp = 1234567890
})

errorMsg = MockAO.getLastMessage()
assert_equals(errorMsg.Action, "Error", "Invalid unlock ID should return error")

-- ========================================
-- TEST SUITE 7: State Persistence
-- ========================================
print("\n=== Test Suite 7: State Persistence ===")

-- Grant multiple unlocks and verify persistence
MockAO.clearMessages()

-- Grant ENDLESS_MODE
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_persist",
    UnlockableId = "0",
    Timestamp = 1234567890
})

-- Grant MINI_BLACK_HOLE
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_persist",
    UnlockableId = "1",
    Timestamp = 1234567891
})

-- Grant EVIOLITE
invokeHandler("grant-unlock", {
    Action = "GrantUnlock",
    From = "test_client",
    PlayerId = "player_persist",
    UnlockableId = "3",
    Timestamp = 1234567892
})

-- Verify all unlocks persist
MockAO.clearMessages()
invokeHandler("get-player-unlocks", {
    Action = "GetPlayerUnlocks",
    From = "test_client",
    PlayerId = "player_persist",
    Timestamp = 1234567893
})

playerData = MockAO.getLastMessage()
unlockData = json.decode(playerData.Data)
assert_equals(unlockData.unlockedCount, 3, "Should have 3 unlocks persisted")
assert_true(unlockData.unlocks[0], "ENDLESS_MODE should be unlocked")
assert_true(unlockData.unlocks[1], "MINI_BLACK_HOLE should be unlocked")
assert_false(unlockData.unlocks[2], "SPLICED_ENDLESS_MODE should not be unlocked")
assert_true(unlockData.unlocks[3], "EVIOLITE should be unlocked")

-- Verify timestamps are tracked
assert_not_nil(unlockData.timestamps[0], "Should track timestamp for ENDLESS_MODE")
assert_not_nil(unlockData.timestamps[1], "Should track timestamp for MINI_BLACK_HOLE")
assert_not_nil(unlockData.timestamps[3], "Should track timestamp for EVIOLITE")

-- ========================================
-- TEST SUITE 8: Edge Cases
-- ========================================
print("\n=== Test Suite 8: Edge Cases ===")

-- Test: Empty party data
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_edge",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = "{}",
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 2, "Empty party data should unlock basic unlocks only")

-- Test: Nil party data (should default)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_edge2",
    GameMode = "classic",
    IsVictory = "true",
    Timestamp = 1234567890
})

evalResult = MockAO.getLastMessage()
evalData = json.decode(evalResult.Data)
assert_equals(#evalData.newUnlocks, 2, "Nil party data should unlock basic unlocks only")

-- Test: Already unlocked content doesn't duplicate
MockAO.clearMessages()

-- First evaluation
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_dup",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({hasFusion = true, hasUnevolved = false}),
    Timestamp = 1234567890
})

local firstEval = MockAO.getLastMessage()
local firstData = json.decode(firstEval.Data)
local firstCount = #firstData.newUnlocks

-- Second evaluation (should find no new unlocks)
MockAO.clearMessages()
invokeHandler("evaluate-unlocks", {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_dup",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = json.encode({hasFusion = true, hasUnevolved = false}),
    Timestamp = 1234567891
})

local secondEval = MockAO.getLastMessage()
local secondData = json.decode(secondEval.Data)
assert_equals(#secondData.newUnlocks, 0, "Already unlocked content should not duplicate")
assert_equals(secondData.totalUnlocked, firstCount, "Total unlocked should remain same")

-- ========================================
-- TEST RESULTS SUMMARY
-- ========================================
print("\n=== Test Results Summary ===")
print("Total Tests: " .. totalTests)
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed == 0 then
    print("\n✓ All tests passed!")
else
    print("\n✗ Some tests failed")
    os.exit(1)
end