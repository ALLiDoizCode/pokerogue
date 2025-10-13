-- Pokemon Species Database - Generation 8 Chunk
-- Generated: 2025-09-23T17:28:47.096Z
-- Species Count: 32

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    -- Additional abilities will be populated as needed
}

local Gen8Species = {
    [812] = {
        id = 812, n = "Drummer Pokémon",
        bs = {100, 125, 90, 60, 70, 85}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.OVERGROW, ABILITY.NONE, ABILITY.GRASSY_SURGE}, -- abilities: primary, secondary, hidden
        h = 21, w = 900, -- height (dm), weight (hg)
        gen = 8
    },
    [815] = {
        id = 815, n = "Striker Pokémon",
        bs = {80, 116, 75, 65, 75, 119}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.BLAZE, ABILITY.NONE, ABILITY.LIBERO}, -- abilities: primary, secondary, hidden
        h = 14, w = 330, -- height (dm), weight (hg)
        gen = 8
    },
    [818] = {
        id = 818, n = "Secret Agent Pokémon",
        bs = {70, 85, 65, 125, 65, 120}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.SNIPER}, -- abilities: primary, secondary, hidden
        h = 19, w = 452, -- height (dm), weight (hg)
        gen = 8
    },
    [823] = {
        id = 823, n = "Raven Pokémon",
        bs = {98, 87, 105, 53, 85, 67}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FLYING, POKEMON_TYPE.STEEL}, -- types
        ab = {ABILITY.PRESSURE, ABILITY.UNNERVE, ABILITY.MIRROR_ARMOR}, -- abilities: primary, secondary, hidden
        h = 22, w = 750, -- height (dm), weight (hg)
        gen = 8
    },
    [826] = {
        id = 826, n = "Seven Spot Pokémon",
        bs = {60, 45, 110, 80, 120, 90}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.PSYCHIC}, -- types
        ab = {ABILITY.SWARM, ABILITY.FRISK, ABILITY.TELEPATHY}, -- abilities: primary, secondary, hidden
        h = 4, w = 408, -- height (dm), weight (hg)
        gen = 8
    },
    [834] = {
        id = 834, n = "Bite Pokémon",
        bs = {90, 115, 90, 48, 68, 74}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER, POKEMON_TYPE.ROCK}, -- types
        ab = {ABILITY.STRONG_JAW, ABILITY.SHELL_ARMOR, ABILITY.SWIFT_SWIM}, -- abilities: primary, secondary, hidden
        h = 10, w = 1155, -- height (dm), weight (hg)
        gen = 8
    },
    [839] = {
        id = 839, n = "Coal Pokémon",
        bs = {110, 80, 120, 80, 90, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ROCK, POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.STEAM_ENGINE, ABILITY.FLAME_BODY, ABILITY.FLASH_FIRE}, -- abilities: primary, secondary, hidden
        h = 28, w = 3105, -- height (dm), weight (hg)
        gen = 8
    },
    [841] = {
        id = 841, n = "Apple Wing Pokémon",
        bs = {70, 110, 80, 95, 60, 70}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.DRAGON}, -- types
        ab = {ABILITY.RIPEN, ABILITY.GLUTTONY, ABILITY.HUSTLE}, -- abilities: primary, secondary, hidden
        h = 3, w = 10, -- height (dm), weight (hg)
        gen = 8
    },
    [842] = {
        id = 842, n = "Apple Nectar Pokémon",
        bs = {110, 85, 80, 100, 80, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.DRAGON}, -- types
        ab = {ABILITY.RIPEN, ABILITY.GLUTTONY, ABILITY.THICK_FAT}, -- abilities: primary, secondary, hidden
        h = 4, w = 130, -- height (dm), weight (hg)
        gen = 8
    },
    [844] = {
        id = 844, n = "Sand Snake Pokémon",
        bs = {72, 107, 125, 65, 70, 71}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.SAND_SPIT, ABILITY.SHED_SKIN, ABILITY.SAND_VEIL}, -- abilities: primary, secondary, hidden
        h = 38, w = 655, -- height (dm), weight (hg)
        gen = 8
    },
    [845] = {
        id = 845, n = "Gulp Pokémon",
        bs = {70, 85, 55, 85, 95, 85}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FLYING, POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.GULP_MISSILE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 8, w = 180, -- height (dm), weight (hg)
        gen = 8
    },
    [849] = {
        id = 849, n = "Punk Pokémon",
        bs = {75, 98, 70, 114, 70, 75}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.PUNK_ROCK, ABILITY.PLUS, ABILITY.TECHNICIAN}, -- abilities: primary, secondary, hidden
        h = 16, w = 400, -- height (dm), weight (hg)
        gen = 8
    },
    [851] = {
        id = 851, n = "Radiator Pokémon",
        bs = {100, 115, 65, 90, 90, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE, POKEMON_TYPE.BUG}, -- types
        ab = {ABILITY.FLASH_FIRE, ABILITY.WHITE_SMOKE, ABILITY.FLAME_BODY}, -- abilities: primary, secondary, hidden
        h = 30, w = 1200, -- height (dm), weight (hg)
        gen = 8
    },
    [854] = {
        id = 854, n = "Black Tea Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [855] = {
        id = 855, n = "Black Tea Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [858] = {
        id = 858, n = "Silent Pokémon",
        bs = {57, 90, 95, 136, 103, 29}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.PSYCHIC, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.HEALER, ABILITY.ANTICIPATION, ABILITY.MAGIC_BOUNCE}, -- abilities: primary, secondary, hidden
        h = 21, w = 51, -- height (dm), weight (hg)
        gen = 8
    },
    [861] = {
        id = 861, n = "Bulk Up Pokémon",
        bs = {95, 120, 65, 95, 75, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.DARK, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.PRANKSTER, ABILITY.FRISK, ABILITY.PICKPOCKET}, -- abilities: primary, secondary, hidden
        h = 15, w = 610, -- height (dm), weight (hg)
        gen = 8
    },
    [869] = {
        id = 869, n = "Cream Pokémon",
        bs = {65, 60, 75, 110, 121, 64}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.SWEET_VEIL, ABILITY.NONE, ABILITY.AROMA_VEIL}, -- abilities: primary, secondary, hidden
        h = 3, w = 5, -- height (dm), weight (hg)
        gen = 8
    },
    [875] = {
        id = 875, n = "Penguin Pokémon",
        bs = {75, 80, 110, 65, 90, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ICE}, -- types
        ab = {ABILITY.ICE_FACE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 14, w = 890, -- height (dm), weight (hg)
        gen = 8
    },
    [876] = {
        id = 876, n = "Emotion Pokémon",
        bs = {60, 65, 55, 105, 95, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.PSYCHIC, POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.INNER_FOCUS, ABILITY.SYNCHRONIZE, ABILITY.PSYCHIC_SURGE}, -- abilities: primary, secondary, hidden
        h = 9, w = 280, -- height (dm), weight (hg)
        gen = 8
    },
    [877] = {
        id = 877, n = "Two-Sided Pokémon",
        bs = {58, 95, 58, 70, 58, 97}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC, POKEMON_TYPE.DARK}, -- types
        ab = {ABILITY.HUNGER_SWITCH, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 3, w = 30, -- height (dm), weight (hg)
        gen = 8
    },
    [879] = {
        id = 879, n = "Copperderm Pokémon",
        bs = {122, 130, 69, 80, 69, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL}, -- types
        ab = {ABILITY.SHEER_FORCE, ABILITY.NONE, ABILITY.HEAVY_METAL}, -- abilities: primary, secondary, hidden
        h = 30, w = 6500, -- height (dm), weight (hg)
        gen = 8
    },
    [884] = {
        id = 884, n = "Alloy Pokémon",
        bs = {70, 95, 115, 120, 50, 85}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.STEEL, POKEMON_TYPE.DRAGON}, -- types
        ab = {ABILITY.LIGHT_METAL, ABILITY.HEAVY_METAL, ABILITY.STALWART}, -- abilities: primary, secondary, hidden
        h = 18, w = 400, -- height (dm), weight (hg)
        gen = 8
    },
    [888] = {
        id = 888, n = "Warrior Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [889] = {
        id = 889, n = "Warrior Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [890] = {
        id = 890, n = "Gigantic Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [892] = {
        id = 892, n = "Wushu Pokémon",
        bs = {100, 130, 100, 63, 60, 97}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIGHTING, POKEMON_TYPE.DARK}, -- types
        ab = {ABILITY.UNSEEN_FIST, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 19, w = 1050, -- height (dm), weight (hg)
        gen = 8
    },
    [893] = {
        id = 893, n = "Rogue Monkey Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [898] = {
        id = 898, n = "King Pokémon",
        bs = {50, 50, 50, 50, 50, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.NONE, ABILITY.NONE, ABILITY.NONE}, -- abilities: primary, secondary, hidden
        h = 10, w = 100, -- height (dm), weight (hg)
        gen = 8
    },
    [902] = {
        id = 902, n = "Big Fish Pokémon",
        bs = {120, 112, 65, 80, 75, 78}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER, POKEMON_TYPE.GHOST}, -- types
        ab = {ABILITY.SWIFT_SWIM, ABILITY.ADAPTABILITY, ABILITY.MOLD_BREAKER}, -- abilities: primary, secondary, hidden
        h = 30, w = 1100, -- height (dm), weight (hg)
        gen = 8
    },
    [905] = {
        id = 905, n = "Love-Hate Pokémon",
        bs = {74, 115, 70, 135, 80, 106}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.CUTE_CHARM, ABILITY.NONE, ABILITY.CONTRARY}, -- abilities: primary, secondary, hidden
        h = 16, w = 480, -- height (dm), weight (hg)
        gen = 8
    },
    [1061] = {
        id = 1061, n = "Blazing Pokémon",
        bs = {105, 140, 55, 30, 55, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ICE}, -- types
        ab = {ABILITY.GORILLA_TACTICS, ABILITY.NONE, ABILITY.ZEN_MODE}, -- abilities: primary, secondary, hidden
        h = 17, w = 1200, -- height (dm), weight (hg)
        gen = 8
    }
}

return Gen8Species