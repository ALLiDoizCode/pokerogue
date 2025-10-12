#!/usr/bin/env lua

-- Enhanced Aolite Test Runner for AO Processes
-- Runs comprehensive unit tests with enhanced framework features

-- Add current directory to package path for requiring local modules
package.path = package.path .. ";./?.lua;./testing/unit/?.lua;./testing/aolite/?.lua;./processes/?.lua;./test/unit/?.lua;./development-tools/aolite/lua/?/init.lua;./development-tools/aolite/lua/?.lua;./development-tools/aolite/lua/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua;./development-tools/aolite/lua/aolite/factories/?.lua"

-- Load enhanced testing framework
local EnhancedFramework = require('testing.aolite.enhanced-test-framework')
local TestGenerators = require('testing.aolite.test-generators')

-- Try to load real aolite first, fallback to mock if not available
local aolite
local aoliteAvailable, aoliteModule = pcall(require, "aolite")

if aoliteAvailable then
  -- Use real aolite from development-tools
  aolite = aoliteModule
  print("✅ Loaded real aolite framework from development-tools")
else
  -- Fallback to simple mock for backward compatibility
  print("⚠️  Using mock aolite (real aolite not found)")
  aolite = {
    spawnProcess = function(originalId, dataOrPath, tags)
      return "test-process-" .. math.random(1000, 9999)
    end,
    send = function(msg)
      -- msg should be a table with From, Target, Action, etc.
      return {
        Action = "SaveState",
        Success = "true",
        From = msg.Target or "test-process",
        Target = msg.From or "test-sender"
      }
    end,
    eval = function(processId, code)
      return { success = true, result = "eval complete" }
    end
  }
end

-- Mock require for aolite
package.loaded.aolite = aolite

-- Load json module from aolite
local json
local jsonAvailable, jsonModule = pcall(require, "json")
if jsonAvailable then
  json = jsonModule
  print("✅ Loaded json module from aolite")
else
  print("⚠️  Using minimal json mock")
  json = {
    encode = function(t) return "{}" end,
    decode = function(s) return {} end
  }
end
package.loaded.json = json

-- Simple test runner function
local function runTestFile(testFile)
  print("Running test file: " .. testFile)
  print(string.rep("-", 60))

  -- Clear aolite process state between tests to prevent process ID collisions
  if aolite and aolite.clearAllProcesses then
    aolite.clearAllProcesses()
  end

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
    "testing/unit/pokemon-species-db.test.lua",
    "testing/unit/pokemon-instance-manager.test.lua",
    "testing/unit/moves-database.test.lua",
    "testing/unit/items-database.test.lua",
    "testing/unit/abilities-database.test.lua",
    "testing/unit/damage-calculation-engine.test.lua",
    "testing/unit/battle-state-manager.test.lua",
    "testing/unit/weather-system-engine.test.lua",
    "testing/unit/positional-battle-mechanics-engine.test.lua",
    "testing/unit/fusion-battle-engine.test.lua",
    "testing/unit/pc-storage-manager.test.lua",
    "testing/unit/unlockable-content-engine.test.lua",
    "testing/unit/trainer-encounter-engine.test.lua",
    "testing/unit/gym-leader-elite-four.test.lua",
    "testing/unit/environmental-cycle.test.lua",
    -- Story 20.3: Rewritten describe/it tests
    "testing/unit/egg-hatching-engine.test.lua",
    "testing/unit/friendship-engine.test.lua",
    -- AI Move Selection Engine tests (Story 17.1)
    "testing/unit/ai-move-selection-benefit-scoring.test.lua",
    "testing/unit/ai-move-selection-special-cases.test.lua",
    "testing/unit/ai-move-selection-target-resolution.test.lua",
    "testing/unit/ai-move-selection-weight-normalization.test.lua",
    "testing/unit/ai-switch-matchup-scoring.test.lua",
    "testing/unit/ai-switch-decision-logic.test.lua",
    -- Daily Run Engine tests (Story 18.1)
    "testing/unit/daily-run-generation.test.lua",
    -- Daily Run Engine additional tests (Story 18.1a)
    "testing/unit/daily-run-biome-selection.test.lua",
    "testing/unit/daily-run-difficulty.test.lua",
    "testing/unit/daily-run-trainer-waves.test.lua",
    "testing/unit/daily-run-event-seed-parsing.test.lua",
    -- Game Mode Engine tests (Story 18.3)
    "testing/unit/game-mode-creation.test.lua",
    "testing/unit/game-mode-wave-detection.test.lua",
    "testing/unit/game-mode-rewards.test.lua",
    "testing/unit/game-mode-challenge-integration.test.lua",
    -- Difficulty Scaling tests (Story 18.4)
    "testing/unit/difficulty-scaling.test.lua",
    -- Dialogue Navigation tests (Story 19.2)
    "testing/unit/dialogue-flow-navigation.test.lua",
    "testing/unit/dialogue-option-validation.test.lua",
    "testing/unit/dialogue-token-replacement.test.lua",
    "testing/unit/dialogue-consequence-calculation.test.lua",
    -- Character Dialogue Engine tests (Story 19.3)
    "testing/unit/character-dialogue-selection.test.lua",
    "testing/unit/character-personality-consistency.test.lua",
    "testing/unit/character-context-awareness.test.lua",
    "testing/unit/character-speaker-mapping.test.lua",
    "testing/parity/character-dialogue-parity.test.lua",
    "testing/performance/character-dialogue-performance.test.lua",
    -- Special Event Engine tests (Story 19.5)
    "testing/unit/special-event-trigger.test.lua",
    "testing/unit/special-event-duration.test.lua",
    "testing/unit/special-event-effects.test.lua",
    "testing/unit/special-event-rewards.test.lua",
    "testing/unit/special-event-encounters.test.lua",
    "testing/parity/special-event-parity.test.lua",
    "testing/performance/special-event-performance.test.lua"
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