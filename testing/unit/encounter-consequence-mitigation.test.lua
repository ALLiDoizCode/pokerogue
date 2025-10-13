-- Unit Tests: Encounter Consequence Mitigation
-- Tests consequence mitigation calculation logic

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.encounter-reward-engine"
local processId = "test-encounter-reward-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Encounter Consequence Mitigation")
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

local function assert(condition, message)
    if not condition then error(currentTest .. " FAILED: " .. message) end
end

tests["mitigation for damage consequences"] = function()
    currentTest = "mitigation for damage consequences"

    local factors = {defenseBonus = 2, protectiveItems = true}
    local resp = sendMessage("MitigateConsequence", {
        ConsequenceType = "DAMAGE",
        BaseValue = "100",
        MitigationFactors = json.encode(factors)
    })

    -- Defense bonus: 2 * 10 = 20%, Protective items: +20% = 40% total
    local expectedMitigated = 100 * (1 - 0.40)
    assertEquals(resp.MitigatedValue, tostring(expectedMitigated), "Should apply 40% mitigation")
    assertEquals(resp.ReductionPercent, "40", "Should report 40% reduction")

    print("✓ " .. currentTest)
end

tests["mitigation for status consequences"] = function()
    currentTest = "mitigation for status consequences"

    local factors = {cleanseItems = true}
    local resp = sendMessage("MitigateConsequence", {
        ConsequenceType = "STATUS",
        BaseValue = "6",
        MitigationFactors = json.encode(factors)
    })

    -- Cleanse items: 50% reduction
    assertEquals(resp.ReductionPercent, "50", "Should apply 50% reduction")
    assertEquals(resp.MitigatedValue, "3", "6 * 0.5 = 3")

    print("✓ " .. currentTest)
end

tests["mitigation cap at 75 percent"] = function()
    currentTest = "mitigation cap at 75 percent"

    -- Excessive defense bonus should cap at 75%
    local factors = {defenseBonus = 10, protectiveItems = true}
    local resp = sendMessage("MitigateConsequence", {
        ConsequenceType = "DAMAGE",
        BaseValue = "100",
        MitigationFactors = json.encode(factors)
    })

    assertEquals(resp.ReductionPercent, "75", "Should cap at 75%")
    assertEquals(resp.MitigatedValue, "25", "100 * 0.25 = 25")

    print("✓ " .. currentTest)
end

tests["zero mitigation scenarios"] = function()
    currentTest = "zero mitigation scenarios"

    local resp = sendMessage("MitigateConsequence", {
        ConsequenceType = "MONEY_LOSS",
        BaseValue = "500",
        MitigationFactors = "{}"
    })

    assertEquals(resp.ReductionPercent, "0", "Should have 0% reduction")
    assertEquals(resp.MitigatedValue, "500", "Should equal base value")

    print("✓ " .. currentTest)
end

tests["mitigation factors combination"] = function()
    currentTest = "mitigation factors combination"

    local factors = {defenseBonus = 3, protectiveItems = true}
    local resp = sendMessage("MitigateConsequence", {
        ConsequenceType = "DAMAGE",
        BaseValue = "200",
        MitigationFactors = json.encode(factors)
    })

    -- Defense: 3 * 10 = 30%, Protective: +20% = 50% total
    assertEquals(resp.ReductionPercent, "50", "Should combine factors")
    local mitigated = tonumber(resp.MitigatedValue)
    assert(mitigated == 100, "200 * 0.5 = 100")

    print("✓ " .. currentTest)
end

local function runTests()
    local passed, failed = 0, 0
    print("\n=== Encounter Consequence Mitigation Tests ===\n")
    for name, test in pairs(tests) do
        local success, err = pcall(test)
        if success then passed = passed + 1 else failed = failed + 1; print("✗ " .. name .. ": " .. err) end
    end
    print("\n=== Test Summary ===\nPassed: " .. passed .. "\nFailed: " .. failed)
    return failed == 0 and 0 or 1
end

return runTests()
