#!/usr/bin/env lua

-- Enhanced Aolite Test Runner for AO Processes
-- Runs comprehensive unit tests with enhanced framework features

-- Add current directory to package path for requiring local modules
package.path = package.path .. ";./?.lua;./testing/unit/?.lua;./testing/aolite/?.lua;./processes/?.lua;./test/unit/?.lua"

-- Load enhanced testing framework
local EnhancedFramework = require('testing.aolite.enhanced-test-framework')
local TestGenerators = require('testing.aolite.test-generators')

-- Simple mock for aolite framework (backward compatibility)
local aolite = {
  spawnProcess = function(code) 
    return { id = "test-process-" .. math.random(1000, 9999) }
  end,
  send = function(processId, action, data)
    return { success = true, response = data }
  end,
  eval = function(processId, code)
    return { success = true, result = "eval complete" }
  end
}

-- Mock require for aolite
package.loaded.aolite = aolite

-- Simple test runner function
local function runTestFile(testFile)
  print("Running test file: " .. testFile)
  print(string.rep("-", 60))
  
  -- Try to load the file directly with dofile
  local success, result = pcall(dofile, testFile)
  if not success then
    print("❌ Failed to load test file: " .. testFile)
    print("Error: " .. tostring(result))
    return false
  end
  
  -- If the file returned a module with runTests, call it
  if type(result) == "table" and result.runTests then
    local testSuccess = result.runTests()
    return testSuccess
  else
    print("✅ Test file executed successfully: " .. testFile)
    return true
  end
end

-- Enhanced main test runner
local function main()
  print("🚀 Enhanced Aolite Unit Testing Framework")
  print("=" .. string.rep("=", 60))
  
  -- Run enhanced framework tests
  print("\n🔬 Running Enhanced Framework Tests...")
  local enhancedTests = TestGenerators.generateAllTests()
  local enhancedSuccess = EnhancedFramework.runTests(enhancedTests)
  
  -- Run legacy test files for backward compatibility
  print("\n📂 Running Legacy Test Files...")
  local testFiles = {
    "testing/unit/coordinator-process.test.lua",
    "testing/unit/data-process-template.test.lua", 
    "testing/unit/pokemon-species-db.test.lua",
    "testing/unit/pokemon-instance-manager.test.lua",
    "testing/unit/moves-database.test.lua",
    "testing/unit/items-database.test.lua",
    "testing/unit/abilities-database.test.lua",
    "testing/unit/damage-calculation-engine.test.lua",
    "testing/unit/battle-state-manager.test.lua",
    "test/unit/weather-system-engine.test.lua"
  }
  
  local totalLegacyTests = 0
  local passedLegacyTests = 0
  local failedLegacyTests = 0
  
  for _, testFile in ipairs(testFiles) do
    print("\n")
    local success = runTestFile(testFile)
    totalLegacyTests = totalLegacyTests + 1
    
    if success then
      passedLegacyTests = passedLegacyTests + 1
      print("✅ " .. testFile .. " - PASSED")
    else
      failedLegacyTests = failedLegacyTests + 1
      print("❌ " .. testFile .. " - FAILED")
    end
  end
  
  -- Final combined results
  print("\n" .. string.rep("=", 60))
  print("📊 Combined Test Results:")
  print("  Enhanced Framework: " .. (enhancedSuccess and "PASSED" or "FAILED"))
  print("  Legacy Test Files: " .. passedLegacyTests .. "/" .. totalLegacyTests .. " passed")
  
  if enhancedSuccess and failedLegacyTests == 0 then
    print("\n🎉 All aolite tests passed!")
    os.exit(0)
  else
    print("\n💥 Some aolite tests failed!")
    os.exit(1)
  end
end

-- Run the tests
main()