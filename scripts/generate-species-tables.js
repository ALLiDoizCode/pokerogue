#!/usr/bin/env node
/**
 * Generate Species Tables for Egg Tier Reward Engine
 *
 * Simplified approach: Extract species data directly from TypeScript files
 * and generate Lua tables without parsing the complex enum structure.
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read source files
const tierFile = fs.readFileSync(path.join(__dirname, "../src/data/balance/species-egg-tiers.ts"), "utf8");
const starterFile = fs.readFileSync(path.join(__dirname, "../src/data/balance/starters.ts"), "utf8");

console.log("🔍 Extracting species data from TypeScript files...\n");

// Extract species from speciesEggTiers (authoritative order)
const tierLines = tierFile.split("\n");
const speciesOrder = [];
const tierMap = {};

for (const line of tierLines) {
  const match = line.match(/\[SpeciesId\.(\w+)\]:\s*EggTier\.(\w+)/);
  if (match) {
    const [, speciesName, tier] = match;
    speciesOrder.push(speciesName);
    tierMap[speciesName] = tier;
  }
}

console.log(`✅ Found ${speciesOrder.length} species with tier mappings`);

// Extract starter costs
const starterLines = starterFile.split("\n");
const costMap = {};

for (const line of starterLines) {
  const match = line.match(/\[SpeciesId\.(\w+)\]:\s*(\d+)/);
  if (match) {
    const [, speciesName, cost] = match;
    costMap[speciesName] = Number.parseInt(cost);
  }
}

console.log(`✅ Found ${Object.keys(costMap).length} species with starter costs\n`);

// Now we need to get the actual numeric IDs from the enum
// We'll parse the enum file to build the mapping
const enumFile = fs.readFileSync(path.join(__dirname, "../src/enums/species-id.ts"), "utf8");
const speciesIdMap = {};

// Extract enum body
const enumMatch = enumFile.match(/export enum SpeciesId\s*\{([\s\S]*?)\n\}/);
if (!enumMatch) {
  throw new Error("Could not find SpeciesId enum");
}

const enumBody = enumMatch[1];
const enumLines = enumBody.split("\n");

let currentId = 0;
for (const line of enumLines) {
  // Skip comments and empty lines
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("/**") || trimmed.startsWith("*") || trimmed.startsWith("//")) {
    continue;
  }

  // Match: SPECIES_NAME = number or SPECIES_NAME,
  const explicitMatch = trimmed.match(/^(\w+)\s*=\s*(\d+)/);
  const implicitMatch = trimmed.match(/^(\w+)\s*[,]?/);

  if (explicitMatch) {
    const [, name, id] = explicitMatch;
    currentId = Number.parseInt(id);
    speciesIdMap[name] = currentId;
    currentId++;
  } else if (implicitMatch) {
    const [, name] = implicitMatch;
    speciesIdMap[name] = currentId;
    currentId++;
  }
}

console.log(`✅ Parsed ${Object.keys(speciesIdMap).length} species ID mappings from enum\n`);

// Generate Lua tables using numeric IDs
console.log("📝 Generating Lua tables...\n");

const luaEntries = [];
const luaCostEntries = [];

for (const speciesName of speciesOrder) {
  const speciesId = speciesIdMap[speciesName];
  const tier = tierMap[speciesName];
  const cost = costMap[speciesName];

  if (speciesId !== undefined && tier) {
    luaEntries.push(`  [${speciesId}] = EggTier.${tier},  -- ${speciesName}`);
  }

  if (speciesId !== undefined && cost !== undefined) {
    luaCostEntries.push(`  [${speciesId}] = ${cost},  -- ${speciesName}`);
  }
}

// Generate complete Lua file
const output = `--[[
  Species Tables for Egg Tier Reward Engine
  Auto-generated from TypeScript source files

  Generated: ${new Date().toISOString()}
  Species Count: ${luaEntries.length} tiers, ${luaCostEntries.length} costs
]]

-- EggTier constants (for reference)
local EggTier = {
  COMMON = 0,
  RARE = 1,
  EPIC = 2,
  LEGENDARY = 3
}

-- ============================================================================
-- SPECIES EGG TIERS (${luaEntries.length} species)
-- ============================================================================
local speciesEggTiers = {
${luaEntries.join("\n")}
}

-- ============================================================================
-- SPECIES STARTER COSTS (${luaCostEntries.length} species)
-- ============================================================================
local speciesStarterCosts = {
${luaCostEntries.join("\n")}
}

return {
  speciesEggTiers = speciesEggTiers,
  speciesStarterCosts = speciesStarterCosts
}
`;

// Write output
const outputPath = path.join(__dirname, "../processes/species-tables.lua");
fs.writeFileSync(outputPath, output);

const sizeKB = (output.length / 1024).toFixed(2);
console.log("✅ Generated species tables:");
console.log(`   📊 speciesEggTiers: ${luaEntries.length} entries`);
console.log(`   💰 speciesStarterCosts: ${luaCostEntries.length} entries`);
console.log(`   📄 Output: ${outputPath}`);
console.log(`   📏 File size: ${sizeKB} KB`);
console.log("\n✅ Species table generation complete!");
