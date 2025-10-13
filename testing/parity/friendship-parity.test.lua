-- Friendship Parity Tests
-- Compares Lua friendship calculations against TypeScript implementation
-- Validates mathematical precision and behavioral consistency

local aolite = require('aolite')

-- Load the friendship engine process
local friendshipEngineCode = aolite.loadFileAndProcess('../processes/friendship-engine.lua')

-- TypeScript reference values and formulas for comparison
local TYPESCRIPT_CONSTANTS = {
    -- From TypeScript constants.ts and balance/starters.ts
    RARE_CANDY_FRIENDSHIP_CAP = 200,
    FRIENDSHIP_GAIN_FROM_BATTLE = 3,
    FRIENDSHIP_GAIN_FROM_RARE_CANDY = 6,
    FRIENDSHIP_LOSS_FROM_FAINT = 5,
    CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER = 3,

    -- Move power calculation constants
    MOVE_POWER_DIVISOR = 2.5,
    FRUSTRATION_MAX_BASE = 102,

    -- Soothe Bell multiplier: floor(friendship * (1 + 0.5 * stackCount))
    SOOTHE_BELL_MULTIPLIER = 1.5,

    -- Base friendship values (from species data)
    BASE_FRIENDSHIP = {
        [25] = 50,   -- Pikachu
        [113] = 140, -- Chansey
        [242] = 140, -- Blissey
        [133] = 50,  -- Eevee
        default = 50
    }
}

-- TypeScript formula implementations for comparison
local function calculateTypescriptReturnPower(friendship, isPlayer)
    -- TypeScript: Math.floor(Math.min(user.isPlayer() ? user.friendship : user.species.baseFriendship, 255) / 2.5)
    local effectiveFriendship = isPlayer and friendship or TYPESCRIPT_CONSTANTS.BASE_FRIENDSHIP.default
    local friendshipPower = math.floor(math.min(effectiveFriendship, 255) / TYPESCRIPT_CONSTANTS.MOVE_POWER_DIVISOR)
    return math.max(friendshipPower, 1)
end

local function calculateTypescriptFrustrationPower(friendship, isPlayer)
    -- TypeScript: Math.max(102 - friendshipPower, 1)
    local returnPower = calculateTypescriptReturnPower(friendship, isPlayer)
    return math.max(TYPESCRIPT_CONSTANTS.FRUSTRATION_MAX_BASE - returnPower, 1)
end

local function calculateTypescriptFriendshipChange(baseFriendship, change, hasSootheBell, capped)
    -- TypeScript addFriendship logic
    local newFriendship = baseFriendship

    if change <= 0 then
        -- Short-circuit friendship loss
        return math.max(baseFriendship + change, 0), change
    end

    local modifiedChange = change

    -- Apply Soothe Bell modifier (TypeScript: floor(friendship * (1 + 0.5 * stackCount)))
    if hasSootheBell then
        modifiedChange = math.floor(change * TYPESCRIPT_CONSTANTS.SOOTHE_BELL_MULTIPLIER)
    end

    newFriendship = baseFriendship + modifiedChange

    -- Handle rare candy cap
    if capped and newFriendship > TYPESCRIPT_CONSTANTS.RARE_CANDY_FRIENDSHIP_CAP then
        newFriendship = math.min(baseFriendship, TYPESCRIPT_CONSTANTS.RARE_CANDY_FRIENDSHIP_CAP)
    end

    -- Enforce bounds
    newFriendship = math.max(0, math.min(newFriendship, 255))

    return newFriendship, newFriendship - baseFriendship
end

describe("Friendship Parity Tests", function()
    local processId

    before_each(function()
        processId = aolite.spawnProcess(friendshipEngineCode)
    end)

    after_each(function()
        if processId then
            aolite.killProcess(processId)
        end
    end)

    describe("Move Power Calculation Parity", function()
        it("should match TypeScript Return move power calculations exactly", function()
            local testCases = {
                {friendship = 0, expected = 1},     -- Math.max(floor(0 / 2.5), 1) = 1
                {friendship = 50, expected = 20},   -- floor(50 / 2.5) = 20
                {friendship = 100, expected = 40},  -- floor(100 / 2.5) = 40
                {friendship = 128, expected = 51},  -- floor(128 / 2.5) = 51
                {friendship = 200, expected = 80},  -- floor(200 / 2.5) = 80
                {friendship = 255, expected = 102}, -- floor(255 / 2.5) = 102
            }

            for _, testCase in ipairs(testCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 25, -- Pikachu
                        friendship = testCase.friendship
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendshipMoveEffects",
                    Data = gameState,
                    From = "parity-test"
                })

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(testCase.expected), response.ReturnPower,
                    string.format("Return power mismatch for friendship %d: expected %d",
                        testCase.friendship, testCase.expected))

                -- Verify against TypeScript calculation
                local typescriptPower = calculateTypescriptReturnPower(testCase.friendship, true)
                assert.are.equal(testCase.expected, typescriptPower,
                    "Test case should match TypeScript implementation")
            end
        end)

        it("should match TypeScript Frustration move power calculations exactly", function()
            local testCases = {
                {friendship = 0, expected = 102},   -- Math.max(102 - 0, 1) = 102
                {friendship = 50, expected = 82},   -- Math.max(102 - 20, 1) = 82
                {friendship = 100, expected = 62},  -- Math.max(102 - 40, 1) = 62
                {friendship = 128, expected = 51},  -- Math.max(102 - 51, 1) = 51
                {friendship = 200, expected = 22},  -- Math.max(102 - 80, 1) = 22
                {friendship = 255, expected = 1},   -- Math.max(102 - 102, 1) = 1
            }

            for _, testCase in ipairs(testCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = testCase.friendship
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendshipMoveEffects",
                    Data = gameState,
                    From = "parity-test"
                })

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(testCase.expected), response.FrustrationPower,
                    string.format("Frustration power mismatch for friendship %d: expected %d",
                        testCase.friendship, testCase.expected))

                -- Verify against TypeScript calculation
                local typescriptPower = calculateTypescriptFrustrationPower(testCase.friendship, true)
                assert.are.equal(testCase.expected, typescriptPower,
                    "Test case should match TypeScript implementation")
            end
        end)

        it("should match TypeScript power calculation edge cases", function()
            -- Test extreme values and edge cases
            local edgeCases = {
                {friendship = 1, returnPower = 1, frustrationPower = 102},
                {friendship = 2, returnPower = 1, frustrationPower = 102},
                {friendship = 3, returnPower = 1, frustrationPower = 102}, -- floor(3/2.5) = floor(1.2) = 1
                {friendship = 254, returnPower = 101, frustrationPower = 1}, -- floor(254/2.5) = floor(101.6) = 101
            }

            for _, testCase in ipairs(edgeCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = testCase.friendship
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendshipMoveEffects",
                    Data = gameState,
                    From = "parity-edge-test"
                })

                assert.are.equal(tostring(testCase.returnPower), response.ReturnPower)
                assert.are.equal(tostring(testCase.frustrationPower), response.FrustrationPower)
            end
        end)
    end)

    describe("Friendship Change Calculation Parity", function()
        it("should match TypeScript battle victory friendship gains", function()
            local initialFriendships = {0, 50, 100, 150, 200, 254}

            for _, initialFriendship in ipairs(initialFriendships) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = initialFriendship
                    },
                    parameters = {
                        friendshipAction = "battleVictory",
                        actionContext = "wild"
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendship",
                    Data = gameState,
                    From = "parity-battle-test"
                })

                -- TypeScript calculation
                local expectedFriendship, expectedChange = calculateTypescriptFriendshipChange(
                    initialFriendship,
                    TYPESCRIPT_CONSTANTS.FRIENDSHIP_GAIN_FROM_BATTLE,
                    false, -- No Soothe Bell
                    false  -- Not capped
                )

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(expectedChange), response.FriendshipChange,
                    string.format("Battle friendship change mismatch for initial %d", initialFriendship))
                assert.are.equal(tostring(expectedFriendship), response.NewFriendship,
                    string.format("Battle new friendship mismatch for initial %d", initialFriendship))
            end
        end)

        it("should match TypeScript Soothe Bell modifier calculations", function()
            local testCases = {
                {initial = 50, baseGain = 3, expected = 54},   -- floor(3 * 1.5) = 4, 50 + 4 = 54
                {initial = 100, baseGain = 6, expected = 109}, -- floor(6 * 1.5) = 9, 100 + 9 = 109
                {initial = 200, baseGain = 3, expected = 204}, -- floor(3 * 1.5) = 4, 200 + 4 = 204
            }

            for _, testCase in ipairs(testCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = testCase.initial,
                        heldItem = "soothe_bell"
                    },
                    parameters = {
                        friendshipAction = "battleVictory"
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendship",
                    Data = gameState,
                    From = "parity-soothe-test"
                })

                -- TypeScript calculation with Soothe Bell
                local expectedFriendship, expectedChange = calculateTypescriptFriendshipChange(
                    testCase.initial,
                    testCase.baseGain,
                    true,  -- Has Soothe Bell
                    false  -- Not capped
                )

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(expectedFriendship), response.NewFriendship,
                    string.format("Soothe Bell friendship mismatch for initial %d", testCase.initial))

                -- Verify this matches our manual calculation
                assert.are.equal(testCase.expected, expectedFriendship,
                    "Manual calculation should match TypeScript formula")
            end
        end)

        it("should match TypeScript rare candy capping behavior", function()
            local testCases = {
                {initial = 190, baseGain = 6, capped = true, expected = 196},  -- 190 + 6 = 196, under cap
                {initial = 195, baseGain = 6, capped = true, expected = 200},  -- 195 + 6 = 201, capped to 200
                {initial = 198, baseGain = 6, capped = true, expected = 200},  -- 198 + 6 = 204, capped to 200
                {initial = 200, baseGain = 6, capped = true, expected = 200},  -- Already at cap
            }

            for _, testCase in ipairs(testCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = testCase.initial
                    },
                    parameters = {
                        friendshipAction = "rareCandy"
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendship",
                    Data = gameState,
                    From = "parity-candy-test"
                })

                -- TypeScript calculation with capping
                local expectedFriendship, expectedChange = calculateTypescriptFriendshipChange(
                    testCase.initial,
                    testCase.baseGain,
                    false, -- No Soothe Bell
                    testCase.capped
                )

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(expectedFriendship), response.NewFriendship,
                    string.format("Rare candy capping mismatch for initial %d", testCase.initial))

                -- Verify this matches our expected value
                assert.are.equal(testCase.expected, expectedFriendship,
                    "Manual calculation should match TypeScript capping formula")
            end
        end)

        it("should match TypeScript friendship loss calculations", function()
            local testCases = {
                {initial = 10, loss = -5, expected = 5},   -- Above minimum
                {initial = 3, loss = -5, expected = 0},    -- Below minimum, clamped to 0
                {initial = 0, loss = -5, expected = 0},    -- Already at minimum
                {initial = 255, loss = -5, expected = 250}, -- From maximum
            }

            for _, testCase in ipairs(testCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = testCase.initial
                    },
                    parameters = {
                        friendshipAction = "faint"
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendship",
                    Data = gameState,
                    From = "parity-loss-test"
                })

                -- TypeScript calculation for loss
                local expectedFriendship, expectedChange = calculateTypescriptFriendshipChange(
                    testCase.initial,
                    testCase.loss,
                    false, -- No item effects on loss
                    false  -- Not capped
                )

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(expectedFriendship), response.NewFriendship,
                    string.format("Friendship loss mismatch for initial %d", testCase.initial))

                -- Verify this matches our expected value
                assert.are.equal(testCase.expected, expectedFriendship,
                    "Manual calculation should match TypeScript loss formula")
            end
        end)
    end)

    describe("Evolution Threshold Parity", function()
        it("should match TypeScript friendship evolution thresholds", function()
            -- TypeScript typically uses 220 as the friendship evolution threshold
            local TYPESCRIPT_EVOLUTION_THRESHOLD = 220

            local testCases = {
                {friendship = 219, canEvolve = false},
                {friendship = 220, canEvolve = true},
                {friendship = 221, canEvolve = true},
                {friendship = 255, canEvolve = true}
            }

            for _, testCase in ipairs(testCases) do
                local gameState = {
                    pokemon = {
                        speciesId = 133, -- Eevee
                        friendship = testCase.friendship
                    },
                    parameters = {
                        requiredFriendship = TYPESCRIPT_EVOLUTION_THRESHOLD
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CheckFriendshipEvolution",
                    Data = gameState,
                    From = "parity-evolution-test"
                })

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(testCase.canEvolve), response.CanEvolve,
                    string.format("Evolution check mismatch for friendship %d", testCase.friendship))

                local data = response.Data
                assert.are.equal(testCase.canEvolve, data.canEvolve)
                assert.are.equal(TYPESCRIPT_EVOLUTION_THRESHOLD, data.evolutionRequirements.requiredFriendship)
            end
        end)
    end)

    describe("Base Friendship Parity", function()
        it("should use correct base friendship values for different species", function()
            local speciesTestCases = {
                {speciesId = 25, expectedBase = 50},   -- Pikachu
                {speciesId = 113, expectedBase = 140}, -- Chansey
                {speciesId = 133, expectedBase = 50},  -- Eevee
                {speciesId = 999, expectedBase = 50},  -- Unknown species -> default
            }

            for _, testCase in ipairs(speciesTestCases) do
                local gameState = {
                    pokemon = {
                        speciesId = testCase.speciesId
                        -- No friendship field - should use base
                    }
                }

                local response = aolite.send(processId, {
                    Action = "GetFriendshipStatus",
                    Data = gameState,
                    From = "parity-base-test"
                })

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(testCase.expectedBase), response.CurrentFriendship,
                    string.format("Base friendship mismatch for species %d", testCase.speciesId))

                -- Verify against our constants
                local expectedBase = TYPESCRIPT_CONSTANTS.BASE_FRIENDSHIP[testCase.speciesId] or
                                   TYPESCRIPT_CONSTANTS.BASE_FRIENDSHIP.default
                assert.are.equal(testCase.expectedBase, expectedBase,
                    "Test case should match TypeScript base friendship values")
            end
        end)
    end)

    describe("Comprehensive Parity Scenarios", function()
        it("should match TypeScript for complex friendship manipulation sequence", function()
            -- Simulate a complex sequence matching TypeScript behavior
            local initialState = {
                speciesId = 25, -- Pikachu
                friendship = 50,
                heldItem = "soothe_bell"
            }

            local sequence = {
                {action = "battleVictory", context = "wild", expected = nil},      -- Will calculate
                {action = "battleVictory", context = "trainer", expected = nil},   -- Will calculate
                {action = "rareCandy", context = nil, expected = nil},            -- Will calculate
                {action = "faint", context = nil, expected = nil},                -- Will calculate
                {action = "battleVictory", context = "gym", expected = nil}       -- Will calculate
            }

            -- Calculate expected values using TypeScript logic
            local currentFriendship = initialState.friendship

            for i, step in ipairs(sequence) do
                local baseChange = 0
                local capped = false

                if step.action == "battleVictory" then
                    baseChange = TYPESCRIPT_CONSTANTS.FRIENDSHIP_GAIN_FROM_BATTLE
                elseif step.action == "rareCandy" then
                    baseChange = TYPESCRIPT_CONSTANTS.FRIENDSHIP_GAIN_FROM_RARE_CANDY
                    capped = true
                elseif step.action == "faint" then
                    baseChange = -TYPESCRIPT_CONSTANTS.FRIENDSHIP_LOSS_FROM_FAINT
                end

                local hasSootheBell = (initialState.heldItem == "soothe_bell") and (baseChange > 0)
                local expectedFriendship, expectedChange = calculateTypescriptFriendshipChange(
                    currentFriendship, baseChange, hasSootheBell, capped
                )

                step.expected = expectedFriendship
                currentFriendship = expectedFriendship
            end

            -- Execute sequence in Lua process
            local gameState = {
                pokemon = {
                    speciesId = initialState.speciesId,
                    friendship = initialState.friendship,
                    heldItem = initialState.heldItem
                }
            }

            for i, step in ipairs(sequence) do
                gameState.parameters = {
                    friendshipAction = step.action,
                    actionContext = step.context
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendship",
                    Data = gameState,
                    From = "parity-sequence-test-" .. i
                })

                assert.are.equal("SaveState", response.Action)
                assert.are.equal(tostring(step.expected), response.NewFriendship,
                    string.format("Sequence step %d (%s) friendship mismatch", i, step.action))

                -- Update for next step
                gameState.pokemon.friendship = response.Data.newFriendship

                print(string.format("Step %d (%s): %s -> %s (TypeScript: %d)",
                    i, step.action, response.FriendshipChange, response.NewFriendship, step.expected))
            end
        end)

        it("should match TypeScript mathematical precision exactly", function()
            -- Test cases that verify mathematical precision matches TypeScript exactly
            local precisionTests = {
                -- Test floating-point division precision
                {friendship = 127, returnPower = math.floor(127 / 2.5)}, -- 50.8 -> 50
                {friendship = 128, returnPower = math.floor(128 / 2.5)}, -- 51.2 -> 51
                {friendship = 129, returnPower = math.floor(129 / 2.5)}, -- 51.6 -> 51

                -- Test boundary conditions
                {friendship = 2, returnPower = math.floor(2 / 2.5)},     -- 0.8 -> 0, but min is 1
                {friendship = 3, returnPower = math.floor(3 / 2.5)},     -- 1.2 -> 1
            }

            for _, test in ipairs(precisionTests) do
                local gameState = {
                    pokemon = {
                        speciesId = 25,
                        friendship = test.friendship
                    }
                }

                local response = aolite.send(processId, {
                    Action = "CalculateFriendshipMoveEffects",
                    Data = gameState,
                    From = "precision-test"
                })

                local expectedPower = math.max(test.returnPower, 1) -- Minimum power enforcement
                assert.are.equal(tostring(expectedPower), response.ReturnPower,
                    string.format("Mathematical precision error for friendship %d", test.friendship))
            end
        end)
    end)
end)