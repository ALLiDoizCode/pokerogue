#!/usr/bin/env node

/**
 * Performance Benchmarking Test Script
 * Executes comprehensive performance comparison between TypeScript and AO implementations
 */

import chalk from "chalk";
import { PerformanceBenchmarkFramework } from "../testing/performance/benchmark-framework.js";

async function main() {
  console.log(chalk.blue.bold("\n⚡ PokéRogue Performance Benchmarking"));
  console.log(chalk.blue("=".repeat(50)));

  try {
    // Initialize performance benchmarking framework
    const framework = new PerformanceBenchmarkFramework({
      typescriptDir: "./typescript-reference",
      aoProcessesDir: "./processes",
      reportsDir: "./testing/reports",
    });

    // Run comprehensive performance benchmarks
    const summary = await framework.runPerformanceBenchmarks();

    // Display results
    console.log(chalk.blue("\n📊 Performance Benchmark Results:"));
    console.log(chalk.blue("-".repeat(40)));
    console.log(`Total Benchmarks: ${summary.totalBenchmarks}`);
    console.log(`Average Speedup: ${summary.avgSpeedup.toFixed(2)}x`);
    console.log(chalk.green(`AO Faster: ${summary.aoFasterCount}`));
    console.log(chalk.yellow(`TypeScript Faster: ${summary.typescriptFasterCount}`));
    console.log(`Total Iterations: ${summary.totalIterations.toLocaleString()}`);

    // Performance verdict
    if (summary.avgSpeedup > 1.1) {
      console.log(chalk.green("\n✅ AO implementation meets performance requirements"));
      console.log(chalk.green("AO processes outperform TypeScript reference"));
    } else if (summary.avgSpeedup > 0.9) {
      console.log(chalk.yellow("\n⚠️  AO implementation has comparable performance"));
      console.log(chalk.yellow("Performance is within acceptable range"));
    } else {
      console.log(chalk.red("\n❌ AO implementation underperforms"));
      console.log(chalk.red("Performance optimization required"));
      process.exit(1);
    }
  } catch (error) {
    console.error(chalk.red("\n💥 Performance benchmarking failed:"));
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

export { main as runPerformanceTests };
