#!/usr/bin/env lua

-- Aolite Test Runner for AO Processes
-- Runs unit tests using Lua without requiring aolite framework

-- Simple mock for aolite framework
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

-- Add current directory to package path for requiring local modules
package.path = package.path .. ";./?.lua;./testing/unit/?.lua;./processes/?.lua"

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

-- Main test runner
local function main()
  print("🚀 Running Aolite Unit Tests")
  print("=" .. string.rep("=", 60))
  
  -- List of test files to run
  local testFiles = {
    "testing/unit/coordinator-process.test.lua", -- Direct path with extension
    "testing/unit/data-process-template.test.lua", -- Data process template tests
    "testing/unit/pokemon-species-db.test.lua", -- Pokemon species database tests
    "testing/unit/moves-database.test.lua", -- Moves database tests
    "testing/unit/items-database.test.lua", -- Items database tests
    "testing/unit/abilities-database.test.lua" -- Abilities database tests
  }
  
  local totalTests = 0
  local passedTests = 0
  local failedTests = 0
  
  for _, testFile in ipairs(testFiles) do
    print("\n")
    local success = runTestFile(testFile)
    totalTests = totalTests + 1
    
    if success then
      passedTests = passedTests + 1
      print("✅ " .. testFile .. " - PASSED")
    else
      failedTests = failedTests + 1
      print("❌ " .. testFile .. " - FAILED")
    end
  end
  
  print("\n" .. string.rep("=", 60))
  print("📊 Final Test Results:")
  print("  Total test files: " .. totalTests)
  print("  Passed: " .. passedTests)
  print("  Failed: " .. failedTests)
  
  if failedTests == 0 then
    print("\n🎉 All aolite tests passed!")
    os.exit(0)
  else
    print("\n💥 Some aolite tests failed!")
    os.exit(1)
  end
end

-- Run the tests
main()