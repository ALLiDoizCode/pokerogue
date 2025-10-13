-- Pokemon Species Database - Generation 5 Chunk
-- Generated: 2025-09-23T17:28:47.095Z
-- Species Count: 13

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen5Species = {
    [531] = {
        id = 531, n = "Hearing Pokémon",
        bs = {103, 60, 86, 60, 86, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.HEALER, ABILITY.REGENERATOR, ABILITY.KLUTZ}, -- abilities: primary, secondary, hidden
        h = 11, w = 310, -- height (dm), weight (hg)
        gen = 5
    },
    [550] = {
        id = 550, n = "Hostile Pokémon",
        bs = {70, 92, 65, 80, 55, 98}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.RECKLESS, ABILITY.ADAPTABILITY, ABILITY.MOLD_BREAKER}, -- abilities: primary, secondary, hidden
        h = 10, w = 180, -- height (dm), weight (hg)
        gen = 5
    },
    [555] = {
        id = 555, n = "Blazing Pokémon",
        bs = {105, 140, 55, 30, 55, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.SHEER_FORCE, ABILITY.NONE, ABILITY.ZEN_MODE}, -- abilities: primary, secondary, hidden
        h = 13, w = 929, -- height (dm), weight (hg)
        gen = 5
    },
    [569] = {
        id = 569, n = "Trash Heap Pokémon",
        bs = {80, 95, 82, 60, 82, 75}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.STENCH, ABILITY.WEAK_ARMOR, ABILITY.AFTERMATH}, -- abilities: primary, secondary, hidden
        h = 19, w = 1073, -- height (dm), weight (hg)
        gen = 5
    },
    [585] = {
        id = 585, n = "Season Pokémon",
        bs = {60, 60, 50, 40, 50, 75}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.CHLOROPHYLL, ABILITY.SAP_SIPPER, ABILITY.SERENE_GRACE}, -- abilities: primary, secondary, hidden
        h = 6, w = 195, -- height (dm), weight (hg)
        gen = 5
    },
    [586] = {
        id = 586, n = "Season Pokémon",
        bs = {80, 100, 70, 60, 70, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.CHLOROPHYLL, ABILITY.SAP_SIPPER, ABILITY.SERENE_GRACE}, -- abilities: primary, secondary, hidden
        h = 19, w = 925, -- height (dm), weight (hg)
        gen = 5
    },
    [641] = {
        id = 641, n = "Cyclone Pokémon",
        bs = {79, 115, 70, 125, 80, 111}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.PRANKSTER, ABILITY.NONE, ABILITY.DEFIANT}, -- abilities: primary, secondary, hidden
        h = 15, w = 630, -- height (dm), weight (hg)
        gen = 5
    },
    [642] = {
        id = 642, n = "Bolt Strike Pokémon",
        bs = {79, 115, 70, 125, 80, 111}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.PRANKSTER, ABILITY.NONE, ABILITY.DEFIANT}, -- abilities: primary, secondary, hidden
        h = 15, w = 610, -- height (dm), weight (hg)
        gen = 5
    },
    [645] = {
        id = 645, n = "Abundance Pokémon",
        bs = {89, 125, 90, 115, 80, 101}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GROUND, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.SAND_FORCE, ABILITY.NONE, ABILITY.SHEER_FORCE}, -- abilities: primary, secondary, hidden
        h = 15, w = 680, -- height (dm), weight (hg)
        gen = 5
    },
    [646] = {
        id = 646, n = "Boundary Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 5
    },
    [647] = {
        id = 647, n = "Colt Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 5
    },
    [648] = {
        id = 648, n = "Melody Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 5
    },
    [649] = {
        id = 649, n = "Paleozoic Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 5
    }
}

return Gen5Species