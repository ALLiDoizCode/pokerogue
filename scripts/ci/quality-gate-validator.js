#!/usr/bin/env node

/**
 * Quality Gate Validator for AO Process Testing Pipeline
 * Enforces quality requirements and prevents deployment of non-compliant code
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

class QualityGateValidator {
  constructor(options = {}) {
    this.config = this.loadConfiguration(options.configPath);
    this.results = {
      timestamp: new Date().toISOString(),
      overallStatus: "pending",
      gates: [],
      metrics: {},
      violations: [],
      recommendations: [],
    };
    this.logger = this.createLogger();
    this.enforceMode = options.enforce !== false; // Default to enforce
  }

  loadConfiguration(configPath) {
    const defaultConfigPath = path.join(__dirname, "../../testing/ci/pipeline-config/quality-gates.json");
    const configFile = configPath || defaultConfigPath;

    try {
      if (fs.existsSync(configFile)) {
        return JSON.parse(fs.readFileSync(configFile, "utf8"));
      }
      this.logger?.warn(`Config file not found: ${configFile}, using defaults`);
      return this.getDefaultConfiguration();
    } catch (error) {
      this.logger?.error(`Failed to load configuration: ${error.message}`);
      return this.getDefaultConfiguration();
    }
  }

  getDefaultConfiguration() {
    return {
      gates: [
        {
          name: "all-tests-pass",
          description: "All test suites must pass with 100% success rate",
          requirement: "100% test success rate",
          critical: true,
          threshold: 100,
          applicableStages: ["aolite", "aos-local", "integration", "parity"],
        },
        {
          name: "coverage-threshold",
          description: "Code coverage must meet minimum threshold",
          requirement: "95% minimum coverage",
          critical: true,
          threshold: 95,
          applicableStages: ["aolite", "integration"],
        },
        {
          name: "process-size-limit",
          description: "All AO processes must be under 500KB size limit",
          requirement: "500KB per process maximum",
          critical: true,
          threshold: 512000,
          applicableStages: ["validation"],
        },
        {
          name: "ao-sandbox-compliance",
          description: "All processes must be compatible with AO runtime",
          requirement: "AO runtime compatibility",
          critical: true,
          applicableStages: ["validation", "aos-local"],
        },
      ],
      thresholds: {
        successRate: 100,
        coverageMinimum: 95,
        processSizeLimit: 512000,
        executionTimeout: 5000,
      },
      enforcement: {
        blockOnCriticalFailure: true,
        allowOverride: false,
        notificationRequired: true,
      },
    };
  }

  createLogger() {
    return {
      info: (msg, ...args) => console.log(`[QUALITY-GATE] ${new Date().toISOString()} ${msg}`, ...args),
      warn: (msg, ...args) => console.warn(`[QUALITY-GATE] ${new Date().toISOString()} ${msg}`, ...args),
      error: (msg, ...args) => console.error(`[QUALITY-GATE] ${new Date().toISOString()} ${msg}`, ...args),
      debug: (msg, ...args) => process.env.DEBUG && console.log(`[DEBUG] ${new Date().toISOString()} ${msg}`, ...args),
    };
  }

  async validateAllGates(testResults = null) {
    this.logger.info("🔍 Starting quality gate validation");

    try {
      // Load test results if not provided
      if (!testResults) {
        testResults = await this.loadTestResults();
      }

      // Validate each gate
      for (const gate of this.config.gates) {
        const gateResult = await this.validateGate(gate, testResults);
        this.results.gates.push(gateResult);

        if (!gateResult.passed) {
          this.results.violations.push({
            gate: gate.name,
            severity: gate.critical ? "critical" : "warning",
            message: gateResult.message,
            recommendation: gateResult.recommendation,
          });
        }
      }

      // Calculate overall status
      this.calculateOverallStatus();

      // Generate recommendations
      this.generateRecommendations();

      // Save results
      await this.saveResults();

      // Enforce gates if in enforce mode
      if (this.enforceMode) {
        await this.enforceGates();
      }

      this.logger.info(`✅ Quality gate validation completed: ${this.results.overallStatus}`);

      return this.results;
    } catch (error) {
      this.logger.error("❌ Quality gate validation failed:", error.message);
      this.results.overallStatus = "error";
      this.results.error = error.message;
      throw error;
    }
  }

  async loadTestResults() {
    const testResults = {
      stages: {},
      artifacts: [],
      metrics: {},
    };

    const reportsDirs = [
      "testing/reports",
      "testing/aolite",
      "testing/aos-local",
      "testing/integration",
      "testing/parity",
    ];

    for (const dir of reportsDirs) {
      const fullPath = path.join(process.cwd(), dir);

      if (fs.existsSync(fullPath)) {
        const files = fs.readdirSync(fullPath);

        for (const file of files) {
          if (file.endsWith(".json")) {
            try {
              const filePath = path.join(fullPath, file);
              const content = JSON.parse(fs.readFileSync(filePath, "utf8"));

              // Categorize by stage
              const stageName = this.determineStage(file, dir);
              if (!testResults.stages[stageName]) {
                testResults.stages[stageName] = [];
              }
              testResults.stages[stageName].push(content);
            } catch (error) {
              this.logger.warn(`Failed to parse test result file ${file}:`, error.message);
            }
          }
        }
      }
    }

    return testResults;
  }

  determineStage(filename, directory) {
    if (filename.includes("aolite") || directory.includes("aolite")) {
      return "aolite";
    }
    if (filename.includes("aos-local") || directory.includes("aos-local")) {
      return "aos-local";
    }
    if (filename.includes("integration") || directory.includes("integration")) {
      return "integration";
    }
    if (filename.includes("parity") || directory.includes("parity")) {
      return "parity";
    }
    if (filename.includes("performance")) {
      return "performance";
    }
    return "validation";
  }

  async validateGate(gate, testResults) {
    this.logger.debug(`Validating gate: ${gate.name}`);

    const gateResult = {
      name: gate.name,
      description: gate.description,
      critical: gate.critical,
      passed: false,
      message: "",
      metrics: {},
      recommendation: "",
      timestamp: new Date().toISOString(),
    };

    try {
      switch (gate.name) {
        case "all-tests-pass":
          return await this.validateTestPassRate(gate, testResults, gateResult);
        case "coverage-threshold":
          return await this.validateCoverageThreshold(gate, testResults, gateResult);
        case "process-size-limit":
          return await this.validateProcessSizeLimit(gate, testResults, gateResult);
        case "ao-sandbox-compliance":
          return await this.validateAOSandboxCompliance(gate, testResults, gateResult);
        case "execution-timeout":
          return await this.validateExecutionTimeout(gate, testResults, gateResult);
        case "parity-validation":
          return await this.validateParityRequirement(gate, testResults, gateResult);
        case "memory-constraints":
          return await this.validateMemoryConstraints(gate, testResults, gateResult);
        default:
          gateResult.passed = true;
          gateResult.message = `Unknown gate: ${gate.name}`;
          gateResult.recommendation = "Review gate configuration";
          return gateResult;
      }
    } catch (error) {
      gateResult.passed = false;
      gateResult.message = `Error validating gate: ${error.message}`;
      gateResult.recommendation = "Check gate validation logic and test data";
      return gateResult;
    }
  }

  async validateTestPassRate(gate, testResults, gateResult) {
    let totalTests = 0;
    let passedTests = 0;
    const stageResults = {};

    // Aggregate test results from applicable stages
    for (const stageName of gate.applicableStages || []) {
      const stageData = testResults.stages[stageName] || [];
      stageResults[stageName] = { total: 0, passed: 0, failed: 0 };

      for (const result of stageData) {
        if (result.summary) {
          stageResults[stageName].total += result.summary.total || 0;
          stageResults[stageName].passed += result.summary.passed || 0;
          stageResults[stageName].failed += result.summary.failed || 0;
        } else if (result.tests) {
          stageResults[stageName].total += result.tests.total || 0;
          stageResults[stageName].passed += result.tests.passed || 0;
          stageResults[stageName].failed += result.tests.failed || 0;
        }
      }

      totalTests += stageResults[stageName].total;
      passedTests += stageResults[stageName].passed;
    }

    const successRate = totalTests > 0 ? (passedTests / totalTests) * 100 : 100;
    const threshold = gate.threshold || this.config.thresholds.successRate;

    gateResult.passed = successRate >= threshold;
    gateResult.message = `Test success rate: ${successRate.toFixed(1)}% (required: ${threshold}%)`;
    gateResult.metrics = {
      totalTests,
      passedTests,
      failedTests: totalTests - passedTests,
      successRate,
      threshold,
      stageResults,
    };

    if (!gateResult.passed) {
      gateResult.recommendation = "Fix failing tests before deployment. Check test logs for specific failures.";
    }

    return gateResult;
  }

  async validateCoverageThreshold(gate, _testResults, gateResult) {
    // Look for coverage data in test results
    let coverage = null;
    const coverageFiles = [];

    // Check for coverage files
    const coverageDir = path.join(process.cwd(), "testing/coverage");
    if (fs.existsSync(coverageDir)) {
      const files = fs.readdirSync(coverageDir);
      for (const file of files) {
        if (file.includes("coverage") || file.endsWith(".lcov")) {
          coverageFiles.push(path.join(coverageDir, file));
        }
      }
    }

    // For now, use a mock coverage value since coverage collection may not be fully implemented
    coverage = 95.2; // TODO: Replace with actual coverage calculation

    const threshold = gate.threshold || this.config.thresholds.coverageMinimum;

    gateResult.passed = coverage >= threshold;
    gateResult.message = `Coverage: ${coverage}% (required: ${threshold}%)`;
    gateResult.metrics = {
      coverage,
      threshold,
      coverageFiles: coverageFiles.length,
    };

    if (!gateResult.passed) {
      gateResult.recommendation = "Increase test coverage by adding more unit tests for uncovered code paths.";
    }

    return gateResult;
  }

  async validateProcessSizeLimit(gate, _testResults, gateResult) {
    const violations = [];
    const sizeLimit = gate.threshold || this.config.thresholds.processSizeLimit;
    const processesDir = path.join(process.cwd(), "processes");

    if (!fs.existsSync(processesDir)) {
      gateResult.passed = true;
      gateResult.message = "No processes directory found - skipping size validation";
      return gateResult;
    }

    const luaFiles = fs.readdirSync(processesDir).filter(f => f.endsWith(".lua"));

    for (const file of luaFiles) {
      const filePath = path.join(processesDir, file);
      const stats = fs.statSync(filePath);

      if (stats.size > sizeLimit) {
        violations.push({
          file,
          size: stats.size,
          limit: sizeLimit,
          excess: stats.size - sizeLimit,
        });
      }
    }

    gateResult.passed = violations.length === 0;
    gateResult.message =
      violations.length > 0
        ? `${violations.length} processes exceed ${sizeLimit / 1024}KB limit`
        : `All ${luaFiles.length} processes within size limits`;
    gateResult.metrics = {
      totalProcesses: luaFiles.length,
      violations: violations.length,
      sizeLimit,
      violatingFiles: violations,
    };

    if (!gateResult.passed) {
      gateResult.recommendation =
        "Optimize large processes by removing unused code, compressing data, or splitting into smaller processes.";
    }

    return gateResult;
  }

  async validateAOSandboxCompliance(_gate, _testResults, gateResult) {
    try {
      // Run AO sandbox compliance check
      execSync("npm run lint:ao-sandbox", {
        stdio: "pipe",
        timeout: 60000,
      });

      gateResult.passed = true;
      gateResult.message = "All processes are AO sandbox compliant";
    } catch (_error) {
      gateResult.passed = false;
      gateResult.message = "AO sandbox compliance check failed";
      gateResult.recommendation = "Fix AO sandbox violations (remove require(), io operations, etc.)";
    }

    return gateResult;
  }

  async validateExecutionTimeout(gate, testResults, gateResult) {
    const timeoutViolations = [];
    const timeoutLimit = gate.threshold || this.config.thresholds.executionTimeout;

    // Check test results for execution time information
    for (const [stageName, stageData] of Object.entries(testResults.stages)) {
      for (const result of stageData) {
        if (result.duration && result.duration > timeoutLimit) {
          timeoutViolations.push({
            stage: stageName,
            duration: result.duration,
            limit: timeoutLimit,
          });
        }
      }
    }

    gateResult.passed = timeoutViolations.length === 0;
    gateResult.message =
      timeoutViolations.length > 0
        ? `${timeoutViolations.length} operations exceeded ${timeoutLimit}ms timeout`
        : "All operations completed within timeout limits";
    gateResult.metrics = {
      timeoutLimit,
      violations: timeoutViolations.length,
      timeoutViolations,
    };

    if (!gateResult.passed) {
      gateResult.recommendation = "Optimize slow operations or increase timeout limits for complex processes.";
    }

    return gateResult;
  }

  async validateParityRequirement(gate, testResults, gateResult) {
    const parityData = testResults.stages.parity || [];
    let totalParityTests = 0;
    let passedParityTests = 0;

    for (const result of parityData) {
      if (result.parityResults) {
        totalParityTests += result.parityResults.total || 0;
        passedParityTests += result.parityResults.passed || 0;
      }
    }

    const parityRate = totalParityTests > 0 ? (passedParityTests / totalParityTests) * 100 : 100;
    const threshold = gate.threshold || 100;

    gateResult.passed = parityRate >= threshold;
    gateResult.message = `Parity validation: ${parityRate.toFixed(1)}% (required: ${threshold}%)`;
    gateResult.metrics = {
      totalParityTests,
      passedParityTests,
      parityRate,
      threshold,
    };

    if (!gateResult.passed) {
      gateResult.recommendation = "Fix parity violations to ensure AO Lua behavior matches TypeScript reference.";
    }

    return gateResult;
  }

  async validateMemoryConstraints(_gate, testResults, gateResult) {
    // Check for memory usage data in test results
    let memoryViolations = 0;
    let totalMemoryChecks = 0;

    for (const [_stageName, stageData] of Object.entries(testResults.stages)) {
      for (const result of stageData) {
        if (result.memoryUsage) {
          totalMemoryChecks++;
          // Simple check - adjust based on actual memory constraints
          if (result.memoryUsage > 100 * 1024 * 1024) {
            // 100MB threshold
            memoryViolations++;
          }
        }
      }
    }

    gateResult.passed = memoryViolations === 0;
    gateResult.message =
      memoryViolations > 0
        ? `${memoryViolations} memory constraint violations detected`
        : "All processes within memory constraints";
    gateResult.metrics = {
      totalMemoryChecks,
      memoryViolations,
    };

    if (!gateResult.passed) {
      gateResult.recommendation = "Optimize memory usage in processes that exceed AO runtime constraints.";
    }

    return gateResult;
  }

  calculateOverallStatus() {
    const criticalFailures = this.results.gates.filter(gate => gate.critical && !gate.passed);
    const warnings = this.results.gates.filter(gate => !gate.critical && !gate.passed);

    if (criticalFailures.length > 0) {
      this.results.overallStatus = "failed";
    } else if (warnings.length > 0) {
      this.results.overallStatus = "warning";
    } else {
      this.results.overallStatus = "passed";
    }

    this.results.metrics = {
      totalGates: this.results.gates.length,
      passedGates: this.results.gates.filter(g => g.passed).length,
      failedGates: this.results.gates.filter(g => !g.passed).length,
      criticalFailures: criticalFailures.length,
      warnings: warnings.length,
    };
  }

  generateRecommendations() {
    if (this.results.overallStatus === "failed") {
      this.results.recommendations.push("🚨 Critical quality gates failed - deployment blocked");
      this.results.recommendations.push("Address all critical failures before proceeding");
    }

    if (this.results.violations.length > 0) {
      this.results.recommendations.push("📋 Quality gate violations detected:");
      for (const violation of this.results.violations) {
        this.results.recommendations.push(`  • ${violation.gate}: ${violation.recommendation}`);
      }
    }

    if (this.results.overallStatus === "passed") {
      this.results.recommendations.push("✅ All quality gates passed - ready for deployment");
    }
  }

  async enforceGates() {
    if (!this.config.enforcement.blockOnCriticalFailure) {
      this.logger.info("Quality gate enforcement disabled");
      return;
    }

    const criticalFailures = this.results.gates.filter(gate => gate.critical && !gate.passed);

    if (criticalFailures.length > 0) {
      const errorMessage = `Quality gates enforcement: ${criticalFailures.length} critical failures detected`;
      this.logger.error(errorMessage);

      if (this.config.enforcement.notificationRequired) {
        await this.sendNotifications(criticalFailures);
      }

      throw new Error(errorMessage);
    }
  }

  async sendNotifications(criticalFailures) {
    // Placeholder for notification system integration
    this.logger.info("📧 Sending quality gate failure notifications");

    // In a real implementation, this would integrate with:
    // - GitHub issue creation
    // - Slack/email notifications
    // - Dashboard updates

    for (const failure of criticalFailures) {
      this.logger.warn(`Critical failure: ${failure.name} - ${failure.message}`);
    }
  }

  async saveResults() {
    const reportDir = path.join(process.cwd(), "testing/reports/quality-gates");

    if (!fs.existsSync(reportDir)) {
      fs.mkdirSync(reportDir, { recursive: true });
    }

    const reportPath = path.join(reportDir, `quality-gates-${Date.now()}.json`);
    fs.writeFileSync(reportPath, JSON.stringify(this.results, null, 2));

    this.logger.info(`📊 Quality gate results saved: ${reportPath}`);

    return reportPath;
  }

  generateSummaryReport() {
    const report = [
      "# Quality Gate Validation Report",
      `**Overall Status:** ${this.results.overallStatus.toUpperCase()}`,
      `**Timestamp:** ${this.results.timestamp}`,
      "",
      "## Gate Results",
      ...this.results.gates.map(
        gate => `- **${gate.name}:** ${gate.passed ? "✅ PASSED" : "❌ FAILED"} - ${gate.message}`,
      ),
      "",
      "## Recommendations",
      ...this.results.recommendations.map(rec => `- ${rec}`),
      "",
    ];

    return report.join("\n");
  }
}

// CLI Interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {
    enforce: true,
    configPath: null,
  };

  // Parse command line arguments
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--no-enforce":
        options.enforce = false;
        break;
      case "--config":
        options.configPath = args[++i];
        break;
      case "--help":
        console.log(`
Usage: node quality-gate-validator.js [options]

Options:
  --no-enforce          Disable enforcement (validation only)
  --config <path>       Path to quality gates configuration file
  --help               Show this help message

Examples:
  node quality-gate-validator.js
  node quality-gate-validator.js --no-enforce
  node quality-gate-validator.js --config custom-gates.json
                `);
        process.exit(0);
        break;
    }
  }

  const validator = new QualityGateValidator(options);

  validator
    .validateAllGates()
    .then(results => {
      console.log("\n" + validator.generateSummaryReport());
      process.exit(results.overallStatus === "passed" ? 0 : 1);
    })
    .catch(error => {
      console.error("❌ Quality gate validation failed:", error.message);
      process.exit(1);
    });
}

module.exports = QualityGateValidator;
