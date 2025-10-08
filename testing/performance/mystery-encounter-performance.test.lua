-- Performance tests for mystery encounter engine
-- Tests execution time benchmarks for all handlers

local aolite = require("aolite")

-- Load the mystery encounter engine process
dofile("processes/mystery-encounter-engine.lua")

-- Helper function to measure execution time
local function measureExecutionTime(fn)
    local startTime = os.clock()
    fn()
    local endTime = os.clock()
    return (endTime - startTime) * 1000  -- Convert to milliseconds
end

-- Test suite for performance benchmarks
aolite.describe("Mystery Encounter Performance", function()

    aolite.it("SelectEncounter execution time < 10ms per call", function()
        -- Target: <10ms per encounter selection

        local executionTimes = {}

        for i = 1, 10 do
            local msg = {
                From = "test_player",
                Action = "SelectEncounter",
                BiomeId = "1",  -- PLAINS
                WaveIndex = "50",
                Seed = tostring(i)
            }

            local sentMessages = {}
            ao.send = function(response) table.insert(sentMessages, response) end

            local execTime = measureExecutionTime(function()
                Handlers._handlers["select-encounter"].fn(msg)
            end)

            table.insert(executionTimes, execTime)
        end

        -- Calculate average execution time
        local totalTime = 0
        for _, time in ipairs(executionTimes) do
            totalTime = totalTime + time
        end
        local avgTime = totalTime / #executionTimes

        print(string.format("SelectEncounter average: %.3f ms (max: %.3f ms)", avgTime, math.max(table.unpack(executionTimes))))
        aolite.assert(avgTime < 10, string.format("Average execution time %.3f ms exceeds 10ms target", avgTime))
    end)

    aolite.it("ValidateEncounterRequirements execution time < 5ms per call", function()
        -- Target: <5ms per validation

        local executionTimes = {}

        for encounterType = 0, 10 do
            local msg = {
                From = "test_player",
                Action = "ValidateEncounterRequirements",
                EncounterType = tostring(encounterType),
                Data = json.encode({
                    waveIndex = 50,
                    party = {{id = 1}, {id = 2}}
                })
            }

            local sentMessages = {}
            ao.send = function(response) table.insert(sentMessages, response) end

            local execTime = measureExecutionTime(function()
                Handlers._handlers["validate-encounter-requirements"].fn(msg)
            end)

            table.insert(executionTimes, execTime)
        end

        local totalTime = 0
        for _, time in ipairs(executionTimes) do
            totalTime = totalTime + time
        end
        local avgTime = totalTime / #executionTimes

        print(string.format("ValidateEncounterRequirements average: %.3f ms (max: %.3f ms)", avgTime, math.max(table.unpack(executionTimes))))
        aolite.assert(avgTime < 5, string.format("Average execution time %.3f ms exceeds 5ms target", avgTime))
    end)

    aolite.it("GetEncountersByBiome execution time < 5ms per call", function()
        -- Target: <5ms per biome query

        local executionTimes = {}

        for biomeId = 0, 10 do
            local msg = {
                From = "test_player",
                Action = "GetEncountersByBiome",
                BiomeId = tostring(biomeId)
            }

            local sentMessages = {}
            ao.send = function(response) table.insert(sentMessages, response) end

            local execTime = measureExecutionTime(function()
                Handlers._handlers["get-encounters-by-biome"].fn(msg)
            end)

            table.insert(executionTimes, execTime)
        end

        local totalTime = 0
        for _, time in ipairs(executionTimes) do
            totalTime = totalTime + time
        end
        local avgTime = totalTime / #executionTimes

        print(string.format("GetEncountersByBiome average: %.3f ms (max: %.3f ms)", avgTime, math.max(table.unpack(executionTimes))))
        aolite.assert(avgTime < 5, string.format("Average execution time %.3f ms exceeds 5ms target", avgTime))
    end)

    aolite.it("Batch selection: 100 encounters in < 500ms", function()
        -- Target: <500ms for 100 selections

        local msg = {
            From = "test_player",
            BiomeId = "1",
            WaveIndex = "50"
        }

        local sentMessages = {}
        ao.send = function(response) table.insert(sentMessages, response) end

        local execTime = measureExecutionTime(function()
            for i = 1, 100 do
                msg.Action = "SelectEncounter"
                msg.Seed = tostring(i)
                Handlers._handlers["select-encounter"].fn(msg)
            end
        end)

        print(string.format("Batch 100 encounters: %.3f ms (%.3f ms per encounter)", execTime, execTime / 100))
        aolite.assert(execTime < 500, string.format("Batch execution time %.3f ms exceeds 500ms target", execTime))
    end)

    aolite.it("GetEncounterProbabilities execution time < 10ms per call", function()
        -- Target: <10ms for probability calculation

        local executionTimes = {}

        for i = 1, 10 do
            local msg = {
                From = "test_player",
                Action = "GetEncounterProbabilities",
                BiomeId = "1",
                WaveIndex = "50",
                Data = json.encode({
                    waveIndex = 50,
                    party = {},
                    encountersCompleted = {}
                })
            }

            local sentMessages = {}
            ao.send = function(response) table.insert(sentMessages, response) end

            local execTime = measureExecutionTime(function()
                Handlers._handlers["get-encounter-probabilities"].fn(msg)
            end)

            table.insert(executionTimes, execTime)
        end

        local totalTime = 0
        for _, time in ipairs(executionTimes) do
            totalTime = totalTime + time
        end
        local avgTime = totalTime / #executionTimes

        print(string.format("GetEncounterProbabilities average: %.3f ms (max: %.3f ms)", avgTime, math.max(table.unpack(executionTimes))))
        aolite.assert(avgTime < 10, string.format("Average execution time %.3f ms exceeds 10ms target", avgTime))
    end)

    aolite.it("Process memory footprint: file size < 500KB", function()
        -- Verify process file size is well within AO 500KB limit

        local fileHandle = io.open("processes/mystery-encounter-engine.lua", "r")
        if fileHandle then
            local fileSize = fileHandle:seek("end")
            fileHandle:close()

            local fileSizeKB = fileSize / 1024
            print(string.format("Process file size: %.2f KB (%.1f%% of 500KB limit)", fileSizeKB, (fileSizeKB / 500) * 100))
            aolite.assert(fileSizeKB < 500, string.format("File size %.2f KB exceeds 500KB limit", fileSizeKB))
        else
            print("Warning: Could not measure file size")
        end
    end)
end)

print("Mystery encounter performance tests completed")
