-- Integration Tests for Biome Progression Engine
-- Tests cross-process coordination and complete biome progression workflows

local aos = require("aos-local")
local json = require("json")

print("Setting up Biome Progression Engine integration tests...")

-- Spawn processes
local biomeEngineId = aos.spawn("biome-progression-engine", "../processes/biome-progression-engine.lua")
assert(biomeEngineId, "Failed to spawn biome-progression-engine")

print("Biome Engine Process ID: " .. biomeEngineId)

-- Helper to send message and wait for response
local function sendAndWait(processId, msg)
    aos.send(processId, msg)
    aos.runScheduler()
    return aos.getAllMsgs({To = msg.From, From = processId})
end

-- ============================================================================
-- TEST SUITE 1: Complete Biome Selection Workflow
-- ============================================================================

print("\n=== TEST SUITE 1: Complete Biome Selection Workflow ===")

local function testCompleteSelectionWorkflow()
    print("Test 1.1: End-to-end biome selection and transition")

    -- Step 1: Select next biome from TOWN
    local selectMsg = {
        From = "coordinator_001",
        Action = "SelectNextBiome",
        PlayerId = "player_integration_001",
        CurrentBiome = "0",  -- TOWN
        CurrentWaveIndex = "10",
        GameMode = "classic",
        HasMapModifier = "false",
        Seed = "12345",
        Timestamp = os.time() * 1000
    }

    local selectResults = sendAndWait(biomeEngineId, selectMsg)
    assert(#selectResults > 0, "Should receive selection response")

    local selectionResponse = selectResults[1]
    assert(selectionResponse.Action == "BiomeSelected", "Should return BiomeSelected")
    assert(selectionResponse.NextBiome == "1", "Should select PLAINS")

    print("  ✓ Biome selection completed")

    -- Step 2: Execute biome transition
    local transitionMsg = {
        From = "coordinator_001",
        Action = "ExecuteBiomeTransition",
        PlayerId = "player_integration_001",
        FromBiome = "0",
        ToBiome = selectionResponse.NextBiome,
        WaveIndex = "10",
        Timestamp = os.time() * 1000
    }

    local transitionResults = sendAndWait(biomeEngineId, transitionMsg)
    assert(#transitionResults > 0, "Should receive transition response")

    local transitionResponse = transitionResults[1]
    assert(transitionResponse.Action == "BiomeTransitioned", "Should return BiomeTransitioned")
    assert(transitionResponse.Success == "true", "Transition should succeed")
    assert(transitionResponse.FirstVisit == "true", "Should be first visit")

    print("  ✓ Biome transition completed")

    -- Step 3: Verify state update
    local stateMsg = {
        From = "coordinator_001",
        Action = "GetPlayerBiomeState",
        PlayerId = "player_integration_001",
        IncludeHistory = "true",
        Timestamp = os.time() * 1000
    }

    local stateResults = sendAndWait(biomeEngineId, stateMsg)
    assert(#stateResults > 0, "Should receive state response")

    local stateResponse = stateResults[1]
    local stateData = json.decode(stateResponse.Data)
    assert(stateData.currentBiome == 1, "Current biome should be PLAINS")
    assert(stateData.totalBiomesUnlocked >= 2, "Should have unlocked TOWN and PLAINS")

    print("  ✓ State verification completed")
    print("✓ Complete workflow test passed")
end

testCompleteSelectionWorkflow()

-- ============================================================================
-- TEST SUITE 2: Map Modifier Player Choice Workflow
-- ============================================================================

print("\n=== TEST SUITE 2: Map Modifier Player Choice Workflow ===")

local function testMapModifierWorkflow()
    print("Test 2.1: Map modifier enables player biome choice")

    -- Step 1: Select with Map modifier from PLAINS (3 options)
    local selectMsg = {
        From = "coordinator_002",
        Action = "SelectNextBiome",
        PlayerId = "player_integration_002",
        CurrentBiome = "1",  -- PLAINS
        CurrentWaveIndex = "20",
        GameMode = "classic",
        HasMapModifier = "true",
        Seed = "54321",
        Timestamp = os.time() * 1000
    }

    local selectResults = sendAndWait(biomeEngineId, selectMsg)
    local selectionResponse = selectResults[1]

    assert(selectionResponse.RequiresPlayerChoice == "true", "Should require player choice")

    local availableBiomes = json.decode(selectionResponse.AvailableBiomes)
    assert(#availableBiomes >= 2, "Should have multiple options")

    print("  ✓ Player choice enabled with " .. #availableBiomes .. " options")

    -- Step 2: Validate player can choose any available biome
    for _, biomeId in ipairs(availableBiomes) do
        local validateMsg = {
            From = "coordinator_002",
            Action = "ValidateBiomeAccess",
            PlayerId = "player_integration_002",
            BiomeId = tostring(biomeId),
            CurrentBiome = "1",
            WaveIndex = "20",
            Timestamp = os.time() * 1000
        }

        local validateResults = sendAndWait(biomeEngineId, validateMsg)
        local validateResponse = validateResults[1]

        assert(validateResponse.Accessible == "true", "Available biome should be accessible")
        assert(validateResponse.IsLinked == "true", "Should be linked")
    end

    print("  ✓ All available biomes validated")

    -- Step 3: Execute transition to player-chosen biome
    local chosenBiome = availableBiomes[1]
    local transitionMsg = {
        From = "coordinator_002",
        Action = "ExecuteBiomeTransition",
        PlayerId = "player_integration_002",
        FromBiome = "1",
        ToBiome = tostring(chosenBiome),
        WaveIndex = "20",
        Timestamp = os.time() * 1000
    }

    local transitionResults = sendAndWait(biomeEngineId, transitionMsg)
    local transitionResponse = transitionResults[1]

    assert(transitionResponse.Success == "true", "Player choice transition should succeed")

    print("  ✓ Player choice transition completed")
    print("✓ Map modifier workflow test passed")
end

testMapModifierWorkflow()

-- ============================================================================
-- TEST SUITE 3: Multi-Biome Progression Chain
-- ============================================================================

print("\n=== TEST SUITE 3: Multi-Biome Progression Chain ===")

local function testProgressionChain()
    print("Test 3.1: TOWN -> PLAINS -> GRASS -> TALL_GRASS chain")

    local playerId = "player_integration_003"
    local biomeChain = {
        {from = 0, to = 1, wave = 10, name = "TOWN -> PLAINS"},
        {from = 1, to = 2, wave = 20, name = "PLAINS -> GRASS"},
        {from = 2, to = 3, wave = 30, name = "GRASS -> TALL_GRASS"}
    }

    for _, step in ipairs(biomeChain) do
        -- Select next biome
        local selectMsg = {
            From = "coordinator_003",
            Action = "SelectNextBiome",
            PlayerId = playerId,
            CurrentBiome = tostring(step.from),
            CurrentWaveIndex = tostring(step.wave),
            GameMode = "classic",
            HasMapModifier = "false",
            Timestamp = os.time() * 1000
        }

        local selectResults = sendAndWait(biomeEngineId, selectMsg)
        local selectionResponse = selectResults[1]

        -- For multi-path, just verify we get a valid selection
        local nextBiome = tonumber(selectionResponse.NextBiome)
        assert(nextBiome, "Should select a next biome")

        -- Execute transition
        local transitionMsg = {
            From = "coordinator_003",
            Action = "ExecuteBiomeTransition",
            PlayerId = playerId,
            FromBiome = tostring(step.from),
            ToBiome = tostring(nextBiome),
            WaveIndex = tostring(step.wave),
            Timestamp = os.time() * 1000
        }

        local transitionResults = sendAndWait(biomeEngineId, transitionMsg)
        local transitionResponse = transitionResults[1]

        assert(transitionResponse.Success == "true", step.name .. " transition should succeed")

        print("  ✓ " .. step.name .. " completed")
    end

    -- Verify final state
    local stateMsg = {
        From = "coordinator_003",
        Action = "GetPlayerBiomeState",
        PlayerId = playerId,
        IncludeHistory = "true",
        Timestamp = os.time() * 1000
    }

    local stateResults = sendAndWait(biomeEngineId, stateMsg)
    local stateData = json.decode(stateResults[1].Data)

    assert(stateData.totalBiomesUnlocked >= 3, "Should have unlocked at least 3 biomes")
    assert(#stateData.biomeHistory >= 3, "Should have 3 history entries")

    print("  ✓ Progression chain state verified")
    print("✓ Multi-biome progression test passed")
end

testProgressionChain()

-- ============================================================================
-- TEST SUITE 4: END Biome Progression
-- ============================================================================

print("\n=== TEST SUITE 4: END Biome Progression ===")

local function testEndBiomeProgression()
    print("Test 4.1: Complete progression to END biome at wave 50")

    local playerId = "player_integration_004"

    -- Progress to wave 49
    local transitionMsg1 = {
        From = "coordinator_004",
        Action = "ExecuteBiomeTransition",
        PlayerId = playerId,
        FromBiome = "0",
        ToBiome = "1",
        WaveIndex = "40",
        Timestamp = os.time() * 1000
    }

    sendAndWait(biomeEngineId, transitionMsg1)

    -- Select next biome at wave 50
    local selectMsg = {
        From = "coordinator_004",
        Action = "SelectNextBiome",
        PlayerId = playerId,
        CurrentBiome = "1",
        CurrentWaveIndex = "50",
        GameMode = "classic",
        HasMapModifier = "false",
        Timestamp = os.time() * 1000
    }

    local selectResults = sendAndWait(biomeEngineId, selectMsg)
    local selectionResponse = selectResults[1]

    assert(selectionResponse.NextBiome == "50", "Wave 50 should select END biome")
    assert(selectionResponse.TransitionType == "end_biome", "Should be end_biome type")

    print("  ✓ END biome selected at wave 50")

    -- Execute END biome transition
    local transitionMsg2 = {
        From = "coordinator_004",
        Action = "ExecuteBiomeTransition",
        PlayerId = playerId,
        FromBiome = "1",
        ToBiome = "50",
        WaveIndex = "50",
        Timestamp = os.time() * 1000
    }

    local transitionResults = sendAndWait(biomeEngineId, transitionMsg2)
    local transitionResponse = transitionResults[1]

    assert(transitionResponse.Success == "true", "END transition should succeed")
    assert(transitionResponse.IsFinalBiome == "true", "Should be final biome")
    assert(transitionResponse.BiomeName == "End", "Should be END biome")

    print("  ✓ END biome transition completed")
    print("✓ END biome progression test passed")
end

testEndBiomeProgression()

-- ============================================================================
-- TEST SUITE 5: State Persistence and Recovery
-- ============================================================================

print("\n=== TEST SUITE 5: State Persistence and Recovery ===")

local function testStatePersistence()
    print("Test 5.1: Player state persists across multiple operations")

    local playerId = "player_integration_005"

    -- Create initial state
    local transitionMsg1 = {
        From = "coordinator_005",
        Action = "ExecuteBiomeTransition",
        PlayerId = playerId,
        FromBiome = "0",
        ToBiome = "1",
        WaveIndex = "10",
        Timestamp = 5000000
    }

    sendAndWait(biomeEngineId, transitionMsg1)

    -- Query state
    local stateMsg1 = {
        From = "coordinator_005",
        Action = "GetPlayerBiomeState",
        PlayerId = playerId,
        IncludeHistory = "true",
        Timestamp = os.time() * 1000
    }

    local stateResults1 = sendAndWait(biomeEngineId, stateMsg1)
    local state1 = json.decode(stateResults1[1].Data)
    local firstUnlockTime = state1.unlockedBiomes["1"]

    assert(firstUnlockTime, "PLAINS should be unlocked")

    -- Add another transition
    local transitionMsg2 = {
        From = "coordinator_005",
        Action = "ExecuteBiomeTransition",
        PlayerId = playerId,
        FromBiome = "1",
        ToBiome = "2",
        WaveIndex = "20",
        Timestamp = 5000001
    }

    sendAndWait(biomeEngineId, transitionMsg2)

    -- Query state again
    local stateResults2 = sendAndWait(biomeEngineId, stateMsg1)
    local state2 = json.decode(stateResults2[1].Data)

    assert(state2.unlockedBiomes["1"] == firstUnlockTime, "PLAINS unlock time should persist")
    assert(state2.unlockedBiomes["2"], "GRASS should now be unlocked")
    assert(state2.totalBiomesUnlocked > state1.totalBiomesUnlocked, "Total unlocked should increase")

    print("  ✓ State persistence verified")
    print("✓ State persistence test passed")
end

testStatePersistence()

-- ============================================================================
-- TEST SUITE 6: Error Handling Integration
-- ============================================================================

print("\n=== TEST SUITE 6: Error Handling Integration ===")

local function testErrorHandling()
    print("Test 6.1: Invalid transition chain is rejected")

    local playerId = "player_integration_006"

    -- Try to transition from TOWN directly to END (invalid)
    local invalidTransitionMsg = {
        From = "coordinator_006",
        Action = "ExecuteBiomeTransition",
        PlayerId = playerId,
        FromBiome = "0",
        ToBiome = "50",
        WaveIndex = "10",
        Timestamp = os.time() * 1000
    }

    local results = sendAndWait(biomeEngineId, invalidTransitionMsg)
    local response = results[1]

    assert(response.Action == "Error", "Should return error for invalid transition")
    assert(response.Error, "Should provide error message")

    print("  ✓ Invalid transition rejected")

    -- Verify state was not corrupted
    local stateMsg = {
        From = "coordinator_006",
        Action = "GetPlayerBiomeState",
        PlayerId = playerId,
        IncludeHistory = "false",
        Timestamp = os.time() * 1000
    }

    local stateResults = sendAndWait(biomeEngineId, stateMsg)
    local stateData = json.decode(stateResults[1].Data)

    assert(stateData.currentBiome == 0, "Current biome should remain TOWN")

    print("  ✓ State integrity preserved after error")
    print("✓ Error handling test passed")
end

testErrorHandling()

-- ============================================================================
-- TEST SUITE 7: Concurrent Player Operations
-- ============================================================================

print("\n=== TEST SUITE 7: Concurrent Player Operations ===")

local function testConcurrentPlayers()
    print("Test 7.1: Multiple players can progress independently")

    local players = {"player_concurrent_001", "player_concurrent_002", "player_concurrent_003"}

    -- Each player makes initial transition
    for _, playerId in ipairs(players) do
        local transitionMsg = {
            From = "coordinator_007",
            Action = "ExecuteBiomeTransition",
            PlayerId = playerId,
            FromBiome = "0",
            ToBiome = "1",
            WaveIndex = "10",
            Timestamp = os.time() * 1000
        }

        local results = sendAndWait(biomeEngineId, transitionMsg)
        assert(results[1].Success == "true", "Each player transition should succeed")
    end

    print("  ✓ All players transitioned independently")

    -- Verify each player has independent state
    for _, playerId in ipairs(players) do
        local stateMsg = {
            From = "coordinator_007",
            Action = "GetPlayerBiomeState",
            PlayerId = playerId,
            IncludeHistory = "false",
            Timestamp = os.time() * 1000
        }

        local stateResults = sendAndWait(biomeEngineId, stateMsg)
        local stateData = json.decode(stateResults[1].Data)

        assert(stateData.currentBiome == 1, "Each player should be at PLAINS")
        assert(stateData.totalBiomesUnlocked >= 2, "Each player should have unlocks")
    end

    print("  ✓ All players have independent state")
    print("✓ Concurrent players test passed")
end

testConcurrentPlayers()

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("ALL INTEGRATION TESTS PASSED")
print("Biome Progression Engine integration tests completed successfully")
print(string.rep("=", 60))
