-- DEPRECATED: Battle Engine Turn Manager Unit Tests
-- This test file is deprecated and needs to be rewritten
-- Reason: Uses incorrect aolite API and references non-existent process
-- Process file: processes/battle-engine-turn-manager.lua (DOES NOT EXIST)
--
-- Issues with current implementation:
-- - Uses incorrect aolite API: process = aolite.spawnProcess(path)
-- - References non-existent process file
-- - Uses custom test suite pattern instead of linear execution
-- - Uses aolite.setMessageLog() (may not be in correct API)
-- - Uses aolite.runScheduler() (may not be in correct API)
-- - Uses aolite.getAllMsgs() (may not be in correct API)
-- - Uses aolite.clearMessages() (may not be in correct API)
--
-- Action Required:
-- 1. Create the missing process file: processes/battle-engine-turn-manager.lua
-- 2. Rewrite this file to use the correct aolite API pattern with:
--    - processId = "test-battle-engine-turn-manager" (string)
--    - Read process source with io.open()
--    - aolite.spawnProcess(processId, processSource, spawnTags)
--    - sendMessage with From field
--    - aolite.send(msg) followed by aolite.getLastMsg(processId)
--    - Linear test execution (no custom test suite)
--    - Direct error() calls for test failures
--    - print() for test output with emojis
--
-- See pokemon-species-db.test.lua for the correct pattern.

local aolite = require("aolite")
local json = require("json")

print("🧪 Battle Engine Turn Manager tests skipped - deprecated pattern")
print("⚠️  This test file requires:")
print("   1. Process file creation: processes/battle-engine-turn-manager.lua")
print("   2. Migration to correct aolite API pattern")
print("==================================================")
print("✅ Test file marked for migration")
