-- Form Attributes Engine - Pokemon Form-Specific Stats and Abilities Migration
-- Handles form-dependent stat calculations, ability activation, type changes, 
-- move availability, item interactions, and resistance calculations

-- JSON is provided globally by AO runtime

-- Embedded Form Attributes Database
local formAttributesDatabase = {
    [681] = { -- Aegislash
        forms = {
            shield = {
                stats = {60, 50, 140, 50, 140, 60}, -- HP/ATK/DEF/SPATK/SPDEF/SPEED
                types = {"STEEL", "GHOST"},
                abilities = {"STANCE_CHANGE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    NORMAL = 0, FIGHTING = 0.5, FLYING = 1.0, POISON = 0,
                    GROUND = 1.0, ROCK = 0.5, BUG = 0.5, GHOST = 1.0,
                    STEEL = 0.5, FIRE = 2.0, WATER = 1.0, GRASS = 1.0,
                    ELECTRIC = 1.0, PSYCHIC = 0.5, ICE = 1.0, DRAGON = 1.0,
                    DARK = 2.0, FAIRY = 0.5
                },
                itemInteractions = {}
            },
            blade = {
                stats = {60, 140, 50, 140, 50, 60},
                types = {"STEEL", "GHOST"},
                abilities = {"STANCE_CHANGE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    NORMAL = 0, FIGHTING = 0.5, FLYING = 1.0, POISON = 0,
                    GROUND = 1.0, ROCK = 0.5, BUG = 0.5, GHOST = 1.0,
                    STEEL = 0.5, FIRE = 2.0, WATER = 1.0, GRASS = 1.0,
                    ELECTRIC = 1.0, PSYCHIC = 0.5, ICE = 1.0, DRAGON = 1.0,
                    DARK = 2.0, FAIRY = 0.5
                },
                itemInteractions = {}
            }
        }
    },
    [555] = { -- Darmanitan
        forms = {
            standard = {
                stats = {105, 140, 55, 30, 55, 95},
                types = {"FIRE"},
                abilities = {"SHEER_FORCE", "ZEN_MODE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    FIRE = 0.5, WATER = 2.0, GRASS = 0.5, ICE = 0.5,
                    GROUND = 2.0, ROCK = 2.0, BUG = 0.5, STEEL = 0.5,
                    FAIRY = 0.5
                },
                itemInteractions = {}
            },
            zen = {
                stats = {105, 30, 105, 140, 105, 55},
                types = {"FIRE", "PSYCHIC"},
                abilities = {"ZEN_MODE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    FIRE = 0.5, WATER = 2.0, GRASS = 0.5, ICE = 0.5,
                    FIGHTING = 0.5, PSYCHIC = 0.5, STEEL = 0.5,
                    GROUND = 2.0, ROCK = 2.0, GHOST = 2.0, DARK = 2.0
                },
                itemInteractions = {}
            }
        }
    },
    [555.1] = { -- Darmanitan-Galar
        forms = {
            standard = {
                stats = {105, 140, 55, 30, 55, 95},
                types = {"ICE"},
                abilities = {"GORILLA_TACTICS", "ZEN_MODE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    ICE = 0.5, FIRE = 2.0, FIGHTING = 2.0, ROCK = 2.0, STEEL = 2.0
                },
                itemInteractions = {}
            },
            zen = {
                stats = {105, 160, 55, 30, 55, 135},
                types = {"ICE", "FIRE"},
                abilities = {"ZEN_MODE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    ICE = 0.25, FIRE = 0.5, GRASS = 0.5, STEEL = 0.5, BUG = 0.5,
                    GROUND = 2.0, ROCK = 4.0, WATER = 2.0
                },
                itemInteractions = {}
            }
        }
    },
    [351] = { -- Castform
        forms = {
            normal = {
                stats = {70, 70, 70, 70, 70, 70},
                types = {"NORMAL"},
                abilities = {"FORECAST"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {GHOST = 0, FIGHTING = 2.0},
                itemInteractions = {}
            },
            sunny = {
                stats = {70, 70, 70, 70, 70, 70},
                types = {"FIRE"},
                abilities = {"FORECAST"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    FIRE = 0.5, WATER = 2.0, GRASS = 0.5, ICE = 0.5,
                    GROUND = 2.0, ROCK = 2.0, BUG = 0.5, STEEL = 0.5, FAIRY = 0.5
                },
                itemInteractions = {}
            },
            rainy = {
                stats = {70, 70, 70, 70, 70, 70},
                types = {"WATER"},
                abilities = {"FORECAST"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    FIRE = 0.5, WATER = 0.5, ICE = 0.5, STEEL = 0.5,
                    GRASS = 2.0, ELECTRIC = 2.0
                },
                itemInteractions = {}
            },
            snowy = {
                stats = {70, 70, 70, 70, 70, 70},
                types = {"ICE"},
                abilities = {"FORECAST"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {}},
                resistances = {
                    ICE = 0.5, FIRE = 2.0, FIGHTING = 2.0, ROCK = 2.0, STEEL = 2.0
                },
                itemInteractions = {}
            }
        }
    },
    [479] = { -- Rotom Base + Appliances
        forms = {
            normal = {
                stats = {50, 50, 77, 95, 77, 91},
                types = {"ELECTRIC", "GHOST"},
                abilities = {"LEVITATE"},
                moveRestrictions = {
                    allowed = "all", 
                    forbidden = {"OVERHEAT", "HYDRO_PUMP", "BLIZZARD", "AIR_SLASH", "LEAF_STORM"},
                    exclusive = {}
                },
                resistances = {
                    NORMAL = 0, FIGHTING = 0, POISON = 0.5, FLYING = 0.5,
                    BUG = 0.5, STEEL = 0.5, ELECTRIC = 0.5, GROUND = 0,
                    WATER = 2.0, DARK = 2.0, GHOST = 2.0
                },
                itemInteractions = {}
            },
            heat = {
                stats = {50, 65, 107, 105, 107, 86},
                types = {"ELECTRIC", "FIRE"},
                abilities = {"LEVITATE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {"OVERHEAT"}},
                resistances = {
                    FIRE = 0.25, GRASS = 0.25, ICE = 0.5, BUG = 0.5,
                    STEEL = 0.25, ELECTRIC = 0.5, FAIRY = 0.5,
                    GROUND = 2.0, ROCK = 2.0, WATER = 2.0
                },
                itemInteractions = {}
            },
            wash = {
                stats = {50, 65, 107, 105, 107, 86},
                types = {"ELECTRIC", "WATER"},
                abilities = {"LEVITATE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {"HYDRO_PUMP"}},
                resistances = {
                    FIRE = 0.25, WATER = 0.25, ICE = 0.5, STEEL = 0.25,
                    ELECTRIC = 0.5, FLYING = 0.5,
                    GROUND = 2.0, GRASS = 2.0
                },
                itemInteractions = {}
            },
            frost = {
                stats = {50, 65, 107, 105, 107, 86},
                types = {"ELECTRIC", "ICE"},
                abilities = {"LEVITATE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {"BLIZZARD"}},
                resistances = {
                    ICE = 0.25, ELECTRIC = 0.5, FLYING = 0.5,
                    FIRE = 2.0, FIGHTING = 2.0, GROUND = 2.0, ROCK = 2.0
                },
                itemInteractions = {}
            },
            fan = {
                stats = {50, 65, 107, 105, 107, 86},
                types = {"ELECTRIC", "FLYING"},
                abilities = {"LEVITATE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {"AIR_SLASH"}},
                resistances = {
                    GRASS = 0.25, FIGHTING = 0.5, BUG = 0.5,
                    ELECTRIC = 0.5, FLYING = 0.5,
                    ICE = 2.0, ROCK = 2.0, GROUND = 0
                },
                itemInteractions = {}
            },
            mow = {
                stats = {50, 65, 107, 105, 107, 86},
                types = {"ELECTRIC", "GRASS"},
                abilities = {"LEVITATE"},
                moveRestrictions = {allowed = "all", forbidden = {}, exclusive = {"LEAF_STORM"}},
                resistances = {
                    WATER = 0.25, ELECTRIC = 0.25, GRASS = 0.5, STEEL = 0.5,
                    FIRE = 2.0, ICE = 2.0, POISON = 2.0, FLYING = 2.0, BUG = 2.0
                },
                itemInteractions = {}
            }
        }
    }
}

-- Nature multipliers lookup
local natureMultipliers = {
    HARDY = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    LONELY = {1.0, 1.1, 0.9, 1.0, 1.0, 1.0},
    BRAVE = {1.0, 1.1, 1.0, 1.0, 1.0, 0.9},
    ADAMANT = {1.0, 1.1, 1.0, 0.9, 1.0, 1.0},
    NAUGHTY = {1.0, 1.1, 1.0, 1.0, 0.9, 1.0},
    BOLD = {1.0, 0.9, 1.1, 1.0, 1.0, 1.0},
    DOCILE = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    RELAXED = {1.0, 1.0, 1.1, 1.0, 1.0, 0.9},
    IMPISH = {1.0, 1.0, 1.1, 0.9, 1.0, 1.0},
    LAX = {1.0, 1.0, 1.1, 1.0, 0.9, 1.0},
    TIMID = {1.0, 0.9, 1.0, 1.0, 1.0, 1.1},
    HASTY = {1.0, 1.0, 0.9, 1.0, 1.0, 1.1},
    SERIOUS = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    JOLLY = {1.0, 1.0, 1.0, 0.9, 1.0, 1.1},
    NAIVE = {1.0, 1.0, 1.0, 1.0, 0.9, 1.1},
    MODEST = {1.0, 0.9, 1.0, 1.1, 1.0, 1.0},
    MILD = {1.0, 1.0, 0.9, 1.1, 1.0, 1.0},
    QUIET = {1.0, 1.0, 1.0, 1.1, 1.0, 0.9},
    BASHFUL = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    RASH = {1.0, 1.0, 1.0, 1.1, 0.9, 1.0},
    CALM = {1.0, 0.9, 1.0, 1.0, 1.1, 1.0},
    GENTLE = {1.0, 1.0, 0.9, 1.0, 1.1, 1.0},
    SASSY = {1.0, 1.0, 1.0, 1.0, 1.1, 0.9},
    CAREFUL = {1.0, 1.0, 1.0, 0.9, 1.1, 1.0},
    QUIRKY = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
}

-- Helper Functions
local function getFormAttributes(speciesId, formName)
    local species = formAttributesDatabase[speciesId] or formAttributesDatabase[math.floor(speciesId)]
    if not species then return nil end
    
    local form = species.forms[formName]
    if not form then
        -- Try default form
        form = species.forms.normal or species.forms.standard or species.forms.shield
    end
    
    return form
end

local function getNatureMultiplier(nature, statIndex)
    local multipliers = natureMultipliers[nature] or natureMultipliers.HARDY
    return multipliers[statIndex] or 1.0
end

local function calculateFormStats(pokemon, formData)
    local formAttributes = getFormAttributes(pokemon.speciesId, pokemon.currentForm)
    if not formAttributes then return pokemon.stats end
    
    local baseStats = formAttributes.stats
    local level = pokemon.level or 50
    local ivs = pokemon.ivs or {31, 31, 31, 31, 31, 31}
    local nature = pokemon.nature or "HARDY"
    
    local calculatedStats = {}
    for i = 1, 6 do
        if i == 1 then -- HP calculation
            calculatedStats[i] = math.floor(((2 * baseStats[i] + ivs[i]) * level / 100) + level + 10)
        else -- Other stats  
            local baseStat = math.floor(((2 * baseStats[i] + ivs[i]) * level / 100) + 5)
            calculatedStats[i] = math.floor(baseStat * getNatureMultiplier(nature, i))
        end
    end
    
    return calculatedStats
end

local function updateFormTypes(pokemon, newForm)
    local formAttributes = getFormAttributes(pokemon.speciesId, newForm)
    if not formAttributes then return false end
    
    local newTypes = formAttributes.types
    pokemon.types = {newTypes[1], newTypes[2] or nil}
    
    return true
end

local function activateFormAbilities(pokemon, formData, triggerContext)
    local formAttributes = getFormAttributes(pokemon.speciesId, pokemon.currentForm)
    if not formAttributes then return false end
    
    local availableAbilities = formAttributes.abilities
    local currentAbility = pokemon.currentAbility
    
    -- Validate ability is available for this form
    local isValidAbility = false
    for _, ability in ipairs(availableAbilities) do
        if ability == currentAbility then
            isValidAbility = true
            break
        end
    end
    
    if not isValidAbility then
        -- Switch to default ability for this form
        pokemon.currentAbility = availableAbilities[1]
    end
    
    return true
end

local function validateFormMoveAvailability(pokemon, moveId)
    local formAttributes = getFormAttributes(pokemon.speciesId, pokemon.currentForm)
    if not formAttributes then return true end
    
    local moveRestrictions = formAttributes.moveRestrictions
    
    -- Check if move is forbidden for this form
    if moveRestrictions.forbidden then
        for _, forbiddenMove in ipairs(moveRestrictions.forbidden) do
            if moveId == forbiddenMove then return false end
        end
    end
    
    -- Check if move is form-exclusive
    if moveRestrictions.exclusive then
        for _, exclusiveMove in ipairs(moveRestrictions.exclusive) do
            if moveId == exclusiveMove then return true end
        end
    end
    
    return moveRestrictions.allowed == "all"
end

local function calculateFormResistances(pokemon, attackType, moveData)
    local formAttributes = getFormAttributes(pokemon.speciesId, pokemon.currentForm)
    if not formAttributes then return 1.0 end
    
    local resistances = formAttributes.resistances
    local multiplier = 1.0
    
    -- Apply type-based resistances for this form
    for _, defenderType in ipairs(pokemon.types) do
        if defenderType and resistances[attackType] then
            multiplier = multiplier * resistances[attackType]
        end
    end
    
    return multiplier
end

local function calculateFormItemInteraction(pokemon, item, context)
    local formAttributes = getFormAttributes(pokemon.speciesId, pokemon.currentForm)
    if not formAttributes or not item then return nil end
    
    local itemInteractions = formAttributes.itemInteractions or {}
    local itemEffect = itemInteractions[item.id]
    
    if itemEffect then
        return itemEffect
    else
        return nil -- No special form interaction
    end
end

-- Message Handlers

Handlers.add("CalculateFormStats",
    Handlers.utils.hasMatchingTag("Action", "CalculateFormStats"),
    function(msg)
        local pokemonData = json.decode(msg.Data or "{}")
        
        if not pokemonData.speciesId or not pokemonData.currentForm then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and CurrentForm required"
            })
            return
        end
        
        local calculatedStats = calculateFormStats(pokemonData, nil)
        
        ao.send({
            Target = msg.From,
            Action = "FormStatsCalculated",
            Data = json.encode({
                speciesId = pokemonData.speciesId,
                currentForm = pokemonData.currentForm,
                calculatedStats = calculatedStats,
                success = true
            })
        })
    end
)

Handlers.add("UpdateFormTypes",
    Handlers.utils.hasMatchingTag("Action", "UpdateFormTypes"),
    function(msg)
        local pokemonData = json.decode(msg.Data or "{}")
        local newForm = msg.NewForm or msg.Tags.NewForm
        
        if not pokemonData.speciesId or not newForm then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and NewForm required"
            })
            return
        end
        
        local success = updateFormTypes(pokemonData, newForm)
        
        ao.send({
            Target = msg.From,
            Action = "FormTypesUpdated",
            Data = json.encode({
                speciesId = pokemonData.speciesId,
                newForm = newForm,
                newTypes = pokemonData.types,
                success = success
            })
        })
    end
)

Handlers.add("ActivateFormAbilities",
    Handlers.utils.hasMatchingTag("Action", "ActivateFormAbilities"),
    function(msg)
        local pokemonData = json.decode(msg.Data or "{}")
        local triggerContext = msg.TriggerContext or msg.Tags.TriggerContext
        
        if not pokemonData.speciesId or not pokemonData.currentForm then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and CurrentForm required"
            })
            return
        end
        
        local success = activateFormAbilities(pokemonData, nil, triggerContext)
        
        ao.send({
            Target = msg.From,
            Action = "FormAbilitiesActivated",
            Data = json.encode({
                speciesId = pokemonData.speciesId,
                currentForm = pokemonData.currentForm,
                currentAbility = pokemonData.currentAbility,
                success = success
            })
        })
    end
)

Handlers.add("ValidateMoveAvailability",
    Handlers.utils.hasMatchingTag("Action", "ValidateMoveAvailability"),
    function(msg)
        local pokemonData = json.decode(msg.Data or "{}")
        local moveId = msg.MoveId or msg.Tags.MoveId
        
        if not pokemonData.speciesId or not moveId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and MoveId required"
            })
            return
        end
        
        local isAvailable = validateFormMoveAvailability(pokemonData, moveId)
        
        ao.send({
            Target = msg.From,
            Action = "MoveAvailabilityValidated",
            Data = json.encode({
                speciesId = pokemonData.speciesId,
                currentForm = pokemonData.currentForm,
                moveId = moveId,
                isAvailable = isAvailable,
                success = true
            })
        })
    end
)

Handlers.add("CalculateFormResistances",
    Handlers.utils.hasMatchingTag("Action", "CalculateFormResistances"),
    function(msg)
        local pokemonData = json.decode(msg.Data or "{}")
        local attackType = msg.AttackType or msg.Tags.AttackType
        
        if not pokemonData.speciesId or not attackType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and AttackType required"
            })
            return
        end
        
        local multiplier = calculateFormResistances(pokemonData, attackType, nil)
        
        ao.send({
            Target = msg.From,
            Action = "FormResistancesCalculated",
            Data = json.encode({
                speciesId = pokemonData.speciesId,
                currentForm = pokemonData.currentForm,
                attackType = attackType,
                multiplier = multiplier,
                success = true
            })
        })
    end
)

Handlers.add("ProcessFormItemInteraction",
    Handlers.utils.hasMatchingTag("Action", "ProcessFormItemInteraction"),
    function(msg)
        local pokemonData = json.decode(msg.Data or "{}")
        local itemData = json.decode(msg.ItemData or "{}")
        local context = msg.Context or msg.Tags.Context
        
        if not pokemonData.speciesId or not itemData.id then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and ItemData.id required"
            })
            return
        end
        
        local interaction = calculateFormItemInteraction(pokemonData, itemData, context)
        
        ao.send({
            Target = msg.From,
            Action = "FormItemInteractionProcessed",
            Data = json.encode({
                speciesId = pokemonData.speciesId,
                currentForm = pokemonData.currentForm,
                itemId = itemData.id,
                interaction = interaction,
                success = true
            })
        })
    end
)

Handlers.add("GetFormAttributes",
    Handlers.utils.hasMatchingTag("Action", "GetFormAttributes"),
    function(msg)
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        local formName = msg.FormName or msg.Tags.FormName
        
        if not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId required"
            })
            return
        end
        
        local formAttributes = getFormAttributes(speciesId, formName)
        
        ao.send({
            Target = msg.From,
            Action = "FormAttributesRetrieved",
            Data = json.encode({
                speciesId = speciesId,
                formName = formName,
                attributes = formAttributes,
                success = formAttributes ~= nil
            })
        })
    end
)

-- AO Documentation Protocol (ADP) v1.0 - Info Handler
Handlers.add("Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Form Attributes Engine",
            Description = "Pokemon form-specific stats and abilities engine handling form-dependent calculations, ability activation, type changes, move availability, item interactions, and resistance calculations",
            Owner = Owner or ao.env.Process.Owner,
            ProcessId = ao.id,
            protocolVersion = "1.0",
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            handlers = {
                {
                    action = "CalculateFormStats",
                    pattern = {"Action"},
                    description = "Calculate form-specific stat distributions with mathematical precision",
                    category = "core",
                    parameters = {
                        {
                            name = "Data",
                            type = "string",
                            required = true,
                            description = "JSON-encoded Pokemon data with speciesId, currentForm, level, ivs, nature"
                        }
                    }
                },
                {
                    action = "UpdateFormTypes",
                    pattern = {"Action"},
                    description = "Update Pokemon types based on form change",
                    category = "core",
                    parameters = {
                        {
                            name = "Data",
                            type = "string",
                            required = true,
                            description = "JSON-encoded Pokemon data"
                        },
                        {
                            name = "NewForm",
                            type = "string",
                            required = true,
                            description = "Target form name"
                        }
                    }
                },
                {
                    action = "ActivateFormAbilities",
                    pattern = {"Action"},
                    description = "Activate and validate form-specific abilities",
                    category = "core",
                    parameters = {
                        {
                            name = "Data",
                            type = "string",
                            required = true,
                            description = "JSON-encoded Pokemon data"
                        },
                        {
                            name = "TriggerContext",
                            type = "string",
                            required = false,
                            description = "Ability trigger context"
                        }
                    }
                },
                {
                    action = "ValidateMoveAvailability",
                    pattern = {"Action"},
                    description = "Validate form-specific move availability and restrictions",
                    category = "core",
                    parameters = {
                        {
                            name = "Data",
                            type = "string",
                            required = true,
                            description = "JSON-encoded Pokemon data"
                        },
                        {
                            name = "MoveId",
                            type = "string",
                            required = true,
                            description = "Move identifier to validate"
                        }
                    }
                },
                {
                    action = "CalculateFormResistances",
                    pattern = {"Action"},
                    description = "Calculate form-based damage resistances and immunities",
                    category = "core",
                    parameters = {
                        {
                            name = "Data",
                            type = "string",
                            required = true,
                            description = "JSON-encoded Pokemon data"
                        },
                        {
                            name = "AttackType",
                            type = "string",
                            required = true,
                            description = "Attacking move type"
                        }
                    }
                },
                {
                    action = "ProcessFormItemInteraction",
                    pattern = {"Action"},
                    description = "Process form-dependent item interactions",
                    category = "core",
                    parameters = {
                        {
                            name = "Data",
                            type = "string",
                            required = true,
                            description = "JSON-encoded Pokemon data"
                        },
                        {
                            name = "ItemData",
                            type = "string",
                            required = true,
                            description = "JSON-encoded item data"
                        },
                        {
                            name = "Context",
                            type = "string",
                            required = false,
                            description = "Interaction context"
                        }
                    }
                },
                {
                    action = "GetFormAttributes",
                    pattern = {"Action"},
                    description = "Retrieve complete form attribute set",
                    category = "utility",
                    parameters = {
                        {
                            name = "SpeciesId",
                            type = "number",
                            required = true,
                            description = "Pokemon species identifier"
                        },
                        {
                            name = "FormName",
                            type = "string",
                            required = false,
                            description = "Form name (defaults to primary form)"
                        }
                    }
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
                supportsTagValidation = true,
                supportsFormAttributes = true,
                supportsStatCalculation = true,
                supportsTypeEffectiveness = true,
                supportsAbilityActivation = true,
                supportsMoveValidation = true,
                supportsItemInteraction = true,
                supportsResistanceCalculation = true
            }
        }
        
        ao.send({
            Target = msg.From,
            Data = json.encode(infoResponse)
        })
    end
)

-- Basic Ping handler for ADP testing
Handlers.add("Ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong"
        })
    end
)

print("Form Attributes Engine initialized successfully")