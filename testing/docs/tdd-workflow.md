# TDD Workflow for AO Process Development

## Overview

This guide outlines the Test-Driven Development (TDD) workflow for developing AO processes using the aolite testing framework. The workflow emphasizes writing failing tests first, then implementing functionality to make tests pass.

## Quick Start

```lua
-- Load the testing framework
local HyperBeamTest = require("testing/aolite/hyperbeam-test-framework")
local Assert = require("testing/aolite/assertion-library")
local Mock = require("testing/aolite/mock-system")

-- Write a failing test
HyperBeamTest.test("should process move correctly", function()
    local moveResult = processMove({moveId = 25, targetSlot = 0})
    Assert.notNil(moveResult)
    Assert.equals(moveResult.success, true)
end)
```

## TDD Cycle for AO Processes

### 1. Red Phase - Write Failing Test

Start by writing a test that describes the desired behavior of your AO message handler:

```lua
-- Example: Testing a battle move handler
HyperBeamTest.test("should handle ProcessMove action", function()
    -- Setup
    local battleProcess = ProcessEmulator.spawn("battle-engine", {})
    
    -- Create test message
    local moveMsg = Mock.MessageBuilder.battleAction({
        moveId = 25,
        targetSlot = 0
    })
    
    -- Send message to process
    ProcessEmulator.routeMessage(moveMsg)
    ProcessEmulator.runScheduler(10, 1000)
    
    -- Verify response
    Assert.isTrue(battleProcess.messageCount > 0)
    -- Test will fail because handler doesn't exist yet
end)
```

### 2. Green Phase - Make Test Pass

Implement the minimal code to make the test pass:

```lua
-- Add handler to make test pass
local battleHandlers = {
    processMove = {
        matcher = function(msg)
            return msg.Action == "ProcessMove"
        end,
        handler = function(msg)
            -- Minimal implementation
            return {
                Target = msg.From,
                Action = "SaveState",
                Data = '{"success":true}',
                ProcessId = "battle-engine"
            }
        end
    }
}
```

### 3. Refactor Phase - Improve Code

Once tests pass, refactor for better design while keeping tests green:

```lua
-- Refactored handler with better structure
local battleHandlers = {
    processMove = {
        matcher = Handlers.utils.hasMatchingTag("Action", "ProcessMove"),
        handler = function(msg)
            local moveData = json.decode(msg.Data)
            
            -- Validate input
            if not moveData.moveId then
                return createErrorResponse(msg.From, "Missing move ID")
            end
            
            -- Process move
            local result = calculateMoveEffect(moveData)
            
            return createSuccessResponse(msg.From, result)
        end
    }
}
```

## AO Process Testing Patterns

### Handler Pattern Testing

```lua
-- Test handler registration and matching
HyperBeamTest.test("should register handler correctly", function()
    local handlers = {}
    
    -- Add handler
    handlers.testHandler = {
        matcher = Handlers.utils.hasMatchingTag("Action", "Test"),
        handler = function(msg) return {success = true} end
    }
    
    -- Test matcher
    local testMsg = {Action = "Test"}
    Assert.isTrue(handlers.testHandler.matcher(testMsg))
end)
```

### Message Flow Testing

```lua
-- Test message routing between processes
HyperBeamTest.test("should route messages correctly", function()
    -- Setup processes
    local processA = ProcessEmulator.spawn("proc-a", handlerA)
    local processB = ProcessEmulator.spawn("proc-b", handlerB)
    
    -- Send message
    ProcessEmulator.routeMessage({
        From = "external",
        Target = "proc-a", 
        Action = "Start"
    })
    
    // Run scheduler
    ProcessEmulator.runScheduler(10, 1000)
    
    // Verify both processes received messages
    Assert.isTrue(processA.messageCount > 0)
    Assert.isTrue(processB.messageCount > 0)
end)
```

### State Validation Testing

```lua
-- Test game state changes
HyperBeamTest.test("should update game state correctly", function()
    // Take initial snapshot
    StateInspector.takeSnapshot("state-process", "initial")
    
    // Process state change
    processStateChange({playerId = "player1", newLevel = 26})
    
    // Take final snapshot
    StateInspector.takeSnapshot("state-process", "final")
    
    // Compare snapshots
    local differences = StateInspector.compareSnapshots("state-process", "initial", "final")
    Assert.isTrue(#differences > 0, "State should have changed")
end)
```

## Testing Best Practices

### 1. Test Structure (AAA Pattern)

```lua
HyperBeamTest.test("descriptive test name", function()
    -- Arrange: Setup test data and environment
    local testData = FixtureLoader.get("pokemon", "pikachu")
    local process = ProcessEmulator.spawn("test-proc", handlers)
    
    -- Act: Execute the operation being tested
    local result = process.handler(testMessage)
    
    // Assert: Verify the results
    Assert.isTrue(result.success)
    Assert.equals(result.data.level, 26)
end)
```

### 2. Use Descriptive Test Names

```lua
-- Good: Describes behavior
HyperBeamTest.test("should increase pokemon level when gaining enough experience", function()

// Bad: Generic name
HyperBeamTest.test("test level up", function()
```

### 3. Test One Thing at a Time

```lua
-- Good: Tests single behavior
HyperBeamTest.test("should calculate type effectiveness correctly", function()
    local effectiveness = calculateTypeEffectiveness("Fire", "Water")
    Assert.equals(effectiveness, 0.5)
end)

// Don't combine multiple assertions for different behaviors
```

### 4. Use Fixtures for Consistent Data

```lua
// Use fixture loader for consistent test data
local testPokemon = FixtureLoader.get("pokemon", "pikachu")
local testBattle = FixtureLoader.get("battles", "wildEncounter")

// Create variations when needed
local lowLevelPokemon = FixtureLoader.createPokemonVariation("pikachu", {level = 5})
```

### 5. Mock External Dependencies

```lua
// Mock RNG for deterministic tests
local mockRNG = Mock.rng(12345)
local damage = calculateDamage(80, 60, mockRNG.random(0.85, 1.0))

// Mock data sources
local mockData = Mock.dataSource({
    species: {25: {name: "Pikachu", types: ["Electric"]}}
})
```

## Process-Specific Testing Guidelines

### Battle Process Testing

```lua
// Test damage calculation
HyperBeamTest.test("should calculate damage with type effectiveness", function()
    local attacker = FixtureLoader.get("pokemon", "pikachu") // Electric
    local defender = FixtureLoader.get("pokemon", "charizard") // Fire/Flying
    
    local damage = calculateDamage(attacker, defender, 25) // Thunderbolt
    Assert.isTrue(damage > 0)
    // Electric vs Flying = 2x effectiveness
end)

// Test status effects
HyperBeamTest.test("should apply paralysis status correctly", function()
    local pokemon = FixtureLoader.get("pokemon", "charizard")
    applyStatusEffect(pokemon, "paralysis")
    
    Assert.equals(pokemon.status, "paralysis")
    Assert.equals(pokemon.statusTurns, -1) // Permanent until healed
end)
```

### State Process Testing

```lua
// Test Pokemon evolution
HyperBeamTest.test("should evolve pokemon at correct level", function()
    local charmander = FixtureLoader.get("pokemon", "charmander")
    charmander.level = 16
    
    local evolved = checkEvolution(charmander)
    Assert.isTrue(evolved.canEvolve)
    Assert.equals(evolved.newSpeciesId, 5) // Charmeleon
end)

// Test inventory management
HyperBeamTest.test("should add item to inventory", function()
    local player = FixtureLoader.get("players", "newPlayer")
    addItem(player, "potion", 5)
    
    Assert.equals(player.inventory.potions, 8) // Was 3, now 8
end)
```

### Query Process Testing

```lua
// Test data retrieval
HyperBeamTest.test("should return pokemon data for valid ID", function()
    local pokemon = queryPokemon("pokemon-025")
    
    Assert.notNil(pokemon)
    Assert.equals(pokemon.speciesId, 25)
    Assert.equals(pokemon.species, "Pikachu")
end)

// Test filtering
HyperBeamTest.test("should filter pokemon by type", function()
    local electricPokemon = queryPokemonByType("Electric")
    
    Assert.isTrue(#electricPokemon > 0)
    for _, pokemon in ipairs(electricPokemon) do
        Assert.contains(pokemon.types, "Electric")
    end
end)
```

## Running Tests

### Command Line Usage

```bash
// Run all tests
lua testing/aolite/test-runner.lua

// Run specific test file
lua testing/run-framework-tests.lua

// Run with verbose output
lua -e "require('testing/aolite/test-runner').run({verbose=true})"

// Run with TAP output
lua -e "require('testing/aolite/test-runner').run({tapOutput=true})"
```

### Programmatic Usage

```lua
local TestRunner = require("testing/aolite/test-runner")

// Run all tests
local success = TestRunner.run()

// Run specific directory
local success = TestRunner.run({
    testDirectories = {"testing/unit/hyperbeam"}
})

// Get test statistics
local stats = TestRunner.getStats()
print("Passed:", stats.files.passed, "Failed:", stats.files.failed)
```

## Debugging Failed Tests

### 1. Use State Inspector

```lua
// Take snapshots to debug state changes
StateInspector.takeSnapshot("process-id", "before-action")
// ... perform action ...
StateInspector.takeSnapshot("process-id", "after-action")

// Compare snapshots
local differences = StateInspector.compareSnapshots("process-id", "before-action", "after-action")
print("State changes:", StateInspector.generateDiffReport(differences))
```

### 2. Enable Debug Mode

```lua
// Enable debug output
ProcessEmulator.enableDebug()
Mock.setConfig("debugMode", true)

// Debug message routing
print("Message queues:", ProcessEmulator.getTotalQueueSize())
print("Message history:", #ProcessEmulator.getMessageHistory())
```

### 3. Examine Test Output

```lua
// Check TAP output for specific failure details
not ok 5 - should process move correctly
  ---
  error: Assertion failed: Expected condition to be true
  ...

// Use assertion messages for clarity
Assert.isTrue(result.success, "Move processing should succeed but got: " .. tostring(result))
```

## Common Testing Patterns

### Testing Error Conditions

```lua
HyperBeamTest.test("should handle invalid move ID", function()
    local invalidMsg = Mock.MessageBuilder.battleAction({moveId = -1})
    
    ProcessEmulator.routeMessage(invalidMsg)
    ProcessEmulator.runScheduler(5, 500)
    
    // Should receive error response
    local sentMessages = ao.getSentMessages()
    local response = sentMessages[#sentMessages]
    Assert.isErrorResponse(response)
end)
```

### Testing Timeouts

```lua
HyperBeamTest.test("should timeout long operations", function()
    local startTime = os.clock()
    
    // This should timeout in 5 seconds
    local result = ProcessEmulator.runScheduler(1000, 5000)
    
    local elapsed = (os.clock() - startTime) * 1000
    Assert.isTrue(elapsed < 6000, "Should timeout within 6 seconds")
end)
```

### Testing Concurrent Operations

```lua
HyperBeamTest.test("should handle concurrent message processing", function()
    // Setup multiple processes
    local processes = {}
    for i = 1, 5 do
        processes[i] = ProcessEmulator.spawn("proc-" .. i, handlers)
    end
    
    // Send messages to all processes
    for i = 1, 5 do
        ProcessEmulator.routeMessage({
            Target = "proc-" .. i,
            Action = "Process",
            Data = "test-data-" .. i
        })
    end
    
    // Run scheduler
    ProcessEmulator.runScheduler(50, 2000)
    
    // Verify all processes handled messages
    for i = 1, 5 do
        Assert.isTrue(processes[i].messageCount > 0)
    end
end)
```

## Integration with CI/CD

### TAP Output Format

The testing framework outputs TAP (Test Anything Protocol) for CI integration:

```
TAP version 13
# AO Process Test Runner v1.0.0
ok 1 - testing/unit/framework/framework.test.lua
ok 2 - testing/unit/message-passing.test.lua
1..2
# Test files: 2, Passed: 2, Failed: 0
# Duration: 150.32ms
```

### Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed

This enables proper CI/CD integration with build systems that check exit codes.

## Performance Testing

### Execution Time Testing

```lua
HyperBeamTest.test("should execute within time limit", function()
    Assert.executesWithin(function()
        // Code that should execute quickly
        processLargeDataSet(testData)
    end, 100, "Data processing should complete within 100ms")
end)
```

### Memory Usage Testing

```lua
// Monitor process state size
HyperBeamTest.test("should not exceed memory limits", function()
    local initialSize = calculateStateSize(process.state)
    
    // Perform operations
    for i = 1, 1000 do
        process.addData("item-" .. i, {data = "test"})
    end
    
    local finalSize = calculateStateSize(process.state)
    local growth = finalSize - initialSize
    
    Assert.isTrue(growth < 50000, "State growth should be < 50KB")
end)
```

## Advanced Testing Scenarios

### Cross-Process Integration Testing

```lua
HyperBeamTest.test("should coordinate between battle and state processes", function()
    // Setup processes
    local battleProc = ProcessEmulator.spawn("battle", battleHandlers)
    local stateProc = ProcessEmulator.spawn("state", stateHandlers)
    
    // Start battle (should update state)
    ProcessEmulator.routeMessage({
        Target = "battle",
        Action = "StartBattle",
        Data = json.encode({opponentId = "wild-pokemon"})
    })
    
    ProcessEmulator.runScheduler(20, 3000)
    
    // Verify both processes were involved
    Assert.isTrue(battleProc.messageCount > 0)
    Assert.isTrue(stateProc.messageCount > 0)
end)
```

This TDD workflow ensures reliable, maintainable AO processes with comprehensive test coverage and clear development practices.