/**
 * Test Suite for Lua Coverage Collector
 * Tests the custom coverage instrumentation system to ensure accurate measurement
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "fs";
import { join } from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const TEST_DIR = join(process.cwd(), "test-temp-coverage");
const _COVERAGE_COLLECTOR_PATH = join(process.cwd(), "scripts/coverage/lua-coverage-collector.lua");

describe("Lua Coverage Collector", () => {
  beforeEach(() => {
    // Create temporary test directory
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
    mkdirSync(TEST_DIR, { recursive: true });
    mkdirSync(join(TEST_DIR, "testing", "coverage"), { recursive: true });
  });

  afterEach(() => {
    // Clean up temporary files
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
  });

  describe("Initialization and Configuration", () => {
    it("should initialize with default configuration", () => {
      const testScript = join(TEST_DIR, "test_init.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        print("Initialized:", CoverageCollector.config.enabled)
        print("Output file:", CoverageCollector.config.outputFile)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Initialized: true");
      expect(result).toContain("Output file: testing/coverage/coverage-report.json");
    });

    it("should initialize with custom configuration", () => {
      const testScript = join(TEST_DIR, "test_custom_init.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init({
          enabled = false,
          outputFile = "custom-coverage.json",
          verbose = true
        })
        print("Enabled:", CoverageCollector.config.enabled)
        print("Output file:", CoverageCollector.config.outputFile)
        print("Verbose:", CoverageCollector.config.verbose)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Enabled: false");
      expect(result).toContain("Output file: custom-coverage.json");
      expect(result).toContain("Verbose: true");
    });

    it("should set start time on initialization", () => {
      const testScript = join(TEST_DIR, "test_time.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        local hasStartTime = CoverageCollector.data.startTime ~= nil
        print("Has start time:", hasStartTime)
        print("Start time type:", type(CoverageCollector.data.startTime))
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Has start time: true");
      expect(result).toContain("Start time type: number");
    });
  });

  describe("File Exclusion Logic", () => {
    it("should exclude test files from coverage", () => {
      const testScript = join(TEST_DIR, "test_exclusion.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        print("test.test.lua:", CoverageCollector.shouldExclude("test.test.lua"))
        print("module.spec.lua:", CoverageCollector.shouldExclude("module.spec.lua"))
        print("helper_test.lua:", CoverageCollector.shouldExclude("helper_test.lua"))
        print("testing/unit/test.lua:", CoverageCollector.shouldExclude("testing/unit/test.lua"))
        print("regular.lua:", CoverageCollector.shouldExclude("regular.lua"))
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("test.test.lua: true");
      expect(result).toContain("module.spec.lua: true");
      expect(result).toContain("helper_test.lua: true");
      expect(result).toContain("testing/unit/test.lua: true");
      expect(result).toContain("regular.lua: false");
    });

    it("should exclude coverage collector itself", () => {
      const testScript = join(TEST_DIR, "test_self_exclusion.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        print("Self exclusion:", CoverageCollector.shouldExclude("scripts/coverage/lua-coverage-collector.lua"))
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Self exclusion: true");
    });
  });

  describe("Line Coverage Tracking", () => {
    it("should track line execution correctly", () => {
      const testScript = join(TEST_DIR, "test_lines.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Simulate line coverage tracking
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackLine("test.lua", 3)
        CoverageCollector.trackLine("test.lua", 5)
        CoverageCollector.trackLine("test.lua", 3)  -- Track line 3 again
        
        local coverage = CoverageCollector.getLineCoverage("test.lua")
        print("Covered lines:", table.concat(coverage.covered, ","))
        print("Hit counts:", coverage.hitCounts[3])  -- Should be 2
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Covered lines: 1,3,5");
      expect(result).toContain("Hit counts: 2");
    });

    it("should handle multiple files", () => {
      const testScript = join(TEST_DIR, "test_multiple_files.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        CoverageCollector.trackLine("file1.lua", 1)
        CoverageCollector.trackLine("file1.lua", 2)
        CoverageCollector.trackLine("file2.lua", 10)
        CoverageCollector.trackLine("file2.lua", 20)
        
        local files = CoverageCollector.getTrackedFiles()
        table.sort(files)
        print("Tracked files:", table.concat(files, ","))
        
        local file1Coverage = CoverageCollector.getLineCoverage("file1.lua")
        local file2Coverage = CoverageCollector.getLineCoverage("file2.lua")
        print("File1 lines:", table.concat(file1Coverage.covered, ","))
        print("File2 lines:", table.concat(file2Coverage.covered, ","))
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Tracked files: file1.lua,file2.lua");
      expect(result).toContain("File1 lines: 1,2");
      expect(result).toContain("File2 lines: 10,20");
    });
  });

  describe("Function Coverage Tracking", () => {
    it("should track function calls", () => {
      const testScript = join(TEST_DIR, "test_functions.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        CoverageCollector.trackFunction("test.lua", "calculateDamage")
        CoverageCollector.trackFunction("test.lua", "validateMove")
        CoverageCollector.trackFunction("test.lua", "calculateDamage")  -- Call again
        
        local functions = CoverageCollector.getFunctionCoverage("test.lua")
        local funcNames = {}
        for name, _ in pairs(functions.called) do
          table.insert(funcNames, name)
        end
        table.sort(funcNames)
        print("Called functions:", table.concat(funcNames, ","))
        print("calculateDamage calls:", functions.callCounts["calculateDamage"])
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Called functions: calculateDamage,validateMove");
      expect(result).toContain("calculateDamage calls: 2");
    });

    it("should differentiate functions across files", () => {
      const testScript = join(TEST_DIR, "test_function_files.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        CoverageCollector.trackFunction("battle.lua", "calculateDamage")
        CoverageCollector.trackFunction("stats.lua", "calculateDamage")
        CoverageCollector.trackFunction("battle.lua", "processMove")
        
        local battleFunctions = CoverageCollector.getFunctionCoverage("battle.lua")
        local statsFunctions = CoverageCollector.getFunctionCoverage("stats.lua")
        
        local battleNames = {}
        for name, _ in pairs(battleFunctions.called) do
          table.insert(battleNames, name)
        end
        table.sort(battleNames)
        
        local statsNames = {}
        for name, _ in pairs(statsFunctions.called) do
          table.insert(statsNames, name)
        end
        
        print("Battle functions:", table.concat(battleNames, ","))
        print("Stats functions:", table.concat(statsNames, ","))
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Battle functions: calculateDamage,processMove");
      expect(result).toContain("Stats functions: calculateDamage");
    });
  });

  describe("Report Generation", () => {
    it("should generate comprehensive coverage report", () => {
      const testScript = join(TEST_DIR, "test_report.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        local json = require("json") or { encode = function(t) return "JSON_PLACEHOLDER" end }
        
        CoverageCollector.init({ outputFile = "test-coverage.json" })
        
        -- Track some coverage
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackLine("test.lua", 2)
        CoverageCollector.trackLine("test.lua", 4)
        CoverageCollector.trackFunction("test.lua", "testFunc")
        
        -- Add source info
        CoverageCollector.addSourceInfo("test.lua", { totalLines = 5, functions = {"testFunc", "untested"} })
        
        local report = CoverageCollector.generateReport()
        
        print("Report timestamp:", report.timestamp ~= nil)
        print("Total files:", report.summary.totalFiles)
        print("Test.lua percentage:", report.files["test.lua"].lines.percentage)
        print("Function coverage:", report.files["test.lua"].functions.percentage)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Report timestamp: true");
      expect(result).toContain("Total files: 1");
      expect(result).toContain("Test.lua percentage: 60"); // 3/5 lines
      expect(result).toContain("Function coverage: 50"); // 1/2 functions
    });

    it("should save report to file", () => {
      const testScript = join(TEST_DIR, "test_save_report.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init({ outputFile = "testing/coverage/saved-report.json" })
        
        CoverageCollector.trackLine("sample.lua", 1)
        CoverageCollector.addSourceInfo("sample.lua", { totalLines = 2 })
        
        local success = CoverageCollector.saveReport()
        print("Report saved:", success)
        
        -- Check if file exists
        local file = io.open("testing/coverage/saved-report.json", "r")
        local exists = file ~= nil
        if file then file:close() end
        print("File exists:", exists)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Report saved: true");
      expect(result).toContain("File exists: true");
    });
  });

  describe("Performance and Memory Management", () => {
    it("should handle large numbers of line hits efficiently", () => {
      const testScript = join(TEST_DIR, "test_performance.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        local startTime = os.clock()
        
        -- Track 1000 line hits
        for i = 1, 1000 do
          CoverageCollector.trackLine("perf-test.lua", i % 50 + 1)
        end
        
        local endTime = os.clock()
        local duration = endTime - startTime
        
        print("Duration under 100ms:", duration < 0.1)
        
        local coverage = CoverageCollector.getLineCoverage("perf-test.lua")
        print("Unique lines covered:", #coverage.covered)
        print("Total hit count:", coverage.hitCounts[1] >= 20)  -- Should be 20 hits for line 1
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Duration under 100ms: true");
      expect(result).toContain("Unique lines covered: 50");
      expect(result).toContain("Total hit count: true");
    });

    it("should reset coverage data cleanly", () => {
      const testScript = join(TEST_DIR, "test_reset.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Add some coverage
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackFunction("test.lua", "func")
        
        local beforeFiles = #CoverageCollector.getTrackedFiles()
        print("Files before reset:", beforeFiles)
        
        CoverageCollector.reset()
        
        local afterFiles = #CoverageCollector.getTrackedFiles()
        print("Files after reset:", afterFiles)
        print("Start time cleared:", CoverageCollector.data.startTime == nil)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Files before reset: 1");
      expect(result).toContain("Files after reset: 0");
      expect(result).toContain("Start time cleared: true");
    });
  });

  describe("Error Handling and Edge Cases", () => {
    it("should handle disabled coverage gracefully", () => {
      const testScript = join(TEST_DIR, "test_disabled.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init({ enabled = false })
        
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackFunction("test.lua", "func")
        
        local files = CoverageCollector.getTrackedFiles()
        print("Files tracked when disabled:", #files)
        
        local report = CoverageCollector.generateReport()
        print("Report generated:", report ~= nil)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Files tracked when disabled: 0");
      expect(result).toContain("Report generated: true");
    });

    it("should handle invalid file operations gracefully", () => {
      const testScript = join(TEST_DIR, "test_file_errors.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init({ outputFile = "/invalid/path/report.json" })
        
        CoverageCollector.trackLine("test.lua", 1)
        
        local success = CoverageCollector.saveReport()
        print("Save to invalid path:", success)  -- Should be false
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Save to invalid path: false");
    });

    it("should handle empty coverage data", () => {
      const testScript = join(TEST_DIR, "test_empty.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        local report = CoverageCollector.generateReport()
        print("Empty report files:", report.summary.totalFiles)
        print("Empty report coverage:", report.summary.linesCovered)
        print("Report has timestamp:", report.timestamp ~= nil)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("Empty report files: 0");
      expect(result).toContain("Empty report coverage: 0");
      expect(result).toContain("Report has timestamp: true");
    });
  });

  describe("Integration with Test Frameworks", () => {
    it("should work with mock AO environment", () => {
      const testScript = join(TEST_DIR, "test_ao_integration.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        
        -- Mock AO environment
        local ao = { id = "test_process" }
        local Handlers = {
          add = function(name, matcher, handler)
            print("Handler registered:", name)
          end
        }
        
        local CoverageCollector = require("lua-coverage-collector")
        CoverageCollector.init()
        
        -- Simulate AO process execution with coverage
        CoverageCollector.trackLine("process.lua", 1)
        CoverageCollector.trackFunction("process.lua", "handleMessage")
        
        local coverage = CoverageCollector.getLineCoverage("process.lua")
        print("AO process coverage:", #coverage.covered > 0)
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });
      expect(result).toContain("AO process coverage: true");
    });
  });
});
