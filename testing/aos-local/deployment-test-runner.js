/**
 * Deployment Test Runner
 * Enhanced deployment testing for comprehensive validation using aolite
 * Validates process deployment, bundling, and AO environment compatibility
 */

import { spawn } from "child_process";
import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { AoliteFramework } from "../aolite/aolite-framework.js";

export class DeploymentTestRunner {
  constructor(options = {}) {
    this.processesDir = options.processesDir || path.join(process.cwd(), "processes");
    this.aoliteDir = options.aoliteDir || path.join(process.cwd(), "development-tools/aolite");
    this.tempDir = options.tempDir || path.join(process.cwd(), "testing/aos-local/temp");
    this.reportsDir = options.reportsDir || path.join(process.cwd(), "testing/reports");
    this.aoliteFramework = new AoliteFramework();
    this.deploymentResults = [];
    this.performanceMetrics = new Map();
  }

  /**
   * Initialize deployment testing environment
   */
  async initializeEnvironment() {
    console.log(chalk.blue("🔧 Initializing deployment testing environment..."));

    // Ensure directories exist
    await fs.mkdir(this.tempDir, { recursive: true });
    await fs.mkdir(this.reportsDir, { recursive: true });

    // Validate aolite availability
    try {
      await this.aoliteFramework.initialize();
      console.log(chalk.green("✅ aolite framework initialized"));
    } catch (error) {
      throw new Error(`aolite initialization failed: ${error.message}`);
    }

    // Setup environment variables
    this.setupEnvironmentConfig();

    console.log(chalk.green("✅ Deployment testing environment ready"));
  }

  /**
   * Setup environment configuration for deployment testing
   */
  setupEnvironmentConfig() {
    // Configure aolite for deployment testing
    process.env.AOLITE_LOG_LEVEL = "2"; // Enhanced logging
    process.env.AOLITE_TIMEOUT = "10000"; // 10 second timeout
    process.env.AOLITE_MEMORY_LIMIT = "512"; // 512MB memory limit
    process.env.AOLITE_PROCESS_LIMIT = "26"; // Support for all 26 processes

    console.log(chalk.blue("📝 Environment configuration set:"));
    console.log(`  Log Level: ${process.env.AOLITE_LOG_LEVEL}`);
    console.log(`  Timeout: ${process.env.AOLITE_TIMEOUT}ms`);
    console.log(`  Memory Limit: ${process.env.AOLITE_MEMORY_LIMIT}MB`);
    console.log(`  Process Limit: ${process.env.AOLITE_PROCESS_LIMIT}`);
  }

  /**
   * Load deployment configuration templates
   */
  async loadDeploymentTemplates() {
    const templatesPath = path.join(this.tempDir, "deployment-configs.json");
    
    const defaultTemplates = {
      coordinatorProcess: {
        processType: "coordinator",
        processPath: "./processes/coordinator-process.lua",
        maxSize: 500000, // 500KB
        requiredHandlers: ["ProcessLogic", "HealthCheck", "Info"],
        dependencies: [],
        performance: {
          maxInitTime: 2000, // 2s
          maxResponseTime: 1000, // 1s
          minMemoryEfficiency: 0.8
        }
      },
      dataProcess: {
        processType: "data",
        processPath: "./processes/pokemon-species-data.lua",
        maxSize: 450000, // 450KB (smaller for data processes)
        requiredHandlers: ["QueryData", "HealthCheck", "Info"],
        dependencies: [],
        performance: {
          maxInitTime: 1500, // 1.5s
          maxResponseTime: 500, // 0.5s
          minMemoryEfficiency: 0.9
        }
      },
      logicProcess: {
        processType: "logic",
        processPath: "./processes/battle-engine.lua",
        maxSize: 500000, // 500KB (max for logic processes)
        requiredHandlers: ["ProcessLogic", "BattleAction", "HealthCheck", "Info"],
        dependencies: ["pokemon-species-data", "move-data"],
        performance: {
          maxInitTime: 3000, // 3s
          maxResponseTime: 2000, // 2s
          minMemoryEfficiency: 0.7
        }
      }
    };

    await fs.writeFile(templatesPath, JSON.stringify(defaultTemplates, null, 2));
    console.log(chalk.green(`📋 Deployment templates created: ${templatesPath}`));
    
    return defaultTemplates;
  }

  /**
   * Validate process bundle before deployment
   */
  async validateBundle(processPath) {
    const validationStart = Date.now();
    
    try {
      const processContent = await fs.readFile(processPath, "utf8");
      const processSize = Buffer.byteLength(processContent, "utf8");
      
      const validation = {
        processPath,
        size: processSize,
        valid: true,
        errors: [],
        warnings: []
      };

      // Size validation
      if (processSize > 500000) {
        validation.valid = false;
        validation.errors.push(`Process size ${processSize} exceeds 500KB limit`);
      } else if (processSize > 450000) {
        validation.warnings.push(`Process size ${processSize} approaching 500KB limit`);
      }

      // AO compatibility validation
      const aoCompatibilityResult = await this.validateAOCompatibility(processContent);
      if (!aoCompatibilityResult.valid) {
        validation.valid = false;
        validation.errors.push(...aoCompatibilityResult.errors);
      }

      // Handler pattern validation
      const handlerValidation = this.validateHandlerPatterns(processContent);
      if (!handlerValidation.valid) {
        validation.valid = false;
        validation.errors.push(...handlerValidation.errors);
      }

      validation.validationTime = Date.now() - validationStart;
      
      console.log(chalk[validation.valid ? "green" : "red"](
        `  ${validation.valid ? "✅" : "❌"} Bundle validation: ${path.basename(processPath)} - ${validation.valid ? "VALID" : "INVALID"}`
      ));

      return validation;
    } catch (error) {
      return {
        processPath,
        size: 0,
        valid: false,
        errors: [`Bundle validation failed: ${error.message}`],
        warnings: [],
        validationTime: Date.now() - validationStart
      };
    }
  }

  /**
   * Validate AO compatibility
   */
  async validateAOCompatibility(processContent) {
    const errors = [];
    
    // Check for forbidden require() statements
    if (processContent.includes("require(")) {
      errors.push("Process contains require() statements - must use monolithic design");
    }

    // Check for proper handler pattern
    if (!processContent.includes("Handlers.add(")) {
      errors.push("Process must use Handlers.add() pattern");
    }

    // Check for forbidden globals
    const forbiddenPatterns = [
      { pattern: /io\./g, error: "io operations not allowed in AO processes" },
      { pattern: /os\.time\(\)/g, error: "Use msg.Timestamp instead of os.time()" },
      { pattern: /debug\./g, error: "debug library not available in AO" }
    ];

    for (const { pattern, error } of forbiddenPatterns) {
      if (pattern.test(processContent)) {
        errors.push(error);
      }
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Validate handler patterns
   */
  validateHandlerPatterns(processContent) {
    const errors = [];
    
    // Check for required ADP v1.0 Info handler
    if (!processContent.includes('"Info"') && !processContent.includes("'Info'")) {
      errors.push("Process missing required Info handler for ADP v1.0 compliance");
    }

    // Check for proper error handling with pcall
    if (!processContent.includes("pcall")) {
      errors.push("Process should use pcall for error handling");
    }

    // Check for ao.send usage
    if (!processContent.includes("ao.send")) {
      errors.push("Process must use ao.send for message responses");
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Deploy process using aolite simulation
   */
  async deployProcess(config) {
    const deployStart = Date.now();
    console.log(chalk.blue(`🚀 Deploying process: ${path.basename(config.processPath)}`));

    try {
      // Validate bundle first
      const bundleValidation = await this.validateBundle(config.processPath);
      if (!bundleValidation.valid) {
        throw new Error(`Bundle validation failed: ${bundleValidation.errors.join(", ")}`);
      }

      // Use aolite to spawn process
      const processId = await this.aoliteFramework.spawnProcess(config.processPath);
      
      // Verify initialization
      const initResult = await this.verifyProcessInitialization(processId, config);
      
      const deploymentResult = {
        processId,
        processPath: config.processPath,
        processType: config.processType,
        status: initResult.success ? "deployed" : "failed",
        deploymentTime: Date.now() - deployStart,
        bundleValidation,
        initialization: initResult,
        error: initResult.success ? null : initResult.error
      };

      this.deploymentResults.push(deploymentResult);
      
      console.log(chalk[deploymentResult.status === "deployed" ? "green" : "red"](
        `  ${deploymentResult.status === "deployed" ? "✅" : "❌"} ${path.basename(config.processPath)} -> ${processId} (${deploymentResult.deploymentTime}ms)`
      ));

      return deploymentResult;
    } catch (error) {
      const deploymentResult = {
        processId: null,
        processPath: config.processPath,
        processType: config.processType,
        status: "failed",
        deploymentTime: Date.now() - deployStart,
        error: error.message
      };

      this.deploymentResults.push(deploymentResult);
      console.log(chalk.red(`  ❌ Deployment failed: ${error.message}`));
      
      return deploymentResult;
    }
  }

  /**
   * Verify process initialization
   */
  async verifyProcessInitialization(processId, config) {
    try {
      // Send Info message to verify ADP compliance
      const infoResponse = await this.aoliteFramework.sendMessage(processId, {
        Action: "Info",
        Data: {}
      });

      if (!infoResponse || !infoResponse.success) {
        return {
          success: false,
          error: "Process did not respond to Info message (ADP compliance check failed)"
        };
      }

      // Verify required handlers are registered
      const handlerCheck = await this.verifyHandlerRegistration(processId, config.requiredHandlers);
      if (!handlerCheck.success) {
        return handlerCheck;
      }

      // Test basic responsiveness
      const healthResponse = await this.aoliteFramework.sendMessage(processId, {
        Action: "HealthCheck",
        Data: {}
      });

      return {
        success: true,
        infoResponse: infoResponse.data,
        handlerCount: config.requiredHandlers.length,
        healthCheck: healthResponse?.success || false
      };
    } catch (error) {
      return {
        success: false,
        error: `Initialization verification failed: ${error.message}`
      };
    }
  }

  /**
   * Verify handler registration
   */
  async verifyHandlerRegistration(processId, requiredHandlers) {
    try {
      for (const handler of requiredHandlers) {
        const testMessage = {
          Action: handler,
          Data: { test: true }
        };

        // Send test message to verify handler exists
        const response = await this.aoliteFramework.sendMessage(processId, testMessage);
        
        // We expect either success or a structured error response
        if (!response) {
          return {
            success: false,
            error: `Handler ${handler} not responding`
          };
        }
      }

      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: `Handler verification failed: ${error.message}`
      };
    }
  }

  /**
   * Run complete deployment validation suite
   */
  async runDeploymentTests() {
    console.log(chalk.blue.bold("\n🚀 Deployment Validation Suite"));
    console.log(chalk.blue("=".repeat(50)));

    try {
      // Initialize environment
      await this.initializeEnvironment();

      // Load deployment templates
      const templates = await this.loadDeploymentTemplates();

      // Find all process files
      const processFiles = await this.discoverProcesses();
      
      console.log(chalk.yellow(`📁 Found ${processFiles.length} processes to validate`));

      // Test each process
      for (const processFile of processFiles) {
        const config = this.getProcessConfig(processFile, templates);
        await this.deployProcess(config);
      }

      // Generate deployment report
      await this.generateDeploymentReport();

      return this.getDeploymentSummary();
    } catch (error) {
      console.error(chalk.red("❌ Deployment testing failed:"), error.message);
      throw error;
    } finally {
      // Cleanup
      await this.cleanup();
    }
  }

  /**
   * Discover available processes
   */
  async discoverProcesses() {
    try {
      const files = await fs.readdir(this.processesDir);
      return files.filter(file => file.endsWith(".lua"));
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not read processes directory: ${error.message}`));
      return [];
    }
  }

  /**
   * Get process configuration based on type
   */
  getProcessConfig(processFile, templates) {
    const processPath = path.join(this.processesDir, processFile);
    
    // Determine process type based on filename
    if (processFile.includes("coordinator")) {
      return { ...templates.coordinatorProcess, processPath };
    } else if (processFile.includes("data") || processFile.includes("species") || processFile.includes("move") || processFile.includes("item")) {
      return { ...templates.dataProcess, processPath };
    } else {
      return { ...templates.logicProcess, processPath };
    }
  }

  /**
   * Generate deployment validation report
   */
  async generateDeploymentReport() {
    const reportPath = path.join(this.reportsDir, `deployment-validation-${Date.now()}.json`);
    const htmlReportPath = path.join(this.reportsDir, `deployment-validation-${Date.now()}.html`);

    const summary = this.getDeploymentSummary();
    
    const report = {
      timestamp: new Date().toISOString(),
      framework: "Deployment Validation Framework",
      summary,
      deploymentResults: this.deploymentResults,
      environment: {
        aoliteVersion: "latest",
        nodeVersion: process.version,
        processesDir: this.processesDir
      }
    };

    // Write JSON report
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    // Generate HTML report
    const htmlReport = this.generateHtmlReport(report);
    await fs.writeFile(htmlReportPath, htmlReport);

    console.log(chalk.green("📊 Deployment validation reports generated:"));
    console.log(chalk.blue(`  JSON: ${reportPath}`));
    console.log(chalk.blue(`  HTML: ${htmlReportPath}`));
  }

  /**
   * Generate HTML deployment report
   */
  generateHtmlReport(report) {
    const { summary } = report;
    
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Deployment Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .success { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
        .deployment-result { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .metrics { background: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 3px; }
        .validation-details { font-family: monospace; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Deployment Validation Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Generated:</strong> ${report.timestamp}</p>
        <p><strong>Total Processes:</strong> ${summary.total}</p>
        <p><strong>Deployed Successfully:</strong> <span class="success">${summary.deployed}</span></p>
        <p><strong>Failed:</strong> <span class="failed">${summary.failed}</span></p>
        <p><strong>Success Rate:</strong> ${summary.successRate.toFixed(1)}%</p>
        <p><strong>Average Deployment Time:</strong> ${summary.averageDeploymentTime.toFixed(0)}ms</p>
    </div>
    
    <h2>Deployment Results</h2>
    ${report.deploymentResults.map(result => `
        <div class="deployment-result">
            <h3>${path.basename(result.processPath)} <span class="${result.status}">${result.status.toUpperCase()}</span></h3>
            <p><strong>Process ID:</strong> ${result.processId || "N/A"}</p>
            <p><strong>Type:</strong> ${result.processType}</p>
            <p><strong>Deployment Time:</strong> ${result.deploymentTime}ms</p>
            ${result.bundleValidation ? `
                <div class="metrics">
                    <h4>Bundle Validation</h4>
                    <p><strong>Size:</strong> ${result.bundleValidation.size} bytes</p>
                    <p><strong>Valid:</strong> ${result.bundleValidation.valid ? "Yes" : "No"}</p>
                    ${result.bundleValidation.errors.length > 0 ? `
                        <div class="validation-details">
                            <strong>Errors:</strong>
                            <ul>${result.bundleValidation.errors.map(error => `<li>${error}</li>`).join("")}</ul>
                        </div>
                    ` : ""}
                    ${result.bundleValidation.warnings.length > 0 ? `
                        <div class="validation-details">
                            <strong>Warnings:</strong>
                            <ul>${result.bundleValidation.warnings.map(warning => `<li>${warning}</li>`).join("")}</ul>
                        </div>
                    ` : ""}
                </div>
            ` : ""}
            ${result.error ? `<p><strong>Error:</strong> <span class="failed">${result.error}</span></p>` : ""}
        </div>
    `).join("")}
</body>
</html>`;
  }

  /**
   * Get deployment summary
   */
  getDeploymentSummary() {
    const total = this.deploymentResults.length;
    const deployed = this.deploymentResults.filter(r => r.status === "deployed").length;
    const failed = this.deploymentResults.filter(r => r.status === "failed").length;
    
    const totalDeploymentTime = this.deploymentResults.reduce((sum, r) => sum + r.deploymentTime, 0);
    const averageDeploymentTime = total > 0 ? totalDeploymentTime / total : 0;

    return {
      total,
      deployed,
      failed,
      successRate: total > 0 ? (deployed / total) * 100 : 0,
      averageDeploymentTime,
      totalDeploymentTime
    };
  }

  /**
   * Cleanup deployment testing environment
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up deployment testing environment..."));

    try {
      // Terminate any running aolite processes
      await this.aoliteFramework.cleanup();
      
      // Clear deployment results
      this.deploymentResults = [];
      this.performanceMetrics.clear();

    } catch (error) {
      console.warn(chalk.yellow(`Warning: Cleanup encountered issues: ${error.message}`));
    }

    console.log(chalk.green("✅ Deployment testing cleanup completed"));
  }
}

export { DeploymentTestRunner };