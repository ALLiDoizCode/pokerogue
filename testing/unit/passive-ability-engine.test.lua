-- Unit tests for Passive Ability Engine Process
-- Tests passive ability lookup, unlock/upgrade, enable/disable, and trigger evaluation
-- Uses AO message-based testing pattern compatible with AO runtime

-- Mock AO environment for testing
local ao = {
    send = function(msg)
        -- Store the message for test verification
        table.insert(_G.testResults or {}, msg)
        return msg
    end,
    id = "passive_ability_engine_unit_test"
}

-- Mock Handlers for testing
local Handlers = {
    add = function(name, matcher, handler)
        -- Store handlers for testing
        _G.testHandlers = _G.testHandlers or {}
        _G.testHandlers[name] = {matcher = matcher, handler = handler}
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value or (type(value) == "table" and msg[tag] and table.contains(value, msg[tag]))
            end
        end
    }
}

-- Mock JSON for testing
local json = {
    encode = function(data)
        if type(data) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(data) do
                if not first then result = result .. "," end
                if type(v) == "table" then
                    result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
                else
                    result = result .. '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                end
                first = false
            end
            return result .. "}"
        end
        return tostring(data)
    end,
    decode = function(str)
        if str == '{}' or str == '' then return {} end
        -- Parse simple JSON for testing
        local result = {}
        -- Extract event field if present
        local event = str:match('"event"%s*:%s*"([^"]+)"')
        if event then
            result.event = event
        end
        -- Extract battleContext if present
        if str:match('"battleContext"') then
            result.battleContext = {}
        end
        return result
    end
}

-- Set up global AO environment
_G.ao = ao
_G.Handlers = Handlers
_G.json = json
_G.testResults = {}

-- Load passive ability engine process
local function loadPassiveAbilityEngineProcess()
    local file = io.open("processes/passive-ability-engine.lua", "r")
    if not file then
        error("Could not find passive-ability-engine.lua")
    end

    local content = file:read("*all")
    file:close()

    local processFunction = load(content)
    if not processFunction then
        error("Failed to load passive ability engine process")
    end

    processFunction()
    print("✓ Passive ability engine process loaded for unit testing")
end

-- Helper functions
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Test message creation helpers
local function createTestMessage(action, fields)
    local msg = {
        Action = action,
        From = "test_client",
        Timestamp = 1234567890
    }

    if fields then
        for k, v in pairs(fields) do
            msg[k] = v
        end
    end

    return msg
end

-- Test execution helper
local function executeHandler(handlerName, msg)
    _G.testResults = {}

    local handler = _G.testHandlers[handlerName]
    if not handler then
        error("Handler not found: " .. handlerName)
    end

    handler.handler(msg)

    return _G.testResults[1]
end

-- ====================================
-- UNIT TESTS
-- ====================================

local function runTests()
    local passedTests = 0
    local failedTests = 0
    local totalTests = 0

    local function test(name, fn)
        totalTests = totalTests + 1
        print("\n▶ Test: " .. name)

        local success, error = pcall(fn)

        if success then
            passedTests = passedTests + 1
            print("  ✅ PASSED")
        else
            failedTests = failedTests + 1
            print("  ❌ FAILED: " .. tostring(error))
        end
    end

    local function assert_equal(actual, expected, message)
        if actual ~= expected then
            error(message or "Expected " .. tostring(expected) .. " but got " .. tostring(actual))
        end
    end

    local function assert_not_nil(value, message)
        if value == nil then
            error(message or "Expected non-nil value")
        end
    end

    local function assert_truthy(value, message)
        if not value then
            error(message or "Expected truthy value")
        end
    end

    -- ====================================
    -- Test 1: Get Passive Ability for Species (Basic)
    -- ====================================
    test("Get passive ability for Bulbasaur at tier 0", function()
        local msg = createTestMessage("GetPassiveAbility", {
            SpeciesId = "BULBASAUR",
            UpgradeLevel = "0"
        })

        local response = executeHandler("get-passive-ability", msg)

        assert_not_nil(response, "Response should not be nil")
        assert_equal(response.Action, "PassiveAbilityData", "Should return PassiveAbilityData")
        assert_equal(response.Success, "true", "Should succeed")
        assert_equal(response.SpeciesId, "BULBASAUR", "Should return BULBASAUR")
        assert_equal(response.AbilityId, "GRASSY_SURGE", "Should return GRASSY_SURGE ability")
        assert_equal(response.UpgradeLevel, "0", "Should be tier 0")
    end)

    -- ====================================
    -- Test 2: Get Passive Ability with Multiple Tiers
    -- ====================================
    test("Get passive ability for Charizard with multiple tiers", function()
        local msg = createTestMessage("GetPassiveAbility", {
            SpeciesId = "CHARIZARD",
            UpgradeLevel = "0"
        })

        local response = executeHandler("get-passive-ability", msg)

        assert_equal(response.SpeciesId, "CHARIZARD", "Should return CHARIZARD")
        assert_equal(response.AbilityId, "BEAST_BOOST", "Should return tier 0 ability")
        assert_equal(response.MaxUpgradeTier, "3", "Charizard has 4 tiers (0-3)")
    end)

    -- ====================================
    -- Test 3: Get Passive Ability at Higher Tier
    -- ====================================
    test("Get Charizard passive at tier 2", function()
        local msg = createTestMessage("GetPassiveAbility", {
            SpeciesId = "CHARIZARD",
            UpgradeLevel = "2"
        })

        local response = executeHandler("get-passive-ability", msg)

        assert_equal(response.AbilityId, "TURBOBLAZE", "Should return tier 2 ability")
        assert_equal(response.UpgradeLevel, "2", "Should be tier 2")
    end)

    -- ====================================
    -- Test 4: Get Passive for Invalid Species
    -- ====================================
    test("Get passive ability for non-existent species", function()
        local msg = createTestMessage("GetPassiveAbility", {
            SpeciesId = "INVALID_POKEMON_999"
        })

        local response = executeHandler("get-passive-ability", msg)

        assert_equal(response.Action, "Error", "Should return Error")
        assert_not_nil(response.Error, "Should have error message")
    end)

    -- ====================================
    -- Test 5: Missing SpeciesId Parameter
    -- ====================================
    test("Get passive ability without SpeciesId", function()
        local msg = createTestMessage("GetPassiveAbility", {})

        local response = executeHandler("get-passive-ability", msg)

        assert_equal(response.Action, "Error", "Should return Error")
        assert_truthy(string.find(response.Error, "SpeciesId"), "Error should mention SpeciesId")
    end)

    -- ====================================
    -- Test 6: Unlock Passive for Player
    -- ====================================
    test("Unlock passive for player's species", function()
        local msg = createTestMessage("UnlockPassive", {
            PlayerId = "player_123",
            SpeciesId = "PIKACHU",
            Cost = "50"
        })

        local response = executeHandler("unlock-passive", msg)

        assert_equal(response.Action, "PassiveUnlocked", "Should return PassiveUnlocked")
        assert_equal(response.Success, "true", "Should succeed")
        assert_equal(response.NewTier, "0", "Should start at tier 0")
        assert_equal(response.CostApplied, "50", "Should apply cost")
    end)

    -- ====================================
    -- Test 7: Unlock Already Unlocked Passive
    -- ====================================
    test("Try to unlock already unlocked passive", function()
        -- First unlock
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_456",
            SpeciesId = "BULBASAUR",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        -- Try to unlock again
        local msg2 = createTestMessage("UnlockPassive", {
            PlayerId = "player_456",
            SpeciesId = "BULBASAUR",
            Cost = "50"
        })

        local response = executeHandler("unlock-passive", msg2)

        assert_equal(response.Action, "Error", "Should return Error")
        assert_truthy(string.find(response.Error, "already"), "Error should mention already unlocked")
    end)

    -- ====================================
    -- Test 8: Upgrade Passive Tier
    -- ====================================
    test("Upgrade passive from tier 0 to tier 1", function()
        -- First unlock
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_789",
            SpeciesId = "CHARIZARD",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        -- Then upgrade
        local msg2 = createTestMessage("UpgradePassive", {
            PlayerId = "player_789",
            SpeciesId = "CHARIZARD",
            ToTier = "1",
            Cost = "100"
        })

        local response = executeHandler("upgrade-passive", msg2)

        assert_equal(response.Action, "PassiveUnlocked", "Should return PassiveUnlocked")
        assert_equal(response.Success, "true", "Should succeed")
        assert_equal(response.NewTier, "1", "Should be tier 1")
        assert_equal(response.CostApplied, "100", "Should apply upgrade cost")
    end)

    -- ====================================
    -- Test 9: Upgrade Without Unlocking First
    -- ====================================
    test("Try to upgrade passive that isn't unlocked", function()
        local msg = createTestMessage("UpgradePassive", {
            PlayerId = "player_new",
            SpeciesId = "CHARIZARD",
            ToTier = "1",
            Cost = "100"
        })

        local response = executeHandler("upgrade-passive", msg)

        assert_equal(response.Action, "Error", "Should return Error")
        assert_truthy(string.find(response.Error, "not unlocked"), "Error should mention not unlocked")
    end)

    -- ====================================
    -- Test 10: Upgrade Beyond Max Tier
    -- ====================================
    test("Try to upgrade beyond max tier", function()
        -- Unlock first
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_999",
            SpeciesId = "BULBASAUR",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        -- Try to upgrade to tier 5 (Bulbasaur only has tier 0)
        local msg2 = createTestMessage("UpgradePassive", {
            PlayerId = "player_999",
            SpeciesId = "BULBASAUR",
            ToTier = "5",
            Cost = "100"
        })

        local response = executeHandler("upgrade-passive", msg2)

        assert_equal(response.Action, "Error", "Should return Error")
        assert_truthy(string.find(response.Error, "Max tier"), "Error should mention max tier")
    end)

    -- ====================================
    -- Test 11: Enable Passive for Pokemon
    -- ====================================
    test("Enable passive for Pokemon instance", function()
        local msg = createTestMessage("EnablePassive", {
            PokemonId = "pokemon_abc123",
            Enable = "true"
        })

        local response = executeHandler("enable-passive", msg)

        assert_equal(response.Action, "PassiveStateUpdated", "Should return PassiveStateUpdated")
        assert_equal(response.Success, "true", "Should succeed")
        assert_equal(response.PokemonId, "pokemon_abc123", "Should return Pokemon ID")
        assert_equal(response.Enabled, "true", "Should be enabled")
    end)

    -- ====================================
    -- Test 12: Disable Passive for Pokemon
    -- ====================================
    test("Disable passive for Pokemon instance", function()
        local msg = createTestMessage("EnablePassive", {
            PokemonId = "pokemon_xyz789",
            Enable = "false"
        })

        local response = executeHandler("enable-passive", msg)

        assert_equal(response.Enabled, "false", "Should be disabled")
    end)

    -- ====================================
    -- Test 13: Can Apply Passive (Unlocked and Enabled)
    -- ====================================
    test("Check if passive can be applied when unlocked and enabled", function()
        -- Unlock passive
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_apply_test",
            SpeciesId = "PIKACHU",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        -- Enable passive
        local msg2 = createTestMessage("EnablePassive", {
            PokemonId = "pokemon_apply_test",
            Enable = "true"
        })
        executeHandler("enable-passive", msg2)

        -- Check if can apply
        local msg3 = createTestMessage("CanApplyPassive", {
            PokemonId = "pokemon_apply_test",
            PlayerId = "player_apply_test",
            SpeciesId = "PIKACHU"
        })

        local response = executeHandler("can-apply-passive", msg3)

        assert_equal(response.Action, "PassiveApplicationResult", "Should return PassiveApplicationResult")
        assert_equal(response.CanApply, "true", "Should be able to apply")
    end)

    -- ====================================
    -- Test 14: Can Apply Passive (Not Unlocked)
    -- ====================================
    test("Check if passive can be applied when not unlocked", function()
        local msg = createTestMessage("CanApplyPassive", {
            PokemonId = "pokemon_not_unlocked",
            PlayerId = "player_not_unlocked",
            SpeciesId = "MEWTWO"
        })

        local response = executeHandler("can-apply-passive", msg)

        assert_equal(response.CanApply, "false", "Should not be able to apply")
        assert_truthy(response.BlockedReason, "Should have blocked reason")
    end)

    -- ====================================
    -- Test 15: Calculate Passive Effect
    -- ====================================
    test("Calculate passive effect for enabled passive", function()
        -- First unlock and enable a passive
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_effect_calc",
            SpeciesId = "CHARIZARD",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        local msg2 = createTestMessage("EnablePassive", {
            PokemonId = "pokemon_effect_test",
            Enable = "true"
        })
        executeHandler("enable-passive", msg2)

        -- Calculate passive effect
        local msg3 = createTestMessage("CalculatePassiveEffect", {
            PokemonId = "pokemon_effect_test",
            PlayerId = "player_effect_calc",
            SpeciesId = "CHARIZARD",
            AbilityId = "BEAST_BOOST",
            Data = json.encode({
                event = "defeated_opponent",
                battleContext = {}
            })
        })

        local response = executeHandler("calculate-passive-effect", msg3)

        assert_equal(response.Action, "PassiveEffectResult", "Should return PassiveEffectResult")
        assert_equal(response.Success, "true", "Should succeed")
        assert_not_nil(response.AbilityId, "Should have ability ID")
        assert_equal(response.TriggerEvent, "defeated_opponent", "Should match trigger event")
    end)

    -- ====================================
    -- Test 16: Calculate Passive Effect (Not Enabled)
    -- ====================================
    test("Calculate passive effect fails when passive not enabled", function()
        local msg = createTestMessage("CalculatePassiveEffect", {
            PokemonId = "pokemon_not_enabled",
            PlayerId = "player_not_enabled",
            SpeciesId = "BULBASAUR",
            Data = json.encode({
                event = "on_switch_in",
                battleContext = {}
            })
        })

        local response = executeHandler("calculate-passive-effect", msg)

        assert_equal(response.Action, "Error", "Should return error")
        assert_not_nil(response.Error, "Should have error message")
    end)

    -- ====================================
    -- Test 17: Check Ability Stacking
    -- ====================================
    test("Check if passive and active abilities can stack", function()
        local msg = createTestMessage("CheckAbilityStacking", {
            PassiveAbilityId = "BEAST_BOOST",
            ActiveAbilityId = "LEVITATE",
            Data = json.encode({})
        })

        local response = executeHandler("check-ability-stacking", msg)

        assert_equal(response.Action, "AbilityStackingResult", "Should return AbilityStackingResult")
        assert_equal(response.Success, "true", "Should succeed")
        assert_equal(response.CanStack, "true", "Different abilities should stack")
    end)

    -- ====================================
    -- Test 18: Check Ability Stacking (Same Ability)
    -- ====================================
    test("Check ability stacking fails for same ability", function()
        local msg = createTestMessage("CheckAbilityStacking", {
            PassiveAbilityId = "BEAST_BOOST",
            ActiveAbilityId = "BEAST_BOOST",
            Data = json.encode({})
        })

        local response = executeHandler("check-ability-stacking", msg)

        assert_equal(response.Action, "AbilityStackingResult", "Should return AbilityStackingResult")
        assert_equal(response.CanStack, "false", "Same ability should not stack")
        assert_not_nil(response.BlockedReason, "Should have blocked reason")
    end)

    -- ====================================
    -- Test 19: Get Passive Ability Priority
    -- ====================================
    test("Get passive ability priority for battle coordination", function()
        -- Unlock passive first
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_priority",
            SpeciesId = "BULBASAUR",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        -- Get priority
        local msg2 = createTestMessage("GetPassivePriority", {
            SpeciesId = "BULBASAUR",
            PlayerId = "player_priority"
        })

        local response = executeHandler("get-passive-priority", msg2)

        assert_equal(response.Action, "PassivePriorityResult", "Should return PassivePriorityResult")
        assert_equal(response.Success, "true", "Should succeed")
        assert_not_nil(response.AbilityId, "Should have ability ID")
        assert_not_nil(response.Priority, "Should have priority value")
        assert_not_nil(response.Tier, "Should have tier value")
    end)

    -- ====================================
    -- Test 20: Calculate Passive Effect (Missing Trigger Context)
    -- ====================================
    test("Calculate passive effect fails without trigger context", function()
        local msg = createTestMessage("CalculatePassiveEffect", {
            PokemonId = "pokemon_no_context",
            PlayerId = "player_no_context",
            SpeciesId = "PIKACHU",
            Data = json.encode({}) -- Missing event field
        })

        local response = executeHandler("calculate-passive-effect", msg)

        assert_equal(response.Action, "Error", "Should return error")
        assert_truthy(response.Error:find("TriggerContext"), "Error should mention TriggerContext")
    end)

    -- ====================================
    -- Test 21: Get Player Passives
    -- ====================================
    test("Get all passives for player", function()
        -- Unlock a couple passives for player
        local msg1 = createTestMessage("UnlockPassive", {
            PlayerId = "player_multi",
            SpeciesId = "BULBASAUR",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg1)

        local msg2 = createTestMessage("UnlockPassive", {
            PlayerId = "player_multi",
            SpeciesId = "CHARIZARD",
            Cost = "50"
        })
        executeHandler("unlock-passive", msg2)

        -- Get player passives
        local msg3 = createTestMessage("GetPlayerPassives", {
            PlayerId = "player_multi"
        })

        local response = executeHandler("get-player-passives", msg3)

        assert_equal(response.Action, "PlayerPassiveData", "Should return PlayerPassiveData")
        assert_equal(response.Success, "true", "Should succeed")
        assert_not_nil(response.Data, "Should have data")
    end)

    -- ====================================
    -- Test 22: Info Handler (ADP v1.0)
    -- ====================================
    test("Get process info (ADP compliance)", function()
        local msg = createTestMessage("Info", {})

        local response = executeHandler("info", msg)

        assert_equal(response.Action, "InfoResponse", "Should return InfoResponse")
        assert_equal(response.Success, "true", "Should succeed")
        assert_not_nil(response.Data, "Should have process info data")
    end)

    -- ====================================
    -- Test 23: Health Check Handler
    -- ====================================
    test("Health check responds correctly", function()
        local msg = createTestMessage("HealthCheck", {})

        local response = executeHandler("health-check", msg)

        assert_equal(response.Action, "HealthCheckResponse", "Should return HealthCheckResponse")
        assert_equal(response.Status, "healthy", "Should be healthy")
        assert_not_nil(response.SpeciesWithPassives, "Should report species count")
    end)

    -- Print test summary
    print("\n" .. string.rep("=", 60))
    print("TEST SUMMARY")
    print(string.rep("=", 60))
    print(string.format("Total Tests: %d", totalTests))
    print(string.format("✅ Passed: %d", passedTests))
    print(string.format("❌ Failed: %d", failedTests))
    print(string.format("Success Rate: %.1f%%", (passedTests / totalTests) * 100))
    print(string.rep("=", 60))

    return passedTests == totalTests
end

-- ====================================
-- MAIN EXECUTION
-- ====================================

print("\n🧪 Starting Passive Ability Engine Unit Tests")
print(string.rep("=", 60))

-- Load the process
local success, error = pcall(loadPassiveAbilityEngineProcess)
if not success then
    print("❌ Failed to load process: " .. tostring(error))
    os.exit(1)
end

-- Run all tests
local allTestsPassed = runTests()

-- Exit with appropriate code
if allTestsPassed then
    print("\n✅ All unit tests passed!")
    os.exit(0)
else
    print("\n❌ Some tests failed")
    os.exit(1)
end