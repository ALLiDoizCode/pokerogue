/**
 * Test Worker for Parallel Execution
 * Executes individual test jobs in isolated worker threads
 */

const { parentPort } = require("worker_threads");
const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

class TestWorker {
  constructor() {
    this.currentJob = null;
    this.startTime = null;

    // Listen for messages from parent
    parentPort.on("message", message => {
      this.handleMessage(message);
    });
  }

  handleMessage(message) {
    switch (message.type) {
      case "execute":
        this.executeJob(message.job);
        break;
      default:
        this.sendMessage("error", { error: `Unknown message type: ${message.type}` });
    }
  }

  async executeJob(job) {
    this.currentJob = job;
    this.startTime = Date.now();

    try {
      this.sendMessage("progress", { progress: "starting", jobId: job.id });

      const result = await this.runTestCommand(job);

      this.sendMessage("completed", {
        jobId: job.id,
        success: result.success,
        output: result.output,
        error: result.error,
        artifacts: await this.collectArtifacts(job),
        metrics: this.calculateMetrics(result),
      });
    } catch (error) {
      this.sendMessage("failed", {
        jobId: job.id,
        error: error.message,
        stack: error.stack,
      });
    }
  }

  async runTestCommand(job) {
    return new Promise(resolve => {
      const { testCommand, timeout } = job;

      this.sendMessage("progress", {
        progress: "executing",
        jobId: job.id,
        command: testCommand,
      });

      const child = spawn("sh", ["-c", testCommand], {
        stdio: ["pipe", "pipe", "pipe"],
        env: {
          ...process.env,
          NODE_ENV: "test",
          TEST_WORKER_ID: `worker-${process.pid}`,
          PROCESS_NAME: job.process,
          FRAMEWORK: job.framework,
        },
      });

      let stdout = "";
      let stderr = "";

      child.stdout.on("data", data => {
        stdout += data.toString();
        // Send periodic progress updates
        this.sendMessage("progress", {
          progress: "running",
          jobId: job.id,
          output: data.toString().slice(-200), // Last 200 chars
        });
      });

      child.stderr.on("data", data => {
        stderr += data.toString();
      });

      const timeoutId = setTimeout(() => {
        child.kill("SIGTERM");
        resolve({
          success: false,
          exitCode: -1,
          stdout,
          stderr: stderr + "\nTest command timed out",
          duration: Date.now() - this.startTime,
          timedOut: true,
        });
      }, timeout);

      child.on("close", code => {
        clearTimeout(timeoutId);

        const result = {
          success: code === 0,
          exitCode: code,
          stdout,
          stderr,
          duration: Date.now() - this.startTime,
          timedOut: false,
        };

        // Parse test results from output
        result.testResults = this.parseTestResults(stdout, stderr, job.framework);

        resolve(result);
      });

      child.on("error", error => {
        clearTimeout(timeoutId);
        resolve({
          success: false,
          exitCode: -1,
          stdout,
          stderr: stderr + `\nProcess error: ${error.message}`,
          duration: Date.now() - this.startTime,
          error: error.message,
        });
      });
    });
  }

  parseTestResults(stdout, stderr, framework) {
    const results = {
      framework,
      tests: {
        total: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
      },
      coverage: null,
      errors: [],
    };

    try {
      switch (framework) {
        case "aolite":
          return this.parseAoliteResults(stdout, stderr, results);
        case "aos-local":
          return this.parseAosLocalResults(stdout, stderr, results);
        case "integration":
          return this.parseIntegrationResults(stdout, stderr, results);
        case "parity":
          return this.parseParityResults(stdout, stderr, results);
        default:
          return this.parseGenericResults(stdout, stderr, results);
      }
    } catch (error) {
      results.errors.push(`Failed to parse test results: ${error.message}`);
      return results;
    }
  }

  parseAoliteResults(stdout, _stderr, results) {
    // Parse aolite-specific output
    const lines = stdout.split("\n");

    for (const line of lines) {
      if (line.includes("✓") || line.includes("PASS")) {
        results.tests.passed++;
        results.tests.total++;
      } else if (line.includes("✗") || line.includes("FAIL")) {
        results.tests.failed++;
        results.tests.total++;
        results.errors.push(line.trim());
      } else if (line.includes("SKIP")) {
        results.tests.skipped++;
        results.tests.total++;
      }
    }

    // Look for coverage information
    const coverageMatch = stdout.match(/coverage:\s*(\d+(?:\.\d+)?)%/i);
    if (coverageMatch) {
      results.coverage = Number.parseFloat(coverageMatch[1]);
    }

    return results;
  }

  parseAosLocalResults(stdout, stderr, results) {
    // Parse aos-local-specific output (Jest-like)
    const testSuiteMatch = stdout.match(/Tests:\s*(\d+)\s*passed.*?(\d+)\s*total/);
    if (testSuiteMatch) {
      results.tests.passed = Number.parseInt(testSuiteMatch[1]);
      results.tests.total = Number.parseInt(testSuiteMatch[2]);
      results.tests.failed = results.tests.total - results.tests.passed;
    }

    // Extract error messages
    const errorMatches = stderr.match(/Error:.*$/gm);
    if (errorMatches) {
      results.errors.push(...errorMatches);
    }

    return results;
  }

  parseIntegrationResults(stdout, _stderr, results) {
    // Parse integration test results
    const lines = stdout.split("\n");

    for (const line of lines) {
      if (line.includes("scenario") && line.includes("✓")) {
        results.tests.passed++;
        results.tests.total++;
      } else if (line.includes("scenario") && line.includes("✗")) {
        results.tests.failed++;
        results.tests.total++;
        results.errors.push(line.trim());
      }
    }

    return results;
  }

  parseParityResults(stdout, _stderr, results) {
    // Parse parity validation results
    const parityMatch = stdout.match(/Parity:\s*(\d+)\/(\d+)\s*tests passed/);
    if (parityMatch) {
      results.tests.passed = Number.parseInt(parityMatch[1]);
      results.tests.total = Number.parseInt(parityMatch[2]);
      results.tests.failed = results.tests.total - results.tests.passed;
    }

    // Extract parity failures
    const parityFailures = stdout.match(/PARITY FAIL:.*$/gm);
    if (parityFailures) {
      results.errors.push(...parityFailures);
    }

    return results;
  }

  parseGenericResults(stdout, _stderr, results) {
    // Generic parser for unknown frameworks
    const lines = stdout.split("\n");

    for (const line of lines) {
      if (line.match(/pass|success|✓|ok/i)) {
        results.tests.passed++;
        results.tests.total++;
      } else if (line.match(/fail|error|✗|not ok/i)) {
        results.tests.failed++;
        results.tests.total++;
        results.errors.push(line.trim());
      }
    }

    return results;
  }

  async collectArtifacts(job) {
    const artifacts = [];
    const artifactDirs = [
      "testing/reports",
      "testing/coverage",
      "testing/aolite",
      "testing/aos-local",
      "testing/integration",
    ];

    for (const dir of artifactDirs) {
      const fullPath = path.join(process.cwd(), dir);

      try {
        if (fs.existsSync(fullPath)) {
          const files = fs.readdirSync(fullPath);

          for (const file of files) {
            // Look for files related to this job
            if (file.includes(job.process) || file.includes(job.framework)) {
              const filePath = path.join(fullPath, file);
              const stats = fs.statSync(filePath);

              artifacts.push({
                path: filePath,
                size: stats.size,
                modified: stats.mtime.toISOString(),
                type: this.getArtifactType(file),
              });
            }
          }
        }
      } catch (_error) {
        // Ignore errors when collecting artifacts
      }
    }

    return artifacts;
  }

  getArtifactType(filename) {
    if (filename.endsWith(".json")) {
      return "report";
    }
    if (filename.endsWith(".log")) {
      return "log";
    }
    if (filename.endsWith(".txt")) {
      return "text";
    }
    if (filename.includes("coverage")) {
      return "coverage";
    }
    return "unknown";
  }

  calculateMetrics(result) {
    const metrics = {
      duration: result.duration,
      exitCode: result.exitCode,
      timedOut: result.timedOut,
      outputSize: (result.stdout || "").length + (result.stderr || "").length,
    };

    // Add test-specific metrics
    if (result.testResults) {
      metrics.testCount = result.testResults.tests.total;
      metrics.successRate =
        result.testResults.tests.total > 0
          ? (result.testResults.tests.passed / result.testResults.tests.total) * 100
          : 0;
      metrics.coverage = result.testResults.coverage;
      metrics.errorCount = result.testResults.errors.length;
    }

    // Memory usage (if available)
    const memUsage = process.memoryUsage();
    metrics.memoryUsage = {
      heapUsed: memUsage.heapUsed,
      heapTotal: memUsage.heapTotal,
      external: memUsage.external,
    };

    return metrics;
  }

  sendMessage(type, data) {
    parentPort.postMessage({
      type,
      timestamp: new Date().toISOString(),
      workerId: process.pid,
      ...data,
    });
  }
}

// Initialize worker
new TestWorker();
