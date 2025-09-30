-- Achievement Engine Unit Tests
-- Comprehensive test suite for achievement-engine.lua
-- Uses AO message-based testing pattern compatible with AO runtime

print("\n=== Achievement Engine Unit Tests ===\n")

-- Mock AO environment
local ao = {
    send = function(msg)
        table.insert(_G.testResults or {}, msg)
    end,
    id = "achievement_engine_unit_test"
}

-- Mock Handlers
local Handlers = {
    add = function(name, matcher, handler)
        _G.testHandlers = _G.testHandlers or {}
        _G.testHandlers[name] = {matcher = matcher, handler = handler}
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON with proper array handling
local json = {
    encode = function(data)
        if type(data) == "table" then
            return "{}"
        end
        return tostring(data)
    end,
    decode = function(str)
        -- Return proper array structure for Args parameter
        if str and str ~= "" then
            return {15000}  -- Mock money value for tests
        end
        return {}
    end
}

-- Set globals
_G.ao = ao
_G.Handlers = Handlers
_G.testResults = {}
_G.testHandlers = {}

-- Pre-load JSON module into package.loaded to prevent require() call
package.loaded["json"] = json
_G.json = json

-- Load process
local file = io.open("processes/achievement-engine.lua", "r")
if not file then
    print("✗ Could not find achievement-engine.lua")
    os.exit(1)
end

local content = file:read("*all")
file:close()

local processFunction = load(content)
if not processFunction then
    print("✗ Failed to load achievement engine process")
    os.exit(1)
end

processFunction()
print("✓ Achievement engine process loaded")

-- Test counter
local passed = 0
local failed = 0

local function test(name, condition)
    if condition then
        print("✓ " .. name)
        passed = passed + 1
    else
        print("✗ " .. name)
        failed = failed + 1
    end
end

-- Execute handler helper
local function exec(name, msg)
    _G.testResults = {}
    local h = _G.testHandlers[name]
    if h and h.handler then
        h.handler(msg)
        return _G.testResults[#_G.testResults]
    end
    return nil
end

print("\nTest Group: Handler Registration")
test("Info handler registered", _G.testHandlers["info"] ~= nil)
test("ValidateAchievement handler registered", _G.testHandlers["validate-achievement"] ~= nil)
test("ValidateAchievementsByType handler registered", _G.testHandlers["validate-achievements-by-type"] ~= nil)
test("GetPlayerAchievements handler registered", _G.testHandlers["get-player-achievements"] ~= nil)
test("GetAchievementMetadata handler registered", _G.testHandlers["get-achievement-metadata"] ~= nil)
test("GetAchievementProgress handler registered", _G.testHandlers["get-achievement-progress"] ~= nil)

print("\nTest Group: Info Handler (ADP v1.0)")
local info = exec("info", {Action = "Info", From = "test", Timestamp = "0"})
test("Info handler responds", info ~= nil)
test("Info action is SaveState", info and info.Action == "SaveState")
test("Info includes data", info and info.Data ~= nil)

print("\nTest Group: Validate Achievement")
local validate = exec("validate-achievement", {
    Action = "ValidateAchievement",
    PlayerId = "player1",
    AchievementId = "_10K_MONEY",
    Args = json.encode({15000}),
    From = "test",
    Timestamp = "1000"
})
test("ValidateAchievement responds", validate ~= nil)
test("ValidateAchievement action correct", validate and validate.Action == "AchievementValidated")
test("Achievement unlocked", validate and validate.Success == "true")

print("\nTest Group: Error Handling")
local noPlayer = exec("validate-achievement", {
    Action = "ValidateAchievement",
    AchievementId = "_10K_MONEY",
    From = "test",
    Timestamp = "1001"
})
test("Missing PlayerId returns error", noPlayer and noPlayer.Action == "Error")

local noAchv = exec("validate-achievement", {
    Action = "ValidateAchievement",
    PlayerId = "player2",
    From = "test",
    Timestamp = "1002"
})
test("Missing AchievementId returns error", noAchv and noAchv.Action == "Error")

local invalidAchv = exec("validate-achievement", {
    Action = "ValidateAchievement",
    PlayerId = "player3",
    AchievementId = "INVALID_ACHIEVEMENT",
    Args = json.encode({}),
    From = "test",
    Timestamp = "1003"
})
test("Invalid achievement returns error", invalidAchv and invalidAchv.Action == "Error")

print("\nTest Group: Batch Validation")
local batch = exec("validate-achievements-by-type", {
    Action = "ValidateAchievementsByType",
    PlayerId = "player4",
    AchievementType = "DamageAchv",
    Args = json.encode({3000}),
    From = "test",
    Timestamp = "1004"
})
test("Batch validation responds", batch ~= nil)
test("Batch action correct", batch and batch.Action == "AchievementsBatchValidated")

print("\nTest Group: Player Achievement Query")
local player = exec("get-player-achievements", {
    Action = "GetPlayerAchievements",
    PlayerId = "player1",
    IncludeSecrets = "false",
    From = "test",
    Timestamp = "1005"
})
test("Get player achievements responds", player ~= nil)
test("Player data action correct", player and player.Action == "PlayerAchievementData")

print("\nTest Group: Metadata Query")
local metadata = exec("get-achievement-metadata", {
    Action = "GetAchievementMetadata",
    From = "test",
    Timestamp = "1006"
})
test("Get metadata responds", metadata ~= nil)
test("Metadata action correct", metadata and metadata.Action == "AchievementMetadata")

print("\nTest Group: Progress Tracking")
local progress = exec("get-achievement-progress", {
    Action = "GetAchievementProgress",
    PlayerId = "player5",
    AchievementId = "_100_RIBBONS",
    CurrentValue = "75",
    From = "test",
    Timestamp = "1007"
})
test("Get progress responds", progress ~= nil)
test("Progress action correct", progress and progress.Action == "AchievementProgress")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
print(string.format("Total: %d", passed + failed))

if failed == 0 then
    print("\n✓ All tests passed!")
    os.exit(0)
else
    print(string.format("\n✗ %d test(s) failed", failed))
    os.exit(1)
end