-- Test for GetSpecies handler with Name tag
-- This tests the fix for name-based Pokemon lookups

print("\n====================================")
print("Testing Pokemon Name Tag Lookup")
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

-- Test 1: Name tag with "Pikachu"
print("\nTest 1: GetSpecies with Name='Pikachu'")
local responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Name = "Pikachu"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ FAILED: " .. response.Error)
    elseif response.SpeciesName == "Pikachu" then
        print("  ✅ PASSED: Found Pikachu")
        print("    - Species ID: " .. (response.SpeciesId or "nil"))
        print("    - HP: " .. (response.HP or "nil"))
        print("    - Attack: " .. (response.Attack or "nil"))
    else
        print("  ❌ FAILED: Wrong Pokemon returned")
    end
else
    print("  ❌ FAILED: No response received")
end

-- Test 2: Case insensitive with "pikachu"
print("\nTest 2: GetSpecies with Name='pikachu' (lowercase)")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Name = "pikachu"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ FAILED: " .. response.Error)
    elseif response.SpeciesName == "Pikachu" then
        print("  ✅ PASSED: Found Pikachu (case insensitive)")
    else
        print("  ❌ FAILED: Wrong Pokemon returned")
    end
else
    print("  ❌ FAILED: No response received")
end

-- Test 3: SpeciesName tag with "Bulbasaur"
print("\nTest 3: GetSpecies with SpeciesName='Bulbasaur'")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    SpeciesName = "Bulbasaur"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ FAILED: " .. response.Error)
    elseif response.SpeciesName == "Bulbasaur" then
        print("  ✅ PASSED: Found Bulbasaur")
        print("    - Species ID: " .. (response.SpeciesId or "nil"))
    else
        print("  ❌ FAILED: Wrong Pokemon returned")
    end
else
    print("  ❌ FAILED: No response received")
end

-- Test 4: Non-existent Pokemon
print("\nTest 4: GetSpecies with Name='FakePokemon'")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Name = "FakePokemon"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ✅ PASSED: Correctly returned error")
        print("    - Error: " .. response.Error)
    else
        print("  ❌ FAILED: Should have returned error for non-existent Pokemon")
    end
else
    print("  ❌ FAILED: No response received")
end

-- Test 5: Using ID still works
print("\nTest 5: GetSpecies with Id='25' (Pikachu's ID)")
responses = testHandler("get-species", {
    From = "test-client",
    Action = "GetSpecies",
    Id = "25"
})

if #responses > 0 then
    local response = responses[1]
    if response.Error then
        print("  ❌ FAILED: " .. response.Error)
    elseif response.SpeciesName == "Pikachu" then
        print("  ✅ PASSED: Found Pikachu by ID")
    else
        print("  ❌ FAILED: Wrong Pokemon returned")
    end
else
    print("  ❌ FAILED: No response received")
end

print("\n====================================")
print("Name Tag Test Suite Complete")
print("====================================\n")