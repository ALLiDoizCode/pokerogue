-- Biome Progression Engine Process
-- AO Process for managing biome selection, transition, and unlock tracking
-- ADP v1.0 Compliant with self-documentation

local json = require("json")

-- ============================================================================
-- BIOME ENUM AND CONSTANTS
-- ============================================================================

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
    ISLAND = 40,
    LABORATORY = 41,
    END = 50
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

local BiomeNames = {
    [0] = "Town",
    [1] = "Plains",
    [2] = "Grass",
    [3] = "Tall Grass",
    [4] = "Metropolis",
    [5] = "Forest",
    [6] = "Sea",
    [7] = "Swamp",
    [8] = "Beach",
    [9] = "Lake",
    [10] = "Seabed",
    [11] = "Mountain",
    [12] = "Badlands",
    [13] = "Cave",
    [14] = "Desert",
    [15] = "Ice Cave",
    [16] = "Meadow",
    [17] = "Power Plant",
    [18] = "Volcano",
    [19] = "Graveyard",
    [20] = "Dojo",
    [21] = "Factory",
    [22] = "Ruins",
    [23] = "Wasteland",
    [24] = "Abyss",
    [25] = "Space",
    [26] = "Construction Site",
    [27] = "Jungle",
    [28] = "Fairy Cave",
    [29] = "Temple",
    [30] = "Slum",
    [31] = "Snowy Forest",
    [40] = "Island",
    [41] = "Laboratory",
    [50] = "End"
}

-- ============================================================================
-- BIOME LINKS STRUCTURE
-- ============================================================================

local biomeLinks = {
    [BiomeId.TOWN] = BiomeId.PLAINS,
    [BiomeId.PLAINS] = {BiomeId.GRASS, BiomeId.METROPOLIS, BiomeId.LAKE},
    [BiomeId.GRASS] = BiomeId.TALL_GRASS,
    [BiomeId.TALL_GRASS] = {BiomeId.FOREST, BiomeId.CAVE},
    [BiomeId.SLUM] = {BiomeId.CONSTRUCTION_SITE, {BiomeId.SWAMP, 2}},
    [BiomeId.FOREST] = {BiomeId.JUNGLE, BiomeId.MEADOW},
    [BiomeId.SEA] = {BiomeId.SEABED, BiomeId.ICE_CAVE},
    [BiomeId.SWAMP] = {BiomeId.GRAVEYARD, BiomeId.TALL_GRASS},
    [BiomeId.BEACH] = {BiomeId.SEA, {BiomeId.ISLAND, 2}},
    [BiomeId.LAKE] = {BiomeId.BEACH, BiomeId.SWAMP, BiomeId.CONSTRUCTION_SITE},
    [BiomeId.SEABED] = {BiomeId.CAVE, {BiomeId.VOLCANO, 3}},
    [BiomeId.MOUNTAIN] = {BiomeId.VOLCANO, {BiomeId.WASTELAND, 2}, {BiomeId.SPACE, 3}},
    [BiomeId.BADLANDS] = {BiomeId.DESERT, BiomeId.MOUNTAIN},
    [BiomeId.CAVE] = {BiomeId.BADLANDS, BiomeId.LAKE, {BiomeId.LABORATORY, 2}},
    [BiomeId.DESERT] = {BiomeId.RUINS, {BiomeId.CONSTRUCTION_SITE, 2}},
    [BiomeId.ICE_CAVE] = BiomeId.SNOWY_FOREST,
    [BiomeId.MEADOW] = {BiomeId.PLAINS, BiomeId.FAIRY_CAVE},
    [BiomeId.POWER_PLANT] = BiomeId.FACTORY,
    [BiomeId.VOLCANO] = {BiomeId.BEACH, {BiomeId.ICE_CAVE, 3}},
    [BiomeId.GRAVEYARD] = BiomeId.ABYSS,
    [BiomeId.DOJO] = {BiomeId.PLAINS, {BiomeId.JUNGLE, 2}, {BiomeId.TEMPLE, 2}},
    [BiomeId.FACTORY] = {BiomeId.PLAINS, {BiomeId.LABORATORY, 2}},
    [BiomeId.RUINS] = {BiomeId.MOUNTAIN, {BiomeId.FOREST, 2}},
    [BiomeId.WASTELAND] = BiomeId.BADLANDS,
    [BiomeId.ABYSS] = {BiomeId.CAVE, {BiomeId.SPACE, 2}, {BiomeId.WASTELAND, 2}},
    [BiomeId.SPACE] = BiomeId.RUINS,
    [BiomeId.CONSTRUCTION_SITE] = {BiomeId.POWER_PLANT, {BiomeId.DOJO, 2}},
    [BiomeId.JUNGLE] = BiomeId.TEMPLE,
    [BiomeId.FAIRY_CAVE] = {BiomeId.ICE_CAVE, {BiomeId.SPACE, 2}},
    [BiomeId.TEMPLE] = {BiomeId.DESERT, {BiomeId.SWAMP, 2}, {BiomeId.RUINS, 2}},
    [BiomeId.METROPOLIS] = BiomeId.SLUM,
    [BiomeId.SNOWY_FOREST] = {BiomeId.FOREST, {BiomeId.MOUNTAIN, 2}, {BiomeId.LAKE, 2}},
    [BiomeId.ISLAND] = BiomeId.SEA,
    [BiomeId.LABORATORY] = BiomeId.CONSTRUCTION_SITE
}

-- ============================================================================
-- BIOME DEPTHS CALCULATION
-- ============================================================================

local biomeDepths = {}

local function initializeBiomeDepths()
    biomeDepths[BiomeId.TOWN] = {0, 1}

    local function traverseBiome(biome, depth)
        if biome == BiomeId.END then
            return
        end

        local linkedBiomes = {}
        local links = biomeLinks[biome]

        if type(links) == "number" then
            linkedBiomes = {links}
        elseif type(links) == "table" then
            linkedBiomes = links
        end

        for _, linkedBiomeEntry in ipairs(linkedBiomes) do
            local linkedBiome, biomeChance

            if type(linkedBiomeEntry) == "number" then
                linkedBiome = linkedBiomeEntry
                biomeChance = 1
            elseif type(linkedBiomeEntry) == "table" then
                linkedBiome = linkedBiomeEntry[1]
                biomeChance = linkedBiomeEntry[2]
            end

            if linkedBiome then
                local shouldUpdate = false

                if not biomeDepths[linkedBiome] then
                    shouldUpdate = true
                else
                    local currentDepth = biomeDepths[linkedBiome][1]
                    local currentChance = biomeDepths[linkedBiome][2]

                    if biomeChance < currentChance then
                        shouldUpdate = true
                    elseif depth + 1 < currentDepth and biomeChance == currentChance then
                        shouldUpdate = true
                    end
                end

                if shouldUpdate then
                    biomeDepths[linkedBiome] = {depth + 1, biomeChance}
                    traverseBiome(linkedBiome, depth + 1)
                end
            end
        end
    end

    traverseBiome(BiomeId.TOWN, 0)

    -- Calculate END biome depth as max depth + 1
    local maxDepth = 0
    for _, depthData in pairs(biomeDepths) do
        if depthData[1] > maxDepth then
            maxDepth = depthData[1]
        end
    end
    biomeDepths[BiomeId.END] = {maxDepth + 1, 1}
end

-- Initialize biome depths on load
initializeBiomeDepths()

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local playerBiomeStates = {}

local function getOrCreatePlayerState(playerId)
    if not playerBiomeStates[playerId] then
        playerBiomeStates[playerId] = {
            playerId = playerId,
            currentBiome = BiomeId.TOWN,
            unlockedBiomes = {
                [BiomeId.TOWN] = 0
            },
            biomeHistory = {},
            currentWaveIndex = 0,
            nextBiomeTransitionWave = 10
        }
    end
    return playerBiomeStates[playerId]
end

-- ============================================================================
-- WEIGHTED RANDOM SELECTION
-- ============================================================================

local function randSeedIntMock(max, seed)
    -- For testing, use simple modulo. In production, this would use proper seeded RNG
    return (seed or 0) % max
end

local function selectWeightedBiome(biomes, seed)
    local filteredBiomes = {}

    for _, biomeEntry in ipairs(biomes) do
        local biome, weight

        if type(biomeEntry) == "number" then
            biome = biomeEntry
            weight = 1
        elseif type(biomeEntry) == "table" then
            biome = biomeEntry[1]
            weight = biomeEntry[2] or 1
        end

        -- Filter based on weight: higher weight = less likely
        -- TypeScript: .filter(b => !Array.isArray(b) || !randSeedInt(b[1]))
        if weight == 1 then
            table.insert(filteredBiomes, biome)
        else
            local roll = randSeedIntMock(weight, seed)
            if roll == 0 then
                table.insert(filteredBiomes, biome)
            end
        end
    end

    if #filteredBiomes == 0 then
        -- If all weighted biomes were filtered out, include them all
        for _, biomeEntry in ipairs(biomes) do
            local biome = type(biomeEntry) == "table" and biomeEntry[1] or biomeEntry
            table.insert(filteredBiomes, biome)
        end
    end

    return filteredBiomes
end

-- ============================================================================
-- BIOME SELECTION LOGIC
-- ============================================================================

local function selectNextBiome(currentBiome, waveIndex, gameMode, hasMapModifier, seed)
    -- Check for END biome conditions
    if gameMode == "classic" and waveIndex >= 50 then
        return BiomeId.END, {BiomeId.END}, false
    end

    if gameMode == "daily" and waveIndex >= 50 then
        return BiomeId.END, {BiomeId.END}, false
    end

    -- Get biome links
    local links = biomeLinks[currentBiome]

    if not links then
        return nil, {}, false
    end

    -- Single biome link
    if type(links) == "number" then
        return links, {links}, false
    end

    -- Multiple biome links
    if type(links) == "table" then
        local filteredBiomes = selectWeightedBiome(links, seed)

        -- Map modifier enables player choice
        if #filteredBiomes > 1 and hasMapModifier then
            return nil, filteredBiomes, true
        end

        -- Random selection from filtered biomes
        if #filteredBiomes > 0 then
            local index = randSeedIntMock(#filteredBiomes, seed) + 1
            return filteredBiomes[index], filteredBiomes, false
        end
    end

    return nil, {}, false
end

-- ============================================================================
-- BIOME TRANSITION
-- ============================================================================

local function executeBiomeTransition(playerId, fromBiome, toBiome, waveIndex, timestamp)
    local state = getOrCreatePlayerState(playerId)

    -- Validate transition
    local links = biomeLinks[fromBiome]
    local isValid = false

    if type(links) == "number" and links == toBiome then
        isValid = true
    elseif type(links) == "table" then
        for _, entry in ipairs(links) do
            local biome = type(entry) == "table" and entry[1] or entry
            if biome == toBiome then
                isValid = true
                break
            end
        end
    end

    if not isValid and toBiome ~= BiomeId.END then
        return false, "Invalid biome transition"
    end

    -- Check if first visit
    local firstVisit = state.unlockedBiomes[toBiome] == nil

    -- Update state
    state.currentBiome = toBiome
    state.currentWaveIndex = waveIndex

    if firstVisit then
        state.unlockedBiomes[toBiome] = timestamp
    end

    -- Add to history
    table.insert(state.biomeHistory, {
        biomeId = toBiome,
        waveIndex = waveIndex,
        timestamp = timestamp
    })

    return true, nil, firstVisit
end

-- ============================================================================
-- BIOME INFO QUERIES
-- ============================================================================

local function getBiomeInfo(biomeId)
    if not BiomeNames[biomeId] then
        return nil
    end

    local links = biomeLinks[biomeId]
    local linkedBiomes = {}
    local linkedBiomesWeighted = {}

    if type(links) == "number" then
        table.insert(linkedBiomes, links)
        table.insert(linkedBiomesWeighted, {biomeId = links, weight = 1})
    elseif type(links) == "table" then
        for _, entry in ipairs(links) do
            if type(entry) == "number" then
                table.insert(linkedBiomes, entry)
                table.insert(linkedBiomesWeighted, {biomeId = entry, weight = 1})
            elseif type(entry) == "table" then
                table.insert(linkedBiomes, entry[1])
                table.insert(linkedBiomesWeighted, {biomeId = entry[1], weight = entry[2]})
            end
        end
    end

    local depth = biomeDepths[biomeId] or {0, 1}

    return {
        id = biomeId,
        name = BiomeNames[biomeId],
        linkedBiomes = linkedBiomes,
        linkedBiomesWeighted = linkedBiomesWeighted,
        depthRange = {depth[1], depth[1]},
        poolTiers = {0, 1, 2, 3, 4, 5, 6, 7, 8}
    }
end

-- ============================================================================
-- AO MESSAGE HANDLERS
-- ============================================================================

-- Info Handler (ADP v1.0 Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    id = ao.id,
                    name = "Biome Progression Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "SelectNextBiome",
                        "ExecuteBiomeTransition",
                        "GetPlayerBiomeState",
                        "GetBiomeInfo",
                        "ValidateBiomeAccess"
                    },
                    messageSchemas = {
                        SelectNextBiome = {
                            required = {"Action", "PlayerId", "CurrentBiome", "CurrentWaveIndex"},
                            optional = {"GameMode", "HasMapModifier", "Seed"}
                        },
                        ExecuteBiomeTransition = {
                            required = {"Action", "PlayerId", "FromBiome", "ToBiome", "WaveIndex"}
                        },
                        GetPlayerBiomeState = {
                            required = {"Action", "PlayerId"},
                            optional = {"IncludeHistory"}
                        },
                        GetBiomeInfo = {
                            required = {"Action"},
                            optional = {"BiomeId"}
                        },
                        ValidateBiomeAccess = {
                            required = {"Action", "PlayerId", "BiomeId", "CurrentBiome"}
                        }
                    }
                },
                handlers = {
                    "Info",
                    "SelectNextBiome",
                    "ExecuteBiomeTransition",
                    "GetPlayerBiomeState",
                    "GetBiomeInfo",
                    "ValidateBiomeAccess"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Manages biome progression, selection, and unlock tracking for PokéRogue game"
                },
                biomeData = {
                    totalBiomes = 36,
                    specialBiomes = 1,
                    graphBased = true
                }
            })
        })
    end
)

-- Select Next Biome Handler
Handlers.add("select-next-biome",
    Handlers.utils.hasMatchingTag("Action", "SelectNextBiome"),
    function(msg)
        local playerId = msg.PlayerId
        local currentBiome = tonumber(msg.CurrentBiome)
        local waveIndex = tonumber(msg.CurrentWaveIndex)
        local gameMode = msg.GameMode or "classic"
        local hasMapModifier = msg.HasMapModifier == "true"
        local seed = tonumber(msg.Seed) or waveIndex

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        if not currentBiome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "CurrentBiome required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local nextBiome, availableBiomes, requiresChoice = selectNextBiome(
            currentBiome,
            waveIndex,
            gameMode,
            hasMapModifier,
            seed
        )

        ao.send({
            Target = msg.From,
            Action = "BiomeSelected",
            PlayerId = playerId,
            NextBiome = nextBiome and tostring(nextBiome) or "",
            AvailableBiomes = json.encode(availableBiomes),
            NextWaveIndex = tostring(waveIndex),
            RequiresPlayerChoice = tostring(requiresChoice),
            TransitionType = nextBiome == BiomeId.END and "end_biome" or "standard",
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- Execute Biome Transition Handler
Handlers.add("execute-biome-transition",
    Handlers.utils.hasMatchingTag("Action", "ExecuteBiomeTransition"),
    function(msg)
        local playerId = msg.PlayerId
        local fromBiome = tonumber(msg.FromBiome)
        local toBiome = tonumber(msg.ToBiome)
        local waveIndex = tonumber(msg.WaveIndex)
        local timestamp = tonumber(msg.Timestamp) or 0

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        if not toBiome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "ToBiome required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local success, errorMsg, firstVisit = executeBiomeTransition(
            playerId,
            fromBiome,
            toBiome,
            waveIndex,
            timestamp
        )

        if not success then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = errorMsg,
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local state = getOrCreatePlayerState(playerId)

        ao.send({
            Target = msg.From,
            Action = "BiomeTransitioned",
            PlayerId = playerId,
            NewBiome = tostring(toBiome),
            BiomeName = BiomeNames[toBiome] or "Unknown",
            FirstVisit = tostring(firstVisit),
            UnlockedTimestamp = tostring(state.unlockedBiomes[toBiome]),
            Success = "true",
            IsFinalBiome = tostring(toBiome == BiomeId.END),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- Get Player Biome State Handler
Handlers.add("get-player-biome-state",
    Handlers.utils.hasMatchingTag("Action", "GetPlayerBiomeState"),
    function(msg)
        local playerId = msg.PlayerId
        local includeHistory = msg.IncludeHistory == "true"

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local state = getOrCreatePlayerState(playerId)

        local totalUnlocked = 0
        for _ in pairs(state.unlockedBiomes) do
            totalUnlocked = totalUnlocked + 1
        end

        local responseData = {
            currentBiome = state.currentBiome,
            currentWaveIndex = state.currentWaveIndex,
            nextTransitionWave = state.nextBiomeTransitionWave,
            unlockedBiomes = state.unlockedBiomes,
            totalBiomesUnlocked = totalUnlocked,
            progressionPercentage = math.floor((totalUnlocked / 36) * 100)
        }

        if includeHistory then
            responseData.biomeHistory = state.biomeHistory
        end

        ao.send({
            Target = msg.From,
            Action = "PlayerBiomeData",
            PlayerId = playerId,
            Data = json.encode(responseData),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

-- Get Biome Info Handler
Handlers.add("get-biome-info",
    Handlers.utils.hasMatchingTag("Action", "GetBiomeInfo"),
    function(msg)
        local biomeId = msg.BiomeId and tonumber(msg.BiomeId) or nil

        if biomeId then
            local info = getBiomeInfo(biomeId)
            if not info then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Invalid biome ID",
                    Timestamp = tostring(msg.Timestamp)
                })
                return
            end

            ao.send({
                Target = msg.From,
                Action = "BiomeInfo",
                Data = json.encode({biome = info}),
                Timestamp = tostring(msg.Timestamp)
            })
        else
            -- Return all biomes
            local allBiomes = {}
            for id, name in pairs(BiomeNames) do
                local info = getBiomeInfo(id)
                if info then
                    table.insert(allBiomes, info)
                end
            end

            ao.send({
                Target = msg.From,
                Action = "BiomeInfo",
                Data = json.encode({biomes = allBiomes}),
                Timestamp = tostring(msg.Timestamp)
            })
        end
    end
)

-- Validate Biome Access Handler
Handlers.add("validate-biome-access",
    Handlers.utils.hasMatchingTag("Action", "ValidateBiomeAccess"),
    function(msg)
        local playerId = msg.PlayerId
        local biomeId = tonumber(msg.BiomeId)
        local currentBiome = tonumber(msg.CurrentBiome)
        local waveIndex = tonumber(msg.WaveIndex) or 0

        if not playerId or not biomeId or not currentBiome then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId, BiomeId, and CurrentBiome required",
                Timestamp = tostring(msg.Timestamp)
            })
            return
        end

        local links = biomeLinks[currentBiome]
        local isLinked = false
        local accessible = false
        local reason = ""

        if type(links) == "number" and links == biomeId then
            isLinked = true
            accessible = true
        elseif type(links) == "table" then
            for _, entry in ipairs(links) do
                local linkedBiome = type(entry) == "table" and entry[1] or entry
                if linkedBiome == biomeId then
                    isLinked = true
                    accessible = true
                    break
                end
            end
        end

        if not isLinked then
            reason = "Biome not linked from current location"
        end

        -- Check wave milestone
        if accessible and waveIndex % 10 ~= 0 then
            accessible = false
            reason = "Biome transitions only at wave milestones (every 10 waves)"
        end

        ao.send({
            Target = msg.From,
            Action = "BiomeAccessValidated",
            PlayerId = playerId,
            BiomeId = tostring(biomeId),
            Accessible = tostring(accessible),
            Reason = reason,
            IsLinked = tostring(isLinked),
            Timestamp = tostring(msg.Timestamp)
        })
    end
)

print("Biome Progression Engine initialized with " .. 36 .. " biomes")
