--[[
  Event Species Collection Tracking Unit Tests

  Tests event species encounter tracking, collection statistics, and persistence.
]]

local aolite = require("aolite")
local json = require("json")

-- Test configuration (Story 2.10 optimized pattern)
local PROCESS_PATH = "processes.seasonal-event-engine"
local processId = "test-seasonal-event-engine"
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Event Species Collection")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,  -- REQUIRED
        Target = processId,
        Action = action,
        Data = data or ""
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Initialize collection for first encounter
print("📝 Test 1: Initialize collection for first encounter")
local response1 = sendMessage("TrackEventSpeciesEncounter", {
    SpeciesId = "GIMMIGHOUL",
    FormIndex = "0",
    IsShiny = "false",
    EventId = "test-event-1"  -- State isolation
})
if response1 and response1.Action == "SaveState" then
    local data1 = json.decode(response1.Data)
    local collection = data1.eventSpeciesCollection
    if collection and collection.totalEncounters == 1 and collection.uniqueSpecies == 1 and collection.shinyEncounters == 0 then
        local gimmighoul = collection.speciesEncountered and collection.speciesEncountered.GIMMIGHOUL
        if gimmighoul and gimmighoul.count == 1 and gimmighoul.shinyCount == 0 and #gimmighoul.formsSeen == 1 then
            print("✅ Test 1 passed")
        else
            error("❌ Test 1 failed: Invalid Gimmighoul entry")
        end
    else
        error("❌ Test 1 failed: Expected totalEncounters=1, uniqueSpecies=1, shinyEncounters=0")
    end
else
    error("❌ Test 1 failed: Expected SaveState action")
end

-- Test 2: Increment counters for repeat encounters
print("📝 Test 2: Increment counters for repeat encounters")
local gameState2 = {
    eventSpeciesCollection = {
        totalEncounters = 1,
        uniqueSpecies = 1,
        shinyEncounters = 0,
        speciesEncountered = {
            GIMMIGHOUL = {
                count = 1,
                shinyCount = 0,
                formsSeen = {0}
            }
        }
    }
}
local response2 = sendMessage("TrackEventSpeciesEncounter", {
    SpeciesId = "GIMMIGHOUL",
    FormIndex = "0",
    IsShiny = "false",
    EventId = "test-event-2",
    GameState = json.encode(gameState2)
})
if response2 and response2.Action == "SaveState" then
    local data2 = json.decode(response2.Data)
    local collection = data2.eventSpeciesCollection
    if collection.totalEncounters == 2 and collection.uniqueSpecies == 1 and collection.speciesEncountered.GIMMIGHOUL.count == 2 then
        print("✅ Test 2 passed")
    else
        error("❌ Test 2 failed: Expected totalEncounters=2, uniqueSpecies=1, Gimmighoul count=2")
    end
else
    error("❌ Test 2 failed: Expected SaveState action")
end

-- Test 3: Track shiny encounters correctly
print("📝 Test 3: Track shiny encounters correctly")
local gameState3 = {
    eventSpeciesCollection = {
        totalEncounters = 1,
        uniqueSpecies = 1,
        shinyEncounters = 0,
        speciesEncountered = {
            GIMMIGHOUL = {
                count = 1,
                shinyCount = 0,
                formsSeen = {0}
            }
        }
    }
}
local response3 = sendMessage("TrackEventSpeciesEncounter", {
    SpeciesId = "GIMMIGHOUL",
    FormIndex = "0",
    IsShiny = "true",
    EventId = "test-event-3",
    GameState = json.encode(gameState3)
})
if response3 and response3.Action == "SaveState" then
    local data3 = json.decode(response3.Data)
    local collection = data3.eventSpeciesCollection
    if collection.shinyEncounters == 1 and collection.speciesEncountered.GIMMIGHOUL.shinyCount == 1 then
        print("✅ Test 3 passed")
    else
        error("❌ Test 3 failed: Expected shinyEncounters=1, Gimmighoul shinyCount=1")
    end
else
    error("❌ Test 3 failed: Expected SaveState action")
end

-- Test 4: Track multiple forms for same species
print("📝 Test 4: Track multiple forms for same species")
local gameState4 = {
    eventSpeciesCollection = {
        totalEncounters = 1,
        uniqueSpecies = 1,
        shinyEncounters = 0,
        speciesEncountered = {
            PIKACHU = {
                count = 1,
                shinyCount = 0,
                formsSeen = {0}
            }
        }
    }
}
local response4 = sendMessage("TrackEventSpeciesEncounter", {
    SpeciesId = "PIKACHU",
    FormIndex = "1",
    IsShiny = "false",
    EventId = "test-event-4",
    GameState = json.encode(gameState4)
})
if response4 and response4.Action == "SaveState" then
    local data4 = json.decode(response4.Data)
    local pikachu = data4.eventSpeciesCollection.speciesEncountered.PIKACHU
    if #pikachu.formsSeen == 2 then
        print("✅ Test 4 passed")
    else
        error("❌ Test 4 failed: Expected 2 forms seen, got " .. #pikachu.formsSeen)
    end
else
    error("❌ Test 4 failed: Expected SaveState action")
end

-- Test 5: Add new unique species to collection
print("📝 Test 5: Add new unique species to collection")
local gameState5 = {
    eventSpeciesCollection = {
        totalEncounters = 2,
        uniqueSpecies = 1,
        shinyEncounters = 0,
        speciesEncountered = {
            GIMMIGHOUL = {
                count = 2,
                shinyCount = 0,
                formsSeen = {0}
            }
        }
    }
}
local response5 = sendMessage("TrackEventSpeciesEncounter", {
    SpeciesId = "DELIBIRD",
    FormIndex = "0",
    IsShiny = "false",
    EventId = "test-event-5",
    GameState = json.encode(gameState5)
})
if response5 and response5.Action == "SaveState" then
    local data5 = json.decode(response5.Data)
    local collection = data5.eventSpeciesCollection
    if collection.uniqueSpecies == 2 and collection.totalEncounters == 3 and collection.speciesEncountered.DELIBIRD and collection.speciesEncountered.DELIBIRD.count == 1 then
        print("✅ Test 5 passed")
    else
        error("❌ Test 5 failed: Expected uniqueSpecies=2, totalEncounters=3, Delibird count=1")
    end
else
    error("❌ Test 5 failed: Expected SaveState action")
end

-- Test 6: Default to form 0 when FormIndex missing
print("📝 Test 6: Default to form 0 when FormIndex missing")
local response6 = sendMessage("TrackEventSpeciesEncounter", {
    SpeciesId = "GIMMIGHOUL",
    IsShiny = "false",
    EventId = "test-event-6"
})
if response6 and response6.Action == "SaveState" then
    local data6 = json.decode(response6.Data)
    local gimmighoul = data6.eventSpeciesCollection.speciesEncountered.GIMMIGHOUL
    if gimmighoul.formsSeen[1] == 0 then
        print("✅ Test 6 passed")
    else
        error("❌ Test 6 failed: Expected form 0 by default, got " .. tostring(gimmighoul.formsSeen[1]))
    end
else
    error("❌ Test 6 failed: Expected SaveState action")
end

-- Test 7: Return error when SpeciesId missing
print("📝 Test 7: Return error when SpeciesId missing")
local response7 = sendMessage("TrackEventSpeciesEncounter", {
    FormIndex = "0",
    IsShiny = "false",
    EventId = "test-event-7"
})
if response7 and response7.Action == "Error" then
    if string.match(response7.Error or "", "SpeciesId") then
        print("✅ Test 7 passed")
    else
        error("❌ Test 7 failed: Error should mention SpeciesId")
    end
else
    error("❌ Test 7 failed: Expected Error action")
end

-- Test 8: Return empty collection when no encounters
print("📝 Test 8: Return empty collection when no encounters")
local response8 = sendMessage("GetEventSpeciesProgress", {
    EventId = "test-event-8"
})
if response8 and response8.Action == "SaveState" then
    local data8 = json.decode(response8.Data)
    local collection = data8.eventSpeciesCollection
    if collection and collection.totalEncounters == 0 and collection.uniqueSpecies == 0 and collection.shinyEncounters == 0 then
        print("✅ Test 8 passed")
    else
        error("❌ Test 8 failed: Expected empty collection")
    end
else
    error("❌ Test 8 failed: Expected SaveState action")
end

-- Test 9: Return existing collection from game state
print("📝 Test 9: Return existing collection from game state")
local gameState9 = {
    eventSpeciesCollection = {
        totalEncounters = 15,
        uniqueSpecies = 8,
        shinyEncounters = 2,
        speciesEncountered = {
            GIMMIGHOUL = {count = 3, shinyCount = 1, formsSeen = {0}},
            DELIBIRD = {count = 5, shinyCount = 0, formsSeen = {0}},
            PIKACHU = {count = 7, shinyCount = 1, formsSeen = {0, 1}}
        }
    }
}
local response9 = sendMessage("GetEventSpeciesProgress", {
    EventId = "test-event-9",
    GameState = json.encode(gameState9)
})
if response9 and response9.Action == "SaveState" then
    local data9 = json.decode(response9.Data)
    local collection = data9.eventSpeciesCollection
    if collection.totalEncounters == 15 and collection.uniqueSpecies == 8 and collection.shinyEncounters == 2 and collection.speciesEncountered.GIMMIGHOUL.count == 3 then
        print("✅ Test 9 passed")
    else
        error("❌ Test 9 failed: Collection data mismatch")
    end
else
    error("❌ Test 9 failed: Expected SaveState action")
end

-- Test 10: Complex multi-species collection scenario
print("📝 Test 10: Complex multi-species collection scenario")
local gameState10 = {
    eventSpeciesCollection = {
        totalEncounters = 0,
        uniqueSpecies = 0,
        shinyEncounters = 0,
        speciesEncountered = {}
    }
}

local encounters = {
    {species = "GIMMIGHOUL", shiny = false},
    {species = "GIMMIGHOUL", shiny = true},
    {species = "DELIBIRD", shiny = false},
    {species = "PIKACHU", shiny = false},
    {species = "GIMMIGHOUL", shiny = false},
    {species = "DELIBIRD", shiny = true},
    {species = "STANTLER", shiny = false}
}

for i, encounter in ipairs(encounters) do
    local response = sendMessage("TrackEventSpeciesEncounter", {
        SpeciesId = encounter.species,
        FormIndex = "0",
        IsShiny = tostring(encounter.shiny),
        EventId = "test-event-10-" .. i,
        GameState = json.encode(gameState10)
    })
    if response and response.Action == "SaveState" then
        local data = json.decode(response.Data)
        gameState10.eventSpeciesCollection = data.eventSpeciesCollection
    else
        error("❌ Test 10 failed: SaveState expected for encounter " .. i)
    end
end

local collection = gameState10.eventSpeciesCollection
if collection.totalEncounters == 7 and collection.uniqueSpecies == 4 and collection.shinyEncounters == 2 and
   collection.speciesEncountered.GIMMIGHOUL.count == 3 and collection.speciesEncountered.GIMMIGHOUL.shinyCount == 1 and
   collection.speciesEncountered.DELIBIRD.count == 2 and collection.speciesEncountered.PIKACHU.count == 1 and
   collection.speciesEncountered.STANTLER.count == 1 then
    print("✅ Test 10 passed")
else
    error("❌ Test 10 failed: Complex collection data mismatch")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ 10/10 Event Species Collection tests completed")
