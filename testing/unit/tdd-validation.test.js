/**
 * Test Suite for TDD Validation Logic
 * Tests the core TDD validation functions to ensure reliable test-first enforcement
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "fs";
import { join } from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const TEST_DIR = join(process.cwd(), "test-temp");
const TDD_VALIDATOR_PATH = join(process.cwd(), "scripts/hooks/tdd-validation.lua");

describe("TDD Validation Logic", () => {
  beforeEach(() => {
    // Create temporary test directory
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterEach(() => {
    // Clean up temporary files
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
  });

  describe("shouldExclude functionality", () => {
    it("should exclude files in data directory", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH} validate data/sample.lua`, { encoding: "utf8" });
      expect(result).toContain("File excluded from TDD requirements");
    });

    it("should exclude template files", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH} validate templates/test.lua`, { encoding: "utf8" });
      expect(result).toContain("File excluded from TDD requirements");
    });

    it("should exclude fixture files", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH} validate fixtures/data.lua`, { encoding: "utf8" });
      expect(result).toContain("File excluded from TDD requirements");
    });

    it("should exclude existing test files", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH} validate test/sample.test.lua`, { encoding: "utf8" });
      expect(result).toContain("File excluded from TDD requirements");
    });
  });

  describe("getTestFilePath functionality", () => {
    it("should map processes files to testing/unit", () => {
      const testFile = join(TEST_DIR, "processes", "battle.lua");
      mkdirSync(join(TEST_DIR, "processes"), { recursive: true });
      writeFileSync(testFile, "function test() end");

      try {
        const result = execSync(`cd ${TEST_DIR} && lua ${TDD_VALIDATOR_PATH} validate processes/battle.lua`, {
          encoding: "utf8",
        });
        expect(result).toContain("testing/unit/battle.test.lua");
      } catch (error) {
        // Expected - test file doesn't exist
        expect(error.stdout || error.message).toContain("testing/unit/battle.test.lua");
      }
    });

    it("should map ao-processes files correctly", () => {
      const testFile = join(TEST_DIR, "ao-processes", "stats.lua");
      mkdirSync(join(TEST_DIR, "ao-processes"), { recursive: true });
      writeFileSync(testFile, "function calculateStat() end");

      try {
        const result = execSync(`cd ${TEST_DIR} && lua ${TDD_VALIDATOR_PATH} validate ao-processes/stats.lua`, {
          encoding: "utf8",
        });
        expect(result).toContain("ao-processes/tests/unit/stats.test.lua");
      } catch (error) {
        // Expected - test file doesn't exist
        expect(error.stdout || error.message).toContain("ao-processes/tests/unit/stats.test.lua");
      }
    });

    it("should skip ao-processes test files", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH} validate ao-processes/tests/unit/stats.test.lua`, {
        encoding: "utf8",
      });
      expect(result).toContain("File excluded from TDD requirements");
    });
  });

  describe("validateTestExists functionality", () => {
    it("should pass when test file exists", () => {
      const sourceFile = join(TEST_DIR, "processes", "battle.lua");
      const testFile = join(TEST_DIR, "testing", "unit", "battle.test.lua");

      mkdirSync(join(TEST_DIR, "processes"), { recursive: true });
      mkdirSync(join(TEST_DIR, "testing", "unit"), { recursive: true });

      writeFileSync(sourceFile, "function battle() end");
      writeFileSync(testFile, 'describe("battle", function() end)');

      const result = execSync(`cd ${TEST_DIR} && lua ${TDD_VALIDATOR_PATH} validate processes/battle.lua`, {
        encoding: "utf8",
      });
      expect(result).toContain("Test file exists");
    });

    it("should fail when test file is missing", () => {
      const sourceFile = join(TEST_DIR, "processes", "battle.lua");

      mkdirSync(join(TEST_DIR, "processes"), { recursive: true });
      writeFileSync(sourceFile, "function battle() end");

      try {
        execSync(`cd ${TEST_DIR} && lua ${TDD_VALIDATOR_PATH} validate processes/battle.lua`);
        expect.fail("Should have failed");
      } catch (error) {
        expect(error.stdout || error.message).toContain("Missing test file");
      }
    });
  });

  describe("extractFunctions functionality", () => {
    it("should extract regular function definitions", () => {
      const sourceFile = join(TEST_DIR, "sample.lua");
      writeFileSync(
        sourceFile,
        `
        function calculateDamage(attack, defense)
          return attack - defense
        end
        
        function validateInput(data)
          return data ~= nil
        end
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("calculateDamage (function)");
      expect(result).toContain("validateInput (function)");
    });

    it("should extract local function definitions", () => {
      const sourceFile = join(TEST_DIR, "sample.lua");
      writeFileSync(
        sourceFile,
        `
        local function helper(value)
          return value * 2
        end
        
        local function process(data)
          return helper(data)
        end
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("helper (local_function)");
      expect(result).toContain("process (local_function)");
    });

    it("should extract table method definitions", () => {
      const sourceFile = join(TEST_DIR, "sample.lua");
      writeFileSync(
        sourceFile,
        `
        Stats.calculate = function(pokemon)
          return pokemon.baseStat
        end
        
        Battle.processMove = function(move)
          return move.power
        end
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("Stats.calculate (method)");
      expect(result).toContain("Battle.processMove (method)");
    });

    it("should extract AO handler definitions", () => {
      const sourceFile = join(TEST_DIR, "sample.lua");
      writeFileSync(
        sourceFile,
        `
        Handlers.add("process-move", 
          Handlers.utils.hasMatchingTag("Action", "ProcessMove"),
          function(msg)
            return processMove(msg)
          end
        )
        
        Handlers.add('calculate-stats',
          function(msg) return msg.Action == "CalculateStats" end,
          function(msg)
            return calculateStats(msg.Data)
          end
        )
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("Handler:process-move (handler)");
      expect(result).toContain("Handler:calculate-stats (handler)");
    });
  });

  describe("validateTestCoverage functionality", () => {
    it("should pass when all functions are covered", () => {
      const sourceFile = join(TEST_DIR, "battle.lua");
      const testFile = join(TEST_DIR, "battle.test.lua");

      writeFileSync(
        sourceFile,
        `
        function calculateDamage(attack, defense)
          return attack - defense
        end
        
        function validateMove(move)
          return move ~= nil
        end
      `,
      );

      writeFileSync(
        testFile,
        `
        describe("calculateDamage", function()
          it("should calculate damage correctly", function()
            assert(calculateDamage(100, 50) == 50)
          end)
        end)
        
        describe("validateMove", function()
          it("should validate move input", function()
            assert(validateMove({}) == true)
          end)
        end)
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} coverage ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("All functions covered");
    });

    it("should fail when functions are uncovered", () => {
      const sourceFile = join(TEST_DIR, "battle.lua");
      const testFile = join(TEST_DIR, "battle.test.lua");

      writeFileSync(
        sourceFile,
        `
        function calculateDamage(attack, defense)
          return attack - defense
        end
        
        function validateMove(move)
          return move ~= nil
        end
        
        function untested()
          return true
        end
      `,
      );

      writeFileSync(
        testFile,
        `
        describe("calculateDamage", function()
          it("should calculate damage correctly", function()
            assert(calculateDamage(100, 50) == 50)
          end)
        end)
      `,
      );

      try {
        execSync(`lua ${TDD_VALIDATOR_PATH} coverage ${sourceFile}`);
        expect.fail("Should have failed");
      } catch (error) {
        expect(error.stdout || error.message).toContain("Uncovered functions");
        expect(error.stdout || error.message).toContain("validateMove");
        expect(error.stdout || error.message).toContain("untested");
      }
    });

    it("should handle files with no functions", () => {
      const sourceFile = join(TEST_DIR, "constants.lua");
      const testFile = join(TEST_DIR, "constants.test.lua");

      writeFileSync(
        sourceFile,
        `
        local CONSTANTS = {
          MAX_HEALTH = 100,
          MAX_LEVEL = 50
        }
        
        return CONSTANTS
      `,
      );

      writeFileSync(
        testFile,
        `
        describe("constants", function()
          it("should have correct values", function()
            assert(true)
          end)
        end)
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} coverage ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("No functions to test");
    });
  });

  describe("Command-line interface", () => {
    it("should show usage when no arguments provided", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH}`, { encoding: "utf8" });
      expect(result).toContain("Usage:");
      expect(result).toContain("validate");
      expect(result).toContain("extract");
      expect(result).toContain("coverage");
    });

    it("should show usage for invalid commands", () => {
      const result = execSync(`lua ${TDD_VALIDATOR_PATH} invalid`, { encoding: "utf8" });
      expect(result).toContain("Usage:");
    });

    it("should exit with code 0 for successful validation", () => {
      const sourceFile = join(TEST_DIR, "processes", "test.lua");
      const testFile = join(TEST_DIR, "testing", "unit", "test.test.lua");

      mkdirSync(join(TEST_DIR, "processes"), { recursive: true });
      mkdirSync(join(TEST_DIR, "testing", "unit"), { recursive: true });

      writeFileSync(sourceFile, "function test() end");
      writeFileSync(testFile, 'describe("test", function() end)');

      expect(() => {
        execSync(`cd ${TEST_DIR} && lua ${TDD_VALIDATOR_PATH} validate processes/test.lua`);
      }).not.toThrow();
    });

    it("should exit with code 1 for failed validation", () => {
      const sourceFile = join(TEST_DIR, "processes", "test.lua");

      mkdirSync(join(TEST_DIR, "processes"), { recursive: true });
      writeFileSync(sourceFile, "function test() end");

      expect(() => {
        execSync(`cd ${TEST_DIR} && lua ${TDD_VALIDATOR_PATH} validate processes/test.lua`);
      }).toThrow();
    });
  });

  describe("Edge cases and error handling", () => {
    it("should handle non-existent source files gracefully", () => {
      expect(() => {
        execSync(`lua ${TDD_VALIDATOR_PATH} extract non-existent.lua`);
      }).not.toThrow();
    });

    it("should handle files with complex function patterns", () => {
      const sourceFile = join(TEST_DIR, "complex.lua");
      writeFileSync(
        sourceFile,
        `
        -- Complex function patterns
        function Space.calculateTrajectory(start, end, speed)
          return trajectory
        end
        
        local function _privateHelper( param1, param2 )
          return param1 + param2
        end
        
        GameObject:update = function(dt)
          self.time = self.time + dt
        end
        
        Handlers.add("complex-handler",
          function(msg)
            return msg.Action == "ComplexAction" and msg.Valid == true
          end,
          function(msg)
            -- handler logic
          end
        )
      `,
      );

      const result = execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`, { encoding: "utf8" });
      expect(result).toContain("Space.calculateTrajectory (method)");
      expect(result).toContain("_privateHelper (local_function)");
      expect(result).toContain("GameObject:update (method)");
      expect(result).toContain("Handler:complex-handler (handler)");
    });

    it("should handle empty files", () => {
      const sourceFile = join(TEST_DIR, "empty.lua");
      writeFileSync(sourceFile, "");

      expect(() => {
        execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`);
      }).not.toThrow();
    });

    it("should handle files with syntax errors gracefully", () => {
      const sourceFile = join(TEST_DIR, "broken.lua");
      writeFileSync(
        sourceFile,
        `
        function incomplete(
        -- Missing closing parenthesis and end
      `,
      );

      expect(() => {
        execSync(`lua ${TDD_VALIDATOR_PATH} extract ${sourceFile}`);
      }).not.toThrow();
    });
  });
});
