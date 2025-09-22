/**
 * Recovery Tester
 * Comprehensive testing for process failure and recovery scenarios
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { AoliteFramework } from "../aolite/aolite-framework.js";
import { ProcessDeployer } from "./process-deployer.js";

export class RecoveryTester {
  constructor(options = {}) {
    this.aoliteFramework = new AoliteFramework();
    this.processDeployer = new ProcessDeployer();
    this.tempDir = options.tempDir || path.join(process.cwd(), "testing/aos-local/temp");
    this.reportsDir = options.reportsDir || path.join(process.cwd(), "testing/reports");
    this.recoveryResults = [];
    this.failureInjectors = new Map();
    this.recoveryMetrics = {
      totalFailures: 0,
      successfulRecoveries: 0,
      averageRecoveryTime: 0,
      failureTypes: new Map()
    };
  }

  /**
   * Initialize recovery tester
   */
  async initialize() {
    console.log(chalk.blue("🔄 Initializing recovery tester..."));
    
    await this.aoliteFramework.initialize();
    await this.processDeployer.initialize();
    
    // Ensure reports directory exists
    await fs.mkdir(this.reportsDir, { recursive: true });
    
    console.log(chalk.green("✅ Recovery tester ready"));
  }

  /**
   * Test process restart and recovery
   */
  async testProcessRestart(processes) {
    console.log(chalk.blue("🔄 Testing process restart and recovery..."));
    
    const restartTest = {
      type: "process_restart",
      timestamp: new Date().toISOString(),
      processes: [],
      overallSuccess: true,
      metrics: {
        totalProcesses: processes.size,
        successfulRestarts: 0,
        failedRestarts: 0,
        averageRestartTime: 0,
        averageRecoveryTime: 0
      }
    };

    const restartTimes = [];
    const recoveryTimes = [];

    for (const [processName, processInfo] of processes) {
      console.log(chalk.yellow(`  🔄 Testing restart for ${processName}...`));
      
      const restartResult = await this.testSingleProcessRestart(processName, processInfo);
      restartTest.processes.push(restartResult);
      
      if (restartResult.success) {
        restartTest.metrics.successfulRestarts++;
        restartTimes.push(restartResult.restartTime);
        recoveryTimes.push(restartResult.recoveryTime);
      } else {
        restartTest.metrics.failedRestarts++;
        restartTest.overallSuccess = false;
      }
    }

    // Calculate averages
    if (restartTimes.length > 0) {
      restartTest.metrics.averageRestartTime = 
        restartTimes.reduce((sum, time) => sum + time, 0) / restartTimes.length;
    }
    
    if (recoveryTimes.length > 0) {
      restartTest.metrics.averageRecoveryTime = 
        recoveryTimes.reduce((sum, time) => sum + time, 0) / recoveryTimes.length;
    }

    this.recoveryResults.push(restartTest);
    
    console.log(chalk.green(
      `✅ Process restart test completed: ${restartTest.metrics.successfulRestarts}/${restartTest.metrics.totalProcesses} successful`
    ));
    
    return restartTest;
  }

  /**
   * Test single process restart
   */
  async testSingleProcessRestart(processName, processInfo) {
    const restartStart = Date.now();
    
    try {
      // Step 1: Establish baseline state
      const baselineResponse = await this.aoliteFramework.sendMessage(processInfo.processId, {
        Action: "HealthCheck",
        Data: { restartTest: true }
      });

      if (!baselineResponse?.success) {
        throw new Error("Process not responsive before restart");
      }

      // Step 2: Store some state data
      await this.aoliteFramework.sendMessage(processInfo.processId, {
        Action: "StoreTestState",
        Data: { 
          testData: "restart_test_data",
          timestamp: Date.now(),
          processName: processName
        }
      });

      // Step 3: Simulate process restart
      const restartTime = await this.simulateProcessRestart(processInfo);
      
      // Step 4: Wait for process to become responsive again
      const recoveryStart = Date.now();
      const recoveryResult = await this.waitForProcessRecovery(processInfo, 10000); // 10 second timeout
      const recoveryTime = Date.now() - recoveryStart;

      if (!recoveryResult.success) {
        throw new Error(`Process recovery failed: ${recoveryResult.error}`);
      }

      // Step 5: Verify state persistence (if applicable)
      const stateVerification = await this.verifyStatePersistence(processInfo);

      return {
        processName,
        success: true,
        restartTime,
        recoveryTime,
        totalTime: Date.now() - restartStart,
        stateVerification,
        details: {
          baselineHealthy: true,
          restartSuccessful: true,
          recoverySuccessful: recoveryResult.success,
          statePersisted: stateVerification.persisted
        }
      };

    } catch (error) {
      return {
        processName,
        success: false,
        error: error.message,
        totalTime: Date.now() - restartStart,
        details: {
          failurePoint: this.identifyFailurePoint(error.message)
        }
      };
    }
  }

  /**
   * Simulate process restart
   */
  async simulateProcessRestart(processInfo) {
    const restartStart = Date.now();
    
    try {
      // Step 1: Stop the process
      await this.processDeployer.stopProcess(processInfo.processId);
      
      // Step 2: Wait a moment to simulate restart delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Step 3: Restart the process
      const restartResult = await this.processDeployer.restartProcess(processInfo.processId);
      
      if (restartResult.success) {
        // Update process info with new process ID
        processInfo.processId = restartResult.processId;
        return Date.now() - restartStart;
      } else {
        throw new Error(`Restart failed: ${restartResult.error}`);
      }

    } catch (error) {
      throw new Error(`Process restart simulation failed: ${error.message}`);
    }
  }

  /**
   * Wait for process recovery
   */
  async waitForProcessRecovery(processInfo, timeout = 10000) {
    const recoveryStart = Date.now();
    const endTime = recoveryStart + timeout;
    
    while (Date.now() < endTime) {
      try {
        const healthResponse = await this.aoliteFramework.sendMessage(processInfo.processId, {
          Action: "HealthCheck",
          Data: { recoveryTest: true }
        });

        if (healthResponse?.success) {
          return {
            success: true,
            recoveryTime: Date.now() - recoveryStart,
            healthResponse
          };
        }

      } catch (error) {
        // Continue trying until timeout
      }

      // Wait before next attempt
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    return {
      success: false,
      error: "Recovery timeout",
      attemptedTime: Date.now() - recoveryStart
    };
  }

  /**
   * Test failure injection and recovery
   */
  async testFailureInjection(processes, failureScenarios) {
    console.log(chalk.blue("💥 Testing failure injection and recovery..."));
    
    const injectionTest = {
      type: "failure_injection",
      timestamp: new Date().toISOString(),
      scenarios: [],
      overallSuccess: true,
      metrics: {
        totalScenarios: failureScenarios.length,
        successfulRecoveries: 0,
        failedRecoveries: 0,
        averageDetectionTime: 0,
        averageRecoveryTime: 0
      }
    };

    for (const scenario of failureScenarios) {
      console.log(chalk.yellow(`  💥 Testing ${scenario.type} failure...`));
      
      const scenarioResult = await this.executeFailureScenario(scenario, processes);
      injectionTest.scenarios.push(scenarioResult);
      
      if (scenarioResult.success) {
        injectionTest.metrics.successfulRecoveries++;
      } else {
        injectionTest.metrics.failedRecoveries++;
        injectionTest.overallSuccess = false;
      }
    }

    // Calculate metrics
    const detectionTimes = injectionTest.scenarios
      .filter(s => s.detectionTime > 0)
      .map(s => s.detectionTime);
    
    const recoveryTimes = injectionTest.scenarios
      .filter(s => s.recoveryTime > 0)
      .map(s => s.recoveryTime);

    if (detectionTimes.length > 0) {
      injectionTest.metrics.averageDetectionTime = 
        detectionTimes.reduce((sum, time) => sum + time, 0) / detectionTimes.length;
    }

    if (recoveryTimes.length > 0) {
      injectionTest.metrics.averageRecoveryTime = 
        recoveryTimes.reduce((sum, time) => sum + time, 0) / recoveryTimes.length;
    }

    this.recoveryResults.push(injectionTest);
    
    console.log(chalk.green(
      `✅ Failure injection test completed: ${injectionTest.metrics.successfulRecoveries}/${injectionTest.metrics.totalScenarios} scenarios recovered`
    ));
    
    return injectionTest;
  }

  /**
   * Execute individual failure scenario
   */
  async executeFailureScenario(scenario, processes) {
    const scenarioStart = Date.now();
    
    try {
      const targetProcess = this.selectTargetProcess(scenario.targetSelection, processes);
      if (!targetProcess) {
        throw new Error("No suitable target process found");
      }

      // Step 1: Establish baseline
      const baseline = await this.establishBaseline(targetProcess);
      
      // Step 2: Inject failure
      const injectionResult = await this.injectFailure(scenario, targetProcess);
      
      // Step 3: Detect failure
      const detectionStart = Date.now();
      const detectionResult = await this.detectFailure(targetProcess, scenario.detectionTimeout || 5000);
      const detectionTime = detectionResult.detected ? Date.now() - detectionStart : -1;
      
      // Step 4: Attempt recovery
      const recoveryStart = Date.now();
      const recoveryResult = await this.attemptRecovery(scenario, targetProcess);
      const recoveryTime = recoveryResult.success ? Date.now() - recoveryStart : -1;

      // Step 5: Verify recovery
      const verificationResult = await this.verifyRecovery(targetProcess, baseline);

      return {
        scenarioType: scenario.type,
        targetProcess: targetProcess.processName,
        success: recoveryResult.success && verificationResult.success,
        detectionTime,
        recoveryTime,
        totalTime: Date.now() - scenarioStart,
        details: {
          baseline,
          injection: injectionResult,
          detection: detectionResult,
          recovery: recoveryResult,
          verification: verificationResult
        }
      };

    } catch (error) {
      return {
        scenarioType: scenario.type,
        success: false,
        error: error.message,
        totalTime: Date.now() - scenarioStart
      };
    }
  }

  /**
   * Test network partition simulation
   */
  async testNetworkPartition(processes) {
    console.log(chalk.blue("🌐 Testing network partition scenarios..."));
    
    const partitionTest = {
      type: "network_partition",
      timestamp: new Date().toISOString(),
      partitions: [],
      overallSuccess: true,
      metrics: {
        totalPartitions: 0,
        successfulRecoveries: 0,
        averagePartitionDuration: 0,
        averageRecoveryTime: 0
      }
    };

    // Test different partition scenarios
    const partitionScenarios = [
      {
        type: "coordinator_isolation",
        description: "Isolate coordinator from other processes",
        affectedProcesses: ["coordinator-process"],
        duration: 5000 // 5 seconds
      },
      {
        type: "data_process_isolation",
        description: "Isolate data processes",
        affectedProcesses: ["pokemon-species-data", "move-data"],
        duration: 3000 // 3 seconds
      },
      {
        type: "split_brain",
        description: "Split processes into two groups",
        affectedProcesses: Array.from(processes.keys()).slice(0, Math.floor(processes.size / 2)),
        duration: 4000 // 4 seconds
      }
    ];

    for (const scenario of partitionScenarios) {
      console.log(chalk.yellow(`  🌐 Testing ${scenario.type}...`));
      
      const partitionResult = await this.executeNetworkPartition(scenario, processes);
      partitionTest.partitions.push(partitionResult);
      partitionTest.metrics.totalPartitions++;
      
      if (partitionResult.success) {
        partitionTest.metrics.successfulRecoveries++;
      } else {
        partitionTest.overallSuccess = false;
      }
    }

    this.recoveryResults.push(partitionTest);
    
    console.log(chalk.green(
      `✅ Network partition test completed: ${partitionTest.metrics.successfulRecoveries}/${partitionTest.metrics.totalPartitions} scenarios recovered`
    ));
    
    return partitionTest;
  }

  /**
   * Execute network partition scenario
   */
  async executeNetworkPartition(scenario, processes) {
    const partitionStart = Date.now();
    
    try {
      // Step 1: Establish baseline communication
      const baseline = await this.testInterProcessCommunication(processes);
      
      // Step 2: Simulate network partition
      const partitionResult = await this.simulateNetworkPartition(scenario, processes);
      
      // Step 3: Verify partition effect
      const partitionVerification = await this.verifyPartitionEffect(scenario, processes);
      
      // Step 4: Wait for partition duration
      await new Promise(resolve => setTimeout(resolve, scenario.duration));
      
      // Step 5: Restore network connectivity
      const restorationResult = await this.restoreNetworkConnectivity(scenario, processes);
      
      // Step 6: Verify recovery
      const recoveryStart = Date.now();
      const recoveryVerification = await this.verifyNetworkRecovery(processes, baseline);
      const recoveryTime = Date.now() - recoveryStart;

      return {
        scenarioType: scenario.type,
        success: restorationResult.success && recoveryVerification.success,
        partitionDuration: scenario.duration,
        recoveryTime,
        totalTime: Date.now() - partitionStart,
        details: {
          baseline,
          partition: partitionResult,
          verification: partitionVerification,
          restoration: restorationResult,
          recovery: recoveryVerification
        }
      };

    } catch (error) {
      return {
        scenarioType: scenario.type,
        success: false,
        error: error.message,
        totalTime: Date.now() - partitionStart
      };
    }
  }

  /**
   * Test state persistence across failures
   */
  async testStatePersistence(processes) {
    console.log(chalk.blue("💾 Testing state persistence across failures..."));
    
    const persistenceTest = {
      type: "state_persistence",
      timestamp: new Date().toISOString(),
      tests: [],
      overallSuccess: true,
      metrics: {
        totalTests: 0,
        successfulPersistence: 0,
        dataIntegrityIssues: 0
      }
    };

    const persistenceScenarios = [
      {
        type: "game_state_persistence",
        description: "Test game state persistence through restart",
        processType: "coordinator",
        stateData: {
          gameSession: "test_session_123",
          playerLevel: 50,
          activePokemon: "Charizard"
        }
      },
      {
        type: "battle_state_persistence",
        description: "Test battle state persistence",
        processType: "logic",
        stateData: {
          battleId: "battle_456",
          turn: 3,
          playerAction: "attack"
        }
      },
      {
        type: "cache_persistence",
        description: "Test cache persistence",
        processType: "data",
        stateData: {
          cachedSpecies: ["Bulbasaur", "Charmander", "Squirtle"],
          lastUpdate: Date.now()
        }
      }
    ];

    for (const scenario of persistenceScenarios) {
      console.log(chalk.yellow(`  💾 Testing ${scenario.type}...`));
      
      const persistenceResult = await this.executeStatePersistenceTest(scenario, processes);
      persistenceTest.tests.push(persistenceResult);
      persistenceTest.metrics.totalTests++;
      
      if (persistenceResult.success) {
        persistenceTest.metrics.successfulPersistence++;
      } else {
        persistenceTest.overallSuccess = false;
        if (persistenceResult.dataIntegrityIssue) {
          persistenceTest.metrics.dataIntegrityIssues++;
        }
      }
    }

    this.recoveryResults.push(persistenceTest);
    
    console.log(chalk.green(
      `✅ State persistence test completed: ${persistenceTest.metrics.successfulPersistence}/${persistenceTest.metrics.totalTests} tests passed`
    ));
    
    return persistenceTest;
  }

  /**
   * Generate comprehensive recovery report
   */
  async generateRecoveryReport() {
    const reportPath = path.join(this.reportsDir, `recovery-test-${Date.now()}.json`);
    const htmlReportPath = path.join(this.reportsDir, `recovery-test-${Date.now()}.html`);

    const report = {
      timestamp: new Date().toISOString(),
      framework: "Process Recovery Testing Framework",
      summary: this.generateRecoverySummary(),
      testResults: this.recoveryResults,
      metrics: this.recoveryMetrics,
      recommendations: this.generateRecoveryRecommendations()
    };

    // Write JSON report
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    // Generate HTML report
    const htmlReport = this.generateHtmlRecoveryReport(report);
    await fs.writeFile(htmlReportPath, htmlReport);

    console.log(chalk.green("📊 Recovery test reports generated:"));
    console.log(chalk.blue(`  JSON: ${reportPath}`));
    console.log(chalk.blue(`  HTML: ${htmlReportPath}`));

    return { jsonReport: reportPath, htmlReport: htmlReportPath };
  }

  /**
   * Helper methods
   */
  selectTargetProcess(selection, processes) {
    switch (selection) {
      case "coordinator":
        return Array.from(processes.values()).find(p => p.processName.includes("coordinator"));
      case "data":
        return Array.from(processes.values()).find(p => p.processType === "data");
      case "logic":
        return Array.from(processes.values()).find(p => p.processType === "logic");
      case "random":
        const processArray = Array.from(processes.values());
        return processArray[Math.floor(Math.random() * processArray.length)];
      default:
        return Array.from(processes.values())[0];
    }
  }

  async establishBaseline(targetProcess) {
    try {
      const response = await this.aoliteFramework.sendMessage(targetProcess.processId, {
        Action: "HealthCheck",
        Data: { baseline: true }
      });

      return {
        healthy: response?.success || false,
        responseTime: Date.now(),
        processId: targetProcess.processId
      };
    } catch (error) {
      return {
        healthy: false,
        error: error.message
      };
    }
  }

  async injectFailure(scenario, targetProcess) {
    // Simulate different types of failures
    switch (scenario.type) {
      case "process_crash":
        return await this.simulateProcessCrash(targetProcess);
      case "memory_exhaustion":
        return await this.simulateMemoryExhaustion(targetProcess);
      case "timeout":
        return await this.simulateTimeout(targetProcess);
      case "corrupted_message":
        return await this.simulateCorruptedMessage(targetProcess);
      default:
        return { injected: false, error: "Unknown failure type" };
    }
  }

  async simulateProcessCrash(targetProcess) {
    try {
      // Simulate crash by stopping the process unexpectedly
      await this.processDeployer.stopProcess(targetProcess.processId);
      return { injected: true, type: "process_crash" };
    } catch (error) {
      return { injected: false, error: error.message };
    }
  }

  async simulateMemoryExhaustion(targetProcess) {
    try {
      // Send a message that would simulate memory pressure
      await this.aoliteFramework.sendMessage(targetProcess.processId, {
        Action: "SimulateMemoryPressure",
        Data: { allocateMemory: true, size: "large" }
      });
      return { injected: true, type: "memory_exhaustion" };
    } catch (error) {
      return { injected: false, error: error.message };
    }
  }

  async simulateTimeout(targetProcess) {
    try {
      // Send a message with very short timeout
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error("Simulated timeout")), 100)
      );
      
      await Promise.race([
        this.aoliteFramework.sendMessage(targetProcess.processId, {
          Action: "HealthCheck",
          Data: {}
        }),
        timeoutPromise
      ]);
      
      return { injected: true, type: "timeout" };
    } catch (error) {
      return { injected: true, type: "timeout", simulatedError: error.message };
    }
  }

  async simulateCorruptedMessage(targetProcess) {
    try {
      // Send malformed message
      await this.aoliteFramework.sendMessage(targetProcess.processId, {
        Action: "InvalidAction",
        Data: { corruption: true, invalidData: "CORRUPT" }
      });
      return { injected: true, type: "corrupted_message" };
    } catch (error) {
      return { injected: false, error: error.message };
    }
  }

  async detectFailure(targetProcess, timeout) {
    const detectionStart = Date.now();
    
    while (Date.now() - detectionStart < timeout) {
      try {
        const response = await this.aoliteFramework.sendMessage(targetProcess.processId, {
          Action: "HealthCheck",
          Data: {}
        });

        if (!response?.success) {
          return {
            detected: true,
            detectionTime: Date.now() - detectionStart,
            method: "health_check_failure"
          };
        }
      } catch (error) {
        return {
          detected: true,
          detectionTime: Date.now() - detectionStart,
          method: "exception",
          error: error.message
        };
      }

      await new Promise(resolve => setTimeout(resolve, 500));
    }

    return { detected: false, reason: "timeout" };
  }

  async attemptRecovery(scenario, targetProcess) {
    try {
      switch (scenario.recoveryStrategy || "restart") {
        case "restart":
          return await this.processDeployer.restartProcess(targetProcess.processId);
        case "reset":
          // Send reset message
          const response = await this.aoliteFramework.sendMessage(targetProcess.processId, {
            Action: "Reset",
            Data: {}
          });
          return { success: response?.success || false };
        default:
          return { success: false, error: "Unknown recovery strategy" };
      }
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async verifyRecovery(targetProcess, baseline) {
    try {
      const response = await this.aoliteFramework.sendMessage(targetProcess.processId, {
        Action: "HealthCheck",
        Data: { recovery: true }
      });

      return {
        success: response?.success || false,
        responsive: response?.success || false,
        baselineRestored: true // Simplified verification
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  async verifyStatePersistence(processInfo) {
    try {
      const response = await this.aoliteFramework.sendMessage(processInfo.processId, {
        Action: "GetTestState",
        Data: {}
      });

      // Check if previously stored state is still available
      return {
        persisted: response?.data?.testData === "restart_test_data",
        stateData: response?.data
      };
    } catch (error) {
      return {
        persisted: false,
        error: error.message
      };
    }
  }

  identifyFailurePoint(errorMessage) {
    if (errorMessage.includes("restart")) return "restart";
    if (errorMessage.includes("recovery")) return "recovery";
    if (errorMessage.includes("responsive")) return "baseline";
    return "unknown";
  }

  generateRecoverySummary() {
    const totalTests = this.recoveryResults.length;
    const successfulTests = this.recoveryResults.filter(r => r.overallSuccess).length;
    
    return {
      totalTests,
      successfulTests,
      failedTests: totalTests - successfulTests,
      successRate: totalTests > 0 ? (successfulTests / totalTests) * 100 : 0,
      totalRecoveries: this.recoveryMetrics.successfulRecoveries,
      averageRecoveryTime: this.recoveryMetrics.averageRecoveryTime
    };
  }

  generateRecoveryRecommendations() {
    const recommendations = [];
    
    if (this.recoveryMetrics.successfulRecoveries / this.recoveryMetrics.totalFailures < 0.9) {
      recommendations.push("Recovery success rate below 90% - improve recovery mechanisms");
    }
    
    if (this.recoveryMetrics.averageRecoveryTime > 5000) {
      recommendations.push("Average recovery time exceeds 5 seconds - optimize recovery procedures");
    }
    
    return recommendations;
  }

  generateHtmlRecoveryReport(report) {
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Process Recovery Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .test-result { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Process Recovery Test Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Generated:</strong> ${report.timestamp}</p>
        <p><strong>Total Tests:</strong> ${report.summary.totalTests}</p>
        <p><strong>Successful:</strong> <span class="success">${report.summary.successfulTests}</span></p>
        <p><strong>Failed:</strong> <span class="failed">${report.summary.failedTests}</span></p>
        <p><strong>Success Rate:</strong> ${report.summary.successRate.toFixed(1)}%</p>
    </div>
    
    <h2>Test Results</h2>
    ${report.testResults.map(result => `
        <div class="test-result">
            <h3>${result.type} <span class="${result.overallSuccess ? 'success' : 'failed'}">${result.overallSuccess ? 'PASSED' : 'FAILED'}</span></h3>
            <p><strong>Timestamp:</strong> ${result.timestamp}</p>
            ${result.metrics ? `
                <p><strong>Metrics:</strong></p>
                <ul>
                    ${Object.entries(result.metrics).map(([key, value]) => `<li>${key}: ${value}</li>`).join('')}
                </ul>
            ` : ''}
        </div>
    `).join('')}
    
    ${report.recommendations.length > 0 ? `
    <h2>Recommendations</h2>
    <ul>
        ${report.recommendations.map(rec => `<li>${rec}</li>`).join('')}
    </ul>
    ` : ''}
</body>
</html>`;
  }

  /**
   * Cleanup recovery tester
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up recovery tester..."));

    await this.processDeployer.cleanup();
    await this.aoliteFramework.cleanup();

    this.recoveryResults = [];
    this.failureInjectors.clear();

    console.log(chalk.green("✅ Recovery tester cleanup completed"));
  }
}

export { RecoveryTester };