-- Experience and Leveling Engine Process
-- Handles Pokemon experience calculations, leveling, and stat recalculation
-- Maintains perfect mathematical parity with TypeScript implementation

-- Process Metadata for ADP v1.0 Compliance
local PROCESS_NAME = "Experience and Leveling Engine"
local PROCESS_VERSION = "1.0.0"
local ADP_VERSION = "1.0"

-- Growth Rate Constants
local GROWTH_RATE = {
    ERRATIC = 0,
    FAST = 1,
    MEDIUM_FAST = 2,
    MEDIUM_SLOW = 3,
    SLOW = 4,
    FLUCTUATING = 5
}

-- Maximum level constant
local MAX_LEVEL = 100

-- Pre-calculated experience tables for levels 1-99
local expLevels = {
    -- ERRATIC
    {
        0, 15, 52, 122, 237, 406, 637, 942, 1326, 1800, 2369, 3041, 3822, 4719, 5737, 6881, 8155, 9564, 11111, 12800, 14632,
        16610, 18737, 21012, 23437, 26012, 28737, 31610, 34632, 37800, 41111, 44564, 48155, 51881, 55737, 59719, 63822,
        68041, 72369, 76800, 81326, 85942, 90637, 95406, 100237, 105122, 110052, 115015, 120001, 125000, 131324, 137795,
        144410, 151165, 158056, 165079, 172229, 179503, 186894, 194400, 202013, 209728, 217540, 225443, 233431, 241496,
        249633, 257834, 267406, 276458, 286328, 296358, 305767, 316074, 326531, 336255, 346965, 357812, 367807, 378880,
        390077, 400293, 411686, 423190, 433572, 445239, 457001, 467489, 479378, 491346, 501878, 513934, 526049, 536557,
        548720, 560922, 571333, 583539, 591882, 600000
    },
    -- FAST
    {
        0, 6, 21, 51, 100, 172, 274, 409, 583, 800, 1064, 1382, 1757, 2195, 2700, 3276, 3930, 4665, 5487, 6400, 7408, 8518,
        9733, 11059, 12500, 14060, 15746, 17561, 19511, 21600, 23832, 26214, 28749, 31443, 34300, 37324, 40522, 43897,
        47455, 51200, 55136, 59270, 63605, 68147, 72900, 77868, 83058, 88473, 94119, 100000, 106120, 112486, 119101, 125971,
        133100, 140492, 148154, 156089, 164303, 172800, 181584, 190662, 200037, 209715, 219700, 229996, 240610, 251545,
        262807, 274400, 286328, 298598, 311213, 324179, 337500, 351180, 365226, 379641, 394431, 409600, 425152, 441094,
        457429, 474163, 491300, 508844, 526802, 545177, 563975, 583200, 602856, 622950, 643485, 664467, 685900, 707788,
        730138, 752953, 776239, 800000
    },
    -- MEDIUM_FAST
    {
        0, 8, 27, 64, 125, 216, 343, 512, 729, 1000, 1331, 1728, 2197, 2744, 3375, 4096, 4913, 5832, 6859, 8000, 9261,
        10648, 12167, 13824, 15625, 17576, 19683, 21952, 24389, 27000, 29791, 32768, 35937, 39304, 42875, 46656, 50653,
        54872, 59319, 64000, 68921, 74088, 79507, 85184, 91125, 97336, 103823, 110592, 117649, 125000, 132651, 140608,
        148877, 157464, 166375, 175616, 185193, 195112, 205379, 216000, 226981, 238328, 250047, 262144, 274625, 287496,
        300763, 314432, 328509, 343000, 357911, 373248, 389017, 405224, 421875, 438976, 456533, 474552, 493039, 512000,
        531441, 551368, 571787, 592704, 614125, 636056, 658503, 681472, 704969, 729000, 753571, 778688, 804357, 830584,
        857375, 884736, 912673, 941192, 970299, 1000000
    },
    -- MEDIUM_SLOW
    {
        0, 9, 57, 96, 135, 179, 236, 314, 419, 560, 742, 973, 1261, 1612, 2035, 2535, 3120, 3798, 4575, 5460, 6458, 7577,
        8825, 10208, 11735, 13411, 15244, 17242, 19411, 21760, 24294, 27021, 29949, 33084, 36435, 40007, 43808, 47846,
        52127, 56660, 61450, 66505, 71833, 77440, 83335, 89523, 96012, 102810, 109923, 117360, 125126, 133229, 141677,
        150476, 159635, 169159, 179056, 189334, 199999, 211060, 222522, 234393, 246681, 259392, 272535, 286115, 300140,
        314618, 329555, 344960, 360838, 377197, 394045, 411388, 429235, 447591, 466464, 485862, 505791, 526260, 547274,
        568841, 590969, 613664, 636935, 660787, 685228, 710266, 735907, 762160, 789030, 816525, 844653, 873420, 902835,
        932903, 963632, 995030, 1027103, 1059860
    },
    -- SLOW
    {
        0, 10, 33, 80, 156, 270, 428, 640, 911, 1250, 1663, 2160, 2746, 3430, 4218, 5120, 6141, 7290, 8573, 10000, 11576,
        13310, 15208, 17280, 19531, 21970, 24603, 27440, 30486, 33750, 37238, 40960, 44921, 49130, 53593, 58320, 63316,
        68590, 74148, 80000, 86151, 92610, 99383, 106480, 113906, 121670, 129778, 138240, 147061, 156250, 165813, 175760,
        186096, 196830, 207968, 219520, 231491, 243890, 256723, 270000, 283726, 297910, 312558, 327680, 343281, 359370,
        375953, 393040, 410636, 428750, 447388, 466560, 486271, 506530, 527343, 548720, 570666, 593190, 616298, 640000,
        664301, 689210, 714733, 740880, 767656, 795070, 823128, 851840, 881211, 911250, 941963, 973360, 1005446, 1038230,
        1071718, 1105920, 1140841, 1176490, 1212873, 1250000
    },
    -- FLUCTUATING
    {
        0, 4, 13, 32, 65, 112, 178, 276, 393, 540, 745, 967, 1230, 1591, 1957, 2457, 3046, 3732, 4526, 5440, 6482, 7666,
        9003, 10506, 12187, 14060, 16140, 18439, 20974, 23760, 26811, 30146, 33780, 37731, 42017, 46656, 50653, 55969,
        60505, 66560, 71677, 78533, 84277, 91998, 98415, 107069, 114205, 123863, 131766, 142500, 151222, 163105, 172697,
        185807, 196322, 210739, 222231, 238036, 250562, 267840, 281456, 300293, 315059, 335544, 351520, 373744, 390991,
        415050, 433631, 459620, 479600, 507617, 529063, 559209, 582187, 614566, 639146, 673863, 700115, 737280, 765275,
        804997, 834809, 877201, 908905, 954084, 987754, 1035837, 1071552, 1122660, 1160499, 1214753, 1254796, 1312322,
        1354652, 1415577, 1460276, 1524731, 1571884, 1640000
    }
}

-- Helper function for power calculation (Lua 5.3 compatible)
local function pow(base, exp)
    return base ^ exp
end

-- Helper function for floor operation matching TypeScript Math.floor
local function floor(x)
    return math.floor(x)
end

-- Get total experience required for a level
local function getLevelTotalExp(level, growthRate)
    if level <= 0 then
        return 0
    end
    
    if level <= 100 then
        local levelExp = expLevels[growthRate + 1][level]  -- +1 because Lua arrays are 1-indexed
        if growthRate ~= GROWTH_RATE.MEDIUM_FAST then
            local mediumFastExp = expLevels[GROWTH_RATE.MEDIUM_FAST + 1][level]
            return floor(levelExp * 0.325 + mediumFastExp * 0.675)
        end
        return levelExp
    end
    
    -- Calculate for levels >= 100 using formulas
    local ret
    if growthRate == GROWTH_RATE.ERRATIC then
        ret = (pow(level, 4) + pow(level, 3) * 2000) / 3500
    elseif growthRate == GROWTH_RATE.FAST then
        ret = (pow(level, 3) * 4) / 5
    elseif growthRate == GROWTH_RATE.MEDIUM_FAST then
        ret = pow(level, 3)
    elseif growthRate == GROWTH_RATE.MEDIUM_SLOW then
        ret = (pow(level, 3) * 6) / 5 - 15 * pow(level, 2) + 100 * level - 140
    elseif growthRate == GROWTH_RATE.SLOW then
        ret = (pow(level, 3) * 5) / 4
    elseif growthRate == GROWTH_RATE.FLUCTUATING then
        ret = (pow(level, 3) * (level / 2 + 8) * 4) / (100 + level)
    end
    
    if growthRate ~= GROWTH_RATE.MEDIUM_FAST then
        return floor(ret * 0.325 + getLevelTotalExp(level, GROWTH_RATE.MEDIUM_FAST) * 0.675)
    end
    
    return floor(ret)
end

-- Get experience required to go from level-1 to level
local function getLevelRelExp(level, growthRate)
    return getLevelTotalExp(level, growthRate) - getLevelTotalExp(level - 1, growthRate)
end

-- Convert growth rate string to enum value
local function parseGrowthRate(growthRateStr)
    local rates = {
        ["ERRATIC"] = GROWTH_RATE.ERRATIC,
        ["FAST"] = GROWTH_RATE.FAST,
        ["MEDIUM_FAST"] = GROWTH_RATE.MEDIUM_FAST,
        ["MEDIUM_SLOW"] = GROWTH_RATE.MEDIUM_SLOW,
        ["SLOW"] = GROWTH_RATE.SLOW,
        ["FLUCTUATING"] = GROWTH_RATE.FLUCTUATING
    }
    return rates[growthRateStr] or GROWTH_RATE.MEDIUM_FAST
end

-- Calculate base experience gain from defeating a Pokemon
local function calculateBaseExperience(defeatedPokemon, victorPokemon, battleType)
    -- Base experience formula matching TypeScript
    local baseExp = defeatedPokemon.baseExperience or 100
    local defeatedLevel = defeatedPokemon.level or 1
    local victorLevel = victorPokemon.level or 1
    
    -- Base calculation: (baseExp * defeatedLevel) / 5
    local expGain = floor((baseExp * defeatedLevel) / 5)
    
    -- Level adjustment: * ((2 * defeatedLevel + 10) / (defeatedLevel + victorLevel + 10))^2.5 + 1
    local levelFactor = pow((2 * defeatedLevel + 10) / (defeatedLevel + victorLevel + 10), 2.5) + 1
    expGain = floor(expGain * levelFactor)
    
    -- Battle type modifier
    if battleType == "TRAINER" or battleType == "GYM" then
        expGain = floor(expGain * 1.5)  -- Trainer battle bonus
    end
    
    return expGain
end

-- Apply experience modifiers (held items, etc.)
local function applyExperienceModifiers(baseExp, modifiers)
    local finalExp = baseExp
    
    if modifiers then
        -- Lucky Egg modifier
        if modifiers.hasLuckyEgg then
            finalExp = floor(finalExp * 1.5)
        end
        
        -- Traded Pokemon modifier
        if modifiers.isTraded then
            if modifiers.isDifferentLanguage then
                finalExp = floor(finalExp * 1.7)  -- Different language traded Pokemon
            else
                finalExp = floor(finalExp * 1.5)  -- Same language traded Pokemon
            end
        end
        
        -- Affection bonus (from Pokemon-Amie/Refresh/Camp)
        if modifiers.hasAffectionBonus then
            finalExp = floor(finalExp * 1.2)
        end
        
        -- EXP Point Power from O-Powers
        if modifiers.expPowerLevel then
            local powerMultipliers = {1.2, 1.5, 2.0}  -- Level 1, 2, 3
            finalExp = floor(finalExp * (powerMultipliers[modifiers.expPowerLevel] or 1.0))
        end
    end
    
    return finalExp
end

-- Distribute experience among party members
local function distributeExperience(totalExp, participatingPokemon, allPartyPokemon, hasExpShare)
    local distribution = {}
    
    if hasExpShare then
        -- Modern EXP Share: All party Pokemon get full experience
        for i, pokemon in ipairs(allPartyPokemon) do
            if pokemon.hp and pokemon.hp > 0 then  -- Only non-fainted Pokemon
                distribution[i] = totalExp
            else
                distribution[i] = 0
            end
        end
    else
        -- Classic distribution: Split among participants
        local activeCount = 0
        local participantMap = {}
        
        -- Count active participants
        for _, participantId in ipairs(participatingPokemon) do
            for i, pokemon in ipairs(allPartyPokemon) do
                if pokemon.id == participantId and pokemon.hp and pokemon.hp > 0 then
                    activeCount = activeCount + 1
                    participantMap[i] = true
                    break
                end
            end
        end
        
        -- Distribute experience
        if activeCount > 0 then
            local expPerPokemon = floor(totalExp / activeCount)
            for i, pokemon in ipairs(allPartyPokemon) do
                if participantMap[i] then
                    distribution[i] = expPerPokemon
                else
                    distribution[i] = 0
                end
            end
        end
    end
    
    return distribution
end

-- Get level from total experience
local function getLevelFromExp(totalExp, growthRate)
    -- Binary search for efficiency
    local level = 1
    for lvl = 1, MAX_LEVEL do
        if totalExp >= getLevelTotalExp(lvl, growthRate) then
            level = lvl
        else
            break
        end
    end
    return level
end

-- Calculate stat based on base stat, IV, EV, level, and nature
local function calculateStat(baseStat, iv, ev, level, natureMod, isHP)
    iv = iv or 0
    ev = ev or 0
    natureMod = natureMod or 1.0
    
    if isHP then
        -- HP formula: floor((2 * base + iv + floor(ev/4)) * level / 100) + level + 10
        return floor((2 * baseStat + iv + floor(ev / 4)) * level / 100) + level + 10
    else
        -- Other stats: floor((floor((2 * base + iv + floor(ev/4)) * level / 100) + 5) * nature)
        return floor((floor((2 * baseStat + iv + floor(ev / 4)) * level / 100) + 5) * natureMod)
    end
end

-- Calculate stat increases on level up
local function calculateLevelUpStats(pokemon, oldLevel, newLevel, speciesBaseStats)
    local statIncreases = {}
    
    -- Nature modifiers (simplified - would need full nature data in production)
    local natureModifiers = {
        attack = pokemon.natureMod and pokemon.natureMod.attack or 1.0,
        defense = pokemon.natureMod and pokemon.natureMod.defense or 1.0,
        spatk = pokemon.natureMod and pokemon.natureMod.spatk or 1.0,
        spdef = pokemon.natureMod and pokemon.natureMod.spdef or 1.0,
        speed = pokemon.natureMod and pokemon.natureMod.speed or 1.0
    }
    
    -- Calculate new stats
    local oldStats = {
        hp = calculateStat(speciesBaseStats.hp, pokemon.ivs.hp, pokemon.evs.hp, oldLevel, 1.0, true),
        attack = calculateStat(speciesBaseStats.attack, pokemon.ivs.attack, pokemon.evs.attack, oldLevel, natureModifiers.attack, false),
        defense = calculateStat(speciesBaseStats.defense, pokemon.ivs.defense, pokemon.evs.defense, oldLevel, natureModifiers.defense, false),
        spatk = calculateStat(speciesBaseStats.spatk, pokemon.ivs.spatk, pokemon.evs.spatk, oldLevel, natureModifiers.spatk, false),
        spdef = calculateStat(speciesBaseStats.spdef, pokemon.ivs.spdef, pokemon.evs.spdef, oldLevel, natureModifiers.spdef, false),
        speed = calculateStat(speciesBaseStats.speed, pokemon.ivs.speed, pokemon.evs.speed, oldLevel, natureModifiers.speed, false)
    }
    
    local newStats = {
        hp = calculateStat(speciesBaseStats.hp, pokemon.ivs.hp, pokemon.evs.hp, newLevel, 1.0, true),
        attack = calculateStat(speciesBaseStats.attack, pokemon.ivs.attack, pokemon.evs.attack, newLevel, natureModifiers.attack, false),
        defense = calculateStat(speciesBaseStats.defense, pokemon.ivs.defense, pokemon.evs.defense, newLevel, natureModifiers.defense, false),
        spatk = calculateStat(speciesBaseStats.spatk, pokemon.ivs.spatk, pokemon.evs.spatk, newLevel, natureModifiers.spatk, false),
        spdef = calculateStat(speciesBaseStats.spdef, pokemon.ivs.spdef, pokemon.evs.spdef, newLevel, natureModifiers.spdef, false),
        speed = calculateStat(speciesBaseStats.speed, pokemon.ivs.speed, pokemon.evs.speed, newLevel, natureModifiers.speed, false)
    }
    
    -- Calculate increases
    statIncreases.hp = newStats.hp - oldStats.hp
    statIncreases.attack = newStats.attack - oldStats.attack
    statIncreases.defense = newStats.defense - oldStats.defense
    statIncreases.spatk = newStats.spatk - oldStats.spatk
    statIncreases.spdef = newStats.spdef - oldStats.spdef
    statIncreases.speed = newStats.speed - oldStats.speed
    
    return statIncreases, newStats
end

-- Apply experience and check for level up
local function applyExperience(pokemon, expGained, growthRate)
    local result = {
        experienceGained = expGained,
        oldLevel = pokemon.level,
        oldExp = pokemon.exp,
        newExp = pokemon.exp + expGained,
        newLevel = pokemon.level,
        leveledUp = false,
        levelsGained = 0
    }
    
    -- Cap experience at maximum for level 100
    local maxExp = getLevelTotalExp(MAX_LEVEL, growthRate)
    if result.newExp > maxExp then
        result.newExp = maxExp
        result.experienceGained = maxExp - pokemon.exp
    end
    
    -- Check for level up
    local newLevel = getLevelFromExp(result.newExp, growthRate)
    if newLevel > pokemon.level then
        result.newLevel = math.min(newLevel, MAX_LEVEL)
        result.leveledUp = true
        result.levelsGained = result.newLevel - result.oldLevel
    end
    
    -- Calculate next level threshold
    if result.newLevel < MAX_LEVEL then
        result.nextLevelThreshold = getLevelTotalExp(result.newLevel + 1, growthRate)
        result.expToNextLevel = result.nextLevelThreshold - result.newExp
    else
        result.nextLevelThreshold = maxExp
        result.expToNextLevel = 0
    end
    
    return result
end

-- Message Handlers
if not Handlers then
    Handlers = { 
        add = function(name, matcher, handler)
            -- Mock for testing
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg) 
                    return msg[tag] == value 
                end
            end
        }
    }
end

-- Info handler for ADP v1.0 compliance
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = PROCESS_NAME,
                    version = PROCESS_VERSION,
                    adpVersion = ADP_VERSION,
                    capabilities = {
                        "CalculateExperience",
                        "ApplyExperience",
                        "GetLevelThreshold",
                        "CalculateLevelUpStats",
                        "DistributeExperience"
                    },
                    messageSchemas = {
                        CalculateExperience = {
                            required = {"Action", "DefeatedPokemon", "VictorPokemon", "BattleType"}
                        },
                        ApplyExperience = {
                            required = {"Action", "PokemonId", "ExperienceGained", "CurrentExp", "CurrentLevel", "GrowthRate"}
                        },
                        GetLevelThreshold = {
                            required = {"Action", "Level", "GrowthRate"}
                        },
                        CalculateLevelUpStats = {
                            required = {"Action", "Pokemon", "OldLevel", "NewLevel", "SpeciesId"}
                        },
                        DistributeExperience = {
                            required = {"Action", "TotalExp", "ParticipatingPokemon", "AllPartyPokemon"}
                        }
                    }
                },
                handlers = {
                    "Info",
                    "CalculateExperience",
                    "ApplyExperience",
                    "GetLevelThreshold",
                    "CalculateLevelUpStats",
                    "DistributeExperience",
                    "HealthCheck"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Handles all experience and leveling calculations with perfect TypeScript parity"
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Calculate experience gain handler
Handlers.add("calculate-experience",
    Handlers.utils.hasMatchingTag("Action", "CalculateExperience"),
    function(msg)
        -- Parse input
        local defeatedPokemon = msg.DefeatedPokemon and json.decode(msg.DefeatedPokemon)
        local victorPokemon = msg.VictorPokemon and json.decode(msg.VictorPokemon)
        local battleType = msg.BattleType or "WILD"
        local participatingPokemon = msg.ParticipatingPokemon and json.decode(msg.ParticipatingPokemon)
        local modifiers = msg.Modifiers and json.decode(msg.Modifiers)
        
        -- Validate input
        if not defeatedPokemon or not victorPokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "DefeatedPokemon and VictorPokemon required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Calculate base experience
        local baseExp = calculateBaseExperience(defeatedPokemon, victorPokemon, battleType)
        
        -- Apply modifiers
        local finalExp = applyExperienceModifiers(baseExp, modifiers)
        
        -- Prepare response
        local result = {
            baseExperience = baseExp,
            modifiedExperience = finalExp,
            modifiersApplied = modifiers or {},
            battleType = battleType
        }
        
        -- Handle party distribution if requested
        if participatingPokemon then
            local allPartyPokemon = msg.AllPartyPokemon and json.decode(msg.AllPartyPokemon) or {victorPokemon}
            local hasExpShare = modifiers and modifiers.hasExpShare or false
            result.distribution = distributeExperience(finalExp, participatingPokemon, allPartyPokemon, hasExpShare)
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                experienceResult = result
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Apply experience and level up handler
Handlers.add("apply-experience",
    Handlers.utils.hasMatchingTag("Action", "ApplyExperience"),
    function(msg)
        -- Parse input
        local pokemonId = msg.PokemonId
        local expGained = tonumber(msg.ExperienceGained)
        local currentExp = tonumber(msg.CurrentExp)
        local currentLevel = tonumber(msg.CurrentLevel)
        local growthRateStr = msg.GrowthRate
        
        -- Validate input
        if not pokemonId or not expGained or not currentExp or not currentLevel or not growthRateStr then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId, ExperienceGained, CurrentExp, CurrentLevel, and GrowthRate required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Parse growth rate
        local growthRate = parseGrowthRate(growthRateStr)
        
        -- Create Pokemon object for calculation
        local pokemon = {
            id = pokemonId,
            exp = currentExp,
            level = currentLevel
        }
        
        -- Apply experience
        local result = applyExperience(pokemon, expGained, growthRate)
        
        -- Check for stat increases if leveled up
        if result.leveledUp and msg.Pokemon and msg.SpeciesBaseStats then
            local pokemonData = json.decode(msg.Pokemon)
            local speciesBaseStats = json.decode(msg.SpeciesBaseStats)
            
            local statIncreases, newStats = calculateLevelUpStats(
                pokemonData, 
                result.oldLevel, 
                result.newLevel, 
                speciesBaseStats
            )
            
            result.statIncreases = statIncreases
            result.newStats = newStats
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                experienceResult = result
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Get level threshold handler
Handlers.add("get-level-threshold",
    Handlers.utils.hasMatchingTag("Action", "GetLevelThreshold"),
    function(msg)
        -- Parse input
        local level = tonumber(msg.Level)
        local growthRateStr = msg.GrowthRate
        
        -- Validate input
        if not level or not growthRateStr then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Level and GrowthRate required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Validate level range
        if level < 1 or level > MAX_LEVEL then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Level must be between 1 and " .. MAX_LEVEL,
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Parse growth rate
        local growthRate = parseGrowthRate(growthRateStr)
        
        -- Calculate thresholds
        local totalExp = getLevelTotalExp(level, growthRate)
        local relativeExp = getLevelRelExp(level, growthRate)
        
        local result = {
            level = level,
            growthRate = growthRateStr,
            totalExpRequired = totalExp,
            expFromPreviousLevel = relativeExp
        }
        
        -- Add next level info if not at max
        if level < MAX_LEVEL then
            result.nextLevelTotalExp = getLevelTotalExp(level + 1, growthRate)
            result.expToNextLevel = result.nextLevelTotalExp - totalExp
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                levelThreshold = result
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Calculate level up stats handler
Handlers.add("calculate-levelup-stats",
    Handlers.utils.hasMatchingTag("Action", "CalculateLevelUpStats"),
    function(msg)
        -- Parse input
        local pokemon = msg.Pokemon and json.decode(msg.Pokemon)
        local oldLevel = tonumber(msg.OldLevel)
        local newLevel = tonumber(msg.NewLevel)
        local speciesBaseStats = msg.SpeciesBaseStats and json.decode(msg.SpeciesBaseStats)
        
        -- Validate input
        if not pokemon or not oldLevel or not newLevel or not speciesBaseStats then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon, OldLevel, NewLevel, and SpeciesBaseStats required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Ensure Pokemon has required stat data
        pokemon.ivs = pokemon.ivs or {hp = 0, attack = 0, defense = 0, spatk = 0, spdef = 0, speed = 0}
        pokemon.evs = pokemon.evs or {hp = 0, attack = 0, defense = 0, spatk = 0, spdef = 0, speed = 0}
        
        -- Calculate stat increases
        local statIncreases, newStats = calculateLevelUpStats(pokemon, oldLevel, newLevel, speciesBaseStats)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                levelUpResult = {
                    oldLevel = oldLevel,
                    newLevel = newLevel,
                    statIncreases = statIncreases,
                    newStats = newStats
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Distribute experience handler
Handlers.add("distribute-experience",
    Handlers.utils.hasMatchingTag("Action", "DistributeExperience"),
    function(msg)
        -- Parse input
        local totalExp = tonumber(msg.TotalExp)
        local participatingPokemon = msg.ParticipatingPokemon and json.decode(msg.ParticipatingPokemon)
        local allPartyPokemon = msg.AllPartyPokemon and json.decode(msg.AllPartyPokemon)
        local hasExpShare = msg.HasExpShare == "true"
        
        -- Validate input
        if not totalExp or not participatingPokemon or not allPartyPokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TotalExp, ParticipatingPokemon, and AllPartyPokemon required",
                Success = "false",
                ProcessId = ao.id,
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end
        
        -- Distribute experience
        local distribution = distributeExperience(totalExp, participatingPokemon, allPartyPokemon, hasExpShare)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                distributionResult = {
                    totalExperience = totalExp,
                    distribution = distribution,
                    hasExpShare = hasExpShare,
                    participantCount = #participatingPokemon,
                    partySize = #allPartyPokemon
                }
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus",
            Status = "healthy",
            ProcessName = PROCESS_NAME,
            Version = PROCESS_VERSION,
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Experience and Leveling Engine Process initialized - Version " .. PROCESS_VERSION)