/**
 * Validation Framework
 * Comprehensive validation tools for deployment testing
 */

import fs from "fs/promises";
import path from "path";
import chalk from "chalk";

export class ValidationFramework {
  constructor(options = {}) {
    this.strictMode = options.strictMode || false;
    this.adpVersion = options.adpVersion || "1.0";
    this.validationRules = options.validationRules || this.getDefaultValidationRules();
    this.validationResults = [];
  }

  /**
   * Get default validation rules
   */
  getDefaultValidationRules() {
    return {
      size: {
        maxSize: 500000, // 500KB
        warningThreshold: 450000, // 450KB (90% of max)
        critical: true
      },
      aoCompatibility: {
        forbiddenPatterns: [
          { pattern: /require\s*\(/g, error: "require() not allowed - use monolithic design", critical: true },
          { pattern: /io\./g, error: "io operations not allowed in AO processes", critical: true },
          { pattern: /os\.time\(\)/g, error: "Use msg.Timestamp instead of os.time()", critical: true },
          { pattern: /debug\./g, error: "debug library not available in AO", critical: true },
          { pattern: /package\./g, error: "package operations not allowed", critical: true },
          { pattern: /loadfile\s*\(/g, error: "loadfile() not allowed in AO", critical: true },
          { pattern: /dofile\s*\(/g, error: "dofile() not allowed in AO", critical: true }
        ],
        requiredPatterns: [
          { pattern: /Handlers\.add\s*\(/g, error: "Process must use Handlers.add() pattern", critical: true },
          { pattern: /ao\.send\s*\(/g, error: "Process must use ao.send for responses", critical: true }
        ]
      },
      handlerPatterns: {
        requiredHandlers: ["Info"], // ADP v1.0 requirement
        handlerNamingPattern: /^[A-Z][a-zA-Z0-9]*$/,
        errorHandlingRequired: true
      },
      adpCompliance: {
        version: "1.0",
        requiredStructures: [
          "adpVersion",
          "capabilities", 
          "messageSchemas",
          "handlers"
        ],
        selfDocumenting: true
      },
      securityValidation: {
        noHardcodedSecrets: true,
        noEvalStatements: true,
        noUnsafeOperations: true
      },
      codeQuality: {
        maxComplexity: 100, // Rough cyclomatic complexity limit
        maxFunctionLength: 1000, // Max lines per function
        requireErrorHandling: true
      }
    };
  }

  /**
   * Validate a process bundle comprehensively
   */
  async validateProcessBundle(processPath, config = {}) {
    const validation = {
      processPath,
      timestamp: new Date().toISOString(),
      overallValid: true,
      validationResults: {},
      errors: [],
      warnings: [],
      metrics: {}
    };

    try {
      // Read process content
      const processContent = await fs.readFile(processPath, "utf8");
      validation.metrics.contentLength = processContent.length;
      validation.metrics.linesOfCode = processContent.split('\n').length;

      // Run all validation checks
      const validationChecks = [
        { name: "size", fn: () => this.validateSize(processContent, processPath) },
        { name: "aoCompatibility", fn: () => this.validateAOCompatibility(processContent) },
        { name: "handlerPatterns", fn: () => this.validateHandlerPatterns(processContent, config) },
        { name: "adpCompliance", fn: () => this.validateADPCompliance(processContent) },
        { name: "securityValidation", fn: () => this.validateSecurity(processContent) },
        { name: "codeQuality", fn: () => this.validateCodeQuality(processContent) },
        { name: "processStructure", fn: () => this.validateProcessStructure(processContent) },
        { name: "performanceOptimization", fn: () => this.validatePerformanceOptimization(processContent) }
      ];

      for (const check of validationChecks) {
        try {
          const result = await check.fn();
          validation.validationResults[check.name] = result;
          
          if (!result.valid) {
            validation.overallValid = false;
            validation.errors.push(...(result.errors || []));
          }
          
          validation.warnings.push(...(result.warnings || []));
        } catch (error) {
          validation.validationResults[check.name] = {
            valid: false,
            error: error.message
          };
          validation.overallValid = false;
          validation.errors.push(`${check.name} validation failed: ${error.message}`);
        }
      }

      // Calculate validation score
      validation.metrics.validationScore = this.calculateValidationScore(validation.validationResults);
      
      console.log(chalk[validation.overallValid ? "green" : "red"](
        `  ${validation.overallValid ? "✅" : "❌"} Bundle validation: ${path.basename(processPath)} - ${validation.overallValid ? "VALID" : "INVALID"} (${validation.metrics.validationScore}%)`
      ));

      this.validationResults.push(validation);
      return validation;

    } catch (error) {
      validation.overallValid = false;
      validation.errors.push(`Validation failed: ${error.message}`);
      console.log(chalk.red(`❌ Bundle validation failed for ${path.basename(processPath)}: ${error.message}`));
      return validation;
    }
  }

  /**
   * Validate process size
   */
  validateSize(processContent, processPath) {
    const size = Buffer.byteLength(processContent, "utf8");
    const rules = this.validationRules.size;
    
    const result = {
      valid: size <= rules.maxSize,
      size,
      maxSize: rules.maxSize,
      warnings: [],
      errors: []
    };

    if (size > rules.maxSize) {
      result.errors.push(`Process size ${size} exceeds limit ${rules.maxSize} bytes`);
    } else if (size > rules.warningThreshold) {
      result.warnings.push(`Process size ${size} approaching limit ${rules.maxSize} bytes`);
    }

    // Additional size analysis
    result.metrics = {
      sizeKB: (size / 1024).toFixed(2),
      percentOfLimit: ((size / rules.maxSize) * 100).toFixed(1),
      compressionPotential: this.estimateCompressionPotential(processContent)
    };

    return result;
  }

  /**
   * Validate AO compatibility
   */
  validateAOCompatibility(processContent) {
    const rules = this.validationRules.aoCompatibility;
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      forbiddenPatternMatches: [],
      missingRequiredPatterns: []
    };

    // Check forbidden patterns
    for (const { pattern, error, critical } of rules.forbiddenPatterns) {
      const matches = [...processContent.matchAll(pattern)];
      if (matches.length > 0) {
        result.forbiddenPatternMatches.push({ pattern: pattern.source, matches: matches.length, error });
        
        if (critical) {
          result.valid = false;
          result.errors.push(`${error} (${matches.length} occurrences)`);
        } else {
          result.warnings.push(`${error} (${matches.length} occurrences)`);
        }
      }
    }

    // Check required patterns
    for (const { pattern, error, critical } of rules.requiredPatterns) {
      const matches = [...processContent.matchAll(pattern)];
      if (matches.length === 0) {
        result.missingRequiredPatterns.push({ pattern: pattern.source, error });
        
        if (critical) {
          result.valid = false;
          result.errors.push(error);
        } else {
          result.warnings.push(error);
        }
      }
    }

    return result;
  }

  /**
   * Validate handler patterns
   */
  validateHandlerPatterns(processContent, config) {
    const rules = this.validationRules.handlerPatterns;
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      foundHandlers: [],
      missingHandlers: []
    };

    // Extract handler registrations
    const handlerPattern = /Handlers\.add\s*\(\s*["']([^"']+)["']/g;
    const handlerMatches = [...processContent.matchAll(handlerPattern)];
    result.foundHandlers = handlerMatches.map(match => match[1]);

    // Check required handlers
    const requiredHandlers = [
      ...rules.requiredHandlers,
      ...(config.requiredHandlers || [])
    ];

    for (const handler of requiredHandlers) {
      if (!result.foundHandlers.includes(handler)) {
        result.missingHandlers.push(handler);
        result.valid = false;
        result.errors.push(`Required handler '${handler}' not found`);
      }
    }

    // Validate handler naming convention
    for (const handler of result.foundHandlers) {
      if (!rules.handlerNamingPattern.test(handler)) {
        result.warnings.push(`Handler '${handler}' does not follow naming convention`);
      }
    }

    // Check error handling in handlers
    if (rules.errorHandlingRequired) {
      const pcallPattern = /pcall\s*\(/g;
      const pcallMatches = [...processContent.matchAll(pcallPattern)];
      
      if (pcallMatches.length === 0) {
        result.warnings.push("No error handling (pcall) detected in process");
      }
    }

    result.handlerCount = result.foundHandlers.length;
    return result;
  }

  /**
   * Validate ADP compliance
   */
  validateADPCompliance(processContent) {
    const rules = this.validationRules.adpCompliance;
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      foundStructures: [],
      missingStructures: []
    };

    // Check for ADP version declaration
    const adpVersionPattern = new RegExp(`adpVersion.*["']${rules.version}["']`);
    if (!adpVersionPattern.test(processContent)) {
      result.valid = false;
      result.errors.push(`ADP version ${rules.version} not declared`);
    }

    // Check for required ADP structures
    for (const structure of rules.requiredStructures) {
      if (processContent.includes(structure)) {
        result.foundStructures.push(structure);
      } else {
        result.missingStructures.push(structure);
        if (structure === "capabilities" || structure === "messageSchemas") {
          result.valid = false;
          result.errors.push(`ADP structure '${structure}' required for compliance`);
        } else {
          result.warnings.push(`ADP structure '${structure}' recommended for compliance`);
        }
      }
    }

    // Check for Info handler (required for ADP)
    if (!processContent.includes('"Info"') && !processContent.includes("'Info'")) {
      result.valid = false;
      result.errors.push("ADP compliance requires Info handler");
    }

    result.adpCompliance = (result.foundStructures.length / rules.requiredStructures.length) * 100;
    return result;
  }

  /**
   * Validate security aspects
   */
  validateSecurity(processContent) {
    const rules = this.validationRules.securityValidation;
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      securityIssues: []
    };

    // Check for hardcoded secrets/keys
    if (rules.noHardcodedSecrets) {
      const secretPatterns = [
        /["'][a-zA-Z0-9]{32,}["']/g, // Potential API keys
        /password\s*=\s*["'][^"']+["']/gi,
        /secret\s*=\s*["'][^"']+["']/gi,
        /key\s*=\s*["'][^"']+["']/gi
      ];

      for (const pattern of secretPatterns) {
        const matches = [...processContent.matchAll(pattern)];
        if (matches.length > 0) {
          result.securityIssues.push({
            type: "potential_hardcoded_secret",
            matches: matches.length,
            pattern: pattern.source
          });
          result.warnings.push(`Potential hardcoded secret detected (${matches.length} matches)`);
        }
      }
    }

    // Check for eval statements
    if (rules.noEvalStatements) {
      const evalPattern = /\beval\s*\(/g;
      const evalMatches = [...processContent.matchAll(evalPattern)];
      if (evalMatches.length > 0) {
        result.valid = false;
        result.errors.push(`eval() statements detected (${evalMatches.length} occurrences) - security risk`);
        result.securityIssues.push({
          type: "eval_statement",
          matches: evalMatches.length
        });
      }
    }

    // Check for unsafe operations
    if (rules.noUnsafeOperations) {
      const unsafePatterns = [
        { pattern: /loadstring\s*\(/g, error: "loadstring() is unsafe" },
        { pattern: /setfenv\s*\(/g, error: "setfenv() can be unsafe" },
        { pattern: /rawget\s*\(/g, error: "rawget() bypasses metamethods - potential security risk" }
      ];

      for (const { pattern, error } of unsafePatterns) {
        const matches = [...processContent.matchAll(pattern)];
        if (matches.length > 0) {
          result.warnings.push(`${error} (${matches.length} occurrences)`);
          result.securityIssues.push({
            type: "unsafe_operation",
            operation: pattern.source,
            matches: matches.length
          });
        }
      }
    }

    result.securityScore = result.securityIssues.length === 0 ? 100 : Math.max(0, 100 - (result.securityIssues.length * 10));
    return result;
  }

  /**
   * Validate code quality
   */
  validateCodeQuality(processContent) {
    const rules = this.validationRules.codeQuality;
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      metrics: {}
    };

    // Estimate cyclomatic complexity (rough approximation)
    const complexityIndicators = [
      /\bif\b/g,
      /\bwhile\b/g,
      /\bfor\b/g,
      /\band\b/g,
      /\bor\b/g,
      /\belseif\b/g
    ];

    let totalComplexity = 1; // Base complexity
    for (const pattern of complexityIndicators) {
      const matches = [...processContent.matchAll(pattern)];
      totalComplexity += matches.length;
    }

    result.metrics.estimatedComplexity = totalComplexity;

    if (totalComplexity > rules.maxComplexity) {
      result.warnings.push(`High complexity detected: ${totalComplexity} (threshold: ${rules.maxComplexity})`);
    }

    // Check function lengths (rough approximation)
    const functionPattern = /function\s+\w+\s*\([^)]*\)(.*?)(?=function|\z)/gs;
    const functions = [...processContent.matchAll(functionPattern)];
    let longFunctions = 0;

    for (const func of functions) {
      const lineCount = func[1].split('\n').length;
      if (lineCount > rules.maxFunctionLength) {
        longFunctions++;
      }
    }

    result.metrics.functionCount = functions.length;
    result.metrics.averageFunctionLength = functions.length > 0 
      ? functions.reduce((sum, func) => sum + func[1].split('\n').length, 0) / functions.length 
      : 0;

    if (longFunctions > 0) {
      result.warnings.push(`${longFunctions} functions exceed length threshold of ${rules.maxFunctionLength} lines`);
    }

    // Check for error handling
    if (rules.requireErrorHandling) {
      const errorHandlingPatterns = [
        /pcall\s*\(/g,
        /xpcall\s*\(/g,
        /\berror\s*\(/g
      ];

      let errorHandlingFound = false;
      for (const pattern of errorHandlingPatterns) {
        if (pattern.test(processContent)) {
          errorHandlingFound = true;
          break;
        }
      }

      if (!errorHandlingFound) {
        result.warnings.push("No explicit error handling detected");
      }
    }

    result.metrics.qualityScore = this.calculateQualityScore(result.metrics, longFunctions);
    return result;
  }

  /**
   * Validate process structure
   */
  validateProcessStructure(processContent) {
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      structure: {}
    };

    // Check for proper module structure
    const hasInitialization = /-- Initialize|initialization|setup/i.test(processContent);
    const hasHandlers = /Handlers\.add/g.test(processContent);
    const hasUtilityFunctions = /local\s+function/g.test(processContent);
    const hasConstants = /local\s+[A-Z_]+\s*=/g.test(processContent);

    result.structure = {
      hasInitialization,
      hasHandlers,
      hasUtilityFunctions,
      hasConstants,
      estimatedSections: this.countCodeSections(processContent)
    };

    // Validate structure requirements
    if (!hasHandlers) {
      result.valid = false;
      result.errors.push("Process must have handler registrations");
    }

    if (!hasUtilityFunctions && processContent.length > 10000) {
      result.warnings.push("Large process without utility functions - consider refactoring");
    }

    return result;
  }

  /**
   * Validate performance optimization
   */
  validatePerformanceOptimization(processContent) {
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      optimizations: {}
    };

    // Check for potential performance issues
    const performanceChecks = [
      {
        name: "string_concatenation",
        pattern: /\.\./g,
        threshold: 10,
        warning: "Excessive string concatenation detected - consider using table.concat"
      },
      {
        name: "global_variables",
        pattern: /\b[a-z]\w*\s*=/g,
        threshold: 20,
        warning: "Many global variables detected - prefer local variables"
      },
      {
        name: "nested_loops",
        pattern: /for.*for/gs,
        threshold: 5,
        warning: "Nested loops detected - potential performance concern"
      }
    ];

    for (const check of performanceChecks) {
      const matches = [...processContent.matchAll(check.pattern)];
      result.optimizations[check.name] = matches.length;
      
      if (matches.length > check.threshold) {
        result.warnings.push(`${check.warning} (${matches.length} occurrences)`);
      }
    }

    // Check for optimization indicators
    const hasLocalCaching = /local\s+\w+\s*=\s*\w+\.\w+/.test(processContent);
    const hasTableReuse = /table\.insert|table\.remove/.test(processContent);
    
    result.optimizations.hasLocalCaching = hasLocalCaching;
    result.optimizations.hasTableReuse = hasTableReuse;

    if (!hasLocalCaching && processContent.length > 5000) {
      result.warnings.push("Consider caching frequently accessed globals in local variables");
    }

    return result;
  }

  /**
   * Calculate overall validation score
   */
  calculateValidationScore(validationResults) {
    const weights = {
      size: 20,
      aoCompatibility: 25,
      handlerPatterns: 20,
      adpCompliance: 15,
      securityValidation: 10,
      codeQuality: 10
    };

    let totalScore = 0;
    let totalWeight = 0;

    for (const [category, result] of Object.entries(validationResults)) {
      if (weights[category] && result.valid !== undefined) {
        const categoryScore = result.valid ? 100 : 0;
        totalScore += categoryScore * weights[category];
        totalWeight += weights[category];
      }
    }

    return totalWeight > 0 ? Math.round(totalScore / totalWeight) : 0;
  }

  /**
   * Calculate code quality score
   */
  calculateQualityScore(metrics, longFunctions) {
    let score = 100;
    
    // Penalize high complexity
    if (metrics.estimatedComplexity > 50) {
      score -= Math.min(30, (metrics.estimatedComplexity - 50) * 0.5);
    }
    
    // Penalize long functions
    score -= longFunctions * 5;
    
    // Bonus for reasonable function count
    if (metrics.functionCount > 0 && metrics.functionCount < 20) {
      score += 5;
    }
    
    return Math.max(0, Math.round(score));
  }

  /**
   * Estimate compression potential
   */
  estimateCompressionPotential(content) {
    // Simple heuristic based on repetitive patterns
    const lines = content.split('\n');
    const uniqueLines = new Set(lines);
    const repetitionRatio = 1 - (uniqueLines.size / lines.length);
    
    return Math.round(repetitionRatio * 100);
  }

  /**
   * Count code sections
   */
  countCodeSections(content) {
    const sectionIndicators = [
      /-- Constants/gi,
      /-- Variables/gi,
      /-- Functions/gi,
      /-- Handlers/gi,
      /-- Initialize/gi,
      /-- Utils/gi,
      /-- Helper/gi
    ];

    let sections = 0;
    for (const indicator of sectionIndicators) {
      if (indicator.test(content)) {
        sections++;
      }
    }

    return sections;
  }

  /**
   * Generate validation summary
   */
  getValidationSummary() {
    const total = this.validationResults.length;
    const valid = this.validationResults.filter(r => r.overallValid).length;
    const invalid = total - valid;
    
    const averageScore = total > 0 
      ? this.validationResults.reduce((sum, r) => sum + (r.metrics?.validationScore || 0), 0) / total 
      : 0;

    return {
      total,
      valid,
      invalid,
      successRate: total > 0 ? (valid / total) * 100 : 0,
      averageScore,
      validationResults: this.validationResults
    };
  }

  /**
   * Clear validation results
   */
  clearResults() {
    this.validationResults = [];
  }
}

export { ValidationFramework };