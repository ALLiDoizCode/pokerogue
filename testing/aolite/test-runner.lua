#!/usr/bin/env lua

--[[
Test Runner for AO Process Testing Framework
Provides test discovery, execution, and reporting capabilities
Version: 1.0.0
]]

local TestRunner = {}

-- Configuration
local Config = {
    testPattern = "%.test%.lua$",
    testDirectories = {"testing/unit"},
    tapOutput = true,
    parallel = false,
    verbose = false,
    timeout = 30000, -- 30 seconds per test file
    coverage = false
}

-- Test execution state
local TestState = {
    totalFiles = 0,
    passedFiles = 0,
    failedFiles = 0,
    totalTests = 0,
    passedTests = 0,
    failedTests = 0,
    skippedTests = 0,
    startTime = 0,
    results = {}
}

-- File system utilities (simplified for testing)
local function scanDirectory(dir, pattern)
    pattern = pattern or ".*"
    local files = {}
    
    -- Note: In a real implementation, this would scan the filesystem
    -- For now, we'll return known test files
    local knownTests = {
        "testing/unit/framework/framework.test.lua",
        "testing/unit/message-passing.test.lua"
    }
    
    for _, file in ipairs(knownTests) do
        if string.find(file, pattern) and string.find(file, dir) then
            table.insert(files, file)
        end
    end
    
    return files
end

-- Test discovery
function TestRunner.discoverTests(directories, pattern)
    directories = directories or Config.testDirectories
    pattern = pattern or Config.testPattern
    
    local testFiles = {}
    
    for _, dir in ipairs(directories) do
        local files = scanDirectory(dir, pattern)
        for _, file in ipairs(files) do
            table.insert(testFiles, file)
        end
    end
    
    return testFiles
end

-- Execute single test file
function TestRunner.executeTestFile(filePath)
    local result = {
        file = filePath,
        success = false,
        tests = 0,
        passed = 0,
        failed = 0,
        skipped = 0,
        duration = 0,
        error = nil,
        output = {}
    }
    
    local startTime = os.clock()
    
    -- Load and execute test file
    local success, testModule = pcall(function()
        return loadfile(filePath)()
    end)
    
    if not success then
        result.error = testModule
        result.duration = (os.clock() - startTime) * 1000
        return result
    end
    
    -- Execute test suite
    if testModule and type(testModule) == "table" then
        -- Look for common test runner patterns
        local runners = {"runAllTests", "runTests", "run"}
        
        for _, runnerName in ipairs(runners) do
            if testModule[runnerName] and type(testModule[runnerName]) == "function" then
                local runSuccess, runResult = pcall(testModule[runnerName])
                result.success = runSuccess and runResult
                break
            end
        end
    end
    
    result.duration = (os.clock() - startTime) * 1000
    return result
end

-- Execute test suite
function TestRunner.run(options)
    options = options or {}
    
    -- Update config with options
    for key, value in pairs(options) do
        if Config[key] ~= nil then
            Config[key] = value
        end
    end
    
    TestState.startTime = os.clock()
    
    if Config.tapOutput then
        print("TAP version 13")
        print("# AO Process Test Runner v1.0.0")
    end
    
    -- Discover tests
    local testFiles = TestRunner.discoverTests()
    TestState.totalFiles = #testFiles
    
    if #testFiles == 0 then
        if Config.tapOutput then
            print("1..0")
            print("# No test files found")
        else
            print("No test files found")
        end
        return true
    end
    
    if Config.verbose then
        print("# Found " .. #testFiles .. " test files")
    end
    
    -- Execute tests
    for i, testFile in ipairs(testFiles) do
        if Config.verbose then
            print("# Running " .. testFile)
        end
        
        local result = TestRunner.executeTestFile(testFile)
        table.insert(TestState.results, result)
        
        if result.success then
            TestState.passedFiles = TestState.passedFiles + 1
            if Config.tapOutput then
                print(string.format("ok %d - %s", i, testFile))
            end
        else
            TestState.failedFiles = TestState.failedFiles + 1
            if Config.tapOutput then
                print(string.format("not ok %d - %s", i, testFile))
                if result.error then
                    print("  ---")
                    print("  error: " .. tostring(result.error))
                    print("  ...")
                end
            end
        end
        
        if Config.verbose then
            print(string.format("# Completed %s (%.2fms)", testFile, result.duration))
        end
    end
    
    -- Generate summary
    local totalTime = (os.clock() - TestState.startTime) * 1000
    
    if Config.tapOutput then
        print(string.format("1..%d", TestState.totalFiles))
        print(string.format("# Test files: %d, Passed: %d, Failed: %d", 
            TestState.totalFiles, TestState.passedFiles, TestState.failedFiles))
        print(string.format("# Duration: %.2fms", totalTime))
    else
        TestRunner.printSummary()
    end
    
    return TestState.failedFiles == 0
end

-- Print detailed summary
function TestRunner.printSummary()
    local totalTime = (os.clock() - TestState.startTime) * 1000
    
    print("\n" .. string.rep("=", 60))
    print("AO Process Test Suite Results")
    print(string.rep("=", 60))
    
    print(string.format("Test Files: %d", TestState.totalFiles))
    print(string.format("Passed: %d (%.1f%%)", 
        TestState.passedFiles, 
        (TestState.passedFiles / math.max(TestState.totalFiles, 1)) * 100))
    print(string.format("Failed: %d (%.1f%%)", 
        TestState.failedFiles,
        (TestState.failedFiles / math.max(TestState.totalFiles, 1)) * 100))
    print(string.format("Total Time: %.2fms", totalTime))
    
    if #TestState.results > 0 then
        print("\nFile Results:")
        for _, result in ipairs(TestState.results) do
            local status = result.success and "PASS" or "FAIL"
            print(string.format("  %s - %s (%.2fms)", status, result.file, result.duration))
            if not result.success and result.error then
                print(string.format("    Error: %s", tostring(result.error)))
            end
        end
    end
    
    if TestState.failedFiles == 0 then
        print("\n🎉 All tests passed!")
    else
        print("\n💥 Some tests failed!")
    end
end

-- Filter tests by pattern
function TestRunner.filter(pattern)
    return function(filePath)
        return string.find(filePath, pattern) ~= nil
    end
end

-- Run specific test file
function TestRunner.runFile(filePath, options)
    options = options or {}
    Config.verbose = options.verbose or false
    Config.tapOutput = options.tap or false
    
    local result = TestRunner.executeTestFile(filePath)
    
    if Config.verbose then
        print(string.format("File: %s", result.file))
        print(string.format("Success: %s", result.success and "true" or "false"))
        print(string.format("Duration: %.2fms", result.duration))
        if result.error then
            print(string.format("Error: %s", result.error))
        end
    end
    
    return result.success
end

-- Configuration helpers
function TestRunner.setConfig(key, value)
    if Config[key] ~= nil then
        Config[key] = value
        return true
    end
    return false
end

function TestRunner.getConfig()
    return Config
end

-- Test statistics
function TestRunner.getStats()
    return {
        files = {
            total = TestState.totalFiles,
            passed = TestState.passedFiles,
            failed = TestState.failedFiles
        },
        duration = TestState.startTime > 0 and ((os.clock() - TestState.startTime) * 1000) or 0,
        results = TestState.results
    }
end

-- Reset test state
function TestRunner.reset()
    TestState.totalFiles = 0
    TestState.passedFiles = 0 
    TestState.failedFiles = 0
    TestState.totalTests = 0
    TestState.passedTests = 0
    TestState.failedTests = 0
    TestState.skippedTests = 0
    TestState.startTime = 0
    TestState.results = {}
end

-- Watch mode (simplified)
function TestRunner.watch(directories, callback)
    directories = directories or Config.testDirectories
    callback = callback or function() TestRunner.run() end
    
    print("Watch mode not implemented (would watch " .. table.concat(directories, ", ") .. ")")
    callback()
end

return TestRunner