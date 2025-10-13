local aolite = require("aolite")

print("Testing process spawn...")

local PROCESS_PATH = "processes.voucher-economy-engine"
local processId = "test-spawn"

print("Attempting to spawn:", PROCESS_PATH)
local success, err = pcall(function()
    aolite.spawnProcess(processId, PROCESS_PATH)
end)

if success then
    print("✅ Process spawned successfully")
else
    print("❌ Process spawn failed:", err)
end

-- Also try with file path
local FILE_PATH = "processes/voucher-economy-engine.lua"
local file = io.open(FILE_PATH, "r")
if file then
    print("✅ File exists:", FILE_PATH)
    local source = file:read("*all")
    file:close()
    print("📦 File size:", #source, "bytes")

    -- Try spawning with source string
    print("Attempting to spawn with source string...")
    local success2, err2 = pcall(function()
        aolite.spawnProcess("test-spawn2", source)
    end)

    if success2 then
        print("✅ Process spawned with source")
    else
        print("❌ Spawn with source failed:", err2)
    end
else
    print("❌ File not found:", FILE_PATH)
end
