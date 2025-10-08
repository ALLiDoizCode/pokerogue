-- ============================================================================
-- Special Event Encounters Tests
-- ============================================================================
-- Tests event encounter aggregation, mystery encounter changes, music, and species luck
-- Framework: aolite
-- ============================================================================

local aolite = require("aolite")

-- Load the special event engine process
local processPath = "processes/special-event-engine.lua"

describe("Special Event Encounters Tests", function()
  local processId

  before_each(function()
    processId = aolite.spawnProcess(processPath)
  end)

  after_each(function()
    processId = nil
  end)

  it("should retrieve event encounters during Winter Holiday", function()
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEncounters",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("SaveState", result.Action)
    assert.are.equal("true", result.Success)
    assert.are.equal("20", result.EncounterCount)

    local json = require("json")
    local encounters = json.decode(result.Data)
    assert.are.equal(20, #encounters)

    -- Verify GIMMIGHOUL has blockEvolution
    assert.are.equal(1002, encounters[1].species)
    assert.is_true(encounters[1].blockEvolution)
  end)

  it("should return empty encounters when no event active", function()
    local testTime = 1736553600000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEncounters",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("0", result.EncounterCount)
  end)

  it("should retrieve mystery encounter tier changes", function()
    -- Winter Holiday has mysteryEncounterTierChanges
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetMysteryEncounterChanges",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("SaveState", result.Action)
    assert.are.equal("5", result.ChangeCount)

    local json = require("json")
    local changes = json.decode(result.Data)
    assert.are.equal(5, #changes)

    -- Verify DELIBIRDY tier change
    assert.are.equal(0, changes[1].mysteryEncounter)
    assert.are.equal(0, changes[1].tier)

    -- Verify disabled encounters
    assert.is_true(changes[2].disable)
  end)

  it("should return empty mystery encounter changes when not set", function()
    -- April Fools has no mysteryEncounterTierChanges
    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetMysteryEncounterChanges",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("0", result.ChangeCount)
  end)

  it("should retrieve music replacement for April Fools", function()
    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventMusicReplacement",
      BgmKey = "title",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("SaveState", result.Action)
    assert.are.equal("title_afd", result.ReplacementBgm)
  end)

  it("should return original BGM when no replacement", function()
    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventMusicReplacement",
      BgmKey = "some_other_bgm",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("some_other_bgm", result.ReplacementBgm)
  end)

  it("should error when BgmKey missing", function()
    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventMusicReplacement",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("Error", result.Action)
    assert.are.equal("BgmKey parameter required", result.Error)
  end)

  it("should check species luck boost for Year of the Snake", function()
    local testTime = 1738368000000

    -- EKANS (23) is luck boosted
    local result = aolite.send({
      Target = processId,
      Action = "CheckSpeciesLuckBoost",
      SpeciesId = "23",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("SaveState", result.Action)
    assert.are.equal("true", result.HasLuckBoost)
    assert.are.equal("1", result.LuckBoost)
  end)

  it("should return false for non-luck-boosted species", function()
    local testTime = 1738368000000

    -- PIKACHU (25) is not luck boosted during Year of the Snake
    local result = aolite.send({
      Target = processId,
      Action = "CheckSpeciesLuckBoost",
      SpeciesId = "25",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("false", result.HasLuckBoost)
    assert.are.equal("0", result.LuckBoost)
  end)

  it("should error when SpeciesId missing", function()
    local testTime = 1738368000000

    local result = aolite.send({
      Target = processId,
      Action = "CheckSpeciesLuckBoost",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("Error", result.Action)
    assert.are.equal("SpeciesId parameter required", result.Error)
  end)

  it("should retrieve event challenges for April Fools", function()
    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventChallenges",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("SaveState", result.Action)
    assert.are.equal("1", result.ChallengeCount)

    local json = require("json")
    local challenges = json.decode(result.Data)
    assert.are.equal(1, #challenges)
    assert.are.equal(0, challenges[1].challenge) -- INVERSE_BATTLE
    assert.are.equal(1, challenges[1].value)
  end)

  it("should return empty challenges when not set", function()
    -- Winter Holiday has no dailyRunChallenges
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventChallenges",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("0", result.ChallengeCount)
  end)

  it("should validate event participation when event active", function()
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "ValidateEventParticipation",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("SaveState", result.Action)
    assert.are.equal("true", result.Eligible)
    assert.are.equal("Event is active", result.Reason)
  end)

  it("should validate event participation when no event active", function()
    local testTime = 1736553600000

    local result = aolite.send({
      Target = processId,
      Action = "ValidateEventParticipation",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("false", result.Eligible)
    assert.are.equal("No active event", result.Reason)
  end)

  it("should handle PKMNDAY2025 luck boosted species", function()
    local testTime = 1740873600000

    -- PIKACHU (25) is luck boosted during PKMNDAY2025
    local result = aolite.send({
      Target = processId,
      Action = "CheckSpeciesLuckBoost",
      SpeciesId = "25",
      CurrentTime = tostring(testTime)
    })

    -- PKMNDAY2025 is LUCK event but has no luckBoost value (only luckBoostedSpecies)
    assert.are.equal("false", result.HasLuckBoost)
    assert.are.equal("0", result.LuckBoost)
  end)

  it("should handle Valentine luck boosted species", function()
    local testTime = 1739664000000

    -- LUVDISC (370) is luck boosted
    local result = aolite.send({
      Target = processId,
      Action = "CheckSpeciesLuckBoost",
      SpeciesId = "370",
      CurrentTime = tostring(testTime)
    })

    -- Valentine has luckBoostedSpecies but no luckBoost value
    assert.are.equal("false", result.HasLuckBoost)
    assert.are.equal("0", result.LuckBoost)
  end)
end)
