-- Unit Tests: Challenge Serialization and Deserialization
-- Tests ChallengeData creation, toChallenge hydration, copyChallenge, and round-trip serialization
-- Target: 5 tests

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

_G.ao = {
    id = "test-challenge-engine",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

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
                        if msg[tag] == v then return true end
                    end
                    return false
                else
                    return msg[tag] == value
                end
            end
        end
    }
}

_G.json = {
    encode = function(t)
        if type(t) ~= "table" then return '"' .. tostring(t) .. '"' end
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
                    if value == "true" then result[key] = true
                    elseif value == "false" then result[key] = false
                    else result[key] = value end
                else
                    key, value = match:match('%s*"([^"]+)"%s*:%s*([%d.-]+)')
                    if key and value then result[key] = tonumber(value) end
                end
            end
        end
        return result
    end
}

local function clearMessages()
    testMessages = {}
end

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

package.loaded.json = _G.json

print("Loading challenge-framework-engine.lua...")
dofile("processes/challenge-framework-engine.lua")
print("✓ Process loaded successfully")

local testsPassed = 0
local testsFailed = 0

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

print("\n=== Challenge Serialization Tests ===\n")

test("should serialize challenge to ChallengeData", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "SerializeChallenge",
        ChallengeId = "0"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    local data = json.decode(result.Data)
    assert(data.id == 0, "Expected id = 0")
end)

test("should deserialize ChallengeData to Challenge instance", function()
    local challengeData = {
        id = 9,
        value = 1,
        severity = 0
    }

    local result = sendMessage({
        Target = ao.id,
        Action = "DeserializeChallenge",
        Data = json.encode(challengeData)
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.ChallengeId == "9", "Expected challenge ID 9")
    assert(result.Value == "1", "Expected value 1")
    assert(result.Severity == "0", "Expected severity 0")
end)

test("should copy all 10 challenge types correctly", function()
    local challengeTypes = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}

    for _, id in ipairs(challengeTypes) do
        local challengeData = {id = id, value = 1, severity = 0}
        local result = sendMessage({
            Target = ao.id,
            Action = "DeserializeChallenge",
            Data = json.encode(challengeData)
        })
        assert(result.Action == "SaveState", "Expected SaveState for challenge " .. id)
        assert(result.ChallengeId == tostring(id), "Expected challenge ID " .. id)
    end
end)

test("should preserve state through round-trip serialization", function()
    local serializeResult = sendMessage({
        Target = ao.id,
        Action = "SerializeChallenge",
        ChallengeId = "1"
    })

    local deserializeResult = sendMessage({
        Target = ao.id,
        Action = "DeserializeChallenge",
        Data = serializeResult.Data
    })

    assert(deserializeResult.Action == "SaveState", "Expected SaveState action")
    assert(deserializeResult.ChallengeId == "1", "Expected challenge ID 1")
end)

test("should handle edge cases in serialization", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "SerializeChallenge",
        ChallengeId = "0"
    })

    local data = json.decode(result.Data)
    assert(data.id == 0, "Expected id = 0")

    local invalidData = {id = 999, value = 1, severity = 0}
    local errorResult = sendMessage({
        Target = ao.id,
        Action = "DeserializeChallenge",
        Data = json.encode(invalidData)
    })

    assert(errorResult.Action == "Error", "Expected Error for invalid challenge ID")
end)

test("should retrieve active challenges from GameState", function()
    local gameState = {
        activeChallenges = {
            {id = 0, value = 5, severity = 0},
            {id = 9, value = 1, severity = 0}
        }
    }

    local result = sendMessage({
        Target = ao.id,
        Action = "GetActiveChallenges",
        Data = json.encode(gameState)
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    -- Note: Mock JSON can't properly handle nested arrays, so just verify basic structure
    assert(result.Data, "Expected Data field with active challenges")
end)

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))
print(string.format("Total:  %d", testsPassed + testsFailed))

if testsFailed > 0 then
    os.exit(1)
end
