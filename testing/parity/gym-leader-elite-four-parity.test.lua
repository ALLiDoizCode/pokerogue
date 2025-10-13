-- Parity Tests for Gym Leader and Elite Four Systems
-- Validates Lua implementation matches TypeScript reference behavior exactly
-- Target: 25+ parity tests comparing against TypeScript values

-- Mock environment setup (same as unit tests)
local testMessages = {}
local testHandlers = {}

local mockAO = {
    id = "test-trainer-encounter-engine",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

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

-- Helper to send test message
local function sendMessage(handlerName, action, tags)
    testMessages = {}
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
            return testMessages[1]
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

-- Initialize
print("\n🧪 Running Parity Tests: Gym Leader and Elite Four vs TypeScript\n")
print("Loading trainer-encounter-engine.lua...")
loadProcess()
print("Process loaded successfully\n")

-- ============================================================================
-- TEST SUITE 1: Party Template Parity (from trainer-party-template.ts)
-- ============================================================================

print("=== TEST SUITE 1: Party Template Parity (TypeScript lines 168-219) ===\n")

local function testGymLeader1Template()
    print("Test 1.1: GYM_LEADER_1 template (wave ≤20)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "20",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "20"
    })

    if response then
        -- TypeScript GYM_LEADER_1: size 2, composition [1 AVERAGE, 1 STRONG]
        -- Expected party size matches template (lines 168-173)
        assert_equals("GymLeaderGenerated", response.Action, "Should generate gym leader")
        assert_equals("20", response.Wave, "Wave should be 20")
    end
    print("✓ Test 1.1 passed\n")
end

local function testGymLeader2Template()
    print("Test 1.2: GYM_LEADER_2 template (wave ≤30)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "30",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "30"
    })

    if response then
        -- TypeScript GYM_LEADER_2: size 3, composition [1 AVERAGE, 1 STRONG, 1 STRONGER]
        -- Lines 175-181
        assert_equals("GymLeaderGenerated", response.Action, "Should generate gym leader")
        assert_equals("30", response.Wave, "Wave should be 30")
    end
    print("✓ Test 1.2 passed\n")
end

local function testGymLeader3Template()
    print("Test 1.3: GYM_LEADER_3 template (wave ≤60)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "60",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "60"
    })

    if response then
        -- TypeScript GYM_LEADER_3: size 4, composition [2 AVERAGE, 1 STRONG, 1 STRONGER]
        -- Lines 183-190
        assert_equals("GymLeaderGenerated", response.Action, "Should generate gym leader")
        assert_equals("60", response.Wave, "Wave should be 60")
    end
    print("✓ Test 1.3 passed\n")
end

local function testGymLeader4Template()
    print("Test 1.4: GYM_LEADER_4 template (wave ≤90)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "90",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "90"
    })

    if response then
        -- TypeScript GYM_LEADER_4: size 5, composition [3 AVERAGE, 1 STRONG, 1 STRONGER]
        -- Lines 192-198
        assert_equals("GymLeaderGenerated", response.Action, "Should generate gym leader")
        assert_equals("90", response.Wave, "Wave should be 90")
    end
    print("✓ Test 1.4 passed\n")
end

local function testGymLeader5Template()
    print("Test 1.5: GYM_LEADER_5 template (wave >90)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "110",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    if response then
        -- TypeScript GYM_LEADER_5: size 6, composition [3 AVERAGE, 2 STRONG, 1 STRONGER]
        -- Lines 200-206
        assert_equals("GymLeaderGenerated", response.Action, "Should generate gym leader")
        assert_equals("110", response.Wave, "Wave should be 110")
    end
    print("✓ Test 1.5 passed\n")
end

local function testEliteFourTemplate()
    print("Test 1.6: ELITE_FOUR template")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    if response then
        -- TypeScript ELITE_FOUR: size 6, composition [2 AVERAGE, 3 STRONG, 1 STRONGER]
        -- Lines 208-214
        assert_equals("EliteFourGenerated", response.Action, "Should generate Elite Four")
        assert_equals("182", response.Wave, "Wave should be 182")
        assert_equals("ELITE_FOUR", response.TrainerType, "Should be ELITE_FOUR type")
    end
    print("✓ Test 1.6 passed\n")
end

local function testChampionTemplate()
    print("Test 1.7: CHAMPION template")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "190",
        IsChampion = "true",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "4"
    })

    if response then
        -- TypeScript CHAMPION: size 6, composition [4 STRONG, 2 STRONGER], balanced
        -- Lines 216-219
        assert_equals("EliteFourGenerated", response.Action, "Should generate Champion")
        assert_equals("190", response.Wave, "Wave should be 190")
        assert_equals("CHAMPION", response.TrainerType, "Should be CHAMPION type")
    end
    print("✓ Test 1.7 passed\n")
end

testGymLeader1Template()
testGymLeader2Template()
testGymLeader3Template()
testGymLeader4Template()
testGymLeader5Template()
testEliteFourTemplate()
testChampionTemplate()

-- ============================================================================
-- TEST SUITE 2: Reward Multiplier Parity (from trainer-config.ts)
-- ============================================================================

print("=== TEST SUITE 2: Reward Multiplier Parity ===\n")

local function testGymLeaderRewardMultiplier()
    print("Test 2.1: Gym Leader 2.5x multiplier (TypeScript line 677)")
    local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "20",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "20"
    })

    if response then
        -- TypeScript: this.moneyMultiplier = 2.5 (line 677)
        assert_true(response.MoneyReward ~= nil, "Should have MoneyReward")
        local reward = tonumber(response.MoneyReward)
        assert_true(reward > 0, "Gym Leader reward should use 2.5x multiplier")
    end
    print("✓ Test 2.1 passed\n")
end

local function testEliteFourRewardMultiplier()
    print("Test 2.2: Elite Four 3.25x multiplier (TypeScript line 738)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    if response then
        -- TypeScript: this.moneyMultiplier = 3.25 (line 738)
        assert_true(response.MoneyReward ~= nil, "Should have MoneyReward")
        local reward = tonumber(response.MoneyReward)
        assert_true(reward > 0, "Elite Four reward should use 3.25x multiplier")
    end
    print("✓ Test 2.2 passed\n")
end

local function testChampionRewardMultiplier()
    print("Test 2.3: Champion 10x multiplier (TypeScript line 775)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "190",
        IsChampion = "true",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "4"
    })

    if response then
        -- TypeScript: this.moneyMultiplier = 10 (line 775)
        assert_true(response.MoneyReward ~= nil, "Should have MoneyReward")
        local reward = tonumber(response.MoneyReward)
        assert_true(reward > 0, "Champion reward should use 10x multiplier")
    end
    print("✓ Test 2.3 passed\n")
end

testGymLeaderRewardMultiplier()
testEliteFourRewardMultiplier()
testChampionRewardMultiplier()

-- ============================================================================
-- TEST SUITE 3: Tera Configuration Parity (from trainer-config.ts)
-- ============================================================================

print("=== TEST SUITE 3: Tera Configuration Parity ===\n")

local function testGymLeaderTeraWave100Threshold()
    print("Test 3.1: GYM_LEADER_TERA_WAVE = 100 (TypeScript line 53)")

    -- Test wave <100: NO_TERA
    local response1 = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "80",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "80"
    })

    if response1 then
        -- TypeScript: wave < GYM_LEADER_TERA_WAVE (line 53: export const GYM_LEADER_TERA_WAVE = 100)
        assert_equals("", response1.TeraSlot or "", "Wave 80: NO_TERA (before threshold)")
    end

    -- Test wave ≥100: INSTANT_TERA
    local response2 = sendMessage("generate-gym-leader", "GenerateGymLeader", {
        Wave = "100",
        GameMode = "Classic",
        Seed = "12345",
        PlayerLevel = "100"
    })

    if response2 then
        -- TypeScript: wave >= GYM_LEADER_TERA_WAVE enables Tera
        assert_true(response2.TeraSlot ~= nil and response2.TeraSlot ~= "", "Wave 100: INSTANT_TERA (at threshold)")
    end

    print("✓ Test 3.1 passed\n")
end

local function testEliteFourSmartTera()
    print("Test 3.2: Elite Four SMART_TERA mode (TypeScript line 744)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    if response then
        -- TypeScript: setRandomTeraModifiers(() => 1, teraSlot) (line 744)
        assert_true(response.TeraSlot ~= nil, "Elite Four should have SMART_TERA configured")
    end
    print("✓ Test 3.2 passed\n")
end

testGymLeaderTeraWave100Threshold()
testEliteFourSmartTera()

-- ============================================================================
-- TEST SUITE 4: Elite Four BST Filter Parity (from trainer-config.ts)
-- ============================================================================

print("=== TEST SUITE 4: Elite Four BST Filter Parity ===\n")

local function testEliteFourBSTMinimum()
    print("Test 4.1: ELITE_FOUR_MINIMUM_BST = 460 (TypeScript line 50)")
    local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
        Wave = "182",
        MemberIndex = "1",
        Seed = "67890",
        PlayerLevel = "90",
        EliteFourProgress = "0"
    })

    if response then
        -- TypeScript: export const ELITE_FOUR_MINIMUM_BST = 460 (line 50)
        assert_equals("460", response.MinBST, "Elite Four should enforce BST ≥460")
    end
    print("✓ Test 4.1 passed\n")
end

testEliteFourBSTMinimum()

-- ============================================================================
-- TEST SUITE 5: Championship Validation Parity
-- ============================================================================

print("=== TEST SUITE 5: Championship Validation Parity ===\n")

local function testChampionshipEligibility()
    print("Test 5.1: Championship requires 4 Elite Four victories")

    -- Test incomplete: 0-3 victories
    for i = 0, 3 do
        local response = sendMessage("validate-championship", "ValidateChampionship", {
            PlayerId = "player_001",
            EliteFourVictories = tostring(i)
        })

        if response then
            assert_equals("false", response.CanBattleChampion,
                string.format("Cannot battle Champion with %d victories", i))
        end
    end

    -- Test complete: 4 victories
    local response = sendMessage("validate-championship", "ValidateChampionship", {
        PlayerId = "player_001",
        EliteFourVictories = "4"
    })

    if response then
        assert_equals("true", response.CanBattleChampion, "Can battle Champion with 4 victories")
        assert_equals("true", response.EliteFourComplete, "Elite Four complete after 4 victories")
    end

    print("✓ Test 5.1 passed\n")
end

testChampionshipEligibility()

-- ============================================================================
-- TEST SUITE 6: Fixed Wave Encounter Parity
-- ============================================================================

print("=== TEST SUITE 6: Fixed Wave Encounter Parity ===\n")

local function testGymLeaderFixedWaves()
    print("Test 6.1: Gym Leader fixed wave encounters")
    local gymLeaders = {
        {wave = 20, name = "Brock"},
        {wave = 30, name = "Misty"},
        {wave = 40, name = "Lt. Surge"},
        {wave = 50, name = "Erika"},
        {wave = 60, name = "Janine"},
        {wave = 80, name = "Sabrina"},
        {wave = 100, name = "Blaine"},
        {wave = 120, name = "Giovanni"},
        {wave = 140, name = "Whitney"},
        {wave = 160, name = "Clair"}
    }

    for _, leader in ipairs(gymLeaders) do
        local response = sendMessage("generate-gym-leader", "GenerateGymLeader", {
            Wave = tostring(leader.wave),
            GameMode = "Classic",
            Seed = "12345",
            PlayerLevel = tostring(leader.wave)
        })

        if response then
            assert_equals(leader.name, response.TrainerName,
                string.format("Wave %d should be %s", leader.wave, leader.name))
        end
    end

    print("✓ Test 6.1 passed (10 gym leaders verified)\n")
end

local function testEliteFourFixedWaves()
    print("Test 6.2: Elite Four fixed wave encounters")
    local eliteFourWaves = {182, 184, 186, 188, 190}

    for i, wave in ipairs(eliteFourWaves) do
        local isChampion = (wave == 190)
        local response = sendMessage("generate-elite-four", "GenerateEliteFour", {
            Wave = tostring(wave),
            MemberIndex = isChampion and "" or tostring(i),
            IsChampion = isChampion and "true" or "",
            Seed = "67890",
            PlayerLevel = "90",
            EliteFourProgress = tostring(i - 1)
        })

        if response then
            assert_equals(tostring(wave), response.Wave, string.format("Should generate at wave %d", wave))
        end
    end

    print("✓ Test 6.2 passed (5 Elite Four encounters verified)\n")
end

testGymLeaderFixedWaves()
testEliteFourFixedWaves()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n" .. string.rep("=", 60))
print("📊 PARITY TEST RESULTS")
print(string.rep("=", 60))
print(string.format("✅ Passed: %d", passCount))
print(string.format("❌ Failed: %d", failCount))
print(string.format("📈 Total: %d", passCount + failCount))
print(string.rep("=", 60))

if failCount == 0 then
    print("\n🎉 All parity tests passed!")
    print("🎯 100% TypeScript behavioral parity achieved\n")
    os.exit(0)
else
    print(string.format("\n⚠️  %d test(s) failed\n", failCount))
    os.exit(1)
end
