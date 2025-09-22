/**
 * Deployment Validation Tests
 * Comprehensive testing for process deployment validation
 */

import { describe, test, expect, beforeAll, afterAll, beforeEach, afterEach } from "@jest/globals";
import path from "path";
import fs from "fs/promises";
import { DeploymentTestRunner } from "../aos-local/deployment-test-runner.js";
import { ProcessDeployer } from "../aos-local/process-deployer.js";
import { ValidationFramework } from "../aos-local/validation-framework.js";
import { IntegrationEnvironmentConfig } from "../../development-tools/integration-testing/environment-config.js";
import { deploymentConfigs, testScenarios } from "../fixtures/deployment-configs.js";

describe("Deployment Validation Tests", () => {
  let deploymentRunner;
  let processDeployer;
  let validationFramework;
  let environmentConfig;
  let tempDir;

  beforeAll(async () => {
    // Setup test environment
    tempDir = path.join(process.cwd(), "testing/aos-local/temp", `deployment-test-${Date.now()}`);
    await fs.mkdir(tempDir, { recursive: true });

    // Initialize components
    environmentConfig = new IntegrationEnvironmentConfig({
      workspaceDir: tempDir
    });

    deploymentRunner = new DeploymentTestRunner({
      tempDir,
      processesDir: path.join(process.cwd(), "processes")
    });

    processDeployer = new ProcessDeployer({
      tempDir,
      processesDir: path.join(process.cwd(), "processes")
    });

    validationFramework = new ValidationFramework({
      strictMode: false,
      adpVersion: "1.0"
    });

    // Initialize environment
    await environmentConfig.initializeEnvironment();
    await deploymentRunner.initializeEnvironment();
    await processDeployer.initialize();
  });

  afterAll(async () => {
    // Cleanup
    await deploymentRunner?.cleanup();
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
    // Clear validation results before each test
    validationFramework.clearResults();
  });

  describe("Bundle Size Validation", () => {
    test("should validate process bundle size within limits", async () => {
      // Create test process file within size limit
      const testProcessPath = path.join(tempDir, "test-process-small.lua");
      const smallProcessContent = `
        -- Test process under size limit
        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = {
              name = "Test Process",
              version = "1.0.0",
              adpVersion = "1.0",
              capabilities = ["test"],
              handlers = ["Info"]
            }
          })
        end)
      `;

      await fs.writeFile(testProcessPath, smallProcessContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(true);
      expect(validation.validationResults.size.valid).toBe(true);
      expect(validation.validationResults.size.size).toBeLessThan(500000);
    }, 10000);

    test("should reject process bundle exceeding size limit", async () => {
      // Create test process file exceeding size limit
      const testProcessPath = path.join(tempDir, "test-process-large.lua");
      const largeContent = "-- Large process content\n".repeat(50000); // ~1MB
      
      await fs.writeFile(testProcessPath, largeContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(false);
      expect(validation.validationResults.size.valid).toBe(false);
      expect(validation.errors).toContain(expect.stringContaining("exceeds limit"));
    }, 10000);

    test("should warn when process approaches size limit", async () => {
      // Create test process file approaching size limit (90% of 500KB = 450KB)
      const testProcessPath = path.join(tempDir, "test-process-warning.lua");
      const warningContent = "-- Warning size content\n".repeat(22500); // ~450KB
      
      await fs.writeFile(testProcessPath, warningContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(true);
      expect(validation.validationResults.size.valid).toBe(true);
      expect(validation.warnings).toContain(expect.stringContaining("approaching limit"));
    }, 10000);
  });

  describe("AO Compatibility Validation", () => {
    test("should validate AO-compatible process structure", async () => {
      const testProcessPath = path.join(tempDir, "test-process-compatible.lua");
      const compatibleContent = `
        -- AO Compatible Process
        Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
          local success, result = pcall(function()
            -- Process logic here
            return { status = "success" }
          end)
          
          if success then
            ao.send({
              Target = msg.From,
              Action = "Success",
              Data = result
            })
          else
            ao.send({
              Target = msg.From,
              Action = "Error",
              Error = result
            })
          end
        end)

        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = {
              name = "Compatible Process",
              adpVersion = "1.0",
              capabilities = ["ProcessLogic"],
              handlers = ["ProcessLogic", "Info"]
            }
          })
        end)
      `;

      await fs.writeFile(testProcessPath, compatibleContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(true);
      expect(validation.validationResults.aoCompatibility.valid).toBe(true);
      expect(validation.validationResults.aoCompatibility.forbiddenPatternMatches).toHaveLength(0);
    }, 10000);

    test("should reject process with forbidden patterns", async () => {
      const testProcessPath = path.join(tempDir, "test-process-incompatible.lua");
      const incompatibleContent = `
        -- Incompatible Process
        local utils = require('utils') -- Forbidden: require()
        local time = os.time() -- Forbidden: os.time()
        
        Handlers["ProcessLogic"] = function(msg) -- Wrong pattern
          io.write("test") -- Forbidden: io operations
        end
      `;

      await fs.writeFile(testProcessPath, incompatibleContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(false);
      expect(validation.validationResults.aoCompatibility.valid).toBe(false);
      expect(validation.validationResults.aoCompatibility.forbiddenPatternMatches.length).toBeGreaterThan(0);
      expect(validation.errors).toContain(expect.stringContaining("require()"));
    }, 10000);

    test("should detect missing required patterns", async () => {
      const testProcessPath = path.join(tempDir, "test-process-missing-patterns.lua");
      const missingPatternsContent = `
        -- Process missing required patterns
        function processMessage(msg)
          -- Missing Handlers.add() and ao.send()
          print("Processing message")
        end
      `;

      await fs.writeFile(testProcessPath, missingPatternsContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(false);
      expect(validation.validationResults.aoCompatibility.valid).toBe(false);
      expect(validation.errors).toContain(expect.stringContaining("Handlers.add()"));
      expect(validation.errors).toContain(expect.stringContaining("ao.send"));
    }, 10000);
  });

  describe("Handler Registration Verification", () => {
    test("should verify required handlers are registered", async () => {
      const testProcessPath = path.join(tempDir, "test-process-handlers.lua");
      const handlersContent = `
        Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
          ao.send({ Target = msg.From, Action = "Success" })
        end)

        Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
          ao.send({ Target = msg.From, Action = "Healthy" })
        end)

        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = {
              handlers = ["ProcessLogic", "HealthCheck", "Info"],
              adpVersion = "1.0"
            }
          })
        end)
      `;

      await fs.writeFile(testProcessPath, handlersContent);

      const config = { requiredHandlers: ["ProcessLogic", "HealthCheck", "Info"] };
      const validation = await validationFramework.validateProcessBundle(testProcessPath, config);

      expect(validation.overallValid).toBe(true);
      expect(validation.validationResults.handlerPatterns.valid).toBe(true);
      expect(validation.validationResults.handlerPatterns.foundHandlers).toEqual(
        expect.arrayContaining(["ProcessLogic", "HealthCheck", "Info"])
      );
      expect(validation.validationResults.handlerPatterns.missingHandlers).toHaveLength(0);
    }, 10000);

    test("should detect missing required handlers", async () => {
      const testProcessPath = path.join(tempDir, "test-process-missing-handlers.lua");
      const missingHandlersContent = `
        Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
          ao.send({ Target = msg.From, Action = "Success" })
        end)
        -- Missing: HealthCheck and Info handlers
      `;

      await fs.writeFile(testProcessPath, missingHandlersContent);

      const config = { requiredHandlers: ["ProcessLogic", "HealthCheck", "Info"] };
      const validation = await validationFramework.validateProcessBundle(testProcessPath, config);

      expect(validation.overallValid).toBe(false);
      expect(validation.validationResults.handlerPatterns.valid).toBe(false);
      expect(validation.validationResults.handlerPatterns.missingHandlers).toEqual(
        expect.arrayContaining(["HealthCheck", "Info"])
      );
    }, 10000);
  });

  describe("ADP v1.0 Compliance Validation", () => {
    test("should validate ADP v1.0 compliant process", async () => {
      const testProcessPath = path.join(tempDir, "test-process-adp-compliant.lua");
      const adpCompliantContent = `
        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
              process = {
                name = "ADP Compliant Process",
                version = "1.0.0",
                adpVersion = "1.0",
                capabilities = ["ProcessLogic", "DataQuery"],
                messageSchemas = {
                  ProcessLogic = {
                    required = {"Action", "Data"}
                  }
                }
              },
              handlers = ["ProcessLogic", "Info"],
              documentation = {
                adpCompliance = "v1.0",
                selfDocumenting = true
              }
            }
          })
        end)

        Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
          ao.send({ Target = msg.From, Action = "Success" })
        end)
      `;

      await fs.writeFile(testProcessPath, adpCompliantContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(true);
      expect(validation.validationResults.adpCompliance.valid).toBe(true);
      expect(validation.validationResults.adpCompliance.foundStructures).toEqual(
        expect.arrayContaining(["adpVersion", "capabilities", "messageSchemas", "handlers"])
      );
    }, 10000);

    test("should detect missing ADP compliance structures", async () => {
      const testProcessPath = path.join(tempDir, "test-process-adp-non-compliant.lua");
      const nonCompliantContent = `
        Handlers.add("ProcessLogic", Handlers.utils.hasMatchingTag("Action", "ProcessLogic"), function(msg)
          ao.send({ Target = msg.From, Action = "Success" })
        end)
        -- Missing: Info handler and ADP structures
      `;

      await fs.writeFile(testProcessPath, nonCompliantContent);

      const validation = await validationFramework.validateProcessBundle(testProcessPath);

      expect(validation.overallValid).toBe(false);
      expect(validation.validationResults.adpCompliance.valid).toBe(false);
      expect(validation.errors).toContain(expect.stringContaining("ADP"));
    }, 10000);
  });

  describe("Deployment Success Validation", () => {
    test("should successfully deploy valid process", async () => {
      // Create a minimal valid process for deployment testing
      const testProcessPath = path.join(tempDir, "test-deployment-valid.lua");
      const validProcessContent = `
        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = {
              name = "Valid Deployment Process",
              adpVersion = "1.0",
              handlers = ["Info", "HealthCheck"]
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
      `;

      await fs.writeFile(testProcessPath, validProcessContent);

      const config = {
        processType: "test",
        processPath: testProcessPath,
        maxSize: 500000,
        requiredHandlers: ["Info", "HealthCheck"]
      };

      const deploymentResult = await processDeployer.deploySingleProcess(config);

      expect(deploymentResult.status).toBe("deployed");
      expect(deploymentResult.processId).toBeDefined();
      expect(deploymentResult.validation.success).toBe(true);
      expect(deploymentResult.verification.success).toBe(true);
    }, 15000);

    test("should fail deployment for invalid process", async () => {
      // Create an invalid process for deployment failure testing
      const testProcessPath = path.join(tempDir, "test-deployment-invalid.lua");
      const invalidProcessContent = `
        -- Invalid process: missing required patterns and too large
        local utils = require('invalid-module')
        ${"-- Large content padding\n".repeat(30000)}
      `;

      await fs.writeFile(testProcessPath, invalidProcessContent);

      const config = {
        processType: "test",
        processPath: testProcessPath,
        maxSize: 500000,
        requiredHandlers: ["Info"]
      };

      const deploymentResult = await processDeployer.deploySingleProcess(config);

      expect(deploymentResult.status).toBe("failed");
      expect(deploymentResult.error).toBeDefined();
      expect(deploymentResult.processId).toBeNull();
    }, 15000);
  });

  describe("Deployment Rollback Capabilities", () => {
    test("should handle deployment rollback on failure", async () => {
      // This test simulates a deployment that succeeds initially but fails verification
      const testProcessPath = path.join(tempDir, "test-rollback.lua");
      const processContent = `
        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          -- Simulate process that deploys but fails verification
          error("Verification failure simulation")
        end)
      `;

      await fs.writeFile(testProcessPath, processContent);

      const config = {
        processType: "test",
        processPath: testProcessPath,
        maxSize: 500000,
        requiredHandlers: ["Info"]
      };

      const deploymentResult = await processDeployer.deploySingleProcess(config);

      // Should fail and not leave process in deployed state
      expect(deploymentResult.status).toBe("failed");
      expect(processDeployer.getDeploymentStatus().deployedProcesses).toBe(0);
    }, 15000);
  });

  describe("Performance Metrics Validation", () => {
    test("should measure deployment time performance", async () => {
      const testProcessPath = path.join(tempDir, "test-performance.lua");
      const processContent = `
        Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
          ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = { name = "Performance Test Process", adpVersion = "1.0" }
          })
        end)
      `;

      await fs.writeFile(testProcessPath, processContent);

      const config = {
        processType: "test",
        processPath: testProcessPath,
        maxSize: 500000,
        requiredHandlers: ["Info"],
        performance: {
          maxDeploymentTime: 5000 // 5 seconds
        }
      };

      const startTime = Date.now();
      const deploymentResult = await processDeployer.deploySingleProcess(config);
      const actualDeploymentTime = Date.now() - startTime;

      expect(deploymentResult.status).toBe("deployed");
      expect(deploymentResult.deploymentTime).toBeLessThan(config.performance.maxDeploymentTime);
      expect(actualDeploymentTime).toBeLessThan(10000); // Reasonable upper bound
    }, 15000);
  });

  describe("Validation Report Generation", () => {
    test("should generate comprehensive validation reports", async () => {
      // Run deployment tests and generate reports
      const configs = [
        {
          processType: "test1",
          processPath: path.join(tempDir, "report-test-1.lua"),
          maxSize: 500000,
          requiredHandlers: ["Info"]
        },
        {
          processType: "test2", 
          processPath: path.join(tempDir, "report-test-2.lua"),
          maxSize: 500000,
          requiredHandlers: ["Info"]
        }
      ];

      // Create test processes
      for (const config of configs) {
        const content = `
          Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
            ao.send({
              Target = msg.From,
              Action = "InfoResponse",
              Data = { name = "${config.processType}", adpVersion = "1.0" }
            })
          end)
        `;
        await fs.writeFile(config.processPath, content);
      }

      // Run deployments
      const results = await processDeployer.deployMultipleProcesses(configs);

      // Generate deployment report
      await deploymentRunner.generateDeploymentReport();

      // Verify report generation
      expect(results).toHaveLength(2);
      expect(results.every(r => r.status === "deployed")).toBe(true);

      // Check if report files were created
      const reportsDir = path.join(process.cwd(), "testing/reports");
      const reportFiles = await fs.readdir(reportsDir);
      const deploymentReports = reportFiles.filter(f => f.includes("deployment-validation"));
      
      expect(deploymentReports.length).toBeGreaterThan(0);
    }, 20000);
  });
});

// Export for use in other test files
export {
  DeploymentTestRunner,
  ProcessDeployer,
  ValidationFramework,
  IntegrationEnvironmentConfig
};