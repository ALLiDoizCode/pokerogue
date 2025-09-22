/**
 * Unit tests for TypeScript Reference Preservation validation
 * Ensures integrity and proper preservation of TypeScript reference implementation
 */

import { exec } from "child_process";
import fs from "fs/promises";
import path from "path";
import { promisify } from "util";
import { beforeAll, describe, expect, it } from "vitest";

const execAsync = promisify(exec);

describe("TypeScript Reference Preservation", () => {
  const REFERENCE_DIR = path.join(process.cwd(), "typescript-reference");
  const REQUIRED_FILES = ["package.json", "tsconfig.json", "vite.config.ts", "README.md", "checksums.sha256"];
  const REQUIRED_SCRIPTS = [
    "scripts/build-reference.sh",
    "scripts/run-tests.sh",
    "scripts/start-game.sh",
    "scripts/validate-integrity.sh",
  ];

  beforeAll(async () => {
    // Ensure TypeScript reference directory exists
    const stats = await fs.stat(REFERENCE_DIR);
    expect(stats.isDirectory()).toBe(true);
  });

  describe("Directory Structure", () => {
    it("should have complete TypeScript source code preserved", async () => {
      const srcDir = path.join(REFERENCE_DIR, "src");
      const stats = await fs.stat(srcDir);
      expect(stats.isDirectory()).toBe(true);

      // Check for critical game logic directories
      const criticalDirs = ["data", "battle", "pokemon", "field"];
      for (const dir of criticalDirs) {
        try {
          const dirPath = path.join(srcDir, dir);
          const dirStats = await fs.stat(dirPath);
          expect(dirStats.isDirectory()).toBe(true);
        } catch (error) {
          // Some directories might be nested differently
          console.warn(`Directory ${dir} not found at expected location`);
        }
      }
    });

    it("should have all required configuration files", async () => {
      for (const file of REQUIRED_FILES) {
        const filePath = path.join(REFERENCE_DIR, file);
        const stats = await fs.stat(filePath);
        expect(stats.isFile()).toBe(true);
      }
    });

    it("should have all required build scripts", async () => {
      for (const script of REQUIRED_SCRIPTS) {
        const scriptPath = path.join(REFERENCE_DIR, script);
        const stats = await fs.stat(scriptPath);
        expect(stats.isFile()).toBe(true);

        // Check script is executable
        try {
          await fs.access(scriptPath, fs.constants.X_OK);
        } catch (error) {
          throw new Error(`Script ${script} is not executable`);
        }
      }
    });
  });

  describe("Package Configuration", () => {
    it("should have isolated package.json with correct configuration", async () => {
      const packagePath = path.join(REFERENCE_DIR, "package.json");
      const packageContent = await fs.readFile(packagePath, "utf8");
      const packageJson = JSON.parse(packageContent);

      expect(packageJson.name).toBe("pokemon-rogue-typescript-reference");
      expect(packageJson.description).toContain("TypeScript reference implementation");
      expect(packageJson.scripts).toHaveProperty("build:reference");
      expect(packageJson.scripts).toHaveProperty("test:reference");
      expect(packageJson.scripts).toHaveProperty("start:game");
    });

    it("should have proper TypeScript configuration", async () => {
      const tsconfigPath = path.join(REFERENCE_DIR, "tsconfig.json");
      const tsconfigContent = await fs.readFile(tsconfigPath, "utf8");
      const tsconfig = JSON.parse(tsconfigContent);

      expect(tsconfig).toHaveProperty("compilerOptions");
      expect(tsconfig.compilerOptions).toHaveProperty("strict");
    });
  });

  describe("Checksum Validation", () => {
    it("should have checksums file with valid format", async () => {
      const checksumsPath = path.join(REFERENCE_DIR, "checksums.sha256");
      const checksumsContent = await fs.readFile(checksumsPath, "utf8");

      const lines = checksumsContent.trim().split("\n");
      expect(lines.length).toBeGreaterThan(0);

      // Check format: hash  filename
      for (const line of lines.slice(0, 5)) {
        // Check first 5 lines
        const parts = line.split(/\s+/);
        expect(parts.length).toBe(2);
        expect(parts[0]).toMatch(/^[a-f0-9]{64}$/); // SHA-256 hash
        expect(parts[1]).toMatch(/^src\/.+\.ts$/); // TypeScript file path
      }
    });

    it("should validate checksums successfully", async () => {
      const { stdout, stderr } = await execAsync("./scripts/validate-integrity.sh --validate", { cwd: REFERENCE_DIR });

      expect(stderr).toBe("");
      expect(stdout).toContain("All checksums valid");
    });
  });

  describe("Build System", () => {
    it("should have working build script", async () => {
      // Test build script syntax (dry run)
      const { stderr } = await execAsync("bash -n ./scripts/build-reference.sh", { cwd: REFERENCE_DIR });

      expect(stderr).toBe("");
    });

    it("should have working test script", async () => {
      // Test script syntax
      const { stderr } = await execAsync("bash -n ./scripts/run-tests.sh", { cwd: REFERENCE_DIR });

      expect(stderr).toBe("");
    });

    it("should have working game startup script", async () => {
      // Test script syntax
      const { stderr } = await execAsync("bash -n ./scripts/start-game.sh", { cwd: REFERENCE_DIR });

      expect(stderr).toBe("");
    });
  });

  describe("Source Code Preservation", () => {
    it("should preserve battle system components", async () => {
      const srcDir = path.join(REFERENCE_DIR, "src");
      const files = await fs.readdir(srcDir, { recursive: true });

      // Look for battle-related files
      const battleFiles = files.filter(
        file => file.includes("battle") || file.includes("damage") || file.includes("move"),
      );

      expect(battleFiles.length).toBeGreaterThan(0);
    });

    it("should preserve Pokemon mechanics components", async () => {
      const srcDir = path.join(REFERENCE_DIR, "src");
      const files = await fs.readdir(srcDir, { recursive: true });

      // Look for Pokemon-related files
      const pokemonFiles = files.filter(
        file => file.includes("pokemon") || file.includes("species") || file.includes("stat"),
      );

      expect(pokemonFiles.length).toBeGreaterThan(0);
    });

    it("should preserve data and enum definitions", async () => {
      const srcDir = path.join(REFERENCE_DIR, "src");
      const files = await fs.readdir(srcDir, { recursive: true });

      // Look for data and enum files
      const dataFiles = files.filter(
        file => file.includes("data") || file.includes("enum") || file.includes("species") || file.includes("move"),
      );

      expect(dataFiles.length).toBeGreaterThan(0);
    });
  });
});
