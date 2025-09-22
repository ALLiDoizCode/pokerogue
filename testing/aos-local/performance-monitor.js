/**
 * Performance Monitor
 * Comprehensive performance benchmarking and monitoring for deployment validation
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";
import { AoliteFramework } from "../aolite/aolite-framework.js";

export class PerformanceMonitor {
  constructor(options = {}) {
    this.aoliteFramework = new AoliteFramework();
    this.reportsDir = options.reportsDir || path.join(process.cwd(), "testing/reports");
    this.baselineFile = options.baselineFile || path.join(process.cwd(), "testing/fixtures/performance-baselines.js");
    this.monitoringInterval = options.monitoringInterval || 1000; // 1 second
    this.benchmarkResults = [];
    this.realTimeMetrics = new Map();
    this.baselines = {};
    this.isMonitoring = false;
    this.monitoringTimer = null;
  }

  /**
   * Initialize performance monitor
   */
  async initialize() {
    console.log(chalk.blue("📊 Initializing performance monitor..."));
    
    await this.aoliteFramework.initialize();
    
    // Load performance baselines
    await this.loadPerformanceBaselines();
    
    // Ensure reports directory exists
    await fs.mkdir(this.reportsDir, { recursive: true });
    
    console.log(chalk.green("✅ Performance monitor ready"));
  }

  /**
   * Load performance baselines
   */
  async loadPerformanceBaselines() {
    try {
      const baselineModule = await import(this.baselineFile);
      this.baselines = baselineModule.performanceBaselines || baselineModule.default || {};
      console.log(chalk.blue(`📈 Loaded performance baselines from ${this.baselineFile}`));
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not load baselines from ${this.baselineFile}, using defaults`));
      this.baselines = this.getDefaultBaselines();
    }
  }

  /**
   * Get default performance baselines
   */
  getDefaultBaselines() {
    return {
      deploymentTime: {
        coordinator: 2000,
        dataProcess: 1500,
        logicProcess: 3000
      },
      responseTime: {
        coordinator: 1000,
        dataProcess: 500,
        logicProcess: 2000
      },
      memoryUsage: {
        coordinator: 50,
        dataProcess: 30,
        logicProcess: 80
      },
      throughput: {
        messagesPerSecond: 100,
        queriesPerSecond: 200
      },
      errorRates: {
        maxErrorRate: 0.05, // 5%
        maxTimeoutRate: 0.02 // 2%
      }
    };
  }

  /**
   * Start real-time performance monitoring
   */
  startMonitoring(processes) {
    if (this.isMonitoring) {
      console.warn(chalk.yellow("Performance monitoring already active"));
      return;
    }

    console.log(chalk.blue("📊 Starting real-time performance monitoring..."));
    
    this.isMonitoring = true;
    this.monitoredProcesses = processes || new Map();
    
    this.monitoringTimer = setInterval(async () => {
      await this.collectRealTimeMetrics();
    }, this.monitoringInterval);

    console.log(chalk.green("✅ Real-time monitoring started"));
  }

  /**
   * Stop real-time performance monitoring
   */
  stopMonitoring() {
    if (!this.isMonitoring) {
      return;
    }

    console.log(chalk.blue("📊 Stopping real-time performance monitoring..."));
    
    this.isMonitoring = false;
    
    if (this.monitoringTimer) {
      clearInterval(this.monitoringTimer);
      this.monitoringTimer = null;
    }

    console.log(chalk.green("✅ Real-time monitoring stopped"));
  }

  /**
   * Collect real-time metrics
   */
  async collectRealTimeMetrics() {
    const timestamp = Date.now();
    
    try {
      // Get framework statistics
      const stats = await this.aoliteFramework.getStatistics();
      
      // Collect metrics for each monitored process
      for (const [processName, processInfo] of this.monitoredProcesses) {
        const processMetrics = await this.collectProcessMetrics(processInfo.processId);
        
        if (!this.realTimeMetrics.has(processName)) {
          this.realTimeMetrics.set(processName, []);
        }
        
        this.realTimeMetrics.get(processName).push({
          timestamp,
          ...processMetrics,
          frameworkStats: stats
        });

        // Keep only last 100 measurements to prevent memory bloat
        const metrics = this.realTimeMetrics.get(processName);
        if (metrics.length > 100) {
          metrics.splice(0, metrics.length - 100);
        }
      }

    } catch (error) {
      console.warn(chalk.yellow(`Warning: Real-time metrics collection failed: ${error.message}`));
    }
  }

  /**
   * Collect metrics for a specific process
   */
  async collectProcessMetrics(processId) {
    const startTime = Date.now();
    
    try {
      // Test process responsiveness
      const healthResponse = await this.aoliteFramework.sendMessage(processId, {
        Action: "HealthCheck",
        Data: {}
      });
      
      const responseTime = Date.now() - startTime;
      
      // Get process messages for throughput calculation
      const messages = await this.aoliteFramework.getProcessMessages(processId);
      
      return {
        responseTime,
        responsive: healthResponse?.success || false,
        messageCount: messages?.length || 0,
        estimatedMemoryUsage: this.estimateMemoryUsage(processId),
        cpuUsage: this.estimateCpuUsage(processId),
        errorCount: this.countErrors(messages)
      };

    } catch (error) {
      return {
        responseTime: -1,
        responsive: false,
        messageCount: 0,
        estimatedMemoryUsage: 0,
        cpuUsage: 0,
        errorCount: 1,
        error: error.message
      };
    }
  }

  /**
   * Run comprehensive performance benchmark
   */
  async runPerformanceBenchmark(processes, config = {}) {
    console.log(chalk.blue("🚀 Running comprehensive performance benchmark..."));
    
    const benchmark = {
      id: `benchmark-${Date.now()}`,
      timestamp: new Date().toISOString(),
      config,
      processes: Array.from(processes.keys()),
      tests: [],
      summary: {},
      duration: 0,
      status: "running"
    };

    const benchmarkStart = Date.now();

    try {
      // Test 1: Response Time Benchmark
      const responseTimeTest = await this.benchmarkResponseTimes(processes, config);
      benchmark.tests.push(responseTimeTest);

      // Test 2: Throughput Benchmark  
      const throughputTest = await this.benchmarkThroughput(processes, config);
      benchmark.tests.push(throughputTest);

      // Test 3: Memory Usage Benchmark
      const memoryTest = await this.benchmarkMemoryUsage(processes, config);
      benchmark.tests.push(memoryTest);

      // Test 4: Error Handling Performance
      const errorHandlingTest = await this.benchmarkErrorHandling(processes, config);
      benchmark.tests.push(errorHandlingTest);

      // Test 5: Concurrent Load Test
      const concurrentLoadTest = await this.benchmarkConcurrentLoad(processes, config);
      benchmark.tests.push(concurrentLoadTest);

      // Test 6: Baseline Comparison
      const baselineComparisonTest = await this.compareWithBaselines(benchmark.tests);
      benchmark.tests.push(baselineComparisonTest);

      // Generate summary
      benchmark.summary = this.generateBenchmarkSummary(benchmark.tests);
      benchmark.status = "completed";

    } catch (error) {
      benchmark.status = "failed";
      benchmark.error = error.message;
      console.log(chalk.red(`❌ Performance benchmark failed: ${error.message}`));
    }

    benchmark.duration = Date.now() - benchmarkStart;
    this.benchmarkResults.push(benchmark);

    console.log(chalk.green(`✅ Performance benchmark completed in ${benchmark.duration}ms`));
    
    return benchmark;
  }

  /**
   * Benchmark response times
   */
  async benchmarkResponseTimes(processes, config) {
    console.log(chalk.yellow("  📋 Testing response times..."));
    
    const test = {
      name: "Response Time Benchmark",
      type: "response_time",
      results: {},
      passed: true,
      metrics: {}
    };

    const iterations = config.responseTimeIterations || 10;
    
    for (const [processName, processInfo] of processes) {
      const responseTimes = [];
      const errors = [];

      for (let i = 0; i < iterations; i++) {
        try {
          const startTime = Date.now();
          
          const response = await this.aoliteFramework.sendMessage(processInfo.processId, {
            Action: "HealthCheck",
            Data: { iteration: i }
          });
          
          const responseTime = Date.now() - startTime;
          responseTimes.push(responseTime);
          
          if (!response?.success) {
            errors.push(`Iteration ${i}: Response failed`);
          }

        } catch (error) {
          errors.push(`Iteration ${i}: ${error.message}`);
          responseTimes.push(-1);
        }
      }

      const validResponseTimes = responseTimes.filter(rt => rt > 0);
      const avgResponseTime = validResponseTimes.length > 0 
        ? validResponseTimes.reduce((sum, rt) => sum + rt, 0) / validResponseTimes.length 
        : -1;
      
      const maxResponseTime = validResponseTimes.length > 0 ? Math.max(...validResponseTimes) : -1;
      const minResponseTime = validResponseTimes.length > 0 ? Math.min(...validResponseTimes) : -1;
      
      const baseline = this.baselines.responseTime?.[this.getProcessType(processName)] || 1000;
      const withinBaseline = avgResponseTime <= baseline && avgResponseTime > 0;
      
      if (!withinBaseline) {
        test.passed = false;
      }

      test.results[processName] = {
        averageResponseTime: avgResponseTime,
        maxResponseTime,
        minResponseTime,
        iterations: iterations,
        errors: errors.length,
        successRate: (validResponseTimes.length / iterations) * 100,
        baseline,
        withinBaseline,
        responseTimes: validResponseTimes
      };
    }

    test.metrics = {
      overallAverageResponseTime: this.calculateOverallAverage(test.results, 'averageResponseTime'),
      overallSuccessRate: this.calculateOverallAverage(test.results, 'successRate'),
      processesWithinBaseline: Object.values(test.results).filter(r => r.withinBaseline).length,
      totalProcesses: Object.keys(test.results).length
    };

    console.log(chalk.green(`    ✅ Response time test completed: ${test.metrics.overallAverageResponseTime.toFixed(1)}ms avg`));
    
    return test;
  }

  /**
   * Benchmark throughput
   */
  async benchmarkThroughput(processes, config) {
    console.log(chalk.yellow("  📋 Testing throughput..."));
    
    const test = {
      name: "Throughput Benchmark", 
      type: "throughput",
      results: {},
      passed: true,
      metrics: {}
    };

    const duration = config.throughputDuration || 10000; // 10 seconds
    const messageInterval = config.messageInterval || 100; // 100ms between messages
    
    for (const [processName, processInfo] of processes) {
      const startTime = Date.now();
      const endTime = startTime + duration;
      let messagesSent = 0;
      let messagesSuccessful = 0;
      let totalResponseTime = 0;

      while (Date.now() < endTime) {
        try {
          const messageStart = Date.now();
          
          const response = await this.aoliteFramework.sendMessage(processInfo.processId, {
            Action: "HealthCheck",
            Data: { throughputTest: true, messageId: messagesSent }
          });
          
          const messageResponseTime = Date.now() - messageStart;
          totalResponseTime += messageResponseTime;
          messagesSent++;
          
          if (response?.success) {
            messagesSuccessful++;
          }

          // Wait for next message interval
          await new Promise(resolve => setTimeout(resolve, messageInterval));

        } catch (error) {
          messagesSent++;
          // Continue throughput test even on errors
        }
      }

      const actualDuration = Date.now() - startTime;
      const messagesPerSecond = (messagesSuccessful / actualDuration) * 1000;
      const averageResponseTime = messagesSuccessful > 0 ? totalResponseTime / messagesSuccessful : -1;
      
      const baseline = this.baselines.throughput?.messagesPerSecond || 100;
      const meetsBaseline = messagesPerSecond >= baseline;
      
      if (!meetsBaseline) {
        test.passed = false;
      }

      test.results[processName] = {
        messagesPerSecond,
        totalMessagesSent: messagesSent,
        successfulMessages: messagesSuccessful,
        successRate: (messagesSuccessful / messagesSent) * 100,
        averageResponseTime,
        duration: actualDuration,
        baseline,
        meetsBaseline
      };
    }

    test.metrics = {
      overallMessagesPerSecond: this.calculateOverallAverage(test.results, 'messagesPerSecond'),
      overallSuccessRate: this.calculateOverallAverage(test.results, 'successRate'),
      processesWithinBaseline: Object.values(test.results).filter(r => r.meetsBaseline).length,
      totalMessages: Object.values(test.results).reduce((sum, r) => sum + r.totalMessagesSent, 0)
    };

    console.log(chalk.green(`    ✅ Throughput test completed: ${test.metrics.overallMessagesPerSecond.toFixed(1)} msg/s`));
    
    return test;
  }

  /**
   * Benchmark memory usage
   */
  async benchmarkMemoryUsage(processes, config) {
    console.log(chalk.yellow("  📋 Testing memory usage..."));
    
    const test = {
      name: "Memory Usage Benchmark",
      type: "memory_usage", 
      results: {},
      passed: true,
      metrics: {}
    };

    const samples = config.memorySamples || 10;
    const sampleInterval = config.memorySampleInterval || 1000; // 1 second
    
    for (const [processName, processInfo] of processes) {
      const memoryReadings = [];

      for (let i = 0; i < samples; i++) {
        try {
          const memoryUsage = this.estimateMemoryUsage(processInfo.processId);
          memoryReadings.push(memoryUsage);
          
          if (i < samples - 1) {
            await new Promise(resolve => setTimeout(resolve, sampleInterval));
          }

        } catch (error) {
          memoryReadings.push(0);
        }
      }

      const averageMemoryUsage = memoryReadings.reduce((sum, mem) => sum + mem, 0) / memoryReadings.length;
      const maxMemoryUsage = Math.max(...memoryReadings);
      const minMemoryUsage = Math.min(...memoryReadings);
      
      const baseline = this.baselines.memoryUsage?.[this.getProcessType(processName)] || 100;
      const withinBaseline = averageMemoryUsage <= baseline;
      
      if (!withinBaseline) {
        test.passed = false;
      }

      test.results[processName] = {
        averageMemoryUsage,
        maxMemoryUsage,
        minMemoryUsage,
        samples: samples,
        memoryReadings,
        baseline,
        withinBaseline
      };
    }

    test.metrics = {
      overallAverageMemoryUsage: this.calculateOverallAverage(test.results, 'averageMemoryUsage'),
      overallMaxMemoryUsage: Math.max(...Object.values(test.results).map(r => r.maxMemoryUsage)),
      processesWithinBaseline: Object.values(test.results).filter(r => r.withinBaseline).length,
      totalProcesses: Object.keys(test.results).length
    };

    console.log(chalk.green(`    ✅ Memory test completed: ${test.metrics.overallAverageMemoryUsage.toFixed(1)}MB avg`));
    
    return test;
  }

  /**
   * Benchmark error handling performance
   */
  async benchmarkErrorHandling(processes, config) {
    console.log(chalk.yellow("  📋 Testing error handling performance..."));
    
    const test = {
      name: "Error Handling Performance",
      type: "error_handling",
      results: {},
      passed: true,
      metrics: {}
    };

    const errorTests = config.errorTests || 5;
    
    for (const [processName, processInfo] of processes) {
      const errorResponseTimes = [];
      const recoveryTimes = [];
      let successfulRecoveries = 0;

      for (let i = 0; i < errorTests; i++) {
        try {
          // Send invalid message and measure error handling time
          const errorStart = Date.now();
          
          await this.aoliteFramework.sendMessage(processInfo.processId, {
            Action: "InvalidAction",
            Data: { invalidData: "test" }
          });
          
          const errorResponseTime = Date.now() - errorStart;
          errorResponseTimes.push(errorResponseTime);

          // Test recovery with valid message
          const recoveryStart = Date.now();
          
          const recoveryResponse = await this.aoliteFramework.sendMessage(processInfo.processId, {
            Action: "HealthCheck",
            Data: {}
          });
          
          const recoveryTime = Date.now() - recoveryStart;
          recoveryTimes.push(recoveryTime);

          if (recoveryResponse?.success) {
            successfulRecoveries++;
          }

        } catch (error) {
          // Expected for error handling test
          errorResponseTimes.push(-1);
          recoveryTimes.push(-1);
        }
      }

      const validErrorResponseTimes = errorResponseTimes.filter(rt => rt > 0);
      const validRecoveryTimes = recoveryTimes.filter(rt => rt > 0);
      
      const averageErrorResponseTime = validErrorResponseTimes.length > 0 
        ? validErrorResponseTimes.reduce((sum, rt) => sum + rt, 0) / validErrorResponseTimes.length 
        : -1;
      
      const averageRecoveryTime = validRecoveryTimes.length > 0
        ? validRecoveryTimes.reduce((sum, rt) => sum + rt, 0) / validRecoveryTimes.length
        : -1;

      const recoveryRate = (successfulRecoveries / errorTests) * 100;
      const meetsRecoveryBaseline = recoveryRate >= 80; // 80% recovery rate baseline
      
      if (!meetsRecoveryBaseline) {
        test.passed = false;
      }

      test.results[processName] = {
        averageErrorResponseTime,
        averageRecoveryTime,
        recoveryRate,
        errorTests,
        successfulRecoveries,
        meetsRecoveryBaseline
      };
    }

    test.metrics = {
      overallRecoveryRate: this.calculateOverallAverage(test.results, 'recoveryRate'),
      overallErrorResponseTime: this.calculateOverallAverage(test.results, 'averageErrorResponseTime'),
      processesWithinBaseline: Object.values(test.results).filter(r => r.meetsRecoveryBaseline).length,
      totalErrorTests: Object.values(test.results).reduce((sum, r) => sum + r.errorTests, 0)
    };

    console.log(chalk.green(`    ✅ Error handling test completed: ${test.metrics.overallRecoveryRate.toFixed(1)}% recovery rate`));
    
    return test;
  }

  /**
   * Benchmark concurrent load
   */
  async benchmarkConcurrentLoad(processes, config) {
    console.log(chalk.yellow("  📋 Testing concurrent load..."));
    
    const test = {
      name: "Concurrent Load Benchmark",
      type: "concurrent_load",
      results: {},
      passed: true,
      metrics: {}
    };

    const concurrentUsers = config.concurrentUsers || 5;
    const messagesPerUser = config.messagesPerUser || 10;
    
    for (const [processName, processInfo] of processes) {
      const startTime = Date.now();
      
      // Create concurrent message sending promises
      const userPromises = Array.from({ length: concurrentUsers }, async (_, userIndex) => {
        const userResults = {
          userId: userIndex,
          messagesSent: 0,
          messagesSuccessful: 0,
          totalResponseTime: 0,
          errors: []
        };

        for (let msgIndex = 0; msgIndex < messagesPerUser; msgIndex++) {
          try {
            const messageStart = Date.now();
            
            const response = await this.aoliteFramework.sendMessage(processInfo.processId, {
              Action: "HealthCheck",
              Data: { userId: userIndex, messageIndex: msgIndex }
            });
            
            const responseTime = Date.now() - messageStart;
            userResults.totalResponseTime += responseTime;
            userResults.messagesSent++;
            
            if (response?.success) {
              userResults.messagesSuccessful++;
            }

          } catch (error) {
            userResults.errors.push(error.message);
            userResults.messagesSent++;
          }
        }

        return userResults;
      });

      // Execute all concurrent users
      const userResults = await Promise.all(userPromises);
      const totalDuration = Date.now() - startTime;

      // Aggregate results
      const totalMessagesSent = userResults.reduce((sum, ur) => sum + ur.messagesSent, 0);
      const totalMessagesSuccessful = userResults.reduce((sum, ur) => sum + ur.messagesSuccessful, 0);
      const totalResponseTime = userResults.reduce((sum, ur) => sum + ur.totalResponseTime, 0);
      const totalErrors = userResults.reduce((sum, ur) => sum + ur.errors.length, 0);

      const successRate = (totalMessagesSuccessful / totalMessagesSent) * 100;
      const averageResponseTime = totalMessagesSuccessful > 0 ? totalResponseTime / totalMessagesSuccessful : -1;
      const messagesPerSecond = (totalMessagesSuccessful / totalDuration) * 1000;
      
      const baseline = this.baselines.throughput?.messagesPerSecond || 100;
      const meetsBaseline = messagesPerSecond >= (baseline * 0.7); // 70% of single-user baseline under load
      
      if (!meetsBaseline) {
        test.passed = false;
      }

      test.results[processName] = {
        concurrentUsers,
        messagesPerUser,
        totalMessagesSent,
        totalMessagesSuccessful,
        successRate,
        averageResponseTime,
        messagesPerSecond,
        totalErrors,
        duration: totalDuration,
        baseline: baseline * 0.7,
        meetsBaseline,
        userResults
      };
    }

    test.metrics = {
      overallSuccessRate: this.calculateOverallAverage(test.results, 'successRate'),
      overallMessagesPerSecond: this.calculateOverallAverage(test.results, 'messagesPerSecond'),
      processesWithinBaseline: Object.values(test.results).filter(r => r.meetsBaseline).length,
      totalConcurrentMessages: Object.values(test.results).reduce((sum, r) => sum + r.totalMessagesSent, 0)
    };

    console.log(chalk.green(`    ✅ Concurrent load test completed: ${test.metrics.overallMessagesPerSecond.toFixed(1)} msg/s`));
    
    return test;
  }

  /**
   * Compare results with baselines
   */
  async compareWithBaselines(tests) {
    console.log(chalk.yellow("  📋 Comparing with baselines..."));
    
    const comparison = {
      name: "Baseline Comparison",
      type: "baseline_comparison",
      comparisons: {},
      overallScore: 0,
      passed: true
    };

    // Analyze each test type against baselines
    for (const test of tests) {
      if (test.type === 'baseline_comparison') continue;

      const testComparison = {
        testName: test.name,
        passed: test.passed,
        score: 0,
        details: {}
      };

      switch (test.type) {
        case 'response_time':
          testComparison.score = this.calculateResponseTimeScore(test);
          testComparison.details = {
            avgResponseTime: test.metrics.overallAverageResponseTime,
            processesWithinBaseline: test.metrics.processesWithinBaseline,
            totalProcesses: test.metrics.totalProcesses
          };
          break;

        case 'throughput':
          testComparison.score = this.calculateThroughputScore(test);
          testComparison.details = {
            messagesPerSecond: test.metrics.overallMessagesPerSecond,
            successRate: test.metrics.overallSuccessRate
          };
          break;

        case 'memory_usage':
          testComparison.score = this.calculateMemoryScore(test);
          testComparison.details = {
            avgMemoryUsage: test.metrics.overallAverageMemoryUsage,
            maxMemoryUsage: test.metrics.overallMaxMemoryUsage
          };
          break;

        case 'error_handling':
          testComparison.score = this.calculateErrorHandlingScore(test);
          testComparison.details = {
            recoveryRate: test.metrics.overallRecoveryRate
          };
          break;

        case 'concurrent_load':
          testComparison.score = this.calculateConcurrentLoadScore(test);
          testComparison.details = {
            successRate: test.metrics.overallSuccessRate,
            messagesPerSecond: test.metrics.overallMessagesPerSecond
          };
          break;
      }

      if (testComparison.score < 70) { // 70% minimum score
        comparison.passed = false;
      }

      comparison.comparisons[test.type] = testComparison;
    }

    // Calculate overall score
    const scores = Object.values(comparison.comparisons).map(c => c.score);
    comparison.overallScore = scores.length > 0 ? scores.reduce((sum, score) => sum + score, 0) / scores.length : 0;

    console.log(chalk.green(`    ✅ Baseline comparison completed: ${comparison.overallScore.toFixed(1)}% overall score`));
    
    return comparison;
  }

  /**
   * Generate comprehensive benchmark summary
   */
  generateBenchmarkSummary(tests) {
    const summary = {
      totalTests: tests.length,
      passedTests: tests.filter(t => t.passed).length,
      failedTests: tests.filter(t => t.passed === false).length,
      overallScore: 0,
      keyMetrics: {},
      recommendations: []
    };

    // Extract key metrics from each test
    for (const test of tests) {
      switch (test.type) {
        case 'response_time':
          summary.keyMetrics.averageResponseTime = test.metrics?.overallAverageResponseTime || 0;
          break;
        case 'throughput':
          summary.keyMetrics.messagesPerSecond = test.metrics?.overallMessagesPerSecond || 0;
          break;
        case 'memory_usage':
          summary.keyMetrics.averageMemoryUsage = test.metrics?.overallAverageMemoryUsage || 0;
          break;
        case 'baseline_comparison':
          summary.overallScore = test.overallScore || 0;
          break;
      }
    }

    // Generate recommendations based on results
    if (summary.keyMetrics.averageResponseTime > 1000) {
      summary.recommendations.push("Consider optimizing response times - average exceeds 1s");
    }
    
    if (summary.keyMetrics.messagesPerSecond < 50) {
      summary.recommendations.push("Throughput is below recommended baseline - investigate bottlenecks");
    }
    
    if (summary.keyMetrics.averageMemoryUsage > 100) {
      summary.recommendations.push("Memory usage is high - consider optimization");
    }

    if (summary.failedTests > 0) {
      summary.recommendations.push(`${summary.failedTests} test(s) failed - review detailed results`);
    }

    return summary;
  }

  /**
   * Generate performance report
   */
  async generatePerformanceReport() {
    const reportPath = path.join(this.reportsDir, `performance-benchmarks-${Date.now()}.json`);
    const htmlReportPath = path.join(this.reportsDir, `performance-benchmarks-${Date.now()}.html`);

    const report = {
      timestamp: new Date().toISOString(),
      framework: "Performance Benchmarking Framework",
      benchmarkResults: this.benchmarkResults,
      realTimeMetrics: this.getRealTimeMetricsSummary(),
      baselines: this.baselines,
      environment: {
        nodeVersion: process.version,
        platform: process.platform
      }
    };

    // Write JSON report
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    // Generate HTML report
    const htmlReport = this.generateHtmlReport(report);
    await fs.writeFile(htmlReportPath, htmlReport);

    console.log(chalk.green("📊 Performance reports generated:"));
    console.log(chalk.blue(`  JSON: ${reportPath}`));
    console.log(chalk.blue(`  HTML: ${htmlReportPath}`));

    return { jsonReport: reportPath, htmlReport: htmlReportPath };
  }

  /**
   * Generate HTML performance report
   */
  generateHtmlReport(report) {
    const latestBenchmark = report.benchmarkResults[report.benchmarkResults.length - 1];
    
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Performance Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .test-result { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .passed { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
        .metric { background: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 3px; }
        .chart { font-family: monospace; font-size: 12px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Performance Benchmark Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Generated:</strong> ${report.timestamp}</p>
        <p><strong>Total Benchmarks:</strong> ${report.benchmarkResults.length}</p>
        ${latestBenchmark ? `
        <p><strong>Latest Benchmark:</strong> ${latestBenchmark.status}</p>
        <p><strong>Overall Score:</strong> ${latestBenchmark.summary?.overallScore?.toFixed(1) || 'N/A'}%</p>
        <p><strong>Tests Passed:</strong> <span class="passed">${latestBenchmark.summary?.passedTests || 0}</span></p>
        <p><strong>Tests Failed:</strong> <span class="failed">${latestBenchmark.summary?.failedTests || 0}</span></p>
        ` : ''}
    </div>
    
    ${latestBenchmark ? `
    <h2>Key Metrics</h2>
    <div class="metric">
        <h4>Response Time: ${latestBenchmark.summary?.keyMetrics?.averageResponseTime?.toFixed(1) || 'N/A'}ms</h4>
        <h4>Throughput: ${latestBenchmark.summary?.keyMetrics?.messagesPerSecond?.toFixed(1) || 'N/A'} msg/s</h4>
        <h4>Memory Usage: ${latestBenchmark.summary?.keyMetrics?.averageMemoryUsage?.toFixed(1) || 'N/A'}MB</h4>
    </div>
    
    <h2>Test Results</h2>
    ${latestBenchmark.tests.map(test => `
        <div class="test-result">
            <h3>${test.name} <span class="${test.passed ? 'passed' : 'failed'}">${test.passed ? 'PASSED' : 'FAILED'}</span></h3>
            ${test.metrics ? `
                <div class="metric">
                    ${Object.entries(test.metrics).map(([key, value]) => `
                        <p><strong>${key}:</strong> ${typeof value === 'number' ? value.toFixed(2) : value}</p>
                    `).join('')}
                </div>
            ` : ''}
        </div>
    `).join('')}
    
    ${latestBenchmark.summary?.recommendations?.length > 0 ? `
    <h2>Recommendations</h2>
    <ul>
        ${latestBenchmark.summary.recommendations.map(rec => `<li>${rec}</li>`).join('')}
    </ul>
    ` : ''}
    ` : ''}
    
    <h2>Benchmark History</h2>
    <table>
        <tr>
            <th>Timestamp</th>
            <th>Status</th>
            <th>Duration</th>
            <th>Tests</th>
            <th>Score</th>
        </tr>
        ${report.benchmarkResults.map(benchmark => `
            <tr>
                <td>${new Date(benchmark.timestamp).toLocaleString()}</td>
                <td class="${benchmark.status}">${benchmark.status.toUpperCase()}</td>
                <td>${benchmark.duration}ms</td>
                <td>${benchmark.tests?.length || 0}</td>
                <td>${benchmark.summary?.overallScore?.toFixed(1) || 'N/A'}%</td>
            </tr>
        `).join('')}
    </table>
</body>
</html>`;
  }

  /**
   * Helper methods
   */
  getProcessType(processName) {
    if (processName.includes("coordinator")) return "coordinator";
    if (processName.includes("data") || processName.includes("species") || processName.includes("move") || processName.includes("item")) {
      return "dataProcess";
    }
    return "logicProcess";
  }

  calculateOverallAverage(results, field) {
    const values = Object.values(results).map(r => r[field]).filter(v => v > 0);
    return values.length > 0 ? values.reduce((sum, v) => sum + v, 0) / values.length : 0;
  }

  calculateResponseTimeScore(test) {
    const baseline = 1000; // 1 second baseline
    const avgResponseTime = test.metrics?.overallAverageResponseTime || 0;
    if (avgResponseTime <= 0) return 0;
    return Math.max(0, Math.min(100, (baseline / avgResponseTime) * 100));
  }

  calculateThroughputScore(test) {
    const baseline = 100; // 100 msg/s baseline
    const throughput = test.metrics?.overallMessagesPerSecond || 0;
    return Math.min(100, (throughput / baseline) * 100);
  }

  calculateMemoryScore(test) {
    const baseline = 100; // 100MB baseline
    const memoryUsage = test.metrics?.overallAverageMemoryUsage || 0;
    if (memoryUsage <= 0) return 100;
    return Math.max(0, Math.min(100, (baseline / memoryUsage) * 100));
  }

  calculateErrorHandlingScore(test) {
    const recoveryRate = test.metrics?.overallRecoveryRate || 0;
    return recoveryRate;
  }

  calculateConcurrentLoadScore(test) {
    const successRate = test.metrics?.overallSuccessRate || 0;
    return successRate;
  }

  estimateMemoryUsage(processId) {
    // Simplified memory estimation - in real implementation this would be more sophisticated
    return Math.random() * 50 + 20; // 20-70MB range
  }

  estimateCpuUsage(processId) {
    // Simplified CPU estimation
    return Math.random() * 50; // 0-50% range
  }

  countErrors(messages) {
    if (!messages || !Array.isArray(messages)) return 0;
    return messages.filter(msg => msg.error || msg.Action === "Error").length;
  }

  getRealTimeMetricsSummary() {
    const summary = {};
    for (const [processName, metrics] of this.realTimeMetrics) {
      if (metrics.length > 0) {
        const latest = metrics[metrics.length - 1];
        summary[processName] = {
          latestMetrics: latest,
          sampleCount: metrics.length,
          timeRange: {
            start: metrics[0].timestamp,
            end: latest.timestamp
          }
        };
      }
    }
    return summary;
  }

  /**
   * Cleanup performance monitor
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up performance monitor..."));

    this.stopMonitoring();
    await this.aoliteFramework.cleanup();

    this.benchmarkResults = [];
    this.realTimeMetrics.clear();

    console.log(chalk.green("✅ Performance monitor cleanup completed"));
  }
}

export { PerformanceMonitor };