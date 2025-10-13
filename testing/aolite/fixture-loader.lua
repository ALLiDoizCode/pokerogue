#!/usr/bin/env lua

--[[
Fixture Loader for AO Process Testing
Provides consistent test data fixtures for Pokemon, battles, and game states
Version: 1.0.0
]]

local FixtureLoader = {}

-- Fixture registry
local Fixtures = {
    pokemon = {},
    battles = {},
    items = {},
    players = {},
    gameStates = {}
}

-- Pokemon fixtures
Fixtures.pokemon.bulbasaur = {
    id = "pokemon-001",
    speciesId = 1,
    level = 25,
    currentHp = 78,
    stats = {
        hp = 78,
        attack = 62,
        defense = 63,
        spAttack = 80,
        spDefense = 80,
        speed = 60
    },
    types = {"Grass", "Poison"},
    moves = {1, 2, 3, 4}, -- Move IDs
    ability = 1,
    nature = "modest",
    ivs = {hp = 20, attack = 15, defense = 25, spAttack = 31, spDefense = 28, speed = 18},
    evs = {hp = 0, attack = 0, defense = 0, spAttack = 252, spDefense = 4, speed = 252}
}

Fixtures.pokemon.pikachu = {
    id = "pokemon-025", 
    speciesId = 25,
    level = 50,
    currentHp = 145,
    stats = {
        hp = 145,
        attack = 85,
        defense = 70,
        spAttack = 75,
        spDefense = 75,
        speed = 125
    },
    types = {"Electric"},
    moves = {25, 85, 87, 129}, -- Thunderbolt, Thunder, Agility, Swift
    ability = 9, -- Static
    nature = "timid",
    ivs = {hp = 31, attack = 0, defense = 31, spAttack = 31, spDefense = 31, speed = 31},
    evs = {hp = 4, attack = 0, defense = 0, spAttack = 252, spDefense = 0, speed = 252}
}

Fixtures.pokemon.charizard = {
    id = "pokemon-006",
    speciesId = 6,
    level = 75,
    currentHp = 207,
    stats = {
        hp = 207,
        attack = 174,
        defense = 141,
        spAttack = 189,
        spDefense = 145,
        speed = 180
    },
    types = {"Fire", "Flying"},
    moves = {83, 53, 17, 307}, -- Fire Blast, Flamethrower, Wing Attack, Dragon Pulse
    ability = 66, -- Solar Power
    nature = "modest",
    ivs = {hp = 31, attack = 0, defense = 31, spAttack = 31, spDefense = 31, speed = 31},
    evs = {hp = 0, attack = 0, defense = 4, spAttack = 252, spDefense = 0, speed = 252}
}

-- Low level Pokemon for testing evolution
Fixtures.pokemon.charmander = {
    id = "pokemon-004",
    speciesId = 4,
    level = 15,
    currentHp = 44,
    stats = {
        hp = 44,
        attack = 37,
        defense = 32,
        spAttack = 40,
        spDefense = 35,
        speed = 47
    },
    types = {"Fire"},
    moves = {1, 10, 52, 39}, -- Scratch, Ember, Smokescreen, Leer
    ability = 66,
    nature = "adamant",
    ivs = {hp = 25, attack = 31, defense = 20, spAttack = 15, spDefense = 18, speed = 28},
    evs = {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0}
}

-- Battle state fixtures
Fixtures.battles.wildEncounter = {
    battleId = "battle-wild-001",
    battleType = "wild",
    turn = 1,
    weather = "none",
    terrain = "none",
    playerPokemon = Fixtures.pokemon.pikachu,
    opponentPokemon = {
        id = "wild-pokemon-001",
        speciesId = 16, -- Pidgey
        level = 12,
        currentHp = 40,
        stats = {hp = 40, attack = 30, defense = 25, spAttack = 25, spDefense = 25, speed = 35}
    },
    playerSideConditions = {},
    opponentSideConditions = {},
    turnHistory = {}
}

Fixtures.battles.trainerBattle = {
    battleId = "battle-trainer-001",
    battleType = "trainer",
    turn = 3,
    weather = "sun",
    terrain = "none", 
    playerPokemon = Fixtures.pokemon.charizard,
    opponentPokemon = {
        id = "trainer-pokemon-001",
        speciesId = 3, -- Venusaur
        level = 75,
        currentHp = 180,
        stats = {hp = 205, attack = 142, defense = 173, spAttack = 180, spDefense = 180, speed = 140}
    },
    playerSideConditions = {},
    opponentSideConditions = {reflect = {turnsLeft = 3}},
    turnHistory = {
        {turn = 1, action = "move", moveId = 83, damage = 85},
        {turn = 2, action = "move", moveId = 76, damage = 0, effect = "reflect"},
        {turn = 3, action = "move", moveId = 307, damage = 120}
    }
}

-- Player fixtures
Fixtures.players.newPlayer = {
    id = "player-new-001",
    name = "Red",
    money = 3000,
    badges = 0,
    playtime = 120, -- minutes
    location = "pallet-town",
    party = {Fixtures.pokemon.charmander},
    pc = {},
    inventory = {
        pokeballs = 5,
        potions = 3,
        berries = {}
    }
}

Fixtures.players.experiencedPlayer = {
    id = "player-exp-001", 
    name = "Blue",
    money = 45000,
    badges = 6,
    playtime = 2400, -- 40 hours
    location = "celadon-city",
    party = {
        Fixtures.pokemon.charizard,
        Fixtures.pokemon.pikachu,
        Fixtures.pokemon.bulbasaur
    },
    pc = {}, -- Would contain many Pokemon
    inventory = {
        pokeballs = 50,
        greatBalls = 25,
        ultraBalls = 10,
        potions = 20,
        superPotions = 15,
        hyperPotions = 8,
        maxPotions = 3,
        berries = {
            oran = 12,
            pecha = 8,
            cheri = 5
        }
    }
}

-- Item fixtures
Fixtures.items.potion = {
    id = "item-017",
    name = "Potion",
    description = "Restores 20 HP",
    type = "healing",
    effect = {heal = 20},
    price = 300
}

Fixtures.items.pokeball = {
    id = "item-001",
    name = "Poke Ball", 
    description = "Used to catch Pokemon",
    type = "pokeball",
    effect = {catchRate = 1.0},
    price = 200
}

-- Game state fixtures
Fixtures.gameStates.newGame = {
    player = Fixtures.players.newPlayer,
    scene = "pallet-town",
    timestamp = 1640995200000, -- Mock timestamp for testing
    version = "1.0.0",
    flags = {
        startedJourney = true,
        receivedPokedex = false,
        defeatedElite4 = false
    },
    party = {Fixtures.pokemon.charmander},
    currentBattle = nil
}

Fixtures.gameStates.midGame = {
    player = Fixtures.players.experiencedPlayer,
    scene = "route-7", 
    timestamp = 1640995200000, -- Mock timestamp for testing
    version = "1.0.0",
    flags = {
        startedJourney = true,
        receivedPokedex = true,
        defeatedElite4 = false,
        gymBadges = {
            boulder = true,
            cascade = true,
            thunder = true,
            rainbow = true,
            soul = true,
            marsh = true,
            volcano = false,
            earth = false
        }
    },
    party = {
        Fixtures.pokemon.charizard,
        Fixtures.pokemon.pikachu,
        Fixtures.pokemon.bulbasaur
    },
    currentBattle = Fixtures.battles.trainerBattle
}

-- Fixture loading functions
function FixtureLoader.get(category, name)
    if not Fixtures[category] then
        error("Unknown fixture category: " .. tostring(category), 2)
    end
    
    if not Fixtures[category][name] then
        error("Unknown fixture: " .. tostring(category) .. "." .. tostring(name), 2)
    end
    
    -- Return deep copy to avoid test pollution
    return FixtureLoader.deepCopy(Fixtures[category][name])
end

function FixtureLoader.deepCopy(original)
    local copy
    if type(original) == "table" then
        copy = {}
        for key, value in pairs(original) do
            copy[FixtureLoader.deepCopy(key)] = FixtureLoader.deepCopy(value)
        end
    else
        copy = original
    end
    return copy
end

function FixtureLoader.list(category)
    if category then
        if not Fixtures[category] then
            return {}
        end
        local names = {}
        for name, _ in pairs(Fixtures[category]) do
            table.insert(names, name)
        end
        return names
    else
        -- List all categories
        local categories = {}
        for category, _ in pairs(Fixtures) do
            table.insert(categories, category)
        end
        return categories
    end
end

-- Create variations of fixtures
function FixtureLoader.createPokemonVariation(baseName, overrides)
    local base = FixtureLoader.get("pokemon", baseName)
    
    for key, value in pairs(overrides or {}) do
        if key == "stats" and type(value) == "table" then
            -- Merge stats
            for statName, statValue in pairs(value) do
                base.stats[statName] = statValue
            end
        elseif key == "level" then
            -- Recalculate stats for new level (simplified)
            local levelMultiplier = value / base.level
            for statName, statValue in pairs(base.stats) do
                base.stats[statName] = math.floor(statValue * levelMultiplier)
            end
            base.level = value
            base.currentHp = math.min(base.currentHp, base.stats.hp)
        else
            base[key] = value
        end
    end
    
    return base
end

function FixtureLoader.createBattleVariation(baseName, overrides)
    local base = FixtureLoader.get("battles", baseName)
    
    for key, value in pairs(overrides or {}) do
        base[key] = value
    end
    
    return base
end

-- Battle scenario generators
function FixtureLoader.generateWildBattle(playerPokemon, wildSpecies, wildLevel)
    playerPokemon = playerPokemon or "pikachu"
    wildLevel = wildLevel or math.random(10, 20)
    
    local battle = FixtureLoader.deepCopy(Fixtures.battles.wildEncounter)
    battle.playerPokemon = FixtureLoader.get("pokemon", playerPokemon)
    battle.opponentPokemon.speciesId = wildSpecies or 16 -- Pidgey
    battle.opponentPokemon.level = wildLevel
    
    -- Recalculate opponent stats based on level
    local baseStats = {hp = 40, attack = 30, defense = 25, spAttack = 25, spDefense = 25, speed = 35}
    for stat, base in pairs(baseStats) do
        battle.opponentPokemon.stats[stat] = math.floor(base * (wildLevel / 12))
    end
    battle.opponentPokemon.currentHp = battle.opponentPokemon.stats.hp
    
    return battle
end

-- Edge case fixtures (initialized after FixtureLoader functions are defined)
-- These will be set up at the end of the file

Fixtures.pokemon.maxLevel = {
    id = "pokemon-max",
    speciesId = 150, -- Mewtwo
    level = 100,
    currentHp = 415,
    stats = {
        hp = 415,
        attack = 284,
        defense = 216,
        spAttack = 405,
        spDefense = 216,
        speed = 296
    },
    types = {"Psychic"},
    moves = {94, 105, 129, 133}, -- Psychic, Recover, Swift, Amnesia
    ability = 39, -- Pressure
    nature = "modest",
    ivs = {hp = 31, attack = 0, defense = 31, spAttack = 31, spDefense = 31, speed = 31},
    evs = {hp = 4, attack = 0, defense = 0, spAttack = 252, spDefense = 0, speed = 252}
}

-- Testing utilities
function FixtureLoader.randomPokemon()
    local pokemonNames = FixtureLoader.list("pokemon")
    local randomName = pokemonNames[math.random(#pokemonNames)]
    return FixtureLoader.get("pokemon", randomName)
end

function FixtureLoader.createTestParty(size)
    size = size or 6
    local party = {}
    local pokemonNames = FixtureLoader.list("pokemon")
    
    for i = 1, math.min(size, #pokemonNames) do
        local pokemon = FixtureLoader.get("pokemon", pokemonNames[i])
        pokemon.id = "test-pokemon-" .. i
        table.insert(party, pokemon)
    end
    
    return party
end

-- Validation
function FixtureLoader.validateFixture(category, name, fixture)
    if category == "pokemon" then
        local required = {"id", "speciesId", "level", "currentHp", "stats"}
        for _, field in ipairs(required) do
            if fixture[field] == nil then
                return false, "Missing required field: " .. field
            end
        end
        
        if fixture.currentHp > fixture.stats.hp then
            return false, "Current HP cannot exceed max HP"
        end
        
        if fixture.level < 1 or fixture.level > 100 then
            return false, "Level must be between 1 and 100"
        end
    end
    
    return true, "Valid"
end

-- Initialize edge case fixtures after all functions are defined
Fixtures.pokemon.fainted = FixtureLoader.deepCopy(Fixtures.pokemon.pikachu)
Fixtures.pokemon.fainted.currentHp = 0

Fixtures.pokemon.criticalHp = FixtureLoader.deepCopy(Fixtures.pokemon.charizard)
Fixtures.pokemon.criticalHp.currentHp = 5

return FixtureLoader