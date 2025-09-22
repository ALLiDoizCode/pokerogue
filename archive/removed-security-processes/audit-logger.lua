-- Audit Logging & Player Attribution System
-- Comprehensive security event tracking with player attribution and correlation
-- ADP v1.0 Compliant Process

-- Audit log storage and configuration
local auditLogs = {}
local securityEvents = {}
local playerActions = {}

-- Log retention and management
local logConfig = {
    maxEntries = 10000, -- Maximum audit log entries to keep in memory
    retentionDays = 30, -- Days to retain logs
    compressionThreshold = 1000, -- Compress logs after this many entries
    securityEventTypes = {
        "AUTHENTICATION_FAILURE",
        "AUTHORIZATION_FAILURE", 
        "CHEAT_DETECTION",
        "VALIDATION_FAILURE",
        "SUSPICIOUS_ACTIVITY",
        "DATA_MANIPULATION",
        "SESSION_ANOMALY",
        "PATTERN_VIOLATION"
    }
}

-- Generate correlation IDs for tracking related events
local function generateCorrelationId()
    return "corr_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
end

-- Calculate differences between game states
local function calculateStateDiff(beforeState, afterState)
    local diff = {}
    
    if type(beforeState) ~= "table" or type(afterState) ~= "table" then
        return {error = "Invalid state objects for diff calculation"}
    end
    
    -- Track Pokemon changes
    if beforeState.party and afterState.party then
        for i, pokemon in ipairs(afterState.party) do
            local beforePokemon = beforeState.party[i]
            if beforePokemon then
                local pokemonDiff = {}
                
                if pokemon.level ~= beforePokemon.level then
                    pokemonDiff.level = {from = beforePokemon.level, to = pokemon.level}
                end
                
                if pokemon.exp ~= beforePokemon.exp then
                    pokemonDiff.exp = {from = beforePokemon.exp, to = pokemon.exp}
                end
                
                if pokemon.hp ~= beforePokemon.hp then
                    pokemonDiff.hp = {from = beforePokemon.hp, to = pokemon.hp}
                end
                
                if next(pokemonDiff) then
                    diff["pokemon_" .. i] = pokemonDiff
                end
            end
        end
    end
    
    -- Track inventory changes
    if beforeState.inventory and afterState.inventory then
        if beforeState.inventory.money ~= afterState.inventory.money then
            diff.money = {
                from = beforeState.inventory.money,
                to = afterState.inventory.money,
                change = (afterState.inventory.money or 0) - (beforeState.inventory.money or 0)
            }
        end
        
        -- Track item changes
        if beforeState.inventory.items and afterState.inventory.items then
            for itemId, newQuantity in pairs(afterState.inventory.items) do
                local oldQuantity = beforeState.inventory.items[itemId] or 0
                if newQuantity ~= oldQuantity then
                    if not diff.items then diff.items = {} end
                    diff.items[itemId] = {
                        from = oldQuantity,
                        to = newQuantity,
                        change = newQuantity - oldQuantity
                    }
                end
            end
        end
    end
    
    return diff
end

-- Create comprehensive audit log entry
local function createAuditLogEntry(eventType, walletAddress, operation, details)
    local entry = {
        id = "audit_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999)),
        timestamp = os.time(),
        eventType = eventType,
        walletAddress = walletAddress or "unknown",
        operation = operation,
        details = details or {},
        processId = ao.id,
        correlationId = details and details.correlationId or generateCorrelationId(),
        severity = details and details.severity or "INFO"
    }
    
    -- Add contextual information
    entry.context = {
        processVersion = "1.0.0",
        aoProtocol = "current",
        networkId = "ao_mainnet"
    }
    
    -- Add before/after state tracking for GameState changes
    if details and details.beforeState and details.afterState then
        entry.stateChange = {
            before = details.beforeState,
            after = details.afterState,
            diff = calculateStateDiff(details.beforeState, details.afterState)
        }
    end
    
    return entry
end


-- Log GameState modifications with full attribution
local function logGameStateModification(walletAddress, operation, beforeState, afterState, correlationId)
    local details = {
        beforeState = beforeState,
        afterState = afterState,
        correlationId = correlationId,
        severity = "INFO"
    }
    
    local auditEntry = createAuditLogEntry("GAMESTATE_MODIFICATION", walletAddress, operation, details)
    table.insert(auditLogs, auditEntry)
    
    -- Track player action statistics
    if not playerActions[walletAddress] then
        playerActions[walletAddress] = {
            totalActions = 0,
            operationCounts = {},
            firstSeen = os.time(),
            lastSeen = os.time()
        }
    end
    
    local playerStats = playerActions[walletAddress]
    playerStats.totalActions = playerStats.totalActions + 1
    playerStats.operationCounts[operation] = (playerStats.operationCounts[operation] or 0) + 1
    playerStats.lastSeen = os.time()
    
    return auditEntry
end

-- Generate security alerts for critical events
local function generateSecurityAlert(auditEntry)
    local alert = {
        id = "alert_" .. auditEntry.id,
        timestamp = os.time(),
        severity = auditEntry.severity,
        eventType = auditEntry.eventType,
        walletAddress = auditEntry.walletAddress,
        operation = auditEntry.operation,
        details = auditEntry.details,
        correlationId = auditEntry.correlationId,
        alertLevel = auditEntry.severity == "CRITICAL" and "IMMEDIATE" or "URGENT"
    }
    
    -- In a real implementation, this would trigger external alerting systems
    -- For now, we'll store it in the audit log with special marking
    alert.isAlert = true
    table.insert(auditLogs, alert)
    
    return alert
end

-- Log security events with high priority
local function logSecurityEvent(eventType, walletAddress, operation, severity, details)
    local securityDetails = details or {}
    securityDetails.severity = severity or "MEDIUM"
    securityDetails.correlationId = securityDetails.correlationId or generateCorrelationId()
    securityDetails.alertGenerated = true
    
    local auditEntry = createAuditLogEntry(eventType, walletAddress, operation, securityDetails)
    table.insert(auditLogs, auditEntry)
    table.insert(securityEvents, auditEntry)
    
    -- Generate alert for high-severity events
    if severity == "HIGH" or severity == "CRITICAL" then
        generateSecurityAlert(auditEntry)
    end
    
    return auditEntry
end

-- Track operation timelines and patterns
local function logOperationTimeline(walletAddress, operation, startTime, endTime, success, details)
    local timelineEntry = {
        walletAddress = walletAddress,
        operation = operation,
        startTime = startTime,
        endTime = endTime,
        duration = endTime - startTime,
        success = success,
        timestamp = os.time(),
        details = details or {}
    }
    
    local auditEntry = createAuditLogEntry("OPERATION_TIMELINE", walletAddress, operation, {
        timeline = timelineEntry,
        correlationId = details and details.correlationId
    })
    
    table.insert(auditLogs, auditEntry)
    return auditEntry
end

-- Query audit logs with advanced filtering
local function queryAuditLogs(criteria)
    local results = {}
    local filters = criteria or {}
    
    for _, entry in ipairs(auditLogs) do
        local matches = true
        
        -- Filter by wallet address
        if filters.walletAddress and entry.walletAddress ~= filters.walletAddress then
            matches = false
        end
        
        -- Filter by event type
        if filters.eventType and entry.eventType ~= filters.eventType then
            matches = false
        end
        
        -- Filter by operation
        if filters.operation and entry.operation ~= filters.operation then
            matches = false
        end
        
        -- Filter by time range
        if filters.startTime and entry.timestamp < filters.startTime then
            matches = false
        end
        
        if filters.endTime and entry.timestamp > filters.endTime then
            matches = false
        end
        
        -- Filter by severity
        if filters.severity and entry.severity ~= filters.severity then
            matches = false
        end
        
        -- Filter by correlation ID
        if filters.correlationId and entry.correlationId ~= filters.correlationId then
            matches = false
        end
        
        if matches then
            table.insert(results, entry)
        end
    end
    
    -- Sort by timestamp (newest first)
    table.sort(results, function(a, b) return a.timestamp > b.timestamp end)
    
    -- Limit results if specified
    if filters.limit and #results > filters.limit then
        local limited = {}
        for i = 1, filters.limit do
            table.insert(limited, results[i])
        end
        results = limited
    end
    
    return results
end

-- Generate investigation reports
local function generateInvestigationReport(walletAddress, timeRange)
    local startTime = timeRange and timeRange.start or (os.time() - 86400) -- Default: last 24 hours
    local endTime = timeRange and timeRange["end"] or os.time()
    
    local report = {
        walletAddress = walletAddress,
        timeRange = {start = startTime, ["end"] = endTime},
        timestamp = os.time(),
        summary = {
            totalEvents = 0,
            securityEvents = 0,
            operations = {},
            timeline = {}
        },
        findings = {},
        recommendations = {}
    }
    
    -- Query logs for this wallet and time range
    local logs = queryAuditLogs({
        walletAddress = walletAddress,
        startTime = startTime,
        endTime = endTime
    })
    
    report.summary.totalEvents = #logs
    
    -- Analyze events
    local operationCounts = {}
    local securityEventCount = 0
    
    for _, entry in ipairs(logs) do
        -- Count operations
        operationCounts[entry.operation] = (operationCounts[entry.operation] or 0) + 1
        
        -- Count security events
        for _, securityType in ipairs(logConfig.securityEventTypes) do
            if entry.eventType == securityType then
                securityEventCount = securityEventCount + 1
                break
            end
        end
        
        -- Add to timeline
        table.insert(report.summary.timeline, {
            timestamp = entry.timestamp,
            eventType = entry.eventType,
            operation = entry.operation,
            severity = entry.severity
        })
    end
    
    report.summary.securityEvents = securityEventCount
    report.summary.operations = operationCounts
    
    -- Generate findings
    if securityEventCount > 0 then
        table.insert(report.findings, {
            type = "SECURITY_EVENTS_DETECTED",
            count = securityEventCount,
            severity = securityEventCount > 5 and "HIGH" or "MEDIUM"
        })
    end
    
    -- Check for suspicious patterns
    local totalOperations = 0
    for _, count in pairs(operationCounts) do
        totalOperations = totalOperations + count
    end
    
    if totalOperations > 1000 then
        table.insert(report.findings, {
            type = "HIGH_ACTIVITY_VOLUME",
            count = totalOperations,
            severity = "MEDIUM"
        })
    end
    
    -- Generate recommendations
    if securityEventCount > 0 then
        table.insert(report.recommendations, "Review security events and implement additional monitoring")
    end
    
    if totalOperations > 1000 then
        table.insert(report.recommendations, "Consider implementing operation throttling for this user")
    end
    
    return report
end

-- Log retention and cleanup
local function performLogRetention()
    local cutoffTime = os.time() - (logConfig.retentionDays * 86400)
    local retained = {}
    local deleted = 0
    
    for _, entry in ipairs(auditLogs) do
        if entry.timestamp > cutoffTime then
            table.insert(retained, entry)
        else
            deleted = deleted + 1
        end
    end
    
    auditLogs = retained
    
    -- Clean up security events
    local retainedSecurity = {}
    for _, event in ipairs(securityEvents) do
        if event.timestamp > cutoffTime then
            table.insert(retainedSecurity, event)
        end
    end
    securityEvents = retainedSecurity
    
    return {
        deletedEntries = deleted,
        retainedEntries = #retained,
        cutoffTime = cutoffTime
    }
end

-- AO Message Handlers
Handlers.add("log-gamestate-modification",
    Handlers.utils.hasMatchingTag("Action", "LogGameStateModification"),
    function(msg)
        local success, data = pcall(json.decode, msg.Data or "{}")
        
        if not success then
            ao.send({
                Target = msg.From,
                Action = "AuditLogError",
                Error = "Invalid JSON data",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        local auditEntry = logGameStateModification(
            msg.From,
            data.operation or "Unknown",
            data.beforeState,
            data.afterState,
            data.correlationId
        )
        
        ao.send({
            Target = msg.From,
            Action = "GameStateModificationLogged",
            Data = json.encode({
                auditId = auditEntry.id,
                correlationId = auditEntry.correlationId,
                timestamp = auditEntry.timestamp
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("log-security-event",
    Handlers.utils.hasMatchingTag("Action", "LogSecurityEvent"),
    function(msg)
        local success, data = pcall(json.decode, msg.Data or "{}")
        
        if not success then
            ao.send({
                Target = msg.From,
                Action = "AuditLogError",
                Error = "Invalid JSON data",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        local auditEntry = logSecurityEvent(
            data.eventType or "UNKNOWN_SECURITY_EVENT",
            msg.From,
            data.operation or "Unknown",
            data.severity or "MEDIUM",
            data.details
        )
        
        ao.send({
            Target = msg.From,
            Action = "SecurityEventLogged",
            Data = json.encode({
                auditId = auditEntry.id,
                correlationId = auditEntry.correlationId,
                severity = auditEntry.severity,
                alertGenerated = auditEntry.details.alertGenerated
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("query-audit-logs",
    Handlers.utils.hasMatchingTag("Action", "QueryAuditLogs"),
    function(msg)
        local success, criteria = pcall(json.decode, msg.Data or "{}")
        
        if not success then
            criteria = {}
        end
        
        local results = queryAuditLogs(criteria)
        
        ao.send({
            Target = msg.From,
            Action = "AuditLogResults",
            Data = json.encode({
                results = results,
                totalFound = #results,
                criteria = criteria,
                timestamp = os.time()
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("generate-investigation-report",
    Handlers.utils.hasMatchingTag("Action", "GenerateInvestigationReport"),
    function(msg)
        local success, data = pcall(json.decode, msg.Data or "{}")
        
        if not success then
            ao.send({
                Target = msg.From,
                Action = "InvestigationError",
                Error = "Invalid JSON data",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        local walletAddress = data.walletAddress or msg.From
        local report = generateInvestigationReport(walletAddress, data.timeRange)
        
        ao.send({
            Target = msg.From,
            Action = "InvestigationReport",
            Data = json.encode(report),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("perform-log-retention",
    Handlers.utils.hasMatchingTag("Action", "PerformLogRetention"),
    function(msg)
        local retentionResult = performLogRetention()
        
        ao.send({
            Target = msg.From,
            Action = "LogRetentionComplete",
            Data = json.encode(retentionResult),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "HealthStatus",
            Data = json.encode({
                status = "healthy",
                service = "Audit Logger",
                version = "1.0.0",
                capabilities = {
                    "gamestate-modification-logging",
                    "security-event-logging",
                    "player-attribution",
                    "correlation-tracking",
                    "investigation-reports",
                    "log-retention"
                },
                statistics = {
                    totalAuditLogs = #auditLogs,
                    securityEvents = #securityEvents,
                    trackedPlayers = 0 -- Count unique players
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- ADP v1.0 Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode({
                process = {
                    name = "Audit Logger",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "logGameStateModification",
                        "logSecurityEvent",
                        "queryAuditLogs",
                        "generateInvestigationReport",
                        "performLogRetention"
                    },
                    messageSchemas = {
                        LogGameStateModification = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                operation = "string",
                                beforeState = "object (optional)",
                                afterState = "object (optional)",
                                correlationId = "string (optional)"
                            }
                        },
                        LogSecurityEvent = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                eventType = "string",
                                operation = "string (optional)",
                                severity = "string (optional)",
                                details = "object (optional)"
                            }
                        },
                        QueryAuditLogs = {
                            required = {"Action"},
                            dataSchema = {
                                walletAddress = "string (optional)",
                                eventType = "string (optional)",
                                startTime = "number (optional)",
                                endTime = "number (optional)",
                                limit = "number (optional)"
                            }
                        }
                    }
                },
                handlers = {"log-gamestate-modification", "log-security-event", "query-audit-logs", "generate-investigation-report", "perform-log-retention", "health-check", "info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    purpose = "Comprehensive audit logging with player attribution and security event tracking",
                    auditFeatures = {
                        "gameStateModificationTracking",
                        "securityEventLogging",
                        "playerAttribution",
                        "correlationTracking",
                        "timelineAnalysis",
                        "investigationReports",
                        "logRetention",
                        "securityAlerts"
                    }
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export functions for testing
_G.AuditLogger = {
    logGameStateModification = logGameStateModification,
    logSecurityEvent = logSecurityEvent,
    queryAuditLogs = queryAuditLogs,
    generateInvestigationReport = generateInvestigationReport,
    calculateStateDiff = calculateStateDiff,
    createAuditLogEntry = createAuditLogEntry,
    generateCorrelationId = generateCorrelationId,
    performLogRetention = performLogRetention,
    auditLogs = auditLogs,
    securityEvents = securityEvents,
    playerActions = playerActions,
    logConfig = logConfig
}