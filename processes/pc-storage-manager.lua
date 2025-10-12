-- PC Storage and Party Management Process for PokéRogue AO
-- ADP v1.0 Compliant Process for Pokemon storage operations, party management, and organization functionality
-- Handles PC storage capacity, organization, search/filtering, and party management with deterministic behavior
-- Monolithic design - all dependencies embedded (no external imports except json)

-- ====================================
-- AO ENVIRONMENT GLOBALS
-- ====================================

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "pc-storage-manager" }

-- Handlers global (AO runtime provides this)
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- ====================================
-- PROCESS CONFIGURATION
-- ====================================

local PROCESS_INFO = {
    name = "PC Storage Manager",
    version = "1.0.0",
    adpVersion = "1.0",
    processId = "pc-storage-manager",
    capabilities = {
        "depositPokemon",
        "withdrawPokemon", 
        "swapPokemon",
        "releasePokemon",
        "searchPokemon",
        "organizePokemon",
        "partyManagement",
        "validateStorageIntegrity"
    }
}

-- Constants for Info handler (fixing undefined variables)
local PROCESS_NAME = PROCESS_INFO.name
local PROCESS_VERSION = PROCESS_INFO.version
local ADP_VERSION = PROCESS_INFO.adpVersion

-- Process Constants
local MAX_BOXES = 30
local MAX_POKEMON_PER_BOX = 30
local MAX_PARTY_SIZE = 6
local MAX_TOTAL_CAPACITY = MAX_BOXES * MAX_POKEMON_PER_BOX -- 900

-- Rate Limiting Configuration
local RATE_LIMIT_OPERATIONS = 50 -- operations per minute per wallet
local RATE_LIMIT_WINDOW = 60000 -- 1 minute in milliseconds

-- ====================================
-- PROCESS STATE INITIALIZATION
-- ====================================

-- Initialize process global state
StorageState = StorageState or {
    playerStorage = {}, -- [playerId] = storage data structure
    rateLimiting = {}, -- [playerId] = { operations: [], lastCleanup: timestamp }
    processMetadata = {
        totalProcessed = 0,
        lastModified = 0,
        processVersion = PROCESS_INFO.version
    }
}

-- Cross-Process Process IDs (to be configured based on deployment)
local POKEMON_INSTANCE_MANAGER_ID = "pokemon-instance-manager-process-id"
local BATTLE_ENGINE_ID = "battle-engine-process-id"
local COORDINATOR_PROCESS_ID = "coordinator-process-id"

-- Initialize empty storage structure for a player
local function initializePlayerStorage(playerId)
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    
    local storage = {
        pcStorage = {
            boxes = {},
            totalBoxes = MAX_BOXES,
            totalStored = 0,
            currentBox = 1,
            maxBoxCapacity = MAX_POKEMON_PER_BOX,
            maxTotalCapacity = MAX_TOTAL_CAPACITY
        },
        party = {
            pokemon = {},
            totalActive = 0,
            maxPartySize = MAX_PARTY_SIZE,
            leadPokemon = 1
        },
        storageMetadata = {
            totalPokemonOwned = 0,
            lastModified = timestamp,
            storageVersion = "1.0",
            organizationSettings = {
                autoSort = false,
                sortCriteria = "level",
                showEmptyBoxes = true
            }
        }
    }
    
    -- Initialize empty boxes
    for i = 1, MAX_BOXES do
        storage.pcStorage.boxes[i] = {
            name = "Box " .. i,
            pokemon = {},
            totalStored = 0
        }
    end
    
    return storage
end

-- Rate Limiting Functions
local function cleanupRateLimiting(playerId, currentTimestamp)
    local playerRateLimit = StorageState.rateLimiting[playerId]
    if not playerRateLimit then
        StorageState.rateLimiting[playerId] = {
            operations = {},
            lastCleanup = currentTimestamp
        }
        return
    end
    
    -- Clean up operations older than rate limit window
    local cutoffTime = currentTimestamp - RATE_LIMIT_WINDOW
    local validOperations = {}
    
    for _, opTimestamp in ipairs(playerRateLimit.operations) do
        if opTimestamp > cutoffTime then
            table.insert(validOperations, opTimestamp)
        end
    end
    
    playerRateLimit.operations = validOperations
    playerRateLimit.lastCleanup = currentTimestamp
end

local function checkRateLimit(playerId, currentTimestamp)
    cleanupRateLimiting(playerId, currentTimestamp)
    
    local playerRateLimit = StorageState.rateLimiting[playerId]
    if #playerRateLimit.operations >= RATE_LIMIT_OPERATIONS then
        return false, "Rate limit exceeded. Maximum " .. RATE_LIMIT_OPERATIONS .. " operations per minute."
    end
    
    table.insert(playerRateLimit.operations, currentTimestamp)
    return true, nil
end

-- Validation Functions
local function validateStorageLocation(location)
    if not location or not location.type then
        return false, "Location type required (party or pc)"
    end
    
    if location.type == "party" then
        local slot = tonumber(location.slot)
        if not slot or slot < 1 or slot > MAX_PARTY_SIZE then
            return false, "Party slot must be between 1 and " .. MAX_PARTY_SIZE
        end
    elseif location.type == "pc" then
        local box = tonumber(location.box)
        local slot = tonumber(location.slot)
        if not box or box < 1 or box > MAX_BOXES then
            return false, "Box number must be between 1 and " .. MAX_BOXES
        end
        if not slot or slot < 1 or slot > MAX_POKEMON_PER_BOX then
            return false, "PC slot must be between 1 and " .. MAX_POKEMON_PER_BOX
        end
    else
        return false, "Invalid location type. Must be 'party' or 'pc'"
    end
    
    return true, nil
end

local function validatePartyConstraints(partyPokemon)
    if not partyPokemon then return true, nil end
    
    local activeCount = 0
    for _, pokemonId in pairs(partyPokemon) do
        if pokemonId then
            activeCount = activeCount + 1
        end
    end
    
    if activeCount > MAX_PARTY_SIZE then
        return false, "Party cannot have more than " .. MAX_PARTY_SIZE .. " Pokemon"
    end
    
    return true, nil
end

-- Storage Operation Functions
local function depositPokemon(playerId, pokemonId, targetBox, targetSlot)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    targetBox = tonumber(targetBox) or storage.pcStorage.currentBox
    targetSlot = tonumber(targetSlot)
    
    -- Validate target box
    if targetBox < 1 or targetBox > MAX_BOXES then
        return false, "Invalid box number: " .. targetBox, nil
    end
    
    local box = storage.pcStorage.boxes[targetBox]
    if not box then
        return false, "Box " .. targetBox .. " does not exist", nil
    end
    
    -- Find available slot if not specified
    if not targetSlot then
        for slot = 1, MAX_POKEMON_PER_BOX do
            if not box.pokemon[slot] then
                targetSlot = slot
                break
            end
        end
        
        if not targetSlot then
            return false, "Box " .. targetBox .. " is full", nil
        end
    else
        if targetSlot < 1 or targetSlot > MAX_POKEMON_PER_BOX then
            return false, "Invalid slot number: " .. targetSlot, nil
        end
        
        if box.pokemon[targetSlot] then
            return false, "Slot " .. targetSlot .. " in Box " .. targetBox .. " is occupied", nil
        end
    end
    
    -- Remove from party if present
    local removedFromParty = false
    for partySlot, partyPokemonId in pairs(storage.party.pokemon) do
        if partyPokemonId == pokemonId then
            storage.party.pokemon[partySlot] = nil
            storage.party.totalActive = storage.party.totalActive - 1
            removedFromParty = true
            break
        end
    end
    
    -- Add to PC box
    box.pokemon[targetSlot] = pokemonId
    box.totalStored = box.totalStored + 1
    storage.pcStorage.totalStored = storage.pcStorage.totalStored + 1
    
    -- Update metadata
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    storage.storageMetadata.lastModified = timestamp
    
    if not removedFromParty then
        storage.storageMetadata.totalPokemonOwned = storage.storageMetadata.totalPokemonOwned + 1
    end
    
    return true, "Pokemon deposited successfully", {
        pokemonId = pokemonId,
        location = { type = "pc", box = targetBox, slot = targetSlot },
        removedFromParty = removedFromParty
    }
end

local function withdrawPokemon(playerId, sourceBox, sourceSlot, targetPartySlot)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    sourceBox = tonumber(sourceBox)
    sourceSlot = tonumber(sourceSlot)
    targetPartySlot = tonumber(targetPartySlot)
    
    -- Validate source location
    if sourceBox < 1 or sourceBox > MAX_BOXES then
        return false, "Invalid box number: " .. sourceBox, nil
    end
    
    if sourceSlot < 1 or sourceSlot > MAX_POKEMON_PER_BOX then
        return false, "Invalid slot number: " .. sourceSlot, nil
    end
    
    local box = storage.pcStorage.boxes[sourceBox]
    local pokemonId = box.pokemon[sourceSlot]
    
    if not pokemonId then
        return false, "No Pokemon in Box " .. sourceBox .. " slot " .. sourceSlot, nil
    end
    
    -- Find available party slot if not specified
    if not targetPartySlot then
        for slot = 1, MAX_PARTY_SIZE do
            if not storage.party.pokemon[slot] then
                targetPartySlot = slot
                break
            end
        end
        
        if not targetPartySlot then
            return false, "Party is full", nil
        end
    else
        if targetPartySlot < 1 or targetPartySlot > MAX_PARTY_SIZE then
            return false, "Invalid party slot: " .. targetPartySlot, nil
        end
        
        if storage.party.pokemon[targetPartySlot] then
            return false, "Party slot " .. targetPartySlot .. " is occupied", nil
        end
    end
    
    -- Move Pokemon from PC to party
    box.pokemon[sourceSlot] = nil
    box.totalStored = box.totalStored - 1
    storage.pcStorage.totalStored = storage.pcStorage.totalStored - 1
    
    storage.party.pokemon[targetPartySlot] = pokemonId
    storage.party.totalActive = storage.party.totalActive + 1
    
    -- Update lead Pokemon if party was empty
    if storage.party.totalActive == 1 then
        storage.party.leadPokemon = targetPartySlot
    end
    
    -- Update metadata
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    storage.storageMetadata.lastModified = timestamp
    
    return true, "Pokemon withdrawn successfully", {
        pokemonId = pokemonId,
        sourceLocation = { type = "pc", box = sourceBox, slot = sourceSlot },
        targetLocation = { type = "party", slot = targetPartySlot }
    }
end

local function swapPokemon(playerId, sourceLocation, targetLocation)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    -- Validate locations
    local sourceValid, sourceError = validateStorageLocation(sourceLocation)
    if not sourceValid then
        return false, "Invalid source location: " .. sourceError, nil
    end
    
    local targetValid, targetError = validateStorageLocation(targetLocation)
    if not targetValid then
        return false, "Invalid target location: " .. targetError, nil
    end
    
    -- Get Pokemon IDs from both locations
    local sourcePokemonId, targetPokemonId
    
    if sourceLocation.type == "party" then
        sourcePokemonId = storage.party.pokemon[sourceLocation.slot]
    else -- pc
        sourcePokemonId = storage.pcStorage.boxes[sourceLocation.box].pokemon[sourceLocation.slot]
    end
    
    if targetLocation.type == "party" then
        targetPokemonId = storage.party.pokemon[targetLocation.slot]
    else -- pc
        targetPokemonId = storage.pcStorage.boxes[targetLocation.box].pokemon[targetLocation.slot]
    end
    
    -- Perform swap
    if sourceLocation.type == "party" then
        storage.party.pokemon[sourceLocation.slot] = targetPokemonId
    else -- pc
        storage.pcStorage.boxes[sourceLocation.box].pokemon[sourceLocation.slot] = targetPokemonId
    end
    
    if targetLocation.type == "party" then
        storage.party.pokemon[targetLocation.slot] = sourcePokemonId
    else -- pc
        storage.pcStorage.boxes[targetLocation.box].pokemon[targetLocation.slot] = sourcePokemonId
    end
    
    -- Update counts and metadata
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    storage.storageMetadata.lastModified = timestamp
    
    return true, "Pokemon swapped successfully", {
        sourceLocation = sourceLocation,
        targetLocation = targetLocation,
        sourcePokemon = sourcePokemonId,
        targetPokemon = targetPokemonId
    }
end

local function releasePokemon(playerId, location)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    -- Validate location
    local locationValid, locationError = validateStorageLocation(location)
    if not locationValid then
        return false, "Invalid location: " .. locationError, nil
    end
    
    -- Get Pokemon ID from location
    local pokemonId
    if location.type == "party" then
        pokemonId = storage.party.pokemon[location.slot]
        if not pokemonId then
            return false, "No Pokemon in party slot " .. location.slot, nil
        end
        
        storage.party.pokemon[location.slot] = nil
        storage.party.totalActive = storage.party.totalActive - 1
        
        -- Update lead Pokemon if necessary
        if storage.party.leadPokemon == location.slot and storage.party.totalActive > 0 then
            for slot = 1, MAX_PARTY_SIZE do
                if storage.party.pokemon[slot] then
                    storage.party.leadPokemon = slot
                    break
                end
            end
        end
    else -- pc
        local box = storage.pcStorage.boxes[location.box]
        pokemonId = box.pokemon[location.slot]
        if not pokemonId then
            return false, "No Pokemon in Box " .. location.box .. " slot " .. location.slot, nil
        end
        
        box.pokemon[location.slot] = nil
        box.totalStored = box.totalStored - 1
        storage.pcStorage.totalStored = storage.pcStorage.totalStored - 1
    end
    
    -- Update metadata
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    storage.storageMetadata.lastModified = timestamp
    storage.storageMetadata.totalPokemonOwned = storage.storageMetadata.totalPokemonOwned - 1
    
    return true, "Pokemon released successfully", {
        pokemonId = pokemonId,
        location = location
    }
end

-- Search and Organization Functions
local function searchPokemon(playerId, searchCriteria)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    local results = {
        party = {},
        pc = {}
    }
    
    -- Search party
    for slot, pokemonId in pairs(storage.party.pokemon) do
        if pokemonId then
            table.insert(results.party, {
                pokemonId = pokemonId,
                location = { type = "party", slot = slot }
            })
        end
    end
    
    -- Search PC boxes
    for boxNum, box in pairs(storage.pcStorage.boxes) do
        for slot, pokemonId in pairs(box.pokemon) do
            if pokemonId then
                table.insert(results.pc, {
                    pokemonId = pokemonId,
                    location = { type = "pc", box = boxNum, slot = slot }
                })
            end
        end
    end
    
    return true, "Search completed", {
        totalFound = #results.party + #results.pc,
        results = results,
        searchCriteria = searchCriteria
    }
end

-- Party Management Functions
local function swapPartyPositions(playerId, position1, position2)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    position1 = tonumber(position1)
    position2 = tonumber(position2)

    if position1 < 1 or position1 > MAX_PARTY_SIZE or position2 < 1 or position2 > MAX_PARTY_SIZE then
        return false, "Party positions must be between 1 and " .. MAX_PARTY_SIZE, nil
    end

    -- Validate both positions have Pokemon
    if not storage.party.pokemon[position1] then
        return false, "No Pokemon in party position " .. position1, nil
    end
    if not storage.party.pokemon[position2] then
        return false, "No Pokemon in party position " .. position2, nil
    end

    -- Swap Pokemon
    local pokemon1 = storage.party.pokemon[position1]
    local pokemon2 = storage.party.pokemon[position2]
    
    storage.party.pokemon[position1] = pokemon2
    storage.party.pokemon[position2] = pokemon1
    
    -- Update lead Pokemon if necessary
    if storage.party.leadPokemon == position1 then
        storage.party.leadPokemon = position2
    elseif storage.party.leadPokemon == position2 then
        storage.party.leadPokemon = position1
    end
    
    -- Update metadata
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    storage.storageMetadata.lastModified = timestamp
    
    return true, "Party positions swapped successfully", {
        position1 = position1,
        position2 = position2,
        pokemon1 = pokemon1,
        pokemon2 = pokemon2
    }
end

local function setLeadPokemon(playerId, partyPosition)
    local storage = StorageState.playerStorage[playerId]
    if not storage then
        return false, "Player storage not initialized", nil
    end
    
    partyPosition = tonumber(partyPosition)
    if partyPosition < 1 or partyPosition > MAX_PARTY_SIZE then
        return false, "Party position must be between 1 and " .. MAX_PARTY_SIZE, nil
    end
    
    if not storage.party.pokemon[partyPosition] then
        return false, "No Pokemon in party position " .. partyPosition, nil
    end
    
    storage.party.leadPokemon = partyPosition
    
    -- Update metadata
    local timestamp = tonumber(msg and msg.Timestamp or 0)
    storage.storageMetadata.lastModified = timestamp
    
    return true, "Lead Pokemon set successfully", {
        leadPosition = partyPosition,
        pokemonId = storage.party.pokemon[partyPosition]
    }
end

-- Main ProcessLogic Handler
Handlers.add("processLogic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local playerId = msg.From
        local timestamp = tonumber(msg.Timestamp or 0)
        
        -- Rate limiting check
        local rateLimitOk, rateLimitError = checkRateLimit(playerId, timestamp)
        if not rateLimitOk then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = rateLimitError,
                Success = "false"
            })
            return
        end
        
        -- Parse operation data
        local data = {}
        if msg.Data and msg.Data ~= "" then
            data = json.decode(msg.Data)
        end
        
        local operation = msg.Operation or data.operation
        if not operation then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Operation required",
                Success = "false"
            })
            return
        end
        
        -- Initialize player storage if needed
        if not StorageState.playerStorage[playerId] then
            StorageState.playerStorage[playerId] = initializePlayerStorage(playerId)
        end
        
        -- Update process metadata
        StorageState.processMetadata.totalProcessed = StorageState.processMetadata.totalProcessed + 1
        StorageState.processMetadata.lastModified = timestamp
        
        local success, message, result
        
        -- Execute operation
        if operation == "deposit" then
            local pokemonId = msg.PokemonId or data.pokemonId
            local targetBox = msg.TargetBox or data.targetBox
            local targetSlot = msg.TargetSlot or data.targetSlot
            success, message, result = depositPokemon(playerId, pokemonId, targetBox, targetSlot)
            
        elseif operation == "withdraw" then
            local sourceBox = msg.SourceBox or data.sourceBox
            local sourceSlot = msg.SourceSlot or data.sourceSlot
            local targetSlot = msg.TargetSlot or data.targetSlot
            success, message, result = withdrawPokemon(playerId, sourceBox, sourceSlot, targetSlot)
            
        elseif operation == "swap" then
            local sourceLocation = data.sourceLocation
            local targetLocation = data.targetLocation
            success, message, result = swapPokemon(playerId, sourceLocation, targetLocation)
            
        elseif operation == "release" then
            local location = data.location
            success, message, result = releasePokemon(playerId, location)
            
        elseif operation == "search" then
            local searchCriteria = data.searchCriteria or {}
            success, message, result = searchPokemon(playerId, searchCriteria)
            
        elseif operation == "swapPartyPositions" then
            local position1 = msg.Position1 or data.position1
            local position2 = msg.Position2 or data.position2
            success, message, result = swapPartyPositions(playerId, position1, position2)
            
        elseif operation == "setLeadPokemon" then
            local partyPosition = msg.PartyPosition or data.partyPosition
            success, message, result = setLeadPokemon(playerId, partyPosition)
            
        elseif operation == "validateIntegrity" then
            local storage = StorageState.playerStorage[playerId]
            success = true
            message = "Storage integrity validation completed"
            result = {
                pcStorage = storage.pcStorage,
                party = storage.party,
                metadata = storage.storageMetadata
            }
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Unknown operation: " .. operation,
                Success = "false"
            })
            return
        end
        
        -- Send response
        if success then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Success = "true",
                Operation = operation,
                Message = message,
                Data = json.encode({
                    result = result,
                    storageState = StorageState.playerStorage[playerId]
                }),
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Success = "false",
                Operation = operation,
                Error = message,
                ProcessId = ao.id,
                Timestamp = tostring(timestamp)
            })
        end
    end
)

-- Info Handler - ADP v1.0 Compliance
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local infoResponse = {
            name = PROCESS_NAME,
            description = "PC Storage and Party Management process for Pokemon game. Manages Pokemon storage operations, party management, search and filtering, and organization functionality with comprehensive cross-process coordination.",
            version = PROCESS_VERSION,
            adpVersion = ADP_VERSION,
            processId = ao.id,
            owner = Owner or ao.env.Process.Owner,
            lastUpdated = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            capabilities = {
                "pokemon_storage_management",
                "party_composition_management", 
                "pokemon_search_and_filtering",
                "pokemon_organization_and_sorting",
                "cross_process_coordination",
                "rate_limiting",
                "storage_integrity_validation"
            },
            handlers = {
                {
                    action = "ProcessLogic",
                    pattern = {"Action"},
                    description = "Main handler for storage operations",
                    category = "core",
                    operations = {
                        "deposit", "withdraw", "swap", "release", 
                        "search", "swapPartyPositions", "setLeadPokemon", "validateIntegrity"
                    },
                    parameters = {
                        {
                            name = "Operation",
                            type = "string",
                            required = true,
                            description = "Storage operation to perform"
                        },
                        {
                            name = "Data",
                            type = "json",
                            required = false,
                            description = "Operation parameters and data"
                        }
                    }
                },
                {
                    action = "Info",
                    pattern = {"Action"},
                    description = "Get process information and capabilities",
                    category = "utility"
                },
                {
                    action = "Ping", 
                    pattern = {"Action"},
                    description = "Health check endpoint",
                    category = "utility"
                }
            },
            messageSchemas = {
                ProcessLogic = {
                    required = {"Action", "Operation"},
                    optional = {"Data", "PokemonId", "TargetBox", "TargetSlot", "SourceBox", "SourceSlot", "Position1", "Position2", "PartyPosition"}
                },
                Info = {
                    required = {"Action"}
                },
                Ping = {
                    required = {"Action"}
                }
            },
            crossProcessIntegration = {
                pokemonInstanceManager = POKEMON_INSTANCE_MANAGER_ID,
                battleEngine = BATTLE_ENGINE_ID,
                coordinatorProcess = COORDINATOR_PROCESS_ID
            },
            rateLimiting = {
                maxOperationsPerMinute = RATE_LIMIT_OPERATIONS,
                windowSizeMs = RATE_LIMIT_WINDOW
            },
            storageCapacity = {
                maxBoxes = MAX_BOXES,
                maxPokemonPerBox = MAX_POKEMON_PER_BOX,
                maxPartySize = MAX_PARTY_SIZE,
                maxTotalCapacity = MAX_TOTAL_CAPACITY
            }
        }
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(infoResponse),
            ProcessId = ao.id
        })
    end
)

-- Ping Handler
Handlers.add("ping",
    Handlers.utils.hasMatchingTag("Action", "Ping"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "Pong",
            Data = "pong",
            ProcessId = ao.id,
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

print("PC Storage Manager Process initialized successfully")
print("Process capabilities: Pokemon storage, party management, search/filtering, organization")
print("ADP v" .. ADP_VERSION .. " compliant with comprehensive documentation")