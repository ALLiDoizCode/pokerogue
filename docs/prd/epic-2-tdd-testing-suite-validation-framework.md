# Epic 2: TDD Testing Suite & Validation Framework

Establish comprehensive Test-Driven Development infrastructure using aolite for AO process testing, aos-local for deployment validation, and advanced multi-process testing frameworks to validate TypeScript→AO Lua migration parity before implementation of any epic functionality.

## Story 2.1: aolite Unit Testing Framework for AO Lua Processes
As a **TDD engineer**,  
I want **comprehensive aolite-based unit testing framework for AO process handlers and Lua process logic**,  
so that **I can write failing tests for Lua handlers first, then implement AO Lua functionality to make tests pass**.

### Acceptance Criteria
1. aolite testing environment configured with concurrent process emulation using coroutines for AO process
2. Message passing test framework validates Lua AO handler responses against expected game action outcomes
3. Handler unit testing covers all game action message types with comprehensive Lua test cases
4. Process state inspection allows validation of ECS world state after Lua handler execution
5. Mock external data sources (Arweave transactions) for isolated Lua handler unit testing
6. Test fixtures provide consistent game state scenarios for reproducible Lua testing
7. Automated test discovery and execution with clear pass/fail reporting for aolite tests
8. TDD workflow documentation guides developers in Lua handler test-first methodology

## Story 2.2: aos-local Deployment Testing Integration
As a **deployment validation engineer**,  
I want **aos-local integration for testing complete AO process deployment and validation**,  
so that **I can validate process deployment, bundling, and real AO environment compatibility**.

### Acceptance Criteria
1. aos-local environment configured for local AO process testing and validation
2. AO process deployment testing validates bundle size, initialization, and functionality
3. Multi-process coordination testing ensures all AO processes communicate correctly
4. End-to-end testing validates complete game scenarios from process deployment to gameplay
5. Performance benchmarking validates response times and resource usage in AO environment
6. External data fetching testing validates Arweave transaction access and caching
7. Process restart and recovery testing ensures state persistence and reliability
8. Integration with CI/CD pipeline for automated deployment validation

## Story 2.3: Advanced AO Lua Process Testing Framework
As a **AO process developer**,  
I want **advanced aolite testing framework for complex multi-process scenarios with parity validation**,  
so that **I can write comprehensive tests for advanced process interactions and state management**.

### Acceptance Criteria
1. Advanced aolite framework configured for multi-process scenario testing with message orchestration
2. Property-based testing using custom Lua generators validates process logic across comprehensive input ranges
3. Complex scenario tests cover advanced multi-process workflows with comprehensive validation
4. Performance benchmark testing measures process execution times against baseline requirements
5. Mock coordination testing isolates process logic from external dependencies using test doubles
6. Load testing validates process performance under high message volume scenarios
7. State persistence testing ensures proper ECS world state management across process restarts
8. Inter-process communication testing validates message integrity and routing between processes

## Story 2.4: TypeScript-AO Lua Parity Validation Suite
As a **parity validation specialist**,  
I want **comprehensive automated testing that validates 100% functional equivalence between TypeScript and AO Lua implementations**,  
so that **no behavioral differences exist between original and migrated code**.

### Acceptance Criteria
1. Golden master testing captures TypeScript outputs for identical inputs across all game mechanics
2. Regression testing automatically detects any behavioral changes during AO Lua migration
3. Equivalence testing validates mathematical calculations produce identical results (damage, stats, etc.)
4. Randomization testing ensures RNG produces identical sequences with same seeds
5. Edge case testing validates handling of boundary conditions and error states
6. Performance comparison testing ensures AO Lua implementation meets or exceeds TypeScript speed
7. State consistency testing validates ECS world state matches TypeScript game state
8. Comprehensive test coverage analysis ensures all code paths are validated

## Story 2.5: TDD Workflow Integration and Automation
As a **development process engineer**,  
I want **automated TDD workflow that enforces test-first development across all epics**,  
so that **no functionality is implemented without corresponding failing tests first**.

### Acceptance Criteria
1. Pre-commit hooks prevent code commits without corresponding passing tests
2. CI/CD pipeline enforces TDD workflow with test-first validation gates
3. Test coverage reporting ensures minimum coverage thresholds for all components
4. Automated test generation creates skeleton tests for new functionality requirements
5. Test documentation generation provides clear specifications from test cases
6. Test result visualization shows TDD progress and identifies uncovered functionality
7. Integration with issue tracking links failing tests to development tasks
8. Developer tooling provides easy test running and debugging capabilities

## Story 2.6: Multi-Process Integration Testing Framework
As a **integration testing engineer**,  
I want **comprehensive testing that validates seamless communication between AO Lua processes**,  
so that **all processes work together correctly with 100% parity to TypeScript reference**.

### Acceptance Criteria
1. Integration tests validate message passing between AO Lua process handlers
2. Process orchestration testing ensures proper coordination and communication of all 26 processes
3. End-to-end game scenario testing validates complete workflows across all process types
4. State synchronization testing ensures ECS world state consistency across process boundaries
5. Performance testing validates that multi-process architecture meets or exceeds TypeScript performance
6. Error handling testing validates graceful degradation when processes fail or become unavailable
7. Serialization testing validates data integrity across AO inter-process communication boundaries
8. Parity testing ensures identical outcomes across all process coordination patterns

## Story 2.7: Continuous Integration Testing Pipeline
As a **CI/CD engineer**,
I want **comprehensive automated testing pipeline that validates AO Lua processes (aolite/aos-local) and advanced multi-process scenarios**,
so that **quality gates prevent deployment of non-functional or non-parity code in the AO architecture**.

### Acceptance Criteria
1. Multi-stage pipeline validates aolite unit tests, aos-local deployment, advanced multi-process testing, and integration testing
2. Parallel testing execution for all process types reduces pipeline runtime while maintaining coverage
3. Quality gates prevent progression without passing tests in ALL process handlers AND coordination scenarios
4. Test result aggregation provides comprehensive reporting across aolite, aos-local, advanced testing, and integration frameworks
5. Notification system alerts developers of test failures with process-specific debugging information
6. Test artifact management stores results from all AO process testing frameworks
7. Environment management provides isolated testing environments for multi-process epic branches
8. Integration with code review process requires passing tests in all process types before merge approval

## Story 2.8: Migrate Direct 1:1 Mapping Tests
As a **TDD engineer**,
I want **to migrate 6 blocked describe/it test files with direct 1:1 process mappings to linear execution pattern using correct aolite API**,
so that **these straightforward tests execute successfully and validate the migration approach for more complex tests in Story 2.9**.

### Acceptance Criteria
1. 6 direct 1:1 mapping test files migrated from describe/it to linear execution pattern
2. Correct aolite API pattern applied: `aolite.spawnProcess(processId, source, tags)`, `aolite.send(msg)`, `aolite.getLastMsg(processId)`
3. Process handler action names validated and documented for each migrated test
4. All 6 migrated tests pass successfully: `npm run test:aolite`
5. Test coverage maintained or improved: No test cases lost during migration
6. Migration follows authoritative pattern from `.ai/correct-aolite-test-pattern.lua`
7. Handler inspection performed pre-migration to validate action response names
8. Migration lessons learned documented to inform Story 2.9 (consolidated tests)

## Story 2.9: Migrate Consolidated & Complex Tests
As a **TDD engineer**,
I want **to migrate the remaining 6 blocked describe/it test files (consolidated processes and complex integration tests) to linear execution pattern**,
so that **all 12 blocked tests are successfully migrated and 100% test coverage is achieved, applying lessons learned from Story 2.8**.

### Acceptance Criteria
1. 6 remaining test files migrated from describe/it to linear execution pattern
2. Correct aolite API pattern applied with special handling for consolidated processes
3. Process handler action names validated, including multi-test-to-process mappings documented
4. All 6 migrated tests pass successfully: `npm run test:aolite`
5. Test coverage maintained: No test cases lost during migration
6. Migration follows authoritative pattern and incorporates Story 2.8 lessons learned
7. Handler inspection performed with consolidated process mapping identified
8. Complete migration report: All 12 blocked tests now passing

## Story 2.10: Handler Discovery Tool + Pilot Enhanced ADP
As a **TDD engineer**,
I want **an automated handler inspection tool and enhanced ADP v1.0 template with tag schemas piloted on 5 diverse processes**,
so that **handler discovery is automated, tag schemas are validated, and a proven template exists for bulk application in Stories 2.11-2.13**.

### Acceptance Criteria
1. Handler inspection tool created: `scripts/inspect-process-handlers.sh` extracts handlers, actions, and response patterns
2. Enhanced ADP v1.0 template created with tag schemas: input tags, response tags, value types, examples
3. Pilot implementation on 5 diverse processes: data, logic, coordinator types
4. Handler inspection tool tested on all 77 process files with validated output
5. Enhanced ADP template validated: tag schemas enable automated test generation
6. Pilot processes fully documented with complete tag schemas
7. Template refinement complete based on pilot feedback
8. Documentation created: Template usage guide for Stories 2.11-2.13

## Story 2.11: Apply Enhanced ADP to Data Processes
As a **TDD engineer**,
I want **enhanced ADP v1.0 with tag schemas applied to all 25 data processes**,
so that **data process handlers are fully self-documenting with complete tag and response schemas**.

### Acceptance Criteria
1. Enhanced ADP applied to 25 data processes using validated template from Story 2.10
2. All data process Info handlers include complete tag schemas (input tags, response tags, examples)
3. Handler inspection validates schema completeness for all data processes
4. Info handler tests pass for all 25 data processes
5. Action naming conventions documented for data process patterns
6. Bulk application automated where possible (script/template-based)
7. Validation report generated: Schema coverage, handler documentation
8. CLAUDE.md updated with data process ADP patterns

## Story 2.12: Apply Enhanced ADP to Engine Processes
As a **TDD engineer**,
I want **enhanced ADP v1.0 with tag schemas applied to all 35 engine processes**,
so that **engine process handlers are fully self-documenting with complete tag and response schemas**.

### Acceptance Criteria
1. Enhanced ADP applied to 35 engine processes using validated template
2. All engine process Info handlers include complete tag schemas
3. Handler inspection validates schema completeness
4. Info handler tests pass for all 35 engine processes
5. Action naming conventions documented for engine patterns
6. Bulk application automated where possible
7. Validation report generated
8. CLAUDE.md updated with engine process ADP patterns

## Story 2.13: Apply Enhanced ADP to Specialized Processes
As a **TDD engineer**,
I want **enhanced ADP v1.0 with tag schemas applied to all remaining specialized processes (coordinator, security, misc)**,
so that **100% of 77 processes have complete self-documentation with tag schemas**.

### Acceptance Criteria
1. Enhanced ADP applied to remaining ~17 specialized processes
2. All specialized process Info handlers include complete tag schemas
3. Handler inspection validates schema completeness across ALL 77 processes
4. Info handler tests pass for all specialized processes
5. Action naming conventions documented for specialized process patterns
6. Final validation report: 77/77 processes with complete ADP compliance
7. Test template updated with handler discovery integration
8. CLAUDE.md updated with complete ADP implementation guide

## Story 2.14: Handler Coverage Validation
As a **TDD engineer**,
I want **automated handler coverage tracking that identifies which handlers are tested across all 77 processes**,
so that **test coverage gaps are visible, quality gates enforce minimum coverage, and untested handlers are prioritized**.

### Acceptance Criteria
1. Handler coverage tool created: Tracks handler test coverage (tested handlers / total handlers) for all 77 processes
2. Coverage calculation implemented: Parses processes for handlers, tests for invocations
3. Handler coverage report generated: Per-process and overall coverage with untested handlers list
4. Coverage threshold validation: Minimum 80% handler coverage enforced
5. CI/CD integration complete: Coverage check runs on every PR, blocks merge if coverage decreases
6. Coverage tracking command created: `npm run coverage:handlers`
7. Coverage report published: `docs/qa/handler-coverage-report.md`
8. Quality gates documented: Coverage requirements and exception process

## Story 2.15: Test Pattern Validation & State Utilities
As a **TDD engineer**,
I want **automated test pattern validation in pre-commit hooks and state management utilities for sequential tests**,
so that **pattern regressions are prevented, aolite API usage is enforced, and state-dependent tests are reliable**.

### Acceptance Criteria
1. Test pattern validation integrated into `scripts/hooks/tdd-pre-commit.sh`
2. Correct aolite API usage validated: `aolite.spawnProcess()`, `aolite.send()`, `aolite.getLastMsg()`
3. Forbidden pattern detection: describe/it blocks, old aolite API, missing From field
4. sendMessage pattern validation: From field required, tag stringification enforced
5. State management utilities library created: `testing/utils/state-management.lua`
6. State utilities tested and documented: resetProcessState, validateState, snapshot/restore
7. CI/CD integration: Pattern validation in GitHub Actions, builds fail on violations
8. Documentation complete: State management decision tree, pattern validation guide, troubleshooting

## Story 2.16: TDD Documentation & Training
As a **TDD engineer**,
I want **comprehensive TDD documentation, training materials, and test development guides with enhanced patterns and workflows**,
so that **new developers can quickly onboard to the aolite testing framework and existing developers have clear references for best practices**.

### Acceptance Criteria
1. CLAUDE.md updated with enhanced TDD patterns, handler discovery workflows, and lessons learned from Stories 2.8-2.15
2. Test development guide created: Step-by-step workflow for creating tests with handler inspection and pattern selection
3. State management decision tree documented: Clear guidance on when to use independent tests vs state-dependent sequences
4. Troubleshooting guide created: Common issues, error messages, and solutions for aolite testing
5. Test pattern examples expanded: Real-world examples from migrated tests demonstrating best practices
6. Training materials complete: Quick reference cards, cheat sheets, and workflow diagrams for TDD process
7. Architecture documentation enhanced: `test-strategy-and-standards.md` includes aolite patterns, handler coverage, and state management
8. Migration lessons learned documented: Insights from Stories 2.8-2.15 captured for future reference
