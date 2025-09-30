-- Unit Tests for Tera Crystal Resource Engine
-- Tests drop rate calculations, type generation algorithms, and usage tracking

-- Simple JSON implementation for testing
local json = {
    encode = function(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            return type(obj) == "string" and '"' .. obj .. '"' or tostring(obj)
        end
    end,
    decode = function(str)
        -- Simple decode for basic testing
        if str == "{}" then return {} end
        if str:match('^%[.*%]$') then
            local result = {}
            for item in str:gmatch('"([^"]*)"') do
                table.insert(result, item)
            end
            return result
        end
        return {}
    end
}

-- Mock AO environment for testing
local function setupTestEnvironment()
    -- Make json global for AO process
    _G.json = json
    
    if not ao then
        ao = {
            send = function(msg) 
                lastSentMessage = msg
                print("Mock ao.send:", json.encode(msg))
            end,
            id = "test_tera_crystal_process_id"
        }
    end
    
    if not Handlers then
        Handlers = {
            add = function(name, matcher, handler)
                registeredHandlers = registeredHandlers or {}
                registeredHandlers[name] = {
                    matcher = matcher,
                    handler = handler
                }
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
    end
    
    -- Reset global state
    State = nil
    lastSentMessage = nil
    registeredHandlers = {}
end

-- Test utilities
local function createTestMessage(action, tags, data)
    local msg = {
        From = "test_player_1",
        Tags = tags or {},
        Data = data,
        Timestamp = tostring(os.time())
    }
    -- Add Action to Tags for AO pattern matching
    msg.Tags.Action = action
    return msg
end

local function callHandler(handlerName, msg)
    if registeredHandlers and registeredHandlers[handlerName] then
        local handler = registeredHandlers[handlerName].handler
        handler(msg)
        return lastSentMessage
    else
        error("Handler not found: " .. handlerName)
    end
end

-- ============================================================================
-- UNIT TESTS
-- ============================================================================

print("=== TERA CRYSTAL RESOURCE ENGINE UNIT TESTS ===")

-- Setup test environment
setupTestEnvironment()

-- Load the process code
dofile("processes/tera-crystal-engine.lua")

-- Test 1: Drop Rate Calculation Algorithm
print("\n--- Test 1: Tera Orb Drop Rate Calculation ---")

local testCases = {
    {wave = 1, expected = 1},      -- Math.max(Math.floor(1/50)*2, 1) = 1
    {wave = 25, expected = 1},     -- Math.max(Math.floor(25/50)*2, 1) = 1  
    {wave = 49, expected = 1},     -- Math.max(Math.floor(49/50)*2, 1) = 1
    {wave = 50, expected = 2},     -- Math.max(Math.floor(50/50)*2, 1) = 2
    {wave = 75, expected = 2},     -- Math.max(Math.floor(75/50)*2, 1) = 2
    {wave = 100, expected = 4},    -- Math.min(Math.max(Math.floor(100/50)*2, 1), 4) = 4
    {wave = 150, expected = 4},    -- Math.min(Math.max(Math.floor(150/50)*2, 1), 4) = 4
    {wave = 200, expected = 4}     -- Math.min(Math.max(Math.floor(200/50)*2, 1), 4) = 4 (capped)
}

for i, testCase in ipairs(testCases) do
    local msg = createTestMessage("GenerateTeraCrystal", {
        WaveIndex = tostring(testCase.wave),
        GameMode = "CLASSIC",
        CrystalType = "orb",
        Guaranteed = "true"  -- Force generation for weight testing
    })
    
    local response = callHandler("generate-tera-crystal", msg)
    
    if response and response.DropWeight then
        local actualWeight = tonumber(response.DropWeight)
        if actualWeight == testCase.expected then
            print(string.format("✓ Wave %d: Expected %d, Got %d", testCase.wave, testCase.expected, actualWeight))
        else
            print(string.format("✗ Wave %d: Expected %d, Got %d", testCase.wave, testCase.expected, actualWeight))
        end
    else
        print(string.format("✗ Wave %d: No DropWeight in response", testCase.wave))
    end
end

-- Test 2: Classic Mode Wave Restriction
print("\n--- Test 2: Classic Mode Wave Restriction ---")

-- Test wave 25 in Classic mode (should be blocked)
local msg = createTestMessage("GenerateTeraCrystal", {
    WaveIndex = "25",
    GameMode = "CLASSIC", 
    CrystalType = "orb"
})

local response = callHandler("generate-tera-crystal", msg)

if response and response.Success == "false" and response.Reason and 
   string.find(response.Reason, "Wave too early") then
    print("✓ Classic mode wave restriction working correctly")
else
    print("✗ Classic mode wave restriction failed")
    print("Response:", json.encode(response))
end

-- Test wave 50 in Classic mode (should be allowed)
msg = createTestMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC",
    CrystalType = "orb",
    Guaranteed = "true"
})

response = callHandler("generate-tera-crystal", msg)

if response and response.Success == "true" then
    print("✓ Wave 50+ Classic mode generation working correctly")
else
    print("✗ Wave 50+ Classic mode generation failed")
    print("Response:", json.encode(response))
end

-- Test 3: Tera Shard Type Generation
print("\n--- Test 3: Tera Shard Type Generation ---")

-- First, give player a Tera Orb
local msg = createTestMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC",
    CrystalType = "orb",
    Guaranteed = "true"
})

callHandler("generate-tera-crystal", msg)

-- Now test Tera Shard generation
msg = createTestMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC", 
    CrystalType = "shard"
})

response = callHandler("generate-tera-crystal", msg)

if response and response.Success == "true" and response.TeraType then
    -- Validate it's a valid type
    local validTypes = {
        "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE",
        "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", 
        "BUG", "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY", "STELLAR"
    }
    
    local isValid = false
    for _, validType in ipairs(validTypes) do
        if response.TeraType == validType then
            isValid = true
            break
        end
    end
    
    if isValid then
        print("✓ Tera Shard generation successful: " .. response.TeraType)
    else
        print("✗ Invalid Tera type generated: " .. response.TeraType)
    end
else
    print("✗ Tera Shard generation failed")
    print("Response:", json.encode(response))
end

-- Test 4: Party Type Exclusion Logic
print("\n--- Test 4: Party Type Exclusion Logic ---")

-- Test with uniform party (all FIRE types)
local uniformParty = {"FIRE", "FIRE", "FIRE", "FIRE", "FIRE", "FIRE"}

msg = createTestMessage("GenerateTeraCrystal", {
    WaveIndex = "50",
    GameMode = "CLASSIC",
    CrystalType = "shard",
    PartyTeraTypes = json.encode(uniformParty)
})

response = callHandler("generate-tera-crystal", msg)

if response and response.Success == "true" and response.TeraType ~= "FIRE" then
    print("✓ Party exclusion logic working: Generated " .. response.TeraType .. " (excluded FIRE)")
else
    print("✗ Party exclusion logic failed")
    print("Response:", json.encode(response))
end

-- Test 5: Tera Shard Application
print("\n--- Test 5: Tera Shard Application ---")

msg = createTestMessage("ApplyTeraShard", {
    PokemonId = "pikachu_001",
    TeraType = "WATER"
})

response = callHandler("apply-tera-shard", msg)

if response and response.Success == "true" and 
   response.PokemonId == "pikachu_001" and response.TeraType == "WATER" then
    print("✓ Tera Shard application successful")
else
    print("✗ Tera Shard application failed")
    print("Response:", json.encode(response))
end

-- Test 6: Invalid Tera Type Validation
print("\n--- Test 6: Invalid Tera Type Validation ---")

msg = createTestMessage("ApplyTeraShard", {
    PokemonId = "pikachu_001", 
    TeraType = "INVALID_TYPE"
})

response = callHandler("apply-tera-shard", msg)

if response and response.Action == "Error" and string.find(response.Error, "Invalid TeraType") then
    print("✓ Invalid Tera type validation working")
else
    print("✗ Invalid Tera type validation failed")
    print("Response:", json.encode(response))
end

-- Test 7: Terastallization Eligibility Check
print("\n--- Test 7: Terastallization Eligibility Check ---")

msg = createTestMessage("CheckTeraEligibility", {
    PokemonId = "pikachu_001",
    BattleId = "battle_001"
})

response = callHandler("check-tera-eligibility", msg)

if response and response.Success == "true" and response.Eligible == "true" then
    print("✓ Terastallization eligibility check passed")
else
    print("✗ Terastallization eligibility check failed")
    print("Response:", json.encode(response))
end

-- Test 8: Battle Usage Tracking
print("\n--- Test 8: Battle Usage Tracking ---")

-- Use Terastallization once
msg = createTestMessage("UseTerastallization", {
    PokemonId = "pikachu_001",
    BattleId = "battle_001"
})

response = callHandler("use-terastallization", msg)

if response and response.Success == "true" and response.TerasUsed == "1" then
    print("✓ First Terastallization usage tracked")
else
    print("✗ First Terastallization usage tracking failed")
    print("Response:", json.encode(response))
end

-- Try to use again (should fail)
response = callHandler("use-terastallization", msg)

if response and response.Action == "Error" and string.find(response.Error, "Already used") then
    print("✓ Per-battle usage limitation working")
else
    print("✗ Per-battle usage limitation failed")
    print("Response:", json.encode(response))
end

-- Test 9: Battle Usage Reset
print("\n--- Test 9: Battle Usage Reset ---")

msg = createTestMessage("ResetBattleUsage", {
    BattleId = "battle_002"
})

response = callHandler("reset-battle-usage", msg)

if response and response.Success == "true" and response.TerasUsed == "0" then
    print("✓ Battle usage reset successful")
else
    print("✗ Battle usage reset failed")
    print("Response:", json.encode(response))
end

-- Verify can use Terastallization again after reset
msg = createTestMessage("UseTerastallization", {
    PokemonId = "pikachu_001",
    BattleId = "battle_002"
})

response = callHandler("use-terastallization", msg)

if response and response.Success == "true" then
    print("✓ Terastallization available after battle reset")
else
    print("✗ Terastallization not available after battle reset")
    print("Response:", json.encode(response))
end

-- Test 10: Player State Retrieval
print("\n--- Test 10: Player State Retrieval ---")

msg = createTestMessage("GetTeraState", {})

response = callHandler("get-tera-state", msg)

if response and response.Success == "true" and response.Data then
    local stateData = json.decode(response.Data)
    if stateData and stateData.hasTeraOrb and stateData.pokemonTeraTypes then
        print("✓ Player state retrieval successful")
        print("  - Has Tera Orb:", stateData.hasTeraOrb)
        print("  - Pokemon Tera Types:", json.encode(stateData.pokemonTeraTypes))
        print("  - Battle Usage:", json.encode(stateData.battleUsage))
    else
        print("✗ Player state data incomplete")
    end
else
    print("✗ Player state retrieval failed")
    print("Response:", json.encode(response))
end

-- Test 11: ADP v1.0 Info Handler
print("\n--- Test 11: ADP v1.0 Info Handler ---")

msg = createTestMessage("Info", {})

response = callHandler("info", msg)

if response and response.Action == "InfoResponse" and response.Data then
    local infoData = json.decode(response.Data)
    if infoData and infoData.process and infoData.handlers and 
       infoData.process.adpVersion == "1.0" then
        print("✓ ADP v1.0 Info handler working")
        print("  - Process:", infoData.process.name)
        print("  - Version:", infoData.process.version)
        print("  - Handlers:", #infoData.handlers)
        print("  - Capabilities:", json.encode(infoData.process.capabilities))
    else
        print("✗ ADP v1.0 Info response incomplete")
    end
else
    print("✗ ADP v1.0 Info handler failed")
    print("Response:", json.encode(response))
end

-- Test 12: Ping Handler
print("\n--- Test 12: Ping Handler ---")

msg = createTestMessage("Ping", {})

response = callHandler("ping", msg)

if response and response.Action == "Pong" and response.Data then
    print("✓ Ping handler working: " .. response.Data)
else
    print("✗ Ping handler failed")
    print("Response:", json.encode(response))
end

print("\n=== TERA CRYSTAL RESOURCE ENGINE UNIT TESTS COMPLETE ===")
print("Run with: npm run test:aolite")