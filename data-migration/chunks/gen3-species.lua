-- Pokemon Species Database - Generation 3 Chunk
-- Generated: 2025-09-23T17:28:47.093Z
-- Species Count: 24

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen3Species = {
    [254] = {
        id = 254, n = "Forest Pokémon",
        bs = {70, 85, 65, 105, 85, 120}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.OVERGROW, ABILITY.NONE, ABILITY.UNBURDEN}, -- abilities: primary, secondary, hidden
        h = 17, w = 522, -- height (dm), weight (hg)
        gen = 3
    },
    [257] = {
        id = 257, n = "Blaze Pokémon",
        bs = {80, 120, 70, 110, 70, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE, POKEMON_TYPE.FIGHTING}, -- types
        ab = {ABILITY.BLAZE, ABILITY.NONE, ABILITY.SPEED_BOOST}, -- abilities: primary, secondary, hidden
        h = 19, w = 520, -- height (dm), weight (hg)
        gen = 3
    },
    [260] = {
        id = 260, n = "Mud Fish Pokémon",
        bs = {100, 110, 90, 85, 90, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.DAMP}, -- abilities: primary, secondary, hidden
        h = 15, w = 819, -- height (dm), weight (hg)
        gen = 3
    },
    [282] = {
        id = 282, n = "Embrace Pokémon",
        bs = {68, 65, 65, 125, 115, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.PSYCHIC, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.SYNCHRONIZE, ABILITY.TRACE, ABILITY.TELEPATHY}, -- abilities: primary, secondary, hidden
        h = 16, w = 484, -- height (dm), weight (hg)
        gen = 3
    },
    [302] = {
        id = 302, n = "Darkness Pokémon",
        bs = {50, 75, 75, 65, 65, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DARK, POKEMON_TYPE.GHOST}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.STALL, ABILITY.PRANKSTER}, -- abilities: primary, secondary, hidden
        h = 5, w = 110, -- height (dm), weight (hg)
        gen = 3
    },
    [303] = {
        id = 303, n = "Deceiver Pokémon",
        bs = {50, 85, 85, 55, 55, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.HYPER_CUTTER, ABILITY.INTIMIDATE, ABILITY.SHEER_FORCE}, -- abilities: primary, secondary, hidden
        h = 6, w = 115, -- height (dm), weight (hg)
        gen = 3
    },
    [306] = {
        id = 306, n = "Iron Armor Pokémon",
        bs = {70, 110, 180, 60, 60, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL, POKEMON_TYPE.ROCK}, -- types
        ab = {ABILITY.STURDY, ABILITY.ROCK_HEAD, ABILITY.HEAVY_METAL}, -- abilities: primary, secondary, hidden
        h = 21, w = 3600, -- height (dm), weight (hg)
        gen = 3
    },
    [308] = {
        id = 308, n = "Meditate Pokémon",
        bs = {60, 60, 75, 60, 75, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIGHTING, POKEMON_TYPE.PSYCHIC}, -- types
        ab = {ABILITY.PURE_POWER, ABILITY.NONE, ABILITY.TELEPATHY}, -- abilities: primary, secondary, hidden
        h = 13, w = 315, -- height (dm), weight (hg)
        gen = 3
    },
    [310] = {
        id = 310, n = "Discharge Pokémon",
        bs = {70, 75, 60, 105, 60, 105}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC}, -- types
        ab = {ABILITY.STATIC, ABILITY.LIGHTNING_ROD, ABILITY.MINUS}, -- abilities: primary, secondary, hidden
        h = 15, w = 402, -- height (dm), weight (hg)
        gen = 3
    },
    [319] = {
        id = 319, n = "Brutal Pokémon",
        bs = {70, 120, 40, 95, 40, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER, POKEMON_TYPE.DARK}, -- types
        ab = {ABILITY.ROUGH_SKIN, ABILITY.NONE, ABILITY.SPEED_BOOST}, -- abilities: primary, secondary, hidden
        h = 18, w = 888, -- height (dm), weight (hg)
        gen = 3
    },
    [323] = {
        id = 323, n = "Eruption Pokémon",
        bs = {70, 100, 70, 105, 75, 40}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.MAGMA_ARMOR, ABILITY.SOLID_ROCK, ABILITY.ANGER_POINT}, -- abilities: primary, secondary, hidden
        h = 19, w = 2200, -- height (dm), weight (hg)
        gen = 3
    },
    [334] = {
        id = 334, n = "Humming Pokémon",
        bs = {75, 70, 90, 70, 105, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DRAGON, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.NATURAL_CURE, ABILITY.NONE, ABILITY.CLOUD_NINE}, -- abilities: primary, secondary, hidden
        h = 11, w = 206, -- height (dm), weight (hg)
        gen = 3
    },
    [351] = {
        id = 351, n = "Weather Pokémon",
        bs = {70, 70, 70, 70, 70, 70}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.FORECAST, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 3, w = 8, -- height (dm), weight (hg)
        gen = 3
    },
    [354] = {
        id = 354, n = "Marionette Pokémon",
        bs = {64, 115, 65, 83, 63, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GHOST}, -- types
        ab = {ABILITY.INSOMNIA, ABILITY.FRISK, ABILITY.CURSED_BODY}, -- abilities: primary, secondary, hidden
        h = 11, w = 125, -- height (dm), weight (hg)
        gen = 3
    },
    [359] = {
        id = 359, n = "Disaster Pokémon",
        bs = {65, 130, 60, 75, 60, 75}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DARK}, -- types
        ab = {ABILITY.PRESSURE, ABILITY.SUPER_LUCK, ABILITY.JUSTIFIED}, -- abilities: primary, secondary, hidden
        h = 12, w = 470, -- height (dm), weight (hg)
        gen = 3
    },
    [362] = {
        id = 362, n = "Face Pokémon",
        bs = {80, 80, 80, 80, 80, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ICE}, -- types
        ab = {ABILITY.INNER_FOCUS, ABILITY.ICE_BODY, ABILITY.MOODY}, -- abilities: primary, secondary, hidden
        h = 15, w = 2565, -- height (dm), weight (hg)
        gen = 3
    },
    [373] = {
        id = 373, n = "Dragon Pokémon",
        bs = {95, 135, 80, 110, 80, 100}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DRAGON, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.INTIMIDATE, ABILITY.NONE, ABILITY.MOXIE}, -- abilities: primary, secondary, hidden
        h = 15, w = 1026, -- height (dm), weight (hg)
        gen = 3
    },
    [376] = {
        id = 376, n = "Iron Leg Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 3
    },
    [380] = {
        id = 380, n = "Eon Pokémon",
        bs = {80, 80, 90, 110, 130, 110}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DRAGON, POKEMON_TYPE.PSYCHIC}, -- types
        ab = {ABILITY.LEVITATE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 14, w = 400, -- height (dm), weight (hg)
        gen = 3
    },
    [381] = {
        id = 381, n = "Eon Pokémon",
        bs = {80, 90, 80, 130, 110, 110}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DRAGON, POKEMON_TYPE.PSYCHIC}, -- types
        ab = {ABILITY.LEVITATE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 20, w = 600, -- height (dm), weight (hg)
        gen = 3
    },
    [382] = {
        id = 382, n = "Sea Basin Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 3
    },
    [383] = {
        id = 383, n = "Continent Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 3
    },
    [384] = {
        id = 384, n = "Sky High Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 3
    },
    [386] = {
        id = 386, n = "DNA Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 3
    }
}

return Gen3Species