-- Fusion Battle Engine - AO Process
-- Implements comprehensive Pokemon fusion battle mechanics with exact TypeScript parity
-- Based on TypeScript pokemon.ts calculateBaseStats and battle logic (lines 1598-1614)

-- JSON is available as global in AO processes

-- Initialize fusion battle state
if not FusionBattleState then
    FusionBattleState = {
        initialized = true,
        processName = "Fusion Battle Engine",
        version = "1.0.0",
        adpVersion = "1.0"
    }
end

-- Embedded Battle Type Effectiveness Database
local TypeEffectiveness = {
    ["Normal"] = {["Rock"] = 0.5, ["Ghost"] = 0, ["Steel"] = 0.5},
    ["Fire"] = {["Fire"] = 0.5, ["Water"] = 0.5, ["Grass"] = 2, ["Ice"] = 2, ["Bug"] = 2, ["Rock"] = 0.5, ["Dragon"] = 0.5, ["Steel"] = 2},
    ["Water"] = {["Fire"] = 2, ["Water"] = 0.5, ["Grass"] = 0.5, ["Ground"] = 2, ["Rock"] = 2, ["Dragon"] = 0.5},
    ["Electric"] = {["Water"] = 2, ["Electric"] = 0.5, ["Grass"] = 0.5, ["Ground"] = 0, ["Flying"] = 2, ["Dragon"] = 0.5},
    ["Grass"] = {["Fire"] = 0.5, ["Water"] = 2, ["Grass"] = 0.5, ["Poison"] = 0.5, ["Flying"] = 0.5, ["Bug"] = 0.5, ["Rock"] = 2, ["Ground"] = 2, ["Dragon"] = 0.5, ["Steel"] = 0.5},
    ["Ice"] = {["Fire"] = 0.5, ["Water"] = 0.5, ["Grass"] = 2, ["Ice"] = 0.5, ["Ground"] = 2, ["Flying"] = 2, ["Dragon"] = 2, ["Steel"] = 0.5},
    ["Fighting"] = {["Normal"] = 2, ["Ice"] = 2, ["Poison"] = 0.5, ["Flying"] = 0.5, ["Psychic"] = 0.5, ["Bug"] = 0.5, ["Rock"] = 2, ["Ghost"] = 0, ["Dark"] = 2, ["Steel"] = 2, ["Fairy"] = 0.5},
    ["Poison"] = {["Grass"] = 2, ["Poison"] = 0.5, ["Ground"] = 0.5, ["Rock"] = 0.5, ["Ghost"] = 0.5, ["Steel"] = 0, ["Fairy"] = 2},
    ["Ground"] = {["Fire"] = 2, ["Electric"] = 2, ["Grass"] = 0.5, ["Poison"] = 2, ["Flying"] = 0, ["Bug"] = 0.5, ["Rock"] = 2, ["Steel"] = 2},
    ["Flying"] = {["Electric"] = 0.5, ["Grass"] = 2, ["Ice"] = 0.5, ["Fighting"] = 2, ["Bug"] = 2, ["Rock"] = 0.5, ["Steel"] = 0.5},
    ["Psychic"] = {["Fighting"] = 2, ["Poison"] = 2, ["Psychic"] = 0.5, ["Dark"] = 0, ["Steel"] = 0.5},
    ["Bug"] = {["Fire"] = 0.5, ["Grass"] = 2, ["Fighting"] = 0.5, ["Poison"] = 0.5, ["Flying"] = 0.5, ["Psychic"] = 2, ["Ghost"] = 0.5, ["Dark"] = 2, ["Steel"] = 0.5, ["Fairy"] = 0.5},
    ["Rock"] = {["Fire"] = 2, ["Ice"] = 2, ["Fighting"] = 0.5, ["Ground"] = 0.5, ["Flying"] = 2, ["Bug"] = 2, ["Steel"] = 0.5},
    ["Ghost"] = {["Normal"] = 0, ["Psychic"] = 2, ["Ghost"] = 2, ["Dark"] = 0.5},
    ["Dragon"] = {["Dragon"] = 2, ["Steel"] = 0.5, ["Fairy"] = 0},
    ["Dark"] = {["Fighting"] = 0.5, ["Psychic"] = 2, ["Ghost"] = 2, ["Dark"] = 0.5, ["Fairy"] = 0.5},
    ["Steel"] = {["Fire"] = 0.5, ["Water"] = 0.5, ["Electric"] = 0.5, ["Ice"] = 2, ["Rock"] = 2, ["Steel"] = 0.5, ["Fairy"] = 2},
    ["Fairy"] = {["Fire"] = 0.5, ["Fighting"] = 2, ["Poison"] = 0.5, ["Dragon"] = 2, ["Dark"] = 2, ["Steel"] = 0.5}
}

-- Nature Multipliers Database (exact values: 0.9, 1.0, 1.1)
local NatureMultipliers = {
    HARDY = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    LONELY = {1.1, 0.9, 1.0, 1.0, 1.0, 1.0},
    BRAVE = {1.1, 1.0, 0.9, 1.0, 1.0, 1.0},
    ADAMANT = {1.1, 1.0, 1.0, 0.9, 1.0, 1.0},
    NAUGHTY = {1.1, 1.0, 1.0, 1.0, 0.9, 1.0},
    BOLD = {0.9, 1.1, 1.0, 1.0, 1.0, 1.0},
    DOCILE = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    RELAXED = {1.0, 1.1, 0.9, 1.0, 1.0, 1.0},
    IMPISH = {1.0, 1.1, 1.0, 0.9, 1.0, 1.0},
    LAX = {1.0, 1.1, 1.0, 1.0, 0.9, 1.0},
    TIMID = {0.9, 1.0, 1.0, 1.0, 1.0, 1.1},
    HASTY = {1.0, 0.9, 1.0, 1.0, 1.0, 1.1},
    SERIOUS = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    JOLLY = {1.0, 1.0, 1.0, 0.9, 1.0, 1.1},
    NAIVE = {1.0, 1.0, 1.0, 1.0, 0.9, 1.1},
    MODEST = {0.9, 1.0, 1.0, 1.1, 1.0, 1.0},
    MILD = {1.0, 0.9, 1.0, 1.1, 1.0, 1.0},
    QUIET = {1.0, 1.0, 0.9, 1.1, 1.0, 1.0},
    BASHFUL = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0},
    RASH = {1.0, 1.0, 1.0, 1.1, 0.9, 1.0},
    CALM = {0.9, 1.0, 1.0, 1.0, 1.1, 1.0},
    GENTLE = {1.0, 0.9, 1.0, 1.0, 1.1, 1.0},
    SASSY = {1.0, 1.0, 0.9, 1.0, 1.1, 1.0},
    CAREFUL = {1.0, 1.0, 1.0, 0.9, 1.1, 1.0},
    QUIRKY = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
}

-- Embedded Species Database for Battle Calculations
local SpeciesDatabase = {
    [1] = {id = 1, name = "Bulbasaur", baseStats = {45, 49, 49, 65, 65, 45}, types = {"Grass", "Poison"}},
    [4] = {id = 4, name = "Charmander", baseStats = {39, 52, 43, 60, 50, 65}, types = {"Fire"}},
    [7] = {id = 7, name = "Squirtle", baseStats = {44, 48, 65, 50, 64, 43}, types = {"Water"}},
    [25] = {id = 25, name = "Pikachu", baseStats = {35, 55, 40, 50, 50, 90}, types = {"Electric"}},
    [26] = {id = 26, name = "Raichu", baseStats = {60, 90, 55, 90, 80, 110}, types = {"Electric"}},
    [39] = {id = 39, name = "Jigglypuff", baseStats = {115, 45, 20, 45, 25, 20}, types = {"Normal", "Fairy"}},
    [94] = {id = 94, name = "Gengar", baseStats = {60, 65, 60, 130, 75, 110}, types = {"Ghost", "Poison"}},
    [150] = {id = 150, name = "Mewtwo", baseStats = {106, 110, 90, 154, 90, 130}, types = {"Psychic"}},
    [151] = {id = 151, name = "Mew", baseStats = {100, 100, 100, 100, 100, 100}, types = {"Psychic"}}
}

-- Ability Database with Fusion Interaction Rules
local AbilityDatabase = {
    OVERGROW = {id = 65, name = "Overgrow", description = "Powers up Grass moves when HP is low", fusionCompatible = true},
    BLAZE = {id = 66, name = "Blaze", description = "Powers up Fire moves when HP is low", fusionCompatible = true},
    TORRENT = {id = 67, name = "Torrent", description = "Powers up Water moves when HP is low", fusionCompatible = true},
    STATIC = {id = 9, name = "Static", description = "May paralyze on contact", fusionCompatible = true},
    LIGHTNING_ROD = {id = 31, name = "Lightning Rod", description = "Draws Electric moves", fusionCompatible = false},
    CUTE_CHARM = {id = 56, name = "Cute Charm", description = "May infatuate on contact", fusionCompatible = true},
    CURSED_BODY = {id = 130, name = "Cursed Body", description = "May disable move on contact", fusionCompatible = false},
    PRESSURE = {id = 46, name = "Pressure", description = "Increases PP usage", fusionCompatible = true},
    SYNCHRONIZE = {id = 28, name = "Synchronize", description = "Passes status conditions", fusionCompatible = true}
}

-- Status Effect Database with Fusion Interactions
local StatusEffectDatabase = {
    BURN = {name = "Burn", damage = 0.0625, atkReduction = 0.5, fusionResistance = false},
    FREEZE = {name = "Freeze", immobilize = true, thawChance = 0.2, fusionResistance = false},
    PARALYSIS = {name = "Paralysis", speedReduction = 0.25, immobilizeChance = 0.25, fusionResistance = false},
    POISON = {name = "Poison", damage = 0.125, fusionResistance = false},
    BADLY_POISONED = {name = "Badly Poisoned", damage = 0.0625, stackable = true, fusionResistance = false},
    SLEEP = {name = "Sleep", immobilize = true, wakeChance = 0.33, fusionResistance = false}
}

-- Battle Event Timing Database
local BattleEventTiming = {
    TURN_START = {priority = 1, events = {"weather", "terrain", "abilities"}},
    MOVE_SELECTION = {priority = 2, events = {"choice_lock", "encore", "taunt"}},
    MOVE_EXECUTION = {priority = 3, events = {"damage", "effects", "stat_changes"}},
    TURN_END = {priority = 4, events = {"status_damage", "leftovers", "abilities"}}
}

-- Fusion Battle Stat Calculation (Exact TypeScript Implementation)
-- Based on pokemon.ts lines 1598-1614: Math.ceil((baseStats[s] + fusionBaseStats[s]) / 2)
local function calculateFusionBaseStats(speciesId, fusionSpeciesId)
    local species = SpeciesDatabase[speciesId]
    local fusionSpecies = SpeciesDatabase[fusionSpeciesId]
    
    if not species or not fusionSpecies then
        return nil
    end
    
    local fusionBaseStats = {}
    for i = 1, 6 do
        -- Exact TypeScript calculation: Math.ceil((baseStats[s] + fusionBaseStats[s]) / 2)
        fusionBaseStats[i] = math.ceil((species.baseStats[i] + fusionSpecies.baseStats[i]) / 2)
    end
    
    return fusionBaseStats
end

-- Fusion Battle Stat Calculation with Exact TypeScript Formula
-- Based on pokemon.ts lines 1548-1589 calculateStats method
local function calculateFusionBattleStats(pokemonData, battleContext)
    local level = pokemonData.level or 50
    local ivs = pokemonData.ivs or {31, 31, 31, 31, 31, 31}
    local nature = pokemonData.nature or "HARDY"
    local fusionBaseStats = pokemonData.fusionBaseStats or pokemonData.baseStats
    
    -- Validation: Ensure fusion base stats are available
    if not fusionBaseStats then
        return nil, "Fusion base stats required for battle calculation"
    end
    
    -- Validation: Check fusion combination validity
    if pokemonData.fusionSpeciesId and pokemonData.speciesId == pokemonData.fusionSpeciesId then
        return nil, "Cannot fuse Pokemon with itself"
    end
    
    local battleStats = {}
    local natureMultipliers = NatureMultipliers[nature] or NatureMultipliers.HARDY
    
    for i = 1, 6 do
        -- Exact TypeScript stat calculation formula
        local baseStat = math.floor((2 * fusionBaseStats[i] + ivs[i]) * level * 0.01)
        
        if i == 1 then -- HP stat
            battleStats[i] = baseStat + level + 10
        else
            baseStat = baseStat + 5
            -- Apply nature multiplier with exact TypeScript rounding
            local natureMultiplier = natureMultipliers[i]
            if natureMultiplier ~= 1.0 then
                if natureMultiplier > 1.0 then
                    baseStat = math.max(math.ceil(baseStat * natureMultiplier), 1)
                else
                    baseStat = math.max(math.floor(baseStat * natureMultiplier), 1)
                end
            end
            battleStats[i] = baseStat
        end
    end
    
    return battleStats
end

-- Fusion Type Effectiveness Calculation
local function calculateFusionTypeEffectiveness(attackingTypes, defendingTypes)
    local totalEffectiveness = 1.0
    
    for _, attackType in ipairs(attackingTypes) do
        for _, defendType in ipairs(defendingTypes) do
            local effectiveness = 1.0
            if TypeEffectiveness[attackType] and TypeEffectiveness[attackType][defendType] then
                effectiveness = TypeEffectiveness[attackType][defendType]
            end
            totalEffectiveness = totalEffectiveness * effectiveness
        end
    end
    
    return totalEffectiveness
end

-- Fusion Ability Activation Logic
local function processFusionAbilityActivation(pokemonData, battleContext, trigger)
    local abilities = pokemonData.abilities or {}
    local activatedAbilities = {}
    
    for _, abilityName in ipairs(abilities) do
        local ability = AbilityDatabase[abilityName]
        if ability and ability.fusionCompatible then
            -- Process ability trigger logic based on battle context
            if trigger == "battle_start" or trigger == "turn_start" or trigger == "on_damage" then
                table.insert(activatedAbilities, {
                    name = abilityName,
                    effect = ability.description,
                    triggered = true
                })
            end
        end
    end
    
    return activatedAbilities
end

-- Fusion Status Effect Application
local function applyFusionStatusEffect(pokemonData, statusEffect, battleContext)
    local effect = StatusEffectDatabase[statusEffect]
    if not effect then
        return false
    end
    
    local application = {
        applied = true,
        effect = statusEffect,
        damage = effect.damage or 0,
        turns = battleContext.statusTurns or 3,
        fusionResistance = effect.fusionResistance
    }
    
    return application
end

-- Fusion AI Decision Engine with Advanced Strategy
local function processFusionAIDecision(pokemonData, battleState, availableMoves)
    local decision = {
        selectedMove = nil,
        reasoning = "fusion_optimal",
        priority = 1,
        targetSelection = "optimal"
    }
    
    -- Advanced AI: Multi-factor decision making for fusion Pokemon
    local bestMove = nil
    local bestScore = 0
    local enemyTypes = battleState.enemyTypes or {}
    
    for _, move in ipairs(availableMoves) do
        local score = move.power or 0
        
        -- Factor 1: Base power
        if score <= 0 then score = 40 end -- Status moves baseline
        
        -- Factor 2: STAB bonus for fusion types (both types considered)
        if move.type and pokemonData.types then
            for _, pokeType in ipairs(pokemonData.types) do
                if move.type == pokeType then
                    score = score * 1.5
                    break
                end
            end
        end
        
        -- Factor 3: Type effectiveness against enemy
        if move.type and #enemyTypes > 0 then
            local effectiveness = calculateFusionTypeEffectiveness({move.type}, enemyTypes)
            score = score * effectiveness
            
            -- Bonus for super effective moves
            if effectiveness > 1.5 then
                score = score * 1.2
            end
        end
        
        -- Factor 4: Fusion Pokemon strategy preferences
        if pokemonData.fusionSpeciesId then
            -- Prefer diverse move types from both fusion components
            if move.category == "special" and pokemonData.stats and pokemonData.stats[4] > pokemonData.stats[2] then
                score = score * 1.1 -- Prefer special moves if special attack higher
            elseif move.category == "physical" and pokemonData.stats and pokemonData.stats[2] > pokemonData.stats[4] then
                score = score * 1.1 -- Prefer physical moves if attack higher
            end
        end
        
        -- Factor 5: Battle situation analysis
        if battleState.enemyHP and battleState.enemyHP < 0.3 then
            -- Prioritize finishing moves when enemy is low
            score = score * 1.3
        end
        
        if score > bestScore then
            bestScore = score
            bestMove = move
            decision.reasoning = string.format("fusion_ai_score_%.1f", score)
        end
    end
    
    decision.selectedMove = bestMove
    decision.calculatedScore = bestScore
    return decision
end

-- Fusion Battle Event Handler
local function processFusionBattleEvent(eventType, battleContext, participants)
    local events = BattleEventTiming[eventType]
    if not events then
        return {processed = false, error = "Unknown event type"}
    end
    
    local processedEvents = {}
    for _, event in ipairs(events.events) do
        table.insert(processedEvents, {
            event = event,
            priority = events.priority,
            timestamp = battleContext.timestamp or 0,
            processed = true
        })
    end
    
    return {
        processed = true,
        events = processedEvents,
        priority = events.priority
    }
end

-- Handler: Calculate Fusion Battle Stats
Handlers.add("calculate-fusion-battle-stats",
    Handlers.utils.hasMatchingTag("Action", "CalculateFusionBattleStats"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.pokemon then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon data required"
            })
            return
        end
        
        local pokemon = data.pokemon
        local battleContext = data.battleContext or {}
        
        -- Calculate fusion base stats if fusion species provided
        if pokemon.fusionSpeciesId then
            pokemon.fusionBaseStats = calculateFusionBaseStats(pokemon.speciesId, pokemon.fusionSpeciesId)
            if not pokemon.fusionBaseStats then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Invalid fusion species combination"
                })
                return
            end
        end
        
        local battleStats, error = calculateFusionBattleStats(pokemon, battleContext)
        if not battleStats then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = error or "Failed to calculate fusion battle stats"
            })
            return
        end
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                fusionBattleStats = battleStats,
                fusionBaseStats = pokemon.fusionBaseStats,
                calculation = {
                    level = pokemon.level,
                    nature = pokemon.nature,
                    isFusion = pokemon.fusionSpeciesId ~= nil
                }
            })
        })
    end
)

-- Handler: Process Fusion Move Interaction
Handlers.add("process-fusion-move-interaction",
    Handlers.utils.hasMatchingTag("Action", "ProcessFusionMoveInteraction"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.move or not data.attacker or not data.defender then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Move, attacker, and defender data required"
            })
            return
        end
        
        local attackerTypes = data.attacker.types or {}
        local defenderTypes = data.defender.types or {}
        local effectiveness = calculateFusionTypeEffectiveness({data.move.type}, defenderTypes)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                moveInteraction = {
                    moveType = data.move.type,
                    effectiveness = effectiveness,
                    damage = (data.move.power or 0) * effectiveness,
                    isFusionMove = data.attacker.fusionSpeciesId ~= nil
                }
            })
        })
    end
)

-- Handler: Calculate Fusion Type Effectiveness
Handlers.add("calculate-fusion-type-effectiveness",
    Handlers.utils.hasMatchingTag("Action", "CalculateFusionTypeEffectiveness"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.attackingTypes or not data.defendingTypes then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Attacking and defending types required"
            })
            return
        end
        
        local effectiveness = calculateFusionTypeEffectiveness(data.attackingTypes, data.defendingTypes)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                typeEffectiveness = {
                    attackingTypes = data.attackingTypes,
                    defendingTypes = data.defendingTypes,
                    effectiveness = effectiveness,
                    description = effectiveness > 1 and "Super effective" or 
                                  effectiveness < 1 and "Not very effective" or "Normal damage"
                }
            })
        })
    end
)

-- Handler: Process Fusion Ability Activation
Handlers.add("process-fusion-ability-activation",
    Handlers.utils.hasMatchingTag("Action", "ProcessFusionAbilityActivation"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.pokemon or not data.trigger then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon data and trigger required"
            })
            return
        end
        
        local activatedAbilities = processFusionAbilityActivation(data.pokemon, data.battleContext, data.trigger)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                abilityActivation = {
                    trigger = data.trigger,
                    activatedAbilities = activatedAbilities,
                    totalAbilities = #activatedAbilities
                }
            })
        })
    end
)

-- Handler: Process Fusion AI Decision
Handlers.add("process-fusion-ai-decision",
    Handlers.utils.hasMatchingTag("Action", "ProcessFusionAIDecision"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.pokemon or not data.availableMoves then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon data and available moves required"
            })
            return
        end
        
        local decision = processFusionAIDecision(data.pokemon, data.battleState, data.availableMoves)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                aiDecision = decision
            })
        })
    end
)

-- Handler: Apply Fusion Status Effect
Handlers.add("apply-fusion-status-effect",
    Handlers.utils.hasMatchingTag("Action", "ApplyFusionStatusEffect"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.pokemon or not data.statusEffect then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Pokemon data and status effect required"
            })
            return
        end
        
        local application = applyFusionStatusEffect(data.pokemon, data.statusEffect, data.battleContext)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                statusApplication = application
            })
        })
    end
)

-- Handler: Process Fusion Battle Event
Handlers.add("process-fusion-battle-event",
    Handlers.utils.hasMatchingTag("Action", "ProcessFusionBattleEvent"),
    function(msg)
        local data = json.decode(msg.Data or "{}")
        
        if not data.eventType or not data.battleContext then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Event type and battle context required"
            })
            return
        end
        
        local eventResult = processFusionBattleEvent(data.eventType, data.battleContext, data.participants)
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                battleEvent = eventResult
            })
        })
    end
)

-- ADP v1.0 Compliance - Info Handler
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Fusion Battle Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "calculateFusionBattleStats",
                        "processFusionMoveInteraction", 
                        "calculateFusionTypeEffectiveness",
                        "processFusionAbilityActivation",
                        "processFusionAIDecision",
                        "applyFusionStatusEffect",
                        "processFusionBattleEvent"
                    },
                    messageSchemas = {
                        CalculateFusionBattleStats = {
                            required = {"Action", "Data"},
                            dataFields = {"pokemon", "battleContext"}
                        },
                        ProcessFusionMoveInteraction = {
                            required = {"Action", "Data"},
                            dataFields = {"move", "attacker", "defender"}
                        },
                        CalculateFusionTypeEffectiveness = {
                            required = {"Action", "Data"}, 
                            dataFields = {"attackingTypes", "defendingTypes"}
                        }
                    }
                },
                handlers = {
                    "calculate-fusion-battle-stats",
                    "process-fusion-move-interaction",
                    "calculate-fusion-type-effectiveness", 
                    "process-fusion-ability-activation",
                    "process-fusion-ai-decision",
                    "apply-fusion-status-effect",
                    "process-fusion-battle-event",
                    "info",
                    "health-check"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    precisionMatching = "TypeScript pokemon.ts calculateBaseStats exact formulas"
                }
            })
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
                timestamp = msg.Timestamp,
                fusionBattleEngineReady = true
            })
        })
    end
)

print("Fusion Battle Engine process initialized with ADP v1.0 compliance")