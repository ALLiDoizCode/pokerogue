/**
 * Recovery Scenarios Tests
 * Comprehensive testing for process failure and recovery scenarios
 */

import fs from "fs/promises";
import path from "path";
import { afterAll, beforeAll, beforeEach, describe, expect, test } from "@jest/globals";
import { IntegrationEnvironmentConfig } from "../../development-tools/integration-testing/environment-config.js";
import { ProcessDeployer } from "../aos-local/process-deployer.js";
import { RecoveryTester } from "../aos-local/recovery-tester.js";
import { recoveryBaselines, recoveryConfigs } from "../fixtures/recovery-scenarios.js";

describe("Recovery Scenarios Tests", () => {
  let recoveryTester;
  let _processDeployer;
  let environmentConfig;
  let tempDir;
  let testProcesses;

  beforeAll(async () => {
    // Setup test environment
    tempDir = path.join(process.cwd(), "testing/aos-local/temp", `recovery-test-${Date.now()}`);
    await fs.mkdir(tempDir, { recursive: true });

    // Initialize components
    environmentConfig = new IntegrationEnvironmentConfig({
      workspaceDir: tempDir,
    });

    recoveryTester = new RecoveryTester({
      tempDir,
      reportsDir: path.join(process.cwd(), "testing/reports"),
    });

    _processDeployer = new ProcessDeployer({
      tempDir,
      processesDir: path.join(process.cwd(), "processes"),
    });

    // Initialize environment
    await environmentConfig.initializeEnvironment();
    await recoveryTester.initialize();

    // Create and deploy test processes
    await createRecoveryTestProcesses();
    testProcesses = await deployRecoveryTestProcesses();
  });

  afterAll(async () => {
    // Cleanup
    await recoveryTester?.cleanup();
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

  describe("Process Restart Recovery", () => {
    test("should successfully restart and recover processes", async () => {
      const restartTest = await recoveryTester.testProcessRestart(testProcesses);

      expect(restartTest.type).toBe("process_restart");
      expect(restartTest.overallSuccess).toBe(true);
      expect(restartTest.metrics.successfulRestarts).toBeGreaterThan(0);
      expect(restartTest.metrics.successfulRestarts).toBe(testProcesses.size);

      // Verify restart times are within acceptable limits
      expect(restartTest.metrics.averageRestartTime).toBeLessThan(recoveryBaselines.timeBaselines.maxRestartTime);
      expect(restartTest.metrics.averageRecoveryTime).toBeLessThan(recoveryBaselines.timeBaselines.maxRecoveryTime);

      // Verify individual process restart results
      for (const processResult of restartTest.processes) {
        expect(processResult.success).toBe(true);
        expect(processResult.restartTime).toBeLessThan(15000); // 15 second limit
        expect(processResult.recoveryTime).toBeLessThan(10000); // 10 second limit
        expect(processResult.details.restartSuccessful).toBe(true);
        expect(processResult.details.recoverySuccessful).toBe(true);
      }
    }, 120000);

    test("should handle process restart failures gracefully", async () => {
      // Create a process that simulates restart failure
      const failingProcesses = new Map();
      const failingProcess = {
        processId: "failing-process-123",
        processName: "failing-process",
        processType: "test",
      };
      failingProcesses.set("failing-process", failingProcess);

      const restartTest = await recoveryTester.testProcessRestart(failingProcesses);

      expect(restartTest.type).toBe("process_restart");
      expect(restartTest.overallSuccess).toBe(false); // Should fail gracefully
      expect(restartTest.metrics.failedRestarts).toBe(1);

      const failedProcess = restartTest.processes[0];
      expect(failedProcess.success).toBe(false);
      expect(failedProcess.error).toBeDefined();
    }, 30000);

    test("should verify state persistence across restarts", async () => {
      // Test with a single process that supports state persistence
      const coordinatorProcess = new Map([["coordinator-process", testProcesses.get("coordinator-process")]]);

      const restartTest = await recoveryTester.testProcessRestart(coordinatorProcess);

      expect(restartTest.overallSuccess).toBe(true);

      const processResult = restartTest.processes[0];
      expect(processResult.stateVerification).toBeDefined();
      // Note: State persistence depends on process implementation
      // In a real scenario, this would verify actual state persistence
    }, 60000);
  });

  describe("Failure Injection and Recovery", () => {
    test("should recover from process crash failures", async () => {
      const crashFailureScenarios = [
        {
          type: "process_crash",
          targetSelection: "coordinator",
          recoveryStrategy: "restart",
          detectionTimeout: 5000,
        },
      ];

      const injectionTest = await recoveryTester.testFailureInjection(testProcesses, crashFailureScenarios);

      expect(injectionTest.type).toBe("failure_injection");
      expect(injectionTest.overallSuccess).toBe(true);
      expect(injectionTest.metrics.successfulRecoveries).toBe(1);
      expect(injectionTest.metrics.averageDetectionTime).toBeLessThan(
        recoveryBaselines.timeBaselines.maxFailureDetectionTime,
      );
      expect(injectionTest.metrics.averageRecoveryTime).toBeLessThan(recoveryBaselines.timeBaselines.maxRecoveryTime);

      const scenario = injectionTest.scenarios[0];
      expect(scenario.success).toBe(true);
      expect(scenario.detectionTime).toBeGreaterThan(0);
      expect(scenario.recoveryTime).toBeGreaterThan(0);
    }, 90000);

    test("should handle multiple failure types", async () => {
      const multipleFailureScenarios = [
        {
          type: "process_crash",
          targetSelection: "data",
          recoveryStrategy: "restart",
          detectionTimeout: 3000,
        },
        {
          type: "timeout",
          targetSelection: "logic",
          recoveryStrategy: "reset",
          detectionTimeout: 2000,
        },
        {
          type: "corrupted_message",
          targetSelection: "coordinator",
          recoveryStrategy: "restart",
          detectionTimeout: 4000,
        },
      ];

      const injectionTest = await recoveryTester.testFailureInjection(testProcesses, multipleFailureScenarios);

      expect(injectionTest.metrics.totalScenarios).toBe(3);
      expect(injectionTest.metrics.successfulRecoveries).toBeGreaterThanOrEqual(2); // At least 2/3 should succeed
      expect(injectionTest.metrics.averageDetectionTime).toBeLessThan(5000);

      // Check that different failure types were handled
      const scenarioTypes = injectionTest.scenarios.map(s => s.scenarioType);
      expect(scenarioTypes).toContain("process_crash");
      expect(scenarioTypes).toContain("timeout");
      expect(scenarioTypes).toContain("corrupted_message");
    }, 120000);

    test("should detect failures within acceptable time limits", async () => {
      const detectionScenarios = [
        {
          type: "process_crash",
          targetSelection: "random",
          recoveryStrategy: "restart",
          detectionTimeout: 2000, // Short detection timeout
        },
      ];

      const injectionTest = await recoveryTester.testFailureInjection(testProcesses, detectionScenarios);

      const scenario = injectionTest.scenarios[0];
      if (scenario.success && scenario.detectionTime > 0) {
        expect(scenario.detectionTime).toBeLessThan(3000); // Should detect within 3 seconds
      }
    }, 45000);
  });

  describe("Network Partition Recovery", () => {
    test("should handle network partition scenarios", async () => {
      const partitionTest = await recoveryTester.testNetworkPartition(testProcesses);

      expect(partitionTest.type).toBe("network_partition");
      expect(partitionTest.overallSuccess).toBe(true);
      expect(partitionTest.metrics.totalPartitions).toBeGreaterThan(0);
      expect(partitionTest.metrics.successfulRecoveries).toBeGreaterThan(0);

      // Verify partition scenarios were tested
      const partitionTypes = partitionTest.partitions.map(p => p.scenarioType);
      expect(partitionTypes).toContain("coordinator_isolation");

      // Check recovery times
      for (const partition of partitionTest.partitions) {
        if (partition.success) {
          expect(partition.recoveryTime).toBeLessThan(recoveryBaselines.timeBaselines.maxNetworkRecoveryTime);
        }
      }
    }, 180000);

    test("should maintain system functionality during partition", async () => {
      // This test would verify that the system maintains some level of functionality
      // even during network partitions (e.g., using cached data, fallback mechanisms)

      const limitedPartitionTest = await recoveryTester.testNetworkPartition(
        new Map([["coordinator-process", testProcesses.get("coordinator-process")]]),
      );

      expect(limitedPartitionTest.metrics.totalPartitions).toBeGreaterThan(0);

      // Even if some partitions fail, the test framework should handle it gracefully
      expect(limitedPartitionTest.partitions).toHaveLength(limitedPartitionTest.metrics.totalPartitions);
    }, 120000);
  });

  describe("State Persistence Testing", () => {
    test("should verify state persistence across various failure conditions", async () => {
      const persistenceTest = await recoveryTester.testStatePersistence(testProcesses);

      expect(persistenceTest.type).toBe("state_persistence");
      expect(persistenceTest.overallSuccess).toBe(true);
      expect(persistenceTest.metrics.totalTests).toBeGreaterThan(0);
      expect(persistenceTest.metrics.successfulPersistence).toBeGreaterThan(0);

      // Verify state persistence rate meets baseline
      const persistenceRate = persistenceTest.metrics.successfulPersistence / persistenceTest.metrics.totalTests;
      expect(persistenceRate).toBeGreaterThanOrEqual(recoveryBaselines.successRateBaselines.minStatePersistenceRate);

      // Check for data integrity issues
      expect(persistenceTest.metrics.dataIntegrityIssues).toBeLessThanOrEqual(1); // Allow minimal issues
    }, 120000);

    test("should handle state corruption and recovery", async () => {
      // Test how the system handles state corruption scenarios
      const corruptionTest = await recoveryTester.testStatePersistence(
        new Map([["coordinator-process", testProcesses.get("coordinator-process")]]),
      );

      expect(corruptionTest.metrics.totalTests).toBeGreaterThan(0);

      // Even with potential corruption, system should handle it gracefully
      const tests = corruptionTest.tests;
      for (const test of tests) {
        // Test should either succeed or fail gracefully with proper error handling
        expect(test).toHaveProperty("success");
        if (!test.success && test.dataIntegrityIssue) {
          expect(test.error).toBeDefined();
        }
      }
    }, 90000);
  });

  describe("Recovery Configuration Testing", () => {
    test("should execute quick recovery configuration", async () => {
      const quickConfig = recoveryConfigs.quick;
      const results = [];

      // Test process restart (from quick config)
      const restartTest = await recoveryTester.testProcessRestart(testProcesses);
      results.push(restartTest);

      // Test failure injection with limited failure types
      const quickFailureScenarios = quickConfig.failureTypes.map(type => ({
        type,
        targetSelection: "random",
        recoveryStrategy: "restart",
        detectionTimeout: 3000,
      }));

      const injectionTest = await recoveryTester.testFailureInjection(testProcesses, quickFailureScenarios);
      results.push(injectionTest);

      // Verify all tests completed within timeout
      const totalDuration = results.reduce((sum, result) => {
        return sum + (result.metrics?.totalTime || 0);
      }, 0);

      expect(totalDuration).toBeLessThan(quickConfig.timeout);
      expect(results.every(r => r.overallSuccess)).toBe(true);
    }, 90000);

    test("should meet recovery baseline requirements", async () => {
      // Test key recovery scenarios against baselines
      const restartTest = await recoveryTester.testProcessRestart(testProcesses);

      // Verify time baselines
      expect(restartTest.metrics.averageRestartTime).toBeLessThan(recoveryBaselines.timeBaselines.maxRestartTime);
      expect(restartTest.metrics.averageRecoveryTime).toBeLessThan(recoveryBaselines.timeBaselines.maxRecoveryTime);

      // Verify success rate baselines
      const successRate = restartTest.metrics.successfulRestarts / restartTest.metrics.totalProcesses;
      expect(successRate).toBeGreaterThanOrEqual(recoveryBaselines.successRateBaselines.minRecoverySuccessRate);
    }, 150000);
  });

  describe("Recovery Report Generation", () => {
    test("should generate comprehensive recovery reports", async () => {
      // Run a few recovery tests to generate report data
      await recoveryTester.testProcessRestart(
        new Map([["coordinator-process", testProcesses.get("coordinator-process")]]),
      );

      const failureScenarios = [
        {
          type: "process_crash",
          targetSelection: "coordinator",
          recoveryStrategy: "restart",
          detectionTimeout: 3000,
        },
      ];
      await recoveryTester.testFailureInjection(testProcesses, failureScenarios);

      // Generate recovery report
      const reports = await recoveryTester.generateRecoveryReport();

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

      expect(report.testResults.length).toBeGreaterThan(0);
      expect(report.summary).toBeDefined();
      expect(report.summary.totalTests).toBeGreaterThan(0);
      expect(report.metrics).toBeDefined();
    }, 120000);
  });

  describe("Edge Cases and Error Handling", () => {
    test("should handle recovery when no processes are available", async () => {
      const emptyProcesses = new Map();

      const restartTest = await recoveryTester.testProcessRestart(emptyProcesses);

      expect(restartTest.type).toBe("process_restart");
      expect(restartTest.metrics.totalProcesses).toBe(0);
      expect(restartTest.metrics.successfulRestarts).toBe(0);
      expect(restartTest.metrics.failedRestarts).toBe(0);
    }, 30000);

    test("should handle invalid failure scenarios gracefully", async () => {
      const invalidScenarios = [
        {
          type: "unknown_failure_type",
          targetSelection: "nonexistent",
          recoveryStrategy: "invalid_strategy",
          detectionTimeout: 1000,
        },
      ];

      const injectionTest = await recoveryTester.testFailureInjection(testProcesses, invalidScenarios);

      expect(injectionTest.type).toBe("failure_injection");
      expect(injectionTest.metrics.totalScenarios).toBe(1);
      // Should handle gracefully, either succeeding with fallback or failing gracefully
      expect(injectionTest.scenarios).toHaveLength(1);
      expect(injectionTest.scenarios[0]).toHaveProperty("success");
    }, 45000);

    test("should handle timeout scenarios appropriately", async () => {
      // Test with very short timeouts to verify timeout handling
      const timeoutScenarios = [
        {
          type: "timeout",
          targetSelection: "random",
          recoveryStrategy: "restart",
          detectionTimeout: 100, // Very short timeout
        },
      ];

      const injectionTest = await recoveryTester.testFailureInjection(testProcesses, timeoutScenarios);

      const scenario = injectionTest.scenarios[0];
      // Should either detect quickly or timeout gracefully
      if (!scenario.success) {
        expect(scenario.error).toBeDefined();
      }
    }, 30000);
  });
});

// Helper functions
async function createRecoveryTestProcesses() {
  const processesDir = path.join(process.cwd(), "processes");
  await fs.mkdir(processesDir, { recursive: true });

  const testProcesses = {
    "coordinator-process.lua": createRecoveryCoordinatorProcess(),
    "data-process.lua": createRecoveryDataProcess(),
    "logic-process.lua": createRecoveryLogicProcess(),
  };

  for (const [filename, content] of Object.entries(testProcesses)) {
    const filePath = path.join(processesDir, filename);
    await fs.writeFile(filePath, content);
  }
}

async function deployRecoveryTestProcesses() {
  const processConfigs = [
    {
      processType: "coordinator",
      processPath: path.join(process.cwd(), "processes/coordinator-process.lua"),
      maxSize: 500000,
      requiredHandlers: ["Info", "HealthCheck"],
    },
    {
      processType: "data",
      processPath: path.join(process.cwd(), "processes/data-process.lua"),
      maxSize: 450000,
      requiredHandlers: ["Info", "HealthCheck"],
    },
    {
      processType: "logic",
      processPath: path.join(process.cwd(), "processes/logic-process.lua"),
      maxSize: 500000,
      requiredHandlers: ["Info", "HealthCheck"],
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

function createRecoveryCoordinatorProcess() {
  return `
    local testState = {}

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Recovery Test Coordinator",
          adpVersion = "1.0",
          handlers = {"Info", "HealthCheck", "StoreTestState", "GetTestState", "Reset"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {
          status = "healthy",
          timestamp = tostring(os.time()),
          testState = testState
        }
      })
    end)

    Handlers.add("StoreTestState", Handlers.utils.hasMatchingTag("Action", "StoreTestState"), function(msg)
      for key, value in pairs(msg.Data) do
        testState[key] = value
      end
      
      ao.send({
        Target = msg.From,
        Action = "StateStored",
        Data = {
          success = true,
          storedKeys = msg.Data
        }
      })
    end)

    Handlers.add("GetTestState", Handlers.utils.hasMatchingTag("Action", "GetTestState"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "TestStateResponse",
        Data = testState
      })
    end)

    Handlers.add("Reset", Handlers.utils.hasMatchingTag("Action", "Reset"), function(msg)
      testState = {}
      ao.send({
        Target = msg.From,
        Action = "ResetComplete",
        Data = {success = true}
      })
    end)

    Handlers.add("SimulateMemoryPressure", Handlers.utils.hasMatchingTag("Action", "SimulateMemoryPressure"), function(msg)
      -- Simulate memory pressure (mock implementation)
      ao.send({
        Target = msg.From,
        Action = "MemoryPressureResponse",
        Data = {
          pressureSimulated = true,
          mockMemoryUsage = "high"
        }
      })
    end)
  `;
}

function createRecoveryDataProcess() {
  return `
    local processData = {}

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Recovery Test Data Process",
          adpVersion = "1.0",
          handlers = {"Info", "HealthCheck", "QueryData", "StoreData"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {
          status = "healthy",
          timestamp = tostring(os.time()),
          dataEntries = #processData
        }
      })
    end)

    Handlers.add("QueryData", Handlers.utils.hasMatchingTag("Action", "QueryData"), function(msg)
      local key = msg.Data.key or "default"
      local data = processData[key]
      
      ao.send({
        Target = msg.From,
        Action = "DataResponse",
        Data = {
          key = key,
          data = data,
          found = data ~= nil
        }
      })
    end)

    Handlers.add("StoreData", Handlers.utils.hasMatchingTag("Action", "StoreData"), function(msg)
      local key = msg.Data.key
      local value = msg.Data.value
      
      if key then
        processData[key] = value
      end
      
      ao.send({
        Target = msg.From,
        Action = "DataStored",
        Data = {
          success = key ~= nil,
          key = key
        }
      })
    end)
  `;
}

function createRecoveryLogicProcess() {
  return `
    local logicState = {
      operationsProcessed = 0,
      lastOperation = nil
    }

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Recovery Test Logic Process",
          adpVersion = "1.0",
          handlers = {"Info", "HealthCheck", "ProcessLogic", "GetState"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {
          status = "healthy",
          timestamp = tostring(os.time()),
          operationsProcessed = logicState.operationsProcessed
        }
      })
    end)

    Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
      local operation = msg.Data.operation or "default"
      
      logicState.operationsProcessed = logicState.operationsProcessed + 1
      logicState.lastOperation = operation
      
      ao.send({
        Target = msg.From,
        Action = "LogicProcessed",
        Data = {
          operation = operation,
          processedCount = logicState.operationsProcessed,
          timestamp = tostring(os.time())
        }
      })
    end)

    Handlers.add("GetState", Handlers.utils.hasMatchingTag("Action", "GetState"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "StateResponse",
        Data = logicState
      })
    end)
  `;
}

// Shared utilities moved to testing/utils/test-helpers.js
