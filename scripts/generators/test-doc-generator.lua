-- Test Documentation Generator
-- Parses test files and generates comprehensive documentation

local TestDocGenerator = {}

-- Configuration
TestDocGenerator.config = {
    outputDir = "docs/testing/",
    formats = {"markdown", "html", "json"},
    includeSpecs = true,
    includeCoverage = true,
    includeMetrics = true,
    templateDir = "scripts/generators/templates/",
    verbose = false
}

-- Documentation data structure
TestDocGenerator.data = {
    suites = {},
    files = {},
    coverage = {},
    metrics = {
        totalTests = 0,
        totalSuites = 0,
        totalFiles = 0,
        passRate = 0,
        coverage = 0
    }
}

-- Test file parsing patterns
TestDocGenerator.patterns = {
    describe = "describe%s*%(%s*[\"']([^\"']+)[\"']%s*,%s*function%s*%(%s*%)",
    it = "it%s*%(%s*[\"']([^\"']+)[\"']%s*,%s*function%s*%(%s*%)",
    beforeEach = "beforeEach%s*%(%s*function%s*%(%s*%)",
    afterEach = "afterEach%s*%(%s*function%s*%(%s*%)",
    comments = "%-%-(.-)$",
    assertions = "assert%.([%w_]+)%s*%(([^)]*%s*%))",
    mocks = "mock%s*%(%s*[\"']([^\"']+)[\"']",
    fixtures = "fixture%s*%(%s*[\"']([^\"']+)[\"']"
}

-- Parse a test file and extract documentation
function TestDocGenerator.parseTestFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil, "Cannot read test file: " .. filePath
    end
    
    local content = file:read("*all")
    file:close()
    
    local testData = {
        file = filePath,
        suites = {},
        tests = {},
        metrics = {
            suiteCount = 0,
            testCount = 0,
            assertionCount = 0
        },
        metadata = {
            generated = TestDocGenerator.extractMetadata(content),
            source = TestDocGenerator.extractSourceFile(content),
            dependencies = TestDocGenerator.extractDependencies(content)
        }
    }
    
    -- Parse test suites (describe blocks)
    local currentSuite = nil
    local lineNumber = 0
    
    for line in content:gmatch("[^\r\n]*") do
        lineNumber = lineNumber + 1
        
        -- Match describe blocks
        local suiteName = line:match(TestDocGenerator.patterns.describe)
        if suiteName then
            currentSuite = {
                name = suiteName,
                description = TestDocGenerator.extractDescription(content, lineNumber),
                tests = {},
                line = lineNumber,
                setup = {},
                teardown = {}
            }
            table.insert(testData.suites, currentSuite)
            testData.metrics.suiteCount = testData.metrics.suiteCount + 1
        end
        
        -- Match test cases (it blocks)
        local testName = line:match(TestDocGenerator.patterns.it)
        if testName and currentSuite then
            local test = {
                name = testName,
                description = TestDocGenerator.extractTestDescription(content, lineNumber),
                assertions = TestDocGenerator.extractAssertions(content, lineNumber),
                line = lineNumber,
                type = TestDocGenerator.classifyTest(testName),
                complexity = TestDocGenerator.calculateComplexity(content, lineNumber)
            }
            table.insert(currentSuite.tests, test)
            table.insert(testData.tests, test)
            testData.metrics.testCount = testData.metrics.testCount + 1
            testData.metrics.assertionCount = testData.metrics.assertionCount + #test.assertions
        end
        
        -- Match setup/teardown
        if line:match(TestDocGenerator.patterns.beforeEach) and currentSuite then
            table.insert(currentSuite.setup, {line = lineNumber, type = "beforeEach"})
        end
        
        if line:match(TestDocGenerator.patterns.afterEach) and currentSuite then
            table.insert(currentSuite.teardown, {line = lineNumber, type = "afterEach"})
        end
    end
    
    return testData
end

-- Extract metadata from test file header
function TestDocGenerator.extractMetadata(content)
    local metadata = {}
    
    -- Look for metadata in comments at the top of the file
    local headerLines = {}
    for line in content:gmatch("[^\r\n]*") do
        if line:match("^%s*%-%-") then
            table.insert(headerLines, line)
        else
            break
        end
    end
    
    local headerText = table.concat(headerLines, "\n")
    
    -- Extract common metadata patterns
    metadata.generated = headerText:match("Generated on ([^\r\n]+)")
    metadata.source = headerText:match("Source: ([^\r\n]+)")
    metadata.template = headerText:match("Template for ([^\r\n]+)")
    metadata.framework = headerText:match("framework: ([^\r\n]+)")
    
    return metadata
end

-- Extract source file reference
function TestDocGenerator.extractSourceFile(content)
    -- Look for source file references
    local patterns = {
        "Source: ([^\r\n]+)",
        "Testing: ([^\r\n]+)",
        "Module: ([^\r\n]+)",
        "load%s*%(%s*[\"']([^\"']+)[\"']"
    }
    
    for _, pattern in ipairs(patterns) do
        local match = content:match(pattern)
        if match then
            return match
        end
    end
    
    return nil
end

-- Extract dependencies and imports
function TestDocGenerator.extractDependencies(content)
    local dependencies = {}
    
    -- Look for require statements and module loads
    for dependency in content:gmatch("require%s*%(%s*[\"']([^\"']+)[\"']") do
        table.insert(dependencies, {name = dependency, type = "require"})
    end
    
    for dependency in content:gmatch("load%s*%(%s*[\"']([^\"']+)[\"']") do
        table.insert(dependencies, {name = dependency, type = "load"})
    end
    
    return dependencies
end

-- Extract description from comments above a line
function TestDocGenerator.extractDescription(content, lineNumber)
    local lines = {}
    for line in content:gmatch("[^\r\n]*") do
        table.insert(lines, line)
    end
    
    local description = {}
    for i = lineNumber - 1, 1, -1 do
        local line = lines[i]
        if line and line:match("^%s*%-%-") then
            local comment = line:match("%-%-(.+)")
            if comment then
                table.insert(description, 1, comment:match("^%s*(.-)%s*$"))
            end
        else
            break
        end
    end
    
    return table.concat(description, " ")
end

-- Extract test description
function TestDocGenerator.extractTestDescription(content, lineNumber)
    local description = TestDocGenerator.extractDescription(content, lineNumber)
    if description == "" then
        -- Generate description from test name pattern
        local lines = {}
        for line in content:gmatch("[^\r\n]*") do
            table.insert(lines, line)
        end
        
        local testLine = lines[lineNumber]
        if testLine then
            local testName = testLine:match(TestDocGenerator.patterns.it)
            if testName then
                return TestDocGenerator.generateTestDescription(testName)
            end
        end
    end
    
    return description
end

-- Generate description from test name
function TestDocGenerator.generateTestDescription(testName)
    -- Convert test name patterns to readable descriptions
    local patterns = {
        ["should_(.+)"] = "Should %1",
        ["test_(.+)"] = "Tests %1",
        ["verify_(.+)"] = "Verifies %1",
        ["check_(.+)"] = "Checks %1",
        ["validate_(.+)"] = "Validates %1"
    }
    
    for pattern, replacement in pairs(patterns) do
        local match = testName:match(pattern)
        if match then
            return replacement:format(match:gsub("_", " "))
        end
    end
    
    return testName:gsub("_", " "):gsub("^%l", string.upper)
end

-- Extract assertions from test function
function TestDocGenerator.extractAssertions(content, startLine)
    local lines = {}
    for line in content:gmatch("[^\r\n]*") do
        table.insert(lines, line)
    end
    
    local assertions = {}
    local braceLevel = 0
    local inFunction = false
    
    for i = startLine, #lines do
        local line = lines[i]
        if not line then break end
        
        -- Track function boundaries
        if line:match("function%s*%(") then
            inFunction = true
        end
        
        -- Track brace levels to find function end
        local openBraces = select(2, line:gsub("{", ""))
        local closeBraces = select(2, line:gsub("}", ""))
        braceLevel = braceLevel + openBraces - closeBraces
        
        if inFunction then
            -- Extract assertions
            for assertType, assertArgs in line:gmatch(TestDocGenerator.patterns.assertions) do
                table.insert(assertions, {
                    type = assertType,
                    args = assertArgs,
                    line = i,
                    description = TestDocGenerator.describeAssertion(assertType, assertArgs)
                })
            end
        end
        
        -- End of function
        if inFunction and line:match("end%s*%)") then
            break
        end
    end
    
    return assertions
end

-- Describe assertion in human readable form
function TestDocGenerator.describeAssertion(assertType, args)
    local descriptions = {
        equals = "Verifies equality: " .. args,
        is_true = "Verifies condition is true",
        is_false = "Verifies condition is false",
        is_nil = "Verifies value is nil",
        is_not_nil = "Verifies value is not nil",
        has_error = "Verifies error is thrown",
        matches = "Verifies pattern match: " .. args,
        greater_than = "Verifies value is greater than: " .. args,
        less_than = "Verifies value is less than: " .. args
    }
    
    return descriptions[assertType] or ("Assertion: " .. assertType)
end

-- Classify test type
function TestDocGenerator.classifyTest(testName)
    local patterns = {
        [".*error.*"] = "error",
        [".*fail.*"] = "negative",
        [".*edge.*"] = "edge",
        [".*boundary.*"] = "boundary",
        [".*performance.*"] = "performance",
        [".*integration.*"] = "integration",
        [".*unit.*"] = "unit",
        ["should_work.*"] = "positive",
        ["should_handle.*"] = "defensive"
    }
    
    local lowercaseName = testName:lower()
    for pattern, testType in pairs(patterns) do
        if lowercaseName:match(pattern) then
            return testType
        end
    end
    
    return "functional"
end

-- Calculate test complexity
function TestDocGenerator.calculateComplexity(content, startLine)
    local lines = {}
    for line in content:gmatch("[^\r\n]*") do
        table.insert(lines, line)
    end
    
    local complexity = 0
    local braceLevel = 0
    
    for i = startLine, #lines do
        local line = lines[i]
        if not line then break end
        
        -- Count decision points
        complexity = complexity + select(2, line:gsub("if%s", ""))
        complexity = complexity + select(2, line:gsub("elseif%s", ""))
        complexity = complexity + select(2, line:gsub("while%s", ""))
        complexity = complexity + select(2, line:gsub("for%s", ""))
        complexity = complexity + select(2, line:gsub("and%s", ""))
        complexity = complexity + select(2, line:gsub("or%s", ""))
        
        -- Track function end
        if line:match("end%s*%)") then
            break
        end
    end
    
    return math.max(1, complexity)
end

-- Generate markdown documentation
function TestDocGenerator.generateMarkdown(testData)
    local md = {}
    
    -- Header
    table.insert(md, "# Test Documentation")
    table.insert(md, "")
    table.insert(md, string.format("**File:** `%s`", testData.file))
    
    if testData.metadata.source then
        table.insert(md, string.format("**Source:** `%s`", testData.metadata.source))
    end
    
    if testData.metadata.generated then
        table.insert(md, string.format("**Generated:** %s", testData.metadata.generated))
    end
    
    table.insert(md, "")
    
    -- Metrics
    table.insert(md, "## Metrics")
    table.insert(md, "")
    table.insert(md, string.format("- **Test Suites:** %d", testData.metrics.suiteCount))
    table.insert(md, string.format("- **Test Cases:** %d", testData.metrics.testCount))
    table.insert(md, string.format("- **Assertions:** %d", testData.metrics.assertionCount))
    table.insert(md, "")
    
    -- Dependencies
    if #testData.metadata.dependencies > 0 then
        table.insert(md, "## Dependencies")
        table.insert(md, "")
        for _, dep in ipairs(testData.metadata.dependencies) do
            table.insert(md, string.format("- `%s` (%s)", dep.name, dep.type))
        end
        table.insert(md, "")
    end
    
    -- Test Suites
    table.insert(md, "## Test Suites")
    table.insert(md, "")
    
    for _, suite in ipairs(testData.suites) do
        table.insert(md, string.format("### %s", suite.name))
        table.insert(md, "")
        
        if suite.description and suite.description ~= "" then
            table.insert(md, suite.description)
            table.insert(md, "")
        end
        
        -- Suite setup/teardown
        if #suite.setup > 0 or #suite.teardown > 0 then
            table.insert(md, "**Setup/Teardown:**")
            for _, setup in ipairs(suite.setup) do
                table.insert(md, string.format("- Setup: %s (line %d)", setup.type, setup.line))
            end
            for _, teardown in ipairs(suite.teardown) do
                table.insert(md, string.format("- Teardown: %s (line %d)", teardown.type, teardown.line))
            end
            table.insert(md, "")
        end
        
        -- Test cases
        if #suite.tests > 0 then
            table.insert(md, "#### Test Cases")
            table.insert(md, "")
            
            for _, test in ipairs(suite.tests) do
                table.insert(md, string.format("##### %s", test.name))
                table.insert(md, "")
                
                if test.description and test.description ~= "" then
                    table.insert(md, test.description)
                    table.insert(md, "")
                end
                
                table.insert(md, string.format("- **Type:** %s", test.type))
                table.insert(md, string.format("- **Complexity:** %d", test.complexity))
                table.insert(md, string.format("- **Line:** %d", test.line))
                
                if #test.assertions > 0 then
                    table.insert(md, "- **Assertions:**")
                    for _, assertion in ipairs(test.assertions) do
                        table.insert(md, string.format("  - %s", assertion.description))
                    end
                end
                
                table.insert(md, "")
            end
        end
    end
    
    return table.concat(md, "\n")
end

-- Generate HTML documentation
function TestDocGenerator.generateHTML(testData)
    local html = string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Documentation - %s</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { border-bottom: 1px solid #eee; padding-bottom: 20px; margin-bottom: 30px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: #f8f9fa; padding: 20px; border-radius: 6px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #007bff; }
        .metric-label { color: #6c757d; margin-top: 5px; }
        .suite { border: 1px solid #dee2e6; border-radius: 6px; margin-bottom: 20px; }
        .suite-header { background: #f8f9fa; padding: 15px; border-bottom: 1px solid #dee2e6; }
        .suite-title { margin: 0; color: #333; }
        .suite-content { padding: 15px; }
        .test { border-left: 3px solid #007bff; padding: 10px 15px; margin: 10px 0; background: #f8f9fa; }
        .test-title { font-weight: bold; margin-bottom: 5px; }
        .test-meta { font-size: 0.9em; color: #6c757d; }
        .assertions { margin-top: 10px; }
        .assertion { font-size: 0.85em; padding: 2px 0; }
        .type-positive { border-left-color: #28a745; }
        .type-negative { border-left-color: #dc3545; }
        .type-edge { border-left-color: #ffc107; }
        .type-performance { border-left-color: #17a2b8; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Test Documentation</h1>
            <p><strong>File:</strong> <code>%s</code></p>
            %s
        </div>

        <div class="metrics">
            <div class="metric">
                <div class="metric-value">%d</div>
                <div class="metric-label">Test Suites</div>
            </div>
            <div class="metric">
                <div class="metric-value">%d</div>
                <div class="metric-label">Test Cases</div>
            </div>
            <div class="metric">
                <div class="metric-value">%d</div>
                <div class="metric-label">Assertions</div>
            </div>
        </div>
]], 
        testData.file, 
        testData.file,
        testData.metadata.source and string.format("<p><strong>Source:</strong> <code>%s</code></p>", testData.metadata.source) or "",
        testData.metrics.suiteCount,
        testData.metrics.testCount,
        testData.metrics.assertionCount
    )
    
    -- Add test suites
    html = html .. "<h2>Test Suites</h2>\n"
    
    for _, suite in ipairs(testData.suites) do
        html = html .. string.format([[
        <div class="suite">
            <div class="suite-header">
                <h3 class="suite-title">%s</h3>
            </div>
            <div class="suite-content">
        ]], suite.name)
        
        if suite.description and suite.description ~= "" then
            html = html .. string.format("<p>%s</p>", suite.description)
        end
        
        -- Add tests
        for _, test in ipairs(suite.tests) do
            html = html .. string.format([[
                <div class="test type-%s">
                    <div class="test-title">%s</div>
                    <div class="test-meta">
                        Type: %s | Complexity: %d | Line: %d
                    </div>
            ]], test.type, test.name, test.type, test.complexity, test.line)
            
            if test.description and test.description ~= "" then
                html = html .. string.format("<p>%s</p>", test.description)
            end
            
            if #test.assertions > 0 then
                html = html .. "<div class=\"assertions\"><strong>Assertions:</strong>"
                for _, assertion in ipairs(test.assertions) do
                    html = html .. string.format("<div class=\"assertion\">• %s</div>", assertion.description)
                end
                html = html .. "</div>"
            end
            
            html = html .. "</div>"
        end
        
        html = html .. "</div></div>"
    end
    
    html = html .. "</div></body></html>"
    return html
end

-- Generate JSON documentation
function TestDocGenerator.generateJSON(testData)
    -- Simple JSON encoding
    local function encodeValue(val)
        if type(val) == "string" then
            return '"' .. val:gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return val and "true" or "false"
        elseif type(val) == "table" then
            if #val > 0 then
                -- Array
                local items = {}
                for _, v in ipairs(val) do
                    table.insert(items, encodeValue(v))
                end
                return "[" .. table.concat(items, ",") .. "]"
            else
                -- Object
                local items = {}
                for k, v in pairs(val) do
                    table.insert(items, '"' .. tostring(k) .. '":' .. encodeValue(v))
                end
                return "{" .. table.concat(items, ",") .. "}"
            end
        else
            return "null"
        end
    end
    
    return encodeValue(testData)
end

-- Process multiple test files
function TestDocGenerator.processFiles(filePaths)
    local allData = {
        files = {},
        summary = {
            totalFiles = 0,
            totalSuites = 0,
            totalTests = 0,
            totalAssertions = 0
        }
    }
    
    for _, filePath in ipairs(filePaths) do
        local testData, err = TestDocGenerator.parseTestFile(filePath)
        if testData then
            table.insert(allData.files, testData)
            allData.summary.totalFiles = allData.summary.totalFiles + 1
            allData.summary.totalSuites = allData.summary.totalSuites + testData.metrics.suiteCount
            allData.summary.totalTests = allData.summary.totalTests + testData.metrics.testCount
            allData.summary.totalAssertions = allData.summary.totalAssertions + testData.metrics.assertionCount
        else
            print("Error processing " .. filePath .. ": " .. err)
        end
    end
    
    return allData
end

-- Save documentation
function TestDocGenerator.saveDocumentation(data, format, outputPath)
    local content
    
    if format == "markdown" then
        content = TestDocGenerator.generateMarkdown(data)
    elseif format == "html" then
        content = TestDocGenerator.generateHTML(data)
    elseif format == "json" then
        content = TestDocGenerator.generateJSON(data)
    else
        return false, "Unsupported format: " .. format
    end
    
    -- Ensure output directory exists
    local dir = outputPath:match("(.+)/[^/]+$")
    if dir then
        os.execute("mkdir -p " .. dir)
    end
    
    local file = io.open(outputPath, "w")
    if not file then
        return false, "Cannot write to: " .. outputPath
    end
    
    file:write(content)
    file:close()
    
    if TestDocGenerator.config.verbose then
        print(string.format("%s documentation saved to: %s", format:upper(), outputPath))
    end
    
    return true
end

-- Command-line interface
if arg and arg[0] and arg[0]:match("test%-doc%-generator%.lua$") then
    local command = arg[1]
    local inputFile = arg[2]
    
    if command == "generate" and inputFile then
        local testData, err = TestDocGenerator.parseTestFile(inputFile)
        if testData then
            -- Generate all configured formats
            for _, format in ipairs(TestDocGenerator.config.formats) do
                local ext = format == "markdown" and "md" or format
                local outputFile = TestDocGenerator.config.outputDir .. 
                                 inputFile:match("([^/]+)%.") .. "-docs." .. ext
                
                local success, saveErr = TestDocGenerator.saveDocumentation(testData, format, outputFile)
                if success then
                    print("✓ Generated " .. format .. " documentation")
                else
                    print("✗ Failed to save " .. format .. ": " .. saveErr)
                end
            end
        else
            print("✗ Error: " .. err)
            os.exit(1)
        end
    elseif command == "batch" then
        local pattern = inputFile or "**/*.test.lua"
        print("Batch documentation generation not yet implemented for pattern: " .. pattern)
    else
        print("Usage:")
        print("  lua test-doc-generator.lua generate <test-file>  - Generate docs for single test file")
        print("  lua test-doc-generator.lua batch [pattern]       - Generate docs for multiple files")
    end
end

return TestDocGenerator