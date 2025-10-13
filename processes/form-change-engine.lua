-- Form Change Engine Process
-- Manages Pokemon form transformations with ADP v1.0 compliance

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

-- Embedded Form Change Database
local formChangeDatabase = {
    -- Darmanitan (555)
    [555] = {
        name = "Darmanitan",
        triggers = {
            {type = "hp", threshold = 0.5, ability = "ZEN_MODE"}
        },
        forms = {
            [0] = {
                name = "standard",
                types = {"FIRE"},
                stats = {hp = 105, attack = 140, defense = 55, spAttack = 30, spDefense = 55, speed = 95},
                abilities = {"SHEER_FORCE", "ZEN_MODE"}
            },
            [1] = {
                name = "zen",
                types = {"FIRE", "PSYCHIC"},
                stats = {hp = 105, attack = 30, defense = 105, spAttack = 140, spDefense = 105, speed = 55},
                abilities = {"ZEN_MODE"}
            }
        },
        persistence = "battle"
    },
    
    -- Castform (351)
    [351] = {
        name = "Castform",
        triggers = {
            {type = "weather", ability = "FORECAST"}
        },
        forms = {
            [0] = {
                name = "normal",
                types = {"NORMAL"},
                stats = {hp = 70, attack = 70, defense = 70, spAttack = 70, spDefense = 70, speed = 70},
                weather = nil
            },
            [1] = {
                name = "sunny",
                types = {"FIRE"},
                stats = {hp = 70, attack = 70, defense = 70, spAttack = 70, spDefense = 70, speed = 70},
                weather = "SUNNY"
            },
            [2] = {
                name = "rainy",
                types = {"WATER"},
                stats = {hp = 70, attack = 70, defense = 70, spAttack = 70, spDefense = 70, speed = 70},
                weather = "RAIN"
            },
            [3] = {
                name = "snowy",
                types = {"ICE"},
                stats = {hp = 70, attack = 70, defense = 70, spAttack = 70, spDefense = 70, speed = 70},
                weather = "SNOW"
            }
        },
        persistence = "temporary"
    },
    
    -- Meloetta (648)
    [648] = {
        name = "Meloetta",
        triggers = {
            {type = "move", moveId = "RELIC_SONG"}
        },
        forms = {
            [0] = {
                name = "aria",
                types = {"NORMAL", "PSYCHIC"},
                stats = {hp = 100, attack = 77, defense = 77, spAttack = 128, spDefense = 128, speed = 90},
                abilities = {"SERENE_GRACE"}
            },
            [1] = {
                name = "pirouette",
                types = {"NORMAL", "FIGHTING"},
                stats = {hp = 100, attack = 128, defense = 90, spAttack = 77, spDefense = 77, speed = 128},
                abilities = {"SERENE_GRACE"}
            }
        },
        persistence = "temporary"
    },
    
    -- Aegislash (681)
    [681] = {
        name = "Aegislash",
        triggers = {
            {type = "pre_move", ability = "STANCE_CHANGE"}
        },
        forms = {
            [0] = {
                name = "shield",
                types = {"STEEL", "GHOST"},
                stats = {hp = 60, attack = 50, defense = 150, spAttack = 50, spDefense = 150, speed = 60},
                abilities = {"STANCE_CHANGE"}
            },
            [1] = {
                name = "blade",
                types = {"STEEL", "GHOST"},
                stats = {hp = 60, attack = 150, defense = 50, spAttack = 150, spDefense = 50, speed = 60},
                abilities = {"STANCE_CHANGE"}
            }
        },
        persistence = "battle"
    },
    
    -- Cramorant (845)
    [845] = {
        name = "Cramorant",
        triggers = {
            {type = "ability_move", ability = "GULP_MISSILE", moves = {"SURF", "DIVE"}}
        },
        forms = {
            [0] = {
                name = "normal",
                types = {"FLYING", "WATER"},
                stats = {hp = 70, attack = 85, defense = 55, spAttack = 85, spDefense = 95, speed = 85},
                abilities = {"GULP_MISSILE"}
            },
            [1] = {
                name = "gulping",
                types = {"FLYING", "WATER"},
                stats = {hp = 70, attack = 85, defense = 55, spAttack = 85, spDefense = 95, speed = 85},
                abilities = {"GULP_MISSILE"},
                hpThreshold = 0.5
            },
            [2] = {
                name = "gorging",
                types = {"FLYING", "WATER"},
                stats = {hp = 70, attack = 85, defense = 55, spAttack = 85, spDefense = 95, speed = 85},
                abilities = {"GULP_MISSILE"},
                hpThreshold = 0
            }
        },
        persistence = "battle"
    }
}

-- State tracking for active Pokemon forms
local pokemonForms = {}

-- Helper Functions

-- Evaluate HP-based trigger
local function evaluateHpTrigger(pokemon, threshold)
    if not pokemon or not pokemon.hp or not pokemon.maxHp then
        return false
    end
    local hpRatio = pokemon.hp / pokemon.maxHp
    return hpRatio <= threshold
end

-- Evaluate weather-based trigger
local function evaluateWeatherTrigger(pokemon, weatherRequired, currentWeather, isWeatherSuppressed, isAbilitySuppressed)
    if isWeatherSuppressed or isAbilitySuppressed then
        return false
    end
    if not weatherRequired then
        -- Normal form when no specific weather
        return currentWeather == nil or currentWeather == "NONE"
    end
    return currentWeather == weatherRequired
end

-- Evaluate move-based trigger
local function evaluateMoveTrigger(moveUsed, triggerMove)
    return moveUsed == triggerMove
end

-- Recalculate stats preserving HP ratio
local function recalculateStats(pokemon, newFormStats)
    if not pokemon or not newFormStats then
        return nil
    end
    
    -- Validate input data structure
    if type(pokemon) ~= "table" then
        return nil
    end
    
    if type(newFormStats) ~= "table" then
        return nil
    end
    
    -- Validate required stat fields
    local requiredStats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
    for _, stat in ipairs(requiredStats) do
        if not newFormStats[stat] or type(newFormStats[stat]) ~= "number" or newFormStats[stat] < 1 then
            return nil
        end
    end
    
    -- Preserve HP ratio with robust fallback
    local hpRatio = 1
    if pokemon.hp and pokemon.stats and pokemon.stats.hp and type(pokemon.hp) == "number" and type(pokemon.stats.hp) == "number" and pokemon.stats.hp > 0 then
        hpRatio = pokemon.hp / pokemon.stats.hp
        -- Ensure HP ratio is valid
        if hpRatio < 0 then hpRatio = 0 end
        if hpRatio > 1 then hpRatio = 1 end
    elseif pokemon.hp and type(pokemon.hp) == "number" and pokemon.hp > 0 then
        -- Fallback: assume current HP is at max if no stats available
        hpRatio = 1
    end
    
    -- Update stats with new base values
    local updatedStats = {
        hp = newFormStats.hp,
        attack = newFormStats.attack,
        defense = newFormStats.defense,
        spAttack = newFormStats.spAttack,
        spDefense = newFormStats.spDefense,
        speed = newFormStats.speed
    }
    
    -- Calculate new current HP with bounds checking
    local newHp = math.floor(updatedStats.hp * hpRatio)
    if newHp < 1 then newHp = 1 end
    if newHp > updatedStats.hp then newHp = updatedStats.hp end
    
    -- Final validation
    if newHp <= 0 or newHp > updatedStats.hp then
        newHp = 1 -- Safe fallback
    end
    
    return {
        stats = updatedStats,
        hp = newHp
    }
end

-- Get form persistence type
local function getFormPersistence(speciesId)
    local formData = formChangeDatabase[speciesId]
    if formData then
        return formData.persistence
    end
    return "temporary"
end

-- Find appropriate form based on trigger
local function findTargetForm(speciesId, triggerType, triggerData, pokemon)
    local formData = formChangeDatabase[speciesId]
    if not formData then
        return nil
    end
    
    -- Handle HP triggers (Darmanitan)
    if triggerType == "hp" then
        for _, trigger in ipairs(formData.triggers) do
            if trigger.type == "hp" then
                local shouldTransform = evaluateHpTrigger(pokemon, trigger.threshold)
                return shouldTransform and 1 or 0
            end
        end
    end
    
    -- Handle weather triggers (Castform)
    if triggerType == "weather" then
        local currentWeather = triggerData.weather
        for formIndex, form in pairs(formData.forms) do
            if form.weather == currentWeather then
                return formIndex
            end
        end
        return 0 -- Default to normal form
    end
    
    -- Handle move triggers (Meloetta)
    if triggerType == "move" then
        local currentForm = pokemonForms[pokemon.id] or 0
        -- Toggle between forms
        return currentForm == 0 and 1 or 0
    end
    
    -- Handle pre-move triggers (Aegislash)
    if triggerType == "pre_move" then
        local moveCategory = triggerData.moveCategory
        if moveCategory == "PHYSICAL" or moveCategory == "SPECIAL" then
            return 1 -- Blade form
        else
            return 0 -- Shield form
        end
    end
    
    -- Handle ability-move triggers (Cramorant)
    if triggerType == "ability_move" then
        local hpRatio = pokemon.hp / pokemon.maxHp
        if hpRatio >= 0.5 then
            return 1 -- Gulping form
        else
            return 2 -- Gorging form
        end
    end
    
    return nil
end

-- Message Handlers

-- Process form change request
Handlers.add(
    "ProcessFormChange",
    Handlers.utils.hasMatchingTag("Action", "ProcessFormChange"),
    function(msg)
        -- Extract parameters
        local pokemonId = msg.PokemonId or msg.Tags.PokemonId
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        local triggerType = msg.TriggerType or msg.Tags.TriggerType
        local triggerData = msg.Data and json.decode(msg.Data) or {}
        
        -- Validate required parameters
        if not pokemonId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId and SpeciesId are required"
            })
            return
        end
        
        -- Check if species has form changes
        local formData = formChangeDatabase[speciesId]
        if not formData then
            ao.send({
                Target = msg.From,
                Action = "FormChangeResult",
                Success = "false",
                PokemonId = pokemonId,
                Reason = "Species does not support form changes"
            })
            return
        end
        
        -- Parse Pokemon data with comprehensive validation
        local pokemon = triggerData.pokemon
        if not pokemon or type(pokemon) ~= "table" then
            pokemon = {
                id = pokemonId,
                hp = tonumber(triggerData.hp) or 100,
                maxHp = tonumber(triggerData.maxHp) or 100,
                stats = triggerData.stats
            }
        end
        
        -- Validate critical Pokemon data
        if not pokemon.id then
            pokemon.id = pokemonId
        end
        
        if not pokemon.hp or type(pokemon.hp) ~= "number" or pokemon.hp < 0 then
            pokemon.hp = 100
        end
        
        if not pokemon.maxHp or type(pokemon.maxHp) ~= "number" or pokemon.maxHp <= 0 then
            pokemon.maxHp = math.max(pokemon.hp, 100)
        end
        
        -- Ensure HP doesn't exceed maxHP
        if pokemon.hp > pokemon.maxHp then
            pokemon.hp = pokemon.maxHp
        end
        
        -- Find target form
        local targetForm = findTargetForm(speciesId, triggerType, triggerData, pokemon)
        if not targetForm then
            ao.send({
                Target = msg.From,
                Action = "FormChangeResult",
                Success = "false",
                PokemonId = pokemonId,
                Reason = "No valid form change for trigger"
            })
            return
        end
        
        -- Get current form
        local currentForm = pokemonForms[pokemonId] or 0
        
        -- Check if already in target form
        if currentForm == targetForm then
            ao.send({
                Target = msg.From,
                Action = "FormChangeResult",
                Success = "false",
                PokemonId = pokemonId,
                Reason = "Already in target form"
            })
            return
        end
        
        -- Get new form data
        local newForm = formData.forms[targetForm]
        if not newForm then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid target form"
            })
            return
        end
        
        -- Recalculate stats with error handling
        local statUpdate = recalculateStats(pokemon, newForm.stats)
        if not statUpdate then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Failed to recalculate stats for form change"
            })
            return
        end
        
        -- Update form tracking
        pokemonForms[pokemonId] = targetForm
        
        -- Send success response
        ao.send({
            Target = msg.From,
            Action = "FormChangeResult",
            Success = "true",
            PokemonId = pokemonId,
            SpeciesId = tostring(speciesId),
            FormIndex = tostring(targetForm),
            FormName = newForm.name,
            Data = json.encode({
                form = newForm,
                stats = statUpdate.stats,
                hp = statUpdate.hp,
                persistence = formData.persistence,
                types = newForm.types,
                abilities = newForm.abilities
            })
        })
    end
)

-- Evaluate if form change should occur
Handlers.add(
    "EvaluateTrigger",
    Handlers.utils.hasMatchingTag("Action", "EvaluateTrigger"),
    function(msg)
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        local triggerType = msg.TriggerType or msg.Tags.TriggerType
        local triggerData = msg.Data and json.decode(msg.Data) or {}
        
        if not speciesId or not triggerType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId and TriggerType are required"
            })
            return
        end
        
        local formData = formChangeDatabase[speciesId]
        if not formData then
            ao.send({
                Target = msg.From,
                Action = "TriggerResult",
                ShouldChange = "false",
                Reason = "Species has no form changes"
            })
            return
        end
        
        local shouldChange = false
        local targetForm = nil
        
        for _, trigger in ipairs(formData.triggers) do
            if trigger.type == triggerType then
                if triggerType == "hp" then
                    shouldChange = evaluateHpTrigger(triggerData.pokemon, trigger.threshold)
                    targetForm = shouldChange and 1 or 0
                elseif triggerType == "weather" then
                    shouldChange = true
                    targetForm = 0 -- Will be determined by actual weather
                elseif triggerType == "move" then
                    shouldChange = triggerData.moveId == trigger.moveId
                    targetForm = nil -- Toggle logic
                else
                    shouldChange = true
                    targetForm = nil
                end
                break
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "TriggerResult",
            ShouldChange = tostring(shouldChange),
            TargetForm = targetForm and tostring(targetForm) or "",
            TriggerType = triggerType
        })
    end
)

-- Recalculate stats for form change
Handlers.add(
    "RecalculateStats",
    Handlers.utils.hasMatchingTag("Action", "RecalculateStats"),
    function(msg)
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        local formIndex = tonumber(msg.FormIndex or msg.Tags.FormIndex or 0)
        local pokemonData = msg.Data and json.decode(msg.Data) or {}
        
        if not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId is required"
            })
            return
        end
        
        local formData = formChangeDatabase[speciesId]
        if not formData or not formData.forms[formIndex] then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid species or form"
            })
            return
        end
        
        local newForm = formData.forms[formIndex]
        local statUpdate = recalculateStats(pokemonData, newForm.stats)
        
        ao.send({
            Target = msg.From,
            Action = "StatsRecalculated",
            Success = "true",
            Data = json.encode(statUpdate)
        })
    end
)

-- Update ability for form
Handlers.add(
    "UpdateAbility",
    Handlers.utils.hasMatchingTag("Action", "UpdateAbility"),
    function(msg)
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        local formIndex = tonumber(msg.FormIndex or msg.Tags.FormIndex or 0)
        
        if not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId is required"
            })
            return
        end
        
        local formData = formChangeDatabase[speciesId]
        if not formData or not formData.forms[formIndex] then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid species or form"
            })
            return
        end
        
        local abilities = formData.forms[formIndex].abilities or {}
        
        ao.send({
            Target = msg.From,
            Action = "AbilityUpdated",
            Success = "true",
            Abilities = json.encode(abilities),
            PrimaryAbility = abilities[1] or ""
        })
    end
)

-- Update move pool for form
Handlers.add(
    "UpdateMovePool",
    Handlers.utils.hasMatchingTag("Action", "UpdateMovePool"),
    function(msg)
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        local formIndex = tonumber(msg.FormIndex or msg.Tags.FormIndex or 0)
        local currentMoves = msg.Data and json.decode(msg.Data) or {}
        
        if not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId is required"
            })
            return
        end
        
        -- For this implementation, moves don't change between forms
        -- but this handler exists for future expansion
        ao.send({
            Target = msg.From,
            Action = "MovePoolUpdated",
            Success = "true",
            MovesChanged = "false",
            Moves = json.encode(currentMoves)
        })
    end
)

-- Get current form data
Handlers.add(
    "GetFormData",
    Handlers.utils.hasMatchingTag("Action", "GetFormData"),
    function(msg)
        local pokemonId = msg.PokemonId or msg.Tags.PokemonId
        local speciesId = tonumber(msg.SpeciesId or msg.Tags.SpeciesId)
        
        if not pokemonId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId and SpeciesId are required"
            })
            return
        end
        
        local formData = formChangeDatabase[speciesId]
        if not formData then
            ao.send({
                Target = msg.From,
                Action = "FormData",
                HasForms = "false"
            })
            return
        end
        
        local currentForm = pokemonForms[pokemonId] or 0
        local form = formData.forms[currentForm]
        
        ao.send({
            Target = msg.From,
            Action = "FormData",
            HasForms = "true",
            PokemonId = pokemonId,
            SpeciesId = tostring(speciesId),
            CurrentForm = tostring(currentForm),
            Data = json.encode({
                formIndex = currentForm,
                formName = form and form.name or "unknown",
                types = form and form.types or {},
                stats = form and form.stats or {},
                abilities = form and form.abilities or {},
                persistence = formData.persistence
            })
        })
    end
)

-- ADP v1.0 Info Handler
Handlers.add(
    "Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local info = {
            Name = "Form Change Engine",
            Version = "1.0.0",
            Description = "Manages Pokemon form transformations with trigger evaluation and stat recalculation",
            Protocol = "ADP",
            ProtocolVersion = "1.0",
            Handlers = {
                {
                    Action = "ProcessFormChange",
                    Description = "Process a form change request for a Pokemon",
                    Parameters = {
                        {name = "PokemonId", type = "string", required = true},
                        {name = "SpeciesId", type = "number", required = true},
                        {name = "TriggerType", type = "string", required = true},
                        {name = "Data", type = "json", required = false}
                    }
                },
                {
                    Action = "EvaluateTrigger",
                    Description = "Evaluate if a form change should occur",
                    Parameters = {
                        {name = "SpeciesId", type = "number", required = true},
                        {name = "TriggerType", type = "string", required = true},
                        {name = "Data", type = "json", required = false}
                    }
                },
                {
                    Action = "RecalculateStats",
                    Description = "Recalculate Pokemon stats for a form",
                    Parameters = {
                        {name = "SpeciesId", type = "number", required = true},
                        {name = "FormIndex", type = "number", required = false},
                        {name = "Data", type = "json", required = false}
                    }
                },
                {
                    Action = "UpdateAbility",
                    Description = "Get abilities for a specific form",
                    Parameters = {
                        {name = "SpeciesId", type = "number", required = true},
                        {name = "FormIndex", type = "number", required = false}
                    }
                },
                {
                    Action = "UpdateMovePool",
                    Description = "Update move pool for a form",
                    Parameters = {
                        {name = "SpeciesId", type = "number", required = true},
                        {name = "FormIndex", type = "number", required = false},
                        {name = "Data", type = "json", required = false}
                    }
                },
                {
                    Action = "GetFormData",
                    Description = "Get current form data for a Pokemon",
                    Parameters = {
                        {name = "PokemonId", type = "string", required = true},
                        {name = "SpeciesId", type = "number", required = true}
                    }
                },
                {
                    Action = "Info",
                    Description = "Get process information and capabilities",
                    Parameters = {}
                }
            },
            SupportedSpecies = {
                {id = 555, name = "Darmanitan", triggers = {"hp"}},
                {id = 351, name = "Castform", triggers = {"weather"}},
                {id = 648, name = "Meloetta", triggers = {"move"}},
                {id = 681, name = "Aegislash", triggers = {"pre_move"}},
                {id = 845, name = "Cramorant", triggers = {"ability_move"}}
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "Info",
            Data = json.encode(info)
        })
    end
)

-- Initialize message
print("Form Change Engine Process initialized with ADP v1.0 compliance")

-- Ensure proper AO global initialization
if ao and ao.id then
    print("AO Process ID: " .. ao.id)
end