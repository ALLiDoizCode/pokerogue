-- ============================================================================
-- Special Event Parity Tests
-- ============================================================================
-- Mathematical proof validation comparing Lua vs TypeScript behavior
-- Framework: aolite
-- ============================================================================

local aolite = require("aolite")

-- Load the special event engine process
local processPath = "processes/special-event-engine.lua"

describe("Special Event Parity Tests", function()
  local processId

  before_each(function()
    processId = aolite.spawnProcess(processPath)
  end)

  after_each(function()
    processId = nil
  end)

  it("should match TypeScript isActive() boundary logic", function()
    -- TypeScript: event.startDate < new Date() && new Date() < event.endDate
    -- Lua: event.startDate < currentTime and currentTime < event.endDate

    -- Winter Holiday: start=1734739200000, end=1735948800000
    local testCases = {
      {time = 1734739199999, expected = "false", desc = "1ms before start"},
      {time = 1734739200000, expected = "false", desc = "exact start (exclusive)"},
      {time = 1734739200001, expected = "true",  desc = "1ms after start"},
      {time = 1735948799999, expected = "true",  desc = "1ms before end"},
      {time = 1735948800000, expected = "false", desc = "exact end (exclusive)"},
      {time = 1735948800001, expected = "false", desc = "1ms after end"}
    }

    for _, testCase in ipairs(testCases) do
      local result = aolite.send({
        Target = processId,
        Action = "CheckEventActive",
        CurrentTime = tostring(testCase.time)
      })

      assert.are.equal(testCase.expected, result.IsActive,
        "Boundary check failed: " .. testCase.desc)
    end
  end)

  it("should match TypeScript cumulative shiny multiplier calculation", function()
    -- TypeScript: multiplier *= se.shinyMultiplier ?? 1
    -- Lua: multiplier = multiplier * (event.shinyMultiplier or 1)

    -- Winter Holiday: shinyMultiplier = 2
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetShinyMultiplier",
      CurrentTime = tostring(testTime)
    })

    -- Expected: 1 * 2 = 2
    assert.are.equal("2", result.ShinyMultiplier)
  end)

  it("should match TypeScript additive luck boost calculation", function()
    -- TypeScript: ret += le.luckBoost!
    -- Lua: luckBoost = luckBoost + event.luckBoost

    -- Year of the Snake: luckBoost = 1
    local testTime = 1738368000000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEffects",
      CurrentTime = tostring(testTime)
    })

    -- Expected: 0 + 1 = 1
    assert.are.equal("1", result.LuckBoost)
  end)

  it("should match TypeScript event encounter aggregation", function()
    -- TypeScript: ret.push(...te.eventEncounters)
    -- Lua: table.insert(encounters, encounter)

    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEncounters",
      CurrentTime = tostring(testTime)
    })

    -- Winter Holiday has 20 encounters
    assert.are.equal("20", result.EncounterCount)

    local json = require("json")
    local encounters = json.decode(result.Data)
    assert.are.equal(20, #encounters)
  end)

  it("should match TypeScript wave reward filtering", function()
    -- TypeScript: ret.push(...te.classicWaveRewards!.filter(cwr => cwr.wave === wave).map(cwr => cwr.type))
    -- Lua: if reward.wave == wave then table.insert(rewards, reward.type)

    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventRewards",
      Wave = "8",
      CurrentTime = tostring(testTime)
    })

    -- Winter Holiday wave 8 has 3 rewards
    assert.are.equal("3", result.RewardCount)
  end)

  it("should match TypeScript highest friendship multiplier selection", function()
    -- TypeScript: if (fe.classicFriendshipMultiplier > multiplier) { multiplier = fe.classicFriendshipMultiplier }
    -- Lua: if event.classicFriendshipMultiplier > multiplier then multiplier = event.classicFriendshipMultiplier

    -- PKMNDAY2025: classicFriendshipMultiplier = 4
    local testTime = 1740873600000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEffects",
      CurrentTime = tostring(testTime)
    })

    -- Expected: max(2.5, 4) = 4
    assert.are.equal("4", result.FriendshipMultiplier)
  end)

  it("should match TypeScript trainer shiny chance accumulation", function()
    -- TypeScript: tsEvents.map(t => (ret += t.trainerShinyChance!))
    -- Lua: chance = chance + event.trainerShinyChance

    -- April Fools: trainerShinyChance = 13107
    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEffects",
      CurrentTime = tostring(testTime)
    })

    -- Expected: 0 + 13107 = 13107
    assert.are.equal("13107", result.TrainerShinyChance)
  end)

  it("should match TypeScript mystery encounter tier changes", function()
    -- TypeScript: ret.push(...te.mysteryEncounterTierChanges)
    -- Lua: table.insert(changes, change)

    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetMysteryEncounterChanges",
      CurrentTime = tostring(testTime)
    })

    -- Winter Holiday has 5 tier changes
    assert.are.equal("5", result.ChangeCount)
  end)

  it("should match TypeScript music replacement logic", function()
    -- TypeScript: if (mr[0] === bgm) { ret = mr[1] }
    -- Lua: if musicReplacement[1] == bgmKey then replacement = musicReplacement[2]

    local testTime = 1743638400000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventMusicReplacement",
      BgmKey = "title",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("title_afd", result.ReplacementBgm)
  end)

  it("should document timestamp handling (milliseconds)", function()
    -- TypeScript: new Date(Date.UTC(2024, 11, 21, 0)) = 1734739200000 milliseconds
    -- Lua: Uses same millisecond timestamps directly

    -- Verify timestamp conversion accuracy
    local winterHolidayStart = 1734739200000
    local winterHolidayEnd = 1735948800000

    -- Test 1ms after start
    local result1 = aolite.send({
      Target = processId,
      Action = "CheckEventActive",
      CurrentTime = tostring(winterHolidayStart + 1)
    })
    assert.are.equal("true", result1.IsActive)

    -- Test exact end
    local result2 = aolite.send({
      Target = processId,
      Action = "CheckEventActive",
      CurrentTime = tostring(winterHolidayEnd)
    })
    assert.are.equal("false", result2.IsActive)
  end)

  it("should match TypeScript default value handling", function()
    -- TypeScript: multiplier *= se.shinyMultiplier ?? 1
    -- Lua: multiplier = multiplier * (event.shinyMultiplier or 1)

    -- Test with event that has no shinyMultiplier
    local testTime = 1738368000000 -- Year of the Snake (LUCK event, no shiny multiplier)

    local result = aolite.send({
      Target = processId,
      Action = "GetShinyMultiplier",
      CurrentTime = tostring(testTime)
    })

    -- Expected: 1 (default)
    assert.are.equal("1", result.ShinyMultiplier)
  end)

  it("should match TypeScript event type filtering", function()
    -- TypeScript: timedEvents.filter(te => te.eventType === EventType.SHINY && this.isActive(te))
    -- Lua: if isEventActive(event, currentTime) and event.eventType == EventType.SHINY

    -- Winter Holiday is SHINY event
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetShinyMultiplier",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("2", result.ShinyMultiplier)

    -- Year of the Snake is LUCK event (not SHINY)
    local testTime2 = 1738368000000

    local result2 = aolite.send({
      Target = processId,
      Action = "GetShinyMultiplier",
      CurrentTime = tostring(testTime2)
    })

    assert.are.equal("1", result2.ShinyMultiplier) -- No SHINY event active
  end)

  it("should match TypeScript boolean flag aggregation", function()
    -- TypeScript: return timedEvents.some(te => this.isActive(te) && (te.upgradeUnlockedVouchers ?? false))
    -- Lua: if isEventActive(event, currentTime) and event.upgradeUnlockedVouchers

    -- Winter Holiday: upgradeUnlockedVouchers = true
    local testTime = 1735084800000

    local result = aolite.send({
      Target = processId,
      Action = "GetEventEffects",
      CurrentTime = tostring(testTime)
    })

    assert.are.equal("true", result.UpgradeVouchers)

    -- Year of the Snake: no upgradeUnlockedVouchers
    local testTime2 = 1738368000000

    local result2 = aolite.send({
      Target = processId,
      Action = "GetEventEffects",
      CurrentTime = tostring(testTime2)
    })

    assert.are.equal("false", result2.UpgradeVouchers)
  end)
end)
