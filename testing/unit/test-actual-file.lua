local aolite = require("aolite")
local json = require("json")

-- Test the ACTUAL voucher-economy-engine.lua file
local processId = "test-actual-voucher"
aolite.spawnProcess(processId, "processes.voucher-economy-engine")

print("Testing ACTUAL voucher-economy-engine.lua...")

-- First check if process loaded
print("\n1. Testing GetVoucherInfo (known to work)...")
local msg1 = {
    From = processId,
    Target = processId,
    Action = "GetVoucherInfo",
    VoucherType = "REGULAR",
    Data = ""
}
aolite.send(msg1)
local response1 = aolite.getLastMsg(processId)
print("  Action:", response1.Action, "Success:", response1.Success)

-- Now test AddVoucher with MINIMAL data
print("\n2. Testing AddVoucher with minimal data...")
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
print("  Action:", response2.Action)
print("  Success:", response2.Success)
if response2.Error then
    print("  Error:", response2.Error)
end
if response2.Data and response2.Data ~= "" then
    print("  Data length:", #response2.Data)
    -- Try to decode
    local success, data = pcall(json.decode, response2.Data)
    if success then
        print("  operation:", data.operation)
        print("  newBalance:", data.newBalance)
    else
        print("  JSON decode failed:", data)
    end
end

-- Debug: Print all response fields
print("\n3. All response fields:")
for k, v in pairs(response2) do
    if type(v) ~= "function" and type(v) ~= "table" then
        print("  " .. k .. ":", tostring(v))
    end
end
