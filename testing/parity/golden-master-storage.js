/**
 * Golden Master Storage System
 * Handles persistent storage, versioning, and integrity validation of TypeScript reference outputs
 */

import crypto from "crypto";
import fs from "fs/promises";
import path from "path";
import chalk from "chalk";

export class GoldenMasterStorage {
  constructor(options = {}) {
    this.storageDir = options.storageDir || path.join(process.cwd(), "testing/parity/scenarios/golden-masters");
    this.versionDir = options.versionDir || "typescript-v1.10.4";
    this.checksumFile = "validation-checksums.json";
    this.version = options.version || "1.10.4";
    this.goldenMasters = new Map();
    this.checksums = new Map();
  }

  /**
   * Initialize storage system
   */
  async initialize() {
    console.log(chalk.blue("🔧 Initializing Golden Master Storage..."));

    const versionedPath = path.join(this.storageDir, this.versionDir);
    await fs.mkdir(versionedPath, { recursive: true });

    // Load existing checksums
    await this.loadChecksums();

    console.log(chalk.green("✅ Golden Master Storage initialized"));
  }

  /**
   * Store golden master output with integrity validation
   */
  async storeGoldenMaster(scenarioId, goldenMaster) {
    console.log(chalk.blue(`💾 Storing golden master: ${scenarioId}`));

    const versionedPath = path.join(this.storageDir, this.versionDir);
    const masterPath = path.join(versionedPath, `${scenarioId}.json`);

    // Add metadata
    const masterWithMetadata = {
      ...goldenMaster,
      metadata: {
        scenarioId,
        version: this.version,
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
        architecture: process.arch,
        platform: process.platform,
      },
    };

    // Serialize and calculate checksum
    const masterJson = JSON.stringify(masterWithMetadata, null, 2);
    const checksum = this.calculateChecksum(masterJson);

    // Store master file
    await fs.writeFile(masterPath, masterJson);

    // Update checksum registry
    this.checksums.set(scenarioId, {
      checksum,
      timestamp: new Date().toISOString(),
      fileSize: Buffer.byteLength(masterJson, "utf8"),
      version: this.version,
    });

    await this.saveChecksums();

    console.log(chalk.green(`✅ Golden master stored: ${scenarioId} (checksum: ${checksum.substring(0, 8)}...)`));

    return {
      scenarioId,
      checksum,
      path: masterPath,
      size: Buffer.byteLength(masterJson, "utf8"),
    };
  }

  /**
   * Load golden master with integrity validation
   */
  async loadGoldenMaster(scenarioId) {
    console.log(chalk.blue(`📖 Loading golden master: ${scenarioId}`));

    const versionedPath = path.join(this.storageDir, this.versionDir);
    const masterPath = path.join(versionedPath, `${scenarioId}.json`);

    try {
      // Check if file exists
      await fs.access(masterPath);

      // Read master file
      const masterJson = await fs.readFile(masterPath, "utf8");
      const goldenMaster = JSON.parse(masterJson);

      // Verify integrity
      const currentChecksum = this.calculateChecksum(masterJson);
      const storedChecksum = this.checksums.get(scenarioId);

      if (storedChecksum && storedChecksum.checksum !== currentChecksum) {
        throw new Error(`Golden master integrity check failed for ${scenarioId}. File may have been corrupted.`);
      }

      console.log(chalk.green(`✅ Golden master loaded: ${scenarioId}`));
      return goldenMaster;
    } catch (error) {
      if (error.code === "ENOENT") {
        console.log(chalk.yellow(`⚠️  Golden master not found: ${scenarioId}`));
        return null;
      }
      throw error;
    }
  }

  /**
   * Check if golden master exists for scenario
   */
  async hasGoldenMaster(scenarioId) {
    const versionedPath = path.join(this.storageDir, this.versionDir);
    const masterPath = path.join(versionedPath, `${scenarioId}.json`);

    try {
      await fs.access(masterPath);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * List all golden masters for current version
   */
  async listGoldenMasters() {
    const versionedPath = path.join(this.storageDir, this.versionDir);

    try {
      const files = await fs.readdir(versionedPath);
      const masters = files
        .filter(file => file.endsWith(".json") && file !== this.checksumFile)
        .map(file => {
          const scenarioId = path.basename(file, ".json");
          return {
            scenarioId,
            checksum: this.checksums.get(scenarioId),
            path: path.join(versionedPath, file),
          };
        });

      return masters;
    } catch (error) {
      if (error.code === "ENOENT") {
        return [];
      }
      throw error;
    }
  }

  /**
   * Validate all golden masters integrity
   */
  async validateAllMasters() {
    console.log(chalk.blue("🔍 Validating all golden masters integrity..."));

    const masters = await this.listGoldenMasters();
    const results = {
      total: masters.length,
      valid: 0,
      invalid: 0,
      missing: 0,
      errors: [],
    };

    for (const master of masters) {
      try {
        const goldenMaster = await this.loadGoldenMaster(master.scenarioId);
        if (goldenMaster) {
          results.valid++;
        } else {
          results.missing++;
          results.errors.push({
            scenarioId: master.scenarioId,
            error: "Master file missing",
          });
        }
      } catch (error) {
        results.invalid++;
        results.errors.push({
          scenarioId: master.scenarioId,
          error: error.message,
        });
      }
    }

    console.log(chalk.green(`✅ Validation complete: ${results.valid}/${results.total} valid`));
    if (results.errors.length > 0) {
      console.log(chalk.red("❌ Errors found:"));
      results.errors.forEach(err => {
        console.log(chalk.red(`  - ${err.scenarioId}: ${err.error}`));
      });
    }

    return results;
  }

  /**
   * Update golden master version
   */
  async updateVersion(newVersion) {
    console.log(chalk.blue(`🔄 Updating golden master version: ${this.version} → ${newVersion}`));

    const oldVersionDir = path.join(this.storageDir, this.versionDir);
    const newVersionDir = path.join(this.storageDir, `typescript-v${newVersion}`);

    // Copy existing masters to new version directory
    try {
      await fs.access(oldVersionDir);
      await fs.mkdir(newVersionDir, { recursive: true });

      const files = await fs.readdir(oldVersionDir);
      for (const file of files) {
        const srcPath = path.join(oldVersionDir, file);
        const destPath = path.join(newVersionDir, file);
        await fs.copyFile(srcPath, destPath);
      }

      console.log(chalk.green(`✅ Golden masters migrated to version ${newVersion}`));
    } catch (error) {
      console.log(chalk.yellow(`⚠️  No existing masters to migrate: ${error.message}`));
    }

    // Update internal version
    this.version = newVersion;
    this.versionDir = `typescript-v${newVersion}`;

    return newVersionDir;
  }

  /**
   * Generate integrity report
   */
  async generateIntegrityReport() {
    const validation = await this.validateAllMasters();
    const masters = await this.listGoldenMasters();

    const report = {
      timestamp: new Date().toISOString(),
      version: this.version,
      storageDir: this.storageDir,
      summary: validation,
      details: masters.map(master => ({
        scenarioId: master.scenarioId,
        checksum: master.checksum?.checksum || "missing",
        timestamp: master.checksum?.timestamp || "unknown",
        fileSize: master.checksum?.fileSize || 0,
        status: validation.errors.find(e => e.scenarioId === master.scenarioId) ? "invalid" : "valid",
      })),
      systemInfo: {
        nodeVersion: process.version,
        platform: process.platform,
        architecture: process.arch,
      },
    };

    const reportPath = path.join(this.storageDir, `integrity-report-${Date.now()}.json`);
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

    console.log(chalk.green(`📊 Integrity report generated: ${reportPath}`));
    return report;
  }

  /**
   * Clean up old versions (keep last N versions)
   */
  async cleanupOldVersions(keepVersions = 3) {
    console.log(chalk.blue(`🧹 Cleaning up old versions (keeping ${keepVersions} versions)...`));

    try {
      const entries = await fs.readdir(this.storageDir, { withFileTypes: true });
      const versionDirs = entries
        .filter(entry => entry.isDirectory() && entry.name.startsWith("typescript-v"))
        .map(entry => ({
          name: entry.name,
          version: entry.name.replace("typescript-v", ""),
          path: path.join(this.storageDir, entry.name),
        }))
        .sort((a, b) => {
          // Sort by version number (semantic versioning)
          const aVersion = a.version.split(".").map(Number);
          const bVersion = b.version.split(".").map(Number);

          for (let i = 0; i < Math.max(aVersion.length, bVersion.length); i++) {
            const aPart = aVersion[i] || 0;
            const bPart = bVersion[i] || 0;
            if (aPart !== bPart) {
              return bPart - aPart; // Descending order (newest first)
            }
          }
          return 0;
        });

      if (versionDirs.length > keepVersions) {
        const versionsToDelete = versionDirs.slice(keepVersions);

        for (const versionDir of versionsToDelete) {
          await fs.rm(versionDir.path, { recursive: true, force: true });
          console.log(chalk.green(`🗑️  Removed old version: ${versionDir.name}`));
        }

        console.log(chalk.green(`✅ Cleanup complete: removed ${versionsToDelete.length} old versions`));
      } else {
        console.log(chalk.green(`✅ No cleanup needed: ${versionDirs.length} versions (< ${keepVersions})`));
      }
    } catch (error) {
      console.log(chalk.yellow(`⚠️  Cleanup failed: ${error.message}`));
    }
  }

  /**
   * Calculate SHA-256 checksum
   */
  calculateChecksum(data) {
    return crypto.createHash("sha256").update(data, "utf8").digest("hex");
  }

  /**
   * Load checksums from storage
   */
  async loadChecksums() {
    const versionedPath = path.join(this.storageDir, this.versionDir);
    const checksumPath = path.join(versionedPath, this.checksumFile);

    try {
      const checksumData = await fs.readFile(checksumPath, "utf8");
      const checksums = JSON.parse(checksumData);

      for (const [scenarioId, checksum] of Object.entries(checksums)) {
        this.checksums.set(scenarioId, checksum);
      }

      console.log(chalk.green(`📋 Loaded ${this.checksums.size} checksums`));
    } catch (error) {
      if (error.code !== "ENOENT") {
        console.log(chalk.yellow(`⚠️  Could not load checksums: ${error.message}`));
      }
    }
  }

  /**
   * Save checksums to storage
   */
  async saveChecksums() {
    const versionedPath = path.join(this.storageDir, this.versionDir);
    const checksumPath = path.join(versionedPath, this.checksumFile);

    const checksumData = Object.fromEntries(this.checksums);
    await fs.writeFile(checksumPath, JSON.stringify(checksumData, null, 2));
  }
}
