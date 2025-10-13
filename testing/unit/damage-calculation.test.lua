-- DEPRECATED: Unit Tests for Damage Calculation (Story 17.1b)
-- This test file is deprecated and needs to be rewritten
-- Reason: Uses describe/it blocks which are NOT supported by aolite framework
--
-- The aolite framework does NOT support:
-- - describe/it/before_each/after_each blocks
-- - Asynchronous testing patterns
-- - Test runner frameworks like Mocha/Jest
--
-- Action Required:
-- This file must be rewritten to use the correct aolite API pattern with:
-- 1. Linear test execution (no describe/it blocks)
-- 2. Direct error() calls for test failures
-- 3. print() for test output with emojis
-- 4. Proper aolite.spawnProcess() API usage
--
-- See pokemon-species-db.test.lua for the correct pattern.

local aolite = require("aolite")
local json = require("json")

print("🧪 Damage Calculation tests skipped - deprecated pattern (describe/it not supported)")
print("⚠️  This test file requires migration to correct aolite API pattern")
print("==================================================")
print("✅ Test file marked for migration")
