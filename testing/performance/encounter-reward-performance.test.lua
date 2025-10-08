-- Performance Tests: Encounter Reward Engine
-- Validates execution time constraints for all handlers

package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

local tests = {}
local currentTest = ""

local function assert(condition, message)
    if not condition then error(currentTest .. " FAILED: " .. message) end
end

local function setup()
    return aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
end

-- Benchmark helper
local function benchmark(name, fn, maxTimeMs)
    local startTime = os.clock()
    fn()
    local endTime = os.clock()
    local elapsedMs = (endTime - startTime) * 1000

    assert(elapsedMs < maxTimeMs,
        name .. " exceeded " .. maxTimeMs .. "ms (took " .. string.format("%.2f", elapsedMs) .. "ms)")

    return elapsedMs
end

-- ============================================================================
-- Performance Test: CalculateRewards
-- ============================================================================

tests["CalculateRewards execution time < 5ms"] = function()
    currentTest = "CalculateRewards execution time < 5ms"
    local process = setup()

    local elapsed = benchmark("CalculateRewards", function()
        local msg = {
            From = "perf_test",
            Action = "CalculateRewards",
            EncounterType = "MYSTERIOUS_CHEST",
            OptionIndex = "0",
            Outcome = "success",
            WaveIndex = "50"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 5)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: CalculateConsequences
-- ============================================================================

tests["CalculateConsequences execution time < 3ms"] = function()
    currentTest = "CalculateConsequences execution time < 3ms"
    local process = setup()

    local partyState = {
        pokemon = {{id = 1, hp = 100}, {id = 2, hp = 80}},
        money = 5000
    }

    local elapsed = benchmark("CalculateConsequences", function()
        local msg = {
            From = "perf_test",
            Action = "CalculateConsequences",
            EncounterType = "MYSTERIOUS_CHEST",
            OptionIndex = "0",
            Outcome = "failure",
            PartyState = aolite.json.encode(partyState)
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 3)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: CalculateExpReward
-- ============================================================================

tests["CalculateExpReward execution time < 2ms"] = function()
    currentTest = "CalculateExpReward execution time < 2ms"
    local process = setup()

    local elapsed = benchmark("CalculateExpReward", function()
        local msg = {
            From = "perf_test",
            Action = "CalculateExpReward",
            BaseExpValue = "100",
            WaveIndex = "50",
            UseWaveIndex = "true",
            ParticipantIds = "1,2,3"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 2)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: CalculateItemRewards
-- ============================================================================

tests["CalculateItemRewards execution time < 5ms"] = function()
    currentTest = "CalculateItemRewards execution time < 5ms"
    local process = setup()

    local elapsed = benchmark("CalculateItemRewards", function()
        local msg = {
            From = "perf_test",
            Action = "CalculateItemRewards",
            EncounterType = "MYSTERIOUS_CHEST",
            RewardTier = "RARE",
            GuaranteedModifiers = "POTION,REVIVE",
            AllowLuckUpgrades = "true",
            RerollMultiplier = "1"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 5)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: Batch Processing
-- ============================================================================

tests["Batch 100 reward calculations in < 500ms"] = function()
    currentTest = "Batch 100 reward calculations in < 500ms"
    local process = setup()

    local elapsed = benchmark("Batch 100 calculations", function()
        for i = 1, 100 do
            local msg = {
                From = "perf_test",
                Action = "CalculateRewards",
                EncounterType = "MYSTERIOUS_CHEST",
                OptionIndex = "0",
                Outcome = "success",
                WaveIndex = tostring(i)
            }
            aolite.send(msg, process)
        end
        aolite.runScheduler(process)
    end, 500)

    print(string.format("✓ %s (%.2fms total, %.2fms avg)", currentTest, elapsed, elapsed / 100))
end

-- ============================================================================
-- Performance Test: CalculateRewardRarity
-- ============================================================================

tests["CalculateRewardRarity execution time < 2ms"] = function()
    currentTest = "CalculateRewardRarity execution time < 2ms"
    local process = setup()

    local elapsed = benchmark("CalculateRewardRarity", function()
        local msg = {
            From = "perf_test",
            Action = "CalculateRewardRarity",
            BaseRarity = "COMMON",
            WaveIndex = "100",
            LuckValue = "7"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 2)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: MitigateConsequence
-- ============================================================================

tests["MitigateConsequence execution time < 2ms"] = function()
    currentTest = "MitigateConsequence execution time < 2ms"
    local process = setup()

    local factors = {defenseBonus = 3, protectiveItems = true}

    local elapsed = benchmark("MitigateConsequence", function()
        local msg = {
            From = "perf_test",
            Action = "MitigateConsequence",
            ConsequenceType = "DAMAGE",
            BaseValue = "100",
            MitigationFactors = aolite.json.encode(factors)
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 2)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: ValidateOutcome
-- ============================================================================

tests["ValidateOutcome execution time < 1ms"] = function()
    currentTest = "ValidateOutcome execution time < 1ms"
    local process = setup()

    local elapsed = benchmark("ValidateOutcome", function()
        local msg = {
            From = "perf_test",
            Action = "ValidateOutcome",
            ResultValue = "75",
            Threshold = "50"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 1)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Performance Test: Info Handler
-- ============================================================================

tests["Info handler execution time < 1ms"] = function()
    currentTest = "Info handler execution time < 1ms"
    local process = setup()

    local elapsed = benchmark("Info handler", function()
        local msg = {
            From = "perf_test",
            Action = "Info"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)
    end, 1)

    print(string.format("✓ %s (%.2fms)", currentTest, elapsed))
end

-- ============================================================================
-- Run all performance tests
-- ============================================================================

local function runTests()
    local passed, failed = 0, 0
    local totalTime = 0

    print("\n=== Encounter Reward Performance Tests ===")
    print("Validating execution time constraints\n")

    for name, test in pairs(tests) do
        local startTime = os.clock()
        local success, err = pcall(test)
        local endTime = os.clock()

        if success then
            passed = passed + 1
            totalTime = totalTime + ((endTime - startTime) * 1000)
        else
            failed = failed + 1
            print("✗ " .. name .. ": " .. err)
        end
    end

    print("\n=== Performance Test Summary ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))
    print(string.format("Total execution time: %.2fms", totalTime))

    if failed == 0 then
        print("\n✓ All performance benchmarks met!")
        return 0
    else
        print("\n✗ Some performance benchmarks failed")
        return 1
    end
end

return runTests()
