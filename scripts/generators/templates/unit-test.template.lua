-- Unit Test Template for {{MODULE_NAME}}
-- Generated on {{TIMESTAMP}}
-- Source: {{SOURCE_FILE}}

-- Test framework setup
local function setupTestEnvironment()
    -- Mock AO environment for testing
    if not ao then
        ao = {
            send = function(msg) 
                print("Mock ao.send:", json and json.encode(msg) or tostring(msg))
            end,
            id = "test_process_id"
        }
    end
    
    if not json then
        json = {
            encode = function(obj) return tostring(obj) end,
            decode = function(str) return {} end
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
            end,
            utils = {
                hasMatchingTag = function(tag, value)
                    return function(msg)
                        return msg[tag] == value
                    end
                end
            }
        }
    end
end

-- Setup test environment
setupTestEnvironment()

-- Load the module under test
-- Note: In actual implementation, this would load the source file
-- For now, we'll mock the functions that should be tested

-- Mock functions from {{SOURCE_FILE}}
-- TODO: Replace with actual module loading when running in test environment

-- Test utilities
local TestUtils = {}

function TestUtils.createMockMessage(action, data, from)
    return {
        Id = "test_msg_" .. math.random(1000000),
        From = from or "test_sender",
        Target = ao.id,
        Action = action,
        Data = data and json.encode(data) or "{}",
        Timestamp = tostring(os.time())
    }
end

function TestUtils.assertValidResponse(response)
    assert(response, "Response should not be nil")
    assert(response.Target, "Response should have Target")
    assert(response.Action, "Response should have Action")
end

function TestUtils.assertSuccessResponse(response)
    TestUtils.assertValidResponse(response)
    assert(response.Action == "Success" or not response.Error, 
           "Response should indicate success: " .. (response.Error or ""))
end

function TestUtils.assertErrorResponse(response, expectedError)
    TestUtils.assertValidResponse(response)
    assert(response.Action == "Error" or response.Error, 
           "Response should indicate error")
    if expectedError then
        assert(response.Error and response.Error:match(expectedError), 
               "Error should match expected pattern: " .. expectedError)
    end
end

-- Test Cases
{{FUNCTION_TESTS}}

-- Additional test utilities and edge cases

describe("Module Integration", function()
    it("should initialize without errors", function()
        -- Test that the module can be loaded/initialized
        -- TODO: Add module initialization tests
        assert.is_true(true) -- Placeholder
    end)
    
    it("should handle AO environment correctly", function()
        -- Test AO-specific functionality
        assert.is_not_nil(ao)
        assert.is_function(ao.send)
        assert.is_string(ao.id)
    end)
end)

-- Performance tests (if applicable)
describe("Performance", function()
    it("should execute within reasonable time limits", function()
        -- Test execution time for critical functions
        local startTime = os.clock()
        
        -- TODO: Add performance-critical function calls
        
        local endTime = os.clock()
        local executionTime = endTime - startTime
        
        -- Should complete within 1 second (adjust as needed)
        assert.is_true(executionTime < 1.0, 
                      string.format("Execution took %.3f seconds", executionTime))
    end)
end)

-- Memory tests (if applicable)
describe("Memory Usage", function()
    it("should not cause memory leaks", function()
        -- Test memory usage patterns
        -- TODO: Add memory usage validation
        assert.is_true(true) -- Placeholder
    end)
end)

print("✅ Unit tests for {{MODULE_NAME}} completed")