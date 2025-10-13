/**
 * Server-Side Bypass Protection Tests
 * Validates the security and functionality of server-side TDD bypass protection
 * Addresses QA finding SECURITY-001: Server-side bypass protection
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, rmSync, unlinkSync, writeFileSync } from "fs";
import { join } from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const TEST_DIR = join(process.cwd(), "test-temp-bypass-security");
const VALIDATOR_PATH = join(process.cwd(), "scripts/hooks/server-side-bypass-validator.js");

describe("Server-Side Bypass Protection", () => {
  beforeEach(() => {
    // Create temporary test directory
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
    mkdirSync(TEST_DIR, { recursive: true });

    // Clear any existing bypass cache
    const cachePath = join(TEST_DIR, ".git/bypass-cache.json");
    if (existsSync(cachePath)) {
      unlinkSync(cachePath);
    }
  });

  afterEach(() => {
    // Clean up temporary files
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
  });

  describe("Request Validation", () => {
    it("should reject requests with missing required fields", () => {
      const incompleteRequest = JSON.stringify({
        user: "testuser",
        // Missing repository, justification, timestamp
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${incompleteRequest}'`, { encoding: "utf8" });
        expect.fail("Should have rejected incomplete request");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("MISSING_FIELDS");
        expect(result.message).toContain("Missing required fields");
      }
    });

    it("should reject requests with stale timestamps", () => {
      const oldTimestamp = new Date(Date.now() - 10 * 60 * 1000).toISOString(); // 10 minutes ago
      const staleRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification:
          "This is a detailed justification that meets the minimum length requirement for testing purposes",
        timestamp: oldTimestamp,
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${staleRequest}'`, { encoding: "utf8" });
        expect.fail("Should have rejected stale request");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("STALE_REQUEST");
      }
    });

    it("should reject requests with insufficient justification", () => {
      const shortJustificationRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "urgent", // Too short
        timestamp: new Date().toISOString(),
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${shortJustificationRequest}'`, {
          encoding: "utf8",
        });
        expect.fail("Should have rejected insufficient justification");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("INSUFFICIENT_JUSTIFICATION");
        expect(result.minimumLength).toBe(50);
      }
    });

    it("should reject generic justifications", () => {
      const genericRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "emergency", // Generic justification
        timestamp: new Date().toISOString(),
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${genericRequest}'`, { encoding: "utf8" });
        expect.fail("Should have rejected generic justification");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("GENERIC_JUSTIFICATION");
      }
    });
  });

  describe("Quota Enforcement", () => {
    it("should enforce daily user bypass limits", () => {
      // Create a bypass cache with user at limit
      const bypassCache = {
        [new Date().toISOString().split("T")[0]]: {
          users: {
            testuser: { count: 3, timestamps: [Date.now(), Date.now(), Date.now()] },
          },
          repositories: {},
          total: 3,
        },
      };

      const cachePath = join(TEST_DIR, ".git/bypass-cache.json");
      mkdirSync(join(TEST_DIR, ".git"), { recursive: true });
      writeFileSync(cachePath, JSON.stringify(bypassCache, null, 2));

      const quotaExceededRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "This is a detailed justification that meets the minimum length requirement for quota testing",
        timestamp: new Date().toISOString(),
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${quotaExceededRequest}'`, { encoding: "utf8" });
        expect.fail("Should have rejected request due to quota exceeded");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("QUOTA_EXCEEDED");
        expect(result.remainingBypasses).toBe(0);
      }
    });

    it("should enforce daily repository bypass limits", () => {
      // Create a bypass cache with repository at limit
      const bypassCache = {
        [new Date().toISOString().split("T")[0]]: {
          users: {},
          repositories: {
            "test-repo": { count: 10, timestamps: new Array(10).fill(Date.now()) },
          },
          total: 10,
        },
      };

      const cachePath = join(TEST_DIR, ".git/bypass-cache.json");
      mkdirSync(join(TEST_DIR, ".git"), { recursive: true });
      writeFileSync(cachePath, JSON.stringify(bypassCache, null, 2));

      const repoQuotaRequest = JSON.stringify({
        user: "newuser",
        repository: "test-repo",
        justification: "This is a detailed justification for testing repository quota enforcement mechanisms",
        timestamp: new Date().toISOString(),
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${repoQuotaRequest}'`, { encoding: "utf8" });
        expect.fail("Should have rejected request due to repo quota exceeded");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("REPO_QUOTA_EXCEEDED");
      }
    });
  });

  describe("Admin Approval", () => {
    it("should require admin approval for non-emergency bypasses", () => {
      const nonEmergencyRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "This is a detailed justification for a non-emergency bypass that should require admin approval",
        timestamp: new Date().toISOString(),
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${nonEmergencyRequest}'`, { encoding: "utf8" });
        expect.fail("Should have required admin approval");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("ADMIN_APPROVAL_REQUIRED");
        expect(result.requiredApprovers).toEqual(["security-team", "tech-lead", "release-manager"]);
      }
    });

    it("should accept requests with valid admin approval", () => {
      const adminApprovedRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "This is a detailed justification for a bypass that has been approved by an admin",
        timestamp: new Date().toISOString(),
        adminApproval: {
          approver: "security-team",
          timestamp: new Date().toISOString(),
        },
      });

      const result = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${adminApprovedRequest}'`, {
        encoding: "utf8",
      });
      const response = JSON.parse(result);

      expect(response.valid).toBe(true);
      expect(response.reason).toBe("APPROVED");
      expect(response.bypassToken).toBeDefined();
      expect(response.expirationTime).toBeGreaterThan(Date.now());
    });
  });

  describe("Emergency Override", () => {
    it("should validate emergency override with correct secret", () => {
      // Set emergency secret via environment variable
      process.env.TDD_EMERGENCY_SECRET = "test-emergency-secret-123";

      const emergencyRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "Emergency production outage requires immediate hotfix deployment",
        timestamp: new Date().toISOString(),
        emergencySecret: "test-emergency-secret-123",
      });

      const result = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${emergencyRequest}'`, {
        encoding: "utf8",
      });
      const response = JSON.parse(result);

      expect(response.valid).toBe(true);
      expect(response.reason).toBe("EMERGENCY_OVERRIDE");
      expect(response.conditions.emergency).toBe(true);
      expect(response.conditions.requiresPostMortem).toBe(true);

      // Clean up
      process.env.TDD_EMERGENCY_SECRET = undefined;
    });

    it("should reject emergency override with incorrect secret", () => {
      // Set emergency secret via environment variable
      process.env.TDD_EMERGENCY_SECRET = "correct-secret";

      const emergencyRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "Emergency production outage requires immediate hotfix deployment",
        timestamp: new Date().toISOString(),
        emergencySecret: "wrong-secret",
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${emergencyRequest}'`, { encoding: "utf8" });
        expect.fail("Should have rejected incorrect emergency secret");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("ADMIN_APPROVAL_REQUIRED"); // Falls back to requiring admin approval
      }

      // Clean up
      process.env.TDD_EMERGENCY_SECRET = undefined;
    });
  });

  describe("Token Generation and Verification", () => {
    it("should generate valid bypass tokens", () => {
      const validRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "This is a detailed justification for testing token generation and validation mechanisms",
        timestamp: new Date().toISOString(),
        adminApproval: {
          approver: "security-team",
          timestamp: new Date().toISOString(),
        },
      });

      const result = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${validRequest}'`, {
        encoding: "utf8",
      });
      const response = JSON.parse(result);

      expect(response.valid).toBe(true);
      expect(response.bypassToken).toBeDefined();

      // Verify the token
      const verifyResult = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} verify '${response.bypassToken}'`, {
        encoding: "utf8",
      });
      const verification = JSON.parse(verifyResult);

      expect(verification.valid).toBe(true);
      expect(verification.payload.user).toBe("testuser");
      expect(verification.payload.repository).toBe("test-repo");
    });

    it("should reject expired tokens", () => {
      // Create a token that will be expired
      const pastTime = Date.now() - 1000; // 1 second ago
      const expiredPayload = {
        user: "testuser",
        repository: "test-repo",
        timestamp: pastTime,
        exp: pastTime + 1000, // Expired
        emergency: false,
      };

      const encodedPayload = Buffer.from(JSON.stringify(expiredPayload)).toString("base64");
      const expiredToken = `${encodedPayload}.fakesignature`;

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} verify '${expiredToken}'`, { encoding: "utf8" });
        expect.fail("Should have rejected expired token");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("TOKEN_EXPIRED");
      }
    });

    it("should reject malformed tokens", () => {
      const malformedToken = "this-is-not-a-valid-token";

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} verify '${malformedToken}'`, { encoding: "utf8" });
        expect.fail("Should have rejected malformed token");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        expect(result.reason).toBe("MALFORMED_TOKEN");
      }
    });
  });

  describe("Statistics and Monitoring", () => {
    it("should provide accurate bypass statistics", () => {
      // Create bypass cache with test data
      const today = new Date().toISOString().split("T")[0];
      const bypassCache = {
        [today]: {
          users: {
            user1: { count: 2, timestamps: [Date.now(), Date.now()] },
            user2: { count: 1, timestamps: [Date.now()] },
          },
          repositories: {
            repo1: { count: 2, timestamps: [Date.now(), Date.now()] },
            repo2: { count: 1, timestamps: [Date.now()] },
          },
          total: 3,
        },
      };

      const cachePath = join(TEST_DIR, ".git/bypass-cache.json");
      mkdirSync(join(TEST_DIR, ".git"), { recursive: true });
      writeFileSync(cachePath, JSON.stringify(bypassCache, null, 2));

      const result = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} stats`, { encoding: "utf8" });
      const stats = JSON.parse(result);

      expect(stats.date).toBe(today);
      expect(stats.totalBypasses).toBe(3);
      expect(stats.userBypasses).toBe(2);
      expect(stats.repositoryBypasses).toBe(2);
      expect(stats.quotaStatus.dailyLimit).toBe(3);
      expect(stats.quotaStatus.repoLimit).toBe(10);
    });

    it("should identify users and repositories near quota limits", () => {
      const today = new Date().toISOString().split("T")[0];
      const bypassCache = {
        [today]: {
          users: {
            "user-near-limit": { count: 2, timestamps: [Date.now(), Date.now()] }, // 1 remaining
            "user-at-limit": { count: 3, timestamps: [Date.now(), Date.now(), Date.now()] }, // 0 remaining
          },
          repositories: {
            "repo-near-limit": { count: 8, timestamps: new Array(8).fill(Date.now()) }, // 2 remaining (within warning threshold)
          },
          total: 11,
        },
      };

      const cachePath = join(TEST_DIR, ".git/bypass-cache.json");
      mkdirSync(join(TEST_DIR, ".git"), { recursive: true });
      writeFileSync(cachePath, JSON.stringify(bypassCache, null, 2));

      const result = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} stats`, { encoding: "utf8" });
      const stats = JSON.parse(result);

      expect(stats.quotaStatus.usersNearLimit).toHaveLength(2);
      expect(stats.quotaStatus.usersNearLimit[0].user).toBe("user-near-limit");
      expect(stats.quotaStatus.usersNearLimit[0].remaining).toBe(1);

      expect(stats.quotaStatus.reposNearLimit).toHaveLength(1);
      expect(stats.quotaStatus.reposNearLimit[0].repository).toBe("repo-near-limit");
      expect(stats.quotaStatus.reposNearLimit[0].remaining).toBe(2);
    });
  });

  describe("Security Hardening", () => {
    it("should use timing-safe comparison for secrets", () => {
      // This test verifies that timing attacks are mitigated
      // We can't easily test timing, but we can verify the function exists and works

      process.env.TDD_EMERGENCY_SECRET = "secret123";

      const correctSecretRequest = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "Emergency production issue requiring immediate deployment with proper security verification",
        timestamp: new Date().toISOString(),
        emergencySecret: "secret123",
      });

      const result = execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${correctSecretRequest}'`, {
        encoding: "utf8",
      });
      const response = JSON.parse(result);

      expect(response.valid).toBe(true);
      expect(response.reason).toBe("EMERGENCY_OVERRIDE");

      process.env.TDD_EMERGENCY_SECRET = undefined;
    });

    it("should fail securely when unable to check quotas", () => {
      // Remove .git directory to simulate file system issues
      const gitPath = join(TEST_DIR, ".git");
      if (existsSync(gitPath)) {
        rmSync(gitPath, { recursive: true, force: true });
      }

      const request = JSON.stringify({
        user: "testuser",
        repository: "test-repo",
        justification: "This is a detailed justification that should fail due to quota check failure",
        timestamp: new Date().toISOString(),
      });

      try {
        execSync(`cd ${TEST_DIR} && node ${VALIDATOR_PATH} validate '${request}'`, { encoding: "utf8" });
        expect.fail("Should have failed securely");
      } catch (error) {
        const result = JSON.parse(error.stdout || "{}");
        expect(result.valid).toBe(false);
        // Should fail securely rather than allowing bypass
      }
    });
  });
});
