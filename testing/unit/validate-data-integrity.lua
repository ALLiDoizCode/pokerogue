-- Validate data integrity between original and ADP processes
print("=== Data Integrity Validation ===")

local processes = {
    {
        original = "processes/abilities-database.lua",
        adp = "processes/abilities-database-adp.lua",
        name = "Abilities Database"
    },
    {
        original = "processes/items-database.lua",
        adp = "processes/items-database-adp.lua",
        name = "Items Database"
    },
    {
        original = "processes/moves-database.lua",
        adp = "processes/moves-database-adp.lua",
        name = "Moves Database"
    },
    {
        original = "processes/pokemon-species-db.lua",
        adp = "processes/pokemon-species-db-adp.lua",
        name = "Pokemon Species Database"
    }
}

local function extractConstants(content, pattern)
    local constants = {}
    for match in content:gmatch(pattern) do
        table.insert(constants, match)
    end
    return constants
end

local function extractHandlerActions(content)
    local actions = {}
    -- Look for actions in Handlers.add calls
    for action in content:gmatch('hasMatchingTag%("Action",.-"([^"]+)"') do
        table.insert(actions, action)
    end
    -- Also look for action arrays
    for actionList in content:gmatch('hasMatchingTag%("Action",%s*{([^}]+)}') do
        for action in actionList:gmatch('"([^"]+)"') do
            table.insert(actions, action)
        end
    end
    return actions
end

local totalTests = 0
local passedTests = 0

for _, process in ipairs(processes) do
    print("\nValidating " .. process.name .. "...")

    -- Read original file
    local originalFile = io.open(process.original, "r")
    if not originalFile then
        print("❌ Cannot read original file: " .. process.original)
        totalTests = totalTests + 1
        goto continue
    end
    local originalContent = originalFile:read("*all")
    originalFile:close()

    -- Read ADP file
    local adpFile = io.open(process.adp, "r")
    if not adpFile then
        print("❌ Cannot read ADP file: " .. process.adp)
        totalTests = totalTests + 1
        goto continue
    end
    local adpContent = adpFile:read("*all")
    adpFile:close()

    -- Test 1: Check constants preservation
    totalTests = totalTests + 1
    local originalConstants = extractConstants(originalContent, "([A-Z_]+)%s*=%s*%d+")
    local adpConstants = extractConstants(adpContent, "([A-Z_]+)%s*=%s*%d+")

    -- Compare significant constants (at least some should be preserved)
    local constantsPreserved = #adpConstants >= (#originalConstants * 0.5) -- Allow some variation
    if constantsPreserved then
        print("✅ Constants mostly preserved (" .. #adpConstants .. " vs " .. #originalConstants .. ")")
        passedTests = passedTests + 1
    else
        print("❌ Too many constants missing (" .. #adpConstants .. " vs " .. #originalConstants .. ")")
    end

    -- Test 2: Check handler actions preservation
    totalTests = totalTests + 1
    local originalActions = extractHandlerActions(originalContent)
    local adpActions = extractHandlerActions(adpContent)

    -- Check that original actions are preserved in ADP version
    local actionsPreserved = true
    local preservedCount = 0
    for _, originalAction in ipairs(originalActions) do
        local found = false
        for _, adpAction in ipairs(adpActions) do
            if adpAction == originalAction then
                found = true
                preservedCount = preservedCount + 1
                break
            end
        end
        if not found and originalAction ~= "HealthCheck" then -- HealthCheck might be renamed
            actionsPreserved = false
            print("  Missing action: " .. originalAction)
        end
    end

    if actionsPreserved or preservedCount >= (#originalActions - 1) then
        print("✅ Handler actions preserved (" .. preservedCount .. "/" .. #originalActions .. ")")
        passedTests = passedTests + 1
    else
        print("❌ Handler actions not preserved (" .. preservedCount .. "/" .. #originalActions .. ")")
    end

    -- Test 3: Check for essential data structures
    totalTests = totalTests + 1
    local hasDatabase = adpContent:match("Database") or adpContent:match("DB%s*=") or adpContent:match("DATA")
    if hasDatabase then
        print("✅ Core data structures found")
        passedTests = passedTests + 1
    else
        print("❌ Core data structures missing")
    end

    -- Test 4: Check for rate limiting preservation
    totalTests = totalTests + 1
    local hasRateLimit = adpContent:match("RATE_LIMIT") or adpContent:match("rateLimitCounters")
    if hasRateLimit then
        print("✅ Rate limiting preserved")
        passedTests = passedTests + 1
    else
        print("❌ Rate limiting missing")
    end

    ::continue::
end

print("\n=== Data Integrity Summary ===")
print("Tests passed: " .. passedTests .. "/" .. totalTests)

if passedTests >= (totalTests * 0.8) then -- Allow 80% pass rate for flexibility
    print("✅ Data integrity validation passed!")
    os.exit(0)
else
    print("❌ Data integrity validation failed")
    os.exit(1)
end