-- Validate ADP v1.0 compliance by examining process files
print("=== ADP v1.0 Compliance Validation ===")

local processes = {
    "abilities-database-adp.lua",
    "items-database-adp.lua",
    "moves-database-adp.lua",
    "pokemon-species-db-adp.lua"
}

local totalTests = 0
local passedTests = 0

for _, processFile in ipairs(processes) do
    print("\nValidating " .. processFile .. "...")

    local filePath = "processes/" .. processFile
    local file = io.open(filePath, "r")

    if not file then
        print("❌ File not found: " .. filePath)
        totalTests = totalTests + 1
        goto continue
    end

    local content = file:read("*all")
    file:close()

    -- Test 1: Check for Info handler
    totalTests = totalTests + 1
    if content:match('Handlers%.add%("info"') or content:match("hasMatchingTag.-Info") then
        print("✅ Info handler found")
        passedTests = passedTests + 1
    else
        print("❌ Info handler missing")
    end

    -- Test 2: Check for ADP version reference
    totalTests = totalTests + 1
    if content:match('adpVersion.*1%.0') or content:match('ADP.*v1%.0') then
        print("✅ ADP v1.0 reference found")
        passedTests = passedTests + 1
    else
        print("❌ ADP v1.0 reference missing")
    end

    -- Test 3: Check for messageSchemas
    totalTests = totalTests + 1
    if content:match("messageSchemas") then
        print("✅ messageSchemas found")
        passedTests = passedTests + 1
    else
        print("❌ messageSchemas missing")
    end

    -- Test 4: Check for process metadata
    totalTests = totalTests + 1
    if content:match("PROCESS_INFO") or content:match("process.*=.*{") then
        print("✅ Process metadata structure found")
        passedTests = passedTests + 1
    else
        print("❌ Process metadata structure missing")
    end

    -- Test 5: Check for capabilities
    totalTests = totalTests + 1
    if content:match("capabilities") then
        print("✅ Capabilities field found")
        passedTests = passedTests + 1
    else
        print("❌ Capabilities field missing")
    end

    ::continue::
end

print("\n=== Validation Summary ===")
print("Tests passed: " .. passedTests .. "/" .. totalTests)

if passedTests == totalTests then
    print("✅ All ADP v1.0 compliance checks passed!")
    os.exit(0)
else
    print("❌ Some compliance checks failed")
    os.exit(1)
end