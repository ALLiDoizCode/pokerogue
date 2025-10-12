-- Game Mode Engine Process
-- Handles alternative game mode systems for PokéRogue
-- ADP v1.0 Compliant | AO Sandbox Compatible

local json = require("json")

-- =======================
-- ENUMERATIONS & CONSTANTS
-- =======================

local GAME_MODES = {
    CLASSIC = 0,
    ENDLESS = 1,
    SPLICED_ENDLESS = 2,
    DAILY = 3,
    CHALLENGE = 4
}

local BIOME_ID = {
    TOWN = 0,
    PLAINS = 1,
    GRASS = 2,
    TALL_GRASS = 3,
    METROPOLIS = 4,
    FOREST = 5,
    SEA = 6,
    SWAMP = 7,
    BEACH = 8,
    LAKE = 9,
    SEABED = 10,
    MOUNTAIN = 11,
    BADLANDS = 12,
    CAVE = 13,
    DESERT = 14,
    ICE_CAVE = 15,
    MEADOW = 16,
    POWER_PLANT = 17,
    VOLCANO = 18,
    GRAVEYARD = 19,
    DOJO = 20,
    FACTORY = 21,
    RUINS = 22,
    WASTELAND = 23,
    ABYSS = 24,
    SPACE = 25,
    CONSTRUCTION_SITE = 26,
    JUNGLE = 27,
    FAIRY_CAVE = 28,
    TEMPLE = 29,
    SLUM = 30,
    SNOWY_FOREST = 31,
    ISLAND = 32,
    LABORATORY = 33,
    END = 34
}

local SPECIES_ID = {
    ETERNATUS = 890,
    ARCEUS = 493
}

local CHALLENGES = {
    SINGLE_GENERATION = 0,
    SINGLE_TYPE = 1,
    LOWER_MAX_STARTER_COST = 2,
    LOWER_STARTER_POINTS = 3,
    FRESH_START = 4,
    INVERSE_BATTLE = 5,
    FLIP_STAT = 6,
    LIMITED_CATCH = 7,
    LIMITED_SUPPORT = 8,
    HARDCORE = 9
}

-- Classic Fixed Battles Configuration
-- [Source: src/data/trainers/fixed-battle-configs.ts]
local CLASSIC_FIXED_BATTLES = {
    [5] = {battleType = "TRAINER", trainerType = "YOUNGSTER"},
    [8] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [25] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [42] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [55] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [62] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [64] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [66] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [95] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [112] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [114] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [115] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [145] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [165] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [182] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [184] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [186] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [188] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [190] = {battleType = "TRAINER", trainerType = "RIVAL"},
    [195] = {battleType = "TRAINER", trainerType = "RIVAL"}
}

-- Mystery Encounter Wave Ranges
local CLASSIC_MODE_MYSTERY_ENCOUNTER_WAVES = {10, 180}
local CHALLENGE_MODE_MYSTERY_ENCOUNTER_WAVES = {10, 180}

-- =======================
-- GAME MODE FACTORY FUNCTIONS
-- =======================

local function createClassicMode()
    return {
        modeId = GAME_MODES.CLASSIC,
        isClassic = true,
        isEndless = false,
        isDaily = false,
        hasTrainers = true,
        hasNoShop = false,
        hasShortBiomes = false,
        hasRandomBiomes = false,
        hasRandomBosses = false,
        isSplicedOnly = false,
        isChallenge = false,
        challenges = {},
        battleConfig = CLASSIC_FIXED_BATTLES,
        hasMysteryEncounters = true,
        minMysteryEncounterWave = CLASSIC_MODE_MYSTERY_ENCOUNTER_WAVES[1],
        maxMysteryEncounterWave = CLASSIC_MODE_MYSTERY_ENCOUNTER_WAVES[2]
    }
end

local function createEndlessMode()
    return {
        modeId = GAME_MODES.ENDLESS,
        isClassic = false,
        isEndless = true,
        isDaily = false,
        hasTrainers = false,
        hasNoShop = false,
        hasShortBiomes = true,
        hasRandomBiomes = false,
        hasRandomBosses = true,
        isSplicedOnly = false,
        isChallenge = false,
        challenges = {},
        battleConfig = {},
        hasMysteryEncounters = false,
        minMysteryEncounterWave = 0,
        maxMysteryEncounterWave = 0
    }
end

local function createSplicedEndlessMode()
    return {
        modeId = GAME_MODES.SPLICED_ENDLESS,
        isClassic = false,
        isEndless = true,
        isDaily = false,
        hasTrainers = false,
        hasNoShop = false,
        hasShortBiomes = true,
        hasRandomBiomes = false,
        hasRandomBosses = true,
        isSplicedOnly = true,
        isChallenge = false,
        challenges = {},
        battleConfig = {},
        hasMysteryEncounters = false,
        minMysteryEncounterWave = 0,
        maxMysteryEncounterWave = 0
    }
end

local function createDailyMode()
    return {
        modeId = GAME_MODES.DAILY,
        isClassic = false,
        isEndless = false,
        isDaily = true,
        hasTrainers = true,
        hasNoShop = true,
        hasShortBiomes = false,
        hasRandomBiomes = false,
        hasRandomBosses = false,
        isSplicedOnly = false,
        isChallenge = false,
        challenges = {},
        battleConfig = {},
        hasMysteryEncounters = false,
        minMysteryEncounterWave = 0,
        maxMysteryEncounterWave = 0
    }
end

local function copyChallenge(challenge)
    return {
        id = challenge.id,
        value = challenge.value,
        severity = challenge.severity
    }
end

local function getAllChallenges()
    return {
        {id = CHALLENGES.SINGLE_GENERATION, value = 0, severity = 0},
        {id = CHALLENGES.SINGLE_TYPE, value = 0, severity = 0},
        {id = CHALLENGES.LOWER_MAX_STARTER_COST, value = 0, severity = 0},
        {id = CHALLENGES.LOWER_STARTER_POINTS, value = 0, severity = 0},
        {id = CHALLENGES.FRESH_START, value = 0, severity = 0},
        {id = CHALLENGES.INVERSE_BATTLE, value = 0, severity = 0},
        {id = CHALLENGES.FLIP_STAT, value = 0, severity = 0},
        {id = CHALLENGES.LIMITED_CATCH, value = 0, severity = 0},
        {id = CHALLENGES.LIMITED_SUPPORT, value = 0, severity = 0},
        {id = CHALLENGES.HARDCORE, value = 0, severity = 0}
    }
end

local function createChallengeMode()
    local challenges = getAllChallenges()
    return {
        modeId = GAME_MODES.CHALLENGE,
        isClassic = true,
        isEndless = false,
        isDaily = false,
        hasTrainers = true,
        hasNoShop = false,
        hasShortBiomes = false,
        hasRandomBiomes = false,
        hasRandomBosses = false,
        isSplicedOnly = false,
        isChallenge = true,
        challenges = challenges,
        battleConfig = CLASSIC_FIXED_BATTLES,
        hasMysteryEncounters = true,
        minMysteryEncounterWave = CHALLENGE_MODE_MYSTERY_ENCOUNTER_WAVES[1],
        maxMysteryEncounterWave = CHALLENGE_MODE_MYSTERY_ENCOUNTER_WAVES[2]
    }
end

-- Factory dispatcher
local function getGameMode(modeId)
    if modeId == GAME_MODES.CLASSIC then
        return createClassicMode()
    elseif modeId == GAME_MODES.ENDLESS then
        return createEndlessMode()
    elseif modeId == GAME_MODES.SPLICED_ENDLESS then
        return createSplicedEndlessMode()
    elseif modeId == GAME_MODES.DAILY then
        return createDailyMode()
    elseif modeId == GAME_MODES.CHALLENGE then
        return createChallengeMode()
    else
        return nil
    end
end

-- =======================
-- GAME MODE METHODS
-- =======================

-- Challenge Integration Methods
local function setChallengeValue(gameMode, challengeId, value)
    if not gameMode.isChallenge then
        gameMode.isChallenge = true
        gameMode.challenges = getAllChallenges()
    end

    for _, challenge in ipairs(gameMode.challenges) do
        if challenge.id == challengeId then
            challenge.value = value
            break
        end
    end
end

local function hasChallenge(gameMode, challengeId)
    if not gameMode.isChallenge or not gameMode.challenges then
        return false
    end

    for _, challenge in ipairs(gameMode.challenges) do
        if challenge.id == challengeId and challenge.value ~= 0 then
            return true
        end
    end

    return false
end

local function hasAnyChallenges(gameMode)
    if not gameMode.isChallenge or not gameMode.challenges then
        return false
    end

    for _, challenge in ipairs(gameMode.challenges) do
        if challenge.value ~= 0 then
            return true
        end
    end

    return false
end

local function isFreshStartChallenge(gameMode)
    return hasChallenge(gameMode, CHALLENGES.FRESH_START)
end

local function isFullFreshStartChallenge(gameMode)
    if not gameMode.isChallenge or not gameMode.challenges then
        return false
    end

    for _, challenge in ipairs(gameMode.challenges) do
        if challenge.id == CHALLENGES.FRESH_START and challenge.value == 1 then
            return true
        end
    end

    return false
end

-- Wave Classification Methods
local function isWaveFinal(gameMode, waveIndex)
    if gameMode.modeId == GAME_MODES.CLASSIC or gameMode.modeId == GAME_MODES.CHALLENGE then
        return waveIndex == 200
    elseif gameMode.modeId == GAME_MODES.ENDLESS or gameMode.modeId == GAME_MODES.SPLICED_ENDLESS then
        return waveIndex % 250 == 0
    elseif gameMode.modeId == GAME_MODES.DAILY then
        return waveIndex == 50
    end
    return false
end

local function isBoss(waveIndex)
    return waveIndex % 10 == 0
end

local function isEndlessBoss(gameMode, waveIndex)
    return (gameMode.modeId == GAME_MODES.ENDLESS or gameMode.modeId == GAME_MODES.SPLICED_ENDLESS) and waveIndex % 50 == 0
end

local function isEndlessMinorBoss(gameMode, waveIndex)
    return (gameMode.modeId == GAME_MODES.ENDLESS or gameMode.modeId == GAME_MODES.SPLICED_ENDLESS) and waveIndex % 250 == 0
end

local function isEndlessMajorBoss(gameMode, waveIndex)
    return (gameMode.modeId == GAME_MODES.ENDLESS or gameMode.modeId == GAME_MODES.SPLICED_ENDLESS) and waveIndex % 1000 == 0
end

local function isBattleClassicFinalBoss(gameMode, waveIndex)
    return (gameMode.modeId == GAME_MODES.CLASSIC or gameMode.modeId == GAME_MODES.CHALLENGE) and isWaveFinal(gameMode, waveIndex)
end

-- Seeded random integer: returns value in range [0, max)
local function seededRandInt(max, seed)
    -- Simple LCG implementation for deterministic randomness
    local a = 1664525
    local c = 1013904223
    local m = 2^32
    local seedNum = seed or 12345  -- Default seed if not provided
    local next = (a * seedNum + c) % m
    return math.floor((next / m) * max)
end

local function checkNearbyWavesForConflicts(waveIndex, arenaData)
    -- Check if nearby waves have fixed battles or other trainers
    -- This is a simplified version - full implementation would check:
    -- - Fixed battles at waveIndex - 1, waveIndex - 2, waveIndex + 1, waveIndex + 2
    -- - Other trainer battles in nearby waves
    -- For now, return true to allow trainer battles
    return true
end

local function isWaveTrainer(gameMode, waveIndex, arenaData)
    if gameMode.isDaily then
        -- Daily: 5, 15, 20, 25, 30, 35, 40, 45
        return waveIndex % 10 == 5 or (waveIndex % 10 == 0 and waveIndex > 10 and not isWaveFinal(gameMode, waveIndex))
    end

    local offsetGym = arenaData and arenaData.offsetGym or false
    if waveIndex % 30 == (offsetGym and 0 or 20) and not isWaveFinal(gameMode, waveIndex) then
        return true
    end

    -- Probabilistic generic trainer logic
    if waveIndex % 10 ~= 1 and waveIndex % 10 ~= 0 then
        local trainerChance = arenaData and arenaData.trainerChance or 0
        if trainerChance and trainerChance > 0 then
            local allowTrainerBattle = checkNearbyWavesForConflicts(waveIndex, arenaData)
            local rngSeed = arenaData and arenaData.seed or waveIndex
            return allowTrainerBattle and seededRandInt(trainerChance, rngSeed) == 0
        end
    end

    return false
end

local function isTrainerBoss(gameMode, waveIndex, biomeType, offsetGym)
    if gameMode.modeId == GAME_MODES.DAILY then
        -- Daily: Waves 20, 30, 40 (not 10 or 50)
        return waveIndex > 10 and waveIndex < 50 and waveIndex % 10 == 0
    else
        -- Classic/Challenge: Gym leaders
        local gymWave = offsetGym and 0 or 20
        return waveIndex % 30 == gymWave and (biomeType ~= BIOME_ID.END or gameMode.isClassic or isWaveFinal(gameMode, waveIndex))
    end
end

local function getWaveForDifficulty(gameMode, waveIndex, ignoreCurveChanges)
    if gameMode.modeId == GAME_MODES.DAILY then
        -- Daily: waveIndex + 30 + floor(waveIndex / 5)
        local curveAdjustment = ignoreCurveChanges and 0 or math.floor(waveIndex / 5)
        return waveIndex + 30 + curveAdjustment
    else
        -- All other modes: no modification
        return waveIndex
    end
end

local function isFixedBattle(gameMode, waveIndex)
    -- Check battleConfig first
    if gameMode.battleConfig[waveIndex] then
        return true
    end

    -- Check challenge-based fixed battles
    -- For now, simplified - full implementation would call applyChallenges
    if gameMode.isChallenge then
        -- Challenge-based fixed battles would be determined here
        return false
    end

    return false
end

local function getFixedBattle(gameMode, waveIndex)
    -- Challenge-based config takes priority (if implemented)
    if gameMode.isChallenge then
        -- Challenge-based fixed battle logic would go here
    end

    -- Return battleConfig entry
    return gameMode.battleConfig[waveIndex] or nil
end

-- Mode Parameters Methods
local function getStartingLevel(gameMode)
    if gameMode.modeId == GAME_MODES.DAILY then
        return 20
    else
        return 5
    end
end

local function getStartingMoney()
    return 1000
end

local function getDailyStartingBiome(seed)
    -- Simplified: In real implementation, this would use seed to select biome
    -- For now, return PLAINS as default daily biome
    return BIOME_ID.PLAINS
end

local function getStartingBiome(gameMode, seed)
    if gameMode.modeId == GAME_MODES.DAILY then
        return getDailyStartingBiome(seed)
    else
        return BIOME_ID.TOWN
    end
end

local function getMysteryEncounterWaves(gameMode)
    if gameMode.modeId == GAME_MODES.CLASSIC or gameMode.modeId == GAME_MODES.CHALLENGE then
        return {gameMode.minMysteryEncounterWave, gameMode.maxMysteryEncounterWave}
    else
        return {0, 0}
    end
end

-- Reward Methods
local function getClearScoreBonus(gameMode)
    if gameMode.modeId == GAME_MODES.CLASSIC or gameMode.modeId == GAME_MODES.CHALLENGE then
        return 5000
    elseif gameMode.modeId == GAME_MODES.DAILY then
        return 2500
    else
        return 0
    end
end

local function getEnemyModifierChance(gameMode, isBoss)
    if gameMode.modeId == GAME_MODES.ENDLESS or gameMode.modeId == GAME_MODES.SPLICED_ENDLESS then
        return isBoss and 4 or 12
    else
        -- CLASSIC, CHALLENGE, DAILY
        return isBoss and 6 or 18
    end
end

-- Daily run event seed boss lookup (simplified)
local function getDailyEventSeedBoss(seed)
    -- This would parse event seeds and return boss if found
    -- For now, return nil (no event boss)
    return nil
end

local function getOverrideSpecies(gameMode, waveIndex, seed)
    if gameMode.isDaily and isWaveFinal(gameMode, waveIndex) then
        -- Check for event seed boss
        local eventBoss = getDailyEventSeedBoss(seed)
        if eventBoss then
            return {speciesId = eventBoss.speciesId}
        end

        -- Fallback: Return a placeholder legendary species
        -- Full implementation would filter all species with:
        -- (subLegendary || legendary || mythical) && baseTotal >= 600
        -- && speciesId != ETERNATUS && speciesId != ARCEUS
        return {speciesId = 150}  -- Mewtwo as default legendary
    end

    return nil
end

-- Shop Status with Challenge Override
local function getShopStatus(gameMode)
    local status = not gameMode.hasNoShop

    -- Apply challenge overrides (LIMITED_SUPPORT disables shop)
    if gameMode.isChallenge and hasChallenge(gameMode, CHALLENGES.LIMITED_SUPPORT) then
        status = false
    end

    return status
end

-- =======================
-- HELPER FUNCTIONS FOR JSON SERIALIZATION
-- =======================

-- Convert gameMode to JSON-safe format
-- Handles sparse battleConfig arrays that can't be JSON encoded
local function toJsonSafeGameMode(gameMode)
    if not gameMode then
        return nil
    end

    -- Convert battleConfig sparse array to dense array
    local battleConfigArray = {}
    if gameMode.battleConfig then
        for waveIndex, battleData in pairs(gameMode.battleConfig) do
            table.insert(battleConfigArray, {
                waveIndex = waveIndex,
                battleType = battleData.battleType,
                trainerType = battleData.trainerType
            })
        end
    end

    return {
        modeId = gameMode.modeId,
        isClassic = gameMode.isClassic,
        isEndless = gameMode.isEndless,
        isDaily = gameMode.isDaily,
        hasTrainers = gameMode.hasTrainers,
        hasNoShop = gameMode.hasNoShop,
        hasShortBiomes = gameMode.hasShortBiomes,
        hasRandomBiomes = gameMode.hasRandomBiomes,
        hasRandomBosses = gameMode.hasRandomBosses,
        isSplicedOnly = gameMode.isSplicedOnly,
        isChallenge = gameMode.isChallenge,
        challenges = gameMode.challenges or {},
        battleConfig = battleConfigArray,
        hasMysteryEncounters = gameMode.hasMysteryEncounters,
        minMysteryEncounterWave = gameMode.minMysteryEncounterWave,
        maxMysteryEncounterWave = gameMode.maxMysteryEncounterWave
    }
end

-- =======================
-- MESSAGE HANDLERS
-- =======================

-- Handler: CreateGameMode
Handlers.add("create-game-mode",
    Handlers.utils.hasMatchingTag("Action", "CreateGameMode"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        if not modeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId required"
            })
            return
        end

        if modeId < 0 or modeId > 4 then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId must be in range [0-4]"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Failed to create game mode"
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(toJsonSafeGameMode(gameMode))
        })
    end
)

-- Handler: GetGameModeInfo
Handlers.add("get-game-mode-info",
    Handlers.utils.hasMatchingTag("Action", "GetGameModeInfo"),
    function(msg)
        local modeId = msg.ModeId and tonumber(msg.ModeId) or nil

        if modeId then
            -- Return single mode info
            if modeId < 0 or modeId > 4 then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "ModeId must be in range [0-4]"
                })
                return
            end

            local gameMode = getGameMode(modeId)
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(toJsonSafeGameMode(gameMode))
            })
        else
            -- Return all mode info
            local allModes = {
                toJsonSafeGameMode(getGameMode(GAME_MODES.CLASSIC)),
                toJsonSafeGameMode(getGameMode(GAME_MODES.ENDLESS)),
                toJsonSafeGameMode(getGameMode(GAME_MODES.SPLICED_ENDLESS)),
                toJsonSafeGameMode(getGameMode(GAME_MODES.DAILY)),
                toJsonSafeGameMode(getGameMode(GAME_MODES.CHALLENGE))
            }

            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(allModes)
            })
        end
    end
)

-- Handler: SetChallengeValue
Handlers.add("set-challenge-value",
    Handlers.utils.hasMatchingTag("Action", "SetChallengeValue"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local challengeId = tonumber(msg.ChallengeId)
        local value = tonumber(msg.Value)

        if not modeId or not challengeId or not value then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId, ChallengeId, and Value required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        setChallengeValue(gameMode, challengeId, value)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(gameMode)
        })
    end
)

-- Handler: IsWaveTrainer
Handlers.add("is-wave-trainer",
    Handlers.utils.hasMatchingTag("Action", "IsWaveTrainer"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local waveIndex = tonumber(msg.WaveIndex)

        if not modeId or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId and WaveIndex required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local arenaData = msg.Data and json.decode(msg.Data) or {}
        local result = isWaveTrainer(gameMode, waveIndex, arenaData)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            IsWaveTrainer = tostring(result)
        })
    end
)

-- Handler: IsWaveFinal
Handlers.add("is-wave-final",
    Handlers.utils.hasMatchingTag("Action", "IsWaveFinal"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local waveIndex = tonumber(msg.WaveIndex)

        if not modeId or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId and WaveIndex required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local result = isWaveFinal(gameMode, waveIndex)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            IsWaveFinal = tostring(result)
        })
    end
)

-- Handler: GetStartingParameters
Handlers.add("get-starting-parameters",
    Handlers.utils.hasMatchingTag("Action", "GetStartingParameters"),
    function(msg)
        local modeId = tonumber(msg.ModeId)

        if not modeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local seed = msg.Seed or "default-seed"
        local startingLevel = getStartingLevel(gameMode)
        local startingMoney = getStartingMoney()
        local startingBiome = getStartingBiome(gameMode, seed)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            StartingLevel = tostring(startingLevel),
            StartingMoney = tostring(startingMoney),
            StartingBiome = tostring(startingBiome)
        })
    end
)

-- Handler: GetWaveClassification
Handlers.add("get-wave-classification",
    Handlers.utils.hasMatchingTag("Action", "GetWaveClassification"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local waveIndex = tonumber(msg.WaveIndex)
        local biomeType = tonumber(msg.BiomeType or "0")
        local offsetGym = msg.OffsetGym == "true"

        if not modeId or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId and WaveIndex required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local resultIsBoss = isBoss(waveIndex)
        local resultIsTrainerBoss = isTrainerBoss(gameMode, waveIndex, biomeType, offsetGym)
        local resultIsEndlessBoss = isEndlessBoss(gameMode, waveIndex)
        local resultIsEndlessMinorBoss = isEndlessMinorBoss(gameMode, waveIndex)
        local resultIsEndlessMajorBoss = isEndlessMajorBoss(gameMode, waveIndex)
        local resultIsFinalBoss = isBattleClassicFinalBoss(gameMode, waveIndex)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            IsBoss = tostring(resultIsBoss),
            IsTrainerBoss = tostring(resultIsTrainerBoss),
            IsEndlessBoss = tostring(resultIsEndlessBoss),
            IsEndlessMinorBoss = tostring(resultIsEndlessMinorBoss),
            IsEndlessMajorBoss = tostring(resultIsEndlessMajorBoss),
            IsFinalBoss = tostring(resultIsFinalBoss)
        })
    end
)

-- Handler: GetFixedBattleConfig
Handlers.add("get-fixed-battle-config",
    Handlers.utils.hasMatchingTag("Action", "GetFixedBattleConfig"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local waveIndex = tonumber(msg.WaveIndex)

        if not modeId or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId and WaveIndex required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        if not isFixedBattle(gameMode, waveIndex) then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                HasFixedBattle = "false"
            })
            return
        end

        local config = getFixedBattle(gameMode, waveIndex)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            HasFixedBattle = "true",
            Data = json.encode(config)
        })
    end
)

-- Handler: GetModeRewards
Handlers.add("get-mode-rewards",
    Handlers.utils.hasMatchingTag("Action", "GetModeRewards"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local isBoss = msg.IsBoss == "true"

        if not modeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local clearScoreBonus = getClearScoreBonus(gameMode)
        local enemyModifierChance = getEnemyModifierChance(gameMode, isBoss)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            ClearScoreBonus = tostring(clearScoreBonus),
            EnemyModifierChance = tostring(enemyModifierChance)
        })
    end
)

-- Handler: GetOverrideSpecies
Handlers.add("get-override-species",
    Handlers.utils.hasMatchingTag("Action", "GetOverrideSpecies"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local waveIndex = tonumber(msg.WaveIndex)
        local seed = msg.Seed or "default-seed"

        if not modeId or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId and WaveIndex required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local species = getOverrideSpecies(gameMode, waveIndex, seed)

        if species then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                HasOverride = "true",
                Data = json.encode(species)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                HasOverride = "false"
            })
        end
    end
)

-- Handler: GetWaveForDifficulty
Handlers.add("get-wave-for-difficulty",
    Handlers.utils.hasMatchingTag("Action", "GetWaveForDifficulty"),
    function(msg)
        local modeId = tonumber(msg.ModeId)
        local waveIndex = tonumber(msg.WaveIndex)
        local ignoreCurveChanges = msg.IgnoreCurveChanges == "true"

        if not modeId or not waveIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId and WaveIndex required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local effectiveDifficulty = getWaveForDifficulty(gameMode, waveIndex, ignoreCurveChanges)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            EffectiveDifficulty = tostring(effectiveDifficulty)
        })
    end
)

-- Handler: GetShopStatus
Handlers.add("get-shop-status",
    Handlers.utils.hasMatchingTag("Action", "GetShopStatus"),
    function(msg)
        local modeId = tonumber(msg.ModeId)

        if not modeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local shopStatus = getShopStatus(gameMode)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            ShopAvailable = tostring(shopStatus)
        })
    end
)

-- Handler: GetMysteryEncounterWaves
Handlers.add("get-mystery-encounter-waves",
    Handlers.utils.hasMatchingTag("Action", "GetMysteryEncounterWaves"),
    function(msg)
        local modeId = tonumber(msg.ModeId)

        if not modeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ModeId required"
            })
            return
        end

        local gameMode = getGameMode(modeId)
        if not gameMode then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ModeId"
            })
            return
        end

        local waves = getMysteryEncounterWaves(gameMode)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            MinWave = tostring(waves[1]),
            MaxWave = tostring(waves[2])
        })
    end
)

-- Handler: Info (ADP v1.0 Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local processInfo = {
            process = {
                name = "Game Mode Engine",
                version = "1.0.0",
                adpVersion = "1.0",
                processId = ao.id or "game-mode-engine-adp",
                capabilities = {
                    "CreateGameMode",
                    "GetGameModeInfo",
                    "SetChallengeValue",
                    "IsWaveTrainer",
                    "IsWaveFinal",
                    "GetStartingParameters",
                    "GetWaveClassification",
                    "GetFixedBattleConfig",
                    "GetModeRewards",
                    "GetOverrideSpecies",
                    "GetWaveForDifficulty",
                    "GetShopStatus",
                    "GetMysteryEncounterWaves"
                },
                messageSchemas = {
                    CreateGameMode = {
                        required = {"Action", "ModeId"}
                    },
                    GetGameModeInfo = {
                        required = {"Action"},
                        optional = {"ModeId"}
                    },
                    SetChallengeValue = {
                        required = {"Action", "ModeId", "ChallengeId", "Value"}
                    },
                    IsWaveTrainer = {
                        required = {"Action", "ModeId", "WaveIndex"},
                        optional = {"Data"}
                    },
                    IsWaveFinal = {
                        required = {"Action", "ModeId", "WaveIndex"}
                    },
                    GetStartingParameters = {
                        required = {"Action", "ModeId"},
                        optional = {"Seed"}
                    },
                    GetWaveClassification = {
                        required = {"Action", "ModeId", "WaveIndex"},
                        optional = {"BiomeType", "OffsetGym"}
                    },
                    GetFixedBattleConfig = {
                        required = {"Action", "ModeId", "WaveIndex"}
                    },
                    GetModeRewards = {
                        required = {"Action", "ModeId"},
                        optional = {"IsBoss"}
                    },
                    GetOverrideSpecies = {
                        required = {"Action", "ModeId", "WaveIndex"},
                        optional = {"Seed"}
                    },
                    GetWaveForDifficulty = {
                        required = {"Action", "ModeId", "WaveIndex"},
                        optional = {"IgnoreCurveChanges"}
                    },
                    GetShopStatus = {
                        required = {"Action", "ModeId"}
                    },
                    GetMysteryEncounterWaves = {
                        required = {"Action", "ModeId"}
                    }
                }
            },
            handlers = {
                "CreateGameMode",
                "GetGameModeInfo",
                "SetChallengeValue",
                "IsWaveTrainer",
                "IsWaveFinal",
                "GetStartingParameters",
                "GetWaveClassification",
                "GetFixedBattleConfig",
                "GetModeRewards",
                "GetOverrideSpecies",
                "GetWaveForDifficulty",
                "GetShopStatus",
                "GetMysteryEncounterWaves",
                "Info"
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true
            }
        }

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(processInfo)
        })
    end
)

print("Game Mode Engine Process initialized successfully.")
