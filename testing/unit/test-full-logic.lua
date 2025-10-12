local aolite = require("aolite")
local json = require("json")

aolite.spawnProcess("test-full", "processes.temp-full-test")

print("Testing full AddVoucher logic...")

local msg = {
    From = "test-full",
    Target = "test-full",
    Action = "AddVoucher",
    VoucherType = "REGULAR",
    Amount = "5",
    Data = ""
}
aolite.send(msg)
local response = aolite.getLastMsg("test-full")
print("Action:", response.Action)
print("Success:", response.Success)
if response.Error then
    print("Error:", response.Error)
else
    local data = json.decode(response.Data)
    print("operation:", data.operation)
    print("previousBalance:", data.previousBalance)
    print("newBalance:", data.newBalance)
end
