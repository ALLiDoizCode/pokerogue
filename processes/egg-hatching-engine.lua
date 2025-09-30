-- egg-hatching-engine.lua
-- Stateless AO Process for Pokemon Egg Hatching and Incubation
-- Handles egg step progression, hatching probability, Pokemon generation, and mass hatching
-- ADP v1.0 Compliant - Self-Documenting Process

-- CRITICAL: This is a monolithic AO process - all dependencies embedded
-- No external requires except json (permitted in AO environment)
local json = require("json")

-- Process version and metadata
local PROCESS_VERSION = "1.0.0"
local ADP_VERSION = "1.0"

-- Cross-process communication addresses
-- These are set via ConfigureProcessIds handler or environment
local BREEDING_COMPATIBILITY_PROCESS_ID = "breeding_compatibility_process"
local GENETIC_INHERITANCE_PROCESS_ID = "genetic_inheritance_process"
local EGG_MOVE_LEARNING_PROCESS_ID = "egg_move_learning_process"
local SPECIES_DB_PROCESS_ID = "pokemon_species_db_process"
local INSTANCE_MANAGER_PROCESS_ID = "pokemon_instance_manager_process"
local COORDINATOR_PROCESS_ID = "coordinator_process"

-- Process ID configuration state
local processIdsConfigured = false

-- ============================================================================
-- EMBEDDED DATA: EGG STEP REQUIREMENTS
-- Source: typescript-reference/src/balance/rates.ts
-- ============================================================================

local HATCH_WAVES_COMMON_EGG = 10
local HATCH_WAVES_RARE_EGG = 25
local HATCH_WAVES_EPIC_EGG = 50
local HATCH_WAVES_LEGENDARY_EGG = 100
local HATCH_WAVES_MANAPHY_EGG = 50

-- Steps per wave (base rate)
local STEPS_PER_WAVE = 256

-- Egg tier definitions
local EggTier = {
    COMMON = 1,
    RARE = 2,
    EPIC = 3,
    LEGENDARY = 4
}

-- Egg source types
local EggSourceType = {
    WILD = "wild",
    VOUCHER = "voucher",
    GACHA = "gacha",
    BREEDING = "breeding",
    EVENT = "event",
    SAME_SPECIES_EGG = "same_species_egg"
}

-- Step requirements by tier (waves * steps per wave)
local EggStepRequirements = {
    [EggTier.COMMON] = HATCH_WAVES_COMMON_EGG * STEPS_PER_WAVE,      -- 2560
    [EggTier.RARE] = HATCH_WAVES_RARE_EGG * STEPS_PER_WAVE,          -- 6400
    [EggTier.EPIC] = HATCH_WAVES_EPIC_EGG * STEPS_PER_WAVE,          -- 12800
    [EggTier.LEGENDARY] = HATCH_WAVES_LEGENDARY_EGG * STEPS_PER_WAVE -- 25600
}

-- Special species step requirements
local SpecialStepRequirements = {
    [489] = HATCH_WAVES_MANAPHY_EGG * STEPS_PER_WAVE, -- PHIONE
    [490] = HATCH_WAVES_MANAPHY_EGG * STEPS_PER_WAVE  -- MANAPHY
}

-- ============================================================================
-- EMBEDDED DATA: HATCHING PROBABILITIES
-- Source: typescript-reference/src/balance/rates.ts
-- ============================================================================

local MANAPHY_EGG_MANAPHY_RATE = 8 -- 1 in 8 chance for Manaphy from Phione egg
local SAME_SPECIES_EGG_HA_RATE = 10 -- Hidden ability rate for same species eggs
local GACHA_EGG_HA_RATE = 192 -- Hidden ability rate for gacha eggs

-- Incubation modifiers
local IncubationModifiers = {
    FLAME_BODY = 2.0,      -- Double step progression
    OVAL_CHARM = 1.5,      -- 50% faster hatching
    HATCHING_POWER_1 = 1.2, -- 20% faster
    HATCHING_POWER_2 = 1.5, -- 50% faster
    HATCHING_POWER_3 = 2.0  -- Double speed
}

-- ============================================================================
-- EMBEDDED DATA: ANIMATION TIMING
-- Source: typescript-reference/src/phases/egg-hatch-phase.ts
-- ============================================================================

local AnimationTiming = {
    PRE_HATCH_DURATION = 1000,    -- Time before egg starts cracking
    CRACK_SEQUENCE = {500, 300, 200}, -- Timing for each crack
    REVEAL_DURATION = 2000,        -- Pokemon reveal time
    TOTAL_DURATION = 4000          -- Total animation time
}

-- ============================================================================
-- STATE MANAGEMENT (Stateless - Passed via messages)
-- ============================================================================

-- Helper function to validate egg data structure
local function validateEggData(eggData)
    if not eggData then
        return false, "Egg data is required"
    end
    if not eggData.eggId then
        return false, "Egg ID is required"
    end
    if not eggData.species then
        return false, "Egg species is required"
    end
    if not eggData.steps then
        eggData.steps = 0
    end
    if not eggData.requiredSteps then
        -- Calculate based on tier or species
        local tier = eggData.eggType and EggTier[string.upper(eggData.eggType)] or EggTier.COMMON
        eggData.requiredSteps = SpecialStepRequirements[tonumber(eggData.species)] or EggStepRequirements[tier]
    end
    return true, nil
end

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

-- Calculate effective step progression with modifiers
local function calculateEffectiveSteps(baseSteps, modifiers)
    local multiplier = 1.0
    
    if modifiers then
        for modifierType, value in pairs(modifiers) do
            if IncubationModifiers[modifierType] then
                multiplier = multiplier * IncubationModifiers[modifierType]
            elseif type(value) == "number" then
                multiplier = multiplier * value
            end
        end
    end
    
    return math.floor(baseSteps * multiplier)
end

-- Progress egg steps and check if ready to hatch
local function progressEggSteps(eggData, stepsToAdd, modifiers)
    local valid, error = validateEggData(eggData)
    if not valid then
        return nil, error
    end
    
    local effectiveSteps = calculateEffectiveSteps(stepsToAdd, modifiers)
    local previousSteps = eggData.steps
    
    -- Add steps, cap at required
    eggData.steps = math.min(eggData.steps + effectiveSteps, eggData.requiredSteps)
    
    -- Check if ready to hatch
    local isReady = eggData.steps >= eggData.requiredSteps
    
    return {
        eggId = eggData.eggId,
        previousSteps = previousSteps,
        currentSteps = eggData.steps,
        stepsAdded = effectiveSteps,
        requiredSteps = eggData.requiredSteps,
        isReadyToHatch = isReady,
        percentComplete = math.floor((eggData.steps / eggData.requiredSteps) * 100)
    }
end

-- Generate hatched Pokemon data
local function generateHatchedPokemon(eggData, parentTraits, eggMoves, timestamp)
    local pokemonData = {
        species = eggData.species,
        level = 1,
        experience = 0,
        friendship = 70, -- Base friendship for hatched Pokemon
        eggHatched = true,
        hatchedTimestamp = timestamp or 0,
        sourceEgg = eggData.eggId
    }
    
    -- Apply parent traits if breeding egg
    if eggData.sourceType == EggSourceType.BREEDING and parentTraits then
        pokemonData.ivs = parentTraits.ivs
        pokemonData.nature = parentTraits.nature
        pokemonData.ability = parentTraits.ability
        pokemonData.hiddenAbility = parentTraits.hiddenAbility
    else
        -- Generate IVs based on egg type
        local ivBonus = 0
        if eggData.eggType == "rare" then
            ivBonus = 10
        elseif eggData.eggType == "epic" then
            ivBonus = 15
        elseif eggData.eggType == "legendary" then
            ivBonus = 20
        end
        
        pokemonData.ivs = {
            hp = 1 + ivBonus + (timestamp % 16),
            attack = 1 + ivBonus + ((timestamp * 3) % 16),
            defense = 1 + ivBonus + ((timestamp * 7) % 16),
            spAttack = 1 + ivBonus + ((timestamp * 11) % 16),
            spDefense = 1 + ivBonus + ((timestamp * 13) % 16),
            speed = 1 + ivBonus + ((timestamp * 17) % 16)
        }
        
        -- Cap IVs at 31
        for stat, value in pairs(pokemonData.ivs) do
            pokemonData.ivs[stat] = math.min(31, value)
        end
    end
    
    -- Apply egg moves if provided
    if eggMoves and #eggMoves > 0 then
        pokemonData.moves = eggMoves
    end
    
    -- Special case: Phione egg can hatch into Manaphy
    if tonumber(eggData.species) == 489 and eggData.sourceType == EggSourceType.SAME_SPECIES_EGG then
        -- Use timestamp-based RNG for Manaphy chance
        if (timestamp % MANAPHY_EGG_MANAPHY_RATE) == 0 then
            pokemonData.species = 490 -- Change to Manaphy
        end
    end
    
    return pokemonData
end

-- Process mass hatching
local function processMassHatch(eggIds, eggDataMap, timestamp)
    local results = {}
    local failed = {}
    
    for _, eggId in ipairs(eggIds) do
        local eggData = eggDataMap[eggId]
        if eggData then
            if eggData.steps >= eggData.requiredSteps then
                -- Ready to hatch
                local pokemonData = generateHatchedPokemon(eggData, nil, nil, timestamp)
                table.insert(results, {
                    eggId = eggId,
                    pokemon = pokemonData,
                    success = true
                })
            else
                -- Not ready
                table.insert(failed, {
                    eggId = eggId,
                    reason = "Not ready to hatch",
                    currentSteps = eggData.steps,
                    requiredSteps = eggData.requiredSteps
                })
            end
        else
            table.insert(failed, {
                eggId = eggId,
                reason = "Egg not found"
            })
        end
    end
    
    return {
        hatched = results,
        failed = failed,
        totalProcessed = #eggIds,
        successCount = #results,
        failureCount = #failed
    }
end

-- Sort eggs by various criteria
local function sortEggs(eggList, sortBy)
    if not eggList or #eggList == 0 then
        return eggList
    end
    
    local sortFunctions = {
        steps = function(a, b)
            return (a.steps or 0) > (b.steps or 0) -- Most progress first
        end,
        type = function(a, b)
            local tierOrder = {legendary = 1, epic = 2, rare = 3, common = 4}
            local aTier = tierOrder[a.eggType] or 5
            local bTier = tierOrder[b.eggType] or 5
            return aTier < bTier
        end,
        species = function(a, b)
            return (a.species or 0) < (b.species or 0)
        end,
        ready = function(a, b)
            local aReady = (a.steps >= a.requiredSteps) and 1 or 0
            local bReady = (b.steps >= b.requiredSteps) and 1 or 0
            return aReady > bReady
        end
    }
    
    local sortFunction = sortFunctions[sortBy] or sortFunctions.steps
    table.sort(eggList, sortFunction)
    
    return eggList
end

-- Filter eggs by criteria
local function filterEggs(eggList, filter)
    if not filter or filter == "all" then
        return eggList
    end
    
    local filtered = {}
    for _, egg in ipairs(eggList) do
        if filter == "ready" and egg.steps >= egg.requiredSteps then
            table.insert(filtered, egg)
        elseif filter == "incubating" and egg.steps < egg.requiredSteps then
            table.insert(filtered, egg)
        end
    end
    
    return filtered
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Info handler for ADP v1.0 compliance
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Info-Response",
            Data = json.encode({
                process = {
                    name = "Egg Hatching Engine",
                    version = PROCESS_VERSION,
                    adpVersion = ADP_VERSION,
                    description = "Handles egg hatching, incubation, and Pokemon generation",
                    capabilities = {
                        "ProgressSteps", "HatchEgg", "MassHatch", "ListEggs",
                        "GetEggDetails", "SortEggs", "ApplyIncubator", "RemoveIncubator",
                        "GetHatchTiming", "ConfigureProcessIds"
                    }
                },
                handlers = {
                    ProgressSteps = "Progress egg steps with optional modifiers",
                    HatchEgg = "Hatch a single egg and generate Pokemon",
                    MassHatch = "Batch hatch multiple eggs",
                    ListEggs = "List eggs with optional filtering",
                    GetEggDetails = "Get detailed information about an egg",
                    SortEggs = "Sort eggs by various criteria",
                    ApplyIncubator = "Apply incubation modifier to egg",
                    RemoveIncubator = "Remove incubation modifier from egg",
                    GetHatchTiming = "Get animation timing for hatching",
                    ConfigureProcessIds = "Configure cross-process communication IDs"
                },
                messageSchemas = {
                    ProgressSteps = {
                        required = {"Action", "EggId", "Steps"},
                        optional = {"Modifiers"}
                    },
                    HatchEgg = {
                        required = {"Action", "EggId"},
                        optional = {"ParentData", "EggMoves"}
                    },
                    MassHatch = {
                        required = {"Action", "Data"}, -- Data contains egg IDs array
                        optional = {}
                    }
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    stateless = true
                }
            })
        })
    end
)

-- Configure process IDs for cross-process communication
Handlers.add("configure-process-ids",
    Handlers.utils.hasMatchingTag("Action", "ConfigureProcessIds"),
    function(msg)
        local config = msg.Data and json.decode(msg.Data) or {}
        
        if config.breedingCompatibilityProcess then
            BREEDING_COMPATIBILITY_PROCESS_ID = config.breedingCompatibilityProcess
        end
        if config.geneticInheritanceProcess then
            GENETIC_INHERITANCE_PROCESS_ID = config.geneticInheritanceProcess
        end
        if config.eggMoveLearningProcess then
            EGG_MOVE_LEARNING_PROCESS_ID = config.eggMoveLearningProcess
        end
        if config.speciesDbProcess then
            SPECIES_DB_PROCESS_ID = config.speciesDbProcess
        end
        if config.instanceManagerProcess then
            INSTANCE_MANAGER_PROCESS_ID = config.instanceManagerProcess
        end
        if config.coordinatorProcess then
            COORDINATOR_PROCESS_ID = config.coordinatorProcess
        end
        
        processIdsConfigured = true
        
        ao.send({
            Target = msg.From,
            Action = "ProcessIds-Configured",
            Success = "true",
            Data = json.encode({
                breedingCompatibility = BREEDING_COMPATIBILITY_PROCESS_ID,
                geneticInheritance = GENETIC_INHERITANCE_PROCESS_ID,
                eggMoveLearning = EGG_MOVE_LEARNING_PROCESS_ID,
                speciesDb = SPECIES_DB_PROCESS_ID,
                instanceManager = INSTANCE_MANAGER_PROCESS_ID,
                coordinator = COORDINATOR_PROCESS_ID
            })
        })
    end
)

-- Progress egg steps
Handlers.add("progress-steps",
    Handlers.utils.hasMatchingTag("Action", "ProgressSteps"),
    function(msg)
        local eggId = msg.EggId
        local steps = tonumber(msg.Steps)
        
        if not eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggId required"
            })
            return
        end
        
        if not steps or steps < 0 then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid step count"
            })
            return
        end
        
        -- Get egg data from message
        local eggData = msg.Data and json.decode(msg.Data) or {}
        if not eggData.eggId then
            eggData.eggId = eggId
        end
        
        -- Parse modifiers if provided
        local modifiers = msg.Modifiers and json.decode(msg.Modifiers) or nil
        
        -- Progress steps
        local result, error = progressEggSteps(eggData, steps, modifiers)
        
        if error then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "StepProgressUpdate",
            Success = "true",
            EggId = eggId,
            CurrentSteps = tostring(result.currentSteps),
            RequiredSteps = tostring(result.requiredSteps),
            StepsAdded = tostring(result.stepsAdded),
            IsReady = tostring(result.isReadyToHatch),
            PercentComplete = tostring(result.percentComplete),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Hatch single egg
Handlers.add("hatch-egg",
    Handlers.utils.hasMatchingTag("Action", "HatchEgg"),
    function(msg)
        local eggId = msg.EggId
        
        if not eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggId required"
            })
            return
        end
        
        -- Get egg data from message
        local eggData = msg.Data and json.decode(msg.Data) or {}
        if not eggData.eggId then
            eggData.eggId = eggId
        end
        
        local valid, error = validateEggData(eggData)
        if not valid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error
            })
            return
        end
        
        -- Check if egg is ready to hatch
        if eggData.steps < eggData.requiredSteps then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Egg not ready to hatch",
                CurrentSteps = tostring(eggData.steps),
                RequiredSteps = tostring(eggData.requiredSteps)
            })
            return
        end
        
        -- Get parent traits and egg moves if provided
        local parentTraits = msg.ParentTraits and json.decode(msg.ParentTraits) or nil
        local eggMoves = msg.EggMoves and json.decode(msg.EggMoves) or nil
        
        -- Generate hatched Pokemon
        local pokemonData = generateHatchedPokemon(
            eggData,
            parentTraits,
            eggMoves,
            msg.Timestamp or 0
        )
        
        -- Request Pokemon instance creation through coordinator
        if processIdsConfigured and COORDINATOR_PROCESS_ID ~= "coordinator_process" then
            ao.send({
                Target = COORDINATOR_PROCESS_ID,
                Action = "CreatePokemonInstance",
                Data = json.encode({
                    eggId = eggId,
                    pokemonData = pokemonData,
                    requesterId = msg.From
                })
            })
        end
        
        ao.send({
            Target = msg.From,
            Action = "HatchComplete",
            Success = "true",
            EggId = eggId,
            Data = json.encode({
                pokemon = pokemonData,
                inheritedMoves = eggMoves,
                parentTraits = parentTraits,
                hatchedAt = msg.Timestamp or 0
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Mass hatch operation
Handlers.add("mass-hatch",
    Handlers.utils.hasMatchingTag("Action", "MassHatch"),
    function(msg)
        local data = msg.Data and json.decode(msg.Data) or {}
        local eggIds = data.eggIds or {}
        local eggDataMap = data.eggDataMap or {}
        
        if #eggIds == 0 then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "No egg IDs provided"
            })
            return
        end
        
        -- Process mass hatching
        local results = processMassHatch(eggIds, eggDataMap, msg.Timestamp or 0)
        
        ao.send({
            Target = msg.From,
            Action = "MassHatchComplete",
            Success = "true",
            Data = json.encode(results),
            TotalProcessed = tostring(results.totalProcessed),
            SuccessCount = tostring(results.successCount),
            FailureCount = tostring(results.failureCount),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- List player eggs with filtering
Handlers.add("list-eggs",
    Handlers.utils.hasMatchingTag("Action", "ListEggs"),
    function(msg)
        local data = msg.Data and json.decode(msg.Data) or {}
        local eggList = data.eggs or {}
        local filter = msg.Filter or "all"
        
        -- Apply filter
        local filtered = filterEggs(eggList, filter)
        
        -- Count ready eggs
        local readyCount = 0
        for _, egg in ipairs(filtered) do
            if egg.steps >= egg.requiredSteps then
                readyCount = readyCount + 1
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "EggInventory",
            Success = "true",
            Data = json.encode({
                eggs = filtered,
                totalCount = #filtered,
                readyCount = readyCount,
                filter = filter
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Get egg details
Handlers.add("get-egg-details",
    Handlers.utils.hasMatchingTag("Action", "GetEggDetails"),
    function(msg)
        local eggId = msg.EggId
        
        if not eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggId required"
            })
            return
        end
        
        local eggData = msg.Data and json.decode(msg.Data) or {}
        
        if not eggData.eggId or eggData.eggId ~= eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Egg not found"
            })
            return
        end
        
        -- Calculate progress
        local percentComplete = 0
        if eggData.requiredSteps and eggData.requiredSteps > 0 then
            percentComplete = math.floor((eggData.steps / eggData.requiredSteps) * 100)
        end
        
        ao.send({
            Target = msg.From,
            Action = "EggDetails",
            Success = "true",
            EggId = eggId,
            Data = json.encode({
                egg = eggData,
                percentComplete = percentComplete,
                isReady = eggData.steps >= eggData.requiredSteps,
                stepsRemaining = math.max(0, eggData.requiredSteps - eggData.steps)
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Sort eggs
Handlers.add("sort-eggs",
    Handlers.utils.hasMatchingTag("Action", "SortEggs"),
    function(msg)
        local data = msg.Data and json.decode(msg.Data) or {}
        local eggList = data.eggs or {}
        local sortBy = msg.SortBy or "steps"
        
        -- Sort eggs
        local sorted = sortEggs(eggList, sortBy)
        
        ao.send({
            Target = msg.From,
            Action = "EggsSorted",
            Success = "true",
            Data = json.encode({
                eggs = sorted,
                sortedBy = sortBy,
                count = #sorted
            }),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Apply incubation modifier
Handlers.add("apply-incubator",
    Handlers.utils.hasMatchingTag("Action", "ApplyIncubator"),
    function(msg)
        local eggId = msg.EggId
        local incubatorType = msg.IncubatorType
        local multiplier = tonumber(msg.Multiplier) or 1.0
        
        if not eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggId required"
            })
            return
        end
        
        if not incubatorType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "IncubatorType required"
            })
            return
        end
        
        -- Get modifier value
        local modifierValue = IncubationModifiers[string.upper(incubatorType)] or multiplier
        
        -- Calculate effective steps per tick
        local baseStepsPerTick = 10 -- Default step progression
        local effectiveStepsPerTick = math.floor(baseStepsPerTick * modifierValue)
        
        ao.send({
            Target = msg.From,
            Action = "IncubationUpdate",
            Success = "true",
            EggId = eggId,
            IncubatorType = incubatorType,
            NewMultiplier = tostring(modifierValue),
            EffectiveStepsPerTick = tostring(effectiveStepsPerTick),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Remove incubation modifier
Handlers.add("remove-incubator",
    Handlers.utils.hasMatchingTag("Action", "RemoveIncubator"),
    function(msg)
        local eggId = msg.EggId
        
        if not eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggId required"
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "IncubationUpdate",
            Success = "true",
            EggId = eggId,
            IncubatorType = "",
            NewMultiplier = "1",
            EffectiveStepsPerTick = "10",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Get hatch animation timing
Handlers.add("get-hatch-timing",
    Handlers.utils.hasMatchingTag("Action", "GetHatchTiming"),
    function(msg)
        local eggId = msg.EggId
        
        if not eggId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EggId required"
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "HatchTimingData",
            Success = "true",
            EggId = eggId,
            Data = json.encode({
                preHatchDuration = AnimationTiming.PRE_HATCH_DURATION,
                crackSequence = AnimationTiming.CRACK_SEQUENCE,
                revealDuration = AnimationTiming.REVEAL_DURATION,
                totalDuration = AnimationTiming.TOTAL_DURATION
            }),
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
            Action = "HealthCheck-Response",
            Status = "healthy",
            ProcessId = ao.id,
            Version = PROCESS_VERSION,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Process initialization complete
print("Egg Hatching Engine initialized - Version " .. PROCESS_VERSION)
print("ADP v1.0 compliant - Self-documenting process")
print("Ready to handle egg hatching, incubation, and Pokemon generation")