#!/usr/bin/env node

/**
 * Test Result Aggregator for Multi-Framework Testing Pipeline
 * Collects, analyzes, and aggregates results from aolite, aos-local, integration, and parity testing
 */

const fs = require("fs");
const path = require("path");
const glob = require("glob");

class TestResultAggregator {
  constructor(options = {}) {
    this.config = {
      outputDir: options.outputDir || "testing/reports/aggregated",
      includeTrends: options.includeTrends !== false,
      includeMetrics: options.includeMetrics !== false,
      retentionDays: options.retentionDays || 30,
      ...options,
    };

    this.aggregatedResults = {
      metadata: {
        timestamp: new Date().toISOString(),
        version: "1.0.0",
        pipelineId: this.generatePipelineId(),
        branch: process.env.GITHUB_REF_NAME || "unknown",
        commit: process.env.GITHUB_SHA || "unknown",
      },
      summary: {
        overallStatus: "pending",
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        skippedTests: 0,
        successRate: 0,
        totalDuration: 0,
        averageDuration: 0,
      },
      frameworks: {},
      stages: {},
      processes: {},
      coverage: {},
      artifacts: [],
      trends: [],
      metrics: {},
      issues: [],
      recommendations: [],
    };

    this.logger = this.createLogger();
    this.frameworkParsers = this.initializeFrameworkParsers();
  }

  createLogger() {
    return {
      info: (msg, ...args) => console.log(`[AGGREGATOR] ${new Date().toISOString()} ${msg}`, ...args),
      warn: (msg, ...args) => console.warn(`[AGGREGATOR] ${new Date().toISOString()} ${msg}`, ...args),
      error: (msg, ...args) => console.error(`[AGGREGATOR] ${new Date().toISOString()} ${msg}`, ...args),
      debug: (msg, ...args) => process.env.DEBUG && console.log(`[DEBUG] ${new Date().toISOString()} ${msg}`, ...args),
    };
  }

  generatePipelineId() {
    return `pipeline-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  initializeFrameworkParsers() {
    return {
      aolite: this.parseAoliteResults.bind(this),
      "aos-local": this.parseAosLocalResults.bind(this),
      integration: this.parseIntegrationResults.bind(this),
      parity: this.parseParityResults.bind(this),
      performance: this.parsePerformanceResults.bind(this),
      validation: this.parseValidationResults.bind(this),
    };
  }

  async aggregateAllResults() {
    this.logger.info("🔄 Starting test result aggregation");

    try {
      // Discover and load all test result files
      const resultFiles = await this.discoverResultFiles();
      this.logger.info(`Found ${resultFiles.length} result files to process`);

      // Process each result file
      for (const file of resultFiles) {
        await this.processResultFile(file);
      }

      // Calculate aggregated metrics
      this.calculateAggregatedMetrics();

      // Generate trends if enabled
      if (this.config.includeTrends) {
        await this.generateTrends();
      }

      // Analyze results and generate recommendations
      this.analyzeResults();

      // Save aggregated results
      const outputPath = await this.saveAggregatedResults();

      // Generate reports
      await this.generateReports();

      this.logger.info(`✅ Test result aggregation completed: ${outputPath}`);

      return this.aggregatedResults;
    } catch (error) {
      this.logger.error("❌ Test result aggregation failed:", error.message);
      throw error;
    }
  }

  async discoverResultFiles() {
    const resultDirs = [
      "testing/reports",
      "testing/aolite",
      "testing/aos-local",
      "testing/integration",
      "testing/parity",
      "testing/performance",
      "testing/coverage",
    ];

    const resultFiles = [];
    const baseDir = process.cwd();

    for (const dir of resultDirs) {
      const fullDir = path.join(baseDir, dir);

      if (fs.existsSync(fullDir)) {
        try {
          // Find JSON files
          const jsonFiles = glob.sync("**/*.json", { cwd: fullDir });

          for (const jsonFile of jsonFiles) {
            const fullPath = path.join(fullDir, jsonFile);
            const stats = fs.statSync(fullPath);

            resultFiles.push({
              path: fullPath,
              relativePath: path.join(dir, jsonFile),
              framework: this.determineFramework(jsonFile, dir),
              stage: this.determineStage(jsonFile, dir),
              size: stats.size,
              modified: stats.mtime.toISOString(),
            });
          }
        } catch (error) {
          this.logger.warn(`Error processing directory ${dir}:`, error.message);
        }
      }
    }

    return resultFiles.sort((a, b) => new Date(b.modified) - new Date(a.modified));
  }

  determineFramework(filename, directory) {
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
    if (filename.includes("performance") || directory.includes("performance")) {
      return "performance";
    }
    if (filename.includes("coverage") || directory.includes("coverage")) {
      return "coverage";
    }
    return "validation";
  }

  determineStage(filename, _directory) {
    if (filename.includes("stage1") || filename.includes("validation")) {
      return "stage1-validation";
    }
    if (filename.includes("stage2") || filename.includes("parallel")) {
      return "stage2-parallel";
    }
    if (filename.includes("stage3") || filename.includes("integration")) {
      return "stage3-integration";
    }
    if (filename.includes("stage4") || filename.includes("parity")) {
      return "stage4-parity";
    }
    if (filename.includes("stage5") || filename.includes("performance")) {
      return "stage5-performance";
    }
    return "unknown";
  }

  async processResultFile(file) {
    try {
      this.logger.debug(`Processing result file: ${file.relativePath}`);

      const content = JSON.parse(fs.readFileSync(file.path, "utf8"));
      const framework = file.framework;

      // Initialize framework data if not exists
      if (!this.aggregatedResults.frameworks[framework]) {
        this.aggregatedResults.frameworks[framework] = {
          name: framework,
          totalTests: 0,
          passedTests: 0,
          failedTests: 0,
          skippedTests: 0,
          duration: 0,
          results: [],
          processes: {},
          coverage: null,
          artifacts: [],
        };
      }

      // Initialize stage data if not exists
      if (!this.aggregatedResults.stages[file.stage]) {
        this.aggregatedResults.stages[file.stage] = {
          name: file.stage,
          status: "unknown",
          startTime: null,
          endTime: null,
          duration: 0,
          frameworks: [],
        };
      }

      // Parse using framework-specific parser
      const parser = this.frameworkParsers[framework];
      if (parser) {
        const parsedResult = await parser(content, file);
        this.aggregatedResults.frameworks[framework].results.push(parsedResult);

        // Update framework totals
        this.updateFrameworkTotals(framework, parsedResult);

        // Track artifacts
        if (parsedResult.artifacts) {
          this.aggregatedResults.frameworks[framework].artifacts.push(...parsedResult.artifacts);
        }
      }

      // Add to artifacts list
      this.aggregatedResults.artifacts.push({
        path: file.relativePath,
        framework: framework,
        stage: file.stage,
        size: file.size,
        modified: file.modified,
      });
    } catch (error) {
      this.logger.warn(`Failed to process result file ${file.path}:`, error.message);
      this.aggregatedResults.issues.push({
        type: "file-processing-error",
        file: file.relativePath,
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  }

  async parseAoliteResults(content, file) {
    const result = {
      framework: "aolite",
      file: file.relativePath,
      timestamp: content.timestamp || file.modified,
      tests: {
        total: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
      },
      processes: {},
      duration: content.duration || 0,
      coverage: content.coverage || null,
      artifacts: content.artifacts || [],
    };

    // Parse aolite-specific test results
    if (content.testResults) {
      result.tests = { ...content.testResults };
    } else if (content.summary) {
      result.tests = { ...content.summary };
    }

    // Extract process-specific results
    if (content.processes) {
      for (const [processName, processResult] of Object.entries(content.processes)) {
        result.processes[processName] = {
          tests: processResult.tests || { total: 0, passed: 0, failed: 0 },
          duration: processResult.duration || 0,
          coverage: processResult.coverage || null,
        };
      }
    }

    return result;
  }

  async parseAosLocalResults(content, file) {
    const result = {
      framework: "aos-local",
      file: file.relativePath,
      timestamp: content.timestamp || file.modified,
      tests: {
        total: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
      },
      deployment: {
        successful: 0,
        failed: 0,
        processes: [],
      },
      messageFlow: {
        totalMessages: 0,
        successfulMessages: 0,
        failedMessages: 0,
      },
      duration: content.duration || 0,
      artifacts: content.artifacts || [],
    };

    // Parse deployment results
    if (content.deployment) {
      result.deployment = { ...content.deployment };
    }

    // Parse message flow results
    if (content.messageFlow) {
      result.messageFlow = { ...content.messageFlow };
    }

    // Parse test results
    if (content.testSuites) {
      for (const suite of content.testSuites) {
        result.tests.total += suite.tests || 0;
        result.tests.passed += suite.passed || 0;
        result.tests.failed += suite.failed || 0;
        result.tests.skipped += suite.skipped || 0;
      }
    }

    return result;
  }

  async parseIntegrationResults(content, file) {
    const result = {
      framework: "integration",
      file: file.relativePath,
      timestamp: content.timestamp || file.modified,
      scenarios: {
        total: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
      },
      workflows: {},
      coordination: {
        successful: 0,
        failed: 0,
        timeouts: 0,
      },
      stateConsistency: {
        checks: 0,
        passed: 0,
        failed: 0,
      },
      duration: content.duration || 0,
      artifacts: content.artifacts || [],
    };

    // Parse scenario results
    if (content.scenarios) {
      for (const scenario of content.scenarios) {
        result.scenarios.total++;
        if (scenario.status === "passed") {
          result.scenarios.passed++;
        } else if (scenario.status === "failed") {
          result.scenarios.failed++;
        } else {
          result.scenarios.skipped++;
        }

        // Track workflow performance
        if (scenario.workflow) {
          if (!result.workflows[scenario.workflow]) {
            result.workflows[scenario.workflow] = { executions: 0, passed: 0, failed: 0, avgDuration: 0 };
          }
          result.workflows[scenario.workflow].executions++;
          if (scenario.status === "passed") {
            result.workflows[scenario.workflow].passed++;
          } else {
            result.workflows[scenario.workflow].failed++;
          }
        }
      }
    }

    // Parse coordination results
    if (content.coordination) {
      result.coordination = { ...content.coordination };
    }

    // Parse state consistency results
    if (content.stateConsistency) {
      result.stateConsistency = { ...content.stateConsistency };
    }

    return result;
  }

  async parseParityResults(content, file) {
    const result = {
      framework: "parity",
      file: file.relativePath,
      timestamp: content.timestamp || file.modified,
      parity: {
        total: 0,
        passed: 0,
        failed: 0,
        rate: 0,
      },
      categories: {},
      deviations: [],
      duration: content.duration || 0,
      artifacts: content.artifacts || [],
    };

    // Parse parity validation results
    if (content.parityResults) {
      result.parity = { ...content.parityResults };
    } else if (content.summary) {
      result.parity.total = content.summary.total || 0;
      result.parity.passed = content.summary.passed || 0;
      result.parity.failed = content.summary.failed || 0;
      result.parity.rate = result.parity.total > 0 ? (result.parity.passed / result.parity.total) * 100 : 0;
    }

    // Parse category-specific results
    if (content.categories) {
      result.categories = { ...content.categories };
    }

    // Parse deviations
    if (content.deviations) {
      result.deviations = [...content.deviations];
    }

    return result;
  }

  async parsePerformanceResults(content, file) {
    const result = {
      framework: "performance",
      file: file.relativePath,
      timestamp: content.timestamp || file.modified,
      benchmarks: {},
      baseline: content.baseline || null,
      regression: {
        detected: false,
        percentage: 0,
        threshold: 120,
      },
      metrics: {
        averageExecutionTime: 0,
        peakMemoryUsage: 0,
        throughput: 0,
      },
      duration: content.duration || 0,
      artifacts: content.artifacts || [],
    };

    // Parse benchmark results
    if (content.benchmarks) {
      result.benchmarks = { ...content.benchmarks };
    }

    // Calculate regression
    if (content.baseline && content.current) {
      const regressionPercentage = ((content.current - content.baseline) / content.baseline) * 100;
      result.regression.percentage = regressionPercentage;
      result.regression.detected = regressionPercentage > result.regression.threshold;
    }

    // Parse metrics
    if (content.metrics) {
      result.metrics = { ...content.metrics };
    }

    return result;
  }

  async parseValidationResults(content, file) {
    const result = {
      framework: "validation",
      file: file.relativePath,
      timestamp: content.timestamp || file.modified,
      validation: {
        aoCompliance: { passed: false, violations: [] },
        sizeConstraints: { passed: false, violations: [] },
        syntaxCheck: { passed: false, errors: [] },
      },
      duration: content.duration || 0,
      artifacts: content.artifacts || [],
    };

    // Parse validation results
    if (content.validation) {
      result.validation = { ...content.validation };
    }

    return result;
  }

  updateFrameworkTotals(framework, parsedResult) {
    const fw = this.aggregatedResults.frameworks[framework];

    if (parsedResult.tests) {
      fw.totalTests += parsedResult.tests.total || 0;
      fw.passedTests += parsedResult.tests.passed || 0;
      fw.failedTests += parsedResult.tests.failed || 0;
      fw.skippedTests += parsedResult.tests.skipped || 0;
    }

    if (parsedResult.scenarios) {
      fw.totalTests += parsedResult.scenarios.total || 0;
      fw.passedTests += parsedResult.scenarios.passed || 0;
      fw.failedTests += parsedResult.scenarios.failed || 0;
      fw.skippedTests += parsedResult.scenarios.skipped || 0;
    }

    if (parsedResult.parity) {
      fw.totalTests += parsedResult.parity.total || 0;
      fw.passedTests += parsedResult.parity.passed || 0;
      fw.failedTests += parsedResult.parity.failed || 0;
    }

    fw.duration += parsedResult.duration || 0;

    // Update coverage if available
    if (parsedResult.coverage) {
      fw.coverage = parsedResult.coverage;
    }

    // Merge process results
    if (parsedResult.processes) {
      for (const [processName, processData] of Object.entries(parsedResult.processes)) {
        if (!fw.processes[processName]) {
          fw.processes[processName] = {
            tests: { total: 0, passed: 0, failed: 0 },
            duration: 0,
            coverage: null,
          };
        }

        const process = fw.processes[processName];
        if (processData.tests) {
          process.tests.total += processData.tests.total || 0;
          process.tests.passed += processData.tests.passed || 0;
          process.tests.failed += processData.tests.failed || 0;
        }
        process.duration += processData.duration || 0;
        if (processData.coverage) {
          process.coverage = processData.coverage;
        }
      }
    }
  }

  calculateAggregatedMetrics() {
    this.logger.info("📊 Calculating aggregated metrics");

    // Calculate summary totals
    let totalTests = 0;
    let passedTests = 0;
    let failedTests = 0;
    let skippedTests = 0;
    let totalDuration = 0;

    for (const framework of Object.values(this.aggregatedResults.frameworks)) {
      totalTests += framework.totalTests;
      passedTests += framework.passedTests;
      failedTests += framework.failedTests;
      skippedTests += framework.skippedTests;
      totalDuration += framework.duration;
    }

    this.aggregatedResults.summary = {
      overallStatus: failedTests === 0 ? "passed" : "failed",
      totalTests,
      passedTests,
      failedTests,
      skippedTests,
      successRate: totalTests > 0 ? (passedTests / totalTests) * 100 : 0,
      totalDuration,
      averageDuration: totalTests > 0 ? totalDuration / totalTests : 0,
    };

    // Calculate framework metrics
    this.calculateFrameworkMetrics();

    // Calculate process metrics
    this.calculateProcessMetrics();

    // Calculate stage metrics
    this.calculateStageMetrics();
  }

  calculateFrameworkMetrics() {
    for (const [_name, framework] of Object.entries(this.aggregatedResults.frameworks)) {
      framework.successRate = framework.totalTests > 0 ? (framework.passedTests / framework.totalTests) * 100 : 0;
      framework.averageDuration = framework.totalTests > 0 ? framework.duration / framework.totalTests : 0;
    }
  }

  calculateProcessMetrics() {
    const allProcesses = new Set();

    // Collect all process names
    for (const framework of Object.values(this.aggregatedResults.frameworks)) {
      Object.keys(framework.processes).forEach(process => allProcesses.add(process));
    }

    // Calculate metrics for each process
    for (const processName of allProcesses) {
      const processMetrics = {
        name: processName,
        frameworks: {},
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        successRate: 0,
        totalDuration: 0,
        averageCoverage: null,
      };

      const coverageValues = [];

      for (const [frameworkName, framework] of Object.entries(this.aggregatedResults.frameworks)) {
        if (framework.processes[processName]) {
          const processData = framework.processes[processName];
          processMetrics.frameworks[frameworkName] = processData;
          processMetrics.totalTests += processData.tests.total;
          processMetrics.passedTests += processData.tests.passed;
          processMetrics.failedTests += processData.tests.failed;
          processMetrics.totalDuration += processData.duration;

          if (processData.coverage) {
            coverageValues.push(processData.coverage);
          }
        }
      }

      processMetrics.successRate =
        processMetrics.totalTests > 0 ? (processMetrics.passedTests / processMetrics.totalTests) * 100 : 0;

      processMetrics.averageCoverage =
        coverageValues.length > 0 ? coverageValues.reduce((sum, val) => sum + val, 0) / coverageValues.length : null;

      this.aggregatedResults.processes[processName] = processMetrics;
    }
  }

  calculateStageMetrics() {
    // This would be enhanced based on actual stage data structure
    for (const [_stageName, stage] of Object.entries(this.aggregatedResults.stages)) {
      stage.status = "completed"; // Simplified for now
    }
  }

  async generateTrends() {
    this.logger.info("📈 Generating trend analysis");

    try {
      // Look for historical data
      const historicalData = await this.loadHistoricalData();

      if (historicalData.length > 0) {
        this.aggregatedResults.trends = this.calculateTrends(historicalData);
      }
    } catch (error) {
      this.logger.warn("Failed to generate trends:", error.message);
    }
  }

  async loadHistoricalData() {
    const historicalDir = path.join(this.config.outputDir, "historical");
    const historical = [];

    if (fs.existsSync(historicalDir)) {
      const files = fs
        .readdirSync(historicalDir)
        .filter(f => f.startsWith("aggregated-") && f.endsWith(".json"))
        .sort()
        .slice(-10); // Last 10 runs

      for (const file of files) {
        try {
          const data = JSON.parse(fs.readFileSync(path.join(historicalDir, file), "utf8"));
          historical.push({
            timestamp: data.metadata.timestamp,
            summary: data.summary,
            frameworks: data.frameworks,
          });
        } catch (error) {
          this.logger.warn(`Failed to load historical data from ${file}:`, error.message);
        }
      }
    }

    return historical;
  }

  calculateTrends(historicalData) {
    const trends = {
      successRate: this.calculateTrend(historicalData, "summary.successRate"),
      testCount: this.calculateTrend(historicalData, "summary.totalTests"),
      duration: this.calculateTrend(historicalData, "summary.totalDuration"),
      frameworks: {},
    };

    // Calculate framework trends
    for (const frameworkName of Object.keys(this.aggregatedResults.frameworks)) {
      trends.frameworks[frameworkName] = {
        successRate: this.calculateTrend(historicalData, `frameworks.${frameworkName}.successRate`),
        testCount: this.calculateTrend(historicalData, `frameworks.${frameworkName}.totalTests`),
      };
    }

    return trends;
  }

  calculateTrend(data, path) {
    const values = data.map(item => this.getNestedValue(item, path)).filter(v => v !== undefined);

    if (values.length < 2) {
      return { trend: "insufficient-data", values };
    }

    const first = values[0];
    const last = values[values.length - 1];
    const change = ((last - first) / first) * 100;

    return {
      trend: change > 5 ? "improving" : change < -5 ? "declining" : "stable",
      change: change,
      values: values,
    };
  }

  getNestedValue(obj, path) {
    return path.split(".").reduce((current, key) => current?.[key], obj);
  }

  analyzeResults() {
    this.logger.info("🔍 Analyzing results and generating recommendations");

    const issues = [];
    const recommendations = [];

    // Overall success rate analysis
    if (this.aggregatedResults.summary.successRate < 100) {
      issues.push({
        type: "test-failures",
        severity: "high",
        message: `${this.aggregatedResults.summary.failedTests} tests failed (${(100 - this.aggregatedResults.summary.successRate).toFixed(1)}% failure rate)`,
        affectedTests: this.aggregatedResults.summary.failedTests,
      });
      recommendations.push("Address failing tests before deployment");
    }

    // Framework-specific analysis
    for (const [name, framework] of Object.entries(this.aggregatedResults.frameworks)) {
      if (framework.successRate < 100) {
        issues.push({
          type: "framework-failures",
          severity: "medium",
          framework: name,
          message: `${framework.failedTests} tests failed in ${name} framework`,
          successRate: framework.successRate,
        });
        recommendations.push(`Review ${name} framework test failures`);
      }

      if (framework.averageDuration > 10000) {
        // 10 seconds
        issues.push({
          type: "performance-concern",
          severity: "low",
          framework: name,
          message: `Average test duration in ${name} is ${(framework.averageDuration / 1000).toFixed(1)}s`,
          duration: framework.averageDuration,
        });
        recommendations.push(`Consider optimizing ${name} test performance`);
      }
    }

    // Process-specific analysis
    for (const [name, process] of Object.entries(this.aggregatedResults.processes)) {
      if (process.successRate < 100) {
        issues.push({
          type: "process-failures",
          severity: "medium",
          process: name,
          message: `Process ${name} has failing tests across frameworks`,
          successRate: process.successRate,
        });
        recommendations.push(`Focus on fixing ${name} process implementation`);
      }
    }

    // Coverage analysis
    const coverageValues = Object.values(this.aggregatedResults.frameworks)
      .map(fw => fw.coverage)
      .filter(c => c !== null);

    if (coverageValues.length > 0) {
      const avgCoverage = coverageValues.reduce((sum, val) => sum + val, 0) / coverageValues.length;
      if (avgCoverage < 95) {
        issues.push({
          type: "coverage-low",
          severity: "medium",
          message: `Average coverage is ${avgCoverage.toFixed(1)}% (target: 95%)`,
          coverage: avgCoverage,
        });
        recommendations.push("Increase test coverage to meet 95% threshold");
      }
    }

    this.aggregatedResults.issues = issues;
    this.aggregatedResults.recommendations = recommendations;
  }

  async saveAggregatedResults() {
    // Ensure output directory exists
    if (!fs.existsSync(this.config.outputDir)) {
      fs.mkdirSync(this.config.outputDir, { recursive: true });
    }

    // Save main aggregated results
    const mainOutputPath = path.join(this.config.outputDir, `aggregated-${Date.now()}.json`);
    fs.writeFileSync(mainOutputPath, JSON.stringify(this.aggregatedResults, null, 2));

    // Save historical copy
    const historicalDir = path.join(this.config.outputDir, "historical");
    if (!fs.existsSync(historicalDir)) {
      fs.mkdirSync(historicalDir, { recursive: true });
    }

    const historicalPath = path.join(
      historicalDir,
      `aggregated-${this.aggregatedResults.metadata.timestamp.replace(/[:.]/g, "-")}.json`,
    );
    fs.writeFileSync(historicalPath, JSON.stringify(this.aggregatedResults, null, 2));

    // Save latest results
    const latestPath = path.join(this.config.outputDir, "latest.json");
    fs.writeFileSync(latestPath, JSON.stringify(this.aggregatedResults, null, 2));

    this.logger.info(`📊 Aggregated results saved: ${mainOutputPath}`);

    return mainOutputPath;
  }

  async generateReports() {
    this.logger.info("📝 Generating reports");

    // Generate summary report
    await this.generateSummaryReport();

    // Generate detailed report
    await this.generateDetailedReport();

    // Generate CSV export
    await this.generateCSVReport();
  }

  async generateSummaryReport() {
    const report = [
      "# Test Results Summary",
      `**Generated:** ${this.aggregatedResults.metadata.timestamp}`,
      `**Pipeline ID:** ${this.aggregatedResults.metadata.pipelineId}`,
      `**Branch:** ${this.aggregatedResults.metadata.branch}`,
      `**Commit:** ${this.aggregatedResults.metadata.commit}`,
      "",
      "## Overall Results",
      `- **Status:** ${this.aggregatedResults.summary.overallStatus.toUpperCase()}`,
      `- **Total Tests:** ${this.aggregatedResults.summary.totalTests}`,
      `- **Success Rate:** ${this.aggregatedResults.summary.successRate.toFixed(1)}%`,
      `- **Total Duration:** ${(this.aggregatedResults.summary.totalDuration / 1000).toFixed(1)}s`,
      "",
      "## Framework Results",
      ...Object.values(this.aggregatedResults.frameworks).map(
        fw => `- **${fw.name}:** ${fw.passedTests}/${fw.totalTests} tests passed (${fw.successRate.toFixed(1)}%)`,
      ),
      "",
      "## Issues",
      ...this.aggregatedResults.issues.map(issue => `- **${issue.type}:** ${issue.message}`),
      "",
      "## Recommendations",
      ...this.aggregatedResults.recommendations.map(rec => `- ${rec}`),
      "",
    ];

    const reportPath = path.join(this.config.outputDir, "summary.md");
    fs.writeFileSync(reportPath, report.join("\n"));

    this.logger.info(`📄 Summary report generated: ${reportPath}`);
  }

  async generateDetailedReport() {
    const reportPath = path.join(this.config.outputDir, "detailed-report.json");

    const detailedReport = {
      metadata: this.aggregatedResults.metadata,
      summary: this.aggregatedResults.summary,
      frameworks: this.aggregatedResults.frameworks,
      processes: this.aggregatedResults.processes,
      stages: this.aggregatedResults.stages,
      trends: this.aggregatedResults.trends,
      issues: this.aggregatedResults.issues,
      recommendations: this.aggregatedResults.recommendations,
      artifacts: this.aggregatedResults.artifacts,
    };

    fs.writeFileSync(reportPath, JSON.stringify(detailedReport, null, 2));

    this.logger.info(`📋 Detailed report generated: ${reportPath}`);
  }

  async generateCSVReport() {
    const csvData = [];

    // Header
    csvData.push(["Framework", "Total Tests", "Passed", "Failed", "Success Rate", "Duration (s)", "Coverage (%)"]);

    // Framework data
    for (const [name, framework] of Object.entries(this.aggregatedResults.frameworks)) {
      csvData.push([
        name,
        framework.totalTests,
        framework.passedTests,
        framework.failedTests,
        framework.successRate.toFixed(1),
        (framework.duration / 1000).toFixed(1),
        framework.coverage ? framework.coverage.toFixed(1) : "N/A",
      ]);
    }

    const csvContent = csvData.map(row => row.join(",")).join("\n");
    const csvPath = path.join(this.config.outputDir, "results.csv");
    fs.writeFileSync(csvPath, csvContent);

    this.logger.info(`📊 CSV report generated: ${csvPath}`);
  }
}

// CLI Interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {};

  // Parse command line arguments
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--output":
        options.outputDir = args[++i];
        break;
      case "--no-trends":
        options.includeTrends = false;
        break;
      case "--no-metrics":
        options.includeMetrics = false;
        break;
      case "--retention":
        options.retentionDays = Number.parseInt(args[++i]);
        break;
      case "--help":
        console.log(`
Usage: node test-result-aggregator.js [options]

Options:
  --output <dir>         Output directory for aggregated results (default: testing/reports/aggregated)
  --no-trends           Disable trend analysis
  --no-metrics          Disable detailed metrics calculation
  --retention <days>    Retention period for historical data in days (default: 30)
  --help               Show this help message

Examples:
  node test-result-aggregator.js
  node test-result-aggregator.js --output reports/custom --retention 60
                `);
        process.exit(0);
        break;
    }
  }

  const aggregator = new TestResultAggregator(options);

  aggregator
    .aggregateAllResults()
    .then(results => {
      console.log("✅ Test result aggregation completed successfully");
      console.log(`Overall status: ${results.summary.overallStatus}`);
      console.log(`Total tests: ${results.summary.totalTests}`);
      console.log(`Success rate: ${results.summary.successRate.toFixed(1)}%`);
      process.exit(0);
    })
    .catch(error => {
      console.error("❌ Test result aggregation failed:", error.message);
      process.exit(1);
    });
}

module.exports = TestResultAggregator;
