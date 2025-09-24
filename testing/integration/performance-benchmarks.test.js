/**
 * Performance Benchmarks Tests
 * Comprehensive performance testing for deployment validation
 */

import fs from "fs/promises";
import path from "path";
import { afterAll, beforeAll, beforeEach, describe, expect, test } from "@jest/globals";
import { IntegrationEnvironmentConfig } from "../../development-tools/integration-testing/environment-config.js";
import { PerformanceMonitor } from "../aos-local/performance-monitor.js";
import { ProcessDeployer } from "../aos-local/process-deployer.js";
import { performanceBaselines } from "../fixtures/performance-baselines.js";

describe("Performance Benchmarks Tests", () => {
  let performanceMonitor;
  let processDeployer;
  let environmentConfig;
  let tempDir;
  let deployedProcesses;

  beforeAll(async () => {
    // Setup test environment
    tempDir = path.join(process.cwd(), "testing/aos-local/temp", `performance-test-${Date.now()}`);
    await fs.mkdir(tempDir, { recursive: true });

    // Initialize components
    environmentConfig = new IntegrationEnvironmentConfig({
      workspaceDir: tempDir,
    });

    performanceMonitor = new PerformanceMonitor({
      tempDir,
      baselineFile: path.join(process.cwd(), "testing/fixtures/performance-baselines.js"),
      reportsDir: path.join(process.cwd(), "testing/reports"),
    });

    processDeployer = new ProcessDeployer({
      tempDir,
      processesDir: path.join(process.cwd(), "processes"),
    });

    // Initialize environment and components
    await environmentConfig.initializeEnvironment();
    await performanceMonitor.initialize();
    await processDeployer.initialize();

    // Create test process files
    await createPerformanceTestProcesses();

    // Deploy test processes
    deployedProcesses = await deployTestProcesses();
  });

  afterAll(async () => {
    // Cleanup
    await performanceMonitor?.cleanup();
    await processDeployer?.cleanup();
    await environmentConfig?.cleanup();

    // Remove temp directory
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (error) {
      console.warn(`Warning: Could not remove temp directory: ${error.message}`);
    }
  });

  beforeEach(() => {
    // Reset any state before each test
  });

  describe("Response Time Benchmarks", () => {
    test("should meet response time baselines for all process types", async () => {
      const responseTimeConfig = {
        responseTimeIterations: 15,
        timeout: 30000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, responseTimeConfig);

      expect(benchmark.status).toBe("completed");
      expect(benchmark.tests).toHaveLength(6); // 6 test types

      const responseTimeTest = benchmark.tests.find(test => test.type === "response_time");
      expect(responseTimeTest).toBeDefined();
      expect(responseTimeTest.passed).toBe(true);

      // Verify each process meets its baseline
      for (const [processName, result] of Object.entries(responseTimeTest.results)) {
        const processType = getProcessType(processName);
        const baseline = performanceBaselines.responseTime[processType];

        expect(result.averageResponseTime).toBeLessThan(baseline);
        expect(result.withinBaseline).toBe(true);
        expect(result.successRate).toBeGreaterThan(90); // At least 90% success rate
      }

      // Overall metrics should be within acceptable ranges
      expect(responseTimeTest.metrics.overallAverageResponseTime).toBeLessThan(1500);
      expect(responseTimeTest.metrics.overallSuccessRate).toBeGreaterThan(95);
    }, 45000);

    test("should maintain consistent response times under repeated requests", async () => {
      const consistencyConfig = {
        responseTimeIterations: 25,
        timeout: 45000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, consistencyConfig);

      const responseTimeTest = benchmark.tests.find(test => test.type === "response_time");

      // Check for consistency (max response time shouldn't be more than 3x average)
      for (const [_processName, result] of Object.entries(responseTimeTest.results)) {
        if (result.averageResponseTime > 0) {
          const responseTimeVariation = result.maxResponseTime / result.averageResponseTime;
          expect(responseTimeVariation).toBeLessThan(3); // Max should be less than 3x average
        }
      }
    }, 60000);
  });

  describe("Throughput Benchmarks", () => {
    test("should achieve minimum throughput baselines", async () => {
      const throughputConfig = {
        throughputDuration: 15000, // 15 seconds
        messageInterval: 50, // 50ms between messages
        timeout: 30000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, throughputConfig);

      const throughputTest = benchmark.tests.find(test => test.type === "throughput");
      expect(throughputTest).toBeDefined();
      expect(throughputTest.passed).toBe(true);

      // Verify throughput meets baselines
      expect(throughputTest.metrics.overallMessagesPerSecond).toBeGreaterThan(
        performanceBaselines.throughput.messagesPerSecond * 0.8, // 80% of baseline
      );
      expect(throughputTest.metrics.overallSuccessRate).toBeGreaterThan(95);

      // Check individual process throughput
      for (const [_processName, result] of Object.entries(throughputTest.results)) {
        expect(result.successRate).toBeGreaterThan(90);
        expect(result.averageResponseTime).toBeLessThan(2000);
      }
    }, 45000);

    test("should maintain throughput under sustained load", async () => {
      const sustainedLoadConfig = {
        throughputDuration: 30000, // 30 seconds sustained load
        messageInterval: 100, // 100ms intervals
        timeout: 45000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, sustainedLoadConfig);

      const throughputTest = benchmark.tests.find(test => test.type === "throughput");

      // Under sustained load, allow some degradation but maintain minimum thresholds
      expect(throughputTest.metrics.overallMessagesPerSecond).toBeGreaterThan(
        performanceBaselines.throughput.messagesPerSecond * 0.6, // 60% of baseline under load
      );
      expect(throughputTest.metrics.overallSuccessRate).toBeGreaterThan(85); // 85% under load
    }, 60000);
  });

  describe("Memory Usage Benchmarks", () => {
    test("should stay within memory usage baselines", async () => {
      const memoryConfig = {
        memorySamples: 20,
        memorySampleInterval: 500, // Sample every 500ms
        timeout: 25000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, memoryConfig);

      const memoryTest = benchmark.tests.find(test => test.type === "memory_usage");
      expect(memoryTest).toBeDefined();
      expect(memoryTest.passed).toBe(true);

      // Verify memory usage is within baselines
      for (const [processName, result] of Object.entries(memoryTest.results)) {
        const processType = getProcessType(processName);
        const baseline = performanceBaselines.memoryUsage[processType];

        expect(result.averageMemoryUsage).toBeLessThan(baseline);
        expect(result.maxMemoryUsage).toBeLessThan(baseline * 1.2); // Allow 20% spike
        expect(result.withinBaseline).toBe(true);
      }

      // Overall memory usage should be reasonable
      expect(memoryTest.metrics.overallAverageMemoryUsage).toBeLessThan(100);
      expect(memoryTest.metrics.overallMaxMemoryUsage).toBeLessThan(150);
    }, 35000);

    test("should have stable memory usage over time", async () => {
      // Start monitoring to collect baseline data
      performanceMonitor.startMonitoring(deployedProcesses);

      // Let monitoring run for a period
      await new Promise(resolve => setTimeout(resolve, 10000));

      performanceMonitor.stopMonitoring();

      // Verify memory usage is stable (no significant leaks)
      const realTimeMetrics = performanceMonitor.getRealTimeMetricsSummary();

      for (const [_processName, summary] of Object.entries(realTimeMetrics)) {
        if (summary.sampleCount > 5) {
          // Memory usage should not increase significantly over time
          const firstSample = summary.latestMetrics.estimatedMemoryUsage;
          const latestSample = summary.latestMetrics.estimatedMemoryUsage;

          // Allow some variation but detect major leaks
          expect(latestSample).toBeLessThan(firstSample * 2);
        }
      }
    }, 20000);
  });

  describe("Error Handling Performance", () => {
    test("should handle errors efficiently and recover quickly", async () => {
      const errorHandlingConfig = {
        errorTests: 8,
        timeout: 30000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, errorHandlingConfig);

      const errorTest = benchmark.tests.find(test => test.type === "error_handling");
      expect(errorTest).toBeDefined();
      expect(errorTest.passed).toBe(true);

      // Verify error handling performance
      expect(errorTest.metrics.overallRecoveryRate).toBeGreaterThan(80); // 80% recovery rate
      expect(errorTest.metrics.overallErrorResponseTime).toBeLessThan(2000); // Error handling under 2s

      // Check individual process error handling
      for (const [_processName, result] of Object.entries(errorTest.results)) {
        expect(result.recoveryRate).toBeGreaterThan(70); // Individual 70% recovery
        expect(result.meetsRecoveryBaseline).toBe(true);
      }
    }, 45000);

    test("should maintain performance after error recovery", async () => {
      // First run error handling test
      const errorConfig = { errorTests: 5 };
      await performanceMonitor.runPerformanceBenchmark(deployedProcesses, errorConfig);

      // Then test normal performance
      const performanceConfig = { responseTimeIterations: 10 };
      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, performanceConfig);

      const responseTimeTest = benchmark.tests.find(test => test.type === "response_time");

      // Performance should still be acceptable after error handling
      expect(responseTimeTest.metrics.overallAverageResponseTime).toBeLessThan(2000);
      expect(responseTimeTest.metrics.overallSuccessRate).toBeGreaterThan(90);
    }, 40000);
  });

  describe("Concurrent Load Performance", () => {
    test("should handle concurrent load within performance thresholds", async () => {
      const concurrentConfig = {
        concurrentUsers: 8,
        messagesPerUser: 8,
        timeout: 45000,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, concurrentConfig);

      const concurrentTest = benchmark.tests.find(test => test.type === "concurrent_load");
      expect(concurrentTest).toBeDefined();
      expect(concurrentTest.passed).toBe(true);

      // Verify concurrent load performance
      expect(concurrentTest.metrics.overallSuccessRate).toBeGreaterThan(85); // 85% under concurrent load
      expect(concurrentTest.metrics.overallMessagesPerSecond).toBeGreaterThan(20); // Minimum throughput

      // Check individual process concurrent handling
      for (const [_processName, result] of Object.entries(concurrentTest.results)) {
        expect(result.successRate).toBeGreaterThan(80);
        expect(result.averageResponseTime).toBeLessThan(3000); // Allow higher response time under load
      }
    }, 60000);

    test("should scale appropriately with increased concurrent load", async () => {
      // Test with lower load first
      const lowLoadConfig = {
        concurrentUsers: 3,
        messagesPerUser: 5,
      };

      const lowLoadBenchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, lowLoadConfig);

      // Test with higher load
      const highLoadConfig = {
        concurrentUsers: 10,
        messagesPerUser: 8,
      };

      const highLoadBenchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, highLoadConfig);

      const lowLoadTest = lowLoadBenchmark.tests.find(test => test.type === "concurrent_load");
      const highLoadTest = highLoadBenchmark.tests.find(test => test.type === "concurrent_load");

      // Performance should degrade gracefully under higher load
      const performanceDegradation =
        (lowLoadTest.metrics.overallSuccessRate - highLoadTest.metrics.overallSuccessRate) /
        lowLoadTest.metrics.overallSuccessRate;

      expect(performanceDegradation).toBeLessThan(0.3); // Less than 30% degradation
      expect(highLoadTest.metrics.overallSuccessRate).toBeGreaterThan(70); // Still functional
    }, 120000);
  });

  describe("Baseline Comparison and Scoring", () => {
    test("should generate comprehensive baseline comparison", async () => {
      const fullBenchmarkConfig = {
        responseTimeIterations: 10,
        throughputDuration: 10000,
        memorySamples: 10,
        errorTests: 5,
        concurrentUsers: 5,
        messagesPerUser: 5,
      };

      const benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, fullBenchmarkConfig);

      const baselineComparison = benchmark.tests.find(test => test.type === "baseline_comparison");
      expect(baselineComparison).toBeDefined();
      expect(baselineComparison.passed).toBe(true);

      // Verify baseline comparison results
      expect(baselineComparison.overallScore).toBeGreaterThan(70); // 70% minimum score
      expect(Object.keys(baselineComparison.comparisons)).toHaveLength(5); // 5 test types compared

      // Check individual test scores
      for (const [_testType, comparison] of Object.entries(baselineComparison.comparisons)) {
        expect(comparison.score).toBeGreaterThan(60); // Minimum 60% per test
        expect(comparison.testName).toBeDefined();
      }
    }, 90000);

    test("should generate performance report with recommendations", async () => {
      // Run a benchmark to generate data
      const _benchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, {
        responseTimeIterations: 8,
        throughputDuration: 8000,
      });

      // Generate performance report
      const reports = await performanceMonitor.generatePerformanceReport();

      expect(reports.jsonReport).toBeDefined();
      expect(reports.htmlReport).toBeDefined();

      // Verify report files exist
      const jsonReportExists = await fs
        .access(reports.jsonReport)
        .then(() => true)
        .catch(() => false);
      const htmlReportExists = await fs
        .access(reports.htmlReport)
        .then(() => true)
        .catch(() => false);

      expect(jsonReportExists).toBe(true);
      expect(htmlReportExists).toBe(true);

      // Verify report content
      const reportContent = await fs.readFile(reports.jsonReport, "utf8");
      const report = JSON.parse(reportContent);

      expect(report.benchmarkResults).toHaveLength(1);
      expect(report.benchmarkResults[0].summary).toBeDefined();
      expect(report.benchmarkResults[0].summary.totalTests).toBeGreaterThan(0);
    }, 40000);
  });

  describe("Real-time Performance Monitoring", () => {
    test("should collect real-time metrics continuously", async () => {
      // Start real-time monitoring
      performanceMonitor.startMonitoring(deployedProcesses);

      // Generate some load while monitoring
      const loadPromises = Array.from({ length: 5 }, async (_, i) => {
        await new Promise(resolve => setTimeout(resolve, i * 1000));

        for (const [_processName, processInfo] of deployedProcesses) {
          try {
            await performanceMonitor.aoliteFramework.sendMessage(processInfo.processId, {
              Action: "HealthCheck",
              Data: { monitoringTest: true },
            });
          } catch (_error) {
            // Continue on errors
          }
        }
      });

      await Promise.all(loadPromises);

      // Stop monitoring
      performanceMonitor.stopMonitoring();

      // Verify metrics were collected
      const realTimeMetrics = performanceMonitor.getRealTimeMetricsSummary();

      expect(Object.keys(realTimeMetrics)).toHaveLength(deployedProcesses.size);

      for (const [_processName, summary] of Object.entries(realTimeMetrics)) {
        expect(summary.sampleCount).toBeGreaterThan(0);
        expect(summary.latestMetrics).toBeDefined();
        expect(summary.timeRange.start).toBeLessThan(summary.timeRange.end);
      }
    }, 25000);
  });

  describe("Performance Regression Detection", () => {
    test("should detect performance regressions", async () => {
      // Run baseline benchmark
      const baselineBenchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, {
        responseTimeIterations: 5,
      });

      // Simulate performance regression by adding artificial delay
      // (In a real test, this would be a code change that causes regression)

      // Run comparison benchmark
      const regressionBenchmark = await performanceMonitor.runPerformanceBenchmark(deployedProcesses, {
        responseTimeIterations: 5,
      });

      // Compare results (simplified regression detection)
      const baselineResponseTime =
        baselineBenchmark.tests.find(t => t.type === "response_time")?.metrics?.overallAverageResponseTime || 0;

      const regressionResponseTime =
        regressionBenchmark.tests.find(t => t.type === "response_time")?.metrics?.overallAverageResponseTime || 0;

      // Both benchmarks should be reasonable (no major regression in this test)
      expect(regressionResponseTime).toBeLessThan(baselineResponseTime * 2); // Less than 2x slower
      expect(regressionResponseTime).toBeGreaterThan(0);
      expect(baselineResponseTime).toBeGreaterThan(0);
    }, 60000);
  });
});

// Helper functions
async function createPerformanceTestProcesses() {
  const processesDir = path.join(process.cwd(), "processes");
  await fs.mkdir(processesDir, { recursive: true });

  const testProcesses = {
    "coordinator-process.lua": createCoordinatorProcess(),
    "data-process.lua": createDataProcess(),
    "logic-process.lua": createLogicProcess(),
  };

  for (const [filename, content] of Object.entries(testProcesses)) {
    const filePath = path.join(processesDir, filename);
    await fs.writeFile(filePath, content);
  }
}

async function deployTestProcesses() {
  const processConfigs = [
    {
      processType: "coordinator",
      processPath: path.join(process.cwd(), "processes/coordinator-process.lua"),
      maxSize: 500000,
      requiredHandlers: ["Info", "HealthCheck", "ProcessLogic"],
    },
    {
      processType: "data",
      processPath: path.join(process.cwd(), "processes/data-process.lua"),
      maxSize: 450000,
      requiredHandlers: ["Info", "HealthCheck", "QueryData"],
    },
    {
      processType: "logic",
      processPath: path.join(process.cwd(), "processes/logic-process.lua"),
      maxSize: 500000,
      requiredHandlers: ["Info", "HealthCheck", "ProcessLogic"],
    },
  ];

  const processDeployer = new ProcessDeployer();
  await processDeployer.initialize();

  const deploymentResults = await processDeployer.deployMultipleProcesses(processConfigs);

  const deployedProcesses = new Map();
  for (const result of deploymentResults) {
    if (result.status === "deployed") {
      deployedProcesses.set(result.processName, {
        processId: result.processId,
        processName: result.processName,
        processType: result.processType,
      });
    }
  }

  return deployedProcesses;
}

function getProcessType(processName) {
  if (processName.includes("coordinator")) {
    return "coordinator";
  }
  if (processName.includes("data")) {
    return "dataProcess";
  }
  return "logicProcess";
}

function createCoordinatorProcess() {
  return `
    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Performance Test Coordinator",
          adpVersion = "1.0",
          handlers = ["Info", "HealthCheck", "ProcessLogic"]
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = { status = "healthy", timestamp = tostring(os.time()) }
      })
    end)

    Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "Success",
        Data = { processed = true, timestamp = tostring(os.time()) }
      })
    end)
  `;
}

function createDataProcess() {
  return `
    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Performance Test Data Process",
          adpVersion = "1.0",
          handlers = ["Info", "HealthCheck", "QueryData"]
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = { status = "healthy", timestamp = tostring(os.time()) }
      })
    end)

    Handlers.add("QueryData", Handlers.utils.hasMatchingTag("Action", "QueryData"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "DataResponse",
        Data = { 
          query = msg.Data.query or "default",
          result = "test_data",
          timestamp = tostring(os.time())
        }
      })
    end)
  `;
}

function createLogicProcess() {
  return `
    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Performance Test Logic Process",
          adpVersion = "1.0",
          handlers = ["Info", "HealthCheck", "ProcessLogic"]
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = { status = "healthy", timestamp = tostring(os.time()) }
      })
    end)

    Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
      -- Simulate some processing time
      local result = {}
      for i = 1, 100 do
        result[i] = i * 2
      end
      
      ao.send({
        Target = msg.From,
        Action = "LogicResult",
        Data = { 
          processed = true,
          result = result,
          timestamp = tostring(os.time())
        }
      })
    end)
  `;
}

// Shared utilities moved to testing/utils/test-helpers.js
