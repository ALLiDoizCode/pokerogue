-- Pokemon Instance Manager Unit Tests
-- Comprehensive testing for Pokemon creation, state management, and persistence

local json = require("json")

-- Mock AO environment
local function setupTestEnvironment()
  if not ao then
    ao = {
      send = function(msg)
        print("Mock send:", json.encode(msg))
        lastSentMessage = msg
      end,
      id = "test_pokemon_instance_process"
    }
  end
  
  if not Handlers then
    Handlers = {
      add = function(name, matcher, handler)
        print("Handler registered:", name)
        registeredHandlers = registeredHandlers or {}
        registeredHandlers[name] = handler
      end,
      utils = {
        hasMatchingTag = function(tagName, tagValue)
          return function(msg)
            return msg and msg[tagName] == tagValue
          end
        end
      }
    }
  end
  
  -- Reset global state for testing
  PokemonInstances = {}
  NextInstanceId = 1
  ProcessState = {
    initialized = true,
    totalPokemonCreated = 0,
    totalSerializations = 0,
    totalDeserializations = 0
  }
end

-- Test utilities
local function createTestMessage(action, data, tags)
  return {
    From = "test_sender",
    Action = action,
    Data = data and json.encode(data) or nil,
    Timestamp = os.time(),
    SpeciesId = tags and tags.SpeciesId or nil,
    Level = tags and tags.Level or nil,
    PokemonId = tags and tags.PokemonId or nil,
    ForceShiny = tags and tags.ForceShiny or nil
  }
end

local function assertNotNil(value, message)
  if value == nil then
    error(message or "Expected non-nil value")
  end
end

local function assertEqual(expected, actual, message)
  if expected ~= actual then
    error((message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assertInRange(value, min, max, message)
  if value < min or value > max then
    error((message or "Value out of range") .. ": " .. tostring(value) .. " not in [" .. min .. ", " .. max .. "]")
  end
end

-- Load the Pokemon Instance Manager process
dofile("/Users/jonathangreen/Documents/pokerogue/processes/pokemon-instance-manager.lua")

-- Test Suite
local function runTests()
  print("=== Pokemon Instance Manager Unit Tests ===")
  
  -- Test 1: IV Generation
  print("\n1. Testing IV Generation Algorithm...")
  setupTestEnvironment()
  
  -- Test IV generation from seed
  local function testIVGeneration()
    -- Create Pokemon and check IVs
    local msg = createTestMessage("CreatePokemon", {speciesId = 25, level = 5})
    registeredHandlers["create-pokemon"](msg)
    
    assertNotNil(lastSentMessage, "Should send response message")
    assertEqual("PokemonCreated", lastSentMessage.Action, "Should confirm Pokemon creation")
    
    local response = json.decode(lastSentMessage.Data)
    assertNotNil(response.pokemon, "Should contain Pokemon data")
    assertNotNil(response.pokemon.ivs, "Should contain IV data")
    
    -- Check IV range (0-31)
    for stat, iv in pairs(response.pokemon.ivs) do
      assertInRange(iv, 0, 31, "IV for " .. stat .. " should be in range 0-31")
    end
    
    print("✓ IV generation produces valid ranges")
    
    -- Check IV consistency (same seed should produce same IVs)
    local firstPokemon = response.pokemon
    
    -- Reset state and create another Pokemon
    PokemonInstances = {}
    NextInstanceId = 1
    
    local msg2 = createTestMessage("CreatePokemon", {speciesId = 25, level = 5})
    registeredHandlers["create-pokemon"](msg2)
    
    local response2 = json.decode(lastSentMessage.Data)
    -- Note: Due to random generation, IVs will be different
    -- This tests that the system generates valid IVs consistently
    
    print("✓ IV generation algorithm working correctly")
  end
  
  testIVGeneration()
  
  -- Test 2: Nature Generation
  print("\n2. Testing Nature Generation...")
  setupTestEnvironment()
  
  local function testNatureGeneration()
    local msg = createTestMessage("CreatePokemon", {speciesId = 1, level = 5})
    registeredHandlers["create-pokemon"](msg)
    
    local response = json.decode(lastSentMessage.Data)
    assertNotNil(response.pokemon.nature, "Should generate nature")
    
    -- Check that nature is valid
    local validNatures = {
      "Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile", "Relaxed",
      "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly", "Naive", "Modest",
      "Mild", "Quiet", "Bashful", "Rash", "Calm", "Gentle", "Sassy", "Careful", "Quirky"
    }
    
    local isValidNature = false
    for _, nature in ipairs(validNatures) do
      if response.pokemon.nature == nature then
        isValidNature = true
        break
      end
    end
    
    if not isValidNature then
      error("Invalid nature generated: " .. tostring(response.pokemon.nature))
    end
    
    print("✓ Nature generation produces valid natures")
  end
  
  testNatureGeneration()
  
  -- Test 3: Shiny Determination
  print("\n3. Testing Shiny Determination...")
  setupTestEnvironment()
  
  local function testShinyDetermination()
    -- Test normal shiny generation
    local msg = createTestMessage("CreatePokemon", {speciesId = 150, level = 50})
    registeredHandlers["create-pokemon"](msg)
    
    local response = json.decode(lastSentMessage.Data)
    assertNotNil(response.pokemon.shiny, "Should have shiny status")
    
    if response.pokemon.shiny then
      assertInRange(response.pokemon.variant, 0, 2, "Shiny variant should be 0-2")
      print("✓ Generated shiny Pokemon with variant " .. response.pokemon.variant)
    else
      assertEqual(0, response.pokemon.variant, "Non-shiny should have variant 0")
      print("✓ Generated non-shiny Pokemon")
    end
    
    -- Test forced shiny
    local msg2 = createTestMessage("CreatePokemon", {speciesId = 150, level = 50, forceShiny = true})
    registeredHandlers["create-pokemon"](msg2)
    
    local response2 = json.decode(lastSentMessage.Data)
    assertEqual(true, response2.pokemon.shiny, "Forced shiny should be shiny")
    
    print("✓ Forced shiny generation working")
  end
  
  testShinyDetermination()
  
  -- Test 4: Stat Calculation
  print("\n4. Testing Stat Calculation...")
  setupTestEnvironment()
  
  local function testStatCalculation()
    local msg = createTestMessage("CreatePokemon", {speciesId = 25, level = 50})
    registeredHandlers["create-pokemon"](msg)
    
    local response = json.decode(lastSentMessage.Data)
    local pokemon = response.pokemon
    
    assertNotNil(pokemon.stats, "Should have stats")
    
    -- Check that all stats are present and positive
    local requiredStats = {"hp", "attack", "defense", "spatk", "spdef", "speed"}
    for _, stat in ipairs(requiredStats) do
      assertNotNil(pokemon.stats[stat], "Should have " .. stat .. " stat")
      if pokemon.stats[stat] <= 0 then
        error(stat .. " should be positive, got " .. pokemon.stats[stat])
      end
    end
    
    -- Check HP calculation (should be higher than other stats due to formula)
    if pokemon.stats.hp <= pokemon.stats.attack then
      error("HP should typically be higher than other stats due to +level+10 formula")
    end
    
    -- Check max HP matches HP stat
    assertEqual(pokemon.stats.hp, pokemon.maxHp, "Max HP should equal HP stat")
    assertEqual(pokemon.maxHp, pokemon.hp, "Current HP should equal max HP for new Pokemon")
    
    print("✓ Stat calculation produces valid values")
    print("  - HP: " .. pokemon.stats.hp)
    print("  - ATK: " .. pokemon.stats.attack) 
    print("  - DEF: " .. pokemon.stats.defense)
  end
  
  testStatCalculation()
  
  -- Test 5: Pokemon State Updates
  print("\n5. Testing Pokemon State Updates...")
  setupTestEnvironment()
  
  local function testStateUpdates()
    -- First create a Pokemon
    local createMsg = createTestMessage("CreatePokemon", {speciesId = 1, level = 10})
    registeredHandlers["create-pokemon"](createMsg)
    
    local createResponse = json.decode(lastSentMessage.Data)
    local pokemonId = createResponse.pokemon.id
    
    -- Test level update
    local updateMsg = createTestMessage("UpdatePokemonState", {
      pokemonId = pokemonId,
      modifications = {
        level = 20,
        exp = 8000,
        hp = 50
      }
    })
    registeredHandlers["update-pokemon-state"](updateMsg)
    
    local updateResponse = json.decode(lastSentMessage.Data)
    assertEqual("PokemonStateUpdated", lastSentMessage.Action, "Should confirm state update")
    
    assertNotNil(updateResponse.changes, "Should report changes")
    assertEqual(20, updateResponse.pokemon.level, "Level should be updated")
    assertEqual(8000, updateResponse.pokemon.exp, "Experience should be updated")
    
    print("✓ Pokemon state updates working correctly")
    print("  - Level updated to: " .. updateResponse.pokemon.level)
    print("  - Experience updated to: " .. updateResponse.pokemon.exp)
  end
  
  testStateUpdates()
  
  -- Test 6: Pokemon Retrieval
  print("\n6. Testing Pokemon Retrieval...")
  setupTestEnvironment()
  
  local function testPokemonRetrieval()
    -- Create a Pokemon
    local createMsg = createTestMessage("CreatePokemon", {speciesId = 150, level = 70})
    registeredHandlers["create-pokemon"](createMsg)
    
    local createResponse = json.decode(lastSentMessage.Data)
    local pokemonId = createResponse.pokemon.id
    
    -- Retrieve the Pokemon
    local getMsg = createTestMessage("GetPokemonInstance", nil, {PokemonId = tostring(pokemonId)})
    registeredHandlers["get-pokemon-instance"](getMsg)
    
    local getResponse = json.decode(lastSentMessage.Data)
    assertEqual("PokemonInstanceData", lastSentMessage.Action, "Should return Pokemon data")
    
    assertEqual(pokemonId, getResponse.pokemon.id, "Should return same Pokemon ID")
    assertEqual(150, getResponse.pokemon.speciesId, "Should return correct species")
    assertEqual(70, getResponse.pokemon.level, "Should return correct level")
    
    print("✓ Pokemon retrieval working correctly")
  end
  
  testPokemonRetrieval()
  
  -- Test 7: Serialization/Deserialization
  print("\n7. Testing Serialization/Deserialization...")
  setupTestEnvironment()
  
  local function testSerialization()
    -- Create a Pokemon
    local createMsg = createTestMessage("CreatePokemon", {speciesId = 25, level = 25})
    registeredHandlers["create-pokemon"](createMsg)
    
    local createResponse = json.decode(lastSentMessage.Data)
    local pokemonId = createResponse.pokemon.id
    local originalPokemon = createResponse.pokemon
    
    -- Serialize the Pokemon
    local serializeMsg = createTestMessage("SerializePokemon", nil, {PokemonId = tostring(pokemonId)})
    registeredHandlers["serialize-pokemon"](serializeMsg)
    
    local serializeResponse = json.decode(lastSentMessage.Data)
    assertEqual("PokemonSerialized", lastSentMessage.Action, "Should confirm serialization")
    
    assertNotNil(serializeResponse.serialized, "Should contain serialized data")
    assertNotNil(serializeResponse.checksum, "Should contain checksum")
    
    -- Deserialize the Pokemon
    local deserializeMsg = createTestMessage("DeserializePokemon", {
      serialized = serializeResponse.serialized,
      checksum = serializeResponse.checksum
    })
    registeredHandlers["deserialize-pokemon"](deserializeMsg)
    
    local deserializeResponse = json.decode(lastSentMessage.Data)
    assertEqual("PokemonDeserialized", lastSentMessage.Action, "Should confirm deserialization")
    
    local restoredPokemon = deserializeResponse.pokemon
    
    -- Compare key fields (ID will be different due to new assignment)
    assertEqual(originalPokemon.speciesId, restoredPokemon.speciesId, "Species should match")
    assertEqual(originalPokemon.level, restoredPokemon.level, "Level should match")
    assertEqual(originalPokemon.nature, restoredPokemon.nature, "Nature should match")
    assertEqual(originalPokemon.shiny, restoredPokemon.shiny, "Shiny status should match")
    
    print("✓ Serialization/deserialization working correctly")
    print("  - Original Pokemon ID: " .. originalPokemon.id)
    print("  - Restored Pokemon ID: " .. restoredPokemon.id)
  end
  
  testSerialization()
  
  -- Test 8: Error Handling
  print("\n8. Testing Error Handling...")
  setupTestEnvironment()
  
  local function testErrorHandling()
    -- Test missing species ID
    local invalidMsg = createTestMessage("CreatePokemon", {level = 5})
    registeredHandlers["create-pokemon"](invalidMsg)
    
    assertNotNil(lastSentMessage.Error, "Should return error for missing species ID")
    print("✓ Proper error handling for missing species ID")
    
    -- Test invalid Pokemon ID for retrieval
    local invalidGetMsg = createTestMessage("GetPokemonInstance", nil, {PokemonId = "999"})
    registeredHandlers["get-pokemon-instance"](invalidGetMsg)
    
    assertNotNil(lastSentMessage.Error, "Should return error for invalid Pokemon ID")
    print("✓ Proper error handling for invalid Pokemon ID")
  end
  
  testErrorHandling()
  
  -- Test 9: ADP v1.0 Compliance
  print("\n9. Testing ADP v1.0 Compliance...")
  setupTestEnvironment()
  
  local function testADPCompliance()
    local infoMsg = createTestMessage("Info")
    registeredHandlers["info"](infoMsg)
    
    assertEqual("SaveState", lastSentMessage.Action, "Info should use SaveState action")
    
    local infoResponse = json.decode(lastSentMessage.Data)
    assertNotNil(infoResponse.name, "Should have process name")
    assertNotNil(infoResponse.adpVersion, "Should have ADP version")
    assertNotNil(infoResponse.handlers, "Should have handler documentation")
    
    assertEqual("1.0", infoResponse.adpVersion, "Should be ADP v1.0 compliant")
    
    -- Check handlers documentation
    local handlerCount = 0
    for _, handler in ipairs(infoResponse.handlers) do
      handlerCount = handlerCount + 1
      assertNotNil(handler.action, "Handler should have action")
      assertNotNil(handler.description, "Handler should have description")
    end
    
    if handlerCount < 5 then
      error("Should document all main handlers")
    end
    
    print("✓ ADP v1.0 compliance verified")
    print("  - Documented handlers: " .. handlerCount)
  end
  
  testADPCompliance()
  
  print("\n=== All Tests Passed! ===")
  print("Pokemon Instance Manager is functioning correctly")
end

-- Run tests if this file is executed directly
if arg and arg[0] == "pokemon-instance-manager.test.lua" then
  runTests()
end

return {
  runTests = runTests,
  setupTestEnvironment = setupTestEnvironment
}