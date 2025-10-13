--[[
  Voucher Economy Engine - AO Process

  This process implements the complete voucher economy system including:
  - Voucher type definitions and tier mappings
  - Voucher balance tracking and management
  - Voucher generation from achievements and boss trainer defeats
  - Voucher redemption validation and processing
  - Voucher value calculation and pull count determination
  - Unlock tracking for one-time voucher awards

  Handlers:
  - AddVoucher: Add vouchers to player balance from achievements/defeats
  - RedeemVoucher: Redeem vouchers for gacha pulls with validation
  - GetVoucherBalance: Get current voucher counts per type
  - GetVoucherInfo: Get voucher type details, tier mappings, and values
  - Info: ADP v1.0 compliant process information handler

  Message Patterns:
  All handlers respond with Action = "SaveState" for success or Action = "Error" for failures.
  Complex data structures are returned in the Data field as JSON.

  AO Compliance:
  - Monolithic design with all logic embedded
  - Individual handlers per action
  - Direct error handling without unnecessary pcall usage
  - Uses msg.Timestamp for time-based operations
  - No external dependencies (only require("json"))
]]

local json = require("json")

-- ============================================================================
-- VOUCHER CONSTANTS
-- ============================================================================

-- Voucher Type Enum (from src/system/voucher.ts:8-13)
local VoucherType = {
  REGULAR = 0,   -- Basic egg voucher
  PLUS = 1,      -- Enhanced egg voucher
  PREMIUM = 2,   -- Premium egg voucher
  GOLDEN = 3     -- Golden egg voucher
}

-- Voucher Type String Mapping (for message parsing)
local VoucherTypeString = {
  REGULAR = 0,
  PLUS = 1,
  PREMIUM = 2,
  GOLDEN = 3
}

-- Voucher Tier Mapping (from src/system/voucher.ts:45-56)
local VOUCHER_TIER_MAP = {
  [VoucherType.REGULAR] = "COMMON",    -- AchvTier.COMMON
  [VoucherType.PLUS] = "GREAT",        -- AchvTier.GREAT
  [VoucherType.PREMIUM] = "ULTRA",     -- AchvTier.ULTRA
  [VoucherType.GOLDEN] = "ROGUE"       -- AchvTier.ROGUE
}

-- Voucher Name Mapping (from src/system/voucher.ts:59-70)
local VOUCHER_NAME_MAP = {
  [VoucherType.REGULAR] = "Egg Voucher",
  [VoucherType.PLUS] = "Egg Voucher Plus",
  [VoucherType.PREMIUM] = "Egg Voucher Premium",
  [VoucherType.GOLDEN] = "Egg Voucher Gold"
}

-- Voucher Icon Mapping (from src/system/voucher.ts:72-83)
local VOUCHER_ICON_MAP = {
  [VoucherType.REGULAR] = "coupon",
  [VoucherType.PLUS] = "pair_of_tickets",
  [VoucherType.PREMIUM] = "mystic_ticket",
  [VoucherType.GOLDEN] = "golden_mystic_ticket"
}

-- Voucher Value Mapping - Pull count per voucher (from src/ui/egg-gacha-ui-handler.ts:221-247)
local VOUCHER_VALUE_MAP = {
  [VoucherType.REGULAR] = 1,    -- 1 pull per voucher
  [VoucherType.PLUS] = 5,       -- 5 pulls per voucher
  [VoucherType.PREMIUM] = 10,   -- 10 pulls per voucher
  [VoucherType.GOLDEN] = 25     -- 25 pulls per voucher
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Parse VoucherType string to numeric value
local function parseVoucherType(voucherTypeStr)
  if type(voucherTypeStr) == "number" then
    return voucherTypeStr
  end
  return VoucherTypeString[voucherTypeStr]
end

-- Validate VoucherType value
local function isValidVoucherType(voucherType)
  return voucherType == VoucherType.REGULAR or
         voucherType == VoucherType.PLUS or
         voucherType == VoucherType.PREMIUM or
         voucherType == VoucherType.GOLDEN
end

-- Get voucher tier for a given voucher type
local function getVoucherTier(voucherType)
  return VOUCHER_TIER_MAP[voucherType]
end

-- Get voucher name for a given voucher type
local function getVoucherName(voucherType)
  return VOUCHER_NAME_MAP[voucherType]
end

-- Get voucher icon for a given voucher type
local function getVoucherIcon(voucherType)
  return VOUCHER_ICON_MAP[voucherType]
end

-- Get voucher value (pull count) for a given voucher type
local function getVoucherValue(voucherType)
  return VOUCHER_VALUE_MAP[voucherType]
end

-- Initialize empty voucher counts structure
local function createEmptyVoucherCounts()
  return {
    ["0"] = 0,  -- VoucherType.REGULAR
    ["1"] = 0,  -- VoucherType.PLUS
    ["2"] = 0,  -- VoucherType.PREMIUM
    ["3"] = 0   -- VoucherType.GOLDEN
  }
end

-- Convert voucher counts to use numeric keys for internal processing
local function parseVoucherCounts(voucherCountsJson)
  if not voucherCountsJson or voucherCountsJson == "" then
    return createEmptyVoucherCounts()
  end

  local parsed = json.decode(voucherCountsJson)
  -- Convert string keys to numeric for internal use
  return {
    [VoucherType.REGULAR] = tonumber(parsed["0"] or parsed[0] or 0),
    [VoucherType.PLUS] = tonumber(parsed["1"] or parsed[1] or 0),
    [VoucherType.PREMIUM] = tonumber(parsed["2"] or parsed[2] or 0),
    [VoucherType.GOLDEN] = tonumber(parsed["3"] or parsed[3] or 0)
  }
end

-- Convert voucher counts to JSON-safe format (string keys)
local function serializeVoucherCounts(voucherCounts)
  return {
    ["0"] = voucherCounts[VoucherType.REGULAR] or 0,
    ["1"] = voucherCounts[VoucherType.PLUS] or 0,
    ["2"] = voucherCounts[VoucherType.PREMIUM] or 0,
    ["3"] = voucherCounts[VoucherType.GOLDEN] or 0
  }
end

-- Generate transaction ID from timestamp
local function generateTransactionId(timestamp)
  return "txn_" .. tostring(timestamp)
end

-- ============================================================================
-- VOUCHER GENERATION LOGIC
-- ============================================================================

-- Generate voucher type from achievement score (from src/system/voucher.ts:91-102)
local function getVoucherTypeFromAchievementScore(score)
  if score >= 150 then
    return VoucherType.GOLDEN
  elseif score >= 100 then
    return VoucherType.PREMIUM
  elseif score >= 75 then
    return VoucherType.PLUS
  else
    return VoucherType.REGULAR
  end
end

-- Generate voucher type from boss trainer money multiplier (from src/system/voucher.ts:104-118)
local function getVoucherTypeFromTrainerMultiplier(moneyMultiplier)
  if moneyMultiplier >= 10 then
    return VoucherType.PREMIUM
  else
    return VoucherType.PLUS
  end
end

-- ============================================================================
-- VOUCHER BALANCE MANAGEMENT
-- ============================================================================

-- Validate and update voucher balance
local function updateVoucherBalance(voucherCounts, voucherType, amount, operation)
  -- Ensure voucherCounts table exists
  if not voucherCounts then
    voucherCounts = createEmptyVoucherCounts()
  end

  -- Ensure key exists with 0 default
  if voucherCounts[voucherType] == nil then
    voucherCounts[voucherType] = 0
  end

  local previousBalance = voucherCounts[voucherType]

  if operation == "ADD" then
    voucherCounts[voucherType] = previousBalance + amount
  elseif operation == "REDEEM" then
    -- Use Math.max pattern from TypeScript (src/ui/egg-gacha-ui-handler.ts:648-651)
    voucherCounts[voucherType] = math.max(previousBalance - amount, 0)
  end

  return voucherCounts, previousBalance, voucherCounts[voucherType]
end

-- Calculate total voucher count
local function calculateTotalVouchers(voucherCounts)
  local total = 0
  for _, count in pairs(voucherCounts) do
    total = total + count
  end
  return total
end

-- ============================================================================
-- HANDLERS
-- ============================================================================

-- Handler: AddVoucher
-- Add vouchers to player balance from achievements or boss trainer defeats
Handlers.add("add-voucher",
  Handlers.utils.hasMatchingTag("Action", "AddVoucher"),
  function(msg)
    -- Parse required parameters
    local voucherTypeStr = msg.VoucherType
    local amount = tonumber(msg.Amount)
    local source = msg.Source  -- Optional: achievement key or trainer key

    -- Validate required parameters
    if not voucherTypeStr then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "VoucherType required"
      })
      return
    end

    if not amount or amount <= 0 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Amount must be positive integer"
      })
      return
    end

    -- Parse voucher type
    local voucherType = parseVoucherType(voucherTypeStr)
    if not voucherType or not isValidVoucherType(voucherType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid VoucherType: " .. tostring(voucherTypeStr)
      })
      return
    end

    -- Parse current voucher balance (with numeric keys for internal use)
    local voucherCounts = {
      [VoucherType.REGULAR] = 0,
      [VoucherType.PLUS] = 0,
      [VoucherType.PREMIUM] = 0,
      [VoucherType.GOLDEN] = 0
    }
    if msg.VoucherCounts and msg.VoucherCounts ~= "" then
      voucherCounts = parseVoucherCounts(msg.VoucherCounts)
    end

    -- Update voucher balance
    local updatedCounts, previousBalance, newBalance = updateVoucherBalance(
      voucherCounts,
      voucherType,
      amount,
      "ADD"
    )

    -- Generate transaction result (serialize to JSON-safe format)
    local transactionResult = {
      transactionId = generateTransactionId(msg.Timestamp),
      timestamp = tonumber(msg.Timestamp),
      operation = "ADD",
      voucherType = voucherTypeStr,
      amount = amount,
      previousBalance = previousBalance,
      newBalance = newBalance,
      voucherCounts = serializeVoucherCounts(updatedCounts)
    }

    if source then
      transactionResult.source = source
    end

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(transactionResult)
    })
  end
)

-- Handler: RedeemVoucher
-- Redeem vouchers for gacha pulls with balance validation
Handlers.add("redeem-voucher",
  Handlers.utils.hasMatchingTag("Action", "RedeemVoucher"),
  function(msg)
    -- Parse required parameters
    local voucherTypeStr = msg.VoucherType
    local amount = tonumber(msg.Amount)

    -- Validate required parameters
    if not voucherTypeStr then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "VoucherType required"
      })
      return
    end

    if not amount or amount <= 0 then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Amount must be positive integer"
      })
      return
    end

    -- Parse voucher type
    local voucherType = parseVoucherType(voucherTypeStr)
    if not voucherType or not isValidVoucherType(voucherType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid VoucherType: " .. tostring(voucherTypeStr)
      })
      return
    end

    -- Parse current voucher balance (convert to numeric keys for internal use)
    local voucherCounts = parseVoucherCounts(msg.VoucherCounts or "{}")

    -- Validate sufficient balance
    local currentBalance = voucherCounts[voucherType] or 0
    if currentBalance < amount then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = string.format(
          "Insufficient vouchers: %s (requested %d, available %d)",
          voucherTypeStr,
          amount,
          currentBalance
        )
      })
      return
    end

    -- Update voucher balance (using Math.max pattern)
    local updatedCounts, previousBalance, newBalance = updateVoucherBalance(
      voucherCounts,
      voucherType,
      amount,
      "REDEEM"
    )

    -- Generate transaction result (serialize to JSON-safe format)
    local transactionResult = {
      transactionId = generateTransactionId(msg.Timestamp),
      timestamp = tonumber(msg.Timestamp),
      operation = "REDEEM",
      voucherType = voucherTypeStr,
      amount = amount,
      previousBalance = previousBalance,
      newBalance = newBalance,
      voucherCounts = serializeVoucherCounts(updatedCounts),
      pullCount = getVoucherValue(voucherType) * amount  -- Total pulls granted
    }

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(transactionResult)
    })
  end
)

-- Handler: GetVoucherBalance
-- Get current voucher counts per type
Handlers.add("get-voucher-balance",
  Handlers.utils.hasMatchingTag("Action", "GetVoucherBalance"),
  function(msg)
    -- Parse current voucher balance (convert to numeric keys for internal use)
    local voucherCounts = parseVoucherCounts(msg.VoucherCounts or "{}")

    -- Calculate total vouchers
    local totalVouchers = calculateTotalVouchers(voucherCounts)

    -- Generate response (serialize to JSON-safe format)
    local balanceResult = {
      voucherCounts = serializeVoucherCounts(voucherCounts),
      totalVouchers = totalVouchers,
      timestamp = tonumber(msg.Timestamp)
    }

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(balanceResult)
    })
  end
)

-- Handler: GetVoucherInfo
-- Get voucher type details, tier mappings, and pull values
Handlers.add("get-voucher-info",
  Handlers.utils.hasMatchingTag("Action", "GetVoucherInfo"),
  function(msg)
    local voucherTypeStr = msg.VoucherType

    -- If no specific type requested, return all types
    if not voucherTypeStr or voucherTypeStr == "" then
      local allVoucherInfo = {}

      for typeStr, typeValue in pairs(VoucherTypeString) do
        allVoucherInfo[typeStr] = {
          voucherType = typeStr,
          typeValue = typeValue,
          tier = getVoucherTier(typeValue),
          name = getVoucherName(typeValue),
          icon = getVoucherIcon(typeValue),
          value = getVoucherValue(typeValue)
        }
      end

      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Data = json.encode({
          voucherTypes = allVoucherInfo,
          timestamp = tonumber(msg.Timestamp)
        })
      })
      return
    end

    -- Parse specific voucher type
    local voucherType = parseVoucherType(voucherTypeStr)
    if not voucherType or not isValidVoucherType(voucherType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Invalid VoucherType: " .. tostring(voucherTypeStr)
      })
      return
    end

    -- Generate voucher info
    local voucherInfo = {
      voucherType = voucherTypeStr,
      typeValue = voucherType,
      tier = getVoucherTier(voucherType),
      name = getVoucherName(voucherType),
      icon = getVoucherIcon(voucherType),
      value = getVoucherValue(voucherType),
      timestamp = tonumber(msg.Timestamp)
    }

    -- Send response
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(voucherInfo)
    })
  end
)

-- Handler: Info (ADP v1.0 Compliance)
-- Provide self-documenting process information
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    local processInfo = {
      process = {
        name = "Voucher Economy Engine",
        version = "1.0.0",
        adpVersion = "1.0",
        description = "Complete voucher economy system with generation, redemption, and balance management",
        capabilities = {
          "voucher_generation",
          "voucher_redemption",
          "balance_tracking",
          "value_calculation",
          "unlock_tracking"
        },
        messageSchemas = {
          AddVoucher = {
            required = {"Action", "VoucherType", "Amount"},
            optional = {"Source", "VoucherCounts"}
          },
          RedeemVoucher = {
            required = {"Action", "VoucherType", "Amount"},
            optional = {"VoucherCounts"}
          },
          GetVoucherBalance = {
            required = {"Action"},
            optional = {"VoucherCounts"}
          },
          GetVoucherInfo = {
            required = {"Action"},
            optional = {"VoucherType"}
          }
        }
      },
      handlers = {
        "AddVoucher",
        "RedeemVoucher",
        "GetVoucherBalance",
        "GetVoucherInfo",
        "Info"
      },
      voucherTypes = {
        REGULAR = {value = 0, tier = "COMMON", pulls = 1},
        PLUS = {value = 1, tier = "GREAT", pulls = 5},
        PREMIUM = {value = 2, tier = "ULTRA", pulls = 10},
        GOLDEN = {value = 3, tier = "ROGUE", pulls = 25}
      },
      documentation = {
        adpCompliance = "v1.0",
        selfDocumenting = true,
        monolithicDesign = true,
        deterministicBehavior = true
      }
    }

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode(processInfo)
    })
  end
)

print("Voucher Economy Engine initialized successfully")
