/**
 * Test Scenarios for End-to-End Integration Testing
 * Comprehensive scenario definitions for deployment validation
 */

export const testScenarios = {
  // Basic deployment and communication scenario
  basicProcessCommunication: {
    id: "basic-process-communication",
    name: "Basic Process Communication",
    description: "Test basic message passing between coordinator and data process",
    timeout: 30000,
    processes: ["coordinator-process", "pokemon-species-data"],
    parallelDeployment: false,
    steps: [
      {
        type: "send_message",
        name: "Send species query",
        target: "pokemon-species-data",
        action: "QuerySpecies",
        data: { speciesId: 1 },
        tags: { From: "coordinator-process" }
      },
      {
        type: "wait_for_response",
        name: "Wait for species data response",
        source: "pokemon-species-data",
        expectedAction: "SpeciesData",
        timeout: 5000
      },
      {
        type: "validate_state",
        name: "Validate species data received",
        target: "coordinator-process",
        stateValidator: (state) => ({
          valid: state && state.lastSpeciesQuery !== undefined,
          error: state ? null : "No species query state found"
        })
      }
    ],
    finalValidation: [
      {
        type: "process_health",
        description: "All processes healthy",
        processes: ["coordinator-process", "pokemon-species-data"]
      }
    ],
    performance: {
      maxTotalTime: 25000,
      maxMemoryUsage: 200
    }
  },

  // Multi-process workflow scenario
  completeGameWorkflow: {
    id: "complete-game-workflow",
    name: "Complete Game Workflow",
    description: "Test complete game workflow from initialization to battle completion",
    timeout: 60000,
    processes: ["coordinator-process", "pokemon-species-data", "move-data", "battle-engine"],
    parallelDeployment: true,
    steps: [
      {
        type: "multi_process_interaction",
        name: "Initialize game data",
        interactions: [
          {
            from: "coordinator-process",
            to: "pokemon-species-data",
            action: "LoadSpeciesData",
            data: { batchSize: 10 }
          },
          {
            from: "coordinator-process",
            to: "move-data",
            action: "LoadMoveData",
            data: { batchSize: 20 }
          }
        ]
      },
      {
        type: "battle_simulation",
        name: "Execute complete battle",
        maxTurns: 5,
        battleConfig: {
          player1: {
            pokemon: [
              { species: "Charizard", level: 50, moves: ["Flamethrower", "Dragon Claw"] }
            ]
          },
          player2: {
            pokemon: [
              { species: "Blastoise", level: 50, moves: ["Water Gun", "Skull Bash"] }
            ]
          }
        },
        player1Actions: [
          { type: "attack", moveIndex: 0 },
          { type: "attack", moveIndex: 1 },
          { type: "attack", moveIndex: 0 }
        ],
        player2Actions: [
          { type: "attack", moveIndex: 0 },
          { type: "attack", moveIndex: 1 },
          { type: "attack", moveIndex: 0 }
        ]
      },
      {
        type: "data_consistency_check",
        name: "Verify data consistency across processes",
        checks: [
          {
            source: "pokemon-species-data",
            target: "battle-engine",
            query: "GetSpeciesStats",
            queryData: { speciesId: 6 }, // Charizard
            compareFields: ["baseStats", "types"]
          }
        ]
      },
      {
        type: "performance_validation",
        name: "Validate response times",
        metrics: [
          {
            target: "pokemon-species-data",
            action: "QuerySpecies",
            data: { speciesId: 9 },
            maxResponseTime: 500
          },
          {
            target: "battle-engine",
            action: "HealthCheck",
            maxResponseTime: 1000
          }
        ]
      }
    ],
    finalValidation: [
      {
        type: "process_health",
        description: "All processes healthy after workflow",
        processes: ["coordinator-process", "pokemon-species-data", "move-data", "battle-engine"]
      },
      {
        type: "data_integrity",
        description: "Data integrity maintained",
        checkData: true
      }
    ],
    performance: {
      maxTotalTime: 45000,
      maxMemoryUsage: 400
    }
  },

  // Error handling and recovery scenario
  errorHandlingValidation: {
    id: "error-handling-validation",
    name: "Error Handling Validation",
    description: "Test error handling and recovery mechanisms",
    timeout: 40000,
    processes: ["coordinator-process", "pokemon-species-data", "battle-engine"],
    steps: [
      {
        type: "send_message",
        name: "Send valid initial message",
        target: "pokemon-species-data",
        action: "QuerySpecies",
        data: { speciesId: 1 }
      },
      {
        type: "error_injection",
        name: "Inject invalid message",
        target: "pokemon-species-data",
        errorType: "invalid_message",
        invalidMessage: {
          Action: "QuerySpecies",
          Data: { speciesId: "invalid" } // Invalid species ID
        }
      },
      {
        type: "error_injection",
        name: "Inject malformed data",
        target: "battle-engine",
        errorType: "malformed_data",
        malformedData: {
          Action: "InitializeBattle",
          Data: { invalidStructure: true }
        }
      },
      {
        type: "validate_state",
        name: "Verify error recovery",
        target: "pokemon-species-data",
        stateValidator: (state) => ({
          valid: state && state.errorCount !== undefined,
          error: "Process should track error occurrences"
        })
      },
      {
        type: "send_message",
        name: "Send valid message after errors",
        target: "pokemon-species-data",
        action: "QuerySpecies",
        data: { speciesId: 25 } // Pikachu
      }
    ],
    finalValidation: [
      {
        type: "error_recovery",
        description: "Processes recovered from errors",
        processes: ["pokemon-species-data", "battle-engine"]
      }
    ],
    performance: {
      maxTotalTime: 35000,
      maxMemoryUsage: 300
    }
  },

  // Performance stress testing scenario
  performanceStressTesting: {
    id: "performance-stress-testing",
    name: "Performance Stress Testing",
    description: "Test system performance under load",
    timeout: 120000,
    processes: ["coordinator-process", "pokemon-species-data", "move-data", "item-data"],
    parallelDeployment: true,
    steps: [
      {
        type: "multi_process_interaction",
        name: "High-frequency data queries",
        interactions: Array.from({ length: 50 }, (_, i) => ({
          from: "coordinator-process",
          to: "pokemon-species-data",
          action: "QuerySpecies",
          data: { speciesId: (i % 151) + 1 } // Cycle through original 151 Pokemon
        }))
      },
      {
        type: "performance_validation",
        name: "Validate response times under load",
        metrics: [
          {
            target: "pokemon-species-data",
            action: "QuerySpecies",
            data: { speciesId: 150 },
            maxResponseTime: 1000 // Should still be under 1s even under load
          },
          {
            target: "move-data",
            action: "QueryMove",
            data: { moveId: 1 },
            maxResponseTime: 800
          }
        ]
      },
      {
        type: "custom_validation",
        name: "Memory usage validation",
        validator: async (context) => {
          const stats = await context.aoliteFramework.getStatistics();
          return {
            valid: stats.processCount >= 4,
            error: stats.processCount < 4 ? "Not all processes running" : null,
            details: stats
          };
        }
      }
    ],
    finalValidation: [
      {
        type: "performance_baseline",
        description: "Performance within acceptable limits",
        maxResponseTime: 1500,
        maxMemoryUsage: 500
      }
    ],
    performance: {
      maxTotalTime: 100000,
      maxMemoryUsage: 600
    }
  },

  // Data synchronization scenario
  dataSynchronizationTest: {
    id: "data-synchronization-test",
    name: "Data Synchronization Test",
    description: "Test data synchronization across multiple processes",
    timeout: 45000,
    processes: ["coordinator-process", "pokemon-species-data", "move-data", "ability-data"],
    steps: [
      {
        type: "multi_process_interaction",
        name: "Synchronize initial data",
        interactions: [
          {
            from: "coordinator-process",
            to: "pokemon-species-data",
            action: "SyncData",
            data: { syncType: "initial" }
          },
          {
            from: "coordinator-process",
            to: "move-data",
            action: "SyncData",
            data: { syncType: "initial" }
          },
          {
            from: "coordinator-process",
            to: "ability-data",
            action: "SyncData",
            data: { syncType: "initial" }
          }
        ]
      },
      {
        type: "data_consistency_check",
        name: "Verify cross-process data consistency",
        checks: [
          {
            source: "pokemon-species-data",
            target: "move-data",
            query: "GetDataVersion",
            compareFields: ["version", "checksum"]
          },
          {
            source: "move-data",
            target: "ability-data",
            query: "GetDataVersion",
            compareFields: ["version", "checksum"]
          }
        ]
      },
      {
        type: "send_message",
        name: "Trigger data update",
        target: "coordinator-process",
        action: "UpdateGameData",
        data: { updateType: "incremental" }
      },
      {
        type: "wait_for_response",
        name: "Wait for sync completion",
        source: "coordinator-process",
        expectedAction: "SyncComplete",
        timeout: 10000
      },
      {
        type: "data_consistency_check",
        name: "Verify data consistency after update",
        checks: [
          {
            source: "pokemon-species-data",
            target: "move-data",
            query: "GetDataVersion",
            compareFields: ["version"]
          }
        ]
      }
    ],
    finalValidation: [
      {
        type: "data_integrity",
        description: "Data integrity maintained across all processes",
        checkFullConsistency: true
      }
    ],
    performance: {
      maxTotalTime: 40000,
      maxMemoryUsage: 400
    }
  },

  // Process failure and recovery scenario
  processFailureRecovery: {
    id: "process-failure-recovery",
    name: "Process Failure Recovery",
    description: "Test system behavior during process failures and recovery",
    timeout: 60000,
    processes: ["coordinator-process", "pokemon-species-data", "battle-engine"],
    steps: [
      {
        type: "send_message",
        name: "Establish baseline communication",
        target: "pokemon-species-data",
        action: "QuerySpecies",
        data: { speciesId: 1 }
      },
      {
        type: "error_injection",
        name: "Simulate process crash",
        target: "pokemon-species-data",
        errorType: "timeout_simulation",
        timeout: 10000 // Simulate 10s timeout
      },
      {
        type: "validate_state",
        name: "Verify coordinator handles failure",
        target: "coordinator-process",
        stateValidator: (state) => ({
          valid: state && (state.failedProcesses || state.processStatus),
          error: "Coordinator should track process failures"
        })
      },
      {
        type: "custom_validation",
        name: "Verify failure detection",
        validator: async (context) => {
          // Check if the coordinator detected the failure
          const response = await context.aoliteFramework.sendMessage(
            context.processes.get("coordinator-process").processId,
            { Action: "GetProcessStatus", Data: {} }
          );
          
          return {
            valid: response && response.data && response.data.failures,
            error: "Coordinator should report process failures"
          };
        }
      },
      {
        type: "send_message",
        name: "Test alternative data path",
        target: "battle-engine",
        action: "HealthCheck",
        data: {}
      }
    ],
    finalValidation: [
      {
        type: "failure_recovery",
        description: "System gracefully handled process failure",
        processes: ["coordinator-process", "battle-engine"]
      }
    ],
    performance: {
      maxTotalTime: 50000,
      maxMemoryUsage: 350
    }
  }
};

// Scenario execution configurations
export const scenarioConfigs = {
  // Quick validation - run essential scenarios
  quick: {
    scenarios: [
      "basic-process-communication",
      "error-handling-validation"
    ],
    timeout: 60000,
    parallelExecution: false
  },

  // Full validation - run all scenarios
  full: {
    scenarios: [
      "basic-process-communication",
      "complete-game-workflow",
      "error-handling-validation",
      "performance-stress-testing",
      "data-synchronization-test",
      "process-failure-recovery"
    ],
    timeout: 300000, // 5 minutes
    parallelExecution: false
  },

  // Performance focused - run performance-related scenarios
  performance: {
    scenarios: [
      "performance-stress-testing",
      "complete-game-workflow"
    ],
    timeout: 180000, // 3 minutes
    parallelExecution: false
  },

  // Reliability focused - run error handling and recovery scenarios
  reliability: {
    scenarios: [
      "error-handling-validation",
      "process-failure-recovery",
      "data-synchronization-test"
    ],
    timeout: 150000, // 2.5 minutes
    parallelExecution: false
  }
};

// Scenario validation rules
export const validationRules = {
  // Response time thresholds
  responseTime: {
    dataProcess: 500, // ms
    logicProcess: 2000, // ms
    coordinatorProcess: 1000 // ms
  },

  // Memory usage limits
  memoryUsage: {
    perProcess: 100, // MB
    total: 500 // MB
  },

  // Error rate thresholds
  errorRates: {
    maxErrorRate: 0.05, // 5% max error rate
    maxConsecutiveErrors: 3
  },

  // Performance baselines
  performanceBaselines: {
    deploymentTime: 5000, // ms
    scenarioExecutionTime: 30000, // ms per scenario
    messageResponseTime: 1000 // ms
  }
};

export default {
  testScenarios,
  scenarioConfigs,
  validationRules
};