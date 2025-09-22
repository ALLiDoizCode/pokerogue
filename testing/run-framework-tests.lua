#!/usr/bin/env lua

-- Simple test runner for framework tests
local frameworkTestPath = "testing/unit/framework/framework.test.lua"
local f = assert(loadfile(frameworkTestPath))
local frameworkTests = f()

-- Run the tests
local success = frameworkTests.runFrameworkTests()

-- Exit with appropriate code
os.exit(success and 0 or 1)