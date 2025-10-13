-- Environmental Interaction Engine Unit Tests
-- Test comprehensive environmental effect interactions and calculations

-- Mock AO environment
local lastSentMessage = nil
local mockAO = {
    send = function(msg) 
        lastSentMessage = msg
        print("Mock ao.send called with:")
        for k, v in pairs(msg) do
            print("  " .. k .. ": " .. tostring(v))
        end
        return msg
    end,
    id = "test_environmental_interaction_engine"
}

local mockHandlers = {
    add = function(name, matcher, handler)
        _G["handler_" .. name] = handler
        print("Registered handler: " .. name)
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg.Tags and msg.Tags[tag] == value
            end
        end
    }
}

local mockJson = {
    encode = function(data)
        -- Simple JSON encoder for testing
        if type(data) == "table" then
            return "{mock_table_data}"
        elseif type(data) == "string" then
            return '"' .. data .. '"'
        else
            return tostring(data)
        end
    end,
    decode = function(str)
        -- Simple JSON decoder for testing
        return {}
    end
}

-- Set up global mocks before loading the process
_G.ao = mockAO
_G.Handlers = mockHandlers  
_G.json = mockJson
_G.Owner = "test_owner"

-- Load the environmental interaction engine
dofile("processes/environmental-interaction-engine.lua")

-- Test utilities
local function runTest(name, testFunc)
    print("\n=== Running Test: " .. name .. " ===")
    local success, err = pcall(testFunc)
    if success then
        print("✅ PASS: " .. name)
    else
        print("❌ FAIL: " .. name)
        print("Error: " .. err)
    end
    return success
end

local function assertEquals(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTableEquals(expected, actual, message)
    for k, v in pairs(expected) do
        if actual[k] ~= v then
            error((message or "Table assertion failed") .. ": expected[" .. k .. "] = " .. tostring(v) .. ", got " .. tostring(actual[k]))
        end
    end
end

-- Test 1: Process Environmental Interaction - Rain + Electric Terrain
runTest("Rain + Electric Terrain Multiplier Calculation", function()
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalInteraction"
        },
        WeatherType = "RAIN",
        TerrainType = "ELECTRIC",
        MoveType = "ELECTRIC",
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsg)
    local response = lastSentMessage
    
    -- Verify response structure
    assertEquals("test_sender", response.Target, "Response target should match sender")
    assertEquals("EnvironmentalInteractionSuccess", response.Action, "Response should indicate success")
    assertEquals("true", response.Success, "Success flag should be true")
    
    -- Verify multiplier calculations
    assertEquals("1.0", response.WeatherMultiplier, "Rain should not boost Electric moves (weather multiplier = 1.0)")
    assertEquals("1.3", response.TerrainMultiplier, "Electric terrain should boost Electric moves by 1.3x")
    assertEquals("1.3", response.CombinedMultiplier, "Combined multiplier should be 1.0 * 1.3 = 1.3")
end)

-- Test 2: Process Environmental Interaction - Rain + Electric Terrain + Water Move
runTest("Rain + Electric Terrain + Water Move", function()
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalInteraction" 
        },
        WeatherType = "RAIN",
        TerrainType = "ELECTRIC",
        MoveType = "WATER",
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsg)
    local response = lastSentMessage
    
    -- Verify multiplier calculations for Water move in Rain + Electric terrain
    assertEquals("1.5", response.WeatherMultiplier, "Rain should boost Water moves by 1.5x")
    assertEquals("1.0", response.TerrainMultiplier, "Electric terrain should not boost Water moves")
    assertEquals("1.5", response.CombinedMultiplier, "Combined multiplier should be 1.5 * 1.0 = 1.5")
end)

-- Test 3: Complex Interaction - Rain + Electric Terrain + Electric Move  
runTest("Rain + Electric Terrain Complex Calculation", function()
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalInteraction"
        },
        WeatherType = "RAIN", 
        TerrainType = "ELECTRIC",
        MoveType = "ELECTRIC",
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsg)
    local response = lastSentMessage
    
    -- Rain doesn't boost Electric, but Electric terrain does
    assertEquals("1.0", response.WeatherMultiplier, "Rain doesn't boost Electric moves")
    assertEquals("1.3", response.TerrainMultiplier, "Electric terrain boosts Electric moves")
    assertEquals("1.3", response.CombinedMultiplier, "Combined should be 1.0 * 1.3 = 1.3")
end)

-- Test 4: Grounding Effects - Terrain Only Affects Grounded Pokemon
runTest("Terrain Grounding Effects", function()
    local mockMsgGrounded = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalInteraction"
        },
        WeatherType = "NONE",
        TerrainType = "ELECTRIC", 
        MoveType = "ELECTRIC",
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    local mockMsgFlying = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalInteraction"
        },
        WeatherType = "NONE",
        TerrainType = "ELECTRIC",
        MoveType = "ELECTRIC", 
        IsGrounded = "false",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsgGrounded)
    local responseGrounded = lastSentMessage
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsgFlying)
    local responseFlying = lastSentMessage
    
    -- Grounded Pokemon should get terrain boost
    assertEquals("1.3", responseGrounded.TerrainMultiplier, "Grounded Pokemon should get terrain boost")
    
    -- Flying Pokemon should not get terrain boost
    assertEquals("1.0", responseFlying.TerrainMultiplier, "Flying Pokemon should not get terrain boost")
end)

-- Test 5: Weather-Terrain Combination Check
runTest("Weather-Terrain Combination Check", function()
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "CheckWeatherTerrainCombo"
        },
        WeatherType = "RAIN",
        TerrainType = "ELECTRIC",
        Timestamp = "1234567890"
    }
    
    _G.handler_CheckWeatherTerrainCombo(mockMsg)
    local response = lastSentMessage
    
    assertEquals("test_sender", response.Target, "Response target should match sender")
    assertEquals("WeatherTerrainComboResult", response.Action, "Response should indicate combo result")
    assertEquals("RAIN_ELECTRIC", response.Combo, "Combo should be RAIN_ELECTRIC")
    assertEquals("true", response.HasInteraction, "Should have interaction between rain and electric terrain")
end)

-- Test 6: Environmental Turn Processing - Sandstorm Damage
runTest("Environmental Turn - Sandstorm Damage", function()
    -- Set up sandstorm weather in environmental state
    EnvironmentalState.activeWeather = "SANDSTORM"
    EnvironmentalState.activeTerrain = "NONE"
    
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalTurn"
        },
        PokemonType1 = "WATER",  -- Not immune to sandstorm
        PokemonType2 = nil,
        MaxHP = "100",
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalTurn(mockMsg)
    local response = lastSentMessage
    
    assertEquals("test_sender", response.Target, "Response target should match sender")
    assertEquals("EnvironmentalTurnResult", response.Action, "Response should indicate turn result")
    assertEquals("6", response.WeatherDamage, "Sandstorm should deal 1/16 max HP = 6 damage")
    assertEquals("0", response.TerrainHealing, "No terrain healing expected")
end)

-- Test 7: Environmental Turn Processing - Grassy Terrain Healing
runTest("Environmental Turn - Grassy Terrain Healing", function()
    -- Set up grassy terrain
    EnvironmentalState.activeWeather = "NONE"
    EnvironmentalState.activeTerrain = "GRASSY"
    
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalTurn"
        },
        PokemonType1 = "ELECTRIC",
        MaxHP = "100",
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalTurn(mockMsg)
    local response = lastSentMessage
    
    assertEquals("0", response.WeatherDamage, "No weather damage expected")
    assertEquals("6", response.TerrainHealing, "Grassy terrain should heal 1/16 max HP = 6")
end)

-- Test 8: Environmental Conflict Resolution
runTest("Environmental Conflict Resolution - Cloud Nine", function()
    -- Set up active weather
    EnvironmentalState.activeWeather = "RAIN"
    EnvironmentalState.activeTerrain = "ELECTRIC"
    
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ResolveEnvironmentalConflicts"
        },
        RemovalSource = "CLOUD_NINE",
        CurrentWeather = "RAIN",
        CurrentTerrain = "ELECTRIC",
        Timestamp = "1234567890"
    }
    
    _G.handler_ResolveEnvironmentalConflicts(mockMsg)
    local response = lastSentMessage
    
    assertEquals("test_sender", response.Target, "Response target should match sender")
    assertEquals("EnvironmentalConflictResolution", response.Action, "Response should indicate conflict resolution")
    assertEquals("1", response.RemovedEffects, "Cloud Nine should remove 1 effect (weather)")
    
    -- Verify weather was removed from state
    assertEquals("NONE", EnvironmentalState.activeWeather, "Weather should be removed after Cloud Nine")
end)

-- Test 9: Mathematical Precision - Combined Multiplier Edge Cases
runTest("Mathematical Precision - Complex Multipliers", function()
    local mockMsg = {
        From = "test_sender", 
        Tags = {
            Action = "ProcessEnvironmentalInteraction"
        },
        WeatherType = "SUN",
        TerrainType = "GRASSY",
        MoveType = "FIRE",  -- Should get sun boost but not terrain boost
        IsGrounded = "true",
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsg)
    local response = lastSentMessage
    
    assertEquals("1.5", response.WeatherMultiplier, "Sun should boost Fire moves by 1.5x")
    assertEquals("1.0", response.TerrainMultiplier, "Grassy terrain should not boost Fire moves")  
    assertEquals("1.5", response.CombinedMultiplier, "Combined should be 1.5 * 1.0 = 1.5")
end)

-- Test 10: Error Handling - Missing Required Parameters
runTest("Error Handling - Missing MoveType", function()
    local mockMsg = {
        From = "test_sender",
        Tags = {
            Action = "ProcessEnvironmentalInteraction"
        },
        WeatherType = "RAIN",
        TerrainType = "ELECTRIC",
        -- Missing MoveType
        Timestamp = "1234567890"
    }
    
    _G.handler_ProcessEnvironmentalInteraction(mockMsg)
    local response = lastSentMessage
    
    assertEquals("test_sender", response.Target, "Response target should match sender")
    assertEquals("EnvironmentalInteractionError", response.Action, "Response should indicate error")
    assertEquals("MoveType required", response.Error, "Should indicate MoveType is required")
end)

print("\n=== Environmental Interaction Engine Unit Tests Complete ===")
print("All handler patterns and calculations tested with mathematical precision")
print("Weather-terrain combinations, grounding effects, and error handling verified")