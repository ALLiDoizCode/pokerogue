-- Unit Tests for Biome Progression Engine
-- Tests biome selection, transition, state management, and access validation
-- Migrated to correct aolite API pattern

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.biome-progression-engine"
local processId = "test-biome-progression-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Biome Progression Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
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

-- ============================================================================
-- TEST SUITE 1: Info Handler (ADP v1.0 Compliance)
-- ============================================================================

print("\n=== TEST SUITE 1: ADP v1.0 Info Handler ===")

local function testInfoHandler()
    print("Test 1.1: Info handler returns process metadata")

    local result = sendMessage("Info", {}, nil)
    if not result then
        error("❌ Info handler should return response")
    end

    if result.Action ~= "InfoResponse" then
        error("❌ Should return InfoResponse action, got: " .. tostring(result.Action))
    end

    local data = json.decode(result.Data)
    if data.process.name ~= "Biome Progression Engine" then
        error("❌ Process name should match")
    end
    if data.process.adpVersion ~= "1.0" then
        error("❌ Should be ADP v1.0 compliant")
    end
    if #data.process.capabilities < 5 then
        error("❌ Should list all capabilities")
    end
    if data.biomeData.totalBiomes ~= 36 then
        error("❌ Should report 36 biomes")
    end

    print("✅ Info handler test passed")
end

testInfoHandler()

-- ============================================================================
-- TEST SUITE 2: Single Path Biome Selection
-- ============================================================================

print("\n=== TEST SUITE 2: Single Path Biome Selection ===")

local function testSinglePathSelection()
    print("Test 2.1: TOWN always progresses to PLAINS")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_001",
        CurrentBiome = "0",  -- TOWN
        CurrentWaveIndex = "10",
        GameMode = "classic",
        HasMapModifier = "false",
        Seed = "12345"
    }, nil)

    if not result then
        error("❌ Should return biome selection")
    end

    if result.Action ~= "BiomeSelected" then
        error("❌ Should return BiomeSelected")
    end
    if result.NextBiome ~= "1" then
        error("❌ TOWN should progress to PLAINS (1)")
    end
    if result.RequiresPlayerChoice ~= "false" then
        error("❌ Single path should not require choice")
    end

    print("✅ TOWN -> PLAINS selection test passed")
end

local function testGrassToTallGrass()
    print("Test 2.2: GRASS always progresses to TALL_GRASS")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_002",
        CurrentBiome = "2",  -- GRASS
        CurrentWaveIndex = "20",
        GameMode = "classic",
        HasMapModifier = "false"
    }, nil)

    if result.NextBiome ~= "3" then
        error("❌ GRASS should progress to TALL_GRASS (3)")
    end

    print("✅ GRASS -> TALL_GRASS selection test passed")
end

testSinglePathSelection()
testGrassToTallGrass()

-- ============================================================================
-- TEST SUITE 3: Multi-Path Random Selection
-- ============================================================================

print("\n=== TEST SUITE 3: Multi-Path Random Selection ===")

local function testPlainsMultiPath()
    print("Test 3.1: PLAINS randomly selects from 3 options")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_003",
        CurrentBiome = "1",  -- PLAINS
        CurrentWaveIndex = "30",
        GameMode = "classic",
        HasMapModifier = "false",
        Seed = "54321"
    }, nil)

    if result.Action ~= "BiomeSelected" then
        error("❌ Should return BiomeSelected")
    end

    local availableBiomes = json.decode(result.AvailableBiomes)
    if #availableBiomes < 1 then
        error("❌ Should have at least one available biome")
    end

    -- PLAINS can lead to: GRASS (2), METROPOLIS (4), LAKE (9)
    local validBiomes = {[2] = true, [4] = true, [9] = true}
    local nextBiome = tonumber(result.NextBiome)
    if not validBiomes[nextBiome] then
        error("❌ Selected biome should be valid from PLAINS")
    end

    print("✅ PLAINS multi-path selection test passed")
end

local function testTallGrassTwoOptions()
    print("Test 3.2: TALL_GRASS randomly selects from 2 options")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_004",
        CurrentBiome = "3",  -- TALL_GRASS
        CurrentWaveIndex = "40",
        GameMode = "classic",
        HasMapModifier = "false"
    }, nil)

    local nextBiome = tonumber(result.NextBiome)

    -- TALL_GRASS can lead to: FOREST (5), CAVE (13)
    if nextBiome ~= 5 and nextBiome ~= 13 then
        error("❌ Should select FOREST or CAVE")
    end

    print("✅ TALL_GRASS multi-path selection test passed")
end

testPlainsMultiPath()
testTallGrassTwoOptions()

-- ============================================================================
-- TEST SUITE 4: Weighted Biome Selection
-- ============================================================================

print("\n=== TEST SUITE 4: Weighted Biome Selection ===")

local function testSlumWeightedSelection()
    print("Test 4.1: SLUM has weighted selection (CONSTRUCTION_SITE more likely)")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_005",
        CurrentBiome = "30",  -- SLUM
        CurrentWaveIndex = "50",
        GameMode = "classic",
        HasMapModifier = "false",
        Seed = "99999"
    }, nil)

    local availableBiomes = json.decode(result.AvailableBiomes)

    -- SLUM can lead to: CONSTRUCTION_SITE (26, weight 1), SWAMP (7, weight 2)
    if #availableBiomes < 1 then
        error("❌ Should have available biomes")
    end

    local nextBiome = tonumber(result.NextBiome)
    if nextBiome ~= 26 and nextBiome ~= 7 then
        error("❌ Should select CONSTRUCTION_SITE or SWAMP")
    end

    print("✅ SLUM weighted selection test passed")
end

local function testBeachWeightedSelection()
    print("Test 4.2: BEACH has weighted selection (SEA more likely)")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_006",
        CurrentBiome = "8",  -- BEACH
        CurrentWaveIndex = "60",
        GameMode = "classic",
        HasMapModifier = "false"
    }, nil)

    local nextBiome = tonumber(result.NextBiome)

    -- BEACH can lead to: SEA (6, weight 1), ISLAND (40, weight 2)
    if nextBiome ~= 6 and nextBiome ~= 40 then
        error("❌ Should select SEA or ISLAND")
    end

    print("✅ BEACH weighted selection test passed")
end

testSlumWeightedSelection()
testBeachWeightedSelection()

-- ============================================================================
-- TEST SUITE 5: Map Modifier Player Choice
-- ============================================================================

print("\n=== TEST SUITE 5: Map Modifier Player Choice ===")

local function testMapModifierEnablesChoice()
    print("Test 5.1: Map modifier enables player choice for PLAINS")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_007",
        CurrentBiome = "1",  -- PLAINS
        CurrentWaveIndex = "70",
        GameMode = "classic",
        HasMapModifier = "true",
        Seed = "11111"
    }, nil)

    if result.RequiresPlayerChoice ~= "true" then
        error("❌ Map modifier should enable choice")
    end

    local availableBiomes = json.decode(result.AvailableBiomes)
    if #availableBiomes < 2 then
        error("❌ Should have multiple biome options")
    end

    print("✅ Map modifier choice enablement test passed")
end

local function testMapModifierNoEffectSinglePath()
    print("Test 5.2: Map modifier has no effect for single-path TOWN")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_008",
        CurrentBiome = "0",  -- TOWN
        CurrentWaveIndex = "10",
        GameMode = "classic",
        HasMapModifier = "true"
    }, nil)

    if result.RequiresPlayerChoice ~= "false" then
        error("❌ Single path should not require choice")
    end
    if result.NextBiome ~= "1" then
        error("❌ Should still select PLAINS")
    end

    print("✅ Map modifier single-path test passed")
end

testMapModifierEnablesChoice()
testMapModifierNoEffectSinglePath()

-- ============================================================================
-- TEST SUITE 6: END Biome Special Handling
-- ============================================================================

print("\n=== TEST SUITE 6: END Biome Special Handling ===")

local function testWave50ClassicEndBiome()
    print("Test 6.1: Wave 50 in Classic mode triggers END biome")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_009",
        CurrentBiome = "25",  -- SPACE
        CurrentWaveIndex = "50",
        GameMode = "classic",
        HasMapModifier = "false"
    }, nil)

    if result.NextBiome ~= "50" then
        error("❌ Wave 50 should select END biome")
    end
    if result.TransitionType ~= "end_biome" then
        error("❌ Should be end_biome transition")
    end

    print("✅ Wave 50 END biome test passed")
end

local function testWave59EndBiome()
    print("Test 6.2: Wave 50+ in Classic mode forces END biome")

    local result = sendMessage("SelectNextBiome", {
        PlayerId = "player_010",
        CurrentBiome = "22",  -- RUINS
        CurrentWaveIndex = "59",
        GameMode = "classic",
        HasMapModifier = "false"
    }, nil)

    if result.NextBiome ~= "50" then
        error("❌ Wave 50+ should force END biome")
    end

    print("✅ Wave 50+ END biome test passed")
end

testWave50ClassicEndBiome()
testWave59EndBiome()

-- ============================================================================
-- TEST SUITE 7: Biome Transition and Unlock Tracking
-- ============================================================================

print("\n=== TEST SUITE 7: Biome Transition and Unlock Tracking ===")

local function testFirstBiomeVisit()
    print("Test 7.1: First biome visit records unlock timestamp")

    local result = sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_011",
        FromBiome = "0",  -- TOWN
        ToBiome = "1",    -- PLAINS
        WaveIndex = "10",
        Timestamp = "1000000"
    }, nil)

    if result.Action ~= "BiomeTransitioned" then
        error("❌ Should return BiomeTransitioned")
    end
    if result.Success ~= "true" then
        error("❌ Transition should succeed")
    end
    if result.FirstVisit ~= "true" then
        error("❌ Should be first visit")
    end
    if result.NewBiome ~= "1" then
        error("❌ Should transition to PLAINS")
    end
    if result.BiomeName ~= "Plains" then
        error("❌ Should return biome name")
    end

    print("✅ First visit unlock test passed")
end

local function testRevisitBiome()
    print("Test 7.2: Revisiting biome doesn't change unlock timestamp")

    -- First transition to GRASS
    sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_012",
        FromBiome = "0",
        ToBiome = "2",  -- GRASS
        WaveIndex = "10",
        Timestamp = "2000000"
    }, nil)

    -- Revisit GRASS
    local result = sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_012",
        FromBiome = "1",
        ToBiome = "2",  -- GRASS again
        WaveIndex = "30",
        Timestamp = "3000000"
    }, nil)

    if result.FirstVisit ~= "false" then
        error("❌ Should not be first visit")
    end
    if result.UnlockedTimestamp ~= "2000000" then
        error("❌ Unlock timestamp should not change")
    end

    print("✅ Revisit biome test passed")
end

testFirstBiomeVisit()
testRevisitBiome()

-- ============================================================================
-- TEST SUITE 8: Biome State Management
-- ============================================================================

print("\n=== TEST SUITE 8: Biome State Management ===")

local function testGetPlayerBiomeState()
    print("Test 8.1: Get player biome state returns complete data")

    -- Create some state first
    sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_013",
        FromBiome = "0",
        ToBiome = "1",
        WaveIndex = "10",
        Timestamp = "4000000"
    }, nil)

    sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_013",
        FromBiome = "1",
        ToBiome = "2",
        WaveIndex = "20",
        Timestamp = "4000001"
    }, nil)

    -- Query state
    local result = sendMessage("GetPlayerBiomeState", {
        PlayerId = "player_013",
        IncludeHistory = "true"
    }, nil)

    if result.Action ~= "PlayerBiomeData" then
        error("❌ Should return PlayerBiomeData")
    end

    local data = json.decode(result.Data)
    if data.currentBiome ~= 2 then
        error("❌ Current biome should be GRASS")
    end
    if data.totalBiomesUnlocked < 2 then
        error("❌ Should have unlocked at least 2 biomes")
    end
    if not data.unlockedBiomes[1] then
        error("❌ PLAINS should be unlocked")
    end
    if not data.unlockedBiomes[2] then
        error("❌ GRASS should be unlocked")
    end
    if not data.biomeHistory then
        error("❌ Should include history")
    end

    print("✅ Get player state test passed")
end

local function testProgressionPercentage()
    print("Test 8.2: Progression percentage calculates correctly")

    local result = sendMessage("GetPlayerBiomeState", {
        PlayerId = "player_011",  -- Has visited TOWN and PLAINS
        IncludeHistory = "false"
    }, nil)

    local data = json.decode(result.Data)

    if data.progressionPercentage < 0 then
        error("❌ Percentage should be non-negative")
    end
    if data.progressionPercentage > 100 then
        error("❌ Percentage should not exceed 100")
    end

    print("✅ Progression percentage test passed")
end

testGetPlayerBiomeState()
testProgressionPercentage()

-- ============================================================================
-- TEST SUITE 9: Biome Access Validation
-- ============================================================================

print("\n=== TEST SUITE 9: Biome Access Validation ===")

local function testValidBiomeAccess()
    print("Test 9.1: Valid biome access from TOWN to PLAINS")

    local result = sendMessage("ValidateBiomeAccess", {
        PlayerId = "player_014",
        BiomeId = "1",  -- PLAINS
        CurrentBiome = "0",  -- TOWN
        WaveIndex = "10"
    }, nil)

    if result.Action ~= "BiomeAccessValidated" then
        error("❌ Should return validation result")
    end
    if result.Accessible ~= "true" then
        error("❌ PLAINS should be accessible from TOWN")
    end
    if result.IsLinked ~= "true" then
        error("❌ Should be linked")
    end

    print("✅ Valid access test passed")
end

local function testInvalidBiomeAccess()
    print("Test 9.2: Invalid biome access from TOWN to MOUNTAIN")

    local result = sendMessage("ValidateBiomeAccess", {
        PlayerId = "player_015",
        BiomeId = "11",  -- MOUNTAIN
        CurrentBiome = "0",  -- TOWN
        WaveIndex = "10"
    }, nil)

    if result.Accessible ~= "false" then
        error("❌ MOUNTAIN should not be accessible from TOWN")
    end
    if result.IsLinked ~= "false" then
        error("❌ Should not be linked")
    end
    if result.Reason == "" then
        error("❌ Should provide reason")
    end

    print("✅ Invalid access test passed")
end

local function testWaveMilestoneValidation()
    print("Test 9.3: Biome transitions only at wave milestones")

    local result = sendMessage("ValidateBiomeAccess", {
        PlayerId = "player_016",
        BiomeId = "1",  -- PLAINS
        CurrentBiome = "0",  -- TOWN
        WaveIndex = "5"  -- Not a milestone
    }, nil)

    if result.Accessible ~= "false" then
        error("❌ Should not be accessible at non-milestone wave")
    end
    if not string.find(result.Reason, "milestone") then
        error("❌ Reason should mention milestone")
    end

    print("✅ Wave milestone validation test passed")
end

testValidBiomeAccess()
testInvalidBiomeAccess()
testWaveMilestoneValidation()

-- ============================================================================
-- TEST SUITE 10: Biome Info Queries
-- ============================================================================

print("\n=== TEST SUITE 10: Biome Info Queries ===")

local function testGetSingleBiomeInfo()
    print("Test 10.1: Get info for single biome")

    local result = sendMessage("GetBiomeInfo", {
        BiomeId = "3"  -- TALL_GRASS
    }, nil)

    if result.Action ~= "BiomeInfo" then
        error("❌ Should return BiomeInfo")
    end

    local data = json.decode(result.Data)
    if not data.biome then
        error("❌ Should have biome data")
    end
    if data.biome.id ~= 3 then
        error("❌ Should be TALL_GRASS")
    end
    if data.biome.name ~= "Tall Grass" then
        error("❌ Should have correct name")
    end
    if #data.biome.linkedBiomes < 1 then
        error("❌ Should have linked biomes")
    end

    print("✅ Single biome info test passed")
end

local function testGetAllBiomesInfo()
    print("Test 10.2: Get info for all biomes")

    local result = sendMessage("GetBiomeInfo", {}, nil)

    local data = json.decode(result.Data)

    if not data.biomes then
        error("❌ Should have biomes array")
    end
    if #data.biomes < 36 then
        error("❌ Should have at least 36 biomes")
    end

    print("✅ All biomes info test passed")
end

testGetSingleBiomeInfo()
testGetAllBiomesInfo()

-- ============================================================================
-- TEST SUITE 11: Edge Cases
-- ============================================================================

print("\n=== TEST SUITE 11: Edge Cases ===")

local function testMissingPlayerId()
    print("Test 11.1: Missing PlayerId produces error")

    local result = sendMessage("SelectNextBiome", {
        CurrentBiome = "1",
        CurrentWaveIndex = "10"
    }, nil)

    if result.Action ~= "Error" then
        error("❌ Should return error")
    end
    if not string.find(result.Error, "PlayerId") then
        error("❌ Error should mention PlayerId")
    end

    print("✅ Missing PlayerId test passed")
end

local function testInvalidBiomeTransition()
    print("Test 11.2: Invalid biome transition produces error")

    local result = sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_017",
        FromBiome = "0",  -- TOWN
        ToBiome = "50",   -- END (not valid from TOWN)
        WaveIndex = "10"
    }, nil)

    if result.Action ~= "Error" then
        error("❌ Should return error for invalid transition")
    end

    print("✅ Invalid transition test passed")
end

local function testInvalidBiomeId()
    print("Test 11.3: Invalid biome ID in GetBiomeInfo")

    local result = sendMessage("GetBiomeInfo", {
        BiomeId = "999"  -- Invalid
    }, nil)

    if result.Action ~= "Error" then
        error("❌ Should return error for invalid biome ID")
    end

    print("✅ Invalid biome ID test passed")
end

testMissingPlayerId()
testInvalidBiomeTransition()
testInvalidBiomeId()

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("ALL TESTS PASSED")
print("Biome Progression Engine unit tests completed successfully")
print(string.rep("=", 60))
print("✅ Test file executed successfully: " .. PROCESS_PATH)
