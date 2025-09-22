#!/usr/bin/env node

/**
 * Enhanced aos-local Integration Test Script
 * Executes comprehensive integration testing with multi-process deployment validation
 * Called by 'npm run test:aos-local' command
 */

import chalk from "chalk";
import { AosLocalIntegrationFramework } from "../testing/aos-local/integration-test-framework.js";

async function main() {
  console.log(chalk.blue.bold("\n🚀 PokéRogue aos-local Integration Testing"));
  console.log(chalk.blue("=".repeat(60)));

  try {
    // Initialize integration testing framework
    const framework = new AosLocalIntegrationFramework({
      processesDir: "./processes",
      testScenariosDir: "./testing/aos-local/scenarios",
      reportsDir: "./testing/reports",
      tempDir: "./testing/aos-local/temp",
    });

    // Run comprehensive integration tests
    const summary = await framework.runIntegrationTests();

    // Display results
    console.log(chalk.blue("\n📊 aos-local Integration Test Results:"));
    console.log(chalk.blue("-".repeat(50)));
    console.log(`Total Tests: ${summary.total}`);
    console.log(chalk.green(`Passed: ${summary.passed}`));
    console.log(chalk.red(`Failed: ${summary.failed}`));
    console.log(chalk.yellow(`Errors: ${summary.errors}`));
    console.log(`Success Rate: ${summary.successRate.toFixed(1)}%`);
    console.log(`Total Duration: ${summary.totalDuration}ms`);

    // Determine exit code
    if (summary.failed > 0 || summary.errors > 0) {
      console.log(chalk.red("\n❌ aos-local integration tests FAILED"));
      console.log(chalk.yellow("Check detailed reports in ./testing/reports/"));
      process.exit(1);
    } else {
      console.log(chalk.green("\n✅ aos-local integration tests PASSED"));
      console.log(chalk.green("All processes deployed and communicating successfully"));
    }
  } catch (error) {
    console.error(chalk.red("\n💥 aos-local integration testing failed:"));
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

export { main as runAosLocalTests };
