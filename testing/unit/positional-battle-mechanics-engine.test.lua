-- DEPRECATED: Positional Battle Mechanics Engine Unit Tests
-- Tests battlefield positioning effects including delayed attacks and position-based healing
-- This test file is deprecated and needs to be rewritten
-- Reason: Uses incorrect aolite API and references non-existent process
-- Process file: processes/positional-battle-mechanics-engine.lua (DOES NOT EXIST)
--
-- Issues with current implementation:
-- - Uses incorrect aolite API: processId = aolite.spawnProcess(path)
-- - Uses aolite.send(processId, msg) (incorrect signature)
-- - References non-existent process file
-- - Uses custom test function pattern
--
-- CRITICAL API VIOLATIONS (Story 20.1):
-- ❌ OLD: processId = aolite.spawnProcess(path)
-- ✅ NEW: aolite.spawnProcess(processId, processSource, spawnTags)
-- ❌ OLD: aolite.send(processId, msg)
-- ✅ NEW: aolite.send(msg); return aolite.getLastMsg(processId)
--
-- Action Required:
-- 1. Create the missing process file: processes/positional-battle-mechanics-engine.lua
-- 2. Rewrite this file to use the CORRECT aolite API pattern
--
-- See pokemon-species-db.test.lua for the correct pattern.

local aolite = require("aolite")
local json = require("json")

print("🧪 Positional Battle Mechanics Engine tests skipped - INCORRECT API (Story 20.1)")
print("⚠️  This test file requires:")
print("   1. Process file creation: processes/positional-battle-mechanics-engine.lua")
print("   2. Migration to CORRECT aolite API")
print("==================================================")
print("✅ Test file marked for re-migration")
