#!/usr/bin/env lua

--[[
Process Emulator for HyperBeam Testing Framework
Provides coroutine-based process emulation with message routing and state management
Version: 1.0.0
]]

local ProcessEmulator = {}

-- Process registry and state
local ProcessRegistry = {
    processes = {},
    messageQueues = {},
    routingTable = {},
    messageHistory = {},
    scheduler = {
        running = false,
        maxIterations = 1000,
        currentIteration = 0
    }
}

-- Message routing configuration
local RoutingConfig = {
    defaultTimeout = 5000, -- 5 seconds
    maxMessageQueueSize = 1000,
    enableRouting = true,
    debugMode = false
}

-- Process creation and management
function ProcessEmulator.spawn(processId, handlers, initialState, config)
    config = config or {}
    processId = processId or "proc-" .. math.random(100000, 999999)
    
    if ProcessRegistry.processes[processId] then
        error("Process with ID " .. processId .. " already exists", 2)
    end
    
    local process = {
        id = processId,
        handlers = handlers or {},
        state = initialState or {},
        messageQueue = {},
        running = true,
        created = os.clock() * 1000,
        lastActivity = os.clock() * 1000,
        messageCount = 0,
        errorCount = 0,
        executionTime = 0,
        config = config
    }
    
    -- Create process coroutine
    process.coroutine = coroutine.create(function()
        while process.running do
            local startTime = os.clock()
            
            -- Wait for messages or yield if queue is empty
            if #process.messageQueue == 0 then
                coroutine.yield("waiting")
            else
                -- Process next message
                local msg = table.remove(process.messageQueue, 1)
                process.messageCount = process.messageCount + 1
                process.lastActivity = os.clock() * 1000
                
                -- Add to message history
                table.insert(ProcessRegistry.messageHistory, {
                    processId = processId,
                    message = msg,
                    timestamp = os.clock() * 1000,
                    direction = "incoming"
                })
                
                -- Find matching handler
                local handled = false
                local handlerResult = nil
                
                for name, handler in pairs(process.handlers) do
                    if handler.matcher and handler.matcher(msg) then
                        -- Execute handler in protected call
                        local success, result = pcall(handler.handler, msg)
                        
                        if success then
                            handlerResult = result
                            handled = true
                            
                            if RoutingConfig.debugMode then
                                print(string.format("Process %s: Handler %s processed message %s",
                                    processId, name, msg.Action))
                            end
                            
                            -- If handler returns a response, route it
                            if result and type(result) == "table" and result.Target then
                                ProcessEmulator.routeMessage(result)
                            end
                            
                            break
                        else
                            process.errorCount = process.errorCount + 1
                            
                            if RoutingConfig.debugMode then
                                print(string.format("Process %s: Handler %s failed: %s",
                                    processId, name, tostring(result)))
                            end
                            
                            coroutine.yield("error", result)
                        end
                    end
                end
                
                if not handled then
                    if RoutingConfig.debugMode then
                        print(string.format("Process %s: No handler for message %s",
                            processId, msg.Action))
                    end
                    coroutine.yield("no-handler", msg)
                else
                    coroutine.yield("handled", handlerResult)
                end
            end
            
            -- Track execution time
            process.executionTime = process.executionTime + ((os.clock() - startTime) * 1000)
        end
        
        coroutine.yield("terminated")
    end)
    
    -- Register process
    ProcessRegistry.processes[processId] = process
    ProcessRegistry.messageQueues[processId] = process.messageQueue
    
    if RoutingConfig.debugMode then
        print("Process spawned: " .. processId)
    end
    
    return process
end

-- Message routing system
function ProcessEmulator.routeMessage(message)
    if not RoutingConfig.enableRouting then
        return {success = false, error = "Routing disabled"}
    end
    
    local targetId = message.Target
    if not targetId then
        return {success = false, error = "Message has no target"}
    end
    
    local targetProcess = ProcessRegistry.processes[targetId]
    if not targetProcess then
        -- Try routing table lookup
        local routedTarget = ProcessRegistry.routingTable[targetId]
        if routedTarget then
            targetProcess = ProcessRegistry.processes[routedTarget]
        end
    end
    
    if not targetProcess then
        return {success = false, error = "Target process not found: " .. targetId}
    end
    
    -- Check message queue size limit
    if #targetProcess.messageQueue >= RoutingConfig.maxMessageQueueSize then
        return {success = false, error = "Target process message queue full"}
    end
    
    -- Add message to target queue
    table.insert(targetProcess.messageQueue, message)
    
    -- Add to message history
    table.insert(ProcessRegistry.messageHistory, {
        processId = targetId,
        message = message,
        timestamp = os.clock() * 1000,
        direction = "outgoing",
        route = message.From .. " -> " .. targetId
    })
    
    if RoutingConfig.debugMode then
        print(string.format("Message routed: %s -> %s (Action: %s)",
            message.From or "unknown", targetId, message.Action))
    end
    
    return {
        success = true,
        targetId = targetId,
        queueSize = #targetProcess.messageQueue
    }
end

-- Send message to specific process
function ProcessEmulator.send(targetId, message)
    return ProcessEmulator.routeMessage(message)
end

-- Broadcast message to multiple processes
function ProcessEmulator.broadcast(message, targetList)
    targetList = targetList or {}
    local results = {}
    
    for _, targetId in ipairs(targetList) do
        local msgCopy = {}
        for k, v in pairs(message) do
            msgCopy[k] = v
        end
        msgCopy.Target = targetId
        
        results[targetId] = ProcessEmulator.routeMessage(msgCopy)
    end
    
    return results
end

-- Process scheduler
function ProcessEmulator.runScheduler(maxIterations, timeoutMs)
    maxIterations = maxIterations or RoutingConfig.maxIterations
    timeoutMs = timeoutMs or RoutingConfig.defaultTimeout
    
    ProcessRegistry.scheduler.running = true
    ProcessRegistry.scheduler.currentIteration = 0
    ProcessRegistry.scheduler.maxIterations = maxIterations
    
    local startTime = os.clock() * 1000
    local processedMessages = 0
    local completedProcesses = 0
    
    while ProcessRegistry.scheduler.currentIteration < maxIterations and
          ProcessRegistry.scheduler.running do
        
        -- Check timeout
        if (os.clock() * 1000) - startTime > timeoutMs then
            break
        end
        
        local anyProcessActive = false
        
        -- Process all active processes
        for processId, process in pairs(ProcessRegistry.processes) do
            if process.running and coroutine.status(process.coroutine) == "suspended" then
                if #process.messageQueue > 0 then
                    anyProcessActive = true
                    local status, result, data = coroutine.resume(process.coroutine)
                    
                    if not status then
                        process.running = false
                        process.errorCount = process.errorCount + 1
                        
                        if RoutingConfig.debugMode then
                            print(string.format("Process %s crashed: %s", processId, tostring(result)))
                        end
                    elseif result == "handled" then
                        processedMessages = processedMessages + 1
                    elseif result == "terminated" then
                        process.running = false
                        completedProcesses = completedProcesses + 1
                    end
                end
            end
        end
        
        -- If no processes are active, break
        if not anyProcessActive then
            break
        end
        
        ProcessRegistry.scheduler.currentIteration = ProcessRegistry.scheduler.currentIteration + 1
    end
    
    ProcessRegistry.scheduler.running = false
    
    local totalTime = (os.clock() * 1000) - startTime
    
    return {
        iterations = ProcessRegistry.scheduler.currentIteration,
        processedMessages = processedMessages,
        completedProcesses = completedProcesses,
        totalTime = totalTime,
        timedOut = totalTime >= timeoutMs,
        success = ProcessRegistry.scheduler.currentIteration < maxIterations
    }
end

-- Process management functions
function ProcessEmulator.stopProcess(processId)
    local process = ProcessRegistry.processes[processId]
    if process then
        process.running = false
        return true
    end
    return false
end

function ProcessEmulator.getProcess(processId)
    return ProcessRegistry.processes[processId]
end

function ProcessEmulator.getAllProcesses()
    return ProcessRegistry.processes
end

function ProcessEmulator.getProcessCount()
    local count = 0
    for _ in pairs(ProcessRegistry.processes) do
        count = count + 1
    end
    return count
end

function ProcessEmulator.getActiveProcessCount()
    local count = 0
    for _, process in pairs(ProcessRegistry.processes) do
        if process.running then
            count = count + 1
        end
    end
    return count
end

-- Message queue management
function ProcessEmulator.getMessageQueue(processId)
    return ProcessRegistry.messageQueues[processId] or {}
end

function ProcessEmulator.getQueueSize(processId)
    local queue = ProcessRegistry.messageQueues[processId]
    return queue and #queue or 0
end

function ProcessEmulator.clearMessageQueue(processId)
    local queue = ProcessRegistry.messageQueues[processId]
    if queue then
        -- Clear the queue
        for i = #queue, 1, -1 do
            queue[i] = nil
        end
        return true
    end
    return false
end

function ProcessEmulator.getTotalQueueSize()
    local total = 0
    for _, queue in pairs(ProcessRegistry.messageQueues) do
        total = total + #queue
    end
    return total
end

-- Routing table management
function ProcessEmulator.addRoute(alias, targetProcessId)
    ProcessRegistry.routingTable[alias] = targetProcessId
end

function ProcessEmulator.removeRoute(alias)
    ProcessRegistry.routingTable[alias] = nil
end

function ProcessEmulator.getRoutingTable()
    return ProcessRegistry.routingTable
end

-- Message history and debugging
function ProcessEmulator.getMessageHistory(processId)
    if processId then
        local history = {}
        for _, entry in ipairs(ProcessRegistry.messageHistory) do
            if entry.processId == processId then
                table.insert(history, entry)
            end
        end
        return history
    else
        return ProcessRegistry.messageHistory
    end
end

function ProcessEmulator.clearMessageHistory()
    ProcessRegistry.messageHistory = {}
end

function ProcessEmulator.getMessageCount(processId)
    if processId then
        local process = ProcessRegistry.processes[processId]
        return process and process.messageCount or 0
    else
        local total = 0
        for _, process in pairs(ProcessRegistry.processes) do
            total = total + process.messageCount
        end
        return total
    end
end

-- Process statistics
function ProcessEmulator.getProcessStats(processId)
    local process = ProcessRegistry.processes[processId]
    if not process then
        return nil
    end
    
    return {
        id = process.id,
        running = process.running,
        created = process.created,
        lastActivity = process.lastActivity,
        messageCount = process.messageCount,
        errorCount = process.errorCount,
        executionTime = process.executionTime,
        queueSize = #process.messageQueue,
        handlerCount = 0 -- Count handlers
    }
end

function ProcessEmulator.getAllStats()
    local stats = {}
    for processId, _ in pairs(ProcessRegistry.processes) do
        stats[processId] = ProcessEmulator.getProcessStats(processId)
    end
    return stats
end

-- Configuration functions
function ProcessEmulator.setConfig(key, value)
    if RoutingConfig[key] ~= nil then
        RoutingConfig[key] = value
        return true
    end
    return false
end

function ProcessEmulator.getConfig()
    return RoutingConfig
end

function ProcessEmulator.enableDebug()
    RoutingConfig.debugMode = true
end

function ProcessEmulator.disableDebug()
    RoutingConfig.debugMode = false
end

-- Cleanup functions
function ProcessEmulator.reset()
    -- Stop all processes
    for processId, process in pairs(ProcessRegistry.processes) do
        process.running = false
    end
    
    -- Clear all state
    ProcessRegistry.processes = {}
    ProcessRegistry.messageQueues = {}
    ProcessRegistry.routingTable = {}
    ProcessRegistry.messageHistory = {}
    ProcessRegistry.scheduler.running = false
    ProcessRegistry.scheduler.currentIteration = 0
end

function ProcessEmulator.cleanup()
    ProcessEmulator.reset()
end

-- Testing helpers
function ProcessEmulator.waitForProcesses(maxWaitMs)
    maxWaitMs = maxWaitMs or 1000
    local startTime = os.clock() * 1000
    
    while (os.clock() * 1000) - startTime < maxWaitMs do
        local hasActiveMessages = false
        for _, queue in pairs(ProcessRegistry.messageQueues) do
            if #queue > 0 then
                hasActiveMessages = true
                break
            end
        end
        
        if not hasActiveMessages then
            return true
        end
        
        -- Brief sleep simulation
        local sleepStart = os.clock()
        while (os.clock() - sleepStart) < 0.01 do end -- 10ms
    end
    
    return false
end

function ProcessEmulator.stepScheduler()
    return ProcessEmulator.runScheduler(1, 100) -- Single iteration, 100ms timeout
end

return ProcessEmulator