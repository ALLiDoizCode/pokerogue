-- Unit tests for mystery encounter requirement validation
-- Tests WaveRangeRequirement, PartySizeRequirement, and validation logic

local aolite = require("aolite")

-- Load the mystery encounter engine process
dofile("processes/mystery-encounter-engine.lua")

-- Test suite for requirement validation
aolite.describe("Mystery Encounter Requirements", function()

    aolite.it("WaveRangeRequirement - valid wave ranges", function()
        -- Test wave range validation for wave 50 (should pass 10-180 range)

        local encounterType = 3  -- FIGHT_OR_FLIGHT (wave range 10-180)

        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 50,
                party = {}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "true", "Expected valid for wave 50")
        aolite.assert(response.RequirementsFailed == "", "Expected no failed requirements")
    end)

    aolite.it("WaveRangeRequirement - invalid wave ranges (too early)", function()
        -- Test wave 5 is invalid for 10-180 range

        local encounterType = 3  -- FIGHT_OR_FLIGHT (wave range 10-180)

        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 5,
                party = {}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "false", "Expected invalid for wave 5")
        aolite.assert(string.find(response.RequirementsFailed, "WaveRange"), "Expected WaveRange in failed requirements")
    end)

    aolite.it("WaveRangeRequirement - invalid wave ranges (too late)", function()
        -- Test wave 200 is invalid for 10-180 range

        local encounterType = 3  -- FIGHT_OR_FLIGHT (wave range 10-180)

        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 200,
                party = {}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "false", "Expected invalid for wave 200")
    end)

    aolite.it("PartySizeRequirement - minimum party size validation", function()
        -- Test MYSTERIOUS_CHEST requires party size >= 2

        local encounterType = 1  -- MYSTERIOUS_CHEST (minSize: 2)

        -- Test with party size 3 (valid)
        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}, {id = 2}, {id = 3}}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "true", "Expected valid for party size 3")
    end)

    aolite.it("PartySizeRequirement - fails with insufficient party size", function()
        -- Test MYSTERIOUS_CHEST fails with party size 1

        local encounterType = 1  -- MYSTERIOUS_CHEST (minSize: 2)

        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}}  -- Only 1 Pokemon
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "false", "Expected invalid for party size 1")
        aolite.assert(string.find(response.RequirementsFailed, "PartySize"), "Expected PartySize in failed requirements")
    end)

    aolite.it("Multiple requirements - all must pass (AND logic)", function()
        -- Test DARK_DEAL requires wave range AND party size

        local encounterType = 2  -- DARK_DEAL (wave 30-180, minSize: 2)

        -- Test with wave 50, party size 3 (both valid)
        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}, {id = 2}, {id = 3}}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "true", "Expected valid when all requirements pass")
    end)

    aolite.it("Multiple requirements - fails if any requirement fails", function()
        -- Test DARK_DEAL fails if either requirement fails

        local encounterType = 2  -- DARK_DEAL (wave 30-180, minSize: 2)

        -- Test with wave 20 (invalid), party size 3 (valid)
        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 20,  -- Below minimum of 30
                party = {{id = 1}, {id = 2}, {id = 3}}
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(response.Valid == "false", "Expected invalid when one requirement fails")
        aolite.assert(string.find(response.RequirementsFailed, "WaveRange"), "Expected WaveRange in failed")
    end)

    aolite.it("Requirement details - provides passed and failed lists", function()
        -- Test that validation returns detailed requirement results

        local encounterType = 2  -- DARK_DEAL (wave 30-180, minSize: 2)

        local msg = {
            From = "test_player",
            Action = "ValidateEncounterRequirements",
            EncounterType = tostring(encounterType),
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}}  -- Party size fails
            })
        }

        local sentMessages = {}
        ao.send = function(response)
            table.insert(sentMessages, response)
        end

        Handlers._handlers["validate-encounter-requirements"].fn(msg)

        local response = sentMessages[1]
        aolite.assert(response.Success == "true", "Expected success")
        aolite.assert(string.find(response.RequirementsPassed, "WaveRange"), "Expected WaveRange passed")
        aolite.assert(string.find(response.RequirementsFailed, "PartySize"), "Expected PartySize failed")
    end)
end)

print("Mystery encounter requirements tests completed")
