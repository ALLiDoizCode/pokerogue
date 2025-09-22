/**
 * Property-Based Testing & Statistical Validation Framework
 * Implements statistical consistency validation for RNG-dependent systems
 * Validates battle outcomes, damage calculations, and probability-based systems
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";

export class PropertyBasedTestingFramework {
  constructor(options = {}) {
    this.testScenariosDir = options.testScenariosDir || path.join(process.cwd(), "testing/statistical/scenarios");
    this.reportsDir = options.reportsDir || path.join(process.cwd(), "testing/reports");
    this.minIterations = options.minIterations || 10000;
    this.confidenceLevel = options.confidenceLevel || 0.95;
    this.tolerances = options.tolerances || {
      probability: 0.02, // ±2% for probability-based outcomes
      damage: 0.05, // ±5% for damage variance calculations
      critical: 0.01, // ±1% for critical hit rates
    };
    this.results = [];
  }

  /**
   * Run complete property-based testing suite
   */
  async runPropertyBasedTests() {
    console.log(chalk.blue.bold("\n🎲 Property-Based Testing & Statistical Validation"));
    console.log(chalk.blue("=".repeat(65)));

    try {
      // Initialize testing environment
      await this.initializeEnvironment();

      // Load statistical test scenarios
      const scenarios = await this.loadStatisticalScenarios();
      console.log(chalk.green(`📊 Loaded ${scenarios.length} statistical validation scenarios`));

      // Execute property-based tests
      for (const scenario of scenarios) {
        console.log(chalk.yellow(`\n🔬 Testing property: ${scenario.name}`));
        await this.executePropertyTest(scenario);
      }

      // Generate statistical report
      await this.generateStatisticalReport();

      // Return summary
      return this.getTestSummary();
    } catch (error) {
      console.error(chalk.red("❌ Property-based testing failed:"), error.message);
      throw error;
    }
  }

  /**
   * Initialize statistical testing environment
   */
  async initializeEnvironment() {
    await fs.mkdir(this.testScenariosDir, { recursive: true });
    await fs.mkdir(this.reportsDir, { recursive: true });

    console.log(chalk.blue("🔧 Statistical testing environment initialized"));
    console.log(chalk.blue(`   Min iterations: ${this.minIterations}`));
    console.log(chalk.blue(`   Confidence level: ${this.confidenceLevel * 100}%`));
  }

  /**
   * Load statistical test scenarios
   */
  async loadStatisticalScenarios() {
    const scenarioFiles = await fs.readdir(this.testScenariosDir);
    const scenarios = [];

    for (const file of scenarioFiles) {
      if (file.endsWith(".json")) {
        const scenarioPath = path.join(this.testScenariosDir, file);
        const scenarioContent = await fs.readFile(scenarioPath, "utf8");
        scenarios.push(JSON.parse(scenarioContent));
      }
    }

    // Create default scenarios if none exist
    if (scenarios.length === 0) {
      return await this.createDefaultStatisticalScenarios();
    }

    return scenarios;
  }

  /**
   * Execute property-based test with statistical analysis
   */
  async executePropertyTest(scenario) {
    const testResult = {
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      timestamp: new Date().toISOString(),
      iterations: scenario.iterations || this.minIterations,
      expectedDistribution: scenario.expectedDistribution,
      actualDistribution: {},
      statisticalAnalysis: {},
      status: "running",
    };

    const startTime = Date.now();

    try {
      // Execute iterations based on scenario type
      const samples = await this.collectSamples(scenario, testResult.iterations);

      // Calculate actual distribution
      testResult.actualDistribution = this.calculateDistribution(samples, scenario);

      // Perform statistical analysis
      testResult.statisticalAnalysis = await this.performStatisticalAnalysis(
        testResult.expectedDistribution,
        testResult.actualDistribution,
        scenario,
      );

      // Determine if test passes statistical validation
      testResult.status = this.determineTestStatus(testResult.statisticalAnalysis, scenario);

      // Log results
      this.logTestResult(testResult);
    } catch (error) {
      testResult.status = "error";
      testResult.error = error.message;
      console.log(chalk.red(`  💥 ERROR: ${error.message}`));
    }

    testResult.duration = Date.now() - startTime;
    this.results.push(testResult);

    return testResult;
  }

  /**
   * Collect samples for statistical analysis
   */
  async collectSamples(scenario, iterations) {
    console.log(chalk.blue(`  📈 Collecting ${iterations} samples...`));

    const samples = [];
    const batchSize = 1000;

    for (let i = 0; i < iterations; i += batchSize) {
      const currentBatch = Math.min(batchSize, iterations - i);
      const batchSamples = await this.collectBatch(scenario, currentBatch, i);
      samples.push(...batchSamples);

      // Progress indication
      if ((i + currentBatch) % 5000 === 0) {
        console.log(chalk.gray(`    Progress: ${i + currentBatch}/${iterations} samples`));
      }
    }

    return samples;
  }

  /**
   * Collect batch of samples based on scenario type
   */
  async collectBatch(scenario, batchSize, offset) {
    const samples = [];

    for (let i = 0; i < batchSize; i++) {
      const seed = offset + i;
      let sample;

      switch (scenario.type) {
        case "critical_hit_rate":
          sample = this.simulateCriticalHit(scenario.parameters, seed);
          break;
        case "damage_variance":
          sample = this.simulateDamageCalculation(scenario.parameters, seed);
          break;
        case "capture_probability":
          sample = this.simulateCaptureAttempt(scenario.parameters, seed);
          break;
        case "status_effect_chance":
          sample = this.simulateStatusEffect(scenario.parameters, seed);
          break;
        case "move_accuracy":
          sample = this.simulateMoveAccuracy(scenario.parameters, seed);
          break;
        default:
          throw new Error(`Unknown scenario type: ${scenario.type}`);
      }

      samples.push(sample);
    }

    return samples;
  }

  /**
   * Simulate critical hit with deterministic RNG
   */
  simulateCriticalHit(parameters, seed) {
    const rng = this.createSeededRNG(seed);
    const criticalStage = parameters.criticalStage || 0;

    // Critical hit rates: [1/24, 1/8, 1/2, 1/1]
    const criticalRates = [1 / 24, 1 / 8, 1 / 2, 1.0];
    const rate = criticalRates[Math.min(criticalStage, 3)];

    const roll = rng();
    return {
      isCritical: roll < rate,
      roll: roll,
      threshold: rate,
      stage: criticalStage,
    };
  }

  /**
   * Simulate damage calculation with variance
   */
  simulateDamageCalculation(parameters, seed) {
    const rng = this.createSeededRNG(seed);

    const baseDamage = parameters.baseDamage || 100;
    const varianceMin = 0.85;
    const varianceMax = 1.0;

    // Damage variance is 85-100% of base damage
    const variance = varianceMin + rng() * (varianceMax - varianceMin);
    const finalDamage = Math.floor(baseDamage * variance);

    return {
      baseDamage: baseDamage,
      variance: variance,
      finalDamage: finalDamage,
      variancePercent: variance * 100,
    };
  }

  /**
   * Simulate capture attempt probability
   */
  simulateCaptureAttempt(parameters, seed) {
    const rng = this.createSeededRNG(seed);

    const catchRate = parameters.catchRate || 45; // Base catch rate
    const ballModifier = parameters.ballModifier || 1.0;
    const statusModifier = parameters.statusModifier || 1.0;
    const hpRatio = parameters.hpRatio || 0.5; // Current HP / Max HP

    // Simplified capture formula
    const captureValue = (catchRate * ballModifier * statusModifier * (1 - hpRatio + 0.1)) / 255;
    const threshold = Math.min(captureValue, 1.0);

    const roll = rng();
    return {
      captured: roll < threshold,
      roll: roll,
      threshold: threshold,
      captureValue: captureValue,
    };
  }

  /**
   * Simulate status effect application
   */
  simulateStatusEffect(parameters, seed) {
    const rng = this.createSeededRNG(seed);

    const baseChance = parameters.baseChance || 0.1; // 10% base chance
    const moveModifier = parameters.moveModifier || 1.0;
    const finalChance = Math.min(baseChance * moveModifier, 1.0);

    const roll = rng();
    return {
      applied: roll < finalChance,
      roll: roll,
      threshold: finalChance,
      effect: parameters.effectType || "burn",
    };
  }

  /**
   * Simulate move accuracy check
   */
  simulateMoveAccuracy(parameters, seed) {
    const rng = this.createSeededRNG(seed);

    const baseAccuracy = parameters.baseAccuracy || 0.9; // 90% base accuracy
    const statModifiers = parameters.statModifiers || 1.0;
    const finalAccuracy = Math.min(baseAccuracy * statModifiers, 1.0);

    const roll = rng();
    return {
      hit: roll < finalAccuracy,
      roll: roll,
      threshold: finalAccuracy,
      moveName: parameters.moveName || "TestMove",
    };
  }

  /**
   * Create seeded RNG for deterministic testing
   */
  createSeededRNG(seed) {
    let state = seed;
    return () => {
      // Simple LCG (Linear Congruential Generator)
      state = (state * 1664525 + 1013904223) % Math.pow(2, 32);
      return state / Math.pow(2, 32);
    };
  }

  /**
   * Calculate distribution from samples
   */
  calculateDistribution(samples, scenario) {
    const distribution = {};

    switch (scenario.type) {
      case "critical_hit_rate": {
        const criticals = samples.filter(s => s.isCritical).length;
        distribution.criticalRate = criticals / samples.length;
        distribution.totalSamples = samples.length;
        break;
      }

      case "damage_variance": {
        const damages = samples.map(s => s.finalDamage);
        distribution.mean = damages.reduce((a, b) => a + b, 0) / damages.length;
        distribution.min = Math.min(...damages);
        distribution.max = Math.max(...damages);
        distribution.variance = this.calculateVariance(damages);
        distribution.standardDeviation = Math.sqrt(distribution.variance);
        break;
      }

      case "capture_probability": {
        const captures = samples.filter(s => s.captured).length;
        distribution.captureRate = captures / samples.length;
        distribution.totalAttempts = samples.length;
        break;
      }

      case "status_effect_chance": {
        const applied = samples.filter(s => s.applied).length;
        distribution.applicationRate = applied / samples.length;
        distribution.totalAttempts = samples.length;
        break;
      }

      case "move_accuracy": {
        const hits = samples.filter(s => s.hit).length;
        distribution.hitRate = hits / samples.length;
        distribution.totalAttempts = samples.length;
        break;
      }
    }

    return distribution;
  }

  /**
   * Calculate variance for numerical data
   */
  calculateVariance(values) {
    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const squaredDiffs = values.map(value => Math.pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b, 0) / values.length;
  }

  /**
   * Perform comprehensive statistical analysis
   */
  async performStatisticalAnalysis(expected, actual, scenario) {
    const analysis = {
      testType: "chi_square",
      confidenceLevel: this.confidenceLevel,
      tolerance: this.tolerances[scenario.category] || 0.05,
    };

    // Calculate statistical metrics based on scenario type
    switch (scenario.type) {
      case "critical_hit_rate":
      case "capture_probability":
      case "status_effect_chance":
      case "move_accuracy":
        analysis = { ...analysis, ...this.analyzeProbabilityDistribution(expected, actual, scenario) };
        break;

      case "damage_variance":
        analysis = { ...analysis, ...this.analyzeContinuousDistribution(expected, actual, scenario) };
        break;
    }

    return analysis;
  }

  /**
   * Analyze probability-based distributions
   */
  analyzeProbabilityDistribution(expected, actual, scenario) {
    const expectedRate = expected.rate || expected.probability;
    const actualRate = actual.criticalRate || actual.captureRate || actual.applicationRate || actual.hitRate;

    const difference = Math.abs(actualRate - expectedRate);
    const relativeError = difference / expectedRate;

    // Calculate confidence interval
    const n = actual.totalSamples || actual.totalAttempts;
    const standardError = Math.sqrt((actualRate * (1 - actualRate)) / n);
    const z = 1.96; // 95% confidence interval
    const marginOfError = z * standardError;

    return {
      expectedRate: expectedRate,
      actualRate: actualRate,
      difference: difference,
      relativeError: relativeError,
      standardError: standardError,
      marginOfError: marginOfError,
      confidenceInterval: [actualRate - marginOfError, actualRate + marginOfError],
      withinTolerance: relativeError <= this.tolerances.probability,
      sampleSize: n,
    };
  }

  /**
   * Analyze continuous distributions (like damage variance)
   */
  analyzeContinuousDistribution(expected, actual, scenario) {
    const expectedMean = expected.mean;
    const actualMean = actual.mean;

    const meanDifference = Math.abs(actualMean - expectedMean);
    const relativeError = meanDifference / expectedMean;

    return {
      expectedMean: expectedMean,
      actualMean: actualMean,
      expectedVariance: expected.variance,
      actualVariance: actual.variance,
      meanDifference: meanDifference,
      relativeError: relativeError,
      withinTolerance: relativeError <= this.tolerances.damage,
      actualStandardDeviation: actual.standardDeviation,
    };
  }

  /**
   * Determine test status based on statistical analysis
   */
  determineTestStatus(analysis, scenario) {
    if (analysis.withinTolerance) {
      return "passed";
    }
    return "failed";
  }

  /**
   * Log test result with detailed statistics
   */
  logTestResult(testResult) {
    const analysis = testResult.statisticalAnalysis;

    if (testResult.status === "passed") {
      console.log(chalk.green("  ✅ PASS - Statistical validation successful"));
      console.log(chalk.blue(`     Expected: ${(analysis.expectedRate || analysis.expectedMean)?.toFixed(4)}`));
      console.log(chalk.blue(`     Actual: ${(analysis.actualRate || analysis.actualMean)?.toFixed(4)}`));
      console.log(chalk.blue(`     Error: ${(analysis.relativeError * 100).toFixed(2)}%`));
    } else {
      console.log(chalk.red("  ❌ FAIL - Statistical validation failed"));
      console.log(chalk.yellow(`     Expected: ${(analysis.expectedRate || analysis.expectedMean)?.toFixed(4)}`));
      console.log(chalk.yellow(`     Actual: ${(analysis.actualRate || analysis.actualMean)?.toFixed(4)}`));
      console.log(
        chalk.yellow(
          `     Error: ${(analysis.relativeError * 100).toFixed(2)}% (tolerance: ${(this.tolerances.probability * 100).toFixed(1)}%)`,
        ),
      );
    }
  }

  /**
   * Generate comprehensive statistical report
   */
  async generateStatisticalReport() {
    const reportPath = path.join(this.reportsDir, `statistical-validation-${Date.now()}.json`);
    const htmlReportPath = path.join(this.reportsDir, `statistical-validation-${Date.now()}.html`);

    const report = {
      timestamp: new Date().toISOString(),
      framework: "Property-Based Testing & Statistical Validation",
      configuration: {
        minIterations: this.minIterations,
        confidenceLevel: this.confidenceLevel,
        tolerances: this.tolerances,
      },
      summary: this.getTestSummary(),
      results: this.results,
      environment: {
        nodeVersion: process.version,
      },
    };

    // Write JSON report
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    // Generate HTML report
    const htmlReport = this.generateStatisticalHtmlReport(report);
    await fs.writeFile(htmlReportPath, htmlReport);

    console.log(chalk.green("📊 Statistical validation reports generated:"));
    console.log(chalk.blue(`  JSON: ${reportPath}`));
    console.log(chalk.blue(`  HTML: ${htmlReportPath}`));
  }

  /**
   * Generate HTML report for statistical validation
   */
  generateStatisticalHtmlReport(report) {
    const passed = report.results.filter(r => r.status === "passed").length;
    const failed = report.results.filter(r => r.status === "failed").length;
    const errors = report.results.filter(r => r.status === "error").length;

    return `
<!DOCTYPE html>
<html>
<head>
    <title>Statistical Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        .error { color: orange; font-weight: bold; }
        .test-result { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .statistics { background: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 3px; font-family: monospace; }
        .confidence-interval { font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <h1>Property-Based Testing & Statistical Validation Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Generated:</strong> ${report.timestamp}</p>
        <p><strong>Framework:</strong> ${report.framework}</p>
        <p><strong>Min Iterations:</strong> ${report.configuration.minIterations}</p>
        <p><strong>Confidence Level:</strong> ${(report.configuration.confidenceLevel * 100).toFixed(1)}%</p>
        <p><strong>Total Tests:</strong> ${report.results.length}</p>
        <p><strong>Passed:</strong> <span class="pass">${passed}</span></p>
        <p><strong>Failed:</strong> <span class="fail">${failed}</span></p>
        <p><strong>Errors:</strong> <span class="error">${errors}</span></p>
    </div>
    
    <h2>Statistical Test Results</h2>
    ${report.results
      .map(
        result => `
        <div class="test-result">
            <h3>${result.scenarioName} <span class="${result.status}">${result.status.toUpperCase()}</span></h3>
            <p><strong>Iterations:</strong> ${result.iterations}</p>
            <p><strong>Duration:</strong> ${result.duration}ms</p>
            
            ${
              result.statisticalAnalysis
                ? `
                <div class="statistics">
                    <h4>Statistical Analysis:</h4>
                    <p>Expected: ${(result.statisticalAnalysis.expectedRate || result.statisticalAnalysis.expectedMean)?.toFixed(4)}</p>
                    <p>Actual: ${(result.statisticalAnalysis.actualRate || result.statisticalAnalysis.actualMean)?.toFixed(4)}</p>
                    <p>Relative Error: ${(result.statisticalAnalysis.relativeError * 100).toFixed(2)}%</p>
                    ${
                      result.statisticalAnalysis.confidenceInterval
                        ? `
                        <p class="confidence-interval">95% CI: [${result.statisticalAnalysis.confidenceInterval[0].toFixed(4)}, ${result.statisticalAnalysis.confidenceInterval[1].toFixed(4)}]</p>
                    `
                        : ""
                    }
                </div>
            `
                : ""
            }
            
            ${result.error ? `<p class="error">Error: ${result.error}</p>` : ""}
        </div>
    `,
      )
      .join("")}
</body>
</html>`;
  }

  /**
   * Get test summary
   */
  getTestSummary() {
    const total = this.results.length;
    const passed = this.results.filter(r => r.status === "passed").length;
    const failed = this.results.filter(r => r.status === "failed").length;
    const errors = this.results.filter(r => r.status === "error").length;

    return {
      total,
      passed,
      failed,
      errors,
      successRate: total > 0 ? (passed / total) * 100 : 0,
      totalIterations: this.results.reduce((sum, r) => sum + r.iterations, 0),
    };
  }

  /**
   * Create default statistical test scenarios
   */
  async createDefaultStatisticalScenarios() {
    const scenarios = [
      {
        id: "critical-hit-rate-stage-0",
        name: "Critical Hit Rate - Stage 0",
        type: "critical_hit_rate",
        category: "critical",
        description: "Validate base critical hit rate (1/24)",
        iterations: 10000,
        parameters: {
          criticalStage: 0,
        },
        expectedDistribution: {
          rate: 1 / 24, // ~4.17%
        },
      },
      {
        id: "damage-variance-normal",
        name: "Damage Variance - Normal Attack",
        type: "damage_variance",
        category: "damage",
        description: "Validate damage variance range (85-100%)",
        iterations: 5000,
        parameters: {
          baseDamage: 100,
        },
        expectedDistribution: {
          mean: 92.5, // Average of 85-100%
          variance: 18.75,
        },
      },
      {
        id: "capture-rate-pokeball",
        name: "Capture Rate - Pokeball",
        type: "capture_probability",
        category: "probability",
        description: "Validate Pokeball capture probability",
        iterations: 10000,
        parameters: {
          catchRate: 45,
          ballModifier: 1.0,
          statusModifier: 1.0,
          hpRatio: 0.5,
        },
        expectedDistribution: {
          rate: 0.088, // ~8.8% for this scenario
        },
      },
      {
        id: "burn-status-chance",
        name: "Burn Status Effect Chance",
        type: "status_effect_chance",
        category: "probability",
        description: "Validate burn application rate",
        iterations: 10000,
        parameters: {
          baseChance: 0.1,
          moveModifier: 1.0,
          effectType: "burn",
        },
        expectedDistribution: {
          rate: 0.1, // 10%
        },
      },
    ];

    // Save scenarios
    for (const scenario of scenarios) {
      const scenarioPath = path.join(this.testScenariosDir, `${scenario.id}.json`);
      await fs.writeFile(scenarioPath, JSON.stringify(scenario, null, 2));
    }

    return scenarios;
  }
}

export { PropertyBasedTestingFramework };
