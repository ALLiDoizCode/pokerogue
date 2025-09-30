local json = require("json")

-- Initialize process state
if not BreedingState then
    BreedingState = {
        initialized = true,
        version = "1.0",
        breedingHistory = {},
        playerStats = {}
    }
end

-- Player Breeding History Storage
if not PlayerBreedingHistory then
    PlayerBreedingHistory = {}
end

-- Security and Rate Limiting
local SECURITY_CONFIG = {
    maxBreedingOperationsPerMinute = 30,
    maxHistoryEntriesPerPlayer = 1000,
    allowedPlayerIdPattern = "^[a-zA-Z0-9_-]+$",
    allowedPokemonIdPattern = "^[a-zA-Z0-9_-]+$"
}

-- Rate limiting storage
if not RateLimitingData then
    RateLimitingData = {}
end

-- Embedded Egg Group Compatibility Matrix
local EGG_GROUP_COMPATIBILITY = {
    ["monster"] = {"monster", "dragon", "ditto"},
    ["dragon"] = {"monster", "dragon", "ditto"},
    ["water1"] = {"water1", "water2", "dragon", "ditto"},
    ["water2"] = {"water1", "water2", "ditto"},
    ["bug"] = {"bug", "ditto"},
    ["flying"] = {"flying", "ditto"},
    ["field"] = {"field", "ditto"},
    ["fairy"] = {"fairy", "ditto"},
    ["grass"] = {"grass", "ditto"},
    ["human-like"] = {"human-like", "ditto"},
    ["mineral"] = {"mineral", "ditto"},
    ["amorphous"] = {"amorphous", "ditto"},
    ["water3"] = {"water3", "ditto"},
    ["undiscovered"] = {}, -- Cannot breed
    ["ditto"] = {"*"} -- Special case - can breed with most groups except undiscovered
}

-- Species Breeding Data (Essential subset for compatibility validation)
local SPECIES_BREEDING_DATA = {
    [1] = { -- Bulbasaur
        eggGroups = {"monster", "grass"},
        genderRatio = {male = 87.5, female = 12.5},
        baseBreedingRate = 0.25,
        breedingCooldown = 256,
        canBreed = true
    },
    [4] = { -- Charmander  
        eggGroups = {"monster", "dragon"},
        genderRatio = {male = 87.5, female = 12.5},
        baseBreedingRate = 0.25,
        breedingCooldown = 256,
        canBreed = true
    },
    [7] = { -- Squirtle
        eggGroups = {"monster", "water1"},
        genderRatio = {male = 87.5, female = 12.5},
        baseBreedingRate = 0.25,
        breedingCooldown = 256,
        canBreed = true
    },
    [132] = { -- Ditto
        eggGroups = {"ditto"},
        genderRatio = {genderless = 100},
        baseBreedingRate = 1.0,
        breedingCooldown = 256,
        canBreed = true,
        specialConditions = {"cannot_breed_with_genderless", "cannot_breed_with_baby"}
    },
    [150] = { -- Mewtwo (Legendary - Cannot breed)
        eggGroups = {"undiscovered"},
        genderRatio = {genderless = 100},
        baseBreedingRate = 0.0,
        breedingCooldown = 0,
        canBreed = false,
        restrictions = {"legendary"}
    }
}

-- Breeding Restrictions
local BREEDING_RESTRICTIONS = {
    cannotBreed = {
        "baby_pokemon",
        "legendary", 
        "mythical",
        "ultra_beast"
    },
    itemRequirements = {
        ["sea_incense"] = {
            requiredFor = {183}, -- Marill line for Azurill
            effect = "enables_azurill_breeding"
        },
        ["luck_incense"] = {
            requiredFor = {113}, -- Chansey line for Happiny  
            effect = "enables_happiny_breeding"
        },
        ["rose_incense"] = {
            requiredFor = {315}, -- Roselia line for Budew
            effect = "enables_budew_breeding"
        },
        ["odd_incense"] = {
            requiredFor = {122}, -- Mr. Mime line for Mime Jr.
            effect = "enables_mime_jr_breeding"
        }
    },
    specialConditions = {
        regionalForms = {
            [25] = { -- Pikachu regional forms
                offspring = 172, -- Pichu
                conditions = {"everstone_required_for_regional_form"}
            }
        },
        hybridBreeding = {
            nidoran = { -- Nidoran F + M (species 29 and 32)
                parents = {29, 32},
                offspring = {29, 32}, -- Can produce either gender
                probability = {female = 0.5, male = 0.5}
            },
            volbeat_illumise = { -- Volbeat + Illumise (species 313 and 314)
                parents = {313, 314},
                offspring = {313, 314},
                probability = {volbeat = 0.5, illumise = 0.5}
            }
        },
        babyPokemon = {
            [172] = { -- Pichu
                parents = {25, 26}, -- Pikachu, Raichu
                requiredItem = nil
            },
            [173] = { -- Cleffa  
                parents = {35, 36}, -- Clefairy, Clefable
                requiredItem = nil
            },
            [174] = { -- Igglybuff
                parents = {39, 40}, -- Jigglypuff, Wigglytuff
                requiredItem = nil
            },
            [175] = { -- Togepi
                parents = {176, 468}, -- Togetic, Togekiss
                requiredItem = nil
            },
            [238] = { -- Smoochum
                parents = {124}, -- Jynx
                requiredItem = nil
            },
            [239] = { -- Elekid
                parents = {125, 466}, -- Electabuzz, Electivire
                requiredItem = nil
            },
            [240] = { -- Magby
                parents = {126, 467}, -- Magmar, Magmortar
                requiredItem = nil
            },
            [298] = { -- Azurill
                parents = {183, 184}, -- Marill, Azumarill
                requiredItem = "sea_incense"
            },
            [360] = { -- Wynaut
                parents = {202}, -- Wobbuffet
                requiredItem = "lax_incense"
            },
            [406] = { -- Budew
                parents = {315, 407}, -- Roselia, Roserade
                requiredItem = "rose_incense"
            },
            [433] = { -- Chingling
                parents = {358}, -- Chimecho
                requiredItem = "pure_incense"
            },
            [438] = { -- Bonsly
                parents = {185}, -- Sudowoodo
                requiredItem = "rock_incense"
            },
            [439] = { -- Mime Jr.
                parents = {122}, -- Mr. Mime
                requiredItem = "odd_incense"
            },
            [440] = { -- Happiny
                parents = {113, 242}, -- Chansey, Blissey
                requiredItem = "luck_incense"
            },
            [446] = { -- Munchlax
                parents = {143}, -- Snorlax
                requiredItem = "full_incense"
            },
            [447] = { -- Riolu
                parents = {448}, -- Lucario
                requiredItem = nil
            },
            [458] = { -- Mantyke
                parents = {226}, -- Mantine
                requiredItem = "wave_incense"
            }
        }
    }
}

-- Success Rate Modifiers
local SUCCESS_RATE_MODIFIERS = {
    baseRates = {
        same_species = 0.75,
        compatible_species = 0.50, 
        ditto_breeding = 0.50,
        low_compatibility = 0.25
    },
    modifiers = {
        maxLevelBonus = 0.15,
        levelPenalty = 0.05,
        maxFriendshipBonus = 0.20,
        friendshipThreshold = 220,
        itemEffects = {
            oval_charm = 0.15,
            destiny_knot = 0.0,
            everstone = 0.0
        }
    },
    constraints = {
        minimum = 0.01,
        maximum = 0.95
    }
}

-- Security and Validation Functions
local function validatePlayerId(playerId)
    if not playerId or type(playerId) ~= "string" then
        return false, "Invalid player ID type"
    end
    
    if #playerId < 1 or #playerId > 100 then
        return false, "Player ID length out of range"
    end
    
    if not string.match(playerId, SECURITY_CONFIG.allowedPlayerIdPattern) then
        return false, "Player ID contains invalid characters"
    end
    
    return true, "Valid player ID"
end

local function validatePokemonId(pokemonId)
    if not pokemonId or type(pokemonId) ~= "string" then
        return false, "Invalid Pokemon ID type"
    end
    
    if #pokemonId < 1 or #pokemonId > 100 then
        return false, "Pokemon ID length out of range"
    end
    
    if not string.match(pokemonId, SECURITY_CONFIG.allowedPokemonIdPattern) then
        return false, "Pokemon ID contains invalid characters"
    end
    
    return true, "Valid Pokemon ID"
end

local function checkRateLimit(playerId, operation, timestamp)
    timestamp = timestamp or 0
    local currentMinute = math.floor(timestamp / 60)
    
    if not RateLimitingData[playerId] then
        RateLimitingData[playerId] = {}
    end
    
    if not RateLimitingData[playerId][currentMinute] then
        RateLimitingData[playerId][currentMinute] = 0
    end
    
    if RateLimitingData[playerId][currentMinute] >= SECURITY_CONFIG.maxBreedingOperationsPerMinute then
        return false, "Rate limit exceeded: " .. SECURITY_CONFIG.maxBreedingOperationsPerMinute .. " operations per minute"
    end
    
    RateLimitingData[playerId][currentMinute] = RateLimitingData[playerId][currentMinute] + 1
    
    -- Clean old rate limiting data (keep only last 2 minutes)
    for minute, _ in pairs(RateLimitingData[playerId]) do
        if minute < currentMinute - 1 then
            RateLimitingData[playerId][minute] = nil
        end
    end
    
    return true, "Rate limit check passed"
end

local function sanitizeInput(input)
    if type(input) == "string" then
        -- Remove potential injection characters
        input = string.gsub(input, "[<>\"'&]", "")
        -- Limit length
        if #input > 1000 then
            input = string.sub(input, 1, 1000)
        end
    end
    return input
end

local function enforceDataProtection(playerId, requestingPlayer)
    -- Players can only access their own breeding data
    if playerId ~= requestingPlayer then
        return false, "Access denied: Cannot access other player's breeding data"
    end
    return true, "Data access authorized"
end

-- Utility Functions
local function getSpeciesBreedingData(speciesId)
    return SPECIES_BREEDING_DATA[tonumber(speciesId)]
end

local function checkEggGroupCompatibility(eggGroups1, eggGroups2)
    if not eggGroups1 or not eggGroups2 then
        return false, "Missing egg group data"
    end
    
    -- Check if either contains "undiscovered" (cannot breed)
    for _, group in ipairs(eggGroups1) do
        if group == "undiscovered" then
            return false, "Species cannot breed (undiscovered egg group)"
        end
    end
    for _, group in ipairs(eggGroups2) do
        if group == "undiscovered" then
            return false, "Species cannot breed (undiscovered egg group)"
        end
    end
    
    -- Special Ditto handling
    for _, group1 in ipairs(eggGroups1) do
        if group1 == "ditto" then
            -- Ditto can breed with anything except undiscovered and other Ditto
            for _, group2 in ipairs(eggGroups2) do
                if group2 ~= "ditto" and group2 ~= "undiscovered" then
                    return true, "Ditto compatibility confirmed"
                end
            end
            return false, "Ditto cannot breed with this species"
        end
    end
    
    for _, group2 in ipairs(eggGroups2) do
        if group2 == "ditto" then
            -- Other species with Ditto
            for _, group1 in ipairs(eggGroups1) do
                if group1 ~= "ditto" and group1 ~= "undiscovered" then
                    return true, "Ditto compatibility confirmed"
                end
            end
            return false, "This species cannot breed with Ditto"
        end
    end
    
    -- Standard egg group compatibility
    for _, group1 in ipairs(eggGroups1) do
        local compatibleGroups = EGG_GROUP_COMPATIBILITY[group1]
        if compatibleGroups then
            for _, group2 in ipairs(eggGroups2) do
                for _, compatGroup in ipairs(compatibleGroups) do
                    if group2 == compatGroup then
                        return true, "Compatible egg groups: " .. group1 .. " + " .. group2
                    end
                end
            end
        end
    end
    
    return false, "No compatible egg groups found"
end

local function validateGenderRequirements(pokemon1, pokemon2)
    if not pokemon1 or not pokemon2 then
        return false, "Missing Pokemon data"
    end
    
    local gender1 = pokemon1.gender or "unknown"
    local gender2 = pokemon2.gender or "unknown"
    local species1Data = getSpeciesBreedingData(pokemon1.speciesId)
    local species2Data = getSpeciesBreedingData(pokemon2.speciesId)
    
    if not species1Data or not species2Data then
        return false, "Missing species breeding data"
    end
    
    -- Check if either is Ditto
    local isDitto1 = false
    local isDitto2 = false
    for _, group in ipairs(species1Data.eggGroups) do
        if group == "ditto" then isDitto1 = true break end
    end
    for _, group in ipairs(species2Data.eggGroups) do
        if group == "ditto" then isDitto2 = true break end
    end
    
    -- Ditto can breed with any gender (except other Ditto)
    if isDitto1 and not isDitto2 then
        return true, "Ditto can breed with any gender"
    end
    if isDitto2 and not isDitto1 then
        return true, "Ditto can breed with any gender"
    end
    if isDitto1 and isDitto2 then
        return false, "Two Ditto cannot breed together"
    end
    
    -- Genderless Pokemon can only breed with Ditto
    if gender1 == "genderless" or gender2 == "genderless" then
        return false, "Genderless Pokemon can only breed with Ditto"
    end
    
    -- Standard gender requirements (opposite gender)
    if gender1 == "male" and gender2 == "female" then
        return true, "Opposite genders - compatible"
    end
    if gender1 == "female" and gender2 == "male" then
        return true, "Opposite genders - compatible"
    end
    
    return false, "Same gender - incompatible for breeding"
end

local function calculateSuccessRate(pokemon1, pokemon2, modifiers)
    local species1Data = getSpeciesBreedingData(pokemon1.speciesId)
    local species2Data = getSpeciesBreedingData(pokemon2.speciesId)
    
    if not species1Data or not species2Data then
        return 0, "Missing species data"
    end
    
    -- Determine base rate
    local baseRate = SUCCESS_RATE_MODIFIERS.baseRates.low_compatibility
    
    if pokemon1.speciesId == pokemon2.speciesId then
        baseRate = SUCCESS_RATE_MODIFIERS.baseRates.same_species
    else
        -- Check if Ditto is involved
        local isDittoBreeding = false
        for _, group in ipairs(species1Data.eggGroups) do
            if group == "ditto" then isDittoBreeding = true break end
        end
        for _, group in ipairs(species2Data.eggGroups) do
            if group == "ditto" then isDittoBreeding = true break end
        end
        
        if isDittoBreeding then
            baseRate = SUCCESS_RATE_MODIFIERS.baseRates.ditto_breeding
        else
            baseRate = SUCCESS_RATE_MODIFIERS.baseRates.compatible_species
        end
    end
    
    -- Apply modifiers
    local finalRate = baseRate
    local appliedModifiers = {}
    
    if modifiers then
        -- Level difference modifier
        if modifiers.levelDifferenceBonus and pokemon1.level and pokemon2.level then
            local levelDiff = math.abs(pokemon1.level - pokemon2.level)
            local levelBonus = math.max(0, SUCCESS_RATE_MODIFIERS.modifiers.maxLevelBonus - (levelDiff * 0.01))
            finalRate = finalRate + levelBonus
            appliedModifiers.levelBonus = levelBonus
        end
        
        -- Friendship modifier
        if modifiers.friendshipBonus then
            local avgFriendship = ((pokemon1.friendship or 0) + (pokemon2.friendship or 0)) / 2
            local friendshipBonus = (avgFriendship / 255) * SUCCESS_RATE_MODIFIERS.modifiers.maxFriendshipBonus
            finalRate = finalRate + friendshipBonus
            appliedModifiers.friendshipBonus = friendshipBonus
        end
        
        -- Item effects
        if modifiers.itemEffects then
            if modifiers.items and modifiers.items.oval_charm then
                finalRate = finalRate + SUCCESS_RATE_MODIFIERS.modifiers.itemEffects.oval_charm
                appliedModifiers.ovalCharmBonus = SUCCESS_RATE_MODIFIERS.modifiers.itemEffects.oval_charm
            end
        end
    end
    
    -- Apply constraints
    finalRate = math.max(SUCCESS_RATE_MODIFIERS.constraints.minimum, 
                        math.min(SUCCESS_RATE_MODIFIERS.constraints.maximum, finalRate))
    
    return finalRate, "Success rate calculated", appliedModifiers
end

local function calculateBreedingTime(species1Id, species2Id, modifiers)
    local baseSteps = 256 -- Standard breeding cycle
    local finalSteps = baseSteps
    
    -- Apply modifiers if provided
    if modifiers then
        if modifiers.items and modifiers.items.oval_charm then
            finalSteps = math.floor(finalSteps * 0.85) -- 15% faster
        end
        if modifiers.items and modifiers.items.flame_body then
            finalSteps = math.floor(finalSteps * 0.50) -- 50% faster for hatching
        end
    end
    
    return {
        breedingDuration = finalSteps,
        eggGenerationTime = finalSteps,
        cooldownPeriod = finalSteps
    }
end

-- Breeding History Management Functions
local function recordBreedingAttempt(playerId, pokemon1Id, pokemon2Id, success, successRate, timestamp)
    if not PlayerBreedingHistory[playerId] then
        PlayerBreedingHistory[playerId] = {
            attempts = {},
            statistics = {
                totalAttempts = 0,
                successfulBreedings = 0,
                eggsGenerated = 0,
                averageSuccessRate = 0.0,
                breedingStreak = 0
            }
        }
    end
    
    local attemptId = #PlayerBreedingHistory[playerId].attempts + 1
    local attempt = {
        attemptId = attemptId,
        parent1 = pokemon1Id,
        parent2 = pokemon2Id,
        timestamp = timestamp or 0,
        success = success,
        successRate = successRate or 0,
        duration = 256 -- Default breeding duration
    }
    
    table.insert(PlayerBreedingHistory[playerId].attempts, attempt)
    
    -- Update statistics
    local stats = PlayerBreedingHistory[playerId].statistics
    stats.totalAttempts = stats.totalAttempts + 1
    
    if success then
        stats.successfulBreedings = stats.successfulBreedings + 1
        stats.eggsGenerated = stats.eggsGenerated + 1
        stats.breedingStreak = stats.breedingStreak + 1
    else
        stats.breedingStreak = 0
    end
    
    -- Calculate average success rate
    local totalRate = 0
    for _, prevAttempt in ipairs(PlayerBreedingHistory[playerId].attempts) do
        totalRate = totalRate + (prevAttempt.successRate or 0)
    end
    stats.averageSuccessRate = totalRate / stats.totalAttempts
    
    return attempt
end

local function getBreedingStatistics(playerId)
    if not PlayerBreedingHistory[playerId] then
        return {
            totalAttempts = 0,
            successfulBreedings = 0,
            eggsGenerated = 0,
            averageSuccessRate = 0.0,
            breedingStreak = 0,
            recentAttempts = {}
        }
    end
    
    local stats = PlayerBreedingHistory[playerId].statistics
    local recentAttempts = {}
    
    -- Get last 5 attempts
    local attempts = PlayerBreedingHistory[playerId].attempts
    local startIndex = math.max(1, #attempts - 4)
    for i = startIndex, #attempts do
        table.insert(recentAttempts, attempts[i])
    end
    
    return {
        totalAttempts = stats.totalAttempts,
        successfulBreedings = stats.successfulBreedings,
        eggsGenerated = stats.eggsGenerated,
        averageSuccessRate = stats.averageSuccessRate,
        breedingStreak = stats.breedingStreak,
        recentAttempts = recentAttempts
    }
end

local function validateBreedingRestrictions(pokemon1, pokemon2, items)
    local restrictions = {}
    
    -- Check if either Pokemon cannot breed
    local species1Data = getSpeciesBreedingData(pokemon1.speciesId)
    local species2Data = getSpeciesBreedingData(pokemon2.speciesId)
    
    if not species1Data or not species2Data then
        table.insert(restrictions, "Missing species data")
        return false, restrictions
    end
    
    if not species1Data.canBreed then
        table.insert(restrictions, "Species " .. pokemon1.speciesId .. " cannot breed")
    end
    
    if not species2Data.canBreed then
        table.insert(restrictions, "Species " .. pokemon2.speciesId .. " cannot breed")
    end
    
    -- Check baby Pokemon restrictions
    for _, babyData in pairs(BREEDING_RESTRICTIONS.specialConditions.babyPokemon) do
        if babyData.requiredItem then
            local hasRequiredItem = items and (items[babyData.requiredItem] or items.item1 == babyData.requiredItem or items.item2 == babyData.requiredItem)
            if not hasRequiredItem then
                for _, parentId in ipairs(babyData.parents) do
                    if pokemon1.speciesId == parentId or pokemon2.speciesId == parentId then
                        table.insert(restrictions, "Required item missing: " .. babyData.requiredItem)
                        break
                    end
                end
            end
        end
    end
    
    if #restrictions > 0 then
        return false, restrictions
    end
    
    return true, {}
end

-- Main Handler Functions
local function validateBreedingPair(pokemon1Id, pokemon2Id, playerId)
    -- This would normally fetch Pokemon data from pokemon-instance-manager
    -- For now, return mock validation structure
    
    local result = {
        isCompatible = false,
        eggGroupMatch = false,
        genderCompatible = false,
        restrictionsPassed = false,
        reasons = {}
    }
    
    -- Validate input parameters
    if not pokemon1Id or not pokemon2Id then
        table.insert(result.reasons, "Missing Pokemon IDs")
        return result
    end
    
    if pokemon1Id == pokemon2Id then
        table.insert(result.reasons, "Cannot breed Pokemon with itself")
        return result
    end
    
    -- Mock Pokemon data (would come from cross-process call)
    local pokemon1 = {
        id = pokemon1Id,
        speciesId = 1, -- Bulbasaur
        level = 50,
        gender = "male",
        friendship = 220
    }
    
    local pokemon2 = {
        id = pokemon2Id,
        speciesId = 4, -- Charmander  
        level = 45,
        gender = "female",
        friendship = 200
    }
    
    -- Get species data
    local species1Data = getSpeciesBreedingData(pokemon1.speciesId)
    local species2Data = getSpeciesBreedingData(pokemon2.speciesId)
    
    if not species1Data or not species2Data then
        table.insert(result.reasons, "Species breeding data not found")
        return result
    end
    
    -- Check breeding restrictions
    if not species1Data.canBreed or not species2Data.canBreed then
        table.insert(result.reasons, "One or both species cannot breed")
        return result
    end
    
    -- Check egg group compatibility
    local eggGroupCompatible, eggGroupReason = checkEggGroupCompatibility(
        species1Data.eggGroups, 
        species2Data.eggGroups
    )
    result.eggGroupMatch = eggGroupCompatible
    if not eggGroupCompatible then
        table.insert(result.reasons, eggGroupReason)
    end
    
    -- Check gender requirements
    local genderCompatible, genderReason = validateGenderRequirements(pokemon1, pokemon2)
    result.genderCompatible = genderCompatible
    if not genderCompatible then
        table.insert(result.reasons, genderReason)
    end
    
    -- All checks passed
    result.restrictionsPassed = true
    result.isCompatible = result.eggGroupMatch and result.genderCompatible and result.restrictionsPassed
    
    return result
end

-- AO Message Handlers

-- Main breeding compatibility validation handler
Handlers.add("validate-breeding-pair",
    Handlers.utils.hasMatchingTag("Action", "ValidateBreedingPair"),
    function(msg)
        -- Security validation
        local pokemon1Id = sanitizeInput(msg.Pokemon1Id or msg.Pokemon1)
        local pokemon2Id = sanitizeInput(msg.Pokemon2Id or msg.Pokemon2)
        local playerId = sanitizeInput(msg.PlayerId or msg.From)
        
        -- Validate required parameters
        if not pokemon1Id or not pokemon2Id then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: Pokemon1Id and Pokemon2Id"
            })
            return
        end
        
        -- Validate input format
        local playerValid, playerError = validatePlayerId(playerId)
        if not playerValid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid player ID: " .. playerError
            })
            return
        end
        
        local pokemon1Valid, pokemon1Error = validatePokemonId(pokemon1Id)
        if not pokemon1Valid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid Pokemon1 ID: " .. pokemon1Error
            })
            return
        end
        
        local pokemon2Valid, pokemon2Error = validatePokemonId(pokemon2Id)
        if not pokemon2Valid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid Pokemon2 ID: " .. pokemon2Error
            })
            return
        end
        
        -- Check rate limiting
        local rateLimitOk, rateLimitError = checkRateLimit(playerId, "validate_breeding_pair", msg.Timestamp)
        if not rateLimitOk then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = rateLimitError
            })
            return
        end
        
        -- Enforce data protection
        local accessOk, accessError = enforceDataProtection(playerId, msg.From)
        if not accessOk then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = accessError
            })
            return
        end
        
        local compatibilityResult = validateBreedingPair(pokemon1Id, pokemon2Id, playerId)
        
        ao.send({
            Target = msg.From,
            Action = "BreedingCompatibilityResult",
            Success = tostring(compatibilityResult.isCompatible),
            EggGroupMatch = tostring(compatibilityResult.eggGroupMatch),
            GenderCompatible = tostring(compatibilityResult.genderCompatible),
            RestrictionsPass = tostring(compatibilityResult.restrictionsPassed),
            Data = json.encode({
                compatibility = compatibilityResult,
                timestamp = msg.Timestamp or 0
            })
        })
    end
)

-- Breeding success rate calculation handler
Handlers.add("calculate-success-rate",
    Handlers.utils.hasMatchingTag("Action", "CalculateSuccessRate"),
    function(msg)
        local pokemon1Id = msg.Pokemon1Id or msg.Pokemon1
        local pokemon2Id = msg.Pokemon2Id or msg.Pokemon2
        
        if not pokemon1Id or not pokemon2Id then
            ao.send({
                Target = msg.From,
                Action = "Error", 
                Error = "Missing required parameters: Pokemon1Id and Pokemon2Id"
            })
            return
        end
        
        -- Mock Pokemon data (would come from cross-process calls)
        local pokemon1 = {
            speciesId = 1,
            level = 50,
            friendship = 220
        }
        
        local pokemon2 = {
            speciesId = 4,
            level = 45, 
            friendship = 200
        }
        
        local modifiers = {
            levelDifferenceBonus = true,
            friendshipBonus = true,
            itemEffects = true,
            items = {
                oval_charm = msg.OvalCharm == "true"
            }
        }
        
        local successRate, reason, appliedModifiers = calculateSuccessRate(pokemon1, pokemon2, modifiers)
        
        ao.send({
            Target = msg.From,
            Action = "SuccessRateResult",
            SuccessRate = tostring(successRate),
            BaseRate = tostring(SUCCESS_RATE_MODIFIERS.baseRates.compatible_species),
            Data = json.encode({
                successRate = successRate,
                reason = reason,
                modifiers = appliedModifiers,
                timestamp = msg.Timestamp or 0
            })
        })
    end
)

-- Breeding time calculation handler
Handlers.add("calculate-breeding-time",
    Handlers.utils.hasMatchingTag("Action", "CalculateBreedingTime"),
    function(msg)
        local species1Id = tonumber(msg.Species1Id or msg.Species1 or 1)
        local species2Id = tonumber(msg.Species2Id or msg.Species2 or 1)
        
        local modifiers = {
            items = {
                oval_charm = msg.OvalCharm == "true",
                flame_body = msg.FlameBody == "true"
            }
        }
        
        local timing = calculateBreedingTime(species1Id, species2Id, modifiers)
        
        ao.send({
            Target = msg.From,
            Action = "BreedingTimeResult",
            BreedingDuration = tostring(timing.breedingDuration),
            EggGenerationTime = tostring(timing.eggGenerationTime),
            CooldownPeriod = tostring(timing.cooldownPeriod),
            Data = json.encode({
                timing = timing,
                timestamp = msg.Timestamp or 0
            })
        })
    end
)

-- Breeding statistics handler
Handlers.add("get-breeding-statistics",
    Handlers.utils.hasMatchingTag("Action", "GetBreedingStatistics"),
    function(msg)
        local playerId = msg.PlayerId or msg.From
        local statistics = getBreedingStatistics(playerId)
        
        ao.send({
            Target = msg.From,
            Action = "BreedingStatistics",
            TotalAttempts = tostring(statistics.totalAttempts),
            SuccessfulBreedings = tostring(statistics.successfulBreedings),
            EggsGenerated = tostring(statistics.eggsGenerated),
            AverageSuccessRate = tostring(statistics.averageSuccessRate),
            BreedingStreak = tostring(statistics.breedingStreak),
            Data = json.encode({
                statistics = statistics,
                timestamp = msg.Timestamp or 0
            })
        })
    end
)

-- Record breeding attempt handler
Handlers.add("record-breeding-attempt",
    Handlers.utils.hasMatchingTag("Action", "RecordBreedingAttempt"),
    function(msg)
        local playerId = msg.PlayerId or msg.From
        local pokemon1Id = msg.Pokemon1Id or msg.Pokemon1
        local pokemon2Id = msg.Pokemon2Id or msg.Pokemon2
        local success = msg.Success == "true"
        local successRate = tonumber(msg.SuccessRate) or 0
        
        if not pokemon1Id or not pokemon2Id then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: Pokemon1Id and Pokemon2Id"
            })
            return
        end
        
        local attempt = recordBreedingAttempt(playerId, pokemon1Id, pokemon2Id, success, successRate, msg.Timestamp)
        
        ao.send({
            Target = msg.From,
            Action = "BreedingAttemptRecorded",
            AttemptId = tostring(attempt.attemptId),
            Success = tostring(success),
            Data = json.encode({
                attempt = attempt,
                timestamp = msg.Timestamp or 0
            })
        })
    end
)

-- Validate breeding restrictions handler
Handlers.add("validate-breeding-restrictions",
    Handlers.utils.hasMatchingTag("Action", "ValidateBreedingRestrictions"),
    function(msg)
        local pokemon1Id = msg.Pokemon1Id or msg.Pokemon1
        local pokemon2Id = msg.Pokemon2Id or msg.Pokemon2
        
        if not pokemon1Id or not pokemon2Id then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required parameters: Pokemon1Id and Pokemon2Id"
            })
            return
        end
        
        -- Mock Pokemon data (would come from cross-process calls)
        local pokemon1 = {
            id = pokemon1Id,
            speciesId = tonumber(msg.Species1Id) or 1,
            level = tonumber(msg.Level1) or 50,
            gender = msg.Gender1 or "male"
        }
        
        local pokemon2 = {
            id = pokemon2Id,
            speciesId = tonumber(msg.Species2Id) or 4,
            level = tonumber(msg.Level2) or 45,
            gender = msg.Gender2 or "female"
        }
        
        local items = nil
        if msg.Items then
            items = json.decode(msg.Items)
        end
        
        local restrictionsPassed, restrictions = validateBreedingRestrictions(pokemon1, pokemon2, items)
        
        ao.send({
            Target = msg.From,
            Action = "BreedingRestrictionsResult",
            RestrictionsPassed = tostring(restrictionsPassed),
            RestrictionsCount = tostring(#restrictions),
            Data = json.encode({
                restrictionsPassed = restrictionsPassed,
                restrictions = restrictions,
                timestamp = msg.Timestamp or 0
            })
        })
    end
)

-- Process health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus", 
            Status = "healthy",
            Version = BreedingState.version,
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            Name = "Breeding Compatibility Engine",
            Description = "Pokemon breeding compatibility validation and success rate calculation process",
            Version = "1.0.0",
            ProcessId = ao.id,
            Owner = ao.env and ao.env.Process and ao.env.Process.Owner or "unknown",
            protocolVersion = "1.0",
            adpVersion = "1.0",
            lastUpdated = "2025-01-05T00:00:00.000Z",
            handlers = {
                {
                    action = "ValidateBreedingPair",
                    pattern = {"Action"},
                    description = "Validate breeding compatibility between two Pokemon",
                    category = "breeding",
                    parameters = {
                        {
                            name = "Pokemon1Id",
                            type = "string",
                            required = true,
                            description = "First Pokemon instance ID"
                        },
                        {
                            name = "Pokemon2Id", 
                            type = "string",
                            required = true,
                            description = "Second Pokemon instance ID"
                        },
                        {
                            name = "PlayerId",
                            type = "string", 
                            required = false,
                            description = "Player wallet address"
                        }
                    }
                },
                {
                    action = "CalculateSuccessRate",
                    pattern = {"Action"},
                    description = "Calculate breeding success rate with modifiers",
                    category = "breeding",
                    parameters = {
                        {
                            name = "Pokemon1Id",
                            type = "string",
                            required = true,
                            description = "First Pokemon instance ID"
                        },
                        {
                            name = "Pokemon2Id",
                            type = "string", 
                            required = true,
                            description = "Second Pokemon instance ID"
                        },
                        {
                            name = "OvalCharm",
                            type = "boolean",
                            required = false,
                            description = "Whether player has Oval Charm item"
                        }
                    }
                },
                {
                    action = "CalculateBreedingTime", 
                    pattern = {"Action"},
                    description = "Calculate breeding duration and timing",
                    category = "breeding",
                    parameters = {
                        {
                            name = "Species1Id",
                            type = "number",
                            required = true,
                            description = "First Pokemon species ID"
                        },
                        {
                            name = "Species2Id",
                            type = "number",
                            required = true, 
                            description = "Second Pokemon species ID"
                        },
                        {
                            name = "OvalCharm",
                            type = "boolean",
                            required = false,
                            description = "Whether player has Oval Charm"
                        },
                        {
                            name = "FlameBody",
                            type = "boolean",
                            required = false,
                            description = "Whether party has Flame Body ability"
                        }
                    }
                },
                {
                    action = "GetBreedingStatistics",
                    pattern = {"Action"},
                    description = "Get breeding statistics and history for a player",
                    category = "breeding",
                    parameters = {
                        {
                            name = "PlayerId",
                            type = "string",
                            required = false,
                            description = "Player wallet address (defaults to sender)"
                        }
                    }
                },
                {
                    action = "RecordBreedingAttempt",
                    pattern = {"Action"},
                    description = "Record a breeding attempt with success/failure",
                    category = "breeding",
                    parameters = {
                        {
                            name = "Pokemon1Id",
                            type = "string",
                            required = true,
                            description = "First Pokemon instance ID"
                        },
                        {
                            name = "Pokemon2Id",
                            type = "string",
                            required = true,
                            description = "Second Pokemon instance ID"
                        },
                        {
                            name = "Success",
                            type = "boolean",
                            required = true,
                            description = "Whether breeding attempt was successful"
                        },
                        {
                            name = "SuccessRate",
                            type = "number",
                            required = false,
                            description = "Calculated success rate for the attempt"
                        }
                    }
                },
                {
                    action = "ValidateBreedingRestrictions",
                    pattern = {"Action"},
                    description = "Validate breeding restrictions and special conditions",
                    category = "breeding",
                    parameters = {
                        {
                            name = "Pokemon1Id",
                            type = "string",
                            required = true,
                            description = "First Pokemon instance ID"
                        },
                        {
                            name = "Pokemon2Id",
                            type = "string",
                            required = true,
                            description = "Second Pokemon instance ID"
                        },
                        {
                            name = "Items",
                            type = "object",
                            required = false,
                            description = "JSON object containing breeding items"
                        }
                    }
                },
                {
                    action = "HealthCheck",
                    pattern = {"Action"},
                    description = "Check process health and status",
                    category = "utility"
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get comprehensive process information and capabilities",
                    category = "core"
                }
            },
            capabilities = {
                breedingCompatibility = true,
                successRateCalculation = true,
                breedingTimeCalculation = true,
                eggGroupValidation = true,
                genderValidation = true,
                breedingRestrictions = true,
                crossProcessCoordination = true,
                adpCompliant = true
            },
            eggGroups = {
                "monster", "dragon", "water1", "water2", "bug", "flying", 
                "field", "fairy", "grass", "human-like", "mineral", 
                "amorphous", "water3", "undiscovered", "ditto"
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true,
                autonomousAgentReady = true
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(infoResponse)
        })
    end
)

print("Breeding Compatibility Engine v1.0 initialized successfully")