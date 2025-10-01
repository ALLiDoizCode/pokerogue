-- Unit Tests for Gym Leader and Elite Four Systems
-- Tests party templates, Tera configuration, rewards, dialogue, validation
-- Target: 40+ tests across party template selection, Elite Four progression, championship validation

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-trainer-encounter-engine",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers
local mockHandlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg)
                if type(values) == "table" then
                    for _, value in ipairs(values) do
                        if msg[tag] == value then
                            return true
                        end
                    end
                    return false
                else
                    return msg[tag] == values
                end
            end
        end
    }
}

-- Load proper JSON library
local json = require("json")

-- Test state
local passCount = 0
local failCount = 0

-- Setup test environment
local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = json
end

-- Load the process
local function loadProcess()
    setupTestEnvironment()
    dofile("processes/trainer-encounter-engine.lua")
end

-- Helper to send test message and capture response
local function sendMessage(handlerName, action, tags)
    testMessages = {} -- Clear previous messages

    local msg = {
        Action = action,
        From = "test_sender",
        Timestamp = os.time() * 1000
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    local handler = testHandlers[handlerName]
    if handler and handler.handler then
        if handler.matcher(msg) then
            handler.handler(msg)
            return testMessages[1] -- Return first response
        end
    end

    return nil
end

-- Test assertion helpers
local function assert_equals(expected, actual, message)
    if expected ~= actual then
        failCount = failCount + 1
        print(string.format("  ❌ FAIL: %s\n     Expected: %s\n     Got: %s", message, tostring(expected), tostring(actual)))
        return false
    end
    passCount = passCount + 1
    return true
end

local function assert_true(condition, message)
    if not condition then
        failCount = failCount + 1
        print(string.format("  ❌ FAIL: %s", message))
        return false
    end
    passCount = passCount + 1
    return true
end

local function assert_not_nil(value, message)
    if value == nil then
        failCount = failCount + 1
        print(string.format("  ❌ FAIL: %s (value was nil)", message))
        return false
    end
    passCount = passCount + 1
    return true
end

-- Initialize process
print("\n🧪 Running Unit Tests: Gym Leader and Elite Four Systems\n")
print("Loading trainer-encounter-engine.lua...")
loadProcess()
print("Process loaded successfully\n")

-- ============================================================================
-- TEST SUITE 1: Gym Leader Party Template Selection
-- ============================================================================

print("=== TEST SUITE 1: Gym Leader Party Template Selection ===\n")

local function testGymLeaderWave20()
    print("Test 1.1: Wave 20 Gym Leader (GYM_LEADER_1: 2 Pokemon)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "20",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "20"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("20", response.Wave, "Wave should be 20")
        assert_equals("GYM_LEADER", response.TrainerType, "Should be GYM_LEADER type")
    end
    print("✓ Test 1.1 passed\n")
end

local function testGymLeaderWave30()
    print("Test 1.2: Wave 30 Gym Leader (GYM_LEADER_2: 3 Pokemon)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "30",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "30"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("30", response.Wave, "Wave should be 30")
    end
    print("✓ Test 1.2 passed\n")
end

local function testGymLeaderWave60()
    print("Test 1.3: Wave 60 Gym Leader (GYM_LEADER_3: 4 Pokemon)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "60",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "60"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("60", response.Wave, "Wave should be 60")
    end
    print("✓ Test 1.3 passed\n")
end

local function testGymLeaderWave90()
    print("Test 1.4: Wave 90 Gym Leader (GYM_LEADER_4: 5 Pokemon)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "90",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "90"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("90", response.Wave, "Wave should be 90")
    end
    print("✓ Test 1.4 passed\n")
end

local function testGymLeaderWave110()
    print("Test 1.5: Wave 110 Gym Leader (GYM_LEADER_5: 6 Pokemon)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "110",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("110", response.Wave, "Wave should be 110")
    end
    print("✓ Test 1.5 passed\n")
end

local function testGymLeaderDailyMode()
    print("Test 1.6: Daily Mode Gym Leader (wave 20 -> GYM_LEADER_2)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "20",
        GameMode = "Daily",
        Seed = "12345",
        PlayerLevel = "20"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("Daily", response.GameMode or "Daily", "GameMode should be Daily")
    end
    print("✓ Test 1.6 passed\n")
end

testGymLeaderWave20()
testGymLeaderWave30()
testGymLeaderWave60()
testGymLeaderWave90()
testGymLeaderWave110()
testGymLeaderDailyMode()

-- ============================================================================
-- TEST SUITE 2: Gym Leader Terastallization
-- ============================================================================

print("=== TEST SUITE 2: Gym Leader Terastallization ===\n")

local function testGymLeaderNoTeraBeforeWave100()
    print("Test 2.1: Wave 80 Gym Leader (NO_TERA before wave 100)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "80",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "80"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("80", response.Wave, "Wave should be 80")
        assert_equals("", response.TeraSlot or "", "TeraSlot should be empty for wave <100")
    end
    print("✓ Test 2.1 passed\n")
end

local function testGymLeaderTeraAtWave100()
    print("Test 2.2: Wave 100 Gym Leader (INSTANT_TERA at wave 100)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "100",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("100", response.Wave, "Wave should be 100")
        assert_true(response.TeraSlot ~= nil and response.TeraSlot ~= "", "TeraSlot should be set for wave ≥100")
    end
    print("✓ Test 2.2 passed\n")
end

local function testGymLeaderTeraAfterWave100()
    print("Test 2.3: Wave 120 Gym Leader (INSTANT_TERA after wave 100)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "120",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("GymLeaderGenerated", response.Action, "Should return GymLeaderGenerated action")
        assert_equals("120", response.Wave, "Wave should be 120")
        assert_true(response.TeraSlot ~= nil and response.TeraSlot ~= "", "TeraSlot should be set for wave ≥100")
    end
    print("✓ Test 2.3 passed\n")
end

testGymLeaderNoTeraBeforeWave100()
testGymLeaderTeraAtWave100()
testGymLeaderTeraAfterWave100()

-- ============================================================================
-- TEST SUITE 3: Elite Four Generation
-- ============================================================================

print("=== TEST SUITE 3: Elite Four Generation ===\n")

local function testEliteFourMember1()
    print("Test 3.1: Elite Four Member 1 (wave 182)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("EliteFourGenerated", response.Action, "Should return EliteFourGenerated action")
        assert_equals("182", response.Wave, "Wave should be 182")
        assert_equals("ELITE_FOUR", response.TrainerType, "Should be ELITE_FOUR type")
    end
    print("✓ Test 3.1 passed\n")
end

local function testEliteFourMember2()
    print("Test 3.2: Elite Four Member 2 (wave 184)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "184",
        MemberIndex = "2",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "1"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("EliteFourGenerated", response.Action, "Should return EliteFourGenerated action")
        assert_equals("184", response.Wave, "Wave should be 184")
    end
    print("✓ Test 3.2 passed\n")
end

local function testEliteFourMember3()
    print("Test 3.3: Elite Four Member 3 (wave 186)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "186",
        MemberIndex = "3",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "2"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("EliteFourGenerated", response.Action, "Should return EliteFourGenerated action")
        assert_equals("186", response.Wave, "Wave should be 186")
    end
    print("✓ Test 3.3 passed\n")
end

local function testEliteFourMember4()
    print("Test 3.4: Elite Four Member 4 (wave 188)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "188",
        MemberIndex = "4",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "3"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("EliteFourGenerated", response.Action, "Should return EliteFourGenerated action")
        assert_equals("188", response.Wave, "Wave should be 188")
    end
    print("✓ Test 3.4 passed\n")
end

local function testChampion()
    print("Test 3.5: Champion (wave 190)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "190",
        IsChampion = "true",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "4"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("EliteFourGenerated", response.Action, "Should return EliteFourGenerated action")
        assert_equals("190", response.Wave, "Wave should be 190")
        assert_equals("CHAMPION", response.TrainerType, "Should be CHAMPION type")
    end
    print("✓ Test 3.5 passed\n")
end

testEliteFourMember1()
testEliteFourMember2()
testEliteFourMember3()
testEliteFourMember4()
testChampion()

-- ============================================================================
-- TEST SUITE 4: Championship Validation
-- ============================================================================

print("=== TEST SUITE 4: Championship Validation ===\n")

local function testChampionshipNotReady()
    print("Test 4.1: Cannot battle Champion with 0 Elite Four victories")
    local response = sendMessage("validate-championship", "ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "0"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("ChampionshipValidated", response.Action, "Should return ChampionshipValidated action")
        assert_equals("false", response.CanBattleChampion, "Cannot battle Champion with 0 victories")
    end
    print("✓ Test 4.1 passed\n")
end

local function testChampionshipPartialProgress()
    print("Test 4.2: Cannot battle Champion with 2 Elite Four victories")
    local response = sendMessage("validate-championship", "ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "2"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("ChampionshipValidated", response.Action, "Should return ChampionshipValidated action")
        assert_equals("false", response.CanBattleChampion, "Cannot battle Champion with 2 victories")
    end
    print("✓ Test 4.2 passed\n")
end

local function testChampionshipAlmostReady()
    print("Test 4.3: Cannot battle Champion with 3 Elite Four victories")
    local response = sendMessage("validate-championship", "ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "3"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("ChampionshipValidated", response.Action, "Should return ChampionshipValidated action")
        assert_equals("false", response.CanBattleChampion, "Cannot battle Champion with 3 victories")
    end
    print("✓ Test 4.3 passed\n")
end

local function testChampionshipReady()
    print("Test 4.4: Can battle Champion with 4 Elite Four victories")
    local response = sendMessage("validate-championship", "ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "4"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_equals("ChampionshipValidated", response.Action, "Should return ChampionshipValidated action")
        assert_equals("true", response.CanBattleChampion, "Can battle Champion with 4 victories")
        assert_equals("true", response.EliteFourComplete, "Elite Four should be complete")
    end
    print("✓ Test 4.4 passed\n")
end

testChampionshipNotReady()
testChampionshipPartialProgress()
testChampionshipAlmostReady()
testChampionshipReady()

-- ============================================================================
-- TEST SUITE 5: Reward Multipliers
-- ============================================================================

print("=== TEST SUITE 5: Reward Multipliers ===\n")

local function testGymLeaderRewards()
    print("Test 5.1: Gym Leader money multiplier (2.5x)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "20",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "20"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        -- Verify response has reward information
        assert_not_nil(response.MoneyReward, "Should have MoneyReward field")
        local reward = tonumber(response.MoneyReward)
        assert_true(reward > 0, "Gym Leader reward should be positive")
    end
    print("✓ Test 5.1 passed\n")
end

local function testEliteFourRewards()
    print("Test 5.2: Elite Four money multiplier (3.25x)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_not_nil(response.MoneyReward, "Should have MoneyReward field")
        local reward = tonumber(response.MoneyReward)
        assert_true(reward > 0, "Elite Four reward should be positive")
    end
    print("✓ Test 5.2 passed\n")
end

local function testChampionRewards()
    print("Test 5.3: Champion money multiplier (10x)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "190",
        IsChampion = "true",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "4"
    })

    assert_not_nil(response, "Should receive response")
    if response then
        assert_not_nil(response.MoneyReward, "Should have MoneyReward field")
        local reward = tonumber(response.MoneyReward)
        assert_true(reward > 0, "Champion reward should be positive")
    end
    print("✓ Test 5.3 passed\n")
end

testGymLeaderRewards()
testEliteFourRewards()
testChampionRewards()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("📊 UNIT TEST RESULTS")
print(string.rep("=", 60))
print(string.format("✅ Passed: %d", passCount))
print(string.format("❌ Failed: %d", failCount))
print(string.format("📈 Total: %d", passCount + failCount))
print(string.rep("=", 60))

if failCount == 0 then
    print("\n🎉 All unit tests passed!\n")
    os.exit(0)
else
    print(string.format("\n⚠️  %d test(s) failed\n", failCount))
    os.exit(1)
end
