# AO Compliance Checklist for Story Development

## Overview

This checklist ensures all new stories and implementations comply with AO runtime requirements and prevent the architectural violations that were discovered in Phase 1.

## Pre-Development Checklist

### Story Definition Requirements
Before starting any story implementation, verify:

- [ ] **AO Compliance AC**: Story includes explicit acceptance criteria for AO compliance
- [ ] **Monolithic Design AC**: Story specifies no external dependencies or require() statements
- [ ] **Handler Pattern AC**: Story requires proper `Handlers.add()` usage with tag matching
- [ ] **Error Handling AC**: Story mandates pcall wrapping for all operations
- [ ] **Performance AC**: Story includes 5-second timeout for logic processes or sub-100ms for data processes

### Required Story Acceptance Criteria Template
Add these AO compliance criteria to every new story:

```markdown
## AO Compliance Acceptance Criteria

**AO-C1:** Process implementation shall use monolithic design with all dependencies embedded (no require() statements)

**AO-C2:** Process handlers shall use `Handlers.add(name, matcher, handler)` pattern with proper tag matching (no direct assignment)

**AO-C3:** All process operations shall be wrapped in pcall with structured error responses sent via ao.send()

**AO-C4:** Process execution shall complete within timeout limits (5 seconds for logic, 100ms for data processes)

**AO-C5:** Process implementation shall use only available AO globals (ao.send, ao.id, Handlers, json, standard Lua)

**AO-C6:** Process testing shall include aolite unit tests with mock AO environment setup

**AO-C7:** Process deployment shall validate AO compatibility using `npm run lint:ao-sandbox`

**AO-C8:** Process file size shall remain under 500KB constraint verified by `npm run validate:size`
```

## Development Phase Checklist

### Implementation Requirements
During development, ensure:

- [ ] **Template Usage**: Use updated process templates with AO compliance headers
- [ ] **Global Declarations**: Include proper AO global declarations at file start
- [ ] **No Forbidden APIs**: No usage of require(), io, debug, or network operations
- [ ] **Handler Registration**: All handlers use `Handlers.add()` with proper matchers
- [ ] **Error Wrapping**: All logic wrapped in pcall with ao.send error responses
- [ ] **Performance Monitoring**: Include timeout checking for long operations

### Code Pattern Verification

#### Required File Header Pattern
```lua
-- ============================================================================
-- [Process Name] - [Brief Description]
-- AO Process Implementation for PokéRogue
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { 
    encode = function(t) return "encoded_json" end, 
    decode = function(s) return {} end 
}
local ao = ao or { 
    send = function(msg) return true end,
    id = "test_process"
}
```

#### Required Handler Pattern
```lua
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local success, response = pcall(processLogic, msg)
        
        if success then
            ao.send({
                Target = msg.From,
                Action = response.Action,
                Data = response.Data,
                GameState = response.GameState,
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        else
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = response,
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        end
    end
)
```

#### Required Testing Pattern
```lua
-- Mock AO environment for testing
local function setupTestEnvironment()
    if not ao then
        ao = {
            send = function(msg) print("Mock send:", json.encode(msg)) end,
            id = "test_process_id"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
            end,
            utils = {
                hasMatchingTag = function(tag, value)
                    return function(msg) return msg[tag] == value end
                end
            }
        }
    end
end
```

## Testing Phase Checklist

### Required Test Coverage
Before marking story complete, verify:

- [ ] **Unit Tests**: aolite tests pass with mock AO environment
- [ ] **Handler Tests**: All handlers tested with proper message flow
- [ ] **Error Tests**: Error handling tested with invalid inputs
- [ ] **Performance Tests**: Timeout scenarios tested
- [ ] **Integration Tests**: Process communication tested with aos-local
- [ ] **Parity Tests**: Behavior matches TypeScript reference implementation

### Test Execution Commands
```bash
# Unit testing with aolite
npm run test:aolite

# Integration testing with aos-local  
npm run test:aos-local

# Parity validation
npm run test:parity

# AO sandbox validation
npm run lint:ao-sandbox

# File size validation
npm run validate:size

# Full test suite
npm run test:all
```

## QA Review Checklist

### Code Review Requirements
QA reviewers must verify:

- [ ] **No require() statements**: Grep for `require(` returns no results
- [ ] **Handler pattern compliance**: All handlers use `Handlers.add()`
- [ ] **Error handling present**: All operations wrapped in pcall
- [ ] **AO globals only**: No usage of forbidden APIs (io, debug, etc.)
- [ ] **Performance monitoring**: Timeout checks implemented
- [ ] **File size compliance**: Process under 500KB limit
- [ ] **Test coverage**: All AO compliance criteria tested

### Automated Validation
```bash
# Check for require() violations
grep -r "require(" processes/ && echo "❌ FAIL: require() found" || echo "✅ PASS: No require() statements"

# Check for direct handler assignment
grep -r "Handlers\[" processes/ && echo "❌ FAIL: Direct assignment found" || echo "✅ PASS: No direct assignments"

# Validate file sizes
npm run validate:size

# Validate AO compatibility
npm run lint:ao-sandbox
```

## Deployment Checklist

### Pre-Deployment Validation
Before deploying any process:

- [ ] **All tests pass**: `npm run test:all` succeeds
- [ ] **Size validation**: `npm run validate:size` passes
- [ ] **AO compatibility**: `npm run lint:ao-sandbox` passes
- [ ] **Parity verification**: `npm run test:parity` confirms identical behavior
- [ ] **Documentation updated**: Process documented in architecture files
- [ ] **QA gate passed**: Story has PASS status from QA review

### Post-Deployment Verification
After deployment:

- [ ] **Health check**: Process responds to health check messages
- [ ] **Message flow**: Process communication works in live environment
- [ ] **Performance**: Response times meet requirements
- [ ] **Error handling**: Graceful failure behavior confirmed
- [ ] **Monitoring**: Process appears in monitoring dashboards

## Common Violations and Fixes

### ❌ Common AO Violations

1. **Using require() statements**
   ```lua
   -- ❌ WRONG
   local utils = require('utils')
   ```

2. **Direct handler assignment**
   ```lua
   -- ❌ WRONG
   Handlers["ProcessLogic"] = function(msg) end
   ```

3. **Unhandled errors**
   ```lua
   -- ❌ WRONG
   local result = riskyOperation()
   ```

4. **Missing timeout monitoring**
   ```lua
   -- ❌ WRONG
   while condition do
       -- Long operation without timeout check
   end
   ```

### ✅ Correct AO Patterns

1. **Embed dependencies**
   ```lua
   -- ✅ CORRECT
   local function utilityFunction() end
   ```

2. **Use Handlers.add pattern**
   ```lua
   -- ✅ CORRECT
   Handlers.add("process-logic", matcher, handler)
   ```

3. **Wrap in pcall**
   ```lua
   -- ✅ CORRECT
   local success, result = pcall(riskyOperation)
   ```

4. **Monitor execution time**
   ```lua
   -- ✅ CORRECT
   local startTime = os.clock() * 1000
   if (os.clock() * 1000) - startTime > 5000 then
       error("Timeout exceeded")
   end
   ```

## Emergency Fixes

If AO violations are discovered:

1. **Immediate**: Stop deployment of affected processes
2. **Assessment**: Run compliance checklist on all related processes
3. **Root Cause**: Identify if template/documentation issue exists
4. **Fix**: Apply correct AO patterns to all affected processes
5. **Validation**: Run full test suite to confirm fixes
6. **Prevention**: Update templates/documentation if needed

## References

- [AO Runtime Environment Documentation](../architecture/ao-runtime-environment.md)
- [Process Implementation Patterns](../architecture/process-implementation-patterns.md)
- [Tech Stack with AO Specifications](../architecture/tech-stack.md)
- [PRD with AO Requirements](../prd.md#functional)