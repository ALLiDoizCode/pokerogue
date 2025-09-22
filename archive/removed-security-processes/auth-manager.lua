-- AO Message Authentication & Authorization Manager
-- Player data ownership validation and role-based authorization
-- ADP v1.0 Compliant Process
-- 
-- NOTE: AO protocol handles signature verification and message authentication at the protocol level
-- This process focuses on application-level authorization and data ownership validation

-- Session management for multi-step operations
local activeSessions = {}
local sessionTimeout = 3600 -- 1 hour in seconds

local function generateSessionId()
    return "session_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

local function createSession(walletAddress, permissions)
    local sessionId = generateSessionId()
    local session = {
        id = sessionId,
        walletAddress = walletAddress,
        permissions = permissions or {},
        createdAt = os.time(),
        lastActivity = os.time(),
        isActive = true
    }
    
    activeSessions[sessionId] = session
    return session
end

local function getSession(sessionId)
    local session = activeSessions[sessionId]
    if not session then
        return nil, "Session not found"
    end
    
    -- Check if session has expired
    local currentTime = os.time()
    if currentTime - session.lastActivity > sessionTimeout then
        activeSessions[sessionId] = nil
        return nil, "Session expired"
    end
    
    -- Update last activity
    session.lastActivity = currentTime
    return session, nil
end

local function invalidateSession(sessionId)
    if activeSessions[sessionId] then
        activeSessions[sessionId].isActive = false
        activeSessions[sessionId] = nil
        return true
    end
    return false
end

-- Player data ownership validation
local playerDataOwnership = {}

local function registerPlayerOwnership(walletAddress, gameDataId)
    if not playerDataOwnership[walletAddress] then
        playerDataOwnership[walletAddress] = {}
    end
    
    playerDataOwnership[walletAddress][gameDataId] = {
        registeredAt = os.time(),
        lastAccessed = os.time()
    }
    
    return true
end

local function validateOwnership(walletAddress, gameDataId)
    if not playerDataOwnership[walletAddress] then
        return false, "No data ownership registered for wallet"
    end
    
    if not playerDataOwnership[walletAddress][gameDataId] then
        return false, "Wallet does not own specified game data"
    end
    
    -- Update last accessed time
    playerDataOwnership[walletAddress][gameDataId].lastAccessed = os.time()
    return true, nil
end

-- Operation authorization system
local operationPermissions = {
    -- Player operations
    ["UpdateGameState"] = {"player", "admin"},
    ["SaveProgress"] = {"player", "admin"},
    ["LoadProgress"] = {"player", "admin"},
    ["BattleAction"] = {"player", "admin"},
    
    -- Battle operations
    ["InitiateBattle"] = {"player", "admin"},
    ["ResolveBattle"] = {"player", "admin"},
    ["EndBattle"] = {"player", "admin"},
    
    -- Admin operations
    ["AdminReset"] = {"admin"},
    ["SystemMaintenance"] = {"admin"},
    ["ViewAllData"] = {"admin"},
    ["ModifyAnyData"] = {"admin"},
    
    -- Public operations
    ["GetLeaderboard"] = {"public", "player", "admin"},
    ["GetGameInfo"] = {"public", "player", "admin"},
    ["HealthCheck"] = {"public", "player", "admin"}
}

local function getUserRole(walletAddress)
    -- In a real implementation, this would check against a admin list or role database
    -- For now, we'll use a simple pattern
    if string.find(walletAddress, "admin") then
        return "admin"
    else
        return "player"
    end
end

local function checkOperationPermission(walletAddress, operation)
    local userRole = getUserRole(walletAddress)
    local allowedRoles = operationPermissions[operation]
    
    if not allowedRoles then
        return false, "Unknown operation: " .. operation
    end
    
    for _, role in ipairs(allowedRoles) do
        if role == userRole or role == "public" then
            return true, nil
        end
    end
    
    return false, "Insufficient permissions for operation: " .. operation
end

-- Authentication workflow leveraging AO's built-in message authentication
local function authenticateMessage(msg)
    local authResult = {
        isAuthenticated = false,
        walletAddress = nil,
        sessionId = nil,
        permissions = {},
        errors = {}
    }
    
    -- AO protocol guarantees msg.From is authenticated wallet address
    local walletAddress = msg.From
    
    if not walletAddress then
        table.insert(authResult.errors, "No sender address in AO message")
        return authResult
    end
    
    -- Validate wallet address format (AO addresses are typically 43 characters)
    if type(walletAddress) ~= "string" or string.len(walletAddress) < 20 then
        table.insert(authResult.errors, "Invalid wallet address format")
        return authResult
    end
    
    -- Extract session data if provided
    local authData = nil
    if msg.Data then
        local success, data = pcall(json.decode, msg.Data or "{}")
        if success then
            authData = data
        end
    end
    
    -- Check for existing session
    if authData and authData.sessionId then
        local session, err = getSession(authData.sessionId)
        if session and session.walletAddress == walletAddress then
            authResult.isAuthenticated = true
            authResult.walletAddress = walletAddress
            authResult.sessionId = session.id
            authResult.permissions = session.permissions
            return authResult
        elseif err then
            table.insert(authResult.errors, "Session validation failed: " .. err)
        end
    end
    
    -- Create new session for authenticated AO message
    local permissions = {getUserRole(walletAddress)}
    local session = createSession(walletAddress, permissions)
    
    authResult.isAuthenticated = true
    authResult.walletAddress = walletAddress
    authResult.sessionId = session.id
    authResult.permissions = permissions
    
    return authResult
end

-- Authorization validation
local function authorizeOperation(authResult, operation, gameDataId)
    if not authResult.isAuthenticated then
        return false, "Not authenticated"
    end
    
    -- Check operation permissions
    local hasPermission, permErr = checkOperationPermission(authResult.walletAddress, operation)
    if not hasPermission then
        return false, permErr
    end
    
    -- Check data ownership for player operations
    if gameDataId and not string.find(authResult.walletAddress, "admin") then
        local ownsData, ownershipErr = validateOwnership(authResult.walletAddress, gameDataId)
        if not ownsData then
            return false, ownershipErr
        end
    end
    
    return true, nil
end

-- Audit logging for authentication events
local authAuditLog = {}

local function logAuthEvent(eventType, walletAddress, operation, success, details)
    local logEntry = {
        timestamp = os.time(),
        eventType = eventType,
        walletAddress = walletAddress,
        operation = operation,
        success = success,
        details = details or {},
        processId = ao.id
    }
    
    table.insert(authAuditLog, logEntry)
    
    -- Keep only last 1000 entries to prevent memory issues
    if #authAuditLog > 1000 then
        table.remove(authAuditLog, 1)
    end
end

-- Comprehensive authentication and authorization
local function authenticateAndAuthorize(msg, operation, gameDataId)
    local authResult = authenticateMessage(msg)
    
    -- Log authentication attempt
    logAuthEvent("AUTHENTICATION", authResult.walletAddress or "unknown", operation, authResult.isAuthenticated, {
        errors = authResult.errors,
        sessionId = authResult.sessionId
    })
    
    if not authResult.isAuthenticated then
        return {
            success = false,
            error = "Authentication failed",
            details = authResult.errors,
            timestamp = tostring(os.time())
        }
    end
    
    -- Check authorization
    local authorized, authErr = authorizeOperation(authResult, operation, gameDataId)
    
    -- Log authorization attempt
    logAuthEvent("AUTHORIZATION", authResult.walletAddress, operation, authorized, {
        gameDataId = gameDataId,
        error = authErr
    })
    
    if not authorized then
        return {
            success = false,
            error = "Authorization failed",
            details = {authErr},
            walletAddress = authResult.walletAddress,
            timestamp = tostring(os.time())
        }
    end
    
    return {
        success = true,
        walletAddress = authResult.walletAddress,
        sessionId = authResult.sessionId,
        permissions = authResult.permissions,
        timestamp = tostring(os.time())
    }
end

-- AO Message Handlers
Handlers.add("create-session",
    Handlers.utils.hasMatchingTag("Action", "CreateSession"),
    function(msg)
        -- AO message authentication guarantees msg.From is valid
        local authResult = authenticateMessage(msg)
        
        -- Register ownership if gameDataId is provided
        local success, data = pcall(json.decode, msg.Data or "{}")
        if success and data.gameDataId then
            registerPlayerOwnership(authResult.walletAddress, data.gameDataId)
        end
        
        ao.send({
            Target = msg.From,
            Action = "SessionCreated",
            Data = json.encode({
                walletAddress = authResult.walletAddress,
                sessionId = authResult.sessionId,
                permissions = authResult.permissions,
                expiresAt = os.time() + sessionTimeout
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("validate-authorization",
    Handlers.utils.hasMatchingTag("Action", "ValidateAuthorization"),
    function(msg)
        local success, data = pcall(json.decode, msg.Data or "{}")
        
        if not success then
            ao.send({
                Target = msg.From,
                Action = "ValidationError",
                Error = "Invalid JSON data",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        local operation = data.operation or "UnknownOperation"
        local gameDataId = data.gameDataId
        
        local authResult = authenticateAndAuthorize(msg, operation, gameDataId)
        
        ao.send({
            Target = msg.From,
            Action = "AuthorizationResult",
            Data = json.encode(authResult),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("invalidate-session",
    Handlers.utils.hasMatchingTag("Action", "InvalidateSession"),
    function(msg)
        local success, data = pcall(json.decode, msg.Data or "{}")
        
        if success and data.sessionId then
            local invalidated = invalidateSession(data.sessionId)
            
            ao.send({
                Target = msg.From,
                Action = "SessionInvalidated",
                Data = json.encode({
                    sessionId = data.sessionId,
                    invalidated = invalidated
                }),
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        else
            ao.send({
                Target = msg.From,
                Action = "InvalidationError",
                Error = "Session ID required",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        end
    end
)

Handlers.add("get-auth-audit",
    Handlers.utils.hasMatchingTag("Action", "GetAuthAudit"),
    function(msg)
        -- This is an admin-only operation
        local authResult = authenticateAndAuthorize(msg, "ViewAllData", nil)
        
        if authResult.success then
            ao.send({
                Target = msg.From,
                Action = "AuthAuditData",
                Data = json.encode({
                    auditLog = authAuditLog,
                    activeSessions = activeSessions,
                    totalEntries = #authAuditLog
                }),
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        else
            ao.send({
                Target = msg.From,
                Action = "AuthorizationError",
                Error = authResult.error,
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        end
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
                service = "Authentication Manager",
                version = "1.0.0",
                capabilities = {
                    "wallet-authentication",
                    "session-management",
                    "operation-authorization",
                    "data-ownership-validation",
                    "audit-logging"
                },
                statistics = {
                    activeSessions = 0, -- Count active sessions
                    auditLogEntries = #authAuditLog
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
                    name = "Authentication Manager",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "createSession",
                        "validateAuthorization", 
                        "invalidateSession",
                        "getAuthAudit",
                        "managePlayerOwnership"
                    },
                    messageSchemas = {
                        CreateSession = {
                            required = {"Action"},
                            dataSchema = {
                                gameDataId = "string (optional)"
                            }
                        },
                        ValidateAuthorization = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                operation = "string",
                                gameDataId = "string (optional)"
                            }
                        },
                        InvalidateSession = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                sessionId = "string"
                            }
                        }
                    }
                },
                handlers = {"create-session", "validate-authorization", "invalidate-session", "get-auth-audit", "health-check", "info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    purpose = "Comprehensive authentication and authorization for AO message handling",
                    securityFeatures = {
                        "walletAddressAuthentication",
                        "sessionManagement",
                        "operationAuthorization",
                        "dataOwnershipValidation",
                        "auditLogging",
                        "roleBasedAccess"
                    }
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export functions for testing
_G.AuthManager = {
    authenticateMessage = authenticateMessage,
    authorizeOperation = authorizeOperation,
    authenticateAndAuthorize = authenticateAndAuthorize,
    createSession = createSession,
    getSession = getSession,
    invalidateSession = invalidateSession,
    registerPlayerOwnership = registerPlayerOwnership,
    validateOwnership = validateOwnership,
    checkOperationPermission = checkOperationPermission,
    getUserRole = getUserRole,
    activeSessions = activeSessions,
    authAuditLog = authAuditLog
}