-- Unit Tests: Encounter Consequence Mitigation
-- Tests consequence mitigation calculation logic

package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

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

local function setup()
    return aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
end

tests["mitigation for damage consequences"] = function()
    currentTest = "mitigation for damage consequences"
    local process = setup()

    local factors = {defenseBonus = 2, protectiveItems = true}
    local msg = {
        From = "test",
        Action = "MitigateConsequence",
        ConsequenceType = "DAMAGE",
        BaseValue = "100",
        MitigationFactors = aolite.json.encode(factors)
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]

    -- Defense bonus: 2 * 10 = 20%, Protective items: +20% = 40% total
    local expectedMitigated = 100 * (1 - 0.40)
    assertEquals(resp.MitigatedValue, tostring(expectedMitigated), "Should apply 40% mitigation")
    assertEquals(resp.ReductionPercent, "40", "Should report 40% reduction")

    print("✓ " .. currentTest)
end

tests["mitigation for status consequences"] = function()
    currentTest = "mitigation for status consequences"
    local process = setup()

    local factors = {cleanseItems = true}
    local msg = {
        From = "test",
        Action = "MitigateConsequence",
        ConsequenceType = "STATUS",
        BaseValue = "6",
        MitigationFactors = aolite.json.encode(factors)
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]

    -- Cleanse items: 50% reduction
    assertEquals(resp.ReductionPercent, "50", "Should apply 50% reduction")
    assertEquals(resp.MitigatedValue, "3", "6 * 0.5 = 3")

    print("✓ " .. currentTest)
end

tests["mitigation cap at 75 percent"] = function()
    currentTest = "mitigation cap at 75 percent"
    local process = setup()

    -- Excessive defense bonus should cap at 75%
    local factors = {defenseBonus = 10, protectiveItems = true}
    local msg = {
        From = "test",
        Action = "MitigateConsequence",
        ConsequenceType = "DAMAGE",
        BaseValue = "100",
        MitigationFactors = aolite.json.encode(factors)
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]

    assertEquals(resp.ReductionPercent, "75", "Should cap at 75%")
    assertEquals(resp.MitigatedValue, "25", "100 * 0.25 = 25")

    print("✓ " .. currentTest)
end

tests["zero mitigation scenarios"] = function()
    currentTest = "zero mitigation scenarios"
    local process = setup()

    local msg = {
        From = "test",
        Action = "MitigateConsequence",
        ConsequenceType = "MONEY_LOSS",
        BaseValue = "500",
        MitigationFactors = "{}"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]

    assertEquals(resp.ReductionPercent, "0", "Should have 0% reduction")
    assertEquals(resp.MitigatedValue, "500", "Should equal base value")

    print("✓ " .. currentTest)
end

tests["mitigation factors combination"] = function()
    currentTest = "mitigation factors combination"
    local process = setup()

    local factors = {defenseBonus = 3, protectiveItems = true}
    local msg = {
        From = "test",
        Action = "MitigateConsequence",
        ConsequenceType = "DAMAGE",
        BaseValue = "200",
        MitigationFactors = aolite.json.encode(factors)
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]

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
