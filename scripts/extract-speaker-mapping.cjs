#!/usr/bin/env node

/**
 * Extract Speaker Name Mapping from Dialogue Data
 *
 * Purpose: Create TRAINER_SPEAKERS mapping from TrainerType to i18n speaker keys
 * Story: 19.3 - Character Dialogue Generation Migration
 */

const fs = require('fs');
const path = require('path');

// Read the dialogue Lua file
const dialoguePath = path.join(__dirname, '../processes/character-dialogue-engine.lua');
const dialogueContent = fs.readFileSync(dialoguePath, 'utf-8');

// Extract all dialogue keys and their trainer type IDs
const speakerMap = {};
const variantMap = {}; // Track which trainers have multiple variants

// More robust regex to capture multi-line trainer blocks
const lines = dialogueContent.split('\n');
let currentTrainerId = null;
let currentVariants = [];
let inVariantBlock = false;
// braceDepth variable removed as unused
let variantDialogueKeys = new Set();

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];

  // Match trainer type declaration: [123]: {
  const trainerMatch = line.match(/^\s*\[(\d+)\]:\s*\{/);
  if (trainerMatch) {
    // Save previous trainer if exists
    if (currentTrainerId !== null && currentVariants.length > 0) {
      speakerMap[currentTrainerId] = currentVariants.length === 1 ? currentVariants[0] : currentVariants;
      if (currentVariants.length > 1) {
        variantMap[currentTrainerId] = currentVariants;
      }
    }

    currentTrainerId = Number.parseInt(trainerMatch[1]);
    currentVariants = [];
    inVariantBlock = false;
    continue;
  }

  if (currentTrainerId === null) {
    continue;
  }

  // Detect variant start: "    {" (4 spaces + opening brace)
  if (line.match(/^\s{4}\{$/)) {
    inVariantBlock = true;
    variantDialogueKeys = new Set();
    continue;
  }

  // Detect variant end: "    }," or "    }" (4 spaces + closing brace)
  if (inVariantBlock && line.match(/^\s{4}\},?$/)) {
    if (variantDialogueKeys.size > 0) {
      // Get the speaker name from the first dialogue key in this variant
      const speakerName = Array.from(variantDialogueKeys)[0];
      currentVariants.push(speakerName);
    }
    inVariantBlock = false;
    variantDialogueKeys = new Set();
    continue;
  }

  // Extract dialogue keys when in a variant block
  if (inVariantBlock) {
    const dialogueMatches = line.matchAll(/"dialogue:([^.]+)\./g);
    for (const match of dialogueMatches) {
      variantDialogueKeys.add(match[1]);
    }
  }

  // Detect non-variant block (direct encounter/victory/defeat): "  encounter ="
  if (line.match(/^\s{2}encounter\s*=/) && !inVariantBlock) {
    // This is a direct dialogue assignment (no variants)
    const dialogueMatches = line.matchAll(/"dialogue:([^.]+)\./g);
    for (const match of dialogueMatches) {
      variantDialogueKeys.add(match[1]);
    }
    // Look ahead for more dialogue keys in this phase
    for (let j = i + 1; j < lines.length; j++) {
      if (lines[j].match(/^\s{2}(victory|defeat)\s*=/)) break;
      if (lines[j].match(/^\s*\[(\d+)\]:/)) break;
      const moreMatches = lines[j].matchAll(/"dialogue:([^.]+)\./g);
      for (const match of moreMatches) {
        variantDialogueKeys.add(match[1]);
      }
    }
    if (variantDialogueKeys.size > 0) {
      currentVariants.push(Array.from(variantDialogueKeys)[0]);
      variantDialogueKeys = new Set();
    }
  }

  // Detect trainer block end: "  }," (2 spaces + closing brace)
  if (line.match(/^\s{2}\},?$/) && currentTrainerId !== null) {
    if (currentVariants.length > 0) {
      speakerMap[currentTrainerId] = currentVariants.length === 1 ? currentVariants[0] : currentVariants;
      if (currentVariants.length > 1) {
        variantMap[currentTrainerId] = currentVariants;
      }
    }
    currentTrainerId = null;
    currentVariants = [];
  }
}

console.log(`Found ${Object.keys(speakerMap).length} trainer types with speaker mappings`);
console.log(`Found ${Object.keys(variantMap).length} trainer types with multiple variants`);

// Generate Lua table
let luaOutput = '-- Auto-generated speaker name mapping\n';
luaOutput += '-- Source: processes/character-dialogue-engine.lua dialogue keys\n';
luaOutput += `-- Generated: ${new Date().toISOString()}\n`;
luaOutput += `-- Trainer Types: ${Object.keys(speakerMap).length}\n\n`;
luaOutput += 'local TRAINER_SPEAKERS = {\n';

// Sort by trainer type ID for readability
const sortedIds = Object.keys(speakerMap).map(Number).sort((a, b) => a - b);

for (const id of sortedIds) {
  const speaker = speakerMap[id];

  if (Array.isArray(speaker)) {
    // Multiple variants
    luaOutput += `  [${id}] = {${speaker.map(s => `"${s}"`).join(', ')}},`;
    luaOutput += ` -- ${speaker.join('/')}\n`;
  } else {
    // Single speaker
    luaOutput += `  [${id}] = "${speaker}",\n`;
  }
}

luaOutput += '}\n\nreturn TRAINER_SPEAKERS\n';

// Write to output file
const outputPath = path.join(__dirname, '../.ai/speaker-mapping-lua.txt');
fs.writeFileSync(outputPath, luaOutput, 'utf-8');

console.log(`\nWrote speaker mapping to: ${outputPath}`);
console.log(`Mapping entries: ${Object.keys(speakerMap).length}`);
console.log('\nSample variants:');
Object.entries(variantMap).slice(0, 5).forEach(([id, speakers]) => {
  console.log(`  [${id}]: ${speakers.join(', ')}`);
});
