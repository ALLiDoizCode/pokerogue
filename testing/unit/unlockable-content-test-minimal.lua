-- Minimal test to debug unlockable content engine

-- Mock JSON
local json = {
    encode = function(t) return t end,  -- Keep as table
    decode = function(s) return type(s) == "table" and s or {} end
}
_G.json = json
package.loaded.json = json

-- Mock AO
local messages = {}
ao = {
    id = "test",
    send = function(msg)
        table.insert(messages, msg)
        print("Message sent:", msg.Action)
        if msg.Data then
            print("  Data type:", type(msg.Data))
            if type(msg.Data) == "table" and msg.Data.newUnlocks then
                print("  newUnlocks length:", #msg.Data.newUnlocks)
                for i, unlock in ipairs(msg.Data.newUnlocks) do
                    print("    [" .. i .. "]", unlock.name)
                end
            end
        end
    end
}

-- Mock Handlers
local handlers = {}
Handlers = {
    add = function(name, matcher, handler)
        handlers[name] = {matcher = matcher, handler = handler}
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg) return msg[tag] == value end
        end
    }
}

-- Load process
dofile("processes/unlockable-content-engine.lua")

-- Test evaluate-unlocks
print("\n=== Testing EvaluateUnlocks ===")
messages = {}
local testMsg = {
    Action = "EvaluateUnlocks",
    From = "test_client",
    PlayerId = "player_test",
    GameMode = "classic",
    IsVictory = "true",
    PartyData = {hasFusion = false, hasUnevolved = false},  -- Pass table directly
    Timestamp = 1234567890
}

print("Calling handler with:")
print("  GameMode:", testMsg.GameMode)
print("  IsVictory:", testMsg.IsVictory)
print("  PartyData type:", type(testMsg.PartyData))
print("  PartyData.hasFusion:", testMsg.PartyData.hasFusion)

handlers["evaluate-unlocks"].handler(testMsg)

print("\nResult:")
if #messages > 0 then
    local result = messages[1]
    print("Action:", result.Action)
    if result.Data then
        print("Data.totalUnlocked:", result.Data.totalUnlocked)
        print("Data.newUnlocks length:", #result.Data.newUnlocks)
    end
else
    print("No messages sent!")
end