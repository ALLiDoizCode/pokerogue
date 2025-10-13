#!/usr/bin/env lua
-- Automated refactoring script for Story 2.10
-- Optimizes aolite process spawning pattern across all test files
--
-- Transforms:
--   FROM: io.open() + file:read() + spawnTags + 3-arg spawn (9 lines)
--   TO: Module path + 2-arg spawn (3 lines)
--
-- Usage:
--   lua scripts/optimize-aolite-spawning.lua [--dry-run] file1.lua file2.lua ...
--   find testing/unit -name "*.test.lua" -exec lua scripts/optimize-aolite-spawning.lua {} +

-- Configuration
local DRY_RUN = false
local VALIDATE = true
local stats = {
    processed = 0,
    transformed = 0,
    skipped = 0,
    errors = 0,
    linesRemoved = 0
}

-- Parse command-line arguments
local files = {}
for i = 1, #arg do
    if arg[i] == "--dry-run" then
        DRY_RUN = true
        print("🔍 DRY RUN MODE - No files will be modified")
    elseif arg[i]:match("%.lua$") then
        table.insert(files, arg[i])
    end
end

if #files == 0 then
    print("❌ Error: No files specified")
    print("Usage: lua scripts/optimize-aolite-spawning.lua [--dry-run] file1.lua file2.lua ...")
    os.exit(1)
end

print(string.format("📋 Found %d test files to process\n", #files))

-- Utility: Extract PROCESS_PATH value from file content
local function extractProcessPath(content)
    -- Pattern: local PROCESS_PATH = "processes/something.lua" or 'processes/something.lua'
    local path = content:match('local%s+PROCESS_PATH%s*=%s*"([^"]+)"')
    if not path then
        path = content:match("local%s+PROCESS_PATH%s*=%s*'([^']+)'")
    end
    return path
end

-- Utility: Transform file path to module path
local function pathToModule(filePath)
    -- "processes/pokemon-species-db.lua" → "processes.pokemon-species-db"
    local modulePath = filePath:gsub("%.lua$", ""):gsub("/", ".")
    return modulePath
end

-- Utility: Check if file uses io.open pattern
local function hasIoOpenPattern(content)
    return content:match("io%.open%(PROCESS_PATH") ~= nil
end

-- Utility: Remove io.open block (5 lines)
local function removeIoOpenBlock(content)
    -- Pattern to match the entire io.open block:
    -- local file = io.open(PROCESS_PATH, "r")
    -- if not file then
    --     error("Failed to open process file: " .. PROCESS_PATH)
    -- end
    -- local processSource = file:read("*all")
    -- file:close()

    local pattern = [[
%-%- Read process source
local file = io%.open%(PROCESS_PATH, "r"%)
if not file then
    error%("Failed to open process file: " %.%. PROCESS_PATH%)
end
local processSource = file:read%("%*all"%)
file:close%(%)

]]

    content = content:gsub(pattern, "")

    -- Alternative pattern without "Read process source" comment
    local pattern2 = [[local file = io%.open%(PROCESS_PATH, "r"%)
if not file then
    error%("Failed to open process file: " %.%. PROCESS_PATH%)
end
local processSource = file:read%("%*all"%)
file:close%(%)

]]

    content = content:gsub(pattern2, "")

    return content
end

-- Utility: Remove spawnTags line
local function removeSpawnTags(content)
    -- Pattern: local spawnTags = { { name = "On-Boot", value = "Data" } }
    local pattern = 'local spawnTags = %{ %{ name = "On%-Boot", value = "Data" %} %}\n'
    content = content:gsub(pattern, "")

    return content
end

-- Utility: Update PROCESS_PATH to module notation
local function updateProcessPath(content, oldPath)
    local modulePath = pathToModule(oldPath)
    local escapedPath = oldPath:gsub("%-", "%%-"):gsub("%.", "%%.")

    -- Try double quotes first
    local pattern = 'local PROCESS_PATH = "' .. escapedPath .. '"'
    local replacement = 'local PROCESS_PATH = "' .. modulePath .. '"'
    local newContent = content:gsub(pattern, replacement)

    -- If no replacement, try single quotes
    if newContent == content then
        pattern = "local PROCESS_PATH = '" .. escapedPath .. "'"
        replacement = 'local PROCESS_PATH = "' .. modulePath .. '"'
        newContent = content:gsub(pattern, replacement)
    end

    return newContent
end

-- Utility: Update spawnProcess call (3-arg to 2-arg)
local function updateSpawnCall(content)
    -- Pattern: aolite.spawnProcess(processId, processSource, spawnTags)
    local pattern = "aolite%.spawnProcess%(processId, processSource, spawnTags%)"
    local replacement = "aolite.spawnProcess(processId, PROCESS_PATH)"
    content = content:gsub(pattern, replacement)

    return content
end

-- Main transformation function
local function transformFile(filePath)
    stats.processed = stats.processed + 1

    -- Read file
    local file = io.open(filePath, "r")
    if not file then
        print(string.format("❌ Error: Cannot open file: %s", filePath))
        stats.errors = stats.errors + 1
        return false
    end

    local originalContent = file:read("*all")
    file:close()

    -- Check if file needs transformation
    if not hasIoOpenPattern(originalContent) then
        print(string.format("⏭️  Skipped: %s (no io.open pattern found)", filePath))
        stats.skipped = stats.skipped + 1
        return true
    end

    -- Extract PROCESS_PATH
    local oldPath = extractProcessPath(originalContent)
    if not oldPath then
        print(string.format("❌ Error: Cannot extract PROCESS_PATH from: %s", filePath))
        stats.errors = stats.errors + 1
        return false
    end

    print(string.format("🔄 Transforming: %s", filePath))
    print(string.format("   Path: %s → %s", oldPath, pathToModule(oldPath)))

    -- Apply transformations
    local content = originalContent
    local linesBefore = select(2, originalContent:gsub("\n", "\n")) + 1

    content = updateProcessPath(content, oldPath)
    content = removeIoOpenBlock(content)
    content = removeSpawnTags(content)
    content = updateSpawnCall(content)

    local linesAfter = select(2, content:gsub("\n", "\n")) + 1
    local linesRemoved = linesBefore - linesAfter
    stats.linesRemoved = stats.linesRemoved + linesRemoved

    print(string.format("   Lines removed: %d", linesRemoved))

    -- Dry run check
    if DRY_RUN then
        print("   [DRY RUN] Would write changes\n")
        stats.transformed = stats.transformed + 1
        return true
    end

    -- Write transformed content
    file = io.open(filePath, "w")
    if not file then
        print(string.format("❌ Error: Cannot write file: %s", filePath))
        stats.errors = stats.errors + 1
        return false
    end

    file:write(content)
    file:close()

    -- Validate syntax
    if VALIDATE then
        local result = os.execute(string.format("luac -p '%s' 2>/dev/null", filePath))
        -- Lua 5.2+ returns true/nil/exitcode, Lua 5.1 returns exitcode
        local success = (type(result) == "boolean" and result) or (type(result) == "number" and result == 0)
        if not success then
            print(string.format("⚠️  Warning: Syntax validation failed for %s", filePath))
            stats.errors = stats.errors + 1
            return false
        end
    end

    print(string.format("✅ Transformed: %s\n", filePath))
    stats.transformed = stats.transformed + 1
    return true
end

-- Process all files
print("=" .. string.rep("=", 60))
print("🚀 Starting Aolite Spawning Pattern Optimization")
print("=" .. string.rep("=", 60) .. "\n")

for _, filePath in ipairs(files) do
    transformFile(filePath)
end

-- Print summary
print("\n" .. "=" .. string.rep("=", 60))
print("📊 Transformation Summary")
print("=" .. string.rep("=", 60))
print(string.format("Files processed:   %d", stats.processed))
print(string.format("Files transformed: %d", stats.transformed))
print(string.format("Files skipped:     %d", stats.skipped))
print(string.format("Errors:            %d", stats.errors))
print(string.format("Lines removed:     %d", stats.linesRemoved))
print(string.rep("=", 62))

if stats.errors > 0 then
    print("\n⚠️  Completed with errors - review failed files above")
    os.exit(1)
elseif stats.transformed > 0 then
    print("\n✅ Optimization complete!")
    if not DRY_RUN then
        print("💡 Next step: Run 'npm run test:aolite' to validate changes")
    end
    os.exit(0)
else
    print("\n✅ No files needed transformation")
    os.exit(0)
end
