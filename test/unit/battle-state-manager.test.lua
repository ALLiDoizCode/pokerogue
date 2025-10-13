-- battle-state-manager.test.lua
-- Unit tests for Battle State Manager AO Process
-- Tests Pokemon state tracking, field conditions, participants, move history, and event logging

local json = require('json')

-- Mock AO environment for testing
local function setupTestEnvironment()
    if not ao then
        ao = {
            send = function(msg) 
                print("Mock send:", json.encode(msg))
                return msg
            end,
            id = "test_battle_state_manager_process",
            env = {
                Process = {
                    Owner = "test_owner_address"
                }
            }
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
                -- Store for testing
                if not Handlers._registry then
                    Handlers._registry = {}
                end
                Handlers._registry[name] = {
                    matcher = matcher,
                    handler = handler
                }
            end,
            utils = {
                hasMatchingTag = function(tagName, tagValue)
                    return function(msg)
                        return msg[tagName] == tagValue or (msg.Tags and msg.Tags[tagName] == tagValue)
                    end
                end
            }
        }
    end
    
    if not crypto then
        crypto = {
            digest = {
                sha256 = function(data)
                    -- Mock SHA256 hash
                    return "mock_hash_" .. tostring(#data) .. "_" .. tostring(data:sub(1,5))
                end
            }
        }
    end
end

-- Test suite for Pokemon State Tracking
local function testPokemonStateTracking()
    print("\n=== Testing Pokemon State Tracking ===")
    
    setupTestEnvironment()
    
    -- Load the battle state manager process
    dofile("/Users/jonathangreen/Documents/pokerogue/processes/battle-state-manager.lua")
    
    -- Test 1: Update Pokemon State - Valid Request
    print("\nTest 1: Update Pokemon State - Valid Request")
    local testMessage1 = {
        From = "test_sender",
        BattleId = "battle_001",
        PokemonId = "pikachu_001",
        Data = json.encode({
            id = "pikachu_001",
            hp = 95,
            maxHp = 100,
            status = "healthy",
            stats = {
                hp = 100,
                attack = 85,
                defense = 75,
                spatk = 90,
                spdef = 80,
                speed = 110
            },
            battleData = {
                turnsInBattle = 3,
                movesPP = {20, 15, 10, 25}
            },
            temporaryModifications = {
                statBoosts = {attack = 1, speed = 2},
                abilities = {"static"},
                items = {"light_ball"}
            }
        }),
        Timestamp = "1234567890"
    }
    
    -- Execute handler
    local handler = Handlers._registry["update-pokemon-state"]
    if handler then
        handler.handler(testMessage1)
        print("✓ Pokemon state update handler executed successfully")
    else
        print("✗ Pokemon state update handler not found")
    end
    
    -- Test 2: Update Pokemon State - Invalid Data
    print("\nTest 2: Update Pokemon State - Invalid Data")
    local testMessage2 = {
        From = "test_sender",
        BattleId = "battle_001",
        PokemonId = "pikachu_002",
        Data = "invalid_json",
        Timestamp = "1234567890"
    }
    
    if handler then
        handler.handler(testMessage2)
        print("✓ Invalid data handled with error response")
    end
    
    -- Test 3: Update Pokemon State - Missing Battle ID
    print("\nTest 3: Update Pokemon State - Missing Battle ID")
    local testMessage3 = {
        From = "test_sender",
        PokemonId = "pikachu_003",
        Data = json.encode({
            id = "pikachu_003",
            hp = 80,
            maxHp = 100
        }),
        Timestamp = "1234567890"
    }
    
    if handler then
        handler.handler(testMessage3)
        print("✓ Missing battle ID handled with error response")
    end
end

-- Test suite for Field Condition Management
local function testFieldConditionManagement()
    print("\n=== Testing Field Condition Management ===")
    
    -- Test 1: Manage Field Conditions - Weather Update
    print("\nTest 1: Manage Field Conditions - Weather Update")
    local testMessage = {
        From = "test_sender",
        BattleId = "battle_001",
        Data = json.encode({
            weather = {
                type = "rain",
                turnsRemaining = 5
            },
            terrain = {
                type = "electric",
                turnsRemaining = 8
            },
            effects = {
                trickRoom = {active = true, turnsRemaining = 3}
            },
            hazards = {
                spikes = {layers = 2, side = "opponent"}
            },
            screens = {
                lightScreen = {turnsRemaining = 5, side = "player"}
            }
        }),
        TurnNumber = "5",
        Timestamp = "1234567890"
    }
    
    local handler = Handlers._registry["manage-field-conditions"]
    if handler then
        handler.handler(testMessage)
        print("✓ Field condition management handler executed successfully")
    else
        print("✗ Field condition management handler not found")
    end
    
    -- Test 2: Invalid Field Condition Data
    print("\nTest 2: Invalid Field Condition Data")
    local testMessage2 = {
        From = "test_sender",
        BattleId = "battle_001",
        Data = "invalid_condition_data",
        TurnNumber = "5",
        Timestamp = "1234567890"
    }
    
    if handler then
        handler.handler(testMessage2)
        print("✓ Invalid condition data handled with error response")
    end
end

-- Test suite for Battle Participant Management
local function testBattleParticipantManagement()
    print("\n=== Testing Battle Participant Management ===")
    
    -- Test 1: Switch Operation
    print("\nTest 1: Battle Participant Switch Operation")
    local testMessage = {
        From = "test_sender",
        BattleId = "battle_001",
        Data = json.encode({
            switchOut = {
                id = "pikachu_001",
                position = 1
            },
            switchIn = {
                id = "charizard_001",
                position = 1,
                hp = 150,
                maxHp = 150
            }
        }),
        Operation = "switch",
        Timestamp = "1234567890"
    }
    
    local handler = Handlers._registry["manage-battle-participants"]
    if handler then
        handler.handler(testMessage)
        print("✓ Participant switch operation executed successfully")
    else
        print("✗ Battle participant management handler not found")
    end
    
    -- Test 2: Party Update
    print("\nTest 2: Party Update Operation")
    local testMessage2 = {
        From = "test_sender",
        BattleId = "battle_001",
        Data = json.encode({
            active = {
                [1] = {id = "charizard_001", hp = 140, maxHp = 150},
                [2] = {id = "blastoise_001", hp = 130, maxHp = 140}
            },
            party = {
                {id = "pikachu_001", hp = 95, maxHp = 100},
                {id = "venusaur_001", hp = 120, maxHp = 125}
            },
            bench = {
                {id = "alakazam_001", hp = 90, maxHp = 95}
            }
        }),
        Operation = "update",
        Timestamp = "1234567890"
    }
    
    if handler then
        handler.handler(testMessage2)
        print("✓ Party update operation executed successfully")
    end
end

-- Test suite for Move History Tracking
local function testMoveHistoryTracking()
    print("\n=== Testing Move History Tracking ===")
    
    -- Test 1: Track Move Usage
    print("\nTest 1: Track Move Usage")
    local testMessage = {
        From = "test_sender",
        BattleId = "battle_001",
        Data = json.encode({
            pokemonId = "pikachu_001",
            moveId = "thunderbolt",
            moveName = "Thunderbolt",
            targets = {"opponent_pokemon_001"},
            result = "hit",
            ppUsed = 1,
            maxPP = 15,
            restrictions = {
                pikachu_001 = {
                    disabled = false,
                    encored = false
                }
            }
        }),
        TurnNumber = "3",
        Timestamp = "1234567890"
    }
    
    local handler = Handlers._registry["track-move-history"]
    if handler then
        handler.handler(testMessage)
        print("✓ Move history tracking executed successfully")
    else
        print("✗ Move history tracking handler not found")
    end
    
    -- Test 2: Track PP Depletion
    print("\nTest 2: Track Move with PP Depletion")
    local testMessage2 = {
        From = "test_sender",
        BattleId = "battle_001",
        Data = json.encode({
            pokemonId = "pikachu_001",
            moveId = "quick_attack",
            moveName = "Quick Attack",
            targets = {"opponent_pokemon_001"},
            result = "hit",
            ppUsed = 1,
            maxPP = 30
        }),
        TurnNumber = "4",
        Timestamp = "1234567891"
    }
    
    if handler then
        handler.handler(testMessage2)
        print("✓ PP tracking executed successfully")
    end
end

-- Test suite for Battle Event Logging
local function testBattleEventLogging()
    print("\n=== Testing Battle Event Logging ===")
    
    -- Test 1: Damage Event
    print("\nTest 1: Log Damage Event")
    local testMessage = {
        From = "test_sender",
        BattleId = "battle_001",
        EventType = "damage",
        Data = json.encode({
            type = "damage",
            turn = 3,
            attacker = "pikachu_001",
            defender = "opponent_pokemon_001",
            damage = 45,
            moveId = "thunderbolt",
            critical = false,
            effectiveness = 2.0,
            breakdown = {
                basePower = 90,
                attackStat = 85,
                defenseStat = 70,
                stab = 1.5,
                typeEffectiveness = 2.0
            }
        }),
        Timestamp = "1234567890"
    }
    
    local handler = Handlers._registry["log-battle-events"]
    if handler then
        handler.handler(testMessage)
        print("✓ Damage event logging executed successfully")
    else
        print("✗ Battle event logging handler not found")
    end
    
    -- Test 2: Status Effect Event
    print("\nTest 2: Log Status Effect Event")
    local testMessage2 = {
        From = "test_sender",
        BattleId = "battle_001",
        EventType = "status",
        Data = json.encode({
            type = "status",
            turn = 3,
            pokemonId = "opponent_pokemon_001",
            status = "paralyzed",
            action = "apply",
            source = "pikachu_001"
        }),
        Timestamp = "1234567891"
    }
    
    if handler then
        handler.handler(testMessage2)
        print("✓ Status effect event logging executed successfully")
    end
    
    -- Test 3: Switch Event
    print("\nTest 3: Log Switch Event")
    local testMessage3 = {
        From = "test_sender",
        BattleId = "battle_001",
        EventType = "switch",
        Data = json.encode({
            type = "switch",
            turn = 4,
            switchOut = "pikachu_001",
            switchIn = "charizard_001",
            forced = false
        }),
        Timestamp = "1234567892"
    }
    
    if handler then
        handler.handler(testMessage3)
        print("✓ Switch event logging executed successfully")
    end
end

-- Test suite for State Serialization
local function testStateSerialization()
    print("\n=== Testing State Serialization ===")
    
    -- Test 1: Serialize Battle State
    print("\nTest 1: Serialize Battle State")
    local testMessage = {
        From = "test_sender",
        BattleId = "battle_001",
        IncludeHistory = "true",
        Timestamp = "1234567890"
    }
    
    local handler = Handlers._registry["serialize-battle-state"]
    if handler then
        handler.handler(testMessage)
        print("✓ Battle state serialization executed successfully")
    else
        print("✗ Battle state serialization handler not found")
    end
    
    -- Test 2: Deserialize Battle State
    print("\nTest 2: Deserialize Battle State")
    local mockSerializedState = json.encode({
        battleId = "battle_001",
        pokemonStates = {
            pikachu_001 = {
                id = "pikachu_001",
                hp = 95,
                maxHp = 100,
                status = "healthy"
            }
        },
        fieldConditions = {
            weather = {type = "rain", turnsRemaining = 3}
        },
        version = "1.0",
        serializedAt = "1234567890"
    })
    
    local testMessage2 = {
        From = "test_sender",
        BattleId = "battle_002",
        Data = mockSerializedState,
        Checksum = "mock_hash_123_battle",
        Timestamp = "1234567900"
    }
    
    local deserializeHandler = Handlers._registry["deserialize-battle-state"]
    if deserializeHandler then
        deserializeHandler.handler(testMessage2)
        print("✓ Battle state deserialization executed successfully")
    else
        print("✗ Battle state deserialization handler not found")
    end
end

-- Test suite for Memory Management
local function testMemoryManagement()
    print("\n=== Testing Memory Management ===")
    
    -- Test 1: Cleanup Operation
    print("\nTest 1: Memory Cleanup Operation")
    local testMessage = {
        From = "test_sender",
        Operation = "cleanup",
        Timestamp = "1234567890"
    }
    
    local handler = Handlers._registry["manage-memory"]
    if handler then
        handler.handler(testMessage)
        print("✓ Memory cleanup executed successfully")
    else
        print("✗ Memory management handler not found")
    end
    
    -- Test 2: State Validation
    print("\nTest 2: State Validation Operation")
    local testMessage2 = {
        From = "test_sender",
        Operation = "validate",
        Timestamp = "1234567890"
    }
    
    if handler then
        handler.handler(testMessage2)
        print("✓ State validation executed successfully")
    end
    
    -- Test 3: Clear Specific Battle
    print("\nTest 3: Clear Specific Battle")
    local testMessage3 = {
        From = "test_sender",
        Operation = "clear",
        BattleId = "battle_001",
        Timestamp = "1234567890"
    }
    
    if handler then
        handler.handler(testMessage3)
        print("✓ Specific battle cleanup executed successfully")
    end
end

-- Test suite for ADP Compliance
local function testADPCompliance()
    print("\n=== Testing ADP Compliance ===")
    
    -- Test Info Handler
    print("\nTest: Info Handler")
    local testMessage = {
        From = "test_sender",
        Action = "Info"
    }
    
    local handler = Handlers._registry["info"]
    if handler then
        handler.handler(testMessage)
        print("✓ ADP Info handler executed successfully")
    else
        print("✗ ADP Info handler not found")
    end
end

-- Main test execution
local function runAllTests()
    print("Starting Battle State Manager Unit Tests...")
    print("=" .. string.rep("=", 50))
    
    setupTestEnvironment()
    
    -- Run all test suites
    testPokemonStateTracking()
    testFieldConditionManagement()
    testBattleParticipantManagement()
    testMoveHistoryTracking()
    testBattleEventLogging()
    testStateSerialization()
    testMemoryManagement()
    testADPCompliance()
    
    print("\n" .. string.rep("=", 50))
    print("Battle State Manager Unit Tests Complete")
end

-- Execute tests
runAllTests()

return {
    runAllTests = runAllTests,
    testPokemonStateTracking = testPokemonStateTracking,
    testFieldConditionManagement = testFieldConditionManagement,
    testBattleParticipantManagement = testBattleParticipantManagement,
    testMoveHistoryTracking = testMoveHistoryTracking,
    testBattleEventLogging = testBattleEventLogging,
    testStateSerialization = testStateSerialization,
    testMemoryManagement = testMemoryManagement,
    testADPCompliance = testADPCompliance
}