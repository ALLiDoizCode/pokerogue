-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.voucher-economy-engine"
local processId = "test-voucher-economy"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Voucher Economy Engine")
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
    print(string.format("📝 Test %d: %s", testCount, name))
    local success, err = pcall(fn)
    if success then
        passCount = passCount + 1
        print("✅ Test passed")
    else
        print("❌ Test failed:", err)
        error(err)
    end
end

-- ==============================================================================
-- TASK 3: Voucher Type and Value Core Logic Tests
-- ==============================================================================

test("GetVoucherInfo returns all voucher types", function()
    local response = sendMessage("GetVoucherInfo")

    assert(response.Action == "SaveState", "Expected SaveState action")
    assert(response.Success == "true", "Expected Success=true")

    local result = json.decode(response.Data)
    assert(result.voucherTypes, "Expected voucherTypes in response")

    -- Verify all 4 voucher types present
    assert(result.voucherTypes.REGULAR, "Expected REGULAR type")
    assert(result.voucherTypes.PLUS, "Expected PLUS type")
    assert(result.voucherTypes.PREMIUM, "Expected PREMIUM type")
    assert(result.voucherTypes.GOLDEN, "Expected GOLDEN type")
end)

test("GetVoucherInfo REGULAR type has correct mappings", function()
    local response = sendMessage("GetVoucherInfo", {VoucherType = "REGULAR"})

    local result = json.decode(response.Data)
    assert(result.voucherType == "REGULAR", "Expected REGULAR type")
    assert(result.typeValue == 0, "Expected typeValue 0")
    assert(result.tier == "COMMON", "Expected COMMON tier")
    assert(result.name == "Egg Voucher", "Expected 'Egg Voucher' name")
    assert(result.icon == "coupon", "Expected 'coupon' icon")
    assert(result.value == 1, "Expected value 1 pull")
end)

test("GetVoucherInfo PLUS type has correct mappings", function()
    local response = sendMessage("GetVoucherInfo", {VoucherType = "PLUS"})

    local result = json.decode(response.Data)
    assert(result.voucherType == "PLUS", "Expected PLUS type")
    assert(result.typeValue == 1, "Expected typeValue 1")
    assert(result.tier == "GREAT", "Expected GREAT tier")
    assert(result.name == "Egg Voucher Plus", "Expected 'Egg Voucher Plus' name")
    assert(result.icon == "pair_of_tickets", "Expected 'pair_of_tickets' icon")
    assert(result.value == 5, "Expected value 5 pulls")
end)

test("GetVoucherInfo PREMIUM type has correct mappings", function()
    local response = sendMessage("GetVoucherInfo", {VoucherType = "PREMIUM"})

    local result = json.decode(response.Data)
    assert(result.voucherType == "PREMIUM", "Expected PREMIUM type")
    assert(result.typeValue == 2, "Expected typeValue 2")
    assert(result.tier == "ULTRA", "Expected ULTRA tier")
    assert(result.name == "Egg Voucher Premium", "Expected 'Egg Voucher Premium' name")
    assert(result.icon == "mystic_ticket", "Expected 'mystic_ticket' icon")
    assert(result.value == 10, "Expected value 10 pulls")
end)

test("GetVoucherInfo GOLDEN type has correct mappings", function()
    local response = sendMessage("GetVoucherInfo", {VoucherType = "GOLDEN"})

    local result = json.decode(response.Data)
    assert(result.voucherType == "GOLDEN", "Expected GOLDEN type")
    assert(result.typeValue == 3, "Expected typeValue 3")
    assert(result.tier == "ROGUE", "Expected ROGUE tier")
    assert(result.name == "Egg Voucher Gold", "Expected 'Egg Voucher Gold' name")
    assert(result.icon == "golden_mystic_ticket", "Expected 'golden_mystic_ticket' icon")
    assert(result.value == 25, "Expected value 25 pulls")
end)

test("GetVoucherInfo rejects invalid voucher type", function()
    local response = sendMessage("GetVoucherInfo", {VoucherType = "INVALID"})

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Invalid VoucherType"), "Expected invalid type error")
end)

-- ==============================================================================
-- TASK 4: Voucher Generation Logic Tests
-- ==============================================================================

test("AddVoucher adds REGULAR vouchers correctly", function()
    local response = sendMessage("AddVoucher", {
        VoucherType = "REGULAR",
        Amount = "5"
    })

    assert(response.Action == "SaveState", "Expected SaveState action")
    assert(response.Success == "true", "Expected Success=true")

    local result = json.decode(response.Data)
    assert(result.operation == "ADD", "Expected ADD operation")
    assert(result.voucherType == "REGULAR", "Expected REGULAR type")
    assert(result.amount == 5, "Expected amount 5")
    assert(result.previousBalance == 0, "Expected previousBalance 0")
    assert(result.newBalance == 5, "Expected newBalance 5")
    assert(result.voucherCounts["0"] == 5, "Expected voucherCounts[0] = 5")
end)

test("AddVoucher adds multiple voucher types independently", function()
    -- Add REGULAR vouchers
    local response1 = sendMessage("AddVoucher", {
        VoucherType = "REGULAR",
        Amount = "3"
    })
    local result1 = json.decode(response1.Data)

    -- Add PREMIUM vouchers to existing balance
    local response2 = sendMessage("AddVoucher", {
        VoucherType = "PREMIUM",
        Amount = "2",
        VoucherCounts = json.encode(result1.voucherCounts)
    })
    local result2 = json.decode(response2.Data)

    assert(result2.voucherCounts["0"] == 3, "Expected REGULAR count 3")
    assert(result2.voucherCounts["2"] == 2, "Expected PREMIUM count 2")
end)

test("AddVoucher increments existing balance correctly", function()
    local initialCounts = {["0"] = 10, ["1"] = 5, ["2"] = 3, ["3"] = 1}

    local response = sendMessage("AddVoucher", {
        VoucherType = "PLUS",
        Amount = "7",
        VoucherCounts = json.encode(initialCounts)
    })

    local result = json.decode(response.Data)
    assert(result.previousBalance == 5, "Expected previousBalance 5")
    assert(result.newBalance == 12, "Expected newBalance 12")
    assert(result.voucherCounts["1"] == 12, "Expected PLUS count 12")
end)

test("AddVoucher tracks source for unlock tracking", function()
    local response = sendMessage("AddVoucher", {
        VoucherType = "GOLDEN",
        Amount = "1",
        Source = "CLASSIC_VICTORY"
    })

    local result = json.decode(response.Data)
    assert(result.source == "CLASSIC_VICTORY", "Expected source tracking")
end)

test("AddVoucher rejects missing VoucherType", function()
    local response = sendMessage("AddVoucher", {Amount = "5"})

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("VoucherType required"), "Expected VoucherType error")
end)

test("AddVoucher rejects missing Amount", function()
    local response = sendMessage("AddVoucher", {VoucherType = "REGULAR"})

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Amount must be positive"), "Expected Amount error")
end)

test("AddVoucher rejects negative amount", function()
    local response = sendMessage("AddVoucher", {
        VoucherType = "REGULAR",
        Amount = "-5"
    })

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Amount must be positive"), "Expected positive amount error")
end)

test("AddVoucher rejects invalid voucher type", function()
    local response = sendMessage("AddVoucher", {
        VoucherType = "INVALID",
        Amount = "5"
    })

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Invalid VoucherType"), "Expected invalid type error")
end)

-- ==============================================================================
-- TASK 5: Voucher Redemption and Validation Logic Tests
-- ==============================================================================

test("RedeemVoucher deducts vouchers correctly with sufficient balance", function()
    local initialCounts = {["0"] = 10, ["1"] = 5, ["2"] = 3, ["3"] = 1}

    local response = sendMessage("RedeemVoucher", {
        VoucherType = "PREMIUM",
        Amount = "2",
        VoucherCounts = json.encode(initialCounts)
    })

    assert(response.Action == "SaveState", "Expected SaveState action")
    assert(response.Success == "true", "Expected Success=true")

    local result = json.decode(response.Data)
    assert(result.operation == "REDEEM", "Expected REDEEM operation")
    assert(result.voucherType == "PREMIUM", "Expected PREMIUM type")
    assert(result.amount == 2, "Expected amount 2")
    assert(result.previousBalance == 3, "Expected previousBalance 3")
    assert(result.newBalance == 1, "Expected newBalance 1")
    assert(result.voucherCounts["2"] == 1, "Expected PREMIUM count 1")
    assert(result.pullCount == 20, "Expected 20 pulls (10 per voucher * 2)")
end)

test("RedeemVoucher calculates pull count based on voucher value", function()
    local testCases = {
        {type = "REGULAR", amount = 3, expectedPulls = 3},  -- 1 * 3
        {type = "PLUS", amount = 2, expectedPulls = 10},    -- 5 * 2
        {type = "PREMIUM", amount = 1, expectedPulls = 10},  -- 10 * 1
        {type = "GOLDEN", amount = 1, expectedPulls = 25}    -- 25 * 1
    }

    for _, tc in ipairs(testCases) do
        local counts = {["0"] = 10, ["1"] = 10, ["2"] = 10, ["3"] = 10}
        local response = sendMessage("RedeemVoucher", {
            VoucherType = tc.type,
            Amount = tostring(tc.amount),
            VoucherCounts = json.encode(counts)
        })

        local result = json.decode(response.Data)
        assert(
            result.pullCount == tc.expectedPulls,
            string.format("Expected %d pulls for %s x%d", tc.expectedPulls, tc.type, tc.amount)
        )
    end
end)

test("RedeemVoucher uses Math.max pattern for balance deduction", function()
    local initialCounts = {["0"] = 2, ["1"] = 0, ["2"] = 0, ["3"] = 0}

    -- Redeem exactly available amount
    local response = sendMessage("RedeemVoucher", {
        VoucherType = "REGULAR",
        Amount = "2",
        VoucherCounts = json.encode(initialCounts)
    })

    local result = json.decode(response.Data)
    assert(result.newBalance == 0, "Expected newBalance 0 (not negative)")
end)

test("RedeemVoucher rejects insufficient balance", function()
    local initialCounts = {["0"] = 2, ["1"] = 1, ["2"] = 0, ["3"] = 0}

    local response = sendMessage("RedeemVoucher", {
        VoucherType = "PLUS",
        Amount = "5",
        VoucherCounts = json.encode(initialCounts)
    })

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Insufficient vouchers"), "Expected insufficient error")
    assert(response.Error:find("PLUS"), "Expected voucher type in error")
    assert(response.Error:find("requested 5"), "Expected requested amount")
    assert(response.Error:find("available 1"), "Expected available amount")
end)

test("RedeemVoucher rejects missing VoucherType", function()
    local response = sendMessage("RedeemVoucher", {Amount = "1"})

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("VoucherType required"), "Expected VoucherType error")
end)

test("RedeemVoucher rejects missing Amount", function()
    local response = sendMessage("RedeemVoucher", {VoucherType = "REGULAR"})

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Amount must be positive"), "Expected Amount error")
end)

test("RedeemVoucher rejects invalid voucher type", function()
    local response = sendMessage("RedeemVoucher", {
        VoucherType = "INVALID",
        Amount = "1"
    })

    assert(response.Action == "Error", "Expected Error action")
    assert(response.Error:find("Invalid VoucherType"), "Expected invalid type error")
end)

-- ==============================================================================
-- TASK 6: Voucher Balance and Inventory Management Tests
-- ==============================================================================

test("GetVoucherBalance returns correct balance structure", function()
    local initialCounts = {["0"] = 10, ["1"] = 5, ["2"] = 3, ["3"] = 1}

    local response = sendMessage("GetVoucherBalance", {
        VoucherCounts = json.encode(initialCounts)
    })

    assert(response.Action == "SaveState", "Expected SaveState action")
    assert(response.Success == "true", "Expected Success=true")

    local result = json.decode(response.Data)
    assert(result.voucherCounts, "Expected voucherCounts")
    assert(result.voucherCounts["0"] == 10, "Expected REGULAR count 10")
    assert(result.voucherCounts["1"] == 5, "Expected PLUS count 5")
    assert(result.voucherCounts["2"] == 3, "Expected PREMIUM count 3")
    assert(result.voucherCounts["3"] == 1, "Expected GOLDEN count 1")
    assert(result.totalVouchers == 19, "Expected total 19 vouchers")
end)

test("GetVoucherBalance handles empty balance", function()
    local response = sendMessage("GetVoucherBalance")

    local result = json.decode(response.Data)
    assert(result.totalVouchers == 0, "Expected 0 total vouchers")
    assert(result.voucherCounts["0"] == 0, "Expected REGULAR count 0")
    assert(result.voucherCounts["1"] == 0, "Expected PLUS count 0")
    assert(result.voucherCounts["2"] == 0, "Expected PREMIUM count 0")
    assert(result.voucherCounts["3"] == 0, "Expected GOLDEN count 0")
end)

test("GetVoucherBalance calculates total correctly", function()
    local testCases = {
        {counts = {["0"] = 0, ["1"] = 0, ["2"] = 0, ["3"] = 0}, expectedTotal = 0},
        {counts = {["0"] = 5, ["1"] = 0, ["2"] = 0, ["3"] = 0}, expectedTotal = 5},
        {counts = {["0"] = 10, ["1"] = 20, ["2"] = 30, ["3"] = 40}, expectedTotal = 100}
    }

    for _, tc in ipairs(testCases) do
        local response = sendMessage("GetVoucherBalance", {
            VoucherCounts = json.encode(tc.counts)
        })

        local result = json.decode(response.Data)
        assert(
            result.totalVouchers == tc.expectedTotal,
            string.format("Expected total %d", tc.expectedTotal)
        )
    end
end)

-- ==============================================================================
-- COMPLEX SCENARIOS
-- ==============================================================================

test("Complex scenario: Multiple add/redeem transactions maintain balance integrity", function()
    -- Start with empty balance
    local counts = {["0"] = 0, ["1"] = 0, ["2"] = 0, ["3"] = 0}

    -- Add REGULAR vouchers
    local r1 = sendMessage("AddVoucher", {
        VoucherType = "REGULAR",
        Amount = "10",
        VoucherCounts = json.encode(counts)
    })
    counts = json.decode(r1.Data).voucherCounts
    assert(counts["0"] == 10, "Expected 10 REGULAR")

    -- Add PREMIUM vouchers
    local r2 = sendMessage("AddVoucher", {
        VoucherType = "PREMIUM",
        Amount = "5",
        VoucherCounts = json.encode(counts)
    })
    counts = json.decode(r2.Data).voucherCounts
    assert(counts["2"] == 5, "Expected 5 PREMIUM")

    -- Redeem some REGULAR vouchers
    local r3 = sendMessage("RedeemVoucher", {
        VoucherType = "REGULAR",
        Amount = "3",
        VoucherCounts = json.encode(counts)
    })
    counts = json.decode(r3.Data).voucherCounts
    assert(counts["0"] == 7, "Expected 7 REGULAR after redemption")

    -- Redeem some PREMIUM vouchers
    local r4 = sendMessage("RedeemVoucher", {
        VoucherType = "PREMIUM",
        Amount = "2",
        VoucherCounts = json.encode(counts)
    })
    counts = json.decode(r4.Data).voucherCounts
    assert(counts["2"] == 3, "Expected 3 PREMIUM after redemption")

    -- Verify final balance
    local balance = sendMessage("GetVoucherBalance", {
        VoucherCounts = json.encode(counts)
    })
    local result = json.decode(balance.Data)
    assert(result.totalVouchers == 10, "Expected 10 total vouchers (7 REGULAR + 3 PREMIUM)")
end)

-- ==============================================================================
-- ADP v1.0 COMPLIANCE TEST
-- ==============================================================================

test("Info handler returns ADP v1.0 compliant process information", function()
    local response = sendMessage("Info")

    assert(response.Action == "SaveState", "Expected SaveState action")
    assert(response.Success == "true", "Expected Success=true")

    local result = json.decode(response.Data)
    assert(result.process, "Expected process info")
    assert(result.process.name == "Voucher Economy Engine", "Expected process name")
    assert(result.process.adpVersion == "1.0", "Expected ADP v1.0")
    assert(result.handlers, "Expected handlers list")
    assert(result.voucherTypes, "Expected voucher types")
    assert(result.documentation, "Expected documentation")
    assert(result.documentation.adpCompliance == "v1.0", "Expected ADP compliance")
end)

-- ==============================================================================
-- TEST SUMMARY
-- ==============================================================================

print("==================================================")
print(string.format("🎉 All tests passed! (%d/%d)", passCount, testCount))
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
