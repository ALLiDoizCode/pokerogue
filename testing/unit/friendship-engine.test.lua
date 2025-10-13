-- Friendship Engine Unit Tests (Linear Execution with Real Aolite Framework)
-- Tests for friendship calculation, evolution triggers, move effects, and status tracking
-- Converted from describe/it to linear execution pattern

-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.friendship-engine"
local processId = "test-friendship-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Friendship Engine")
print("Process ID:", processId)
print("==================================================")

-- Test utility function
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

local testCount = 0
local passCount = 0

local function runTest(testName, testFn)
    testCount = testCount + 1
    print("\n📝 Test " .. testCount .. ": " .. testName)
    local success, err = pcall(testFn)
    if success then
        passCount = passCount + 1
        print("✅ Test " .. testCount .. " passed")
    else
        print("❌ Test " .. testCount .. " failed: " .. tostring(err))
        error("Test failed: " .. testName)
    end
end

-- ==========================================
-- TEST SUITE: Process Info Handler (ADP Compliance)
-- ==========================================

runTest("Info handler responds with process metadata", function()
    local response = sendMessage("Info", nil, "")

    if response.Action ~= "SaveState" then
        error("Expected Action 'SaveState', got: " .. tostring(response.Action))
    end

    if response.Success ~= "true" then
        error("Expected Success 'true', got: " .. tostring(response.Success))
    end

    local data = json.decode(response.Data or "{}")
    if not data.process then
        error("Missing process metadata in response")
    end

    if data.process.name ~= "Friendship Engine" then
        error("Expected process name 'Friendship Engine', got: " .. tostring(data.process.name))
    end

    if data.process.adpVersion ~= "1.0" then
        error("Expected ADP version '1.0', got: " .. tostring(data.process.adpVersion))
    end
end)

-- ==========================================
-- TEST SUITE: CalculateFriendship Handler
-- ==========================================

runTest("Calculate friendship gain from battle victory", function()
    local testData = {
        pokemon = {
            speciesId = 25, -- Pikachu
            friendship = 50
        },
        parameters = {
            friendshipAction = "battleVictory",
            actionContext = "wild"
        }
    }

    local response = sendMessage("CalculateFriendship", nil, json.encode(testData))

    if response.Action ~= "SaveState" then
        error("Expected SaveState action, got: " .. tostring(response.Action))
    end

    if response.FriendshipChange ~= "3" then
        error("Expected FriendshipChange '3', got: " .. tostring(response.FriendshipChange))
    end

    if response.NewFriendship ~= "53" then
        error("Expected NewFriendship '53', got: " .. tostring(response.NewFriendship))
    end
end)

runTest("Calculate friendship loss from fainting", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 100
        },
        parameters = {
            friendshipAction = "faint"
        }
    }

    local response = sendMessage("CalculateFriendship", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    if response.FriendshipChange ~= "-5" then
        error("Expected FriendshipChange '-5', got: " .. tostring(response.FriendshipChange))
    end

    if response.NewFriendship ~= "95" then
        error("Expected NewFriendship '95', got: " .. tostring(response.NewFriendship))
    end
end)

runTest("Apply Soothe Bell modifier to friendship gains", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 50,
            heldItem = "soothe_bell"
        },
        parameters = {
            friendshipAction = "battleVictory",
            actionContext = "wild"
        }
    }

    local response = sendMessage("CalculateFriendship", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    -- Base 3 * 1.5 (soothe bell) = 4.5, floored to 4
    if response.FriendshipChange ~= "4" then
        error("Expected FriendshipChange '4' with Soothe Bell, got: " .. tostring(response.FriendshipChange))
    end

    if response.NewFriendship ~= "54" then
        error("Expected NewFriendship '54', got: " .. tostring(response.NewFriendship))
    end
end)

runTest("Enforce rare candy friendship cap (200)", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 198
        },
        parameters = {
            friendshipAction = "rareCandy"
        }
    }

    local response = sendMessage("CalculateFriendship", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    -- Should be capped at 200, not 198 + 6 = 204
    if response.NewFriendship ~= "200" then
        error("Expected NewFriendship capped at '200', got: " .. tostring(response.NewFriendship))
    end
end)

runTest("Enforce absolute friendship bounds (0-255)", function()
    -- Test lower bound
    local testDataLow = {
        pokemon = {
            speciesId = 25,
            friendship = 2
        },
        parameters = {
            friendshipAction = "faint"
        }
    }

    local responseLow = sendMessage("CalculateFriendship", testDataLow)

    if responseLow.NewFriendship ~= "0" then
        error("Expected NewFriendship clamped to '0', got: " .. tostring(responseLow.NewFriendship))
    end

    -- Test upper bound
    local testDataHigh = {
        pokemon = {
            speciesId = 25,
            friendship = 254
        },
        parameters = {
            friendshipAction = "battleVictory"
        }
    }

    local responseHigh = sendMessage("CalculateFriendship", testDataHigh)

    if responseHigh.NewFriendship ~= "255" then
        error("Expected NewFriendship clamped to '255', got: " .. tostring(responseHigh.NewFriendship))
    end
end)

runTest("Handle invalid pokemon data", function()
    local testData = {
        pokemon = nil
    }

    local response = sendMessage("CalculateFriendship", testData)

    if response.Action ~= "Error" then
        error("Expected Error action for invalid pokemon data, got: " .. tostring(response.Action))
    end

    if not response.Error then
        error("Expected Error field in response")
    end
end)

runTest("Handle invalid friendship action", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 50
        },
        parameters = {
            friendshipAction = "invalidAction"
        }
    }

    local response = sendMessage("CalculateFriendship", testData)

    if response.Action ~= "Error" then
        error("Expected Error action for invalid friendship action")
    end

    if not response.Error or not string.match(response.Error, "Unknown friendship action") then
        error("Expected 'Unknown friendship action' error message")
    end
end)

-- ==========================================
-- TEST SUITE: CheckFriendshipEvolution Handler
-- ==========================================

runTest("Confirm evolution when friendship meets threshold", function()
    local testData = {
        pokemon = {
            speciesId = 133, -- Eevee
            friendship = 230
        },
        parameters = {
            requiredFriendship = 220
        }
    }

    local response = sendMessage("CheckFriendshipEvolution", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    if response.CanEvolve ~= "true" then
        error("Expected CanEvolve 'true', got: " .. tostring(response.CanEvolve))
    end

    if response.CurrentFriendship ~= "230" then
        error("Expected CurrentFriendship '230', got: " .. tostring(response.CurrentFriendship))
    end
end)

runTest("Reject evolution when friendship is too low", function()
    local testData = {
        pokemon = {
            speciesId = 133,
            friendship = 180
        },
        parameters = {
            requiredFriendship = 220
        }
    }

    local response = sendMessage("CheckFriendshipEvolution", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    if response.CanEvolve ~= "false" then
        error("Expected CanEvolve 'false', got: " .. tostring(response.CanEvolve))
    end

    if not string.match(response.Reason or "", "Friendship too low") then
        error("Expected 'Friendship too low' reason")
    end
end)

runTest("Check time of day requirements for Espeon/Umbreon", function()
    local testDataDay = {
        pokemon = {
            speciesId = 133,
            friendship = 230
        },
        parameters = {
            timeOfDay = "day",
            specialRequirements = {
                timeOfDay = "day"
            }
        }
    }

    local responseDay = sendMessage("CheckFriendshipEvolution", testDataDay)

    if responseDay.CanEvolve ~= "true" then
        error("Expected CanEvolve 'true' for correct time of day")
    end

    -- Test wrong time of day
    testDataDay.parameters.specialRequirements.timeOfDay = "night"
    local responseWrongTime = sendMessage("CheckFriendshipEvolution", testDataDay)

    if responseWrongTime.CanEvolve ~= "false" then
        error("Expected CanEvolve 'false' for wrong time of day")
    end

    if not string.match(responseWrongTime.Reason or "", "Wrong time of day") then
        error("Expected 'Wrong time of day' reason")
    end
end)

runTest("Check fairy move requirement for Sylveon", function()
    local testData = {
        pokemon = {
            speciesId = 133,
            friendship = 230,
            moveset = {
                {name = "Tackle", type = "normal"},
                {name = "Baby-Doll Eyes", type = "fairy"}
            }
        },
        parameters = {
            specialRequirements = {
                fairyMove = true
            }
        }
    }

    local response = sendMessage("CheckFriendshipEvolution", testData)

    if response.CanEvolve ~= "true" then
        error("Expected CanEvolve 'true' with fairy move")
    end

    -- Test without fairy move
    testData.pokemon.moveset = {
        {name = "Tackle", type = "normal"},
        {name = "Sand Attack", type = "ground"}
    }

    local responseNoFairy = sendMessage("CheckFriendshipEvolution", testData)

    if responseNoFairy.CanEvolve ~= "false" then
        error("Expected CanEvolve 'false' without fairy move")
    end

    if not string.match(responseNoFairy.Reason or "", "No Fairy%-type move") then
        error("Expected 'No Fairy-type move' reason")
    end
end)

runTest("Use default evolution threshold when none provided", function()
    local testData = {
        pokemon = {
            speciesId = 133,
            friendship = 220
        },
        parameters = {}
    }

    local response = sendMessage("CheckFriendshipEvolution", testData)

    if response.CanEvolve ~= "true" then
        error("Expected CanEvolve 'true' at default threshold (220)")
    end

    local data = json.decode(response.Data or "{}")
    if data.evolutionRequirements and data.evolutionRequirements.requiredFriendship ~= 220 then
        error("Expected default threshold 220 in response data")
    end
end)

-- ==========================================
-- TEST SUITE: CalculateFriendshipMoveEffects Handler
-- ==========================================

runTest("Calculate Return move power based on friendship", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 255
        }
    }

    local response = sendMessage("CalculateFriendshipMoveEffects", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    -- Math.floor(255 / 2.5) = 102
    if response.ReturnPower ~= "102" then
        error("Expected ReturnPower '102', got: " .. tostring(response.ReturnPower))
    end
end)

runTest("Calculate Frustration move power (inverse friendship)", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 0
        }
    }

    local response = sendMessage("CalculateFriendshipMoveEffects", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    -- Math.max(102 - Math.floor(0 / 2.5), 1) = 102
    if response.FrustrationPower ~= "102" then
        error("Expected FrustrationPower '102', got: " .. tostring(response.FrustrationPower))
    end
end)

runTest("Calculate mid-range friendship move effects", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 128
        }
    }

    local response = sendMessage("CalculateFriendshipMoveEffects", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    -- Return: Math.floor(128 / 2.5) = 51
    if response.ReturnPower ~= "51" then
        error("Expected ReturnPower '51', got: " .. tostring(response.ReturnPower))
    end

    -- Frustration: Math.max(102 - 51, 1) = 51
    if response.FrustrationPower ~= "51" then
        error("Expected FrustrationPower '51', got: " .. tostring(response.FrustrationPower))
    end
end)

runTest("Ensure minimum power of 1 for both moves", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 1
        }
    }

    local response = sendMessage("CalculateFriendshipMoveEffects", testData)

    local data = json.decode(response.Data or "{}")
    if not data.moveEffects then
        error("Missing moveEffects in response data")
    end

    if data.moveEffects.returnPower < 1 then
        error("Return power should be at least 1")
    end

    if data.moveEffects.frustrationPower < 1 then
        error("Frustration power should be at least 1")
    end
end)

-- ==========================================
-- TEST SUITE: GetFriendshipStatus Handler
-- ==========================================

runTest("Return comprehensive friendship status information", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 180
        }
    }

    local response = sendMessage("GetFriendshipStatus", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    if response.CurrentFriendship ~= "180" then
        error("Expected CurrentFriendship '180', got: " .. tostring(response.CurrentFriendship))
    end

    if response.FriendshipLevel ~= "high" then
        error("Expected FriendshipLevel 'high', got: " .. tostring(response.FriendshipLevel))
    end

    if response.CanEvolveByFriendship ~= "false" then
        error("Expected CanEvolveByFriendship 'false' (180 < 220)")
    end

    if response.ToEvolution ~= "40" then
        error("Expected ToEvolution '40', got: " .. tostring(response.ToEvolution))
    end
end)

runTest("Indicate evolution readiness for high friendship", function()
    local testData = {
        pokemon = {
            speciesId = 25,
            friendship = 240
        }
    }

    local response = sendMessage("GetFriendshipStatus", testData)

    if response.CanEvolveByFriendship ~= "true" then
        error("Expected CanEvolveByFriendship 'true' for friendship 240")
    end

    if response.ToEvolution ~= "0" then
        error("Expected ToEvolution '0' (already meets threshold)")
    end
end)

runTest("Handle pokemon without explicit friendship value", function()
    local testData = {
        pokemon = {
            speciesId = 25
            -- No friendship field
        }
    }

    local response = sendMessage("GetFriendshipStatus", testData)

    if response.Action ~= "SaveState" then
        error("Expected SaveState action")
    end

    if response.CurrentFriendship ~= "50" then
        error("Expected base friendship '50' for Pikachu, got: " .. tostring(response.CurrentFriendship))
    end

    if response.FriendshipLevel ~= "normal" then
        error("Expected FriendshipLevel 'normal' for friendship 50")
    end
end)

-- ==========================================
-- TEST SUITE: Friendship Level Classification
-- ==========================================

runTest("Classify friendship levels correctly", function()
    local testCases = {
        {friendship = 0, expectedLevel = "very_low"},
        {friendship = 25, expectedLevel = "very_low"},
        {friendship = 50, expectedLevel = "low"},
        {friendship = 99, expectedLevel = "low"},
        {friendship = 100, expectedLevel = "normal"},
        {friendship = 149, expectedLevel = "normal"},
        {friendship = 150, expectedLevel = "high"},
        {friendship = 199, expectedLevel = "high"},
        {friendship = 200, expectedLevel = "very_high"},
        {friendship = 254, expectedLevel = "very_high"},
        {friendship = 255, expectedLevel = "maximum"}
    }

    for _, testCase in ipairs(testCases) do
        local testData = {
            pokemon = {
                speciesId = 25,
                friendship = testCase.friendship
            }
        }

        local response = sendMessage("GetFriendshipStatus", testData)

        if response.FriendshipLevel ~= testCase.expectedLevel then
            error("Friendship " .. testCase.friendship .. " should be level " .. testCase.expectedLevel ..
                  ", got: " .. tostring(response.FriendshipLevel))
        end
    end
end)

-- ==========================================
-- TEST SUITE: Input Validation
-- ==========================================

runTest("Reject messages without pokemon data", function()
    local handlers = {"CalculateFriendship", "CheckFriendshipEvolution", "CalculateFriendshipMoveEffects", "GetFriendshipStatus"}

    for _, handlerAction in ipairs(handlers) do
        local response = sendMessage(handlerAction, {})

        if response.Action ~= "Error" then
            error("Handler " .. handlerAction .. " should reject empty pokemon data, got: " .. tostring(response.Action))
        end
    end
end)

runTest("Reject invalid species ID", function()
    local testData = {
        pokemon = {
            speciesId = "invalid",
            friendship = 50
        }
    }

    local response = sendMessage("CalculateFriendship", testData)

    if response.Action ~= "Error" then
        error("Expected Error action for invalid species ID")
    end

    if not string.match(response.Error or "", "Valid species ID") then
        error("Expected 'Valid species ID' error message")
    end
end)

runTest("Reject friendship values out of range", function()
    -- Test below 0
    local testDataLow = {
        pokemon = {
            speciesId = 25,
            friendship = -10
        }
    }

    local responseLow = sendMessage("GetFriendshipStatus", testDataLow)

    if responseLow.Action ~= "Error" then
        error("Expected Error action for friendship below 0")
    end

    if not string.match(responseLow.Error or "", "between 0 and 255") then
        error("Expected 'between 0 and 255' error message")
    end

    -- Test above 255
    local testDataHigh = {
        pokemon = {
            speciesId = 25,
            friendship = 300
        }
    }

    local responseHigh = sendMessage("GetFriendshipStatus", testDataHigh)

    if responseHigh.Action ~= "Error" then
        error("Expected Error action for friendship above 255")
    end
end)

-- ==========================================
-- TEST SUMMARY
-- ==========================================
print("\n==================================================")
print("🎉 All tests passed!")
print("✅ " .. passCount .. " / " .. testCount .. " tests successful")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
