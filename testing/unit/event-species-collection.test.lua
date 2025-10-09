--[[
  Event Species Collection Tracking Unit Tests

  Tests event species encounter tracking, collection statistics, and persistence.
]]

local aolite = require("aolite")
local json = require("json")

-- Load the seasonal event engine process
local processPath = "processes/seasonal-event-engine.lua"
local process = aolite.spawnProcess(processPath)

-- Test suite
describe("Event Species Collection Tracking", function()

  -- Test: TrackEventSpeciesEncounter initializes collection
  it("should initialize collection for first encounter", function()
    local msg = {
      Action = "TrackEventSpeciesEncounter",
      SpeciesId = "GIMMIGHOUL",
      FormIndex = "0",
      IsShiny = "false",
      GameState = "",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local collection = response.eventSpeciesCollection

    assert(collection, "Should return collection")
    assert(collection.totalEncounters == 1, "Should have 1 total encounter")
    assert(collection.uniqueSpecies == 1, "Should have 1 unique species")
    assert(collection.shinyEncounters == 0, "Should have 0 shiny encounters")

    local gimmighoul = collection.speciesEncountered.GIMMIGHOUL
    assert(gimmighoul, "Should have Gimmighoul entry")
    assert(gimmighoul.count == 1, "Gimmighoul count should be 1")
    assert(gimmighoul.shinyCount == 0, "Gimmighoul shiny count should be 0")
    assert(#gimmighoul.formsSeen == 1, "Should have 1 form seen")
    assert(gimmighoul.formsSeen[1] == 0, "Should have form 0")
  end)

  -- Test: TrackEventSpeciesEncounter increments existing species
  it("should increment counters for repeat encounters", function()
    -- First encounter
    local gameState = {
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

    local msg = {
      Action = "TrackEventSpeciesEncounter",
      SpeciesId = "GIMMIGHOUL",
      FormIndex = "0",
      IsShiny = "false",
      GameState = json.encode(gameState),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local collection = response.eventSpeciesCollection

    assert(collection.totalEncounters == 2, "Should have 2 total encounters")
    assert(collection.uniqueSpecies == 1, "Should still have 1 unique species")
    assert(collection.speciesEncountered.GIMMIGHOUL.count == 2, "Gimmighoul count should be 2")
  end)

  -- Test: TrackEventSpeciesEncounter tracks shiny encounters
  it("should track shiny encounters correctly", function()
    local gameState = {
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

    local msg = {
      Action = "TrackEventSpeciesEncounter",
      SpeciesId = "GIMMIGHOUL",
      FormIndex = "0",
      IsShiny = "true",
      GameState = json.encode(gameState),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local collection = response.eventSpeciesCollection

    assert(collection.shinyEncounters == 1, "Should have 1 shiny encounter")
    assert(collection.speciesEncountered.GIMMIGHOUL.shinyCount == 1, "Gimmighoul should have 1 shiny")
  end)

  -- Test: TrackEventSpeciesEncounter tracks multiple forms
  it("should track multiple forms for same species", function()
    local gameState = {
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

    local msg = {
      Action = "TrackEventSpeciesEncounter",
      SpeciesId = "PIKACHU",
      FormIndex = "1", -- Partner form
      IsShiny = "false",
      GameState = json.encode(gameState),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local pikachu = response.eventSpeciesCollection.speciesEncountered.PIKACHU

    assert(#pikachu.formsSeen == 2, "Should have 2 forms seen")
    assert(pikachu.formsSeen[1] == 0 or pikachu.formsSeen[1] == 1, "Should have form 0 or 1")
    assert(pikachu.formsSeen[2] == 0 or pikachu.formsSeen[2] == 1, "Should have form 0 or 1")
  end)

  -- Test: TrackEventSpeciesEncounter adds new species
  it("should add new unique species to collection", function()
    local gameState = {
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

    local msg = {
      Action = "TrackEventSpeciesEncounter",
      SpeciesId = "DELIBIRD",
      FormIndex = "0",
      IsShiny = "false",
      GameState = json.encode(gameState),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local collection = response.eventSpeciesCollection

    assert(collection.uniqueSpecies == 2, "Should have 2 unique species")
    assert(collection.totalEncounters == 3, "Should have 3 total encounters")
    assert(collection.speciesEncountered.DELIBIRD, "Should have Delibird entry")
    assert(collection.speciesEncountered.DELIBIRD.count == 1, "Delibird count should be 1")
  end)

  -- Test: TrackEventSpeciesEncounter handles missing FormIndex
  it("should default to form 0 when FormIndex missing", function()
    local msg = {
      Action = "TrackEventSpeciesEncounter",
      SpeciesId = "GIMMIGHOUL",
      IsShiny = "false",
      GameState = "",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local gimmighoul = response.eventSpeciesCollection.speciesEncountered.GIMMIGHOUL

    assert(gimmighoul.formsSeen[1] == 0, "Should default to form 0")
  end)

  -- Test: TrackEventSpeciesEncounter error handling
  it("should return error when SpeciesId missing", function()
    local msg = {
      Action = "TrackEventSpeciesEncounter",
      FormIndex = "0",
      IsShiny = "false",
      GameState = "",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result.Action == "Error", "Should return error")
    assert(string.match(result.Error, "Missing SpeciesId"), "Error should mention missing SpeciesId")
  end)

  -- Test: GetEventSpeciesProgress returns empty collection for no encounters
  it("should return empty collection when no encounters", function()
    local msg = {
      Action = "GetEventSpeciesProgress",
      GameState = "",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local collection = response.eventSpeciesCollection

    assert(collection.totalEncounters == 0, "Should have 0 total encounters")
    assert(collection.uniqueSpecies == 0, "Should have 0 unique species")
    assert(collection.shinyEncounters == 0, "Should have 0 shiny encounters")
  end)

  -- Test: GetEventSpeciesProgress returns existing collection
  it("should return existing collection from game state", function()
    local gameState = {
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

    local msg = {
      Action = "GetEventSpeciesProgress",
      GameState = json.encode(gameState),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local collection = response.eventSpeciesCollection

    assert(collection.totalEncounters == 15, "Should have 15 total encounters")
    assert(collection.uniqueSpecies == 8, "Should have 8 unique species")
    assert(collection.shinyEncounters == 2, "Should have 2 shiny encounters")
    assert(collection.speciesEncountered.GIMMIGHOUL.count == 3, "Gimmighoul should have 3 encounters")
    assert(collection.speciesEncountered.PIKACHU.shinyCount == 1, "Pikachu should have 1 shiny")
  end)

  -- Test: Complex multi-species collection scenario
  it("should correctly track complex multi-species collection", function()
    local gameState = {
      eventSpeciesCollection = {
        totalEncounters = 0,
        uniqueSpecies = 0,
        shinyEncounters = 0,
        speciesEncountered = {}
      }
    }

    -- Track 5 different species with varying counts
    local encounters = {
      {species = "GIMMIGHOUL", shiny = false},
      {species = "GIMMIGHOUL", shiny = true},
      {species = "DELIBIRD", shiny = false},
      {species = "PIKACHU", shiny = false},
      {species = "GIMMIGHOUL", shiny = false},
      {species = "DELIBIRD", shiny = true},
      {species = "STANTLER", shiny = false}
    }

    for _, encounter in ipairs(encounters) do
      local msg = {
        Action = "TrackEventSpeciesEncounter",
        SpeciesId = encounter.species,
        FormIndex = "0",
        IsShiny = tostring(encounter.shiny),
        GameState = json.encode(gameState),
        From = "test-sender"
      }

      local result = aolite.send(process, msg)
      local response = json.decode(result.Data)
      gameState.eventSpeciesCollection = response.eventSpeciesCollection
    end

    local collection = gameState.eventSpeciesCollection

    assert(collection.totalEncounters == 7, "Should have 7 total encounters")
    assert(collection.uniqueSpecies == 4, "Should have 4 unique species")
    assert(collection.shinyEncounters == 2, "Should have 2 shiny encounters")
    assert(collection.speciesEncountered.GIMMIGHOUL.count == 3, "Gimmighoul should have 3 encounters")
    assert(collection.speciesEncountered.GIMMIGHOUL.shinyCount == 1, "Gimmighoul should have 1 shiny")
    assert(collection.speciesEncountered.DELIBIRD.count == 2, "Delibird should have 2 encounters")
    assert(collection.speciesEncountered.PIKACHU.count == 1, "Pikachu should have 1 encounter")
    assert(collection.speciesEncountered.STANTLER.count == 1, "Stantler should have 1 encounter")
  end)
end)

print("Event Species Collection tests completed")
