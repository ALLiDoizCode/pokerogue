--[[
  Pokedex Registration Engine - Stateless AO Process

  Handles Pokemon species discovery and registration including:
  - Species seen/caught attribute tracking
  - Form, gender, variant, shiny attribute bitmasking
  - Nature and ability unlock integration
  - Discovery progress calculation and analytics
  - Registration validation and data integrity

  Process follows AO monolithic design with ADP v1.0 compliance.

  === Message Schemas ===

  RegisterSeen:
    Tags: Action="RegisterSeen", SpeciesId="<number>"
    Data: JSON{formIndex, gender, shiny, variant, isTrainer, preventStatsUpdate}
    Response: SaveState with updated dexEntry and statistics

  RegisterCaught:
    Tags: Action="RegisterCaught", SpeciesId="<number>"
    Data: JSON{formIndex, gender, shiny, variant, nature, abilityIndex, fromEgg, incrementCount}
    Response: SaveState with updated dexEntry, ability unlocks, statistics

  GetDexEntry:
    Tags: Action="GetDexEntry", SpeciesId="<number>"
    Data: JSON{dexData}
    Response: SaveState with complete DexEntry for species

  GetDexProgress:
    Tags: Action="GetDexProgress"
    Data: JSON{dexData}
    Response: SaveState with completion statistics and milestones

  ValidateDexData:
    Tags: Action="ValidateDexData"
    Data: JSON{dexEntries}
    Response: SaveState with validation results and integrity score

  Info:
    Tags: Action="Info"
    Response: SaveState with process capabilities and handler list
]]

local json = require("json")

-- ============================================================================
-- Constants and Data Structures
-- ============================================================================

-- DexAttr flags for attribute bitmasking (matches TypeScript DexAttr enum)
local DexAttr = {
  NON_SHINY = 1,        -- Bit 0
  SHINY = 2,            -- Bit 1
  MALE = 4,             -- Bit 2
  FEMALE = 8,           -- Bit 3
  DEFAULT_VARIANT = 16, -- Bit 4
  VARIANT_2 = 32,       -- Bit 5
  VARIANT_3 = 64,       -- Bit 6
  DEFAULT_FORM = 128    -- Bit 7 (additional forms continue from bit 8+)
}

-- Gender constants (matches TypeScript Gender enum)
local Gender = {
  MALE = 0,
  FEMALE = 1,
  GENDERLESS = 2
}

-- Special species IDs for form unlock logic
local SpeciesId = {
  PICHU = 172,
  PIKACHU = 25,
  URSHIFU = 892,
  ZYGARDE = 718
}

-- Maximum species count for progress calculation
local MAX_SPECIES_COUNT = 1025

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Create empty DexEntry
local function createDexEntry()
  return {
    seenAttr = 0,
    caughtAttr = 0,
    natureAttr = 0,
    seenCount = 0,
    caughtCount = 0,
    hatchedCount = 0,
    ivs = {0, 0, 0, 0, 0, 0},
    ribbons = {}
  }
end

-- Compute form attribute bit for given form index
-- Formula: 1 << (7 + formIndex)
local function getFormAttr(formIndex)
  return 1 << (7 + formIndex)
end

-- Compute DexAttr flags from Pokemon attributes
-- Returns combined attribute bitmask
local function getDexAttr(gender, shiny, variant, formIndex)
  local attr = 0

  -- Gender attribute (skip if genderless)
  if gender ~= Gender.GENDERLESS then
    attr = attr | (gender == Gender.MALE and DexAttr.MALE or DexAttr.FEMALE)
  end

  -- Shiny attribute
  attr = attr | (shiny and DexAttr.SHINY or DexAttr.NON_SHINY)

  -- Variant attribute
  if variant >= 2 then
    attr = attr | DexAttr.VARIANT_3
  elseif variant == 1 then
    attr = attr | DexAttr.VARIANT_2
  else
    attr = attr | DexAttr.DEFAULT_VARIANT
  end

  -- Form attribute
  attr = attr | getFormAttr(formIndex)

  return attr
end

-- Check if species is legendary
local function isLegendary(speciesId)
  -- Simplified legendary check - in production would use species data
  -- Legendary birds: 144-146, Mewtwo: 150, Legendary beasts: 243-245, etc.
  local legendaries = {144, 145, 146, 150, 243, 244, 245, 249, 250, 377, 378, 379, 380, 381, 382, 383, 384, 480, 481, 482, 483, 484, 487, 488, 643, 644, 646, 647, 716, 717, 718, 785, 786, 787, 788, 791, 792, 800, 888, 889, 894, 896, 897, 898}
  for _, id in ipairs(legendaries) do
    if id == speciesId then return true end
  end
  return false
end

-- Check if species is sub-legendary
local function isSubLegendary(speciesId)
  -- Sub-legendaries include Articuno, Zapdos, Moltres, Raikou, Entei, Suicune, Regis, etc.
  local subLegendaries = {144, 145, 146, 243, 244, 245, 377, 378, 379, 480, 481, 482, 638, 639, 640, 641, 642, 645, 772, 773, 785, 786, 787, 788, 793, 794, 795, 796, 797, 798, 799, 805, 806, 891, 892, 894, 895, 896, 897}
  for _, id in ipairs(subLegendaries) do
    if id == speciesId then return true end
  end
  return false
end

-- Check if species is mythical
local function isMythical(speciesId)
  -- Mythicals: Mew, Celebi, Jirachi, Deoxys, Phione, Manaphy, Darkrai, Shaymin, Arceus, etc.
  local mythicals = {151, 251, 385, 386, 489, 490, 491, 492, 493, 494, 647, 648, 649, 719, 720, 721, 801, 802, 807, 808, 809, 893}
  for _, id in ipairs(mythicals) do
    if id == speciesId then return true end
  end
  return false
end

-- Initialize game statistics if not present
local function initGameStats(gameStats)
  gameStats = gameStats or {}
  gameStats.pokemonSeen = gameStats.pokemonSeen or 0
  gameStats.pokemonCaught = gameStats.pokemonCaught or 0
  gameStats.pokemonHatched = gameStats.pokemonHatched or 0
  gameStats.subLegendaryPokemonSeen = gameStats.subLegendaryPokemonSeen or 0
  gameStats.subLegendaryPokemonCaught = gameStats.subLegendaryPokemonCaught or 0
  gameStats.subLegendaryPokemonHatched = gameStats.subLegendaryPokemonHatched or 0
  gameStats.legendaryPokemonSeen = gameStats.legendaryPokemonSeen or 0
  gameStats.legendaryPokemonCaught = gameStats.legendaryPokemonCaught or 0
  gameStats.legendaryPokemonHatched = gameStats.legendaryPokemonHatched or 0
  gameStats.mythicalPokemonSeen = gameStats.mythicalPokemonSeen or 0
  gameStats.mythicalPokemonCaught = gameStats.mythicalPokemonCaught or 0
  gameStats.mythicalPokemonHatched = gameStats.mythicalPokemonHatched or 0
  gameStats.shinyPokemonSeen = gameStats.shinyPokemonSeen or 0
  gameStats.shinyPokemonCaught = gameStats.shinyPokemonCaught or 0
  gameStats.shinyPokemonHatched = gameStats.shinyPokemonHatched or 0
  return gameStats
end

-- ============================================================================
-- Registration Logic
-- ============================================================================

-- Register species as seen with attribute tracking
local function registerSeen(speciesId, attributes, dexData, gameStats)
  -- Get or create dex entry
  local entry = dexData[tostring(speciesId)]
  if not entry then
    entry = createDexEntry()
    dexData[tostring(speciesId)] = entry
  end

  -- Compute DexAttr flags
  local dexAttr = getDexAttr(
    attributes.gender or Gender.GENDERLESS,
    attributes.shiny or false,
    attributes.variant or 0,
    attributes.formIndex or 0
  )

  -- Track newly unlocked attributes
  local newAttributes = {}
  if (entry.seenAttr & dexAttr) ~= dexAttr then
    if (dexAttr & DexAttr.SHINY) ~= 0 then table.insert(newAttributes, "SHINY") end
    if (dexAttr & DexAttr.MALE) ~= 0 then table.insert(newAttributes, "MALE") end
    if (dexAttr & DexAttr.FEMALE) ~= 0 then table.insert(newAttributes, "FEMALE") end
  end

  -- Update seenAttr with OR operation
  entry.seenAttr = entry.seenAttr | dexAttr

  -- Initialize stats if needed
  gameStats = initGameStats(gameStats)

  -- Update counts and statistics (if not prevented and incrementing)
  local incrementCount = attributes.incrementCount
  if incrementCount == nil then incrementCount = true end

  if incrementCount and not attributes.preventStatsUpdate then
    entry.seenCount = entry.seenCount + 1
    gameStats.pokemonSeen = gameStats.pokemonSeen + 1

    -- Update legendary/mythical/sub-legendary stats (skip for trainer battles)
    if not attributes.isTrainer then
      if isSubLegendary(speciesId) then
        gameStats.subLegendaryPokemonSeen = gameStats.subLegendaryPokemonSeen + 1
      elseif isLegendary(speciesId) then
        gameStats.legendaryPokemonSeen = gameStats.legendaryPokemonSeen + 1
      elseif isMythical(speciesId) then
        gameStats.mythicalPokemonSeen = gameStats.mythicalPokemonSeen + 1
      end

      -- Track shiny sightings
      if attributes.shiny then
        gameStats.shinyPokemonSeen = gameStats.shinyPokemonSeen + 1
      end
    end
  end

  return {
    speciesId = speciesId,
    registered = true,
    newAttributes = newAttributes,
    dexEntry = entry,
    statsUpdated = {
      pokemonSeen = incrementCount and 1 or 0,
      subLegendaryPokemonSeen = (incrementCount and not attributes.isTrainer and isSubLegendary(speciesId)) and 1 or 0,
      legendaryPokemonSeen = (incrementCount and not attributes.isTrainer and isLegendary(speciesId)) and 1 or 0,
      mythicalPokemonSeen = (incrementCount and not attributes.isTrainer and isMythical(speciesId)) and 1 or 0,
      shinyPokemonSeen = (incrementCount and not attributes.isTrainer and attributes.shiny) and 1 or 0
    }
  }
end

-- Register species as caught with form unlock and ability tracking
local function registerCaught(speciesId, attributes, dexData, gameStats, starterData)
  -- Get or create dex entry
  local entry = dexData[tostring(speciesId)]
  if not entry then
    entry = createDexEntry()
    dexData[tostring(speciesId)] = entry
  end

  -- Compute DexAttr flags
  local dexAttr = getDexAttr(
    attributes.gender or Gender.GENDERLESS,
    attributes.shiny or false,
    attributes.variant or 0,
    attributes.formIndex or 0
  )

  -- Track newly unlocked attributes
  local newAttributes = {}
  if (entry.caughtAttr & dexAttr) ~= dexAttr then
    if (dexAttr & DexAttr.SHINY) ~= 0 then table.insert(newAttributes, "SHINY") end
    if (dexAttr & DexAttr.MALE) ~= 0 then table.insert(newAttributes, "MALE") end
    if (dexAttr & DexAttr.FEMALE) ~= 0 then table.insert(newAttributes, "FEMALE") end
    table.insert(newAttributes, "FORM_" .. (attributes.formIndex or 0))
  end

  -- Update caughtAttr with OR operation
  local newCatch = entry.caughtAttr == 0
  entry.caughtAttr = entry.caughtAttr | dexAttr

  -- Handle special form unlocks
  local formsUnlocked = {attributes.formIndex or 0}
  local formIndex = attributes.formIndex or 0

  if formIndex > 0 then
    -- Pikachu/Pichu special case
    if speciesId == SpeciesId.PIKACHU then
      -- When Pikachu with formIndex > 0 is caught, check if we should unlock Pichu base form
      -- Note: This would be handled by caller passing Pichu dex data
    elseif speciesId == SpeciesId.PICHU and attributes.pikachuFormIndex and attributes.pikachuFormIndex > 0 then
      -- Unlock Pichu base form when cosplay Pikachu is caught
      entry.caughtAttr = entry.caughtAttr | getFormAttr(0)
      table.insert(formsUnlocked, 0)
    -- Urshifu form mapping
    elseif speciesId == SpeciesId.URSHIFU then
      if formIndex == 2 then
        entry.caughtAttr = entry.caughtAttr | getFormAttr(0)
        table.insert(formsUnlocked, 0)
      elseif formIndex == 3 then
        entry.caughtAttr = entry.caughtAttr | getFormAttr(1)
        table.insert(formsUnlocked, 1)
      end
    -- Zygarde form mapping
    elseif speciesId == SpeciesId.ZYGARDE then
      if formIndex == 4 then
        entry.caughtAttr = entry.caughtAttr | getFormAttr(2)
        table.insert(formsUnlocked, 2)
      elseif formIndex == 5 then
        entry.caughtAttr = entry.caughtAttr | getFormAttr(3)
        table.insert(formsUnlocked, 3)
      end
    else
      -- Battle form detection - auto-unlock base form
      -- Simplified: assume any formIndex > 0 might be a battle form
      if attributes.isBattleForm then
        entry.caughtAttr = entry.caughtAttr | getFormAttr(0)
        table.insert(formsUnlocked, 0)
      end
    end
  end

  -- Update nature tracking
  if attributes.nature then
    entry.natureAttr = entry.natureAttr | (1 << (attributes.nature + 1))
  end

  -- Update ability unlock for starter species
  local abilityUnlocked = nil
  if starterData and starterData[tostring(speciesId)] and attributes.abilityIndex then
    local starter = starterData[tostring(speciesId)]
    if not starter.abilityAttr then starter.abilityAttr = 0 end

    -- Unlock ability (matches TypeScript logic)
    local abilityBit = 1 << attributes.abilityIndex
    starter.abilityAttr = starter.abilityAttr | abilityBit

    abilityUnlocked = {
      speciesId = speciesId,
      abilityIndex = attributes.abilityIndex,
      abilityAttr = starter.abilityAttr
    }
  end

  -- Initialize stats
  gameStats = initGameStats(gameStats)

  -- Update counts and statistics
  local incrementCount = attributes.incrementCount
  if incrementCount == nil then incrementCount = true end
  local fromEgg = attributes.fromEgg or false

  if incrementCount then
    if not fromEgg then
      entry.caughtCount = entry.caughtCount + 1
      gameStats.pokemonCaught = gameStats.pokemonCaught + 1

      if isSubLegendary(speciesId) then
        gameStats.subLegendaryPokemonCaught = gameStats.subLegendaryPokemonCaught + 1
      elseif isLegendary(speciesId) then
        gameStats.legendaryPokemonCaught = gameStats.legendaryPokemonCaught + 1
      elseif isMythical(speciesId) then
        gameStats.mythicalPokemonCaught = gameStats.mythicalPokemonCaught + 1
      end

      if attributes.shiny then
        gameStats.shinyPokemonCaught = gameStats.shinyPokemonCaught + 1
      end
    else
      entry.hatchedCount = entry.hatchedCount + 1
      gameStats.pokemonHatched = gameStats.pokemonHatched + 1

      if isSubLegendary(speciesId) then
        gameStats.subLegendaryPokemonHatched = gameStats.subLegendaryPokemonHatched + 1
      elseif isLegendary(speciesId) then
        gameStats.legendaryPokemonHatched = gameStats.legendaryPokemonHatched + 1
      elseif isMythical(speciesId) then
        gameStats.mythicalPokemonHatched = gameStats.mythicalPokemonHatched + 1
      end

      if attributes.shiny then
        gameStats.shinyPokemonHatched = gameStats.shinyPokemonHatched + 1
      end
    end
  end

  return {
    speciesId = speciesId,
    registered = true,
    newCatch = newCatch,
    newAttributes = newAttributes,
    formsUnlocked = formsUnlocked,
    dexEntry = entry,
    abilityUnlocked = abilityUnlocked,
    statsUpdated = {
      pokemonCaught = (incrementCount and not fromEgg) and 1 or 0,
      pokemonHatched = (incrementCount and fromEgg) and 1 or 0
    }
  }
end

-- Get complete dex entry for a species
local function getDexEntry(speciesId, dexData)
  local entry = dexData[tostring(speciesId)]

  if not entry then
    return {
      speciesId = speciesId,
      seen = false,
      dexEntry = nil
    }
  end

  -- Parse attribute breakdown
  local breakdown = {
    hasShiny = (entry.seenAttr & DexAttr.SHINY) ~= 0,
    shinyCaught = (entry.caughtAttr & DexAttr.SHINY) ~= 0,
    hasMale = (entry.seenAttr & DexAttr.MALE) ~= 0,
    maleCaught = (entry.caughtAttr & DexAttr.MALE) ~= 0,
    hasFemale = (entry.seenAttr & DexAttr.FEMALE) ~= 0,
    femaleCaught = (entry.caughtAttr & DexAttr.FEMALE) ~= 0
  }

  return {
    speciesId = speciesId,
    seen = true,
    dexEntry = entry,
    attributeBreakdown = breakdown
  }
end

-- Calculate dex progress and milestones
local function getDexProgress(dexData)
  local totalSeen = 0
  local totalCaught = 0
  local legendaryCount = 0
  local mythicalCount = 0
  local shinyCount = 0

  for speciesIdStr, entry in pairs(dexData) do
    local speciesId = tonumber(speciesIdStr)
    if entry.seenAttr > 0 then
      totalSeen = totalSeen + 1
    end
    if entry.caughtAttr > 0 then
      totalCaught = totalCaught + 1

      if isLegendary(speciesId) then
        legendaryCount = legendaryCount + 1
      elseif isMythical(speciesId) then
        mythicalCount = mythicalCount + 1
      end

      if (entry.caughtAttr & DexAttr.SHINY) ~= 0 then
        shinyCount = shinyCount + 1
      end
    end
  end

  local completionPercentage = (totalCaught / MAX_SPECIES_COUNT) * 100

  -- Milestone detection
  local milestones = {
    firstCatch = totalCaught >= 1,
    pokedex_10 = totalCaught >= 10,
    pokedex_50 = totalCaught >= 50,
    pokedex_150 = totalCaught >= 150,
    pokedex_500 = totalCaught >= 500,
    fullCompletion = totalCaught >= MAX_SPECIES_COUNT
  }

  return {
    overall = {
      totalSeen = totalSeen,
      totalCaught = totalCaught,
      completionPercentage = completionPercentage,
      maxSpecies = MAX_SPECIES_COUNT
    },
    milestones = milestones,
    analytics = {
      legendaryCount = legendaryCount,
      mythicalCount = mythicalCount,
      shinyCount = shinyCount
    }
  }
end

-- Validate dex data integrity
local function validateDexData(dexEntries)
  local errors = {}
  local warnings = {}
  local valid = true

  for speciesIdStr, entry in pairs(dexEntries) do
    local speciesId = tonumber(speciesIdStr)

    -- Validate species ID range
    if not speciesId or speciesId < 1 or speciesId > MAX_SPECIES_COUNT then
      table.insert(errors, "Invalid species ID: " .. speciesIdStr)
      valid = false
    end

    -- Validate count consistency
    if entry.seenCount < entry.caughtCount then
      table.insert(errors, "Species " .. speciesId .. ": seenCount < caughtCount")
      valid = false
    end

    -- Validate caught requires seen
    if entry.caughtAttr > 0 and entry.seenAttr == 0 then
      table.insert(errors, "Species " .. speciesId .. ": caught without being seen")
      valid = false
    end

    -- Validate non-negative counts
    if entry.seenCount < 0 or entry.caughtCount < 0 or entry.hatchedCount < 0 then
      table.insert(errors, "Species " .. speciesId .. ": negative count values")
      valid = false
    end

    -- Warning for unusual caught without seen attributes
    if entry.caughtAttr > 0 and (entry.caughtAttr & entry.seenAttr) ~= entry.caughtAttr then
      table.insert(warnings, "Species " .. speciesId .. ": caught attributes not subset of seen attributes")
    end
  end

  local integrityScore = valid and (#warnings == 0 and 100.0 or 90.0) or 0.0

  return {
    valid = valid,
    errors = errors,
    warnings = warnings,
    integrityScore = integrityScore
  }
end

-- ============================================================================
-- AO Message Handlers
-- ============================================================================

-- Handler: RegisterSeen - Mark species as seen
Handlers.add("register-seen",
  Handlers.utils.hasMatchingTag("Action", "RegisterSeen"),
  function(msg)
    local speciesId = tonumber(msg.SpeciesId)
    if not speciesId then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "SpeciesId required"
      })
      return
    end

    -- Parse request data
    local data = json.decode(msg.Data or "{}")
    local dexData = data.dexData or {}
    local gameStats = data.gameStats or {}

    -- Parse attributes
    local attributes = {
      formIndex = data.formIndex or 0,
      gender = data.gender,
      shiny = data.shiny or false,
      variant = data.variant or 0,
      isTrainer = data.isTrainer or false,
      preventStatsUpdate = data.preventStatsUpdate or false,
      incrementCount = data.incrementCount
    }

    -- Register seen
    local result = registerSeen(speciesId, attributes, dexData, gameStats)

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      SpeciesId = tostring(speciesId),
      Data = json.encode({
        result = result,
        dexData = dexData,
        gameStats = gameStats
      })
    })
  end
)

-- Handler: RegisterCaught - Mark species as caught
Handlers.add("register-caught",
  Handlers.utils.hasMatchingTag("Action", "RegisterCaught"),
  function(msg)
    local speciesId = tonumber(msg.SpeciesId)
    if not speciesId then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "SpeciesId required"
      })
      return
    end

    -- Check for rental Pokemon protection
    local data = json.decode(msg.Data or "{}")
    local dexData = data.dexData or {}
    local gameStats = data.gameStats or {}
    local starterData = data.starterData or {}

    -- Rental protection: skip if not incrementCount and species not already caught
    local incrementCount = data.incrementCount
    if incrementCount == nil then incrementCount = true end

    if not incrementCount then
      local entry = dexData[tostring(speciesId)]
      if not entry or entry.caughtAttr == 0 then
        ao.send({
          Target = msg.From,
          Action = "SaveState",
          Success = "true",
          SpeciesId = tostring(speciesId),
          Data = json.encode({
            result = {
              registered = false,
              reason = "rental_protection"
            },
            dexData = dexData,
            gameStats = gameStats
          })
        })
        return
      end
    end

    -- Parse attributes
    local attributes = {
      formIndex = data.formIndex or 0,
      gender = data.gender,
      shiny = data.shiny or false,
      variant = data.variant or 0,
      nature = data.nature,
      abilityIndex = data.abilityIndex,
      fromEgg = data.fromEgg or false,
      incrementCount = incrementCount,
      isBattleForm = data.isBattleForm or false,
      pikachuFormIndex = data.pikachuFormIndex
    }

    -- Register caught
    local result = registerCaught(speciesId, attributes, dexData, gameStats, starterData)

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      SpeciesId = tostring(speciesId),
      Data = json.encode({
        result = result,
        dexData = dexData,
        gameStats = gameStats,
        starterData = starterData
      })
    })
  end
)

-- Handler: GetDexEntry - Retrieve complete dex entry for species
Handlers.add("get-dex-entry",
  Handlers.utils.hasMatchingTag("Action", "GetDexEntry"),
  function(msg)
    local speciesId = tonumber(msg.SpeciesId)
    if not speciesId then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "SpeciesId required"
      })
      return
    end

    local data = json.decode(msg.Data or "{}")
    local dexData = data.dexData or {}

    local result = getDexEntry(speciesId, dexData)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      SpeciesId = tostring(speciesId),
      Data = json.encode(result)
    })
  end
)

-- Handler: GetDexProgress - Calculate completion statistics
Handlers.add("get-dex-progress",
  Handlers.utils.hasMatchingTag("Action", "GetDexProgress"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local dexData = data.dexData or {}

    local result = getDexProgress(dexData)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: ValidateDexData - Verify data integrity
Handlers.add("validate-dex-data",
  Handlers.utils.hasMatchingTag("Action", "ValidateDexData"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local dexEntries = data.dexEntries or {}

    local result = validateDexData(dexEntries)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: Info - ADP v1.0 self-documentation
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        process = {
          name = "Pokedex Registration Engine",
          version = "1.0.0",
          adpVersion = "1.0",
          description = "Stateless Pokemon species discovery and registration system with attribute tracking",
          capabilities = {
            "species_seen_registration",
            "species_caught_registration",
            "attribute_bitmasking",
            "form_unlock_logic",
            "nature_tracking",
            "ability_unlock",
            "progress_calculation",
            "data_validation"
          }
        },
        handlers = {
          "RegisterSeen",
          "RegisterCaught",
          "GetDexEntry",
          "GetDexProgress",
          "ValidateDexData",
          "Info"
        },
        schemas = {
          RegisterSeen = {
            tags = {"Action", "SpeciesId"},
            data = {"formIndex", "gender", "shiny", "variant", "isTrainer", "preventStatsUpdate", "dexData", "gameStats"}
          },
          RegisterCaught = {
            tags = {"Action", "SpeciesId"},
            data = {"formIndex", "gender", "shiny", "variant", "nature", "abilityIndex", "fromEgg", "incrementCount", "dexData", "gameStats", "starterData"}
          },
          GetDexEntry = {
            tags = {"Action", "SpeciesId"},
            data = {"dexData"}
          },
          GetDexProgress = {
            tags = {"Action"},
            data = {"dexData"}
          },
          ValidateDexData = {
            tags = {"Action"},
            data = {"dexEntries"}
          }
        }
      })
    })
  end
)
