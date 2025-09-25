-- Terrain Effects Integration Tests
-- Tests terrain system interaction with battle processes

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
        id = "terrain_system_process_" .. tostring(math.random(100000, 999999)),
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

function IntegrationTest:loadTerrainSystem()
    -- Load terrain effects system process
    dofile("processes/terrain-effects-engine.lua")
    print("[LOAD] Terrain Effects Engine loaded successfully")
end

function IntegrationTest:createBattleScenario()
    -- Create a realistic battle scenario for testing
    return {
        gameState = {
            battle = {
                conditions = {
                    terrain = {
                        terrainType = "NONE",
                        turnsLeft = 0
                    }
                },
                playerParty = {
                    {
                        id = "player_pikachu",
                        name = "Pikachu",
                        types = {12}, -- Electric
                        maxHP = 200,
                        currentHP = 180,
                        isActive = true,
                        abilities = {
                            {name = "Static", active = false}
                        }
                    },
                    {
                        id = "player_venusaur", 
                        name = "Venusaur",
                        types = {11, 3}, -- Grass/Poison
                        maxHP = 230,
                        currentHP = 215,
                        isActive = false,
                        abilities = {
                            {name = "Overgrow", active = false}
                        }
                    }
                },
                enemyParty = {
                    {
                        id = "enemy_alakazam",
                        name = "Alakazam", 
                        types = {13}, -- Psychic
                        maxHP = 195,
                        currentHP = 195,
                        isActive = true,
                        abilities = {
                            {name = "Synchronize", active = true}
                        }
                    },
                    {
                        id = "enemy_crobat",
                        name = "Crobat",
                        types = {3, 2}, -- Poison/Flying
                        maxHP = 235,
                        currentHP = 235,
                        isActive = false,
                        abilities = {
                            {name = "Inner Focus", active = true}
                        }
                    }
                }
            },
            battleSeed = "integration_test_terrain_12345"
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
        ["SetTerrain"] = "set-terrain",
        ["ProcessTerrainTurn"] = "process-terrain-turn", 
        ["ClearTerrain"] = "clear-terrain",
        ["GetTerrainInfo"] = "get-terrain-info",
        ["CheckMoveBlocking"] = "check-move-blocking",
        ["CalculateTypeMultiplier"] = "calculate-type-multiplier",
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

-- Test 1: Complete Terrain Lifecycle
local function testCompleteTerrainLifecycle()
    local test = IntegrationTest:new("Complete Terrain Lifecycle")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    local scenario = test:createBattleScenario()
    
    -- Step 1: Set electric terrain
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "ELECTRIC",
            duration = 3,
            overwrite = true
        }
    })
    
    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.terrain.terrainType == "ELECTRIC", "Should set electric terrain")
    assert(data.terrain.turnsLeft == 3, "Should set 3 turns duration")
    assert(#data.messages == 1, "Should have start message")
    
    -- Step 2: Process first terrain turn  
    test:sendMessage("ProcessTerrainTurn", scenario)
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.terrain.turnsLeft == 2, "Should decrement to 2 turns")
    assert(data.terrain.isActive == true, "Should still be active")
    
    -- Step 3: Process second terrain turn
    test:sendMessage("ProcessTerrainTurn", scenario)
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.terrain.turnsLeft == 1, "Should decrement to 1 turn")
    
    -- Step 4: Process final terrain turn (should expire)
    test:sendMessage("ProcessTerrainTurn", scenario)
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.terrain.turnsLeft == 0, "Should expire")
    assert(data.terrain.isActive == false, "Should become inactive")
    assert(data.terrain.terrainType == "NONE", "Should clear terrain")
    
    return test:complete(true)
end

-- Test 2: Grassy Terrain Healing Integration
local function testGrassyTerrainHealingIntegration()
    local test = IntegrationTest:new("Grassy Terrain Healing Integration")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    local scenario = test:createBattleScenario()
    
    -- Set grassy terrain
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "GRASSY",
            duration = 5
        }
    })
    
    test:assertResponse("SaveState", true)
    
    -- Process terrain turn with healing
    test:sendMessage("ProcessTerrainTurn", scenario)
    
    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    
    -- Pikachu (Electric, damaged) should get healed if grounded
    -- Crobat (Poison/Flying) should not get healed due to Flying type
    local healingDealt = data.effects.healingDealt
    assert(#healingDealt >= 1, "Should heal at least one Pokemon")
    
    local pikachuHealing = nil
    for _, healing in ipairs(healingDealt) do
        if healing.pokemonId == "player_pikachu" then
            pikachuHealing = healing
            break
        end
    end
    
    assert(pikachuHealing ~= nil, "Pikachu should receive Grassy terrain healing")
    assert(pikachuHealing.healAmount == 12, "Should heal 1/16 max HP (200/16=12.5, floored=12)")
    
    return test:complete(true)
end

-- Test 3: Terrain Overwrite Scenarios
local function testTerrainOverwriteScenarios()
    local test = IntegrationTest:new("Terrain Overwrite Scenarios")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    -- Set initial electric terrain
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "ELECTRIC",
            duration = 5
        }
    })
    
    test:assertResponse("SaveState", true)
    
    -- Try to set grassy terrain without overwrite (should fail)
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "GRASSY",
            duration = 3,
            overwrite = false
        }
    })
    
    local response = test:assertResponse("SaveState", false)
    local data = json.decode(response.Data)
    assert(data.success == false, "Should fail without overwrite")
    
    -- Now set grassy terrain with overwrite (should succeed)
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "GRASSY",
            duration = 3,
            overwrite = true
        }
    })
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.terrain.terrainType == "GRASSY", "Should overwrite with grassy terrain")
    assert(data.terrain.turnsLeft == 3, "Should set new duration")
    
    return test:complete(true)
end

-- Test 4: Move Type Multiplier Integration
local function testMoveTypeMultiplierIntegration()
    local test = IntegrationTest:new("Move Type Multiplier Integration")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    -- Set electric terrain
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "ELECTRIC",
            duration = 5
        }
    })
    
    test:assertResponse("SaveState", true)
    
    -- Check Electric move on Electric terrain (should be boosted)
    test:sendMessage("CalculateTypeMultiplier", {
        parameters = {
            moveType = "ELECTRIC",
            pokemon = {
                id = "player_pikachu",
                types = {12}, -- Electric (grounded)
                abilities = {}
            }
        }
    })
    
    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.typeMultiplier == 1.3, "Electric moves should get 1.3x on Electric terrain")
    assert(data.boostMessage ~= "", "Should have boost message")
    
    -- Check same move with Flying Pokemon (should not be boosted)
    test:sendMessage("CalculateTypeMultiplier", {
        parameters = {
            moveType = "ELECTRIC",
            pokemon = {
                id = "enemy_crobat",
                types = {3, 2}, -- Poison/Flying (not grounded)
                abilities = {}
            }
        }
    })
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.typeMultiplier == 1.0, "Flying Pokemon should not get terrain multipliers")
    
    return test:complete(true)
end

-- Test 5: Psychic Terrain Move Blocking
local function testPsychicTerrainMoveBlocking()
    local test = IntegrationTest:new("Psychic Terrain Move Blocking")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    -- Set psychic terrain
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "PSYCHIC",
            duration = 5
        }
    })
    
    test:assertResponse("SaveState", true)
    
    -- Test priority move against grounded Pokemon (should be blocked)
    test:sendMessage("CheckMoveBlocking", {
        parameters = {
            moveData = {
                priority = 1, -- Priority move
                targetsOpponent = true,
                target = "SINGLE"
            },
            targetPokemon = {
                id = "player_pikachu",
                types = {12}, -- Electric (grounded)
                abilities = {}
            }
        }
    })
    
    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.moveBlocked == true, "Priority moves should be blocked on Psychic terrain")
    assert(data.blockMessage ~= "", "Should have block message")
    
    -- Test priority move against Flying Pokemon (should not be blocked)
    test:sendMessage("CheckMoveBlocking", {
        parameters = {
            moveData = {
                priority = 1, -- Priority move
                targetsOpponent = true,
                target = "SINGLE"
            },
            targetPokemon = {
                id = "enemy_crobat",
                types = {3, 2}, -- Poison/Flying (not grounded)
                abilities = {}
            }
        }
    })
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.moveBlocked == false, "Flying Pokemon should not be affected by terrain blocking")
    
    -- Test normal priority move (should not be blocked)
    test:sendMessage("CheckMoveBlocking", {
        parameters = {
            moveData = {
                priority = 0, -- Normal priority
                targetsOpponent = true,
                target = "SINGLE"
            },
            targetPokemon = {
                id = "player_pikachu",
                types = {12}, -- Electric (grounded)
                abilities = {}
            }
        }
    })
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.moveBlocked == false, "Normal priority moves should not be blocked")
    
    return test:complete(true)
end

-- Test 6: Misty Terrain Status Prevention
local function testMistyTerrainStatusPrevention()
    local test = IntegrationTest:new("Misty Terrain Status Prevention")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    -- Set misty terrain
    test:sendMessage("SetTerrain", {
        parameters = {
            terrainType = "MISTY",
            duration = 5
        }
    })
    
    test:assertResponse("SaveState", true)
    
    -- Check status prevention for grounded Pokemon
    test:sendMessage("GetTerrainInfo", {
        parameters = {
            statusCondition = "SLEEP",
            targetPokemon = {
                id = "player_pikachu",
                types = {12}, -- Electric (grounded)
                abilities = {}
            }
        }
    })
    
    local response = test:assertResponse("SaveState", true)
    local data = json.decode(response.Data)
    assert(data.effects.statusPrevented == true, "Misty terrain should prevent sleep on grounded Pokemon")
    assert(data.effects.preventMessage ~= "", "Should have prevent message")
    
    -- Check status prevention for Flying Pokemon (should not be prevented)
    test:sendMessage("GetTerrainInfo", {
        parameters = {
            statusCondition = "PARALYSIS",
            targetPokemon = {
                id = "enemy_crobat",
                types = {3, 2}, -- Poison/Flying (not grounded)
                abilities = {}
            }
        }
    })
    
    response = test:assertResponse("SaveState", true)
    data = json.decode(response.Data)
    assert(data.effects.statusPrevented == false, "Flying Pokemon should not be protected by Misty terrain")
    
    return test:complete(true)
end

-- Test 7: Multi-Terrain Type Testing
local function testMultiTerrainTypes()
    local test = IntegrationTest:new("Multi-Terrain Type Testing")
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    local terrainTypes = {"ELECTRIC", "GRASSY", "MISTY", "PSYCHIC"}
    local expectedMultipliers = {
        ELECTRIC = {ELECTRIC = 1.3, FIRE = 1.0},
        GRASSY = {GRASS = 1.3, FIRE = 1.0},
        MISTY = {ELECTRIC = 1.0, FIRE = 1.0}, -- No multipliers
        PSYCHIC = {PSYCHIC = 1.3, FIRE = 1.0}
    }
    
    for _, terrainType in ipairs(terrainTypes) do
        -- Set terrain
        test:sendMessage("SetTerrain", {
            parameters = {
                terrainType = terrainType,
                duration = 5
            }
        })
        
        test:assertResponse("SaveState", true)
        
        -- Test type multipliers for this terrain
        local multipliers = expectedMultipliers[terrainType]
        for moveType, expectedMultiplier in pairs(multipliers) do
            test:sendMessage("CalculateTypeMultiplier", {
                parameters = {
                    moveType = moveType,
                    pokemon = {
                        id = "test_pokemon",
                        types = {0}, -- Normal (grounded)
                        abilities = {}
                    }
                }
            })
            
            local response = test:assertResponse("SaveState", true)
            local data = json.decode(response.Data)
            assert(data.typeMultiplier == expectedMultiplier, 
                string.format("%s moves should get %sx on %s terrain", moveType, expectedMultiplier, terrainType))
        end
    end
    
    return test:complete(true)
end

-- Test 8: ADP Protocol Compliance
local function testADPProtocolCompliance()
    local test = IntegrationTest:new("ADP Protocol Compliance")  
    test:run()
    
    test:mockAOEnvironment()
    test:loadTerrainSystem()
    
    -- Test Info handler
    test:sendMessage("Info", {})
    
    local response = test:getLastResponse()
    assert(response ~= nil, "Should respond to Info request")
    
    local data = json.decode(response.Data)
    assert(data.Name == "Terrain Effects Engine", "Should have correct process name")
    assert(data.protocolVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(type(data.handlers) == "table", "Should have handlers array")
    assert(#data.handlers >= 7, "Should have at least 7 handlers")
    assert(type(data.capabilities) == "table", "Should have capabilities")
    assert(type(data.terrainTypes) == "table", "Should list terrain types")
    assert(#data.terrainTypes == 5, "Should support all 5 terrain types (including NONE)")
    
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
    print("🔗 Running Terrain Effects Integration Tests...")
    print("=" .. string.rep("=", 70))
    
    local tests = {
        testCompleteTerrainLifecycle,
        testGrassyTerrainHealingIntegration,
        testTerrainOverwriteScenarios,
        testMoveTypeMultiplierIntegration,
        testPsychicTerrainMoveBlocking,
        testMistyTerrainStatusPrevention,
        testMultiTerrainTypes,
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
        print("🎉 All integration tests passed! Terrain Effects ready for production.")
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