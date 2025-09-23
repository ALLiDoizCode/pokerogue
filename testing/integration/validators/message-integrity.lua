--[[
Message Integrity Validator for AO Process Integration Testing

Validates message structure, data integrity, and protocol compliance
for inter-process communication in the 26-process stateless architecture.
]]

local MessageIntegrityValidator = {}

-- AO Message Schema Validation
local REQUIRED_MESSAGE_FIELDS = {
    "Id", "From", "Target", "Action", "Data", "Timestamp"
}

local OPTIONAL_MESSAGE_FIELDS = {
    "GameState", "Tags", "ProcessId", "Success", "Error"
}

-- Action Types for Different Process Categories
local VALID_ACTIONS = {
    coordinator = {
        "CoordinateWorkflow", "ProcessBattleTurn", "HandleEvolution", 
        "ManageCapture", "QueryGameState", "ValidateState"
    },
    data = {
        "QuerySpecies", "QueryMove", "QueryItem", "QueryAbility",
        "GetTypeChart", "GetNatureModifiers", "GetEvolutionChain"
    },
    logic = {
        "ProcessBattle", "CalculateDamage", "ApplyStatusEffect",
        "ProcessEvolution", "CalculateCapture", "UpdateStats"
    },
    common = {
        "Info", "HealthCheck", "Error", "Success"
    }
}

-- GameState Schema Validation
local GAMESTATE_REQUIRED_FIELDS = {
    "version", "playerId", "party", "progression"
}

local GAMESTATE_OPTIONAL_FIELDS = {
    "battleId", "currentBattle", "inventory", "settings"
}

function MessageIntegrityValidator.validateMessage(message)
    local validation = {
        valid = true,
        errors = {},
        warnings = {},
        metadata = {
            messageType = "unknown",
            processType = "unknown",
            dataSize = 0
        }
    }
    
    -- Basic structure validation
    if type(message) ~= "table" then
        validation.valid = false
        table.insert(validation.errors, "Message must be a table/object")
        return validation
    end
    
    -- Check required fields
    for _, field in ipairs(REQUIRED_MESSAGE_FIELDS) do
        if not message[field] then
            validation.valid = false
            table.insert(validation.errors, "Missing required field: " .. field)
        end
    end
    
    -- Validate field types and formats
    local fieldValidations = {
        {field = "Id", validator = MessageIntegrityValidator.validateId},
        {field = "From", validator = MessageIntegrityValidator.validateProcessId},
        {field = "Target", validator = MessageIntegrityValidator.validateProcessId},
        {field = "Action", validator = MessageIntegrityValidator.validateAction},
        {field = "Data", validator = MessageIntegrityValidator.validateData},
        {field = "Timestamp", validator = MessageIntegrityValidator.validateTimestamp},
        {field = "GameState", validator = MessageIntegrityValidator.validateGameState}
    }
    
    for _, fieldValidation in ipairs(fieldValidations) do
        if message[fieldValidation.field] then
            local fieldResult = fieldValidation.validator(message[fieldValidation.field], message)
            if not fieldResult.valid then
                validation.valid = false
                for _, error in ipairs(fieldResult.errors) do
                    table.insert(validation.errors, fieldValidation.field .. ": " .. error)
                end
            end
            for _, warning in ipairs(fieldResult.warnings) do
                table.insert(validation.warnings, fieldValidation.field .. ": " .. warning)
            end
        end
    end
    
    -- Determine message and process type
    validation.metadata.messageType = MessageIntegrityValidator.classifyMessage(message)
    validation.metadata.processType = MessageIntegrityValidator.classifyProcess(message.Target or message.From)
    
    -- Calculate data size
    validation.metadata.dataSize = MessageIntegrityValidator.calculateMessageSize(message)
    
    -- Check message size constraints (AO has practical limits)
    if validation.metadata.dataSize > 1024 * 1024 then -- 1MB warning threshold
        table.insert(validation.warnings, "Large message size: " .. validation.metadata.dataSize .. " bytes")
    end
    
    return validation
end

function MessageIntegrityValidator.validateId(id, message)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if type(id) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "ID must be a string")
        return validation
    end
    
    if #id == 0 then
        validation.valid = false
        table.insert(validation.errors, "ID cannot be empty")
    end
    
    -- Check for UUID format (recommended but not required)
    if not string.match(id, "^[0-9a-fA-F%-]+$") then
        table.insert(validation.warnings, "ID does not follow UUID format")
    end
    
    return validation
end

function MessageIntegrityValidator.validateProcessId(processId, message)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if type(processId) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "Process ID must be a string")
        return validation
    end
    
    if #processId == 0 then
        validation.valid = false
        table.insert(validation.errors, "Process ID cannot be empty")
    end
    
    -- Check if it matches known process naming patterns
    local knownPatterns = {
        "coordinator%-process",
        ".*%-database",
        ".*%-engine",
        ".*%-validator",
        ".*%-processor"
    }
    
    local matchesPattern = false
    for _, pattern in ipairs(knownPatterns) do
        if string.match(processId, pattern) then
            matchesPattern = true
            break
        end
    end
    
    if not matchesPattern then
        table.insert(validation.warnings, "Process ID does not match known patterns")
    end
    
    return validation
end

function MessageIntegrityValidator.validateAction(action, message)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if type(action) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "Action must be a string")
        return validation
    end
    
    if #action == 0 then
        validation.valid = false
        table.insert(validation.errors, "Action cannot be empty")
        return validation
    end
    
    -- Validate action against known action types
    local processType = MessageIntegrityValidator.classifyProcess(message.Target or message.From)
    local validActions = VALID_ACTIONS[processType] or {}
    
    -- Add common actions
    for _, commonAction in ipairs(VALID_ACTIONS.common) do
        table.insert(validActions, commonAction)
    end
    
    local actionValid = false
    for _, validAction in ipairs(validActions) do
        if action == validAction then
            actionValid = true
            break
        end
    end
    
    if not actionValid then
        table.insert(validation.warnings, "Action '" .. action .. "' not in known action list for " .. processType .. " process")
    end
    
    return validation
end

function MessageIntegrityValidator.validateData(data, message)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if type(data) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "Data must be a JSON string")
        return validation
    end
    
    -- Attempt to parse JSON
    local success, parsed = pcall(function()
        return json and json.decode(data) or nil
    end)
    
    if not success then
        validation.valid = false
        table.insert(validation.errors, "Data is not valid JSON")
        return validation
    end
    
    if parsed then
        -- Validate data structure based on action type
        local actionValidation = MessageIntegrityValidator.validateDataForAction(parsed, message.Action)
        if not actionValidation.valid then
            for _, error in ipairs(actionValidation.errors) do
                table.insert(validation.errors, error)
            end
        end
        for _, warning in ipairs(actionValidation.warnings) do
            table.insert(validation.warnings, warning)
        end
    end
    
    return validation
end

function MessageIntegrityValidator.validateTimestamp(timestamp, message)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if type(timestamp) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "Timestamp must be a string")
        return validation
    end
    
    -- Attempt to convert to number
    local timestampNum = tonumber(timestamp)
    if not timestampNum then
        validation.valid = false
        table.insert(validation.errors, "Timestamp must be a valid number string")
        return validation
    end
    
    -- Check if timestamp is reasonable (not too old or in future)
    local currentTime = os.time()
    local timeDiff = math.abs(currentTime - timestampNum / 1000) -- Convert ms to seconds
    
    if timeDiff > 3600 then -- More than 1 hour difference
        table.insert(validation.warnings, "Timestamp differs from current time by " .. timeDiff .. " seconds")
    end
    
    return validation
end

function MessageIntegrityValidator.validateGameState(gameStateStr, message)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if gameStateStr == nil or gameStateStr == "" then
        -- GameState is optional for some messages
        return validation
    end
    
    if type(gameStateStr) ~= "string" then
        validation.valid = false
        table.insert(validation.errors, "GameState must be a JSON string")
        return validation
    end
    
    -- Attempt to parse JSON
    local success, gameState = pcall(function()
        return json and json.decode(gameStateStr) or nil
    end)
    
    if not success then
        validation.valid = false
        table.insert(validation.errors, "GameState is not valid JSON")
        return validation
    end
    
    if gameState then
        -- Validate GameState structure
        for _, field in ipairs(GAMESTATE_REQUIRED_FIELDS) do
            if not gameState[field] then
                validation.valid = false
                table.insert(validation.errors, "Missing required GameState field: " .. field)
            end
        end
        
        -- Validate specific GameState fields
        if gameState.version and type(gameState.version) ~= "string" then
            validation.valid = false
            table.insert(validation.errors, "GameState version must be a string")
        end
        
        if gameState.playerId and type(gameState.playerId) ~= "string" then
            validation.valid = false
            table.insert(validation.errors, "GameState playerId must be a string")
        end
        
        if gameState.party and type(gameState.party) ~= "table" then
            validation.valid = false
            table.insert(validation.errors, "GameState party must be an array")
        end
    end
    
    return validation
end

function MessageIntegrityValidator.validateDataForAction(data, action)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    -- Action-specific data validation
    if action == "QuerySpecies" then
        if not data.speciesId then
            validation.valid = false
            table.insert(validation.errors, "QuerySpecies requires speciesId")
        end
    elseif action == "ProcessBattle" then
        if not data.battleData then
            validation.valid = false
            table.insert(validation.errors, "ProcessBattle requires battleData")
        end
    elseif action == "CalculateDamage" then
        if not data.attacker or not data.defender or not data.move then
            validation.valid = false
            table.insert(validation.errors, "CalculateDamage requires attacker, defender, and move")
        end
    end
    
    return validation
end

function MessageIntegrityValidator.classifyMessage(message)
    if not message.Action then
        return "unknown"
    end
    
    local action = message.Action
    
    if string.match(action, "Query") then
        return "query"
    elseif string.match(action, "Process") or string.match(action, "Calculate") then
        return "command"
    elseif action == "Success" or action == "Error" then
        return "response"
    elseif action == "Info" or action == "HealthCheck" then
        return "system"
    else
        return "custom"
    end
end

function MessageIntegrityValidator.classifyProcess(processId)
    if not processId then
        return "unknown"
    end
    
    if string.match(processId, "coordinator") then
        return "coordinator"
    elseif string.match(processId, "database") then
        return "data"
    elseif string.match(processId, "engine") then
        return "logic"
    elseif string.match(processId, "validator") or string.match(processId, "processor") then
        return "utility"
    else
        return "unknown"
    end
end

function MessageIntegrityValidator.calculateMessageSize(message)
    -- Approximate message size calculation
    local size = 0
    
    for key, value in pairs(message) do
        size = size + #tostring(key)
        if type(value) == "string" then
            size = size + #value
        elseif type(value) == "table" then
            size = size + #tostring(value) -- Rough approximation
        else
            size = size + #tostring(value)
        end
    end
    
    return size
end

function MessageIntegrityValidator.validateMessageSequence(messages)
    local validation = {valid = true, errors = {}, warnings = {}}
    
    if type(messages) ~= "table" then
        validation.valid = false
        table.insert(validation.errors, "Message sequence must be an array")
        return validation
    end
    
    -- Check for proper request-response pairing
    local pendingRequests = {}
    
    for i, message in ipairs(messages) do
        local msgValidation = MessageIntegrityValidator.validateMessage(message)
        if not msgValidation.valid then
            validation.valid = false
            table.insert(validation.errors, "Message " .. i .. " is invalid: " .. table.concat(msgValidation.errors, ", "))
        end
        
        -- Track request-response patterns
        local messageType = MessageIntegrityValidator.classifyMessage(message)
        if messageType == "query" or messageType == "command" then
            pendingRequests[message.Id] = {
                message = message,
                index = i
            }
        elseif messageType == "response" then
            -- Look for corresponding request
            local found = false
            for requestId, request in pairs(pendingRequests) do
                if message.From == request.message.Target and message.Target == request.message.From then
                    pendingRequests[requestId] = nil
                    found = true
                    break
                end
            end
            if not found then
                table.insert(validation.warnings, "Response message " .. i .. " has no corresponding request")
            end
        end
    end
    
    -- Check for orphaned requests
    for requestId, request in pairs(pendingRequests) do
        table.insert(validation.warnings, "Request message " .. request.index .. " has no response")
    end
    
    return validation
end

return MessageIntegrityValidator