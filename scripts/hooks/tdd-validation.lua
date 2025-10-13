-- TDD Validation Logic
-- Provides validation functions for test-first development enforcement

local TDDValidator = {}

-- Configuration
TDDValidator.config = {
    testDirectories = {
        "testing/unit/",
        "testing/integration/",
        "ao-processes/tests/unit/",
        "ao-processes/tests/integration/"
    },
    excludePatterns = {
        "data/",
        "templates/",
        "fixtures/",
        "test",
        "spec"
    },
    testFilePatterns = {
        ".test.lua",
        ".spec.lua",
        "_test.lua"
    }
}

-- Check if a file should be excluded from TDD requirements
function TDDValidator.shouldExclude(filePath)
    for _, pattern in ipairs(TDDValidator.config.excludePatterns) do
        if filePath:match(pattern) then
            return true
        end
    end
    return false
end

-- Determine test file path for a given source file
function TDDValidator.getTestFilePath(sourceFile)
    -- Skip if should be excluded
    if TDDValidator.shouldExclude(sourceFile) then
        return nil
    end
    
    -- Handle different source locations
    local testFile
    if sourceFile:match("^processes/") then
        testFile = sourceFile:gsub("^processes/", "testing/unit/")
        testFile = testFile:gsub("%.lua$", ".test.lua")
    elseif sourceFile:match("^ao%-processes/") then
        -- Skip if already a test file
        if sourceFile:match("tests/") then
            return nil
        end
        testFile = sourceFile:gsub("^ao%-processes/", "ao-processes/tests/unit/")
        testFile = testFile:gsub("%.lua$", ".test.lua")
    else
        testFile = sourceFile:gsub("%.lua$", ".test.lua")
    end
    
    return testFile
end

-- Validate that a test file exists for the source file
function TDDValidator.validateTestExists(sourceFile)
    local testFile = TDDValidator.getTestFilePath(sourceFile)
    if not testFile then
        return true, "File excluded from TDD requirements"
    end
    
    local file = io.open(testFile, "r")
    if file then
        file:close()
        return true, testFile
    else
        return false, testFile
    end
end

-- Extract functions from a Lua source file
function TDDValidator.extractFunctions(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    local functions = {}
    
    -- Pattern for regular function definitions
    for funcName in content:gmatch("function%s+([%w_]+)%s*%(") do
        table.insert(functions, {name = funcName, type = "function"})
    end
    
    -- Pattern for local function definitions
    for funcName in content:gmatch("local%s+function%s+([%w_]+)%s*%(") do
        table.insert(functions, {name = funcName, type = "local_function"})
    end
    
    -- Pattern for table method definitions
    for tableName, methodName in content:gmatch("([%w_]+)%.([%w_]+)%s*=%s*function%s*%(") do
        table.insert(functions, {name = tableName .. "." .. methodName, type = "method"})
    end
    
    -- Pattern for colon method definitions
    for tableName, methodName in content:gmatch("([%w_]+):([%w_]+)%s*=%s*function%s*%(") do
        table.insert(functions, {name = tableName .. ":" .. methodName, type = "method"})
    end
    
    -- Pattern for handler definitions (AO specific)
    for handlerName in content:gmatch("Handlers%.add%s*%(%s*[\"']([%w%-_]+)[\"']") do
        table.insert(functions, {name = "Handler:" .. handlerName, type = "handler"})
    end
    
    return functions
end

-- Check if test file covers the required functions
function TDDValidator.validateTestCoverage(sourceFile, testFile)
    local sourceFunctions = TDDValidator.extractFunctions(sourceFile)
    if #sourceFunctions == 0 then
        return true, "No functions to test"
    end
    
    local file = io.open(testFile, "r")
    if not file then
        return false, "Test file not found"
    end
    
    local testContent = file:read("*all")
    file:close()
    
    local uncoveredFunctions = {}
    for _, func in ipairs(sourceFunctions) do
        -- Check if function is mentioned in test file
        -- Simple check - can be enhanced
        if not testContent:match(func.name) and 
           not testContent:match(func.name:gsub("%.", "_")) and
           not testContent:match(func.name:gsub(":", "_")) then
            table.insert(uncoveredFunctions, func.name)
        end
    end
    
    if #uncoveredFunctions > 0 then
        return false, "Uncovered functions: " .. table.concat(uncoveredFunctions, ", ")
    end
    
    return true, "All functions covered"
end

-- Generate test coverage report
function TDDValidator.generateCoverageReport(files)
    local report = {
        total = 0,
        tested = 0,
        missing = {},
        coverage = 0
    }
    
    for _, file in ipairs(files) do
        report.total = report.total + 1
        local exists, testFile = TDDValidator.validateTestExists(file)
        if exists then
            report.tested = report.tested + 1
        else
            table.insert(report.missing, {
                source = file,
                expectedTest = testFile
            })
        end
    end
    
    if report.total > 0 then
        report.coverage = (report.tested / report.total) * 100
    end
    
    return report
end

-- Export for command-line usage
if arg and arg[0] and arg[0]:match("tdd%-validation%.lua$") then
    -- Command-line mode
    local command = arg[1]
    local file = arg[2]
    
    if command == "validate" and file then
        local exists, testFile = TDDValidator.validateTestExists(file)
        if exists then
            print("✓ Test file exists: " .. testFile)
            os.exit(0)
        else
            print("✗ Missing test file: " .. testFile)
            os.exit(1)
        end
    elseif command == "extract" and file then
        local functions = TDDValidator.extractFunctions(file)
        print("Functions found in " .. file .. ":")
        for _, func in ipairs(functions) do
            print("  - " .. func.name .. " (" .. func.type .. ")")
        end
    elseif command == "coverage" and file then
        local testFile = TDDValidator.getTestFilePath(file)
        if testFile then
            local covered, message = TDDValidator.validateTestCoverage(file, testFile)
            print(message)
            os.exit(covered and 0 or 1)
        else
            print("File excluded from TDD requirements")
            os.exit(0)
        end
    else
        print("Usage:")
        print("  lua tdd-validation.lua validate <file>    - Check if test file exists")
        print("  lua tdd-validation.lua extract <file>     - Extract functions from file")
        print("  lua tdd-validation.lua coverage <file>    - Check test coverage")
    end
end

return TDDValidator