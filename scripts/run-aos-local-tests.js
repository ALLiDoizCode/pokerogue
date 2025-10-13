#!/usr/bin/env node

/**
 * Enhanced aos-local Integration Test Script
 * Executes comprehensive integration testing with multi-process deployment validation
 * Called by 'npm run test:aos-local' command
 */

import { AosLocalIntegrationFramework } from "../testing/aos-local/integration-test-framework.js";

// Simple color helpers (replacing chalk)
const colors = {
  blue: text => `\x1b[34m${text}\x1b[0m`,
  green: text => `\x1b[32m${text}\x1b[0m`,
  red: text => `\x1b[31m${text}\x1b[0m`,
  yellow: text => `\x1b[33m${text}\x1b[0m`,
  gray: text => `\x1b[90m${text}\x1b[0m`,
  bold: text => `\x1b[1m${text}\x1b[0m`,
};

async function main() {
  console.log(colors.bold(colors.blue("\n🚀 PokéRogue aos-local Integration Testing")));
  console.log(colors.blue("=".repeat(60)));

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
    console.log(colors.blue("\n📊 aos-local Integration Test Results:"));
    console.log(colors.blue("-".repeat(50)));
    console.log(`Total Tests: ${summary.total}`);
    console.log(colors.green(`Passed: ${summary.passed}`));
    console.log(colors.red(`Failed: ${summary.failed}`));
    console.log(colors.yellow(`Errors: ${summary.errors}`));
    console.log(`Success Rate: ${summary.successRate.toFixed(1)}%`);
    console.log(`Total Duration: ${summary.totalDuration}ms`);

    // Determine exit code
    if (summary.failed > 0 || summary.errors > 0) {
      console.log(colors.red("\n❌ aos-local integration tests FAILED"));
      console.log(colors.yellow("Check detailed reports in ./testing/reports/"));
      process.exit(1);
    } else {
      console.log(colors.green("\n✅ aos-local integration tests PASSED"));
      console.log(colors.green("All processes deployed and communicating successfully"));
    }
  } catch (error) {
    console.error(colors.red("\n💥 aos-local integration testing failed:"));
    console.error(colors.red(error.message));
    if (error.stack) {
      console.error(colors.gray(error.stack));
    }
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(error => {
    console.error(colors.red("Unhandled error:"), error);
    process.exit(1);
  });
}

export { main as runAosLocalTests };
