/**
 * Scenario Executor
 * Executes comprehensive end-to-end scenarios for deployment validation
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { AoliteFramework } from "../aolite/aolite-framework.js";
import { ProcessDeployer } from "./process-deployer.js";

export class ScenarioExecutor {
  constructor(options = {}) {
    this.aoliteFramework = new AoliteFramework();
    this.processDeployer = new ProcessDeployer();
    this.scenariosDir = options.scenariosDir || path.join(process.cwd(), "testing/aos-local/scenarios");
    this.tempDir = options.tempDir || path.join(process.cwd(), "testing/aos-local/temp");
    this.executionResults = [];
    this.activeScenarios = new Map();
  }

  /**
   * Initialize scenario executor
   */
  async initialize() {
    console.log(chalk.blue("🎬 Initializing scenario executor..."));

    await this.aoliteFramework.initialize();
    await this.processDeployer.initialize();

    // Create scenarios directory if it doesn't exist
    await fs.mkdir(this.scenariosDir, { recursive: true });

    console.log(chalk.green("✅ Scenario executor ready"));
  }

  /**
   * Execute a single end-to-end scenario
   */
  async executeScenario(scenario) {
    const executionStart = Date.now();
    console.log(chalk.blue(`🎭 Executing scenario: ${scenario.name}`));

    const result = {
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      timestamp: new Date().toISOString(),
      status: "running",
      steps: [],
      processes: new Map(),
      messages: [],
      performance: {},
      validation: {},
      duration: 0,
      errors: [],
    };

    this.activeScenarios.set(scenario.id, result);

    try {
      // Phase 1: Process Deployment
      if (scenario.processes && scenario.processes.length > 0) {
        const deploymentResult = await this.deployProcessesForScenario(scenario, result);
        if (!deploymentResult.success) {
          throw new Error(`Process deployment failed: ${deploymentResult.error}`);
        }
      }

      // Phase 2: Scenario Steps Execution
      for (let i = 0; i < scenario.steps.length; i++) {
        const step = scenario.steps[i];
        console.log(chalk.yellow(`  📋 Step ${i + 1}/${scenario.steps.length}: ${step.type}`));

        const stepResult = await this.executeScenarioStep(step, scenario, result);
        result.steps.push(stepResult);

        if (stepResult.status === "failed" && step.critical !== false) {
          throw new Error(`Critical step failed: ${stepResult.error}`);
        }
      }

      // Phase 3: Final Validation
      const validation = await this.validateScenarioCompletion(scenario, result);
      result.validation = validation;

      if (!validation.success) {
        throw new Error(`Scenario validation failed: ${validation.error}`);
      }

      result.status = "passed";
      console.log(chalk.green(`  ✅ Scenario completed: ${scenario.name}`));
    } catch (error) {
      result.status = "failed";
      result.errors.push(error.message);
      console.log(chalk.red(`  ❌ Scenario failed: ${scenario.name} - ${error.message}`));
    }

    result.duration = Date.now() - executionStart;
    this.executionResults.push(result);
    this.activeScenarios.delete(scenario.id);

    return result;
  }

  /**
   * Deploy processes required for scenario
   */
  async deployProcessesForScenario(scenario, result) {
    console.log(chalk.blue(`  🚀 Deploying ${scenario.processes.length} processes for scenario...`));

    try {
      const deploymentConfigs = await this.createDeploymentConfigs(scenario.processes);
      const deploymentResults = await this.processDeployer.deployMultipleProcesses(deploymentConfigs, {
        respectDependencies: true,
        parallel: scenario.parallelDeployment || false,
      });

      // Track deployed processes
      for (const deploymentResult of deploymentResults) {
        if (deploymentResult.status === "deployed") {
          result.processes.set(deploymentResult.processName, {
            processId: deploymentResult.processId,
            processName: deploymentResult.processName,
            processType: deploymentResult.processType,
            deploymentTime: deploymentResult.deploymentTime,
            status: "deployed",
          });
        }
      }

      const successfulDeployments = deploymentResults.filter(r => r.status === "deployed").length;
      console.log(chalk.green(`    ✅ ${successfulDeployments}/${deploymentResults.length} processes deployed`));

      if (successfulDeployments < deploymentResults.length) {
        const failedDeployments = deploymentResults.filter(r => r.status === "failed");
        return {
          success: false,
          error: `Failed to deploy: ${failedDeployments.map(f => f.processName).join(", ")}`,
        };
      }

      return { success: true, deployments: deploymentResults };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Create deployment configurations for scenario processes
   */
  async createDeploymentConfigs(processNames) {
    const configs = [];

    for (const processName of processNames) {
      const processPath = await this.findProcessFile(processName);
      if (!processPath) {
        throw new Error(`Process file not found for: ${processName}`);
      }

      const config = {
        processType: this.determineProcessType(processName),
        processPath,
        maxSize: 500000,
        requiredHandlers: this.getRequiredHandlers(processName),
        dependencies: this.getProcessDependencies(processName),
      };

      configs.push(config);
    }

    return configs;
  }

  /**
   * Execute individual scenario step
   */
  async executeScenarioStep(step, _scenario, result) {
    const stepStart = Date.now();

    try {
      let stepResult;

      switch (step.type) {
        case "send_message":
          stepResult = await this.executeSendMessage(step, result);
          break;
        case "wait_for_response":
          stepResult = await this.executeWaitForResponse(step, result);
          break;
        case "validate_state":
          stepResult = await this.executeValidateState(step, result);
          break;
        case "multi_process_interaction":
          stepResult = await this.executeMultiProcessInteraction(step, result);
          break;
        case "battle_simulation":
          stepResult = await this.executeBattleSimulation(step, result);
          break;
        case "data_consistency_check":
          stepResult = await this.executeDataConsistencyCheck(step, result);
          break;
        case "performance_validation":
          stepResult = await this.executePerformanceValidation(step, result);
          break;
        case "error_injection":
          stepResult = await this.executeErrorInjection(step, result);
          break;
        case "custom_validation":
          stepResult = await this.executeCustomValidation(step, result);
          break;
        default:
          throw new Error(`Unknown step type: ${step.type}`);
      }

      stepResult.stepType = step.type;
      stepResult.stepName = step.name || step.type;
      stepResult.duration = Date.now() - stepStart;
      stepResult.status = stepResult.status || "completed";

      console.log(chalk.green(`    ✅ ${stepResult.stepName} (${stepResult.duration}ms)`));

      return stepResult;
    } catch (error) {
      const stepResult = {
        stepType: step.type,
        stepName: step.name || step.type,
        status: "failed",
        error: error.message,
        duration: Date.now() - stepStart,
      };

      console.log(chalk.red(`    ❌ ${stepResult.stepName}: ${error.message}`));

      return stepResult;
    }
  }

  /**
   * Execute send message step
   */
  async executeSendMessage(step, result) {
    const targetProcess = result.processes.get(step.target);
    if (!targetProcess) {
      throw new Error(`Target process not found: ${step.target}`);
    }

    const message = {
      Action: step.action,
      Data: step.data || {},
      Tags: step.tags || {},
      ...step.messageExtras,
    };

    const response = await this.aoliteFramework.sendMessage(targetProcess.processId, message);

    // Log message for debugging
    result.messages.push({
      timestamp: Date.now(),
      from: "scenario-executor",
      to: step.target,
      action: step.action,
      response: response?.success || false,
    });

    return {
      messageId: response?.messageId || "unknown",
      response,
      targetProcess: step.target,
      action: step.action,
    };
  }

  /**
   * Execute wait for response step
   */
  async executeWaitForResponse(step, result) {
    const sourceProcess = result.processes.get(step.source);
    if (!sourceProcess) {
      throw new Error(`Source process not found: ${step.source}`);
    }

    const timeout = step.timeout || 5000;
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      // Check for messages from the source process
      const messages = await this.aoliteFramework.getProcessMessages(sourceProcess.processId);

      // Look for expected response
      const expectedResponse = messages.find(msg => msg.Action === step.expectedAction || step.responseFilter?.(msg));

      if (expectedResponse) {
        return {
          response: expectedResponse,
          waitTime: Date.now() - startTime,
          source: step.source,
        };
      }

      // Wait a bit before checking again
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    throw new Error(`Timeout waiting for response from ${step.source} (${timeout}ms)`);
  }

  /**
   * Execute validate state step
   */
  async executeValidateState(step, result) {
    const targetProcess = result.processes.get(step.target);
    if (!targetProcess) {
      throw new Error(`Target process not found: ${step.target}`);
    }

    // Get current process state
    const currentState = await this.aoliteFramework.getProcessState(targetProcess.processId);

    // Perform validation based on step configuration
    const validationResult = await this.performStateValidation(currentState, step);

    if (!validationResult.valid) {
      throw new Error(`State validation failed: ${validationResult.error}`);
    }

    return {
      validation: validationResult,
      currentState: currentState,
      target: step.target,
    };
  }

  /**
   * Execute multi-process interaction step
   */
  async executeMultiProcessInteraction(step, result) {
    const interactions = [];

    for (const interaction of step.interactions) {
      const sourceProcess = result.processes.get(interaction.from);
      const targetProcess = result.processes.get(interaction.to);

      if (!sourceProcess || !targetProcess) {
        throw new Error(`Process not found: ${interaction.from} or ${interaction.to}`);
      }

      // Send message and track response
      const message = {
        Action: interaction.action,
        Data: interaction.data || {},
        From: sourceProcess.processId,
      };

      const response = await this.aoliteFramework.sendMessage(targetProcess.processId, message);

      interactions.push({
        from: interaction.from,
        to: interaction.to,
        action: interaction.action,
        response: response?.success || false,
        responseTime: Date.now(),
      });

      // Log for debugging
      result.messages.push({
        timestamp: Date.now(),
        from: interaction.from,
        to: interaction.to,
        action: interaction.action,
        response: response?.success || false,
      });
    }

    return {
      interactions,
      totalInteractions: interactions.length,
      successfulInteractions: interactions.filter(i => i.response).length,
    };
  }

  /**
   * Execute battle simulation step
   */
  async executeBattleSimulation(step, result) {
    const battleEngine = result.processes.get("battle-engine") || result.processes.get("battle-logic");
    if (!battleEngine) {
      throw new Error("Battle engine process not found");
    }

    const battleConfig = step.battleConfig || {
      player1: { pokemon: [{ species: "Charizard", level: 50 }] },
      player2: { pokemon: [{ species: "Blastoise", level: 50 }] },
    };

    // Initialize battle
    const initResponse = await this.aoliteFramework.sendMessage(battleEngine.processId, {
      Action: "InitializeBattle",
      Data: battleConfig,
    });

    if (!initResponse?.success) {
      throw new Error("Failed to initialize battle");
    }

    // Simulate battle turns
    const turns = [];
    const maxTurns = step.maxTurns || 10;

    for (let turn = 1; turn <= maxTurns; turn++) {
      const turnAction = {
        Action: "ProcessTurn",
        Data: {
          turn,
          player1Action: step.player1Actions?.[turn - 1] || { type: "attack", moveIndex: 0 },
          player2Action: step.player2Actions?.[turn - 1] || { type: "attack", moveIndex: 0 },
        },
      };

      const turnResponse = await this.aoliteFramework.sendMessage(battleEngine.processId, turnAction);

      turns.push({
        turn,
        response: turnResponse?.success || false,
        result: turnResponse?.data,
      });

      // Check if battle ended
      if (turnResponse?.data?.battleEnded) {
        break;
      }
    }

    return {
      battleInitialized: initResponse.success,
      totalTurns: turns.length,
      turns,
      battleResult: turns[turns.length - 1]?.result,
    };
  }

  /**
   * Execute data consistency check step
   */
  async executeDataConsistencyCheck(step, result) {
    const checks = [];

    for (const check of step.checks) {
      const sourceProcess = result.processes.get(check.source);
      const targetProcess = result.processes.get(check.target);

      if (!sourceProcess || !targetProcess) {
        throw new Error(`Process not found for consistency check: ${check.source} or ${check.target}`);
      }

      // Query data from both processes
      const sourceData = await this.aoliteFramework.sendMessage(sourceProcess.processId, {
        Action: check.query,
        Data: check.queryData || {},
      });

      const targetData = await this.aoliteFramework.sendMessage(targetProcess.processId, {
        Action: check.query,
        Data: check.queryData || {},
      });

      // Compare results
      const isConsistent = this.compareData(sourceData?.data, targetData?.data, check.compareFields);

      checks.push({
        source: check.source,
        target: check.target,
        query: check.query,
        consistent: isConsistent,
        sourceData: sourceData?.data,
        targetData: targetData?.data,
      });
    }

    const inconsistentChecks = checks.filter(c => !c.consistent);
    if (inconsistentChecks.length > 0) {
      throw new Error(
        `Data inconsistency detected: ${inconsistentChecks.map(c => `${c.source}-${c.target}`).join(", ")}`,
      );
    }

    return {
      checks,
      totalChecks: checks.length,
      consistentChecks: checks.filter(c => c.consistent).length,
    };
  }

  /**
   * Execute performance validation step
   */
  async executePerformanceValidation(step, result) {
    const metrics = {};

    for (const metric of step.metrics) {
      const targetProcess = result.processes.get(metric.target);
      if (!targetProcess) {
        throw new Error(`Target process not found: ${metric.target}`);
      }

      const startTime = Date.now();

      // Send test message to measure response time
      const response = await this.aoliteFramework.sendMessage(targetProcess.processId, {
        Action: metric.action || "HealthCheck",
        Data: metric.data || {},
      });

      const responseTime = Date.now() - startTime;

      metrics[metric.target] = {
        responseTime,
        success: response?.success || false,
        threshold: metric.maxResponseTime || 1000,
        passed: responseTime <= (metric.maxResponseTime || 1000),
      };
    }

    const failedMetrics = Object.entries(metrics).filter(([_, metric]) => !metric.passed);
    if (failedMetrics.length > 0) {
      throw new Error(`Performance validation failed: ${failedMetrics.map(([name, _]) => name).join(", ")}`);
    }

    return {
      metrics,
      totalTargets: Object.keys(metrics).length,
      passedTargets: Object.values(metrics).filter(m => m.passed).length,
    };
  }

  /**
   * Execute error injection step
   */
  async executeErrorInjection(step, result) {
    const targetProcess = result.processes.get(step.target);
    if (!targetProcess) {
      throw new Error(`Target process not found: ${step.target}`);
    }

    // Inject error based on type
    let injectionResult;

    switch (step.errorType) {
      case "invalid_message":
        injectionResult = await this.injectInvalidMessage(targetProcess, step);
        break;
      case "timeout_simulation":
        injectionResult = await this.simulateTimeout(targetProcess, step);
        break;
      case "malformed_data":
        injectionResult = await this.injectMalformedData(targetProcess, step);
        break;
      default:
        throw new Error(`Unknown error injection type: ${step.errorType}`);
    }

    // Verify error handling
    const errorHandled = await this.verifyErrorHandling(targetProcess, step);

    return {
      errorType: step.errorType,
      injectionResult,
      errorHandled,
      target: step.target,
    };
  }

  /**
   * Execute custom validation step
   */
  async executeCustomValidation(step, result) {
    if (typeof step.validator !== "function") {
      throw new Error("Custom validation step requires validator function");
    }

    const validationContext = {
      processes: result.processes,
      messages: result.messages,
      aoliteFramework: this.aoliteFramework,
      scenario: step,
    };

    const validationResult = await step.validator(validationContext);

    if (!validationResult.valid) {
      throw new Error(`Custom validation failed: ${validationResult.error}`);
    }

    return validationResult;
  }

  /**
   * Validate scenario completion
   */
  async validateScenarioCompletion(scenario, result) {
    const validation = {
      success: true,
      checks: [],
      error: null,
    };

    try {
      // Check all processes are still responsive
      for (const [processName, process] of result.processes) {
        const healthCheck = await this.aoliteFramework.sendMessage(process.processId, {
          Action: "HealthCheck",
          Data: {},
        });

        validation.checks.push({
          check: `${processName} health`,
          passed: healthCheck?.success || false,
          details: healthCheck,
        });

        if (!healthCheck?.success) {
          validation.success = false;
        }
      }

      // Run scenario-specific validations
      if (scenario.finalValidation) {
        for (const check of scenario.finalValidation) {
          const checkResult = await this.runFinalValidationCheck(check, result);
          validation.checks.push(checkResult);

          if (!checkResult.passed) {
            validation.success = false;
          }
        }
      }

      if (!validation.success) {
        validation.error = "One or more validation checks failed";
      }
    } catch (error) {
      validation.success = false;
      validation.error = error.message;
    }

    return validation;
  }

  /**
   * Helper method to find process file
   */
  async findProcessFile(processName) {
    const possiblePaths = [
      path.join(process.cwd(), "processes", `${processName}.lua`),
      path.join(process.cwd(), "processes", processName),
      path.join(process.cwd(), "processes", `${processName}-process.lua`),
    ];

    for (const processPath of possiblePaths) {
      try {
        await fs.access(processPath);
        return processPath;
      } catch (_error) {
        // Continue to next path
      }
    }

    return null;
  }

  /**
   * Helper method to determine process type
   */
  determineProcessType(processName) {
    if (processName.includes("coordinator")) {
      return "coordinator";
    }
    if (
      processName.includes("data") ||
      processName.includes("species") ||
      processName.includes("move") ||
      processName.includes("item")
    ) {
      return "data";
    }
    return "logic";
  }

  /**
   * Helper method to get required handlers
   */
  getRequiredHandlers(processName) {
    const baseHandlers = ["Info", "HealthCheck"];

    if (processName.includes("coordinator")) {
      return [...baseHandlers, "ProcessLogic", "CoordinateAction"];
    }
    if (processName.includes("battle")) {
      return [...baseHandlers, "ProcessLogic", "BattleAction", "InitializeBattle"];
    }
    if (processName.includes("data")) {
      return [...baseHandlers, "QueryData"];
    }

    return [...baseHandlers, "ProcessLogic"];
  }

  /**
   * Helper method to get process dependencies
   */
  getProcessDependencies(processName) {
    if (processName.includes("battle")) {
      return ["pokemon-species-data", "move-data"];
    }
    if (processName.includes("coordinator")) {
      return [];
    }
    return [];
  }

  /**
   * Helper method to perform state validation
   */
  async performStateValidation(currentState, step) {
    // This is a simplified validation - real implementation would be more sophisticated
    if (step.expectedState) {
      const matches = this.deepCompare(currentState, step.expectedState);
      return {
        valid: matches,
        error: matches ? null : "State does not match expected state",
      };
    }

    if (step.stateValidator && typeof step.stateValidator === "function") {
      return step.stateValidator(currentState);
    }

    return { valid: true };
  }

  /**
   * Helper method to compare data
   */
  compareData(data1, data2, compareFields) {
    if (!compareFields) {
      return JSON.stringify(data1) === JSON.stringify(data2);
    }

    for (const field of compareFields) {
      if (data1?.[field] !== data2?.[field]) {
        return false;
      }
    }

    return true;
  }

  /**
   * Helper method for deep comparison
   */
  deepCompare(obj1, obj2) {
    return JSON.stringify(obj1) === JSON.stringify(obj2);
  }

  /**
   * Get execution summary
   */
  getExecutionSummary() {
    const total = this.executionResults.length;
    const passed = this.executionResults.filter(r => r.status === "passed").length;
    const failed = this.executionResults.filter(r => r.status === "failed").length;

    const totalDuration = this.executionResults.reduce((sum, r) => sum + r.duration, 0);
    const averageDuration = total > 0 ? totalDuration / total : 0;

    return {
      total,
      passed,
      failed,
      successRate: total > 0 ? (passed / total) * 100 : 0,
      totalDuration,
      averageDuration,
      executionResults: this.executionResults,
    };
  }

  /**
   * Cleanup scenario executor
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up scenario executor..."));

    await this.processDeployer.cleanup();
    await this.aoliteFramework.cleanup();

    this.executionResults = [];
    this.activeScenarios.clear();

    console.log(chalk.green("✅ Scenario executor cleanup completed"));
  }
}

export { ScenarioExecutor };
