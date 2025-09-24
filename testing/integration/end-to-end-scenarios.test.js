/**
 * End-to-End Scenario Tests
 * Comprehensive end-to-end testing for complete game workflows
 */

import fs from "fs/promises";
import path from "path";
import { afterAll, beforeAll, beforeEach, describe, expect, test } from "vitest";
import { IntegrationEnvironmentConfig } from "../../development-tools/integration-testing/environment-config.js";
import { ScenarioExecutor } from "../aos-local/scenario-executor.js";
import { scenarioConfigs, testScenarios, validationRules } from "../fixtures/test-scenarios.js";

describe("End-to-End Scenario Tests", () => {
  let scenarioExecutor;
  let environmentConfig;
  let tempDir;

  beforeAll(async () => {
    // Setup test environment
    tempDir = path.join(process.cwd(), "testing/aos-local/temp", `e2e-test-${Date.now()}`);
    await fs.mkdir(tempDir, { recursive: true });

    // Initialize environment
    environmentConfig = new IntegrationEnvironmentConfig({
      workspaceDir: tempDir,
    });

    scenarioExecutor = new ScenarioExecutor({
      tempDir,
      scenariosDir: path.join(tempDir, "scenarios"),
    });

    // Initialize components
    await environmentConfig.initializeEnvironment();
    await scenarioExecutor.initialize();

    // Create test process files for scenarios
    await createTestProcessFiles(tempDir);
  });

  afterAll(async () => {
    // Cleanup
    await scenarioExecutor?.cleanup();
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

  describe("Basic Process Communication", () => {
    test("should execute basic process communication scenario", async () => {
      const scenario = testScenarios.basicProcessCommunication;

      const result = await scenarioExecutor.executeScenario(scenario);

      expect(result.status).toBe("passed");
      expect(result.errors).toHaveLength(0);
      expect(result.steps).toHaveLength(3);
      expect(result.duration).toBeLessThan(scenario.timeout);

      // Verify all steps completed successfully
      const failedSteps = result.steps.filter(step => step.status === "failed");
      expect(failedSteps).toHaveLength(0);

      // Verify processes were deployed
      expect(result.processes.size).toBe(2);
      expect(result.processes.has("coordinator-process")).toBe(true);
      expect(result.processes.has("pokemon-species-data")).toBe(true);

      // Verify message flow occurred
      expect(result.messages.length).toBeGreaterThan(0);
      expect(result.messages.some(msg => msg.action === "QuerySpecies")).toBe(true);
    }, 45000);

    test("should handle communication timeouts gracefully", async () => {
      const timeoutScenario = {
        ...testScenarios.basicProcessCommunication,
        id: "timeout-test",
        steps: [
          {
            type: "send_message",
            target: "pokemon-species-data",
            action: "QuerySpecies",
            data: { speciesId: 1 },
          },
          {
            type: "wait_for_response",
            source: "pokemon-species-data",
            expectedAction: "NonExistentResponse", // This should timeout
            timeout: 2000, // Short timeout
          },
        ],
      };

      const result = await scenarioExecutor.executeScenario(timeoutScenario);

      expect(result.status).toBe("failed");
      expect(result.errors.some(error => error.includes("Timeout"))).toBe(true);
    }, 30000);
  });

  describe("Complete Game Workflow", () => {
    test("should execute complete game workflow scenario", async () => {
      const scenario = testScenarios.completeGameWorkflow;

      const result = await scenarioExecutor.executeScenario(scenario);

      expect(result.status).toBe("passed");
      expect(result.errors).toHaveLength(0);
      expect(result.duration).toBeLessThan(scenario.timeout);

      // Verify all required processes were deployed
      expect(result.processes.size).toBe(4);
      const expectedProcesses = ["coordinator-process", "pokemon-species-data", "move-data", "battle-engine"];
      for (const processName of expectedProcesses) {
        expect(result.processes.has(processName)).toBe(true);
      }

      // Verify battle simulation step
      const battleStep = result.steps.find(step => step.stepType === "battle_simulation");
      expect(battleStep).toBeDefined();
      expect(battleStep.status).toBe("completed");
      expect(battleStep.battleInitialized).toBe(true);
      expect(battleStep.totalTurns).toBeGreaterThan(0);

      // Verify data consistency check
      const consistencyStep = result.steps.find(step => step.stepType === "data_consistency_check");
      expect(consistencyStep).toBeDefined();
      expect(consistencyStep.status).toBe("completed");
      expect(consistencyStep.consistentChecks).toBe(consistencyStep.totalChecks);

      // Verify performance validation
      const performanceStep = result.steps.find(step => step.stepType === "performance_validation");
      expect(performanceStep).toBeDefined();
      expect(performanceStep.status).toBe("completed");
      expect(performanceStep.passedTargets).toBe(performanceStep.totalTargets);
    }, 90000);

    test("should maintain data consistency across multiple processes", async () => {
      const consistencyScenario = {
        id: "data-consistency-focus",
        name: "Data Consistency Focus",
        timeout: 30000,
        processes: ["coordinator-process", "pokemon-species-data", "move-data"],
        steps: [
          {
            type: "multi_process_interaction",
            name: "Query same data from multiple processes",
            interactions: [
              {
                from: "coordinator-process",
                to: "pokemon-species-data",
                action: "QuerySpecies",
                data: { speciesId: 6 }, // Charizard
              },
              {
                from: "coordinator-process",
                to: "move-data",
                action: "QueryMove",
                data: { moveId: 52 }, // Ember
              },
            ],
          },
          {
            type: "data_consistency_check",
            name: "Verify consistent data",
            checks: [
              {
                source: "pokemon-species-data",
                target: "move-data",
                query: "GetDataVersion",
                compareFields: ["version"],
              },
            ],
          },
        ],
      };

      const result = await scenarioExecutor.executeScenario(consistencyScenario);

      expect(result.status).toBe("passed");
      expect(result.validation.success).toBe(true);

      const consistencyStep = result.steps.find(step => step.stepType === "data_consistency_check");
      expect(consistencyStep.consistentChecks).toBe(consistencyStep.totalChecks);
    }, 45000);
  });

  describe("Error Handling Validation", () => {
    test("should handle and recover from errors gracefully", async () => {
      const scenario = testScenarios.errorHandlingValidation;

      const result = await scenarioExecutor.executeScenario(scenario);

      expect(result.status).toBe("passed");
      expect(result.duration).toBeLessThan(scenario.timeout);

      // Verify error injection steps were executed
      const errorSteps = result.steps.filter(step => step.stepType === "error_injection");
      expect(errorSteps.length).toBeGreaterThan(0);

      // Verify processes recovered from errors
      expect(result.validation.success).toBe(true);

      // Check that final messages were processed successfully after errors
      const finalMessageStep = result.steps.find(step => step.stepName === "Send valid message after errors");
      expect(finalMessageStep).toBeDefined();
      expect(finalMessageStep.status).toBe("completed");
    }, 60000);

    test("should maintain system stability during error injection", async () => {
      const stabilityScenario = {
        id: "stability-test",
        name: "System Stability Test",
        timeout: 25000,
        processes: ["coordinator-process", "pokemon-species-data"],
        steps: [
          // Send multiple invalid messages
          ...Array.from({ length: 5 }, (_, i) => ({
            type: "error_injection",
            name: `Error injection ${i + 1}`,
            target: "pokemon-species-data",
            errorType: "invalid_message",
            critical: false, // Don't fail scenario on these errors
          })),
          {
            type: "send_message",
            name: "Send valid message after errors",
            target: "pokemon-species-data",
            action: "HealthCheck",
            data: {},
          },
        ],
      };

      const result = await scenarioExecutor.executeScenario(stabilityScenario);

      expect(result.status).toBe("passed");

      // Verify the final valid message was processed successfully
      const finalStep = result.steps[result.steps.length - 1];
      expect(finalStep.status).toBe("completed");
    }, 40000);
  });

  describe("Performance Validation", () => {
    test("should meet performance requirements under load", async () => {
      const scenario = testScenarios.performanceStressTesting;

      const result = await scenarioExecutor.executeScenario(scenario);

      expect(result.status).toBe("passed");
      expect(result.duration).toBeLessThan(scenario.timeout);

      // Verify performance validation step
      const performanceStep = result.steps.find(step => step.stepType === "performance_validation");
      expect(performanceStep).toBeDefined();
      expect(performanceStep.status).toBe("completed");

      // Check response times are within limits
      for (const [_target, metrics] of Object.entries(performanceStep.metrics)) {
        expect(metrics.responseTime).toBeLessThan(metrics.threshold);
        expect(metrics.passed).toBe(true);
      }

      // Verify high-frequency interactions completed
      const interactionStep = result.steps.find(step => step.stepType === "multi_process_interaction");
      expect(interactionStep).toBeDefined();
      expect(interactionStep.successfulInteractions).toBeGreaterThan(40); // Most should succeed
    }, 180000);

    test("should validate memory usage remains within limits", async () => {
      const memoryScenario = {
        id: "memory-validation",
        name: "Memory Usage Validation",
        timeout: 20000,
        processes: ["coordinator-process", "pokemon-species-data", "move-data"],
        steps: [
          {
            type: "multi_process_interaction",
            name: "Load test data",
            interactions: Array.from({ length: 20 }, (_, i) => ({
              from: "coordinator-process",
              to: "pokemon-species-data",
              action: "QuerySpecies",
              data: { speciesId: i + 1 },
            })),
          },
          {
            type: "custom_validation",
            name: "Check memory usage",
            validator: async context => {
              const stats = await context.aoliteFramework.getStatistics();
              return {
                valid: stats.processCount <= 10, // Reasonable process count
                error: stats.processCount > 10 ? "Too many processes running" : null,
                details: { processCount: stats.processCount },
              };
            },
          },
        ],
      };

      const result = await scenarioExecutor.executeScenario(memoryScenario);

      expect(result.status).toBe("passed");

      const memoryStep = result.steps.find(step => step.stepName === "Check memory usage");
      expect(memoryStep.status).toBe("completed");
    }, 35000);
  });

  describe("Data Synchronization", () => {
    test("should maintain data synchronization across processes", async () => {
      const scenario = testScenarios.dataSynchronizationTest;

      const result = await scenarioExecutor.executeScenario(scenario);

      expect(result.status).toBe("passed");
      expect(result.duration).toBeLessThan(scenario.timeout);

      // Verify synchronization steps
      const syncStep = result.steps.find(step => step.stepName === "Synchronize initial data");
      expect(syncStep).toBeDefined();
      expect(syncStep.status).toBe("completed");

      // Verify data consistency checks passed
      const consistencySteps = result.steps.filter(step => step.stepType === "data_consistency_check");
      expect(consistencySteps.length).toBe(2);

      for (const step of consistencySteps) {
        expect(step.status).toBe("completed");
        expect(step.consistentChecks).toBe(step.totalChecks);
      }
    }, 60000);
  });

  describe("Scenario Configuration Execution", () => {
    test("should execute quick scenario configuration", async () => {
      const quickConfig = scenarioConfigs.quick;
      const results = [];

      for (const scenarioId of quickConfig.scenarios) {
        const scenario = testScenarios[scenarioId.replace(/-/g, "")];
        if (scenario) {
          const result = await scenarioExecutor.executeScenario(scenario);
          results.push(result);
        }
      }

      expect(results.length).toBe(quickConfig.scenarios.length);
      expect(results.every(r => r.status === "passed")).toBe(true);

      const totalDuration = results.reduce((sum, r) => sum + r.duration, 0);
      expect(totalDuration).toBeLessThan(quickConfig.timeout);
    }, 90000);

    test("should execute performance-focused scenario configuration", async () => {
      const performanceConfig = scenarioConfigs.performance;
      const results = [];

      for (const scenarioId of performanceConfig.scenarios) {
        const scenarioKey = scenarioId.replace(/-/g, "");
        const scenario = testScenarios[scenarioKey];
        if (scenario) {
          const result = await scenarioExecutor.executeScenario(scenario);
          results.push(result);

          // Verify performance criteria
          expect(result.duration).toBeLessThan(validationRules.performanceBaselines.scenarioExecutionTime * 3);
        }
      }

      expect(results.length).toBe(performanceConfig.scenarios.length);
      expect(results.filter(r => r.status === "passed").length).toBeGreaterThan(0);
    }, 240000);
  });

  describe("Scenario Execution Summary", () => {
    test("should provide comprehensive execution summary", async () => {
      // Execute a few scenarios to generate summary data
      const scenarios = [testScenarios.basicProcessCommunication, testScenarios.errorHandlingValidation];

      for (const scenario of scenarios) {
        await scenarioExecutor.executeScenario(scenario);
      }

      const summary = scenarioExecutor.getExecutionSummary();

      expect(summary.total).toBe(2);
      expect(summary.passed).toBeGreaterThan(0);
      expect(summary.successRate).toBeGreaterThan(0);
      expect(summary.totalDuration).toBeGreaterThan(0);
      expect(summary.averageDuration).toBeGreaterThan(0);
      expect(summary.executionResults).toHaveLength(2);
    }, 120000);
  });
});

/**
 * Create test process files for scenario testing
 */
async function createTestProcessFiles(_tempDir) {
  const processesDir = path.join(process.cwd(), "processes");
  await fs.mkdir(processesDir, { recursive: true });

  // Create minimal test processes for scenario testing
  const testProcesses = {
    "coordinator-process.lua": `
      Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "InfoResponse",
          Data = {
            name = "Test Coordinator Process",
            adpVersion = "1.0",
            handlers = ["ProcessLogic", "CoordinateAction", "Info", "HealthCheck"]
          }
        })
      end)

      Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "HealthResponse",
          Data = { status = "healthy" }
        })
      end)

      Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "Success",
          Data = { processed = true }
        })
      end)

      Handlers.add("CoordinateAction", Handlers.utils.hasMatchingTag("Action", "CoordinateAction"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "ActionCoordinated",
          Data = { coordinated = true }
        })
      end)
    `,

    "pokemon-species-data.lua": `
      Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "InfoResponse",
          Data = {
            name = "Test Pokemon Species Data",
            adpVersion = "1.0",
            handlers = ["QuerySpecies", "Info", "HealthCheck"]
          }
        })
      end)

      Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "HealthResponse",
          Data = { status = "healthy" }
        })
      end)

      Handlers.add("QuerySpecies", Handlers.utils.hasMatchingTag("Action", "QuerySpecies"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "SpeciesData",
          Data = { 
            speciesId = msg.Data.speciesId or 1,
            name = "Test Pokemon",
            types = {"Normal"}
          }
        })
      end)
    `,

    "move-data.lua": `
      Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "InfoResponse",
          Data = {
            name = "Test Move Data",
            adpVersion = "1.0",
            handlers = ["QueryMove", "Info", "HealthCheck"]
          }
        })
      end)

      Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "HealthResponse",
          Data = { status = "healthy" }
        })
      end)

      Handlers.add("QueryMove", Handlers.utils.hasMatchingTag("Action", "QueryMove"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "MoveData",
          Data = { 
            moveId = msg.Data.moveId or 1,
            name = "Test Move",
            power = 50
          }
        })
      end)
    `,

    "battle-engine.lua": `
      Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "InfoResponse",
          Data = {
            name = "Test Battle Engine",
            adpVersion = "1.0",
            handlers = ["InitializeBattle", "ProcessTurn", "Info", "HealthCheck"]
          }
        })
      end)

      Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "HealthResponse",
          Data = { status = "healthy" }
        })
      end)

      Handlers.add("InitializeBattle", Handlers.utils.hasMatchingTag("Action", "InitializeBattle"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "BattleInitialized",
          Data = { battleId = "test-battle-123" }
        })
      end)

      Handlers.add("ProcessTurn", Handlers.utils.hasMatchingTag("Action", "ProcessTurn"), function(msg)
        ao.send({
          Target = msg.From,
          Action = "TurnProcessed",
          Data = { 
            turn = msg.Data.turn or 1,
            battleEnded = (msg.Data.turn or 1) >= 3
          }
        })
      end)
    `,
  };

  for (const [filename, content] of Object.entries(testProcesses)) {
    const filePath = path.join(processesDir, filename);
    await fs.writeFile(filePath, content);
  }
}

// Shared utilities moved to testing/utils/test-helpers.js
