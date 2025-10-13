--[[
  Collection Statistics Engine - Stateless AO Process

  Handles Pokemon collection progress calculation and statistical analysis including:
  - Progress calculation: completion percentages, regional tracking, milestones
  - Statistical analysis: capture rates, encounter stats, success rates
  - Visualization data generation: chart-ready formats with labels
  - Analytics engine: velocity, projections, trend detection
  - Progress comparison: rankings, percentiles, peer analysis
  - Historical persistence: statistics snapshots over time
  - Validation: data integrity, bounds checking

  Process follows AO monolithic design with ADP v1.0 compliance.

  === Message Schemas ===

  CalculateProgress:
    Tags: Action="CalculateProgress"
    Data: JSON{dexData, starterData}
    Response: SaveState with completion percentages and milestone status

  GenerateStatistics:
    Tags: Action="GenerateStatistics"
    Data: JSON{gameStats, captureData}
    Response: SaveState with comprehensive statistical metrics

  GetVisualizationData:
    Tags: Action="GetVisualizationData"
    Data: JSON{progressData, statsData}
    Response: SaveState with chart-ready data formats

  AnalyzeTrends:
    Tags: Action="AnalyzeTrends"
    Data: JSON{historicalData, timeWindow}
    Response: SaveState with trend analysis and projections

  CompareProgress:
    Tags: Action="CompareProgress"
    Data: JSON{playerData, peerData}
    Response: SaveState with rankings and percentiles

  ValidateStatistics:
    Tags: Action="ValidateStatistics"
    Data: JSON{statisticsData}
    Response: SaveState with validation results and integrity score

  Info:
    Tags: Action="Info"
    Response: SaveState with process capabilities and handler list
]]

local json = require("json")

-- ============================================================================
-- Constants and Data Structures
-- ============================================================================

-- Maximum species count for progress calculation
local MAX_SPECIES_COUNT = 1025

-- Region definitions with species ranges
local REGIONS = {
  kanto = {start = 1, finish = 151, total = 151},
  johto = {start = 152, finish = 251, total = 100},
  hoenn = {start = 252, finish = 386, total = 135},
  sinnoh = {start = 387, finish = 493, total = 107},
  unova = {start = 494, finish = 649, total = 156},
  kalos = {start = 650, finish = 721, total = 72},
  alola = {start = 722, finish = 802, total = 81},
  galar = {start = 803, finish = 891, total = 89},
  paldea = {start = 892, finish = 1025, total = 103}
}

-- Milestone thresholds
local MILESTONES = {
  first_catch = 1,
  pokedex_10 = 10,
  pokedex_50 = 50,
  pokedex_150 = 150,
  pokedex_500 = 500,
  pokedex_1000 = 1000
}

-- Decimal precision for percentage formatting
local PERCENTAGE_DECIMALS = 2

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Calculate completion percentage with zero-division protection
local function calculateCompletionPercentage(caught, total)
  if total == 0 then return 0.0 end
  return (caught / total) * 100.0
end

-- Calculate success rate (0.0 to 1.0)
local function calculateSuccessRate(successes, attempts)
  if attempts == 0 then return 0.0 end
  return successes / attempts
end

-- Format percentage for display with specified decimal places
local function formatPercentage(value, decimals)
  decimals = decimals or PERCENTAGE_DECIMALS
  local multiplier = 10 ^ decimals
  return math.floor(value * multiplier + 0.5) / multiplier
end

-- Get region for species ID
local function getRegionForSpecies(speciesId)
  for regionName, range in pairs(REGIONS) do
    if speciesId >= range.start and speciesId <= range.finish then
      return regionName
    end
  end
  return nil
end

-- Count species in dexData matching predicate
local function countSpecies(dexData, predicate)
  local count = 0
  for speciesIdStr, entry in pairs(dexData) do
    if predicate(entry) then
      count = count + 1
    end
  end
  return count
end

-- Detect milestone completion
local function detectMilestone(count, threshold)
  return count >= threshold
end

-- Validate percentage bounds (0.0 to 100.0)
local function isValidPercentage(value)
  return value >= 0.0 and value <= 100.0
end

-- Validate non-negative count
local function isValidCount(value)
  return value >= 0
end

-- ============================================================================
-- Progress Calculation (AC: 1)
-- ============================================================================

-- Calculate overall and regional progress with milestone detection
local function calculateProgress(dexData, starterData)
  dexData = dexData or {}
  starterData = starterData or {}

  -- Overall progress
  local totalSeen = countSpecies(dexData, function(entry) return entry.seenAttr and entry.seenAttr > 0 end)
  local totalCaught = countSpecies(dexData, function(entry) return entry.caughtAttr and entry.caughtAttr > 0 end)
  local completionPercentage = formatPercentage(calculateCompletionPercentage(totalCaught, MAX_SPECIES_COUNT))

  -- Regional progress
  local regionalProgress = {}
  for regionName, range in pairs(REGIONS) do
    local regionSeen = 0
    local regionCaught = 0

    for speciesId = range.start, range.finish do
      local entry = dexData[tostring(speciesId)]
      if entry then
        if entry.seenAttr and entry.seenAttr > 0 then
          regionSeen = regionSeen + 1
        end
        if entry.caughtAttr and entry.caughtAttr > 0 then
          regionCaught = regionCaught + 1
        end
      end
    end

    regionalProgress[regionName] = {
      seen = regionSeen,
      caught = regionCaught,
      total = range.total,
      percentage = formatPercentage(calculateCompletionPercentage(regionCaught, range.total))
    }
  end

  -- Starter progress
  local starterCount = 0
  local shinyStarterCount = 0
  local totalStarters = 0

  for speciesIdStr, starterEntry in pairs(starterData) do
    totalStarters = totalStarters + 1
    if starterEntry.caughtAttr and starterEntry.caughtAttr > 0 then
      starterCount = starterCount + 1
      -- Check for shiny (bit 1 = SHINY)
      if (starterEntry.caughtAttr & 2) ~= 0 then
        shinyStarterCount = shinyStarterCount + 1
      end
    end
  end

  local starterUnlockPercentage = totalStarters > 0 and
    formatPercentage(calculateCompletionPercentage(starterCount, totalStarters)) or 0.0
  local shinyStarterPercentage = totalStarters > 0 and
    formatPercentage(calculateCompletionPercentage(shinyStarterCount, totalStarters)) or 0.0

  -- Milestone detection
  local milestones = {
    first_catch = detectMilestone(totalCaught, MILESTONES.first_catch),
    pokedex_10 = detectMilestone(totalCaught, MILESTONES.pokedex_10),
    pokedex_50 = detectMilestone(totalCaught, MILESTONES.pokedex_50),
    pokedex_150 = detectMilestone(totalCaught, MILESTONES.pokedex_150),
    pokedex_500 = detectMilestone(totalCaught, MILESTONES.pokedex_500),
    pokedex_1000 = detectMilestone(totalCaught, MILESTONES.pokedex_1000),
    kanto_completion = regionalProgress.kanto and detectMilestone(regionalProgress.kanto.caught, regionalProgress.kanto.total)
  }

  return {
    overall = {
      totalSeen = totalSeen,
      totalCaught = totalCaught,
      completionPercentage = completionPercentage,
      maxSpecies = MAX_SPECIES_COUNT
    },
    regional = regionalProgress,
    starters = {
      unlockedCount = starterCount,
      unlockPercentage = starterUnlockPercentage,
      shinyUnlockedCount = shinyStarterCount,
      shinyPercentage = shinyStarterPercentage,
      totalStarters = totalStarters
    },
    milestones = milestones
  }
end

-- ============================================================================
-- Statistical Analysis (AC: 2)
-- ============================================================================

-- Generate comprehensive statistics from game data
local function generateStatistics(gameStats, captureData)
  gameStats = gameStats or {}
  captureData = captureData or {}

  -- Initialize stats with defaults
  local pokemonSeen = gameStats.pokemonSeen or 0
  local pokemonCaught = gameStats.pokemonCaught or 0
  local pokemonHatched = gameStats.pokemonHatched or 0

  -- Capture statistics
  local captureAttempts = captureData.totalAttempts or 0
  local captureSuccesses = pokemonCaught
  local criticalCaptures = captureData.criticalCaptures or 0
  local escapeCount = captureData.escapeCount or 0

  local successRate = formatPercentage(calculateSuccessRate(captureSuccesses, captureAttempts) * 100)
  local averageAttempts = captureSuccesses > 0 and (captureAttempts / captureSuccesses) or 0.0
  averageAttempts = formatPercentage(averageAttempts)

  local captureStats = {
    totalAttempts = captureAttempts,
    successfulCaptures = captureSuccesses,
    successRate = successRate,
    criticalCaptures = criticalCaptures,
    escapeCount = escapeCount,
    averageAttempts = averageAttempts
  }

  -- Encounter statistics
  local totalEncounters = pokemonSeen
  local uniqueSpecies = pokemonSeen
  local shinyEncounters = gameStats.shinyPokemonSeen or 0
  local shinyRate = totalEncounters > 0 and (shinyEncounters / totalEncounters) or 0.0

  local encounterStats = {
    totalEncounters = totalEncounters,
    uniqueSpecies = uniqueSpecies,
    shinyEncounters = shinyEncounters,
    shinyRate = formatPercentage(shinyRate * 100)
  }

  -- Legendary/mythical/shiny tracking
  local legendaryStats = {
    legendaryPokemonSeen = gameStats.legendaryPokemonSeen or 0,
    legendaryPokemonCaught = gameStats.legendaryPokemonCaught or 0,
    legendaryPokemonHatched = gameStats.legendaryPokemonHatched or 0,
    subLegendaryPokemonSeen = gameStats.subLegendaryPokemonSeen or 0,
    subLegendaryPokemonCaught = gameStats.subLegendaryPokemonCaught or 0,
    subLegendaryPokemonHatched = gameStats.subLegendaryPokemonHatched or 0,
    mythicalPokemonSeen = gameStats.mythicalPokemonSeen or 0,
    mythicalPokemonCaught = gameStats.mythicalPokemonCaught or 0,
    mythicalPokemonHatched = gameStats.mythicalPokemonHatched or 0,
    shinyPokemonSeen = shinyEncounters,
    shinyPokemonCaught = gameStats.shinyPokemonCaught or 0,
    shinyPokemonHatched = gameStats.shinyPokemonHatched or 0
  }

  -- Session statistics
  local sessionStats = {
    classicSessionsPlayed = gameStats.classicSessionsPlayed or 0,
    sessionsWon = gameStats.sessionsWon or 0,
    dailyRunSessionsPlayed = gameStats.dailyRunSessionsPlayed or 0,
    dailyRunSessionsWon = gameStats.dailyRunSessionsWon or 0,
    endlessSessionsPlayed = gameStats.endlessSessionsPlayed or 0,
    highestEndlessWave = gameStats.highestEndlessWave or 0,
    sessionWinRate = (gameStats.classicSessionsPlayed or 0) > 0 and
      formatPercentage(calculateSuccessRate(gameStats.sessionsWon or 0, gameStats.classicSessionsPlayed) * 100) or 0.0
  }

  -- Battle statistics
  local battleStats = {
    totalBattles = gameStats.battles or 0,
    trainersDefeated = gameStats.trainersDefeated or 0,
    pokemonDefeated = gameStats.pokemonDefeated or 0,
    highestDamage = gameStats.highestDamage or 0,
    highestHeal = gameStats.highestHeal or 0
  }

  -- Resource statistics
  local resourceStats = {
    highestMoney = gameStats.highestMoney or 0,
    eggsPulled = gameStats.eggsPulled or 0,
    rareEggsPulled = gameStats.rareEggsPulled or 0,
    epicEggsPulled = gameStats.epicEggsPulled or 0,
    legendaryEggsPulled = gameStats.legendaryEggsPulled or 0
  }

  return {
    captureStats = captureStats,
    encounterStats = encounterStats,
    legendaryStats = legendaryStats,
    sessionStats = sessionStats,
    battleStats = battleStats,
    resourceStats = resourceStats
  }
end

-- ============================================================================
-- Visualization Data Generation (AC: 3)
-- ============================================================================

-- Generate chart-ready data with labels and colors
local function generateVisualizationData(progressData, statsData)
  progressData = progressData or {}
  statsData = statsData or {}

  -- Completion chart (regional completion)
  local completionChartLabels = {}
  local completionChartValues = {}
  local completionChartColors = {}

  local colorPalette = {
    "#4CAF50", "#FF9800", "#2196F3", "#9C27B0", "#F44336",
    "#00BCD4", "#FFEB3B", "#E91E63", "#009688"
  }

  local colorIndex = 1
  for regionName, regionData in pairs(progressData.regional or {}) do
    -- Capitalize first letter
    local capitalizedName = regionName:sub(1,1):upper() .. regionName:sub(2)
    table.insert(completionChartLabels, capitalizedName)
    table.insert(completionChartValues, regionData.percentage or 0.0)
    table.insert(completionChartColors, colorPalette[colorIndex])
    colorIndex = (colorIndex % #colorPalette) + 1
  end

  local completionChart = {
    labels = completionChartLabels,
    values = completionChartValues,
    colors = completionChartColors,
    type = "bar",
    title = "Regional Completion"
  }

  -- Stats overview chart (seen/caught/hatched)
  local overall = progressData.overall or {}
  local statsChart = {
    labels = {"Seen", "Caught", "Hatched"},
    values = {
      overall.totalSeen or 0,
      overall.totalCaught or 0,
      (statsData.legendaryStats and statsData.legendaryStats.shinyPokemonHatched or 0)
    },
    colors = {"#2196F3", "#4CAF50", "#FF9800"},
    type = "bar",
    title = "Collection Overview"
  }

  -- Capture rate pie chart
  local captureStats = statsData.captureStats or {}
  local captureChart = {
    labels = {"Successful", "Escaped"},
    values = {
      captureStats.successfulCaptures or 0,
      captureStats.escapeCount or 0
    },
    colors = {"#4CAF50", "#F44336"},
    type = "pie",
    title = "Capture Success Rate"
  }

  return {
    completionChart = completionChart,
    statsChart = statsChart,
    captureChart = captureChart
  }
end

-- ============================================================================
-- Analytics Engine (AC: 4)
-- ============================================================================

-- Analyze trends and calculate projections
local function analyzeTrends(historicalData, timeWindow)
  historicalData = historicalData or {}
  timeWindow = timeWindow or 7 -- Default 7 days

  local dailyProgress = historicalData.dailyProgress or {}

  -- Calculate capture velocity (species per day)
  local recentCaptures = 0
  local oldestCaptures = 0
  local dayCount = 0

  -- Get sorted dates
  local dates = {}
  for date, _ in pairs(dailyProgress) do
    table.insert(dates, date)
  end
  table.sort(dates)

  -- Calculate velocity from recent data
  if #dates > 0 then
    local latestDate = dates[#dates]
    local latestData = dailyProgress[latestDate]
    recentCaptures = latestData.caught or 0

    if #dates > timeWindow then
      local oldDate = dates[#dates - timeWindow]
      oldestCaptures = dailyProgress[oldDate].caught or 0
    end

    dayCount = math.min(#dates, timeWindow)
  end

  local captureVelocity = dayCount > 0 and ((recentCaptures - oldestCaptures) / dayCount) or 0.0
  captureVelocity = formatPercentage(captureVelocity)

  -- Project completion date
  local currentProgress = historicalData.currentProgress or {}
  local currentCaught = currentProgress.totalCaught or 0
  local remaining = MAX_SPECIES_COUNT - currentCaught

  local completionProjection = nil
  local daysToCompletion = nil

  if captureVelocity > 0 then
    daysToCompletion = math.ceil(remaining / captureVelocity)
    -- Simple projection (would use actual timestamp in production)
    completionProjection = "~" .. daysToCompletion .. " days"
  end

  -- Detect progress trend
  local progressTrend = "steady"
  if captureVelocity > 5.0 then
    progressTrend = "increasing"
  elseif captureVelocity < 1.0 then
    progressTrend = "decreasing"
  end

  -- Generate insights
  local insights = {}
  if progressTrend == "decreasing" then
    table.insert(insights, "Collection progress has slowed - try exploring new areas!")
  end
  if remaining < 100 then
    table.insert(insights, "You're close to completion! Only " .. remaining .. " species remaining.")
  end

  return {
    captureVelocity = captureVelocity,
    completionProjection = completionProjection,
    daysToCompletion = daysToCompletion,
    progressTrend = progressTrend,
    insights = insights,
    timeWindow = timeWindow
  }
end

-- ============================================================================
-- Progress Comparison (AC: 5)
-- ============================================================================

-- Calculate rankings and relative performance
local function compareProgress(playerData, peerData)
  playerData = playerData or {}
  peerData = peerData or {}

  local playerCompletion = playerData.completionPercentage or 0.0

  -- Calculate ranking
  local rank = 1
  local totalPeers = #peerData

  for _, peer in ipairs(peerData) do
    if peer.completionPercentage > playerCompletion then
      rank = rank + 1
    end
  end

  -- Calculate percentile (0-100)
  local percentile = totalPeers > 0 and
    formatPercentage(((totalPeers - rank + 1) / totalPeers) * 100) or 0.0

  -- Calculate relative performance
  local avgCompletion = 0.0
  if totalPeers > 0 then
    local sum = 0.0
    for _, peer in ipairs(peerData) do
      sum = sum + (peer.completionPercentage or 0.0)
    end
    avgCompletion = sum / totalPeers
  end

  local performanceGap = formatPercentage(playerCompletion - avgCompletion)

  -- Performance assessment
  local assessment = "average"
  if percentile >= 90 then
    assessment = "excellent"
  elseif percentile >= 75 then
    assessment = "above_average"
  elseif percentile >= 50 then
    assessment = "average"
  elseif percentile >= 25 then
    assessment = "below_average"
  else
    assessment = "needs_improvement"
  end

  return {
    rank = rank,
    totalPeers = totalPeers,
    percentile = percentile,
    averageCompletion = formatPercentage(avgCompletion),
    performanceGap = performanceGap,
    assessment = assessment
  }
end

-- ============================================================================
-- Historical Persistence (AC: 6)
-- ============================================================================

-- Create statistics snapshot for historical tracking
local function createSnapshot(currentStats, timestamp)
  currentStats = currentStats or {}
  timestamp = timestamp or 0

  return {
    timestamp = timestamp,
    overall = currentStats.overall or {},
    regional = currentStats.regional or {},
    starters = currentStats.starters or {},
    captureStats = currentStats.captureStats or {},
    encounterStats = currentStats.encounterStats or {}
  }
end

-- Retrieve historical snapshots within time range
local function getHistoricalSnapshots(snapshots, startTime, endTime)
  snapshots = snapshots or {}
  local results = {}

  for _, snapshot in ipairs(snapshots) do
    local ts = snapshot.timestamp or 0
    if ts >= startTime and ts <= endTime then
      table.insert(results, snapshot)
    end
  end

  -- Sort by timestamp
  table.sort(results, function(a, b) return a.timestamp < b.timestamp end)

  return results
end

-- ============================================================================
-- Validation and Integrity (AC: 7)
-- ============================================================================

-- Validate statistics data integrity
local function validateStatistics(statisticsData)
  statisticsData = statisticsData or {}

  local errors = {}
  local warnings = {}
  local valid = true

  -- Validate overall progress
  local overall = statisticsData.overall or {}
  if overall.totalCaught and overall.totalSeen then
    if overall.totalCaught > overall.totalSeen then
      table.insert(errors, "Caught count exceeds seen count")
      valid = false
    end
  end

  if overall.completionPercentage then
    if not isValidPercentage(overall.completionPercentage) then
      table.insert(errors, "Completion percentage out of bounds: " .. tostring(overall.completionPercentage))
      valid = false
    end
  end

  -- Validate counts are non-negative
  local countsToCheck = {
    overall.totalSeen, overall.totalCaught,
    (statisticsData.captureStats or {}).totalAttempts,
    (statisticsData.captureStats or {}).successfulCaptures
  }

  for _, count in ipairs(countsToCheck) do
    if count and not isValidCount(count) then
      table.insert(errors, "Negative count value detected")
      valid = false
    end
  end

  -- Validate regional percentages
  local regional = statisticsData.regional or {}
  for regionName, regionData in pairs(regional) do
    if regionData.percentage and not isValidPercentage(regionData.percentage) then
      table.insert(errors, "Region " .. regionName .. " percentage out of bounds")
      valid = false
    end

    if regionData.caught and regionData.seen then
      if regionData.caught > regionData.seen then
        table.insert(warnings, "Region " .. regionName .. ": caught > seen")
      end
    end
  end

  -- Validate success rates (0.0 to 100.0)
  local captureStats = statisticsData.captureStats or {}
  if captureStats.successRate then
    if not isValidPercentage(captureStats.successRate) then
      table.insert(errors, "Success rate out of bounds: " .. tostring(captureStats.successRate))
      valid = false
    end
  end

  -- Calculate integrity score
  local integrityScore = valid and (#warnings == 0 and 100.0 or 90.0) or 0.0

  return {
    valid = valid,
    errors = errors,
    warnings = warnings,
    integrityScore = integrityScore,
    checksPerformed = {
      "count_consistency",
      "percentage_bounds",
      "non_negative_values",
      "regional_validation",
      "rate_validation"
    }
  }
end

-- ============================================================================
-- AO Message Handlers
-- ============================================================================

-- Handler: CalculateProgress - Compute completion percentages and milestones
Handlers.add("calculate-progress",
  Handlers.utils.hasMatchingTag("Action", "CalculateProgress"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local dexData = data.dexData or {}
    local starterData = data.starterData or {}

    local result = calculateProgress(dexData, starterData)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: GenerateStatistics - Compute comprehensive statistical metrics
Handlers.add("generate-statistics",
  Handlers.utils.hasMatchingTag("Action", "GenerateStatistics"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local gameStats = data.gameStats or {}
    local captureData = data.captureData or {}

    local result = generateStatistics(gameStats, captureData)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: GetVisualizationData - Generate chart-ready data formats
Handlers.add("get-visualization-data",
  Handlers.utils.hasMatchingTag("Action", "GetVisualizationData"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local progressData = data.progressData or {}
    local statsData = data.statsData or {}

    local result = generateVisualizationData(progressData, statsData)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: AnalyzeTrends - Perform trend analysis and projections
Handlers.add("analyze-trends",
  Handlers.utils.hasMatchingTag("Action", "AnalyzeTrends"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local historicalData = data.historicalData or {}
    local timeWindow = data.timeWindow or 7

    local result = analyzeTrends(historicalData, timeWindow)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: CompareProgress - Calculate rankings and relative performance
Handlers.add("compare-progress",
  Handlers.utils.hasMatchingTag("Action", "CompareProgress"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local playerData = data.playerData or {}
    local peerData = data.peerData or {}

    local result = compareProgress(playerData, peerData)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(result)
    })
  end
)

-- Handler: ValidateStatistics - Verify data integrity and bounds
Handlers.add("validate-statistics",
  Handlers.utils.hasMatchingTag("Action", "ValidateStatistics"),
  function(msg)
    local data = json.decode(msg.Data or "{}")
    local statisticsData = data.statisticsData or {}

    local result = validateStatistics(statisticsData)

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
          name = "Collection Statistics Engine",
          version = "1.0.0",
          adpVersion = "1.0",
          description = "Stateless Pokemon collection progress calculation and statistical analysis system",
          capabilities = {
            "progress_calculation",
            "statistical_analysis",
            "visualization_data_generation",
            "trend_analysis",
            "progress_comparison",
            "historical_persistence",
            "data_validation"
          }
        },
        handlers = {
          "CalculateProgress",
          "GenerateStatistics",
          "GetVisualizationData",
          "AnalyzeTrends",
          "CompareProgress",
          "ValidateStatistics",
          "Info"
        },
        schemas = {
          CalculateProgress = {
            tags = {"Action"},
            data = {"dexData", "starterData"}
          },
          GenerateStatistics = {
            tags = {"Action"},
            data = {"gameStats", "captureData"}
          },
          GetVisualizationData = {
            tags = {"Action"},
            data = {"progressData", "statsData"}
          },
          AnalyzeTrends = {
            tags = {"Action"},
            data = {"historicalData", "timeWindow"}
          },
          CompareProgress = {
            tags = {"Action"},
            data = {"playerData", "peerData"}
          },
          ValidateStatistics = {
            tags = {"Action"},
            data = {"statisticsData"}
          }
        }
      })
    })
  end
)
