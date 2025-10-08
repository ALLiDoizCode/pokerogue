-- Unit Tests: Encounter Rarity Scaling
-- Tests reward rarity calculation with wave progression and luck modifiers

package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

local tests = {}
local currentTest = ""

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(currentTest .. " FAILED: " .. message .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end
end

local function assertNotNil(value, message)
    if value == nil then
        error(currentTest .. " FAILED: " .. message)
    end
end

local function setup()
    return aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
end

tests["rarity scaling with wave progression"] = function()
    currentTest = "rarity scaling with wave progression"
    local process = setup()

    -- Test at wave 0 (no bonus)
    local msg = {
        From = "test",
        Action = "CalculateRewardRarity",
        BaseRarity = "COMMON",
        WaveIndex = "0",
        LuckValue = "0"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp1 = aolite.getAllMsgs(process)[1]
    assertEquals(resp1.Rarity, "COMMON", "Wave 0 should keep COMMON")

    -- Test at wave 50 (+1 tier)
    msg.WaveIndex = "50"
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp2 = aolite.getAllMsgs(process)[2]
    assertEquals(resp2.Rarity, "UNCOMMON", "Wave 50 should upgrade to UNCOMMON")

    -- Test at wave 100 (+2 tiers)
    msg.WaveIndex = "100"
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp3 = aolite.getAllMsgs(process)[3]
    assertEquals(resp3.Rarity, "RARE", "Wave 100 should upgrade to RARE")

    print("✓ " .. currentTest)
end

tests["rarity scaling with luck values"] = function()
    currentTest = "rarity scaling with luck values"
    local process = setup()

    -- Luck 0-5: no bonus
    local msg = {
        From = "test",
        Action = "CalculateRewardRarity",
        BaseRarity = "COMMON",
        WaveIndex = "0",
        LuckValue = "3"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp1 = aolite.getAllMsgs(process)[1]
    assertEquals(resp1.Rarity, "COMMON", "Luck 3 should not upgrade")

    -- Luck 6-10: +1 bonus
    msg.LuckValue = "7"
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp2 = aolite.getAllMsgs(process)[2]
    assertEquals(resp2.Rarity, "UNCOMMON", "Luck 7 should upgrade to UNCOMMON")

    -- Luck 11+: +2 bonus
    msg.LuckValue = "12"
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp3 = aolite.getAllMsgs(process)[3]
    assertEquals(resp3.Rarity, "RARE", "Luck 12 should upgrade to RARE")

    print("✓ " .. currentTest)
end

tests["rarity tier clamping"] = function()
    currentTest = "rarity tier clamping"
    local process = setup()

    -- Test upper limit (LEGENDARY)
    local msg = {
        From = "test",
        Action = "CalculateRewardRarity",
        BaseRarity = "LEGENDARY",
        WaveIndex = "200",
        LuckValue = "15"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Rarity, "LEGENDARY", "Should clamp at LEGENDARY")

    print("✓ " .. currentTest)
end

tests["base rarity preservation"] = function()
    currentTest = "base rarity preservation"
    local process = setup()

    -- No bonuses should preserve base rarity
    local msg = {
        From = "test",
        Action = "CalculateRewardRarity",
        BaseRarity = "RARE",
        WaveIndex = "0",
        LuckValue = "0"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]
    assertEquals(resp.Rarity, "RARE", "Should preserve RARE with no bonuses")

    print("✓ " .. currentTest)
end

tests["bonus calculation"] = function()
    currentTest = "bonus calculation"
    local process = setup()

    local msg = {
        From = "test",
        Action = "CalculateRewardRarity",
        BaseRarity = "COMMON",
        WaveIndex = "50",
        LuckValue = "7"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)
    local resp = aolite.getAllMsgs(process)[1]

    assertEquals(resp.RarityBonus, "2", "Should have +2 bonus (wave+luck)")
    assertEquals(resp.Rarity, "RARE", "COMMON + 2 bonus = RARE")

    print("✓ " .. currentTest)
end

local function runTests()
    local passed, failed = 0, 0
    print("\n=== Encounter Rarity Scaling Tests ===\n")
    for name, test in pairs(tests) do
        local success, err = pcall(test)
        if success then passed = passed + 1 else failed = failed + 1; print("✗ " .. name .. ": " .. err) end
    end
    print("\n=== Test Summary ===\nPassed: " .. passed .. "\nFailed: " .. failed .. "\nTotal: " .. (passed + failed))
    return failed == 0 and 0 or 1
end

return runTests()
