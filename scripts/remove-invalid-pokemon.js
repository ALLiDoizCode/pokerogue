#!/usr/bin/env node

/**
 * Remove Invalid Pokemon Entries Script
 * Removes Pokemon IDs 1026-1081 which are placeholder data not in the actual game
 * Purpose: Clean up database to only include real Pokemon (1-1025)
 */

import fs from 'fs';

const MAIN_PROCESS_FILE = 'processes/pokemon-species-db.lua';

console.log('🔧 Starting Invalid Pokemon Cleanup...');

// Read the main process file
console.log('📂 Reading main process file...');
let processContent = fs.readFileSync(MAIN_PROCESS_FILE, 'utf8');

// Count current invalid entries
const invalidEntries = processContent.match(/\[10[2-7][0-9]\] = \{[\s\S]*?\},/g) || [];
const undefinedCount = (processContent.match(/n = "undefined"/g) || []).length;

console.log(`🔍 Found ${invalidEntries.length} entries with IDs 1026-1081`);
console.log(`🔍 Found ${undefinedCount} undefined names total`);

// Remove entries with IDs 1026-1081 (these are invalid placeholder data)
console.log('🗑️  Removing invalid entries...');

// Remove the invalid entries
processContent = processContent.replace(/,\s*\[10[2-8][0-9]\] = \{[\s\S]*?\}/g, '');

// Update metadata to reflect the correct count
const finalSpeciesCount = 1025; // Pecharunt is #1025, the last real Pokemon

processContent = processContent
    .replace(/totalSpecies = 1082/g, `totalSpecies = ${finalSpeciesCount}`)
    .replace(/expectedSpecies = 1082/g, `expectedSpecies = ${finalSpeciesCount}`)
    .replace(/-- Total Species: 1082/g, `-- Total Species: ${finalSpeciesCount}`)
    .replace(/description = "Complete Pokemon species database with all 1082 species/g, 
             `description = "Complete Pokemon species database with all ${finalSpeciesCount} species`);

// Write the updated file
fs.writeFileSync(MAIN_PROCESS_FILE, processContent);

// Verify the changes
const updatedContent = fs.readFileSync(MAIN_PROCESS_FILE, 'utf8');
const remainingInvalid = (updatedContent.match(/\[10[2-8][0-9]\] = \{/g) || []).length;
const remainingUndefined = (updatedContent.match(/n = "undefined"/g) || []).length;

console.log('\n📊 Cleanup Results:');
console.log(`Before: ${invalidEntries.length} invalid entries, ${undefinedCount} undefined names`);
console.log(`After: ${remainingInvalid} invalid entries, ${remainingUndefined} undefined names`);
console.log(`Removed: ${invalidEntries.length - remainingInvalid} invalid entries`);

// Check final file size
const finalStats = fs.statSync(MAIN_PROCESS_FILE);
const finalSizeKB = (finalStats.size / 1024).toFixed(2);
const percentOfLimit = ((finalStats.size / (500 * 1024)) * 100).toFixed(1);

console.log(`📁 Final file size: ${finalSizeKB} KB (${percentOfLimit}% of 500KB limit)`);

if (remainingInvalid === 0 && remainingUndefined === 0) {
    console.log('🎉 All invalid entries and undefined names removed!');
    console.log(`✅ Clean database with ${finalSpeciesCount} real Pokemon only`);
} else {
    console.log(`⚠️  ${remainingInvalid + remainingUndefined} entries still need attention`);
}

console.log(`\n📁 Updated file: ${MAIN_PROCESS_FILE}`);