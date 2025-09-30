-- Unit tests for Voucher Reward Engine Process
-- Tests voucher award logic, validation, inventory management, and metadata queries
-- Uses AO message-based testing pattern compatible with AO runtime

-- Mock AO environment for testing
local ao = {
    send = function(msg)
        -- Store the message for test verification
        table.insert(_G.testResults or {}, msg)
        return msg
    end,
    id = "voucher_reward_engine_unit_test"
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
            -- Simple JSON encoding for testing
            local result = "{"
            local first = true
            for k, v in pairs(data) do
                if not first then result = result .. "," end
                local key = '"' .. tostring(k) .. '"'
                local value
                if type(v) == "string" then
                    value = '"' .. v .. '"'
                elseif type(v) == "table" then
                    value = json.encode(v)
                else
                    value = tostring(v)
                end
                result = result .. key .. ":" .. value
                first = false
            end
            return result .. "}"
        end
        return tostring(data)
    end,
    decode = function(str)
        if str == '{}' or str == '' then return {} end
        -- For testing, we'll parse simple JSON
        -- In real scenarios, this would be handled by AO's json module
        local result = {}
        -- Very basic parsing for test data
        if str:match('"voucherUnlocks"') then
            result.voucherUnlocks = {}
            result.voucherCounts = {[0] = 0, [1] = 0, [2] = 0, [3] = 0}
            result.totalVouchersAwarded = 0
            result.totalVouchersAvailable = 0
        end
        return result
    end
}

-- Set up global AO environment
_G.ao = ao
_G.Handlers = Handlers
_G.json = json
_G.testResults = {}

-- Mock require('json') for the process
package.loaded['json'] = json

-- Load voucher reward engine process by executing it
local function loadVoucherRewardEngine()
    local success, err = pcall(dofile, "processes/voucher-reward-engine.lua")
    if not success then
        print("❌ Failed to load voucher-reward-engine.lua: " .. tostring(err))
        os.exit(1)
    end
    return true
end

-- Test helper: Execute handler and get response
local function executeHandler(handlerName, msg)
    _G.testResults = {}  -- Clear previous results
    local handler = _G.testHandlers[handlerName]
    if not handler then
        error("Handler not found: " .. handlerName)
    end
    handler.handler(msg)
    return _G.testResults[#_G.testResults]  -- Return last sent message
end

-- Test helper: Assert equals
local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\nExpected: %s\nActual: %s", message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

-- Test helper: Assert not nil
local function assertNotNil(value, message)
    if value == nil then
        error(message or "Value should not be nil")
    end
end

-- Test helper: Assert true
local function assertTrue(condition, message)
    if not condition then
        error(message or "Condition should be true")
    end
end

print("Running Voucher Reward Engine Unit Tests...")
print("===================================================\n")

-- Load the process
loadVoucherRewardEngine()
print("✓ Voucher Reward Engine loaded successfully\n")

-- Track test results
local testsRun = 0
local testsPassed = 0
local testsFailed = 0

local function runTest(testName, testFunc)
    testsRun = testsRun + 1
    io.write("Running: " .. testName .. "...")
    local success, err = pcall(testFunc)
    if success then
        testsPassed = testsPassed + 1
        print(" ✓")
    else
        testsFailed = testsFailed + 1
        print(" ❌")
        print("  Error: " .. tostring(err))
    end
end

-- ========================================================================
-- Test 1: Achievement Voucher Generation
-- ========================================================================

runTest("test_classic_victory_voucher_metadata", function()
    local response = executeHandler("get-voucher-metadata", {
        From = "test_sender",
        Action = "GetVoucherMetadata",
        VoucherId = "CLASSIC_VICTORY",
        Timestamp = "1000000"
    })

    assertEquals(response.Action, "VoucherMetadata", "Should return VoucherMetadata action")
    assertNotNil(response.Data, "Should have Data field")
end)

-- ========================================================================
-- Test 2: Boss Trainer Voucher Generation
-- ========================================================================

runTest("test_gym_leader_brock_metadata", function()
    local response = executeHandler("get-voucher-metadata", {
        From = "test_sender",
        Action = "GetVoucherMetadata",
        VoucherId = "GYM_LEADER_BROCK",
        Timestamp = "1000000"
    })

    assertEquals(response.Action, "VoucherMetadata", "Should return VoucherMetadata action")
    assertNotNil(response.Data, "Should have Data field")
end)

runTest("test_elite_four_metadata", function()
    local response = executeHandler("get-voucher-metadata", {
        From = "test_sender",
        Action = "GetVoucherMetadata",
        VoucherId = "ELITE_FOUR_LANCE",
        Timestamp = "1000000"
    })

    assertEquals(response.Action, "VoucherMetadata", "Should return VoucherMetadata action")
end)

-- ========================================================================
-- Test 3: Voucher Award Logic
-- ========================================================================

runTest("test_award_voucher_first_time", function()
    local response = executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_test1",
        VoucherId = "CLASSIC_VICTORY",
        Source = "Achievement",
        Timestamp = "1234567890000"
    })

    assertEquals(response.Action, "VoucherAwarded", "Should return VoucherAwarded action")
    assertEquals(response.Success, "true", "Should be successful")
    assertEquals(response.AlreadyAwarded, "false", "Should not be already awarded")
    assertEquals(response.VoucherId, "CLASSIC_VICTORY", "Should return correct voucher ID")
    assertEquals(response.NewCount, "1", "Should increment count to 1")
end)

runTest("test_award_voucher_duplicate", function()
    -- First award
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_test2",
        VoucherId = "GYM_LEADER_BROCK",
        Source = "BossTrainer",
        Timestamp = "1000000"
    })

    -- Second award (duplicate)
    local response = executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_test2",
        VoucherId = "GYM_LEADER_BROCK",
        Source = "BossTrainer",
        Timestamp = "1000001"
    })

    assertEquals(response.Success, "false", "Should not be successful")
    assertEquals(response.AlreadyAwarded, "true", "Should be already awarded")
    assertEquals(response.AwardTimestamp, "1000000", "Should return original timestamp")
end)

runTest("test_award_invalid_voucher", function()
    local response = executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_test3",
        VoucherId = "INVALID_VOUCHER",
        Source = "Achievement",
        Timestamp = "1000000"
    })

    assertEquals(response.Action, "Error", "Should return Error action")
    assertNotNil(response.Error, "Should have error message")
end)

runTest("test_award_missing_player_id", function()
    local response = executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        VoucherId = "CLASSIC_VICTORY",
        Source = "Achievement",
        Timestamp = "1000000"
    })

    assertEquals(response.Action, "Error", "Should return Error action")
end)

-- ========================================================================
-- Test 4: Voucher Validation
-- ========================================================================

runTest("test_validate_awarded_voucher", function()
    -- Award voucher first
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_validation",
        VoucherId = "GYM_LEADER_MISTY",
        Source = "BossTrainer",
        Timestamp = "2000000"
    })

    -- Validate
    local response = executeHandler("validate-voucher", {
        From = "test_sender",
        Action = "ValidateVoucher",
        PlayerId = "player_validation",
        VoucherId = "GYM_LEADER_MISTY",
        Timestamp = "2000001"
    })

    assertEquals(response.Action, "VoucherValidated", "Should return VoucherValidated action")
    assertEquals(response.IsAwarded, "true", "Should be awarded")
    assertEquals(response.AwardTimestamp, "2000000", "Should return award timestamp")
end)

runTest("test_validate_not_awarded_voucher", function()
    local response = executeHandler("validate-voucher", {
        From = "test_sender",
        Action = "ValidateVoucher",
        PlayerId = "player_not_awarded",
        VoucherId = "GYM_LEADER_ERIKA",
        Timestamp = "1000000"
    })

    assertEquals(response.Action, "VoucherValidated", "Should return VoucherValidated action")
    assertEquals(response.IsAwarded, "false", "Should not be awarded")
    assertEquals(response.AwardTimestamp, "", "Should have empty timestamp")
end)

-- ========================================================================
-- Test 5: Inventory Management
-- ========================================================================

runTest("test_multiple_voucher_types", function()
    -- Award GOLDEN voucher
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_inventory",
        VoucherId = "CLASSIC_VICTORY",
        Source = "Achievement",
        Timestamp = "3000000"
    })

    -- Award PLUS vouchers
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_inventory",
        VoucherId = "GYM_LEADER_BROCK",
        Source = "BossTrainer",
        Timestamp = "3000001"
    })

    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_inventory",
        VoucherId = "GYM_LEADER_MISTY",
        Source = "BossTrainer",
        Timestamp = "3000002"
    })

    -- Get voucher data
    local response = executeHandler("get-player-vouchers", {
        From = "test_sender",
        Action = "GetPlayerVouchers",
        PlayerId = "player_inventory",
        Timestamp = "3000003"
    })

    assertEquals(response.Action, "PlayerVoucherData", "Should return PlayerVoucherData action")
    assertNotNil(response.Data, "Should have Data field")
end)

runTest("test_consume_voucher", function()
    -- Award vouchers
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_consume",
        VoucherId = "GYM_LEADER_SABRINA",
        Source = "BossTrainer",
        Timestamp = "4000000"
    })

    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_consume",
        VoucherId = "GYM_LEADER_BLAINE",
        Source = "BossTrainer",
        Timestamp = "4000001"
    })

    -- Consume one PLUS voucher
    local response = executeHandler("consume-voucher", {
        From = "test_sender",
        Action = "ConsumeVoucher",
        PlayerId = "player_consume",
        VoucherType = "1",  -- PLUS
        Quantity = "1",
        Timestamp = "4000002"
    })

    assertEquals(response.Action, "VoucherConsumed", "Should return VoucherConsumed action")
    assertEquals(response.Success, "true", "Should be successful")
    assertEquals(response.RemainingCount, "1", "Should have 1 remaining")
end)

runTest("test_consume_insufficient_vouchers", function()
    -- Award only 1 voucher
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_insufficient",
        VoucherId = "GYM_LEADER_GIOVANNI",
        Source = "BossTrainer",
        Timestamp = "5000000"
    })

    -- Try to consume 2
    local response = executeHandler("consume-voucher", {
        From = "test_sender",
        Action = "ConsumeVoucher",
        PlayerId = "player_insufficient",
        VoucherType = "1",  -- PLUS
        Quantity = "2",
        Timestamp = "5000001"
    })

    assertEquals(response.Action, "Error", "Should return Error action")
    assertNotNil(response.Error, "Should have error message")
end)

runTest("test_consume_zero_quantity", function()
    local response = executeHandler("consume-voucher", {
        From = "test_sender",
        Action = "ConsumeVoucher",
        PlayerId = "player_zero",
        VoucherType = "1",
        Quantity = "0",
        Timestamp = "5000002"
    })

    assertEquals(response.Action, "Error", "Should return Error action")
end)

-- ========================================================================
-- Test 6: Metadata Queries
-- ========================================================================

runTest("test_get_player_vouchers_with_metadata", function()
    -- Award a voucher
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_metadata",
        VoucherId = "CLASSIC_VICTORY",
        Source = "Achievement",
        Timestamp = "6000000"
    })

    -- Get with metadata
    local response = executeHandler("get-player-vouchers", {
        From = "test_sender",
        Action = "GetPlayerVouchers",
        PlayerId = "player_metadata",
        IncludeMetadata = "true",
        Timestamp = "6000001"
    })

    assertEquals(response.Action, "PlayerVoucherData", "Should return PlayerVoucherData action")
    assertNotNil(response.Data, "Should have Data field")
end)

runTest("test_get_all_vouchers_metadata", function()
    local response = executeHandler("get-voucher-metadata", {
        From = "test_sender",
        Action = "GetVoucherMetadata",
        Timestamp = "6000002"
    })

    assertEquals(response.Action, "VoucherMetadata", "Should return VoucherMetadata action")
    assertNotNil(response.Data, "Should have Data field")
end)

-- ========================================================================
-- Test 7: ADP Info Handler
-- ========================================================================

runTest("test_adp_info_handler", function()
    local response = executeHandler("info", {
        From = "test_sender",
        Action = "Info",
        Timestamp = "7000000"
    })

    assertEquals(response.Action, "SaveState", "Should return SaveState action")
    assertNotNil(response.Data, "Should have Data field")
end)

-- ========================================================================
-- Test 8: Player Isolation
-- ========================================================================

runTest("test_player_voucher_isolation", function()
    -- Award to player 1
    executeHandler("award-voucher", {
        From = "test_sender",
        Action = "AwardVoucher",
        PlayerId = "player_isolation_1",
        VoucherId = "CLASSIC_VICTORY",
        Source = "Achievement",
        Timestamp = "8000000"
    })

    -- Check player 2 (should have no vouchers)
    local response = executeHandler("get-player-vouchers", {
        From = "test_sender",
        Action = "GetPlayerVouchers",
        PlayerId = "player_isolation_2",
        Timestamp = "8000001"
    })

    assertEquals(response.Action, "PlayerVoucherData", "Should return PlayerVoucherData action")
    -- Player 2 should have empty voucher state
end)

-- ========================================================================
-- Print Summary
-- ========================================================================

print("\n==================================================")
print("Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. testsRun)
print()

if testsFailed == 0 then
    print("🎉 All tests passed!")
    os.exit(0)
else
    print("❌ Some tests failed")
    os.exit(1)
end
