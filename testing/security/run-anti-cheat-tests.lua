#!/usr/bin/env lua

-- Standalone test runner for Anti-Cheat Detector
print("🚀 Loading Anti-Cheat Detector Tests...")

-- Load and run the tests
local testModule = dofile("testing/security/anti-cheat-detector.test.lua")
local success = pcall(testModule.runAllTests)

if not success then
    print("❌ Anti-Cheat Detector tests failed")
    os.exit(1)
end

print("✅ Anti-Cheat Detector test suite completed successfully")