/**
 * Process Deployer
 * Utilities for deploying and managing processes in aolite testing environment
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { AoliteFramework } from "../aolite/aolite-framework.js";

export class ProcessDeployer {
  constructor(options = {}) {
    this.aoliteFramework = new AoliteFramework();
    this.processesDir = options.processesDir || path.join(process.cwd(), "processes");
    this.tempDir = options.tempDir || path.join(process.cwd(), "testing/aos-local/temp");
    this.deployedProcesses = new Map();
    this.deploymentQueue = [];
    this.maxConcurrentDeployments = options.maxConcurrent || 5;
  }

  /**
   * Initialize process deployer
   */
  async initialize() {
    console.log(chalk.blue("🔧 Initializing process deployer..."));
    
    // Initialize aolite framework
    await this.aoliteFramework.initialize();
    
    // Ensure temp directory exists
    await fs.mkdir(this.tempDir, { recursive: true });
    
    console.log(chalk.green("✅ Process deployer ready"));
  }

  /**
   * Deploy a single process with comprehensive validation
   */
  async deploySingleProcess(config) {
    const deployStart = Date.now();
    const processName = path.basename(config.processPath, ".lua");
    
    console.log(chalk.blue(`🚀 Deploying ${processName}...`));

    try {
      // Step 1: Pre-deployment validation
      const validation = await this.validateProcessForDeployment(config);
      if (!validation.success) {
        throw new Error(`Pre-deployment validation failed: ${validation.errors.join(", ")}`);
      }

      // Step 2: Prepare process for deployment
      const preparedProcess = await this.prepareProcessForDeployment(config);
      
      // Step 3: Deploy to aolite
      const processId = await this.aoliteFramework.spawnProcess(preparedProcess.processPath);
      
      // Step 4: Verify deployment success
      const verification = await this.verifyDeployment(processId, config);
      if (!verification.success) {
        throw new Error(`Deployment verification failed: ${verification.error}`);
      }

      // Step 5: Initialize process
      const initialization = await this.initializeProcess(processId, config);
      if (!initialization.success) {
        throw new Error(`Process initialization failed: ${initialization.error}`);
      }

      // Step 6: Record successful deployment
      const deploymentRecord = {
        processId,
        processName,
        processPath: config.processPath,
        processType: config.processType,
        status: "deployed",
        deploymentTime: Date.now() - deployStart,
        validation,
        verification,
        initialization,
        config
      };

      this.deployedProcesses.set(processId, deploymentRecord);
      
      console.log(chalk.green(`✅ ${processName} deployed successfully -> ${processId} (${deploymentRecord.deploymentTime}ms)`));
      
      return deploymentRecord;

    } catch (error) {
      const failureRecord = {
        processId: null,
        processName,
        processPath: config.processPath,
        processType: config.processType,
        status: "failed",
        deploymentTime: Date.now() - deployStart,
        error: error.message
      };

      console.log(chalk.red(`❌ ${processName} deployment failed: ${error.message}`));
      
      return failureRecord;
    }
  }

  /**
   * Deploy multiple processes with dependency management
   */
  async deployMultipleProcesses(configs, options = {}) {
    console.log(chalk.blue(`🚀 Deploying ${configs.length} processes...`));
    
    const { respectDependencies = true, parallel = false } = options;
    const deploymentResults = [];

    if (parallel && !respectDependencies) {
      // Deploy all processes in parallel
      const deploymentPromises = configs.map(config => this.deploySingleProcess(config));
      const results = await Promise.allSettled(deploymentPromises);
      
      return results.map((result, index) => {
        if (result.status === "fulfilled") {
          return result.value;
        } else {
          return {
            processName: path.basename(configs[index].processPath, ".lua"),
            status: "failed",
            error: result.reason.message
          };
        }
      });
    }

    if (respectDependencies) {
      // Deploy processes in dependency order
      const orderedConfigs = this.resolveDependencyOrder(configs);
      
      for (const config of orderedConfigs) {
        // Wait for dependencies to be deployed
        if (config.dependencies && config.dependencies.length > 0) {
          await this.waitForDependencies(config.dependencies);
        }
        
        const result = await this.deploySingleProcess(config);
        deploymentResults.push(result);
        
        // Stop deployment if a critical process fails
        if (result.status === "failed" && config.critical) {
          console.log(chalk.red(`❌ Critical process ${result.processName} failed, stopping deployment`));
          break;
        }
      }
    } else {
      // Deploy processes sequentially without dependency management
      for (const config of configs) {
        const result = await this.deploySingleProcess(config);
        deploymentResults.push(result);
      }
    }

    const summary = this.getDeploymentSummary(deploymentResults);
    console.log(chalk.blue(`📊 Deployment completed: ${summary.successful}/${summary.total} processes deployed`));
    
    return deploymentResults;
  }

  /**
   * Validate process for deployment
   */
  async validateProcessForDeployment(config) {
    const errors = [];
    const warnings = [];

    try {
      // Check if process file exists
      const processContent = await fs.readFile(config.processPath, "utf8");
      const processSize = Buffer.byteLength(processContent, "utf8");

      // Size validation
      if (processSize > config.maxSize) {
        errors.push(`Process size ${processSize} exceeds limit ${config.maxSize}`);
      } else if (processSize > config.maxSize * 0.9) {
        warnings.push(`Process size ${processSize} approaching limit ${config.maxSize}`);
      }

      // AO compatibility validation
      const aoValidation = this.validateAOCompatibility(processContent);
      if (!aoValidation.valid) {
        errors.push(...aoValidation.errors);
      }

      // Handler validation
      const handlerValidation = this.validateRequiredHandlers(processContent, config.requiredHandlers);
      if (!handlerValidation.valid) {
        errors.push(...handlerValidation.errors);
      }

      // ADP compliance validation
      if (config.validation && config.validation.adpCompliance) {
        const adpValidation = this.validateADPCompliance(processContent, config.validation.adpCompliance);
        if (!adpValidation.valid) {
          errors.push(...adpValidation.errors);
        }
      }

      return {
        success: errors.length === 0,
        errors,
        warnings,
        processSize,
        validationTime: Date.now()
      };

    } catch (error) {
      return {
        success: false,
        errors: [`Validation failed: ${error.message}`],
        warnings: []
      };
    }
  }

  /**
   * Validate AO compatibility
   */
  validateAOCompatibility(processContent) {
    const errors = [];

    // Check for forbidden patterns
    const forbiddenPatterns = [
      { pattern: /require\s*\(/g, error: "require() not allowed - use monolithic design" },
      { pattern: /io\./g, error: "io operations not allowed in AO processes" },
      { pattern: /os\.time\(\)/g, error: "Use msg.Timestamp instead of os.time()" },
      { pattern: /debug\./g, error: "debug library not available in AO" },
      { pattern: /package\./g, error: "package operations not allowed" }
    ];

    for (const { pattern, error } of forbiddenPatterns) {
      if (pattern.test(processContent)) {
        errors.push(error);
      }
    }

    // Check for required patterns
    if (!processContent.includes("Handlers.add(")) {
      errors.push("Process must use Handlers.add() pattern");
    }

    if (!processContent.includes("ao.send")) {
      errors.push("Process must use ao.send for responses");
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Validate required handlers
   */
  validateRequiredHandlers(processContent, requiredHandlers) {
    const errors = [];

    for (const handler of requiredHandlers) {
      // Check if handler is registered
      const handlerPattern = new RegExp(`["']${handler}["']`, "g");
      if (!handlerPattern.test(processContent)) {
        errors.push(`Required handler '${handler}' not found`);
      }
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Validate ADP compliance
   */
  validateADPCompliance(processContent, adpVersion) {
    const errors = [];

    // Check for Info handler (required for ADP)
    if (!processContent.includes('"Info"') && !processContent.includes("'Info'")) {
      errors.push("ADP compliance requires Info handler");
    }

    // Check for ADP version declaration
    if (!processContent.includes(`adpVersion.*["']${adpVersion}["']`)) {
      errors.push(`ADP version ${adpVersion} not declared`);
    }

    // Check for self-documentation structures
    if (!processContent.includes("messageSchemas") && !processContent.includes("capabilities")) {
      errors.push("ADP compliance requires self-documentation structures");
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Prepare process for deployment
   */
  async prepareProcessForDeployment(config) {
    // For now, just return the original config
    // In the future, this could include:
    // - Code transformation
    // - Size optimization
    // - Dependency injection
    
    return {
      processPath: config.processPath,
      prepared: true
    };
  }

  /**
   * Verify deployment success
   */
  async verifyDeployment(processId, config) {
    try {
      // Send Info message to verify process is responsive
      const infoResponse = await this.aoliteFramework.sendMessage(processId, {
        Action: "Info",
        Data: {}
      });

      if (!infoResponse || !infoResponse.success) {
        return {
          success: false,
          error: "Process not responsive to Info message"
        };
      }

      // Verify process reports correct handlers
      const processInfo = infoResponse.data;
      if (processInfo && processInfo.handlers) {
        const missingHandlers = config.requiredHandlers.filter(
          handler => !processInfo.handlers.includes(handler)
        );
        
        if (missingHandlers.length > 0) {
          return {
            success: false,
            error: `Missing required handlers: ${missingHandlers.join(", ")}`
          };
        }
      }

      return {
        success: true,
        processInfo,
        responseTime: Date.now()
      };

    } catch (error) {
      return {
        success: false,
        error: `Deployment verification failed: ${error.message}`
      };
    }
  }

  /**
   * Initialize process after deployment
   */
  async initializeProcess(processId, config) {
    try {
      // Send initial configuration if needed
      if (config.initialization) {
        const initResponse = await this.aoliteFramework.sendMessage(processId, {
          Action: "Initialize",
          Data: config.initialization
        });

        if (!initResponse || !initResponse.success) {
          return {
            success: false,
            error: "Process initialization failed"
          };
        }
      }

      // Test basic functionality
      const healthResponse = await this.aoliteFramework.sendMessage(processId, {
        Action: "HealthCheck",
        Data: {}
      });

      return {
        success: true,
        healthCheck: healthResponse?.success || false,
        initializationTime: Date.now()
      };

    } catch (error) {
      return {
        success: false,
        error: `Process initialization failed: ${error.message}`
      };
    }
  }

  /**
   * Resolve dependency order for deployment
   */
  resolveDependencyOrder(configs) {
    const orderedConfigs = [];
    const processedNames = new Set();
    const configMap = new Map();

    // Create map of process names to configs
    configs.forEach(config => {
      const processName = path.basename(config.processPath, ".lua");
      configMap.set(processName, config);
    });

    // Recursive function to add dependencies first
    const addConfigWithDependencies = (config) => {
      const processName = path.basename(config.processPath, ".lua");
      
      if (processedNames.has(processName)) {
        return; // Already processed
      }

      // Add dependencies first
      if (config.dependencies) {
        for (const depName of config.dependencies) {
          const depConfig = configMap.get(depName);
          if (depConfig && !processedNames.has(depName)) {
            addConfigWithDependencies(depConfig);
          }
        }
      }

      // Add this config
      orderedConfigs.push(config);
      processedNames.add(processName);
    };

    // Process all configs
    configs.forEach(addConfigWithDependencies);

    return orderedConfigs;
  }

  /**
   * Wait for dependencies to be deployed
   */
  async waitForDependencies(dependencies) {
    const maxWaitTime = 30000; // 30 seconds
    const checkInterval = 500; // 0.5 seconds
    let waited = 0;

    while (waited < maxWaitTime) {
      const deployedProcessNames = Array.from(this.deployedProcesses.values())
        .filter(p => p.status === "deployed")
        .map(p => p.processName);

      const missingDependencies = dependencies.filter(dep => !deployedProcessNames.includes(dep));
      
      if (missingDependencies.length === 0) {
        return; // All dependencies are deployed
      }

      await new Promise(resolve => setTimeout(resolve, checkInterval));
      waited += checkInterval;
    }

    throw new Error(`Timeout waiting for dependencies: ${dependencies.join(", ")}`);
  }

  /**
   * Get deployment summary
   */
  getDeploymentSummary(results) {
    const total = results.length;
    const successful = results.filter(r => r.status === "deployed").length;
    const failed = results.filter(r => r.status === "failed").length;
    
    const totalTime = results.reduce((sum, r) => sum + (r.deploymentTime || 0), 0);
    const averageTime = total > 0 ? totalTime / total : 0;

    return {
      total,
      successful,
      failed,
      successRate: total > 0 ? (successful / total) * 100 : 0,
      totalTime,
      averageTime
    };
  }

  /**
   * Stop and cleanup a deployed process
   */
  async stopProcess(processId) {
    try {
      const processRecord = this.deployedProcesses.get(processId);
      if (!processRecord) {
        throw new Error(`Process ${processId} not found in deployed processes`);
      }

      // Send shutdown message
      await this.aoliteFramework.sendMessage(processId, {
        Action: "Shutdown",
        Data: {}
      });

      // Remove from aolite framework
      await this.aoliteFramework.removeProcess(processId);

      // Update record
      processRecord.status = "stopped";
      processRecord.stoppedAt = Date.now();

      console.log(chalk.yellow(`🛑 Process ${processRecord.processName} stopped`));

      return { success: true };

    } catch (error) {
      console.log(chalk.red(`❌ Failed to stop process ${processId}: ${error.message}`));
      return { success: false, error: error.message };
    }
  }

  /**
   * Restart a deployed process
   */
  async restartProcess(processId) {
    try {
      const processRecord = this.deployedProcesses.get(processId);
      if (!processRecord) {
        throw new Error(`Process ${processId} not found`);
      }

      console.log(chalk.blue(`🔄 Restarting ${processRecord.processName}...`));

      // Stop the process
      await this.stopProcess(processId);

      // Deploy again
      const newDeployment = await this.deploySingleProcess(processRecord.config);

      if (newDeployment.status === "deployed") {
        console.log(chalk.green(`✅ ${processRecord.processName} restarted successfully`));
      } else {
        console.log(chalk.red(`❌ ${processRecord.processName} restart failed`));
      }

      return newDeployment;

    } catch (error) {
      console.log(chalk.red(`❌ Restart failed: ${error.message}`));
      return { success: false, error: error.message };
    }
  }

  /**
   * Get deployment status
   */
  getDeploymentStatus() {
    const processes = Array.from(this.deployedProcesses.values());
    
    return {
      totalProcesses: processes.length,
      deployedProcesses: processes.filter(p => p.status === "deployed").length,
      failedProcesses: processes.filter(p => p.status === "failed").length,
      stoppedProcesses: processes.filter(p => p.status === "stopped").length,
      processes: processes.map(p => ({
        processId: p.processId,
        processName: p.processName,
        processType: p.processType,
        status: p.status,
        deploymentTime: p.deploymentTime
      }))
    };
  }

  /**
   * Cleanup all deployed processes
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up deployed processes..."));

    const cleanupPromises = Array.from(this.deployedProcesses.keys()).map(processId =>
      this.stopProcess(processId).catch(error => 
        console.warn(chalk.yellow(`Warning: Failed to stop process ${processId}: ${error.message}`))
      )
    );

    await Promise.allSettled(cleanupPromises);

    this.deployedProcesses.clear();
    this.deploymentQueue = [];

    console.log(chalk.green("✅ Process deployer cleanup completed"));
  }
}

export { ProcessDeployer };