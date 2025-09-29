-- Form Persistence Engine Process
-- Manages temporary vs permanent Pokemon form changes with duration tracking and persistence
-- ADP v1.0 compliant for self-documentation and autonomous agent interaction

-- Use global json if available, fallback to embedded JSON functions
local json = json or {
    encode = function(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                if type(v) == "string" then
                    table.insert(parts, '"' .. k .. '":"' .. v .. '"')
                elseif type(v) == "number" then
                    table.insert(parts, '"' .. k .. '":' .. tostring(v))
                elseif type(v) == "boolean" then
                    table.insert(parts, '"' .. k .. '":' .. (v and "true" or "false"))
                elseif type(v) == "table" then
                    table.insert(parts, '"' .. k .. '":' .. json.encode(v))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj .. '"'
        else
            return tostring(obj)
        end
    end,
    decode = function(str)
        -- Enhanced JSON decode for more robust parsing
        if not str or str == "" then return {} end
        if str == "{}" then return {} end
        if str == "[]" then return {} end
        
        -- Try to parse simple object patterns
        if str:match("^%s*{.*}%s*$") then
            -- Basic object parsing for key-value pairs
            local result = {}
            
            -- Extract content between braces
            local content = str:match("{(.*)}")
            if content then
                -- Split by commas outside of quotes
                local pairs = {}
                local current = ""
                local inQuotes = false
                local depth = 0
                
                for i = 1, #content do
                    local char = content:sub(i, i)
                    if char == '"' and (i == 1 or content:sub(i-1, i-1) ~= '\\') then
                        inQuotes = not inQuotes
                    elseif not inQuotes then
                        if char == '{' or char == '[' then
                            depth = depth + 1
                        elseif char == '}' or char == ']' then
                            depth = depth - 1
                        elseif char == ',' and depth == 0 then
                            table.insert(pairs, current)
                            current = ""
                            goto continue
                        end
                    end
                    current = current .. char
                    ::continue::
                end
                if current ~= "" then
                    table.insert(pairs, current)
                end
                
                -- Parse key-value pairs
                for _, pair in ipairs(pairs) do
                    local key, value = pair:match('^%s*"([^"]+)"%s*:%s*(.+)%s*$')
                    if key and value then
                        -- Parse value based on type
                        if value == "true" then
                            result[key] = true
                        elseif value == "false" then
                            result[key] = false
                        elseif value == "null" then
                            result[key] = nil
                        elseif value:match('^".*"$') then
                            result[key] = value:sub(2, -2) -- Remove quotes
                        elseif value:match('^%d+%.?%d*$') then
                            result[key] = tonumber(value)
                        elseif value:match('^%s*{.*}%s*$') then
                            -- Recursive object parsing
                            result[key] = json.decode(value)
                        else
                            result[key] = value
                        end
                    end
                end
            end
            return result
        end
        
        -- Fallback: return empty table for unparseable input
        return {}
    end
}

-- Initialize process state
if not State then
    State = {
        initialized = true,
        formPersistenceTracking = {},
        activeTimers = {},
        persistentForms = {}
    }
end

-- Embedded form persistence database
local formPersistenceDatabase = {
    -- Shaymin: Conditional day/night and status dependent forms
    [492] = {
        speciesName = "Shaymin",
        forms = {
            sky = {
                type = "conditional",
                persistThroughSave = true,
                expirationCondition = "night_time_or_frozen",
                revertToForm = "land",
                duration = -1, -- Until condition met
                activeConditions = {"is_day", "not_frozen"},
                priority = 3
            },
            land = {
                type = "permanent",
                persistThroughSave = true,
                expirationCondition = "none",
                duration = -1,
                priority = 1
            }
        }
    },
    
    -- Hoopa: Timed form with 3-day duration
    [720] = {
        speciesName = "Hoopa",
        forms = {
            unbound = {
                type = "timed",
                persistThroughSave = true,
                duration = 259200, -- 3 days in seconds
                revertToForm = "confined",
                expirationCondition = "timer_expiry",
                priority = 2
            },
            confined = {
                type = "permanent",
                persistThroughSave = true,
                expirationCondition = "none",
                duration = -1,
                priority = 1
            }
        }
    },
    
    -- Dialga: Item-dependent permanent forms
    [483] = {
        speciesName = "Dialga",
        forms = {
            origin = {
                type = "permanent",
                persistThroughSave = true,
                duration = -1,
                requiredItem = "ADAMANT_ORB",
                expirationCondition = "item_removed",
                revertToForm = "altered",
                priority = 1
            },
            altered = {
                type = "permanent",
                persistThroughSave = true,
                expirationCondition = "none",
                duration = -1,
                priority = 1
            }
        }
    },
    
    -- Palkia: Item-dependent permanent forms
    [484] = {
        speciesName = "Palkia",
        forms = {
            origin = {
                type = "permanent",
                persistThroughSave = true,
                duration = -1,
                requiredItem = "LUSTROUS_ORB",
                expirationCondition = "item_removed",
                revertToForm = "altered",
                priority = 1
            },
            altered = {
                type = "permanent",
                persistThroughSave = true,
                expirationCondition = "none",
                duration = -1,
                priority = 1
            }
        }
    },
    
    -- Giratina: Item or location dependent forms
    [487] = {
        speciesName = "Giratina",
        forms = {
            origin = {
                type = "permanent",
                persistThroughSave = true,
                duration = -1,
                requiredItem = "GRISEOUS_ORB",
                expirationCondition = "item_removed_or_location_change",
                revertToForm = "altered",
                priority = 1
            },
            altered = {
                type = "permanent",
                persistThroughSave = true,
                expirationCondition = "none",
                duration = -1,
                priority = 1
            }
        }
    },
    
    -- Castform: Weather-dependent conditional forms
    [351] = {
        speciesName = "Castform",
        forms = {
            sunny = {
                type = "conditional",
                persistThroughSave = false,
                expirationCondition = "weather_change_or_battle_end",
                revertToForm = "normal",
                duration = -1,
                activeConditions = {"sunny_weather"},
                priority = 3
            },
            rainy = {
                type = "conditional", 
                persistThroughSave = false,
                expirationCondition = "weather_change_or_battle_end",
                revertToForm = "normal",
                duration = -1,
                activeConditions = {"rain_weather"},
                priority = 3
            },
            snowy = {
                type = "conditional",
                persistThroughSave = false, 
                expirationCondition = "weather_change_or_battle_end",
                revertToForm = "normal",
                duration = -1,
                activeConditions = {"hail_weather"},
                priority = 3
            },
            normal = {
                type = "permanent",
                persistThroughSave = true,
                expirationCondition = "none",
                duration = -1,
                priority = 1
            }
        }
    },
    
    -- Universal Mega Evolution rules
    ["MEGA_EVOLUTION"] = {
        type = "battle_only",
        persistThroughSave = false,
        duration = 1, -- One battle
        expirationCondition = "battle_end",
        revertToForm = "base",
        priority = 4
    },
    
    -- Universal Primal Reversion rules
    ["PRIMAL_REVERSION"] = {
        type = "battle_only",
        persistThroughSave = false,
        duration = 1, -- One battle
        expirationCondition = "battle_end",
        revertToForm = "base",
        priority = 4
    }
}

-- Utility functions
local function getCurrentTime()
    return msg.Timestamp or 0
end

local function getFormPersistenceRule(speciesId, formType)
    local species = formPersistenceDatabase[tonumber(speciesId)]
    if species and species.forms and species.forms[formType] then
        return species.forms[formType]
    end
    
    -- Check universal rules
    if formType == "mega" then
        return formPersistenceDatabase["MEGA_EVOLUTION"]
    elseif formType == "primal" then
        return formPersistenceDatabase["PRIMAL_REVERSION"]
    end
    
    return nil
end

local function trackFormDuration(pokemon, formType, durationData)
    local persistenceRule = getFormPersistenceRule(pokemon.speciesId, formType)
    if not persistenceRule then
        return false, "No persistence rule found for form"
    end
    
    pokemon.formPersistenceData = {
        startTime = getCurrentTime(),
        duration = durationData.duration or persistenceRule.duration,
        expirationCondition = persistenceRule.expirationCondition,
        revertToForm = persistenceRule.revertToForm,
        persistThroughSave = persistenceRule.persistThroughSave,
        type = persistenceRule.type,
        priority = persistenceRule.priority or 1,
        requiredItem = persistenceRule.requiredItem,
        activeConditions = persistenceRule.activeConditions
    }
    
    return true, persistenceRule
end

local function isTimerExpired(formData)
    if not formData or formData.duration == -1 then
        return false
    end
    
    local currentTime = getCurrentTime()
    local elapsed = currentTime - formData.startTime
    return elapsed >= formData.duration
end

local function hasRequiredItem(pokemon, itemId)
    if not itemId then return true end
    -- Check if pokemon has required item
    return pokemon.heldItem == itemId
end

local function evaluateFormReversion(pokemon, currentConditions)
    local formData = pokemon.formPersistenceData
    if not formData then return false, nil end
    
    local expirationCondition = formData.expirationCondition
    
    if expirationCondition == "battle_end" and currentConditions.battleEnded then
        return true, formData.revertToForm
    elseif expirationCondition == "timer_expiry" and isTimerExpired(formData) then
        return true, formData.revertToForm
    elseif expirationCondition == "item_removed" and not hasRequiredItem(pokemon, formData.requiredItem) then
        return true, formData.revertToForm
    elseif expirationCondition == "night_time_or_frozen" then
        if currentConditions.isNight or currentConditions.isFrozen then
            return true, formData.revertToForm
        end
    elseif expirationCondition == "weather_change_or_battle_end" then
        if currentConditions.weatherChanged or currentConditions.battleEnded then
            return true, formData.revertToForm
        end
    end
    
    return false, nil
end

local function resolveFormPriorityConflicts(pokemon, pendingFormChanges)
    -- Priority order: permanent (1) > timed (2) > conditional (3) > battle_only (4)
    local highestPriority = 999
    local selectedForm = nil
    
    for _, formChange in ipairs(pendingFormChanges) do
        local persistenceRule = getFormPersistenceRule(pokemon.speciesId, formChange.formType)
        if persistenceRule and persistenceRule.priority < highestPriority then
            highestPriority = persistenceRule.priority
            selectedForm = formChange
        end
    end
    
    return selectedForm
end

local function revertToBaseForm(pokemon)
    local formData = pokemon.formPersistenceData
    if formData and formData.revertToForm then
        pokemon.currentForm = formData.revertToForm
    else
        pokemon.currentForm = "base"
    end
    pokemon.formPersistenceData = nil
end

local function clearFormPersistenceData(pokemon)
    pokemon.formPersistenceData = nil
end

-- Handler: Process Form Persistence
Handlers.add("process-form-persistence",
    Handlers.utils.hasMatchingTag("Action", "ProcessFormPersistence"),
    function(msg)
        local pokemonId = msg.PokemonId or msg.Id
        local formType = msg.FormType
        local durationType = msg.Duration
        local persistenceCondition = msg.PersistenceCondition
        
        if not pokemonId or not formType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId and FormType required"
            })
            return
        end
        
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end
        
        local pokemon = gameState.pokemon or {
            id = pokemonId,
            speciesId = msg.SpeciesId or "1",
            currentForm = formType
        }
        
        local durationData = {
            duration = tonumber(durationType) or -1
        }
        
        local success, result = trackFormDuration(pokemon, formType, durationData)
        
        if success then
            gameState.pokemon = pokemon
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "true",
                PokemonId = pokemonId,
                FormType = formType,
                PersistenceType = result.type,
                Duration = tostring(durationData.duration),
                Data = json.encode(gameState)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result or "Failed to track form duration"
            })
        end
    end
)

-- Handler: Check Form Expiration
Handlers.add("check-form-expiration",
    Handlers.utils.hasMatchingTag("Action", "CheckFormExpiration"),
    function(msg)
        local pokemonId = msg.PokemonId or msg.Id
        
        if not pokemonId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required"
            })
            return
        end
        
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end
        
        local pokemon = gameState.pokemon
        if not pokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon not found"
            })
            return
        end
        
        local currentConditions = {
            battleEnded = msg.BattleEnded == "true",
            weatherChanged = msg.WeatherChanged == "true",
            isNight = msg.IsNight == "true",
            isFrozen = msg.IsFrozen == "true"
        }
        
        local shouldRevert, revertForm = evaluateFormReversion(pokemon, currentConditions)
        
        if shouldRevert then
            pokemon.currentForm = revertForm
            clearFormPersistenceData(pokemon)
            gameState.pokemon = pokemon
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormReverted = "true",
                PokemonId = pokemonId,
                NewForm = revertForm,
                Data = json.encode(gameState)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormReverted = "false",
                PokemonId = pokemonId,
                CurrentForm = pokemon.currentForm,
                Data = json.encode(gameState)
            })
        end
    end
)

-- Handler: Save Form State
Handlers.add("save-form-state",
    Handlers.utils.hasMatchingTag("Action", "SaveFormState"),
    function(msg)
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end
        
        local pokemon = gameState.pokemon
        if not pokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon not found in game state"
            })
            return
        end
        
        local formData = pokemon.formPersistenceData
        if not formData or not formData.persistThroughSave then
            -- Revert non-persistent forms before save
            revertToBaseForm(pokemon)
            gameState.pokemon = pokemon
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormPersisted = "false",
                Reason = "Non-persistent form reverted",
                Data = json.encode(gameState)
            })
            return
        end
        
        -- Validate persistent form data
        if formData.requiredItem and not hasRequiredItem(pokemon, formData.requiredItem) then
            revertToBaseForm(pokemon)
            gameState.pokemon = pokemon
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormPersisted = "false",
                Reason = "Required item missing",
                Data = json.encode(gameState)
            })
            return
        end
        
        -- Store persistent form data
        gameState.persistentForms = gameState.persistentForms or {}
        gameState.persistentForms[pokemon.id] = {
            form = pokemon.currentForm,
            persistenceData = formData,
            timestamp = getCurrentTime()
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            FormPersisted = "true",
            PokemonId = pokemon.id,
            PersistedForm = pokemon.currentForm,
            Data = json.encode(gameState)
        })
    end
)

-- Handler: Load Form State
Handlers.add("load-form-state",
    Handlers.utils.hasMatchingTag("Action", "LoadFormState"),
    function(msg)
        local pokemonId = msg.PokemonId or msg.Id
        
        if not pokemonId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required"
            })
            return
        end
        
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end
        
        local pokemon = gameState.pokemon
        if not pokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon not found"
            })
            return
        end
        
        local persistentForms = gameState.persistentForms or {}
        local savedForm = persistentForms[pokemonId]
        
        if savedForm then
            -- Validate required items still exist
            if savedForm.persistenceData.requiredItem and not hasRequiredItem(pokemon, savedForm.persistenceData.requiredItem) then
                -- Item missing, revert form
                revertToBaseForm(pokemon)
                gameState.pokemon = pokemon
                
                ao.send({
                    Target = msg.From,
                    Action = "SaveState",
                    FormRestored = "false",
                    Reason = "Required item missing",
                    Data = json.encode(gameState)
                })
                return
            end
            
            -- Check if form expired during save
            if isTimerExpired(savedForm.persistenceData) then
                revertToBaseForm(pokemon)
                gameState.pokemon = pokemon
                
                ao.send({
                    Target = msg.From,
                    Action = "SaveState",
                    FormRestored = "false",
                    Reason = "Form timer expired",
                    Data = json.encode(gameState)
                })
                return
            end
            
            -- Restore form
            pokemon.currentForm = savedForm.form
            pokemon.formPersistenceData = savedForm.persistenceData
            gameState.pokemon = pokemon
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormRestored = "true",
                PokemonId = pokemonId,
                RestoredForm = savedForm.form,
                Data = json.encode(gameState)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormRestored = "false",
                Reason = "No persistent form found",
                Data = json.encode(gameState)
            })
        end
    end
)

-- Handler: Revert Form
Handlers.add("revert-form",
    Handlers.utils.hasMatchingTag("Action", "RevertForm"),
    function(msg)
        local pokemonId = msg.PokemonId or msg.Id
        local cancellationTrigger = msg.CancellationTrigger or "manual"
        
        if not pokemonId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required"
            })
            return
        end
        
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end
        
        local pokemon = gameState.pokemon
        if not pokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon not found"
            })
            return
        end
        
        local formData = pokemon.formPersistenceData
        if not formData then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                FormReverted = "false",
                Reason = "No active form to revert",
                Data = json.encode(gameState)
            })
            return
        end
        
        revertToBaseForm(pokemon)
        gameState.pokemon = pokemon
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            FormReverted = "true",
            PokemonId = pokemonId,
            RevertedTo = pokemon.currentForm,
            CancellationTrigger = cancellationTrigger,
            Data = json.encode(gameState)
        })
    end
)

-- Handler: Validate Form Conditions
Handlers.add("validate-form-conditions",
    Handlers.utils.hasMatchingTag("Action", "ValidateFormConditions"),
    function(msg)
        local pokemonId = msg.PokemonId or msg.Id
        local formType = msg.FormType
        
        if not pokemonId or not formType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId and FormType required"
            })
            return
        end
        
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end
        
        local pokemon = gameState.pokemon or {
            id = pokemonId,
            speciesId = msg.SpeciesId or "1"
        }
        
        local persistenceRule = getFormPersistenceRule(pokemon.speciesId, formType)
        if not persistenceRule then
            ao.send({
                Target = msg.From,
                Action = "ValidationResult",
                Valid = "false",
                Reason = "No persistence rule found",
                FormType = formType
            })
            return
        end
        
        -- Validate required conditions
        local valid = true
        local reason = ""
        
        if persistenceRule.requiredItem and not hasRequiredItem(pokemon, persistenceRule.requiredItem) then
            valid = false
            reason = "Required item missing: " .. persistenceRule.requiredItem
        end
        
        if persistenceRule.activeConditions then
            -- Check active conditions based on current game state
            local currentConditions = {
                isDay = msg.IsDay == "true",
                notFrozen = msg.IsFrozen ~= "true",
                sunnyWeather = msg.Weather == "sunny",
                rainWeather = msg.Weather == "rain",
                hailWeather = msg.Weather == "hail"
            }
            
            for _, condition in ipairs(persistenceRule.activeConditions) do
                if not currentConditions[condition] then
                    valid = false
                    reason = "Active condition not met: " .. condition
                    break
                end
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "ValidationResult",
            Valid = tostring(valid),
            Reason = reason,
            FormType = formType,
            PersistenceType = persistenceRule.type,
            Priority = tostring(persistenceRule.priority or 1)
        })
    end
)

-- ADP v1.0 Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Form Persistence Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "ProcessFormPersistence",
                        "CheckFormExpiration", 
                        "SaveFormState",
                        "LoadFormState",
                        "RevertForm",
                        "ValidateFormConditions"
                    },
                    messageSchemas = {
                        ProcessFormPersistence = {
                            required = {"Action", "PokemonId", "FormType"},
                            optional = {"Duration", "PersistenceCondition", "Data"}
                        },
                        CheckFormExpiration = {
                            required = {"Action", "PokemonId"},
                            optional = {"BattleEnded", "WeatherChanged", "IsNight", "IsFrozen", "Data"}
                        },
                        SaveFormState = {
                            required = {"Action", "Data"},
                            optional = {}
                        },
                        LoadFormState = {
                            required = {"Action", "PokemonId", "Data"},
                            optional = {}
                        },
                        RevertForm = {
                            required = {"Action", "PokemonId"},
                            optional = {"CancellationTrigger", "Data"}
                        },
                        ValidateFormConditions = {
                            required = {"Action", "PokemonId", "FormType"},
                            optional = {"SpeciesId", "IsDay", "IsFrozen", "Weather", "Data"}
                        }
                    }
                },
                handlers = {
                    "ProcessFormPersistence",
                    "CheckFormExpiration",
                    "SaveFormState", 
                    "LoadFormState",
                    "RevertForm",
                    "ValidateFormConditions",
                    "Info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Manages temporary vs permanent Pokemon form changes with duration tracking, save/load persistence, reversion mechanics, and priority resolution"
                }
            })
        })
    end
)

print("Form Persistence Engine initialized successfully.")