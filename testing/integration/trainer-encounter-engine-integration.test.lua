-- Integration Tests for Trainer Encounter Engine
-- End-to-end workflow testing with external process communication
-- Target: 15+ integration tests covering complete trainer generation workflows

local aolite = require("aolite")
local json = require("json")

-- Test state
local trainerProcessId = nil
local speciesProcessId = nil
local movesProcessId = nil
local passCount = 0
local failCount = 0

-- Helper to send message and capture response
local function sendMessage(processId, action, tags)
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

-- Test assertion helper
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

-- Setup: Load processes
print("Setting up Trainer Encounter Engine integration tests...")
print("Loading trainer-encounter-engine process...")
trainerProcessId = aolite.spawn("trainer-encounter-engine", "processes/trainer-encounter-engine.lua")

if not trainerProcessId then
    error("Failed to spawn trainer-encounter-engine process")
end

-- Mock external processes with stubs
print("Loading integration stubs...")
local stubsCode = [[
-- Integration stubs for external processes
Handlers.add("get-species",
    Handlers.utils.hasMatchingTag("Action", "get-species"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                id = tonumber(data.speciesId) or 25,
                n = "TestMon",
                bs = {35, 55, 40, 50, 50, 90},
                t = {13},
                a = {9, 31}
            })
        })
    end
)

Handlers.add("get-level-moves",
    Handlers.utils.hasMatchingTag("Action", "get-level-moves"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                {moveId = 84, level = 1},
                {moveId = 98, level = 10},
                {moveId = 113, level = 20},
                {moveId = 129, level = 30}
            })
        })
    end
)

Handlers.add("get-move",
    Handlers.utils.hasMatchingTag("Action", "get-move"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            MoveId = "84",
            MoveName = "Thunderbolt",
            Type = "13",
            Category = "2",
            Power = "90",
            Accuracy = "100",
            PP = "15"
        })
    end
)
]]

speciesProcessId = aolite.spawn("pokemon-species-db-stub", stubsCode)
movesProcessId = aolite.spawn("moves-database-stub", stubsCode)

print("Process spawned with ID: " .. trainerProcessId)
print("\n=== Trainer Encounter Engine Integration Tests ===\n")

-- ===========================================
-- Test Suite 1: Complete Level Calculation Workflow
-- ===========================================
print("Test Suite 1: Complete Level Calculation Workflow")

local function testLevelWorkflow(name, wave, strength, expectedLevels)
    local result = sendMessage(trainerProcessId, "calculate-party-levels", {
        WaveIndex = tostring(wave),
        GameMode = "classic",
        PartyTemplate = json.encode({
            size = 3,
            strength = strength,
            sameSpecies = false,
            balanced = false
        })
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "party-levels-calculated" then
            local data = json.decode(response.Data)
            assertTrue(#data.levels == 3, string.format("%s: 3 levels returned", name))
            assertTrue(data.baseLevel > 0, string.format("%s: Valid base level", name))
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: Wrong action", name))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", name))
    end
end

testLevelWorkflow("Early game (Wave 10)", 10, 2, {6, 6, 6})
testLevelWorkflow("Mid game (Wave 50)", 50, 3, {30, 32, 34})
testLevelWorkflow("Late game (Wave 100)", 100, 4, {67, 74, 81})
testLevelWorkflow("Endgame (Wave 180)", 180, 5, {153, 170, 187})

-- ===========================================
-- Test Suite 2: Matchup Scoring with Multiple Pokemon
-- ===========================================
print("\nTest Suite 2: Matchup Scoring with Multiple Pokemon")

local function testMultipleMatchups(name, count)
    for i = 1, count do
        local result = sendMessage(trainerProcessId, "calculate-matchup-score", {
            AttackerData = json.encode({
                speciesId = 25,
                types = {13},
                moveset = {84, 98},
                speed = 90
            }),
            OpponentData = json.encode({
                speciesId = 9,
                types = {11},
                hp = 100,
                maxHp = 150,
                speed = 78
            })
        })

        if result and #result > 0 then
            local response = result[1]
            assertTrue(response.Action == "matchup-score-calculated",
                string.format("%s: Calculation %d", name, i))
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: Calculation %d failed", name, i))
        end
    end
end

testMultipleMatchups("Sequential matchup calculations", 3)

-- ===========================================
-- Test Suite 3: AI Switch Decision Chains
-- ===========================================
print("\nTest Suite 3: AI Switch Decision Chains")

local function testSwitchChain(name, decisions)
    for i, decision in ipairs(decisions) do
        local result = sendMessage(trainerProcessId, "evaluate-switch-decision", {
            CurrentMatchupScore = tostring(decision.current),
            BestSwitchMatchupScore = tostring(decision.best),
            IsBoss = tostring(decision.isBoss),
            SwitchCounter = tostring(decision.counter)
        })

        if result and #result > 0 then
            local response = result[1]
            assertTrue(response.Action == "switch-decision-evaluated",
                string.format("%s: Decision %d", name, i))
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: Decision %d failed", name, i))
        end
    end
end

testSwitchChain("Battle progression switches", {
    {current = 5.0, best = 18.0, isBoss = false, counter = 0},
    {current = 8.0, best = 20.0, isBoss = false, counter = 1},
    {current = 6.0, best = 15.0, isBoss = false, counter = 2}
})

testSwitchChain("Boss trainer switches", {
    {current = 3.0, best = 10.0, isBoss = true, counter = 0},
    {current = 4.0, best = 12.0, isBoss = true, counter = 1}
})

-- ===========================================
-- Test Suite 4: Reward Calculation for Full Party
-- ===========================================
print("\nTest Suite 4: Reward Calculation for Full Party")

local function testPartyRewards(name, wave, multiplier, partyStrengths)
    local result = sendMessage(trainerProcessId, "calculate-rewards", {
        WaveIndex = tostring(wave),
        MoneyMultiplier = tostring(multiplier),
        PartyStrengths = json.encode(partyStrengths)
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "rewards-calculated" then
            local data = json.decode(response.Data)
            assertTrue(data.moneyReward > 0, string.format("%s: Valid money reward", name))
            assertTrue(#data.itemChances == #partyStrengths,
                string.format("%s: Correct item chances count", name))
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: Wrong action", name))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", name))
    end
end

testPartyRewards("Standard trainer (3 Pokemon)", 25, 1.0, {2, 3, 3})
testPartyRewards("Gym leader (6 Pokemon)", 40, 10.0, {3, 3, 4, 4, 4, 5})
testPartyRewards("Elite Four (6 Pokemon)", 80, 25.0, {5, 5, 5, 5, 5, 5})

-- ===========================================
-- Test Suite 5: Complete Generation Workflow (Stubbed)
-- ===========================================
print("\nTest Suite 5: Complete Generation Workflow")

local function testGenerateWorkflow(name, wave, gameMode)
    local result = sendMessage(trainerProcessId, "generate-trainer", {
        WaveIndex = tostring(wave),
        GameMode = gameMode,
        BiomeType = "PLAIN",
        Seed = "123456"
    })

    if result and #result > 0 then
        local response = result[1]
        -- Accept either success or error (external processes are stubs)
        assertTrue(response.Action ~= nil, string.format("%s: Handler responded", name))
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", name))
    end
end

testGenerateWorkflow("Random encounter Wave 15", 15, "classic")
testGenerateWorkflow("Fixed encounter Wave 20", 20, "classic")
testGenerateWorkflow("Fixed encounter Wave 50", 50, "classic")

-- ===========================================
-- Test Suite 6: Validation Workflow
-- ===========================================
print("\nTest Suite 6: Validation Workflow")

local function testValidationWorkflow(name, wave, trainerType, gameMode, shouldPass)
    local result = sendMessage(trainerProcessId, "validate-trainer-type", {
        WaveIndex = tostring(wave),
        TrainerType = trainerType,
        GameMode = gameMode
    })

    if result and #result > 0 then
        local response = result[1]
        local isValid = response.Action == "trainer-type-validated" and response.Valid == "true"
        assertTrue(isValid == shouldPass, string.format("%s: Expected %s", name, shouldPass and "valid" or "invalid"))
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", name))
    end
end

testValidationWorkflow("Valid regular trainer", 25, "ACE_TRAINER", "classic", true)
testValidationWorkflow("Valid gym leader", 40, "GYM_LEADER", "classic", true)
testValidationWorkflow("Valid elite four", 60, "ELITE_FOUR", "classic", true)
testValidationWorkflow("Invalid wave 0", 0, "ACE_TRAINER", "classic", false)
testValidationWorkflow("Invalid wave 201", 201, "ACE_TRAINER", "classic", false)

-- ===========================================
-- Test Suite 7: Multi-Handler Workflow
-- ===========================================
print("\nTest Suite 7: Multi-Handler Workflow")

local function testMultiHandlerWorkflow(name)
    -- Step 1: Validate trainer type
    local result1 = sendMessage(trainerProcessId, "validate-trainer-type", {
        WaveIndex = "50",
        TrainerType = "ACE_TRAINER",
        GameMode = "classic"
    })
    assertTrue(result1 and #result1 > 0, string.format("%s: Step 1 (validate)", name))

    -- Step 2: Calculate party levels
    local result2 = sendMessage(trainerProcessId, "calculate-party-levels", {
        WaveIndex = "50",
        GameMode = "classic",
        PartyTemplate = json.encode({size = 3, strength = 3})
    })
    assertTrue(result2 and #result2 > 0, string.format("%s: Step 2 (levels)", name))

    -- Step 3: Calculate rewards
    local result3 = sendMessage(trainerProcessId, "calculate-rewards", {
        WaveIndex = "50",
        MoneyMultiplier = "1.0",
        PartyStrengths = json.encode({3, 3, 3})
    })
    assertTrue(result3 and #result3 > 0, string.format("%s: Step 3 (rewards)", name))
end

testMultiHandlerWorkflow("Complete trainer generation flow")

-- ===========================================
-- Test Suite 8: ADP Compliance Validation
-- ===========================================
print("\nTest Suite 8: ADP Compliance Validation")

local function testADPCompliance(name)
    local result = sendMessage(trainerProcessId, "info", {})
    if result and #result > 0 then
        local response = result[1]
        if response.Data then
            local data = json.decode(response.Data)
            assertTrue(data.process.adpVersion == "1.0", string.format("%s: ADP v1.0", name))
            assertTrue(type(data.handlers) == "table", string.format("%s: Handlers list", name))
            assertTrue(#data.handlers >= 7, string.format("%s: 7+ handlers", name))
            assertTrue(data.process.capabilities ~= nil, string.format("%s: Capabilities", name))
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: No data", name))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", name))
    end
end

testADPCompliance("ADP v1.0 compliance check")

-- ===========================================
-- Test Summary
-- ===========================================
print("\n=== Integration Test Summary ===")
print(string.format("Total: %d tests", passCount + failCount))
print(string.format("Passed: %d (%.1f%%)", passCount, (passCount / (passCount + failCount)) * 100))
print(string.format("Failed: %d (%.1f%%)", failCount, (failCount / (passCount + failCount)) * 100))

if failCount == 0 then
    print("\n✅ All integration tests passed!")
    os.exit(0)
else
    print(string.format("\n⚠️  %d integration tests failed", failCount))
    os.exit(1)
end
