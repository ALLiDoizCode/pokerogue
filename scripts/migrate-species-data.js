#!/usr/bin/env node

/**
 * Pokemon Species Data Migration Script
 * Extracts species data from TypeScript files and generates Lua tables
 * 
 * Sources:
 * - typescript-reference/src/data/balance/pokemon-species.ts (species definitions)
 * - typescript-reference/src/enums/species-id.ts (species IDs)
 * - typescript-reference/src/data/balance/pokemon-evolutions.ts (evolution data)
 * - typescript-reference/src/data/balance/pokemon-level-moves.ts (move data)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Paths to source files
const TYPESCRIPT_BASE = path.join(__dirname, '../typescript-reference/src');
const SPECIES_FILE = path.join(TYPESCRIPT_BASE, 'data/balance/pokemon-species.ts');
const SPECIES_ID_FILE = path.join(TYPESCRIPT_BASE, 'enums/species-id.ts');
const EVOLUTIONS_FILE = path.join(TYPESCRIPT_BASE, 'data/balance/pokemon-evolutions.ts');
const LEVEL_MOVES_FILE = path.join(TYPESCRIPT_BASE, 'data/balance/pokemon-level-moves.ts');

// Output files
const OUTPUT_DIR = path.join(__dirname, '../data-migration');
const LUA_OUTPUT = path.join(OUTPUT_DIR, 'species-data.lua');
const REPORT_OUTPUT = path.join(OUTPUT_DIR, 'migration-report.txt');

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Pokemon type mapping (numeric values from TypeScript)
const POKEMON_TYPES = {
    'PokemonType.NORMAL': 0, 'PokemonType.FIGHTING': 1, 'PokemonType.FLYING': 2, 'PokemonType.POISON': 3,
    'PokemonType.GROUND': 4, 'PokemonType.ROCK': 5, 'PokemonType.BUG': 6, 'PokemonType.GHOST': 7,
    'PokemonType.STEEL': 8, 'PokemonType.FIRE': 9, 'PokemonType.WATER': 10, 'PokemonType.GRASS': 11,
    'PokemonType.ELECTRIC': 12, 'PokemonType.PSYCHIC': 13, 'PokemonType.ICE': 14, 'PokemonType.DRAGON': 15,
    'PokemonType.DARK': 16, 'PokemonType.FAIRY': 17
};

// Ability mapping (simplified for now)
const ABILITIES = {
    'AbilityId.NONE': 0, 'AbilityId.OVERGROW': 65, 'AbilityId.BLAZE': 66, 'AbilityId.TORRENT': 67,
    'AbilityId.SWARM': 68, 'AbilityId.CHLOROPHYLL': 34, 'AbilityId.SOLAR_POWER': 94,
    'AbilityId.RAIN_DISH': 44, 'AbilityId.STATIC': 9, 'AbilityId.LIGHTNING_ROD': 31,
    'AbilityId.PRESSURE': 46, 'AbilityId.UNNERVE': 186, 'AbilityId.THICK_FAT': 47,
    'AbilityId.DROUGHT': 70, 'AbilityId.TOUGH_CLAWS': 181
};

/**
 * Parse species ID enum file to extract species constants
 */
function parseSpeciesIds() {
    const content = fs.readFileSync(SPECIES_ID_FILE, 'utf8');
    const speciesIds = {};
    
    // Extract enum content between { and }
    const enumMatch = content.match(/export enum SpeciesId\s*\{([\s\S]*)\}/);
    if (!enumMatch) {
        throw new Error('Could not find SpeciesId enum definition');
    }
    
    const enumContent = enumMatch[1];
    
    // Split by lines and parse each entry
    const lines = enumContent.split('\n');
    let currentId = 0;
    
    for (const line of lines) {
        const trimmedLine = line.trim();
        
        // Skip comments and empty lines
        if (trimmedLine.startsWith('/**') || trimmedLine.startsWith('*') || trimmedLine === '' || trimmedLine === '}') {
            continue;
        }
        
        // Match enum entries: NAME = value, or just NAME,
        const explicitValueMatch = trimmedLine.match(/(\w+)\s*=\s*(\d+),?/);
        const implicitValueMatch = trimmedLine.match(/(\w+),?/);
        
        if (explicitValueMatch) {
            const [, name, value] = explicitValueMatch;
            currentId = parseInt(value);
            speciesIds[name] = currentId;
            currentId++;
        } else if (implicitValueMatch) {
            const [, name] = implicitValueMatch;
            speciesIds[name] = currentId;
            currentId++;
        }
    }
    
    console.log(`Parsed ${Object.keys(speciesIds).length} species IDs`);
    return speciesIds;
}

/**
 * Parse species definitions from TypeScript file
 */
function parseSpeciesData() {
    const content = fs.readFileSync(SPECIES_FILE, 'utf8');
    const species = [];
    
    // Match PokemonSpecies constructor calls
    // Pattern: new PokemonSpecies(SpeciesId.NAME, generation, legendary, mythical, ultraBeast, species, type1, type2, height, weight, ability1, ability2, abilityHidden, baseTotal, hp, atk, def, spatk, spdef, spd, catchRate, baseFriendship, baseExp, growthRate, malePercent, genderDiffs, ...)
    const speciesPattern = /new PokemonSpecies\(\s*SpeciesId\.(\w+),\s*(\d+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*"([^"]+)",\s*PokemonType\.(\w+),\s*(?:PokemonType\.(\w+)|null),\s*([\d.]+),\s*([\d.]+),\s*AbilityId\.(\w+),\s*AbilityId\.(\w+),\s*AbilityId\.(\w+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)/g;
    
    let match;
    let count = 0;
    
    while ((match = speciesPattern.exec(content)) !== null && count < 1000) { // Limit for safety
        const [
            , speciesName, generation, legendary, mythical, ultraBeast, displayName,
            type1, type2, height, weight, ability1, ability2, abilityHidden,
            baseTotal, hp, atk, def, spatk, spdef, spd, catchRate, baseFriendship, baseExp
        ] = match;
        
        species.push({
            name: speciesName,
            displayName: displayName,
            generation: parseInt(generation),
            legendary: legendary === 'true',
            mythical: mythical === 'true',
            ultraBeast: ultraBeast === 'true',
            type1: type1,
            type2: type2 === 'null' ? null : type2,
            height: parseFloat(height),
            weight: parseFloat(weight),
            abilities: [ability1, ability2, abilityHidden],
            baseStats: [
                parseInt(hp), parseInt(atk), parseInt(def),
                parseInt(spatk), parseInt(spdef), parseInt(spd)
            ],
            baseTotal: parseInt(baseTotal),
            catchRate: parseInt(catchRate),
            baseFriendship: parseInt(baseFriendship),
            baseExp: parseInt(baseExp)
        });
        
        count++;
    }
    
    console.log(`Parsed ${species.length} species definitions`);
    return species;
}

/**
 * Convert parsed data to Lua format
 */
function generateLuaData(speciesIds, speciesData) {
    const luaLines = [];
    
    // Header
    luaLines.push('-- ============================================================================');
    luaLines.push('-- MIGRATED POKEMON SPECIES DATABASE');
    luaLines.push('-- Generated from TypeScript reference implementation');
    luaLines.push(`-- Generated on: ${new Date().toISOString()}`);
    luaLines.push(`-- Species count: ${speciesData.length}`);
    luaLines.push('-- ============================================================================');
    luaLines.push('');
    
    // Species ID constants
    luaLines.push('local SPECIES = {');
    const sortedSpecies = Object.entries(speciesIds).sort((a, b) => a[1] - b[1]);
    for (const [name, id] of sortedSpecies.slice(0, 50)) { // Limit for initial migration
        luaLines.push(`    ${name} = ${id},`);
    }
    luaLines.push('}');
    luaLines.push('');
    
    // Pokemon types
    luaLines.push('local POKEMON_TYPE = {');
    Object.entries(POKEMON_TYPES).forEach(([tsType, value]) => {
        const luaName = tsType.replace('PokemonType.', '');
        luaLines.push(`    ${luaName} = ${value},`);
    });
    luaLines.push('}');
    luaLines.push('');
    
    // Abilities
    luaLines.push('local ABILITY = {');
    Object.entries(ABILITIES).forEach(([tsAbility, value]) => {
        const luaName = tsAbility.replace('AbilityId.', '');
        luaLines.push(`    ${luaName} = ${value},`);
    });
    luaLines.push('}');
    luaLines.push('');
    
    // Species database (compact format)
    luaLines.push('local SpeciesDatabase = {');
    
    for (let i = 0; i < Math.min(speciesData.length, 50); i++) { // Limit for initial migration
        const species = speciesData[i];
        const speciesId = speciesIds[species.name];
        
        if (!speciesId) continue;
        
        const type1 = `POKEMON_TYPE.${species.type1}`;
        const type2 = species.type2 ? `POKEMON_TYPE.${species.type2}` : 'nil';
        const abilities = species.abilities.map(a => `ABILITY.${a}`).join(', ');
        
        luaLines.push(`    [SPECIES.${species.name}] = {`);
        luaLines.push(`        id = ${speciesId}, n = "${species.displayName}",`);
        luaLines.push(`        bs = {${species.baseStats.join(', ')}}, -- HP, ATK, DEF, SPATK, SPDEF, SPD`);
        luaLines.push(`        t = {${type1}${species.type2 ? `, ${type2}` : ''}}, -- types`);
        luaLines.push(`        ab = {${abilities}}, -- abilities: normal1, normal2, hidden`);
        luaLines.push(`        h = ${Math.round(species.height * 10)}, w = ${Math.round(species.weight * 10)}, -- height (dm), weight (hg)`);
        luaLines.push(`        cr = ${species.catchRate}, bf = ${species.baseFriendship}, be = ${species.baseExp}, -- catch rate, base friendship, base exp`);
        luaLines.push(`        ec = {}, -- evolution chain (to be populated)`);
        luaLines.push(`        lm = {} -- level moves (to be populated)`);
        luaLines.push(`    },`);
    }
    
    luaLines.push('}');
    luaLines.push('');
    luaLines.push('return SpeciesDatabase');
    
    return luaLines.join('\n');
}

/**
 * Generate migration report
 */
function generateReport(speciesIds, speciesData) {
    const lines = [];
    
    lines.push('Pokemon Species Data Migration Report');
    lines.push('=====================================');
    lines.push(`Generated: ${new Date().toISOString()}`);
    lines.push('');
    
    lines.push('Source Files:');
    lines.push(`- Species definitions: ${SPECIES_FILE}`);
    lines.push(`- Species IDs: ${SPECIES_ID_FILE}`);
    lines.push('');
    
    lines.push('Migration Statistics:');
    lines.push(`- Species IDs parsed: ${Object.keys(speciesIds).length}`);
    lines.push(`- Species data parsed: ${speciesData.length}`);
    lines.push(`- Species migrated: ${Math.min(speciesData.length, 50)} (limited for initial version)`);
    lines.push('');
    
    lines.push('Data Validation:');
    const validSpecies = speciesData.filter(s => speciesIds[s.name]);
    lines.push(`- Valid species with IDs: ${validSpecies.length}`);
    lines.push(`- Invalid species (no ID): ${speciesData.length - validSpecies.length}`);
    lines.push('');
    
    if (speciesData.length - validSpecies.length > 0) {
        lines.push('Invalid Species:');
        speciesData.filter(s => !speciesIds[s.name]).slice(0, 10).forEach(s => {
            lines.push(`- ${s.name}: ${s.displayName}`);
        });
        lines.push('');
    }
    
    lines.push('Sample Species:');
    validSpecies.slice(0, 10).forEach(s => {
        const id = speciesIds[s.name];
        lines.push(`- ${s.name} (${id}): ${s.displayName} [${s.type1}${s.type2 ? `/${s.type2}` : ''}]`);
    });
    
    return lines.join('\n');
}

/**
 * Main migration function
 */
function main() {
    console.log('Starting Pokemon species data migration...');
    
    try {
        // Parse source data
        console.log('Parsing species IDs...');
        const speciesIds = parseSpeciesIds();
        
        console.log('Parsing species data...');
        const speciesData = parseSpeciesData();
        
        // Generate outputs
        console.log('Generating Lua data...');
        const luaContent = generateLuaData(speciesIds, speciesData);
        
        console.log('Generating migration report...');
        const report = generateReport(speciesIds, speciesData);
        
        // Write files
        fs.writeFileSync(LUA_OUTPUT, luaContent, 'utf8');
        fs.writeFileSync(REPORT_OUTPUT, report, 'utf8');
        
        console.log(`\nMigration complete!`);
        console.log(`- Lua data: ${LUA_OUTPUT}`);
        console.log(`- Report: ${REPORT_OUTPUT}`);
        console.log(`- File size: ${Math.round(fs.statSync(LUA_OUTPUT).size / 1024)}KB`);
        
    } catch (error) {
        console.error('Migration failed:', error.message);
        process.exit(1);
    }
}

// Run migration if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
    main();
}

export { main, parseSpeciesIds, parseSpeciesData };