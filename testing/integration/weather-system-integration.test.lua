-- Weather System Integration Tests
-- Tests weather system interaction with battle processes

-- Mock JSON implementation for testing
local json = {
    encode = function(obj)
        if type(obj) ~= "table" then
            return tostring(obj)
        end

        local result = "{"
        local first = true
        for k, v in pairs(obj) do
            if not first then
                result = result .. ","
            end
            first = false

            if type(k) == "string" then
                result = result .. '"' .. k .. '":'
            else
                result = result .. tostring(k) .. ":"
            end

            if type(v) == "string" then
                result = result .. '"' .. v .. '"'
            elseif type(v) == "table" then
                result = result .. json.encode(v)
            else
                result = result .. tostring(v)
            end
        end
        result = result .. "}"
        return result
    end,

    decode = function(str)
        if not str or str == "{}" then
            return {}
        end
        -- Mock decode functionality
        return {}
    end
}

-- Integration test framework setup
local IntegrationTest = {}

function IntegrationTest:new(testName)
    local test = {
        name = testName,
        messages = {},
        processes = {},
        startTime = os.time()
    }
    setmetatable(test, {__index = self})
    return test
end

function IntegrationTest:mockAOEnvironment()
    -- Mock AO environment for integration testing
    _G.ao = {
        send = function(msg)
            table.insert(self.messages, {
                timestamp = os.time(),
                message = msg
            })
            print(string.format("[AO SEND] %s -> %s: %s",
                ao.id or "unknown",
                msg.Target,
                msg.Action or "unknown"))
        end,
        id = "weather_system_process_" .. tostring(math.random(100000, 999999)),
        env = {
            Process = {
                Owner = "test_owner_address"
            }
        }
    }

    _G.Handlers = {
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        },
        add = function(name, matcher, handler)
            if not _G.testHandlers then
                _G.testHandlers = {}
            end
            _G.testHandlers[name] = {
                name = name,
                matcher = matcher,
                handler = handler
            }
            print(string.format("[HANDLER] Registered: %s", name))
        end
    }

    _G.json = json
end

function IntegrationTest:loadWeatherSystem()
    -- Load weather system process
    dofile("processes/weather-system-engine.lua")
    print("[LOAD] Weather System Engine loaded successfully")
end

function IntegrationTest:createBattleScenario()
    -- Create a realistic battle scenario for testing
    return {
        gameState = {
            battle = {
                conditions = {
                    weather = {
                        weatherType = "NONE",
                        turnsLeft = 0
                    }
                },
                playerParty = {
                    {
                        id = "player_charizard",
                        name = "Charizard",
                        types = {9, 2}, -- Fire/Flying
                        maxHP = 266,
                        currentHP = 266,
                        isActive = true,
                        abilities = {
                            {name = "Blaze", active = false}
                        }
                    },
                    {
                        id = "player_blastoise",
                        name = "Blastoise",
                        types = {10}, -- Water
                        maxHP = 268,
                        currentHP = 268,
                        isActive = false,
                        abilities = {
                            {name = "Torrent", active = false}
                        }
                    }
                },
                enemyParty = {
                    {
                        id = "enemy_garchomp",
                        name = "Garchomp",
                        types = {15, 4}, -- Dragon/Ground
                        maxHP = 280,
                        currentHP = 280,
                        isActive = true,
                        abilities = {
                            {name = "Sand Veil", active = true}
                        }
                    }
                }
            },
            battleSeed = "integration_test_seed_12345"
        }
    }
end

function IntegrationTest:sendMessage(action, data)
    local msg = {
        From = "integration_test_sender",
        Tags = {
            Action = action
        },
        Data = json.encode(data or {}),
        Timestamp = os.time()
    }

    -- Map action names to handler names
    local handlerMap = {
        ["SetWeather"] = "set-weather",
        ["ProcessWeatherTurn"] = "process-weather-turn",
        ["ClearWeather"] = "clear-weather",
        ["GetWeatherInfo"] = "get-weather-info",
        ["Info"] = "info",
        ["Ping"] = "ping"
    }

    local handlerName = handlerMap[action]
    local handler = _G.testHandlers[handlerName]
    if handler then
        print(string.format("[MESSAGE] Sending %s to handler %s", action, handler.name))
        handler.handler(msg)
        return true
    else
        print(string.format("[ERROR] No handler found for action: %s", action))
        return false
    end
end

function IntegrationTest:getLastResponse()
    if #self.messages > 0 then
        return self.messages[#self.messages].message
    end
    return nil
end

function IntegrationTest:assertResponse(expectedAction, expectedSuccess)
    local response = self:getLastResponse()
    assert(response ~= nil, "Expected response but got nil")
    assert(response.Action == expectedAction,
        string.format("Expected action %s but got %s", expectedAction, response.Action))

    if expectedAction == "SaveState" and expectedSuccess ~= nil then
        local data = json.decode(response.Data)
        assert(data.success == expectedSuccess,
            string.format("Expected success=%s but got %s", expectedSuccess, data.success))
    end

    return response
end

function IntegrationTest:run()
    print(string.format("🔄 Running integration test: %s", self.name))
    print("-" .. string.rep("-", 60))
end

function IntegrationTest:complete(success)
    local duration = os.time() - self.startTime
    local status = success and "✅ PASSED" or "❌ FAILED"
    print(string.format("%s %s (%.2fs)", status, self.name, duration))
    print("")
    return success
end

-- Test 1: Complete Weather Lifecycle
local function testCompleteWeatherLifecycle()
    local test = IntegrationTest:new("Complete Weather Lifecycle")
    test:run()

    test:mockAOEnvironment()
    test:loadWeatherSystem()

    local scenario = test:createBattleScenario()

    -- Step 1: Set rain weather
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "RAIN",
            duration = 3,
            overwrite = true
        }
    })

    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.weather.weatherType == "RAIN", "Should set rain weather")
    assert(data.weather.turnsLeft == 3, "Should set 3 turns duration")
    assert(#data.messages == 1, "Should have start message")

    -- Step 2: Process first weather turn
    test:sendMessage("ProcessWeatherTurn", scenario)

    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.weather.turnsLeft == 2, "Should decrement to 2 turns")
    assert(data.weather.isActive == true, "Should still be active")

    -- Step 3: Process second weather turn
    test:sendMessage("ProcessWeatherTurn", scenario)

    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.weather.turnsLeft == 1, "Should decrement to 1 turn")

    -- Step 4: Process final weather turn (should expire)
    test:sendMessage("ProcessWeatherTurn", scenario)

    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.weather.turnsLeft == 0, "Should expire")
    assert(data.weather.isActive == false, "Should become inactive")
    assert(data.weather.weatherType == "NONE", "Should clear weather")

    return test:complete(true)
end

-- Test 2: Sandstorm Damage Integration
local function testSandstormDamageIntegration()
    local test = IntegrationTest:new("Sandstorm Damage Integration")
    test:run()

    test:mockAOEnvironment()
    test:loadWeatherSystem()

    local scenario = test:createBattleScenario()

    -- Set sandstorm weather
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "SANDSTORM",
            duration = 5
        }
    })

    test:assertResponse("SaveState", true)

    -- Process weather turn with damage
    test:sendMessage("ProcessWeatherTurn", scenario)

    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)

    -- Charizard (Fire/Flying) should take damage
    -- Garchomp (Dragon/Ground) should be immune due to Ground type
    local damageDealt = data.effects.damageDealt
    assert(#damageDealt == 1, "Should damage only non-immune Pokemon")

    local charizardDamage = nil
    for _, damage in ipairs(damageDealt) do
        if damage.pokemonId == "player_charizard" then
            charizardDamage = damage
            break
        end
    end

    assert(charizardDamage ~= nil, "Charizard should take sandstorm damage")
    assert(charizardDamage.damage == 16, "Should deal 1/16 max HP (266/16=16.625, floored=16)")

    return test:complete(true)
end

-- Test 3: Weather Overwrite Scenarios
local function testWeatherOverwriteScenarios()
    local test = IntegrationTest:new("Weather Overwrite Scenarios")
    test:run()

    test:mockAOEnvironment()
    test:loadWeatherSystem()

    -- Set initial rain weather
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "RAIN",
            duration = 5
        }
    })

    test:assertResponse("SaveState", true)

    -- Try to set sunny weather without overwrite (should fail)
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "SUNNY",
            duration = 3,
            overwrite = false
        }
    })

    local response = test:assertResponse("SaveState", false)
    local data = json.decode(response.Data)
    assert(data.success == false, "Should fail without overwrite")

    -- Now set sunny weather with overwrite (should succeed)
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "SUNNY",
            duration = 3,
            overwrite = true
        }
    })

    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.weather.weatherType == "SUNNY", "Should overwrite with sunny weather")
    assert(data.weather.turnsLeft == 3, "Should set new duration")

    return test:complete(true)
end

-- Test 4: Move Type Multiplier Integration
local function testMoveTypeMultiplierIntegration()
    local test = IntegrationTest:new("Move Type Multiplier Integration")
    test:run()

    test:mockAOEnvironment()
    test:loadWeatherSystem()

    -- Set sunny weather
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "SUNNY",
            duration = 5
        }
    })

    test:assertResponse("SaveState", true)

    -- Check Fire move in sun (should be boosted)
    test:sendMessage("GetWeatherInfo", {
        parameters = {
            moveType = "FIRE",
            moveCategory = "SPECIAL"
        }
    })

    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.effects.typeMultiplier == 1.5, "Fire moves should get 1.5x in sun")
    assert(data.effects.moveBlocked == false, "Fire moves should not be blocked")

    -- Check Water move in sun (should be weakened)
    test:sendMessage("GetWeatherInfo", {
        parameters = {
            moveType = "WATER",
            moveCategory = "SPECIAL"
        }
    })

    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.effects.typeMultiplier == 0.5, "Water moves should get 0.5x in sun")

    return test:complete(true)
end

-- Test 5: Immutable Weather Behavior
local function testImmutableWeatherBehavior()
    local test = IntegrationTest:new("Immutable Weather Behavior")
    test:run()

    test:mockAOEnvironment()
    test:loadWeatherSystem()

    local scenario = test:createBattleScenario()

    -- Set harsh sun (immutable weather)
    test:sendMessage("SetWeather", {
        parameters = {
            weatherType = "HARSH_SUN",
            duration = 5 -- Should be ignored
        }
    })

    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.weather.turnsLeft == 0, "Immutable weather should have 0 turns")
    assert(data.weather.isActive == true, "Should be active")

    -- Process multiple turns - weather should never expire
    for i = 1, 10 do
        test:sendMessage("ProcessWeatherTurn", scenario)
        response = test:assertResponse("SaveState", true)
        data = json.decode(response.Data)
        assert(data.weather.isActive == true, "Should remain active after turn " .. i)
        assert(data.weather.weatherType == "HARSH_SUN", "Should remain harsh sun")
    end

    return test:complete(true)
end

-- Test 6: ADP Protocol Compliance
local function testADPProtocolCompliance()
    local test = IntegrationTest:new("ADP Protocol Compliance")
    test:run()

    test:mockAOEnvironment()
    test:loadWeatherSystem()

    -- Test Info handler
    test:sendMessage("Info", {})

    local response = test:getLastResponse()
    assert(response ~= nil, "Should respond to Info request")

    local data = json.decode(response.Data)
    assert(data.Name == "Weather System Engine", "Should have correct process name")
    assert(data.protocolVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(type(data.handlers) == "table", "Should have handlers array")
    assert(#data.handlers >= 6, "Should have at least 6 handlers")
    assert(type(data.capabilities) == "table", "Should have capabilities")
    assert(type(data.weatherTypes) == "table", "Should list weather types")
    assert(#data.weatherTypes == 10, "Should support all 10 weather types")

    -- Test Ping handler
    test:sendMessage("Ping", {})

    response = test:getLastResponse()
    assert(response ~= nil, "Should respond to Ping")
    assert(response.Action == "Pong", "Should send Pong response")
    assert(response.Data == "pong", "Should have pong data")

    return test:complete(true)
end

-- Test Runner
local function runIntegrationTests()
    print("🔗 Running Weather System Integration Tests...")
    print("=" .. string.rep("=", 70))

    local tests = {
        testCompleteWeatherLifecycle,
        testSandstormDamageIntegration,
        testWeatherOverwriteScenarios,
        testMoveTypeMultiplierIntegration,
        testImmutableWeatherBehavior,
        testADPProtocolCompliance
    }

    local passed = 0
    local failed = 0

    for _, testFunc in ipairs(tests) do
        local success, err = pcall(testFunc)
        if success and err then
            passed = passed + 1
        else
            failed = failed + 1
            if not success then
                print(string.format("❌ Test failed with error: %s", tostring(err)))
            end
        end
    end

    print("=" .. string.rep("=", 70))
    print(string.format("📊 Integration Test Results: %d passed, %d failed", passed, failed))

    if failed == 0 then
        print("🎉 All integration tests passed! Weather System ready for production.")
        return true
    else
        print("💥 Some integration tests failed. Please review and fix issues.")
        return false
    end
end

-- Export test runner
return {
    runIntegrationTests = runIntegrationTests,
    IntegrationTest = IntegrationTest
}