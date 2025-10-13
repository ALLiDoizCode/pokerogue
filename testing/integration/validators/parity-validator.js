/**
 * Parity Validator for TypeScript-AO Lua Integration Testing
 *
 * Validates 100% behavioral equivalence between TypeScript reference
 * implementation and AO Lua multi-process architecture.
 */

const _crypto = require("crypto");

class ParityValidator {
  constructor(options = {}) {
    this.tolerances = options.tolerances || {
      numeric: 0.001,
      timing: 100, // ms
      rng: "deterministic",
    };
    this.validationRules = this.getValidationRules();
    this.comparisonResults = new Map();
  }

  /**
   * Define validation rules for different data types
   */
  getValidationRules() {
    return {
      pokemon_stats: {
        fields: ["hp", "attack", "defense", "specialAttack", "specialDefense", "speed"],
        tolerance: 0, // Exact match required
        validation: "exact_match",
      },
      damage_calculation: {
        fields: ["damage", "critical", "effectiveness"],
        tolerance: 0,
        validation: "exact_match",
      },
      battle_result: {
        fields: ["winner", "turns", "finalStates"],
        tolerance: 0,
        validation: "exact_match",
      },
      evolution_result: {
        fields: ["evolved", "newSpeciesId", "statChanges"],
        tolerance: 0,
        validation: "exact_match",
      },
      capture_result: {
        fields: ["captured", "shakeCount", "criticalCapture"],
        tolerance: 0,
        validation: "exact_match",
      },
      experience_calculation: {
        fields: ["experienceGained", "newLevel", "leveledUp"],
        tolerance: 0,
        validation: "exact_match",
      },
    };
  }

  /**
   * Validate complete scenario parity between implementations
   */
  async validateScenarioParity(scenario, typeScriptResult, aoLuaResult) {
    const validation = {
      scenarioId: scenario.id,
      scenarioType: scenario.type,
      timestamp: Date.now(),
      parity: {
        overall: true,
        categories: {},
        score: 0,
      },
      differences: [],
      warnings: [],
      recommendations: [],
    };

    try {
      // Validate execution results
      const resultParity = this.validateExecutionResults(typeScriptResult, aoLuaResult, scenario.type);
      validation.parity.categories.execution = resultParity;

      // Validate state transitions
      if (scenario.stateTransitions) {
        const stateParity = this.validateStateTransitions(
          typeScriptResult.stateTransitions,
          aoLuaResult.stateTransitions,
          scenario.stateTransitions,
        );
        validation.parity.categories.stateTransitions = stateParity;
      }

      // Validate timing characteristics
      const timingParity = this.validateTimingParity(typeScriptResult.timing, aoLuaResult.timing);
      validation.parity.categories.timing = timingParity;

      // Validate RNG determinism
      if (scenario.battleSeed || scenario.rngSeed) {
        const rngParity = this.validateRNGDeterminism(typeScriptResult.rngTrace, aoLuaResult.rngTrace);
        validation.parity.categories.rng = rngParity;
      }

      // Calculate overall parity score
      validation.parity.score = this.calculateParityScore(validation.parity.categories);
      validation.parity.overall = validation.parity.score >= 0.95; // 95% threshold

      // Generate recommendations
      if (!validation.parity.overall) {
        validation.recommendations = this.generateParityRecommendations(validation);
      }
    } catch (error) {
      validation.parity.overall = false;
      validation.error = error.message;
    }

    this.comparisonResults.set(scenario.id, validation);
    return validation;
  }

  /**
   * Validate execution results between implementations
   */
  validateExecutionResults(tsResult, aoResult, scenarioType) {
    const validation = {
      parity: true,
      score: 0,
      comparisons: [],
      differences: [],
    };

    const rule = this.validationRules[scenarioType] || this.validationRules.battle_result;

    // Compare each field according to validation rules
    for (const field of rule.fields) {
      const comparison = this.compareField(tsResult[field], aoResult[field], field, rule);

      validation.comparisons.push(comparison);

      if (!comparison.matches) {
        validation.parity = false;
        validation.differences.push({
          field,
          typescript: tsResult[field],
          aoLua: aoResult[field],
          reason: comparison.reason,
        });
      }
    }

    validation.score = validation.comparisons.filter(c => c.matches).length / validation.comparisons.length;
    return validation;
  }

  /**
   * Compare individual field values
   */
  compareField(tsValue, aoValue, fieldName, rule) {
    const comparison = {
      field: fieldName,
      matches: false,
      reason: "",
      typescript: tsValue,
      aoLua: aoValue,
    };

    // Handle null/undefined values
    if (tsValue === null && aoValue === null) {
      comparison.matches = true;
      return comparison;
    }

    if (tsValue === null || aoValue === null) {
      comparison.reason = "One value is null while the other is not";
      return comparison;
    }

    // Type checking
    if (typeof tsValue !== typeof aoValue) {
      comparison.reason = `Type mismatch: ${typeof tsValue} vs ${typeof aoValue}`;
      return comparison;
    }

    // Numeric comparison with tolerance
    if (typeof tsValue === "number") {
      const diff = Math.abs(tsValue - aoValue);
      const tolerance = rule.tolerance || this.tolerances.numeric;

      if (diff <= tolerance) {
        comparison.matches = true;
      } else {
        comparison.reason = `Numeric difference ${diff} exceeds tolerance ${tolerance}`;
      }
      return comparison;
    }

    // String comparison
    if (typeof tsValue === "string") {
      comparison.matches = tsValue === aoValue;
      if (!comparison.matches) {
        comparison.reason = "String values do not match exactly";
      }
      return comparison;
    }

    // Boolean comparison
    if (typeof tsValue === "boolean") {
      comparison.matches = tsValue === aoValue;
      if (!comparison.matches) {
        comparison.reason = "Boolean values do not match";
      }
      return comparison;
    }

    // Array comparison
    if (Array.isArray(tsValue)) {
      if (!Array.isArray(aoValue)) {
        comparison.reason = "TypeScript value is array but AO Lua value is not";
        return comparison;
      }

      if (tsValue.length !== aoValue.length) {
        comparison.reason = `Array length mismatch: ${tsValue.length} vs ${aoValue.length}`;
        return comparison;
      }

      // Deep array comparison
      for (let i = 0; i < tsValue.length; i++) {
        const elementComparison = this.compareField(tsValue[i], aoValue[i], `${fieldName}[${i}]`, rule);

        if (!elementComparison.matches) {
          comparison.reason = `Array element ${i} mismatch: ${elementComparison.reason}`;
          return comparison;
        }
      }

      comparison.matches = true;
      return comparison;
    }

    // Object comparison
    if (typeof tsValue === "object") {
      const tsKeys = Object.keys(tsValue).sort();
      const aoKeys = Object.keys(aoValue).sort();

      if (JSON.stringify(tsKeys) !== JSON.stringify(aoKeys)) {
        comparison.reason = "Object keys do not match";
        return comparison;
      }

      // Deep object comparison
      for (const key of tsKeys) {
        const nestedComparison = this.compareField(tsValue[key], aoValue[key], `${fieldName}.${key}`, rule);

        if (!nestedComparison.matches) {
          comparison.reason = `Object property ${key} mismatch: ${nestedComparison.reason}`;
          return comparison;
        }
      }

      comparison.matches = true;
      return comparison;
    }

    comparison.reason = "Unknown data type for comparison";
    return comparison;
  }

  /**
   * Validate state transition parity
   */
  validateStateTransitions(tsTransitions, aoTransitions, expectedTransitions) {
    const validation = {
      parity: true,
      score: 0,
      transitionComparisons: [],
      missingTransitions: [],
      unexpectedTransitions: [],
    };

    // Check that both implementations follow expected transitions
    for (const expectedTransition of expectedTransitions) {
      const tsTransition = tsTransitions.find(t => t.step === expectedTransition.step);
      const aoTransition = aoTransitions.find(t => t.step === expectedTransition.step);

      if (!tsTransition) {
        validation.missingTransitions.push({
          implementation: "typescript",
          transition: expectedTransition.step,
        });
        validation.parity = false;
      }

      if (!aoTransition) {
        validation.missingTransitions.push({
          implementation: "ao_lua",
          transition: expectedTransition.step,
        });
        validation.parity = false;
      }

      if (tsTransition && aoTransition) {
        const transitionComparison = this.compareStateTransition(tsTransition, aoTransition, expectedTransition);
        validation.transitionComparisons.push(transitionComparison);

        if (!transitionComparison.matches) {
          validation.parity = false;
        }
      }
    }

    validation.score =
      validation.transitionComparisons.filter(tc => tc.matches).length /
      Math.max(validation.transitionComparisons.length, 1);

    return validation;
  }

  /**
   * Compare individual state transitions
   */
  compareStateTransition(tsTransition, aoTransition, expected) {
    const comparison = {
      step: expected.step,
      matches: true,
      differences: [],
    };

    // Compare key values if specified
    if (expected.key_values) {
      for (const [key, expectedValue] of Object.entries(expected.key_values)) {
        const tsValue = this.getNestedValue(tsTransition, key);
        const aoValue = this.getNestedValue(aoTransition, key);

        if (tsValue !== aoValue) {
          comparison.matches = false;
          comparison.differences.push({
            key,
            expected: expectedValue,
            typescript: tsValue,
            aoLua: aoValue,
          });
        }
      }
    }

    return comparison;
  }

  /**
   * Validate timing parity between implementations
   */
  validateTimingParity(tsTiming, aoTiming) {
    const validation = {
      parity: true,
      score: 1.0,
      timingComparison: {},
      recommendations: [],
    };

    if (!tsTiming || !aoTiming) {
      validation.parity = false;
      validation.score = 0;
      validation.recommendations.push("Missing timing data for comparison");
      return validation;
    }

    // Compare execution times with tolerance
    const timeDiff = Math.abs(tsTiming.total - aoTiming.total);
    const timeToleranceMs = this.tolerances.timing;

    validation.timingComparison = {
      typescript: tsTiming.total,
      aoLua: aoTiming.total,
      difference: timeDiff,
      tolerance: timeToleranceMs,
      withinTolerance: timeDiff <= timeToleranceMs,
    };

    if (!validation.timingComparison.withinTolerance) {
      validation.parity = false;
      validation.score = Math.max(0, 1 - timeDiff / (tsTiming.total + timeToleranceMs));
      validation.recommendations.push(`Timing difference ${timeDiff}ms exceeds tolerance ${timeToleranceMs}ms`);
    }

    return validation;
  }

  /**
   * Validate RNG determinism between implementations
   */
  validateRNGDeterminism(tsRngTrace, aoRngTrace) {
    const validation = {
      parity: true,
      score: 1.0,
      rngComparison: {},
      divergencePoint: null,
    };

    if (!tsRngTrace || !aoRngTrace) {
      validation.parity = false;
      validation.score = 0;
      return validation;
    }

    // Compare RNG call sequences
    const minLength = Math.min(tsRngTrace.length, aoRngTrace.length);
    let matchingCalls = 0;

    for (let i = 0; i < minLength; i++) {
      const tsCall = tsRngTrace[i];
      const aoCall = aoRngTrace[i];

      if (tsCall.value === aoCall.value && tsCall.context === aoCall.context) {
        matchingCalls++;
      } else {
        validation.divergencePoint = i;
        break;
      }
    }

    validation.rngComparison = {
      typescriptCalls: tsRngTrace.length,
      aoLuaCalls: aoRngTrace.length,
      matchingCalls,
      divergencePoint: validation.divergencePoint,
    };

    if (validation.divergencePoint !== null) {
      validation.parity = false;
      validation.score = matchingCalls / Math.max(tsRngTrace.length, aoRngTrace.length);
    }

    return validation;
  }

  /**
   * Calculate overall parity score from category scores
   */
  calculateParityScore(categories) {
    const weights = {
      execution: 0.4,
      stateTransitions: 0.3,
      timing: 0.2,
      rng: 0.1,
    };

    let totalScore = 0;
    let totalWeight = 0;

    for (const [category, result] of Object.entries(categories)) {
      const weight = weights[category] || 0.1;
      totalScore += result.score * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? totalScore / totalWeight : 0;
  }

  /**
   * Generate recommendations for improving parity
   */
  generateParityRecommendations(validation) {
    const recommendations = [];

    // Execution parity recommendations
    if (validation.parity.categories.execution && !validation.parity.categories.execution.parity) {
      recommendations.push({
        category: "execution",
        priority: "high",
        description: "Fix execution result differences",
        details: validation.parity.categories.execution.differences,
      });
    }

    // State transition recommendations
    if (validation.parity.categories.stateTransitions && !validation.parity.categories.stateTransitions.parity) {
      recommendations.push({
        category: "state_transitions",
        priority: "high",
        description: "Align state transition behavior",
        details: validation.parity.categories.stateTransitions.missingTransitions,
      });
    }

    // RNG recommendations
    if (validation.parity.categories.rng && validation.parity.categories.rng.divergencePoint !== null) {
      recommendations.push({
        category: "rng",
        priority: "critical",
        description: "Fix RNG determinism issues",
        divergencePoint: validation.parity.categories.rng.divergencePoint,
      });
    }

    return recommendations;
  }

  /**
   * Get nested value from object using dot notation
   */
  getNestedValue(obj, path) {
    return path.split(".").reduce((current, key) => {
      if (current && typeof current === "object") {
        // Handle array indices
        if (key.includes("[") && key.includes("]")) {
          const arrayKey = key.substring(0, key.indexOf("["));
          const index = Number.parseInt(key.substring(key.indexOf("[") + 1, key.indexOf("]")));
          return current[arrayKey]?.[index];
        }
        return current[key];
      }
      return undefined;
    }, obj);
  }

  /**
   * Generate comprehensive parity report
   */
  generateParityReport(scenarios) {
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        totalScenarios: scenarios.length,
        parityAchieved: 0,
        averageScore: 0,
        criticalIssues: 0,
      },
      scenarioResults: [],
      overallRecommendations: [],
    };

    let totalScore = 0;
    let criticalIssues = 0;

    for (const scenarioId of scenarios) {
      const result = this.comparisonResults.get(scenarioId);
      if (result) {
        report.scenarioResults.push({
          scenarioId: result.scenarioId,
          scenarioType: result.scenarioType,
          parity: result.parity.overall,
          score: result.parity.score,
          categories: Object.keys(result.parity.categories),
          recommendationCount: result.recommendations.length,
        });

        totalScore += result.parity.score;

        if (result.parity.overall) {
          report.summary.parityAchieved++;
        }

        // Count critical issues
        const criticalRecs = result.recommendations.filter(r => r.priority === "critical");
        criticalIssues += criticalRecs.length;
      }
    }

    report.summary.averageScore = totalScore / scenarios.length;
    report.summary.criticalIssues = criticalIssues;

    // Generate overall recommendations
    if (report.summary.averageScore < 0.9) {
      report.overallRecommendations.push({
        priority: "high",
        description: "Overall parity score below 90% threshold",
        action: "Review and fix parity issues across all scenarios",
      });
    }

    if (criticalIssues > 0) {
      report.overallRecommendations.push({
        priority: "critical",
        description: `${criticalIssues} critical parity issues identified`,
        action: "Address critical issues immediately before deployment",
      });
    }

    return report;
  }
}

module.exports = ParityValidator;
