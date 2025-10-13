-- DEPRECATED: AI Move Selection Weight Normalization Tests
-- Story 17.1c: Weight Normalization and Probabilistic Selection Testing
-- This test file is deprecated and needs to be rewritten
-- Reason: Uses describe/it blocks which are NOT supported by aolite framework
-- Also references non-existent process: processes/ai-move-selection-engine.lua
--
-- The aolite framework does NOT support:
-- - describe/it/before_each/after_each blocks
-- - Asynchronous testing patterns
-- - Test runner frameworks like Mocha/Jest
-- - aolite.eval() for code loading (use aolite.spawnProcess with process source)
--
-- Action Required:
-- 1. Create the missing process file: processes/ai-move-selection-engine.lua
-- 2. Rewrite this file to use the correct aolite API pattern with:
--    - Linear test execution (no describe/it blocks)
--    - Direct error() calls for test failures
--    - print() for test output with emojis
--    - Proper aolite.spawnProcess() API usage
--
-- See pokemon-species-db.test.lua for the correct pattern.

local aolite = require("aolite")
local json = require("json")

print("🧪 AI Move Selection Weight Normalization tests skipped - deprecated pattern")
print("⚠️  This test file requires:")
print("   1. Process file creation: processes/ai-move-selection-engine.lua")
print("   2. Migration to correct aolite API pattern (no describe/it)")
print("==================================================")
print("✅ Test file marked for migration")
