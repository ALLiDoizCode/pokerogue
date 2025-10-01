-- integration-stubs.lua
-- Mock external process responses for integration testing
-- Provides realistic responses from pokemon-species-db and moves-database processes

local json = require("json")

local IntegrationStubs = {}

-- ============================================================================
-- POKEMON SPECIES DATABASE STUBS
-- ============================================================================

-- Sample species data matching pokemon-species-db.lua response format
IntegrationStubs.speciesResponses = {
    -- Pikachu (Electric type, common)
    [25] = {
        id = 25,
        n = "Pikachu",
        bs = { 35, 55, 40, 50, 50, 90 },  -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = { 12 },  -- ELECTRIC
        a = { 9, 31 },  -- Static, Lightning Rod
        evo = { from = 172, level = 20 }
    },
    -- Charizard (Fire/Flying type, starter final evolution)
    [6] = {
        id = 6,
        n = "Charizard",
        bs = { 78, 84, 78, 109, 85, 100 },
        t = { 9, 2 },  -- FIRE, FLYING
        a = { 66, 94 },  -- Blaze, Solar Power
        evo = { from = 5, level = 36 }
    },
    -- Gyarados (Water/Flying type, pseudo-legendary)
    [130] = {
        id = 130,
        n = "Gyarados",
        bs = { 95, 125, 79, 60, 100, 81 },
        t = { 10, 2 },  -- WATER, FLYING
        a = { 22, 62 },  -- Intimidate, Moxie
        evo = { from = 129, level = 20 }
    },
    -- Dragonite (Dragon/Flying type, pseudo-legendary)
    [149] = {
        id = 149,
        n = "Dragonite",
        bs = { 91, 134, 95, 100, 100, 80 },
        t = { 15, 2 },  -- DRAGON, FLYING
        a = { 39, 136 },  -- Inner Focus, Multiscale
        evo = { from = 148, level = 55 }
    },
    -- Mewtwo (Psychic legendary)
    [150] = {
        id = 150,
        n = "Mewtwo",
        bs = { 106, 110, 90, 154, 90, 130 },
        t = { 13 },  -- PSYCHIC
        a = { 94, 127 },  -- Pressure, Unnerve
        evo = nil
    },
    -- Garchomp (Dragon/Ground pseudo-legendary)
    [445] = {
        id = 445,
        n = "Garchomp",
        bs = { 108, 130, 95, 80, 85, 102 },
        t = { 15, 4 },  -- DRAGON, GROUND
        a = { 81, 164 },  -- Sand Veil, Rough Skin
        evo = { from = 444, level = 48 }
    }
}

-- Get species stub response
function IntegrationStubs.getSpecies(speciesId)
    local species = IntegrationStubs.speciesResponses[speciesId]
    if species then
        return {
            Action = "SaveState",
            Data = json.encode(species)
        }
    else
        return {
            Action = "Error",
            Error = "Species not found: " .. tostring(speciesId)
        }
    end
end

-- Get level moves stub (simplified - returns common moves)
function IntegrationStubs.getLevelMoves(speciesId, level)
    -- Simplified: Return 4 common moves based on species type
    local species = IntegrationStubs.speciesResponses[speciesId]
    if not species then
        return {
            Action = "Error",
            Error = "Species not found"
        }
    end

    local moves = {}
    local primaryType = species.t[1]

    -- Map types to common move IDs (simplified)
    local typeMoves = {
        [9] = {52, 83, 126, 257},   -- FIRE: Ember, Flamethrower, Fire Blast, Heat Wave
        [10] = {55, 56, 57, 352},   -- WATER: Water Gun, Hydro Pump, Surf, Water Pulse
        [11] = {71, 75, 76, 437},   -- GRASS: Absorb, Razor Leaf, Solar Beam, Seed Bomb
        [12] = {84, 85, 87, 435},   -- ELECTRIC: Thunder Shock, Thunderbolt, Thunder, Discharge
        [13] = {93, 94, 121, 473},  -- PSYCHIC: Confusion, Psychic, Psybeam, Psycho Cut
        [15] = {82, 225, 406, 407}  -- DRAGON: Dragon Rage, Dragon Claw, Dragon Pulse, Draco Meteor
    }

    local moveList = typeMoves[primaryType] or {33, 36, 44, 163}  -- Default: Tackle, etc.

    for i = 1, math.min(4, #moveList) do
        moves[i] = moveList[i]
    end

    return {
        Action = "SaveState",
        Data = json.encode({ moves = moves })
    }
end

-- ============================================================================
-- MOVES DATABASE STUBS
-- ============================================================================

-- Sample move data matching moves-database.lua response format
IntegrationStubs.moveResponses = {
    -- Thunderbolt (Electric special, high power)
    [85] = {
        id = 85,
        name = "Thunderbolt",
        type = 12,  -- ELECTRIC
        category = 2,  -- Special
        power = 90,
        accuracy = 100,
        pp = 15,
        priority = 0,
        effects = "10% chance to paralyze"
    },
    -- Flamethrower (Fire special, high power)
    [83] = {
        id = 83,
        name = "Flamethrower",
        type = 9,  -- FIRE
        category = 2,  -- Special
        power = 90,
        accuracy = 100,
        pp = 15,
        priority = 0,
        effects = "10% chance to burn"
    },
    -- Surf (Water special, high power)
    [57] = {
        id = 57,
        name = "Surf",
        type = 10,  -- WATER
        category = 2,  -- Special
        power = 90,
        accuracy = 100,
        pp = 15,
        priority = 0,
        effects = "Hits all adjacent Pokemon"
    },
    -- Dragon Claw (Dragon physical, reliable)
    [225] = {
        id = 225,
        name = "Dragon Claw",
        type = 15,  -- DRAGON
        category = 1,  -- Physical
        power = 80,
        accuracy = 100,
        pp = 15,
        priority = 0,
        effects = "No additional effects"
    }
}

-- Get move stub response (single move - uses tags)
function IntegrationStubs.getMove(moveId)
    local move = IntegrationStubs.moveResponses[moveId]
    if move then
        return {
            Action = "SaveState",
            Success = "true",
            MoveId = tostring(move.id),
            MoveName = move.name,
            Type = tostring(move.type),
            Category = tostring(move.category),
            Power = tostring(move.power),
            Accuracy = tostring(move.accuracy),
            PP = tostring(move.pp),
            Priority = tostring(move.priority),
            Effects = move.effects
        }
    else
        return {
            Action = "Error",
            Error = "Move not found: " .. tostring(moveId)
        }
    end
end

-- Get moves by type stub (multiple moves - uses Data field)
function IntegrationStubs.getMovesByType(typeId)
    local moves = {}
    for _, move in pairs(IntegrationStubs.moveResponses) do
        if move.type == typeId then
            table.insert(moves, move)
        end
    end

    if #moves > 0 then
        return {
            Action = "SaveState",
            Data = json.encode(moves)
        }
    else
        return {
            Action = "Error",
            Error = "No moves found for type: " .. tostring(typeId)
        }
    end
end

-- ============================================================================
-- MOCK PROCESS COMMUNICATION
-- ============================================================================

-- Simulate async message passing with external processes
function IntegrationStubs.mockExternalCall(processId, action, data)
    -- Simulate species lookup
    if processId == "pokemon-species-db" then
        if action == "get-species" then
            local speciesId = data.speciesId
            return IntegrationStubs.getSpecies(speciesId)
        elseif action == "get-level-moves" then
            return IntegrationStubs.getLevelMoves(data.speciesId, data.level)
        end
    end

    -- Simulate move lookup
    if processId == "moves-database-adp" then
        if action == "get-move" then
            return IntegrationStubs.getMove(data.moveId)
        elseif action == "get-moves-by-type" then
            return IntegrationStubs.getMovesByType(data.type)
        end
    end

    return {
        Action = "Error",
        Error = "Unknown external process or action"
    }
end

-- ============================================================================
-- HELPER FUNCTIONS FOR TESTS
-- ============================================================================

-- Create realistic trainer configuration for testing
function IntegrationStubs.createTrainerConfig(trainerType, wave)
    return {
        trainerType = trainerType or 1,  -- ACE_TRAINER
        waveIndex = wave or 10,
        gameMode = "classic",
        biomeType = 1,  -- PLAINS
        partyTemplate = {
            size = 3,
            strength = 3,  -- AVERAGE
            sameSpecies = false,
            balanced = true
        }
    }
end

-- Create realistic battle state for AI testing
function IntegrationStubs.createBattleState(trainerPokemon, playerPokemon)
    return {
        trainer = {
            activeIndex = 0,
            party = trainerPokemon or {
                { species = 25, level = 20, currentHP = 100, maxHP = 100 },
                { species = 6, level = 22, currentHP = 120, maxHP = 120 }
            }
        },
        player = {
            activeIndex = 0,
            party = playerPokemon or {
                { species = 130, level = 25, currentHP = 150, maxHP = 150 }
            }
        }
    }
end

return IntegrationStubs
