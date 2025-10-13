-- Abilities and Nature Manager Process
-- Pokemon ability and nature management with exact TypeScript parity
-- ADP v1.0 Compliant for autonomous agent compatibility

-- Use global json if available (aolite), otherwise provide fallback
local json = json or {
  encode = function(obj)
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
    return {}  -- Basic implementation for AO
  end
}

-- Process state initialization
if not AbilityNatureState then
  AbilityNatureState = {
    initialized = true,
    totalNaturesApplied = 0,
    totalAbilitiesTriggered = 0,
    totalAbilitiesAssigned = 0
  }
end

-- ===== EMBEDDED NATURE DATA =====
-- Exact TypeScript parity from nature.ts with getNatureStatMultiplier
local NATURE_DATA = {
  -- Format: [natureId] = {name, increasedStat, decreasedStat}
  [0] = {"Hardy", nil, nil},      -- Neutral nature
  [1] = {"Lonely", "ATK", "DEF"},
  [2] = {"Brave", "ATK", "SPD"},
  [3] = {"Adamant", "ATK", "SPATK"},
  [4] = {"Naughty", "ATK", "SPDEF"},
  [5] = {"Bold", "DEF", "ATK"},
  [6] = {"Docile", nil, nil},     -- Neutral nature
  [7] = {"Relaxed", "DEF", "SPD"},
  [8] = {"Impish", "DEF", "SPATK"},
  [9] = {"Lax", "DEF", "SPDEF"},
  [10] = {"Timid", "SPD", "ATK"},
  [11] = {"Hasty", "SPD", "DEF"},
  [12] = {"Serious", nil, nil},   -- Neutral nature
  [13] = {"Jolly", "SPD", "SPATK"},
  [14] = {"Naive", "SPD", "SPDEF"},
  [15] = {"Modest", "SPATK", "ATK"},
  [16] = {"Mild", "SPATK", "DEF"},
  [17] = {"Quiet", "SPATK", "SPD"},
  [18] = {"Bashful", nil, nil},   -- Neutral nature
  [19] = {"Rash", "SPATK", "SPDEF"},
  [20] = {"Calm", "SPDEF", "ATK"},
  [21] = {"Gentle", "SPDEF", "DEF"},
  [22] = {"Sassy", "SPDEF", "SPD"},
  [23] = {"Careful", "SPDEF", "SPATK"},
  [24] = {"Quirky", nil, nil}     -- Neutral nature
}

-- Nature stat multiplier calculation (exact TypeScript parity)
local function getNatureStatMultiplier(natureId, stat)
  local natureData = NATURE_DATA[natureId]
  if not natureData then return 1.0 end
  
  local name, increasedStat, decreasedStat = natureData[1], natureData[2], natureData[3]
  
  if increasedStat == stat then
    return 1.1  -- Exactly 1.1 as in TypeScript
  elseif decreasedStat == stat then
    return 0.9  -- Exactly 0.9 as in TypeScript
  else
    return 1.0  -- Default multiplier
  end
end

-- ===== EMBEDDED ABILITY DATA =====
-- Key abilities from TypeScript ability.ts
local ABILITY_DATA = {
  [0] = {name = "None", description = "No ability"},
  [1] = {name = "Stench", description = "May cause foe to flinch", triggers = {"ON_CONTACT"}},
  [2] = {name = "Drizzle", description = "Summons rain", triggers = {"POST_SUMMON"}, weatherEffect = "RAIN"},
  [3] = {name = "Speed Boost", description = "Gradually boosts Speed", triggers = {"TURN_END"}},
  [4] = {name = "Battle Armor", description = "Blocks critical hits", effects = {"PREVENT_CRIT"}},
  [5] = {name = "Sturdy", description = "Cannot be knocked out with one hit", effects = {"PREVENT_OHKO"}},
  [7] = {name = "Limber", description = "Prevents paralysis", effects = {"PREVENT_PARALYSIS"}},
  [8] = {name = "Sand Veil", description = "Ups evasion in sandstorm", weatherBonus = "SAND"},
  [9] = {name = "Static", description = "May cause paralysis on contact", triggers = {"ON_CONTACT"}, statusInflict = "PARALYSIS"},
  [10] = {name = "Volt Absorb", description = "Absorbs Electric moves to restore HP", absorbs = {"ELECTRIC"}},
  [11] = {name = "Water Absorb", description = "Absorbs Water moves to restore HP", absorbs = {"WATER"}},
  [13] = {name = "Cloud Nine", description = "Eliminates weather effects", effects = {"WEATHER_IMMUNITY"}},
  [15] = {name = "Insomnia", description = "Prevents sleep", effects = {"PREVENT_SLEEP"}},
  [16] = {name = "Color Change", description = "Changes type to match attacking move", triggers = {"POST_DEFEND"}},
  [17] = {name = "Immunity", description = "Prevents poison", effects = {"PREVENT_POISON"}},
  [18] = {name = "Flash Fire", description = "Powers up Fire moves after being hit by Fire", absorbs = {"FIRE"}},
  [22] = {name = "Intimidate", description = "Lowers foe's Attack", triggers = {"POST_SUMMON"}, statChange = {target = "OPPONENT", stat = "ATK", amount = -1}},
  [39] = {name = "Inner Focus", description = "Prevents flinching", effects = {"PREVENT_FLINCH"}},
  [65] = {name = "Overgrow", description = "Powers up Grass moves in a pinch", triggers = {"LOW_HP"}, typeBonus = "GRASS"},
  [66] = {name = "Blaze", description = "Powers up Fire moves in a pinch", triggers = {"LOW_HP"}, typeBonus = "FIRE"},
  [67] = {name = "Torrent", description = "Powers up Water moves in a pinch", triggers = {"LOW_HP"}, typeBonus = "WATER"}
}

-- Get ability data by ID
local function getAbilityById(abilityId)
  return ABILITY_DATA[abilityId]
end

-- Get nature data by ID (without functions for JSON serialization)
local function getNatureById(natureId)
  local natureData = NATURE_DATA[natureId]
  if not natureData then return nil end
  
  return {
    natureId = natureId,
    name = natureData[1],
    increasedStat = natureData[2],
    decreasedStat = natureData[3]
    -- getMultiplier function removed to enable JSON serialization
  }
end

-- Random nature selection using deterministic seed
local function selectRandomNature(seed)
  local rng = seed or 12345
  return rng % 25  -- 25 total natures (0-24)
end

-- Battle state tracking
if not BattleStates then
  BattleStates = {}
end

-- Ability cooldowns and usage tracking
if not AbilityCooldowns then
  AbilityCooldowns = {}
end

-- Battle ability state management
local function initializeBattleAbilityState(battleId, pokemonId, abilityId)
  if not BattleStates[battleId] then
    BattleStates[battleId] = {}
  end
  
  local key = pokemonId .. "_" .. abilityId
  if not BattleStates[battleId][key] then
    BattleStates[battleId][key] = {
      pokemonId = pokemonId,
      abilityId = abilityId,
      activated = false,
      activationCount = 0,
      lastActivatedTurn = 0,
      persistentEffects = {},
      cooldownRemaining = 0
    }
  end
  
  return BattleStates[battleId][key]
end

-- ===== HANDLERS =====

-- ApplyNature Handler
Handlers.add("apply-nature",
  Handlers.utils.hasMatchingTag("Action", "ApplyNature"),
  function(msg)
    local pokemonId = tonumber(msg.PokemonId or msg.Id)
    local natureId = tonumber(msg.NatureId)
    local forceNature = msg.ForceNature
    local timestamp = tonumber(msg.Timestamp) or 0
    
    if not pokemonId then
      ao.send({
        Target = msg.From,
        Action = "NatureApplied",
        Data = json.encode({success = false, error = "PokemonId is required"}),
        Error = "PokemonId is required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    -- Generate or use provided nature
    local selectedNatureId = natureId
    if not selectedNatureId then
      if forceNature then
        -- Find nature by name
        for id, data in pairs(NATURE_DATA) do
          if data[1]:lower() == forceNature:lower() then
            selectedNatureId = id
            break
          end
        end
      else
        -- Random nature selection
        selectedNatureId = selectRandomNature(pokemonId + timestamp)
      end
    end
    
    local natureData = getNatureById(selectedNatureId)
    if not natureData then
      ao.send({
        Target = msg.From,
        Action = "NatureApplied",
        Data = json.encode({success = false, error = "Invalid nature ID: " .. tostring(selectedNatureId)}),
        Error = "Invalid nature ID: " .. tostring(selectedNatureId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    -- Calculate stat modifiers for all stats
    local statModifiers = {
      hp = 1.0,      -- HP is never modified by nature
      attack = getNatureStatMultiplier(selectedNatureId, "ATK"),
      defense = getNatureStatMultiplier(selectedNatureId, "DEF"),
      spatk = getNatureStatMultiplier(selectedNatureId, "SPATK"),
      spdef = getNatureStatMultiplier(selectedNatureId, "SPDEF"),
      speed = getNatureStatMultiplier(selectedNatureId, "SPD")
    }
    
    AbilityNatureState.totalNaturesApplied = AbilityNatureState.totalNaturesApplied + 1
    
    local response = {
      success = true,
      pokemonId = pokemonId,
      nature = natureData,
      statModifiers = statModifiers,
      appliedAt = timestamp
    }
    
    ao.send({
      Target = msg.From,
      Action = "NatureApplied",
      Data = json.encode(response),
      PokemonId = tostring(response.pokemonId or 0),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- AssignAbility Handler
Handlers.add("assign-ability",
  Handlers.utils.hasMatchingTag("Action", "AssignAbility"),
  function(msg)
    local pokemonId = tonumber(msg.PokemonId or msg.Id)
    local abilitySlot = tonumber(msg.AbilitySlot) or 1
    local forceAbility = tonumber(msg.ForceAbility)
    local timestamp = tonumber(msg.Timestamp) or 0
    
    if not pokemonId then
      ao.send({
        Target = msg.From,
        Action = "AbilityAssigned",
        Data = json.encode({success = false, error = "PokemonId is required"}),
        Error = "PokemonId is required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    if abilitySlot < 1 or abilitySlot > 3 then
      ao.send({
        Target = msg.From,
        Action = "AbilityAssigned",
        Data = json.encode({success = false, error = "AbilitySlot must be 1-3 (1=normal1, 2=normal2, 3=hidden)"}),
        Error = "AbilitySlot must be 1-3 (1=normal1, 2=normal2, 3=hidden)",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    -- For testing, assign common abilities based on slot
    local assignedAbilityId = forceAbility
    if not assignedAbilityId then
      if abilitySlot == 1 then
        assignedAbilityId = 65 -- Overgrow
      elseif abilitySlot == 2 then
        assignedAbilityId = 66 -- Blaze  
      else
        assignedAbilityId = 67 -- Torrent (hidden)
      end
    end
    
    local abilityData = getAbilityById(assignedAbilityId)
    if not abilityData then
      ao.send({
        Target = msg.From,
        Action = "AbilityAssigned",
        Data = json.encode({success = false, error = "Invalid ability ID: " .. tostring(assignedAbilityId)}),
        Error = "Invalid ability ID: " .. tostring(assignedAbilityId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    AbilityNatureState.totalAbilitiesAssigned = AbilityNatureState.totalAbilitiesAssigned + 1
    
    local response = {
      success = true,
      pokemonId = pokemonId,
      ability = {
        abilityId = assignedAbilityId,
        name = abilityData.name,
        description = abilityData.description,
        triggers = abilityData.triggers or {},
        effects = abilityData.effects or {},
        slot = abilitySlot
      },
      slot = abilitySlot,
      assignedAt = timestamp
    }
    
    ao.send({
      Target = msg.From,
      Action = "AbilityAssigned",
      Data = json.encode(response),
      AbilityId = tostring(response.ability and response.ability.abilityId or 0),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- TriggerAbility Handler
Handlers.add("trigger-ability",
  Handlers.utils.hasMatchingTag("Action", "TriggerAbility"),
  function(msg)
    local pokemonId = tonumber(msg.PokemonId or msg.Id)
    local abilityId = tonumber(msg.AbilityId)
    local triggerEvent = msg.TriggerEvent or "MANUAL"
    local battleContext = msg.BattleContext and json.decode(msg.BattleContext) or {}
    local timestamp = tonumber(msg.Timestamp) or 0
    
    if not pokemonId or not abilityId then
      ao.send({
        Target = msg.From,
        Action = "AbilityTriggered",
        Data = json.encode({success = false, error = "PokemonId and AbilityId are required"}),
        Error = "PokemonId and AbilityId are required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local abilityData = getAbilityById(abilityId)
    if not abilityData then
      ao.send({
        Target = msg.From,
        Action = "AbilityTriggered",
        Data = json.encode({success = false, error = "Invalid ability ID: " .. tostring(abilityId)}),
        Error = "Invalid ability ID: " .. tostring(abilityId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    -- Process ability effects
    local effects = {}
    local chainTriggers = {}
    
    if abilityData.weatherEffect then
      table.insert(effects, {type = "WEATHER", value = abilityData.weatherEffect})
    end
    
    if abilityData.statChange then
      table.insert(effects, {type = "STAT_CHANGE", data = abilityData.statChange})
    end
    
    if abilityData.statusInflict then
      table.insert(effects, {type = "STATUS_INFLICT", status = abilityData.statusInflict})
    end
    
    if abilityData.typeBonus then
      table.insert(effects, {type = "TYPE_BOOST", pokemonType = abilityData.typeBonus, multiplier = 1.5})
    end
    
    AbilityNatureState.totalAbilitiesTriggered = AbilityNatureState.totalAbilitiesTriggered + 1
    
    local response = {
      success = true,
      pokemonId = pokemonId,
      abilityId = abilityId,
      abilityName = abilityData.name,
      triggerEvent = triggerEvent,
      effects = effects,
      chainTriggers = chainTriggers,
      triggeredAt = timestamp
    }
    
    ao.send({
      Target = msg.From,
      Action = "AbilityTriggered",
      Data = json.encode(response),
      AbilityId = tostring(response.abilityId),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- GetAbilityInfo Handler
Handlers.add("get-ability-info",
  Handlers.utils.hasMatchingTag("Action", "GetAbilityInfo"),
  function(msg)
    local abilityId = tonumber(msg.AbilityId or msg.Id)
    
    if not abilityId then
      ao.send({
        Target = msg.From,
        Action = "AbilityInfo",
        Data = json.encode({success = false, error = "AbilityId is required"}),
        Error = "AbilityId is required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local abilityData = getAbilityById(abilityId)
    if not abilityData then
      ao.send({
        Target = msg.From,
        Action = "AbilityInfo",
        Data = json.encode({success = false, error = "Ability not found: " .. tostring(abilityId)}),
        Error = "Ability not found: " .. tostring(abilityId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local response = {
      success = true,
      ability = {
        abilityId = abilityId,
        name = abilityData.name,
        description = abilityData.description,
        triggers = abilityData.triggers or {},
        effects = abilityData.effects or {},
        weatherEffect = abilityData.weatherEffect,
        statChange = abilityData.statChange,
        statusInflict = abilityData.statusInflict,
        typeBonus = abilityData.typeBonus,
        absorbs = abilityData.absorbs
      }
    }
    
    ao.send({
      Target = msg.From,
      Action = "AbilityInfo",
      Data = json.encode(response),
      AbilityId = tostring(msg.AbilityId or msg.Id or 0),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- GetNatureInfo Handler
Handlers.add("get-nature-info",
  Handlers.utils.hasMatchingTag("Action", "GetNatureInfo"),
  function(msg)
    local natureId = tonumber(msg.NatureId or msg.Id)
    
    if not natureId then
      ao.send({
        Target = msg.From,
        Action = "NatureInfo",
        Data = json.encode({success = false, error = "NatureId is required"}),
        Error = "NatureId is required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local natureData = getNatureById(natureId)
    if not natureData then
      ao.send({
        Target = msg.From,
        Action = "NatureInfo",
        Data = json.encode({success = false, error = "Nature not found: " .. tostring(natureId)}),
        Error = "Nature not found: " .. tostring(natureId),
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    -- Calculate multipliers for all stats
    local multipliers = {
      hp = 1.0,
      attack = getNatureStatMultiplier(natureId, "ATK"),
      defense = getNatureStatMultiplier(natureId, "DEF"),
      spatk = getNatureStatMultiplier(natureId, "SPATK"),
      spdef = getNatureStatMultiplier(natureId, "SPDEF"),
      speed = getNatureStatMultiplier(natureId, "SPD")
    }
    
    local response = {
      success = true,
      nature = {
        natureId = natureId,
        name = natureData.name,
        increasedStat = natureData.increasedStat,
        decreasedStat = natureData.decreasedStat,
        multipliers = multipliers
      }
    }
    
    ao.send({
      Target = msg.From,
      Action = "NatureInfo",
      Data = json.encode(response),
      NatureId = tostring(msg.NatureId or msg.Id or 0),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- InitializeBattleState Handler
Handlers.add("initialize-battle-state",
  Handlers.utils.hasMatchingTag("Action", "InitializeBattleState"),
  function(msg)
    local battleId = msg.BattleId
    local pokemonId = tonumber(msg.PokemonId)
    local abilityId = tonumber(msg.AbilityId)
    
    if not battleId or not pokemonId or not abilityId then
      ao.send({
        Target = msg.From,
        Action = "BattleStateInitialized",
        Data = json.encode({success = false, error = "BattleId, PokemonId, and AbilityId are required"}),
        Error = "BattleId, PokemonId, and AbilityId are required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local battleState = initializeBattleAbilityState(battleId, pokemonId, abilityId)
    
    local response = {
      success = true,
      battleId = battleId,
      pokemonId = pokemonId,
      abilityId = abilityId,
      battleState = battleState
    }
    
    ao.send({
      Target = msg.From,
      Action = "BattleStateInitialized",
      Data = json.encode(response),
      BattleId = msg.BattleId or "",
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- UpdateBattleAbilityState Handler
Handlers.add("update-battle-ability-state",
  Handlers.utils.hasMatchingTag("Action", "UpdateBattleAbilityState"),
  function(msg)
    local battleId = msg.BattleId
    local pokemonId = tonumber(msg.PokemonId)
    local abilityId = tonumber(msg.AbilityId)
    local turn = tonumber(msg.Turn) or 0
    local effectData = msg.EffectData and json.decode(msg.EffectData) or {}
    
    if not battleId or not pokemonId or not abilityId then
      ao.send({
        Target = msg.From,
        Action = "BattleStateUpdated",
        Data = json.encode({success = false, error = "BattleId, PokemonId, and AbilityId are required"}),
        Error = "BattleId, PokemonId, and AbilityId are required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local battleState = initializeBattleAbilityState(battleId, pokemonId, abilityId)
    battleState.activated = true
    battleState.activationCount = battleState.activationCount + 1
    battleState.lastActivatedTurn = turn
    
    -- Add persistent effect if provided
    if effectData.type then
      table.insert(battleState.persistentEffects, {
        type = effectData.type,
        value = effectData.value,
        duration = effectData.duration or -1, -- -1 means permanent until removed
        appliedTurn = turn
      })
    end
    
    local response = {
      success = true,
      battleId = battleId,
      pokemonId = pokemonId,
      abilityId = abilityId,
      battleState = battleState,
      updatedAt = turn
    }
    
    ao.send({
      Target = msg.From,
      Action = "BattleStateUpdated",
      Data = json.encode(response),
      BattleId = msg.BattleId or "",
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- CleanupBattleState Handler
Handlers.add("cleanup-battle-state",
  Handlers.utils.hasMatchingTag("Action", "CleanupBattleState"),
  function(msg)
    local battleId = msg.BattleId
    
    if not battleId then
      ao.send({
        Target = msg.From,
        Action = "BattleStateCleanedUp",
        Data = json.encode({success = false, error = "BattleId is required"}),
        Error = "BattleId is required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local removedStates = 0
    if BattleStates[battleId] then
      for key, _ in pairs(BattleStates[battleId]) do
        removedStates = removedStates + 1
      end
      BattleStates[battleId] = nil
    end
    
    local response = {
      success = true,
      battleId = battleId,
      removedStates = removedStates
    }
    
    ao.send({
      Target = msg.From,
      Action = "BattleStateCleanedUp",
      Data = json.encode(response),
      BattleId = msg.BattleId or "",
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- GetBattleAbilityState Handler
Handlers.add("get-battle-ability-state",
  Handlers.utils.hasMatchingTag("Action", "GetBattleAbilityState"),
  function(msg)
    local battleId = msg.BattleId
    local pokemonId = tonumber(msg.PokemonId)
    local abilityId = tonumber(msg.AbilityId)
    
    if not battleId then
      ao.send({
        Target = msg.From,
        Action = "BattleAbilityState",
        Data = json.encode({success = false, error = "BattleId is required"}),
        Error = "BattleId is required",
        ProcessId = ao.id,
        Timestamp = tostring(msg.Timestamp or 0)
      })
      return
    end
    
    local response
    if pokemonId and abilityId then
      -- Get specific ability state
      local key = pokemonId .. "_" .. abilityId
      local battleState = BattleStates[battleId] and BattleStates[battleId][key]
      
      if not battleState then
        ao.send({
          Target = msg.From,
          Action = "BattleAbilityState",
          Data = json.encode({success = false, error = "Battle state not found for Pokemon " .. pokemonId .. " ability " .. abilityId}),
          Error = "Battle state not found for Pokemon " .. pokemonId .. " ability " .. abilityId,
          ProcessId = ao.id,
          Timestamp = tostring(msg.Timestamp or 0)
        })
        return
      end
      
      response = {
        success = true,
        battleId = battleId,
        pokemonId = pokemonId,
        abilityId = abilityId,
        battleState = battleState
      }
    else
      -- Get all battle states for this battle
      local allStates = BattleStates[battleId] or {}
      
      response = {
        success = true,
        battleId = battleId,
        allStates = allStates,
        stateCount = #allStates
      }
    end
    
    ao.send({
      Target = msg.From,
      Action = "BattleAbilityState",
      Data = json.encode(response),
      BattleId = msg.BattleId or "",
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

-- Info Handler for ADP v1.0 compliance
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    local processInfo = {
      name = "Abilities and Nature Manager",
      description = "Pokemon ability and nature management with exact TypeScript parity",
      version = "1.0.0",
      adpVersion = "1.0",
      processId = ao.id,
      capabilities = {
        "nature-assignment",
        "ability-assignment", 
        "ability-triggering",
        "stat-calculation",
        "battle-integration"
      },
      handlers = {
        "ApplyNature",
        "AssignAbility", 
        "TriggerAbility",
        "GetAbilityInfo",
        "GetNatureInfo",
        "InitializeBattleState",
        "UpdateBattleAbilityState",
        "CleanupBattleState",
        "GetBattleAbilityState",
        "Info"
      },
      messageSchemas = {
        ApplyNature = {
          required = {"PokemonId"},
          optional = {"NatureId", "ForceNature", "Timestamp"}
        },
        AssignAbility = {
          required = {"PokemonId"},
          optional = {"AbilitySlot", "ForceAbility", "Timestamp"}
        },
        TriggerAbility = {
          required = {"PokemonId", "AbilityId"},
          optional = {"TriggerEvent", "BattleContext", "Timestamp"}
        },
        GetAbilityInfo = {
          required = {"AbilityId"},
          optional = {"Timestamp"}
        },
        GetNatureInfo = {
          required = {"NatureId"},
          optional = {"Timestamp"}
        },
        InitializeBattleState = {
          required = {"BattleId", "PokemonId", "AbilityId"},
          optional = {"Timestamp"}
        },
        UpdateBattleAbilityState = {
          required = {"BattleId", "PokemonId", "AbilityId"},
          optional = {"Turn", "EffectData", "Timestamp"}
        },
        CleanupBattleState = {
          required = {"BattleId"},
          optional = {"Timestamp"}
        },
        GetBattleAbilityState = {
          required = {"BattleId"},
          optional = {"PokemonId", "AbilityId", "Timestamp"}
        }
      },
      state = {
        totalNaturesApplied = AbilityNatureState.totalNaturesApplied,
        totalAbilitiesTriggered = AbilityNatureState.totalAbilitiesTriggered,
        totalAbilitiesAssigned = AbilityNatureState.totalAbilitiesAssigned,
        embeddedNatures = 25,
        embeddedAbilities = 19,
        activeBattles = 0,
        totalBattleStatesTracked = 0
      },
      documentation = {
        adpCompliance = "v1.0",
        selfDocumenting = true,
        typeScriptParity = true,
        naturePrecision = "0.9/1.0/1.1 exact multipliers"
      }
    }
    
    ao.send({
      Target = msg.From,
      Action = "InfoResponse",
      Data = json.encode(processInfo),
      ProcessId = ao.id,
      Timestamp = tostring(msg.Timestamp or 0)
    })
  end
)

print("Abilities and Nature Manager Process initialized")
print("Embedded data: 25 natures, 19 abilities")
print("Handlers: ApplyNature, AssignAbility, TriggerAbility, GetAbilityInfo, GetNatureInfo, Info")
print("ADP v1.0 compliant with exact TypeScript parity for nature multipliers")