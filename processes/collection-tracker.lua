-- Collection Tracker Process - Comprehensive Pokemon Collection and Progress Management
-- Implements complete collection tracking, achievement system, statistics, and analytics
-- ADP v1.0 Compliant Process for autonomous agent integration

-- Process Configuration and Constants
local PROCESS_VERSION = "1.0.0"
local ADP_VERSION = "1.0"
local MAX_SPECIES_COUNT = 1025 -- Total species available in game
local MAX_OPERATIONS_PER_MINUTE = 50

-- Collection State Model - Core data structure for tracking all collection progress
local function createCollectionState(playerId)
    return {
        -- Player collection identification
        playerId = playerId or "unknown_player",
        collectionVersion = "1.0",
        
        -- Pokedex and Species Collection
        pokedex = {
            totalSpeciesCount = MAX_SPECIES_COUNT,
            totalSeen = 0,
            totalCaught = 0,
            seenSpecies = {}, -- species[speciesId] = first_seen_timestamp
            caughtSpecies = {}, -- species[speciesId] = first_caught_timestamp
            completionPercentage = 0.0,
            regionCompletion = {
                kanto = {seen = 0, caught = 0, total = 151, percentage = 0.0},
                johto = {seen = 0, caught = 0, total = 100, percentage = 0.0},
                hoenn = {seen = 0, caught = 0, total = 135, percentage = 0.0},
                sinnoh = {seen = 0, caught = 0, total = 107, percentage = 0.0},
                unova = {seen = 0, caught = 0, total = 156, percentage = 0.0},
                kalos = {seen = 0, caught = 0, total = 72, percentage = 0.0},
                alola = {seen = 0, caught = 0, total = 81, percentage = 0.0},
                galar = {seen = 0, caught = 0, total = 89, percentage = 0.0},
                paldea = {seen = 0, caught = 0, total = 103, percentage = 0.0}
            }
        },
        
        -- Collection Achievements and Milestones
        achievements = {
            milestones = {
                first_catch = {
                    id = "first_catch",
                    name = "First Catch",
                    description = "Catch your first Pokemon",
                    threshold = 1,
                    currentProgress = 0,
                    completed = false,
                    completedAt = nil,
                    rewardClaimed = false,
                    points = 10
                },
                pokedex_10 = {
                    id = "pokedex_10",
                    name = "Collector",
                    description = "Catch 10 different species",
                    threshold = 10,
                    currentProgress = 0,
                    completed = false,
                    completedAt = nil,
                    rewardClaimed = false,
                    points = 25
                },
                pokedex_50 = {
                    id = "pokedex_50",
                    name = "Dedicated Trainer",
                    description = "Catch 50 different species",
                    threshold = 50,
                    currentProgress = 0,
                    completed = false,
                    completedAt = nil,
                    rewardClaimed = false,
                    points = 100
                },
                pokedex_150 = {
                    id = "pokedex_150",
                    name = "Master Collector",
                    description = "Catch 150 different species",
                    threshold = 150,
                    currentProgress = 0,
                    completed = false,
                    completedAt = nil,
                    rewardClaimed = false,
                    points = 500
                },
                kanto_completion = {
                    id = "kanto_completion",
                    name = "Kanto Master",
                    description = "Complete the Kanto Pokedex",
                    threshold = 151,
                    currentProgress = 0,
                    completed = false,
                    completedAt = nil,
                    rewardClaimed = false,
                    points = 1000
                }
            },
            totalAchievements = 5,
            totalCompleted = 0,
            achievementPoints = 0,
            lastAchievementEarned = nil
        },
        
        -- Collection Statistics and Analytics
        statistics = {
            captureStats = {
                totalCaptureAttempts = 0,
                successfulCaptures = 0,
                captureSuccessRate = 0.0,
                criticalCaptures = 0,
                escapeCount = 0,
                averageCaptureAttempts = 0.0
            },
            encounterStats = {
                totalEncounters = 0,
                uniqueSpeciesEncountered = 0,
                shinyEncounters = 0,
                rareEncounters = 0,
                averageEncounterLevel = 0.0
            },
            collectionTiming = {
                firstCaptureDate = nil,
                lastCaptureDate = nil,
                fastestSpeciesCompletion = nil,
                totalPlaytime = 0,
                capturesPerSession = 0.0
            },
            progressAnalytics = {
                dailyProgress = {},
                weeklyProgress = {},
                monthlyProgress = {},
                progressTrends = {
                    captureVelocity = 0.0,
                    completionProjection = nil
                }
            }
        },
        
        -- Collection Goals and Targets
        goals = {
            activeGoals = {},
            completedGoals = {},
            goalProgress = {
                totalActiveGoals = 0,
                totalCompletedGoals = 0,
                averageCompletionTime = 0.0,
                goalCompletionRate = 0.0
            }
        },
        
        -- Collection History and Event Log
        history = {
            events = {},
            timeline = {
                firstCapture = nil,
                firstShiny = nil,
                firstLegendary = nil,
                firstAchievement = nil,
                regionCompletions = {}
            },
            eventCount = 0,
            lastEventTimestamp = 0
        },
        
        -- Collection Sharing and Export
        sharing = {
            publicProfile = {
                displayName = "Unknown Trainer",
                favoriteSpecies = nil,
                showcaseTeam = {},
                achievements = {},
                statistics = {
                    totalCaught = 0,
                    completionPercentage = 0.0,
                    favoriteType = nil,
                    playingSince = nil
                }
            },
            exportFormats = {
                lastExportDate = nil,
                exportCount = 0,
                availableFormats = {"json", "csv", "markdown"}
            }
        },
        
        -- Metadata and State Management
        metadata = {
            lastUpdated = 0,
            version = "1.0",
            dataIntegrity = {
                checksum = "",
                lastValidated = 0
            },
            syncStatus = {
                lastSyncTimestamp = 0,
                pendingUpdates = 0,
                syncErrors = 0
            }
        }
    }
end

-- Pokemon Species Region Mapping
local SPECIES_REGIONS = {
    -- Kanto (Gen 1): 1-151
    kanto = {start = 1, finish = 151},
    -- Johto (Gen 2): 152-251
    johto = {start = 152, finish = 251},
    -- Hoenn (Gen 3): 252-386
    hoenn = {start = 252, finish = 386},
    -- Sinnoh (Gen 4): 387-493
    sinnoh = {start = 387, finish = 493},
    -- Unova (Gen 5): 494-649
    unova = {start = 494, finish = 649},
    -- Kalos (Gen 6): 650-721
    kalos = {start = 650, finish = 721},
    -- Alola (Gen 7): 722-802
    alola = {start = 722, finish = 802},
    -- Galar (Gen 8): 803-891
    galar = {start = 803, finish = 891},
    -- Paldea (Gen 9): 892-1025
    paldea = {start = 892, finish = 1025}
}

-- Goal Definition Templates
local GOAL_TEMPLATES = {
    region_completion = {
        type = "region_completion",
        validTargets = {"kanto", "johto", "hoenn", "sinnoh", "unova", "kalos", "alola", "galar", "paldea"},
        thresholdType = "species_count"
    },
    species_milestone = {
        type = "species_milestone",
        validThresholds = {10, 25, 50, 100, 150, 200, 300, 500, 750, 1000},
        thresholdType = "total_caught"
    },
    completion_percentage = {
        type = "completion_percentage",
        validThresholds = {10, 25, 50, 75, 90, 95, 99, 100},
        thresholdType = "percentage"
    }
}

-- Achievement Evaluation Rules
local ACHIEVEMENT_RULES = {
    first_catch = function(collectionState)
        return collectionState.pokedex.totalCaught >= 1
    end,
    pokedex_10 = function(collectionState)
        return collectionState.pokedex.totalCaught >= 10
    end,
    pokedex_50 = function(collectionState)
        return collectionState.pokedex.totalCaught >= 50
    end,
    pokedex_150 = function(collectionState)
        return collectionState.pokedex.totalCaught >= 150
    end,
    kanto_completion = function(collectionState)
        return collectionState.pokedex.regionCompletion.kanto.caught >= 151
    end
}

-- Global Collection State Storage
local playerCollections = {}

-- Rate Limiting Tracking
local operationCounts = {}

-- Utility Functions

-- Deep copy function for immutable state updates
local function deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

-- Validate species ID is within valid range
local function isValidSpeciesId(speciesId)
    local id = tonumber(speciesId)
    return id and id >= 1 and id <= MAX_SPECIES_COUNT
end

-- Get region for species ID
local function getSpeciesRegion(speciesId)
    local id = tonumber(speciesId)
    if not id then return nil end
    
    for region, range in pairs(SPECIES_REGIONS) do
        if id >= range.start and id <= range.finish then
            return region
        end
    end
    return nil
end

-- Calculate completion percentage
local function calculateCompletionPercentage(caught, total)
    if total == 0 then return 0.0 end
    return (caught / total) * 100.0
end

-- Validate timestamp
local function isValidTimestamp(timestamp)
    local ts = tonumber(timestamp)
    return ts and ts > 0
end

-- Rate limiting check
local function checkRateLimit(playerId, currentTime)
    if not operationCounts[playerId] then
        operationCounts[playerId] = {count = 0, windowStart = currentTime}
        return true
    end
    
    local playerData = operationCounts[playerId]
    local timeWindow = 60000 -- 1 minute in milliseconds
    
    if (currentTime - playerData.windowStart) >= timeWindow then
        playerData.count = 0
        playerData.windowStart = currentTime
    end
    
    if playerData.count >= MAX_OPERATIONS_PER_MINUTE then
        return false
    end
    
    playerData.count = playerData.count + 1
    return true
end

-- Initialize AO environment
if not ao then
    ao = {
        send = function(msg) print("Mock send:", json.encode(msg)) end,
        id = "collection_tracker_process_id"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
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

-- Collection Tracker Core Operations

-- Core Collection Tracking Functions

-- Record Pokemon capture event and update collection state
local function recordCapture(playerId, pokemonId, captureContext, timestamp)
    if not playerId or not pokemonId or not captureContext then
        return {success = false, error = "Missing required parameters for capture recording"}
    end
    
    if not captureContext.speciesId then
        return {success = false, error = "Species ID required in capture context"}
    end
    
    local speciesId = tonumber(captureContext.speciesId)
    if not isValidSpeciesId(speciesId) then
        return {success = false, error = "Invalid species ID: " .. tostring(speciesId)}
    end
    
    local currentTime = timestamp or 0
    if not isValidTimestamp(currentTime) then
        return {success = false, error = "Invalid timestamp"}
    end
    
    -- Get or create collection state
    if not playerCollections[playerId] then
        playerCollections[playerId] = createCollectionState(playerId)
    end
    
    local collection = playerCollections[playerId]
    local wasNewSpecies = false
    
    -- Update seen species if not already seen
    if not collection.pokedex.seenSpecies[speciesId] then
        collection.pokedex.seenSpecies[speciesId] = currentTime
        collection.pokedex.totalSeen = collection.pokedex.totalSeen + 1
    end
    
    -- Update caught species if not already caught
    if not collection.pokedex.caughtSpecies[speciesId] then
        collection.pokedex.caughtSpecies[speciesId] = currentTime
        collection.pokedex.totalCaught = collection.pokedex.totalCaught + 1
        wasNewSpecies = true
        
        -- Update region completion
        local region = getSpeciesRegion(speciesId)
        if region and collection.pokedex.regionCompletion[region] then
            collection.pokedex.regionCompletion[region].caught = 
                collection.pokedex.regionCompletion[region].caught + 1
            collection.pokedex.regionCompletion[region].percentage = 
                calculateCompletionPercentage(
                    collection.pokedex.regionCompletion[region].caught,
                    collection.pokedex.regionCompletion[region].total
                )
        end
        
        -- Update overall completion percentage
        collection.pokedex.completionPercentage = 
            calculateCompletionPercentage(collection.pokedex.totalCaught, collection.pokedex.totalSpeciesCount)
    end
    
    -- Update capture statistics
    local stats = collection.statistics.captureStats
    stats.successfulCaptures = stats.successfulCaptures + 1
    if captureContext.attempts then
        stats.totalCaptureAttempts = stats.totalCaptureAttempts + tonumber(captureContext.attempts)
        stats.averageCaptureAttempts = stats.totalCaptureAttempts / stats.successfulCaptures
    end
    if captureContext.critical then
        stats.criticalCaptures = stats.criticalCaptures + 1
    end
    stats.captureSuccessRate = calculateCompletionPercentage(stats.successfulCaptures, stats.totalCaptureAttempts)
    
    -- Update timing statistics
    local timing = collection.statistics.collectionTiming
    if not timing.firstCaptureDate then
        timing.firstCaptureDate = currentTime
    end
    timing.lastCaptureDate = currentTime
    
    -- Record event in history
    local eventId = tostring(currentTime) .. "_" .. pokemonId
    collection.history.events[eventId] = {
        type = "capture",
        speciesId = speciesId,
        pokemonId = pokemonId,
        location = captureContext.location or "Unknown",
        level = captureContext.level or 1,
        timestamp = currentTime,
        metadata = {
            captureMethod = captureContext.method or "pokeball",
            attempts = captureContext.attempts or 1,
            critical = captureContext.critical or false,
            newSpecies = wasNewSpecies
        }
    }
    collection.history.eventCount = collection.history.eventCount + 1
    collection.history.lastEventTimestamp = currentTime
    
    -- Update timeline for first capture
    if not collection.history.timeline.firstCapture then
        collection.history.timeline.firstCapture = currentTime
    end
    
    -- Update metadata
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "recordCapture",
        speciesId = speciesId,
        pokemonId = pokemonId,
        wasNewSpecies = wasNewSpecies,
        collectionUpdate = {
            totalCaught = collection.pokedex.totalCaught,
            completionPercentage = collection.pokedex.completionPercentage,
            regionProgress = region and collection.pokedex.regionCompletion[region] or nil
        }
    }
end

-- Record Pokemon encounter event and update seen species
local function recordEncounter(playerId, speciesId, encounterContext, timestamp)
    if not playerId or not speciesId then
        return {success = false, error = "Missing required parameters for encounter recording"}
    end
    
    local species = tonumber(speciesId)
    if not isValidSpeciesId(species) then
        return {success = false, error = "Invalid species ID: " .. tostring(speciesId)}
    end
    
    local currentTime = timestamp or 0
    if not isValidTimestamp(currentTime) then
        return {success = false, error = "Invalid timestamp"}
    end
    
    -- Get or create collection state
    if not playerCollections[playerId] then
        playerCollections[playerId] = createCollectionState(playerId)
    end
    
    local collection = playerCollections[playerId]
    local wasNewSighting = false
    
    -- Update seen species if not already seen
    if not collection.pokedex.seenSpecies[species] then
        collection.pokedex.seenSpecies[species] = currentTime
        collection.pokedex.totalSeen = collection.pokedex.totalSeen + 1
        wasNewSighting = true
        
        -- Update region completion
        local region = getSpeciesRegion(species)
        if region and collection.pokedex.regionCompletion[region] then
            collection.pokedex.regionCompletion[region].seen = 
                collection.pokedex.regionCompletion[region].seen + 1
        end
    end
    
    -- Update encounter statistics
    local stats = collection.statistics.encounterStats
    stats.totalEncounters = stats.totalEncounters + 1
    if wasNewSighting then
        stats.uniqueSpeciesEncountered = stats.uniqueSpeciesEncountered + 1
    end
    if encounterContext and encounterContext.shiny then
        stats.shinyEncounters = stats.shinyEncounters + 1
    end
    if encounterContext and encounterContext.rare then
        stats.rareEncounters = stats.rareEncounters + 1
    end
    if encounterContext and encounterContext.level then
        local totalLevels = stats.averageEncounterLevel * (stats.totalEncounters - 1) + tonumber(encounterContext.level)
        stats.averageEncounterLevel = totalLevels / stats.totalEncounters
    end
    
    -- Record event in history
    local eventId = tostring(currentTime) .. "_encounter_" .. species
    collection.history.events[eventId] = {
        type = "encounter",
        speciesId = species,
        location = encounterContext and encounterContext.location or "Unknown",
        level = encounterContext and encounterContext.level or 1,
        timestamp = currentTime,
        metadata = {
            shiny = encounterContext and encounterContext.shiny or false,
            rare = encounterContext and encounterContext.rare or false,
            newSighting = wasNewSighting
        }
    }
    collection.history.eventCount = collection.history.eventCount + 1
    collection.history.lastEventTimestamp = currentTime
    
    -- Update metadata
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "recordEncounter",
        speciesId = species,
        wasNewSighting = wasNewSighting,
        collectionUpdate = {
            totalSeen = collection.pokedex.totalSeen,
            uniqueSpeciesEncountered = stats.uniqueSpeciesEncountered
        }
    }
end

-- Update collection progress and recalculate statistics
local function updateProgress(playerId, progressType, data, timestamp)
    if not playerId or not progressType then
        return {success = false, error = "Missing required parameters for progress update"}
    end
    
    local currentTime = timestamp or 0
    if not isValidTimestamp(currentTime) then
        return {success = false, error = "Invalid timestamp"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    
    -- Update based on progress type
    if progressType == "pokedex" then
        -- Recalculate overall completion percentage
        collection.pokedex.completionPercentage = 
            calculateCompletionPercentage(collection.pokedex.totalCaught, collection.pokedex.totalSpeciesCount)
        
        -- Recalculate region completion percentages
        for region, regionData in pairs(collection.pokedex.regionCompletion) do
            regionData.percentage = calculateCompletionPercentage(regionData.caught, regionData.total)
        end
        
    elseif progressType == "statistics" then
        -- Recalculate capture success rate
        local stats = collection.statistics.captureStats
        if stats.totalCaptureAttempts > 0 then
            stats.captureSuccessRate = calculateCompletionPercentage(stats.successfulCaptures, stats.totalCaptureAttempts)
            stats.averageCaptureAttempts = stats.totalCaptureAttempts / stats.successfulCaptures
        end
        
    elseif progressType == "goals" then
        -- Update goal progress tracking
        local goalProgress = collection.goals.goalProgress
        goalProgress.totalActiveGoals = 0
        goalProgress.totalCompletedGoals = 0
        
        for _, goal in pairs(collection.goals.activeGoals) do
            goalProgress.totalActiveGoals = goalProgress.totalActiveGoals + 1
        end
        
        for _, goal in pairs(collection.goals.completedGoals) do
            goalProgress.totalCompletedGoals = goalProgress.totalCompletedGoals + 1
        end
        
        if (goalProgress.totalActiveGoals + goalProgress.totalCompletedGoals) > 0 then
            goalProgress.goalCompletionRate = calculateCompletionPercentage(
                goalProgress.totalCompletedGoals,
                goalProgress.totalActiveGoals + goalProgress.totalCompletedGoals
            )
        end
    end
    
    -- Update metadata
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "updateProgress",
        progressType = progressType,
        collectionUpdate = {
            completionPercentage = collection.pokedex.completionPercentage,
            lastUpdated = currentTime
        }
    }
end

-- Calculate completion statistics for regions and overall progress
local function calculateCompletion(playerId, region, criteria, timestamp)
    if not playerId then
        return {success = false, error = "Player ID required for completion calculation"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local result = {
        success = true,
        operation = "calculateCompletion",
        timestamp = timestamp or 0
    }
    
    if region and region ~= "all" then
        -- Calculate specific region completion
        if not collection.pokedex.regionCompletion[region] then
            return {success = false, error = "Invalid region: " .. tostring(region)}
        end
        
        local regionData = collection.pokedex.regionCompletion[region]
        result.region = region
        result.completion = {
            seen = regionData.seen,
            caught = regionData.caught,
            total = regionData.total,
            percentage = regionData.percentage,
            seenPercentage = calculateCompletionPercentage(regionData.seen, regionData.total),
            remaining = regionData.total - regionData.caught
        }
        
    else
        -- Calculate overall completion
        result.region = "all"
        result.completion = {
            seen = collection.pokedex.totalSeen,
            caught = collection.pokedex.totalCaught,
            total = collection.pokedex.totalSpeciesCount,
            percentage = collection.pokedex.completionPercentage,
            seenPercentage = calculateCompletionPercentage(collection.pokedex.totalSeen, collection.pokedex.totalSpeciesCount),
            remaining = collection.pokedex.totalSpeciesCount - collection.pokedex.totalCaught
        }
        
        -- Include region breakdown
        result.regionBreakdown = {}
        for regionName, regionData in pairs(collection.pokedex.regionCompletion) do
            result.regionBreakdown[regionName] = {
                seen = regionData.seen,
                caught = regionData.caught,
                total = regionData.total,
                percentage = regionData.percentage
            }
        end
    end
    
    return result
end

-- Validate collection state integrity and fix inconsistencies
local function validateCollectionState(collection)
    local fixes = {}
    
    -- Validate pokedex totals match actual counts
    local actualSeen = 0
    local actualCaught = 0
    
    for speciesId, _ in pairs(collection.pokedex.seenSpecies) do
        actualSeen = actualSeen + 1
    end
    
    for speciesId, _ in pairs(collection.pokedex.caughtSpecies) do
        actualCaught = actualCaught + 1
    end
    
    if collection.pokedex.totalSeen ~= actualSeen then
        collection.pokedex.totalSeen = actualSeen
        table.insert(fixes, "Fixed totalSeen count")
    end
    
    if collection.pokedex.totalCaught ~= actualCaught then
        collection.pokedex.totalCaught = actualCaught
        table.insert(fixes, "Fixed totalCaught count")
    end
    
    -- Validate region counts
    for region, regionData in pairs(collection.pokedex.regionCompletion) do
        local regionRange = SPECIES_REGIONS[region]
        if regionRange then
            local regionSeen = 0
            local regionCaught = 0
            
            for speciesId = regionRange.start, regionRange.finish do
                if collection.pokedex.seenSpecies[speciesId] then
                    regionSeen = regionSeen + 1
                end
                if collection.pokedex.caughtSpecies[speciesId] then
                    regionCaught = regionCaught + 1
                end
            end
            
            if regionData.seen ~= regionSeen then
                regionData.seen = regionSeen
                table.insert(fixes, "Fixed " .. region .. " seen count")
            end
            
            if regionData.caught ~= regionCaught then
                regionData.caught = regionCaught
                table.insert(fixes, "Fixed " .. region .. " caught count")
            end
            
            -- Recalculate percentage
            regionData.percentage = calculateCompletionPercentage(regionData.caught, regionData.total)
        end
    end
    
    -- Recalculate overall completion
    collection.pokedex.completionPercentage = 
        calculateCompletionPercentage(collection.pokedex.totalCaught, collection.pokedex.totalSpeciesCount)
    
    return fixes
end

-- Achievement and Milestone System

-- Check and evaluate achievements for completion
local function checkAchievements(playerId, triggerEvent, eventData, timestamp)
    if not playerId then
        return {success = false, error = "Player ID required for achievement checking"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local currentTime = timestamp or 0
    local newAchievements = {}
    local updatedAchievements = {}
    
    -- Evaluate each achievement
    for achievementId, achievement in pairs(collection.achievements.milestones) do
        if not achievement.completed then
            local previousProgress = achievement.currentProgress
            
            -- Update current progress based on achievement type
            if achievementId == "first_catch" then
                achievement.currentProgress = collection.pokedex.totalCaught
            elseif achievementId == "pokedex_10" or achievementId == "pokedex_50" or achievementId == "pokedex_150" then
                achievement.currentProgress = collection.pokedex.totalCaught
            elseif achievementId == "kanto_completion" then
                achievement.currentProgress = collection.pokedex.regionCompletion.kanto.caught
            end
            
            -- Check if achievement is now completed
            if achievement.currentProgress >= achievement.threshold then
                achievement.completed = true
                achievement.completedAt = currentTime
                collection.achievements.totalCompleted = collection.achievements.totalCompleted + 1
                collection.achievements.achievementPoints = collection.achievements.achievementPoints + achievement.points
                collection.achievements.lastAchievementEarned = currentTime
                
                -- Record achievement completion event
                local eventId = tostring(currentTime) .. "_achievement_" .. achievementId
                collection.history.events[eventId] = {
                    type = "achievement",
                    achievementId = achievementId,
                    achievementName = achievement.name,
                    timestamp = currentTime,
                    metadata = {
                        points = achievement.points,
                        threshold = achievement.threshold,
                        triggerEvent = triggerEvent or "unknown"
                    }
                }
                collection.history.eventCount = collection.history.eventCount + 1
                
                -- Update timeline for first achievement
                if not collection.history.timeline.firstAchievement then
                    collection.history.timeline.firstAchievement = currentTime
                end
                
                table.insert(newAchievements, {
                    id = achievementId,
                    name = achievement.name,
                    description = achievement.description,
                    points = achievement.points,
                    completedAt = currentTime
                })
                
            elseif achievement.currentProgress ~= previousProgress then
                -- Track progress updates even if not completed
                table.insert(updatedAchievements, {
                    id = achievementId,
                    name = achievement.name,
                    previousProgress = previousProgress,
                    currentProgress = achievement.currentProgress,
                    threshold = achievement.threshold,
                    percentComplete = (achievement.currentProgress / achievement.threshold) * 100
                })
            end
        end
    end
    
    -- Update metadata
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "checkAchievements",
        triggerEvent = triggerEvent,
        newAchievements = newAchievements,
        updatedAchievements = updatedAchievements,
        totalCompleted = collection.achievements.totalCompleted,
        totalPoints = collection.achievements.achievementPoints
    }
end

-- Generate achievement notifications for completed milestones
local function generateAchievementNotifications(achievementResults)
    local notifications = {}
    
    for _, achievement in ipairs(achievementResults.newAchievements) do
        table.insert(notifications, {
            type = "achievement_completed",
            title = "Achievement Unlocked!",
            message = achievement.name .. ": " .. achievement.description,
            points = achievement.points,
            timestamp = achievement.completedAt,
            priority = "high"
        })
    end
    
    for _, achievement in ipairs(achievementResults.updatedAchievements) do
        if achievement.percentComplete >= 75 then -- Notify when 75% complete
            table.insert(notifications, {
                type = "achievement_progress",
                title = "Achievement Progress",
                message = achievement.name .. " is " .. math.floor(achievement.percentComplete) .. "% complete",
                progress = achievement.currentProgress,
                threshold = achievement.threshold,
                timestamp = achievementResults.timestamp or 0,
                priority = "medium"
            })
        end
    end
    
    return notifications
end

-- Distribute rewards for completed achievements
local function distributeAchievementRewards(playerId, achievementIds, timestamp)
    if not playerId or not achievementIds then
        return {success = false, error = "Missing required parameters for reward distribution"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local currentTime = timestamp or 0
    local distributedRewards = {}
    local totalPointsAwarded = 0
    
    for _, achievementId in ipairs(achievementIds) do
        local achievement = collection.achievements.milestones[achievementId]
        if achievement and achievement.completed and not achievement.rewardClaimed then
            achievement.rewardClaimed = true
            totalPointsAwarded = totalPointsAwarded + achievement.points
            
            table.insert(distributedRewards, {
                achievementId = achievementId,
                achievementName = achievement.name,
                points = achievement.points,
                rewardType = "achievement_points",
                claimedAt = currentTime
            })
            
            -- Record reward claim event
            local eventId = tostring(currentTime) .. "_reward_" .. achievementId
            collection.history.events[eventId] = {
                type = "reward_claim",
                achievementId = achievementId,
                rewardType = "achievement_points",
                points = achievement.points,
                timestamp = currentTime,
                metadata = {
                    achievementName = achievement.name
                }
            }
            collection.history.eventCount = collection.history.eventCount + 1
        end
    end
    
    -- Update metadata
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "distributeRewards",
        distributedRewards = distributedRewards,
        totalPointsAwarded = totalPointsAwarded,
        timestamp = currentTime
    }
end

-- Get achievement progress summary for display
local function getAchievementSummary(playerId)
    if not playerId then
        return {success = false, error = "Player ID required for achievement summary"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local summary = {
        success = true,
        operation = "getAchievementSummary",
        totalAchievements = collection.achievements.totalAchievements,
        totalCompleted = collection.achievements.totalCompleted,
        totalPoints = collection.achievements.achievementPoints,
        completionPercentage = calculateCompletionPercentage(
            collection.achievements.totalCompleted, 
            collection.achievements.totalAchievements
        ),
        achievements = {}
    }
    
    for achievementId, achievement in pairs(collection.achievements.milestones) do
        table.insert(summary.achievements, {
            id = achievementId,
            name = achievement.name,
            description = achievement.description,
            threshold = achievement.threshold,
            currentProgress = achievement.currentProgress,
            percentComplete = (achievement.currentProgress / achievement.threshold) * 100,
            completed = achievement.completed,
            completedAt = achievement.completedAt,
            points = achievement.points,
            rewardClaimed = achievement.rewardClaimed
        })
    end
    
    -- Sort achievements by completion status and progress
    table.sort(summary.achievements, function(a, b)
        if a.completed ~= b.completed then
            return b.completed -- Completed achievements first
        end
        return a.percentComplete > b.percentComplete -- Higher progress first
    end)
    
    return summary
end

-- Create custom achievement for players
local function createCustomAchievement(playerId, achievementDefinition, timestamp)
    if not playerId or not achievementDefinition then
        return {success = false, error = "Missing required parameters for custom achievement creation"}
    end
    
    local currentTime = timestamp or 0
    
    -- Validate achievement definition
    if not achievementDefinition.id or not achievementDefinition.name or not achievementDefinition.threshold then
        return {success = false, error = "Achievement definition missing required fields (id, name, threshold)"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        playerCollections[playerId] = createCollectionState(playerId)
    end
    
    local collection = playerCollections[playerId]
    
    -- Check if achievement already exists
    if collection.achievements.milestones[achievementDefinition.id] then
        return {success = false, error = "Achievement already exists: " .. achievementDefinition.id}
    end
    
    -- Create new achievement
    collection.achievements.milestones[achievementDefinition.id] = {
        id = achievementDefinition.id,
        name = achievementDefinition.name,
        description = achievementDefinition.description or "Custom achievement",
        threshold = tonumber(achievementDefinition.threshold),
        currentProgress = 0,
        completed = false,
        completedAt = nil,
        rewardClaimed = false,
        points = tonumber(achievementDefinition.points) or 50,
        custom = true,
        createdAt = currentTime
    }
    
    collection.achievements.totalAchievements = collection.achievements.totalAchievements + 1
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "createCustomAchievement",
        achievementId = achievementDefinition.id,
        achievement = collection.achievements.milestones[achievementDefinition.id]
    }
end

-- Collection Statistics and Analytics System

-- Generate comprehensive statistics for collection progress
local function generateStatistics(playerId, timeframe, categories, timestamp)
    if not playerId then
        return {success = false, error = "Player ID required for statistics generation"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local currentTime = timestamp or 0
    local statisticsResult = {
        success = true,
        operation = "generateStatistics",
        timeframe = timeframe or "all_time",
        generatedAt = currentTime,
        statistics = {}
    }
    
    -- Default to all categories if not specified
    local requestedCategories = categories or {"capture", "encounter", "achievement", "progress"}
    
    -- Generate capture statistics
    if table.concat(requestedCategories, ","):find("capture") then
        local captureStats = collection.statistics.captureStats
        statisticsResult.statistics.capture = {
            totalAttempts = captureStats.totalCaptureAttempts,
            successfulCaptures = captureStats.successfulCaptures,
            successRate = captureStats.captureSuccessRate,
            criticalCaptures = captureStats.criticalCaptures,
            escapeCount = captureStats.escapeCount,
            averageAttempts = captureStats.averageCaptureAttempts,
            efficiency = captureStats.totalCaptureAttempts > 0 and 
                (captureStats.successfulCaptures / captureStats.totalCaptureAttempts) or 0
        }
    end
    
    -- Generate encounter statistics
    if table.concat(requestedCategories, ","):find("encounter") then
        local encounterStats = collection.statistics.encounterStats
        statisticsResult.statistics.encounter = {
            totalEncounters = encounterStats.totalEncounters,
            uniqueSpecies = encounterStats.uniqueSpeciesEncountered,
            shinyEncounters = encounterStats.shinyEncounters,
            rareEncounters = encounterStats.rareEncounters,
            averageLevel = encounterStats.averageEncounterLevel,
            shinyRate = encounterStats.totalEncounters > 0 and 
                (encounterStats.shinyEncounters / encounterStats.totalEncounters) * 100 or 0,
            rareRate = encounterStats.totalEncounters > 0 and 
                (encounterStats.rareEncounters / encounterStats.totalEncounters) * 100 or 0
        }
    end
    
    -- Generate achievement statistics
    if table.concat(requestedCategories, ","):find("achievement") then
        statisticsResult.statistics.achievement = {
            totalAchievements = collection.achievements.totalAchievements,
            completedAchievements = collection.achievements.totalCompleted,
            completionRate = calculateCompletionPercentage(
                collection.achievements.totalCompleted, 
                collection.achievements.totalAchievements
            ),
            totalPoints = collection.achievements.achievementPoints,
            lastEarned = collection.achievements.lastAchievementEarned,
            averagePointsPerAchievement = collection.achievements.totalCompleted > 0 and 
                (collection.achievements.achievementPoints / collection.achievements.totalCompleted) or 0
        }
    end
    
    -- Generate progress statistics
    if table.concat(requestedCategories, ","):find("progress") then
        statisticsResult.statistics.progress = {
            totalSpecies = collection.pokedex.totalSpeciesCount,
            speciesSeen = collection.pokedex.totalSeen,
            speciesCaught = collection.pokedex.totalCaught,
            seenPercentage = calculateCompletionPercentage(
                collection.pokedex.totalSeen, 
                collection.pokedex.totalSpeciesCount
            ),
            caughtPercentage = collection.pokedex.completionPercentage,
            remaining = collection.pokedex.totalSpeciesCount - collection.pokedex.totalCaught,
            captureEfficiency = collection.pokedex.totalSeen > 0 and 
                (collection.pokedex.totalCaught / collection.pokedex.totalSeen) * 100 or 0
        }
        
        -- Add region breakdown
        statisticsResult.statistics.progress.regions = {}
        for region, regionData in pairs(collection.pokedex.regionCompletion) do
            statisticsResult.statistics.progress.regions[region] = {
                seen = regionData.seen,
                caught = regionData.caught,
                total = regionData.total,
                percentage = regionData.percentage,
                remaining = regionData.total - regionData.caught
            }
        end
    end
    
    return statisticsResult
end

-- Calculate progress velocity and completion projections
local function calculateProgressVelocity(playerId, timeWindow, timestamp)
    if not playerId then
        return {success = false, error = "Player ID required for velocity calculation"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local currentTime = timestamp or 0
    local windowMs = (timeWindow or 7) * 24 * 60 * 60 * 1000 -- Default 7 days in milliseconds
    local cutoffTime = currentTime - windowMs
    
    -- Analyze recent capture events
    local recentCaptures = 0
    local recentEncounters = 0
    local recentAchievements = 0
    
    for _, event in pairs(collection.history.events) do
        if event.timestamp >= cutoffTime then
            if event.type == "capture" and event.metadata.newSpecies then
                recentCaptures = recentCaptures + 1
            elseif event.type == "encounter" and event.metadata.newSighting then
                recentEncounters = recentEncounters + 1
            elseif event.type == "achievement" then
                recentAchievements = recentAchievements + 1
            end
        end
    end
    
    -- Calculate velocities (per day)
    local dayWindow = timeWindow or 7
    local captureVelocity = recentCaptures / dayWindow
    local encounterVelocity = recentEncounters / dayWindow
    local achievementVelocity = recentAchievements / dayWindow
    
    -- Project completion time based on current velocity
    local remaining = collection.pokedex.totalSpeciesCount - collection.pokedex.totalCaught
    local completionProjection = nil
    if captureVelocity > 0 then
        local daysToCompletion = remaining / captureVelocity
        completionProjection = currentTime + (daysToCompletion * 24 * 60 * 60 * 1000)
    end
    
    return {
        success = true,
        operation = "calculateProgressVelocity",
        timeWindow = dayWindow,
        velocities = {
            capturesPerDay = captureVelocity,
            encountersPerDay = encounterVelocity,
            achievementsPerDay = achievementVelocity
        },
        projections = {
            remainingSpecies = remaining,
            estimatedCompletionDate = completionProjection,
            daysToCompletion = completionProjection and 
                math.ceil((completionProjection - currentTime) / (24 * 60 * 60 * 1000)) or nil
        },
        recentActivity = {
            captures = recentCaptures,
            encounters = recentEncounters,
            achievements = recentAchievements
        }
    }
end

-- Perform collection gap analysis to identify missing species
local function analyzeCollectionGaps(playerId, region, analysisType)
    if not playerId then
        return {success = false, error = "Player ID required for gap analysis"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local gaps = {
        success = true,
        operation = "analyzeCollectionGaps",
        region = region or "all",
        analysisType = analysisType or "missing",
        gaps = {}
    }
    
    if region and region ~= "all" then
        -- Analyze specific region
        local regionRange = SPECIES_REGIONS[region]
        if not regionRange then
            return {success = false, error = "Invalid region: " .. tostring(region)}
        end
        
        for speciesId = regionRange.start, regionRange.finish do
            local isSeenOnly = collection.pokedex.seenSpecies[speciesId] and not collection.pokedex.caughtSpecies[speciesId]
            local isMissing = not collection.pokedex.seenSpecies[speciesId]
            
            if (analysisType == "missing" and isMissing) or 
               (analysisType == "seen_only" and isSeenOnly) or
               (analysisType == "all" and (isMissing or isSeenOnly)) then
                table.insert(gaps.gaps, {
                    speciesId = speciesId,
                    status = isMissing and "not_seen" or "seen_not_caught",
                    region = region,
                    priority = isMissing and "high" or "medium"
                })
            end
        end
    else
        -- Analyze all regions
        for regionName, regionRange in pairs(SPECIES_REGIONS) do
            local regionGaps = 0
            for speciesId = regionRange.start, regionRange.finish do
                local isSeenOnly = collection.pokedex.seenSpecies[speciesId] and not collection.pokedex.caughtSpecies[speciesId]
                local isMissing = not collection.pokedex.seenSpecies[speciesId]
                
                if (analysisType == "missing" and isMissing) or 
                   (analysisType == "seen_only" and isSeenOnly) or
                   (analysisType == "all" and (isMissing or isSeenOnly)) then
                    regionGaps = regionGaps + 1
                end
            end
            
            if regionGaps > 0 then
                table.insert(gaps.gaps, {
                    region = regionName,
                    missingCount = regionGaps,
                    totalSpecies = regionRange.finish - regionRange.start + 1,
                    completionRate = calculateCompletionPercentage(
                        collection.pokedex.regionCompletion[regionName].caught,
                        collection.pokedex.regionCompletion[regionName].total
                    )
                })
            end
        end
        
        -- Sort regions by completion rate (lowest first for priority)
        table.sort(gaps.gaps, function(a, b)
            return a.completionRate < b.completionRate
        end)
    end
    
    return gaps
end

-- Generate progress insights and recommendations
local function generateProgressInsights(playerId, timestamp)
    if not playerId then
        return {success = false, error = "Player ID required for insights generation"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local insights = {
        success = true,
        operation = "generateProgressInsights",
        generatedAt = timestamp or 0,
        insights = {},
        recommendations = {}
    }
    
    -- Analyze completion rate
    local completionRate = collection.pokedex.completionPercentage
    if completionRate < 10 then
        table.insert(insights.insights, {
            type = "progress",
            message = "You're just getting started! Focus on exploring different areas to encounter new species.",
            priority = "high"
        })
        table.insert(insights.recommendations, {
            action = "explore",
            description = "Visit different routes and locations to discover new Pokemon species"
        })
    elseif completionRate < 50 then
        table.insert(insights.insights, {
            type = "progress",
            message = "Good progress! You've caught " .. collection.pokedex.totalCaught .. " species so far.",
            priority = "medium"
        })
    else
        table.insert(insights.insights, {
            type = "progress",
            message = "Excellent collection! You're over halfway to completing your Pokedex.",
            priority = "low"
        })
    end
    
    -- Analyze capture efficiency
    local captureStats = collection.statistics.captureStats
    if captureStats.captureSuccessRate < 50 then
        table.insert(insights.insights, {
            type = "efficiency",
            message = "Consider using stronger Pokeballs or status effects to improve capture success rate.",
            priority = "medium"
        })
        table.insert(insights.recommendations, {
            action = "improve_capture",
            description = "Use Great Balls, Ultra Balls, or status-inducing moves for better capture rates"
        })
    end
    
    -- Analyze recent activity
    local velocity = calculateProgressVelocity(playerId, 7, timestamp or 0)
    if velocity.success and velocity.velocities.capturesPerDay < 1 then
        table.insert(insights.insights, {
            type = "activity",
            message = "Your collection progress has slowed down. Try exploring new areas!",
            priority = "medium"
        })
        table.insert(insights.recommendations, {
            action = "increase_activity",
            description = "Spend more time in the wild to encounter and catch new Pokemon"
        })
    end
    
    -- Find best region to focus on
    local gapAnalysis = analyzeCollectionGaps(playerId, "all", "missing")
    if gapAnalysis.success and #gapAnalysis.gaps > 0 then
        local bestRegion = gapAnalysis.gaps[1] -- Lowest completion rate
        table.insert(insights.recommendations, {
            action = "focus_region",
            description = "Focus on " .. bestRegion.region .. " region - you have the most potential progress there",
            region = bestRegion.region,
            potential = bestRegion.missingCount
        })
    end
    
    return insights
end

-- Track daily, weekly, and monthly progress
local function updateProgressTracking(playerId, timestamp)
    if not playerId then
        return {success = false, error = "Player ID required for progress tracking"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local currentTime = timestamp or 0
    local date = os.date("*t", currentTime / 1000) -- Convert to seconds for os.date
    
    -- Create date keys
    local dayKey = string.format("%04d-%02d-%02d", date.year, date.month, date.day)
    local weekKey = string.format("%04d-W%02d", date.year, math.ceil(date.yday / 7))
    local monthKey = string.format("%04d-%02d", date.year, date.month)
    
    local analytics = collection.statistics.progressAnalytics
    
    -- Update daily progress
    if not analytics.dailyProgress[dayKey] then
        analytics.dailyProgress[dayKey] = {
            date = dayKey,
            captures = 0,
            encounters = 0,
            achievements = 0,
            completionPercentage = collection.pokedex.completionPercentage
        }
    end
    
    -- Update weekly progress
    if not analytics.weeklyProgress[weekKey] then
        analytics.weeklyProgress[weekKey] = {
            week = weekKey,
            captures = 0,
            encounters = 0,
            achievements = 0,
            startCompletion = collection.pokedex.completionPercentage,
            endCompletion = collection.pokedex.completionPercentage
        }
    end
    
    -- Update monthly progress
    if not analytics.monthlyProgress[monthKey] then
        analytics.monthlyProgress[monthKey] = {
            month = monthKey,
            captures = 0,
            encounters = 0,
            achievements = 0,
            startCompletion = collection.pokedex.completionPercentage,
            endCompletion = collection.pokedex.completionPercentage
        }
    end
    
    -- Update current completion for all periods
    analytics.dailyProgress[dayKey].completionPercentage = collection.pokedex.completionPercentage
    analytics.weeklyProgress[weekKey].endCompletion = collection.pokedex.completionPercentage
    analytics.monthlyProgress[monthKey].endCompletion = collection.pokedex.completionPercentage
    
    return {
        success = true,
        operation = "updateProgressTracking",
        updated = {
            daily = dayKey,
            weekly = weekKey,
            monthly = monthKey
        }
    }
end

-- Collection Goal Management System (Task 5)

-- Create collection goal for player
local function createGoal(playerId, goalDefinition, timestamp)
    if not playerId or not goalDefinition then
        return {success = false, error = "Missing required parameters for goal creation"}
    end
    
    local currentTime = timestamp or 0
    
    -- Get collection state
    if not playerCollections[playerId] then
        playerCollections[playerId] = createCollectionState(playerId)
    end
    
    local collection = playerCollections[playerId]
    local goalId = goalDefinition.id or (goalDefinition.type .. "_" .. tostring(currentTime))
    
    -- Validate goal definition
    local goalTemplate = GOAL_TEMPLATES[goalDefinition.type]
    if not goalTemplate then
        return {success = false, error = "Invalid goal type: " .. tostring(goalDefinition.type)}
    end
    
    -- Create goal
    collection.goals.activeGoals[goalId] = {
        id = goalId,
        type = goalDefinition.type,
        target = goalDefinition.target,
        threshold = tonumber(goalDefinition.threshold),
        currentProgress = 0,
        deadline = goalDefinition.deadline,
        priority = goalDefinition.priority or "medium",
        createdAt = currentTime,
        active = true
    }
    
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "createGoal",
        goalId = goalId,
        goal = collection.goals.activeGoals[goalId]
    }
end

-- Collection Export System (Task 6)

-- Export collection in specified format
local function exportCollection(playerId, format, options, timestamp)
    if not playerId or not format then
        return {success = false, error = "Missing required parameters for collection export"}
    end
    
    -- Get collection state
    if not playerCollections[playerId] then
        return {success = false, error = "Player collection not found"}
    end
    
    local collection = playerCollections[playerId]
    local currentTime = timestamp or 0
    local exportData = {}
    
    if format == "json" then
        exportData = {
            playerId = playerId,
            exportDate = currentTime,
            collection = {
                pokedex = collection.pokedex,
                achievements = collection.achievements,
                statistics = collection.statistics
            }
        }
    elseif format == "csv" then
        exportData = "Species ID,Species Name,Status,Capture Date\n"
        for speciesId, captureDate in pairs(collection.pokedex.caughtSpecies) do
            exportData = exportData .. speciesId .. ",Species" .. speciesId .. ",Caught," .. captureDate .. "\n"
        end
    elseif format == "markdown" then
        exportData = "# " .. collection.sharing.publicProfile.displayName .. "'s Collection\n\n"
        exportData = exportData .. "**Total Caught:** " .. collection.pokedex.totalCaught .. "\n"
        exportData = exportData .. "**Completion:** " .. string.format("%.1f", collection.pokedex.completionPercentage) .. "%\n\n"
    end
    
    -- Update export history
    collection.sharing.exportFormats.lastExportDate = currentTime
    collection.sharing.exportFormats.exportCount = collection.sharing.exportFormats.exportCount + 1
    collection.metadata.lastUpdated = currentTime
    
    return {
        success = true,
        operation = "exportCollection",
        format = format,
        exportData = exportData,
        exportSize = string.len(tostring(exportData))
    }
end

-- Main ProcessLogic Handler - Routes all collection operations
Handlers.add("processLogic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local currentTime = msg.Timestamp or 0
        local playerId = msg.PlayerId or msg.From
        local operation = msg.Operation
        local data = msg.Data and json.decode(msg.Data) or {}
        
        -- Rate limiting check
        if not checkRateLimit(playerId, currentTime) then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Rate limit exceeded - maximum " .. MAX_OPERATIONS_PER_MINUTE .. " operations per minute"
            })
            return
        end
        
        local result = {}
        
        -- Route to appropriate operation
        if operation == "recordCapture" then
            result = recordCapture(playerId, data.pokemonId, data.captureContext, currentTime)
            
        elseif operation == "recordEncounter" then
            result = recordEncounter(playerId, data.speciesId, data.encounterContext, currentTime)
            
        elseif operation == "updateProgress" then
            result = updateProgress(playerId, data.progressType, data, currentTime)
            
        elseif operation == "calculateCompletion" then
            result = calculateCompletion(playerId, data.region, data.criteria, currentTime)
            
        elseif operation == "checkAchievements" then
            result = checkAchievements(playerId, data.triggerEvent, data, currentTime)
            
        elseif operation == "generateStatistics" then
            result = generateStatistics(playerId, data.timeframe, data.categories, currentTime)
            
        elseif operation == "exportCollection" then
            result = exportCollection(playerId, data.format, data.options, currentTime)
            
        elseif operation == "createGoal" then
            result = createGoal(playerId, data.goalDefinition, currentTime)
            
        elseif operation == "getAchievementSummary" then
            result = getAchievementSummary(playerId)
            
        elseif operation == "analyzeCollectionGaps" then
            result = analyzeCollectionGaps(playerId, data.region, data.analysisType)
            
        elseif operation == "generateProgressInsights" then
            result = generateProgressInsights(playerId, currentTime)
            
        elseif operation == "validateCollectionState" then
            if playerCollections[playerId] then
                local fixes = validateCollectionState(playerCollections[playerId])
                result = {success = true, operation = "validateCollectionState", fixes = fixes}
            else
                result = {success = false, error = "Player collection not found"}
            end
            
        else
            result = {success = false, error = "Unknown operation: " .. tostring(operation)}
        end
        
        -- Send response
        if result.success then
            -- Update progress tracking for successful operations
            if operation == "recordCapture" or operation == "recordEncounter" then
                updateProgressTracking(playerId, currentTime)
            end
            
            -- Check achievements for capture/encounter operations
            if operation == "recordCapture" and result.wasNewSpecies then
                local achievementResult = checkAchievements(playerId, "capture", {speciesId = result.speciesId}, currentTime)
                if achievementResult.success and #achievementResult.newAchievements > 0 then
                    result.newAchievements = achievementResult.newAchievements
                end
            end
            
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = json.encode(result),
                Success = "true",
                ProcessId = ao.id,
                Operation = operation,
                Timestamp = tostring(currentTime)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                ProcessId = ao.id,
                Operation = operation,
                Timestamp = tostring(currentTime)
            })
        end
    end
)

-- ADP v1.0 Info Handler - Process self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Collection Tracker Process",
                    version = PROCESS_VERSION,
                    adpVersion = ADP_VERSION,
                    capabilities = {
                        "recordCapture", "recordEncounter", "updateProgress", 
                        "calculateCompletion", "checkAchievements", "generateStatistics",
                        "exportCollection", "createGoal", "analyzeCollectionGaps",
                        "generateProgressInsights", "getAchievementSummary"
                    },
                    messageSchemas = {
                        ProcessLogic = {
                            required = {"Action", "Operation", "PlayerId"},
                            operations = {
                                "recordCapture", "recordEncounter", "updateProgress",
                                "calculateCompletion", "checkAchievements", "generateStatistics",
                                "exportCollection", "createGoal", "analyzeCollectionGaps",
                                "generateProgressInsights", "getAchievementSummary"
                            }
                        }
                    }
                },
                handlers = {"ProcessLogic", "Info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Comprehensive Pokemon collection tracking and progress management with analytics"
                }
            })
        })
    end
)

print("Collection Tracker Process initialized successfully with " .. 
      "comprehensive collection tracking, achievement system, statistics, and analytics")