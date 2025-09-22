-- Input Validation & Sanitization System
-- Comprehensive validation for all AO message inputs with schema validation and sanitization
-- ADP v1.0 Compliant Process

-- Core validation utilities
local function validateType(value, expectedType, fieldName)
    if type(value) ~= expectedType then
        return false, fieldName .. " must be of type " .. expectedType .. ", got " .. type(value)
    end
    return true, nil
end

local function validateRange(value, min, max, fieldName)
    if type(value) ~= "number" then
        return false, fieldName .. " must be a number for range validation"
    end
    if value < min or value > max then
        return false, fieldName .. " must be between " .. min .. " and " .. max .. ", got " .. value
    end
    return true, nil
end

local function validateStringLength(value, minLength, maxLength, fieldName)
    if type(value) ~= "string" then
        return false, fieldName .. " must be a string for length validation"
    end
    local length = string.len(value)
    if length < minLength or length > maxLength then
        return false, fieldName .. " length must be between " .. minLength .. " and " .. maxLength .. ", got " .. length
    end
    return true, nil
end

local function validatePattern(value, pattern, fieldName)
    if type(value) ~= "string" then
        return false, fieldName .. " must be a string for pattern validation"
    end
    if not string.match(value, pattern) then
        return false, fieldName .. " does not match required pattern"
    end
    return true, nil
end

local function validateWhitelist(value, allowedValues, fieldName)
    if type(allowedValues) ~= "table" then
        return false, "Invalid whitelist configuration for " .. fieldName
    end
    
    for _, allowedValue in ipairs(allowedValues) do
        if value == allowedValue then
            return true, nil
        end
    end
    
    return false, fieldName .. " must be one of: " .. table.concat(allowedValues, ", ")
end

local function validateArray(value, maxLength, itemValidator, fieldName)
    if type(value) ~= "table" then
        return false, fieldName .. " must be an array"
    end
    
    if #value > maxLength then
        return false, fieldName .. " exceeds maximum length of " .. maxLength
    end
    
    if itemValidator then
        for i, item in ipairs(value) do
            local valid, err = itemValidator(item, fieldName .. "[" .. i .. "]")
            if not valid then
                return false, err
            end
        end
    end
    
    return true, nil
end

-- Forward declaration
local validateField

local function validateObject(value, schema, fieldName)
    if type(value) ~= "table" then
        return false, fieldName .. " must be an object"
    end
    
    if type(schema) ~= "table" then
        return false, "Invalid schema configuration for " .. fieldName
    end
    
    -- Check required fields
    if schema.required then
        for _, requiredField in ipairs(schema.required) do
            if value[requiredField] == nil then
                return false, fieldName .. " is missing required field: " .. requiredField
            end
        end
    end
    
    -- Validate field types and constraints
    if schema.fields then
        for fieldKey, fieldSchema in pairs(schema.fields) do
            local fieldValue = value[fieldKey]
            if fieldValue ~= nil then
                local valid, err = validateField(fieldValue, fieldSchema, fieldName .. "." .. fieldKey)
                if not valid then
                    return false, err
                end
            end
        end
    end
    
    return true, nil
end

-- Field validation dispatcher
validateField = function(value, fieldSchema, fieldName)
    if type(fieldSchema) ~= "table" then
        return false, "Invalid field schema for " .. fieldName
    end
    
    -- Type validation
    if fieldSchema.type then
        local valid, err = validateType(value, fieldSchema.type, fieldName)
        if not valid then return false, err end
    end
    
    -- Range validation for numbers
    if fieldSchema.min or fieldSchema.max then
        local min = fieldSchema.min or -math.huge
        local max = fieldSchema.max or math.huge
        local valid, err = validateRange(value, min, max, fieldName)
        if not valid then return false, err end
    end
    
    -- String length validation
    if fieldSchema.minLength or fieldSchema.maxLength then
        local minLength = fieldSchema.minLength or 0
        local maxLength = fieldSchema.maxLength or math.huge
        local valid, err = validateStringLength(value, minLength, maxLength, fieldName)
        if not valid then return false, err end
    end
    
    -- Pattern validation
    if fieldSchema.pattern then
        local valid, err = validatePattern(value, fieldSchema.pattern, fieldName)
        if not valid then return false, err end
    end
    
    -- Whitelist validation
    if fieldSchema.allowedValues then
        local valid, err = validateWhitelist(value, fieldSchema.allowedValues, fieldName)
        if not valid then return false, err end
    end
    
    -- Array validation
    if fieldSchema.isArray then
        local maxLength = fieldSchema.maxItems or 1000
        local itemValidator = fieldSchema.itemSchema and function(item, itemFieldName)
            return validateField(item, fieldSchema.itemSchema, itemFieldName)
        end
        local valid, err = validateArray(value, maxLength, itemValidator, fieldName)
        if not valid then return false, err end
    end
    
    -- Object validation
    if fieldSchema.objectSchema then
        local valid, err = validateObject(value, fieldSchema.objectSchema, fieldName)
        if not valid then return false, err end
    end
    
    return true, nil
end

-- Predefined schemas for common game data structures
local pokemonSchema = {
    type = "table",
    objectSchema = {
        required = {"id", "species", "level"},
        fields = {
            id = {type = "number", min = 1, max = 9999},
            species = {type = "string", minLength = 1, maxLength = 50},
            level = {type = "number", min = 1, max = 100},
            hp = {type = "number", min = 0, max = 9999},
            maxHp = {type = "number", min = 1, max = 9999},
            status = {type = "string", allowedValues = {"NONE", "SLEEP", "POISON", "BURN", "FREEZE", "PARALYSIS", "BADLY_POISONED"}},
            ivs = {
                type = "table",
                objectSchema = {
                    fields = {
                        hp = {type = "number", min = 0, max = 31},
                        attack = {type = "number", min = 0, max = 31},
                        defense = {type = "number", min = 0, max = 31},
                        spAttack = {type = "number", min = 0, max = 31},
                        spDefense = {type = "number", min = 0, max = 31},
                        speed = {type = "number", min = 0, max = 31}
                    }
                }
            },
            moves = {
                type = "table",
                isArray = true,
                maxItems = 4,
                itemSchema = {
                    type = "table",
                    objectSchema = {
                        required = {"id"},
                        fields = {
                            id = {type = "number", min = 1, max = 9999},
                            name = {type = "string", minLength = 1, maxLength = 50},
                            pp = {type = "number", min = 0, max = 64},
                            maxPp = {type = "number", min = 1, max = 64}
                        }
                    }
                }
            }
        }
    }
}

local inventorySchema = {
    type = "table",
    objectSchema = {
        fields = {
            money = {type = "number", min = 0, max = 999999999},
            items = {
                type = "table",
                -- Note: items is a map, not an array, so we validate differently
            },
            keyItems = {
                type = "table",
                isArray = true,
                maxItems = 50,
                itemSchema = {type = "string", minLength = 1, maxLength = 50}
            }
        }
    }
}

local battleStateSchema = {
    type = "table",
    objectSchema = {
        fields = {
            turn = {type = "number", min = 1, max = 1000},
            phase = {type = "string", allowedValues = {"INIT", "COMMAND_SELECT", "TURN_RESOLVE", "BATTLE_END"}},
            playerPokemon = pokemonSchema,
            enemyPokemon = pokemonSchema,
            weather = {
                type = "table",
                objectSchema = {
                    fields = {
                        type = {type = "string", allowedValues = {"NONE", "RAIN", "SUN", "SANDSTORM", "HAIL", "FOG", "HEAVY_RAIN", "HARSH_SUN", "STRONG_WINDS"}},
                        turnsLeft = {type = "number", min = 0, max = 8}
                    }
                }
            }
        }
    }
}

local gameStateSchema = {
    type = "table",
    objectSchema = {
        required = {"party"},
        fields = {
            party = {
                type = "table",
                isArray = true,
                maxItems = 6,
                itemSchema = pokemonSchema
            },
            inventory = inventorySchema,
            battleState = battleStateSchema,
            progression = {
                type = "table",
                objectSchema = {
                    fields = {
                        exp = {type = "number", min = 0, max = 1000000},
                        badges = {
                            type = "table",
                            isArray = true,
                            maxItems = 8,
                            itemSchema = {type = "string", minLength = 1, maxLength = 50}
                        },
                        unlockedAreas = {
                            type = "table",
                            isArray = true,
                            maxItems = 100,
                            itemSchema = {type = "string", minLength = 1, maxLength = 50}
                        }
                    }
                }
            }
        }
    }
}

-- Input sanitization functions
local function sanitizeString(value, maxLength)
    if type(value) ~= "string" then
        return ""
    end
    
    -- Remove control characters and excessive whitespace
    local sanitized = string.gsub(value, "[%c\r\n\t]+", " ")
    sanitized = string.gsub(sanitized, "%s+", " ")
    sanitized = string.gsub(sanitized, "^%s+", "")
    sanitized = string.gsub(sanitized, "%s+$", "")
    
    -- Truncate to max length
    if maxLength and string.len(sanitized) > maxLength then
        sanitized = string.sub(sanitized, 1, maxLength)
    end
    
    return sanitized
end

local function sanitizeNumber(value, min, max)
    if type(value) ~= "number" then
        return 0
    end
    
    -- Clamp to valid range
    if min and value < min then
        return min
    end
    if max and value > max then
        return max
    end
    
    -- Handle NaN and infinity
    if value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    
    return value
end

-- Message structure validation
local function validateMessageStructure(msg)
    local errors = {}
    
    -- Required fields
    if not msg.From then
        table.insert(errors, "Message missing required field: From")
    end
    
    if not msg.Action then
        table.insert(errors, "Message missing required field: Action")
    end
    
    -- Field type validation
    if msg.From and type(msg.From) ~= "string" then
        table.insert(errors, "From field must be a string")
    end
    
    if msg.Action and type(msg.Action) ~= "string" then
        table.insert(errors, "Action field must be a string")
    end
    
    if msg.Data and type(msg.Data) ~= "string" then
        table.insert(errors, "Data field must be a string (JSON)")
    end
    
    -- Validate From field format (should be a valid process ID)
    if msg.From then
        local valid, err = validatePattern(msg.From, "^[a-zA-Z0-9_-]+$", "From")
        if not valid then
            table.insert(errors, err)
        end
        
        valid, err = validateStringLength(msg.From, 1, 100, "From")
        if not valid then
            table.insert(errors, err)
        end
    end
    
    -- Validate Action field
    if msg.Action then
        local valid, err = validateStringLength(msg.Action, 1, 50, "Action")
        if not valid then
            table.insert(errors, err)
        end
        
        valid, err = validatePattern(msg.Action, "^[a-zA-Z][a-zA-Z0-9_-]*$", "Action")
        if not valid then
            table.insert(errors, err)
        end
    end
    
    return #errors == 0, errors
end

-- Schema-based validation for specific message types
local messageSchemas = {
    ValidateGameState = {
        requiredFields = {"Action", "Data"},
        dataSchema = gameStateSchema
    },
    
    AnalyzeCheatDetection = {
        requiredFields = {"Action", "Data"},
        dataSchema = {
            type = "table",
            objectSchema = {
                required = {"gameState"},
                fields = {
                    gameState = gameStateSchema,
                    previousGameState = gameStateSchema,
                    operationContext = {
                        type = "table",
                        objectSchema = {
                            fields = {
                                timeDelta = {type = "number", min = 0, max = 86400},
                                battleResult = {type = "table"},
                                playerHistory = {type = "table"}
                            }
                        }
                    }
                }
            }
        }
    },
    
    AuthenticatePlayer = {
        requiredFields = {"Action", "Data"},
        dataSchema = {
            type = "table",
            objectSchema = {
                required = {"walletAddress", "signature"},
                fields = {
                    walletAddress = {type = "string", minLength = 40, maxLength = 50, pattern = "^[a-zA-Z0-9_-]+$"},
                    signature = {type = "string", minLength = 1, maxLength = 200},
                    timestamp = {type = "number", min = 0}
                }
            }
        }
    },
    
    BattleAction = {
        requiredFields = {"Action", "Data"},
        dataSchema = {
            type = "table",
            objectSchema = {
                required = {"actionType", "pokemonIndex"},
                fields = {
                    actionType = {type = "string", allowedValues = {"ATTACK", "SWITCH", "USE_ITEM", "RUN"}},
                    pokemonIndex = {type = "number", min = 0, max = 5},
                    moveIndex = {type = "number", min = 0, max = 3},
                    targetIndex = {type = "number", min = 0, max = 5},
                    itemId = {type = "number", min = 1, max = 9999}
                }
            }
        }
    }
}

-- Comprehensive message validation
local function validateMessage(msg)
    local validationResult = {
        valid = true,
        errors = {},
        warnings = {},
        sanitizedData = nil
    }
    
    -- Basic structure validation
    local structureValid, structureErrors = validateMessageStructure(msg)
    if not structureValid then
        validationResult.valid = false
        for _, error in ipairs(structureErrors) do
            table.insert(validationResult.errors, error)
        end
        return validationResult
    end
    
    -- Schema-based validation
    local actionSchema = messageSchemas[msg.Action]
    if actionSchema then
        -- Check required fields
        for _, field in ipairs(actionSchema.requiredFields) do
            if not msg[field] then
                validationResult.valid = false
                table.insert(validationResult.errors, "Missing required field: " .. field)
            end
        end
        
        -- Validate data if present and schema is defined
        if msg.Data and actionSchema.dataSchema then
            local success, data = pcall(json.decode, msg.Data)
            if not success then
                validationResult.valid = false
                table.insert(validationResult.errors, "Invalid JSON in Data field")
            else
                local dataValid, dataError = validateField(data, actionSchema.dataSchema, "Data")
                if not dataValid then
                    validationResult.valid = false
                    table.insert(validationResult.errors, dataError)
                else
                    validationResult.sanitizedData = data
                end
            end
        end
    else
        -- Unknown action type - add warning but don't fail
        table.insert(validationResult.warnings, "Unknown action type: " .. msg.Action)
    end
    
    return validationResult
end

-- Sanitization for common data types
local function sanitizeInput(data, schema)
    if not data or not schema then
        return data
    end
    
    local sanitized = {}
    
    if schema.type == "string" then
        local maxLength = schema.maxLength or 1000
        return sanitizeString(data, maxLength)
    elseif schema.type == "number" then
        return sanitizeNumber(data, schema.min, schema.max)
    elseif schema.type == "table" and schema.objectSchema then
        for key, value in pairs(data) do
            local fieldSchema = schema.objectSchema.fields and schema.objectSchema.fields[key]
            if fieldSchema then
                sanitized[key] = sanitizeInput(value, fieldSchema)
            else
                sanitized[key] = value -- Keep unknown fields as-is with warning
            end
        end
        return sanitized
    elseif schema.type == "table" and schema.isArray then
        for i, item in ipairs(data) do
            if schema.itemSchema then
                sanitized[i] = sanitizeInput(item, schema.itemSchema)
            else
                sanitized[i] = item
            end
        end
        return sanitized
    end
    
    return data
end

-- AO Message Handlers
Handlers.add("validate-input",
    Handlers.utils.hasMatchingTag("Action", "ValidateInput"),
    function(msg)
        local validationResult = validateMessage(msg)
        
        ao.send({
            Target = msg.From,
            Action = "InputValidationResult",
            Data = json.encode(validationResult),
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus",
            Data = json.encode({
                status = "healthy",
                service = "Input Validator",
                version = "1.0.0",
                capabilities = {
                    "message-structure-validation",
                    "schema-based-validation",
                    "input-sanitization",
                    "whitelist-validation",
                    "pattern-validation",
                    "data-type-validation"
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- ADP v1.0 Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = "Input Validator",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "validateMessage",
                        "validateField",
                        "sanitizeInput",
                        "validateMessageStructure",
                        "schemaValidation"
                    },
                    messageSchemas = {
                        ValidateInput = {
                            required = {"Action"},
                            description = "Validates any AO message structure and data"
                        },
                        HealthCheck = {
                            required = {"Action"}
                        }
                    }
                },
                handlers = {"validate-input", "health-check", "info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    purpose = "Comprehensive input validation and sanitization for AO messages",
                    validationFeatures = {
                        "messageStructureValidation",
                        "schemaBasedValidation",
                        "inputSanitization",
                        "whitelistValidation",
                        "patternMatching",
                        "dataTypeValidation",
                        "rangeValidation",
                        "lengthValidation"
                    },
                    supportedSchemas = {
                        "GameState",
                        "Pokemon",
                        "Inventory",
                        "BattleState",
                        "CheatDetectionData",
                        "AuthenticationData",
                        "BattleAction"
                    }
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(msg and msg.Timestamp or 0)
        })
    end
)

-- Export validation functions for testing and integration
_G.InputValidator = {
    validateMessage = validateMessage,
    validateField = validateField,
    validateMessageStructure = validateMessageStructure,
    sanitizeInput = sanitizeInput,
    sanitizeString = sanitizeString,
    sanitizeNumber = sanitizeNumber,
    messageSchemas = messageSchemas,
    pokemonSchema = pokemonSchema,
    gameStateSchema = gameStateSchema
}