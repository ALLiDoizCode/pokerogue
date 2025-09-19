-- Unit tests for Data Process Template
-- Test framework: aolite

local DataProcessTemplate = require("processes.templates.data-process-template")

-- Test data
local testMessage = {
    Action = "GetTestData",
    Data = { id = "test123" },
    Timestamp = os.time()
}

local invalidMessages = {
    { msg = nil, desc = "nil message" },
    { msg = "string", desc = "string instead of table" },
    { msg = { Data = {}, Timestamp = os.time() }, desc = "missing Action" },
    { msg = { Action = "Test", Timestamp = os.time() }, desc = "missing Data" },
    { msg = { Action = "Test", Data = {} }, desc = "missing Timestamp" },
    { msg = { Action = 123, Data = {}, Timestamp = os.time() }, desc = "non-string Action" },
    { msg = { Action = "Test", Data = "string", Timestamp = os.time() }, desc = "non-table Data" },
    { msg = { Action = "Test", Data = {}, Timestamp = "string" }, desc = "non-number Timestamp" }
}

-- Test validateInput function
function testValidateInput()
    print("Testing validateInput...")
    
    -- Test valid message
    local isValid, error = DataProcessTemplate.validateInput(testMessage)
    assert(isValid == true, "Valid message should pass validation")
    assert(error == nil, "Valid message should not return error")
    
    -- Test invalid messages
    for _, testCase in ipairs(invalidMessages) do
        local isValid, error = DataProcessTemplate.validateInput(testCase.msg)
        assert(isValid == false, "Invalid message should fail validation: " .. testCase.desc)
        assert(error ~= nil, "Invalid message should return error: " .. testCase.desc)
    end
    
    print("✓ validateInput tests passed")
end

-- Test rate limiting functionality
function testRateLimit()
    print("Testing rate limiting...")
    
    local testAddress = "test-address-123"
    
    -- Test normal operation
    for i = 1, 50 do
        local ok, error = DataProcessTemplate.checkRateLimit(testAddress)
        assert(ok == true, "Rate limit should allow first 50 requests")
        assert(error == nil, "Should not return error for allowed requests")
    end
    
    -- Test approaching limit
    for i = 51, 100 do
        local ok, error = DataProcessTemplate.checkRateLimit(testAddress)
        assert(ok == true, "Rate limit should allow up to 100 requests")
    end
    
    -- Test exceeding limit
    local ok, error = DataProcessTemplate.checkRateLimit(testAddress)
    assert(ok == false, "Rate limit should block 101st request")
    assert(error ~= nil, "Should return error when rate limit exceeded")
    assert(string.find(error, "Rate limit exceeded"), "Error should mention rate limit")
    
    print("✓ Rate limit tests passed")
end

-- Test performance monitoring
function testPerformanceMonitoring()
    print("Testing performance monitoring...")
    
    -- Test without starting monitoring
    local responseTime = DataProcessTemplate.endPerformanceMonitoring()
    assert(responseTime == nil, "Should return nil when monitoring not started")
    
    -- Test with monitoring
    DataProcessTemplate.startPerformanceMonitoring()
    -- Simulate some work
    local sum = 0
    for i = 1, 1000 do
        sum = sum + i
    end
    local responseTime = DataProcessTemplate.endPerformanceMonitoring()
    
    assert(type(responseTime) == "number", "Should return numeric response time")
    assert(responseTime >= 0, "Response time should be non-negative")
    
    print("✓ Performance monitoring tests passed")
end

-- Test response creation
function testResponseCreation()
    print("Testing response creation...")
    
    local testData = { species = "Pikachu", type = "Electric" }
    local processId = "test-process"
    
    -- Test success response
    local successResponse = DataProcessTemplate.createSuccessResponse(testData, processId)
    assert(successResponse.Action == "SaveState", "Success response should use SaveState action")
    assert(successResponse.Data == testData, "Success response should include provided data")
    assert(successResponse.ProcessId == processId, "Success response should include process ID")
    assert(type(successResponse.Timestamp) == "number", "Success response should include timestamp")
    
    -- Test error response
    local errorMessage = "Test error message"
    local errorResponse = DataProcessTemplate.createErrorResponse(errorMessage, processId)
    assert(errorResponse.Action == "SaveState", "Error response should use SaveState action")
    assert(errorResponse.Error == errorMessage, "Error response should include error message")
    assert(errorResponse.ProcessId == processId, "Error response should include process ID")
    assert(type(errorResponse.Timestamp) == "number", "Error response should include timestamp")
    
    print("✓ Response creation tests passed")
end

-- Test handleMessage function
function testHandleMessage()
    print("Testing handleMessage...")
    
    local processId = "test-data-process"
    
    -- Mock query handler that returns test data
    local function mockQueryHandler(message)
        return { result = "success", action = message.Action }
    end
    
    -- Test valid message handling
    local response = DataProcessTemplate.handleMessage(testMessage, processId, mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data ~= nil, "Should include data in response")
    assert(response.ProcessId == processId, "Should include correct process ID")
    
    -- Test invalid message handling
    local invalidResponse = DataProcessTemplate.handleMessage({}, processId, mockQueryHandler)
    assert(invalidResponse.Action == "SaveState", "Should return SaveState for invalid message")
    assert(invalidResponse.Error ~= nil, "Should include error for invalid message")
    
    -- Test query handler error
    local function errorQueryHandler(message)
        error("Test query error")
    end
    
    local errorResponse = DataProcessTemplate.handleMessage(testMessage, processId, errorQueryHandler)
    assert(errorResponse.Action == "SaveState", "Should return SaveState for query error")
    assert(errorResponse.Error ~= nil, "Should include error for failed query")
    
    print("✓ handleMessage tests passed")
end

-- Test query optimization functions
function testQueryOptimizations()
    print("Testing query optimizations...")
    
    local testData = {
        { id = "001", name = "Bulbasaur", type = "Grass" },
        { id = "025", name = "Pikachu", type = "Electric" },
        { id = "150", name = "Mewtwo", type = "Psychic" }
    }
    
    -- Test createIndex
    local index = DataProcessTemplate.QueryOptimizations.createIndex(testData, "id")
    assert(index["001"].name == "Bulbasaur", "Index should provide O(1) lookup")
    assert(index["025"].name == "Pikachu", "Index should work for all items")
    assert(index["999"] == nil, "Index should return nil for non-existent keys")
    
    -- Test createCompositeIndex
    local compositeIndex = DataProcessTemplate.QueryOptimizations.createCompositeIndex(testData, {"type", "name"})
    assert(compositeIndex["Grass|Bulbasaur"] ~= nil, "Composite index should work")
    assert(compositeIndex["Electric|Pikachu"] ~= nil, "Composite index should handle multiple fields")
    
    -- Test filterData
    local electricPokemon = DataProcessTemplate.QueryOptimizations.filterData(testData, function(item)
        return item.type == "Electric"
    end)
    assert(#electricPokemon == 1, "Filter should return correct number of results")
    assert(electricPokemon[1].name == "Pikachu", "Filter should return correct items")
    
    -- Test filterData with maxResults
    local limitedResults = DataProcessTemplate.QueryOptimizations.filterData(testData, function(item)
        return true -- Accept all
    end, 2)
    assert(#limitedResults == 2, "Filter should respect maxResults parameter")
    
    print("✓ Query optimization tests passed")
end

-- Run all tests
function runAllTests()
    print("Running Data Process Template tests...")
    print("=====================================")
    
    testValidateInput()
    testRateLimit()
    testPerformanceMonitoring()
    testResponseCreation()
    testHandleMessage()
    testQueryOptimizations()
    
    print("=====================================")
    print("✅ All Data Process Template tests passed!")
end

-- Execute tests
runAllTests()