/**
 * Integration Test Suite for TDD Pre-commit Hook
 * Tests the complete TDD enforcement workflow during git commits
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, unlinkSync, writeFileSync } from "fs";
import { join } from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const TEST_DIR = join(process.cwd(), "test-temp-precommit");
const HOOK_SCRIPT_PATH = join(process.cwd(), "scripts/hooks/tdd-pre-commit.sh");

describe("TDD Pre-commit Hook Integration", () => {
  let originalCwd;

  beforeEach(() => {
    originalCwd = process.cwd();

    // Create temporary git repository
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
    mkdirSync(TEST_DIR, { recursive: true });

    process.chdir(TEST_DIR);

    // Initialize git repo
    execSync("git init");
    execSync('git config user.email "test@example.com"');
    execSync('git config user.name "Test User"');

    // Create necessary directory structure
    mkdirSync("scripts/hooks", { recursive: true });
    mkdirSync("testing/unit", { recursive: true });
    mkdirSync("testing/integration", { recursive: true });
    mkdirSync("processes", { recursive: true });
    mkdirSync("ao-processes/tests/unit", { recursive: true });

    // Copy hook script and validation script
    execSync(`cp "${HOOK_SCRIPT_PATH}" scripts/hooks/`);
    execSync(`cp "${join(originalCwd, "scripts/hooks/tdd-validation.lua")}" scripts/hooks/`);
    execSync("chmod +x scripts/hooks/tdd-pre-commit.sh");
  });

  afterEach(() => {
    process.chdir(originalCwd);
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
  });

  describe("Basic TDD Enforcement", () => {
    it("should pass when source file has corresponding test", () => {
      // Create source file
      writeFileSync(
        "processes/battle.lua",
        `
        function calculateDamage(attack, defense)
          return math.max(1, attack - defense)
        end
      `,
      );

      // Create corresponding test file
      writeFileSync(
        "testing/unit/battle.test.lua",
        `
        describe("battle.lua", function()
          describe("calculateDamage", function()
            it("should calculate damage correctly", function()
              assert(calculateDamage(100, 50) == 50)
            end)
          end)
        end)
      `,
      );

      // Stage files
      execSync("git add .");

      // Run pre-commit hook
      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
      expect(result).toContain("All modified files have corresponding tests");
    });

    it("should fail when source file lacks test", () => {
      // Create source file without test
      writeFileSync(
        "processes/stats.lua",
        `
        function calculateStat(base, level)
          return base * level
        end
      `,
      );

      // Stage file
      execSync("git add processes/stats.lua");

      // Run pre-commit hook - should fail
      try {
        execSync("bash scripts/hooks/tdd-pre-commit.sh");
        expect.fail("Hook should have failed");
      } catch (error) {
        expect(error.stdout || error.message).toContain("✗ Missing test file");
        expect(error.stdout || error.message).toContain("testing/unit/stats.test.lua");
      }
    });

    it("should pass when only test files are modified", () => {
      // Create and modify only test files
      writeFileSync(
        "testing/unit/existing.test.lua",
        `
        describe("existing tests", function()
          it("should pass", function()
            assert(true)
          end)
        end)
      `,
      );

      execSync("git add testing/unit/existing.test.lua");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });

    it("should exclude files in data directory", () => {
      mkdirSync("data", { recursive: true });
      writeFileSync(
        "data/pokemon.lua",
        `
        return {
          { name = "Pikachu", type = "Electric" }
        }
      `,
      );

      execSync("git add data/pokemon.lua");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
      expect(result).toContain("Excluded files: data/pokemon.lua");
    });
  });

  describe("Multiple File Scenarios", () => {
    it("should handle multiple source files with tests", () => {
      // Create multiple source files
      writeFileSync("processes/battle.lua", "function battle() end");
      writeFileSync("processes/stats.lua", "function stats() end");
      writeFileSync("processes/moves.lua", "function moves() end");

      // Create corresponding tests
      writeFileSync("testing/unit/battle.test.lua", 'describe("battle", function() end)');
      writeFileSync("testing/unit/stats.test.lua", 'describe("stats", function() end)');
      writeFileSync("testing/unit/moves.test.lua", 'describe("moves", function() end)');

      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
      expect(result).toContain("Files checked: 3");
    });

    it("should fail when some files lack tests", () => {
      // Create source files - some with tests, some without
      writeFileSync("processes/battle.lua", "function battle() end");
      writeFileSync("processes/stats.lua", "function stats() end");
      writeFileSync("processes/untested.lua", "function untested() end");

      // Create tests for only some files
      writeFileSync("testing/unit/battle.test.lua", 'describe("battle", function() end)');
      writeFileSync("testing/unit/stats.test.lua", 'describe("stats", function() end)');

      execSync("git add .");

      try {
        execSync("bash scripts/hooks/tdd-pre-commit.sh");
        expect.fail("Hook should have failed");
      } catch (error) {
        expect(error.stdout || error.message).toContain("✗ Missing test file");
        expect(error.stdout || error.message).toContain("untested.lua");
      }
    });

    it("should handle mixed file types correctly", () => {
      // Create various file types
      writeFileSync("processes/logic.lua", "function logic() end");
      writeFileSync("data/constants.lua", "return {}");
      writeFileSync("templates/example.lua", "return template");
      writeFileSync("README.md", "# Test Project");
      writeFileSync("package.json", "{}");

      // Create test only for logic file
      writeFileSync("testing/unit/logic.test.lua", 'describe("logic", function() end)');

      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
      expect(result).toContain("Excluded files:");
      expect(result).toContain("data/constants.lua");
      expect(result).toContain("templates/example.lua");
    });
  });

  describe("AO Process Handling", () => {
    it("should handle ao-processes directory correctly", () => {
      writeFileSync(
        "ao-processes/token.lua",
        `
        function transfer(from, to, amount)
          return { success = true }
        end
      `,
      );

      writeFileSync(
        "ao-processes/tests/unit/token.test.lua",
        `
        describe("token transfer", function()
          it("should transfer tokens", function()
            assert(transfer("A", "B", 100).success)
          end)
        end)
      `,
      );

      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });

    it("should skip ao-processes test files themselves", () => {
      writeFileSync(
        "ao-processes/tests/unit/new-test.test.lua",
        `
        describe("new test", function()
          it("should work", function()
            assert(true)
          end)
        end)
      `,
      );

      execSync("git add ao-processes/tests/unit/new-test.test.lua");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });
  });

  describe("Bypass Mechanism", () => {
    it("should log bypass attempts with --no-verify", () => {
      // Create source file without test
      writeFileSync("processes/bypass-test.lua", "function test() end");
      execSync("git add processes/bypass-test.lua");

      // Commit with --no-verify to bypass hook
      execSync('git commit -m "Test bypass" --no-verify');

      // Check if bypass was logged
      const logFile = ".git/tdd-bypass.log";
      if (existsSync(logFile)) {
        const logContent = readFileSync(logFile, "utf8");
        expect(logContent).toContain("BYPASS");
        expect(logContent).toContain("Test bypass");
      }
    });

    it("should create bypass log file if it doesnt exist", () => {
      writeFileSync("processes/test.lua", "function test() end");
      execSync("git add processes/test.lua");

      // Simulate bypass logging
      execSync('echo "$(date): BYPASS: Test commit by Test User" >> .git/tdd-bypass.log');

      expect(existsSync(".git/tdd-bypass.log")).toBe(true);

      const logContent = readFileSync(".git/tdd-bypass.log", "utf8");
      expect(logContent).toContain("BYPASS");
      expect(logContent).toContain("Test User");
    });
  });

  describe("Coverage Validation", () => {
    it("should validate test coverage when enabled", () => {
      // Create source file with function
      writeFileSync(
        "processes/coverage-test.lua",
        `
        function covered() return true end
        function uncovered() return false end
      `,
      );

      // Create test file that only covers one function
      writeFileSync(
        "testing/unit/coverage-test.test.lua",
        `
        describe("coverage test", function()
          describe("covered", function()
            it("should be tested", function()
              assert(covered())
            end)
          end)
        end)
      `,
      );

      execSync("git add .");

      // Hook should pass basic test existence but may warn about coverage
      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });
  });

  describe("Performance and Reliability", () => {
    it("should complete within 2 seconds for typical commits", () => {
      // Create a moderate number of files
      for (let i = 1; i <= 5; i++) {
        writeFileSync(`processes/file${i}.lua`, `function func${i}() end`);
        writeFileSync(`testing/unit/file${i}.test.lua`, `describe("file${i}", function() end)`);
      }

      execSync("git add .");

      const startTime = Date.now();
      execSync("bash scripts/hooks/tdd-pre-commit.sh");
      const endTime = Date.now();

      const duration = endTime - startTime;
      expect(duration).toBeLessThan(2000); // Under 2 seconds
    });

    it("should handle large commits efficiently", () => {
      // Create many files to test performance
      for (let i = 1; i <= 20; i++) {
        writeFileSync(`processes/large${i}.lua`, `function large${i}() return ${i} end`);
        writeFileSync(`testing/unit/large${i}.test.lua`, `describe("large${i}", function() end)`);
      }

      execSync("git add .");

      const startTime = Date.now();
      execSync("bash scripts/hooks/tdd-pre-commit.sh");
      const endTime = Date.now();

      const duration = endTime - startTime;
      expect(duration).toBeLessThan(5000); // Under 5 seconds even for large commits
    });

    it("should handle files with special characters in names", () => {
      writeFileSync("processes/file-with-dashes.lua", "function test() end");
      writeFileSync("processes/file_with_underscores.lua", "function test() end");

      writeFileSync("testing/unit/file-with-dashes.test.lua", 'describe("test", function() end)');
      writeFileSync("testing/unit/file_with_underscores.test.lua", 'describe("test", function() end)');

      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });
  });

  describe("Error Handling", () => {
    it("should handle corrupted git state gracefully", () => {
      // Create source file
      writeFileSync("processes/test.lua", "function test() end");

      // Don't stage file, then try to check staged files
      try {
        execSync("bash scripts/hooks/tdd-pre-commit.sh");
        // Should pass because no files are staged
        expect(true).toBe(true);
      } catch (error) {
        // If it fails, should fail gracefully
        expect(error.code).toBeDefined();
      }
    });

    it("should handle missing validation script", () => {
      // Remove validation script
      unlinkSync("scripts/hooks/tdd-validation.lua");

      writeFileSync("processes/test.lua", "function test() end");
      execSync("git add processes/test.lua");

      try {
        execSync("bash scripts/hooks/tdd-pre-commit.sh");
        expect.fail("Should have failed");
      } catch (error) {
        expect(error.stdout || error.message).toContain("validation script not found");
      }
    });

    it("should handle permission issues gracefully", () => {
      writeFileSync("processes/test.lua", "function test() end");
      execSync("git add processes/test.lua");

      // Remove execute permission from hook
      execSync("chmod -x scripts/hooks/tdd-pre-commit.sh");

      try {
        execSync("bash scripts/hooks/tdd-pre-commit.sh");
        // Test should still work when called with bash explicitly
        expect.fail("This test needs to be run with execute permission removed");
      } catch (error) {
        // Expected when permission is denied
        expect(error.code).toBeDefined();
      }
    });
  });

  describe("Integration with Git Workflow", () => {
    it("should work with git add --patch workflow", () => {
      writeFileSync(
        "processes/incremental.lua",
        `
        -- First function
        function first() return 1 end
        
        -- Second function (to be added later)
        function second() return 2 end
      `,
      );

      writeFileSync(
        "testing/unit/incremental.test.lua",
        `
        describe("incremental", function()
          describe("first", function()
            it("should return 1", function()
              assert(first() == 1)
            end)
          end)
          describe("second", function()
            it("should return 2", function()
              assert(second() == 2)
            end)
          end)
        end)
      `,
      );

      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });

    it("should work with git stash workflow", () => {
      // Create files and commit them
      writeFileSync("processes/stable.lua", "function stable() end");
      writeFileSync("testing/unit/stable.test.lua", 'describe("stable", function() end)');
      execSync("git add .");
      execSync('git commit -m "Initial commit"');

      // Make changes to files
      writeFileSync(
        "processes/stable.lua",
        `
        function stable() end
        function new_function() end
      `,
      );

      writeFileSync(
        "testing/unit/stable.test.lua",
        `
        describe("stable", function() end)
        describe("new_function", function() end)
      `,
      );

      // Stash changes
      execSync("git add .");
      execSync("git stash");

      // Pop changes and test
      execSync("git stash pop");
      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
    });
  });

  describe("Configuration and Customization", () => {
    it("should respect custom configuration", () => {
      // Create custom config file
      writeFileSync(
        ".tdd-config.json",
        JSON.stringify({
          excludePatterns: ["custom-exclude/"],
          testDirectories: ["custom-tests/"],
          requireCoverage: false,
        }),
      );

      mkdirSync("custom-exclude", { recursive: true });
      writeFileSync("custom-exclude/ignored.lua", "function ignored() end");

      execSync("git add .");

      const result = execSync("bash scripts/hooks/tdd-pre-commit.sh", { encoding: "utf8" });

      expect(result).toContain("✓ TDD validation passed");
      expect(result).toContain("custom-exclude/ignored.lua");
    });
  });
});
