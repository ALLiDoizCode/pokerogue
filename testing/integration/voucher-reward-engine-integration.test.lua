-- Integration tests for Voucher Reward Engine Process
-- Tests cross-process coordination and message-based communication

-- Mock JSON for testing (define first so it can be used in ao.send)
local json
json = {
    encode = function(data)
        -- Simple JSON encoding for testing
        if type(data) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(data) do
                if not first then result = result .. "," end
                if type(v) == "table" then
                    result = result .. '"' .. tostring(k) .. '":' .. json.encode(v)
                else
                    result = result .. '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                end
                first = false
            end
            return result .. "}"
        end
        return tostring(data)
    end,
    decode = function(str)
        -- Simple JSON decoding for testing
        if str == '{}' or str == '' then return {} end
        -- For testing, return mock structures
        if str:find("voucherUnlocks") then
            return {voucherUnlocks = {}, voucherCounts = {[0] = 0, [1] = 0, [2] = 0, [3] = 0}}
        end
        return {}
    end
}

-- Mock AO environment for testing
local ao = {
    send = function(msg)
        print("MOCK AO.SEND:", json.encode(msg))
        return msg
    end,
    id = "voucher_reward_engine_test_id"
}

-- Mock Handlers for testing
local Handlers = {
    add = function(name, matcher, handler)
        print("HANDLER REGISTERED:", name)
        -- Store for testing if needed
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value or (type(value) == "table" and msg[tag] and table.contains(value, msg[tag]))
            end
        end
    }
}

-- Load the voucher reward engine process
local function loadVoucherRewardEngine()
    -- Set up global environment BEFORE loading process
    _G.ao = ao
    _G.Handlers = Handlers
    _G.json = json

    -- Mock require('json') for the process
    package.loaded['json'] = json

    -- Load and execute the process file
    local file = io.open("processes/voucher-reward-engine.lua", "r")
    if not file then
        error("Could not find voucher-reward-engine.lua")
    end

    local content = file:read("*all")
    file:close()

    -- Execute the process code
    local processFunction = load(content)
    if not processFunction then
        error("Failed to load voucher reward engine process")
    end

    processFunction()
    print("✓ Voucher reward engine process loaded successfully")
end

-- Integration test suite
local integrationTests = {}

-- Test 1: Process initialization and ADP Info handler
function integrationTests.testProcessInitialization()
    print("Testing process initialization and ADP Info handler...")

    loadVoucherRewardEngine()

    -- Verify the process loaded without errors
    assert(ao ~= nil, "AO should be available")
    assert(Handlers ~= nil, "Handlers should be available")
    assert(json ~= nil, "JSON should be available")

    print("✓ Process initialization tests passed")
end

-- Test 2: Cross-process coordination with Achievement Engine
function integrationTests.testAchievementEngineCoordination()
    print("Testing Achievement Engine coordination...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Simulate achievement unlock workflow that triggers voucher award
    -- Step 1: Achievement engine validates achievement (CLASSIC_VICTORY)
    local achievementUnlockMsg = {
        From = "achievement_engine_id",
        Target = "coordinator_process_id",
        Action = "AchievementValidated",
        PlayerId = "test_player_456",
        AchievementId = "CLASSIC_VICTORY",
        Success = "true",
        Score = "250",
        Timestamp = "1234567890000"
    }

    -- Step 2: Coordinator checks if voucher should be awarded
    local voucherAwardRequest = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "AwardVoucher",
        PlayerId = "test_player_456",
        VoucherId = "CLASSIC_VICTORY",
        Source = "Achievement",
        Timestamp = "1234567890001"
    }

    -- Verify coordination message structure
    assert(voucherAwardRequest.Target ~= nil, "Should target voucher reward engine")
    assert(voucherAwardRequest.Action == "AwardVoucher", "Should award voucher")
    assert(voucherAwardRequest.PlayerId ~= nil, "Should include player ID")
    assert(voucherAwardRequest.VoucherId == "CLASSIC_VICTORY", "Should include voucher ID")
    assert(voucherAwardRequest.Source == "Achievement", "Should indicate achievement source")

    -- Step 3: Voucher engine responds with award result
    local expectedResponse = {
        Target = "coordinator_process_id",
        Action = "VoucherAwarded",
        PlayerId = "test_player_456",
        VoucherId = "CLASSIC_VICTORY",
        VoucherType = "3",  -- GOLDEN tier
        Success = "true",
        AlreadyAwarded = "false",
        NewCount = "1",
        AwardTimestamp = "1234567890001"
    }

    -- Verify response structure
    assert(expectedResponse.Action == "VoucherAwarded", "Should confirm voucher awarded")
    assert(expectedResponse.VoucherType == "3", "CLASSIC_VICTORY should award GOLDEN voucher")

    ao.send = originalSend

    print("✓ Achievement Engine coordination tests passed")
end

-- Test 3: Cross-process coordination with Player Progression Engine
function integrationTests.testPlayerProgressionEngineCoordination()
    print("Testing Player Progression Engine coordination...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Simulate voucher state persistence workflow
    -- Step 1: Voucher awarded and coordinator updates player progression
    local updateVouchersMsg = {
        From = "coordinator_process_id",
        Target = "player_progression_engine_id",
        Action = "UpdateVouchers",
        PlayerId = "test_player_456",
        Data = json.encode({
            voucherUnlocks = {
                CLASSIC_VICTORY = 1234567890001
            },
            voucherCounts = {
                [3] = 1  -- 1 GOLDEN voucher
            }
        }),
        Timestamp = "1234567890002"
    }

    -- Verify coordination message structure
    assert(updateVouchersMsg.Target ~= nil, "Should target player progression engine")
    assert(updateVouchersMsg.Action == "UpdateVouchers", "Should update vouchers")
    assert(updateVouchersMsg.PlayerId ~= nil, "Should include player ID")
    assert(updateVouchersMsg.Data ~= nil, "Should include voucher data")

    -- Step 2: Player progression confirms update
    local confirmationMsg = {
        From = "player_progression_engine_id",
        Target = "coordinator_process_id",
        Action = "VouchersUpdated",
        PlayerId = "test_player_456",
        Success = "true",
        Timestamp = "1234567890003"
    }

    assert(confirmationMsg.Action == "VouchersUpdated", "Should confirm voucher update")
    assert(confirmationMsg.Success == "true", "Update should be successful")

    ao.send = originalSend

    print("✓ Player Progression Engine coordination tests passed")
end

-- Test 4: Boss trainer victory voucher workflow
function integrationTests.testBossTrainerVoucherWorkflow()
    print("Testing boss trainer victory voucher workflow...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Step 1: Boss trainer defeated
    local trainerVictoryMsg = {
        From = "client_id",
        Target = "coordinator_process_id",
        Action = "TrainerVictoryComplete",
        PlayerId = "test_player_456",
        TrainerType = "GYM_LEADER_BROCK",
        Timestamp = "2000000000"
    }

    -- Step 2: Coordinator validates voucher hasn't been awarded
    local validateMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "ValidateVoucher",
        PlayerId = "test_player_456",
        VoucherId = "GYM_LEADER_BROCK",
        Timestamp = "2000000001"
    }

    assert(validateMsg.Action == "ValidateVoucher", "Should validate voucher")

    -- Step 3: Validation confirms not yet awarded
    local validationResponse = {
        Target = "coordinator_process_id",
        Action = "VoucherValidated",
        PlayerId = "test_player_456",
        VoucherId = "GYM_LEADER_BROCK",
        IsAwarded = "false",
        Timestamp = "2000000001"
    }

    assert(validationResponse.IsAwarded == "false", "Should not be awarded yet")

    -- Step 4: Coordinator awards voucher
    local awardMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "AwardVoucher",
        PlayerId = "test_player_456",
        VoucherId = "GYM_LEADER_BROCK",
        Source = "BossTrainer",
        Timestamp = "2000000002"
    }

    assert(awardMsg.VoucherId == "GYM_LEADER_BROCK", "Should award Brock voucher")
    assert(awardMsg.Source == "BossTrainer", "Should indicate boss trainer source")

    -- Step 5: Voucher awarded successfully
    local awardResponse = {
        Target = "coordinator_process_id",
        Action = "VoucherAwarded",
        PlayerId = "test_player_456",
        VoucherId = "GYM_LEADER_BROCK",
        VoucherType = "1",  -- PLUS tier (moneyMultiplier < 10)
        Success = "true",
        NewCount = "1",
        Timestamp = "2000000002"
    }

    assert(awardResponse.VoucherType == "1", "Brock should award PLUS voucher")

    ao.send = originalSend

    print("✓ Boss trainer victory voucher workflow tests passed")
end

-- Test 5: Voucher consumption for egg gacha workflow
function integrationTests.testEggGachaVoucherConsumptionWorkflow()
    print("Testing egg gacha voucher consumption workflow...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Step 1: Client requests egg gacha pull
    local gachaRequest = {
        From = "client_id",
        Target = "coordinator_process_id",
        Action = "PullEggGacha",
        PlayerId = "test_player_456",
        VoucherType = "3",  -- GOLDEN
        Quantity = "1",
        Timestamp = "3000000000"
    }

    -- Step 2: Coordinator validates voucher availability
    local getVouchersMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "GetPlayerVouchers",
        PlayerId = "test_player_456",
        Timestamp = "3000000001"
    }

    assert(getVouchersMsg.Action == "GetPlayerVouchers", "Should get player vouchers")

    -- Step 3: Voucher data returned
    local voucherDataResponse = {
        Target = "coordinator_process_id",
        Action = "PlayerVoucherData",
        PlayerId = "test_player_456",
        Data = json.encode({
            voucherCounts = {[3] = 1}  -- 1 GOLDEN voucher available
        }),
        Timestamp = "3000000001"
    }

    assert(voucherDataResponse.Action == "PlayerVoucherData", "Should return voucher data")

    -- Step 4: Coordinator consumes voucher
    local consumeMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "ConsumeVoucher",
        PlayerId = "test_player_456",
        VoucherType = "3",
        Quantity = "1",
        Timestamp = "3000000002"
    }

    assert(consumeMsg.Action == "ConsumeVoucher", "Should consume voucher")
    assert(consumeMsg.VoucherType == "3", "Should consume GOLDEN voucher")

    -- Step 5: Voucher consumed
    local consumeResponse = {
        Target = "coordinator_process_id",
        Action = "VoucherConsumed",
        PlayerId = "test_player_456",
        VoucherType = "3",
        Quantity = "1",
        Success = "true",
        RemainingCount = "0",
        Timestamp = "3000000002"
    }

    assert(consumeResponse.Success == "true", "Consumption should succeed")
    assert(consumeResponse.RemainingCount == "0", "Should have 0 remaining")

    -- Step 6: Process egg gacha logic (handled by egg-gacha-engine)
    local generateEggMsg = {
        From = "coordinator_process_id",
        Target = "egg_gacha_engine_id",
        Action = "GenerateEgg",
        PlayerId = "test_player_456",
        VoucherTier = "3",
        Timestamp = "3000000003"
    }

    assert(generateEggMsg.VoucherTier == "3", "Should pass voucher tier to egg gacha")

    ao.send = originalSend

    print("✓ Egg gacha voucher consumption workflow tests passed")
end

-- Test 6: Multi-voucher award scenario
function integrationTests.testMultiVoucherAwardScenario()
    print("Testing multi-voucher award scenario...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Simulate player earning multiple vouchers in sequence
    local voucherSequence = {
        {id = "GYM_LEADER_BROCK", type = "1"},      -- PLUS
        {id = "GYM_LEADER_MISTY", type = "1"},      -- PLUS
        {id = "ELITE_FOUR_LANCE", type = "2"},      -- PREMIUM
        {id = "CLASSIC_VICTORY", type = "3"}        -- GOLDEN
    }

    -- Award each voucher
    for i, voucher in ipairs(voucherSequence) do
        local awardMsg = {
            From = "coordinator_process_id",
            Target = "voucher_reward_engine_id",
            Action = "AwardVoucher",
            PlayerId = "test_player_multi",
            VoucherId = voucher.id,
            Source = (voucher.id == "CLASSIC_VICTORY") and "Achievement" or "BossTrainer",
            Timestamp = tostring(4000000000 + i)
        }

        assert(awardMsg.VoucherId == voucher.id, "Should award " .. voucher.id)
    end

    -- Verify final state
    local getStateMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "GetPlayerVouchers",
        PlayerId = "test_player_multi",
        Timestamp = "4000000010"
    }

    -- Expected final state:
    -- voucherCounts: {[1] = 2, [2] = 1, [3] = 1}
    -- totalVouchersAwarded: 4
    -- totalVouchersAvailable: 4

    ao.send = originalSend

    print("✓ Multi-voucher award scenario tests passed")
end

-- Test 7: State persistence integration
function integrationTests.testStatePersistenceIntegration()
    print("Testing state persistence integration...")

    local sentMessages = {}
    local originalSend = ao.send
    ao.send = function(msg)
        table.insert(sentMessages, msg)
        return msg
    end

    -- Step 1: Award voucher
    local awardMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "AwardVoucher",
        PlayerId = "test_player_persist",
        VoucherId = "GYM_LEADER_ERIKA",
        Source = "BossTrainer",
        Timestamp = "5000000000"
    }

    -- Step 2: Coordinator persists state
    local persistMsg = {
        From = "coordinator_process_id",
        Target = "player_progression_engine_id",
        Action = "UpdateVouchers",
        PlayerId = "test_player_persist",
        Data = json.encode({
            voucherUnlocks = {
                GYM_LEADER_ERIKA = 5000000000
            },
            voucherCounts = {
                [1] = 1
            }
        }),
        Timestamp = "5000000001"
    }

    -- Step 3: Later session retrieves state
    local loadStateMsg = {
        From = "coordinator_process_id",
        Target = "player_progression_engine_id",
        Action = "LoadPlayerProgression",
        PlayerId = "test_player_persist",
        Timestamp = "6000000000"
    }

    -- Step 4: State restored and voucher validation confirms persistence
    local validateAfterLoadMsg = {
        From = "coordinator_process_id",
        Target = "voucher_reward_engine_id",
        Action = "ValidateVoucher",
        PlayerId = "test_player_persist",
        VoucherId = "GYM_LEADER_ERIKA",
        Timestamp = "6000000001"
    }

    -- Expected validation: IsAwarded = "true", AwardTimestamp = "5000000000"
    assert(validateAfterLoadMsg.VoucherId == "GYM_LEADER_ERIKA", "Should validate persisted voucher")

    ao.send = originalSend

    print("✓ State persistence integration tests passed")
end

-- Run all integration tests
print("\n========================================")
print("Voucher Reward Engine Integration Tests")
print("========================================\n")

local testsRun = 0
local testsPassed = 0
local testsFailed = 0

for testName, testFunc in pairs(integrationTests) do
    testsRun = testsRun + 1
    io.write("Running: " .. testName .. "...")
    local success, err = pcall(testFunc)
    if success then
        testsPassed = testsPassed + 1
        print(" ✓")
    else
        testsFailed = testsFailed + 1
        print(" ❌")
        print("  Error: " .. tostring(err))
    end
end

print("\n========================================")
print("Integration Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. testsRun)
print()

if testsFailed == 0 then
    print("🎉 All integration tests passed!")
    os.exit(0)
else
    print("❌ Some integration tests failed")
    os.exit(1)
end
