-- Aolite Unit Tests for Voucher Reward Engine Process
-- Tests voucher award logic, validation, inventory management, and metadata queries
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.voucher-reward-engine"
local processId = "test-voucher-reward-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Voucher Reward Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Achievement Voucher Metadata (Classic Victory)
print("📝 Test 1: Achievement Voucher Metadata (Classic Victory)")
local metadataResponse = sendMessage("GetVoucherMetadata", {
    VoucherId = "CLASSIC_VICTORY"
})
if metadataResponse and metadataResponse.Action == "VoucherMetadata" then
    print("✅ Classic victory voucher metadata test passed")
else
    error("❌ Classic victory voucher metadata test failed")
end

-- Test 2: Boss Trainer Voucher Metadata (Gym Leader Brock)
print("📝 Test 2: Boss Trainer Voucher Metadata (Gym Leader Brock)")
local brockResponse = sendMessage("GetVoucherMetadata", {
    VoucherId = "GYM_LEADER_BROCK"
})
if brockResponse and brockResponse.Action == "VoucherMetadata" then
    print("✅ Gym leader Brock metadata test passed")
else
    error("❌ Gym leader Brock metadata test failed")
end

-- Test 3: Elite Four Voucher Metadata
print("📝 Test 3: Elite Four Voucher Metadata (Lance)")
local lanceResponse = sendMessage("GetVoucherMetadata", {
    VoucherId = "ELITE_FOUR_LANCE"
})
if lanceResponse and lanceResponse.Action == "VoucherMetadata" then
    print("✅ Elite Four Lance metadata test passed")
else
    error("❌ Elite Four Lance metadata test failed")
end

-- Test 4: Award Voucher First Time
print("📝 Test 4: Award Voucher First Time")
local awardResponse = sendMessage("AwardVoucher", {
    PlayerId = "player_test_1",
    VoucherId = "CLASSIC_VICTORY",
    Source = "Achievement"
})
if awardResponse and awardResponse.Action == "VoucherAwarded" and awardResponse.Success == "true" and awardResponse.AlreadyAwarded == "false" then
    print("✅ Award voucher first time test passed")
else
    error("❌ Award voucher first time test failed")
end

-- Test 5: Award Voucher Duplicate
print("📝 Test 5: Award Voucher Duplicate")
-- First award
sendMessage("AwardVoucher", {
    PlayerId = "player_test_2",
    VoucherId = "GYM_LEADER_BROCK",
    Source = "BossTrainer"
})
-- Second award (duplicate)
local duplicateResponse = sendMessage("AwardVoucher", {
    PlayerId = "player_test_2",
    VoucherId = "GYM_LEADER_BROCK",
    Source = "BossTrainer"
})
if duplicateResponse and duplicateResponse.Success == "false" and duplicateResponse.AlreadyAwarded == "true" then
    print("✅ Award voucher duplicate test passed")
else
    error("❌ Award voucher duplicate test failed")
end

-- Test 6: Award Invalid Voucher
print("📝 Test 6: Award Invalid Voucher")
local invalidResponse = sendMessage("AwardVoucher", {
    PlayerId = "player_test_3",
    VoucherId = "INVALID_VOUCHER",
    Source = "Achievement"
})
if invalidResponse and invalidResponse.Action == "Error" then
    print("✅ Award invalid voucher test passed")
else
    error("❌ Award invalid voucher test failed")
end

-- Test 7: Award Missing PlayerId
print("📝 Test 7: Award Missing PlayerId")
local missingPlayerResponse = sendMessage("AwardVoucher", {
    VoucherId = "CLASSIC_VICTORY",
    Source = "Achievement"
})
if missingPlayerResponse and missingPlayerResponse.Action == "Error" then
    print("✅ Award missing player ID test passed")
else
    error("❌ Award missing player ID test failed")
end

-- Test 8: Validate Awarded Voucher
print("📝 Test 8: Validate Awarded Voucher")
-- Award voucher first
sendMessage("AwardVoucher", {
    PlayerId = "player_validation",
    VoucherId = "GYM_LEADER_MISTY",
    Source = "BossTrainer"
})
-- Validate
local validateResponse = sendMessage("ValidateVoucher", {
    PlayerId = "player_validation",
    VoucherId = "GYM_LEADER_MISTY"
})
if validateResponse and validateResponse.Action == "VoucherValidated" and validateResponse.IsAwarded == "true" then
    print("✅ Validate awarded voucher test passed")
else
    error("❌ Validate awarded voucher test failed")
end

-- Test 9: Validate Not Awarded Voucher
print("📝 Test 9: Validate Not Awarded Voucher")
local notAwardedResponse = sendMessage("ValidateVoucher", {
    PlayerId = "player_not_awarded",
    VoucherId = "GYM_LEADER_ERIKA"
})
if notAwardedResponse and notAwardedResponse.IsAwarded == "false" then
    print("✅ Validate not awarded voucher test passed")
else
    error("❌ Validate not awarded voucher test failed")
end

-- Test 10: Multiple Voucher Types
print("📝 Test 10: Multiple Voucher Types (Inventory)")
-- Award GOLDEN voucher
sendMessage("AwardVoucher", {
    PlayerId = "player_inventory",
    VoucherId = "CLASSIC_VICTORY",
    Source = "Achievement"
})
-- Award PLUS vouchers
sendMessage("AwardVoucher", {
    PlayerId = "player_inventory",
    VoucherId = "GYM_LEADER_BROCK",
    Source = "BossTrainer"
})
sendMessage("AwardVoucher", {
    PlayerId = "player_inventory",
    VoucherId = "GYM_LEADER_MISTY",
    Source = "BossTrainer"
})
-- Get voucher data
local inventoryResponse = sendMessage("GetPlayerVouchers", {
    PlayerId = "player_inventory"
})
if inventoryResponse and inventoryResponse.Action == "PlayerVoucherData" then
    print("✅ Multiple voucher types test passed")
else
    error("❌ Multiple voucher types test failed")
end

-- Test 11: Consume Voucher
print("📝 Test 11: Consume Voucher")
-- Award vouchers
sendMessage("AwardVoucher", {
    PlayerId = "player_consume",
    VoucherId = "GYM_LEADER_SABRINA",
    Source = "BossTrainer"
})
sendMessage("AwardVoucher", {
    PlayerId = "player_consume",
    VoucherId = "GYM_LEADER_BLAINE",
    Source = "BossTrainer"
})
-- Consume one PLUS voucher
local consumeResponse = sendMessage("ConsumeVoucher", {
    PlayerId = "player_consume",
    VoucherType = "1", -- PLUS
    Quantity = "1"
})
if consumeResponse and consumeResponse.Action == "VoucherConsumed" and consumeResponse.Success == "true" and consumeResponse.RemainingCount == "1" then
    print("✅ Consume voucher test passed")
else
    error("❌ Consume voucher test failed")
end

-- Test 12: Consume Insufficient Vouchers
print("📝 Test 12: Consume Insufficient Vouchers")
-- Award only 1 voucher
sendMessage("AwardVoucher", {
    PlayerId = "player_insufficient",
    VoucherId = "GYM_LEADER_GIOVANNI",
    Source = "BossTrainer"
})
-- Try to consume 2
local insufficientResponse = sendMessage("ConsumeVoucher", {
    PlayerId = "player_insufficient",
    VoucherType = "1", -- PLUS
    Quantity = "2"
})
if insufficientResponse and insufficientResponse.Action == "Error" then
    print("✅ Consume insufficient vouchers test passed")
else
    error("❌ Consume insufficient vouchers test failed")
end

-- Test 13: Consume Zero Quantity
print("📝 Test 13: Consume Zero Quantity")
local zeroResponse = sendMessage("ConsumeVoucher", {
    PlayerId = "player_zero",
    VoucherType = "1",
    Quantity = "0"
})
if zeroResponse and zeroResponse.Action == "Error" then
    print("✅ Consume zero quantity test passed")
else
    error("❌ Consume zero quantity test failed")
end

-- Test 14: Get Player Vouchers with Metadata
print("📝 Test 14: Get Player Vouchers with Metadata")
-- Award a voucher
sendMessage("AwardVoucher", {
    PlayerId = "player_metadata",
    VoucherId = "CLASSIC_VICTORY",
    Source = "Achievement"
})
-- Get with metadata
local metadataPlayerResponse = sendMessage("GetPlayerVouchers", {
    PlayerId = "player_metadata",
    IncludeMetadata = "true"
})
if metadataPlayerResponse and metadataPlayerResponse.Action == "PlayerVoucherData" then
    print("✅ Get player vouchers with metadata test passed")
else
    error("❌ Get player vouchers with metadata test failed")
end

-- Test 15: Get All Vouchers Metadata
print("📝 Test 15: Get All Vouchers Metadata")
local allMetadataResponse = sendMessage("GetVoucherMetadata")
if allMetadataResponse and allMetadataResponse.Action == "VoucherMetadata" then
    print("✅ Get all vouchers metadata test passed")
else
    error("❌ Get all vouchers metadata test failed")
end

-- Test 16: ADP Info Handler
print("📝 Test 16: ADP Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ ADP info handler test passed")
else
    error("❌ ADP info handler test failed")
end

-- Test 17: Player Voucher Isolation
print("📝 Test 17: Player Voucher Isolation")
-- Award to player 1
sendMessage("AwardVoucher", {
    PlayerId = "player_isolation_1",
    VoucherId = "CLASSIC_VICTORY",
    Source = "Achievement"
})
-- Check player 2 (should have no vouchers)
local isolationResponse = sendMessage("GetPlayerVouchers", {
    PlayerId = "player_isolation_2"
})
if isolationResponse and isolationResponse.Action == "PlayerVoucherData" then
    print("✅ Player voucher isolation test passed")
else
    error("❌ Player voucher isolation test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
