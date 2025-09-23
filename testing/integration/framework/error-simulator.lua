--[[
Error Simulator for AO Process Integration Testing

Simulates various failure scenarios to test error handling, recovery patterns,
and graceful degradation in the 26-process stateless architecture.
]]

local ErrorSimulator = {}

-- Error Types and Simulation Patterns
local ERROR_TYPES = {
    PROCESS_TIMEOUT = "process_timeout",
    PROCESS_CRASH = "process_crash", 
    MESSAGE_CORRUPTION = "message_corruption",
    NETWORK_PARTITION = "network_partition",
    MEMORY_EXHAUSTION = "memory_exhaustion",
    INVALID_STATE = "invalid_state",
    HANDLER_EXCEPTION = "handler_exception",
    SERIALIZATION_ERROR = "serialization_error"
}

local FAILURE_PATTERNS = {
    SINGLE_PROCESS = "single_process",
    CASCADE_FAILURE = "cascade_failure",
    INTERMITTENT = "intermittent",
    PROGRESSIVE_DEGRADATION = "progressive_degradation",
    SPLIT_BRAIN = "split_brain"
}

-- Coordinator Process Failure Scenarios
local COORDINATOR_FAILURES = {
    ORCHESTRATION_TIMEOUT = {
        type = ERROR_TYPES.PROCESS_TIMEOUT,
        pattern = FAILURE_PATTERNS.SINGLE_PROCESS,
        severity = "high",
        description = "Coordinator process fails to respond within timeout"
    },
    WORKFLOW_CORRUPTION = {
        type = ERROR_TYPES.INVALID_STATE,
        pattern = FAILURE_PATTERNS.SINGLE_PROCESS,
        severity = "critical",
        description = "Coordinator workflow state becomes corrupted"
    },
    MESSAGE_QUEUE_OVERFLOW = {
        type = ERROR_TYPES.MEMORY_EXHAUSTION,
        pattern = FAILURE_PATTERNS.PROGRESSIVE_DEGRADATION,
        severity = "high",
        description = "Coordinator message queue exceeds capacity"
    }
}

-- Data Process Failure Scenarios
local DATA_PROCESS_FAILURES = {
    DATABASE_UNAVAILABLE = {
        type = ERROR_TYPES.PROCESS_CRASH,
        pattern = FAILURE_PATTERNS.SINGLE_PROCESS,
        severity = "high",
        description = "Data process becomes completely unavailable"
    },
    CORRUPTED_RESPONSE = {
        type = ERROR_TYPES.MESSAGE_CORRUPTION,
        pattern = FAILURE_PATTERNS.INTERMITTENT,
        severity = "medium",
        description = "Data process returns corrupted responses"
    },
    SLOW_RESPONSE = {
        type = ERROR_TYPES.PROCESS_TIMEOUT,
        pattern = FAILURE_PATTERNS.PROGRESSIVE_DEGRADATION,
        severity = "medium",
        description = "Data process responds slowly, causing timeouts"
    }
}

-- Logic Process Failure Scenarios
local LOGIC_PROCESS_FAILURES = {
    CALCULATION_ERROR = {
        type = ERROR_TYPES.HANDLER_EXCEPTION,
        pattern = FAILURE_PATTERNS.INTERMITTENT,
        severity = "high",
        description = "Logic process throws exception during calculation"
    },
    INFINITE_LOOP = {
        type = ERROR_TYPES.PROCESS_TIMEOUT,
        pattern = FAILURE_PATTERNS.SINGLE_PROCESS,
        severity = "critical",
        description = "Logic process enters infinite loop"
    },
    STATE_DESYNC = {
        type = ERROR_TYPES.INVALID_STATE,
        pattern = FAILURE_PATTERNS.CASCADE_FAILURE,
        severity = "high",
        description = "Logic process state becomes out of sync"
    }
}

function ErrorSimulator.createFailureScenario(scenarioType, config)
    local scenario = {
        id = "error-sim-" .. os.time(),
        type = scenarioType,
        config = config or {},
        startTime = os.time(),
        status = "initializing",
        failuresInjected = {},
        recoveryAttempts = {},
        effectsObserved = {}
    }
    
    -- Configure scenario based on type
    if scenarioType == "coordinator_failure" then
        scenario.targetProcess = "coordinator-process"
        scenario.failureTypes = COORDINATOR_FAILURES
    elseif scenarioType == "data_process_failure" then
        scenario.targetProcess = config.targetProcess or "pokemon-species-db"
        scenario.failureTypes = DATA_PROCESS_FAILURES
    elseif scenarioType == "logic_process_failure" then
        scenario.targetProcess = config.targetProcess or "battle-engine"
        scenario.failureTypes = LOGIC_PROCESS_FAILURES
    elseif scenarioType == "network_partition" then
        scenario.targetProcesses = config.targetProcesses or {"coordinator-process", "battle-engine"}
        scenario.partitionType = config.partitionType or "coordinator_isolation"
    elseif scenarioType == "cascade_failure" then
        scenario.initialProcess = config.initialProcess or "pokemon-species-db"
        scenario.cascadePattern = config.cascadePattern or "data_to_logic"
    end
    
    return scenario
end

function ErrorSimulator.injectFailure(scenario, failureSpec)
    local failure = {
        id = "failure-" .. os.time(),
        type = failureSpec.type,
        targetProcess = failureSpec.targetProcess,
        injectionTime = os.time(),
        duration = failureSpec.duration or 5000, -- 5 seconds default
        severity = failureSpec.severity or "medium",
        parameters = failureSpec.parameters or {},
        status = "active"
    }
    
    -- Log failure injection
    table.insert(scenario.failuresInjected, failure)
    
    -- Simulate failure based on type
    if failure.type == ERROR_TYPES.PROCESS_TIMEOUT then
        return ErrorSimulator.simulateProcessTimeout(failure)
    elseif failure.type == ERROR_TYPES.PROCESS_CRASH then
        return ErrorSimulator.simulateProcessCrash(failure)
    elseif failure.type == ERROR_TYPES.MESSAGE_CORRUPTION then
        return ErrorSimulator.simulateMessageCorruption(failure)
    elseif failure.type == ERROR_TYPES.HANDLER_EXCEPTION then
        return ErrorSimulator.simulateHandlerException(failure)
    elseif failure.type == ERROR_TYPES.INVALID_STATE then
        return ErrorSimulator.simulateInvalidState(failure)
    else
        failure.status = "failed"
        failure.error = "Unknown failure type: " .. failure.type
        return failure
    end
end

function ErrorSimulator.simulateProcessTimeout(failure)
    -- Simulate process timeout by introducing artificial delays
    failure.simulationDetails = {
        method = "artificial_delay",
        originalTimeout = 5000,
        injectedDelay = failure.duration,
        expectedBehavior = "timeout_error"
    }
    
    -- Create mock timeout response
    failure.mockResponse = {
        Id = "timeout-" .. failure.id,
        From = failure.targetProcess,
        Target = "error-simulator",
        Action = "Error",
        Error = "Process timeout after " .. failure.duration .. "ms",
        Success = false,
        Timestamp = tostring(os.time())
    }
    
    failure.status = "simulated"
    return failure
end

function ErrorSimulator.simulateProcessCrash(failure)
    -- Simulate complete process unavailability
    failure.simulationDetails = {
        method = "process_unavailable",
        crashType = "complete_failure",
        recoveryTime = failure.parameters.recoveryTime or 10000,
        expectedBehavior = "no_response"
    }
    
    -- No response expected from crashed process
    failure.mockResponse = nil
    failure.status = "simulated"
    return failure
end

function ErrorSimulator.simulateMessageCorruption(failure)
    -- Simulate corrupted message data
    failure.simulationDetails = {
        method = "data_corruption",
        corruptionType = failure.parameters.corruptionType or "json_malformed",
        corruptionRate = failure.parameters.corruptionRate or 0.3,
        expectedBehavior = "parsing_error"
    }
    
    -- Create corrupted response
    local corruptedData = ErrorSimulator.corruptJsonData(failure.parameters.originalData or "{}")
    
    failure.mockResponse = {
        Id = "corrupted-" .. failure.id,
        From = failure.targetProcess,
        Target = "error-simulator",
        Action = "Success",
        Data = corruptedData,
        Success = true,
        Timestamp = tostring(os.time())
    }
    
    failure.status = "simulated"
    return failure
end

function ErrorSimulator.simulateHandlerException(failure)
    -- Simulate exception in message handler
    failure.simulationDetails = {
        method = "handler_exception",
        exceptionType = failure.parameters.exceptionType or "lua_runtime_error",
        stackTrace = "Error in handler: " .. (failure.parameters.errorMessage or "Simulated exception"),
        expectedBehavior = "error_response"
    }
    
    failure.mockResponse = {
        Id = "exception-" .. failure.id,
        From = failure.targetProcess,
        Target = "error-simulator",
        Action = "Error",
        Error = "Handler exception: " .. failure.simulationDetails.stackTrace,
        Success = false,
        Timestamp = tostring(os.time())
    }
    
    failure.status = "simulated"
    return failure
end

function ErrorSimulator.simulateInvalidState(failure)
    -- Simulate invalid or corrupted process state
    failure.simulationDetails = {
        method = "state_corruption",
        stateCorruptionType = failure.parameters.stateCorruptionType or "gamestate_invalid",
        affectedFields = failure.parameters.affectedFields or {"party", "inventory"},
        expectedBehavior = "state_validation_error"
    }
    
    -- Create response with invalid state
    local invalidGameState = ErrorSimulator.createInvalidGameState(failure.parameters)
    
    failure.mockResponse = {
        Id = "invalid-state-" .. failure.id,
        From = failure.targetProcess,
        Target = "error-simulator",
        Action = "Success",
        Data = json.encode({processed = true}),
        GameState = invalidGameState,
        Success = true,
        Timestamp = tostring(os.time())
    }
    
    failure.status = "simulated"
    return failure
end

function ErrorSimulator.corruptJsonData(originalData)
    local corrupted = originalData
    
    -- Simulate various JSON corruption patterns
    local corruptionPatterns = {
        "missing_brace", "invalid_quotes", "truncated_data", 
        "extra_comma", "invalid_escape", "wrong_type"
    }
    
    local pattern = corruptionPatterns[math.random(#corruptionPatterns)]
    
    if pattern == "missing_brace" then
        corrupted = string.gsub(corrupted, "}", "")
    elseif pattern == "invalid_quotes" then
        corrupted = string.gsub(corrupted, '"', "'")
    elseif pattern == "truncated_data" then
        corrupted = string.sub(corrupted, 1, math.floor(#corrupted * 0.7))
    elseif pattern == "extra_comma" then
        corrupted = string.gsub(corrupted, "}", ",}")
    elseif pattern == "invalid_escape" then
        corrupted = string.gsub(corrupted, "\\", "\\\\\\")
    elseif pattern == "wrong_type" then
        corrupted = '"' .. corrupted .. '"'
    end
    
    return corrupted
end

function ErrorSimulator.createInvalidGameState(parameters)
    local invalidState = {
        version = "1.0.0",
        playerId = "test-player",
        party = {},
        progression = {}
    }
    
    local corruptionType = parameters.stateCorruptionType or "party_invalid"
    
    if corruptionType == "party_invalid" then
        -- Create invalid party data
        invalidState.party = {
            {
                id = nil, -- Missing required field
                speciesId = -1, -- Invalid species ID
                level = 0, -- Invalid level
                stats = {
                    hp = -50, -- Negative HP
                    attack = "invalid" -- Wrong type
                },
                currentHp = 200, -- HP exceeds max
                moves = {9999, 9999, 9999, 9999, 9999} -- Too many moves, invalid IDs
            }
        }
    elseif corruptionType == "progression_invalid" then
        -- Create invalid progression data
        invalidState.progression = {
            level = -5, -- Negative level
            experience = "not_a_number", -- Wrong type
            badges = 15 -- Too many badges
        }
    elseif corruptionType == "cross_field_inconsistent" then
        -- Create cross-field inconsistencies
        invalidState.party = {
            {
                id = "pokemon-001",
                speciesId = 25,
                level = 50,
                currentHp = 0 -- Fainted Pokemon
            }
        }
        invalidState.currentBattle = {
            battleType = "wild",
            playerPokemon = {
                id = "pokemon-002", -- Different ID than party
                currentHp = 100
            }
        }
    end
    
    return json.encode(invalidState)
end

function ErrorSimulator.executeRecoveryPattern(scenario, recoverySpec)
    local recovery = {
        id = "recovery-" .. os.time(),
        type = recoverySpec.type,
        targetFailure = recoverySpec.targetFailure,
        startTime = os.time(),
        steps = {},
        status = "executing"
    }
    
    table.insert(scenario.recoveryAttempts, recovery)
    
    if recoverySpec.type == "coordinator_failover" then
        return ErrorSimulator.executeCoordinatorFailover(recovery, recoverySpec)
    elseif recoverySpec.type == "process_restart" then
        return ErrorSimulator.executeProcessRestart(recovery, recoverySpec)
    elseif recoverySpec.type == "state_rollback" then
        return ErrorSimulator.executeStateRollback(recovery, recoverySpec)
    elseif recoverySpec.type == "graceful_degradation" then
        return ErrorSimulator.executeGracefulDegradation(recovery, recoverySpec)
    elseif recoverySpec.type == "retry_with_backoff" then
        return ErrorSimulator.executeRetryWithBackoff(recovery, recoverySpec)
    else
        recovery.status = "failed"
        recovery.error = "Unknown recovery type: " .. recoverySpec.type
        return recovery
    end
end

function ErrorSimulator.executeCoordinatorFailover(recovery, spec)
    -- Simulate coordinator failover process
    table.insert(recovery.steps, {
        step = "detect_coordinator_failure",
        timestamp = os.time(),
        description = "Detecting coordinator process failure"
    })
    
    table.insert(recovery.steps, {
        step = "initiate_failover",
        timestamp = os.time(),
        description = "Initiating failover to backup coordinator"
    })
    
    table.insert(recovery.steps, {
        step = "restore_workflow_state",
        timestamp = os.time(),
        description = "Restoring workflow state from checkpoint"
    })
    
    table.insert(recovery.steps, {
        step = "resume_operations",
        timestamp = os.time(),
        description = "Resuming normal operations with new coordinator"
    })
    
    recovery.endTime = os.time()
    recovery.duration = recovery.endTime - recovery.startTime
    recovery.status = "completed"
    recovery.success = true
    
    return recovery
end

function ErrorSimulator.executeProcessRestart(recovery, spec)
    -- Simulate process restart recovery
    table.insert(recovery.steps, {
        step = "terminate_failed_process",
        timestamp = os.time(),
        description = "Terminating failed process: " .. spec.targetProcess
    })
    
    table.insert(recovery.steps, {
        step = "clean_process_state",
        timestamp = os.time(),
        description = "Cleaning up process state and resources"
    })
    
    table.insert(recovery.steps, {
        step = "restart_process",
        timestamp = os.time(),
        description = "Restarting process with clean state"
    })
    
    table.insert(recovery.steps, {
        step = "validate_process_health",
        timestamp = os.time(),
        description = "Validating restarted process health"
    })
    
    recovery.endTime = os.time()
    recovery.duration = recovery.endTime - recovery.startTime
    recovery.status = "completed"
    recovery.success = true
    
    return recovery
end

function ErrorSimulator.executeStateRollback(recovery, spec)
    -- Simulate state rollback recovery
    table.insert(recovery.steps, {
        step = "identify_corruption_point",
        timestamp = os.time(),
        description = "Identifying state corruption point"
    })
    
    table.insert(recovery.steps, {
        step = "locate_clean_checkpoint",
        timestamp = os.time(),
        description = "Locating clean state checkpoint"
    })
    
    table.insert(recovery.steps, {
        step = "rollback_to_checkpoint",
        timestamp = os.time(),
        description = "Rolling back to clean checkpoint"
    })
    
    table.insert(recovery.steps, {
        step = "validate_rolled_back_state",
        timestamp = os.time(),
        description = "Validating rolled back state integrity"
    })
    
    recovery.endTime = os.time()
    recovery.duration = recovery.endTime - recovery.startTime
    recovery.status = "completed"
    recovery.success = true
    
    return recovery
end

function ErrorSimulator.executeGracefulDegradation(recovery, spec)
    -- Simulate graceful degradation
    table.insert(recovery.steps, {
        step = "assess_failure_impact",
        timestamp = os.time(),
        description = "Assessing failure impact on system capabilities"
    })
    
    table.insert(recovery.steps, {
        step = "identify_degraded_functions",
        timestamp = os.time(),
        description = "Identifying functions that must be degraded"
    })
    
    table.insert(recovery.steps, {
        step = "activate_fallback_mode",
        timestamp = os.time(),
        description = "Activating fallback mode for affected operations"
    })
    
    table.insert(recovery.steps, {
        step = "notify_users_of_degradation",
        timestamp = os.time(),
        description = "Notifying users of degraded service"
    })
    
    recovery.endTime = os.time()
    recovery.duration = recovery.endTime - recovery.startTime
    recovery.status = "completed"
    recovery.success = true
    recovery.degradedCapabilities = spec.degradedCapabilities or {"advanced_battle_calculations"}
    
    return recovery
end

function ErrorSimulator.executeRetryWithBackoff(recovery, spec)
    -- Simulate retry with exponential backoff
    local maxRetries = spec.maxRetries or 3
    local baseDelay = spec.baseDelay or 1000
    
    for attempt = 1, maxRetries do
        local delay = baseDelay * (2 ^ (attempt - 1))
        
        table.insert(recovery.steps, {
            step = "retry_attempt_" .. attempt,
            timestamp = os.time(),
            description = "Retry attempt " .. attempt .. " after " .. delay .. "ms delay",
            delay = delay
        })
        
        -- Simulate increasing success probability with retries
        local successProbability = 0.3 + (attempt * 0.2)
        if math.random() < successProbability then
            table.insert(recovery.steps, {
                step = "retry_successful",
                timestamp = os.time(),
                description = "Retry attempt " .. attempt .. " succeeded"
            })
            
            recovery.endTime = os.time()
            recovery.duration = recovery.endTime - recovery.startTime
            recovery.status = "completed"
            recovery.success = true
            recovery.successfulAttempt = attempt
            return recovery
        end
    end
    
    -- All retries failed
    table.insert(recovery.steps, {
        step = "all_retries_failed",
        timestamp = os.time(),
        description = "All retry attempts failed, escalating to higher-level recovery"
    })
    
    recovery.endTime = os.time()
    recovery.duration = recovery.endTime - recovery.startTime
    recovery.status = "failed"
    recovery.success = false
    
    return recovery
end

function ErrorSimulator.validateRecoveryEffectiveness(scenario)
    local validation = {
        scenario = scenario.id,
        timestamp = os.time(),
        recoverySuccess = true,
        validationResults = {},
        recommendations = {}
    }
    
    -- Validate each recovery attempt
    for _, recovery in ipairs(scenario.recoveryAttempts) do
        local recoveryValidation = {
            recoveryId = recovery.id,
            type = recovery.type,
            success = recovery.success,
            duration = recovery.duration,
            stepsCompleted = #recovery.steps,
            issues = {}
        }
        
        -- Check recovery time requirements
        local maxAcceptableTime = 30000 -- 30 seconds
        if recovery.duration > maxAcceptableTime then
            recoveryValidation.success = false
            table.insert(recoveryValidation.issues, "Recovery time exceeded threshold: " .. recovery.duration .. "ms > " .. maxAcceptableTime .. "ms")
        end
        
        -- Check for complete recovery steps
        local expectedSteps = ErrorSimulator.getExpectedRecoverySteps(recovery.type)
        if #recovery.steps < expectedSteps then
            table.insert(recoveryValidation.issues, "Incomplete recovery steps: " .. #recovery.steps .. " < " .. expectedSteps)
        end
        
        table.insert(validation.validationResults, recoveryValidation)
        
        if not recoveryValidation.success then
            validation.recoverySuccess = false
        end
    end
    
    -- Generate recommendations
    if not validation.recoverySuccess then
        table.insert(validation.recommendations, "Improve recovery time targets")
        table.insert(validation.recommendations, "Implement automated recovery validation")
        table.insert(validation.recommendations, "Add more detailed recovery monitoring")
    end
    
    return validation
end

function ErrorSimulator.getExpectedRecoverySteps(recoveryType)
    local expectedSteps = {
        coordinator_failover = 4,
        process_restart = 4,
        state_rollback = 4,
        graceful_degradation = 4,
        retry_with_backoff = 2 -- Minimum 2 steps (at least one retry + result)
    }
    
    return expectedSteps[recoveryType] or 3
end

function ErrorSimulator.generateFailureReport(scenario)
    local report = {
        scenarioId = scenario.id,
        scenarioType = scenario.type,
        executionTime = os.time() - scenario.startTime,
        totalFailures = #scenario.failuresInjected,
        totalRecoveries = #scenario.recoveryAttempts,
        successfulRecoveries = 0,
        failureTypes = {},
        recoveryTypes = {},
        summary = {},
        recommendations = {}
    }
    
    -- Analyze failures
    local failureTypeCounts = {}
    for _, failure in ipairs(scenario.failuresInjected) do
        failureTypeCounts[failure.type] = (failureTypeCounts[failure.type] or 0) + 1
    end
    report.failureTypes = failureTypeCounts
    
    -- Analyze recoveries
    local recoveryTypeCounts = {}
    for _, recovery in ipairs(scenario.recoveryAttempts) do
        recoveryTypeCounts[recovery.type] = (recoveryTypeCounts[recovery.type] or 0) + 1
        if recovery.success then
            report.successfulRecoveries = report.successfulRecoveries + 1
        end
    end
    report.recoveryTypes = recoveryTypeCounts
    
    -- Generate summary
    report.summary = {
        recoverySuccessRate = report.successfulRecoveries / math.max(report.totalRecoveries, 1),
        mostCommonFailure = ErrorSimulator.getMostCommon(failureTypeCounts),
        mostEffectiveRecovery = ErrorSimulator.getMostEffectiveRecovery(scenario.recoveryAttempts),
        averageRecoveryTime = ErrorSimulator.getAverageRecoveryTime(scenario.recoveryAttempts)
    }
    
    -- Generate recommendations
    if report.summary.recoverySuccessRate < 0.8 then
        table.insert(report.recommendations, "Improve recovery success rate (currently " .. string.format("%.1f", report.summary.recoverySuccessRate * 100) .. "%)")
    end
    
    if report.summary.averageRecoveryTime > 15000 then
        table.insert(report.recommendations, "Reduce average recovery time (currently " .. report.summary.averageRecoveryTime .. "ms)")
    end
    
    table.insert(report.recommendations, "Focus testing on " .. report.summary.mostCommonFailure .. " failure scenarios")
    table.insert(report.recommendations, "Leverage " .. report.summary.mostEffectiveRecovery .. " recovery pattern")
    
    return report
end

function ErrorSimulator.getMostCommon(counts)
    local maxCount = 0
    local mostCommon = "none"
    
    for type, count in pairs(counts) do
        if count > maxCount then
            maxCount = count
            mostCommon = type
        end
    end
    
    return mostCommon
end

function ErrorSimulator.getMostEffectiveRecovery(recoveries)
    local successRates = {}
    
    for _, recovery in ipairs(recoveries) do
        if not successRates[recovery.type] then
            successRates[recovery.type] = {total = 0, successful = 0}
        end
        
        successRates[recovery.type].total = successRates[recovery.type].total + 1
        if recovery.success then
            successRates[recovery.type].successful = successRates[recovery.type].successful + 1
        end
    end
    
    local bestType = "none"
    local bestRate = 0
    
    for type, stats in pairs(successRates) do
        local rate = stats.successful / stats.total
        if rate > bestRate then
            bestRate = rate
            bestType = type
        end
    end
    
    return bestType
end

function ErrorSimulator.getAverageRecoveryTime(recoveries)
    if #recoveries == 0 then
        return 0
    end
    
    local totalTime = 0
    local count = 0
    
    for _, recovery in ipairs(recoveries) do
        if recovery.duration then
            totalTime = totalTime + recovery.duration
            count = count + 1
        end
    end
    
    return count > 0 and (totalTime / count) or 0
end

return ErrorSimulator