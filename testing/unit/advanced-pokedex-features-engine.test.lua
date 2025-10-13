--[[
  Unit Tests: Advanced Pokedex Features Engine

  Tests for search, filter, sort, visualization, export, analytics, and customization features.
  Uses aolite framework for AO process testing.
]]

local aolite = require("aolite")
local json = require("json")

-- Module path for the process
local PROCESS_PATH = "processes.advanced-pokedex-features-engine"
local processId = "test-advanced-pokedex"

print("Starting Advanced Pokedex Features Engine unit tests...")

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

-- Helper function to send messages (matching collection-statistics pattern)
local function sendMessage(action, dataTable, tags)
  local msg = {
    From = processId,
    Target = processId,
    Action = action,
    Data = dataTable and json.encode(dataTable) or ""
  }

  if tags then
    for k, v in pairs(tags) do
      msg[k] = tostring(v)
    end
  end

  aolite.send(msg)
  return aolite.getLastMsg(processId)
end

--[[
  Test Suite 1: Info Handler (ADP v1.0 Compliance)
]]

print("\n=== Test Suite 1: Info Handler ===")

local function testInfoHandler()
  local response = sendMessage("Info")

  if not response then
    error("❌ Info handler: No response received")
  end

  if response.Action ~= "SaveState" then
    error("❌ Info handler: Expected Action='SaveState', got '" .. tostring(response.Action) .. "'")
  end

  local info = json.decode(response.Data)

  if not info.Name or info.Name ~= "Advanced Pokedex Features Engine" then
    error("❌ Info handler: Invalid process name")
  end

  if not info.protocolVersion or info.protocolVersion ~= "1.0" then
    error("❌ Info handler: Invalid protocol version")
  end

  if not info.handlers or #info.handlers == 0 then
    error("❌ Info handler: No handlers defined")
  end

  print("✅ Info handler returns ADP v1.0 compliant response")
end

testInfoHandler()

--[[
  Test Suite 2: SearchPokedex Handler - Name Search
]]

print("\n=== Test Suite 2: Name Search ===")

local function testExactNameMatch()
  local searchQuery = {
    textSearch = {
      name = "Pikachu"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)

  if not response or response.Action ~= "SaveState" then
    error("❌ Exact name match: Invalid response action")
  end

  if response.Success ~= "true" then
    error("❌ Exact name match: Expected Success='true'")
  end

  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Exact name match: No species found")
  end

  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Exact name match: Expected 'Pikachu', got '" .. tostring(pikachu.name) .. "'")
  end

  if pikachu.matchScore ~= 100 then
    error("❌ Exact name match: Expected score 100, got " .. tostring(pikachu.matchScore))
  end

  print("✅ Exact name match works correctly (score: 100)")
end

local function testSubstringNameMatch()
  local searchQuery = {
    textSearch = {
      name = "pika"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Substring name match: No species found")
  end

  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Substring name match: Expected 'Pikachu', got '" .. tostring(pikachu.name) .. "'")
  end

  if pikachu.matchScore ~= 80 then
    error("❌ Substring name match: Expected score 80, got " .. tostring(pikachu.matchScore))
  end

  print("✅ Substring name match works correctly (score: 80)")
end

local function testCaseInsensitiveNameSearch()
  local searchQuery = {
    textSearch = {
      name = "PIKACHU"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Case-insensitive search: No species found")
  end

  if result.species[1].name ~= "Pikachu" then
    error("❌ Case-insensitive search: Failed to match 'PIKACHU' to 'Pikachu'")
  end

  print("✅ Case-insensitive name search works correctly")
end

local function testFuzzyNameMatch()
  local searchQuery = {
    textSearch = {
      name = "Pikachuu"  -- Typo with distance 1
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Fuzzy name match: No species found")
  end

  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Fuzzy name match: Expected 'Pikachu', got '" .. tostring(pikachu.name) .. "'")
  end

  if pikachu.matchScore ~= 40 then
    error("❌ Fuzzy name match: Expected score 40, got " .. tostring(pikachu.matchScore))
  end

  print("✅ Fuzzy name match (distance 1) works correctly (score: 40)")
end

testExactNameMatch()
testSubstringNameMatch()
testCaseInsensitiveNameSearch()
testFuzzyNameMatch()

--[[
  Test Suite 3: SearchPokedex Handler - Move Search
]]

print("\n=== Test Suite 3: Move Search ===")

local function testMoveSearch()
  local searchQuery = {
    textSearch = {
      move1 = "Thunder"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Move search: No species found with move 'Thunder'")
  end

  -- Pikachu should be in results
  local foundPikachu = false
  for _, species in ipairs(result.species) do
    if species.name == "Pikachu" then
      foundPikachu = true
      if species.matchScore ~= 60 then
        error("❌ Move search: Expected score 60, got " .. tostring(species.matchScore))
      end
      break
    end
  end

  if not foundPikachu then
    error("❌ Move search: Pikachu not found in results")
  end

  print("✅ Move search works correctly (score: 60)")
end

local function testMultipleMoveSearch()
  local searchQuery = {
    textSearch = {
      move1 = "Thunder",
      move2 = "Flamethrower"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species then
    error("❌ Multiple move search: No results returned")
  end

  -- Should find both Pikachu (Thunder) and Charizard (Flamethrower)
  local foundPikachu = false
  local foundCharizard = false

  for _, species in ipairs(result.species) do
    if species.name == "Pikachu" then
      foundPikachu = true
    elseif species.name == "Charizard" then
      foundCharizard = true
    end
  end

  if not foundPikachu or not foundCharizard then
    error("❌ Multiple move search: Did not find both Pikachu and Charizard")
  end

  print("✅ Multiple move search works correctly")
end

testMoveSearch()
testMultipleMoveSearch()

--[[
  Test Suite 4: SearchPokedex Handler - Ability Search
]]

print("\n=== Test Suite 4: Ability Search ===")

local function testAbilitySearch()
  local searchQuery = {
    textSearch = {
      ability1 = "Static"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Ability search: No species found with ability 'Static'")
  end

  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Ability search: Expected 'Pikachu', got '" .. tostring(pikachu.name) .. "'")
  end

  if pikachu.matchScore ~= 60 then
    error("❌ Ability search: Expected score 60, got " .. tostring(pikachu.matchScore))
  end

  print("✅ Ability search works correctly (score: 60)")
end

local function testHiddenAbilitySearch()
  local searchQuery = {
    textSearch = {
      ability1 = "Lightning Rod"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Hidden ability search: No species found")
  end

  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Hidden ability search: Expected 'Pikachu'")
  end

  print("✅ Hidden ability search works correctly")
end

local function testPassiveAbilitySearch()
  local searchQuery = {
    textSearch = {
      ability1 = "Static Shield"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Passive ability search: No species found")
  end

  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Passive ability search: Expected 'Pikachu'")
  end

  print("✅ Passive ability search works correctly")
end

testAbilitySearch()
testHiddenAbilitySearch()
testPassiveAbilitySearch()

--[[
  Test Suite 5: SearchPokedex Handler - Error Handling
]]

print("\n=== Test Suite 5: Error Handling ===")

local function testMissingSearchQuery()
  local response = sendMessage("SearchPokedex")

  if not response or response.Action ~= "Error" then
    error("❌ Missing search query: Should return error")
  end

  if response.ErrorCode ~= "INVALID_SEARCH_QUERY" then
    error("❌ Missing search query: Expected ErrorCode='INVALID_SEARCH_QUERY'")
  end

  print("✅ Missing search query returns proper error")
end

local function testSearchTermTooLong()
  local longString = string.rep("a", 51)  -- 51 characters
  local searchQuery = {
    textSearch = {
      name = longString
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)

  if not response or response.Action ~= "Error" then
    error("❌ Search term too long: Should return error")
  end

  if response.ErrorCode ~= "INVALID_SEARCH_QUERY" then
    error("❌ Search term too long: Expected ErrorCode='INVALID_SEARCH_QUERY'")
  end

  print("✅ Search term too long returns proper error")
end

testMissingSearchQuery()
testSearchTermTooLong()

--[[
  Test Suite 6: Relevance Scoring
]]

print("\n=== Test Suite 6: Relevance Scoring ===")

local function testScoreOrdering()
  local searchQuery = {
    textSearch = {
      name = "pika"  -- Substring match (80) for Pikachu
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Score ordering: No species found")
  end

  -- Verify results are sorted by score (highest first)
  for i = 1, #result.species - 1 do
    if result.species[i].matchScore < result.species[i + 1].matchScore then
      error("❌ Score ordering: Results not sorted by relevance score")
    end
  end

  print("✅ Results sorted by relevance score correctly")
end

testScoreOrdering()

--[[
  Test Suite 7: Combined Search
]]

print("\n=== Test Suite 7: Combined Search ===")

local function testCombinedSearch()
  local searchQuery = {
    textSearch = {
      name = "Pikachu",
      move1 = "Thunder"
    }
  }

  local response = sendMessage("SearchPokedex", searchQuery)
  local result = json.decode(response.Data)

  if not result.species or #result.species == 0 then
    error("❌ Combined search: No species found")
  end

  -- Pikachu should match both name and move
  local pikachu = result.species[1]
  if pikachu.name ~= "Pikachu" then
    error("❌ Combined search: Expected 'Pikachu' as top result")
  end

  -- Should have high score due to multiple matches
  if pikachu.matchScore < 60 then
    error("❌ Combined search: Score too low for combined match")
  end

  print("✅ Combined search (name + move) works correctly")
end

testCombinedSearch()

print("\n" .. string.rep("=", 50))
print("✅ All SearchPokedex unit tests passed!")
print(string.rep("=", 50))

--[[
  Test Suite 8: ApplyFilters Handler - Generation Filter
]]

print("\n=== Test Suite 8: Generation Filter ===")

local function testGenerationFilter()
  local filterQuery = {
    filters = {
      generation = {1}  -- Only Gen 1
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)

  if not response or response.Action ~= "SaveState" then
    error("❌ Generation filter: Invalid response action")
  end

  local result = json.decode(response.Data)

  if not result.filteredSpecies then
    error("❌ Generation filter: No filtered species in response")
  end

  -- All results should be Gen 1
  for _, species in ipairs(result.filteredSpecies) do
    if species.generation ~= 1 then
      error("❌ Generation filter: Found non-Gen 1 species: " .. species.name)
    end
  end

  -- Should include Pikachu, Charizard, Bulbasaur but NOT Chikorita (Gen 2)
  local foundGen2 = false
  for _, species in ipairs(result.filteredSpecies) do
    if species.generation == 2 then
      foundGen2 = true
      break
    end
  end

  if foundGen2 then
    error("❌ Generation filter: Gen 2 species found in Gen 1 filter")
  end

  print("✅ Generation filter works correctly")
end

local function testMultipleGenerationFilter()
  local filterQuery = {
    filters = {
      generation = {1, 2}  -- Gen 1 and Gen 2
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should include all species (Pikachu, Charizard, Bulbasaur, Chikorita)
  if result.filteredCount ~= 4 then
    error("❌ Multiple generation filter: Expected 4 species, got " .. tostring(result.filteredCount))
  end

  print("✅ Multiple generation filter works correctly")
end

testGenerationFilter()
testMultipleGenerationFilter()

--[[
  Test Suite 9: ApplyFilters Handler - Type Filter
]]

print("\n=== Test Suite 9: Type Filter ===")

local function testTypeFilter()
  local filterQuery = {
    filters = {
      types = {13}  -- Electric type
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Pikachu (Electric type)
  if result.filteredCount ~= 1 then
    error("❌ Type filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Pikachu" then
    error("❌ Type filter: Expected Pikachu, got " .. result.filteredSpecies[1].name)
  end

  print("✅ Type filter works correctly")
end

local function testSecondaryTypeFilter()
  local filterQuery = {
    filters = {
      types = {3}  -- Flying type (Charizard's secondary type)
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should include Charizard (Fire/Flying)
  local foundCharizard = false
  for _, species in ipairs(result.filteredSpecies) do
    if species.name == "Charizard" then
      foundCharizard = true
      break
    end
  end

  if not foundCharizard then
    error("❌ Secondary type filter: Charizard not found with Flying type")
  end

  print("✅ Secondary type filter works correctly")
end

testTypeFilter()
testSecondaryTypeFilter()

--[[
  Test Suite 10: ApplyFilters Handler - Caught Status Filter
]]

print("\n=== Test Suite 10: Caught Status Filter ===")

local function testCaughtNormalFilter()
  local filterQuery = {
    filters = {
      caught = "NORMAL"  -- Non-shiny caught
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Charizard (caught, shinyVariant = 0)
  if result.filteredCount ~= 1 then
    error("❌ Caught NORMAL filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Charizard" then
    error("❌ Caught NORMAL filter: Expected Charizard")
  end

  print("✅ Caught NORMAL filter works correctly")
end

local function testCaughtShinyFilter()
  local filterQuery = {
    filters = {
      caught = "SHINY"  -- Shiny variant 1
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Pikachu (shinyVariant = 1)
  if result.filteredCount ~= 1 then
    error("❌ Caught SHINY filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Pikachu" then
    error("❌ Caught SHINY filter: Expected Pikachu")
  end

  print("✅ Caught SHINY filter works correctly")
end

local function testUncaughtFilter()
  local filterQuery = {
    filters = {
      caught = "UNCAUGHT"
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Bulbasaur (not caught)
  if result.filteredCount ~= 1 then
    error("❌ UNCAUGHT filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Bulbasaur" then
    error("❌ UNCAUGHT filter: Expected Bulbasaur")
  end

  print("✅ UNCAUGHT filter works correctly")
end

testCaughtNormalFilter()
testCaughtShinyFilter()
testUncaughtFilter()

--[[
  Test Suite 11: ApplyFilters Handler - Unlocks Filter
]]

print("\n=== Test Suite 11: Unlocks Filter ===")

local function testPassiveUnlockedFilter()
  local filterQuery = {
    filters = {
      unlocks = {
        passive = "ON"  -- Passive unlocked
      }
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should include Pikachu and Charizard (passive = "UNLOCKED")
  if result.filteredCount ~= 2 then
    error("❌ Passive unlocked filter: Expected 2 species, got " .. tostring(result.filteredCount))
  end

  print("✅ Passive unlocked filter works correctly")
end

local function testCostReductionTwoFilter()
  local filterQuery = {
    filters = {
      unlocks = {
        costReduction = "TWO"  -- Cost reduction = 2
      }
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Charizard (costReduction = 2)
  if result.filteredCount ~= 1 then
    error("❌ Cost reduction TWO filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Charizard" then
    error("❌ Cost reduction TWO filter: Expected Charizard")
  end

  print("✅ Cost reduction TWO filter works correctly")
end

testPassiveUnlockedFilter()
testCostReductionTwoFilter()

--[[
  Test Suite 12: ApplyFilters Handler - Misc Filters
]]

print("\n=== Test Suite 12: Misc Filters ===")

local function testFavoriteFilter()
  local filterQuery = {
    filters = {
      misc = {
        favorite = "ON"  -- Is favorite
      }
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Charizard (isFavorite = true)
  if result.filteredCount ~= 1 then
    error("❌ Favorite filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Charizard" then
    error("❌ Favorite filter: Expected Charizard")
  end

  print("✅ Favorite filter works correctly")
end

local function testPokerusFilter()
  local filterQuery = {
    filters = {
      misc = {
        pokerus = "ON"  -- Has pokerus
      }
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Charizard (hasPokerus = true)
  if result.filteredCount ~= 1 then
    error("❌ Pokerus filter: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Charizard" then
    error("❌ Pokerus filter: Expected Charizard")
  end

  print("✅ Pokerus filter works correctly")
end

testFavoriteFilter()
testPokerusFilter()

--[[
  Test Suite 13: ApplyFilters Handler - Combined Filters
]]

print("\n=== Test Suite 13: Combined Filters (AND Logic) ===")

local function testCombinedFilters()
  local filterQuery = {
    filters = {
      generation = {1},
      caught = "SHINY"
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Pikachu (Gen 1 AND shiny variant 1)
  if result.filteredCount ~= 1 then
    error("❌ Combined filters: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Pikachu" then
    error("❌ Combined filters: Expected Pikachu")
  end

  print("✅ Combined filters (AND logic) work correctly")
end

local function testComplexCombinedFilters()
  local filterQuery = {
    filters = {
      generation = {1},
      types = {10}, -- Fire type
      unlocks = {
        costReduction = "TWO"
      }
    }
  }

  local response = sendMessage("ApplyFilters", filterQuery)
  local result = json.decode(response.Data)

  -- Should only include Charizard (Gen 1 AND Fire type AND cost reduction 2)
  if result.filteredCount ~= 1 then
    error("❌ Complex combined filters: Expected 1 species, got " .. tostring(result.filteredCount))
  end

  if result.filteredSpecies[1].name ~= "Charizard" then
    error("❌ Complex combined filters: Expected Charizard")
  end

  print("✅ Complex combined filters work correctly")
end

testCombinedFilters()
testComplexCombinedFilters()

--[[
  Test Suite 14: ApplyFilters Handler - Error Handling
]]

print("\n=== Test Suite 14: ApplyFilters Error Handling ===")

local function testMissingFilters()
  local response = sendMessage("ApplyFilters")

  if not response or response.Action ~= "Error" then
    error("❌ Missing filters: Should return error")
  end

  if response.ErrorCode ~= "INVALID_FILTER" then
    error("❌ Missing filters: Expected ErrorCode='INVALID_FILTER'")
  end

  print("✅ Missing filters returns proper error")
end

testMissingFilters()

print("\n" .. string.rep("=", 50))
print("✅ All ApplyFilters unit tests passed!")
print(string.rep("=", 50))

--[[
  Test Suite 15: SortResults Handler - Sort by NUMBER
]]

print("\n=== Test Suite 15: Sort by NUMBER ===")

-- Respawn process to work around aolite message queue issue with high message counts
print("Respawning process for SortResults tests...")
aolite.clearAllProcesses()
aolite.spawnProcess(processId, PROCESS_PATH)
print("Process respawned\n")

local function testSortByNumberAsc()
  local sortQuery = {
    species = {
      {speciesId = 152, name = "Chikorita"},
      {speciesId = 25, name = "Pikachu"},
      {speciesId = 6, name = "Charizard"},
      {speciesId = 1, name = "Bulbasaur"}
    },
    sort = {
      criteria = "NUMBER",
      direction = -1  -- ASC
    }
  }

  local response = sendMessage("SortResults", sortQuery)

  if not response or response.Action ~= "SaveState" then
    error("❌ Sort by NUMBER ASC: Invalid response action")
  end

  local result = json.decode(response.Data)

  if not result.sortedSpecies or #result.sortedSpecies ~= 4 then
    error("❌ Sort by NUMBER ASC: Invalid sorted species count")
  end

  -- Check order: 1 (Bulbasaur), 6 (Charizard), 25 (Pikachu), 152 (Chikorita)
  if result.sortedSpecies[1].speciesId ~= 1 then
    error("❌ Sort by NUMBER ASC: First should be Bulbasaur (1)")
  end
  if result.sortedSpecies[2].speciesId ~= 6 then
    error("❌ Sort by NUMBER ASC: Second should be Charizard (6)")
  end
  if result.sortedSpecies[3].speciesId ~= 25 then
    error("❌ Sort by NUMBER ASC: Third should be Pikachu (25)")
  end
  if result.sortedSpecies[4].speciesId ~= 152 then
    error("❌ Sort by NUMBER ASC: Fourth should be Chikorita (152)")
  end

  print("✅ Sort by NUMBER ASC works correctly")
end

local function testSortByNumberDesc()
  -- Use same data as ASC test, just different direction
  local sortQuery = {
    species = {
      {speciesId = 152, name = "Chikorita"},
      {speciesId = 25, name = "Pikachu"},
      {speciesId = 6, name = "Charizard"},
      {speciesId = 1, name = "Bulbasaur"}
    },
    sort = {
      criteria = "NUMBER",
      direction = 1  -- DESC
    }
  }

  local response = sendMessage("SortResults", sortQuery)

  if not response or response.Action ~= "SaveState" then
    error("❌ Sort by NUMBER DESC: Invalid response action")
  end

  local result = json.decode(response.Data)

  if not result.sortedSpecies then
    error("❌ Sort by NUMBER DESC: No sortedSpecies in response")
  end

  -- Check order: 152, 25, 6, 1 (reverse)
  if result.sortedSpecies[1].speciesId ~= 152 then
    error("❌ Sort by NUMBER DESC: First should be Chikorita (152)")
  end
  if result.sortedSpecies[4].speciesId ~= 1 then
    error("❌ Sort by NUMBER DESC: Last should be Bulbasaur (1)")
  end

  print("✅ Sort by NUMBER DESC works correctly")
end

testSortByNumberAsc()

-- Clear messages before next test to work around aolite message queue issue
aolite.clearAllMessages(processId)

testSortByNumberDesc()

--[[
  Test Suite 16: SortResults Handler - Sort by NAME
]]

print("\n=== Test Suite 16: Sort by NAME ===")

local function testSortByNameAsc()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu"},
      {speciesId = 6, name = "Charizard"},
      {speciesId = 1, name = "Bulbasaur"}
    },
    sort = {
      criteria = "NAME",
      direction = -1  -- ASC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check alphabetical order: Bulbasaur, Charizard, Pikachu
  if result.sortedSpecies[1].name ~= "Bulbasaur" then
    error("❌ Sort by NAME ASC: First should be Bulbasaur")
  end
  if result.sortedSpecies[2].name ~= "Charizard" then
    error("❌ Sort by NAME ASC: Second should be Charizard")
  end
  if result.sortedSpecies[3].name ~= "Pikachu" then
    error("❌ Sort by NAME ASC: Third should be Pikachu")
  end

  print("✅ Sort by NAME ASC works correctly")
end

local function testSortByNameDesc()
  local sortQuery = {
    species = {
      {speciesId = 1, name = "Bulbasaur"},
      {speciesId = 6, name = "Charizard"},
      {speciesId = 25, name = "Pikachu"}
    },
    sort = {
      criteria = "NAME",
      direction = 1  -- DESC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check reverse alphabetical: Pikachu, Charizard, Bulbasaur
  if result.sortedSpecies[1].name ~= "Pikachu" then
    error("❌ Sort by NAME DESC: First should be Pikachu")
  end
  if result.sortedSpecies[3].name ~= "Bulbasaur" then
    error("❌ Sort by NAME DESC: Last should be Bulbasaur")
  end

  print("✅ Sort by NAME DESC works correctly")
end

testSortByNameAsc()
testSortByNameDesc()

--[[
  Test Suite 17: SortResults Handler - Sort by COST
]]

print("\n=== Test Suite 17: Sort by COST ===")

local function testSortByCost()
  local sortQuery = {
    species = {
      {speciesId = 6, name = "Charizard", cost = 8},
      {speciesId = 25, name = "Pikachu", cost = 3},
      {speciesId = 1, name = "Bulbasaur", cost = 3}
    },
    sort = {
      criteria = "COST",
      direction = -1  -- ASC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check order by cost: 3, 3, 8
  if result.sortedSpecies[1].cost ~= 3 then
    error("❌ Sort by COST: First should have cost 3")
  end
  if result.sortedSpecies[3].cost ~= 8 then
    error("❌ Sort by COST: Last should have cost 8 (Charizard)")
  end

  print("✅ Sort by COST works correctly")
end

testSortByCost()

--[[
  Test Suite 18: SortResults Handler - Sort by CANDY
]]

print("\n=== Test Suite 18: Sort by CANDY ===")

local function testSortByCandy()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu", candyCount = 150},
      {speciesId = 6, name = "Charizard", candyCount = 50},
      {speciesId = 1, name = "Bulbasaur", candyCount = 200}
    },
    sort = {
      criteria = "CANDY",
      direction = -1  -- ASC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check order by candy: 50, 150, 200
  if result.sortedSpecies[1].candyCount ~= 50 then
    error("❌ Sort by CANDY: First should be Charizard (50)")
  end
  if result.sortedSpecies[2].candyCount ~= 150 then
    error("❌ Sort by CANDY: Second should be Pikachu (150)")
  end
  if result.sortedSpecies[3].candyCount ~= 200 then
    error("❌ Sort by CANDY: Third should be Bulbasaur (200)")
  end

  print("✅ Sort by CANDY works correctly")
end

testSortByCandy()

--[[
  Test Suite 19: SortResults Handler - Sort by IV
]]

print("\n=== Test Suite 19: Sort by IV ===")

local function testSortByIV()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu", avgIVs = 28.5},
      {speciesId = 6, name = "Charizard", avgIVs = 31.0},
      {speciesId = 1, name = "Bulbasaur", avgIVs = 15.2}
    },
    sort = {
      criteria = "IV",
      direction = 1  -- DESC (highest IV first)
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check order by IV DESC: 31.0, 28.5, 15.2
  if result.sortedSpecies[1].avgIVs ~= 31.0 then
    error("❌ Sort by IV DESC: First should be Charizard (31.0)")
  end
  if result.sortedSpecies[2].avgIVs ~= 28.5 then
    error("❌ Sort by IV DESC: Second should be Pikachu (28.5)")
  end
  if result.sortedSpecies[3].avgIVs ~= 15.2 then
    error("❌ Sort by IV DESC: Third should be Bulbasaur (15.2)")
  end

  print("✅ Sort by IV works correctly")
end

testSortByIV()

--[[
  Test Suite 20: SortResults Handler - Sort by CAUGHT and HATCHED
]]

print("\n=== Test Suite 20: Sort by CAUGHT and HATCHED ===")

local function testSortByCaught()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu", caughtCount = 5},
      {speciesId = 6, name = "Charizard", caughtCount = 10},
      {speciesId = 1, name = "Bulbasaur", caughtCount = 2}
    },
    sort = {
      criteria = "CAUGHT",
      direction = -1  -- ASC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check order: 2, 5, 10
  if result.sortedSpecies[1].caughtCount ~= 2 then
    error("❌ Sort by CAUGHT: First should be Bulbasaur (2)")
  end

  print("✅ Sort by CAUGHT works correctly")
end

local function testSortByHatched()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu", hatchedCount = 8},
      {speciesId = 6, name = "Charizard", hatchedCount = 3},
      {speciesId = 1, name = "Bulbasaur", hatchedCount = 12}
    },
    sort = {
      criteria = "HATCHED",
      direction = 1  -- DESC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- Check order DESC: 12, 8, 3
  if result.sortedSpecies[1].hatchedCount ~= 12 then
    error("❌ Sort by HATCHED DESC: First should be Bulbasaur (12)")
  end
  if result.sortedSpecies[3].hatchedCount ~= 3 then
    error("❌ Sort by HATCHED DESC: Last should be Charizard (3)")
  end

  print("✅ Sort by HATCHED works correctly")
end

testSortByCaught()
testSortByHatched()

--[[
  Test Suite 21: SortResults Handler - Stable Sorting
]]

print("\n=== Test Suite 21: Stable Sorting ===")

local function testStableSorting()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu", cost = 3},
      {speciesId = 1, name = "Bulbasaur", cost = 3},
      {speciesId = 152, name = "Chikorita", cost = 3}
    },
    sort = {
      criteria = "COST",
      direction = -1  -- ASC
    }
  }

  local response = sendMessage("SortResults", sortQuery)
  local result = json.decode(response.Data)

  -- All have same cost, so relative order should be preserved (stable sort)
  -- Original order: Pikachu (25), Bulbasaur (1), Chikorita (152)
  if result.sortedSpecies[1].speciesId ~= 25 then
    error("❌ Stable sorting: First should still be Pikachu")
  end
  if result.sortedSpecies[2].speciesId ~= 1 then
    error("❌ Stable sorting: Second should still be Bulbasaur")
  end
  if result.sortedSpecies[3].speciesId ~= 152 then
    error("❌ Stable sorting: Third should still be Chikorita")
  end

  print("✅ Stable sorting preserves relative order for equal values")
end

testStableSorting()

--[[
  Test Suite 22: SortResults Handler - Error Handling
]]

print("\n=== Test Suite 22: SortResults Error Handling ===")

local function testMissingSortData()
  local response = sendMessage("SortResults")

  if not response or response.Action ~= "Error" then
    error("❌ Missing sort data: Should return error")
  end

  if response.ErrorCode ~= "INVALID_SORT" then
    error("❌ Missing sort data: Expected ErrorCode='INVALID_SORT'")
  end

  print("✅ Missing sort data returns proper error")
end

local function testInvalidSortCriteria()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu"}
    },
    sort = {
      criteria = "INVALID",
      direction = -1
    }
  }

  local response = sendMessage("SortResults", sortQuery)

  if not response or response.Action ~= "Error" then
    error("❌ Invalid sort criteria: Should return error")
  end

  if response.ErrorCode ~= "INVALID_SORT" then
    error("❌ Invalid sort criteria: Expected ErrorCode='INVALID_SORT'")
  end

  print("✅ Invalid sort criteria returns proper error")
end

local function testInvalidSortDirection()
  local sortQuery = {
    species = {
      {speciesId = 25, name = "Pikachu"}
    },
    sort = {
      criteria = "NUMBER",
      direction = 5  -- Invalid (should be -1 or 1)
    }
  }

  local response = sendMessage("SortResults", sortQuery)

  if not response or response.Action ~= "Error" then
    error("❌ Invalid sort direction: Should return error")
  end

  if response.ErrorCode ~= "INVALID_SORT" then
    error("❌ Invalid sort direction: Expected ErrorCode='INVALID_SORT'")
  end

  print("✅ Invalid sort direction returns proper error")
end

testMissingSortData()
testInvalidSortCriteria()
testInvalidSortDirection()

print("\n" .. string.rep("=", 50))
print("✅ All SortResults unit tests passed!")
print(string.rep("=", 50))

--[[
  Test Suite 23: GetVisualization Handler
]]

print("\n=== Test Suite 23: GetVisualization ===")

-- Respawn for clean state
aolite.clearAllProcesses()
aolite.spawnProcess(processId, PROCESS_PATH)

local function testGetVisualizationPikachu()
  local response = sendMessage("GetVisualization", nil, {SpeciesId = "25"})

  if not response or response.Action ~= "SaveState" then
    error("❌ GetVisualization: Invalid response action")
  end

  local viz = json.decode(response.Data)

  if viz.speciesId ~= 25 then
    error("❌ GetVisualization: Expected speciesId 25")
  end

  if viz.name ~= "Pikachu" then
    error("❌ GetVisualization: Expected name 'Pikachu'")
  end

  if viz.number ~= "025" then
    error("❌ GetVisualization: Expected number '025'")
  end

  -- Check types
  if not viz.types or not viz.types.primary then
    error("❌ GetVisualization: Missing type data")
  end

  if viz.types.primary.name ~= "Electric" then
    error("❌ GetVisualization: Expected Electric type")
  end

  if viz.types.secondary ~= nil and viz.types.secondary ~= json.null then
    error("❌ GetVisualization: Pikachu should have no secondary type")
  end

  -- Check stats
  if not viz.stats or not viz.stats.base or not viz.stats.calculated then
    error("❌ GetVisualization: Missing stats data")
  end

  if viz.stats.base.hp ~= 35 then
    error("❌ GetVisualization: Expected base HP 35")
  end

  -- Check abilities
  if not viz.abilities or #viz.abilities == 0 then
    error("❌ GetVisualization: Missing abilities")
  end

  -- Check moves
  if not viz.moves or not viz.moves.levelUp or not viz.moves.eggMoves or not viz.moves.tmMoves then
    error("❌ GetVisualization: Missing move data")
  end

  -- Check forms
  if not viz.forms or #viz.forms == 0 then
    error("❌ GetVisualization: Missing forms data")
  end

  -- Check evolution
  if not viz.evolution then
    error("❌ GetVisualization: Missing evolution data")
  end

  print("✅ GetVisualization for Pikachu works correctly")
end

local function testGetVisualizationCharizard()
  local response = sendMessage("GetVisualization", nil, {SpeciesId = "6"})

  if not response or response.Action ~= "SaveState" then
    error("❌ GetVisualization Charizard: Invalid response action")
  end

  local viz = json.decode(response.Data)

  if viz.name ~= "Charizard" then
    error("❌ GetVisualization Charizard: Expected name 'Charizard'")
  end

  -- Check dual types
  if not viz.types.primary or viz.types.primary.name ~= "Fire" then
    error("❌ GetVisualization Charizard: Expected Fire primary type")
  end

  if not viz.types.secondary or viz.types.secondary.name ~= "Flying" then
    error("❌ GetVisualization Charizard: Expected Flying secondary type")
  end

  -- Check multiple forms (Mega evolutions)
  if #viz.forms < 3 then
    error("❌ GetVisualization Charizard: Expected at least 3 forms (Standard + 2 Megas)")
  end

  print("✅ GetVisualization for Charizard works correctly")
end

local function testGetVisualizationNotFound()
  local response = sendMessage("GetVisualization", nil, {SpeciesId = "9999"})

  if not response or response.Action ~= "Error" then
    error("❌ GetVisualization not found: Should return error")
  end

  if response.ErrorCode ~= "SPECIES_NOT_FOUND" then
    error("❌ GetVisualization not found: Expected ErrorCode='SPECIES_NOT_FOUND'")
  end

  print("✅ GetVisualization species not found returns proper error")
end

testGetVisualizationPikachu()
testGetVisualizationCharizard()
testGetVisualizationNotFound()

print("\n" .. string.rep("=", 50))
print("✅ All GetVisualization unit tests passed!")
print(string.rep("=", 50))

--[[
  Test Suite 24: ExportData Handler - JSON Export
]]

print("\n=== Test Suite 24: JSON Export ===")

-- Respawn for clean state
aolite.clearAllProcesses()
aolite.spawnProcess(processId, PROCESS_PATH)

local function testJSONExport()
  local exportConfig = {
    format = "JSON",
    species = {
      {speciesId = 25, name = "Pikachu", generation = 1, types = {13}, cost = 3},
      {speciesId = 1, name = "Bulbasaur", generation = 1, types = {12, 4}, cost = 3}
    },
    columns = {"speciesId", "name", "generation", "types", "cost"}
  }

  local response = sendMessage("ExportData", exportConfig)

  if not response or response.Action ~= "SaveState" then
    error("❌ JSON export: Invalid response action")
  end

  local result = json.decode(response.Data)

  if result.format ~= "JSON" then
    error("❌ JSON export: Expected format 'JSON'")
  end

  if not result.data then
    error("❌ JSON export: Missing data field")
  end

  -- Parse the exported JSON data
  local exportedData = json.decode(result.data)

  if exportedData.totalRecords ~= 2 then
    error("❌ JSON export: Expected 2 records")
  end

  if not exportedData.data or #exportedData.data ~= 2 then
    error("❌ JSON export: Expected 2 species in data array")
  end

  -- Check metadata
  if not result.metadata or not result.metadata.exportDate then
    error("❌ JSON export: Missing metadata")
  end

  print("✅ JSON export works correctly")
end

testJSONExport()

--[[
  Test Suite 25: ExportData Handler - CSV Export
]]

print("\n=== Test Suite 25: CSV Export ===")

local function testCSVExport()
  local exportConfig = {
    format = "CSV",
    species = {
      {speciesId = 25, name = "Pikachu", generation = 1, cost = 3},
      {speciesId = 1, name = "Bulbasaur", generation = 1, cost = 3}
    },
    columns = {"speciesId", "name", "generation", "cost"}
  }

  local response = sendMessage("ExportData", exportConfig)

  if not response or response.Action ~= "SaveState" then
    error("❌ CSV export: Invalid response action")
  end

  local result = json.decode(response.Data)

  if result.format ~= "CSV" then
    error("❌ CSV export: Expected format 'CSV'")
  end

  if not result.data or result.data == "" then
    error("❌ CSV export: Missing CSV data")
  end

  -- Check CSV format (should have header + 2 data rows)
  local lines = {}
  for line in result.data:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  if #lines ~= 3 then  -- Header + 2 rows
    error("❌ CSV export: Expected 3 lines (header + 2 data rows), got " .. tostring(#lines))
  end

  -- Check header
  if lines[1] ~= "speciesId,name,generation,cost" then
    error("❌ CSV export: Invalid header row")
  end

  -- Check first data row
  if not string.find(lines[2], "25") or not string.find(lines[2], "Pikachu") then
    error("❌ CSV export: First row should contain Pikachu data")
  end

  print("✅ CSV export works correctly")
end

testCSVExport()

--[[
  Test Suite 26: ExportData Handler - Error Handling
]]

print("\n=== Test Suite 26: Export Error Handling ===")

local function testInvalidExportFormat()
  local exportConfig = {
    format = "XML",  -- Invalid format
    species = {{speciesId = 25, name = "Pikachu"}}
  }

  local response = sendMessage("ExportData", exportConfig)

  if not response or response.Action ~= "Error" then
    error("❌ Invalid export format: Should return error")
  end

  if response.ErrorCode ~= "INVALID_EXPORT_FORMAT" then
    error("❌ Invalid export format: Expected ErrorCode='INVALID_EXPORT_FORMAT'")
  end

  print("✅ Invalid export format returns proper error")
end

local function testExportSizeExceeded()
  -- Create 1001 species (exceeds limit)
  local largeSpeciesList = {}
  for i = 1, 1001 do
    table.insert(largeSpeciesList, {speciesId = i, name = "Species" .. tostring(i)})
  end

  local exportConfig = {
    format = "JSON",
    species = largeSpeciesList
  }

  local response = sendMessage("ExportData", exportConfig)

  if not response or response.Action ~= "Error" then
    error("❌ Export size exceeded: Should return error")
  end

  if response.ErrorCode ~= "EXPORT_SIZE_EXCEEDED" then
    error("❌ Export size exceeded: Expected ErrorCode='EXPORT_SIZE_EXCEEDED'")
  end

  print("✅ Export size limit enforced correctly")
end

testInvalidExportFormat()
testExportSizeExceeded()

print("\n" .. string.rep("=", 50))
print("✅ All ExportData unit tests passed!")
print(string.rep("=", 50))

--[[
  Test Suite 27: GetAnalytics Handler
]]

print("\n=== Test Suite 27: GetAnalytics ===")

-- Respawn for clean state
aolite.clearAllProcesses()
aolite.spawnProcess(processId, PROCESS_PATH)

local function testGetAnalytics()
  -- First, perform some searches to populate analytics
  sendMessage("SearchPokedex", {textSearch = {name = "Pikachu"}})
  sendMessage("SearchPokedex", {textSearch = {name = "Charizard"}})
  sendMessage("ApplyFilters", {filters = {generation = {1}}})
  sendMessage("ApplyFilters", {filters = {types = {13}}})

  -- Now get analytics
  local response = sendMessage("GetAnalytics")

  if not response or response.Action ~= "SaveState" then
    error("❌ GetAnalytics: Invalid response action")
  end

  local analytics = json.decode(response.Data)

  if not analytics.searchHistory then
    error("❌ GetAnalytics: Missing searchHistory")
  end

  if #analytics.searchHistory ~= 2 then
    error("❌ GetAnalytics: Expected 2 searches in history")
  end

  if not analytics.filterUsage then
    error("❌ GetAnalytics: Missing filterUsage")
  end

  if not analytics.sessionStats then
    error("❌ GetAnalytics: Missing sessionStats")
  end

  if analytics.sessionStats.totalSearches ~= 2 then
    error("❌ GetAnalytics: Expected 2 total searches")
  end

  print("✅ GetAnalytics works correctly")
end

testGetAnalytics()

print("\n" .. string.rep("=", 50))
print("✅ All GetAnalytics unit tests passed!")
print(string.rep("=", 50))

--[[
  Test Suite 28: CustomizePreferences Handler
]]

print("\n=== Test Suite 28: CustomizePreferences ===")

-- Respawn for clean state
aolite.clearAllProcesses()
aolite.spawnProcess(processId, PROCESS_PATH)

local function testGetDefaultPreferences()
  -- Get default preferences (no data sent)
  local response = sendMessage("CustomizePreferences")

  if not response or response.Action ~= "SaveState" then
    error("❌ Get default preferences: Invalid response action")
  end

  local prefs = json.decode(response.Data)

  if not prefs.defaultSort then
    error("❌ Get default preferences: Missing defaultSort")
  end

  if prefs.defaultSort.criteria ~= "NUMBER" then
    error("❌ Get default preferences: Expected default sort NUMBER")
  end

  print("✅ Get default preferences works correctly")
end

local function testUpdatePreferences()
  local preferencesUpdate = {
    savedPresets = {
      {name = "Shiny Gen 1", filters = {generation = {1}, caught = "SHINY"}}
    },
    defaultSort = {criteria = "NAME", direction = -1}
  }

  local response = sendMessage("CustomizePreferences", preferencesUpdate)

  if not response or response.Action ~= "SaveState" then
    error("❌ Update preferences: Invalid response action")
  end

  local result = json.decode(response.Data)

  if not result.preferencesUpdated then
    error("❌ Update preferences: Expected preferencesUpdated flag")
  end

  if not result.currentPreferences or not result.currentPreferences.savedPresets then
    error("❌ Update preferences: Missing current preferences")
  end

  if #result.currentPreferences.savedPresets ~= 1 then
    error("❌ Update preferences: Expected 1 saved preset")
  end

  if result.currentPreferences.defaultSort.criteria ~= "NAME" then
    error("❌ Update preferences: Default sort not updated")
  end

  print("✅ Update preferences works correctly")
end

testGetDefaultPreferences()
testUpdatePreferences()

print("\n" .. string.rep("=", 50))
print("✅ All CustomizePreferences unit tests passed!")
print(string.rep("=", 50))

print("\n" .. string.rep("=", 70))
print("🎉 ALL UNIT TESTS PASSED! Total: 50 tests")
print(string.rep("=", 70))
