-- Unit Tests for Environmental Cycle Engine
-- Tests time-of-day calculation, pool updates, species forms, tints, transitions

local aolite = require("aolite")
local json = require("json")

-- Test state
local processId = nil
local testMessages = {}
local assertionCount = 0
local failedAssertions = 0

-- Helper to send message and capture response
local function sendMessage(action, tags, data)
    local msg = {
        Action = action,
        From = "test_sender",
        Timestamp = os.time() * 1000
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    if data then
        msg.Data = type(data) == "table" and json.encode(data) or data
    end

    local result = aolite.send(processId, msg)
    table.insert(testMessages, result)
    return result
end

-- Helper: Assert equals
local function assertEquals(actual, expected, message)
    assertionCount = assertionCount + 1
    if actual ~= expected then
        failedAssertions = failedAssertions + 1
        print("  ✗ FAIL: " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual: " .. tostring(actual))
        return false
    else
        print("  ✓ PASS: " .. message)
        return true
    end
end

-- Setup: Load process
print("Setting up Environmental Cycle Engine tests...")
processId = aolite.spawn("environmental-cycle-engine", "../processes/environmental-cycle-engine.lua")

if not processId then
    error("Failed to spawn environmental-cycle-engine process")
end

print("Process spawned with ID: " .. processId)

-- ============================================================================
-- TEST SUITE 1: Time of Day Calculation (40-wave cycle)
-- ============================================================================

print("\n=== TEST SUITE 1: Time of Day Calculation ===")

local function testTimeOfDayCalculation()
    print("Test 1.1: Wave 0-14 returns DAY (TimeOfDay.DAY = 1)")
    local result = sendMessage("GetTimeOfDay", {Wave = "5", Biome = "1"})
    assertEquals(result.TimeOfDay, "1", "Wave 5 should be DAY")
    assertEquals(result.WaveCycle, "5", "Wave cycle should be 5")

    print("Test 1.2: Wave 15-19 returns DUSK (TimeOfDay.DUSK = 2)")
    result = sendMessage("GetTimeOfDay", {Wave = "17", Biome = "1"})
    assertEquals(result.TimeOfDay, "2", "Wave 17 should be DUSK")
    assertEquals(result.WaveCycle, "17", "Wave cycle should be 17")

    print("Test 1.3: Wave 20-34 returns NIGHT (TimeOfDay.NIGHT = 3)")
    result = sendMessage("GetTimeOfDay", {Wave = "25", Biome = "1"})
    assertEquals(result.TimeOfDay, "3", "Wave 25 should be NIGHT")
    assertEquals(result.WaveCycle, "25", "Wave cycle should be 25")

    print("Test 1.4: Wave 35-39 returns DAWN (TimeOfDay.DAWN = 0)")
    result = sendMessage("GetTimeOfDay", {Wave = "37", Biome = "1"})
    assertEquals(result.TimeOfDay, "0", "Wave 37 should be DAWN")
    assertEquals(result.WaveCycle, "37", "Wave cycle should be 37")

    print("Test 1.5: Wave 40 cycles back to DAY")
    result = sendMessage("GetTimeOfDay", {Wave = "40", Biome = "1"})
    assertEquals(result.TimeOfDay, "1", "Wave 40 should be DAY (cycle 0)")
    assertEquals(result.WaveCycle, "0", "Wave cycle should be 0")

    print("Test 1.6: Wave 14 boundary (last DAY wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "14", Biome = "1"})
    assertEquals(result.TimeOfDay, "1", "Wave 14 should be DAY")

    print("Test 1.7: Wave 15 boundary (first DUSK wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "15", Biome = "1"})
    assertEquals(result.TimeOfDay, "2", "Wave 15 should be DUSK")

    print("Test 1.8: Wave 19 boundary (last DUSK wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "19", Biome = "1"})
    assertEquals(result.TimeOfDay, "2", "Wave 19 should be DUSK")

    print("Test 1.9: Wave 20 boundary (first NIGHT wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "20", Biome = "1"})
    assertEquals(result.TimeOfDay, "3", "Wave 20 should be NIGHT")

    print("Test 1.10: Wave 34 boundary (last NIGHT wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "34", Biome = "1"})
    assertEquals(result.TimeOfDay, "3", "Wave 34 should be NIGHT")

    print("Test 1.11: Wave 35 boundary (first DAWN wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "35", Biome = "1"})
    assertEquals(result.TimeOfDay, "0", "Wave 35 should be DAWN")

    print("Test 1.12: Wave 39 boundary (last DAWN wave)")
    result = sendMessage("GetTimeOfDay", {Wave = "39", Biome = "1"})
    assertEquals(result.TimeOfDay, "0", "Wave 39 should be DAWN")
end

local function testWaveCycleOffset()
    print("Test 1.13: Wave cycle offset shifts time of day")
    local result = sendMessage("GetTimeOfDay", {Wave = "10", Biome = "1", WaveCycleOffset = "10"})
    assertEquals(result.TimeOfDay, "2", "Wave 10 + offset 10 = cycle 20 (NIGHT)")
    assertEquals(result.WaveCycle, "20", "Wave cycle should be 20")

    print("Test 1.14: Wave cycle offset wraps around")
    result = sendMessage("GetTimeOfDay", {Wave = "35", Biome = "1", WaveCycleOffset = "10"})
    assertEquals(result.TimeOfDay, "1", "Wave 35 + offset 10 = cycle 5 (DAY)")
    assertEquals(result.WaveCycle, "5", "Wave cycle should be 5")
end

local function testBiomeOverrides()
    print("Test 1.15: ABYSS biome always returns NIGHT")
    local result = sendMessage("GetTimeOfDay", {Wave = "5", Biome = "24"})  -- BiomeId.ABYSS = 24
    assertEquals(result.TimeOfDay, "3", "ABYSS at wave 5 should be NIGHT")

    print("Test 1.16: ABYSS biome overrides DAWN")
    result = sendMessage("GetTimeOfDay", {Wave = "37", Biome = "24"})
    assertEquals(result.TimeOfDay, "3", "ABYSS at wave 37 should be NIGHT")
end

testTimeOfDayCalculation()
testWaveCycleOffset()
testBiomeOverrides()

-- ============================================================================
-- TEST SUITE 2: Species Form Resolution
-- ============================================================================

print("\n=== TEST SUITE 2: Species Form Resolution ===")

local function testLycanrocForms()
    print("Test 2.1: Lycanroc Midday form (DAY)")
    local result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "1"})
    local data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[745]), "0", "Lycanroc should be form 0 (Midday) during DAY")

    print("Test 2.2: Lycanroc Dusk form (DUSK)")
    result = sendMessage("GetEnvironmentalState", {Wave = "17", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[745]), "2", "Lycanroc should be form 2 (Dusk) during DUSK")

    print("Test 2.3: Lycanroc Midnight form (NIGHT)")
    result = sendMessage("GetEnvironmentalState", {Wave = "25", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[745]), "1", "Lycanroc should be form 1 (Midnight) during NIGHT")

    print("Test 2.4: Lycanroc Midday form (DAWN)")
    result = sendMessage("GetEnvironmentalState", {Wave = "37", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[745]), "0", "Lycanroc should be form 0 (Midday) during DAWN")
end

local function testBiomeForms()
    print("Test 2.5: Burmy Plant Cloak (default)")
    local result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "1"})  -- PLAINS
    local data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[412]), "0", "Burmy should be form 0 (Plant) in PLAINS")

    print("Test 2.6: Burmy Sandy Cloak (BEACH)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "8"})  -- BiomeId.BEACH = 8
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[412]), "1", "Burmy should be form 1 (Sandy) at BEACH")

    print("Test 2.7: Burmy Trash Cloak (SLUM)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "30"})  -- BiomeId.SLUM = 30
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[412]), "2", "Burmy should be form 2 (Trash) in SLUM")

    print("Test 2.8: Rotom base form (default)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[479]), "0", "Rotom should be form 0 (base) in PLAINS")

    print("Test 2.9: Rotom Heat form (VOLCANO)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "18"})  -- BiomeId.VOLCANO = 18
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[479]), "1", "Rotom should be form 1 (Heat) in VOLCANO")

    print("Test 2.10: Rotom Wash form (SEA)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "6"})  -- BiomeId.SEA = 6
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[479]), "2", "Rotom should be form 2 (Wash) at SEA")

    print("Test 2.11: Rotom Frost form (ICE_CAVE)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "15"})  -- BiomeId.ICE_CAVE = 15
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[479]), "3", "Rotom should be form 3 (Frost) in ICE_CAVE")

    print("Test 2.12: Rotom Fan form (MOUNTAIN)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "11"})  -- BiomeId.MOUNTAIN = 11
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[479]), "4", "Rotom should be form 4 (Fan) at MOUNTAIN")

    print("Test 2.13: Rotom Mow form (TALL_GRASS)")
    result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "3"})  -- BiomeId.TALL_GRASS = 3
    data = json.decode(result.Data)
    assertEquals(tostring(data.formIndices[479]), "5", "Rotom should be form 5 (Mow) in TALL_GRASS")
end

testLycanrocForms()
testBiomeForms()

-- ============================================================================
-- TEST SUITE 3: Visual Tint Calculation
-- ============================================================================

print("\n=== TEST SUITE 3: Visual Tint Calculation ===")

local function testVisualTints()
    print("Test 3.1: DAY tint is neutral [128, 128, 128]")
    local result = sendMessage("GetEnvironmentalState", {Wave = "5", Biome = "1"})
    local data = json.decode(result.Data)
    assertEquals(tostring(data.visualTint[1]), "128", "DAY tint R should be 128")
    assertEquals(tostring(data.visualTint[2]), "128", "DAY tint G should be 128")
    assertEquals(tostring(data.visualTint[3]), "128", "DAY tint B should be 128")

    print("Test 3.2: DUSK tint is [113, 88, 100]")
    result = sendMessage("GetEnvironmentalState", {Wave = "17", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.visualTint[1]), "113", "DUSK tint R should be 113")
    assertEquals(tostring(data.visualTint[2]), "88", "DUSK tint G should be 88")
    assertEquals(tostring(data.visualTint[3]), "100", "DUSK tint B should be 100")

    print("Test 3.3: NIGHT tint is dark [64, 64, 64]")
    result = sendMessage("GetEnvironmentalState", {Wave = "25", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.visualTint[1]), "64", "NIGHT tint R should be 64")
    assertEquals(tostring(data.visualTint[2]), "64", "NIGHT tint G should be 64")
    assertEquals(tostring(data.visualTint[3]), "64", "NIGHT tint B should be 64")

    print("Test 3.4: DAWN tint is neutral [128, 128, 128]")
    result = sendMessage("GetEnvironmentalState", {Wave = "37", Biome = "1"})
    data = json.decode(result.Data)
    assertEquals(tostring(data.visualTint[1]), "128", "DAWN tint R should be 128")
    assertEquals(tostring(data.visualTint[2]), "128", "DAWN tint G should be 128")
    assertEquals(tostring(data.visualTint[3]), "128", "DAWN tint B should be 128")
end

testVisualTints()

-- ============================================================================
-- TEST SUITE 4: Time Transition Detection
-- ============================================================================

print("\n=== TEST SUITE 4: Time Transition Detection ===")

local function testTimeTransitions()
    print("Test 4.1: Transition from DAY to DUSK (wave 14 → 15)")
    local result = sendMessage("TransitionTimeOfDay", {
        Wave = "15",
        PreviousWave = "14",
        Biome = "1",
        LastTimeOfDay = "1"
    })
    assertEquals(result.PreviousTimeOfDay, "1", "Previous time should be DAY")
    assertEquals(result.NewTimeOfDay, "2", "New time should be DUSK")
    assertEquals(result.TransitionType, "day_to_dusk", "Transition type should be day_to_dusk")
    assertEquals(result.PoolUpdateRequired, "true", "Pool update should be required")

    print("Test 4.2: Transition from DUSK to NIGHT (wave 19 → 20)")
    result = sendMessage("TransitionTimeOfDay", {
        Wave = "20",
        PreviousWave = "19",
        Biome = "1",
        LastTimeOfDay = "2"
    })
    assertEquals(result.TransitionType, "dusk_to_night", "Transition type should be dusk_to_night")

    print("Test 4.3: Transition from NIGHT to DAWN (wave 34 → 35)")
    result = sendMessage("TransitionTimeOfDay", {
        Wave = "35",
        PreviousWave = "34",
        Biome = "1",
        LastTimeOfDay = "3"
    })
    assertEquals(result.TransitionType, "night_to_dawn", "Transition type should be night_to_dawn")

    print("Test 4.4: Transition from DAWN to DAY (wave 39 → 40)")
    result = sendMessage("TransitionTimeOfDay", {
        Wave = "40",
        PreviousWave = "39",
        Biome = "1",
        LastTimeOfDay = "0"
    })
    assertEquals(result.TransitionType, "dawn_to_day", "Transition type should be dawn_to_day")

    print("Test 4.5: No transition when time unchanged")
    result = sendMessage("TransitionTimeOfDay", {
        Wave = "10",
        PreviousWave = "9",
        Biome = "1",
        LastTimeOfDay = "1"
    })
    assertEquals(result.PoolUpdateRequired, "false", "Pool update should not be required when time unchanged")
end

testTimeTransitions()

-- ============================================================================
-- TEST SUITE 5: State Validation
-- ============================================================================

print("\n=== TEST SUITE 5: State Validation ===")

local function testStateValidation()
    print("Test 5.1: Valid state (correct time of day)")
    local result = sendMessage("ValidateEnvironmentalState", {
        Wave = "5",
        Biome = "1",
        TimeOfDay = "1"  -- DAY
    })
    assertEquals(result.Valid, "true", "State should be valid")
    assertEquals(result.ExpectedTimeOfDay, "1", "Expected time should be DAY")

    print("Test 5.2: Invalid state (incorrect time of day)")
    result = sendMessage("ValidateEnvironmentalState", {
        Wave = "25",
        Biome = "1",
        TimeOfDay = "1"  -- Claiming DAY but should be NIGHT
    })
    assertEquals(result.Valid, "false", "State should be invalid")
    assertEquals(result.ExpectedTimeOfDay, "3", "Expected time should be NIGHT")
    assertEquals(result.ActualTimeOfDay, "1", "Actual time should be DAY")

    print("Test 5.3: Validation with ABYSS override")
    result = sendMessage("ValidateEnvironmentalState", {
        Wave = "5",
        Biome = "24",  -- ABYSS
        TimeOfDay = "3"  -- NIGHT
    })
    assertEquals(result.Valid, "true", "ABYSS should always be NIGHT")
end

testStateValidation()

-- ============================================================================
-- TEST SUITE 6: Weather Interaction
-- ============================================================================

print("\n=== TEST SUITE 6: Weather Interaction ===")

local function testWeatherInteraction()
    print("Test 6.1: Weather state preserved in environmental state")
    local result = sendMessage("GetEnvironmentalState", {
        Wave = "5",
        Biome = "1",
        WeatherType = "1",
        WeatherTurnsLeft = "5"
    })
    local data = json.decode(result.Data)
    assertEquals(tostring(data.weatherState.weatherType), "1", "Weather type should be preserved")
    assertEquals(tostring(data.weatherState.turnsLeft), "5", "Weather turns should be preserved")

    print("Test 6.2: Environmental state without weather")
    result = sendMessage("GetEnvironmentalState", {
        Wave = "5",
        Biome = "1"
    })
    data = json.decode(result.Data)
    assertEquals(type(data.weatherState), "nil", "Weather state should be nil when not provided")
end

testWeatherInteraction()

-- ============================================================================
-- TEST RESULTS
-- ============================================================================

print("\n=== ENVIRONMENTAL CYCLE ENGINE TEST RESULTS ===")
print("Total Assertions: " .. assertionCount)
print("Failed Assertions: " .. failedAssertions)
print("Passed Assertions: " .. (assertionCount - failedAssertions))
print("Success Rate: " .. string.format("%.1f%%", ((assertionCount - failedAssertions) / assertionCount) * 100))

if failedAssertions == 0 then
    print("\n✓ ALL TESTS PASSED!")
else
    print("\n✗ SOME TESTS FAILED")
end

-- Return success status for test runner
return failedAssertions == 0
