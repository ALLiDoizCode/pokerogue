/**
 * Coverage Collector Accuracy Validation Test
 * Validates that the coverage collector produces accurate coverage reports
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "fs";
import { join } from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const TEST_DIR = join(process.cwd(), "test-temp-coverage-validation");
const COVERAGE_COLLECTOR_PATH = join(process.cwd(), "scripts/coverage/lua-coverage-collector.lua");

describe("Coverage Collector Accuracy Validation", () => {
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

  describe("Line Coverage Accuracy", () => {
    it("should accurately track line execution with known scenario", () => {
      const testScript = join(TEST_DIR, "line_coverage_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Test scenario: 5 lines, execute lines 1, 3, 5 (60% coverage expected)
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackLine("test.lua", 3)
        CoverageCollector.trackLine("test.lua", 5)
        
        -- Add source info
        CoverageCollector.addSourceInfo("test.lua", { totalLines = 5 })
        
        local report = CoverageCollector.generateReport()
        local fileReport = report.files["test.lua"]
        
        print("Lines covered:", #fileReport.lines.covered)
        print("Total lines:", fileReport.lines.total)
        print("Coverage percentage:", fileReport.lines.percentage)
        
        -- Validate accuracy
        assert(#fileReport.lines.covered == 3, "Should have 3 covered lines")
        assert(fileReport.lines.total == 5, "Should have 5 total lines")
        assert(fileReport.lines.percentage == 60, "Should have 60% coverage")
        
        print("✓ Line coverage accuracy validated")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("Lines covered: 3");
      expect(result).toContain("Total lines: 5");
      expect(result).toContain("Coverage percentage: 60");
      expect(result).toContain("✓ Line coverage accuracy validated");
    });

    it("should handle duplicate line hits correctly", () => {
      const testScript = join(TEST_DIR, "duplicate_hits_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Track same line multiple times
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackLine("test.lua", 1)
        CoverageCollector.trackLine("test.lua", 2)
        
        CoverageCollector.addSourceInfo("test.lua", { totalLines = 3 })
        
        local report = CoverageCollector.generateReport()
        local fileReport = report.files["test.lua"]
        
        print("Unique lines covered:", #fileReport.lines.covered)
        print("Coverage percentage:", fileReport.lines.percentage)
        
        -- Should count unique lines only
        assert(#fileReport.lines.covered == 2, "Should have 2 unique covered lines")
        assert(fileReport.lines.percentage == math.floor((2/3)*100), "Should have ~67% coverage")
        
        print("✓ Duplicate hits handled correctly")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("Unique lines covered: 2");
      expect(result).toContain("✓ Duplicate hits handled correctly");
    });

    it("should calculate hit counts accurately", () => {
      const testScript = join(TEST_DIR, "hit_counts_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Track specific hit patterns
        for i = 1, 5 do
          CoverageCollector.trackLine("test.lua", 1)  -- Line 1: 5 hits
        end
        
        for i = 1, 3 do
          CoverageCollector.trackLine("test.lua", 2)  -- Line 2: 3 hits
        end
        
        CoverageCollector.trackLine("test.lua", 3)    -- Line 3: 1 hit
        
        local coverage = CoverageCollector.getLineCoverage("test.lua")
        
        print("Line 1 hits:", coverage.hitCounts[1])
        print("Line 2 hits:", coverage.hitCounts[2])
        print("Line 3 hits:", coverage.hitCounts[3])
        
        assert(coverage.hitCounts[1] == 5, "Line 1 should have 5 hits")
        assert(coverage.hitCounts[2] == 3, "Line 2 should have 3 hits")
        assert(coverage.hitCounts[3] == 1, "Line 3 should have 1 hit")
        
        print("✓ Hit counts accurate")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("Line 1 hits: 5");
      expect(result).toContain("Line 2 hits: 3");
      expect(result).toContain("Line 3 hits: 1");
      expect(result).toContain("✓ Hit counts accurate");
    });
  });

  describe("Function Coverage Accuracy", () => {
    it("should accurately track function calls", () => {
      const testScript = join(TEST_DIR, "function_coverage_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Track function calls
        CoverageCollector.trackFunction("test.lua", "function1")
        CoverageCollector.trackFunction("test.lua", "function2")
        CoverageCollector.trackFunction("test.lua", "function1")  -- Called again
        
        -- Add source info
        CoverageCollector.addSourceInfo("test.lua", { 
          functions = {"function1", "function2", "function3"} 
        })
        
        local report = CoverageCollector.generateReport()
        local fileReport = report.files["test.lua"]
        
        print("Functions covered:", fileReport.functions.covered)
        print("Total functions:", fileReport.functions.total)
        print("Function percentage:", fileReport.functions.percentage)
        
        assert(fileReport.functions.covered == 2, "Should have 2 covered functions")
        assert(fileReport.functions.total == 3, "Should have 3 total functions")
        assert(fileReport.functions.percentage == math.floor((2/3)*100), "Should have ~67% function coverage")
        
        print("✓ Function coverage accuracy validated")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("Functions covered: 2");
      expect(result).toContain("Total functions: 3");
      expect(result).toContain("✓ Function coverage accuracy validated");
    });

    it("should track function call counts correctly", () => {
      const testScript = join(TEST_DIR, "function_call_counts_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Call functions with different frequencies
        for i = 1, 10 do
          CoverageCollector.trackFunction("test.lua", "hotFunction")
        end
        
        for i = 1, 2 do
          CoverageCollector.trackFunction("test.lua", "coldFunction")
        end
        
        local coverage = CoverageCollector.getFunctionCoverage("test.lua")
        
        print("Hot function calls:", coverage.callCounts["hotFunction"])
        print("Cold function calls:", coverage.callCounts["coldFunction"])
        
        assert(coverage.callCounts["hotFunction"] == 10, "Hot function should have 10 calls")
        assert(coverage.callCounts["coldFunction"] == 2, "Cold function should have 2 calls")
        
        print("✓ Function call counts accurate")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("Hot function calls: 10");
      expect(result).toContain("Cold function calls: 2");
      expect(result).toContain("✓ Function call counts accurate");
    });
  });

  describe("Multi-File Coverage Accuracy", () => {
    it("should handle multiple files independently", () => {
      const testScript = join(TEST_DIR, "multi_file_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- File 1: 50% line coverage
        CoverageCollector.trackLine("file1.lua", 1)
        CoverageCollector.trackLine("file1.lua", 2)
        CoverageCollector.addSourceInfo("file1.lua", { totalLines = 4 })
        
        -- File 2: 75% line coverage  
        CoverageCollector.trackLine("file2.lua", 1)
        CoverageCollector.trackLine("file2.lua", 2)
        CoverageCollector.trackLine("file2.lua", 3)
        CoverageCollector.addSourceInfo("file2.lua", { totalLines = 4 })
        
        local report = CoverageCollector.generateReport()
        
        print("File1 coverage:", report.files["file1.lua"].lines.percentage)
        print("File2 coverage:", report.files["file2.lua"].lines.percentage)
        print("Overall coverage:", report.summary.linesPercentage)
        
        assert(report.files["file1.lua"].lines.percentage == 50, "File1 should have 50% coverage")
        assert(report.files["file2.lua"].lines.percentage == 75, "File2 should have 75% coverage")
        
        -- Overall should be (2+3)/(4+4) = 62.5% ≈ 62%
        local expectedOverall = math.floor((5/8)*100)
        assert(report.summary.linesPercentage == expectedOverall, "Overall coverage should be " .. expectedOverall .. "%")
        
        print("✓ Multi-file coverage accurate")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("File1 coverage: 50");
      expect(result).toContain("File2 coverage: 75");
      expect(result).toContain("✓ Multi-file coverage accurate");
    });
  });

  describe("Report Generation Accuracy", () => {
    it("should generate accurate summary statistics", () => {
      const testScript = join(TEST_DIR, "summary_accuracy_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Create known coverage scenario
        -- File 1: 2/4 lines, 1/2 functions
        CoverageCollector.trackLine("file1.lua", 1)
        CoverageCollector.trackLine("file1.lua", 3)
        CoverageCollector.trackFunction("file1.lua", "func1")
        CoverageCollector.addSourceInfo("file1.lua", { 
          totalLines = 4, 
          functions = {"func1", "func2"} 
        })
        
        -- File 2: 3/3 lines, 2/2 functions
        CoverageCollector.trackLine("file2.lua", 1)
        CoverageCollector.trackLine("file2.lua", 2)
        CoverageCollector.trackLine("file2.lua", 3)
        CoverageCollector.trackFunction("file2.lua", "func3")
        CoverageCollector.trackFunction("file2.lua", "func4")
        CoverageCollector.addSourceInfo("file2.lua", { 
          totalLines = 3, 
          functions = {"func3", "func4"} 
        })
        
        local report = CoverageCollector.generateReport()
        local summary = report.summary
        
        print("Total files:", summary.totalFiles)
        print("Lines covered:", summary.linesCovered)
        print("Lines total:", summary.linesTotal)
        print("Functions covered:", summary.functionsCovered)
        print("Functions total:", summary.functionsTotal)
        
        assert(summary.totalFiles == 2, "Should have 2 files")
        assert(summary.linesCovered == 5, "Should have 5 covered lines (2+3)")
        assert(summary.linesTotal == 7, "Should have 7 total lines (4+3)")
        assert(summary.functionsCovered == 3, "Should have 3 covered functions (1+2)")
        assert(summary.functionsTotal == 4, "Should have 4 total functions (2+2)")
        
        -- Check percentages
        local expectedLinePercentage = math.floor((5/7)*100)  -- ~71%
        local expectedFunctionPercentage = math.floor((3/4)*100)  -- 75%
        
        assert(summary.linesPercentage == expectedLinePercentage, "Line percentage should be " .. expectedLinePercentage)
        assert(summary.functionsPercentage == expectedFunctionPercentage, "Function percentage should be " .. expectedFunctionPercentage)
        
        print("✓ Summary statistics accurate")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("Total files: 2");
      expect(result).toContain("Lines covered: 5");
      expect(result).toContain("Lines total: 7");
      expect(result).toContain("Functions covered: 3");
      expect(result).toContain("Functions total: 4");
      expect(result).toContain("✓ Summary statistics accurate");
    });

    it("should handle edge cases correctly", () => {
      const testScript = join(TEST_DIR, "edge_cases_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        CoverageCollector.init()
        
        -- Test edge cases
        
        -- 1. File with no coverage
        CoverageCollector.addSourceInfo("empty.lua", { totalLines = 5, functions = {"uncalled"} })
        
        -- 2. File with 100% coverage
        CoverageCollector.trackLine("full.lua", 1)
        CoverageCollector.trackLine("full.lua", 2)
        CoverageCollector.trackFunction("full.lua", "called")
        CoverageCollector.addSourceInfo("full.lua", { totalLines = 2, functions = {"called"} })
        
        -- 3. File with no functions
        CoverageCollector.trackLine("noFunc.lua", 1)
        CoverageCollector.addSourceInfo("noFunc.lua", { totalLines = 1, functions = {} })
        
        local report = CoverageCollector.generateReport()
        
        -- Validate edge cases
        assert(report.files["empty.lua"].lines.percentage == 0, "Empty file should have 0% line coverage")
        assert(report.files["empty.lua"].functions.percentage == 0, "Empty file should have 0% function coverage")
        
        assert(report.files["full.lua"].lines.percentage == 100, "Full file should have 100% line coverage")
        assert(report.files["full.lua"].functions.percentage == 100, "Full file should have 100% function coverage")
        
        assert(report.files["noFunc.lua"].lines.percentage == 100, "No-func file should have 100% line coverage")
        assert(report.files["noFunc.lua"].functions.total == 0, "No-func file should have 0 total functions")
        
        print("✓ Edge cases handled correctly")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("✓ Edge cases handled correctly");
    });
  });

  describe("Performance and Consistency", () => {
    it("should produce consistent results across multiple runs", () => {
      const testScript = join(TEST_DIR, "consistency_test.lua");
      writeFileSync(
        testScript,
        `
        package.path = package.path .. ";${process.cwd()}/scripts/coverage/?.lua"
        local CoverageCollector = require("lua-coverage-collector")
        
        local function runCoverageTest()
          CoverageCollector.init()
          
          -- Consistent test scenario
          CoverageCollector.trackLine("test.lua", 1)
          CoverageCollector.trackLine("test.lua", 3)
          CoverageCollector.trackLine("test.lua", 5)
          CoverageCollector.trackFunction("test.lua", "func1")
          CoverageCollector.addSourceInfo("test.lua", { 
            totalLines = 10, 
            functions = {"func1", "func2", "func3"} 
          })
          
          local report = CoverageCollector.generateReport()
          CoverageCollector.reset()
          return report
        end
        
        -- Run multiple times
        local results = {}
        for i = 1, 3 do
          results[i] = runCoverageTest()
        end
        
        -- Check consistency
        local firstLinePercentage = results[1].files["test.lua"].lines.percentage
        local firstFunctionPercentage = results[1].files["test.lua"].functions.percentage
        
        for i = 2, 3 do
          assert(results[i].files["test.lua"].lines.percentage == firstLinePercentage, 
                 "Line percentage should be consistent across runs")
          assert(results[i].files["test.lua"].functions.percentage == firstFunctionPercentage, 
                 "Function percentage should be consistent across runs")
        end
        
        print("Line percentage:", firstLinePercentage)
        print("Function percentage:", firstFunctionPercentage)
        print("✓ Results consistent across multiple runs")
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${testScript}`, { encoding: "utf8" });

      expect(result).toContain("✓ Results consistent across multiple runs");
    });
  });
});
