# /research-ao-tdd-strategy Task

When this command is used, execute the following task:

<!-- Powered by BMAD™ Core -->

# Research AO TDD Strategy Task

This command executes comprehensive research on Test-Driven Development (TDD) strategies for stateless AO (Arweave Operating System) Lua processes using the aolite testing framework.

## Purpose

Develop an enhanced TDD strategy addressing specific pain points in the 26-process stateless architecture, focusing on:
- Linear execution test patterns (non-describe/it)
- Aolite framework optimization
- Process handler discovery automation
- State management in sequential tests
- Test coverage and quality gates

## Execution

When this command is invoked, execute the research prompt defined below using available resources (MCP servers, documentation, codebase analysis).

---

## Research Objective

Develop an enhanced Test-Driven Development (TDD) strategy and implementation approach for **stateless AO (Arweave Operating System) Lua processes** using the **aolite testing framework**, addressing specific pain points in the current 26-process architecture testing approach and improving test reliability, coverage, and maintainability.

## Background Context

**Project**: PokéRogue Stateless AO Processes
**Architecture**: 26-Process Stateless Architecture with Async Coordination
**Current Testing Infrastructure**:
- **125 unit test files** using aolite framework (Lua-based)
- **95 tests migrated** to correct aolite API (77% of total)
- **26 tests blocked** requiring full rewrite from describe/it to linear execution
- **77 AO process files** requiring test coverage
- **3 testing layers**: Unit (aolite), Parity (Lua vs TS), Integration (aos-local)

**Recent Migration Context** (Story 20.1):
- Successfully migrated from custom mock patterns to real aolite framework
- Discovered API misalignment causing test failures
- Identified architectural pattern incompatibilities (describe/it vs linear execution)
- Established correct aolite API pattern as baseline

**Current Pain Points**:
1. **26 blocked tests** using describe/it framework (incompatible with aolite)
2. **Action name discovery** required per-process (no standardization)
3. **Consolidated process testing** (14 tests map to 4 core processes)
4. **State management** across sequential test execution
5. **Test coverage gaps** for process coordination patterns
6. **Validation overhead** for AO compliance in tests

---

## Research Questions

### Primary Questions (Must Answer)

1. **Test Architecture Patterns**:
   - What are the best practices for structuring linear execution tests (non-describe/it) while maintaining readability and maintainability?
   - How should test state management be handled when tests execute sequentially on a single process instance?
   - What design patterns enable independent tests that don't rely on execution order?

2. **Aolite Framework Optimization**:
   - What are the comprehensive capabilities and limitations of the aolite framework for AO process testing?
   - How can the aolite message passing simulation be leveraged for better test isolation?
   - What strategies exist for mocking/stubbing inter-process communication in aolite?

3. **Process Action Discovery**:
   - How can action response naming conventions be standardized across 77 processes?
   - What automation strategies can reduce per-process handler inspection overhead?
   - Should processes implement ADP (AO Documentation Protocol) v1.0 for self-documenting capabilities?

4. **Consolidated Process Testing**:
   - How should sub-functionality tests be structured when multiple test files map to single consolidated processes?
   - What test organization patterns work best for testing specific handlers within large monolithic processes?
   - How can test context be established to validate specific process behaviors without full integration?

5. **Coverage & Quality Gates**:
   - What test coverage metrics are appropriate for stateless AO processes?
   - How should handler coverage be measured and enforced?
   - What automated validation can prevent AO compliance violations during test development?

### Secondary Questions (Nice to Have)

6. **Performance Testing Integration**:
   - How can sub-5-second execution targets be validated in unit tests?
   - What profiling strategies work within the aolite framework?

7. **Parity Test Strategy**:
   - How should Lua vs TypeScript behavioral parity tests be structured?
   - What criteria determine when parity tests are necessary vs redundant?

8. **Integration Test Boundaries**:
   - What scenarios require integration tests (aos-local) vs unit tests (aolite)?
   - How can test duplication be minimized across testing layers?

---

## Research Methodology

### Information Sources

**Use these resources in order of priority:**

1. **Aolite Framework Documentation** (via MCP)
   - Tool: `mcp__aolite_Docs__fetch_aolite_documentation`
   - Tool: `mcp__aolite_Docs__search_aolite_documentation`
   - Focus: API reference, examples, concurrency model

2. **Permaweb Documentation** (via MCP)
   - Tool: `mcp__permamind__queryPermawebDocs`
   - Domains: `ao` (AO protocol, handler patterns)
   - Focus: ADP v1.0 specification, message passing conventions

3. **Codebase Analysis**
   - Working examples: `testing/unit/pokemon-species-db.test.lua`
   - Correct pattern: `.ai/correct-aolite-test-pattern.lua`
   - Blocked tests: 26 files with describe/it patterns
   - Process files: `processes/*.lua` (77 files)

4. **Web Research** (if needed)
   - Lua testing best practices
   - TDD patterns for stateless/functional systems
   - Message-passing architecture testing strategies

### Analysis Frameworks

**Framework 1: Test Pattern Analysis Matrix**
Evaluate patterns across:
- Readability (1-5 scale)
- Maintainability (effort to modify)
- Isolation (test independence)
- Coverage (handler/scenario coverage)
- Performance (execution time)

**Framework 2: Aolite Capability Assessment**
Systematic feature evaluation:
- Process spawning and lifecycle
- Message queuing and scheduling
- State inspection capabilities
- Error handling and debugging
- Logging and diagnostics

**Framework 3: Migration Complexity Scoring**
Assess blocked test rewrites by:
- Number of test cases
- State dependency complexity
- Process action discovery requirements
- Estimated rewrite time

---

## Expected Deliverables

### Executive Summary

Provide:
1. **Current State Assessment**: 3-4 key findings about test strategy strengths/weaknesses
2. **Critical Pain Point Analysis**: Root causes of blocked tests and state management issues
3. **Recommended Strategy**: High-level TDD enhancement approach (1-2 paragraphs)
4. **Implementation Priority**: Ranking of improvements by impact vs effort
5. **Success Metrics**: KPIs for measuring TDD strategy effectiveness

### Detailed Analysis

**Section 1: Linear Execution Test Patterns** (CRITICAL)
- Best practices for tests without describe/it/before_each/after_each
- Code examples for common scenarios:
  - Independent tests (preferred)
  - State-dependent test sequences
  - Error handling and cleanup
  - Test organization and naming
- Comparison matrix: describe/it vs linear execution trade-offs

**Section 2: Aolite Framework Deep Dive**
- Comprehensive API reference with examples
- Message passing patterns for test scenarios
- State inspection techniques
- Debugging and logging best practices
- Performance optimization tips

**Section 3: Process Testing Architecture**
- Handler discovery automation strategies
- Consolidated process testing patterns
- Test file organization approaches
- Test reusability patterns

**Section 4: Implementation Roadmap**
- **Phase 1**: Fix 26 blocked describe/it tests (by complexity)
  - Story 20.3a: Direct 1:1 mapping (11 files, 8-10 hours)
  - Story 20.3b: Consolidated processes (14 files, 10-12 hours)
  - Story 20.3c: Framework tests (1 file, 2-3 hours)
- **Phase 2**: Handler discovery automation (4-6 hours)
- **Phase 3**: Enhanced TDD validation (4-5 hours)
- **Phase 4**: Documentation and training (2-3 hours)

**Section 5: Quality Assurance Strategy**
- Test coverage metrics and targets
- Handler coverage validation
- AO compliance automation
- Pre-commit hook enhancements
- CI/CD integration requirements

### Supporting Materials

**Code Templates** (Production-Ready):
1. Linear execution test template
2. Consolidated process test template
3. Handler discovery script template
4. Test utility functions library

**Comparison Matrices**:
1. Test pattern comparison (describe/it vs linear vs hybrid)
2. Aolite vs aos-local capabilities
3. Test layer boundaries (unit vs parity vs integration)

**Reference Documentation**:
- Annotated sources bibliography
- Aolite API quick reference
- AO compliance checklist
- Migration guide (describe/it → linear)

---

## Success Criteria

Research succeeds if it provides:

1. ✅ **Actionable patterns** for the 26 blocked test rewrites
2. ✅ **Clear guidance** on aolite framework with production examples
3. ✅ **Automation strategies** reducing testing overhead by 50%+
4. ✅ **Quality gates** preventing test pattern regressions
5. ✅ **Implementation roadmap** with realistic time estimates
6. ✅ **Code templates** ready to copy-paste and adapt

**Validation Approach**:
- Test patterns on 2-3 sample blocked tests before full migration
- Validate templates against existing working tests
- Calibrate time estimates against Story 20.1 actuals

---

## Research Execution Steps

When this command runs, execute these steps:

### Step 1: Query Aolite Documentation
Use `mcp__aolite_Docs__fetch_aolite_documentation` to get comprehensive framework documentation.

### Step 2: Query AO Protocol Documentation
Use `mcp__permamind__queryPermawebDocs` with domain `ao` to understand:
- ADP v1.0 specification
- Handler registration patterns
- Message passing conventions
- Process lifecycle management

### Step 3: Analyze Codebase Examples
Read and analyze:
- `testing/unit/pokemon-species-db.test.lua` (working example)
- `.ai/correct-aolite-test-pattern.lua` (template)
- 2-3 blocked describe/it tests for complexity assessment

### Step 4: Synthesize Findings
Create structured output with:
- Executive summary (current state, recommendations, priorities)
- Detailed analysis (5 sections as outlined)
- Supporting materials (templates, matrices, references)

### Step 5: Validate Recommendations
- Test patterns against working examples
- Verify aolite API usage against documentation
- Ensure recommendations align with AO compliance requirements

---

## Output Format

Present findings in this structure:

```markdown
# AO TDD Strategy Research Report
Generated: [date]

## Executive Summary
[Current state, critical issues, recommendations, priorities, metrics]

## Section 1: Linear Execution Test Patterns
[Best practices, code examples, comparison matrix]

## Section 2: Aolite Framework Deep Dive
[API reference, message patterns, debugging, performance]

## Section 3: Process Testing Architecture
[Handler discovery, consolidated testing, organization]

## Section 4: Implementation Roadmap
[Phased approach with time estimates]

## Section 5: Quality Assurance Strategy
[Coverage metrics, validation automation, CI/CD]

## Supporting Materials
### Code Templates
[Production-ready templates]

### Comparison Matrices
[Pattern comparisons, capability matrices]

### Reference Documentation
[Quick references, checklists, guides]

## Validation Results
[Pattern testing, API verification, compliance check]

## Next Steps
[Immediate actions, pilot tests, team review]
```

---

## Additional Context

**Project Constraints**:
- Monolithic process design (no external dependencies)
- 500KB process size limit
- Sub-5-second execution targets
- AO compliance (strict sandbox rules)

**Development Environment**:
- Aolite: `development-tools/aolite/`
- Lua version: 5.3
- Test runner: `npm run test:aolite`
- Pre-commit: `scripts/hooks/tdd-pre-commit.sh`

**Reference Files**:
- Correct pattern: `.ai/correct-aolite-test-pattern.lua`
- Working test: `testing/unit/pokemon-species-db.test.lua`
- Story context: `docs/stories/story-20.3-rewrite-describe-it-tests.md`
- Migration notes: `docs/stories/story-20.1-aolite-test-migration.md`

---

## Notes

- Research should take 4-6 hours
- Focus on actionable patterns for immediate use
- Prioritize blocked test rewrites (Story 20.3)
- Validate all code examples with real aolite API
- Ensure templates are production-ready
