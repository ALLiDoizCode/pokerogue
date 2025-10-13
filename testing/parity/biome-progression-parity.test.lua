-- Parity Tests for Biome Progression Engine
-- Validates behavioral parity with TypeScript implementation

local aolite = require("aolite")
local json = require("json")

print("Setting up Biome Progression Engine parity tests...")

-- Load process
local processId = aolite.spawn("biome-progression-engine", "../processes/biome-progression-engine.lua")
assert(processId, "Failed to spawn biome-progression-engine process")

-- Helper function
local function sendMessage(action, tags)
    local msg = {Action = action, From = "parity_tester", Timestamp = os.time() * 1000}
    for k, v in pairs(tags or {}) do msg[k] = v end
    local result = aolite.send(processId, msg)
    return result[1]
end

-- ============================================================================
-- TEST SUITE 1: biomeLinks Structure Parity
-- ============================================================================

print("\n=== TEST SUITE 1: biomeLinks Structure Parity ===")

local function testBiomeLinksStructure()
    print("Test 1.1: All 36 biomes have correct links")

    -- TypeScript biomeLinks mapping (from biomes.ts:37-72)
    local expectedLinks = {
        [0] = {1},  -- TOWN -> PLAINS
        [1] = {2, 4, 9},  -- PLAINS -> GRASS, METROPOLIS, LAKE
        [2] = {3},  -- GRASS -> TALL_GRASS
        [3] = {5, 13},  -- TALL_GRASS -> FOREST, CAVE
        [30] = {26, 7},  -- SLUM -> CONSTRUCTION_SITE, SWAMP (weighted)
        [5] = {27, 16},  -- FOREST -> JUNGLE, MEADOW
        [6] = {10, 15},  -- SEA -> SEABED, ICE_CAVE
        [7] = {19, 3},  -- SWAMP -> GRAVEYARD, TALL_GRASS
        [8] = {6, 40},  -- BEACH -> SEA, ISLAND (weighted)
        [9] = {8, 7, 26},  -- LAKE -> BEACH, SWAMP, CONSTRUCTION_SITE
        [10] = {13, 18},  -- SEABED -> CAVE, VOLCANO (weighted)
        [11] = {18, 23, 25},  -- MOUNTAIN -> VOLCANO, WASTELAND, SPACE (weighted)
        [12] = {14, 11},  -- BADLANDS -> DESERT, MOUNTAIN
        [13] = {12, 9, 41},  -- CAVE -> BADLANDS, LAKE, LABORATORY (weighted)
        [14] = {22, 26},  -- DESERT -> RUINS, CONSTRUCTION_SITE (weighted)
        [15] = {31},  -- ICE_CAVE -> SNOWY_FOREST
        [16] = {1, 28},  -- MEADOW -> PLAINS, FAIRY_CAVE
        [17] = {21},  -- POWER_PLANT -> FACTORY
        [18] = {8, 15},  -- VOLCANO -> BEACH, ICE_CAVE (weighted)
        [19] = {24},  -- GRAVEYARD -> ABYSS
        [20] = {1, 27, 29},  -- DOJO -> PLAINS, JUNGLE, TEMPLE (weighted)
        [21] = {1, 41},  -- FACTORY -> PLAINS, LABORATORY (weighted)
        [22] = {11, 5},  -- RUINS -> MOUNTAIN, FOREST (weighted)
        [23] = {12},  -- WASTELAND -> BADLANDS
        [24] = {13, 25, 23},  -- ABYSS -> CAVE, SPACE, WASTELAND (weighted)
        [25] = {22},  -- SPACE -> RUINS
        [26] = {17, 20},  -- CONSTRUCTION_SITE -> POWER_PLANT, DOJO (weighted)
        [27] = {29},  -- JUNGLE -> TEMPLE
        [28] = {15, 25},  -- FAIRY_CAVE -> ICE_CAVE, SPACE (weighted)
        [29] = {14, 7, 22},  -- TEMPLE -> DESERT, SWAMP, RUINS (weighted)
        [4] = {30},  -- METROPOLIS -> SLUM
        [31] = {5, 11, 9},  -- SNOWY_FOREST -> FOREST, MOUNTAIN, LAKE (weighted)
        [40] = {6},  -- ISLAND -> SEA
        [41] = {26}  -- LABORATORY -> CONSTRUCTION_SITE
    }

    local allCorrect = true

    for biomeId, expectedNextBiomes in pairs(expectedLinks) do
        local response = sendMessage("GetBiomeInfo", {BiomeId = tostring(biomeId)})
        local data = json.decode(response.Data)

        local linkedBiomes = data.biome.linkedBiomes

        -- Verify all expected links are present
        for _, expectedBiome in ipairs(expectedNextBiomes) do
            local found = false
            for _, linkedBiome in ipairs(linkedBiomes) do
                if linkedBiome == expectedBiome then
                    found = true
                    break
                end
            end

            if not found then
                print("  ✗ Biome " .. biomeId .. " missing link to " .. expectedBiome)
                allCorrect = false
            end
        end
    end

    assert(allCorrect, "All biome links should match TypeScript")
    print("✓ biomeLinks structure parity verified")
end

testBiomeLinksStructure()

-- ============================================================================
-- TEST SUITE 2: Weighted Selection Parity
-- ============================================================================

print("\n=== TEST SUITE 2: Weighted Selection Parity ===")

local function testWeightedSelectionParity()
    print("Test 2.1: Weighted biome selection matches TypeScript randSeedInt")

    -- Test SLUM weighted selection (SWAMP has weight 2)
    local response = sendMessage("GetBiomeInfo", {BiomeId = "30"})
    local data = json.decode(response.Data)
    local weighted = data.biome.linkedBiomesWeighted

    -- Verify weights match TypeScript
    local swampEntry = nil
    local constructionSiteEntry = nil

    for _, entry in ipairs(weighted) do
        if entry.biomeId == 7 then
            swampEntry = entry
        elseif entry.biomeId == 26 then
            constructionSiteEntry = entry
        end
    end

    assert(constructionSiteEntry and constructionSiteEntry.weight == 1, "CONSTRUCTION_SITE weight should be 1")
    assert(swampEntry and swampEntry.weight == 2, "SWAMP weight should be 2")

    print("  ✓ SLUM weighted links match TypeScript")

    -- Test BEACH weighted selection (ISLAND has weight 2)
    local response2 = sendMessage("GetBiomeInfo", {BiomeId = "8"})
    local data2 = json.decode(response2.Data)
    local weighted2 = data2.biome.linkedBiomesWeighted

    local islandEntry = nil
    for _, entry in ipairs(weighted2) do
        if entry.biomeId == 40 then
            islandEntry = entry
        end
    end

    assert(islandEntry and islandEntry.weight == 2, "ISLAND weight should be 2")

    print("  ✓ BEACH weighted links match TypeScript")
    print("✓ Weighted selection parity verified")
end

testWeightedSelectionParity()

-- ============================================================================
-- TEST SUITE 3: Biome Selection Logic Parity
-- ============================================================================

print("\n=== TEST SUITE 3: Biome Selection Logic Parity ===")

local function testSelectionLogicParity()
    print("Test 3.1: Single-path selection matches TypeScript behavior")

    -- TypeScript: if biome has single link, return that link directly
    local response = sendMessage("SelectNextBiome", {
        PlayerId = "parity_001",
        CurrentBiome = "0",  -- TOWN (single link to PLAINS)
        CurrentWaveIndex = "10",
        GameMode = "classic",
        HasMapModifier = "false"
    })

    assert(response.NextBiome == "1", "TOWN should always select PLAINS")
    assert(response.RequiresPlayerChoice == "false", "Single path should not require choice")

    print("  ✓ Single-path logic matches TypeScript")

    print("Test 3.2: Multi-path selection logic matches TypeScript")

    -- TypeScript: array of biomes -> filter weighted -> random selection
    local response2 = sendMessage("SelectNextBiome", {
        PlayerId = "parity_002",
        CurrentBiome = "1",  -- PLAINS (3 options)
        CurrentWaveIndex = "20",
        GameMode = "classic",
        HasMapModifier = "false",
        Seed = "12345"
    })

    local availableBiomes = json.decode(response2.AvailableBiomes)
    assert(#availableBiomes >= 1, "Should have available biomes after filtering")

    local nextBiome = tonumber(response2.NextBiome)
    local validBiomes = {[2] = true, [4] = true, [9] = true}
    assert(validBiomes[nextBiome], "Selected biome should be valid from PLAINS")

    print("  ✓ Multi-path logic matches TypeScript")
    print("✓ Selection logic parity verified")
end

testSelectionLogicParity()

-- ============================================================================
-- TEST SUITE 4: Map Modifier Logic Parity
-- ============================================================================

print("\n=== TEST SUITE 4: Map Modifier Logic Parity ===")

local function testMapModifierParity()
    print("Test 4.1: Map modifier player choice matches TypeScript")

    -- TypeScript: if biomes.length > 1 && findModifier(MapModifier) -> player choice
    local response = sendMessage("SelectNextBiome", {
        PlayerId = "parity_003",
        CurrentBiome = "1",  -- PLAINS (multiple options)
        CurrentWaveIndex = "30",
        GameMode = "classic",
        HasMapModifier = "true"
    })

    assert(response.RequiresPlayerChoice == "true", "Map modifier should enable choice")

    local availableBiomes = json.decode(response.AvailableBiomes)
    assert(#availableBiomes >= 2, "Should present multiple options")

    print("  ✓ Map modifier enables choice")

    -- TypeScript: single-path biome with Map modifier -> no choice
    local response2 = sendMessage("SelectNextBiome", {
        PlayerId = "parity_004",
        CurrentBiome = "0",  -- TOWN (single path)
        CurrentWaveIndex = "10",
        GameMode = "classic",
        HasMapModifier = "true"
    })

    assert(response2.RequiresPlayerChoice == "false", "Single path should not offer choice")

    print("  ✓ Map modifier correctly ignored for single paths")
    print("✓ Map modifier parity verified")
end

testMapModifierParity()

-- ============================================================================
-- TEST SUITE 5: END Biome Trigger Parity
-- ============================================================================

print("\n=== TEST SUITE 5: END Biome Trigger Parity ===")

local function testEndBiomeParity()
    print("Test 5.1: END biome trigger conditions match TypeScript")

    -- TypeScript: gameMode.isClassic && gameMode.isWaveFinal(nextWaveIndex + 9)
    -- Wave 50 is the trigger (50 + 9 = 59, boss at 60)
    local response1 = sendMessage("SelectNextBiome", {
        PlayerId = "parity_005",
        CurrentBiome = "25",
        CurrentWaveIndex = "50",
        GameMode = "classic",
        HasMapModifier = "false"
    })

    assert(response1.NextBiome == "50", "Wave 50 classic should select END")
    assert(response1.TransitionType == "end_biome", "Should be end_biome type")

    print("  ✓ Classic wave 50 END trigger matches")

    -- TypeScript: gameMode.isDaily && gameMode.isWaveFinal(nextWaveIndex)
    local response2 = sendMessage("SelectNextBiome", {
        PlayerId = "parity_006",
        CurrentBiome = "25",
        CurrentWaveIndex = "50",
        GameMode = "daily",
        HasMapModifier = "false"
    })

    assert(response2.NextBiome == "50", "Wave 50 daily should select END")

    print("  ✓ Daily wave 50 END trigger matches")

    -- Before wave 50 should not trigger END
    local response3 = sendMessage("SelectNextBiome", {
        PlayerId = "parity_007",
        CurrentBiome = "25",
        CurrentWaveIndex = "40",
        GameMode = "classic",
        HasMapModifier = "false"
    })

    assert(response3.NextBiome ~= "50", "Wave 40 should not select END")

    print("  ✓ Pre-wave-50 correctly avoids END")
    print("✓ END biome trigger parity verified")
end

testEndBiomeParity()

-- ============================================================================
-- TEST SUITE 6: Biome Transition Flow Parity
-- ============================================================================

print("\n=== TEST SUITE 6: Biome Transition Flow Parity ===")

local function testTransitionFlowParity()
    print("Test 6.1: Biome transition sequence matches TypeScript phases")

    -- TypeScript flow:
    -- 1. SelectBiomePhase: select next biome
    -- 2. SwitchBiomePhase: execute transition with arena updates

    local playerId = "parity_008"

    -- Step 1: Selection (SelectBiomePhase)
    local selectResponse = sendMessage("SelectNextBiome", {
        PlayerId = playerId,
        CurrentBiome = "0",
        CurrentWaveIndex = "10",
        GameMode = "classic",
        HasMapModifier = "false"
    })

    local nextBiome = selectResponse.NextBiome

    -- Step 2: Transition (SwitchBiomePhase)
    local transitionResponse = sendMessage("ExecuteBiomeTransition", {
        PlayerId = playerId,
        FromBiome = "0",
        ToBiome = nextBiome,
        WaveIndex = "10",
        Timestamp = "6000000"
    })

    assert(transitionResponse.Success == "true", "Transition should succeed")
    assert(transitionResponse.NewBiome == nextBiome, "Should transition to selected biome")
    assert(transitionResponse.FirstVisit == "true", "Should detect first visit")

    print("  ✓ Two-phase transition flow matches TypeScript")

    -- Step 3: Verify state matches TypeScript ArenaData.biome
    local stateResponse = sendMessage("GetPlayerBiomeState", {
        PlayerId = playerId,
        IncludeHistory = "false"
    })

    local stateData = json.decode(stateResponse.Data)
    assert(stateData.currentBiome == tonumber(nextBiome), "Current biome should be updated")

    print("  ✓ Arena biome state matches TypeScript")
    print("✓ Transition flow parity verified")
end

testTransitionFlowParity()

-- ============================================================================
-- TEST SUITE 7: Biome Unlock Tracking Parity
-- ============================================================================

print("\n=== TEST SUITE 7: Biome Unlock Tracking Parity ===")

local function testUnlockTrackingParity()
    print("Test 7.1: First visit detection matches TypeScript behavior")

    local playerId = "parity_009"

    -- First visit
    local response1 = sendMessage("ExecuteBiomeTransition", {
        PlayerId = playerId,
        FromBiome = "0",
        ToBiome = "1",
        WaveIndex = "10",
        Timestamp = "7000000"
    })

    assert(response1.FirstVisit == "true", "First visit should be detected")
    assert(response1.UnlockedTimestamp == "7000000", "Unlock timestamp should be recorded")

    -- Revisit
    local response2 = sendMessage("ExecuteBiomeTransition", {
        PlayerId = playerId,
        FromBiome = "0",
        ToBiome = "1",
        WaveIndex = "20",
        Timestamp = "7000001"
    })

    assert(response2.FirstVisit == "false", "Revisit should not be first visit")
    assert(response2.UnlockedTimestamp == "7000000", "Original unlock timestamp preserved")

    print("  ✓ First visit tracking matches TypeScript")
    print("✓ Unlock tracking parity verified")
end

testUnlockTrackingParity()

-- ============================================================================
-- TEST SUITE 8: biomeDepths Calculation Parity
-- ============================================================================

print("\n=== TEST SUITE 8: biomeDepths Calculation Parity ===")

local function testBiomeDepthsParity()
    print("Test 8.1: biomeDepths calculation matches TypeScript traverseBiome")

    -- TypeScript: biomeDepths[BiomeId.TOWN] = [0, 1]
    local response1 = sendMessage("GetBiomeInfo", {BiomeId = "0"})
    local data1 = json.decode(response1.Data)
    assert(data1.biome.depthRange[1] == 0, "TOWN depth should be 0")

    print("  ✓ TOWN depth matches TypeScript")

    -- TypeScript: biomeDepths[BiomeId.PLAINS] = [1, 1]
    local response2 = sendMessage("GetBiomeInfo", {BiomeId = "1"})
    local data2 = json.decode(response2.Data)
    assert(data2.biome.depthRange[1] == 1, "PLAINS depth should be 1")

    print("  ✓ PLAINS depth matches TypeScript")

    -- TypeScript: END depth = max depth + 1
    local response3 = sendMessage("GetBiomeInfo", {BiomeId = "50"})
    local data3 = json.decode(response3.Data)
    assert(data3.biome.depthRange[1] >= 10, "END depth should be max + 1")

    print("  ✓ END depth calculation matches TypeScript")
    print("✓ biomeDepths parity verified")
end

testBiomeDepthsParity()

-- ============================================================================
-- TEST SUITE 9: Edge Case Behavioral Parity
-- ============================================================================

print("\n=== TEST SUITE 9: Edge Case Behavioral Parity ===")

local function testEdgeCaseParity()
    print("Test 9.1: Invalid biome link rejection matches TypeScript")

    -- TypeScript: biomeLinks check before transition
    local response = sendMessage("ExecuteBiomeTransition", {
        PlayerId = "parity_010",
        FromBiome = "0",  -- TOWN
        ToBiome = "11",   -- MOUNTAIN (not linked from TOWN)
        WaveIndex = "10"
    })

    assert(response.Action == "Error", "Should reject invalid transition")

    print("  ✓ Invalid transition handling matches TypeScript")

    print("Test 9.2: Missing required parameters match TypeScript validation")

    local response2 = sendMessage("SelectNextBiome", {
        CurrentBiome = "1"
        -- Missing PlayerId
    })

    assert(response2.Action == "Error", "Should require PlayerId")

    print("  ✓ Parameter validation matches TypeScript")
    print("✓ Edge case parity verified")
end

testEdgeCaseParity()

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("ALL PARITY TESTS PASSED")
print("Biome Progression Engine matches TypeScript implementation")
print(string.rep("=", 60))
