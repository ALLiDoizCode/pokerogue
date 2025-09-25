-- Environmental Interaction Engine Process
-- Coordinates complex multi-system environmental interactions in Pokemon battles
-- Handles weather-terrain combinations, status-environment integration, and effect stacking
-- ADP v1.0 compliant with comprehensive self-documentation

-- Initialize global state
if not EnvironmentalState then
    EnvironmentalState = {
        activeWeather = nil,
        activeTerrain = nil,
        activeInteractions = {},
        effectMultipliers = {},
        statusPrevention = {},
        itemExtensions = {},
        removalChains = {},
        switchPersistence = {}
    }
end

-- WeatherType enumeration
local WeatherType = {
    NONE = "NONE",
    RAIN = "RAIN", 
    SUN = "SUN",
    SANDSTORM = "SANDSTORM",
    HAIL = "HAIL",
    HARSH_SUN = "HARSH_SUN",
    HEAVY_RAIN = "HEAVY_RAIN",
    STRONG_WINDS = "STRONG_WINDS",
    FOG = "FOG"
}

-- TerrainType enumeration
local TerrainType = {
    NONE = "NONE",
    ELECTRIC = "ELECTRIC",
    GRASSY = "GRASSY", 
    MISTY = "MISTY",
    PSYCHIC = "PSYCHIC"
}

-- PokemonType enumeration for multiplier calculations
local PokemonType = {
    WATER = "WATER",
    FIRE = "FIRE",
    ELECTRIC = "ELECTRIC",
    GRASS = "GRASS",
    PSYCHIC = "PSYCHIC",
    GROUND = "GROUND",
    FLYING = "FLYING",
    ROCK = "ROCK",
    ICE = "ICE",
    STEEL = "STEEL"
}

-- Weather multiplier constants
local WEATHER_MULTIPLIERS = {
    [WeatherType.RAIN] = {
        [PokemonType.WATER] = 1.5,
        [PokemonType.FIRE] = 0.5
    },
    [WeatherType.SUN] = {
        [PokemonType.FIRE] = 1.5,
        [PokemonType.WATER] = 0.5
    },
    [WeatherType.HARSH_SUN] = {
        [PokemonType.FIRE] = 1.5,
        [PokemonType.WATER] = 0.0  -- Water moves blocked
    },
    [WeatherType.HEAVY_RAIN] = {
        [PokemonType.WATER] = 1.5,
        [PokemonType.FIRE] = 0.0   -- Fire moves blocked
    },
    [WeatherType.SANDSTORM] = {},
    [WeatherType.HAIL] = {},
    [WeatherType.STRONG_WINDS] = {}
}

-- Terrain multiplier constants
local TERRAIN_MULTIPLIERS = {
    [TerrainType.ELECTRIC] = {
        [PokemonType.ELECTRIC] = 1.3
    },
    [TerrainType.GRASSY] = {
        [PokemonType.GRASS] = 1.3
    },
    [TerrainType.MISTY] = {},
    [TerrainType.PSYCHIC] = {
        [PokemonType.PSYCHIC] = 1.3
    }
}

-- Calculate environmental effect multipliers
local function calculateEnvironmentalMultipliers(weather, terrain, moveType, isGrounded)
    local weatherMultiplier = 1.0
    local terrainMultiplier = 1.0
    local combinedMultiplier = 1.0
    
    -- Apply weather effects (affects all Pokemon)
    if weather and WEATHER_MULTIPLIERS[weather] then
        weatherMultiplier = WEATHER_MULTIPLIERS[weather][moveType] or 1.0
    end
    
    -- Apply terrain effects (only affects grounded Pokemon)
    if terrain and isGrounded and TERRAIN_MULTIPLIERS[terrain] then
        terrainMultiplier = TERRAIN_MULTIPLIERS[terrain][moveType] or 1.0
    end
    
    -- Calculate combined multiplier (weather first, then terrain)
    combinedMultiplier = weatherMultiplier * terrainMultiplier
    
    return {
        weather = weatherMultiplier,
        terrain = terrainMultiplier,
        combined = combinedMultiplier
    }
end

-- Check status prevention from environmental effects
local function checkStatusPrevention(terrain, statusType)
    if terrain == TerrainType.MISTY then
        -- Misty terrain prevents all status conditions for grounded Pokemon
        return {
            prevented = true,
            source = "MISTY_TERRAIN",
            bypassedByWeather = false  -- Weather damage bypasses terrain protection
        }
    elseif terrain == TerrainType.PSYCHIC then
        -- Psychic terrain prevents priority moves
        if statusType == "PRIORITY_MOVE" then
            return {
                prevented = true,
                source = "PSYCHIC_TERRAIN",
                bypassedByWeather = false
            }
        end
    end
    
    return {
        prevented = false,
        source = nil,
        bypassedByWeather = false
    }
end

-- Calculate item duration extensions
local function calculateItemExtensions(weather, terrain, item)
    local extensions = {
        weatherTurns = 0,
        terrainTurns = 0
    }
    
    if item == "HEAT_ROCK" and (weather == WeatherType.SUN or weather == WeatherType.HARSH_SUN) then
        extensions.weatherTurns = 3  -- Extends sunny weather from 5 to 8 turns
    elseif item == "DAMP_ROCK" and (weather == WeatherType.RAIN or weather == WeatherType.HEAVY_RAIN) then
        extensions.weatherTurns = 3  -- Extends rainy weather from 5 to 8 turns
    elseif item == "SMOOTH_ROCK" and weather == WeatherType.SANDSTORM then
        extensions.weatherTurns = 3  -- Extends sandstorm from 5 to 8 turns
    elseif item == "ICY_ROCK" and weather == WeatherType.HAIL then
        extensions.weatherTurns = 3  -- Extends hail from 5 to 8 turns
    elseif item == "TERRAIN_EXTENDER" and terrain ~= TerrainType.NONE then
        extensions.terrainTurns = 3  -- Extends terrain from 5 to 8 turns
    end
    
    return extensions
end

-- Process environmental removal chains
local function processRemovalChains(removalSource, currentWeather, currentTerrain)
    local removedEffects = {}
    
    -- Cloud Nine ability removes all weather effects
    if removalSource == "CLOUD_NINE" then
        if currentWeather ~= WeatherType.NONE then
            table.insert(removedEffects, {type = "WEATHER", value = currentWeather})
        end
    end
    
    -- Defog removes terrain effects
    if removalSource == "DEFOG" then
        if currentTerrain ~= TerrainType.NONE then
            table.insert(removedEffects, {type = "TERRAIN", value = currentTerrain})
        end
    end
    
    -- Some abilities can remove multiple environmental effects
    if removalSource == "NORMALIZE" then  -- Example ability that clears all environmental effects
        if currentWeather ~= WeatherType.NONE then
            table.insert(removedEffects, {type = "WEATHER", value = currentWeather})
        end
        if currentTerrain ~= TerrainType.NONE then
            table.insert(removedEffects, {type = "TERRAIN", value = currentTerrain})
        end
    end
    
    return removedEffects
end

-- Handler: Process Environmental Interaction
Handlers.add("ProcessEnvironmentalInteraction",
    Handlers.utils.hasMatchingTag("Action", "ProcessEnvironmentalInteraction"),
    function(msg)
        local success, response = pcall(function()
            -- Validate required parameters
            local weatherType = msg.WeatherType or WeatherType.NONE
            local terrainType = msg.TerrainType or TerrainType.NONE  
            local moveType = msg.MoveType
            local isGrounded = msg.IsGrounded == "true"
            local itemHeld = msg.ItemHeld
            
            if not moveType then
                return {
                    Target = msg.From,
                    Action = "EnvironmentalInteractionError", 
                    Error = "MoveType required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end
            
            -- Calculate environmental multipliers
            local multipliers = calculateEnvironmentalMultipliers(weatherType, terrainType, moveType, isGrounded)
            
            -- Check status prevention
            local statusPrevention = checkStatusPrevention(terrainType, msg.StatusType)
            
            -- Calculate item extensions
            local itemExtensions = calculateItemExtensions(weatherType, terrainType, itemHeld)
            
            -- Update environmental state
            EnvironmentalState.activeWeather = weatherType
            EnvironmentalState.activeTerrain = terrainType
            EnvironmentalState.effectMultipliers = multipliers
            EnvironmentalState.statusPrevention = statusPrevention
            EnvironmentalState.itemExtensions = itemExtensions
            
            return {
                Target = msg.From,
                Action = "EnvironmentalInteractionSuccess",
                Data = json.encode({
                    environment = {
                        weather = weatherType,
                        terrain = terrainType,
                        isGrounded = isGrounded
                    },
                    calculations = {
                        multipliers = multipliers,
                        statusPrevention = statusPrevention,
                        itemExtensions = itemExtensions
                    },
                    interactions = {
                        weatherTerrainCombo = weatherType .. "_" .. terrainType,
                        environmentalEffects = {
                            damageBoost = multipliers.combined,
                            statusBlocked = statusPrevention.prevented,
                            durationExtended = itemExtensions.weatherTurns > 0 or itemExtensions.terrainTurns > 0
                        }
                    }
                }),
                Success = "true",
                WeatherMultiplier = tostring(multipliers.weather),
                TerrainMultiplier = tostring(multipliers.terrain),  
                CombinedMultiplier = tostring(multipliers.combined),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)
        
        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "EnvironmentalInteractionError",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Check Weather-Terrain Combination
Handlers.add("CheckWeatherTerrainCombo",
    Handlers.utils.hasMatchingTag("Action", "CheckWeatherTerrainCombo"),
    function(msg)
        local success, response = pcall(function()
            local weatherType = msg.WeatherType or WeatherType.NONE
            local terrainType = msg.TerrainType or TerrainType.NONE
            
            local combo = weatherType .. "_" .. terrainType
            local hasInteraction = weatherType ~= WeatherType.NONE and terrainType ~= TerrainType.NONE
            
            -- Check for specific weather-terrain interactions
            local specialInteractions = {}
            
            if weatherType == WeatherType.RAIN and terrainType == TerrainType.ELECTRIC then
                table.insert(specialInteractions, {
                    type = "ENHANCED_ELECTRIC",
                    description = "Rain boosts Water moves (1.5x), Electric Terrain boosts Electric moves (1.3x)",
                    combinedEffect = "Water Electric moves get 1.95x multiplier (1.5 * 1.3)"
                })
            elseif weatherType == WeatherType.SUN and terrainType == TerrainType.GRASSY then
                table.insert(specialInteractions, {
                    type = "ENHANCED_FIRE_GRASS",
                    description = "Sun boosts Fire moves (1.5x), Grassy Terrain boosts Grass moves (1.3x)",
                    combinedEffect = "Fire and Grass moves get respective boosts independently"
                })
            end
            
            return {
                Target = msg.From,
                Action = "WeatherTerrainComboResult",
                Data = json.encode({
                    combo = combo,
                    hasInteraction = hasInteraction,
                    weather = {type = weatherType, active = weatherType ~= WeatherType.NONE},
                    terrain = {type = terrainType, active = terrainType ~= TerrainType.NONE},
                    specialInteractions = specialInteractions
                }),
                Success = "true",
                Combo = combo,
                HasInteraction = tostring(hasInteraction),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)
        
        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "WeatherTerrainComboError",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Process Environmental Turn
Handlers.add("ProcessEnvironmentalTurn",
    Handlers.utils.hasMatchingTag("Action", "ProcessEnvironmentalTurn"),
    function(msg)
        local success, response = pcall(function()
            -- Process environmental effects that occur each turn
            local weatherDamage = 0
            local terrainHealing = 0
            local statusChanges = {}
            
            -- Calculate weather damage (affects all Pokemon)
            if EnvironmentalState.activeWeather == WeatherType.SANDSTORM then
                -- Sandstorm damages non-Ground/Rock/Steel types
                local pokemonType1 = msg.PokemonType1
                local pokemonType2 = msg.PokemonType2
                
                if pokemonType1 ~= PokemonType.GROUND and pokemonType1 ~= PokemonType.ROCK and pokemonType1 ~= PokemonType.STEEL and
                   (not pokemonType2 or (pokemonType2 ~= PokemonType.GROUND and pokemonType2 ~= PokemonType.ROCK and pokemonType2 ~= PokemonType.STEEL)) then
                    weatherDamage = math.floor(tonumber(msg.MaxHP or "100") / 16)  -- 1/16 max HP damage
                end
            elseif EnvironmentalState.activeWeather == WeatherType.HAIL then
                -- Hail damages non-Ice types
                local pokemonType1 = msg.PokemonType1
                local pokemonType2 = msg.PokemonType2
                
                if pokemonType1 ~= PokemonType.ICE and (not pokemonType2 or pokemonType2 ~= PokemonType.ICE) then
                    weatherDamage = math.floor(tonumber(msg.MaxHP or "100") / 16)  -- 1/16 max HP damage
                end
            end
            
            -- Calculate terrain healing (only affects grounded Pokemon)
            local isGrounded = msg.IsGrounded == "true"
            if isGrounded and EnvironmentalState.activeTerrain == TerrainType.GRASSY then
                terrainHealing = math.floor(tonumber(msg.MaxHP or "100") / 16)  -- 1/16 max HP healing
            end
            
            return {
                Target = msg.From,
                Action = "EnvironmentalTurnResult",
                Data = json.encode({
                    environmental = {
                        weather = EnvironmentalState.activeWeather,
                        terrain = EnvironmentalState.activeTerrain
                    },
                    effects = {
                        weatherDamage = weatherDamage,
                        terrainHealing = terrainHealing,
                        statusChanges = statusChanges
                    },
                    calculations = {
                        damageSource = weatherDamage > 0 and EnvironmentalState.activeWeather or "NONE",
                        healingSource = terrainHealing > 0 and EnvironmentalState.activeTerrain or "NONE",
                        affectedByGrounding = isGrounded
                    }
                }),
                Success = "true",
                WeatherDamage = tostring(weatherDamage),
                TerrainHealing = tostring(terrainHealing),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)
        
        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "EnvironmentalTurnError",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: Resolve Environmental Conflicts
Handlers.add("ResolveEnvironmentalConflicts",
    Handlers.utils.hasMatchingTag("Action", "ResolveEnvironmentalConflicts"),
    function(msg)
        local success, response = pcall(function()
            local removalSource = msg.RemovalSource
            local currentWeather = msg.CurrentWeather or EnvironmentalState.activeWeather
            local currentTerrain = msg.CurrentTerrain or EnvironmentalState.activeTerrain
            
            if not removalSource then
                return {
                    Target = msg.From,
                    Action = "EnvironmentalConflictError",
                    Error = "RemovalSource required",
                    ProcessId = ao.id,
                    Timestamp = tostring(msg.Timestamp or 0)
                }
            end
            
            -- Process removal chains
            local removedEffects = processRemovalChains(removalSource, currentWeather, currentTerrain)
            
            -- Update environmental state after removals
            for _, effect in ipairs(removedEffects) do
                if effect.type == "WEATHER" then
                    EnvironmentalState.activeWeather = WeatherType.NONE
                elseif effect.type == "TERRAIN" then
                    EnvironmentalState.activeTerrain = TerrainType.NONE
                end
            end
            
            return {
                Target = msg.From,
                Action = "EnvironmentalConflictResolution",
                Data = json.encode({
                    removalSource = removalSource,
                    removedEffects = removedEffects,
                    newEnvironment = {
                        weather = EnvironmentalState.activeWeather,
                        terrain = EnvironmentalState.activeTerrain
                    },
                    removalChain = {
                        triggered = #removedEffects > 0,
                        effectCount = #removedEffects,
                        chainLength = #removedEffects
                    }
                }),
                Success = "true",
                RemovedEffects = tostring(#removedEffects),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            }
        end)
        
        if success then
            ao.send(response)
        else
            ao.send({
                Target = msg.From,
                Action = "EnvironmentalConflictError",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add("Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Environmental Interaction Engine",
            Description = "Coordinates complex multi-system environmental interactions in Pokemon battles including weather-terrain combinations, status-environment integration, and effect stacking with mathematical precision",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
                {
                    action = "ProcessEnvironmentalInteraction",
                    pattern = {"Action"},
                    description = "Calculate environmental effect multipliers and interactions",
                    category = "core",
                    parameters = {
                        {
                            name = "WeatherType",
                            type = "string",
                            required = false,
                            description = "Current weather type (RAIN, SUN, HAIL, etc.)"
                        },
                        {
                            name = "TerrainType", 
                            type = "string",
                            required = false,
                            description = "Current terrain type (ELECTRIC, GRASSY, MISTY, PSYCHIC)"
                        },
                        {
                            name = "MoveType",
                            type = "string", 
                            required = true,
                            description = "Type of move being used"
                        },
                        {
                            name = "IsGrounded",
                            type = "string",
                            required = false,
                            description = "Whether Pokemon is grounded (true/false)"
                        },
                        {
                            name = "ItemHeld",
                            type = "string",
                            required = false,
                            description = "Item held by Pokemon for duration calculations"
                        }
                    }
                },
                {
                    action = "CheckWeatherTerrainCombo",
                    pattern = {"Action"},
                    description = "Check for special weather-terrain combination interactions",
                    category = "core",
                    parameters = {
                        {
                            name = "WeatherType",
                            type = "string",
                            required = false,
                            description = "Weather type to check"
                        },
                        {
                            name = "TerrainType",
                            type = "string",
                            required = false,
                            description = "Terrain type to check"
                        }
                    }
                },
                {
                    action = "ProcessEnvironmentalTurn", 
                    pattern = {"Action"},
                    description = "Process per-turn environmental effects like weather damage and terrain healing",
                    category = "core",
                    parameters = {
                        {
                            name = "PokemonType1",
                            type = "string",
                            required = false,
                            description = "Primary Pokemon type"
                        },
                        {
                            name = "PokemonType2",
                            type = "string", 
                            required = false,
                            description = "Secondary Pokemon type"
                        },
                        {
                            name = "MaxHP",
                            type = "string",
                            required = false,
                            description = "Pokemon's maximum HP for damage calculations"
                        },
                        {
                            name = "IsGrounded",
                            type = "string",
                            required = false,
                            description = "Whether Pokemon is grounded"
                        }
                    }
                },
                {
                    action = "ResolveEnvironmentalConflicts",
                    pattern = {"Action"},
                    description = "Handle environmental effect removal chains and conflicts",
                    category = "core",
                    parameters = {
                        {
                            name = "RemovalSource",
                            type = "string",
                            required = true,
                            description = "Source of environmental effect removal (ability, move, etc.)"
                        },
                        {
                            name = "CurrentWeather",
                            type = "string",
                            required = false,
                            description = "Current weather to potentially remove"
                        },
                        {
                            name = "CurrentTerrain",
                            type = "string",
                            required = false,
                            description = "Current terrain to potentially remove"
                        }
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get comprehensive process information and handler metadata",
                    category = "utility"
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
                supportsTagValidation = true,
                supportsExamples = true,
                environmentalInteractions = true,
                weatherTerrainCombinations = true,
                statusEnvironmentIntegration = true,
                mathematicalPrecision = true
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
    end
)

-- Ping Handler for ADP testing
Handlers.add("Ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "Environmental Interaction Engine operational",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Environmental Interaction Engine process initialized successfully")
print("Handlers registered: ProcessEnvironmentalInteraction, CheckWeatherTerrainCombo, ProcessEnvironmentalTurn, ResolveEnvironmentalConflicts")
print("ADP v1.0 compliant with comprehensive self-documentation")