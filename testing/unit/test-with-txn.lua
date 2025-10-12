local aolite = require("aolite")
local json = require("json")

aolite.spawnProcess("test-txn", "processes.temp-full-test")

print("Testing AddVoucher with transactionId...")

local msg = {
    From = "test-txn",
    Target = "test-txn",
    Action = "AddVoucherTxn",
    VoucherType = "REGULAR",
    Amount = "5",
    Data = ""
}
aolite.send(msg)
local response = aolite.getLastMsg("test-txn")
print("Action:", response.Action)
print("Success:", response.Success)
if response.Error then
    print("Error:", response.Error)
else
    local data = json.decode(response.Data)
    print("transactionId:", data.transactionId)
    print("timestamp:", data.timestamp)
    print("newBalance:", data.newBalance)
    print("voucherCounts[0]:", data.voucherCounts[0])
end
