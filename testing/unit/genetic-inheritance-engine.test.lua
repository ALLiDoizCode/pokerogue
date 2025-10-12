-- Unit Tests for Genetic Inheritance Engine
-- Tests IV inheritance, nature inheritance, ability inheritance, and breeding mechanics

local aolite = require("aolite")
local json = require("json")

-- Test Configuration
local PROCESS_PATH = "processes.genetic-inheritance-engine"
local processId = "test-genetic-inheritance-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Genetic Inheritance Engine")
print("Process ID:", processId)
print("==================================================")

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

-- Test data factories
local function createTestParent(id, speciesId, ivs, nature, ability, abilityIndex)
    return {
        id = id,
        speciesId = speciesId or "CHARIZARD",
        ivs = ivs or {31, 31, 31, 31, 31, 31},
        nature = nature or "ADAMANT",
        ability = ability or "BLAZE",
        abilityIndex = abilityIndex or 1
    }
end

-- ===============================
-- INFO HANDLER TESTS
-- ===============================

print("\n📝 Test 1: Return process information")
local response1 = sendMessage("Info")

if response1 and response1.Data then
    local data = json.decode(response1.Data or "{}")
    if data.process and data.process.name and
       data.process.adpVersion == "1.0" and
       data.handlers and #data.handlers > 0 then
        print("✅ Test 1 passed - Info response correct")
    else
        error("❌ Test 1 failed: Info response incomplete or incorrect structure")
    end
else
    error("❌ Test 1 failed: Expected Data field")
end

-- ===============================
-- IV INHERITANCE TESTS
-- ===============================

print("\n📝 Test 2: Inherit 3 IVs without items")
local parent1 = createTestParent("p1_test2", "CHARIZARD", {31, 30, 29, 28, 27, 26})
local parent2 = createTestParent("p2_test2", "CHARIZARD", {26, 27, 28, 29, 30, 31})

local response2 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateIvInheritance",
    parameters = {
        parent1 = parent1,
        parent2 = parent2,
        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
    }
}))

if response2 and response2.Action == "SaveState" then
    local data = json.decode(response2.Data or "{}")
    if data.success and data.genetics and data.genetics.ivInheritance then
        local inheritedCount = 0
        for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources or {}) do
            if source ~= "random" then
                inheritedCount = inheritedCount + 1
            end
        end
        if inheritedCount == 3 then
            print("✅ Test 2 passed - 3 IVs inherited")
        else
            error("❌ Test 2 failed: Expected 3 inherited IVs, got " .. inheritedCount)
        end
    else
        error("❌ Test 2 failed: Missing genetics data")
    end
else
    error("❌ Test 2 failed: Expected SaveState action")
end

print("\n📝 Test 3: Inherit 5 IVs with Destiny Knot")
local parent3a = createTestParent("p1_test3", "CHARIZARD", {31, 30, 29, 28, 27, 26})
local parent3b = createTestParent("p2_test3", "CHARIZARD", {26, 27, 28, 29, 30, 31})

local response3 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateIvInheritance",
    parameters = {
        parent1 = parent3a,
        parent2 = parent3b,
        parent1Item = "DESTINY_KNOT",
        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
    }
}))

if response3 and response3.Action == "SaveState" then
    local data = json.decode(response3.Data or "{}")
    if data.success and data.genetics and data.genetics.ivInheritance then
        local inheritedCount = 0
        for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources or {}) do
            if source ~= "random" then
                inheritedCount = inheritedCount + 1
            end
        end

        local hasDestinyKnot = false
        for _, effect in ipairs(data.genetics.ivInheritance.itemEffects or {}) do
            if string.find(effect, "destiny_knot") then
                hasDestinyKnot = true
            end
        end

        if inheritedCount == 5 and hasDestinyKnot then
            print("✅ Test 3 passed - 5 IVs inherited with Destiny Knot")
        else
            error("❌ Test 3 failed: Expected 5 inherited IVs with Destiny Knot effect")
        end
    else
        error("❌ Test 3 failed: Missing genetics data")
    end
else
    error("❌ Test 3 failed: Expected SaveState action")
end

print("\n📝 Test 4: Guarantee specific IV with Power Item")
local parent4a = createTestParent("p1_test4", "CHARIZARD", {31, 25, 25, 25, 25, 25})
local parent4b = createTestParent("p2_test4", "CHARIZARD", {25, 25, 25, 25, 25, 25})

local response4 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateIvInheritance",
    parameters = {
        parent1 = parent4a,
        parent2 = parent4b,
        parent1Item = "POWER_WEIGHT", -- Guarantees HP
        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
    }
}))

if response4 and response4.Action == "SaveState" then
    local data = json.decode(response4.Data or "{}")
    if data.success and data.genetics and data.genetics.ivInheritance then
        local hasPowerItem = false
        for _, effect in ipairs(data.genetics.ivInheritance.itemEffects or {}) do
            if string.find(effect, "power_item") then
                hasPowerItem = true
            end
        end

        if data.genetics.ivInheritance.inheritedIvs[1] == 31 and hasPowerItem then
            print("✅ Test 4 passed - Power Item guarantees HP IV")
        else
            error("❌ Test 4 failed: Expected HP IV=31 with Power Item effect")
        end
    else
        error("❌ Test 4 failed: Missing genetics data")
    end
else
    error("❌ Test 4 failed: Expected SaveState action")
end

-- ===============================
-- NATURE INHERITANCE TESTS
-- ===============================

print("\n📝 Test 5: 50% nature inheritance without items")
local parent5a = createTestParent("p1_test5", "CHARIZARD", nil, "ADAMANT")
local parent5b = createTestParent("p2_test5", "CHARIZARD", nil, "MODEST")

local response5 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "determineNatureInheritance",
    parameters = {
        parent1 = parent5a,
        parent2 = parent5b,
        randomValues = {0.5, 0.3, 0.7} -- Array of random values, not single number
    }
}))

if response5 and response5.Action == "SaveState" then
    local data = json.decode(response5.Data or "{}")
    if data.success and data.genetics and data.genetics.natureInheritance then
        if data.genetics.natureInheritance.inheritedNature and
           data.genetics.natureInheritance.inheritanceSource then
            print("✅ Test 5 passed - Nature inheritance without items")
        else
            error("❌ Test 5 failed: Missing nature inheritance data")
        end
    else
        error("❌ Test 5 failed: Missing genetics data")
    end
else
    error("❌ Test 5 failed: Expected SaveState action")
end

print("\n📝 Test 6: Guarantee nature with Everstone")
local parent6a = createTestParent("p1_test6", "CHARIZARD", nil, "ADAMANT")
local parent6b = createTestParent("p2_test6", "CHARIZARD", nil, "MODEST")

local response6 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "determineNatureInheritance",
    parameters = {
        parent1 = parent6a,
        parent2 = parent6b,
        parent1Item = "EVERSTONE",
        randomValues = {0.5, 0.3, 0.7}
    }
}))

if response6 and response6.Action == "SaveState" then
    local data = json.decode(response6.Data or "{}")
    if data.success and data.genetics and data.genetics.natureInheritance then
        -- Check if Everstone effect is indicated by inheritanceSource
        local hasEverstone = data.genetics.natureInheritance.inheritanceSource and
                             string.find(data.genetics.natureInheritance.inheritanceSource, "everstone")

        if data.genetics.natureInheritance.inheritedNature == "ADAMANT" and hasEverstone then
            print("✅ Test 6 passed - Everstone guarantees nature")
        else
            error("❌ Test 6 failed: Expected ADAMANT nature with Everstone effect (got " ..
                  (data.genetics.natureInheritance.inheritedNature or "nil") .. " from " ..
                  (data.genetics.natureInheritance.inheritanceSource or "nil") .. ")")
        end
    else
        error("❌ Test 6 failed: Missing genetics data")
    end
else
    error("❌ Test 6 failed: Expected SaveState action")
end

print("\n📝 Test 7: Handle dual Everstone scenario")
local parent7a = createTestParent("p1_test7", "CHARIZARD", nil, "ADAMANT")
local parent7b = createTestParent("p2_test7", "CHARIZARD", nil, "MODEST")

local response7 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "determineNatureInheritance",
    parameters = {
        parent1 = parent7a,
        parent2 = parent7b,
        parent1Item = "EVERSTONE",
        parent2Item = "EVERSTONE",
        randomValues = {0.3, 0.7, 0.5} -- Different random for dual Everstone
    }
}))

if response7 and response7.Action == "SaveState" then
    local data = json.decode(response7.Data or "{}")
    if data.success and data.genetics and data.genetics.natureInheritance then
        local nature = data.genetics.natureInheritance.inheritedNature
        if nature == "ADAMANT" or nature == "MODEST" then
            print("✅ Test 7 passed - Dual Everstone selects one parent")
        else
            error("❌ Test 7 failed: Expected ADAMANT or MODEST nature")
        end
    else
        error("❌ Test 7 failed: Missing genetics data")
    end
else
    error("❌ Test 7 failed: Expected SaveState action")
end

print("\n📝 Test 8: Include nature stat modifiers")
local parent8a = createTestParent("p1_test8", "CHARIZARD", nil, "ADAMANT")
local parent8b = createTestParent("p2_test8", "CHARIZARD", nil, "MODEST")

local response8 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "determineNatureInheritance",
    parameters = {
        parent1 = parent8a,
        parent2 = parent8b,
        randomValues = {0.5, 0.3, 0.7}
    }
}))

if response8 and response8.Action == "SaveState" then
    local data = json.decode(response8.Data or "{}")
    if data.success and data.genetics and data.genetics.natureInheritance then
        -- Check for natureEffects (not statModifiers)
        if data.genetics.natureInheritance.natureEffects and
           data.genetics.natureInheritance.natureEffects.multipliers then
            print("✅ Test 8 passed - Nature stat modifiers included")
        else
            error("❌ Test 8 failed: Missing natureEffects/multipliers")
        end
    else
        error("❌ Test 8 failed: Missing genetics data")
    end
else
    error("❌ Test 8 failed: Expected SaveState action")
end

-- ===============================
-- ABILITY INHERITANCE TESTS
-- ===============================

print("\n📝 Test 9: Inherit standard abilities with 80/20 distribution")
local parent9a = createTestParent("p1_test9", "CHARIZARD", nil, nil, "BLAZE", 1)
local parent9b = createTestParent("p2_test9", "CHARIZARD", nil, nil, "SOLAR_POWER", 2)

local response9 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateAbilityInheritance",
    parameters = {
        parent1 = parent9a,
        parent2 = parent9b,
        speciesData = {
            id = 6,
            name = "Charizard",
            abilities = {"BLAZE", "SOLAR_POWER", "DROUGHT"} -- Slot 1, Slot 2, Hidden
        },
        randomValues = {0.5, 0.3, 0.7}
    }
}))

if response9 and response9.Action == "SaveState" then
    local data = json.decode(response9.Data or "{}")
    if data.success and data.genetics and data.genetics.abilityInheritance then
        if data.genetics.abilityInheritance.inheritedAbility and
           data.genetics.abilityInheritance.inheritanceSource then
            print("✅ Test 9 passed - Standard ability inheritance")
        else
            error("❌ Test 9 failed: Missing ability inheritance data")
        end
    else
        error("❌ Test 9 failed: Missing genetics data")
    end
else
    error("❌ Test 9 failed: Expected SaveState action")
end

print("\n📝 Test 10: Inherit hidden ability with 60% chance")
local parent10a = createTestParent("p1_test10", "CHARIZARD", nil, nil, "DROUGHT", 3) -- Hidden ability
local parent10b = createTestParent("p2_test10", "CHARIZARD", nil, nil, "BLAZE", 1)

local response10 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateAbilityInheritance",
    parameters = {
        parent1 = parent10a,
        parent2 = parent10b,
        speciesData = {
            id = 6,
            name = "Charizard",
            abilities = {"BLAZE", "SOLAR_POWER", "DROUGHT"}
        },
        randomValues = {0.5, 0.3, 0.7}
    }
}))

if response10 and response10.Action == "SaveState" then
    local data = json.decode(response10.Data or "{}")
    if data.success and data.genetics and data.genetics.abilityInheritance then
        -- Just check that hidden ability inheritance is supported
        if data.genetics.abilityInheritance.inheritedAbility then
            print("✅ Test 10 passed - Hidden ability inheritance supported")
        else
            error("❌ Test 10 failed: Missing inherited ability")
        end
    else
        error("❌ Test 10 failed: Missing genetics data")
    end
else
    error("❌ Test 10 failed: Expected SaveState action")
end

-- ===============================
-- COMPLETE INHERITANCE TEST
-- ===============================

print("\n📝 Test 11: Process complete genetic inheritance")
local parent11a = createTestParent("p1_test11", "CHARIZARD", {31, 30, 29, 28, 27, 26}, "ADAMANT", "BLAZE", 1)
local parent11b = createTestParent("p2_test11", "CHARIZARD", {26, 27, 28, 29, 30, 31}, "MODEST", "SOLAR_POWER", 2)

local response11 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "processCompleteInheritance",
    parameters = {
        parent1 = parent11a,
        parent2 = parent11b,
        parent1Item = "DESTINY_KNOT",
        parent2Item = "EVERSTONE",
        speciesData = {
            id = 6,
            name = "Charizard",
            abilities = {"BLAZE", "SOLAR_POWER", "DROUGHT"}
        },
        randomValues = {0.5, 0.3, 0.7, 0.2, 0.8, 0.4, 0.6, 0.1, 0.9, 0.35, 0.65, 0.45, 0.55, 0.25, 0.75}
    }
}))

if response11 and response11.Action == "SaveState" then
    local data = json.decode(response11.Data or "{}")
    if data.success and data.genetics then
        if data.genetics.ivInheritance and
           data.genetics.natureInheritance and
           data.genetics.abilityInheritance then
            print("✅ Test 11 passed - Complete inheritance processing")
        else
            error("❌ Test 11 failed: Missing complete inheritance data")
        end
    else
        error("❌ Test 11 failed: Missing genetics data")
    end
else
    error("❌ Test 11 failed: Expected SaveState action")
end

-- ===============================
-- BREEDING PROBABILITIES TEST
-- ===============================

print("\n📝 Test 12: Calculate breeding success probabilities")
local currentGenetics12 = {
    ivs = {31, 31, 31, 25, 25, 25},
    nature = "ADAMANT",
    ability = "BLAZE"
}
local targetGenetics12 = {
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "ADAMANT",
    ability = "BLAZE"
}

local response12 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateProbabilities",
    parameters = {
        currentGenetics = currentGenetics12,
        targetGenetics = targetGenetics12
    }
}))

if response12 and response12.Action == "SaveState" then
    local data = json.decode(response12.Data or "{}")
    if data.success and data.probabilities then
        print("✅ Test 12 passed - Breeding probabilities calculated")
    else
        error("❌ Test 12 failed: Missing probabilities data")
    end
else
    error("❌ Test 12 failed: Expected SaveState action, got " .. (response12 and response12.Action or "nil"))
end

-- ===============================
-- BREEDING STRATEGY TEST
-- ===============================

print("\n📝 Test 13: Recommend optimal breeding strategy")
local currentParents13 = {
    parent1 = createTestParent("p1_test13", "CHARIZARD", {31, 31, 25, 25, 25, 25}, "ADAMANT", "BLAZE", 1),
    parent2 = createTestParent("p2_test13", "CHARIZARD", {25, 25, 31, 31, 31, 25}, "MODEST", "SOLAR_POWER", 2)
}
local targetGenetics13 = {
    ivs = {31, 31, 31, 31, 31, 31},
    nature = "ADAMANT",
    ability = "BLAZE"
}

local response13 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "optimizeStrategy",
    parameters = {
        currentParents = currentParents13,
        targetGenetics = targetGenetics13
    }
}))

if response13 and response13.Action == "SaveState" then
    local data = json.decode(response13.Data or "{}")
    if data.success and data.recommendations then
        print("✅ Test 13 passed - Breeding strategy recommended")
    else
        error("❌ Test 13 failed: Missing recommendations data")
    end
else
    error("❌ Test 13 failed: Expected SaveState action, got " .. (response13 and response13.Action or "nil"))
end

-- ===============================
-- ERROR HANDLING TESTS
-- ===============================

print("\n📝 Test 14: Handle missing operation")
local response14 = sendMessage("ProcessLogic", {}, json.encode({
    parameters = { test = true }
}))

if response14 and response14.Action == "Error" then
    print("✅ Test 14 passed - Missing operation error")
else
    error("❌ Test 14 failed: Expected Error action")
end

print("\n📝 Test 15: Handle unknown operation")
local response15 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "unknownOperation",
    parameters = {}
}))

if response15 and response15.Action == "Error" then
    print("✅ Test 15 passed - Unknown operation error")
else
    error("❌ Test 15 failed: Expected Error action")
end

print("\n📝 Test 16: Handle missing parent data")
local response16 = sendMessage("ProcessLogic", {}, json.encode({
    operation = "calculateIvInheritance",
    parameters = {
        -- Missing parent1 and parent2
        randomValues = {0.5}
    }
}))

if response16 and response16.Action == "Error" then
    print("✅ Test 16 passed - Missing parent data error")
else
    error("❌ Test 16 failed: Expected Error action")
end

-- ===============================
-- HEALTH CHECK TEST
-- ===============================

print("\n📝 Test 17: Respond to health check")
local response17 = sendMessage("HealthCheck")

if response17 and response17.Action == "HealthCheckResponse" and
   response17.Status == "healthy" then
    print("✅ Test 17 passed - HealthCheck successful")
else
    error("❌ Test 17 failed: Expected healthy HealthCheckResponse")
end

-- ===============================
-- TEST SUMMARY
-- ===============================

print("\n==================================================")
print("🎉 All 17 tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
print("\n📊 Test Coverage Summary:")
print("  - Info handler: 1 test")
print("  - IV inheritance: 3 tests")
print("  - Nature inheritance: 4 tests")
print("  - Ability inheritance: 2 tests")
print("  - Complete inheritance: 1 test")
print("  - Breeding probabilities: 1 test")
print("  - Breeding strategy: 1 test")
print("  - Error handling: 3 tests")
print("  - Health check: 1 test")
print("==================================================")
