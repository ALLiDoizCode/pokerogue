-- testing/unit/battle-state-manager.test.lua
-- Aolite Unit Tests for Battle State Manager AO Process
-- Tests comprehensive battle state management functionality

local aolite = require('aolite')

-- Mock JSON module for testing
local json = {
    encode = function(obj)
        -- Simple JSON encode for testing
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                local key = type(k) == "string" and '"' .. k .. '"' or tostring(k)
                local value = type(v) == "string" and '"' .. v .. '"' or 
                             type(v) == "table" and json.encode(v) or 
                             tostring(v)
                table.insert(parts, key .. ":" .. value)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            return type(obj) == "string" and '"' .. obj .. '"' or tostring(obj)
        end
    end,
    decode = function(str)
        -- Simple JSON decode for testing - basic implementation
        if not str or str == "" then return nil end
        if str == "null" then return nil end
        if str == "true" then return true end
        if str == "false" then return false end
        if str:match("^%d+$") then return tonumber(str) end
        if str:match("^\".*\"$") then return str:sub(2, -2) end
        -- For simple object decode (limited functionality for tests)
        if str:match("^%{.*%}$") then
            return {
                id = "test_pokemon",
                hp = 85,
                maxHp = 100,
                status = "healthy"
            }
        end
        return str
    end
}

-- Initialize aolite environment
local process = nil

-- Setup function to load the battle state manager process
local function setup()
    -- Create a new process instance
    process = aolite.spawnProcess()
    
    -- Load the battle state manager process code
    local processCode = io.open("/Users/jonathangreen/Documents/pokerogue/processes/battle-state-manager.lua", "r")
    if not processCode then
        error("Could not load battle-state-manager.lua")
    end
    
    local code = processCode:read("*all")
    processCode:close()
    
    -- Evaluate the process code
    local success, err = aolite.eval(process, code)
    if not success then
        error("Failed to load process: " .. tostring(err))
    end
    
    print("Battle State Manager process loaded successfully")
    return process
end

-- Test Pokemon State Management
local function testPokemonStateManagement()
    print("\n=== Testing Pokemon State Management with Aolite ===")
    
    local testBattleId = "battle_" .. tostring(os.time())
    local testPokemonId = "pikachu_001"
    
    -- Test 1: Update Pokemon State
    local pokemonStateData = {
        id = testPokemonId,
        hp = 85,
        maxHp = 100,
        status = "poisoned",
        stats = {
            hp = 100,
            attack = 85,
            defense = 75,
            spatk = 90,
            spdef = 80,
            speed = 110
        },
        battleData = {
            turnsInBattle = 5,
            statusTurns = 2,
            confusionTurns = 0
        },
        temporaryModifications = {
            statBoosts = {attack = 2, speed = 1},
            abilities = {"static"},
            items = {"leftovers"}
        },
        moveset = {
            {id = "thunderbolt", pp = 14, maxPP = 15},
            {id = "quick_attack", pp = 29, maxPP = 30},
            {id = "iron_tail", pp = 14, maxPP = 15},
            {id = "double_team", pp = 15, maxPP = 15}
        }
    }
    
    local updateMessage = {
        Action = "UpdatePokemonState",
        From = "test_trainer",
        BattleId = testBattleId,
        PokemonId = testPokemonId,
        Data = json.encode(pokemonStateData),
        Timestamp = tostring(os.time())
    }
    
    print("Sending Pokemon state update...")
    local responses = aolite.send(process, updateMessage)
    
    -- Verify response
    if #responses > 0 then
        local response = responses[1]
        print("Response Action:", response.Action)
        print("Response Success:", response.Success)
        
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Pokemon state updated successfully")
                print("  Pokemon HP:", responseData.pokemonState.hp .. "/" .. responseData.pokemonState.maxHp)
                print("  Status:", responseData.pokemonState.status)
                print("  Stat boosts:", json.encode(responseData.pokemonState.temporaryModifications.statBoosts))
            else
                print("✗ Pokemon state update failed:", responseData and responseData.error or "Unknown error")
            end
        else
            print("✗ Pokemon state update failed:", response.Error)
        end
    else
        print("✗ No response received for Pokemon state update")
    end
    
    -- Test 2: Update Pokemon HP (damage scenario)
    pokemonStateData.hp = 45
    pokemonStateData.battleData.turnsInBattle = 6
    
    local damageMessage = {
        Action = "UpdatePokemonState",
        From = "test_trainer",
        BattleId = testBattleId,
        PokemonId = testPokemonId,
        Data = json.encode(pokemonStateData),
        Timestamp = tostring(os.time())
    }
    
    print("\nSending Pokemon damage update...")
    local damageResponses = aolite.send(process, damageMessage)
    
    if #damageResponses > 0 then
        local response = damageResponses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success and responseData.stateChanges then
                print("✓ Pokemon damage tracked successfully")
                print("  State changes:", #responseData.stateChanges)
                for _, change in ipairs(responseData.stateChanges) do
                    print("    " .. change.field .. ": " .. tostring(change.from) .. " -> " .. tostring(change.to))
                end
            end
        end
    end
end

-- Test Field Condition Management
local function testFieldConditionManagement()
    print("\n=== Testing Field Condition Management with Aolite ===")
    
    local testBattleId = "battle_" .. tostring(os.time())
    
    -- Test weather and terrain setup
    local fieldData = {
        weather = {
            type = "rain",
            turnsRemaining = 6
        },
        terrain = {
            type = "electric",
            turnsRemaining = 8
        },
        effects = {
            trickRoom = {active = true, turnsRemaining = 4},
            tailwind = {active = false, turnsRemaining = 0}
        },
        hazards = {
            spikes = {layers = 1, side = "opponent"},
            stealthRock = {active = true, side = "opponent"},
            toxicSpikes = {layers = 0, side = "player"}
        },
        screens = {
            lightScreen = {turnsRemaining = 4, side = "player"},
            reflect = {turnsRemaining = 0, side = "player"},
            auroraVeil = {turnsRemaining = 0, side = "opponent"}
        }
    }
    
    local conditionMessage = {
        Action = "ManageFieldConditions",
        From = "test_battle_system",
        BattleId = testBattleId,
        Data = json.encode(fieldData),
        TurnNumber = "8",
        Timestamp = tostring(os.time())
    }
    
    print("Setting up field conditions...")
    local responses = aolite.send(process, conditionMessage)
    
    if #responses > 0 then
        local response = responses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Field conditions set successfully")
                print("  Weather:", responseData.fieldConditions.weather and responseData.fieldConditions.weather.type or "none")
                print("  Terrain:", responseData.fieldConditions.terrain and responseData.fieldConditions.terrain.type or "none")
                print("  Active effects:", #(responseData.fieldConditions.effects or {}))
                print("  Expirations:", #responseData.expirations)
            end
        else
            print("✗ Field condition setup failed:", response.Error)
        end
    end
end

-- Test Battle Participant Management
local function testBattleParticipantManagement()
    print("\n=== Testing Battle Participant Management with Aolite ===")
    
    local testBattleId = "battle_" .. tostring(os.time())
    
    -- Test party setup
    local participantData = {
        active = {
            [1] = {id = "charizard_001", hp = 140, maxHp = 150, position = 1},
            [2] = {id = "blastoise_001", hp = 130, maxHp = 140, position = 2}
        },
        party = {
            {id = "pikachu_001", hp = 95, maxHp = 100},
            {id = "venusaur_001", hp = 120, maxHp = 125},
            {id = "alakazam_001", hp = 90, maxHp = 95},
            {id = "machamp_001", hp = 110, maxHp = 115}
        },
        bench = {},
        substitutes = {},
        trainers = {
            player = {id = "ash", name = "Ash"},
            opponent = {id = "rival", name = "Gary"}
        }
    }
    
    local participantMessage = {
        Action = "ManageBattleParticipants",
        From = "test_battle_system",
        BattleId = testBattleId,
        Data = json.encode(participantData),
        Operation = "update",
        Timestamp = tostring(os.time())
    }
    
    print("Setting up battle participants...")
    local responses = aolite.send(process, participantMessage)
    
    if #responses > 0 then
        local response = responses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Battle participants set successfully")
                print("  Active Pokemon:", #(responseData.participants.active or {}))
                print("  Party size:", #(responseData.participants.party or {}))
                print("  Operation:", responseData.operation)
            end
        else
            print("✗ Battle participant setup failed:", response.Error)
        end
    end
    
    -- Test switching
    print("\nTesting Pokemon switching...")
    local switchData = {
        switchOut = {id = "charizard_001", position = 1},
        switchIn = {id = "pikachu_001", position = 1, hp = 95, maxHp = 100}
    }
    
    local switchMessage = {
        Action = "ManageBattleParticipants",
        From = "test_battle_system",
        BattleId = testBattleId,
        Data = json.encode(switchData),
        Operation = "switch",
        Timestamp = tostring(os.time())
    }
    
    local switchResponses = aolite.send(process, switchMessage)
    if #switchResponses > 0 then
        local response = switchResponses[1]
        if response.Success == "true" then
            print("✓ Pokemon switch executed successfully")
        else
            print("✗ Pokemon switch failed:", response.Error)
        end
    end
end

-- Test Move History and Event Logging
local function testMoveHistoryAndEventLogging()
    print("\n=== Testing Move History and Event Logging with Aolite ===")
    
    local testBattleId = "battle_" .. tostring(os.time())
    
    -- Test move usage tracking
    local moveData = {
        pokemonId = "pikachu_001",
        moveId = "thunderbolt",
        moveName = "Thunderbolt",
        targets = {"opponent_charizard_001"},
        result = "hit",
        ppUsed = 1,
        maxPP = 15
    }
    
    local moveMessage = {
        Action = "TrackMoveHistory",
        From = "test_battle_system",
        BattleId = testBattleId,
        Data = json.encode(moveData),
        TurnNumber = "5",
        Timestamp = tostring(os.time())
    }
    
    print("Tracking move usage...")
    local moveResponses = aolite.send(process, moveMessage)
    
    if #moveResponses > 0 then
        local response = moveResponses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Move usage tracked successfully")
                print("  Move history entries:", #responseData.moveHistory)
                print("  PP tracking entries:", responseData.ppTracking and "active" or "none")
            end
        else
            print("✗ Move tracking failed:", response.Error)
        end
    end
    
    -- Test battle event logging
    print("\nTesting battle event logging...")
    local eventData = {
        type = "damage",
        turn = 5,
        pokemonId = "opponent_charizard_001",
        attacker = "pikachu_001",
        defender = "opponent_charizard_001",
        damage = 68,
        moveId = "thunderbolt",
        critical = true,
        effectiveness = 2.0,
        breakdown = {
            basePower = 90,
            attackStat = 85,
            defenseStat = 65,
            stab = 1.5,
            typeEffectiveness = 2.0,
            critical = 1.5,
            randomFactor = 0.92
        }
    }
    
    local eventMessage = {
        Action = "LogBattleEvents",
        From = "test_battle_system",
        BattleId = testBattleId,
        EventType = "damage",
        Data = json.encode(eventData),
        Timestamp = tostring(os.time())
    }
    
    local eventResponses = aolite.send(process, eventMessage)
    
    if #eventResponses > 0 then
        local response = eventResponses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Battle event logged successfully")
                print("  Event ID:", responseData.eventId)
                print("  Total events:", responseData.totalEvents)
            end
        else
            print("✗ Event logging failed:", response.Error)
        end
    end
end

-- Test State Serialization
local function testStateSerialization()
    print("\n=== Testing State Serialization with Aolite ===")
    
    local testBattleId = "battle_" .. tostring(os.time())
    
    -- First populate some state data by running previous tests on same battle
    -- ... (would use the same battle ID in real integration)
    
    -- Test serialization
    local serializeMessage = {
        Action = "SerializeBattleState",
        From = "test_system",
        BattleId = testBattleId,
        IncludeHistory = "true",
        Timestamp = tostring(os.time())
    }
    
    print("Serializing battle state...")
    local serializeResponses = aolite.send(process, serializeMessage)
    
    if #serializeResponses > 0 then
        local response = serializeResponses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Battle state serialized successfully")
                print("  Checksum:", responseData.checksum and responseData.checksum:sub(1, 20) .. "..." or "none")
                print("  Size:", responseData.size, "bytes")
                print("  Version:", responseData.version)
                print("  Include history:", responseData.includeHistory)
                
                -- Test deserialization
                local deserializeMessage = {
                    Action = "DeserializeBattleState",
                    From = "test_system",
                    BattleId = testBattleId .. "_restored",
                    Data = responseData.serializedState,
                    Checksum = responseData.checksum,
                    Timestamp = tostring(os.time())
                }
                
                print("\nDeserializing battle state...")
                local deserializeResponses = aolite.send(process, deserializeMessage)
                
                if #deserializeResponses > 0 then
                    local deserializeResponse = deserializeResponses[1]
                    if deserializeResponse.Success == "true" then
                        local deserializeData = json.decode(deserializeResponse.Data)
                        if deserializeData and deserializeData.success then
                            print("✓ Battle state deserialized successfully")
                            print("  Restored components:")
                            for component, restored in pairs(deserializeData.restoredComponents) do
                                print("    " .. component .. ": " .. (restored and "✓" or "✗"))
                            end
                        end
                    else
                        print("✗ Deserialization failed:", deserializeResponse.Error)
                    end
                end
            end
        else
            print("✗ Serialization failed:", response.Error)
        end
    end
end

-- Test Memory Management
local function testMemoryManagement()
    print("\n=== Testing Memory Management with Aolite ===")
    
    -- Test cleanup operation
    local cleanupMessage = {
        Action = "ManageMemory",
        From = "test_system",
        Operation = "cleanup",
        Timestamp = tostring(os.time())
    }
    
    print("Running memory cleanup...")
    local cleanupResponses = aolite.send(process, cleanupMessage)
    
    if #cleanupResponses > 0 then
        local response = cleanupResponses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ Memory cleanup completed successfully")
                print("  Active battles before:", responseData.stats.before.activeBattles)
                print("  Active battles after:", responseData.stats.after.activeBattles)
                print("  Cleaned battles:", responseData.stats.cleaned or 0)
            end
        else
            print("✗ Memory cleanup failed:", response.Error)
        end
    end
    
    -- Test state validation
    local validateMessage = {
        Action = "ManageMemory",
        From = "test_system",
        Operation = "validate",
        Timestamp = tostring(os.time())
    }
    
    print("\nRunning state validation...")
    local validateResponses = aolite.send(process, validateMessage)
    
    if #validateResponses > 0 then
        local response = validateResponses[1]
        if response.Success == "true" then
            local responseData = json.decode(response.Data)
            if responseData and responseData.success then
                print("✓ State validation completed successfully")
                print("  Validation issues found:", #(responseData.stats.validationIssues or {}))
            end
        else
            print("✗ State validation failed:", response.Error)
        end
    end
end

-- Test ADP Compliance
local function testADPCompliance()
    print("\n=== Testing ADP Compliance with Aolite ===")
    
    local infoMessage = {
        Action = "Info",
        From = "test_system"
    }
    
    print("Requesting process info...")
    local infoResponses = aolite.send(process, infoMessage)
    
    if #infoResponses > 0 then
        local response = infoResponses[1]
        if response.Action == "InfoResponse" then
            local infoData = json.decode(response.Data)
            if infoData then
                print("✓ ADP Info response received successfully")
                print("  Process name:", infoData.Name)
                print("  Protocol version:", infoData.protocolVersion)
                print("  ADP version:", infoData.adpVersion)
                print("  Handlers count:", #infoData.handlers)
                print("  Capabilities count:", #infoData.capabilities)
            else
                print("✗ Invalid ADP Info response data")
            end
        else
            print("✗ Invalid ADP response action:", response.Action)
        end
    else
        print("✗ No ADP Info response received")
    end
end

-- Main test runner
local function runAllTests()
    print("Starting Aolite Unit Tests for Battle State Manager")
    print("=" .. string.rep("=", 60))
    
    -- Setup the process
    setup()
    
    -- Run all test suites
    testPokemonStateManagement()
    testFieldConditionManagement()
    testBattleParticipantManagement()
    testMoveHistoryAndEventLogging()
    testStateSerialization()
    testMemoryManagement()
    testADPCompliance()
    
    print("\n" .. string.rep("=", 60))
    print("Aolite Battle State Manager Unit Tests Complete")
    
    -- Clean up
    if process then
        aolite.close(process)
    end
end

-- Execute the tests if run directly
if not pcall(debug.getlocal, 4, 1) then
    runAllTests()
end

return {
    runAllTests = runAllTests,
    setup = setup,
    testPokemonStateManagement = testPokemonStateManagement,
    testFieldConditionManagement = testFieldConditionManagement,
    testBattleParticipantManagement = testBattleParticipantManagement,
    testMoveHistoryAndEventLogging = testMoveHistoryAndEventLogging,
    testStateSerialization = testStateSerialization,
    testMemoryManagement = testMemoryManagement,
    testADPCompliance = testADPCompliance
}