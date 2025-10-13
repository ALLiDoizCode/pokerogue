/**
 * Process Topology Validator for 26-Process AO Architecture
 *
 * Validates the fixed process topology, inter-process communication patterns,
 * and ensures all required processes are available and properly configured.
 */

const _crypto = require("crypto");

class ProcessTopologyValidator {
  constructor() {
    this.requiredProcesses = this.getRequiredProcessTopology();
    this.communicationPatterns = this.getCommunicationPatterns();
    this.processCapabilities = this.getProcessCapabilities();
  }

  /**
   * Define the complete 26-process topology
   */
  getRequiredProcessTopology() {
    return {
      coordinator: {
        processes: ["coordinator-process"],
        critical: true,
        description: "Central orchestration and workflow coordination",
      },
      data: {
        processes: [
          "pokemon-species-db",
          "moves-database",
          "items-database",
          "abilities-database",
          "type-chart-db",
          "nature-modifiers-db",
          "evolution-chains-db",
        ],
        critical: true,
        description: "Core game data storage and retrieval",
      },
      logic: {
        processes: [
          "battle-engine",
          "damage-calculator",
          "status-effects-engine",
          "evolution-engine",
          "capture-engine",
          "experience-calculator",
        ],
        critical: true,
        description: "Core game logic and calculations",
      },
      utility: {
        processes: [
          "state-validator",
          "query-processor",
          "rng-coordinator",
          "inventory-manager",
          "progression-tracker",
          "save-manager",
        ],
        critical: true,
        description: "Utility services and state management",
      },
      specialized: {
        processes: [
          "breeding-system",
          "contest-system",
          "trade-system",
          "weather-system",
          "terrain-system",
          "field-effects-system",
        ],
        critical: false,
        description: "Specialized game features",
      },
    };
  }

  /**
   * Define valid communication patterns between process types
   */
  getCommunicationPatterns() {
    return {
      coordinator: {
        canSendTo: ["data", "logic", "utility", "specialized"],
        canReceiveFrom: ["client", "data", "logic", "utility", "specialized"],
        mustCoordinate: true,
      },
      data: {
        canSendTo: ["coordinator"],
        canReceiveFrom: ["coordinator"],
        mustCoordinate: false,
      },
      logic: {
        canSendTo: ["coordinator", "data"],
        canReceiveFrom: ["coordinator"],
        mustCoordinate: false,
      },
      utility: {
        canSendTo: ["coordinator", "data"],
        canReceiveFrom: ["coordinator"],
        mustCoordinate: false,
      },
      specialized: {
        canSendTo: ["coordinator", "data", "logic"],
        canReceiveFrom: ["coordinator"],
        mustCoordinate: false,
      },
    };
  }

  /**
   * Define required capabilities for each process type
   */
  getProcessCapabilities() {
    return {
      "coordinator-process": {
        requiredHandlers: ["CoordinateWorkflow", "ProcessBattleTurn", "HandleEvolution", "ManageCapture", "Info"],
        requiredCapabilities: ["workflow_coordination", "async_orchestration", "state_management"],
        maxResponseTime: 5000,
      },
      "pokemon-species-db": {
        requiredHandlers: ["QuerySpecies", "QueryEvolutionChain", "Info"],
        requiredCapabilities: ["species_lookup", "evolution_data", "stat_retrieval"],
        maxResponseTime: 2000,
      },
      "moves-database": {
        requiredHandlers: ["QueryMove", "QueryMoves", "QueryMovesByType", "Info"],
        requiredCapabilities: ["move_lookup", "move_effects", "type_filtering"],
        maxResponseTime: 2000,
      },
      "items-database": {
        requiredHandlers: ["QueryItem", "QueryItems", "QueryItemsByCategory", "Info"],
        requiredCapabilities: ["item_lookup", "item_effects", "category_filtering"],
        maxResponseTime: 2000,
      },
      "abilities-database": {
        requiredHandlers: ["QueryAbility", "QueryAbilities", "Info"],
        requiredCapabilities: ["ability_lookup", "ability_effects"],
        maxResponseTime: 2000,
      },
      "battle-engine": {
        requiredHandlers: ["ProcessBattle", "CalculateStats", "ApplyEffects", "Info"],
        requiredCapabilities: ["battle_resolution", "stat_calculation", "effect_application"],
        maxResponseTime: 3000,
      },
      "damage-calculator": {
        requiredHandlers: ["CalculateDamage", "GetTypeEffectiveness", "Info"],
        requiredCapabilities: ["damage_calculation", "type_effectiveness", "critical_hits"],
        maxResponseTime: 1000,
      },
      "status-effects-engine": {
        requiredHandlers: ["ApplyStatusEffect", "ProcessStatusEffects", "RemoveStatusEffect", "Info"],
        requiredCapabilities: ["status_application", "status_processing", "status_removal"],
        maxResponseTime: 2000,
      },
      "state-validator": {
        requiredHandlers: ["ValidateGameState", "ValidateParty", "ValidateBattle", "Info"],
        requiredCapabilities: ["state_validation", "integrity_checking", "constraint_validation"],
        maxResponseTime: 1000,
      },
    };
  }

  /**
   * Validate the complete process topology
   */
  async validateTopology(processes) {
    const validation = {
      valid: true,
      errors: [],
      warnings: [],
      summary: {
        totalProcesses: processes.length,
        criticalProcesses: 0,
        missingProcesses: [],
        extraProcesses: [],
        communicationPatterns: [],
        capabilityChecks: [],
      },
    };

    // Get all required process names
    const allRequiredProcesses = Object.values(this.requiredProcesses).flatMap(category => category.processes);

    const providedProcessIds = processes.map(p => p.id);

    // Check for missing critical processes
    for (const [categoryName, category] of Object.entries(this.requiredProcesses)) {
      for (const requiredProcess of category.processes) {
        if (!providedProcessIds.includes(requiredProcess)) {
          validation.summary.missingProcesses.push(requiredProcess);

          if (category.critical) {
            validation.valid = false;
            validation.errors.push(`Missing critical process: ${requiredProcess} (${categoryName})`);
            validation.summary.criticalProcesses++;
          } else {
            validation.warnings.push(`Missing optional process: ${requiredProcess} (${categoryName})`);
          }
        }
      }
    }

    // Check for unexpected processes
    for (const processId of providedProcessIds) {
      if (!allRequiredProcesses.includes(processId)) {
        validation.summary.extraProcesses.push(processId);
        validation.warnings.push(`Unexpected process found: ${processId}`);
      }
    }

    // Validate individual processes
    for (const process of processes) {
      const processValidation = await this.validateProcess(process);
      validation.summary.capabilityChecks.push({
        processId: process.id,
        valid: processValidation.valid,
        errors: processValidation.errors,
        warnings: processValidation.warnings,
      });

      if (!processValidation.valid) {
        validation.valid = false;
        validation.errors.push(`Process ${process.id} validation failed: ${processValidation.errors.join(", ")}`);
      }

      validation.warnings.push(...processValidation.warnings.map(w => `${process.id}: ${w}`));
    }

    // Validate communication patterns
    const communicationValidation = this.validateCommunicationPatterns(processes);
    validation.summary.communicationPatterns = communicationValidation.patterns;

    if (!communicationValidation.valid) {
      validation.valid = false;
      validation.errors.push(...communicationValidation.errors);
    }
    validation.warnings.push(...communicationValidation.warnings);

    // Check coordinator presence and configuration
    const coordinatorValidation = this.validateCoordinatorConfiguration(processes);
    if (!coordinatorValidation.valid) {
      validation.valid = false;
      validation.errors.push(...coordinatorValidation.errors);
    }

    return validation;
  }

  /**
   * Validate individual process configuration
   */
  async validateProcess(process) {
    const validation = {
      valid: true,
      errors: [],
      warnings: [],
    };

    // Check basic process structure
    if (!process.id) {
      validation.valid = false;
      validation.errors.push("Process missing ID");
      return validation;
    }

    if (!process.handlers || !Array.isArray(process.handlers)) {
      validation.valid = false;
      validation.errors.push("Process missing handlers array");
    }

    if (!process.capabilities || !Array.isArray(process.capabilities)) {
      validation.warnings.push("Process missing capabilities array");
    }

    // Validate against process-specific requirements
    const requirements = this.processCapabilities[process.id];
    if (requirements) {
      // Check required handlers
      for (const requiredHandler of requirements.requiredHandlers) {
        if (!process.handlers.includes(requiredHandler)) {
          validation.valid = false;
          validation.errors.push(`Missing required handler: ${requiredHandler}`);
        }
      }

      // Check required capabilities
      for (const requiredCapability of requirements.requiredCapabilities) {
        if (!process.capabilities.includes(requiredCapability)) {
          validation.warnings.push(`Missing recommended capability: ${requiredCapability}`);
        }
      }

      // Check response time configuration
      if (process.responseTime && process.responseTime > requirements.maxResponseTime) {
        validation.warnings.push(
          `Response time ${process.responseTime}ms exceeds recommended ${requirements.maxResponseTime}ms`,
        );
      }
    } else {
      validation.warnings.push(`No validation requirements defined for process: ${process.id}`);
    }

    // Validate process status
    if (process.status && !["ready", "initializing", "failed"].includes(process.status)) {
      validation.warnings.push(`Unknown process status: ${process.status}`);
    }

    return validation;
  }

  /**
   * Validate communication patterns across the topology
   */
  validateCommunicationPatterns(processes) {
    const validation = {
      valid: true,
      errors: [],
      warnings: [],
      patterns: [],
    };

    const processMap = new Map();
    processes.forEach(p => processMap.set(p.id, p));

    // Group processes by type
    const processByType = {
      coordinator: [],
      data: [],
      logic: [],
      utility: [],
      specialized: [],
    };

    for (const process of processes) {
      const type = this.classifyProcessType(process.id);
      if (processByType[type]) {
        processByType[type].push(process);
      } else {
        validation.warnings.push(`Unable to classify process: ${process.id}`);
      }
    }

    // Validate coordinator-centric communication pattern
    if (processByType.coordinator.length !== 1) {
      validation.valid = false;
      validation.errors.push(`Must have exactly 1 coordinator process, found ${processByType.coordinator.length}`);
    }

    // Validate that data processes don't communicate directly with logic processes
    const communicationRules = this.communicationPatterns;

    // Check each process type's communication constraints
    for (const [processType, typeProcesses] of Object.entries(processByType)) {
      if (typeProcesses.length === 0) {
        continue;
      }

      const rules = communicationRules[processType];
      if (!rules) {
        continue;
      }

      validation.patterns.push({
        processType,
        processCount: typeProcesses.length,
        canSendTo: rules.canSendTo,
        canReceiveFrom: rules.canReceiveFrom,
        mustCoordinate: rules.mustCoordinate,
      });

      // Validate communication restrictions
      if (rules.mustCoordinate && processType !== "coordinator") {
        // These processes should only communicate through coordinator
        for (const process of typeProcesses) {
          if (process.directCommunication) {
            validation.warnings.push(`${process.id} should not have direct communication, must use coordinator`);
          }
        }
      }
    }

    return validation;
  }

  /**
   * Validate coordinator process configuration
   */
  validateCoordinatorConfiguration(processes) {
    const validation = {
      valid: true,
      errors: [],
      warnings: [],
    };

    const coordinators = processes.filter(p => p.id.includes("coordinator"));

    if (coordinators.length === 0) {
      validation.valid = false;
      validation.errors.push("No coordinator process found");
      return validation;
    }

    if (coordinators.length > 1) {
      validation.valid = false;
      validation.errors.push(`Multiple coordinator processes found: ${coordinators.map(c => c.id).join(", ")}`);
    }

    const coordinator = coordinators[0];
    const requirements = this.processCapabilities["coordinator-process"];

    if (requirements) {
      // Validate coordinator has all required orchestration capabilities
      const requiredOrchestrationCapabilities = ["workflow_coordination", "async_orchestration", "state_management"];

      for (const capability of requiredOrchestrationCapabilities) {
        if (!coordinator.capabilities || !coordinator.capabilities.includes(capability)) {
          validation.valid = false;
          validation.errors.push(`Coordinator missing critical capability: ${capability}`);
        }
      }

      // Validate coordinator handlers
      const criticalHandlers = ["CoordinateWorkflow", "ProcessBattleTurn", "Info"];
      for (const handler of criticalHandlers) {
        if (!coordinator.handlers || !coordinator.handlers.includes(handler)) {
          validation.valid = false;
          validation.errors.push(`Coordinator missing critical handler: ${handler}`);
        }
      }
    }

    return validation;
  }

  /**
   * Classify process type based on naming convention
   */
  classifyProcessType(processId) {
    if (processId.includes("coordinator")) {
      return "coordinator";
    }
    if (processId.includes("database") || processId.includes("-db")) {
      return "data";
    }
    if (processId.includes("engine") || processId.includes("calculator")) {
      return "logic";
    }
    if (
      processId.includes("validator") ||
      processId.includes("processor") ||
      processId.includes("manager") ||
      processId.includes("tracker")
    ) {
      return "utility";
    }
    return "specialized";
  }

  /**
   * Generate topology validation report
   */
  generateTopologyReport(processes) {
    const validation = this.validateTopology(processes);

    return {
      timestamp: new Date().toISOString(),
      overall: {
        valid: validation.valid,
        totalProcesses: validation.summary.totalProcesses,
        criticalProcesses: validation.summary.criticalProcesses,
      },
      categories: Object.entries(this.requiredProcesses).map(([name, category]) => ({
        name,
        critical: category.critical,
        requiredCount: category.processes.length,
        actualCount: category.processes.filter(p => processes.some(proc => proc.id === p)).length,
        missingProcesses: category.processes.filter(p => !processes.some(proc => proc.id === p)),
      })),
      communicationValidation: validation.summary.communicationPatterns,
      issues: {
        errors: validation.errors,
        warnings: validation.warnings,
      },
      recommendations: this.generateRecommendations(validation),
    };
  }

  /**
   * Generate recommendations based on validation results
   */
  generateRecommendations(validation) {
    const recommendations = [];

    if (validation.summary.missingProcesses.length > 0) {
      recommendations.push({
        type: "missing_processes",
        priority: "high",
        message: `Deploy missing processes: ${validation.summary.missingProcesses.join(", ")}`,
        action: "deploy_processes",
      });
    }

    if (validation.summary.extraProcesses.length > 0) {
      recommendations.push({
        type: "extra_processes",
        priority: "medium",
        message: `Review unexpected processes: ${validation.summary.extraProcesses.join(", ")}`,
        action: "review_topology",
      });
    }

    const failedCapabilityChecks = validation.summary.capabilityChecks.filter(c => !c.valid);
    if (failedCapabilityChecks.length > 0) {
      recommendations.push({
        type: "capability_failures",
        priority: "high",
        message: `Fix process capability issues in: ${failedCapabilityChecks.map(c => c.processId).join(", ")}`,
        action: "update_processes",
      });
    }

    return recommendations;
  }

  /**
   * Validate process discovery and addressing
   */
  async validateProcessDiscovery(processes) {
    const validation = {
      valid: true,
      errors: [],
      warnings: [],
      discoveryResults: [],
    };

    for (const process of processes) {
      const discoveryResult = {
        processId: process.id,
        addressable: false,
        responseTime: null,
        capabilities: [],
        handlers: [],
      };

      try {
        // Simulate process discovery (Info query)
        const startTime = Date.now();

        // In real implementation, this would send an actual Info message
        await new Promise(resolve => setTimeout(resolve, 50)); // Simulate network delay

        discoveryResult.addressable = true;
        discoveryResult.responseTime = Date.now() - startTime;
        discoveryResult.capabilities = process.capabilities || [];
        discoveryResult.handlers = process.handlers || [];
      } catch (error) {
        validation.valid = false;
        validation.errors.push(`Process discovery failed for ${process.id}: ${error.message}`);
      }

      validation.discoveryResults.push(discoveryResult);
    }

    return validation;
  }
}

module.exports = ProcessTopologyValidator;
