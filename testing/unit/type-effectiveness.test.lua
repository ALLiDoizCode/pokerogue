-- Type Effectiveness Unit Tests
-- Tests for AI Move Selection Type System (Story 17.1a)
-- Framework: aolite (local AO emulation)

local aolite = require("aolite")
local json = require("json")

-- Test constants
local TEST_PROCESS_PATH = "processes/ai-move-selection-engine.lua"

-- Pokemon type constants (matching process)
local PokemonType = {
    UNKNOWN = -1,
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 9,
    WATER = 10,
    GRASS = 11,
    ELECTRIC = 12,
    PSYCHIC = 13,
    ICE = 14,
    DRAGON = 15,
    DARK = 16,
    FAIRY = 17,
    STELLAR = 18
}

-- Ability constants
local Ability = {
    VOLT_ABSORB = 10,
    WATER_ABSORB = 11,
    FLASH_FIRE = 18,
    WONDER_GUARD = 25,
    LEVITATE = 26,
    LIGHTNING_ROD = 31,
    THICK_FAT = 71,
    HEATPROOF = 85,
    DRY_SKIN = 87,
    SAP_SIPPER = 113,
    STORM_DRAIN = 114
}

-- Test suite
local function runTests()
    print("====================================")
    print("Type Effectiveness Unit Tests")
    print("====================================\n")

    local passCount = 0
    local failCount = 0

    -- Helper function to run a test
    local function test(name, fn)
        local success, err = pcall(fn)
        if success then
            print("✅ PASS: " .. name)
            passCount = passCount + 1
        else
            print("❌ FAIL: " .. name)
            print("   Error: " .. tostring(err))
            failCount = failCount + 1
        end
    end

    -- Helper to assert equality with tolerance
    local function assertApprox(actual, expected, tolerance, message)
        tolerance = tolerance or 0.001
        if math.abs(actual - expected) > tolerance then
            error(message or string.format("Expected %f, got %f", expected, actual))
        end
    end

    -- Spawn AI move selection process
    local processId = aolite.spawnProcess(TEST_PROCESS_PATH)
    print("Process spawned: " .. processId .. "\n")

    -- ========================================================================
    -- TEST CATEGORY 1: Basic Type Matchups (5 tests)
    -- ========================================================================

    test("1.1 Normal effectiveness (Water vs Fire)", function()
        local testData = {
            move = { type = PokemonType.WATER, power = 100, category = 1 },
            attacker = { types = {PokemonType.WATER}, battlerIndex = 0 },
            target = { types = {PokemonType.FIRE}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "1",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        -- Water vs Fire = 2x effectiveness
        -- Score should be 100 * 2 = 200 (before STAB)
        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        assertApprox(score, 200, 0.1, "Water vs Fire should be 2x effective")
    end)

    test("1.2 Super effective (Electric vs Water)", function()
        local testData = {
            move = { type = PokemonType.ELECTRIC, power = 90, category = 1 },
            attacker = { types = {PokemonType.ELECTRIC}, battlerIndex = 0 },
            target = { types = {PokemonType.WATER}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "2",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Electric vs Water = 2x, with STAB = 2 * 1.5 = 3x
        -- Score: 90 * 3 = 270
        assertApprox(score, 270, 0.1, "Electric vs Water with STAB should be 3x")
    end)

    test("1.3 Not very effective (Grass vs Fire)", function()
        local testData = {
            move = { type = PokemonType.GRASS, power = 80, category = 1 },
            attacker = { types = {PokemonType.GRASS}, battlerIndex = 0 },
            target = { types = {PokemonType.FIRE}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "3",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Grass vs Fire = 0.5x, with STAB = 0.5 * 1.5 = 0.75x
        -- Score: 80 * 0.75 = 60
        assertApprox(score, 60, 0.1, "Grass vs Fire with STAB should be 0.75x")
    end)

    test("1.4 Immune (Normal vs Ghost)", function()
        local testData = {
            move = { type = PokemonType.NORMAL, power = 100, category = 0 },
            attacker = { types = {PokemonType.NORMAL}, battlerIndex = 0 },
            target = { types = {PokemonType.GHOST}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "4",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Normal vs Ghost = 0x (immune), score becomes 0, then -20 per logic
        assertApprox(score, -20, 0.1, "Normal vs Ghost should be immune (-20 score)")
    end)

    test("1.5 Neutral effectiveness (Fighting vs Normal)", function()
        local testData = {
            move = { type = PokemonType.FIGHTING, power = 100, category = 0 },
            attacker = { types = {PokemonType.NORMAL}, battlerIndex = 0 },
            target = { types = {PokemonType.NORMAL}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "5",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Fighting vs Normal = 2x (super effective), no STAB
        -- Score: 100 * 2 = 200
        assertApprox(score, 200, 0.1, "Fighting vs Normal should be 2x effective")
    end)

    -- ========================================================================
    -- TEST CATEGORY 2: Dual-Type Calculations (4 tests)
    -- ========================================================================

    test("2.1 Double weakness (Electric vs Water/Flying - Gyarados)", function()
        local testData = {
            move = { type = PokemonType.ELECTRIC, power = 90, category = 1 },
            attacker = { types = {PokemonType.ELECTRIC}, battlerIndex = 0 },
            target = { types = {PokemonType.WATER, PokemonType.FLYING}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "6",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Electric vs Water/Flying = 2 * 2 = 4x, with STAB = 4 * 1.5 = 6x
        -- Score: 90 * 6 = 540
        assertApprox(score, 540, 0.1, "Electric vs Water/Flying should be 6x with STAB")
    end)

    test("2.2 Neutral dual-type (Normal vs Rock/Ground)", function()
        local testData = {
            move = { type = PokemonType.NORMAL, power = 100, category = 0 },
            attacker = { types = {PokemonType.NORMAL}, battlerIndex = 0 },
            target = { types = {PokemonType.ROCK, PokemonType.GROUND}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "7",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Normal vs Rock = 0.5x, Normal vs Ground = 1x
        -- Total: 0.5 * 1 = 0.5x, with STAB = 0.5 * 1.5 = 0.75x
        -- Score: 100 * 0.75 = 75
        assertApprox(score, 75, 0.1, "Normal vs Rock/Ground should be 0.75x with STAB")
    end)

    test("2.3 Double resistance (Grass vs Steel/Water)", function()
        local testData = {
            move = { type = PokemonType.GRASS, power = 100, category = 1 },
            attacker = { types = {PokemonType.GRASS}, battlerIndex = 0 },
            target = { types = {PokemonType.STEEL, PokemonType.WATER}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "8",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Grass vs Steel = 0.5x, Grass vs Water = 2x
        -- Total: 0.5 * 2 = 1x (neutral), with STAB = 1 * 1.5 = 1.5x
        -- Score: 100 * 1.5 = 150
        assertApprox(score, 150, 0.1, "Grass vs Steel/Water should be 1.5x with STAB")
    end)

    test("2.4 Immunity overrides (Ground vs Flying/Electric)", function()
        local testData = {
            move = { type = PokemonType.GROUND, power = 100, category = 0 },
            attacker = { types = {PokemonType.GROUND}, battlerIndex = 0 },
            target = { types = {PokemonType.FLYING, PokemonType.ELECTRIC}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "9",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Ground vs Flying = 0 (immune), Ground vs Electric = 2x
        -- Total: 0 * 2 = 0 (immunity overrides everything)
        -- Score becomes -20 per logic
        assertApprox(score, -20, 0.1, "Ground vs Flying should be immune (-20)")
    end)

    -- ========================================================================
    -- TEST CATEGORY 3: Ability Immunities (3 tests)
    -- ========================================================================

    test("3.1 Levitate immunity (Ground vs Levitate)", function()
        local testData = {
            move = { type = PokemonType.GROUND, power = 100, category = 0 },
            attacker = { types = {PokemonType.GROUND}, battlerIndex = 0 },
            target = { types = {PokemonType.ELECTRIC}, battlerIndex = 2, hp = 100, ability = Ability.LEVITATE }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "10",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Levitate makes Ground 0x (immune)
        assertApprox(score, -20, 0.1, "Levitate should grant Ground immunity")
    end)

    test("3.2 Flash Fire immunity (Fire vs Flash Fire)", function()
        local testData = {
            move = { type = PokemonType.FIRE, power = 90, category = 1 },
            attacker = { types = {PokemonType.FIRE}, battlerIndex = 0 },
            target = { types = {PokemonType.STEEL}, battlerIndex = 2, hp = 100, ability = Ability.FLASH_FIRE }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "11",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Flash Fire makes Fire 0x (immune)
        assertApprox(score, -20, 0.1, "Flash Fire should grant Fire immunity")
    end)

    test("3.3 Thick Fat resistance (Fire vs Thick Fat)", function()
        local testData = {
            move = { type = PokemonType.FIRE, power = 100, category = 1 },
            attacker = { types = {PokemonType.FIRE}, battlerIndex = 0 },
            target = { types = {PokemonType.NORMAL}, battlerIndex = 2, hp = 100, ability = Ability.THICK_FAT }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "12",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Thick Fat makes Fire 0.5x effective
        -- Base: 1x (Normal has no interaction), Thick Fat: 1 * 0.5 = 0.5x
        -- With STAB: 0.5 * 1.5 = 0.75x
        -- Score: 100 * 0.75 = 75
        assertApprox(score, 75, 0.1, "Thick Fat should halve Fire effectiveness")
    end)

    -- ========================================================================
    -- TEST CATEGORY 4: Edge Cases (3 tests)
    -- ========================================================================

    test("4.1 UNKNOWN type handling", function()
        local testData = {
            move = { type = PokemonType.UNKNOWN, power = 100, category = 0 },
            attacker = { types = {PokemonType.NORMAL}, battlerIndex = 0 },
            target = { types = {PokemonType.NORMAL}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "13",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- UNKNOWN type defaults to 1x effectiveness
        -- Score: 100 * 1 = 100
        assertApprox(score, 100, 0.1, "UNKNOWN type should default to 1x")
    end)

    test("4.2 Stellar type (no interactions)", function()
        local testData = {
            move = { type = PokemonType.FIRE, power = 100, category = 1 },
            attacker = { types = {PokemonType.FIRE}, battlerIndex = 0 },
            target = { types = {PokemonType.STELLAR}, battlerIndex = 2, hp = 100 }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "14",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Stellar type has no special interactions (1x)
        -- With STAB: 1 * 1.5 = 1.5x
        -- Score: 100 * 1.5 = 150
        assertApprox(score, 150, 0.1, "Stellar type should have neutral effectiveness")
    end)

    test("4.3 Wonder Guard (only super-effective hits)", function()
        local testData = {
            move = { type = PokemonType.NORMAL, power = 100, category = 0 },
            attacker = { types = {PokemonType.NORMAL}, battlerIndex = 0 },
            target = { types = {PokemonType.BUG, PokemonType.GHOST}, battlerIndex = 2, hp = 100, ability = Ability.WONDER_GUARD }
        }

        local response = aolite.send({
            Target = processId,
            Action = "CalculateMoveBenefit",
            MoveId = "15",
            AttackerId = "1",
            TargetId = "2",
            Data = json.encode(testData)
        })

        assert(response.Success == "true", "Request failed")
        local score = tonumber(response.Score)
        -- Normal vs Bug/Ghost = 0 (Ghost immune)
        -- Wonder Guard blocks any non-super-effective hit
        -- Score becomes -20
        assertApprox(score, -20, 0.1, "Wonder Guard should block non-super-effective moves")
    end)

    -- ========================================================================
    -- SUMMARY
    -- ========================================================================

    print("\n====================================")
    print("Test Summary")
    print("====================================")
    print(string.format("Total: %d | Passed: %d | Failed: %d", passCount + failCount, passCount, failCount))

    if failCount == 0 then
        print("\n✅ ALL TESTS PASSED")
        return 0
    else
        print("\n❌ SOME TESTS FAILED")
        return 1
    end
end

-- Run tests
local exitCode = runTests()
os.exit(exitCode)
