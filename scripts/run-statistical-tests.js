#!/usr/bin/env node

/**
 * Statistical Validation Test Script
 * Executes property-based testing and statistical validation
 * Called by 'npm run test:statistical' command
 */

import chalk from "chalk";
import { PropertyBasedTestingFramework } from "../testing/statistical/property-based-testing.js";

async function main() {
  console.log(chalk.blue.bold("\n🎲 PokéRogue Statistical Validation Testing"));
  console.log(chalk.blue("=".repeat(60)));

  try {
    // Initialize statistical testing framework
    const framework = new PropertyBasedTestingFramework({
      testScenariosDir: "./testing/statistical/scenarios",
      reportsDir: "./testing/reports",
      minIterations: 10000,
      confidenceLevel: 0.95,
      tolerances: {
        probability: 0.02, // ±2% for probability-based outcomes
        damage: 0.05, // ±5% for damage variance calculations
        critical: 0.01, // ±1% for critical hit rates
      },
    });

    // Run comprehensive statistical validation
    const summary = await framework.runPropertyBasedTests();

    // Display results
    console.log(chalk.blue("\n📊 Statistical Validation Results:"));
    console.log(chalk.blue("-".repeat(50)));
    console.log(`Total Tests: ${summary.total}`);
    console.log(chalk.green(`Passed: ${summary.passed}`));
    console.log(chalk.red(`Failed: ${summary.failed}`));
    console.log(chalk.yellow(`Errors: ${summary.errors}`));
    console.log(`Success Rate: ${summary.successRate.toFixed(1)}%`);
    console.log(`Total Iterations: ${summary.totalIterations.toLocaleString()}`);

    // Determine exit code
    if (summary.failed > 0 || summary.errors > 0) {
      console.log(chalk.red("\n❌ Statistical validation FAILED"));
      console.log(chalk.yellow("Some probability distributions do not match expected values"));
      console.log(chalk.yellow("Check detailed reports in ./testing/reports/"));
      process.exit(1);
    } else {
      console.log(chalk.green("\n✅ Statistical validation PASSED"));
      console.log(chalk.green("All probability distributions within expected tolerances"));
    }
  } catch (error) {
    console.error(chalk.red("\n💥 Statistical validation failed:"));
    console.error(chalk.red(error.message));
    if (error.stack) {
      console.error(chalk.gray(error.stack));
    }
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(error => {
    console.error(chalk.red("Unhandled error:"), error);
    process.exit(1);
  });
}

export { main as runStatisticalTests };
