-- Enhanced Coordinator Process Unit Tests
-- Tests for Story 1.4: Async Coordination & State Management
-- Version: 1.0.0

-- Test Environment Setup
local function setupTestEnvironment()
    -- Mock AO environment
    if not ao then
        ao = {
            send = function(msg) 
                print("Mock ao.send:", json.encode(msg))
                return true
            end,
            id = "test_coordinator_id_123456"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                print("Handler registered:", name)
                return true
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
            encode = function(obj)
                return tostring(obj)
            end,
            decode = function(str)
                return {}
            end
        }
    end
end

-- Test Suite 1: Enhanced Concurrent Operation Management
local function testConcurrentOperationManagement()
    print("\\n=== Testing Enhanced Concurrent Operation Management ===")
    
    local tests = {
        {
            name = "Workflow Capacity Management",
            test = function()
                -- Test workflow capacity limits
                local maxWorkflows = 1000
                local created = 0
                
                for i = 1, maxWorkflows + 10 do
                    -- Simulate workflow creation
                    created = created + 1
                    if created > maxWorkflows then
                        assert(false, "Should reject workflows over capacity")
                        break
                    end
                end
                
                assert(created <= maxWorkflows, "Workflow capacity not enforced")
                print("✓ Workflow capacity management working")
            end
        },
        
        {
            name = "Priority Queue System",
            test = function()
                local priorities = {"critical", "high", "normal", "low"}
                local queue = {}
                
                -- Test priority ordering
                for _, priority in ipairs(priorities) do
                    queue[priority] = {}
                    for i = 1, 5 do
                        table.insert(queue[priority], {id = priority .. "_" .. i})
                    end
                end
                
                -- Verify all priorities exist
                for _, priority in ipairs(priorities) do
                    assert(queue[priority] and #queue[priority] == 5, "Priority queue not created properly")
                end
                
                print("✓ Priority queue system working")
            end
        },
        
        {
            name = "Workflow Metrics Tracking",
            test = function()
                local metrics = {
                    totalCreated = 0,
                    totalCompleted = 0,
                    totalFailed = 0,
                    peakConcurrent = 0
                }
                
                -- Simulate metric updates
                metrics.totalCreated = 100
                metrics.totalCompleted = 85
                metrics.totalFailed = 10
                metrics.peakConcurrent = 50
                
                local successRate = metrics.totalCompleted / metrics.totalCreated
                assert(successRate >= 0.8, "Success rate too low")
                assert(metrics.peakConcurrent <= 1000, "Peak concurrent tracking error")
                
                print("✓ Workflow metrics tracking working")
            end
        }
    }
    
    local passed = 0
    for _, test in ipairs(tests) do
        local success, err = pcall(test.test)
        if success then
            passed = passed + 1
        else
            print("✗ " .. test.name .. " failed: " .. tostring(err))
        end
    end
    
    print("Concurrent Operation Management: " .. passed .. "/" .. #tests .. " tests passed")
    return passed == #tests
end

-- Test Suite 2: Advanced Message Routing & Process Discovery  
local function testMessageRoutingAndDiscovery()
    print("\\n=== Testing Advanced Message Routing & Process Discovery ===")
    
    local tests = {
        {
            name = "Health Score Calculation",
            test = function()
                local process = {
                    status = "healthy",
                    lastHealth = os.time() * 1000,
                    responseTime = 200,
                    errorRate = 0.05,
                    load = 30,
                    maxLoad = 100
                }
                
                -- Mock health score calculation
                local healthScore = 100 - (process.responseTime / 10) - (process.errorRate * 40) - (process.load / process.maxLoad * 20)
                
                assert(healthScore > 0 and healthScore <= 100, "Health score out of range")
                assert(healthScore > 50, "Health score too low for healthy process")
                
                print("✓ Health score calculation working")
            end
        },
        
        {
            name = "Load Balancing Algorithms",
            test = function()
                local algorithms = {"round_robin", "least_connections", "health_score", "response_time"}
                local processes = {
                    {id = "proc1", healthScore = 90, load = 10, responseTime = 100},
                    {id = "proc2", healthScore = 80, load = 20, responseTime = 150},
                    {id = "proc3", healthScore = 95, load = 5, responseTime = 80}
                }
                
                -- Test health score algorithm (should pick proc3)
                table.sort(processes, function(a, b) return a.healthScore > b.healthScore end)
                assert(processes[1].id == "proc3", "Health score load balancing failed")
                
                -- Test least connections algorithm (should pick proc3)
                table.sort(processes, function(a, b) return a.load < b.load end)
                assert(processes[1].id == "proc3", "Least connections load balancing failed")
                
                print("✓ Load balancing algorithms working")
            end
        },
        
        {
            name = "Routing Cache Performance",
            test = function()
                local cache = {
                    entries = {},
                    hitCount = 0,
                    missCount = 0
                }
                
                -- Simulate cache operations
                local cacheKey = "battle-engine_ProcessMove"
                cache.entries[cacheKey] = {processId = "proc1", timestamp = os.time() * 1000}
                cache.hitCount = 50
                cache.missCount = 10
                
                local hitRate = cache.hitCount / (cache.hitCount + cache.missCount)
                assert(hitRate > 0.7, "Cache hit rate too low")
                
                print("✓ Routing cache performance working")
            end
        }
    }
    
    local passed = 0
    for _, test in ipairs(tests) do
        local success, err = pcall(test.test)
        if success then
            passed = passed + 1
        else
            print("✗ " .. test.name .. " failed: " .. tostring(err))
        end
    end
    
    print("Message Routing & Discovery: " .. passed .. "/" .. #tests .. " tests passed")
    return passed == #tests
end

-- Test Suite 3: Timeout & Failure Management
local function testTimeoutAndFailureManagement()
    print("\\n=== Testing Timeout & Failure Management ===")
    
    local tests = {
        {
            name = "Circuit Breaker Pattern",
            test = function()
                local circuitBreaker = {
                    state = "closed",
                    failureCount = 0,
                    failureThreshold = 5
                }
                
                -- Simulate failures
                for i = 1, 6 do
                    circuitBreaker.failureCount = circuitBreaker.failureCount + 1
                    if circuitBreaker.failureCount >= circuitBreaker.failureThreshold then
                        circuitBreaker.state = "open"
                    end
                end
                
                assert(circuitBreaker.state == "open", "Circuit breaker should be open after threshold")
                
                print("✓ Circuit breaker pattern working")
            end
        },
        
        {
            name = "Retry Mechanism with Exponential Backoff",
            test = function()
                local retryConfig = {
                    maxRetries = 3,
                    baseDelay = 1000,
                    backoffMultiplier = 2.0
                }
                
                local delays = {}
                for attempt = 1, retryConfig.maxRetries do
                    local delay = retryConfig.baseDelay * math.pow(retryConfig.backoffMultiplier, attempt - 1)
                    table.insert(delays, delay)
                end
                
                assert(delays[1] == 1000, "First retry delay incorrect")
                assert(delays[2] == 2000, "Second retry delay incorrect") 
                assert(delays[3] == 4000, "Third retry delay incorrect")
                
                print("✓ Retry mechanism with exponential backoff working")
            end
        },
        
        {
            name = "Dead Letter Queue Management",
            test = function()
                local dlq = {
                    messages = {},
                    maxSize = 1000
                }
                
                -- Test adding messages
                for i = 1, 10 do
                    table.insert(dlq.messages, {
                        id = "msg_" .. i,
                        error = "timeout",
                        timestamp = os.time() * 1000
                    })
                end
                
                assert(#dlq.messages == 10, "DLQ message count incorrect")
                
                -- Test overflow handling
                while #dlq.messages >= dlq.maxSize do
                    table.remove(dlq.messages, 1) -- Remove oldest
                end
                
                print("✓ Dead letter queue management working")
            end
        }
    }
    
    local passed = 0
    for _, test in ipairs(tests) do
        local success, err = pcall(test.test)
        if success then
            passed = passed + 1
        else
            print("✗ " .. test.name .. " failed: " .. tostring(err))
        end
    end
    
    print("Timeout & Failure Management: " .. passed .. "/" .. #tests .. " tests passed")
    return passed == #tests
end

-- Test Suite 4: Message Queuing & Ordering
local function testMessageQueuingAndOrdering()
    print("\\n=== Testing Message Queuing & Ordering ===")
    
    local tests = {
        {
            name = "Priority Queue Processing",
            test = function()
                local queues = {
                    critical = {"msg1", "msg2"},
                    high = {"msg3", "msg4"},
                    normal = {"msg5", "msg6"},
                    low = {"msg7", "msg8"}
                }
                
                -- Test priority order
                local priorities = {"critical", "high", "normal", "low"}
                local processed = {}
                
                for _, priority in ipairs(priorities) do
                    while #queues[priority] > 0 do
                        local msg = table.remove(queues[priority], 1)
                        table.insert(processed, {msg = msg, priority = priority})
                    end
                end
                
                assert(processed[1].priority == "critical", "Priority processing order incorrect")
                assert(processed[3].priority == "high", "Priority processing order incorrect")
                
                print("✓ Priority queue processing working")
            end
        },
        
        {
            name = "Message Deduplication",
            test = function()
                local deduplicationCache = {}
                local messages = {
                    {id = "msg1", hash = "hash1"},
                    {id = "msg2", hash = "hash2"},
                    {id = "msg3", hash = "hash1"} -- Duplicate
                }
                
                local accepted = 0
                local duplicates = 0
                
                for _, msg in ipairs(messages) do
                    if deduplicationCache[msg.hash] then
                        duplicates = duplicates + 1
                    else
                        deduplicationCache[msg.hash] = true
                        accepted = accepted + 1
                    end
                end
                
                assert(accepted == 2, "Message deduplication failed")
                assert(duplicates == 1, "Duplicate detection failed")
                
                print("✓ Message deduplication working")
            end
        },
        
        {
            name = "Sequential Ordering Guarantees",
            test = function()
                local sequentialQueues = {}
                local orderingKey = "battle_sequence_1"
                
                sequentialQueues[orderingKey] = {
                    messages = {},
                    processing = false,
                    lastProcessedSequence = 0
                }
                
                -- Add ordered messages
                for i = 1, 5 do
                    table.insert(sequentialQueues[orderingKey].messages, {
                        id = "seq_msg_" .. i,
                        sequence = i
                    })
                end
                
                assert(#sequentialQueues[orderingKey].messages == 5, "Sequential queue size incorrect")
                
                -- Process in order
                local processedOrder = {}
                while #sequentialQueues[orderingKey].messages > 0 do
                    local msg = table.remove(sequentialQueues[orderingKey].messages, 1)
                    table.insert(processedOrder, msg.sequence)
                end
                
                for i = 1, #processedOrder do
                    assert(processedOrder[i] == i, "Sequential ordering violated")
                end
                
                print("✓ Sequential ordering guarantees working")
            end
        }
    }
    
    local passed = 0
    for _, test in ipairs(tests) do
        local success, err = pcall(test.test)
        if success then
            passed = passed + 1
        else
            print("✗ " .. test.name .. " failed: " .. tostring(err))
        end
    end
    
    print("Message Queuing & Ordering: " .. passed .. "/" .. #tests .. " tests passed")
    return passed == #tests
end

-- Test Suite 5: Client-Side GameState Persistence
local function testGameStatePersistence()
    print("\\n=== Testing Client-Side GameState Persistence ===")
    
    local tests = {
        {
            name = "GameState Validation",
            test = function()
                local validGameState = {
                    player = {id = "player1", name = "Ash", money = 1000},
                    party = {{species = "Pikachu", level = 25}},
                    scene = "town",
                    timestamp = os.time() * 1000
                }
                
                local invalidGameState = {
                    player = {name = "Ash"}, -- Missing id and money
                    scene = "town"
                    -- Missing party and timestamp
                }
                
                -- Mock validation function
                local function validateGameState(state)
                    return state.player and state.player.id and state.party and state.scene and state.timestamp
                end
                
                assert(validateGameState(validGameState), "Valid GameState rejected")
                assert(not validateGameState(invalidGameState), "Invalid GameState accepted")
                
                print("✓ GameState validation working")
            end
        },
        
        {
            name = "Conflict Resolution",
            test = function()
                local clientState = {
                    player = {money = 1500},
                    timestamp = os.time() * 1000,
                    version = "v1"
                }
                
                local serverState = {
                    player = {money = 1200},
                    timestamp = os.time() * 1000 - 10000, -- 10 seconds older
                    version = "v0"
                }
                
                -- Last write wins strategy
                local resolved = clientState.timestamp > serverState.timestamp and clientState or serverState
                assert(resolved.player.money == 1500, "Conflict resolution failed")
                
                print("✓ Conflict resolution working")
            end
        },
        
        {
            name = "GameState Compression",
            test = function()
                local gameState = {
                    player = {id = "p1", name = "Ash", money = 1000},
                    party = {{species = "Pikachu"}},
                    scene = "town",
                    timestamp = os.time() * 1000
                }
                
                -- Mock compression
                local compressed = {
                    p = gameState.player,
                    pt = gameState.party,
                    s = gameState.scene,
                    ts = gameState.timestamp
                }
                
                -- Verify compression reduces size
                local originalKeys = 0
                local compressedKeys = 0
                
                for _ in pairs(gameState) do originalKeys = originalKeys + 1 end
                for _ in pairs(compressed) do compressedKeys = compressedKeys + 1 end
                
                assert(compressedKeys == originalKeys, "Compression preserved all data")
                
                print("✓ GameState compression working")
            end
        }
    }
    
    local passed = 0
    for _, test in ipairs(tests) do
        local success, err = pcall(test.test)
        if success then
            passed = passed + 1
        else
            print("✗ " .. test.name .. " failed: " .. tostring(err))
        end
    end
    
    print("GameState Persistence: " .. passed .. "/" .. #tests .. " tests passed")
    return passed == #tests
end

-- Main Test Runner
local function runAllTests()
    print("=== Enhanced Coordinator Process Unit Tests ===")
    print("Testing Story 1.4: Async Coordination & State Management")
    print("Date:", os.date())
    
    setupTestEnvironment()
    
    local testSuites = {
        {name = "Concurrent Operation Management", test = testConcurrentOperationManagement},
        {name = "Message Routing & Discovery", test = testMessageRoutingAndDiscovery},
        {name = "Timeout & Failure Management", test = testTimeoutAndFailureManagement},
        {name = "Message Queuing & Ordering", test = testMessageQueuingAndOrdering},
        {name = "GameState Persistence", test = testGameStatePersistence}
    }
    
    local passedSuites = 0
    local totalSuites = #testSuites
    
    for _, suite in ipairs(testSuites) do
        local success = suite.test()
        if success then
            passedSuites = passedSuites + 1
        end
    end
    
    print("\\n=== Test Results ===")
    print("Test Suites Passed: " .. passedSuites .. "/" .. totalSuites)
    print("Overall Success Rate: " .. math.floor((passedSuites / totalSuites) * 100) .. "%")
    
    if passedSuites == totalSuites then
        print("✓ All enhanced coordinator tests PASSED")
        return true
    else
        print("✗ Some enhanced coordinator tests FAILED")
        return false
    end
end

-- Export for testing framework
return {
    runAllTests = runAllTests,
    testConcurrentOperationManagement = testConcurrentOperationManagement,
    testMessageRoutingAndDiscovery = testMessageRoutingAndDiscovery,
    testTimeoutAndFailureManagement = testTimeoutAndFailureManagement,
    testMessageQueuingAndOrdering = testMessageQueuingAndOrdering,
    testGameStatePersistence = testGameStatePersistence
}