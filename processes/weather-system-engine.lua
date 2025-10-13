-- Weather System Engine for AO Processes
-- Manages all 10 weather types with identical behavior to TypeScript implementation
-- ADP v1.0 Compliant Process

-- json is a global in AO environment, no require needed

-- Weather Types (matching TypeScript enum)
local WeatherType = {
    NONE = 0,
    SUNNY = 1,
    RAIN = 2,
    SANDSTORM = 3,
    HAIL = 4,
    SNOW = 5,
    FOG = 6,
    HEAVY_RAIN = 7,
    HARSH_SUN = 8,
    STRONG_WINDS = 9
}

-- Pokemon Types for immunity calculations
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

-- Move Types for type effectiveness
local MoveCategory = {
    PHYSICAL = 0,
    SPECIAL = 1,
    STATUS = 2
}

-- Initialize Weather State
if not WeatherState then
    WeatherState = {
        currentWeather = WeatherType.NONE,
        turnsLeft = 0,
        isActive = false
    }
end

-- Utility functions
local function isImmutableWeather(weatherType)
    return weatherType == WeatherType.HEAVY_RAIN or 
           weatherType == WeatherType.HARSH_SUN or 
           weatherType == WeatherType.STRONG_WINDS
end

local function isDamagingWeather(weatherType)
    return weatherType == WeatherType.SANDSTORM or weatherType == WeatherType.HAIL
end

local function isTypeImmuneToWeather(pokemonType, weatherType)
    if weatherType == WeatherType.SANDSTORM then
        return pokemonType == Type.GROUND or 
               pokemonType == Type.ROCK or 
               pokemonType == Type.STEEL
    elseif weatherType == WeatherType.HAIL then
        return pokemonType == Type.ICE
    end
    return false
end

local function hasWeatherImmunityAbility(pokemon, weatherType)
    -- Check for abilities that provide weather immunity
    local immunityAbilities = pokemon.abilities or {}
    
    for _, ability in ipairs(immunityAbilities) do
        -- Sand Veil provides sandstorm immunity
        if weatherType == WeatherType.SANDSTORM and ability.name == "Sand Veil" then
            return true
        end
        -- Ice Body provides hail immunity  
        if weatherType == WeatherType.HAIL and ability.name == "Ice Body" then
            return true
        end
        -- Overcoat provides weather damage immunity
        if ability.name == "Overcoat" and isDamagingWeather(weatherType) then
            return true
        end
        -- Magic Guard prevents weather damage
        if ability.name == "Magic Guard" and isDamagingWeather(weatherType) then
            return true
        end
    end
    
    return false
end

local function hasWeatherSuppressionAbility(pokemon)
    -- Check for abilities that suppress weather effects
    local abilities = pokemon.abilities or {}
    
    for _, ability in ipairs(abilities) do
        if ability.name == "Cloud Nine" or ability.name == "Air Lock" then
            return true
        end
    end
    
    return false
end

local function calculateWeatherDamage(maxHP, weatherType)
    if not isDamagingWeather(weatherType) then
        return 0
    end
    -- 1/16 max HP damage (matching TypeScript Math.floor precision)
    return math.floor(maxHP / 16)
end

local function getMoveTypeMultiplier(moveType, weatherType)
    local multiplier = 1.0
    
    if weatherType == WeatherType.SUNNY or weatherType == WeatherType.HARSH_SUN then
        if moveType == Type.FIRE then
            multiplier = 1.5 -- +50% Fire moves
        elseif moveType == Type.WATER then
            multiplier = 0.5 -- -50% Water moves
        end
    elseif weatherType == WeatherType.RAIN or weatherType == WeatherType.HEAVY_RAIN then
        if moveType == Type.WATER then
            multiplier = 1.5 -- +50% Water moves
        elseif moveType == Type.FIRE then
            multiplier = 0.5 -- -50% Fire moves
        end
    end
    
    return multiplier
end

local function isMoveBlocked(moveType, moveCategory, weatherType)
    if moveCategory ~= MoveCategory.PHYSICAL and moveCategory ~= MoveCategory.SPECIAL then
        return false -- Status moves not blocked
    end
    
    if weatherType == WeatherType.HARSH_SUN and moveType == Type.WATER then
        return true -- Harsh Sun blocks Water moves
    elseif weatherType == WeatherType.HEAVY_RAIN and moveType == Type.FIRE then
        return true -- Heavy Rain blocks Fire moves
    end
    
    return false
end

local function getWeatherMessage(weatherType, messageType, pokemonName)
    local messages = {
        [WeatherType.SUNNY] = {
            start = "The sunlight turned harsh!",
            lapse = "The sunlight is strong.",
            clear = "The harsh sunlight faded."
        },
        [WeatherType.RAIN] = {
            start = "It started to rain!",
            lapse = "Rain continues to fall.",
            clear = "The rain stopped."
        },
        [WeatherType.SANDSTORM] = {
            start = "A sandstorm kicked up!",
            lapse = "The sandstorm rages.",
            damage = (pokemonName or "The Pokémon") .. " is buffeted by the sandstorm!",
            clear = "The sandstorm subsided."
        },
        [WeatherType.HAIL] = {
            start = "It started to hail!",
            lapse = "Hail continues to fall.",
            damage = (pokemonName or "The Pokémon") .. " is pelted by hail!",
            clear = "The hail stopped."
        },
        [WeatherType.SNOW] = {
            start = "It started to snow!",
            lapse = "Snow continues to fall.",
            clear = "The snow stopped."
        },
        [WeatherType.FOG] = {
            start = "A thick fog rolled in!",
            lapse = "The fog is deep.",
            clear = "The fog cleared up."
        },
        [WeatherType.HEAVY_RAIN] = {
            start = "A heavy rain began to fall!",
            lapse = "The heavy rain continues.",
            continue = "There is no relief from this heavy rain!",
            block = "The Fire-type attack fizzled out in the heavy rain!"
        },
        [WeatherType.HARSH_SUN] = {
            start = "The sunlight turned extremely harsh!",
            lapse = "The sunlight is extremely harsh.",
            continue = "The extremely harsh sunlight continues!",
            block = "The Water-type attack evaporated in the harsh sunlight!"
        },
        [WeatherType.STRONG_WINDS] = {
            start = "Mysterious strong winds are protecting Flying-type Pokémon!",
            lapse = "The mysterious strong winds continue!",
            continue = "The mysterious strong winds blow on!"
        }
    }
    
    local weatherMessages = messages[weatherType]
    if weatherMessages and weatherMessages[messageType] then
        return weatherMessages[messageType]
    end
    return ""
end

-- Handler: Set Weather
Handlers.add("set-weather",
    Handlers.utils.hasMatchingTag("Action", "SetWeather"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local weatherType = data.parameters and data.parameters.weatherType
        local duration = data.parameters and data.parameters.duration or 5
        local overwrite = data.parameters and data.parameters.overwrite
        if overwrite == nil then overwrite = true end
        
        -- Validate weather type
        local weatherTypeNum = WeatherType[weatherType]
        if not weatherTypeNum then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid weather type: " .. tostring(weatherType),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Handle weather overwrite logic
        if WeatherState.isActive and not overwrite then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    success = false,
                    message = "Weather already active and overwrite disabled",
                    weather = {
                        weatherType = weatherType,
                        turnsLeft = WeatherState.turnsLeft,
                        isActive = WeatherState.isActive
                    }
                }),
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Set new weather
        WeatherState.currentWeather = weatherTypeNum
        WeatherState.turnsLeft = isImmutableWeather(weatherTypeNum) and 0 or duration
        WeatherState.isActive = (weatherTypeNum ~= WeatherType.NONE)
        
        local message = getWeatherMessage(weatherTypeNum, "start")
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                weather = {
                    weatherType = weatherType,
                    turnsLeft = WeatherState.turnsLeft,
                    isActive = WeatherState.isActive
                },
                messages = {message}
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Process Weather Turn
Handlers.add("process-weather-turn",
    Handlers.utils.hasMatchingTag("Action", "ProcessWeatherTurn"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local gameState = data.gameState or {}
        local battle = gameState.battle or {}
        local playerParty = battle.playerParty or {}
        local enemyParty = battle.enemyParty or {}
        
        local messages = {}
        local damageResults = {}
        
        if not WeatherState.isActive then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    success = true,
                    weather = {
                        weatherType = "NONE",
                        turnsLeft = 0,
                        isActive = false
                    },
                    effects = {},
                    messages = {}
                })
            })
            return
        end
            
            -- Generate lapse message
            local lapseMessage = getWeatherMessage(WeatherState.currentWeather, "lapse")
            if lapseMessage ~= "" then
                table.insert(messages, lapseMessage)
            end
            
            -- Handle damaging weather
            if isDamagingWeather(WeatherState.currentWeather) then
                local allPokemon = {}
                
                -- Add player party Pokemon
                for _, pokemon in ipairs(playerParty) do
                    table.insert(allPokemon, pokemon)
                end
                
                -- Add enemy party Pokemon
                for _, pokemon in ipairs(enemyParty) do
                    table.insert(allPokemon, pokemon)
                end
                
                -- Apply weather damage
                for _, pokemon in ipairs(allPokemon) do
                    if pokemon.isActive and pokemon.currentHP > 0 then
                        local isImmune = false
                        
                        -- Check type immunity
                        for _, pokemonType in ipairs(pokemon.types or {}) do
                            if isTypeImmuneToWeather(pokemonType, WeatherState.currentWeather) then
                                isImmune = true
                                break
                            end
                        end
                        
                        -- Check ability immunity
                        if not isImmune and hasWeatherImmunityAbility(pokemon, WeatherState.currentWeather) then
                            isImmune = true
                        end
                        
                        if not isImmune then
                            local damage = calculateWeatherDamage(pokemon.maxHP, WeatherState.currentWeather)
                            if damage > 0 then
                                local damageMessage = getWeatherMessage(WeatherState.currentWeather, "damage", pokemon.name)
                                table.insert(messages, damageMessage)
                                
                                table.insert(damageResults, {
                                    pokemonId = pokemon.id,
                                    damage = damage,
                                    weatherType = WeatherState.currentWeather
                                })
                            end
                        end
                    end
                end
            end
            
            -- Handle turn counting for non-immutable weather
            if not isImmutableWeather(WeatherState.currentWeather) and WeatherState.turnsLeft > 0 then
                WeatherState.turnsLeft = WeatherState.turnsLeft - 1
                
                if WeatherState.turnsLeft <= 0 then
                    local clearMessage = getWeatherMessage(WeatherState.currentWeather, "clear")
                    if clearMessage ~= "" then
                        table.insert(messages, clearMessage)
                    end
                    
                    WeatherState.currentWeather = WeatherType.NONE
                    WeatherState.isActive = false
                    WeatherState.turnsLeft = 0
                end
            elseif isImmutableWeather(WeatherState.currentWeather) then
                local continueMessage = getWeatherMessage(WeatherState.currentWeather, "continue")
                if continueMessage ~= "" then
                    table.insert(messages, continueMessage)
                end
            end
            
            -- Determine weather type name
            local weatherTypeName = "NONE"
            for name, value in pairs(WeatherType) do
                if value == WeatherState.currentWeather then
                    weatherTypeName = name
                    break
                end
            end
            
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                weather = {
                    weatherType = weatherTypeName,
                    turnsLeft = WeatherState.turnsLeft,
                    isActive = WeatherState.isActive
                },
                effects = {
                    damageDealt = damageResults
                },
                messages = messages
            })
        })
    end
)

-- Handler: Clear Weather
Handlers.add("clear-weather",
    Handlers.utils.hasMatchingTag("Action", "ClearWeather"),
    function(msg)
        local messages = {}
        
        if WeatherState.isActive then
            local clearMessage = getWeatherMessage(WeatherState.currentWeather, "clear")
            if clearMessage ~= "" then
                table.insert(messages, clearMessage)
            end
        end
        
        WeatherState.currentWeather = WeatherType.NONE
        WeatherState.turnsLeft = 0
        WeatherState.isActive = false
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                weather = {
                    weatherType = "NONE",
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

-- Handler: Get Weather Info
Handlers.add("get-weather-info",
    Handlers.utils.hasMatchingTag("Action", "GetWeatherInfo"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        local parameters = data.parameters or {}
        local moveType = parameters.moveType
        local moveCategory = parameters.moveCategory
        local pokemon = parameters.pokemon -- For ability checking
        
        -- Determine weather type name
        local weatherTypeName = "NONE"
        for name, value in pairs(WeatherType) do
            if value == WeatherState.currentWeather then
                weatherTypeName = name
                break
            end
        end
        
        local effects = {}
        local weatherSuppressed = false
        
        -- Check if weather effects are suppressed by abilities
        if pokemon and hasWeatherSuppressionAbility(pokemon) then
            weatherSuppressed = true
            effects.weatherSuppressed = true
            effects.suppressionMessage = pokemon.name .. "'s ability nullifies weather effects!"
        end
        
        -- Calculate move effects if move info provided and weather not suppressed
        if moveType and WeatherState.isActive and not weatherSuppressed then
            local moveTypeNum = Type[moveType]
            local moveCategoryNum = MoveCategory[moveCategory or "PHYSICAL"]
            
            if moveTypeNum then
                effects.typeMultiplier = getMoveTypeMultiplier(moveTypeNum, WeatherState.currentWeather)
                effects.moveBlocked = isMoveBlocked(moveTypeNum, moveCategoryNum, WeatherState.currentWeather)
                
                if effects.moveBlocked then
                    effects.blockMessage = getWeatherMessage(WeatherState.currentWeather, "block")
                end
            end
        elseif weatherSuppressed then
            -- Weather suppressed, so no effects apply
            effects.typeMultiplier = 1.0
            effects.moveBlocked = false
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                success = true,
                weather = {
                    weatherType = weatherTypeName,
                    turnsLeft = WeatherState.turnsLeft,
                    isActive = WeatherState.isActive,
                    isImmutable = isImmutableWeather(WeatherState.currentWeather),
                    isDamaging = isDamagingWeather(WeatherState.currentWeather)
                },
                effects = effects
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
            Name = "Weather System Engine",
            Description = "Comprehensive weather system engine managing all 10 weather types with identical behavior to TypeScript implementation",
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
                    action = "SetWeather",
                    pattern = {"Action"},
                    description = "Set active weather with type, duration, and overwrite options",
                    category = "weather",
                    parameters = {
                        {
                            name = "weatherType",
                            type = "string",
                            required = true,
                            description = "Weather type (SUNNY, RAIN, SANDSTORM, etc.)"
                        },
                        {
                            name = "duration",
                            type = "number",
                            required = false,
                            description = "Number of turns (default: 5, ignored for immutable weather)"
                        },
                        {
                            name = "overwrite",
                            type = "boolean",
                            required = false,
                            description = "Whether to replace existing weather (default: true)"
                        }
                    }
                },
                {
                    action = "ProcessWeatherTurn",
                    pattern = {"Action"},
                    description = "Process weather effects for a battle turn",
                    category = "weather"
                },
                {
                    action = "ClearWeather",
                    pattern = {"Action"},
                    description = "Clear all active weather effects",
                    category = "weather"
                },
                {
                    action = "GetWeatherInfo",
                    pattern = {"Action"},
                    description = "Get current weather information and move interactions",
                    category = "weather",
                    parameters = {
                        {
                            name = "moveType",
                            type = "string",
                            required = false,
                            description = "Move type to check for weather interactions"
                        },
                        {
                            name = "moveCategory",
                            type = "string",
                            required = false,
                            description = "Move category (PHYSICAL, SPECIAL, STATUS)"
                        }
                    }
                }
            },
            capabilities = {
                supportsHandlerRegistry = true,
                supportsTagValidation = true,
                supportsWeatherManagement = true,
                supportsTypeCalculations = true,
                supportsDamageCalculations = true,
                supportsMessageGeneration = true
            },
            weatherTypes = {
                "NONE", "SUNNY", "RAIN", "SANDSTORM", "HAIL", "SNOW", 
                "FOG", "HEAVY_RAIN", "HARSH_SUN", "STRONG_WINDS"
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
        
        print("Sent ADP v1.0 compliant Weather System Info response to " .. msg.From)
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

print("Weather System Engine initialized successfully!")