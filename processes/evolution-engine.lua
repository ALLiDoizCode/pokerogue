-- Evolution Engine Process for PokéRogue AO
-- Handles Pokemon evolution logic, stat recalculation, and form change handling
-- Implements pure computation on GameState with evolution transformations
-- Monolithic process - all dependencies embedded (no external imports)

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end }

-- Evolution Engine process identifier
local PROCESS_ID = "evolution-engine"

-- Performance monitoring configuration (5 second limit for logic operations)
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local performanceStartTime = nil

-- Rate limiting configuration (stricter for logic processes)
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}

-- Evolution types (embedded data)
local EVOLUTION_TYPES = {
    LEVEL = "level",
    STONE = "stone", 
    TRADE = "trade",
    HAPPINESS = "happiness",
    TIME = "time",
    LOCATION = "location",
    CONDITION = "condition"
}

-- Evolution conditions and chains (embedded data)
local EVOLUTION_CHAINS = {
    [1] = { -- Bulbasaur
        {toSpecies = 2, level = 16, type = EVOLUTION_TYPES.LEVEL}, -- to Ivysaur
    },
    [2] = { -- Ivysaur
        {toSpecies = 3, level = 32, type = EVOLUTION_TYPES.LEVEL}, -- to Venusaur
    },
    [4] = { -- Charmander
        {toSpecies = 5, level = 16, type = EVOLUTION_TYPES.LEVEL}, -- to Charmeleon
    },
    [5] = { -- Charmeleon
        {toSpecies = 6, level = 36, type = EVOLUTION_TYPES.LEVEL}, -- to Charizard
    },
    [7] = { -- Squirtle
        {toSpecies = 8, level = 16, type = EVOLUTION_TYPES.LEVEL}, -- to Wartortle
    },
    [8] = { -- Wartortle
        {toSpecies = 9, level = 36, type = EVOLUTION_TYPES.LEVEL}, -- to Blastoise
    },
    [25] = { -- Pikachu
        {toSpecies = 26, type = EVOLUTION_TYPES.STONE, item = "thunder_stone"}, -- to Raichu
    },
    [133] = { -- Eevee
        {toSpecies = 134, type = EVOLUTION_TYPES.STONE, item = "water_stone"}, -- to Vaporeon
        {toSpecies = 135, type = EVOLUTION_TYPES.STONE, item = "thunder_stone"}, -- to Jolteon
        {toSpecies = 136, type = EVOLUTION_TYPES.STONE, item = "fire_stone"}, -- to Flareon
        {toSpecies = 196, type = EVOLUTION_TYPES.HAPPINESS, timeOfDay = "day"}, -- to Espeon
        {toSpecies = 197, type = EVOLUTION_TYPES.HAPPINESS, timeOfDay = "night"}, -- to Umbreon
    }
}

-- Base stats for recalculation (simplified data)
local SPECIES_BASE_STATS = {
    [1] = {hp = 45, attack = 49, defense = 49, spAttack = 65, spDefense = 65, speed = 45}, -- Bulbasaur
    [2] = {hp = 60, attack = 62, defense = 63, spAttack = 80, spDefense = 80, speed = 60}, -- Ivysaur
    [3] = {hp = 80, attack = 82, defense = 83, spAttack = 100, spDefense = 100, speed = 80}, -- Venusaur
    [4] = {hp = 39, attack = 52, defense = 43, spAttack = 60, spDefense = 50, speed = 65}, -- Charmander
    [5] = {hp = 58, attack = 64, defense = 58, spAttack = 80, spDefense = 65, speed = 80}, -- Charmeleon
    [6] = {hp = 78, attack = 84, defense = 78, spAttack = 109, spDefense = 85, speed = 100}, -- Charizard
    [7] = {hp = 44, attack = 48, defense = 65, spAttack = 50, spDefense = 64, speed = 43}, -- Squirtle
    [8] = {hp = 59, attack = 63, defense = 80, spAttack = 65, spDefense = 80, speed = 58}, -- Wartortle
    [9] = {hp = 79, attack = 83, defense = 100, spAttack = 85, spDefense = 105, speed = 78}, -- Blastoise
    [25] = {hp = 35, attack = 55, defense = 40, spAttack = 50, spDefense = 50, speed = 90}, -- Pikachu
    [26] = {hp = 60, attack = 90, defense = 55, spAttack = 90, spDefense = 80, speed = 110}, -- Raichu
    [133] = {hp = 55, attack = 55, defense = 50, spAttack = 45, spDefense = 65, speed = 55}, -- Eevee
    [134] = {hp = 130, attack = 65, defense = 60, spAttack = 110, spDefense = 95, speed = 65}, -- Vaporeon
    [135] = {hp = 65, attack = 65, defense = 60, spAttack = 110, spDefense = 95, speed = 130}, -- Jolteon
    [136] = {hp = 65, attack = 130, defense = 60, spAttack = 95, spDefense = 110, speed = 65}, -- Flareon
    [196] = {hp = 65, attack = 65, defense = 60, spAttack = 130, spDefense = 95, speed = 110}, -- Espeon
    [197] = {hp = 95, attack = 65, defense = 110, spAttack = 60, spDefense = 130, speed = 65}, -- Umbreon
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

-- Calculate stat with nature modifier (exact 0.9, 1.0, 1.1 values)
local function calculateStatWithNature(baseStat, natureMod)
    if natureMod == 0.9 then
        return math.floor(baseStat * 0.9)
    elseif natureMod == 1.1 then
        return math.floor(baseStat * 1.1)
    else
        return baseStat -- nature modifier is 1.0
    end
end

-- ====================================
-- EVOLUTION ENGINE CORE FUNCTIONS
-- ====================================

local EvolutionEngine = {}

-- Check if Pokemon meets evolution requirements
function EvolutionEngine.checkEvolutionRequirements(pokemon, evolutionData, evolutionContext)
    if evolutionData.type == EVOLUTION_TYPES.LEVEL then
        return pokemon.level >= evolutionData.level
        
    elseif evolutionData.type == EVOLUTION_TYPES.STONE then
        return evolutionContext.item == evolutionData.item
        
    elseif evolutionData.type == EVOLUTION_TYPES.TRADE then
        return evolutionContext.tradeEvolution == true
        
    elseif evolutionData.type == EVOLUTION_TYPES.HAPPINESS then
        local happiness = pokemon.happiness or 0
        local happinessThreshold = evolutionData.happiness or 220
        local timeCondition = true
        
        if evolutionData.timeOfDay then
            timeCondition = evolutionContext.timeOfDay == evolutionData.timeOfDay
        end
        
        return happiness >= happinessThreshold and timeCondition
        
    elseif evolutionData.type == EVOLUTION_TYPES.TIME then
        return evolutionContext.timeOfDay == evolutionData.timeOfDay
        
    elseif evolutionData.type == EVOLUTION_TYPES.LOCATION then
        return evolutionContext.location == evolutionData.location
        
    elseif evolutionData.type == EVOLUTION_TYPES.CONDITION then
        -- Custom condition checking (simplified)
        return evolutionContext.specialCondition == evolutionData.condition
    end
    
    return false
end

-- Calculate evolved Pokemon stats
function EvolutionEngine.calculateEvolvedStats(pokemon, newSpeciesId)
    local newBaseStats = SPECIES_BASE_STATS[newSpeciesId]
    if not newBaseStats then
        error("Missing base stats for species " .. newSpeciesId)
    end
    
    local level = pokemon.level
    local ivs = pokemon.ivs or {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0}
    local nature = pokemon.nature or "hardy"
    
    -- Nature modifiers (simplified)
    local natureModifiers = {
        hardy = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.0},
        adamant = {attack = 1.1, defense = 1.0, spAttack = 0.9, spDefense = 1.0, speed = 1.0},
        modest = {attack = 0.9, defense = 1.0, spAttack = 1.1, spDefense = 1.0, speed = 1.0},
        timid = {attack = 0.9, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.1},
        jolly = {attack = 1.0, defense = 1.0, spAttack = 0.9, spDefense = 1.0, speed = 1.1},
    }
    
    local natureStats = natureModifiers[nature] or natureModifiers.hardy
    
    -- Calculate new stats using Pokemon formula
    local newStats = {}
    
    -- HP calculation: floor(((2 * base + iv) * level / 100) + level + 10)
    newStats.hp = math.floor(((2 * newBaseStats.hp + ivs.hp) * level / 100) + level + 10)
    
    -- Other stats: floor((floor(((2 * base + iv) * level / 100) + 5) * nature))
    newStats.attack = calculateStatWithNature(
        math.floor(((2 * newBaseStats.attack + ivs.attack) * level / 100) + 5),
        natureStats.attack
    )
    newStats.defense = calculateStatWithNature(
        math.floor(((2 * newBaseStats.defense + ivs.defense) * level / 100) + 5),
        natureStats.defense
    )
    newStats.spAttack = calculateStatWithNature(
        math.floor(((2 * newBaseStats.spAttack + ivs.spAttack) * level / 100) + 5),
        natureStats.spAttack
    )
    newStats.spDefense = calculateStatWithNature(
        math.floor(((2 * newBaseStats.spDefense + ivs.spDefense) * level / 100) + 5),
        natureStats.spDefense
    )
    newStats.speed = calculateStatWithNature(
        math.floor(((2 * newBaseStats.speed + ivs.speed) * level / 100) + 5),
        natureStats.speed
    )
    
    return newStats
end

-- Process Pokemon evolution
function EvolutionEngine.evolvePokemon(pokemon, targetSpeciesId, evolutionContext)
    local evolvedPokemon = deepCopy(pokemon)
    
    -- Update species
    evolvedPokemon.speciesId = targetSpeciesId
    
    -- Recalculate stats with new base stats
    local newStats = EvolutionEngine.calculateEvolvedStats(pokemon, targetSpeciesId)
    
    -- Update stats while preserving HP ratio
    local hpRatio = pokemon.hp / pokemon.maxHp
    evolvedPokemon.stats = newStats
    evolvedPokemon.maxHp = newStats.hp
    evolvedPokemon.hp = math.floor(newStats.hp * hpRatio)
    
    -- Update evolution metadata
    evolvedPokemon.evolutionLevel = pokemon.level
    evolvedPokemon.evolutionMethod = evolutionContext.method or "unknown"
    evolvedPokemon.evolvedAt = os.time()
    
    -- Preserve other important data
    evolvedPokemon.exp = pokemon.exp
    evolvedPokemon.moveset = pokemon.moveset or {}
    evolvedPokemon.nature = pokemon.nature
    evolvedPokemon.ivs = pokemon.ivs
    evolvedPokemon.originalTrainer = pokemon.originalTrainer
    
    return evolvedPokemon
end

-- Get available evolutions for a Pokemon
function EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
    local evolutions = EVOLUTION_CHAINS[pokemon.speciesId] or {}
    local availableEvolutions = {}
    
    for _, evolutionData in ipairs(evolutions) do
        if EvolutionEngine.checkEvolutionRequirements(pokemon, evolutionData, evolutionContext) then
            table.insert(availableEvolutions, {
                toSpecies = evolutionData.toSpecies,
                type = evolutionData.type,
                requirements = evolutionData
            })
        end
    end
    
    return availableEvolutions
end

-- Process evolution attempt
function EvolutionEngine.processEvolution(gameState, pokemonIndex, targetSpeciesId, evolutionContext)
    local newGameState = deepCopy(gameState)
    
    -- Get Pokemon from party
    if not newGameState.player.party[pokemonIndex] then
        error("Pokemon not found at index " .. pokemonIndex)
    end
    
    local pokemon = newGameState.player.party[pokemonIndex]
    
    -- Validate evolution is possible
    local availableEvolutions = EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
    local validEvolution = false
    
    for _, evolution in ipairs(availableEvolutions) do
        if evolution.toSpecies == targetSpeciesId then
            validEvolution = true
            break
        end
    end
    
    if not validEvolution then
        error("Pokemon cannot evolve to species " .. targetSpeciesId .. " under current conditions")
    end
    
    -- Perform evolution
    local evolvedPokemon = EvolutionEngine.evolvePokemon(pokemon, targetSpeciesId, evolutionContext)
    newGameState.player.party[pokemonIndex] = evolvedPokemon
    
    return {
        gameState = newGameState,
        evolutionSuccess = true,
        originalSpecies = pokemon.speciesId,
        newSpecies = targetSpeciesId,
        evolvedPokemon = evolvedPokemon
    }
end

-- Handle form changes (alternate forms, regional variants)
function EvolutionEngine.processFormChange(gameState, pokemonIndex, newForm, formContext)
    local newGameState = deepCopy(gameState)
    
    if not newGameState.player.party[pokemonIndex] then
        error("Pokemon not found at index " .. pokemonIndex)
    end
    
    local pokemon = newGameState.player.party[pokemonIndex]
    local changedPokemon = deepCopy(pokemon)
    
    -- Update form data
    changedPokemon.form = newForm
    changedPokemon.formChangeMethod = formContext.method or "unknown"
    changedPokemon.formChangedAt = os.time()
    
    -- Form changes might affect stats, types, abilities
    if formContext.statChanges then
        for stat, value in pairs(formContext.statChanges) do
            if changedPokemon.stats[stat] then
                changedPokemon.stats[stat] = value
            end
        end
    end
    
    if formContext.typeChanges then
        changedPokemon.type1 = formContext.typeChanges.type1 or changedPokemon.type1
        changedPokemon.type2 = formContext.typeChanges.type2 or changedPokemon.type2
    end
    
    newGameState.player.party[pokemonIndex] = changedPokemon
    
    return {
        gameState = newGameState,
        formChangeSuccess = true,
        originalForm = pokemon.form,
        newForm = newForm,
        changedPokemon = changedPokemon
    }
end

-- Main logic handler for evolution operations
function EvolutionEngine.handleLogicOperation(gameState, operation, parameters, rngState)
    if operation == "processEvolution" then
        local pokemonIndex = parameters.pokemonIndex
        local targetSpeciesId = parameters.targetSpeciesId
        local evolutionContext = parameters.evolutionContext or {}
        
        if not pokemonIndex or not targetSpeciesId then
            error("pokemonIndex and targetSpeciesId parameters are required for processEvolution operation")
        end
        
        return EvolutionEngine.processEvolution(gameState, pokemonIndex, targetSpeciesId, evolutionContext)
        
    elseif operation == "getAvailableEvolutions" then
        local pokemonIndex = parameters.pokemonIndex
        local evolutionContext = parameters.evolutionContext or {}
        
        if not pokemonIndex then
            error("pokemonIndex parameter is required for getAvailableEvolutions operation")
        end
        
        local pokemon = gameState.player.party[pokemonIndex]
        if not pokemon then
            error("Pokemon not found at index " .. pokemonIndex)
        end
        
        local availableEvolutions = EvolutionEngine.getAvailableEvolutions(pokemon, evolutionContext)
        
        local newGameState = deepCopy(gameState)
        newGameState.version = (gameState.version or 0) + 1
        
        return {
            gameState = newGameState,
            availableEvolutions = availableEvolutions
        }
        
    elseif operation == "processFormChange" then
        local pokemonIndex = parameters.pokemonIndex
        local newForm = parameters.newForm
        local formContext = parameters.formContext or {}
        
        if not pokemonIndex or not newForm then
            error("pokemonIndex and newForm parameters are required for processFormChange operation")
        end
        
        return EvolutionEngine.processFormChange(gameState, pokemonIndex, newForm, formContext)
        
    else
        error("Unknown evolution engine operation: " .. operation)
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
    
    local success, result = pcall(function()
        return EvolutionEngine.handleLogicOperation(originalGameState, operation, parameters, nil)
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
                    "processEvolution",
                    "getAvailableEvolutions",
                    "processFormChange"
                }
            },
            ProcessId = PROCESS_ID,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export for testing
return {
    EvolutionEngine = EvolutionEngine,
    PROCESS_ID = PROCESS_ID,
    EVOLUTION_TYPES = EVOLUTION_TYPES,
    EVOLUTION_CHAINS = EVOLUTION_CHAINS,
    SPECIES_BASE_STATS = SPECIES_BASE_STATS
}