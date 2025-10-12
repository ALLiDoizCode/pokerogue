-- Unit Tests: Encounter Outcome Validation
-- Tests outcome validation and threshold determination logic

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.encounter-reward-engine"
local processId = "test-encounter-reward-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Encounter Outcome Validation")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

local tests = {}
local currentTest = ""

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(currentTest .. " FAILED: " .. message .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end
end

tests["outcome validation with success threshold"] = function()
    currentTest = "outcome validation with success threshold"

    local resp = sendMessage("ValidateOutcome", {
        ResultValue = "80",
        Threshold = "50"
    })
    assertEquals(resp.Outcome, "success", "80 >= 50 should be success")

    print("✓ " .. currentTest)
end

tests["outcome validation with failure threshold"] = function()
    currentTest = "outcome validation with failure threshold"

    local resp = sendMessage("ValidateOutcome", {
        ResultValue = "20",
        Threshold = "50"
    })
    assertEquals(resp.Outcome, "failure", "20 < 35 (70% of 50) should be failure")

    print("✓ " .. currentTest)
end

tests["partial success scenarios"] = function()
    currentTest = "partial success scenarios"

    local resp = sendMessage("ValidateOutcome", {
        ResultValue = "40",
        Threshold = "50"
    })
    assertEquals(resp.Outcome, "partial", "40 >= 35 but < 50 should be partial")

    print("✓ " .. currentTest)
end

tests["edge case at exact threshold"] = function()
    currentTest = "edge case at exact threshold"

    local resp = sendMessage("ValidateOutcome", {
        ResultValue = "50",
        Threshold = "50"
    })
    assertEquals(resp.Outcome, "success", "Exact threshold should be success")

    print("✓ " .. currentTest)
end

tests["threshold determination per encounter"] = function()
    currentTest = "threshold determination per encounter"

    -- Test different encounter types derive different thresholds
    local resp = sendMessage("ValidateOutcome", {
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        ResultValue = "60"
    })
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
