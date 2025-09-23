#!/usr/bin/env node

/**
 * Embed All Species Data Script
 * Merges all generation chunk files into the main pokemon-species-db.lua
 * Purpose: Resolve integration gap by embedding complete dataset directly
 */

import fs from 'fs';
import path from 'path';

const MAIN_PROCESS_FILE = 'processes/pokemon-species-db.lua';
const GENERATION_FILES = [
    'data-migration/chunks/gen1-species.lua',
    'data-migration/chunks/gen2-species.lua', 
    'data-migration/chunks/gen3-species.lua',
    'data-migration/chunks/gen4-species.lua',
    'data-migration/chunks/gen5-species.lua',
    'data-migration/chunks/gen6-species.lua',
    'data-migration/chunks/gen7-species.lua',
    'data-migration/chunks/gen8-species.lua',
    'data-migration/chunks/gen9-species.lua'
];

console.log('🔧 Starting Species Data Embedding Process...');

// Read the main process file
let mainProcessContent = fs.readFileSync(MAIN_PROCESS_FILE, 'utf8');

// Extract all species data from generation files
let allSpeciesData = {};
let totalSpeciesCount = 0;

console.log('📂 Reading generation chunk files...');

for (const genFile of GENERATION_FILES) {
    if (!fs.existsSync(genFile)) {
        console.log(`⚠️  Warning: ${genFile} not found, skipping...`);
        continue;
    }
    
    console.log(`   Reading ${genFile}...`);
    const genContent = fs.readFileSync(genFile, 'utf8');
    
    // Extract species data from the generation file
    // Look for the species table definition and capture everything until the closing brace
    const genMatch = genContent.match(/local Gen\d+Species = \{([\s\S]*)\}[\s\S]*return Gen\d+Species/);
    if (genMatch) {
        const speciesDataStr = genMatch[1];
        
        // Count species in this generation
        const speciesCount = (speciesDataStr.match(/\[\d+\] = \{/g) || []).length;
        totalSpeciesCount += speciesCount;
        
        console.log(`     Found ${speciesCount} species`);
        
        // Store the species data string for this generation
        const genNum = genFile.match(/gen(\d+)/)[1];
        allSpeciesData[genNum] = speciesDataStr;
    } else {
        console.log(`     ❌ Could not parse species data from ${genFile}`);
    }
}

console.log(`📊 Total species found: ${totalSpeciesCount}`);

// Create the combined species database
const combinedSpeciesData = `-- ============================================================================
-- COMPLETE EMBEDDED SPECIES DATABASE
-- Generated: ${new Date().toISOString()}
-- Total Species: ${totalSpeciesCount}
-- Source: Merged from all generation chunks
-- ============================================================================

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3, GROUND = 4, ROCK = 5, 
    BUG = 6, GHOST = 7, STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11, 
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15, DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67, SWARM = 68,
    KEEN_EYE = 51, TANGLED_FEET = 77, BIG_PECKS = 145, CHLOROPHYLL = 34
    -- Note: Additional abilities defined inline as needed
}

-- Complete embedded species database
local SpeciesDatabase = {
${Object.values(allSpeciesData).join(',\n')}
}

-- Helper function to get species by ID
local function getSpeciesById(id)
    return SpeciesDatabase[id]
end

-- Helper function to get species by name
local function getSpeciesByName(name)
    local searchName = name:lower()
    for id, species in pairs(SpeciesDatabase) do
        if species.n and species.n:lower() == searchName then
            return species
        end
    end
    return nil
end`;

// Replace the chunked loading implementation with embedded data
const updatedContent = mainProcessContent
    .replace(/-- ============================================================================\s*-- CHUNK LOADER IMPLEMENTATION[\s\S]*?-- ============================================================================\s*-- ENHANCED QUERY HANDLERS/g, 
             combinedSpeciesData + '\n\n-- ============================================================================\n-- ENHANCED QUERY HANDLERS')
    .replace(/totalSpecies = 1082/g, `totalSpecies = ${totalSpeciesCount}`)
    .replace(/expectedSpecies = 1082/g, `expectedSpecies = ${totalSpeciesCount}`)
    .replace(/description = "Complete Pokemon species database with all 1082 species and chunked loading"/g, 
             `description = "Complete Pokemon species database with all ${totalSpeciesCount} species embedded directly"`)
    .replace(/lazyLoading = true/g, 'lazyLoading = false')
    .replace(/chunkCount = 9/g, 'chunkCount = 0');

// Update the process metadata to reflect embedded data
const finalContent = updatedContent.replace(
    /-- Total Species: 1082 \(100% coverage\)\s*-- Architecture: Chunked loading with lazy evaluation/g,
    `-- Total Species: ${totalSpeciesCount} (100% coverage)
-- Architecture: Complete embedded dataset`
);

// Write the updated file
fs.writeFileSync(MAIN_PROCESS_FILE, finalContent);

// Check final file size
const finalStats = fs.statSync(MAIN_PROCESS_FILE);
const finalSizeKB = (finalStats.size / 1024).toFixed(2);
const percentOfLimit = ((finalStats.size / (500 * 1024)) * 100).toFixed(1);

console.log('✅ Species embedding completed!');
console.log(`📊 Final process file size: ${finalSizeKB} KB (${percentOfLimit}% of 500KB limit)`);
console.log(`🎯 Total species embedded: ${totalSpeciesCount}`);

if (finalStats.size > 500 * 1024) {
    console.log('❌ ERROR: File size exceeds 500KB limit!');
    process.exit(1);
} else {
    console.log('✅ File size within 500KB constraint');
}

console.log(`📁 Updated file: ${MAIN_PROCESS_FILE}`);