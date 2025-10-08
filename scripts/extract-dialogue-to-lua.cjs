#!/usr/bin/env node

/**
 * Extract Dialogue Data from TypeScript and Convert to Lua
 *
 * Purpose: Convert src/data/dialogue.ts trainer dialogue to Lua format
 * for embedding in character-dialogue-engine.lua process
 *
 * Story: 19.3 - Character Dialogue Generation Migration
 */

const fs = require('fs');
const path = require('path');

// Read TypeScript enum file
const enumPath = path.join(__dirname, '../src/enums/trainer-type.ts');
const enumContent = fs.readFileSync(enumPath, 'utf-8');

// Extract TrainerType enum
const enumMatch = enumContent.match(/export enum TrainerType\s*{([^}]+)}/);
if (!enumMatch) {
  console.error('Could not extract TrainerType enum');
  process.exit(1);
}

// Parse enum to create name→value mapping
const enumLines = enumMatch[1].split('\n').filter(line => line.trim());
const trainerTypeMap = {};
let enumValue = 0;

enumLines.forEach(line => {
  const trimmed = line.trim().replace(/,$/, '');
  if (!trimmed || trimmed.startsWith('//')) return;

  const parts = trimmed.split('=');
  const name = parts[0].trim();

  if (parts.length > 1) {
    enumValue = parseInt(parts[1].trim());
  }

  trainerTypeMap[name] = enumValue;
  enumValue++;
});

console.log(`Extracted ${Object.keys(trainerTypeMap).length} trainer types from enum`);

// Read dialogue TypeScript file
const dialoguePath = path.join(__dirname, '../src/data/dialogue.ts');
const dialogueContent = fs.readFileSync(dialoguePath, 'utf-8');

// Extract the trainerTypeDialogue object
const dialogueMatch = dialogueContent.match(/export const trainerTypeDialogue: TrainerTypeDialogue = ({[\s\S]*?^};)/m);
if (!dialogueMatch) {
  console.error('Could not find trainerTypeDialogue object');
  process.exit(1);
}

console.log('Successfully extracted dialogue object from TypeScript');

// Parse and convert to Lua
// Since the TS object uses computed properties [TrainerType.NAME], we need to evaluate them
const dialogueObjStr = dialogueMatch[1];

// Step 1: Replace TrainerType.NAME with temporary placeholders
let luaDialogue = dialogueObjStr;

Object.entries(trainerTypeMap).forEach(([name, value]) => {
  const regex = new RegExp(`\\[TrainerType\\.${name}\\]`, 'g');
  luaDialogue = luaDialogue.replace(regex, `___TRAINER_${value}___`);
});

// Step 2: Convert JS arrays [] to Lua tables {}
luaDialogue = luaDialogue
  .replace(/\[/g, '{')
  .replace(/\]/g, '}');

// Step 3: Convert object property syntax to Lua
luaDialogue = luaDialogue
  .replace(/encounter:/g, 'encounter =')
  .replace(/victory:/g, 'victory =')
  .replace(/defeat:/g, 'defeat =');

// Step 4: Restore trainer type keys with proper Lua syntax
Object.entries(trainerTypeMap).forEach(([name, value]) => {
  const regex = new RegExp(`___TRAINER_${value}___`, 'g');
  luaDialogue = luaDialogue.replace(regex, `[${value}]`);
});

// Remove comments (preserving LASS, etc.)
luaDialogue = luaDialogue.replace(/^\s*\/\/.*$/gm, '');

console.log('Converted TypeScript syntax to Lua format');

// Output Lua table
const output = `-- Auto-generated dialogue database
-- Source: src/data/dialogue.ts
-- Generated: ${new Date().toISOString()}
-- Trainer Types: ${Object.keys(trainerTypeMap).length}

local TRAINER_DIALOGUE = ${luaDialogue}

return TRAINER_DIALOGUE
`;

// Write to temporary file for inspection
const outputPath = path.join(__dirname, '../.ai/dialogue-data-lua.txt');
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, output, 'utf-8');

console.log(`\nWrote Lua dialogue data to: ${outputPath}`);
console.log(`File size: ${(output.length / 1024).toFixed(2)} KB`);
console.log('\nNext step: Embed this data in processes/character-dialogue-engine.lua');
