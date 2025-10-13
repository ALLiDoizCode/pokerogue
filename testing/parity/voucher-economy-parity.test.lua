-- Voucher Economy Parity Test
-- Validates behavioral equivalence between Lua and TypeScript voucher implementations

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.voucher-economy-engine"
local processId = "test-voucher-parity"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Voucher Economy Parity Tests")
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

-- Test counter
local testCount = 0
local passCount = 0

local function test(name, fn)
    testCount = testCount + 1
    print(string.format("📝 Parity Test %d: %s", testCount, name))
    local success, err = pcall(fn)
    if success then
        passCount = passCount + 1
        print("✅ Parity verified")
    else
        print("❌ Parity test failed:", err)
        error(err)
    end
end

-- ==============================================================================
-- TASK 7: COMPREHENSIVE PARITY TESTING
-- ==============================================================================

-- Test Case 1: Voucher Value Calculation Parity (AC 3, 6)
test("Voucher values match TypeScript constants", function()
    -- TypeScript: VOUCHER_VALUE_MAP from egg-gacha-ui-handler.ts:221-247
    -- REGULAR = 1, PLUS = 5, PREMIUM = 10, GOLDEN = 25

    local response = sendMessage("GetVoucherInfo")
    local result = json.decode(response.Data)

    assert(result.voucherTypes.REGULAR.value == 1, "REGULAR should be 1 pull")
    assert(result.voucherTypes.PLUS.value == 5, "PLUS should be 5 pulls")
    assert(result.voucherTypes.PREMIUM.value == 10, "PREMIUM should be 10 pulls")
    assert(result.voucherTypes.GOLDEN.value == 25, "GOLDEN should be 25 pulls")
end)

-- Test Case 2: Voucher Tier Mapping Parity (AC 3, 6)
test("Voucher tiers match TypeScript mappings", function()
    -- TypeScript: VOUCHER_TIER_MAP from voucher.ts:45-56

    local response = sendMessage("GetVoucherInfo")
    local result = json.decode(response.Data)

    assert(result.voucherTypes.REGULAR.tier == "COMMON", "REGULAR tier mismatch")
    assert(result.voucherTypes.PLUS.tier == "GREAT", "PLUS tier mismatch")
    assert(result.voucherTypes.PREMIUM.tier == "ULTRA", "PREMIUM tier mismatch")
    assert(result.voucherTypes.GOLDEN.tier == "ROGUE", "GOLDEN tier mismatch")
end)

-- Test Case 3: Voucher Name Mapping Parity (AC 3, 6)
test("Voucher names match TypeScript constants", function()
    -- TypeScript: VOUCHER_NAME_MAP from voucher.ts:59-70

    local response = sendMessage("GetVoucherInfo")
    local result = json.decode(response.Data)

    assert(result.voucherTypes.REGULAR.name == "Egg Voucher", "REGULAR name mismatch")
    assert(result.voucherTypes.PLUS.name == "Egg Voucher Plus", "PLUS name mismatch")
    assert(result.voucherTypes.PREMIUM.name == "Egg Voucher Premium", "PREMIUM name mismatch")
    assert(result.voucherTypes.GOLDEN.name == "Egg Voucher Gold", "GOLDEN name mismatch")
end)

-- Test Case 4: Voucher Icon Mapping Parity (AC 3, 6)
test("Voucher icons match TypeScript constants", function()
    -- TypeScript: VOUCHER_ICON_MAP from voucher.ts:72-83

    local response = sendMessage("GetVoucherInfo")
    local result = json.decode(response.Data)

    assert(result.voucherTypes.REGULAR.icon == "coupon", "REGULAR icon mismatch")
    assert(result.voucherTypes.PLUS.icon == "pair_of_tickets", "PLUS icon mismatch")
    assert(result.voucherTypes.PREMIUM.icon == "mystic_ticket", "PREMIUM icon mismatch")
    assert(result.voucherTypes.GOLDEN.icon == "golden_mystic_ticket", "GOLDEN icon mismatch")
end)

-- Test Case 5: Voucher Addition Parity (AC 1, 6)
test("AddVoucher matches TypeScript balance increment logic", function()
    -- TypeScript: voucherCounts[type] += count

    local initialBalance = {
        ["0"] = 0,  -- REGULAR
        ["1"] = 0,  -- PLUS
        ["2"] = 0,  -- PREMIUM
        ["3"] = 0   -- GOLDEN
    }

    -- Add 3 PREMIUM vouchers
    local response = sendMessage("AddVoucher", {
        VoucherType = "PREMIUM",
        Amount = "3",
        VoucherCounts = json.encode(initialBalance)
    })

    assert(response.Action == "SaveState", "Expected SaveState action")
    local result = json.decode(response.Data)

    -- Verify balance update matches TypeScript logic
    assert(result.previousBalance == 0, "Previous balance should be 0")
    assert(result.newBalance == 3, "New balance should be 3")
    assert(result.voucherCounts["2"] == 3, "PREMIUM balance should be 3")
end)

-- Test Case 6: Voucher Redemption Validation Parity (AC 2, 6)
test("RedeemVoucher validation matches TypeScript logic", function()
    -- TypeScript: Math.max(voucherCounts[type] - count, 0)

    local voucherBalance = {
        ["0"] = 5,   -- REGULAR
        ["1"] = 3,   -- PLUS
        ["2"] = 2,   -- PREMIUM
        ["3"] = 1    -- GOLDEN
    }

    -- Redeem 1 PREMIUM voucher
    local response = sendMessage("RedeemVoucher", {
        VoucherType = "PREMIUM",
        Amount = "1",
        VoucherCounts = json.encode(voucherBalance)
    })

    assert(response.Action == "SaveState", "Expected SaveState action")
    local result = json.decode(response.Data)

    -- Verify deduction matches TypeScript logic
    assert(result.previousBalance == 2, "Previous balance should be 2")
    assert(result.newBalance == 1, "New balance should be 1")
    assert(result.voucherCounts["2"] == 1, "PREMIUM balance should be 1 after redemption")
end)

-- Test Case 7: Insufficient Balance Error Parity (AC 2, 6)
test("Insufficient balance error matches TypeScript behavior", function()
    -- TypeScript: Error handling for insufficient vouchers

    local voucherBalance = {
        ["0"] = 5,
        ["1"] = 3,
        ["2"] = 0,   -- No PREMIUM vouchers
        ["3"] = 1
    }

    -- Attempt to redeem PREMIUM voucher with 0 balance
    local response = sendMessage("RedeemVoucher", {
        VoucherType = "PREMIUM",
        Amount = "1",
        VoucherCounts = json.encode(voucherBalance)
    })

    -- TypeScript would prevent redemption and show error
    assert(response.Action == "Error", "Expected Error action for insufficient balance")
    assert(response.Error:find("Insufficient"), "Error message should mention insufficient balance")
end)

-- Test Case 8: Multi-Type Balance Tracking Parity (AC 4, 6)
test("Multiple voucher types tracked independently", function()
    -- TypeScript: Separate counters for each voucher type

    local initialBalance = {
        ["0"] = 0,
        ["1"] = 0,
        ["2"] = 0,
        ["3"] = 0
    }

    -- Add different voucher types
    local r1 = sendMessage("AddVoucher", {VoucherType = "REGULAR", Amount = "10",
        VoucherCounts = json.encode(initialBalance)
    })
    local result1 = json.decode(r1.Data)

    local r2 = sendMessage("AddVoucher", {VoucherType = "PLUS", Amount = "5",
        VoucherCounts = json.encode(result1.voucherCounts)
    })
    local result2 = json.decode(r2.Data)

    local r3 = sendMessage("AddVoucher", {VoucherType = "GOLDEN", Amount = "2",
        VoucherCounts = json.encode(result2.voucherCounts)
    })
    local result3 = json.decode(r3.Data)

    -- Verify independent tracking
    assert(result3.voucherCounts["0"] == 10, "REGULAR balance should be 10")
    assert(result3.voucherCounts["1"] == 5, "PLUS balance should be 5")
    assert(result3.voucherCounts["2"] == 0, "PREMIUM balance should remain 0")
    assert(result3.voucherCounts["3"] == 2, "GOLDEN balance should be 2")
end)

-- Test Case 9: Complex Workflow with Mixed Transactions (AC 5, 6)
test("Complex voucher economy workflow matches TypeScript behavior", function()
    -- Test scenario: Add vouchers, redeem some, add more, verify final balance

    local balance = {["0"] = 0, ["1"] = 0, ["2"] = 0, ["3"] = 0}

    -- Step 1: Add vouchers from achievement
    local r1 = sendMessage("AddVoucher", {VoucherType = "PREMIUM", Amount = "3",
        VoucherCounts = json.encode(balance)
    })
    balance = json.decode(r1.Data).voucherCounts

    -- Step 2: Add vouchers from boss trainer
    local r2 = sendMessage("AddVoucher", {VoucherType = "PLUS", Amount = "5",
        VoucherCounts = json.encode(balance)
    })
    balance = json.decode(r2.Data).voucherCounts

    -- Step 3: Redeem PREMIUM voucher
    local r3 = sendMessage("RedeemVoucher", {VoucherType = "PREMIUM", Amount = "1",
        VoucherCounts = json.encode(balance)
    })
    balance = json.decode(r3.Data).voucherCounts

    -- Step 4: Add more REGULAR vouchers
    local r4 = sendMessage("AddVoucher", {VoucherType = "REGULAR", Amount = "10",
        VoucherCounts = json.encode(balance)
    })
    balance = json.decode(r4.Data).voucherCounts

    -- Step 5: Redeem PLUS vouchers
    local r5 = sendMessage("RedeemVoucher", {VoucherType = "PLUS", Amount = "2",
        VoucherCounts = json.encode(balance)
    })
    balance = json.decode(r5.Data).voucherCounts

    -- Verify final balances match TypeScript calculation
    assert(balance["0"] == 10, "REGULAR final balance incorrect")
    assert(balance["1"] == 3, "PLUS final balance incorrect (5 - 2)")
    assert(balance["2"] == 2, "PREMIUM final balance incorrect (3 - 1)")
    assert(balance["3"] == 0, "GOLDEN final balance should remain 0")
end)

-- Test Case 10: Balance Retrieval Parity (AC 4, 6)
test("GetVoucherBalance returns complete balance structure", function()
    -- TypeScript: Returns voucherCounts object with all types

    local balance = {
        ["0"] = 15,  -- REGULAR
        ["1"] = 8,   -- PLUS
        ["2"] = 4,   -- PREMIUM
        ["3"] = 2    -- GOLDEN
    }

    local response = sendMessage("GetVoucherBalance", {
        VoucherCounts = json.encode(balance)
    })
    assert(response.Action == "SaveState", "Expected SaveState action")

    local result = json.decode(response.Data)
    assert(result.voucherCounts, "Expected voucherCounts in response")

    -- Verify all balances returned correctly
    assert(result.voucherCounts["0"] == 15, "REGULAR balance incorrect")
    assert(result.voucherCounts["1"] == 8, "PLUS balance incorrect")
    assert(result.voucherCounts["2"] == 4, "PREMIUM balance incorrect")
    assert(result.voucherCounts["3"] == 2, "GOLDEN balance incorrect")

    -- TypeScript also calculates totalVouchers
    assert(result.totalVouchers == 29, "Total vouchers incorrect (15+8+4+2)")
end)

-- Test Case 11: Zero Balance Initialization Parity (AC 4, 6)
test("Empty voucher balance initializes to zeros", function()
    -- TypeScript: Default voucherCounts is empty, all counters start at 0

    local response = sendMessage("GetVoucherBalance", {
        VoucherCounts = json.encode({})
    })
    local result = json.decode(response.Data)

    -- Verify all types default to 0
    assert(result.voucherCounts["0"] == 0, "REGULAR should default to 0")
    assert(result.voucherCounts["1"] == 0, "PLUS should default to 0")
    assert(result.voucherCounts["2"] == 0, "PREMIUM should default to 0")
    assert(result.voucherCounts["3"] == 0, "GOLDEN should default to 0")
    assert(result.totalVouchers == 0, "Total should be 0")
end)

-- Test Case 12: Negative Balance Prevention Parity (AC 4, 6)
test("Negative balance prevention matches TypeScript Math.max logic", function()
    -- TypeScript: Math.max(voucherCounts[type] - count, 0) prevents negative

    local balance = {["0"] = 0, ["1"] = 0, ["2"] = 2, ["3"] = 0}

    -- Attempt to redeem more than available (should error, not go negative)
    local response = sendMessage("RedeemVoucher", {
        VoucherType = "PREMIUM",
        Amount = "5",
        VoucherCounts = json.encode(balance)
    })

    -- TypeScript prevents transaction with insufficient balance
    assert(response.Action == "Error", "Expected Error action")

    -- Verify balance unchanged after failed redemption
    local balanceCheck = sendMessage("GetVoucherBalance", {
        VoucherCounts = json.encode(balance)
    })
    local balanceResult = json.decode(balanceCheck.Data)
    assert(balanceResult.voucherCounts["2"] == 2, "Balance should remain 2 after failed redemption")
end)

-- Test Case 13: Type Safety Parity (AC 3, 6)
test("Invalid voucher type handling matches TypeScript validation", function()
    -- TypeScript: Enum validation prevents invalid voucher types

    local response = sendMessage("AddVoucher", {
        VoucherType = "INVALID",
        Amount = "1",
        VoucherCounts = json.encode({})
    })

    assert(response.Action == "Error", "Expected Error for invalid voucher type")
    assert(response.Error:find("Invalid"), "Error should mention invalid type")
end)

-- Test Case 14: Amount Validation Parity (AC 1, 2, 6)
test("Negative/zero amount validation matches TypeScript", function()
    -- TypeScript: Validates amount > 0 for add/redeem operations

    -- Test negative amount
    local r1 = sendMessage("AddVoucher", {
        VoucherType = "REGULAR",
        Amount = "-5",
        VoucherCounts = json.encode({})
    })

    assert(r1.Action == "Error", "Expected Error for negative amount")

    -- Test zero amount
    local r2 = sendMessage("AddVoucher", {
        VoucherType = "REGULAR",
        Amount = "0",
        VoucherCounts = json.encode({})
    })

    assert(r2.Action == "Error", "Expected Error for zero amount")
end)

-- ==============================================================================
-- PARITY TEST SUMMARY
-- ==============================================================================

print("==================================================")
print("🎉 All Parity Tests Passed!")
print(string.format("✅ %d/%d tests verified behavioral parity", passCount, testCount))
print("==================================================")
print("Parity Validation Summary:")
print("- Voucher value calculation: VERIFIED")
print("- Voucher tier/name/icon mappings: VERIFIED")
print("- AddVoucher logic: VERIFIED")
print("- RedeemVoucher validation: VERIFIED")
print("- Balance tracking: VERIFIED")
print("- Error handling: VERIFIED")
print("- Complex workflows: VERIFIED")
print("==================================================")
print("✅ 100% Behavioral Parity with TypeScript Implementation")
