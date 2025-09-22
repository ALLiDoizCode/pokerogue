-- Authentication Manager Unit Tests
-- Comprehensive test suite for AO-native authentication and authorization

-- Test data factories
local function createValidAOMessage(from, action, data)
    return {
        From = from or "valid_wallet_address_12345678901234567890123",
        Action = action or "CreateSession",
        Data = data and json.encode(data) or nil
    }
end

local function createMessageWithoutSender(action, data)
    return {
        Action = action or "CreateSession",
        Data = data and json.encode(data) or nil
        -- Deliberately omit From field
    }
end

-- Test functions
local function testUserRoleDetection(authManager)
    print("  🧪 Testing user role detection...")
    
    -- Test admin role detection
    local adminRole = authManager.getUserRole("admin_wallet_12345678901234567890123")
    assert(adminRole == "admin", "Admin wallet should have admin role")
    
    -- Test player role detection
    local playerRole = authManager.getUserRole("player_wallet_12345678901234567890123")
    assert(playerRole == "player", "Regular wallet should have player role")
    
    print("    ✅ User role detection tests passed")
end

local function testSessionManagement(authManager)
    print("  🧪 Testing session management...")
    
    local walletAddress = "test_wallet_12345678901234567890123"
    local permissions = {"player"}
    
    -- Test session creation
    local session = authManager.createSession(walletAddress, permissions)
    assert(session ~= nil, "Session should be created")
    assert(session.walletAddress == walletAddress, "Session should have correct wallet address")
    assert(session.isActive == true, "Session should be active")
    assert(session.id ~= nil, "Session should have ID")
    
    -- Test session retrieval
    local retrievedSession, err = authManager.getSession(session.id)
    assert(retrievedSession ~= nil, "Session should be retrievable")
    assert(err == nil, "No error should occur when retrieving valid session")
    assert(retrievedSession.walletAddress == walletAddress, "Retrieved session should match")
    
    -- Test session invalidation
    local invalidated = authManager.invalidateSession(session.id)
    assert(invalidated == true, "Session should be invalidated successfully")
    
    -- Test accessing invalidated session
    local invalidSession, invalidErr = authManager.getSession(session.id)
    assert(invalidSession == nil, "Invalidated session should not be accessible")
    assert(invalidErr == "Session not found", "Should get session not found error")
    
    print("    ✅ Session management tests passed")
end

local function testPlayerOwnership(authManager)
    print("  🧪 Testing player ownership validation...")
    
    local walletAddress = "owner_wallet_12345678901234567890123"
    local gameDataId = "gamedata_12345"
    
    -- Test ownership registration
    local registered = authManager.registerPlayerOwnership(walletAddress, gameDataId)
    assert(registered == true, "Ownership should be registered successfully")
    
    -- Test ownership validation
    local ownsData, err = authManager.validateOwnership(walletAddress, gameDataId)
    assert(ownsData == true, "Player should own the registered data")
    assert(err == nil, "No error should occur for valid ownership")
    
    -- Test ownership validation for different wallet
    local differentWallet = "different_wallet_12345678901234567890123"
    local doesNotOwn, ownershipErr = authManager.validateOwnership(differentWallet, gameDataId)
    assert(doesNotOwn == false, "Different wallet should not own the data")
    assert(ownershipErr ~= nil, "Should get ownership error")
    
    -- Test ownership validation for non-existent data
    local noData, noDataErr = authManager.validateOwnership(walletAddress, "nonexistent_data")
    assert(noData == false, "Should not own non-existent data")
    assert(noDataErr ~= nil, "Should get error for non-existent data")
    
    print("    ✅ Player ownership validation tests passed")
end

local function testOperationPermissions(authManager)
    print("  🧪 Testing operation permissions...")
    
    local playerWallet = "player_wallet_12345678901234567890123"
    local adminWallet = "admin_wallet_12345678901234567890123"
    
    -- Test player permissions
    local playerCanUpdate, playerErr = authManager.checkOperationPermission(playerWallet, "UpdateGameState")
    assert(playerCanUpdate == true, "Player should be able to update game state")
    assert(playerErr == nil, "No error for valid player operation")
    
    local playerCannotAdmin, adminErr = authManager.checkOperationPermission(playerWallet, "AdminReset")
    assert(playerCannotAdmin == false, "Player should not have admin permissions")
    assert(adminErr ~= nil, "Should get permission error")
    
    -- Test admin permissions
    local adminCanUpdate, adminUpdateErr = authManager.checkOperationPermission(adminWallet, "UpdateGameState")
    assert(adminCanUpdate == true, "Admin should be able to update game state")
    
    local adminCanAdmin, adminAdminErr = authManager.checkOperationPermission(adminWallet, "AdminReset")
    assert(adminCanAdmin == true, "Admin should have admin permissions")
    assert(adminAdminErr == nil, "No error for valid admin operation")
    
    -- Test public operations
    local publicAccess, publicErr = authManager.checkOperationPermission(playerWallet, "GetLeaderboard")
    assert(publicAccess == true, "Anyone should access public operations")
    
    -- Test unknown operation
    local unknownOp, unknownErr = authManager.checkOperationPermission(playerWallet, "UnknownOperation")
    assert(unknownOp == false, "Unknown operation should be denied")
    assert(string.find(unknownErr, "Unknown operation"), "Should get unknown operation error")
    
    print("    ✅ Operation permissions tests passed")
end

local function testAOMessageAuthentication(authManager)
    print("  🧪 Testing AO message authentication...")
    
    local walletAddress = "ao_wallet_12345678901234567890123"
    
    -- Test valid AO message
    local validMsg = createValidAOMessage(walletAddress, "CreateSession")
    local authResult = authManager.authenticateMessage(validMsg)
    
    assert(authResult.isAuthenticated == true, "Valid AO message should be authenticated")
    assert(authResult.walletAddress == walletAddress, "Should extract correct wallet address")
    assert(authResult.sessionId ~= nil, "Should create session")
    assert(#authResult.permissions > 0, "Should assign permissions")
    assert(#authResult.errors == 0, "Should have no errors")
    
    -- Test message without sender
    local noSenderMsg = createMessageWithoutSender("CreateSession")
    authResult = authManager.authenticateMessage(noSenderMsg)
    assert(authResult.isAuthenticated == false, "Message without sender should fail")
    assert(#authResult.errors > 0, "Should have authentication errors")
    
    -- Test message with invalid wallet format
    local invalidWalletMsg = createValidAOMessage("short", "CreateSession")
    authResult = authManager.authenticateMessage(invalidWalletMsg)
    assert(authResult.isAuthenticated == false, "Invalid wallet format should fail")
    
    -- Test message with existing session
    local sessionData = {sessionId = authResult.sessionId}
    local sessionMsg = createValidAOMessage(walletAddress, "CreateSession", sessionData)
    local sessionAuthResult = authManager.authenticateMessage(sessionMsg)
    -- Note: This test depends on previous session creation
    
    print("    ✅ AO message authentication tests passed")
end

local function testAuthorizationWorkflow(authManager)
    print("  🧪 Testing authorization workflow...")
    
    local playerWallet = "player_wallet_12345678901234567890123"
    local gameDataId = "player_game_data_12345"
    
    -- Register ownership first
    authManager.registerPlayerOwnership(playerWallet, gameDataId)
    
    -- Test complete authorization workflow
    local playerMsg = createValidAOMessage(playerWallet, "CreateSession")
    local authResult = authManager.authenticateAndAuthorize(playerMsg, "UpdateGameState", gameDataId)
    
    assert(authResult.success == true, "Player should be authorized for their own data")
    assert(authResult.walletAddress == playerWallet, "Should return correct wallet address")
    
    -- Test authorization without ownership
    local differentData = "different_game_data_12345"
    authResult = authManager.authenticateAndAuthorize(playerMsg, "UpdateGameState", differentData)
    assert(authResult.success == false, "Player should not be authorized for data they don't own")
    assert(authResult.error ~= nil, "Should provide authorization error")
    
    -- Test admin override
    local adminWallet = "admin_wallet_12345678901234567890123"
    local adminMsg = createValidAOMessage(adminWallet, "CreateSession")
    authResult = authManager.authenticateAndAuthorize(adminMsg, "UpdateGameState", differentData)
    assert(authResult.success == true, "Admin should be authorized for any data")
    
    -- Test public operation
    authResult = authManager.authenticateAndAuthorize(playerMsg, "GetLeaderboard", nil)
    assert(authResult.success == true, "Anyone should be authorized for public operations")
    
    print("    ✅ Authorization workflow tests passed")
end

local function testAuditLogging(authManager)
    print("  🧪 Testing audit logging...")
    
    local initialLogCount = #authManager.authAuditLog
    
    local walletAddress = "audit_wallet_12345678901234567890123"
    local msg = createValidAOMessage(walletAddress, "CreateSession")
    
    -- Perform operation that should generate audit logs
    local authResult = authManager.authenticateAndAuthorize(msg, "UpdateGameState", "test_data")
    
    -- Check that audit logs were created
    local finalLogCount = #authManager.authAuditLog
    assert(finalLogCount > initialLogCount, "Audit logs should be created")
    
    -- Check audit log content
    local latestLog = authManager.authAuditLog[finalLogCount]
    assert(latestLog.walletAddress == walletAddress, "Audit log should record wallet address")
    assert(latestLog.operation == "UpdateGameState", "Audit log should record operation")
    assert(latestLog.timestamp ~= nil, "Audit log should have timestamp")
    
    print("    ✅ Audit logging tests passed")
end

local function testSessionExpiry(authManager)
    print("  🧪 Testing session expiry...")
    
    local walletAddress = "expiry_wallet_12345678901234567890123"
    local session = authManager.createSession(walletAddress, {"player"})
    
    -- Manually set session to expired state for testing
    session.lastActivity = 1234567890 - 4000 -- 4000 seconds ago (expired)
    
    local expiredSession, err = authManager.getSession(session.id)
    assert(expiredSession == nil, "Expired session should not be accessible")
    assert(err == "Session expired", "Should get session expired error")
    
    print("    ✅ Session expiry tests passed")
end

local function testEdgeCases(authManager)
    print("  🧪 Testing edge cases...")
    
    -- Test session with invalid ID
    local invalidSession, err = authManager.getSession("invalid_session_id")
    assert(invalidSession == nil, "Invalid session should return nil")
    assert(err == "Session not found", "Should get session not found error")
    
    -- Test invalidating non-existent session
    local invalidated = authManager.invalidateSession("nonexistent_session")
    assert(invalidated == false, "Should return false for non-existent session")
    
    -- Test ownership with nil parameters
    local nilOwnership, nilErr = authManager.validateOwnership(nil, "data")
    assert(nilOwnership == false, "Nil wallet should not own data")
    
    print("    ✅ Edge case tests passed")
end

local function testPerformance(authManager)
    print("  🧪 Testing authentication performance...")
    
    local walletAddress = "perf_wallet_12345678901234567890123"
    
    -- Test bulk session creation and validation
    local startTime = os.clock()
    local sessions = {}
    
    for i = 1, 100 do
        local msg = createValidAOMessage(walletAddress .. "_" .. i, "CreateSession")
        local authResult = authManager.authenticateMessage(msg)
        table.insert(sessions, authResult.sessionId)
    end
    
    -- Test bulk authorization
    for i = 1, 100 do
        local msg = createValidAOMessage(walletAddress .. "_" .. i, "CreateSession")
        local authResult = authManager.authenticateAndAuthorize(msg, "GetLeaderboard", nil)
        assert(authResult.success == true, "Bulk authorization should succeed")
    end
    
    local endTime = os.clock()
    local duration = endTime - startTime
    
    assert(duration < 0.5, "100 auth operations should complete within 500ms (actual: " .. duration .. "s)")
    
    print("    ✅ Performance tests passed - 200 operations completed in " .. string.format("%.3f", duration) .. "s")
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
        id = "test_auth_manager"
    }
    _G.Handlers = {
        add = function(name, matcher, handler) end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg) return true end
            end
        }
    }
    
    -- Load the auth manager
    dofile("processes/security/auth-manager.lua")
    local authManager = _G.AuthManager
    
    print("🚀 Authentication Manager Test Suite")
    print("="..string.rep("=", 50))
    
    testUserRoleDetection(authManager)
    testSessionManagement(authManager)
    testPlayerOwnership(authManager)
    testOperationPermissions(authManager)
    testAOMessageAuthentication(authManager)
    testAuthorizationWorkflow(authManager)
    testAuditLogging(authManager)
    testSessionExpiry(authManager)
    testEdgeCases(authManager)
    testPerformance(authManager)
    
    print("="..string.rep("=", 50))
    print("🎉 All Authentication Manager tests passed!")
    return true
end

-- Export test runner
return {
    runAllTests = runAllTests
}