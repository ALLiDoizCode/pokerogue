-- Unit Tests: Encounter Outcome Validation
-- Tests outcome validation and threshold determination logic

package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

local tests = {}
local currentTest = ""

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(currentTest .. " FAILED: " .. message .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end
end

local function setup()
    return aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
end

tests["outcome validation with success threshold"] = function()
    currentTest = "outcome validation with success threshold"
    local process = setup()

    local msg = {
        From = "test",
        Action = "ValidateOutcome",
        ResultValue = "80",
        Threshold = "50"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Outcome, "success", "80 >= 50 should be success")

    print("✓ " .. currentTest)
end

tests["outcome validation with failure threshold"] = function()
    currentTest = "outcome validation with failure threshold"
    local process = setup()

    local msg = {
        From = "test",
        Action = "ValidateOutcome",
        ResultValue = "20",
        Threshold = "50"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Outcome, "failure", "20 < 35 (70% of 50) should be failure")

    print("✓ " .. currentTest)
end

tests["partial success scenarios"] = function()
    currentTest = "partial success scenarios"
    local process = setup()

    local msg = {
        From = "test",
        Action = "ValidateOutcome",
        ResultValue = "40",
        Threshold = "50"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Outcome, "partial", "40 >= 35 but < 50 should be partial")

    print("✓ " .. currentTest)
end

tests["edge case at exact threshold"] = function()
    currentTest = "edge case at exact threshold"
    local process = setup()

    local msg = {
        From = "test",
        Action = "ValidateOutcome",
        ResultValue = "50",
        Threshold = "50"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Outcome, "success", "Exact threshold should be success")

    print("✓ " .. currentTest)
end

tests["threshold determination per encounter"] = function()
    currentTest = "threshold determination per encounter"
    local process = setup()

    -- Test different encounter types derive different thresholds
    local msg = {
        From = "test",
        Action = "ValidateOutcome",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        ResultValue = "60"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Success, "true", "Should determine threshold from encounter")

    print("✓ " .. currentTest)
end

local function runTests()
    local passed, failed = 0, 0
    print("\n=== Encounter Outcome Validation Tests ===\n")
    for name, test in pairs(tests) do
        local success, err = pcall(test)
        if success then passed = passed + 1 else failed = failed + 1; print("✗ " .. name .. ": " .. err) end
    end
    print("\n=== Test Summary ===\nPassed: " .. passed .. "\nFailed: " .. failed)
    return failed == 0 and 0 or 1
end

return runTests()
