#!/usr/bin/env node

/**
 * Enhanced Parity Test Script
 * Executes comprehensive parity validation between TypeScript and AO implementations
 * Called by 'npm run test:parity' command
 */

import { exec } from "child_process";
import { promisify } from "util";
import chalk from "chalk";
import { ParityTestFramework } from "../testing/parity/parity-test-framework.js";

const execAsync = promisify(exec);

async function main() {
  console.log(chalk.blue.bold("\n🚀 PokéRogue TypeScript ↔ AO Lua Parity Testing"));
  console.log(chalk.blue("=".repeat(60)));

  try {
    // Initialize parity test framework
    const framework = new ParityTestFramework({
      typescriptDir: "./typescript-reference",
      aoProcessesDir: "./processes",
      testScenariosDir: "./testing/parity/scenarios",
      reportsDir: "./testing/reports",
    });

    // Run comprehensive parity tests
    const summary = await framework.runParityTests();

    // Display results
    console.log(chalk.blue("\n📊 Parity Test Results Summary:"));
    console.log(chalk.blue("-".repeat(40)));
    console.log(`Total Tests: ${summary.total}`);
    console.log(chalk.green(`Passed: ${summary.passed}`));
    console.log(chalk.red(`Failed: ${summary.failed}`));
    console.log(chalk.yellow(`Errors: ${summary.errors}`));
    console.log(`Success Rate: ${summary.successRate.toFixed(1)}%`);

    // Determine exit code
    if (summary.failed > 0 || summary.errors > 0) {
      console.log(chalk.red("\n❌ Parity validation FAILED"));
      console.log(chalk.yellow("Check detailed reports in ./testing/reports/"));
      process.exit(1);
    } else {
      console.log(chalk.green("\n✅ Parity validation PASSED"));
      console.log(chalk.green("All implementations maintain functional equivalence"));
    }
  } catch (error) {
    console.error(chalk.red("\n💥 Parity testing failed with error:"));
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

export { main as runParityTests };
