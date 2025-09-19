-- Data Process Template Test (Deprecated - ADP v1.0 Migration)
-- This test is deprecated as templates have been replaced with ADP v1.0 compliant processes

-- Simple placeholder to prevent test runner failures
local function runTests()
    print("Data Process Template tests skipped - deprecated after ADP v1.0 migration")
    return true
end

-- Export for aolite framework
return {
    runTests = runTests
}