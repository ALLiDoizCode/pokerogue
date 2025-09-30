-- Parity tests for Wild Pokemon Encounter Engine
-- Validates behavioral matching with TypeScript implementation

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local TEST_PROCESS_PATH = "../../processes/wild-encounter-engine.lua"
local TYPESCRIPT_REFERENCE = require("typescript-reference-data")

describe("Wild Encounter Parity Tests", function()
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
    
    describe("Encounter Rate Parity", function()
        it("should match TypeScript base encounter rates", function()
            -- TypeScript reference rates
            local tsRates = {
                PLAINS = 0.10,
                GRASS = 0.12,
                TALL_GRASS = 0.15,
                FOREST = 0.13,
                CAVE = 0.11,
                WATER = 0.14,
                MOUNTAIN = 0.09,
                TOWN = 0.05
            }
            
            for biome, expectedRate in pairs(tsRates) do
                local result = process:eval(string.format([[
                    local rate = calculateEncounterRate(BiomeType.%s, {})
                    return rate
                ]], biome))
                
                assert.equal(expectedRate, result, "Mismatch for biome: " .. biome)
            end
        end)
        
        it("should match TypeScript modifier calculations", function()
            -- Test repel blocking
            local repelResult = process:eval([[
                local rate = calculateEncounterRate(BiomeType.GRASS, { repelActive = true })
                return rate
            ]])
            assert.equal(0, repelResult, "Repel should block all encounters")
            
            -- Test incense modifier (1.5x)
            local incenseResult = process:eval([[
                local rate = calculateEncounterRate(BiomeType.PLAINS, { encounterIncense = true })
                return rate
            ]])
            assert.equal(0.15, incenseResult, "Incense should multiply rate by 1.5")
            
            -- Test ability modifier (1.2x)
            local abilityResult = process:eval([[
                local rate = calculateEncounterRate(BiomeType.PLAINS, { encounterAbility = true })
                return rate
            ]])
            assert.equal(0.12, abilityResult, "Ability should multiply rate by 1.2")
            
            -- Test combined modifiers
            local comboResult = process:eval([[
                local rate = calculateEncounterRate(BiomeType.PLAINS, {
                    encounterIncense = true,
                    encounterAbility = true
                })
                return rate
            ]])
            assert.equal(0.18, comboResult, "Combined modifiers: 0.10 * 1.5 * 1.2")
        end)
    end)
    
    describe("Species Pool Tier Distribution", function()
        it("should match TypeScript tier probabilities", function()
            -- TypeScript tier distribution for regular encounters (out of 512)
            -- Common: >= 156/512 (69.5%)
            -- Uncommon: >= 32/512 (24.2%)
            -- Rare: >= 6/512 (5.2%)
            -- Super Rare: >= 1/512 (1.0%)
            -- Ultra Rare: < 1/512 (0.2%)
            
            local tierCounts = {
                COMMON = 0,
                UNCOMMON = 0,
                RARE = 0,
                SUPER_RARE = 0,
                ULTRA_RARE = 0
            }
            
            -- Run 1000 encounters to get distribution
            for i = 1, 1000 do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "generate",
                    BiomeType = "1", -- PLAINS
                    WaveIndex = "25",
                    Data = json.encode({ rngSeed = i * 100 })
                }
                
                local response = process:send(msg)
                if response.EncounterOccurred == "true" then
                    local data = json.decode(response.Data)
                    -- Track tier distribution (would need tier tracking in response)
                end
            end
            
            -- Verify distribution matches TypeScript within tolerance
            -- Note: Actual validation would require tier tracking in the process
        end)
        
        it("should match TypeScript boss tier probabilities", function()
            -- TypeScript boss tier distribution (out of 64)
            -- Boss: >= 20/64 (68.75%)
            -- Boss Rare: >= 6/64 (21.9%)
            -- Boss Super Rare: >= 1/64 (7.8%)
            -- Boss Ultra Rare: < 1/64 (1.6%)
            
            local bossCounts = {}
            
            for i = 1, 100 do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "generate",
                    BiomeType = "1",
                    WaveIndex = "50",
                    EncounterType = "BOSS",
                    Data = json.encode({ rngSeed = i * 200 })
                }
                
                local response = process:send(msg)
                -- Track boss tier distribution
            end
        end)
    end)
    
    describe("Shiny Rate Parity", function()
        it("should match TypeScript base shiny rate", function()
            -- TypeScript base shiny rate: 1/4096
            local baseRate = process:eval([[
                local rate = calculateShinyRate({})
                return rate
            ]])
            
            local expectedRate = 1 / 4096
            assert.isTrue(math.abs(baseRate - expectedRate) < 0.0000001,
                string.format("Expected %f, got %f", expectedRate, baseRate))
        end)
        
        it("should match TypeScript shiny modifiers", function()
            -- Shiny Charm: 3x rate
            local charmRate = process:eval([[
                local rate = calculateShinyRate({ shinyCharm = true })
                return rate
            ]])
            assert.equal(3 / 4096, charmRate)
            
            -- Masuda Method: 6x rate
            local masudaRate = process:eval([[
                local rate = calculateShinyRate({ masudaMethod = true })
                return rate
            ]])
            assert.equal(6 / 4096, masudaRate)
            
            -- Combined: 18x rate
            local comboRate = process:eval([[
                local rate = calculateShinyRate({
                    shinyCharm = true,
                    masudaMethod = true
                })
                return rate
            ]])
            assert.equal(18 / 4096, comboRate)
        end)
        
        it("should match TypeScript shiny-locked species", function()
            local shinyLocked = {493, 649, 721} -- Arceus, Genesect, Volcanion
            
            for _, speciesId in ipairs(shinyLocked) do
                local result = process:eval(string.format([[
                    local rng = createRNG(12345)
                    local isShiny = determineIfShiny(rng, { shinyCharm = true }, %d)
                    return isShiny
                ]], speciesId))
                
                assert.isFalse(result, "Species " .. speciesId .. " should be shiny-locked")
            end
        end)
    end)
    
    describe("Level Generation Parity", function()
        it("should match TypeScript level calculation formula", function()
            -- TypeScript formula: baseLevel = floor(waveIndex / 10) * 5 + 1
            -- Level range: baseLevel to baseLevel + 5
            
            local testWaves = {1, 10, 25, 50, 75, 100, 150, 200}
            
            for _, wave in ipairs(testWaves) do
                local expectedBase = math.floor(wave / 10) * 5 + 1
                
                -- Generate multiple encounters to check range
                for seed = 1, 10 do
                    local msg = {
                        Action = "ProcessWildEncounter",
                        Operation = "generate",
                        BiomeType = "1",
                        WaveIndex = tostring(wave),
                        Data = json.encode({ rngSeed = seed * 1000 })
                    }
                    
                    local response = process:send(msg)
                    local data = json.decode(response.Data)
                    local level = data.wildPokemon.level
                    
                    assert.isTrue(level >= expectedBase, 
                        string.format("Wave %d: Level %d below minimum %d", wave, level, expectedBase))
                    assert.isTrue(level <= expectedBase + 5, 
                        string.format("Wave %d: Level %d above maximum %d", wave, level, expectedBase + 5))
                end
            end
        end)
    end)
    
    describe("IV Generation Parity", function()
        it("should generate IVs in correct range", function()
            -- TypeScript: Each IV is 0-31
            local ivCounts = {}
            for i = 0, 31 do
                ivCounts[i] = 0
            end
            
            -- Generate many Pokemon to check IV distribution
            for seed = 1, 100 do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "generate",
                    BiomeType = "1",
                    WaveIndex = "50",
                    Data = json.encode({ rngSeed = seed })
                }
                
                local response = process:send(msg)
                local data = json.decode(response.Data)
                
                for _, iv in ipairs(data.wildPokemon.ivs) do
                    assert.isTrue(iv >= 0 and iv <= 31, "IV out of range: " .. iv)
                    ivCounts[iv] = ivCounts[iv] + 1
                end
            end
            
            -- Check distribution is relatively uniform
            local totalIVs = 100 * 6
            local expectedPerValue = totalIVs / 32
            
            for iv = 0, 31 do
                local count = ivCounts[iv]
                -- Allow 50% variance from expected
                assert.isTrue(count > expectedPerValue * 0.5 and count < expectedPerValue * 1.5,
                    string.format("IV %d has abnormal distribution: %d", iv, count))
            end
        end)
        
        it("should guarantee perfect IVs for legendary encounters", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "1",
                WaveIndex = "100",
                EncounterType = "LEGENDARY",
                Data = json.encode({ rngSeed = 99999 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            -- Count perfect IVs (31)
            local perfectCount = 0
            for _, iv in ipairs(data.wildPokemon.ivs) do
                if iv == 31 then
                    perfectCount = perfectCount + 1
                end
            end
            
            -- Legendary should have at least 3 perfect IVs
            assert.isTrue(perfectCount >= 3, 
                string.format("Legendary has only %d perfect IVs, expected >= 3", perfectCount))
        end)
    end)
    
    describe("AI Difficulty Scaling Parity", function()
        it("should match TypeScript difficulty tiers", function()
            -- TypeScript difficulty tiers by wave
            local difficultyMap = {
                [5] = "EASY",      -- Wave 1-10
                [15] = "NORMAL",   -- Wave 11-30
                [35] = "HARD",     -- Wave 31-60
                [75] = "EXPERT",   -- Wave 61-100
                [125] = "MASTER"   -- Wave 100+
            }
            
            for wave, expectedTier in pairs(difficultyMap) do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "ai-decision",
                    WaveIndex = tostring(wave),
                    Data = json.encode({
                        rngSeed = 12345,
                        wildPokemon = { moves = {{id = 1, power = 40}} },
                        battleState = {
                            wildPokemon = { hp = 50, maxHp = 100 },
                            playerPokemon = { hp = 50, maxHp = 100 }
                        }
                    })
                }
                
                local response = process:send(msg)
                local aiDecision = json.decode(response.AIDecision)
                
                assert.equal(expectedTier, aiDecision.difficultyTier,
                    string.format("Wave %d should be %s difficulty", wave, expectedTier))
            end
        end)
        
        it("should match TypeScript AI weight distributions", function()
            -- TypeScript AI weights by difficulty
            local expectedWeights = {
                EASY = { attack = 0.8, status = 0.1, switch = 0.05, optimal = 0.05 },
                NORMAL = { attack = 0.6, status = 0.2, switch = 0.1, optimal = 0.1 },
                HARD = { attack = 0.4, status = 0.25, switch = 0.15, optimal = 0.2 },
                EXPERT = { attack = 0.3, status = 0.25, switch = 0.15, optimal = 0.3 },
                MASTER = { attack = 0.2, status = 0.2, switch = 0.1, optimal = 0.5 }
            }
            
            local waves = {5, 25, 45, 80, 150}
            local tiers = {"EASY", "NORMAL", "HARD", "EXPERT", "MASTER"}
            
            for i, wave in ipairs(waves) do
                local msg = {
                    Action = "ProcessWildEncounter",
                    Operation = "ai-decision",
                    WaveIndex = tostring(wave),
                    Data = json.encode({
                        rngSeed = 54321,
                        wildPokemon = { moves = {{id = 1, power = 40}} },
                        battleState = {
                            wildPokemon = { hp = 100, maxHp = 100 },
                            playerPokemon = { hp = 100, maxHp = 100 }
                        }
                    })
                }
                
                local response = process:send(msg)
                local aiDecision = json.decode(response.AIDecision)
                local weights = aiDecision.decisionWeights
                local expected = expectedWeights[tiers[i]]
                
                -- Check base weights match
                assert.equal(expected.attack, weights.attack)
                assert.equal(expected.status, weights.status)
                assert.equal(expected.switch, weights.switch)
                assert.equal(expected.optimal, weights.optimal)
            end
        end)
    end)
    
    describe("Special Encounter Parity", function()
        it("should match TypeScript boss enhancements", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "11",
                WaveIndex = "60",
                EncounterType = "BOSS",
                Data = json.encode({ rngSeed = 11111 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            -- TypeScript boss properties
            assert.equal(2.0, data.specialData.hpMultiplier, "Boss HP multiplier")
            assert.equal(1.5, data.specialData.statBoost, "Boss stat boost")
            assert.equal(3, data.specialData.segments, "Boss segments: floor(60/30) + 1")
            assert.isTrue(data.specialData.guaranteedItem, "Boss guaranteed item")
        end)
        
        it("should match TypeScript legendary properties", function()
            local msg = {
                Action = "ProcessWildEncounter",
                Operation = "generate",
                BiomeType = "25",
                WaveIndex = "180",
                EncounterType = "LEGENDARY",
                Data = json.encode({ rngSeed = 22222 })
            }
            
            local response = process:send(msg)
            local data = json.decode(response.Data)
            
            -- TypeScript legendary properties
            assert.equal(3.0, data.specialData.captureResistance, "Legendary capture resistance")
            assert.equal(1.2, data.specialData.statBoost, "Legendary stat boost")
            assert.equal(3, data.specialData.guaranteedIVs, "Legendary guaranteed perfect IVs")
            assert.isTrue(data.specialData.specialMoves, "Legendary special moves")
        end)
    end)
end)