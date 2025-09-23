#!/usr/bin/env node

/**
 * Script to update the main pokemon-species-db.lua process with complete migrated data
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROCESS_FILE = path.join(__dirname, "../processes/pokemon-species-db.lua");
const MIGRATED_DATA_FILE = path.join(__dirname, "../data-migration/species-data.lua");

console.log("Updating process file with complete migrated data...");

// Read the migrated data
const migratedContent = fs.readFileSync(MIGRATED_DATA_FILE, "utf8");

// Extract the SpeciesDatabase from migrated data
const dbMatch = migratedContent.match(/local SpeciesDatabase = \{([\s\S]*)\}[\s]*return SpeciesDatabase/);
if (!dbMatch) {
  throw new Error("Could not extract SpeciesDatabase from migrated data");
}

const speciesDatabaseContent = dbMatch[1];

// Read the current process file
const processContent = fs.readFileSync(PROCESS_FILE, "utf8");

// Replace the SpeciesDatabase section
const processDbPattern =
  /(-- Embedded Species Database.*?\nlocal SpeciesDatabase = \{)([\s\S]*?)(\}[\s\S]*?-- Create optimized indexes)/;
const processMatch = processContent.match(processDbPattern);

if (!processMatch) {
  throw new Error("Could not find SpeciesDatabase section in process file");
}

// Replace with migrated data
const updatedProcessContent = processContent.replace(processDbPattern, `$1${speciesDatabaseContent}$3`);

// Write updated content
fs.writeFileSync(PROCESS_FILE, updatedProcessContent, "utf8");

// Check file size
const stats = fs.statSync(PROCESS_FILE);
const fileSizeKB = Math.round(stats.size / 1024);

console.log("Process file updated successfully!");
console.log(`- File size: ${fileSizeKB}KB`);
console.log(`- Size constraint: 500KB (${((fileSizeKB / 500) * 100).toFixed(1)}% used)`);

if (fileSizeKB > 500) {
  console.warn("⚠️  WARNING: File size exceeds 500KB constraint!");
  console.log("   Need to implement size optimization...");
} else {
  console.log("✅ File size within 500KB constraint");
}
