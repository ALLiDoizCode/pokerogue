local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.gacha-mechanics-engine"  -- Use working process for comparison
local processId = "test-working"

aolite.spawnProcess(processId, PROCESS_PATH)

print("Testing working process...")

-- Test GetGachaInfo (known to work)
local msg1 = {
    From = processId,
    Target = processId,
    Action = "GetGachaInfo",
    GachaType = "MOVE",
    Data = ""
}
aolite.send(msg1)
local response1 = aolite.getLastMsg(processId)
print("GetGachaInfo Action:", response1.Action)
print("GetGachaInfo Success:", response1.Success)

-- Now test voucher process
local VOUCHER_PATH = "processes.voucher-economy-engine"
local voucherId = "test-voucher"

aolite.spawnProcess(voucherId, VOUCHER_PATH)

print("\nTesting voucher process...")

-- Test GetVoucherInfo (known to work)
local msg2 = {
    From = voucherId,
    Target = voucherId,
    Action = "GetVoucherInfo",
    Data = ""
}
aolite.send(msg2)
local response2 = aolite.getLastMsg(voucherId)
print("GetVoucherInfo Action:", response2.Action)
print("GetVoucherInfo Success:", response2.Success)

-- Test AddVoucher
local msg3 = {
    From = voucherId,
    Target = voucherId,
    Action = "AddVoucher",
    VoucherType = "REGULAR",
    Amount = "5",
    Data = ""
}
aolite.send(msg3)
local response3 = aolite.getLastMsg(voucherId)
print("AddVoucher Action:", response3.Action)
print("AddVoucher Success:", response3.Success)
if response3.Error then
    print("AddVoucher Error:", response3.Error)
end
if response3.Data and response3.Data ~= "" then
    print("AddVoucher Data length:", #response3.Data)
end
