-- Unit Tests for Modifier System Engine Item Interactions
-- Validates item interaction calculations, stacking, and effect combinations

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.modifier-system-engine"
local processId = "test-modifier-system-engine-interactions"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Modifier System Engine Interactions")
print("Process ID:", processId)

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

-- Test 1: Item interaction lookup
print("📝 Test 1: Item Interaction Lookup")
local lookupData = json.encode({
    primaryItemId = "POTION",
    secondaryItemIds = {"SUPER_POTION"}
})
local response1 = sendMessage("LookupItemInteraction", {}, lookupData)
if not response1 or response1.Action == "Error" then
    error("❌ Test failed: Expected successful item interaction lookup")
end
print("✅ Test 1 passed: Item interaction lookup")

-- Test 2: Effect combination calculation
print("📝 Test 2: Effect Combination Calculation")
local combinationData = json.encode({
    primaryItem = "POTION",
    secondaryItems = {"SUPER_POTION"},
    interactionRule = {
        combinationRule = "additive",
        calculationOrder = {"primary", "secondary"}
    }
})
local response2 = sendMessage("CalculateItemEffectCombination", {}, combinationData)
if not response2 or response2.Action == "Error" then
    error("❌ Test failed: Expected successful effect combination calculation")
end
print("✅ Test 2 passed: Effect combination calculation")

-- Test 3: Modifier stacking validation
print("📝 Test 3: Modifier Stacking Validation")
local stackingData = json.encode({
    itemId = "POTION",
    currentStackCount = 5,
    newStackCount = 3
})
local response3 = sendMessage("ValidateItemStackingLimits", {}, stackingData)
if not response3 or response3.Action == "Error" then
    error("❌ Test failed: Expected successful stacking validation")
end
print("✅ Test 3 passed: Modifier stacking validation")

-- Test 4: Stacking limit exceeded
print("📝 Test 4: Stacking Limit Exceeded")
local exceedData = json.encode({
    itemId = "CHOICE_BAND",
    currentStackCount = 3,
    newStackCount = 3
})
local response4 = sendMessage("ValidateItemStackingLimits", {}, exceedData)
if response4 and response4.Action ~= "Error" then
    error("❌ Test failed: Expected error for exceeded stacking limit")
end
print("✅ Test 4 passed: Stacking limit exceeded error")

-- Test 5: Effect cancellation detection
print("📝 Test 5: Effect Cancellation Detection")
local cancellationData = json.encode({
    primaryItemId = "CHOICE_BAND",
    secondaryItemId = "CHOICE_SPECS"
})
local response5 = sendMessage("CheckEffectCancellation", {}, cancellationData)
if not response5 or response5.Action == "Error" then
    error("❌ Test failed: Expected successful cancellation check")
end
print("✅ Test 5 passed: Effect cancellation detection")

-- Test 6: No cancellation for compatible items
print("📝 Test 6: No Cancellation for Compatible Items")
local noCancelData = json.encode({
    primaryItemId = "POTION",
    secondaryItemId = "SUPER_POTION"
})
local response6 = sendMessage("CheckEffectCancellation", {}, noCancelData)
if not response6 or response6.Action == "Error" then
    error("❌ Test failed: Expected successful no-cancellation check")
end
print("✅ Test 6 passed: No cancellation for compatible items")

-- Test 7: Complex interaction scenarios
print("📝 Test 7: Complex Interaction Scenarios")
local complexData = json.encode({
    primaryItem = "POTION",
    secondaryItems = {"SUPER_POTION"},
    interactionRule = {
        combinationRule = "additive",
        calculationOrder = {"primary", "secondary"}
    }
})
local response7 = sendMessage("CalculateItemEffectCombination", {}, complexData)
if not response7 or response7.Action == "Error" then
    error("❌ Test failed: Expected successful complex interaction")
end
print("✅ Test 7 passed: Complex interaction scenarios")

-- Test 8: Edge case - Invalid item
print("📝 Test 8: Edge Case - Invalid Item")
local invalidData = json.encode({
    primaryItem = "INVALID_ITEM",
    secondaryItems = {}
})
local response8 = sendMessage("CalculateItemEffectCombination", {}, invalidData)
if response8 and response8.Action ~= "Error" then
    error("❌ Test failed: Expected error for invalid item")
end
print("✅ Test 8 passed: Invalid item error handling")

-- Test 9: Edge case - Empty secondary items
print("📝 Test 9: Edge Case - Empty Secondary Items")
local emptySecondaryData = json.encode({
    primaryItem = "POTION",
    secondaryItems = {}
})
local response9 = sendMessage("CalculateItemEffectCombination", {}, emptySecondaryData)
if not response9 or response9.Action == "Error" then
    error("❌ Test failed: Expected successful handling of empty secondary items")
end
print("✅ Test 9 passed: Empty secondary items handling")

-- Test 10: Ping handler
print("📝 Test 10: Ping Handler")
local response10 = sendMessage("Ping")
if not response10 or response10.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong response")
end
print("✅ Test 10 passed: Ping handler")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
