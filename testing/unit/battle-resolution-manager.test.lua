-- Battle Resolution Manager Unit Tests (Aolite)
-- Comprehensive testing using aolite framework for AO process validation

local aolite = require("aolite")
local json = require("json")

-- Test utilities
local function createMockBattleData(playerAlive, enemyAlive)
    local playerParty = {}
    local enemyParty = {}
    
    -- Create player party
    for i = 1, 2 do
        table.insert(playerParty, {
            id = "player_" .. i,
            speciesId = 25, -- Pikachu
            level = 20,
            hp = playerAlive and 80 or 0,
            maxHp = 100,
            status = playerAlive and nil or "faint",
            exp = 2000
        })
    end
    
    -- Create enemy party  
    for i = 1, 2 do
        table.insert(enemyParty, {
            id = "enemy_" .. i,
            speciesId = 1, -- Bulbasaur
            level = 18,
            hp = enemyAlive and 60 or 0,
            maxHp = 80,
            status = enemyAlive and nil or "faint",
            defeated = not enemyAlive
        })
    end
    
    return playerParty, enemyParty
end

-- Set up AO global mocks for isolated testing
_G.Handlers = {
    _handlers = {},
    add = function(name, matcher, handler)
        _G.Handlers._handlers[name] = { name = name, matcher = matcher, handler = handler }
        print("Handler registered:", name)
    end,
    utils = {
        hasMatchingTag = function(tagName, tagValue)
            return function(msg)
                return msg.Tags and msg.Tags[tagName] == tagValue
            end
        end
    }
}

-- Mock JSON utilities
_G.json = {
    encode = function(obj)
        if type(obj) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(obj) do
                if not first then result = result .. "," end
                first = false
                if type(v) == "table" then
                    result = result .. '"' .. tostring(k) .. '":' .. _G.json.encode(v)
                elseif type(v) == "string" then
                    result = result .. '"' .. tostring(k) .. '":"' .. v .. '"'
                else
                    result = result .. '"' .. tostring(k) .. '":' .. tostring(v)
                end
            end
            return result .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj .. '"'
        else
            return tostring(obj)
        end
    end,
    decode = function(str)
        -- Simple JSON decode mock for testing
        if type(str) == "string" and string.find(str, "playerParty") then
            return {
                {id = "player_1", hp = 80, maxHp = 100},
                {id = "player_2", hp = 80, maxHp = 100}
            }
        elseif type(str) == "string" and string.find(str, "enemyParty") then
            return {
                {id = "enemy_1", hp = 0, maxHp = 80},
                {id = "enemy_2", hp = 0, maxHp = 80}
            }
        else
            return {mock_decoded = str}
        end
    end
}

_G.ao = {
    id = "test-battle-resolution-process",
    send = function(params) 
        print("Mock ao.send:", json.encode(params))
        return params 
    end,
    env = {
        Process = {
            Owner = "test-owner"
        }
    }
}

-- Load the battle resolution manager process
dofile("processes/battle-resolution-manager.lua")

-- Test functions
local function test_info_handler()
    print("Testing Info handler...")
    
    local infoMessage = {
        From = "test-sender",
        Action = "Info",
        Tags = { Action = "Info" }
    }

    -- Find and execute the info handler
    local handler = _G.Handlers._handlers["info"]
    if not handler then
        print("❌ Info handler not found")
        return false
    end

    local success, result = pcall(handler.handler, infoMessage)
    if success then
        print("✓ Info handler test passed")
        return true
    else
        print("❌ Info handler test failed:", result)
        return false
    end
end

local function test_detect_battle_outcome_victory()
    print("Testing DetectBattleOutcome victory...")
    
    local playerParty, enemyParty = createMockBattleData(true, false) -- Player alive, enemy fainted
    
    local battleMessage = {
        From = "test-sender",
        Action = "DetectBattleOutcome",
        Tags = {
            Action = "DetectBattleOutcome",
            BattleId = "test_001",
            PlayerParty = json.encode(playerParty),
            EnemyParty = json.encode(enemyParty)
        },
        Timestamp = 1234567890
    }

    local handler = _G.Handlers._handlers["detect-battle-outcome"]
    if not handler then
        print("❌ DetectBattleOutcome handler not found")
        return false
    end

    local success, result = pcall(handler.handler, battleMessage)
    if success then
        print("✓ DetectBattleOutcome victory test passed")
        return true
    else
        print("❌ DetectBattleOutcome victory test failed:", result)
        return false
    end
end

local function test_detect_battle_outcome_defeat()
    print("Testing DetectBattleOutcome defeat...")
    
    local playerParty, enemyParty = createMockBattleData(false, true) -- Player fainted, enemy alive
    
    local battleMessage = {
        From = "test-sender",
        Action = "DetectBattleOutcome",
        Tags = {
            Action = "DetectBattleOutcome",
            BattleId = "test_002",
            PlayerParty = json.encode(playerParty),
            EnemyParty = json.encode(enemyParty)
        },
        Timestamp = 1234567890
    }

    local handler = _G.Handlers._handlers["detect-battle-outcome"]
    if not handler then
        print("❌ DetectBattleOutcome handler not found")
        return false
    end

    local success, result = pcall(handler.handler, battleMessage)
    if success then
        print("✓ DetectBattleOutcome defeat test passed")
        return true
    else
        print("❌ DetectBattleOutcome defeat test failed:", result)
        return false
    end
end

local function test_ping_handler()
    print("Testing Ping handler...")
    
    local pingMessage = {
        From = "test-sender",
        Action = "Ping",
        Tags = { Action = "Ping" }
    }

    local handler = _G.Handlers._handlers["ping"]
    if not handler then
        print("❌ Ping handler not found")
        return false
    end

    local success, result = pcall(handler.handler, pingMessage)
    if success then
        print("✓ Ping handler test passed")
        return true
    else
        print("❌ Ping handler test failed:", result)
        return false
    end
end

-- Run tests with aolite
local function runAoliteTests()
    print("🧪 Running Battle Resolution Manager Aolite Tests")
    print(string.rep("=", 60))
    
    local tests = {
        test_info_handler,
        test_detect_battle_outcome_victory,
        test_detect_battle_outcome_defeat,
        test_ping_handler
    }
    
    local passed = 0
    local total = #tests
    
    for _, testFunc in ipairs(tests) do
        local success = testFunc()
        if success then
            passed = passed + 1
        end
    end
    
    print(string.rep("=", 60))
    print(string.format("📊 Test Results: %d/%d passed", passed, total))
    
    if passed == total then
        print("✅ All tests passed!")
        return true
    else
        print("❌ Some tests failed!")
        return false
    end
end

-- Execute if run directly
if arg and arg[0] then
    runAoliteTests()
end

return {
    runAoliteTests = runAoliteTests,
    createMockBattleData = createMockBattleData
}