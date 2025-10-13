-- Unit Tests: Encounter Consequence Calculation
-- Tests consequence calculation logic for encounter failures

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.encounter-reward-engine"
local processId = "test-encounter-reward-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Encounter Reward Engine")
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

local function assert(condition, message)
    if not condition then
        error(currentTest .. " FAILED: " .. message)
    end
end

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

-- ============================================================================
-- Test: Damage Consequence
-- ============================================================================

tests["consequence calculation for damage type"] = function()
    currentTest = "consequence calculation for damage type"

    local partyState = {
        pokemon = {
            {id = 1, hp = 100, maxHp = 150},
            {id = 2, hp = 80, maxHp = 120}
        }
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    assertEquals(response.Action, "SaveState", "Response should be SaveState")
    assertEquals(response.Success, "true", "Success should be true")
    assertEquals(response.ConsequenceType, "DAMAGE", "ConsequenceType should be DAMAGE")

    local data = json.decode(response.Data)
    assertEquals(data.type, "DAMAGE", "Consequence type should be DAMAGE")
    assertNotNil(data.targets, "Should have targets")
    assertNotNil(data.value, "Should have damage value")
    assert(data.value > 0, "Damage value should be positive")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Status Effect Consequence
-- ============================================================================

tests["consequence calculation for status effect type"] = function()
    currentTest = "consequence calculation for status effect type"

    local partyState = {
        pokemon = {
            {id = 1, hp = 100},
            {id = 2, hp = 80}
        }
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "DARK_CAVE",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    -- DARK_CAVE can return STATUS or DAMAGE (depends on implementation)
    assert(data.type == "STATUS" or data.type == "DAMAGE", "Should have valid consequence type")

    if data.type == "STATUS" then
        assertNotNil(data.statusEffect, "Should have status effect")
        assertNotNil(data.duration, "Should have duration")
        assert(data.duration > 0, "Duration should be positive")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Item Loss Consequence
-- ============================================================================

tests["consequence calculation for item loss type"] = function()
    currentTest = "consequence calculation for item loss type"

    local partyState = {
        pokemon = {{id = 1}},
        items = {
            {type = "CONSUMABLE", name = "Potion"},
            {type = "HELD_ITEM", name = "Lucky Egg"}
        }
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "RISKY_TRADE",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    -- RISKY_TRADE can return ITEM_LOSS or MONEY_LOSS
    assert(data.type == "ITEM_LOSS" or data.type == "MONEY_LOSS", "Should have valid consequence type")

    if data.type == "ITEM_LOSS" then
        assertNotNil(data.itemCount, "Should have item count")
        assertNotNil(data.itemTypes, "Should have item types")
        assert(data.itemCount > 0, "Item count should be positive")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Money Loss Consequence
-- ============================================================================

tests["consequence calculation for money loss type"] = function()
    currentTest = "consequence calculation for money loss type"

    local partyState = {
        pokemon = {{id = 1}},
        money = 10000
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "RISKY_TRADE",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    if data.type == "MONEY_LOSS" then
        assertNotNil(data.amount, "Should have money loss amount")
        assert(data.amount > 0, "Money loss should be positive")
        assert(data.amount <= partyState.money, "Money loss should not exceed available money")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Target Selection - Random
-- ============================================================================

tests["target selection random mode"] = function()
    currentTest = "target selection random mode"

    local partyState = {
        pokemon = {
            {id = 1, hp = 100},
            {id = 2, hp = 80},
            {id = 3, hp = 60}
        }
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    if data.targets then
        assert(#data.targets > 0, "Should have at least one target")
        assert(#data.targets <= #partyState.pokemon, "Should not exceed party size")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Target Selection - All
-- ============================================================================

tests["target selection all mode"] = function()
    currentTest = "target selection all mode"

    local partyState = {
        pokemon = {
            {id = 1, hp = 100},
            {id = 2, hp = 80},
            {id = 3, hp = 60}
        }
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "DARK_CAVE",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    -- STATUS consequences typically target all Pokemon
    if data.type == "STATUS" and data.targets then
        assertEquals(#data.targets, #partyState.pokemon, "STATUS should target all Pokemon")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: Consequence Value Ranges
-- ============================================================================

tests["consequence value ranges"] = function()
    currentTest = "consequence value ranges"

    local partyState = {
        pokemon = {{id = 1, hp = 100}},
        money = 5000
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "failure",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    -- Validate consequence values are within reasonable ranges
    if data.type == "DAMAGE" then
        assert(data.value >= 0, "Damage should be non-negative")
        assert(data.value <= 500, "Damage should be reasonable (max 500)")
    elseif data.type == "MONEY_LOSS" then
        assert(data.amount >= 0, "Money loss should be non-negative")
        assert(data.amount <= partyState.money, "Money loss should not exceed available")
    elseif data.type == "STATUS" then
        assert(data.duration >= 1, "Status duration should be at least 1")
        assert(data.duration <= 10, "Status duration should be reasonable (max 10)")
    end

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Test: No Consequences for Success
-- ============================================================================

tests["no consequences for success outcome"] = function()
    currentTest = "no consequences for success outcome"

    local partyState = {
        pokemon = {{id = 1, hp = 100}}
    }

    local response = sendMessage("CalculateConsequences", {
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "success",
        PartyState = json.encode(partyState)
    })

    local data = json.decode(response.Data)

    assertEquals(response.ConsequenceType, "NONE", "Success should have no consequences")
    assert(not data.type or data.type == nil, "Should have no consequence type for success")

    print("✓ " .. currentTest)
end

-- ============================================================================
-- Run all tests
-- ============================================================================

local function runTests()
    local passed = 0
    local failed = 0

    print("\n=== Encounter Consequence Calculation Tests ===\n")

    for name, test in pairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ " .. name .. ": " .. err)
        end
    end

    print("\n=== Test Summary ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))

    if failed == 0 then
        print("\n✓ All tests passed!")
        return 0
    else
        print("\n✗ Some tests failed")
        return 1
    end
end

return runTests()
