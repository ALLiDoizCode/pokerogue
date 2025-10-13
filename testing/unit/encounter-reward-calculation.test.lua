-- Aolite Unit Tests for Encounter Reward Calculation (CORRECT API)
-- Tests reward calculation logic for mystery encounters with various outcomes

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.encounter-reward-engine"
local processId = "test-encounter-reward-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Encounter Reward Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Reward Calculation with Success Outcome
print("📝 Test 1: Reward calculation with success outcome")
local response = sendMessage("CalculateRewards", {
    EncounterType = "MYSTERIOUS_CHEST",
    OptionIndex = "0",
    Outcome = "success",
    WaveIndex = "10"
})

if not response then
    error("❌ Test 1 failed: No response received")
end

if response.Action ~= "SaveState" then
    error("❌ Test 1 failed: Expected SaveState action, got " .. tostring(response.Action))
end

if response.Success ~= "true" then
    error("❌ Test 1 failed: Expected Success to be true")
end

if response.HasRewards ~= "true" then
    error("❌ Test 1 failed: Should have rewards for success")
end

local data = json.decode(response.Data)
if not data.customShopRewards then
    error("❌ Test 1 failed: Should have customShopRewards")
end

if data.customShopRewards.allowLuckUpgrades ~= true then
    error("❌ Test 1 failed: Should allow luck upgrades on success")
end

if data.customShopRewards.rerollMultiplier ~= 1 then
    error("❌ Test 1 failed: Should have normal reroll cost on success")
end

print("✅ Test 1 passed")

-- Test 2: Reward Calculation with Failure Outcome
print("📝 Test 2: Reward calculation with failure outcome")
response = sendMessage("CalculateRewards", {
    EncounterType = "MYSTERIOUS_CHEST",
    OptionIndex = "0",
    Outcome = "failure",
    WaveIndex = "10"
})

if response.Success ~= "true" then
    error("❌ Test 2 failed: Request should succeed")
end

if response.HasRewards ~= "false" then
    error("❌ Test 2 failed: Should have no rewards for failure")
end

data = json.decode(response.Data)
if data.customShopRewards ~= nil then
    error("❌ Test 2 failed: Should have no customShopRewards on failure")
end

print("✅ Test 2 passed")

-- Test 3: Reward Calculation with Partial Outcome
print("📝 Test 3: Reward calculation with partial outcome")
response = sendMessage("CalculateRewards", {
    EncounterType = "MYSTERIOUS_CHEST",
    OptionIndex = "0",
    Outcome = "partial",
    WaveIndex = "10"
})

if response.HasRewards ~= "true" then
    error("❌ Test 3 failed: Should have some rewards for partial success")
end

data = json.decode(response.Data)
if not data.customShopRewards then
    error("❌ Test 3 failed: Should have customShopRewards")
end

if data.customShopRewards.allowLuckUpgrades ~= false then
    error("❌ Test 3 failed: Should not allow luck upgrades on partial")
end

if data.customShopRewards.rerollMultiplier ~= 2 then
    error("❌ Test 3 failed: Should have increased reroll cost on partial")
end

local tiers = data.customShopRewards.guaranteedModifierTiers
if #tiers ~= 2 then
    error("❌ Test 3 failed: Should have 2 guaranteed tiers for partial success")
end

if tiers[1] ~= "COMMON" then
    error("❌ Test 3 failed: First tier should be COMMON")
end

if tiers[2] ~= "UNCOMMON" then
    error("❌ Test 3 failed: Second tier should be UNCOMMON")
end

print("✅ Test 3 passed")

-- Test 4: Guaranteed Modifier Inclusion
print("📝 Test 4: Guaranteed modifier inclusion")
response = sendMessage("CalculateRewards", {
    EncounterType = "MYSTERIOUS_CHEST",
    OptionIndex = "0",
    Outcome = "success",
    WaveIndex = "10"
})

data = json.decode(response.Data)
local guaranteedModifiers = data.customShopRewards.guaranteedModifierTypeFuncs
if not guaranteedModifiers then
    error("❌ Test 4 failed: Should have guaranteed modifiers")
end

if #guaranteedModifiers <= 0 then
    error("❌ Test 4 failed: Should have at least one guaranteed modifier for MYSTERIOUS_CHEST")
end

print("✅ Test 4 passed")

-- Test 5: Egg Reward Generation
print("📝 Test 5: Egg reward generation")
response = sendMessage("CalculateRewards", {
    EncounterType = "POKEMON_BREEDER",
    OptionIndex = "0",
    Outcome = "success",
    WaveIndex = "10"
})

data = json.decode(response.Data)
if not data.eggRewards then
    error("❌ Test 5 failed: Should have egg rewards for POKEMON_BREEDER")
end

if #data.eggRewards <= 0 then
    error("❌ Test 5 failed: Should have at least one egg")
end

local egg = data.eggRewards[1]
if not egg.tier then
    error("❌ Test 5 failed: Egg should have tier")
end

if not egg.sourceType then
    error("❌ Test 5 failed: Egg should have sourceType")
end

if not egg.hatchWaves then
    error("❌ Test 5 failed: Egg should have hatchWaves")
end

if egg.pulled ~= false then
    error("❌ Test 5 failed: Egg should not be pulled initially")
end

print("✅ Test 5 passed")

-- Test 6: Reward Configuration Validity
print("📝 Test 6: Reward configuration validity")
response = sendMessage("CalculateRewards", {
    EncounterType = "MYSTERIOUS_CHEST",
    OptionIndex = "0",
    Outcome = "success",
    WaveIndex = "50"
})

if not response.Action then
    error("❌ Test 6 failed: Response should have Action")
end

if not response.Success then
    error("❌ Test 6 failed: Response should have Success")
end

if not response.HasRewards then
    error("❌ Test 6 failed: Response should have HasRewards")
end

if not response.HasExp then
    error("❌ Test 6 failed: Response should have HasExp")
end

if not response.Data then
    error("❌ Test 6 failed: Response should have Data")
end

data = json.decode(response.Data)
if type(data) ~= "table" then
    error("❌ Test 6 failed: Data should be a table")
end

if not (data.customShopRewards ~= nil or data.eggRewards ~= nil or response.HasRewards == "false") then
    error("❌ Test 6 failed: Should have rewards or HasRewards should be false")
end

print("✅ Test 6 passed")

-- Test 7: Missing Parameters Error
print("📝 Test 7: Missing parameters error")
response = sendMessage("CalculateRewards", {
    OptionIndex = "0",
    Outcome = "success"
    -- Missing EncounterType
})

if response.Action ~= "Error" then
    error("❌ Test 7 failed: Should return Error for missing parameters")
end

if not response.Error then
    error("❌ Test 7 failed: Should have error message")
end

print("✅ Test 7 passed")

-- Test Summary
print("==================================================")
print("🎉 All Encounter Reward Calculation tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
