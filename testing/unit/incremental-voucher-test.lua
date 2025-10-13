-- Incremental test to find the bug
local aolite = require("aolite")
local json = require("json")

local incrementalProcess = [[
local json = require("json")

-- VoucherType enum
local VoucherType = {
  REGULAR = 0,
  PLUS = 1,
  PREMIUM = 2,
  GOLDEN = 3
}

-- VoucherTypeString mapping
local VoucherTypeString = {
  REGULAR = 0,
  PLUS = 1,
  PREMIUM = 2,
  GOLDEN = 3
}

-- Parse function
local function parseVoucherType(voucherTypeStr)
  if type(voucherTypeStr) == "number" then
    return voucherTypeStr
  end
  return VoucherTypeString[voucherTypeStr]
end

-- Validate function
local function isValidVoucherType(voucherType)
  return voucherType == VoucherType.REGULAR or
         voucherType == VoucherType.PLUS or
         voucherType == VoucherType.PREMIUM or
         voucherType == VoucherType.GOLDEN
end

Handlers.add("test-add",
  Handlers.utils.hasMatchingTag("Action", "AddVoucher"),
  function(msg)
    -- Step 1: Parse parameters
    local voucherTypeStr = msg.VoucherType
    local amount = tonumber(msg.Amount)

    -- Step 2: Validate parameters exist
    if not voucherTypeStr then
      ao.send({Target = msg.From, Action = "Error", Error = "VoucherType required"})
      return
    end

    if not amount or amount <= 0 then
      ao.send({Target = msg.From, Action = "Error", Error = "Amount required"})
      return
    end

    -- Step 3: Parse voucher type
    local voucherType = parseVoucherType(voucherTypeStr)
    if not voucherType then
      ao.send({Target = msg.From, Action = "Error", Error = "Parse failed: voucherType is nil"})
      return
    end

    -- Step 4: Validate voucher type
    if not isValidVoucherType(voucherType) then
      ao.send({Target = msg.From, Action = "Error", Error = "Invalid voucher type: " .. tostring(voucherType)})
      return
    end

    -- Success!
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        test = "AddVoucher incremental works",
        voucherType = voucherTypeStr,
        voucherTypeValue = voucherType,
        amount = amount
      })
    })
  end
)

print("Incremental process loaded")
]]

local tempFile = io.open("processes/temp-incremental-voucher.lua", "w")
tempFile:write(incrementalProcess)
tempFile:close()

local processId = "test-incremental"
aolite.spawnProcess(processId, "processes.temp-incremental-voucher")

print("Testing incremental AddVoucher...")

-- Test AddVoucher with REGULAR type
local msg = {
    From = processId,
    Target = processId,
    Action = "AddVoucher",
    VoucherType = "REGULAR",
    Amount = "5",
    Data = ""
}
aolite.send(msg)
local response = aolite.getLastMsg(processId)
print("Action:", response.Action)
print("Success:", response.Success)
if response.Error then
    print("Error:", response.Error)
end
if response.Data and response.Data ~= "" then
    local data = json.decode(response.Data)
    print("Data.test:", data.test)
    print("Data.voucherType:", data.voucherType)
    print("Data.voucherTypeValue:", data.voucherTypeValue)
    print("Data.amount:", data.amount)
end

-- Clean up
os.remove("processes/temp-incremental-voucher.lua")
