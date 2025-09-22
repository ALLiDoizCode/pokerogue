#!/usr/bin/env lua

-- Test runner for message passing tests
local messagePassingTestPath = "testing/unit/message-passing.test.lua"
local f = assert(loadfile(messagePassingTestPath))
local messagePassingTests = f()

-- Run the tests
local success = messagePassingTests.runMessagePassingTests()

-- Exit with appropriate code
os.exit(success and 0 or 1)