-- Biome Trainer Pools Database (Auto-generated)
-- Trainer types available per biome and tier
local biomeTrainerPools = {
    [BiomeId.TOWN] = {
        commonPool = {TrainerType.YOUNGSTER},
    },
    [BiomeId.PLAINS] = {
        commonPool = {TrainerType.BREEDER, TrainerType.TWINS},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.CYCLIST},
        rarePool = {TrainerType.BLACK_BELT},
        bossPool = {TrainerType.CILAN, TrainerType.CHILI, TrainerType.CRESS, TrainerType.CHEREN},
    },
    [BiomeId.GRASS] = {
        commonPool = {TrainerType.BREEDER, TrainerType.SCHOOL_KID},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.POKEFAN},
        rarePool = {TrainerType.BLACK_BELT},
        bossPool = {TrainerType.ERIKA},
    },
    [BiomeId.TALL_GRASS] = {
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.BREEDER, TrainerType.RANGER},
        bossPool = {TrainerType.GARDENIA, TrainerType.VIOLA, TrainerType.BRASSIUS},
    },
    [BiomeId.METROPOLIS] = {
        commonPool = {TrainerType.BEAUTY, TrainerType.CLERK, TrainerType.CYCLIST, TrainerType.OFFICER, TrainerType.WAITER},
        uncommonPool = {TrainerType.BREEDER, TrainerType.DEPOT_AGENT, TrainerType.GUITARIST},
        rarePool = {TrainerType.ARTIST, TrainerType.RICH_KID},
        bossPool = {TrainerType.WHITNEY, TrainerType.NORMAN, TrainerType.IONO, TrainerType.LARRY},
    },
    [BiomeId.FOREST] = {
        commonPool = {TrainerType.RANGER},
        bossPool = {TrainerType.BUGSY, TrainerType.BURGH, TrainerType.KATY},
    },
    [BiomeId.SEA] = {
        commonPool = {TrainerType.SAILOR, TrainerType.SWIMMER},
        bossPool = {TrainerType.MARLON},
    },
    [BiomeId.SWAMP] = {
        commonPool = {TrainerType.PARASOL_LADY},
        uncommonPool = {TrainerType.ACE_TRAINER},
        rarePool = {TrainerType.BLACK_BELT},
        bossPool = {TrainerType.JANINE, TrainerType.ROXIE},
    },
    [BiomeId.BEACH] = {
        commonPool = {TrainerType.FISHERMAN, TrainerType.SAILOR},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.BREEDER},
        rarePool = {TrainerType.BLACK_BELT},
        bossPool = {TrainerType.MISTY, TrainerType.KOFU},
    },
    [BiomeId.LAKE] = {
        commonPool = {TrainerType.BREEDER, TrainerType.FISHERMAN, TrainerType.PARASOL_LADY},
        uncommonPool = {TrainerType.ACE_TRAINER},
        rarePool = {TrainerType.BLACK_BELT},
        bossPool = {TrainerType.CRASHER_WAKE},
    },
    [BiomeId.SEABED] = {
        commonPool = {TrainerType.SWIMMER},
        bossPool = {TrainerType.JUAN},
    },
    [BiomeId.MOUNTAIN] = {
        commonPool = {TrainerType.BACKPACKER, TrainerType.BLACK_BELT, TrainerType.HIKER},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.PILOT},
        bossPool = {TrainerType.FALKNER, TrainerType.WINONA, TrainerType.SKYLA},
    },
    [BiomeId.BADLANDS] = {
        commonPool = {TrainerType.BACKPACKER, TrainerType.HIKER},
        uncommonPool = {TrainerType.ACE_TRAINER},
        bossPool = {TrainerType.CLAY, TrainerType.GRANT},
    },
    [BiomeId.CAVE] = {
        commonPool = {TrainerType.BACKPACKER, TrainerType.HIKER},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.BLACK_BELT},
        bossPool = {TrainerType.BROCK, TrainerType.ROXANNE, TrainerType.ROARK},
    },
    [BiomeId.DESERT] = {
        commonPool = {TrainerType.BACKPACKER, TrainerType.SCIENTIST},
        bossPool = {TrainerType.GORDIE},
    },
    [BiomeId.ICE_CAVE] = {
        commonPool = {TrainerType.SNOW_WORKER},
        bossPool = {TrainerType.PRYCE, TrainerType.BRYCEN, TrainerType.WULFRIC, TrainerType.GRUSHA},
    },
    [BiomeId.MEADOW] = {
        commonPool = {TrainerType.BEAUTY, TrainerType.MUSICIAN, TrainerType.PARASOL_LADY},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.BAKER, TrainerType.BREEDER, TrainerType.POKEFAN},
        bossPool = {TrainerType.LENORA, TrainerType.MILO},
    },
    [BiomeId.POWER_PLANT] = {
        commonPool = {TrainerType.GUITARIST, TrainerType.WORKER},
        bossPool = {TrainerType.VOLKNER, TrainerType.ELESA, TrainerType.CLEMONT},
    },
    [BiomeId.VOLCANO] = {
        commonPool = {TrainerType.FIREBREATHER},
        bossPool = {TrainerType.BLAINE, TrainerType.FLANNERY, TrainerType.KABU},
    },
    [BiomeId.GRAVEYARD] = {
        commonPool = {TrainerType.PSYCHIC},
        uncommonPool = {TrainerType.HEX_MANIAC},
        bossPool = {TrainerType.MORTY, TrainerType.ALLISTER, TrainerType.RYME},
    },
    [BiomeId.DOJO] = {
        commonPool = {TrainerType.BLACK_BELT},
        bossPool = {TrainerType.BRAWLY, TrainerType.MAYLENE, TrainerType.KORRINA, TrainerType.BEA},
    },
    [BiomeId.FACTORY] = {
        commonPool = {TrainerType.WORKER},
        bossPool = {TrainerType.JASMINE, TrainerType.BYRON},
    },
    [BiomeId.RUINS] = {
        commonPool = {TrainerType.PSYCHIC, TrainerType.SCIENTIST},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.BLACK_BELT, TrainerType.HEX_MANIAC},
        bossPool = {TrainerType.SABRINA, TrainerType.TATE, TrainerType.LIZA, TrainerType.TULIP},
    },
    [BiomeId.WASTELAND] = {
        commonPool = {TrainerType.VETERAN},
        bossPool = {TrainerType.CLAIR, TrainerType.DRAYDEN, TrainerType.RAIHAN},
    },
    [BiomeId.ABYSS] = {
        uncommonPool = {TrainerType.ACE_TRAINER},
        bossPool = {TrainerType.MARNIE},
    },
    [BiomeId.SPACE] = {
        bossPool = {TrainerType.OLYMPIA},
    },
    [BiomeId.CONSTRUCTION_SITE] = {
        commonPool = {TrainerType.OFFICER, TrainerType.WORKER},
        bossPool = {TrainerType.LT_SURGE, TrainerType.CHUCK, TrainerType.WATTSON},
    },
    [BiomeId.JUNGLE] = {
        commonPool = {TrainerType.BACKPACKER, TrainerType.RANGER},
        bossPool = {TrainerType.RAMOS},
    },
    [BiomeId.FAIRY_CAVE] = {
        commonPool = {TrainerType.BEAUTY},
        uncommonPool = {TrainerType.ACE_TRAINER, TrainerType.BREEDER},
        bossPool = {TrainerType.VALERIE, TrainerType.OPAL, TrainerType.BEDE},
    },
    [BiomeId.TEMPLE] = {
        uncommonPool = {TrainerType.ACE_TRAINER},
        bossPool = {TrainerType.FANTINA},
    },
    [BiomeId.SLUM] = {
        commonPool = {TrainerType.BIKER, TrainerType.OFFICER, TrainerType.ROUGHNECK},
        uncommonPool = {TrainerType.BAKER, TrainerType.HOOLIGANS},
        bossPool = {TrainerType.PIERS},
    },
    [BiomeId.SNOWY_FOREST] = {
        commonPool = {TrainerType.SNOW_WORKER},
        bossPool = {TrainerType.CANDICE, TrainerType.MELONY},
    },
    [BiomeId.ISLAND] = {
        commonPool = {TrainerType.RICH_KID},
        uncommonPool = {TrainerType.RICH},
        bossPool = {TrainerType.NESSA},
    },
    [BiomeId.LABORATORY] = {
        commonPool = {TrainerType.SCIENTIST},
        bossPool = {TrainerType.GIOVANNI},
    },
    [BiomeId.END] = {
    },
}

