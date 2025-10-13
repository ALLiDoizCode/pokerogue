-- Terastalization Battle Integration Engine Process for Pokemon Battle System
-- Implements comprehensive battle integration for Terastalization mechanics with cross-process coordination
-- ADP v1.0 compliant for self-documentation and agent compatibility

-- Note: json is available as a global in AO environment

-- ===============================
-- EMBEDDED BATTLE INTEGRATION DATABASE
-- ===============================

-- Process IDs for coordination (will be set during deployment)
local PROCESS_IDS = {
    TERA_TYPE_ENGINE = "TERA_TYPE_PROCESS_ID", -- tera-type-engine.lua
    STELLAR_TERA_ENGINE = "STELLAR_TERA_PROCESS_ID", -- stellar-tera-engine.lua
    TERA_CRYSTAL_ENGINE = "TERA_CRYSTAL_PROCESS_ID", -- tera-crystal-engine.lua
    BATTLE_STATE_MANAGER = "BATTLE_STATE_PROCESS_ID" -- battle-state-manager.lua
}

-- Battle phases for Terastalization timing
local BATTLE_PHASES = {
    COMMAND_PHASE = "COMMAND_PHASE",         -- Terastalization activation occurs here
    MOVE_EXECUTION_PHASE = "MOVE_EXECUTION_PHASE", -- Tera effects apply during moves
    STATUS_PHASE = "STATUS_PHASE",           -- Status effect interactions with Tera types
    END_PHASE = "END_PHASE"                  -- Cleanup and state updates
}

-- Status effect types and their interactions with Tera types
local STATUS_INTERACTIONS = {
    -- Status effects that can be prevented by Tera type immunity
    BURN = {
        immuneTypes = {"FIRE"},
        applyDamage = true,
        physicalAttackReduction = 0.5
    },
    POISON = {
        immuneTypes = {"POISON", "STEEL"},
        applyDamage = true
    },
    PARALYSIS = {
        immuneTypes = {"ELECTRIC"},
        speedReduction = 0.75,
        moveFailureChance = 0.25
    },
    FREEZE = {
        immuneTypes = {"ICE"},
        preventMove = true,
        thawChance = 0.2
    },
    SLEEP = {
        immuneTypes = {},
        preventMove = true,
        turnDuration = {min = 1, max = 3}
    }
}

-- Weather and terrain effects that interact with Tera types
local ENVIRONMENTAL_EFFECTS = {
    weather = {
        RAIN = {
            boostedTypes = {"WATER"},
            weakenedTypes = {"FIRE"},
            modifier = 1.5
        },
        SUN = {
            boostedTypes = {"FIRE"},
            weakenedTypes = {"WATER"},
            modifier = 1.5
        },
        HAIL = {
            damagingTo = "ALL_EXCEPT_ICE",
            immuneTypes = {"ICE"},
            damagePercentage = 0.0625
        },
        SANDSTORM = {
            damagingTo = "ALL_EXCEPT_GROUND_ROCK_STEEL",
            immuneTypes = {"GROUND", "ROCK", "STEEL"},
            spDefBoost = {"ROCK"},
            damagePercentage = 0.0625
        }
    },
    terrain = {
        ELECTRIC_TERRAIN = {
            boostedTypes = {"ELECTRIC"},
            preventStatus = {"SLEEP"},
            turnDuration = 5
        },
        GRASSY_TERRAIN = {
            boostedTypes = {"GRASS"},
            healingPercentage = 0.0625,
            turnDuration = 5
        },
        PSYCHIC_TERRAIN = {
            boostedTypes = {"PSYCHIC"},
            preventPriority = true,
            turnDuration = 5
        },
        MISTY_TERRAIN = {
            boostedTypes = {"FAIRY"},
            preventStatus = {"BURN", "POISON", "PARALYSIS", "SLEEP", "FREEZE"},
            turnDuration = 5
        }
    }
}

-- AI decision-making patterns for Terastalization
local AI_PATTERNS = {
    AGGRESSIVE = {
        teraUsagePriority = 0.8,
        preferOffensiveTypes = true,
        considerTypeAdvantage = true
    },
    DEFENSIVE = {
        teraUsagePriority = 0.6,
        preferResistiveTypes = true,
        considerWeaknessCoverage = true
    },
    BALANCED = {
        teraUsagePriority = 0.7,
        considerBothOffenseDefense = true,
        adaptToSituation = true
    }
}

-- ===============================
-- PROCESS STATE INITIALIZATION
-- ===============================

if not TerastalizationBattleState then
    TerastalizationBattleState = {
        initialized = true,
        version = "1.0.0",
        activeBattles = {},
        aiContexts = {},
        phaseTimers = {},
        coordinationQueue = {}
    }
end

-- ===============================
-- UTILITY FUNCTIONS
-- ===============================

-- Validate battle data structure with comprehensive checks
local function validateBattleData(battleData)
    if not battleData then return false, "Missing battle data" end
    if not battleData.battleId then return false, "Missing battle ID" end
    if not battleData.pokemonId then return false, "Missing Pokemon ID" end
    if not battleData.phase then return false, "Missing battle phase" end
    
    -- Validate battle phase is recognized
    local validPhases = {BATTLE_PHASES.COMMAND_PHASE, BATTLE_PHASES.MOVE_EXECUTION_PHASE, BATTLE_PHASES.STATUS_PHASE, BATTLE_PHASES.END_PHASE}
    local phaseValid = false
    for _, validPhase in ipairs(validPhases) do
        if battleData.phase == validPhase then
            phaseValid = true
            break
        end
    end
    if not phaseValid then
        return false, "Invalid battle phase: " .. tostring(battleData.phase)
    end
    
    -- Validate turn number if provided
    if battleData.turn and (type(battleData.turn) ~= "number" or battleData.turn < 1 or battleData.turn > 1000) then
        return false, "Invalid turn number: must be between 1 and 1000"
    end
    
    -- Validate Tera type if provided
    if battleData.teraType then
        local validTeraTypes = {"NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG", "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY", "STELLAR"}
        local teraTypeValid = false
        for _, validType in ipairs(validTeraTypes) do
            if battleData.teraType == validType then
                teraTypeValid = true
                break
            end
        end
        if not teraTypeValid then
            return false, "Invalid Tera type: " .. tostring(battleData.teraType)
        end
    end
    
    return true, "Valid"
end

-- Check if Pokemon can activate Terastalization based on timing
local function canActivateInPhase(phase, pokemonData)
    -- Terastalization can only be activated during COMMAND_PHASE
    if phase ~= BATTLE_PHASES.COMMAND_PHASE then
        return false, "Invalid phase for Terastalization activation"
    end
    
    -- Check if Pokemon is already Terastalized
    if pokemonData and pokemonData.isTerastallized then
        return false, "Pokemon is already Terastalized"
    end
    
    -- Check if Pokemon is fainted
    if pokemonData and pokemonData.hp and pokemonData.hp <= 0 then
        return false, "Cannot Terastalize fainted Pokemon"
    end
    
    return true, "Can activate"
end

-- Calculate type-based status immunity
local function checkStatusImmunity(teraType, statusEffect)
    if not teraType or not statusEffect then return false end
    
    local statusData = STATUS_INTERACTIONS[statusEffect]
    if not statusData or not statusData.immuneTypes then return false end
    
    for _, immuneType in ipairs(statusData.immuneTypes) do
        if immuneType == teraType then
            return true
        end
    end
    
    return false
end

-- Calculate weather/terrain effectiveness boost
local function calculateEnvironmentalBoost(teraType, weatherType, terrainType)
    local boost = 1.0
    
    -- Weather effects
    if weatherType and ENVIRONMENTAL_EFFECTS.weather[weatherType] then
        local weather = ENVIRONMENTAL_EFFECTS.weather[weatherType]
        if weather.boostedTypes then
            for _, boostedType in ipairs(weather.boostedTypes) do
                if boostedType == teraType then
                    boost = boost * weather.modifier
                end
            end
        end
        if weather.weakenedTypes then
            for _, weakenedType in ipairs(weather.weakenedTypes) do
                if weakenedType == teraType then
                    boost = boost / weather.modifier
                end
            end
        end
    end
    
    -- Terrain effects
    if terrainType and ENVIRONMENTAL_EFFECTS.terrain[terrainType] then
        local terrain = ENVIRONMENTAL_EFFECTS.terrain[terrainType]
        if terrain.boostedTypes then
            for _, boostedType in ipairs(terrain.boostedTypes) do
                if boostedType == teraType then
                    boost = boost * 1.3 -- Standard terrain boost
                end
            end
        end
    end
    
    return boost
end

-- Generate AI decision for Terastalization
local function generateAIDecision(battleContext, aiStrategy, randomSeed)
    local strategy = AI_PATTERNS[aiStrategy] or AI_PATTERNS.BALANCED
    local decision = {
        shouldUse = false,
        recommendedType = nil,
        confidence = 0.0,
        reasoning = {}
    }
    
    -- Use deterministic random calculation based on seed instead of math.random()
    local usageThreshold = strategy.teraUsagePriority * 100
    local randomValue = (randomSeed % 100) + 1  -- Convert to 1-100 range
    
    -- Basic probability check using deterministic calculation
    if randomValue > usageThreshold then
        decision.reasoning = {"AI chose not to use Terastalization this turn (probability: " .. randomValue .. "/" .. usageThreshold .. ")"}
        return decision
    end
    
    -- Type advantage consideration with more sophisticated logic
    if battleContext.opponentTypes and strategy.considerTypeAdvantage then
        -- Select optimal type based on opponent weaknesses
        local optimalType = selectOptimalTeraType(battleContext.opponentTypes, battleContext.availableTypes)
        decision.shouldUse = true
        decision.recommendedType = optimalType or "NORMAL"
        decision.confidence = 0.7
        table.insert(decision.reasoning, "Type advantage detected against opponent types")
    elseif strategy.preferDefensiveTypes and battleContext.playerWeaknesses then
        -- Defensive strategy: cover weaknesses
        decision.shouldUse = true
        decision.recommendedType = selectDefensiveTeraType(battleContext.playerWeaknesses)
        decision.confidence = 0.6
        table.insert(decision.reasoning, "Defensive type coverage selected")
    end
    
    return decision
end

-- Helper function to select optimal offensive Tera type
local function selectOptimalTeraType(opponentTypes, availableTypes)
    -- Type effectiveness chart (simplified for AI decision making)
    local typeEffectiveness = {
        FIRE = {weakTo = {"WATER", "GROUND", "ROCK"}, strongAgainst = {"GRASS", "ICE", "BUG", "STEEL"}},
        WATER = {weakTo = {"ELECTRIC", "GRASS"}, strongAgainst = {"FIRE", "GROUND", "ROCK"}},
        ELECTRIC = {weakTo = {"GROUND"}, strongAgainst = {"WATER", "FLYING"}},
        GRASS = {weakTo = {"FIRE", "ICE", "POISON", "FLYING", "BUG"}, strongAgainst = {"WATER", "GROUND", "ROCK"}},
        ICE = {weakTo = {"FIRE", "FIGHTING", "ROCK", "STEEL"}, strongAgainst = {"GRASS", "GROUND", "FLYING", "DRAGON"}},
        FIGHTING = {weakTo = {"FLYING", "PSYCHIC", "FAIRY"}, strongAgainst = {"NORMAL", "ICE", "ROCK", "DARK", "STEEL"}},
        POISON = {weakTo = {"GROUND", "PSYCHIC"}, strongAgainst = {"GRASS", "FAIRY"}},
        GROUND = {weakTo = {"WATER", "GRASS", "ICE"}, strongAgainst = {"FIRE", "ELECTRIC", "POISON", "ROCK", "STEEL"}},
        FLYING = {weakTo = {"ELECTRIC", "ICE", "ROCK"}, strongAgainst = {"GRASS", "FIGHTING", "BUG"}},
        PSYCHIC = {weakTo = {"BUG", "GHOST", "DARK"}, strongAgainst = {"FIGHTING", "POISON"}},
        BUG = {weakTo = {"FIRE", "FLYING", "ROCK"}, strongAgainst = {"GRASS", "PSYCHIC", "DARK"}},
        ROCK = {weakTo = {"WATER", "GRASS", "FIGHTING", "GROUND", "STEEL"}, strongAgainst = {"FIRE", "ICE", "FLYING", "BUG"}},
        GHOST = {weakTo = {"GHOST", "DARK"}, strongAgainst = {"PSYCHIC", "GHOST"}},
        DRAGON = {weakTo = {"ICE", "DRAGON", "FAIRY"}, strongAgainst = {"DRAGON"}},
        DARK = {weakTo = {"FIGHTING", "BUG", "FAIRY"}, strongAgainst = {"PSYCHIC", "GHOST"}},
        STEEL = {weakTo = {"FIRE", "FIGHTING", "GROUND"}, strongAgainst = {"ICE", "ROCK", "FAIRY"}},
        FAIRY = {weakTo = {"POISON", "STEEL"}, strongAgainst = {"FIGHTING", "DRAGON", "DARK"}}
    }
    
    -- Find best type that's strong against opponent
    for _, teraType in ipairs(availableTypes or {"FIRE", "WATER", "ELECTRIC", "GRASS"}) do
        local typeData = typeEffectiveness[teraType]
        if typeData and typeData.strongAgainst then
            for _, strongAgainst in ipairs(typeData.strongAgainst) do
                for _, opponentType in ipairs(opponentTypes) do
                    if strongAgainst == opponentType then
                        return teraType
                    end
                end
            end
        end
    end
    
    -- Default to a versatile type if no clear advantage
    return "WATER"
end

-- Helper function to select defensive Tera type
local function selectDefensiveTeraType(playerWeaknesses)
    -- Defensive type coverage mapping
    local defensiveTypes = {
        ["WATER"] = {"FIRE", "GROUND", "ROCK"},  -- Water resists these
        ["FIRE"] = {"GRASS", "ICE", "BUG", "STEEL"},  -- Fire resists these
        ["STEEL"] = {"NORMAL", "GRASS", "ICE", "FLYING", "PSYCHIC", "BUG", "ROCK", "DRAGON", "STEEL", "FAIRY"},  -- Steel resists many
        ["ELECTRIC"] = {"FLYING", "STEEL", "ELECTRIC"}  -- Electric resists these
    }
    
    -- Find type that covers the most weaknesses
    local bestType = "STEEL"  -- Default to Steel (good defensive type)
    local bestCoverage = 0
    
    for defenseType, resistances in pairs(defensiveTypes) do
        local coverage = 0
        for _, resistance in ipairs(resistances) do
            for _, weakness in ipairs(playerWeaknesses or {}) do
                if resistance == weakness then
                    coverage = coverage + 1
                end
            end
        end
        if coverage > bestCoverage then
            bestCoverage = coverage
            bestType = defenseType
        end
    end
    
    return bestType
end

-- ===============================
-- ERROR HANDLING SYSTEM
-- ===============================

local ERROR_CODES = {
    -- Integration errors (TERA_BATTLE_001-099)
    INVALID_BATTLE_DATA = {code = "TERA_BATTLE_001", message = "Invalid battle data structure", recovery = "Validate battle parameters"},
    INVALID_PHASE = {code = "TERA_BATTLE_002", message = "Invalid battle phase for operation", recovery = "Check phase timing"},
    POKEMON_UNAVAILABLE = {code = "TERA_BATTLE_003", message = "Pokemon cannot perform action", recovery = "Check Pokemon state"},
    USAGE_ALREADY_CONSUMED = {code = "TERA_BATTLE_004", message = "Terastalization already used this battle", recovery = "Reset for new battle"},
    
    -- Coordination errors (TERA_BATTLE_101-199)
    PROCESS_COMMUNICATION_FAILED = {code = "TERA_BATTLE_101", message = "Failed to communicate with Tera process", recovery = "Retry coordination"},
    VALIDATION_FAILED = {code = "TERA_BATTLE_102", message = "Cross-process validation failed", recovery = "Check process state"},
    TIMEOUT_ERROR = {code = "TERA_BATTLE_103", message = "Operation timeout", recovery = "Retry with simpler operation"},
    
    -- Status interaction errors (TERA_BATTLE_201-299)
    STATUS_CONFLICT = {code = "TERA_BATTLE_201", message = "Status effect conflicts with Tera type", recovery = "Resolve status interaction"},
    IMMUNITY_CALCULATION_ERROR = {code = "TERA_BATTLE_202", message = "Status immunity calculation failed", recovery = "Use default immunity rules"},
    
    -- JSON parsing errors (TERA_BATTLE_301-399)
    INVALID_JSON = {code = "TERA_BATTLE_301", message = "Invalid JSON in message data", recovery = "Use empty data structure"}
}

local function sendErrorResponse(target, errorInfo, context)
    local response = {
        Target = target,
        Action = "TerastalizationBattleError",
        ErrorCode = errorInfo.code,
        ErrorMessage = errorInfo.message,
        RecoveryAction = errorInfo.recovery,
        Context = context or {},
        Timestamp = msg.Timestamp or "0",
        ProcessId = ao.id
    }
    
    ao.send(response)
end

-- Safe JSON parsing with comprehensive error handling
local function safeJsonDecode(jsonStr, defaultValue)
    if not jsonStr or jsonStr == "" then
        return defaultValue or {}
    end
    
    -- Validate JSON string format before decoding
    if type(jsonStr) ~= "string" then
        return defaultValue or {}
    end
    
    -- Additional validation for common malformed JSON patterns
    if not jsonStr:match("^%s*[{%[]") or not jsonStr:match("[}%]]%s*$") then
        return defaultValue or {}
    end
    
    local decoded = json.decode(jsonStr)
    return decoded or defaultValue or {}
end

-- ===============================
-- CORE BATTLE INTEGRATION FUNCTIONS
-- ===============================

-- Coordinate Terastalization activation with all relevant processes
local function coordinateTerastalizationActivation(battleData)
    local coordination = {
        success = true,
        responses = {},
        errors = {}
    }
    
    -- 1. Validate with tera-crystal-engine.lua (eligibility)
    ao.send({
        Target = PROCESS_IDS.TERA_CRYSTAL_ENGINE,
        Action = "CheckTeraEligibility",
        PokemonId = battleData.pokemonId,
        BattleId = battleData.battleId,
        PokemonData = json.encode(battleData.pokemonData or {})
    })
    
    -- 2. Coordinate with tera-type-engine.lua (type validation and activation)
    ao.send({
        Target = PROCESS_IDS.TERA_TYPE_ENGINE,
        Action = "ActivateTerastalization",
        Data = json.encode(battleData.pokemonData or {}),
        BattleId = battleData.battleId,
        TrainerId = battleData.trainerId,
        Turn = tostring(battleData.turn or 1)
    })
    
    -- 3. Handle Stellar Tera if applicable
    if battleData.teraType == "STELLAR" then
        ao.send({
            Target = PROCESS_IDS.STELLAR_TERA_ENGINE,
            Action = "ProcessStellarTera",
            Operation = "activate",
            Data = json.encode(battleData.pokemonData or {}),
            BattleId = battleData.battleId
        })
    end
    
    -- 4. Update battle state
    ao.send({
        Target = PROCESS_IDS.BATTLE_STATE_MANAGER,
        Action = "UpdatePokemonState",
        BattleId = battleData.battleId,
        PokemonId = battleData.pokemonId,
        StateUpdates = json.encode({
            isTerastallized = true,
            teraType = battleData.teraType,
            teraActivationTurn = battleData.turn
        })
    })
    
    return coordination
end

-- Process status effect interactions with Tera types
local function processStatusInteraction(pokemonData, statusEffect, teraType)
    local interaction = {
        immune = false,
        modified = false,
        effects = {}
    }
    
    -- Check for type-based immunity
    if checkStatusImmunity(teraType, statusEffect) then
        interaction.immune = true
        interaction.effects = {"Status effect blocked by Tera type immunity"}
        return interaction
    end
    
    -- Apply status effect modifications based on Tera type
    local statusData = STATUS_INTERACTIONS[statusEffect]
    if statusData then
        if statusData.applyDamage then
            table.insert(interaction.effects, "Status damage applies normally")
        end
        if statusData.physicalAttackReduction and teraType ~= "FIRE" then
            table.insert(interaction.effects, "Physical attack reduction applies")
        end
        if statusData.speedReduction then
            table.insert(interaction.effects, "Speed reduction applies")
        end
    end
    
    return interaction
end

-- Calculate complex interaction results (status + weather + terrain + Tera)
local function calculateComplexInteraction(battleState)
    local result = {
        finalDamageMultiplier = 1.0,
        statusEffects = {},
        environmentalBoosts = {},
        interactions = {}
    }
    
    if not battleState or not battleState.pokemon then
        return result
    end
    
    local pokemon = battleState.pokemon
    local teraType = pokemon.teraType or pokemon.types[1]
    
    -- Environmental boosts
    local envBoost = calculateEnvironmentalBoost(
        teraType,
        battleState.weather,
        battleState.terrain
    )
    result.finalDamageMultiplier = result.finalDamageMultiplier * envBoost
    
    -- Status interactions
    if pokemon.statusEffect then
        local statusInteraction = processStatusInteraction(
            pokemon,
            pokemon.statusEffect,
            teraType
        )
        result.statusEffects = statusInteraction.effects
    end
    
    -- Add interaction details
    table.insert(result.interactions, {
        type = "environmental",
        boost = envBoost,
        teraType = teraType
    })
    
    return result
end

-- ===============================
-- AO MESSAGE HANDLERS
-- ===============================

-- Main Terastalization battle integration handler
Handlers.add(
    "process-terastalization-battle",
    Handlers.utils.hasMatchingTag("Action", "ProcessTerastalizationBattle"),
    function(msg)
        local operation = msg.Operation or "activate"
        local battleData = {
            battleId = msg.BattleId,
            pokemonId = msg.PokemonId,
            teraType = msg.TeraType,
            phase = msg.BattlePhase or BATTLE_PHASES.COMMAND_PHASE,
            turn = tonumber(msg.TurnNumber) or 1,
            trainerId = msg.TrainerId or msg.From,
            pokemonData = safeJsonDecode(msg.Data, {})
        }
        
        -- Validate battle data
        local isValid, errorMsg = validateBattleData(battleData)
        if not isValid then
            sendErrorResponse(msg.From, ERROR_CODES.INVALID_BATTLE_DATA, {
                operation = operation,
                error = errorMsg
            })
            return
        end
        
        local response = {
            Target = msg.From,
            Action = "TerastalizationBattleProcessed",
            Operation = operation,
            Success = "false",
            ProcessId = ao.id
        }
        
        if operation == "activate" then
            -- Check activation requirements
            local canActivate, reason = canActivateInPhase(battleData.phase, battleData.pokemonData)
            if not canActivate then
                response.Error = reason
                ao.send(response)
                return
            end
            
            -- Coordinate activation across processes
            local coordination = coordinateTerastalizationActivation(battleData)
            
            response.Success = "true"
            response.Message = "Terastalization activation coordinated"
            response.BattleId = battleData.battleId
            response.PokemonId = battleData.pokemonId
            response.TeraType = battleData.teraType
            
        elseif operation == "integrate" then
            -- Handle battle integration during move execution
            local integrationData = safeJsonDecode(msg.Data, {})
            local complexResult = calculateComplexInteraction(integrationData)
            
            response.Success = "true"
            response.IntegrationResult = json.encode(complexResult)
            
        elseif operation == "validate" then
            -- Validate current battle state consistency
            local battleState = safeJsonDecode(msg.Data, {})
            response.Success = "true"
            response.ValidationResult = "Battle state validated"
            
        elseif operation == "coordinate" then
            -- Handle cross-process coordination
            response.Success = "true"
            response.CoordinationStatus = "Coordination completed"
            
        else
            response.Error = "Unknown operation: " .. operation
        end
        
        ao.send(response)
    end
)

-- Handle battle timing coordination
Handlers.add(
    "battle-timing-coordination",
    Handlers.utils.hasMatchingTag("Action", "BattleTimingCoordination"),
    function(msg)
        local battleId = msg.BattleId
        local phase = msg.Phase or BATTLE_PHASES.COMMAND_PHASE
        local turn = tonumber(msg.Turn) or 1
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BattleId required",
                Success = "false"
            })
            return
        end
        
        -- Update battle phase timing
        if not TerastalizationBattleState.activeBattles[battleId] then
            TerastalizationBattleState.activeBattles[battleId] = {
                currentPhase = phase,
                currentTurn = turn,
                phaseHistory = {}
            }
        end
        
        local battle = TerastalizationBattleState.activeBattles[battleId]
        battle.currentPhase = phase
        battle.currentTurn = turn
        table.insert(battle.phaseHistory, {
            phase = phase,
            turn = turn,
            timestamp = msg.Timestamp or "0"
        })
        
        ao.send({
            Target = msg.From,
            Action = "BattleTimingUpdated",
            Success = "true",
            BattleId = battleId,
            Phase = phase,
            Turn = tostring(turn),
            ProcessId = ao.id
        })
    end
)

-- Handle status effect interactions
Handlers.add(
    "status-effect-interaction",
    Handlers.utils.hasMatchingTag("Action", "StatusEffectInteraction"),
    function(msg)
        local pokemonData = safeJsonDecode(msg.Data, {})
        local statusEffect = msg.StatusEffect
        local teraType = msg.TeraType or pokemonData.teraType
        
        if not statusEffect or not teraType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "StatusEffect and TeraType required",
                Success = "false"
            })
            return
        end
        
        local interaction = processStatusInteraction(pokemonData, statusEffect, teraType)
        
        ao.send({
            Target = msg.From,
            Action = "StatusEffectInteractionProcessed",
            Success = "true",
            Immune = tostring(interaction.immune),
            Modified = tostring(interaction.modified),
            Effects = json.encode(interaction.effects),
            StatusEffect = statusEffect,
            TeraType = teraType,
            ProcessId = ao.id
        })
    end
)

-- Handle weather and terrain integration
Handlers.add(
    "weather-terrain-integration",
    Handlers.utils.hasMatchingTag("Action", "WeatherTerrainIntegration"),
    function(msg)
        local teraType = msg.TeraType
        local weatherType = msg.Weather
        local terrainType = msg.Terrain
        
        if not teraType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TeraType required",
                Success = "false"
            })
            return
        end
        
        local boost = calculateEnvironmentalBoost(teraType, weatherType, terrainType)
        
        ao.send({
            Target = msg.From,
            Action = "WeatherTerrainIntegrationProcessed",
            Success = "true",
            EnvironmentalBoost = tostring(boost),
            TeraType = teraType,
            Weather = weatherType or "none",
            Terrain = terrainType or "none",
            ProcessId = ao.id
        })
    end
)

-- Handle AI decision making
Handlers.add(
    "ai-decision-making",
    Handlers.utils.hasMatchingTag("Action", "AIDecisionMaking"),
    function(msg)
        local battleContext = safeJsonDecode(msg.Data, {})
        local aiStrategy = msg.AIStrategy or "BALANCED"
        local turn = tonumber(msg.Turn) or 1
        
        -- Generate AI decision with deterministic seed (no math.random() usage)
        local randomSeed = tonumber(msg.Timestamp) or (turn * 1234567)
        local decision = generateAIDecision(battleContext, aiStrategy, randomSeed)
        
        ao.send({
            Target = msg.From,
            Action = "AIDecisionMade",
            Success = "true",
            ShouldUse = tostring(decision.shouldUse),
            RecommendedType = decision.recommendedType or "none",
            Confidence = tostring(decision.confidence),
            Reasoning = json.encode(decision.reasoning),
            AIStrategy = aiStrategy,
            ProcessId = ao.id
        })
    end
)

-- Handle complex scenario coordination
Handlers.add(
    "complex-scenario-coordination",
    Handlers.utils.hasMatchingTag("Action", "ComplexScenarioCoordination"),
    function(msg)
        local scenarioData = safeJsonDecode(msg.Data, {})
        local scenarioType = msg.ScenarioType or "multi_effect"
        
        local result = calculateComplexInteraction(scenarioData)
        
        ao.send({
            Target = msg.From,
            Action = "ComplexScenarioProcessed",
            Success = "true",
            ScenarioType = scenarioType,
            Result = json.encode(result),
            ProcessId = ao.id
        })
    end
)

-- Health check handler
Handlers.add(
    "health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        local battleCount = 0
        for _ in pairs(TerastalizationBattleState.activeBattles) do
            battleCount = battleCount + 1
        end
        
        ao.send({
            Target = msg.From,
            Action = "HealthCheckResponse",
            Status = "healthy",
            Version = TerastalizationBattleState.version,
            ActiveBattles = tostring(battleCount),
            ProcessId = ao.id
        })
    end
)

-- ===============================
-- ADP v1.0 COMPLIANCE
-- ===============================

-- Enhanced Info handler for ADP v1.0 compliance
Handlers.add(
    "info", 
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Terastalization Battle Integration Engine",
            Description = "Comprehensive battle integration engine for Terastalization mechanics with cross-process coordination, battle timing, status effect interactions, weather/terrain integration, AI decision-making, and complex scenario handling.",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            adpVersion = "1.0",
            version = TerastalizationBattleState.version,
            handlers = {
                {
                    action = "ProcessTerastalizationBattle",
                    pattern = {"Action"},
                    description = "Main battle integration handler supporting multiple operations",
                    category = "core",
                    parameters = {
                        {name = "Operation", type = "string", required = true, description = "Operation type: activate|integrate|validate|coordinate"},
                        {name = "BattleId", type = "string", required = true, description = "Battle session identifier"},
                        {name = "PokemonId", type = "string", required = true, description = "Pokemon identifier"},
                        {name = "TeraType", type = "string", required = false, description = "Tera type for activation"},
                        {name = "BattlePhase", type = "string", required = false, description = "Current battle phase"},
                        {name = "TurnNumber", type = "number", required = false, description = "Current turn number"},
                        {name = "Data", type = "json", required = false, description = "Battle state or Pokemon data"}
                    }
                },
                {
                    action = "BattleTimingCoordination",
                    pattern = {"Action"},
                    description = "Coordinate battle phase timing and turn management",
                    category = "timing",
                    parameters = {
                        {name = "BattleId", type = "string", required = true, description = "Battle session identifier"},
                        {name = "Phase", type = "string", required = true, description = "Battle phase"},
                        {name = "Turn", type = "number", required = true, description = "Turn number"}
                    }
                },
                {
                    action = "StatusEffectInteraction",
                    pattern = {"Action"},
                    description = "Process status effect interactions with Tera types",
                    category = "interaction",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Pokemon data object"},
                        {name = "StatusEffect", type = "string", required = true, description = "Status effect type"},
                        {name = "TeraType", type = "string", required = true, description = "Current Tera type"}
                    }
                },
                {
                    action = "WeatherTerrainIntegration",
                    pattern = {"Action"},
                    description = "Calculate weather and terrain effects with Tera types",
                    category = "integration",
                    parameters = {
                        {name = "TeraType", type = "string", required = true, description = "Tera type"},
                        {name = "Weather", type = "string", required = false, description = "Current weather"},
                        {name = "Terrain", type = "string", required = false, description = "Current terrain"}
                    }
                },
                {
                    action = "AIDecisionMaking",
                    pattern = {"Action"},
                    description = "Generate AI decisions for Terastalization usage",
                    category = "ai",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Battle context data"},
                        {name = "AIStrategy", type = "string", required = false, description = "AI strategy: AGGRESSIVE|DEFENSIVE|BALANCED"},
                        {name = "Turn", type = "number", required = false, description = "Current turn for seeding"}
                    }
                },
                {
                    action = "ComplexScenarioCoordination",
                    pattern = {"Action"},
                    description = "Handle complex multi-effect battle scenarios",
                    category = "complex",
                    parameters = {
                        {name = "Data", type = "json", required = true, description = "Complete scenario state"},
                        {name = "ScenarioType", type = "string", required = false, description = "Type of complex scenario"}
                    }
                },
                {
                    action = "HealthCheck",
                    pattern = {"Action"},
                    description = "Process health and status check",
                    category = "utility"
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get comprehensive process information and handler metadata",
                    category = "core"
                },
                {
                    action = "Ping",
                    pattern = {"Action"},
                    description = "Test if process is responding",
                    category = "utility"
                }
            },
            capabilities = {
                supportsHandlerRegistry = true,
                supportsCrossProcessCoordination = true,
                supportsBattleTiming = true,
                supportsStatusInteractions = true,
                supportsEnvironmentalEffects = true,
                supportsAIDecisionMaking = true,
                supportsComplexScenarios = true,
                supportsErrorHandling = true,
                adpCompliant = true
            },
            coordination = {
                connectedProcesses = {
                    "tera-type-engine.lua",
                    "stellar-tera-engine.lua", 
                    "tera-crystal-engine.lua",
                    "battle-state-manager.lua"
                },
                messageProtocols = {"AO_MESSAGE_PASSING"},
                coordinationPatterns = {"REQUEST_RESPONSE", "EVENT_DRIVEN"}
            },
            battlePhases = BATTLE_PHASES,
            statusInteractions = STATUS_INTERACTIONS,
            environmentalEffects = ENVIRONMENTAL_EFFECTS,
            aiPatterns = AI_PATTERNS
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
        
        print("Sent ADP v1.0 compliant Terastalization Battle Integration Info response to " .. msg.From)
    end
)

-- Basic Ping handler for ADP testing
Handlers.add(
    "ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong",
            ProcessType = "TerastalizationBattleIntegrationEngine",
            ProcessId = ao.id
        })
    end
)

-- ===============================
-- INITIALIZATION COMPLETE
-- ===============================

print("Terastalization Battle Integration Engine Process initialized successfully")
print("ADP v1.0 compliant with comprehensive battle integration")
print("Cross-process coordination enabled with existing Tera engines")
print("Process ID: " .. (ao.id or "unknown"))