-- Coordinator Process: ADP v1.0 Compliant Multi-Process Workflow Orchestrator
-- Version: 1.0.0
-- Purpose: Orchestrates workflows across 26-process stateless AO architecture
-- Architecture: Stateless coordination with async workflow management

-- Process Registry and Health State
local ProcessRegistry = {
    dataProcesses = {
        ["pokemon-species-db"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["moves-database"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["items-database"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["abilities-database"] = { id = nil, status = "unknown", lastHealth = 0 }
    },
    logicProcesses = {
        ["battle-engine"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["evolution-engine"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["capture-engine"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["status-effects-engine"] = { id = nil, status = "unknown", lastHealth = 0 }
    },
    gameProcesses = {
        ["player-state"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["inventory-manager"] = { id = nil, status = "unknown", lastHealth = 0 },
        ["team-manager"] = { id = nil, status = "unknown", lastHealth = 0 }
    }
}

-- Workflow State Management
local ActiveWorkflows = {}
local WorkflowTimeout = 30000 -- 30 seconds
local HealthCheckInterval = 10000 -- 10 seconds

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

-- Process Discovery Functions
local function discoverProcess(processName, processId)
    local allProcesses = getAllProcesses()
    if allProcesses[processName] then
        allProcesses[processName].id = processId
        allProcesses[processName].status = "discovered"
        allProcesses[processName].lastHealth = getCurrentTimestamp()
        return true
    end
    return false
end

local function getProcessId(processName)
    local allProcesses = getAllProcesses()
    if allProcesses[processName] and allProcesses[processName].id then
        return allProcesses[processName].id
    end
    return nil
end

-- Workflow Management Functions
local function createWorkflow(workflowType, steps, requester, data)
    local workflowId = generateWorkflowId()
    local workflow = {
        id = workflowId,
        type = workflowType,
        steps = steps,
        currentStep = 1,
        requester = requester,
        data = data or {},
        status = "active",
        created = getCurrentTimestamp(),
        lastActivity = getCurrentTimestamp(),
        responses = {},
        timeouts = {}
    }
    
    ActiveWorkflows[workflowId] = workflow
    return workflowId
end

local function updateWorkflowStep(workflowId, stepResponse)
    local workflow = ActiveWorkflows[workflowId]
    if not workflow then
        return false, "Workflow not found"
    end
    
    workflow.responses[workflow.currentStep] = stepResponse
    workflow.lastActivity = getCurrentTimestamp()
    
    if workflow.currentStep >= #workflow.steps then
        workflow.status = "completed"
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
    
    -- Set timeout for this step
    workflow.timeouts[workflow.currentStep] = getCurrentTimestamp() + WorkflowTimeout
    return true, "Step executed"
end

-- Message Routing Functions
local function routeMessage(msg)
    local targetProcess = msg.TargetProcess
    if not targetProcess then
        return false, "No target process specified"
    end
    
    local processId = getProcessId(targetProcess)
    if not processId then
        return false, "Target process not available: " .. targetProcess
    end
    
    local success, err = pcall(function()
        ao.send({
            Target = processId,
            Action = msg.Action or "ProcessMessage",
            Data = msg.Data,
            OriginalSender = msg.From,
            RoutedBy = ao.id,
            Timestamp = getCurrentTimestamp()
        })
    end)
    
    if not success then
        return false, "Failed to route message: " .. tostring(err)
    end
    
    return true, "Message routed successfully"
end

-- Health Monitoring Functions
local function checkProcessHealth(processName)
    local processId = getProcessId(processName)
    if not processId then
        return false, "Process not discovered"
    end
    
    local success, err = pcall(function()
        ao.send({
            Target = processId,
            Action = "HealthCheck",
            RequestId = string.format("health_%d_%s", getCurrentTimestamp(), processName),
            Timestamp = getCurrentTimestamp(),
            Requester = ao.id
        })
    end)
    
    if not success then
        return false, "Failed to send health check: " .. tostring(err)
    end
    
    return true, "Health check sent"
end

local function checkAllProcessesHealth()
    local healthReport = {
        timestamp = getCurrentTimestamp(),
        processes = {},
        summary = { total = 0, healthy = 0, unhealthy = 0, unknown = 0 }
    }
    
    local allProcesses = getAllProcesses()
    for name, process in pairs(allProcesses) do
        healthReport.summary.total = healthReport.summary.total + 1
        
        if process.status == "healthy" then
            healthReport.summary.healthy = healthReport.summary.healthy + 1
        elseif process.status == "unhealthy" then
            healthReport.summary.unhealthy = healthReport.summary.unhealthy + 1
        else
            healthReport.summary.unknown = healthReport.summary.unknown + 1
        end
        
        healthReport.processes[name] = {
            status = process.status,
            lastHealth = process.lastHealth,
            id = process.id
        }
        
        -- Send health check if process is discovered
        if process.id then
            checkProcessHealth(name)
        end
    end
    
    return healthReport
end

-- Workflow Timeout Management
local function checkWorkflowTimeouts()
    local currentTime = getCurrentTimestamp()
    local timedOutWorkflows = {}
    
    for workflowId, workflow in pairs(ActiveWorkflows) do
        if workflow.status == "active" then
            local stepTimeout = workflow.timeouts[workflow.currentStep]
            if stepTimeout and currentTime > stepTimeout then
                workflow.status = "timeout"
                table.insert(timedOutWorkflows, workflowId)
                
                sendErrorResponse(
                    workflow.requester,
                    workflowId,
                    "Workflow step timeout",
                    "coordinateWorkflow"
                )
            end
        end
    end
    
    return timedOutWorkflows
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
            
            local workflowId = createWorkflow(msg.WorkflowType, steps, msg.From, data)
            
            -- Execute first step
            local stepSuccess, stepErr = executeWorkflowStep(workflowId)
            if not stepSuccess then
                ActiveWorkflows[workflowId].status = "failed"
                sendErrorResponse(msg.From, workflowId, stepErr, "CoordinateWorkflow")
                return
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

-- Health Response Handler
Handlers.add("health-response",
    Handlers.utils.hasMatchingTag("Action", "HealthResponse"),
    function(msg)
        local success, err = pcall(function()
            local processName = msg.ProcessName
            if not processName then
                return -- Ignore malformed health responses
            end
            
            local allProcesses = getAllProcesses()
            if allProcesses[processName] then
                allProcesses[processName].status = msg.Status or "healthy"
                allProcesses[processName].lastHealth = getCurrentTimestamp()
            end
        end)
        
        if not success then
            -- Log error but don't send response to avoid loops
            print("Health response processing error: " .. tostring(err))
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

-- Maintenance Handler (cleanup timeouts, etc.)
Handlers.add("maintenance",
    Handlers.utils.hasMatchingTag("Action", "Maintenance"),
    function(msg)
        local success, err = pcall(function()
            local timedOutWorkflows = checkWorkflowTimeouts()
            local currentTime = getCurrentTimestamp()
            
            -- Clean up completed workflows older than 1 hour
            local cleanupThreshold = currentTime - 3600000
            local cleaned = 0
            
            for workflowId, workflow in pairs(ActiveWorkflows) do
                if (workflow.status == "completed" or workflow.status == "failed" or workflow.status == "timeout") 
                   and workflow.lastActivity < cleanupThreshold then
                    ActiveWorkflows[workflowId] = nil
                    cleaned = cleaned + 1
                end
            end
            
            ao.send({
                Target = msg.From,
                Action = "MaintenanceComplete",
                TimedOutWorkflows = #timedOutWorkflows,
                CleanedWorkflows = cleaned,
                ActiveWorkflows = 0,
                Timestamp = currentTime
            })
            
            -- Count active workflows
            local activeCount = 0
            for _, workflow in pairs(ActiveWorkflows) do
                if workflow.status == "active" then
                    activeCount = activeCount + 1
                end
            end
            
            -- Update the response with actual active count
            ao.send({
                Target = msg.From,
                Action = "MaintenanceComplete",
                TimedOutWorkflows = #timedOutWorkflows,
                CleanedWorkflows = cleaned,
                ActiveWorkflows = activeCount,
                Timestamp = currentTime
            })
        end)
        
        if not success then
            sendErrorResponse(msg.From, nil, "Maintenance failed: " .. tostring(err), "Maintenance")
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
                            "timeoutManagement"
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