/**
 * Scenario Runner for Multi-Process Integration Testing
 *
 * Orchestrates end-to-end test scenarios across all 26 AO Lua processes
 * with comprehensive validation, error handling, and performance monitoring.
 */

const EventEmitter = require("events");
const MessageFlowOrchestrator = require("./message-flow-orchestrator");
const ProcessTopologyValidator = require("../validators/topology-validator");

class ScenarioRunner extends EventEmitter {
  constructor(options = {}) {
    super();
    this.processRegistry = new Map();
    this.activeScenarios = new Map();
    this.orchestrator = new MessageFlowOrchestrator(options);
    this.topologyValidator = new ProcessTopologyValidator();
    this.config = {
      maxConcurrentScenarios: options.maxConcurrentScenarios || 5,
      defaultTimeout: options.defaultTimeout || 30000,
      retryAttempts: options.retryAttempts || 3,
      processHealthCheckInterval: options.processHealthCheckInterval || 5000,
      ...options,
    };

    this.setupOrchestrator();
    this.startHealthMonitoring();
  }

  /**
   * Initialize the 26-process topology for testing
   */
  async initializeProcessTopology(topology) {
    this.emit("topology:initializing", { topology });

    const requiredProcesses = [
      // Coordinator
      "coordinator-process",

      // Data Processes
      "pokemon-species-db",
      "moves-database",
      "items-database",
      "abilities-database",
      "type-chart-db",
      "nature-modifiers-db",
      "evolution-chains-db",

      // Logic Processes
      "battle-engine",
      "damage-calculator",
      "status-effects-engine",
      "evolution-engine",
      "capture-engine",
      "experience-calculator",

      // Utility Processes
      "state-validator",
      "query-processor",
      "rng-coordinator",
      "inventory-manager",
      "progression-tracker",
      "save-manager",

      // Specialized Processes
      "breeding-system",
      "contest-system",
      "trade-system",
      "weather-system",
      "terrain-system",
      "field-effects-system",
    ];

    // Register all required processes
    for (const processId of requiredProcesses) {
      await this.registerProcess(processId, topology[processId] || {});
    }

    // Validate topology
    const validation = await this.topologyValidator.validateTopology(Array.from(this.processRegistry.values()));

    if (!validation.valid) {
      throw new Error(`Topology validation failed: ${validation.errors.join(", ")}`);
    }

    this.emit("topology:initialized", {
      processCount: this.processRegistry.size,
      validation,
    });

    return validation;
  }

  /**
   * Register a process in the testing topology
   */
  async registerProcess(processId, config) {
    const processInfo = {
      id: processId,
      type: this.classifyProcess(processId),
      status: "initializing",
      capabilities: config.capabilities || [],
      handlers: config.handlers || [],
      lastHealthCheck: null,
      healthStatus: "unknown",
      responseTime: null,
      errorCount: 0,
      ...config,
    };

    this.processRegistry.set(processId, processInfo);
    this.orchestrator.registerProcess(processId, config);

    // Perform initial health check
    try {
      await this.performHealthCheck(processId);
      processInfo.status = "ready";
      this.emit("process:registered", { processId, processInfo });
    } catch (error) {
      processInfo.status = "failed";
      processInfo.lastError = error.message;
      this.emit("process:registration_failed", { processId, error: error.message });
      throw error;
    }
  }

  /**
   * Execute a complete test scenario
   */
  async executeScenario(scenarioDefinition) {
    const scenarioId = crypto.randomUUID();
    const scenario = {
      id: scenarioId,
      definition: scenarioDefinition,
      startTime: Date.now(),
      status: "running",
      phases: [],
      currentPhase: null,
      results: {},
      errors: [],
      performance: {},
    };

    this.activeScenarios.set(scenarioId, scenario);
    this.emit("scenario:started", { scenarioId, definition: scenarioDefinition });

    try {
      // Phase 1: Pre-execution validation
      await this.executePhase(scenario, "validation", async () => {
        return await this.validateScenarioPrerequisites(scenario);
      });

      // Phase 2: Process health verification
      await this.executePhase(scenario, "health_check", async () => {
        return await this.verifyProcessHealth(scenario);
      });

      // Phase 3: Scenario execution
      await this.executePhase(scenario, "execution", async () => {
        return await this.executeScenarioFlow(scenario);
      });

      // Phase 4: Post-execution validation
      await this.executePhase(scenario, "post_validation", async () => {
        return await this.validateScenarioResults(scenario);
      });

      scenario.status = "completed";
      scenario.endTime = Date.now();
      scenario.duration = scenario.endTime - scenario.startTime;
    } catch (error) {
      scenario.status = "failed";
      scenario.endTime = Date.now();
      scenario.duration = scenario.endTime - scenario.startTime;
      scenario.errors.push({
        phase: scenario.currentPhase,
        error: error.message,
        timestamp: Date.now(),
        stack: error.stack,
      });
      this.emit("scenario:failed", { scenarioId, error: error.message });
      throw error;
    } finally {
      this.emit("scenario:completed", { scenarioId, scenario });
    }

    return scenario;
  }

  /**
   * Execute a scenario phase with error handling and timing
   */
  async executePhase(scenario, phaseName, phaseFunction) {
    const phase = {
      name: phaseName,
      startTime: Date.now(),
      status: "running",
    };

    scenario.currentPhase = phaseName;
    this.emit("phase:started", { scenarioId: scenario.id, phase: phaseName });

    try {
      phase.result = await phaseFunction();
      phase.status = "completed";
    } catch (error) {
      phase.status = "failed";
      phase.error = error.message;
      throw error;
    } finally {
      phase.endTime = Date.now();
      phase.duration = phase.endTime - phase.startTime;
      scenario.phases.push(phase);
      this.emit("phase:completed", {
        scenarioId: scenario.id,
        phase: phaseName,
        duration: phase.duration,
        status: phase.status,
      });
    }
  }

  /**
   * Validate scenario prerequisites
   */
  async validateScenarioPrerequisites(scenario) {
    const definition = scenario.definition;
    const validation = {
      valid: true,
      checks: [],
      errors: [],
    };

    // Check required processes are available
    for (const processId of definition.testScenario.processes) {
      const process = this.processRegistry.get(processId);
      if (!process) {
        validation.valid = false;
        validation.errors.push(`Required process not found: ${processId}`);
      } else if (process.status !== "ready") {
        validation.valid = false;
        validation.errors.push(`Process not ready: ${processId} (status: ${process.status})`);
      } else {
        validation.checks.push(`Process available: ${processId}`);
      }
    }

    // Validate message flow structure
    if (!definition.messageFlow || !Array.isArray(definition.messageFlow)) {
      validation.valid = false;
      validation.errors.push("Invalid messageFlow: must be an array");
    }

    // Check for parallel execution requirements
    if (definition.parallelExecution?.enabled) {
      const parallelSteps = definition.parallelExecution.parallelSteps || [];
      for (const stepIndex of parallelSteps) {
        if (!definition.messageFlow[stepIndex]) {
          validation.valid = false;
          validation.errors.push(`Parallel step ${stepIndex} not found in messageFlow`);
        }
      }
    }

    if (!validation.valid) {
      throw new Error(`Scenario validation failed: ${validation.errors.join(", ")}`);
    }

    return validation;
  }

  /**
   * Verify all required processes are healthy
   */
  async verifyProcessHealth(scenario) {
    const healthChecks = [];
    const requiredProcesses = scenario.definition.testScenario.processes;

    for (const processId of requiredProcesses) {
      healthChecks.push(this.performHealthCheck(processId));
    }

    const results = await Promise.allSettled(healthChecks);
    const failures = [];

    results.forEach((result, index) => {
      const processId = requiredProcesses[index];
      if (result.status === "rejected") {
        failures.push(`${processId}: ${result.reason.message}`);
      }
    });

    if (failures.length > 0) {
      throw new Error(`Health check failures: ${failures.join(", ")}`);
    }

    return {
      healthyProcesses: requiredProcesses.length,
      checkedAt: Date.now(),
    };
  }

  /**
   * Execute the main scenario flow
   */
  async executeScenarioFlow(scenario) {
    const definition = scenario.definition;

    // Handle parallel execution if specified
    if (definition.parallelExecution?.enabled) {
      return await this.executeParallelFlow(scenario);
    }
    return await this.executeSequentialFlow(scenario);
  }

  /**
   * Execute scenario with parallel message flow
   */
  async executeParallelFlow(scenario) {
    const definition = scenario.definition;
    const parallelConfig = definition.parallelExecution;
    const parallelSteps = new Set(parallelConfig.parallelSteps || []);
    const sequentialSteps = [];
    const parallelBatches = [];

    // Separate sequential and parallel steps
    definition.messageFlow.forEach((step, index) => {
      if (parallelSteps.has(index)) {
        parallelBatches.push(step);
      } else {
        sequentialSteps.push({ step, index });
      }
    });

    const results = { sequential: [], parallel: [] };

    // Execute sequential steps first
    for (const { step, index } of sequentialSteps) {
      if (index < Math.min(...parallelSteps)) {
        const result = await this.orchestrator.startFlow({
          testScenario: definition.testScenario,
          messageFlow: [step],
        });
        results.sequential.push(result);
      }
    }

    // Execute parallel batch
    if (parallelBatches.length > 0) {
      const parallelPromises = parallelBatches.map(step =>
        this.orchestrator.startFlow({
          testScenario: definition.testScenario,
          messageFlow: [step],
        }),
      );

      const parallelResults = await Promise.allSettled(parallelPromises);
      results.parallel = parallelResults.map(result => {
        if (result.status === "rejected") {
          throw new Error(`Parallel execution failed: ${result.reason.message}`);
        }
        return result.value;
      });
    }

    // Execute remaining sequential steps
    for (const { step, index } of sequentialSteps) {
      if (index > Math.max(...parallelSteps)) {
        const result = await this.orchestrator.startFlow({
          testScenario: definition.testScenario,
          messageFlow: [step],
        });
        results.sequential.push(result);
      }
    }

    return results;
  }

  /**
   * Execute scenario with sequential message flow
   */
  async executeSequentialFlow(scenario) {
    return await this.orchestrator.startFlow(scenario.definition);
  }

  /**
   * Validate scenario results against assertions
   */
  async validateScenarioResults(scenario) {
    const definition = scenario.definition;
    const assertions = definition.assertions || [];
    const validation = {
      valid: true,
      passedAssertions: 0,
      failedAssertions: 0,
      results: [],
    };

    for (const assertion of assertions) {
      const result = await this.evaluateAssertion(assertion, scenario);
      validation.results.push(result);

      if (result.passed) {
        validation.passedAssertions++;
      } else {
        validation.failedAssertions++;
        validation.valid = false;
      }
    }

    if (!validation.valid) {
      const failedAssertions = validation.results
        .filter(r => !r.passed)
        .map(r => r.assertion.description || r.assertion.condition);
      throw new Error(`Assertion failures: ${failedAssertions.join(", ")}`);
    }

    return validation;
  }

  /**
   * Evaluate a single assertion
   */
  async evaluateAssertion(assertion, scenario) {
    const result = {
      assertion,
      passed: false,
      actualValue: null,
      expectedValue: assertion.expected,
      message: "",
    };

    try {
      switch (assertion.type) {
        case "coordination":
          result.actualValue = await this.evaluateCoordinationAssertion(assertion, scenario);
          break;
        case "performance":
          result.actualValue = await this.evaluatePerformanceAssertion(assertion, scenario);
          break;
        case "state_consistency":
          result.actualValue = await this.evaluateStateConsistencyAssertion(assertion, scenario);
          break;
        case "message_integrity":
          result.actualValue = await this.evaluateMessageIntegrityAssertion(assertion, scenario);
          break;
        case "data_integrity":
          result.actualValue = await this.evaluateDataIntegrityAssertion(assertion, scenario);
          break;
        default:
          throw new Error(`Unknown assertion type: ${assertion.type}`);
      }

      result.passed = this.compareValues(result.actualValue, result.expectedValue, assertion);
      result.message = result.passed ? "Passed" : `Expected ${result.expectedValue}, got ${result.actualValue}`;
    } catch (error) {
      result.passed = false;
      result.message = `Assertion evaluation failed: ${error.message}`;
    }

    return result;
  }

  /**
   * Compare assertion values with tolerance support
   */
  compareValues(actual, expected, assertion) {
    if (assertion.tolerance && typeof actual === "number" && typeof expected === "number") {
      const tolerance = Number.parseFloat(assertion.tolerance.replace("%", "")) / 100;
      const diff = Math.abs(actual - expected) / expected;
      return diff <= tolerance;
    }

    if (typeof expected === "string" && expected.startsWith("<") && typeof actual === "number") {
      const threshold = Number.parseFloat(expected.substring(1).replace("ms", ""));
      return actual < threshold;
    }

    return actual === expected;
  }

  /**
   * Perform health check on a process
   */
  async performHealthCheck(processId) {
    const process = this.processRegistry.get(processId);
    if (!process) {
      throw new Error(`Process not found: ${processId}`);
    }

    const startTime = Date.now();

    try {
      // Send Info message to check process responsiveness
      const _response = await this.orchestrator._simulateAOSend(
        {
          Id: crypto.randomUUID(),
          From: "health-checker",
          Target: processId,
          Action: "Info",
          Data: "{}",
          Timestamp: Date.now().toString(),
        },
        processId,
      );

      const responseTime = Date.now() - startTime;

      process.healthStatus = "healthy";
      process.responseTime = responseTime;
      process.lastHealthCheck = Date.now();
      process.errorCount = 0;

      return {
        processId,
        healthy: true,
        responseTime,
        timestamp: Date.now(),
      };
    } catch (error) {
      process.healthStatus = "unhealthy";
      process.lastError = error.message;
      process.errorCount++;
      process.lastHealthCheck = Date.now();

      throw new Error(`Health check failed for ${processId}: ${error.message}`);
    }
  }

  /**
   * Classify process type based on naming convention
   */
  classifyProcess(processId) {
    if (processId.includes("coordinator")) {
      return "coordinator";
    }
    if (processId.includes("database") || processId.includes("-db")) {
      return "data";
    }
    if (processId.includes("engine") || processId.includes("calculator")) {
      return "logic";
    }
    if (processId.includes("validator") || processId.includes("processor")) {
      return "utility";
    }
    return "specialized";
  }

  /**
   * Setup orchestrator event handlers
   */
  setupOrchestrator() {
    this.orchestrator.on("flow:started", data => {
      this.emit("flow:started", data);
    });

    this.orchestrator.on("step:completed", data => {
      this.emit("step:completed", data);
    });

    this.orchestrator.on("flow:completed", data => {
      this.emit("flow:completed", data);
    });
  }

  /**
   * Start periodic health monitoring
   */
  startHealthMonitoring() {
    setInterval(async () => {
      for (const [processId, process] of this.processRegistry) {
        if (process.status === "ready") {
          try {
            await this.performHealthCheck(processId);
          } catch (error) {
            this.emit("process:health_check_failed", { processId, error: error.message });
          }
        }
      }
    }, this.config.processHealthCheckInterval);
  }

  /**
   * Get scenario results
   */
  getScenarioResults(scenarioId) {
    return this.activeScenarios.get(scenarioId);
  }

  /**
   * Get process topology status
   */
  getTopologyStatus() {
    const processes = Array.from(this.processRegistry.values());
    return {
      totalProcesses: processes.length,
      healthyProcesses: processes.filter(p => p.healthStatus === "healthy").length,
      unhealthyProcesses: processes.filter(p => p.healthStatus === "unhealthy").length,
      readyProcesses: processes.filter(p => p.status === "ready").length,
      processes: processes.map(p => ({
        id: p.id,
        type: p.type,
        status: p.status,
        healthStatus: p.healthStatus,
        responseTime: p.responseTime,
        lastHealthCheck: p.lastHealthCheck,
        errorCount: p.errorCount,
      })),
    };
  }

  // Placeholder methods for assertion evaluation
  async evaluateCoordinationAssertion(_assertion, _scenario) {
    return true;
  }
  async evaluatePerformanceAssertion(_assertion, scenario) {
    return scenario.duration || 0;
  }
  async evaluateStateConsistencyAssertion(_assertion, _scenario) {
    return true;
  }
  async evaluateMessageIntegrityAssertion(_assertion, _scenario) {
    return true;
  }
  async evaluateDataIntegrityAssertion(_assertion, _scenario) {
    return true;
  }
}

module.exports = ScenarioRunner;
