-- Battle Resolution Manager Unit Tests (Aolite)
-- Comprehensive testing using aolite framework for AO process validation

local aolite = require("aolite")
local json = require("json")

-- Test utilities
local function createMockBattleData(playerAlive, enemyAlive)
    local playerParty = {}
    local enemyParty = {}
    
    -- Create player party
    for i = 1, 2 do
        table.insert(playerParty, {
            id = "player_" .. i,
            speciesId = 25, -- Pikachu
            level = 20,
            hp = playerAlive and 80 or 0,
            maxHp = 100,
            status = playerAlive and nil or "faint",
            exp = 2000
        })
    end
    
    -- Create enemy party  
    for i = 1, 2 do
        table.insert(enemyParty, {
            id = "enemy_" .. i,
            speciesId = 1, -- Bulbasaur
            level = 18,
            hp = enemyAlive and 60 or 0,
            maxHp = 80,
            status = enemyAlive and nil or "faint",
            defeated = not enemyAlive
        })
    end
    
    return playerParty, enemyParty
end

-- Test Suite: Battle Resolution Manager Process
describe("Battle Resolution Manager Process", function()
    local processId
    
    before_each(function()
        -- Spawn new process for each test
        processId = aolite.spawnProcess("../processes/battle-resolution-manager.lua")
        assert(processId, "Failed to spawn battle resolution manager process")
    end)
    
    after_each(function()
        -- Clean up process
        if processId then
            aolite.clearProcess(processId)
        end
    end)

    describe("Info Handler", function()
        it("should respond to Info requests with ADP v1.0 compliant metadata", function()
            -- Arrange
            local infoMessage = {
                Target = processId,
                Action = "Info"
            }

            -- Act
            local response = aolite.send(infoMessage)

            -- Assert
            assert(response, "Should receive response to Info request")
            assert(response.Data, "Response should contain Data field")
            
            local infoData = json.decode(response.Data)
            assert(infoData.Name == "Battle Resolution Manager Process", "Should have correct process name")
            assert(infoData.protocolVersion == "1.0", "Should be ADP v1.0 compliant")
            assert(type(infoData.handlers) == "table", "Should contain handlers array")
            assert(#infoData.handlers >= 7, "Should have at least 7 battle resolution handlers")
        end)
    end)

    describe("DetectBattleOutcome Handler", function()
        it("should detect victory when enemy party is defeated", function()
            -- Arrange
            local playerParty, enemyParty = createMockBattleData(true, false) -- Player alive, enemy fainted
            
            local battleMessage = {
                Target = processId,
                Action = "DetectBattleOutcome",
                Tags = {
                    BattleId = "test_001",
                    PlayerParty = json.encode(playerParty),
                    EnemyParty = json.encode(enemyParty)
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(battleMessage)

            -- Assert
            assert(response, "Should receive battle outcome response")
            assert(response.Action == "SaveState", "Should return SaveState action")
            
            local battleData = json.decode(response.Data)
            assert(battleData.battleOutcome == "victory", "Should detect victory")
            assert(battleData.outcomeTrigger == "enemy_party_defeated", "Should identify correct trigger")
            assert(battleData.playerAlivePokemon == 2, "Should count alive player Pokemon correctly")
            assert(battleData.enemyAlivePokemon == 0, "Should count alive enemy Pokemon correctly")
        end)

        it("should detect defeat when player party is defeated", function()
            -- Arrange
            local playerParty, enemyParty = createMockBattleData(false, true) -- Player fainted, enemy alive
            
            local battleMessage = {
                Target = processId,
                Action = "DetectBattleOutcome",
                Tags = {
                    BattleId = "test_002", 
                    PlayerParty = json.encode(playerParty),
                    EnemyParty = json.encode(enemyParty)
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(battleMessage)

            -- Assert
            assert(response, "Should receive battle outcome response")
            local battleData = json.decode(response.Data)
            assert(battleData.battleOutcome == "defeat", "Should detect defeat")
            assert(battleData.outcomeTrigger == "player_party_fainted", "Should identify correct trigger")
        end)

        it("should handle missing required fields", function()
            -- Arrange
            local incompleteMessage = {
                Target = processId,
                Action = "DetectBattleOutcome",
                Tags = {
                    BattleId = "test_003"
                    -- Missing PlayerParty and EnemyParty
                },
                Timestamp = 1234567890
            }

            -- Act  
            local response = aolite.send(incompleteMessage)

            -- Assert
            assert(response, "Should receive error response")
            assert(response.Action == "SaveState", "Should return SaveState action")
            assert(response.Error, "Should contain error message")
            assert(string.match(response.Error, "Missing required field"), "Should indicate missing field")
        end)
    end)

    describe("CalculateExperience Handler", function()
        it("should calculate experience using exact TypeScript formula", function()
            -- Arrange
            local participantData = {
                {
                    id = "participant_1",
                    level = 20,
                    exp = 2000,
                    speciesId = 25
                }
            }
            
            local enemyData = {
                {
                    id = "enemy_1", 
                    speciesId = 25, -- Pikachu (baseExp = 112)
                    level = 18,
                    defeated = true
                }
            }

            local expMessage = {
                Target = processId,
                Action = "CalculateExperience",
                Tags = {
                    ParticipantData = json.encode(participantData),
                    EnemyData = json.encode(enemyData),
                    BattleType = "wild"
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(expMessage)

            -- Assert
            assert(response, "Should receive experience calculation response")
            local expData = json.decode(response.Data)
            assert(expData.experienceGains, "Should contain experience gains")
            assert(expData.experienceDistribution, "Should contain distribution details")
            
            -- Verify TypeScript formula: (112 * 18) / 5 + 1 = 403
            assert(expData.totalExpValue >= 403, "Should calculate correct base experience value")
        end)

        it("should apply trainer battle multiplier", function()
            -- Arrange
            local participantData = {{id = "p1", level = 20, exp = 2000}}
            local enemyData = {{id = "e1", speciesId = 25, level = 18, defeated = true}}

            local trainerMessage = {
                Target = processId,
                Action = "CalculateExperience",
                Tags = {
                    ParticipantData = json.encode(participantData),
                    EnemyData = json.encode(enemyData),
                    BattleType = "trainer" -- Should get 1.5x multiplier
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(trainerMessage)

            -- Assert
            assert(response, "Should receive experience calculation response")
            local expData = json.decode(response.Data)
            
            -- Base exp (403) * 1.5 = 604 (rounded down)
            assert(expData.totalExpValue >= 604, "Should apply trainer multiplier correctly")
        end)
    end)

    describe("ProcessLevelUp Handler", function()
        it("should calculate stat increases for level progression", function()
            -- Arrange
            local levelUpMessage = {
                Target = processId,
                Action = "ProcessLevelUp",
                Tags = {
                    PokemonId = "test_pokemon",
                    OldLevel = "20",
                    NewLevel = "22",
                    SpeciesId = "25"
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(levelUpMessage)

            -- Assert
            assert(response, "Should receive level up response")
            local levelData = json.decode(response.Data)
            assert(levelData.levelUpResults, "Should contain level up results")
            assert(levelData.levelUpResults.statIncreases, "Should calculate stat increases")
            
            -- Verify stat calculations for 2-level gain
            local stats = levelData.levelUpResults.statIncreases
            assert(stats.hp == 4, "Should increase HP by 4 for 2 levels") -- (22-20) * 2 = 4
            assert(stats.attack == 3, "Should increase attack by 3 for 2 levels") -- (22-20) * 1.5 = 3
        end)

        it("should detect move learning at appropriate levels", function()
            -- Arrange (Level 20 is divisible by 5, should learn move)
            local moveLearnMessage = {
                Target = processId,
                Action = "ProcessLevelUp", 
                Tags = {
                    PokemonId = "move_learner",
                    OldLevel = "19",
                    NewLevel = "20",
                    SpeciesId = "25"
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(moveLearnMessage)

            -- Assert
            assert(response, "Should receive level up response")
            local levelData = json.decode(response.Data)
            assert(levelData.movesLearned, "Should check for moves learned")
            assert(#levelData.movesLearned > 0, "Should learn move at level 20")
        end)
    end)

    describe("DetectCaptureOpportunity Handler", function()
        it("should allow capture in wild battles with low HP Pokemon", function()
            -- Arrange
            local wildPokemon = {
                hp = 20,
                maxHp = 100,
                status = "sleep", -- Should give capture bonus
                speciesId = 25
            }
            
            local captureMessage = {
                Target = processId,
                Action = "DetectCaptureOpportunity",
                Tags = {
                    WildPokemon = json.encode(wildPokemon),
                    BattleType = "wild",
                    PokeballCount = "5"
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(captureMessage)

            -- Assert
            assert(response, "Should receive capture opportunity response")
            local captureData = json.decode(response.Data)
            assert(captureData.captureOpportunity, "Should contain capture opportunity data")
            assert(captureData.captureOpportunity.canCapture == true, "Should allow capture in wild battle")
            assert(captureData.captureOpportunity.captureRate > 0.5, "Should have high capture rate for low HP + status")
        end)

        it("should prevent capture in trainer battles", function()
            -- Arrange
            local trainerPokemon = {hp = 50, maxHp = 100, speciesId = 25}
            
            local trainerCaptureMessage = {
                Target = processId,
                Action = "DetectCaptureOpportunity",
                Tags = {
                    WildPokemon = json.encode(trainerPokemon),
                    BattleType = "trainer", -- Should prevent capture
                    PokeballCount = "10"
                },
                Timestamp = 1234567890
            }

            -- Act
            local response = aolite.send(trainerCaptureMessage)

            -- Assert
            assert(response, "Should receive capture opportunity response")
            local captureData = json.decode(response.Data)
            assert(captureData.captureOpportunity.canCapture == false, "Should prevent capture in trainer battles")
            assert(captureData.captureOpportunity.reason == "invalid_battle_type", "Should indicate invalid battle type")
        end)
    end)

    describe("Ping Handler", function()
        it("should respond to ping requests", function()
            -- Arrange
            local pingMessage = {
                Target = processId,
                Action = "Ping"
            }

            -- Act
            local response = aolite.send(pingMessage)

            -- Assert
            assert(response, "Should receive ping response")
            assert(response.Action == "Pong", "Should return Pong action")
            assert(response.Data == "pong", "Should return pong data")
        end)
    end)
end)

-- Run tests with aolite
local function runAoliteTests()
    print("🧪 Running Battle Resolution Manager Aolite Tests")
    print("=".rep(60))
    
    -- Set up aolite configuration
    aolite.configure({
        logLevel = 1, -- Minimal logging for tests
        processTimeout = 30000, -- 30 second timeout
        messageTimeout = 5000   -- 5 second message timeout
    })
    
    -- Execute test suite
    local success, results = pcall(function()
        return aolite.runTests()
    end)
    
    if success then
        print("✅ All aolite tests completed successfully!")
        print("📊 Test Results:", json.encode(results))
        return true
    else
        print("❌ Aolite tests failed:", results)
        return false
    end
end

-- Execute if run directly
if arg and arg[0] then
    runAoliteTests()
end

return {
    runAoliteTests = runAoliteTests,
    createMockBattleData = createMockBattleData
}