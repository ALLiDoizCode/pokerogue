#!/usr/bin/env node

/**
 * Extract Speaker Name Mapping from Dialogue Data (V2 - Simplified)
 *
 * Purpose: Create TRAINER_SPEAKERS mapping from TrainerType to i18n speaker keys
 * Story: 19.3 - Character Dialogue Generation Migration
 *
 * Strategy: Parse the entire TRAINER_DIALOGUE table and extract speakers per trainer/variant
 */

const fs = require("fs");
const path = require("path");

// Read the dialogue Lua file
const dialoguePath = path.join(__dirname, "../processes/character-dialogue-engine.lua");
const dialogueContent = fs.readFileSync(dialoguePath, "utf-8");

// Find the TRAINER_DIALOGUE table boundaries
const tableStart = dialogueContent.indexOf("local TRAINER_DIALOGUE = {");
const tableEnd = dialogueContent.indexOf("};", tableStart);
const tableContent = dialogueContent.substring(tableStart, tableEnd + 2);

// Extract trainer blocks: [ID]: { ... }
const speakerMap = {};
const variantMap = {};

// Split into lines for processing
const lines = tableContent.split("\n");
let currentId = null;
let currentVariants = [];
let currentVariantSpeakers = new Set();
let inVariant = false;
// indentLevel removed as unused

for (const line of lines) {
  // Detect trainer ID: [123]: {
  const idMatch = line.match(/^\s*\[(\d+)\]:/);
  if (idMatch) {
    // Save previous trainer
    if (currentId !== null && currentVariants.length > 0) {
      speakerMap[currentId] = currentVariants.length === 1 ? currentVariants[0] : currentVariants;
      if (currentVariants.length > 1) {
        variantMap[currentId] = currentVariants;
      }
    }

    currentId = Number.parseInt(idMatch[1]);
    currentVariants = [];
    currentVariantSpeakers = new Set();
    inVariant = false;
    continue;
  }

  if (!currentId) {
    continue;
  }

  // Detect variant start: 4-space indent + {
  if (line.match(/^\s{4}\{$/)) {
    inVariant = true;
    currentVariantSpeakers = new Set();
    continue;
  }

  // Detect variant end: 4-space indent + },
  if (line.match(/^\s{4}\},?\s*$/)) {
    if (currentVariantSpeakers.size > 0) {
      currentVariants.push(Array.from(currentVariantSpeakers)[0]);
    }
    inVariant = false;
    currentVariantSpeakers = new Set();
    continue;
  }

  // Detect direct encounter (no variant wrapper): 2-space indent + encounter =
  if (line.match(/^\s{2}encounter\s*=/)) {
    currentVariantSpeakers = new Set();
    const matches = [...line.matchAll(/"dialogue:([^.]+)\./g)];
    for (const m of matches) {
      currentVariantSpeakers.add(m[1]);
    }

    // Look ahead for more speakers on subsequent lines
    const nextLineIdx = lines.indexOf(line) + 1;
    for (let i = nextLineIdx; i < lines.length; i++) {
      const nextLine = lines[i];
      if (nextLine.match(/^\s{2}(victory|defeat)\s*=/)) {
        break;
      }
      if (nextLine.match(/^\s*\[(\d+)\]:/)) {
        break;
      }

      const nextMatches = [...nextLine.matchAll(/"dialogue:([^.]+)\./g)];
      for (const m of nextMatches) {
        currentVariantSpeakers.add(m[1]);
      }
    }

    if (currentVariantSpeakers.size > 0) {
      currentVariants.push(Array.from(currentVariantSpeakers)[0]);
      currentVariantSpeakers = new Set();
    }
    continue;
  }

  // Extract speakers from current line if in variant
  if (inVariant) {
    const speakerMatches = [...line.matchAll(/"dialogue:([^.]+)\./g)];
    for (const m of speakerMatches) {
      currentVariantSpeakers.add(m[1]);
    }
  }
}

// Save last trainer
if (currentId !== null && currentVariants.length > 0) {
  speakerMap[currentId] = currentVariants.length === 1 ? currentVariants[0] : currentVariants;
  if (currentVariants.length > 1) {
    variantMap[currentId] = currentVariants;
  }
}

console.log(`Found ${Object.keys(speakerMap).length} trainer types with speaker mappings`);
console.log(`Found ${Object.keys(variantMap).length} trainer types with multiple variants`);

// Generate Lua table
let luaOutput = "-- Auto-generated speaker name mapping\n";
luaOutput += "-- Source: processes/character-dialogue-engine.lua dialogue keys\n";
luaOutput += `-- Generated: ${new Date().toISOString()}\n`;
luaOutput += `-- Trainer Types: ${Object.keys(speakerMap).length}\n\n`;
luaOutput += "local TRAINER_SPEAKERS = {\n";

// Sort by trainer type ID
const sortedIds = Object.keys(speakerMap)
  .map(Number)
  .sort((a, b) => a - b);

for (const id of sortedIds) {
  const speaker = speakerMap[id];

  if (Array.isArray(speaker)) {
    luaOutput += `  [${id}] = {${speaker.map(s => `"${s}"`).join(", ")}},`;
    luaOutput += ` -- ${speaker.join("/")}\n`;
  } else {
    luaOutput += `  [${id}] = "${speaker}",\n`;
  }
}

luaOutput += "}\n\nreturn TRAINER_SPEAKERS\n";

// Write to output file
const outputPath = path.join(__dirname, "../.ai/speaker-mapping-lua.txt");
fs.writeFileSync(outputPath, luaOutput, "utf-8");

console.log(`\nWrote speaker mapping to: ${outputPath}`);
console.log(`Mapping entries: ${Object.keys(speakerMap).length}`);
console.log("\nSample variants:");
Object.entries(variantMap)
  .slice(0, 10)
  .forEach(([id, speakers]) => {
    console.log(`  [${id}]: ${speakers.join(", ")}`);
  });
