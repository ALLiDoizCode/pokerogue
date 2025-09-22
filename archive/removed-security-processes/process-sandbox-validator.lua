-- Process Sandbox Validation System
-- Enhanced process validation for AO compliance and security
-- ADP v1.0 Compliant Process

-- Validation configuration and rules
local validationConfig = {
    maxProcessSize = 512000, -- 500KB in bytes
    maxFunctionLength = 10000, -- Maximum characters per function
    maxNestingDepth = 20, -- Maximum nesting depth for functions/loops
    allowedAoGlobals = {"ao", "Handlers", "json", "string", "table", "math", "os", "tonumber", "tostring", "type", "pairs", "ipairs", "next", "pcall", "xpcall"},
    forbiddenOperations = {
        "require%s*%(", "loadfile%s*%(", "dofile%s*%(", "loadstring%s*%(", "load%s*%(", 
        "io%.", "debug%.", "package%.", "module%s*%(",
        "coroutine%.create%s*%(", "coroutine%.wrap%s*%(", "coroutine%.yield%s*%(",
        "os%.execute%s*%(", "os%.exit%s*%(", "os%.getenv%s*%(", "os%.remove%s*%(", "os%.rename%s*%("
    },
    requiredPatterns = {
        "Handlers%.add%s*%(", -- Must use Handlers.add pattern
        "ao%.send%s*%(", -- Must use ao.send for communication
        "pcall%s*%(" -- Should include error handling
    },
    securityPatterns = {
        -- Potential security risks
        "eval%s*%(", "assert%s*%(", "error%s*%(", 
        "rawget%s*%(", "rawset%s*%(", "rawequal%s*%(", "rawlen%s*%(",
        "getmetatable%s*%(", "setmetatable%s*%(",
        "%_%G", -- Global variable access patterns that might be suspicious
    }
}

-- Validation results structure
local function createValidationResult(processName, isValid, errors, warnings, metrics)
    return {
        processName = processName,
        isValid = isValid or false,
        timestamp = os.time(),
        errors = errors or {},
        warnings = warnings or {},
        metrics = metrics or {},
        validationVersion = "1.0.0",
        aoCompliant = isValid and #errors == 0
    }
end

-- Enhanced file size validation
local function validateProcessSize(filePath, content)
    local errors = {}
    local warnings = {}
    local metrics = {}
    
    -- Get file size
    local fileSize = string.len(content)
    metrics.fileSize = fileSize
    metrics.maxAllowedSize = validationConfig.maxProcessSize
    
    if fileSize > validationConfig.maxProcessSize then
        table.insert(errors, string.format("Process size (%d bytes) exceeds maximum allowed size (%d bytes)", 
            fileSize, validationConfig.maxProcessSize))
    elseif fileSize > (validationConfig.maxProcessSize * 0.8) then
        table.insert(warnings, string.format("Process size (%d bytes) is approaching maximum limit", fileSize))
    end
    
    -- Count lines for complexity analysis
    local lineCount = 0
    for _ in content:gmatch("\n") do
        lineCount = lineCount + 1
    end
    metrics.lineCount = lineCount
    
    if lineCount > 2000 then
        table.insert(warnings, string.format("Process has %d lines, consider breaking into smaller modules", lineCount))
    end
    
    return {errors = errors, warnings = warnings, metrics = metrics}
end

-- AO compatibility validation
local function validateAoCompatibility(content)
    local errors = {}
    local warnings = {}
    local metrics = {
        handlerCount = 0,
        aoSendUsage = 0,
        forbiddenOperationCount = 0
    }
    
    -- Check for forbidden operations
    for _, pattern in ipairs(validationConfig.forbiddenOperations) do
        if content:match(pattern) then
            table.insert(errors, "Contains forbidden operation: " .. pattern:gsub("%%", ""))
            metrics.forbiddenOperationCount = metrics.forbiddenOperationCount + 1
        end
    end
    
    -- Check for required AO patterns
    for _, pattern in ipairs(validationConfig.requiredPatterns) do
        if not content:match(pattern) then
            if pattern:match("Handlers") then
                table.insert(errors, "Missing required Handlers.add pattern")
            elseif pattern:match("ao%.send") then
                table.insert(warnings, "No ao.send usage found - process may not communicate")
            elseif pattern:match("pcall") then
                table.insert(warnings, "No error handling with pcall found")
            end
        end
    end
    
    -- Count handlers
    for _ in content:gmatch("Handlers%.add%s*%(") do
        metrics.handlerCount = metrics.handlerCount + 1
    end
    
    -- Count ao.send usage
    for _ in content:gmatch("ao%.send%s*%(") do
        metrics.aoSendUsage = metrics.aoSendUsage + 1
    end
    
    if metrics.handlerCount == 0 then
        table.insert(errors, "No message handlers found - process cannot receive messages")
    end
    
    return {errors = errors, warnings = warnings, metrics = metrics}
end

-- Handler pattern validation
local function validateHandlerPatterns(content)
    local errors = {}
    local warnings = {}
    local metrics = {
        properHandlers = 0,
        improperHandlers = 0,
        adpCompliantHandlers = 0
    }
    
    -- Check for proper handler patterns
    local handlerPattern = "Handlers%.add%s*%(%s*[\"']([^\"']+)[\"']%s*,%s*([^,]+)%s*,%s*function%s*%([^%)]*%)"
    for handlerName, matcher in content:gmatch(handlerPattern) do
        metrics.properHandlers = metrics.properHandlers + 1
        
        -- Check for ADP compliance (Info handler)
        if handlerName == "info" then
            metrics.adpCompliantHandlers = metrics.adpCompliantHandlers + 1
        end
    end
    
    -- Check for improper direct assignments
    if content:match("Handlers%s*%[%s*[\"'][^\"']+[\"']%s*%]%s*=") then
        table.insert(errors, "Found direct handler assignment - use Handlers.add() instead")
        metrics.improperHandlers = metrics.improperHandlers + 1
    end
    
    -- Check for ADP v1.0 compliance
    if not content:match("adpVersion.*1%.0") then
        table.insert(warnings, "Process may not be ADP v1.0 compliant")
    end
    
    return {errors = errors, warnings = warnings, metrics = metrics}
end

-- Code safety validation
local function validateCodeSafety(content)
    local errors = {}
    local warnings = {}
    local metrics = {
        securityRisks = 0,
        complexityScore = 0
    }
    
    -- Check for security patterns
    for _, pattern in ipairs(validationConfig.securityPatterns) do
        if content:match(pattern) then
            table.insert(warnings, "Potentially risky pattern found: " .. pattern:gsub("%%", ""))
            metrics.securityRisks = metrics.securityRisks + 1
        end
    end
    
    -- Check for overly complex functions
    local functionPattern = "function%s+[%w_]+%s*%([^%)]*%)"
    local functionCount = 0
    for func in content:gmatch(functionPattern) do
        functionCount = functionCount + 1
    end
    
    local localFunctionPattern = "local%s+function%s+[%w_]+%s*%([^%)]*%)"
    for func in content:gmatch(localFunctionPattern) do
        functionCount = functionCount + 1
    end
    
    metrics.complexityScore = functionCount
    
    if functionCount > 50 then
        table.insert(warnings, string.format("High function count (%d) may indicate complex process", functionCount))
    end
    
    -- Check for proper local variable usage
    local globalAssignments = 0
    for _ in content:gmatch("\n%s*[%w_]+%s*=") do
        globalAssignments = globalAssignments + 1
    end
    
    local localAssignments = 0
    for _ in content:gmatch("\n%s*local%s+[%w_]+%s*=") do
        localAssignments = localAssignments + 1
    end
    
    if globalAssignments > localAssignments then
        table.insert(warnings, "Consider using more local variables to avoid global namespace pollution")
    end
    
    return {errors = errors, warnings = warnings, metrics = metrics}
end

-- Deterministic execution validation
local function validateDeterministicExecution(content)
    local errors = {}
    local warnings = {}
    local metrics = {
        mathRandomUsage = 0,
        osTimeUsage = 0,
        deterministicScore = 100
    }
    
    -- Check for non-deterministic functions
    for _ in content:gmatch("math%.random%s*%(") do
        table.insert(errors, "Uses math.random() - must use AO crypto module for deterministic randomness")
        metrics.mathRandomUsage = metrics.mathRandomUsage + 1
        metrics.deterministicScore = metrics.deterministicScore - 20
    end
    
    -- Check for time-based operations that might affect determinism
    for _ in content:gmatch("os%.time%s*%(") do
        metrics.osTimeUsage = metrics.osTimeUsage + 1
        -- os.time() is allowed for timestamps but warn about potential issues
        if metrics.osTimeUsage > 5 then
            table.insert(warnings, "Heavy os.time() usage detected - ensure this doesn't affect determinism")
            metrics.deterministicScore = metrics.deterministicScore - 5
        end
    end
    
    -- Check for external state dependencies
    if content:match("io%.") or content:match("file:") then
        table.insert(errors, "External file system access detected - not allowed in AO processes")
        metrics.deterministicScore = 0
    end
    
    return {errors = errors, warnings = warnings, metrics = metrics}
end

-- Error handling validation
local function validateErrorHandling(content)
    local errors = {}
    local warnings = {}
    local metrics = {
        pcallUsage = 0,
        unhandledErrors = 0,
        errorResponses = 0
    }
    
    -- Count pcall usage
    for _ in content:gmatch("pcall%s*%(") do
        metrics.pcallUsage = metrics.pcallUsage + 1
    end
    
    -- Count error responses
    for _ in content:gmatch("Action.*Error") do
        metrics.errorResponses = metrics.errorResponses + 1
    end
    
    -- Check for proper error handling patterns
    if metrics.pcallUsage == 0 then
        table.insert(warnings, "No pcall error handling found - consider adding for robustness")
    end
    
    -- Check for error response patterns
    if not content:match("Error.*=") and not content:match("error.*=") then
        table.insert(warnings, "No error response handling found")
    end
    
    -- Look for potential unhandled error sources
    local riskPatterns = {"json%.decode", "tonumber", "table%."}
    for _, pattern in ipairs(riskPatterns) do
        if content:match(pattern) and not content:match("pcall.*" .. pattern) then
            metrics.unhandledErrors = metrics.unhandledErrors + 1
        end
    end
    
    if metrics.unhandledErrors > 0 then
        table.insert(warnings, string.format("%d potentially unhandled error sources found", metrics.unhandledErrors))
    end
    
    return {errors = errors, warnings = warnings, metrics = metrics}
end

-- Comprehensive process validation
local function validateProcess(processPath, content)
    if not content then
        return createValidationResult(processPath, false, {"Cannot read process content"}, {}, {})
    end
    
    local allErrors = {}
    local allWarnings = {}
    local allMetrics = {}
    
    -- Run all validation checks
    local checks = {
        validateProcessSize(processPath, content),
        validateAoCompatibility(content),
        validateHandlerPatterns(content),
        validateCodeSafety(content),
        validateDeterministicExecution(content),
        validateErrorHandling(content)
    }
    
    -- Combine results
    for _, check in ipairs(checks) do
        for _, error in ipairs(check.errors) do
            table.insert(allErrors, error)
        end
        for _, warning in ipairs(check.warnings) do
            table.insert(allWarnings, warning)
        end
        for key, value in pairs(check.metrics) do
            allMetrics[key] = value
        end
    end
    
    -- Calculate overall validation score
    local totalIssues = #allErrors + (#allWarnings * 0.5)
    local isValid = #allErrors == 0
    allMetrics.validationScore = math.max(0, 100 - (totalIssues * 5))
    allMetrics.totalErrors = #allErrors
    allMetrics.totalWarnings = #allWarnings
    
    return createValidationResult(processPath, isValid, allErrors, allWarnings, allMetrics)
end

-- Deployment gate functionality
local function validateForDeployment(processPath, content)
    local result = validateProcess(processPath, content)
    
    -- Deployment criteria
    local deploymentReady = result.isValid and 
                           result.metrics.validationScore >= 80 and
                           result.metrics.deterministicScore >= 90
    
    result.deploymentReady = deploymentReady
    result.deploymentChecks = {
        noErrors = result.isValid,
        validationScore = result.metrics.validationScore >= 80,
        deterministicScore = result.metrics.deterministicScore >= 90,
        aoCompliant = result.aoCompliant
    }
    
    return result
end

-- Batch validation for multiple processes
local function validateMultipleProcesses(processPaths)
    local results = {}
    local summary = {
        totalProcesses = #processPaths,
        validProcesses = 0,
        deploymentReady = 0,
        totalErrors = 0,
        totalWarnings = 0
    }
    
    for _, processPath in ipairs(processPaths) do
        -- In a real implementation, this would read the file
        -- For testing, we'll pass nil content to trigger error handling
        local result = validateProcess(processPath, nil)
        table.insert(results, result)
        
        if result.isValid then
            summary.validProcesses = summary.validProcesses + 1
        end
        
        if result.deploymentReady then
            summary.deploymentReady = summary.deploymentReady + 1
        end
        
        summary.totalErrors = summary.totalErrors + result.metrics.totalErrors
        summary.totalWarnings = summary.totalWarnings + result.metrics.totalWarnings
    end
    
    return {
        results = results,
        summary = summary,
        timestamp = os.time()
    }
end

-- AO Message Handlers
Handlers.add("validate-process",
    Handlers.utils.hasMatchingTag("Action", "ValidateProcess"),
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
        
        local processPath = data.processPath or "unknown"
        local content = data.content or ""
        
        local result = validateProcess(processPath, content)
        
        ao.send({
            Target = msg.From,
            Action = "ProcessValidationResult",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("validate-for-deployment",
    Handlers.utils.hasMatchingTag("Action", "ValidateForDeployment"),
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
        
        local processPath = data.processPath or "unknown"
        local content = data.content or ""
        
        local result = validateForDeployment(processPath, content)
        
        ao.send({
            Target = msg.From,
            Action = "DeploymentValidationResult",
            Data = json.encode(result),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

Handlers.add("validate-multiple-processes",
    Handlers.utils.hasMatchingTag("Action", "ValidateMultipleProcesses"),
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
        
        local processPaths = data.processPaths or {}
        local result = validateMultipleProcesses(processPaths)
        
        ao.send({
            Target = msg.From,
            Action = "MultipleProcessValidationResult",
            Data = json.encode(result),
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
                service = "Process Sandbox Validator",
                version = "1.0.0",
                capabilities = {
                    "process-size-validation",
                    "ao-compatibility-validation",
                    "handler-pattern-validation",
                    "code-safety-validation",
                    "deterministic-execution-validation",
                    "error-handling-validation",
                    "deployment-gate-validation",
                    "batch-validation"
                },
                validationConfig = {
                    maxProcessSize = validationConfig.maxProcessSize,
                    supportedPatterns = #validationConfig.requiredPatterns,
                    securityChecks = #validationConfig.securityPatterns
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
                    name = "Process Sandbox Validator",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {
                        "validateProcess",
                        "validateForDeployment",
                        "validateMultipleProcesses",
                        "enhancedSecurityValidation",
                        "aoCompatibilityChecking"
                    },
                    messageSchemas = {
                        ValidateProcess = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                processPath = "string",
                                content = "string"
                            }
                        },
                        ValidateForDeployment = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                processPath = "string",
                                content = "string"
                            }
                        },
                        ValidateMultipleProcesses = {
                            required = {"Action", "Data"},
                            dataSchema = {
                                processPaths = "array of strings"
                            }
                        }
                    }
                },
                handlers = {"validate-process", "validate-for-deployment", "validate-multiple-processes", "health-check", "info"},
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    purpose = "Comprehensive process validation for AO sandbox compliance and security",
                    validationFeatures = {
                        "processSizeValidation",
                        "aoCompatibilityValidation",
                        "handlerPatternValidation",
                        "codeSafetyValidation",
                        "deterministicExecutionValidation",
                        "errorHandlingValidation",
                        "deploymentGateValidation",
                        "batchValidation"
                    }
                }
            }),
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Export functions for testing
_G.ProcessSandboxValidator = {
    validateProcess = validateProcess,
    validateForDeployment = validateForDeployment,
    validateMultipleProcesses = validateMultipleProcesses,
    validateProcessSize = validateProcessSize,
    validateAoCompatibility = validateAoCompatibility,
    validateHandlerPatterns = validateHandlerPatterns,
    validateCodeSafety = validateCodeSafety,
    validateDeterministicExecution = validateDeterministicExecution,
    validateErrorHandling = validateErrorHandling,
    createValidationResult = createValidationResult,
    validationConfig = validationConfig
}