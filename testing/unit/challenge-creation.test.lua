-- Unit Tests: Challenge Creation and Modification
-- Tests challenge factory functions, value/severity bounds, and modification methods
-- Target: 15 tests

-- Mock environment setup
local testMessages = {}
local testHandlers = {}
local currentChallengeId = 0

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

        -- Simple decode for test purposes
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

    -- Find matching handler
    for name, handlerData in pairs(testHandlers) do
        if handlerData.matcher(msg) then
            handlerData.handler(msg)
            break
        end
    end

    -- Return first response message
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

print("\n=== Challenge Creation Tests ===\n")

-- Test 1: SINGLE_GENERATION challenge instantiation
test("should create SINGLE_GENERATION challenge with correct defaults", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "0"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.ChallengeId == "0", "Expected challenge ID 0")
    assert(result.Value == "0", "Expected initial value 0")
    assert(result.Severity == "0", "Expected initial severity 0")
end)

-- Test 2: SINGLE_TYPE challenge instantiation
test("should create SINGLE_TYPE challenge with maxValue 18", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "1"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.ChallengeId == "1", "Expected challenge ID 1")
end)

-- Test 3: FRESH_START challenge instantiation
test("should create FRESH_START challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "4"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.ChallengeId == "4", "Expected challenge ID 4")
end)

-- Test 4: INVERSE_BATTLE challenge instantiation
test("should create INVERSE_BATTLE challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "5"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.ChallengeId == "5", "Expected challenge ID 5")
end)

-- Test 5: HARDCORE challenge instantiation
test("should create HARDCORE challenge", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "9"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.ChallengeId == "9", "Expected challenge ID 9")
end)

-- Test 6: Create challenge with initial value
test("should create challenge with initial value", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "0",
        Value = "5"
    })

    assert(result.Action == "SaveState", "Expected SaveState action")
    assert(result.Value == "5", "Expected value 5")
end)

-- Test 7: Value bounds enforcement (within bounds)
test("should enforce value within bounds", function()
    -- First create challenge
    sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "0"
    })

    -- Increase value 6 times
    for i = 1, 6 do
        sendMessage({
            Target = ao.id,
            Action = "ModifyChallenge",
            ChallengeId = "0",
            Operation = "IncreaseValue"
        })
    end

    local result = sendMessage({
        Target = ao.id,
        Action = "GetChallengeInfo",
        ChallengeId = "0"
    })

    local data = json.decode(result.Data)
    assert(tonumber(data.value) == 6, "Expected value 6 after 6 increments, got " .. tostring(data.value))
end)

-- Test 8: Value bounds enforcement (at max)
test("should not increase value beyond maxValue", function()
    -- First reset the challenge
    sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "Reset"
    })

    -- Set to max value
    for i = 1, 9 do
        sendMessage({
            Target = ao.id,
            Action = "ModifyChallenge",
            ChallengeId = "0",
            Operation = "IncreaseValue"
        })
    end

    -- Try to increase beyond max
    local result = sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "IncreaseValue"
    })

    assert(result.Modified == "false", "Expected modified = false at maxValue")
    assert(result.Value == "9", "Expected value to remain 9")
end)

-- Test 9: IncreaseValue method
test("should increase value correctly", function()
    -- Reset first
    sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "Reset"
    })

    local result = sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "IncreaseValue"
    })

    assert(result.Modified == "true", "Expected modified = true")
    assert(result.Value == "1", "Expected value 1 after increase")
end)

-- Test 10: DecreaseValue method
test("should decrease value correctly", function()
    -- Reset first, then set to 5
    sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "Reset"
    })

    for i = 1, 5 do
        sendMessage({
            Target = ao.id,
            Action = "ModifyChallenge",
            ChallengeId = "0",
            Operation = "IncreaseValue"
        })
    end

    local result = sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "DecreaseValue"
    })

    assert(result.Modified == "true", "Expected modified = true")
    assert(result.Value == "4", "Expected value 4 after decrease")
end)

-- Test 11: DecreaseValue at zero
test("should not decrease value below zero", function()
    -- Reset to ensure value is 0
    sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "Reset"
    })

    local result = sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "DecreaseValue"
    })

    assert(result.Modified == "false", "Expected modified = false at zero")
    assert(result.Value == "0", "Expected value to remain 0")
end)

-- Test 12: Reset method
test("should reset challenge to default state", function()
    sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "0",
        Value = "5"
    })

    local result = sendMessage({
        Target = ao.id,
        Action = "ModifyChallenge",
        ChallengeId = "0",
        Operation = "Reset"
    })

    assert(result.Modified == "true", "Expected modified = true")
    assert(result.Value == "0", "Expected value 0 after reset")
    assert(result.Severity == "0", "Expected severity 0 after reset")
end)

-- Test 13: getRibbonAwarded for SINGLE_GENERATION (bitshift logic)
test("should calculate SINGLE_GENERATION ribbon with bitshift", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "0",
        Value = "3"
    })

    -- MONO_GEN_1 = 1, bitshift by (3-1) = 2 positions = 1 * 2^2 = 4
    -- Handle both "4" and "4.0" as valid (Lua number-to-string conversion)
    local ribbon = tonumber(result.RibbonAwarded)
    assert(ribbon == 4, "Expected ribbon 4 for Gen 3, got " .. tostring(result.RibbonAwarded))
end)

-- Test 14: getRibbonAwarded for HARDCORE (static ribbon)
test("should return static ribbon for HARDCORE", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "9",
        Value = "1"
    })

    -- HARDCORE ribbon = 65536
    assert(result.RibbonAwarded == "65536", "Expected HARDCORE ribbon 65536, got " .. tostring(result.RibbonAwarded))
end)

-- Test 15: getRibbonAwarded for value = 0 (no ribbon)
test("should return 0 ribbon when value is 0", function()
    local result = sendMessage({
        Target = ao.id,
        Action = "CreateChallenge",
        ChallengeId = "0",
        Value = "0"
    })

    assert(result.RibbonAwarded == "0", "Expected ribbon 0 when value = 0")
end)

-- Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))
print(string.format("Total:  %d", testsPassed + testsFailed))

if testsFailed > 0 then
    os.exit(1)
end
