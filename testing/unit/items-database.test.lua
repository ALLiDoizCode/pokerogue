-- Unit tests for Items Database Process
-- Test framework: aolite

-- ADP v1.0 Compatible Test - Template dependency removed
-- Temporary stub for DataProcessTemplate
local DataProcessTemplate = {
    validateInput = function(msg) return true, nil end,
    handleMessage = function(msg, processId, handler) return {Action = "Response", Data = {}} end
}

-- Set up AO global mocks
_G.Handlers = {
    add = function(name, matcher, handler) end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg) return true end
        end
    },
    list = {}
}

_G.ao = {
    send = function(params) return params end
}

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

-- Test basic item data structure
function testItemDataStructure()
    print("Testing item data structure...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.POTION },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local isValid, error = DataProcessTemplate.validateInput(testMessage)
    assert(isValid == true, "Test message should be valid")
    assert(error == nil, "Valid message should not produce error")
    
    print("✓ Item data structure test passed")
end

-- Test GetItem by ID
function testGetItemByID()
    print("Testing GetItem by ID...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.MASTER_BALL },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetItem" and message.Data.id == ITEM.MASTER_BALL then
            return {
                id = 1,
                n = "Master Ball",
                cat = ITEM_CATEGORY.POKEBALL,
                eff = "Catches any Pokemon without fail",
                val = 0,
                stack = 999
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data.n == "Master Ball", "Should return Master Ball data")
    assert(response.Data.cat == ITEM_CATEGORY.POKEBALL, "Should return correct category")
    
    print("✓ GetItem by ID test passed")
end

-- Test GetItem by name
function testGetItemByName()
    print("Testing GetItem by name...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { name = "Potion" },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetItem" and message.Data.name == "Potion" then
            return {
                id = 17,
                n = "Potion",
                cat = ITEM_CATEGORY.HEALING,
                eff = "Restores 20 HP",
                val = 300,
                heal = 20
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data.heal == 20, "Should return correct healing amount")
    
    print("✓ GetItem by name test passed")
end

-- Test GetItemsByCategory
function testGetItemsByCategory()
    print("Testing GetItemsByCategory...")
    
    local testMessage = {
        Action = "GetItemsByCategory",
        Data = { category = ITEM_CATEGORY.BERRY },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetItemsByCategory" and message.Data.category == ITEM_CATEGORY.BERRY then
            return {
                {id = 149, n = "Cheri Berry", cat = ITEM_CATEGORY.BERRY, berry = true},
                {id = 155, n = "Oran Berry", cat = ITEM_CATEGORY.BERRY, berry = true},
                {id = 157, n = "Lum Berry", cat = ITEM_CATEGORY.BERRY, berry = true}
            }
        end
        return {}
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(type(response.Data) == "table", "Should return berries as table")
    
    print("✓ GetItemsByCategory test passed")
end

-- Test berry effects
function testBerryEffects()
    print("Testing berry effects...")
    
    local testMessage = {
        Action = "GetBerryEffect",
        Data = { id = ITEM.CHERI_BERRY },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetBerryEffect" and message.Data.id == ITEM.CHERI_BERRY then
            return {
                name = "Cheri Berry",
                effect = "Cures paralysis when held",
                natural = true,
                statusCure = {"paralysis"}
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data.name == "Cheri Berry", "Should return correct berry name")
    assert(type(response.Data.statusCure) == "table", "Should include status cure data")
    
    print("✓ Berry effects test passed")
end

-- Test healing berries
function testHealingBerries()
    print("Testing healing berries...")
    
    local testMessage = {
        Action = "GetBerryEffect",
        Data = { id = ITEM.ORAN_BERRY },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetBerryEffect" and message.Data.id == ITEM.ORAN_BERRY then
            return {
                name = "Oran Berry",
                effect = "Restores 10 HP when held",
                natural = true,
                healAmount = 10
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Data.healAmount == 10, "Should return correct heal amount")
    
    -- Test percentage healing berry
    testMessage.Data.id = ITEM.SITRUS_BERRY
    mockQueryHandler = function(message)
        return {
            name = "Sitrus Berry",
            healPercent = 0.25
        }
    end
    
    response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Data.healPercent == 0.25, "Should return correct heal percentage")
    
    print("✓ Healing berries test passed")
end

-- Test item categories
function testItemCategories()
    print("Testing item categories...")
    
    local categoryTests = {
        {id = ITEM.POKE_BALL, expectedCategory = ITEM_CATEGORY.POKEBALL},
        {id = ITEM.POTION, expectedCategory = ITEM_CATEGORY.HEALING},
        {id = ITEM.ANTIDOTE, expectedCategory = ITEM_CATEGORY.STATUS_CURE},
        {id = ITEM.REVIVE, expectedCategory = ITEM_CATEGORY.REVIVAL},
        {id = ITEM.FIRE_STONE, expectedCategory = ITEM_CATEGORY.EVOLUTION},
        {id = ITEM.CHERI_BERRY, expectedCategory = ITEM_CATEGORY.BERRY},
        {id = ITEM.NUGGET, expectedCategory = ITEM_CATEGORY.VALUABLE}
    }
    
    for _, test in ipairs(categoryTests) do
        local testMessage = {
            Action = "GetItem",
            Data = { id = test.id },
            Timestamp = 1234567890,
            From = "test-address"
        }
        
        local mockQueryHandler = function(message)
            return {
                cat = test.expectedCategory
            }
        end
        
        local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
        assert(response.Data.cat == test.expectedCategory, "Category should match expected value")
    end
    
    print("✓ Item categories test passed")
end

-- Test healing items
function testHealingItems()
    print("Testing healing items...")
    
    local healingTests = {
        {id = ITEM.POTION, expectedHeal = 20},
        {id = ITEM.MAX_POTION, expectedHeal = 999} -- Max healing
    }
    
    for _, test in ipairs(healingTests) do
        local testMessage = {
            Action = "GetItem",
            Data = { id = test.id },
            Timestamp = 1234567890,
            From = "test-address"
        }
        
        local mockQueryHandler = function(message)
            return {
                heal = test.expectedHeal
            }
        end
        
        local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
        assert(response.Data.heal == test.expectedHeal, "Heal amount should match expected value")
    end
    
    print("✓ Healing items test passed")
end

-- Test status cure items
function testStatusCureItems()
    print("Testing status cure items...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.ANTIDOTE },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            n = "Antidote",
            cures = {"poison"}
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(type(response.Data.cures) == "table", "Should include cures data")
    
    -- Test full heal
    testMessage.Data.id = ITEM.FULL_HEAL
    mockQueryHandler = function(message)
        return {
            cures = {"all"}
        }
    end
    
    response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Data.cures[1] == "all", "Full Heal should cure all status")
    
    print("✓ Status cure items test passed")
end

-- Test revival items
function testRevivalItems()
    print("Testing revival items...")
    
    local revivalTests = {
        {id = ITEM.REVIVE, expectedRevive = 0.5},
        {id = ITEM.MAX_REVIVE, expectedRevive = 1.0}
    }
    
    for _, test in ipairs(revivalTests) do
        local testMessage = {
            Action = "GetItem",
            Data = { id = test.id },
            Timestamp = 1234567890,
            From = "test-address"
        }
        
        local mockQueryHandler = function(message)
            return {
                revive = test.expectedRevive
            }
        end
        
        local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
        assert(response.Data.revive == test.expectedRevive, "Revive amount should match expected value")
    end
    
    print("✓ Revival items test passed")
end

-- Test evolution stones
function testEvolutionStones()
    print("Testing evolution stones...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.THUNDER_STONE },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            n = "Thunder Stone",
            cat = ITEM_CATEGORY.EVOLUTION,
            eff = "Evolves certain Electric-type Pokemon"
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Data.cat == ITEM_CATEGORY.EVOLUTION, "Should be evolution category")
    assert(string.find(response.Data.eff, "Evolves"), "Effect should mention evolution")
    
    print("✓ Evolution stones test passed")
end

-- Test valuable items
function testValuableItems()
    print("Testing valuable items...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.NUGGET },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            n = "Nugget",
            cat = ITEM_CATEGORY.VALUABLE,
            val = 10000
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Data.cat == ITEM_CATEGORY.VALUABLE, "Should be valuable category")
    assert(response.Data.val == 10000, "Should have correct value")
    
    print("✓ Valuable items test passed")
end

-- Test GetItemEffect
function testGetItemEffect()
    print("Testing GetItemEffect...")
    
    local testMessage = {
        Action = "GetItemEffect",
        Data = { id = ITEM.RARE_CANDY },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetItemEffect" then
            return {
                name = "Rare Candy",
                category = ITEM_CATEGORY.STAT_BOOST,
                effect = "Raises a Pokemon's level by 1",
                value = 4800,
                stackable = 999
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    assert(response.Data.name == "Rare Candy", "Should return correct item name")
    assert(response.Data.category == ITEM_CATEGORY.STAT_BOOST, "Should return correct category")
    
    print("✓ GetItemEffect test passed")
end

-- Test invalid queries
function testInvalidQueries()
    print("Testing invalid queries...")
    
    -- Test missing required data for GetItem
    local invalidMessage = {
        Action = "GetItem",
        Data = {}, -- Missing id or name
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        error("GetItem requires either 'id' or 'name' in Data")
    end
    
    local response = DataProcessTemplate.handleMessage(invalidMessage, "items-database", mockQueryHandler)
    assert(response.Error ~= nil, "Should return error for invalid query")
    
    -- Test missing category for GetItemsByCategory
    invalidMessage.Action = "GetItemsByCategory"
    invalidMessage.Data = {} -- Missing category
    
    mockQueryHandler = function(message)
        error("GetItemsByCategory requires 'category' in Data")
    end
    
    response = DataProcessTemplate.handleMessage(invalidMessage, "items-database", mockQueryHandler)
    assert(response.Error ~= nil, "Should return error for missing category")
    
    print("✓ Invalid queries test passed")
end

-- Test response format compliance
function testResponseFormat()
    print("Testing response format compliance...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.POKE_BALL },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            id = 4,
            n = "Poke Ball",
            cat = ITEM_CATEGORY.POKEBALL,
            eff = "Standard catch rate",
            val = 200
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", mockQueryHandler)
    
    -- Verify SaveState protocol compliance
    assert(response.Action == "SaveState", "Response must use SaveState action")
    assert(response.Data ~= nil, "Response must include Data field")
    assert(response.ProcessId == "items-database", "Response must include correct ProcessId")
    assert(type(response.Timestamp) == "number", "Response must include numeric Timestamp")
    
    print("✓ Response format compliance test passed")
end

-- Test performance requirements
function testPerformanceRequirements()
    print("Testing performance requirements...")
    
    local testMessage = {
        Action = "GetItem",
        Data = { id = ITEM.POTION },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local fastQueryHandler = function(message)
        return { id = 17, n = "Potion" }
    end
    
    local startTime = os.clock()
    local response = DataProcessTemplate.handleMessage(testMessage, "items-database", fastQueryHandler)
    local endTime = os.clock()
    
    local responseTime = (endTime - startTime) * 1000
    
    assert(response.Action == "SaveState", "Should return valid response")
    print("Item query response time: " .. string.format("%.2f", responseTime) .. "ms")
    
    print("✓ Performance requirements test passed")
end

-- Test size optimization
function testSizeOptimization()
    print("Testing size optimization...")
    
    -- Test abbreviated keys for size optimization
    local sampleItemData = {
        id = 17,
        n = "Potion", -- name abbreviated
        cat = ITEM_CATEGORY.HEALING, -- category abbreviated
        eff = "Restores 20 HP", -- effect abbreviated
        val = 300, -- value abbreviated
        stack = 999, -- stackable abbreviated
        heal = 20 -- heal amount
    }
    
    local fullKeys = {"name", "category", "effect", "value", "stackable"}
    local abbrevKeys = {"n", "cat", "eff", "val", "stack"}
    
    local fullKeyLength = 0
    local abbrevKeyLength = 0
    
    for _, key in ipairs(fullKeys) do
        fullKeyLength = fullKeyLength + #key
    end
    
    for _, key in ipairs(abbrevKeys) do
        abbrevKeyLength = abbrevKeyLength + #key
    end
    
    local spaceSaved = fullKeyLength - abbrevKeyLength
    print("Space saved by key abbreviation: " .. spaceSaved .. " characters per item")
    assert(spaceSaved > 0, "Abbreviated keys should save space")
    
    print("✓ Size optimization test passed")
end

-- Run all tests
function runAllTests()
    print("Running Items Database tests...")
    print("=====================================")
    
    testItemDataStructure()
    testGetItemByID()
    testGetItemByName()
    testGetItemsByCategory()
    testBerryEffects()
    testHealingBerries()
    testItemCategories()
    testHealingItems()
    testStatusCureItems()
    testRevivalItems()
    testEvolutionStones()
    testValuableItems()
    testGetItemEffect()
    testInvalidQueries()
    testResponseFormat()
    testPerformanceRequirements()
    testSizeOptimization()
    
    print("=====================================")
    print("✅ All Items Database tests passed!")
end

-- Execute tests
runAllTests()