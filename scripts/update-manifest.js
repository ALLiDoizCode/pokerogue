#!/usr/bin/env node

/**
 * Update Species Manifest from Actual Chunk Files
 * Scans the chunks directory and generates accurate manifest
 *
 * Generated: 2025-09-23
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const CONFIG = {
  chunkDir: path.join(__dirname, "../data-migration/chunks"),
  manifestFile: path.join(__dirname, "../data-migration/species-manifest.json"),
};

function scanChunkFiles() {
  console.log("Scanning chunk files...");

  if (!fs.existsSync(CONFIG.chunkDir)) {
    throw new Error("Chunks directory not found");
  }

  const files = fs.readdirSync(CONFIG.chunkDir);
  const chunks = [];
  let totalSpecies = 0;

  files.forEach(file => {
    if (file.endsWith("-species.lua")) {
      const filePath = path.join(CONFIG.chunkDir, file);
      const content = fs.readFileSync(filePath, "utf8");
      const stats = fs.statSync(filePath);

      // Extract generation from filename
      const genMatch = file.match(/gen(\d+)-species\.lua/);
      if (!genMatch) {
        return;
      }

      const generation = Number.parseInt(genMatch[1]);

      // Count species in file
      const speciesMatches = content.match(/\[\d+\]\s*=/g);
      const speciesCount = speciesMatches ? speciesMatches.length : 0;

      console.log(`  ${file}: Gen ${generation}, ${speciesCount} species, ${Math.round(stats.size / 1024)}KB`);

      chunks.push({
        generation: generation,
        file: file,
        size: stats.size,
        speciesCount: speciesCount,
        path: `chunks/${file}`,
      });

      totalSpecies += speciesCount;
    }
  });

  // Sort chunks by generation
  chunks.sort((a, b) => a.generation - b.generation);

  console.log(`Total: ${totalSpecies} species across ${chunks.length} chunks`);

  return { chunks, totalSpecies };
}

function updateManifest() {
  const { chunks, totalSpecies } = scanChunkFiles();

  const manifest = {
    version: "1.0.0",
    generated: new Date().toISOString(),
    totalSpecies: totalSpecies,
    chunkCount: chunks.length,
    chunks: chunks,
  };

  fs.writeFileSync(CONFIG.manifestFile, JSON.stringify(manifest, null, 2));
  console.log(`Updated manifest: ${CONFIG.manifestFile}`);

  return manifest;
}

// Execute if run directly
if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    const manifest = updateManifest();
    console.log("\n✅ Manifest updated successfully!");
    console.log(`📊 Total Species: ${manifest.totalSpecies}`);
    console.log(`📁 Chunks: ${manifest.chunkCount}`);
  } catch (error) {
    console.error("❌ Failed to update manifest:", error);
    process.exit(1);
  }
}

export { updateManifest };
