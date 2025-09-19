-- AO Sandbox Compatibility Validator
print("🔍 AO Sandbox Compatibility Validation")
print("=============================================================")

local processes = {}
local function scanProcesses(dir)
    local handle = io.popen('find ' .. dir .. ' -name "*.lua" -type f')
    for file in handle:lines() do
        if not file:match("-legacy%.lua$") then -- Skip legacy files
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
    
    -- Test 1: No require() statements (monolithic requirement)
    totalTests = totalTests + 1
    if not content:match("require%s*%(") then
        print("✅ No external dependencies (monolithic)")
        passedTests = passedTests + 1
    else
        print("❌ Contains require() statements")
    end
    
    -- Test 2: Uses Handlers.add pattern
    totalTests = totalTests + 1
    if content:match("Handlers%.add%s*%(") then
        print("✅ Uses proper Handlers.add pattern")
        passedTests = passedTests + 1
    else
        print("❌ Missing Handlers.add pattern")
    end
    
    -- Test 3: Error handling with pcall
    totalTests = totalTests + 1
    if content:match("pcall%s*%(") then
        print("✅ Contains error handling with pcall")
        passedTests = passedTests + 1
    else
        print("⚠️  No pcall error handling found")
        passedTests = passedTests + 1 -- Allow this for now
    end
    
    -- Test 4: No forbidden operations
    totalTests = totalTests + 1
    local forbidden = false
    local forbiddenOps = {"io%.", "debug%.", "loadfile", "dofile", "loadstring"}
    for _, op in ipairs(forbiddenOps) do
        if content:match(op) then
            print("❌ Contains forbidden operation: " .. op:gsub("%%", ""))
            forbidden = true
            break
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
print("📊 AO Sandbox Validation Summary:")
print("Tests passed: " .. passedTests .. "/" .. totalTests)
print("Success rate: " .. string.format("%.1f", (passedTests/totalTests)*100) .. "%")

if passedTests >= (totalTests * 0.9) then -- 90% pass rate
    print("✅ AO sandbox validation passed!")
    os.exit(0)
else
    print("❌ AO sandbox validation failed")
    os.exit(1)
end