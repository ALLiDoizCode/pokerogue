-- Data Process Template for PokéRogue AO
-- Provides standardized framework for stateless data processes
-- Version: 2.0 - AO Compliance Enhanced
--
-- AO COMPLIANCE REQUIREMENTS:
-- 1. MONOLITHIC DESIGN: All dependencies must be embedded (no require() statements)
-- 2. HANDLER PATTERN: Use Handlers.add() with proper tag matching
-- 3. ERROR HANDLING: Wrap all operations in pcall
-- 4. PERFORMANCE: Sub-100ms response time target for data queries
-- 5. AO GLOBALS ONLY: Use ao.send(), ao.id, Handlers, json, standard Lua only
--
-- USAGE EXAMPLE:
-- Handlers.add("query-data",
--     Handlers.utils.hasMatchingTag("Action", "QueryData"),
--     function(msg)
--         local response = DataProcessTemplate.handleMessage(msg, ao.id, myQueryHandler)
--         ao.send({
--             Target = msg.From,
--             Action = response.Action,
--             Data = response.Data,
--             Error = response.Error,
--             ProcessId = response.ProcessId,
--             Timestamp = response.Timestamp
--         })
--     end
-- )

local DataProcessTemplate = {}

-- Rate limiting configuration
local RATE_LIMIT_MAX = 100 -- queries per minute per address
local rateLimitCounters = {}

-- Performance monitoring
local performanceStartTime = nil

-- Input validation framework
function DataProcessTemplate.validateInput(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    
    if not message.Action or type(message.Action) ~= "string" then
        return false, "Action field is required and must be a string"
    end
    
    if not message.Data or type(message.Data) ~= "table" then
        return false, "Data field is required and must be a table"
    end
    
    if not message.Timestamp or type(message.Timestamp) ~= "number" then
        return false, "Timestamp field is required and must be a number"
    end
    
    return true, nil
end

-- Rate limiting implementation
function DataProcessTemplate.checkRateLimit(address)
    local currentTime = os.time()
    local currentMinute = math.floor(currentTime / 60)
    
    if not rateLimitCounters[address] then
        rateLimitCounters[address] = {
            minute = currentMinute,
            count = 0
        }
    end
    
    local counter = rateLimitCounters[address]
    
    -- Reset counter if we're in a new minute
    if counter.minute ~= currentMinute then
        counter.minute = currentMinute
        counter.count = 0
    end
    
    -- Check if rate limit exceeded
    if counter.count >= RATE_LIMIT_MAX then
        return false, "Rate limit exceeded: maximum " .. RATE_LIMIT_MAX .. " queries per minute"
    end
    
    -- Increment counter
    counter.count = counter.count + 1
    return true, nil
end

-- Performance monitoring hooks
function DataProcessTemplate.startPerformanceMonitoring()
    performanceStartTime = os.clock()
end

function DataProcessTemplate.endPerformanceMonitoring()
    if performanceStartTime then
        local responseTime = (os.clock() - performanceStartTime) * 1000 -- Convert to milliseconds
        performanceStartTime = nil
        return responseTime
    end
    return nil
end

-- Standard SaveState response protocol
function DataProcessTemplate.createSuccessResponse(data, processId)
    return {
        Action = "SaveState",
        Data = data,
        Timestamp = os.time(),
        ProcessId = processId or "data-process"
    }
end

-- Error response with SaveState protocol
function DataProcessTemplate.createErrorResponse(errorMessage, processId)
    return {
        Action = "SaveState",
        Error = errorMessage,
        ProcessId = processId or "data-process",
        Timestamp = os.time()
    }
end

-- Main message handler template
function DataProcessTemplate.handleMessage(message, processId, queryHandler)
    -- Start performance monitoring
    DataProcessTemplate.startPerformanceMonitoring()
    
    -- Input validation
    local isValid, validationError = DataProcessTemplate.validateInput(message)
    if not isValid then
        return DataProcessTemplate.createErrorResponse(validationError, processId)
    end
    
    -- Rate limiting check
    local senderAddress = message.From or "unknown"
    local rateLimitOk, rateLimitError = DataProcessTemplate.checkRateLimit(senderAddress)
    if not rateLimitOk then
        return DataProcessTemplate.createErrorResponse(rateLimitError, processId)
    end
    
    -- Process the query using provided handler
    local success, result = pcall(function()
        return queryHandler(message)
    end)
    
    -- Check performance requirement
    local responseTime = DataProcessTemplate.endPerformanceMonitoring()
    if responseTime and responseTime > 100 then
        -- Log performance warning but don't fail the request
        print("Warning: Query response time " .. responseTime .. "ms exceeds 100ms target")
    end
    
    if success then
        return DataProcessTemplate.createSuccessResponse(result, processId)
    else
        return DataProcessTemplate.createErrorResponse("Query processing failed: " .. tostring(result), processId)
    end
end

-- Query optimization patterns
DataProcessTemplate.QueryOptimizations = {
    -- Create indexed lookup tables for O(1) access
    createIndex = function(dataTable, keyField)
        local index = {}
        for i, item in ipairs(dataTable) do
            if item[keyField] then
                index[item[keyField]] = item
            end
        end
        return index
    end,
    
    -- Create multi-field composite index
    createCompositeIndex = function(dataTable, keyFields)
        local index = {}
        for i, item in ipairs(dataTable) do
            local key = {}
            for _, field in ipairs(keyFields) do
                table.insert(key, tostring(item[field] or ""))
            end
            local compositeKey = table.concat(key, "|")
            index[compositeKey] = item
        end
        return index
    end,
    
    -- Filter data by predicate with early termination
    filterData = function(dataTable, predicate, maxResults)
        local results = {}
        local count = 0
        maxResults = maxResults or math.huge
        
        for i, item in ipairs(dataTable) do
            if count >= maxResults then
                break
            end
            if predicate(item) then
                table.insert(results, item)
                count = count + 1
            end
        end
        return results
    end
}

return DataProcessTemplate