-- Unit Tests: Challenge Validation and Unlock Conditions
-- Tests isUnlocked logic, condition functions, and unlock status validation
-- Target: 10 tests

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
_G.ao = {
    id = "test-challenge-engine",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers
_G.Handlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                if type(value) == "table" then
                    for _, v in ipairs(value) do
                        if msg[tag] == v then
                            return true
                        end
                    end
                    return false
                else
                    return msg[tag] == value
                end
            end
        end
    }
}

-- Mock JSON
_G.json = {
    encode = function(t)
        if type(t) ~= "table" then
            return '"' .. tostring(t) .. '"'
        end

        local result = "{"
        local first = true
        for k, v in pairs(t) do
            if not first then result = result .. "," end
            first = false

            result = result .. '"' .. tostring(k) .. '":'
            if type(v) == "table" then
                result = result .. _G.json.encode(v)
            elseif type(v) == "string" then
                result = result .. '"' .. v .. '"'
            elseif type(v) == "boolean" then
                result = result .. (v and "true" or "false")
            else
                result = result .. tostring(v)
            end
        end
        result = result .. "}"
        return result
    end,

    decode = function(s)
        if type(s) ~= "string" then return s end
        if s == "" or s == "{}" then return {} end

        local content = s:match("^%s*{%s*(.-)%s*}%s*$")
        if not content then return {} end

        local result = {}
        for match in content:gmatch('[^,]+') do
            local key, value = match:match('%s*"([^"]+)"%s*:%s*"([^"]*)"')
            if key and value then
                result[key] = value
            else
                key, value = match:match('%s*"([^"]+)"%s*:%s*(%a+)')
                if key and value then
                    if value == "true" then
                        result[key] = true
                    elseif value == "false" then
                        result[key] = false
                    else
                        result[key] = value
                    end
                else
                    key, value = match:match('%s*"([^"]+)"%s*:%s*([%d.-]+)')
                    if key and value then
                        result[key] = tonumber(value)
                    end
                end
            end
        end
        return result
    end
}

-- Helper to clear messages
local function clearMessages()
    testMessages = {}
end

-- Helper to send message and get response
local function sendMessage(msg)
    clearMessages()

    for name, handlerData in pairs(testHandlers) do
        if handlerData.matcher(msg) then
            handlerData.handler(msg)
            break
        end
    end

    return testMessages[1]
end

-- Mock package.loaded to provide json module
package.loaded.json = _G.json

-- Load the challenge framework engine
print("Loading challenge-framework-engine.lua...")
dofile("processes/challenge-framework-engine.lua")
print("✓ Process loaded successfully")

-- Test counter
local testsPassed = 0
local testsFailed = 0

-- Test helper
local function test(description, fn)
    local success, err = pcall(fn)
    if success then
        print("✓ " .. description)
        testsPassed = testsPassed + 1
    else
        print("✗ " .. description)
        print("  Error: " .. tostring(err))
        testsFailed = testsFailed + 1
    end
end

print("\n=== Challenge Validation Tests ===\n")

-- Test 1: Challenge with no conditions (always unlocked)
test("should return unlocked for challenge with no conditions", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "0",
        Data = "{}"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.Unlocked == "true", "Expected unlocked = true with no conditions")
end)

-- Test 2: Validate SINGLE_TYPE challenge
test("should validate SINGLE_TYPE challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "1",
        Data = "{}"
    })

    assert(result.Unlocked == "true", "Expected unlocked = true")
end)

-- Test 3: Validate FRESH_START challenge
test("should validate FRESH_START challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "4",
        Data = "{}"
    })

    assert(result.Unlocked == "true", "Expected unlocked = true")
end)

-- Test 4: Validate INVERSE_BATTLE challenge
test("should validate INVERSE_BATTLE challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "5",
        Data = "{}"
    })

    assert(result.Unlocked == "true", "Expected unlocked = true")
end)

-- Test 5: Validate HARDCORE challenge
test("should validate HARDCORE challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "9",
        Data = "{}"
    })

    assert(result.Unlocked == "true", "Expected unlocked = true")
end)

-- Test 6: Validate with empty GameData
test("should handle empty GameData", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "0",
        Data = ""
    })

    assert(result.Unlocked == "true", "Expected unlocked = true with empty data")
end)

-- Test 7: Validate with complex GameData
test("should handle complex GameData", function()
    local gameData = {
        progression = {
            beatGame = true,
            unlockedAchievements = {1, 2, 3}
        }
    }

    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "0",
        Data = json.encode(gameData)
    })

    assert(result.Unlocked == "true", "Expected unlocked = true")
end)

-- Test 8: Error handling for missing ChallengeId
test("should return error for missing ChallengeId", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        Data = "{}"
    })

    assert(result.Action == "Error", "Expected Error action")
    assert(result.Error:find("ChallengeId required"), "Expected ChallengeId error message")
end)

-- Test 9: Error handling for invalid ChallengeId
test("should return error for invalid ChallengeId", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "ValidateChallenge",
        ChallengeId = "999",
        Data = "{}"
    })

    assert(result.Action == "Error", "Expected Error action")
    assert(result.Error:find("not found"), "Expected challenge not found error")
end)

-- Test 10: Validate all 10 challenge types
test("should validate all 10 challenge types successfully", function()
    local challengeIds = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}

    for _, challengeId in ipairs(challengeIds) do
        local result = sendMessage({
            Target = ao.id,
            Action = "ValidateChallenge",
            ChallengeId = challengeId,
            Data = "{}"
        })

        assert(result.Unlocked == "true", "Expected unlocked = true for challenge " .. challengeId)
    end
end)

-- Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))
print(string.format("Total:  %d", testsPassed + testsFailed))

if testsFailed > 0 then
    os.exit(1)
end
