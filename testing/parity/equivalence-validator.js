/**
 * Mathematical Equivalence Validator
 * Validates exact mathematical equivalence between TypeScript and AO Lua implementations
 * Ensures precision parity for all game calculations
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";

export class EquivalenceValidator {
  constructor(options = {}) {
    this.precisionThreshold = options.precisionThreshold || 1e-10; // Ultra-high precision
    this.toleranceOverrides = options.toleranceOverrides || new Map();
    this.validationRules = options.validationRules || new Map();
    this.reportsDir = options.reportsDir || path.join(process.cwd(), "testing/reports");

    // Mathematical validation tracking
    this.validationResults = [];
    this.formulaValidations = new Map();
    this.precisionViolations = [];

    // Built-in validation rules for Pokemon mechanics
    this.initializePokemonValidationRules();
  }

  /**
   * Initialize Pokemon-specific validation rules
   */
  initializePokemonValidationRules() {
    // Nature modifier rules
    this.addValidationRule("nature_modifiers", (tsValue, aoValue, _context) => {
      const validModifiers = [0.9, 1.0, 1.1];

      if (!validModifiers.includes(tsValue) || !validModifiers.includes(aoValue)) {
        return {
          valid: false,
          reason: `Nature modifier must be exactly 0.9, 1.0, or 1.1. TS: ${tsValue}, AO: ${aoValue}`,
        };
      }

      return { valid: tsValue === aoValue, reason: null };
    });

    // Stat calculation rules
    this.addValidationRule("stat_calculation", (tsValue, aoValue, _context) => {
      // Pokemon stats must be positive integers
      if (!Number.isInteger(tsValue) || !Number.isInteger(aoValue) || tsValue < 1 || aoValue < 1) {
        return {
          valid: false,
          reason: `Pokemon stats must be positive integers. TS: ${tsValue}, AO: ${aoValue}`,
        };
      }

      return { valid: tsValue === aoValue, reason: null };
    });

    // Damage calculation rules
    this.addValidationRule("damage_calculation", (tsValue, aoValue, _context) => {
      // Damage must be non-negative integer
      if (!Number.isInteger(tsValue) || !Number.isInteger(aoValue) || tsValue < 0 || aoValue < 0) {
        return {
          valid: false,
          reason: `Damage must be non-negative integer. TS: ${tsValue}, AO: ${aoValue}`,
        };
      }

      return { valid: tsValue === aoValue, reason: null };
    });

    // Type effectiveness rules
    this.addValidationRule("type_effectiveness", (tsValue, aoValue, _context) => {
      const validEffectiveness = [0.0, 0.25, 0.5, 1.0, 2.0, 4.0];

      if (!validEffectiveness.includes(tsValue) || !validEffectiveness.includes(aoValue)) {
        return {
          valid: false,
          reason: `Type effectiveness must be 0, 0.25, 0.5, 1.0, 2.0, or 4.0. TS: ${tsValue}, AO: ${aoValue}`,
        };
      }

      return { valid: tsValue === aoValue, reason: null };
    });

    // HP calculation special rule (Shedinja)
    this.addValidationRule("hp_special_cases", (tsValue, aoValue, context) => {
      // Shedinja always has 1 HP regardless of calculation
      if (context.species === "Shedinja" || context.speciesId === 292) {
        const expectedHP = 1;
        return {
          valid: tsValue === expectedHP && aoValue === expectedHP,
          reason:
            tsValue !== expectedHP || aoValue !== expectedHP
              ? `Shedinja HP must always be 1. TS: ${tsValue}, AO: ${aoValue}`
              : null,
        };
      }

      return { valid: true, reason: null };
    });
  }

  /**
   * Validate mathematical equivalence between two results
   */
  async validateEquivalence(typescriptResult, aoLuaResult, scenario) {
    console.log(chalk.blue(`🔢 Validating mathematical equivalence: ${scenario.name}`));

    const validation = {
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      timestamp: new Date().toISOString(),
      isEquivalent: false,
      precisionScore: 0.0,
      validationDetails: {
        exactMatches: 0,
        toleranceMatches: 0,
        precisionViolations: 0,
        ruleViolations: 0,
        totalComparisons: 0,
      },
      differences: [],
      ruleViolations: [],
      precisionIssues: [],
      confidence: 1.0,
    };

    try {
      // Perform deep mathematical comparison
      const comparisonResult = await this.performMathematicalComparison(
        typescriptResult.result,
        aoLuaResult.result,
        scenario,
        "",
      );

      validation.differences = comparisonResult.differences;
      validation.validationDetails = comparisonResult.details;
      validation.ruleViolations = comparisonResult.ruleViolations;
      validation.precisionIssues = comparisonResult.precisionIssues;

      // Calculate precision score
      validation.precisionScore = this.calculatePrecisionScore(comparisonResult);

      // Determine equivalence
      validation.isEquivalent = this.determineEquivalence(comparisonResult, scenario);

      // Validate mathematical formulas if applicable
      if (scenario.category === "pokemon_mechanics" || scenario.category === "battle") {
        const formulaValidation = await this.validateFormulas(typescriptResult, aoLuaResult, scenario);
        validation.formulaValidation = formulaValidation;
      }

      // Store validation result
      this.validationResults.push(validation);

      console.log(this.getValidationStatusMessage(validation));
    } catch (error) {
      validation.isEquivalent = false;
      validation.error = error.message;
      console.error(chalk.red(`❌ Equivalence validation error: ${error.message}`));
    }

    return validation;
  }

  /**
   * Perform deep mathematical comparison with precision analysis
   */
  async performMathematicalComparison(tsObj, aoObj, scenario, path = "") {
    const result = {
      differences: [],
      ruleViolations: [],
      precisionIssues: [],
      details: {
        exactMatches: 0,
        toleranceMatches: 0,
        precisionViolations: 0,
        ruleViolations: 0,
        totalComparisons: 0,
      },
    };

    const compare = (tsValue, aoValue, currentPath) => {
      result.details.totalComparisons++;

      // Type validation
      if (typeof tsValue !== typeof aoValue) {
        result.differences.push({
          type: "type_mismatch",
          path: currentPath,
          typescriptValue: tsValue,
          aoValue: aoValue,
          typescriptType: typeof tsValue,
          aoType: typeof aoValue,
          severity: "high",
        });
        return;
      }

      // Handle different data types
      if (typeof tsValue === "number") {
        this.compareNumbers(tsValue, aoValue, currentPath, scenario, result);
      } else if (typeof tsValue === "object" && tsValue !== null && aoValue !== null) {
        this.compareObjects(tsValue, aoValue, currentPath, scenario, result);
      } else {
        this.compareValues(tsValue, aoValue, currentPath, scenario, result);
      }
    };

    compare(tsObj, aoObj, path);
    return result;
  }

  /**
   * Compare numeric values with precision analysis
   */
  compareNumbers(tsValue, aoValue, path, scenario, result) {
    const tolerance = this.getTolerance(path, scenario);
    const absoluteDifference = Math.abs(tsValue - aoValue);
    const relativeDifference = tsValue !== 0 ? absoluteDifference / Math.abs(tsValue) : absoluteDifference;

    // Check for exact match
    if (tsValue === aoValue) {
      result.details.exactMatches++;
      return;
    }

    // Check precision requirements
    if (absoluteDifference < this.precisionThreshold) {
      result.details.exactMatches++;
      return;
    }

    // Check tolerance
    if (tolerance > 0 && absoluteDifference <= tolerance) {
      result.details.toleranceMatches++;

      // Still flag as precision issue if it's within tolerance but not exact
      if (this.requiresExactMatch(path, scenario)) {
        result.precisionIssues.push({
          type: "tolerance_match_not_exact",
          path: path,
          typescriptValue: tsValue,
          aoValue: aoValue,
          difference: absoluteDifference,
          tolerance: tolerance,
          severity: "medium",
        });
        result.details.precisionViolations++;
      }
      return;
    }

    // Record as difference
    result.differences.push({
      type: "numeric_difference",
      path: path,
      typescriptValue: tsValue,
      aoValue: aoValue,
      absoluteDifference: absoluteDifference,
      relativeDifference: relativeDifference,
      tolerance: tolerance,
      severity: this.assessNumericSeverity(absoluteDifference, relativeDifference, tolerance),
    });

    // Apply validation rules
    this.applyValidationRules(tsValue, aoValue, path, scenario, result);
  }

  /**
   * Compare object structures recursively
   */
  compareObjects(tsObj, aoObj, path, scenario, result) {
    const tsKeys = Object.keys(tsObj);
    const aoKeys = Object.keys(aoObj);
    const allKeys = new Set([...tsKeys, ...aoKeys]);

    for (const key of allKeys) {
      const newPath = path ? `${path}.${key}` : key;

      if (!(key in tsObj)) {
        result.differences.push({
          type: "missing_key_typescript",
          path: newPath,
          aoValue: aoObj[key],
          severity: "medium",
        });
      } else if (!(key in aoObj)) {
        result.differences.push({
          type: "missing_key_ao",
          path: newPath,
          typescriptValue: tsObj[key],
          severity: "medium",
        });
      } else {
        // Recursively compare
        const subResult = this.performMathematicalComparison(
          { [key]: tsObj[key] },
          { [key]: aoObj[key] },
          scenario,
          newPath,
        );

        // Merge results
        result.differences.push(...subResult.differences);
        result.ruleViolations.push(...subResult.ruleViolations);
        result.precisionIssues.push(...subResult.precisionIssues);

        // Merge details
        Object.keys(result.details).forEach(detailKey => {
          result.details[detailKey] += subResult.details[detailKey];
        });
      }
    }
  }

  /**
   * Compare non-numeric values
   */
  compareValues(tsValue, aoValue, path, _scenario, result) {
    if (tsValue === aoValue) {
      result.details.exactMatches++;
    } else {
      result.differences.push({
        type: "value_difference",
        path: path,
        typescriptValue: tsValue,
        aoValue: aoValue,
        severity: "medium",
      });
    }
  }

  /**
   * Apply validation rules to numeric comparisons
   */
  applyValidationRules(tsValue, aoValue, path, scenario, result) {
    // Determine which rules apply to this path
    const applicableRules = this.getApplicableRules(path, scenario);

    for (const [ruleName, ruleFunction] of applicableRules) {
      try {
        const ruleResult = ruleFunction(tsValue, aoValue, {
          path: path,
          scenario: scenario,
          species: scenario.inputGameState?.pokemon?.species,
          speciesId: scenario.inputGameState?.pokemon?.speciesId,
        });

        if (!ruleResult.valid) {
          result.ruleViolations.push({
            rule: ruleName,
            path: path,
            typescriptValue: tsValue,
            aoValue: aoValue,
            reason: ruleResult.reason,
            severity: "high",
          });
          result.details.ruleViolations++;
        }
      } catch (error) {
        console.error(chalk.red(`❌ Rule validation error for ${ruleName}: ${error.message}`));
      }
    }
  }

  /**
   * Validate mathematical formulas used in calculations
   */
  async validateFormulas(typescriptResult, aoLuaResult, scenario) {
    const formulaValidation = {
      formulasValidated: [],
      allFormulasCorrect: true,
      formulaIssues: [],
    };

    // Validate Pokemon stat calculation formula
    if (scenario.category === "pokemon_mechanics" && scenario.inputGameState?.pokemon) {
      const statFormulaValidation = await this.validateStatCalculationFormula(typescriptResult, aoLuaResult, scenario);
      formulaValidation.formulasValidated.push("stat_calculation");

      if (!statFormulaValidation.isCorrect) {
        formulaValidation.allFormulasCorrect = false;
        formulaValidation.formulaIssues.push(...statFormulaValidation.issues);
      }
    }

    // Validate damage calculation formula
    if (scenario.category === "battle" && scenario.inputGameState?.battle) {
      const damageFormulaValidation = await this.validateDamageCalculationFormula(
        typescriptResult,
        aoLuaResult,
        scenario,
      );
      formulaValidation.formulasValidated.push("damage_calculation");

      if (!damageFormulaValidation.isCorrect) {
        formulaValidation.allFormulasCorrect = false;
        formulaValidation.formulaIssues.push(...damageFormulaValidation.issues);
      }
    }

    return formulaValidation;
  }

  /**
   * Validate Pokemon stat calculation formula
   */
  async validateStatCalculationFormula(typescriptResult, aoLuaResult, scenario) {
    const validation = {
      isCorrect: true,
      issues: [],
    };

    const pokemon = scenario.inputGameState.pokemon;
    const expectedStats = this.calculateExpectedStats(pokemon);

    // Compare calculated stats with expected formula results
    if (typescriptResult.result.finalStats) {
      const tsStats = typescriptResult.result.finalStats;

      for (let i = 0; i < expectedStats.length; i++) {
        if (tsStats[i] !== expectedStats[i]) {
          validation.isCorrect = false;
          validation.issues.push({
            type: "stat_formula_error",
            statIndex: i,
            expected: expectedStats[i],
            calculated: tsStats[i],
            implementation: "typescript",
          });
        }
      }
    }

    if (aoLuaResult.result.finalStats) {
      const aoStats = aoLuaResult.result.finalStats;

      for (let i = 0; i < expectedStats.length; i++) {
        if (aoStats[i] !== expectedStats[i]) {
          validation.isCorrect = false;
          validation.issues.push({
            type: "stat_formula_error",
            statIndex: i,
            expected: expectedStats[i],
            calculated: aoStats[i],
            implementation: "ao_lua",
          });
        }
      }
    }

    return validation;
  }

  /**
   * Calculate expected Pokemon stats using reference formula
   */
  calculateExpectedStats(pokemon) {
    const level = pokemon.level;
    const baseStats = pokemon.baseStats;
    const ivs = { hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31, ...pokemon.ivs };
    const evs = { hp: 0, attack: 0, defense: 0, spAttack: 0, spDefense: 0, speed: 0, ...pokemon.evs };
    const nature = pokemon.nature || "Hardy";

    const natureModifiers = this.getNatureModifiers(nature);

    // Gen 8 Pokemon stat calculation formula
    const stats = [];

    // HP calculation (different formula)
    if (pokemon.species === "Shedinja" || pokemon.speciesId === 292) {
      stats[0] = 1; // Shedinja always has 1 HP
    } else {
      stats[0] = Math.floor(((2 * baseStats.hp + ivs.hp + Math.floor(evs.hp / 4)) * level) / 100 + level + 10);
    }

    // Other stats calculation
    const statKeys = ["attack", "defense", "spAttack", "spDefense", "speed"];
    const modifierKeys = ["attack", "defense", "spAttack", "spDefense", "speed"];

    for (let i = 0; i < statKeys.length; i++) {
      const statKey = statKeys[i];
      const modifierKey = modifierKeys[i];

      const baseStat = Math.floor(
        ((2 * baseStats[statKey] + ivs[statKey] + Math.floor(evs[statKey] / 4)) * level) / 100 + 5,
      );
      stats[i + 1] = Math.floor(baseStat * natureModifiers[modifierKey]);
    }

    return stats;
  }

  /**
   * Get nature modifiers for stat calculations
   */
  getNatureModifiers(nature) {
    const natureMap = {
      Hardy: { attack: 1.0, defense: 1.0, spAttack: 1.0, spDefense: 1.0, speed: 1.0 },
      Adamant: { attack: 1.1, defense: 1.0, spAttack: 0.9, spDefense: 1.0, speed: 1.0 },
      Modest: { attack: 0.9, defense: 1.0, spAttack: 1.1, spDefense: 1.0, speed: 1.0 },
      Timid: { attack: 0.9, defense: 1.0, spAttack: 1.0, spDefense: 1.0, speed: 1.1 },
      Bold: { attack: 0.9, defense: 1.1, spAttack: 1.0, spDefense: 1.0, speed: 1.0 },
      Jolly: { attack: 1.0, defense: 1.0, spAttack: 0.9, spDefense: 1.0, speed: 1.1 },
    };

    return natureMap[nature] || natureMap["Hardy"];
  }

  /**
   * Validate damage calculation formula
   */
  async validateDamageCalculationFormula(typescriptResult, aoLuaResult, scenario) {
    const validation = {
      isCorrect: true,
      issues: [],
    };

    // Simplified damage formula validation
    const battle = scenario.inputGameState.battle || scenario.inputGameState;
    const expectedDamage = this.calculateExpectedDamage(battle);

    // Compare with TypeScript result
    if (typescriptResult.result.damage !== expectedDamage) {
      validation.isCorrect = false;
      validation.issues.push({
        type: "damage_formula_error",
        expected: expectedDamage,
        calculated: typescriptResult.result.damage,
        implementation: "typescript",
      });
    }

    // Compare with AO Lua result
    if (aoLuaResult.result.damage !== expectedDamage) {
      validation.isCorrect = false;
      validation.issues.push({
        type: "damage_formula_error",
        expected: expectedDamage,
        calculated: aoLuaResult.result.damage,
        implementation: "ao_lua",
      });
    }

    return validation;
  }

  /**
   * Calculate expected damage using reference formula
   */
  calculateExpectedDamage(battle) {
    // Simplified Gen 8 damage formula
    const level = battle.attacker.level;
    const power = battle.move.power;
    const attack = battle.attacker.stats?.attack || 100;
    const defense = battle.defender.stats?.defense || 80;

    // Type effectiveness
    const effectiveness = this.calculateTypeEffectiveness(battle.move.type, battle.defender.types);

    // Damage roll (use fixed value for testing)
    const damageRoll = battle.rng?.damageRoll || 0.85;

    // Gen 8 damage formula
    const baseDamage = Math.floor(((((2 * level) / 5 + 2) * power * attack) / defense / 50 + 2) * damageRoll);
    const finalDamage = Math.floor(baseDamage * effectiveness);

    return finalDamage;
  }

  /**
   * Calculate type effectiveness
   */
  calculateTypeEffectiveness(attackingType, defendingTypes) {
    // Simplified type chart
    const typeChart = {
      Fire: { Grass: 2.0, Water: 0.5, Fire: 0.5 },
      Water: { Fire: 2.0, Grass: 0.5, Water: 0.5 },
      Electric: { Water: 2.0, Flying: 2.0, Ground: 0.0, Electric: 0.5 },
    };

    let effectiveness = 1.0;

    if (defendingTypes) {
      for (const defendingType of defendingTypes) {
        const matchup = typeChart[attackingType]?.[defendingType];
        if (matchup !== undefined) {
          effectiveness *= matchup;
        }
      }
    }

    return effectiveness;
  }

  /**
   * Generate comprehensive mathematical equivalence report
   */
  async generateEquivalenceReport() {
    console.log(chalk.blue("📊 Generating mathematical equivalence report..."));

    const report = {
      timestamp: new Date().toISOString(),
      summary: this.getEquivalenceSummary(),
      validationResults: this.validationResults,
      precisionAnalysis: this.analyzePrecisionIssues(),
      ruleViolationAnalysis: this.analyzeRuleViolations(),
      formulaValidationSummary: this.getFormulaValidationSummary(),
      recommendations: this.generateEquivalenceRecommendations(),
    };

    const reportPath = path.join(this.reportsDir, `mathematical-equivalence-report-${Date.now()}.json`);
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    // Generate HTML report
    const htmlReport = this.generateEquivalenceHtmlReport(report);
    const htmlReportPath = path.join(this.reportsDir, `mathematical-equivalence-report-${Date.now()}.html`);
    await fs.writeFile(htmlReportPath, htmlReport);

    console.log(chalk.green("📄 Mathematical equivalence reports generated:"));
    console.log(chalk.blue(`  JSON: ${reportPath}`));
    console.log(chalk.blue(`  HTML: ${htmlReportPath}`));

    return report;
  }

  /**
   * Helper methods
   */

  addValidationRule(ruleName, ruleFunction) {
    this.validationRules.set(ruleName, ruleFunction);
  }

  getTolerance(path, scenario) {
    // Check for scenario-specific tolerance
    if (scenario.tolerances && scenario.tolerances[path] !== undefined) {
      return scenario.tolerances[path];
    }

    // Check for global tolerance overrides
    if (this.toleranceOverrides.has(path)) {
      return this.toleranceOverrides.get(path);
    }

    // Default to zero tolerance for exact matching
    return 0;
  }

  requiresExactMatch(path, scenario) {
    // Pokemon stats and nature modifiers require exact matches
    const exactMatchPaths = ["finalStats", "statModifiers", "damage", "effectiveness"];

    return (
      exactMatchPaths.some(exactPath => path.includes(exactPath)) ||
      scenario.validationRules?.requiresExactMatch === true
    );
  }

  getApplicableRules(path, _scenario) {
    const applicableRules = [];

    // Apply rules based on path patterns
    if (path.includes("modifier") || path.includes("nature")) {
      applicableRules.push(["nature_modifiers", this.validationRules.get("nature_modifiers")]);
    }

    if (path.includes("Stats") || path.includes("stat")) {
      applicableRules.push(["stat_calculation", this.validationRules.get("stat_calculation")]);
    }

    if (path.includes("damage")) {
      applicableRules.push(["damage_calculation", this.validationRules.get("damage_calculation")]);
    }

    if (path.includes("effectiveness")) {
      applicableRules.push(["type_effectiveness", this.validationRules.get("type_effectiveness")]);
    }

    if (path.includes("hp") || path.includes("Hp")) {
      applicableRules.push(["hp_special_cases", this.validationRules.get("hp_special_cases")]);
    }

    return applicableRules.filter(([_, rule]) => rule !== undefined);
  }

  assessNumericSeverity(absoluteDifference, _relativeDifference, tolerance) {
    if (tolerance === 0) {
      // Exact match required
      return absoluteDifference === 0 ? "none" : "high";
    }

    if (absoluteDifference > tolerance * 10) {
      return "high";
    }
    if (absoluteDifference > tolerance * 2) {
      return "medium";
    }
    return "low";
  }

  calculatePrecisionScore(comparisonResult) {
    const { details } = comparisonResult;
    const totalComparisons = details.totalComparisons;

    if (totalComparisons === 0) {
      return 1.0;
    }

    const exactMatchWeight = 1.0;
    const toleranceMatchWeight = 0.8;
    const violationPenalty = 0.5;

    const score =
      (details.exactMatches * exactMatchWeight +
        details.toleranceMatches * toleranceMatchWeight -
        details.precisionViolations * violationPenalty -
        details.ruleViolations * violationPenalty) /
      totalComparisons;

    return Math.max(0, Math.min(1, score));
  }

  determineEquivalence(comparisonResult, scenario) {
    // High-level equivalence determination
    const { details, differences, ruleViolations } = comparisonResult;

    // No rule violations allowed
    if (ruleViolations.length > 0) {
      return false;
    }

    // Check for high-severity differences
    const highSeverityDiffs = differences.filter(diff => diff.severity === "high");
    if (highSeverityDiffs.length > 0) {
      return false;
    }

    // Precision score threshold
    const precisionScore = this.calculatePrecisionScore(comparisonResult);
    const precisionThreshold = scenario.validationRules?.requiresExactMatch ? 0.95 : 0.8;

    return precisionScore >= precisionThreshold;
  }

  getValidationStatusMessage(validation) {
    if (validation.isEquivalent) {
      return chalk.green(
        `✅ Mathematical equivalence validated (precision: ${(validation.precisionScore * 100).toFixed(1)}%)`,
      );
    }
    const issues = validation.differences.length + validation.ruleViolations.length;
    return chalk.red(
      `❌ Mathematical equivalence failed (${issues} issues, precision: ${(validation.precisionScore * 100).toFixed(1)}%)`,
    );
  }

  getEquivalenceSummary() {
    const total = this.validationResults.length;
    const equivalent = this.validationResults.filter(v => v.isEquivalent).length;
    const avgPrecision = total > 0 ? this.validationResults.reduce((sum, v) => sum + v.precisionScore, 0) / total : 0;

    return {
      totalValidations: total,
      equivalentValidations: equivalent,
      equivalenceRate: total > 0 ? (equivalent / total) * 100 : 0,
      averagePrecisionScore: avgPrecision,
      totalDifferences: this.validationResults.reduce((sum, v) => sum + v.differences.length, 0),
      totalRuleViolations: this.validationResults.reduce((sum, v) => sum + v.ruleViolations.length, 0),
      totalPrecisionIssues: this.validationResults.reduce((sum, v) => sum + v.precisionIssues.length, 0),
    };
  }

  analyzePrecisionIssues() {
    const allPrecisionIssues = this.validationResults.flatMap(v => v.precisionIssues);

    const issuesByType = {};
    const issuesBySeverity = { high: 0, medium: 0, low: 0 };

    allPrecisionIssues.forEach(issue => {
      issuesByType[issue.type] = (issuesByType[issue.type] || 0) + 1;
      issuesBySeverity[issue.severity] = (issuesBySeverity[issue.severity] || 0) + 1;
    });

    return {
      totalIssues: allPrecisionIssues.length,
      issuesByType,
      issuesBySeverity,
      commonPaths: this.getCommonPaths(allPrecisionIssues),
    };
  }

  analyzeRuleViolations() {
    const allRuleViolations = this.validationResults.flatMap(v => v.ruleViolations);

    const violationsByRule = {};
    const violationsBySeverity = { high: 0, medium: 0, low: 0 };

    allRuleViolations.forEach(violation => {
      violationsByRule[violation.rule] = (violationsByRule[violation.rule] || 0) + 1;
      violationsBySeverity[violation.severity] = (violationsBySeverity[violation.severity] || 0) + 1;
    });

    return {
      totalViolations: allRuleViolations.length,
      violationsByRule,
      violationsBySeverity,
      commonPaths: this.getCommonPaths(allRuleViolations),
    };
  }

  getCommonPaths(issues) {
    const pathCounts = {};

    issues.forEach(issue => {
      pathCounts[issue.path] = (pathCounts[issue.path] || 0) + 1;
    });

    return Object.entries(pathCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 10) // Top 10 most common paths
      .map(([path, count]) => ({ path, count }));
  }

  getFormulaValidationSummary() {
    const formulaResults = this.validationResults.filter(v => v.formulaValidation).map(v => v.formulaValidation);

    if (formulaResults.length === 0) {
      return { totalFormulas: 0, correctFormulas: 0, formulaAccuracy: 0 };
    }

    const totalFormulas = formulaResults.reduce((sum, f) => sum + f.formulasValidated.length, 0);
    const correctFormulas = formulaResults.filter(f => f.allFormulasCorrect).length;

    return {
      totalFormulas,
      correctFormulas,
      formulaAccuracy: totalFormulas > 0 ? (correctFormulas / totalFormulas) * 100 : 0,
      commonIssues: this.getCommonFormulaIssues(formulaResults),
    };
  }

  getCommonFormulaIssues(formulaResults) {
    const allIssues = formulaResults.flatMap(f => f.formulaIssues || []);
    const issueTypes = {};

    allIssues.forEach(issue => {
      issueTypes[issue.type] = (issueTypes[issue.type] || 0) + 1;
    });

    return Object.entries(issueTypes)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 5)
      .map(([type, count]) => ({ type, count }));
  }

  generateEquivalenceRecommendations() {
    const recommendations = [];
    const summary = this.getEquivalenceSummary();

    if (summary.equivalenceRate < 90) {
      recommendations.push({
        priority: "high",
        category: "equivalence",
        description: `Low equivalence rate (${summary.equivalenceRate.toFixed(1)}%). Review mathematical implementations.`,
        action: "review_mathematical_implementations",
      });
    }

    if (summary.averagePrecisionScore < 0.9) {
      recommendations.push({
        priority: "high",
        category: "precision",
        description: `Low precision score (${(summary.averagePrecisionScore * 100).toFixed(1)}%). Improve numerical precision.`,
        action: "improve_numerical_precision",
      });
    }

    if (summary.totalRuleViolations > 0) {
      recommendations.push({
        priority: "critical",
        category: "rules",
        description: `${summary.totalRuleViolations} rule violations detected. Fix implementation compliance.`,
        action: "fix_rule_violations",
      });
    }

    return recommendations;
  }

  generateEquivalenceHtmlReport(report) {
    return `
<!DOCTYPE html>
<html>
<head>
    <title>Mathematical Equivalence Validation Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; margin-bottom: 5px; }
        .metric-label { font-size: 0.9em; opacity: 0.9; }
        .section { margin: 30px 0; }
        .precision-high { color: #28a745; }
        .precision-medium { color: #ffc107; }
        .precision-low { color: #dc3545; }
        .recommendations { background: #e9ecef; padding: 20px; border-radius: 8px; }
        .recommendation { margin: 10px 0; padding: 10px; border-left: 4px solid #007bff; background: white; }
        .critical { border-left-color: #dc3545; }
        .high { border-left-color: #fd7e14; }
        .medium { border-left-color: #ffc107; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔢 Mathematical Equivalence Validation Report</h1>
            <p><strong>Generated:</strong> ${report.timestamp}</p>
        </div>
        
        <div class="summary-grid">
            <div class="metric-card">
                <div class="metric-value">${report.summary.equivalenceRate.toFixed(1)}%</div>
                <div class="metric-label">Equivalence Rate</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${(report.summary.averagePrecisionScore * 100).toFixed(1)}%</div>
                <div class="metric-label">Avg Precision Score</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${report.summary.totalValidations}</div>
                <div class="metric-label">Total Validations</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${report.summary.totalRuleViolations}</div>
                <div class="metric-label">Rule Violations</div>
            </div>
        </div>

        <div class="section">
            <h2>📊 Precision Analysis</h2>
            <p><strong>Total Issues:</strong> ${report.precisionAnalysis.totalIssues}</p>
            <p><strong>High Severity:</strong> ${report.precisionAnalysis.issuesBySeverity.high}</p>
            <p><strong>Medium Severity:</strong> ${report.precisionAnalysis.issuesBySeverity.medium}</p>
            <p><strong>Low Severity:</strong> ${report.precisionAnalysis.issuesBySeverity.low}</p>
        </div>

        <div class="section">
            <h2>🛡️ Rule Violations</h2>
            <p><strong>Total Violations:</strong> ${report.ruleViolationAnalysis.totalViolations}</p>
            ${Object.entries(report.ruleViolationAnalysis.violationsByRule)
              .map(([rule, count]) => `<p><strong>${rule}:</strong> ${count} violations</p>`)
              .join("")}
        </div>

        <div class="recommendations">
            <h2>💡 Recommendations</h2>
            ${report.recommendations
              .map(
                rec =>
                  `<div class="recommendation ${rec.priority}">
                <strong>${rec.category.toUpperCase()} (${rec.priority}):</strong> ${rec.description}
              </div>`,
              )
              .join("")}
        </div>
    </div>
</body>
</html>`;
  }
}
