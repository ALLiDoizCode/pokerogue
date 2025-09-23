/**
 * Automated Regression Detection System
 * Monitors and detects behavioral changes during AO Lua migration
 * Provides continuous validation against golden masters
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { GoldenMasterStorage } from "./golden-master-storage.js";

export class RegressionDetector {
  constructor(options = {}) {
    this.goldenMasterStorage = new GoldenMasterStorage(options);
    this.reportsDir = options.reportsDir || path.join(process.cwd(), "testing/reports");
    this.alertThreshold = options.alertThreshold || 0.05; // 5% threshold for regression alerts
    this.monitoringEnabled = options.monitoringEnabled || true;
    this.continuousMode = options.continuousMode || false;

    // Regression tracking
    this.regressionHistory = [];
    this.baselineMap = new Map();
    this.alertCallbacks = [];

    // Performance tracking
    this.performanceBaselines = new Map();
    this.performanceThreshold = options.performanceThreshold || 2.0; // 2x slowdown threshold

    // Behavioral change detection
    this.behavioralPatterns = new Map();
    this.changeDetectionSensitivity = options.changeDetectionSensitivity || "medium"; // low, medium, high
  }

  /**
   * Initialize regression detection system
   */
  async initialize() {
    console.log(chalk.blue("🔧 Initializing Regression Detection System..."));

    await this.goldenMasterStorage.initialize();
    await fs.mkdir(this.reportsDir, { recursive: true });

    // Load existing baselines and history
    await this.loadRegressionHistory();
    await this.loadPerformanceBaselines();

    console.log(chalk.green("✅ Regression Detection System initialized"));
  }

  /**
   * Detect regressions in a set of test results
   */
  async detectRegressions(testResults) {
    console.log(chalk.blue("🔍 Analyzing test results for regressions..."));

    const regressionAnalysis = {
      timestamp: new Date().toISOString(),
      totalScenarios: testResults.length,
      regressions: [],
      performanceRegressions: [],
      behavioralChanges: [],
      summary: {
        hasRegressions: false,
        regressionCount: 0,
        severityDistribution: { high: 0, medium: 0, low: 0 },
      },
    };

    for (const testResult of testResults) {
      try {
        // Check for functional regressions
        const functionalRegression = await this.detectFunctionalRegression(testResult);
        if (functionalRegression.hasRegression) {
          regressionAnalysis.regressions.push(functionalRegression);
        }

        // Check for performance regressions
        const performanceRegression = await this.detectPerformanceRegression(testResult);
        if (performanceRegression.hasRegression) {
          regressionAnalysis.performanceRegressions.push(performanceRegression);
        }

        // Check for behavioral changes
        const behavioralChange = await this.detectBehavioralChange(testResult);
        if (behavioralChange.hasChange) {
          regressionAnalysis.behavioralChanges.push(behavioralChange);
        }
      } catch (error) {
        console.error(chalk.red(`❌ Error analyzing ${testResult.scenarioId}: ${error.message}`));
      }
    }

    // Update analysis summary
    regressionAnalysis.summary.hasRegressions =
      regressionAnalysis.regressions.length > 0 || regressionAnalysis.performanceRegressions.length > 0;

    regressionAnalysis.summary.regressionCount =
      regressionAnalysis.regressions.length + regressionAnalysis.performanceRegressions.length;

    // Calculate severity distribution
    [...regressionAnalysis.regressions, ...regressionAnalysis.performanceRegressions].forEach(regression => {
      const severity = regression.severity || "medium";
      regressionAnalysis.summary.severityDistribution[severity]++;
    });

    // Store regression analysis
    await this.storeRegressionAnalysis(regressionAnalysis);

    // Trigger alerts if necessary
    if (regressionAnalysis.summary.hasRegressions) {
      await this.triggerRegressionAlerts(regressionAnalysis);
    }

    console.log(this.getRegressionStatusMessage(regressionAnalysis));
    return regressionAnalysis;
  }

  /**
   * Detect functional regressions against golden masters
   */
  async detectFunctionalRegression(testResult) {
    const regression = {
      scenarioId: testResult.scenarioId,
      scenarioName: testResult.scenarioName,
      hasRegression: false,
      regressionType: null,
      severity: "low",
      differences: [],
      confidence: 1.0,
      timestamp: new Date().toISOString(),
    };

    try {
      // Load golden master baseline
      const goldenMaster = await this.goldenMasterStorage.loadGoldenMaster(testResult.scenarioId);
      if (!goldenMaster) {
        regression.hasRegression = false;
        regression.reason = "no_golden_master_baseline";
        return regression;
      }

      // Compare current result with golden master
      const comparison = await this.compareWithBaseline(
        goldenMaster.typescriptReference,
        testResult.aoResult || testResult.typescriptResult,
        testResult,
      );

      if (comparison.differences.length > 0) {
        regression.hasRegression = true;
        regression.regressionType = "functional";
        regression.differences = comparison.differences;
        regression.severity = this.assessRegressionSeverity(comparison.differences);

        // Check if this is a new regression or existing issue
        regression.isNewRegression = await this.isNewRegression(testResult.scenarioId, comparison);
      }
    } catch (error) {
      console.error(chalk.red(`Error detecting functional regression for ${testResult.scenarioId}: ${error.message}`));
      regression.hasRegression = false;
      regression.error = error.message;
    }

    return regression;
  }

  /**
   * Detect performance regressions
   */
  async detectPerformanceRegression(testResult) {
    const regression = {
      scenarioId: testResult.scenarioId,
      scenarioName: testResult.scenarioName,
      hasRegression: false,
      regressionType: "performance",
      severity: "medium",
      metrics: {},
      timestamp: new Date().toISOString(),
    };

    try {
      const executionTimes = testResult.executionTimes || {};
      const currentTime = executionTimes.ao || executionTimes.typescript || 0;

      // Get performance baseline
      const baseline = this.performanceBaselines.get(testResult.scenarioId);
      if (!baseline) {
        // Store current performance as baseline
        this.performanceBaselines.set(testResult.scenarioId, {
          baselineTime: currentTime,
          timestamp: new Date().toISOString(),
          samples: [currentTime],
        });
        regression.hasRegression = false;
        regression.reason = "establishing_baseline";
        return regression;
      }

      // Calculate performance ratio
      const performanceRatio = currentTime / baseline.baselineTime;
      regression.metrics = {
        currentTime: currentTime,
        baselineTime: baseline.baselineTime,
        performanceRatio: performanceRatio,
        threshold: this.performanceThreshold,
      };

      // Check for regression
      if (performanceRatio > this.performanceThreshold) {
        regression.hasRegression = true;
        regression.severity = this.assessPerformanceSeverity(performanceRatio);

        // Update performance baseline with new sample
        baseline.samples.push(currentTime);
        if (baseline.samples.length > 100) {
          baseline.samples = baseline.samples.slice(-100); // Keep last 100 samples
        }

        // Check if this is a consistent degradation
        regression.isConsistent = await this.isConsistentPerformanceDegradation(
          testResult.scenarioId,
          performanceRatio,
        );
      }
    } catch (error) {
      console.error(chalk.red(`Error detecting performance regression for ${testResult.scenarioId}: ${error.message}`));
      regression.hasRegression = false;
      regression.error = error.message;
    }

    return regression;
  }

  /**
   * Detect behavioral changes (patterns and trends)
   */
  async detectBehavioralChange(testResult) {
    const change = {
      scenarioId: testResult.scenarioId,
      scenarioName: testResult.scenarioName,
      hasChange: false,
      changeType: "behavioral",
      patterns: [],
      confidence: 0.0,
      timestamp: new Date().toISOString(),
    };

    try {
      // Analyze result patterns
      const resultPattern = this.extractResultPattern(testResult);

      // Get historical patterns
      const historicalPatterns = this.behavioralPatterns.get(testResult.scenarioId) || [];

      if (historicalPatterns.length > 0) {
        // Compare with historical patterns
        const patternComparison = this.comparePatterns(resultPattern, historicalPatterns);

        if (patternComparison.similarity < this.getChangeDetectionThreshold()) {
          change.hasChange = true;
          change.patterns = patternComparison.differences;
          change.confidence = 1.0 - patternComparison.similarity;
        }
      }

      // Store current pattern
      historicalPatterns.push({
        pattern: resultPattern,
        timestamp: new Date().toISOString(),
      });

      // Keep only recent patterns
      if (historicalPatterns.length > 50) {
        historicalPatterns.splice(0, historicalPatterns.length - 50);
      }

      this.behavioralPatterns.set(testResult.scenarioId, historicalPatterns);
    } catch (error) {
      console.error(chalk.red(`Error detecting behavioral change for ${testResult.scenarioId}: ${error.message}`));
      change.hasChange = false;
      change.error = error.message;
    }

    return change;
  }

  /**
   * Monitor continuous execution for regressions
   */
  async startContinuousMonitoring(testRunner, interval = 300000) {
    // 5 minutes default
    if (!this.monitoringEnabled) {
      console.log(chalk.yellow("⚠️  Continuous monitoring is disabled"));
      return;
    }

    console.log(chalk.blue(`🔄 Starting continuous regression monitoring (${interval / 1000}s interval)...`));

    this.continuousMode = true;

    const monitoringLoop = async () => {
      if (!this.continuousMode) {
        return;
      }

      try {
        console.log(chalk.blue("📊 Running continuous regression check..."));

        // Run test suite
        const testResults = await testRunner.runParityTests();

        // Detect regressions
        const regressionAnalysis = await this.detectRegressions(testResults.results || []);

        // Log summary
        if (regressionAnalysis.summary.hasRegressions) {
          console.log(chalk.red(`🚨 ${regressionAnalysis.summary.regressionCount} regressions detected`));
        } else {
          console.log(chalk.green("✅ No regressions detected"));
        }
      } catch (error) {
        console.error(chalk.red(`❌ Continuous monitoring error: ${error.message}`));
      }

      // Schedule next check
      setTimeout(monitoringLoop, interval);
    };

    // Start monitoring
    monitoringLoop();
  }

  /**
   * Stop continuous monitoring
   */
  stopContinuousMonitoring() {
    console.log(chalk.blue("⏹️  Stopping continuous monitoring..."));
    this.continuousMode = false;
  }

  /**
   * Register alert callback for regression notifications
   */
  registerAlertCallback(callback) {
    this.alertCallbacks.push(callback);
  }

  /**
   * Trigger regression alerts
   */
  async triggerRegressionAlerts(regressionAnalysis) {
    const alertData = {
      timestamp: new Date().toISOString(),
      severity: this.getOverallSeverity(regressionAnalysis),
      regressionCount: regressionAnalysis.summary.regressionCount,
      scenarios: regressionAnalysis.regressions.map(r => r.scenarioId),
      summary: regressionAnalysis.summary,
    };

    // Console alert
    this.logRegressionAlert(alertData);

    // Custom callback alerts
    for (const callback of this.alertCallbacks) {
      try {
        await callback(alertData);
      } catch (error) {
        console.error(chalk.red(`❌ Alert callback error: ${error.message}`));
      }
    }

    // Generate alert report
    await this.generateAlertReport(regressionAnalysis);
  }

  /**
   * Generate regression trend analysis
   */
  async generateTrendAnalysis(timeRange = 7 * 24 * 60 * 60 * 1000) {
    // 7 days default
    console.log(chalk.blue("📈 Generating regression trend analysis..."));

    const endTime = Date.now();
    const startTime = endTime - timeRange;

    const trends = {
      timeRange: { start: new Date(startTime).toISOString(), end: new Date(endTime).toISOString() },
      regressionFrequency: {},
      severityTrends: { high: [], medium: [], low: [] },
      affectedScenarios: new Set(),
      performanceTrends: {},
      recommendations: [],
    };

    // Analyze historical regression data
    const relevantHistory = this.regressionHistory.filter(entry => {
      const entryTime = new Date(entry.timestamp).getTime();
      return entryTime >= startTime && entryTime <= endTime;
    });

    // Calculate regression frequency
    const frequencyMap = {};
    relevantHistory.forEach(entry => {
      entry.regressions.forEach(regression => {
        const scenarioId = regression.scenarioId;
        frequencyMap[scenarioId] = (frequencyMap[scenarioId] || 0) + 1;
        trends.affectedScenarios.add(scenarioId);
      });
    });

    trends.regressionFrequency = frequencyMap;

    // Generate recommendations
    trends.recommendations = this.generateRegressionRecommendations(trends);

    // Save trend analysis
    const trendReportPath = path.join(this.reportsDir, `regression-trends-${Date.now()}.json`);
    await fs.writeFile(trendReportPath, JSON.stringify(trends, null, 2));

    console.log(chalk.green(`📊 Trend analysis saved: ${trendReportPath}`));
    return trends;
  }

  /**
   * Update baseline after approved changes
   */
  async updateBaseline(scenarioId, newBaseline, approvalReason) {
    console.log(chalk.blue(`🔄 Updating baseline for scenario: ${scenarioId}`));

    try {
      // Store the new baseline as golden master
      const goldenMaster = {
        scenarioId: scenarioId,
        timestamp: new Date().toISOString(),
        typescriptReference: newBaseline,
        validated: true,
        approvalReason: approvalReason,
        previousBaseline: await this.goldenMasterStorage.loadGoldenMaster(scenarioId),
      };

      await this.goldenMasterStorage.storeGoldenMaster(scenarioId, goldenMaster);

      // Update local baseline map
      this.baselineMap.set(scenarioId, goldenMaster);

      console.log(chalk.green(`✅ Baseline updated for ${scenarioId}: ${approvalReason}`));
    } catch (error) {
      console.error(chalk.red(`❌ Failed to update baseline for ${scenarioId}: ${error.message}`));
      throw error;
    }
  }

  /**
   * Helper methods
   */

  async compareWithBaseline(baseline, current, testResult) {
    const differences = [];

    // Deep comparison logic (simplified)
    const compare = (baseObj, currentObj, path = "") => {
      if (typeof baseObj !== typeof currentObj) {
        differences.push({
          type: "type_mismatch",
          path: path,
          baseline: baseObj,
          current: currentObj,
          description: `Type mismatch at ${path}`,
        });
        return;
      }

      if (typeof baseObj === "object" && baseObj !== null) {
        const baseKeys = Object.keys(baseObj);
        const currentKeys = Object.keys(currentObj);

        for (const key of new Set([...baseKeys, ...currentKeys])) {
          const newPath = path ? `${path}.${key}` : key;

          if (!(key in baseObj)) {
            differences.push({
              type: "missing_key",
              path: newPath,
              current: currentObj[key],
              description: `New key '${newPath}' in current result`,
            });
          } else if (!(key in currentObj)) {
            differences.push({
              type: "removed_key",
              path: newPath,
              baseline: baseObj[key],
              description: `Missing key '${newPath}' in current result`,
            });
          } else {
            compare(baseObj[key], currentObj[key], newPath);
          }
        }
      } else if (baseObj !== currentObj) {
        differences.push({
          type: "value_change",
          path: path,
          baseline: baseObj,
          current: currentObj,
          description: `Value changed at ${path}: ${baseObj} → ${currentObj}`,
        });
      }
    };

    compare(baseline.result, current.result);

    return { differences };
  }

  assessRegressionSeverity(differences) {
    let highSeverityCount = 0;
    let mediumSeverityCount = 0;

    differences.forEach(diff => {
      if (diff.type === "type_mismatch" || diff.type === "removed_key") {
        highSeverityCount++;
      } else if (diff.type === "missing_key") {
        mediumSeverityCount++;
      }
    });

    if (highSeverityCount > 0) {
      return "high";
    }
    if (mediumSeverityCount > 0) {
      return "medium";
    }
    return "low";
  }

  assessPerformanceSeverity(performanceRatio) {
    if (performanceRatio > 5.0) {
      return "high";
    }
    if (performanceRatio > 3.0) {
      return "medium";
    }
    return "low";
  }

  async isNewRegression(scenarioId, comparison) {
    // Check if this regression pattern has been seen before
    const recentHistory = this.regressionHistory
      .filter(entry => entry.regressions.some(r => r.scenarioId === scenarioId))
      .slice(-5); // Last 5 entries

    if (recentHistory.length === 0) {
      return true;
    }

    // Simple pattern matching (can be enhanced)
    const currentPattern = this.createRegressionPattern(comparison);
    const similarPatterns = recentHistory.filter(entry => {
      const entryPattern = entry.regressions.find(r => r.scenarioId === scenarioId);
      return entryPattern && this.patternsAreSimilar(currentPattern, entryPattern);
    });

    return similarPatterns.length === 0;
  }

  async isConsistentPerformanceDegradation(scenarioId, performanceRatio) {
    const baseline = this.performanceBaselines.get(scenarioId);
    if (!baseline || baseline.samples.length < 5) {
      return false;
    }

    // Check if recent samples show consistent degradation
    const recentSamples = baseline.samples.slice(-5);
    const degradationCount = recentSamples.filter(
      sample => sample / baseline.baselineTime > this.performanceThreshold,
    ).length;

    return degradationCount >= 3; // 3 out of 5 recent samples show degradation
  }

  extractResultPattern(testResult) {
    // Extract key characteristics of the test result
    return {
      resultStructure: this.getObjectStructure(testResult.aoResult?.result || {}),
      valueRanges: this.getValueRanges(testResult.aoResult?.result || {}),
      executionTime: testResult.executionTimes?.ao || 0,
      status: testResult.comparisonStatus || testResult.overallStatus,
    };
  }

  comparePatterns(currentPattern, historicalPatterns) {
    if (historicalPatterns.length === 0) {
      return { similarity: 0, differences: [] };
    }

    // Compare with most recent patterns
    const recentPatterns = historicalPatterns.slice(-10);
    const similarities = recentPatterns.map(historical =>
      this.calculatePatternSimilarity(currentPattern, historical.pattern),
    );

    const avgSimilarity = similarities.reduce((sum, sim) => sum + sim, 0) / similarities.length;

    return {
      similarity: avgSimilarity,
      differences: avgSimilarity < 0.8 ? ["pattern_divergence"] : [],
    };
  }

  calculatePatternSimilarity(pattern1, pattern2) {
    // Simple similarity calculation (can be enhanced with more sophisticated algorithms)
    let matches = 0;
    let total = 0;

    // Compare result structures
    if (JSON.stringify(pattern1.resultStructure) === JSON.stringify(pattern2.resultStructure)) {
      matches++;
    }
    total++;

    // Compare execution time similarity (within 50% range)
    if (Math.abs(pattern1.executionTime - pattern2.executionTime) / pattern1.executionTime < 0.5) {
      matches++;
    }
    total++;

    // Compare status
    if (pattern1.status === pattern2.status) {
      matches++;
    }
    total++;

    return matches / total;
  }

  getChangeDetectionThreshold() {
    const thresholds = {
      low: 0.6,
      medium: 0.8,
      high: 0.9,
    };
    return thresholds[this.changeDetectionSensitivity] || 0.8;
  }

  getObjectStructure(obj, depth = 0, maxDepth = 3) {
    if (depth > maxDepth || typeof obj !== "object" || obj === null) {
      return typeof obj;
    }

    const structure = {};
    for (const [key, value] of Object.entries(obj)) {
      structure[key] = this.getObjectStructure(value, depth + 1, maxDepth);
    }
    return structure;
  }

  getValueRanges(obj) {
    const ranges = {};

    const traverse = (current, path = "") => {
      if (typeof current === "number") {
        ranges[path] = { min: current, max: current, type: "number" };
      } else if (typeof current === "string") {
        ranges[path] = { length: current.length, type: "string" };
      } else if (typeof current === "object" && current !== null) {
        for (const [key, value] of Object.entries(current)) {
          traverse(value, path ? `${path}.${key}` : key);
        }
      }
    };

    traverse(obj);
    return ranges;
  }

  createRegressionPattern(comparison) {
    return {
      differenceCount: comparison.differences.length,
      differenceTypes: [...new Set(comparison.differences.map(d => d.type))],
      affectedPaths: comparison.differences.map(d => d.path),
    };
  }

  patternsAreSimilar(pattern1, pattern2) {
    // Simple similarity check
    return (
      pattern1.differenceCount === pattern2.differenceCount &&
      JSON.stringify(pattern1.differenceTypes.sort()) === JSON.stringify(pattern2.differenceTypes.sort())
    );
  }

  getOverallSeverity(regressionAnalysis) {
    const { severityDistribution } = regressionAnalysis.summary;

    if (severityDistribution.high > 0) {
      return "high";
    }
    if (severityDistribution.medium > 0) {
      return "medium";
    }
    if (severityDistribution.low > 0) {
      return "low";
    }
    return "none";
  }

  getRegressionStatusMessage(regressionAnalysis) {
    const { summary } = regressionAnalysis;

    if (!summary.hasRegressions) {
      return chalk.green("✅ No regressions detected");
    }

    const severity = this.getOverallSeverity(regressionAnalysis);
    const color = severity === "high" ? "red" : severity === "medium" ? "yellow" : "blue";

    return chalk[color](`🚨 ${summary.regressionCount} regressions detected (${severity} severity)`);
  }

  logRegressionAlert(alertData) {
    console.log(chalk.red.bold("\n🚨 REGRESSION ALERT 🚨"));
    console.log(chalk.red(`Severity: ${alertData.severity.toUpperCase()}`));
    console.log(chalk.red(`Regressions: ${alertData.regressionCount}`));
    console.log(chalk.red(`Affected scenarios: ${alertData.scenarios.join(", ")}`));
    console.log(chalk.red(`Timestamp: ${alertData.timestamp}`));
  }

  generateRegressionRecommendations(trends) {
    const recommendations = [];

    // Frequent regression scenarios
    const frequentRegressions = Object.entries(trends.regressionFrequency)
      .filter(([_, count]) => count > 3)
      .map(([scenarioId, _]) => scenarioId);

    if (frequentRegressions.length > 0) {
      recommendations.push({
        type: "investigation",
        priority: "high",
        description: `Investigate frequently regressing scenarios: ${frequentRegressions.join(", ")}`,
        scenarios: frequentRegressions,
      });
    }

    // Performance trends
    if (Object.keys(trends.performanceTrends).length > 0) {
      recommendations.push({
        type: "performance",
        priority: "medium",
        description: "Review performance optimization for degraded scenarios",
        action: "performance_review",
      });
    }

    return recommendations;
  }

  async storeRegressionAnalysis(analysis) {
    // Store in history
    this.regressionHistory.push(analysis);

    // Keep only recent history (last 100 entries)
    if (this.regressionHistory.length > 100) {
      this.regressionHistory = this.regressionHistory.slice(-100);
    }

    // Save to file
    const analysisPath = path.join(this.reportsDir, `regression-analysis-${Date.now()}.json`);
    await fs.writeFile(analysisPath, JSON.stringify(analysis, null, 2));
  }

  async generateAlertReport(regressionAnalysis) {
    const reportPath = path.join(this.reportsDir, `regression-alert-${Date.now()}.json`);
    await fs.writeFile(reportPath, JSON.stringify(regressionAnalysis, null, 2));
    console.log(chalk.blue(`📄 Regression alert report saved: ${reportPath}`));
  }

  async loadRegressionHistory() {
    // Load from persistent storage if available
    try {
      const historyPath = path.join(this.reportsDir, "regression-history.json");
      const historyData = await fs.readFile(historyPath, "utf8");
      this.regressionHistory = JSON.parse(historyData);
    } catch (error) {
      // No existing history, start fresh
      this.regressionHistory = [];
    }
  }

  async loadPerformanceBaselines() {
    // Load from persistent storage if available
    try {
      const baselinesPath = path.join(this.reportsDir, "performance-baselines.json");
      const baselinesData = await fs.readFile(baselinesPath, "utf8");
      const baselines = JSON.parse(baselinesData);

      for (const [scenarioId, baseline] of Object.entries(baselines)) {
        this.performanceBaselines.set(scenarioId, baseline);
      }
    } catch (error) {
      // No existing baselines, start fresh
      this.performanceBaselines = new Map();
    }
  }

  /**
   * Save current state to persistent storage
   */
  async saveState() {
    try {
      // Save regression history
      const historyPath = path.join(this.reportsDir, "regression-history.json");
      await fs.writeFile(historyPath, JSON.stringify(this.regressionHistory, null, 2));

      // Save performance baselines
      const baselinesPath = path.join(this.reportsDir, "performance-baselines.json");
      const baselinesObj = Object.fromEntries(this.performanceBaselines);
      await fs.writeFile(baselinesPath, JSON.stringify(baselinesObj, null, 2));

      console.log(chalk.green("💾 Regression detector state saved"));
    } catch (error) {
      console.error(chalk.red(`❌ Failed to save state: ${error.message}`));
    }
  }
}
