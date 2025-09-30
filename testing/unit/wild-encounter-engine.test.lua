-- Unit tests for Wild Pokemon Encounter Engine
-- Tests encounter probabilities, species generation, and shiny calculations

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local TEST_PROCESS_PATH = "../../processes/wild-encounter-engine.lua"
local TEST_TIMEOUT = 5000

describe("Wild Pokemon Encounter Engine Unit Tests", function()
    local process
    
    before(function()
        -- Initialize test process
        process = aolite.spawnProcess({
            file = TEST_PROCESS_PATH,
            logLevel = 0
        })
    end)
    
    after(function()
        -- Cleanup
        process = nil
    end)
    
    describe("Encounter Rate Calculations", function()
        it("should calculate base encounter rate correctly", function()
            local result = process:eval([[
                local rate = calculateEncounterRate(BiomeType.PLAINS, {})
                return rate
            ]])
            
            assert.isNumber(result)
            assert.equal(0.10, result) -- Base 10% rate for Plains
        end)
        
        it("should apply area density modifiers", function()
            local result = process:eval([[
                local grassRate = calculateEncounterRate(BiomeType.GRASS, {})
                local tallGrassRate = calculateEncounterRate(BiomeType.TALL_GRASS, {})
                return { grass = grassRate, tallGrass = tallGrassRate }
            ]])
            
            assert.equal(0.12, result.grass) -- 1.2x modifier
            assert.equal(0.15, result.tallGrass) -- 1.5x modifier
        end)
        
        it("should block encounters when repel is active", function()
            local result = process:eval([[
                local rate = calculateEncounterRate(BiomeType.GRASS, { repelActive = true })
                return rate
            ]])
            
            assert.equal(0, result)
        end)
        
        it("should increase encounters with incense", function()
            local result = process:eval([[
                local rate = calculateEncounterRate(BiomeType.PLAINS, { encounterIncense = true })
                return rate
            ]])
            
            assert.equal(0.15, result) -- 1.5x modifier
        end)
    end)
    
    describe("Species Pool Determination", function()
        it("should select species from correct tier pool", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1", -- PLAINS
                WaveIndex = "10",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            assert.equal("SaveState", response.Action)
            assert.equal("true", response.Success)
            
            local data = json.decode(response.Data)
            assert.isTable(data.wildPokemon)
            assert.isNumber(data.wildPokemon.speciesId)
        end)
        
        it("should respect biome-specific species pools", function()
            -- Test different biomes return appropriate species
            local biomes = { "TOWN", "PLAINS", "GRASS", "FOREST", "WATER", "MOUNTAIN", "CAVE" }
            
            for _, biome in ipairs(biomes) do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "generate",
                    BiomeType = tostring(BiomeType[biome]),
                    WaveIndex = "5",
                    Data = json.encode({ rngSeed = math.random(1, 10000) })
                }
                
                local response = process:send(msg)
                assert.equal("true", response.Success, "Failed for biome: " .. biome)
                
                local data = json.decode(response.Data)
                assert.isNumber(data.wildPokemon.speciesId, "No species for biome: " .. biome)
            end
        end)
        
        it("should scale encounter tier with wave progression", function()
            -- Higher waves should have higher tier chances
            local lowWaveMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "5",
                EncounterType = "BOSS",
                Data = json.encode({ rngSeed = 999 })
            }
            
            local highWaveMsg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "100",
                EncounterType = "BOSS",
                Data = json.encode({ rngSeed = 999 })
            }
            
            local lowResponse = process:send(lowWaveMsg)
            local highResponse = process:send(highWaveMsg)
            
            local lowData = json.decode(lowResponse.Data)
            local highData = json.decode(highResponse.Data)
            
            -- Higher wave should generate higher level Pokemon
            assert.isTrue(highData.wildPokemon.level > lowData.wildPokemon.level)
        end)
    end)
    
    describe("Shiny Determination", function()
        it("should calculate base shiny rate correctly", function()
            local result = process:eval([[
                local rate = calculateShinyRate({})
                return rate
            ]])
            
            assert.isNumber(result)
            assert.isTrue(math.abs(result - 1/4096) < 0.0001) -- Base 1/4096
        end)
        
        it("should apply shiny charm modifier", function()
            local result = process:eval([[
                local rate = calculateShinyRate({ shinyCharm = true })
                return rate
            ]])
            
            assert.isTrue(math.abs(result - 3/4096) < 0.0001) -- 3x rate
        end)
        
        it("should force shiny when requested", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "10",
                ForceShiny = "true",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            assert.isTrue(data.wildPokemon.isShiny)
        end)
        
        it("should respect shiny-locked species", function()
            local result = process:eval([[
                local rng = createRNG(12345)
                -- Arceus (493) is shiny-locked
                local isShiny = determineIfShiny(rng, { shinyCharm = true }, 493)
                return isShiny
            ]])
            
            assert.isFalse(result)
        end)
    end)
    
    describe("Wild Pokemon Generation", function()
        it("should generate valid IVs", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "10",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            assert.equal(6, #data.wildPokemon.ivs)
            for _, iv in ipairs(data.wildPokemon.ivs) do
                assert.isTrue(iv >= 0 and iv <= 31)
            end
        end)
        
        it("should assign valid nature", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "10",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            local validNatures = {
                "Hardy", "Lonely", "Brave", "Adamant", "Naughty",
                "Bold", "Docile", "Relaxed", "Impish", "Lax",
                "Timid", "Hasty", "Serious", "Jolly", "Naive",
                "Modest", "Mild", "Quiet", "Bashful", "Rash",
                "Calm", "Gentle", "Sassy", "Careful", "Quirky"
            }
            
            local found = false
            for _, nature in ipairs(validNatures) do
                if data.wildPokemon.nature == nature then
                    found = true
                    break
                end
            end
            assert.isTrue(found, "Invalid nature: " .. tostring(data.wildPokemon.nature))
        end)
        
        it("should calculate correct level based on wave", function()
            local waves = {1, 10, 25, 50, 100}
            
            for _, wave in ipairs(waves) do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "generate",
                    BiomeType = "1",
                    WaveIndex = tostring(wave),
                    Data = json.encode({ rngSeed = 12345 })
                }
                
                local response = process:send(msg)
                local data = json.decode(response.Data)
                
                local expectedBase = math.floor(wave / 10) * 5 + 1
                assert.isTrue(data.wildPokemon.level >= expectedBase)
                assert.isTrue(data.wildPokemon.level <= expectedBase + 5)
            end
        end)
    end)
    
    describe("AI Behavior", function()
        it("should calculate AI decisions based on difficulty", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "ai-decision",
                WaveIndex = "5",
                Data = json.encode({
                    rngSeed = 12345,
                    wildPokemon = { moves = {{id = 1, power = 40}} },
                    battleState = { 
                        wildPokemon = { hp = 50, maxHp = 100 },
                        playerPokemon = { hp = 75, maxHp = 100 }
                    }
                })
            }
            
            local response = process:send(msg)
            assert.equal("true", response.Success)
            
            local aiDecision = json.decode(response.AIDecision)
            assert.isTable(aiDecision.action)
            assert.equal("EASY", aiDecision.difficultyTier)
        end)
        
        it("should adjust AI strategy based on HP", function()
            -- Test low HP scenario
            local lowHpMsg = {
                Action = "ProcessWildEncounter",
                Operation = "ai-decision",
                WaveIndex = "50",
                Data = json.encode({
                    rngSeed = 12345,
                    wildPokemon = { moves = {{id = 1, power = 40}} },
                    battleState = {
                        wildPokemon = { hp = 10, maxHp = 100 },
                        playerPokemon = { hp = 90, maxHp = 100 }
                    }
                })
            }
            
            local response = process:send(lowHpMsg)
            local aiDecision = json.decode(response.AIDecision)
            
            -- Low HP should increase switch weight
            assert.isTrue(aiDecision.decisionWeights.switch > 0.15)
        end)
    end)
    
    describe("Special Encounters", function()
        it("should handle legendary encounters", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "100",
                EncounterType = "LEGENDARY",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            assert.equal("LEGENDARY", data.encounterType)
            assert.isTable(data.specialData)
            assert.equal(3.0, data.specialData.captureResistance)
            assert.equal(3, data.specialData.guaranteedIVs)
        end)
        
        it("should handle boss encounters", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "50",
                EncounterType = "BOSS",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            assert.equal("BOSS", data.encounterType)
            assert.equal(2.0, data.specialData.hpMultiplier)
            assert.equal(2, data.specialData.segments) -- floor(50/30) + 1
        end)
        
        it("should handle roaming encounters", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "25",
                EncounterType = "ROAMING",
                Data = json.encode({ rngSeed = 12345 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            assert.equal("ROAMING", data.encounterType)
            assert.equal(0.5, data.specialData.fleeProbability)
        end)
    end)
    
    describe("Validation", function()
        it("should validate encounter conditions", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "validate",
                BiomeType = "1",
                WaveIndex = "50"
            }
            
            local response = process:send(msg)
            assert.equal("true", response.Success)
            assert.equal("true", response.Valid)
            assert.equal("true", response.BiomeValid)
            assert.equal("true", response.WaveValid)
        end)
        
        it("should reject invalid biomes", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "validate",
                BiomeType = "999",
                WaveIndex = "50"
            }
            
            local response = process:send(msg)
            assert.equal("true", response.Success)
            assert.equal("false", response.Valid)
            assert.equal("false", response.BiomeValid)
        end)
    end)
end)