-- Voucher Reward Engine Process
-- Stateless AO process for voucher reward distribution and inventory management
-- Implements ADP v1.0 for self-documentation
-- Manages egg voucher awards from achievements and boss trainer victories

local json = require("json")

-- Voucher Type Enum
local VoucherType = {
    REGULAR = 0,
    PLUS = 1,
    PREMIUM = 2,
    GOLDEN = 3
}

-- Achievement Tier Enum (for mapping voucher types)
local AchvTier = {
    COMMON = 0,
    GREAT = 1,
    ULTRA = 2,
    ROGUE = 3,
    MASTER = 4
}

-- Voucher icon mappings
local VoucherIcons = {
    [VoucherType.REGULAR] = "coupon",
    [VoucherType.PLUS] = "pair_of_tickets",
    [VoucherType.PREMIUM] = "mystic_ticket",
    [VoucherType.GOLDEN] = "golden_mystic_ticket"
}

-- Voucher name mappings
local VoucherNames = {
    [VoucherType.REGULAR] = "Egg Voucher",
    [VoucherType.PLUS] = "Egg Voucher Plus",
    [VoucherType.PREMIUM] = "Egg Voucher Premium",
    [VoucherType.GOLDEN] = "Golden Egg Voucher"
}

-- Get tier from voucher type
local function getTierFromVoucherType(voucherType)
    if voucherType == VoucherType.REGULAR then return AchvTier.COMMON end
    if voucherType == VoucherType.PLUS then return AchvTier.GREAT end
    if voucherType == VoucherType.PREMIUM then return AchvTier.ULTRA end
    if voucherType == VoucherType.GOLDEN then return AchvTier.ROGUE end
    return AchvTier.COMMON
end

-- Embedded Boss Trainer Configuration (subset for voucher generation)
-- Source: TypeScript trainerConfigs with isBoss=true, derivedType!=RIVAL, hasVoucher=true
local bossTrainerConfigs = {
    -- Gym Leaders (moneyMultiplier < 10 = PLUS, >= 10 = PREMIUM)
    GYM_LEADER_BROCK = {name = "Brock", title = "Boulder Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_MISTY = {name = "Misty", title = "Cascade Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_LT_SURGE = {name = "Lt. Surge", title = "Thunder Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_ERIKA = {name = "Erika", title = "Rainbow Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_JANINE = {name = "Janine", title = "Soul Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_SABRINA = {name = "Sabrina", title = "Marsh Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_BLAINE = {name = "Blaine", title = "Volcano Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_GIOVANNI = {name = "Giovanni", title = "Earth Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},

    -- Elite Four and Champions (moneyMultiplier >= 10 = PREMIUM)
    ELITE_FOUR_LORELEI = {name = "Lorelei", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    ELITE_FOUR_BRUNO = {name = "Bruno", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    ELITE_FOUR_AGATHA = {name = "Agatha", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    ELITE_FOUR_LANCE = {name = "Lance", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    CHAMPION_BLUE = {name = "Blue", title = nil, moneyMultiplier = 50, isBoss = true, hasVoucher = true},

    -- Additional Gym Leaders (Gen 2-9)
    GYM_LEADER_FALKNER = {name = "Falkner", title = "Zephyr Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_BUGSY = {name = "Bugsy", title = "Hive Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_WHITNEY = {name = "Whitney", title = "Plain Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_MORTY = {name = "Morty", title = "Fog Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_CHUCK = {name = "Chuck", title = "Storm Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_JASMINE = {name = "Jasmine", title = "Mineral Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_PRYCE = {name = "Pryce", title = "Glacier Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},
    GYM_LEADER_CLAIR = {name = "Clair", title = "Rising Badge", moneyMultiplier = 8, isBoss = true, hasVoucher = true},

    -- More Elite Four members
    ELITE_FOUR_WILL = {name = "Will", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    ELITE_FOUR_KOGA = {name = "Koga", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    ELITE_FOUR_KAREN = {name = "Karen", title = nil, moneyMultiplier = 25, isBoss = true, hasVoucher = true},
    CHAMPION_LANCE = {name = "Lance", title = nil, moneyMultiplier = 50, isBoss = true, hasVoucher = true},
}

-- Initialize achievement-based vouchers
-- Source: TypeScript voucher.ts initVouchers() lines 91-102
local function initAchievementVouchers()
    local achievementVouchers = {}

    -- Currently only CLASSIC_VICTORY achievement awards a voucher (score = 250)
    local classicVictoryScore = 250  -- From achievement-engine.lua

    -- Tier calculation based on achievement score
    local voucherType
    if classicVictoryScore >= 150 then
        voucherType = VoucherType.GOLDEN   -- score 250 = GOLDEN
    elseif classicVictoryScore >= 100 then
        voucherType = VoucherType.PREMIUM
    elseif classicVictoryScore >= 75 then
        voucherType = VoucherType.PLUS
    else
        voucherType = VoucherType.REGULAR
    end

    achievementVouchers["CLASSIC_VICTORY"] = {
        id = "CLASSIC_VICTORY",
        voucherType = voucherType,
        description = "Win Classic mode",
        iconImage = VoucherIcons[voucherType],
        tier = getTierFromVoucherType(voucherType),
        source = "Achievement"
    }

    return achievementVouchers
end

-- Initialize boss trainer vouchers
-- Source: TypeScript voucher.ts initVouchers() lines 104-118
local function initBossTrainerVouchers()
    local bossVouchers = {}

    -- Filter trainer configs for boss trainers with vouchers
    for trainerKey, config in pairs(bossTrainerConfigs) do
        if config.isBoss and config.hasVoucher then
            -- Tier determination based on money multiplier
            local voucherType
            if config.moneyMultiplier < 10 then
                voucherType = VoucherType.PLUS      -- Gym Leaders
            else
                voucherType = VoucherType.PREMIUM   -- Elite Four/Champions
            end

            local title = config.title and (" (" .. config.title .. ")") or ""
            local description = "Defeat " .. config.name .. title

            bossVouchers[trainerKey] = {
                id = trainerKey,
                voucherType = voucherType,
                description = description,
                iconImage = VoucherIcons[voucherType],
                tier = getTierFromVoucherType(voucherType),
                source = "BossTrainer"
            }
        end
    end

    return bossVouchers
end

-- Initialize all vouchers
local allVouchers = {}

local function initializeVouchers()
    local achievementVouchers = initAchievementVouchers()
    local bossVouchers = initBossTrainerVouchers()

    -- Merge all vouchers
    for k, v in pairs(achievementVouchers) do
        allVouchers[k] = v
    end
    for k, v in pairs(bossVouchers) do
        allVouchers[k] = v
    end
end

-- Initialize vouchers on process load
initializeVouchers()

-- Player voucher state storage (in-memory, client manages persistence)
local playerVoucherStates = {}

-- Get player voucher state (initialize if not exists)
local function getPlayerVoucherState(playerId)
    if not playerVoucherStates[playerId] then
        playerVoucherStates[playerId] = {
            voucherUnlocks = {},    -- voucherId -> timestamp
            voucherCounts = {       -- voucherType -> count
                [VoucherType.REGULAR] = 0,
                [VoucherType.PLUS] = 0,
                [VoucherType.PREMIUM] = 0,
                [VoucherType.GOLDEN] = 0
            }
        }
    end
    return playerVoucherStates[playerId]
end

-- Award voucher to player
-- Source: TypeScript trainer-victory-phase.ts lines 29-54, game-over-phase.ts lines 313-316
local function awardVoucher(playerId, voucherId, timestamp)
    if not playerId or playerId == "" then
        return {success = false, error = "PlayerId required"}
    end

    if not voucherId or voucherId == "" then
        return {success = false, error = "VoucherId required"}
    end

    -- Check if voucher exists
    local voucher = allVouchers[voucherId]
    if not voucher then
        return {success = false, error = "Voucher not found: " .. voucherId}
    end

    local playerState = getPlayerVoucherState(playerId)

    -- Check if already awarded
    if playerState.voucherUnlocks[voucherId] then
        return {
            success = false,
            alreadyAwarded = true,
            voucherType = voucher.voucherType,
            awardTimestamp = playerState.voucherUnlocks[voucherId],
            newCount = playerState.voucherCounts[voucher.voucherType]
        }
    end

    -- Award voucher: record unlock timestamp and increment count
    playerState.voucherUnlocks[voucherId] = timestamp
    playerState.voucherCounts[voucher.voucherType] = playerState.voucherCounts[voucher.voucherType] + 1

    return {
        success = true,
        alreadyAwarded = false,
        voucherType = voucher.voucherType,
        awardTimestamp = timestamp,
        newCount = playerState.voucherCounts[voucher.voucherType]
    }
end

-- Validate voucher (check if awarded)
-- Source: TypeScript battle-scene.ts validateVoucher method
local function validateVoucher(playerId, voucherId)
    if not playerId or playerId == "" then
        return {valid = false, error = "PlayerId required"}
    end

    if not voucherId or voucherId == "" then
        return {valid = false, error = "VoucherId required"}
    end

    local voucher = allVouchers[voucherId]
    if not voucher then
        return {valid = false, error = "Voucher not found: " .. voucherId}
    end

    local playerState = getPlayerVoucherState(playerId)
    local isAwarded = playerState.voucherUnlocks[voucherId] ~= nil

    return {
        valid = true,
        isAwarded = isAwarded,
        awardTimestamp = playerState.voucherUnlocks[voucherId],
        voucherType = voucher.voucherType
    }
end

-- Get player voucher data
local function getPlayerVouchers(playerId, includeMetadata)
    if not playerId or playerId == "" then
        return {error = "PlayerId required"}
    end

    local playerState = getPlayerVoucherState(playerId)

    -- Calculate totals
    local totalAwarded = 0
    for _ in pairs(playerState.voucherUnlocks) do
        totalAwarded = totalAwarded + 1
    end

    local totalAvailable = 0
    for _, count in pairs(playerState.voucherCounts) do
        totalAvailable = totalAvailable + count
    end

    local result = {
        voucherUnlocks = playerState.voucherUnlocks,
        voucherCounts = playerState.voucherCounts,
        totalVouchersAwarded = totalAwarded,
        totalVouchersAvailable = totalAvailable
    }

    -- Optionally include metadata
    if includeMetadata then
        result.metadata = {}
        for voucherId, timestamp in pairs(playerState.voucherUnlocks) do
            local voucher = allVouchers[voucherId]
            if voucher then
                result.metadata[voucherId] = {
                    voucherType = voucher.voucherType,
                    description = voucher.description,
                    iconImage = voucher.iconImage,
                    tier = voucher.tier,
                    source = voucher.source
                }
            end
        end
    end

    return result
end

-- Get voucher metadata
local function getVoucherMetadata(voucherId)
    if voucherId and voucherId ~= "" then
        -- Single voucher metadata
        local voucher = allVouchers[voucherId]
        if not voucher then
            return {error = "Voucher not found: " .. voucherId}
        end
        return {voucher = voucher}
    else
        -- All vouchers metadata
        local vouchers = {}
        for _, voucher in pairs(allVouchers) do
            table.insert(vouchers, voucher)
        end
        return {
            vouchers = vouchers,
            totalVouchers = #vouchers
        }
    end
end

-- Consume voucher (decrement count)
local function consumeVoucher(playerId, voucherType, quantity)
    if not playerId or playerId == "" then
        return {success = false, error = "PlayerId required"}
    end

    if not voucherType then
        return {success = false, error = "VoucherType required"}
    end

    if not quantity or quantity <= 0 then
        return {success = false, error = "Invalid quantity"}
    end

    local playerState = getPlayerVoucherState(playerId)

    -- Check sufficient vouchers
    local currentCount = playerState.voucherCounts[voucherType] or 0
    if currentCount < quantity then
        return {
            success = false,
            error = "Insufficient vouchers",
            currentCount = currentCount,
            requestedQuantity = quantity
        }
    end

    -- Consume vouchers
    playerState.voucherCounts[voucherType] = currentCount - quantity

    return {
        success = true,
        remainingCount = playerState.voucherCounts[voucherType],
        consumedQuantity = quantity
    }
end

-- ============================================================================
-- AO Message Handlers
-- ============================================================================

-- Handler: Award Voucher
Handlers.add("award-voucher",
    Handlers.utils.hasMatchingTag("Action", "AwardVoucher"),
    function(msg)
        local playerId = msg.PlayerId
        local voucherId = msg.VoucherId
        local source = msg.Source or "Unknown"
        local timestamp = tonumber(msg.Timestamp) or 0

        local result = awardVoucher(playerId, voucherId, timestamp)

        if result.success then
            ao.send({
                Target = msg.From,
                Action = "VoucherAwarded",
                PlayerId = playerId,
                VoucherId = voucherId,
                VoucherType = tostring(result.voucherType),
                Success = "true",
                AlreadyAwarded = "false",
                NewCount = tostring(result.newCount),
                AwardTimestamp = tostring(result.awardTimestamp),
                Timestamp = tostring(timestamp)
            })
        elseif result.alreadyAwarded then
            ao.send({
                Target = msg.From,
                Action = "VoucherAwarded",
                PlayerId = playerId,
                VoucherId = voucherId,
                VoucherType = tostring(result.voucherType),
                Success = "false",
                AlreadyAwarded = "true",
                NewCount = tostring(result.newCount),
                AwardTimestamp = tostring(result.awardTimestamp),
                Timestamp = tostring(timestamp)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                VoucherId = voucherId,
                Timestamp = tostring(timestamp)
            })
        end
    end
)

-- Handler: Validate Voucher
Handlers.add("validate-voucher",
    Handlers.utils.hasMatchingTag("Action", "ValidateVoucher"),
    function(msg)
        local playerId = msg.PlayerId
        local voucherId = msg.VoucherId
        local timestamp = tonumber(msg.Timestamp) or 0

        local result = validateVoucher(playerId, voucherId)

        if result.valid then
            ao.send({
                Target = msg.From,
                Action = "VoucherValidated",
                PlayerId = playerId,
                VoucherId = voucherId,
                IsAwarded = tostring(result.isAwarded),
                AwardTimestamp = result.awardTimestamp and tostring(result.awardTimestamp) or "",
                VoucherType = tostring(result.voucherType),
                Timestamp = tostring(timestamp)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                VoucherId = voucherId,
                Timestamp = tostring(timestamp)
            })
        end
    end
)

-- Handler: Get Player Vouchers
Handlers.add("get-player-vouchers",
    Handlers.utils.hasMatchingTag("Action", "GetPlayerVouchers"),
    function(msg)
        local playerId = msg.PlayerId
        local includeMetadata = msg.IncludeMetadata == "true"
        local timestamp = tonumber(msg.Timestamp) or 0

        local result = getPlayerVouchers(playerId, includeMetadata)

        if result.error then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                Timestamp = tostring(timestamp)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "PlayerVoucherData",
                PlayerId = playerId,
                Data = json.encode(result),
                Timestamp = tostring(timestamp)
            })
        end
    end
)

-- Handler: Get Voucher Metadata
Handlers.add("get-voucher-metadata",
    Handlers.utils.hasMatchingTag("Action", "GetVoucherMetadata"),
    function(msg)
        local voucherId = msg.VoucherId  -- Optional: specific voucher or nil for all
        local timestamp = tonumber(msg.Timestamp) or 0

        local result = getVoucherMetadata(voucherId)

        if result.error then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                Timestamp = tostring(timestamp)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "VoucherMetadata",
                Data = json.encode(result),
                Timestamp = tostring(timestamp)
            })
        end
    end
)

-- Handler: Consume Voucher
Handlers.add("consume-voucher",
    Handlers.utils.hasMatchingTag("Action", "ConsumeVoucher"),
    function(msg)
        local playerId = msg.PlayerId
        local voucherType = tonumber(msg.VoucherType)
        local quantity = tonumber(msg.Quantity) or 1
        local timestamp = tonumber(msg.Timestamp) or 0

        local result = consumeVoucher(playerId, voucherType, quantity)

        if result.success then
            ao.send({
                Target = msg.From,
                Action = "VoucherConsumed",
                PlayerId = playerId,
                VoucherType = tostring(voucherType),
                Quantity = tostring(quantity),
                Success = "true",
                RemainingCount = tostring(result.remainingCount),
                Timestamp = tostring(timestamp)
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = result.error,
                VoucherType = tostring(voucherType),
                RequestedQuantity = tostring(quantity),
                CurrentCount = result.currentCount and tostring(result.currentCount) or "0",
                Timestamp = tostring(timestamp)
            })
        end
    end
)

-- Handler: Info (ADP v1.0 compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local timestamp = tonumber(msg.Timestamp) or 0

        -- Count vouchers by source
        local achievementVouchers = 0
        local bossVouchers = 0
        for _, voucher in pairs(allVouchers) do
            if voucher.source == "Achievement" then
                achievementVouchers = achievementVouchers + 1
            elseif voucher.source == "BossTrainer" then
                bossVouchers = bossVouchers + 1
            end
        end

        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Voucher Reward Engine",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    processId = ao.id,
                    capabilities = {
                        "AwardVoucher",
                        "ValidateVoucher",
                        "GetPlayerVouchers",
                        "GetVoucherMetadata",
                        "ConsumeVoucher"
                    },
                    messageSchemas = {
                        AwardVoucher = {
                            required = {"Action", "PlayerId", "VoucherId", "Source", "Timestamp"},
                            optional = {}
                        },
                        ValidateVoucher = {
                            required = {"Action", "PlayerId", "VoucherId", "Timestamp"},
                            optional = {}
                        },
                        GetPlayerVouchers = {
                            required = {"Action", "PlayerId", "Timestamp"},
                            optional = {"IncludeMetadata"}
                        },
                        GetVoucherMetadata = {
                            required = {"Action", "Timestamp"},
                            optional = {"VoucherId"}
                        },
                        ConsumeVoucher = {
                            required = {"Action", "PlayerId", "VoucherType", "Quantity", "Timestamp"},
                            optional = {}
                        }
                    }
                },
                handlers = {"AwardVoucher", "ValidateVoucher", "GetPlayerVouchers", "GetVoucherMetadata", "ConsumeVoucher", "Info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    description = "Manages egg voucher rewards from achievements and boss trainer victories"
                },
                voucherStats = {
                    totalVouchers = achievementVouchers + bossVouchers,
                    achievementVouchers = achievementVouchers,
                    bossTrainerVouchers = bossVouchers,
                    voucherTypes = {
                        REGULAR = VoucherType.REGULAR,
                        PLUS = VoucherType.PLUS,
                        PREMIUM = VoucherType.PREMIUM,
                        GOLDEN = VoucherType.GOLDEN
                    }
                }
            }),
            Timestamp = tostring(timestamp)
        })
    end
)

-- Count vouchers
local voucherCount = 0
for _ in pairs(allVouchers) do
    voucherCount = voucherCount + 1
end

print("Voucher Reward Engine initialized with " .. voucherCount .. " vouchers")
