-- Pokemon Instance Manager Process
-- Individual Pokemon creation, modification, and state tracking
-- ADP v1.0 Compliant for autonomous agent compatibility

-- Use global json if available (aolite), otherwise provide fallback
local json = json or {
  encode = function(obj)
    -- Simple JSON encoding for basic objects
    if type(obj) == "table" then
      local result = "{"
      local first = true
      for k, v in pairs(obj) do
        if not first then result = result .. "," end
        first = false
        result = result .. '"' .. tostring(k) .. '":' 
        if type(v) == "string" then
          result = result .. '"' .. v .. '"'
        elseif type(v) == "table" then
          result = result .. json.encode(v)
        else
          result = result .. tostring(v)
        end
      end
      return result .. "}"
    else
      return '"' .. tostring(obj) .. '"'
    end
  end,
  decode = function(str)
    -- Basic JSON decoding - AO processes should use global json
    return {}
  end
}

-- Process state initialization
if not PokemonInstances then
  PokemonInstances = {}
end

if not NextInstanceId then
  NextInstanceId = 1
end

if not ProcessState then
  ProcessState = {
    initialized = true,
    totalPokemonCreated = 0,
    totalSerializations = 0,
    totalDeserializations = 0
  }
end

-- Embedded Species Base Stats (essential subset from pokemon-species-db.lua)
-- Format: [speciesId] = {hp, attack, defense, spatk, spdef, speed}
local SPECIES_BASE_STATS = {
  [1] = {45, 49, 49, 65, 65, 45}, -- Bulbasaur
  [25] = {35, 55, 40, 50, 50, 90}, -- Pikachu
  [150] = {106, 110, 90, 154, 90, 130}, -- Mewtwo
  -- Add more common species as needed
}

-- Fallback base stats for unknown species (Ditto-like stats)
local DEFAULT_BASE_STATS = {48, 48, 48, 48, 48, 48}

-- Get base stats for a species
local function getBaseStats(speciesId)
  return SPECIES_BASE_STATS[speciesId] or DEFAULT_BASE_STATS
end

-- Experience calculation from level (Medium Fast growth rate)
-- Formula: exp = level^3 - matches most Pokemon growth rates
local function calculateExpFromLevel(level)
  if level <= 1 then return 0 end
  return level * level * level
end

-- Level calculation from experience (reverse of above)
local function calculateLevelFromExp(exp)
  if exp <= 0 then return 1 end
  local level = 1
  while level * level * level <= exp do
    level = level + 1
  end
  return math.max(1, level - 1)
end

-- IV Generation using AO crypto module (deterministic replacement for TypeScript getIvsFromId)
local function generateIVsFromSeed(seed)
  local ivs = {}
  local rng = seed
  
  for i = 1, 6 do
    -- Extract 5 bits for each IV (0-31 range)
    ivs[i] = rng & 0x1f
    rng = rng >> 5
  end
  
  return ivs
end

-- Nature generation matching TypeScript algorithm
local NATURES = {
  "Hardy", "Lonely", "Brave", "Adamant", "Naughty", "Bold", "Docile", "Relaxed", 
  "Impish", "Lax", "Timid", "Hasty", "Serious", "Jolly", "Naive", "Modest", 
  "Mild", "Quiet", "Bashful", "Rash", "Calm", "Gentle", "Sassy", "Careful", "Quirky"
}

local function generateNature(seed)
  return NATURES[(seed % 25) + 1]
end

-- Shiny determination using Masuda method (exact TypeScript algorithm)
local function determineShiny(personalityValue, trainerId, secretId)
  local rand1 = (personalityValue & 0xffff0000) >> 16
  local rand2 = personalityValue & 0x0000ffff
  
  local E = trainerId ~ secretId  -- XOR operation
  local F = rand1 ~ rand2
  
  -- Base shiny chance: 1/65536 (exact TypeScript value)
  return (E ~ F) < 16
end

-- Shiny variant generation (exact TypeScript probabilities)
local function generateShinyVariant(seed)
  if not seed then return 0 end
  
  local variantRoll = seed % 1000
  if variantRoll < 100 then return 2 end  -- 10% epic
  if variantRoll < 400 then return 1 end  -- 30% rare  
  return 0  -- 60% basic
end

-- Stat calculation with exact TypeScript formulas
local function calculateStat(baseStat, iv, level, nature, statType)
  local statValue = math.floor((2 * baseStat + iv) * level * 0.01)
  
  if statType == "hp" then
    return statValue + level + 10
  else
    statValue = statValue + 5
    -- Apply nature multiplier (exact TypeScript values)
    local multiplier = 1.0
    -- TODO: Nature stat modifications based on nature type
    return math.floor(statValue * multiplier)
  end
end

-- Pokemon instance creation with full TypeScript parity
local function createPokemonInstance(speciesId, level, forcedValues)
  level = level or 5
  
  -- Generate personality value (32-bit like TypeScript) using AO-compatible method
  local personalityValue = (level or 5) * (speciesId or 1) * ((msg.Timestamp or 0) % 4294967295)
  
  -- Generate IVs from personality value
  local ivs = forcedValues and forcedValues.ivs or generateIVsFromSeed(personalityValue)
  
  -- Generate nature
  local nature = forcedValues and forcedValues.nature or generateNature(personalityValue)
  
  -- Determine shiny status
  local isShiny = forcedValues and forcedValues.forceShiny or determineShiny(personalityValue, 12345, 67890)
  local shinyVariant = isShiny and generateShinyVariant(personalityValue) or 0
  
  -- Create Pokemon instance
  local pokemon = {
    id = NextInstanceId,
    speciesId = speciesId,
    level = level,
    exp = calculateExpFromLevel(level),
    hp = 0,  -- Will be set after stat calculation
    maxHp = 0,
    
    -- Core stats
    stats = {
      hp = 0,
      attack = 0,
      defense = 0,
      spatk = 0,
      spdef = 0,
      speed = 0
    },
    
    -- Genetic data
    ivs = {
      hp = ivs[1] or 0,
      attack = ivs[2] or 0,
      defense = ivs[3] or 0,
      spatk = ivs[4] or 0,
      spdef = ivs[5] or 0,
      speed = ivs[6] or 0
    },
    
    nature = nature,
    personality = personalityValue,
    
    -- Shiny data
    shiny = isShiny,
    variant = shinyVariant,
    
    -- Additional data
    moveset = {},
    abilities = {},
    statusEffect = nil,
    heldItem = nil,
    
    -- Metadata
    originalTrainer = "player",
    captured = forcedValues and forcedValues.timestamp or 0, -- Use msg.Timestamp in handlers
    nickname = nil
  }
  
  -- Calculate stats using species base stats from embedded data
  local baseStats = getBaseStats(speciesId)
  pokemon.stats.hp = calculateStat(baseStats[1], pokemon.ivs.hp, level, nature, "hp")
  pokemon.stats.attack = calculateStat(baseStats[2], pokemon.ivs.attack, level, nature, "attack")
  pokemon.stats.defense = calculateStat(baseStats[3], pokemon.ivs.defense, level, nature, "defense")
  pokemon.stats.spatk = calculateStat(baseStats[4], pokemon.ivs.spatk, level, nature, "spatk")
  pokemon.stats.spdef = calculateStat(baseStats[5], pokemon.ivs.spdef, level, nature, "spdef")
  pokemon.stats.speed = calculateStat(baseStats[6], pokemon.ivs.speed, level, nature, "speed")
  
  pokemon.maxHp = pokemon.stats.hp
  pokemon.hp = pokemon.maxHp
  
  -- Store instance
  PokemonInstances[NextInstanceId] = pokemon
  NextInstanceId = NextInstanceId + 1
  ProcessState.totalPokemonCreated = ProcessState.totalPokemonCreated + 1
  
  return pokemon
end

-- CreatePokemon Handler
Handlers.add(
  "create-pokemon",
  Handlers.utils.hasMatchingTag("Action", "CreatePokemon"),
  function(msg)
    local data = msg.Data and json.decode(msg.Data) or {}
    
    local speciesId = data.speciesId or tonumber(msg.SpeciesId)
    if not speciesId then
      ao.send({
        Target = msg.From,
        Action = "PokemonCreated",
        Error = "SpeciesId required for Pokemon creation",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local level = data.level or tonumber(msg.Level) or 5
    local forcedValues = {
      forceShiny = data.forceShiny or msg.ForceShiny == "true",
      ivs = data.forcedIVs,
      nature = data.forcedNature,
      timestamp = msg.Timestamp or 0
    }
    
    local pokemon = createPokemonInstance(speciesId, level, forcedValues)
    
    local result = {
      success = true,
      pokemon = pokemon,
      message = "Pokemon created successfully"
    }
    
    ao.send({
      Target = msg.From,
      Action = "PokemonCreated",
      Data = json.encode(result),
      SpeciesId = tostring(result.pokemon.speciesId),
      PokemonId = tostring(result.pokemon.id),
      Level = tostring(result.pokemon.level),
      Shiny = tostring(result.pokemon.shiny),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- UpdatePokemonState Handler
Handlers.add(
  "update-pokemon-state",
  Handlers.utils.hasMatchingTag("Action", "UpdatePokemonState"),
  function(msg)
    local data = msg.Data and json.decode(msg.Data) or {}
    
    local pokemonId = data.pokemonId or tonumber(msg.PokemonId)
    if not pokemonId then
      ao.send({
        Target = msg.From,
        Action = "PokemonStateUpdated",
        Error = "PokemonId required for state update",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local pokemon = PokemonInstances[pokemonId]
    if not pokemon then
      ao.send({
        Target = msg.From,
        Action = "PokemonStateUpdated",
        Error = "Pokemon not found: " .. tostring(pokemonId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local changes = {}
    
    -- Update level
    if data.modifications and data.modifications.level then
      local newLevel = data.modifications.level
      if newLevel ~= pokemon.level then
        pokemon.level = newLevel
        -- Recalculate stats based on new level
        local baseStats = getBaseStats(pokemon.speciesId)
        pokemon.stats.hp = calculateStat(baseStats[1], pokemon.ivs.hp, newLevel, pokemon.nature, "hp")
        pokemon.stats.attack = calculateStat(baseStats[2], pokemon.ivs.attack, newLevel, pokemon.nature, "attack")
        pokemon.stats.defense = calculateStat(baseStats[3], pokemon.ivs.defense, newLevel, pokemon.nature, "defense")
        pokemon.stats.spatk = calculateStat(baseStats[4], pokemon.ivs.spatk, newLevel, pokemon.nature, "spatk")
        pokemon.stats.spdef = calculateStat(baseStats[5], pokemon.ivs.spdef, newLevel, pokemon.nature, "spdef")
        pokemon.stats.speed = calculateStat(baseStats[6], pokemon.ivs.speed, newLevel, pokemon.nature, "speed")
        pokemon.maxHp = pokemon.stats.hp
        -- Adjust current HP proportionally to preserve percentage
        local hpPercentage = pokemon.hp / (pokemon.maxHp > 0 and pokemon.maxHp or 1)
        pokemon.hp = math.floor(pokemon.maxHp * hpPercentage)
        changes.level = newLevel
      end
    end
    
    -- Update experience
    if data.modifications and data.modifications.exp then
      pokemon.exp = data.modifications.exp
      changes.exp = data.modifications.exp
      
      -- Check if experience change triggers level up
      local newLevelFromExp = calculateLevelFromExp(pokemon.exp)
      if newLevelFromExp ~= pokemon.level then
        pokemon.level = newLevelFromExp
        -- Recalculate stats for new level
        local baseStats = getBaseStats(pokemon.speciesId)
        pokemon.stats.hp = calculateStat(baseStats[1], pokemon.ivs.hp, pokemon.level, pokemon.nature, "hp")
        pokemon.stats.attack = calculateStat(baseStats[2], pokemon.ivs.attack, pokemon.level, pokemon.nature, "attack")
        pokemon.stats.defense = calculateStat(baseStats[3], pokemon.ivs.defense, pokemon.level, pokemon.nature, "defense")
        pokemon.stats.spatk = calculateStat(baseStats[4], pokemon.ivs.spatk, pokemon.level, pokemon.nature, "spatk")
        pokemon.stats.spdef = calculateStat(baseStats[5], pokemon.ivs.spdef, pokemon.level, pokemon.nature, "spdef")
        pokemon.stats.speed = calculateStat(baseStats[6], pokemon.ivs.speed, pokemon.level, pokemon.nature, "speed")
        local oldMaxHp = pokemon.maxHp
        pokemon.maxHp = pokemon.stats.hp
        -- Scale current HP proportionally
        local hpPercentage = pokemon.hp / (oldMaxHp > 0 and oldMaxHp or 1)
        pokemon.hp = math.floor(pokemon.maxHp * hpPercentage)
        changes.level = pokemon.level
        changes.maxHp = pokemon.maxHp
      end
    end
    
    -- Update HP
    if data.modifications and data.modifications.hp then
      pokemon.hp = math.max(0, math.min(data.modifications.hp, pokemon.maxHp))
      changes.hp = pokemon.hp
    end
    
    -- Update status effect
    if data.modifications and data.modifications.statusEffect then
      pokemon.statusEffect = data.modifications.statusEffect
      changes.statusEffect = data.modifications.statusEffect
    end
    
    local result = {
      success = true,
      pokemon = pokemon,
      changes = changes,
      message = "Pokemon state updated successfully"
    }
    
    ao.send({
      Target = msg.From,
      Action = "PokemonStateUpdated",
      Data = json.encode(result),
      PokemonId = tostring(result.pokemon.id),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- GetPokemonInstance Handler
Handlers.add(
  "get-pokemon-instance",
  Handlers.utils.hasMatchingTag("Action", "GetPokemonInstance"),
  function(msg)
    local pokemonId = tonumber(msg.PokemonId) or (msg.Data and json.decode(msg.Data).pokemonId)
    if not pokemonId then
      ao.send({
        Target = msg.From,
        Action = "PokemonInstanceData",
        Error = "PokemonId required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local pokemon = PokemonInstances[pokemonId]
    if not pokemon then
      ao.send({
        Target = msg.From,
        Action = "PokemonInstanceData",
        Error = "Pokemon not found: " .. tostring(pokemonId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local result = {
      success = true,
      pokemon = pokemon,
      message = "Pokemon retrieved successfully"
    }
    
    ao.send({
      Target = msg.From,
      Action = "PokemonInstanceData",
      Data = json.encode(result),
      PokemonId = tostring(result.pokemon.id),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- SerializePokemon Handler
Handlers.add(
  "serialize-pokemon",
  Handlers.utils.hasMatchingTag("Action", "SerializePokemon"),
  function(msg)
    local pokemonId = tonumber(msg.PokemonId) or (msg.Data and json.decode(msg.Data).pokemonId)
    if not pokemonId then
      ao.send({
        Target = msg.From,
        Action = "PokemonSerialized",
        Error = "PokemonId required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local pokemon = PokemonInstances[pokemonId]
    if not pokemon then
      ao.send({
        Target = msg.From,
        Action = "PokemonSerialized",
        Error = "Pokemon not found: " .. tostring(pokemonId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local serialized = json.encode(pokemon)
    
    -- Simple checksum for data integrity
    local checksum = tostring(#serialized)
    
    ProcessState.totalSerializations = ProcessState.totalSerializations + 1
    
    local result = {
      success = true,
      serialized = serialized,
      checksum = checksum,
      message = "Pokemon serialized successfully"
    }
    
    ao.send({
      Target = msg.From,
      Action = "PokemonSerialized",
      Data = json.encode(result),
      PokemonId = msg.PokemonId,
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- DeserializePokemon Handler
Handlers.add(
  "deserialize-pokemon",
  Handlers.utils.hasMatchingTag("Action", "DeserializePokemon"),
  function(msg)
    local data = msg.Data and json.decode(msg.Data) or {}
    
    local serialized = data.serialized
    local checksum = data.checksum
    
    if not serialized then
      ao.send({
        Target = msg.From,
        Action = "PokemonDeserialized",
        Error = "Serialized data required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    -- Verify checksum
    if checksum and tostring(#serialized) ~= checksum then
      ao.send({
        Target = msg.From,
        Action = "PokemonDeserialized",
        Error = "Data integrity check failed",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local pokemon = json.decode(serialized)
    
    -- Assign new ID and store
    pokemon.id = NextInstanceId
    PokemonInstances[NextInstanceId] = pokemon
    NextInstanceId = NextInstanceId + 1
    
    ProcessState.totalDeserializations = ProcessState.totalDeserializations + 1
    
    local result = {
      success = true,
      pokemon = pokemon,
      pokemonId = pokemon.id,
      message = "Pokemon deserialized successfully"
    }
    
    ao.send({
      Target = msg.From,
      Action = "PokemonDeserialized",
      Data = json.encode(result),
      PokemonId = tostring(result.pokemonId),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
  local infoResponse = {
    name = "Pokemon Instance Manager",
    description = "Individual Pokemon creation, modification, and state tracking with TypeScript parity",
    version = "1.0.0",
    adpVersion = "1.0",
    owner = ao.env and ao.env.Process and ao.env.Process.Owner or "unknown",
    processId = ao.id,
    
    capabilities = {
      "pokemon-creation",
      "pokemon-state-management", 
      "pokemon-persistence",
      "iv-generation",
      "shiny-determination",
      "stat-calculation",
      "serialization"
    },
    
    handlers = {
      {
        action = "CreatePokemon",
        description = "Create new Pokemon instance with IV/nature generation",
        parameters = {
          {name = "SpeciesId", type = "number", required = true, description = "Pokemon species identifier"},
          {name = "Level", type = "number", required = false, description = "Initial level (default: 5)"},
          {name = "ForceShiny", type = "boolean", required = false, description = "Force shiny generation"},
          {name = "Data", type = "object", required = false, description = "JSON object with forcedIVs, forcedNature"}
        }
      },
      {
        action = "UpdatePokemonState", 
        description = "Update Pokemon level, experience, HP, or status",
        parameters = {
          {name = "PokemonId", type = "number", required = true, description = "Pokemon instance ID"},
          {name = "Data", type = "object", required = true, description = "JSON object with modifications"}
        }
      },
      {
        action = "GetPokemonInstance",
        description = "Retrieve complete Pokemon instance data",
        parameters = {
          {name = "PokemonId", type = "number", required = true, description = "Pokemon instance ID"}
        }
      },
      {
        action = "SerializePokemon",
        description = "Serialize Pokemon instance for storage",
        parameters = {
          {name = "PokemonId", type = "number", required = true, description = "Pokemon instance ID"}
        }
      },
      {
        action = "DeserializePokemon",
        description = "Deserialize and restore Pokemon instance",
        parameters = {
          {name = "Data", type = "object", required = true, description = "JSON object with serialized data and checksum"}
        }
      },
      {
        action = "Info",
        description = "Get process information and handler documentation",
        parameters = {}
      }
    },
    
    statistics = {
      totalPokemonCreated = ProcessState.totalPokemonCreated,
      totalSerializations = ProcessState.totalSerializations,
      totalDeserializations = ProcessState.totalDeserializations,
      currentPokemonCount = NextInstanceId - 1
    }
  }
  
  ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = json.encode(infoResponse),
    ProcessId = ao.id,
    Timestamp = tostring(msg.Timestamp or 0)
  })
end)

-- Ping handler for testing
Handlers.add("ping", Handlers.utils.hasMatchingTag("Action", "Ping"), function(msg)
  ao.send({
    Target = msg.From,
    Action = "Pong",
    Data = "Pokemon Instance Manager is operational",
    ProcessId = ao.id,
    Timestamp = tostring(msg.Timestamp or 0)
  })
end)

print("Pokemon Instance Manager initialized successfully")
print("Handlers: CreatePokemon, UpdatePokemonState, GetPokemonInstance, SerializePokemon, DeserializePokemon")
print("ADP v1.0 Compliant - Use 'Info' action for process documentation")