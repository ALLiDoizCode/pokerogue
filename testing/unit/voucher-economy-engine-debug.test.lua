-- Required imports
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.voucher-economy-engine"
local processId = "test-voucher-economy"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Debug Test for Voucher Economy Engine")

-- Test GetVoucherInfo first (known to work)
local msg1 = {
    From = processId,
    Target = processId,
    Action = "GetVoucherInfo",
    Data = ""
}
aolite.send(msg1)
local response1 = aolite.getLastMsg(processId)
print("GetVoucherInfo response Action:", response1.Action)

-- Test AddVoucher
local msg2 = {
    From = processId,
    Target = processId,
    Action = "AddVoucher",
    VoucherType = "REGULAR",
    Amount = "5",
    Data = ""
}
aolite.send(msg2)
local response2 = aolite.getLastMsg(processId)

print("\n📦 AddVoucher Response:")
print("  Action:", response2.Action)
print("  Success:", response2.Success)
print("  Target:", response2.Target)
if response2.Error then
    print("  Error:", response2.Error)
end
if response2.Data and response2.Data ~= "" then
    print("  Data:", response2.Data)
    local success_decode, result = pcall(json.decode, response2.Data)
    if success_decode then
        print("  Parsed operation:", result.operation)
        print("  Parsed voucherType:", result.voucherType)
    end
else
    print("  Data: (empty)")
end

-- Also check all message fields
print("\n📦 All Response Fields:")
for k, v in pairs(response2) do
    print("  " .. k .. ":", tostring(v))
end
