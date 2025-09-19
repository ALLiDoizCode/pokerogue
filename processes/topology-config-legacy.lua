-- Topology Configuration Process
-- ADP v1.0 Compliant Process for 26-Process AO Architecture Discovery
-- Provides complete topology mapping, process metadata, and autonomous discovery

-- Process State
local State = {
    version = "1.0.0",
    adpVersion = "1.0",
    topology = {},
    processMetadata = {},
    lastUpdated = 0
}

-- Initialize 26-Process AO Architecture Topology
local function initializeTopology()
    State.topology = {
        -- Data Layer Processes (8 processes)
        dataLayer = {
            player_data = {
                processId = nil,
                name = "Player Data Store",
                type = "data",
                capabilities = {"store_player", "retrieve_player", "update_player"},
                dependencies = {},
                endpoints = {
                    store = "Action: StorePlayer",
                    retrieve = "Action: RetrievePlayer",
                    update = "Action: UpdatePlayer"
                }
            },
            pokemon_data = {
                processId = nil,
                name = "Pokemon Data Store",
                type = "data",
                capabilities = {"store_pokemon", "retrieve_pokemon", "update_pokemon"},
                dependencies = {},
                endpoints = {
                    store = "Action: StorePokemon",
                    retrieve = "Action: RetrievePokemon",
                    update = "Action: UpdatePokemon"
                }
            },
            battle_data = {
                processId = nil,
                name = "Battle Data Store",
                type = "data",
                capabilities = {"store_battle", "retrieve_battle", "update_battle"},
                dependencies = {},
                endpoints = {
                    store = "Action: StoreBattle",
                    retrieve = "Action: RetrieveBattle",
                    update = "Action: UpdateBattle"
                }
            },
            game_state_data = {
                processId = nil,
                name = "Game State Data Store",
                type = "data",
                capabilities = {"store_state", "retrieve_state", "update_state"},
                dependencies = {},
                endpoints = {
                    store = "Action: StoreGameState",
                    retrieve = "Action: RetrieveGameState",
                    update = "Action: UpdateGameState"
                }
            },
            party_data = {
                processId = nil,
                name = "Party Data Store",
                type = "data",
                capabilities = {"store_party", "retrieve_party", "update_party"},
                dependencies = {},
                endpoints = {
                    store = "Action: StoreParty",
                    retrieve = "Action: RetrieveParty",
                    update = "Action: UpdateParty"
                }
            },
            inventory_data = {
                processId = nil,
                name = "Inventory Data Store",
                type = "data",
                capabilities = {"store_inventory", "retrieve_inventory", "update_inventory"},
                dependencies = {},
                endpoints = {
                    store = "Action: StoreInventory",
                    retrieve = "Action: RetrieveInventory",
                    update = "Action: UpdateInventory"
                }
            },
            arena_data = {
                processId = nil,
                name = "Arena Data Store",
                type = "data",
                capabilities = {"store_arena", "retrieve_arena", "update_arena"},
                dependencies = {},
                endpoints = {
                    store = "Action: StoreArena",
                    retrieve = "Action: RetrieveArena",
                    update = "Action: UpdateArena"
                }
            },
            biome_data = {
                processId = nil,
                name = "Biome Data Store",
                type = "data",
                capabilities = {"store_biome", "retrieve_biome", "update_biome"},
                dependencies = {},
                endpoints = {
                    store = "Action: StoreBiome",
                    retrieve = "Action: RetrieveBiome",
                    update = "Action: UpdateBiome"
                }
            }
        },
        
        -- Logic Layer Processes (17 processes)
        logicLayer = {
            battle_engine = {
                processId = nil,
                name = "Battle Engine",
                type = "logic",
                capabilities = {"process_turn", "calculate_damage", "apply_effects", "validate_move"},
                dependencies = {"battle_data", "pokemon_data", "party_data"},
                endpoints = {
                    processTurn = "Action: ProcessTurn",
                    calculateDamage = "Action: CalculateDamage",
                    applyEffects = "Action: ApplyEffects",
                    validateMove = "Action: ValidateMove"
                }
            },
            pokemon_engine = {
                processId = nil,
                name = "Pokemon Engine",
                type = "logic",
                capabilities = {"level_up", "evolve", "learn_move", "calculate_stats"},
                dependencies = {"pokemon_data", "party_data"},
                endpoints = {
                    levelUp = "Action: LevelUp",
                    evolve = "Action: Evolve",
                    learnMove = "Action: LearnMove",
                    calculateStats = "Action: CalculateStats"
                }
            },
            game_state_engine = {
                processId = nil,
                name = "Game State Engine",
                type = "logic",
                capabilities = {"progress_game", "trigger_event", "validate_state"},
                dependencies = {"game_state_data", "player_data"},
                endpoints = {
                    progressGame = "Action: ProgressGame",
                    triggerEvent = "Action: TriggerEvent",
                    validateState = "Action: ValidateState"
                }
            },
            party_engine = {
                processId = nil,
                name = "Party Engine",
                type = "logic",
                capabilities = {"add_pokemon", "remove_pokemon", "swap_pokemon", "heal_party"},
                dependencies = {"party_data", "pokemon_data"},
                endpoints = {
                    addPokemon = "Action: AddPokemon",
                    removePokemon = "Action: RemovePokemon",
                    swapPokemon = "Action: SwapPokemon",
                    healParty = "Action: HealParty"
                }
            },
            inventory_engine = {
                processId = nil,
                name = "Inventory Engine",
                type = "logic",
                capabilities = {"add_item", "remove_item", "use_item", "validate_inventory"},
                dependencies = {"inventory_data", "player_data"},
                endpoints = {
                    addItem = "Action: AddItem",
                    removeItem = "Action: RemoveItem",
                    useItem = "Action: UseItem",
                    validateInventory = "Action: ValidateInventory"
                }
            },
            catch_engine = {
                processId = nil,
                name = "Catch Engine",
                type = "logic",
                capabilities = {"attempt_catch", "calculate_catch_rate", "apply_ball_modifier"},
                dependencies = {"pokemon_data", "party_data", "inventory_data"},
                endpoints = {
                    attemptCatch = "Action: AttemptCatch",
                    calculateCatchRate = "Action: CalculateCatchRate",
                    applyBallModifier = "Action: ApplyBallModifier"
                }
            },
            move_engine = {
                processId = nil,
                name = "Move Engine",
                type = "logic",
                capabilities = {"execute_move", "calculate_accuracy", "apply_move_effects"},
                dependencies = {"pokemon_data", "battle_data"},
                endpoints = {
                    executeMove = "Action: ExecuteMove",
                    calculateAccuracy = "Action: CalculateAccuracy",
                    applyMoveEffects = "Action: ApplyMoveEffects"
                }
            },
            ability_engine = {
                processId = nil,
                name = "Ability Engine",
                type = "logic",
                capabilities = {"trigger_ability", "validate_ability", "apply_ability_effects"},
                dependencies = {"pokemon_data", "battle_data"},
                endpoints = {
                    triggerAbility = "Action: TriggerAbility",
                    validateAbility = "Action: ValidateAbility",
                    applyAbilityEffects = "Action: ApplyAbilityEffects"
                }
            },
            item_engine = {
                processId = nil,
                name = "Item Engine",
                type = "logic",
                capabilities = {"use_item", "validate_item_use", "apply_item_effects"},
                dependencies = {"inventory_data", "pokemon_data", "battle_data"},
                endpoints = {
                    useItem = "Action: UseItem",
                    validateItemUse = "Action: ValidateItemUse",
                    applyItemEffects = "Action: ApplyItemEffects"
                }
            },
            trainer_engine = {
                processId = nil,
                name = "Trainer Engine",
                type = "logic",
                capabilities = {"train_pokemon", "gain_experience", "distribute_stats"},
                dependencies = {"pokemon_data", "party_data", "player_data"},
                endpoints = {
                    trainPokemon = "Action: TrainPokemon",
                    gainExperience = "Action: GainExperience",
                    distributeStats = "Action: DistributeStats"
                }
            },
            weather_engine = {
                processId = nil,
                name = "Weather Engine",
                type = "logic",
                capabilities = {"set_weather", "apply_weather_effects", "weather_transitions"},
                dependencies = {"battle_data", "biome_data"},
                endpoints = {
                    setWeather = "Action: SetWeather",
                    applyWeatherEffects = "Action: ApplyWeatherEffects",
                    weatherTransitions = "Action: WeatherTransitions"
                }
            },
            status_engine = {
                processId = nil,
                name = "Status Engine",
                type = "logic",
                capabilities = {"apply_status", "remove_status", "process_status_effects"},
                dependencies = {"pokemon_data", "battle_data"},
                endpoints = {
                    applyStatus = "Action: ApplyStatus",
                    removeStatus = "Action: RemoveStatus",
                    processStatusEffects = "Action: ProcessStatusEffects"
                }
            },
            arena_engine = {
                processId = nil,
                name = "Arena Engine",
                type = "logic",
                capabilities = {"generate_encounter", "set_arena_conditions", "spawn_wild_pokemon"},
                dependencies = {"arena_data", "biome_data", "pokemon_data"},
                endpoints = {
                    generateEncounter = "Action: GenerateEncounter",
                    setArenaConditions = "Action: SetArenaConditions",
                    spawnWildPokemon = "Action: SpawnWildPokemon"
                }
            },
            biome_engine = {
                processId = nil,
                name = "Biome Engine",
                type = "logic",
                capabilities = {"generate_biome", "set_biome_modifiers", "biome_transitions"},
                dependencies = {"biome_data", "arena_data"},
                endpoints = {
                    generateBiome = "Action: GenerateBiome",
                    setBiomeModifiers = "Action: SetBiomeModifiers",
                    biomeTransitions = "Action: BiomeTransitions"
                }
            },
            wave_engine = {
                processId = nil,
                name = "Wave Engine",
                type = "logic",
                capabilities = {"progress_wave", "generate_wave_encounter", "calculate_wave_difficulty"},
                dependencies = {"game_state_data", "arena_data", "pokemon_data"},
                endpoints = {
                    progressWave = "Action: ProgressWave",
                    generateWaveEncounter = "Action: GenerateWaveEncounter",
                    calculateWaveDifficulty = "Action: CalculateWaveDifficulty"
                }
            },
            modifier_engine = {
                processId = nil,
                name = "Modifier Engine",
                type = "logic",
                capabilities = {"apply_modifier", "remove_modifier", "calculate_modifier_effects"},
                dependencies = {"pokemon_data", "battle_data", "player_data"},
                endpoints = {
                    applyModifier = "Action: ApplyModifier",
                    removeModifier = "Action: RemoveModifier",
                    calculateModifierEffects = "Action: CalculateModifierEffects"
                }
            },
            event_engine = {
                processId = nil,
                name = "Event Engine",
                type = "logic",
                capabilities = {"trigger_event", "process_event_chain", "validate_event_conditions"},
                dependencies = {"game_state_data", "player_data"},
                endpoints = {
                    triggerEvent = "Action: TriggerEvent",
                    processEventChain = "Action: ProcessEventChain",
                    validateEventConditions = "Action: ValidateEventConditions"
                }
            }
        },
        
        -- Coordination Layer (1 process)
        coordinationLayer = {
            coordinator = {
                processId = nil,
                name = "Process Coordinator",
                type = "coordinator",
                capabilities = {"route_message", "manage_dependencies", "health_check", "orchestrate_workflow"},
                dependencies = {},
                endpoints = {
                    routeMessage = "Action: RouteMessage",
                    manageDependencies = "Action: ManageDependencies",
                    healthCheck = "Action: HealthCheck",
                    orchestrateWorkflow = "Action: OrchestrateWorkflow"
                }
            }
        }
    }
    
    State.lastUpdated = os.time()
end

-- Utility Functions
local function validateInput(data)
    if not data then return false, "Missing data" end
    if type(data) ~= "table" then return false, "Data must be a table" end
    return true, nil
end

local function createResponse(action, data, error)
    return {
        Action = action,
        Data = data or {},
        Error = error,
        Timestamp = os.time(),
        ProcessId = ao.id
    }
end

local function getAllProcesses()
    local processes = {}
    
    -- Add data layer processes
    for name, process in pairs(State.topology.dataLayer) do
        processes[name] = process
    end
    
    -- Add logic layer processes
    for name, process in pairs(State.topology.logicLayer) do
        processes[name] = process
    end
    
    -- Add coordination layer processes
    for name, process in pairs(State.topology.coordinationLayer) do
        processes[name] = process
    end
    
    return processes
end

local function findProcessByName(processName)
    local allProcesses = getAllProcesses()
    return allProcesses[processName]
end

local function getProcessHealth(processName)
    local process = findProcessByName(processName)
    if not process then
        return false, "Process not found"
    end
    
    -- Health validation logic
    local health = {
        name = processName,
        status = "unknown",
        capabilities = process.capabilities,
        dependencies = process.dependencies,
        lastChecked = os.time()
    }
    
    -- If processId is set, consider it healthy (would normally ping the process)
    if process.processId then
        health.status = "healthy"
    else
        health.status = "not_deployed"
    end
    
    return true, health
end

local function getMessageFlows()
    return {
        battleFlow = {
            description = "Battle processing workflow",
            steps = {
                "player_action -> coordinator",
                "coordinator -> battle_engine",
                "battle_engine -> pokemon_data (read)",
                "battle_engine -> move_engine",
                "move_engine -> battle_data (write)",
                "battle_engine -> coordinator (result)"
            }
        },
        catchFlow = {
            description = "Pokemon catching workflow",
            steps = {
                "catch_attempt -> coordinator",
                "coordinator -> catch_engine",
                "catch_engine -> pokemon_data (read)",
                "catch_engine -> party_data (write)",
                "catch_engine -> inventory_data (update)",
                "catch_engine -> coordinator (result)"
            }
        },
        progressionFlow = {
            description = "Game progression workflow",
            steps = {
                "progress_action -> coordinator",
                "coordinator -> game_state_engine",
                "game_state_engine -> wave_engine",
                "wave_engine -> arena_engine",
                "arena_engine -> biome_engine",
                "biome_engine -> coordinator (result)"
            }
        }
    }
end

-- Handler Functions
local function handleGetTopology(msg)
    local success, error = validateInput(msg)
    if not success then
        return createResponse("TopologyError", nil, error)
    end
    
    local topology = {
        version = State.version,
        adpVersion = State.adpVersion,
        lastUpdated = State.lastUpdated,
        totalProcesses = 26,
        layers = {
            data = {
                count = 8,
                processes = State.topology.dataLayer
            },
            logic = {
                count = 17,
                processes = State.topology.logicLayer
            },
            coordination = {
                count = 1,
                processes = State.topology.coordinationLayer
            }
        },
        messageFlows = getMessageFlows(),
        deploymentTopology = {
            pattern = "stateless_ao_processes",
            architecture = "26_process_distributed",
            coordination = "async_message_passing",
            dataConsistency = "eventual_consistency"
        }
    }
    
    return createResponse("TopologyResponse", topology)
end

local function handleValidateProcess(msg)
    local success, error = validateInput(msg)
    if not success then
        return createResponse("ValidationError", nil, error)
    end
    
    local processName = msg.ProcessName or msg.Data.processName
    if not processName then
        return createResponse("ValidationError", nil, "ProcessName required")
    end
    
    local healthSuccess, health = getProcessHealth(processName)
    if not healthSuccess then
        return createResponse("ValidationError", nil, health)
    end
    
    return createResponse("ProcessValidation", health)
end

local function handleGetProcessMetadata(msg)
    local success, error = validateInput(msg)
    if not success then
        return createResponse("MetadataError", nil, error)
    end
    
    local processName = msg.ProcessName or msg.Data.processName
    if not processName then
        return createResponse("MetadataError", nil, "ProcessName required")
    end
    
    local process = findProcessByName(processName)
    if not process then
        return createResponse("MetadataError", nil, "Process not found")
    end
    
    local metadata = {
        name = process.name,
        type = process.type,
        capabilities = process.capabilities,
        dependencies = process.dependencies,
        endpoints = process.endpoints,
        adpCompliant = true,
        processId = process.processId,
        lastUpdated = State.lastUpdated
    }
    
    return createResponse("ProcessMetadata", metadata)
end

local function handleDiscoverProcesses(msg)
    local success, error = validateInput(msg)
    if not success then
        return createResponse("DiscoveryError", nil, error)
    end
    
    local filters = msg.Filters or msg.Data.filters or {}
    local allProcesses = getAllProcesses()
    local discovered = {}
    
    for name, process in pairs(allProcesses) do
        local include = true
        
        -- Apply filters
        if filters.type and process.type ~= filters.type then
            include = false
        end
        
        if filters.capabilities then
            local hasCapability = false
            for _, capability in ipairs(filters.capabilities) do
                for _, processCapability in ipairs(process.capabilities) do
                    if processCapability == capability then
                        hasCapability = true
                        break
                    end
                end
                if hasCapability then break end
            end
            if not hasCapability then
                include = false
            end
        end
        
        if include then
            discovered[name] = {
                name = process.name,
                type = process.type,
                capabilities = process.capabilities,
                endpoints = process.endpoints,
                processId = process.processId
            }
        end
    end
    
    return createResponse("ProcessDiscovery", {
        totalFound = #discovered,
        processes = discovered,
        filters = filters
    })
end

local function handleHealthCheck(msg)
    local allProcesses = getAllProcesses()
    local healthReport = {
        totalProcesses = 0,
        healthyProcesses = 0,
        unhealthyProcesses = 0,
        notDeployedProcesses = 0,
        processHealth = {}
    }
    
    for name, _ in pairs(allProcesses) do
        healthReport.totalProcesses = healthReport.totalProcesses + 1
        local success, health = getProcessHealth(name)
        
        if success then
            healthReport.processHealth[name] = health
            if health.status == "healthy" then
                healthReport.healthyProcesses = healthReport.healthyProcesses + 1
            elseif health.status == "not_deployed" then
                healthReport.notDeployedProcesses = healthReport.notDeployedProcesses + 1
            else
                healthReport.unhealthyProcesses = healthReport.unhealthyProcesses + 1
            end
        else
            healthReport.unhealthyProcesses = healthReport.unhealthyProcesses + 1
            healthReport.processHealth[name] = {
                name = name,
                status = "error",
                error = health
            }
        end
    end
    
    return createResponse("HealthReport", healthReport)
end

local function handleInfo(msg)
    local info = {
        process = {
            name = "Topology Configuration Process",
            version = State.version,
            adpVersion = State.adpVersion,
            capabilities = {
                "getTopology",
                "validateProcess", 
                "getProcessMetadata",
                "discoverProcesses",
                "healthCheck"
            },
            messageSchemas = {
                GetTopology = {
                    required = {"Action"},
                    optional = {}
                },
                ValidateProcess = {
                    required = {"Action", "ProcessName"},
                    optional = {}
                },
                GetProcessMetadata = {
                    required = {"Action", "ProcessName"},
                    optional = {}
                },
                DiscoverProcesses = {
                    required = {"Action"},
                    optional = {"Filters"}
                },
                HealthCheck = {
                    required = {"Action"},
                    optional = {}
                }
            }
        },
        handlers = {
            "GetTopology",
            "ValidateProcess", 
            "GetProcessMetadata",
            "DiscoverProcesses",
            "HealthCheck",
            "Info"
        },
        documentation = {
            adpCompliance = "v1.0",
            selfDocumenting = true,
            description = "Topology configuration and process discovery for 26-process AO architecture",
            autonomousDiscovery = true
        },
        topology = {
            totalProcesses = 26,
            dataLayerProcesses = 8,
            logicLayerProcesses = 17,
            coordinationLayerProcesses = 1,
            architecture = "stateless_ao_distributed"
        }
    }
    
    return createResponse("ProcessInfo", info)
end

-- Initialize topology on startup
initializeTopology()

-- ADP v1.0 Compliant Handlers
Handlers.add("get-topology",
    Handlers.utils.hasMatchingTag("Action", "GetTopology"),
    function(msg)
        local success, response = pcall(handleGetTopology, msg)
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                Error = response.Error,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "TopologyError",
                Error = response
            })
        end
    end
)

Handlers.add("validate-process",
    Handlers.utils.hasMatchingTag("Action", "ValidateProcess"),
    function(msg)
        local success, response = pcall(handleValidateProcess, msg)
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                Error = response.Error,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "ValidationError",
                Error = response
            })
        end
    end
)

Handlers.add("get-process-metadata",
    Handlers.utils.hasMatchingTag("Action", "GetProcessMetadata"),
    function(msg)
        local success, response = pcall(handleGetProcessMetadata, msg)
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                Error = response.Error,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "MetadataError",
                Error = response
            })
        end
    end
)

Handlers.add("discover-processes",
    Handlers.utils.hasMatchingTag("Action", "DiscoverProcesses"),
    function(msg)
        local success, response = pcall(handleDiscoverProcesses, msg)
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                Error = response.Error,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "DiscoveryError",
                Error = response
            })
        end
    end
)

Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        local success, response = pcall(handleHealthCheck, msg)
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                Error = response.Error,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "HealthError",
                Error = response
            })
        end
    end
)

Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local success, response = pcall(handleInfo, msg)
        if success then
            ao.send({
                Target = msg.From,
                Action = "ProcessInfo",
                Data = response.Data,
                Timestamp = response.Timestamp
            })
        else
            ao.send({
                Target = msg.From,
                Action = "InfoError",
                Error = response
            })
        end
    end
)

-- Process initialization complete
print("Topology Configuration Process initialized - ADP v1.0 compliant")
print("Total processes defined: 26 (8 data + 17 logic + 1 coordinator)")
print("Autonomous discovery enabled - send Action: Info for capabilities")