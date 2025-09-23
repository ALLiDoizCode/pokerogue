-- Test Mapper
-- Maps source files to their corresponding test files

local TestMapper = {}

-- Configuration
TestMapper.mappings = {
    -- Process files to unit tests
    ["^processes/(.+)%.lua$"] = "testing/unit/%1.test.lua",
    
    -- AO process files to tests
    ["^ao%-processes/([^/]+)%.lua$"] = "ao-processes/tests/unit/%1.test.lua",
    ["^ao%-processes/handlers/(.+)%.lua$"] = "ao-processes/tests/unit/handlers/%1.test.lua",
    ["^ao%-processes/game%-logic/(.+)%.lua$"] = "ao-processes/tests/unit/game-logic/%1.test.lua",
    
    -- Testing framework files
    ["^testing/aolite/(.+)%.lua$"] = "testing/unit/aolite/%1.test.lua",
    ["^testing/aos%-local/(.+)%.lua$"] = "testing/unit/aos-local/%1.test.lua",
    ["^testing/parity/(.+)%.lua$"] = "testing/unit/parity/%1.test.lua",
    
    -- Script files
    ["^scripts/(.+)%.lua$"] = "testing/unit/scripts/%1.test.lua",
    
    -- Development tools
    ["^development%-tools/(.+)%.lua$"] = "testing/unit/dev-tools/%1.test.lua"
}

-- Files/directories to exclude from testing requirements
TestMapper.excludes = {
    -- Test files themselves
    "%.test%.lua$",
    "%.spec%.lua$",
    "_test%.lua$",
    
    -- Data files
    "^ao%-processes/data/",
    "^data/",
    "^fixtures/",
    
    -- Templates
    "^templates/",
    "^scripts/generators/templates/",
    
    -- Documentation and examples
    "^docs/",
    "^examples/",
    
    -- Configuration files
    "%-config%.lua$",
    "^config/",
    
    -- Archive directory
    "^archive/"
}

-- Integration test mappings (for handlers and complex components)
TestMapper.integrationMappings = {
    ["^ao%-processes/handlers/(.+)%.lua$"] = "ao-processes/tests/integration/handlers/%1.test.lua",
    ["^processes/(.+)%-process%.lua$"] = "testing/integration/%1.test.lua"
}

-- Get test file path for a source file
function TestMapper.getTestFile(sourceFile)
    -- Check if file should be excluded
    for _, pattern in ipairs(TestMapper.excludes) do
        if sourceFile:match(pattern) then
            return nil, "excluded"
        end
    end
    
    -- Check mappings
    for pattern, replacement in pairs(TestMapper.mappings) do
        local testFile = sourceFile:gsub(pattern, replacement)
        if testFile ~= sourceFile then
            return testFile, "unit"
        end
    end
    
    -- Default mapping if no specific rule matches
    local testFile = sourceFile:gsub("%.lua$", ".test.lua")
    return testFile, "unit"
end

-- Get integration test file for a source file
function TestMapper.getIntegrationTestFile(sourceFile)
    for pattern, replacement in pairs(TestMapper.integrationMappings) do
        local testFile = sourceFile:gsub(pattern, replacement)
        if testFile ~= sourceFile then
            return testFile
        end
    end
    return nil
end

-- Get all test files for a source file
function TestMapper.getAllTestFiles(sourceFile)
    local tests = {}
    
    local unitTest, testType = TestMapper.getTestFile(sourceFile)
    if unitTest and testType ~= "excluded" then
        table.insert(tests, {
            file = unitTest,
            type = "unit"
        })
    end
    
    local integrationTest = TestMapper.getIntegrationTestFile(sourceFile)
    if integrationTest then
        table.insert(tests, {
            file = integrationTest,
            type = "integration"
        })
    end
    
    return tests
end

-- Get source file from test file (reverse mapping)
function TestMapper.getSourceFile(testFile)
    -- Remove test suffixes
    local sourceFile = testFile:gsub("%.test%.lua$", ".lua")
    sourceFile = sourceFile:gsub("%.spec%.lua$", ".lua")
    sourceFile = sourceFile:gsub("_test%.lua$", ".lua")
    
    -- Reverse directory mappings
    sourceFile = sourceFile:gsub("^testing/unit/", "")
    sourceFile = sourceFile:gsub("^testing/integration/", "")
    sourceFile = sourceFile:gsub("^ao%-processes/tests/unit/", "ao-processes/")
    sourceFile = sourceFile:gsub("^ao%-processes/tests/integration/", "ao-processes/")
    
    -- Special cases
    if sourceFile:match("^aolite/") then
        sourceFile = "testing/" .. sourceFile
    elseif sourceFile:match("^aos%-local/") then
        sourceFile = "testing/" .. sourceFile
    elseif sourceFile:match("^parity/") then
        sourceFile = "testing/" .. sourceFile
    elseif sourceFile:match("^scripts/") and not testFile:match("^scripts/") then
        -- Already has scripts prefix
    elseif sourceFile:match("^dev%-tools/") then
        sourceFile = sourceFile:gsub("^dev%-tools/", "development-tools/")
    end
    
    return sourceFile
end

-- Check if a file should have tests
function TestMapper.shouldHaveTests(file)
    for _, pattern in ipairs(TestMapper.excludes) do
        if file:match(pattern) then
            return false
        end
    end
    return file:match("%.lua$") ~= nil
end

-- Generate test file structure report
function TestMapper.generateReport(files)
    local report = {
        total = 0,
        excluded = 0,
        needsUnit = 0,
        needsIntegration = 0,
        hasUnit = 0,
        hasIntegration = 0,
        files = {}
    }
    
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            report.total = report.total + 1
            
            local fileInfo = {
                source = file,
                tests = TestMapper.getAllTestFiles(file)
            }
            
            if #fileInfo.tests == 0 then
                report.excluded = report.excluded + 1
                fileInfo.status = "excluded"
            else
                fileInfo.status = "needs_tests"
                for _, test in ipairs(fileInfo.tests) do
                    local testExists = io.open(test.file, "r")
                    if testExists then
                        testExists:close()
                        test.exists = true
                        if test.type == "unit" then
                            report.hasUnit = report.hasUnit + 1
                        else
                            report.hasIntegration = report.hasIntegration + 1
                        end
                    else
                        test.exists = false
                        if test.type == "unit" then
                            report.needsUnit = report.needsUnit + 1
                        else
                            report.needsIntegration = report.needsIntegration + 1
                        end
                    end
                end
            end
            
            table.insert(report.files, fileInfo)
        end
    end
    
    return report
end

-- Command-line interface
if arg and arg[0] and arg[0]:match("test%-mapper%.lua$") then
    local command = arg[1]
    local file = arg[2]
    
    if command == "map" and file then
        local tests = TestMapper.getAllTestFiles(file)
        if #tests == 0 then
            print("File excluded from testing: " .. file)
        else
            print("Test files for " .. file .. ":")
            for _, test in ipairs(tests) do
                print("  - " .. test.file .. " (" .. test.type .. ")")
            end
        end
    elseif command == "reverse" and file then
        local source = TestMapper.getSourceFile(file)
        print("Source file: " .. source)
    elseif command == "check" and file then
        if TestMapper.shouldHaveTests(file) then
            print("File requires tests: " .. file)
            os.exit(0)
        else
            print("File excluded from tests: " .. file)
            os.exit(1)
        end
    else
        print("Usage:")
        print("  lua test-mapper.lua map <file>      - Get test files for source")
        print("  lua test-mapper.lua reverse <file>  - Get source file from test")
        print("  lua test-mapper.lua check <file>    - Check if file needs tests")
    end
end

return TestMapper