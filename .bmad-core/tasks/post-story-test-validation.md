<!-- Powered by BMAD™ Core -->

# Post-Story Test Validation Task

**Purpose:** Ensure comprehensive test coverage and prevent test regressions when completing stories/epics

**Trigger:** Execute after marking any story as "Done" or "Review" 

**Prerequisites:** Story must be in completion state with all functional requirements implemented

---

## LLM Agent Instructions

This task MUST be executed before final story completion. Follow each step systematically and honestly assess test coverage gaps.

### STEP 1: Story Test Requirements Analysis

**Action:** Analyze the completed story for test requirements

**Process:**
1. Read the completed story file completely
2. Identify all functional requirements and acceptance criteria
3. List all new/modified code areas that require testing
4. Determine required test types based on test strategy:
   - **Unit Tests:** For all new functions, calculations, validations
   - **Integration Tests:** For AO process handlers, message flows, state changes
   - **Parity Tests:** For game mechanics vs TypeScript reference
   - **End-to-End Tests:** For complete user workflows

**Output:** Create detailed test requirements list with coverage gaps identified

---

### STEP 2: Existing Test Coverage Assessment

**Action:** Evaluate current test coverage for story scope

**Process:**
1. Run test discovery commands:
   ```bash
   # Check existing tests
   find testing/ -name "*.test.lua" -o -name "*.test.js" -o -name "*.test.ts"
   find test/ -name "*.test.*"
   
   # Run test suites to identify gaps
   npm run test:aolite  # Lua unit tests
   npm run test:aos-local  # Integration tests
   npm run test:parity  # Parity validation
   ```

2. Analyze test results for:
   - **Missing Tests:** Functions/handlers without test coverage
   - **Failing Tests:** Tests broken by story implementation
   - **Incomplete Coverage:** Edge cases or error conditions not tested

**Output:** Report all missing, failing, or inadequate tests with specific file references

---

### STEP 3: Test Generation & Remediation

**Action:** Create missing tests and fix failing ones

**Process:**
1. **For Missing Unit Tests:**
   ```bash
   npm run tdd:generate-tests  # Generate test skeletons
   ```
   - Create comprehensive test cases following AAA pattern
   - Cover happy path, edge cases, error conditions
   - Mock external dependencies and RNG

2. **For Missing Integration Tests:**
   - Create handler workflow tests
   - Test complete message processing chains
   - Validate state transitions and responses

3. **For Failing Tests:**
   - Identify root cause (implementation change vs test obsolescence)
   - Update tests to match new behavior OR fix implementation if incorrect
   - Ensure backward compatibility where required

4. **For Missing Parity Tests:**
   - Compare Lua implementation against TypeScript reference
   - Create validation tests for game mechanics
   - Ensure mathematical calculations match exactly

**Output:** All tests created/fixed with passing status confirmed

---

### STEP 4: Test Quality Validation

**Action:** Ensure test quality meets project standards

**Process:**
1. **Run Full Test Suite:**
   ```bash
   npm run test:all  # Complete test execution
   ```

2. **Validate Test Quality:**
   - Tests follow AAA pattern (Arrange, Act, Assert)
   - Comprehensive edge case coverage
   - Proper mocking of dependencies
   - Clear, descriptive test names
   - Adequate assertions for behavior validation

3. **Check Coverage Requirements:**
   - Unit tests: 100% for calculations, 95% for core logic
   - Integration tests: All handlers and workflows
   - Parity tests: All game mechanics vs reference

**Output:** Confirmed passing test suite with quality standards met

---

### STEP 5: Continuous Integration Validation

**Action:** Ensure CI pipeline compatibility

**Process:**
1. **Validate Build Process:**
   ```bash
   npm run build  # Ensure clean build
   npm run lint:ao-sandbox  # AO process validation
   npm run validate:size  # Process size limits
   ```

2. **Check CI Integration:**
   - All tests pass in clean environment
   - No new build warnings or errors
   - Performance benchmarks within acceptable ranges
   - Test execution time under CI limits

**Output:** Clean CI pipeline status with all validations passing

---

### STEP 6: Documentation & Reporting

**Action:** Document test coverage and any technical debt

**Process:**
1. **Update Story Documentation:**
   - List all tests created during validation
   - Document any test coverage exceptions with justification
   - Note any technical debt or follow-up testing needs

2. **Update Test Documentation:**
   - Add new test cases to relevant test suites
   - Update test strategy if new patterns emerged
   - Document any testing utilities or helpers created

3. **Final Validation Report:**
   - Summarize test coverage achieved
   - List any remaining gaps with mitigation strategies
   - Confirm story meets Definition of Done testing requirements

**Output:** Comprehensive test validation report with full traceability

---

## Success Criteria

**Story completion is approved ONLY when:**

✅ All functional requirements have corresponding tests  
✅ All existing tests pass without regression  
✅ New tests meet quality standards and coverage requirements  
✅ Full test suite executes successfully  
✅ CI pipeline validates cleanly  
✅ Test documentation is complete and current  

**If ANY criterion fails:** Story must remain in development until remediated

---

## Integration with BMad Workflow

**Usage:** 
```bash
*task post-story-test-validation
```

**Timing:** Execute before running `*execute-checklist story-dod-checklist`

**Dependencies:** Requires completed story implementation and functional development environment

**Follow-up:** Story can proceed to review only after successful validation completion