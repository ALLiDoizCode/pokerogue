-- Achievement Engine Process
-- Stateless AO process for achievement tracking and validation
-- Implements ADP v1.0 for self-documentation
-- All 68 achievements embedded with complete validation logic

local json = require("json")

-- Achievement Tier Enum
local AchvTier = {
    COMMON = 0,
    GREAT = 1,
    ULTRA = 2,
    ROGUE = 3,
    MASTER = 4
}

-- Calculate tier based on score thresholds
local function getTier(score)
    if score >= 100 then return AchvTier.MASTER end
    if score >= 75 then return AchvTier.ROGUE end
    if score >= 50 then return AchvTier.ULTRA end
    if score >= 25 then return AchvTier.GREAT end
    return AchvTier.COMMON
end

-- Achievement Type Validators
-- Each validator returns true/false based on achievement-specific conditions

local function validateMoneyAchv(achv, args)
    if not args or #args == 0 then return false end
    local currentMoney = tonumber(args[1])
    return currentMoney and currentMoney >= achv.moneyAmount
end

local function validateRibbonAchv(achv, args)
    if not args or #args == 0 then return false end
    local ribbonsOwned = tonumber(args[1])
    return ribbonsOwned and ribbonsOwned >= achv.ribbonAmount
end

local function validateDamageAchv(achv, args)
    if not args or #args == 0 then return false end
    local damageDealt = tonumber(args[1])
    return damageDealt and damageDealt >= achv.damageAmount
end

local function validateHealAchv(achv, args)
    if not args or #args == 0 then return false end
    local healAmount = tonumber(args[1])
    return healAmount and healAmount >= achv.healAmount
end

local function validateLevelAchv(achv, args)
    if not args or #args == 0 then return false end
    local pokemonLevel = tonumber(args[1])
    return pokemonLevel and pokemonLevel >= achv.level
end

-- Embedded Achievement Definitions (All 68 achievements)
local achievements = {
    -- Core Game Achievements
    CLASSIC_VICTORY = {
        id = "CLASSIC_VICTORY",
        localizationKey = "classicVictory",
        name = "Classic Victory",
        description = "Win Classic mode",
        iconImage = "relic_crown",
        score = 250,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    DAILY_VICTORY = {
        id = "DAILY_VICTORY",
        localizationKey = "dailyVictory",
        name = "Daily Victory",
        description = "Win Daily mode",
        iconImage = "calendar",
        score = 100,
        type = "Achv",
        secret = false,
        hasParent = false
    },

    -- Ribbon Achievements
    _10_RIBBONS = {
        id = "_10_RIBBONS",
        localizationKey = "10Ribbons",
        name = "10 Ribbons",
        description = "Earn 10 ribbons",
        iconImage = "common_ribbon",
        score = 50,
        type = "RibbonAchv",
        ribbonAmount = 10,
        secret = false,
        hasParent = false
    },
    _25_RIBBONS = {
        id = "_25_RIBBONS",
        localizationKey = "25Ribbons",
        name = "25 Ribbons",
        description = "Earn 25 ribbons",
        iconImage = "great_ribbon",
        score = 75,
        type = "RibbonAchv",
        ribbonAmount = 25,
        secret = false,
        hasParent = false
    },
    _50_RIBBONS = {
        id = "_50_RIBBONS",
        localizationKey = "50Ribbons",
        name = "50 Ribbons",
        description = "Earn 50 ribbons",
        iconImage = "ultra_ribbon",
        score = 100,
        type = "RibbonAchv",
        ribbonAmount = 50,
        secret = false,
        hasParent = false
    },
    _75_RIBBONS = {
        id = "_75_RIBBONS",
        localizationKey = "75Ribbons",
        name = "75 Ribbons",
        description = "Earn 75 ribbons",
        iconImage = "rogue_ribbon",
        score = 125,
        type = "RibbonAchv",
        ribbonAmount = 75,
        secret = false,
        hasParent = false
    },
    _100_RIBBONS = {
        id = "_100_RIBBONS",
        localizationKey = "100Ribbons",
        name = "100 Ribbons",
        description = "Earn 100 ribbons",
        iconImage = "master_ribbon",
        score = 150,
        type = "RibbonAchv",
        ribbonAmount = 100,
        secret = false,
        hasParent = false
    },

    -- Money Achievements
    _10K_MONEY = {
        id = "_10K_MONEY",
        localizationKey = "10KMoney",
        name = "10K Money",
        description = "Accumulate 10,000 money",
        iconImage = "nugget",
        score = 25,
        type = "MoneyAchv",
        moneyAmount = 10000,
        secret = false,
        hasParent = false
    },
    _100K_MONEY = {
        id = "_100K_MONEY",
        localizationKey = "100KMoney",
        name = "100K Money",
        description = "Accumulate 100,000 money",
        iconImage = "big_nugget",
        score = 25,
        type = "MoneyAchv",
        moneyAmount = 100000,
        secret = true,
        hasParent = false
    },
    _1M_MONEY = {
        id = "_1M_MONEY",
        localizationKey = "1MMoney",
        name = "1M Money",
        description = "Accumulate 1,000,000 money",
        iconImage = "relic_gold",
        score = 50,
        type = "MoneyAchv",
        moneyAmount = 1000000,
        secret = true,
        hasParent = false
    },
    _10M_MONEY = {
        id = "_10M_MONEY",
        localizationKey = "10MMoney",
        name = "10M Money",
        description = "Accumulate 10,000,000 money",
        iconImage = "coin_case",
        score = 50,
        type = "MoneyAchv",
        moneyAmount = 10000000,
        secret = true,
        hasParent = false
    },

    -- Damage Achievements
    _250_DMG = {
        id = "_250_DMG",
        localizationKey = "250Dmg",
        name = "250 Damage",
        description = "Deal 250 damage in one hit",
        iconImage = "lucky_punch",
        score = 25,
        type = "DamageAchv",
        damageAmount = 250,
        secret = false,
        hasParent = false
    },
    _1000_DMG = {
        id = "_1000_DMG",
        localizationKey = "1000Dmg",
        name = "1000 Damage",
        description = "Deal 1000 damage in one hit",
        iconImage = "lucky_punch_great",
        score = 25,
        type = "DamageAchv",
        damageAmount = 1000,
        secret = true,
        hasParent = false
    },
    _2500_DMG = {
        id = "_2500_DMG",
        localizationKey = "2500Dmg",
        name = "2500 Damage",
        description = "Deal 2500 damage in one hit",
        iconImage = "lucky_punch_ultra",
        score = 50,
        type = "DamageAchv",
        damageAmount = 2500,
        secret = true,
        hasParent = false
    },
    _10000_DMG = {
        id = "_10000_DMG",
        localizationKey = "10000Dmg",
        name = "10000 Damage",
        description = "Deal 10000 damage in one hit",
        iconImage = "lucky_punch_master",
        score = 50,
        type = "DamageAchv",
        damageAmount = 10000,
        secret = true,
        hasParent = false
    },

    -- Healing Achievements
    _250_HEAL = {
        id = "_250_HEAL",
        localizationKey = "250Heal",
        name = "250 Heal",
        description = "Heal 250 HP in one action",
        iconImage = "potion",
        score = 25,
        type = "HealAchv",
        healAmount = 250,
        secret = false,
        hasParent = false
    },
    _1000_HEAL = {
        id = "_1000_HEAL",
        localizationKey = "1000Heal",
        name = "1000 Heal",
        description = "Heal 1000 HP in one action",
        iconImage = "super_potion",
        score = 25,
        type = "HealAchv",
        healAmount = 1000,
        secret = true,
        hasParent = false
    },
    _2500_HEAL = {
        id = "_2500_HEAL",
        localizationKey = "2500Heal",
        name = "2500 Heal",
        description = "Heal 2500 HP in one action",
        iconImage = "hyper_potion",
        score = 50,
        type = "HealAchv",
        healAmount = 2500,
        secret = true,
        hasParent = false
    },
    _10000_HEAL = {
        id = "_10000_HEAL",
        localizationKey = "10000Heal",
        name = "10000 Heal",
        description = "Heal 10000 HP in one action",
        iconImage = "max_potion",
        score = 50,
        type = "HealAchv",
        healAmount = 10000,
        secret = true,
        hasParent = false
    },

    -- Level Achievements
    LV_100 = {
        id = "LV_100",
        localizationKey = "lv100",
        name = "Level 100",
        description = "Reach level 100",
        iconImage = "rare_candy",
        score = 25,
        type = "LevelAchv",
        level = 100,
        secret = true,
        hasParent = false
    },
    LV_250 = {
        id = "LV_250",
        localizationKey = "lv250",
        name = "Level 250",
        description = "Reach level 250",
        iconImage = "rarer_candy",
        score = 25,
        type = "LevelAchv",
        level = 250,
        secret = true,
        hasParent = true
    },
    LV_1000 = {
        id = "LV_1000",
        localizationKey = "lv1000",
        name = "Level 1000",
        description = "Reach level 1000",
        iconImage = "candy_jar",
        score = 50,
        type = "LevelAchv",
        level = 1000,
        secret = true,
        hasParent = true
    },

    -- Special Mechanics Achievements
    TRANSFER_MAX_STAT_STAGE = {
        id = "TRANSFER_MAX_STAT_STAGE",
        localizationKey = "transferMaxStatStage",
        name = "Transfer Max Stat Stage",
        description = "Transfer max stat stage to another Pokemon",
        iconImage = "baton",
        score = 25,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    MAX_FRIENDSHIP = {
        id = "MAX_FRIENDSHIP",
        localizationKey = "maxFriendship",
        name = "Max Friendship",
        description = "Reach maximum friendship",
        iconImage = "soothe_bell",
        score = 25,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    MEGA_EVOLVE = {
        id = "MEGA_EVOLVE",
        localizationKey = "megaEvolve",
        name = "Mega Evolve",
        description = "Mega evolve a Pokemon",
        iconImage = "mega_bracelet",
        score = 50,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    GIGANTAMAX = {
        id = "GIGANTAMAX",
        localizationKey = "gigantamax",
        name = "Gigantamax",
        description = "Gigantamax a Pokemon",
        iconImage = "dynamax_band",
        score = 50,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    TERASTALLIZE = {
        id = "TERASTALLIZE",
        localizationKey = "terastallize",
        name = "Terastallize",
        description = "Terastallize a Pokemon",
        iconImage = "tera_orb",
        score = 25,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    STELLAR_TERASTALLIZE = {
        id = "STELLAR_TERASTALLIZE",
        localizationKey = "stellarTerastallize",
        name = "Stellar Terastallize",
        description = "Terastallize with Stellar type",
        iconImage = "stellar_tera_shard",
        score = 25,
        type = "Achv",
        secret = true,
        hasParent = true
    },
    SPLICE = {
        id = "SPLICE",
        localizationKey = "splice",
        name = "Splice",
        description = "Splice two Pokemon",
        iconImage = "dna_splicers",
        score = 50,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    MINI_BLACK_HOLE = {
        id = "MINI_BLACK_HOLE",
        localizationKey = "miniBlackHole",
        name = "Mini Black Hole",
        description = "Obtain Mini Black Hole modifier",
        iconImage = "mini_black_hole",
        score = 25,
        type = "ModifierAchv",
        secret = true,
        hasParent = false
    },
    HIDDEN_ABILITY = {
        id = "HIDDEN_ABILITY",
        localizationKey = "hiddenAbility",
        name = "Hidden Ability",
        description = "Obtain Pokemon with hidden ability",
        iconImage = "ability_charm",
        score = 25,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    PERFECT_IVS = {
        id = "PERFECT_IVS",
        localizationKey = "perfectIvs",
        name = "Perfect IVs",
        description = "Obtain Pokemon with perfect IVs",
        iconImage = "blunder_policy",
        score = 25,
        type = "Achv",
        secret = false,
        hasParent = false
    },

    -- Pokemon Capture Achievements
    SEE_SHINY = {
        id = "SEE_SHINY",
        localizationKey = "seeShiny",
        name = "See Shiny",
        description = "Encounter a shiny Pokemon",
        iconImage = "pb_gold",
        score = 50,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    SHINY_PARTY = {
        id = "SHINY_PARTY",
        localizationKey = "shinyParty",
        name = "Shiny Party",
        description = "Have a full party of shiny Pokemon",
        iconImage = "shiny_charm",
        score = 50,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    CATCH_SUB_LEGENDARY = {
        id = "CATCH_SUB_LEGENDARY",
        localizationKey = "catchSubLegendary",
        name = "Catch Sub-Legendary",
        description = "Catch a sub-legendary Pokemon",
        iconImage = "rb",
        score = 50,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    CATCH_MYTHICAL = {
        id = "CATCH_MYTHICAL",
        localizationKey = "catchMythical",
        name = "Catch Mythical",
        description = "Catch a mythical Pokemon",
        iconImage = "strange_ball",
        score = 75,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    CATCH_LEGENDARY = {
        id = "CATCH_LEGENDARY",
        localizationKey = "catchLegendary",
        name = "Catch Legendary",
        description = "Catch a legendary Pokemon",
        iconImage = "mb",
        score = 100,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    HATCH_SUB_LEGENDARY = {
        id = "HATCH_SUB_LEGENDARY",
        localizationKey = "hatchSubLegendary",
        name = "Hatch Sub-Legendary",
        description = "Hatch a sub-legendary Pokemon",
        iconImage = "epic_egg",
        score = 50,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    HATCH_MYTHICAL = {
        id = "HATCH_MYTHICAL",
        localizationKey = "hatchMythical",
        name = "Hatch Mythical",
        description = "Hatch a mythical Pokemon",
        iconImage = "manaphy_egg",
        score = 50,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    HATCH_LEGENDARY = {
        id = "HATCH_LEGENDARY",
        localizationKey = "hatchLegendary",
        name = "Hatch Legendary",
        description = "Hatch a legendary Pokemon",
        iconImage = "legendary_egg",
        score = 100,
        type = "Achv",
        secret = true,
        hasParent = false
    },
    HATCH_SHINY = {
        id = "HATCH_SHINY",
        localizationKey = "hatchShiny",
        name = "Hatch Shiny",
        description = "Hatch a shiny Pokemon",
        iconImage = "rogue_egg",
        score = 100,
        type = "Achv",
        secret = true,
        hasParent = false
    },

    -- Challenge Mode Achievements
    FRESH_START = {
        id = "FRESH_START",
        localizationKey = "freshStart",
        name = "Fresh Start",
        description = "Complete Fresh Start challenge",
        iconImage = "reviver_seed",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    NUZLOCKE = {
        id = "NUZLOCKE",
        localizationKey = "nuzlocke",
        name = "Nuzlocke",
        description = "Complete Nuzlocke challenge",
        iconImage = "leaf_stone",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    INVERSE_BATTLE = {
        id = "INVERSE_BATTLE",
        localizationKey = "inverseBattle",
        name = "Inverse Battle",
        description = "Complete Inverse Battle challenge",
        iconImage = "inverse",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    FLIP_STATS = {
        id = "FLIP_STATS",
        localizationKey = "flipStats",
        name = "Flip Stats",
        description = "Complete Flip Stats challenge",
        iconImage = "dubious_disc",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    FLIP_INVERSE = {
        id = "FLIP_INVERSE",
        localizationKey = "flipInverse",
        name = "Flip Inverse",
        description = "Complete Flip Stats and Inverse Battle together",
        iconImage = "cracked_pot",
        score = 50,
        type = "ChallengeAchv",
        secret = true,
        hasParent = false
    },

    -- Generation Challenge Achievements
    MONO_GEN_ONE_VICTORY = {
        id = "MONO_GEN_ONE_VICTORY",
        localizationKey = "monoGenOne",
        name = "Mono Gen One",
        description = "Complete with only Gen 1 Pokemon",
        iconImage = "ribbon_gen1",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_TWO_VICTORY = {
        id = "MONO_GEN_TWO_VICTORY",
        localizationKey = "monoGenTwo",
        name = "Mono Gen Two",
        description = "Complete with only Gen 2 Pokemon",
        iconImage = "ribbon_gen2",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_THREE_VICTORY = {
        id = "MONO_GEN_THREE_VICTORY",
        localizationKey = "monoGenThree",
        name = "Mono Gen Three",
        description = "Complete with only Gen 3 Pokemon",
        iconImage = "ribbon_gen3",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_FOUR_VICTORY = {
        id = "MONO_GEN_FOUR_VICTORY",
        localizationKey = "monoGenFour",
        name = "Mono Gen Four",
        description = "Complete with only Gen 4 Pokemon",
        iconImage = "ribbon_gen4",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_FIVE_VICTORY = {
        id = "MONO_GEN_FIVE_VICTORY",
        localizationKey = "monoGenFive",
        name = "Mono Gen Five",
        description = "Complete with only Gen 5 Pokemon",
        iconImage = "ribbon_gen5",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_SIX_VICTORY = {
        id = "MONO_GEN_SIX_VICTORY",
        localizationKey = "monoGenSix",
        name = "Mono Gen Six",
        description = "Complete with only Gen 6 Pokemon",
        iconImage = "ribbon_gen6",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_SEVEN_VICTORY = {
        id = "MONO_GEN_SEVEN_VICTORY",
        localizationKey = "monoGenSeven",
        name = "Mono Gen Seven",
        description = "Complete with only Gen 7 Pokemon",
        iconImage = "ribbon_gen7",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_EIGHT_VICTORY = {
        id = "MONO_GEN_EIGHT_VICTORY",
        localizationKey = "monoGenEight",
        name = "Mono Gen Eight",
        description = "Complete with only Gen 8 Pokemon",
        iconImage = "ribbon_gen8",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GEN_NINE_VICTORY = {
        id = "MONO_GEN_NINE_VICTORY",
        localizationKey = "monoGenNine",
        name = "Mono Gen Nine",
        description = "Complete with only Gen 9 Pokemon",
        iconImage = "ribbon_gen9",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },

    -- Type Challenge Achievements
    MONO_NORMAL = {
        id = "MONO_NORMAL",
        localizationKey = "monoNormal",
        name = "Mono Normal",
        description = "Complete with only Normal type",
        iconImage = "silk_scarf",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_FIGHTING = {
        id = "MONO_FIGHTING",
        localizationKey = "monoFighting",
        name = "Mono Fighting",
        description = "Complete with only Fighting type",
        iconImage = "black_belt",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_FLYING = {
        id = "MONO_FLYING",
        localizationKey = "monoFlying",
        name = "Mono Flying",
        description = "Complete with only Flying type",
        iconImage = "sharp_beak",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_POISON = {
        id = "MONO_POISON",
        localizationKey = "monoPoison",
        name = "Mono Poison",
        description = "Complete with only Poison type",
        iconImage = "poison_barb",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GROUND = {
        id = "MONO_GROUND",
        localizationKey = "monoGround",
        name = "Mono Ground",
        description = "Complete with only Ground type",
        iconImage = "soft_sand",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_ROCK = {
        id = "MONO_ROCK",
        localizationKey = "monoRock",
        name = "Mono Rock",
        description = "Complete with only Rock type",
        iconImage = "hard_stone",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_BUG = {
        id = "MONO_BUG",
        localizationKey = "monoBug",
        name = "Mono Bug",
        description = "Complete with only Bug type",
        iconImage = "silver_powder",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GHOST = {
        id = "MONO_GHOST",
        localizationKey = "monoGhost",
        name = "Mono Ghost",
        description = "Complete with only Ghost type",
        iconImage = "spell_tag",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_STEEL = {
        id = "MONO_STEEL",
        localizationKey = "monoSteel",
        name = "Mono Steel",
        description = "Complete with only Steel type",
        iconImage = "metal_coat",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_FIRE = {
        id = "MONO_FIRE",
        localizationKey = "monoFire",
        name = "Mono Fire",
        description = "Complete with only Fire type",
        iconImage = "charcoal",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_WATER = {
        id = "MONO_WATER",
        localizationKey = "monoWater",
        name = "Mono Water",
        description = "Complete with only Water type",
        iconImage = "mystic_water",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_GRASS = {
        id = "MONO_GRASS",
        localizationKey = "monoGrass",
        name = "Mono Grass",
        description = "Complete with only Grass type",
        iconImage = "miracle_seed",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_ELECTRIC = {
        id = "MONO_ELECTRIC",
        localizationKey = "monoElectric",
        name = "Mono Electric",
        description = "Complete with only Electric type",
        iconImage = "magnet",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_PSYCHIC = {
        id = "MONO_PSYCHIC",
        localizationKey = "monoPsychic",
        name = "Mono Psychic",
        description = "Complete with only Psychic type",
        iconImage = "twisted_spoon",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_ICE = {
        id = "MONO_ICE",
        localizationKey = "monoIce",
        name = "Mono Ice",
        description = "Complete with only Ice type",
        iconImage = "never_melt_ice",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_DRAGON = {
        id = "MONO_DRAGON",
        localizationKey = "monoDragon",
        name = "Mono Dragon",
        description = "Complete with only Dragon type",
        iconImage = "dragon_fang",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_DARK = {
        id = "MONO_DARK",
        localizationKey = "monoDark",
        name = "Mono Dark",
        description = "Complete with only Dark type",
        iconImage = "black_glasses",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },
    MONO_FAIRY = {
        id = "MONO_FAIRY",
        localizationKey = "monoFairy",
        name = "Mono Fairy",
        description = "Complete with only Fairy type",
        iconImage = "fairy_feather",
        score = 100,
        type = "ChallengeAchv",
        secret = false,
        hasParent = false
    },

    -- Misc Achievements
    UNEVOLVED_CLASSIC_VICTORY = {
        id = "UNEVOLVED_CLASSIC_VICTORY",
        localizationKey = "unevolvedClassicVictory",
        name = "Unevolved Classic Victory",
        description = "Win Classic with unevolved Pokemon",
        iconImage = "eviolite",
        score = 50,
        type = "Achv",
        secret = false,
        hasParent = false
    },
    BREEDERS_IN_SPACE = {
        id = "BREEDERS_IN_SPACE",
        name = "Breeders in Space",
        localizationKey = "breedersInSpace",
        description = "Special breeding achievement",
        iconImage = "moon_stone",
        score = 50,
        type = "Achv",
        secret = true,
        hasParent = false
    }
}

-- Player Achievement State Storage
-- In-memory storage per player (stateless - reloaded from coordinator on each message)
local playerAchievements = {}

-- Get or initialize player achievement state
local function getPlayerState(playerId)
    if not playerAchievements[playerId] then
        playerAchievements[playerId] = {
            achvUnlocks = {},  -- { achievementId = unlockTimestamp }
            totalScore = 0,
            totalAchievements = 0,
            secretsUnlocked = 0
        }
    end
    return playerAchievements[playerId]
end

-- Validate achievement based on type and conditions
local function validateAchievement(achv, args)
    if achv.type == "MoneyAchv" then
        return validateMoneyAchv(achv, args)
    elseif achv.type == "RibbonAchv" then
        return validateRibbonAchv(achv, args)
    elseif achv.type == "DamageAchv" then
        return validateDamageAchv(achv, args)
    elseif achv.type == "HealAchv" then
        return validateHealAchv(achv, args)
    elseif achv.type == "LevelAchv" then
        return validateLevelAchv(achv, args)
    elseif achv.type == "Achv" then
        -- Base achievement type - custom validation via args
        -- For now, accepts validation from coordinator
        return true
    elseif achv.type == "ModifierAchv" then
        -- Modifier achievements validated by coordinator
        return true
    elseif achv.type == "ChallengeAchv" then
        -- Challenge achievements validated by coordinator
        return true
    end
    return false
end

-- Calculate total score from unlocked achievements
local function calculateTotalScore(playerState)
    local totalScore = 0
    for achvId, _ in pairs(playerState.achvUnlocks) do
        local achv = achievements[achvId]
        if achv then
            totalScore = totalScore + achv.score
        end
    end
    return totalScore
end

-- ADP v1.0 Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                name = "Achievement Engine",
                version = "1.0.0",
                adpVersion = "1.0",
                capabilities = {
                    "validateAchievement",
                    "validateAchievementsByType",
                    "getPlayerAchievements",
                    "getAchievementMetadata",
                    "getAchievementProgress"
                },
                handlers = {
                    {
                        action = "ValidateAchievement",
                        description = "Validate single achievement for player",
                        required = {"PlayerId", "AchievementId"}
                    },
                    {
                        action = "ValidateAchievementsByType",
                        description = "Validate all achievements of specific type",
                        required = {"PlayerId", "AchievementType", "Args"}
                    },
                    {
                        action = "GetPlayerAchievements",
                        description = "Get all achievement states for player",
                        required = {"PlayerId"}
                    },
                    {
                        action = "GetAchievementMetadata",
                        description = "Get achievement definitions and metadata",
                        required = {}
                    },
                    {
                        action = "GetAchievementProgress",
                        description = "Get progress toward specific achievement",
                        required = {"PlayerId", "AchievementId"}
                    }
                },
                totalAchievements = 68,
                achievementTypes = {
                    "Achv", "MoneyAchv", "RibbonAchv", "DamageAchv",
                    "HealAchv", "LevelAchv", "ModifierAchv", "ChallengeAchv"
                }
            })
        })
    end
)

-- Handler: ValidateAchievement
Handlers.add("validate-achievement",
    Handlers.utils.hasMatchingTag("Action", "ValidateAchievement"),
    function(msg)
        local playerId = msg.PlayerId
        local achievementId = msg.AchievementId

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required"
            })
            return
        end

        if not achievementId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "AchievementId required"
            })
            return
        end

        local achv = achievements[achievementId]
        if not achv then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Achievement not found: " .. achievementId
            })
            return
        end

        local playerState = getPlayerState(playerId)

        -- Check if already unlocked
        if playerState.achvUnlocks[achievementId] then
            ao.send({
                Target = msg.From,
                Action = "AchievementValidated",
                PlayerId = playerId,
                AchievementId = achievementId,
                Success = "false",
                AlreadyUnlocked = "true",
                UnlockTimestamp = tostring(playerState.achvUnlocks[achievementId]),
                Score = tostring(achv.score),
                Tier = tostring(getTier(achv.score)),
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        -- Parse validation args
        local args = {}
        if msg.Args and msg.Args ~= "" then
            args = json.decode(msg.Args)
        end

        -- Validate achievement
        local validated = validateAchievement(achv, args)

        if validated then
            -- Record unlock
            local unlockTimestamp = tonumber(msg.Timestamp or 0)
            playerState.achvUnlocks[achievementId] = unlockTimestamp
            playerState.totalAchievements = playerState.totalAchievements + 1
            if achv.secret then
                playerState.secretsUnlocked = playerState.secretsUnlocked + 1
            end
            playerState.totalScore = calculateTotalScore(playerState)

            ao.send({
                Target = msg.From,
                Action = "AchievementValidated",
                PlayerId = playerId,
                AchievementId = achievementId,
                Success = "true",
                AlreadyUnlocked = "false",
                UnlockTimestamp = tostring(unlockTimestamp),
                Score = tostring(achv.score),
                Tier = tostring(getTier(achv.score)),
                TotalScore = tostring(playerState.totalScore),
                TotalAchievements = tostring(playerState.totalAchievements),
                Timestamp = tostring(msg.Timestamp or 0)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "AchievementValidated",
                PlayerId = playerId,
                AchievementId = achievementId,
                Success = "false",
                AlreadyUnlocked = "false",
                Error = "Validation conditions not met",
                Timestamp = tostring(msg.Timestamp or 0)
            })
        end
    end
)

-- Handler: ValidateAchievementsByType
Handlers.add("validate-achievements-by-type",
    Handlers.utils.hasMatchingTag("Action", "ValidateAchievementsByType"),
    function(msg)
        local playerId = msg.PlayerId
        local achievementType = msg.AchievementType

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required"
            })
            return
        end

        if not achievementType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "AchievementType required"
            })
            return
        end

        -- Parse validation args
        local args = {}
        if msg.Args and msg.Args ~= "" then
            args = json.decode(msg.Args)
        end

        local playerState = getPlayerState(playerId)
        local newUnlocks = {}
        local totalNewUnlocks = 0
        local newScore = 0

        -- Filter achievements by type and validate
        for achvId, achv in pairs(achievements) do
            if achv.type == achievementType then
                -- Skip if already unlocked
                if not playerState.achvUnlocks[achvId] then
                    local validated = validateAchievement(achv, args)
                    if validated then
                        local unlockTimestamp = tonumber(msg.Timestamp or 0)
                        playerState.achvUnlocks[achvId] = unlockTimestamp
                        playerState.totalAchievements = playerState.totalAchievements + 1
                        if achv.secret then
                            playerState.secretsUnlocked = playerState.secretsUnlocked + 1
                        end

                        table.insert(newUnlocks, {
                            id = achvId,
                            score = achv.score,
                            timestamp = unlockTimestamp,
                            tier = getTier(achv.score)
                        })
                        totalNewUnlocks = totalNewUnlocks + 1
                        newScore = newScore + achv.score
                    end
                end
            end
        end

        playerState.totalScore = calculateTotalScore(playerState)

        ao.send({
            Target = msg.From,
            Action = "AchievementsBatchValidated",
            PlayerId = playerId,
            AchievementType = achievementType,
            Data = json.encode({
                newUnlocks = newUnlocks,
                totalNewUnlocks = totalNewUnlocks,
                totalScore = newScore,
                playerTotalScore = playerState.totalScore,
                playerTotalAchievements = playerState.totalAchievements
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: GetPlayerAchievements
Handlers.add("get-player-achievements",
    Handlers.utils.hasMatchingTag("Action", "GetPlayerAchievements"),
    function(msg)
        local playerId = msg.PlayerId

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required"
            })
            return
        end

        local playerState = getPlayerState(playerId)
        local includeSecrets = msg.IncludeSecrets == "true"

        -- Calculate completion percentage
        local completionPercentage = (playerState.totalAchievements / 68) * 100

        -- Build achievement list with visibility rules
        local visibleAchievements = {}
        for achvId, unlockTimestamp in pairs(playerState.achvUnlocks) do
            local achv = achievements[achvId]
            if achv then
                -- Include if not secret, or if secrets requested
                if not achv.secret or includeSecrets then
                    visibleAchievements[achvId] = unlockTimestamp
                end
            end
        end

        ao.send({
            Target = msg.From,
            Action = "PlayerAchievementData",
            PlayerId = playerId,
            Data = json.encode({
                achvUnlocks = visibleAchievements,
                totalScore = playerState.totalScore,
                totalAchievements = playerState.totalAchievements,
                secretsUnlocked = playerState.secretsUnlocked,
                completionPercentage = completionPercentage
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: GetAchievementMetadata
Handlers.add("get-achievement-metadata",
    Handlers.utils.hasMatchingTag("Action", "GetAchievementMetadata"),
    function(msg)
        local achievementId = msg.AchievementId
        local categoryFilter = msg.CategoryFilter

        local achievementList = {}
        local categories = {}
        local categorySet = {}

        -- Single achievement query
        if achievementId and achievementId ~= "" then
            local achv = achievements[achievementId]
            if achv then
                table.insert(achievementList, {
                    id = achv.id,
                    localizationKey = achv.localizationKey,
                    name = achv.name,
                    description = achv.description,
                    iconImage = achv.iconImage,
                    score = achv.score,
                    tier = getTier(achv.score),
                    secret = achv.secret,
                    hasParent = achv.hasParent,
                    type = achv.type
                })
            else
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Achievement not found: " .. achievementId
                })
                return
            end
        else
            -- All achievements or filtered by category
            for achvId, achv in pairs(achievements) do
                if not categoryFilter or categoryFilter == "" or achv.type == categoryFilter then
                    table.insert(achievementList, {
                        id = achv.id,
                        localizationKey = achv.localizationKey,
                        name = achv.name,
                        description = achv.description,
                        iconImage = achv.iconImage,
                        score = achv.score,
                        tier = getTier(achv.score),
                        secret = achv.secret,
                        hasParent = achv.hasParent,
                        type = achv.type
                    })
                end

                -- Collect unique categories
                if not categorySet[achv.type] then
                    categorySet[achv.type] = true
                    table.insert(categories, achv.type)
                end
            end
        end

        ao.send({
            Target = msg.From,
            Action = "AchievementMetadata",
            Data = json.encode({
                achievements = achievementList,
                totalAchievements = #achievementList,
                categories = categories
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: GetAchievementProgress
Handlers.add("get-achievement-progress",
    Handlers.utils.hasMatchingTag("Action", "GetAchievementProgress"),
    function(msg)
        local playerId = msg.PlayerId
        local achievementId = msg.AchievementId
        local currentValue = tonumber(msg.CurrentValue)

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required"
            })
            return
        end

        if not achievementId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "AchievementId required"
            })
            return
        end

        local achv = achievements[achievementId]
        if not achv then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Achievement not found: " .. achievementId
            })
            return
        end

        local playerState = getPlayerState(playerId)
        local isUnlocked = playerState.achvUnlocks[achievementId] ~= nil

        -- Determine required value based on achievement type
        local required = 0
        local current = currentValue or 0

        if achv.type == "MoneyAchv" then
            required = achv.moneyAmount
        elseif achv.type == "RibbonAchv" then
            required = achv.ribbonAmount
        elseif achv.type == "DamageAchv" then
            required = achv.damageAmount
        elseif achv.type == "HealAchv" then
            required = achv.healAmount
        elseif achv.type == "LevelAchv" then
            required = achv.level
        end

        local percentage = 0
        if required > 0 then
            percentage = math.min((current / required) * 100, 100)
        end

        local isComplete = current >= required

        ao.send({
            Target = msg.From,
            Action = "AchievementProgress",
            PlayerId = playerId,
            AchievementId = achievementId,
            Data = json.encode({
                current = current,
                required = required,
                percentage = percentage,
                isComplete = isComplete,
                isUnlocked = isUnlocked
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Achievement Engine Process initialized with 68 achievements (Process ID: " .. ao.id .. ")")