/**
 * Comprehensive Test Suite for Enhanced Parity Framework
 * Tests all components of the TypeScript-AO Lua Parity Validation Suite
 */

import { describe, test, expect, beforeEach, afterEach } from '@jest/globals';
import { EnhancedParityTestFramework } from '../testing/parity/enhanced-parity-framework.js';
import { GoldenMasterStorage } from '../testing/parity/golden-master-storage.js';
import { RegressionDetector } from '../testing/parity/regression-detector.js';
import { EquivalenceValidator } from '../testing/parity/equivalence-validator.js';
import { RNGConsistencyTester } from '../testing/parity/rng-consistency-tester.js';
import fs from 'fs/promises';
import path from 'path';

// Test configuration
const TEST_CONFIG = {
  testDir: './test-temp',
  goldenMasterDir: './test-temp/golden-masters',
  reportsDir: './test-temp/reports',
  scenariosDir: './test-temp/scenarios'
};

describe('Enhanced Parity Test Framework', () => {
  let framework;
  let testScenarios;

  beforeEach(async () => {
    // Create test directories
    await fs.mkdir(TEST_CONFIG.testDir, { recursive: true });
    await fs.mkdir(TEST_CONFIG.goldenMasterDir, { recursive: true });
    await fs.mkdir(TEST_CONFIG.reportsDir, { recursive: true });
    await fs.mkdir(TEST_CONFIG.scenariosDir, { recursive: true });

    // Initialize framework
    framework = new EnhancedParityTestFramework({
      goldenMasterDir: TEST_CONFIG.goldenMasterDir,
      reportsDir: TEST_CONFIG.reportsDir,
      testScenariosDir: TEST_CONFIG.scenariosDir,
      enableGoldenMasterMode: true
    });

    // Create test scenarios
    testScenarios = await createTestScenarios();
  });

  afterEach(async () => {
    // Clean up test directories
    try {
      await fs.rm(TEST_CONFIG.testDir, { recursive: true, force: true });
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  describe('Golden Master Testing', () => {
    test('should initialize golden master storage correctly', async () => {
      const storage = new GoldenMasterStorage({
        storageDir: TEST_CONFIG.goldenMasterDir,
        version: '1.10.4'
      });

      await storage.initialize();
      
      // Test directory creation
      const versionDir = path.join(TEST_CONFIG.goldenMasterDir, 'typescript-v1.10.4');
      const dirExists = await fs.access(versionDir).then(() => true).catch(() => false);
      expect(dirExists).toBe(true);
    });

    test('should store and retrieve golden masters', async () => {
      const storage = new GoldenMasterStorage({
        storageDir: TEST_CONFIG.goldenMasterDir,
        version: '1.10.4'
      });
      await storage.initialize();

      const testGoldenMaster = {
        scenarioId: 'test-scenario',
        timestamp: new Date().toISOString(),
        typescriptReference: {
          result: { damage: 100, critical: false },
          metadata: { executionTime: 50 }
        },
        validated: true
      };

      // Store golden master
      const storeResult = await storage.storeGoldenMaster('test-scenario', testGoldenMaster);
      expect(storeResult.scenarioId).toBe('test-scenario');
      expect(storeResult.checksum).toBeDefined();

      // Retrieve golden master
      const retrievedMaster = await storage.loadGoldenMaster('test-scenario');
      expect(retrievedMaster.scenarioId).toBe('test-scenario');
      expect(retrievedMaster.typescriptReference.result.damage).toBe(100);
    });

    test('should validate golden master integrity', async () => {
      const storage = new GoldenMasterStorage({
        storageDir: TEST_CONFIG.goldenMasterDir,
        version: '1.10.4'
      });
      await storage.initialize();

      const testGoldenMaster = {
        scenarioId: 'integrity-test',
        typescriptReference: { result: { value: 42 } },
        validated: true
      };

      await storage.storeGoldenMaster('integrity-test', testGoldenMaster);
      
      const validation = await storage.validateAllMasters();
      expect(validation.valid).toBeGreaterThan(0);
      expect(validation.errors).toHaveLength(0);
    });
  });

  describe('Regression Detection', () => {
    test('should detect functional regressions', async () => {
      const detector = new RegressionDetector({
        reportsDir: TEST_CONFIG.reportsDir,
        goldenMasterDir: TEST_CONFIG.goldenMasterDir
      });
      await detector.initialize();

      const testResults = [
        {
          scenarioId: 'regression-test',
          scenarioName: 'Regression Test Scenario',
          aoResult: {
            result: { damage: 150 }, // Different from expected 100
            metadata: { executionTime: 75 }
          }
        }
      ];

      // Mock golden master
      const mockGoldenMaster = {
        typescriptReference: {
          result: { damage: 100 },
          metadata: { executionTime: 50 }
        }
      };

      // Mock golden master storage
      detector.goldenMasterStorage.loadGoldenMaster = async () => mockGoldenMaster;

      const regressionAnalysis = await detector.detectRegressions(testResults);
      
      expect(regressionAnalysis.summary.hasRegressions).toBe(true);
      expect(regressionAnalysis.regressions).toHaveLength(1);
      expect(regressionAnalysis.regressions[0].hasRegression).toBe(true);
    });

    test('should detect performance regressions', async () => {
      const detector = new RegressionDetector({
        reportsDir: TEST_CONFIG.reportsDir,
        performanceThreshold: 2.0
      });
      await detector.initialize();

      // Establish baseline
      detector.performanceBaselines.set('perf-test', {
        baselineTime: 50,
        samples: [50, 52, 48]
      });

      const testResults = [
        {
          scenarioId: 'perf-test',
          scenarioName: 'Performance Test',
          executionTimes: { ao: 150 } // 3x slower than baseline
        }
      ];

      const regressionAnalysis = await detector.detectRegressions(testResults);
      
      expect(regressionAnalysis.performanceRegressions).toHaveLength(1);
      expect(regressionAnalysis.performanceRegressions[0].hasRegression).toBe(true);
      expect(regressionAnalysis.performanceRegressions[0].severity).toBe('medium');
    });
  });

  describe('Mathematical Equivalence Validation', () => {
    test('should validate exact mathematical equivalence', async () => {
      const validator = new EquivalenceValidator({
        reportsDir: TEST_CONFIG.reportsDir
      });

      const tsResult = {
        result: {
          finalStats: [185, 200, 146, 219, 207, 236],
          statModifiers: [1.0, 1.1, 1.0, 0.9, 1.0, 1.0]
        }
      };

      const aoResult = {
        result: {
          finalStats: [185, 200, 146, 219, 207, 236],
          statModifiers: [1.0, 1.1, 1.0, 0.9, 1.0, 1.0]
        }
      };

      const scenario = {
        id: 'stat-calculation-test',
        name: 'Stat Calculation Test',
        category: 'pokemon_mechanics',
        validationRules: { requiresExactMatch: true }
      };

      const validation = await validator.validateEquivalence(tsResult, aoResult, scenario);
      
      expect(validation.isEquivalent).toBe(true);
      expect(validation.differences).toHaveLength(0);
      expect(validation.precisionScore).toBeCloseTo(1.0);
    });

    test('should detect mathematical differences', async () => {
      const validator = new EquivalenceValidator();

      const tsResult = {
        result: { damage: 100, critical: false }
      };

      const aoResult = {
        result: { damage: 105, critical: false } // 5 point difference
      };

      const scenario = {
        id: 'damage-test',
        name: 'Damage Test',
        category: 'battle',
        tolerances: {}
      };

      const validation = await validator.validateEquivalence(tsResult, aoResult, scenario);
      
      expect(validation.isEquivalent).toBe(false);
      expect(validation.differences).toHaveLength(1);
      expect(validation.differences[0].type).toBe('numeric_difference');
    });

    test('should enforce nature modifier rules', async () => {
      const validator = new EquivalenceValidator();

      const tsResult = {
        result: { statModifiers: [1.0, 1.1, 1.0, 0.9, 1.0, 1.0] }
      };

      const aoResult = {
        result: { statModifiers: [1.0, 1.15, 1.0, 0.85, 1.0, 1.0] } // Invalid modifiers
      };

      const scenario = {
        id: 'nature-test',
        name: 'Nature Modifier Test',
        category: 'pokemon_mechanics'
      };

      const validation = await validator.validateEquivalence(tsResult, aoResult, scenario);
      
      expect(validation.isEquivalent).toBe(false);
      expect(validation.ruleViolations.length).toBeGreaterThan(0);
    });
  });

  describe('RNG Determinism Testing', () => {
    test('should validate RNG consistency', async () => {
      const rngTester = new RNGConsistencyTester({
        reportsDir: TEST_CONFIG.reportsDir,
        minIterations: 5 // Small number for testing
      });

      const scenario = {
        id: 'rng-test',
        name: 'RNG Test',
        rngSeed: 12345,
        testIterations: 5
      };

      // Mock test runner
      const mockTestRunner = {
        executeOnTypeScript: async (scenario) => ({
          result: { damage: 100 + (scenario.rngSeed % 10) }, // Deterministic based on seed
          metadata: { executionTime: 50 }
        }),
        executeOnAO: async (scenario) => ({
          result: { damage: 100 + (scenario.rngSeed % 10) }, // Same as TypeScript
          metadata: { executionTime: 45 }
        })
      };

      const validation = await rngTester.validateRNGDeterminism(scenario, mockTestRunner);
      
      expect(validation.isDeterministic).toBe(true);
      expect(validation.consistency).toBeCloseTo(1.0);
      expect(validation.seedTests).toHaveLength(5);
    });

    test('should detect RNG inconsistencies', async () => {
      const rngTester = new RNGConsistencyTester({
        minIterations: 5
      });

      const scenario = {
        id: 'rng-inconsistent-test',
        rngSeed: 12345,
        testIterations: 5
      };

      // Mock test runner with inconsistent results
      const mockTestRunner = {
        executeOnTypeScript: async (scenario) => ({
          result: { damage: 100 + (scenario.rngSeed % 10) },
          metadata: { executionTime: 50 }
        }),
        executeOnAO: async (scenario) => ({
          result: { damage: 120 + (scenario.rngSeed % 15) }, // Different formula
          metadata: { executionTime: 45 }
        })
      };

      const validation = await rngTester.validateRNGDeterminism(scenario, mockTestRunner);
      
      expect(validation.isDeterministic).toBe(false);
      expect(validation.consistency).toBeLessThan(0.95);
      expect(validation.issues.length).toBeGreaterThan(0);
    });
  });

  describe('Comprehensive Validation Flow', () => {
    test('should execute complete enhanced parity validation', async () => {
      // Create mock test scenarios
      const scenarios = [
        {
          id: 'comprehensive-test-1',
          name: 'Comprehensive Test 1',
          category: 'pokemon_mechanics',
          scenarioType: 'golden_master',
          inputGameState: {
            pokemon: {
              species: 'Charizard',
              level: 50,
              nature: 'Adamant'
            }
          },
          expectedOutput: {
            finalStats: [185, 200, 146, 219, 207, 236]
          },
          tolerances: {}
        }
      ];

      // Write scenarios to file
      for (const scenario of scenarios) {
        const scenarioPath = path.join(TEST_CONFIG.scenariosDir, `${scenario.id}.json`);
        await fs.writeFile(scenarioPath, JSON.stringify(scenario, null, 2));
      }

      // Mock framework methods for testing
      framework.executeOnTypeScript = async (scenario) => ({
        result: scenario.expectedOutput,
        metadata: { executionTime: 50 }
      });

      framework.executeOnAO = async (scenario) => ({
        result: scenario.expectedOutput,
        metadata: { executionTime: 45 }
      });

      // Run comprehensive validation
      const results = await framework.runComprehensiveValidation();
      
      expect(results.total).toBe(1);
      expect(results.passed).toBe(1);
      expect(results.successRate).toBe(100);
    });
  });

  describe('Error Handling', () => {
    test('should handle missing golden masters gracefully', async () => {
      const storage = new GoldenMasterStorage({
        storageDir: TEST_CONFIG.goldenMasterDir
      });
      await storage.initialize();

      const nonExistentMaster = await storage.loadGoldenMaster('non-existent');
      expect(nonExistentMaster).toBeNull();
    });

    test('should handle corrupted test data', async () => {
      const validator = new EquivalenceValidator();

      const invalidTsResult = null;
      const validAoResult = { result: { damage: 100 } };
      const scenario = { id: 'error-test', name: 'Error Test' };

      await expect(
        validator.validateEquivalence(invalidTsResult, validAoResult, scenario)
      ).resolves.toMatchObject({
        isEquivalent: false,
        error: expect.any(String)
      });
    });
  });

  describe('Performance Validation', () => {
    test('should measure and compare execution times', async () => {
      const framework = new EnhancedParityTestFramework({
        enablePerformanceComparison: true
      });

      const scenario = {
        id: 'performance-test',
        name: 'Performance Test'
      };

      // Mock execution with timing
      framework.executeOnTypeScript = async () => {
        await new Promise(resolve => setTimeout(resolve, 10)); // 10ms delay
        return { result: { value: 42 }, metadata: { executionTime: 10 } };
      };

      framework.executeOnAO = async () => {
        await new Promise(resolve => setTimeout(resolve, 5)); // 5ms delay
        return { result: { value: 42 }, metadata: { executionTime: 5 } };
      };

      const performanceResults = await framework.runPerformanceComparison([scenario]);
      
      expect(performanceResults).toHaveLength(1);
      expect(performanceResults[0].speedRatio).toBeLessThan(1.0); // AO is faster
    });
  });
});

// Helper function to create test scenarios
async function createTestScenarios() {
  return [
    {
      id: 'pokemon-stat-calculation',
      name: 'Pokemon Stat Calculation',
      category: 'pokemon_mechanics',
      scenarioType: 'golden_master',
      inputGameState: {
        pokemon: {
          species: 'Charizard',
          level: 50,
          nature: 'Adamant',
          baseStats: { hp: 78, attack: 84, defense: 78, spAttack: 109, spDefense: 85, speed: 100 },
          ivs: { hp: 31, attack: 31, defense: 31, spAttack: 31, spDefense: 31, speed: 31 },
          evs: { hp: 0, attack: 252, defense: 0, spAttack: 0, spDefense: 6, speed: 252 }
        }
      },
      expectedOutput: {
        finalStats: [185, 200, 146, 219, 207, 236],
        statModifiers: [1.0, 1.1, 1.0, 0.9, 1.0, 1.0]
      },
      tolerances: {},
      validationRules: { requiresExactMatch: true }
    },
    {
      id: 'battle-damage-calculation',
      name: 'Battle Damage Calculation',
      category: 'battle',
      scenarioType: 'randomization',
      inputGameState: {
        battle: {
          attacker: { species: 'Pikachu', level: 50, stats: { attack: 120 } },
          defender: { species: 'Gyarados', level: 50, stats: { defense: 100 }, types: ['water', 'flying'] },
          move: { name: 'Thunderbolt', type: 'electric', power: 90 },
          rng: { damageRoll: 0.85 }
        }
      },
      expectedOutput: {
        damage: 156,
        effectiveness: 4.0,
        critical: false
      },
      tolerances: { damage: 0 },
      rngSeed: 12345,
      requiresStatisticalAnalysis: true
    }
  ];
}