-- Terrain Effects Engine for AO Processes
-- Manages all 4 terrain types with identical behavior to TypeScript implementation
-- ADP v1.0 Compliant Process

-- json is a global in AO environment, no require needed

-- Terrain Types (matching TypeScript enum)
local TerrainType = {
    NONE = 0,
    MISTY = 1,
    ELECTRIC = 2,
    GRASSY = 3,
    PSYCHIC = 4
}

-- Pokemon Types for terrain interactions
local Type = {
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 9,
    WATER = 10,
    GRASS = 11,
    ELECTRIC = 12,
    PSYCHIC = 13,
    ICE = 14,
    DRAGON = 15,
    DARK = 16,
    FAIRY = 17
}

-- Move Categories for move blocking checks
local MoveCategory = {
    PHYSICAL = 0,
    SPECIAL = 1,
    STATUS = 2
}

-- Initialize Terrain State
if not TerrainState then
    TerrainState = {
        currentTerrain = TerrainType.NONE,
        turnsLeft = 0,
        isActive = false
    }
end

-- Utility functions
local function isGrounded(pokemon)
    -- Check if Pokemon is grounded (affected by terrain)
    local types = pokemon.types or {}
    
    -- Flying types are not grounded
    for _, pokemonType in ipairs(types) do
        if pokemonType == Type.FLYING then
            return false
        end
    end
    
    -- Check for Levitate ability
    local abilities = pokemon.abilities or {}
    for _, ability in ipairs(abilities) do
        if ability.name == "Levitate" then
            return false
        end
    end
    
    return true
end

local function hasTerrainSuppressionAbility(pokemon)
    -- Check for abilities that suppress terrain effects
    local abilities = pokemon.abilities or {}
    
    for _, ability in ipairs(abilities) do
        -- No specific terrain suppression abilities in gen 8
        -- Could be extended for future abilities
    end
    
    return false
end

local function getTerrainTypeMultiplier(moveType, terrainType)
    local multiplier = 1.0
    
    if terrainType == TerrainType.ELECTRIC and moveType == Type.ELECTRIC then
        multiplier = 1.3 -- +30% Electric moves on Electric terrain
    elseif terrainType == TerrainType.GRASSY and moveType == Type.GRASS then
        multiplier = 1.3 -- +30% Grass moves on Grassy terrain
    elseif terrainType == TerrainType.PSYCHIC and moveType == Type.PSYCHIC then
        multiplier = 1.3 -- +30% Psychic moves on Psychic terrain
    end
    -- MISTY terrain has no type multipliers
    
    return multiplier
end

local function isPriorityMove(movePriority)
    return (movePriority or 0) > 0
end

local function isMoveBlocked(moveData, targetPokemon, terrainType)
    if terrainType ~= TerrainType.PSYCHIC then
        return false
    end
    
    -- Psychic terrain only blocks priority moves targeting grounded Pokemon
    if not isPriorityMove(moveData.priority) then
        return false
    end
    
    -- Move must target an opponent
    if not moveData.targetsOpponent then
        return false
    end
    
    -- Target must be grounded
    if not isGrounded(targetPokemon) then
        return false
    end
    
    -- Exclude field moves and spread moves
    if moveData.target == "ALL" or moveData.target == "FIELD" then
        return false
    end
    
    return true
end

local function canPreventStatus(statusCondition, pokemon, terrainType)
    if terrainType ~= TerrainType.MISTY then
        return false
    end
    
    -- Only prevents status on grounded Pokemon
    if not isGrounded(pokemon) then
        return false
    end
    
    -- Misty terrain prevents these status conditions
    local preventedStatuses = {
        "SLEEP", "PARALYSIS", "BURN", "FREEZE", "POISON", "BADLY_POISONED"
    }
    
    for _, preventedStatus in ipairs(preventedStatuses) do
        if statusCondition == preventedStatus then
            return true
        end
    end
    
    return false
end

local function getTerrainMessage(terrainType, messageType, pokemonName)
    local messages = {
        [TerrainType.MISTY] = {
            start = "Mist swirled around the battlefield!",
            lapse = "The mist continues to swirl.",
            clear = "The mist disappeared from the battlefield.",
            prevent = (pokemonName or "The Pokémon") .. " is protected by the misty terrain!"
        },
        [TerrainType.ELECTRIC] = {
            start = "The battlefield became electrified!",
            lapse = "The electric current continues to flow.",
            clear = "The electricity disappeared from the battlefield.",
            boost = "The Electric-type attack was powered up by the electric terrain!"
        },
        [TerrainType.GRASSY] = {
            start = "Grass grew to cover the battlefield!",
            lapse = "The grass continues to grow.",
            clear = "The grass disappeared from the battlefield.",
            boost = "The Grass-type attack was powered up by the grassy terrain!",
            heal = (pokemonName or "The Pokémon") .. " is healed by the grassy terrain!"
        },
        [TerrainType.PSYCHIC] = {
            start = "The battlefield became weird!",
            lapse = "The psychic energy continues to flow.",
            clear = "The weirdness disappeared from the battlefield!",
            boost = "The Psychic-type attack was powered up by the psychic terrain!",
            block = (pokemonName or "The Pokémon") .. " cannot use priority moves!"
        }
    }
    
    local terrainMessages = messages[terrainType]
    if terrainMessages and terrainMessages[messageType] then
        return terrainMessages[messageType]
    end
    return ""
end

-- Handler: Set Terrain
Handlers.add("set-terrain",
    Handlers.utils.hasMatchingTag("Action", "SetTerrain"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local terrainType = data.parameters and data.parameters.terrainType
        local duration = data.parameters and data.parameters.duration or 5
        local overwrite = data.parameters and data.parameters.overwrite or true
        
        -- Validate terrain type
        local terrainTypeNum = TerrainType[terrainType]
        if not terrainTypeNum then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid terrain type: " .. tostring(terrainType),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Handle terrain overwrite logic
        if TerrainState.isActive and not overwrite then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    success = false,
                    message = "Terrain already active and overwrite disabled",
                    terrain = {
                        terrainType = terrainType,
                        turnsLeft = TerrainState.turnsLeft,
                        isActive = TerrainState.isActive
                    }
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Set new terrain
        TerrainState.currentTerrain = terrainTypeNum
        TerrainState.turnsLeft = (terrainTypeNum == TerrainType.NONE) and 0 or duration
        TerrainState.isActive = (terrainTypeNum ~= TerrainType.NONE)
        
        local message = getTerrainMessage(terrainTypeNum, "start")
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                terrain = {
                    terrainType = terrainType,
                    turnsLeft = TerrainState.turnsLeft,
                    isActive = TerrainState.isActive
                },
                messages = {message}
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Process Terrain Turn
Handlers.add("process-terrain-turn",
    Handlers.utils.hasMatchingTag("Action", "ProcessTerrainTurn"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local gameState = data.gameState or {}
        local battle = gameState.battle or {}
        local playerParty = battle.playerParty or {}
        local enemyParty = battle.enemyParty or {}
        
        local messages = {}
        local healingResults = {}
        
        if not TerrainState.isActive then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    success = true,
                    terrain = {
                        terrainType = "NONE",
                        turnsLeft = 0,
                        isActive = false
                    },
                    effects = {},
                    messages = {}
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Generate lapse message
        local lapseMessage = getTerrainMessage(TerrainState.currentTerrain, "lapse")
        if lapseMessage ~= "" then
            table.insert(messages, lapseMessage)
        end
        
        -- Handle Grassy Terrain healing
        if TerrainState.currentTerrain == TerrainType.GRASSY then
            local allPokemon = {}
            
            -- Add player party Pokemon
            for _, pokemon in ipairs(playerParty) do
                table.insert(allPokemon, pokemon)
            end
            
            -- Add enemy party Pokemon
            for _, pokemon in ipairs(enemyParty) do
                table.insert(allPokemon, pokemon)
            end
            
            -- Apply healing to grounded Pokemon
            for _, pokemon in ipairs(allPokemon) do
                if pokemon.isActive and pokemon.currentHP > 0 and isGrounded(pokemon) then
                    local healAmount = math.floor(pokemon.maxHP / 16) -- 1/16 max HP healing
                    if healAmount > 0 then
                        local healMessage = getTerrainMessage(TerrainState.currentTerrain, "heal", pokemon.name)
                        table.insert(messages, healMessage)
                        
                        table.insert(healingResults, {
                            pokemonId = pokemon.id,
                            healAmount = healAmount,
                            terrainType = TerrainState.currentTerrain
                        })
                    end
                end
            end
        end
        
        -- Handle turn counting
        if TerrainState.turnsLeft > 0 then
            TerrainState.turnsLeft = TerrainState.turnsLeft - 1
            
            if TerrainState.turnsLeft <= 0 then
                local clearMessage = getTerrainMessage(TerrainState.currentTerrain, "clear")
                if clearMessage ~= "" then
                    table.insert(messages, clearMessage)
                end
                
                TerrainState.currentTerrain = TerrainType.NONE
                TerrainState.isActive = false
                TerrainState.turnsLeft = 0
            end
        end
        
        -- Determine terrain type name
        local terrainTypeName = "NONE"
        for name, value in pairs(TerrainType) do
            if value == TerrainState.currentTerrain then
                terrainTypeName = name
                break
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                terrain = {
                    terrainType = terrainTypeName,
                    turnsLeft = TerrainState.turnsLeft,
                    isActive = TerrainState.isActive
                },
                effects = {
                    healingDealt = healingResults
                },
                messages = messages
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Clear Terrain
Handlers.add("clear-terrain",
    Handlers.utils.hasMatchingTag("Action", "ClearTerrain"),
    function(msg)
        local messages = {}
        
        if TerrainState.isActive then
            local clearMessage = getTerrainMessage(TerrainState.currentTerrain, "clear")
            if clearMessage ~= "" then
                table.insert(messages, clearMessage)
            end
        end
        
        TerrainState.currentTerrain = TerrainType.NONE
        TerrainState.turnsLeft = 0
        TerrainState.isActive = false
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                terrain = {
                    terrainType = "NONE",
                    turnsLeft = 0,
                    isActive = false
                },
                messages = messages
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Get Terrain Info
Handlers.add("get-terrain-info",
    Handlers.utils.hasMatchingTag("Action", "GetTerrainInfo"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local parameters = data.parameters or {}
        local moveType = parameters.moveType
        local moveData = parameters.moveData or {}
        local targetPokemon = parameters.targetPokemon
        local pokemon = parameters.pokemon -- For ability checking
        
        -- Determine terrain type name
        local terrainTypeName = "NONE"
        for name, value in pairs(TerrainType) do
            if value == TerrainState.currentTerrain then
                terrainTypeName = name
                break
            end
        end
        
        local effects = {}
        local terrainSuppressed = false
        
        -- Check if terrain effects are suppressed by abilities
        if pokemon and hasTerrainSuppressionAbility(pokemon) then
            terrainSuppressed = true
            effects.terrainSuppressed = true
            effects.suppressionMessage = pokemon.name .. "'s ability nullifies terrain effects!"
        end
        
        -- Calculate move effects if move info provided and terrain not suppressed
        if moveType and TerrainState.isActive and not terrainSuppressed then
            local moveTypeNum = Type[moveType]
            
            if moveTypeNum then
                effects.typeMultiplier = getTerrainTypeMultiplier(moveTypeNum, TerrainState.currentTerrain)
                
                -- Check move blocking for Psychic terrain
                if targetPokemon then
                    effects.moveBlocked = isMoveBlocked(moveData, targetPokemon, TerrainState.currentTerrain)
                    if effects.moveBlocked then
                        effects.blockMessage = getTerrainMessage(TerrainState.currentTerrain, "block", targetPokemon.name)
                    end
                end
                
                -- Check status prevention for Misty terrain
                if parameters.statusCondition and targetPokemon then
                    effects.statusPrevented = canPreventStatus(parameters.statusCondition, targetPokemon, TerrainState.currentTerrain)
                    if effects.statusPrevented then
                        effects.preventMessage = getTerrainMessage(TerrainState.currentTerrain, "prevent", targetPokemon.name)
                    end
                end
            end
        elseif terrainSuppressed then
            -- Terrain suppressed, so no effects apply
            effects.typeMultiplier = 1.0
            effects.moveBlocked = false
            effects.statusPrevented = false
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                terrain = {
                    terrainType = terrainTypeName,
                    turnsLeft = TerrainState.turnsLeft,
                    isActive = TerrainState.isActive
                },
                effects = effects
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Check Move Blocking
Handlers.add("check-move-blocking",
    Handlers.utils.hasMatchingTag("Action", "CheckMoveBlocking"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local moveData = data.parameters and data.parameters.moveData or {}
        local targetPokemon = data.parameters and data.parameters.targetPokemon
        
        if not TerrainState.isActive or not targetPokemon then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    success = true,
                    moveBlocked = false,
                    terrainType = "NONE"
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        local moveBlocked = isMoveBlocked(moveData, targetPokemon, TerrainState.currentTerrain)
        local blockMessage = ""
        
        if moveBlocked then
            blockMessage = getTerrainMessage(TerrainState.currentTerrain, "block", targetPokemon.name)
        end
        
        -- Determine terrain type name
        local terrainTypeName = "NONE"
        for name, value in pairs(TerrainType) do
            if value == TerrainState.currentTerrain then
                terrainTypeName = name
                break
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                moveBlocked = moveBlocked,
                terrainType = terrainTypeName,
                blockMessage = blockMessage
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Calculate Type Multiplier
Handlers.add("calculate-type-multiplier",
    Handlers.utils.hasMatchingTag("Action", "CalculateTypeMultiplier"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local moveType = data.parameters and data.parameters.moveType
        local pokemon = data.parameters and data.parameters.pokemon
        
        if not moveType or not TerrainState.isActive then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    success = true,
                    typeMultiplier = 1.0,
                    terrainType = "NONE"
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Check if Pokemon is grounded (required for terrain type multipliers)
        local multiplier = 1.0
        if pokemon and isGrounded(pokemon) then
            local moveTypeNum = Type[moveType]
            if moveTypeNum then
                multiplier = getTerrainTypeMultiplier(moveTypeNum, TerrainState.currentTerrain)
            end
        end
        
        local boostMessage = ""
        if multiplier > 1.0 then
            boostMessage = getTerrainMessage(TerrainState.currentTerrain, "boost")
        end
        
        -- Determine terrain type name
        local terrainTypeName = "NONE"
        for name, value in pairs(TerrainType) do
            if value == TerrainState.currentTerrain then
                terrainTypeName = name
                break
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                typeMultiplier = multiplier,
                terrainType = terrainTypeName,
                boostMessage = boostMessage
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- ADP v1.0 Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Terrain Effects Engine",
            Description = "Comprehensive terrain effects engine managing all 4 terrain types with identical behavior to TypeScript implementation",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
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
                },
                {
                    action = "SetTerrain",
                    pattern = {"Action"},
                    description = "Set active terrain with type, duration, and overwrite options",
                    category = "terrain",
                    parameters = {
                        {
                            name = "terrainType",
                            type = "string",
                            required = true,
                            description = "Terrain type (MISTY, ELECTRIC, GRASSY, PSYCHIC)"
                        },
                        {
                            name = "duration",
                            type = "number",
                            required = false,
                            description = "Number of turns (default: 5)"
                        },
                        {
                            name = "overwrite",
                            type = "boolean",
                            required = false,
                            description = "Whether to replace existing terrain (default: true)"
                        }
                    }
                },
                {
                    action = "ProcessTerrainTurn",
                    pattern = {"Action"},
                    description = "Process terrain effects for a battle turn",
                    category = "terrain"
                },
                {
                    action = "ClearTerrain",
                    pattern = {"Action"},
                    description = "Clear all active terrain effects",
                    category = "terrain"
                },
                {
                    action = "GetTerrainInfo",
                    pattern = {"Action"},
                    description = "Get current terrain information and move interactions",
                    category = "terrain",
                    parameters = {
                        {
                            name = "moveType",
                            type = "string",
                            required = false,
                            description = "Move type to check for terrain interactions"
                        },
                        {
                            name = "moveData",
                            type = "object",
                            required = false,
                            description = "Move data including priority and targeting info"
                        },
                        {
                            name = "targetPokemon",
                            type = "object",
                            required = false,
                            description = "Target Pokemon for grounding and blocking checks"
                        }
                    }
                },
                {
                    action = "CheckMoveBlocking",
                    pattern = {"Action"},
                    description = "Check if a move is blocked by terrain effects",
                    category = "terrain",
                    parameters = {
                        {
                            name = "moveData",
                            type = "object",
                            required = true,
                            description = "Move data including priority and targeting info"
                        },
                        {
                            name = "targetPokemon",
                            type = "object",
                            required = true,
                            description = "Target Pokemon for blocking validation"
                        }
                    }
                },
                {
                    action = "CalculateTypeMultiplier",
                    pattern = {"Action"},
                    description = "Calculate terrain-based move type multipliers",
                    category = "terrain",
                    parameters = {
                        {
                            name = "moveType",
                            type = "string",
                            required = true,
                            description = "Move type for multiplier calculation"
                        },
                        {
                            name = "pokemon",
                            type = "object",
                            required = false,
                            description = "Pokemon using the move (for grounding checks)"
                        }
                    }
                }
            },
            capabilities = {
                supportsHandlerRegistry = true,
                supportsTagValidation = true,
                supportsTerrainManagement = true,
                supportsTypeCalculations = true,
                supportsMoveBlocking = true,
                supportsStatusPrevention = true,
                supportsMessageGeneration = true
            },
            terrainTypes = {
                "NONE", "MISTY", "ELECTRIC", "GRASSY", "PSYCHIC"
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
        
        print("Sent ADP v1.0 compliant Terrain Effects Info response to " .. msg.From)
    end
)

-- Basic Ping handler for ADP testing
Handlers.add("ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong"
        })
    end
)

print("Terrain Effects Engine initialized successfully!")