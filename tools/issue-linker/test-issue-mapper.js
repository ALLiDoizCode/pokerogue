#!/usr/bin/env node

/**
 * Test Issue Mapper
 * Maps test failures to GitHub issues and manages test-issue relationships
 */

const fs = require("fs");
const path = require("path");

class TestIssueMapper {
  constructor(config = {}) {
    this.config = {
      mappingFile: config.mappingFile || "testing/reports/test-issue-mapping.json",
      issueHistoryFile: config.issueHistoryFile || "testing/reports/issue-history.json",
      maxHistoryEntries: config.maxHistoryEntries || 1000,
      autoCloseResolved: config.autoCloseResolved !== false,
      ...config,
    };

    this.mapping = this.loadMapping();
    this.history = this.loadHistory();
  }

  // Load existing test-issue mapping
  loadMapping() {
    try {
      if (fs.existsSync(this.config.mappingFile)) {
        const content = fs.readFileSync(this.config.mappingFile, "utf8");
        return JSON.parse(content);
      }
    } catch (error) {
      console.warn("Failed to load mapping file:", error.message);
    }

    return {
      version: "1.0",
      lastUpdated: new Date().toISOString(),
      testToIssues: {}, // testFile:testCase -> [issueNumbers]
      issueToTests: {}, // issueNumber -> {testFile, testCase, status}
      statistics: {
        totalMappings: 0,
        openIssues: 0,
        resolvedIssues: 0,
      },
    };
  }

  // Load issue history
  loadHistory() {
    try {
      if (fs.existsSync(this.config.issueHistoryFile)) {
        const content = fs.readFileSync(this.config.issueHistoryFile, "utf8");
        return JSON.parse(content);
      }
    } catch (error) {
      console.warn("Failed to load history file:", error.message);
    }

    return {
      version: "1.0",
      entries: [],
    };
  }

  // Save mapping to file
  saveMapping() {
    try {
      // Ensure directory exists
      const dir = path.dirname(this.config.mappingFile);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }

      this.mapping.lastUpdated = new Date().toISOString();
      this.updateStatistics();

      fs.writeFileSync(this.config.mappingFile, JSON.stringify(this.mapping, null, 2));
    } catch (error) {
      console.error("Failed to save mapping:", error.message);
      throw error;
    }
  }

  // Save history to file
  saveHistory() {
    try {
      // Ensure directory exists
      const dir = path.dirname(this.config.issueHistoryFile);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }

      // Limit history size
      if (this.history.entries.length > this.config.maxHistoryEntries) {
        this.history.entries = this.history.entries.slice(-this.config.maxHistoryEntries);
      }

      fs.writeFileSync(this.config.issueHistoryFile, JSON.stringify(this.history, null, 2));
    } catch (error) {
      console.error("Failed to save history:", error.message);
      throw error;
    }
  }

  // Map test failure to issue
  mapTestToIssue(testFailure, issueNumber, issueUrl) {
    const testKey = this.getTestKey(testFailure);

    // Update test-to-issue mapping
    if (!this.mapping.testToIssues[testKey]) {
      this.mapping.testToIssues[testKey] = [];
    }

    if (!this.mapping.testToIssues[testKey].includes(issueNumber)) {
      this.mapping.testToIssues[testKey].push(issueNumber);
    }

    // Update issue-to-test mapping
    this.mapping.issueToTests[issueNumber] = {
      testFile: testFailure.testFile,
      testCase: testFailure.testCase,
      testSuite: testFailure.testSuite,
      status: "open",
      failureType: testFailure.failureType,
      priority: testFailure.priority,
      createdAt: new Date().toISOString(),
      lastUpdated: new Date().toISOString(),
      url: issueUrl,
    };

    // Add to history
    this.addHistoryEntry({
      action: "mapped",
      testKey,
      issueNumber,
      testFailure,
      timestamp: new Date().toISOString(),
    });

    this.saveMapping();
    this.saveHistory();

    return {
      testKey,
      issueNumber,
      mapping: this.mapping.issueToTests[issueNumber],
    };
  }

  // Mark issue as resolved
  markIssueResolved(issueNumber, resolvedBy = "system") {
    if (!this.mapping.issueToTests[issueNumber]) {
      throw new Error(`Issue ${issueNumber} not found in mapping`);
    }

    const issueData = this.mapping.issueToTests[issueNumber];
    issueData.status = "resolved";
    issueData.resolvedAt = new Date().toISOString();
    issueData.resolvedBy = resolvedBy;
    issueData.lastUpdated = new Date().toISOString();

    // Add to history
    this.addHistoryEntry({
      action: "resolved",
      issueNumber,
      resolvedBy,
      testFile: issueData.testFile,
      testCase: issueData.testCase,
      timestamp: new Date().toISOString(),
    });

    this.saveMapping();
    this.saveHistory();

    return issueData;
  }

  // Mark issue as closed
  markIssueClosed(issueNumber, closedBy = "system") {
    if (!this.mapping.issueToTests[issueNumber]) {
      throw new Error(`Issue ${issueNumber} not found in mapping`);
    }

    const issueData = this.mapping.issueToTests[issueNumber];
    issueData.status = "closed";
    issueData.closedAt = new Date().toISOString();
    issueData.closedBy = closedBy;
    issueData.lastUpdated = new Date().toISOString();

    // Add to history
    this.addHistoryEntry({
      action: "closed",
      issueNumber,
      closedBy,
      testFile: issueData.testFile,
      testCase: issueData.testCase,
      timestamp: new Date().toISOString(),
    });

    this.saveMapping();
    this.saveHistory();

    return issueData;
  }

  // Find issues for a test
  findIssuesForTest(testFile, testCase = null) {
    const testKey = testCase ? `${testFile}:${testCase}` : testFile;

    // Exact match first
    if (this.mapping.testToIssues[testKey]) {
      return this.mapping.testToIssues[testKey].map(issueNumber => ({
        issueNumber,
        ...this.mapping.issueToTests[issueNumber],
      }));
    }

    // If no exact match and no test case provided, find all issues for the file
    if (!testCase) {
      const matchingIssues = [];
      for (const [key, issueNumbers] of Object.entries(this.mapping.testToIssues)) {
        if (key.startsWith(testFile + ":")) {
          matchingIssues.push(
            ...issueNumbers.map(issueNumber => ({
              issueNumber,
              ...this.mapping.issueToTests[issueNumber],
            })),
          );
        }
      }
      return matchingIssues;
    }

    return [];
  }

  // Find tests for an issue
  findTestsForIssue(issueNumber) {
    const issueData = this.mapping.issueToTests[issueNumber];
    if (!issueData) {
      return null;
    }

    return {
      issueNumber,
      ...issueData,
    };
  }

  // Get all open issues
  getOpenIssues() {
    const openIssues = [];

    for (const [issueNumber, issueData] of Object.entries(this.mapping.issueToTests)) {
      if (issueData.status === "open") {
        openIssues.push({
          issueNumber: Number.parseInt(issueNumber),
          ...issueData,
        });
      }
    }

    return openIssues.sort((a, b) => b.issueNumber - a.issueNumber);
  }

  // Get resolved issues that should be closed
  getResolvableIssues(passingTests) {
    const resolvableIssues = [];

    for (const [issueNumber, issueData] of Object.entries(this.mapping.issueToTests)) {
      if (issueData.status === "open") {
        const testKey = this.getTestKeyFromIssueData(issueData);
        const isTestPassing = passingTests.some(test => {
          const passedTestKey = this.getTestKey(test);
          return passedTestKey === testKey;
        });

        if (isTestPassing) {
          resolvableIssues.push({
            issueNumber: Number.parseInt(issueNumber),
            ...issueData,
          });
        }
      }
    }

    return resolvableIssues;
  }

  // Process test results and update mappings
  processTestResults(testResults) {
    const summary = {
      failingTests: [],
      passingTests: [],
      newFailures: [],
      resolvedFailures: [],
      persistentFailures: [],
    };

    // Categorize test results
    for (const testResult of testResults) {
      if (testResult.status === "failed") {
        summary.failingTests.push(testResult);

        // Check if this is a new failure
        const existingIssues = this.findIssuesForTest(testResult.testFile, testResult.testCase);

        if (existingIssues.length === 0) {
          summary.newFailures.push(testResult);
        } else {
          summary.persistentFailures.push(testResult);
        }
      } else if (testResult.status === "passed") {
        summary.passingTests.push(testResult);
      }
    }

    // Find resolved failures
    summary.resolvedFailures = this.getResolvableIssues(summary.passingTests);

    return summary;
  }

  // Generate test failure report
  generateFailureReport() {
    const openIssues = this.getOpenIssues();
    const report = {
      summary: {
        totalOpenIssues: openIssues.length,
        issuesByPriority: this.groupBy(openIssues, "priority"),
        issuesByType: this.groupBy(openIssues, "failureType"),
        oldestIssue: this.getOldestIssue(openIssues),
        newestIssue: this.getNewestIssue(openIssues),
      },
      openIssues: openIssues,
      statistics: this.mapping.statistics,
      lastUpdated: this.mapping.lastUpdated,
    };

    return report;
  }

  // Utility methods
  getTestKey(test) {
    return test.testCase ? `${test.testFile}:${test.testCase}` : test.testFile;
  }

  getTestKeyFromIssueData(issueData) {
    return issueData.testCase ? `${issueData.testFile}:${issueData.testCase}` : issueData.testFile;
  }

  addHistoryEntry(entry) {
    this.history.entries.push(entry);
  }

  updateStatistics() {
    const stats = {
      totalMappings: Object.keys(this.mapping.issueToTests).length,
      openIssues: 0,
      resolvedIssues: 0,
      closedIssues: 0,
      issuesByPriority: {},
      issuesByType: {},
    };

    for (const issueData of Object.values(this.mapping.issueToTests)) {
      if (issueData.status === "open") {
        stats.openIssues++;
      } else if (issueData.status === "resolved") {
        stats.resolvedIssues++;
      } else if (issueData.status === "closed") {
        stats.closedIssues++;
      }

      // Count by priority
      const priority = issueData.priority || "unknown";
      stats.issuesByPriority[priority] = (stats.issuesByPriority[priority] || 0) + 1;

      // Count by type
      const type = issueData.failureType || "unknown";
      stats.issuesByType[type] = (stats.issuesByType[type] || 0) + 1;
    }

    this.mapping.statistics = stats;
  }

  groupBy(array, key) {
    return array.reduce((groups, item) => {
      const value = item[key] || "unknown";
      groups[value] = (groups[value] || 0) + 1;
      return groups;
    }, {});
  }

  getOldestIssue(issues) {
    if (issues.length === 0) {
      return null;
    }
    return issues.reduce((oldest, current) =>
      new Date(current.createdAt) < new Date(oldest.createdAt) ? current : oldest,
    );
  }

  getNewestIssue(issues) {
    if (issues.length === 0) {
      return null;
    }
    return issues.reduce((newest, current) =>
      new Date(current.createdAt) > new Date(newest.createdAt) ? current : newest,
    );
  }

  // Export mapping data
  exportMapping(format = "json") {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const filename = `test-issue-mapping-${timestamp}.${format}`;

    let content;
    if (format === "json") {
      content = JSON.stringify(
        {
          mapping: this.mapping,
          history: this.history,
        },
        null,
        2,
      );
    } else if (format === "csv") {
      content = this.convertToCSV();
    }

    fs.writeFileSync(filename, content);
    return filename;
  }

  convertToCSV() {
    const headers = [
      "Issue Number",
      "Test File",
      "Test Case",
      "Test Suite",
      "Status",
      "Failure Type",
      "Priority",
      "Created At",
      "Last Updated",
      "Resolved At",
      "URL",
    ];

    const rows = [headers.join(",")];

    for (const [issueNumber, issueData] of Object.entries(this.mapping.issueToTests)) {
      rows.push(
        [
          issueNumber,
          `"${issueData.testFile}"`,
          `"${issueData.testCase || ""}"`,
          `"${issueData.testSuite || ""}"`,
          issueData.status,
          issueData.failureType || "",
          issueData.priority || "",
          issueData.createdAt,
          issueData.lastUpdated,
          issueData.resolvedAt || "",
          `"${issueData.url || ""}"`,
        ].join(","),
      );
    }

    return rows.join("\n");
  }

  // Clean up old resolved issues
  cleanupOldIssues(daysOld = 30) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);

    const removed = [];

    for (const [issueNumber, issueData] of Object.entries(this.mapping.issueToTests)) {
      if (issueData.status === "closed" && issueData.closedAt) {
        const closedDate = new Date(issueData.closedAt);
        if (closedDate < cutoffDate) {
          // Remove from mappings
          delete this.mapping.issueToTests[issueNumber];

          // Remove from test-to-issue mappings
          const testKey = this.getTestKeyFromIssueData(issueData);
          if (this.mapping.testToIssues[testKey]) {
            this.mapping.testToIssues[testKey] = this.mapping.testToIssues[testKey].filter(
              num => num !== Number.parseInt(issueNumber),
            );

            if (this.mapping.testToIssues[testKey].length === 0) {
              delete this.mapping.testToIssues[testKey];
            }
          }

          removed.push(issueNumber);
        }
      }
    }

    if (removed.length > 0) {
      this.saveMapping();
      console.log(`Cleaned up ${removed.length} old closed issues`);
    }

    return removed;
  }
}

// Command-line interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];

  const mapper = new TestIssueMapper();

  if (command === "map" && args.length >= 3) {
    const testFile = args[1];
    const issueNumber = Number.parseInt(args[2]);
    const testCase = args[3];

    const result = mapper.mapTestToIssue(
      {
        testFile,
        testCase,
      },
      issueNumber,
    );

    console.log("Mapped:", result);
  } else if (command === "resolve" && args[1]) {
    const issueNumber = Number.parseInt(args[1]);
    const result = mapper.markIssueResolved(issueNumber);
    console.log("Resolved:", result);
  } else if (command === "find-test" && args[1]) {
    const testFile = args[1];
    const testCase = args[2];
    const issues = mapper.findIssuesForTest(testFile, testCase);
    console.log("Issues:", issues);
  } else if (command === "find-issue" && args[1]) {
    const issueNumber = Number.parseInt(args[1]);
    const test = mapper.findTestsForIssue(issueNumber);
    console.log("Test:", test);
  } else if (command === "report") {
    const report = mapper.generateFailureReport();
    console.log(JSON.stringify(report, null, 2));
  } else if (command === "export") {
    const format = args[1] || "json";
    const filename = mapper.exportMapping(format);
    console.log(`Exported to: ${filename}`);
  } else if (command === "cleanup") {
    const days = Number.parseInt(args[1]) || 30;
    const removed = mapper.cleanupOldIssues(days);
    console.log(`Cleaned up ${removed.length} issues older than ${days} days`);
  } else {
    console.log("Usage:");
    console.log("  node test-issue-mapper.js map <testFile> <issueNumber> [testCase]");
    console.log("  node test-issue-mapper.js resolve <issueNumber>");
    console.log("  node test-issue-mapper.js find-test <testFile> [testCase]");
    console.log("  node test-issue-mapper.js find-issue <issueNumber>");
    console.log("  node test-issue-mapper.js report");
    console.log("  node test-issue-mapper.js export [format]");
    console.log("  node test-issue-mapper.js cleanup [days]");
  }
}

module.exports = TestIssueMapper;
