/**
 * Message Flow Orchestrator for Multi-Process Integration Testing
 *
 * Coordinates message sequences between AO Lua processes and validates
 * communication patterns, timing, and data integrity across the 26-process
 * stateless architecture.
 */

const crypto = require("crypto");
const EventEmitter = require("events");

class MessageFlowOrchestrator extends EventEmitter {
  constructor(options = {}) {
    super();
    this.processRegistry = new Map();
    this.messageTraces = new Map();
    this.activeFlows = new Map();
    this.timeouts = options.timeouts || {
      message: 5000, // 5 second AO timeout
      flow: 30000, // 30 second total flow timeout
    };
    this.validator = options.validator;
  }

  /**
   * Register a process for testing with its capabilities and handlers
   */
  registerProcess(processId, config) {
    this.processRegistry.set(processId, {
      id: processId,
      handlers: config.handlers || [],
      capabilities: config.capabilities || [],
      messageSchema: config.messageSchema || {},
      status: "available",
      lastSeen: Date.now(),
    });
  }

  /**
   * Start a multi-process message flow test scenario
   */
  async startFlow(flowDefinition) {
    const flowId = crypto.randomUUID();
    const flow = {
      id: flowId,
      definition: flowDefinition,
      startTime: Date.now(),
      steps: [],
      currentStep: 0,
      status: "running",
      errors: [],
      warnings: [],
    };

    this.activeFlows.set(flowId, flow);
    this.emit("flow:started", { flowId, definition: flowDefinition });

    try {
      await this._executeFlow(flow);
      flow.status = "completed";
      flow.endTime = Date.now();
      flow.duration = flow.endTime - flow.startTime;
    } catch (error) {
      flow.status = "failed";
      flow.endTime = Date.now();
      flow.duration = flow.endTime - flow.startTime;
      flow.errors.push({
        step: flow.currentStep,
        error: error.message,
        timestamp: Date.now(),
      });
      throw error;
    } finally {
      this.emit("flow:completed", { flowId, flow });
    }

    return flow;
  }

  /**
   * Execute a message flow with step-by-step validation
   */
  async _executeFlow(flow) {
    const { definition } = flow;

    for (let i = 0; i < definition.messageFlow.length; i++) {
      flow.currentStep = i;
      const step = definition.messageFlow[i];

      this.emit("step:started", { flowId: flow.id, step: i, stepDef: step });

      const stepResult = await this._executeStep(flow, step);
      flow.steps.push(stepResult);

      // Validate step results
      if (this.validator) {
        const validation = await this.validator.validateStep(stepResult, step);
        if (!validation.valid) {
          throw new Error(`Step validation failed: ${validation.errors.join(", ")}`);
        }
      }

      this.emit("step:completed", { flowId: flow.id, step: i, result: stepResult });
    }
  }

  /**
   * Execute a single message step in the flow
   */
  async _executeStep(_flow, stepDef) {
    const stepId = crypto.randomUUID();
    const step = {
      id: stepId,
      definition: stepDef,
      startTime: Date.now(),
      messages: [],
      responses: [],
      validations: [],
    };

    // Validate source and target processes are available
    const sourceProcess = this.processRegistry.get(stepDef.source);
    const targetProcess = this.processRegistry.get(stepDef.target);

    if (!sourceProcess) {
      throw new Error(`Source process not found: ${stepDef.source}`);
    }
    if (!targetProcess) {
      throw new Error(`Target process not found: ${stepDef.target}`);
    }

    // Construct message according to AO protocol
    const message = this._buildAOMessage(stepDef, stepId);
    step.messages.push(message);

    // Send message and wait for response
    const response = await this._sendMessage(message, stepDef.target);
    step.responses.push(response);
    step.endTime = Date.now();
    step.duration = step.endTime - step.startTime;

    // Validate response against expected outcome
    if (stepDef.expectedResponse) {
      const validation = this._validateResponse(response, stepDef.expectedResponse);
      step.validations.push(validation);

      if (!validation.valid) {
        throw new Error(`Response validation failed: ${validation.errors.join(", ")}`);
      }
    }

    return step;
  }

  /**
   * Build AO message according to protocol specification
   */
  _buildAOMessage(stepDef, stepId) {
    return {
      Id: stepId,
      From: stepDef.source,
      Target: stepDef.target,
      Action: stepDef.action,
      Data: JSON.stringify(stepDef.data || {}),
      GameState: JSON.stringify(stepDef.gameState || {}),
      Timestamp: Date.now().toString(),
      Tags: stepDef.tags || [],
    };
  }

  /**
   * Send message to target process and await response
   */
  async _sendMessage(message, targetProcessId) {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error(`Message timeout after ${this.timeouts.message}ms`));
      }, this.timeouts.message);

      // Simulate AO message sending - in real implementation this would
      // use the actual AO runtime or aolite/aos-local testing framework
      this._simulateAOSend(message, targetProcessId)
        .then(response => {
          clearTimeout(timeout);
          resolve(response);
        })
        .catch(error => {
          clearTimeout(timeout);
          reject(error);
        });
    });
  }

  /**
   * Simulate AO message sending (placeholder for actual AO integration)
   */
  async _simulateAOSend(message, targetProcessId) {
    // This would be replaced with actual AO runtime integration
    // For now, simulate a basic response structure
    await new Promise(resolve => setTimeout(resolve, 100)); // Simulate processing time

    return {
      Id: crypto.randomUUID(),
      From: targetProcessId,
      Target: message.From,
      Action: message.Action === "Error" ? "Error" : "Success",
      Data: JSON.stringify({ processed: true, originalAction: message.Action }),
      GameState: message.GameState, // Echo back for now
      ProcessId: targetProcessId,
      Timestamp: Date.now().toString(),
      Success: message.Action !== "Error",
    };
  }

  /**
   * Validate response against expected outcome
   */
  _validateResponse(response, expected) {
    const validation = {
      valid: true,
      errors: [],
      warnings: [],
    };

    // Check required fields
    const requiredFields = ["Action", "Data", "Success"];
    for (const field of requiredFields) {
      if (!(field in response)) {
        validation.valid = false;
        validation.errors.push(`Missing required field: ${field}`);
      }
    }

    // Check action matches expected
    if (expected.Action && response.Action !== expected.Action) {
      validation.valid = false;
      validation.errors.push(`Action mismatch: expected ${expected.Action}, got ${response.Action}`);
    }

    // Check success flag
    if (expected.Success !== undefined && response.Success !== expected.Success) {
      validation.valid = false;
      validation.errors.push(`Success flag mismatch: expected ${expected.Success}, got ${response.Success}`);
    }

    // Validate data structure if specified
    if (expected.Data) {
      try {
        const responseData = JSON.parse(response.Data);
        const expectedData = expected.Data;

        for (const [key, value] of Object.entries(expectedData)) {
          if (responseData[key] !== value) {
            validation.warnings.push(`Data field ${key}: expected ${value}, got ${responseData[key]}`);
          }
        }
      } catch (error) {
        validation.valid = false;
        validation.errors.push(`Invalid JSON in response data: ${error.message}`);
      }
    }

    return validation;
  }

  /**
   * Get flow execution results
   */
  getFlowResults(flowId) {
    return this.activeFlows.get(flowId);
  }

  /**
   * Get all active flows
   */
  getActiveFlows() {
    return Array.from(this.activeFlows.values());
  }

  /**
   * Get process registry
   */
  getProcessRegistry() {
    return Array.from(this.processRegistry.values());
  }

  /**
   * Generate execution report
   */
  generateReport(flowId) {
    const flow = this.activeFlows.get(flowId);
    if (!flow) {
      throw new Error(`Flow not found: ${flowId}`);
    }

    return {
      flowId,
      scenario: flow.definition.testScenario,
      status: flow.status,
      duration: flow.duration,
      totalSteps: flow.steps.length,
      successfulSteps: flow.steps.filter(s => s.validations.every(v => v.valid)).length,
      failedSteps: flow.steps.filter(s => s.validations.some(v => !v.valid)).length,
      averageStepDuration: flow.steps.reduce((sum, s) => sum + s.duration, 0) / flow.steps.length,
      errors: flow.errors,
      warnings: flow.warnings,
      steps: flow.steps.map(step => ({
        id: step.id,
        action: step.definition.action,
        source: step.definition.source,
        target: step.definition.target,
        duration: step.duration,
        success: step.validations.every(v => v.valid),
        validationErrors: step.validations.flatMap(v => v.errors),
        validationWarnings: step.validations.flatMap(v => v.warnings),
      })),
    };
  }
}

module.exports = MessageFlowOrchestrator;
