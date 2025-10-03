#!/usr/bin/env node

/**
 * Enhanced Parity Test Script
 * Executes comprehensive parity validation between TypeScript and AO implementations
 * Called by 'npm run test:parity' command
 */

import { exec } from "child_process";
import { promisify } from "util";
import { ParityTestFramework } from "../testing/parity/parity-test-framework.js";

const _execAsync = promisify(exec);

// Simple color helpers (replacing chalk)
const colors = {
  blue: (text) => `\x1b[34m${text}\x1b[0m`,
  green: (text) => `\x1b[32m${text}\x1b[0m`,
  red: (text) => `\x1b[31m${text}\x1b[0m`,
  yellow: (text) => `\x1b[33m${text}\x1b[0m`,
  gray: (text) => `\x1b[90m${text}\x1b[0m`,
  bold: (text) => `\x1b[1m${text}\x1b[0m`
};

async function main() {
  console.log(colors.bold(colors.blue("\n🚀 PokéRogue TypeScript ↔ AO Lua Parity Testing")));
  console.log(colors.blue("=".repeat(60)));

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
    console.log(colors.blue("\n📊 Parity Test Results Summary:"));
    console.log(colors.blue("-".repeat(40)));
    console.log(`Total Tests: ${summary.total}`);
    console.log(colors.green(`Passed: ${summary.passed}`));
    console.log(colors.red(`Failed: ${summary.failed}`));
    console.log(colors.yellow(`Errors: ${summary.errors}`));
    console.log(`Success Rate: ${summary.successRate.toFixed(1)}%`);

    // Determine exit code
    if (summary.failed > 0 || summary.errors > 0) {
      console.log(colors.red("\n❌ Parity validation FAILED"));
      console.log(colors.yellow("Check detailed reports in ./testing/reports/"));
      process.exit(1);
    } else {
      console.log(colors.green("\n✅ Parity validation PASSED"));
      console.log(colors.green("All implementations maintain functional equivalence"));
    }
  } catch (error) {
    console.error(colors.red("\n💥 Parity testing failed with error:"));
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

export { main as runParityTests };
