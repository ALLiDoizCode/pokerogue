-- Parity tests for pokedex-registration-engine.lua
-- Verifies Lua implementation matches TypeScript behavior from src/system/game-data.ts

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.pokedex-registration-engine"
local processId = "test-pokedex-parity"

print("\n=== Pokedex Registration Parity Tests ===\n")
print("Comparing Lua implementation vs TypeScript src/system/game-data.ts\n")

-- Spawn process
print("Spawning process...")
aolite.spawnProcess(processId, PROCESS_PATH)
print("✅ Process spawned\n")

-- Helper function
local function sendMessage(action, tags, data)
  local msg = {
    From = processId,
    Target = processId,
    Action = action,
    Data = data or ""
  }
  if tags then
    for k, v in pairs(tags) do msg[k] = tostring(v) end
  end
  aolite.send(msg)
  return aolite.getLastMsg(processId)
end

-- PARITY TEST 1: seenAttr bitmasking matches TypeScript OR operation
print("PARITY TEST 1: seenAttr bitmasking (TS: dexEntry.seenAttr |= pokemon.getDexAttr())")

-- First encounter: male, non-shiny
local data1 = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 0, -- Male
  shiny = false,
  variant = 0,
  isTrainer = false
}

local response = sendMessage("RegisterSeen", {SpeciesId = "25"}, json.encode(data1))
local result1 = json.decode(response.Data)
local seenAttr1 = result1.dexData["25"].seenAttr

-- Second encounter: female, shiny (should OR with first)
local data2 = {
  dexData = result1.dexData,
  gameStats = result1.gameStats,
  formIndex = 0,
  gender = 1, -- Female
  shiny = true,
  variant = 0,
  isTrainer = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "25"}, json.encode(data2))
local result2 = json.decode(response.Data)
local seenAttr2 = result2.dexData["25"].seenAttr

-- Verify OR operation: seenAttr should preserve previous attributes
if seenAttr2 <= seenAttr1 then
  error("❌ PARITY FAIL: seenAttr2 should include attributes from both encounters")
end

-- Verify both attributes present via GetDexEntry
local getDexData = {dexData = result2.dexData}
response = sendMessage("GetDexEntry", {SpeciesId = "25"}, json.encode(getDexData))
local entryData = json.decode(response.Data)

if not entryData.attributeBreakdown.hasMale then
  error("❌ PARITY FAIL: Male attribute not preserved after female encounter")
end

if not entryData.attributeBreakdown.hasFemale then
  error("❌ PARITY FAIL: Female attribute not added")
end

if not entryData.attributeBreakdown.hasShiny then
  error("❌ PARITY FAIL: Shiny attribute not added")
end

print("✅ PARITY PASS: Attribute bitmasking matches TypeScript OR behavior\n")

-- PARITY TEST 2: Game stats increment matches TypeScript (gameStats.pokemonSeen++)
print("PARITY TEST 2: Game statistics updates (TS: this.gameStats.pokemonSeen++)")

local freshData = {
  dexData = {},
  gameStats = {pokemonSeen = 0},
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  isTrainer = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "1"}, json.encode(freshData))
local statsResult = json.decode(response.Data)

if statsResult.gameStats.pokemonSeen ~= 1 then
  error("❌ PARITY FAIL: pokemonSeen should increment to 1, got: " .. tostring(statsResult.gameStats.pokemonSeen))
end

print("✅ PARITY PASS: Game stats increment matches TypeScript\n")

-- PARITY TEST 3: Legendary stats skip in trainer battles (TS: !trainer && pokemon.species.legendary)
print("PARITY TEST 3: Trainer battle legendary skip (TS: !trainer && pokemon.species.legendary)")

-- Wild legendary (should count)
local wildLegendary = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 2,
  shiny = false,
  variant = 0,
  isTrainer = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "150"}, json.encode(wildLegendary)) -- Mewtwo
local wildResult = json.decode(response.Data)

if (wildResult.gameStats.legendaryPokemonSeen or 0) == 0 then
  error("❌ PARITY FAIL: Wild legendary should increment legendaryPokemonSeen")
end

-- Trainer legendary (should NOT count)
local trainerLegendary = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 2,
  shiny = false,
  variant = 0,
  isTrainer = true -- Trainer battle!
}

response = sendMessage("RegisterSeen", {SpeciesId = "150"}, json.encode(trainerLegendary))
local trainerResult = json.decode(response.Data)

if (trainerResult.gameStats.legendaryPokemonSeen or 0) ~= 0 then
  error("❌ PARITY FAIL: Trainer legendary should NOT increment legendaryPokemonSeen, got: " .. tostring(trainerResult.gameStats.legendaryPokemonSeen))
end

print("✅ PARITY PASS: Trainer battle legendary skip matches TypeScript\n")

-- PARITY TEST 4: Mystery encounter stats prevention (TS: preventGameStatsUpdates)
print("PARITY TEST 4: Mystery encounter stats prevention (TS: preventGameStatsUpdates check)")

local mysteryData = {
  dexData = {},
  gameStats = {pokemonSeen = 0},
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  isTrainer = false,
  preventStatsUpdate = true -- Mystery encounter flag
}

response = sendMessage("RegisterSeen", {SpeciesId = "25"}, json.encode(mysteryData))
local mysteryResult = json.decode(response.Data)

-- Dex entry should still update
if not mysteryResult.dexData["25"] then
  error("❌ PARITY FAIL: Dex entry should update even with preventStatsUpdate")
end

-- But game stats should NOT
if mysteryResult.gameStats.pokemonSeen ~= 0 then
  error("❌ PARITY FAIL: pokemonSeen should not increment with preventStatsUpdate, got: " .. tostring(mysteryResult.gameStats.pokemonSeen))
end

print("✅ PARITY PASS: Mystery encounter stats prevention matches TypeScript\n")

-- PARITY TEST 5: caughtAttr bitmasking (TS: dexEntry.caughtAttr |= dexAttr)
print("PARITY TEST 5: caughtAttr bitmasking (TS: dexEntry.caughtAttr |= dexAttr)")

local catchData1 = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0, -- Male
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(catchData1))
local catchResult1 = json.decode(response.Data)
local caughtAttr1 = catchResult1.dexData["25"].caughtAttr

-- Catch shiny female
local catchData2 = {
  dexData = catchResult1.dexData,
  gameStats = catchResult1.gameStats,
  starterData = catchResult1.starterData,
  formIndex = 0,
  gender = 1, -- Female
  shiny = true,
  variant = 0,
  nature = 1,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(catchData2))
local catchResult2 = json.decode(response.Data)
local caughtAttr2 = catchResult2.dexData["25"].caughtAttr

-- Verify OR operation preserved previous attributes
if caughtAttr2 <= caughtAttr1 then
  error("❌ PARITY FAIL: caughtAttr2 should include attributes from both catches")
end

getDexData = {dexData = catchResult2.dexData}
response = sendMessage("GetDexEntry", {SpeciesId = "25"}, json.encode(getDexData))
entryData = json.decode(response.Data)

if not entryData.attributeBreakdown.maleCaught then
  error("❌ PARITY FAIL: Male caught attribute not preserved")
end

if not entryData.attributeBreakdown.femaleCaught then
  error("❌ PARITY FAIL: Female caught attribute not added")
end

if not entryData.attributeBreakdown.shinyCaught then
  error("❌ PARITY FAIL: Shiny caught attribute not added")
end

print("✅ PARITY PASS: caughtAttr bitmasking matches TypeScript\n")

-- PARITY TEST 6: Nature tracking (TS: dexEntry.natureAttr |= 1 << (pokemon.nature + 1))
print("PARITY TEST 6: Nature tracking (TS: dexEntry.natureAttr |= 1 << (pokemon.nature + 1))")

local natureData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 3, -- Adamant (index 3)
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(natureData))
local natureResult = json.decode(response.Data)
local natureAttr = natureResult.dexData["25"].natureAttr

-- natureAttr should have bit for nature 3 set (1 << 4 = 16 since nature+1)
-- Expected: 1 << (3 + 1) = 1 << 4 = 16
if natureAttr == 0 then
  error("❌ PARITY FAIL: natureAttr should be set for nature 3")
end

-- Catch with different nature
natureData.dexData = natureResult.dexData
natureData.nature = 0 -- Hardy (index 0)

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(natureData))
natureResult = json.decode(response.Data)
local natureAttr2 = natureResult.dexData["25"].natureAttr

-- Should have both natures
if natureAttr2 <= natureAttr then
  error("❌ PARITY FAIL: natureAttr should include both natures")
end

print("✅ PARITY PASS: Nature tracking matches TypeScript bitmask logic\n")

-- PARITY TEST 7: Hatched vs caught count (TS: fromEgg ? dexEntry.hatchedCount++ : dexEntry.caughtCount++)
print("PARITY TEST 7: Hatched vs caught count (TS: fromEgg branch logic)")

local hatchData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = true, -- Hatched!
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(hatchData))
local hatchResult = json.decode(response.Data)

if hatchResult.dexData["25"].hatchedCount ~= 1 then
  error("❌ PARITY FAIL: hatchedCount should be 1 for fromEgg=true")
end

if hatchResult.dexData["25"].caughtCount ~= 0 then
  error("❌ PARITY FAIL: caughtCount should be 0 for fromEgg=true, got: " .. tostring(hatchResult.dexData["25"].caughtCount))
end

if hatchResult.gameStats.pokemonHatched ~= 1 then
  error("❌ PARITY FAIL: pokemonHatched stat should be 1")
end

if (hatchResult.gameStats.pokemonCaught or 0) ~= 0 then
  error("❌ PARITY FAIL: pokemonCaught stat should be 0 for hatched")
end

print("✅ PARITY PASS: Hatched vs caught counting matches TypeScript\n")

-- PARITY TEST 8: Rental Pokemon protection (TS: !incrementCount && !dexData[speciesRootForm].caughtAttr)
print("PARITY TEST 8: Rental Pokemon protection (TS: rental Pokemon check)")

local rentalData = {
  dexData = {}, -- Empty, species never caught
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = false -- Rental scenario!
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(rentalData))
local rentalResult = json.decode(response.Data)

if rentalResult.result.registered then
  error("❌ PARITY FAIL: Rental Pokemon should not register if never caught before")
end

if rentalResult.result.reason ~= "rental_protection" then
  error("❌ PARITY FAIL: Expected rental_protection reason")
end

-- Now if species WAS caught before, rental should update
local preCaughtData = {
  ["25"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}}
}

rentalData.dexData = preCaughtData
rentalData.incrementCount = false -- Still rental

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(rentalData))
rentalResult = json.decode(response.Data)

if not rentalResult.result.registered then
  error("❌ PARITY FAIL: Rental Pokemon SHOULD register if species already caught")
end

print("✅ PARITY PASS: Rental Pokemon protection matches TypeScript\n")

-- PARITY TEST 9: Urshifu form unlock (TS: Special form mapping logic)
print("PARITY TEST 9: Urshifu form unlock (TS: formIndex 2 → unlock form 0)")

local urshifuData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 2, -- Single Strike (Rapid Strike Style)
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "892"}, json.encode(urshifuData)) -- Urshifu
local urshifuResult = json.decode(response.Data)

-- Should unlock both form 2 (caught) and form 0 (base)
local formsUnlocked = urshifuResult.result.formsUnlocked
local hasForm0 = false
local hasForm2 = false
for _, form in ipairs(formsUnlocked) do
  if form == 0 then hasForm0 = true end
  if form == 2 then hasForm2 = true end
end

if not hasForm0 then
  error("❌ PARITY FAIL: Urshifu form 2 should unlock base form 0 (TS: formIndex === 2 → unlock form 0)")
end

if not hasForm2 then
  error("❌ PARITY FAIL: Urshifu form 2 should be in formsUnlocked")
end

print("✅ PARITY PASS: Urshifu form unlock matches TypeScript special case\n")

-- PARITY TEST 10: Zygarde form unlock (TS: Special form mapping logic)
print("PARITY TEST 10: Zygarde form unlock (TS: formIndex 4 → unlock form 2)")

local zygardeData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 4, -- Complete form
  gender = 2,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "718"}, json.encode(zygardeData)) -- Zygarde
local zygardeResult = json.decode(response.Data)

formsUnlocked = zygardeResult.result.formsUnlocked
local hasForm2 = false
local hasForm4 = false
for _, form in ipairs(formsUnlocked) do
  if form == 2 then hasForm2 = true end
  if form == 4 then hasForm4 = true end
end

if not hasForm2 then
  error("❌ PARITY FAIL: Zygarde form 4 should unlock form 2 (TS: formIndex === 4 → unlock form 2)")
end

if not hasForm4 then
  error("❌ PARITY FAIL: Zygarde form 4 should be in formsUnlocked")
end

print("✅ PARITY PASS: Zygarde form unlock matches TypeScript special case\n")

-- PARITY TEST 11: Ability unlock for starters (TS: starterData[speciesId].abilityAttr |= abilityBit)
print("PARITY TEST 11: Ability unlock (TS: starterData[speciesId].abilityAttr |= abilityBit)")

local abilityData = {
  dexData = {},
  gameStats = {},
  starterData = {
    ["25"] = {abilityAttr = 0}
  },
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 1, -- Second ability (bit 1)
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(abilityData))
local abilityResult = json.decode(response.Data)

if not abilityResult.result.abilityUnlocked then
  error("❌ PARITY FAIL: abilityUnlocked should be present for starter species")
end

if abilityResult.result.abilityUnlocked.abilityIndex ~= 1 then
  error("❌ PARITY FAIL: Wrong ability index unlocked")
end

-- Ability bit should be set (1 << 1 = 2)
if abilityResult.starterData["25"].abilityAttr == 0 then
  error("❌ PARITY FAIL: abilityAttr should be updated")
end

print("✅ PARITY PASS: Ability unlock matches TypeScript bitmask logic\n")

-- PARITY TEST 12: Progress calculation (TS: totalCaught / MAX_SPECIES_COUNT)
print("PARITY TEST 12: Progress calculation (TS: completion percentage)")

local progressDex = {
  ["1"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}},
  ["25"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}},
  ["150"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}}
}

local progressData = {dexData = progressDex}
response = sendMessage("GetDexProgress", {}, json.encode(progressData))
local progressResult = json.decode(response.Data)

if progressResult.overall.totalCaught ~= 3 then
  error("❌ PARITY FAIL: totalCaught should be 3")
end

-- Calculate expected percentage: 3 / 1025 * 100
local expectedPercentage = (3 / 1025) * 100

if math.abs(progressResult.overall.completionPercentage - expectedPercentage) > 0.01 then
  error("❌ PARITY FAIL: completionPercentage calculation mismatch. Expected: " .. expectedPercentage .. ", got: " .. progressResult.overall.completionPercentage)
end

print("✅ PARITY PASS: Progress calculation matches TypeScript\n")

-- PARITY TEST 13: Validation - seenCount >= caughtCount (TS: data integrity)
print("PARITY TEST 13: Validation logic (TS: data integrity checks)")

local invalidDex = {
  ["25"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 2, caughtCount = 5, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}} -- Invalid: seenCount < caughtCount
}

local validateData = {dexEntries = invalidDex}
response = sendMessage("ValidateDexData", {}, json.encode(validateData))
local validateResult = json.decode(response.Data)

if validateResult.valid then
  error("❌ PARITY FAIL: Should detect seenCount < caughtCount violation")
end

if #validateResult.errors == 0 then
  error("❌ PARITY FAIL: Should report errors for invalid data")
end

print("✅ PARITY PASS: Validation logic detects data integrity violations\n")

print("\n=== All Parity Tests Passed! ===\n")
print("Total parity checks: 13")
print("Status: ✅ PASS")
print("\nBehavioral parity with TypeScript src/system/game-data.ts confirmed!")
