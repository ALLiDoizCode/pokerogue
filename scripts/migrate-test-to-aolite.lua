#!/usr/bin/env lua
--[[
  Automated Test Migration Script

  Migrates test files from mock-aolite pattern to real aolite framework pattern.

  Usage:
    lua scripts/migrate-test-to-aolite.lua <test-file-path>

  Example:
    lua scripts/migrate-test-to-aolite.lua testing/unit/my-test.test.lua
]]

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Failed to open file: " .. path
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function writeFile(path, content)
    local file = io.open(path, "w")
    if not file then
        return false, "Failed to write file: " .. path
    end
    file:write(content)
    file:close()
    return true
end

local function extractProcessPath(content)
    -- Try to find process path in spawnProcess call
    local path = content:match('spawnProcess%([^,]+,%s*["\'](.-)["\'')
    if path then
        -- Remove leading "./" if present
        path = path:gsub("^%./", "")
        return path
    end

    -- Fallback: try to find it in dofile
    path = content:match('dofile%(["\'](.-)["\'')
    if path then
        path = path:gsub("^%./", "")
        return path
    end

    return nil
end

local function extractProcessName(processPath)
    if not processPath then
        return "Unknown Process"
    end

    -- Extract filename without extension
    local name = processPath:match("([^/]+)%.lua$")
    if not name then
        return "Unknown Process"
    end

    -- Convert kebab-case or snake_case to Title Case
    name = name:gsub("[-_]", " ")
    name = name:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)

    return name
end

local function parseTestBlocks(content)
    local tests = {}
    local testNumber = 1

    -- Pattern 1: tests["test name"] = function()
    for testName, testBody in content:gmatch('tests%[["\'](.-)["\']%]%s*=%s*function%s*%(%)(.-)end') do
        table.insert(tests, {
            number = testNumber,
            name = testName,
            body = testBody
        })
        testNumber = testNumber + 1
    end

    -- Pattern 2: Look for test sections with comments
    if #tests == 0 then
        for testComment in content:gmatch('%-%-[%s]*Test[%s]+%d+:(.-)%s*\n') do
            table.insert(tests, {
                number = testNumber,
                name = testComment:match("^%s*(.-)%s*$"),
                body = "" -- Will need manual review
            })
            testNumber = testNumber + 1
        end
    end

    return tests
end

local function convertTestBody(testBody, testNumber, testName)
    local converted = {}

    -- Extract message construction
    local msgPattern = 'local%s+msg%s*=%s*{(.-)}'
    local msgContent = testBody:match(msgPattern)

    if msgContent then
        -- Parse message fields
        local action = msgContent:match('["\']?Action["\']?%s*=%s*["\'](.-)["\'%s,]')
        local tags = {}
        local data = msgContent:match('["\']?Data["\']?%s*=%s*(.-)%s*[,}]')

        -- Extract other tags (skip Action, Data, Target, Timestamp)
        for key, value in msgContent:gmatch('([%w_]+)%s*=%s*([^,}]+)') do
            if key ~= "Action" and key ~= "Data" and key ~= "Target" and key ~= "Timestamp" then
                -- Clean up the value
                value = value:gsub("^%s+", ""):gsub("%s+$", "")
                tags[key] = value
            end
        end

        -- Build sendMessage call
        table.insert(converted, string.format('print("📝 Test %d: %s")', testNumber, testName))

        if next(tags) then
            local tagStr = "{"
            local first = true
            for k, v in pairs(tags) do
                if not first then tagStr = tagStr .. ", " end
                tagStr = tagStr .. k .. " = " .. v
                first = false
            end
            tagStr = tagStr .. "}"
            table.insert(converted, string.format('local response = sendMessage("%s", %s, %s)',
                action or "ProcessLogic", tagStr, data or '""'))
        else
            table.insert(converted, string.format('local response = sendMessage("%s", nil, %s)',
                action or "ProcessLogic", data or '""'))
        end
    else
        -- Fallback for simple cases
        table.insert(converted, string.format('print("📝 Test %d: %s")', testNumber, testName))
        table.insert(converted, 'local response = sendMessage("ProcessLogic")')
    end

    -- Add basic validation
    table.insert(converted, 'if not response then')
    table.insert(converted, string.format('    error("❌ Test %d failed: No response")', testNumber))
    table.insert(converted, 'end')

    -- Extract assertions and convert them
    for assertion in testBody:gmatch('assert(%w+)%((.-)%)') do
        if assertion == "Equals" or assertion == "Equal" then
            local args = testBody:match('assert' .. assertion .. '%((.-),(.-)%)')
            if args then
                local actual, expected = args:match('^(.-),%s*(.-)$')
                if actual and expected then
                    table.insert(converted, string.format('if %s ~= %s then', actual:gsub("^%s+", ""):gsub("%s+$", ""), expected:gsub("^%s+", ""):gsub("%s+$", "")))
                    table.insert(converted, string.format('    error("❌ Test %d failed: Expected " .. tostring(%s) .. " but got " .. tostring(%s))', testNumber, expected:gsub("^%s+", ""):gsub("%s+$", ""), actual:gsub("^%s+", ""):gsub("%s+$", "")))
                    table.insert(converted, 'end')
                end
            end
        elseif assertion == "NotNil" then
            local value = testBody:match('assertNotNil%((.-)%)')
            if value then
                value = value:gsub("^%s+", ""):gsub("%s+$", "")
                table.insert(converted, string.format('if not %s then', value))
                table.insert(converted, string.format('    error("❌ Test %d failed: Expected non-nil value")', testNumber))
                table.insert(converted, 'end')
            end
        elseif assertion == "True" then
            local condition = testBody:match('assertTrue%((.-)%)')
            if condition then
                condition = condition:gsub("^%s+", ""):gsub("%s+$", "")
                table.insert(converted, string.format('if not (%s) then', condition))
                table.insert(converted, string.format('    error("❌ Test %d failed: Condition was false")', testNumber))
                table.insert(converted, 'end')
            end
        end
    end

    table.insert(converted, string.format('print("✅ Test %d passed")', testNumber))
    table.insert(converted, '')

    return table.concat(converted, '\n')
end

local function migrateContent(content)
    -- Check if already using real aolite
    if content:match('local aolite = require%("aolite"%)') and
       not content:match('require%("mock%-aolite"%)') then
        return nil, "File already uses real aolite pattern"
    end

    -- Check if using mock-aolite
    if not content:match('require%("mock%-aolite"%)') and
       not content:match('package%.path.*testing/aolite') then
        return nil, "File does not appear to use mock-aolite pattern"
    end

    -- Extract process path
    local processPath = extractProcessPath(content)
    if not processPath then
        return nil, "Could not determine process path from test file"
    end

    local processName = extractProcessName(processPath)

    -- Parse test blocks
    local tests = parseTestBlocks(content)

    -- Build new content
    local lines = {}

    -- Header
    table.insert(lines, '-- Required imports')
    table.insert(lines, 'local aolite = require("aolite")')
    table.insert(lines, 'local json = require("json")')
    table.insert(lines, '')
    table.insert(lines, '-- Test configuration')
    table.insert(lines, 'local TEST_TIMEOUT = 30000  -- 30 seconds')
    table.insert(lines, 'local PROCESS_PATH = "' .. processPath .. '"')
    table.insert(lines, '')
    table.insert(lines, '-- Initialize test process')
    table.insert(lines, 'local process = aolite.spawnProcess(PROCESS_PATH)')
    table.insert(lines, 'if not process then')
    table.insert(lines, '    error("Failed to spawn process from " .. PROCESS_PATH)')
    table.insert(lines, 'end')
    table.insert(lines, '')
    table.insert(lines, 'print("🧪 Starting Aolite Tests for ' .. processName .. '")')
    table.insert(lines, 'print("Process ID:", process.id)')
    table.insert(lines, '')
    table.insert(lines, '-- Test utilities')
    table.insert(lines, 'local function sendMessage(action, tags, data, timeout)')
    table.insert(lines, '    local msg = {')
    table.insert(lines, '        Target = process.id,')
    table.insert(lines, '        Action = action,')
    table.insert(lines, '        Data = data or "",')
    table.insert(lines, '        Timestamp = tostring(os.time() * 1000)')
    table.insert(lines, '    }')
    table.insert(lines, '    if tags then')
    table.insert(lines, '        for k, v in pairs(tags) do')
    table.insert(lines, '            msg[k] = tostring(v)')
    table.insert(lines, '        end')
    table.insert(lines, '    end')
    table.insert(lines, '    return aolite.send(msg, timeout or TEST_TIMEOUT)')
    table.insert(lines, 'end')
    table.insert(lines, '')

    -- Convert tests
    if #tests > 0 then
        for _, test in ipairs(tests) do
            if test.body and test.body ~= "" then
                table.insert(lines, convertTestBody(test.body, test.number, test.name))
            else
                -- Placeholder for manual review
                table.insert(lines, string.format('-- Test %d: %s', test.number, test.name))
                table.insert(lines, string.format('print("📝 Test %d: %s")', test.number, test.name))
                table.insert(lines, 'local response = sendMessage("ProcessLogic")')
                table.insert(lines, 'if not response then')
                table.insert(lines, string.format('    error("❌ Test %d failed: No response")', test.number))
                table.insert(lines, 'end')
                table.insert(lines, '-- TODO: Add test assertions')
                table.insert(lines, string.format('print("✅ Test %d passed")', test.number))
                table.insert(lines, '')
            end
        end
    else
        -- No tests found, create placeholder
        table.insert(lines, '-- Test 1: Basic functionality')
        table.insert(lines, 'print("📝 Test 1: Basic functionality")')
        table.insert(lines, 'local response = sendMessage("ProcessLogic")')
        table.insert(lines, 'if not response then')
        table.insert(lines, '    error("❌ Test 1 failed: No response")')
        table.insert(lines, 'end')
        table.insert(lines, '-- TODO: Add test assertions')
        table.insert(lines, 'print("✅ Test 1 passed")')
        table.insert(lines, '')
    end

    -- Footer
    table.insert(lines, '-- Test Summary')
    table.insert(lines, 'print("==================================================")')
    table.insert(lines, 'print("🎉 All tests passed!")')
    table.insert(lines, 'print("✅ Test file executed successfully: " .. PROCESS_PATH)')

    return table.concat(lines, '\n')
end

-- Main execution
local function main(args)
    if #args < 1 then
        print("Usage: lua scripts/migrate-test-to-aolite.lua <test-file-path>")
        print("")
        print("Example:")
        print("  lua scripts/migrate-test-to-aolite.lua testing/unit/my-test.test.lua")
        return 1
    end

    local filePath = args[1]

    print("📄 Reading test file: " .. filePath)
    local content, err = readFile(filePath)
    if not content then
        print("❌ Error: " .. err)
        return 1
    end

    print("🔄 Migrating to real aolite pattern...")
    local migratedContent, migrationErr = migrateContent(content)
    if not migratedContent then
        print("⚠️  " .. migrationErr)
        return 1
    end

    print("💾 Writing migrated content...")
    local success, writeErr = writeFile(filePath, migratedContent)
    if not success then
        print("❌ Error: " .. writeErr)
        return 1
    end

    print("✅ Migration complete: " .. filePath)
    print("")
    print("⚠️  IMPORTANT: Please review the migrated file and:")
    print("   1. Verify test assertions are correct")
    print("   2. Add any missing test logic")
    print("   3. Run: npm run test:aolite")

    return 0
end

-- Run main with command line arguments
os.exit(main(arg))
