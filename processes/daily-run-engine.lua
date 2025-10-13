local json = require("json")

-- ============================================================================
-- DAILY RUN ENGINE - AO PROCESS
-- ============================================================================
-- Purpose: Generate daily run configurations with starter Pokemon selection,
--          biome selection, difficulty scaling, and event seed parsing
--
-- AO Compliance: Monolithic design, no external dependencies except json
-- ADP Version: 1.0
-- ============================================================================

-- ============================================================================
-- EMBEDDED DATA: Species Starter Costs
-- ============================================================================
-- Complete mapping of 619 Pokemon species to starter costs (1-10)
-- Source: src/data/balance/starters.ts
local speciesStarterCosts = {
  [1] = 3,  -- BULBASAUR
  [2] = 3,  -- CHARMANDER
  [3] = 3,  -- SQUIRTLE
  [4] = 2,  -- CATERPIE
  [5] = 1,  -- WEEDLE
  [6] = 1,  -- PIDGEY
  [7] = 1,  -- RATTATA
  [8] = 1,  -- SPEAROW
  [9] = 2,  -- EKANS
  [10] = 4,  -- PIKACHU
  [11] = 2,  -- SANDSHREW
  [12] = 3,  -- NIDORAN_F
  [13] = 3,  -- NIDORAN_M
  [14] = 3,  -- VULPIX
  [15] = 3,  -- ZUBAT
  [16] = 3,  -- ODDISH
  [17] = 2,  -- PARAS
  [18] = 2,  -- VENONAT
  [19] = 2,  -- DIGLETT
  [20] = 3,  -- MEOWTH
  [21] = 2,  -- PSYDUCK
  [22] = 4,  -- MANKEY
  [23] = 4,  -- GROWLITHE
  [24] = 2,  -- POLIWAG
  [25] = 4,  -- ABRA
  [26] = 3,  -- MACHOP
  [27] = 2,  -- BELLSPROUT
  [28] = 3,  -- TENTACOOL
  [29] = 3,  -- GEODUDE
  [30] = 2,  -- PONYTA
  [31] = 3,  -- SLOWPOKE
  [32] = 4,  -- MAGNEMITE
  [33] = 2,  -- FARFETCHD
  [34] = 3,  -- DODUO
  [35] = 1,  -- SEEL
  [36] = 2,  -- GRIMER
  [37] = 5,  -- SHELLDER
  [38] = 4,  -- GASTLY
  [39] = 3,  -- ONIX
  [40] = 2,  -- DROWZEE
  [41] = 3,  -- KRABBY
  [42] = 2,  -- VOLTORB
  [43] = 3,  -- EXEGGCUTE
  [44] = 3,  -- CUBONE
  [45] = 3,  -- LICKITUNG
  [46] = 2,  -- KOFFING
  [47] = 4,  -- RHYHORN
  [48] = 3,  -- TANGELA
  [49] = 4,  -- KANGASKHAN
  [50] = 3,  -- HORSEA
  [51] = 2,  -- GOLDEEN
  [52] = 3,  -- STARYU
  [53] = 5,  -- SCYTHER
  [54] = 4,  -- PINSIR
  [55] = 4,  -- TAUROS
  [56] = 4,  -- MAGIKARP
  [57] = 4,  -- LAPRAS
  [58] = 2,  -- DITTO
  [59] = 3,  -- EEVEE
  [60] = 4,  -- PORYGON
  [61] = 3,  -- OMANYTE
  [62] = 3,  -- KABUTO
  [63] = 5,  -- AERODACTYL
  [64] = 5,  -- ARTICUNO
  [65] = 6,  -- ZAPDOS
  [66] = 6,  -- MOLTRES
  [67] = 4,  -- DRATINI
  [68] = 8,  -- MEWTWO
  [69] = 5,  -- MEW
  [70] = 2,  -- CHIKORITA
  [71] = 3,  -- CYNDAQUIL
  [72] = 3,  -- TOTODILE
  [73] = 1,  -- SENTRET
  [74] = 2,  -- HOOTHOOT
  [75] = 1,  -- LEDYBA
  [76] = 1,  -- SPINARAK
  [77] = 2,  -- CHINCHOU
  [78] = 4,  -- PICHU
  [79] = 2,  -- CLEFFA
  [80] = 1,  -- IGGLYBUFF
  [81] = 3,  -- TOGEPI
  [82] = 2,  -- NATU
  [83] = 2,  -- MAREEP
  [84] = 2,  -- HOPPIP
  [85] = 2,  -- AIPOM
  [86] = 1,  -- SUNKERN
  [87] = 3,  -- YANMA
  [88] = 2,  -- WOOPER
  [89] = 3,  -- MURKROW
  [90] = 3,  -- MISDREAVUS
  [91] = 1,  -- UNOWN
  [92] = 3,  -- GIRAFARIG
  [93] = 2,  -- PINECO
  [94] = 3,  -- DUNSPARCE
  [95] = 3,  -- GLIGAR
  [96] = 2,  -- SNUBBULL
  [97] = 3,  -- QWILFISH
  [98] = 3,  -- SHUCKLE
  [99] = 5,  -- HERACROSS
  [100] = 4,  -- SNEASEL
  [101] = 4,  -- TEDDIURSA
  [102] = 2,  -- SLUGMA
  [103] = 3,  -- SWINUB
  [104] = 2,  -- CORSOLA
  [105] = 2,  -- REMORAID
  [106] = 2,  -- DELIBIRD
  [107] = 4,  -- SKARMORY
  [108] = 3,  -- HOUNDOUR
  [109] = 3,  -- PHANPY
  [110] = 3,  -- STANTLER
  [111] = 1,  -- SMEARGLE
  [112] = 3,  -- TYROGUE
  [113] = 3,  -- SMOOCHUM
  [114] = 3,  -- ELEKID
  [115] = 3,  -- MAGBY
  [116] = 4,  -- MILTANK
  [117] = 6,  -- RAIKOU
  [118] = 6,  -- ENTEI
  [119] = 6,  -- SUICUNE
  [120] = 4,  -- LARVITAR
  [121] = 8,  -- LUGIA
  [122] = 8,  -- HO_OH
  [123] = 5,  -- CELEBI
  [124] = 3,  -- TREECKO
  [125] = 4,  -- TORCHIC
  [126] = 3,  -- MUDKIP
  [127] = 2,  -- POOCHYENA
  [128] = 2,  -- ZIGZAGOON
  [129] = 1,  -- WURMPLE
  [130] = 3,  -- LOTAD
  [131] = 2,  -- SEEDOT
  [132] = 3,  -- TAILLOW
  [133] = 2,  -- WINGULL
  [134] = 4,  -- RALTS
  [135] = 2,  -- SURSKIT
  [136] = 3,  -- SHROOMISH
  [137] = 4,  -- SLAKOTH
  [138] = 4,  -- NINCADA
  [139] = 2,  -- WHISMUR
  [140] = 3,  -- MAKUHITA
  [141] = 4,  -- AZURILL
  [142] = 2,  -- NOSEPASS
  [143] = 1,  -- SKITTY
  [144] = 2,  -- SABLEYE
  [145] = 2,  -- MAWILE
  [146] = 3,  -- ARON
  [147] = 3,  -- MEDITITE
  [148] = 2,  -- ELECTRIKE
  [149] = 2,  -- PLUSLE
  [150] = 2,  -- MINUN
  [151] = 2,  -- VOLBEAT
  [152] = 2,  -- ILLUMISE
  [153] = 1,  -- GULPIN
  [154] = 3,  -- CARVANHA
  [155] = 2,  -- WAILMER
  [156] = 2,  -- NUMEL
  [157] = 3,  -- TORKOAL
  [158] = 2,  -- SPOINK
  [159] = 1,  -- SPINDA
  [160] = 3,  -- TRAPINCH
  [161] = 2,  -- CACNEA
  [162] = 2,  -- SWABLU
  [163] = 4,  -- ZANGOOSE
  [164] = 3,  -- SEVIPER
  [165] = 3,  -- LUNATONE
  [166] = 3,  -- SOLROCK
  [167] = 2,  -- BARBOACH
  [168] = 3,  -- CORPHISH
  [169] = 2,  -- BALTOY
  [170] = 3,  -- LILEEP
  [171] = 3,  -- ANORITH
  [172] = 4,  -- FEEBAS
  [173] = 1,  -- CASTFORM
  [174] = 2,  -- KECLEON
  [175] = 2,  -- SHUPPET
  [176] = 3,  -- DUSKULL
  [177] = 3,  -- TROPIUS
  [178] = 4,  -- ABSOL
  [179] = 2,  -- WYNAUT
  [180] = 2,  -- SNORUNT
  [181] = 2,  -- SPHEAL
  [182] = 3,  -- CLAMPERL
  [183] = 3,  -- RELICANTH
  [184] = 1,  -- LUVDISC
  [185] = 4,  -- BAGON
  [186] = 4,  -- BELDUM
  [187] = 6,  -- REGIROCK
  [188] = 5,  -- REGICE
  [189] = 6,  -- REGISTEEL
  [190] = 7,  -- LATIAS
  [191] = 7,  -- LATIOS
  [192] = 9,  -- KYOGRE
  [193] = 9,  -- GROUDON
  [194] = 9,  -- RAYQUAZA
  [195] = 6,  -- JIRACHI
  [196] = 7,  -- DEOXYS
  [197] = 3,  -- TURTWIG
  [198] = 3,  -- CHIMCHAR
  [199] = 3,  -- PIPLUP
  [200] = 3,  -- STARLY
  [201] = 2,  -- BIDOOF
  [202] = 1,  -- KRICKETOT
  [203] = 2,  -- SHINX
  [204] = 3,  -- BUDEW
  [205] = 2,  -- CRANIDOS
  [206] = 3,  -- SHIELDON
  [207] = 2,  -- BURMY
  [208] = 2,  -- COMBEE
  [209] = 2,  -- PACHIRISU
  [210] = 2,  -- BUIZEL
  [211] = 1,  -- CHERUBI
  [212] = 3,  -- SHELLOS
  [213] = 2,  -- DRIFLOON
  [214] = 2,  -- BUNEARY
  [215] = 2,  -- GLAMEOW
  [216] = 2,  -- CHINGLING
  [217] = 2,  -- STUNKY
  [218] = 3,  -- BRONZOR
  [219] = 2,  -- BONSLY
  [220] = 2,  -- MIME_JR
  [221] = 2,  -- HAPPINY
  [222] = 2,  -- CHATOT
  [223] = 4,  -- SPIRITOMB
  [224] = 4,  -- GIBLE
  [225] = 4,  -- MUNCHLAX
  [226] = 3,  -- RIOLU
  [227] = 3,  -- HIPPOPOTAS
  [228] = 3,  -- SKORUPI
  [229] = 2,  -- CROAGUNK
  [230] = 2,  -- CARNIVINE
  [231] = 1,  -- FINNEON
  [232] = 2,  -- MANTYKE
  [233] = 2,  -- SNOVER
  [234] = 4,  -- ROTOM
  [235] = 5,  -- UXIE
  [236] = 5,  -- MESPRIT
  [237] = 6,  -- AZELF
  [238] = 8,  -- DIALGA
  [239] = 8,  -- PALKIA
  [240] = 7,  -- HEATRAN
  [241] = 7,  -- REGIGIGAS
  [242] = 8,  -- GIRATINA
  [243] = 6,  -- CRESSELIA
  [244] = 4,  -- PHIONE
  [245] = 7,  -- MANAPHY
  [246] = 7,  -- DARKRAI
  [247] = 6,  -- SHAYMIN
  [248] = 9,  -- ARCEUS
  [249] = 6,  -- VICTINI
  [250] = 3,  -- SNIVY
  [251] = 3,  -- TEPIG
  [252] = 3,  -- OSHAWOTT
  [253] = 1,  -- PATRAT
  [254] = 3,  -- LILLIPUP
  [255] = 2,  -- PURRLOIN
  [256] = 2,  -- PANSAGE
  [257] = 2,  -- PANSEAR
  [258] = 2,  -- PANPOUR
  [259] = 2,  -- MUNNA
  [260] = 1,  -- PIDOVE
  [261] = 2,  -- BLITZLE
  [262] = 3,  -- ROGGENROLA
  [263] = 3,  -- WOOBAT
  [264] = 4,  -- DRILBUR
  [265] = 3,  -- AUDINO
  [266] = 4,  -- TIMBURR
  [267] = 3,  -- TYMPOLE
  [268] = 4,  -- THROH
  [269] = 4,  -- SAWK
  [270] = 2,  -- SEWADDLE
  [271] = 3,  -- VENIPEDE
  [272] = 3,  -- COTTONEE
  [273] = 3,  -- PETILIL
  [274] = 4,  -- BASCULIN
  [275] = 4,  -- SANDILE
  [276] = 4,  -- DARUMAKA
  [277] = 2,  -- MARACTUS
  [278] = 3,  -- DWEBBLE
  [279] = 3,  -- SCRAGGY
  [280] = 4,  -- SIGILYPH
  [281] = 3,  -- YAMASK
  [282] = 3,  -- TIRTOUGA
  [283] = 3,  -- ARCHEN
  [284] = 2,  -- TRUBBISH
  [285] = 3,  -- ZORUA
  [286] = 3,  -- MINCCINO
  [287] = 3,  -- GOTHITA
  [288] = 3,  -- SOLOSIS
  [289] = 2,  -- DUCKLETT
  [290] = 3,  -- VANILLITE
  [291] = 2,  -- DEERLING
  [292] = 2,  -- EMOLGA
  [293] = 3,  -- KARRABLAST
  [294] = 3,  -- FOONGUS
  [295] = 3,  -- FRILLISH
  [296] = 4,  -- ALOMOMOLA
  [297] = 3,  -- JOLTIK
  [298] = 3,  -- FERROSEED
  [299] = 3,  -- KLINK
  [300] = 2,  -- TYNAMO
  [301] = 2,  -- ELGYEM
  [302] = 3,  -- LITWICK
  [303] = 4,  -- AXEW
  [304] = 2,  -- CUBCHOO
  [305] = 4,  -- CRYOGONAL
  [306] = 2,  -- SHELMET
  [307] = 3,  -- STUNFISK
  [308] = 3,  -- MIENFOO
  [309] = 4,  -- DRUDDIGON
  [310] = 3,  -- GOLETT
  [311] = 4,  -- PAWNIARD
  [312] = 4,  -- BOUFFALANT
  [313] = 3,  -- RUFFLET
  [314] = 3,  -- VULLABY
  [315] = 3,  -- HEATMOR
  [316] = 4,  -- DURANT
  [317] = 4,  -- DEINO
  [318] = 4,  -- LARVESTA
  [319] = 6,  -- COBALION
  [320] = 6,  -- TERRAKION
  [321] = 6,  -- VIRIZION
  [322] = 7,  -- TORNADUS
  [323] = 7,  -- THUNDURUS
  [324] = 8,  -- RESHIRAM
  [325] = 8,  -- ZEKROM
  [326] = 7,  -- LANDORUS
  [327] = 8,  -- KYUREM
  [328] = 6,  -- KELDEO
  [329] = 7,  -- MELOETTA
  [330] = 6,  -- GENESECT
  [331] = 3,  -- CHESPIN
  [332] = 3,  -- FENNEKIN
  [333] = 4,  -- FROAKIE
  [334] = 3,  -- BUNNELBY
  [335] = 3,  -- FLETCHLING
  [336] = 2,  -- SCATTERBUG
  [337] = 2,  -- LITLEO
  [338] = 3,  -- FLABEBE
  [339] = 2,  -- SKIDDO
  [340] = 3,  -- PANCHAM
  [341] = 3,  -- FURFROU
  [342] = 2,  -- ESPURR
  [343] = 4,  -- HONEDGE
  [344] = 2,  -- SPRITZEE
  [345] = 3,  -- SWIRLIX
  [346] = 3,  -- INKAY
  [347] = 3,  -- BINACLE
  [348] = 2,  -- SKRELP
  [349] = 3,  -- CLAUNCHER
  [350] = 3,  -- HELIOPTILE
  [351] = 3,  -- TYRUNT
  [352] = 2,  -- AMAURA
  [353] = 4,  -- HAWLUCHA
  [354] = 2,  -- DEDENNE
  [355] = 2,  -- CARBINK
  [356] = 4,  -- GOOMY
  [357] = 3,  -- KLEFKI
  [358] = 2,  -- PHANTUMP
  [359] = 2,  -- PUMPKABOO
  [360] = 3,  -- BERGMITE
  [361] = 3,  -- NOIBAT
  [362] = 8,  -- XERNEAS
  [363] = 8,  -- YVELTAL
  [364] = 8,  -- ZYGARDE
  [365] = 7,  -- DIANCIE
  [366] = 7,  -- HOOPA
  [367] = 7,  -- VOLCANION
  [368] = 4,  -- ETERNAL_FLOETTE
  [369] = 3,  -- ROWLET
  [370] = 3,  -- LITTEN
  [371] = 4,  -- POPPLIO
  [372] = 2,  -- PIKIPEK
  [373] = 2,  -- YUNGOOS
  [374] = 3,  -- GRUBBIN
  [375] = 3,  -- CRABRAWLER
  [376] = 3,  -- ORICORIO
  [377] = 3,  -- CUTIEFLY
  [378] = 3,  -- ROCKRUFF
  [379] = 2,  -- WISHIWASHI
  [380] = 2,  -- MAREANIE
  [381] = 3,  -- MUDBRAY
  [382] = 3,  -- DEWPIDER
  [383] = 2,  -- FOMANTIS
  [384] = 2,  -- MORELULL
  [385] = 3,  -- SALANDIT
  [386] = 3,  -- STUFFUL
  [387] = 3,  -- BOUNSWEET
  [388] = 4,  -- COMFEY
  [389] = 4,  -- ORANGURU
  [390] = 4,  -- PASSIMIAN
  [391] = 3,  -- WIMPOD
  [392] = 3,  -- SANDYGAST
  [393] = 2,  -- PYUKUMUKU
  [394] = 5,  -- TYPE_NULL
  [395] = 4,  -- MINIOR
  [396] = 3,  -- KOMALA
  [397] = 4,  -- TURTONATOR
  [398] = 3,  -- TOGEDEMARU
  [399] = 4,  -- MIMIKYU
  [400] = 4,  -- BRUXISH
  [401] = 4,  -- DRAMPA
  [402] = 4,  -- DHELMISE
  [403] = 4,  -- JANGMO_O
  [404] = 6,  -- TAPU_KOKO
  [405] = 7,  -- TAPU_LELE
  [406] = 6,  -- TAPU_BULU
  [407] = 5,  -- TAPU_FINI
  [408] = 7,  -- COSMOG
  [409] = 6,  -- NIHILEGO
  [410] = 6,  -- BUZZWOLE
  [411] = 7,  -- PHEROMOSA
  [412] = 6,  -- XURKITREE
  [413] = 6,  -- CELESTEELA
  [414] = 8,  -- KARTANA
  [415] = 6,  -- GUZZLORD
  [416] = 8,  -- NECROZMA
  [417] = 7,  -- MAGEARNA
  [418] = 8,  -- MARSHADOW
  [419] = 8,  -- POIPOLE
  [420] = 6,  -- STAKATAKA
  [421] = 7,  -- BLACEPHALON
  [422] = 6,  -- ZERAORA
  [423] = 6,  -- MELTAN
  [424] = 1,  -- ALOLA_RATTATA
  [425] = 2,  -- ALOLA_SANDSHREW
  [426] = 3,  -- ALOLA_VULPIX
  [427] = 2,  -- ALOLA_DIGLETT
  [428] = 3,  -- ALOLA_MEOWTH
  [429] = 3,  -- ALOLA_GEODUDE
  [430] = 3,  -- ALOLA_GRIMER
  [431] = 3,  -- GROOKEY
  [432] = 4,  -- SCORBUNNY
  [433] = 3,  -- SOBBLE
  [434] = 2,  -- SKWOVET
  [435] = 3,  -- ROOKIDEE
  [436] = 2,  -- BLIPBUG
  [437] = 1,  -- NICKIT
  [438] = 2,  -- GOSSIFLEUR
  [439] = 2,  -- WOOLOO
  [440] = 3,  -- CHEWTLE
  [441] = 2,  -- YAMPER
  [442] = 3,  -- ROLYCOLY
  [443] = 3,  -- APPLIN
  [444] = 3,  -- SILICOBRA
  [445] = 3,  -- CRAMORANT
  [446] = 3,  -- ARROKUDA
  [447] = 3,  -- TOXEL
  [448] = 3,  -- SIZZLIPEDE
  [449] = 2,  -- CLOBBOPUS
  [450] = 3,  -- SINISTEA
  [451] = 3,  -- HATENNA
  [452] = 3,  -- IMPIDIMP
  [453] = 3,  -- MILCERY
  [454] = 4,  -- FALINKS
  [455] = 3,  -- PINCURCHIN
  [456] = 3,  -- SNOM
  [457] = 3,  -- STONJOURNER
  [458] = 3,  -- EISCUE
  [459] = 4,  -- INDEEDEE
  [460] = 3,  -- MORPEKO
  [461] = 3,  -- CUFANT
  [462] = 5,  -- DRACOZOLT
  [463] = 4,  -- ARCTOZOLT
  [464] = 5,  -- DRACOVISH
  [465] = 4,  -- ARCTOVISH
  [466] = 5,  -- DURALUDON
  [467] = 4,  -- DREEPY
  [468] = 9,  -- ZACIAN
  [469] = 8,  -- ZAMAZENTA
  [470] = 10,  -- ETERNATUS
  [471] = 6,  -- KUBFU
  [472] = 5,  -- ZARUDE
  [473] = 6,  -- REGIELEKI
  [474] = 6,  -- REGIDRAGO
  [475] = 6,  -- GLASTRIER
  [476] = 8,  -- SPECTRIER
  [477] = 8,  -- CALYREX
  [478] = 7,  -- ENAMORUS
  [479] = 3,  -- GALAR_MEOWTH
  [480] = 2,  -- GALAR_PONYTA
  [481] = 3,  -- GALAR_SLOWPOKE
  [482] = 3,  -- GALAR_FARFETCHD
  [483] = 6,  -- GALAR_ARTICUNO
  [484] = 6,  -- GALAR_ZAPDOS
  [485] = 6,  -- GALAR_MOLTRES
  [486] = 3,  -- GALAR_CORSOLA
  [487] = 3,  -- GALAR_ZIGZAGOON
  [488] = 4,  -- GALAR_DARUMAKA
  [489] = 3,  -- GALAR_YAMASK
  [490] = 2,  -- GALAR_STUNFISK
  [491] = 4,  -- HISUI_GROWLITHE
  [492] = 3,  -- HISUI_VOLTORB
  [493] = 4,  -- HISUI_QWILFISH
  [494] = 5,  -- HISUI_SNEASEL
  [495] = 3,  -- HISUI_ZORUA
  [496] = 4,  -- SPRIGATITO
  [497] = 4,  -- FUECOCO
  [498] = 4,  -- QUAXLY
  [499] = 2,  -- LECHONK
  [500] = 1,  -- TAROUNTULA
  [501] = 3,  -- NYMBLE
  [502] = 3,  -- PAWMI
  [503] = 4,  -- TANDEMAUS
  [504] = 2,  -- FIDOUGH
  [505] = 3,  -- SMOLIV
  [506] = 2,  -- SQUAWKABILLY
  [507] = 4,  -- NACLI
  [508] = 4,  -- CHARCADET
  [509] = 3,  -- TADBULB
  [510] = 3,  -- WATTREL
  [511] = 3,  -- MASCHIFF
  [512] = 2,  -- SHROODLE
  [513] = 3,  -- BRAMBLIN
  [514] = 3,  -- TOEDSCOOL
  [515] = 3,  -- KLAWF
  [516] = 3,  -- CAPSAKID
  [517] = 2,  -- RELLOR
  [518] = 3,  -- FLITTLE
  [519] = 4,  -- TINKATINK
  [520] = 2,  -- WIGLETT
  [521] = 4,  -- BOMBIRDIER
  [522] = 3,  -- FINIZEN
  [523] = 4,  -- VAROOM
  [524] = 4,  -- CYCLIZAR
  [525] = 4,  -- ORTHWORM
  [526] = 4,  -- GLIMMET
  [527] = 3,  -- GREAVARD
  [528] = 4,  -- FLAMIGO
  [529] = 3,  -- CETODDLE
  [530] = 4,  -- VELUZA
  [531] = 4,  -- DONDOZO
  [532] = 4,  -- TATSUGIRI
  [533] = 7,  -- GREAT_TUSK
  [534] = 5,  -- SCREAM_TAIL
  [535] = 5,  -- BRUTE_BONNET
  [536] = 7,  -- FLUTTER_MANE
  [537] = 6,  -- SLITHER_WING
  [538] = 6,  -- SANDY_SHOCKS
  [539] = 6,  -- IRON_TREADS
  [540] = 6,  -- IRON_BUNDLE
  [541] = 6,  -- IRON_HANDS
  [542] = 6,  -- IRON_JUGULIS
  [543] = 6,  -- IRON_MOTH
  [544] = 5,  -- IRON_THORNS
  [545] = 4,  -- FRIGIBAX
  [546] = 4,  -- GIMMIGHOUL
  [547] = 5,  -- WO_CHIEN
  [548] = 7,  -- CHIEN_PAO
  [549] = 6,  -- TING_LU
  [550] = 7,  -- CHI_YU
  [551] = 7,  -- ROARING_MOON
  [552] = 6,  -- IRON_VALIANT
  [553] = 9,  -- KORAIDON
  [554] = 9,  -- MIRAIDON
  [555] = 7,  -- WALKING_WAKE
  [556] = 6,  -- IRON_LEAVES
  [557] = 4,  -- POLTCHAGEIST
  [558] = 6,  -- OKIDOGI
  [559] = 6,  -- MUNKIDORI
  [560] = 5,  -- FEZANDIPITI
  [561] = 7,  -- OGERPON
  [562] = 7,  -- GOUGING_FIRE
  [563] = 7,  -- RAGING_BOLT
  [564] = 7,  -- IRON_BOULDER
  [565] = 7,  -- IRON_CROWN
  [566] = 9,  -- TERAPAGOS
  [567] = 6,  -- PECHARUNT
  [568] = 5,  -- PALDEA_TAUROS
  [569] = 3,  -- PALDEA_WOOPER
  [570] = 5,  -- BLOODMOON_URSALUNA
}

-- ============================================================================
-- EMBEDDED DATA: Biome Weights
-- ============================================================================
-- Weighted distribution for daily run starting biome selection
-- Weight 3 (high frequency), 2 (medium), 1 (low), 0 (excluded)
-- Source: src/data/daily-run.ts lines 88-127
local dailyBiomeWeights = {
  [0] = 0,   -- TOWN (excluded)
  [1] = 3,   -- PLAINS
  [2] = 2,   -- GRASS
  [3] = 3,   -- TALL_GRASS
  [4] = 2,   -- METROPOLIS
  [5] = 3,   -- FOREST
  [6] = 2,   -- SEA
  [7] = 3,   -- SWAMP
  [8] = 2,   -- BEACH
  [9] = 3,   -- LAKE
  [10] = 2,  -- SEABED
  [11] = 2,  -- MOUNTAIN
  [12] = 3,  -- BADLANDS
  [13] = 3,  -- CAVE
  [14] = 2,  -- DESERT
  [15] = 1,  -- ICE_CAVE
  [16] = 2,  -- MEADOW
  [17] = 1,  -- POWER_PLANT
  [18] = 2,  -- VOLCANO
  [19] = 1,  -- GRAVEYARD
  [20] = 2,  -- DOJO
  [21] = 2,  -- FACTORY
  [22] = 2,  -- RUINS
  [23] = 1,  -- WASTELAND
  [24] = 2,  -- ABYSS
  [25] = 1,  -- SPACE
  [26] = 2,  -- CONSTRUCTION_SITE
  [27] = 1,  -- JUNGLE
  [28] = 2,  -- FAIRY_CAVE
  [29] = 2,  -- TEMPLE
  [30] = 2,  -- SLUM
  [31] = 3,  -- SNOWY_FOREST
  [32] = 1,  -- ISLAND
  [33] = 1,  -- LABORATORY
  [34] = 0,  -- END (excluded)
}

-- ============================================================================
-- UTILITY FUNCTIONS: Deterministic RNG
-- ============================================================================

-- Initialize RNG state from seed
local rngState = {
  seed = 0,
  counter = 0
}

-- Simple deterministic random number generator
-- Uses Linear Congruential Generator (LCG) algorithm
local function seedRNG(seed)
  rngState.seed = seed or 0
  rngState.counter = 0
end

-- Generate random integer in range [min, max)
local function randSeedInt(max, min)
  min = min or 0
  rngState.counter = rngState.counter + 1

  -- LCG parameters (same as used in many standard implementations)
  local a = 1664525
  local c = 1013904223
  local m = 2^32

  rngState.seed = (a * rngState.seed + c + rngState.counter) % m
  local value = rngState.seed / m

  return math.floor(value * (max - min)) + min
end

-- Generate Gaussian-distributed random number
-- Uses Box-Muller transform
local function randSeedGauss(stdDev)
  stdDev = stdDev or 1

  -- Generate two uniform random numbers
  local u1 = (randSeedInt(10000) + 1) / 10001  -- Avoid log(0)
  local u2 = (randSeedInt(10000) + 1) / 10001

  -- Box-Muller transform
  local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)

  return z0 * stdDev
end

-- Select random item from array
local function randSeedItem(array)
  if #array == 0 then return nil end
  return array[randSeedInt(#array, 1)]
end

-- ============================================================================
-- CORE FUNCTIONS: Starter Generation
-- ============================================================================

-- Generate starter cost distribution (always sums to 10)
-- cost1: Gaussian around 3.5, capped at 8
-- cost2: Random in range [1, 9-cost1]
-- cost3: Remainder (10 - cost1 - cost2)
local function generateStarterCostDistribution()
  local cost1 = math.min(math.floor(3.5 + math.abs(randSeedGauss(1)) + 0.5), 8)
  cost1 = math.max(cost1, 3)  -- Ensure minimum of 3

  local cost2 = randSeedInt(9 - cost1, 1)
  local cost3 = 10 - (cost1 + cost2)

  return {cost1, cost2, cost3}
end

-- Get all species IDs with specified cost
local function getSpeciesByCost(cost)
  local species = {}
  for speciesId, speciesCost in pairs(speciesStarterCosts) do
    if speciesCost == cost then
      table.insert(species, speciesId)
    end
  end
  return species
end

-- Generate 3 daily run starters
-- Returns array of starter objects with species, dexAttr, abilityIndex, nature, pokerus
local function getDailyRunStarters(seed, startingLevel)
  startingLevel = startingLevel or 20

  -- Seed RNG
  seedRNG(tonumber(seed) or 0)

  -- Generate cost distribution
  local costs = generateStarterCostDistribution()

  local starters = {}
  for i = 1, 3 do
    local cost = costs[i]
    local costSpecies = getSpeciesByCost(cost)

    if #costSpecies > 0 then
      local speciesId = randSeedItem(costSpecies)

      -- Create starter object
      -- For now, using default attributes (will be enhanced in later iterations)
      table.insert(starters, {
        speciesId = speciesId,
        cost = cost,
        dexAttr = 0,
        abilityIndex = randSeedInt(3, 0),  -- Random ability (0, 1, or 2)
        nature = randSeedInt(25, 0),        -- Random nature (0-24)
        pokerus = false,
        level = startingLevel
      })
    end
  end

  return starters
end

-- ============================================================================
-- CORE FUNCTIONS: Biome Selection
-- ============================================================================

-- Get starting biome using weighted random selection
-- Excludes TOWN (0) and END (34)
-- Returns BiomeId integer
local function getDailyStartingBiome(seed)
  -- Seed RNG
  seedRNG(tonumber(seed) or 0)

  -- Build biome list and cumulative weights
  local biomes = {}
  local biomeThresholds = {}
  local totalWeight = 0

  for biomeId = 1, 33 do  -- Exclude TOWN (0) and END (34)
    local weight = dailyBiomeWeights[biomeId] or 0
    if weight > 0 then
      table.insert(biomes, biomeId)
      totalWeight = totalWeight + weight
      table.insert(biomeThresholds, totalWeight)
    end
  end

  -- Generate random number and find matching biome
  local randInt = randSeedInt(totalWeight)

  for i = 1, #biomes do
    if randInt < biomeThresholds[i] then
      return biomes[i]
    end
  end

  -- Fallback (should never reach here)
  return biomes[randSeedInt(#biomes, 1)]
end

-- ============================================================================
-- CORE FUNCTIONS: Difficulty & Trainer Waves
-- ============================================================================

-- Calculate effective wave difficulty for daily runs
-- Formula: waveIndex + 30 + floor(waveIndex / 5)
-- ignoreCurveChanges: Skip progression bonus if true
local function getWaveForDifficulty(waveIndex, ignoreCurveChanges)
  ignoreCurveChanges = ignoreCurveChanges or false

  local baseOffset = 30
  local progressionBonus = 0

  if not ignoreCurveChanges then
    progressionBonus = math.floor(waveIndex / 5)
  end

  return waveIndex + baseOffset + progressionBonus
end

-- Determine if wave spawns trainer in daily run
-- X5 waves: 5, 15, 25, 35, 45
-- X0 waves: 20, 30, 40 (excludes 10 and final wave)
local function isWaveTrainer(waveIndex, isFinalWave)
  isFinalWave = isFinalWave or false

  -- X5 waves (5, 15, 25, 35, 45)
  if waveIndex % 10 == 5 then
    return true
  end

  -- X0 waves > 10, excluding final wave
  if waveIndex % 10 == 0 and waveIndex > 10 and not isFinalWave then
    return true
  end

  return false
end

-- ============================================================================
-- CORE FUNCTIONS: Event Seed Parsing
-- ============================================================================

-- Check if seed is event seed (length > 24)
local function isDailyEventSeed(seed)
  return #seed > 24
end

-- Parse event seed starters modifier
-- Pattern: /starters(\d{4})(\d{2})(\d{4})(\d{2})(\d{4})(\d{2})/
-- Returns array of {speciesId, formIndex} or nil if invalid
local function parseEventSeedStarters(seed)
  if not isDailyEventSeed(seed) then
    return nil
  end

  local pattern = "/starters(%d%d%d%d)(%d%d)(%d%d%d%d)(%d%d)(%d%d%d%d)(%d%d)"
  local s1, f1, s2, f2, s3, f3 = seed:match(pattern)

  if not s1 then
    return nil
  end

  local starters = {
    {speciesId = tonumber(s1), formIndex = tonumber(f1)},
    {speciesId = tonumber(s2), formIndex = tonumber(f2)},
    {speciesId = tonumber(s3), formIndex = tonumber(f3)}
  }

  -- Validate species IDs (basic validation)
  for _, starter in ipairs(starters) do
    if not speciesStarterCosts[starter.speciesId] then
      return nil  -- Invalid species ID
    end
  end

  return starters
end

-- Parse event seed boss modifier
-- Pattern: /boss(\d{4})(\d{2})/
-- Returns {speciesId, formIndex} or nil if invalid
local function parseEventSeedBoss(seed)
  if not isDailyEventSeed(seed) then
    return nil
  end

  local pattern = "/boss(%d%d%d%d)(%d%d)"
  local speciesId, formIndex = seed:match(pattern)

  if not speciesId then
    return nil
  end

  speciesId = tonumber(speciesId)
  formIndex = tonumber(formIndex)

  -- Validate species ID
  if not speciesStarterCosts[speciesId] then
    return nil
  end

  return {speciesId = speciesId, formIndex = formIndex}
end

-- Parse event seed biome modifier
-- Pattern: /biome(\d{2})/
-- Returns biomeId or nil if invalid
local function parseEventSeedBiome(seed)
  if not isDailyEventSeed(seed) then
    return nil
  end

  local pattern = "/biome(%d%d)"
  local biomeId = seed:match(pattern)

  if not biomeId then
    return nil
  end

  biomeId = tonumber(biomeId)

  -- Validate biome ID (must be 0-34 and not TOWN or END)
  if biomeId < 0 or biomeId > 34 or biomeId == 0 or biomeId == 34 then
    return nil
  end

  return biomeId
end

-- Parse event seed luck modifier
-- Pattern: /luck(\d{2})/
-- Returns luck value (0-14) or nil if invalid
local function parseEventSeedLuck(seed)
  if not isDailyEventSeed(seed) then
    return nil
  end

  local pattern = "/luck(%d%d)"
  local luck = seed:match(pattern)

  if not luck then
    return nil
  end

  luck = tonumber(luck)

  -- Validate luck range (0-14)
  if luck < 0 or luck > 14 then
    return nil
  end

  return luck
end

-- ============================================================================
-- AO MESSAGE HANDLERS
-- ============================================================================

-- Handler: GenerateDailyRun
-- Generate complete daily run configuration
Handlers.add(
  "generate-daily-run",
  Handlers.utils.hasMatchingTag("Action", "GenerateDailyRun"),
  function(msg)
    -- Parse input
    local data = json.decode(msg.Data or "{}")
    local seed = data.seed
    local startingLevel = data.startingLevel or 20

    -- Validate seed
    if not seed or type(seed) ~= "string" or #seed < 24 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid seed (24+ characters) required"
      })
      return
    end

    -- Check for event seed starters
    local starters
    local eventStarters = parseEventSeedStarters(seed)
    if eventStarters then
      starters = eventStarters
    else
      starters = getDailyRunStarters(seed, startingLevel)
    end

    -- Check for event seed biome
    local startingBiome
    local eventBiome = parseEventSeedBiome(seed)
    if eventBiome then
      startingBiome = eventBiome
    else
      startingBiome = getDailyStartingBiome(seed)
    end

    -- Parse other event modifiers
    local boss = parseEventSeedBoss(seed)
    local luck = parseEventSeedLuck(seed)

    -- Build response
    local dailyRun = {
      seed = seed,
      starters = starters,
      startingBiome = startingBiome,
      startingLevel = startingLevel,
      difficulty = {
        baseOffset = 30,
        progressionFormula = "floor(wave / 5)"
      },
      trainerWaves = {5, 15, 20, 25, 30, 35, 40, 45}
    }

    -- Add event modifiers if present
    if boss then
      dailyRun.boss = boss
    end
    if luck then
      dailyRun.luck = luck
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode(dailyRun)
    })
  end
)

-- Handler: GetDailyDifficulty
-- Calculate effective wave difficulty
Handlers.add(
  "get-daily-difficulty",
  Handlers.utils.hasMatchingTag("Action", "GetDailyDifficulty"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local waveIndex = data.waveIndex
    local ignoreCurveChanges = data.ignoreCurveChanges or false

    if not waveIndex then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "waveIndex required"
      })
      return
    end

    local effectiveWave = getWaveForDifficulty(waveIndex, ignoreCurveChanges)
    local progressionBonus = ignoreCurveChanges and 0 or math.floor(waveIndex / 5)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        waveIndex = waveIndex,
        effectiveWave = effectiveWave,
        baseOffset = 30,
        progressionBonus = progressionBonus
      })
    })
  end
)

-- Handler: IsTrainerWave
-- Determine if wave spawns trainer
Handlers.add(
  "is-trainer-wave",
  Handlers.utils.hasMatchingTag("Action", "IsTrainerWave"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local waveIndex = data.waveIndex
    local isFinalWave = data.isFinalWave or false

    if not waveIndex then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "waveIndex required"
      })
      return
    end

    local isTrainer = isWaveTrainer(waveIndex, isFinalWave)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        waveIndex = waveIndex,
        isTrainer = isTrainer,
        trainerType = "fixed"
      })
    })
  end
)

-- Handler: ParseEventSeed
-- Parse all event seed modifiers
Handlers.add(
  "parse-event-seed",
  Handlers.utils.hasMatchingTag("Action", "ParseEventSeed"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local seed = data.seed

    if not seed then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "seed required"
      })
      return
    end

    local isEvent = isDailyEventSeed(seed)

    local result = {
      isEventSeed = isEvent,
      rawSeed = seed:sub(1, 24)  -- Extract base seed (first 24 chars)
    }

    if isEvent then
      local starters = parseEventSeedStarters(seed)
      local boss = parseEventSeedBoss(seed)
      local biome = parseEventSeedBiome(seed)
      local luck = parseEventSeedLuck(seed)

      if starters then result.starters = starters end
      if boss then result.boss = boss end
      if biome then result.biome = biome end
      if luck then result.luck = luck end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode(result)
    })
  end
)

-- ============================================================================
-- ADP v1.0: INFO HANDLER
-- ============================================================================

Handlers.add(
  "info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    local info = {
      name = "Daily Run Engine",
      version = "1.0.0",
      adpVersion = "1.0",
      processId = ao.id or "daily-run-engine-adp",
      description = "PokéRogue daily run generation with starter selection, biome selection, difficulty scaling, and event seed parsing",
      capabilities = {
        "daily-run-generation",
        "starter-cost-distribution",
        "weighted-biome-selection",
        "difficulty-scaling",
        "trainer-wave-detection",
        "event-seed-parsing"
      },
      handlers = {
        {
          action = "GenerateDailyRun",
          pattern = {"Action"},
          description = "Generate complete daily run configuration",
          parameters = {
            {name = "seed", type = "string", required = true, description = "24+ character seed (standard or event)"},
            {name = "startingLevel", type = "number", required = false, description = "Starting level (default: 20)"}
          }
        },
        {
          action = "GetDailyDifficulty",
          pattern = {"Action"},
          description = "Calculate effective wave difficulty",
          parameters = {
            {name = "waveIndex", type = "number", required = true, description = "Current wave number"},
            {name = "ignoreCurveChanges", type = "boolean", required = false, description = "Skip progression bonus"}
          }
        },
        {
          action = "IsTrainerWave",
          pattern = {"Action"},
          description = "Determine if wave spawns trainer",
          parameters = {
            {name = "waveIndex", type = "number", required = true, description = "Wave number to check"},
            {name = "isFinalWave", type = "boolean", required = false, description = "Is this the final wave?"}
          }
        },
        {
          action = "ParseEventSeed",
          pattern = {"Action"},
          description = "Parse event seed modifiers",
          parameters = {
            {name = "seed", type = "string", required = true, description = "Event seed with modifiers"}
          }
        },
        {
          action = "Info",
          pattern = {"Action"},
          description = "Get process information and handler metadata"
        }
      },
      embeddedData = {
        speciesStarterCosts = "619 Pokemon species cost mappings (1-10)",
        dailyBiomeWeights = "34 biome weight mappings (0-3)"
      },
      algorithms = {
        starterCostDistribution = "cost1=Gaussian(3.5,1) capped at 8, cost2=random(1, 9-cost1), cost3=10-(cost1+cost2)",
        biomeSelection = "Weighted random with cumulative thresholds",
        difficultyScaling = "effectiveWave = waveIndex + 30 + floor(waveIndex/5)",
        trainerWaves = "X5 waves (5,15,25,35,45) + X0 waves >10 except final (20,30,40)"
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode(info)
    })
  end
)

-- ============================================================================
-- PROCESS INITIALIZATION
-- ============================================================================

print("Daily Run Engine initialized - ADP v1.0 compliant")
