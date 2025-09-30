-- Genetic Inheritance Engine Process
-- Comprehensive genetic inheritance calculation and optimization for Pokemon breeding
-- Implements ADP v1.0 for self-documentation

-- Process metadata for ADP compliance
local PROCESS_NAME = "genetic-inheritance-engine"
local PROCESS_VERSION = "1.0.0"
local ADP_VERSION = "1.0"

-- Embedded genetic data structures
local GeneticInheritanceData = {
    -- IV Inheritance Rules
    ivInheritance = {
        standardInheritance = {
            inheritedStats = 3,
            randomStats = 3,
            maxValue = 31,
            minValue = 0
        },
        destinyKnotEffect = {
            inheritedStats = 5,
            randomStats = 1
        },
        powerItemStats = {
            POWER_WEIGHT = "hp",
            POWER_BRACER = "attack",
            POWER_BELT = "defense",
            POWER_LENS = "spattack",
            POWER_BAND = "spdefense",
            POWER_ANKLET = "speed"
        }
    },
    
    -- Nature Inheritance Rules
    natureInheritance = {
        standardRate = 0.5,
        everstoneRate = 1.0,
        natureCount = 25
    },
    
    -- Nature stat modifiers (exact values)
    natureModifiers = {
        HARDY = {1.0, 1.0, 1.0, 1.0, 1.0},
        LONELY = {1.0, 1.1, 0.9, 1.0, 1.0},
        BRAVE = {1.0, 1.1, 1.0, 1.0, 0.9},
        ADAMANT = {1.0, 1.1, 1.0, 0.9, 1.0},
        NAUGHTY = {1.0, 1.1, 1.0, 1.0, 0.9},
        BOLD = {1.0, 0.9, 1.1, 1.0, 1.0},
        DOCILE = {1.0, 1.0, 1.0, 1.0, 1.0},
        RELAXED = {1.0, 1.0, 1.1, 1.0, 0.9},
        IMPISH = {1.0, 1.0, 1.1, 0.9, 1.0},
        LAX = {1.0, 1.0, 1.1, 1.0, 0.9},
        TIMID = {1.0, 0.9, 1.0, 1.0, 1.1},
        HASTY = {1.0, 1.0, 0.9, 1.0, 1.1},
        SERIOUS = {1.0, 1.0, 1.0, 1.0, 1.0},
        JOLLY = {1.0, 1.0, 1.0, 0.9, 1.1},
        NAIVE = {1.0, 1.0, 0.9, 1.0, 1.1},
        MODEST = {1.0, 0.9, 1.0, 1.1, 1.0},
        MILD = {1.0, 1.0, 0.9, 1.1, 1.0},
        QUIET = {1.0, 1.0, 1.0, 1.1, 0.9},
        BASHFUL = {1.0, 1.0, 1.0, 1.0, 1.0},
        RASH = {1.0, 1.0, 0.9, 1.1, 1.0},
        CALM = {1.0, 0.9, 1.0, 1.0, 1.1},
        GENTLE = {1.0, 0.9, 1.0, 1.0, 1.1},
        SASSY = {1.0, 1.0, 1.0, 1.0, 0.9},
        CAREFUL = {1.0, 1.0, 1.0, 0.9, 1.1},
        QUIRKY = {1.0, 1.0, 1.0, 1.0, 1.0}
    },
    
    -- Ability Inheritance Rules
    abilityInheritance = {
        standardSlotRates = {0.8, 0.2}, -- Slot 1: 80%, Slot 2: 20%
        hiddenAbilityRate = 0.6 -- 60% when parent has hidden ability
    },
    
    -- Stat names for indexing
    statNames = {"hp", "attack", "defense", "spattack", "spdefense", "speed"}
}

-- Core genetic inheritance state
local geneticState = {}

-- Helper function to deep copy tables
local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- Helper function to validate Pokemon data
local function validatePokemonData(pokemon)
    if not pokemon then
        return false, "Pokemon data required"
    end
    if not pokemon.id then
        return false, "Pokemon ID required"
    end
    if not pokemon.speciesId then
        return false, "Species ID required"
    end
    if not pokemon.ivs or #pokemon.ivs ~= 6 then
        return false, "Valid IVs required (6 values)"
    end
    if not pokemon.nature then
        return false, "Nature required"
    end
    if not pokemon.ability then
        return false, "Ability required"
    end
    return true
end

-- Calculate IV inheritance with item effects
local function calculateIvInheritance(parent1, parent2, parent1Item, parent2Item, randomValues)
    local result = {
        inheritedIvs = {0, 0, 0, 0, 0, 0},
        inheritanceSources = {},
        itemEffects = {}
    }
    
    -- Check for Destiny Knot
    local hasDestinyKnot = parent1Item == "DESTINY_KNOT" or parent2Item == "DESTINY_KNOT"
    local inheritCount = hasDestinyKnot and 5 or 3
    
    if hasDestinyKnot then
        table.insert(result.itemEffects, "destiny_knot_5_inherited")
    end
    
    -- Check for Power Items
    local guaranteedStats = {}
    if parent1Item and string.match(parent1Item, "^POWER_") then
        local stat = GeneticInheritanceData.ivInheritance.powerItemStats[parent1Item]
        if stat then
            for i, statName in ipairs(GeneticInheritanceData.statNames) do
                if statName == stat then
                    guaranteedStats[i] = {parent = 1, source = parent1Item}
                    table.insert(result.itemEffects, "power_item_guaranteed_" .. stat)
                    break
                end
            end
        end
    end
    
    if parent2Item and string.match(parent2Item, "^POWER_") then
        local stat = GeneticInheritanceData.ivInheritance.powerItemStats[parent2Item]
        if stat then
            for i, statName in ipairs(GeneticInheritanceData.statNames) do
                if statName == stat then
                    guaranteedStats[i] = {parent = 2, source = parent2Item}
                    table.insert(result.itemEffects, "power_item_guaranteed_" .. stat)
                    break
                end
            end
        end
    end
    
    -- Apply guaranteed stats first
    for statIndex, guarantee in pairs(guaranteedStats) do
        if guarantee.parent == 1 then
            result.inheritedIvs[statIndex] = parent1.ivs[statIndex]
            result.inheritanceSources[statIndex] = "parent1"
        else
            result.inheritedIvs[statIndex] = parent2.ivs[statIndex]
            result.inheritanceSources[statIndex] = "parent2"
        end
    end
    
    -- Calculate remaining inherited stats
    local availableStats = {}
    for i = 1, 6 do
        if not guaranteedStats[i] then
            table.insert(availableStats, i)
        end
    end
    
    -- Use provided random values from message parameters
    local randomIndex = 1
    randomValues = randomValues or {}
    local guaranteedCount = 0
    for _ in pairs(guaranteedStats) do
        guaranteedCount = guaranteedCount + 1
    end
    local remainingInheritCount = inheritCount - guaranteedCount
    
    for i = 1, math.min(remainingInheritCount, #availableStats) do
        -- Use provided random values
        local randVal = randomValues[randomIndex] or 0.5
        randomIndex = randomIndex + 1
        local index = math.floor(randVal * #availableStats) + 1
        index = math.min(index, #availableStats)
        local statIndex = availableStats[index]
        
        -- Select parent using next random value
        local parentRand = randomValues[randomIndex] or 0.5
        randomIndex = randomIndex + 1
        local parentChoice = parentRand < 0.5 and 1 or 2
        
        if parentChoice == 1 then
            result.inheritedIvs[statIndex] = parent1.ivs[statIndex]
            result.inheritanceSources[statIndex] = "parent1"
        else
            result.inheritedIvs[statIndex] = parent2.ivs[statIndex]
            result.inheritanceSources[statIndex] = "parent2"
        end
        
        table.remove(availableStats, index)
    end
    
    -- Generate random IVs for non-inherited stats using provided values
    for i = 1, 6 do
        if not result.inheritanceSources[i] then
            local ivRand = randomValues[randomIndex] or 0.5
            randomIndex = randomIndex + 1
            result.inheritedIvs[i] = math.floor(ivRand * 32)
            result.inheritanceSources[i] = "random"
        end
    end
    
    return result
end

-- Determine nature inheritance
local function determineNatureInheritance(parent1, parent2, parent1Item, parent2Item, randomValues)
    local result = {
        inheritedNature = nil,
        inheritanceSource = nil,
        inheritanceProbability = 0
    }
    
    -- Check for Everstone
    local parent1HasEverstone = parent1Item == "EVERSTONE"
    local parent2HasEverstone = parent2Item == "EVERSTONE"
    
    if parent1HasEverstone and parent2HasEverstone then
        -- Both have Everstone - 50/50 chance
        randomValues = randomValues or {}
        local randVal = randomValues[1] or 0.5
        if randVal < 0.5 then
            result.inheritedNature = parent1.nature
            result.inheritanceSource = "parent1_everstone"
        else
            result.inheritedNature = parent2.nature
            result.inheritanceSource = "parent2_everstone"
        end
        result.inheritanceProbability = 1.0
    elseif parent1HasEverstone then
        result.inheritedNature = parent1.nature
        result.inheritanceSource = "parent1_everstone"
        result.inheritanceProbability = 1.0
    elseif parent2HasEverstone then
        result.inheritedNature = parent2.nature
        result.inheritanceSource = "parent2_everstone"
        result.inheritanceProbability = 1.0
    else
        -- Standard inheritance - 50% chance to inherit
        randomValues = randomValues or {}
        local inheritRand = randomValues[1] or 0.5
        
        if inheritRand < 0.5 then
            -- Inherit from random parent
            local parentRand = randomValues[2] or 0.5
            if parentRand < 0.5 then
                result.inheritedNature = parent1.nature
                result.inheritanceSource = "parent1"
            else
                result.inheritedNature = parent2.nature
                result.inheritanceSource = "parent2"
            end
            result.inheritanceProbability = 0.5
        else
            -- Random nature
            local natures = {}
            for nature, _ in pairs(GeneticInheritanceData.natureModifiers) do
                table.insert(natures, nature)
            end
            local natureRand = randomValues[3] or 0.5
            local natureIndex = math.floor(natureRand * #natures) + 1
            natureIndex = math.min(natureIndex, #natures)
            result.inheritedNature = natures[natureIndex]
            result.inheritanceSource = "random"
            result.inheritanceProbability = 0.5
        end
    end
    
    -- Add nature effects
    local modifiers = GeneticInheritanceData.natureModifiers[result.inheritedNature]
    if modifiers then
        result.natureEffects = {
            multipliers = modifiers
        }
        
        -- Identify boosted and lowered stats
        for i, mult in ipairs(modifiers) do
            if mult > 1.0 then
                result.natureEffects.boosted = GeneticInheritanceData.statNames[i]
            elseif mult < 1.0 then
                result.natureEffects.lowered = GeneticInheritanceData.statNames[i]
            end
        end
    end
    
    return result
end

-- Calculate ability inheritance
local function calculateAbilityInheritance(parent1, parent2, speciesData, randomValues)
    local result = {
        inheritedAbility = nil,
        inheritanceSource = nil,
        inheritanceProbability = 0,
        abilityType = "normal"
    }
    
    -- Check for hidden abilities
    local parent1HasHidden = parent1.abilityIndex and parent1.abilityIndex == 3
    local parent2HasHidden = parent2.abilityIndex and parent2.abilityIndex == 3
    
    randomValues = randomValues or {}
    local randomIndex = 1
    
    if parent1HasHidden or parent2HasHidden then
        -- Hidden ability inheritance
        local roll = randomValues[randomIndex] or 0.5
        randomIndex = randomIndex + 1
        
        if roll < GeneticInheritanceData.abilityInheritance.hiddenAbilityRate then
            -- Inherit hidden ability
            if speciesData.abilities and speciesData.abilities[3] then
                result.inheritedAbility = speciesData.abilities[3]
                result.abilityType = "hidden"
                result.inheritanceSource = parent1HasHidden and "parent1_hidden" or "parent2_hidden"
                result.inheritanceProbability = 0.6
            end
        end
    end
    
    -- If no hidden ability inherited, use standard abilities
    if not result.inheritedAbility and speciesData.abilities then
        local roll = randomValues[randomIndex] or 0.5
        randomIndex = randomIndex + 1
        
        if roll < GeneticInheritanceData.abilityInheritance.standardSlotRates[1] then
            -- Slot 1
            if speciesData.abilities[1] then
                result.inheritedAbility = speciesData.abilities[1]
                result.inheritanceSource = "slot1"
                result.inheritanceProbability = 0.8
            end
        elseif speciesData.abilities[2] then
            -- Slot 2
            result.inheritedAbility = speciesData.abilities[2]
            result.inheritanceSource = "slot2"
            result.inheritanceProbability = 0.2
        elseif speciesData.abilities[1] then
            -- Fallback to slot 1 if no slot 2
            result.inheritedAbility = speciesData.abilities[1]
            result.inheritanceSource = "slot1"
            result.inheritanceProbability = 1.0
        end
    end
    
    return result
end

-- Process complete genetic inheritance
local function processCompleteInheritance(parent1, parent2, parent1Item, parent2Item, speciesData, randomValues)
    -- Split random values for each component
    local ivRandoms = {}
    local natureRandoms = {}
    local abilityRandoms = {}
    
    if randomValues then
        -- Distribute random values to each component
        for i = 1, 20 do
            ivRandoms[i] = randomValues[i] or math.random()
        end
        for i = 1, 5 do
            natureRandoms[i] = randomValues[20 + i] or math.random()
        end
        for i = 1, 5 do
            abilityRandoms[i] = randomValues[25 + i] or math.random()
        end
    end
    
    local ivResult = calculateIvInheritance(parent1, parent2, parent1Item, parent2Item, ivRandoms)
    local natureResult = determineNatureInheritance(parent1, parent2, parent1Item, parent2Item, natureRandoms)
    local abilityResult = calculateAbilityInheritance(parent1, parent2, speciesData, abilityRandoms)
    
    return {
        ivInheritance = ivResult,
        natureInheritance = natureResult,
        abilityInheritance = abilityResult
    }
end

-- Calculate breeding probabilities
local function calculateBreedingProbabilities(currentGenetics, targetGenetics)
    local probabilities = {
        perfectIvChance = 1.0,
        targetNatureChance = 0,
        targetAbilityChance = 0,
        combinedSuccessRate = 0,
        estimatedAttempts = 0
    }
    
    -- Calculate IV probability
    if targetGenetics.targetIvs then
        local perfectCount = 0
        for i = 1, 6 do
            if currentGenetics.ivInheritance and currentGenetics.ivInheritance.inheritedIvs then
                if currentGenetics.ivInheritance.inheritedIvs[i] == targetGenetics.targetIvs[i] then
                    perfectCount = perfectCount + 1
                end
            end
        end
        probabilities.perfectIvChance = perfectCount / 6
    end
    
    -- Calculate nature probability
    if targetGenetics.targetNature and currentGenetics.natureInheritance then
        if currentGenetics.natureInheritance.inheritedNature == targetGenetics.targetNature then
            probabilities.targetNatureChance = currentGenetics.natureInheritance.inheritanceProbability or 0
        end
    end
    
    -- Calculate ability probability
    if targetGenetics.targetAbility and currentGenetics.abilityInheritance then
        if currentGenetics.abilityInheritance.inheritedAbility == targetGenetics.targetAbility then
            probabilities.targetAbilityChance = currentGenetics.abilityInheritance.inheritanceProbability or 0
        end
    end
    
    -- Combined probability
    probabilities.combinedSuccessRate = probabilities.perfectIvChance * 
                                        (probabilities.targetNatureChance > 0 and probabilities.targetNatureChance or 1) *
                                        (probabilities.targetAbilityChance > 0 and probabilities.targetAbilityChance or 1)
    
    -- Estimated attempts
    if probabilities.combinedSuccessRate > 0 then
        probabilities.estimatedAttempts = math.ceil(1 / probabilities.combinedSuccessRate)
    else
        probabilities.estimatedAttempts = 999999
    end
    
    return probabilities
end

-- Optimize breeding strategy
local function optimizeBreedingStrategy(currentParents, targetGenetics)
    local recommendations = {
        optimalItems = {},
        parentImprovements = {},
        breedingStrategy = "",
        efficiencyRating = ""
    }
    
    -- Check for IV optimization
    if targetGenetics.targetIvs then
        table.insert(recommendations.optimalItems, "DESTINY_KNOT")
        
        -- Check parent IV quality
        local parent1IvSum = 0
        local parent2IvSum = 0
        if currentParents.parent1 and currentParents.parent1.ivs then
            for _, iv in ipairs(currentParents.parent1.ivs) do
                parent1IvSum = parent1IvSum + iv
            end
        end
        if currentParents.parent2 and currentParents.parent2.ivs then
            for _, iv in ipairs(currentParents.parent2.ivs) do
                parent2IvSum = parent2IvSum + iv
            end
        end
        
        if parent1IvSum < 150 then
            table.insert(recommendations.parentImprovements, "improve_parent1_ivs")
        end
        if parent2IvSum < 150 then
            table.insert(recommendations.parentImprovements, "improve_parent2_ivs")
        end
    end
    
    -- Check for nature optimization
    if targetGenetics.targetNature then
        table.insert(recommendations.optimalItems, "EVERSTONE")
        
        if currentParents.parent1 and currentParents.parent1.nature ~= targetGenetics.targetNature and
           currentParents.parent2 and currentParents.parent2.nature ~= targetGenetics.targetNature then
            table.insert(recommendations.parentImprovements, "acquire_target_nature")
        end
    end
    
    -- Check for ability optimization
    if targetGenetics.targetAbility then
        local hasTargetAbility = false
        if currentParents.parent1 and currentParents.parent1.ability == targetGenetics.targetAbility then
            hasTargetAbility = true
        end
        if currentParents.parent2 and currentParents.parent2.ability == targetGenetics.targetAbility then
            hasTargetAbility = true
        end
        
        if not hasTargetAbility then
            table.insert(recommendations.parentImprovements, "acquire_target_ability")
        end
    end
    
    -- Determine breeding strategy
    if #recommendations.parentImprovements > 2 then
        recommendations.breedingStrategy = "multi_generation_optimization"
        recommendations.efficiencyRating = "low"
    elseif #recommendations.parentImprovements > 0 then
        recommendations.breedingStrategy = "single_generation_improvement"
        recommendations.efficiencyRating = "medium"
    else
        recommendations.breedingStrategy = "direct_breeding"
        recommendations.efficiencyRating = "high"
    end
    
    return recommendations
end

-- Message handlers
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = PROCESS_NAME,
                    version = PROCESS_VERSION,
                    adpVersion = ADP_VERSION,
                    capabilities = {
                        "calculateIvInheritance",
                        "determineNatureInheritance", 
                        "calculateAbilityInheritance",
                        "processCompleteInheritance",
                        "calculateBreedingProbabilities",
                        "optimizeBreedingStrategy"
                    }
                },
                handlers = {
                    "Info",
                    "ProcessLogic",
                    "HealthCheck"
                },
                messageSchemas = {
                    ProcessLogic = {
                        required = {"Action", "Operation", "Data"},
                        operations = {
                            "calculateIvInheritance",
                            "determineNatureInheritance",
                            "calculateAbilityInheritance",
                            "processCompleteInheritance",
                            "calculateProbabilities",
                            "optimizeStrategy"
                        }
                    }
                },
                documentation = {
                    description = "Comprehensive genetic inheritance calculation and optimization for Pokemon breeding",
                    adpCompliance = true,
                    selfDocumenting = true
                }
            })
        })
    end
)

-- Cross-process coordination handler
Handlers.add("fetch-pokemon-data",
    Handlers.utils.hasMatchingTag("Action", "FetchPokemonDataResponse"),
    function(msg)
        -- Store fetched Pokemon data for processing
        local data = msg.Data and json.decode(msg.Data) or {}
        if data.pokemon then
            -- Process pending genetic calculation with fetched data
            if geneticState.pendingRequest then
                local pending = geneticState.pendingRequest
                pending.pokemonData[data.pokemon.id] = data.pokemon
                
                -- Check if we have all required data
                if pending.pokemonData[pending.parent1Id] and pending.pokemonData[pending.parent2Id] then
                    -- Execute the pending genetic calculation
                    local parent1 = pending.pokemonData[pending.parent1Id]
                    local parent2 = pending.pokemonData[pending.parent2Id]
                    
                    local genetics = processCompleteInheritance(
                        parent1,
                        parent2,
                        pending.parent1Item,
                        pending.parent2Item,
                        pending.speciesData,
                        pending.randomValues
                    )
                    
                    ao.send({
                        Target = pending.requester,
                        Action = "SaveState",
                        Data = json.encode({
                            success = true,
                            operation = pending.operation,
                            genetics = genetics
                        })
                    })
                    
                    -- Clear pending request
                    geneticState.pendingRequest = nil
                end
            end
        end
    end
)

-- Breeding compatibility response handler
Handlers.add("breeding-compatibility-response",
    Handlers.utils.hasMatchingTag("Action", "BreedingCompatibilityResponse"),
    function(msg)
        local data = msg.Data and json.decode(msg.Data) or {}
        if geneticState.pendingRequest and data.compatible then
            -- Continue with genetic calculation if compatible
            local pending = geneticState.pendingRequest
            
            -- Request Pokemon data from instance manager
            ao.send({
                Target = msg.InstanceManagerId or "POKEMON_INSTANCE_MANAGER_PROCESS",
                Action = "GetPokemonData",
                Data = json.encode({
                    pokemonId = pending.parent1Id,
                    includeIvs = true,
                    includeNature = true,
                    includeAbility = true,
                    includeItems = true
                })
            })
            
            ao.send({
                Target = msg.InstanceManagerId or "POKEMON_INSTANCE_MANAGER_PROCESS",
                Action = "GetPokemonData",
                Data = json.encode({
                    pokemonId = pending.parent2Id,
                    includeIvs = true,
                    includeNature = true,
                    includeAbility = true,
                    includeItems = true
                })
            })
        elseif geneticState.pendingRequest and not data.compatible then
            -- Send error response for incompatible breeding
            ao.send({
                Target = geneticState.pendingRequest.requester,
                Action = "Error",
                Error = "Breeding pair is not compatible: " .. (data.reason or "Unknown reason")
            })
            geneticState.pendingRequest = nil
        end
    end
)

Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        -- Parse incoming data
        local data = msg.Data and json.decode(msg.Data) or {}
        local operation = data.operation
        local params = data.parameters or {}
        
        if not operation then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Operation required"
            })
            return
        end
        
        local result = {
            success = false,
            operation = operation
        }
        
        if operation == "calculateIvInheritance" then
            if not params.parent1 or not params.parent2 then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Parent data required"
                })
                return
            end
            
            -- Use randomValues instead of rngSeed
            local ivResult = calculateIvInheritance(
                params.parent1,
                params.parent2,
                params.parent1Item,
                params.parent2Item,
                params.randomValues or {}
            )
            
            result.success = true
            result.genetics = {ivInheritance = ivResult}
            
        elseif operation == "determineNatureInheritance" then
            if not params.parent1 or not params.parent2 then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Parent data required"
                })
                return
            end
            
            -- Use randomValues instead of rngSeed
            local natureResult = determineNatureInheritance(
                params.parent1,
                params.parent2,
                params.parent1Item,
                params.parent2Item,
                params.randomValues or {}
            )
            
            result.success = true
            result.genetics = {natureInheritance = natureResult}
            
        elseif operation == "calculateAbilityInheritance" then
            if not params.parent1 or not params.parent2 or not params.speciesData then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Parent and species data required"
                })
                return
            end
            
            -- Use randomValues instead of rngSeed
            local abilityResult = calculateAbilityInheritance(
                params.parent1,
                params.parent2,
                params.speciesData,
                params.randomValues or {}
            )
            
            result.success = true
            result.genetics = {abilityInheritance = abilityResult}
            
        elseif operation == "processCompleteInheritance" then
            -- For complete inheritance, we need to coordinate with other processes
            if params.parent1Id and params.parent2Id then
                -- Store pending request for cross-process coordination
                geneticState.pendingRequest = {
                    requester = msg.From,
                    operation = operation,
                    parent1Id = params.parent1Id,
                    parent2Id = params.parent2Id,
                    parent1Item = params.parent1Item,
                    parent2Item = params.parent2Item,
                    speciesData = params.speciesData,
                    randomValues = params.randomValues or {},
                    pokemonData = {}
                }
                
                -- First validate breeding compatibility
                ao.send({
                    Target = params.compatibilityEngineId or "BREEDING_COMPATIBILITY_ENGINE_PROCESS",
                    Action = "ValidateBreedingPair",
                    Data = json.encode({
                        parent1Id = params.parent1Id,
                        parent2Id = params.parent2Id,
                        includeGeneticCompatibility = true
                    })
                })
                return -- Wait for async response
            elseif params.parent1 and params.parent2 and params.speciesData then
                -- Direct calculation with provided data
                local genetics = processCompleteInheritance(
                    params.parent1,
                    params.parent2,
                    params.parent1Item,
                    params.parent2Item,
                    params.speciesData,
                    params.randomValues or {}
                )
                
                result.success = true
                result.genetics = genetics
            else
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Either parent IDs for coordination or complete parent data required"
                })
                return
            end
            
        elseif operation == "calculateProbabilities" then
            if not params.currentGenetics or not params.targetGenetics then
                ao.send({
                    Target = msg.From,
                    Action = "Error", 
                    Error = "Current and target genetics required"
                })
                return
            end
            
            local probabilities = calculateBreedingProbabilities(
                params.currentGenetics,
                params.targetGenetics
            )
            
            result.success = true
            result.probabilities = probabilities
            
        elseif operation == "optimizeStrategy" then
            if not params.currentParents or not params.targetGenetics then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Current parents and target genetics required"
                })
                return
            end
            
            local recommendations = optimizeBreedingStrategy(
                params.currentParents,
                params.targetGenetics
            )
            
            result.success = true
            result.recommendations = recommendations
            
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Unknown operation: " .. operation
            })
            return
        end
        
        -- Send successful response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result)
        })
    end
)

Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthCheckResponse",
            Status = "healthy",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Process initialization
print("Genetic Inheritance Engine Process initialized - Version " .. PROCESS_VERSION)