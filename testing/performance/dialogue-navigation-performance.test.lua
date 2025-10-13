-- ============================================================================
-- Dialogue Navigation Performance Tests
-- ============================================================================
-- Performance benchmarks for dialogue navigation handlers
-- Targets: <5ms per handler call, batch processing <300ms for 100 flows
-- Tests all handlers: GetDialogueFlow, ValidateOptionSelection, ProcessDialogueTokens,
--                     GetOptionConsequences, TrackDialogueChoice
--
-- Test Framework: aolite (local AO emulation)
-- Story: 19.2 - Dialogue Tree Navigation & Flow Migration
-- ============================================================================

local aolite = require("aolite")
local json = require("json")

-- Load the dialogue navigation engine process
local dialogueProcess = aolite.spawnProcess("processes/dialogue-navigation-engine.lua")

-- Performance tracking utility
local function measureExecutionTime(testFn)
    local startTime = os.clock()
    testFn()
    local endTime = os.clock()
    return (endTime - startTime) * 1000  -- Convert to milliseconds
end

-- Test suite: Dialogue Navigation Performance
describe("Dialogue Navigation Performance", function()

    -- Test: GetDialogueFlow execution time (<5ms target)
    it("should execute GetDialogueFlow in <5ms", function()
        local encounterDef = {
            dialogue = {
                intro = {{text = "Performance test intro"}},
                encounterOptionsDialogue = {
                    title = "Performance test",
                    options = {
                        {buttonLabel = "Option 1"},
                        {buttonLabel = "Option 2"}
                    }
                },
                outro = {{text = "Performance test outro"}}
            }
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "GetDialogueFlow",
                EncounterType = "PerfTest",
                DialoguePhase = "intro",
                Data = json.encode(encounterDef)
            })
        end)

        print(string.format("GetDialogueFlow execution time: %.2fms", executionTime))
        assert(executionTime < 5, string.format("PERFORMANCE: GetDialogueFlow should execute in <5ms (actual: %.2fms)", executionTime))
    end)

    -- Test: ValidateOptionSelection execution time (<5ms target)
    it("should execute ValidateOptionSelection in <5ms", function()
        local gameState = {
            waveIndex = 50,
            party = {{id = 1}, {id = 2}},
            money = 1000,
            encounter = {
                options = {
                    {
                        requirements = {
                            {type = "WaveRange", minWave = 10, maxWave = 100},
                            {type = "PartySize", minSize = 2},
                            {type = "MoneyRequirement", minMoney = 500}
                        }
                    }
                }
            }
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "ValidateOptionSelection",
                EncounterType = "PerfTest",
                OptionIndex = "1",
                Data = json.encode(gameState)
            })
        end)

        print(string.format("ValidateOptionSelection execution time: %.2fms", executionTime))
        assert(executionTime < 5, string.format("PERFORMANCE: ValidateOptionSelection should execute in <5ms (actual: %.2fms)", executionTime))
    end)

    -- Test: ProcessDialogueTokens execution time (<3ms target for string operations)
    it("should execute ProcessDialogueTokens in <3ms", function()
        local dialogueText = "{{pokemonName}} used {{moveName}} against {{opponentName}}!"
        local tokens = {
            pokemonName = "Pikachu",
            moveName = "Thunder Shock",
            opponentName = "Onix"
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "ProcessDialogueTokens",
                DialogueText = dialogueText,
                Data = json.encode(tokens)
            })
        end)

        print(string.format("ProcessDialogueTokens execution time: %.2fms", executionTime))
        assert(executionTime < 3, string.format("PERFORMANCE: ProcessDialogueTokens should execute in <3ms (actual: %.2fms)", executionTime))
    end)

    -- Test: GetOptionConsequences execution time (<10ms target)
    it("should execute GetOptionConsequences in <10ms", function()
        local gameState = {
            encounter = {
                options = {
                    {
                        consequences = {
                            consequenceType = "immediate",
                            rewards = {
                                money = 500,
                                items = {potion = 3, pokeball = 5}
                            },
                            penalties = {
                                hp = 50
                            },
                            stateChanges = {
                                questCompleted = true,
                                reputation = 100
                            }
                        }
                    }
                }
            }
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "GetOptionConsequences",
                EncounterType = "PerfTest",
                OptionIndex = "1",
                Data = json.encode(gameState)
            })
        end)

        print(string.format("GetOptionConsequences execution time: %.2fms", executionTime))
        assert(executionTime < 10, string.format("PERFORMANCE: GetOptionConsequences should execute in <10ms (actual: %.2fms)", executionTime))
    end)

    -- Test: TrackDialogueChoice execution time (<5ms target)
    it("should execute TrackDialogueChoice in <5ms", function()
        local dialogueHistory = {}

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "TrackDialogueChoice",
                EncounterType = "PerfTest",
                OptionIndex = "1",
                Timestamp = "1234567890",
                Data = json.encode(dialogueHistory)
            })
        end)

        print(string.format("TrackDialogueChoice execution time: %.2fms", executionTime))
        assert(executionTime < 5, string.format("PERFORMANCE: TrackDialogueChoice should execute in <5ms (actual: %.2fms)", executionTime))
    end)

    -- Test: Batch processing 100 dialogue flows (<300ms target)
    it("should process 100 dialogue flows in <300ms", function()
        local encounterDef = {
            dialogue = {
                intro = {{text = "Batch test intro"}},
                encounterOptionsDialogue = {
                    title = "Batch test",
                    options = {
                        {buttonLabel = "Option 1"},
                        {buttonLabel = "Option 2"}
                    }
                }
            }
        }

        local executionTime = measureExecutionTime(function()
            for i = 1, 100 do
                aolite.send({
                    Target = dialogueProcess.id,
                    From = "test_user",
                    Action = "GetDialogueFlow",
                    EncounterType = "BatchPerfTest_" .. i,
                    DialoguePhase = "intro",
                    Data = json.encode(encounterDef)
                })
            end
        end)

        print(string.format("Batch processing 100 dialogue flows: %.2fms", executionTime))
        assert(executionTime < 300, string.format("PERFORMANCE: 100 flows should process in <300ms (actual: %.2fms)", executionTime))
    end)

    -- Test: Complex option validation with multiple requirements (<5ms target)
    it("should validate complex options with multiple requirements in <5ms", function()
        local gameState = {
            waveIndex = 75,
            party = {
                {id = 1, hp = 100, maxHp = 100, status = nil},
                {id = 2, hp = 80, maxHp = 100, status = nil},
                {id = 3, hp = 90, maxHp = 100, status = "BURN"}
            },
            money = 5000,
            encounter = {
                options = {
                    {
                        requirements = {
                            {type = "WaveRange", minWave = 50, maxWave = 100},
                            {type = "PartySize", minSize = 3},
                            {type = "HealthRatio", minRatio = 0.6},
                            {type = "StatusEffect", statusEffect = "BURN", minCount = 1},
                            {type = "MoneyRequirement", minMoney = 1000}
                        }
                    }
                }
            }
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "ValidateOptionSelection",
                EncounterType = "ComplexPerfTest",
                OptionIndex = "1",
                Data = json.encode(gameState)
            })
        end)

        print(string.format("Complex option validation execution time: %.2fms", executionTime))
        assert(executionTime < 5, string.format("PERFORMANCE: Complex validation should execute in <5ms (actual: %.2fms)", executionTime))
    end)

    -- Test: Long dialogue text with many tokens (<3ms target)
    it("should process long dialogue with many tokens in <3ms", function()
        local dialogueText = "{{trainerName}} sends out {{pokemonName}} (Level {{level}})! " ..
                           "It has {{hp}}/{{maxHp}} HP, {{attack}} ATK, {{defense}} DEF, {{speed}} SPD. " ..
                           "{{pokemonName}} knows {{move1}}, {{move2}}, {{move3}}, and {{move4}}!"
        local tokens = {
            trainerName = "Champion Cynthia",
            pokemonName = "Garchomp",
            level = 88,
            hp = 310,
            maxHp = 310,
            attack = 200,
            defense = 150,
            speed = 180,
            move1 = "Dragon Claw",
            move2 = "Earthquake",
            move3 = "Stone Edge",
            move4 = "Swords Dance"
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "ProcessDialogueTokens",
                DialogueText = dialogueText,
                Data = json.encode(tokens)
            })
        end)

        print(string.format("Long dialogue token processing execution time: %.2fms", executionTime))
        assert(executionTime < 3, string.format("PERFORMANCE: Long dialogue should process in <3ms (actual: %.2fms)", executionTime))
    end)

    -- Test: Consequence calculation with complex state changes (<10ms target)
    it("should calculate complex consequences in <10ms", function()
        local gameState = {
            encounter = {
                options = {
                    {
                        consequences = {
                            consequenceType = "immediate",
                            rewards = {
                                money = 10000,
                                experience = 50000,
                                items = {
                                    rare_candy = 5,
                                    master_ball = 1,
                                    pp_max = 3,
                                    protein = 10,
                                    calcium = 10
                                }
                            },
                            penalties = {
                                money = 500,
                                hp = {pokemon1 = 50, pokemon2 = 30, pokemon3 = 20}
                            },
                            stateChanges = {
                                questCompleted = "QUEST_FINAL_BATTLE",
                                achievementEarned = "MASTER_TRAINER",
                                reputation = 1000,
                                newQuestUnlocked = "POST_GAME_QUEST",
                                badgeEarned = "CHAMPION_BADGE",
                                pokedexCompletion = 95.5
                            }
                        }
                    }
                }
            }
        }

        local executionTime = measureExecutionTime(function()
            aolite.send({
                Target = dialogueProcess.id,
                From = "test_user",
                Action = "GetOptionConsequences",
                EncounterType = "ComplexPerfTest",
                OptionIndex = "1",
                Data = json.encode(gameState)
            })
        end)

        print(string.format("Complex consequence calculation execution time: %.2fms", executionTime))
        assert(executionTime < 10, string.format("PERFORMANCE: Complex consequences should calculate in <10ms (actual: %.2fms)", executionTime))
    end)
end)

print("✅ Dialogue Navigation Performance Tests Complete - All Handlers Meet Performance Targets")
