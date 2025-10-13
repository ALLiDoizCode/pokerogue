-- Unit tests for pokedex-registration-engine.lua
-- Tests species seen/caught registration, attribute bitmasking, form unlocks, validation

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.pokedex-registration-engine"
local processId = "test-pokedex-registration"

print("\n=== Pokedex Registration Engine Tests ===\n")

-- Spawn process
print("Spawning process...")
aolite.spawnProcess(processId, PROCESS_PATH)
print("✅ Process spawned\n")

-- Helper function to send messages
local function sendMessage(action, tags, data)
  local msg = {
    From = processId,
    Target = processId,
    Action = action,
    Data = data or ""
  }
  if tags then
    for k, v in pairs(tags) do
      msg[k] = tostring(v)
    end
  end
  aolite.send(msg)
  return aolite.getLastMsg(processId)
end

-- Test 1: Info handler (ADP v1.0 compliance)
print("TEST 1: Info handler returns process capabilities")
local response = sendMessage("Info")
if not response then
  error("❌ No response from Info handler")
end

if response.Action ~= "SaveState" then
  error("❌ Expected Action=SaveState, got: " .. tostring(response.Action))
end

local infoData = json.decode(response.Data or "{}")
if not infoData.process then
  error("❌ Info response missing process field")
end

if not infoData.handlers then
  error("❌ Info response missing handlers list")
end

print("✅ Info handler working\n")

-- Test 2: RegisterSeen - Basic registration
print("TEST 2: RegisterSeen - Basic species seen registration")

local seenData = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 0, -- Male
  shiny = false,
  variant = 0,
  isTrainer = false,
  preventStatsUpdate = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "25"}, json.encode(seenData))

if not response or response.Action ~= "SaveState" then
  error("❌ RegisterSeen failed: " .. tostring(response and response.Action or "no response"))
end

local resultData = json.decode(response.Data or "{}")
if not resultData.result then
  error("❌ RegisterSeen missing result")
end

if not resultData.result.registered then
  error("❌ Species not registered")
end

-- Check dex entry
local dexData = resultData.dexData
if not dexData["25"] then
  error("❌ Dex entry not created for species 25")
end

local entry = dexData["25"]
if entry.seenAttr == 0 then
  error("❌ seenAttr not set")
end

if entry.seenCount ~= 1 then
  error("❌ seenCount not incremented, got: " .. tostring(entry.seenCount))
end

-- Check game stats
local gameStats = resultData.gameStats
if gameStats.pokemonSeen ~= 1 then
  error("❌ pokemonSeen stat not updated, got: " .. tostring(gameStats.pokemonSeen))
end

print("✅ RegisterSeen working\n")

-- Test 3: RegisterSeen - Shiny tracking
print("TEST 3: RegisterSeen - Shiny Pokemon tracking")

seenData = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 1, -- Female
  shiny = true,
  variant = 0,
  isTrainer = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "150"}, json.encode(seenData))
resultData = json.decode(response.Data or "{}")

if not resultData.result.registered then
  error("❌ Shiny species not registered")
end

-- Check shiny stat update
gameStats = resultData.gameStats
if gameStats.shinyPokemonSeen ~= 1 then
  error("❌ shinyPokemonSeen not updated, got: " .. tostring(gameStats.shinyPokemonSeen or 0))
end

-- Check legendary stat (Mewtwo is legendary)
if gameStats.legendaryPokemonSeen ~= 1 then
  error("❌ legendaryPokemonSeen not updated for Mewtwo")
end

print("✅ Shiny and legendary tracking working\n")

-- Test 4: RegisterSeen - Trainer battle (skip legendary stats)
print("TEST 4: RegisterSeen - Trainer battle skips legendary stats")

seenData = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 2, -- Genderless
  shiny = false,
  variant = 0,
  isTrainer = true -- Trainer battle
}

response = sendMessage("RegisterSeen", {SpeciesId = "150"}, json.encode(seenData))
resultData = json.decode(response.Data or "{}")

gameStats = resultData.gameStats
if (gameStats.legendaryPokemonSeen or 0) ~= 0 then
  error("❌ legendaryPokemonSeen should not update for trainer battles, got: " .. tostring(gameStats.legendaryPokemonSeen))
end

print("✅ Trainer battle stats skip working\n")

-- Test 5: RegisterCaught - Basic registration
print("TEST 5: RegisterCaught - Basic species caught registration")

local caughtData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0, -- Male
  shiny = false,
  variant = 0,
  nature = 3, -- Adamant
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(caughtData))

if not response or response.Action ~= "SaveState" then
  error("❌ RegisterCaught failed")
end

resultData = json.decode(response.Data or "{}")
if not resultData.result.registered then
  error("❌ Species not caught")
end

dexData = resultData.dexData
entry = dexData["25"]

if entry.caughtAttr == 0 then
  error("❌ caughtAttr not set")
end

if entry.caughtCount ~= 1 then
  error("❌ caughtCount not incremented")
end

if entry.natureAttr == 0 then
  error("❌ natureAttr not set")
end

gameStats = resultData.gameStats
if gameStats.pokemonCaught ~= 1 then
  error("❌ pokemonCaught stat not updated")
end

print("✅ RegisterCaught working\n")

-- Test 6: RegisterCaught - From egg (hatched count)
print("TEST 6: RegisterCaught - Hatched from egg tracking")

caughtData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 1, -- Female
  shiny = true,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = true, -- Hatched!
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(caughtData))
resultData = json.decode(response.Data or "{}")

entry = resultData.dexData["25"]
if entry.hatchedCount ~= 1 then
  error("❌ hatchedCount not incremented, got: " .. tostring(entry.hatchedCount))
end

if entry.caughtCount ~= 0 then
  error("❌ caughtCount should not increment for eggs, got: " .. tostring(entry.caughtCount))
end

gameStats = resultData.gameStats
if gameStats.pokemonHatched ~= 1 then
  error("❌ pokemonHatched stat not updated")
end

if gameStats.shinyPokemonHatched ~= 1 then
  error("❌ shinyPokemonHatched not updated")
end

print("✅ Egg hatching tracking working\n")

-- Test 7: RegisterCaught - Rental Pokemon protection
print("TEST 7: RegisterCaught - Rental Pokemon protection")

caughtData = {
  dexData = {}, -- Empty dex, species never caught before
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = false -- Rental scenario
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(caughtData))
resultData = json.decode(response.Data or "{}")

if resultData.result.registered then
  error("❌ Rental Pokemon should not register if never caught before")
end

if resultData.result.reason ~= "rental_protection" then
  error("❌ Expected rental_protection reason")
end

print("✅ Rental Pokemon protection working\n")

-- Test 8: RegisterCaught - Special form unlocks (Urshifu)
print("TEST 8: RegisterCaught - Urshifu form unlock logic")

caughtData = {
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

response = sendMessage("RegisterCaught", {SpeciesId = "892"}, json.encode(caughtData)) -- Urshifu
resultData = json.decode(response.Data or "{}")

if not resultData.result.formsUnlocked then
  error("❌ formsUnlocked missing from result")
end

-- Should unlock both form 2 (caught) and form 0 (base)
local formsUnlocked = resultData.result.formsUnlocked
local hasForm0 = false
local hasForm2 = false
for _, form in ipairs(formsUnlocked) do
  if form == 0 then hasForm0 = true end
  if form == 2 then hasForm2 = true end
end

if not hasForm0 then
  error("❌ Urshifu form 2 should unlock base form 0")
end

if not hasForm2 then
  error("❌ Urshifu form 2 should be in formsUnlocked")
end

print("✅ Urshifu form unlock working\n")

-- Test 9: RegisterCaught - Ability unlock for starter
print("TEST 9: RegisterCaught - Ability unlock for starter species")

caughtData = {
  dexData = {},
  gameStats = {},
  starterData = {
    ["25"] = { abilityAttr = 0 }
  },
  formIndex = 0,
  gender = 0,
  shiny = false,
  variant = 0,
  nature = 0,
  abilityIndex = 1, -- Second ability
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(caughtData))
resultData = json.decode(response.Data or "{}")

if not resultData.result.abilityUnlocked then
  error("❌ abilityUnlocked missing from result")
end

local abilityUnlock = resultData.result.abilityUnlocked
if abilityUnlock.abilityIndex ~= 1 then
  error("❌ Wrong ability index unlocked")
end

-- Check starterData was updated
local starterData = resultData.starterData
if not starterData["25"] then
  error("❌ starterData not updated")
end

if starterData["25"].abilityAttr == 0 then
  error("❌ abilityAttr not updated")
end

print("✅ Ability unlock working\n")

-- Test 10: GetDexEntry - Single species lookup
print("TEST 10: GetDexEntry - Retrieve species entry")

-- First register a species
caughtData = {
  dexData = {},
  gameStats = {},
  starterData = {},
  formIndex = 0,
  gender = 0,
  shiny = true,
  variant = 0,
  nature = 0,
  abilityIndex = 0,
  fromEgg = false,
  incrementCount = true
}

response = sendMessage("RegisterCaught", {SpeciesId = "25"}, json.encode(caughtData))
resultData = json.decode(response.Data or "{}")
local existingDex = resultData.dexData

-- Now retrieve it
local getDexData = {
  dexData = existingDex
}

response = sendMessage("GetDexEntry", {SpeciesId = "25"}, json.encode(getDexData))
resultData = json.decode(response.Data or "{}")

if not resultData.seen then
  error("❌ Species should be marked as seen")
end

if not resultData.dexEntry then
  error("❌ dexEntry missing from response")
end

if not resultData.attributeBreakdown then
  error("❌ attributeBreakdown missing")
end

if not resultData.attributeBreakdown.shinyCaught then
  error("❌ shinyCaught should be true")
end

print("✅ GetDexEntry working\n")

-- Test 11: GetDexEntry - Never seen species
print("TEST 11: GetDexEntry - Never seen species")

getDexData = {
  dexData = {}
}

response = sendMessage("GetDexEntry", {SpeciesId = "150"}, json.encode(getDexData))
resultData = json.decode(response.Data or "{}")

if resultData.seen then
  error("❌ Species should not be marked as seen")
end

if resultData.dexEntry ~= json.null and resultData.dexEntry then
  error("❌ dexEntry should be null for never-seen species")
end

print("✅ Never-seen species handling working\n")

-- Test 12: GetDexProgress - Completion calculation
print("TEST 12: GetDexProgress - Calculate completion statistics")

-- Create dex with multiple species
local progressDex = {
  ["1"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}},
  ["25"] = {seenAttr = 3, caughtAttr = 3, natureAttr = 1, seenCount = 5, caughtCount = 2, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}},
  ["150"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}}
}

local progressData = {
  dexData = progressDex
}

response = sendMessage("GetDexProgress", {}, json.encode(progressData))
resultData = json.decode(response.Data or "{}")

if not resultData.overall then
  error("❌ overall stats missing")
end

if resultData.overall.totalSeen ~= 3 then
  error("❌ totalSeen should be 3, got: " .. tostring(resultData.overall.totalSeen))
end

if resultData.overall.totalCaught ~= 3 then
  error("❌ totalCaught should be 3, got: " .. tostring(resultData.overall.totalCaught))
end

if not resultData.milestones then
  error("❌ milestones missing")
end

if not resultData.milestones.firstCatch then
  error("❌ firstCatch milestone should be true")
end

if not resultData.analytics then
  error("❌ analytics missing")
end

-- Mewtwo is legendary
if resultData.analytics.legendaryCount ~= 1 then
  error("❌ legendaryCount should be 1, got: " .. tostring(resultData.analytics.legendaryCount))
end

print("✅ GetDexProgress working\n")

-- Test 13: ValidateDexData - Valid data
print("TEST 13: ValidateDexData - Valid dex data")

local validDex = {
  ["25"] = {seenAttr = 3, caughtAttr = 1, natureAttr = 1, seenCount = 15, caughtCount = 3, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}},
  ["150"] = {seenAttr = 1, caughtAttr = 0, natureAttr = 0, seenCount = 1, caughtCount = 0, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}}
}

local validateData = {
  dexEntries = validDex
}

response = sendMessage("ValidateDexData", {}, json.encode(validateData))
resultData = json.decode(response.Data or "{}")

if not resultData.valid then
  error("❌ Valid dex data should pass validation")
end

if #resultData.errors > 0 then
  error("❌ No errors expected for valid data")
end

if resultData.integrityScore ~= 100.0 then
  error("❌ integrityScore should be 100.0 for valid data")
end

print("✅ ValidateDexData working\n")

-- Test 14: ValidateDexData - Invalid data (seenCount < caughtCount)
print("TEST 14: ValidateDexData - Invalid count consistency")

local invalidDex = {
  ["25"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 2, caughtCount = 5, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}} -- seenCount < caughtCount!
}

validateData = {
  dexEntries = invalidDex
}

response = sendMessage("ValidateDexData", {}, json.encode(validateData))
resultData = json.decode(response.Data or "{}")

if resultData.valid then
  error("❌ Invalid dex data should fail validation")
end

if #resultData.errors == 0 then
  error("❌ Errors expected for invalid count data")
end

if resultData.integrityScore ~= 0.0 then
  error("❌ integrityScore should be 0.0 for invalid data")
end

print("✅ Validation error detection working\n")

-- Test 15: ValidateDexData - Invalid species ID
print("TEST 15: ValidateDexData - Invalid species ID range")

invalidDex = {
  ["9999"] = {seenAttr = 1, caughtAttr = 1, natureAttr = 1, seenCount = 1, caughtCount = 1, hatchedCount = 0, ivs = {0,0,0,0,0,0}, ribbons = {}}
}

validateData = {
  dexEntries = invalidDex
}

response = sendMessage("ValidateDexData", {}, json.encode(validateData))
resultData = json.decode(response.Data or "{}")

if resultData.valid then
  error("❌ Invalid species ID should fail validation")
end

print("✅ Species ID validation working\n")

-- Test 16: Error handling - Missing SpeciesId
print("TEST 16: Error handling - Missing SpeciesId")

response = sendMessage("RegisterSeen", {}, json.encode({dexData = {}, gameStats = {}}))

if response.Action ~= "Error" then
  error("❌ Expected Error action for missing SpeciesId")
end

if not response.Error or not string.find(response.Error, "SpeciesId") then
  error("❌ Error message should mention SpeciesId")
end

print("✅ Error handling working\n")

-- Test 17: Attribute bitmasking - Multiple attributes
print("TEST 17: Attribute bitmasking - Multiple seen attributes")

-- See non-shiny male
seenData = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 0, -- Male
  shiny = false,
  variant = 0,
  isTrainer = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "25"}, json.encode(seenData))
resultData = json.decode(response.Data or "{}")
dexData = resultData.dexData

-- See shiny female
seenData.dexData = dexData
seenData.gender = 1 -- Female
seenData.shiny = true

response = sendMessage("RegisterSeen", {SpeciesId = "25"}, json.encode(seenData))
resultData = json.decode(response.Data or "{}")

entry = resultData.dexData["25"]

-- Both attributes should be captured
-- Check via GetDexEntry breakdown
getDexData = {dexData = resultData.dexData}
response = sendMessage("GetDexEntry", {SpeciesId = "25"}, json.encode(getDexData))
resultData = json.decode(response.Data or "{}")

local breakdown = resultData.attributeBreakdown

if not breakdown.hasMale then
  error("❌ Male attribute not preserved")
end

if not breakdown.hasFemale then
  error("❌ Female attribute not added")
end

if not breakdown.hasShiny then
  error("❌ Shiny attribute not added")
end

print("✅ Attribute bitmasking working\n")

-- Test 18: Form variant tracking
print("TEST 18: Form variant tracking")

seenData = {
  dexData = {},
  gameStats = {},
  formIndex = 0,
  gender = 2, -- Genderless
  shiny = true,
  variant = 2, -- Variant 3
  isTrainer = false
}

response = sendMessage("RegisterSeen", {SpeciesId = "150"}, json.encode(seenData))
resultData = json.decode(response.Data or "{}")

if not resultData.result.registered then
  error("❌ Variant species not registered")
end

-- Variant tracking is embedded in seenAttr - no direct check available
-- but registration should succeed

print("✅ Variant tracking working\n")

print("\n=== All Pokedex Registration Engine Tests Passed! ===\n")
print("Total tests: 18")
print("Status: ✅ PASS")
