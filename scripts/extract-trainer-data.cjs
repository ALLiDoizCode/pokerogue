#!/usr/bin/env node
/**
 * extract-trainer-data.js
 * Purpose: Extract TypeScript trainer configurations and convert to Lua format
 * Usage: node scripts/extract-trainer-data.js
 * Output: Generated Lua table structures for trainer-data-engine.lua
 */

const fs = require("fs");
const path = require("path");

// ============================================================================
// FILE PATHS
// ============================================================================

const TYPESCRIPT_BASE = path.join(__dirname, "../typescript-reference/src");
const OUTPUT_DIR = path.join(__dirname, "../processes/generated");

const SOURCE_FILES = {
  trainerConfig: path.join(TYPESCRIPT_BASE, "data/trainers/trainer-config.ts"),
  trainerType: path.join(TYPESCRIPT_BASE, "enums/trainer-type.ts"),
  signatureSpecies: path.join(TYPESCRIPT_BASE, "data/balance/signature-species.ts"),
  biomes: path.join(TYPESCRIPT_BASE, "data/balance/biomes.ts"),
  partyTemplates: path.join(TYPESCRIPT_BASE, "data/trainers/trainer-party-template.ts"),
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function readSourceFile(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch (error) {
    console.error(`Error reading ${filePath}:`, error.message);
    return null;
  }
}

function writeOutputFile(filename, content) {
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const outputPath = path.join(OUTPUT_DIR, filename);
  fs.writeFileSync(outputPath, content, "utf8");
  console.log(`✅ Generated: ${outputPath}`);
}

// ============================================================================
// TRAINER TYPE ENUM EXTRACTION
// ============================================================================

function extractTrainerTypeEnum(content) {
  if (!content) {
    return null;
  }

  const enumMatch = content.match(/export enum TrainerType\s*{([^}]+)}/s);
  if (!enumMatch) {
    console.error("❌ Could not find TrainerType enum");
    return null;
  }

  const enumBody = enumMatch[1];
  const entries = [];
  const lines = enumBody.split("\n");

  for (const line of lines) {
    // Match: TRAINER_NAME = value, or TRAINER_NAME,
    const match = line.match(/^\s*([A-Z_0-9]+)\s*(?:=\s*(\d+))?,?\s*(?:\/\/.*)?$/);
    if (match) {
      const name = match[1];
      const value = match[2];
      entries.push({ name, value });
    }
  }

  console.log(`📊 Extracted ${entries.length} trainer types`);
  return entries;
}

function generateTrainerTypeEnumLua(entries) {
  if (!entries) {
    return "";
  }

  let lua = "-- TrainerType Enum (Auto-generated)\n";
  lua += "local TrainerType = {\n";

  let currentValue = 0;
  for (const entry of entries) {
    if (entry.value !== undefined) {
      currentValue = Number.parseInt(entry.value);
    }
    lua += `    ${entry.name} = ${currentValue},\n`;
    currentValue++;
  }

  lua += "}\n\n";
  return lua;
}

// ============================================================================
// TRAINER CONFIG EXTRACTION
// ============================================================================

function extractTrainerConfigs(content) {
  if (!content) {
    return null;
  }

  // Find all TrainerConfig declarations
  const configMatches = content.matchAll(/\[TrainerType\.([A-Z_0-9]+)\]:\s*new TrainerConfig\(([^)]+)\)/gs);
  const configs = [];

  for (const match of configMatches) {
    const trainerTypeName = match[1];
    const configBody = match[2];

    // Parse config properties
    const config = {
      trainerType: trainerTypeName,
      name: extractStringValue(configBody, "name"),
      hasGenders: extractBooleanValue(configBody, "hasGenders"),
      hasDouble: extractBooleanValue(configBody, "hasDouble"),
      doubleOnly: extractBooleanValue(configBody, "doubleOnly"),
      moneyMultiplier: extractNumberValue(configBody, "moneyMultiplier"),
      isBoss: extractBooleanValue(configBody, "isBoss"),
      hasStaticParty: extractBooleanValue(configBody, "hasStaticParty"),
      hasVoucher: extractBooleanValue(configBody, "hasVoucher"),
    };

    configs.push(config);
  }

  console.log(`📊 Extracted ${configs.length} trainer configurations`);
  return configs;
}

function extractStringValue(text, propertyName) {
  const match = text.match(new RegExp(`${propertyName}:\\s*['"]([^'"]+)['"]`));
  return match ? match[1] : null;
}

function extractNumberValue(text, propertyName) {
  const match = text.match(new RegExp(`${propertyName}:\\s*(\\d+\\.?\\d*)`));
  return match ? Number.parseFloat(match[1]) : null;
}

function extractBooleanValue(text, propertyName) {
  const match = text.match(new RegExp(`${propertyName}:\\s*(true|false)`));
  return match ? match[1] === "true" : false;
}

function generateTrainerConfigsLua(configs) {
  if (!configs) {
    return "";
  }

  let lua = "-- Trainer Configuration Database (Auto-generated)\n";
  lua += "-- Total Configurations: " + configs.length + "\n";
  lua += "local trainerConfigs = {\n";

  for (const config of configs) {
    lua += `    [TrainerType.${config.trainerType}] = {\n`;
    lua += `        trainerType = TrainerType.${config.trainerType},\n`;

    if (config.name) {
      lua += `        name = "${config.name}",\n`;
    }

    lua += `        hasGenders = ${config.hasGenders},\n`;
    lua += `        hasDouble = ${config.hasDouble},\n`;
    lua += `        doubleOnly = ${config.doubleOnly},\n`;

    if (config.moneyMultiplier !== null) {
      lua += `        moneyMultiplier = ${config.moneyMultiplier},\n`;
    }

    lua += `        isBoss = ${config.isBoss},\n`;
    lua += `        hasStaticParty = ${config.hasStaticParty},\n`;
    lua += `        hasVoucher = ${config.hasVoucher},\n`;

    // Placeholder for complex fields
    lua += "        partyTemplates = {},\n";
    lua += "        speciesPools = {},\n";
    lua += "        trainerAI = {teraMode = 0, instantTeras = {}}\n";

    lua += "    },\n\n";
  }

  lua += "}\n\n";
  return lua;
}

// ============================================================================
// SIGNATURE SPECIES EXTRACTION
// ============================================================================

function extractSignatureSpecies(content) {
  if (!content) {
    return null;
  }

  // Find signature species object (handles Proxy wrapper)
  // Format: export const signatureSpecies: SignatureSpecies = new Proxy({
  const signatureMatch = content.match(/export const signatureSpecies[^=]+=\s*new Proxy\(\s*{([\s\S]+?)},\s*{/s);
  if (!signatureMatch) {
    console.error("❌ Could not find signatureSpecies object");
    return null;
  }

  const signatures = [];
  const objectBody = signatureMatch[1];

  // Parse individual trainer signatures - match entire line to avoid crossing boundaries
  // Format: BROCK: [SpeciesId.ONIX, SpeciesId.GEODUDE, ...],
  const lines = objectBody.split("\n");

  for (const line of lines) {
    // Skip comments and empty lines
    if (line.trim().startsWith("//") || line.trim() === "") {
      continue;
    }

    // Match: TRAINER_NAME: [species list],
    const trainerMatch = line.match(/^\s*([A-Z_0-9]+):\s*\[(.*?)\],?\s*(?:\/\/.*)?$/);
    if (!trainerMatch) {
      continue;
    }

    const trainerType = trainerMatch[1];
    const speciesArray = trainerMatch[2];

    // Parse species IDs (including nested arrays)
    const species = [];

    // First, extract all nested arrays (choice options)
    const nestedArrays = [];
    let processedArray = speciesArray;
    const nestedRegex = /\[([^\]]+)\]/g;
    let nestedMatch;

    while ((nestedMatch = nestedRegex.exec(speciesArray)) !== null) {
      const placeholder = `__NESTED_${nestedArrays.length}__`;
      const nestedSpecies = [];
      const nestedContent = nestedMatch[1];
      const nestedSpeciesMatches = nestedContent.matchAll(/SpeciesId\.([A-Z_0-9]+)/g);

      for (const sm of nestedSpeciesMatches) {
        nestedSpecies.push(sm[1]);
      }

      if (nestedSpecies.length > 0) {
        nestedArrays.push(nestedSpecies);
        processedArray = processedArray.replace(nestedMatch[0], placeholder);
      }
    }

    // Now extract top-level species and nested array placeholders
    const tokens = processedArray.split(",").map(s => s.trim());

    for (const token of tokens) {
      if (token.includes("__NESTED_")) {
        const nestedMatch = token.match(/__NESTED_(\d+)__/);
        if (nestedMatch) {
          const nestedIndex = Number.parseInt(nestedMatch[1]);
          species.push(nestedArrays[nestedIndex]);
        }
      } else {
        const speciesMatch = token.match(/SpeciesId\.([A-Z_0-9]+)/);
        if (speciesMatch) {
          species.push(speciesMatch[1]);
        }
      }
    }

    if (species.length > 0) {
      signatures.push({ trainerType, species });
    }
  }

  console.log(`📊 Extracted ${signatures.length} signature species mappings`);
  return signatures;
}

function generateSignatureSpeciesLua(signatures) {
  if (!signatures || signatures.length === 0) {
    return "-- Signature Species Database (Auto-generated)\nlocal signatureSpecies = {}\n\n";
  }

  let lua = "-- Signature Species Database (Auto-generated)\n";
  lua += "-- Gym Leader, Elite Four, and Champion signature Pokemon\n";
  lua += "local signatureSpecies = {\n";

  for (const sig of signatures) {
    lua += `    [TrainerType.${sig.trainerType}] = {\n`;

    for (const species of sig.species) {
      if (Array.isArray(species)) {
        // Nested array (choice options)
        lua += "        {";
        lua += species.map(s => `SpeciesId.${s}`).join(", ");
        lua += "},\n";
      } else {
        // Single species
        lua += `        SpeciesId.${species},\n`;
      }
    }

    lua += "    },\n";
  }

  lua += "}\n\n";
  return lua;
}

// ============================================================================
// BIOME TRAINER POOLS EXTRACTION
// ============================================================================

function extractBiomeTrainerPools(content) {
  if (!content) {
    return null;
  }

  // Find biomeTrainerPools object
  // Format: export const biomeTrainerPools: BiomeTrainerPools = { ... }
  const poolsMatch = content.match(/export const biomeTrainerPools[^=]+=\s*{([\s\S]+)^};/ms);
  if (!poolsMatch) {
    console.error("❌ Could not find biomeTrainerPools object");
    return null;
  }

  const pools = [];
  const objectBody = poolsMatch[1];

  // Parse each biome section
  // Format: [BiomeId.PLAINS]: { [BiomePoolTier.COMMON]: [...], ... }
  const biomeMatches = objectBody.matchAll(/\[BiomeId\.([A-Z_0-9]+)\]:\s*{([^}]+)}/gs);

  for (const match of biomeMatches) {
    const biomeName = match[1];
    const biomeBody = match[2];

    const pool = {
      biome: biomeName,
      commonPool: extractTrainerArray(biomeBody, "BiomePoolTier.COMMON"),
      uncommonPool: extractTrainerArray(biomeBody, "BiomePoolTier.UNCOMMON"),
      rarePool: extractTrainerArray(biomeBody, "BiomePoolTier.RARE"),
      superRarePool: extractTrainerArray(biomeBody, "BiomePoolTier.SUPER_RARE"),
      ultraRarePool: extractTrainerArray(biomeBody, "BiomePoolTier.ULTRA_RARE"),
      bossPool: extractTrainerArray(biomeBody, "BiomePoolTier.BOSS"),
    };

    pools.push(pool);
  }

  console.log(`📊 Extracted ${pools.length} biome trainer pools`);
  return pools;
}

function extractTrainerArray(text, tierName) {
  // Escape special regex characters in tierName
  const escapedTier = tierName.replace(/[.*+?^${}()|\\[\]\\]/g, "\\$&");

  // Match: [BiomePoolTier.COMMON]: [ TrainerType.X, TrainerType.Y ]
  const match = text.match(new RegExp(`\\[${escapedTier}\\]:\\s*\\[([^\\]]*)\\]`));
  if (!match) {
    return [];
  }

  const arrayContent = match[1];
  const trainers = [];
  const trainerMatches = arrayContent.matchAll(/TrainerType\.([A-Z_0-9]+)/g);

  for (const trainerMatch of trainerMatches) {
    trainers.push(trainerMatch[1]);
  }

  return trainers;
}

function generateBiomeTrainerPoolsLua(pools) {
  if (!pools || pools.length === 0) {
    return "-- Biome Trainer Pools Database (Auto-generated)\nlocal biomeTrainerPools = {}\n\n";
  }

  let lua = "-- Biome Trainer Pools Database (Auto-generated)\n";
  lua += "-- Trainer types available per biome and tier\n";
  lua += "local biomeTrainerPools = {\n";

  for (const pool of pools) {
    lua += `    [BiomeId.${pool.biome}] = {\n`;

    // Generate all tiers
    const tiers = [
      { name: "common", arr: pool.commonPool },
      { name: "uncommon", arr: pool.uncommonPool },
      { name: "rare", arr: pool.rarePool },
      { name: "superRare", arr: pool.superRarePool },
      { name: "ultraRare", arr: pool.ultraRarePool },
      { name: "boss", arr: pool.bossPool },
    ];

    for (const tier of tiers) {
      if (tier.arr && tier.arr.length > 0) {
        lua += `        ${tier.name}Pool = {`;
        lua += tier.arr.map(t => `TrainerType.${t}`).join(", ");
        lua += "},\n";
      }
    }

    lua += "    },\n";
  }

  lua += "}\n\n";
  return lua;
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

function main() {
  console.log("🚀 Starting TypeScript to Lua trainer data extraction...\n");

  // Extract TrainerType enum
  const trainerTypeContent = readSourceFile(SOURCE_FILES.trainerType);
  const trainerTypes = extractTrainerTypeEnum(trainerTypeContent);
  const trainerTypeEnumLua = generateTrainerTypeEnumLua(trainerTypes);

  // Extract Trainer Configurations
  const trainerConfigContent = readSourceFile(SOURCE_FILES.trainerConfig);
  const trainerConfigs = extractTrainerConfigs(trainerConfigContent);
  const trainerConfigsLua = generateTrainerConfigsLua(trainerConfigs);

  // Extract Signature Species
  const signatureSpeciesContent = readSourceFile(SOURCE_FILES.signatureSpecies);
  const signatures = extractSignatureSpecies(signatureSpeciesContent);
  const signatureSpeciesLua = generateSignatureSpeciesLua(signatures);

  // Extract Biome Trainer Pools
  const biomesContent = readSourceFile(SOURCE_FILES.biomes);
  const biomePools = extractBiomeTrainerPools(biomesContent);
  const biomePoolsLua = generateBiomeTrainerPoolsLua(biomePools);

  // Write output files
  writeOutputFile("trainer-type-enum.lua", trainerTypeEnumLua);
  writeOutputFile("trainer-configs.lua", trainerConfigsLua);
  writeOutputFile("signature-species.lua", signatureSpeciesLua);
  writeOutputFile("biome-trainer-pools.lua", biomePoolsLua);

  // Generate combined file
  const combinedLua = `-- Generated Trainer Data
-- Auto-generated by scripts/extract-trainer-data.js
-- DO NOT EDIT MANUALLY

${trainerTypeEnumLua}
${trainerConfigsLua}
${signatureSpeciesLua}
${biomePoolsLua}
-- End of generated data
`;

  writeOutputFile("trainer-data-combined.lua", combinedLua);

  console.log("\n✅ Data extraction complete!");
  console.log(`📊 Total Trainer Types: ${trainerTypes?.length || 0}`);
  console.log(`📊 Total Configurations: ${trainerConfigs?.length || 0}`);
  console.log(`📊 Total Signature Species: ${signatures?.length || 0}`);
  console.log(`📊 Total Biome Pools: ${biomePools?.length || 0}`);
}

// Run extraction
main();
