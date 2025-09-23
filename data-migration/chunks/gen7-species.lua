-- Pokemon Species Database - Generation 7 Chunk
-- Generated: 2025-09-23T17:28:47.095Z
-- Species Count: 11

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen7Species = {
    [741] = {
        id = 741, n = "Dancing Pokémon",
        bs = {75, 70, 70, 98, 70, 93}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.DANCER, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 6, w = 34, -- height (dm), weight (hg)
        gen = 7
    },
    [744] = {
        id = 744, n = "Puppy Pokémon",
        bs = {45, 65, 40, 30, 40, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ROCK}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.VITAL_SPIRIT, ABILITY.STEADFAST}, -- abilities: primary, secondary, hidden
        h = 5, w = 92, -- height (dm), weight (hg)
        gen = 7
    },
    [745] = {
        id = 745, n = "Wolf Pokémon",
        bs = {75, 115, 65, 55, 65, 112}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ROCK}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.SAND_RUSH, ABILITY.STEADFAST}, -- abilities: primary, secondary, hidden
        h = 8, w = 250, -- height (dm), weight (hg)
        gen = 7
    },
    [746] = {
        id = 746, n = "Small Fry Pokémon",
        bs = {45, 20, 20, 25, 25, 40}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.SCHOOLING, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 2, w = 3, -- height (dm), weight (hg)
        gen = 7
    },
    [773] = {
        id = 773, n = "Synthetic Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 7
    },
    [774] = {
        id = 774, n = "Meteor Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 7
    },
    [778] = {
        id = 778, n = "Disguise Pokémon",
        bs = {55, 90, 80, 50, 105, 96}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GHOST, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.DISGUISE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 2, w = 7, -- height (dm), weight (hg)
        gen = 7
    },
    [800] = {
        id = 800, n = "Prism Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 7
    },
    [801] = {
        id = 801, n = "Artificial Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 7
    },
    [802] = {
        id = 802, n = "Gloomdweller Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 7
    },
    [809] = {
        id = 809, n = "Hex Nut Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 7
    }
}

return Gen7Species