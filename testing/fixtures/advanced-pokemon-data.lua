#!/usr/bin/env lua

--[[
Advanced Pokemon Data Fixtures for Complex Testing Scenarios
Provides comprehensive test data for multi-process coordination testing:
- Real Pokemon species data for accuracy testing
- Complex team compositions for battle scenarios
- Edge case Pokemon with extreme stats
- Comprehensive nature and ability combinations
- Evolution chain test data for coordination testing
]]

local AdvancedPokemonData = {}

-- Comprehensive Pokemon species database for testing
AdvancedPokemonData.speciesDatabase = {
  -- Generation 1 iconic Pokemon
  {
    id = 1, name = "Bulbasaur", 
    baseStats = {45, 49, 49, 65, 65, 45},
    types = {"Grass", "Poison"},
    abilities = {"Overgrow", "Chlorophyll"},
    evolutionChain = {1, 2, 3},
    category = "starter"
  },
  {
    id = 25, name = "Pikachu",
    baseStats = {35, 55, 40, 50, 50, 90},
    types = {"Electric"},
    abilities = {"Static", "Lightning Rod"},
    evolutionChain = {172, 25, 26},
    category = "mascot"
  },
  {
    id = 150, name = "Mewtwo",
    baseStats = {106, 110, 90, 154, 90, 130},
    types = {"Psychic"},
    abilities = {"Pressure", "Unnerve"},
    evolutionChain = {150},
    category = "legendary"
  },
  
  -- Extreme stat Pokemon for edge case testing
  {
    id = 213, name = "Shuckle",
    baseStats = {20, 10, 230, 10, 230, 5},
    types = {"Bug", "Rock"},
    abilities = {"Sturdy", "Gluttony", "Contrary"},
    evolutionChain = {213},
    category = "extreme_defense"
  },
  {
    id = 292, name = "Shedinja",
    baseStats = {1, 90, 45, 30, 30, 40},
    types = {"Bug", "Ghost"},
    abilities = {"Wonder Guard"},
    evolutionChain = {290, 291, 292},
    category = "extreme_hp"
  },
  {
    id = 120, name = "Staryu",
    baseStats = {30, 45, 55, 70, 55, 85},
    types = {"Water"},
    abilities = {"Illuminate", "Natural Cure", "Analytic"},
    evolutionChain = {120, 121},
    category = "standard"
  },
  
  -- High BST legendaries for performance testing
  {
    id = 493, name = "Arceus",
    baseStats = {120, 120, 120, 120, 120, 120},
    types = {"Normal"},
    abilities = {"Multitype"},
    evolutionChain = {493},
    category = "creation_trio"
  },
  {
    id = 800, name = "Necrozma",
    baseStats = {97, 107, 101, 127, 89, 79},
    types = {"Psychic"},
    abilities = {"Prism Armor"},
    evolutionChain = {800},
    category = "ultra_necrozma"
  }
}

-- Comprehensive nature data with exact stat modifications
AdvancedPokemonData.natureDatabase = {
  -- Neutral natures (no stat changes)
  Hardy = {boosted = nil, lowered = nil, multipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}},
  Docile = {boosted = nil, lowered = nil, multipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}},
  Serious = {boosted = nil, lowered = nil, multipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}},
  Bashful = {boosted = nil, lowered = nil, multipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}},
  Quirky = {boosted = nil, lowered = nil, multipliers = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}},
  
  -- Attack-boosting natures
  Lonely = {boosted = "attack", lowered = "defense", multipliers = {1.0, 1.1, 0.9, 1.0, 1.0, 1.0}},
  Brave = {boosted = "attack", lowered = "speed", multipliers = {1.0, 1.1, 1.0, 1.0, 1.0, 0.9}},
  Adamant = {boosted = "attack", lowered = "specialAttack", multipliers = {1.0, 1.1, 1.0, 0.9, 1.0, 1.0}},
  Naughty = {boosted = "attack", lowered = "specialDefense", multipliers = {1.0, 1.1, 1.0, 1.0, 0.9, 1.0}},
  
  -- Defense-boosting natures
  Bold = {boosted = "defense", lowered = "attack", multipliers = {1.0, 0.9, 1.1, 1.0, 1.0, 1.0}},
  Relaxed = {boosted = "defense", lowered = "speed", multipliers = {1.0, 1.0, 1.1, 1.0, 1.0, 0.9}},
  Impish = {boosted = "defense", lowered = "specialAttack", multipliers = {1.0, 1.0, 1.1, 0.9, 1.0, 1.0}},
  Lax = {boosted = "defense", lowered = "specialDefense", multipliers = {1.0, 1.0, 1.1, 1.0, 0.9, 1.0}},
  
  -- Special Attack-boosting natures
  Modest = {boosted = "specialAttack", lowered = "attack", multipliers = {1.0, 0.9, 1.0, 1.1, 1.0, 1.0}},
  Mild = {boosted = "specialAttack", lowered = "defense", multipliers = {1.0, 1.0, 0.9, 1.1, 1.0, 1.0}},
  Quiet = {boosted = "specialAttack", lowered = "speed", multipliers = {1.0, 1.0, 1.0, 1.1, 1.0, 0.9}},
  Rash = {boosted = "specialAttack", lowered = "specialDefense", multipliers = {1.0, 1.0, 1.0, 1.1, 0.9, 1.0}},
  
  -- Special Defense-boosting natures
  Calm = {boosted = "specialDefense", lowered = "attack", multipliers = {1.0, 0.9, 1.0, 1.0, 1.1, 1.0}},
  Gentle = {boosted = "specialDefense", lowered = "defense", multipliers = {1.0, 1.0, 0.9, 1.0, 1.1, 1.0}},
  Sassy = {boosted = "specialDefense", lowered = "speed", multipliers = {1.0, 1.0, 1.0, 1.0, 1.1, 0.9}},
  Careful = {boosted = "specialDefense", lowered = "specialAttack", multipliers = {1.0, 1.0, 1.0, 0.9, 1.1, 1.0}},
  
  -- Speed-boosting natures
  Timid = {boosted = "speed", lowered = "attack", multipliers = {1.0, 0.9, 1.0, 1.0, 1.0, 1.1}},
  Hasty = {boosted = "speed", lowered = "defense", multipliers = {1.0, 1.0, 0.9, 1.0, 1.0, 1.1}},
  Jolly = {boosted = "speed", lowered = "specialAttack", multipliers = {1.0, 1.0, 1.0, 0.9, 1.0, 1.1}},
  Naive = {boosted = "speed", lowered = "specialDefense", multipliers = {1.0, 1.0, 1.0, 1.0, 0.9, 1.1}}
}

-- Competitive team compositions for complex scenario testing
AdvancedPokemonData.competitiveTeams = {
  hyperOffense = {
    {
      species = 25, -- Pikachu
      level = 50,
      nature = "Timid",
      ability = "Lightning Rod",
      item = "Focus Sash",
      moves = {"Thunderbolt", "Hidden Power Ice", "Substitute", "Encore"},
      ivs = {31, 0, 31, 31, 31, 31},
      evs = {0, 0, 0, 252, 6, 252}
    },
    {
      species = 150, -- Mewtwo
      level = 50,
      nature = "Timid",
      ability = "Pressure",
      item = "Life Orb",
      moves = {"Psystrike", "Ice Beam", "Fire Blast", "Recover"},
      ivs = {31, 0, 31, 31, 31, 31},
      evs = {0, 0, 0, 252, 6, 252}
    }
  },
  
  stall = {
    {
      species = 213, -- Shuckle
      level = 50,
      nature = "Bold",
      ability = "Sturdy",
      item = "Leftovers",
      moves = {"Stealth Rock", "Toxic", "Rest", "Sleep Talk"},
      ivs = {31, 0, 31, 31, 31, 31},
      evs = {252, 0, 252, 0, 6, 0}
    }
  },
  
  balanced = {
    {
      species = 1, -- Bulbasaur
      level = 50,
      nature = "Modest",
      ability = "Overgrow",
      item = "Eviolite",
      moves = {"Giga Drain", "Hidden Power Fire", "Sleep Powder", "Synthesis"},
      ivs = {31, 0, 31, 30, 31, 30}, -- HP Fire IVs
      evs = {248, 0, 0, 252, 0, 8}
    }
  }
}

-- Complex battle scenarios for multi-process testing
AdvancedPokemonData.battleScenarios = {
  speedTieScenario = {
    description = "Testing speed tie resolution and priority moves",
    pokemon1 = {
      species = 25, level = 50, nature = "Timid",
      finalStats = {145, 122, 90, 317, 106, 317} -- Calculated Pikachu stats
    },
    pokemon2 = {
      species = 25, level = 50, nature = "Timid", 
      finalStats = {145, 122, 90, 317, 106, 317} -- Identical Pikachu
    },
    moves = {
      {name = "Quick Attack", priority = 1, power = 40},
      {name = "Thunderbolt", priority = 0, power = 90}
    },
    expectedOutcome = "speed_tie_resolution_required"
  },
  
  typeEffectivenessScenario = {
    description = "Complex type effectiveness calculation",
    pokemon1 = {
      species = 25, level = 50, types = {"Electric"},
      finalStats = {145, 122, 90, 317, 106, 317}
    },
    pokemon2 = {
      species = 120, level = 50, types = {"Water"},
      finalStats = {105, 95, 105, 120, 105, 135} -- Calculated Staryu stats
    },
    move = {name = "Thunderbolt", type = "Electric", power = 90},
    effectiveness = 2.0, -- Super effective
    expectedDamageRange = {75, 88} -- Approximate range
  },
  
  criticalHitScenario = {
    description = "Critical hit damage calculation with different stats",
    attacker = {
      species = 150, level = 50,
      finalStats = {193, 202, 180, 317, 180, 230} -- Mewtwo
    },
    defender = {
      species = 213, level = 50,
      finalStats = {142, 58, 504, 58, 504, 23} -- Shuckle
    },
    move = {name = "Psystrike", power = 100, criticalHit = true},
    expectedOutcome = "significant_damage_despite_defense"
  }
}

-- Evolution chain test data for coordination testing
AdvancedPokemonData.evolutionChains = {
  pikachuLine = {
    {id = 172, name = "Pichu", baseStats = {20, 40, 15, 35, 35, 60}, evolutionLevel = 2},
    {id = 25, name = "Pikachu", baseStats = {35, 55, 40, 50, 50, 90}, evolutionStone = "Thunder Stone"},
    {id = 26, name = "Raichu", baseStats = {60, 90, 55, 90, 80, 110}, finalForm = true}
  },
  
  bulbasaurLine = {
    {id = 1, name = "Bulbasaur", baseStats = {45, 49, 49, 65, 65, 45}, evolutionLevel = 16},
    {id = 2, name = "Ivysaur", baseStats = {60, 62, 63, 80, 80, 60}, evolutionLevel = 32},
    {id = 3, name = "Venusaur", baseStats = {80, 82, 83, 100, 100, 80}, finalForm = true}
  },
  
  starLine = {
    {id = 120, name = "Staryu", baseStats = {30, 45, 55, 70, 55, 85}, evolutionStone = "Water Stone"},
    {id = 121, name = "Starmie", baseStats = {60, 75, 85, 100, 85, 115}, finalForm = true}
  }
}

-- Edge case test data for boundary testing
AdvancedPokemonData.edgeCases = {
  minimumValues = {
    species = {id = 999, name = "MinTest", baseStats = {1, 1, 1, 1, 1, 1}},
    level = 1,
    ivs = {0, 0, 0, 0, 0, 0},
    evs = {0, 0, 0, 0, 0, 0},
    nature = "Hardy",
    expectedStats = {12, 6, 6, 6, 6, 6} -- Calculated minimum stats
  },
  
  maximumValues = {
    species = {id = 998, name = "MaxTest", baseStats = {255, 255, 255, 255, 255, 255}},
    level = 100,
    ivs = {31, 31, 31, 31, 31, 31},
    evs = {252, 252, 6, 0, 0, 0}, -- Valid max EV spread
    nature = "Adamant",
    expectedStats = {714, 690, 591, 460, 591, 591} -- Calculated maximum stats
  },
  
  shedinja = {
    species = {id = 292, name = "Shedinja", baseStats = {1, 90, 45, 30, 30, 40}},
    level = 50,
    ivs = {31, 31, 31, 31, 31, 31},
    evs = {0, 252, 6, 0, 0, 252},
    nature = "Adamant",
    expectedStats = {1, 269, 106, 85, 85, 152}, -- HP always 1 for Shedinja
    specialCase = "hp_always_one"
  }
}

-- Comprehensive IV/EV test combinations
AdvancedPokemonData.ivEvCombinations = {
  perfectIVs = {
    description = "Perfect IVs across all stats",
    ivs = {31, 31, 31, 31, 31, 31},
    variants = {
      {evs = {252, 252, 6, 0, 0, 0}, spread = "physical_attacker"},
      {evs = {252, 0, 6, 252, 0, 0}, spread = "special_attacker"},
      {evs = {252, 0, 252, 0, 6, 0}, spread = "physical_wall"},
      {evs = {252, 0, 6, 0, 252, 0}, spread = "special_wall"},
      {evs = {6, 0, 0, 252, 0, 252}, spread = "speed_special_attacker"}
    }
  },
  
  hiddenPowerIVs = {
    description = "Hidden Power optimal IVs",
    variants = {
      {type = "Fire", ivs = {31, 0, 31, 30, 31, 30}},
      {type = "Ice", ivs = {31, 0, 30, 31, 31, 31}},
      {type = "Grass", ivs = {31, 0, 31, 30, 31, 30}},
      {type = "Fighting", ivs = {31, 30, 30, 30, 30, 30}}
    }
  },
  
  trickRoomIVs = {
    description = "Trick Room (minimum speed) IVs",
    ivs = {31, 31, 31, 31, 31, 0},
    evs = {252, 252, 6, 0, 0, 0},
    nature = "Brave" -- -Speed nature
  }
}

-- Performance test data sets
AdvancedPokemonData.performanceTestSets = {
  smallTeam = {
    size = 6,
    description = "Standard 6-Pokemon team for basic performance testing"
  },
  
  largeBattlefield = {
    size = 100,
    description = "Large battlefield simulation with 100 Pokemon"
  },
  
  tournamentSize = {
    size = 1000,
    description = "Tournament-scale testing with 1000+ Pokemon calculations"
  }
}

-- Utility functions for working with test data
function AdvancedPokemonData.getSpeciesById(id)
  for _, species in ipairs(AdvancedPokemonData.speciesDatabase) do
    if species.id == id then
      return species
    end
  end
  return nil
end

function AdvancedPokemonData.getRandomSpecies(category)
  local candidates = {}
  for _, species in ipairs(AdvancedPokemonData.speciesDatabase) do
    if not category or species.category == category then
      table.insert(candidates, species)
    end
  end
  
  if #candidates > 0 then
    return candidates[math.random(1, #candidates)]
  end
  return nil
end

function AdvancedPokemonData.generateRandomTeam(teamSize, restrictions)
  teamSize = teamSize or 6
  restrictions = restrictions or {}
  
  local team = {}
  for i = 1, teamSize do
    local species = AdvancedPokemonData.getRandomSpecies(restrictions.category)
    if species then
      local pokemon = {
        species = species.id,
        level = restrictions.level or math.random(50, 100),
        nature = restrictions.nature or "Hardy",
        ivs = restrictions.ivs or {31, 31, 31, 31, 31, 31},
        evs = restrictions.evs or {85, 85, 85, 85, 85, 85} -- Equal spread
      }
      table.insert(team, pokemon)
    end
  end
  
  return team
end

function AdvancedPokemonData.getAllNatures()
  local natures = {}
  for natureName, _ in pairs(AdvancedPokemonData.natureDatabase) do
    table.insert(natures, natureName)
  end
  return natures
end

function AdvancedPokemonData.validateEVSpread(evs)
  local total = 0
  for i = 1, 6 do
    if evs[i] < 0 or evs[i] > 252 then
      return false, string.format("EV value %d is out of range [0, 252]", evs[i])
    end
    total = total + evs[i]
  end
  
  if total > 510 then
    return false, string.format("Total EVs %d exceed maximum of 510", total)
  end
  
  return true
end

return AdvancedPokemonData