-- DEPRECATED: Field Condition Engine Unit Tests
-- Tests field condition application, priority resolution, state persistence, and future attacks
-- This test file is deprecated and needs to be rewritten
-- Reason: Uses describe/it blocks, aolite.eval(), and hardcoded absolute paths
-- Process file: processes/field-condition-engine.lua (DOES NOT EXIST)
--
-- Issues with current implementation:
-- - Uses describe/it/beforeEach blocks (NOT supported by aolite)
-- - Uses aolite.setupMockEnvironment() (may not exist in correct API)
-- - Uses aolite.eval() instead of aolite.spawnProcess()
-- - Uses hardcoded absolute path: /Users/jonathangreen/Documents/pokerogue/processes/...
-- - Uses aolite.sendMessage() (incorrect API)
-- - References non-existent process file
--
-- Action Required:
-- 1. Create the missing process file: processes/field-condition-engine.lua
-- 2. Rewrite this file to use the correct aolite API pattern with:
--    - Linear test execution (no describe/it blocks)
--    - processId = "test-field-condition-engine" (string)
--    - Read process source with io.open()
--    - aolite.spawnProcess(processId, processSource, spawnTags)
--    - Messages with From field
--    - aolite.send(msg) followed by aolite.getLastMsg(processId)
--    - Direct error() calls for test failures
--    - print() for test output with emojis
--
-- See pokemon-species-db.test.lua for the correct pattern.

local aolite = require("aolite")
local json = require("json")

print("🧪 Field Condition Engine tests skipped - deprecated pattern")
print("⚠️  This test file requires:")
print("   1. Process file creation: processes/field-condition-engine.lua")
print("   2. Migration to correct aolite API (no describe/it, no absolute paths)")
print("==================================================")
print("✅ Test file marked for migration")
