--[[
  Parity Tests: Advanced Pokedex Features Engine

  Validates that Lua implementation matches TypeScript behavior patterns
  from src/ui/pokedex-ui-handler.ts (updateStarters method).

  Key behavior validations:
  - Text search matching (name, move, ability)
  - Filter application (generation, type, biome, caught, unlocks, misc)
  - Sort criteria and direction
  - Combined filter AND logic
  - Visualization data structure
  - Export format accuracy
]]

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.advanced-pokedex-features-engine"
local processId = "parity-test-advanced-pokedex"

print("\n🔍 Advanced Pokedex Features - Parity Testing")
print("Comparing Lua implementation against TypeScript behavior patterns\n")

-- Spawn process
aolite.spawnProcess(processId, PROCESS_PATH)

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
  Parity Test 1: Text Search Behavior
  Reference: src/ui/pokedex-ui-handler.ts:1392-1416 (move and name filtering)
]]

print("📝 Parity Test 1: Text Search (NAME filter)")

-- TypeScript behavior: case-insensitive exact match
local response1 = sendMessage("SearchPokedex", {textSearch = {name = "pikachu"}})
local result1 = json.decode(response1.Data)

if not (result1.species and #result1.species >= 1 and result1.species[1].name == "Pikachu") then
  error("❌ Parity: Name search case-insensitive matching failed")
end

if result1.species[1].matchScore ~= 100 then
  error("❌ Parity: Exact name match should score 100")
end

print("✅ Text search NAME filter matches TypeScript behavior")

--[[
  Parity Test 2: Filter Combination Logic
  Reference: src/ui/pokedex-ui-handler.ts:1695-1716 (AND logic for all filters)
]]

print("\n📝 Parity Test 2: Combined Filters (AND Logic)")

-- TypeScript behavior: ALL filters must match (AND logic, not OR)
local response2 = sendMessage("ApplyFilters", {
  filters = {
    generation = {1},
    types = {13},  -- Electric
    caught = "SHINY"
  }
})
local result2 = json.decode(response2.Data)

-- Should only include Pikachu (Gen 1 AND Electric AND Shiny)
if not result2.filteredSpecies then
  error("❌ Parity: Missing filteredSpecies in response")
end

-- Verify AND logic: if any filter doesn't match, species excluded
if result2.filteredCount ~= 1 then
  print("DEBUG: filteredCount = " .. tostring(result2.filteredCount))
  error("❌ Parity: Combined filters should use AND logic (expected 1 species)")
end

print("✅ Combined filters use AND logic matching TypeScript")

--[[
  Parity Test 3: Sort Criteria Behavior
  Reference: src/ui/pokedex-ui-handler.ts:1723-1763 (sort implementation)
]]

print("\n📝 Parity Test 3: Sort Criteria (NUMBER)")

-- TypeScript behavior: sort.dir multiplier (-sort.dir for direction)
local response3 = sendMessage("SortResults", {
  species = {
    {speciesId = 25, name = "Pikachu"},
    {speciesId = 1, name = "Bulbasaur"},
    {speciesId = 6, name = "Charizard"}
  },
  sort = {
    criteria = "NUMBER",
    direction = -1  -- ASC in TypeScript
  }
})
local result3 = json.decode(response3.Data)

-- TypeScript sorts with (a.speciesId - b.speciesId) * -sort.dir
-- For ASC (dir=-1): (a - b) * -(-1) = (a - b) * 1, so ascending order
if result3.sortedSpecies[1].speciesId ~= 1 or
   result3.sortedSpecies[2].speciesId ~= 6 or
   result3.sortedSpecies[3].speciesId ~= 25 then
  error("❌ Parity: Sort NUMBER ASC order incorrect")
end

print("✅ Sort by NUMBER matches TypeScript behavior")

--[[
  Parity Test 4: Sort Direction Toggle
  Reference: src/ui/pokedex-ui-handler.ts:1726 (direction multiplier)
]]

print("\n📝 Parity Test 4: Sort Direction (DESC)")

local response4 = sendMessage("SortResults", {
  species = {
    {speciesId = 1, name = "Bulbasaur"},
    {speciesId = 6, name = "Charizard"},
    {speciesId = 25, name = "Pikachu"}
  },
  sort = {
    criteria = "NUMBER",
    direction = 1  -- DESC in TypeScript
  }
})
local result4 = json.decode(response4.Data)

-- DESC order: 25, 6, 1
if result4.sortedSpecies[1].speciesId ~= 25 or
   result4.sortedSpecies[3].speciesId ~= 1 then
  error("❌ Parity: Sort NUMBER DESC order incorrect")
end

print("✅ Sort direction toggle matches TypeScript")

--[[
  Parity Test 5: Filter State Handling
  Reference: src/ui/dropdown.ts:8-15 (DropDownState enum)
]]

print("\n📝 Parity Test 5: Filter States (UNLOCKABLE)")

-- TypeScript behavior: UNLOCKABLE state filters for unlockable but not yet unlocked
local response5 = sendMessage("ApplyFilters", {
  filters = {
    unlocks = {
      passive = "UNLOCKABLE"
    }
  }
})
local result5 = json.decode(response5.Data)

-- Should only include species with passive = "UNLOCKABLE"
for _, species in ipairs(result5.filteredSpecies) do
  -- In our test data, only Chikorita has passive="UNLOCKABLE"
  if species.name == "Chikorita" then
    -- Expected
  else
    error("❌ Parity: UNLOCKABLE filter should only match unlockable species")
  end
end

print("✅ Filter state UNLOCKABLE matches TypeScript")

--[[
  Parity Test 6: Type Filter (Primary OR Secondary)
  Reference: src/ui/pokedex-ui-handler.ts:1488-1490 (type matching)
]]

print("\n📝 Parity Test 6: Type Filter (Primary OR Secondary)")

-- TypeScript behavior: species.isOfType((type as number) - 1)
-- Matches if species has type as primary OR secondary
local response6 = sendMessage("ApplyFilters", {
  filters = {
    types = {3}  -- Flying type (Charizard's secondary)
  }
})
local result6 = json.decode(response6.Data)

-- Should include Charizard (Fire/Flying)
local foundCharizard = false
for _, species in ipairs(result6.filteredSpecies) do
  if species.name == "Charizard" then
    foundCharizard = true
    break
  end
end

if not foundCharizard then
  error("❌ Parity: Type filter should match secondary type")
end

print("✅ Type filter matches primary OR secondary (TypeScript behavior)")

--[[
  Parity Test 7: NAME Sort (Case-Insensitive)
  Reference: src/ui/pokedex-ui-handler.ts:1745-1746 (localeCompare for NAME sort)
]]

print("\n📝 Parity Test 7: Sort by NAME (Alphabetical)")

local response7 = sendMessage("SortResults", {
  species = {
    {speciesId = 25, name = "Pikachu"},
    {speciesId = 1, name = "Bulbasaur"},
    {speciesId = 6, name = "Charizard"}
  },
  sort = {
    criteria = "NAME",
    direction = -1  -- ASC
  }
})
local result7 = json.decode(response7.Data)

-- Alphabetical: Bulbasaur, Charizard, Pikachu
if result7.sortedSpecies[1].name ~= "Bulbasaur" or
   result7.sortedSpecies[2].name ~= "Charizard" or
   result7.sortedSpecies[3].name ~= "Pikachu" then
  error("❌ Parity: NAME sort alphabetical order incorrect")
end

print("✅ Sort by NAME alphabetical matches TypeScript")

--[[
  Parity Test 8: Caught Status Filter (NORMAL vs SHINY variants)
  Reference: src/ui/pokedex-ui-handler.ts:1518-1534 (caught status filtering)
]]

print("\n📝 Parity Test 8: Caught Status (SHINY Variants)")

-- TypeScript behavior: SHINY, SHINY2, SHINY3 are distinct caught statuses
local response8 = sendMessage("ApplyFilters", {
  filters = {
    caught = "SHINY2"  -- Variant 2 specifically
  }
})
local result8 = json.decode(response8.Data)

-- Should only include species with shinyVariant = 2 (Chikorita in test data)
for _, species in ipairs(result8.filteredSpecies) do
  if species.name == "Chikorita" then
    -- Expected
  else
    error("❌ Parity: SHINY2 filter should only match variant 2")
  end
end

print("✅ Shiny variant filtering matches TypeScript")

--[[
  Parity Summary
]]

print("\n" .. string.rep("=", 70))
print("✅ ALL PARITY TESTS PASSED!")
print("Lua implementation matches TypeScript behavior patterns")
print(string.rep("=", 70))
