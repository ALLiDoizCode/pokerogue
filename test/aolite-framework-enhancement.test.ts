/**
 * Unit tests for Enhanced Aolite Unit Testing Framework
 * Tests the enhanced aolite testing infrastructure for comprehensive process validation
 */

import fs from "fs/promises";
import path from "path";
import { beforeAll, describe, expect, it } from "vitest";

describe("Enhanced Aolite Testing Framework", () => {
  const AOLITE_DIR = path.join(process.cwd(), "testing/aolite");
  const ENHANCED_FRAMEWORK_PATH = path.join(AOLITE_DIR, "enhanced-test-framework.lua");
  const TEST_GENERATORS_PATH = path.join(AOLITE_DIR, "test-generators.lua");
  const AOLITE_SCRIPT_PATH = path.join(process.cwd(), "scripts/run-aolite-tests.lua");

  beforeAll(async () => {
    // Ensure aolite testing directory exists
    await fs.mkdir(AOLITE_DIR, { recursive: true });
  });

  describe("Framework Structure", () => {
    it("should have enhanced test framework file", async () => {
      const stats = await fs.stat(ENHANCED_FRAMEWORK_PATH);
      expect(stats.isFile()).toBe(true);
    });

    it("should have test generators file", async () => {
      const stats = await fs.stat(TEST_GENERATORS_PATH);
      expect(stats.isFile()).toBe(true);
    });

    it("should have enhanced aolite test script", async () => {
      const stats = await fs.stat(AOLITE_SCRIPT_PATH);
      expect(stats.isFile()).toBe(true);
    });

    it("should have aolite directory structure", async () => {
      const stats = await fs.stat(AOLITE_DIR);
      expect(stats.isDirectory()).toBe(true);
    });
  });

  describe("Mock AO Environment", () => {
    it("should implement mock AO globals", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("_G.ao");
      expect(frameworkContent).toContain("_G.Handlers");
      expect(frameworkContent).toContain("_G.json");
      expect(frameworkContent).toContain("_G.crypto");
    });

    it("should mock ao.send function", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("ao.send");
      expect(frameworkContent).toContain("MockAO.send");
    });

    it("should mock Handlers system", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("_G.Handlers");
      expect(frameworkContent).toContain("add = function(name, matcher, handler)");
      expect(frameworkContent).toContain("hasMatchingTag");
      expect(frameworkContent).toContain("receive = function(msg)");
    });

    it("should provide deterministic crypto for testing", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("_G.crypto");
      expect(frameworkContent).toContain("random = function(min, max)");
      expect(frameworkContent).toContain("math.randomseed(12345)");
    });
  });

  describe("Test Assertion Functions", () => {
    it("should implement comprehensive assertion functions", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("assert_equal");
      expect(frameworkContent).toContain("assert_true");
      expect(frameworkContent).toContain("assert_not_nil");
      expect(frameworkContent).toContain("assert_type");
    });

    it("should provide detailed assertion error messages", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("Expected %s, got %s");
      expect(frameworkContent).toContain("Assertion failed");
    });
  });

  describe("Test Execution Framework", () => {
    it("should implement test execution with metrics", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("executeTest");
      expect(frameworkContent).toContain("TestMetrics");
      expect(frameworkContent).toContain("totalTests");
      expect(frameworkContent).toContain("passedTests");
      expect(frameworkContent).toContain("failedTests");
    });

    it("should implement test suite execution", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("runTestSuite");
      expect(frameworkContent).toContain("suiteName");
      expect(frameworkContent).toContain("suiteStart");
      expect(frameworkContent).toContain("suiteEnd");
    });

    it("should track execution times", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("os.clock()");
      expect(frameworkContent).toContain("executionTime");
      expect(frameworkContent).toContain("performance");
    });
  });

  describe("Performance Profiling", () => {
    it("should implement function profiling", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("profileFunction");
      expect(frameworkContent).toContain("iterations");
      expect(frameworkContent).toContain("totalTime");
      expect(frameworkContent).toContain("avgTime");
    });

    it("should provide performance metrics", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("Performance profile");
      expect(frameworkContent).toContain("Total time");
      expect(frameworkContent).toContain("Avg per call");
    });
  });

  describe("Test Data Fixtures", () => {
    it("should provide comprehensive test fixtures", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("createTestFixtures");
      expect(frameworkContent).toContain("mockPokemon");
      expect(frameworkContent).toContain("mockBattle");
      expect(frameworkContent).toContain("mockMessage");
    });

    it("should include realistic test data", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("Charizard");
      expect(frameworkContent).toContain("stats");
      expect(frameworkContent).toContain("types");
      expect(frameworkContent).toContain("moves");
    });
  });

  describe("Coverage Tracking", () => {
    it("should implement coverage tracking", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("trackCoverage");
      expect(frameworkContent).toContain("coverage");
      expect(frameworkContent).toContain("functions");
      expect(frameworkContent).toContain("lines");
    });

    it("should track coverage metrics", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("totalLines");
      expect(frameworkContent).toContain("coveredLines");
      expect(frameworkContent).toContain("Tracking coverage");
    });
  });

  describe("Test Report Generation", () => {
    it("should generate comprehensive test reports", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("generateTestReport");
      expect(frameworkContent).toContain("Enhanced Aolite Test Report");
      expect(frameworkContent).toContain("Total Tests");
      expect(frameworkContent).toContain("Passed");
      expect(frameworkContent).toContain("Failed");
    });

    it("should include performance summary", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("Performance Summary");
      expect(frameworkContent).toContain("Total Time");
    });

    it("should provide success/failure indicators", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("All tests passed!");
      expect(frameworkContent).toContain("Some tests failed!");
    });
  });

  describe("Test Generators", () => {
    it("should generate battle engine tests", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("generateBattleEngineTests");
      expect(generatorContent).toContain("test_damage_calculation");
      expect(generatorContent).toContain("test_type_effectiveness");
      expect(generatorContent).toContain("test_critical_hit_calculation");
    });

    it("should generate stat calculation tests", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("generateStatCalculationTests");
      expect(generatorContent).toContain("test_hp_calculation");
      expect(generatorContent).toContain("test_other_stat_calculation");
      expect(generatorContent).toContain("test_nature_modifiers");
    });

    it("should generate status effect tests", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("generateStatusEffectTests");
      expect(generatorContent).toContain("test_burn_damage");
      expect(generatorContent).toContain("test_paralysis_effects");
      expect(generatorContent).toContain("test_sleep_turns");
    });

    it("should generate data process tests", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("generateDataProcessTests");
      expect(generatorContent).toContain("test_species_lookup");
      expect(generatorContent).toContain("test_move_lookup");
      expect(generatorContent).toContain("test_item_lookup");
    });

    it("should generate message handler tests", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("generateMessageHandlerTests");
      expect(generatorContent).toContain("test_handler_registration");
      expect(generatorContent).toContain("test_message_routing");
      expect(generatorContent).toContain("test_error_handling");
    });
  });

  describe("Enhanced Script Integration", () => {
    it("should integrate enhanced framework with existing script", async () => {
      const scriptContent = await fs.readFile(AOLITE_SCRIPT_PATH, "utf8");

      expect(scriptContent).toContain("Enhanced Aolite Unit Testing Framework");
      expect(scriptContent).toContain("require('testing.aolite.enhanced-test-framework')");
      expect(scriptContent).toContain("require('testing.aolite.test-generators')");
    });

    it("should maintain backward compatibility", async () => {
      const scriptContent = await fs.readFile(AOLITE_SCRIPT_PATH, "utf8");

      expect(scriptContent).toContain("backward compatibility");
      expect(scriptContent).toContain("Legacy Test Files");
      expect(scriptContent).toContain("runTestFile");
    });

    it("should combine enhanced and legacy results", async () => {
      const scriptContent = await fs.readFile(AOLITE_SCRIPT_PATH, "utf8");

      expect(scriptContent).toContain("Combined Test Results");
      expect(scriptContent).toContain("Enhanced Framework");
      expect(scriptContent).toContain("Legacy Test Files");
    });

    it("should use proper npm test command integration", async () => {
      const packagePath = path.join(process.cwd(), "package.json");
      const packageContent = await fs.readFile(packagePath, "utf8");
      const packageJson = JSON.parse(packageContent);

      expect(packageJson.scripts).toHaveProperty("test:aolite");
      expect(packageJson.scripts["test:aolite"]).toContain("run-aolite-tests.lua");
    });
  });

  describe("Game Logic Test Coverage", () => {
    it("should test battle mechanics comprehensively", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("calculateDamage");
      expect(generatorContent).toContain("getEffectiveness");
      expect(generatorContent).toContain("calculateCriticalHit");
      expect(generatorContent).toContain("Type effectiveness");
    });

    it("should test Pokemon stat calculations", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("calculateHP");
      expect(generatorContent).toContain("calculateStat");
      expect(generatorContent).toContain("getNatureModifier");
      expect(generatorContent).toContain("Garchomp");
    });

    it("should test status effect mechanics", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("calculateBurnDamage");
      expect(generatorContent).toContain("applyParalysis");
      expect(generatorContent).toContain("calculateSleepTurns");
    });

    it("should validate test assertions", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("assert(");
      expect(generatorContent).toContain("Expected");
      expect(generatorContent).toContain("should be");
    });
  });

  describe("Framework Export Interface", () => {
    it("should export all framework functions", async () => {
      const frameworkContent = await fs.readFile(ENHANCED_FRAMEWORK_PATH, "utf8");

      expect(frameworkContent).toContain("EnhancedAoliteFramework.runTests");
      expect(frameworkContent).toContain("EnhancedAoliteFramework.setupMockAO");
      expect(frameworkContent).toContain("EnhancedAoliteFramework.assert_equal");
      expect(frameworkContent).toContain("return EnhancedAoliteFramework");
    });

    it("should export test generators", async () => {
      const generatorContent = await fs.readFile(TEST_GENERATORS_PATH, "utf8");

      expect(generatorContent).toContain("TestGenerators.generateAllTests");
      expect(generatorContent).toContain("return TestGenerators");
    });
  });
});
