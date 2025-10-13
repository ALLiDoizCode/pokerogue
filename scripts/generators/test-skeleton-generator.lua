-- Test Skeleton Generator
-- Automatically generates test file skeletons for Lua source files

local TestGenerator = {}

-- Load dependencies
local function loadModule(name)
    local modulePath = "scripts/tdd/" .. name .. ".lua"
    local file = io.open(modulePath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local func = load(content)
        if func then
            return func()
        end
    end
    return nil
end

local TestMapper = loadModule("test-mapper")

-- Configuration
TestGenerator.config = {
    templateDir = "scripts/generators/templates/",
    outputMode = "create", -- create, overwrite, merge
    includeEdgeCases = true,
    includeTodos = true,
    aaa_pattern = true, -- Arrange, Act, Assert
    verbose = false
}

-- Template types
TestGenerator.templates = {
    unit = "unit-test.template.lua",
    integration = "integration-test.template.lua",
    handler = "handler-test.template.lua"
}

-- Function extraction patterns
TestGenerator.patterns = {
    functions = {
        "function%s+([%w_%.]+)%s*%(([^)]*)%)",
        "local%s+function%s+([%w_]+)%s*%(([^)]*)%)"
    },
    methods = {
        "([%w_]+)%.([%w_]+)%s*=%s*function%s*%(([^)]*)%)",
        "([%w_]+):([%w_]+)%s*=%s*function%s*%(([^)]*)%)"
    },
    handlers = {
        "Handlers%.add%s*%(%s*[\"']([%w%-_]+)[\"']%s*,",
        "Handlers%.add%s*%(%s*[\"']([%w%-_]+)[\"']%s*,%s*(.-)%s*,"
    },
    variables = {
        "local%s+([%w_]+)%s*=",
        "([%w_]+)%s*=%s*%{",
        "([%w_]+)%s*=%s*[\"'%d]"
    }
}

-- Load template file
function TestGenerator.loadTemplate(templateName)
    local templatePath = TestGenerator.config.templateDir .. templateName
    local file = io.open(templatePath, "r")
    if not file then
        return nil, "Template not found: " .. templatePath
    end
    
    local content = file:read("*all")
    file:close()
    return content
end

-- Extract functions from source file
function TestGenerator.extractFunctions(sourceFile)
    local file = io.open(sourceFile, "r")
    if not file then
        return {}, "Cannot read source file: " .. sourceFile
    end
    
    local content = file:read("*all")
    file:close()
    
    local functions = {}
    
    -- Extract regular functions
    for _, pattern in ipairs(TestGenerator.patterns.functions) do
        for name, params in content:gmatch(pattern) do
            table.insert(functions, {
                name = name,
                type = "function",
                params = params,
                line = TestGenerator.findLineNumber(content, name)
            })
        end
    end
    
    -- Extract methods
    for _, pattern in ipairs(TestGenerator.patterns.methods) do
        for tableName, methodName, params in content:gmatch(pattern) do
            local fullName = tableName .. "." .. methodName
            table.insert(functions, {
                name = fullName,
                type = "method",
                params = params,
                tableName = tableName,
                methodName = methodName,
                line = TestGenerator.findLineNumber(content, fullName)
            })
        end
    end
    
    -- Extract handlers (AO specific)
    for _, pattern in ipairs(TestGenerator.patterns.handlers) do
        for handlerName in content:gmatch(pattern) do
            table.insert(functions, {
                name = handlerName,
                type = "handler",
                params = "msg",
                line = TestGenerator.findLineNumber(content, handlerName)
            })
        end
    end
    
    return functions
end

-- Find line number of a function in content
function TestGenerator.findLineNumber(content, functionName)
    local lineNumber = 1
    for line in content:gmatch("[^\r\n]*") do
        if line:match(functionName) then
            return lineNumber
        end
        lineNumber = lineNumber + 1
    end
    return 1
end

-- Generate test cases for a function
function TestGenerator.generateTestCases(func)
    local tests = {}
    
    -- Basic test case
    table.insert(tests, {
        name = "should_work_with_valid_input",
        description = "Tests " .. func.name .. " with valid input parameters",
        type = "positive"
    })
    
    if TestGenerator.config.includeEdgeCases then
        -- Edge cases based on function type
        if func.type == "handler" then
            table.insert(tests, {
                name = "should_handle_missing_data",
                description = "Tests " .. func.name .. " handler with missing data in message",
                type = "edge"
            })
            table.insert(tests, {
                name = "should_handle_invalid_message_format",
                description = "Tests " .. func.name .. " handler with invalid message format",
                type = "negative"
            })
        else
            table.insert(tests, {
                name = "should_handle_nil_input",
                description = "Tests " .. func.name .. " with nil input",
                type = "edge"
            })
            table.insert(tests, {
                name = "should_handle_empty_input",
                description = "Tests " .. func.name .. " with empty input",
                type = "edge"
            })
        end
        
        -- Parameter-specific edge cases
        if func.params:match("number") or func.params:match("int") then
            table.insert(tests, {
                name = "should_handle_zero_value",
                description = "Tests " .. func.name .. " with zero value",
                type = "edge"
            })
            table.insert(tests, {
                name = "should_handle_negative_value",
                description = "Tests " .. func.name .. " with negative value",
                type = "edge"
            })
        end
        
        if func.params:match("string") then
            table.insert(tests, {
                name = "should_handle_empty_string",
                description = "Tests " .. func.name .. " with empty string",
                type = "edge"
            })
        end
        
        if func.params:match("table") then
            table.insert(tests, {
                name = "should_handle_empty_table",
                description = "Tests " .. func.name .. " with empty table",
                type = "edge"
            })
        end
    end
    
    return tests
end

-- Generate test file content
function TestGenerator.generateTestFile(sourceFile, testFile, functions)
    local templateName = TestGenerator.determineTemplateType(sourceFile, functions)
    local template, err = TestGenerator.loadTemplate(templateName)
    if not template then
        return nil, err
    end
    
    -- Template variables
    local variables = {
        SOURCE_FILE = sourceFile,
        TEST_FILE = testFile,
        MODULE_NAME = TestGenerator.getModuleName(sourceFile),
        TIMESTAMP = os.date("%Y-%m-%d %H:%M:%S"),
        FUNCTIONS = functions,
        TESTS = {}
    }
    
    -- Generate test cases for each function
    for _, func in ipairs(functions) do
        local testCases = TestGenerator.generateTestCases(func)
        table.insert(variables.TESTS, {
            function_info = func,
            test_cases = testCases
        })
    end
    
    -- Replace template variables
    local content = TestGenerator.replaceTemplateVariables(template, variables)
    return content
end

-- Determine template type based on source file
function TestGenerator.determineTemplateType(sourceFile, functions)
    -- Check if it's a handler file
    for _, func in ipairs(functions) do
        if func.type == "handler" then
            return TestGenerator.templates.handler
        end
    end
    
    -- Check if it's an integration test candidate
    if sourceFile:match("handler") or sourceFile:match("integration") or sourceFile:match("process") then
        return TestGenerator.templates.integration
    end
    
    return TestGenerator.templates.unit
end

-- Get module name from source file
function TestGenerator.getModuleName(sourceFile)
    local name = sourceFile:match("([^/]+)%.lua$") or sourceFile
    return name:gsub("%-", "_"):gsub("%.", "_")
end

-- Replace template variables with actual values
function TestGenerator.replaceTemplateVariables(template, vars)
    local content = template
    
    -- Simple variable replacement
    content = content:gsub("{{SOURCE_FILE}}", vars.SOURCE_FILE)
    content = content:gsub("{{TEST_FILE}}", vars.TEST_FILE)
    content = content:gsub("{{MODULE_NAME}}", vars.MODULE_NAME)
    content = content:gsub("{{TIMESTAMP}}", vars.TIMESTAMP)
    
    -- Generate function tests
    local testBlocks = {}
    for _, testGroup in ipairs(vars.TESTS) do
        local func = testGroup.function_info
        local funcTests = {}
        
        for _, testCase in ipairs(testGroup.test_cases) do
            local testBlock = TestGenerator.generateTestBlock(func, testCase)
            table.insert(funcTests, testBlock)
        end
        
        local funcBlock = string.format([[
describe("%s", function()
%s
end)]], func.name, table.concat(funcTests, "\n\n"))
        
        table.insert(testBlocks, funcBlock)
    end
    
    content = content:gsub("{{FUNCTION_TESTS}}", table.concat(testBlocks, "\n\n"))
    
    return content
end

-- Generate individual test block
function TestGenerator.generateTestBlock(func, testCase)
    local template = [[
    it("%s", function()
        -- Arrange
        %s
        
        -- Act
        %s
        
        -- Assert
        %s
    end)]]
    
    local arrange, act, assert = TestGenerator.generateTestContent(func, testCase)
    
    return string.format(template, testCase.description, arrange, act, assert)
end

-- Generate test content (Arrange, Act, Assert)
function TestGenerator.generateTestContent(func, testCase)
    local arrange, act, assert
    
    if func.type == "handler" then
        -- Handler test content
        if testCase.type == "positive" then
            arrange = [[local testMsg = {
            From = "test_sender",
            Action = "]] .. func.name .. [[",
            Data = json.encode({test = "data"})
        }]]
            act = "local result = " .. func.name .. "(testMsg)"
            assert = [[assert.is_not_nil(result)
        assert.equals("success", result.status)]]
        elseif testCase.type == "edge" then
            arrange = "local testMsg = {From = \"test_sender\"}"
            act = "local result = pcall(" .. func.name .. ", testMsg)"
            assert = "assert.is_true(result) -- Should handle gracefully"
        else
            arrange = "local invalidMsg = nil"
            act = "local success, result = pcall(" .. func.name .. ", invalidMsg)"
            assert = "assert.is_false(success) -- Should fail with invalid input"
        end
    else
        -- Regular function test content
        if testCase.type == "positive" then
            arrange = "local input = {} -- TODO: Add valid test input"
            act = "local result = " .. func.name .. "(input)"
            assert = "assert.is_not_nil(result) -- TODO: Add specific assertions"
        elseif testCase.type == "edge" then
            if testCase.name:match("nil") then
                arrange = "local input = nil"
            elseif testCase.name:match("empty") then
                arrange = "local input = {}"
            elseif testCase.name:match("zero") then
                arrange = "local input = 0"
            else
                arrange = "local input = {} -- TODO: Add edge case input"
            end
            act = "local result = " .. func.name .. "(input)"
            assert = "-- TODO: Add edge case assertions"
        else
            arrange = "local invalidInput = {} -- TODO: Add invalid input"
            act = "local success, result = pcall(" .. func.name .. ", invalidInput)"
            assert = "assert.is_false(success) -- Should reject invalid input"
        end
    end
    
    if TestGenerator.config.includeTodos then
        if not assert:match("TODO") then
            assert = assert .. "\n        -- TODO: Add more specific assertions"
        end
    end
    
    return arrange, act, assert
end

-- Create test file
function TestGenerator.createTestFile(sourceFile, outputPath, functions)
    local content, err = TestGenerator.generateTestFile(sourceFile, outputPath, functions)
    if not content then
        return false, err
    end
    
    -- Check if file exists and handle based on mode
    if io.open(outputPath, "r") then
        if TestGenerator.config.outputMode == "create" then
            return false, "Test file already exists: " .. outputPath
        elseif TestGenerator.config.outputMode == "merge" then
            -- TODO: Implement merge logic
            return false, "Merge mode not yet implemented"
        end
    end
    
    -- Ensure output directory exists
    local dir = outputPath:match("(.+)/[^/]+$")
    if dir then
        os.execute("mkdir -p " .. dir)
    end
    
    -- Write test file
    local file = io.open(outputPath, "w")
    if not file then
        return false, "Cannot write to: " .. outputPath
    end
    
    file:write(content)
    file:close()
    
    if TestGenerator.config.verbose then
        print("Generated test file: " .. outputPath)
    end
    
    return true
end

-- Generate tests for a source file
function TestGenerator.generateTests(sourceFile)
    -- Extract functions from source
    local functions, err = TestGenerator.extractFunctions(sourceFile)
    if err then
        return false, err
    end
    
    if #functions == 0 then
        return false, "No functions found in: " .. sourceFile
    end
    
    -- Determine test file paths
    local testFiles = {}
    if TestMapper then
        testFiles = TestMapper.getAllTestFiles(sourceFile)
    end
    
    if #testFiles == 0 then
        -- Fallback to simple mapping
        local testFile = sourceFile:gsub("%.lua$", ".test.lua")
        table.insert(testFiles, {file = testFile, type = "unit"})
    end
    
    local results = {}
    for _, testInfo in ipairs(testFiles) do
        local success, err = TestGenerator.createTestFile(sourceFile, testInfo.file, functions)
        table.insert(results, {
            testFile = testInfo.file,
            success = success,
            error = err,
            functionCount = #functions
        })
    end
    
    return results
end

-- Generate tests for multiple files
function TestGenerator.generateTestsForFiles(sourceFiles)
    local results = {
        total = 0,
        generated = 0,
        failed = 0,
        files = {}
    }
    
    for _, sourceFile in ipairs(sourceFiles) do
        results.total = results.total + 1
        local fileResults = TestGenerator.generateTests(sourceFile)
        
        if type(fileResults) == "table" then
            local success = false
            for _, result in ipairs(fileResults) do
                if result.success then
                    success = true
                    break
                end
            end
            
            if success then
                results.generated = results.generated + 1
            else
                results.failed = results.failed + 1
            end
            
            table.insert(results.files, {
                source = sourceFile,
                results = fileResults
            })
        else
            results.failed = results.failed + 1
            table.insert(results.files, {
                source = sourceFile,
                error = fileResults
            })
        end
    end
    
    return results
end

-- Command-line interface
if arg and arg[0] and arg[0]:match("test%-skeleton%-generator%.lua$") then
    local command = arg[1]
    
    if command == "generate" then
        local sourceFile = arg[2]
        if not sourceFile then
            print("Usage: lua test-skeleton-generator.lua generate <source-file>")
            os.exit(1)
        end
        
        local results = TestGenerator.generateTests(sourceFile)
        if type(results) == "table" then
            for _, result in ipairs(results) do
                if result.success then
                    print("✓ Generated: " .. result.testFile .. " (" .. result.functionCount .. " functions)")
                else
                    print("✗ Failed: " .. result.testFile .. " - " .. (result.error or "Unknown error"))
                end
            end
        else
            print("✗ Error: " .. results)
            os.exit(1)
        end
    elseif command == "extract" then
        local sourceFile = arg[2]
        if not sourceFile then
            print("Usage: lua test-skeleton-generator.lua extract <source-file>")
            os.exit(1)
        end
        
        local functions = TestGenerator.extractFunctions(sourceFile)
        print("Functions found in " .. sourceFile .. ":")
        for _, func in ipairs(functions) do
            print("  - " .. func.name .. " (" .. func.type .. ") at line " .. func.line)
        end
    elseif command == "batch" then
        local pattern = arg[2] or "**/*.lua"
        print("Batch generation not yet implemented for pattern: " .. pattern)
    else
        print("Usage:")
        print("  lua test-skeleton-generator.lua generate <file>  - Generate test for single file")
        print("  lua test-skeleton-generator.lua extract <file>   - Extract functions from file")
        print("  lua test-skeleton-generator.lua batch [pattern]  - Generate tests for multiple files")
    end
end

return TestGenerator