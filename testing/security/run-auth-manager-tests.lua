#!/usr/bin/env lua

-- Standalone test runner for Authentication Manager
print("🚀 Loading Authentication Manager Tests...")

-- Load and run the tests
local testModule = dofile("testing/security/auth-manager.test.lua")
local success, error = pcall(testModule.runAllTests)

if not success then
    print("❌ Authentication Manager tests failed with error:", error)
    os.exit(1)
end

print("✅ Authentication Manager test suite completed successfully")