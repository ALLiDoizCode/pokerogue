--[[
  Egg Tier Reward Engine

  Stateless AO process for egg tier determination, species selection, and reward calculation.
  Implements tier-based progression system with pity mechanics and weighted species distribution.

  Core Features:
  - Tier rolling with threshold-based determination (COMMON, RARE, EPIC, LEGENDARY)
  - Species selection with starter cost weighting (1x-2x multiplier)
  - Pity system for guaranteed tier pulls (RARE=9, EPIC=59, LEGENDARY=412)
  - Unlock pity for guaranteed new species (9 pulls)
  - Tier bonus calculation for egg moves and hatch waves

  ADP v1.0 Compliant: Self-documenting with Info handler

  Handlers:
  - Info: Process capabilities and self-documentation
  - RollEggTier: Determine egg tier using threshold comparison
  - GetSpeciesByTier: Get filtered species pool for a tier
  - RollSpecies: Select species with weighted random selection
  - GetTierInfo: Get tier metadata and configuration
  - ValidateTierProgression: Validate pity counters and progression
  - GetEggMoveIndex: Calculate egg move slot with tier-specific rates
]]

local json = require("json")

-- ============================================================================
-- EGG TIER CONSTANTS
-- ============================================================================

local EggTier = {
  COMMON = 0,
  RARE = 1,
  EPIC = 2,
  LEGENDARY = 3
}

-- Tier threshold constants for gacha pulls (0-255 range)
local GACHA_DEFAULT_COMMON_EGG_THRESHOLD = 52  -- 204/256 chance (79.7%)
local GACHA_DEFAULT_RARE_EGG_THRESHOLD = 8     -- 44/256 chance (17.2%)
local GACHA_DEFAULT_EPIC_EGG_THRESHOLD = 1     -- 7/256 chance (2.7%)
-- LEGENDARY = remainder                        -- 1/256 chance (0.4%)

-- Legendary Up Gacha modifier: +1 to all thresholds
local GACHA_LEGENDARY_UP_THRESHOLD_OFFSET = 1

-- Hatch wave requirements by tier
local HATCH_WAVES = {
  [EggTier.COMMON] = 10,
  [EggTier.RARE] = 25,
  [EggTier.EPIC] = 50,
  [EggTier.LEGENDARY] = 100
}
local HATCH_WAVES_MANAPHY_EGG = 50

-- Pity thresholds: force tier after X pulls without that tier
local EGG_PITY_RARE_THRESHOLD = 9
local EGG_PITY_EPIC_THRESHOLD = 59
local EGG_PITY_LEGENDARY_THRESHOLD = 412

-- Unlock pity: force locked species after X pulls
local UNLOCK_PITY_THRESHOLD = 9

-- Egg move rates: 1/x chance for rare move (slot 3), else common move (0-2)
local RARE_EGGMOVE_RATES = {
  [EggTier.COMMON] = 48,
  [EggTier.RARE] = 24,
  [EggTier.EPIC] = 12,
  [EggTier.LEGENDARY] = 6
}

-- Boosted rates for GACHA_MOVE source and candy
local BOOSTED_RARE_EGGMOVE_RATES = {
  [EggTier.COMMON] = 16,
  [EggTier.RARE] = 12,
  [EggTier.EPIC] = 6,
  [EggTier.LEGENDARY] = 3
}

-- Special species IDs
local SPECIES_ID_PHIONE = 253
local SPECIES_ID_MANAPHY = 254
local SPECIES_ID_ETERNATUS = 483

-- Starter cost ranges by tier
local TIER_COST_RANGES = {
  [EggTier.COMMON] = {min = 1, max = 3},
  [EggTier.RARE] = {min = 4, max = 5},
  [EggTier.EPIC] = {min = 6, max = 7},
  [EggTier.LEGENDARY] = {min = 8, max = 9}
}

-- ============================================================================
-- SPECIES DATA TABLES (EMBEDDED)
-- ============================================================================

--[[
  Species Egg Tiers: Maps SpeciesId to EggTier
  Total: 569 species from BULBASAUR (1) to BLOODMOON_URSALUNA (8901)
  Auto-generated from TypeScript source files
]]
local speciesEggTiers = {
  [1] = EggTier.COMMON,  -- BULBASAUR
  [4] = EggTier.COMMON,  -- CHARMANDER
  [7] = EggTier.COMMON,  -- SQUIRTLE
  [10] = EggTier.COMMON,  -- CATERPIE
  [13] = EggTier.COMMON,  -- WEEDLE
  [16] = EggTier.COMMON,  -- PIDGEY
  [19] = EggTier.COMMON,  -- RATTATA
  [21] = EggTier.COMMON,  -- SPEAROW
  [23] = EggTier.COMMON,  -- EKANS
  [27] = EggTier.COMMON,  -- SANDSHREW
  [29] = EggTier.COMMON,  -- NIDORAN_F
  [32] = EggTier.COMMON,  -- NIDORAN_M
  [37] = EggTier.COMMON,  -- VULPIX
  [41] = EggTier.COMMON,  -- ZUBAT
  [43] = EggTier.COMMON,  -- ODDISH
  [46] = EggTier.COMMON,  -- PARAS
  [48] = EggTier.COMMON,  -- VENONAT
  [50] = EggTier.COMMON,  -- DIGLETT
  [52] = EggTier.COMMON,  -- MEOWTH
  [54] = EggTier.COMMON,  -- PSYDUCK
  [56] = EggTier.RARE,  -- MANKEY
  [58] = EggTier.RARE,  -- GROWLITHE
  [60] = EggTier.COMMON,  -- POLIWAG
  [63] = EggTier.RARE,  -- ABRA
  [66] = EggTier.COMMON,  -- MACHOP
  [69] = EggTier.COMMON,  -- BELLSPROUT
  [72] = EggTier.COMMON,  -- TENTACOOL
  [74] = EggTier.COMMON,  -- GEODUDE
  [77] = EggTier.COMMON,  -- PONYTA
  [79] = EggTier.COMMON,  -- SLOWPOKE
  [81] = EggTier.COMMON,  -- MAGNEMITE
  [83] = EggTier.COMMON,  -- FARFETCHD
  [84] = EggTier.COMMON,  -- DODUO
  [86] = EggTier.COMMON,  -- SEEL
  [88] = EggTier.RARE,  -- GRIMER
  [90] = EggTier.COMMON,  -- SHELLDER
  [92] = EggTier.RARE,  -- GASTLY
  [95] = EggTier.RARE,  -- ONIX
  [96] = EggTier.COMMON,  -- DROWZEE
  [98] = EggTier.COMMON,  -- KRABBY
  [100] = EggTier.COMMON,  -- VOLTORB
  [102] = EggTier.COMMON,  -- EXEGGCUTE
  [104] = EggTier.COMMON,  -- CUBONE
  [106] = EggTier.RARE,  -- HITMONLEE
  [107] = EggTier.RARE,  -- HITMONCHAN
  [108] = EggTier.RARE,  -- LICKITUNG
  [109] = EggTier.COMMON,  -- KOFFING
  [111] = EggTier.COMMON,  -- RHYHORN
  [113] = EggTier.RARE,  -- CHANSEY
  [114] = EggTier.COMMON,  -- TANGELA
  [115] = EggTier.RARE,  -- KANGASKHAN
  [116] = EggTier.COMMON,  -- HORSEA
  [118] = EggTier.COMMON,  -- GOLDEEN
  [120] = EggTier.COMMON,  -- STARYU
  [122] = EggTier.RARE,  -- MR_MIME
  [123] = EggTier.RARE,  -- SCYTHER
  [124] = EggTier.RARE,  -- JYNX
  [125] = EggTier.RARE,  -- ELECTABUZZ
  [126] = EggTier.RARE,  -- MAGMAR
  [127] = EggTier.RARE,  -- PINSIR
  [128] = EggTier.RARE,  -- TAUROS
  [129] = EggTier.COMMON,  -- MAGIKARP
  [131] = EggTier.RARE,  -- LAPRAS
  [132] = EggTier.COMMON,  -- DITTO
  [133] = EggTier.COMMON,  -- EEVEE
  [137] = EggTier.COMMON,  -- PORYGON
  [138] = EggTier.RARE,  -- OMANYTE
  [140] = EggTier.RARE,  -- KABUTO
  [142] = EggTier.RARE,  -- AERODACTYL
  [143] = EggTier.RARE,  -- SNORLAX
  [144] = EggTier.LEGENDARY,  -- ARTICUNO
  [145] = EggTier.LEGENDARY,  -- ZAPDOS
  [146] = EggTier.LEGENDARY,  -- MOLTRES
  [147] = EggTier.COMMON,  -- DRATINI
  [150] = EggTier.LEGENDARY,  -- MEWTWO
  [151] = EggTier.EPIC,  -- MEW
  [152] = EggTier.COMMON,  -- CHIKORITA
  [155] = EggTier.COMMON,  -- CYNDAQUIL
  [158] = EggTier.COMMON,  -- TOTODILE
  [161] = EggTier.COMMON,  -- SENTRET
  [163] = EggTier.COMMON,  -- HOOTHOOT
  [165] = EggTier.COMMON,  -- LEDYBA
  [167] = EggTier.COMMON,  -- SPINARAK
  [170] = EggTier.COMMON,  -- CHINCHOU
  [172] = EggTier.COMMON,  -- PICHU
  [173] = EggTier.COMMON,  -- CLEFFA
  [174] = EggTier.COMMON,  -- IGGLYBUFF
  [175] = EggTier.COMMON,  -- TOGEPI
  [177] = EggTier.RARE,  -- NATU
  [179] = EggTier.COMMON,  -- MAREEP
  [183] = EggTier.COMMON,  -- MARILL
  [185] = EggTier.RARE,  -- SUDOWOODO
  [187] = EggTier.COMMON,  -- HOPPIP
  [190] = EggTier.COMMON,  -- AIPOM
  [191] = EggTier.COMMON,  -- SUNKERN
  [193] = EggTier.COMMON,  -- YANMA
  [194] = EggTier.COMMON,  -- WOOPER
  [198] = EggTier.COMMON,  -- MURKROW
  [200] = EggTier.COMMON,  -- MISDREAVUS
  [202] = EggTier.RARE,  -- WOBBUFFET
  [203] = EggTier.RARE,  -- GIRAFARIG
  [204] = EggTier.COMMON,  -- PINECO
  [206] = EggTier.RARE,  -- DUNSPARCE
  [207] = EggTier.COMMON,  -- GLIGAR
  [209] = EggTier.COMMON,  -- SNUBBULL
  [211] = EggTier.COMMON,  -- QWILFISH
  [213] = EggTier.RARE,  -- SHUCKLE
  [214] = EggTier.RARE,  -- HERACROSS
  [215] = EggTier.COMMON,  -- SNEASEL
  [216] = EggTier.COMMON,  -- TEDDIURSA
  [217] = EggTier.RARE,  -- URSARING
  [218] = EggTier.COMMON,  -- SLUGMA
  [220] = EggTier.COMMON,  -- SWINUB
  [222] = EggTier.RARE,  -- CORSOLA
  [223] = EggTier.COMMON,  -- REMORAID
  [225] = EggTier.RARE,  -- DELIBIRD
  [226] = EggTier.RARE,  -- MANTINE
  [227] = EggTier.RARE,  -- SKARMORY
  [228] = EggTier.COMMON,  -- HOUNDOUR
  [231] = EggTier.RARE,  -- PHANPY
  [234] = EggTier.RARE,  -- STANTLER
  [235] = EggTier.COMMON,  -- SMEARGLE
  [236] = EggTier.RARE,  -- TYROGUE
  [238] = EggTier.RARE,  -- SMOOCHUM
  [239] = EggTier.RARE,  -- ELEKID
  [240] = EggTier.RARE,  -- MAGBY
  [241] = EggTier.RARE,  -- MILTANK
  [243] = EggTier.LEGENDARY,  -- RAIKOU
  [244] = EggTier.LEGENDARY,  -- ENTEI
  [245] = EggTier.LEGENDARY,  -- SUICUNE
  [246] = EggTier.COMMON,  -- LARVITAR
  [249] = EggTier.LEGENDARY,  -- LUGIA
  [250] = EggTier.LEGENDARY,  -- HO_OH
  [251] = EggTier.EPIC,  -- CELEBI
  [252] = EggTier.COMMON,  -- TREECKO
  [255] = EggTier.COMMON,  -- TORCHIC
  [258] = EggTier.COMMON,  -- MUDKIP
  [261] = EggTier.COMMON,  -- POOCHYENA
  [263] = EggTier.COMMON,  -- ZIGZAGOON
  [265] = EggTier.COMMON,  -- WURMPLE
  [270] = EggTier.COMMON,  -- LOTAD
  [273] = EggTier.COMMON,  -- SEEDOT
  [276] = EggTier.COMMON,  -- TAILLOW
  [278] = EggTier.COMMON,  -- WINGULL
  [280] = EggTier.RARE,  -- RALTS
  [283] = EggTier.COMMON,  -- SURSKIT
  [285] = EggTier.RARE,  -- SHROOMISH
  [287] = EggTier.COMMON,  -- SLAKOTH
  [290] = EggTier.RARE,  -- NINCADA
  [293] = EggTier.COMMON,  -- WHISMUR
  [296] = EggTier.COMMON,  -- MAKUHITA
  [298] = EggTier.COMMON,  -- AZURILL
  [299] = EggTier.COMMON,  -- NOSEPASS
  [300] = EggTier.COMMON,  -- SKITTY
  [302] = EggTier.RARE,  -- SABLEYE
  [303] = EggTier.RARE,  -- MAWILE
  [304] = EggTier.COMMON,  -- ARON
  [307] = EggTier.RARE,  -- MEDITITE
  [309] = EggTier.COMMON,  -- ELECTRIKE
  [311] = EggTier.RARE,  -- PLUSLE
  [312] = EggTier.RARE,  -- MINUN
  [313] = EggTier.RARE,  -- VOLBEAT
  [314] = EggTier.RARE,  -- ILLUMISE
  [315] = EggTier.RARE,  -- ROSELIA
  [316] = EggTier.COMMON,  -- GULPIN
  [318] = EggTier.RARE,  -- CARVANHA
  [320] = EggTier.RARE,  -- WAILMER
  [322] = EggTier.COMMON,  -- NUMEL
  [324] = EggTier.RARE,  -- TORKOAL
  [325] = EggTier.COMMON,  -- SPOINK
  [327] = EggTier.RARE,  -- SPINDA
  [328] = EggTier.COMMON,  -- TRAPINCH
  [331] = EggTier.RARE,  -- CACNEA
  [333] = EggTier.COMMON,  -- SWABLU
  [335] = EggTier.RARE,  -- ZANGOOSE
  [336] = EggTier.RARE,  -- SEVIPER
  [337] = EggTier.RARE,  -- LUNATONE
  [338] = EggTier.RARE,  -- SOLROCK
  [339] = EggTier.COMMON,  -- BARBOACH
  [341] = EggTier.COMMON,  -- CORPHISH
  [343] = EggTier.RARE,  -- BALTOY
  [345] = EggTier.RARE,  -- LILEEP
  [347] = EggTier.RARE,  -- ANORITH
  [349] = EggTier.COMMON,  -- FEEBAS
  [351] = EggTier.RARE,  -- CASTFORM
  [352] = EggTier.RARE,  -- KECLEON
  [353] = EggTier.COMMON,  -- SHUPPET
  [355] = EggTier.COMMON,  -- DUSKULL
  [357] = EggTier.RARE,  -- TROPIUS
  [358] = EggTier.RARE,  -- CHIMECHO
  [359] = EggTier.RARE,  -- ABSOL
  [360] = EggTier.COMMON,  -- WYNAUT
  [361] = EggTier.COMMON,  -- SNORUNT
  [363] = EggTier.COMMON,  -- SPHEAL
  [366] = EggTier.RARE,  -- CLAMPERL
  [369] = EggTier.RARE,  -- RELICANTH
  [370] = EggTier.RARE,  -- LUVDISC
  [371] = EggTier.COMMON,  -- BAGON
  [374] = EggTier.RARE,  -- BELDUM
  [377] = EggTier.LEGENDARY,  -- REGIROCK
  [378] = EggTier.LEGENDARY,  -- REGICE
  [379] = EggTier.LEGENDARY,  -- REGISTEEL
  [380] = EggTier.LEGENDARY,  -- LATIAS
  [381] = EggTier.LEGENDARY,  -- LATIOS
  [382] = EggTier.LEGENDARY,  -- KYOGRE
  [383] = EggTier.LEGENDARY,  -- GROUDON
  [384] = EggTier.LEGENDARY,  -- RAYQUAZA
  [385] = EggTier.EPIC,  -- JIRACHI
  [386] = EggTier.LEGENDARY,  -- DEOXYS
  [387] = EggTier.COMMON,  -- TURTWIG
  [390] = EggTier.COMMON,  -- CHIMCHAR
  [393] = EggTier.COMMON,  -- PIPLUP
  [396] = EggTier.COMMON,  -- STARLY
  [399] = EggTier.COMMON,  -- BIDOOF
  [401] = EggTier.COMMON,  -- KRICKETOT
  [403] = EggTier.COMMON,  -- SHINX
  [406] = EggTier.RARE,  -- BUDEW
  [408] = EggTier.RARE,  -- CRANIDOS
  [410] = EggTier.RARE,  -- SHIELDON
  [412] = EggTier.COMMON,  -- BURMY
  [415] = EggTier.COMMON,  -- COMBEE
  [417] = EggTier.RARE,  -- PACHIRISU
  [418] = EggTier.COMMON,  -- BUIZEL
  [420] = EggTier.RARE,  -- CHERUBI
  [422] = EggTier.COMMON,  -- SHELLOS
  [425] = EggTier.COMMON,  -- DRIFLOON
  [427] = EggTier.RARE,  -- BUNEARY
  [429] = EggTier.RARE,  -- MISMAGIUS
  [431] = EggTier.COMMON,  -- GLAMEOW
  [433] = EggTier.RARE,  -- CHINGLING
  [434] = EggTier.COMMON,  -- STUNKY
  [436] = EggTier.RARE,  -- BRONZOR
  [438] = EggTier.RARE,  -- BONSLY
  [439] = EggTier.RARE,  -- MIME_JR
  [440] = EggTier.RARE,  -- HAPPINY
  [441] = EggTier.RARE,  -- CHATOT
  [442] = EggTier.RARE,  -- SPIRITOMB
  [443] = EggTier.COMMON,  -- GIBLE
  [446] = EggTier.RARE,  -- MUNCHLAX
  [447] = EggTier.COMMON,  -- RIOLU
  [449] = EggTier.RARE,  -- HIPPOPOTAS
  [451] = EggTier.COMMON,  -- SKORUPI
  [453] = EggTier.RARE,  -- CROAGUNK
  [455] = EggTier.RARE,  -- CARNIVINE
  [456] = EggTier.RARE,  -- FINNEON
  [458] = EggTier.RARE,  -- MANTYKE
  [459] = EggTier.COMMON,  -- SNOVER
  [462] = EggTier.RARE,  -- MAGNEZONE
  [463] = EggTier.RARE,  -- LICKILICKY
  [464] = EggTier.RARE,  -- RHYPERIOR
  [465] = EggTier.RARE,  -- TANGROWTH
  [466] = EggTier.RARE,  -- ELECTIVIRE
  [467] = EggTier.RARE,  -- MAGMORTAR
  [468] = EggTier.RARE,  -- TOGEKISS
  [469] = EggTier.RARE,  -- YANMEGA
  [470] = EggTier.RARE,  -- LEAFEON
  [471] = EggTier.RARE,  -- GLACEON
  [472] = EggTier.RARE,  -- GLISCOR
  [473] = EggTier.RARE,  -- MAMOSWINE
  [474] = EggTier.RARE,  -- PORYGON_Z
  [475] = EggTier.RARE,  -- GALLADE
  [476] = EggTier.RARE,  -- PROBOPASS
  [477] = EggTier.RARE,  -- DUSKNOIR
  [478] = EggTier.RARE,  -- FROSLASS
  [479] = EggTier.EPIC,  -- ROTOM
  [480] = EggTier.LEGENDARY,  -- UXIE
  [481] = EggTier.LEGENDARY,  -- MESPRIT
  [482] = EggTier.LEGENDARY,  -- AZELF
  [483] = EggTier.LEGENDARY,  -- DIALGA
  [484] = EggTier.LEGENDARY,  -- PALKIA
  [485] = EggTier.LEGENDARY,  -- HEATRAN
  [486] = EggTier.LEGENDARY,  -- REGIGIGAS
  [487] = EggTier.LEGENDARY,  -- GIRATINA
  [488] = EggTier.LEGENDARY,  -- CRESSELIA
  [490] = EggTier.EPIC,  -- MANAPHY
  [491] = EggTier.LEGENDARY,  -- DARKRAI
  [492] = EggTier.EPIC,  -- SHAYMIN
  [493] = EggTier.LEGENDARY,  -- ARCEUS
  [494] = EggTier.EPIC,  -- VICTINI
  [495] = EggTier.COMMON,  -- SNIVY
  [498] = EggTier.COMMON,  -- TEPIG
  [501] = EggTier.COMMON,  -- OSHAWOTT
  [504] = EggTier.COMMON,  -- PATRAT
  [506] = EggTier.COMMON,  -- LILLIPUP
  [509] = EggTier.COMMON,  -- PURRLOIN
  [511] = EggTier.COMMON,  -- PANSAGE
  [513] = EggTier.COMMON,  -- PANSEAR
  [515] = EggTier.COMMON,  -- PANPOUR
  [517] = EggTier.COMMON,  -- MUNNA
  [519] = EggTier.COMMON,  -- PIDOVE
  [522] = EggTier.RARE,  -- BLITZLE
  [524] = EggTier.RARE,  -- ROGGENROLA
  [527] = EggTier.COMMON,  -- WOOBAT
  [529] = EggTier.COMMON,  -- DRILBUR
  [531] = EggTier.RARE,  -- AUDINO
  [532] = EggTier.COMMON,  -- TIMBURR
  [535] = EggTier.COMMON,  -- TYMPOLE
  [538] = EggTier.RARE,  -- THROH
  [539] = EggTier.RARE,  -- SAWK
  [540] = EggTier.COMMON,  -- SEWADDLE
  [543] = EggTier.COMMON,  -- VENIPEDE
  [546] = EggTier.RARE,  -- COTTONEE
  [548] = EggTier.RARE,  -- PETILIL
  [550] = EggTier.RARE,  -- BASCULIN
  [551] = EggTier.COMMON,  -- SANDILE
  [554] = EggTier.RARE,  -- DARUMAKA
  [556] = EggTier.RARE,  -- MARACTUS
  [557] = EggTier.COMMON,  -- DWEBBLE
  [559] = EggTier.COMMON,  -- SCRAGGY
  [561] = EggTier.RARE,  -- SIGILYPH
  [562] = EggTier.RARE,  -- YAMASK
  [564] = EggTier.RARE,  -- TIRTOUGA
  [566] = EggTier.RARE,  -- ARCHEN
  [568] = EggTier.RARE,  -- TRUBBISH
  [570] = EggTier.RARE,  -- ZORUA
  [572] = EggTier.COMMON,  -- MINCCINO
  [574] = EggTier.RARE,  -- GOTHITA
  [577] = EggTier.RARE,  -- SOLOSIS
  [580] = EggTier.COMMON,  -- DUCKLETT
  [582] = EggTier.COMMON,  -- VANILLITE
  [585] = EggTier.RARE,  -- DEERLING
  [587] = EggTier.RARE,  -- EMOLGA
  [588] = EggTier.RARE,  -- KARRABLAST
  [590] = EggTier.RARE,  -- FOONGUS
  [592] = EggTier.RARE,  -- FRILLISH
  [594] = EggTier.RARE,  -- ALOMOMOLA
  [595] = EggTier.COMMON,  -- JOLTIK
  [597] = EggTier.COMMON,  -- FERROSEED
  [599] = EggTier.RARE,  -- KLINK
  [602] = EggTier.RARE,  -- TYNAMO
  [605] = EggTier.RARE,  -- ELGYEM
  [607] = EggTier.RARE,  -- LITWICK
  [610] = EggTier.COMMON,  -- AXEW
  [613] = EggTier.RARE,  -- CUBCHOO
  [615] = EggTier.RARE,  -- CRYOGONAL
  [616] = EggTier.RARE,  -- SHELMET
  [618] = EggTier.RARE,  -- STUNFISK
  [619] = EggTier.RARE,  -- MIENFOO
  [621] = EggTier.EPIC,  -- DRUDDIGON
  [622] = EggTier.RARE,  -- GOLETT
  [624] = EggTier.COMMON,  -- PAWNIARD
  [626] = EggTier.RARE,  -- BOUFFALANT
  [627] = EggTier.RARE,  -- RUFFLET
  [629] = EggTier.RARE,  -- VULLABY
  [631] = EggTier.RARE,  -- HEATMOR
  [632] = EggTier.RARE,  -- DURANT
  [633] = EggTier.COMMON,  -- DEINO
  [636] = EggTier.RARE,  -- LARVESTA
  [638] = EggTier.LEGENDARY,  -- COBALION
  [639] = EggTier.LEGENDARY,  -- TERRAKION
  [640] = EggTier.LEGENDARY,  -- VIRIZION
  [641] = EggTier.LEGENDARY,  -- TORNADUS
  [642] = EggTier.LEGENDARY,  -- THUNDURUS
  [643] = EggTier.LEGENDARY,  -- RESHIRAM
  [644] = EggTier.LEGENDARY,  -- ZEKROM
  [645] = EggTier.LEGENDARY,  -- LANDORUS
  [646] = EggTier.LEGENDARY,  -- KYUREM
  [647] = EggTier.EPIC,  -- KELDEO
  [648] = EggTier.EPIC,  -- MELOETTA
  [649] = EggTier.LEGENDARY,  -- GENESECT
  [650] = EggTier.COMMON,  -- CHESPIN
  [653] = EggTier.COMMON,  -- FENNEKIN
  [656] = EggTier.COMMON,  -- FROAKIE
  [659] = EggTier.COMMON,  -- BUNNELBY
  [661] = EggTier.COMMON,  -- FLETCHLING
  [664] = EggTier.COMMON,  -- SCATTERBUG
  [667] = EggTier.RARE,  -- LITLEO
  [669] = EggTier.RARE,  -- FLABEBE
  [672] = EggTier.COMMON,  -- SKIDDO
  [674] = EggTier.COMMON,  -- PANCHAM
  [676] = EggTier.RARE,  -- FURFROU
  [677] = EggTier.RARE,  -- ESPURR
  [679] = EggTier.RARE,  -- HONEDGE
  [682] = EggTier.RARE,  -- SPRITZEE
  [684] = EggTier.RARE,  -- SWIRLIX
  [686] = EggTier.RARE,  -- INKAY
  [688] = EggTier.RARE,  -- BINACLE
  [690] = EggTier.RARE,  -- SKRELP
  [692] = EggTier.RARE,  -- CLAUNCHER
  [694] = EggTier.RARE,  -- HELIOPTILE
  [696] = EggTier.RARE,  -- TYRUNT
  [698] = EggTier.RARE,  -- AMAURA
  [700] = EggTier.RARE,  -- SYLVEON
  [701] = EggTier.RARE,  -- HAWLUCHA
  [702] = EggTier.RARE,  -- DEDENNE
  [703] = EggTier.EPIC,  -- CARBINK
  [704] = EggTier.COMMON,  -- GOOMY
  [707] = EggTier.RARE,  -- KLEFKI
  [708] = EggTier.RARE,  -- PHANTUMP
  [710] = EggTier.RARE,  -- PUMPKABOO
  [712] = EggTier.RARE,  -- BERGMITE
  [714] = EggTier.RARE,  -- NOIBAT
  [716] = EggTier.LEGENDARY,  -- XERNEAS
  [717] = EggTier.LEGENDARY,  -- YVELTAL
  [718] = EggTier.LEGENDARY,  -- ZYGARDE
  [719] = EggTier.EPIC,  -- DIANCIE
  [720] = EggTier.EPIC,  -- HOOPA
  [721] = EggTier.EPIC,  -- VOLCANION
  [722] = EggTier.COMMON,  -- ROWLET
  [725] = EggTier.COMMON,  -- LITTEN
  [728] = EggTier.COMMON,  -- POPPLIO
  [731] = EggTier.COMMON,  -- PIKIPEK
  [734] = EggTier.COMMON,  -- YUNGOOS
  [736] = EggTier.COMMON,  -- GRUBBIN
  [739] = EggTier.RARE,  -- CRABRAWLER
  [741] = EggTier.RARE,  -- ORICORIO
  [742] = EggTier.COMMON,  -- CUTIEFLY
  [744] = EggTier.COMMON,  -- ROCKRUFF
  [747] = EggTier.RARE,  -- MAREANIE
  [749] = EggTier.COMMON,  -- MUDBRAY
  [751] = EggTier.COMMON,  -- DEWPIDER
  [753] = EggTier.RARE,  -- FOMANTIS
  [755] = EggTier.RARE,  -- MORELULL
  [757] = EggTier.RARE,  -- SALANDIT
  [759] = EggTier.RARE,  -- STUFFUL
  [761] = EggTier.COMMON,  -- BOUNSWEET
  [764] = EggTier.RARE,  -- COMFEY
  [765] = EggTier.RARE,  -- ORANGURU
  [766] = EggTier.RARE,  -- PASSIMIAN
  [767] = EggTier.RARE,  -- WIMPOD
  [769] = EggTier.RARE,  -- SANDYGAST
  [771] = EggTier.RARE,  -- PYUKUMUKU
  [772] = EggTier.LEGENDARY,  -- TYPE_NULL
  [774] = EggTier.RARE,  -- MINIOR
  [775] = EggTier.RARE,  -- KOMALA
  [776] = EggTier.RARE,  -- TURTONATOR
  [777] = EggTier.RARE,  -- TOGEDEMARU
  [778] = EggTier.RARE,  -- MIMIKYU
  [779] = EggTier.RARE,  -- BRUXISH
  [780] = EggTier.EPIC,  -- DRAMPA
  [781] = EggTier.RARE,  -- DHELMISE
  [782] = EggTier.COMMON,  -- JANGMO_O
  [785] = EggTier.LEGENDARY,  -- TAPU_KOKO
  [786] = EggTier.LEGENDARY,  -- TAPU_LELE
  [787] = EggTier.LEGENDARY,  -- TAPU_BULU
  [788] = EggTier.LEGENDARY,  -- TAPU_FINI
  [789] = EggTier.LEGENDARY,  -- COSMOG
  [791] = EggTier.LEGENDARY,  -- SOLGALEO
  [792] = EggTier.LEGENDARY,  -- LUNALA
  [793] = EggTier.LEGENDARY,  -- NIHILEGO
  [794] = EggTier.LEGENDARY,  -- BUZZWOLE
  [795] = EggTier.LEGENDARY,  -- PHEROMOSA
  [796] = EggTier.LEGENDARY,  -- XURKITREE
  [797] = EggTier.LEGENDARY,  -- CELESTEELA
  [798] = EggTier.LEGENDARY,  -- KARTANA
  [799] = EggTier.LEGENDARY,  -- GUZZLORD
  [800] = EggTier.LEGENDARY,  -- NECROZMA
  [801] = EggTier.EPIC,  -- MAGEARNA
  [802] = EggTier.EPIC,  -- MARSHADOW
  [803] = EggTier.LEGENDARY,  -- POIPOLE
  [805] = EggTier.LEGENDARY,  -- STAKATAKA
  [806] = EggTier.LEGENDARY,  -- BLACEPHALON
  [807] = EggTier.EPIC,  -- ZERAORA
  [808] = EggTier.EPIC,  -- MELTAN
  [810] = EggTier.COMMON,  -- GROOKEY
  [813] = EggTier.COMMON,  -- SCORBUNNY
  [816] = EggTier.COMMON,  -- SOBBLE
  [819] = EggTier.COMMON,  -- SKWOVET
  [821] = EggTier.COMMON,  -- ROOKIDEE
  [824] = EggTier.COMMON,  -- BLIPBUG
  [827] = EggTier.COMMON,  -- NICKIT
  [829] = EggTier.COMMON,  -- GOSSIFLEUR
  [831] = EggTier.COMMON,  -- WOOLOO
  [833] = EggTier.COMMON,  -- CHEWTLE
  [835] = EggTier.COMMON,  -- YAMPER
  [837] = EggTier.RARE,  -- ROLYCOLY
  [840] = EggTier.COMMON,  -- APPLIN
  [843] = EggTier.RARE,  -- SILICOBRA
  [845] = EggTier.RARE,  -- CRAMORANT
  [846] = EggTier.COMMON,  -- ARROKUDA
  [848] = EggTier.RARE,  -- TOXEL
  [850] = EggTier.RARE,  -- SIZZLIPEDE
  [852] = EggTier.RARE,  -- CLOBBOPUS
  [854] = EggTier.RARE,  -- SINISTEA
  [856] = EggTier.RARE,  -- HATENNA
  [859] = EggTier.RARE,  -- IMPIDIMP
  [868] = EggTier.RARE,  -- MILCERY
  [870] = EggTier.RARE,  -- FALINKS
  [871] = EggTier.RARE,  -- PINCURCHIN
  [872] = EggTier.RARE,  -- SNOM
  [874] = EggTier.RARE,  -- STONJOURNER
  [875] = EggTier.RARE,  -- EISCUE
  [876] = EggTier.RARE,  -- INDEEDEE
  [877] = EggTier.RARE,  -- MORPEKO
  [878] = EggTier.RARE,  -- CUFANT
  [880] = EggTier.EPIC,  -- DRACOZOLT
  [881] = EggTier.EPIC,  -- ARCTOZOLT
  [882] = EggTier.EPIC,  -- DRACOVISH
  [883] = EggTier.EPIC,  -- ARCTOVISH
  [884] = EggTier.EPIC,  -- DURALUDON
  [885] = EggTier.COMMON,  -- DREEPY
  [888] = EggTier.LEGENDARY,  -- ZACIAN
  [889] = EggTier.LEGENDARY,  -- ZAMAZENTA
  [890] = EggTier.LEGENDARY,  -- ETERNATUS
  [891] = EggTier.LEGENDARY,  -- KUBFU
  [893] = EggTier.LEGENDARY,  -- ZARUDE
  [894] = EggTier.LEGENDARY,  -- REGIELEKI
  [895] = EggTier.LEGENDARY,  -- REGIDRAGO
  [896] = EggTier.LEGENDARY,  -- GLASTRIER
  [897] = EggTier.LEGENDARY,  -- SPECTRIER
  [898] = EggTier.LEGENDARY,  -- CALYREX
  [899] = EggTier.EPIC,  -- WYRDEER
  [900] = EggTier.EPIC,  -- KLEAVOR
  [901] = EggTier.EPIC,  -- URSALUNA
  [902] = EggTier.EPIC,  -- BASCULEGION
  [903] = EggTier.EPIC,  -- SNEASLER
  [904] = EggTier.EPIC,  -- OVERQWIL
  [905] = EggTier.LEGENDARY,  -- ENAMORUS
  [906] = EggTier.COMMON,  -- SPRIGATITO
  [909] = EggTier.COMMON,  -- FUECOCO
  [912] = EggTier.COMMON,  -- QUAXLY
  [915] = EggTier.COMMON,  -- LECHONK
  [917] = EggTier.COMMON,  -- TAROUNTULA
  [919] = EggTier.COMMON,  -- NYMBLE
  [921] = EggTier.COMMON,  -- PAWMI
  [924] = EggTier.RARE,  -- TANDEMAUS
  [926] = EggTier.RARE,  -- FIDOUGH
  [928] = EggTier.RARE,  -- SMOLIV
  [931] = EggTier.COMMON,  -- SQUAWKABILLY
  [932] = EggTier.COMMON,  -- NACLI
  [935] = EggTier.RARE,  -- CHARCADET
  [937] = EggTier.COMMON,  -- TADBULB
  [939] = EggTier.COMMON,  -- BELLIBOLT
  [940] = EggTier.COMMON,  -- WATTREL
  [942] = EggTier.COMMON,  -- MASCHIFF
  [944] = EggTier.RARE,  -- SHROODLE
  [946] = EggTier.COMMON,  -- BRAMBLIN
  [948] = EggTier.RARE,  -- TOEDSCOOL
  [950] = EggTier.RARE,  -- KLAWF
  [951] = EggTier.RARE,  -- CAPSAKID
  [953] = EggTier.RARE,  -- RELLOR
  [955] = EggTier.COMMON,  -- FLITTLE
  [957] = EggTier.RARE,  -- TINKATINK
  [960] = EggTier.RARE,  -- WIGLETT
  [962] = EggTier.COMMON,  -- BOMBIRDIER
  [963] = EggTier.RARE,  -- FINIZEN
  [965] = EggTier.COMMON,  -- VAROOM
  [967] = EggTier.RARE,  -- CYCLIZAR
  [968] = EggTier.COMMON,  -- ORTHWORM
  [969] = EggTier.RARE,  -- GLIMMET
  [971] = EggTier.COMMON,  -- GREAVARD
  [973] = EggTier.RARE,  -- FLAMIGO
  [974] = EggTier.COMMON,  -- CETODDLE
  [976] = EggTier.RARE,  -- VELUZA
  [977] = EggTier.RARE,  -- DONDOZO
  [978] = EggTier.RARE,  -- TATSUGIRI
  [984] = EggTier.EPIC,  -- GREAT_TUSK
  [985] = EggTier.EPIC,  -- SCREAM_TAIL
  [986] = EggTier.EPIC,  -- BRUTE_BONNET
  [987] = EggTier.EPIC,  -- FLUTTER_MANE
  [988] = EggTier.EPIC,  -- SLITHER_WING
  [989] = EggTier.EPIC,  -- SANDY_SHOCKS
  [990] = EggTier.EPIC,  -- IRON_TREADS
  [991] = EggTier.EPIC,  -- IRON_BUNDLE
  [992] = EggTier.EPIC,  -- IRON_HANDS
  [993] = EggTier.EPIC,  -- IRON_JUGULIS
  [994] = EggTier.EPIC,  -- IRON_MOTH
  [995] = EggTier.EPIC,  -- IRON_THORNS
  [996] = EggTier.COMMON,  -- FRIGIBAX
  [999] = EggTier.RARE,  -- GIMMIGHOUL
  [1001] = EggTier.EPIC,  -- WO_CHIEN
  [1002] = EggTier.EPIC,  -- CHIEN_PAO
  [1003] = EggTier.EPIC,  -- TING_LU
  [1004] = EggTier.EPIC,  -- CHI_YU
  [1005] = EggTier.EPIC,  -- ROARING_MOON
  [1006] = EggTier.EPIC,  -- IRON_VALIANT
  [1007] = EggTier.LEGENDARY,  -- KORAIDON
  [1008] = EggTier.LEGENDARY,  -- MIRAIDON
  [1009] = EggTier.EPIC,  -- WALKING_WAKE
  [1010] = EggTier.EPIC,  -- IRON_LEAVES
  [1012] = EggTier.RARE,  -- POLTCHAGEIST
  [1014] = EggTier.EPIC,  -- OKIDOGI
  [1015] = EggTier.EPIC,  -- MUNKIDORI
  [1016] = EggTier.EPIC,  -- FEZANDIPITI
  [1017] = EggTier.EPIC,  -- OGERPON
  [1020] = EggTier.EPIC,  -- GOUGING_FIRE
  [1021] = EggTier.EPIC,  -- RAGING_BOLT
  [1022] = EggTier.EPIC,  -- IRON_BOULDER
  [1023] = EggTier.EPIC,  -- IRON_CROWN
  [1024] = EggTier.LEGENDARY,  -- TERAPAGOS
  [1025] = EggTier.EPIC,  -- PECHARUNT
  [8128] = EggTier.RARE,  -- PALDEA_TAUROS
  [8194] = EggTier.RARE,  -- PALDEA_WOOPER
  [8901] = EggTier.EPIC,  -- BLOODMOON_URSALUNA
}

--[[
  Species Starter Costs: Maps SpeciesId to starter cost (1-9 range)
  Used for weighted species selection within tiers
  Auto-generated from TypeScript source files
]]
local speciesStarterCosts = {
  [1] = 3,  -- BULBASAUR
  [4] = 3,  -- CHARMANDER
  [7] = 3,  -- SQUIRTLE
  [10] = 2,  -- CATERPIE
  [13] = 1,  -- WEEDLE
  [16] = 1,  -- PIDGEY
  [19] = 1,  -- RATTATA
  [21] = 1,  -- SPEAROW
  [23] = 2,  -- EKANS
  [27] = 2,  -- SANDSHREW
  [29] = 3,  -- NIDORAN_F
  [32] = 3,  -- NIDORAN_M
  [37] = 3,  -- VULPIX
  [41] = 3,  -- ZUBAT
  [43] = 3,  -- ODDISH
  [46] = 2,  -- PARAS
  [48] = 2,  -- VENONAT
  [50] = 2,  -- DIGLETT
  [52] = 3,  -- MEOWTH
  [54] = 2,  -- PSYDUCK
  [56] = 4,  -- MANKEY
  [58] = 4,  -- GROWLITHE
  [60] = 2,  -- POLIWAG
  [63] = 4,  -- ABRA
  [66] = 3,  -- MACHOP
  [69] = 3,  -- BELLSPROUT
  [72] = 2,  -- TENTACOOL
  [74] = 3,  -- GEODUDE
  [77] = 3,  -- PONYTA
  [79] = 3,  -- SLOWPOKE
  [81] = 3,  -- MAGNEMITE
  [83] = 3,  -- FARFETCHD
  [84] = 2,  -- DODUO
  [86] = 2,  -- SEEL
  [88] = 4,  -- GRIMER
  [90] = 3,  -- SHELLDER
  [92] = 4,  -- GASTLY
  [95] = 4,  -- ONIX
  [96] = 3,  -- DROWZEE
  [98] = 2,  -- KRABBY
  [100] = 2,  -- VOLTORB
  [102] = 3,  -- EXEGGCUTE
  [104] = 2,  -- CUBONE
  [106] = 4,  -- HITMONLEE
  [107] = 4,  -- HITMONCHAN
  [108] = 4,  -- LICKITUNG
  [109] = 3,  -- KOFFING
  [111] = 3,  -- RHYHORN
  [113] = 4,  -- CHANSEY
  [114] = 3,  -- TANGELA
  [115] = 4,  -- KANGASKHAN
  [116] = 2,  -- HORSEA
  [118] = 2,  -- GOLDEEN
  [120] = 2,  -- STARYU
  [122] = 4,  -- MR_MIME
  [123] = 4,  -- SCYTHER
  [124] = 4,  -- JYNX
  [125] = 4,  -- ELECTABUZZ
  [126] = 4,  -- MAGMAR
  [127] = 4,  -- PINSIR
  [128] = 4,  -- TAUROS
  [129] = 1,  -- MAGIKARP
  [131] = 4,  -- LAPRAS
  [132] = 3,  -- DITTO
  [133] = 3,  -- EEVEE
  [137] = 3,  -- PORYGON
  [138] = 4,  -- OMANYTE
  [140] = 4,  -- KABUTO
  [142] = 4,  -- AERODACTYL
  [143] = 4,  -- SNORLAX
  [144] = 8,  -- ARTICUNO
  [145] = 8,  -- ZAPDOS
  [146] = 8,  -- MOLTRES
  [147] = 3,  -- DRATINI
  [150] = 9,  -- MEWTWO
  [151] = 8,  -- MEW
  [152] = 3,  -- CHIKORITA
  [155] = 3,  -- CYNDAQUIL
  [158] = 3,  -- TOTODILE
  [161] = 1,  -- SENTRET
  [163] = 1,  -- HOOTHOOT
  [165] = 1,  -- LEDYBA
  [167] = 1,  -- SPINARAK
  [170] = 2,  -- CHINCHOU
  [172] = 2,  -- PICHU
  [173] = 2,  -- CLEFFA
  [174] = 2,  -- IGGLYBUFF
  [175] = 3,  -- TOGEPI
  [177] = 4,  -- NATU
  [179] = 3,  -- MAREEP
  [183] = 2,  -- MARILL
  [185] = 4,  -- SUDOWOODO
  [187] = 2,  -- HOPPIP
  [190] = 3,  -- AIPOM
  [191] = 1,  -- SUNKERN
  [193] = 3,  -- YANMA
  [194] = 2,  -- WOOPER
  [198] = 3,  -- MURKROW
  [200] = 3,  -- MISDREAVUS
  [202] = 4,  -- WOBBUFFET
  [203] = 4,  -- GIRAFARIG
  [204] = 2,  -- PINECO
  [206] = 4,  -- DUNSPARCE
  [207] = 3,  -- GLIGAR
  [209] = 2,  -- SNUBBULL
  [211] = 3,  -- QWILFISH
  [213] = 4,  -- SHUCKLE
  [214] = 4,  -- HERACROSS
  [215] = 3,  -- SNEASEL
  [216] = 2,  -- TEDDIURSA
  [217] = 4,  -- URSARING
  [218] = 2,  -- SLUGMA
  [220] = 2,  -- SWINUB
  [222] = 4,  -- CORSOLA
  [223] = 2,  -- REMORAID
  [225] = 4,  -- DELIBIRD
  [226] = 4,  -- MANTINE
  [227] = 4,  -- SKARMORY
  [228] = 3,  -- HOUNDOUR
  [231] = 4,  -- PHANPY
  [234] = 4,  -- STANTLER
  [235] = 3,  -- SMEARGLE
  [236] = 4,  -- TYROGUE
  [238] = 4,  -- SMOOCHUM
  [239] = 4,  -- ELEKID
  [240] = 4,  -- MAGBY
  [241] = 4,  -- MILTANK
  [243] = 8,  -- RAIKOU
  [244] = 8,  -- ENTEI
  [245] = 8,  -- SUICUNE
  [246] = 3,  -- LARVITAR
  [249] = 9,  -- LUGIA
  [250] = 9,  -- HO_OH
  [251] = 8,  -- CELEBI
  [252] = 3,  -- TREECKO
  [255] = 3,  -- TORCHIC
  [258] = 3,  -- MUDKIP
  [261] = 1,  -- POOCHYENA
  [263] = 1,  -- ZIGZAGOON
  [265] = 1,  -- WURMPLE
  [270] = 2,  -- LOTAD
  [273] = 2,  -- SEEDOT
  [276] = 1,  -- TAILLOW
  [278] = 1,  -- WINGULL
  [280] = 4,  -- RALTS
  [283] = 2,  -- SURSKIT
  [285] = 4,  -- SHROOMISH
  [287] = 3,  -- SLAKOTH
  [290] = 4,  -- NINCADA
  [293] = 2,  -- WHISMUR
  [296] = 2,  -- MAKUHITA
  [298] = 2,  -- AZURILL
  [299] = 3,  -- NOSEPASS
  [300] = 2,  -- SKITTY
  [302] = 4,  -- SABLEYE
  [303] = 4,  -- MAWILE
  [304] = 3,  -- ARON
  [307] = 4,  -- MEDITITE
  [309] = 2,  -- ELECTRIKE
  [311] = 4,  -- PLUSLE
  [312] = 4,  -- MINUN
  [313] = 4,  -- VOLBEAT
  [314] = 4,  -- ILLUMISE
  [315] = 4,  -- ROSELIA
  [316] = 2,  -- GULPIN
  [318] = 4,  -- CARVANHA
  [320] = 4,  -- WAILMER
  [322] = 2,  -- NUMEL
  [324] = 4,  -- TORKOAL
  [325] = 2,  -- SPOINK
  [327] = 4,  -- SPINDA
  [328] = 3,  -- TRAPINCH
  [331] = 4,  -- CACNEA
  [333] = 2,  -- SWABLU
  [335] = 4,  -- ZANGOOSE
  [336] = 4,  -- SEVIPER
  [337] = 4,  -- LUNATONE
  [338] = 4,  -- SOLROCK
  [339] = 2,  -- BARBOACH
  [341] = 2,  -- CORPHISH
  [343] = 4,  -- BALTOY
  [345] = 4,  -- LILEEP
  [347] = 4,  -- ANORITH
  [349] = 1,  -- FEEBAS
  [351] = 4,  -- CASTFORM
  [352] = 4,  -- KECLEON
  [353] = 2,  -- SHUPPET
  [355] = 2,  -- DUSKULL
  [357] = 4,  -- TROPIUS
  [358] = 4,  -- CHIMECHO
  [359] = 4,  -- ABSOL
  [360] = 3,  -- WYNAUT
  [361] = 2,  -- SNORUNT
  [363] = 2,  -- SPHEAL
  [366] = 4,  -- CLAMPERL
  [369] = 4,  -- RELICANTH
  [370] = 4,  -- LUVDISC
  [371] = 3,  -- BAGON
  [374] = 4,  -- BELDUM
  [377] = 8,  -- REGIROCK
  [378] = 8,  -- REGICE
  [379] = 8,  -- REGISTEEL
  [380] = 8,  -- LATIAS
  [381] = 8,  -- LATIOS
  [382] = 9,  -- KYOGRE
  [383] = 9,  -- GROUDON
  [384] = 9,  -- RAYQUAZA
  [385] = 8,  -- JIRACHI
  [386] = 8,  -- DEOXYS
  [387] = 3,  -- TURTWIG
  [390] = 3,  -- CHIMCHAR
  [393] = 3,  -- PIPLUP
  [396] = 1,  -- STARLY
  [399] = 1,  -- BIDOOF
  [401] = 1,  -- KRICKETOT
  [403] = 2,  -- SHINX
  [406] = 4,  -- BUDEW
  [408] = 4,  -- CRANIDOS
  [410] = 4,  -- SHIELDON
  [412] = 2,  -- BURMY
  [415] = 1,  -- COMBEE
  [417] = 4,  -- PACHIRISU
  [418] = 2,  -- BUIZEL
  [420] = 4,  -- CHERUBI
  [422] = 2,  -- SHELLOS
  [425] = 2,  -- DRIFLOON
  [427] = 4,  -- BUNEARY
  [429] = 4,  -- MISMAGIUS
  [431] = 2,  -- GLAMEOW
  [433] = 4,  -- CHINGLING
  [434] = 2,  -- STUNKY
  [436] = 4,  -- BRONZOR
  [438] = 4,  -- BONSLY
  [439] = 4,  -- MIME_JR
  [440] = 4,  -- HAPPINY
  [441] = 4,  -- CHATOT
  [442] = 4,  -- SPIRITOMB
  [443] = 3,  -- GIBLE
  [446] = 4,  -- MUNCHLAX
  [447] = 3,  -- RIOLU
  [449] = 4,  -- HIPPOPOTAS
  [451] = 2,  -- SKORUPI
  [453] = 4,  -- CROAGUNK
  [455] = 4,  -- CARNIVINE
  [456] = 4,  -- FINNEON
  [458] = 4,  -- MANTYKE
  [459] = 2,  -- SNOVER
  [462] = 5,  -- MAGNEZONE
  [463] = 5,  -- LICKILICKY
  [464] = 5,  -- RHYPERIOR
  [465] = 5,  -- TANGROWTH
  [466] = 5,  -- ELECTIVIRE
  [467] = 5,  -- MAGMORTAR
  [468] = 5,  -- TOGEKISS
  [469] = 5,  -- YANMEGA
  [470] = 5,  -- LEAFEON
  [471] = 5,  -- GLACEON
  [472] = 5,  -- GLISCOR
  [473] = 5,  -- MAMOSWINE
  [474] = 5,  -- PORYGON_Z
  [475] = 5,  -- GALLADE
  [476] = 5,  -- PROBOPASS
  [477] = 5,  -- DUSKNOIR
  [478] = 5,  -- FROSLASS
  [479] = 6,  -- ROTOM
  [480] = 8,  -- UXIE
  [481] = 8,  -- MESPRIT
  [482] = 8,  -- AZELF
  [483] = 9,  -- DIALGA
  [484] = 9,  -- PALKIA
  [485] = 8,  -- HEATRAN
  [486] = 8,  -- REGIGIGAS
  [487] = 9,  -- GIRATINA
  [488] = 8,  -- CRESSELIA
  [490] = 8,  -- MANAPHY
  [491] = 8,  -- DARKRAI
  [492] = 8,  -- SHAYMIN
  [493] = 9,  -- ARCEUS
  [494] = 8,  -- VICTINI
  [495] = 3,  -- SNIVY
  [498] = 3,  -- TEPIG
  [501] = 3,  -- OSHAWOTT
  [504] = 1,  -- PATRAT
  [506] = 1,  -- LILLIPUP
  [509] = 1,  -- PURRLOIN
  [511] = 2,  -- PANSAGE
  [513] = 2,  -- PANSEAR
  [515] = 2,  -- PANPOUR
  [517] = 2,  -- MUNNA
  [519] = 1,  -- PIDOVE
  [522] = 4,  -- BLITZLE
  [524] = 4,  -- ROGGENROLA
  [527] = 2,  -- WOOBAT
  [529] = 2,  -- DRILBUR
  [531] = 4,  -- AUDINO
  [532] = 2,  -- TIMBURR
  [535] = 2,  -- TYMPOLE
  [538] = 4,  -- THROH
  [539] = 4,  -- SAWK
  [540] = 2,  -- SEWADDLE
  [543] = 2,  -- VENIPEDE
  [546] = 4,  -- COTTONEE
  [548] = 4,  -- PETILIL
  [550] = 4,  -- BASCULIN
  [551] = 2,  -- SANDILE
  [554] = 4,  -- DARUMAKA
  [556] = 4,  -- MARACTUS
  [557] = 2,  -- DWEBBLE
  [559] = 2,  -- SCRAGGY
  [561] = 4,  -- SIGILYPH
  [562] = 4,  -- YAMASK
  [564] = 4,  -- TIRTOUGA
  [566] = 4,  -- ARCHEN
  [568] = 4,  -- TRUBBISH
  [570] = 4,  -- ZORUA
  [572] = 2,  -- MINCCINO
  [574] = 4,  -- GOTHITA
  [577] = 4,  -- SOLOSIS
  [580] = 2,  -- DUCKLETT
  [582] = 2,  -- VANILLITE
  [585] = 4,  -- DEERLING
  [587] = 4,  -- EMOLGA
  [588] = 4,  -- KARRABLAST
  [590] = 4,  -- FOONGUS
  [592] = 4,  -- FRILLISH
  [594] = 4,  -- ALOMOMOLA
  [595] = 2,  -- JOLTIK
  [597] = 2,  -- FERROSEED
  [599] = 4,  -- KLINK
  [602] = 4,  -- TYNAMO
  [605] = 4,  -- ELGYEM
  [607] = 4,  -- LITWICK
  [610] = 3,  -- AXEW
  [613] = 4,  -- CUBCHOO
  [615] = 4,  -- CRYOGONAL
  [616] = 4,  -- SHELMET
  [618] = 4,  -- STUNFISK
  [619] = 4,  -- MIENFOO
  [621] = 6,  -- DRUDDIGON
  [622] = 4,  -- GOLETT
  [624] = 2,  -- PAWNIARD
  [626] = 4,  -- BOUFFALANT
  [627] = 4,  -- RUFFLET
  [629] = 4,  -- VULLABY
  [631] = 4,  -- HEATMOR
  [632] = 4,  -- DURANT
  [633] = 3,  -- DEINO
  [636] = 4,  -- LARVESTA
  [638] = 8,  -- COBALION
  [639] = 8,  -- TERRAKION
  [640] = 8,  -- VIRIZION
  [641] = 8,  -- TORNADUS
  [642] = 8,  -- THUNDURUS
  [643] = 9,  -- RESHIRAM
  [644] = 9,  -- ZEKROM
  [645] = 8,  -- LANDORUS
  [646] = 9,  -- KYUREM
  [647] = 8,  -- KELDEO
  [648] = 8,  -- MELOETTA
  [649] = 8,  -- GENESECT
  [650] = 3,  -- CHESPIN
  [653] = 3,  -- FENNEKIN
  [656] = 3,  -- FROAKIE
  [659] = 1,  -- BUNNELBY
  [661] = 1,  -- FLETCHLING
  [664] = 1,  -- SCATTERBUG
  [667] = 4,  -- LITLEO
  [669] = 4,  -- FLABEBE
  [672] = 2,  -- SKIDDO
  [674] = 2,  -- PANCHAM
  [676] = 4,  -- FURFROU
  [677] = 4,  -- ESPURR
  [679] = 4,  -- HONEDGE
  [682] = 4,  -- SPRITZEE
  [684] = 4,  -- SWIRLIX
  [686] = 4,  -- INKAY
  [688] = 4,  -- BINACLE
  [690] = 4,  -- SKRELP
  [692] = 4,  -- CLAUNCHER
  [694] = 4,  -- HELIOPTILE
  [696] = 4,  -- TYRUNT
  [698] = 4,  -- AMAURA
  [700] = 5,  -- SYLVEON
  [701] = 4,  -- HAWLUCHA
  [702] = 4,  -- DEDENNE
  [703] = 7,  -- CARBINK
  [704] = 3,  -- GOOMY
  [707] = 4,  -- KLEFKI
  [708] = 4,  -- PHANTUMP
  [710] = 4,  -- PUMPKABOO
  [712] = 4,  -- BERGMITE
  [714] = 4,  -- NOIBAT
  [716] = 9,  -- XERNEAS
  [717] = 9,  -- YVELTAL
  [718] = 9,  -- ZYGARDE
  [719] = 8,  -- DIANCIE
  [720] = 8,  -- HOOPA
  [721] = 8,  -- VOLCANION
  [722] = 3,  -- ROWLET
  [725] = 3,  -- LITTEN
  [728] = 3,  -- POPPLIO
  [731] = 1,  -- PIKIPEK
  [734] = 1,  -- YUNGOOS
  [736] = 2,  -- GRUBBIN
  [739] = 4,  -- CRABRAWLER
  [741] = 4,  -- ORICORIO
  [742] = 2,  -- CUTIEFLY
  [744] = 2,  -- ROCKRUFF
  [747] = 4,  -- MAREANIE
  [749] = 2,  -- MUDBRAY
  [751] = 2,  -- DEWPIDER
  [753] = 4,  -- FOMANTIS
  [755] = 4,  -- MORELULL
  [757] = 4,  -- SALANDIT
  [759] = 4,  -- STUFFUL
  [761] = 2,  -- BOUNSWEET
  [764] = 4,  -- COMFEY
  [765] = 4,  -- ORANGURU
  [766] = 4,  -- PASSIMIAN
  [767] = 4,  -- WIMPOD
  [769] = 4,  -- SANDYGAST
  [771] = 4,  -- PYUKUMUKU
  [772] = 8,  -- TYPE_NULL
  [774] = 4,  -- MINIOR
  [775] = 4,  -- KOMALA
  [776] = 4,  -- TURTONATOR
  [777] = 4,  -- TOGEDEMARU
  [778] = 4,  -- MIMIKYU
  [779] = 4,  -- BRUXISH
  [780] = 7,  -- DRAMPA
  [781] = 4,  -- DHELMISE
  [782] = 3,  -- JANGMO_O
  [785] = 8,  -- TAPU_KOKO
  [786] = 8,  -- TAPU_LELE
  [787] = 8,  -- TAPU_BULU
  [788] = 8,  -- TAPU_FINI
  [789] = 8,  -- COSMOG
  [791] = 9,  -- SOLGALEO
  [792] = 9,  -- LUNALA
  [793] = 8,  -- NIHILEGO
  [794] = 8,  -- BUZZWOLE
  [795] = 8,  -- PHEROMOSA
  [796] = 8,  -- XURKITREE
  [797] = 8,  -- CELESTEELA
  [798] = 8,  -- KARTANA
  [799] = 8,  -- GUZZLORD
  [800] = 8,  -- NECROZMA
  [801] = 8,  -- MAGEARNA
  [802] = 8,  -- MARSHADOW
  [803] = 8,  -- POIPOLE
  [805] = 8,  -- STAKATAKA
  [806] = 8,  -- BLACEPHALON
  [807] = 8,  -- ZERAORA
  [808] = 8,  -- MELTAN
  [810] = 3,  -- GROOKEY
  [813] = 3,  -- SCORBUNNY
  [816] = 3,  -- SOBBLE
  [819] = 1,  -- SKWOVET
  [821] = 1,  -- ROOKIDEE
  [824] = 1,  -- BLIPBUG
  [827] = 2,  -- NICKIT
  [829] = 2,  -- GOSSIFLEUR
  [831] = 2,  -- WOOLOO
  [833] = 2,  -- CHEWTLE
  [835] = 2,  -- YAMPER
  [837] = 4,  -- ROLYCOLY
  [840] = 2,  -- APPLIN
  [843] = 4,  -- SILICOBRA
  [845] = 4,  -- CRAMORANT
  [846] = 2,  -- ARROKUDA
  [848] = 4,  -- TOXEL
  [850] = 4,  -- SIZZLIPEDE
  [852] = 4,  -- CLOBBOPUS
  [854] = 4,  -- SINISTEA
  [856] = 4,  -- HATENNA
  [859] = 4,  -- IMPIDIMP
  [868] = 4,  -- MILCERY
  [870] = 4,  -- FALINKS
  [871] = 4,  -- PINCURCHIN
  [872] = 4,  -- SNOM
  [874] = 4,  -- STONJOURNER
  [875] = 4,  -- EISCUE
  [876] = 4,  -- INDEEDEE
  [877] = 4,  -- MORPEKO
  [878] = 4,  -- CUFANT
  [880] = 7,  -- DRACOZOLT
  [881] = 7,  -- ARCTOZOLT
  [882] = 7,  -- DRACOVISH
  [883] = 7,  -- ARCTOVISH
  [884] = 6,  -- DURALUDON
  [885] = 3,  -- DREEPY
  [888] = 9,  -- ZACIAN
  [889] = 9,  -- ZAMAZENTA
  [890] = 9,  -- ETERNATUS
  [891] = 8,  -- KUBFU
  [893] = 8,  -- ZARUDE
  [894] = 8,  -- REGIELEKI
  [895] = 8,  -- REGIDRAGO
  [896] = 8,  -- GLASTRIER
  [897] = 8,  -- SPECTRIER
  [898] = 9,  -- CALYREX
  [899] = 7,  -- WYRDEER
  [900] = 7,  -- KLEAVOR
  [901] = 7,  -- URSALUNA
  [902] = 6,  -- BASCULEGION
  [903] = 6,  -- SNEASLER
  [904] = 6,  -- OVERQWIL
  [905] = 8,  -- ENAMORUS
  [906] = 3,  -- SPRIGATITO
  [909] = 3,  -- FUECOCO
  [912] = 3,  -- QUAXLY
  [915] = 1,  -- LECHONK
  [917] = 1,  -- TAROUNTULA
  [919] = 1,  -- NYMBLE
  [921] = 2,  -- PAWMI
  [924] = 4,  -- TANDEMAUS
  [926] = 4,  -- FIDOUGH
  [928] = 4,  -- SMOLIV
  [931] = 2,  -- SQUAWKABILLY
  [932] = 2,  -- NACLI
  [935] = 4,  -- CHARCADET
  [937] = 2,  -- TADBULB
  [939] = 3,  -- BELLIBOLT
  [940] = 2,  -- WATTREL
  [942] = 2,  -- MASCHIFF
  [944] = 4,  -- SHROODLE
  [946] = 2,  -- BRAMBLIN
  [948] = 4,  -- TOEDSCOOL
  [950] = 4,  -- KLAWF
  [951] = 4,  -- CAPSAKID
  [953] = 4,  -- RELLOR
  [955] = 2,  -- FLITTLE
  [957] = 4,  -- TINKATINK
  [960] = 4,  -- WIGLETT
  [962] = 2,  -- BOMBIRDIER
  [963] = 4,  -- FINIZEN
  [965] = 2,  -- VAROOM
  [967] = 4,  -- CYCLIZAR
  [968] = 2,  -- ORTHWORM
  [969] = 4,  -- GLIMMET
  [971] = 3,  -- GREAVARD
  [973] = 4,  -- FLAMIGO
  [974] = 3,  -- CETODDLE
  [976] = 4,  -- VELUZA
  [977] = 4,  -- DONDOZO
  [978] = 4,  -- TATSUGIRI
  [984] = 7,  -- GREAT_TUSK
  [985] = 5,  -- SCREAM_TAIL
  [986] = 5,  -- BRUTE_BONNET
  [987] = 7,  -- FLUTTER_MANE
  [988] = 6,  -- SLITHER_WING
  [989] = 6,  -- SANDY_SHOCKS
  [990] = 6,  -- IRON_TREADS
  [991] = 6,  -- IRON_BUNDLE
  [992] = 6,  -- IRON_HANDS
  [993] = 6,  -- IRON_JUGULIS
  [994] = 6,  -- IRON_MOTH
  [995] = 5,  -- IRON_THORNS
  [996] = 4,  -- FRIGIBAX
  [999] = 4,  -- GIMMIGHOUL
  [1001] = 5,  -- WO_CHIEN
  [1002] = 7,  -- CHIEN_PAO
  [1003] = 6,  -- TING_LU
  [1004] = 7,  -- CHI_YU
  [1005] = 7,  -- ROARING_MOON
  [1006] = 6,  -- IRON_VALIANT
  [1007] = 9,  -- KORAIDON
  [1008] = 9,  -- MIRAIDON
  [1009] = 7,  -- WALKING_WAKE
  [1010] = 6,  -- IRON_LEAVES
  [1012] = 4,  -- POLTCHAGEIST
  [1014] = 6,  -- OKIDOGI
  [1015] = 6,  -- MUNKIDORI
  [1016] = 5,  -- FEZANDIPITI
  [1017] = 7,  -- OGERPON
  [1020] = 7,  -- GOUGING_FIRE
  [1021] = 7,  -- RAGING_BOLT
  [1022] = 7,  -- IRON_BOULDER
  [1023] = 7,  -- IRON_CROWN
  [1024] = 9,  -- TERAPAGOS
  [1025] = 6,  -- PECHARUNT
  [8128] = 5,  -- PALDEA_TAUROS
  [8194] = 3,  -- PALDEA_WOOPER
  [8901] = 5,  -- BLOODMOON_URSALUNA
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
  Get tier name as string
  @param tier Tier value (0-3)
  @return Tier name ("COMMON", "RARE", "EPIC", "LEGENDARY")
]]
local function getEggTierDescriptor(tier)
  if tier == EggTier.RARE then
    return "RARE"
  elseif tier == EggTier.EPIC then
    return "EPIC"
  elseif tier == EggTier.LEGENDARY then
    return "LEGENDARY"
  else
    return "COMMON"
  end
end

--[[
  Get default hatch waves for a tier
  @param tier Tier value (0-3)
  @param speciesId Optional species ID for special cases (Manaphy/Phione)
  @return Number of waves required to hatch
]]
local function getEggTierDefaultHatchWaves(tier, speciesId)
  if speciesId == SPECIES_ID_PHIONE or speciesId == SPECIES_ID_MANAPHY then
    return HATCH_WAVES_MANAPHY_EGG
  end

  return HATCH_WAVES[tier] or HATCH_WAVES[EggTier.LEGENDARY]
end

--[[
  Roll egg tier using threshold comparison
  @param sourceType Gacha source type ("GACHA_LEGENDARY", "GACHA_SHINY", "GACHA_MOVE", "SAME_SPECIES_EGG")
  @param tierValueOffset Optional offset for threshold (default 0)
  @param randomValue Optional pre-generated random value (0-255) for testing
  @return Rolled tier (0-3)
]]
local function rollEggTier(sourceType, tierValueOffset, randomValue)
  tierValueOffset = tierValueOffset or 0

  -- Generate random value 0-255 (or use provided value for testing)
  local tierValue = randomValue or math.random(0, 255)

  -- Apply legendary gacha offset if applicable
  if sourceType == "GACHA_LEGENDARY" then
    tierValueOffset = tierValueOffset + GACHA_LEGENDARY_UP_THRESHOLD_OFFSET
  end

  -- Determine tier by highest threshold met or exceeded
  if tierValue >= GACHA_DEFAULT_COMMON_EGG_THRESHOLD + tierValueOffset then
    return EggTier.COMMON
  elseif tierValue >= GACHA_DEFAULT_RARE_EGG_THRESHOLD + tierValueOffset then
    return EggTier.RARE
  elseif tierValue >= GACHA_DEFAULT_EPIC_EGG_THRESHOLD + tierValueOffset then
    return EggTier.EPIC
  else
    return EggTier.LEGENDARY
  end
end

--[[
  Calculate species weight based on starter cost
  @param speciesCost Species starter cost (1-9)
  @param minCost Minimum cost for tier
  @param maxCost Maximum cost for tier
  @return Weight value (multiplied by 100 for precision)
]]
local function calculateSpeciesWeight(speciesCost, minCost, maxCost)
  -- Clamp cost to tier range
  local clampedCost = math.max(minCost, math.min(speciesCost, maxCost))

  -- Weight formula: lower cost in tier = higher weight
  -- Formula: floor((((maxCost - clampedCost) / (maxCost - minCost + 1)) * 1.5 + 1) * 100)
  local weight = math.floor((((maxCost - clampedCost) / (maxCost - minCost + 1)) * 1.5 + 1) * 100)

  return weight
end

--[[
  Get species pool for a tier with filtering
  @param tier Tier value (0-3)
  @param variantTier Optional variant tier filter (1=RARE, 2=EPIC)
  @param dexData Optional caught species data for unlock pity
  @param unlockPityCount Optional unlock pity counter
  @return Filtered species pool (array of species IDs)
]]
local function getSpeciesPoolForTier(tier, variantTier, dexData, unlockPityCount)
  local speciesPool = {}

  -- Filter species by tier
  for speciesId, speciesTier in pairs(speciesEggTiers) do
    if speciesTier == tier then
      -- Exclude ignored species
      if speciesId ~= SPECIES_ID_PHIONE and
         speciesId ~= SPECIES_ID_MANAPHY and
         speciesId ~= SPECIES_ID_ETERNATUS then
        table.insert(speciesPool, speciesId)
      end
    end
  end

  -- Apply unlock pity: force locked species after threshold
  if unlockPityCount and unlockPityCount >= UNLOCK_PITY_THRESHOLD and dexData then
    local lockedPool = {}
    for _, speciesId in ipairs(speciesPool) do
      if not dexData[tostring(speciesId)] then
        table.insert(lockedPool, speciesId)
      end
    end

    if #lockedPool > 0 then
      speciesPool = lockedPool
    end
  end

  -- TODO: Filter by variant tier if specified (requires variant data)
  -- TODO: Filter out prevolutions (requires evolution data)

  return speciesPool
end

--[[
  Roll species with weighted selection
  @param tier Tier value (0-3)
  @param speciesPool Array of species IDs
  @param randomValue Optional pre-generated random value for testing
  @return Selected species ID
]]
local function rollSpecies(tier, speciesPool, randomValue)
  local costRange = TIER_COST_RANGES[tier]
  local minCost = costRange.min
  local maxCost = costRange.max

  -- Calculate weights for each species
  local totalWeight = 0
  local speciesWeights = {}

  for _, speciesId in ipairs(speciesPool) do
    local cost = speciesStarterCosts[speciesId] or minCost
    local weight = calculateSpeciesWeight(cost, minCost, maxCost)
    totalWeight = totalWeight + weight
    table.insert(speciesWeights, {speciesId = speciesId, cumulativeWeight = totalWeight})
  end

  -- Select species using weighted random
  local rand = randomValue or math.random(1, totalWeight)
  for _, entry in ipairs(speciesWeights) do
    if rand <= entry.cumulativeWeight then
      return entry.speciesId
    end
  end

  -- Fallback to first species (shouldn't happen)
  return speciesPool[1]
end

--[[
  Check if pity should force a tier override
  @param currentTier Current rolled tier
  @param eggPity Pity counter object {[tier] = count}
  @param sourceType Gacha source type
  @return Forced tier (or currentTier if no override)
]]
local function checkForPityTierOverrides(currentTier, eggPity, sourceType)
  if not eggPity or currentTier ~= EggTier.COMMON then
    return currentTier
  end

  local tierOffset = (sourceType == "GACHA_LEGENDARY") and GACHA_LEGENDARY_UP_THRESHOLD_OFFSET or 0

  -- Check legendary pity
  local legPity = eggPity[tostring(EggTier.LEGENDARY)] or 0
  if legPity >= EGG_PITY_LEGENDARY_THRESHOLD then
    return EggTier.LEGENDARY
  end

  -- Check epic pity
  local epicPity = eggPity[tostring(EggTier.EPIC)] or 0
  if epicPity >= EGG_PITY_EPIC_THRESHOLD then
    return EggTier.EPIC
  end

  -- Check rare pity
  local rarePity = eggPity[tostring(EggTier.RARE)] or 0
  if rarePity >= EGG_PITY_RARE_THRESHOLD then
    return EggTier.RARE
  end

  return currentTier
end

--[[
  Get egg move index with tier-specific rates
  @param tier Tier value (0-3)
  @param sourceType Gacha source type
  @param randomValue Optional pre-generated random value for testing
  @return Egg move slot (0-2 for common, 3 for rare)
]]
local function getEggMoveIndexForTier(tier, sourceType, randomValue)
  local rates = RARE_EGGMOVE_RATES

  -- Use boosted rates for GACHA_MOVE or SAME_SPECIES_EGG
  if sourceType == "GACHA_MOVE" or sourceType == "SAME_SPECIES_EGG" then
    rates = BOOSTED_RARE_EGGMOVE_RATES
  end

  local rareChance = rates[tier] or rates[EggTier.LEGENDARY]
  local rand = randomValue or math.random(1, rareChance)

  -- 1/rareChance for slot 3 (rare), else random common slot (0-2)
  if rand == 1 then
    return 3  -- Rare egg move
  else
    return math.random(0, 2)  -- Common egg move
  end
end

-- ============================================================================
-- AO MESSAGE HANDLERS
-- ============================================================================

--[[
  Info Handler: ADP v1.0 self-documentation
]]
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        name = "Egg Tier Reward Engine",
        version = "1.0.0",
        adpVersion = "1.0",
        capabilities = {
          "tier-rolling",
          "species-selection",
          "pity-tracking",
          "tier-validation",
          "bonus-calculation"
        },
        handlers = {
          {action = "Info", description = "Get process capabilities and documentation"},
          {action = "RollEggTier", description = "Roll egg tier using threshold comparison"},
          {action = "GetSpeciesByTier", description = "Get filtered species pool for a tier"},
          {action = "RollSpecies", description = "Select species with weighted random"},
          {action = "GetTierInfo", description = "Get tier metadata and configuration"},
          {action = "ValidateTierProgression", description = "Validate pity counters"},
          {action = "GetEggMoveIndex", description = "Calculate egg move slot"}
        },
        dataStructures = {
          eggTiers = {"COMMON = 0", "RARE = 1", "EPIC = 2", "LEGENDARY = 3"},
          speciesCount = 569,
          pityThresholds = {RARE = 9, EPIC = 59, LEGENDARY = 412}
        }
      })
    })
  end
)

--[[
  RollEggTier Handler: Determine egg tier using threshold comparison
]]
Handlers.add("roll-egg-tier",
  Handlers.utils.hasMatchingTag("Action", "RollEggTier"),
  function(msg)
    local sourceType = msg.SourceType
    if not sourceType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "SourceType required"
      })
      return
    end

    -- Parse egg pity if provided
    local eggPity = nil
    if msg.EggPity and msg.EggPity ~= "" then
      eggPity = json.decode(msg.EggPity)
    end

    -- Roll tier
    local tier = rollEggTier(sourceType, 0, nil)

    -- Check for pity overrides
    if eggPity then
      tier = checkForPityTierOverrides(tier, eggPity, sourceType)
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Tier = tostring(tier),
      TierName = getEggTierDescriptor(tier),
      HatchWaves = tostring(getEggTierDefaultHatchWaves(tier))
    })
  end
)

--[[
  GetSpeciesByTier Handler: Get filtered species pool for a tier
]]
Handlers.add("get-species-by-tier",
  Handlers.utils.hasMatchingTag("Action", "GetSpeciesByTier"),
  function(msg)
    local tier = tonumber(msg.Tier)
    if not tier or tier < 0 or tier > 3 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Tier (0-3) required"
      })
      return
    end

    -- Parse optional filters
    local variantTier = tonumber(msg.VariantTier)
    local unlockPity = tonumber(msg.UnlockPity) or 0
    local dexData = nil
    if msg.DexData and msg.DexData ~= "" then
      dexData = json.decode(msg.DexData)
    end

    local speciesPool = getSpeciesPoolForTier(tier, variantTier, dexData, unlockPity)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        tier = tier,
        speciesPool = speciesPool,
        poolSize = #speciesPool
      })
    })
  end
)

--[[
  RollSpecies Handler: Select species with weighted random selection
]]
Handlers.add("roll-species",
  Handlers.utils.hasMatchingTag("Action", "RollSpecies"),
  function(msg)
    local tier = tonumber(msg.Tier)
    if not tier or tier < 0 or tier > 3 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Tier (0-3) required"
      })
      return
    end

    -- Get species pool
    local variantTier = tonumber(msg.VariantTier)
    local unlockPity = tonumber(msg.UnlockPity) or 0
    local dexData = nil
    if msg.DexData and msg.DexData ~= "" then
      dexData = json.decode(msg.DexData)
    end

    local speciesPool = getSpeciesPoolForTier(tier, variantTier, dexData, unlockPity)

    if #speciesPool == 0 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "No species available for tier"
      })
      return
    end

    -- Roll species
    local speciesId = rollSpecies(tier, speciesPool, nil)
    local cost = speciesStarterCosts[speciesId] or 1

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      SpeciesId = tostring(speciesId),
      Tier = tostring(tier),
      StarterCost = tostring(cost)
    })
  end
)

--[[
  GetTierInfo Handler: Get tier metadata and configuration
]]
Handlers.add("get-tier-info",
  Handlers.utils.hasMatchingTag("Action", "GetTierInfo"),
  function(msg)
    local tiers = {
      [tostring(EggTier.COMMON)] = {
        name = "COMMON",
        threshold = GACHA_DEFAULT_COMMON_EGG_THRESHOLD,
        hatchWaves = HATCH_WAVES[EggTier.COMMON],
        pityThreshold = nil,
        probability = 204/256,
        starterCostRange = {1, 3}
      },
      [tostring(EggTier.RARE)] = {
        name = "RARE",
        threshold = GACHA_DEFAULT_RARE_EGG_THRESHOLD,
        hatchWaves = HATCH_WAVES[EggTier.RARE],
        pityThreshold = EGG_PITY_RARE_THRESHOLD,
        probability = 44/256,
        starterCostRange = {4, 5}
      },
      [tostring(EggTier.EPIC)] = {
        name = "EPIC",
        threshold = GACHA_DEFAULT_EPIC_EGG_THRESHOLD,
        hatchWaves = HATCH_WAVES[EggTier.EPIC],
        pityThreshold = EGG_PITY_EPIC_THRESHOLD,
        probability = 7/256,
        starterCostRange = {6, 7}
      },
      [tostring(EggTier.LEGENDARY)] = {
        name = "LEGENDARY",
        threshold = 0,
        hatchWaves = HATCH_WAVES[EggTier.LEGENDARY],
        pityThreshold = EGG_PITY_LEGENDARY_THRESHOLD,
        probability = 1/256,
        starterCostRange = {8, 9}
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({tiers = tiers})
    })
  end
)

--[[
  ValidateTierProgression Handler: Validate pity counters and progression
]]
Handlers.add("validate-tier-progression",
  Handlers.utils.hasMatchingTag("Action", "ValidateTierProgression"),
  function(msg)
    if not msg.EggPity or msg.EggPity == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "EggPity required"
      })
      return
    end

    local eggPity = json.decode(msg.EggPity)
    local pityStatus = {}

    for tierStr, count in pairs(eggPity) do
      local tier = tonumber(tierStr)
      local threshold = nil
      if tier == EggTier.RARE then
        threshold = EGG_PITY_RARE_THRESHOLD
      elseif tier == EggTier.EPIC then
        threshold = EGG_PITY_EPIC_THRESHOLD
      elseif tier == EggTier.LEGENDARY then
        threshold = EGG_PITY_LEGENDARY_THRESHOLD
      end

      if threshold then
        pityStatus[tierStr] = {
          current = count,
          threshold = threshold,
          nearThreshold = count >= (threshold - 5),
          willForce = count >= threshold
        }
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        valid = true,
        pityStatus = pityStatus
      })
    })
  end
)

--[[
  GetEggMoveIndex Handler: Calculate egg move slot with tier-specific rates
]]
Handlers.add("get-egg-move-index",
  Handlers.utils.hasMatchingTag("Action", "GetEggMoveIndex"),
  function(msg)
    local tier = tonumber(msg.Tier)
    if not tier or tier < 0 or tier > 3 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid Tier (0-3) required"
      })
      return
    end

    local sourceType = msg.SourceType or "GACHA_DEFAULT"
    local moveIndex = getEggMoveIndexForTier(tier, sourceType, nil)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      EggMoveIndex = tostring(moveIndex),
      IsRareMove = tostring(moveIndex == 3)
    })
  end
)

print("🥚 Egg Tier Reward Engine initialized")
print("✅ EggTier constants loaded")
print("✅ Species tables loaded: 569 species with tiers and costs")
print("✅ Handlers registered: Info, RollEggTier, GetSpeciesByTier, RollSpecies, GetTierInfo, ValidateTierProgression, GetEggMoveIndex")
print("📦 Process size: ~55KB / 500KB (11% utilization)")
print("🎯 ADP v1.0 compliant - use Action=Info for self-documentation")
