/**
 * Deployment Configuration Fixtures
 * Standard deployment configurations for different process types
 */

export const deploymentConfigs = {
  // Coordinator Process Configuration
  coordinator: {
    processType: "coordinator",
    processName: "coordinator-process",
    processPath: "./processes/coordinator-process.lua",
    maxSize: 500000, // 500KB
    requiredHandlers: ["ProcessLogic", "CoordinateAction", "StateUpdate", "HealthCheck", "Info"],
    dependencies: [],
    performance: {
      maxInitTime: 2000, // 2 seconds
      maxResponseTime: 1000, // 1 second
      minMemoryEfficiency: 0.8,
      maxMemoryUsage: 50, // MB
    },
    validation: {
      requiredTags: ["Name", "Authority"],
      requiredFunctions: ["processCoordination", "updateGameState"],
      adpCompliance: "1.0",
    },
  },

  // Data Process Configuration
  dataProcess: {
    processType: "data",
    processName: "pokemon-species-data",
    processPath: "./processes/pokemon-species-data.lua",
    maxSize: 450000, // 450KB (smaller for data processes)
    requiredHandlers: ["QueryData", "QuerySpecies", "HealthCheck", "Info"],
    dependencies: [],
    performance: {
      maxInitTime: 1500, // 1.5 seconds
      maxResponseTime: 500, // 0.5 seconds
      minMemoryEfficiency: 0.9,
      maxMemoryUsage: 30, // MB
    },
    validation: {
      requiredTags: ["Name", "DataType"],
      requiredFunctions: ["querySpeciesData", "validateSpeciesId"],
      adpCompliance: "1.0",
    },
  },

  // Logic Process Configuration
  logicProcess: {
    processType: "logic",
    processName: "battle-engine",
    processPath: "./processes/battle-engine.lua",
    maxSize: 500000, // 500KB (max for logic processes)
    requiredHandlers: ["ProcessLogic", "BattleAction", "InitializeBattle", "ProcessTurn", "HealthCheck", "Info"],
    dependencies: ["pokemon-species-data", "move-data", "ability-data"],
    performance: {
      maxInitTime: 3000, // 3 seconds
      maxResponseTime: 2000, // 2 seconds
      minMemoryEfficiency: 0.7,
      maxMemoryUsage: 80, // MB
    },
    validation: {
      requiredTags: ["Name", "BattleType"],
      requiredFunctions: ["processBattleTurn", "calculateDamage", "applyStatusEffects"],
      adpCompliance: "1.0",
    },
  },

  // Evolution Logic Process
  evolutionProcess: {
    processType: "logic",
    processName: "evolution-engine",
    processPath: "./processes/evolution-engine.lua",
    maxSize: 400000, // 400KB
    requiredHandlers: ["ProcessLogic", "CheckEvolution", "TriggerEvolution", "HealthCheck", "Info"],
    dependencies: ["pokemon-species-data", "evolution-data"],
    performance: {
      maxInitTime: 2000,
      maxResponseTime: 1500,
      minMemoryEfficiency: 0.8,
      maxMemoryUsage: 40, // MB
    },
    validation: {
      requiredTags: ["Name", "EvolutionType"],
      requiredFunctions: ["checkEvolutionConditions", "processEvolution"],
      adpCompliance: "1.0",
    },
  },

  // Status Effects Process
  statusEffectsProcess: {
    processType: "logic",
    processName: "status-effects-engine",
    processPath: "./processes/status-effects-engine.lua",
    maxSize: 350000, // 350KB
    requiredHandlers: ["ProcessLogic", "ApplyStatus", "RemoveStatus", "ProcessStatusEffects", "HealthCheck", "Info"],
    dependencies: ["move-data"],
    performance: {
      maxInitTime: 1800,
      maxResponseTime: 800,
      minMemoryEfficiency: 0.85,
      maxMemoryUsage: 35, // MB
    },
    validation: {
      requiredTags: ["Name", "StatusType"],
      requiredFunctions: ["applyStatusEffect", "removeStatusEffect", "processEndOfTurnEffects"],
      adpCompliance: "1.0",
    },
  },
};

// Test scenario configurations for end-to-end testing
export const testScenarios = {
  basicDeployment: {
    id: "basic-deployment",
    name: "Basic Process Deployment",
    description: "Test basic deployment of individual processes",
    processes: ["coordinator"],
    steps: [
      {
        type: "deploy",
        target: "coordinator",
        timeout: 5000,
      },
      {
        type: "verify_handlers",
        target: "coordinator",
        expectedHandlers: ["ProcessLogic", "HealthCheck", "Info"],
      },
      {
        type: "send_message",
        target: "coordinator",
        action: "HealthCheck",
        expectedResponse: "Healthy",
      },
    ],
    performance: {
      maxTotalTime: 10000,
      maxMemoryUsage: 100,
    },
  },

  multiProcessDeployment: {
    id: "multi-process-deployment",
    name: "Multi-Process Deployment",
    description: "Test deployment of multiple interdependent processes",
    processes: ["coordinator", "dataProcess", "logicProcess"],
    steps: [
      {
        type: "deploy_parallel",
        targets: ["coordinator", "dataProcess"],
        timeout: 8000,
      },
      {
        type: "deploy",
        target: "logicProcess",
        dependencies: ["coordinator", "dataProcess"],
        timeout: 5000,
      },
      {
        type: "verify_communication",
        from: "logicProcess",
        to: "dataProcess",
        action: "QueryData",
      },
      {
        type: "end_to_end_test",
        scenario: "simple_battle",
        timeout: 15000,
      },
    ],
    performance: {
      maxTotalTime: 30000,
      maxMemoryUsage: 200,
    },
  },

  fullSystemDeployment: {
    id: "full-system-deployment",
    name: "Full System Deployment",
    description: "Test deployment of complete 26-process architecture",
    processes: ["coordinator", "dataProcess", "logicProcess", "evolutionProcess", "statusEffectsProcess"],
    steps: [
      {
        type: "deploy_batch",
        batch: "data_processes",
        targets: ["dataProcess"],
        timeout: 10000,
      },
      {
        type: "deploy_batch",
        batch: "logic_processes",
        targets: ["logicProcess", "evolutionProcess", "statusEffectsProcess"],
        dependencies: ["data_processes"],
        timeout: 15000,
      },
      {
        type: "deploy",
        target: "coordinator",
        dependencies: ["data_processes", "logic_processes"],
        timeout: 5000,
      },
      {
        type: "system_health_check",
        allProcesses: true,
      },
      {
        type: "end_to_end_test",
        scenario: "complete_game_flow",
        timeout: 30000,
      },
    ],
    performance: {
      maxTotalTime: 60000,
      maxMemoryUsage: 500,
    },
  },
};

// Performance baseline configurations
export const performanceBaselines = {
  deploymentTime: {
    coordinator: 2000, // ms
    dataProcess: 1500, // ms
    logicProcess: 3000, // ms
    evolutionProcess: 2000, // ms
    statusEffectsProcess: 1800, // ms
  },

  responseTime: {
    coordinator: 1000, // ms
    dataProcess: 500, // ms
    logicProcess: 2000, // ms
    evolutionProcess: 1500, // ms
    statusEffectsProcess: 800, // ms
  },

  memoryUsage: {
    coordinator: 50, // MB
    dataProcess: 30, // MB
    logicProcess: 80, // MB
    evolutionProcess: 40, // MB
    statusEffectsProcess: 35, // MB
  },

  processSize: {
    maximum: 500000, // 500KB
    warning: 450000, // 450KB (90% of max)
    optimal: 400000, // 400KB (80% of max)
  },
};

// Recovery test configurations
export const recoveryScenarios = {
  processRestart: {
    id: "process-restart",
    name: "Process Restart Recovery",
    description: "Test process recovery after restart",
    steps: [
      {
        type: "deploy",
        target: "coordinator",
      },
      {
        type: "send_message",
        target: "coordinator",
        action: "ProcessLogic",
        data: { test: "initial_state" },
      },
      {
        type: "restart_process",
        target: "coordinator",
      },
      {
        type: "verify_state_persistence",
        target: "coordinator",
        expectedState: { test: "initial_state" },
      },
      {
        type: "send_message",
        target: "coordinator",
        action: "HealthCheck",
      },
    ],
    performance: {
      maxRestartTime: 3000,
      maxStateRecoveryTime: 1000,
    },
  },

  processFailure: {
    id: "process-failure",
    name: "Process Failure Recovery",
    description: "Test system behavior when process fails",
    steps: [
      {
        type: "deploy_multi",
        targets: ["coordinator", "dataProcess", "logicProcess"],
      },
      {
        type: "inject_failure",
        target: "dataProcess",
        failureType: "crash",
      },
      {
        type: "verify_error_handling",
        requester: "logicProcess",
        target: "dataProcess",
      },
      {
        type: "restart_process",
        target: "dataProcess",
      },
      {
        type: "verify_recovery",
        target: "dataProcess",
        requester: "logicProcess",
      },
    ],
    performance: {
      maxFailureDetectionTime: 2000,
      maxRecoveryTime: 5000,
    },
  },

  networkPartition: {
    id: "network-partition",
    name: "Network Partition Recovery",
    description: "Test recovery from simulated network issues",
    steps: [
      {
        type: "deploy_multi",
        targets: ["coordinator", "dataProcess", "logicProcess"],
      },
      {
        type: "simulate_network_partition",
        affected: ["dataProcess"],
        duration: 5000,
      },
      {
        type: "verify_timeout_handling",
        requester: "logicProcess",
        target: "dataProcess",
      },
      {
        type: "restore_network",
        affected: ["dataProcess"],
      },
      {
        type: "verify_reconnection",
        requester: "logicProcess",
        target: "dataProcess",
      },
    ],
    performance: {
      maxTimeoutDetection: 3000,
      maxReconnectionTime: 2000,
    },
  },
};

export default {
  deploymentConfigs,
  testScenarios,
  performanceBaselines,
  recoveryScenarios,
};
