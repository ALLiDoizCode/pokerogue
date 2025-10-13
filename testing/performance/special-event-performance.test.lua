-- ============================================================================
-- Special Event Performance Tests
-- ============================================================================
-- Performance benchmarks for event engine handlers
-- Framework: aolite
-- ============================================================================

local aolite = require("aolite")

-- Load the special event engine process
local processPath = "processes/special-event-engine.lua"

describe("Special Event Performance Tests", function()
  local processId

  before_each(function()
    processId = aolite.spawnProcess(processPath)
  end)

  after_each(function()
    processId = nil
  end)

  it("CheckEventActive should execute in <2ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "CheckEventActive",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 2, string.format("Average time: %.2fms (expected <2ms)", avgTime))
  end)

  it("GetShinyMultiplier should execute in <3ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetShinyMultiplier",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 3, string.format("Average time: %.2fms (expected <3ms)", avgTime))
  end)

  it("GetEventEncounters should execute in <5ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetEventEncounters",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 5, string.format("Average time: %.2fms (expected <5ms)", avgTime))
  end)

  it("GetEventRewards should execute in <3ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetEventRewards",
        Wave = "8",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 3, string.format("Average time: %.2fms (expected <3ms)", avgTime))
  end)

  it("GetEventEffects should execute in <5ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetEventEffects",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 5, string.format("Average time: %.2fms (expected <5ms)", avgTime))
  end)

  it("GetMysteryEncounterChanges should execute in <3ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetMysteryEncounterChanges",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 3, string.format("Average time: %.2fms (expected <3ms)", avgTime))
  end)

  it("CheckSpeciesLuckBoost should execute in <2ms", function()
    local testTime = 1738368000000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "CheckSpeciesLuckBoost",
        SpeciesId = "23",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 2, string.format("Average time: %.2fms (expected <2ms)", avgTime))
  end)

  it("Batch processing: 100 event checks in <200ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "CheckEventActive",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local totalTime = (endTime - startTime) * 1000

    assert.is_true(totalTime < 200, string.format("Total time: %.2fms (expected <200ms)", totalTime))
  end)

  it("GetActiveEvent should execute in <3ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetActiveEvent",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 3, string.format("Average time: %.2fms (expected <3ms)", avgTime))
  end)

  it("GetEventMusicReplacement should execute in <2ms", function()
    local testTime = 1743638400000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetEventMusicReplacement",
        BgmKey = "title",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 2, string.format("Average time: %.2fms (expected <2ms)", avgTime))
  end)

  it("GetEventChallenges should execute in <2ms", function()
    local testTime = 1743638400000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "GetEventChallenges",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 2, string.format("Average time: %.2fms (expected <2ms)", avgTime))
  end)

  it("ValidateEventParticipation should execute in <2ms", function()
    local testTime = 1735084800000
    local iterations = 100
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({
        Target = processId,
        Action = "ValidateEventParticipation",
        CurrentTime = tostring(testTime)
      })
    end

    local endTime = os.clock()
    local avgTime = ((endTime - startTime) * 1000) / iterations

    assert.is_true(avgTime < 2, string.format("Average time: %.2fms (expected <2ms)", avgTime))
  end)

  it("Mixed workload: all handlers in sequence", function()
    local testTime = 1735084800000
    local iterations = 10
    local startTime = os.clock()

    for i = 1, iterations do
      aolite.send({Target = processId, Action = "CheckEventActive", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetActiveEvent", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetShinyMultiplier", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetEventEncounters", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetEventRewards", Wave = "8", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetEventEffects", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetMysteryEncounterChanges", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "CheckSpeciesLuckBoost", SpeciesId = "23", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "GetEventChallenges", CurrentTime = tostring(testTime)})
      aolite.send({Target = processId, Action = "ValidateEventParticipation", CurrentTime = tostring(testTime)})
    end

    local endTime = os.clock()
    local totalTime = (endTime - startTime) * 1000
    local avgPerHandler = totalTime / (iterations * 10)

    assert.is_true(avgPerHandler < 5, string.format("Average per handler: %.2fms (expected <5ms)", avgPerHandler))
  end)
end)
