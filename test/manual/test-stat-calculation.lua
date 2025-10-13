#!/usr/bin/env lua

-- Manual test for CalculateStats functionality

-- Mock AO environment for testing
local captured_responses = {}
ao = {
    send = function(msg) 
        table.insert(captured_responses, msg)
        print("Response:", msg.Data and (msg.Data.hp and string.format("HP: %d, ATK: %d, DEF: %d", msg.Data.hp, msg.Data.attack, msg.Data.defense) or tostring(msg.Data)) or "no data")
        return true
    end,
    id = "test-pokemon-species-db"
}

-- Mock Handlers system
Handlers = {
    list = {},
    add = function(name, matcher, handler)
        table.insert(Handlers.list, {
            name = name,
            matcher = matcher,
            handle = handler
        })
    end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg)
                if type(values) == "table" then
                    for _, value in ipairs(values) do
                        if msg[tag] == value then return true end
                    end
                else
                    return msg[tag] == values
                end
                return false
            end
        end
    }
}

-- Load the process
local process = loadfile("processes/pokemon-species-db.lua")
assert(process, "Failed to load pokemon-species-db.lua")

-- Execute the process to register handlers
local result = process()

print("🧪 Testing CalculateStats functionality...")

-- Test the exact scenario from parity test
local testMsg = {
    Action = "CalculateStats",
    Data = {
        species = "Charizard",
        level = 50,
        nature = "Adamant",
        ivs = {
            attack = 31,
            hp = 31,
            defense = 20
        },
        evs = {
            attack = 252,
            hp = 252
        }
    },
    From = "test",
    Timestamp = 1234567890
}

-- Find and execute the handler
local handled = false
for _, handler in pairs(Handlers.list or {}) do
    if handler.name == "pokemon-species-query" then
        if handler.matcher(testMsg) then
            handler.handle(testMsg)
            handled = true
            break
        end
    end
end

if handled then
    print("✓ CalculateStats test executed")
    if #captured_responses > 0 then
        local response = captured_responses[1]
        if response.Data then
            print("Expected from parity test: HP: 153, ATK: 156, DEF: 98")
        end
    end
else
    print("✗ CalculateStats test failed - handler not found or didn't match")
end