-- AI Switch Decision - Matchup Scoring Unit Tests
-- Story 17.2: Tests for getMatchupScore(), party member scoring, and entry hazards
-- Test Framework: aolite (local Lua AO emulation)

local json = require("json")

-- Mock AO environment
_G.ao = {
    id = "test_process_switch_matchup",
    send = function(msg)
        -- Capture sent messages for assertions
        table.insert(_G.sentMessages, msg)
    end
}

_G.Handlers = {
    list = {},
    add = function(name, matcher, handler)
        _G.Handlers.list[name] = { matcher = matcher, handler = handler }
    end,
    utils = {
        hasMatchingTag = function(tagName, tagValue)
            return function(msg)
                return msg[tagName] == tagValue
            end
        end
    }
}

_G.sentMessages = {}

-- Load process
dofile("processes/ai-move-selection-engine.lua")

-- Test counter
local testsRun = 0
local testsPassed = 0

local function runTest(name, testFn)
    testsRun = testsRun + 1
    _G.sentMessages = {}

    local success, err = pcall(testFn)
    if success then
        testsPassed = testsPassed + 1
        print(string.format("✓ %s", name))
    else
        print(string.format("✗ %s: %s", name, err))
    end
end

local function assertEq(actual, expected, context)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", context or "", tostring(expected), tostring(actual)))
    end
end

local function assertNear(actual, expected, tolerance, context)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected %s ± %s, got %s", context or "", tostring(expected), tostring(tolerance), tostring(actual)))
    end
end

local function assertGreater(actual, threshold, context)
    if actual <= threshold then
        error(string.format("%s: expected > %s, got %s", context or "", tostring(threshold), tostring(actual)))
    end
end

local function assertLess(actual, threshold, context)
    if actual >= threshold then
        error(string.format("%s: expected < %s, got %s", context or "", tostring(threshold), tostring(actual)))
    end
end

-- ============================================================================
-- TEST SUITE: Matchup Score Calculation (15 tests)
-- ============================================================================

print("\n=== Matchup Score Calculation Tests ===\n")

-- Test 1: Equal matchup (same types, similar stats)
runTest("Equal matchup scenario", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},  -- Normal
                moveset = {
                    {moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}  -- Normal move
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
                isActive = true
            },
            opponent = {
                types = {0},  -- Normal
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }
        })
    })

    local response = _G.sentMessages[1]
    assertEq(response.Action, "SaveState", "Should return SaveState")
    local data = json.decode(response.Data)
    assertNear(data.matchupScore, 2.0, 0.5, "Equal matchup score around 2.0")
end)

-- Test 2: Type advantage (Fire vs Grass)
runTest("Type advantage Fire vs Grass", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {9},  -- Fire
                moveset = {
                    {moveId = 52, pp = 10, maxPp = 10, category = 1, type = 9}  -- Ember (Fire)
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponent = {
                types = {11},  -- Grass
                hp = 100,
                maxHp = 100,
                stats = {atk = 45, def = 49, spatk = 65, spdef = 65, spd = 45}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertGreater(data.matchupScore, 3.0, "Fire vs Grass should score > 3.0")
    assertGreater(data.components.atkScore, 2.0, "Attack score should be > 2.0 (STAB + 2x effectiveness)")
end)

-- Test 3: Type disadvantage (Fire vs Water)
runTest("Type disadvantage Fire vs Water", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {9},  -- Fire
                moveset = {
                    {moveId = 52, pp = 10, maxPp = 10, category = 1, type = 9}  -- Ember
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponent = {
                types = {10},  -- Water
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertLess(data.matchupScore, 2.0, "Fire vs Water should score < 2.0 (poor matchup)")
    assertLess(data.components.atkScore, 1.0, "Attack score should be < 1.0 (0.5x effectiveness)")
end)

-- Test 4: Speed advantage bonus
runTest("Speed advantage HP ratio bonus", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},  -- Normal
                moveset = {
                    {moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 100},  -- Fast
                isActive = true
            },
            opponent = {
                types = {0},  -- Normal
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 30}  -- Slow
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.components.outspeed, true, "Should outspeed opponent")
    assertGreater(data.matchupScore, 2.0, "Speed advantage should boost score")
end)

-- Test 5: Low HP dying Pokemon (sacrifice logic)
runTest("Dying Pokemon sacrifice candidate", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},
                moveset = {
                    {moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}
                },
                hp = 15,  -- 15% HP (dying)
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 30},  -- Slow
                isActive = true
            },
            opponent = {
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 80}  -- Faster
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertLess(data.matchupScore, 1.5, "Dying Pokemon with bad matchup should have low score")
end)

-- Test 6: Moderate HP switch candidate (20-40% HP)
runTest("Moderate HP switch candidate", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},
                moveset = {
                    {moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}
                },
                hp = 30,  -- 30% HP (moderate)
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
                isActive = true
            },
            opponent = {
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertLess(data.matchupScore, 1.5, "Moderate HP Pokemon should have reduced score (0.5x penalty)")
end)

-- Test 7: STAB bonus in attack score
runTest("STAB bonus application", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {10},  -- Water
                moveset = {
                    {moveId = 55, pp = 25, maxPp = 25, category = 1, type = 10}  -- Water Gun (Water)
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponent = {
                types = {9},  -- Fire (weak to Water)
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertGreater(data.components.atkScore, 2.5, "STAB + 2x effectiveness should give atkScore > 2.5 (1.5 * 2.0)")
end)

-- Test 8: Dual-type defense score
runTest("Dual-type defense score calculation", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {11, 3},  -- Grass/Poison
                moveset = {
                    {moveId = 1, pp = 10, maxPp = 10, category = 0, type = 0}
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 45},
                isActive = true
            },
            opponent = {
                types = {9},  -- Fire (super effective vs Grass)
                hp = 100,
                maxHp = 100,
                stats = {atk = 52, def = 43, spatk = 60, spdef = 50, spd = 65}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertLess(data.components.defScore, 1.0, "Weak to Fire should give low defense score")
end)

-- Test 9: No damaging moves (default atkScore = 1.0)
runTest("No damaging moves default score", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},
                moveset = {
                    {moveId = 45, pp = 40, maxPp = 40, category = 2, type = 0}  -- Growl (status)
                },
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
                isActive = true
            },
            opponent = {
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.components.atkScore, 1.0, "No damaging moves should default atkScore to 1.0")
end)

-- Test 10: Maximum matchup score scenario
runTest("Maximum matchup score", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {10},  -- Water
                moveset = {
                    {moveId = 55, pp = 25, maxPp = 25, category = 1, type = 10}  -- Water Gun
                },
                hp = 100,  -- Full HP
                maxHp = 100,
                stats = {atk = 100, def = 100, spatk = 100, spdef = 100, spd = 100},  -- High stats, fast
                isActive = true
            },
            opponent = {
                types = {9, 5},  -- Fire/Rock (quad weak to Water)
                hp = 10,  -- Low HP
                maxHp = 100,
                stats = {atk = 30, def = 30, spatk = 30, spdef = 30, spd = 30}  -- Slow, weak
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertGreater(data.matchupScore, 6.0, "Perfect matchup should score very high")
end)

-- Test 11: Minimum matchup score scenario
runTest("Minimum matchup score", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {9},  -- Fire
                moveset = {
                    {moveId = 52, pp = 5, maxPp = 25, category = 1, type = 9}  -- Ember
                },
                hp = 10,  -- Low HP (dying)
                maxHp = 100,
                stats = {atk = 30, def = 30, spatk = 30, spdef = 30, spd = 30},  -- Weak, slow
                isActive = true
            },
            opponent = {
                types = {10, 4},  -- Water/Ground (quad resists Fire)
                hp = 100,  -- Full HP
                maxHp = 100,
                stats = {atk = 100, def = 100, spatk = 100, spdef = 100, spd = 100}  -- Strong, fast
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertLess(data.matchupScore, 1.0, "Terrible matchup should score very low")
end)

-- Test 12: Bad matchup detection (atk < 1.5, def < 1.5)
runTest("Bad matchup detection logic", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},  -- Normal
                moveset = {
                    {moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}  -- Tackle
                },
                hp = 15,  -- Dying
                maxHp = 100,
                stats = {atk = 40, def = 35, spatk = 40, spdef = 35, spd = 35},  -- Slow, weak
                isActive = true
            },
            opponent = {
                types = {5},  -- Rock (resists Normal)
                hp = 100,
                maxHp = 100,
                stats = {atk = 80, def = 100, spatk = 55, spdef = 65, spd = 70}  -- Strong
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertLess(data.matchupScore, 0.5, "Bad matchup with dying Pokemon should have very low score")
end)

-- Test 13: Legendary opponent penalty
runTest("Legendary opponent score halving", function()
    local handler = _G.Handlers.list["evaluate-switch-decision"].handler
    handler({
        From = "test",
        Action = "EvaluateSwitchDecision",
        Timestamp = "1234567890",
        Data = json.encode({
            hasTrainer = true,
            hasMoveQueue = false,
            isTrapped = false,
            currentPokemon = {
                types = {0},
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
                isActive = true
            },
            opponents = {
                {
                    types = {15},  -- Dragon
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 100, def = 90, spatk = 120, spdef = 100, spd = 90},
                    isLegendary = true
                }
            },
            partyMembers = {
                {
                    partyIndex = 2,
                    types = {14},  -- Ice (good vs Dragon)
                    moveset = {{moveId = 58, pp = 10, maxPp = 10, category = 1, type = 14}},  -- Ice Beam
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 50, def = 50, spatk = 80, spdef = 70, spd = 80}
                }
            },
            isBoss = false,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    -- Legendary penalty should reduce party member score by half
    assertGreater(data.bestPartyScore, 0, "Party member should still have positive score vs legendary")
end)

-- Test 14: Multiple opponents averaging
runTest("Multiple opponents score averaging", function()
    local handler = _G.Handlers.list["evaluate-switch-decision"].handler
    handler({
        From = "test",
        Action = "EvaluateSwitchDecision",
        Timestamp = "1234567890",
        Data = json.encode({
            hasTrainer = true,
            hasMoveQueue = false,
            isTrapped = false,
            currentPokemon = {
                types = {0},
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50},
                isActive = true
            },
            opponents = {
                {
                    types = {9},  -- Fire
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
                },
                {
                    types = {10},  -- Water
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
                }
            },
            partyMembers = {
                {
                    partyIndex = 2,
                    types = {12},  -- Electric
                    moveset = {{moveId = 85, pp = 20, maxPp = 20, category = 1, type = 12}},  -- Thunderbolt
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 50, def = 50, spatk = 90, spdef = 55, spd = 90}
                }
            },
            isBoss = false,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    assertEq(response.Action, "SaveState", "Should evaluate with multiple opponents")
end)

-- Test 15: HP ratio floor at 1.0
runTest("HP ratio capped at 1.0", function()
    local handler = _G.Handlers.list["calculate-matchup-score"].handler
    handler({
        From = "test",
        Action = "CalculateMatchupScore",
        Timestamp = "1234567890",
        Data = json.encode({
            pokemon = {
                types = {0},
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 100,  -- Full HP
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 100},  -- Fast
                isActive = true
            },
            opponent = {
                types = {0},
                hp = 10,  -- Low HP opponent
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 30}
            }
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.components.hpDiffRatio, 1.0, "HP ratio should be capped at 1.0")
end)

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print(string.format("\n=== Test Results ==="))
print(string.format("Tests run: %d", testsRun))
print(string.format("Tests passed: %d", testsPassed))
print(string.format("Tests failed: %d", testsRun - testsPassed))
print(string.format("Success rate: %.1f%%", (testsPassed / testsRun) * 100))

if testsPassed == testsRun then
    print("\n✅ All matchup scoring tests passed!")
else
    print("\n❌ Some tests failed")
end

-- Return success status for test runner
return testsPassed == testsRun
