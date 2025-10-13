-- Integration Tests for Gym Leader and Elite Four Systems
-- End-to-end workflow testing for elite trainer generation
-- Target: 20+ integration tests covering complete workflows

local aolite = require("aolite")
local json = require("json")

-- Test state
local processId = nil
local passCount = 0
local failCount = 0

-- Helper to send message and capture response
local function sendMessage(action, tags)
    local msg = {
        Action = action,
        From = "test_sender",
        Timestamp = os.time() * 1000
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    local result = aolite.send(processId, msg)
    return result
end

-- Test assertion helpers
local function assertTrue(condition, testName, message)
    if condition then
        print(string.format("  ✓ %s", testName))
        passCount = passCount + 1
        return true
    else
        print(string.format("  ✗ %s: %s", testName, message or "Assertion failed"))
        failCount = failCount + 1
        return false
    end
end

local function assertEquals(expected, actual, testName)
    if expected == actual then
        print(string.format("  ✓ %s", testName))
        passCount = passCount + 1
        return true
    else
        print(string.format("  ✗ %s: expected %s, got %s", testName, tostring(expected), tostring(actual)))
        failCount = failCount + 1
        return false
    end
end

-- Setup: Load process
print("\n🧪 Running Integration Tests: Gym Leader and Elite Four Systems\n")
print("Loading trainer-encounter-engine process...")
processId = aolite.spawn("trainer-encounter-engine", "processes/trainer-encounter-engine.lua")

if not processId then
    error("Failed to spawn trainer-encounter-engine process")
end

print("Process spawned successfully: " .. processId .. "\n")

-- ============================================================================
-- TEST SUITE 1: Complete Gym Leader Generation Workflow
-- ============================================================================

print("=== TEST SUITE 1: Complete Gym Leader Generation Workflow ===\n")

local function testGymLeaderWave20()
    print("Test 1.1: Gym Leader at wave 20 (Brock - ROCK specialty)")
    local response = sendMessage("GenerateGymLeader", {
        Wave = "20",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "20"
    })

    assertTrue(response and #response > 0, "1.1.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("GymLeaderGenerated", msg.Action, "1.1.2: Should return GymLeaderGenerated action")
        assertEquals("20", msg.Wave, "1.1.3: Wave should be 20")
        assertEquals("GYM_LEADER", msg.TrainerType, "1.1.4: TrainerType should be GYM_LEADER")
        assertEquals("Brock", msg.TrainerName, "1.1.5: Gym leader should be Brock")
        assertTrue(msg.SpecialtyType ~= nil, "1.1.6: Should have specialty type")
        assertTrue(msg.MoneyReward ~= nil, "1.1.7: Should have money reward")
        assertEquals("true", msg.HasBadge, "1.1.8: Should have badge")
    end
    print("")
end

local function testGymLeaderWave100()
    print("Test 1.2: Gym Leader at wave 100 (Blaine - Tera mode enabled)")
    local response = sendMessage("GenerateGymLeader", {
        Wave = "100",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    assertTrue(response and #response > 0, "1.2.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("GymLeaderGenerated", msg.Action, "1.2.2: Should return GymLeaderGenerated action")
        assertEquals("100", msg.Wave, "1.2.3: Wave should be 100")
        assertEquals("Blaine", msg.TrainerName, "1.2.4: Gym leader should be Blaine")
        assertTrue(msg.TeraSlot ~= nil and msg.TeraSlot ~= "", "1.2.5: Should have Tera slot configured (wave ≥100)")
    end
    print("")
end

local function testGymLeaderWave160()
    print("Test 1.3: Gym Leader at wave 160 (Clair - DRAGON specialty)")
    local response = sendMessage("GenerateGymLeader", {
        Wave = "160",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    assertTrue(response and #response > 0, "1.3.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("GymLeaderGenerated", msg.Action, "1.3.2: Should return GymLeaderGenerated action")
        assertEquals("160", msg.Wave, "1.3.3: Wave should be 160")
        assertEquals("Clair", msg.TrainerName, "1.3.4: Gym leader should be Clair")
    end
    print("")
end

testGymLeaderWave20()
testGymLeaderWave100()
testGymLeaderWave160()

-- ============================================================================
-- TEST SUITE 2: Complete Elite Four Challenge Sequence
-- ============================================================================

print("=== TEST SUITE 2: Complete Elite Four Challenge Sequence ===\n")

local function testEliteFourMember1()
    print("Test 2.1: Elite Four Member 1 (wave 182)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    assertTrue(response and #response > 0, "2.1.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("EliteFourGenerated", msg.Action, "2.1.2: Should return EliteFourGenerated action")
        assertEquals("182", msg.Wave, "2.1.3: Wave should be 182")
        assertEquals("ELITE_FOUR", msg.TrainerType, "2.1.4: TrainerType should be ELITE_FOUR")
        assertEquals("1", msg.MemberIndex, "2.1.5: Member index should be 1")
        assertTrue(msg.SpecialtyType ~= nil, "2.1.6: Should have specialty type")
        assertTrue(msg.MoneyReward ~= nil, "2.1.7: Should have money reward")
    end
    print("")
end

local function testEliteFourMember2()
    print("Test 2.2: Elite Four Member 2 (wave 184)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "184",
        MemberIndex = "2",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "1"
    })

    assertTrue(response and #response > 0, "2.2.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("EliteFourGenerated", msg.Action, "2.2.2: Should return EliteFourGenerated action")
        assertEquals("184", msg.Wave, "2.2.3: Wave should be 184")
        assertEquals("2", msg.MemberIndex, "2.2.4: Member index should be 2")
    end
    print("")
end

local function testEliteFourMember3()
    print("Test 2.3: Elite Four Member 3 (wave 186)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "186",
        MemberIndex = "3",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "2"
    })

    assertTrue(response and #response > 0, "2.3.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("EliteFourGenerated", msg.Action, "2.3.2: Should return EliteFourGenerated action")
        assertEquals("186", msg.Wave, "2.3.3: Wave should be 186")
        assertEquals("3", msg.MemberIndex, "2.3.4: Member index should be 3")
    end
    print("")
end

local function testEliteFourMember4()
    print("Test 2.4: Elite Four Member 4 (wave 188)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "188",
        MemberIndex = "4",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "3"
    })

    assertTrue(response and #response > 0, "2.4.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("EliteFourGenerated", msg.Action, "2.4.2: Should return EliteFourGenerated action")
        assertEquals("188", msg.Wave, "2.4.3: Wave should be 188")
        assertEquals("4", msg.MemberIndex, "2.4.4: Member index should be 4")
    end
    print("")
end

local function testChampion()
    print("Test 2.5: Champion (wave 190)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "190",
        IsChampion = "true",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "4"
    })

    assertTrue(response and #response > 0, "2.5.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("EliteFourGenerated", msg.Action, "2.5.2: Should return EliteFourGenerated action")
        assertEquals("190", msg.Wave, "2.5.3: Wave should be 190")
        assertEquals("CHAMPION", msg.TrainerType, "2.5.4: TrainerType should be CHAMPION")
        assertTrue(msg.TrainerName ~= nil, "2.5.5: Should have Champion name")
    end
    print("")
end

testEliteFourMember1()
testEliteFourMember2()
testEliteFourMember3()
testEliteFourMember4()
testChampion()

-- ============================================================================
-- TEST SUITE 3: Gym Leader Progression Tracking
-- ============================================================================

print("=== TEST SUITE 3: Gym Leader Progression Tracking ===\n")

local function testGymLeaderProgression()
    print("Test 3.1: All 10 gym leaders generate correctly")
    local gymLeaderWaves = {20, 30, 40, 50, 60, 80, 100, 120, 140, 160}
    local expectedNames = {"Brock", "Misty", "Lt. Surge", "Erika", "Janine", "Sabrina", "Blaine", "Giovanni", "Whitney", "Clair"}

    for i, wave in ipairs(gymLeaderWaves) do
        local response = sendMessage("GenerateGymLeader", {
            Wave = tostring(wave),
            GameMode = "Classic",
            Seed = "12345",
            PlayerLevel = tostring(wave)
        })

        local testName = string.format("3.1.%d: Wave %d gym leader generates", i, wave)
        assertTrue(response and #response > 0, testName)

        if response and #response > 0 then
            local msg = response[1]
            local expectedName = expectedNames[i]
            local nameTestName = string.format("3.1.%d.1: Wave %d should be %s", i, wave, expectedName)
            assertEquals(expectedName, msg.TrainerName, nameTestName)
        end
    end
    print("")
end

testGymLeaderProgression()

-- ============================================================================
-- TEST SUITE 4: Championship Validation Integration
-- ============================================================================

print("=== TEST SUITE 4: Championship Validation Integration ===\n")

local function testChampionshipValidationNotReady()
    print("Test 4.1: Championship validation - not ready (0 victories)")
    local response = sendMessage("ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "0"
    })

    assertTrue(response and #response > 0, "4.1.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("ChampionshipValidated", msg.Action, "4.1.2: Should return ChampionshipValidated action")
        assertEquals("false", msg.CanBattleChampion, "4.1.3: Cannot battle Champion with 0 victories")
        assertEquals("false", msg.EliteFourComplete, "4.1.4: Elite Four not complete")
    end
    print("")
end

local function testChampionshipValidationReady()
    print("Test 4.2: Championship validation - ready (4 victories)")
    local response = sendMessage("ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "4"
    })

    assertTrue(response and #response > 0, "4.2.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("ChampionshipValidated", msg.Action, "4.2.2: Should return ChampionshipValidated action")
        assertEquals("true", msg.CanBattleChampion, "4.2.3: Can battle Champion with 4 victories")
        assertEquals("true", msg.EliteFourComplete, "4.2.4: Elite Four is complete")
    end
    print("")
end

testChampionshipValidationNotReady()
testChampionshipValidationReady()

-- ============================================================================
-- TEST SUITE 5: Reward Distribution Integration
-- ============================================================================

print("=== TEST SUITE 5: Reward Distribution Integration ===\n")

local function testGymLeaderRewardDistribution()
    print("Test 5.1: Gym Leader reward distribution (2.5x multiplier)")
    local response = sendMessage("GenerateGymLeader", {
        Wave = "20",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "20"
    })

    assertTrue(response and #response > 0, "5.1.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertTrue(msg.MoneyReward ~= nil, "5.1.2: Should have MoneyReward field")
        local reward = tonumber(msg.MoneyReward)
        assertTrue(reward > 0, "5.1.3: Gym Leader reward should be positive")
    end
    print("")
end

local function testEliteFourRewardDistribution()
    print("Test 5.2: Elite Four reward distribution (3.25x multiplier)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    assertTrue(response and #response > 0, "5.2.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertTrue(msg.MoneyReward ~= nil, "5.2.2: Should have MoneyReward field")
        local reward = tonumber(msg.MoneyReward)
        assertTrue(reward > 0, "5.2.3: Elite Four reward should be positive")
    end
    print("")
end

local function testChampionRewardDistribution()
    print("Test 5.3: Champion reward distribution (10x multiplier)")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "190",
        IsChampion = "true",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "4"
    })

    assertTrue(response and #response > 0, "5.3.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertTrue(msg.MoneyReward ~= nil, "5.3.2: Should have MoneyReward field")
        local reward = tonumber(msg.MoneyReward)
        assertTrue(reward > 0, "5.3.3: Champion reward should be positive")
    end
    print("")
end

testGymLeaderRewardDistribution()
testEliteFourRewardDistribution()
testChampionRewardDistribution()

-- ============================================================================
-- TEST SUITE 6: Tera Mode Activation Integration
-- ============================================================================

print("=== TEST SUITE 6: Tera Mode Activation Integration ===\n")

local function testGymLeaderTeraBeforeThreshold()
    print("Test 6.1: Gym Leader Tera mode before wave 100 (NO_TERA)")
    local response = sendMessage("GenerateGymLeader", {
        Wave = "80",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "80"
    })

    assertTrue(response and #response > 0, "6.1.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertEquals("", msg.TeraSlot or "", "6.1.2: TeraSlot should be empty for wave <100")
    end
    print("")
end

local function testGymLeaderTeraAfterThreshold()
    print("Test 6.2: Gym Leader Tera mode after wave 100 (INSTANT_TERA)")
    local response = sendMessage("GenerateGymLeader", {
        Wave = "120",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    assertTrue(response and #response > 0, "6.2.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertTrue(msg.TeraSlot ~= nil and msg.TeraSlot ~= "", "6.2.2: TeraSlot should be set for wave ≥100")
    end
    print("")
end

local function testEliteFourSmartTera()
    print("Test 6.3: Elite Four SMART_TERA mode")
    local response = sendMessage("GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    assertTrue(response and #response > 0, "6.3.1: Should receive response")
    if response and #response > 0 then
        local msg = response[1]
        assertTrue(msg.TeraSlot ~= nil, "6.3.2: Elite Four should have TeraSlot configured")
    end
    print("")
end

testGymLeaderTeraBeforeThreshold()
testGymLeaderTeraAfterThreshold()
testEliteFourSmartTera()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("📊 INTEGRATION TEST RESULTS")
print(string.rep("=", 60))
print(string.format("✅ Passed: %d", passCount))
print(string.format("❌ Failed: %d", failCount))
print(string.format("📈 Total: %d", passCount + failCount))
print(string.rep("=", 60))

if failCount == 0 then
    print("\n🎉 All integration tests passed!\n")
    os.exit(0)
else
    print(string.format("\n⚠️  %d test(s) failed\n", failCount))
    os.exit(1)
end
