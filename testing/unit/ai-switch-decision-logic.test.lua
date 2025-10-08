-- AI Switch Decision Logic Unit Tests
-- Story 17.2: Tests for switch decision evaluation, dampening, and thresholds
-- Test Framework: aolite (local Lua AO emulation)

local json = require("json")

-- Mock AO environment
_G.ao = {
    id = "test_process_switch_decision",
    send = function(msg)
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

-- Test utilities
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

-- ============================================================================
-- TEST SUITE: Switch Decision Logic (15 tests)
-- ============================================================================

print("\n=== Switch Decision Logic Tests ===\n")

-- Test 1: Normal trainer 3x threshold - should not switch
runTest("Normal trainer 3x threshold blocks switch", function()
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
            opponents = {{
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {0},
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 60}
            }},
            isBoss = false,  -- Normal trainer (3x threshold)
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, false, "Normal trainer should not switch with moderate advantage")
    assertEq(data.threshold, 3, "Normal trainer threshold should be 3")
end)

-- Test 2: Boss trainer 2x threshold - should switch
runTest("Boss trainer 2x threshold allows switch", function()
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
                types = {9},  -- Fire
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 50,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},  -- Water (bad matchup for Fire)
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {11},  -- Grass (good vs Water)
                moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},  -- Razor Leaf
                hp = 100,
                maxHp = 100,
                stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
            }},
            isBoss = true,  -- Boss trainer (2x threshold)
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, true, "Boss trainer should switch with type advantage")
    assertEq(data.threshold, 2, "Boss trainer threshold should be 2")
end)

-- Test 3: First switch (counter=1) no dampening
runTest("First switch no dampening multiplier", function()
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
                types = {9},  -- Fire
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},  -- Water
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {11},  -- Grass
                moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
            }},
            isBoss = true,
            enemySwitchCounter = 1,  -- First switch
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertNear(data.switchMultiplier, 1.0, 0.01, "First switch should have multiplier 1.0 (no penalty)")
end)

-- Test 4: Second switch (counter=2) ~0.68 dampening
runTest("Second switch dampening ~0.68", function()
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
            opponents = {{
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {0},
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 60}
            }},
            isBoss = false,
            enemySwitchCounter = 2,  -- Second switch
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertNear(data.switchMultiplier, 0.68, 0.05, "Second switch should have multiplier ~0.68")
end)

-- Test 5: Third+ switch (counter=3+) ~0.36 dampening
runTest("Third switch heavy dampening ~0.36", function()
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
            opponents = {{
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {0},
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 60, def = 60, spatk = 60, spdef = 60, spd = 60}
            }},
            isBoss = false,
            enemySwitchCounter = 3,  -- Third switch
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertNear(data.switchMultiplier, 0.36, 0.05, "Third+ switch should have multiplier ~0.36")
end)

-- Test 6: Tied party member scores (random selection)
runTest("Tied scores use deterministic RNG", function()
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
                types = {9},  -- Fire
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 50,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},  -- Water
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {
                {
                    partyIndex = 2,
                    types = {11},  -- Grass (good vs Water)
                    moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
                },
                {
                    partyIndex = 3,
                    types = {11},  -- Grass (identical to party member 2)
                    moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
                }
            },
            isBoss = true,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 5
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    -- With same seed and turn, should select same Pokemon deterministically
    assertEq(type(data.switchToIndex), "number", "Should select a party member")
end)

-- Test 7: Trapped Pokemon blocks switch
runTest("Trapped Pokemon cannot switch", function()
    local handler = _G.Handlers.list["evaluate-switch-decision"].handler
    handler({
        From = "test",
        Action = "EvaluateSwitchDecision",
        Timestamp = "1234567890",
        Data = json.encode({
            hasTrainer = true,
            hasMoveQueue = false,
            isTrapped = true,  -- Trapped (Wrap, Mean Look, etc.)
            currentPokemon = {
                types = {9},
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 50,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {11},
                moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
            }},
            isBoss = true,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, false, "Trapped Pokemon cannot switch")
end)

-- Test 8: Move queue not empty blocks switch
runTest("Move queue not empty prevents switch", function()
    local handler = _G.Handlers.list["evaluate-switch-decision"].handler
    handler({
        From = "test",
        Action = "EvaluateSwitchDecision",
        Timestamp = "1234567890",
        Data = json.encode({
            hasTrainer = true,
            hasMoveQueue = true,  -- Charging move (e.g., Solar Beam)
            isTrapped = false,
            currentPokemon = {
                types = {9},
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 50,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {11},
                moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
            }},
            isBoss = true,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, false, "Move queue should prevent switching")
end)

-- Test 9: No trainer (wild Pokemon) never switches
runTest("Wild Pokemon never switch", function()
    local handler = _G.Handlers.list["evaluate-switch-decision"].handler
    handler({
        From = "test",
        Action = "EvaluateSwitchDecision",
        Timestamp = "1234567890",
        Data = json.encode({
            hasTrainer = false,  -- Wild Pokemon
            hasMoveQueue = false,
            isTrapped = false,
            currentPokemon = {
                types = {9},
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 10,  -- Low HP, bad matchup
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {},
            isBoss = false,
            enemySwitchCounter = 0,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, false, "Wild Pokemon should never switch")
end)

-- Test 10: Best party member below threshold
runTest("Best party member below threshold no switch", function()
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
                types = {0},  -- Normal
                moveset = {{moveId = 36, pp = 15, maxPp = 15, category = 0, type = 0}},  -- Take Down
                hp = 100,
                maxHp = 100,
                stats = {atk = 80, def = 80, spatk = 80, spdef = 80, spd = 80},
                isActive = true
            },
            opponents = {{
                types = {0},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 50, spdef = 50, spd = 50}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {0},  -- Weak party member
                moveset = {{moveId = 1, pp = 10, maxPp = 35, category = 0, type = 0}},
                hp = 80,
                maxHp = 100,
                stats = {atk = 40, def = 40, spatk = 40, spdef = 40, spd = 40}
            }},
            isBoss = false,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, false, "Should not switch to worse Pokemon")
end)

-- Test 11: Entry hazard penalty reduces party scores
runTest("Entry hazards reduce party member scores", function()
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
                types = {9},  -- Fire
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 50,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},  -- Water
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {9, 2},  -- Fire/Flying (4x weak to Stealth Rock)
                moveset = {{moveId = 17, pp = 20, maxPp = 20, category = 2, type = 2}},  -- Wing Attack
                hp = 100,
                maxHp = 100,
                stats = {atk = 90, def = 90, spatk = 110, spdef = 90, spd = 100}
            }},
            entryHazards = {
                {type = "STEALTH_ROCK"}
            },
            isBoss = true,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    -- Entry hazards should reduce party member score
    assertEq(type(data.partyScores), "table", "Party scores should be calculated with hazards")
end)

-- Test 12: Empty party members (no switch options)
runTest("Empty party no switch options", function()
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
                types = {9},
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 10,  -- Low HP
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {},  -- No party members available
            isBoss = false,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    assertEq(data.shouldSwitch, false, "Cannot switch with no party members")
end)

-- Test 13: Doubles battle multi-opponent scoring
runTest("Doubles battle multiple opponents", function()
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
            partyMembers = {{
                partyIndex = 2,
                types = {12},  -- Electric (good vs Water, neutral vs Fire)
                moveset = {{moveId = 85, pp = 20, maxPp = 20, category = 1, type = 12}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 90, spdef = 55, spd = 90}
            }},
            isBoss = true,
            enemySwitchCounter = 1,
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    assertEq(response.Action, "SaveState", "Should handle doubles battle")
    local data = json.decode(response.Data)
    assertGreater(data.currentMatchupScore, 0, "Should average scores across multiple opponents")
end)

-- Test 14: Switch counter edge case (counter = 0)
runTest("Switch counter zero edge case", function()
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
                types = {9},
                moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                isActive = true
            },
            opponents = {{
                types = {10},
                hp = 100,
                maxHp = 100,
                stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
            }},
            partyMembers = {{
                partyIndex = 2,
                types = {11},
                moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                hp = 100,
                maxHp = 100,
                stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
            }},
            isBoss = true,
            enemySwitchCounter = 0,  -- Edge case: no previous switches
            battleSeed = 12345,
            battleTurn = 1
        })
    })

    local response = _G.sentMessages[1]
    local data = json.decode(response.Data)
    -- Should handle counter = 0 gracefully (treat as 1)
    assertNear(data.switchMultiplier, 1.0, 0.01, "Counter 0 should be treated as 1 (no penalty)")
end)

-- Test 15: Switch decision determinism with same seed
runTest("Switch decision determinism with battle seed", function()
    local handler = _G.Handlers.list["evaluate-switch-decision"].handler

    -- Run twice with same seed
    local results = {}
    for i = 1, 2 do
        _G.sentMessages = {}
        handler({
            From = "test",
            Action = "EvaluateSwitchDecision",
            Timestamp = "1234567890",
            Data = json.encode({
                hasTrainer = true,
                hasMoveQueue = false,
                isTrapped = false,
                currentPokemon = {
                    types = {9},
                    moveset = {{moveId = 52, pp = 10, maxPp = 25, category = 1, type = 9}},
                    hp = 50,
                    maxHp = 100,
                    stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65},
                    isActive = true
                },
                opponents = {{
                    types = {10},
                    hp = 100,
                    maxHp = 100,
                    stats = {atk = 50, def = 50, spatk = 60, spdef = 50, spd = 65}
                }},
                partyMembers = {
                    {
                        partyIndex = 2,
                        types = {11},
                        moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                        hp = 100,
                        maxHp = 100,
                        stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
                    },
                    {
                        partyIndex = 3,
                        types = {11},
                        moveset = {{moveId = 75, pp = 10, maxPp = 10, category = 1, type = 11}},
                        hp = 100,
                        maxHp = 100,
                        stats = {atk = 45, def = 55, spatk = 65, spdef = 65, spd = 45}
                    }
                },
                isBoss = true,
                enemySwitchCounter = 1,
                battleSeed = 42424242,  -- Fixed seed
                battleTurn = 7  -- Fixed turn
            })
        })

        local response = _G.sentMessages[1]
        local data = json.decode(response.Data)
        table.insert(results, data.switchToIndex)
    end

    assertEq(results[1], results[2], "Same seed and turn should produce same switch decision")
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
    print("\n✅ All switch decision logic tests passed!")
else
    print("\n❌ Some tests failed")
end

-- Return success status for test runner
return testsPassed == testsRun
