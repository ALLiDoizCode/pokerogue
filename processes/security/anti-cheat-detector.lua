-- Anti-Cheat Detection System
-- Advanced pattern recognition for identifying manipulation attempts and cheating behaviors
-- ADP v1.0 Compliant Process

-- Mathematical precision utilities for statistical analysis
local function calculateMean(values)
    if #values == 0 then return 0 end
    local sum = 0
    for _, value in ipairs(values) do
        sum = sum + value
    end
    return sum / #values
end

local function calculateStandardDeviation(values, mean)
    if #values <= 1 then return 0 end
    local variance = 0
    for _, value in ipairs(values) do
        variance = variance + (value - mean) ^ 2
    end
    variance = variance / (#values - 1)
    return math.sqrt(variance)
end

local function calculateZScore(value, mean, stdDev)
    if stdDev == 0 then return 0 end
    return (value - mean) / stdDev
end

-- Pokemon stat validation and cheat detection
local function detectStatManipulation(pokemon, previousPokemon)
    local violations = {}
    
    if not pokemon or not previousPokemon then
        return violations
    end
    
    -- Check for impossible IV changes (IVs should never change)
    if pokemon.ivs and previousPokemon.ivs then
        local ivStats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
        for _, stat in ipairs(ivStats) do
            if pokemon.ivs[stat] and previousPokemon.ivs[stat] then
                if pokemon.ivs[stat] ~= previousPokemon.ivs[stat] then
                    table.insert(violations, {
                        type = "IV_MANIPULATION",
                        severity = "HIGH",
                        details = "IV " .. stat .. " changed from " .. previousPokemon.ivs[stat] .. " to " .. pokemon.ivs[stat],
                        evidence = {
                            stat = stat,
                            oldValue = previousPokemon.ivs[stat],
                            newValue = pokemon.ivs[stat]
                        }
                    })
                end
            end
        end
    end
    
    -- Check for impossible level decreases
    if pokemon.level and previousPokemon.level then
        if pokemon.level < previousPokemon.level then
            table.insert(violations, {
                type = "LEVEL_MANIPULATION",
                severity = "HIGH",
                details = "Pokemon level decreased from " .. previousPokemon.level .. " to " .. pokemon.level,
                evidence = {
                    oldLevel = previousPokemon.level,
                    newLevel = pokemon.level
                }
            })
        end
        
        -- Check for impossible level jumps (more than 5 levels at once without rare candy)
        local levelDiff = pokemon.level - previousPokemon.level
        if levelDiff > 5 then
            table.insert(violations, {
                type = "EXCESSIVE_LEVEL_GAIN",
                severity = "MEDIUM",
                details = "Pokemon gained " .. levelDiff .. " levels in single operation",
                evidence = {
                    levelGain = levelDiff,
                    oldLevel = previousPokemon.level,
                    newLevel = pokemon.level
                }
            })
        end
    end
    
    -- Check for HP manipulation (HP should never exceed maxHP)
    if pokemon.hp and pokemon.maxHp then
        if pokemon.hp > pokemon.maxHp then
            table.insert(violations, {
                type = "HP_MANIPULATION",
                severity = "HIGH",
                details = "Pokemon HP (" .. pokemon.hp .. ") exceeds maxHP (" .. pokemon.maxHp .. ")",
                evidence = {
                    currentHp = pokemon.hp,
                    maxHp = pokemon.maxHp
                }
            })
        end
    end
    
    return violations
end

-- Move usage validation and cheat detection
local function detectMoveManipulation(pokemon, moveUsed, availableMoves)
    local violations = {}
    
    if not pokemon or not moveUsed then
        return violations
    end
    
    -- Check if Pokemon can actually learn the move
    local canLearnMove = false
    if pokemon.moves then
        for _, move in ipairs(pokemon.moves) do
            if move.id == moveUsed.id or move.name == moveUsed.name then
                canLearnMove = true
                
                -- Check PP manipulation
                if move.pp and moveUsed.pp then
                    if moveUsed.pp > move.maxPp then
                        table.insert(violations, {
                            type = "PP_MANIPULATION",
                            severity = "MEDIUM",
                            details = "Move " .. (move.name or move.id) .. " has PP exceeding maximum",
                            evidence = {
                                moveName = move.name or move.id,
                                currentPp = moveUsed.pp,
                                maxPp = move.maxPp
                            }
                        })
                    end
                end
                break
            end
        end
    end
    
    if not canLearnMove then
        table.insert(violations, {
            type = "INVALID_MOVE_USAGE",
            severity = "HIGH",
            details = "Pokemon attempted to use move it cannot learn: " .. (moveUsed.name or moveUsed.id),
            evidence = {
                pokemonSpecies = pokemon.species,
                moveUsed = moveUsed.name or moveUsed.id,
                knownMoves = pokemon.moves
            }
        })
    end
    
    return violations
end

-- Resource manipulation detection
local function detectResourceManipulation(inventory, previousInventory)
    local violations = {}
    
    if not inventory or not previousInventory then
        return violations
    end
    
    -- Check for impossible money gains
    if inventory.money and previousInventory.money then
        local moneyGain = inventory.money - previousInventory.money
        if moneyGain > 100000 then -- Arbitrary threshold for large money gains
            table.insert(violations, {
                type = "EXCESSIVE_MONEY_GAIN",
                severity = "MEDIUM",
                details = "Gained " .. moneyGain .. " money in single operation",
                evidence = {
                    moneyGain = moneyGain,
                    oldMoney = previousInventory.money,
                    newMoney = inventory.money
                }
            })
        end
        
        -- Check for negative money (should be impossible)
        if inventory.money < 0 then
            table.insert(violations, {
                type = "NEGATIVE_MONEY",
                severity = "HIGH",
                details = "Player has negative money: " .. inventory.money,
                evidence = {
                    money = inventory.money
                }
            })
        end
    end
    
    -- Check for impossible item gains
    if inventory.items and previousInventory.items then
        for itemId, quantity in pairs(inventory.items) do
            local previousQuantity = previousInventory.items[itemId] or 0
            local itemGain = quantity - previousQuantity
            
            if itemGain > 99 then -- Arbitrary threshold for large item gains
                table.insert(violations, {
                    type = "EXCESSIVE_ITEM_GAIN",
                    severity = "MEDIUM",
                    details = "Gained " .. itemGain .. " of item " .. itemId .. " in single operation",
                    evidence = {
                        itemId = itemId,
                        itemGain = itemGain,
                        oldQuantity = previousQuantity,
                        newQuantity = quantity
                    }
                })
            end
        end
    end
    
    return violations
end

-- Battle outcome validation
local function detectBattleOutcomeManipulation(battleResult, playerPokemon, enemyPokemon)
    local violations = {}
    
    if not battleResult then
        return violations
    end
    
    -- Check for impossible damage values
    if battleResult.damage and battleResult.damage > 9999 then
        table.insert(violations, {
            type = "IMPOSSIBLE_DAMAGE",
            severity = "HIGH",
            details = "Battle damage exceeded possible maximum: " .. battleResult.damage,
            evidence = {
                damage = battleResult.damage,
                attackerLevel = playerPokemon and playerPokemon.level,
                defenderLevel = enemyPokemon and enemyPokemon.level
            }
        })
    end
    
    -- Check for impossible critical hit rates
    if battleResult.criticalHits and battleResult.totalHits then
        local critRate = battleResult.criticalHits / battleResult.totalHits
        if critRate > 0.5 and battleResult.totalHits > 10 then -- 50% crit rate over 10 hits is suspicious
            table.insert(violations, {
                type = "SUSPICIOUS_CRITICAL_RATE",
                severity = "MEDIUM",
                details = "Abnormally high critical hit rate: " .. string.format("%.2f", critRate * 100) .. "%",
                evidence = {
                    criticalHits = battleResult.criticalHits,
                    totalHits = battleResult.totalHits,
                    critRate = critRate
                }
            })
        end
    end
    
    return violations
end

-- Progression speed analysis
local function detectProgressionSpeedManipulation(progression, previousProgression, timeDelta)
    local violations = {}
    
    if not progression or not previousProgression or not timeDelta then
        return violations
    end
    
    -- Check for impossible experience gains
    if progression.exp and previousProgression.exp then
        local expGain = progression.exp - previousProgression.exp
        local expPerSecond = timeDelta > 0 and expGain / timeDelta or 0
        
        -- Maximum reasonable exp gain is about 1000 per second
        if expPerSecond > 1000 then
            table.insert(violations, {
                type = "EXCESSIVE_EXP_RATE",
                severity = "MEDIUM",
                details = "Experience gained too quickly: " .. string.format("%.2f", expPerSecond) .. " exp/second",
                evidence = {
                    expGain = expGain,
                    timeDelta = timeDelta,
                    expPerSecond = expPerSecond
                }
            })
        end
    end
    
    -- Check for badge manipulation
    if progression.badges and previousProgression.badges then
        local badgeGain = #progression.badges - #previousProgression.badges
        if badgeGain > 1 and timeDelta < 60 then -- More than 1 badge in under a minute
            table.insert(violations, {
                type = "RAPID_BADGE_GAIN",
                severity = "HIGH",
                details = "Gained " .. badgeGain .. " badges in " .. timeDelta .. " seconds",
                evidence = {
                    badgeGain = badgeGain,
                    timeDelta = timeDelta,
                    newBadges = progression.badges,
                    oldBadges = previousProgression.badges
                }
            })
        end
    end
    
    return violations
end

-- Pattern recognition for common cheat signatures
local function detectCheatPatterns(gameState, previousGameState, playerHistory)
    local violations = {}
    
    -- Perfect IV pattern detection
    if gameState.party then
        for i, pokemon in ipairs(gameState.party) do
            if pokemon and pokemon.ivs then
                local perfectIVs = 0
                local ivStats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
                for _, stat in ipairs(ivStats) do
                    if pokemon.ivs[stat] == 31 then
                        perfectIVs = perfectIVs + 1
                    end
                end
                
                -- Having more than 3 Pokemon with perfect IVs is suspicious
                if perfectIVs == 6 then
                    table.insert(violations, {
                        type = "PERFECT_IV_PATTERN",
                        severity = "MEDIUM",
                        details = "Pokemon " .. i .. " has perfect IVs in all stats",
                        evidence = {
                            pokemonIndex = i,
                            ivs = pokemon.ivs,
                            perfectStats = perfectIVs
                        }
                    })
                end
            end
        end
    end
    
    -- Shiny rate manipulation
    if playerHistory and playerHistory.shinyCaught then
        local totalCaught = playerHistory.totalCaught or 1
        local shinyRate = playerHistory.shinyCaught / totalCaught
        if shinyRate > 0.01 and totalCaught > 100 then -- More than 1% shiny rate over 100 catches
            table.insert(violations, {
                type = "SUSPICIOUS_SHINY_RATE",
                severity = "MEDIUM",
                details = "Abnormally high shiny encounter rate: " .. string.format("%.2f", shinyRate * 100) .. "%",
                evidence = {
                    shinyCaught = playerHistory.shinyCaught,
                    totalCaught = totalCaught,
                    shinyRate = shinyRate
                }
            })
        end
    end
    
    return violations
end

-- Comprehensive anti-cheat analysis
local function analyzeForCheating(gameState, previousGameState, operationContext)
    local allViolations = {}
    
    -- Pokemon stat manipulation detection
    if gameState.party and previousGameState.party then
        for i, pokemon in ipairs(gameState.party) do
            local previousPokemon = previousGameState.party[i]
            if pokemon and previousPokemon then
                local statViolations = detectStatManipulation(pokemon, previousPokemon)
                for _, violation in ipairs(statViolations) do
                    violation.pokemonIndex = i
                    table.insert(allViolations, violation)
                end
            end
        end
    end
    
    -- Resource manipulation detection
    local resourceViolations = detectResourceManipulation(gameState.inventory, previousGameState.inventory)
    for _, violation in ipairs(resourceViolations) do
        table.insert(allViolations, violation)
    end
    
    -- Progression speed analysis
    if operationContext and operationContext.timeDelta then
        local progressionViolations = detectProgressionSpeedManipulation(
            gameState.progression, 
            previousGameState.progression, 
            operationContext.timeDelta
        )
        for _, violation in ipairs(progressionViolations) do
            table.insert(allViolations, violation)
        end
    end
    
    -- Battle outcome validation
    if operationContext and operationContext.battleResult then
        local battleViolations = detectBattleOutcomeManipulation(
            operationContext.battleResult,
            gameState.battleState and gameState.battleState.playerPokemon,
            gameState.battleState and gameState.battleState.enemyPokemon
        )
        for _, violation in ipairs(battleViolations) do
            table.insert(allViolations, violation)
        end
    end
    
    -- Cheat pattern recognition
    local patternViolations = detectCheatPatterns(
        gameState, 
        previousGameState, 
        operationContext and operationContext.playerHistory
    )
    for _, violation in ipairs(patternViolations) do
        table.insert(allViolations, violation)
    end
    
    -- Calculate risk score
    local riskScore = 0
    local highSeverityCount = 0
    local mediumSeverityCount = 0
    
    for _, violation in ipairs(allViolations) do
        if violation.severity == "HIGH" then
            riskScore = riskScore + 10
            highSeverityCount = highSeverityCount + 1
        elseif violation.severity == "MEDIUM" then
            riskScore = riskScore + 5
            mediumSeverityCount = mediumSeverityCount + 1
        else
            riskScore = riskScore + 1
        end
    end
    
    return {
        violations = allViolations,
        riskScore = riskScore,
        severityCounts = {
            high = highSeverityCount,
            medium = mediumSeverityCount,
            low = #allViolations - highSeverityCount - mediumSeverityCount
        },
        analysisTimestamp = tostring(os.time()),
        recommendation = riskScore > 20 and "BLOCK" or (riskScore > 10 and "INVESTIGATE" or "ALLOW")
    }
end

-- AO Message Handlers
Handlers.add("analyze-cheat-detection",
    Handlers.utils.hasMatchingTag("Action", "AnalyzeCheatDetection"),
    function(msg)
        local success, data = pcall(json.decode, msg.Data or "{}")
        
        if not success then
            ao.send({
                Target = msg.From,
                Action = "CheatAnalysisError",
                Error = "Invalid JSON in analysis data",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        local analysisResult = analyzeForCheating(
            data.gameState,
            data.previousGameState,
            data.operationContext
        )
        
        ao.send({
            Target = msg.From,
            Action = "CheatAnalysisResult",
            Data = json.encode(analysisResult),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus",
            Data = json.encode({
                status = "healthy",
                service = "Anti-Cheat Detector",
                version = "1.0.0",
                capabilities = {
                    "stat-manipulation-detection",
                    "move-usage-validation",
                    "resource-manipulation-detection",
                    "battle-outcome-validation",
                    "progression-speed-analysis",
                    "cheat-pattern-recognition"
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- ADP v1.0 Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = "Anti-Cheat Detector",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "analyzeCheatDetection",
                        "detectStatManipulation",
                        "detectMoveManipulation",
                        "detectResourceManipulation",
                        "detectBattleOutcomeManipulation",
                        "detectProgressionSpeedManipulation",
                        "detectCheatPatterns"
                    },
                    messageSchemas = {
                        AnalyzeCheatDetection = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                gameState = "object",
                                previousGameState = "object",
                                operationContext = "object (optional)"
                            }
                        },
                        HealthCheck = {
                            required = {"Action"}
                        }
                    }
                },
                handlers = {"analyze-cheat-detection", "health-check", "info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    purpose = "Advanced anti-cheat detection with statistical analysis and pattern recognition",
                    detectionFeatures = {
                        "statManipulation",
                        "moveValidation",
                        "resourceManipulation",
                        "battleOutcomeAnalysis",
                        "progressionSpeedAnalysis",
                        "cheatPatternRecognition",
                        "riskScoring",
                        "statisticalAnalysis"
                    }
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export functions for testing
_G.AntiCheatDetector = {
    detectStatManipulation = detectStatManipulation,
    detectMoveManipulation = detectMoveManipulation,
    detectResourceManipulation = detectResourceManipulation,
    detectBattleOutcomeManipulation = detectBattleOutcomeManipulation,
    detectProgressionSpeedManipulation = detectProgressionSpeedManipulation,
    detectCheatPatterns = detectCheatPatterns,
    analyzeForCheating = analyzeForCheating,
    calculateMean = calculateMean,
    calculateStandardDeviation = calculateStandardDeviation,
    calculateZScore = calculateZScore
}