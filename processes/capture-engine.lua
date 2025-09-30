-- Pokemon Capture Engine Process for PokéRogue AO
-- ADP v1.0 Compliant Process for capture probability calculations and mechanics
-- Handles deterministic capture attempts, Pokeball effectiveness, and status modifiers
-- Monolithic design - all dependencies embedded (no external imports)

-- ====================================
-- AO ENVIRONMENT GLOBALS
-- ====================================

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "capture-engine" }

-- Handlers global (AO runtime provides this)
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- ====================================
-- PROCESS CONFIGURATION
-- ====================================

local PROCESS_INFO = {
    name = "Pokemon Capture Engine",
    version = "1.0.0",
    adpVersion = "1.0",
    processId = "capture-engine",
    capabilities = {
        "calculateCaptureRate",
        "processCaptureAttempt", 
        "validateCaptureConditions",
        "deterministic_rng"
    },
    messageSchemas = {
        ProcessLogic = {
            required = {"Action", "Data", "Timestamp"},
            dataFields = {"gameState", "operation", "parameters"}
        },
        Info = {
            required = {"Action"},
            response = "process_metadata"
        },
        HealthCheck = {
            required = {"Action"},
            response = "status_report"
        }
    }
}

-- Performance and rate limiting
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}
local performanceStartTime = nil

-- ====================================
-- POKEBALL DATA AND CONSTANTS
-- ====================================

local POKEBALL_DATA = {
    pokeball = {
        name = "Poke Ball",
        catchRate = 1.0,
        bonusConditions = {}
    },
    greatball = {
        name = "Great Ball", 
        catchRate = 1.5,
        bonusConditions = {}
    },
    ultraball = {
        name = "Ultra Ball",
        catchRate = 2.0,
        bonusConditions = {}
    },
    rogueball = {
        name = "Rogue Ball",
        catchRate = 3.0,
        bonusConditions = {}
    },
    masterball = {
        name = "Master Ball",
        catchRate = 255.0, -- Guaranteed catch (-1 in TypeScript)
        bonusConditions = {}
    },
    netball = {
        name = "Net Ball",
        catchRate = 3.5,
        bonusConditions = {waterBug = true}
    },
    diveball = {
        name = "Dive Ball",
        catchRate = 3.5,
        bonusConditions = {underwater = true}
    },
    timerball = {
        name = "Timer Ball",
        catchRate = 1.0,
        bonusConditions = {timer = true}
    },
    quickball = {
        name = "Quick Ball",
        catchRate = 5.0,
        bonusConditions = {firstTurn = true}
    },
    duskball = {
        name = "Dusk Ball",
        catchRate = 3.5,
        bonusConditions = {darkTime = true}
    },
    repeatball = {
        name = "Repeat Ball",
        catchRate = 3.5,
        bonusConditions = {alreadyCaught = true}
    },
    luxuryball = {
        name = "Luxury Ball",
        catchRate = 1.0,
        bonusConditions = {friendship = true}
    },
    premierball = {
        name = "Premier Ball",
        catchRate = 1.0,
        bonusConditions = {}
    },
    healball = {
        name = "Heal Ball",
        catchRate = 1.0,
        bonusConditions = {heal = true}
    },
    levelball = {
        name = "Level Ball",
        catchRate = 1.0,
        bonusConditions = {levelDifference = true}
    },
    loveball = {
        name = "Love Ball",
        catchRate = 1.0,
        bonusConditions = {oppositeGender = true}
    },
    heavyball = {
        name = "Heavy Ball",
        catchRate = 1.0,
        bonusConditions = {heavyPokemon = true}
    },
    fastball = {
        name = "Fast Ball",
        catchRate = 1.0,
        bonusConditions = {fastPokemon = true}
    },
    friendball = {
        name = "Friend Ball",
        catchRate = 1.0,
        bonusConditions = {friendship = true}
    },
    lureball = {
        name = "Lure Ball",
        catchRate = 1.0,
        bonusConditions = {fishing = true}
    },
    moonball = {
        name = "Moon Ball",
        catchRate = 1.0,
        bonusConditions = {moonStone = true}
    },
    sportball = {
        name = "Sport Ball",
        catchRate = 1.5,
        bonusConditions = {bugCatching = true}
    },
    safariball = {
        name = "Safari Ball",
        catchRate = 1.5,
        bonusConditions = {safari = true}
    },
    dreamball = {
        name = "Dream Ball",
        catchRate = 1.0,
        bonusConditions = {dreamWorld = true}
    },
    beastball = {
        name = "Beast Ball",
        catchRate = 0.1,
        bonusConditions = {ultraBeast = true, ultraBeastMultiplier = 5.0}
    }
}

-- Status effect multipliers for capture rate (TypeScript parity)
local STATUS_EFFECT_MULTIPLIERS = {
    none = 1.0,
    sleep = 2.5,
    freeze = 2.5,
    paralysis = 1.5,
    burn = 1.5,
    poison = 1.5,
    toxic = 1.5, -- TypeScript uses TOXIC instead of badly_poison
    badly_poison = 1.5, -- Keep for backwards compatibility
    confusion = 1.0, -- Confusion doesn't affect capture rate
    faint = 0.0 -- Cannot catch fainted Pokemon
}

-- Ability effects on capture rates and mechanics
local ABILITY_CAPTURE_EFFECTS = {
    -- Abilities that reduce capture rate (target Pokemon)
    pressure = {
        type = "capture_rate_modifier",
        multiplier = 0.5,
        description = "Reduces capture rate by 50%"
    },
    intimidate = {
        type = "capture_rate_modifier",
        multiplier = 1.1,
        description = "Slightly increases capture rate due to intimidation"
    },
    
    -- Abilities that affect status application and capture
    magic_guard = {
        type = "status_immunity",
        blockedStatuses = {"poison", "burn"},
        description = "Blocks certain status effects that would increase capture rate"
    },
    natural_cure = {
        type = "status_cure",
        activationTrigger = "capture_attempt",
        description = "May cure status effects during capture attempts"
    },
    
    -- Player abilities that improve capture rates
    compound_eyes = {
        type = "critical_capture_bonus",
        multiplier = 1.3,
        description = "Increases critical capture chance by 30%"
    },
    keen_eye = {
        type = "accuracy_bonus",
        effect = "pokeball_accuracy",
        description = "Improves pokeball throwing accuracy"
    },
    
    -- Abilities that affect specific pokeball types
    static = {
        type = "pokeball_type_bonus",
        affectedBalls = {"quickball"},
        multiplier = 1.2,
        description = "Slight bonus to electric-themed pokeballs"
    },
    flash_fire = {
        type = "status_resistance",
        resistedStatus = "burn",
        description = "Prevents burn status that would increase capture rate"
    },
    
    -- Abilities that affect flee behavior
    run_away = {
        type = "flee_modifier",
        multiplier = 2.0,
        description = "Doubles flee rate after failed capture attempts"
    },
    arena_trap = {
        type = "prevent_flee",
        description = "Prevents wild Pokemon from fleeing after failed captures"
    },
    shadow_tag = {
        type = "prevent_flee",
        description = "Prevents wild Pokemon from fleeing after failed captures"
    },
    magnet_pull = {
        type = "prevent_flee",
        targetTypes = {"steel"},
        description = "Prevents Steel-type Pokemon from fleeing"
    },
    
    -- Complex abilities with special effects
    trace = {
        type = "copy_ability",
        description = "Copies target's ability, including capture-affecting abilities"
    },
    skill_swap = {
        type = "swap_ability",
        description = "Swaps abilities, potentially affecting capture mechanics"
    }
}

-- Item effects on capture rates
local ITEM_CAPTURE_EFFECTS = {
    -- Player held items
    catching_charm = {
        type = "critical_capture_bonus",
        multiplier = 1.5,
        description = "Increases critical capture chance"
    },
    pokeball_plus = {
        type = "pokeball_effectiveness",
        ballTypeBonus = 1.2,
        description = "Increases all pokeball effectiveness by 20%"
    },
    
    -- Pokemon held items that affect capture
    quick_claw = {
        type = "escape_bonus",
        fleeRateMultiplier = 1.3,
        description = "Increases flee rate after failed captures"
    },
    bright_powder = {
        type = "capture_evasion",
        evasionBonus = 0.1,
        description = "10% chance to avoid capture entirely"
    },
    
    -- Berries that affect capture indirectly
    oran_berry = {
        type = "hp_restore",
        effect = "reduces_low_hp_capture_bonus",
        description = "Restores HP, reducing low-HP capture bonus"
    },
    pecha_berry = {
        type = "status_cure",
        curedStatus = "poison",
        description = "Cures poison, removing status capture bonus"
    }
}

-- ====================================
-- UTILITY FUNCTIONS
-- ====================================

-- Deep copy utility for immutable state management
local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = deepCopy(value)
    end
    return copy
end

-- Apply ability and item effects to capture calculations
local function applyAbilityAndItemEffects(pokemon, battleConditions, captureRate, criticalCaptureChance)
    local modifiedCaptureRate = captureRate
    local modifiedCriticalChance = criticalCaptureChance
    local abilityEffects = {}
    
    -- Process Pokemon abilities
    if pokemon.abilities then
        for _, ability in ipairs(pokemon.abilities) do
            local abilityEffect = ABILITY_CAPTURE_EFFECTS[ability]
            if abilityEffect then
                if abilityEffect.type == "capture_rate_modifier" then
                    modifiedCaptureRate = modifiedCaptureRate * abilityEffect.multiplier
                    table.insert(abilityEffects, {
                        ability = ability,
                        effect = abilityEffect.description,
                        modifier = abilityEffect.multiplier
                    })
                elseif abilityEffect.type == "critical_capture_bonus" then
                    modifiedCriticalChance = modifiedCriticalChance * abilityEffect.multiplier
                    table.insert(abilityEffects, {
                        ability = ability,
                        effect = abilityEffect.description,
                        modifier = abilityEffect.multiplier
                    })
                end
            end
        end
    end
    
    -- Process player abilities (if available)
    if battleConditions.playerAbilities then
        for _, ability in ipairs(battleConditions.playerAbilities) do
            local abilityEffect = ABILITY_CAPTURE_EFFECTS[ability]
            if abilityEffect then
                if abilityEffect.type == "critical_capture_bonus" then
                    modifiedCriticalChance = modifiedCriticalChance * abilityEffect.multiplier
                    table.insert(abilityEffects, {
                        ability = ability,
                        effect = abilityEffect.description,
                        source = "player",
                        modifier = abilityEffect.multiplier
                    })
                end
            end
        end
    end
    
    -- Process held items
    if pokemon.heldItem then
        local itemEffect = ITEM_CAPTURE_EFFECTS[pokemon.heldItem]
        if itemEffect then
            if itemEffect.type == "capture_evasion" then
                -- Special handling for evasion items
                table.insert(abilityEffects, {
                    item = pokemon.heldItem,
                    effect = itemEffect.description,
                    evasionChance = itemEffect.evasionBonus
                })
            elseif itemEffect.type == "escape_bonus" then
                table.insert(abilityEffects, {
                    item = pokemon.heldItem,
                    effect = itemEffect.description,
                    fleeModifier = itemEffect.fleeRateMultiplier
                })
            end
        end
    end
    
    -- Process player held items
    if battleConditions.playerHeldItem then
        local itemEffect = ITEM_CAPTURE_EFFECTS[battleConditions.playerHeldItem]
        if itemEffect then
            if itemEffect.type == "critical_capture_bonus" then
                modifiedCriticalChance = modifiedCriticalChance * itemEffect.multiplier
                table.insert(abilityEffects, {
                    item = battleConditions.playerHeldItem,
                    effect = itemEffect.description,
                    source = "player",
                    modifier = itemEffect.multiplier
                })
            elseif itemEffect.type == "pokeball_effectiveness" then
                modifiedCaptureRate = modifiedCaptureRate * itemEffect.ballTypeBonus
                table.insert(abilityEffects, {
                    item = battleConditions.playerHeldItem,
                    effect = itemEffect.description,
                    source = "player",
                    modifier = itemEffect.ballTypeBonus
                })
            end
        end
    end
    
    return {
        captureRate = math.max(0, math.min(255, modifiedCaptureRate)),
        criticalCaptureChance = math.max(0, math.min(255, modifiedCriticalChance)),
        abilityEffects = abilityEffects
    }
end

-- GameState integrity validation
local function validateGameState(gameState)
    if type(gameState) ~= "table" then
        return false, "GameState must be a table"
    end
    
    local requiredFields = {"playerId", "timestamp", "version"}
    for _, field in ipairs(requiredFields) do
        if not gameState[field] then
            return false, "GameState missing required field: " .. field
        end
    end
    
    if gameState.player then
        if not gameState.player.party or type(gameState.player.party) ~= "table" then
            return false, "GameState.player.party must be a table"
        end
    end
    
    if gameState.battle then
        if not gameState.battle.battleId or not gameState.battle.battleSeed then
            return false, "GameState.battle must have battleId and battleSeed"
        end
    end
    
    return true, nil
end

-- Input validation for capture operations
local function validateInput(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    
    if not message.Action or type(message.Action) ~= "string" then
        return false, "Action field is required and must be a string"
    end
    
    if not message.Data or type(message.Data) ~= "table" then
        return false, "Data field is required and must be a table"
    end
    
    if not message.Timestamp or type(message.Timestamp) ~= "number" then
        return false, "Timestamp field is required and must be a number"
    end
    
    if not message.Data.gameState then
        return false, "Data.gameState is required for capture operations"
    end
    
    if not message.Data.operation or type(message.Data.operation) ~= "string" then
        return false, "Data.operation is required and must be a string"
    end
    
    local gameStateValid, gameStateError = validateGameState(message.Data.gameState)
    if not gameStateValid then
        return false, "Invalid GameState: " .. gameStateError
    end
    
    return true, nil
end

-- Rate limiting protection
local function checkRateLimit(address)
    local currentTime = msg and msg.Timestamp or 0
    local currentMinute = math.floor(currentTime / 60)
    
    if not rateLimitCounters[address] then
        rateLimitCounters[address] = {minute = currentMinute, count = 0}
    end
    
    local counter = rateLimitCounters[address]
    
    if counter.minute ~= currentMinute then
        counter.minute = currentMinute
        counter.count = 0
    end
    
    if counter.count >= RATE_LIMIT_MAX then
        return false, "Rate limit exceeded: maximum " .. RATE_LIMIT_MAX .. " operations per minute"
    end
    
    counter.count = counter.count + 1
    return true, nil
end

-- Performance monitoring
local function startPerformanceMonitoring()
    performanceStartTime = os.clock()
end

local function endPerformanceMonitoring()
    if performanceStartTime then
        local responseTime = (os.clock() - performanceStartTime) * 1000
        performanceStartTime = nil
        return responseTime
    end
    return nil
end

-- ====================================
-- DETERMINISTIC RNG SYSTEM
-- ====================================

-- Initialize deterministic RNG using battle seed
local function initializeRNG(battleSeed)
    if not battleSeed or type(battleSeed) ~= "string" then
        return nil, "Battle seed is required for deterministic RNG"
    end
    
    local seedValue = 0
    for i = 1, #battleSeed do
        seedValue = seedValue + string.byte(battleSeed, i) * i
    end
    
    return {seed = seedValue, counter = 0}, nil
end

-- Generate next deterministic random number
local function nextRandom(rngState, min, max)
    if not rngState then
        error("RNG state is required for deterministic random generation")
    end
    
    rngState.counter = rngState.counter + 1
    
    -- Linear congruential generator parameters
    local a = 1664525
    local c = 1013904223
    local m = 2^32
    
    rngState.seed = (a * rngState.seed + c + rngState.counter) % m
    local random = rngState.seed / m
    
    if min and max then
        return math.floor(random * (max - min + 1)) + min
    else
        return random
    end
end

-- ====================================
-- CAPTURE ENGINE CORE LOGIC
-- ====================================

local CaptureEngine = {}

-- Calculate comprehensive capture rate based on all factors (TypeScript Parity)
function CaptureEngine.calculateCaptureRate(pokemon, pokeballType, battleConditions, rngState)
    -- Use exact TypeScript variable names and formula
    local _3m = 3 * (pokemon.maxHp or 100)
    local _2h = 2 * math.max(1, pokemon.hp) -- Prevent division by zero
    local catchRate = pokemon.catchRate or 45 -- Default species catch rate
    local ballData = POKEBALL_DATA[pokeballType] or POKEBALL_DATA.pokeball
    
    -- Apply pokeball multiplier with TypeScript parity logic
    local pokeballMultiplier = ballData.catchRate
    
    -- Handle Master Ball special case (-1 in TypeScript indicates guaranteed capture)
    if pokeballType == "masterball" then
        pokeballMultiplier = -1
    end
    
    -- Apply pokeball-specific bonuses with comprehensive conditional logic
    if ballData.bonusConditions then
        -- Net Ball bonus for Water/Bug types (3.5x when conditions met, 1x otherwise)
        if ballData.bonusConditions.waterBug then
            if pokemon.type1 == "water" or pokemon.type1 == "bug" or 
               pokemon.type2 == "water" or pokemon.type2 == "bug" then
                -- NetBall condition met, use full 3.5x multiplier
            else
                -- NetBall condition not met, reduce to 1x
                pokeballMultiplier = 1.0
            end
        end
        
        -- Quick Ball bonus on first turn (5.0x on turn 1, 1x otherwise)
        if ballData.bonusConditions.firstTurn then
            if battleConditions.turn ~= 1 then
                pokeballMultiplier = 1.0
            end
        end
        
        -- Timer Ball bonus increases with turn count (1.0x to 4.0x)
        if ballData.bonusConditions.timer and battleConditions.turn then
            local timerMultiplier = math.min(4.0, 1.0 + (battleConditions.turn - 1) * 0.1)
            pokeballMultiplier = timerMultiplier
        end
        
        -- Dusk Ball bonus in caves or at night (3.5x when dark, 1x otherwise)
        if ballData.bonusConditions.darkTime then
            if not (battleConditions.environment == "cave" or battleConditions.timeOfDay == "night") then
                pokeballMultiplier = 1.0
            end
        end
        
        -- Repeat Ball bonus if species already caught (3.5x if caught, 1x otherwise)
        if ballData.bonusConditions.alreadyCaught then
            if not battleConditions.pokedexCaught then
                pokeballMultiplier = 1.0
            end
        end
        
        -- Dive Ball bonus for underwater encounters (3.5x underwater, 1x otherwise)
        if ballData.bonusConditions.underwater then
            if battleConditions.environment ~= "underwater" then
                pokeballMultiplier = 1.0
            end
        end
        
        -- Level Ball effectiveness based on level difference (2x-8x scaling)
        if ballData.bonusConditions.levelDifference and battleConditions.playerLevel and pokemon.level then
            local levelDiff = battleConditions.playerLevel - pokemon.level
            if levelDiff >= 20 then
                pokeballMultiplier = 8.0
            elseif levelDiff >= 10 then
                pokeballMultiplier = 4.0
            elseif levelDiff >= 5 then
                pokeballMultiplier = 2.0
            else
                pokeballMultiplier = 1.0
            end
        end
        
        -- Love Ball effectiveness for opposite gender (8x opposite gender, 1x otherwise)
        if ballData.bonusConditions.oppositeGender and battleConditions.playerGender and pokemon.gender then
            if (battleConditions.playerGender == "male" and pokemon.gender == "female") or
               (battleConditions.playerGender == "female" and pokemon.gender == "male") then
                pokeballMultiplier = 8.0
            else
                pokeballMultiplier = 1.0
            end
        end
        
        -- Heavy Ball effectiveness based on Pokemon weight
        if ballData.bonusConditions.heavyPokemon and pokemon.weight then
            if pokemon.weight >= 300 then
                pokeballMultiplier = 30.0 -- +20 bonus
            elseif pokemon.weight >= 200 then
                pokeballMultiplier = 20.0 -- +0 bonus (neutral)
            else
                pokeballMultiplier = 1.0 -- Penalty for light Pokemon
            end
        end
        
        -- Fast Ball effectiveness for high-speed Pokemon
        if ballData.bonusConditions.fastPokemon and pokemon.baseSpeed then
            if pokemon.baseSpeed >= 100 then
                pokeballMultiplier = 4.0
            else
                pokeballMultiplier = 1.0
            end
        end
        
        -- Beast Ball effectiveness (0.1x normally, 5.0x for Ultra Beasts)
        if ballData.bonusConditions.ultraBeast then
            if pokemon.isUltraBeast then
                pokeballMultiplier = ballData.bonusConditions.ultraBeastMultiplier or 5.0
            -- Beast Ball already has 0.1x base rate for non-Ultra Beasts
            end
        end
        
        -- Moon Ball effectiveness for Pokemon that evolve with Moon Stone
        if ballData.bonusConditions.moonStone and pokemon.evolvesWithMoonStone then
            pokeballMultiplier = 4.0
        end
        
        -- Lure Ball effectiveness for Pokemon caught while fishing
        if ballData.bonusConditions.fishing and battleConditions.encounterMethod == "fishing" then
            pokeballMultiplier = 4.0
        end
    end
    
    -- Apply status effect multiplier (exact TypeScript values)
    local statusMultiplier = 1
    if pokemon.statusEffect then
        statusMultiplier = STATUS_EFFECT_MULTIPLIERS[pokemon.statusEffect] or 1
    end
    
    -- Master Ball guaranteed capture
    if pokeballMultiplier == -1 then
        return {
            captureValue = 255,
            probability = 1.0,
            hpFactor = _3m,
            ballModifier = pokeballMultiplier,
            statusMultiplier = statusMultiplier,
            finalRate = 255,
            pokeball = pokeballType,
            validCapture = statusMultiplier > 0
        }
    end
    
    -- Calculate exact TypeScript formula:
    -- modifiedCatchRate = Math.round((((_3m - _2h) * catchRate * pokeballMultiplier) / _3m) * statusMultiplier)
    local baseCatchRate = math.floor(((_3m - _2h) * catchRate * pokeballMultiplier / _3m) * statusMultiplier + 0.5)
    baseCatchRate = math.min(255, math.max(0, baseCatchRate))
    
    -- Apply ability and item effects
    local abilityResults = applyAbilityAndItemEffects(pokemon, battleConditions, baseCatchRate, 0)
    local modifiedCatchRate = abilityResults.captureRate
    
    return {
        captureValue = modifiedCatchRate,
        probability = modifiedCatchRate / 255,
        hpFactor = (_3m - _2h) / _3m,
        ballModifier = pokeballMultiplier,
        statusMultiplier = statusMultiplier,
        finalRate = modifiedCatchRate,
        pokeball = pokeballType,
        validCapture = statusMultiplier > 0 and modifiedCatchRate > 0,
        abilityEffects = abilityResults.abilityEffects
    }
end

-- Process capture attempt with shake mechanics (Gen 6 Formula - TypeScript Parity)
function CaptureEngine.attemptCapture(captureRate, rngState, pokedexData)
    local modifiedCatchRate = math.min(255, captureRate.captureValue)
    
    -- Master Ball always succeeds
    if captureRate.pokeball == "masterball" or modifiedCatchRate >= 255 then
        return {
            success = true,
            criticalCapture = false,
            shakeCount = 0,
            captureValue = modifiedCatchRate,
            guaranteed = true
        }
    end
    
    -- Calculate critical capture chance using TypeScript parity formula
    local criticalCaptureChance = 0
    if pokedexData then
        local dexCount = pokedexData.speciesCaught or 0
        local catchingCharmMultiplier = pokedexData.catchingCharmMultiplier or 1
        local dexMultiplier = 
            dexCount > 800 and 2.5 or
            dexCount > 600 and 2 or
            dexCount > 400 and 1.5 or
            dexCount > 200 and 1 or
            dexCount > 100 and 0.5 or 0
        
        criticalCaptureChance = math.floor((catchingCharmMultiplier * dexMultiplier * modifiedCatchRate) / 6)
    end
    
    local criticalRoll = nextRandom(rngState, 0, 255)
    local criticalCapture = criticalRoll < criticalCaptureChance
    
    -- Calculate shake probability using exact Gen 6 TypeScript formula
    -- shakeProbability = Math.round(65536 / Math.pow(255 / modifiedCatchRate, 0.1875))
    local shakeProbability = math.floor(65536 / math.pow(255 / modifiedCatchRate, 0.1875) + 0.5)
    
    if criticalCapture then
        -- Critical capture: only 1 shake check
        local shakeRoll = nextRandom(rngState, 0, 65535)
        local success = shakeRoll < shakeProbability
        return {
            success = success,
            criticalCapture = true,
            shakeCount = success and 1 or 0,
            captureValue = modifiedCatchRate,
            guaranteed = false,
            shakeProbability = shakeProbability
        }
    end
    
    -- Normal capture with shake calculation (up to 3 shakes)
    local shakeCount = 0
    local success = true
    
    for shake = 1, 3 do
        local shakeRoll = nextRandom(rngState, 0, 65535)
        
        if shakeRoll < shakeProbability then
            shakeCount = shake
        else
            success = false
            break
        end
    end
    
    -- If all 3 shakes succeed, capture succeeds
    if shakeCount == 3 then
        success = true
    end
    
    return {
        success = success,
        criticalCapture = false,
        shakeCount = shakeCount,
        captureValue = modifiedCatchRate,
        guaranteed = false,
        shakeProbability = shakeProbability
    }
end

-- Validate capture conditions before attempt
function CaptureEngine.validateCaptureConditions(pokemon, gameState, battleConditions)
    local errors = {}
    
    -- Check if Pokemon is fainted
    if pokemon.hp <= 0 then
        table.insert(errors, "Cannot capture a fainted Pokemon")
    end
    
    -- Check if it's a trainer Pokemon
    if pokemon.isTrainerPokemon then
        table.insert(errors, "Cannot capture trainer Pokemon")
    end
    
    -- Check if player has pokeballs
    if gameState.player and gameState.player.inventory then
        local hasPokeballs = false
        for item, count in pairs(gameState.player.inventory) do
            if POKEBALL_DATA[item] and count > 0 then
                hasPokeballs = true
                break
            end
        end
        if not hasPokeballs then
            table.insert(errors, "No pokeballs available in inventory")
        end
    end
    
    -- Check battle state
    if battleConditions and battleConditions.battleEnded then
        table.insert(errors, "Cannot capture Pokemon after battle has ended")
    end
    
    return #errors == 0, errors
end

-- Calculate Pokemon behavior after failed capture attempt
function CaptureEngine.calculateFailedCaptureBehavior(pokemon, captureResult, battleConditions, rngState)
    -- Base flee rate depends on species and battle conditions
    local baseFleRate = pokemon.fleRate or 10 -- Default 10% flee rate
    
    -- Modify flee rate based on capture attempt factors
    local fleeModifier = 1.0
    
    -- Pokemon more likely to flee after multiple failed captures
    if battleConditions.failedCaptureAttempts then
        fleeModifier = fleeModifier + (battleConditions.failedCaptureAttempts * 0.15)
    end
    
    -- Pokemon more likely to flee if severely wounded
    local hpPercentage = pokemon.hp / (pokemon.maxHp or 100)
    if hpPercentage < 0.25 then
        fleeModifier = fleeModifier + 0.3 -- 30% increase when under 25% HP
    elseif hpPercentage < 0.5 then
        fleeModifier = fleeModifier + 0.15 -- 15% increase when under 50% HP
    end
    
    -- Status effects affect flee behavior
    if pokemon.statusEffect then
        if pokemon.statusEffect == "sleep" or pokemon.statusEffect == "freeze" then
            fleeModifier = fleeModifier * 0.1 -- Much less likely to flee when asleep/frozen
        elseif pokemon.statusEffect == "paralysis" then
            fleeModifier = fleeModifier * 0.5 -- Half as likely to flee when paralyzed
        end
    end
    
    -- Environmental factors
    if battleConditions.environment == "cave" then
        fleeModifier = fleeModifier * 0.8 -- Slightly less likely to flee in caves
    elseif battleConditions.environment == "open_field" then
        fleeModifier = fleeModifier * 1.2 -- More likely to flee in open areas
    end
    
    -- Calculate final flee probability
    local finalFleeRate = math.min(95, baseFleRate * fleeModifier) -- Cap at 95%
    local fleeRoll = nextRandom(rngState, 1, 100)
    local willFlee = fleeRoll <= finalFleeRate
    
    -- Determine Pokemon's action if it doesn't flee
    local action = "continue_battle"
    if not willFlee then
        -- 70% chance to attack, 20% to use status move, 10% to do nothing
        local actionRoll = nextRandom(rngState, 1, 100)
        if actionRoll <= 70 then
            action = "attack"
        elseif actionRoll <= 90 then
            action = "status_move"
        else
            action = "wait"
        end
    else
        action = "flee"
    end
    
    return {
        willFlee = willFlee,
        fleeRate = finalFleeRate,
        action = action,
        hpPreserved = pokemon.hp,
        statusPreserved = pokemon.statusEffect,
        battleContinues = not willFlee
    }
end

-- Add captured Pokemon to party or PC storage
function CaptureEngine.addPokemonToParty(gameState, capturedPokemon)
    local newGameState = deepCopy(gameState)
    
    -- Ensure player structure exists
    if not newGameState.player then
        newGameState.player = {party = {}}
    end
    if not newGameState.player.party then
        newGameState.player.party = {}
    end
    
    -- Check if party has space (max 6 Pokemon)
    if #newGameState.player.party < 6 then
        table.insert(newGameState.player.party, capturedPokemon)
        return newGameState, "party"
    else
        -- Add to PC storage
        if not newGameState.player.pcStorage then
            newGameState.player.pcStorage = {}
        end
        table.insert(newGameState.player.pcStorage, capturedPokemon)
        return newGameState, "pc"
    end
end

-- Process complete capture attempt with all mechanics
function CaptureEngine.processCaptureAttempt(gameState, pokeballType, targetPokemon, battleConditions, rngState)
    -- 1. COORDINATE: Validate Pokemon state with pokemon-instance-manager
    if battleConditions.pokemonId then
        ao.send({
            Target = battleConditions.pokemonInstanceManagerId or "pokemon-instance-manager",
            Action = "ValidatePokemon",
            PokemonId = battleConditions.pokemonId,
            Operation = "status_check",
            Data = json.encode({
                battleId = battleConditions.battleId or "unknown",
                validateHP = true,
                validateStatus = true,
                timestamp = (msg.Timestamp or 0)
            })
        })
    end
    
    -- 2. COORDINATE: Get battle context from battle-engine
    if battleConditions.battleId then
        ao.send({
            Target = battleConditions.battleEngineId or "battle-engine",
            Action = "QueryBattleState", 
            BattleId = battleConditions.battleId,
            Data = json.encode({
                queryType = "capture_context",
                turnInfo = true,
                environmentalConditions = true,
                timestamp = (msg.Timestamp or 0)
            })
        })
    end
    
    -- 3. COORDINATE: Consume Pokeball from inventory-manager
    ao.send({
        Target = battleConditions.inventoryManagerId or "inventory-manager",
        Action = "ConsumeItem",
        ItemType = pokeballType,
        Quantity = "1",
        PlayerId = gameState.playerId or "unknown",
        Data = json.encode({
            reason = "pokeball_usage",
            battleId = battleConditions.battleId or "unknown",
            captureAttempt = true,
            timestamp = (msg.Timestamp or 0)
        })
    })
    
    -- Validate capture conditions
    local isValid, validationErrors = CaptureEngine.validateCaptureConditions(targetPokemon, gameState, battleConditions)
    if not isValid then
        error("Capture validation failed: " .. table.concat(validationErrors, ", "))
    end
    
    -- Calculate capture rate with all modifiers
    local captureRate = CaptureEngine.calculateCaptureRate(targetPokemon, pokeballType, battleConditions, rngState)
    
    -- Attempt capture with shake mechanics (pass pokedex data from game state)
    local pokedexData = gameState.player and gameState.player.pokedex or {speciesCaught = 0}
    local captureResult = CaptureEngine.attemptCapture(captureRate, rngState, pokedexData)
    
    if captureResult.success then
        -- Create captured Pokemon with metadata
        local capturedPokemon = deepCopy(targetPokemon)
        capturedPokemon.originalTrainer = gameState.playerId
        capturedPokemon.captureDate = msg and msg.Timestamp or 0
        capturedPokemon.pokeball = pokeballType
        capturedPokemon.captureLocation = battleConditions.location or "unknown"
        capturedPokemon.captureLevel = targetPokemon.level
        
        -- Add to party or PC
        local updatedGameState, location = CaptureEngine.addPokemonToParty(gameState, capturedPokemon)
        
        -- 4. COORDINATE: Transfer Pokemon to player collection
        if battleConditions.pokemonId then
            ao.send({
                Target = battleConditions.pokemonInstanceManagerId or "pokemon-instance-manager",
                Action = "TransferPokemon",
                PokemonId = battleConditions.pokemonId,
                Operation = "wild_to_player",
                PlayerId = gameState.playerId or "unknown",
                Data = json.encode({
                    captureMethod = pokeballType,
                    captureLocation = battleConditions.location or "unknown",
                    captureDate = msg and msg.Timestamp or (msg.Timestamp or 0),
                    partySlot = location == "party" and #updatedGameState.player.party or nil,
                    timestamp = (msg.Timestamp or 0)
                })
            })
        end
        
        -- 5. COORDINATE: Notify battle engine of capture success
        if battleConditions.battleId then
            ao.send({
                Target = battleConditions.battleEngineId or "battle-engine",
                Action = "CaptureResult",
                BattleId = battleConditions.battleId,
                Success = "true",
                Data = json.encode({
                    capturedPokemon = battleConditions.pokemonId,
                    captureMethod = pokeballType,
                    shakeCount = captureResult.shakeCount,
                    criticalCapture = captureResult.criticalCapture,
                    timestamp = (msg.Timestamp or 0)
                })
            })
        end
        
        -- Update player inventory (remove used pokeball) - local state only
        if updatedGameState.player.inventory and updatedGameState.player.inventory[pokeballType] then
            updatedGameState.player.inventory[pokeballType] = 
                math.max(0, updatedGameState.player.inventory[pokeballType] - 1)
        end
        
        return {
            gameState = updatedGameState,
            captureSuccess = true,
            captureResult = captureResult,
            captureRate = captureRate,
            storageLocation = location,
            capturedPokemon = capturedPokemon
        }
    else
        -- Failed capture coordination and behavior
        
        -- 6. COORDINATE: Notify battle engine of capture failure
        if battleConditions.battleId then
            ao.send({
                Target = battleConditions.battleEngineId or "battle-engine",
                Action = "CaptureResult",
                BattleId = battleConditions.battleId,
                Success = "false",
                Data = json.encode({
                    targetPokemon = battleConditions.pokemonId,
                    failureReason = "capture_failed",
                    shakeCount = captureResult.shakeCount,
                    ballUsed = pokeballType,
                    timestamp = (msg.Timestamp or 0)
                })
            })
        end
        
        -- Calculate Pokemon behavior after failed capture
        local pokemonBehavior = CaptureEngine.calculateFailedCaptureBehavior(targetPokemon, captureResult, battleConditions, rngState)
        
        -- 7. COORDINATE: Update Pokemon behavior in pokemon-instance-manager
        if battleConditions.pokemonId and pokemonBehavior.willFlee then
            ao.send({
                Target = battleConditions.pokemonInstanceManagerId or "pokemon-instance-manager",
                Action = "UpdatePokemonBehavior",
                PokemonId = battleConditions.pokemonId,
                Data = json.encode({
                    behavior = "flee",
                    fleeRate = pokemonBehavior.fleeRate,
                    reason = "failed_capture",
                    battleId = battleConditions.battleId or "unknown",
                    timestamp = (msg.Timestamp or 0)
                })
            })
        end
        
        -- Failed capture - only remove pokeball from inventory (local state)
        local updatedGameState = deepCopy(gameState)
        if updatedGameState.player.inventory and updatedGameState.player.inventory[pokeballType] then
            updatedGameState.player.inventory[pokeballType] = 
                math.max(0, updatedGameState.player.inventory[pokeballType] - 1)
        end
        
        return {
            gameState = updatedGameState,
            captureSuccess = false,
            captureResult = captureResult,
            captureRate = captureRate,
            storageLocation = nil,
            capturedPokemon = nil,
            pokemonBehavior = pokemonBehavior
        }
    end
end

-- Main operation handler
function CaptureEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "calculateCaptureRate" then
        local pokemon = parameters.pokemon
        local pokeballType = parameters.pokeballType
        local battleConditions = parameters.battleConditions or {}
        
        if not pokemon or not pokeballType then
            error("pokemon and pokeballType parameters are required for calculateCaptureRate operation")
        end
        
        local captureRate = CaptureEngine.calculateCaptureRate(pokemon, pokeballType, battleConditions, rngState)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            captureRate = captureRate
        }
        
    elseif operation == "processCaptureAttempt" then
        local pokeballType = parameters.pokeballType
        local targetPokemon = parameters.targetPokemon
        local battleConditions = parameters.battleConditions or {}
        
        if not pokeballType or not targetPokemon then
            error("pokeballType and targetPokemon parameters are required for processCaptureAttempt operation")
        end
        
        return CaptureEngine.processCaptureAttempt(gameState, pokeballType, targetPokemon, battleConditions, rngState)
        
    elseif operation == "validateCaptureConditions" then
        local pokemon = parameters.pokemon
        local battleConditions = parameters.battleConditions or {}
        
        if not pokemon then
            error("pokemon parameter is required for validateCaptureConditions operation")
        end
        
        local isValid, errors = CaptureEngine.validateCaptureConditions(pokemon, gameState, battleConditions)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            validationResult = {
                isValid = isValid,
                errors = errors
            }
        }
        
    else
        error("Unknown capture engine operation: " .. operation)
    end
end

-- ====================================
-- MESSAGE PROCESSING
-- ====================================

local function handleMessage(message)
    startPerformanceMonitoring()
    
    local isValid, validationError = validateInput(message)
    if not isValid then
        return {
            Action = "SaveState",
            Error = validationError,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
    
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
    if not rateLimitOk then
        return {
            Action = "SaveState",
            Error = rateLimitError,
            GameState = message.Data.gameState,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
    
    local originalGameState = message.Data.gameState
    local operation = message.Data.operation
    local parameters = message.Data.parameters or {}
    
    -- Initialize deterministic RNG if battle seed available
    local rngState = nil
    if originalGameState.battle and originalGameState.battle.battleSeed then
        local rngInitSuccess, rngError = initializeRNG(originalGameState.battle.battleSeed)
        if not rngInitSuccess then
            return {
                Action = "SaveState",
                Error = "RNG initialization failed: " .. rngError,
                GameState = originalGameState,
                ProcessId = PROCESS_INFO.processId,
                Timestamp = msg and msg.Timestamp or 0
            }
        end
        rngState = rngInitSuccess
    end
    
    local result = CaptureEngine.handleLogicOperation(originalGameState, operation, parameters, rngState)
    
    local responseTime = endPerformanceMonitoring()
    if responseTime and responseTime > LOGIC_OPERATION_TIMEOUT then
        return {
            Action = "SaveState",
            Error = "Logic operation exceeded " .. LOGIC_OPERATION_TIMEOUT .. "ms timeout (took " .. responseTime .. "ms)",
            GameState = originalGameState,
            ProcessId = PROCESS_INFO.processId,
            Timestamp = msg and msg.Timestamp or 0
        }
    end
    
    if result and result.gameState then
        result.gameState.timestamp = msg and msg.Timestamp or 0
        if originalGameState.version then
            result.gameState.version = (originalGameState.version or 0) + 1
        end
    end
    
    return {
        Action = "SaveState",
        Data = {
            gameState = result and result.gameState or originalGameState,
            result = result
        },
        Timestamp = msg and msg.Timestamp or 0,
        ProcessId = PROCESS_INFO.processId
    }
end

-- ====================================
-- AO MESSAGE HANDLERS (ADP v1.0 COMPLIANT)
-- ====================================

-- ADP v1.0 Info Handler (REQUIRED)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = PROCESS_INFO.name,
                    version = PROCESS_INFO.version,
                    adpVersion = PROCESS_INFO.adpVersion,
                    processId = ao.id,
                    capabilities = PROCESS_INFO.capabilities,
                    messageSchemas = PROCESS_INFO.messageSchemas
                },
                handlers = {"ProcessLogic", "HealthCheck", "Info"},
                pokeballs = {
                    supported = {},
                    statusEffects = {}
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Pokemon capture engine with comprehensive mechanics including HP, status effects, pokeball modifiers, and deterministic RNG"
                }
            }
        })
        
        -- Populate pokeball data for documentation
        local response = {
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = {
                    name = PROCESS_INFO.name,
                    version = PROCESS_INFO.version,
                    adpVersion = PROCESS_INFO.adpVersion,
                    processId = ao.id,
                    capabilities = PROCESS_INFO.capabilities,
                    messageSchemas = PROCESS_INFO.messageSchemas
                },
                handlers = {"ProcessLogic", "HealthCheck", "Info"},
                pokeballs = {
                    supported = {},
                    statusEffects = {}
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Pokemon capture engine with comprehensive mechanics"
                }
            }
        }
        
        -- Add pokeball data
        for ballType, ballData in pairs(POKEBALL_DATA) do
            response.Data.pokeballs.supported[ballType] = {
                name = ballData.name,
                catchRate = ballData.catchRate,
                bonusConditions = ballData.bonusConditions
            }
        end
        
        -- Add status effect data
        for status, multiplier in pairs(STATUS_EFFECT_MULTIPLIERS) do
            response.Data.pokeballs.statusEffects[status] = multiplier
        end
        
        -- Add ability effects data
        response.Data.abilities = {
            captureModifiers = {},
            fleeModifiers = {},
            criticalCaptureModifiers = {}
        }
        for ability, effect in pairs(ABILITY_CAPTURE_EFFECTS) do
            response.Data.abilities[effect.type .. "s"] = response.Data.abilities[effect.type .. "s"] or {}
            response.Data.abilities[effect.type .. "s"][ability] = {
                description = effect.description,
                multiplier = effect.multiplier
            }
        end
        
        -- Add item effects data
        response.Data.items = {
            playerItems = {},
            pokemonItems = {}
        }
        for item, effect in pairs(ITEM_CAPTURE_EFFECTS) do
            if effect.description:find("player") then
                response.Data.items.playerItems[item] = {
                    type = effect.type,
                    description = effect.description
                }
            else
                response.Data.items.pokemonItems[item] = {
                    type = effect.type,
                    description = effect.description
                }
            end
        end
        
        -- Add cross-process coordination capabilities
        response.Data.coordination = {
            supportedProcesses = {
                "pokemon-instance-manager",
                "battle-engine",
                "inventory-manager",
                "wild-encounter-engine"
            },
            messageTypes = {
                "ValidatePokemon",
                "QueryBattleState", 
                "ConsumeItem",
                "TransferPokemon"
            },
            capabilities = {
                "deterministic_rng",
                "critical_capture_calculation",
                "specialty_pokeball_conditions",
                "ability_interactions",
                "failed_capture_behavior"
            }
        }
        
        ao.send(response)
    end
)

-- Process Logic Handler (main entry point)
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local response = handleMessage(msg)
        ao.send({
            Target = msg.From,
            Action = response.Action,
            Data = response.Data,
            Error = response.Error,
            GameState = response.GameState,
            ProcessId = response.ProcessId,
            Timestamp = tostring(response.Timestamp)
        })
    end
)

-- Health Check Handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                processId = ao.id,
                processType = "logic",
                status = "healthy",
                timestamp = msg and msg.Timestamp or 0,
                operations = PROCESS_INFO.capabilities,
                adpCompliance = PROCESS_INFO.adpVersion
            },
            ProcessId = PROCESS_INFO.processId,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- AO processes should not return module exports
-- All data is handled through message passing via ao.send()
print("Process initialization complete.")