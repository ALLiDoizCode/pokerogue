# TDD Workflow Guide

## Overview

This guide explains the Test-Driven Development (TDD) workflow integrated into the PokéRogue AO Migration project. Our TDD system enforces test-first development, provides comprehensive coverage reporting, and automatically manages test failures through GitHub issue integration.

## Quick Start

### Running Tests

```bash
# Run all tests with coverage and dashboard
npm run tdd:dashboard

# Watch mode for continuous testing
npm run tdd:watch

# Run specific test file
npm run tdd:run -- testing/unit/battle-engine.test.lua

# Generate test skeletons for new files
npm run tdd:generate-tests -- ao-processes/my-new-process.lua
```

### VS Code Integration

The project includes pre-configured VS Code tasks and debug configurations:

1. **Ctrl+Shift+P** → "Tasks: Run Task"
2. Select from available TDD tasks:
   - 🧪 Run All Tests
   - 🧪 Run Current Test File
   - 🔧 Generate Test Skeleton
   - 📊 Generate Coverage Report
   - 📈 Open Coverage Dashboard

## TDD Workflow

### 1. Write Failing Tests First

Before implementing any functionality:

```lua
-- testing/unit/new-feature.test.lua
describe("New Feature", function()
    it("should work with valid input", function()
        -- Arrange
        local input = {valid = true}
        
        -- Act
        local result = newFeature(input)
        
        -- Assert
        assert.is_not_nil(result)
        assert.equals("success", result.status)
    end)
end)
```

### 2. Run Tests to Confirm Failure

```bash
npm run test:aolite -- testing/unit/new-feature.test.lua
```

### 3. Implement Minimum Code to Pass

```lua
-- ao-processes/new-feature.lua
function newFeature(input)
    if input and input.valid then
        return {status = "success"}
    end
    return {status = "error"}
end
```

### 4. Run Tests to Confirm Pass

```bash
npm run test:aolite -- testing/unit/new-feature.test.lua
```

### 5. Refactor and Repeat

Continue the Red-Green-Refactor cycle.

## Test Organization

### Test File Structure

```
testing/
├── unit/                           # Unit tests (aolite)
│   ├── battle-engine.test.lua
│   ├── pokemon-manager.test.lua
│   └── stat-calculator.test.lua
├── integration/                    # Integration tests (aos-local)
│   ├── message-flow.test.lua
│   └── process-coordination.test.lua
├── parity/                         # TypeScript-AO parity tests
│   ├── calculation-parity.test.lua
│   └── behavior-parity.test.lua
└── coverage/                       # Coverage reports
    ├── coverage-report.json
    └── html/
```

### Test Naming Convention

- **Test Files**: `*.test.lua` or `*.spec.lua`
- **Test Suites**: Descriptive names (e.g., "Battle Engine Tests")
- **Test Cases**: Should statements (e.g., "should calculate damage correctly")

### Test Templates

Use the automated test generator to create consistent test structures:

```bash
# Generate unit test template
npm run tdd:generate-tests -- ao-processes/my-process.lua

# Templates available:
# - unit-test.template.lua      (for utility functions)
# - integration-test.template.lua (for process workflows)
# - handler-test.template.lua   (for AO message handlers)
```

## Coverage Requirements

### Minimum Thresholds

- **Critical Files** (stat calculations, RNG): 100% line and function coverage
- **Core Game Logic**: 95% line coverage, 95% function coverage
- **General Code**: 80% line coverage, 80% function coverage

### Coverage Monitoring

```bash
# Generate coverage report
npm run coverage:report

# View coverage dashboard
npm run tdd:dashboard

# Check coverage for specific file
lua scripts/coverage/lua-coverage-collector.lua instrument ao-processes/my-file.lua
```

## Pre-commit Hooks

### TDD Validation

The pre-commit hook automatically:

1. **Validates test existence** for modified Lua files
2. **Runs tests** to ensure they pass
3. **Checks coverage** against thresholds
4. **Blocks commits** if TDD requirements not met

### Bypassing Hooks (Emergency Only)

```bash
# Emergency bypass (logged and monitored)
git commit --no-verify -m "Emergency fix"

# Check bypass log
cat .git/tdd-bypass.log
```

## Continuous Integration

### GitHub Actions Workflows

#### TDD Validation Workflow
- **Triggers**: Push to main, beta, ECS branches; Pull requests
- **Actions**: 
  - Validates test compliance
  - Runs comprehensive test suite
  - Creates GitHub issues for failures
  - Closes issues for resolved tests

#### Coverage Reporting
- **Triggers**: After successful tests
- **Actions**:
  - Collects coverage data
  - Generates reports
  - Updates coverage badges
  - Uploads artifacts

### Branch Protection

Main and beta branches require:
- ✅ All TDD validation checks pass
- ✅ Coverage thresholds met
- ✅ No test failures
- ✅ Pre-commit hooks executed

## Issue Tracking Integration

### Automatic Issue Creation

When tests fail in CI:

1. **Issue Created** with detailed failure information
2. **Labels Applied**: `test-failure`, `priority:medium`, `failure:assertion`
3. **Assignees Added** (if configured)
4. **Tracking Enabled** for resolution monitoring

### Issue Resolution

When tests pass again:

1. **Issue Updated** with resolution comment
2. **Issue Closed** automatically
3. **History Logged** for audit trail

### Manual Issue Management

```bash
# Create issues for current failures
npm run tdd:create-issues -- testing/reports/test-failures.json

# Close resolved issues
npm run tdd:close-resolved-issues -- testing/reports/resolved-tests.json

# View issue mapping report
node tools/issue-linker/test-issue-mapper.js report
```

## Test Documentation

### Automatic Generation

```bash
# Generate documentation for test file
npm run tdd:generate-docs -- testing/unit/my-test.test.lua

# Batch generate for all tests
find testing/ -name "*.test.lua" -exec npm run tdd:generate-docs -- {} \;
```

### Documentation Outputs

- **Markdown**: Human-readable test specifications
- **HTML**: Interactive test documentation with navigation
- **JSON**: Machine-readable test metadata

## Performance Optimization

### Test Execution Speed

- **Parallel Execution**: Tests run in parallel where possible
- **Smart Test Selection**: Only run tests for changed files in watch mode
- **Caching**: Test results cached to avoid re-running unchanged tests

### Coverage Collection Optimization

- **Instrumentation**: Minimal overhead custom coverage collector
- **Selective Collection**: Only instrument files under test
- **Efficient Reporting**: Fast JSON-based coverage format

## Troubleshooting

### Common Issues

#### "Missing test file" Error
```bash
# Generate test file
npm run tdd:generate-tests -- path/to/source-file.lua

# Or create manually following template
cp scripts/generators/templates/unit-test.template.lua testing/unit/my-test.test.lua
```

#### "Test file exists but tests failing"
```bash
# Run specific test with verbose output
npm run test:aolite -- --verbose testing/unit/failing-test.test.lua

# Check test file syntax
lua -c testing/unit/failing-test.test.lua
```

#### "Coverage below threshold"
```bash
# Check current coverage
npm run coverage:report

# Identify uncovered lines
npm run tdd:dashboard
# Navigate to file coverage details
```

#### "Pre-commit hook fails"
```bash
# Validate manually
npm run tdd:validate -- path/to/file.lua

# Fix failing tests
npm run test:aolite -- testing/unit/related-test.test.lua

# Check coverage
npm run coverage:report
```

### Debug Configuration

VS Code debug configurations included for:

- **Lua Test Debugging**: Step through test execution
- **aolite Integration**: Debug test framework integration
- **Coverage Collection**: Debug coverage instrumentation
- **GitHub Integration**: Debug issue creation/resolution

### Getting Help

1. **Check Documentation**: This guide and architecture docs
2. **Run Diagnostics**: `npm run tdd:validate`
3. **View Dashboard**: `npm run tdd:dashboard`
4. **Check Logs**: `.git/tdd-bypass.log`, `testing/reports/`
5. **Create Issue**: Use GitHub issue templates for TDD problems

## Best Practices

### Writing Effective Tests

#### Arrange-Act-Assert Pattern
```lua
describe("Pokemon Stat Calculator", function()
    it("should calculate HP with nature modifier", function()
        -- Arrange
        local baseStat = 100
        local level = 50
        local iv = 31
        local ev = 252
        local natureModifier = 1.1 -- +Nature
        
        -- Act
        local result = calculateHP(baseStat, level, iv, ev, natureModifier)
        
        -- Assert
        assert.equals(207, result) -- Expected HP value
    end)
end)
```

#### Test Edge Cases
```lua
describe("Edge Cases", function()
    it("should handle nil input gracefully", function()
        local result = calculateHP(nil, 50, 31, 252, 1.0)
        assert.is_nil(result) -- or appropriate error handling
    end)
    
    it("should handle zero level", function()
        local result = calculateHP(100, 0, 31, 252, 1.0)
        assert.equals(1, result) -- Minimum HP
    end)
    
    it("should handle maximum values", function()
        local result = calculateHP(255, 100, 31, 252, 1.1)
        assert.is_true(result > 0) -- Reasonable bounds check
    end)
end)
```

#### Mock AO Environment
```lua
-- Setup test environment for AO processes
local function setupTestEnvironment()
    if not ao then
        ao = {
            send = function(msg) 
                print("Mock ao.send:", json.encode(msg))
            end,
            id = "test_process_id"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
            end
        }
    end
end
```

### Maintaining Test Quality

#### Regular Test Review
- **Weekly**: Review test coverage reports
- **Monthly**: Analyze test failure patterns
- **Quarterly**: Update test documentation

#### Test Maintenance
- **Keep Tests Simple**: One concept per test
- **Update Tests with Code**: Tests should evolve with implementation
- **Remove Obsolete Tests**: Clean up tests for removed features

#### Performance Monitoring
- **Test Execution Time**: Keep tests fast (< 100ms per test)
- **Coverage Collection**: Monitor overhead (< 10% slowdown)
- **CI Pipeline Time**: Total pipeline should complete in < 10 minutes

## Advanced Features

### Custom Test Runners

Create specialized test runners for specific scenarios:

```bash
# Custom runner example
scripts/tdd/test-runner-wrapper.sh --runner custom --pattern "performance/*"
```

### Integration with External Tools

#### Git Hooks
- **Pre-push**: Run full test suite before pushing
- **Post-merge**: Update test documentation after merges

#### IDE Integration
- **Test Explorer**: VS Code extension for test navigation
- **Live Coverage**: Real-time coverage highlighting
- **Test Generation**: Context menu integration

### Metrics and Analytics

#### Test Metrics Dashboard
- **Pass Rate Trends**: Track test stability over time
- **Coverage Evolution**: Monitor coverage improvements
- **Failure Analysis**: Identify patterns in test failures

#### Performance Analytics
- **Test Execution Trends**: Monitor test performance
- **Coverage Collection Overhead**: Optimize instrumentation
- **CI Pipeline Efficiency**: Identify bottlenecks

---

## Summary

The TDD workflow in PokéRogue ensures:

1. **Quality**: All code has corresponding tests
2. **Coverage**: Comprehensive test coverage with thresholds
3. **Automation**: Pre-commit hooks and CI/CD integration
4. **Visibility**: Dashboard and reporting for monitoring
5. **Collaboration**: GitHub issue integration for team coordination

Follow this workflow to maintain high code quality and ensure reliable, well-tested implementations of game mechanics and AO processes.

For additional help, refer to:
- [Architecture Documentation](./architecture/)
- [Testing Standards](./architecture/test-strategy-and-standards.md)
- [GitHub Issue Templates](./.github/ISSUE_TEMPLATE/)
- [VS Code Configuration](./.vscode/)