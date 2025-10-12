-- Aolite Unit Tests for Passive Ability Engine Process
-- Tests passive ability lookup, unlock/upgrade, enable/disable, and trigger evaluation
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.passive-ability-engine"
local processId = "test-passive-ability-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Passive Ability Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Get Passive Ability for Species (Basic)
print("📝 Test 1: Get Passive Ability for Bulbasaur at tier 0")
local passiveResponse = sendMessage("GetPassiveAbility", {
    SpeciesId = "BULBASAUR",
    UpgradeLevel = "0"
})
if passiveResponse and passiveResponse.Action == "PassiveAbilityData" and passiveResponse.Success == "true" then
    print("✅ Get passive ability test passed")
else
    error("❌ Get passive ability test failed")
end

-- Test 2: Get Passive Ability with Multiple Tiers
print("📝 Test 2: Get Passive Ability for Charizard (Multiple Tiers)")
local multiTierResponse = sendMessage("GetPassiveAbility", {
    SpeciesId = "CHARIZARD",
    UpgradeLevel = "0"
})
if multiTierResponse and multiTierResponse.Action == "PassiveAbilityData" then
    print("✅ Multi-tier passive test passed")
else
    error("❌ Multi-tier passive test failed")
end

-- Test 3: Get Passive Ability at Higher Tier
print("📝 Test 3: Get Charizard Passive at Tier 2")
local tierResponse = sendMessage("GetPassiveAbility", {
    SpeciesId = "CHARIZARD",
    UpgradeLevel = "2"
})
if tierResponse and tierResponse.Action == "PassiveAbilityData" and tierResponse.UpgradeLevel == "2" then
    print("✅ Higher tier passive test passed")
else
    error("❌ Higher tier passive test failed")
end

-- Test 4: Get Passive for Invalid Species
print("📝 Test 4: Get Passive for Invalid Species")
local invalidResponse = sendMessage("GetPassiveAbility", {
    SpeciesId = "INVALID_POKEMON_999"
})
if invalidResponse and invalidResponse.Action == "Error" then
    print("✅ Invalid species test passed")
else
    error("❌ Invalid species test failed")
end

-- Test 5: Missing SpeciesId Parameter
print("📝 Test 5: Missing SpeciesId Parameter")
local missingResponse = sendMessage("GetPassiveAbility")
if missingResponse and missingResponse.Action == "Error" then
    print("✅ Missing parameter test passed")
else
    error("❌ Missing parameter test failed")
end

-- Test 6: Unlock Passive for Player
print("📝 Test 6: Unlock Passive for Player")
local unlockResponse = sendMessage("UnlockPassive", {
    PlayerId = "player_test_1",
    SpeciesId = "PIKACHU",
    Cost = "50"
})
if unlockResponse and unlockResponse.Action == "PassiveUnlocked" and unlockResponse.Success == "true" then
    print("✅ Unlock passive test passed")
else
    error("❌ Unlock passive test failed")
end

-- Test 7: Unlock Already Unlocked Passive
print("📝 Test 7: Unlock Already Unlocked Passive")
local alreadyUnlockedResponse = sendMessage("UnlockPassive", {
    PlayerId = "player_test_2",
    SpeciesId = "BULBASAUR",
    Cost = "50"
})
-- Unlock again
local duplicateResponse = sendMessage("UnlockPassive", {
    PlayerId = "player_test_2",
    SpeciesId = "BULBASAUR",
    Cost = "50"
})
if duplicateResponse and duplicateResponse.Action == "Error" then
    print("✅ Duplicate unlock test passed")
else
    error("❌ Duplicate unlock test failed")
end

-- Test 8: Upgrade Passive Tier
print("📝 Test 8: Upgrade Passive from Tier 0 to Tier 1")
-- First unlock
sendMessage("UnlockPassive", {
    PlayerId = "player_test_3",
    SpeciesId = "CHARIZARD",
    Cost = "50"
})
-- Then upgrade
local upgradeResponse = sendMessage("UpgradePassive", {
    PlayerId = "player_test_3",
    SpeciesId = "CHARIZARD",
    ToTier = "1",
    Cost = "100"
})
if upgradeResponse and upgradeResponse.Action == "PassiveUnlocked" and upgradeResponse.NewTier == "1" then
    print("✅ Upgrade passive test passed")
else
    error("❌ Upgrade passive test failed")
end

-- Test 9: Upgrade Without Unlocking First
print("📝 Test 9: Upgrade Without Unlocking First")
local upgradeNoUnlockResponse = sendMessage("UpgradePassive", {
    PlayerId = "player_new",
    SpeciesId = "CHARIZARD",
    ToTier = "1",
    Cost = "100"
})
if upgradeNoUnlockResponse and upgradeNoUnlockResponse.Action == "Error" then
    print("✅ Upgrade without unlock test passed")
else
    error("❌ Upgrade without unlock test failed")
end

-- Test 10: Enable Passive for Pokemon
print("📝 Test 10: Enable Passive for Pokemon Instance")
local enableResponse = sendMessage("EnablePassive", {
    PokemonId = "pokemon_abc123",
    Enable = "true"
})
if enableResponse and enableResponse.Action == "PassiveStateUpdated" and enableResponse.Success == "true" then
    print("✅ Enable passive test passed")
else
    error("❌ Enable passive test failed")
end

-- Test 11: Disable Passive for Pokemon
print("📝 Test 11: Disable Passive for Pokemon Instance")
local disableResponse = sendMessage("EnablePassive", {
    PokemonId = "pokemon_xyz789",
    Enable = "false"
})
if disableResponse and disableResponse.Enabled == "false" then
    print("✅ Disable passive test passed")
else
    error("❌ Disable passive test failed")
end

-- Test 12: Can Apply Passive (Unlocked and Enabled)
print("📝 Test 12: Can Apply Passive When Unlocked and Enabled")
-- Unlock passive
sendMessage("UnlockPassive", {
    PlayerId = "player_apply_test",
    SpeciesId = "PIKACHU",
    Cost = "50"
})
-- Enable passive
sendMessage("EnablePassive", {
    PokemonId = "pokemon_apply_test",
    Enable = "true"
})
-- Check if can apply
local canApplyResponse = sendMessage("CanApplyPassive", {
    PokemonId = "pokemon_apply_test",
    PlayerId = "player_apply_test",
    SpeciesId = "PIKACHU"
})
if canApplyResponse and canApplyResponse.Action == "PassiveApplicationResult" and canApplyResponse.CanApply == "true" then
    print("✅ Can apply passive test passed")
else
    error("❌ Can apply passive test failed")
end

-- Test 13: Check Ability Stacking (Different Abilities)
print("📝 Test 13: Check Ability Stacking (Different Abilities)")
local stackingData = json.encode({})
local stackingResponse = sendMessage("CheckAbilityStacking", {
    PassiveAbilityId = "BEAST_BOOST",
    ActiveAbilityId = "LEVITATE"
}, stackingData)
if stackingResponse and stackingResponse.Action == "AbilityStackingResult" and stackingResponse.CanStack == "true" then
    print("✅ Ability stacking test passed")
else
    error("❌ Ability stacking test failed")
end

-- Test 14: Check Ability Stacking (Same Ability)
print("📝 Test 14: Check Ability Stacking (Same Ability)")
local sameAbilityData = json.encode({})
local sameAbilityResponse = sendMessage("CheckAbilityStacking", {
    PassiveAbilityId = "BEAST_BOOST",
    ActiveAbilityId = "BEAST_BOOST"
}, sameAbilityData)
if sameAbilityResponse and sameAbilityResponse.CanStack == "false" then
    print("✅ Same ability stacking test passed")
else
    error("❌ Same ability stacking test failed")
end

-- Test 15: Health Check Handler
print("📝 Test 15: Health Check Handler")
local healthResponse = sendMessage("HealthCheck")
if healthResponse and healthResponse.Action == "HealthCheckResponse" and healthResponse.Status == "healthy" then
    print("✅ Health check test passed")
else
    error("❌ Health check test failed")
end

-- Test 16: ADP Info Handler
print("📝 Test 16: ADP Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "InfoResponse" and infoResponse.Success == "true" then
    print("✅ ADP info handler test passed")
else
    error("❌ ADP info handler test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
