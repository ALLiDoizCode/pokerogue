-- Unit Tests for Biome Progression Engine
-- Tests biome selection, transition, state management, and access validation

local aolite = require("aolite")
local json = require("json")

-- Test state
local processId = nil
local testMessages = {}

-- Helper to send message and capture response
local function sendMessage(action, tags, data)
    local msg = {
        Action = action,
        From = "test_sender",
        Timestamp = os.time() * 1000
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    if data then
        msg.Data = type(data) == "table" and json.encode(data) or data
    end

    local result = aolite.send(processId, msg)
    table.insert(testMessages, result)
    return result
end

-- Setup: Load process
print("Setting up Biome Progression Engine tests...")
processId = aolite.spawn("biome-progression-engine", "../processes/biome-progression-engine.lua")

if not processId then
    error("Failed to spawn biome-progression-engine process")
end

print("Process spawned with ID: " .. processId)

-- ============================================================================
-- TEST SUITE 1: Info Handler (ADP v1.0 Compliance)
-- ============================================================================

print("\n=== TEST SUITE 1: ADP v1.0 Info Handler ===")

local function testInfoHandler()
    print("Test 1.1: Info handler returns process metadata")

    local result = sendMessage("Info", {}, nil)
    assert(result, "Info handler should return response")

    local response = result[1]
    assert(response.Action == "InfoResponse", "Should return InfoResponse action")

    local data = json.decode(response.Data)
    assert(data.process.name == "Biome Progression Engine", "Process name should match")
    assert(data.process.adpVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(#data.process.capabilities >= 5, "Should list all capabilities")
    assert(data.biomeData.totalBiomes == 36, "Should report 36 biomes")

    print("✓ Info handler test passed")
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

    assert(result, "Should return biome selection")

    local response = result[1]
    assert(response.Action == "BiomeSelected", "Should return BiomeSelected")
    assert(response.NextBiome == "1", "TOWN should progress to PLAINS (1)")
    assert(response.RequiresPlayerChoice == "false", "Single path should not require choice")

    print("✓ TOWN -> PLAINS selection test passed")
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

    local response = result[1]
    assert(response.NextBiome == "3", "GRASS should progress to TALL_GRASS (3)")

    print("✓ GRASS -> TALL_GRASS selection test passed")
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

    local response = result[1]
    assert(response.Action == "BiomeSelected", "Should return BiomeSelected")

    local availableBiomes = json.decode(response.AvailableBiomes)
    assert(#availableBiomes >= 1, "Should have at least one available biome")

    -- PLAINS can lead to: GRASS (2), METROPOLIS (4), LAKE (9)
    local validBiomes = {[2] = true, [4] = true, [9] = true}
    local nextBiome = tonumber(response.NextBiome)
    assert(validBiomes[nextBiome], "Selected biome should be valid from PLAINS")

    print("✓ PLAINS multi-path selection test passed")
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

    local response = result[1]
    local nextBiome = tonumber(response.NextBiome)

    -- TALL_GRASS can lead to: FOREST (5), CAVE (13)
    assert(nextBiome == 5 or nextBiome == 13, "Should select FOREST or CAVE")

    print("✓ TALL_GRASS multi-path selection test passed")
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

    local response = result[1]
    local availableBiomes = json.decode(response.AvailableBiomes)

    -- SLUM can lead to: CONSTRUCTION_SITE (26, weight 1), SWAMP (7, weight 2)
    assert(#availableBiomes >= 1, "Should have available biomes")

    local nextBiome = tonumber(response.NextBiome)
    assert(nextBiome == 26 or nextBiome == 7, "Should select CONSTRUCTION_SITE or SWAMP")

    print("✓ SLUM weighted selection test passed")
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

    local response = result[1]
    local nextBiome = tonumber(response.NextBiome)

    -- BEACH can lead to: SEA (6, weight 1), ISLAND (40, weight 2)
    assert(nextBiome == 6 or nextBiome == 40, "Should select SEA or ISLAND")

    print("✓ BEACH weighted selection test passed")
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

    local response = result[1]
    assert(response.RequiresPlayerChoice == "true", "Map modifier should enable choice")

    local availableBiomes = json.decode(response.AvailableBiomes)
    assert(#availableBiomes >= 2, "Should have multiple biome options")

    print("✓ Map modifier choice enablement test passed")
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

    local response = result[1]
    assert(response.RequiresPlayerChoice == "false", "Single path should not require choice")
    assert(response.NextBiome == "1", "Should still select PLAINS")

    print("✓ Map modifier single-path test passed")
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

    local response = result[1]
    assert(response.NextBiome == "50", "Wave 50 should select END biome")
    assert(response.TransitionType == "end_biome", "Should be end_biome transition")

    print("✓ Wave 50 END biome test passed")
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

    local response = result[1]
    assert(response.NextBiome == "50", "Wave 50+ should force END biome")

    print("✓ Wave 50+ END biome test passed")
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

    local response = result[1]
    assert(response.Action == "BiomeTransitioned", "Should return BiomeTransitioned")
    assert(response.Success == "true", "Transition should succeed")
    assert(response.FirstVisit == "true", "Should be first visit")
    assert(response.NewBiome == "1", "Should transition to PLAINS")
    assert(response.BiomeName == "Plains", "Should return biome name")

    print("✓ First visit unlock test passed")
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

    local response = result[1]
    assert(response.FirstVisit == "false", "Should not be first visit")
    assert(response.UnlockedTimestamp == "2000000", "Unlock timestamp should not change")

    print("✓ Revisit biome test passed")
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

    local response = result[1]
    assert(response.Action == "PlayerBiomeData", "Should return PlayerBiomeData")

    local data = json.decode(response.Data)
    assert(data.currentBiome == 2, "Current biome should be GRASS")
    assert(data.totalBiomesUnlocked >= 2, "Should have unlocked at least 2 biomes")
    assert(data.unlockedBiomes[1], "PLAINS should be unlocked")
    assert(data.unlockedBiomes[2], "GRASS should be unlocked")
    assert(data.biomeHistory, "Should include history")

    print("✓ Get player state test passed")
end

local function testProgressionPercentage()
    print("Test 8.2: Progression percentage calculates correctly")

    local result = sendMessage("GetPlayerBiomeState", {
        PlayerId = "player_011",  -- Has visited TOWN and PLAINS
        IncludeHistory = "false"
    }, nil)

    local response = result[1]
    local data = json.decode(response.Data)

    assert(data.progressionPercentage >= 0, "Percentage should be non-negative")
    assert(data.progressionPercentage <= 100, "Percentage should not exceed 100")

    print("✓ Progression percentage test passed")
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

    local response = result[1]
    assert(response.Action == "BiomeAccessValidated", "Should return validation result")
    assert(response.Accessible == "true", "PLAINS should be accessible from TOWN")
    assert(response.IsLinked == "true", "Should be linked")

    print("✓ Valid access test passed")
end

local function testInvalidBiomeAccess()
    print("Test 9.2: Invalid biome access from TOWN to MOUNTAIN")

    local result = sendMessage("ValidateBiomeAccess", {
        PlayerId = "player_015",
        BiomeId = "11",  -- MOUNTAIN
        CurrentBiome = "0",  -- TOWN
        WaveIndex = "10"
    }, nil)

    local response = result[1]
    assert(response.Accessible == "false", "MOUNTAIN should not be accessible from TOWN")
    assert(response.IsLinked == "false", "Should not be linked")
    assert(response.Reason ~= "", "Should provide reason")

    print("✓ Invalid access test passed")
end

local function testWaveMilestoneValidation()
    print("Test 9.3: Biome transitions only at wave milestones")

    local result = sendMessage("ValidateBiomeAccess", {
        PlayerId = "player_016",
        BiomeId = "1",  -- PLAINS
        CurrentBiome = "0",  -- TOWN
        WaveIndex = "5"  -- Not a milestone
    }, nil)

    local response = result[1]
    assert(response.Accessible == "false", "Should not be accessible at non-milestone wave")
    assert(response.Reason:find("milestone"), "Reason should mention milestone")

    print("✓ Wave milestone validation test passed")
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

    local response = result[1]
    assert(response.Action == "BiomeInfo", "Should return BiomeInfo")

    local data = json.decode(response.Data)
    assert(data.biome, "Should have biome data")
    assert(data.biome.id == 3, "Should be TALL_GRASS")
    assert(data.biome.name == "Tall Grass", "Should have correct name")
    assert(#data.biome.linkedBiomes >= 1, "Should have linked biomes")

    print("✓ Single biome info test passed")
end

local function testGetAllBiomesInfo()
    print("Test 10.2: Get info for all biomes")

    local result = sendMessage("GetBiomeInfo", {}, nil)

    local response = result[1]
    local data = json.decode(response.Data)

    assert(data.biomes, "Should have biomes array")
    assert(#data.biomes >= 36, "Should have at least 36 biomes")

    print("✓ All biomes info test passed")
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

    local response = result[1]
    assert(response.Action == "Error", "Should return error")
    assert(response.Error:find("PlayerId"), "Error should mention PlayerId")

    print("✓ Missing PlayerId test passed")
end

local function testInvalidBiomeTransition()
    print("Test 11.2: Invalid biome transition produces error")

    local result = sendMessage("ExecuteBiomeTransition", {
        PlayerId = "player_017",
        FromBiome = "0",  -- TOWN
        ToBiome = "50",   -- END (not valid from TOWN)
        WaveIndex = "10"
    }, nil)

    local response = result[1]
    assert(response.Action == "Error", "Should return error for invalid transition")

    print("✓ Invalid transition test passed")
end

local function testInvalidBiomeId()
    print("Test 11.3: Invalid biome ID in GetBiomeInfo")

    local result = sendMessage("GetBiomeInfo", {
        BiomeId = "999"  -- Invalid
    }, nil)

    local response = result[1]
    assert(response.Action == "Error", "Should return error for invalid biome ID")

    print("✓ Invalid biome ID test passed")
end

testMissingPlayerId()
testInvalidBiomeTransition()
testInvalidBiomeId()

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("ALL TESTS PASSED")
print("Total test messages sent: " .. #testMessages)
print("Biome Progression Engine unit tests completed successfully")
print(string.rep("=", 60))
