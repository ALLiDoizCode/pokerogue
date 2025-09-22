-- Coordinator Process: ADP v1.0 Compliant Multi-Process Workflow Orchestrator
-- Version: 1.0.0
-- Purpose: Orchestrates workflows across 26-process stateless AO architecture
-- Architecture: Stateless coordination with async workflow management

-- Enhanced Process Registry with Health Scoring and Load Balancing
local ProcessRegistry = {
    dataProcesses = {
        ["pokemon-species-db"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 100, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["moves-database"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 100, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["items-database"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 100, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["abilities-database"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 100, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        }
    },
    logicProcesses = {
        ["battle-engine"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 50, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["evolution-engine"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 75, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["capture-engine"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 75, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["status-effects-engine"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 60, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        }
    },
    gameProcesses = {
        ["player-state"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 80, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["inventory-manager"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 90, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        },
        ["team-manager"] = { 
            id = nil, status = "unknown", lastHealth = 0,
            healthScore = 0, responseTime = 0, errorRate = 0, availability = 0,
            load = 0, maxLoad = 85, instances = {}, metrics = { totalRequests = 0, successfulRequests = 0 }
        }
    }
}

-- Routing Cache and Load Balancing State
local RoutingCache = {
    cache = {},
    maxCacheSize = 1000,
    cacheTimeout = 30000, -- 30 seconds
    hitCount = 0,
    missCount = 0
}

local LoadBalancingAlgorithms = {
    roundRobin = "round_robin",
    leastConnections = "least_connections",
    healthScore = "health_score",
    responseTime = "response_time"
}

local RoutingConfig = {
    defaultAlgorithm = LoadBalancingAlgorithms.healthScore,
    failoverEnabled = true,
    maxRetries = 3,
    retryDelay = 1000, -- 1 second
    cacheEnabled = true,
    latencyTarget = 500 -- 500ms target
}

-- Enhanced Workflow State Management for 1000+ Concurrent Operations
local ActiveWorkflows = {}
local WorkflowMetrics = {
    totalCreated = 0,
    totalCompleted = 0,
    totalFailed = 0,
    totalTimedOut = 0,
    peakConcurrent = 0,
    currentActive = 0
}
local WorkflowConfig = {
    defaultTimeout = 30000, -- 30 seconds
    maxConcurrentWorkflows = 1000,
    priorityLevels = { low = 1, normal = 2, high = 3, critical = 4 },
    memoryOptimization = true,
    capacityWarningThreshold = 800, -- 80% of max capacity
    cleanupInterval = 300000 -- 5 minutes
}
local WorkflowPriorityQueue = {
    critical = {},
    high = {},
    normal = {},
    low = {}
}
local HealthCheckInterval = 10000 -- 10 seconds
local LastCleanupTime = 0

-- Message Queuing and Ordering System
local MessageQueue = {
    queues = {
        critical = {},
        high = {},
        normal = {},
        low = {}
    },
    sequentialQueues = {}, -- For ordering guarantees
    messageDeduplication = {}, -- For preventing duplicate processing
    persistence = {
        enabled = true,
        maxPersistedMessages = 10000,
        retentionTime = 3600000 -- 1 hour
    },
    metrics = {
        totalEnqueued = 0,
        totalDequeued = 0,
        totalDeduplicated = 0,
        currentQueueSizes = { critical = 0, high = 0, normal = 0, low = 0 },
        averageWaitTime = 0,
        maxWaitTime = 0
    },
    backpressure = {
        enabled = true,
        thresholds = {
            warning = 1000,  -- Start warning at 1000 messages
            critical = 5000, -- Start rejecting at 5000 messages
            emergency = 10000 -- Emergency overflow handling
        },
        currentLevel = "normal" -- normal, warning, critical, emergency
    }
}

local QueueConfig = {
    maxMessageSize = 100000, -- 100KB per message
    defaultTTL = 300000, -- 5 minutes
    batchProcessingSize = 10,
    orderingTimeout = 30000, -- 30 seconds for ordered delivery
    compressionEnabled = true,
    priorityPreemption = true -- Allow higher priority messages to preempt lower priority
}

-- Utility Functions
local function getCurrentTimestamp()
    return math.floor(os.time() * 1000)
end

local function generateWorkflowId()
    return string.format("wf_%d_%s", getCurrentTimestamp(), ao.id:sub(1, 8))
end

local function validateMessage(msg, requiredFields)
    for _, field in ipairs(requiredFields) do
        if not msg[field] then
            return false, "Missing required field: " .. field
        end
    end
    return true, nil
end

local function sendErrorResponse(target, workflowId, error, originalAction)
    ao.send({
        Target = target,
        Action = "WorkflowError",
        WorkflowId = workflowId or "unknown",
        OriginalAction = originalAction or "unknown",
        Error = error,
        Timestamp = getCurrentTimestamp()
    })
end

local function getAllProcesses()
    local allProcesses = {}
    for category, processes in pairs(ProcessRegistry) do
        for name, process in pairs(processes) do
            allProcesses[name] = process
        end
    end
    return allProcesses
end

-- Enhanced Process Discovery and Health Scoring Functions
local function calculateHealthScore(process)
    if not process or process.status == "unknown" then
        return 0
    end
    
    local currentTime = getCurrentTimestamp()
    local timeSinceLastHealth = currentTime - process.lastHealth
    
    -- Base scores
    local statusScore = 0
    if process.status == "healthy" then
        statusScore = 100
    elseif process.status == "degraded" then
        statusScore = 50
    elseif process.status == "unhealthy" then
        statusScore = 10
    end
    
    -- Availability penalty (recent health check)
    local availabilityPenalty = math.min(50, timeSinceLastHealth / 1000) -- Max 50 point penalty
    
    -- Response time penalty (target <500ms)
    local responseTimePenalty = 0
    if process.responseTime > RoutingConfig.latencyTarget then
        responseTimePenalty = math.min(30, (process.responseTime - RoutingConfig.latencyTarget) / 100)
    end
    
    -- Error rate penalty
    local errorRatePenalty = process.errorRate * 40 -- Max 40 point penalty for 100% error rate
    
    -- Load penalty
    local loadPenalty = 0
    if process.maxLoad > 0 then
        loadPenalty = (process.load / process.maxLoad) * 20 -- Max 20 point penalty for full load
    end
    
    local finalScore = math.max(0, statusScore - availabilityPenalty - responseTimePenalty - errorRatePenalty - loadPenalty)
    return math.floor(finalScore)
end

local function updateProcessMetrics(processName, responseTime, success)
    local allProcesses = getAllProcesses()
    local process = allProcesses[processName]
    if not process then return end
    
    process.metrics.totalRequests = process.metrics.totalRequests + 1
    if success then
        process.metrics.successfulRequests = process.metrics.successfulRequests + 1
    end
    
    -- Update error rate (rolling average)
    process.errorRate = 1 - (process.metrics.successfulRequests / process.metrics.totalRequests)
    
    -- Update response time (exponential moving average)
    if responseTime then
        if process.responseTime == 0 then
            process.responseTime = responseTime
        else
            process.responseTime = (process.responseTime * 0.8) + (responseTime * 0.2)
        end
    end
    
    -- Update availability
    local currentTime = getCurrentTimestamp()
    local timeSinceLastHealth = currentTime - process.lastHealth
    process.availability = math.max(0, 100 - (timeSinceLastHealth / 1000)) -- Decrease 1% per second
    
    -- Recalculate health score
    process.healthScore = calculateHealthScore(process)
end

local function discoverProcess(processName, processId, instanceInfo)
    local allProcesses = getAllProcesses()
    if allProcesses[processName] then
        allProcesses[processName].id = processId
        allProcesses[processName].status = "discovered"
        allProcesses[processName].lastHealth = getCurrentTimestamp()
        allProcesses[processName].availability = 100
        
        -- Handle multiple instances
        if instanceInfo then
            table.insert(allProcesses[processName].instances, {
                id = processId,
                info = instanceInfo,
                registered = getCurrentTimestamp()
            })
        end
        
        -- Initialize health score
        allProcesses[processName].healthScore = calculateHealthScore(allProcesses[processName])
        
        -- Clear routing cache for this process
        clearRoutingCache(processName)
        
        return true
    end
    return false
end

local function clearRoutingCache(processName)
    if not RoutingConfig.cacheEnabled then return end
    
    for key, _ in pairs(RoutingCache.cache) do
        if string.find(key, processName) then
            RoutingCache.cache[key] = nil
        end
    end
end

local function getProcessId(processName)
    local allProcesses = getAllProcesses()
    if allProcesses[processName] and allProcesses[processName].id then
        return allProcesses[processName].id
    end
    return nil
end

-- Enhanced Workflow Management Functions with Priority and Capacity Management
local function getWorkflowPriorityLevel(priority)
    if priority and WorkflowConfig.priorityLevels[priority] then
        return priority
    end
    return "normal"
end

local function checkWorkflowCapacity()
    local activeCount = 0
    for _, workflow in pairs(ActiveWorkflows) do
        if workflow.status == "active" or workflow.status == "pending" then
            activeCount = activeCount + 1
        end
    end
    
    WorkflowMetrics.currentActive = activeCount
    if activeCount > WorkflowMetrics.peakConcurrent then
        WorkflowMetrics.peakConcurrent = activeCount
    end
    
    return activeCount < WorkflowConfig.maxConcurrentWorkflows, activeCount
end

local function updateWorkflowMetrics(event, workflow)
    if event == "created" then
        WorkflowMetrics.totalCreated = WorkflowMetrics.totalCreated + 1
    elseif event == "completed" then
        WorkflowMetrics.totalCompleted = WorkflowMetrics.totalCompleted + 1
        WorkflowMetrics.currentActive = math.max(0, WorkflowMetrics.currentActive - 1)
    elseif event == "failed" then
        WorkflowMetrics.totalFailed = WorkflowMetrics.totalFailed + 1
        WorkflowMetrics.currentActive = math.max(0, WorkflowMetrics.currentActive - 1)
    elseif event == "timeout" then
        WorkflowMetrics.totalTimedOut = WorkflowMetrics.totalTimedOut + 1
        WorkflowMetrics.currentActive = math.max(0, WorkflowMetrics.currentActive - 1)
    end
end

local function createWorkflow(workflowType, steps, requester, data, priority, customTimeout)
    -- Check capacity before creating workflow
    local hasCapacity, currentCount = checkWorkflowCapacity()
    if not hasCapacity then
        return nil, "Maximum concurrent workflow limit reached: " .. WorkflowConfig.maxConcurrentWorkflows
    end
    
    -- Check if approaching capacity warning threshold
    if currentCount >= WorkflowConfig.capacityWarningThreshold then
        print("Warning: Workflow capacity at " .. math.floor((currentCount / WorkflowConfig.maxConcurrentWorkflows) * 100) .. "%")
    end
    
    local workflowId = generateWorkflowId()
    local priorityLevel = getWorkflowPriorityLevel(priority)
    local timeout = customTimeout or WorkflowConfig.defaultTimeout
    
    local workflow = {
        id = workflowId,
        type = workflowType,
        steps = steps,
        currentStep = 1,
        requester = requester,
        data = data or {},
        status = "active",
        priority = priorityLevel,
        priorityScore = WorkflowConfig.priorityLevels[priorityLevel],
        timeout = timeout,
        created = getCurrentTimestamp(),
        lastActivity = getCurrentTimestamp(),
        responses = {},
        timeouts = {},
        resourceConsumption = {
            memoryUsage = 0,
            processingTime = 0,
            messagesSent = 0
        },
        recovery = {
            retryCount = 0,
            maxRetries = RetryConfig.maxRetries,
            lastError = nil,
            nextRetryTime = 0,
            circuitBreakerBypass = false,
            fallbackProcesses = {},
            degradationMode = false
        }
    }
    
    ActiveWorkflows[workflowId] = workflow
    updateWorkflowMetrics("created", workflow)
    
    -- Add to priority queue for execution ordering
    table.insert(WorkflowPriorityQueue[priorityLevel], workflowId)
    
    return workflowId, nil
end

local function updateWorkflowStep(workflowId, stepResponse)
    local workflow = ActiveWorkflows[workflowId]
    if not workflow then
        return false, "Workflow not found"
    end
    
    workflow.responses[workflow.currentStep] = stepResponse
    workflow.lastActivity = getCurrentTimestamp()
    workflow.resourceConsumption.processingTime = workflow.lastActivity - workflow.created
    
    -- Update resource consumption tracking
    if stepResponse and stepResponse.resourceUsage then
        workflow.resourceConsumption.memoryUsage = workflow.resourceConsumption.memoryUsage + (stepResponse.resourceUsage.memory or 0)
    end
    
    if workflow.currentStep >= #workflow.steps then
        workflow.status = "completed"
        updateWorkflowMetrics("completed", workflow)
        
        -- Memory optimization: clear large response data if enabled
        if WorkflowConfig.memoryOptimization then
            -- Keep only essential completion data
            workflow.data = nil
            for i = 1, workflow.currentStep - 1 do
                if workflow.responses[i] and workflow.responses[i].response then
                    workflow.responses[i].response = "[optimized]"
                end
            end
        end
        
        return true, "Workflow completed"
    else
        workflow.currentStep = workflow.currentStep + 1
        return true, "Step completed, proceeding to next"
    end
end

local function executeWorkflowStep(workflowId)
    local workflow = ActiveWorkflows[workflowId]
    if not workflow or workflow.status ~= "active" then
        return false, "Invalid or inactive workflow"
    end
    
    local step = workflow.steps[workflow.currentStep]
    if not step then
        return false, "Invalid step"
    end
    
    local targetProcess = getProcessId(step.process)
    if not targetProcess then
        return false, "Target process not available: " .. step.process
    end
    
    -- Send message to target process
    local success, err = pcall(function()
        ao.send({
            Target = targetProcess,
            Action = step.action,
            WorkflowId = workflowId,
            StepNumber = workflow.currentStep,
            Data = json.encode(step.data),
            Timestamp = getCurrentTimestamp(),
            Requester = workflow.requester
        })
    end)
    
    if not success then
        return false, "Failed to send message: " .. tostring(err)
    end
    
    -- Set timeout for this step using workflow-specific timeout
    workflow.timeouts[workflow.currentStep] = getCurrentTimestamp() + workflow.timeout
    workflow.resourceConsumption.messagesSent = workflow.resourceConsumption.messagesSent + 1
    return true, "Step executed"
end

-- Enhanced Message Routing with Load Balancing and Intelligent Selection
local function getBestProcessInstance(processName, algorithm)
    algorithm = algorithm or RoutingConfig.defaultAlgorithm
    local allProcesses = getAllProcesses()
    local process = allProcesses[processName]
    
    if not process or not process.id then
        return nil, "Process not available: " .. processName
    end
    
    -- If no multiple instances, return the primary instance
    if #process.instances == 0 then
        if process.healthScore < 30 and RoutingConfig.failoverEnabled then
            return nil, "Process unhealthy and no failover available: " .. processName
        end
        return process.id, nil
    end
    
    -- Multiple instances available - apply load balancing
    local candidates = {}
    table.insert(candidates, { id = process.id, score = process.healthScore, load = process.load })
    
    for _, instance in ipairs(process.instances) do
        local instanceProcess = allProcesses[instance.id]
        if instanceProcess and instanceProcess.healthScore > 30 then
            table.insert(candidates, { 
                id = instance.id, 
                score = instanceProcess.healthScore, 
                load = instanceProcess.load 
            })
        end
    end
    
    if #candidates == 0 then
        return nil, "No healthy instances available for: " .. processName
    end
    
    -- Apply load balancing algorithm
    local selectedInstance
    
    if algorithm == LoadBalancingAlgorithms.healthScore then
        -- Select instance with highest health score
        table.sort(candidates, function(a, b) return a.score > b.score end)
        selectedInstance = candidates[1]
    elseif algorithm == LoadBalancingAlgorithms.leastConnections then
        -- Select instance with lowest load
        table.sort(candidates, function(a, b) return a.load < b.load end)
        selectedInstance = candidates[1]
    elseif algorithm == LoadBalancingAlgorithms.roundRobin then
        -- Simple round robin (using timestamp for pseudo-randomness)
        local index = (getCurrentTimestamp() % #candidates) + 1
        selectedInstance = candidates[index]
    else
        -- Default to health score
        table.sort(candidates, function(a, b) return a.score > b.score end)
        selectedInstance = candidates[1]
    end
    
    return selectedInstance.id, nil
end

local function checkRoutingCache(cacheKey)
    if not RoutingConfig.cacheEnabled then return nil end
    
    local cached = RoutingCache.cache[cacheKey]
    if cached and (getCurrentTimestamp() - cached.timestamp) < RoutingCache.cacheTimeout then
        RoutingCache.hitCount = RoutingCache.hitCount + 1
        return cached.processId
    end
    
    RoutingCache.missCount = RoutingCache.missCount + 1
    return nil
end

local function updateRoutingCache(cacheKey, processId)
    if not RoutingConfig.cacheEnabled then return end
    
    -- Implement LRU cache
    if #RoutingCache.cache >= RoutingCache.maxCacheSize then
        local oldestKey = nil
        local oldestTime = getCurrentTimestamp()
        
        for key, entry in pairs(RoutingCache.cache) do
            if entry.timestamp < oldestTime then
                oldestTime = entry.timestamp
                oldestKey = key
            end
        end
        
        if oldestKey then
            RoutingCache.cache[oldestKey] = nil
        end
    end
    
    RoutingCache.cache[cacheKey] = {
        processId = processId,
        timestamp = getCurrentTimestamp()
    }
end

local function routeMessage(msg)
    local targetProcess = msg.TargetProcess
    if not targetProcess then
        return false, "No target process specified"
    end
    
    local startTime = getCurrentTimestamp()
    local cacheKey = targetProcess .. "_" .. (msg.Action or "default")
    
    -- Check routing cache first
    local cachedProcessId = checkRoutingCache(cacheKey)
    local processId
    local routingError
    
    if cachedProcessId then
        processId = cachedProcessId
    else
        processId, routingError = getBestProcessInstance(targetProcess, msg.LoadBalancingAlgorithm)
        if processId then
            updateRoutingCache(cacheKey, processId)
        end
    end
    
    if not processId then
        updateProcessMetrics(targetProcess, nil, false)
        return false, routingError or "Target process not available: " .. targetProcess
    end
    
    local success, err = pcall(function()
        ao.send({
            Target = processId,
            Action = msg.Action or "ProcessMessage",
            Data = msg.Data,
            Priority = msg.Priority,
            OrderingKey = msg.OrderingKey,
            OriginalSender = msg.From,
            RoutedBy = ao.id,
            RouteTime = getCurrentTimestamp(),
            Timestamp = getCurrentTimestamp()
        })
    end)
    
    local endTime = getCurrentTimestamp()
    local routeTime = endTime - startTime
    
    if not success then
        updateProcessMetrics(targetProcess, routeTime, false)
        return false, "Failed to route message: " .. tostring(err)
    end
    
    updateProcessMetrics(targetProcess, routeTime, true)
    return true, "Message routed successfully to " .. processId .. " (" .. routeTime .. "ms)"
end

-- Enhanced Health Monitoring with Performance Tracking
local function checkProcessHealth(processName)
    local allProcesses = getAllProcesses()
    local process = allProcesses[processName]
    
    if not process or not process.id then
        return false, "Process not discovered"
    end
    
    local healthCheckStart = getCurrentTimestamp()
    
    local success, err = pcall(function()
        ao.send({
            Target = process.id,
            Action = "HealthCheck",
            RequestId = string.format("health_%d_%s", getCurrentTimestamp(), processName),
            Timestamp = getCurrentTimestamp(),
            Requester = ao.id,
            HealthCheckType = "performance",
            ExpectedResponseTime = RoutingConfig.latencyTarget
        })
    end)
    
    if not success then
        -- Update metrics for failed health check
        updateProcessMetrics(processName, nil, false)
        return false, "Failed to send health check: " .. tostring(err)
    end
    
    -- Store health check start time for response time calculation
    process.lastHealthCheckStart = healthCheckStart
    
    return true, "Health check sent"
end

local function performIntelligentHealthCheck()
    local allProcesses = getAllProcesses()
    local healthCheckResults = {
        timestamp = getCurrentTimestamp(),
        processesChecked = 0,
        healthyProcesses = 0,
        degradedProcesses = 0,
        unhealthyProcesses = 0,
        averageResponseTime = 0,
        routingCacheStats = {
            hitRate = 0,
            totalHits = RoutingCache.hitCount,
            totalMisses = RoutingCache.missCount
        }
    }
    
    local totalResponseTime = 0
    local responseTimeCount = 0
    
    for name, process in pairs(allProcesses) do
        healthCheckResults.processesChecked = healthCheckResults.processesChecked + 1
        
        -- Update health score
        process.healthScore = calculateHealthScore(process)
        
        -- Categorize process health
        if process.healthScore >= 80 then
            healthCheckResults.healthyProcesses = healthCheckResults.healthyProcesses + 1
        elseif process.healthScore >= 50 then
            healthCheckResults.degradedProcesses = healthCheckResults.degradedProcesses + 1
        else
            healthCheckResults.unhealthyProcesses = healthCheckResults.unhealthyProcesses + 1
        end
        
        -- Accumulate response times
        if process.responseTime > 0 then
            totalResponseTime = totalResponseTime + process.responseTime
            responseTimeCount = responseTimeCount + 1
        end
        
        -- Send health check if process is discovered
        if process.id then
            checkProcessHealth(name)
        end
    end
    
    -- Calculate average response time
    if responseTimeCount > 0 then
        healthCheckResults.averageResponseTime = totalResponseTime / responseTimeCount
    end
    
    -- Calculate cache hit rate
    local totalCacheRequests = RoutingCache.hitCount + RoutingCache.missCount
    if totalCacheRequests > 0 then
        healthCheckResults.routingCacheStats.hitRate = (RoutingCache.hitCount / totalCacheRequests) * 100
    end
    
    return healthCheckResults
end

local function checkAllProcessesHealth()
    return performIntelligentHealthCheck()
end

-- Enhanced Workflow Timeout and Persistence Management
local function performWorkflowCleanup()
    local currentTime = getCurrentTimestamp()
    if currentTime - LastCleanupTime < WorkflowConfig.cleanupInterval then
        return -- Skip cleanup if too recent
    end
    
    LastCleanupTime = currentTime
    local cleanupThreshold = currentTime - 3600000 -- 1 hour
    local cleaned = 0
    
    for workflowId, workflow in pairs(ActiveWorkflows) do
        if (workflow.status == "completed" or workflow.status == "failed" or workflow.status == "timeout")
           and workflow.lastActivity < cleanupThreshold then
            ActiveWorkflows[workflowId] = nil
            cleaned = cleaned + 1
        end
    end
    
    -- Clean priority queues
    for priority, queue in pairs(WorkflowPriorityQueue) do
        local cleanedQueue = {}
        for _, workflowId in ipairs(queue) do
            if ActiveWorkflows[workflowId] then
                table.insert(cleanedQueue, workflowId)
            end
        end
        WorkflowPriorityQueue[priority] = cleanedQueue
    end
    
    return cleaned
end

local function getNextPriorityWorkflow()
    -- Get next workflow from priority queues
    local priorities = {"critical", "high", "normal", "low"}
    
    for _, priority in ipairs(priorities) do
        local queue = WorkflowPriorityQueue[priority]
        if #queue > 0 then
            local workflowId = table.remove(queue, 1)
            if ActiveWorkflows[workflowId] and ActiveWorkflows[workflowId].status == "pending" then
                return workflowId
            end
        end
    end
    
    return nil
end

local function checkWorkflowTimeouts()
    local currentTime = getCurrentTimestamp()
    local timedOutWorkflows = {}
    
    for workflowId, workflow in pairs(ActiveWorkflows) do
        if workflow.status == "active" then
            local stepTimeout = workflow.timeouts[workflow.currentStep]
            if stepTimeout and currentTime > stepTimeout then
                -- Check if we can retry or need to fail
                if workflow.recovery.retryCount < workflow.recovery.maxRetries then
                    workflow.recovery.retryCount = workflow.recovery.retryCount + 1
                    workflow.recovery.lastError = "Step timeout after " .. workflow.timeout .. "ms (retry " .. workflow.recovery.retryCount .. ")"
                    workflow.recovery.nextRetryTime = currentTime + calculateRetryDelay(workflow.recovery.retryCount)
                    workflow.status = "retrying"
                    
                    -- Try graceful degradation
                    local currentStep = workflow.steps[workflow.currentStep]
                    if currentStep then
                        local fallbackProcess = findFallbackProcess(currentStep.process)
                        if fallbackProcess then
                            workflow.recovery.degradationMode = true
                            table.insert(workflow.recovery.fallbackProcesses, fallbackProcess)
                        end
                    end
                else
                    workflow.status = "timeout"
                    workflow.recovery.lastError = "Step timeout after " .. workflow.timeout .. "ms (max retries exceeded)"
                    updateWorkflowMetrics("timeout", workflow)
                    table.insert(timedOutWorkflows, workflowId)
                    
                    -- Add to dead letter queue for manual intervention
                    addToDeadLetterQueue({
                        workflowId = workflowId,
                        type = workflow.type,
                        step = workflow.currentStep,
                        requester = workflow.requester
                    }, workflow.recovery.lastError)
                    
                    sendErrorResponse(
                        workflow.requester,
                        workflowId,
                        "Workflow step timeout: " .. workflow.recovery.lastError,
                        "coordinateWorkflow"
                    )
                end
            end
        end
    end
    
    -- Handle retry workflows
    local retriedWorkflows = {}
    for workflowId, workflow in pairs(ActiveWorkflows) do
        if workflow.status == "retrying" and currentTime >= workflow.recovery.nextRetryTime then
            workflow.status = "active"
            
            -- Execute workflow step with potential fallback
            local stepSuccess, stepErr
            if workflow.recovery.degradationMode and #workflow.recovery.fallbackProcesses > 0 then
                -- Try fallback process
                local originalProcess = workflow.steps[workflow.currentStep].process
                workflow.steps[workflow.currentStep].process = workflow.recovery.fallbackProcesses[1]
                stepSuccess, stepErr = executeWorkflowStep(workflowId)
                
                if not stepSuccess then
                    -- Fallback failed, restore original and mark as failed
                    workflow.steps[workflow.currentStep].process = originalProcess
                    workflow.status = "failed"
                    workflow.recovery.lastError = "Fallback process also failed: " .. stepErr
                    updateWorkflowMetrics("failed", workflow)
                end
            else
                stepSuccess, stepErr = executeWorkflowStep(workflowId)
                if not stepSuccess then
                    workflow.status = "failed"
                    workflow.recovery.lastError = "Retry failed: " .. stepErr
                    updateWorkflowMetrics("failed", workflow)
                end
            end
            
            table.insert(retriedWorkflows, workflowId)
        end
    end
    
    -- Perform periodic cleanup
    performWorkflowCleanup()
    local dlqCleaned = cleanupDeadLetterQueue()
    
    return timedOutWorkflows, retriedWorkflows, dlqCleaned
end

local function saveWorkflowState()
    -- Workflow state persistence for coordinator restarts
    local persistentState = {
        workflows = {},
        metrics = WorkflowMetrics,
        timestamp = getCurrentTimestamp()
    }
    
    -- Save only essential workflow data
    for workflowId, workflow in pairs(ActiveWorkflows) do
        if workflow.status == "active" or workflow.status == "pending" then
            persistentState.workflows[workflowId] = {
                id = workflow.id,
                type = workflow.type,
                status = workflow.status,
                priority = workflow.priority,
                currentStep = workflow.currentStep,
                requester = workflow.requester,
                created = workflow.created,
                lastActivity = workflow.lastActivity,
                timeout = workflow.timeout
            }
        end
    end
    
    return persistentState
end

local function restoreWorkflowState(persistentState)
    if not persistentState or not persistentState.workflows then
        return false, "No valid persistent state"
    end
    
    local restoredCount = 0
    for workflowId, workflowData in pairs(persistentState.workflows) do
        -- Restore only if workflow is still valid (not too old)
        local currentTime = getCurrentTimestamp()
        if currentTime - workflowData.lastActivity < 300000 then -- 5 minutes
            ActiveWorkflows[workflowId] = {
                id = workflowData.id,
                type = workflowData.type,
                status = "pending", -- Mark as pending for re-execution
                priority = workflowData.priority,
                currentStep = workflowData.currentStep,
                requester = workflowData.requester,
                created = workflowData.created,
                lastActivity = currentTime,
                timeout = workflowData.timeout,
                responses = {},
                timeouts = {},
                recovery = { retryCount = 0, maxRetries = 3, lastError = "Restored from persistence" }
            }
            restoredCount = restoredCount + 1
        end
    end
    
    if persistentState.metrics then
        WorkflowMetrics = persistentState.metrics
    end
    
    return true, "Restored " .. restoredCount .. " workflows"
end

-- Client-Side GameState Persistence Architecture
local GameStatePersistence = {
    versioningEnabled = true,
    compressionEnabled = true,
    validationEnabled = true,
    conflictResolution = {
        strategy = "last_write_wins", -- last_write_wins, merge, manual
        maxConflictAge = 300000 -- 5 minutes
    },
    backup = {
        enabled = true,
        maxBackups = 10,
        backupInterval = 600000 -- 10 minutes
    },
    synchronization = {
        enabled = true,
        maxConcurrentClients = 5,
        lockTimeout = 30000 -- 30 seconds
    }
}

local function generateGameStateVersion()
    return string.format("v_%d_%s", getCurrentTimestamp(), ao.id:sub(1, 6))
end

local function calculateGameStateChecksum(gameStateData)
    -- Simple checksum for integrity validation
    local checksum = 0
    local dataString = json.encode(gameStateData)
    
    for i = 1, #dataString do
        checksum = (checksum + string.byte(dataString, i)) % 1000000
    end
    
    return tostring(checksum)
end

local function validateGameStateStructure(gameState)
    if not gameState or type(gameState) ~= "table" then
        return false, "GameState must be a table"
    end
    
    -- Required fields for valid GameState
    local requiredFields = {"player", "party", "scene", "timestamp"}
    
    for _, field in ipairs(requiredFields) do
        if not gameState[field] then
            return false, "Missing required GameState field: " .. field
        end
    end
    
    -- Validate player data structure
    if gameState.player then
        local playerRequiredFields = {"id", "name", "money"}
        for _, field in ipairs(playerRequiredFields) do
            if not gameState.player[field] then
                return false, "Missing required player field: " .. field
            end
        end
    end
    
    -- Validate party structure
    if gameState.party and type(gameState.party) ~= "table" then
        return false, "Party must be an array of Pokemon"
    end
    
    return true, nil
end

local function compressGameState(gameState)
    if not GameStatePersistence.compressionEnabled then
        return gameState
    end
    
    -- Simple compression by removing redundant data
    local compressed = {
        p = gameState.player,
        pt = gameState.party,
        s = gameState.scene,
        ts = gameState.timestamp,
        v = gameState.version
    }
    
    return compressed
end

local function decompressGameState(compressedState)
    if not compressedState.p then
        return compressedState -- Not compressed
    end
    
    local gameState = {
        player = compressedState.p,
        party = compressedState.pt,
        scene = compressedState.s,
        timestamp = compressedState.ts,
        version = compressedState.v
    }
    
    return gameState
end

local function detectGameStateConflicts(clientState, serverState)
    if not clientState or not serverState then
        return false, nil
    end
    
    local conflicts = {}
    local clientTime = clientState.timestamp or 0
    local serverTime = serverState.timestamp or 0
    
    -- Time-based conflict detection
    if math.abs(clientTime - serverTime) > GameStatePersistence.conflictResolution.maxConflictAge then
        table.insert(conflicts, {
            type = "timestamp",
            clientValue = clientTime,
            serverValue = serverTime,
            description = "Significant time difference detected"
        })
    end
    
    -- Version conflict detection
    if clientState.version and serverState.version and clientState.version ~= serverState.version then
        table.insert(conflicts, {
            type = "version",
            clientValue = clientState.version,
            serverValue = serverState.version,
            description = "Version mismatch detected"
        })
    end
    
    -- Data structure conflicts (simplified)
    if clientState.player and serverState.player then
        if clientState.player.money ~= serverState.player.money then
            table.insert(conflicts, {
                type = "player_money",
                clientValue = clientState.player.money,
                serverValue = serverState.player.money,
                description = "Player money values differ"
            })
        end
    end
    
    return #conflicts > 0, conflicts
end

local function resolveGameStateConflicts(clientState, serverState, conflicts)
    local resolvedState = {}
    
    if GameStatePersistence.conflictResolution.strategy == "last_write_wins" then
        -- Use the state with the most recent timestamp
        local clientTime = clientState.timestamp or 0
        local serverTime = serverState.timestamp or 0
        
        if clientTime > serverTime then
            resolvedState = clientState
        else
            resolvedState = serverState
        end
        
        -- Update version and timestamp
        resolvedState.version = generateGameStateVersion()
        resolvedState.timestamp = getCurrentTimestamp()
        resolvedState.conflictResolution = {
            strategy = "last_write_wins",
            resolvedAt = getCurrentTimestamp(),
            conflictCount = #conflicts
        }
    elseif GameStatePersistence.conflictResolution.strategy == "merge" then
        -- Merge strategy (simplified)
        resolvedState = serverState
        
        -- Merge player data taking highest values where safe
        if clientState.player and serverState.player then
            resolvedState.player.money = math.max(
                clientState.player.money or 0,
                serverState.player.money or 0
            )
        end
        
        -- Use newer scene data
        if clientState.timestamp > serverState.timestamp then
            resolvedState.scene = clientState.scene
        end
        
        resolvedState.version = generateGameStateVersion()
        resolvedState.timestamp = getCurrentTimestamp()
        resolvedState.conflictResolution = {
            strategy = "merge",
            resolvedAt = getCurrentTimestamp(),
            conflictCount = #conflicts
        }
    end
    
    return resolvedState
end

local function createGameStateBackup(gameState, backupReason)
    if not GameStatePersistence.backup.enabled then
        return nil
    end
    
    local backup = {
        id = string.format("backup_%d_%s", getCurrentTimestamp(), ao.id:sub(1, 6)),
        gameState = gameState,
        reason = backupReason or "manual",
        timestamp = getCurrentTimestamp(),
        checksum = calculateGameStateChecksum(gameState)
    }
    
    return backup
end

-- Game State Coordination
local function coordinateGameState(operation, data)
    local stateOperations = {
        "save", "load", "sync", "backup", "restore"
    }
    
    local isValidOperation = false
    for _, op in ipairs(stateOperations) do
        if op == operation then
            isValidOperation = true
            break
        end
    end
    
    if not isValidOperation then
        return false, "Invalid state operation: " .. tostring(operation)
    end
    
    -- Create workflow for state coordination
    local steps = {}
    
    if operation == "save" then
        table.insert(steps, { process = "player-state", action = "SaveState", data = data })
        table.insert(steps, { process = "inventory-manager", action = "SaveInventory", data = data })
        table.insert(steps, { process = "team-manager", action = "SaveTeam", data = data })
    elseif operation == "load" then
        table.insert(steps, { process = "player-state", action = "LoadState", data = data })
        table.insert(steps, { process = "inventory-manager", action = "LoadInventory", data = data })
        table.insert(steps, { process = "team-manager", action = "LoadTeam", data = data })
    elseif operation == "sync" then
        table.insert(steps, { process = "player-state", action = "SyncState", data = data })
        table.insert(steps, { process = "inventory-manager", action = "SyncInventory", data = data })
        table.insert(steps, { process = "team-manager", action = "SyncTeam", data = data })
    end
    
    return steps
end

-- Handlers

-- Process Discovery Handler
Handlers.add("process-discovery",
    Handlers.utils.hasMatchingTag("Action", "RegisterProcess"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"ProcessName", "ProcessId"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "RegisterProcess")
                return
            end
            
            local discovered = discoverProcess(msg.ProcessName, msg.ProcessId)
            if discovered then
                ao.send({
                    Target = msg.From,
                    Action = "ProcessRegistered",
                    ProcessName = msg.ProcessName,
                    Status = "success",
                    Timestamp = getCurrentTimestamp()
                })
            else
                sendErrorResponse(msg.From, nil, "Unknown process name: " .. msg.ProcessName, "RegisterProcess")
            end
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Registration failed: " .. tostring(err), "RegisterProcess")
        end
    end
)

-- Workflow Coordination Handler
Handlers.add("coordinate-workflow",
    Handlers.utils.hasMatchingTag("Action", "CoordinateWorkflow"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"WorkflowType", "Steps"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "CoordinateWorkflow")
                return
            end
            
            local steps = json.decode(msg.Steps)
            local data = msg.Data and json.decode(msg.Data) or {}
            local priority = msg.Priority or "normal"
            local customTimeout = msg.Timeout and tonumber(msg.Timeout)
            
            local workflowId, createErr = createWorkflow(msg.WorkflowType, steps, msg.From, data, priority, customTimeout)
            if not workflowId then
                sendErrorResponse(msg.From, nil, createErr, "CoordinateWorkflow")
                return
            end
            
            -- Execute first step with circuit breaker and retry logic
            local operation = function()
                return executeWorkflowStep(workflowId)
            end
            
            local stepSuccess, stepErr = executeWithRetry(operation, steps[1].process, RetryConfig.maxRetries)
            if not stepSuccess then
                ActiveWorkflows[workflowId].status = "failed"
                ActiveWorkflows[workflowId].recovery.lastError = stepErr
                
                -- Check for graceful degradation
                if shouldTriggerDegradation(steps[1].process) then
                    local fallbackProcess = findFallbackProcess(steps[1].process)
                    if fallbackProcess then
                        ActiveWorkflows[workflowId].recovery.degradationMode = true
                        steps[1].process = fallbackProcess
                        stepSuccess, stepErr = executeWorkflowStep(workflowId)
                    end
                end
                
                if not stepSuccess then
                    updateWorkflowMetrics("failed", ActiveWorkflows[workflowId])
                    addToDeadLetterQueue({
                        workflowType = msg.WorkflowType,
                        steps = steps,
                        requester = msg.From,
                        data = data
                    }, stepErr)
                    sendErrorResponse(msg.From, workflowId, stepErr, "CoordinateWorkflow")
                    return
                end
            end
            
            ao.send({
                Target = msg.From,
                Action = "WorkflowStarted",
                WorkflowId = workflowId,
                Status = "active",
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Workflow creation failed: " .. tostring(err), "CoordinateWorkflow")
        end
    end
)

-- Workflow Response Handler
Handlers.add("workflow-response",
    Handlers.utils.hasMatchingTag("Action", "WorkflowResponse"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"WorkflowId", "StepNumber"})
            if not valid then
                sendErrorResponse(msg.From, msg.WorkflowId, validationError, "WorkflowResponse")
                return
            end
            
            local stepComplete, updateErr = updateWorkflowStep(msg.WorkflowId, {
                stepNumber = tonumber(msg.StepNumber),
                response = msg.Data,
                processId = msg.From,
                timestamp = getCurrentTimestamp()
            })
            
            if not stepComplete then
                sendErrorResponse(msg.From, msg.WorkflowId, updateErr, "WorkflowResponse")
                return
            end
            
            local workflow = ActiveWorkflows[msg.WorkflowId]
            if workflow.status == "completed" then
                -- Send final response to requester
                ao.send({
                    Target = workflow.requester,
                    Action = "WorkflowCompleted",
                    WorkflowId = msg.WorkflowId,
                    Results = json.encode(workflow.responses),
                    Timestamp = getCurrentTimestamp()
                })
            else
                -- Execute next step
                local nextSuccess, nextErr = executeWorkflowStep(msg.WorkflowId)
                if not nextSuccess then
                    workflow.status = "failed"
                    sendErrorResponse(workflow.requester, msg.WorkflowId, nextErr, "CoordinateWorkflow")
                end
            end
        end)
        
        if not success then
            sendErrorResponse(msg.From, msg.WorkflowId, "Response processing failed: " .. tostring(err), "WorkflowResponse")
        end
    end
)

-- Message Routing Handler
Handlers.add("route-message",
    Handlers.utils.hasMatchingTag("Action", "RouteMessage"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"TargetProcess"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "RouteMessage")
                return
            end
            
            local routeSuccess, routeErr = routeMessage(msg)
            if not routeSuccess then
                sendErrorResponse(msg.From, nil, routeErr, "RouteMessage")
                return
            end
            
            ao.send({
                Target = msg.From,
                Action = "MessageRouted",
                TargetProcess = msg.TargetProcess,
                Status = "success",
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Message routing failed: " .. tostring(err), "RouteMessage")
        end
    end
)

-- Health Check Handler
Handlers.add("check-process-health",
    Handlers.utils.hasMatchingTag("Action", "CheckProcessHealth"),
    function(msg)
        local success, err = pcall(function()
            local healthReport
            
            if msg.ProcessName then
                -- Check specific process
                local valid, validationError = validateMessage(msg, {"ProcessName"})
                if not valid then
                    sendErrorResponse(msg.From, nil, validationError, "CheckProcessHealth")
                    return
                end
                
                local healthSuccess, healthErr = checkProcessHealth(msg.ProcessName)
                healthReport = {
                    process = msg.ProcessName,
                    success = healthSuccess,
                    error = healthErr,
                    timestamp = getCurrentTimestamp()
                }
            else
                -- Check all processes
                healthReport = checkAllProcessesHealth()
            end
            
            ao.send({
                Target = msg.From,
                Action = "HealthReport",
                Data = json.encode(healthReport),
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Health check failed: " .. tostring(err), "CheckProcessHealth")
        end
    end
)

-- Enhanced Health Response Handler with Performance Metrics
Handlers.add("health-response",
    Handlers.utils.hasMatchingTag("Action", "HealthResponse"),
    function(msg)
        local success, err = pcall(function()
            local processName = msg.ProcessName
            if not processName then
                return -- Ignore malformed health responses
            end
            
            local allProcesses = getAllProcesses()
            local process = allProcesses[processName]
            if process then
                process.status = msg.Status or "healthy"
                process.lastHealth = getCurrentTimestamp()
                
                -- Calculate response time if health check start time is available
                if process.lastHealthCheckStart then
                    local responseTime = process.lastHealth - process.lastHealthCheckStart
                    updateProcessMetrics(processName, responseTime, true)
                    process.lastHealthCheckStart = nil
                end
                
                -- Update load information if provided
                if msg.Load then
                    process.load = tonumber(msg.Load) or 0
                end
                
                -- Update process metrics from health response
                if msg.Metrics then
                    local metrics = json.decode(msg.Metrics)
                    if metrics.responseTime then
                        process.responseTime = tonumber(metrics.responseTime)
                    end
                    if metrics.errorRate then
                        process.errorRate = tonumber(metrics.errorRate)
                    end
                end
                
                -- Recalculate health score
                process.healthScore = calculateHealthScore(process)
            end
        end)
        
        if not success then
            -- Log error but don't send response to avoid loops
            print("Health response processing error: " .. tostring(err))
        end
    end
)

-- Process Performance Monitoring Handler
Handlers.add("process-performance",
    Handlers.utils.hasMatchingTag("Action", "GetProcessPerformance"),
    function(msg)
        local success, err = pcall(function()
            local performanceData = {
                timestamp = getCurrentTimestamp(),
                routingStats = {
                    cacheHitRate = 0,
                    totalCacheHits = RoutingCache.hitCount,
                    totalCacheMisses = RoutingCache.missCount,
                    averageRouteTime = 0
                },
                processHealth = {},
                loadBalancing = {
                    algorithm = RoutingConfig.defaultAlgorithm,
                    failoverEnabled = RoutingConfig.failoverEnabled,
                    latencyTarget = RoutingConfig.latencyTarget
                }
            }
            
            -- Calculate cache hit rate
            local totalCacheRequests = RoutingCache.hitCount + RoutingCache.missCount
            if totalCacheRequests > 0 then
                performanceData.routingStats.cacheHitRate = (RoutingCache.hitCount / totalCacheRequests) * 100
            end
            
            -- Collect process health and performance data
            local allProcesses = getAllProcesses()
            local totalResponseTime = 0
            local responseTimeCount = 0
            
            for name, process in pairs(allProcesses) do
                performanceData.processHealth[name] = {
                    healthScore = process.healthScore,
                    status = process.status,
                    responseTime = process.responseTime,
                    errorRate = math.floor(process.errorRate * 100),
                    availability = math.floor(process.availability),
                    load = process.load,
                    maxLoad = process.maxLoad,
                    instanceCount = #process.instances + (process.id and 1 or 0),
                    metrics = process.metrics
                }
                
                if process.responseTime > 0 then
                    totalResponseTime = totalResponseTime + process.responseTime
                    responseTimeCount = responseTimeCount + 1
                end
            end
            
            -- Calculate average route time
            if responseTimeCount > 0 then
                performanceData.routingStats.averageRouteTime = totalResponseTime / responseTimeCount
            end
            
            ao.send({
                Target = msg.From,
                Action = "ProcessPerformanceResponse",
                Data = json.encode(performanceData),
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Process performance query failed: " .. tostring(err), "GetProcessPerformance")
        end
    end
)

-- Load Balancing Configuration Handler
Handlers.add("configure-load-balancing",
    Handlers.utils.hasMatchingTag("Action", "ConfigureLoadBalancing"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"Algorithm"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "ConfigureLoadBalancing")
                return
            end
            
            -- Validate algorithm
            local validAlgorithms = {"round_robin", "least_connections", "health_score", "response_time"}
            local algorithmValid = false
            for _, alg in ipairs(validAlgorithms) do
                if alg == msg.Algorithm then
                    algorithmValid = true
                    break
                end
            end
            
            if not algorithmValid then
                sendErrorResponse(msg.From, nil, "Invalid load balancing algorithm: " .. msg.Algorithm, "ConfigureLoadBalancing")
                return
            end
            
            -- Update configuration
            RoutingConfig.defaultAlgorithm = msg.Algorithm
            if msg.FailoverEnabled then
                RoutingConfig.failoverEnabled = msg.FailoverEnabled == "true"
            end
            if msg.LatencyTarget then
                RoutingConfig.latencyTarget = tonumber(msg.LatencyTarget) or RoutingConfig.latencyTarget
            end
            if msg.CacheEnabled then
                RoutingConfig.cacheEnabled = msg.CacheEnabled == "true"
            end
            
            -- Clear routing cache after configuration change
            RoutingCache.cache = {}
            RoutingCache.hitCount = 0
            RoutingCache.missCount = 0
            
            ao.send({
                Target = msg.From,
                Action = "LoadBalancingConfigured",
                Configuration = json.encode(RoutingConfig),
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Load balancing configuration failed: " .. tostring(err), "ConfigureLoadBalancing")
        end
    end
)

-- Circuit Breaker Management Handler
Handlers.add("circuit-breaker-management",
    Handlers.utils.hasMatchingTag("Action", "ManageCircuitBreaker"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"Operation"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "ManageCircuitBreaker")
                return
            end
            
            local operation = msg.Operation
            local processName = msg.ProcessName
            
            if operation == "GetStatus" then
                local status = {}
                for name, breaker in pairs(CircuitBreakers) do
                    if not processName or name == processName then
                        status[name] = {
                            state = breaker.state,
                            failureCount = breaker.failureCount,
                            successCount = breaker.successCount,
                            lastFailureTime = breaker.lastFailureTime,
                            lastStateChange = breaker.lastStateChange
                        }
                    end
                end
                
                ao.send({
                    Target = msg.From,
                    Action = "CircuitBreakerStatus",
                    Data = json.encode(status),
                    Timestamp = getCurrentTimestamp()
                })
            elseif operation == "Reset" and processName then
                if CircuitBreakers[processName] then
                    CircuitBreakers[processName] = {
                        state = "closed",
                        failureCount = 0,
                        successCount = 0,
                        lastFailureTime = 0,
                        lastStateChange = getCurrentTimestamp(),
                        halfOpenCalls = 0
                    }
                    
                    ao.send({
                        Target = msg.From,
                        Action = "CircuitBreakerReset",
                        ProcessName = processName,
                        Status = "success",
                        Timestamp = getCurrentTimestamp()
                    })
                else
                    sendErrorResponse(msg.From, nil, "Circuit breaker not found for process: " .. processName, "ManageCircuitBreaker")
                end
            elseif operation == "Configure" then
                if msg.FailureThreshold then
                    CircuitBreakerConfig.failureThreshold = tonumber(msg.FailureThreshold)
                end
                if msg.RecoveryTimeout then
                    CircuitBreakerConfig.recoveryTimeout = tonumber(msg.RecoveryTimeout)
                end
                
                ao.send({
                    Target = msg.From,
                    Action = "CircuitBreakerConfigured",
                    Configuration = json.encode(CircuitBreakerConfig),
                    Timestamp = getCurrentTimestamp()
                })
            else
                sendErrorResponse(msg.From, nil, "Unknown circuit breaker operation: " .. operation, "ManageCircuitBreaker")
            end
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Circuit breaker management failed: " .. tostring(err), "ManageCircuitBreaker")
        end
    end
)

-- Dead Letter Queue Management Handler
Handlers.add("dead-letter-queue",
    Handlers.utils.hasMatchingTag("Action", "ManageDeadLetterQueue"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"Operation"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "ManageDeadLetterQueue")
                return
            end
            
            local operation = msg.Operation
            
            if operation == "GetMessages" then
                local responseData = {
                    messages = DeadLetterQueue.messages,
                    count = #DeadLetterQueue.messages,
                    maxSize = DeadLetterQueue.maxSize,
                    retentionTime = DeadLetterQueue.retentionTime
                }
                
                ao.send({
                    Target = msg.From,
                    Action = "DeadLetterQueueMessages",
                    Data = json.encode(responseData),
                    Timestamp = getCurrentTimestamp()
                })
            elseif operation == "RetryMessage" and msg.MessageIndex then
                local messageIndex = tonumber(msg.MessageIndex)
                if messageIndex and DeadLetterQueue.messages[messageIndex] then
                    local dlqMessage = DeadLetterQueue.messages[messageIndex]
                    dlqMessage.retryCount = dlqMessage.retryCount + 1
                    
                    -- Re-submit the original message for processing
                    local originalMsg = dlqMessage.originalMessage
                    if originalMsg.workflowType then
                        -- This is a workflow message, recreate the workflow
                        local workflowId, createErr = createWorkflow(
                            originalMsg.workflowType,
                            originalMsg.steps,
                            originalMsg.requester,
                            originalMsg.data
                        )
                        
                        if workflowId then
                            -- Remove from dead letter queue
                            table.remove(DeadLetterQueue.messages, messageIndex)
                            
                            ao.send({
                                Target = msg.From,
                                Action = "DeadLetterMessageRetried",
                                WorkflowId = workflowId,
                                Status = "success",
                                Timestamp = getCurrentTimestamp()
                            })
                        else
                            sendErrorResponse(msg.From, nil, "Failed to retry message: " .. (createErr or "unknown error"), "ManageDeadLetterQueue")
                        end
                    else
                        sendErrorResponse(msg.From, nil, "Unsupported message type for retry", "ManageDeadLetterQueue")
                    end
                else
                    sendErrorResponse(msg.From, nil, "Invalid message index: " .. tostring(messageIndex), "ManageDeadLetterQueue")
                end
            elseif operation == "Clear" then
                local clearedCount = #DeadLetterQueue.messages
                DeadLetterQueue.messages = {}
                
                ao.send({
                    Target = msg.From,
                    Action = "DeadLetterQueueCleared",
                    ClearedCount = clearedCount,
                    Timestamp = getCurrentTimestamp()
                })
            else
                sendErrorResponse(msg.From, nil, "Unknown dead letter queue operation: " .. operation, "ManageDeadLetterQueue")
            end
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Dead letter queue management failed: " .. tostring(err), "ManageDeadLetterQueue")
        end
    end
)

-- Failure Recovery Handler
Handlers.add("failure-recovery",
    Handlers.utils.hasMatchingTag("Action", "TriggerFailureRecovery"),
    function(msg)
        local success, err = pcall(function()
            local recoveryActions = {
                circuitBreakerResets = 0,
                workflowRetries = 0,
                deadLetterProcessed = 0,
                processHealthChecks = 0
            }
            
            -- Reset circuit breakers for processes that have been healthy for a while
            local currentTime = getCurrentTimestamp()
            for processName, breaker in pairs(CircuitBreakers) do
                if breaker.state == "open" and 
                   currentTime - breaker.lastStateChange > CircuitBreakerConfig.recoveryTimeout * 2 then
                    local allProcesses = getAllProcesses()
                    local process = allProcesses[processName]
                    if process and process.healthScore > 70 then
                        breaker.state = "closed"
                        breaker.failureCount = 0
                        breaker.lastStateChange = currentTime
                        recoveryActions.circuitBreakerResets = recoveryActions.circuitBreakerResets + 1
                    end
                end
            end
            
            -- Retry failed workflows that might now succeed
            for workflowId, workflow in pairs(ActiveWorkflows) do
                if workflow.status == "failed" and 
                   workflow.recovery.retryCount < workflow.recovery.maxRetries and
                   currentTime - workflow.lastActivity > 60000 then -- Wait 1 minute before retry
                    workflow.status = "retrying"
                    workflow.recovery.nextRetryTime = currentTime
                    recoveryActions.workflowRetries = recoveryActions.workflowRetries + 1
                end
            end
            
            -- Process some dead letter queue messages
            local dlqProcessed = math.min(5, #DeadLetterQueue.messages) -- Process up to 5 messages
            for i = 1, dlqProcessed do
                local dlqMessage = DeadLetterQueue.messages[1]
                if dlqMessage.retryCount < 3 then -- Max 3 retries for DLQ messages
                    -- Attempt to reprocess
                    table.remove(DeadLetterQueue.messages, 1)
                    recoveryActions.deadLetterProcessed = recoveryActions.deadLetterProcessed + 1
                end
            end
            
            -- Trigger health checks for all processes
            local allProcesses = getAllProcesses()
            for name, process in pairs(allProcesses) do
                if process.id then
                    checkProcessHealth(name)
                    recoveryActions.processHealthChecks = recoveryActions.processHealthChecks + 1
                end
            end
            
            ao.send({
                Target = msg.From,
                Action = "FailureRecoveryComplete",
                RecoveryActions = json.encode(recoveryActions),
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Failure recovery failed: " .. tostring(err), "TriggerFailureRecovery")
        end
    end
)

-- Game State Management Handler
Handlers.add("manage-game-state",
    Handlers.utils.hasMatchingTag("Action", "ManageGameState"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"Operation"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "ManageGameState")
                return
            end
            
            local data = msg.Data and json.decode(msg.Data) or {}
            local steps, stateErr = coordinateGameState(msg.Operation, data)
            
            if not steps then
                sendErrorResponse(msg.From, nil, stateErr, "ManageGameState")
                return
            end
            
            local workflowId = createWorkflow("GameState", steps, msg.From, data)
            
            -- Execute first step
            local stepSuccess, stepErr = executeWorkflowStep(workflowId)
            if not stepSuccess then
                ActiveWorkflows[workflowId].status = "failed"
                sendErrorResponse(msg.From, workflowId, stepErr, "ManageGameState")
                return
            end
            
            ao.send({
                Target = msg.From,
                Action = "GameStateWorkflowStarted",
                WorkflowId = workflowId,
                Operation = msg.Operation,
                Status = "active",
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Game state management failed: " .. tostring(err), "ManageGameState")
        end
    end
)

-- Enhanced Maintenance Handler with Comprehensive Monitoring
Handlers.add("maintenance",
    Handlers.utils.hasMatchingTag("Action", "Maintenance"),
    function(msg)
        local success, err = pcall(function()
            local timedOutWorkflows, retriedWorkflows, dlqCleaned = checkWorkflowTimeouts()
            local currentTime = getCurrentTimestamp()
            local cleaned = performWorkflowCleanup()
            
            -- Count workflows by status
            local statusCounts = { active = 0, pending = 0, completed = 0, failed = 0, timeout = 0 }
            local totalMemoryUsage = 0
            local totalProcessingTime = 0
            
            for _, workflow in pairs(ActiveWorkflows) do
                statusCounts[workflow.status] = (statusCounts[workflow.status] or 0) + 1
                if workflow.resourceConsumption then
                    totalMemoryUsage = totalMemoryUsage + workflow.resourceConsumption.memoryUsage
                    totalProcessingTime = totalProcessingTime + workflow.resourceConsumption.processingTime
                end
            end
            
            -- Calculate capacity utilization
            local totalActive = statusCounts.active + statusCounts.pending
            local capacityUtilization = math.floor((totalActive / WorkflowConfig.maxConcurrentWorkflows) * 100)
            
            -- Generate priority queue status
            local queueStatus = {}
            for priority, queue in pairs(WorkflowPriorityQueue) do
                queueStatus[priority] = #queue
            end
            
            ao.send({
                Target = msg.From,
                Action = "MaintenanceComplete",
                Data = json.encode({
                    timedOutWorkflows = #timedOutWorkflows,
                    cleanedWorkflows = cleaned,
                    workflowCounts = statusCounts,
                    capacityUtilization = capacityUtilization,
                    maxCapacity = WorkflowConfig.maxConcurrentWorkflows,
                    metrics = WorkflowMetrics,
                    queueStatus = queueStatus,
                    resourceUsage = {
                        totalMemoryUsage = totalMemoryUsage,
                        averageProcessingTime = totalActive > 0 and (totalProcessingTime / totalActive) or 0
                    },
                    configuration = WorkflowConfig
                }),
                Timestamp = currentTime
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Maintenance failed: " .. tostring(err), "Maintenance")
        end
    end
)

-- Workflow State Persistence Handler
Handlers.add("workflow-persistence",
    Handlers.utils.hasMatchingTag("Action", "SaveWorkflowState"),
    function(msg)
        local success, err = pcall(function()
            local persistentState = saveWorkflowState()
            
            ao.send({
                Target = msg.From,
                Action = "WorkflowStateSaved",
                Data = json.encode(persistentState),
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Workflow state save failed: " .. tostring(err), "SaveWorkflowState")
        end
    end
)

-- Workflow State Restoration Handler
Handlers.add("workflow-restoration",
    Handlers.utils.hasMatchingTag("Action", "RestoreWorkflowState"),
    function(msg)
        local success, err = pcall(function()
            local valid, validationError = validateMessage(msg, {"Data"})
            if not valid then
                sendErrorResponse(msg.From, nil, validationError, "RestoreWorkflowState")
                return
            end
            
            local persistentState = json.decode(msg.Data)
            local restoreSuccess, restoreResult = restoreWorkflowState(persistentState)
            
            ao.send({
                Target = msg.From,
                Action = restoreSuccess and "WorkflowStateRestored" or "WorkflowRestoreError",
                Message = restoreResult,
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Workflow state restore failed: " .. tostring(err), "RestoreWorkflowState")
        end
    end
)

-- Workflow Metrics Handler
Handlers.add("workflow-metrics",
    Handlers.utils.hasMatchingTag("Action", "GetWorkflowMetrics"),
    function(msg)
        local success, err = pcall(function()
            local currentTime = getCurrentTimestamp()
            local hasCapacity, currentCount = checkWorkflowCapacity()
            
            ao.send({
                Target = msg.From,
                Action = "WorkflowMetricsResponse",
                Data = json.encode({
                    metrics = WorkflowMetrics,
                    currentCapacity = {
                        active = currentCount,
                        max = WorkflowConfig.maxConcurrentWorkflows,
                        available = WorkflowConfig.maxConcurrentWorkflows - currentCount,
                        utilizationPercent = math.floor((currentCount / WorkflowConfig.maxConcurrentWorkflows) * 100)
                    },
                    priorityQueues = WorkflowPriorityQueue,
                    configuration = WorkflowConfig
                }),
                Timestamp = currentTime
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Workflow metrics failed: " .. tostring(err), "GetWorkflowMetrics")
        end
    end
)

-- ADP v1.0 Info Handler (Required for ADP Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        local success, err = pcall(function()
            ao.send({
                Target = msg.From,
                Action = "InfoResponse",
                Data = json.encode({
                    process = {
                        name = "Coordinator Process",
                        version = "1.0.0",
                        adpVersion = "1.0",
                        capabilities = {
                            "coordinateWorkflow",
                            "routeMessage", 
                            "checkProcessHealth",
                            "manageGameState",
                            "processDiscovery",
                            "workflowManagement",
                            "healthMonitoring",
                            "timeoutManagement",
                            "concurrentOperations",
                            "priorityQueuing",
                            "workflowPersistence",
                            "resourceMonitoring",
                            "capacityManagement",
                            "memoryOptimization",
                            "intelligentRouting",
                            "loadBalancing",
                            "performanceMonitoring",
                            "routingCache",
                            "failoverSupport",
                            "clientSideGameState",
                            "gameStateVersioning",
                            "gameStateValidation",
                            "gameStateCompression",
                            "gameStateSynchronization"
                        },
                        messageSchemas = {
                            RegisterProcess = {
                                required = {"Action", "ProcessName", "ProcessId"},
                                description = "Register a process for discovery and health monitoring"
                            },
                            CoordinateWorkflow = {
                                required = {"Action", "WorkflowType", "Steps"},
                                optional = {"Data"},
                                description = "Start a multi-step workflow across processes"
                            },
                            RouteMessage = {
                                required = {"Action", "TargetProcess"},
                                optional = {"Data"},
                                description = "Route a message to a specific process"
                            },
                            CheckProcessHealth = {
                                required = {"Action"},
                                optional = {"ProcessName"},
                                description = "Check health of specific process or all processes"
                            },
                            ManageGameState = {
                                required = {"Action", "Operation"},
                                optional = {"Data"},
                                description = "Coordinate game state operations across processes"
                            },
                            WorkflowResponse = {
                                required = {"Action", "WorkflowId", "StepNumber"},
                                optional = {"Data"},
                                description = "Response from a process participating in a workflow"
                            },
                            HealthResponse = {
                                required = {"Action"},
                                optional = {"ProcessName", "Status"},
                                description = "Health status response from a monitored process"
                            },
                            Maintenance = {
                                required = {"Action"},
                                description = "Trigger maintenance operations (cleanup, timeout checks)"
                            }
                        },
                        workflowPatterns = {
                            battleFlow = {
                                description = "Coordinate battle mechanics across battle-engine, status-effects-engine, and data processes",
                                steps = {"initBattle", "processMove", "applyEffects", "checkWin"}
                            },
                            evolutionFlow = {
                                description = "Handle pokemon evolution across evolution-engine and player state",
                                steps = {"checkEvolution", "updateStats", "saveState"}
                            },
                            captureFlow = {
                                description = "Coordinate pokemon capture across capture-engine and inventory",
                                steps = {"attemptCapture", "updateInventory", "updateTeam"}
                            },
                            stateSync = {
                                description = "Synchronize game state across all game processes",
                                steps = {"backupState", "syncPlayer", "syncInventory", "syncTeam"}
                            }
                        },
                        routingCapabilities = {
                            intelligentRouting = "Routes messages based on process availability and health",
                            loadBalancing = "Distributes requests across healthy processes",
                            failover = "Handles process failures with alternative routing",
                            discovery = "Automatic process discovery and registration"
                        }
                    },
                    handlers = {
                        "process-discovery",
                        "coordinate-workflow", 
                        "workflow-response",
                        "route-message",
                        "check-process-health",
                        "health-response",
                        "manage-game-state",
                        "maintenance",
                        "info"
                    },
                    state = {
                        registeredProcesses = ProcessRegistry,
                        activeWorkflows = ActiveWorkflows,
                        configuration = {
                            workflowTimeout = WorkflowTimeout,
                            healthCheckInterval = HealthCheckInterval
                        }
                    },
                    documentation = {
                        adpCompliance = "v1.0",
                        selfDocumenting = true,
                        architecture = "26-process stateless AO with async coordination",
                        purpose = "Multi-process workflow orchestration and health monitoring"
                    }
                }),
                Timestamp = getCurrentTimestamp()
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Info handler failed: " .. tostring(err), "Info")
        end
    end
)

-- Initialize coordinator
print("Coordinator Process v1.0.0 initialized")
print("ADP v1.0 compliant - ready for workflow orchestration")
print("Process ID: " .. ao.id)