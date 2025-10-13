<!-- Powered by BMAD™ Core -->

# Post-Story Test Validation Checklist

**Purpose:** Prevent test regressions and ensure comprehensive test coverage before story completion

**Usage:** Execute automatically before running `story-dod-checklist.md`

**Requirement:** ALL items must be ✅ before story can be marked "Review" or "Done"

---

## Instructions for Developer Agent

This checklist is MANDATORY for all story completions. Each item represents a critical test quality gate that prevents production issues.

**EXECUTION APPROACH:**
1. Work through each section systematically
2. Mark items as [x] Done, [ ] Not Done, or [N/A] Not Applicable  
3. Provide specific evidence for [x] items (file names, test counts, coverage %)
4. Document remediation for any [ ] items before proceeding
5. **CRITICAL:** Story completion is BLOCKED until ALL applicable items are [x]

---

## Test Coverage Analysis

**[[LLM: Analyze story scope and identify ALL areas requiring test coverage]]**

### Functional Requirements Coverage
- [ ] **Unit Tests Created:** All new functions have corresponding unit tests with 100% line coverage
  - Evidence: _[List specific test files created]_
- [ ] **Integration Tests Created:** All new AO handlers have complete workflow tests  
  - Evidence: _[List handler test files and scenarios covered]_
- [ ] **Parity Tests Updated:** All game mechanics changes validated against TypeScript reference
  - Evidence: _[List parity test updates and results]_
- [ ] **Edge Case Coverage:** Boundary conditions, error states, and invalid inputs tested
  - Evidence: _[List edge cases covered with test names]_

### Test Quality Validation  
- [ ] **Test Structure:** All tests follow AAA pattern (Arrange, Act, Assert) consistently
- [ ] **Test Naming:** Test names clearly describe scenario and expected outcome
- [ ] **Mocking Strategy:** External dependencies properly mocked (RNG, database, AO messages)
- [ ] **Assertion Quality:** Tests verify both positive outcomes and error conditions

---

## Test Execution Status

**[[LLM: Execute all relevant test suites and verify clean status]]**

### Core Test Suites
- [ ] **Unit Tests Passing:** `npm run test:aolite` executes with 0 failures
  - Results: _[Pass/Fail count and execution time]_
- [ ] **Integration Tests Passing:** `npm run test:aos-local` executes with 0 failures  
  - Results: _[Pass/Fail count and execution time]_
- [ ] **Parity Tests Passing:** `npm run test:parity` shows 100% compatibility
  - Results: _[Compatibility percentage and any deviations]_
- [ ] **Full Suite Clean:** `npm run test:all` completes successfully
  - Results: _[Overall execution summary]_

### Build & Quality Gates
- [ ] **Build Successful:** `npm run build` completes without errors or warnings
- [ ] **AO Sandbox Valid:** `npm run lint:ao-sandbox` passes all process validations
- [ ] **Size Constraints:** `npm run validate:size` confirms all processes under limits
- [ ] **Type Checking:** `npm run typecheck` passes without errors

---

## Regression Prevention

**[[LLM: Ensure new implementation doesn't break existing functionality]]**

### Backward Compatibility
- [ ] **Existing Tests Status:** All pre-existing tests continue to pass without modification
  - Status: _[Count of existing tests, any failures addressed]_
- [ ] **API Compatibility:** Public interfaces maintain backward compatibility  
  - Evidence: _[List any breaking changes with migration strategy]_
- [ ] **Performance Impact:** New implementation doesn't degrade performance beyond acceptable thresholds
  - Metrics: _[Before/after performance comparison]_

### Integration Points
- [ ] **Cross-Process Communication:** Message interfaces between processes validated
- [ ] **State Management:** GameState transitions properly tested and validated
- [ ] **Error Handling:** Failure modes tested and recovery mechanisms validated

---

## Test Documentation & Maintenance

**[[LLM: Ensure tests are maintainable and well-documented]]**

### Documentation Updates
- [ ] **Test Strategy Updated:** Any new testing patterns documented in test strategy
- [ ] **Coverage Metrics:** Test coverage percentages documented and meet standards
  - Coverage: _[Unit: X%, Integration: Y%, Overall: Z%]_
- [ ] **Test Utilities:** Any new test helpers or utilities properly documented

### Future Maintainability  
- [ ] **Test Data Management:** Test fixtures and mock data properly organized
- [ ] **Test Environment:** Test setup/teardown processes documented and automated
- [ ] **Debugging Support:** Test failures provide clear diagnostic information

---

## Story-Specific Test Requirements

**[[LLM: Address any unique testing requirements from the story acceptance criteria]]**

### Story Acceptance Criteria Testing
- [ ] **AC #1 Validated:** _[Specific acceptance criteria with test evidence]_
- [ ] **AC #2 Validated:** _[Specific acceptance criteria with test evidence]_  
- [ ] **AC #3 Validated:** _[Specific acceptance criteria with test evidence]_
- [ ] **AC #4 Validated:** _[Specific acceptance criteria with test evidence]_
- [ ] **AC #5 Validated:** _[Specific acceptance criteria with test evidence]_

### Special Considerations
- [ ] **Security Testing:** Security-related functionality has appropriate security tests
- [ ] **Performance Testing:** Performance-critical features have benchmark tests
- [ ] **Compliance Testing:** Regulatory or standards compliance validated through tests

---

## Final Test Validation

**[[LLM: Provide comprehensive test validation summary]]**

### Test Validation Summary
- [ ] **Total Tests Created:** _[Number]_ new tests across _[Number]_ test files
- [ ] **Coverage Achieved:** Unit: _%_, Integration: _%_, E2E: _%_ 
- [ ] **Execution Time:** Full test suite completes in under _[Time]_ minutes
- [ ] **CI Compatibility:** All tests pass in clean CI environment

### Quality Assurance Confirmation
- [ ] **No Test Debt:** All identified test gaps have been addressed
- [ ] **No Regression Risk:** Existing functionality fully protected by tests
- [ ] **Production Ready:** Test coverage provides confidence for production deployment

### Story Completion Readiness
- [ ] **DoD Alignment:** All testing requirements from Definition of Done are satisfied
- [ ] **Technical Review Ready:** Code and tests ready for peer review
- [ ] **Production Deployment Ready:** Comprehensive test coverage provides production confidence

---

## Test Validation Report

**[[LLM: Provide detailed summary of test validation results]]**

### Test Creation Summary
```
New Unit Tests: [Count] tests in [Files]
New Integration Tests: [Count] tests in [Files]  
New Parity Tests: [Count] validations in [Files]
Updated Existing Tests: [Count] tests modified
```

### Coverage Analysis
```
Before Story: [Coverage %]
After Story: [Coverage %]
Gap Analysis: [Areas still requiring coverage]
```

### Risk Assessment
```
Regression Risk: [Low/Medium/High] - [Justification]
Production Risk: [Low/Medium/High] - [Justification]  
Technical Debt: [Description of any test debt created]
```

### Recommendations
```
Follow-up Testing: [Any additional testing recommended]
Monitoring: [Suggested production monitoring for new features]
Maintenance: [Test maintenance considerations]
```

---

## Final Confirmation

- [ ] **Test Validation Complete:** I confirm all test requirements have been satisfied
- [ ] **Quality Standards Met:** All tests meet project quality standards  
- [ ] **Regression Protected:** Existing functionality is protected from regression
- [ ] **Story Ready for Review:** Testing provides confidence for story completion

**Agent Signature:** _[Agent ID and validation timestamp]_

---

## Integration Notes

**Workflow Integration:**
1. Complete story implementation
2. Execute `*task post-story-test-validation` 
3. Complete this checklist with evidence
4. Only then proceed to `*execute-checklist story-dod-checklist`

**Failure Protocol:**
- If ANY item cannot be marked [x], story must remain in development
- Address all test gaps before attempting story completion
- Document any exceptions with explicit user approval