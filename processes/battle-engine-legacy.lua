-- Battle Engine Process for PokéRogue AO
-- Handles damage calculation, turn resolution logic, and battle state transitions
-- Implements pure computation on GameState with deterministic outcomes
-- Monolithic process - all dependencies embedded (no external imports)

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end }

-- Battle Engine process identifier
local PROCESS_ID = "battle-engine"

-- Performance monitoring configuration (5 second limit for logic operations)
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local performanceStartTime = nil

-- Rate limiting configuration (stricter for logic processes)
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}

-- Type effectiveness chart (embedded data)
local TYPE_EFFECTIVENESS = {
    normal = {rock = 0.5, ghost = 0, steel = 0.5},
    fire = {fire = 0.5, water = 0.5, grass = 2, ice = 2, bug = 2, rock = 0.5, dragon = 0.5, steel = 2},
    water = {fire = 2, water = 0.5, grass = 0.5, ground = 2, rock = 2, dragon = 0.5},
    electric = {water = 2, electric = 0.5, grass = 0.5, ground = 0, flying = 2, dragon = 0.5},
    grass = {fire = 0.5, water = 2, grass = 0.5, poison = 0.5, flying = 0.5, bug = 0.5, rock = 2, dragon = 0.5, steel = 0.5},
    ice = {fire = 0.5, water = 0.5, grass = 2, ice = 0.5, ground = 2, flying = 2, dragon = 2, steel = 0.5},
    fighting = {normal = 2, ice = 2, poison = 0.5, flying = 0.5, psychic = 0.5, bug = 0.5, rock = 2, ghost = 0, dark = 2, steel = 2},
    poison = {grass = 2, poison = 0.5, ground = 0.5, rock = 0.5, ghost = 0.5, steel = 0},
    ground = {fire = 2, electric = 2, grass = 0.5, poison = 2, flying = 0, bug = 0.5, rock = 2, steel = 2},
    flying = {electric = 0.5, grass = 2, ice = 0.5, fighting = 2, bug = 2, rock = 0.5, steel = 0.5},
    psychic = {fighting = 2, poison = 2, psychic = 0.5, dark = 0, steel = 0.5},
    bug = {fire = 0.5, grass = 2, fighting = 0.5, poison = 0.5, flying = 0.5, psychic = 2, ghost = 0.5, dark = 2, steel = 0.5},
    rock = {fire = 2, ice = 2, fighting = 0.5, ground = 0.5, flying = 2, bug = 2, steel = 0.5},
    ghost = {normal = 0, psychic = 2, ghost = 2, dark = 0.5, steel = 0.5},
    dragon = {dragon = 2, steel = 0.5},
    dark = {fighting = 0.5, psychic = 2, ghost = 2, dark = 0.5, steel = 0.5},
    steel = {fire = 0.5, water = 0.5, electric = 0.5, ice = 2, rock = 2, steel = 0.5}
}

-- ====================================
-- EMBEDDED LOGIC TEMPLATE FUNCTIONS
-- ====================================

-- Deep copy utility
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

-- Input validation for logic process messages
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
        return false, "Data.gameState is required for logic operations"
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

-- Rate limiting check
local function checkRateLimit(address)
    local currentTime = os.time()
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

-- Deterministic RNG using battle seed
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

local function nextRandom(rngState, min, max)
    if not rngState then
        error("RNG state is required for deterministic random generation")
    end
    
    rngState.counter = rngState.counter + 1
    
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
-- BATTLE ENGINE CORE FUNCTIONS
-- ====================================

local BattleEngine = {}

-- Calculate type effectiveness multiplier
function BattleEngine.getTypeEffectiveness(attackType, defenderType1, defenderType2)
    local effectiveness = 1.0
    
    if TYPE_EFFECTIVENESS[attackType] and TYPE_EFFECTIVENESS[attackType][defenderType1] then
        effectiveness = effectiveness * TYPE_EFFECTIVENESS[attackType][defenderType1]
    end
    
    if defenderType2 and TYPE_EFFECTIVENESS[attackType] and TYPE_EFFECTIVENESS[attackType][defenderType2] then
        effectiveness = effectiveness * TYPE_EFFECTIVENESS[attackType][defenderType2]
    end
    
    return effectiveness
end

-- Calculate critical hit multiplier
function BattleEngine.calculateCriticalHit(attacker, rngState)
    local critRate = 24 -- Base critical hit rate (1/24 chance)
    local critRoll = nextRandom(rngState, 1, critRate)
    
    if critRoll == 1 then
        return 2.0 -- Critical hit multiplier
    else
        return 1.0 -- No critical hit
    end
end

-- Calculate accuracy check
function BattleEngine.checkAccuracy(move, attacker, defender, rngState)
    local baseAccuracy = move.accuracy or 100
    local finalAccuracy = baseAccuracy
    
    local accuracyRoll = nextRandom(rngState, 1, 100)
    return accuracyRoll <= finalAccuracy
end

-- Calculate damage with all modifiers
function BattleEngine.calculateDamage(attacker, defender, move, battleConditions, rngState)
    local level = attacker.level
    local attackStat = attacker.stats.attack
    local defenseStat = defender.stats.defense
    local power = move.power or 0
    
    if move.category == "special" then
        attackStat = attacker.stats.spAttack
        defenseStat = defender.stats.spDefense
    end
    
    local baseDamage = math.floor(((2 * level / 5 + 2) * power * attackStat / defenseStat / 50 + 2))
    
    local effectiveness = BattleEngine.getTypeEffectiveness(move.type, defender.type1, defender.type2)
    baseDamage = math.floor(baseDamage * effectiveness)
    
    local critMultiplier = BattleEngine.calculateCriticalHit(attacker, rngState)
    baseDamage = math.floor(baseDamage * critMultiplier)
    
    local randomFactor = nextRandom(rngState, 85, 100) / 100
    local finalDamage = math.floor(baseDamage * randomFactor)
    
    if power > 0 and finalDamage < 1 then
        finalDamage = 1
    end
    
    return {
        damage = finalDamage,
        effectiveness = effectiveness,
        criticalHit = critMultiplier > 1,
        accuracyCheck = true
    }
end

-- Apply damage to Pokemon
function BattleEngine.applyDamage(pokemon, damage)
    local newPokemon = deepCopy(pokemon)
    newPokemon.hp = math.max(0, newPokemon.hp - damage)
    
    if newPokemon.hp <= 0 then
        newPokemon.hp = 0
        newPokemon.statusEffect = "faint"
    end
    
    return newPokemon
end

-- Process a single battle turn
function BattleEngine.processBattleTurn(gameState, battleCommand, rngState)
    local newGameState = deepCopy(gameState)
    local battle = newGameState.battle
    
    local playerPokemon = newGameState.player.party[1]
    local enemyPokemon = battle.enemyParty and battle.enemyParty[1]
    
    if not playerPokemon or not enemyPokemon then
        error("Battle requires both player and enemy Pokemon")
    end
    
    local playerGoesFirst = playerPokemon.stats.speed >= enemyPokemon.stats.speed
    
    local turnResults = {
        turn = battle.turn,
        actions = {}
    }
    
    if playerGoesFirst then
        if battleCommand.action == "attack" and battleCommand.moveId then
            local move = {
                id = battleCommand.moveId,
                name = "Tackle",
                type = "normal",
                category = "physical",
                power = 40,
                accuracy = 100
            }
            
            if BattleEngine.checkAccuracy(move, playerPokemon, enemyPokemon, rngState) then
                local damageResult = BattleEngine.calculateDamage(playerPokemon, enemyPokemon, move, battle.conditions or {}, rngState)
                
                if battle.enemyParty then
                    battle.enemyParty[1] = BattleEngine.applyDamage(enemyPokemon, damageResult.damage)
                end
                
                table.insert(turnResults.actions, {
                    actor = "player",
                    action = "attack",
                    move = move.name,
                    damage = damageResult.damage,
                    effectiveness = damageResult.effectiveness,
                    criticalHit = damageResult.criticalHit,
                    target = "enemy"
                })
            else
                table.insert(turnResults.actions, {
                    actor = "player",
                    action = "attack",
                    move = move.name,
                    result = "miss"
                })
            end
        end
        
        if battle.enemyParty and battle.enemyParty[1].hp > 0 then
            local enemyMove = {
                id = 1,
                name = "Scratch",
                type = "normal",
                category = "physical",
                power = 40,
                accuracy = 100
            }
            
            if BattleEngine.checkAccuracy(enemyMove, battle.enemyParty[1], playerPokemon, rngState) then
                local damageResult = BattleEngine.calculateDamage(battle.enemyParty[1], playerPokemon, enemyMove, battle.conditions or {}, rngState)
                
                newGameState.player.party[1] = BattleEngine.applyDamage(playerPokemon, damageResult.damage)
                
                table.insert(turnResults.actions, {
                    actor = "enemy",
                    action = "attack",
                    move = enemyMove.name,
                    damage = damageResult.damage,
                    effectiveness = damageResult.effectiveness,
                    criticalHit = damageResult.criticalHit,
                    target = "player"
                })
            else
                table.insert(turnResults.actions, {
                    actor = "enemy",
                    action = "attack",
                    move = enemyMove.name,
                    result = "miss"
                })
            end
        end
    end
    
    battle.turn = battle.turn + 1
    
    local battleEnded = false
    local winner = nil
    
    if newGameState.player.party[1].hp <= 0 then
        battleEnded = true
        winner = "enemy"
        battle.result = "defeat"
    elseif battle.enemyParty and battle.enemyParty[1] and battle.enemyParty[1].hp <= 0 then
        battleEnded = true
        winner = "player"
        battle.result = "victory"
    end
    
    if battleEnded then
        battle.status = "completed"
        battle.winner = winner
    end
    
    return {
        gameState = newGameState,
        turnResults = turnResults,
        battleEnded = battleEnded,
        winner = winner
    }
end

-- Main logic handler for battle operations
function BattleEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "processBattleTurn" then
        local battleCommand = parameters.battleCommand
        if not battleCommand then
            error("battleCommand parameter is required for processBattleTurn operation")
        end
        
        return BattleEngine.processBattleTurn(gameState, battleCommand, rngState)
        
    elseif operation == "calculateDamage" then
        local attacker = parameters.attacker
        local defender = parameters.defender
        local move = parameters.move
        
        if not attacker or not defender or not move then
            error("attacker, defender, and move parameters are required for calculateDamage operation")
        end
        
        local damageResult = BattleEngine.calculateDamage(attacker, defender, move, parameters.battleConditions or {}, rngState)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            damageResult = damageResult
        }
        
    elseif operation == "checkAccuracy" then
        local move = parameters.move
        local attacker = parameters.attacker
        local defender = parameters.defender
        
        if not move or not attacker or not defender then
            error("move, attacker, and defender parameters are required for checkAccuracy operation")
        end
        
        local accuracyResult = BattleEngine.checkAccuracy(move, attacker, defender, rngState)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            accuracyResult = accuracyResult
        }
        
    else
        error("Unknown battle engine operation: " .. operation)
    end
end

-- ====================================
-- MESSAGE PROCESSING LOGIC
-- ====================================

local function handleMessage(message)
    startPerformanceMonitoring()
    
    local isValid, validationError = validateInput(message)
    if not isValid then
        return {
            Action = "SaveState",
            Error = validationError,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
    
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
    if not rateLimitOk then
        return {
            Action = "SaveState",
            Error = rateLimitError,
            GameState = message.Data.gameState,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
    
    local originalGameState = message.Data.gameState
    local operation = message.Data.operation
    local parameters = message.Data.parameters or {}
    
    local rngState = nil
    if originalGameState.battle and originalGameState.battle.battleSeed then
        local rngInitSuccess, rngError = initializeRNG(originalGameState.battle.battleSeed)
        if not rngInitSuccess then
            return {
                Action = "SaveState",
                Error = "RNG initialization failed: " .. rngError,
                GameState = originalGameState,
                ProcessId = PROCESS_ID,
                Timestamp = os.time()
            }
        end
        rngState = rngInitSuccess
    end
    
    local success, result = pcall(function()
        return BattleEngine.handleLogicOperation(originalGameState, operation, parameters, rngState)
    end)
    
    local responseTime = endPerformanceMonitoring()
    if responseTime and responseTime > LOGIC_OPERATION_TIMEOUT then
        return {
            Action = "SaveState",
            Error = "Logic operation exceeded " .. LOGIC_OPERATION_TIMEOUT .. "ms timeout (took " .. responseTime .. "ms)",
            GameState = originalGameState,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
    
    if success then
        if result and result.gameState then
            result.gameState.timestamp = os.time()
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
            Timestamp = os.time(),
            ProcessId = PROCESS_ID
        }
    else
        return {
            Action = "SaveState",
            Error = "Logic operation failed: " .. tostring(result),
            GameState = originalGameState,
            ProcessId = PROCESS_ID,
            Timestamp = os.time()
        }
    end
end

-- ====================================
-- AO MESSAGE HANDLERS
-- ====================================

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

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                processId = PROCESS_ID,
                processType = "logic",
                status = "healthy",
                timestamp = os.time(),
                operations = {
                    "processBattleTurn",
                    "calculateDamage",
                    "checkAccuracy"
                }
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export for testing
return {
    BattleEngine = BattleEngine,
    PROCESS_ID = PROCESS_ID,
    TYPE_EFFECTIVENESS = TYPE_EFFECTIVENESS
}