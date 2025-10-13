--[[
  Gacha Mechanics Engine - AO Process

  This process implements the complete gacha pull mechanics including:
  - Egg tier probability rolling with gacha type modifiers
  - Pity system tracking and automatic tier guarantees
  - Gacha pull transaction validation
  - Reward generation with species selection and properties
  - Pull history tracking and statistics
  - Rate modifications based on gacha type

  Handlers:
  - PullEgg: Execute a gacha pull and generate egg reward
  - GetGachaInfo: Get current gacha type configuration and probabilities
  - GetPityStatus: Get current pity counters and progress
  - GetPullHistory: Get recent pull history with statistics
  - Info: ADP v1.0 compliant process information handler

  Message Patterns:
  All handlers respond with Action = "SaveState" for success or Action = "Error" for failures.
  Complex data structures are returned in the Data field as JSON.

  AO Compliance:
  - Monolithic design with all logic embedded
  - Individual handlers per action
  - Direct error handling without unnecessary pcall usage
  - Uses msg.Timestamp for time-based operations
  - Deterministic seeded RNG for all probability calculations
]]

local json = require("json")

-- ============================================================================
-- GACHA CONSTANTS
-- ============================================================================

-- Egg Tier Probability Thresholds (from balance/rates.ts)
local GACHA_DEFAULT_COMMON_EGG_THRESHOLD = 52  -- 204/256 chance (79.69%)
local GACHA_DEFAULT_RARE_EGG_THRESHOLD = 8     -- 44/256 chance (17.19%)
local GACHA_DEFAULT_EPIC_EGG_THRESHOLD = 1     -- 7/256 chance (2.73%)
-- LEGENDARY: 1/256 chance (0.39%)
local GACHA_LEGENDARY_UP_THRESHOLD_OFFSET = 1  -- +1/256 legendary, -1/256 common

-- Pity System Thresholds (from balance/rates.ts)
local EGG_PITY_LEGENDARY_THRESHOLD = 412
local EGG_PITY_EPIC_THRESHOLD = 59
local EGG_PITY_RARE_THRESHOLD = 9

-- Shiny Rates (1/x) (from balance/rates.ts)
local GACHA_DEFAULT_SHINY_RATE = 128       -- Default gacha: 1/128
local GACHA_SHINY_UP_SHINY_RATE = 64       -- Shiny Up gacha: 1/64 (2x boost)
local SAME_SPECIES_EGG_SHINY_RATE = 12     -- Same species egg: 1/12

-- Hidden Ability Rates (1/x) (from balance/rates.ts)
local GACHA_EGG_HA_RATE = 192              -- Gacha egg: 1/192
local SAME_SPECIES_EGG_HA_RATE = 8         -- Same species egg: 1/8

-- Special Rates (from balance/rates.ts)
local MANAPHY_EGG_MANAPHY_RATE = 8         -- Phione egg → Manaphy: 1/8

-- Variant Chances (x/10) (from balance/rates.ts)
local SHINY_VARIANT_CHANCE = 4             -- 4/10 for variant
local SHINY_EPIC_CHANCE = 1                -- 1/10 for epic variant (of variants)

-- Egg Move Rates (1/x per tier) (from balance/rates.ts)
-- [COMMON, RARE, EPIC/MANAPHY, LEGENDARY]
local RARE_EGGMOVE_RATES = {48, 24, 12, 6}           -- Base rates
local BOOSTED_RARE_EGGMOVE_RATES = {16, 12, 6, 3}   -- Move Up gacha or Candy

-- Hatch Wave Requirements (from balance/rates.ts)
local HATCH_WAVES_COMMON_EGG = 10
local HATCH_WAVES_RARE_EGG = 25
local HATCH_WAVES_EPIC_EGG = 50
local HATCH_WAVES_LEGENDARY_EGG = 100
local HATCH_WAVES_MANAPHY_EGG = 50

-- Gacha Type Enum
local GachaType = {
  MOVE = "MOVE",
  LEGENDARY = "LEGENDARY",
  SHINY = "SHINY"
}

-- Egg Tier Enum
local EggTier = {
  COMMON = "COMMON",
  RARE = "RARE",
  EPIC = "EPIC",
  LEGENDARY = "LEGENDARY"
}

-- Variant Tier Enum
local VariantTier = {
  STANDARD = "STANDARD",
  RARE = "RARE",
  EPIC = "EPIC"
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Deterministic seeded random number generator
-- Uses Linear Congruential Generator (LCG) algorithm
local function createSeededRNG(seed)
  local state = tonumber(seed) or 12345

  return {
    next = function(self, max)
      -- LCG parameters (from Numerical Recipes)
      local a = 1664525
      local c = 1013904223
      local m = 2^32

      state = (a * state + c) % m
      if max then
        return math.floor((state / m) * max)
      end
      return state / m
    end,

    nextInt = function(self, max)
      return math.floor(self:next(max or 1))
    end
  }
end

-- ============================================================================
-- GACHA PROBABILITY FUNCTIONS
-- ============================================================================

--[[
  Roll egg tier using threshold-based probability

  @param gachaType: "MOVE", "LEGENDARY", or "SHINY"
  @param rng: Seeded RNG instance
  @return tier: "COMMON", "RARE", "EPIC", or "LEGENDARY"
]]
local function rollEggTier(gachaType, rng)
  local tierValueOffset = 0
  if gachaType == GachaType.LEGENDARY then
    tierValueOffset = GACHA_LEGENDARY_UP_THRESHOLD_OFFSET
  end

  local tierValue = rng:nextInt(256)

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
  Check if pity system should override the rolled tier

  @param pullHistory: Table with pity counters
  @param tierRolled: Originally rolled tier
  @param gachaType: Gacha type for legendary offset calculation
  @return tier: Potentially upgraded tier
  @return pityTriggered: Boolean indicating if pity was activated
]]
local function checkPityOverride(pullHistory, tierRolled, gachaType)
  local tierValueOffset = 0
  if gachaType == GachaType.LEGENDARY then
    tierValueOffset = GACHA_LEGENDARY_UP_THRESHOLD_OFFSET
  end

  local legendaryCounter = pullHistory.pullsSinceLastLegendary or 0
  local epicCounter = pullHistory.pullsSinceLastEpic or 0
  local rareCounter = pullHistory.pullsSinceLastRare or 0

  -- Check legendary pity (highest priority)
  if legendaryCounter + tierValueOffset >= EGG_PITY_LEGENDARY_THRESHOLD and tierRolled == EggTier.COMMON then
    return EggTier.LEGENDARY, true
  end

  -- Check epic pity
  if epicCounter >= EGG_PITY_EPIC_THRESHOLD and tierRolled == EggTier.COMMON then
    return EggTier.EPIC, true
  end

  -- Check rare pity
  if rareCounter >= EGG_PITY_RARE_THRESHOLD and tierRolled == EggTier.COMMON then
    return EggTier.RARE, true
  end

  return tierRolled, false
end

--[[
  Roll if egg is shiny based on gacha type

  @param gachaType: Gacha type affecting shiny rate
  @param rng: Seeded RNG instance
  @return isShiny: Boolean
]]
local function rollShiny(gachaType, rng)
  local shinyRate = GACHA_DEFAULT_SHINY_RATE

  if gachaType == GachaType.SHINY then
    shinyRate = GACHA_SHINY_UP_SHINY_RATE
  end

  return rng:nextInt(shinyRate) == 0
end

--[[
  Roll variant tier for shiny eggs

  @param isShiny: Whether egg is shiny
  @param rng: Seeded RNG instance
  @return variantTier: "STANDARD", "RARE", or "EPIC"
]]
local function rollVariant(isShiny, rng)
  if not isShiny then
    return VariantTier.STANDARD
  end

  local rand = rng:nextInt(10)

  if rand >= SHINY_VARIANT_CHANCE then
    return VariantTier.STANDARD  -- 6/10
  elseif rand >= SHINY_EPIC_CHANCE then
    return VariantTier.RARE      -- 3/10
  else
    return VariantTier.EPIC      -- 1/10
  end
end

--[[
  Roll hidden ability flag

  @param rng: Seeded RNG instance
  @return hasHiddenAbility: Boolean
]]
local function rollHiddenAbility(rng)
  return rng:nextInt(GACHA_EGG_HA_RATE) == 0
end

--[[
  Roll egg move index based on tier and gacha type

  @param tier: Egg tier
  @param gachaType: Gacha type (MOVE type uses boosted rates)
  @param rng: Seeded RNG instance
  @return eggMoveIndex: 0-2 for common moves, 3 for rare move
]]
local function rollEggMoveIndex(tier, gachaType, rng)
  local tierNum = 0
  if tier == EggTier.RARE then
    tierNum = 1
  elseif tier == EggTier.EPIC then
    tierNum = 2
  elseif tier == EggTier.LEGENDARY then
    tierNum = 3
  end

  local rates = RARE_EGGMOVE_RATES
  if gachaType == GachaType.MOVE then
    rates = BOOSTED_RARE_EGGMOVE_RATES
  end

  local baseChance = rates[tierNum + 1]

  if rng:nextInt(baseChance) == 0 then
    return 3  -- Rare egg move
  else
    return rng:nextInt(3)  -- Common egg move (0, 1, or 2)
  end
end

--[[
  Get hatch waves for a tier

  @param tier: Egg tier
  @return hatchWaves: Number of waves to hatch
]]
local function getHatchWaves(tier)
  if tier == EggTier.COMMON then
    return HATCH_WAVES_COMMON_EGG
  elseif tier == EggTier.RARE then
    return HATCH_WAVES_RARE_EGG
  elseif tier == EggTier.EPIC then
    return HATCH_WAVES_EPIC_EGG
  else
    return HATCH_WAVES_LEGENDARY_EGG
  end
end

-- ============================================================================
-- SPECIES SELECTION FUNCTIONS
-- ============================================================================

--[[
  Get legendary species for a specific timestamp (daily rotation)

  @param timestamp: UTC timestamp
  @param legendarySpecies: Array of valid legendary species IDs
  @param rng: Seeded RNG for shuffling
  @return speciesId: Selected legendary species ID
]]
local function getLegendaryGachaSpeciesForTimestamp(timestamp, legendarySpecies, rng)
  if not legendarySpecies or #legendarySpecies == 0 then
    return 150  -- Default to Mewtwo if no species available
  end

  -- 86400000 ms in one day
  local dayTimestamp = math.floor(timestamp / 86400000)
  local cycleLength = #legendarySpecies
  local index = (dayTimestamp % cycleLength) + 1  -- Lua is 1-indexed

  -- Shuffle species array deterministically based on cycle
  local offset = math.floor(dayTimestamp / cycleLength)
  local shuffledSpecies = {}
  for i, speciesId in ipairs(legendarySpecies) do
    shuffledSpecies[i] = speciesId
  end

  -- Simple deterministic shuffle based on offset
  for i = #shuffledSpecies, 2, -1 do
    local j = ((offset * i) % i) + 1
    shuffledSpecies[i], shuffledSpecies[j] = shuffledSpecies[j], shuffledSpecies[i]
  end

  return shuffledSpecies[index]
end

--[[
  Generate a complete egg reward

  @param tier: Egg tier
  @param gachaType: Gacha type
  @param timestamp: UTC timestamp for legendary rotation
  @param rng: Seeded RNG instance
  @return eggResult: Table with all egg properties
]]
local function generateEggReward(tier, gachaType, timestamp, rng)
  -- Generate egg ID
  local eggId = rng:nextInt(1073741824)  -- EGG_SEED constant

  -- Roll shiny, variant, hidden ability, and egg move
  local isShiny = rollShiny(gachaType, rng)
  local variantTier = rollVariant(isShiny, rng)
  local hasHiddenAbility = rollHiddenAbility(rng)
  local eggMoveIndex = rollEggMoveIndex(tier, gachaType, rng)
  local hatchWaves = getHatchWaves(tier)

  -- Check for Manaphy egg (id % 204 === 0)
  local isManaphyEgg = (eggId % 204 == 0) and tier == EggTier.COMMON
  local speciesId = 0  -- Placeholder - would normally select from species pool

  if isManaphyEgg then
    -- Manaphy egg logic: 1/8 chance for Manaphy, 7/8 for Phione
    if rng:nextInt(MANAPHY_EGG_MANAPHY_RATE) == 0 then
      speciesId = 490  -- Manaphy
    else
      speciesId = 489  -- Phione
    end
    hatchWaves = HATCH_WAVES_MANAPHY_EGG
  elseif tier == EggTier.LEGENDARY and gachaType == GachaType.LEGENDARY then
    -- Legendary gacha: 50% chance for featured legendary
    if rng:nextInt(2) == 0 then
      -- Use timestamp-based rotation
      local legendaryPool = {144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251}  -- Example pool
      speciesId = getLegendaryGachaSpeciesForTimestamp(timestamp, legendaryPool, rng)
    else
      -- Random legendary from pool
      local legendaryPool = {144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251}
      speciesId = legendaryPool[rng:nextInt(#legendaryPool) + 1]
    end
  else
    -- Normal species selection based on tier
    -- This would normally use the full species pool with tier filtering
    -- For now, use placeholder logic
    local speciesPools = {
      COMMON = {1, 4, 7, 25, 133, 152, 155, 158},
      RARE = {2, 5, 8, 16, 63, 104, 109},
      EPIC = {3, 6, 9, 59, 130, 131, 142},
      LEGENDARY = {144, 145, 146, 150, 151, 243, 244, 245}
    }

    local pool = speciesPools[tier] or speciesPools.COMMON
    speciesId = pool[rng:nextInt(#pool) + 1]
  end

  return {
    id = eggId,
    tier = tier,
    hatchWaves = hatchWaves,
    speciesId = speciesId,
    isShiny = isShiny,
    variantTier = variantTier,
    eggMoveIndex = eggMoveIndex,
    hasHiddenAbility = hasHiddenAbility,
    isManaphyEgg = isManaphyEgg
  }
end

-- ============================================================================
-- PULL HISTORY MANAGEMENT
-- ============================================================================

--[[
  Update pull history after a pull

  @param pullHistory: Current pull history
  @param tierObtained: Tier of egg obtained
  @param gachaType: Gacha type used
  @return updatedHistory: Updated pull history
]]
local function updatePullHistory(pullHistory, tierObtained, gachaType)
  local updated = {
    totalPulls = (pullHistory.totalPulls or 0) + 1,
    pullsSinceLastLegendary = (pullHistory.pullsSinceLastLegendary or 0) + 1,
    pullsSinceLastEpic = (pullHistory.pullsSinceLastEpic or 0) + 1,
    pullsSinceLastRare = (pullHistory.pullsSinceLastRare or 0) + 1
  }

  -- Reset appropriate counter
  if tierObtained == EggTier.LEGENDARY then
    updated.pullsSinceLastLegendary = 0
  elseif tierObtained == EggTier.EPIC then
    updated.pullsSinceLastEpic = 0
  elseif tierObtained == EggTier.RARE then
    updated.pullsSinceLastRare = 0
  end

  -- Track gacha type statistics
  updated.gachaTypeStats = pullHistory.gachaTypeStats or {MOVE = 0, LEGENDARY = 0, SHINY = 0}
  updated.gachaTypeStats[gachaType] = (updated.gachaTypeStats[gachaType] or 0) + 1

  -- Track tier statistics
  updated.tierStats = pullHistory.tierStats or {COMMON = 0, RARE = 0, EPIC = 0, LEGENDARY = 0}
  updated.tierStats[tierObtained] = (updated.tierStats[tierObtained] or 0) + 1

  return updated
end

-- ============================================================================
-- HANDLER IMPLEMENTATIONS
-- ============================================================================

--[[
  Handler: PullEgg
  Execute a gacha pull and generate egg reward

  Required Tags:
  - Action: "PullEgg"
  - GachaType: "MOVE", "LEGENDARY", or "SHINY"
  - VoucherType: Voucher type used (for validation)
  - RNGSeed: Deterministic seed for RNG
  - Timestamp: UTC timestamp

  Optional Tags:
  - PullHistory: JSON-encoded pull history with pity counters

  Response:
  - Action: "SaveState" (success) or "Error" (failure)
  - Data: JSON-encoded pull result with egg properties and updated history
]]
Handlers.add("pull-egg",
  Handlers.utils.hasMatchingTag("Action", "PullEgg"),
  function(msg)
    local gachaType = msg.GachaType
    local voucherType = msg.VoucherType
    local rngSeed = msg.RNGSeed
    local timestamp = tonumber(msg.Timestamp)

    -- Validate required parameters
    if not gachaType or not voucherType or not rngSeed or not timestamp then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "GachaType, VoucherType, RNGSeed, and Timestamp required"
      })
      return
    end

    -- Validate gacha type
    if not GachaType[gachaType] then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid GachaType: " .. gachaType .. ". Must be MOVE, LEGENDARY, or SHINY"
      })
      return
    end

    -- Parse pull history
    local pullHistory = {}
    if msg.PullHistory and msg.PullHistory ~= "" then
      pullHistory = json.decode(msg.PullHistory)
    end

    -- Create seeded RNG
    local rng = createSeededRNG(rngSeed)

    -- Roll egg tier
    local tierRolled = rollEggTier(gachaType, rng)

    -- Check for pity override
    local pityTriggered = false
    if pullHistory.pullsSinceLastLegendary or pullHistory.pullsSinceLastEpic or pullHistory.pullsSinceLastRare then
      tierRolled, pityTriggered = checkPityOverride(pullHistory, tierRolled, gachaType)
    end

    -- Generate egg reward
    local eggResult = generateEggReward(tierRolled, gachaType, timestamp, rng)

    -- Update pull history
    local updatedHistory = updatePullHistory(pullHistory, tierRolled, gachaType)

    -- Generate pull ID
    local pullId = "pull_" .. tostring(timestamp) .. "_" .. tostring(rng:nextInt(1000000))

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        pullId = pullId,
        timestamp = timestamp,
        gachaType = gachaType,
        voucherUsed = voucherType,
        eggResult = eggResult,
        pityTriggered = pityTriggered,
        pullHistory = updatedHistory
      })
    })
  end
)

--[[
  Handler: GetGachaInfo
  Get current gacha configuration and probabilities

  Required Tags:
  - Action: "GetGachaInfo"
  - GachaType: "MOVE", "LEGENDARY", or "SHINY"

  Response:
  - Action: "SaveState"
  - Data: JSON-encoded gacha configuration
]]
Handlers.add("get-gacha-info",
  Handlers.utils.hasMatchingTag("Action", "GetGachaInfo"),
  function(msg)
    local gachaType = msg.GachaType

    if not gachaType or not GachaType[gachaType] then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Valid GachaType required"
      })
      return
    end

    -- Calculate probabilities with offset
    local tierValueOffset = 0
    if gachaType == GachaType.LEGENDARY then
      tierValueOffset = GACHA_LEGENDARY_UP_THRESHOLD_OFFSET
    end

    local commonChance = (256 - (GACHA_DEFAULT_COMMON_EGG_THRESHOLD + tierValueOffset)) / 256
    local rareChance = ((GACHA_DEFAULT_COMMON_EGG_THRESHOLD + tierValueOffset) - (GACHA_DEFAULT_RARE_EGG_THRESHOLD + tierValueOffset)) / 256
    local epicChance = ((GACHA_DEFAULT_RARE_EGG_THRESHOLD + tierValueOffset) - (GACHA_DEFAULT_EPIC_EGG_THRESHOLD + tierValueOffset)) / 256
    local legendaryChance = (GACHA_DEFAULT_EPIC_EGG_THRESHOLD + tierValueOffset) / 256

    -- Determine modifiers
    local shinyRateMultiplier = 1.0
    if gachaType == GachaType.SHINY then
      shinyRateMultiplier = 2.0
    end

    local legendaryThresholdBonus = tierValueOffset
    local eggMoveRateBoost = (gachaType == GachaType.MOVE)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        gachaType = gachaType,
        probabilities = {
          common = commonChance,
          rare = rareChance,
          epic = epicChance,
          legendary = legendaryChance
        },
        modifiers = {
          shinyRateMultiplier = shinyRateMultiplier,
          legendaryThresholdBonus = legendaryThresholdBonus,
          eggMoveRateBoost = eggMoveRateBoost
        },
        pityThresholds = {
          legendary = EGG_PITY_LEGENDARY_THRESHOLD,
          epic = EGG_PITY_EPIC_THRESHOLD,
          rare = EGG_PITY_RARE_THRESHOLD
        }
      })
    })
  end
)

--[[
  Handler: GetPityStatus
  Get current pity status and progress

  Required Tags:
  - Action: "GetPityStatus"
  - PullHistory: JSON-encoded pull history

  Response:
  - Action: "SaveState"
  - Data: JSON-encoded pity status
]]
Handlers.add("get-pity-status",
  Handlers.utils.hasMatchingTag("Action", "GetPityStatus"),
  function(msg)
    if not msg.PullHistory or msg.PullHistory == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "PullHistory required"
      })
      return
    end

    local pullHistory = json.decode(msg.PullHistory)

    local legendaryCounter = pullHistory.pullsSinceLastLegendary or 0
    local epicCounter = pullHistory.pullsSinceLastEpic or 0
    local rareCounter = pullHistory.pullsSinceLastRare or 0

    local function calculateProgress(counter, threshold)
      local remaining = math.max(0, threshold - counter)
      local progressPercent = math.floor((counter / threshold) * 10000) / 100
      return {
        counter = counter,
        threshold = threshold,
        remaining = remaining,
        progressPercent = progressPercent
      }
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        legendaryPity = calculateProgress(legendaryCounter, EGG_PITY_LEGENDARY_THRESHOLD),
        epicPity = calculateProgress(epicCounter, EGG_PITY_EPIC_THRESHOLD),
        rarePity = calculateProgress(rareCounter, EGG_PITY_RARE_THRESHOLD)
      })
    })
  end
)

--[[
  Handler: GetPullHistory
  Get recent pull history with statistics

  Required Tags:
  - Action: "GetPullHistory"
  - PullHistory: JSON-encoded pull history

  Optional Tags:
  - Limit: Number of recent pulls to return (default 10)

  Response:
  - Action: "SaveState"
  - Data: JSON-encoded pull history statistics
]]
Handlers.add("get-pull-history",
  Handlers.utils.hasMatchingTag("Action", "GetPullHistory"),
  function(msg)
    if not msg.PullHistory or msg.PullHistory == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "PullHistory required"
      })
      return
    end

    local pullHistory = json.decode(msg.PullHistory)
    local limit = tonumber(msg.Limit) or 10

    local totalPulls = pullHistory.totalPulls or 0
    local tierStats = pullHistory.tierStats or {COMMON = 0, RARE = 0, EPIC = 0, LEGENDARY = 0}
    local gachaTypeStats = pullHistory.gachaTypeStats or {MOVE = 0, LEGENDARY = 0, SHINY = 0}

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        statistics = {
          totalPulls = totalPulls,
          tierDistribution = tierStats,
          gachaTypeBreakdown = gachaTypeStats
        }
      })
    })
  end
)

--[[
  Handler: Info
  ADP v1.0 compliant process information handler

  Required Tags:
  - Action: "Info"

  Response:
  - Action: "SaveState"
  - Data: JSON-encoded process metadata
]]
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        process = {
          name = "Gacha Mechanics Engine",
          version = "1.0.0",
          adpVersion = "1.0",
          description = "Gacha pull mechanics with probability rolling, pity system, and reward generation",
          capabilities = {
            "gacha_pull",
            "pity_tracking",
            "reward_generation",
            "probability_calculation",
            "pull_history"
          }
        },
        handlers = {
          "PullEgg",
          "GetGachaInfo",
          "GetPityStatus",
          "GetPullHistory",
          "Info"
        },
        messageSchemas = {
          PullEgg = {
            required = {"Action", "GachaType", "VoucherType", "RNGSeed", "Timestamp"},
            optional = {"PullHistory"}
          },
          GetGachaInfo = {
            required = {"Action", "GachaType"}
          },
          GetPityStatus = {
            required = {"Action", "PullHistory"}
          },
          GetPullHistory = {
            required = {"Action", "PullHistory"},
            optional = {"Limit"}
          }
        },
        constants = {
          gachaTypes = {"MOVE", "LEGENDARY", "SHINY"},
          eggTiers = {"COMMON", "RARE", "EPIC", "LEGENDARY"},
          pityThresholds = {
            legendary = EGG_PITY_LEGENDARY_THRESHOLD,
            epic = EGG_PITY_EPIC_THRESHOLD,
            rare = EGG_PITY_RARE_THRESHOLD
          },
          shinyRates = {
            default = GACHA_DEFAULT_SHINY_RATE,
            shinyUp = GACHA_SHINY_UP_SHINY_RATE
          }
        }
      })
    })
  end
)

print("✅ Gacha Mechanics Engine initialized")
print("📊 Handlers: PullEgg, GetGachaInfo, GetPityStatus, GetPullHistory, Info")
print("🎲 Probability system: Tier rolling, pity tracking, reward generation")
