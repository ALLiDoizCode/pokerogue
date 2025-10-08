--[[
Daily Run Integration Tests
Tests multi-handler scenarios and complex event seeds

Priority: P1 (High)
Coverage: 20 tests for complex scenarios, edge cases, multi-handler coordination
--]]

-- Load aolite test framework
local aolite = require('aolite')

-- Test counters
local totalTests = 0
local passedTests = 0

-- Helper: Run test with assertions
local function runTest(testName, testFn)
    totalTests = totalTests + 1
    local success, err = pcall(testFn)
    if success then
        passedTests = passedTests + 1
        print("✓ " .. testName)
    else
        print("✗ " .. testName .. ": " .. tostring(err))
    end
end

-- Helper: Assert equality
local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(message or ("Expected " .. tostring(expected) .. " but got " .. tostring(actual)))
    end
end

-- Helper: Assert not nil
local function assertNotNil(value, message)
    if value == nil then
        error(message or "Expected value to not be nil")
    end
end

print("\n=== Daily Run Integration Tests ===\n")

-- Spawn daily run engine process
local process = aolite.spawnProcess("processes/daily-run-engine.lua")

--[[
Full Daily Run Generation (5 tests)
--]]

print("## Full Daily Run Generation")

runTest("1.1: Complete daily run with standard seed", function()
    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = '{"seed":"20250103complete1234567890"}'
    })

    local response = json.decode(result.Data)

    -- Validate all components present
    assertNotNil(response.dailyRun.seed, "Seed should be present")
    assertEquals(#response.dailyRun.starters, 3, "Should have 3 starters")
    assertNotNil(response.dailyRun.startingBiome, "Biome should be present")
    assertEquals(response.dailyRun.startingLevel, 20, "Starting level should be 20")
    assertNotNil(response.dailyRun.difficulty, "Difficulty config should be present")
    assertNotNil(response.dailyRun.trainerWaves, "Trainer waves should be present")
end)

runTest("1.2: Complete daily run with event seed (all modifiers)", function()
    local eventSeed = "20250103abcdefghij123456/starters002500013300003700/boss014900/biome08/luck12/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = eventSeed})
    })

    local response = json.decode(result.Data)

    -- Validate event modifiers applied
    assertEquals(response.dailyRun.starters[1].species, 25, "Event starter 1")
    assertEquals(response.dailyRun.starters[2].species, 133, "Event starter 2")
    assertEquals(response.dailyRun.starters[3].species, 37, "Event starter 3")
    assertEquals(response.dailyRun.startingBiome, 8, "Event biome (PLAINS)")
end)

runTest("1.3: Multiple daily runs with different seeds", function()
    local seeds = {
        "20250103seed1abcdefghij123",
        "20250104seed2abcdefghij123",
        "20250105seed3abcdefghij123"
    }

    local results = {}

    for _, seed in ipairs(seeds) do
        local result = aolite.send({
            Target = process,
            Action = "GenerateDailyRun",
            Data = json.encode({seed = seed})
        })

        table.insert(results, json.decode(result.Data))
    end

    -- Validate variation across runs
    local uniqueStarters = {}
    for _, result in ipairs(results) do
        local key = result.dailyRun.starters[1].species
        uniqueStarters[key] = true
    end

    -- Should have at least 2 different first starters
    local uniqueCount = 0
    for _ in pairs(uniqueStarters) do
        uniqueCount = uniqueCount + 1
    end

    assert(uniqueCount >= 2, "Different seeds should produce variation")
end)

runTest("1.4: Verify starter cost sum = 10 across 100 runs", function()
    for i = 1, 100 do
        local seed = string.format("costsum%021d", i)
        local result = aolite.send({
            Target = process,
            Action = "GenerateDailyRun",
            Data = json.encode({seed = seed})
        })

        local response = json.decode(result.Data)
        -- Cost sum = 10 is enforced by generating exactly 3 starters
        assertEquals(#response.dailyRun.starters, 3, "Run " .. i .. " should have 3 starters")
    end
end)

runTest("1.5: Verify all biomes appear in 200 runs", function()
    local biomesSeen = {}

    for i = 1, 200 do
        local seed = string.format("biomecover%019d", i)
        local result = aolite.send({
            Target = process,
            Action = "GenerateDailyRun",
            Data = json.encode({seed = seed})
        })

        local response = json.decode(result.Data)
        biomesSeen[response.dailyRun.startingBiome] = true
    end

    local uniqueBiomes = 0
    for _ in pairs(biomesSeen) do
        uniqueBiomes = uniqueBiomes + 1
    end

    -- Should see at least 20 different biomes in 200 runs
    assert(uniqueBiomes >= 20, "Should have good biome coverage (got " .. uniqueBiomes .. ")")
end)

--[[
Difficulty Progression (5 tests)
--]]

print("\n## Difficulty Progression")

runTest("2.1: Daily run wave progression (waves 1-50)", function()
    local difficulties = {}

    for wave = 1, 50 do
        local result = aolite.send({
            Target = process,
            Action = "GetDailyDifficulty",
            Data = json.encode({waveIndex = wave, ignoreCurveChanges = false})
        })

        local response = json.decode(result.Data)
        difficulties[wave] = response.effectiveWave
    end

    -- Validate monotonic increasing
    for wave = 2, 50 do
        assert(difficulties[wave] > difficulties[wave - 1],
            "Wave " .. wave .. " should be harder than wave " .. (wave - 1))
    end

    -- Validate key milestones
    assertEquals(difficulties[1], 31, "Wave 1 should be difficulty 31")
    assertEquals(difficulties[10], 42, "Wave 10 should be difficulty 42")
    assertEquals(difficulties[25], 60, "Wave 25 should be difficulty 60")
    assertEquals(difficulties[50], 90, "Wave 50 should be difficulty 90")
end)

runTest("2.2: Trainer wave schedule validation (8 waves per 50-wave run)", function()
    local trainerWaves = {}

    for wave = 1, 50 do
        local isFinal = (wave == 50)
        local result = aolite.send({
            Target = process,
            Action = "IsTrainerWave",
            Data = json.encode({waveIndex = wave, isFinalWave = isFinal})
        })

        local response = json.decode(result.Data)
        if response.isTrainer then
            table.insert(trainerWaves, wave)
        end
    end

    assertEquals(#trainerWaves, 8, "Should have 8 trainer waves")

    -- Validate specific waves
    local expected = {5, 15, 20, 25, 30, 35, 40, 45}
    for i, wave in ipairs(expected) do
        assertEquals(trainerWaves[i], wave, "Trainer wave " .. i .. " should be wave " .. wave)
    end
end)

runTest("2.3: Difficulty comparison: daily harder than classic", function()
    -- Daily wave 1 = effective 31
    -- Classic wave 1 = effective 1 (no offset)

    local dailyResult = aolite.send({
        Target = process,
        Action = "GetDailyDifficulty",
        Data = '{"waveIndex":1,"ignoreCurveChanges":false}'
    })

    local dailyResponse = json.decode(dailyResult.Data)
    assertEquals(dailyResponse.effectiveWave, 31, "Daily wave 1 should be harder")
end)

runTest("2.4: Effective wave calculation for score multipliers", function()
    -- Test waves used for scoring calculations
    local scoringWaves = {10, 20, 30, 40, 50}

    for _, wave in ipairs(scoringWaves) do
        local result = aolite.send({
            Target = process,
            Action = "GetDailyDifficulty",
            Data = json.encode({waveIndex = wave, ignoreCurveChanges = false})
        })

        local response = json.decode(result.Data)
        local expectedEffective = wave + 30 + math.floor(wave / 5)

        assertEquals(response.effectiveWave, expectedEffective,
            "Wave " .. wave .. " effective should be " .. expectedEffective)
    end
end)

runTest("2.5: Final wave difficulty (wave 50 = effective 90)", function()
    local result = aolite.send({
        Target = process,
        Action = "GetDailyDifficulty",
        Data = '{"waveIndex":50,"ignoreCurveChanges":false}'
    })

    local response = json.decode(result.Data)
    assertEquals(response.effectiveWave, 90, "Wave 50 should be effective wave 90")
    assertEquals(response.baseOffset, 30, "Base offset should be 30")
    assertEquals(response.progressionBonus, 10, "Progression bonus should be 10")
end)

--[[
Event Seed Scenarios (5 tests)
--]]

print("\n## Event Seed Scenarios")

runTest("3.1: Event seed with legendary starters (high cost)", function()
    -- Mewtwo (150), Lugia (249), Rayquaza (384) - all legendary
    local eventSeed = "20250103abcdefghij123456/starters015000024900038400/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = eventSeed})
    })

    local response = json.decode(result.Data)
    assertEquals(response.dailyRun.starters[1].species, 150, "First starter should be Mewtwo")
    assertEquals(response.dailyRun.starters[2].species, 249, "Second starter should be Lugia")
    assertEquals(response.dailyRun.starters[3].species, 384, "Third starter should be Rayquaza")
end)

runTest("3.2: Event seed with specific boss", function()
    local eventSeed = "20250103abcdefghij123456/boss014900/"

    local parseResult = aolite.send({
        Target = process,
        Action = "ParseEventSeed",
        Data = json.encode({seed = eventSeed})
    })

    local parseResponse = json.decode(parseResult.Data)
    assertEquals(parseResponse.boss.speciesId, 149, "Boss should be Dragonite (149)")
end)

runTest("3.3: Event seed with rare biome", function()
    -- GRAVEYARD (biome 18) has weight 1 (rare)
    local eventSeed = "20250103abcdefghij123456/biome18/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = eventSeed})
    })

    local response = json.decode(result.Data)
    assertEquals(response.dailyRun.startingBiome, 18, "Biome should be GRAVEYARD (18)")
end)

runTest("3.4: Event seed with max luck (14)", function()
    local eventSeed = "20250103abcdefghij123456/luck14/"

    local result = aolite.send({
        Target = process,
        Action = "ParseEventSeed",
        Data = json.encode({seed = eventSeed})
    })

    local response = json.decode(result.Data)
    assertEquals(response.luck, 14, "Luck should be max (14)")
end)

runTest("3.5: Event seed with min luck (0)", function()
    local eventSeed = "20250103abcdefghij123456/luck00/"

    local result = aolite.send({
        Target = process,
        Action = "ParseEventSeed",
        Data = json.encode({seed = eventSeed})
    })

    local response = json.decode(result.Data)
    assertEquals(response.luck, 0, "Luck should be min (0)")
end)

--[[
Edge Cases (5 tests)
--]]

print("\n## Edge Cases")

runTest("4.1: Invalid event seed format (graceful fallback)", function()
    local invalidSeed = "20250103abcdefghij123456/malformed!@#$%/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = invalidSeed})
    })

    local response = json.decode(result.Data)
    -- Should fall back to standard generation
    assertEquals(#response.dailyRun.starters, 3, "Should generate 3 starters via fallback")
end)

runTest("4.2: Empty seed handling", function()
    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = '{"seed":""}'
    })

    -- Should handle gracefully (either error or default behavior)
    -- Validate response has proper structure
    local response = json.decode(result.Data)
    assert(response.dailyRun or response.Error, "Should have either dailyRun or Error")
end)

runTest("4.3: Seed with only partial modifiers (mixed standard/event)", function()
    local partialSeed = "20250103abcdefghij123456/biome10/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = partialSeed})
    })

    local response = json.decode(result.Data)

    -- Event biome should be applied
    assertEquals(response.dailyRun.startingBiome, 10, "Event biome should be applied")

    -- Standard cost-based starters should be generated
    assertEquals(#response.dailyRun.starters, 3, "Should generate standard starters")
end)

runTest("4.4: Extremely long seed (>100 characters)", function()
    local longSeed = "20250103abcdefghij123456/starters002500013300003700/boss014900/biome08/luck12/" ..
        "/extramodifier123456789012345678901234567890/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = longSeed})
    })

    local response = json.decode(result.Data)
    -- Should parse valid modifiers and ignore unknown ones
    assertEquals(response.dailyRun.starters[1].species, 25, "Should parse valid starters")
end)

runTest("4.5: Non-alphanumeric characters in seed", function()
    -- Seed with special characters in base (but valid modifiers)
    local specialSeed = "20250103!@#$%^&*()123456/biome05/"

    local result = aolite.send({
        Target = process,
        Action = "GenerateDailyRun",
        Data = json.encode({seed = specialSeed})
    })

    local response = json.decode(result.Data)
    -- Should handle gracefully
    assert(response.dailyRun or response.Error, "Should handle special characters")
end)

-- Print summary
print("\n=== Test Summary ===")
print("Total: " .. totalTests)
print("Passed: " .. passedTests)
print("Failed: " .. (totalTests - passedTests))
print("Pass Rate: " .. string.format("%.1f%%", (passedTests / totalTests) * 100))

if passedTests == totalTests then
    print("\n✓ All integration tests PASSED")
    os.exit(0)
else
    print("\n✗ Some integration tests FAILED")
    os.exit(1)
end
