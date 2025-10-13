/**
 * Shared test utilities and helpers
 * Provides common functionality for test files
 */

// Import classes from test files that need to be shared
import {
  DeploymentTestRunner,
  IntegrationEnvironmentConfig,
  ProcessDeployer,
  ValidationFramework,
} from "../integration/deployment-validation.test.js";
import { ScenarioExecutor, scenarioConfigs, testScenarios } from "../integration/end-to-end-scenarios.test.js";
import { createMockDataSources } from "../integration/external-data-access.test.js";
import { PerformanceMonitor, performanceBaselines } from "../integration/performance-benchmarks.test.js";
import { RecoveryTester, recoveryScenarios } from "../integration/recovery-scenarios.test.js";

// Re-export for shared use
export {
  DeploymentTestRunner,
  ProcessDeployer,
  ValidationFramework,
  IntegrationEnvironmentConfig,
  ScenarioExecutor,
  testScenarios,
  scenarioConfigs,
  createMockDataSources,
  PerformanceMonitor,
  performanceBaselines,
  RecoveryTester,
  recoveryScenarios,
};
