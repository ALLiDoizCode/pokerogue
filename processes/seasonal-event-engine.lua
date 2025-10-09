--[[
  Seasonal Event Engine Process

  Manages seasonal events with timing validation, content modifications, and reward distributions.
  Provides stateless event queries based on current timestamp for PokéRogue AO processes.

  AO Compliance:
  - Monolithic design with all event data embedded
  - Individual handlers for each action (no multi-action handlers)
  - Direct error handling without unnecessary pcall
  - Uses msg.Timestamp for all date comparisons
  - All tag values as strings

  ADP v1.0 Compliant: Self-documenting process with Info handler
]]

local json = require("json")

-- Constants
local CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER = 2.5

-- Event Type Enum
local EventType = {
  SHINY = "SHINY",
  NO_TIMER_DISPLAY = "NO_TIMER_DISPLAY",
  LUCK = "LUCK"
}

-- Embedded Seasonal Events Data
-- All dates are UTC Unix timestamps for comparison with msg.Timestamp
-- Timestamps calculated externally and embedded as constants
local timedEvents = {
  {
    name = "Winter Holiday Update",
    eventType = EventType.SHINY,
    shinyMultiplier = 2,
    upgradeUnlockedVouchers = true,
    startDate = 1734739200, -- Dec 21, 2024 00:00:00 UTC
    endDate = 1735948800, -- Jan 4, 2025 00:00:00 UTC
    bannerKey = "winter_holidays2024-event",
    scale = 0.21,
    xOffset = 0,
    yOffset = 0,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "pt-BR", "zh-CN"},
    eventEncounters = {
      {species = "GIMMIGHOUL", blockEvolution = true},
      {species = "DELIBIRD"},
      {species = "STANTLER"},
      {species = "CYNDAQUIL"},
      {species = "PIPLUP"},
      {species = "CHESPIN"},
      {species = "BALTOY"},
      {species = "SNOVER"},
      {species = "CHINGLING"},
      {species = "LITWICK"},
      {species = "CUBCHOO"},
      {species = "SWIRLIX"},
      {species = "AMAURA"},
      {species = "MUDBRAY"},
      {species = "ROLYCOLY"},
      {species = "MILCERY"},
      {species = "SMOLIV"},
      {species = "ALOLA_VULPIX"},
      {species = "GALAR_DARUMAKA"},
      {species = "IRON_BUNDLE"}
    },
    delibirdyBuff = {"CATCHING_CHARM", "SHINY_CHARM", "ABILITY_CHARM", "EXP_CHARM", "SUPER_EXP_CHARM", "HEALING_CHARM"},
    weather = {{weatherType = "SNOW", weight = 1}},
    mysteryEncounterTierChanges = {
      {mysteryEncounter = "DELIBIRDY", tier = "COMMON"},
      {mysteryEncounter = "PART_TIMER", disable = true},
      {mysteryEncounter = "AN_OFFER_YOU_CANT_REFUSE", disable = true},
      {mysteryEncounter = "FIELD_TRIP", disable = true},
      {mysteryEncounter = "DEPARTMENT_STORE_SALE", disable = true}
    },
    classicWaveRewards = {
      {wave = 8, type = "SHINY_CHARM"},
      {wave = 8, type = "ABILITY_CHARM"},
      {wave = 8, type = "CATCHING_CHARM"},
      {wave = 25, type = "SHINY_CHARM"}
    }
  },
  {
    name = "Year of the Snake",
    eventType = EventType.LUCK,
    luckBoost = 1,
    startDate = 1738108800, -- Jan 29, 2025 00:00:00 UTC
    endDate = 1738540800, -- Feb 3, 2025 00:00:00 UTC
    bannerKey = "yearofthesnakeevent",
    scale = 0.21,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "pt-BR", "zh-CN"},
    eventEncounters = {
      {species = "EKANS"},
      {species = "ONIX"},
      {species = "DRATINI"},
      {species = "CLEFFA"},
      {species = "UMBREON"},
      {species = "DUNSPARCE"},
      {species = "TEDDIURSA"},
      {species = "SEVIPER"},
      {species = "LUNATONE"},
      {species = "CHINGLING"},
      {species = "SNIVY"},
      {species = "DARUMAKA"},
      {species = "DRAMPA"},
      {species = "SILICOBRA"},
      {species = "BLOODMOON_URSALUNA"}
    },
    luckBoostedSpecies = {
      "EKANS", "ARBOK", "ONIX", "STEELIX", "DRATINI", "DRAGONAIR", "DRAGONITE",
      "CLEFFA", "CLEFAIRY", "CLEFABLE", "UMBREON", "DUNSPARCE", "DUDUNSPARCE",
      "TEDDIURSA", "URSARING", "URSALUNA", "SEVIPER", "LUNATONE", "RAYQUAZA",
      "CHINGLING", "CHIMECHO", "CRESSELIA", "DARKRAI", "SNIVY", "SERVINE", "SERPERIOR",
      "DARUMAKA", "DARMANITAN", "ZYGARDE", "DRAMPA", "LUNALA", "BLACEPHALON",
      "SILICOBRA", "SANDACONDA", "ROARING_MOON", "BLOODMOON_URSALUNA"
    },
    classicWaveRewards = {
      {wave = 8, type = "SHINY_CHARM"},
      {wave = 8, type = "ABILITY_CHARM"},
      {wave = 8, type = "CATCHING_CHARM"},
      {wave = 25, type = "SHINY_CHARM"}
    }
  },
  {
    name = "Valentine",
    eventType = EventType.SHINY,
    startDate = 1739145600, -- Feb 10, 2025 00:00:00 UTC
    endDate = 1740096000, -- Feb 21, 2025 00:00:00 UTC
    boostFusions = true,
    shinyMultiplier = 2,
    bannerKey = "valentines2025event",
    scale = 0.21,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "pt-BR", "zh-CN"},
    eventEncounters = {
      {species = "NIDORAN_F"},
      {species = "NIDORAN_M"},
      {species = "IGGLYBUFF"},
      {species = "SMOOCHUM"},
      {species = "VOLBEAT"},
      {species = "ILLUMISE"},
      {species = "ROSELIA"},
      {species = "LUVDISC"},
      {species = "WOOBAT"},
      {species = "FRILLISH"},
      {species = "ALOMOMOLA"},
      {species = "FURFROU", formIndex = 1}, -- Heart Trim
      {species = "ESPURR"},
      {species = "SPRITZEE"},
      {species = "SWIRLIX"},
      {species = "APPLIN"},
      {species = "MILCERY"},
      {species = "INDEEDEE"},
      {species = "TANDEMAUS"},
      {species = "ENAMORUS"}
    },
    luckBoostedSpecies = {"LUVDISC"},
    classicWaveRewards = {
      {wave = 8, type = "SHINY_CHARM"},
      {wave = 8, type = "ABILITY_CHARM"},
      {wave = 8, type = "CATCHING_CHARM"},
      {wave = 25, type = "SHINY_CHARM"}
    }
  },
  {
    name = "PKMNDAY2025",
    eventType = EventType.LUCK,
    startDate = 1740614400, -- Feb 27, 2025 00:00:00 UTC
    endDate = 1741046400, -- Mar 4, 2025 00:00:00 UTC
    classicFriendshipMultiplier = 4,
    bannerKey = "pkmnday2025event",
    scale = 0.21,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "pt-BR", "zh-CN"},
    eventEncounters = {
      {species = "PIKACHU", formIndex = 1, blockEvolution = true}, -- Partner Form
      {species = "EEVEE", formIndex = 1, blockEvolution = true}, -- Partner Form
      {species = "CHIKORITA"},
      {species = "TOTODILE"},
      {species = "TEPIG"}
    },
    luckBoostedSpecies = {
      "PICHU", "PIKACHU", "RAICHU", "ALOLA_RAICHU", "PSYDUCK", "GOLDUCK",
      "EEVEE", "FLAREON", "JOLTEON", "VAPOREON", "ESPEON", "UMBREON", "LEAFEON", "GLACEON", "SYLVEON",
      "CHIKORITA", "BAYLEEF", "MEGANIUM", "TOTODILE", "CROCONAW", "FERALIGATR",
      "TEPIG", "PIGNITE", "EMBOAR", "ZYGARDE", "ETERNAL_FLOETTE"
    },
    classicWaveRewards = {
      {wave = 8, type = "SHINY_CHARM"},
      {wave = 8, type = "ABILITY_CHARM"},
      {wave = 8, type = "CATCHING_CHARM"},
      {wave = 25, type = "SHINY_CHARM"}
    }
  },
  {
    name = "April Fools 2025",
    eventType = EventType.LUCK,
    startDate = 1743379200, -- Mar 31, 2025 00:00:00 UTC
    endDate = 1743638400, -- Apr 3, 2025 00:00:00 UTC
    bannerKey = "aprf25",
    scale = 0.21,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "es-MX", "pt-BR", "zh-CN"},
    trainerShinyChance = 13107, -- 13107/65536 = 1/5
    music = {
      {"title", "title_afd"},
      {"battle_rival_3", "battle_rival_3_afd"}
    },
    dailyRunChallenges = {
      {challenge = "INVERSE_BATTLE", value = 1}
    }
  },
  {
    name = "Shining Spring",
    eventType = EventType.SHINY,
    startDate = 1746230400, -- May 3, 2025 00:00:00 UTC
    endDate = 1747094400, -- May 13, 2025 00:00:00 UTC
    bannerKey = "spr25event",
    scale = 0.21,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "es-MX", "pt-BR", "zh-CN"},
    shinyMultiplier = 2,
    upgradeUnlockedVouchers = true,
    eventEncounters = {
      {species = "HOPPIP"},
      {species = "CELEBI"},
      {species = "VOLBEAT"},
      {species = "ILLUMISE"},
      {species = "SPOINK"},
      {species = "LILEEP"},
      {species = "SHINX"},
      {species = "PACHIRISU"},
      {species = "CHERUBI"},
      {species = "MUNCHLAX"},
      {species = "TEPIG"},
      {species = "PANSAGE"},
      {species = "PANSEAR"},
      {species = "PANPOUR"},
      {species = "DARUMAKA"},
      {species = "ARCHEN"},
      {species = "DEERLING", formIndex = 0}, -- Spring Deerling
      {species = "CLAUNCHER"},
      {species = "WISHIWASHI"},
      {species = "DRAMPA"},
      {species = "JANGMO_O"},
      {species = "APPLIN"}
    },
    classicWaveRewards = {
      {wave = 8, type = "SHINY_CHARM"},
      {wave = 8, type = "ABILITY_CHARM"},
      {wave = 8, type = "CATCHING_CHARM"},
      {wave = 25, type = "SHINY_CHARM"}
    }
  },
  {
    name = "Pride 25",
    eventType = EventType.SHINY,
    startDate = 1750118400, -- Jun 18, 2025 00:00:00 UTC
    endDate = 1751155200, -- Jun 30, 2025 00:00:00 UTC
    bannerKey = "pride2025",
    scale = 0.105,
    availableLangs = {"en", "de", "it", "fr", "ja", "ko", "es-ES", "es-MX", "pt-BR", "zh-CN", "zh-TW"},
    shinyMultiplier = 2,
    eventEncounters = {
      {species = "CHARMANDER"},
      {species = "SANDILE"},
      {species = "FERROSEED"},
      {species = "FOONGUS"},
      {species = "CUTIEFLY"},
      {species = "DEWPIDER"},
      {species = "TYPE_NULL"},
      {species = "MINIOR"},
      {species = "SOBBLE"},
      {species = "INDEEDEE"},
      {species = "CAPSAKID"},
      {species = "ALOLA_MEOWTH"}
    },
    classicWaveRewards = {
      {wave = 8, type = "SHINY_CHARM"},
      {wave = 8, type = "ABILITY_CHARM"},
      {wave = 8, type = "CATCHING_CHARM"},
      {wave = 25, type = "SHINY_CHARM"}
    }
  }
}

-- Helper Functions

-- Check if an event is active at the given timestamp
local function isEventActive(event, currentTimestamp)
  if not event or not event.startDate or not event.endDate then
    return false
  end
  return event.startDate <= currentTimestamp and currentTimestamp < event.endDate
end

-- Get all active events at the given timestamp
local function getActiveEvents(currentTimestamp)
  local active = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTimestamp) then
      table.insert(active, event)
    end
  end
  return active
end

-- Deduplicate species list
local function deduplicateSpecies(speciesList)
  local seen = {}
  local result = {}
  for _, species in ipairs(speciesList) do
    if not seen[species] then
      seen[species] = true
      table.insert(result, species)
    end
  end
  return result
end

-- AO Message Handlers

-- Handler: GetActiveEvent
-- Returns the first currently active event or nil
Handlers.add("get-active-event",
  Handlers.utils.hasMatchingTag("Action", "GetActiveEvent"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local activeEvent = activeEvents[1] -- Get first active event

    if activeEvent then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({activeEvent = activeEvent}),
        Success = "true"
      })
    else
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({activeEvent = json.null}),
        Success = "true"
      })
    end
  end
)

-- Handler: GetEventMultipliers
-- Returns cumulative multipliers from all active events
Handlers.add("get-event-multipliers",
  Handlers.utils.hasMatchingTag("Action", "GetEventMultipliers"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)

    -- Cumulative logic:
    -- Shiny: multiply all active event values (default 1)
    -- Friendship: use maximum value from active events (default CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER)
    -- Luck: sum all active event values (default 0)
    local shinyMultiplier = 1
    local friendshipMultiplier = CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER
    local luckBoost = 0

    for _, event in ipairs(activeEvents) do
      if event.shinyMultiplier then
        shinyMultiplier = shinyMultiplier * event.shinyMultiplier
      end
      if event.classicFriendshipMultiplier and event.classicFriendshipMultiplier > friendshipMultiplier then
        friendshipMultiplier = event.classicFriendshipMultiplier
      end
      if event.luckBoost then
        luckBoost = luckBoost + event.luckBoost
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        shinyMultiplier = shinyMultiplier,
        friendshipMultiplier = friendshipMultiplier,
        luckBoost = luckBoost
      }),
      Success = "true"
    })
  end
)

-- Handler: GetEventEncounters
-- Returns concatenated event encounter lists from all active events
Handlers.add("get-event-encounters",
  Handlers.utils.hasMatchingTag("Action", "GetEventEncounters"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local encounters = {}

    for _, event in ipairs(activeEvents) do
      if event.eventEncounters then
        for _, encounter in ipairs(event.eventEncounters) do
          table.insert(encounters, encounter)
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({encounters = encounters}),
      Success = "true"
    })
  end
)

-- Handler: GetWeatherModifications
-- Returns weather pool entries from all active events
Handlers.add("get-weather-modifications",
  Handlers.utils.hasMatchingTag("Action", "GetWeatherModifications"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local weather = {}

    for _, event in ipairs(activeEvents) do
      if event.weather then
        for _, w in ipairs(event.weather) do
          table.insert(weather, w)
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({weather = weather}),
      Success = "true"
    })
  end
)

-- Handler: GetMysteryEncounterChanges
-- Returns mystery encounter tier changes and disable flags
Handlers.add("get-mystery-encounter-changes",
  Handlers.utils.hasMatchingTag("Action", "GetMysteryEncounterChanges"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local changes = {}

    for _, event in ipairs(activeEvents) do
      if event.mysteryEncounterTierChanges then
        for _, change in ipairs(event.mysteryEncounterTierChanges) do
          table.insert(changes, change)
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({changes = changes}),
      Success = "true"
    })
  end
)

-- Handler: GetEventRewards
-- Returns rewards for specified wave number during active events
Handlers.add("get-event-rewards",
  Handlers.utils.hasMatchingTag("Action", "GetEventRewards"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    local wave = tonumber(msg.Wave)

    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    if not wave then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Wave parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local rewards = {}

    for _, event in ipairs(activeEvents) do
      if event.classicWaveRewards then
        for _, reward in ipairs(event.classicWaveRewards) do
          if reward.wave == wave then
            table.insert(rewards, reward.type)
          end
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({rewards = rewards}),
      Success = "true"
    })
  end
)

-- Handler: GetDelibirdyBuff
-- Returns Delibirdy bonus modifier types from all active events
Handlers.add("get-delibirdy-buff",
  Handlers.utils.hasMatchingTag("Action", "GetDelibirdyBuff"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local buff = {}

    for _, event in ipairs(activeEvents) do
      if event.delibirdyBuff then
        for _, modifier in ipairs(event.delibirdyBuff) do
          table.insert(buff, modifier)
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({buff = buff}),
      Success = "true"
    })
  end
)

-- Handler: GetClassicFriendshipMultiplier
-- Returns the highest friendship multiplier among active events or default
Handlers.add("get-classic-friendship-multiplier",
  Handlers.utils.hasMatchingTag("Action", "GetClassicFriendshipMultiplier"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local multiplier = CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER

    for _, event in ipairs(activeEvents) do
      if event.classicFriendshipMultiplier and event.classicFriendshipMultiplier > multiplier then
        multiplier = event.classicFriendshipMultiplier
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({multiplier = multiplier}),
      Success = "true"
    })
  end
)

-- Handler: GetUpgradeUnlockedVouchers
-- Returns whether vouchers should be upgraded during active events
Handlers.add("get-upgrade-unlocked-vouchers",
  Handlers.utils.hasMatchingTag("Action", "GetUpgradeUnlockedVouchers"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local upgradeVouchers = false

    for _, event in ipairs(activeEvents) do
      if event.upgradeUnlockedVouchers then
        upgradeVouchers = true
        break
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({upgradeVouchers = upgradeVouchers}),
      Success = "true"
    })
  end
)

-- Handler: GetEventLuckBoostedSpecies
-- Returns deduplicated list of luck-boosted species from all active events
Handlers.add("get-event-luck-boosted-species",
  Handlers.utils.hasMatchingTag("Action", "GetEventLuckBoostedSpecies"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local species = {}

    for _, event in ipairs(activeEvents) do
      if event.luckBoostedSpecies then
        for _, s in ipairs(event.luckBoostedSpecies) do
          table.insert(species, s)
        end
      end
    end

    -- Deduplicate species list
    species = deduplicateSpecies(species)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({species = species}),
      Success = "true"
    })
  end
)

-- Handler: GetAreFusionsBoosted
-- Returns whether fusions are boosted during active events
Handlers.add("get-are-fusions-boosted",
  Handlers.utils.hasMatchingTag("Action", "GetAreFusionsBoosted"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local fusionsBoosted = false

    for _, event in ipairs(activeEvents) do
      if event.boostFusions then
        fusionsBoosted = true
        break
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({fusionsBoosted = fusionsBoosted}),
      Success = "true"
    })
  end
)

-- Handler: GetClassicTrainerShinyChance
-- Returns cumulative trainer shiny chance from all active events
Handlers.add("get-classic-trainer-shiny-chance",
  Handlers.utils.hasMatchingTag("Action", "GetClassicTrainerShinyChance"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local shinyChance = 0

    for _, event in ipairs(activeEvents) do
      if event.trainerShinyChance then
        shinyChance = shinyChance + event.trainerShinyChance
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({shinyChance = shinyChance}),
      Success = "true"
    })
  end
)

-- Handler: GetEventBgmReplacement
-- Returns replacement BGM key if active event has music override
Handlers.add("get-event-bgm-replacement",
  Handlers.utils.hasMatchingTag("Action", "GetEventBgmReplacement"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    local bgmKey = msg.BgmKey

    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    if not bgmKey then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Missing BgmKey parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local replacementBgm = bgmKey -- Default to original

    for _, event in ipairs(activeEvents) do
      if event.music then
        for _, musicPair in ipairs(event.music) do
          if musicPair[1] == bgmKey then
            replacementBgm = musicPair[2]
            break
          end
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({bgm = replacementBgm}),
      Success = "true"
    })
  end
)

-- Handler: GetEventChallenges
-- Returns daily run challenge configurations from all active events
Handlers.add("get-event-challenges",
  Handlers.utils.hasMatchingTag("Action", "GetEventChallenges"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local challenges = {}

    for _, event in ipairs(activeEvents) do
      if event.dailyRunChallenges then
        for _, challenge in ipairs(event.dailyRunChallenges) do
          table.insert(challenges, challenge)
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({challenges = challenges}),
      Success = "true"
    })
  end
)

-- Handler: GetEventInfo
-- Returns complete event metadata for UI display
Handlers.add("get-event-info",
  Handlers.utils.hasMatchingTag("Action", "GetEventInfo"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local activeEvent = activeEvents[1] -- Get first active event

    if activeEvent then
      local eventInfo = {
        name = activeEvent.name,
        eventType = activeEvent.eventType,
        bannerKey = activeEvent.bannerKey,
        scale = activeEvent.scale,
        xOffset = activeEvent.xOffset,
        yOffset = activeEvent.yOffset,
        availableLangs = activeEvent.availableLangs,
        startDate = activeEvent.startDate,
        endDate = activeEvent.endDate
      }

      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode(eventInfo),
        Success = "true"
      })
    else
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({eventInfo = json.null}),
        Success = "true"
      })
    end
  end
)

--[[
  ========================================
  EVENT SPECIES HANDLERS
  ========================================
  Handlers for event-exclusive species generation, availability checking,
  and collection tracking. Extends seasonal event system with species logic.
]]

-- Helper: Seeded RNG for deterministic random generation
-- Implements simple LCG (Linear Congruential Generator) for deterministic randomness
local function seededRandom(seed, min, max)
  -- LCG parameters (from Numerical Recipes)
  local a = 1664525
  local c = 1013904223
  local m = 2^32

  -- Generate next value
  local next = (a * seed + c) % m

  -- Scale to range [min, max]
  local range = max - min + 1
  return min + (next % range)
end

-- Helper: Select random item from array using seed
local function seededRandomItem(items, seed)
  if #items == 0 then
    return nil
  end
  local index = seededRandom(seed, 1, #items)
  return items[index]
end

-- Handler: GetEventSpecies
-- Returns all event species from active events at given timestamp
Handlers.add("get-event-species",
  Handlers.utils.hasMatchingTag("Action", "GetEventSpecies"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local eventSpecies = {}
    local activeEventNames = {}

    for _, event in ipairs(activeEvents) do
      table.insert(activeEventNames, event.name)
      if event.eventEncounters then
        for _, encounter in ipairs(event.eventEncounters) do
          table.insert(eventSpecies, encounter)
        end
      end
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        eventSpecies = eventSpecies,
        activeEvents = activeEventNames,
        spawnProbability = 0.5,
        shinyReroll = true
      }),
      Success = "true"
    })
  end
)

-- Handler: CheckEventSpeciesAvailability
-- Validates if species is available as event encounter at timestamp
Handlers.add("check-event-species-availability",
  Handlers.utils.hasMatchingTag("Action", "CheckEventSpeciesAvailability"),
  function(msg)
    local timestamp = tonumber(msg.Timestamp)
    local speciesId = msg.SpeciesId

    if not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid or missing Timestamp parameter",
        Success = "false"
      })
      return
    end

    if not speciesId then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Missing SpeciesId parameter",
        Success = "false"
      })
      return
    end

    local activeEvents = getActiveEvents(timestamp)
    local foundEncounter = nil
    local foundEventName = nil

    for _, event in ipairs(activeEvents) do
      if event.eventEncounters then
        for _, encounter in ipairs(event.eventEncounters) do
          if encounter.species == speciesId then
            foundEncounter = encounter
            foundEventName = event.name
            break
          end
        end
      end
      if foundEncounter then
        break
      end
    end

    if foundEncounter then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({
          available = true,
          eventName = foundEventName,
          blockEvolution = foundEncounter.blockEvolution or false,
          formIndex = foundEncounter.formIndex
        }),
        Success = "true"
      })
    else
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({
          available = false
        }),
        Success = "true"
      })
    end
  end
)

-- Handler: GenerateEventSpecies
-- Generates event species or regular species based on 50% probability
-- Implements algorithm from encounter-phase-utils.ts:1008-1049
Handlers.add("generate-event-species",
  Handlers.utils.hasMatchingTag("Action", "GenerateEventSpecies"),
  function(msg)
    local level = tonumber(msg.Level)
    local seed = tonumber(msg.Seed)
    local timestamp = tonumber(msg.Timestamp)

    if not level or not seed or not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Missing required parameters: Level, Seed, and Timestamp",
        Success = "false"
      })
      return
    end

    -- Validate level range
    if level < 1 or level > 100 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Level must be between 1 and 100",
        Success = "false"
      })
      return
    end

    local isBoss = msg.IsBoss == "true"
    local rerollHidden = msg.RerollHidden == "true"

    -- Step 1: Check active events
    local activeEvents = getActiveEvents(timestamp)
    if #activeEvents == 0 then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({
          speciesGenerated = {
            isEventEncounter = false,
            useRegularSpecies = true,
            reason = "No active events"
          }
        }),
        Success = "true"
      })
      return
    end

    -- Step 2: Get event encounters
    local eventEncounters = {}
    for _, event in ipairs(activeEvents) do
      if event.eventEncounters then
        for _, encounter in ipairs(event.eventEncounters) do
          table.insert(eventEncounters, encounter)
        end
      end
    end

    if #eventEncounters == 0 then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({
          speciesGenerated = {
            isEventEncounter = false,
            useRegularSpecies = true,
            reason = "No event encounters defined"
          }
        }),
        Success = "true"
      })
      return
    end

    -- Step 3: Deterministic 50% probability roll (randSeedInt(2) === 1)
    local rand = seededRandom(seed, 0, 1)
    if rand == 0 then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({
          speciesGenerated = {
            isEventEncounter = false,
            useRegularSpecies = true,
            reason = "RNG selected regular species",
            rngRoll = rand
          }
        }),
        Success = "true"
      })
      return
    end

    -- Step 4: Select random event encounter
    local eventEncounter = seededRandomItem(eventEncounters, seed + 1)

    -- Step 5: Build event species result
    -- NOTE: Actual species evolution and stat generation would require
    -- species database integration. For now, return metadata for client processing.
    local pokemon = {
      species = eventEncounter.species,
      level = level,
      isBoss = isBoss,
      formIndex = eventEncounter.formIndex,
      blockEvolution = eventEncounter.blockEvolution or false,
      isEventEncounter = true,
      shinyRerolled = true,  -- Event species get extra shiny roll
      hiddenAbilityRerolled = rerollHidden,
      seed = seed,
      -- Client should use these seeds for stat/shiny/ability generation:
      statSeed = seed + 2,
      shinySeed = seed + 3,
      abilitySeed = seed + 4
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        speciesGenerated = pokemon
      }),
      Success = "true"
    })
  end
)

-- Handler: TrackEventSpeciesEncounter
-- Records event species encounter in player save data
Handlers.add("track-event-species-encounter",
  Handlers.utils.hasMatchingTag("Action", "TrackEventSpeciesEncounter"),
  function(msg)
    local speciesId = msg.SpeciesId
    local gameStateJson = msg.GameState

    if not speciesId then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Missing SpeciesId parameter",
        Success = "false"
      })
      return
    end

    -- Parse game state
    local gameState = {}
    if gameStateJson and gameStateJson ~= "" then
      gameState = json.decode(gameStateJson)
    end

    -- Initialize collection if not exists
    if not gameState.eventSpeciesCollection then
      gameState.eventSpeciesCollection = {
        totalEncounters = 0,
        uniqueSpecies = 0,
        shinyEncounters = 0,
        speciesEncountered = {}
      }
    end

    local collection = gameState.eventSpeciesCollection
    local formIndex = tonumber(msg.FormIndex) or 0
    local isShiny = msg.IsShiny == "true"

    -- Initialize species entry if not exists
    if not collection.speciesEncountered[speciesId] then
      collection.speciesEncountered[speciesId] = {
        count = 0,
        shinyCount = 0,
        formsSeen = {}
      }
      collection.uniqueSpecies = collection.uniqueSpecies + 1
    end

    local speciesData = collection.speciesEncountered[speciesId]

    -- Update counters
    speciesData.count = speciesData.count + 1
    collection.totalEncounters = collection.totalEncounters + 1

    if isShiny then
      speciesData.shinyCount = speciesData.shinyCount + 1
      collection.shinyEncounters = collection.shinyEncounters + 1
    end

    -- Track form
    local formSeen = false
    for _, form in ipairs(speciesData.formsSeen) do
      if form == formIndex then
        formSeen = true
        break
      end
    end
    if not formSeen then
      table.insert(speciesData.formsSeen, formIndex)
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        eventSpeciesCollection = collection
      }),
      Success = "true"
    })
  end
)

-- Handler: GetEventSpeciesProgress
-- Retrieves player's event species collection statistics
Handlers.add("get-event-species-progress",
  Handlers.utils.hasMatchingTag("Action", "GetEventSpeciesProgress"),
  function(msg)
    local gameStateJson = msg.GameState

    if not gameStateJson or gameStateJson == "" then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Data = json.encode({
          eventSpeciesCollection = {
            totalEncounters = 0,
            uniqueSpecies = 0,
            shinyEncounters = 0,
            speciesEncountered = {}
          }
        }),
        Success = "true"
      })
      return
    end

    local gameState = json.decode(gameStateJson)
    local collection = gameState.eventSpeciesCollection or {
      totalEncounters = 0,
      uniqueSpecies = 0,
      shinyEncounters = 0,
      speciesEncountered = {}
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        eventSpeciesCollection = collection
      }),
      Success = "true"
    })
  end
)

-- ADP v1.0 Info Handler
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    local infoResponse = {
      process = {
        name = "Seasonal Event Engine",
        version = "1.0.0",
        adpVersion = "1.0",
        processId = ao.id,
        description = "Manages seasonal events with timing validation, content modifications, and reward distributions for PokéRogue",
        capabilities = {
          "event-timing",
          "content-modifications",
          "reward-distribution",
          "multiplier-calculations",
          "event-queries",
          "event-species-generation",
          "event-species-availability",
          "collection-tracking"
        }
      },
      handlers = {
        {
          action = "GetActiveEvent",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for event query"}
          },
          returns = "Active event object or null"
        },
        {
          action = "GetEventMultipliers",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Cumulative multipliers (shiny, friendship, luck)"
        },
        {
          action = "GetEventEncounters",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Event-exclusive species encounters"
        },
        {
          action = "GetWeatherModifications",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Weather pool entries for active events"
        },
        {
          action = "GetMysteryEncounterChanges",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Mystery encounter tier changes and disable flags"
        },
        {
          action = "GetEventRewards",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"},
            {name = "Wave", type = "number", required = true, description = "Wave number for reward lookup"}
          },
          returns = "Array of reward types for specified wave"
        },
        {
          action = "GetDelibirdyBuff",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Delibirdy bonus modifier types"
        },
        {
          action = "GetClassicFriendshipMultiplier",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Highest friendship multiplier or default (2.5)"
        },
        {
          action = "GetUpgradeUnlockedVouchers",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Voucher upgrade feature flag"
        },
        {
          action = "GetEventLuckBoostedSpecies",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Deduplicated list of luck-boosted species"
        },
        {
          action = "GetAreFusionsBoosted",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Fusion boost feature flag"
        },
        {
          action = "GetClassicTrainerShinyChance",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Cumulative trainer shiny odds (over 65536)"
        },
        {
          action = "GetEventBgmReplacement",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"},
            {name = "BgmKey", type = "string", required = true, description = "Original BGM key"}
          },
          returns = "Replacement BGM key or original if no override"
        },
        {
          action = "GetEventChallenges",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Daily run challenge configurations"
        },
        {
          action = "GetEventInfo",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"}
          },
          returns = "Complete event metadata for UI display"
        },
        {
          action = "GetEventSpecies",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for event query"}
          },
          returns = "Event species list with spawn probability and shiny reroll flag"
        },
        {
          action = "CheckEventSpeciesAvailability",
          parameters = {
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for query"},
            {name = "SpeciesId", type = "string", required = true, description = "Species ID to check"}
          },
          returns = "Availability status with blockEvolution and formIndex if available"
        },
        {
          action = "GenerateEventSpecies",
          parameters = {
            {name = "Level", type = "number", required = true, description = "Pokemon level (1-100)"},
            {name = "Seed", type = "number", required = true, description = "RNG seed for deterministic generation"},
            {name = "Timestamp", type = "number", required = true, description = "UTC timestamp for event query"},
            {name = "IsBoss", type = "boolean", required = false, description = "Boss flag"},
            {name = "RerollHidden", type = "boolean", required = false, description = "Hidden ability reroll flag"}
          },
          returns = "Generated event species metadata or regular species indicator"
        },
        {
          action = "TrackEventSpeciesEncounter",
          parameters = {
            {name = "SpeciesId", type = "string", required = true, description = "Species ID encountered"},
            {name = "GameState", type = "string", required = true, description = "JSON-encoded game state"},
            {name = "FormIndex", type = "number", required = false, description = "Form index (default 0)"},
            {name = "IsShiny", type = "boolean", required = false, description = "Shiny flag"}
          },
          returns = "Updated event species collection statistics"
        },
        {
          action = "GetEventSpeciesProgress",
          parameters = {
            {name = "GameState", type = "string", required = true, description = "JSON-encoded game state"}
          },
          returns = "Event species collection statistics"
        }
      },
      events = {
        count = #timedEvents,
        types = {"SHINY", "NO_TIMER_DISPLAY", "LUCK"}
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode(infoResponse),
      Success = "true"
    })
  end
)

print("Seasonal Event Engine initialized with " .. #timedEvents .. " events")
