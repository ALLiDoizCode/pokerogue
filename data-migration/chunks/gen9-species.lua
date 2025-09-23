-- Pokemon Species Database - Generation 9 Chunk
-- Generated: 2025-09-23T17:28:47.096Z
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

local Gen9Species = {
    [916] = {
        id = 916, n = "Hog Pokémon",
        bs = {110, 100, 75, 59, 80, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.LINGERING_AROMA, ABILITY.GLUTTONY, ABILITY.THICK_FAT}, -- abilities: primary, secondary, hidden
        h = 10, w = 1200, -- height (dm), weight (hg)
        gen = 9
    },
    [925] = {
        id = 925, n = "Family Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 9
    },
    [931] = {
        id = 931, n = "Parrot Pokémon",
        bs = {82, 96, 51, 45, 51, 92}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.INTIMIDATE, ABILITY.HUSTLE, ABILITY.GUTS}, -- abilities: primary, secondary, hidden
        h = 6, w = 24, -- height (dm), weight (hg)
        gen = 9
    },
    [964] = {
        id = 964, n = "Dolphin Pokémon",
        bs = {100, 70, 72, 53, 62, 100}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.ZERO_TO_HERO, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 13, w = 602, -- height (dm), weight (hg)
        gen = 9
    },
    [966] = {
        id = 966, n = "Multi-Cyl Pokémon",
        bs = {80, 119, 90, 54, 67, 90}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.OVERCOAT, ABILITY.NONE, ABILITY.FILTER}, -- abilities: primary, secondary, hidden
        h = 18, w = 1200, -- height (dm), weight (hg)
        gen = 9
    },
    [978] = {
        id = 978, n = "Mimicry Pokémon",
        bs = {68, 50, 60, 120, 95, 82}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DRAGON, POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.COMMANDER, ABILITY.NONE, ABILITY.STORM_DRAIN}, -- abilities: primary, secondary, hidden
        h = 3, w = 80, -- height (dm), weight (hg)
        gen = 9
    },
    [982] = {
        id = 982, n = "Land Snake Pokémon",
        bs = {125, 100, 80, 85, 75, 55}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.SERENE_GRACE, ABILITY.RUN_AWAY, ABILITY.RATTLED}, -- abilities: primary, secondary, hidden
        h = 36, w = 392, -- height (dm), weight (hg)
        gen = 9
    },
    [999] = {
        id = 999, n = "Coin Chest Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 9
    },
    [1007] = {
        id = 1007, n = "Paradox Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 9
    },
    [1008] = {
        id = 1008, n = "Paradox Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 9
    },
    [1012] = {
        id = 1012, n = "Matcha Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 9
    },
    [1013] = {
        id = 1013, n = "Matcha Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 9
    },
    [1017] = {
        id = 1017, n = "Mask Pokémon",
        bs = {80, 120, 84, 60, 96, 110}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.DEFIANT, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 12, w = 398, -- height (dm), weight (hg)
        gen = 9
    },
    [1024] = {
        id = 1024, n = "Tera Pokémon",
        bs = {90, 65, 85, 65, 85, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.TERA_SHIFT, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 2, w = 65, -- height (dm), weight (hg)
        gen = 9
    },
    [1080] = {
        id = 1080, n = "Wild Bull Pokémon",
        bs = {75, 110, 105, 30, 70, 100}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIGHTING}, -- types
        ab = {ABILITY.INTIMIDATE, ABILITY.ANGER_POINT, ABILITY.CUD_CHEW}, -- abilities: primary, secondary, hidden
        h = 14, w = 1150, -- height (dm), weight (hg)
        gen = 9
    },
    [1082] = {
        id = 1082, n = "Peat Pokémon",
        bs = {113, 70, 120, 135, 65, 52}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GROUND, POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.MINDS_EYE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 27, w = 3330, -- height (dm), weight (hg)
        gen = 9
    }
}

return Gen9Species