-- Challenge Framework Engine Process
-- Implements PokéRogue challenge system for AO platform
-- ADP v1.0 Compliant

local json = require("json")

-- ============================================================================
-- CONSTANTS & ENUMS
-- ============================================================================

-- Challenge Type Enumeration (matches TypeScript Challenges enum)
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

-- Default party max cost constant
local DEFAULT_PARTY_MAX_COST = 10

-- Ribbon data flags (using Lua numbers instead of BigInt)
local RIBBON_DATA = {
    MONO_GEN_1 = 1,
    MONO_NORMAL = 1024,  -- Starting position for type ribbons
    FRESH_START = 2048,
    INVERSE = 4096,
    FLIP_STATS = 8192,
    LIMITED_CATCH = 16384,
    NO_HEAL = 32768,
    HARDCORE = 65536
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Create BooleanHolder table for pass-by-reference modification
local function createBooleanHolder(value)
    return {value = value}
end

-- Create NumberHolder table for pass-by-reference modification
local function createNumberHolder(value)
    return {value = value}
end

-- Deep copy utility for tables
local function deepCopy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do
        res[k] = deepCopy(v)
    end
    return res
end

-- ============================================================================
-- BASE CHALLENGE FACTORY
-- ============================================================================

local function createBaseChallenge(id, maxValue, maxSeverity)
    local challenge = {
        id = id,
        value = 0,
        maxValue = maxValue or 9999999,
        severity = 0,
        maxSeverity = maxSeverity or 0,
        conditions = {}
    }

    -- Reset challenge to base state
    function challenge:reset()
        self.value = 0
        self.severity = 0
    end

    -- Check if challenge is unlocked
    function challenge:isUnlocked(gameData)
        for _, conditionFn in ipairs(self.conditions) do
            if not conditionFn(gameData) then
                return false
            end
        end
        return true
    end

    -- Add unlock condition (chainable)
    function challenge:addCondition(conditionFn)
        table.insert(self.conditions, conditionFn)
        return self
    end

    -- Increase value
    function challenge:increaseValue()
        if self.value < self.maxValue then
            self.value = math.min(self.value + 1, self.maxValue)
            return true
        end
        return false
    end

    -- Decrease value
    function challenge:decreaseValue()
        if self.value > 0 then
            self.value = math.max(self.value - 1, 0)
            return true
        end
        return false
    end

    -- Check if severity is available
    function challenge:hasSeverity()
        return self.value ~= 0 and self.maxSeverity > 0
    end

    -- Increase severity
    function challenge:increaseSeverity()
        if self.severity < self.maxSeverity then
            self.severity = math.min(self.severity + 1, self.maxSeverity)
            return true
        end
        return false
    end

    -- Decrease severity
    function challenge:decreaseSeverity()
        if self.severity > 0 then
            self.severity = math.max(self.severity - 1, 0)
            return true
        end
        return false
    end

    -- Get difficulty value
    function challenge:getDifficulty()
        return self.value
    end

    -- Get minimum difficulty
    function challenge:getMinDifficulty()
        return 0
    end

    -- Get ribbon awarded (default implementation)
    function challenge:getRibbonAwarded()
        return 0
    end

    -- Hook methods (default no-op implementations)
    function challenge:applyStarterChoice(pokemon, valid, dexAttr)
        return false
    end

    function challenge:applyStarterPoints(points)
        return false
    end

    function challenge:applyStarterCost(speciesId, cost)
        return false
    end

    function challenge:applyStarterSelectModify(speciesId, dexEntry, starterDataEntry)
        return false
    end

    function challenge:applyStarterModify(pokemon)
        return false
    end

    function challenge:applyPokemonInBattle(pokemon, valid)
        return false
    end

    function challenge:applyFixedBattle(waveIndex, battleConfig)
        return false
    end

    function challenge:applyTypeEffectiveness(effectiveness)
        return false
    end

    function challenge:applyLevelChange(level, levelCap, isTrainer, isBoss)
        return false
    end

    function challenge:applyMoveSlot(pokemon, moveSlots)
        return false
    end

    function challenge:applyPassiveAccess(pokemon, hasPassive)
        return false
    end

    function challenge:applyGameModeModify()
        return false
    end

    function challenge:applyMoveAccessLevel(pokemon, moveSource, move, level)
        return false
    end

    function challenge:applyMoveWeight(pokemon, moveSource, move, weight)
        return false
    end

    function challenge:applyFlipStat(pokemon, baseStats)
        return false
    end

    function challenge:applyPartyHeal(status)
        return false
    end

    function challenge:applyShop(status)
        return false
    end

    function challenge:applyPokemonAddToParty(pokemon, status)
        return false
    end

    function challenge:applyPokemonFusion(pokemon, status)
        return false
    end

    function challenge:applyPokemonMove(moveId, status)
        return false
    end

    function challenge:applyShopItem(shopItem, status)
        return false
    end

    function challenge:applyWaveReward(reward, status)
        return false
    end

    function challenge:applyPreventRevive(status)
        return false
    end

    return challenge
end

-- ============================================================================
-- CHALLENGE TYPE FACTORY FUNCTIONS
-- ============================================================================

-- SINGLE_GENERATION Challenge
local function createSingleGenerationChallenge()
    local challenge = createBaseChallenge(CHALLENGES.SINGLE_GENERATION, 9, 0)

    function challenge:getRibbonAwarded()
        if self.value > 0 then
            -- Bitshift logic: MONO_GEN_1 << (value - 1)
            return RIBBON_DATA.MONO_GEN_1 * (2 ^ (self.value - 1))
        end
        return 0
    end

    function challenge:applyStarterChoice(pokemon, valid, dexAttr)
        if pokemon.generation ~= self.value then
            valid.value = false
            return true
        end
        return false
    end

    function challenge:applyPokemonInBattle(pokemon, valid)
        if pokemon.isPlayer and pokemon.generation ~= self.value then
            valid.value = false
            return true
        end
        -- Check fusion generation if applicable
        if pokemon.isFusion and pokemon.fusionGeneration and pokemon.fusionGeneration ~= self.value then
            valid.value = false
            return true
        end
        return false
    end

    function challenge:getDifficulty()
        return self.value > 0 and 1 or 0
    end

    return challenge
end

-- SINGLE_TYPE Challenge
local function createSingleTypeChallenge()
    local challenge = createBaseChallenge(CHALLENGES.SINGLE_TYPE, 18, 0)

    function challenge:getRibbonAwarded()
        if self.value > 0 then
            -- Bitshift logic: MONO_NORMAL << (value - 1)
            return RIBBON_DATA.MONO_NORMAL * (2 ^ (self.value - 1))
        end
        return 0
    end

    function challenge:applyStarterChoice(pokemon, valid, dexAttr)
        local types = {pokemon.type1, pokemon.type2}
        local hasType = false
        for _, pokemonType in ipairs(types) do
            if pokemonType == self.value - 1 then
                hasType = true
                break
            end
        end
        if not hasType then
            valid.value = false
            return true
        end
        return false
    end

    function challenge:applyPokemonInBattle(pokemon, valid)
        if pokemon.isPlayer then
            local hasType = false
            if pokemon.type1 == self.value - 1 or pokemon.type2 == self.value - 1 then
                hasType = true
            end
            if not hasType then
                valid.value = false
                return true
            end
        end
        return false
    end

    return challenge
end

-- FRESH_START Challenge
local function createFreshStartChallenge()
    local challenge = createBaseChallenge(CHALLENGES.FRESH_START, 2, 0)

    function challenge:getRibbonAwarded()
        return self.value > 0 and RIBBON_DATA.FRESH_START or 0
    end

    function challenge:applyStarterSelectModify(speciesId, dexEntry, starterDataEntry)
        -- Implementation simplified - full logic requires complex dex attribute manipulation
        return true
    end

    function challenge:getDifficulty()
        return 0
    end

    return challenge
end

-- INVERSE_BATTLE Challenge
local function createInverseBattleChallenge()
    local challenge = createBaseChallenge(CHALLENGES.INVERSE_BATTLE, 1, 0)

    function challenge:getRibbonAwarded()
        return self.value > 0 and RIBBON_DATA.INVERSE or 0
    end

    function challenge:applyTypeEffectiveness(effectiveness)
        if effectiveness.value < 1 then
            effectiveness.value = 2.0
            return true
        end
        if effectiveness.value > 1 then
            effectiveness.value = 0.5
            return true
        end
        return false
    end

    function challenge:getDifficulty()
        return 0
    end

    return challenge
end

-- FLIP_STAT Challenge
local function createFlipStatChallenge()
    local challenge = createBaseChallenge(CHALLENGES.FLIP_STAT, 1, 0)

    function challenge:getRibbonAwarded()
        return self.value > 0 and RIBBON_DATA.FLIP_STATS or 0
    end

    function challenge:applyFlipStat(pokemon, baseStats)
        -- Flip stats: HP, ATK, DEF, SPATK, SPDEF, SPD -> SPD, SPDEF, SPATK, DEF, ATK, HP
        local origStats = deepCopy(baseStats)
        baseStats[1] = origStats[6]  -- HP = SPD
        baseStats[2] = origStats[5]  -- ATK = SPDEF
        baseStats[3] = origStats[4]  -- DEF = SPATK
        baseStats[4] = origStats[3]  -- SPATK = DEF
        baseStats[5] = origStats[2]  -- SPDEF = ATK
        baseStats[6] = origStats[1]  -- SPD = HP
        return true
    end

    return challenge
end

-- LOWER_MAX_STARTER_COST Challenge
local function createLowerMaxStarterCostChallenge()
    local challenge = createBaseChallenge(CHALLENGES.LOWER_MAX_STARTER_COST, 9, 0)

    function challenge:applyStarterChoice(pokemon, valid, dexAttr)
        local starterCost = pokemon.starterCost or 0
        if starterCost > DEFAULT_PARTY_MAX_COST - self.value then
            valid.value = false
            return true
        end
        return false
    end

    return challenge
end

-- LOWER_STARTER_POINTS Challenge
local function createLowerStarterPointsChallenge()
    local challenge = createBaseChallenge(CHALLENGES.LOWER_STARTER_POINTS, 9, 0)

    function challenge:applyStarterPoints(points)
        points.value = points.value - self.value
        return true
    end

    return challenge
end

-- LIMITED_CATCH Challenge
local function createLimitedCatchChallenge()
    local challenge = createBaseChallenge(CHALLENGES.LIMITED_CATCH, 1, 0)

    function challenge:getRibbonAwarded()
        return self.value > 0 and RIBBON_DATA.LIMITED_CATCH or 0
    end

    function challenge:applyPokemonAddToParty(pokemon, status)
        if status.value then
            -- Only allow catching on waves ending in 1 (metWave % 10 == 1)
            local metWave = pokemon.metWave or 0
            status.value = (metWave % 10 == 1)
            return true
        end
        return false
    end

    return challenge
end

-- LIMITED_SUPPORT Challenge
local function createLimitedSupportChallenge()
    local challenge = createBaseChallenge(CHALLENGES.LIMITED_SUPPORT, 3, 0)

    function challenge:getRibbonAwarded()
        if self.value > 0 then
            return RIBBON_DATA.NO_HEAL * (2 ^ (self.value - 1))
        end
        return 0
    end

    function challenge:applyPartyHeal(status)
        if status.value then
            status.value = (self.value == 2)
            return true
        end
        return false
    end

    function challenge:applyShop(status)
        if status.value then
            status.value = (self.value == 1)
            return true
        end
        return false
    end

    return challenge
end

-- HARDCORE Challenge
local function createHardcoreChallenge()
    local challenge = createBaseChallenge(CHALLENGES.HARDCORE, 1, 0)

    function challenge:getRibbonAwarded()
        return self.value > 0 and RIBBON_DATA.HARDCORE or 0
    end

    function challenge:applyPokemonFusion(pokemon, status)
        if not status.value then
            status.value = (pokemon.isFainted == true)
            return true
        end
        return false
    end

    function challenge:applyShopItem(shopItem, status)
        if shopItem and shopItem.group then
            status.value = (shopItem.group ~= "revive")
        else
            status.value = true
        end
        return true
    end

    function challenge:applyWaveReward(reward, status)
        return self:applyShopItem(reward, status)
    end

    function challenge:applyPokemonMove(moveId, status)
        if status.value then
            -- Block Revival Blessing (MoveId 855)
            status.value = (moveId ~= 855)
            return true
        end
        return false
    end

    function challenge:applyPreventRevive(status)
        if not status.value then
            status.value = true
            return true
        end
        return false
    end

    return challenge
end

-- ============================================================================
-- CHALLENGE REGISTRY
-- ============================================================================

local ALL_CHALLENGES = {}

local function initChallenges()
    ALL_CHALLENGES = {
        createFreshStartChallenge(),
        createHardcoreChallenge(),
        createLimitedCatchChallenge(),
        createLimitedSupportChallenge(),
        createSingleGenerationChallenge(),
        createSingleTypeChallenge(),
        createLowerMaxStarterCostChallenge(),
        createLowerStarterPointsChallenge(),
        createInverseBattleChallenge(),
        createFlipStatChallenge()
    }
end

local function getChallengeById(challengeId)
    for _, challenge in ipairs(ALL_CHALLENGES) do
        if challenge.id == challengeId then
            return challenge
        end
    end
    return nil
end

-- Copy/clone challenge instance
local function copyChallenge(source)
    local challengeId = source.id
    local newChallenge = nil

    if challengeId == CHALLENGES.SINGLE_GENERATION then
        newChallenge = createSingleGenerationChallenge()
    elseif challengeId == CHALLENGES.SINGLE_TYPE then
        newChallenge = createSingleTypeChallenge()
    elseif challengeId == CHALLENGES.FRESH_START then
        newChallenge = createFreshStartChallenge()
    elseif challengeId == CHALLENGES.INVERSE_BATTLE then
        newChallenge = createInverseBattleChallenge()
    elseif challengeId == CHALLENGES.FLIP_STAT then
        newChallenge = createFlipStatChallenge()
    elseif challengeId == CHALLENGES.LOWER_MAX_STARTER_COST then
        newChallenge = createLowerMaxStarterCostChallenge()
    elseif challengeId == CHALLENGES.LOWER_STARTER_POINTS then
        newChallenge = createLowerStarterPointsChallenge()
    elseif challengeId == CHALLENGES.LIMITED_CATCH then
        newChallenge = createLimitedCatchChallenge()
    elseif challengeId == CHALLENGES.LIMITED_SUPPORT then
        newChallenge = createLimitedSupportChallenge()
    elseif challengeId == CHALLENGES.HARDCORE then
        newChallenge = createHardcoreChallenge()
    end

    if newChallenge then
        newChallenge.value = source.value or 0
        newChallenge.severity = source.severity or 0
    end

    return newChallenge
end

-- Initialize challenge registry
initChallenges()

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Handler: CreateChallenge
Handlers.add("create-challenge",
    Handlers.utils.hasMatchingTag("Action", "CreateChallenge"),
    function(msg)
        local challengeId = tonumber(msg.ChallengeId)

        if not challengeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ChallengeId required"
            })
            return
        end

        if challengeId < 0 or challengeId > 9 then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid ChallengeId: must be 0-9"
            })
            return
        end

        local challenge = getChallengeById(challengeId)
        if not challenge then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge type not found"
            })
            return
        end

        -- Clone challenge to create new instance
        local newChallenge = copyChallenge(challenge)

        -- Set initial value and severity if provided
        if msg.Value then
            local value = tonumber(msg.Value)
            if value and value >= 0 and value <= newChallenge.maxValue then
                newChallenge.value = value
            end
        end

        if msg.Severity then
            local severity = tonumber(msg.Severity)
            if severity and severity >= 0 and severity <= newChallenge.maxSeverity then
                newChallenge.severity = severity
            end
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            ChallengeId = tostring(newChallenge.id),
            Value = tostring(newChallenge.value),
            Severity = tostring(newChallenge.severity),
            RibbonAwarded = tostring(newChallenge:getRibbonAwarded())
        })
    end
)

-- Handler: ModifyChallenge
Handlers.add("modify-challenge",
    Handlers.utils.hasMatchingTag("Action", "ModifyChallenge"),
    function(msg)
        local challengeId = tonumber(msg.ChallengeId)
        local operation = msg.Operation

        if not challengeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ChallengeId required"
            })
            return
        end

        if not operation then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Operation required"
            })
            return
        end

        local challenge = getChallengeById(challengeId)
        if not challenge then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge not found"
            })
            return
        end

        local modified = false

        if operation == "IncreaseValue" then
            modified = challenge:increaseValue()
        elseif operation == "DecreaseValue" then
            modified = challenge:decreaseValue()
        elseif operation == "IncreaseSeverity" then
            modified = challenge:increaseSeverity()
        elseif operation == "DecreaseSeverity" then
            modified = challenge:decreaseSeverity()
        elseif operation == "Reset" then
            challenge:reset()
            modified = true
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid operation: " .. operation
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Modified = tostring(modified),
            ChallengeId = tostring(challenge.id),
            Value = tostring(challenge.value),
            Severity = tostring(challenge.severity),
            RibbonAwarded = tostring(challenge:getRibbonAwarded())
        })
    end
)

-- Handler: ValidateChallenge
Handlers.add("validate-challenge",
    Handlers.utils.hasMatchingTag("Action", "ValidateChallenge"),
    function(msg)
        local challengeId = tonumber(msg.ChallengeId)

        if not challengeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ChallengeId required"
            })
            return
        end

        local challenge = getChallengeById(challengeId)
        if not challenge then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge not found"
            })
            return
        end

        local gameData = {}
        if msg.Data and msg.Data ~= "" then
            gameData = json.decode(msg.Data)
        end

        local unlocked = challenge:isUnlocked(gameData)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Unlocked = tostring(unlocked),
            ChallengeId = tostring(challenge.id)
        })
    end
)

-- Handler: GetChallengeInfo
Handlers.add("get-challenge-info",
    Handlers.utils.hasMatchingTag("Action", "GetChallengeInfo"),
    function(msg)
        local challengeId = msg.ChallengeId and tonumber(msg.ChallengeId)

        if challengeId then
            -- Return single challenge info
            local challenge = getChallengeById(challengeId)
            if not challenge then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Challenge not found"
                })
                return
            end

            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode({
                    id = challenge.id,
                    value = challenge.value,
                    maxValue = challenge.maxValue,
                    severity = challenge.severity,
                    maxSeverity = challenge.maxSeverity,
                    ribbonAwarded = challenge:getRibbonAwarded()
                })
            })
        else
            -- Return all challenges info
            local challengesInfo = {}
            for _, challenge in ipairs(ALL_CHALLENGES) do
                table.insert(challengesInfo, {
                    id = challenge.id,
                    value = challenge.value,
                    maxValue = challenge.maxValue,
                    severity = challenge.severity,
                    maxSeverity = challenge.maxSeverity,
                    ribbonAwarded = challenge:getRibbonAwarded()
                })
            end

            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(challengesInfo)
            })
        end
    end
)

-- Handler: ApplyChallengeHook
Handlers.add("apply-challenge-hook",
    Handlers.utils.hasMatchingTag("Action", "ApplyChallengeHook"),
    function(msg)
        local challengeId = tonumber(msg.ChallengeId)
        local hookName = msg.Hook

        if not challengeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ChallengeId required"
            })
            return
        end

        if not hookName then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Hook name required"
            })
            return
        end

        local challenge = getChallengeById(challengeId)
        if not challenge then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge not found"
            })
            return
        end

        local hookParams = {}
        if msg.Data and msg.Data ~= "" then
            hookParams = json.decode(msg.Data)
        end

        local applied = false
        local resultParams = hookParams

        -- Execute hook method if it exists
        if challenge[hookName] then
            -- Create holders from params
            if hookParams.valid ~= nil then
                local validHolder = createBooleanHolder(hookParams.valid)
                applied = challenge[hookName](challenge, hookParams.pokemon or {}, validHolder)
                resultParams.valid = validHolder.value
            elseif hookParams.points ~= nil then
                local pointsHolder = createNumberHolder(hookParams.points)
                applied = challenge[hookName](challenge, pointsHolder)
                resultParams.points = pointsHolder.value
            elseif hookParams.effectiveness ~= nil then
                local effectivenessHolder = createNumberHolder(hookParams.effectiveness)
                applied = challenge[hookName](challenge, effectivenessHolder)
                resultParams.effectiveness = effectivenessHolder.value
            elseif hookParams.baseStats then
                applied = challenge[hookName](challenge, hookParams.pokemon or {}, hookParams.baseStats)
                resultParams.baseStats = hookParams.baseStats
            else
                applied = challenge[hookName](challenge, hookParams)
            end
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Applied = tostring(applied),
            Data = json.encode(resultParams)
        })
    end
)

-- Handler: SerializeChallenge
Handlers.add("serialize-challenge",
    Handlers.utils.hasMatchingTag("Action", "SerializeChallenge"),
    function(msg)
        local challengeId = tonumber(msg.ChallengeId)

        if not challengeId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ChallengeId required"
            })
            return
        end

        local challenge = getChallengeById(challengeId)
        if not challenge then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge not found"
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                id = challenge.id,
                value = challenge.value,
                severity = challenge.severity
            })
        })
    end
)

-- Handler: DeserializeChallenge
Handlers.add("deserialize-challenge",
    Handlers.utils.hasMatchingTag("Action", "DeserializeChallenge"),
    function(msg)
        if not msg.Data or msg.Data == "" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge data required"
            })
            return
        end

        local challengeData = json.decode(msg.Data)

        if not challengeData.id then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Challenge id required in data"
            })
            return
        end

        local challenge = copyChallenge(challengeData)
        if not challenge then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid challenge data"
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            ChallengeId = tostring(challenge.id),
            Value = tostring(challenge.value),
            Severity = tostring(challenge.severity),
            RibbonAwarded = tostring(challenge:getRibbonAwarded())
        })
    end
)

-- Handler: GetActiveChallenges
Handlers.add("get-active-challenges",
    Handlers.utils.hasMatchingTag("Action", "GetActiveChallenges"),
    function(msg)
        if not msg.Data or msg.Data == "" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "GameState required"
            })
            return
        end

        local gameState = json.decode(msg.Data)
        local activeChallenges = gameState.activeChallenges or {}

        local serializedChallenges = {}
        for _, challengeData in ipairs(activeChallenges) do
            table.insert(serializedChallenges, {
                id = challengeData.id,
                value = challengeData.value,
                severity = challengeData.severity
            })
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(serializedChallenges)
        })
    end
)

-- Handler: Info (ADP v1.0 Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0),
            Data = json.encode({
                process = {
                    name = "Challenge Framework Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    processId = ao.id,
                    capabilities = {
                        "CreateChallenge",
                        "ModifyChallenge",
                        "ValidateChallenge",
                        "GetChallengeInfo",
                        "ApplyChallengeHook",
                        "SerializeChallenge",
                        "DeserializeChallenge",
                        "GetActiveChallenges"
                    },
                    messageSchemas = {
                        CreateChallenge = {
                            required = {"Action", "ChallengeId"},
                            optional = {"Value", "Severity"}
                        },
                        ModifyChallenge = {
                            required = {"Action", "ChallengeId", "Operation"},
                            optional = {"GameState"}
                        },
                        ValidateChallenge = {
                            required = {"Action", "ChallengeId"},
                            optional = {"Data"}
                        },
                        GetChallengeInfo = {
                            required = {"Action"},
                            optional = {"ChallengeId"}
                        },
                        ApplyChallengeHook = {
                            required = {"Action", "ChallengeId", "Hook"},
                            optional = {"Data"}
                        },
                        SerializeChallenge = {
                            required = {"Action", "ChallengeId"}
                        },
                        DeserializeChallenge = {
                            required = {"Action", "Data"}
                        },
                        GetActiveChallenges = {
                            required = {"Action", "Data"}
                        }
                    }
                },
                handlers = {
                    "CreateChallenge",
                    "ModifyChallenge",
                    "ValidateChallenge",
                    "GetChallengeInfo",
                    "ApplyChallengeHook",
                    "SerializeChallenge",
                    "DeserializeChallenge",
                    "GetActiveChallenges",
                    "Info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Challenge Framework Engine for PokéRogue - manages 10 challenge types with 18 hook methods"
                }
            })
        })
    end
)

print("Challenge Framework Engine initialized successfully.")
