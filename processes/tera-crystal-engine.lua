-- Tera Crystal Resource Engine AO Process
-- Handles Tera Crystal generation, inventory, and progression for PokéRogue AO migration
-- ADP v1.0 Compliant - Self-documenting AO process

-- AO provides json global - no require needed

-- ============================================================================
-- EMBEDDED DATABASE STRUCTURES
-- ============================================================================

-- Tera Crystal Configuration Database
local TERA_CRYSTAL_CONFIG = {
    -- Drop rate configuration
    dropRates = {
        teraOrb = {
            baseWeight = 1,
            progressionMultiplier = 2,
            waveThreshold = 50,
            maxWeight = 4,
            tier = "ULTRA"
        },
        teraShard = {
            baseWeight = 1,
            stellarProbability = 1/64,  -- Special 1/64 probability for Stellar
            tier = "ULTRA",
            requiresTeraOrb = true
        }
    },
    
    -- Type configuration
    types = {
        regular = {
            "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
            "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", 
            "BUG", "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY"
        },
        special = {"STELLAR"}
    },
    
    -- Blocked Pokemon species (cannot Terastallize)
    blockedSpecies = {
        TERAPAGOS = true,
        OGERPON = true,
        SHEDINJA = true
    },
    
    -- Blocked states (cannot Terastallize while in these states)
    blockedStates = {
        megaEvolved = true,
        dynamaxed = true,
        ultraNecrozma = true
    },
    
    -- Progression gates
    progression = {
        firstUnlockWave = 50,
        championRewardWave = 200,  -- Approximate champion encounter
        achievementTrigger = "first_terastallization",
        classicModeRestriction = true
    }
}

-- ============================================================================
-- CORE CALCULATION FUNCTIONS
-- ============================================================================

-- Calculate Tera Orb drop weight based on wave progression
-- Formula: Math.min(Math.max(Math.floor(waveIndex / 50) * 2, 1), 4)
local function calculateTeraOrbWeight(waveIndex)
    if not waveIndex or waveIndex < 1 then
        return 0
    end
    
    local baseCalc = math.floor(waveIndex / 50) * 2
    local weight = math.min(math.max(baseCalc, 1), 4)
    return weight
end

-- Generate Tera Shard type with party exclusion logic
local function generateTeraShardType(partyTeraTypes, randomSeed)
    -- Use AO-compatible random seed for deterministic behavior
    math.randomseed(randomSeed or os.time())
    
    -- Check for Stellar special probability (1/64)
    if math.random(64) == 1 then
        return "STELLAR"
    end
    
    -- Get available regular types
    local availableTypes = {}
    
    -- Determine if party has uniform Tera type
    local uniformType = nil
    local hasUniformType = true
    
    if partyTeraTypes and #partyTeraTypes > 0 then
        uniformType = partyTeraTypes[1]
        for i = 2, #partyTeraTypes do
            if partyTeraTypes[i] ~= uniformType then
                hasUniformType = false
                break
            end
        end
    else
        hasUniformType = false
    end
    
    -- Build available types list (exclude uniform party type)
    for _, teraType in ipairs(TERA_CRYSTAL_CONFIG.types.regular) do
        if not hasUniformType or teraType ~= uniformType then
            table.insert(availableTypes, teraType)
        end
    end
    
    -- Select random type from available types
    if #availableTypes > 0 then
        local randomIndex = math.random(#availableTypes)
        return availableTypes[randomIndex]
    end
    
    -- Fallback to NORMAL if no types available
    return "NORMAL"
end

-- Check if Pokemon is blocked from Terastallization
local function isTeraBlocked(pokemonData)
    if not pokemonData then
        return true
    end
    
    -- Check blocked species
    if pokemonData.speciesId and TERA_CRYSTAL_CONFIG.blockedSpecies[pokemonData.speciesId] then
        return true
    end
    
    -- Check blocked states
    if pokemonData.megaEvolved or 
       pokemonData.isDynamaxed or 
       pokemonData.isUltraNecrozma then
        return true
    end
    
    return false
end

-- Validate wave-based availability
local function canUnlockAtWave(waveIndex, gameMode)
    if not waveIndex then
        return false
    end
    
    -- Classic mode restriction for waves 1-49
    if gameMode == "CLASSIC" and waveIndex < TERA_CRYSTAL_CONFIG.progression.firstUnlockWave then
        return false
    end
    
    return true
end

-- ============================================================================
-- STATE MANAGEMENT FUNCTIONS
-- ============================================================================

-- Initialize process state
local function initializeState()
    if not State then
        State = {
            playerStates = {},  -- Per-player Tera Crystal states
            initialized = true,
            version = "1.0.0"
        }
    end
end

-- Get or create player Tera Crystal state
local function getPlayerState(playerId)
    if not State.playerStates[playerId] then
        State.playerStates[playerId] = {
            -- Global unlocks
            hasTeraOrb = false,  -- TerastallizeAccessModifier equivalent
            
            -- Pokemon-specific assignments
            pokemonTeraTypes = {},  -- [pokemonId] = "ASSIGNED_TYPE"
            
            -- Battle state
            battleUsage = {
                terasUsed = 0,  -- Reset per battle
                battleId = nil
            },
            
            -- Progression tracking
            achievements = {
                firstTerastallization = false,
                teraCrystalsFound = 0,
                stellarShardsUsed = 0
            }
        }
    end
    
    return State.playerStates[playerId]
end

-- Reset battle state for new battle
local function resetBattleState(playerState, battleId)
    if playerState.battleUsage.battleId ~= battleId then
        playerState.battleUsage.terasUsed = 0
        playerState.battleUsage.battleId = battleId
    end
end

-- ============================================================================
-- MESSAGE HANDLERS
-- ============================================================================

-- Initialize process state
initializeState()

-- Generate Tera Crystal (Orb or Shard)
Handlers.add("generate-tera-crystal",
    Handlers.utils.hasMatchingTag("Action", "GenerateTeraCrystal"),
    function(msg)
        local playerId = msg.From
        local waveIndex = tonumber(msg.WaveIndex or msg.Tags.WaveIndex)
        local gameMode = msg.GameMode or msg.Tags.GameMode or "CLASSIC"
        local crystalType = msg.CrystalType or msg.Tags.CrystalType  -- "orb" or "shard"
        
        -- Validate inputs
        if not waveIndex or waveIndex < 1 then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid WaveIndex",
                Success = "false"
            })
            return
        end
        
        if not crystalType or (crystalType ~= "orb" and crystalType ~= "shard") then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "CrystalType must be 'orb' or 'shard'",
                Success = "false"
            })
            return
        end
        
        -- Check wave-based availability
        if not canUnlockAtWave(waveIndex, gameMode) then
            ao.send({
                Target = msg.From,
                Action = "TeraCrystalGenerated",
                Success = "false",
                Reason = "Wave too early for Classic mode",
                WaveIndex = tostring(waveIndex),
                GameMode = gameMode
            })
            return
        end
        
        local playerState = getPlayerState(playerId)
        
        if crystalType == "orb" then
            -- Generate Tera Orb
            local dropWeight = calculateTeraOrbWeight(waveIndex)
            
            -- Champion battle guaranteed reward
            local isChampionBattle = waveIndex >= TERA_CRYSTAL_CONFIG.progression.championRewardWave
            local guaranteed = isChampionBattle or msg.Guaranteed == "true" or msg.Tags.Guaranteed == "true"
            
            if guaranteed or dropWeight > 0 then
                playerState.hasTeraOrb = true
                playerState.achievements.teraCrystalsFound = playerState.achievements.teraCrystalsFound + 1
                
                ao.send({
                    Target = msg.From,
                    Action = "TeraCrystalGenerated",
                    Success = "true",
                    CrystalType = "orb",
                    DropWeight = tostring(dropWeight),
                    Guaranteed = tostring(guaranteed),
                    WaveIndex = tostring(waveIndex)
                })
            else
                ao.send({
                    Target = msg.From,
                    Action = "TeraCrystalGenerated",
                    Success = "false",
                    Reason = "Drop weight too low",
                    DropWeight = tostring(dropWeight),
                    WaveIndex = tostring(waveIndex)
                })
            end
            
        elseif crystalType == "shard" then
            -- Generate Tera Shard (requires Tera Orb)
            if not playerState.hasTeraOrb then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Tera Orb required for Tera Shard generation",
                    Success = "false"
                })
                return
            end
            
            -- Parse party Tera types for exclusion logic
            local partyTeraTypes = {}
            local partyTypesData = msg.PartyTeraTypes or msg.Tags.PartyTeraTypes
            if partyTypesData then
                partyTeraTypes = json.decode(partyTypesData) or {}
            end
            
            -- Generate random seed from message timestamp
            local randomSeed = tonumber(msg.Timestamp) or os.time()
            
            -- Generate Tera Shard type
            local shardType = generateTeraShardType(partyTeraTypes, randomSeed)
            
            playerState.achievements.teraCrystalsFound = playerState.achievements.teraCrystalsFound + 1
            
            if shardType == "STELLAR" then
                playerState.achievements.stellarShardsUsed = playerState.achievements.stellarShardsUsed + 1
            end
            
            ao.send({
                Target = msg.From,
                Action = "TeraCrystalGenerated",
                Success = "true",
                CrystalType = "shard",
                TeraType = shardType,
                WaveIndex = tostring(waveIndex),
                PartyExcluded = json.encode(partyTeraTypes)
            })
        end
    end
)

-- Apply Tera Shard to Pokemon (permanent type change)
Handlers.add("apply-tera-shard",
    Handlers.utils.hasMatchingTag("Action", "ApplyTeraShard"),
    function(msg)
        local playerId = msg.From
        local pokemonId = msg.PokemonId or msg.Tags.PokemonId
        local teraType = msg.TeraType or msg.Tags.TeraType
        
        -- Validate inputs
        if not pokemonId or pokemonId == "" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required",
                Success = "false"
            })
            return
        end
        
        if not teraType or teraType == "" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "TeraType required",
                Success = "false"
            })
            return
        end
        
        -- Validate Tera type
        local validType = false
        for _, validTeraType in ipairs(TERA_CRYSTAL_CONFIG.types.regular) do
            if teraType == validTeraType then
                validType = true
                break
            end
        end
        
        if teraType == "STELLAR" then
            validType = true
        end
        
        if not validType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid TeraType: " .. teraType,
                Success = "false"
            })
            return
        end
        
        local playerState = getPlayerState(playerId)
        
        -- Apply Tera type to Pokemon (permanent change)
        playerState.pokemonTeraTypes[pokemonId] = teraType
        
        ao.send({
            Target = msg.From,
            Action = "TeraShardApplied",
            Success = "true",
            PokemonId = pokemonId,
            TeraType = teraType
        })
    end
)

-- Check Terastallization eligibility
Handlers.add("check-tera-eligibility",
    Handlers.utils.hasMatchingTag("Action", "CheckTeraEligibility"),
    function(msg)
        local playerId = msg.From
        local pokemonId = msg.PokemonId or msg.Tags.PokemonId
        local battleId = msg.BattleId or msg.Tags.BattleId
        
        -- Validate inputs
        if not pokemonId or pokemonId == "" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required",
                Success = "false"
            })
            return
        end
        
        local playerState = getPlayerState(playerId)
        
        -- Reset battle state if new battle
        if battleId then
            resetBattleState(playerState, battleId)
        end
        
        -- Check basic requirements
        local eligible = true
        local reasons = {}
        
        -- Must have Tera Orb
        if not playerState.hasTeraOrb then
            eligible = false
            table.insert(reasons, "No Tera Orb")
        end
        
        -- Check per-battle usage limit
        if playerState.battleUsage.terasUsed > 0 then
            eligible = false
            table.insert(reasons, "Already used Terastallization this battle")
        end
        
        -- Parse Pokemon data if provided
        local pokemonData = nil
        local pokemonDataRaw = msg.PokemonData or msg.Tags.PokemonData
        if pokemonDataRaw then
            pokemonData = json.decode(pokemonDataRaw) or {}
        end
        
        -- Check if Pokemon is blocked
        if pokemonData and isTeraBlocked(pokemonData) then
            eligible = false
            table.insert(reasons, "Pokemon cannot Terastallize")
        end
        
        ao.send({
            Target = msg.From,
            Action = "TeraEligibilityChecked",
            Success = "true",
            Eligible = tostring(eligible),
            PokemonId = pokemonId,
            Reasons = json.encode(reasons),
            HasTeraOrb = tostring(playerState.hasTeraOrb),
            TerasUsed = tostring(playerState.battleUsage.terasUsed)
        })
    end
)

-- Use Terastallization (consume battle usage)
Handlers.add("use-terastallization",
    Handlers.utils.hasMatchingTag("Action", "UseTerastallization"),
    function(msg)
        local playerId = msg.From
        local pokemonId = msg.PokemonId or msg.Tags.PokemonId
        local battleId = msg.BattleId or msg.Tags.BattleId
        
        -- Validate inputs
        if not pokemonId or pokemonId == "" then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required",
                Success = "false"
            })
            return
        end
        
        local playerState = getPlayerState(playerId)
        
        -- Reset battle state if new battle
        if battleId then
            resetBattleState(playerState, battleId)
        end
        
        -- Check if can use Terastallization
        if not playerState.hasTeraOrb then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "No Tera Orb",
                Success = "false"
            })
            return
        end
        
        if playerState.battleUsage.terasUsed > 0 then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Already used Terastallization this battle",
                Success = "false"
            })
            return
        end
        
        -- Consume usage (battle limitation)
        playerState.battleUsage.terasUsed = playerState.battleUsage.terasUsed + 1
        
        -- Track first Terastallization achievement
        if not playerState.achievements.firstTerastallization then
            playerState.achievements.firstTerastallization = true
        end
        
        -- Get Pokemon's Tera type
        local pokemonTeraType = playerState.pokemonTeraTypes[pokemonId] or "NORMAL"
        
        ao.send({
            Target = msg.From,
            Action = "TerastallizationUsed",
            Success = "true",
            PokemonId = pokemonId,
            TeraType = pokemonTeraType,
            TerasUsed = tostring(playerState.battleUsage.terasUsed),
            FirstTime = tostring(not playerState.achievements.firstTerastallization)
        })
    end
)

-- Reset battle usage (new battle, party heal, etc.)
Handlers.add("reset-battle-usage",
    Handlers.utils.hasMatchingTag("Action", "ResetBattleUsage"),
    function(msg)
        local playerId = msg.From
        local battleId = msg.BattleId or msg.Tags.BattleId
        
        local playerState = getPlayerState(playerId)
        
        -- Reset battle state
        playerState.battleUsage.terasUsed = 0
        if battleId then
            playerState.battleUsage.battleId = battleId
        end
        
        ao.send({
            Target = msg.From,
            Action = "BattleUsageReset",
            Success = "true",
            BattleId = battleId or "",
            TerasUsed = "0"
        })
    end
)

-- Get player Tera Crystal state
Handlers.add("get-tera-state",
    Handlers.utils.hasMatchingTag("Action", "GetTeraState"),
    function(msg)
        local playerId = msg.From
        local playerState = getPlayerState(playerId)
        
        ao.send({
            Target = msg.From,
            Action = "TeraStateRetrieved",
            Success = "true",
            Data = json.encode({
                hasTeraOrb = playerState.hasTeraOrb,
                pokemonTeraTypes = playerState.pokemonTeraTypes,
                battleUsage = playerState.battleUsage,
                achievements = playerState.achievements
            })
        })
    end
)

-- ============================================================================
-- ADP v1.0 COMPLIANCE - INFO HANDLER
-- ============================================================================

Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = "Tera Crystal Resource Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    description = "Manages Tera Crystal generation, inventory, and progression for PokéRogue AO migration",
                    capabilities = {
                        "tera-crystal-generation",
                        "resource-inventory-management", 
                        "battle-usage-tracking",
                        "progression-unlock-system",
                        "terastallization-eligibility"
                    }
                },
                handlers = {
                    {
                        action = "GenerateTeraCrystal",
                        description = "Generate Tera Orb or Tera Shard with wave-based progression",
                        parameters = {
                            WaveIndex = {type = "number", required = true, description = "Current wave number"},
                            GameMode = {type = "string", required = false, description = "Game mode (CLASSIC, etc.)"},
                            CrystalType = {type = "string", required = true, description = "orb or shard"},
                            PartyTeraTypes = {type = "json", required = false, description = "Party Tera types for exclusion"}
                        }
                    },
                    {
                        action = "ApplyTeraShard",
                        description = "Apply Tera Shard to Pokemon for permanent type change",
                        parameters = {
                            PokemonId = {type = "string", required = true, description = "Pokemon identifier"},
                            TeraType = {type = "string", required = true, description = "New Tera type"}
                        }
                    },
                    {
                        action = "CheckTeraEligibility", 
                        description = "Check if Pokemon can Terastallize in current battle",
                        parameters = {
                            PokemonId = {type = "string", required = true, description = "Pokemon identifier"},
                            BattleId = {type = "string", required = false, description = "Battle identifier"},
                            PokemonData = {type = "json", required = false, description = "Pokemon state data"}
                        }
                    },
                    {
                        action = "UseTerastallization",
                        description = "Use Terastallization and consume battle usage",
                        parameters = {
                            PokemonId = {type = "string", required = true, description = "Pokemon identifier"},
                            BattleId = {type = "string", required = false, description = "Battle identifier"}
                        }
                    },
                    {
                        action = "ResetBattleUsage",
                        description = "Reset per-battle usage limitations",
                        parameters = {
                            BattleId = {type = "string", required = false, description = "New battle identifier"}
                        }
                    },
                    {
                        action = "GetTeraState",
                        description = "Retrieve complete player Tera Crystal state",
                        parameters = {}
                    }
                },
                documentation = {
                    dropRateFormula = "Tera Orb: Math.min(Math.max(Math.floor(waveIndex / 50) * 2, 1), 4)",
                    stellarProbability = "1/64 for Stellar Tera Shards",
                    progressionGates = {
                        firstUnlock = 50,
                        classicModeRestriction = true,
                        championReward = true
                    },
                    blockedPokemon = {"TERAPAGOS", "OGERPON", "SHEDINJA"},
                    blockedStates = {"megaEvolved", "dynamaxed", "ultraNecrozma"},
                    usageLimitation = "One Terastallization per battle"
                }
            })
        })
    end
)

-- Health check handler
Handlers.add("ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "Tera Crystal Resource Engine operational",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Tera Crystal Resource Engine initialized successfully")