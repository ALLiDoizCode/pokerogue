#!/usr/bin/env lua

--[[
Property-Based Testing Framework for AO Lua Processes
Provides comprehensive input generation and property validation:
- Custom Lua generators for Pokemon data, stats, and battle scenarios
- Property test execution with configurable iterations
- Shrinking for minimal failing cases
- Statistical analysis of test results
- Integration with existing aolite framework
]]

local PropertyBasedTesting = {}

-- Generator registry
local Generators = {}

-- Test execution configuration
local PropertyConfig = {
  defaultIterations = 100,
  shrinkingAttempts = 50,
  maxGenerationAttempts = 1000,
  randomSeed = 42
}

-- Statistical tracking
local PropertyStats = {
  totalProperties = 0,
  passedProperties = 0,
  failedProperties = 0,
  generationStats = {},
  shrinkingStats = {}
}

-- Initialize deterministic random for property testing
local function initializeRandom(seed)
  seed = seed or PropertyConfig.randomSeed
  math.randomseed(seed)
  print(string.format("🎲 Initialized property testing with seed: %d", seed))
end

-- Basic generator functions
function Generators.integer(min, max)
  min = min or 0
  max = max or 100
  return function()
    return math.random(min, max)
  end
end

function Generators.float(min, max, precision)
  min = min or 0.0
  max = max or 1.0
  precision = precision or 2
  return function()
    local value = min + (max - min) * math.random()
    return math.floor(value * (10 ^ precision)) / (10 ^ precision)
  end
end

function Generators.boolean()
  return function()
    return math.random() > 0.5
  end
end

function Generators.string(length, charset)
  length = length or 10
  charset = charset or "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  return function()
    local result = ""
    for i = 1, math.random(1, length) do
      local charIndex = math.random(1, #charset)
      result = result .. charset:sub(charIndex, charIndex)
    end
    return result
  end
end

function Generators.choice(options)
  return function()
    return options[math.random(1, #options)]
  end
end

function Generators.list(elementGenerator, minLength, maxLength)
  minLength = minLength or 0
  maxLength = maxLength or 10
  return function()
    local length = math.random(minLength, maxLength)
    local result = {}
    for i = 1, length do
      result[i] = elementGenerator()
    end
    return result
  end
end

function Generators.table(keyGenerator, valueGenerator, minPairs, maxPairs)
  minPairs = minPairs or 1
  maxPairs = maxPairs or 5
  return function()
    local pairCount = math.random(minPairs, maxPairs)
    local result = {}
    for i = 1, pairCount do
      local key = keyGenerator()
      local value = valueGenerator()
      result[key] = value
    end
    return result
  end
end

-- Pokemon-specific generators
function Generators.pokemonSpeciesId()
  return Generators.integer(1, 1010) -- Gen 9 Pokemon count
end

function Generators.pokemonLevel()
  return Generators.integer(1, 100)
end

function Generators.pokemonStats()
  return function()
    return {
      hp = math.random(1, 255),
      attack = math.random(1, 255),
      defense = math.random(1, 255),
      spAttack = math.random(1, 255),
      spDefense = math.random(1, 255),
      speed = math.random(1, 255)
    }
  end
end

function Generators.pokemonIVs()
  return function()
    return {
      hp = math.random(0, 31),
      attack = math.random(0, 31),
      defense = math.random(0, 31),
      spAttack = math.random(0, 31),
      spDefense = math.random(0, 31),
      speed = math.random(0, 31)
    }
  end
end

function Generators.pokemonEVs()
  return function()
    local totalEVs = 0
    local evs = {}
    local stats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
    
    for _, stat in ipairs(stats) do
      local maxForStat = math.min(252, 510 - totalEVs)
      if maxForStat > 0 then
        evs[stat] = math.random(0, maxForStat)
        totalEVs = totalEVs + evs[stat]
      else
        evs[stat] = 0
      end
    end
    
    return evs
  end
end

function Generators.pokemonNature()
  local natures = {
    "Hardy", "Lonely", "Brave", "Adamant", "Naughty",
    "Bold", "Docile", "Relaxed", "Impish", "Lax",
    "Timid", "Hasty", "Serious", "Jolly", "Naive",
    "Modest", "Mild", "Quiet", "Bashful", "Rash",
    "Calm", "Gentle", "Sassy", "Careful", "Quirky"
  }
  return Generators.choice(natures)
end

function Generators.pokemonType()
  local types = {
    "Normal", "Fire", "Water", "Electric", "Grass", "Ice",
    "Fighting", "Poison", "Ground", "Flying", "Psychic", "Bug",
    "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy"
  }
  return Generators.choice(types)
end

function Generators.pokemonData()
  return function()
    return {
      speciesId = Generators.pokemonSpeciesId()(),
      level = Generators.pokemonLevel()(),
      baseStats = Generators.pokemonStats()(),
      ivs = Generators.pokemonIVs()(),
      evs = Generators.pokemonEVs()(),
      nature = Generators.pokemonNature()(),
      types = {
        Generators.pokemonType()(),
        math.random() > 0.5 and Generators.pokemonType()() or nil
      }
    }
  end
end

-- Battle-specific generators
function Generators.battleConditions()
  local weather = {"none", "rain", "sun", "sandstorm", "hail", "snow"}
  local terrain = {"none", "electric", "grassy", "misty", "psychic"}
  
  return function()
    return {
      weather = Generators.choice(weather)(),
      terrain = Generators.choice(terrain)(),
      fieldEffects = Generators.list(Generators.string(8), 0, 3)()
    }
  end
end

function Generators.moveData()
  local categories = {"physical", "special", "status"}
  
  return function()
    return {
      id = math.random(1, 900),
      type = Generators.pokemonType()(),
      power = math.random(0, 250),
      accuracy = math.random(0, 100),
      category = Generators.choice(categories)(),
      pp = math.random(1, 40),
      priority = math.random(-6, 6)
    }
  end
end

function Generators.battleScenario()
  return function()
    return {
      attacker = Generators.pokemonData()(),
      defender = Generators.pokemonData()(),
      move = Generators.moveData()(),
      conditions = Generators.battleConditions()(),
      rngSeed = math.random(1, 2147483647)
    }
  end
end

-- AO Message generators
function Generators.aoMessage()
  local actions = {
    "CalculateStats", "ProcessBattle", "EvolvePokemon", 
    "ValidateTeam", "SaveGameState", "LoadGameState"
  }
  
  return function()
    return {
      Id = string.format("msg-%d", math.random(10000, 99999)),
      From = string.format("process-%d", math.random(1000, 9999)),
      Target = string.format("process-%d", math.random(1000, 9999)),
      Action = Generators.choice(actions)(),
      Data = json.encode({
        payload = Generators.string(20)(),
        timestamp = os.time()
      }),
      Tags = {
        Action = Generators.choice(actions)(),
        Type = Generators.choice({"Request", "Response", "Notification"})()
      },
      Timestamp = tostring(os.time())
    }
  end
end

-- Property test execution
function PropertyBasedTesting.property(name, generator, predicate, config)
  config = config or {}
  local iterations = config.iterations or PropertyConfig.defaultIterations
  local shrinking = config.shrinking ~= false
  
  PropertyStats.totalProperties = PropertyStats.totalProperties + 1
  
  print(string.format("\n🔍 Testing property: %s (%d iterations)", name, iterations))
  
  local propertyStart = os.clock()
  local failures = {}
  local successes = 0
  
  for i = 1, iterations do
    local testData = generator()
    local success, result = pcall(predicate, testData)
    
    if success and result then
      successes = successes + 1
    else
      local failure = {
        iteration = i,
        input = testData,
        error = success and "Property failed" or result,
        success = success
      }
      
      -- Attempt shrinking for better failure case
      if shrinking and success then
        failure.shrunk = PropertyBasedTesting.shrink(generator, predicate, testData)
      end
      
      table.insert(failures, failure)
      
      -- Early termination on failure for faster feedback
      if not config.continueOnFailure then
        break
      end
    end
  end
  
  local propertyEnd = os.clock()
  local executionTime = propertyEnd - propertyStart
  
  local passed = #failures == 0
  if passed then
    PropertyStats.passedProperties = PropertyStats.passedProperties + 1
    print(string.format("  ✅ Property passed (%d/%d iterations, %.2fms)", 
      successes, iterations, executionTime * 1000))
  else
    PropertyStats.failedProperties = PropertyStats.failedProperties + 1
    print(string.format("  ❌ Property failed (%d/%d iterations, %.2fms)", 
      #failures, iterations, executionTime * 1000))
    
    -- Report first failure with details
    local firstFailure = failures[1]
    print(string.format("     First failure at iteration %d:", firstFailure.iteration))
    print(string.format("     Error: %s", firstFailure.error))
    if firstFailure.shrunk then
      print(string.format("     Shrunk input: %s", json.encode(firstFailure.shrunk)))
    end
  end
  
  PropertyStats.generationStats[name] = {
    iterations = iterations,
    successes = successes,
    failures = #failures,
    executionTime = executionTime
  }
  
  return {
    name = name,
    passed = passed,
    iterations = iterations,
    successes = successes,
    failures = failures,
    executionTime = executionTime
  }
end

-- Input shrinking for minimal failing cases
function PropertyBasedTesting.shrink(generator, predicate, failingInput)
  local shrinkAttempts = PropertyConfig.shrinkingAttempts
  local currentInput = failingInput
  
  for attempt = 1, shrinkAttempts do
    local shrunkInput = PropertyBasedTesting.shrinkValue(currentInput)
    
    if shrunkInput then
      local success, result = pcall(predicate, shrunkInput)
      if success and not result then
        -- Shrunk input still fails the property, use it
        currentInput = shrunkInput
      else
        -- Shrunk input passes or errors, stop shrinking
        break
      end
    else
      -- Cannot shrink further
      break
    end
  end
  
  return currentInput
end

-- Value shrinking strategies
function PropertyBasedTesting.shrinkValue(value)
  local valueType = type(value)
  
  if valueType == "number" then
    if value > 0 then
      return math.floor(value / 2)
    elseif value < 0 then
      return math.ceil(value / 2)
    else
      return nil -- Cannot shrink 0
    end
  elseif valueType == "string" then
    if #value > 1 then
      return value:sub(1, math.floor(#value / 2))
    else
      return nil -- Cannot shrink single character
    end
  elseif valueType == "table" then
    if #value > 0 then
      -- Shrink lists by removing elements
      local shrunk = {}
      for i = 1, math.floor(#value / 2) do
        shrunk[i] = value[i]
      end
      return shrunk
    else
      -- Shrink tables by removing key-value pairs
      local shrunk = {}
      local count = 0
      for k, v in pairs(value) do
        if count < math.floor(table.getn(value) / 2) then
          shrunk[k] = v
          count = count + 1
        end
      end
      return next(shrunk) and shrunk or nil
    end
  end
  
  return nil
end

-- Property test suite execution
function PropertyBasedTesting.runPropertySuite(suiteName, properties)
  print(string.format("\n🎯 Running property test suite: %s", suiteName))
  print(string.rep("-", 50))
  
  local suiteStart = os.clock()
  local suiteResults = {}
  
  for propertyName, propertyConfig in pairs(properties) do
    local result = PropertyBasedTesting.property(
      propertyName,
      propertyConfig.generator,
      propertyConfig.predicate,
      propertyConfig.config
    )
    suiteResults[propertyName] = result
  end
  
  local suiteEnd = os.clock()
  local suiteTime = suiteEnd - suiteStart
  
  -- Calculate suite statistics
  local totalProperties = 0
  local passedProperties = 0
  for _, result in pairs(suiteResults) do
    totalProperties = totalProperties + 1
    if result.passed then
      passedProperties = passedProperties + 1
    end
  end
  
  print(string.format("📊 Property suite results: %d/%d passed (%.2fms)", 
    passedProperties, totalProperties, suiteTime * 1000))
  
  return {
    suiteName = suiteName,
    results = suiteResults,
    totalProperties = totalProperties,
    passedProperties = passedProperties,
    executionTime = suiteTime
  }
end

-- Statistical analysis of property test results
function PropertyBasedTesting.generateStatistics()
  print(string.rep("=", 60))
  print("📈 Property-Based Testing Statistics")
  print(string.rep("=", 60))
  
  print(string.format("Total Properties: %d", PropertyStats.totalProperties))
  print(string.format("Passed: %d (%.1f%%)", 
    PropertyStats.passedProperties,
    (PropertyStats.passedProperties / math.max(PropertyStats.totalProperties, 1)) * 100))
  print(string.format("Failed: %d (%.1f%%)",
    PropertyStats.failedProperties,
    (PropertyStats.failedProperties / math.max(PropertyStats.totalProperties, 1)) * 100))
  
  if next(PropertyStats.generationStats) then
    print("\n⏱️  Property Performance:")
    for name, stats in pairs(PropertyStats.generationStats) do
      print(string.format("  %s: %.2fms (%d iterations, %.1f%% success)", 
        name, stats.executionTime * 1000, stats.iterations,
        (stats.successes / stats.iterations) * 100))
    end
  end
  
  return PropertyStats.passedProperties == PropertyStats.totalProperties
end

-- Initialize property testing framework
function PropertyBasedTesting.initialize(config)
  config = config or {}
  
  PropertyConfig.defaultIterations = config.iterations or PropertyConfig.defaultIterations
  PropertyConfig.shrinkingAttempts = config.shrinkingAttempts or PropertyConfig.shrinkingAttempts
  PropertyConfig.randomSeed = config.seed or PropertyConfig.randomSeed
  
  initializeRandom(PropertyConfig.randomSeed)
  
  -- Reset statistics
  PropertyStats.totalProperties = 0
  PropertyStats.passedProperties = 0
  PropertyStats.failedProperties = 0
  PropertyStats.generationStats = {}
  PropertyStats.shrinkingStats = {}
  
  print("🚀 Property-Based Testing Framework initialized")
end

-- Export generators and testing functions
PropertyBasedTesting.generators = Generators
PropertyBasedTesting.config = PropertyConfig
PropertyBasedTesting.stats = PropertyStats

return PropertyBasedTesting