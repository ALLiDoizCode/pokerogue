-- Audit Logger Unit Tests
-- Comprehensive test suite for audit logging and player attribution

-- Test data factories
local function createTestGameState(level, money, hp)
    return {
        party = {{
            id = 1,
            species = "BULBASAUR",
            level = level or 5,
            hp = hp or 20,
            maxHp = 20,
            exp = (level or 5) * 100
        }},
        inventory = {
            money = money or 1000,
            items = {POTION = 5}
        },
        progression = {
            exp = (level or 5) * 100,
            badges = {"BOULDER_BADGE"}
        }
    }
end

local function createAOMessage(from, action, data)
    return {
        From = from or "test_wallet_12345678901234567890123",
        Action = action or "LogGameStateModification",
        Data = data and json.encode(data) or nil
    }
end

-- Test functions
local function testAuditLogEntryCreation(logger)
    print("  🧪 Testing audit log entry creation...")
    
    local walletAddress = "test_wallet_12345678901234567890123"
    local operation = "BattleAction"
    local details = {
        severity = "INFO",
        battleResult = "victory",
        correlationId = "test_corr_123"
    }
    
    local entry = logger.createAuditLogEntry("GAMESTATE_MODIFICATION", walletAddress, operation, details)
    
    assert(entry ~= nil, "Audit entry should be created")
    assert(entry.id ~= nil, "Entry should have ID")
    assert(entry.timestamp ~= nil, "Entry should have timestamp")
    assert(entry.eventType == "GAMESTATE_MODIFICATION", "Entry should have correct event type")
    assert(entry.walletAddress == walletAddress, "Entry should have correct wallet address")
    assert(entry.operation == operation, "Entry should have correct operation")
    assert(entry.correlationId == "test_corr_123", "Entry should preserve correlation ID")
    assert(entry.severity == "INFO", "Entry should have correct severity")
    assert(entry.context ~= nil, "Entry should have context information")
    
    print("    ✅ Audit log entry creation tests passed")
end

local function testStateDiffCalculation(logger)
    print("  🧪 Testing state diff calculation...")
    
    local beforeState = createTestGameState(5, 1000, 20)
    local afterState = createTestGameState(6, 1200, 18)
    
    local diff = logger.calculateStateDiff(beforeState, afterState)
    
    assert(diff ~= nil, "Diff should be calculated")
    assert(diff.pokemon_1 ~= nil, "Pokemon changes should be detected")
    assert(diff.pokemon_1.level ~= nil, "Level change should be detected")
    assert(diff.pokemon_1.level.from == 5, "Should track old level")
    assert(diff.pokemon_1.level.to == 6, "Should track new level")
    assert(diff.pokemon_1.hp.from == 20, "Should track old HP")
    assert(diff.pokemon_1.hp.to == 18, "Should track new HP")
    assert(diff.money ~= nil, "Money change should be detected")
    assert(diff.money.change == 200, "Should calculate money change correctly")
    
    -- Test with identical states
    local identicalDiff = logger.calculateStateDiff(beforeState, beforeState)
    assert(next(identicalDiff) == nil, "Identical states should have empty diff")
    
    -- Test with invalid states
    local invalidDiff = logger.calculateStateDiff("invalid", {})
    assert(invalidDiff.error ~= nil, "Invalid states should return error")
    
    print("    ✅ State diff calculation tests passed")
end

local function testGameStateModificationLogging(logger)
    print("  🧪 Testing GameState modification logging...")
    
    local walletAddress = "mod_wallet_12345678901234567890123"
    local operation = "LevelUp"
    local beforeState = createTestGameState(5, 1000, 20)
    local afterState = createTestGameState(6, 1000, 25)
    local correlationId = "test_level_up_123"
    
    local initialLogCount = #logger.auditLogs
    
    local entry = logger.logGameStateModification(walletAddress, operation, beforeState, afterState, correlationId)
    
    assert(entry ~= nil, "Should return audit entry")
    assert(#logger.auditLogs == initialLogCount + 1, "Should add entry to audit logs")
    assert(entry.eventType == "GAMESTATE_MODIFICATION", "Should have correct event type")
    assert(entry.stateChange ~= nil, "Should include state change information")
    assert(entry.stateChange.diff ~= nil, "Should calculate state diff")
    
    -- Check player action tracking
    assert(logger.playerActions[walletAddress] ~= nil, "Should track player actions")
    assert(logger.playerActions[walletAddress].totalActions > 0, "Should increment action count")
    assert(logger.playerActions[walletAddress].operationCounts[operation] == 1, "Should count operation")
    
    print("    ✅ GameState modification logging tests passed")
end

local function testSecurityEventLogging(logger)
    print("  🧪 Testing security event logging...")
    
    local walletAddress = "security_wallet_12345678901234567890123"
    local eventType = "CHEAT_DETECTION"
    local operation = "AntiCheatAnalysis"
    local severity = "HIGH"
    local details = {
        violationType = "STAT_MANIPULATION",
        evidence = "Impossible IV values detected"
    }
    
    local initialSecurityCount = #logger.securityEvents
    local initialLogCount = #logger.auditLogs
    
    local entry = logger.logSecurityEvent(eventType, walletAddress, operation, severity, details)
    
    assert(entry ~= nil, "Should return security event entry")
    assert(#logger.auditLogs > initialLogCount, "Should add to audit logs")
    assert(#logger.securityEvents == initialSecurityCount + 1, "Should add to security events")
    assert(entry.eventType == eventType, "Should have correct event type")
    assert(entry.severity == severity, "Should have correct severity")
    assert(entry.details.alertGenerated == true, "Should mark alert as generated")
    
    print("    ✅ Security event logging tests passed")
end

local function testCorrelationIdGeneration(logger)
    print("  🧪 Testing correlation ID generation...")
    
    local corrId1 = logger.generateCorrelationId()
    local corrId2 = logger.generateCorrelationId()
    
    assert(corrId1 ~= nil, "Should generate correlation ID")
    assert(corrId2 ~= nil, "Should generate second correlation ID")
    assert(corrId1 ~= corrId2, "Should generate unique correlation IDs")
    assert(string.find(corrId1, "corr_"), "Should have correct prefix")
    
    print("    ✅ Correlation ID generation tests passed")
end

local function testAuditLogQuerying(logger)
    print("  🧪 Testing audit log querying...")
    
    -- Add some test entries
    local wallet1 = "query_wallet_1_12345678901234567890123"
    local wallet2 = "query_wallet_2_12345678901234567890123"
    
    logger.logGameStateModification(wallet1, "BattleAction", createTestGameState(), createTestGameState())
    logger.logSecurityEvent("AUTHENTICATION_FAILURE", wallet1, "CreateSession", "MEDIUM", {})
    logger.logGameStateModification(wallet2, "SaveProgress", createTestGameState(), createTestGameState())
    
    -- Test querying by wallet address
    local wallet1Results = logger.queryAuditLogs({walletAddress = wallet1})
    assert(#wallet1Results >= 2, "Should find entries for wallet1")
    
    for _, entry in ipairs(wallet1Results) do
        assert(entry.walletAddress == wallet1, "All results should match wallet address")
    end
    
    -- Test querying by event type
    local securityResults = logger.queryAuditLogs({eventType = "AUTHENTICATION_FAILURE"})
    assert(#securityResults >= 1, "Should find security events")
    
    for _, entry in ipairs(securityResults) do
        assert(entry.eventType == "AUTHENTICATION_FAILURE", "All results should match event type")
    end
    
    -- Test querying by operation
    local battleResults = logger.queryAuditLogs({operation = "BattleAction"})
    assert(#battleResults >= 1, "Should find battle actions")
    
    -- Test time range filtering
    local currentTime = os.time()
    local recentResults = logger.queryAuditLogs({
        startTime = currentTime - 60,
        endTime = currentTime + 60
    })
    assert(#recentResults >= 3, "Should find recent entries")
    
    -- Test result limiting
    local limitedResults = logger.queryAuditLogs({limit = 2})
    assert(#limitedResults <= 2, "Should respect limit parameter")
    
    print("    ✅ Audit log querying tests passed")
end

local function testInvestigationReportGeneration(logger)
    print("  🧪 Testing investigation report generation...")
    
    local investigationWallet = "investigation_wallet_12345678901234567890123"
    
    -- Add various types of events for this wallet
    logger.logGameStateModification(investigationWallet, "BattleAction", createTestGameState(), createTestGameState())
    logger.logGameStateModification(investigationWallet, "SaveProgress", createTestGameState(), createTestGameState())
    logger.logSecurityEvent("CHEAT_DETECTION", investigationWallet, "AntiCheatAnalysis", "HIGH", {})
    logger.logSecurityEvent("VALIDATION_FAILURE", investigationWallet, "ValidateGameState", "MEDIUM", {})
    
    local report = logger.generateInvestigationReport(investigationWallet, {
        start = os.time() - 3600,
        end = os.time()
    })
    
    assert(report ~= nil, "Should generate investigation report")
    assert(report.walletAddress == investigationWallet, "Should target correct wallet")
    assert(report.summary ~= nil, "Should include summary")
    assert(report.summary.totalEvents >= 4, "Should count all events")
    assert(report.summary.securityEvents >= 2, "Should count security events")
    assert(report.summary.operations ~= nil, "Should include operation counts")
    assert(report.findings ~= nil, "Should include findings")
    assert(report.recommendations ~= nil, "Should include recommendations")
    
    -- Check for security event finding
    local hasSecurityFinding = false
    for _, finding in ipairs(report.findings) do
        if finding.type == "SECURITY_EVENTS_DETECTED" then
            hasSecurityFinding = true
            break
        end
    end
    assert(hasSecurityFinding, "Should detect security events in findings")
    
    print("    ✅ Investigation report generation tests passed")
end

local function testLogRetention(logger)
    print("  🧪 Testing log retention...")
    
    -- Add some test entries with old timestamps
    local oldEntry = logger.createAuditLogEntry("TEST_EVENT", "old_wallet", "TestOp", {})
    oldEntry.timestamp = os.time() - (32 * 86400) -- 32 days ago
    table.insert(logger.auditLogs, oldEntry)
    
    local recentEntry = logger.createAuditLogEntry("TEST_EVENT", "recent_wallet", "TestOp", {})
    recentEntry.timestamp = os.time() - (10 * 86400) -- 10 days ago
    table.insert(logger.auditLogs, recentEntry)
    
    local initialCount = #logger.auditLogs
    
    local retentionResult = logger.performLogRetention()
    
    assert(retentionResult ~= nil, "Should return retention result")
    assert(retentionResult.deletedEntries >= 1, "Should delete old entries")
    assert(retentionResult.retainedEntries >= 1, "Should retain recent entries")
    assert(#logger.auditLogs < initialCount, "Should reduce log count")
    
    print("    ✅ Log retention tests passed")
end

local function testPlayerActionTracking(logger)
    print("  🧪 Testing player action tracking...")
    
    local trackingWallet = "tracking_wallet_12345678901234567890123"
    
    -- Perform multiple actions
    logger.logGameStateModification(trackingWallet, "BattleAction", createTestGameState(), createTestGameState())
    logger.logGameStateModification(trackingWallet, "BattleAction", createTestGameState(), createTestGameState())
    logger.logGameStateModification(trackingWallet, "SaveProgress", createTestGameState(), createTestGameState())
    
    local playerStats = logger.playerActions[trackingWallet]
    
    assert(playerStats ~= nil, "Should track player statistics")
    assert(playerStats.totalActions == 3, "Should count total actions")
    assert(playerStats.operationCounts["BattleAction"] == 2, "Should count battle actions")
    assert(playerStats.operationCounts["SaveProgress"] == 1, "Should count save progress")
    assert(playerStats.firstSeen ~= nil, "Should track first seen time")
    assert(playerStats.lastSeen ~= nil, "Should track last seen time")
    
    print("    ✅ Player action tracking tests passed")
end

local function testEdgeCases(logger)
    print("  🧪 Testing edge cases...")
    
    -- Test with nil parameters
    local nilEntry = logger.createAuditLogEntry(nil, nil, nil, nil)
    assert(nilEntry ~= nil, "Should handle nil parameters gracefully")
    assert(nilEntry.eventType == nil, "Should preserve nil event type")
    assert(nilEntry.walletAddress == "unknown", "Should use default wallet address")
    
    -- Test empty query
    local emptyResults = logger.queryAuditLogs({})
    assert(type(emptyResults) == "table", "Should return table for empty query")
    
    -- Test query with no matches
    local noMatchResults = logger.queryAuditLogs({walletAddress = "nonexistent_wallet"})
    assert(#noMatchResults == 0, "Should return empty results for no matches")
    
    -- Test state diff with nil states
    local nilDiff = logger.calculateStateDiff(nil, nil)
    assert(nilDiff.error ~= nil, "Should handle nil states")
    
    print("    ✅ Edge case tests passed")
end

local function testPerformance(logger)
    print("  🧪 Testing audit logging performance...")
    
    local performanceWallet = "perf_wallet_12345678901234567890123"
    
    -- Test bulk logging performance
    local startTime = os.clock()
    
    for i = 1, 100 do
        logger.logGameStateModification(
            performanceWallet .. "_" .. i,
            "BulkTest",
            createTestGameState(),
            createTestGameState()
        )
    end
    
    local endTime = os.clock()
    local duration = endTime - startTime
    
    assert(duration < 0.2, "100 audit log operations should complete within 200ms (actual: " .. duration .. "s)")
    
    -- Test query performance
    startTime = os.clock()
    
    for i = 1, 50 do
        logger.queryAuditLogs({operation = "BulkTest"})
    end
    
    endTime = os.clock()
    duration = endTime - startTime
    
    assert(duration < 0.1, "50 query operations should complete within 100ms (actual: " .. duration .. "s)")
    
    print("    ✅ Performance tests passed - operations completed efficiently")
end

-- Main test runner
local function runAllTests()
    -- Setup environment
    _G.json = {
        encode = function(obj)
            if type(obj) == "table" then
                return "json_encoded_table"
            else
                return tostring(obj)
            end
        end,
        decode = function(str)
            if str then
                return {decoded = true}
            else
                return {}
            end
        end
    }
    _G.ao = {
        send = function(msg) end,
        id = "test_audit_logger"
    }
    _G.Handlers = {
        add = function(name, matcher, handler) end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg) return true end
            end
        }
    }
    
    -- Load the audit logger
    dofile("processes/security/audit-logger.lua")
    local logger = _G.AuditLogger
    
    print("🚀 Audit Logger Test Suite")
    print("="..string.rep("=", 50))
    
    testAuditLogEntryCreation(logger)
    testStateDiffCalculation(logger)
    testGameStateModificationLogging(logger)
    testSecurityEventLogging(logger)
    testCorrelationIdGeneration(logger)
    testAuditLogQuerying(logger)
    testInvestigationReportGeneration(logger)
    testLogRetention(logger)
    testPlayerActionTracking(logger)
    testEdgeCases(logger)
    testPerformance(logger)
    
    print("="..string.rep("=", 50))
    print("🎉 All Audit Logger tests passed!")
    return true
end

-- Export test runner
return {
    runAllTests = runAllTests
}