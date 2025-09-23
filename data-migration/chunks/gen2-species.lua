-- Pokemon Species Database - Generation 2 Chunk
-- Generated: 2025-09-23T17:28:47.092Z
-- Species Count: 8

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen2Species = {
    [172] = {
        id = 172, n = "Tiny Mouse Pokémon",
        bs = {20, 40, 15, 35, 35, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC}, -- types
        ab = {ABILITY.STATIC, ABILITY.NONE, ABILITY.LIGHTNING_ROD}, -- abilities: primary, secondary, hidden
        h = 3, w = 20, -- height (dm), weight (hg)
        gen = 2
    },
    [181] = {
        id = 181, n = "Light Pokémon",
        bs = {90, 75, 85, 115, 90, 55}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC}, -- types
        ab = {ABILITY.STATIC, ABILITY.NONE, ABILITY.PLUS}, -- abilities: primary, secondary, hidden
        h = 14, w = 615, -- height (dm), weight (hg)
        gen = 2
    },
    [201] = {
        id = 201, n = "Symbol Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 2
    },
    [208] = {
        id = 208, n = "Iron Snake Pokémon",
        bs = {75, 85, 200, 55, 65, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.ROCK_HEAD, ABILITY.STURDY, ABILITY.SHEER_FORCE}, -- abilities: primary, secondary, hidden
        h = 92, w = 4000, -- height (dm), weight (hg)
        gen = 2
    },
    [212] = {
        id = 212, n = "Pincer Pokémon",
        bs = {70, 130, 100, 55, 80, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.STEEL}, -- types
        ab = {ABILITY.SWARM, ABILITY.TECHNICIAN, ABILITY.LIGHT_METAL}, -- abilities: primary, secondary, hidden
        h = 18, w = 1180, -- height (dm), weight (hg)
        gen = 2
    },
    [214] = {
        id = 214, n = "Single Horn Pokémon",
        bs = {80, 125, 75, 40, 95, 85}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.FIGHTING}, -- types
        ab = {ABILITY.SWARM, ABILITY.GUTS, ABILITY.MOXIE}, -- abilities: primary, secondary, hidden
        h = 15, w = 540, -- height (dm), weight (hg)
        gen = 2
    },
    [229] = {
        id = 229, n = "Dark Pokémon",
        bs = {75, 90, 50, 110, 80, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DARK, POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.EARLY_BIRD, ABILITY.FLASH_FIRE, ABILITY.UNNERVE}, -- abilities: primary, secondary, hidden
        h = 14, w = 350, -- height (dm), weight (hg)
        gen = 2
    },
    [248] = {
        id = 248, n = "Armor Pokémon",
        bs = {100, 134, 110, 95, 100, 61}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ROCK, POKEMON_TYPE.DARK}, -- types
        ab = {ABILITY.SAND_STREAM, ABILITY.NONE, ABILITY.UNNERVE}, -- abilities: primary, secondary, hidden
        h = 20, w = 2020, -- height (dm), weight (hg)
        gen = 2
    }
}

return Gen2Species