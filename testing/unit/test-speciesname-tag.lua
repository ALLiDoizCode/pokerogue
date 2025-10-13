-- Test for GetSpecies handler with SpeciesName tag only
-- Confirms that Name tag is avoided (might be reserved in AO)

print("\n====================================")
print("Testing GetSpecies with SpeciesName tag")
print("====================================")

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local ao = {
    id = "test-pokemon-species-db",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers
local Handlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg)
                if type(values) == "table" then
                    for _, value in ipairs(values) do
                        if msg[tag] == value then
                            return true
                        end
                    end
                    return false
                else
                    return msg[tag] == values
                end
            end
        end
    }
}

-- Mock JSON
local json = {
    encode = function(t)
        if type(t) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(t) do
                if not first then result = result .. "," end
                result = result .. '"' .. tostring(k) .. '":"' .. tostring(v) .. '"'
                first = false
            end
            return result .. "}"
        end
        return tostring(t)
    end,
    decode = function(s) return {} end
}

-- Set globals
_G.ao = ao
_G.Handlers = Handlers
_G.json = json
_G.msg = {} -- dummy msg for initialization

-- Load the pokemon-species-db process
dofile("processes/pokemon-species-db.lua")

-- Helper function to test handler
local function testHandler(handlerName, message)
    testMessages = {} -- Clear previous messages

    if testHandlers[handlerName] then
        local handler = testHandlers[handlerName].handler
        handler(message)
        return testMessages
    else
        error("Handler not found: " .. handlerName)
    end
end

print("\n=== Test 1: SpeciesName='Abra' ===")
local responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    SpeciesName = "Abra"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ ERROR: " .. response.Error)
    elseif response.SpeciesName == "Abra" then
        print("  ✅ SUCCESS: Found Abra")
        print("    - Species ID: " .. (response.SpeciesId or "nil"))
        print("    - HP: " .. (response.HP or "nil"))
    else
        print("  ❌ Wrong Pokemon: " .. (response.SpeciesName or "nil"))
    end
else
    print("  ❌ No response received")
end

print("\n=== Test 2: SpeciesName='Pikachu' ===")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    SpeciesName = "Pikachu"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ ERROR: " .. response.Error)
    elseif response.SpeciesName == "Pikachu" then
        print("  ✅ SUCCESS: Found Pikachu")
        print("    - Species ID: " .. (response.SpeciesId or "nil"))
    else
        print("  ❌ Wrong Pokemon: " .. (response.SpeciesName or "nil"))
    end
else
    print("  ❌ No response received")
end

print("\n=== Test 3: SpeciesName='bulbasaur' (lowercase) ===")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    SpeciesName = "bulbasaur"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ ERROR: " .. response.Error)
    elseif response.SpeciesName == "Bulbasaur" then
        print("  ✅ SUCCESS: Found Bulbasaur (case insensitive)")
        print("    - Species ID: " .. (response.SpeciesId or "nil"))
    else
        print("  ❌ Wrong Pokemon: " .. (response.SpeciesName or "nil"))
    end
else
    print("  ❌ No response received")
end

print("\n=== Test 4: Name tag should NOT work ===")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Name = "Pikachu"  -- Using Name tag (should not work)
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ✅ EXPECTED: Error because Name tag is not supported")
        print("    - Error: " .. response.Error)
    else
        print("  ❌ UNEXPECTED: Name tag worked (should only use SpeciesName)")
    end
else
    print("  ❌ No response received")
end

print("\n=== Test 5: Missing both SpeciesName and Id ===")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies"
    -- No SpeciesName or Id provided
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ✅ EXPECTED: Error for missing parameters")
        print("    - Error: " .. response.Error)
    else
        print("  ❌ UNEXPECTED: Should have returned error")
    end
else
    print("  ❌ No response received")
end

print("\n====================================")
print("SpeciesName Tag Test Complete")
print("====================================\n")