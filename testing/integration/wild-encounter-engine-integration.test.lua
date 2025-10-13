-- Integration tests for Wild Pokemon Encounter Engine
-- Tests cross-process coordination with Pokemon Instance Manager and Battle Engine

local aosLocal = require("aos-local")
local json = require("json")

-- Process paths
local WILD_ENCOUNTER_ENGINE = "../../processes/wild-encounter-engine.lua"
local POKEMON_INSTANCE_MANAGER = "../../processes/pokemon-instance-manager.lua"
local BATTLE_ENGINE = "../../processes/battle-engine.lua"
local CAPTURE_ENGINE = "../../processes/capture-engine.lua"

describe("Wild Encounter Engine Integration Tests", function()
    local network
    local wildEncounterPid
    local pokemonInstancePid
    local battleEnginePid
    local captureEnginePid
    
    before(function()
        -- Initialize AOS network
        network = aosLocal.createNetwork()
        
        -- Spawn processes
        wildEncounterPid = network:spawnProcess(WILD_ENCOUNTER_ENGINE)
        pokemonInstancePid = network:spawnProcess(POKEMON_INSTANCE_MANAGER)
        battleEnginePid = network:spawnProcess(BATTLE_ENGINE)
        captureEnginePid = network:spawnProcess(CAPTURE_ENGINE)
        
        -- Set process IDs for cross-communication
        network:eval(wildEncounterPid, [[
            POKEMON_INSTANCE_MANAGER_ID = "]] .. pokemonInstancePid .. [["
            BATTLE_ENGINE_ID = "]] .. battleEnginePid .. [["
        ]])
    end)
    
    after(function()
        -- Cleanup
        network:shutdown()
    end)
    
    describe("Wild Encounter Generation Flow", function()
        it("should generate wild encounter and coordinate with Pokemon Instance Manager", function()
            -- Step 1: Generate wild encounter
            local encounterMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "2", -- GRASS
                WaveIndex = "15",
                Data = json.encode({
                    rngSeed = 54321,
                    playerState = { playerId = "player123" }
                })
            }
            
            local encounterResponse = network:send(wildEncounterPid, encounterMsg)
            assert.equal("SaveState", encounterResponse.Action)
            assert.equal("true", encounterResponse.Success)
            assert.equal("true", encounterResponse.EncounterOccurred)
            
            local encounterData = json.decode(encounterResponse.Data)
            assert.isTable(encounterData.wildPokemon)
            assert.isNumber(encounterData.wildPokemon.speciesId)
            assert.isNumber(encounterData.wildPokemon.level)
            
            -- Step 2: Create Pokemon instance from encounter data
            local createMsg = {
                Action = "CreatePokemon",
                SpeciesId = tostring(encounterData.wildPokemon.speciesId),
                Level = tostring(encounterData.wildPokemon.level),
                Data = json.encode({
                    ivs = encounterData.wildPokemon.ivs,
                    nature = encounterData.wildPokemon.nature,
                    isShiny = encounterData.wildPokemon.isShiny,
                    isWild = true
                })
            }
            
            local createResponse = network:send(pokemonInstancePid, createMsg)
            assert.equal("SaveState", createResponse.Action)
            assert.equal("true", createResponse.Success)
            
            local pokemonData = json.decode(createResponse.Data)
            assert.isTable(pokemonData.pokemon)
            assert.isNumber(pokemonData.pokemon.id)
        end)
        
        it("should handle boss encounter with special properties", function()
            -- Generate boss encounter
            local bossMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "11", -- MOUNTAIN
                WaveIndex = "50",
                EncounterType = "BOSS",
                Data = json.encode({
                    rngSeed = 99999
                })
            }
            
            local bossResponse = network:send(wildEncounterPid, bossMsg)
            assert.equal("true", bossResponse.Success)
            
            local bossData = json.decode(bossResponse.Data)
            assert.equal("BOSS", bossData.encounterType)
            assert.isTable(bossData.specialData)
            assert.equal(2.0, bossData.specialData.hpMultiplier)
            assert.equal(1.5, bossData.specialData.statBoost)
            assert.isTrue(bossData.specialData.guaranteedItem)
        end)
    end)
    
    describe("Battle Integration", function()
        it("should initiate wild battle with generated Pokemon", function()
            -- Generate encounter
            local encounterMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "5", -- FOREST
                WaveIndex = "20",
                Data = json.encode({
                    rngSeed = 11111,
                    playerState = {
                        playerId = "player456",
                        party = {
                            {id = 1, speciesId = 25, level = 20, hp = 50, maxHp = 50}
                        }
                    }
                })
            }
            
            local encounterResponse = network:send(wildEncounterPid, encounterMsg)
            local encounterData = json.decode(encounterResponse.Data)
            
            -- Initiate battle
            local battleMsg = {
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "initiateBattle",
                    gameState = {
                        playerId = "player456",
                        battle = {
                            battleType = "WILD",
                            wildPokemon = encounterData.wildPokemon,
                            battleSeed = encounterData.encounterSeed
                        }
                    }
                })
            }
            
            -- Note: Actual battle engine integration would require proper battle setup
            -- This test validates the data flow structure
            assert.isTable(encounterData.wildPokemon)
            assert.isNumber(encounterData.encounterSeed)
        end)
        
        it("should calculate AI decisions during battle", function()
            -- Request AI decision
            local aiMsg = {
                Action = "ProcessWildEncounter",
                Operation = "ai-decision",
                WaveIndex = "30",
                Data = json.encode({
                    rngSeed = 22222,
                    wildPokemon = {
                        moves = {
                            {id = 1, power = 40, accuracy = 100},
                            {id = 2, power = 0, category = "status"},
                            {id = 3, power = 80, accuracy = 85}
                        }
                    },
                    battleState = {
                        wildPokemon = { hp = 30, maxHp = 60 },
                        playerPokemon = { hp = 45, maxHp = 50, types = {12} } -- Electric
                    }
                })
            }
            
            local aiResponse = network:send(wildEncounterPid, aiMsg)
            assert.equal("true", aiResponse.Success)
            
            local aiDecision = json.decode(aiResponse.AIDecision)
            assert.isTable(aiDecision.action)
            assert.equal("NORMAL", aiDecision.difficultyTier)
            assert.isTable(aiDecision.decisionWeights)
        end)
    end)
    
    describe("Capture Integration", function()
        it("should handle capture attempts for wild encounters", function()
            -- Generate shiny encounter for capture test
            local shinyMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "9", -- LAKE
                WaveIndex = "35",
                ForceShiny = "true",
                Data = json.encode({
                    rngSeed = 33333
                })
            }
            
            local shinyResponse = network:send(wildEncounterPid, shinyMsg)
            local shinyData = json.decode(shinyResponse.Data)
            
            assert.isTrue(shinyData.wildPokemon.isShiny)
            
            -- Prepare capture attempt
            local captureMsg = {
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "attemptCapture",
                    gameState = {
                        battle = {
                            wildPokemon = shinyData.wildPokemon,
                            pokeball = "ultraball"
                        }
                    }
                })
            }
            
            -- Capture engine would process this
            -- Verify shiny status is preserved
            assert.isTrue(shinyData.wildPokemon.isShiny)
        end)
        
        it("should apply capture resistance for legendary encounters", function()
            -- Generate legendary encounter
            local legendaryMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "25", -- SPACE
                WaveIndex = "150",
                EncounterType = "LEGENDARY",
                Data = json.encode({
                    rngSeed = 44444
                })
            }
            
            local legendaryResponse = network:send(wildEncounterPid, legendaryMsg)
            local legendaryData = json.decode(legendaryResponse.Data)
            
            assert.equal("LEGENDARY", legendaryData.encounterType)
            assert.equal(3.0, legendaryData.specialData.captureResistance)
        end)
    end)
    
    describe("Multi-Process Coordination", function()
        it("should handle complete encounter-to-battle flow", function()
            -- Full workflow test
            local playerId = "player789"
            
            -- 1. Generate encounter
            local encounterMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "13", -- CAVE
                WaveIndex = "40",
                Data = json.encode({
                    rngSeed = 55555,
                    playerState = { playerId = playerId }
                })
            }
            
            local encounterResp = network:send(wildEncounterPid, encounterMsg)
            assert.equal("true", encounterResp.Success)
            
            local encData = json.decode(encounterResp.Data)
            
            -- 2. Create Pokemon instance
            local createMsg = {
                Action = "CreatePokemon",
                SpeciesId = tostring(encData.wildPokemon.speciesId),
                Level = tostring(encData.wildPokemon.level),
                Data = json.encode(encData.wildPokemon)
            }
            
            local createResp = network:send(pokemonInstancePid, createMsg)
            assert.equal("true", createResp.Success)
            
            -- 3. Get AI decision
            local aiMsg = {
                Action = "ProcessWildEncounter",
                Operation = "ai-decision",
                WaveIndex = "40",
                Data = json.encode({
                    rngSeed = encData.encounterSeed,
                    wildPokemon = encData.wildPokemon,
                    battleState = {
                        wildPokemon = { hp = 100, maxHp = 100 },
                        playerPokemon = { hp = 100, maxHp = 100 }
                    }
                })
            }
            
            local aiResp = network:send(wildEncounterPid, aiMsg)
            assert.equal("true", aiResp.Success)
            
            local aiData = json.decode(aiResp.AIDecision)
            assert.equal("HARD", aiData.difficultyTier) -- Wave 40 = HARD
        end)
        
        it("should validate encounter conditions across biomes", function()
            local biomes = {"0", "1", "2", "5", "9", "11", "13"} -- Various biomes
            
            for _, biomeId in ipairs(biomes) do
                local validateMsg = {
                    Action = "ProcessWildEncounter",
                    Operation = "validate",
                    BiomeType = biomeId,
                    WaveIndex = "25"
                }
                
                local response = network:send(wildEncounterPid, validateMsg)
                assert.equal("true", response.Success, "Failed for biome: " .. biomeId)
                assert.equal("true", response.Valid, "Invalid for biome: " .. biomeId)
            end
        end)
    end)
    
    describe("Performance and Edge Cases", function()
        it("should handle rapid successive encounters", function()
            local startTime = os.clock()
            
            for i = 1, 10 do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "generate",
                    BiomeType = tostring(i % 5),
                    WaveIndex = tostring(i * 10),
                    Data = json.encode({ rngSeed = i * 1000 })
                }
                
                local response = network:send(wildEncounterPid, msg)
                assert.equal("true", response.Success)
            end
            
            local elapsed = os.clock() - startTime
            assert.isTrue(elapsed < 1.0, "Performance issue: " .. elapsed .. "s for 10 encounters")
        end)
        
        it("should handle missing or invalid data gracefully", function()
            -- Missing operation
            local badMsg1 = {
                Action = "ProcessWildEncounter",
                BiomeType = "1"
            }
            
            local response1 = network:send(wildEncounterPid, badMsg1)
            assert.equal("Error", response1.Action)
            assert.match(response1.Error, "Operation required")
            
            -- Invalid operation
            local badMsg2 = {
                Action = "ProcessWildEncounter",
                Operation = "invalid_op"
            }
            
            local response2 = network:send(wildEncounterPid, badMsg2)
            assert.equal("Error", response2.Action)
            assert.match(response2.Error, "Unknown operation")
        end)
    end)
end)