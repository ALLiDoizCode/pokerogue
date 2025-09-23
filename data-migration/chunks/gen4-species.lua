-- Pokemon Species Database - Generation 4 Chunk
-- Generated: 2025-09-23T17:28:47.094Z
-- Species Count: 16

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen4Species = {
    [412] = {
        id = 412, n = "Bagworm Pokémon",
        bs = {40, 29, 45, 29, 45, 36}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG}, -- types
        ab = {ABILITY.SHED_SKIN, ABILITY.NONE, ABILITY.OVERCOAT}, -- abilities: primary, secondary, hidden
        h = 2, w = 34, -- height (dm), weight (hg)
        gen = 4
    },
    [413] = {
        id = 413, n = "Bagworm Pokémon",
        bs = {60, 59, 85, 79, 105, 36}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.ANTICIPATION, ABILITY.NONE, ABILITY.OVERCOAT}, -- abilities: primary, secondary, hidden
        h = 5, w = 65, -- height (dm), weight (hg)
        gen = 4
    },
    [421] = {
        id = 421, n = "Blossom Pokémon",
        bs = {70, 60, 70, 87, 78, 85}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.FLOWER_GIFT, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 5, w = 93, -- height (dm), weight (hg)
        gen = 4
    },
    [422] = {
        id = 422, n = "Sea Slug Pokémon",
        bs = {76, 48, 48, 57, 62, 34}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.STICKY_HOLD, ABILITY.STORM_DRAIN, ABILITY.SAND_FORCE}, -- abilities: primary, secondary, hidden
        h = 3, w = 63, -- height (dm), weight (hg)
        gen = 4
    },
    [423] = {
        id = 423, n = "Sea Slug Pokémon",
        bs = {111, 83, 68, 92, 82, 39}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.STICKY_HOLD, ABILITY.STORM_DRAIN, ABILITY.SAND_FORCE}, -- abilities: primary, secondary, hidden
        h = 9, w = 299, -- height (dm), weight (hg)
        gen = 4
    },
    [428] = {
        id = 428, n = "Rabbit Pokémon",
        bs = {65, 76, 84, 54, 96, 105}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.CUTE_CHARM, ABILITY.KLUTZ, ABILITY.LIMBER}, -- abilities: primary, secondary, hidden
        h = 12, w = 333, -- height (dm), weight (hg)
        gen = 4
    },
    [445] = {
        id = 445, n = "Mach Pokémon",
        bs = {108, 130, 95, 80, 85, 102}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DRAGON, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.SAND_VEIL, ABILITY.NONE, ABILITY.ROUGH_SKIN}, -- abilities: primary, secondary, hidden
        h = 19, w = 950, -- height (dm), weight (hg)
        gen = 4
    },
    [448] = {
        id = 448, n = "Aura Pokémon",
        bs = {70, 110, 70, 115, 70, 90}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIGHTING, POKEMON_TYPE.STEEL}, -- types
        ab = {ABILITY.STEADFAST, ABILITY.INNER_FOCUS, ABILITY.JUSTIFIED}, -- abilities: primary, secondary, hidden
        h = 12, w = 540, -- height (dm), weight (hg)
        gen = 4
    },
    [460] = {
        id = 460, n = "Frost Tree Pokémon",
        bs = {90, 92, 75, 92, 85, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.ICE}, -- types
        ab = {ABILITY.SNOW_WARNING, ABILITY.NONE, ABILITY.SOUNDPROOF}, -- abilities: primary, secondary, hidden
        h = 22, w = 1355, -- height (dm), weight (hg)
        gen = 4
    },
    [475] = {
        id = 475, n = "Blade Pokémon",
        bs = {68, 125, 65, 65, 115, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.PSYCHIC, POKEMON_TYPE.FIGHTING}, -- types
        ab = {ABILITY.STEADFAST, ABILITY.SHARPNESS, ABILITY.JUSTIFIED}, -- abilities: primary, secondary, hidden
        h = 16, w = 520, -- height (dm), weight (hg)
        gen = 4
    },
    [479] = {
        id = 479, n = "Plasma Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 4
    },
    [483] = {
        id = 483, n = "Temporal Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 4
    },
    [484] = {
        id = 484, n = "Spatial Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 4
    },
    [487] = {
        id = 487, n = "Renegade Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 4
    },
    [492] = {
        id = 492, n = "Gratitude Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 4
    },
    [493] = {
        id = 493, n = "Alpha Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 4
    }
}

return Gen4Species