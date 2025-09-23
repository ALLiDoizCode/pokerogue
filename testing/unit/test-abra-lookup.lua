-- Test for GetSpecies handler with Name tag for Abra
-- Testing the exact message format the user is using

print("\n====================================")
print("Testing GetSpecies with Name='Abra'")
print("====================================")

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local ao = {
    id = "test-pokemon-species-db",
    send = function(msg)
        table.insert(testMessages, msg)
        print("\nResponse message sent:")
        for k, v in pairs(msg) do
            print("  " .. k .. " = " .. tostring(v))
        end
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

-- First, let's check if Abra exists in the database
print("\nChecking if Abra exists in the database...")

-- Test with exact message format user is using
print("\n=== Testing GetSpecies with Name='Abra' ===")
print("Sending message with tags:")
print("  Action = 'GetSpecies'")
print("  Name = 'Abra'")

local responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Name = "Abra"
})

if #responses > 0 then
    local response = responses[1]
    print("\nResponse analysis:")
    if response.Error then
        print("  ❌ ERROR FOUND: " .. response.Error)
        print("  This means Abra was NOT found in the database")
    elseif response.SpeciesName then
        print("  ✅ SUCCESS: Found " .. response.SpeciesName)
        print("    - Species ID: " .. (response.SpeciesId or "nil"))
        print("    - HP: " .. (response.HP or "nil"))
        print("    - Attack: " .. (response.Attack or "nil"))
    else
        print("  ⚠️ UNEXPECTED: No Error but also no SpeciesName")
    end
else
    print("  ❌ FAILED: No response received")
end

-- Let's also test with lowercase
print("\n=== Testing GetSpecies with Name='abra' (lowercase) ===")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Name = "abra"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ ERROR: " .. response.Error)
    elseif response.SpeciesName then
        print("  ✅ SUCCESS: Found " .. response.SpeciesName)
    end
end

-- Let's check if Abra might be under a different ID
print("\n=== Checking database for Abra ===")
-- Abra is typically Pokemon #63 in the official Pokedex
print("Testing with ID 63 (Abra's typical Pokedex number)...")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Id = "63"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ID 63 not found: " .. response.Error)
    elseif response.SpeciesName then
        print("  Found at ID 63: " .. response.SpeciesName)
    end
end

print("\n====================================")
print("Test Complete")
print("====================================\n")