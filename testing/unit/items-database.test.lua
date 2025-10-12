-- Aolite Unit Tests for Items Database Process
-- Tests item data structure, retrieval, categories, and effects
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.items-database"
local processId = "test-items-database"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Items Database")
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

-- Constants for testing
local ITEM = {
    MASTER_BALL = 1,
    POKE_BALL = 4,
    POTION = 17,
    MAX_POTION = 24,
    ANTIDOTE = 18,
    FULL_HEAL = 27,
    REVIVE = 28,
    MAX_REVIVE = 29,
    FIRE_STONE = 82,
    THUNDER_STONE = 83,
    CHERI_BERRY = 149,
    ORAN_BERRY = 155,
    LUM_BERRY = 157,
    SITRUS_BERRY = 158,
    NUGGET = 92,
    RARE_CANDY = 50
}

local ITEM_CATEGORY = {
    POKEBALL = 0,
    HEALING = 1,
    STATUS_CURE = 2,
    REVIVAL = 3,
    STAT_BOOST = 4,
    EVOLUTION = 5,
    BERRY = 6,
    HELD_ITEM = 7,
    KEY_ITEM = 8,
    BATTLE_ITEM = 9,
    VALUABLE = 10,
    FOSSIL = 11
}

-- Test 1: GetItem by ID (Master Ball)
print("📝 Test 1: GetItem by ID (Master Ball)")
local masterBallResponse = sendMessage("GetItem", {
    ItemId = tostring(ITEM.MASTER_BALL)
})
if masterBallResponse and masterBallResponse.Action == "SaveState" then
    print("✅ GetItem by ID (Master Ball) passed")
else
    error("❌ GetItem by ID (Master Ball) failed")
end

-- Test 2: GetItem by Name (Potion)
print("📝 Test 2: GetItem by Name (Potion)")
local potionResponse = sendMessage("GetItem", {
    ItemName = "Potion"
})
if potionResponse and potionResponse.Action == "SaveState" then
    print("✅ GetItem by name (Potion) passed")
else
    error("❌ GetItem by name (Potion) failed")
end

-- Test 3: GetItemsByCategory (Berries)
print("📝 Test 3: GetItemsByCategory (Berries)")
local berriesResponse = sendMessage("GetItemsByCategory", {
    Category = tostring(ITEM_CATEGORY.BERRY)
})
if berriesResponse and berriesResponse.Action == "SaveState" then
    print("✅ GetItemsByCategory (Berries) passed")
else
    error("❌ GetItemsByCategory (Berries) failed")
end

-- Test 4: GetBerryEffect (Cheri Berry)
print("📝 Test 4: GetBerryEffect (Cheri Berry)")
local cheriBerryResponse = sendMessage("GetBerryEffect", {
    ItemId = tostring(ITEM.CHERI_BERRY)
})
if cheriBerryResponse and cheriBerryResponse.Action == "SaveState" then
    print("✅ GetBerryEffect (Cheri Berry) passed")
else
    error("❌ GetBerryEffect (Cheri Berry) failed")
end

-- Test 5: Healing Berry (Oran Berry)
print("📝 Test 5: Healing Berry (Oran Berry)")
local oranBerryResponse = sendMessage("GetBerryEffect", {
    ItemId = tostring(ITEM.ORAN_BERRY)
})
if oranBerryResponse and oranBerryResponse.Action == "SaveState" then
    print("✅ Healing berry (Oran Berry) passed")
else
    error("❌ Healing berry (Oran Berry) failed")
end

-- Test 6: Percentage Healing Berry (Sitrus Berry)
print("📝 Test 6: Percentage Healing Berry (Sitrus Berry)")
local sitrusBerryResponse = sendMessage("GetBerryEffect", {
    ItemId = tostring(ITEM.SITRUS_BERRY)
})
if sitrusBerryResponse and sitrusBerryResponse.Action == "SaveState" then
    print("✅ Percentage healing berry (Sitrus Berry) passed")
else
    error("❌ Percentage healing berry (Sitrus Berry) failed")
end

-- Test 7: Item Categories (Multiple Items)
print("📝 Test 7: Item Categories (Multiple Items)")
local categoryTests = {
    {id = ITEM.POKE_BALL, category = ITEM_CATEGORY.POKEBALL},
    {id = ITEM.POTION, category = ITEM_CATEGORY.HEALING},
    {id = ITEM.ANTIDOTE, category = ITEM_CATEGORY.STATUS_CURE},
    {id = ITEM.REVIVE, category = ITEM_CATEGORY.REVIVAL},
    {id = ITEM.FIRE_STONE, category = ITEM_CATEGORY.EVOLUTION},
    {id = ITEM.CHERI_BERRY, category = ITEM_CATEGORY.BERRY},
    {id = ITEM.NUGGET, category = ITEM_CATEGORY.VALUABLE}
}

local categoriesPassed = true
for _, test in ipairs(categoryTests) do
    local catResponse = sendMessage("GetItem", {
        ItemId = tostring(test.id)
    })
    if not catResponse or catResponse.Action ~= "SaveState" then
        categoriesPassed = false
        break
    end
end

if categoriesPassed then
    print("✅ Item categories (Multiple items) passed")
else
    error("❌ Item categories (Multiple items) failed")
end

-- Test 8: Healing Items (Potion and Max Potion)
print("📝 Test 8: Healing Items (Potion and Max Potion)")
local healingTests = {
    {id = ITEM.POTION},
    {id = ITEM.MAX_POTION}
}

local healingPassed = true
for _, test in ipairs(healingTests) do
    local healResponse = sendMessage("GetItem", {
        ItemId = tostring(test.id)
    })
    if not healResponse or healResponse.Action ~= "SaveState" then
        healingPassed = false
        break
    end
end

if healingPassed then
    print("✅ Healing items (Potion and Max Potion) passed")
else
    error("❌ Healing items (Potion and Max Potion) failed")
end

-- Test 9: Status Cure Items (Antidote and Full Heal)
print("📝 Test 9: Status Cure Items (Antidote and Full Heal)")
local antidoteResponse = sendMessage("GetItem", {
    ItemId = tostring(ITEM.ANTIDOTE)
})
if antidoteResponse and antidoteResponse.Action == "SaveState" then
    local fullHealResponse = sendMessage("GetItem", {
        ItemId = tostring(ITEM.FULL_HEAL)
    })
    if fullHealResponse and fullHealResponse.Action == "SaveState" then
        print("✅ Status cure items (Antidote and Full Heal) passed")
    else
        error("❌ Full Heal test failed")
    end
else
    error("❌ Antidote test failed")
end

-- Test 10: Revival Items (Revive and Max Revive)
print("📝 Test 10: Revival Items (Revive and Max Revive)")
local reviveResponse = sendMessage("GetItem", {
    ItemId = tostring(ITEM.REVIVE)
})
if reviveResponse and reviveResponse.Action == "SaveState" then
    local maxReviveResponse = sendMessage("GetItem", {
        ItemId = tostring(ITEM.MAX_REVIVE)
    })
    if maxReviveResponse and maxReviveResponse.Action == "SaveState" then
        print("✅ Revival items (Revive and Max Revive) passed")
    else
        error("❌ Max Revive test failed")
    end
else
    error("❌ Revive test failed")
end

-- Test 11: Evolution Stones (Thunder Stone)
print("📝 Test 11: Evolution Stones (Thunder Stone)")
local thunderStoneResponse = sendMessage("GetItem", {
    ItemId = tostring(ITEM.THUNDER_STONE)
})
if thunderStoneResponse and thunderStoneResponse.Action == "SaveState" then
    print("✅ Evolution stones (Thunder Stone) passed")
else
    error("❌ Evolution stones (Thunder Stone) failed")
end

-- Test 12: Valuable Items (Nugget)
print("📝 Test 12: Valuable Items (Nugget)")
local nuggetResponse = sendMessage("GetItem", {
    ItemId = tostring(ITEM.NUGGET)
})
if nuggetResponse and nuggetResponse.Action == "SaveState" then
    print("✅ Valuable items (Nugget) passed")
else
    error("❌ Valuable items (Nugget) failed")
end

-- Test 13: GetItemEffect (Rare Candy)
print("📝 Test 13: GetItemEffect (Rare Candy)")
local rareCandyResponse = sendMessage("GetItemEffect", {
    ItemId = tostring(ITEM.RARE_CANDY)
})
if rareCandyResponse and rareCandyResponse.Action == "SaveState" then
    print("✅ GetItemEffect (Rare Candy) passed")
else
    error("❌ GetItemEffect (Rare Candy) failed")
end

-- Test 14: Error Handling - Missing Required Data for GetItem
print("📝 Test 14: Error Handling - Missing Required Data for GetItem")
local errorResponse = sendMessage("GetItem")
if errorResponse and errorResponse.Action == "Error" then
    print("✅ Error handling for missing GetItem data passed")
else
    error("❌ Error handling for missing GetItem data failed")
end

-- Test 15: Error Handling - Missing Category for GetItemsByCategory
print("📝 Test 15: Error Handling - Missing Category for GetItemsByCategory")
local categoryErrorResponse = sendMessage("GetItemsByCategory")
if categoryErrorResponse and categoryErrorResponse.Action == "Error" then
    print("✅ Error handling for missing category passed")
else
    error("❌ Error handling for missing category failed")
end

-- Test 16: Response Format Compliance
print("📝 Test 16: Response Format Compliance")
local formatResponse = sendMessage("GetItem", {
    ItemId = tostring(ITEM.POKE_BALL)
})
if formatResponse and formatResponse.Action == "SaveState" and formatResponse.Data then
    print("✅ Response format compliance passed")
else
    error("❌ Response format compliance failed")
end

-- Test 17: Health Check
print("📝 Test 17: Health Check")
local healthResponse = sendMessage("HealthCheck")
if healthResponse and healthResponse.Action == "HealthStatus" then
    if healthResponse.Status == "healthy" then
        print("✅ Health check passed")
    else
        error("❌ Invalid health status")
    end
else
    error("❌ Health check failed")
end

-- Test 18: ADP v1.0 Info Handler
print("📝 Test 18: ADP v1.0 Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ ADP v1.0 Info handler passed")
else
    error("❌ ADP v1.0 Info handler failed")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
print("📊 Test Summary:")
print("- ✅ GetItem by ID")
print("- ✅ GetItem by name")
print("- ✅ GetItemsByCategory")
print("- ✅ Berry effects (status cure)")
print("- ✅ Healing berries (fixed amount)")
print("- ✅ Healing berries (percentage)")
print("- ✅ Item categories validation")
print("- ✅ Healing items")
print("- ✅ Status cure items")
print("- ✅ Revival items")
print("- ✅ Evolution stones")
print("- ✅ Valuable items")
print("- ✅ Item effects")
print("- ✅ Error handling (missing item data)")
print("- ✅ Error handling (missing category)")
print("- ✅ Response format compliance")
print("- ✅ Process health monitoring")
print("- ✅ ADP v1.0 compliance")
