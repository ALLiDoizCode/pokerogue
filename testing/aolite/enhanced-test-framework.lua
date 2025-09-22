#!/usr/bin/env lua

--[[
Enhanced Aolite Unit Testing Framework
Provides comprehensive process validation with advanced features:
- Mock AO environment setup for isolated testing
- Unit test generators for process logic functions  
- Test coverage reporting and metrics collection
- Performance profiling and resource measurement
- Test data fixtures for consistent scenarios
]]

local EnhancedAoliteFramework = {}

-- Load advanced testing components
local CoordinationTesting = require('testing.aolite.coordination-testing')
local PropertyBasedTesting = require('testing.aolite.property-based-testing')
local AdvancedBenchmarks = require('testing.aolite.advanced-benchmarks')
local StateManagementAdvanced = require('testing.aolite.state-management-advanced')

-- Test execution metrics
local TestMetrics = {
  totalTests = 0,
  passedTests = 0,
  failedTests = 0,
  errorTests = 0,
  startTime = 0,
  endTime = 0,
  coverage = {},
  performance = {},
  coordination = {},
  properties = {},
  benchmarks = {},
  stateManagement = {}
}

-- Mock AO environment for isolated testing
local function setupMockAOEnvironment()
  -- Mock AO globals
  _G.ao = {
    id = "test-process-12345",
    send = function(message)
      print("MockAO.send:", require('json').encode(message))
      return { success = true, id = "msg-" .. math.random(1000, 9999) }
    end,
    env = {
      Process = {
        Id = "test-process-12345",
        Owner = "test-owner",
        Tags = {}
      }
    }
  }
  
  -- Mock Handlers system
  _G.Handlers = {
    _handlers = {},
    add = function(name, matcher, handler)
      _G.Handlers._handlers[name] = {
        name = name,
        matcher = matcher,
        handler = handler,
        callCount = 0
      }
      print("Handler registered:", name)
    end,
    utils = {
      hasMatchingTag = function(tagName, tagValue)
        return function(msg)
          return msg.Tags and msg.Tags[tagName] == tagValue
        end
      end,
      reply = function(message)
        return function(msg)
          return ao.send({
            Target = msg.From,
            Data = message
          })
        end
      end
    },
    receive = function(msg)
      for name, handler in pairs(_G.Handlers._handlers) do
        if handler.matcher(msg) then
          handler.callCount = handler.callCount + 1
          local success, result = pcall(handler.handler, msg)
          return { success = success, result = result, handler = name }
        end
      end
      return { success = false, error = "No matching handler" }
    end
  }
  
  -- Mock JSON utilities (embedded for AO compatibility)
  _G.json = {
    encode = function(obj)
      if type(obj) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(obj) do
          if not first then result = result .. "," end
          result = result .. '"' .. tostring(k) .. '":' .. _G.json.encode(v)
          first = false
        end
        return result .. "}"
      elseif type(obj) == "string" then
        return '"' .. obj .. '"'
      else
        return tostring(obj)
      end
    end,
    decode = function(str) return {} end
  }
  
  -- Mock crypto for deterministic testing
  _G.crypto = {
    random = function(min, max)
      math.randomseed(12345) -- Fixed seed for deterministic tests
      return math.random(min or 0, max or 1)
    end
  }
  
  print("✅ Mock AO environment initialized")
end

-- Test assertion functions
local function assert_equal(actual, expected, message)
  message = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
  if actual ~= expected then
    error("Assertion failed: " .. message)
  end
end

local function assert_true(condition, message)
  message = message or "Expected condition to be true"
  if not condition then
    error("Assertion failed: " .. message)
  end
end

local function assert_not_nil(value, message)
  message = message or "Expected value to not be nil"
  if value == nil then
    error("Assertion failed: " .. message)
  end
end

local function assert_type(value, expectedType, message)
  message = message or string.format("Expected type %s, got %s", expectedType, type(value))
  if type(value) ~= expectedType then
    error("Assertion failed: " .. message)
  end
end

-- Test execution functions
local function executeTest(testName, testFunction)
  TestMetrics.totalTests = TestMetrics.totalTests + 1
  
  local testStart = os.clock()
  local success, result = pcall(testFunction)
  local testEnd = os.clock()
  
  local executionTime = testEnd - testStart
  TestMetrics.performance[testName] = executionTime
  
  if success then
    TestMetrics.passedTests = TestMetrics.passedTests + 1
    print(string.format("  ✅ %s (%.2fms)", testName, executionTime * 1000))
    return true
  else
    TestMetrics.failedTests = TestMetrics.failedTests + 1
    print(string.format("  ❌ %s - %s", testName, tostring(result)))
    return false
  end
end

-- Test suite execution
local function runTestSuite(suiteName, tests)
  print(string.format("\n🧪 Running test suite: %s", suiteName))
  print(string.rep("-", 50))
  
  local suiteStart = os.clock()
  local suitePassed = 0
  local suiteTotal = 0
  
  for testName, testFunction in pairs(tests) do
    if type(testFunction) == "function" then
      suiteTotal = suiteTotal + 1
      if executeTest(testName, testFunction) then
        suitePassed = suitePassed + 1
      end
    end
  end
  
  local suiteEnd = os.clock()
  local suiteTime = suiteEnd - suiteStart
  
  print(string.format("📊 Suite results: %d/%d passed (%.2fms)", 
    suitePassed, suiteTotal, suiteTime * 1000))
  
  return suitePassed, suiteTotal
end

-- Performance profiling
local function profileFunction(functionName, func, iterations)
  iterations = iterations or 1000
  
  local start = os.clock()
  for i = 1, iterations do
    func()
  end
  local finish = os.clock()
  
  local totalTime = finish - start
  local avgTime = totalTime / iterations
  
  print(string.format("⏱️  Performance profile for %s:", functionName))
  print(string.format("   Total time: %.4fs", totalTime))
  print(string.format("   Avg per call: %.6fs", avgTime))
  print(string.format("   Iterations: %d", iterations))
  
  return {
    totalTime = totalTime,
    avgTime = avgTime,
    iterations = iterations
  }
end

-- Test data fixtures
local function createTestFixtures()
  return {
    mockPokemon = {
      species = "Charizard",
      level = 50,
      stats = { hp = 153, attack = 134, defense = 111, spAttack = 159, spDefense = 115, speed = 120 },
      types = { "Fire", "Flying" },
      moves = { "Flamethrower", "Dragon Pulse", "Air Slash", "Solar Beam" },
      nature = "Modest",
      ability = "Blaze"
    },
    mockBattle = {
      turn = 1,
      weather = "none",
      field = { terrain = "none", effects = {} },
      players = {
        player1 = { id = "player1", pokemon = {} },
        player2 = { id = "player2", pokemon = {} }
      }
    },
    mockMessage = {
      Id = "msg-12345",
      From = "test-sender",
      Target = "test-target", 
      Action = "Test",
      Data = "test data",
      Tags = { Action = "Test" },
      Timestamp = tostring(1234567890)
    }
  }
end

-- Coverage tracking
local function trackCoverage(processFile)
  local coverage = {
    file = processFile,
    functions = {},
    lines = {},
    totalLines = 0,
    coveredLines = 0
  }
  
  -- Mock coverage tracking - real implementation would instrument Lua code
  print(string.format("📈 Tracking coverage for: %s", processFile))
  
  return coverage
end

-- Test report generation
local function generateTestReport()
  TestMetrics.endTime = os.clock()
  local totalTime = TestMetrics.endTime - TestMetrics.startTime
  
  print(string.rep("=", 60))
  print("📊 Enhanced Aolite Test Report")
  print(string.rep("=", 60))
  
  print(string.format("Total Tests: %d", TestMetrics.totalTests))
  print(string.format("Passed: %d (%.1f%%)", 
    TestMetrics.passedTests, 
    (TestMetrics.passedTests / math.max(TestMetrics.totalTests, 1)) * 100))
  print(string.format("Failed: %d (%.1f%%)", 
    TestMetrics.failedTests,
    (TestMetrics.failedTests / math.max(TestMetrics.totalTests, 1)) * 100))
  print(string.format("Total Time: %.2fs", totalTime))
  
  -- Performance summary
  if next(TestMetrics.performance) then
    print("\n⏱️  Performance Summary:")
    for testName, time in pairs(TestMetrics.performance) do
      print(string.format("  %s: %.2fms", testName, time * 1000))
    end
  end
  
  -- Overall result
  if TestMetrics.failedTests == 0 then
    print("\n🎉 All tests passed!")
    return true
  else
    print("\n💥 Some tests failed!")
    return false
  end
end

-- Main framework interface
function EnhancedAoliteFramework.runTests(testSuites)
  TestMetrics.startTime = os.clock()
  
  print("🚀 Enhanced Aolite Unit Testing Framework")
  print("=" .. string.rep("=", 59))
  
  -- Setup mock environment
  setupMockAOEnvironment()
  
  -- Create test fixtures
  local fixtures = createTestFixtures()
  
  -- Run all test suites
  for suiteName, tests in pairs(testSuites) do
    runTestSuite(suiteName, tests)
  end
  
  -- Generate final report
  local success = generateTestReport()
  
  return success
end

-- Advanced testing integration functions
function EnhancedAoliteFramework.runAdvancedTestSuite(suiteName, testConfig)
  print(string.format("\n🚀 Running Advanced Test Suite: %s", suiteName))
  print(string.rep("=", 60))
  
  local suiteStart = os.clock()
  local results = {
    basic = {},
    coordination = {},
    properties = {},
    benchmarks = {},
    stateManagement = {}
  }
  
  -- Run basic unit tests
  if testConfig.unitTests then
    results.basic = EnhancedAoliteFramework.runTests(testConfig.unitTests)
  end
  
  -- Run coordination tests
  if testConfig.coordinationTests then
    for scenarioName, scenario in pairs(testConfig.coordinationTests) do
      results.coordination[scenarioName] = CoordinationTesting.testCoordinationScenario(
        scenarioName, scenario.processes, scenario.messages, scenario.validations
      )
    end
  end
  
  -- Run property-based tests
  if testConfig.propertyTests then
    PropertyBasedTesting.initialize(testConfig.propertyConfig)
    for suiteName, properties in pairs(testConfig.propertyTests) do
      results.properties[suiteName] = PropertyBasedTesting.runPropertySuite(suiteName, properties)
    end
  end
  
  -- Run benchmarks
  if testConfig.benchmarks then
    results.benchmarks = AdvancedBenchmarks.runBenchmarkSuite(
      suiteName .. "_benchmarks", testConfig.benchmarks, testConfig.benchmarkConfig
    )
  end
  
  -- Run state management tests
  if testConfig.stateTests then
    for testName, stateTest in pairs(testConfig.stateTests) do
      if stateTest.type == "synchronization" then
        results.stateManagement[testName] = StateManagementAdvanced.testStateSynchronization(
          stateTest.processes, stateTest.updates
        )
      elseif stateTest.type == "persistence" then
        results.stateManagement[testName] = StateManagementAdvanced.testStatePersistence(
          stateTest.worldState, stateTest.persistFunction, stateTest.loadFunction
        )
      elseif stateTest.type == "rollback" then
        results.stateManagement[testName] = StateManagementAdvanced.testStateRollback(
          stateTest.worldState, stateTest.mutationFunction, stateTest.rollbackFunction
        )
      end
    end
  end
  
  local suiteEnd = os.clock()
  local totalTime = suiteEnd - suiteStart
  
  -- Generate comprehensive report
  print(string.rep("=", 60))
  print("📊 Advanced Test Suite Report")
  print(string.rep("=", 60))
  print(string.format("Total execution time: %.2fs", totalTime))
  
  -- Summary statistics
  local totalTestCount = 0
  local totalPassCount = 0
  
  if results.basic then
    print(string.format("Unit Tests: %s", results.basic and "✅ Passed" or "❌ Failed"))
  end
  
  if results.coordination then
    local coordPassed = 0
    local coordTotal = 0
    for _, result in pairs(results.coordination) do
      coordTotal = coordTotal + 1
      if result.success then coordPassed = coordPassed + 1 end
    end
    print(string.format("Coordination Tests: %d/%d passed", coordPassed, coordTotal))
  end
  
  if results.properties then
    local propPassed = 0
    local propTotal = 0
    for _, suite in pairs(results.properties) do
      propTotal = propTotal + suite.totalProperties
      propPassed = propPassed + suite.passedProperties
    end
    print(string.format("Property Tests: %d/%d passed", propPassed, propTotal))
  end
  
  if results.benchmarks then
    print(string.format("Benchmarks: %d executed, %d regressions", 
      results.benchmarks.summary.totalBenchmarks,
      results.benchmarks.summary.regressions))
  end
  
  if results.stateManagement then
    local statePassed = 0
    local stateTotal = 0
    for _, result in pairs(results.stateManagement) do
      stateTotal = stateTotal + 1
      if result.synchronizationSuccessful or result.dataIntegrity or result.stateRestored then
        statePassed = statePassed + 1
      end
    end
    print(string.format("State Management Tests: %d/%d passed", statePassed, stateTotal))
  end
  
  return results
end

-- Export framework functions for external use
EnhancedAoliteFramework.setupMockAO = setupMockAOEnvironment
EnhancedAoliteFramework.assert_equal = assert_equal
EnhancedAoliteFramework.assert_true = assert_true
EnhancedAoliteFramework.assert_not_nil = assert_not_nil
EnhancedAoliteFramework.assert_type = assert_type
EnhancedAoliteFramework.profileFunction = profileFunction
EnhancedAoliteFramework.createFixtures = createTestFixtures
EnhancedAoliteFramework.trackCoverage = trackCoverage

-- Export advanced testing components
EnhancedAoliteFramework.coordination = CoordinationTesting
EnhancedAoliteFramework.properties = PropertyBasedTesting
EnhancedAoliteFramework.benchmarks = AdvancedBenchmarks
EnhancedAoliteFramework.stateManagement = StateManagementAdvanced

return EnhancedAoliteFramework