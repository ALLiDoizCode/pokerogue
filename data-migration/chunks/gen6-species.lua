-- Pokemon Species Database - Generation 6 Chunk
-- Generated: 2025-09-23T17:28:47.095Z
-- Species Count: 18

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen6Species = {
    [656] = {
        id = 656, n = "Bubble Frog Pokémon",
        bs = {41, 56, 40, 62, 44, 71}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.PROTEAN}, -- abilities: primary, secondary, hidden
        h = 3, w = 70, -- height (dm), weight (hg)
        gen = 6
    },
    [657] = {
        id = 657, n = "Bubble Frog Pokémon",
        bs = {54, 63, 52, 83, 56, 97}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.PROTEAN}, -- abilities: primary, secondary, hidden
        h = 6, w = 109, -- height (dm), weight (hg)
        gen = 6
    },
    [658] = {
        id = 658, n = "Ninja Pokémon",
        bs = {72, 95, 67, 103, 71, 122}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER, POKEMON_TYPE.DARK}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.PROTEAN}, -- abilities: primary, secondary, hidden
        h = 15, w = 400, -- height (dm), weight (hg)
        gen = 6
    },
    [664] = {
        id = 664, n = "Scatterdust Pokémon",
        bs = {38, 35, 40, 27, 25, 35}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG}, -- types
        ab = {ABILITY.SHIELD_DUST, ABILITY.COMPOUND_EYES, ABILITY.FRIEND_GUARD}, -- abilities: primary, secondary, hidden
        h = 3, w = 25, -- height (dm), weight (hg)
        gen = 6
    },
    [665] = {
        id = 665, n = "Scatterdust Pokémon",
        bs = {45, 22, 60, 27, 30, 29}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG}, -- types
        ab = {ABILITY.SHED_SKIN, ABILITY.SHED_SKIN, ABILITY.FRIEND_GUARD}, -- abilities: primary, secondary, hidden
        h = 3, w = 84, -- height (dm), weight (hg)
        gen = 6
    },
    [666] = {
        id = 666, n = "Scale Pokémon",
        bs = {80, 52, 50, 90, 50, 89}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.SHIELD_DUST, ABILITY.COMPOUND_EYES, ABILITY.FRIEND_GUARD}, -- abilities: primary, secondary, hidden
        h = 12, w = 170, -- height (dm), weight (hg)
        gen = 6
    },
    [669] = {
        id = 669, n = "Single Bloom Pokémon",
        bs = {44, 38, 39, 61, 79, 42}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.FLOWER_VEIL, ABILITY.NONE, ABILITY.SYMBIOSIS}, -- abilities: primary, secondary, hidden
        h = 1, w = 1, -- height (dm), weight (hg)
        gen = 6
    },
    [670] = {
        id = 670, n = "Single Bloom Pokémon",
        bs = {54, 45, 47, 75, 98, 52}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.FLOWER_VEIL, ABILITY.NONE, ABILITY.SYMBIOSIS}, -- abilities: primary, secondary, hidden
        h = 2, w = 9, -- height (dm), weight (hg)
        gen = 6
    },
    [671] = {
        id = 671, n = "Garden Pokémon",
        bs = {78, 65, 68, 112, 154, 75}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.FLOWER_VEIL, ABILITY.NONE, ABILITY.SYMBIOSIS}, -- abilities: primary, secondary, hidden
        h = 11, w = 100, -- height (dm), weight (hg)
        gen = 6
    },
    [676] = {
        id = 676, n = "Poodle Pokémon",
        bs = {75, 80, 60, 65, 90, 102}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.FUR_COAT, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 12, w = 280, -- height (dm), weight (hg)
        gen = 6
    },
    [678] = {
        id = 678, n = "Constraint Pokémon",
        bs = {74, 48, 76, 83, 81, 104}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.PSYCHIC}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.INFILTRATOR, ABILITY.PRANKSTER}, -- abilities: primary, secondary, hidden
        h = 6, w = 85, -- height (dm), weight (hg)
        gen = 6
    },
    [681] = {
        id = 681, n = "Royal Sword Pokémon",
        bs = {60, 50, 140, 50, 140, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL, POKEMON_TYPE.GHOST}, -- types
        ab = {ABILITY.STANCE_CHANGE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 17, w = 530, -- height (dm), weight (hg)
        gen = 6
    },
    [710] = {
        id = 710, n = "Pumpkin Pokémon",
        bs = {49, 66, 70, 44, 55, 51}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GHOST, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.PICKUP, ABILITY.FRISK, ABILITY.INSOMNIA}, -- abilities: primary, secondary, hidden
        h = 4, w = 50, -- height (dm), weight (hg)
        gen = 6
    },
    [711] = {
        id = 711, n = "Pumpkin Pokémon",
        bs = {65, 90, 122, 58, 75, 84}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GHOST, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.PICKUP, ABILITY.FRISK, ABILITY.INSOMNIA}, -- abilities: primary, secondary, hidden
        h = 9, w = 125, -- height (dm), weight (hg)
        gen = 6
    },
    [716] = {
        id = 716, n = "Life Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 6
    },
    [718] = {
        id = 718, n = "Order Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 6
    },
    [719] = {
        id = 719, n = "Jewel Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 6
    },
    [720] = {
        id = 720, n = "Mischief Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 6
    }
}

return Gen6Species