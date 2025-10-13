-- ============================================================================
-- MIGRATED POKEMON SPECIES DATABASE
-- Generated from TypeScript reference implementation
-- Generated on: 2025-09-23T15:49:51.913Z
-- Species count: 1000
-- ============================================================================

local SPECIES = {
    BULBASAUR = 1,
    IVYSAUR = 2,
    VENUSAUR = 3,
    CHARMANDER = 4,
    CHARMELEON = 5,
    CHARIZARD = 6,
    SQUIRTLE = 7,
    WARTORTLE = 8,
    BLASTOISE = 9,
    CATERPIE = 10,
    METAPOD = 11,
    BUTTERFREE = 12,
    WEEDLE = 13,
    KAKUNA = 14,
    BEEDRILL = 15,
    PIDGEY = 16,
    PIDGEOTTO = 17,
    PIDGEOT = 18,
    RATTATA = 19,
    RATICATE = 20,
    SPEAROW = 21,
    FEAROW = 22,
    EKANS = 23,
    ARBOK = 24,
    PIKACHU = 25,
    RAICHU = 26,
    SANDSHREW = 27,
    SANDSLASH = 28,
    NIDORAN_F = 29,
    NIDORINA = 30,
    NIDOQUEEN = 31,
    NIDORAN_M = 32,
    NIDORINO = 33,
    NIDOKING = 34,
    CLEFAIRY = 35,
    CLEFABLE = 36,
    VULPIX = 37,
    NINETALES = 38,
    JIGGLYPUFF = 39,
    WIGGLYTUFF = 40,
    ZUBAT = 41,
    GOLBAT = 42,
    ODDISH = 43,
    GLOOM = 44,
    VILEPLUME = 45,
    PARAS = 46,
    PARASECT = 47,
    VENONAT = 48,
    VENOMOTH = 49,
    DIGLETT = 50,
}

local POKEMON_TYPE = {
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 9,
    WATER = 10,
    GRASS = 11,
    ELECTRIC = 12,
    PSYCHIC = 13,
    ICE = 14,
    DRAGON = 15,
    DARK = 16,
    FAIRY = 17,
}

local ABILITY = {
    NONE = 0,
    OVERGROW = 65,
    BLAZE = 66,
    TORRENT = 67,
    SWARM = 68,
    CHLOROPHYLL = 34,
    SOLAR_POWER = 94,
    RAIN_DISH = 44,
    STATIC = 9,
    LIGHTNING_ROD = 31,
    PRESSURE = 46,
    UNNERVE = 186,
    THICK_FAT = 47,
    DROUGHT = 70,
    TOUGH_CLAWS = 181,
}

local SpeciesDatabase = {
    [SPECIES.BULBASAUR] = {
        id = 1, n = "Seed Pokémon",
        bs = {45, 49, 49, 65, 65, 45}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.OVERGROW, ABILITY.NONE, ABILITY.CHLOROPHYLL}, -- abilities: normal1, normal2, hidden
        h = 7, w = 69, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 64, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.IVYSAUR] = {
        id = 2, n = "Seed Pokémon",
        bs = {60, 62, 63, 80, 80, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.OVERGROW, ABILITY.NONE, ABILITY.CHLOROPHYLL}, -- abilities: normal1, normal2, hidden
        h = 10, w = 130, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 142, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.VENUSAUR] = {
        id = 3, n = "Seed Pokémon",
        bs = {80, 82, 83, 100, 100, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.OVERGROW, ABILITY.NONE, ABILITY.CHLOROPHYLL}, -- abilities: normal1, normal2, hidden
        h = 20, w = 1000, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 263, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.CHARMANDER] = {
        id = 4, n = "Lizard Pokémon",
        bs = {39, 52, 43, 60, 50, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.BLAZE, ABILITY.NONE, ABILITY.SOLAR_POWER}, -- abilities: normal1, normal2, hidden
        h = 6, w = 85, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 62, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.CHARMELEON] = {
        id = 5, n = "Flame Pokémon",
        bs = {58, 64, 58, 80, 65, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.BLAZE, ABILITY.NONE, ABILITY.SOLAR_POWER}, -- abilities: normal1, normal2, hidden
        h = 11, w = 190, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 142, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.CHARIZARD] = {
        id = 6, n = "Flame Pokémon",
        bs = {78, 84, 78, 109, 85, 100}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.BLAZE, ABILITY.NONE, ABILITY.SOLAR_POWER}, -- abilities: normal1, normal2, hidden
        h = 17, w = 905, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 267, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.SQUIRTLE] = {
        id = 7, n = "Tiny Turtle Pokémon",
        bs = {44, 48, 65, 50, 64, 43}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.RAIN_DISH}, -- abilities: normal1, normal2, hidden
        h = 5, w = 90, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 63, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.WARTORTLE] = {
        id = 8, n = "Turtle Pokémon",
        bs = {59, 63, 80, 65, 80, 58}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.RAIN_DISH}, -- abilities: normal1, normal2, hidden
        h = 10, w = 225, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 142, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.BLASTOISE] = {
        id = 9, n = "Shellfish Pokémon",
        bs = {79, 83, 100, 85, 105, 78}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.WATER}, -- types
        ab = {ABILITY.TORRENT, ABILITY.NONE, ABILITY.RAIN_DISH}, -- abilities: normal1, normal2, hidden
        h = 16, w = 855, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 265, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.CATERPIE] = {
        id = 10, n = "Worm Pokémon",
        bs = {45, 30, 35, 20, 20, 45}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG}, -- types
        ab = {ABILITY.SHIELD_DUST, ABILITY.NONE, ABILITY.RUN_AWAY}, -- abilities: normal1, normal2, hidden
        h = 3, w = 29, -- height (dm), weight (hg)
        cr = 255, bf = 50, be = 39, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.METAPOD] = {
        id = 11, n = "Cocoon Pokémon",
        bs = {50, 20, 55, 25, 25, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG}, -- types
        ab = {ABILITY.SHED_SKIN, ABILITY.NONE, ABILITY.SHED_SKIN}, -- abilities: normal1, normal2, hidden
        h = 7, w = 99, -- height (dm), weight (hg)
        cr = 120, bf = 50, be = 72, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.BUTTERFREE] = {
        id = 12, n = "Butterfly Pokémon",
        bs = {60, 45, 50, 90, 80, 70}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.COMPOUND_EYES, ABILITY.NONE, ABILITY.TINTED_LENS}, -- abilities: normal1, normal2, hidden
        h = 11, w = 320, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 198, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.WEEDLE] = {
        id = 13, n = "Hairy Bug Pokémon",
        bs = {40, 35, 30, 20, 20, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.SHIELD_DUST, ABILITY.NONE, ABILITY.RUN_AWAY}, -- abilities: normal1, normal2, hidden
        h = 3, w = 32, -- height (dm), weight (hg)
        cr = 255, bf = 70, be = 39, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.KAKUNA] = {
        id = 14, n = "Cocoon Pokémon",
        bs = {45, 25, 50, 25, 25, 35}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.SHED_SKIN, ABILITY.NONE, ABILITY.SHED_SKIN}, -- abilities: normal1, normal2, hidden
        h = 6, w = 100, -- height (dm), weight (hg)
        cr = 120, bf = 70, be = 72, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.BEEDRILL] = {
        id = 15, n = "Poison Bee Pokémon",
        bs = {65, 90, 40, 45, 80, 75}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.SWARM, ABILITY.NONE, ABILITY.SNIPER}, -- abilities: normal1, normal2, hidden
        h = 10, w = 295, -- height (dm), weight (hg)
        cr = 45, bf = 70, be = 198, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.PIDGEY] = {
        id = 16, n = "Tiny Bird Pokémon",
        bs = {40, 45, 40, 35, 35, 56}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.TANGLED_FEET, ABILITY.BIG_PECKS}, -- abilities: normal1, normal2, hidden
        h = 3, w = 18, -- height (dm), weight (hg)
        cr = 255, bf = 70, be = 50, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.PIDGEOTTO] = {
        id = 17, n = "Bird Pokémon",
        bs = {63, 60, 55, 50, 50, 71}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.TANGLED_FEET, ABILITY.BIG_PECKS}, -- abilities: normal1, normal2, hidden
        h = 11, w = 300, -- height (dm), weight (hg)
        cr = 120, bf = 70, be = 122, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.PIDGEOT] = {
        id = 18, n = "Bird Pokémon",
        bs = {83, 80, 75, 70, 70, 101}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.TANGLED_FEET, ABILITY.BIG_PECKS}, -- abilities: normal1, normal2, hidden
        h = 15, w = 395, -- height (dm), weight (hg)
        cr = 45, bf = 70, be = 240, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.RATTATA] = {
        id = 19, n = "Mouse Pokémon",
        bs = {30, 56, 35, 25, 35, 72}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.RUN_AWAY, ABILITY.GUTS, ABILITY.HUSTLE}, -- abilities: normal1, normal2, hidden
        h = 3, w = 35, -- height (dm), weight (hg)
        cr = 255, bf = 70, be = 51, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.RATICATE] = {
        id = 20, n = "Mouse Pokémon",
        bs = {55, 81, 60, 50, 70, 97}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL}, -- types
        ab = {ABILITY.RUN_AWAY, ABILITY.GUTS, ABILITY.HUSTLE}, -- abilities: normal1, normal2, hidden
        h = 7, w = 185, -- height (dm), weight (hg)
        cr = 127, bf = 70, be = 145, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.SPEAROW] = {
        id = 21, n = "Tiny Bird Pokémon",
        bs = {40, 60, 30, 31, 31, 70}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.NONE, ABILITY.SNIPER}, -- abilities: normal1, normal2, hidden
        h = 3, w = 20, -- height (dm), weight (hg)
        cr = 255, bf = 70, be = 52, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.FEAROW] = {
        id = 22, n = "Beak Pokémon",
        bs = {65, 90, 65, 61, 61, 100}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.KEEN_EYE, ABILITY.NONE, ABILITY.SNIPER}, -- abilities: normal1, normal2, hidden
        h = 12, w = 380, -- height (dm), weight (hg)
        cr = 90, bf = 70, be = 155, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.EKANS] = {
        id = 23, n = "Snake Pokémon",
        bs = {35, 60, 44, 40, 54, 55}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.INTIMIDATE, ABILITY.SHED_SKIN, ABILITY.UNNERVE}, -- abilities: normal1, normal2, hidden
        h = 20, w = 69, -- height (dm), weight (hg)
        cr = 255, bf = 70, be = 58, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.ARBOK] = {
        id = 24, n = "Cobra Pokémon",
        bs = {60, 95, 69, 65, 79, 80}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.INTIMIDATE, ABILITY.SHED_SKIN, ABILITY.UNNERVE}, -- abilities: normal1, normal2, hidden
        h = 35, w = 650, -- height (dm), weight (hg)
        cr = 90, bf = 70, be = 157, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.PIKACHU] = {
        id = 25, n = "Mouse Pokémon",
        bs = {35, 55, 40, 50, 50, 90}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC}, -- types
        ab = {ABILITY.STATIC, ABILITY.NONE, ABILITY.LIGHTNING_ROD}, -- abilities: normal1, normal2, hidden
        h = 4, w = 60, -- height (dm), weight (hg)
        cr = 190, bf = 50, be = 112, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.RAICHU] = {
        id = 26, n = "Mouse Pokémon",
        bs = {60, 90, 55, 90, 80, 110}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.ELECTRIC}, -- types
        ab = {ABILITY.STATIC, ABILITY.NONE, ABILITY.LIGHTNING_ROD}, -- abilities: normal1, normal2, hidden
        h = 8, w = 300, -- height (dm), weight (hg)
        cr = 75, bf = 50, be = 243, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.SANDSHREW] = {
        id = 27, n = "Mouse Pokémon",
        bs = {50, 75, 85, 20, 30, 40}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.SAND_VEIL, ABILITY.NONE, ABILITY.SAND_RUSH}, -- abilities: normal1, normal2, hidden
        h = 6, w = 120, -- height (dm), weight (hg)
        cr = 255, bf = 50, be = 60, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.SANDSLASH] = {
        id = 28, n = "Mouse Pokémon",
        bs = {75, 100, 110, 45, 55, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.SAND_VEIL, ABILITY.NONE, ABILITY.SAND_RUSH}, -- abilities: normal1, normal2, hidden
        h = 10, w = 295, -- height (dm), weight (hg)
        cr = 90, bf = 50, be = 158, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NIDORAN_F] = {
        id = 29, n = "Poison Pin Pokémon",
        bs = {55, 47, 52, 40, 40, 41}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.POISON_POINT, ABILITY.RIVALRY, ABILITY.HUSTLE}, -- abilities: normal1, normal2, hidden
        h = 4, w = 70, -- height (dm), weight (hg)
        cr = 235, bf = 50, be = 55, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NIDORINA] = {
        id = 30, n = "Poison Pin Pokémon",
        bs = {70, 62, 67, 55, 55, 56}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.POISON_POINT, ABILITY.RIVALRY, ABILITY.HUSTLE}, -- abilities: normal1, normal2, hidden
        h = 8, w = 200, -- height (dm), weight (hg)
        cr = 120, bf = 50, be = 128, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NIDOQUEEN] = {
        id = 31, n = "Drill Pokémon",
        bs = {90, 92, 87, 75, 85, 76}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.POISON_POINT, ABILITY.RIVALRY, ABILITY.SHEER_FORCE}, -- abilities: normal1, normal2, hidden
        h = 13, w = 600, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 253, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NIDORAN_M] = {
        id = 32, n = "Poison Pin Pokémon",
        bs = {46, 57, 40, 40, 40, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.POISON_POINT, ABILITY.RIVALRY, ABILITY.HUSTLE}, -- abilities: normal1, normal2, hidden
        h = 5, w = 90, -- height (dm), weight (hg)
        cr = 235, bf = 50, be = 55, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NIDORINO] = {
        id = 33, n = "Poison Pin Pokémon",
        bs = {61, 72, 57, 55, 55, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.POISON_POINT, ABILITY.RIVALRY, ABILITY.HUSTLE}, -- abilities: normal1, normal2, hidden
        h = 9, w = 195, -- height (dm), weight (hg)
        cr = 120, bf = 50, be = 128, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NIDOKING] = {
        id = 34, n = "Drill Pokémon",
        bs = {81, 102, 77, 85, 75, 85}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON, POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.POISON_POINT, ABILITY.RIVALRY, ABILITY.SHEER_FORCE}, -- abilities: normal1, normal2, hidden
        h = 14, w = 620, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 253, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.CLEFAIRY] = {
        id = 35, n = "Fairy Pokémon",
        bs = {70, 45, 48, 60, 65, 35}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.CUTE_CHARM, ABILITY.MAGIC_GUARD, ABILITY.FRIEND_GUARD}, -- abilities: normal1, normal2, hidden
        h = 6, w = 75, -- height (dm), weight (hg)
        cr = 150, bf = 140, be = 113, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.CLEFABLE] = {
        id = 36, n = "Fairy Pokémon",
        bs = {95, 70, 73, 95, 90, 60}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.CUTE_CHARM, ABILITY.MAGIC_GUARD, ABILITY.UNAWARE}, -- abilities: normal1, normal2, hidden
        h = 13, w = 400, -- height (dm), weight (hg)
        cr = 25, bf = 140, be = 242, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.VULPIX] = {
        id = 37, n = "Fox Pokémon",
        bs = {38, 41, 40, 50, 65, 65}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.FLASH_FIRE, ABILITY.NONE, ABILITY.DROUGHT}, -- abilities: normal1, normal2, hidden
        h = 6, w = 99, -- height (dm), weight (hg)
        cr = 190, bf = 50, be = 60, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.NINETALES] = {
        id = 38, n = "Fox Pokémon",
        bs = {73, 76, 75, 81, 100, 100}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.FIRE}, -- types
        ab = {ABILITY.FLASH_FIRE, ABILITY.NONE, ABILITY.DROUGHT}, -- abilities: normal1, normal2, hidden
        h = 11, w = 199, -- height (dm), weight (hg)
        cr = 75, bf = 50, be = 177, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.JIGGLYPUFF] = {
        id = 39, n = "Balloon Pokémon",
        bs = {115, 45, 20, 45, 25, 20}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.CUTE_CHARM, ABILITY.COMPETITIVE, ABILITY.FRIEND_GUARD}, -- abilities: normal1, normal2, hidden
        h = 5, w = 55, -- height (dm), weight (hg)
        cr = 170, bf = 50, be = 95, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.WIGGLYTUFF] = {
        id = 40, n = "Balloon Pokémon",
        bs = {140, 70, 45, 85, 50, 45}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.NORMAL, POKEMON_TYPE.FAIRY}, -- types
        ab = {ABILITY.CUTE_CHARM, ABILITY.COMPETITIVE, ABILITY.FRISK}, -- abilities: normal1, normal2, hidden
        h = 10, w = 120, -- height (dm), weight (hg)
        cr = 50, bf = 50, be = 218, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.ZUBAT] = {
        id = 41, n = "Bat Pokémon",
        bs = {40, 45, 35, 30, 40, 55}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.INNER_FOCUS, ABILITY.NONE, ABILITY.INFILTRATOR}, -- abilities: normal1, normal2, hidden
        h = 8, w = 75, -- height (dm), weight (hg)
        cr = 255, bf = 50, be = 49, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.GOLBAT] = {
        id = 42, n = "Bat Pokémon",
        bs = {75, 80, 70, 65, 75, 90}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.POISON, POKEMON_TYPE.FLYING}, -- types
        ab = {ABILITY.INNER_FOCUS, ABILITY.NONE, ABILITY.INFILTRATOR}, -- abilities: normal1, normal2, hidden
        h = 16, w = 550, -- height (dm), weight (hg)
        cr = 90, bf = 50, be = 159, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.ODDISH] = {
        id = 43, n = "Weed Pokémon",
        bs = {45, 50, 55, 75, 65, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.CHLOROPHYLL, ABILITY.NONE, ABILITY.RUN_AWAY}, -- abilities: normal1, normal2, hidden
        h = 5, w = 54, -- height (dm), weight (hg)
        cr = 255, bf = 50, be = 64, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.GLOOM] = {
        id = 44, n = "Weed Pokémon",
        bs = {60, 65, 70, 85, 75, 40}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.CHLOROPHYLL, ABILITY.NONE, ABILITY.STENCH}, -- abilities: normal1, normal2, hidden
        h = 8, w = 86, -- height (dm), weight (hg)
        cr = 120, bf = 50, be = 138, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.VILEPLUME] = {
        id = 45, n = "Flower Pokémon",
        bs = {75, 80, 85, 110, 90, 50}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.CHLOROPHYLL, ABILITY.NONE, ABILITY.EFFECT_SPORE}, -- abilities: normal1, normal2, hidden
        h = 12, w = 186, -- height (dm), weight (hg)
        cr = 45, bf = 50, be = 245, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.PARAS] = {
        id = 46, n = "Mushroom Pokémon",
        bs = {35, 70, 55, 45, 55, 25}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.EFFECT_SPORE, ABILITY.DRY_SKIN, ABILITY.DAMP}, -- abilities: normal1, normal2, hidden
        h = 3, w = 54, -- height (dm), weight (hg)
        cr = 190, bf = 70, be = 57, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.PARASECT] = {
        id = 47, n = "Mushroom Pokémon",
        bs = {60, 95, 80, 60, 80, 30}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.GRASS}, -- types
        ab = {ABILITY.EFFECT_SPORE, ABILITY.DRY_SKIN, ABILITY.DAMP}, -- abilities: normal1, normal2, hidden
        h = 10, w = 295, -- height (dm), weight (hg)
        cr = 75, bf = 70, be = 142, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.VENONAT] = {
        id = 48, n = "Insect Pokémon",
        bs = {60, 55, 50, 40, 55, 45}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.COMPOUND_EYES, ABILITY.TINTED_LENS, ABILITY.RUN_AWAY}, -- abilities: normal1, normal2, hidden
        h = 10, w = 300, -- height (dm), weight (hg)
        cr = 190, bf = 70, be = 61, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.VENOMOTH] = {
        id = 49, n = "Poison Moth Pokémon",
        bs = {70, 65, 60, 90, 75, 90}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.BUG, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.SHIELD_DUST, ABILITY.TINTED_LENS, ABILITY.WONDER_SKIN}, -- abilities: normal1, normal2, hidden
        h = 15, w = 125, -- height (dm), weight (hg)
        cr = 75, bf = 70, be = 158, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
    [SPECIES.DIGLETT] = {
        id = 50, n = "Mole Pokémon",
        bs = {10, 55, 25, 35, 45, 95}, -- HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GROUND}, -- types
        ab = {ABILITY.SAND_VEIL, ABILITY.ARENA_TRAP, ABILITY.SAND_FORCE}, -- abilities: normal1, normal2, hidden
        h = 2, w = 8, -- height (dm), weight (hg)
        cr = 255, bf = 50, be = 53, -- catch rate, base friendship, base exp
        ec = {}, -- evolution chain (to be populated)
        lm = {} -- level moves (to be populated)
    },
}

return SpeciesDatabase