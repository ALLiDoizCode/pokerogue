local json = require("json")

local VoucherType = {REGULAR = 0, PLUS = 1, PREMIUM = 2, GOLDEN = 3}
local VoucherTypeString = {REGULAR = 0, PLUS = 1, PREMIUM = 2, GOLDEN = 3}

local function parseVoucherType(voucherTypeStr)
  if type(voucherTypeStr) == "number" then return voucherTypeStr end
  return VoucherTypeString[voucherTypeStr]
end

local function isValidVoucherType(voucherType)
  return voucherType == VoucherType.REGULAR or voucherType == VoucherType.PLUS or 
         voucherType == VoucherType.PREMIUM or voucherType == VoucherType.GOLDEN
end

local function createEmptyVoucherCounts()
  return {[VoucherType.REGULAR] = 0, [VoucherType.PLUS] = 0, [VoucherType.PREMIUM] = 0, [VoucherType.GOLDEN] = 0}
end

local function updateVoucherBalance(voucherCounts, voucherType, amount, operation)
  if not voucherCounts then voucherCounts = createEmptyVoucherCounts() end
  if voucherCounts[voucherType] == nil then voucherCounts[voucherType] = 0 end
  local previousBalance = voucherCounts[voucherType]
  if operation == "ADD" then
    voucherCounts[voucherType] = previousBalance + amount
  end
  return voucherCounts, previousBalance, voucherCounts[voucherType]
end

Handlers.add("test-full",
  Handlers.utils.hasMatchingTag("Action", "AddVoucher"),
  function(msg)
    local voucherTypeStr = msg.VoucherType
    local amount = tonumber(msg.Amount)
    if not voucherTypeStr then ao.send({Target = msg.From, Action = "Error", Error = "VoucherType required"}); return end
    if not amount or amount <= 0 then ao.send({Target = msg.From, Action = "Error", Error = "Amount required"}); return end
    
    local voucherType = parseVoucherType(voucherTypeStr)
    if not voucherType or not isValidVoucherType(voucherType) then
      ao.send({Target = msg.From, Action = "Error", Error = "Invalid type"}); return
    end
    
    local voucherCounts = createEmptyVoucherCounts()
    local updatedCounts, previousBalance, newBalance = updateVoucherBalance(voucherCounts, voucherType, amount, "ADD")
    
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        operation = "ADD",
        voucherType = voucherTypeStr,
        amount = amount,
        previousBalance = previousBalance,
        newBalance = newBalance
      })
    })
  end
)

print("Full test process loaded")

local function generateTransactionId(timestamp)
  return "txn_" .. tostring(timestamp)
end

Handlers.add("test-with-txn-id",
  Handlers.utils.hasMatchingTag("Action", "AddVoucherTxn"),
  function(msg)
    local voucherTypeStr = msg.VoucherType
    local amount = tonumber(msg.Amount)
    if not voucherTypeStr then ao.send({Target = msg.From, Action = "Error", Error = "VoucherType required"}); return end
    if not amount or amount <= 0 then ao.send({Target = msg.From, Action = "Error", Error = "Amount required"}); return end
    
    local voucherType = parseVoucherType(voucherTypeStr)
    if not voucherType or not isValidVoucherType(voucherType) then
      ao.send({Target = msg.From, Action = "Error", Error = "Invalid type"}); return
    end
    
    local voucherCounts = createEmptyVoucherCounts()
    local updatedCounts, previousBalance, newBalance = updateVoucherBalance(voucherCounts, voucherType, amount, "ADD")
    
    local transactionResult = {
      transactionId = generateTransactionId(msg.Timestamp),
      timestamp = tonumber(msg.Timestamp),
      operation = "ADD",
      voucherType = voucherTypeStr,
      amount = amount,
      previousBalance = previousBalance,
      newBalance = newBalance,
      voucherCounts = updatedCounts
    }
    
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(transactionResult)
    })
  end
)
