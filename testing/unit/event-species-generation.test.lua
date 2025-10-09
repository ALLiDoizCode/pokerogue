--[[
  Event Species Generation Unit Tests

  Tests event species spawn logic, probability calculations, and deterministic RNG.
  Validates 50% spawn probability and event species selection algorithms.
]]

local aolite = require("aolite")
local json = require("json")

-- Load the seasonal event engine process
local processPath = "processes/seasonal-event-engine.lua"
local process = aolite.spawnProcess(processPath)

-- Test suite
describe("Event Species Generation", function()

  -- Test: GetEventSpecies handler returns event species for active event
  it("should return event species for Winter Holiday event", function()
    -- Winter Holiday: Dec 21, 2024 - Jan 4, 2025
    local timestamp = 1734739200 + 86400 -- Dec 22, 2024

    local msg = {
      Action = "GetEventSpecies",
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result, "Handler should return a result")

    local response = json.decode(result.Data)
    assert(response.eventSpecies, "Should return eventSpecies array")
    assert(#response.eventSpecies > 0, "Should have event species for Winter Holiday")
    assert(response.spawnProbability == 0.5, "Spawn probability should be 50%")
    assert(response.shinyReroll == true, "Event species should get shiny reroll")

    -- Verify specific Winter Holiday species are present
    local hasGimmighoul = false
    local hasDelibird = false
    for _, encounter in ipairs(response.eventSpecies) do
      if encounter.species == "GIMMIGHOUL" then
        hasGimmighoul = true
        assert(encounter.blockEvolution == true, "Gimmighoul should have evolution blocked")
      end
      if encounter.species == "DELIBIRD" then
        hasDelibird = true
      end
    end
    assert(hasGimmighoul, "Winter Holiday should include Gimmighoul")
    assert(hasDelibird, "Winter Holiday should include Delibird")
  end)

  -- Test: GetEventSpecies returns empty for no active events
  it("should return empty event species when no events active", function()
    local timestamp = 1609459200 -- Jan 1, 2021 (before any events)

    local msg = {
      Action = "GetEventSpecies",
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)

    assert(#response.eventSpecies == 0, "Should return empty array when no events active")
    assert(#response.activeEvents == 0, "Should have no active events")
  end)

  -- Test: CheckEventSpeciesAvailability validates species
  it("should validate Gimmighoul availability during Winter Holiday", function()
    local timestamp = 1734739200 + 86400 -- Dec 22, 2024

    local msg = {
      Action = "CheckEventSpeciesAvailability",
      SpeciesId = "GIMMIGHOUL",
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)

    assert(response.available == true, "Gimmighoul should be available during Winter Holiday")
    assert(response.eventName == "Winter Holiday Update", "Should return event name")
    assert(response.blockEvolution == true, "Gimmighoul evolution should be blocked")
    assert(response.formIndex == nil or response.formIndex == json.null, "Gimmighoul should not have form index")
  end)

  -- Test: CheckEventSpeciesAvailability returns false for non-event species
  it("should return false for non-event species", function()
    local timestamp = 1734739200 + 86400 -- Dec 22, 2024

    local msg = {
      Action = "CheckEventSpeciesAvailability",
      SpeciesId = "PIKACHU",
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)

    assert(response.available == false, "Pikachu should not be event species during Winter Holiday")
  end)

  -- Test: GenerateEventSpecies with deterministic 50% probability
  it("should generate event species with 50% probability (seed=12345 -> event)", function()
    local timestamp = 1734739200 + 86400 -- Dec 22, 2024
    local seed = 12345 -- Known seed that selects event species (odd result)

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      IsBoss = "false",
      RerollHidden = "false",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local pokemon = response.speciesGenerated

    assert(pokemon, "Should return generated pokemon")
    assert(pokemon.isEventEncounter == true, "Should be event encounter for this seed")
    assert(pokemon.species, "Should have species ID")
    assert(pokemon.level == 25, "Should have correct level")
    assert(pokemon.shinyRerolled == true, "Event species should get shiny reroll")
    assert(pokemon.hiddenAbilityRerolled == false, "Hidden ability reroll should be false")
    assert(pokemon.seed == seed, "Should preserve original seed")
  end)

  -- Test: GenerateEventSpecies returns regular species indicator for 50% other half
  it("should return regular species indicator with 50% probability (seed=12346 -> regular)", function()
    local timestamp = 1734739200 + 86400 -- Dec 22, 2024
    local seed = 12346 -- Known seed that selects regular species (even result)

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "30",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      IsBoss = "true",
      RerollHidden = "true",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local pokemon = response.speciesGenerated

    assert(pokemon.isEventEncounter == false, "Should not be event encounter for this seed")
    assert(pokemon.useRegularSpecies == true, "Should indicate regular species")
    assert(pokemon.reason, "Should provide reason for regular species selection")
  end)

  -- Test: GenerateEventSpecies returns regular species when no events active
  it("should return regular species indicator when no events active", function()
    local timestamp = 1609459200 -- Jan 1, 2021 (before any events)
    local seed = 12345

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local pokemon = response.speciesGenerated

    assert(pokemon.useRegularSpecies == true, "Should use regular species when no events")
    assert(pokemon.reason == "No active events", "Should provide correct reason")
  end)

  -- Test: GenerateEventSpecies validates level range
  it("should reject invalid level (level = 0)", function()
    local timestamp = 1734739200 + 86400
    local seed = 12345

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "0",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result.Action == "Error", "Should return error for level 0")
    assert(string.match(result.Error, "Level must be between 1 and 100"), "Error should mention level range")
  end)

  it("should reject invalid level (level = 101)", function()
    local timestamp = 1734739200 + 86400
    local seed = 12345

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "101",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result.Action == "Error", "Should return error for level 101")
    assert(string.match(result.Error, "Level must be between 1 and 100"), "Error should mention level range")
  end)

  -- Test: GenerateEventSpecies preserves boss and reroll flags
  it("should preserve isBoss and rerollHidden flags", function()
    local timestamp = 1734739200 + 86400
    local seed = 12345 -- Event species seed

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "50",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      IsBoss = "true",
      RerollHidden = "true",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local pokemon = response.speciesGenerated

    if pokemon.isEventEncounter then
      assert(pokemon.isBoss == true, "Should preserve boss flag")
      assert(pokemon.hiddenAbilityRerolled == true, "Should preserve hidden ability reroll flag")
    end
  end)

  -- Test: GenerateEventSpecies preserves form index and evolution blocking
  it("should preserve form index and evolution blocking from encounter", function()
    local timestamp = 1734739200 + 86400
    local seed = 12345 -- Event species seed

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    local response = json.decode(result.Data)
    local pokemon = response.speciesGenerated

    if pokemon.isEventEncounter then
      -- blockEvolution should match event encounter
      assert(type(pokemon.blockEvolution) == "boolean", "Should have blockEvolution flag")

      -- If Gimmighoul, should have blockEvolution = true
      if pokemon.species == "GIMMIGHOUL" then
        assert(pokemon.blockEvolution == true, "Gimmighoul should have evolution blocked")
      end
    end
  end)

  -- Test: Deterministic RNG produces consistent results
  it("should produce consistent results for same seed", function()
    local timestamp = 1734739200 + 86400
    local seed = 99999

    local msg1 = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local msg2 = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Seed = tostring(seed),
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result1 = aolite.send(process, msg1)
    local result2 = aolite.send(process, msg2)

    local response1 = json.decode(result1.Data)
    local response2 = json.decode(result2.Data)

    -- Should produce identical results
    assert(response1.speciesGenerated.isEventEncounter == response2.speciesGenerated.isEventEncounter,
           "Same seed should produce same event/regular decision")

    if response1.speciesGenerated.isEventEncounter then
      assert(response1.speciesGenerated.species == response2.speciesGenerated.species,
             "Same seed should select same event species")
    end
  end)

  -- Test: Error handling for missing parameters
  it("should return error when Level is missing", function()
    local timestamp = 1734739200 + 86400

    local msg = {
      Action = "GenerateEventSpecies",
      Seed = "12345",
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result.Action == "Error", "Should return error")
    assert(string.match(result.Error, "Missing required parameters"), "Error should mention missing parameters")
  end)

  it("should return error when Seed is missing", function()
    local timestamp = 1734739200 + 86400

    local msg = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Timestamp = tostring(timestamp),
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result.Action == "Error", "Should return error")
    assert(string.match(result.Error, "Missing required parameters"), "Error should mention missing parameters")
  end)

  it("should return error when Timestamp is missing", function()
    local msg = {
      Action = "GenerateEventSpecies",
      Level = "25",
      Seed = "12345",
      From = "test-sender"
    }

    local result = aolite.send(process, msg)
    assert(result.Action == "Error", "Should return error")
    assert(string.match(result.Error, "Missing required parameters"), "Error should mention missing parameters")
  end)
end)

print("Event Species Generation tests completed")
