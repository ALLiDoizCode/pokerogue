--[[
  Advanced Pokedex Features Engine

  Purpose: Advanced search, filtering, sorting, and visualization for Pokemon species
  Version: 1.0.0
  ADP Compliance: v1.0

  Handlers:
  - Info: ADP v1.0 self-documentation
  - SearchPokedex: Text search with fuzzy matching and relevance scoring
  - ApplyFilters: Multi-criteria filtering with state management
  - SortResults: Sort by 7 criteria with direction toggle
  - GetVisualization: Generate species display data
  - ExportData: Export to JSON/CSV formats
  - CustomizePreferences: Store user preferences (session-based)
  - GetAnalytics: Search and filter usage statistics
]]

local json = require("json")

-- Constants
local DROPDOWN_STATE = {
  ON = 0,
  OFF = 1,
  EXCLUDE = 2,
  UNLOCKABLE = 3,
  ONE = 4,
  TWO = 5
}

local SORT_CRITERIA = {
  NUMBER = 0,
  COST = 1,
  CANDY = 2,
  IV = 3,
  NAME = 4,
  CAUGHT = 5,
  HATCHED = 6
}

-- Error codes
local ERROR_CODES = {
  INVALID_SEARCH_QUERY = "INVALID_SEARCH_QUERY",
  INVALID_FILTER = "INVALID_FILTER",
  INVALID_SORT = "INVALID_SORT",
  INVALID_EXPORT_FORMAT = "INVALID_EXPORT_FORMAT",
  EXPORT_SIZE_EXCEEDED = "EXPORT_SIZE_EXCEEDED",
  SPECIES_NOT_FOUND = "SPECIES_NOT_FOUND"
}

-- Initialize session state for analytics
if not SessionState then
  SessionState = {
    searchHistory = {},  -- Last 50 searches
    filterUsage = {},    -- Filter usage counts
    userPreferences = {
      savedPresets = {},
      defaultSort = {criteria = "NUMBER", direction = -1},
      displayPreferences = {infoDensity = "NORMAL", showDecorations = true}
    }
  }
end

--[[
  Helper Functions
]]

-- Calculate Levenshtein distance between two strings
local function levenshteinDistance(str1, str2)
  local len1 = #str1
  local len2 = #str2

  if len1 == 0 then return len2 end
  if len2 == 0 then return len1 end

  -- Create matrix
  local matrix = {}
  for i = 0, len1 do
    matrix[i] = {[0] = i}
  end
  for j = 0, len2 do
    matrix[0][j] = j
  end

  -- Calculate distances
  for i = 1, len1 do
    for j = 1, len2 do
      local cost = (str1:sub(i, i) == str2:sub(j, j)) and 0 or 1
      matrix[i][j] = math.min(
        matrix[i-1][j] + 1,      -- deletion
        matrix[i][j-1] + 1,      -- insertion
        matrix[i-1][j-1] + cost  -- substitution
      )
    end
  end

  return matrix[len1][len2]
end

-- Case-insensitive substring search
local function substringMatch(haystack, needle)
  if not haystack or not needle or needle == "" then
    return false
  end

  local lowerHaystack = string.lower(haystack)
  local lowerNeedle = string.lower(needle)

  return string.find(lowerHaystack, lowerNeedle, 1, true) ~= nil
end

-- Fuzzy match with Levenshtein distance threshold
local function fuzzyMatch(str1, str2, maxDistance)
  if not str1 or not str2 or str2 == "" then
    return false, 999
  end

  local distance = levenshteinDistance(string.lower(str1), string.lower(str2))
  return distance <= maxDistance, distance
end

-- Calculate relevance score for a match
local function calculateRelevanceScore(matchType, fuzzyDistance)
  if matchType == "exact_name" then
    return 100
  elseif matchType == "substring_name" then
    return 80
  elseif matchType == "move" then
    return 60
  elseif matchType == "ability" then
    return 60
  elseif matchType == "fuzzy_name" then
    if fuzzyDistance == 1 then
      return 40
    elseif fuzzyDistance == 2 then
      return 20
    end
  end
  return 0
end

-- Add search to history (maintain last 50)
local function addToSearchHistory(searchQuery, timestamp)
  table.insert(SessionState.searchHistory, 1, {
    query = searchQuery,
    timestamp = timestamp or "0"
  })

  -- Keep only last 50 searches
  while #SessionState.searchHistory > 50 do
    table.remove(SessionState.searchHistory)
  end
end

--[[
  Handler: Info (ADP v1.0 Compliance)
]]

Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    local infoResponse = {
      Name = "Advanced Pokedex Features Engine",
      Description = "Advanced search, filtering, sorting, and visualization for Pokemon species in the Pokedex system",
      Version = "1.0.0",
      Owner = Owner or ao.env.Process.Owner,
      ProcessId = ao.id,
      protocolVersion = "1.0",
      capabilities = {
        search = true,
        filter = true,
        sort = true,
        visualization = true,
        export = true,
        analytics = true,
        customization = true
      },
      handlers = {
        {
          action = "Info",
          pattern = {"Action"},
          description = "Get comprehensive process information and handler metadata",
          category = "core"
        },
        {
          action = "SearchPokedex",
          pattern = {"Action"},
          description = "Advanced search with text matching, fuzzy search, and relevance scoring",
          category = "search",
          parameters = {
            {
              name = "Data",
              type = "json",
              required = true,
              description = "JSON with textSearch object {name, move1, move2, ability1, ability2} and optional filters/sort"
            }
          }
        },
        {
          action = "ApplyFilters",
          pattern = {"Action"},
          description = "Apply multiple filter criteria to species dataset",
          category = "filter",
          parameters = {
            {
              name = "Data",
              type = "json",
              required = true,
              description = "JSON with filters object containing generation, types, biome, caught, unlocks, misc"
            }
          }
        },
        {
          action = "SortResults",
          pattern = {"Action"},
          description = "Sort filtered results by specified criteria",
          category = "sort",
          parameters = {
            {
              name = "Data",
              type = "json",
              required = true,
              description = "JSON with species array and sort object {criteria, direction}"
            }
          }
        },
        {
          action = "GetVisualization",
          pattern = {"Action"},
          description = "Generate visualization data for species display",
          category = "visualization",
          parameters = {
            {
              name = "SpeciesId",
              type = "string",
              required = true,
              description = "Species ID to generate visualization for"
            }
          }
        },
        {
          action = "ExportData",
          pattern = {"Action"},
          description = "Export filtered/sorted results in JSON or CSV format",
          category = "export",
          parameters = {
            {
              name = "Data",
              type = "json",
              required = true,
              description = "JSON with format, columns array, and species array"
            }
          }
        },
        {
          action = "CustomizePreferences",
          pattern = {"Action"},
          description = "Save and load user preferences (session-based)",
          category = "customization",
          parameters = {
            {
              name = "Data",
              type = "json",
              required = true,
              description = "JSON with savedPresets, defaultSort, displayPreferences"
            }
          }
        },
        {
          action = "GetAnalytics",
          pattern = {"Action"},
          description = "Get search pattern insights and filter usage statistics",
          category = "analytics",
          parameters = {
            {
              name = "Data",
              type = "json",
              required = true,
              description = "JSON with analyticsType: 'search', 'filter', or 'result'"
            }
          }
        }
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(infoResponse)
    })
  end
)

--[[
  Handler: SearchPokedex

  Advanced text search with fuzzy matching and relevance scoring.
  Supports name, move, and ability searches with combined filtering.
]]

Handlers.add("search-pokedex",
  Handlers.utils.hasMatchingTag("Action", "SearchPokedex"),
  function(msg)
    -- Validate input
    if not msg.Data or msg.Data == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Search query required in Data field",
        ErrorCode = ERROR_CODES.INVALID_SEARCH_QUERY
      })
      return
    end

    local searchQuery = json.decode(msg.Data)

    if not searchQuery.textSearch and not searchQuery.filters then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "At least one search field or filter must be provided",
        ErrorCode = ERROR_CODES.INVALID_SEARCH_QUERY
      })
      return
    end

    -- Validate text search lengths
    if searchQuery.textSearch then
      for key, value in pairs(searchQuery.textSearch) do
        if type(value) == "string" and #value > 50 then
          ao.send({
            Target = msg.From,
            Action = "Error",
            Error = "Search term too long (max 50 characters): " .. key,
            ErrorCode = ERROR_CODES.INVALID_SEARCH_QUERY
          })
          return
        end
      end
    end

    -- Add to search history for analytics
    addToSearchHistory(searchQuery, msg.Timestamp)

    -- Initialize results
    local results = {}
    local speciesData = {} -- TODO: Load from embedded species database

    -- For now, create sample species data for testing
    -- In production, this would be a large embedded dataset
    speciesData = {
      {
        speciesId = 25,
        name = "Pikachu",
        generation = 1,
        types = {13, -1}, -- Electric, no secondary
        moves = {
          levelUp = {"Thunder Shock", "Tail Whip", "Thunder Wave", "Thunderbolt", "Thunder"},
          egg = {"Volt Tackle", "Charge"},
          tm = {"Thunder", "Thunderbolt", "Wild Charge"}
        },
        abilities = {
          primary = "Static",
          hidden = "Lightning Rod",
          passive = "Static Shield"
        }
      },
      {
        speciesId = 6,
        name = "Charizard",
        generation = 1,
        types = {10, 3}, -- Fire, Flying
        moves = {
          levelUp = {"Flamethrower", "Fire Blast", "Air Slash", "Dragon Claw"},
          egg = {"Dragon Rush", "Belly Drum"},
          tm = {"Flamethrower", "Fire Blast", "Earthquake"}
        },
        abilities = {
          primary = "Blaze",
          hidden = "Solar Power",
          passive = "Flame Body"
        }
      },
      {
        speciesId = 1,
        name = "Bulbasaur",
        generation = 1,
        types = {12, 4}, -- Grass, Poison
        moves = {
          levelUp = {"Vine Whip", "Razor Leaf", "Solar Beam", "Sludge Bomb"},
          egg = {"Power Whip", "Leaf Storm"},
          tm = {"Solar Beam", "Earthquake", "Sludge Bomb"}
        },
        abilities = {
          primary = "Overgrow",
          hidden = "Chlorophyll",
          passive = "Thick Fat"
        }
      }
    }

    -- Process text search if provided
    if searchQuery.textSearch then
      local nameSearch = searchQuery.textSearch.name or ""
      local move1Search = searchQuery.textSearch.move1 or ""
      local move2Search = searchQuery.textSearch.move2 or ""
      local ability1Search = searchQuery.textSearch.ability1 or ""
      local ability2Search = searchQuery.textSearch.ability2 or ""

      for _, species in ipairs(speciesData) do
        local matches = {}
        local maxScore = 0
        local matchReasons = {}

        -- Name search
        if nameSearch ~= "" then
          -- Exact match (case-insensitive)
          if string.lower(species.name) == string.lower(nameSearch) then
            local score = calculateRelevanceScore("exact_name", 0)
            if score > maxScore then maxScore = score end
            table.insert(matchReasons, "Exact name match")
            table.insert(matches, {type = "name", score = score})
          -- Substring match
          elseif substringMatch(species.name, nameSearch) then
            local score = calculateRelevanceScore("substring_name", 0)
            if score > maxScore then maxScore = score end
            table.insert(matchReasons, "Name contains '" .. nameSearch .. "'")
            table.insert(matches, {type = "name", score = score})
          -- Fuzzy match (Levenshtein distance ≤2)
          else
            local isFuzzy, distance = fuzzyMatch(species.name, nameSearch, 2)
            if isFuzzy then
              local score = calculateRelevanceScore("fuzzy_name", distance)
              if score > maxScore then maxScore = score end
              table.insert(matchReasons, "Fuzzy name match (distance " .. tostring(distance) .. ")")
              table.insert(matches, {type = "fuzzy_name", score = score, distance = distance})
            end
          end
        end

        -- Move search (across level-up, egg, TM moves)
        local function searchMoves(moveSearch)
          if moveSearch == "" then return false end

          -- Search level-up moves
          for _, move in ipairs(species.moves.levelUp) do
            if substringMatch(move, moveSearch) then
              local score = calculateRelevanceScore("move", 0)
              if score > maxScore then maxScore = score end
              table.insert(matchReasons, "Has move: " .. move)
              table.insert(matches, {type = "move", score = score, move = move})
              return true
            end
          end

          -- Search egg moves
          for _, move in ipairs(species.moves.egg) do
            if substringMatch(move, moveSearch) then
              local score = calculateRelevanceScore("move", 0)
              if score > maxScore then maxScore = score end
              table.insert(matchReasons, "Has egg move: " .. move)
              table.insert(matches, {type = "egg_move", score = score, move = move})
              return true
            end
          end

          -- Search TM moves
          for _, move in ipairs(species.moves.tm) do
            if substringMatch(move, moveSearch) then
              local score = calculateRelevanceScore("move", 0)
              if score > maxScore then maxScore = score end
              table.insert(matchReasons, "Has TM move: " .. move)
              table.insert(matches, {type = "tm_move", score = score, move = move})
              return true
            end
          end

          return false
        end

        if move1Search ~= "" then
          searchMoves(move1Search)
        end

        if move2Search ~= "" then
          searchMoves(move2Search)
        end

        -- Ability search (primary, hidden, passive)
        local function searchAbilities(abilitySearch)
          if abilitySearch == "" then return false end

          if substringMatch(species.abilities.primary, abilitySearch) then
            local score = calculateRelevanceScore("ability", 0)
            if score > maxScore then maxScore = score end
            table.insert(matchReasons, "Has ability: " .. species.abilities.primary)
            table.insert(matches, {type = "ability", score = score, ability = species.abilities.primary})
            return true
          end

          if substringMatch(species.abilities.hidden, abilitySearch) then
            local score = calculateRelevanceScore("ability", 0)
            if score > maxScore then maxScore = score end
            table.insert(matchReasons, "Has hidden ability: " .. species.abilities.hidden)
            table.insert(matches, {type = "hidden_ability", score = score, ability = species.abilities.hidden})
            return true
          end

          if substringMatch(species.abilities.passive, abilitySearch) then
            local score = calculateRelevanceScore("ability", 0)
            if score > maxScore then maxScore = score end
            table.insert(matchReasons, "Has passive ability: " .. species.abilities.passive)
            table.insert(matches, {type = "passive_ability", score = score, ability = species.abilities.passive})
            return true
          end

          return false
        end

        if ability1Search ~= "" then
          searchAbilities(ability1Search)
        end

        if ability2Search ~= "" then
          searchAbilities(ability2Search)
        end

        -- If any matches found, add to results
        if #matches > 0 then
          table.insert(results, {
            speciesId = species.speciesId,
            name = species.name,
            generation = species.generation,
            types = species.types,
            matchScore = maxScore,
            matchReason = table.concat(matchReasons, ", "),
            matches = matches
          })
        end
      end
    else
      -- No text search, return all species (will be filtered later if filters provided)
      for _, species in ipairs(speciesData) do
        table.insert(results, {
          speciesId = species.speciesId,
          name = species.name,
          generation = species.generation,
          types = species.types,
          matchScore = 0,
          matchReason = "No search criteria"
        })
      end
    end

    -- Sort results by relevance score (highest first)
    table.sort(results, function(a, b)
      return a.matchScore > b.matchScore
    end)

    -- Prepare response
    local response = {
      species = results,
      totalCount = #speciesData,
      filteredCount = #results,
      appliedFilters = {
        textSearch = searchQuery.textSearch or {}
      },
      searchPerformed = msg.Timestamp or "0"
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(response)
    })
  end
)

--[[
  Handler: ApplyFilters

  Apply multiple filter criteria to species dataset.
  All filters use AND logic (species must match all active filters).

  Filters supported:
  - Generation: 1-9
  - Type: primary/secondary type matching
  - Biome: biome availability + uncatchable option
  - Caught status: NORMAL, SHINY, SHINY2, SHINY3, UNCAUGHT
  - Unlocks: PASSIVE and COST_REDUCTION with states
  - Misc: 8 options (starter, favorite, win, hiddenAbility, seen, encountered, egg, pokerus)
]]

Handlers.add("apply-filters",
  Handlers.utils.hasMatchingTag("Action", "ApplyFilters"),
  function(msg)
    -- Validate input
    if not msg.Data or msg.Data == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Filters required in Data field",
        ErrorCode = ERROR_CODES.INVALID_FILTER
      })
      return
    end

    local filterQuery = json.decode(msg.Data)

    if not filterQuery.filters then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Filters object required",
        ErrorCode = ERROR_CODES.INVALID_FILTER
      })
      return
    end

    local filters = filterQuery.filters

    -- Track filter usage for analytics
    for filterType, _ in pairs(filters) do
      SessionState.filterUsage[filterType] = (SessionState.filterUsage[filterType] or 0) + 1
    end

    -- Load species data (expanded with filter fields)
    local speciesData = {
      {
        speciesId = 25,
        name = "Pikachu",
        generation = 1,
        types = {13, -1}, -- Electric
        biomes = {0, 1, 5}, -- Town, Plains, Forest
        cost = 3,
        caught = true,
        shiny = true,
        shinyVariant = 1, -- SHINY (variant 1)
        passive = "UNLOCKED",
        costReduction = 1,
        isStarter = true,
        isFavorite = false,
        hasWon = true,
        hasHiddenAbility = true,
        isSeen = true,
        isEncountered = true,
        isEggPurchasable = true,
        hasPokerus = false
      },
      {
        speciesId = 6,
        name = "Charizard",
        generation = 1,
        types = {10, 3}, -- Fire, Flying
        biomes = {8, 9}, -- Volcano, Mountain
        cost = 8,
        caught = true,
        shiny = false,
        shinyVariant = 0, -- NORMAL
        passive = "UNLOCKED",
        costReduction = 2,
        isStarter = true,
        isFavorite = true,
        hasWon = true,
        hasHiddenAbility = false,
        isSeen = true,
        isEncountered = true,
        isEggPurchasable = true,
        hasPokerus = true
      },
      {
        speciesId = 1,
        name = "Bulbasaur",
        generation = 1,
        types = {12, 4}, -- Grass, Poison
        biomes = {0, 1, 5}, -- Town, Plains, Forest
        cost = 3,
        caught = false,
        shiny = false,
        shinyVariant = 0,
        passive = "LOCKED",
        costReduction = 0,
        isStarter = true,
        isFavorite = false,
        hasWon = false,
        hasHiddenAbility = false,
        isSeen = true,
        isEncountered = false,
        isEggPurchasable = false,
        hasPokerus = false
      },
      {
        speciesId = 152,
        name = "Chikorita",
        generation = 2,
        types = {12, -1}, -- Grass
        biomes = {1, 5}, -- Plains, Forest
        cost = 3,
        caught = true,
        shiny = true,
        shinyVariant = 2, -- SHINY2 (variant 2)
        passive = "UNLOCKABLE",
        costReduction = 0,
        isStarter = true,
        isFavorite = false,
        hasWon = false,
        hasHiddenAbility = true,
        isSeen = true,
        isEncountered = true,
        isEggPurchasable = true,
        hasPokerus = false
      }
    }

    local results = {}

    -- Apply all filters (AND logic)
    for _, species in ipairs(speciesData) do
      local passesAllFilters = true

      -- Generation filter
      if filters.generation and #filters.generation > 0 then
        local passesGen = false
        for _, gen in ipairs(filters.generation) do
          if species.generation == gen then
            passesGen = true
            break
          end
        end
        if not passesGen then
          passesAllFilters = false
        end
      end

      -- Type filter (match primary OR secondary type)
      if passesAllFilters and filters.types and #filters.types > 0 then
        local passesType = false
        for _, typeId in ipairs(filters.types) do
          if species.types[1] == typeId or species.types[2] == typeId then
            passesType = true
            break
          end
        end
        if not passesType then
          passesAllFilters = false
        end
      end

      -- Biome filter
      if passesAllFilters and filters.biome and #filters.biome > 0 then
        local passesBiome = false
        for _, biomeId in ipairs(filters.biome) do
          -- Check for uncatchable option (biome ID 35)
          if biomeId == 35 and #species.biomes == 0 then
            passesBiome = true
            break
          end
          -- Check if species available in this biome
          for _, speciesBiome in ipairs(species.biomes) do
            if speciesBiome == biomeId then
              passesBiome = true
              break
            end
          end
          if passesBiome then break end
        end
        if not passesBiome then
          passesAllFilters = false
        end
      end

      -- Caught status filter
      if passesAllFilters and filters.caught then
        local passesCaught = false
        if filters.caught == "UNCAUGHT" and not species.caught then
          passesCaught = true
        elseif filters.caught == "NORMAL" and species.caught and species.shinyVariant == 0 then
          passesCaught = true
        elseif filters.caught == "SHINY" and species.caught and species.shinyVariant == 1 then
          passesCaught = true
        elseif filters.caught == "SHINY2" and species.caught and species.shinyVariant == 2 then
          passesCaught = true
        elseif filters.caught == "SHINY3" and species.caught and species.shinyVariant == 3 then
          passesCaught = true
        end
        if not passesCaught then
          passesAllFilters = false
        end
      end

      -- Unlocks filter (PASSIVE)
      if passesAllFilters and filters.unlocks and filters.unlocks.passive then
        local state = filters.unlocks.passive
        local passesPassive = false

        if state == "OFF" then
          passesPassive = true -- No filtering
        elseif state == "ON" and species.passive == "UNLOCKED" then
          passesPassive = true
        elseif state == "UNLOCKABLE" and species.passive == "UNLOCKABLE" then
          passesPassive = true
        elseif state == "EXCLUDE" and species.passive ~= "UNLOCKED" then
          passesPassive = true
        end

        if not passesPassive then
          passesAllFilters = false
        end
      end

      -- Unlocks filter (COST_REDUCTION)
      if passesAllFilters and filters.unlocks and filters.unlocks.costReduction then
        local state = filters.unlocks.costReduction
        local passesCostReduction = false

        if state == "OFF" then
          passesCostReduction = true -- No filtering
        elseif state == "ON" and species.costReduction > 0 then
          passesCostReduction = true
        elseif state == "ONE" and species.costReduction == 1 then
          passesCostReduction = true
        elseif state == "TWO" and species.costReduction == 2 then
          passesCostReduction = true
        elseif state == "UNLOCKABLE" and species.costReduction == 0 and species.isStarter then
          passesCostReduction = true -- Can unlock but hasn't yet
        elseif state == "EXCLUDE" and species.costReduction == 0 then
          passesCostReduction = true
        end

        if not passesCostReduction then
          passesAllFilters = false
        end
      end

      -- Misc filter (STARTER)
      if passesAllFilters and filters.misc and filters.misc.starter then
        local state = filters.misc.starter
        local passesStarter = false

        if state == "OFF" then
          passesStarter = true
        elseif state == "ON" and species.isStarter then
          passesStarter = true
        elseif state == "EXCLUDE" and not species.isStarter then
          passesStarter = true
        end

        if not passesStarter then
          passesAllFilters = false
        end
      end

      -- Misc filter (FAVORITE)
      if passesAllFilters and filters.misc and filters.misc.favorite then
        local state = filters.misc.favorite
        local passesFavorite = false

        if state == "OFF" then
          passesFavorite = true
        elseif state == "ON" and species.isFavorite then
          passesFavorite = true
        elseif state == "EXCLUDE" and not species.isFavorite then
          passesFavorite = true
        end

        if not passesFavorite then
          passesAllFilters = false
        end
      end

      -- Misc filter (WIN)
      if passesAllFilters and filters.misc and filters.misc.win then
        local state = filters.misc.win
        local passesWin = false

        if state == "OFF" then
          passesWin = true
        elseif state == "ON" and species.hasWon then
          passesWin = true
        elseif state == "EXCLUDE" and not species.hasWon then
          passesWin = true
        end

        if not passesWin then
          passesAllFilters = false
        end
      end

      -- Misc filter (HIDDEN_ABILITY)
      if passesAllFilters and filters.misc and filters.misc.hiddenAbility then
        local state = filters.misc.hiddenAbility
        local passesHA = false

        if state == "OFF" then
          passesHA = true
        elseif state == "ON" and species.hasHiddenAbility then
          passesHA = true
        elseif state == "EXCLUDE" and not species.hasHiddenAbility then
          passesHA = true
        end

        if not passesHA then
          passesAllFilters = false
        end
      end

      -- Misc filter (SEEN_SPECIES)
      if passesAllFilters and filters.misc and filters.misc.seenSpecies then
        local state = filters.misc.seenSpecies
        local passesSeen = false

        if state == "OFF" then
          passesSeen = true
        elseif state == "ON" and species.isSeen then
          passesSeen = true
        elseif state == "EXCLUDE" and not species.isSeen then
          passesSeen = true
        end

        if not passesSeen then
          passesAllFilters = false
        end
      end

      -- Misc filter (ENCOUNTERED_SPECIES)
      if passesAllFilters and filters.misc and filters.misc.encounteredSpecies then
        local state = filters.misc.encounteredSpecies
        local passesEncountered = false

        if state == "OFF" then
          passesEncountered = true
        elseif state == "ON" and species.isEncountered then
          passesEncountered = true
        elseif state == "EXCLUDE" and not species.isEncountered then
          passesEncountered = true
        end

        if not passesEncountered then
          passesAllFilters = false
        end
      end

      -- Misc filter (EGG)
      if passesAllFilters and filters.misc and filters.misc.egg then
        local state = filters.misc.egg
        local passesEgg = false

        if state == "OFF" then
          passesEgg = true
        elseif state == "ON" and species.isEggPurchasable then
          passesEgg = true
        end

        if not passesEgg then
          passesAllFilters = false
        end
      end

      -- Misc filter (POKERUS)
      if passesAllFilters and filters.misc and filters.misc.pokerus then
        local state = filters.misc.pokerus
        local passesPokerus = false

        if state == "OFF" then
          passesPokerus = true
        elseif state == "ON" and species.hasPokerus then
          passesPokerus = true
        end

        if not passesPokerus then
          passesAllFilters = false
        end
      end

      -- If species passes all filters, add to results
      if passesAllFilters then
        table.insert(results, {
          speciesId = species.speciesId,
          name = species.name,
          generation = species.generation,
          types = species.types,
          biomes = species.biomes,
          cost = species.cost,
          caught = species.caught,
          shiny = species.shiny
        })
      end
    end

    -- Prepare response
    local response = {
      filteredSpecies = results,
      totalCount = #speciesData,
      filteredCount = #results,
      appliedFilters = filters
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(response)
    })
  end
)

--[[
  Handler: SortResults

  Sort filtered results by specified criteria with direction toggle.

  Sort Criteria:
  - NUMBER (0): Sort by Pokedex number (speciesId)
  - COST (1): Sort by starter cost value
  - CANDY (2): Sort by candy count
  - IV (3): Sort by average IV quality
  - NAME (4): Alphabetical sorting by species name
  - CAUGHT (5): Sort by caught count
  - HATCHED (6): Sort by hatched count

  Direction:
  - ASC (-1): Ascending order
  - DESC (1): Descending order
]]

Handlers.add("sort-results",
  Handlers.utils.hasMatchingTag("Action", "SortResults"),
  function(msg)
    -- Validate input
    if not msg.Data or msg.Data == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Sort data required in Data field",
        ErrorCode = ERROR_CODES.INVALID_SORT
      })
      return
    end

    local sortQuery = json.decode(msg.Data)

    if not sortQuery.species or not sortQuery.sort then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Both species array and sort object required",
        ErrorCode = ERROR_CODES.INVALID_SORT
      })
      return
    end

    local species = sortQuery.species
    local sortCriteria = sortQuery.sort.criteria
    local sortDirection = sortQuery.sort.direction or -1 -- Default ASC

    -- Validate sort criteria
    local validCriteria = {
      NUMBER = 0,
      COST = 1,
      CANDY = 2,
      IV = 3,
      NAME = 4,
      CAUGHT = 5,
      HATCHED = 6
    }

    local criteriaValue = validCriteria[sortCriteria]
    if not criteriaValue then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid sort criteria: " .. tostring(sortCriteria),
        ErrorCode = ERROR_CODES.INVALID_SORT
      })
      return
    end

    -- Validate sort direction
    if sortDirection ~= -1 and sortDirection ~= 1 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid sort direction (must be -1 for ASC or 1 for DESC)",
        ErrorCode = ERROR_CODES.INVALID_SORT
      })
      return
    end

    -- Create a copy of the species array for sorting (preserve original)
    local sortedSpecies = {}
    for i, sp in ipairs(species) do
      sortedSpecies[i] = sp
    end

    -- Sort by specified criteria
    -- Lua's table.sort is stable (maintains relative order for equal values)
    table.sort(sortedSpecies, function(a, b)
      local result = false

      if sortCriteria == "NUMBER" then
        -- Sort by Pokedex number
        result = (a.speciesId or 0) < (b.speciesId or 0)
      elseif sortCriteria == "COST" then
        -- Sort by starter cost
        result = (a.cost or 0) < (b.cost or 0)
      elseif sortCriteria == "CANDY" then
        -- Sort by candy count
        result = (a.candyCount or 0) < (b.candyCount or 0)
      elseif sortCriteria == "IV" then
        -- Sort by average IV quality
        result = (a.avgIVs or 0) < (b.avgIVs or 0)
      elseif sortCriteria == "NAME" then
        -- Alphabetical sort by species name
        local nameA = string.lower(a.name or "")
        local nameB = string.lower(b.name or "")
        result = nameA < nameB
      elseif sortCriteria == "CAUGHT" then
        -- Sort by caught count
        result = (a.caughtCount or 0) < (b.caughtCount or 0)
      elseif sortCriteria == "HATCHED" then
        -- Sort by hatched count
        result = (a.hatchedCount or 0) < (b.hatchedCount or 0)
      end

      -- Apply sort direction
      -- ASC (-1): return result as-is (a < b means a comes first)
      -- DESC (1): invert result (a < b means b comes first)
      if sortDirection == 1 then
        return not result
      else
        return result
      end
    end)

    -- Prepare response
    local response = {
      sortedSpecies = sortedSpecies,
      sortCriteria = sortCriteria,
      sortDirection = sortDirection,
      totalCount = #sortedSpecies
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(response)
    })
  end
)

--[[
  Handler: GetVisualization

  Generate comprehensive visualization data for species display.
  Includes type badges, stats, abilities, moves, forms, and evolution data.
]]

Handlers.add("get-visualization",
  Handlers.utils.hasMatchingTag("Action", "GetVisualization"),
  function(msg)
    -- Validate input
    if not msg.SpeciesId or msg.SpeciesId == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "SpeciesId required",
        ErrorCode = ERROR_CODES.SPECIES_NOT_FOUND
      })
      return
    end

    local speciesId = tonumber(msg.SpeciesId)

    -- Mock species database for visualization
    -- In production, this would be a comprehensive embedded dataset
    local speciesDatabase = {
      [25] = {
        speciesId = 25,
        name = "Pikachu",
        number = "025",
        types = {
          primary = {id = 13, name = "Electric", color = "#F8D030", icon = "type_electric"},
          secondary = nil
        },
        sprite = {
          key = "pikachu",
          shiny = false,
          variant = 0,
          formIndex = 0
        },
        stats = {
          base = {hp = 35, atk = 55, def = 40, spatk = 50, spdef = 50, spd = 90},
          calculated = {hp = 200, atk = 150, def = 120, spatk = 140, spdef = 130, spd = 180}
        },
        abilities = {
          {name = "Static", description = "30% chance to paralyze attacker on contact", unlocked = true},
          {name = "Lightning Rod", description = "Electric moves drawn to this Pokemon", unlocked = false}
        },
        moves = {
          levelUp = {
            {level = 1, moveId = 84, name = "Thunder Shock"},
            {level = 5, moveId = 39, name = "Tail Whip"},
            {level = 10, moveId = 86, name = "Thunder Wave"}
          },
          eggMoves = {
            {moveId = 268, name = "Charge"},
            {moveId = 527, name = "Volt Tackle"}
          },
          tmMoves = {
            {tmId = 25, moveId = 87, name = "Thunder"},
            {tmId = 24, moveId = 85, name = "Thunderbolt"}
          }
        },
        forms = {
          {formIndex = 0, name = "Standard", unlocked = true},
          {formIndex = 1, name = "Partner", unlocked = false}
        },
        evolution = {
          preEvolution = {speciesId = 172, name = "Pichu"},
          evolutions = {
            {speciesId = 26, name = "Raichu", condition = "Thunder Stone"}
          }
        }
      },
      [6] = {
        speciesId = 6,
        name = "Charizard",
        number = "006",
        types = {
          primary = {id = 10, name = "Fire", color = "#F08030", icon = "type_fire"},
          secondary = {id = 3, name = "Flying", color = "#A890F0", icon = "type_flying"}
        },
        sprite = {
          key = "charizard",
          shiny = false,
          variant = 0,
          formIndex = 0
        },
        stats = {
          base = {hp = 78, atk = 84, def = 78, spatk = 109, spdef = 85, spd = 100},
          calculated = {hp = 266, atk = 204, def = 192, spatk = 254, spdef = 206, spd = 236}
        },
        abilities = {
          {name = "Blaze", description = "Powers up Fire-type moves when HP is low", unlocked = true},
          {name = "Solar Power", description = "Boosts Sp. Atk in harsh sunlight but loses HP", unlocked = true}
        },
        moves = {
          levelUp = {
            {level = 1, moveId = 52, name = "Ember"},
            {level = 36, moveId = 53, name = "Flamethrower"},
            {level = 54, moveId = 126, name = "Fire Blast"}
          },
          eggMoves = {
            {moveId = 225, name = "Dragon Rush"},
            {moveId = "Belly Drum"}
          },
          tmMoves = {
            {tmId = 38, moveId = 126, name = "Fire Blast"},
            {tmId = 26, moveId = 89, name = "Earthquake"}
          }
        },
        forms = {
          {formIndex = 0, name = "Standard", unlocked = true},
          {formIndex = 1, name = "Mega Charizard X", unlocked = false},
          {formIndex = 2, name = "Mega Charizard Y", unlocked = false}
        },
        evolution = {
          preEvolution = {speciesId = 5, name = "Charmeleon"},
          evolutions = {}
        }
      }
    }

    -- Find species
    local speciesViz = speciesDatabase[speciesId]

    if not speciesViz then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Species not found: " .. tostring(speciesId),
        ErrorCode = ERROR_CODES.SPECIES_NOT_FOUND
      })
      return
    end

    -- Return visualization data
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(speciesViz)
    })
  end
)

--[[
  Handler: ExportData ✨ [ENHANCEMENT]

  Export filtered/sorted results in JSON or CSV format.
  Supports column selection and includes export metadata.
  Max 1000 records per export.
]]

Handlers.add("export-data",
  Handlers.utils.hasMatchingTag("Action", "ExportData"),
  function(msg)
    -- Validate input
    if not msg.Data or msg.Data == "" then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Export configuration required in Data field",
        ErrorCode = ERROR_CODES.INVALID_EXPORT_FORMAT
      })
      return
    end

    local exportConfig = json.decode(msg.Data)

    -- Validate format
    if not exportConfig.format or (exportConfig.format ~= "JSON" and exportConfig.format ~= "CSV") then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid export format (must be 'JSON' or 'CSV')",
        ErrorCode = ERROR_CODES.INVALID_EXPORT_FORMAT
      })
      return
    end

    -- Validate species data
    if not exportConfig.species or #exportConfig.species == 0 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Species array required for export",
        ErrorCode = ERROR_CODES.INVALID_EXPORT_FORMAT
      })
      return
    end

    -- Check export size limit (max 1000 records)
    if #exportConfig.species > 1000 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Export size exceeded (max 1000 records, got " .. tostring(#exportConfig.species) .. ")",
        ErrorCode = ERROR_CODES.EXPORT_SIZE_EXCEEDED
      })
      return
    end

    local format = exportConfig.format
    local species = exportConfig.species
    local columns = exportConfig.columns or {
      "speciesId", "name", "generation", "types", "biomes", "cost",
      "caught", "shiny", "passive", "costReduction",
      "candyCount", "avgIVs", "caughtCount", "hatchedCount"
    }

    local exportData = ""
    local exportTimestamp = msg.Timestamp or "0"

    if format == "JSON" then
      -- JSON export: structured format
      local jsonExport = {
        format = "JSON",
        exportDate = exportTimestamp,
        totalRecords = #species,
        columns = columns,
        data = species
      }
      exportData = json.encode(jsonExport)

    elseif format == "CSV" then
      -- CSV export: tabular format
      local csvLines = {}

      -- Header row
      table.insert(csvLines, table.concat(columns, ","))

      -- Data rows
      for _, sp in ipairs(species) do
        local row = {}
        for _, col in ipairs(columns) do
          local value = sp[col]

          -- Handle array fields (types, biomes)
          if type(value) == "table" then
            value = table.concat(value, ";")
          elseif value == nil then
            value = ""
          else
            value = tostring(value)
          end

          table.insert(row, value)
        end
        table.insert(csvLines, table.concat(row, ","))
      end

      exportData = table.concat(csvLines, "\n")
    end

    -- Prepare response with export metadata
    local response = {
      format = format,
      data = exportData,
      metadata = {
        exportDate = exportTimestamp,
        totalRecords = #species,
        columns = columns,
        fileSize = #exportData
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(response)
    })
  end
)

--[[
  Handler: GetAnalytics ✨ [ENHANCEMENT]

  Provide search pattern insights and filter usage statistics.
  Session-based analytics (last 50 searches).
]]

Handlers.add("get-analytics",
  Handlers.utils.hasMatchingTag("Action", "GetAnalytics"),
  function(msg)
    local analyticsData = {
      searchHistory = SessionState.searchHistory or {},
      filterUsage = SessionState.filterUsage or {},
      sessionStats = {
        totalSearches = #(SessionState.searchHistory or {}),
        totalFilterApplications = 0
      }
    }

    -- Calculate total filter applications
    for _, count in pairs(SessionState.filterUsage or {}) do
      analyticsData.sessionStats.totalFilterApplications = analyticsData.sessionStats.totalFilterApplications + count
    end

    -- Calculate popular filters (top 3)
    local filterList = {}
    for filterName, count in pairs(SessionState.filterUsage or {}) do
      table.insert(filterList, {filter = filterName, count = count})
    end
    table.sort(filterList, function(a, b) return a.count > b.count end)

    analyticsData.popularFilters = {}
    for i = 1, math.min(3, #filterList) do
      table.insert(analyticsData.popularFilters, filterList[i])
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(analyticsData)
    })
  end
)

--[[
  Handler: CustomizePreferences

  Save and load user preferences (session-based).
  Includes saved filter presets and default sort preferences.
]]

Handlers.add("customize-preferences",
  Handlers.utils.hasMatchingTag("Action", "CustomizePreferences"),
  function(msg)
    if not msg.Data or msg.Data == "" then
      -- Return current preferences if no update data provided
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Data = json.encode(SessionState.userPreferences)
      })
      return
    end

    local preferencesUpdate = json.decode(msg.Data)

    -- Update saved presets
    if preferencesUpdate.savedPresets then
      SessionState.userPreferences.savedPresets = preferencesUpdate.savedPresets
    end

    -- Update default sort
    if preferencesUpdate.defaultSort then
      SessionState.userPreferences.defaultSort = preferencesUpdate.defaultSort
    end

    -- Update display preferences
    if preferencesUpdate.displayPreferences then
      SessionState.userPreferences.displayPreferences = preferencesUpdate.displayPreferences
    end

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        preferencesUpdated = true,
        currentPreferences = SessionState.userPreferences
      })
    })
  end
)

print("Advanced Pokedex Features Engine v1.0.0 loaded successfully")
