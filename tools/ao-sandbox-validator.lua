-- AO Sandbox Compatibility Validator
print("🔍 AO Sandbox Compatibility Validation")
print("=============================================================")

local processes = {}
local function scanProcesses(dir)
    local handle = io.popen('find ' .. dir .. ' -name "*.lua" -type f')
    for file in handle:lines() do
        if not file:match("-legacy%.lua$") and not file:match("/generated/") then -- Skip legacy files and generated data
            table.insert(processes, file)
        end
    end
    handle:close()
end

scanProcesses("processes")

local totalTests = 0
local passedTests = 0

for _, processFile in ipairs(processes) do
    local filename = processFile:match("([^/]+)$")
    print("\n📄 Validating " .. filename .. "...")
    
    local file = io.open(processFile, "r")
    if not file then
        print("❌ Cannot read file: " .. processFile)
        goto continue
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Test 1: No forbidden require() statements (json require is allowed)
    totalTests = totalTests + 1
    -- Remove comments before checking for require
    local contentNoComments = content:gsub("%-%-[^\n]*", "")
    local forbiddenRequireMatches = {}
    
    -- Find all require statements
    for match in contentNoComments:gmatch("require%s*%([^%)]*%)") do
        -- Allow json require, block others
        if not match:match('require%s*%(%s*["\']json["\']%s*%)') then
            table.insert(forbiddenRequireMatches, match)
        end
    end
    
    if #forbiddenRequireMatches == 0 then
        print("✅ No forbidden external dependencies (json require allowed)")
        passedTests = passedTests + 1
    else
        print("❌ Contains forbidden require() statements:")
        for _, match in ipairs(forbiddenRequireMatches) do
            print("   " .. match)
        end
        print("   💡 Only json require is allowed: require(\"json\")")
    end
    
    -- Test 2: Uses Handlers.add pattern
    totalTests = totalTests + 1
    if content:match("Handlers%.add%s*%(") then
        print("✅ Uses proper Handlers.add pattern")
        passedTests = passedTests + 1
    else
        print("❌ Missing Handlers.add pattern")
    end
    
    -- Test 3: Forbidden pcall patterns (anti-pattern detection)
    totalTests = totalTests + 1
    local forbiddenPcallPatterns = {
        "pcall%s*%(%s*json%.decode%s*,",  -- pcall(json.decode, ...) for controlled data
        "pcall%s*%(%s*function%s*%(%).*handler",  -- wrapping entire handlers
        "pcall%s*%(%s*function%s*%(msg%).*end%s*%)",  -- handler wrapper functions
    }
    
    local foundForbiddenPcall = false
    for _, pattern in ipairs(forbiddenPcallPatterns) do
        if content:match(pattern) then
            print("❌ Forbidden pcall pattern detected: unnecessary pcall usage")
            foundForbiddenPcall = true
            break
        end
    end
    
    if not foundForbiddenPcall then
        print("✅ No forbidden pcall anti-patterns found")
        passedTests = passedTests + 1
    end
    
    -- Test 4: No forbidden operations
    totalTests = totalTests + 1
    local forbidden = false
    local forbiddenOps = {
        "debug%.", "loadfile", "dofile", "loadstring", "os%.time%("  -- Add os.time() as forbidden
    }
    for _, op in ipairs(forbiddenOps) do
        if contentNoComments:match(op) then  -- Check content without comments
            print("❌ Contains forbidden operation: " .. op:gsub("%%", ""))
            forbidden = true
            break
        end
    end
    
    -- Special check for io. operations (excluding ao.id)
    if content:match("io%.") and not content:match("ao%.id") then
        local ioMatches = {}
        for match in content:gmatch("[%w_]*io%.[%w_]*") do
            if not match:match("ao%.id") then
                table.insert(ioMatches, match)
            end
        end
        if #ioMatches > 0 then
            print("❌ Contains forbidden operation: io.")
            forbidden = true
        end
    end
    if not forbidden then
        print("✅ No forbidden operations found")
        passedTests = passedTests + 1
    end
    
    -- Test 5: AO global usage
    totalTests = totalTests + 1
    if content:match("ao%.send") and content:match("ao%.id") then
        print("✅ Uses AO globals correctly")
        passedTests = passedTests + 1
    else
        print("❌ Missing proper AO global usage")
    end
    
    ::continue::
end

print("\n=============================================================")
-- Additional validation: AO compliance best practices
local complianceWarnings = 0
local complianceChecks = 0

for _, processFile in ipairs(processes) do
    local file = io.open(processFile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        -- Check for direct error handling patterns (preferred over pcall)
        complianceChecks = complianceChecks + 1
        if content:match("ao%.send%s*%([^%)]*Error[^%)]*%)") then
            print("✅ " .. processFile:match("([^/]+)$") .. ": Uses direct error handling with ao.send()")
        else
            print("⚠️  " .. processFile:match("([^/]+)$") .. ": Consider adding direct error handling patterns")
            complianceWarnings = complianceWarnings + 1
        end
        
        -- Check for proper timestamp handling
        complianceChecks = complianceChecks + 1
        if content:match("msg%.Timestamp") then
            print("✅ " .. processFile:match("([^/]+)$") .. ": Uses msg.Timestamp for deterministic execution")
        else
            print("⚠️  " .. processFile:match("([^/]+)$") .. ": Consider using msg.Timestamp instead of os.time()")
            complianceWarnings = complianceWarnings + 1
        end
    end
end

print("\n=============================================================")
print("📊 AO Sandbox Validation Summary:")
print("Critical tests passed: " .. passedTests .. "/" .. totalTests)
print("Compliance warnings: " .. complianceWarnings .. "/" .. complianceChecks)
print("Success rate: " .. string.format("%.1f", (passedTests/totalTests)*100) .. "%")

-- Strict compliance: 100% critical tests must pass
if passedTests == totalTests then
    if complianceWarnings == 0 then
        print("✅ AO sandbox validation passed with perfect compliance!")
        os.exit(0)
    else
        print("⚠️  AO sandbox validation passed but with " .. complianceWarnings .. " compliance warnings")
        print("   Consider addressing warnings for production-ready code")
        os.exit(0)  -- Still pass but warn
    end
else
    print("❌ AO sandbox validation failed")
    print("   Critical compliance violations must be fixed before deployment")
    os.exit(1)
end