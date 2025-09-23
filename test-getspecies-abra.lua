#!/usr/bin/env lua
-- Test GetSpecies handler with Abra and SpeciesId 63
-- Using both aolite and aos-local for comprehensive testing

local aolite = require('aolite')

print("🧪 Testing GetSpecies Handler with Abra and SpeciesId 63")
print("============================================================")

-- Initialize aolite environment
local process_id = aolite.spawnProcess('processes/pokemon-species-db.lua')
print("✅ Spawned pokemon-species-db process:", process_id)

-- Test 1: GetSpecies by SpeciesId = 63 (Abra)
print("\n🔬 Test 1: GetSpecies by SpeciesId = 63")
print("--------------------------------------------------")
local response1 = aolite.send("test-caller", process_id, {
    Action = "GetSpecies",
    SpeciesId = "63",
    Timestamp = tostring(os.time())
})

-- Run scheduler to process the message
aolite.runScheduler()

-- Get all messages to see the response
local messages = aolite.getAllMsgs()
local found_response1 = false

for _, msg in ipairs(messages) do
    if msg.Target == "test-caller" and msg.Action == "SaveState" then
        print("📥 Response received:")
        print("  Action:", msg.Action)
        print("  From:", msg.From)
        if msg.Data then
            local success, data = pcall(function() return require('json').decode(msg.Data) end)
            if success and data then
                print("  Species Name:", data.name)
                print("  Species ID:", data.id)
                print("  Generation:", data.generation)
                print("  Types:", table.concat(data.types or {}, ", "))
                if data.name == "abra" and data.id == 63 then
                    print("  ✅ PASS: Correct species returned for SpeciesId 63")
                    found_response1 = true
                else
                    print("  ❌ FAIL: Wrong species returned")
                end
            end
        elseif msg.Error then
            print("  ❌ Error:", msg.Error)
        end
        break
    end
end

if not found_response1 then
    print("  ❌ FAIL: No response received for SpeciesId 63")
end

-- Clear messages for next test
aolite.setMessageLog(0)  -- Clear previous messages

-- Test 2: GetSpecies by SpeciesName = "Abra"
print("\n🔬 Test 2: GetSpecies by SpeciesName = 'Abra'")
print("--------------------------------------------------")
local response2 = aolite.send("test-caller-2", process_id, {
    Action = "GetSpecies",
    SpeciesName = "Abra",
    Timestamp = tostring(os.time())
})

-- Run scheduler to process the message
aolite.runScheduler()

-- Get all messages to see the response
local messages2 = aolite.getAllMsgs()
local found_response2 = false

for _, msg in ipairs(messages2) do
    if msg.Target == "test-caller-2" and msg.Action == "SaveState" then
        print("📥 Response received:")
        print("  Action:", msg.Action)
        print("  From:", msg.From)
        if msg.Data then
            local success, data = pcall(function() return require('json').decode(msg.Data) end)
            if success and data then
                print("  Species Name:", data.name)
                print("  Species ID:", data.id)
                print("  Generation:", data.generation)
                print("  Types:", table.concat(data.types or {}, ", "))
                if data.name == "abra" and data.id == 63 then
                    print("  ✅ PASS: Correct species returned for SpeciesName 'Abra'")
                    found_response2 = true
                else
                    print("  ❌ FAIL: Wrong species returned")
                end
            end
        elseif msg.Error then
            print("  ❌ Error:", msg.Error)
        end
        break
    end
end

if not found_response2 then
    print("  ❌ FAIL: No response received for SpeciesName 'Abra'")
end

-- Test 3: GetSpecies by Name = "Abra" (alternative tag)
print("\n🔬 Test 3: GetSpecies by Name = 'Abra' (alternative tag)")
print("--------------------------------------------------")
local response3 = aolite.send("test-caller-3", process_id, {
    Action = "GetSpecies",
    Name = "Abra",
    Timestamp = tostring(os.time())
})

-- Run scheduler to process the message
aolite.runScheduler()

-- Get all messages to see the response
local messages3 = aolite.getAllMsgs()
local found_response3 = false

for _, msg in ipairs(messages3) do
    if msg.Target == "test-caller-3" and msg.Action == "SaveState" then
        print("📥 Response received:")
        print("  Action:", msg.Action)
        print("  From:", msg.From)
        if msg.Data then
            local success, data = pcall(function() return require('json').decode(msg.Data) end)
            if success and data then
                print("  Species Name:", data.name)
                print("  Species ID:", data.id)
                print("  Generation:", data.generation)
                print("  Types:", table.concat(data.types or {}, ", "))
                if data.name == "abra" and data.id == 63 then
                    print("  ✅ PASS: Correct species returned for Name 'Abra'")
                    found_response3 = true
                else
                    print("  ❌ FAIL: Wrong species returned")
                end
            end
        elseif msg.Error then
            print("  ❌ Error:", msg.Error)
        end
        break
    end
end

if not found_response3 then
    print("  ❌ FAIL: No response received for Name 'Abra'")
end

-- Test 4: GetSpecies by Id = "63" (alternative tag)
print("\n🔬 Test 4: GetSpecies by Id = '63' (alternative tag)")
print("--------------------------------------------------")
local response4 = aolite.send("test-caller-4", process_id, {
    Action = "GetSpecies",
    Id = "63",
    Timestamp = tostring(os.time())
})

-- Run scheduler to process the message
aolite.runScheduler()

-- Get all messages to see the response
local messages4 = aolite.getAllMsgs()
local found_response4 = false

for _, msg in ipairs(messages4) do
    if msg.Target == "test-caller-4" and msg.Action == "SaveState" then
        print("📥 Response received:")
        print("  Action:", msg.Action)
        print("  From:", msg.From)
        if msg.Data then
            local success, data = pcall(function() return require('json').decode(msg.Data) end)
            if success and data then
                print("  Species Name:", data.name)
                print("  Species ID:", data.id)
                print("  Generation:", data.generation)
                print("  Types:", table.concat(data.types or {}, ", "))
                if data.name == "abra" and data.id == 63 then
                    print("  ✅ PASS: Correct species returned for Id '63'")
                    found_response4 = true
                else
                    print("  ❌ FAIL: Wrong species returned")
                end
            end
        elseif msg.Error then
            print("  ❌ Error:", msg.Error)
        end
        break
    end
end

if not found_response4 then
    print("  ❌ FAIL: No response received for Id '63'")
end

-- Summary
print("\n📊 Test Summary")
print("============================================================")
local total_tests = 4
local passed_tests = 0
if found_response1 then passed_tests = passed_tests + 1 end
if found_response2 then passed_tests = passed_tests + 1 end
if found_response3 then passed_tests = passed_tests + 1 end
if found_response4 then passed_tests = passed_tests + 1 end

print(string.format("Total Tests: %d", total_tests))
print(string.format("Passed: %d", passed_tests))
print(string.format("Failed: %d", total_tests - passed_tests))
print(string.format("Success Rate: %.1f%%", (passed_tests / total_tests) * 100))

if passed_tests == total_tests then
    print("🎉 All GetSpecies tests PASSED!")
else
    print("❌ Some tests FAILED!")
end