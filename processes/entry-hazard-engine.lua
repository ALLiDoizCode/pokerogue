-- Entry Hazard Engine AO Process
-- Implements Spikes, Stealth Rock, Toxic Spikes, and Sticky Web
-- ADP v1.0 Compliant with comprehensive self-documentation

-- Note: json is available as a global in AO runtime

-- Battle State Storage
local battleStates = {}

-- Type Effectiveness Chart (Rock vs other types for Stealth Rock)
local typeChart = {
    NORMAL = 1.0,
    FIRE = 2.0,     -- Rock super effective vs Fire
    WATER = 1.0,
    ELECTRIC = 1.0,
    GRASS = 1.0,
    ICE = 2.0,      -- Rock super effective vs Ice
    FIGHTING = 0.5, -- Rock not very effective vs Fighting
    POISON = 1.0,
    GROUND = 0.5,   -- Rock not very effective vs Ground
    FLYING = 2.0,   -- Rock super effective vs Flying
    PSYCHIC = 1.0,
    BUG = 2.0,      -- Rock super effective vs Bug
    ROCK = 1.0,
    GHOST = 1.0,
    DRAGON = 1.0,
    DARK = 1.0,
    STEEL = 0.5,    -- Rock not very effective vs Steel
    FAIRY = 1.0
}

-- Hazard Configuration
local hazardConfig = {
    SPIKES = {
        maxLayers = 3,
        groundedOnly = true,
        damageType = "HP_FRACTION"
        -- Damage calculation: 1 / (10 - 2 * layers) matching TypeScript exactly
    },
    STEALTH_ROCK = {
        maxLayers = 1,
        groundedOnly = false,
        damageType = "TYPE_EFFECTIVE",
        baseDamage = 0.125 -- 1/8 base damage
    },
    TOXIC_SPIKES = {
        maxLayers = 2,
        groundedOnly = true,
        damageType = "STATUS",
        effects = { [1] = "POISON", [2] = "BADLY_POISONED" }
    },
    STICKY_WEB = {
        maxLayers = 1,
        groundedOnly = true,
        damageType = "STAT_CHANGE",
        statChanges = { speed = -1 }
    }
}

-- Helper Functions
local function validateInput(data, requiredFields)
    for _, field in ipairs(requiredFields) do
        if not data[field] then
            return false, "Missing required field: " .. field
        end
    end
    return true, nil
end

local function isGrounded(pokemonData)
    -- Check if Pokemon is grounded (not Flying type and doesn't have Levitate)
    if not pokemonData.types then
        return true
    end
    
    for _, type in ipairs(pokemonData.types) do
        if type == "FLYING" then
            return false
        end
    end
    
    -- Check for Levitate ability
    if pokemonData.ability and pokemonData.ability == "LEVITATE" then
        return false
    end
    
    return true
end

local function hasMagicGuard(pokemonData)
    return pokemonData.ability and pokemonData.ability == "MAGIC_GUARD"
end

local function calculateTypeEffectiveness(rockType, defenderTypes)
    local effectiveness = 1.0
    
    if not defenderTypes then
        return effectiveness
    end
    
    for _, type in ipairs(defenderTypes) do
        effectiveness = effectiveness * (typeChart[type] or 1.0)
    end
    
    return effectiveness
end

local function calculateSpikeDamage(pokemonData, layers)
    if not pokemonData.stats or not pokemonData.stats.hp then
        return 0
    end
    
    -- TypeScript formula: 1 / (10 - 2 * layers)
    local damagePercent = 1 / (10 - 2 * layers)
    local damage = math.floor(pokemonData.stats.hp * damagePercent)
    
    return math.max(1, damage) -- Minimum 1 damage
end

local function calculateStealthRockDamage(pokemonData)
    if not pokemonData.stats or not pokemonData.stats.hp or not pokemonData.types then
        return 0
    end
    
    local baseDamage = pokemonData.stats.hp * hazardConfig.STEALTH_ROCK.baseDamage
    local typeEffectiveness = calculateTypeEffectiveness("ROCK", pokemonData.types)
    local finalDamage = math.floor(baseDamage * typeEffectiveness)
    
    return math.max(1, finalDamage) -- Minimum 1 damage
end

local function getBattleState(battleId)
    if not battleStates[battleId] then
        battleStates[battleId] = {
            playerHazards = {},
            enemyHazards = {}
        }
    end
    return battleStates[battleId]
end

local function getHazardsBySide(battleState, side)
    if side == "PLAYER" then
        return battleState.playerHazards
    else
        return battleState.enemyHazards
    end
end

-- Handler: Place Entry Hazard
Handlers.add("place-entry-hazard",
    Handlers.utils.hasMatchingTag("Action", "PlaceEntryHazard"),
    function(msg)
        local hazardType = msg.HazardType
        local side = msg.Side
        local sourceId = tonumber(msg.SourceId or 0)
        local sourceMove = msg.SourceMove
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Validate input
        if not hazardType or not side or not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: HazardType, Side, BattleId",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        if not hazardConfig[hazardType] then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid hazard type: " .. hazardType,
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleState = getBattleState(battleId)
        local hazards = getHazardsBySide(battleState, side)
        
        -- Check if hazard already exists and can stack
        local existingHazard = hazards[hazardType]
        local config = hazardConfig[hazardType]
        
        if existingHazard then
            if existingHazard.layers < config.maxLayers then
                existingHazard.layers = existingHazard.layers + 1
            end
        else
            hazards[hazardType] = {
                hazardType = hazardType,
                side = side,
                layers = 1,
                sourceId = sourceId,
                sourceMove = sourceMove,
                timestamp = timestamp
            }
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                hazardState = hazards[hazardType],
                success = true
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Handler: Activate Entry Hazards (on Pokemon switch-in)
Handlers.add("activate-entry-hazards",
    Handlers.utils.hasMatchingTag("Action", "ActivateEntryHazards"),
    function(msg)
        local pokemonData = json.decode(msg.PokemonData or "{}")
        local side = msg.Side
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Validate input
        if not side or not battleId or not pokemonData then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: Side, BattleId, PokemonData",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleState = getBattleState(battleId)
        local hazards = getHazardsBySide(battleState, side)
        
        local totalDamage = 0
        local statusEffects = {}
        local statChanges = {}
        local activatedHazards = {}
        
        -- Process each hazard type
        for hazardType, hazardData in pairs(hazards) do
            local config = hazardConfig[hazardType]
            local activated = false
            local damage = 0
            local immuneReason = ""
            
            -- Check grounding requirement
            if config.groundedOnly and not isGrounded(pokemonData) then
                immuneReason = "Not grounded"
            -- Check Magic Guard for damaging hazards
            elseif config.damageType ~= "STATUS" and config.damageType ~= "STAT_CHANGE" and hasMagicGuard(pokemonData) then
                immuneReason = "Magic Guard"
            else
                activated = true
                
                if hazardType == "SPIKES" then
                    damage = calculateSpikeDamage(pokemonData, hazardData.layers)
                elseif hazardType == "STEALTH_ROCK" then
                    damage = calculateStealthRockDamage(pokemonData)
                elseif hazardType == "TOXIC_SPIKES" then
                    -- Check for Poison-type neutralization
                    if pokemonData.types then
                        for _, type in ipairs(pokemonData.types) do
                            if type == "POISON" then
                                -- Remove Toxic Spikes when Poison-type enters
                                hazards[hazardType] = nil
                                immuneReason = "Poison-type absorbed"
                                activated = false
                                break
                            end
                        end
                    end
                    
                    if activated then
                        local effect = config.effects[hazardData.layers] or "POISON"
                        table.insert(statusEffects, effect)
                    end
                elseif hazardType == "STICKY_WEB" then
                    for stat, change in pairs(config.statChanges) do
                        statChanges[stat] = change
                    end
                end
            end
            
            if activated or immuneReason ~= "" then
                table.insert(activatedHazards, {
                    hazardType = hazardType,
                    activated = activated,
                    damage = damage,
                    immuneReason = immuneReason
                })
                
                totalDamage = totalDamage + damage
            end
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                activationResult = {
                    totalDamage = totalDamage,
                    statusEffects = statusEffects,
                    statChanges = statChanges,
                    activatedHazards = activatedHazards
                },
                battleState = battleState
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Handler: Remove Entry Hazards
Handlers.add("remove-entry-hazards",
    Handlers.utils.hasMatchingTag("Action", "RemoveEntryHazards"),
    function(msg)
        local removalType = msg.RemovalType
        local side = msg.Side
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Validate input
        if not removalType or not side or not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required fields: RemovalType, Side, BattleId",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleState = getBattleState(battleId)
        local removedHazards = {}
        
        if removalType == "RAPID_SPIN" then
            -- Rapid Spin removes hazards from user's side only
            local hazards = getHazardsBySide(battleState, side)
            for hazardType, _ in pairs(hazards) do
                table.insert(removedHazards, hazardType)
                hazards[hazardType] = nil
            end
        elseif removalType == "DEFOG" then
            -- Defog removes hazards from both sides
            for _, sideHazards in pairs({battleState.playerHazards, battleState.enemyHazards}) do
                for hazardType, _ in pairs(sideHazards) do
                    table.insert(removedHazards, hazardType)
                    sideHazards[hazardType] = nil
                end
            end
        elseif removalType == "MAGIC_BOUNCE" then
            -- Magic Bounce reflects hazard back to opponent
            -- Implementation would depend on battle system integration
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Magic Bounce reflection not implemented",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                removalResult = {
                    removalType = removalType,
                    removedHazards = removedHazards,
                    side = side
                },
                battleState = battleState
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- Handler: Get Hazard State
Handlers.add("get-hazard-state",
    Handlers.utils.hasMatchingTag("Action", "GetHazardState"),
    function(msg)
        local battleId = msg.BattleId
        local timestamp = tonumber(msg.Timestamp or 0)
        
        if not battleId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Missing required field: BattleId",
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
            return
        end
        
        local battleState = getBattleState(battleId)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                battleState = battleState
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(timestamp)
        })
    end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            process = {
                name = "Entry Hazard Engine",
                version = "1.0.0",
                adpVersion = "1.0",
                description = "Implements all four Pokemon entry hazards with TypeScript behavioral parity",
                capabilities = {
                    "PlaceEntryHazard",
                    "ActivateEntryHazards", 
                    "RemoveEntryHazards",
                    "GetHazardState"
                },
                messageSchemas = {
                    PlaceEntryHazard = {
                        required = {"Action", "HazardType", "Side", "BattleId"},
                        optional = {"SourceId", "SourceMove", "Timestamp"}
                    },
                    ActivateEntryHazards = {
                        required = {"Action", "PokemonData", "Side", "BattleId"},
                        optional = {"Timestamp"}
                    },
                    RemoveEntryHazards = {
                        required = {"Action", "RemovalType", "Side", "BattleId"},
                        optional = {"Timestamp"}
                    },
                    GetHazardState = {
                        required = {"Action", "BattleId"},
                        optional = {"Timestamp"}
                    }
                }
            },
            handlers = {
                "PlaceEntryHazard",
                "ActivateEntryHazards",
                "RemoveEntryHazards", 
                "GetHazardState",
                "Info"
            },
            documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true,
                hazardTypes = {
                    "SPIKES - 3 layers, 1/8, 1/6, 1/4 HP damage",
                    "STEALTH_ROCK - 1 layer, 1/8 HP × Rock type effectiveness", 
                    "TOXIC_SPIKES - 2 layers, poison/badly poisoned status",
                    "STICKY_WEB - 1 layer, -1 Speed stage"
                }
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState", 
            Data = json.encode(infoResponse),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Health Check Handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                status = "healthy",
                processId = ao.id,
                activeBattles = #battleStates
            }),
            Success = "true",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("Entry Hazard Engine process initialized successfully")