-- ============================================================================
-- Special Event Engine Process (AO Stateless)
-- ============================================================================
-- Manages timed event activation, effects, and rewards for PokéRogue
-- ADP v1.0 Compliant | AO Runtime Compatible
-- ============================================================================

local json = require("json")

-- ============================================================================
-- Mock AO Environment for Testing
-- ============================================================================
if not ao then
  ao = {
    id = "special_event_process_id",
    send = function(msg)
      print("Mock ao.send:", json.encode(msg))
    end
  }
end

if not Handlers then
  Handlers = {
    add = function(name, matcher, handler)
      print("Handler registered:", name)
    end,
    utils = {
      hasMatchingTag = function(tagName, tagValue)
        return function(msg)
          return msg[tagName] == tagValue
        end
      end
    }
  }
end

-- ============================================================================
-- Event Type Enumeration
-- ============================================================================
local EventType = {
  SHINY = "SHINY",
  NO_TIMER_DISPLAY = "NO_TIMER_DISPLAY",
  LUCK = "LUCK"
}

-- ============================================================================
-- Embedded Timed Events Data
-- ============================================================================
-- Converted from src/timed-event-manager.ts (lines 74-385)
-- All Date objects converted to Unix timestamps in milliseconds
local timedEvents = {
  {
    name = "Winter Holiday Update",
    eventType = EventType.SHINY,
    shinyMultiplier = 2,
    upgradeUnlockedVouchers = true,
    startDate = 1734739200000, -- 2024-12-21T00:00:00Z
    endDate = 1735948800000,   -- 2025-01-04T00:00:00Z
    eventEncounters = {
      { species = 1002, blockEvolution = true }, -- GIMMIGHOUL
      { species = 225 }, -- DELIBIRD
      { species = 234 }, -- STANTLER
      { species = 155 }, -- CYNDAQUIL
      { species = 393 }, -- PIPLUP
      { species = 650 }, -- CHESPIN
      { species = 343 }, -- BALTOY
      { species = 459 }, -- SNOVER
      { species = 433 }, -- CHINGLING
      { species = 607 }, -- LITWICK
      { species = 613 }, -- CUBCHOO
      { species = 684 }, -- SWIRLIX
      { species = 698 }, -- AMAURA
      { species = 749 }, -- MUDBRAY
      { species = 837 }, -- ROLYCOLY
      { species = 868 }, -- MILCERY
      { species = 928 }, -- SMOLIV
      { species = 10063 }, -- ALOLA_VULPIX
      { species = 10115 }, -- GALAR_DARUMAKA
      { species = 991 }  -- IRON_BUNDLE
    },
    delibirdyBuff = {"CATCHING_CHARM", "SHINY_CHARM", "ABILITY_CHARM", "EXP_CHARM", "SUPER_EXP_CHARM", "HEALING_CHARM"},
    weather = {{ weatherType = 7, weight = 1 }}, -- SNOW
    mysteryEncounterTierChanges = {
      { mysteryEncounter = 0, tier = 0 }, -- DELIBIRDY -> COMMON
      { mysteryEncounter = 1, disable = true }, -- PART_TIMER
      { mysteryEncounter = 2, disable = true }, -- AN_OFFER_YOU_CANT_REFUSE
      { mysteryEncounter = 3, disable = true }, -- FIELD_TRIP
      { mysteryEncounter = 4, disable = true }  -- DEPARTMENT_STORE_SALE
    },
    classicWaveRewards = {
      { wave = 8, type = "SHINY_CHARM" },
      { wave = 8, type = "ABILITY_CHARM" },
      { wave = 8, type = "CATCHING_CHARM" },
      { wave = 25, type = "SHINY_CHARM" }
    }
  },
  {
    name = "Year of the Snake",
    eventType = EventType.LUCK,
    luckBoost = 1,
    startDate = 1738108800000, -- 2025-01-29T00:00:00Z
    endDate = 1738540800000,   -- 2025-02-03T00:00:00Z
    eventEncounters = {
      { species = 23 },  -- EKANS
      { species = 95 },  -- ONIX
      { species = 147 }, -- DRATINI
      { species = 173 }, -- CLEFFA
      { species = 197 }, -- UMBREON
      { species = 206 }, -- DUNSPARCE
      { species = 216 }, -- TEDDIURSA
      { species = 336 }, -- SEVIPER
      { species = 337 }, -- LUNATONE
      { species = 433 }, -- CHINGLING
      { species = 495 }, -- SNIVY
      { species = 554 }, -- DARUMAKA
      { species = 780 }, -- DRAMPA
      { species = 843 }, -- SILICOBRA
      { species = 10235 } -- BLOODMOON_URSALUNA
    },
    luckBoostedSpecies = {
      23, 24, 95, 208, 147, 148, 149, 173, 174, 36, 197, 206, 982, 216, 217, 901, 336, 337, 384, 433, 358, 488, 491, 495, 496, 497, 554, 555, 718, 780, 792, 806, 843, 844, 1005, 10235
    },
    classicWaveRewards = {
      { wave = 8, type = "SHINY_CHARM" },
      { wave = 8, type = "ABILITY_CHARM" },
      { wave = 8, type = "CATCHING_CHARM" },
      { wave = 25, type = "SHINY_CHARM" }
    }
  },
  {
    name = "Valentine",
    eventType = EventType.SHINY,
    startDate = 1739145600000, -- 2025-02-10T00:00:00Z
    endDate = 1740096000000,   -- 2025-02-21T00:00:00Z
    boostFusions = true,
    shinyMultiplier = 2,
    eventEncounters = {
      { species = 29 },  -- NIDORAN_F
      { species = 32 },  -- NIDORAN_M
      { species = 174 }, -- IGGLYBUFF
      { species = 238 }, -- SMOOCHUM
      { species = 313 }, -- VOLBEAT
      { species = 314 }, -- ILLUMISE
      { species = 315 }, -- ROSELIA
      { species = 370 }, -- LUVDISC
      { species = 527 }, -- WOOBAT
      { species = 592 }, -- FRILLISH
      { species = 594 }, -- ALOMOMOLA
      { species = 676, formIndex = 1 }, -- FURFROU Heart Trim
      { species = 677 }, -- ESPURR
      { species = 682 }, -- SPRITZEE
      { species = 684 }, -- SWIRLIX
      { species = 840 }, -- APPLIN
      { species = 868 }, -- MILCERY
      { species = 876 }, -- INDEEDEE
      { species = 924 }, -- TANDEMAUS
      { species = 905 }  -- ENAMORUS
    },
    luckBoostedSpecies = { 370 },
    classicWaveRewards = {
      { wave = 8, type = "SHINY_CHARM" },
      { wave = 8, type = "ABILITY_CHARM" },
      { wave = 8, type = "CATCHING_CHARM" },
      { wave = 25, type = "SHINY_CHARM" }
    }
  },
  {
    name = "PKMNDAY2025",
    eventType = EventType.LUCK,
    startDate = 1740614400000, -- 2025-02-27T00:00:00Z
    endDate = 1741132800000,   -- 2025-03-04T00:00:00Z
    classicFriendshipMultiplier = 4,
    eventEncounters = {
      { species = 25, formIndex = 1, blockEvolution = true }, -- PIKACHU Partner
      { species = 133, formIndex = 1, blockEvolution = true }, -- EEVEE Partner
      { species = 152 }, -- CHIKORITA
      { species = 158 }, -- TOTODILE
      { species = 498 }  -- TEPIG
    },
    luckBoostedSpecies = {
      172, 25, 26, 10094, 54, 55, 133, 136, 135, 134, 196, 197, 470, 471, 700, 152, 153, 154, 158, 159, 160, 498, 499, 500, 718, 669
    },
    classicWaveRewards = {
      { wave = 8, type = "SHINY_CHARM" },
      { wave = 8, type = "ABILITY_CHARM" },
      { wave = 8, type = "CATCHING_CHARM" },
      { wave = 25, type = "SHINY_CHARM" }
    }
  },
  {
    name = "April Fools 2025",
    eventType = EventType.LUCK,
    startDate = 1743465600000, -- 2025-03-31T00:00:00Z
    endDate = 1743724800000,   -- 2025-04-03T00:00:00Z
    trainerShinyChance = 13107, -- 13107/65536 = 1/5
    music = {
      {"title", "title_afd"},
      {"battle_rival_3", "battle_rival_3_afd"}
    },
    dailyRunChallenges = {
      { challenge = 0, value = 1 } -- INVERSE_BATTLE
    }
  },
  {
    name = "Shining Spring",
    eventType = EventType.SHINY,
    startDate = 1746230400000, -- 2025-05-03T00:00:00Z
    endDate = 1747094400000,   -- 2025-05-13T00:00:00Z
    shinyMultiplier = 2,
    upgradeUnlockedVouchers = true,
    eventEncounters = {
      { species = 187 }, -- HOPPIP
      { species = 251 }, -- CELEBI
      { species = 313 }, -- VOLBEAT
      { species = 314 }, -- ILLUMISE
      { species = 325 }, -- SPOINK
      { species = 345 }, -- LILEEP
      { species = 403 }, -- SHINX
      { species = 417 }, -- PACHIRISU
      { species = 420 }, -- CHERUBI
      { species = 446 }, -- MUNCHLAX
      { species = 498 }, -- TEPIG
      { species = 511 }, -- PANSAGE
      { species = 513 }, -- PANSEAR
      { species = 515 }, -- PANPOUR
      { species = 554 }, -- DARUMAKA
      { species = 566 }, -- ARCHEN
      { species = 585, formIndex = 0 }, -- DEERLING Spring
      { species = 692 }, -- CLAUNCHER
      { species = 746 }, -- WISHIWASHI
      { species = 780 }, -- DRAMPA
      { species = 782 }, -- JANGMO_O
      { species = 840 }  -- APPLIN
    },
    classicWaveRewards = {
      { wave = 8, type = "SHINY_CHARM" },
      { wave = 8, type = "ABILITY_CHARM" },
      { wave = 8, type = "CATCHING_CHARM" },
      { wave = 25, type = "SHINY_CHARM" }
    }
  },
  {
    name = "Pride 25",
    eventType = EventType.SHINY,
    startDate = 1750032000000, -- 2025-06-18T00:00:00Z
    endDate = 1751068800000,   -- 2025-06-30T00:00:00Z
    shinyMultiplier = 2,
    eventEncounters = {
      { species = 4 },   -- CHARMANDER
      { species = 551 }, -- SANDILE
      { species = 597 }, -- FERROSEED
      { species = 590 }, -- FOONGUS
      { species = 742 }, -- CUTIEFLY
      { species = 751 }, -- DEWPIDER
      { species = 772 }, -- TYPE_NULL
      { species = 774 }, -- MINIOR
      { species = 816 }, -- SOBBLE
      { species = 876 }, -- INDEEDEE
      { species = 951 }, -- CAPSAKID
      { species = 10088 } -- ALOLA_MEOWTH
    },
    classicWaveRewards = {
      { wave = 8, type = "SHINY_CHARM" },
      { wave = 8, type = "ABILITY_CHARM" },
      { wave = 8, type = "CATCHING_CHARM" },
      { wave = 25, type = "SHINY_CHARM" }
    }
  }
}

-- ============================================================================
-- Event Activation Logic
-- ============================================================================

-- Check if event is currently active based on timestamp
local function isEventActive(event, currentTime)
  return event.startDate < currentTime and currentTime < event.endDate
end

-- Get the currently active event (returns nil if no event active)
local function getActiveEvent(currentTime)
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) then
      return event
    end
  end
  return nil
end

-- ============================================================================
-- Event Effect Calculations
-- ============================================================================

-- Calculate cumulative shiny multiplier from active SHINY events
local function getShinyMultiplier(currentTime)
  local multiplier = 1
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.eventType == EventType.SHINY then
      multiplier = multiplier * (event.shinyMultiplier or 1)
    end
  end
  return multiplier
end

-- Calculate cumulative luck boost from active LUCK events
local function getEventLuckBoost(currentTime)
  local luckBoost = 0
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.luckBoost then
      luckBoost = luckBoost + event.luckBoost
    end
  end
  return luckBoost
end

-- Get highest friendship multiplier among active events
local function getClassicFriendshipMultiplier(currentTime)
  local multiplier = 2.5 -- CLASSIC_CANDY_FRIENDSHIP_MULTIPLIER default
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.classicFriendshipMultiplier then
      if event.classicFriendshipMultiplier > multiplier then
        multiplier = event.classicFriendshipMultiplier
      end
    end
  end
  return multiplier
end

-- ============================================================================
-- Event Encounter Management
-- ============================================================================

-- Aggregate event encounters from all active events
local function getEventEncounters(currentTime)
  local encounters = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.eventEncounters then
      for _, encounter in ipairs(event.eventEncounters) do
        table.insert(encounters, encounter)
      end
    end
  end
  return encounters
end

-- ============================================================================
-- Event Reward Distribution
-- ============================================================================

-- Get rewards for specific wave from active events
local function getFixedBattleEventRewards(wave, currentTime)
  local rewards = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.classicWaveRewards then
      for _, reward in ipairs(event.classicWaveRewards) do
        if reward.wave == wave then
          table.insert(rewards, reward.type)
        end
      end
    end
  end
  return rewards
end

-- Aggregate Delibirdy bonus items from active events
local function getDelibirdyBuff(currentTime)
  local buffs = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.delibirdyBuff then
      for _, buff in ipairs(event.delibirdyBuff) do
        table.insert(buffs, buff)
      end
    end
  end
  return buffs
end

-- ============================================================================
-- Mystery Encounter Changes
-- ============================================================================

-- Aggregate all encounter tier changes from active events
local function getAllMysteryEncounterChanges(currentTime)
  local changes = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.mysteryEncounterTierChanges then
      for _, change in ipairs(event.mysteryEncounterTierChanges) do
        table.insert(changes, change)
      end
    end
  end
  return changes
end

-- Get list of disabled encounter types from active events
local function getEventMysteryEncountersDisabled(currentTime)
  local disabled = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.mysteryEncounterTierChanges then
      for _, change in ipairs(event.mysteryEncounterTierChanges) do
        if change.disable then
          table.insert(disabled, change.mysteryEncounter)
        end
      end
    end
  end
  return disabled
end

-- Get modified tier for specific encounter type during events
local function getMysteryEncounterTierForEvent(encounterType, normalTier, currentTime)
  local tier = normalTier
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.mysteryEncounterTierChanges then
      for _, change in ipairs(event.mysteryEncounterTierChanges) do
        if change.mysteryEncounter == encounterType then
          tier = change.tier or normalTier
          break
        end
      end
    end
  end
  return tier
end

-- ============================================================================
-- Event Participation Validation
-- ============================================================================

-- Check if species has luck boost during active events
local function isSpeciesLuckBoosted(speciesId, currentTime)
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.luckBoostedSpecies then
      for _, boostedSpecies in ipairs(event.luckBoostedSpecies) do
        if boostedSpecies == speciesId then
          return true
        end
      end
    end
  end
  return false
end

-- Check if fusions are boosted by any active event
local function areFusionsBoosted(currentTime)
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.boostFusions then
      return true
    end
  end
  return false
end

-- Check if voucher upgrades are enabled by any active event
local function getUpgradeUnlockedVouchers(currentTime)
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.upgradeUnlockedVouchers then
      return true
    end
  end
  return false
end

-- ============================================================================
-- Event Progression Tracking
-- ============================================================================

-- Aggregate daily run challenges from active events
local function getEventChallenges(currentTime)
  local challenges = {}
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.dailyRunChallenges then
      for _, challenge in ipairs(event.dailyRunChallenges) do
        table.insert(challenges, challenge)
      end
    end
  end
  return challenges
end

-- Sum trainer shiny chances from active events
local function getClassicTrainerShinyChance(currentTime)
  local chance = 0
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.trainerShinyChance then
      chance = chance + event.trainerShinyChance
    end
  end
  return chance
end

-- Get music replacement for BGM during active events
local function getEventBgmReplacement(bgmKey, currentTime)
  local replacement = bgmKey
  for _, event in ipairs(timedEvents) do
    if isEventActive(event, currentTime) and event.music then
      for _, musicReplacement in ipairs(event.music) do
        if musicReplacement[1] == bgmKey then
          replacement = musicReplacement[2]
          break
        end
      end
    end
  end
  return replacement
end

-- ============================================================================
-- AO Message Handlers
-- ============================================================================

-- Handler: CheckEventActive
Handlers.add("check-event-active",
  Handlers.utils.hasMatchingTag("Action", "CheckEventActive"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local activeEvent = getActiveEvent(currentTime)
    local isActive = activeEvent ~= nil

    if isActive then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        IsActive = "true",
        EventName = activeEvent.name,
        Data = json.encode(activeEvent)
      })
    else
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        IsActive = "false",
        EventName = "",
        Data = json.encode({})
      })
    end
  end
)

-- Handler: GetActiveEvent
Handlers.add("get-active-event",
  Handlers.utils.hasMatchingTag("Action", "GetActiveEvent"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local activeEvent = getActiveEvent(currentTime)
    local hasActiveEvent = activeEvent ~= nil

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      HasActiveEvent = tostring(hasActiveEvent),
      Data = json.encode(activeEvent or {})
    })
  end
)

-- Handler: GetShinyMultiplier
Handlers.add("get-shiny-multiplier",
  Handlers.utils.hasMatchingTag("Action", "GetShinyMultiplier"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local multiplier = getShinyMultiplier(currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      ShinyMultiplier = tostring(multiplier)
    })
  end
)

-- Handler: GetEventEncounters
Handlers.add("get-event-encounters",
  Handlers.utils.hasMatchingTag("Action", "GetEventEncounters"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local encounters = getEventEncounters(currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      EncounterCount = tostring(#encounters),
      Data = json.encode(encounters)
    })
  end
)

-- Handler: GetEventRewards
Handlers.add("get-event-rewards",
  Handlers.utils.hasMatchingTag("Action", "GetEventRewards"),
  function(msg)
    if not msg.Wave then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Wave parameter required"
      })
      return
    end

    local wave = tonumber(msg.Wave)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local rewards = getFixedBattleEventRewards(wave, currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      RewardCount = tostring(#rewards),
      Data = json.encode(rewards)
    })
  end
)

-- Handler: GetEventEffects
Handlers.add("get-event-effects",
  Handlers.utils.hasMatchingTag("Action", "GetEventEffects"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0

    local shinyMultiplier = getShinyMultiplier(currentTime)
    local luckBoost = getEventLuckBoost(currentTime)
    local friendshipMultiplier = getClassicFriendshipMultiplier(currentTime)
    local upgradeVouchers = getUpgradeUnlockedVouchers(currentTime)
    local trainerShinyChance = getClassicTrainerShinyChance(currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      ShinyMultiplier = tostring(shinyMultiplier),
      LuckBoost = tostring(luckBoost),
      FriendshipMultiplier = tostring(friendshipMultiplier),
      UpgradeVouchers = tostring(upgradeVouchers),
      TrainerShinyChance = tostring(trainerShinyChance),
      Data = json.encode({
        shinyMultiplier = shinyMultiplier,
        luckBoost = luckBoost,
        friendshipMultiplier = friendshipMultiplier,
        upgradeVouchers = upgradeVouchers,
        trainerShinyChance = trainerShinyChance
      })
    })
  end
)

-- Handler: GetMysteryEncounterChanges
Handlers.add("get-mystery-encounter-changes",
  Handlers.utils.hasMatchingTag("Action", "GetMysteryEncounterChanges"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local changes = getAllMysteryEncounterChanges(currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      ChangeCount = tostring(#changes),
      Data = json.encode(changes)
    })
  end
)

-- Handler: GetEventMusicReplacement
Handlers.add("get-event-music-replacement",
  Handlers.utils.hasMatchingTag("Action", "GetEventMusicReplacement"),
  function(msg)
    if not msg.BgmKey then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "BgmKey parameter required"
      })
      return
    end

    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local replacement = getEventBgmReplacement(msg.BgmKey, currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      ReplacementBgm = replacement
    })
  end
)

-- Handler: CheckSpeciesLuckBoost
Handlers.add("check-species-luck-boost",
  Handlers.utils.hasMatchingTag("Action", "CheckSpeciesLuckBoost"),
  function(msg)
    if not msg.SpeciesId then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "SpeciesId parameter required"
      })
      return
    end

    local speciesId = tonumber(msg.SpeciesId)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local hasLuckBoost = isSpeciesLuckBoosted(speciesId, currentTime)
    local luckBoost = hasLuckBoost and getEventLuckBoost(currentTime) or 0

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      HasLuckBoost = tostring(hasLuckBoost),
      LuckBoost = tostring(luckBoost)
    })
  end
)

-- Handler: GetEventChallenges
Handlers.add("get-event-challenges",
  Handlers.utils.hasMatchingTag("Action", "GetEventChallenges"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local challenges = getEventChallenges(currentTime)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      ChallengeCount = tostring(#challenges),
      Data = json.encode(challenges)
    })
  end
)

-- Handler: ValidateEventParticipation
Handlers.add("validate-event-participation",
  Handlers.utils.hasMatchingTag("Action", "ValidateEventParticipation"),
  function(msg)
    local currentTime = tonumber(msg.CurrentTime) or tonumber(msg.Timestamp) or 0
    local activeEvent = getActiveEvent(currentTime)

    -- Always eligible if event is active (no additional criteria in original implementation)
    local eligible = activeEvent ~= nil
    local reason = eligible and "Event is active" or "No active event"

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Eligible = tostring(eligible),
      Reason = reason
    })
  end
)

-- Handler: Info (ADP v1.0)
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Data = json.encode({
        process = {
          name = "Special Event Engine",
          version = "1.0.0",
          adpVersion = "1.0",
          processId = ao.id or "special-event-engine-adp",
          capabilities = {
            "CheckEventActive",
            "GetActiveEvent",
            "GetShinyMultiplier",
            "GetEventEncounters",
            "GetEventRewards",
            "GetEventEffects",
            "GetMysteryEncounterChanges",
            "GetEventMusicReplacement",
            "CheckSpeciesLuckBoost",
            "GetEventChallenges",
            "ValidateEventParticipation"
          },
          messageSchemas = {
            CheckEventActive = {
              required = {"Action"},
              optional = {"CurrentTime"}
            },
            GetActiveEvent = {
              required = {"Action"},
              optional = {"CurrentTime"}
            },
            GetShinyMultiplier = {
              required = {"Action"},
              optional = {"CurrentTime"}
            },
            GetEventEncounters = {
              required = {"Action"},
              optional = {"CurrentTime"}
            },
            GetEventRewards = {
              required = {"Action", "Wave"},
              optional = {"CurrentTime"}
            },
            GetEventEffects = {
              required = {"Action"},
              optional = {"CurrentTime"}
            },
            GetMysteryEncounterChanges = {
              required = {"Action"},
              optional = {"CurrentTime", "EncounterType"}
            },
            GetEventMusicReplacement = {
              required = {"Action", "BgmKey"},
              optional = {"CurrentTime"}
            },
            CheckSpeciesLuckBoost = {
              required = {"Action", "SpeciesId"},
              optional = {"CurrentTime"}
            },
            GetEventChallenges = {
              required = {"Action"},
              optional = {"CurrentTime"}
            },
            ValidateEventParticipation = {
              required = {"Action"},
              optional = {"CurrentTime", "Data"}
            }
          }
        },
        handlers = {
          "check-event-active",
          "get-active-event",
          "get-shiny-multiplier",
          "get-event-encounters",
          "get-event-rewards",
          "get-event-effects",
          "get-mystery-encounter-changes",
          "get-event-music-replacement",
          "check-species-luck-boost",
          "get-event-challenges",
          "validate-event-participation",
          "info"
        },
        documentation = {
          adpCompliance = "v1.0",
          selfDocumenting = true,
          description = "Manages timed event activation, effects, and rewards for PokéRogue"
        }
      })
    })
  end
)

print("Special Event Engine process initialized")
