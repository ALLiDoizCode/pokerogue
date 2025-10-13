-- Anti-Cheat Detector Unit Tests
-- Comprehensive test suite for anti-cheat detection system

-- Test data factories
local function createValidPokemon(level)
    return {
        id = 1,
        species = "BULBASAUR",
        level = level or 5,
        hp = 20,
        maxHp = 20,
        ivs = {
            hp = 15,
            attack = 12,
            defense = 13,
            spAttack = 16,
            spDefense = 14,
            speed = 11
        },
        status = "NONE",
        moves = {
            {id = 1, name = "TACKLE", pp = 35, maxPp = 35},
            {id = 2, name = "GROWL", pp = 40, maxPp = 40}
        }
    }
end

local function createPerfectIVPokemon()
    local pokemon = createValidPokemon()
    pokemon.ivs = {
        hp = 31,
        attack = 31,
        defense = 31,
        spAttack = 31,
        spDefense = 31,
        speed = 31
    }
    return pokemon
end

local function createValidInventory(money)
    return {
        money = money or 3000,
        items = {
            POTION = 5,
            POKEBALL = 10
        },
        keyItems = {"POKEDEX", "TOWN_MAP"}
    }
end

local function createValidProgression(exp, badges)
    return {
        exp = exp or 1000,
        badges = badges or {"BOULDER_BADGE"},
        unlockedAreas = {"PALLET_TOWN", "ROUTE_1"}
    }
end

local function createValidGameState()
    return {
        party = {createValidPokemon()},
        inventory = createValidInventory(),
        progression = createValidProgression()
    }
end

-- Test functions
local function testStatManipulationDetection(detector)
    print("  🧪 Testing stat manipulation detection...")
    
    local originalPokemon = createValidPokemon(5)
    
    -- Test IV manipulation (should be detected)
    local ivManipulatedPokemon = createValidPokemon(5)
    ivManipulatedPokemon.ivs.hp = 31  -- Changed from 15 to 31
    
    local violations = detector.detectStatManipulation(ivManipulatedPokemon, originalPokemon)
    assert(#violations > 0, "IV manipulation should be detected")
    assert(violations[1].type == "IV_MANIPULATION", "Should detect IV manipulation")
    assert(violations[1].severity == "HIGH", "IV manipulation should be high severity")
    
    -- Test level decrease (should be detected)
    local levelDecreasedPokemon = createValidPokemon(3) -- Decreased from 5 to 3
    violations = detector.detectStatManipulation(levelDecreasedPokemon, originalPokemon)
    assert(#violations > 0, "Level decrease should be detected")
    assert(violations[1].type == "LEVEL_MANIPULATION", "Should detect level manipulation")
    
    -- Test excessive level gain (should be detected)
    local excessiveLevelPokemon = createValidPokemon(15) -- Increased from 5 to 15 (10 levels)
    violations = detector.detectStatManipulation(excessiveLevelPokemon, originalPokemon)
    assert(#violations > 0, "Excessive level gain should be detected")
    assert(violations[1].type == "EXCESSIVE_LEVEL_GAIN", "Should detect excessive level gain")
    
    -- Test HP manipulation (should be detected)
    local hpManipulatedPokemon = createValidPokemon(5)
    hpManipulatedPokemon.hp = 25  -- Exceeds maxHp of 20
    violations = detector.detectStatManipulation(hpManipulatedPokemon, originalPokemon)
    assert(#violations > 0, "HP manipulation should be detected")
    assert(violations[1].type == "HP_MANIPULATION", "Should detect HP manipulation")
    
    -- Test normal progression (should not be detected)
    local normalProgressionPokemon = createValidPokemon(7) -- Normal 2-level gain
    violations = detector.detectStatManipulation(normalProgressionPokemon, originalPokemon)
    local hasExcessiveGain = false
    for _, violation in ipairs(violations) do
        if violation.type == "EXCESSIVE_LEVEL_GAIN" then
            hasExcessiveGain = true
            break
        end
    end
    assert(not hasExcessiveGain, "Normal level progression should not trigger excessive gain detection")
    
    print("    ✅ Stat manipulation detection tests passed")
end

local function testMoveManipulationDetection(detector)
    print("  🧪 Testing move manipulation detection...")
    
    local pokemon = createValidPokemon()
    
    -- Test valid move usage (should pass)
    local validMove = {id = 1, name = "TACKLE", pp = 35, maxPp = 35}
    local violations = detector.detectMoveManipulation(pokemon, validMove)
    assert(#violations == 0, "Valid move should not trigger violations")
    
    -- Test invalid move usage (should be detected)
    local invalidMove = {id = 999, name = "HYPER_BEAM", pp = 5, maxPp = 5}
    violations = detector.detectMoveManipulation(pokemon, invalidMove)
    assert(#violations > 0, "Invalid move should be detected")
    assert(violations[1].type == "INVALID_MOVE_USAGE", "Should detect invalid move usage")
    assert(violations[1].severity == "HIGH", "Invalid move should be high severity")
    
    -- Test PP manipulation (should be detected)
    local ppManipulatedMove = {id = 1, name = "TACKLE", pp = 50, maxPp = 35} -- PP exceeds max
    violations = detector.detectMoveManipulation(pokemon, ppManipulatedMove)
    assert(#violations > 0, "PP manipulation should be detected")
    assert(violations[1].type == "PP_MANIPULATION", "Should detect PP manipulation")
    
    print("    ✅ Move manipulation detection tests passed")
end

local function testResourceManipulationDetection(detector)
    print("  🧪 Testing resource manipulation detection...")
    
    local originalInventory = createValidInventory(3000)
    
    -- Test excessive money gain (should be detected)
    local richInventory = createValidInventory(150000) -- Gained 147,000 money
    local violations = detector.detectResourceManipulation(richInventory, originalInventory)
    assert(#violations > 0, "Excessive money gain should be detected")
    assert(violations[1].type == "EXCESSIVE_MONEY_GAIN", "Should detect excessive money gain")
    
    -- Test negative money (should be detected)
    local negativeMoneyInventory = createValidInventory(-100)
    violations = detector.detectResourceManipulation(negativeMoneyInventory, originalInventory)
    assert(#violations > 0, "Negative money should be detected")
    assert(violations[1].type == "NEGATIVE_MONEY", "Should detect negative money")
    assert(violations[1].severity == "HIGH", "Negative money should be high severity")
    
    -- Test excessive item gain (should be detected)
    local itemManipulatedInventory = createValidInventory(3000)
    itemManipulatedInventory.items.POTION = 105 -- Gained 100 potions
    violations = detector.detectResourceManipulation(itemManipulatedInventory, originalInventory)
    assert(#violations > 0, "Excessive item gain should be detected")
    assert(violations[1].type == "EXCESSIVE_ITEM_GAIN", "Should detect excessive item gain")
    
    -- Test normal money gain (should not be detected)
    local normalInventory = createValidInventory(4000) -- Gained 1,000 money
    violations = detector.detectResourceManipulation(normalInventory, originalInventory)
    local hasExcessiveGain = false
    for _, violation in ipairs(violations) do
        if violation.type == "EXCESSIVE_MONEY_GAIN" then
            hasExcessiveGain = true
            break
        end
    end
    assert(not hasExcessiveGain, "Normal money gain should not trigger detection")
    
    print("    ✅ Resource manipulation detection tests passed")
end

local function testBattleOutcomeManipulation(detector)
    print("  🧪 Testing battle outcome manipulation detection...")
    
    local playerPokemon = createValidPokemon(5)
    local enemyPokemon = createValidPokemon(5)
    
    -- Test impossible damage (should be detected)
    local impossibleDamageBattle = {damage = 15000, criticalHits = 1, totalHits = 1}
    local violations = detector.detectBattleOutcomeManipulation(impossibleDamageBattle, playerPokemon, enemyPokemon)
    assert(#violations > 0, "Impossible damage should be detected")
    assert(violations[1].type == "IMPOSSIBLE_DAMAGE", "Should detect impossible damage")
    assert(violations[1].severity == "HIGH", "Impossible damage should be high severity")
    
    -- Test suspicious critical hit rate (should be detected)
    local suspiciousCritBattle = {damage = 100, criticalHits = 8, totalHits = 15} -- 53% crit rate
    violations = detector.detectBattleOutcomeManipulation(suspiciousCritBattle, playerPokemon, enemyPokemon)
    assert(#violations > 0, "Suspicious crit rate should be detected")
    assert(violations[1].type == "SUSPICIOUS_CRITICAL_RATE", "Should detect suspicious critical rate")
    
    -- Test normal battle outcome (should not be detected)
    local normalBattle = {damage = 25, criticalHits = 1, totalHits = 10} -- 10% crit rate
    violations = detector.detectBattleOutcomeManipulation(normalBattle, playerPokemon, enemyPokemon)
    assert(#violations == 0, "Normal battle outcome should not trigger violations")
    
    print("    ✅ Battle outcome manipulation detection tests passed")
end

local function testProgressionSpeedManipulation(detector)
    print("  🧪 Testing progression speed manipulation detection...")
    
    local originalProgression = createValidProgression(1000, {"BOULDER_BADGE"})
    
    -- Test excessive exp rate (should be detected)
    local fastExpProgression = createValidProgression(11000) -- Gained 10,000 exp
    local violations = detector.detectProgressionSpeedManipulation(fastExpProgression, originalProgression, 5) -- In 5 seconds
    assert(#violations > 0, "Excessive exp rate should be detected")
    assert(violations[1].type == "EXCESSIVE_EXP_RATE", "Should detect excessive exp rate")
    
    -- Test rapid badge gain (should be detected)
    local rapidBadgeProgression = createValidProgression(1000, {"BOULDER_BADGE", "CASCADE_BADGE", "THUNDER_BADGE"})
    violations = detector.detectProgressionSpeedManipulation(rapidBadgeProgression, originalProgression, 30) -- 2 badges in 30 seconds
    assert(#violations > 0, "Rapid badge gain should be detected")
    assert(violations[1].type == "RAPID_BADGE_GAIN", "Should detect rapid badge gain")
    assert(violations[1].severity == "HIGH", "Rapid badge gain should be high severity")
    
    -- Test normal progression (should not be detected)
    local normalProgression = createValidProgression(1200) -- Gained 200 exp
    violations = detector.detectProgressionSpeedManipulation(normalProgression, originalProgression, 60) -- In 60 seconds
    assert(#violations == 0, "Normal progression should not trigger violations")
    
    print("    ✅ Progression speed manipulation detection tests passed")
end

local function testCheatPatternRecognition(detector)
    print("  🧪 Testing cheat pattern recognition...")
    
    -- Test perfect IV pattern detection
    local perfectIVGameState = createValidGameState()
    perfectIVGameState.party = {createPerfectIVPokemon()}
    
    local violations = detector.detectCheatPatterns(perfectIVGameState, createValidGameState(), nil)
    assert(#violations > 0, "Perfect IV pattern should be detected")
    assert(violations[1].type == "PERFECT_IV_PATTERN", "Should detect perfect IV pattern")
    
    -- Test suspicious shiny rate
    local playerHistory = {shinyCaught = 5, totalCaught = 200} -- 2.5% shiny rate
    violations = detector.detectCheatPatterns(createValidGameState(), createValidGameState(), playerHistory)
    assert(#violations > 0, "Suspicious shiny rate should be detected")
    assert(violations[1].type == "SUSPICIOUS_SHINY_RATE", "Should detect suspicious shiny rate")
    
    -- Test normal patterns (should not be detected)
    local normalGameState = createValidGameState()
    local normalHistory = {shinyCaught = 1, totalCaught = 200} -- 0.5% shiny rate (normal)
    violations = detector.detectCheatPatterns(normalGameState, createValidGameState(), normalHistory)
    
    local hasSuspiciousShiny = false
    for _, violation in ipairs(violations) do
        if violation.type == "SUSPICIOUS_SHINY_RATE" then
            hasSuspiciousShiny = true
            break
        end
    end
    assert(not hasSuspiciousShiny, "Normal shiny rate should not trigger detection")
    
    print("    ✅ Cheat pattern recognition tests passed")
end

local function testComprehensiveAnalysis(detector)
    print("  🧪 Testing comprehensive cheat analysis...")
    
    -- Create scenarios with multiple violations
    local originalGameState = createValidGameState()
    
    local cheatedGameState = createValidGameState()
    cheatedGameState.party[1].level = 15 -- Excessive level gain
    cheatedGameState.party[1].ivs.hp = 31 -- IV manipulation
    cheatedGameState.inventory.money = 150000 -- Excessive money gain
    
    local operationContext = {
        timeDelta = 5,
        battleResult = {damage = 15000}, -- Impossible damage
        playerHistory = {shinyCaught = 5, totalCaught = 200} -- Suspicious shiny rate
    }
    
    local analysisResult = detector.analyzeForCheating(cheatedGameState, originalGameState, operationContext)
    
    assert(analysisResult ~= nil, "Analysis result should not be nil")
    assert(#analysisResult.violations > 0, "Should detect multiple violations")
    assert(analysisResult.riskScore > 0, "Risk score should be calculated")
    assert(analysisResult.severityCounts ~= nil, "Severity counts should be provided")
    assert(analysisResult.recommendation ~= nil, "Recommendation should be provided")
    assert(analysisResult.recommendation == "BLOCK", "High risk should recommend blocking")
    
    -- Test clean analysis (should pass)
    local cleanGameState = createValidGameState()
    cleanGameState.party[1].level = 6 -- Normal 1-level gain
    cleanGameState.inventory.money = 3100 -- Normal money gain
    
    local cleanContext = {
        timeDelta = 60,
        battleResult = {damage = 25, criticalHits = 1, totalHits = 10},
        playerHistory = {shinyCaught = 1, totalCaught = 200}
    }
    
    analysisResult = detector.analyzeForCheating(cleanGameState, originalGameState, cleanContext)
    assert(analysisResult.riskScore < 10, "Clean gameplay should have low risk score")
    assert(analysisResult.recommendation == "ALLOW", "Clean gameplay should be allowed")
    
    print("    ✅ Comprehensive cheat analysis tests passed")
end

local function testStatisticalFunctions(detector)
    print("  🧪 Testing statistical functions...")
    
    -- Test mean calculation
    local values = {1, 2, 3, 4, 5}
    local mean = detector.calculateMean(values)
    assert(mean == 3, "Mean should be 3 for values 1-5")
    
    -- Test standard deviation
    local stdDev = detector.calculateStandardDeviation(values, mean)
    assert(stdDev > 1.5 and stdDev < 1.6, "Standard deviation should be approximately 1.58")
    
    -- Test Z-score calculation
    local zScore = detector.calculateZScore(5, mean, stdDev)
    assert(zScore > 1.2 and zScore < 1.3, "Z-score should be approximately 1.26")
    
    -- Test edge cases
    local emptyMean = detector.calculateMean({})
    assert(emptyMean == 0, "Mean of empty array should be 0")
    
    local singleValueStdDev = detector.calculateStandardDeviation({5}, 5)
    assert(singleValueStdDev == 0, "Standard deviation of single value should be 0")
    
    print("    ✅ Statistical functions tests passed")
end

local function testPerformance(detector)
    print("  🧪 Testing anti-cheat performance...")
    
    -- Create complex game state for performance testing
    local largeGameState = createValidGameState()
    for i = 2, 6 do
        largeGameState.party[i] = createValidPokemon(i * 5)
    end
    
    -- Add many items
    for i = 1, 50 do
        largeGameState.inventory.items["ITEM_" .. i] = 10
    end
    
    local operationContext = {
        timeDelta = 30,
        battleResult = {damage = 50, criticalHits = 2, totalHits = 20},
        playerHistory = {shinyCaught = 2, totalCaught = 500}
    }
    
    local startTime = os.clock()
    local analysisResult = detector.analyzeForCheating(largeGameState, createValidGameState(), operationContext)
    local endTime = os.clock()
    local duration = endTime - startTime
    
    assert(analysisResult ~= nil, "Analysis should complete successfully")
    assert(duration < 0.2, "Analysis should complete within 200ms (actual: " .. duration .. "s)")
    
    print("    ✅ Performance tests passed - analysis completed in " .. string.format("%.3f", duration) .. "s")
end

-- Main test runner
local function runAllTests()
    -- Setup environment
    _G.json = {
        encode = function(obj) return "json_encoded" end,
        decode = function(str) return {decoded = true} end
    }
    _G.ao = {
        send = function(msg) end,
        id = "test_anti_cheat_detector"
    }
    _G.Handlers = {
        add = function(name, matcher, handler) end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg) return true end
            end
        }
    }
    
    -- Load the detector
    dofile("processes/security/anti-cheat-detector.lua")
    local detector = _G.AntiCheatDetector
    
    print("🚀 Anti-Cheat Detector Test Suite")
    print("="..string.rep("=", 50))
    
    testStatisticalFunctions(detector)
    testStatManipulationDetection(detector)
    testMoveManipulationDetection(detector)
    testResourceManipulationDetection(detector)
    testBattleOutcomeManipulation(detector)
    testProgressionSpeedManipulation(detector)
    testCheatPatternRecognition(detector)
    testComprehensiveAnalysis(detector)
    testPerformance(detector)
    
    print("="..string.rep("=", 50))
    print("🎉 All Anti-Cheat Detector tests passed!")
    return true
end

-- Export test runner
return {
    runAllTests = runAllTests
}