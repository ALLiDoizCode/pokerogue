/**
 * Performance Baselines
 * Baseline performance metrics for process validation
 */

export const performanceBaselines = {
  // Deployment time baselines (milliseconds)
  deploymentTime: {
    coordinator: 2000,        // 2 seconds max for coordinator process
    dataProcess: 1500,        // 1.5 seconds max for data processes
    logicProcess: 3000,       // 3 seconds max for logic processes
    evolutionProcess: 2000,   // 2 seconds max for evolution process
    statusEffectsProcess: 1800 // 1.8 seconds max for status effects
  },

  // Response time baselines (milliseconds)
  responseTime: {
    coordinator: 1000,        // 1 second max response time
    dataProcess: 500,         // 0.5 seconds max for data queries
    logicProcess: 2000,       // 2 seconds max for complex logic
    evolutionProcess: 1500,   // 1.5 seconds max for evolution checks
    statusEffectsProcess: 800 // 0.8 seconds max for status effects
  },

  // Memory usage baselines (MB)
  memoryUsage: {
    coordinator: 50,          // 50MB max for coordinator
    dataProcess: 30,          // 30MB max for data processes
    logicProcess: 80,         // 80MB max for logic processes
    evolutionProcess: 40,     // 40MB max for evolution process
    statusEffectsProcess: 35  // 35MB max for status effects
  },

  // Throughput baselines
  throughput: {
    messagesPerSecond: 100,   // 100 messages per second baseline
    queriesPerSecond: 200,    // 200 queries per second for data processes
    battlesPerMinute: 30,     // 30 battles per minute for battle engine
    evolutionsPerMinute: 60   // 60 evolution checks per minute
  },

  // Error rate thresholds
  errorRates: {
    maxErrorRate: 0.05,       // 5% maximum error rate
    maxTimeoutRate: 0.02,     // 2% maximum timeout rate
    maxFailureRate: 0.01,     // 1% maximum failure rate
    maxRecoveryTime: 3000     // 3 seconds maximum recovery time
  },

  // Process size constraints
  processSize: {
    maximum: 500000,          // 500KB absolute maximum
    warning: 450000,          // 450KB warning threshold (90% of max)
    optimal: 400000,          // 400KB optimal size (80% of max)
    coordinator: 500000,      // Coordinator can use full size
    dataProcess: 450000,      // Data processes should be smaller
    logicProcess: 500000      // Logic processes can use full size
  },

  // Initialization baselines
  initialization: {
    maxInitTime: 3000,        // 3 seconds maximum initialization time
    maxHandlerRegistration: 1000, // 1 second max for handler registration
    maxDataLoading: 2000,     // 2 seconds max for data loading
    maxValidation: 500        // 0.5 seconds max for validation
  },

  // Network and communication baselines
  communication: {
    maxMessageLatency: 100,   // 100ms max message latency
    maxProcessingDelay: 200,  // 200ms max processing delay
    maxQueueTime: 50,         // 50ms max queue time
    maxRetryAttempts: 3       // 3 maximum retry attempts
  },

  // Concurrent load baselines
  concurrentLoad: {
    maxConcurrentUsers: 50,   // 50 concurrent users max
    maxConcurrentMessages: 100, // 100 concurrent messages max
    maxConcurrentProcesses: 26, // 26 processes maximum (full architecture)
    degradationThreshold: 0.3 // 30% performance degradation threshold
  },

  // Battle simulation baselines
  battleSimulation: {
    maxTurnProcessingTime: 500,  // 0.5 seconds max per turn
    maxBattleInitTime: 1000,     // 1 second max battle initialization
    maxDamageCalculationTime: 50, // 50ms max damage calculation
    maxStatusEffectTime: 100,    // 100ms max status effect processing
    maxBattleDuration: 300000    // 5 minutes max battle duration
  },

  // Data consistency baselines
  dataConsistency: {
    maxSyncTime: 2000,        // 2 seconds max data synchronization
    maxValidationTime: 500,   // 0.5 seconds max data validation
    maxConsistencyCheckTime: 1000, // 1 second max consistency check
    allowedInconsistencyRate: 0.001 // 0.1% allowed inconsistency rate
  },

  // Recovery and resilience baselines
  recovery: {
    maxFailureDetectionTime: 2000, // 2 seconds max failure detection
    maxRecoveryTime: 5000,         // 5 seconds max recovery time
    maxRestartTime: 3000,          // 3 seconds max restart time
    minSuccessfulRecoveryRate: 0.95 // 95% minimum successful recovery rate
  },

  // Performance regression thresholds
  regression: {
    responseTimeRegression: 0.2,   // 20% response time regression threshold
    throughputRegression: 0.15,    // 15% throughput regression threshold
    memoryRegression: 0.3,         // 30% memory usage regression threshold
    errorRateRegression: 0.1       // 10% error rate regression threshold
  }
};

// Environment-specific baselines
export const environmentBaselines = {
  development: {
    ...performanceBaselines,
    // More lenient baselines for development
    responseTime: {
      coordinator: 2000,
      dataProcess: 1000,
      logicProcess: 4000,
      evolutionProcess: 3000,
      statusEffectsProcess: 1600
    },
    errorRates: {
      maxErrorRate: 0.1,    // 10% for development
      maxTimeoutRate: 0.05, // 5% for development
      maxFailureRate: 0.02, // 2% for development
      maxRecoveryTime: 5000
    }
  },

  testing: {
    ...performanceBaselines,
    // Standard baselines for testing (same as production)
  },

  production: {
    ...performanceBaselines,
    // Stricter baselines for production
    responseTime: {
      coordinator: 800,
      dataProcess: 300,
      logicProcess: 1500,
      evolutionProcess: 1000,
      statusEffectsProcess: 600
    },
    errorRates: {
      maxErrorRate: 0.02,   // 2% for production
      maxTimeoutRate: 0.01, // 1% for production
      maxFailureRate: 0.005, // 0.5% for production
      maxRecoveryTime: 2000
    }
  }
};

// Test scenario specific baselines
export const scenarioBaselines = {
  quickValidation: {
    maxTotalTime: 30000,      // 30 seconds max for quick validation
    maxProcesses: 5,          // 5 processes max
    maxMemoryUsage: 200       // 200MB max total memory
  },

  fullValidation: {
    maxTotalTime: 300000,     // 5 minutes max for full validation
    maxProcesses: 26,         // All 26 processes
    maxMemoryUsage: 1000      // 1GB max total memory
  },

  performanceValidation: {
    maxTotalTime: 180000,     // 3 minutes max for performance tests
    maxProcesses: 10,         // 10 processes max
    maxMemoryUsage: 500,      // 500MB max
    minThroughput: 50         // 50 operations/second minimum
  },

  stressTest: {
    maxTotalTime: 600000,     // 10 minutes max for stress testing
    maxProcesses: 26,         // All processes
    maxMemoryUsage: 2000,     // 2GB max under stress
    minThroughput: 25,        // 25 operations/second minimum under stress
    maxConcurrentLoad: 100    // 100 concurrent operations
  }
};

// Benchmark scoring weights
export const benchmarkWeights = {
  responseTime: 0.25,       // 25% weight for response time
  throughput: 0.20,         // 20% weight for throughput
  memoryUsage: 0.15,        // 15% weight for memory usage
  errorHandling: 0.15,      // 15% weight for error handling
  concurrentLoad: 0.15,     // 15% weight for concurrent load
  baselineCompliance: 0.10  // 10% weight for baseline compliance
};

// Performance alert thresholds
export const alertThresholds = {
  critical: {
    responseTime: 5000,       // 5 seconds - critical alert
    errorRate: 0.1,           // 10% error rate - critical
    memoryUsage: 200,         // 200MB per process - critical
    throughput: 10            // 10 operations/second - critical
  },

  warning: {
    responseTime: 2000,       // 2 seconds - warning
    errorRate: 0.05,          // 5% error rate - warning
    memoryUsage: 100,         // 100MB per process - warning
    throughput: 50            // 50 operations/second - warning
  },

  info: {
    responseTime: 1000,       // 1 second - info
    errorRate: 0.02,          // 2% error rate - info
    memoryUsage: 50,          // 50MB per process - info
    throughput: 100           // 100 operations/second - info
  }
};

export default {
  performanceBaselines,
  environmentBaselines,
  scenarioBaselines,
  benchmarkWeights,
  alertThresholds
};