-- Encounter Reward Engine Process
-- Handles reward calculation, consequence application, and outcome determination for mystery encounters
-- AO Process - Stateless, embedded data, ADP v1.0 compliant

-- ============================================================================
-- JSON Library (Allowed in AO)
-- ============================================================================
local json = require("json")

-- ============================================================================
-- Mock AO Environment (for testing)
-- ============================================================================
if not ao then
    ao = {
        send = function(msg)
            print("Mock ao.send:", json.encode(msg))
        end,
        id = "encounter_reward_engine_process_id"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    return msg[tagName] == tagValue
                end
            end
        }
    }
end

-- ============================================================================
-- Data Structures and Enumerations
-- ============================================================================

-- Modifier Types (Reward Items)
local ModifierType = {
    POTION = "POTION",
    SUPER_POTION = "SUPER_POTION",
    HYPER_POTION = "HYPER_POTION",
    MAX_POTION = "MAX_POTION",
    FULL_RESTORE = "FULL_RESTORE",
    REVIVE = "REVIVE",
    MAX_REVIVE = "MAX_REVIVE",
    RARE_CANDY = "RARE_CANDY",
    PP_UP = "PP_UP",
    PP_MAX = "PP_MAX",
    MASTER_BALL = "MASTER_BALL",
    SACRED_ASH = "SACRED_ASH",
    PROTEIN = "PROTEIN",
    IRON = "IRON",
    CALCIUM = "CALCIUM",
    ZINC = "ZINC",
    CARBOS = "CARBOS",
    HP_UP = "HP_UP",
    FIRE_STONE = "FIRE_STONE",
    WATER_STONE = "WATER_STONE",
    THUNDER_STONE = "THUNDER_STONE",
    LEAF_STONE = "LEAF_STONE",
    MOON_STONE = "MOON_STONE",
    SUN_STONE = "SUN_STONE"
}

-- Egg Tiers
local EggTier = {
    COMMON = "COMMON",
    RARE = "RARE",
    EPIC = "EPIC",
    LEGENDARY = "LEGENDARY"
}

-- Egg Source Types
local EggSourceType = {
    MYSTERY_ENCOUNTER = "MYSTERY_ENCOUNTER",
    EVENT = "EVENT",
    GACHA = "GACHA"
}

-- Consequence Types
local ConsequenceType = {
    DAMAGE = "DAMAGE",
    STATUS = "STATUS",
    ITEM_LOSS = "ITEM_LOSS",
    MONEY_LOSS = "MONEY_LOSS",
    STAT_REDUCTION = "STAT_REDUCTION",
    PP_REDUCTION = "PP_REDUCTION",
    POKEMON_REMOVAL = "POKEMON_REMOVAL"
}

-- Status Effects
local StatusEffect = {
    POISON = "POISON",
    BURN = "BURN",
    PARALYSIS = "PARALYSIS",
    SLEEP = "SLEEP",
    FREEZE = "FREEZE"
}

-- Rarity Tiers
local RarityTier = {
    COMMON = 1,
    UNCOMMON = 2,
    RARE = 3,
    EPIC = 4,
    LEGENDARY = 5
}

-- ============================================================================
-- Reward Calculation Functions
-- ============================================================================

-- Get guaranteed modifiers for encounter type
local function getGuaranteedModifiers(encounterType)
    -- Placeholder implementation - would be populated with actual encounter-specific rewards
    local guaranteedModifiers = {}

    -- Example reward configurations per encounter type
    if encounterType == "MYSTERIOUS_CHEST" then
        guaranteedModifiers = {ModifierType.RARE_CANDY, ModifierType.MAX_POTION}
    elseif encounterType == "BERRY_HARVEST" then
        guaranteedModifiers = {ModifierType.FULL_RESTORE}
    elseif encounterType == "POKEMON_BREEDER" then
        guaranteedModifiers = {ModifierType.RARE_CANDY}
    end

    return guaranteedModifiers
end

-- Check if encounter has egg reward
local function hasEggReward(encounterType)
    local eggEncounters = {
        "POKEMON_BREEDER",
        "MYSTERIOUS_EGG",
        "DAYCARE_ENCOUNTER"
    }

    for _, encounter in ipairs(eggEncounters) do
        if encounter == encounterType then
            return true
        end
    end

    return false
end

-- Calculate egg rewards for encounter
local function calculateEggRewardsForEncounter(encounterType, outcome)
    local eggRewards = {}

    if not hasEggReward(encounterType) then
        return eggRewards
    end

    local tier = EggTier.COMMON
    local hatchWaves = 10

    if outcome == "success" then
        if encounterType == "MYSTERIOUS_EGG" then
            tier = EggTier.RARE
            hatchWaves = 5
        elseif encounterType == "POKEMON_BREEDER" then
            tier = EggTier.EPIC
            hatchWaves = 15
        end
    elseif outcome == "partial" then
        tier = EggTier.COMMON
        hatchWaves = 20
    end

    table.insert(eggRewards, {
        tier = tier,
        sourceType = EggSourceType.MYSTERY_ENCOUNTER,
        hatchWaves = hatchWaves,
        pulled = false
    })

    return eggRewards
end

-- Main reward calculation function
local function calculateRewards(encounterType, optionIndex, outcome, waveIndex)
    local rewardConfig = {
        customShopRewards = nil,
        eggRewards = nil,
        preRewardsCallback = nil
    }

    -- Determine reward eligibility based on outcome
    if outcome == "success" then
        -- Success rewards: full reward shop
        rewardConfig.customShopRewards = {
            guaranteedModifierTypeFuncs = getGuaranteedModifiers(encounterType),
            guaranteedModifierTiers = {},
            allowLuckUpgrades = true,
            rerollMultiplier = 1
        }
    elseif outcome == "partial" then
        -- Partial success: reduced rewards
        rewardConfig.customShopRewards = {
            guaranteedModifierTypeFuncs = {},
            guaranteedModifierTiers = {"COMMON", "UNCOMMON"},
            allowLuckUpgrades = false,
            rerollMultiplier = 2
        }
    end

    -- Add egg rewards for specific encounters
    if hasEggReward(encounterType) then
        rewardConfig.eggRewards = calculateEggRewardsForEncounter(encounterType, outcome)
    end

    return rewardConfig
end

-- ============================================================================
-- Experience Reward Functions
-- ============================================================================

-- Get base exp value for encounter type or species
local function getBaseExpValue(encounterType, pokemonSpecies)
    -- Base exp value guidelines (from story notes):
    -- 36 - Sunkern (lowest), 62-64 - regional starters, 100 - Scyther
    -- 170 - Spiritomb, 250 - Gengar, 290 - trio legendaries
    -- 340 - box legendaries, 608 - Blissey (highest)

    if pokemonSpecies then
        -- Species-based exp values would go here
        return 100
    end

    -- Encounter-based default values
    local encounterExpValues = {
        MYSTERIOUS_CHEST = 100,
        BERRY_HARVEST = 62,
        POKEMON_BREEDER = 170,
        LEGENDARY_ENCOUNTER = 340,
        CHAMPION_BATTLE = 290
    }

    return encounterExpValues[encounterType] or 100
end

-- Calculate experience reward with wave scaling
local function calculateExpReward(participantIds, baseExpValue, waveIndex, useWaveIndex)
    if useWaveIndex == nil then
        useWaveIndex = true
    end

    local totalExp = baseExpValue
    if useWaveIndex then
        -- Scale exp by wave index (matches TypeScript calculation)
        totalExp = baseExpValue * (1 + (waveIndex / 50))
    end

    return {
        participantIds = participantIds,
        totalExp = totalExp,
        useWaveIndex = useWaveIndex,
        baseExpValue = baseExpValue
    }
end

-- ============================================================================
-- Consequence Calculation Functions
-- ============================================================================

-- Get consequence type for encounter and option
local function getConsequenceType(encounterType, optionIndex)
    -- Placeholder implementation - would be populated with actual encounter consequences
    local consequences = {
        MYSTERIOUS_CHEST = {ConsequenceType.DAMAGE},
        DARK_CAVE = {ConsequenceType.STATUS, ConsequenceType.DAMAGE},
        RISKY_TRADE = {ConsequenceType.ITEM_LOSS, ConsequenceType.MONEY_LOSS}
    }

    local typeList = consequences[encounterType] or {ConsequenceType.DAMAGE}
    return typeList[1] or ConsequenceType.DAMAGE
end

-- Calculate damage value for encounter
local function calculateDamage(encounterType)
    local damageValues = {
        MYSTERIOUS_CHEST = 50,
        DARK_CAVE = 75,
        TRAP_ENCOUNTER = 100
    }

    return damageValues[encounterType] or 50
end

-- Get status effect for encounter
local function getStatusEffect(encounterType)
    local statusEffects = {
        POISON_TRAP = StatusEffect.POISON,
        BURN_HAZARD = StatusEffect.BURN,
        PARALYSIS_TRAP = StatusEffect.PARALYSIS
    }

    return statusEffects[encounterType] or StatusEffect.POISON
end

-- Get status duration for encounter
local function getStatusDuration(encounterType)
    return 3 -- Default duration in turns
end

-- Get item loss count
local function getItemLossCount(encounterType)
    return 1 -- Default item loss count
end

-- Get affected item types for item loss
local function getAffectedItemTypes(encounterType)
    return {"CONSUMABLE", "HELD_ITEM"}
end

-- Calculate money loss
local function calculateMoneyLoss(encounterType, currentMoney)
    local lossPercentages = {
        THIEF_ENCOUNTER = 0.25,
        RISKY_TRADE = 0.10,
        GAMBLING_LOSS = 0.50
    }

    local percentage = lossPercentages[encounterType] or 0.10
    return math.floor(currentMoney * percentage)
end

-- Select targets from party
local function selectTargets(partyState, targetingMode, count)
    local targets = {}

    if not partyState or not partyState.pokemon then
        return targets
    end

    if targetingMode == "all" then
        for _, pokemon in ipairs(partyState.pokemon) do
            table.insert(targets, pokemon.id)
        end
    elseif targetingMode == "random" and count then
        -- Select random Pokemon
        local availablePokemon = {}
        for _, pokemon in ipairs(partyState.pokemon) do
            if pokemon.hp and pokemon.hp > 0 then
                table.insert(availablePokemon, pokemon.id)
            end
        end

        for i = 1, math.min(count, #availablePokemon) do
            table.insert(targets, availablePokemon[i])
        end
    elseif targetingMode == "first" then
        if partyState.pokemon[1] then
            table.insert(targets, partyState.pokemon[1].id)
        end
    elseif targetingMode == "weakest" then
        -- Find Pokemon with lowest HP
        local weakest = nil
        for _, pokemon in ipairs(partyState.pokemon) do
            if pokemon.hp and pokemon.hp > 0 then
                if not weakest or pokemon.hp < weakest.hp then
                    weakest = pokemon
                end
            end
        end

        if weakest then
            table.insert(targets, weakest.id)
        end
    end

    return targets
end

-- Calculate consequences for failure
local function calculateConsequences(encounterType, optionIndex, outcome, partyState)
    local consequences = {}

    if outcome == "failure" then
        local consequenceType = getConsequenceType(encounterType, optionIndex)

        if consequenceType == ConsequenceType.DAMAGE then
            consequences.type = ConsequenceType.DAMAGE
            consequences.targets = selectTargets(partyState, "random", 1)
            consequences.value = calculateDamage(encounterType)
        elseif consequenceType == ConsequenceType.STATUS then
            consequences.type = ConsequenceType.STATUS
            consequences.targets = selectTargets(partyState, "all", nil)
            consequences.statusEffect = getStatusEffect(encounterType)
            consequences.duration = getStatusDuration(encounterType)
        elseif consequenceType == ConsequenceType.ITEM_LOSS then
            consequences.type = ConsequenceType.ITEM_LOSS
            consequences.itemCount = getItemLossCount(encounterType)
            consequences.itemTypes = getAffectedItemTypes(encounterType)
        elseif consequenceType == ConsequenceType.MONEY_LOSS then
            consequences.type = ConsequenceType.MONEY_LOSS
            consequences.amount = calculateMoneyLoss(encounterType, partyState.money or 0)
        end
    end

    return consequences
end

-- ============================================================================
-- Item Reward Calculation Functions
-- ============================================================================

-- Get modifier pool for reward tier
local function getModifierPool(rewardTier)
    local pools = {
        COMMON = {
            ModifierType.POTION,
            ModifierType.SUPER_POTION
        },
        UNCOMMON = {
            ModifierType.HYPER_POTION,
            ModifierType.REVIVE,
            ModifierType.PROTEIN,
            ModifierType.IRON
        },
        RARE = {
            ModifierType.MAX_POTION,
            ModifierType.MAX_REVIVE,
            ModifierType.RARE_CANDY,
            ModifierType.PP_UP
        },
        EPIC = {
            ModifierType.FULL_RESTORE,
            ModifierType.PP_MAX,
            ModifierType.FIRE_STONE,
            ModifierType.WATER_STONE,
            ModifierType.THUNDER_STONE
        },
        LEGENDARY = {
            ModifierType.MASTER_BALL,
            ModifierType.SACRED_ASH
        }
    }

    return pools[rewardTier] or pools.COMMON
end

-- Apply luck upgrades to modifier pool
local function applyLuckUpgrades(modifierPool, luckValue)
    -- Luck upgrade logic: higher luck = better modifiers
    if luckValue > 10 then
        -- Significant luck boost
        return modifierPool
    elseif luckValue > 5 then
        -- Minor luck boost
        return modifierPool
    end

    return modifierPool
end

-- Calculate item rewards
local function calculateItemRewards(encounterType, rewardTier, guaranteedModifiers, allowLuckUpgrades, rerollMultiplier)
    local modifierPool = getModifierPool(rewardTier)

    -- Add guaranteed modifiers if specified
    if guaranteedModifiers and #guaranteedModifiers > 0 then
        for _, modifier in ipairs(guaranteedModifiers) do
            table.insert(modifierPool, modifier)
        end
    end

    -- Apply luck upgrades if allowed
    if allowLuckUpgrades then
        modifierPool = applyLuckUpgrades(modifierPool, 0) -- Default luck value
    end

    return {
        modifiers = modifierPool,
        rerollMultiplier = rerollMultiplier or 1,
        modifierCount = #modifierPool
    }
end

-- ============================================================================
-- Egg Reward Calculation Functions
-- ============================================================================

-- Calculate detailed egg rewards
local function calculateEggRewardDetails(eggTier, species, sourceType, hatchWaves)
    local eggConfig = {
        tier = eggTier,
        species = species,
        sourceType = sourceType or EggSourceType.MYSTERY_ENCOUNTER,
        hatchWaves = hatchWaves or 10,
        pulled = false
    }

    return eggConfig
end

-- ============================================================================
-- Outcome Validation Functions
-- ============================================================================

-- Determine success threshold for encounter option
local function determineThreshold(encounterType, optionIndex)
    -- Placeholder implementation - would be populated with actual thresholds
    local thresholds = {
        MYSTERIOUS_CHEST = {50, 75, 90},
        DARK_CAVE = {40, 60, 80},
        RISKY_TRADE = {30, 50, 70}
    }

    local encounterThresholds = thresholds[encounterType] or {50, 70, 90}
    return encounterThresholds[optionIndex + 1] or 50
end

-- Validate outcome against threshold
local function validateOutcome(encounterType, optionIndex, resultValue, threshold)
    threshold = threshold or determineThreshold(encounterType, optionIndex)

    local outcome = "failure"
    if resultValue >= threshold then
        outcome = "success"
    elseif resultValue >= (threshold * 0.7) then
        outcome = "partial"
    end

    return {
        outcome = outcome,
        resultValue = resultValue,
        threshold = threshold,
        success = outcome == "success"
    }
end

-- ============================================================================
-- Reward Rarity Scaling Functions
-- ============================================================================

-- Get rarity index from rarity name
local function getRarityIndex(rarityName)
    return RarityTier[rarityName] or RarityTier.COMMON
end

-- Calculate reward rarity with scaling
local function calculateRewardRarity(encounterType, waveIndex, luckValue, baseRarity)
    local rarityTiers = {"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"}
    local rarityIndex = getRarityIndex(baseRarity)

    -- Wave scaling bonus (every 50 waves = +1 tier)
    local waveBonus = math.floor(waveIndex / 50)

    -- Luck scaling bonus
    local luckBonus = 0
    if luckValue > 10 then
        luckBonus = 2
    elseif luckValue > 5 then
        luckBonus = 1
    end

    -- Apply bonuses
    rarityIndex = rarityIndex + waveBonus + luckBonus

    -- Clamp to valid range
    rarityIndex = math.max(1, math.min(rarityIndex, #rarityTiers))

    return {
        rarity = rarityTiers[rarityIndex],
        rarityBonus = waveBonus + luckBonus,
        waveBonus = waveBonus,
        luckBonus = luckBonus
    }
end

-- ============================================================================
-- Consequence Mitigation Functions
-- ============================================================================

-- Get mitigation factors from party state
local function getMitigationFactors(partyState, consequenceType)
    local factors = {
        defenseBonus = 0,
        protectiveItems = false,
        cleanseItems = false
    }

    if not partyState then
        return factors
    end

    -- Calculate defense bonus from party
    if partyState.pokemon then
        local totalDefense = 0
        for _, pokemon in ipairs(partyState.pokemon) do
            if pokemon.stats and pokemon.stats.defense then
                totalDefense = totalDefense + pokemon.stats.defense
            end
        end
        factors.defenseBonus = math.floor(totalDefense / 100)
    end

    -- Check for protective items
    if partyState.items then
        for _, item in ipairs(partyState.items) do
            if item.type == "PROTECTIVE" then
                factors.protectiveItems = true
            elseif item.type == "CLEANSE" then
                factors.cleanseItems = true
            end
        end
    end

    return factors
end

-- Calculate consequence mitigation
local function mitigateConsequence(consequenceType, baseValue, mitigationFactors)
    local mitigatedValue = baseValue
    local reductionPercent = 0

    -- Apply mitigation based on factors
    if consequenceType == ConsequenceType.DAMAGE then
        if mitigationFactors.defenseBonus then
            reductionPercent = reductionPercent + (mitigationFactors.defenseBonus * 10)
        end
        if mitigationFactors.protectiveItems then
            reductionPercent = reductionPercent + 20
        end
    elseif consequenceType == ConsequenceType.STATUS then
        if mitigationFactors.cleanseItems then
            reductionPercent = 50
        end
    end

    -- Cap reduction at 75%
    reductionPercent = math.min(reductionPercent, 75)
    mitigatedValue = math.floor(baseValue * (1 - (reductionPercent / 100)))

    return {
        mitigatedValue = mitigatedValue,
        reductionPercent = reductionPercent,
        originalValue = baseValue
    }
end

-- ============================================================================
-- AO Handlers
-- ============================================================================

-- Handler: CalculateRewards
Handlers.add("calculate-rewards",
    Handlers.utils.hasMatchingTag("Action", "CalculateRewards"),
    function(msg)
        local encounterType = msg.EncounterType
        local optionIndex = tonumber(msg.OptionIndex)
        local outcome = msg.Outcome
        local waveIndex = tonumber(msg.WaveIndex) or 0

        if not encounterType or not optionIndex or not outcome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: EncounterType, OptionIndex, Outcome"
            })
            return
        end

        local partyState = msg.PartyState and json.decode(msg.PartyState) or nil
        local rewardConfig = calculateRewards(encounterType, optionIndex, outcome, waveIndex)

        local hasRewards = rewardConfig.customShopRewards ~= nil or rewardConfig.eggRewards ~= nil
        local hasExp = false -- Will be calculated separately via CalculateExpReward

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            HasRewards = tostring(hasRewards),
            HasExp = tostring(hasExp),
            Data = json.encode(rewardConfig)
        })
    end
)

-- Handler: CalculateConsequences
Handlers.add("calculate-consequences",
    Handlers.utils.hasMatchingTag("Action", "CalculateConsequences"),
    function(msg)
        local encounterType = msg.EncounterType
        local optionIndex = tonumber(msg.OptionIndex)
        local outcome = msg.Outcome

        if not encounterType or not optionIndex or not outcome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: EncounterType, OptionIndex, Outcome"
            })
            return
        end

        local partyState = msg.PartyState and json.decode(msg.PartyState) or {}
        local consequences = calculateConsequences(encounterType, optionIndex, outcome, partyState)

        local consequenceType = consequences.type or "NONE"

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            ConsequenceType = consequenceType,
            Data = json.encode(consequences)
        })
    end
)

-- Handler: CalculateExpReward
Handlers.add("calculate-exp-reward",
    Handlers.utils.hasMatchingTag("Action", "CalculateExpReward"),
    function(msg)
        local encounterType = msg.EncounterType
        local baseExpValue = tonumber(msg.BaseExpValue)
        local waveIndex = tonumber(msg.WaveIndex) or 0
        local useWaveIndex = msg.UseWaveIndex ~= "false" -- Default true

        if not baseExpValue then
            -- Try to derive from encounter type
            baseExpValue = getBaseExpValue(encounterType, nil)
            if not baseExpValue then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "BaseExpValue required or valid EncounterType"
                })
                return
            end
        end

        -- Parse participant IDs (comma-separated or all)
        local participantIds = {}
        if msg.ParticipantIds and msg.ParticipantIds ~= "" then
            for id in string.gmatch(msg.ParticipantIds, "[^,]+") do
                table.insert(participantIds, tonumber(id))
            end
        end

        local expReward = calculateExpReward(participantIds, baseExpValue, waveIndex, useWaveIndex)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            TotalExp = tostring(expReward.totalExp),
            ParticipantIds = msg.ParticipantIds or "",
            Data = json.encode(expReward)
        })
    end
)

-- Handler: CalculateItemRewards
Handlers.add("calculate-item-rewards",
    Handlers.utils.hasMatchingTag("Action", "CalculateItemRewards"),
    function(msg)
        local encounterType = msg.EncounterType
        local rewardTier = msg.RewardTier

        if not rewardTier then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "RewardTier required"
            })
            return
        end

        -- Parse guaranteed modifiers (comma-separated)
        local guaranteedModifiers = {}
        if msg.GuaranteedModifiers and msg.GuaranteedModifiers ~= "" then
            for modifier in string.gmatch(msg.GuaranteedModifiers, "[^,]+") do
                table.insert(guaranteedModifiers, modifier)
            end
        end

        local allowLuckUpgrades = msg.AllowLuckUpgrades ~= "false" -- Default true
        local rerollMultiplier = tonumber(msg.RerollMultiplier) or 1

        local itemRewards = calculateItemRewards(
            encounterType,
            rewardTier,
            guaranteedModifiers,
            allowLuckUpgrades,
            rerollMultiplier
        )

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            ModifierCount = tostring(itemRewards.modifierCount),
            Data = json.encode(itemRewards.modifiers)
        })
    end
)

-- Handler: CalculateEggRewards
Handlers.add("calculate-egg-rewards",
    Handlers.utils.hasMatchingTag("Action", "CalculateEggRewards"),
    function(msg)
        local eggTier = msg.EggTier

        if not eggTier then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggTier required"
            })
            return
        end

        local species = msg.Species
        local sourceType = msg.SourceType or EggSourceType.MYSTERY_ENCOUNTER
        local hatchWaves = tonumber(msg.HatchWaves) or 10

        local eggConfig = calculateEggRewardDetails(eggTier, species, sourceType, hatchWaves)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            EggCount = "1",
            Data = json.encode({eggConfig})
        })
    end
)

-- Handler: ValidateOutcome
Handlers.add("validate-outcome",
    Handlers.utils.hasMatchingTag("Action", "ValidateOutcome"),
    function(msg)
        local encounterType = msg.EncounterType
        local optionIndex = tonumber(msg.OptionIndex) or 0
        local resultValue = tonumber(msg.ResultValue) or 0
        local threshold = tonumber(msg.Threshold)

        local outcomeResult = validateOutcome(encounterType, optionIndex, resultValue, threshold)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Outcome = outcomeResult.outcome,
            Data = json.encode(outcomeResult)
        })
    end
)

-- Handler: CalculateRewardRarity
Handlers.add("calculate-reward-rarity",
    Handlers.utils.hasMatchingTag("Action", "CalculateRewardRarity"),
    function(msg)
        local encounterType = msg.EncounterType
        local waveIndex = tonumber(msg.WaveIndex) or 0
        local luckValue = tonumber(msg.LuckValue) or 0
        local baseRarity = msg.BaseRarity or "COMMON"

        local rarityResult = calculateRewardRarity(encounterType, waveIndex, luckValue, baseRarity)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Rarity = rarityResult.rarity,
            RarityBonus = tostring(rarityResult.rarityBonus),
            Data = json.encode(rarityResult)
        })
    end
)

-- Handler: MitigateConsequence
Handlers.add("mitigate-consequence",
    Handlers.utils.hasMatchingTag("Action", "MitigateConsequence"),
    function(msg)
        local consequenceType = msg.ConsequenceType

        if not consequenceType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ConsequenceType required"
            })
            return
        end

        local baseValue = tonumber(msg.BaseValue) or 0
        local mitigationFactors = msg.MitigationFactors and json.decode(msg.MitigationFactors) or {}

        local mitigationResult = mitigateConsequence(consequenceType, baseValue, mitigationFactors)

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            MitigatedValue = tostring(mitigationResult.mitigatedValue),
            ReductionPercent = tostring(mitigationResult.reductionPercent),
            Data = json.encode(mitigationResult)
        })
    end
)

-- Handler: Info (ADP v1.0 Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local processInfo = {
            process = {
                name = "Encounter Reward Engine",
                version = "1.0.0",
                adpVersion = "1.0",
                description = "Handles reward calculation, consequence application, and outcome determination for mystery encounters",
                capabilities = {
                    "CalculateRewards",
                    "CalculateConsequences",
                    "CalculateExpReward",
                    "CalculateItemRewards",
                    "CalculateEggRewards",
                    "ValidateOutcome",
                    "CalculateRewardRarity",
                    "MitigateConsequence"
                },
                messageSchemas = {
                    CalculateRewards = {
                        required = {"Action", "EncounterType", "OptionIndex", "Outcome"},
                        optional = {"WaveIndex", "PartyState"}
                    },
                    CalculateConsequences = {
                        required = {"Action", "EncounterType", "OptionIndex", "Outcome"},
                        optional = {"PartyState"}
                    },
                    CalculateExpReward = {
                        required = {"Action", "BaseExpValue"},
                        optional = {"EncounterType", "ParticipantIds", "WaveIndex", "UseWaveIndex"}
                    },
                    CalculateItemRewards = {
                        required = {"Action", "RewardTier"},
                        optional = {"EncounterType", "GuaranteedModifiers", "AllowLuckUpgrades", "RerollMultiplier"}
                    },
                    CalculateEggRewards = {
                        required = {"Action", "EggTier"},
                        optional = {"Species", "SourceType", "HatchWaves"}
                    },
                    ValidateOutcome = {
                        required = {"Action"},
                        optional = {"EncounterType", "OptionIndex", "ResultValue", "Threshold"}
                    },
                    CalculateRewardRarity = {
                        required = {"Action"},
                        optional = {"EncounterType", "WaveIndex", "LuckValue", "BaseRarity"}
                    },
                    MitigateConsequence = {
                        required = {"Action", "ConsequenceType"},
                        optional = {"BaseValue", "MitigationFactors"}
                    }
                }
            },
            handlers = {
                "calculate-rewards",
                "calculate-consequences",
                "calculate-exp-reward",
                "calculate-item-rewards",
                "calculate-egg-rewards",
                "validate-outcome",
                "calculate-reward-rarity",
                "mitigate-consequence",
                "info"
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true,
                homepage = "https://github.com/pokerogue/ao-migration"
            }
        }

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(processInfo)
        })
    end
)

-- ============================================================================
-- Process Initialization
-- ============================================================================
print("Encounter Reward Engine Process initialized successfully")
