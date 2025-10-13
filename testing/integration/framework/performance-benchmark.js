/**
 * Performance Benchmark Framework for AO Lua vs TypeScript Comparison
 *
 * Measures and compares execution performance between TypeScript reference
 * implementation and AO Lua multi-process architecture with comprehensive
 * bottleneck detection and resource monitoring.
 */

const EventEmitter = require("events");
const { performance } = require("perf_hooks");
const os = require("os");

class PerformanceBenchmark extends EventEmitter {
  constructor(options = {}) {
    super();
    this.config = {
      samplingInterval: options.samplingInterval || 100, // ms
      warmupRuns: options.warmupRuns || 3,
      benchmarkRuns: options.benchmarkRuns || 10,
      timeoutThreshold: options.timeoutThreshold || 30000, // 30 seconds
      memoryThreshold: options.memoryThreshold || 500 * 1024 * 1024, // 500MB
      ...options,
    };

    this.benchmarkResults = new Map();
    this.baselineMetrics = new Map();
    this.resourceMonitor = new ResourceMonitor(this.config.samplingInterval);

    this.setupResourceMonitoring();
  }

  /**
   * Run comprehensive performance comparison between TypeScript and AO Lua
   */
  async runPerformanceComparison(scenarios) {
    const comparison = {
      id: `perf-comparison-${Date.now()}`,
      startTime: Date.now(),
      scenarios: scenarios.length,
      results: [],
      summary: {},
      recommendations: [],
    };

    this.emit("comparison:started", { comparisonId: comparison.id, scenarios: scenarios.length });

    try {
      // Establish TypeScript baseline
      await this.establishTypeScriptBaseline(scenarios);

      // Run AO Lua benchmarks
      for (const scenario of scenarios) {
        const result = await this.benchmarkScenario(scenario);
        comparison.results.push(result);
        this.emit("scenario:completed", { scenarioId: scenario.id, result });
      }

      // Generate comparison analysis
      comparison.summary = this.generateComparisonSummary(comparison.results);
      comparison.recommendations = this.generatePerformanceRecommendations(comparison.summary);
      comparison.endTime = Date.now();
      comparison.duration = comparison.endTime - comparison.startTime;

      this.emit("comparison:completed", comparison);
      return comparison;
    } catch (error) {
      comparison.status = "failed";
      comparison.error = error.message;
      comparison.endTime = Date.now();
      this.emit("comparison:failed", { comparisonId: comparison.id, error: error.message });
      throw error;
    }
  }

  /**
   * Establish performance baseline using TypeScript reference implementation
   */
  async establishTypeScriptBaseline(scenarios) {
    this.emit("baseline:started", { scenarios: scenarios.length });

    for (const scenario of scenarios) {
      const baselineMetrics = {
        scenarioId: scenario.id,
        measurements: [],
        averageExecutionTime: 0,
        minExecutionTime: Number.MAX_VALUE,
        maxExecutionTime: 0,
        throughput: 0,
        memoryUsage: {},
        cpuUsage: {},
      };

      // Warmup runs
      for (let i = 0; i < this.config.warmupRuns; i++) {
        await this.executeTypeScriptScenario(scenario, true);
      }

      // Measurement runs
      for (let i = 0; i < this.config.benchmarkRuns; i++) {
        const measurement = await this.executeTypeScriptScenario(scenario, false);
        baselineMetrics.measurements.push(measurement);

        baselineMetrics.minExecutionTime = Math.min(baselineMetrics.minExecutionTime, measurement.executionTime);
        baselineMetrics.maxExecutionTime = Math.max(baselineMetrics.maxExecutionTime, measurement.executionTime);
      }

      // Calculate statistics
      baselineMetrics.averageExecutionTime =
        baselineMetrics.measurements.reduce((sum, m) => sum + m.executionTime, 0) / baselineMetrics.measurements.length;

      baselineMetrics.throughput = 1000 / baselineMetrics.averageExecutionTime; // operations per second

      this.baselineMetrics.set(scenario.id, baselineMetrics);
      this.emit("baseline:scenario_completed", { scenarioId: scenario.id, metrics: baselineMetrics });
    }

    this.emit("baseline:completed", { scenarios: scenarios.length });
  }

  /**
   * Execute TypeScript scenario for baseline measurement
   */
  async executeTypeScriptScenario(scenario, isWarmup = false) {
    const measurement = {
      isWarmup,
      startTime: performance.now(),
      memoryBefore: process.memoryUsage(),
      cpuBefore: process.cpuUsage(),
    };

    try {
      // Simulate TypeScript scenario execution
      // In real implementation, this would call actual TypeScript functions
      const result = await this.simulateTypeScriptExecution(scenario);

      measurement.endTime = performance.now();
      measurement.executionTime = measurement.endTime - measurement.startTime;
      measurement.memoryAfter = process.memoryUsage();
      measurement.cpuAfter = process.cpuUsage();
      measurement.memoryDelta = this.calculateMemoryDelta(measurement.memoryBefore, measurement.memoryAfter);
      measurement.cpuDelta = this.calculateCpuDelta(measurement.cpuBefore, measurement.cpuAfter);
      measurement.success = true;
      measurement.result = result;
    } catch (error) {
      measurement.endTime = performance.now();
      measurement.executionTime = measurement.endTime - measurement.startTime;
      measurement.success = false;
      measurement.error = error.message;
    }

    return measurement;
  }

  /**
   * Benchmark AO Lua scenario performance
   */
  async benchmarkScenario(scenario) {
    const benchmark = {
      scenarioId: scenario.id,
      scenarioType: scenario.type,
      startTime: Date.now(),
      measurements: [],
      aoLuaMetrics: {},
      comparison: {},
      bottlenecks: [],
      resourceUsage: {},
    };

    this.emit("benchmark:started", { scenarioId: scenario.id });

    try {
      // Start resource monitoring
      const monitoringSession = this.resourceMonitor.startSession(`benchmark-${scenario.id}`);

      // Warmup runs
      for (let i = 0; i < this.config.warmupRuns; i++) {
        await this.executeAOLuaScenario(scenario, true);
      }

      // Measurement runs
      for (let i = 0; i < this.config.benchmarkRuns; i++) {
        const measurement = await this.executeAOLuaScenario(scenario, false);
        benchmark.measurements.push(measurement);

        this.emit("benchmark:measurement", {
          scenarioId: scenario.id,
          run: i + 1,
          measurement,
        });
      }

      // Stop resource monitoring
      benchmark.resourceUsage = this.resourceMonitor.stopSession(monitoringSession);

      // Calculate AO Lua metrics
      benchmark.aoLuaMetrics = this.calculateScenarioMetrics(benchmark.measurements);

      // Compare with TypeScript baseline
      const baseline = this.baselineMetrics.get(scenario.id);
      if (baseline) {
        benchmark.comparison = this.compareWithBaseline(benchmark.aoLuaMetrics, baseline);
      }

      // Detect performance bottlenecks
      benchmark.bottlenecks = this.detectBottlenecks(benchmark.measurements, benchmark.resourceUsage);

      benchmark.endTime = Date.now();
      benchmark.duration = benchmark.endTime - benchmark.startTime;
      benchmark.status = "completed";
    } catch (error) {
      benchmark.endTime = Date.now();
      benchmark.duration = benchmark.endTime - benchmark.startTime;
      benchmark.status = "failed";
      benchmark.error = error.message;
      this.emit("benchmark:failed", { scenarioId: scenario.id, error: error.message });
    }

    this.emit("benchmark:completed", { scenarioId: scenario.id, benchmark });
    return benchmark;
  }

  /**
   * Execute AO Lua scenario for performance measurement
   */
  async executeAOLuaScenario(scenario, isWarmup = false) {
    const measurement = {
      isWarmup,
      startTime: performance.now(),
      processTimings: {},
      messageCount: 0,
      totalProcessingTime: 0,
      coordinationOverhead: 0,
    };

    try {
      // Simulate AO Lua multi-process execution
      // In real implementation, this would use the ScenarioRunner
      const result = await this.simulateAOLuaExecution(scenario, measurement);

      measurement.endTime = performance.now();
      measurement.executionTime = measurement.endTime - measurement.startTime;
      measurement.success = true;
      measurement.result = result;

      // Calculate coordination overhead
      measurement.coordinationOverhead = measurement.executionTime - measurement.totalProcessingTime;
    } catch (error) {
      measurement.endTime = performance.now();
      measurement.executionTime = measurement.endTime - measurement.startTime;
      measurement.success = false;
      measurement.error = error.message;
    }

    return measurement;
  }

  /**
   * Simulate TypeScript scenario execution
   */
  async simulateTypeScriptExecution(scenario) {
    // Simulate different scenario types with realistic timing
    const simulationTime = this.getSimulatedExecutionTime(scenario, "typescript");

    await new Promise(resolve => setTimeout(resolve, simulationTime));

    return {
      scenarioType: scenario.type,
      operationsCompleted: scenario.messageFlow?.length || 1,
      executionPath: "typescript_direct",
      processesInvolved: 1, // Single process execution
    };
  }

  /**
   * Simulate AO Lua multi-process execution
   */
  async simulateAOLuaExecution(scenario, measurement) {
    const processes = scenario.testScenario?.processes || ["coordinator-process"];
    const messageFlow = scenario.messageFlow || [];

    measurement.messageCount = messageFlow.length;

    // Simulate process execution times
    for (const processId of processes) {
      const processTime = this.getSimulatedProcessTime(processId, scenario.type);
      measurement.processTimings[processId] = processTime;
      measurement.totalProcessingTime += processTime;
    }

    // Simulate message passing overhead
    const messagingOverhead = messageFlow.length * 10; // 10ms per message
    measurement.messagingOverhead = messagingOverhead;

    // Simulate coordination delay
    const coordinationDelay = processes.length > 1 ? 50 : 0; // 50ms coordination overhead
    measurement.coordinationDelay = coordinationDelay;

    const totalSimulatedTime = measurement.totalProcessingTime + messagingOverhead + coordinationDelay;
    await new Promise(resolve => setTimeout(resolve, totalSimulatedTime));

    return {
      scenarioType: scenario.type,
      operationsCompleted: messageFlow.length,
      executionPath: "ao_lua_multiprocess",
      processesInvolved: processes.length,
      coordinationRequired: processes.length > 1,
    };
  }

  /**
   * Get simulated execution time based on scenario type and platform
   */
  getSimulatedExecutionTime(scenario, platform) {
    const baseTimings = {
      integration: { typescript: 100, ao_lua: 150 },
      "end-to-end": { typescript: 500, ao_lua: 700 },
      orchestration: { typescript: 200, ao_lua: 400 },
    };

    const baseTime = baseTimings[scenario.type]?.[platform] || 100;
    const complexity = scenario.messageFlow?.length || 1;

    return baseTime + complexity * 20; // Add 20ms per operation
  }

  /**
   * Get simulated process execution time
   */
  getSimulatedProcessTime(processId, scenarioType) {
    const processTimings = {
      "coordinator-process": 50,
      "battle-engine": 100,
      "pokemon-species-db": 30,
      "moves-database": 25,
      "damage-calculator": 40,
      "state-validator": 60,
    };

    const baseTime = processTimings[processId] || 30;
    const complexityMultiplier = scenarioType === "end-to-end" ? 1.5 : 1;

    return baseTime * complexityMultiplier;
  }

  /**
   * Calculate comprehensive metrics for scenario measurements
   */
  calculateScenarioMetrics(measurements) {
    const validMeasurements = measurements.filter(m => m.success);

    if (validMeasurements.length === 0) {
      throw new Error("No successful measurements found");
    }

    const executionTimes = validMeasurements.map(m => m.executionTime);
    const messagesCounts = validMeasurements.map(m => m.messageCount || 0);
    const coordinationOverheads = validMeasurements.map(m => m.coordinationOverhead || 0);

    return {
      totalMeasurements: measurements.length,
      successfulMeasurements: validMeasurements.length,
      failureRate: (measurements.length - validMeasurements.length) / measurements.length,

      executionTime: {
        average: this.calculateAverage(executionTimes),
        min: Math.min(...executionTimes),
        max: Math.max(...executionTimes),
        median: this.calculateMedian(executionTimes),
        standardDeviation: this.calculateStandardDeviation(executionTimes),
        percentile95: this.calculatePercentile(executionTimes, 95),
      },

      throughput: {
        averageOpsPerSecond: 1000 / this.calculateAverage(executionTimes),
        peakOpsPerSecond: 1000 / Math.min(...executionTimes),
      },

      coordination: {
        averageOverhead: this.calculateAverage(coordinationOverheads),
        overheadPercentage:
          (this.calculateAverage(coordinationOverheads) / this.calculateAverage(executionTimes)) * 100,
      },

      messaging: {
        averageMessageCount: this.calculateAverage(messagesCounts),
        averageTimePerMessage: this.calculateAverage(executionTimes) / this.calculateAverage(messagesCounts),
      },
    };
  }

  /**
   * Compare AO Lua metrics with TypeScript baseline
   */
  compareWithBaseline(aoLuaMetrics, baseline) {
    const comparison = {
      executionTime: {
        ratio: aoLuaMetrics.executionTime.average / baseline.averageExecutionTime,
        difference: aoLuaMetrics.executionTime.average - baseline.averageExecutionTime,
        percentageChange:
          ((aoLuaMetrics.executionTime.average - baseline.averageExecutionTime) / baseline.averageExecutionTime) * 100,
      },

      throughput: {
        ratio: aoLuaMetrics.throughput.averageOpsPerSecond / baseline.throughput,
        difference: aoLuaMetrics.throughput.averageOpsPerSecond - baseline.throughput,
        percentageChange:
          ((aoLuaMetrics.throughput.averageOpsPerSecond - baseline.throughput) / baseline.throughput) * 100,
      },

      performance: "unknown",
    };

    // Determine overall performance comparison
    if (comparison.executionTime.ratio <= 1.1) {
      comparison.performance = "equivalent";
    } else if (comparison.executionTime.ratio <= 1.5) {
      comparison.performance = "acceptable";
    } else if (comparison.executionTime.ratio <= 2.0) {
      comparison.performance = "slower";
    } else {
      comparison.performance = "significantly_slower";
    }

    return comparison;
  }

  /**
   * Detect performance bottlenecks in measurements
   */
  detectBottlenecks(measurements, resourceUsage) {
    const bottlenecks = [];

    // Analyze execution time variations
    const executionTimes = measurements.filter(m => m.success).map(m => m.executionTime);
    const avgTime = this.calculateAverage(executionTimes);
    const stdDev = this.calculateStandardDeviation(executionTimes);

    if (stdDev > avgTime * 0.3) {
      bottlenecks.push({
        type: "execution_time_variance",
        severity: "medium",
        description: "High variance in execution times detected",
        metric: `Std Dev: ${stdDev.toFixed(2)}ms (${((stdDev / avgTime) * 100).toFixed(1)}% of average)`,
        recommendation: "Investigate process coordination timing and message queue handling",
      });
    }

    // Analyze coordination overhead
    const coordOverheads = measurements
      .filter(m => m.success && m.coordinationOverhead)
      .map(m => m.coordinationOverhead);

    if (coordOverheads.length > 0) {
      const avgOverhead = this.calculateAverage(coordOverheads);
      const overheadPercentage = (avgOverhead / avgTime) * 100;

      if (overheadPercentage > 30) {
        bottlenecks.push({
          type: "coordination_overhead",
          severity: "high",
          description: "High coordination overhead detected",
          metric: `${overheadPercentage.toFixed(1)}% of total execution time`,
          recommendation: "Optimize process coordination patterns and reduce message round-trips",
        });
      }
    }

    // Analyze resource usage patterns
    if (resourceUsage.memoryPeak > this.config.memoryThreshold) {
      bottlenecks.push({
        type: "memory_usage",
        severity: "high",
        description: "High memory usage detected",
        metric: `Peak: ${(resourceUsage.memoryPeak / 1024 / 1024).toFixed(1)}MB`,
        recommendation: "Optimize data structures and implement memory pooling",
      });
    }

    return bottlenecks;
  }

  /**
   * Generate comprehensive comparison summary
   */
  generateComparisonSummary(results) {
    const summary = {
      totalScenarios: results.length,
      successfulScenarios: results.filter(r => r.status === "completed").length,
      overallPerformance: "unknown",
      averageSlowdown: 0,
      criticalBottlenecks: 0,
      recommendations: [],
    };

    const completedResults = results.filter(r => r.status === "completed" && r.comparison);

    if (completedResults.length > 0) {
      // Calculate overall performance metrics
      const slowdownRatios = completedResults.map(r => r.comparison.executionTime.ratio);
      summary.averageSlowdown = this.calculateAverage(slowdownRatios);

      // Determine overall performance classification
      if (summary.averageSlowdown <= 1.1) {
        summary.overallPerformance = "equivalent";
      } else if (summary.averageSlowdown <= 1.5) {
        summary.overallPerformance = "acceptable";
      } else {
        summary.overallPerformance = "needs_optimization";
      }

      // Count critical bottlenecks
      summary.criticalBottlenecks = completedResults.reduce(
        (count, r) => count + r.bottlenecks.filter(b => b.severity === "high").length,
        0,
      );
    }

    return summary;
  }

  /**
   * Generate performance optimization recommendations
   */
  generatePerformanceRecommendations(summary) {
    const recommendations = [];

    if (summary.averageSlowdown > 2.0) {
      recommendations.push({
        priority: "high",
        category: "architecture",
        title: "Significant Performance Gap Detected",
        description: `AO Lua implementation is ${summary.averageSlowdown.toFixed(1)}x slower than TypeScript`,
        actions: [
          "Review process coordination patterns",
          "Optimize message passing protocols",
          "Consider process consolidation for hot paths",
        ],
      });
    }

    if (summary.criticalBottlenecks > 0) {
      recommendations.push({
        priority: "high",
        category: "optimization",
        title: "Critical Bottlenecks Identified",
        description: `${summary.criticalBottlenecks} critical performance bottlenecks found`,
        actions: [
          "Address high-severity bottlenecks first",
          "Implement performance monitoring",
          "Optimize resource usage patterns",
        ],
      });
    }

    if (summary.overallPerformance === "acceptable") {
      recommendations.push({
        priority: "medium",
        category: "monitoring",
        title: "Performance Monitoring Recommended",
        description: "Performance is acceptable but should be monitored",
        actions: [
          "Implement continuous performance monitoring",
          "Set up performance regression alerts",
          "Regular performance benchmarking",
        ],
      });
    }

    return recommendations;
  }

  /**
   * Setup resource monitoring
   */
  setupResourceMonitoring() {
    this.resourceMonitor.on("high_memory_usage", data => {
      this.emit("resource:high_memory", data);
    });

    this.resourceMonitor.on("high_cpu_usage", data => {
      this.emit("resource:high_cpu", data);
    });
  }

  // Statistical utility functions
  calculateAverage(values) {
    return values.reduce((sum, val) => sum + val, 0) / values.length;
  }

  calculateMedian(values) {
    const sorted = [...values].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
  }

  calculateStandardDeviation(values) {
    const avg = this.calculateAverage(values);
    const squaredDiffs = values.map(val => Math.pow(val - avg, 2));
    return Math.sqrt(this.calculateAverage(squaredDiffs));
  }

  calculatePercentile(values, percentile) {
    const sorted = [...values].sort((a, b) => a - b);
    const index = Math.ceil((percentile / 100) * sorted.length) - 1;
    return sorted[index];
  }

  calculateMemoryDelta(before, after) {
    return {
      rss: after.rss - before.rss,
      heapTotal: after.heapTotal - before.heapTotal,
      heapUsed: after.heapUsed - before.heapUsed,
      external: after.external - before.external,
    };
  }

  calculateCpuDelta(before, after) {
    return {
      user: after.user - before.user,
      system: after.system - before.system,
    };
  }
}

/**
 * Resource Monitor for tracking system resource usage during benchmarks
 */
class ResourceMonitor extends EventEmitter {
  constructor(samplingInterval = 100) {
    super();
    this.samplingInterval = samplingInterval;
    this.activeSessions = new Map();
    this.monitoringActive = false;
  }

  startSession(sessionId) {
    const session = {
      id: sessionId,
      startTime: Date.now(),
      samples: [],
      memoryPeak: 0,
      cpuPeak: 0,
    };

    this.activeSessions.set(sessionId, session);

    if (!this.monitoringActive) {
      this.startMonitoring();
    }

    return sessionId;
  }

  stopSession(sessionId) {
    const session = this.activeSessions.get(sessionId);
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    session.endTime = Date.now();
    session.duration = session.endTime - session.startTime;

    this.activeSessions.delete(sessionId);

    if (this.activeSessions.size === 0) {
      this.stopMonitoring();
    }

    return session;
  }

  startMonitoring() {
    this.monitoringActive = true;
    this.monitorInterval = setInterval(() => {
      this.collectSample();
    }, this.samplingInterval);
  }

  stopMonitoring() {
    this.monitoringActive = false;
    if (this.monitorInterval) {
      clearInterval(this.monitorInterval);
      this.monitorInterval = null;
    }
  }

  collectSample() {
    const timestamp = Date.now();
    const memoryUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    const loadAverage = os.loadavg();

    const sample = {
      timestamp,
      memory: memoryUsage,
      cpu: cpuUsage,
      loadAverage: loadAverage[0], // 1-minute load average
    };

    // Update all active sessions
    for (const [sessionId, session] of this.activeSessions) {
      session.samples.push(sample);
      session.memoryPeak = Math.max(session.memoryPeak, memoryUsage.rss);
      session.cpuPeak = Math.max(session.cpuPeak, loadAverage[0]);

      // Emit warnings for high resource usage
      if (memoryUsage.rss > 500 * 1024 * 1024) {
        // 500MB
        this.emit("high_memory_usage", { sessionId, memoryUsage: memoryUsage.rss });
      }

      if (loadAverage[0] > 2.0) {
        this.emit("high_cpu_usage", { sessionId, loadAverage: loadAverage[0] });
      }
    }
  }
}

module.exports = { PerformanceBenchmark, ResourceMonitor };
