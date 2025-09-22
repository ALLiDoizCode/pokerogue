/**
 * Integration Testing Environment Configuration
 * Manages environment setup and configuration for integration testing
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";

export class IntegrationEnvironmentConfig {
  constructor(options = {}) {
    this.workspaceDir = options.workspaceDir || path.join(process.cwd(), "testing/aos-local");
    this.processesDir = options.processesDir || path.join(process.cwd(), "processes");
    this.aoliteDir = options.aoliteDir || path.join(process.cwd(), "testing/aolite");
    this.config = {
      environment: "integration-testing",
      version: "1.0.0",
      ...options.config
    };
  }

  /**
   * Initialize integration testing environment
   */
  async initializeEnvironment() {
    console.log(chalk.blue("🔧 Initializing integration testing environment..."));

    // Create workspace structure
    await this.createWorkspaceStructure();

    // Configure environment variables
    this.configureEnvironmentVariables();

    // Validate prerequisites
    await this.validatePrerequisites();

    // Setup default configurations
    await this.setupDefaultConfigurations();

    console.log(chalk.green("✅ Integration testing environment initialized"));
    return this.getEnvironmentInfo();
  }

  /**
   * Create enhanced workspace structure for deployment testing
   */
  async createWorkspaceStructure() {
    const directories = [
      // Core testing directories
      path.join(this.workspaceDir, "temp"),
      path.join(this.workspaceDir, "scenarios"),
      path.join(this.workspaceDir, "configs"),
      path.join(this.workspaceDir, "logs"),
      
      // Integration testing specific
      path.join(this.workspaceDir, "deployment"),
      path.join(this.workspaceDir, "performance"),
      path.join(this.workspaceDir, "recovery"),
      
      // Reports and artifacts
      path.join(process.cwd(), "testing/reports/deployment"),
      path.join(process.cwd(), "testing/reports/performance"),
      path.join(process.cwd(), "testing/reports/integration"),
      
      // Fixtures and test data
      path.join(process.cwd(), "testing/fixtures/scenarios"),
      path.join(process.cwd(), "testing/fixtures/performance"),
      path.join(process.cwd(), "testing/fixtures/recovery"),
      
      // Development tools integration
      path.join(process.cwd(), "development-tools/integration-testing/process-templates"),
      path.join(process.cwd(), "development-tools/integration-testing/monitoring")
    ];

    for (const dir of directories) {
      try {
        await fs.mkdir(dir, { recursive: true });
        console.log(chalk.blue(`  📁 Created directory: ${path.relative(process.cwd(), dir)}`));
      } catch (error) {
        console.warn(chalk.yellow(`Warning: Could not create directory ${dir}: ${error.message}`));
      }
    }
  }

  /**
   * Configure environment variables for integration testing
   */
  configureEnvironmentVariables() {
    const envConfig = {
      // aolite configuration
      AOLITE_LOG_LEVEL: "2", // Enhanced logging for integration testing
      AOLITE_TIMEOUT: "10000", // 10 second timeout for integration tests
      AOLITE_MEMORY_LIMIT: "512", // 512MB memory limit
      AOLITE_PROCESS_LIMIT: "26", // Support all 26 processes
      AOLITE_CONCURRENT_MESSAGES: "10", // Allow 10 concurrent messages
      
      // Integration testing configuration  
      INTEGRATION_TEST_MODE: "true",
      INTEGRATION_MAX_PROCESSES: "26",
      INTEGRATION_DEPLOYMENT_TIMEOUT: "30000", // 30 second deployment timeout
      INTEGRATION_RESPONSE_TIMEOUT: "5000", // 5 second response timeout
      INTEGRATION_RETRY_COUNT: "3", // Retry failed operations 3 times
      
      // Performance monitoring
      PERFORMANCE_MONITORING: "true",
      PERFORMANCE_BASELINE_PATH: path.join(process.cwd(), "testing/fixtures/performance-baselines.js"),
      PERFORMANCE_REPORT_INTERVAL: "1000", // Report every 1000ms
      
      // Recovery testing
      RECOVERY_TEST_ENABLED: "true",
      RECOVERY_MAX_RESTART_TIME: "5000", // 5 second max restart time
      RECOVERY_STATE_VALIDATION: "true",
      
      // Workspace paths
      INTEGRATION_WORKSPACE: this.workspaceDir,
      INTEGRATION_PROCESSES_DIR: this.processesDir,
      INTEGRATION_AOLITE_DIR: this.aoliteDir,
      INTEGRATION_REPORTS_DIR: path.join(process.cwd(), "testing/reports"),
      INTEGRATION_TEMP_DIR: path.join(this.workspaceDir, "temp")
    };

    // Set environment variables
    for (const [key, value] of Object.entries(envConfig)) {
      process.env[key] = value;
    }

    console.log(chalk.blue("📝 Environment variables configured:"));
    Object.entries(envConfig).forEach(([key, value]) => {
      console.log(chalk.gray(`  ${key}=${value}`));
    });
  }

  /**
   * Validate prerequisites for integration testing
   */
  async validatePrerequisites() {
    console.log(chalk.blue("🔍 Validating prerequisites..."));

    const validations = [
      { name: "Node.js version", check: () => this.validateNodeVersion() },
      { name: "Lua availability", check: () => this.validateLuaAvailability() },
      { name: "aolite framework", check: () => this.validateAoliteFramework() },
      { name: "Process files", check: () => this.validateProcessFiles() },
      { name: "Test fixtures", check: () => this.validateTestFixtures() }
    ];

    const results = [];

    for (const validation of validations) {
      try {
        const result = await validation.check();
        results.push({ name: validation.name, success: true, result });
        console.log(chalk.green(`  ✅ ${validation.name}: OK`));
      } catch (error) {
        results.push({ name: validation.name, success: false, error: error.message });
        console.log(chalk.red(`  ❌ ${validation.name}: ${error.message}`));
      }
    }

    const failedValidations = results.filter(r => !r.success);
    if (failedValidations.length > 0) {
      throw new Error(`Prerequisites validation failed: ${failedValidations.map(v => v.name).join(", ")}`);
    }

    return results;
  }

  /**
   * Validate Node.js version
   */
  async validateNodeVersion() {
    const version = process.version;
    const majorVersion = parseInt(version.substring(1).split(".")[0]);
    
    if (majorVersion < 14) {
      throw new Error(`Node.js version ${version} is too old. Requires Node.js 14+`);
    }
    
    return version;
  }

  /**
   * Validate Lua availability
   */
  async validateLuaAvailability() {
    const { spawn } = await import("child_process");
    
    return new Promise((resolve, reject) => {
      const lua = spawn("lua", ["-v"]);
      
      let output = "";
      lua.stdout.on("data", (data) => output += data.toString());
      lua.stderr.on("data", (data) => output += data.toString());
      
      lua.on("close", (code) => {
        if (code === 0) {
          resolve(output.trim());
        } else {
          reject(new Error("Lua not available. Please install Lua 5.3+"));
        }
      });
      
      lua.on("error", () => {
        reject(new Error("Lua not available. Please install Lua 5.3+"));
      });
    });
  }

  /**
   * Validate aolite framework
   */
  async validateAoliteFramework() {
    const requiredFiles = [
      "process-emulator.lua",
      "enhanced-test-framework.lua",
      "assertion-library.lua",
      "mock-system.lua",
      "state-inspector.lua"
    ];

    const missingFiles = [];
    for (const file of requiredFiles) {
      const filePath = path.join(this.aoliteDir, file);
      try {
        await fs.access(filePath);
      } catch (error) {
        missingFiles.push(file);
      }
    }

    if (missingFiles.length > 0) {
      throw new Error(`Missing aolite files: ${missingFiles.join(", ")}`);
    }

    return "aolite framework complete";
  }

  /**
   * Validate process files
   */
  async validateProcessFiles() {
    try {
      const files = await fs.readdir(this.processesDir);
      const luaFiles = files.filter(f => f.endsWith(".lua"));
      
      if (luaFiles.length === 0) {
        throw new Error("No Lua process files found");
      }
      
      return `${luaFiles.length} process files found`;
    } catch (error) {
      throw new Error(`Cannot access processes directory: ${error.message}`);
    }
  }

  /**
   * Validate test fixtures
   */
  async validateTestFixtures() {
    const fixturesDir = path.join(process.cwd(), "testing/fixtures");
    try {
      await fs.access(fixturesDir);
      const files = await fs.readdir(fixturesDir);
      return `${files.length} fixture files found`;
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Test fixtures directory not found, will create defaults`));
      return "fixtures will be created";
    }
  }

  /**
   * Setup default configurations
   */
  async setupDefaultConfigurations() {
    console.log(chalk.blue("⚙️  Setting up default configurations..."));

    // Resource constraints configuration
    const resourceConstraints = {
      deployment: {
        maxConcurrentDeployments: 5,
        deploymentTimeout: 30000, // 30 seconds
        maxRetries: 3,
        retryDelay: 1000 // 1 second
      },
      process: {
        maxProcessSize: 500000, // 500KB
        maxMemoryUsage: 100, // 100MB per process
        maxResponseTime: 5000, // 5 seconds
        healthCheckInterval: 10000 // 10 seconds
      },
      performance: {
        baselineTolerancePercent: 10, // Allow 10% variance from baseline
        maxPerformanceRegressionPercent: 20, // Fail if >20% regression
        performanceReportingEnabled: true,
        detailedMetricsEnabled: true
      },
      recovery: {
        maxRestartTime: 5000, // 5 seconds
        stateValidationTimeout: 3000, // 3 seconds
        recoveryRetryCount: 3,
        recoveryRetryDelay: 2000 // 2 seconds
      }
    };

    const constraintsPath = path.join(this.workspaceDir, "configs/resource-constraints.json");
    await fs.writeFile(constraintsPath, JSON.stringify(resourceConstraints, null, 2));

    // Process limits configuration
    const processLimits = {
      aolite: {
        logLevel: parseInt(process.env.AOLITE_LOG_LEVEL),
        timeout: parseInt(process.env.AOLITE_TIMEOUT),
        memoryLimit: parseInt(process.env.AOLITE_MEMORY_LIMIT),
        processLimit: parseInt(process.env.AOLITE_PROCESS_LIMIT),
        concurrentMessages: parseInt(process.env.AOLITE_CONCURRENT_MESSAGES)
      },
      validation: {
        bundleSizeLimit: 500000, // 500KB
        handlerResponseTimeout: 2000, // 2 seconds
        initializationTimeout: 3000, // 3 seconds
        adpComplianceRequired: true
      }
    };

    const limitsPath = path.join(this.workspaceDir, "configs/process-limits.json");
    await fs.writeFile(limitsPath, JSON.stringify(processLimits, null, 2));

    console.log(chalk.green(`  ✅ Resource constraints: ${constraintsPath}`));
    console.log(chalk.green(`  ✅ Process limits: ${limitsPath}`));
  }

  /**
   * Get environment health status
   */
  async getHealthStatus() {
    const health = {
      timestamp: new Date().toISOString(),
      environment: "integration-testing",
      status: "unknown",
      checks: []
    };

    try {
      // Check workspace directories
      const workspaceCheck = await this.checkWorkspaceHealth();
      health.checks.push({ name: "workspace", status: workspaceCheck.status, details: workspaceCheck });

      // Check environment variables
      const envCheck = this.checkEnvironmentVariables();
      health.checks.push({ name: "environment", status: envCheck.status, details: envCheck });

      // Check aolite availability
      const aoliteCheck = await this.checkAoliteHealth();
      health.checks.push({ name: "aolite", status: aoliteCheck.status, details: aoliteCheck });

      // Determine overall status
      const failedChecks = health.checks.filter(c => c.status !== "healthy");
      health.status = failedChecks.length === 0 ? "healthy" : "degraded";

      if (failedChecks.length > 0) {
        health.issues = failedChecks.map(c => `${c.name}: ${c.details.error || "degraded"}`);
      }

    } catch (error) {
      health.status = "unhealthy";
      health.error = error.message;
    }

    return health;
  }

  /**
   * Check workspace health
   */
  async checkWorkspaceHealth() {
    try {
      // Check if workspace directories exist and are writable
      const tempDir = path.join(this.workspaceDir, "temp");
      const testFile = path.join(tempDir, "health-check.tmp");
      
      await fs.writeFile(testFile, "health check");
      await fs.unlink(testFile);
      
      return { status: "healthy", writeable: true };
    } catch (error) {
      return { status: "unhealthy", error: error.message };
    }
  }

  /**
   * Check environment variables
   */
  checkEnvironmentVariables() {
    const requiredVars = [
      "AOLITE_LOG_LEVEL",
      "INTEGRATION_TEST_MODE", 
      "INTEGRATION_WORKSPACE"
    ];

    const missingVars = requiredVars.filter(varName => !process.env[varName]);
    
    if (missingVars.length > 0) {
      return { status: "unhealthy", error: `Missing variables: ${missingVars.join(", ")}` };
    }

    return { status: "healthy", variables: requiredVars.length };
  }

  /**
   * Check aolite health
   */
  async checkAoliteHealth() {
    try {
      const { AoliteFramework } = await import("../aolite/aolite-framework.js");
      const aolite = new AoliteFramework();
      
      // Try to initialize aolite (this will validate Lua and aolite files)
      await aolite.initialize();
      await aolite.cleanup();
      
      return { status: "healthy", initialized: true };
    } catch (error) {
      return { status: "unhealthy", error: error.message };
    }
  }

  /**
   * Get complete environment information
   */
  getEnvironmentInfo() {
    return {
      version: this.config.version,
      environment: this.config.environment,
      workspace: this.workspaceDir,
      processesDir: this.processesDir,
      aoliteDir: this.aoliteDir,
      nodeVersion: process.version,
      platform: process.platform,
      architecture: process.arch,
      environmentVariables: {
        aoliteLogLevel: process.env.AOLITE_LOG_LEVEL,
        integrationTestMode: process.env.INTEGRATION_TEST_MODE,
        maxProcesses: process.env.INTEGRATION_MAX_PROCESSES,
        deploymentTimeout: process.env.INTEGRATION_DEPLOYMENT_TIMEOUT
      },
      directories: {
        workspace: this.workspaceDir,
        temp: path.join(this.workspaceDir, "temp"),
        scenarios: path.join(this.workspaceDir, "scenarios"),
        configs: path.join(this.workspaceDir, "configs"),
        reports: path.join(process.cwd(), "testing/reports"),
        fixtures: path.join(process.cwd(), "testing/fixtures")
      }
    };
  }

  /**
   * Cleanup environment
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up integration testing environment..."));

    try {
      // Clean temporary files
      const tempDir = path.join(this.workspaceDir, "temp");
      await fs.rm(tempDir, { recursive: true, force: true });
      await fs.mkdir(tempDir, { recursive: true });

      // Clean logs
      const logsDir = path.join(this.workspaceDir, "logs");
      await fs.rm(logsDir, { recursive: true, force: true });
      await fs.mkdir(logsDir, { recursive: true });

      console.log(chalk.green("✅ Integration testing environment cleanup completed"));
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Cleanup encountered issues: ${error.message}`));
    }
  }
}

export { IntegrationEnvironmentConfig };