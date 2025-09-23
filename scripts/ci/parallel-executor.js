#!/usr/bin/env node

/**
 * Parallel Test Execution Framework for AO Process Testing
 * Optimizes test execution by running processes in parallel across multiple testing frameworks
 */

const fs = require("fs");
const path = require("path");
const { Worker } = require("worker_threads");
const EventEmitter = require("events");

class ParallelExecutor extends EventEmitter {
  constructor(options = {}) {
    super();
    this.config = {
      maxConcurrent: options.maxConcurrent || 4,
      timeout: options.timeout || 300000,
      retryAttempts: options.retryAttempts || 1,
      resourceMonitoring: options.resourceMonitoring || true,
      ...options,
    };

    this.workers = new Map();
    this.activeJobs = new Map();
    this.completedJobs = new Map();
    this.jobQueue = [];
    this.metrics = {
      startTime: null,
      endTime: null,
      totalJobs: 0,
      completedJobs: 0,
      failedJobs: 0,
      averageExecutionTime: 0,
      resourceUsage: {
        peakMemory: 0,
        avgCpuUsage: 0,
      },
    };

    this.logger = this.createLogger();
  }

  createLogger() {
    return {
      info: (msg, ...args) => console.log(`[PARALLEL] ${new Date().toISOString()} ${msg}`, ...args),
      warn: (msg, ...args) => console.warn(`[PARALLEL] ${new Date().toISOString()} ${msg}`, ...args),
      error: (msg, ...args) => console.error(`[PARALLEL] ${new Date().toISOString()} ${msg}`, ...args),
      debug: (msg, ...args) => process.env.DEBUG && console.log(`[DEBUG] ${new Date().toISOString()} ${msg}`, ...args),
    };
  }

  async executeParallel(testMatrix) {
    this.metrics.startTime = new Date().toISOString();
    this.metrics.totalJobs = testMatrix.length;

    this.logger.info(`🚀 Starting parallel execution of ${testMatrix.length} test jobs`);
    this.logger.info(
      `Configuration: ${this.config.maxConcurrent} concurrent workers, ${this.config.timeout}ms timeout`,
    );

    try {
      // Initialize worker pool
      await this.initializeWorkerPool();

      // Start resource monitoring
      if (this.config.resourceMonitoring) {
        this.startResourceMonitoring();
      }

      // Queue all jobs
      this.jobQueue = [
        ...testMatrix.map(test => ({
          id: `${test.process}-${test.framework}`,
          ...test,
          status: "queued",
          attempts: 0,
        })),
      ];

      // Execute jobs in parallel
      const results = await this.processJobQueue();

      // Cleanup
      await this.cleanup();

      this.metrics.endTime = new Date().toISOString();
      this.calculateMetrics();

      this.logger.info(
        `✅ Parallel execution completed: ${this.metrics.completedJobs}/${this.metrics.totalJobs} jobs successful`,
      );

      return {
        success: this.metrics.failedJobs === 0,
        results,
        metrics: this.metrics,
      };
    } catch (error) {
      this.logger.error("❌ Parallel execution failed:", error.message);
      await this.cleanup();
      throw error;
    }
  }

  async initializeWorkerPool() {
    this.logger.debug(`Initializing ${this.config.maxConcurrent} workers`);

    for (let i = 0; i < this.config.maxConcurrent; i++) {
      const workerId = `worker-${i}`;
      const worker = new Worker(path.join(__dirname, "test-worker.js"));

      worker.on("message", message => {
        this.handleWorkerMessage(workerId, message);
      });

      worker.on("error", error => {
        this.logger.error(`Worker ${workerId} error:`, error);
        this.handleWorkerError(workerId, error);
      });

      worker.on("exit", code => {
        if (code !== 0) {
          this.logger.warn(`Worker ${workerId} exited with code ${code}`);
        }
      });

      this.workers.set(workerId, {
        worker,
        busy: false,
        currentJob: null,
      });
    }
  }

  async processJobQueue() {
    return new Promise((resolve, _reject) => {
      const _results = [];

      const checkCompletion = () => {
        if (this.completedJobs.size === this.metrics.totalJobs) {
          resolve(Array.from(this.completedJobs.values()));
        }
      };

      const processNextJob = () => {
        if (this.jobQueue.length === 0) {
          checkCompletion();
          return;
        }

        const availableWorker = this.getAvailableWorker();
        if (!availableWorker) {
          return; // All workers busy, wait for one to become available
        }

        const job = this.jobQueue.shift();
        this.assignJobToWorker(availableWorker.workerId, job);
      };

      // Handle worker completion
      this.on("jobCompleted", result => {
        this.completedJobs.set(result.jobId, result);
        this.metrics.completedJobs++;

        if (!result.success) {
          this.metrics.failedJobs++;
        }

        processNextJob();
      });

      // Handle worker failure with retry
      this.on("jobFailed", (jobId, error) => {
        const job = this.activeJobs.get(jobId);
        if (job && job.attempts < this.config.retryAttempts) {
          job.attempts++;
          job.status = "queued";
          this.jobQueue.unshift(job); // Retry at front of queue
          this.logger.warn(`Retrying job ${jobId} (attempt ${job.attempts}/${this.config.retryAttempts})`);
        } else {
          this.completedJobs.set(jobId, {
            jobId,
            success: false,
            error: error.message,
            attempts: job ? job.attempts : 0,
          });
          this.metrics.completedJobs++;
          this.metrics.failedJobs++;
        }

        processNextJob();
      });

      // Start processing
      for (let i = 0; i < Math.min(this.config.maxConcurrent, this.jobQueue.length); i++) {
        processNextJob();
      }
    });
  }

  getAvailableWorker() {
    for (const [workerId, workerInfo] of this.workers) {
      if (!workerInfo.busy) {
        return { workerId, ...workerInfo };
      }
    }
    return null;
  }

  assignJobToWorker(workerId, job) {
    const workerInfo = this.workers.get(workerId);
    if (!workerInfo) {
      this.logger.error(`Worker ${workerId} not found`);
      return;
    }

    workerInfo.busy = true;
    workerInfo.currentJob = job;
    job.status = "running";
    job.startTime = Date.now();

    this.activeJobs.set(job.id, job);

    this.logger.debug(`Assigning job ${job.id} to ${workerId}`);

    // Send job to worker
    workerInfo.worker.postMessage({
      type: "execute",
      job: {
        id: job.id,
        process: job.process,
        framework: job.framework,
        timeout: job.timeout || this.config.timeout,
        type: job.type,
        testCommand: this.generateTestCommand(job),
      },
    });

    // Set timeout for job
    setTimeout(() => {
      if (this.activeJobs.has(job.id)) {
        this.handleJobTimeout(workerId, job.id);
      }
    }, job.timeout || this.config.timeout);
  }

  generateTestCommand(job) {
    const { process, framework, type } = job;

    switch (framework) {
      case "aolite":
        return `npm run test:aolite -- --grep "${process}"`;
      case "aos-local":
        return `npm run test:aos-local -- --grep "${process}"`;
      case "integration":
        return `npm run test:all -- --grep "${process}"`;
      case "parity":
        return `npm run test:parity -- --grep "${process}"`;
      default:
        throw new Error(`Unknown framework: ${framework}`);
    }
  }

  handleWorkerMessage(workerId, message) {
    const _workerInfo = this.workers.get(workerId);

    switch (message.type) {
      case "completed":
        this.handleJobCompletion(workerId, message);
        break;
      case "failed":
        this.handleJobFailure(workerId, message);
        break;
      case "progress":
        this.handleJobProgress(workerId, message);
        break;
      default:
        this.logger.warn(`Unknown message type from ${workerId}:`, message.type);
    }
  }

  handleJobCompletion(workerId, message) {
    const workerInfo = this.workers.get(workerId);
    const job = workerInfo.currentJob;

    if (!job) {
      this.logger.warn(`Worker ${workerId} completed job but no current job found`);
      return;
    }

    const result = {
      jobId: job.id,
      process: job.process,
      framework: job.framework,
      type: job.type,
      success: message.success,
      duration: Date.now() - job.startTime,
      attempts: job.attempts,
      output: message.output,
      error: message.error,
      artifacts: message.artifacts || [],
      metrics: message.metrics || {},
    };

    // Free up worker
    workerInfo.busy = false;
    workerInfo.currentJob = null;
    this.activeJobs.delete(job.id);

    this.emit("jobCompleted", result);
  }

  handleJobFailure(workerId, message) {
    const workerInfo = this.workers.get(workerId);
    const job = workerInfo.currentJob;

    if (!job) {
      this.logger.warn(`Worker ${workerId} failed job but no current job found`);
      return;
    }

    // Free up worker
    workerInfo.busy = false;
    workerInfo.currentJob = null;
    this.activeJobs.delete(job.id);

    this.emit("jobFailed", job.id, new Error(message.error));
  }

  handleJobProgress(workerId, message) {
    this.logger.debug(`Job progress from ${workerId}:`, message.progress);
  }

  handleJobTimeout(workerId, jobId) {
    this.logger.warn(`Job ${jobId} timed out on worker ${workerId}`);

    const workerInfo = this.workers.get(workerId);
    if (workerInfo?.currentJob && workerInfo.currentJob.id === jobId) {
      // Terminate the worker and restart it
      workerInfo.worker.terminate();
      this.restartWorker(workerId);

      this.emit("jobFailed", jobId, new Error("Job timeout"));
    }
  }

  handleWorkerError(workerId, error) {
    this.logger.error(`Worker ${workerId} error:`, error);

    const workerInfo = this.workers.get(workerId);
    if (workerInfo?.currentJob) {
      this.emit("jobFailed", workerInfo.currentJob.id, error);
    }

    this.restartWorker(workerId);
  }

  async restartWorker(workerId) {
    this.logger.info(`Restarting worker ${workerId}`);

    const oldWorkerInfo = this.workers.get(workerId);
    if (oldWorkerInfo) {
      try {
        await oldWorkerInfo.worker.terminate();
      } catch (error) {
        this.logger.warn(`Failed to terminate worker ${workerId}:`, error.message);
      }
    }

    // Create new worker
    const worker = new Worker(path.join(__dirname, "test-worker.js"));

    worker.on("message", message => {
      this.handleWorkerMessage(workerId, message);
    });

    worker.on("error", error => {
      this.logger.error(`Worker ${workerId} error:`, error);
      this.handleWorkerError(workerId, error);
    });

    this.workers.set(workerId, {
      worker,
      busy: false,
      currentJob: null,
    });
  }

  startResourceMonitoring() {
    const interval = 5000; // Monitor every 5 seconds

    this.resourceMonitor = setInterval(() => {
      const memUsage = process.memoryUsage();
      this.metrics.resourceUsage.peakMemory = Math.max(this.metrics.resourceUsage.peakMemory, memUsage.heapUsed);

      // Emit resource usage for external monitoring
      this.emit("resourceUsage", {
        memory: memUsage,
        activeJobs: this.activeJobs.size,
        queuedJobs: this.jobQueue.length,
      });
    }, interval);
  }

  calculateMetrics() {
    const startTime = new Date(this.metrics.startTime).getTime();
    const endTime = new Date(this.metrics.endTime).getTime();
    const totalDuration = endTime - startTime;

    let totalExecutionTime = 0;
    for (const result of this.completedJobs.values()) {
      if (result.duration) {
        totalExecutionTime += result.duration;
      }
    }

    this.metrics.totalDuration = totalDuration;
    this.metrics.averageExecutionTime =
      this.metrics.completedJobs > 0 ? totalExecutionTime / this.metrics.completedJobs : 0;
    this.metrics.successRate =
      this.metrics.totalJobs > 0
        ? ((this.metrics.totalJobs - this.metrics.failedJobs) / this.metrics.totalJobs) * 100
        : 0;
    this.metrics.parallelizationEfficiency = totalDuration > 0 ? (totalExecutionTime / totalDuration) * 100 : 0;
  }

  async cleanup() {
    this.logger.debug("Cleaning up parallel executor");

    // Stop resource monitoring
    if (this.resourceMonitor) {
      clearInterval(this.resourceMonitor);
    }

    // Terminate all workers
    const terminationPromises = [];
    for (const [workerId, workerInfo] of this.workers) {
      terminationPromises.push(
        workerInfo.worker.terminate().catch(error => {
          this.logger.warn(`Failed to terminate worker ${workerId}:`, error.message);
        }),
      );
    }

    await Promise.all(terminationPromises);
    this.workers.clear();
  }

  generateReport() {
    const reportDir = path.join(process.cwd(), "testing/reports/parallel");

    if (!fs.existsSync(reportDir)) {
      fs.mkdirSync(reportDir, { recursive: true });
    }

    const report = {
      timestamp: new Date().toISOString(),
      metrics: this.metrics,
      configuration: this.config,
      results: Array.from(this.completedJobs.values()),
      summary: {
        totalJobs: this.metrics.totalJobs,
        completedJobs: this.metrics.completedJobs,
        failedJobs: this.metrics.failedJobs,
        successRate: this.metrics.successRate,
        averageExecutionTime: this.metrics.averageExecutionTime,
        parallelizationEfficiency: this.metrics.parallelizationEfficiency,
      },
    };

    const reportPath = path.join(reportDir, `parallel-execution-${Date.now()}.json`);
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

    this.logger.info(`📊 Parallel execution report generated: ${reportPath}`);

    return reportPath;
  }
}

// Default test matrix for AO processes
const DEFAULT_TEST_MATRIX = [
  { process: "pokemon-species-db", framework: "aolite", type: "data", timeout: 120000 },
  { process: "moves-database", framework: "aolite", type: "data", timeout: 120000 },
  { process: "items-database", framework: "aolite", type: "data", timeout: 120000 },
  { process: "abilities-database", framework: "aolite", type: "data", timeout: 120000 },
  { process: "battle-engine", framework: "aos-local", type: "logic", timeout: 300000 },
  { process: "evolution-engine", framework: "aos-local", type: "logic", timeout: 180000 },
  { process: "capture-engine", framework: "aos-local", type: "logic", timeout: 180000 },
  { process: "status-effects-engine", framework: "aos-local", type: "logic", timeout: 180000 },
  { process: "coordinator-process", framework: "integration", type: "coordinator", timeout: 300000 },
];

// CLI Interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = {
    maxConcurrent: 4,
    timeout: 300000,
    resourceMonitoring: true,
  };

  let testMatrixFile = null;

  // Parse command line arguments
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--concurrent":
        options.maxConcurrent = Number.parseInt(args[++i]);
        break;
      case "--timeout":
        options.timeout = Number.parseInt(args[++i]);
        break;
      case "--matrix":
        testMatrixFile = args[++i];
        break;
      case "--no-monitoring":
        options.resourceMonitoring = false;
        break;
      case "--help":
        console.log(`
Usage: node parallel-executor.js [options]

Options:
  --concurrent <n>       Maximum concurrent workers (default: 4)
  --timeout <ms>         Job timeout in milliseconds (default: 300000)
  --matrix <file>        JSON file with test matrix (uses default if not specified)
  --no-monitoring        Disable resource monitoring
  --help                 Show this help message

Examples:
  node parallel-executor.js --concurrent 6 --timeout 600000
  node parallel-executor.js --matrix custom-test-matrix.json
                `);
        process.exit(0);
        break;
    }
  }

  // Load test matrix
  let testMatrix = DEFAULT_TEST_MATRIX;
  if (testMatrixFile) {
    try {
      testMatrix = JSON.parse(fs.readFileSync(testMatrixFile, "utf8"));
    } catch (error) {
      console.error("Failed to load test matrix file:", error.message);
      process.exit(1);
    }
  }

  const executor = new ParallelExecutor(options);

  executor
    .executeParallel(testMatrix)
    .then(result => {
      executor.generateReport();
      console.log("✅ Parallel execution completed successfully");
      process.exit(result.success ? 0 : 1);
    })
    .catch(error => {
      console.error("❌ Parallel execution failed:", error.message);
      process.exit(1);
    });
}

module.exports = ParallelExecutor;
