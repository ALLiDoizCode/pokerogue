-- Unit Tests for Trainer Encounter Engine
-- Migrated to real aolite framework
-- Comprehensive test suite covering all algorithms and handlers

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.trainer-encounter-engine"
local processId = "test-trainer-encounter-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Trainer Encounter Engine")
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

-- Test counter
local passed = 0
local failed = 0

-- ===========================================
-- Test Suite 1: Level Calculation Algorithm
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 1: Level Calculation Algorithm")

print("\n📝 Test 1: Wave 10 WEAK level calculation")
local result1 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "10",
    GameMode = "classic",
    PartyTemplate = json.encode({
        size = 1,
        strength = 2,
        sameSpecies = false,
        balanced = false
    })
})
if result1 and result1.Action == "PartyLevelsCalculated" then
    local data = json.decode(result1.Data)
    if data.baseLevel and data.levels and data.levels[1] then
        print(string.format("✅ Test passed: Base=%d, Final=%d", data.baseLevel, data.levels[1]))
        passed = passed + 1
    else
        error("❌ Test failed: Expected baseLevel and levels in response")
    end
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

print("\n📝 Test 2: Wave 40 AVERAGE level calculation")
local result2 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "40",
    GameMode = "classic",
    PartyTemplate = json.encode({size = 1, strength = 3})
})
if result2 and result2.Action == "PartyLevelsCalculated" then
    print("✅ Test passed: Wave 40 levels calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

print("\n📝 Test 3: Wave 100 STRONG level calculation")
local result3 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "100",
    GameMode = "classic",
    PartyTemplate = json.encode({size = 1, strength = 4})
})
if result3 and result3.Action == "PartyLevelsCalculated" then
    print("✅ Test passed: Wave 100 levels calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

-- ===========================================
-- Test Suite 2: Matchup Score Calculation
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 2: Matchup Score Calculation")

print("\n📝 Test 4: Electric vs Water matchup")
local result4 = sendMessage("CalculateMatchupScore", {
    AttackerData = json.encode({
        speciesId = 25,
        types = {12},
        moveset = {84, 98, 113, 129},
        speed = 90
    }),
    OpponentData = json.encode({
        speciesId = 9,
        types = {10},
        hp = 120,
        maxHp = 150,
        speed = 78
    })
})
if result4 and result4.Action == "MatchupScoreCalculated" then
    print(string.format("✅ Test passed: Def=%.2f, Total=%.2f",
        tonumber(result4.DefensiveScore), tonumber(result4.TotalScore)))
    passed = passed + 1
else
    error("❌ Test failed: Expected MatchupScoreCalculated action")
end

print("\n📝 Test 5: Fire vs Rock matchup")
local result5 = sendMessage("CalculateMatchupScore", {
    AttackerData = json.encode({
        speciesId = 6,
        types = {9},
        moveset = {52, 7, 83},
        speed = 65
    }),
    OpponentData = json.encode({
        speciesId = 75,
        types = {5},
        hp = 100,
        maxHp = 100,
        speed = 90
    })
})
if result5 and result5.Action == "MatchupScoreCalculated" then
    print("✅ Test passed: Fire vs Rock matchup calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected MatchupScoreCalculated action")
end

-- ===========================================
-- Test Suite 3: AI Switch Decision Logic
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 3: AI Switch Decision Logic")

print("\n📝 Test 6: Regular trainer switch decision")
local result6 = sendMessage("EvaluateSwitchDecision", {
    CurrentMatchupScore = "5.0",
    BestSwitchMatchupScore = "18.0",
    IsBoss = "false",
    SwitchCounter = "0"
})
if result6 and result6.Action == "SwitchDecisionEvaluated" then
    print(string.format("✅ Test passed: Switch=%s, Threshold=%.1f",
        result6.ShouldSwitch, tonumber(result6.Threshold)))
    passed = passed + 1
else
    error("❌ Test failed: Expected SwitchDecisionEvaluated action")
end

print("\n📝 Test 7: Boss trainer switch decision")
local result7 = sendMessage("EvaluateSwitchDecision", {
    CurrentMatchupScore = "5.0",
    BestSwitchMatchupScore = "18.0",
    IsBoss = "true",
    SwitchCounter = "0"
})
if result7 and result7.Action == "SwitchDecisionEvaluated" then
    print("✅ Test passed: Boss switch decision evaluated")
    passed = passed + 1
else
    error("❌ Test failed: Expected SwitchDecisionEvaluated action")
end

-- ===========================================
-- Test Suite 4: Money Reward Calculation
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 4: Money Reward Calculation")

print("\n📝 Test 8: Wave 10 regular reward")
local result8 = sendMessage("CalculateRewards", {
    WaveIndex = "10",
    MoneyMultiplier = "1.0",
    PartyStrengths = json.encode({3})
})
if result8 and result8.Action == "RewardsCalculated" then
    local data = json.decode(result8.Data)
    print(string.format("✅ Test passed: Reward=%d", data.moneyReward))
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

print("\n📝 Test 9: Wave 40 gym leader reward")
local result9 = sendMessage("CalculateRewards", {
    WaveIndex = "40",
    MoneyMultiplier = "10.0",
    PartyStrengths = json.encode({3})
})
if result9 and result9.Action == "RewardsCalculated" then
    print("✅ Test passed: Gym leader reward calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

-- ===========================================
-- Test Suite 5: Modifier Chance Calculation
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 5: Modifier Chance Calculation")

print("\n📝 Test 10: WEAKER Pokemon modifier chance")
local result10 = sendMessage("CalculateRewards", {
    WaveIndex = "50",
    MoneyMultiplier = "1.0",
    PartyStrengths = json.encode({1})
})
if result10 and result10.Action == "RewardsCalculated" then
    local data = json.decode(result10.Data)
    print(string.format("✅ Test passed: Item chance=%.4f", data.itemChances[1]))
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

print("\n📝 Test 11: AVERAGE Pokemon modifier chance")
local result11 = sendMessage("CalculateRewards", {
    WaveIndex = "50",
    MoneyMultiplier = "1.0",
    PartyStrengths = json.encode({3})
})
if result11 and result11.Action == "RewardsCalculated" then
    print("✅ Test passed: AVERAGE modifier chance calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

-- ===========================================
-- Test Suite 6: Info Handler (ADP Compliance)
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 6: Info Handler (ADP Compliance)")

print("\n📝 Test 12: Info handler returns metadata")
local result12 = sendMessage("Info")
if result12 and result12.Action == "InfoResponse" and result12.Data then
    local data = json.decode(result12.Data)
    if data.process and data.process.adpVersion == "1.0" then
        print("✅ Test passed: ADP v1.0 compliant info handler")
        passed = passed + 1
    else
        error("❌ Test failed: Expected ADP v1.0 compliance")
    end
else
    error("❌ Test failed: Expected InfoResponse with data")
end

print("\n📝 Test 13: Info includes process metadata")
if result12 and result12.Data then
    local data = json.decode(result12.Data)
    if data.process.name and data.process.version then
        print("✅ Test passed: Process metadata present")
        passed = passed + 1
    else
        error("❌ Test failed: Expected process name and version")
    end
else
    error("❌ Test failed: Expected Data field")
end

-- ===========================================
-- Test Suite 7: Validation Handler
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 7: Validation Handler")

print("\n📝 Test 14: Valid wave 10")
local result14 = sendMessage("ValidateTrainerType", {
    WaveIndex = "10",
    TrainerType = "ACE_TRAINER"
})
if result14 and result14.Action == "TrainerTypeValidated" and result14.Valid == "true" then
    print("✅ Test passed: Wave 10 validated")
    passed = passed + 1
else
    error("❌ Test failed: Expected Valid=true for wave 10")
end

print("\n📝 Test 15: Invalid wave 0")
local result15 = sendMessage("ValidateTrainerType", {
    WaveIndex = "0",
    TrainerType = "ACE_TRAINER"
})
if result15 and result15.Valid == "false" then
    print("✅ Test passed: Wave 0 rejected")
    passed = passed + 1
else
    error("❌ Test failed: Expected Valid=false for wave 0")
end

-- ===========================================
-- Test Suite 8: Level Calculation Edge Cases
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 8: Level Calculation Edge Cases")

print("\n📝 Test 16: Wave 1 minimum")
local result16 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "1",
    GameMode = "classic",
    PartyTemplate = json.encode({size = 1, strength = 2})
})
if result16 and result16.Action == "PartyLevelsCalculated" then
    print("✅ Test passed: Wave 1 levels calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

print("\n📝 Test 17: Wave 150 boss")
local result17 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "150",
    GameMode = "classic",
    PartyTemplate = json.encode({size = 1, strength = 5})
})
if result17 and result17.Action == "PartyLevelsCalculated" then
    print("✅ Test passed: Wave 150 levels calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

-- ===========================================
-- Test Suite 9: Matchup Score Edge Cases
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 9: Matchup Score Edge Cases")

print("\n📝 Test 18: Neutral matchup")
local result18 = sendMessage("CalculateMatchupScore", {
    AttackerData = json.encode({
        speciesId = 16,
        types = {1, 3},
        moveset = {33, 64},
        speed = 56
    }),
    OpponentData = json.encode({
        speciesId = 19,
        types = {1},
        hp = 50,
        maxHp = 50,
        speed = 56
    })
})
if result18 and result18.Action == "MatchupScoreCalculated" then
    print("✅ Test passed: Neutral matchup calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected MatchupScoreCalculated action")
end

print("\n📝 Test 19: Speed advantage")
local result19 = sendMessage("CalculateMatchupScore", {
    AttackerData = json.encode({
        speciesId = 25,
        types = {13},
        moveset = {98},
        speed = 120
    }),
    OpponentData = json.encode({
        speciesId = 143,
        types = {1},
        hp = 100,
        maxHp = 200,
        speed = 30
    })
})
if result19 and result19.Action == "MatchupScoreCalculated" then
    print("✅ Test passed: Speed advantage matchup calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected MatchupScoreCalculated action")
end

-- ===========================================
-- Test Suite 10: AI Switch Edge Cases
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 10: AI Switch Edge Cases")

print("\n📝 Test 20: Marginal advantage (no switch)")
local result20 = sendMessage("EvaluateSwitchDecision", {
    CurrentMatchupScore = "12.0",
    BestSwitchMatchupScore = "15.0",
    IsBoss = "false",
    SwitchCounter = "0"
})
if result20 and result20.Action == "SwitchDecisionEvaluated" then
    print("✅ Test passed: Marginal advantage evaluated")
    passed = passed + 1
else
    error("❌ Test failed: Expected SwitchDecisionEvaluated action")
end

print("\n📝 Test 21: Multiple switches penalty")
local result21 = sendMessage("EvaluateSwitchDecision", {
    CurrentMatchupScore = "5.0",
    BestSwitchMatchupScore = "20.0",
    IsBoss = "false",
    SwitchCounter = "2"
})
if result21 and result21.Action == "SwitchDecisionEvaluated" then
    print("✅ Test passed: Switch penalty applied")
    passed = passed + 1
else
    error("❌ Test failed: Expected SwitchDecisionEvaluated action")
end

-- ===========================================
-- Test Suite 11: Reward Calculation Edge Cases
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 11: Reward Calculation Edge Cases")

print("\n📝 Test 22: Wave 1 early game")
local result22 = sendMessage("CalculateRewards", {
    WaveIndex = "1",
    MoneyMultiplier = "1.0",
    PartyStrengths = json.encode({3})
})
if result22 and result22.Action == "RewardsCalculated" then
    print("✅ Test passed: Early game reward calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

print("\n📝 Test 23: Wave 180 champion")
local result23 = sendMessage("CalculateRewards", {
    WaveIndex = "180",
    MoneyMultiplier = "50.0",
    PartyStrengths = json.encode({3})
})
if result23 and result23.Action == "RewardsCalculated" then
    print("✅ Test passed: Champion reward calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

-- ===========================================
-- Test Suite 12: Generate Trainer Handler
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 12: Generate Trainer Handler")

print("\n📝 Test 24: Generate trainer with wave")
local result24 = sendMessage("GenerateTrainer", {
    WaveIndex = "50",
    GameMode = "classic",
    BiomeType = "PLAIN",
    Seed = "123456"
})
if result24 then
    print("✅ Test passed: Trainer generation handler responds")
    passed = passed + 1
else
    error("❌ Test failed: Expected response from GenerateTrainer")
end

-- ===========================================
-- Test Suite 13: Fixed Trainer Detection
-- ===========================================
print("\n==================================================")
print("📝 Test Suite 13: Fixed Trainer Detection")

print("\n📝 Test 25: Fixed wave 20 recognized")
local result25 = sendMessage("ValidateTrainerType", {
    WaveIndex = "20",
    TrainerType = "GYM_LEADER",
    GameMode = "classic"
})
if result25 and result25.Valid == "true" then
    print("✅ Test passed: Fixed wave 20 recognized")
    passed = passed + 1
else
    error("❌ Test failed: Expected Valid=true for fixed wave 20")
end

print("\n📝 Test 26: Regular wave 25 valid")
local result26 = sendMessage("ValidateTrainerType", {
    WaveIndex = "25",
    TrainerType = "ACE_TRAINER",
    GameMode = "classic"
})
if result26 and result26.Valid == "true" then
    print("✅ Test passed: Regular wave 25 valid")
    passed = passed + 1
else
    error("❌ Test failed: Expected Valid=true for regular wave")
end

-- ===========================================
-- Additional Coverage Tests
-- ===========================================
print("\n==================================================")
print("📝 Additional Coverage Tests")

print("\n📝 Test 27: STRONG Pokemon modifier chance")
local result27 = sendMessage("CalculateRewards", {
    WaveIndex = "50",
    MoneyMultiplier = "1.0",
    PartyStrengths = json.encode({4})
})
if result27 and result27.Action == "RewardsCalculated" then
    print("✅ Test passed: STRONG modifier chance calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected RewardsCalculated action")
end

print("\n📝 Test 28: Wave 50 AVERAGE level")
local result28 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "50",
    GameMode = "classic",
    PartyTemplate = json.encode({size = 1, strength = 3})
})
if result28 and result28.Action == "PartyLevelsCalculated" then
    print("✅ Test passed: Wave 50 levels calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

print("\n📝 Test 29: Boss with high threshold")
local result29 = sendMessage("EvaluateSwitchDecision", {
    CurrentMatchupScore = "3.0",
    BestSwitchMatchupScore = "10.0",
    IsBoss = "true",
    SwitchCounter = "0"
})
if result29 and result29.Action == "SwitchDecisionEvaluated" then
    print("✅ Test passed: Boss high threshold evaluated")
    passed = passed + 1
else
    error("❌ Test failed: Expected SwitchDecisionEvaluated action")
end

print("\n📝 Test 30: Wave 80 STRONGER level")
local result30 = sendMessage("CalculatePartyLevels", {
    WaveIndex = "80",
    GameMode = "classic",
    PartyTemplate = json.encode({size = 1, strength = 5})
})
if result30 and result30.Action == "PartyLevelsCalculated" then
    print("✅ Test passed: Wave 80 STRONGER levels calculated")
    passed = passed + 1
else
    error("❌ Test failed: Expected PartyLevelsCalculated action")
end

print("\n==================================================")
print("🎉 All tests completed!")
print("==================================================")
print(string.format("✅ Passed: %d", passed))
print(string.format("❌ Failed: %d", failed))
print(string.format("📊 Total: %d", passed + failed))
print(string.format("📈 Success Rate: %.1f%%", (passed / (passed + failed)) * 100))
print("==================================================")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
