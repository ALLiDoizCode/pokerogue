#!/usr/bin/env lua

-- Standalone test runner for Input Validator
print("🚀 Loading Input Validator Tests...")

-- Load and run the tests
local testModule = dofile("testing/security/input-validator.test.lua")
local success, error = pcall(testModule.runAllTests)

if not success then
    print("❌ Input Validator tests failed with error:", error)
    os.exit(1)
end

print("✅ Input Validator test suite completed successfully")