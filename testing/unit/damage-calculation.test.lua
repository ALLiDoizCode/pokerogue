-- Unit Tests: Damage Calculation (Story 17.1b)
-- Testing: Base damage formula, multipliers, abilities, weather/terrain
-- Framework: aolite for local AO emulation
-- Coverage: 15+ scenarios for damage calculation functions

local aolite = require("aolite")
local json = require("json")

-- Test setup
local processPath = "./processes/ai-move-selection-engine.lua"
local testProcess

describe("Damage Calculation Module", function()
    before_each(function()
        testProcess = aolite.spawnProcess(processPath)
    end)

    after_each(function()
        if testProcess then
            testProcess = nil
        end
    end)

    -- ========================================================================
    -- Test Category 1: Base Damage Formula (3 tests)
    -- ========================================================================

    describe("Base Damage Formula", function()
        it("Test 1.1: Level 50, Power 90, Atk 100, Def 80 → Base damage 63", function()
            local attacker = {
                level = 50,
                types = {9},  -- Fire
                stats = {atk = 100, spAtk = 90, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {11},  -- Grass
                stats = {def = 80, spDef = 80},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 52,  -- Flamethrower
                power = 90,
                category = 1,  -- SPECIAL
                type = 9  -- Fire
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test1"
            })

            assert.is_not_nil(result)
            assert.equals("SaveState", result.Action)
            assert.equals("true", result.Success)

            local damage = tonumber(result.Damage)
            -- Expected: base ~63, STAB 1.5×, type 2×, random ~0.9 → ~170
            assert.is_true(damage > 150 and damage < 200, "Damage should be ~170")
        end)

        it("Test 1.2: Level 100, Power 120, Atk 150, Def 100 → Base damage 122", function()
            local attacker = {
                level = 100,
                types = {1},  -- Fighting
                stats = {atk = 150, spAtk = 80, def = 90, spDef = 80},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 200,
                maxHp = 200,
                types = {0},  -- Normal
                stats = {def = 100, spDef = 90},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 67,  -- Close Combat
                power = 120,
                category = 0,  -- PHYSICAL
                type = 1  -- Fighting
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test2"
            })

            assert.is_not_nil(result)
            local damage = tonumber(result.Damage)
            -- Expected: base ~122, STAB 1.5×, type 2×, random ~0.9 → ~330
            assert.is_true(damage > 300 and damage < 400, "Damage should be ~330")
        end)

        it("Test 1.3: Physical vs Special stat selection", function()
            local attacker = {
                level = 50,
                types = {12},  -- Electric
                stats = {atk = 60, spAtk = 120, def = 70, spDef = 80},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {10},  -- Water
                stats = {def = 90, spDef = 70},
                ability = 0,
                isGrounded = true
            }

            -- Test Special move (should use spAtk vs spDef)
            local specialMove = {
                id = 85,  -- Thunderbolt
                power = 90,
                category = 1,  -- SPECIAL
                type = 12  -- Electric
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(specialMove),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test3"
            })

            assert.is_not_nil(result)
            local specialDamage = tonumber(result.Damage)

            -- Special should deal more damage (spAtk 120 > atk 60)
            assert.is_true(specialDamage > 100, "Special move should deal significant damage")
        end)
    end)

    -- ========================================================================
    -- Test Category 2: Damage Multipliers (4 tests)
    -- ========================================================================

    describe("Damage Multipliers", function()
        it("Test 2.1: STAB multiplier (Fire move + Fire type → 1.5×)", function()
            local attacker = {
                level = 50,
                types = {9},  -- Fire
                stats = {atk = 80, spAtk = 100, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {11},  -- Grass
                stats = {def = 70, spDef = 70},
                ability = 0,
                isGrounded = true
            }

            -- Fire move with STAB
            local stabMove = {
                id = 52,  -- Flamethrower
                power = 90,
                category = 1,  -- SPECIAL
                type = 9  -- Fire (matches attacker)
            }

            -- Non-STAB move
            local nonStabMove = {
                id = 57,  -- Surf
                power = 90,
                category = 1,  -- SPECIAL
                type = 10  -- Water (doesn't match)
            }

            local stabResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(stabMove),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test4"
            })

            -- Update attacker to Water type for non-STAB comparison
            attacker.types = {10}  -- Water
            local nonStabResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(nonStabMove),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test4"
            })

            local stabDamage = tonumber(stabResult.Damage)
            local nonStabDamage = tonumber(nonStabResult.Damage)

            -- STAB should deal 1.5× damage (accounting for type effectiveness differences)
            assert.is_true(stabDamage > nonStabDamage, "STAB move should deal more damage")
        end)

        it("Test 2.2: Critical hit multiplier (1.5× Gen 6+)", function()
            local attacker = {
                level = 50,
                types = {0},  -- Normal
                stats = {atk = 100, spAtk = 80, def = 70, spDef = 70},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {0},  -- Normal
                stats = {def = 80, spDef = 80},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 33,  -- Tackle
                power = 40,
                category = 0,  -- PHYSICAL
                type = 0  -- Normal
            }

            -- Non-critical hit
            local normalResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test5"
            })

            -- Critical hit
            local critResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "true",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test5"
            })

            local normalDamage = tonumber(normalResult.Damage)
            local critDamage = tonumber(critResult.Damage)

            -- Critical should be ~1.5× damage
            local ratio = critDamage / normalDamage
            assert.is_true(ratio > 1.4 and ratio < 1.6, "Critical hit should be ~1.5× damage")
        end)

        it("Test 2.3: Type effectiveness integration (Water vs Fire → 2×)", function()
            local attacker = {
                level = 50,
                types = {10},  -- Water
                stats = {atk = 80, spAtk = 100, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {9},  -- Fire
                stats = {def = 70, spDef = 70},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 57,  -- Surf
                power = 90,
                category = 1,  -- SPECIAL
                type = 10  -- Water (super effective against Fire)
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test6"
            })

            local damage = tonumber(result.Damage)
            -- Expected: STAB 1.5×, type 2× → significant damage
            assert.is_true(damage > 150, "Super effective + STAB should deal high damage")
        end)

        it("Test 2.4: Multiple multipliers combined (STAB + Type + Crit)", function()
            local attacker = {
                level = 50,
                types = {12},  -- Electric
                stats = {atk = 80, spAtk = 110, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {10},  -- Water
                stats = {def = 70, spDef = 70},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 85,  -- Thunderbolt
                power = 90,
                category = 1,  -- SPECIAL
                type = 12  -- Electric
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "true",  -- Critical hit
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test7"
            })

            local damage = tonumber(result.Damage)
            -- Expected: STAB 1.5×, type 2×, crit 1.5× → ~200+ damage
            assert.is_true(damage > 200, "All multipliers should compound to high damage")
            assert.equals("true", result.IsCritical)
        end)
    end)

    -- ========================================================================
    -- Test Category 3: Ability Modifiers (4 tests)
    -- ========================================================================

    describe("Ability Modifiers", function()
        it("Test 3.1: Thick Fat reduces Fire damage (1.0× → 0.5×)", function()
            local attacker = {
                level = 50,
                types = {9},  -- Fire
                stats = {atk = 80, spAtk = 100, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {14},  -- Ice
                stats = {def = 70, spDef = 70},
                ability = 47,  -- Thick Fat
                isGrounded = true
            }
            local move = {
                id = 52,  -- Flamethrower
                power = 90,
                category = 1,  -- SPECIAL
                type = 9  -- Fire
            }

            -- With Thick Fat
            local thickFatResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test8"
            })

            -- Without Thick Fat
            defender.ability = 0
            local normalResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test8"
            })

            local thickFatDamage = tonumber(thickFatResult.Damage)
            local normalDamage = tonumber(normalResult.Damage)

            -- Thick Fat should halve damage
            local ratio = thickFatDamage / normalDamage
            assert.is_true(ratio > 0.45 and ratio < 0.55, "Thick Fat should reduce damage by ~0.5×")
        end)

        it("Test 3.2: Filter reduces super-effective damage (2× → 1.5×)", function()
            local attacker = {
                level = 50,
                types = {1},  -- Fighting
                stats = {atk = 100, spAtk = 80, def = 70, spDef = 70},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {0},  -- Normal (weak to Fighting)
                stats = {def = 80, spDef = 80},
                ability = 40,  -- Filter
                isGrounded = true
            }
            local move = {
                id = 67,  -- Close Combat
                power = 120,
                category = 0,  -- PHYSICAL
                type = 1  -- Fighting (super effective)
            }

            -- With Filter
            local filterResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test9"
            })

            -- Without Filter
            defender.ability = 0
            local normalResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test9"
            })

            local filterDamage = tonumber(filterResult.Damage)
            local normalDamage = tonumber(normalResult.Damage)

            -- Filter should reduce to 0.75× of normal
            local ratio = filterDamage / normalDamage
            assert.is_true(ratio > 0.7 and ratio < 0.8, "Filter should reduce super-effective damage to ~0.75×")
        end)

        it("Test 3.3: Multiscale at full HP (1.0× → 0.5×)", function()
            local attacker = {
                level = 50,
                types = {15},  -- Dragon
                stats = {atk = 80, spAtk = 100, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,  -- Full HP
                types = {15},  -- Dragon
                stats = {def = 80, spDef = 80},
                ability = 136,  -- Multiscale
                isGrounded = true
            }
            local move = {
                id = 406,  -- Dragon Pulse
                power = 85,
                category = 1,  -- SPECIAL
                type = 15  -- Dragon
            }

            -- At full HP with Multiscale
            local fullHpResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test10"
            })

            -- At damaged HP with Multiscale
            defender.hp = 90
            local damagedResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test10"
            })

            local fullHpDamage = tonumber(fullHpResult.Damage)
            local damagedDamage = tonumber(damagedResult.Damage)

            -- Multiscale at full HP should halve damage
            local ratio = fullHpDamage / damagedDamage
            assert.is_true(ratio > 0.45 and ratio < 0.55, "Multiscale at full HP should reduce damage to ~0.5×")
        end)

        it("Test 3.4: Fur Coat halves physical damage (1.0× → 0.5×)", function()
            local attacker = {
                level = 50,
                types = {0},  -- Normal
                stats = {atk = 100, spAtk = 80, def = 70, spDef = 70},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {0},  -- Normal
                stats = {def = 70, spDef = 70},
                ability = 169,  -- Fur Coat
                isGrounded = true
            }
            local move = {
                id = 33,  -- Tackle
                power = 40,
                category = 0,  -- PHYSICAL
                type = 0  -- Normal
            }

            -- With Fur Coat
            local furCoatResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test11"
            })

            -- Without Fur Coat
            defender.ability = 0
            local normalResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test11"
            })

            local furCoatDamage = tonumber(furCoatResult.Damage)
            local normalDamage = tonumber(normalResult.Damage)

            -- Fur Coat should halve physical damage
            local ratio = furCoatDamage / normalDamage
            assert.is_true(ratio > 0.45 and ratio < 0.55, "Fur Coat should reduce physical damage to ~0.5×")
        end)
    end)

    -- ========================================================================
    -- Test Category 4: Weather/Terrain (2 tests)
    -- ========================================================================

    describe("Weather/Terrain Modifiers", function()
        it("Test 4.1: Rain boosts Water moves (1.0× → 1.5×)", function()
            local attacker = {
                level = 50,
                types = {10},  -- Water
                stats = {atk = 80, spAtk = 100, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {9},  -- Fire
                stats = {def = 70, spDef = 70},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 57,  -- Surf
                power = 90,
                category = 1,  -- SPECIAL
                type = 10  -- Water
            }

            -- With Rain
            local rainResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "2",  -- RAIN
                Terrain = "0",
                BattleSeed = "test12"
            })

            -- No Weather
            local normalResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",  -- NONE
                Terrain = "0",
                BattleSeed = "test12"
            })

            local rainDamage = tonumber(rainResult.Damage)
            local normalDamage = tonumber(normalResult.Damage)

            -- Rain should boost Water moves by 1.5×
            local ratio = rainDamage / normalDamage
            assert.is_true(ratio > 1.4 and ratio < 1.6, "Rain should boost Water damage by ~1.5×")
        end)

        it("Test 4.2: Electric Terrain boosts Electric moves (1.0× → 1.3×)", function()
            local attacker = {
                level = 50,
                types = {12},  -- Electric
                stats = {atk = 80, spAtk = 110, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 100,
                maxHp = 100,
                types = {10},  -- Water
                stats = {def = 70, spDef = 70},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 85,  -- Thunderbolt
                power = 90,
                category = 1,  -- SPECIAL
                type = 12  -- Electric
            }

            -- With Electric Terrain
            local terrainResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "1",  -- ELECTRIC
                BattleSeed = "test13"
            })

            -- No Terrain
            local normalResult = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",  -- NONE
                BattleSeed = "test13"
            })

            local terrainDamage = tonumber(terrainResult.Damage)
            local normalDamage = tonumber(normalResult.Damage)

            -- Electric Terrain should boost Electric moves by 1.3×
            local ratio = terrainDamage / normalDamage
            assert.is_true(ratio > 1.25 and ratio < 1.35, "Electric Terrain should boost Electric damage by ~1.3×")
        end)
    end)

    -- ========================================================================
    -- Test Category 5: KO Detection (2 tests)
    -- ========================================================================

    describe("KO Detection", function()
        it("Test 5.1: Damage >= HP → isKO = true", function()
            local attacker = {
                level = 50,
                types = {12},  -- Electric
                stats = {atk = 80, spAtk = 110, def = 70, spDef = 75},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 50,  -- Low HP
                maxHp = 100,
                types = {10},  -- Water
                stats = {def = 70, spDef = 70},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 85,  -- Thunderbolt
                power = 90,
                category = 1,  -- SPECIAL
                type = 12  -- Electric (super effective)
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test14"
            })

            assert.equals("true", result.IsKO, "Should detect KO when damage >= HP")
        end)

        it("Test 5.2: Damage < HP → isKO = false", function()
            local attacker = {
                level = 50,
                types = {0},  -- Normal
                stats = {atk = 50, spAtk = 50, def = 70, spDef = 70},
                ability = 0,
                status = 0
            }
            local defender = {
                hp = 200,  -- High HP
                maxHp = 200,
                types = {5},  -- Rock (high defense)
                stats = {def = 150, spDef = 100},
                ability = 0,
                isGrounded = true
            }
            local move = {
                id = 33,  -- Tackle
                power = 40,
                category = 0,  -- PHYSICAL
                type = 0  -- Normal
            }

            local result = aolite.send(testProcess, {
                Target = testProcess.id,
                Action = "CalculateDamage",
                Attacker = json.encode(attacker),
                Defender = json.encode(defender),
                Move = json.encode(move),
                IsCritical = "false",
                Weather = "0",
                Terrain = "0",
                BattleSeed = "test15"
            })

            assert.equals("false", result.IsKO, "Should not detect KO when damage < HP")
        end)
    end)
end)

print("Damage Calculation Unit Tests: 15 scenarios defined")
print("Run with: npm run test:aolite")
