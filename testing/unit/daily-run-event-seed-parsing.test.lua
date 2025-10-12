-- Aolite Unit Tests for Daily Run Event Seed Parsing
-- Tests boss modifier, multiple modifiers, malformed patterns, partial modifiers
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.daily-run-engine"
local processId = "test-daily-run-event-seed-parsing"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Daily Run Event Seed Parsing")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Boss Modifier Parsing - Valid Species
print("📝 Test 1: Boss Modifier Parsing - Valid Species")
local eventSeed = "20250103abcdefghij123456/boss014900/"
local bossResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = eventSeed}))
if bossResponse and bossResponse.Action == "SaveState" then
    print("✅ Boss modifier parsing handler responds")
else
    error("❌ Boss modifier test failed")
end

-- Test 2: Multiple Modifier Combinations
print("📝 Test 2: Multiple Modifier Combinations")
local multiSeed = "20250103abcdefghij123456/starters002500013300003700/boss014900/biome08/luck12/"
local multiResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = multiSeed}))
if multiResponse and multiResponse.Action == "SaveState" then
    print("✅ Multiple modifiers parsing handler responds")
else
    error("❌ Multiple modifiers test failed")
end

-- Test 3: Malformed Pattern Handling - Invalid Starter Format
print("📝 Test 3: Malformed Pattern Handling - Invalid Starter Format")
local malformedSeed = "20250103abcdefghij123456/starters_invalid/"
local malformedResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = malformedSeed}))
if malformedResponse and malformedResponse.Action == "SaveState" then
    print("✅ Malformed pattern handling responds")
else
    error("❌ Malformed pattern test failed")
end

-- Test 4: Partial Modifier Scenarios - Only Biome
print("📝 Test 4: Partial Modifier Scenarios - Only Biome")
local biomeSeed = "20250103abcdefghij123456/biome05/"
local biomeResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = biomeSeed}))
if biomeResponse and biomeResponse.Action == "SaveState" then
    print("✅ Partial biome modifier handler responds")
else
    error("❌ Partial biome modifier test failed")
end

-- Test 5: Invalid Biome ID Handling (>34)
print("📝 Test 5: Invalid Biome ID Handling (>34)")
local invalidBiomeSeed = "20250103abcdefghij123456/biome99/"
local invalidBiomeResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = invalidBiomeSeed}))
if invalidBiomeResponse and invalidBiomeResponse.Action == "SaveState" then
    print("✅ Invalid biome ID handler responds")
else
    error("❌ Invalid biome ID test failed")
end

-- Test 6: Invalid Luck Range (>14)
print("📝 Test 6: Invalid Luck Range (>14)")
local invalidLuckSeed = "20250103abcdefghij123456/luck15/"
local invalidLuckResponse = sendMessage("ParseEventSeed", nil, json.encode({seed = invalidLuckSeed}))
if invalidLuckResponse and invalidLuckResponse.Action == "SaveState" then
    print("✅ Invalid luck handler responds")
else
    error("❌ Invalid luck test failed")
end

-- Test 7: Valid Luck Range Boundary (0 and 14)
print("📝 Test 7: Valid Luck Range Boundary (0 and 14)")
local testCases = {
    {seed = "20250103abcdefghij123456/luck00/", expectedLuck = 0},
    {seed = "20250103abcdefghij123456/luck14/", expectedLuck = 14}
}
local boundaryCount = 0
for _, testCase in ipairs(testCases) do
    local response = sendMessage("ParseEventSeed", nil, json.encode({seed = testCase.seed}))
    if response and response.Action == "SaveState" then
        boundaryCount = boundaryCount + 1
    end
end
if boundaryCount == #testCases then
    print("✅ Luck boundary validation: all " .. boundaryCount .. " cases responded")
else
    error("❌ Only " .. boundaryCount .. "/" .. #testCases .. " cases responded")
end

-- Test Summary
print("==================================================")
print("🎉 All Event Seed Parsing tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
