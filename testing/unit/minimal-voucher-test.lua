-- Minimal inline process test
local aolite = require("aolite")
local json = require("json")

-- Create minimal process inline
local minimalProcess = [[
local json = require("json")

Handlers.add("test-add",
  Handlers.utils.hasMatchingTag("Action", "AddVoucher"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({test = "AddVoucher works", amount = msg.Amount})
    })
  end
)

Handlers.add("test-get",
  Handlers.utils.hasMatchingTag("Action", "GetVoucherInfo"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({test = "GetVoucherInfo works"})
    })
  end
)

print("Minimal process loaded")
]]

-- Spawn with source (need to use require approach)
-- Actually, let's use module approach
-- Save to temp file first
local tempFile = io.open("processes/temp-minimal-voucher.lua", "w")
tempFile:write(minimalProcess)
tempFile:close()

local processId = "test-minimal"
aolite.spawnProcess(processId, "processes.temp-minimal-voucher")

print("Testing minimal process...")

-- Test GetVoucherInfo
local msg1 = {
    From = processId,
    Target = processId,
    Action = "GetVoucherInfo",
    Data = ""
}
aolite.send(msg1)
local response1 = aolite.getLastMsg(processId)
print("GetVoucherInfo Action:", response1.Action, "Success:", response1.Success)

-- Test AddVoucher
local msg2 = {
    From = processId,
    Target = processId,
    Action = "AddVoucher",
    Amount = "5",
    Data = ""
}
aolite.send(msg2)
local response2 = aolite.getLastMsg(processId)
print("AddVoucher Action:", response2.Action, "Success:", response2.Success)

-- Clean up
os.remove("processes/temp-minimal-voucher.lua")
