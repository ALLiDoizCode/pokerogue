# AO Testing Guidelines for PokéRogue Processes

## Overview

This document provides comprehensive testing guidelines specifically for AO processes, focusing on the unique requirements of the AO runtime environment and ensuring all processes comply with AO architectural patterns.

## Testing Framework Architecture

### Multi-Layer Testing Strategy

1. **Unit Testing** (aolite) - Individual process logic testing
2. **Integration Testing** (aos-local) - Process communication and deployment
3. **Parity Testing** - Validation against TypeScript reference
4. **AO Compliance Testing** - Runtime compatibility validation
5. **Performance Testing** - Timeout and response time validation

## Unit Testing with aolite

### Test Environment Setup

All AO process unit tests must include the standard mock environment:

```lua
-- test-setup.lua - Include at start of all unit tests
local function setupTestEnvironment()
    -- Mock AO globals for testing
    if not ao then
        ao = {
            send = function(msg) 
                print("Mock AO send:", json.encode(msg))
                -- Store sent messages for test verification
                if not _G.testMessages then _G.testMessages = {} end
                table.insert(_G.testMessages, msg)
            end,
            id = "test_process_id"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
                -- Store handlers for test verification
                if not _G.testHandlers then _G.testHandlers = {} end
                _G.testHandlers[name] = { matcher = matcher, handler = handler }
            end,
            utils = {
                hasMatchingTag = function(tag, value)
                    return function(msg)
                        return msg[tag] == value
                    end
                end
            }
        }
    end
    
    if not json then
        json = {
            encode = function(t) 
                return "mock_json_" .. tostring(t)
            end,
            decode = function(s) 
                return { mock = true, original = s }
            end
        }
    end
    
    -- Clear test state
    _G.testMessages = {}
    _G.testHandlers = {}
end
```

### Required Test Categories

#### 1. AO Compliance Tests
Every process must include these compliance tests:

```lua
-- Test AO compliance patterns
function testAOCompliance()
    setupTestEnvironment()
    
    -- Test 1: No require() statements
    local processCode = io.open("processes/test-process.lua", "r"):read("*all")
    assert(not string.match(processCode, "require%("), 
           "Process must not contain require() statements")
    
    -- Test 2: Handler registration pattern
    require("processes.test-process")
    assert(_G.testHandlers["process-logic"], 
           "Process must register handlers using Handlers.add()")
    
    -- Test 3: Error handling with pcall
    local testMsg = { 
        Action = "ProcessLogic", 
        Data = "invalid_data",
        From = "test_sender"
    }
    
    -- Should not crash on invalid input
    local success = pcall(function()
        _G.testHandlers["process-logic"].handler(testMsg)
    end)
    assert(success, "Process must handle errors gracefully with pcall")
    
    print("✓ AO Compliance tests passed")
end
```

#### 2. Handler Registration Tests
```lua
function testHandlerRegistration()
    setupTestEnvironment()
    require("processes.test-process")
    
    -- Verify all required handlers are registered
    local requiredHandlers = { "process-logic", "health-check" }
    for _, handlerName in ipairs(requiredHandlers) do
        assert(_G.testHandlers[handlerName], 
               "Required handler missing: " .. handlerName)
    end
    
    -- Test message routing
    local testMsg = {
        Action = "ProcessLogic",
        Data = { test = true },
        From = "test_sender",
        Timestamp = os.time()
    }
    
    local matcher = _G.testHandlers["process-logic"].matcher
    assert(matcher(testMsg), "Handler matcher should accept valid messages")
    
    print("✓ Handler registration tests passed")
end
```

#### 3. Message Flow Tests
```lua
function testMessageFlow()
    setupTestEnvironment()
    require("processes.test-process")
    
    local testMsg = {
        Action = "ProcessLogic",
        Data = { operation = "test", gameState = { playerId = "test123" } },
        From = "test_sender",
        Timestamp = os.time()
    }
    
    -- Execute handler
    _G.testHandlers["process-logic"].handler(testMsg)
    
    -- Verify response was sent
    assert(#_G.testMessages > 0, "Process should send response message")
    
    local response = _G.testMessages[1]
    assert(response.Target == "test_sender", "Response should target original sender")
    assert(response.Action, "Response should have Action field")
    assert(response.ProcessId, "Response should include ProcessId")
    
    print("✓ Message flow tests passed")
end
```

#### 4. Performance Tests
```lua
function testPerformanceCompliance()
    setupTestEnvironment()
    require("processes.test-process")
    
    local testMsg = {
        Action = "ProcessLogic",
        Data = { operation = "heavy_computation", gameState = { playerId = "test123" } },
        From = "test_sender",
        Timestamp = os.time()
    }
    
    local startTime = os.clock()
    _G.testHandlers["process-logic"].handler(testMsg)
    local endTime = os.clock()
    
    local executionTime = (endTime - startTime) * 1000 -- Convert to milliseconds
    
    -- Logic processes: 5-second limit, Data processes: 100ms limit
    local isLogicProcess = true -- Set based on process type
    local timeLimit = isLogicProcess and 5000 or 100
    
    assert(executionTime < timeLimit, 
           string.format("Execution time %dms exceeds %dms limit", 
                        executionTime, timeLimit))
    
    print("✓ Performance compliance tests passed")
end
```

### Test File Template

```lua
-- testing/unit/[process-name].test.lua
-- AO Process Unit Tests for [Process Name]

-- Include test setup
dofile("testing/test-setup.lua")

-- Test suite runner
local function runTests()
    print("Running AO compliance tests for [process-name]...")
    
    -- Required AO compliance tests
    testAOCompliance()
    testHandlerRegistration() 
    testMessageFlow()
    testPerformanceCompliance()
    
    -- Process-specific tests
    testProcessSpecificFeature1()
    testProcessSpecificFeature2()
    testErrorHandling()
    testEdgeCases()
    
    print("All tests passed for [process-name]!")
end

-- Execute tests when run
runTests()
```

## Integration Testing with aos-local

### aos-local Environment Setup

Integration tests verify process deployment and communication in AO-like environment:

```javascript
// testing/integration/[process-name].integration.test.js
const { spawn } = require('child_process');
const path = require('path');

describe('AO Process Integration Tests', () => {
    let aosProcess;
    
    beforeEach(async () => {
        // Setup aos-local environment
        aosProcess = spawn('aos-local', ['--quiet']);
        await waitForReady(aosProcess);
    });
    
    afterEach(() => {
        if (aosProcess) {
            aosProcess.kill();
        }
    });
    
    test('Process deployment', async () => {
        const processPath = path.join(__dirname, '../../processes/test-process.lua');
        const result = await deployProcess(aosProcess, processPath);
        
        expect(result.success).toBe(true);
        expect(result.processId).toBeDefined();
        expect(result.size).toBeLessThan(500 * 1024); // 500KB limit
    });
    
    test('Message handling', async () => {
        const processId = await deployProcess(aosProcess, processPath);
        
        const message = {
            Action: 'ProcessLogic',
            Data: { operation: 'test', gameState: { playerId: 'test123' } },
            Timestamp: Date.now()
        };
        
        const response = await sendMessage(aosProcess, processId, message);
        
        expect(response.Action).toBeDefined();
        expect(response.ProcessId).toBe(processId);
        expect(response.Timestamp).toBeDefined();
    });
    
    test('Error handling', async () => {
        const processId = await deployProcess(aosProcess, processPath);
        
        const invalidMessage = {
            Action: 'ProcessLogic',
            Data: 'invalid_data'
        };
        
        const response = await sendMessage(aosProcess, processId, invalidMessage);
        
        expect(response.Error).toBeDefined();
        expect(response.Action).toBe('SaveState'); // Even errors use SaveState protocol
    });
});
```

## Parity Testing

### TypeScript Reference Validation

Parity tests ensure AO processes produce identical results to TypeScript reference:

```lua
-- testing/parity/[process-name].parity.test.lua

local function testBattleDamageCalculation()
    setupTestEnvironment()
    require("processes.battle-engine")
    
    -- Load TypeScript reference results
    local referenceResults = loadTypeScriptReference("battle-damage-scenarios.json")
    
    for _, scenario in ipairs(referenceResults) do
        local msg = {
            Action = "ProcessLogic",
            Data = {
                operation = "calculateDamage",
                gameState = scenario.input.gameState,
                parameters = scenario.input.parameters
            },
            From = "test_sender",
            Timestamp = os.time()
        }
        
        -- Execute AO process
        _G.testMessages = {}
        _G.testHandlers["process-logic"].handler(msg)
        
        local response = _G.testMessages[1]
        local aoResult = json.decode(response.Data)
        
        -- Compare with TypeScript reference
        assert(aoResult.damage == scenario.expected.damage,
               string.format("Damage mismatch: AO=%d, TS=%d", 
                           aoResult.damage, scenario.expected.damage))
        
        assert(aoResult.critical == scenario.expected.critical,
               "Critical hit determination mismatch")
    end
    
    print("✓ Battle damage calculation parity verified")
end
```

## AO Compliance Testing

### Automated Compliance Validation

```bash
#!/bin/bash
# scripts/validate-ao-compliance.sh

echo "Running AO compliance validation..."

# Check for require() violations
echo "Checking for require() statements..."
if grep -r "require(" processes/ --include="*.lua"; then
    echo "❌ FAIL: require() statements found in processes"
    exit 1
else
    echo "✅ PASS: No require() statements found"
fi

# Check for direct handler assignment
echo "Checking for direct handler assignment..."
if grep -r "Handlers\[" processes/ --include="*.lua"; then
    echo "❌ FAIL: Direct handler assignment found"
    exit 1
else
    echo "✅ PASS: No direct handler assignments found"
fi

# Check for forbidden APIs
echo "Checking for forbidden API usage..."
FORBIDDEN_APIS=("io\." "debug\." "require(" "os\.execute" "os\.exit")
for api in "${FORBIDDEN_APIS[@]}"; do
    if grep -r "$api" processes/ --include="*.lua"; then
        echo "❌ FAIL: Forbidden API usage found: $api"
        exit 1
    fi
done
echo "✅ PASS: No forbidden API usage found"

# Validate file sizes
echo "Checking file sizes..."
npm run validate:size || exit 1

echo "✅ All AO compliance checks passed"
```

## Performance Testing

### Timeout and Response Time Validation

```lua
-- testing/performance/timeout-validation.test.lua

local function testTimeoutCompliance()
    setupTestEnvironment()
    
    -- Test logic process timeout (5 seconds)
    local function testLogicProcessTimeout()
        require("processes.battle-engine")
        
        local heavyComputationMsg = {
            Action = "ProcessLogic",
            Data = {
                operation = "heavyComputation",
                gameState = generateLargeGameState(),
                parameters = { iterations = 1000000 }
            },
            From = "test_sender",
            Timestamp = os.time()
        }
        
        local startTime = os.clock()
        _G.testHandlers["process-logic"].handler(heavyComputationMsg)
        local endTime = os.clock()
        
        local executionTime = (endTime - startTime) * 1000
        assert(executionTime < 5000, 
               "Logic process exceeded 5-second timeout: " .. executionTime .. "ms")
    end
    
    -- Test data process response time (100ms target)
    local function testDataProcessResponseTime()
        require("processes.pokemon-species-db")
        
        local queryMsg = {
            Action = "QueryData",
            Data = { query = "getSpecies", speciesId = "pikachu" },
            From = "test_sender",
            Timestamp = os.time()
        }
        
        local startTime = os.clock()
        _G.testHandlers["query-data"].handler(queryMsg)
        local endTime = os.clock()
        
        local responseTime = (endTime - startTime) * 1000
        if responseTime > 100 then
            print("Warning: Data query exceeded 100ms target: " .. responseTime .. "ms")
        end
    end
    
    testLogicProcessTimeout()
    testDataProcessResponseTime()
    
    print("✓ Timeout compliance tests passed")
end
```

## Test Execution Commands

### NPM Scripts for Testing

```json
{
  "scripts": {
    "test:aolite": "find testing/unit -name '*.test.lua' -exec lua {} \\;",
    "test:aos-local": "jest testing/integration --testTimeout=30000",
    "test:parity": "find testing/parity -name '*.parity.test.lua' -exec lua {} \\;",
    "test:compliance": "bash scripts/validate-ao-compliance.sh",
    "test:performance": "find testing/performance -name '*.test.lua' -exec lua {} \\;",
    "test:all": "npm run test:compliance && npm run test:aolite && npm run test:aos-local && npm run test:parity",
    "validate:size": "lua tools/size-validator.lua",
    "lint:ao-sandbox": "lua tools/ao-sandbox-validator.lua"
  }
}
```

### Test Execution Workflow

```bash
# 1. Quick compliance check
npm run test:compliance

# 2. Unit test execution
npm run test:aolite

# 3. Integration testing
npm run test:aos-local

# 4. Parity validation
npm run test:parity

# 5. Performance validation
npm run test:performance

# 6. Full test suite
npm run test:all
```

## Test Coverage Requirements

### Mandatory Test Coverage

Every AO process must include:

- [ ] **AO Compliance Tests**: No require(), proper handlers, error handling
- [ ] **Handler Registration Tests**: All handlers properly registered
- [ ] **Message Flow Tests**: Input/output message validation
- [ ] **Performance Tests**: Timeout compliance verification
- [ ] **Error Handling Tests**: Graceful error handling with pcall
- [ ] **Edge Case Tests**: Boundary conditions and invalid inputs
- [ ] **Parity Tests**: Identical behavior to TypeScript reference

### Test Quality Gates

Tests must meet these criteria to pass:

1. **100% Handler Coverage**: All registered handlers tested
2. **Error Path Coverage**: All error conditions tested
3. **Performance Compliance**: All timeout limits validated
4. **Parity Verification**: Zero behavioral differences from TypeScript
5. **AO Compatibility**: All AO runtime requirements verified

## Continuous Integration

### Pre-Commit Hooks

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running AO compliance checks..."

# Run compliance validation
npm run test:compliance || exit 1

# Run unit tests  
npm run test:aolite || exit 1

# Validate file sizes
npm run validate:size || exit 1

echo "Pre-commit checks passed"
```

### Pipeline Integration

```yaml
# .github/workflows/ao-testing.yml
name: AO Process Testing

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm install
      
      - name: AO Compliance Check
        run: npm run test:compliance
      
      - name: Unit Tests
        run: npm run test:aolite
      
      - name: Integration Tests
        run: npm run test:aos-local
      
      - name: Parity Tests
        run: npm run test:parity
      
      - name: Performance Tests
        run: npm run test:performance
```

## Debugging AO Processes

### Debug Output Patterns

```lua
-- Debug helpers for AO testing
local DEBUG = true -- Set to false for production

local function debugLog(message, data)
    if DEBUG then
        print("[DEBUG] " .. message)
        if data then
            print("[DATA] " .. json.encode(data))
        end
    end
end

-- Use in process handlers
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        debugLog("Received message", msg)
        
        local success, response = pcall(processLogic, msg)
        
        if success then
            debugLog("Process success", response)
            ao.send(response)
        else
            debugLog("Process error", response)
            ao.send(createErrorResponse(response))
        end
    end
)
```

### Test State Inspection

```lua
-- Helper functions for test debugging
local function inspectTestState()
    print("=== Test State Inspection ===")
    print("Messages sent: " .. #(_G.testMessages or {}))
    print("Handlers registered: " .. #(getTableKeys(_G.testHandlers or {})))
    
    if _G.testMessages then
        for i, msg in ipairs(_G.testMessages) do
            print("Message " .. i .. ": " .. json.encode(msg))
        end
    end
end

-- Use in tests when debugging
local function testWithDebugging()
    setupTestEnvironment()
    require("processes.test-process")
    
    -- Execute test logic
    testMessageFlow()
    
    -- Inspect state if test fails
    inspectTestState()
end
```

This comprehensive testing framework ensures all AO processes meet the strict requirements of the AO runtime while maintaining 100% functional parity with the TypeScript reference implementation.