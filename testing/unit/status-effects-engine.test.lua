-- DEPRECATED: Status Effects Engine Unit Tests
-- Tests status effect application, turn processing, removal, and interactions
-- This test file is deprecated and needs to be rewritten
-- Reason: Uses incorrect aolite API (CRITICAL) and references non-existent process
-- Process file: processes/status-effects-engine.lua (DOES NOT EXIST)
--
-- CRITICAL API VIOLATIONS (Story 20.1):
-- ❌ OLD: local process = aolite.spawnProcess(PROCESS_PATH)
-- ✅ NEW: aolite.spawnProcess(processId, processSource, spawnTags)
-- ❌ OLD: Target = process.id (process.id doesn't exist)
-- ✅ NEW: From = processId, Target = processId
-- ❌ OLD: return aolite.send(msg, timeout)
-- ✅ NEW: aolite.send(msg); return aolite.getLastMsg(processId)
-- ❌ OLD: Timestamp = tostring(os.time() * 1000)
-- ✅ NEW: No Timestamp field needed
-- ❌ OLD: TEST_TIMEOUT parameter
-- ✅ NEW: No timeout parameter
--
-- Action Required:
-- 1. Create the missing process file: processes/status-effects-engine.lua
-- 2. Rewrite this file to use the CORRECT aolite API pattern
--
-- See pokemon-species-db.test.lua for the correct pattern.

local aolite = require("aolite")
local json = require("json")

print("🧪 Status Effects Engine tests skipped - INCORRECT API (Story 20.1)")
print("⚠️  This test file requires:")
print("   1. Process file creation: processes/status-effects-engine.lua")
print("   2. Migration to CORRECT aolite API")
print("==================================================")
print("✅ Test file marked for re-migration")
