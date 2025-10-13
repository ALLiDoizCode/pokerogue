-- Environmental Cycle Engine
-- Purpose: Manages time-of-day cycles, pokemon pool updates, species form resolution, weather interactions
-- ADP Compliance: v1.0
-- Size Target: 15-25KB (3-5% of 500KB limit)

-- ============================================================================
-- ENUMS AND CONSTANTS
-- ============================================================================

local TimeOfDay = {
    ALL = -1,      -- Species available at all times
    DAWN = 0,      -- Wave 35-39 (cycle 35-39)
    DAY = 1,       -- Wave 0-14 (cycle 0-14)
    DUSK = 2,      -- Wave 15-19 (cycle 15-19)
    NIGHT = 3      -- Wave 20-34 (cycle 20-34)
}

local BiomeId = {
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

local BiomePoolTier = {
    COMMON = 0,
    UNCOMMON = 1,
    RARE = 2,
    SUPER_RARE = 3,
    ULTRA_RARE = 4,
    BOSS = 5,
    BOSS_RARE = 6,
    BOSS_SUPER_RARE = 7,
    BOSS_ULTRA_RARE = 8
}

-- ============================================================================
-- CORE FUNCTIONS
-- ============================================================================

-- Helper: Deep copy array
local function copyArray(arr)
    local result = {}
    for i = 1, #arr do
        result[i] = arr[i]
    end
    return result
end

-- Helper: Concatenate arrays
local function concatArrays(arr1, arr2)
    local result = copyArray(arr1)
    if arr2 then
        for i = 1, #arr2 do
            table.insert(result, arr2[i])
        end
    end
    return result
end

-- Calculate time of day based on wave cycle
-- TypeScript Reference: src/field/arena.ts lines 545-566
local function getTimeOfDay(wave, waveCycleOffset, biome)
    -- Input validation
    if not wave or type(wave) ~= "number" then
        return nil, "Wave must be a number"
    end

    if not waveCycleOffset or type(waveCycleOffset) ~= "number" then
        waveCycleOffset = 0
    end

    if not biome or type(biome) ~= "number" then
        return nil, "Biome must be a number"
    end

    -- Special biome handling: ABYSS always returns NIGHT
    if biome == BiomeId.ABYSS then
        return TimeOfDay.NIGHT
    end

    -- Calculate wave cycle (40-wave cycle)
    local waveCycle = (wave + waveCycleOffset) % 40

    -- Determine time of day based on wave cycle position
    if waveCycle < 15 then
        return TimeOfDay.DAY
    end

    if waveCycle < 20 then
        return TimeOfDay.DUSK
    end

    if waveCycle < 35 then
        return TimeOfDay.NIGHT
    end

    return TimeOfDay.DAWN
end

-- Update pokemon pools for time of day
-- TypeScript Reference: src/field/arena.ts lines 94-105
local function updatePoolsForTimeOfDay(biome, timeOfDay, lastTimeOfDay, biomePools)
    -- Input validation
    if not biome or type(biome) ~= "number" then
        return nil, nil, "Biome must be a number"
    end

    if not timeOfDay or type(timeOfDay) ~= "number" then
        return nil, nil, "TimeOfDay must be a number"
    end

    if not biomePools or type(biomePools) ~= "table" then
        return nil, nil, "BiomePools must be a table"
    end

    -- Optimization: Skip if time hasn't changed
    if timeOfDay == lastTimeOfDay then
        return {}, false, nil
    end

    -- Get biome-specific pools
    local biomeData = biomePools[biome]
    if not biomeData then
        return nil, nil, "Biome not found in biomePools"
    end

    -- Create merged pool for each tier
    local mergedPool = {}

    for tierName, tierValue in pairs(BiomePoolTier) do
        local tierPools = biomeData[tierValue]
        if tierPools then
            -- Start with ALL species (available at all times)
            local allSpecies = tierPools[TimeOfDay.ALL] or {}

            -- Concatenate time-specific species
            local timeSpecies = tierPools[timeOfDay] or {}

            mergedPool[tierValue] = concatArrays(allSpecies, timeSpecies)
        else
            mergedPool[tierValue] = {}
        end
    end

    return mergedPool, true, nil
end

-- Get species form index based on biome and time of day
-- TypeScript Reference: src/field/arena.ts lines 236-277
local function getSpeciesFormIndex(speciesId, biome, timeOfDay)
    -- Input validation
    if not speciesId or type(speciesId) ~= "number" then
        return 0
    end

    if not biome or type(biome) ~= "number" then
        return 0
    end

    if not timeOfDay or type(timeOfDay) ~= "number" then
        return 0
    end

    -- Lycanroc: Time-dependent forms
    -- Species ID 745 (Lycanroc)
    if speciesId == 745 then
        if timeOfDay == TimeOfDay.DAY or timeOfDay == TimeOfDay.DAWN then
            return 0  -- Midday form
        elseif timeOfDay == TimeOfDay.DUSK then
            return 2  -- Dusk form
        elseif timeOfDay == TimeOfDay.NIGHT then
            return 1  -- Midnight form
        end
    end

    -- Burmy: Biome-dependent forms
    -- Species ID 412 (Burmy)
    if speciesId == 412 then
        if biome == BiomeId.BEACH then
            return 1  -- Sandy Cloak
        elseif biome == BiomeId.SLUM then
            return 2  -- Trash Cloak
        end
        return 0  -- Plant Cloak (default)
    end

    -- Wormadam: Biome-dependent forms
    -- Species ID 413 (Wormadam)
    if speciesId == 413 then
        if biome == BiomeId.BEACH then
            return 1  -- Sandy Cloak
        elseif biome == BiomeId.SLUM then
            return 2  -- Trash Cloak
        end
        return 0  -- Plant Cloak (default)
    end

    -- Rotom: Biome-dependent forms
    -- Species ID 479 (Rotom)
    if speciesId == 479 then
        if biome == BiomeId.VOLCANO then
            return 1  -- Heat Rotom
        elseif biome == BiomeId.SEA then
            return 2  -- Wash Rotom
        elseif biome == BiomeId.ICE_CAVE then
            return 3  -- Frost Rotom
        elseif biome == BiomeId.MOUNTAIN then
            return 4  -- Fan Rotom
        elseif biome == BiomeId.TALL_GRASS then
            return 5  -- Mow Rotom
        end
        return 0  -- Base Rotom (default)
    end

    -- Default: No form change
    return 0
end

-- Get visual tint for time of day
-- TypeScript behavior inferred from story specs
local function getTintForTimeOfDay(timeOfDay)
    -- Input validation
    if not timeOfDay or type(timeOfDay) ~= "number" then
        return {128, 128, 128}  -- Neutral tint
    end

    -- Tint values based on time of day
    if timeOfDay == TimeOfDay.DAWN or timeOfDay == TimeOfDay.DAY then
        return {128, 128, 128}  -- Neutral
    elseif timeOfDay == TimeOfDay.DUSK then
        -- DUSK: Average of [98, 48, 73] and [128, 128, 128]
        return {113, 88, 100}
    elseif timeOfDay == TimeOfDay.NIGHT then
        return {64, 64, 64}  -- Dark
    end

    -- Default: Neutral tint
    return {128, 128, 128}
end

-- Validate weather-time interaction
-- TypeScript behavior: Weather persists across time changes
local function validateWeatherTimeInteraction(weatherType, turnsLeft, timeOfDay)
    -- Weather always valid with time of day
    -- Weather persists across time transitions
    -- Time change does not reset weather duration
    return true
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Handler: Get Time of Day
Handlers.add("get-time-of-day",
    Handlers.utils.hasMatchingTag("Action", "GetTimeOfDay"),
    function(msg)
        -- Extract parameters
        local wave = tonumber(msg.Wave)
        local biome = tonumber(msg.Biome)
        local waveCycleOffset = tonumber(msg.WaveCycleOffset) or 0

        -- Validate inputs
        if not wave then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Wave parameter required and must be a number"
            })
            return
        end

        if not biome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Biome parameter required and must be a number"
            })
            return
        end

        -- Calculate time of day
        local timeOfDay, err = getTimeOfDay(wave, waveCycleOffset, biome)

        if not timeOfDay then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err or "Failed to calculate time of day"
            })
            return
        end

        -- Calculate wave cycle
        local waveCycle = (wave + waveCycleOffset) % 40

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "TimeOfDay",
            Success = "true",
            Wave = tostring(wave),
            Biome = tostring(biome),
            TimeOfDay = tostring(timeOfDay),
            WaveCycle = tostring(waveCycle),
            WaveCycleOffset = tostring(waveCycleOffset)
        })
    end
)

-- Handler: Get Environmental State (Task 6)
Handlers.add("get-environmental-state",
    Handlers.utils.hasMatchingTag("Action", "GetEnvironmentalState"),
    function(msg)
        -- Extract parameters
        local wave = tonumber(msg.Wave)
        local biome = tonumber(msg.Biome)
        local waveCycleOffset = tonumber(msg.WaveCycleOffset) or 0
        local weatherType = tonumber(msg.WeatherType)
        local weatherTurnsLeft = tonumber(msg.WeatherTurnsLeft)

        -- Validate inputs
        if not wave then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Wave parameter required"
            })
            return
        end

        if not biome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Biome parameter required"
            })
            return
        end

        -- Calculate time of day
        local timeOfDay = getTimeOfDay(wave, waveCycleOffset, biome)
        local waveCycle = (wave + waveCycleOffset) % 40

        -- Calculate visual tint
        local tint = getTintForTimeOfDay(timeOfDay)

        -- Get form indices for time-dependent species
        local formIndices = {
            [745] = getSpeciesFormIndex(745, biome, timeOfDay),  -- Lycanroc
            [412] = getSpeciesFormIndex(412, biome, timeOfDay),  -- Burmy
            [413] = getSpeciesFormIndex(413, biome, timeOfDay),  -- Wormadam
            [479] = getSpeciesFormIndex(479, biome, timeOfDay)   -- Rotom
        }

        -- Build weather state
        local weatherState = nil
        if weatherType then
            weatherState = {
                weatherType = weatherType,
                turnsLeft = weatherTurnsLeft or 0
            }
        end

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "EnvironmentalState",
            Success = "true",
            Wave = tostring(wave),
            Biome = tostring(biome),
            TimeOfDay = tostring(timeOfDay),
            WaveCycle = tostring(waveCycle),
            VisualTintR = tostring(tint[1]),
            VisualTintG = tostring(tint[2]),
            VisualTintB = tostring(tint[3]),
            Data = json.encode({
                timeOfDay = timeOfDay,
                waveCycle = waveCycle,
                visualTint = tint,
                weatherState = weatherState,
                formIndices = formIndices
            })
        })
    end
)

-- Handler: Transition Time of Day (Task 7)
Handlers.add("transition-time-of-day",
    Handlers.utils.hasMatchingTag("Action", "TransitionTimeOfDay"),
    function(msg)
        -- Extract parameters
        local wave = tonumber(msg.Wave)
        local previousWave = tonumber(msg.PreviousWave)
        local biome = tonumber(msg.Biome)
        local waveCycleOffset = tonumber(msg.WaveCycleOffset) or 0
        local lastTimeOfDay = tonumber(msg.LastTimeOfDay)

        -- Validate inputs
        if not wave then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Wave parameter required"
            })
            return
        end

        if not biome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Biome parameter required"
            })
            return
        end

        -- Calculate time of day for current and previous wave
        local currentTimeOfDay = getTimeOfDay(wave, waveCycleOffset, biome)
        local previousTimeOfDay = lastTimeOfDay

        if not previousTimeOfDay and previousWave then
            previousTimeOfDay = getTimeOfDay(previousWave, waveCycleOffset, biome)
        end

        -- Check if time changed
        local transitioned = (previousTimeOfDay ~= nil and currentTimeOfDay ~= previousTimeOfDay)
        local poolUpdateRequired = transitioned

        -- Determine transition type
        local transitionType = ""
        if transitioned then
            if previousTimeOfDay == TimeOfDay.DAY and currentTimeOfDay == TimeOfDay.DUSK then
                transitionType = "day_to_dusk"
            elseif previousTimeOfDay == TimeOfDay.DUSK and currentTimeOfDay == TimeOfDay.NIGHT then
                transitionType = "dusk_to_night"
            elseif previousTimeOfDay == TimeOfDay.NIGHT and currentTimeOfDay == TimeOfDay.DAWN then
                transitionType = "night_to_dawn"
            elseif previousTimeOfDay == TimeOfDay.DAWN and currentTimeOfDay == TimeOfDay.DAY then
                transitionType = "dawn_to_day"
            else
                transitionType = "other"
            end
        end

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "TimeTransitioned",
            Success = "true",
            Wave = tostring(wave),
            PreviousTimeOfDay = previousTimeOfDay and tostring(previousTimeOfDay) or "",
            NewTimeOfDay = tostring(currentTimeOfDay),
            TransitionType = transitionType,
            PoolUpdateRequired = tostring(poolUpdateRequired),
            MilestoneReached = "false",  -- Milestone tracking would require additional state
            Data = json.encode({
                previousTime = previousTimeOfDay,
                newTime = currentTimeOfDay,
                transitionType = transitionType,
                poolUpdateRequired = poolUpdateRequired,
                milestoneReached = false
            })
        })
    end
)

-- Handler: Validate Environmental State (Task 8)
Handlers.add("validate-environmental-state",
    Handlers.utils.hasMatchingTag("Action", "ValidateEnvironmentalState"),
    function(msg)
        -- Extract parameters
        local wave = tonumber(msg.Wave)
        local biome = tonumber(msg.Biome)
        local claimedTimeOfDay = tonumber(msg.TimeOfDay)
        local waveCycleOffset = tonumber(msg.WaveCycleOffset) or 0

        -- Validate inputs
        if not wave then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Wave parameter required"
            })
            return
        end

        if not biome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Biome parameter required"
            })
            return
        end

        if not claimedTimeOfDay then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TimeOfDay parameter required"
            })
            return
        end

        -- Calculate expected time of day
        local expectedTimeOfDay = getTimeOfDay(wave, waveCycleOffset, biome)

        -- Validate
        local valid = (expectedTimeOfDay == claimedTimeOfDay)
        local validationErrors = {}

        if not valid then
            table.insert(validationErrors, "Time of day mismatch: expected " .. tostring(expectedTimeOfDay) .. ", got " .. tostring(claimedTimeOfDay))
        end

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "StateValidated",
            Success = "true",
            Valid = tostring(valid),
            ExpectedTimeOfDay = tostring(expectedTimeOfDay),
            ActualTimeOfDay = tostring(claimedTimeOfDay),
            ValidationErrors = #validationErrors > 0 and table.concat(validationErrors, "; ") or "",
            Data = json.encode({
                valid = valid,
                expectedTime = expectedTimeOfDay,
                actualTime = claimedTimeOfDay,
                validationErrors = validationErrors
            })
        })
    end
)

-- Handler: Info (ADP v1.0 compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            ProcessId = ao.id,
            Data = json.encode({
                process = {
                    name = "Environmental Cycle Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    processId = ao.id,
                    capabilities = {
                        "GetTimeOfDay",
                        "GetEnvironmentalState",
                        "TransitionTimeOfDay",
                        "ValidateEnvironmentalState"
                    },
                    messageSchemas = {
                        GetTimeOfDay = {
                            required = {"Action", "Wave", "Biome"},
                            optional = {"WaveCycleOffset"}
                        },
                        GetEnvironmentalState = {
                            required = {"Action", "Wave", "Biome"},
                            optional = {"WaveCycleOffset", "WeatherType", "WeatherTurnsLeft"}
                        },
                        TransitionTimeOfDay = {
                            required = {"Action", "Wave", "Biome"},
                            optional = {"PreviousWave", "WaveCycleOffset", "LastTimeOfDay"}
                        },
                        ValidateEnvironmentalState = {
                            required = {"Action", "Wave", "Biome", "TimeOfDay"},
                            optional = {"WaveCycleOffset"}
                        }
                    }
                },
                handlers = {
                    "get-time-of-day",
                    "get-environmental-state",
                    "transition-time-of-day",
                    "validate-environmental-state",
                    "info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Manages environmental cycles including time-of-day, pokemon pool updates, species forms, and visual tints"
                }
            })
        })
    end
)

print("Environmental Cycle Engine initialized successfully")
