#!/usr/bin/env node

/**
 * GitHub Integration for Test Failure Tracking
 * Automatically creates and manages GitHub issues for test failures
 */

import fs from "fs";
import { Octokit } from "@octokit/rest";

class GitHubIntegration {
  constructor(config = {}) {
    this.config = {
      token: config.token || process.env.GITHUB_TOKEN,
      owner: config.owner || process.env.GITHUB_REPOSITORY_OWNER,
      repo: config.repo || process.env.GITHUB_REPOSITORY_NAME,
      labelPrefix: "test-failure",
      autoAssign: config.autoAssign || false,
      dryRun: config.dryRun || false,
      ...config,
    };

    if (!this.config.token) {
      throw new Error("GitHub token is required. Set GITHUB_TOKEN environment variable or pass token in config.");
    }

    this.octokit = new Octokit({
      auth: this.config.token,
    });

    this.issueCache = new Map();
  }

  // Create issue for test failure
  async createTestFailureIssue(testFailure) {
    try {
      // Check if issue already exists
      const existingIssue = await this.findExistingIssue(testFailure);
      if (existingIssue) {
        console.log(`Issue already exists for ${testFailure.testFile}: #${existingIssue.number}`);
        return await this.updateExistingIssue(existingIssue, testFailure);
      }

      // Create new issue
      const issueData = this.formatTestFailureIssue(testFailure);

      if (this.config.dryRun) {
        console.log("DRY RUN - Would create issue:", issueData);
        return { number: "DRY_RUN", url: "dry-run-url" };
      }

      const response = await this.octokit.rest.issues.create({
        owner: this.config.owner,
        repo: this.config.repo,
        ...issueData,
      });

      console.log(`Created issue #${response.data.number} for test failure: ${testFailure.testFile}`);

      // Add to cache
      this.issueCache.set(this.getIssueCacheKey(testFailure), response.data);

      return response.data;
    } catch (error) {
      console.error("Failed to create test failure issue:", error.message);
      throw error;
    }
  }

  // Format test failure data into GitHub issue format
  formatTestFailureIssue(testFailure) {
    const title = `[TEST FAILURE] ${testFailure.testSuite || testFailure.testFile}: ${testFailure.testCase || "Multiple failures"}`;

    const body = this.generateIssueBody(testFailure);

    const labels = [
      "test-failure",
      "bug",
      "automated",
      this.getFailureTypeLabel(testFailure.failureType),
      this.getPriorityLabel(testFailure.priority),
    ].filter(Boolean);

    const issueData = {
      title: title.substring(0, 256), // GitHub title limit
      body,
      labels,
    };

    // Add assignees if configured
    if (this.config.autoAssign && this.config.defaultAssignees) {
      issueData.assignees = this.config.defaultAssignees;
    }

    return issueData;
  }

  // Generate detailed issue body
  generateIssueBody(testFailure) {
    const sections = [];

    // Header
    sections.push("## 🧪 Automated Test Failure Report");
    sections.push("");
    sections.push("This issue was automatically created by the TDD monitoring system.");
    sections.push("");

    // Test Information
    sections.push("### Test Information");
    sections.push("");
    sections.push(`**Test File:** \`${testFailure.testFile}\``);
    if (testFailure.testSuite) {
      sections.push(`**Test Suite:** ${testFailure.testSuite}`);
    }
    if (testFailure.testCase) {
      sections.push(`**Test Case:** ${testFailure.testCase}`);
    }
    if (testFailure.sourceFile) {
      sections.push(`**Source File:** \`${testFailure.sourceFile}\``);
    }
    sections.push(`**Failure Type:** ${testFailure.failureType || "Unknown"}`);
    sections.push(`**Priority:** ${testFailure.priority || "Medium"}`);
    sections.push("");

    // Error Details
    if (testFailure.errorMessage) {
      sections.push("### Error Details");
      sections.push("");
      sections.push("```");
      sections.push(testFailure.errorMessage);
      sections.push("```");
      sections.push("");
    }

    // Failure Summary
    if (testFailure.summary) {
      sections.push("### Failure Summary");
      sections.push("");
      sections.push(testFailure.summary);
      sections.push("");
    }

    // Steps to Reproduce
    if (testFailure.stepsToReproduce) {
      sections.push("### Steps to Reproduce");
      sections.push("");
      if (Array.isArray(testFailure.stepsToReproduce)) {
        testFailure.stepsToReproduce.forEach((step, index) => {
          sections.push(`${index + 1}. ${step}`);
        });
      } else {
        sections.push(testFailure.stepsToReproduce);
      }
      sections.push("");
    } else {
      sections.push("### Steps to Reproduce");
      sections.push("");
      sections.push(`1. Run test command: \`npm run test:aolite -- ${testFailure.testFile}\``);
      sections.push("2. Observe test failure");
      sections.push("");
    }

    // Expected vs Actual
    if (testFailure.expectedBehavior || testFailure.actualBehavior) {
      sections.push("### Expected vs Actual Behavior");
      sections.push("");
      if (testFailure.expectedBehavior) {
        sections.push(`**Expected:** ${testFailure.expectedBehavior}`);
      }
      if (testFailure.actualBehavior) {
        sections.push(`**Actual:** ${testFailure.actualBehavior}`);
      }
      sections.push("");
    }

    // Coverage Impact
    if (testFailure.coverageImpact) {
      sections.push("### Coverage Impact");
      sections.push("");
      sections.push(testFailure.coverageImpact);
      sections.push("");
    }

    // Environment Information
    sections.push("### Environment");
    sections.push("");
    sections.push(`**Timestamp:** ${testFailure.timestamp || new Date().toISOString()}`);
    sections.push(`**Branch:** ${testFailure.branch || "unknown"}`);
    sections.push(`**Commit:** ${testFailure.commit || "unknown"}`);
    if (testFailure.testRunner) {
      sections.push(`**Test Runner:** ${testFailure.testRunner}`);
    }
    sections.push("");

    // Metadata
    if (testFailure.metadata) {
      sections.push("### Additional Metadata");
      sections.push("");
      sections.push("```json");
      sections.push(JSON.stringify(testFailure.metadata, null, 2));
      sections.push("```");
      sections.push("");
    }

    // Related Information
    if (testFailure.relatedIssues && testFailure.relatedIssues.length > 0) {
      sections.push("### Related Issues");
      sections.push("");
      testFailure.relatedIssues.forEach(issue => {
        sections.push(`- #${issue}`);
      });
      sections.push("");
    }

    // Action Items
    sections.push("### Action Items");
    sections.push("");
    sections.push("- [ ] Investigate root cause of test failure");
    sections.push("- [ ] Fix failing test or update test expectations");
    sections.push("- [ ] Verify fix with local test run");
    sections.push("- [ ] Ensure test coverage is maintained");
    sections.push("- [ ] Update related documentation if needed");
    sections.push("");

    // Footer
    sections.push("---");
    sections.push("");
    sections.push("*This issue was automatically generated by the TDD monitoring system.*");
    sections.push(`*Issue created at: ${new Date().toISOString()}*`);

    return sections.join("\n");
  }

  // Find existing issue for this test failure
  async findExistingIssue(testFailure) {
    try {
      const cacheKey = this.getIssueCacheKey(testFailure);
      if (this.issueCache.has(cacheKey)) {
        return this.issueCache.get(cacheKey);
      }

      // Search for existing issues
      const searchQuery = `repo:${this.config.owner}/${this.config.repo} is:open label:test-failure "${testFailure.testFile}"`;

      const searchResponse = await this.octokit.rest.search.issues({
        q: searchQuery,
      });

      if (searchResponse.data.items.length > 0) {
        const issue = searchResponse.data.items[0];
        this.issueCache.set(cacheKey, issue);
        return issue;
      }

      return null;
    } catch (error) {
      console.error("Failed to search for existing issues:", error.message);
      return null;
    }
  }

  // Update existing issue with new failure information
  async updateExistingIssue(existingIssue, testFailure) {
    try {
      const updateComment = this.generateUpdateComment(testFailure);

      if (this.config.dryRun) {
        console.log("DRY RUN - Would update issue with comment:", updateComment);
        return existingIssue;
      }

      // Add comment to existing issue
      await this.octokit.rest.issues.createComment({
        owner: this.config.owner,
        repo: this.config.repo,
        issue_number: existingIssue.number,
        body: updateComment,
      });

      // Update labels if needed
      const currentLabels = existingIssue.labels.map(label => (typeof label === "string" ? label : label.name));

      const newLabels = [
        this.getFailureTypeLabel(testFailure.failureType),
        this.getPriorityLabel(testFailure.priority),
      ].filter(label => label && !currentLabels.includes(label));

      if (newLabels.length > 0) {
        await this.octokit.rest.issues.addLabels({
          owner: this.config.owner,
          repo: this.config.repo,
          issue_number: existingIssue.number,
          labels: newLabels,
        });
      }

      console.log(`Updated existing issue #${existingIssue.number}`);
      return existingIssue;
    } catch (error) {
      console.error("Failed to update existing issue:", error.message);
      throw error;
    }
  }

  // Generate update comment for existing issue
  generateUpdateComment(testFailure) {
    const sections = [];

    sections.push("## 🔄 Test Failure Update");
    sections.push("");
    sections.push(`**Timestamp:** ${testFailure.timestamp || new Date().toISOString()}`);
    sections.push(`**Commit:** ${testFailure.commit || "unknown"}`);
    sections.push("");

    if (testFailure.errorMessage) {
      sections.push("### Latest Error");
      sections.push("");
      sections.push("```");
      sections.push(testFailure.errorMessage);
      sections.push("```");
      sections.push("");
    }

    if (testFailure.summary) {
      sections.push("### Summary");
      sections.push("");
      sections.push(testFailure.summary);
      sections.push("");
    }

    sections.push("*This update was automatically generated by the TDD monitoring system.*");

    return sections.join("\n");
  }

  // Close resolved test failure issues
  async closeResolvedIssues(resolvedTests) {
    const results = [];

    for (const test of resolvedTests) {
      try {
        const existingIssue = await this.findExistingIssue(test);
        if (existingIssue && existingIssue.state === "open") {
          const closeComment = `## ✅ Test Failure Resolved

This test is now passing. Automatically closing issue.

**Resolution Details:**
- Test Status: ✅ Passing
- Resolved at: ${new Date().toISOString()}
- Commit: ${test.commit || "unknown"}

*This issue was automatically closed by the TDD monitoring system.*`;

          if (this.config.dryRun) {
            console.log(`DRY RUN - Would close issue #${existingIssue.number}`);
            results.push({ issue: existingIssue.number, action: "close", status: "dry-run" });
            continue;
          }

          // Add closing comment
          await this.octokit.rest.issues.createComment({
            owner: this.config.owner,
            repo: this.config.repo,
            issue_number: existingIssue.number,
            body: closeComment,
          });

          // Close the issue
          await this.octokit.rest.issues.update({
            owner: this.config.owner,
            repo: this.config.repo,
            issue_number: existingIssue.number,
            state: "closed",
          });

          console.log(`Closed resolved issue #${existingIssue.number}`);
          results.push({ issue: existingIssue.number, action: "close", status: "success" });
        }
      } catch (error) {
        console.error(`Failed to close issue for ${test.testFile}:`, error.message);
        results.push({ test: test.testFile, action: "close", status: "error", error: error.message });
      }
    }

    return results;
  }

  // Utility methods
  getIssueCacheKey(testFailure) {
    return `${testFailure.testFile}:${testFailure.testCase || "suite"}`;
  }

  getFailureTypeLabel(failureType) {
    const labelMap = {
      assertion: "failure:assertion",
      runtime: "failure:runtime",
      timeout: "failure:timeout",
      coverage: "failure:coverage",
      compliance: "failure:tdd-compliance",
      integration: "failure:integration",
      performance: "failure:performance",
    };

    return labelMap[failureType?.toLowerCase()] || "failure:other";
  }

  getPriorityLabel(priority) {
    const labelMap = {
      critical: "priority:critical",
      high: "priority:high",
      medium: "priority:medium",
      low: "priority:low",
    };

    return labelMap[priority?.toLowerCase()] || "priority:medium";
  }

  // Batch process test failures
  async processTestFailures(testFailures) {
    const results = [];

    for (const failure of testFailures) {
      try {
        const issue = await this.createTestFailureIssue(failure);
        results.push({
          testFile: failure.testFile,
          issueNumber: issue.number,
          issueUrl: issue.html_url,
          status: "success",
        });
      } catch (error) {
        results.push({
          testFile: failure.testFile,
          status: "error",
          error: error.message,
        });
      }
    }

    return results;
  }

  // Generate summary report
  generateSummaryReport(results) {
    const successful = results.filter(r => r.status === "success");
    const failed = results.filter(r => r.status === "error");

    return {
      total: results.length,
      successful: successful.length,
      failed: failed.length,
      issues: successful.map(r => ({
        testFile: r.testFile,
        issueNumber: r.issueNumber,
        issueUrl: r.issueUrl,
      })),
      errors: failed.map(r => ({
        testFile: r.testFile,
        error: r.error,
      })),
    };
  }
}

// Command-line interface
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command) {
    console.log("Usage:");
    console.log("  node github-integration.js create <test-failures.json>");
    console.log("  node github-integration.js close <resolved-tests.json>");
    console.log("  node github-integration.js process <test-results.json>");
    process.exit(1);
  }

  // Check if GitHub token is available
  if (!process.env.GITHUB_TOKEN) {
    console.log("⚠️  GitHub integration disabled: No GITHUB_TOKEN found");
    console.log("   This is normal for CI environments without issue tracking permissions");
    console.log("   Test failures will be reported in logs only");
    process.exit(0); // Exit successfully without processing
  }

  const github = new GitHubIntegration({
    dryRun: process.env.DRY_RUN === "true",
  });

  async function main() {
    try {
      if (command === "create" && args[1]) {
        const failuresFile = args[1];
        const failures = JSON.parse(fs.readFileSync(failuresFile, "utf8"));
        const results = await github.processTestFailures(failures);
        const summary = github.generateSummaryReport(results);
        console.log("Summary:", JSON.stringify(summary, null, 2));
      } else if (command === "close" && args[1]) {
        const resolvedFile = args[1];
        const resolved = JSON.parse(fs.readFileSync(resolvedFile, "utf8"));
        const results = await github.closeResolvedIssues(resolved);
        console.log("Closed issues:", results);
      } else {
        console.error("Invalid command or missing file argument");
        process.exit(1);
      }
    } catch (error) {
      console.error("Error:", error.message);
      process.exit(1);
    }
  }

  main();
}

export default GitHubIntegration;
