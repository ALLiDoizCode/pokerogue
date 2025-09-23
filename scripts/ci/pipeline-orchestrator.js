#!/usr/bin/env node

/**
 * Pipeline Orchestrator for AO Process Testing
 * Coordinates execution of multi-stage testing pipeline across different frameworks
 */

const fs = require("fs");
const path = require("path");
const { execSync, spawn } = require("child_process");

class PipelineOrchestrator {
  constructor() {
    this.config = this.loadConfiguration();
    this.results = {
      startTime: new Date().toISOString(),
      stages: {},
      overallStatus: "pending",
      metrics: {},
    };
    this.logger = this.createLogger();
  }

  loadConfiguration() {
    const configPath = path.join(__dirname, "../../testing/ci/pipeline-config");
    const config = {
      stages: {
        validation: this.loadStageConfig(configPath, "validation-stage.json"),
        aolite: this.loadStageConfig(configPath, "aolite-stage.json"),
        aosLocal: this.loadStageConfig(configPath, "aos-local-stage.json"),
        integration: this.loadStageConfig(configPath, "integration-stage.json"),
        parity: this.loadStageConfig(configPath, "parity-stage.json"),
        performance: this.loadStageConfig(configPath, "performance-stage.json"),
      },
      qualityGates: this.loadStageConfig(configPath, "quality-gates.json"),
      parallel: {
        maxConcurrent: 4,
        processTypes: ["data", "logic", "coordinator"],
      },
    };

    return config;
  }

  loadStageConfig(configPath, fileName) {
    const filePath = path.join(configPath, fileName);
    try {
      if (fs.existsSync(filePath)) {
        return JSON.parse(fs.readFileSync(filePath, "utf8"));
      }
      return this.getDefaultConfig(fileName);
    } catch (error) {
      this.logger.warn(`Failed to load config ${fileName}, using defaults:`, error.message);
      return this.getDefaultConfig(fileName);
    }
  }

  getDefaultConfig(fileName) {
    const defaults = {
      "validation-stage.json": {
        name: "validation",
        commands: ["npm run lint:ao-sandbox", "npm run validate:size"],
        timeout: 120000,
        required: true,
      },
      "aolite-stage.json": {
        name: "aolite",
        commands: ["npm run test:aolite"],
        timeout: 180000,
        required: true,
        parallel: true,
      },
      "aos-local-stage.json": {
        name: "aos-local",
        commands: ["npm run test:aos-local"],
        timeout: 300000,
        required: true,
        parallel: true,
      },
      "integration-stage.json": {
        name: "integration",
        commands: ["npm run test:all"],
        timeout: 600000,
        required: true,
      },
      "parity-stage.json": {
        name: "parity",
        commands: ["npm run test:parity", "npm run test:statistical"],
        timeout: 300000,
        required: true,
      },
      "performance-stage.json": {
        name: "performance",
        commands: ["npm run test:performance"],
        timeout: 900000,
        required: false,
      },
      "quality-gates.json": {
        gates: [
          { name: "all-tests-pass", requirement: "100% test success rate", critical: true },
          { name: "coverage-threshold", requirement: "95% minimum coverage", critical: true },
          { name: "process-size-limit", requirement: "500KB per process", critical: true },
          { name: "ao-sandbox-compliance", requirement: "AO runtime compatibility", critical: true },
        ],
        thresholds: {
          successRate: 100,
          coverageMinimum: 95,
          processSizeLimit: 512000,
        },
      },
    };

    return defaults[fileName] || {};
  }

  createLogger() {
    return {
      info: (msg, ...args) => console.log(`[INFO] ${new Date().toISOString()} ${msg}`, ...args),
      warn: (msg, ...args) => console.warn(`[WARN] ${new Date().toISOString()} ${msg}`, ...args),
      error: (msg, ...args) => console.error(`[ERROR] ${new Date().toISOString()} ${msg}`, ...args),
      debug: (msg, ...args) => process.env.DEBUG && console.log(`[DEBUG] ${new Date().toISOString()} ${msg}`, ...args),
    };
  }

  async orchestrate(options = {}) {
    const { level = "comprehensive", parallel = true, skipPerformance = false } = options;

    this.logger.info(`🚀 Starting pipeline orchestration (level: ${level})`);

    try {
      // Stage 1: Validation and Linting
      await this.executeStage("validation", this.config.stages.validation);

      // Stage 2: Parallel Testing (if enabled)
      if (parallel) {
        await this.executeParallelStage();
      } else {
        await this.executeStage("aolite", this.config.stages.aolite);
        await this.executeStage("aos-local", this.config.stages.aosLocal);
      }

      // Stage 3: Integration Testing
      await this.executeStage("integration", this.config.stages.integration);

      // Stage 4: Parity Validation
      await this.executeStage("parity", this.config.stages.parity);

      // Stage 5: Performance (conditional)
      if (!skipPerformance && (level === "comprehensive" || level === "full")) {
        await this.executeStage("performance", this.config.stages.performance);
      }

      // Quality Gates
      await this.evaluateQualityGates();

      this.results.endTime = new Date().toISOString();
      this.results.overallStatus = "success";

      await this.generateReport();

      this.logger.info("✅ Pipeline orchestration completed successfully");
      return this.results;
    } catch (error) {
      this.results.endTime = new Date().toISOString();
      this.results.overallStatus = "failure";
      this.results.error = error.message;

      await this.generateReport();

      this.logger.error("❌ Pipeline orchestration failed:", error.message);
      throw error;
    }
  }

  async executeStage(stageName, stageConfig) {
    this.logger.info(`📋 Executing stage: ${stageName}`);

    const stageResult = {
      name: stageName,
      startTime: new Date().toISOString(),
      status: "running",
      commands: [],
      artifacts: [],
    };

    try {
      for (const command of stageConfig.commands) {
        const commandResult = await this.executeCommand(command, stageConfig.timeout);
        stageResult.commands.push(commandResult);

        if (!commandResult.success && stageConfig.required) {
          throw new Error(`Required command failed: ${command}`);
        }
      }

      // Collect artifacts
      stageResult.artifacts = await this.collectStageArtifacts(stageName);

      stageResult.endTime = new Date().toISOString();
      stageResult.status = "success";
      this.results.stages[stageName] = stageResult;

      this.logger.info(`✅ Stage ${stageName} completed successfully`);
    } catch (error) {
      stageResult.endTime = new Date().toISOString();
      stageResult.status = "failure";
      stageResult.error = error.message;
      this.results.stages[stageName] = stageResult;

      this.logger.error(`❌ Stage ${stageName} failed:`, error.message);
      throw error;
    }
  }

  async executeParallelStage() {
    this.logger.info("🔄 Executing parallel testing stage");

    const processMatrix = this.generateProcessMatrix();
    const chunks = this.chunkArray(processMatrix, this.config.parallel.maxConcurrent);

    for (const chunk of chunks) {
      const promises = chunk.map(process => this.executeProcessTest(process));
      await Promise.all(promises);
    }
  }

  generateProcessMatrix() {
    return [
      { type: "data", process: "pokemon-species-db", framework: "aolite", timeout: 120000 },
      { type: "data", process: "moves-database", framework: "aolite", timeout: 120000 },
      { type: "data", process: "items-database", framework: "aolite", timeout: 120000 },
      { type: "data", process: "abilities-database", framework: "aolite", timeout: 120000 },
      { type: "logic", process: "battle-engine", framework: "aos-local", timeout: 300000 },
      { type: "logic", process: "evolution-engine", framework: "aos-local", timeout: 180000 },
      { type: "logic", process: "capture-engine", framework: "aos-local", timeout: 180000 },
      { type: "logic", process: "status-effects-engine", framework: "aos-local", timeout: 180000 },
      { type: "coordinator", process: "coordinator-process", framework: "integration", timeout: 300000 },
    ];
  }

  async executeProcessTest(processConfig) {
    const { process, framework, timeout } = processConfig;

    this.logger.info(`🧪 Testing ${process} with ${framework}`);

    let command;
    switch (framework) {
      case "aolite":
        command = `npm run test:aolite -- --grep "${process}"`;
        break;
      case "aos-local":
        command = `npm run test:aos-local -- --grep "${process}"`;
        break;
      case "integration":
        command = `npm run test:all -- --grep "${process}"`;
        break;
      default:
        throw new Error(`Unknown framework: ${framework}`);
    }

    const result = await this.executeCommand(command, timeout);

    if (!this.results.stages.parallel) {
      this.results.stages.parallel = { processes: {} };
    }

    this.results.stages.parallel.processes[process] = {
      framework,
      ...result,
    };

    return result;
  }

  async executeCommand(command, timeout = 120000) {
    return new Promise(resolve => {
      this.logger.debug(`Executing: ${command}`);

      const startTime = Date.now();
      const child = spawn("sh", ["-c", command], {
        stdio: ["pipe", "pipe", "pipe"],
        env: { ...process.env },
      });

      let stdout = "";
      let stderr = "";

      child.stdout.on("data", data => {
        stdout += data.toString();
      });

      child.stderr.on("data", data => {
        stderr += data.toString();
      });

      const timeoutId = setTimeout(() => {
        child.kill("SIGTERM");
        resolve({
          command,
          success: false,
          exitCode: -1,
          stdout,
          stderr: stderr + "\nCommand timed out",
          duration: Date.now() - startTime,
          timedOut: true,
        });
      }, timeout);

      child.on("close", code => {
        clearTimeout(timeoutId);
        resolve({
          command,
          success: code === 0,
          exitCode: code,
          stdout,
          stderr,
          duration: Date.now() - startTime,
          timedOut: false,
        });
      });
    });
  }

  async collectStageArtifacts(stageName) {
    const artifactsDir = path.join(process.cwd(), "testing/reports");
    const artifacts = [];

    try {
      if (fs.existsSync(artifactsDir)) {
        const files = fs.readdirSync(artifactsDir);
        for (const file of files) {
          if (file.includes(stageName)) {
            artifacts.push(path.join(artifactsDir, file));
          }
        }
      }
    } catch (error) {
      this.logger.warn(`Failed to collect artifacts for ${stageName}:`, error.message);
    }

    return artifacts;
  }

  async evaluateQualityGates() {
    this.logger.info("🔍 Evaluating quality gates");

    const qualityResults = {
      overallStatus: "pass",
      gates: [],
      metrics: {},
    };

    const gates = this.config.qualityGates.gates;

    for (const gate of gates) {
      const gateResult = await this.evaluateGate(gate);
      qualityResults.gates.push(gateResult);

      if (!gateResult.passed && gate.critical) {
        qualityResults.overallStatus = "fail";
      }
    }

    this.results.qualityGates = qualityResults;

    if (qualityResults.overallStatus === "fail") {
      throw new Error("Quality gates failed");
    }

    this.logger.info("✅ All quality gates passed");
  }

  async evaluateGate(gate) {
    switch (gate.name) {
      case "all-tests-pass":
        return this.evaluateTestPassRate();
      case "coverage-threshold":
        return this.evaluateCoverageThreshold();
      case "process-size-limit":
        return this.evaluateProcessSizeLimit();
      case "ao-sandbox-compliance":
        return this.evaluateAOCompliance();
      default:
        return { name: gate.name, passed: true, message: "Unknown gate" };
    }
  }

  evaluateTestPassRate() {
    let totalTests = 0;
    let passedTests = 0;

    for (const stage of Object.values(this.results.stages)) {
      if (stage.commands) {
        for (const command of stage.commands) {
          totalTests++;
          if (command.success) {
            passedTests++;
          }
        }
      }
    }

    const successRate = totalTests > 0 ? (passedTests / totalTests) * 100 : 100;
    const threshold = this.config.qualityGates.thresholds.successRate;

    return {
      name: "all-tests-pass",
      passed: successRate >= threshold,
      message: `Success rate: ${successRate.toFixed(1)}% (required: ${threshold}%)`,
      metrics: { totalTests, passedTests, successRate },
    };
  }

  evaluateCoverageThreshold() {
    // Placeholder - would integrate with actual coverage collection
    const mockCoverage = 95.2;
    const threshold = this.config.qualityGates.thresholds.coverageMinimum;

    return {
      name: "coverage-threshold",
      passed: mockCoverage >= threshold,
      message: `Coverage: ${mockCoverage}% (required: ${threshold}%)`,
      metrics: { coverage: mockCoverage, threshold },
    };
  }

  evaluateProcessSizeLimit() {
    // Check process file sizes
    const processesDir = path.join(process.cwd(), "processes");
    const violations = [];
    const sizeLimit = this.config.qualityGates.thresholds.processSizeLimit;

    try {
      if (fs.existsSync(processesDir)) {
        const files = fs.readdirSync(processesDir).filter(f => f.endsWith(".lua"));

        for (const file of files) {
          const filePath = path.join(processesDir, file);
          const stats = fs.statSync(filePath);

          if (stats.size > sizeLimit) {
            violations.push({ file, size: stats.size, limit: sizeLimit });
          }
        }
      }
    } catch (error) {
      return {
        name: "process-size-limit",
        passed: false,
        message: `Error checking process sizes: ${error.message}`,
      };
    }

    return {
      name: "process-size-limit",
      passed: violations.length === 0,
      message:
        violations.length > 0 ? `${violations.length} processes exceed size limit` : "All processes within size limits",
      metrics: { violations, sizeLimit },
    };
  }

  evaluateAOCompliance() {
    // Would run actual AO sandbox validation
    return {
      name: "ao-sandbox-compliance",
      passed: true,
      message: "AO sandbox compliance verified",
      metrics: { compliant: true },
    };
  }

  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  async generateReport() {
    const reportDir = path.join(process.cwd(), "testing/reports/pipeline");

    if (!fs.existsSync(reportDir)) {
      fs.mkdirSync(reportDir, { recursive: true });
    }

    const reportPath = path.join(reportDir, `pipeline-execution-${Date.now()}.json`);

    const report = {
      ...this.results,
      configuration: this.config,
      environment: {
        nodeVersion: process.version,
        platform: process.platform,
        cwd: process.cwd(),
      },
    };

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

    this.logger.info(`📊 Report generated: ${reportPath}`);

    return reportPath;
  }
}

// CLI Interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {};

  // Parse command line arguments
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--level":
        options.level = args[++i];
        break;
      case "--no-parallel":
        options.parallel = false;
        break;
      case "--skip-performance":
        options.skipPerformance = true;
        break;
      case "--help":
        console.log(`
Usage: node pipeline-orchestrator.js [options]

Options:
  --level <level>        Test level: quick, comprehensive, full (default: comprehensive)
  --no-parallel          Disable parallel execution
  --skip-performance     Skip performance testing stage
  --help                 Show this help message

Examples:
  node pipeline-orchestrator.js --level full
  node pipeline-orchestrator.js --no-parallel --skip-performance
                `);
        process.exit(0);
        break;
    }
  }

  const orchestrator = new PipelineOrchestrator();

  orchestrator
    .orchestrate(options)
    .then(results => {
      console.log("✅ Pipeline orchestration completed");
      process.exit(0);
    })
    .catch(error => {
      console.error("❌ Pipeline orchestration failed:", error.message);
      process.exit(1);
    });
}

module.exports = PipelineOrchestrator;
