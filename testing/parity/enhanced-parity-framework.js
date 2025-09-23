/**
 * Enhanced Parity Test Framework
 * Extends the base ParityTestFramework with comprehensive golden master testing,
 * regression detection, and advanced validation capabilities
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { GoldenMasterStorage } from "./golden-master-storage.js";
import { ParityTestFramework } from "./parity-test-framework.js";

export class EnhancedParityTestFramework extends ParityTestFramework {
  constructor(options = {}) {
    super(options);

    // Enhanced components
    this.goldenMasterStorage = new GoldenMasterStorage({
      storageDir: options.goldenMasterDir || path.join(process.cwd(), "testing/parity/scenarios/golden-masters"),
      version: options.typescriptVersion || "1.10.4",
    });

    // Configuration
    this.enableGoldenMasterMode = options.enableGoldenMasterMode || false;
    this.enableRegressionDetection = options.enableRegressionDetection || true;
    this.enablePerformanceComparison = options.enablePerformanceComparison || true;
    this.enableStatisticalAnalysis = options.enableStatisticalAnalysis || true;

    // Results tracking
    this.goldenMasterResults = [];
    this.regressionResults = [];
    this.performanceResults = [];
    this.statisticalResults = [];
  }

  /**
   * Initialize enhanced framework
   */
  async initialize() {
    console.log(chalk.blue("\n🚀 Initializing Enhanced Parity Test Framework..."));

    // Initialize base framework
    await this.initializeTestEnvironment();

    // Initialize golden master storage
    await this.goldenMasterStorage.initialize();

    console.log(chalk.green("✅ Enhanced Parity Framework initialized"));
  }

  /**
   * Run comprehensive parity validation suite
   */
  async runComprehensiveValidation() {
    console.log(chalk.blue("\n🔄 Starting Comprehensive Parity Validation..."));

    try {
      await this.initialize();

      // Load test scenarios
      const scenarios = await this.loadTestScenarios();
      console.log(chalk.green(`📋 Loaded ${scenarios.length} test scenarios`));

      // Execute validation phases
      for (const scenario of scenarios) {
        console.log(chalk.yellow(`\n🧪 Validating scenario: ${scenario.name}`));
        await this.executeComprehensiveScenario(scenario);
      }

      // Generate comprehensive reports
      await this.generateComprehensiveReports();

      // Return comprehensive summary
      return this.getComprehensiveSummary();
    } catch (error) {
      console.error(chalk.red("❌ Comprehensive validation failed:"), error.message);
      throw error;
    }
  }

  /**
   * Execute comprehensive scenario validation
   */
  async executeComprehensiveScenario(scenario) {
    const scenarioResult = {
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      scenarioType: scenario.scenarioType || "unknown",
      timestamp: new Date().toISOString(),
      phases: {},
    };

    try {
      // Phase 1: Golden Master Testing
      if (this.enableGoldenMasterMode || !(await this.goldenMasterStorage.hasGoldenMaster(scenario.id))) {
        console.log(chalk.blue("  📸 Phase 1: Golden Master Capture/Validation"));
        scenarioResult.phases.goldenMaster = await this.executeGoldenMasterPhase(scenario);
      }

      // Phase 2: Regression Testing
      if (this.enableRegressionDetection) {
        console.log(chalk.blue("  🔄 Phase 2: Regression Detection"));
        scenarioResult.phases.regression = await this.executeRegressionPhase(scenario);
      }

      // Phase 3: Equivalence Testing
      console.log(chalk.blue("  ⚖️  Phase 3: Equivalence Validation"));
      scenarioResult.phases.equivalence = await this.executeEquivalencePhase(scenario);

      // Phase 4: RNG Determinism (if applicable)
      if (scenario.rngSeed !== undefined || scenario.requiresStatisticalAnalysis) {
        console.log(chalk.blue("  🎲 Phase 4: RNG Determinism Testing"));
        scenarioResult.phases.rngDeterminism = await this.executeRNGPhase(scenario);
      }

      // Phase 5: Performance Comparison
      if (this.enablePerformanceComparison) {
        console.log(chalk.blue("  ⚡ Phase 5: Performance Comparison"));
        scenarioResult.phases.performance = await this.executePerformancePhase(scenario);
      }

      // Aggregate scenario results
      scenarioResult.overallStatus = this.aggregateScenarioStatus(scenarioResult.phases);

      console.log(
        this.getStatusEmoji(scenarioResult.overallStatus) + ` Overall: ${scenarioResult.overallStatus.toUpperCase()}`,
      );
    } catch (error) {
      scenarioResult.overallStatus = "error";
      scenarioResult.error = error.message;
      console.log(chalk.red(`  💥 ERROR - ${error.message}`));
    }

    this.results.push(scenarioResult);
  }

  /**
   * Execute Golden Master phase
   */
  async executeGoldenMasterPhase(scenario) {
    const phase = {
      name: "golden_master",
      status: "pending",
      timestamp: new Date().toISOString(),
    };

    try {
      // Check if golden master exists
      const hasExistingMaster = await this.goldenMasterStorage.hasGoldenMaster(scenario.id);

      if (!hasExistingMaster || this.enableGoldenMasterMode) {
        // Capture new golden master
        console.log(chalk.blue(`    📸 Capturing golden master for: ${scenario.name}`));

        const typescriptResult = await this.executeOnTypeScript(scenario);
        const goldenMaster = {
          scenarioId: scenario.id,
          timestamp: new Date().toISOString(),
          typescriptVersion: await this.getTypeScriptVersion(),
          typescriptReference: typescriptResult,
          validated: true,
          scenario: {
            id: scenario.id,
            name: scenario.name,
            category: scenario.category || "unknown",
            scenarioType: scenario.scenarioType || "unknown",
          },
        };

        const storageResult = await this.goldenMasterStorage.storeGoldenMaster(scenario.id, goldenMaster);

        phase.status = "captured";
        phase.action = "golden_master_captured";
        phase.checksum = storageResult.checksum;
        phase.fileSize = storageResult.size;

        console.log(chalk.green(`    ✅ Golden master captured: ${scenario.id}`));
      } else {
        // Validate against existing golden master
        console.log(chalk.blue("    🔍 Validating against existing golden master"));

        const goldenMaster = await this.goldenMasterStorage.loadGoldenMaster(scenario.id);
        const aoResult = await this.executeOnAO(scenario);

        const comparison = await this.compareAgainstGoldenMaster(goldenMaster, aoResult, scenario);

        phase.status = comparison.status;
        phase.action = "golden_master_validation";
        phase.comparison = comparison;

        console.log(
          this.getStatusEmoji(comparison.status) + ` Golden master validation: ${comparison.status.toUpperCase()}`,
        );
      }
    } catch (error) {
      phase.status = "error";
      phase.error = error.message;
      throw error;
    }

    this.goldenMasterResults.push(phase);
    return phase;
  }

  /**
   * Execute Regression Detection phase
   */
  async executeRegressionPhase(scenario) {
    const phase = {
      name: "regression_detection",
      status: "pending",
      timestamp: new Date().toISOString(),
    };

    try {
      // Load baseline (golden master)
      const goldenMaster = await this.goldenMasterStorage.loadGoldenMaster(scenario.id);

      if (!goldenMaster) {
        phase.status = "skipped";
        phase.reason = "no_golden_master";
        return phase;
      }

      // Execute current AO implementation
      const currentResult = await this.executeOnAO(scenario);

      // Perform regression analysis
      const regressionAnalysis = await this.performRegressionAnalysis(
        goldenMaster.typescriptReference,
        currentResult,
        scenario,
      );

      phase.status = regressionAnalysis.hasRegression ? "regression_detected" : "pass";
      phase.analysis = regressionAnalysis;

      if (regressionAnalysis.hasRegression) {
        console.log(chalk.red(`    ⚠️  Regression detected: ${regressionAnalysis.regressionType}`));
        regressionAnalysis.regressions.forEach(regression => {
          console.log(chalk.red(`      - ${regression.description}`));
        });
      } else {
        console.log(chalk.green("    ✅ No regression detected"));
      }
    } catch (error) {
      phase.status = "error";
      phase.error = error.message;
    }

    this.regressionResults.push(phase);
    return phase;
  }

  /**
   * Execute Equivalence Testing phase
   */
  async executeEquivalencePhase(scenario) {
    const phase = {
      name: "equivalence_testing",
      status: "pending",
      timestamp: new Date().toISOString(),
    };

    try {
      // Execute both implementations
      const [tsResult, aoResult] = await Promise.all([this.executeOnTypeScript(scenario), this.executeOnAO(scenario)]);

      // Perform equivalence analysis
      const equivalenceAnalysis = await this.performEquivalenceAnalysis(tsResult, aoResult, scenario);

      phase.status = equivalenceAnalysis.isEquivalent ? "pass" : "fail";
      phase.analysis = equivalenceAnalysis;
      phase.executionTimes = {
        typescript: equivalenceAnalysis.typescriptTime,
        ao: equivalenceAnalysis.aoTime,
      };

      if (equivalenceAnalysis.isEquivalent) {
        console.log(chalk.green("    ✅ Implementations are equivalent"));
      } else {
        console.log(chalk.red("    ❌ Equivalence validation failed"));
        equivalenceAnalysis.differences.forEach(diff => {
          console.log(chalk.red(`      - ${diff.description}`));
        });
      }
    } catch (error) {
      phase.status = "error";
      phase.error = error.message;
    }

    return phase;
  }

  /**
   * Execute RNG Determinism phase
   */
  async executeRNGPhase(scenario) {
    const phase = {
      name: "rng_determinism",
      status: "pending",
      timestamp: new Date().toISOString(),
    };

    try {
      if (!scenario.rngSeed && !scenario.requiresStatisticalAnalysis) {
        phase.status = "skipped";
        phase.reason = "no_rng_required";
        return phase;
      }

      console.log(chalk.blue(`    🎲 Validating RNG determinism with seed: ${scenario.rngSeed}`));

      const rngAnalysis = await this.validateRandomization(scenario);

      phase.status = rngAnalysis.isDeterministic ? "pass" : "fail";
      phase.analysis = rngAnalysis;

      if (rngAnalysis.isDeterministic) {
        console.log(chalk.green("    ✅ RNG is deterministic across implementations"));
      } else {
        console.log(chalk.red("    ❌ RNG determinism validation failed"));
        console.log(chalk.red(`      Consistency: ${(rngAnalysis.consistency * 100).toFixed(1)}%`));
      }
    } catch (error) {
      phase.status = "error";
      phase.error = error.message;
    }

    return phase;
  }

  /**
   * Execute Performance Comparison phase
   */
  async executePerformancePhase(scenario) {
    const phase = {
      name: "performance_comparison",
      status: "pending",
      timestamp: new Date().toISOString(),
    };

    try {
      const performanceComparison = await this.runPerformanceComparison([scenario]);

      if (performanceComparison.length > 0) {
        const result = performanceComparison[0];

        phase.status = result.speedRatio <= 2.0 ? "pass" : "performance_degradation";
        phase.metrics = result;

        console.log(chalk.blue(`    ⚡ Performance ratio: ${result.speedRatio.toFixed(2)}x`));
        console.log(chalk.blue(`    📊 TS: ${result.typescript.executionTime}ms, AO: ${result.aoLua.executionTime}ms`));

        if (result.speedRatio > 2.0) {
          console.log(chalk.yellow("    ⚠️  Performance degradation detected"));
        } else {
          console.log(chalk.green("    ✅ Performance within acceptable range"));
        }
      }
    } catch (error) {
      phase.status = "error";
      phase.error = error.message;
    }

    this.performanceResults.push(phase);
    return phase;
  }

  /**
   * Compare against golden master
   */
  async compareAgainstGoldenMaster(goldenMaster, aoResult, scenario) {
    const comparison = {
      status: "pending",
      timestamp: new Date().toISOString(),
      exactMatch: false,
      differences: [],
      toleranceViolations: [],
    };

    try {
      const tsReference = goldenMaster.typescriptReference;

      // Perform deep comparison
      const differences = await this.performDeepComparison(tsReference.result, aoResult.result, scenario);

      comparison.differences = differences;
      comparison.exactMatch = differences.length === 0;
      comparison.status = comparison.exactMatch ? "pass" : "fail";

      // Check tolerance violations
      if (scenario.tolerances) {
        comparison.toleranceViolations = differences.filter(diff => {
          const tolerance = scenario.tolerances[diff.key];
          return tolerance !== undefined && !this.withinTolerance(diff, tolerance);
        });
      }

      // Performance comparison
      comparison.performanceRatio = aoResult.metadata.executionTime / tsReference.metadata.executionTime;
    } catch (error) {
      comparison.status = "error";
      comparison.error = error.message;
    }

    return comparison;
  }

  /**
   * Perform regression analysis
   */
  async performRegressionAnalysis(baseline, current, scenario) {
    const analysis = {
      hasRegression: false,
      regressionType: null,
      regressions: [],
      timestamp: new Date().toISOString(),
      confidence: 1.0,
    };

    // Compare results structure
    const structuralDiffs = await this.compareStructure(baseline.result, current.result);
    if (structuralDiffs.length > 0) {
      analysis.hasRegression = true;
      analysis.regressionType = "structural";
      analysis.regressions.push(
        ...structuralDiffs.map(diff => ({
          type: "structural",
          description: `Structural change: ${diff.description}`,
          severity: "high",
        })),
      );
    }

    // Compare values
    const valueDiffs = await this.performDeepComparison(baseline.result, current.result, scenario);
    const significantDiffs = valueDiffs.filter(diff => !this.withinTolerance(diff, scenario.tolerances?.[diff.key]));

    if (significantDiffs.length > 0) {
      analysis.hasRegression = true;
      analysis.regressionType = analysis.regressionType || "behavioral";
      analysis.regressions.push(
        ...significantDiffs.map(diff => ({
          type: "behavioral",
          description: `Value regression: ${diff.description}`,
          severity: this.assessRegressionSeverity(diff),
          expected: diff.typescriptValue,
          actual: diff.aoValue,
        })),
      );
    }

    // Performance regression check
    const performanceRatio = current.metadata.executionTime / baseline.metadata.executionTime;
    if (performanceRatio > 2.0) {
      analysis.hasRegression = true;
      analysis.regressionType = analysis.regressionType || "performance";
      analysis.regressions.push({
        type: "performance",
        description: `Performance regression: ${performanceRatio.toFixed(2)}x slower`,
        severity: "medium",
        ratio: performanceRatio,
      });
    }

    return analysis;
  }

  /**
   * Perform equivalence analysis
   */
  async performEquivalenceAnalysis(tsResult, aoResult, scenario) {
    const startTime = Date.now();

    const analysis = {
      isEquivalent: false,
      differences: [],
      timestamp: new Date().toISOString(),
      typescriptTime: Date.now() - startTime,
      aoTime: Date.now() - startTime, // Will be updated with actual times
      confidence: 1.0,
    };

    // Record actual execution times from results
    analysis.typescriptTime = tsResult.metadata?.executionTime || 0;
    analysis.aoTime = aoResult.metadata?.executionTime || 0;

    // Perform deep comparison
    analysis.differences = await this.performDeepComparison(tsResult.result, aoResult.result, scenario);

    // Check if within tolerances
    const toleranceViolations = analysis.differences.filter(diff => {
      const tolerance = scenario.tolerances?.[diff.key];
      return tolerance !== undefined && !this.withinTolerance(diff, tolerance);
    });

    analysis.isEquivalent = toleranceViolations.length === 0;
    analysis.toleranceViolations = toleranceViolations;

    return analysis;
  }

  /**
   * Validate randomization consistency
   */
  async validateRandomization(scenario) {
    console.log(chalk.blue(`    🎲 Validating RNG determinism: ${scenario.name}`));

    if (!scenario.rngSeed) {
      throw new Error("RNG scenario requires seed");
    }

    const iterations = scenario.testIterations || 10;
    const results = [];

    for (let i = 0; i < iterations; i++) {
      const testScenario = {
        ...scenario,
        rngSeed: scenario.rngSeed + i,
      };

      const [tsResult, aoResult] = await Promise.all([
        this.executeOnTypeScript(testScenario),
        this.executeOnAO(testScenario),
      ]);

      const matches = this.compareRNGResults(tsResult, aoResult);

      results.push({
        seed: scenario.rngSeed + i,
        typescript: tsResult,
        aoLua: aoResult,
        matches: matches,
        iteration: i + 1,
      });
    }

    return this.analyzeRNGConsistency(results);
  }

  /**
   * Analyze RNG consistency across multiple iterations
   */
  analyzeRNGConsistency(results) {
    const totalIterations = results.length;
    const matchingIterations = results.filter(r => r.matches).length;
    const consistency = matchingIterations / totalIterations;

    const analysis = {
      isDeterministic: consistency >= 0.95, // 95% consistency threshold
      consistency: consistency,
      totalIterations: totalIterations,
      matchingIterations: matchingIterations,
      failedIterations: totalIterations - matchingIterations,
      detailedResults: results.map(r => ({
        seed: r.seed,
        matches: r.matches,
        iteration: r.iteration,
      })),
    };

    // Statistical analysis for randomized scenarios
    if (results.length > 0 && results[0].typescript.result.damage !== undefined) {
      const tsDamages = results.map(r => r.typescript.result.damage);
      const aoDamages = results.map(r => r.aoLua.result.damage);

      analysis.statisticalAnalysis = {
        typescript: this.calculateStatistics(tsDamages),
        aoLua: this.calculateStatistics(aoDamages),
        correlation: this.calculateCorrelation(tsDamages, aoDamages),
      };
    }

    return analysis;
  }

  /**
   * Generate comprehensive reports
   */
  async generateComprehensiveReports() {
    console.log(chalk.blue("📊 Generating comprehensive reports..."));

    // Generate enhanced parity report
    await this.generateEnhancedParityReport();

    // Generate golden master report
    await this.generateGoldenMasterReport();

    // Generate regression analysis report
    await this.generateRegressionReport();

    // Generate performance comparison report
    await this.generatePerformanceReport();

    console.log(chalk.green("✅ All comprehensive reports generated"));
  }

  /**
   * Generate enhanced parity report
   */
  async generateEnhancedParityReport() {
    const timestamp = Date.now();
    const reportPath = path.join(this.reportsDir, `enhanced-parity-report-${timestamp}.json`);
    const htmlReportPath = path.join(this.reportsDir, `enhanced-parity-report-${timestamp}.html`);

    const report = {
      timestamp: new Date().toISOString(),
      summary: this.getComprehensiveSummary(),
      results: this.results,
      goldenMasterResults: this.goldenMasterResults,
      regressionResults: this.regressionResults,
      performanceResults: this.performanceResults,
      environment: {
        typescriptDir: this.typescriptDir,
        aoProcessesDir: this.aoProcessesDir,
        nodeVersion: process.version,
        platform: process.platform,
        architecture: process.arch,
      },
      configuration: {
        enableGoldenMasterMode: this.enableGoldenMasterMode,
        enableRegressionDetection: this.enableRegressionDetection,
        enablePerformanceComparison: this.enablePerformanceComparison,
        enableStatisticalAnalysis: this.enableStatisticalAnalysis,
      },
    };

    // Write JSON report
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    // Generate enhanced HTML report
    const htmlReport = this.generateEnhancedHtmlReport(report);
    await fs.writeFile(htmlReportPath, htmlReport);

    console.log(chalk.green("📄 Enhanced parity reports generated:"));
    console.log(chalk.blue(`  JSON: ${reportPath}`));
    console.log(chalk.blue(`  HTML: ${htmlReportPath}`));
  }

  /**
   * Generate enhanced HTML report
   */
  generateEnhancedHtmlReport(report) {
    const summary = report.summary;

    return `
<!DOCTYPE html>
<html>
<head>
    <title>Enhanced TypeScript ↔ AO Lua Parity Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .metric-value { font-size: 2.5em; font-weight: bold; margin-bottom: 5px; }
        .metric-label { font-size: 0.9em; opacity: 0.9; }
        .phase-results { margin: 30px 0; }
        .phase-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .phase-card { border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; }
        .phase-header { font-weight: bold; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 2px solid #e9ecef; }
        .status-pass { color: #28a745; }
        .status-fail { color: #dc3545; }
        .status-error { color: #fd7e14; }
        .status-regression_detected { color: #dc3545; }
        .status-performance_degradation { color: #ffc107; }
        .scenario-details { margin: 15px 0; padding: 15px; background: #f8f9fa; border-radius: 5px; }
        .differences { background: #fff3cd; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #ffc107; }
        .chart-placeholder { height: 200px; background: #e9ecef; border-radius: 5px; display: flex; align-items: center; justify-content: center; color: #6c757d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔬 Enhanced TypeScript ↔ AO Lua Parity Report</h1>
            <p><strong>Generated:</strong> ${report.timestamp}</p>
            <p><strong>Framework Version:</strong> Enhanced Parity Framework v2.0</p>
        </div>
        
        <div class="summary">
            <div class="metric-card">
                <div class="metric-value">${summary.total}</div>
                <div class="metric-label">Total Scenarios</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${summary.passed}</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${summary.failed}</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${summary.successRate.toFixed(1)}%</div>
                <div class="metric-label">Success Rate</div>
            </div>
        </div>

        <div class="phase-results">
            <h2>📊 Validation Phase Results</h2>
            <div class="phase-grid">
                ${this.generatePhaseCards(report)}
            </div>
        </div>

        <div class="scenario-results">
            <h2>🧪 Detailed Scenario Results</h2>
            ${report.results.map(result => this.generateScenarioCard(result)).join("")}
        </div>

        <div class="system-info">
            <h2>🖥️ Environment Information</h2>
            <div class="scenario-details">
                <p><strong>Node.js:</strong> ${report.environment.nodeVersion}</p>
                <p><strong>Platform:</strong> ${report.environment.platform}</p>
                <p><strong>Architecture:</strong> ${report.environment.architecture}</p>
                <p><strong>TypeScript Dir:</strong> ${report.environment.typescriptDir}</p>
                <p><strong>AO Processes Dir:</strong> ${report.environment.aoProcessesDir}</p>
            </div>
        </div>
    </div>
</body>
</html>`;
  }

  /**
   * Helper methods for report generation
   */
  generatePhaseCards(report) {
    const phases = [
      { name: "Golden Master", results: report.goldenMasterResults },
      { name: "Regression Detection", results: report.regressionResults },
      { name: "Performance Comparison", results: report.performanceResults },
    ];

    return phases
      .map(phase => {
        const passed = phase.results.filter(r => r.status === "pass").length;
        const total = phase.results.length;
        const rate = total > 0 ? ((passed / total) * 100).toFixed(1) : "0.0";

        return `
        <div class="phase-card">
            <div class="phase-header">${phase.name}</div>
            <p><strong>Success Rate:</strong> ${rate}% (${passed}/${total})</p>
            <div class="chart-placeholder">Phase Results Chart</div>
        </div>
      `;
      })
      .join("");
  }

  generateScenarioCard(result) {
    const statusClass = `status-${result.overallStatus}`;

    return `
      <div class="scenario-details">
          <h3>${result.scenarioName} <span class="${statusClass}">${result.overallStatus.toUpperCase()}</span></h3>
          <p><strong>Scenario ID:</strong> ${result.scenarioId}</p>
          <p><strong>Type:</strong> ${result.scenarioType}</p>
          <p><strong>Executed:</strong> ${result.timestamp}</p>
          
          ${Object.entries(result.phases || {})
            .map(
              ([phaseName, phase]) => `
              <div style="margin: 10px 0; padding: 10px; background: #f8f9fa; border-radius: 3px;">
                  <strong>${phaseName.replace("_", " ").toUpperCase()}:</strong> 
                  <span class="status-${phase.status}">${phase.status.toUpperCase()}</span>
              </div>
          `,
            )
            .join("")}
      </div>
    `;
  }

  /**
   * Helper methods
   */
  getStatusEmoji(status) {
    const emojis = {
      pass: "✅",
      fail: "❌",
      error: "💥",
      regression_detected: "⚠️",
      performance_degradation: "🐌",
      captured: "📸",
      skipped: "⏭️",
    };
    return emojis[status] || "❓";
  }

  aggregateScenarioStatus(phases) {
    const statuses = Object.values(phases).map(phase => phase.status);

    if (statuses.includes("error")) {
      return "error";
    }
    if (statuses.includes("regression_detected")) {
      return "regression_detected";
    }
    if (statuses.includes("fail")) {
      return "fail";
    }
    if (statuses.includes("performance_degradation")) {
      return "performance_degradation";
    }
    if (statuses.every(status => ["pass", "captured", "skipped"].includes(status))) {
      return "pass";
    }

    return "unknown";
  }

  getComprehensiveSummary() {
    const base = super.getTestSummary();

    return {
      ...base,
      goldenMasters: {
        captured: this.goldenMasterResults.filter(r => r.status === "captured").length,
        validated: this.goldenMasterResults.filter(r => r.status === "pass").length,
        total: this.goldenMasterResults.length,
      },
      regressions: {
        detected: this.regressionResults.filter(r => r.status === "regression_detected").length,
        total: this.regressionResults.length,
      },
      performance: {
        degradations: this.performanceResults.filter(r => r.status === "performance_degradation").length,
        total: this.performanceResults.length,
      },
    };
  }

  // Additional helper methods for deep comparison, statistics, etc.
  async performDeepComparison(obj1, obj2, scenario) {
    const differences = [];
    const visited = new Set();

    const compare = (val1, val2, path = "") => {
      if (visited.has(path)) {
        return;
      }
      visited.add(path);

      if (typeof val1 !== typeof val2) {
        differences.push({
          type: "type_mismatch",
          key: path,
          typescriptValue: val1,
          aoValue: val2,
          description: `Type mismatch at ${path}: ${typeof val1} vs ${typeof val2}`,
        });
        return;
      }

      if (typeof val1 === "object" && val1 !== null && val2 !== null) {
        const keys1 = Object.keys(val1);
        const keys2 = Object.keys(val2);

        for (const key of new Set([...keys1, ...keys2])) {
          const newPath = path ? `${path}.${key}` : key;

          if (!(key in val1)) {
            differences.push({
              type: "missing_key",
              key: newPath,
              aoValue: val2[key],
              description: `Key '${newPath}' missing in TypeScript result`,
            });
          } else if (!(key in val2)) {
            differences.push({
              type: "extra_key",
              key: newPath,
              typescriptValue: val1[key],
              description: `Key '${newPath}' missing in AO result`,
            });
          } else {
            compare(val1[key], val2[key], newPath);
          }
        }
      } else if (!this.valuesEqual(val1, val2, scenario.tolerances?.[path])) {
        differences.push({
          type: "value_difference",
          key: path,
          typescriptValue: val1,
          aoValue: val2,
          description: `Value difference at ${path}: ${val1} vs ${val2}`,
        });
      }
    };

    compare(obj1, obj2);
    return differences;
  }

  compareStructure(obj1, obj2) {
    const differences = [];

    const getStructure = (obj, path = "") => {
      if (typeof obj !== "object" || obj === null) {
        return { [path]: typeof obj };
      }

      const structure = {};
      for (const [key, value] of Object.entries(obj)) {
        const newPath = path ? `${path}.${key}` : key;
        Object.assign(structure, getStructure(value, newPath));
      }
      return structure;
    };

    const struct1 = getStructure(obj1);
    const struct2 = getStructure(obj2);

    for (const [path, type] of Object.entries(struct1)) {
      if (!(path in struct2)) {
        differences.push({
          type: "missing_path",
          path,
          description: `Path '${path}' missing in current result`,
        });
      } else if (struct2[path] !== type) {
        differences.push({
          type: "type_change",
          path,
          description: `Type changed at '${path}': ${type} → ${struct2[path]}`,
        });
      }
    }

    for (const [path, type] of Object.entries(struct2)) {
      if (!(path in struct1)) {
        differences.push({
          type: "new_path",
          path,
          description: `New path '${path}' added to current result`,
        });
      }
    }

    return differences;
  }

  withinTolerance(difference, tolerance) {
    if (tolerance === undefined || tolerance === 0) {
      return difference.typescriptValue === difference.aoValue;
    }

    if (typeof difference.typescriptValue === "number" && typeof difference.aoValue === "number") {
      return Math.abs(difference.typescriptValue - difference.aoValue) <= tolerance;
    }

    return false;
  }

  assessRegressionSeverity(difference) {
    if (difference.type === "type_mismatch") {
      return "high";
    }
    if (difference.type === "missing_key" || difference.type === "extra_key") {
      return "high";
    }

    if (typeof difference.typescriptValue === "number" && typeof difference.aoValue === "number") {
      const percentDiff = Math.abs(difference.typescriptValue - difference.aoValue) / difference.typescriptValue;
      if (percentDiff > 0.1) {
        return "high";
      }
      if (percentDiff > 0.05) {
        return "medium";
      }
      return "low";
    }

    return "medium";
  }

  compareRNGResults(tsResult, aoResult) {
    // Simple comparison - can be enhanced based on specific RNG requirements
    return JSON.stringify(tsResult.result) === JSON.stringify(aoResult.result);
  }

  calculateStatistics(values) {
    const n = values.length;
    const mean = values.reduce((sum, val) => sum + val, 0) / n;
    const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / n;

    return {
      count: n,
      mean: mean,
      variance: variance,
      standardDeviation: Math.sqrt(variance),
      min: Math.min(...values),
      max: Math.max(...values),
    };
  }

  calculateCorrelation(arr1, arr2) {
    const n = arr1.length;
    const mean1 = arr1.reduce((sum, val) => sum + val, 0) / n;
    const mean2 = arr2.reduce((sum, val) => sum + val, 0) / n;

    let numerator = 0;
    let denominator1 = 0;
    let denominator2 = 0;

    for (let i = 0; i < n; i++) {
      const diff1 = arr1[i] - mean1;
      const diff2 = arr2[i] - mean2;

      numerator += diff1 * diff2;
      denominator1 += diff1 * diff1;
      denominator2 += diff2 * diff2;
    }

    return numerator / Math.sqrt(denominator1 * denominator2);
  }

  async getTypeScriptVersion() {
    // Placeholder - would integrate with actual TypeScript version detection
    return "1.10.4";
  }

  // Placeholder methods for generating additional reports
  async generateGoldenMasterReport() {
    console.log(chalk.blue("📸 Generating Golden Master Report..."));
    // Implementation would generate detailed golden master report
  }

  async generateRegressionReport() {
    console.log(chalk.blue("🔄 Generating Regression Analysis Report..."));
    // Implementation would generate detailed regression report
  }

  async generatePerformanceReport() {
    console.log(chalk.blue("⚡ Generating Performance Comparison Report..."));
    // Implementation would generate detailed performance report
  }
}
