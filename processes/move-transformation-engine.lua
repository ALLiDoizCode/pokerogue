-- JSON module for AO processes
local json = json or {
    encode = function(obj)
        if type(obj) == "table" then
            local items = {}
            for k, v in pairs(obj) do
                if type(v) == "string" then
                    table.insert(items, string.format('"%s":"%s"', k, v))
                elseif type(v) == "number" then
                    table.insert(items, string.format('"%s":%s', k, v))
                elseif type(v) == "boolean" then
                    table.insert(items, string.format('"%s":%s', k, v and "true" or "false"))
                elseif type(v) == "table" then
                    table.insert(items, string.format('"%s":"%s"', k, tostring(v)))
                end
            end
            return "{" .. table.concat(items, ",") .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj .. '"'
        else
            return tostring(obj)
        end
    end,
    decode = function(str)
        -- In AO environment, json module provides proper decode
        -- For testing, return a simple table
        if str and str ~= "" then
            return {decoded = true, original = str}
        end
        return {}
    end
}

-- Move Transformation Engine - AO Process for Pokemon move-based form changes
-- Implements Aegislash stance change, Meloetta Relic Song, Transform move, and duration tracking
-- Based on TypeScript implementation analysis from src/data/pokemon-forms/form-change-triggers.ts

-- Initialize process state
if not State then
    State = {
        initialized = true,
        transformationHistory = {},
        battleTransformations = {}
    }
end

-- Embedded move transformation database
local moveTransformationDatabase = {
    -- Aegislash: Pre-move stance changes
    [681] = {
        speciesName = "Aegislash",
        transformations = {
            {
                type = "pre_move",
                fromForm = "shield",
                toForm = "blade",
                trigger = function(moveId, moveData)
                    -- Shield to Blade: Non-STATUS moves
                    return moveData and moveData.category ~= "STATUS"
                end,
                requiredAbility = "STANCE_CHANGE",
                persistent = false,
                priority = 2
            },
            {
                type = "pre_move",
                fromForm = "blade", 
                toForm = "shield",
                trigger = function(moveId, moveData)
                    -- Blade to Shield: King's Shield specifically
                    return moveId == "KINGS_SHIELD"
                end,
                requiredAbility = "STANCE_CHANGE",
                persistent = false,
                priority = 1
            },
            {
                type = "switch_out",
                fromForm = "blade",
                toForm = "shield",
                trigger = function() return true end,
                requiredAbility = "STANCE_CHANGE",
                persistent = false,
                priority = 3
            }
        },
        stats = {
            shield = {hp = 60, atk = 50, def = 150, spa = 50, spd = 150, spe = 60},
            blade = {hp = 60, atk = 150, def = 50, spa = 150, spd = 50, spe = 60}
        },
        forms = {
            shield = {formKey = "shield", formIndex = 0},
            blade = {formKey = "blade", formIndex = 1}
        }
    },
    
    -- Meloetta: Post-move toggle transformations
    [648] = {
        speciesName = "Meloetta",
        transformations = {
            {
                type = "post_move",
                fromForm = "aria",
                toForm = "pirouette",
                trigger = function(moveId, moveData)
                    return moveId == "RELIC_SONG"
                end,
                blockedAbilities = {"SHEER_FORCE"},
                blockedChallenges = {"SINGLE_TYPE"},
                persistent = true,
                toggleMode = true,
                priority = 1
            },
            {
                type = "post_move",
                fromForm = "pirouette",
                toForm = "aria",
                trigger = function(moveId, moveData)
                    return moveId == "RELIC_SONG"
                end,
                blockedAbilities = {"SHEER_FORCE"},
                blockedChallenges = {"SINGLE_TYPE"},
                persistent = true,
                toggleMode = true,
                priority = 1
            }
        },
        stats = {
            aria = {hp = 100, atk = 77, def = 77, spa = 128, spd = 128, spe = 90},
            pirouette = {hp = 100, atk = 128, def = 90, spa = 77, spd = 77, spe = 128}
        },
        types = {
            aria = {"NORMAL", "PSYCHIC"},
            pirouette = {"NORMAL", "FIGHTING"}
        },
        forms = {
            aria = {formKey = "aria", formIndex = 0},
            pirouette = {formKey = "pirouette", formIndex = 1}
        }
    },
    
    -- Keldeo: Move learned/forgotten transformations
    [647] = {
        speciesName = "Keldeo",
        transformations = {
            {
                type = "move_learned",
                fromForm = "ordinary",
                toForm = "resolute",
                trigger = function(moveId, moveData)
                    return moveId == "SECRET_SWORD"
                end,
                persistent = true,
                priority = 1
            },
            {
                type = "move_forgotten",
                fromForm = "resolute",
                toForm = "ordinary",
                trigger = function(moveId, moveData)
                    return moveId == "SECRET_SWORD"
                end,
                persistent = true,
                priority = 1
            }
        },
        stats = {
            ordinary = {hp = 91, atk = 72, def = 90, spa = 129, spd = 90, spe = 108},
            resolute = {hp = 91, atk = 72, def = 90, spa = 129, spd = 90, spe = 108}
        },
        forms = {
            ordinary = {formKey = "ordinary", formIndex = 0},
            resolute = {formKey = "resolute", formIndex = 1}
        }
    }
}

-- Transform move configuration
local transformMoveConfig = {
    type = "transform_move",
    moveId = "TRANSFORM",
    duration = "battle",
    copyStats = true,
    copyMoves = true,
    copyTypes = true,
    copyAbilities = true,
    excludedMoves = {"TRANSFORM", "STRUGGLE", "MIMIC", "SKETCH"},
    maxPP = 5,
    priority = 10 -- Highest priority
}

-- Duration tracking rules
local durationRules = {
    battle = "revert_on_switch_or_battle_end",
    toggle = "persists_until_triggered_again", 
    conditional = "check_conditions_each_turn",
    permanent = "persists_across_battles"
}

-- Move categories for validation
local moveCategories = {
    PHYSICAL = "PHYSICAL",
    SPECIAL = "SPECIAL", 
    STATUS = "STATUS"
}

-- Common move database (subset for transformation logic)
local moveDatabase = {
    KINGS_SHIELD = {category = "STATUS", name = "King's Shield"},
    RELIC_SONG = {category = "SPECIAL", name = "Relic Song"},
    SECRET_SWORD = {category = "SPECIAL", name = "Secret Sword"},
    TRANSFORM = {category = "STATUS", name = "Transform"},
    STRUGGLE = {category = "PHYSICAL", name = "Struggle"},
    MIMIC = {category = "STATUS", name = "Mimic"},
    SKETCH = {category = "STATUS", name = "Sketch"}
}

-- Ability database (subset for transformation logic)
local abilityDatabase = {
    STANCE_CHANGE = "Stance Change",
    SHEER_FORCE = "Sheer Force",
    IMPOSTER = "Imposter"
}

-- Core transformation validation functions
local function validateAbilityRequirement(pokemon, transformRule)
    if transformRule.requiredAbility then
        if not pokemon.abilities or not pokemon.abilities[transformRule.requiredAbility] then
            return false
        end
    end
    
    if transformRule.blockedAbilities then
        for _, blockedAbility in ipairs(transformRule.blockedAbilities) do
            if pokemon.abilities and pokemon.abilities[blockedAbility] then
                return false
            end
        end
    end
    
    return true
end

local function validateChallengeRestrictions(pokemon, transformRule, gameData)
    if transformRule.blockedChallenges then
        for _, blockedChallenge in ipairs(transformRule.blockedChallenges) do
            if gameData.challenges and gameData.challenges[blockedChallenge] then
                return false
            end
        end
    end
    
    return true
end

local function getTransformationRule(speciesId, transformationType, currentForm)
    local speciesData = moveTransformationDatabase[speciesId]
    if not speciesData then
        return nil
    end
    
    for _, transformation in ipairs(speciesData.transformations) do
        if transformation.type == transformationType then
            if not currentForm or transformation.fromForm == currentForm then
                return transformation
            end
        end
    end
    
    return nil
end

local function evaluateTransformationTrigger(transformRule, moveId, moveData, pokemon, gameData)
    -- Validate ability requirements
    if not validateAbilityRequirement(pokemon, transformRule) then
        return false
    end
    
    -- Validate challenge restrictions
    if not validateChallengeRestrictions(pokemon, transformRule, gameData or {}) then
        return false
    end
    
    -- Evaluate transformation trigger
    if transformRule.trigger then
        return transformRule.trigger(moveId, moveData)
    end
    
    return false
end

local function copyTargetData(user, target)
    -- Store original data for reversion
    local originalData = {
        speciesId = user.speciesId,
        baseStats = user.baseStats,
        types = user.types,
        abilities = user.abilities,
        moveset = user.moveset,
        form = user.form
    }
    
    -- Copy target species and form
    user.speciesId = target.speciesId
    user.form = target.form or "default"
    
    -- Copy base stats (preserve HP)
    user.baseStats = {
        hp = user.baseStats.hp, -- Keep original HP
        atk = target.baseStats.atk,
        def = target.baseStats.def,
        spa = target.baseStats.spa,
        spd = target.baseStats.spd,
        spe = target.baseStats.spe
    }
    
    -- Copy types
    user.types = {}
    for i, typeValue in ipairs(target.types or {}) do
        user.types[i] = typeValue
    end
    
    -- Copy abilities
    user.abilities = {}
    for abilityKey, abilityValue in pairs(target.abilities or {}) do
        user.abilities[abilityKey] = abilityValue
    end
    
    -- Copy moveset with PP limitations
    user.moveset = {}
    for i, move in ipairs(target.moveset or {}) do
        if move and move.moveId then
            -- Check if move is excluded
            local isExcluded = false
            for _, excludedMove in ipairs(transformMoveConfig.excludedMoves) do
                if move.moveId == excludedMove then
                    isExcluded = true
                    break
                end
            end
            
            if not isExcluded then
                user.moveset[i] = {
                    moveId = move.moveId,
                    pp = math.min(move.pp or 5, transformMoveConfig.maxPP),
                    maxPP = math.min(move.maxPP or 5, transformMoveConfig.maxPP)
                }
            end
        end
    end
    
    return originalData
end

local function resolveTransformationConflicts(pendingTransformations)
    -- Priority order: Transform > Pre-move > Post-move > Conditional
    local priorities = {
        {type = "transform", priority = 10},
        {type = "pre_move", priority = 5},
        {type = "post_move", priority = 3},
        {type = "move_learned", priority = 2},
        {type = "move_forgotten", priority = 2},
        {type = "conditional", priority = 1}
    }
    
    -- Sort transformations by priority
    table.sort(pendingTransformations, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    
    -- Return highest priority transformation
    return pendingTransformations[1]
end

-- Handler: Process pre-move transformation
Handlers.add(
    "process-pre-move-transformation",
    Handlers.utils.hasMatchingTag("Action", "ProcessPreMoveTransformation"),
    function(msg)
        local pokemonId = msg.PokemonId
        local moveId = msg.MoveId
        local speciesId = tonumber(msg.SpeciesId)
        local currentForm = msg.CurrentForm
        
        if not pokemonId or not moveId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId, MoveId, and SpeciesId are required"
            })
            return
        end
        
        -- Get transformation rule
        local transformRule = getTransformationRule(speciesId, "pre_move", currentForm)
        if not transformRule then
            ao.send({
                Target = msg.From,
                Action = "NoTransformation",
                PokemonId = pokemonId,
                Reason = "No pre-move transformation rule found"
            })
            return
        end
        
        -- Get move data
        local moveData = moveDatabase[moveId]
        
        -- Decode pokemon and game data
        local pokemon = msg.Data and json.decode(msg.Data) or {}
        local gameData = msg.GameData and json.decode(msg.GameData) or {}
        
        -- Evaluate transformation trigger
        if evaluateTransformationTrigger(transformRule, moveId, moveData, pokemon, gameData) then
            local speciesData = moveTransformationDatabase[speciesId]
            local newStats = speciesData.stats[transformRule.toForm]
            local formData = speciesData.forms[transformRule.toForm]
            
            ao.send({
                Target = msg.From,
                Action = "TransformationTriggered",
                PokemonId = pokemonId,
                TransformationType = "pre_move",
                FromForm = transformRule.fromForm,
                ToForm = transformRule.toForm,
                NewStats = json.encode(newStats),
                FormData = json.encode(formData),
                Persistent = tostring(transformRule.persistent),
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "NoTransformation",
                PokemonId = pokemonId,
                Reason = "Pre-move transformation conditions not met"
            })
        end
    end
)

-- Handler: Process post-move transformation
Handlers.add(
    "process-post-move-transformation",
    Handlers.utils.hasMatchingTag("Action", "ProcessPostMoveTransformation"),
    function(msg)
        local pokemonId = msg.PokemonId
        local moveId = msg.MoveId
        local speciesId = tonumber(msg.SpeciesId)
        local currentForm = msg.CurrentForm
        
        if not pokemonId or not moveId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId, MoveId, and SpeciesId are required"
            })
            return
        end
        
        -- Get transformation rule  
        local transformRule = getTransformationRule(speciesId, "post_move", currentForm)
        if not transformRule then
            ao.send({
                Target = msg.From,
                Action = "NoTransformation",
                PokemonId = pokemonId,
                Reason = "No post-move transformation rule found"
            })
            return
        end
        
        -- Get move data
        local moveData = moveDatabase[moveId]
        
        -- Decode pokemon and game data
        local pokemon = msg.Data and json.decode(msg.Data) or {}
        local gameData = msg.GameData and json.decode(msg.GameData) or {}
        
        -- Evaluate transformation trigger
        if evaluateTransformationTrigger(transformRule, moveId, moveData, pokemon, gameData) then
            local speciesData = moveTransformationDatabase[speciesId]
            local newStats = speciesData.stats[transformRule.toForm]
            local formData = speciesData.forms[transformRule.toForm]
            local newTypes = speciesData.types and speciesData.types[transformRule.toForm]
            
            ao.send({
                Target = msg.From,
                Action = "TransformationTriggered",
                PokemonId = pokemonId,
                TransformationType = "post_move",
                FromForm = transformRule.fromForm,
                ToForm = transformRule.toForm,
                NewStats = json.encode(newStats),
                FormData = json.encode(formData),
                NewTypes = newTypes and json.encode(newTypes) or nil,
                ToggleMode = tostring(transformRule.toggleMode or false),
                Persistent = tostring(transformRule.persistent),
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "NoTransformation",
                PokemonId = pokemonId,
                Reason = "Post-move transformation conditions not met"
            })
        end
    end
)

-- Handler: Process Transform move
Handlers.add(
    "process-transform-move",
    Handlers.utils.hasMatchingTag("Action", "ProcessTransformMove"),
    function(msg)
        local userPokemonId = msg.UserPokemonId
        local targetPokemonId = msg.TargetPokemonId
        local battleId = msg.BattleId
        
        if not userPokemonId or not targetPokemonId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "UserPokemonId and TargetPokemonId are required"
            })
            return
        end
        
        -- Decode pokemon data
        local userData = msg.UserData and json.decode(msg.UserData) or {}
        local targetData = msg.TargetData and json.decode(msg.TargetData) or {}
        
        -- Validate transformation target
        if userData.speciesId == targetData.speciesId and 
           (userData.form == targetData.form or 
            (not userData.form and not targetData.form)) then
            ao.send({
                Target = msg.From,
                Action = "TransformFailed",
                UserPokemonId = userPokemonId,
                Reason = "Cannot transform into same species and form"
            })
            return
        end
        
        -- Copy target data and get original data for reversion
        local originalData = copyTargetData(userData, targetData)
        
        -- Store transformation data for battle duration tracking
        if battleId then
            if not State.battleTransformations[battleId] then
                State.battleTransformations[battleId] = {}
            end
            
            State.battleTransformations[battleId][userPokemonId] = {
                originalData = originalData,
                transformationType = "transform_move",
                timestamp = msg.Timestamp or 0,
                duration = transformMoveConfig.duration
            }
        end
        
        ao.send({
            Target = msg.From,
            Action = "TransformSuccess",
            UserPokemonId = userPokemonId,
            TargetPokemonId = targetPokemonId,
            TransformedData = json.encode(userData),
            OriginalData = json.encode(originalData),
            Duration = transformMoveConfig.duration,
            BattleId = battleId,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Process move learned transformation
Handlers.add(
    "process-move-learned-transformation", 
    Handlers.utils.hasMatchingTag("Action", "ProcessMoveLearnedTransformation"),
    function(msg)
        local pokemonId = msg.PokemonId
        local moveId = msg.MoveId
        local speciesId = tonumber(msg.SpeciesId)
        local currentForm = msg.CurrentForm
        
        if not pokemonId or not moveId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId, MoveId, and SpeciesId are required"
            })
            return
        end
        
        -- Get transformation rule
        local transformRule = getTransformationRule(speciesId, "move_learned", currentForm)
        if not transformRule then
            ao.send({
                Target = msg.From,
                Action = "NoTransformation",
                PokemonId = pokemonId,
                Reason = "No move learned transformation rule found"
            })
            return
        end
        
        -- Get move data
        local moveData = moveDatabase[moveId]
        
        -- Decode pokemon data
        local pokemon = msg.Data and json.decode(msg.Data) or {}
        
        -- Evaluate transformation trigger
        if evaluateTransformationTrigger(transformRule, moveId, moveData, pokemon, {}) then
            local speciesData = moveTransformationDatabase[speciesId]
            local formData = speciesData.forms[transformRule.toForm]
            
            ao.send({
                Target = msg.From,
                Action = "TransformationTriggered",
                PokemonId = pokemonId,
                TransformationType = "move_learned",
                FromForm = transformRule.fromForm,
                ToForm = transformRule.toForm,
                FormData = json.encode(formData),
                Persistent = tostring(transformRule.persistent),
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "NoTransformation",
                PokemonId = pokemonId,
                Reason = "Move learned transformation conditions not met"
            })
        end
    end
)

-- Handler: Revert transformation on switch out
Handlers.add(
    "revert-transformation",
    Handlers.utils.hasMatchingTag("Action", "RevertTransformation"),
    function(msg)
        local pokemonId = msg.PokemonId
        local battleId = msg.BattleId
        local revertType = msg.RevertType or "switch_out"
        
        if not pokemonId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId is required"
            })
            return
        end
        
        local reverted = false
        
        -- Check for battle-duration transformations to revert
        if battleId and State.battleTransformations[battleId] and 
           State.battleTransformations[battleId][pokemonId] then
            local transformData = State.battleTransformations[battleId][pokemonId]
            
            if transformData.duration == "battle" or revertType == "battle_end" then
                ao.send({
                    Target = msg.From,
                    Action = "TransformationReverted",
                    PokemonId = pokemonId,
                    OriginalData = json.encode(transformData.originalData),
                    RevertType = revertType,
                    Timestamp = tostring(msg.Timestamp or 0)
                })
                
                -- Clean up transformation data
                State.battleTransformations[battleId][pokemonId] = nil
                reverted = true
            end
        end
        
        -- Check for form-based reversions (like Aegislash on switch out)
        local speciesId = tonumber(msg.SpeciesId)
        if speciesId then
            local transformRule = getTransformationRule(speciesId, "switch_out", msg.CurrentForm)
            if transformRule then
                local speciesData = moveTransformationDatabase[speciesId]
                local newStats = speciesData.stats[transformRule.toForm]
                local formData = speciesData.forms[transformRule.toForm]
                
                ao.send({
                    Target = msg.From,
                    Action = "TransformationTriggered",
                    PokemonId = pokemonId,
                    TransformationType = "switch_out",
                    FromForm = transformRule.fromForm,
                    ToForm = transformRule.toForm,
                    NewStats = json.encode(newStats),
                    FormData = json.encode(formData),
                    RevertType = revertType,
                    Timestamp = tostring(msg.Timestamp or 0)
                })
                reverted = true
            end
        end
        
        if not reverted then
            ao.send({
                Target = msg.From,
                Action = "NoReversion",
                PokemonId = pokemonId,
                Reason = "No active transformations to revert"
            })
        end
    end
)

-- Handler: Clean up battle transformations
Handlers.add(
    "cleanup-battle-transformations",
    Handlers.utils.hasMatchingTag("Action", "CleanupBattleTransformations"),
    function(msg)
        local battleId = msg.BattleId
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "BattleId is required"
            })
            return
        end
        
        local cleanedCount = 0
        if State.battleTransformations[battleId] then
            for pokemonId, _ in pairs(State.battleTransformations[battleId]) do
                cleanedCount = cleanedCount + 1
            end
            State.battleTransformations[battleId] = nil
        end
        
        ao.send({
            Target = msg.From,
            Action = "CleanupComplete",
            BattleId = battleId,
            CleanedTransformations = tostring(cleanedCount),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Get transformation info
Handlers.add(
    "get-transformation-info",
    Handlers.utils.hasMatchingTag("Action", "GetTransformationInfo"),
    function(msg)
        local speciesId = tonumber(msg.SpeciesId)
        
        if not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId is required"
            })
            return
        end
        
        local speciesData = moveTransformationDatabase[speciesId]
        if not speciesData then
            ao.send({
                Target = msg.From,
                Action = "NoTransformationData",
                SpeciesId = tostring(speciesId),
                Reason = "Species not found in transformation database"
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "TransformationInfo",
            SpeciesId = tostring(speciesId),
            SpeciesName = speciesData.speciesName,
            TransformationData = json.encode(speciesData),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- AO Documentation Protocol (ADP) v1.0 - Info Handler
Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
    local infoResponse = {
        Name = "Move Transformation Engine",
        Description = "Comprehensive AO process for Pokemon move-based transformations including Aegislash stance changes, Meloetta Relic Song toggles, Transform move implementation, and transformation duration tracking",
        Owner = Owner or (ao.env and ao.env.Process and ao.env.Process.Owner) or "unknown",
        ProcessId = ao.id,
        adpVersion = "1.0",
        lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        capabilities = {
            "pre_move_transformations",
            "post_move_transformations", 
            "transform_move_implementation",
            "duration_tracking",
            "ability_interaction_validation",
            "battle_transformation_cleanup"
        },
        handlers = {
            {
                action = "ProcessPreMoveTransformation",
                description = "Process pre-move form changes (e.g., Aegislash stance)",
                parameters = {
                    PokemonId = {type = "string", required = true},
                    MoveId = {type = "string", required = true},
                    SpeciesId = {type = "number", required = true},
                    CurrentForm = {type = "string", required = false},
                    Data = {type = "json", required = false, description = "Pokemon data"},
                    GameData = {type = "json", required = false, description = "Game state data"}
                }
            },
            {
                action = "ProcessPostMoveTransformation", 
                description = "Process post-move form changes (e.g., Meloetta Relic Song)",
                parameters = {
                    PokemonId = {type = "string", required = true},
                    MoveId = {type = "string", required = true},
                    SpeciesId = {type = "number", required = true},
                    CurrentForm = {type = "string", required = false},
                    Data = {type = "json", required = false, description = "Pokemon data"},
                    GameData = {type = "json", required = false, description = "Game state data"}
                }
            },
            {
                action = "ProcessTransformMove",
                description = "Process Transform move complete species transformation", 
                parameters = {
                    UserPokemonId = {type = "string", required = true},
                    TargetPokemonId = {type = "string", required = true},
                    BattleId = {type = "string", required = false},
                    UserData = {type = "json", required = true, description = "User Pokemon data"},
                    TargetData = {type = "json", required = true, description = "Target Pokemon data"}
                }
            },
            {
                action = "ProcessMoveLearnedTransformation",
                description = "Process transformations triggered by learning moves",
                parameters = {
                    PokemonId = {type = "string", required = true},
                    MoveId = {type = "string", required = true},
                    SpeciesId = {type = "number", required = true},
                    CurrentForm = {type = "string", required = false},
                    Data = {type = "json", required = false, description = "Pokemon data"}
                }
            },
            {
                action = "RevertTransformation",
                description = "Revert transformations on switch out or battle end",
                parameters = {
                    PokemonId = {type = "string", required = true},
                    BattleId = {type = "string", required = false},
                    SpeciesId = {type = "number", required = false},
                    CurrentForm = {type = "string", required = false},
                    RevertType = {type = "string", required = false, default = "switch_out"}
                }
            },
            {
                action = "CleanupBattleTransformations",
                description = "Clean up all transformations for a completed battle",
                parameters = {
                    BattleId = {type = "string", required = true}
                }
            },
            {
                action = "GetTransformationInfo",
                description = "Get transformation data for a species",
                parameters = {
                    SpeciesId = {type = "number", required = true}
                }
            }
        },
        transformationDatabase = {
            supportedSpecies = {681, 648, 647}, -- Aegislash, Meloetta, Keldeo
            transformationTypes = {"pre_move", "post_move", "transform_move", "move_learned", "move_forgotten", "switch_out"},
            durationTypes = {"battle", "toggle", "conditional", "permanent"}
        }
    }
    
    ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode(infoResponse)
    })
end)

-- Basic Ping handler for ADP testing
Handlers.add("ping", Handlers.utils.hasMatchingTag("Action", "Ping"), function(msg)
    ao.send({
        Target = msg.From,
        Action = "Pong",
        Data = "pong"
    })
end)

print("Move Transformation Engine initialized successfully!")
print("Supported species: Aegislash (681), Meloetta (648), Keldeo (647)")
print("Transformation types: pre_move, post_move, transform_move, move_learned")
print("ADP v1.0 compliant with comprehensive handler documentation")