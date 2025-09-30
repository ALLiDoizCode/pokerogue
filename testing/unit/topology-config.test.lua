-- Test file for processes/topology-config.lua
-- Tests topology configuration, process discovery, and ADP v1.0 compliance

local aolite = require("testing.aolite.aolite")

describe("Topology Configuration Process", function()
    local process

    before_each(function()
        -- Spawn process with topology-config code
        process = aolite.spawnProcess("processes/topology-config.lua")

        -- Set up mock timestamp
        process.mockTimestamp = 1234567890
    end)

    after_each(function()
        -- Cleanup
        process = nil
    end)

    describe("Handler: get-topology", function()
        it("should return complete topology structure", function()
            local result = process.send({
                Target = process.id,
                Action = "GetTopology",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.is_not_nil(result.Data)

            local topology = aolite.json.decode(result.Data)
            assert.is_not_nil(topology.dataLayer)
            assert.is_not_nil(topology.gameLogicLayer)
            assert.is_not_nil(topology.coordinationLayer)
        end)

        it("should include all data layer processes", function()
            local result = process.send({
                Target = process.id,
                Action = "GetTopology",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local topology = aolite.json.decode(result.Data)
            assert.is_not_nil(topology.dataLayer.player_data)
            assert.is_not_nil(topology.dataLayer.pokemon_data)
            assert.is_not_nil(topology.dataLayer.battle_data)
        end)
    end)

    describe("Handler: validate-process", function()
        it("should validate known process types", function()
            local result = process.send({
                Target = process.id,
                Action = "ValidateProcess",
                ProcessType = "battle_engine",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("ProcessValidation", result.Action)
            assert.equals("true", result.Valid)
        end)

        it("should reject unknown process types", function()
            local result = process.send({
                Target = process.id,
                Action = "ValidateProcess",
                ProcessType = "invalid_process_type",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("ProcessValidation", result.Action)
            assert.equals("false", result.Valid)
        end)

        it("should handle missing ProcessType parameter", function()
            local result = process.send({
                Target = process.id,
                Action = "ValidateProcess",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("Error", result.Action)
            assert.is_not_nil(result.Error)
        end)
    end)

    describe("Handler: get-process-metadata", function()
        it("should return metadata for known process", function()
            local result = process.send({
                Target = process.id,
                Action = "GetProcessMetadata",
                ProcessId = "battle_engine",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("ProcessMetadata", result.Action)
            assert.is_not_nil(result.Data)

            local metadata = aolite.json.decode(result.Data)
            assert.is_not_nil(metadata.name)
            assert.is_not_nil(metadata.type)
            assert.is_not_nil(metadata.capabilities)
        end)

        it("should handle unknown process ID", function()
            local result = process.send({
                Target = process.id,
                Action = "GetProcessMetadata",
                ProcessId = "nonexistent_process",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("Error", result.Action)
            assert.is_not_nil(result.Error)
        end)
    end)

    describe("Handler: discover-processes", function()
        it("should discover processes by capability", function()
            local result = process.send({
                Target = process.id,
                Action = "DiscoverProcesses",
                Capability = "calculate_damage",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("ProcessDiscovery", result.Action)
            assert.is_not_nil(result.Data)

            local discovered = aolite.json.decode(result.Data)
            assert.is_table(discovered.processes)
        end)

        it("should filter by process type", function()
            local result = process.send({
                Target = process.id,
                Action = "DiscoverProcesses",
                Type = "data",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("ProcessDiscovery", result.Action)

            local discovered = aolite.json.decode(result.Data)
            assert.is_true(#discovered.processes > 0)
        end)
    end)

    describe("Handler: health-check", function()
        it("should return healthy status", function()
            local result = process.send({
                Target = process.id,
                Action = "HealthCheck",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("HealthStatus", result.Action)
            assert.equals("healthy", result.Status)
        end)
    end)

    describe("Handler: info (ADP v1.0)", function()
        it("should return process information with ADP compliance", function()
            local result = process.send({
                Target = process.id,
                Action = "Info",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.is_not_nil(result.Data)

            local info = aolite.json.decode(result.Data)
            assert.is_not_nil(info.process)
            assert.equals("1.0", info.process.adpVersion)
            assert.is_not_nil(info.handlers)
            assert.is_table(info.handlers)
        end)

        it("should list all available handlers", function()
            local result = process.send({
                Target = process.id,
                Action = "Info",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local info = aolite.json.decode(result.Data)
            local handlerNames = {}
            for _, handler in ipairs(info.handlers) do
                handlerNames[handler] = true
            end

            assert.is_true(handlerNames["GetTopology"])
            assert.is_true(handlerNames["ValidateProcess"])
            assert.is_true(handlerNames["GetProcessMetadata"])
            assert.is_true(handlerNames["DiscoverProcesses"])
            assert.is_true(handlerNames["HealthCheck"])
            assert.is_true(handlerNames["Info"])
        end)

        it("should include message schemas", function()
            local result = process.send({
                Target = process.id,
                Action = "Info",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local info = aolite.json.decode(result.Data)
            assert.is_not_nil(info.process.messageSchemas)
            assert.is_table(info.process.messageSchemas)
        end)
    end)

    describe("Edge Cases", function()
        it("should handle malformed requests gracefully", function()
            local result = process.send({
                Target = process.id,
                Action = "GetTopology",
                Data = "invalid json {{{",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            assert.is_not_nil(result)
            -- Should still return topology or error, not crash
        end)

        it("should handle concurrent discovery requests", function()
            local results = {}
            for i = 1, 5 do
                results[i] = process.send({
                    Target = process.id,
                    Action = "DiscoverProcesses",
                    Type = "data",
                    From = "test-sender-" .. i,
                    Timestamp = process.mockTimestamp + i
                })
            end

            -- All requests should succeed
            for _, result in ipairs(results) do
                assert.is_not_nil(result)
                assert.equals("ProcessDiscovery", result.Action)
            end
        end)
    end)

    describe("State Management", function()
        it("should maintain consistent topology state", function()
            -- Request topology twice
            local result1 = process.send({
                Target = process.id,
                Action = "GetTopology",
                From = "test-sender",
                Timestamp = process.mockTimestamp
            })

            local result2 = process.send({
                Target = process.id,
                Action = "GetTopology",
                From = "test-sender",
                Timestamp = process.mockTimestamp + 100
            })

            -- Topology should be identical
            assert.equals(result1.Data, result2.Data)
        end)
    end)
end)
