-- Unit Tests: Encounter Rarity Scaling
-- Tests reward rarity calculation with wave progression and luck modifiers

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.encounter-reward-engine"
local processId = "test-encounter-reward-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Encounter Rarity Scaling")
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

local function assertNotNil(value, message)
    if value == nil then
        error(currentTest .. " FAILED: " .. message)
    end
end

tests["rarity scaling with wave progression"] = function()
    currentTest = "rarity scaling with wave progression"

    -- Test at wave 0 (no bonus)
    local resp1 = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "0",
        LuckValue = "0"
    })
    assertEquals(resp1.Rarity, "COMMON", "Wave 0 should keep COMMON")

    -- Test at wave 50 (+1 tier)
    local resp2 = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "50",
        LuckValue = "0"
    })
    assertEquals(resp2.Rarity, "UNCOMMON", "Wave 50 should upgrade to UNCOMMON")

    -- Test at wave 100 (+2 tiers)
    local resp3 = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "100",
        LuckValue = "0"
    })
    assertEquals(resp3.Rarity, "RARE", "Wave 100 should upgrade to RARE")

    print("✓ " .. currentTest)
end

tests["rarity scaling with luck values"] = function()
    currentTest = "rarity scaling with luck values"

    -- Luck 0-5: no bonus
    local resp1 = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "0",
        LuckValue = "3"
    })
    assertEquals(resp1.Rarity, "COMMON", "Luck 3 should not upgrade")

    -- Luck 6-10: +1 bonus
    local resp2 = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "0",
        LuckValue = "7"
    })
    assertEquals(resp2.Rarity, "UNCOMMON", "Luck 7 should upgrade to UNCOMMON")

    -- Luck 11+: +2 bonus
    local resp3 = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "0",
        LuckValue = "12"
    })
    assertEquals(resp3.Rarity, "RARE", "Luck 12 should upgrade to RARE")

    print("✓ " .. currentTest)
end

tests["rarity tier clamping"] = function()
    currentTest = "rarity tier clamping"

    -- Test upper limit (LEGENDARY)
    local resp = sendMessage("CalculateRewardRarity", {
        BaseRarity = "LEGENDARY",
        WaveIndex = "200",
        LuckValue = "15"
    })
    assertEquals(resp.Rarity, "LEGENDARY", "Should clamp at LEGENDARY")

    print("✓ " .. currentTest)
end

tests["base rarity preservation"] = function()
    currentTest = "base rarity preservation"

    -- No bonuses should preserve base rarity
    local resp = sendMessage("CalculateRewardRarity", {
        BaseRarity = "RARE",
        WaveIndex = "0",
        LuckValue = "0"
    })
    assertEquals(resp.Rarity, "RARE", "Should preserve RARE with no bonuses")

    print("✓ " .. currentTest)
end

tests["bonus calculation"] = function()
    currentTest = "bonus calculation"

    local resp = sendMessage("CalculateRewardRarity", {
        BaseRarity = "COMMON",
        WaveIndex = "50",
        LuckValue = "7"
    })

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
