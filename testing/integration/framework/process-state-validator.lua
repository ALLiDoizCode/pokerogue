--[[
Process State Validator for Cross-Process State Synchronization Testing

Validates GameState consistency across process boundaries in the 26-process
stateless architecture, ensuring state integrity during multi-process workflows.
]]

local ProcessStateValidator = {}

-- GameState Schema Definition
local GAMESTATE_SCHEMA = {
    required = {
        "version", "playerId", "party", "progression"
    },
    optional = {
        "battleId", "currentBattle", "inventory", "settings", "flags"
    },
    nested = {
        party = {
            required = {"id", "speciesId", "level", "stats", "currentHp"},
            optional = {"name", "nature", "ivs", "evs", "moves", "ability", "heldItem", "experience"}
        },
        currentBattle = {
            required = {"battleType", "turn", "phase"},
            optional = {"battleId", "playerPokemon", "enemyPokemon", "field", "weather"}
        },
        progression = {
            required = {"level", "experience"},
            optional = {"badges", "pokedexSeen", "pokedexCaught", "story"}
        }
    }
}

-- State Consistency Rules
local CONSISTENCY_RULES = {
    party_size_limit = 6,
    max_level = 100,
    min_level = 1,
    max_hp_ratio = 1.0,
    valid_species_range = {1, 1000},
    valid_move_range = {1, 1000},
    valid_item_range = {1, 2000}
}

function ProcessStateValidator.validateGameState(gameState, context)
    local validation = {
        valid = true,
        errors = {},
        warnings = {},
        metadata = {
            context = context or "unknown",
            timestamp = os.time(),
            stateVersion = gameState.version or "unknown",
            validationLevel = "comprehensive"
        }
    }

    if type(gameState) ~= "table" then
        validation.valid = false
        table.insert(validation.errors, "GameState must be a table/object")
        return validation
    end

    -- Validate required fields
    local schemaValidation = ProcessStateValidator.validateSchema(gameState, GAMESTATE_SCHEMA)
    if not schemaValidation.valid then
        validation.valid = false
        for _, error in ipairs(schemaValidation.errors) do
            table.insert(validation.errors, "Schema: " .. error)
        end
    end

    -- Validate party consistency
    if gameState.party then
        local partyValidation = ProcessStateValidator.validateParty(gameState.party)
        if not partyValidation.valid then
            validation.valid = false
            for _, error in ipairs(partyValidation.errors) do
                table.insert(validation.errors, "Party: " .. error)
            end
        end
        for _, warning in ipairs(partyValidation.warnings) do
            table.insert(validation.warnings, "Party: " .. warning)
        end
    end

    -- Validate battle state consistency
    if gameState.currentBattle then
        local battleValidation = ProcessStateValidator.validateBattleState(gameState.currentBattle)
        if not battleValidation.valid then
            validation.valid = false
            for _, error in ipairs(battleValidation.errors) do
                table.insert(validation.errors, "Battle: " .. error)
            end
        end
        for _, warning in ipairs(battleValidation.warnings) do
            table.insert(validation.warnings, "Battle: " .. warning)
        end
    end

    -- Validate progression consistency
    if gameState.progression then
        local progressionValidation = ProcessStateValidator.validateProgression(gameState.progression)
        if not progressionValidation.valid then
            validation.valid = false
            for _, error in ipairs(progressionValidation.errors) do
                table.insert(validation.errors, "Progression: " .. error)
            end
        end
        for _, warning in ipairs(progressionValidation.warnings) do
            table.insert(validation.warnings, "Progression: " .. warning)
        end
    end

    -- Cross-field validation
    local crossValidation = ProcessStateValidator.validateCrossFieldConsistency(gameState)
    if not crossValidation.valid then
        validation.valid = false
        for _, error in ipairs(crossValidation.errors) do
            table.insert(validation.errors, "Cross-field: " .. error)
        end
    end
    for _, warning in ipairs(crossValidation.warnings) do
        table.insert(validation.warnings, "Cross-field: " .. warning)
    end

    return validation
end

function ProcessStateValidator.validateSchema(data, schema)
    local validation = {valid = true, errors = {}, warnings = {}}

    -- Check required fields
    for _, field in ipairs(schema.required) do
        if not data[field] then
            validation.valid = false
            table.insert(validation.errors, "Missing required field: " .. field)
        end
    end

    -- Validate nested schemas
    if schema.nested then
        for field, nestedSchema in pairs(schema.nested) do
            if data[field] then
                if type(data[field]) == "table" then
                    if #data[field] > 0 then
                        -- Array of objects
                        for i, item in ipairs(data[field]) do
                            local nestedValidation = ProcessStateValidator.validateSchema(item, nestedSchema)
                            if not nestedValidation.valid then
                                validation.valid = false
                                for _, error in ipairs(nestedValidation.errors) do
                                    table.insert(validation.errors, field .. "[" .. i .. "]: " .. error)
                                end
                            end
                        end
                    else
                        -- Single object
                        local nestedValidation = ProcessStateValidator.validateSchema(data[field], nestedSchema)
                        if not nestedValidation.valid then
                            validation.valid = false
                            for _, error in ipairs(nestedValidation.errors) do
                                table.insert(validation.errors, field .. ": " .. error)
                            end
                        end
                    end
                end
            end
        end
    end

    return validation
end

function ProcessStateValidator.validateParty(party)
    local validation = {valid = true, errors = {}, warnings = {}}

    if type(party) ~= "table" then
        validation.valid = false
        table.insert(validation.errors, "Party must be an array")
        return validation
    end

    -- Check party size limits
    if #party > CONSISTENCY_RULES.party_size_limit then
        validation.valid = false
        table.insert(validation.errors, "Party size exceeds limit: " .. #party .. " > " .. CONSISTENCY_RULES.party_size_limit)
    end

    if #party == 0 then
        table.insert(validation.warnings, "Party is empty")
    end

    -- Validate each Pokemon
    local usedIds = {}
    for i, pokemon in ipairs(party) do
        -- Check for duplicate IDs
        if usedIds[pokemon.id] then
            validation.valid = false
            table.insert(validation.errors, "Duplicate Pokemon ID: " .. pokemon.id)
        else
            usedIds[pokemon.id] = true
        end

        local pokemonValidation = ProcessStateValidator.validatePokemon(pokemon, i)
        if not pokemonValidation.valid then
            validation.valid = false
            for _, error in ipairs(pokemonValidation.errors) do
                table.insert(validation.errors, "Pokemon " .. i .. ": " .. error)
            end
        end
        for _, warning in ipairs(pokemonValidation.warnings) do
            table.insert(validation.warnings, "Pokemon " .. i .. ": " .. warning)
        end
    end

    return validation
end

function ProcessStateValidator.validatePokemon(pokemon, index)
    local validation = {valid = true, errors = {}, warnings = {}}

    -- Validate basic fields
    if not pokemon.id or type(pokemon.id) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "Invalid or missing Pokemon ID")
    end

    if not pokemon.speciesId or type(pokemon.speciesId) ~= "number" then
        validation.valid = false
        table.insert(validation.errors, "Invalid or missing speciesId")
    else
        if pokemon.speciesId < CONSISTENCY_RULES.valid_species_range[1] or
           pokemon.speciesId > CONSISTENCY_RULES.valid_species_range[2] then
            validation.valid = false
            table.insert(validation.errors, "Invalid speciesId range: " .. pokemon.speciesId)
        end
    end

    if not pokemon.level or type(pokemon.level) ~= "number" then
        validation.valid = false
        table.insert(validation.errors, "Invalid or missing level")
    else
        if pokemon.level < CONSISTENCY_RULES.min_level or pokemon.level > CONSISTENCY_RULES.max_level then
            validation.valid = false
            table.insert(validation.errors, "Invalid level range: " .. pokemon.level)
        end
    end

    -- Validate stats
    if not pokemon.stats or type(pokemon.stats) ~= "table" then
        validation.valid = false
        table.insert(validation.errors, "Missing or invalid stats")
    else
        local statsValidation = ProcessStateValidator.validateStats(pokemon.stats)
        if not statsValidation.valid then
            validation.valid = false
            for _, error in ipairs(statsValidation.errors) do
                table.insert(validation.errors, "Stats: " .. error)
            end
        end
    end

    -- Validate HP consistency
    if pokemon.currentHp and pokemon.stats and pokemon.stats.hp then
        if pokemon.currentHp > pokemon.stats.hp then
            validation.valid = false
            table.insert(validation.errors, "Current HP exceeds max HP: " .. pokemon.currentHp .. " > " .. pokemon.stats.hp)
        end

        if pokemon.currentHp < 0 then
            validation.valid = false
            table.insert(validation.errors, "Current HP cannot be negative: " .. pokemon.currentHp)
        end

        if pokemon.currentHp == 0 and index == 1 then
            table.insert(validation.warnings, "Lead Pokemon is fainted")
        end
    end

    -- Validate moves
    if pokemon.moves then
        if type(pokemon.moves) ~= "table" then
            validation.valid = false
            table.insert(validation.errors, "Moves must be an array")
        else
            if #pokemon.moves > 4 then
                validation.valid = false
                table.insert(validation.errors, "Too many moves: " .. #pokemon.moves .. " > 4")
            end

            for i, moveId in ipairs(pokemon.moves) do
                if type(moveId) ~= "number" then
                    validation.valid = false
                    table.insert(validation.errors, "Invalid move ID type at position " .. i)
                elseif moveId < CONSISTENCY_RULES.valid_move_range[1] or
                       moveId > CONSISTENCY_RULES.valid_move_range[2] then
                    validation.valid = false
                    table.insert(validation.errors, "Invalid move ID range: " .. moveId)
                end
            end
        end
    end

    -- Validate IVs and EVs if present
    if pokemon.ivs then
        local ivsValidation = ProcessStateValidator.validateIVs(pokemon.ivs)
        if not ivsValidation.valid then
            validation.valid = false
            for _, error in ipairs(ivsValidation.errors) do
                table.insert(validation.errors, "IVs: " .. error)
            end
        end
    end

    if pokemon.evs then
        local evsValidation = ProcessStateValidator.validateEVs(pokemon.evs)
        if not evsValidation.valid then
            validation.valid = false
            for _, error in ipairs(evsValidation.errors) do
                table.insert(validation.errors, "EVs: " .. error)
            end
        end
    end

    return validation
end

function ProcessStateValidator.validateStats(stats)
    local validation = {valid = true, errors = {}, warnings = {}}

    local requiredStats = {"hp", "attack", "defense", "specialAttack", "specialDefense", "speed"}

    for _, stat in ipairs(requiredStats) do
        if not stats[stat] then
            validation.valid = false
            table.insert(validation.errors, "Missing stat: " .. stat)
        elseif type(stats[stat]) ~= "number" then
            validation.valid = false
            table.insert(validation.errors, "Invalid stat type for " .. stat)
        elseif stats[stat] <= 0 then
            validation.valid = false
            table.insert(validation.errors, "Stat must be positive: " .. stat .. " = " .. stats[stat])
        elseif stats[stat] > 999 then
            table.insert(validation.warnings, "Unusually high stat: " .. stat .. " = " .. stats[stat])
        end
    end

    return validation
end

function ProcessStateValidator.validateIVs(ivs)
    local validation = {valid = true, errors = {}, warnings = {}}

    local stats = {"hp", "attack", "defense", "specialAttack", "specialDefense", "speed"}

    for _, stat in ipairs(stats) do
        if ivs[stat] then
            if type(ivs[stat]) ~= "number" then
                validation.valid = false
                table.insert(validation.errors, "Invalid IV type for " .. stat)
            elseif ivs[stat] < 0 or ivs[stat] > 31 then
                validation.valid = false
                table.insert(validation.errors, "IV out of range for " .. stat .. ": " .. ivs[stat])
            end
        end
    end

    return validation
end

function ProcessStateValidator.validateEVs(evs)
    local validation = {valid = true, errors = {}, warnings = {}}

    local stats = {"hp", "attack", "defense", "specialAttack", "specialDefense", "speed"}
    local totalEVs = 0

    for _, stat in ipairs(stats) do
        if evs[stat] then
            if type(evs[stat]) ~= "number" then
                validation.valid = false
                table.insert(validation.errors, "Invalid EV type for " .. stat)
            elseif evs[stat] < 0 or evs[stat] > 255 then
                validation.valid = false
                table.insert(validation.errors, "EV out of range for " .. stat .. ": " .. evs[stat])
            else
                totalEVs = totalEVs + evs[stat]
            end
        end
    end

    if totalEVs > 510 then
        validation.valid = false
        table.insert(validation.errors, "Total EVs exceed limit: " .. totalEVs .. " > 510")
    end

    return validation
end

function ProcessStateValidator.validateBattleState(battleState)
    local validation = {valid = true, errors = {}, warnings = {}}

    -- Validate required battle fields
    if not battleState.battleType then
        validation.valid = false
        table.insert(validation.errors, "Missing battleType")
    end

    if not battleState.turn or type(battleState.turn) ~= "number" then
        validation.valid = false
        table.insert(validation.errors, "Invalid or missing turn number")
    elseif battleState.turn < 1 then
        validation.valid = false
        table.insert(validation.errors, "Turn number must be positive: " .. battleState.turn)
    end

    if not battleState.phase then
        validation.valid = false
        table.insert(validation.errors, "Missing battle phase")
    end

    -- Validate battle participants
    if battleState.playerPokemon then
        if not battleState.playerPokemon.id then
            validation.valid = false
            table.insert(validation.errors, "Player Pokemon missing ID")
        end

        if battleState.playerPokemon.currentHp and battleState.playerPokemon.currentHp < 0 then
            validation.valid = false
            table.insert(validation.errors, "Player Pokemon HP cannot be negative")
        end
    end

    if battleState.enemyPokemon or battleState.wildPokemon then
        local enemy = battleState.enemyPokemon or battleState.wildPokemon
        if enemy.currentHp and enemy.currentHp < 0 then
            validation.valid = false
            table.insert(validation.errors, "Enemy Pokemon HP cannot be negative")
        end
    end

    return validation
end

function ProcessStateValidator.validateProgression(progression)
    local validation = {valid = true, errors = {}, warnings = {}}

    if not progression.level or type(progression.level) ~= "number" then
        validation.valid = false
        table.insert(validation.errors, "Invalid or missing player level")
    elseif progression.level < 1 or progression.level > 100 then
        validation.valid = false
        table.insert(validation.errors, "Player level out of range: " .. progression.level)
    end

    if not progression.experience or type(progression.experience) ~= "number" then
        validation.valid = false
        table.insert(validation.errors, "Invalid or missing experience")
    elseif progression.experience < 0 then
        validation.valid = false
        table.insert(validation.errors, "Experience cannot be negative: " .. progression.experience)
    end

    if progression.badges and type(progression.badges) == "number" then
        if progression.badges < 0 or progression.badges > 8 then
            table.insert(validation.warnings, "Unusual badge count: " .. progression.badges)
        end
    end

    if progression.pokedexSeen and progression.pokedexCaught then
        if progression.pokedexCaught > progression.pokedexSeen then
            validation.valid = false
            table.insert(validation.errors, "Cannot have caught more Pokemon than seen")
        end
    end

    return validation
end

function ProcessStateValidator.validateCrossFieldConsistency(gameState)
    local validation = {valid = true, errors = {}, warnings = {}}

    -- Validate battle state consistency with party
    if gameState.currentBattle and gameState.party then
        if gameState.currentBattle.playerPokemon then
            local playerPokemonId = gameState.currentBattle.playerPokemon.id
            local found = false

            for _, pokemon in ipairs(gameState.party) do
                if pokemon.id == playerPokemonId then
                    found = true

                    -- Check HP consistency
                    if gameState.currentBattle.playerPokemon.currentHp and
                       pokemon.currentHp and
                       gameState.currentBattle.playerPokemon.currentHp ~= pokemon.currentHp then
                        table.insert(validation.warnings, "HP mismatch between battle and party for " .. playerPokemonId)
                    end
                    break
                end
            end

            if not found then
                validation.valid = false
                table.insert(validation.errors, "Battle Pokemon not found in party: " .. playerPokemonId)
            end
        end
    end

    -- Validate version consistency
    if gameState.version then
        -- Add version-specific validation rules here
        local supportedVersions = {"1.0.0", "1.0.1", "1.1.0"}
        local versionSupported = false
        for _, version in ipairs(supportedVersions) do
            if gameState.version == version then
                versionSupported = true
                break
            end
        end

        if not versionSupported then
            table.insert(validation.warnings, "Unsupported GameState version: " .. gameState.version)
        end
    end

    return validation
end

function ProcessStateValidator.compareGameStates(state1, state2, tolerances)
    local comparison = {
        identical = true,
        differences = {},
        warnings = {},
        tolerances = tolerances or {}
    }

    -- Deep comparison of game states
    local function deepCompare(obj1, obj2, path)
        path = path or ""

        if type(obj1) ~= type(obj2) then
            comparison.identical = false
            table.insert(comparison.differences, {
                path = path,
                type = "type_mismatch",
                value1 = type(obj1),
                value2 = type(obj2)
            })
            return
        end

        if type(obj1) == "table" then
            -- Check for missing/extra keys
            for key, _ in pairs(obj1) do
                if obj2[key] == nil then
                    comparison.identical = false
                    table.insert(comparison.differences, {
                        path = path .. "." .. key,
                        type = "missing_key",
                        value1 = obj1[key],
                        value2 = nil
                    })
                end
            end

            for key, _ in pairs(obj2) do
                if obj1[key] == nil then
                    comparison.identical = false
                    table.insert(comparison.differences, {
                        path = path .. "." .. key,
                        type = "extra_key",
                        value1 = nil,
                        value2 = obj2[key]
                    })
                end
            end

            -- Compare common keys
            for key, value1 in pairs(obj1) do
                if obj2[key] ~= nil then
                    deepCompare(value1, obj2[key], path .. "." .. key)
                end
            end
        else
            if obj1 ~= obj2 then
                -- Check if difference is within tolerance
                local withinTolerance = false
                if type(obj1) == "number" and type(obj2) == "number" and comparison.tolerances[path] then
                    local tolerance = comparison.tolerances[path]
                    local diff = math.abs(obj1 - obj2)
                    if diff <= tolerance then
                        withinTolerance = true
                        table.insert(comparison.warnings, {
                            path = path,
                            type = "within_tolerance",
                            difference = diff,
                            tolerance = tolerance
                        })
                    end
                end

                if not withinTolerance then
                    comparison.identical = false
                    table.insert(comparison.differences, {
                        path = path,
                        type = "value_mismatch",
                        value1 = obj1,
                        value2 = obj2
                    })
                end
            end
        end
    end

    deepCompare(state1, state2)
    return comparison
end

function ProcessStateValidator.validateStateTransition(beforeState, afterState, expectedChanges)
    local validation = {
        valid = true,
        errors = {},
        warnings = {},
        actualChanges = {},
        expectedChanges = expectedChanges or {}
    }

    -- Compare states to find actual changes
    local comparison = ProcessStateValidator.compareGameStates(beforeState, afterState)
    validation.actualChanges = comparison.differences

    -- Validate expected changes occurred
    for _, expectedChange in ipairs(validation.expectedChanges) do
        local found = false
        for _, actualChange in ipairs(validation.actualChanges) do
            if actualChange.path == expectedChange.path and
               actualChange.type == expectedChange.type then
                found = true

                -- Validate the change value if specified
                if expectedChange.expectedValue and
                   actualChange.value2 ~= expectedChange.expectedValue then
                    validation.valid = false
                    table.insert(validation.errors,
                        "Expected change value mismatch at " .. expectedChange.path ..
                        ": expected " .. tostring(expectedChange.expectedValue) ..
                        ", got " .. tostring(actualChange.value2))
                end
                break
            end
        end

        if not found then
            validation.valid = false
            table.insert(validation.errors, "Expected change not found: " .. expectedChange.path)
        end
    end

    -- Check for unexpected changes
    for _, actualChange in ipairs(validation.actualChanges) do
        local expected = false
        for _, expectedChange in ipairs(validation.expectedChanges) do
            if actualChange.path == expectedChange.path then
                expected = true
                break
            end
        end

        if not expected then
            table.insert(validation.warnings, "Unexpected change: " .. actualChange.path)
        end
    end

    return validation
end

function ProcessStateValidator.generateStateChecksum(gameState)
    -- Generate a simple checksum for state integrity verification
    local function serializeForChecksum(obj, visited)
        visited = visited or {}

        if visited[obj] then
            return "circular_reference"
        end

        if type(obj) == "table" then
            visited[obj] = true
            local result = "{"
            local keys = {}
            for k, _ in pairs(obj) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

            for _, k in ipairs(keys) do
                result = result .. tostring(k) .. ":" .. serializeForChecksum(obj[k], visited) .. ","
            end
            result = result .. "}"
            visited[obj] = nil
            return result
        else
            return tostring(obj)
        end
    end

    local serialized = serializeForChecksum(gameState)

    -- Simple hash function (in real implementation, use proper cryptographic hash)
    local hash = 0
    for i = 1, #serialized do
        hash = (hash * 31 + string.byte(serialized, i)) % 2147483647
    end

    return hash
end

return ProcessStateValidator