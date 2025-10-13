# Process Action Pattern Documentation
Generated: 2025-10-10
Purpose: Document exact handler names and response actions for all 11 direct mapping processes

## Pattern Legend
- **Handler Name**: Kebab-case name used in Handlers.add()
- **Input Action**: Tag value for Action in hasMatchingTag()
- **Response Action**: Action field in ao.send() response
- **Response Type**: "SaveState" (data), "Error" (error), or custom

---

## 1. egg-hatching-engine
**Status**: ✅ Test exists (needs action name fixes)

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| info | Info | Info-Response | Hyphenated response |
| configure-process-ids | ConfigureProcessIds | Error/Success | Configuration |
| progress-steps | ProgressSteps | SaveState/Error | Main handler |
| hatch-egg | HatchEgg | SaveState/Error | Single hatch |
| mass-hatch | MassHatch | SaveState/Error | Batch hatch |
| list-eggs | ListEggs | SaveState/Error | Query eggs |
| get-egg-details | GetEggDetails | SaveState/Error | Individual egg |
| sort-eggs | SortEggs | SaveState/Error | Sort by metric |
| apply-incubator | ApplyIncubator | SaveState/Error | Add modifier |
| remove-incubator | RemoveIncubator | SaveState/Error | Remove modifier |
| get-hatch-timing | GetHatchTiming | SaveState/Error | Timing calc |
| health-check | HealthCheck | HealthCheck-Response | Hyphenated response |

---

## 2. friendship-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| calculate-friendship | CalculateFriendship | SaveState/Error | Main calculation |
| check-friendship-evolution | CheckFriendshipEvolution | SaveState/Error | Evolution check |
| calculate-friendship-move-effects | CalculateFriendshipMoveEffects | SaveState/Error | Return/Frustration |
| get-friendship-status | GetFriendshipStatus | SaveState/Error | Display level |
| info | Info | SaveState | Process metadata |

---

## 3. genetic-inheritance-engine  
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| info | Info | InfoResponse | **NO HYPHEN** |
| fetch-pokemon-data | FetchPokemonDataResponse | N/A | Listener handler |
| breeding-compatibility-response | BreedingCompatibilityResponse | N/A | Listener handler |
| process-logic | ProcessLogic | SaveState/Error | Main handler |
| health-check | HealthCheck | HealthCheckResponse | **NO HYPHEN** |

**CRITICAL**: This process uses NO HYPHENS in response actions (InfoResponse, HealthCheckResponse)

---

## 4. field-condition-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| apply-field-condition | ApplyFieldCondition | SaveState/Error | Apply condition |
| apply-future-attack | ApplyFutureAttack | SaveState/Error | Future Sight/Doom Desire |
| check-field-condition-effects | CheckFieldConditionEffects | SaveState/Error | Effect query |
| process-field-condition-interactions | ProcessFieldConditionInteractions | SaveState/Error | Interactions |
| advance-turn | AdvanceTurn | SaveState/Error | Turn counter |
| info | Info | SaveState | Process metadata |
| ping | Ping | Pong | Health check |

---

## 5. battle-engine-turn-manager
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| calculate-turn-order | CalculateTurnOrder | SaveState/Error | Speed/priority calc |
| validate-action | ValidateAction | SaveState/Error | Move validation |
| execute-turn | ExecuteTurn | SaveState/Error | Turn execution |
| process-switch | ProcessSwitch | SaveState/Error | Switch handling |
| info | Info | SaveState | Process metadata |
| ping | Ping | Pong | Health check |

---

## 6. positional-battle-mechanics-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| apply-positional-effect | ApplyPositionalEffect | SaveState/Error | Position effects |
| check-positional-targeting | CheckPositionalTargeting | SaveState/Error | Target validation |
| process-positional-turn-effects | ProcessPositionalTurnEffects | SaveState/Error | Turn effects |
| update-battlefield-positions | UpdateBattlefieldPositions | SaveState/Error | Position update |
| health-check | HealthCheck | SaveState/Error | Health check |
| cleanup-battle-data | CleanupBattleData | SaveState/Error | Cleanup |
| info | Info | SaveState | Process metadata |

---

## 7. stellar-tera-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| process-stellar-tera | ProcessStellarTera | SaveState/Error | Main stellar logic |
| calculate-stellar-stab | CalculateStellarSTAB | SaveState/Error | STAB calculation |
| track-stellar-usage | TrackStellarUsage | SaveState/Error | Usage tracking |
| process-multi-type-stellar | ProcessMultiTypeStellar | SaveState/Error | Multi-type handling |
| validate-stellar-state | ValidateStellarState | SaveState/Error | State validation |
| reset-battle-stellar | ResetBattleStellar | SaveState/Error | Battle reset |
| get-stellar-effectiveness | GetStellarEffectiveness | SaveState/Error | Effectiveness calc |
| health-check | HealthCheck | SaveState/Error | Health check |
| info | Info | SaveState | Process metadata |
| ping | Ping | Pong | Health check |

---

## 8. terastalization-battle-integration-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| process-terastalization-battle | ProcessTerastalizationBattle | SaveState/Error | Main battle integration |
| battle-timing-coordination | BattleTimingCoordination | SaveState/Error | Phase timing |
| status-effect-interaction | StatusEffectInteraction | SaveState/Error | Status interactions |
| weather-terrain-integration | WeatherTerrainIntegration | SaveState/Error | Environmental effects |
| ai-decision-making | AIDecisionMaking | SaveState/Error | AI tera decisions |
| complex-scenario-coordination | ComplexScenarioCoordination | SaveState/Error | Complex scenarios |
| health-check | HealthCheck | SaveState/Error | Health check |
| info | Info | SaveState | Process metadata |
| ping | Ping | Pong | Health check |

---

## 9. fusion-content-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| generateFusionName | GenerateFusionName | SaveState | Name generation |
| generateFusionMovePool | GenerateFusionMovePool | SaveState | Move pool |
| validateFusionContent | ValidateFusionContent | SaveState | Validation |
| resolveFusionContentConflicts | ResolveFusionContentConflicts | SaveState | Conflict resolution |
| calculateContentPrecision | CalculateContentPrecision | SaveState | Precision calc |
| info | Info | SaveState | Process metadata |

---

## 10. fusion-form-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| generate-fusion-appearance | GenerateFusionAppearance | SaveState | Visual generation |
| determine-fusion-form | DetermineFusionForm | SaveState | Form selection |
| validate-fusion-appearance | ValidateFusionAppearance | SaveState | Appearance validation |
| resolve-fusion-visuals | ResolveFusionVisuals | SaveState | Visual conflicts |
| calculate-appearance-precision | CalculateAppearancePrecision | SaveState | Precision calc |
| info | Info | SaveState | Process metadata |
| ping | Ping | Pong | Health check |

---

## 11. wild-encounter-engine
**Status**: ⏳ Needs rewrite

| Handler | Input Action | Response Action | Notes |
|---------|-------------|-----------------|-------|
| info | Info | SaveState | Process metadata |
| health-check | HealthCheck | SaveState | Health check |
| process-wild-encounter | ProcessWildEncounter | SaveState/Error | Main encounter logic |

---

## Common Patterns Discovered

### Response Action Naming
1. **Most Common**: `SaveState` (success), `Error` (failure)
2. **Health Checks**: Usually `HealthCheck-Response` (hyphenated) or `Pong`
3. **Info Handler**: Usually `SaveState` or `Info-Response` (hyphenated)
4. **Exception**: genetic-inheritance-engine uses NO hyphens (InfoResponse, HealthCheckResponse)

### Input Action Naming
- Always PascalCase (e.g., `CalculateFriendship`, `ApplyFieldCondition`)
- Matches handler name but in PascalCase instead of kebab-case

### Handler Registration Pattern
```lua
Handlers.add("handler-name",
    Handlers.utils.hasMatchingTag("Action", "InputActionName"),
    function(msg)
        -- Logic
        ao.send({
            Target = msg.From,
            Action = "ResponseActionName",
            Data = json.encode(result)
        })
    end
)
```

---

## Testing Strategy

### For Each Process
1. Read process file to confirm handler list
2. Inspect action response patterns with: `./scripts/inspect-process-handlers.sh <process-name>`
3. Write linear test following correct aolite pattern
4. Test each handler with valid and invalid inputs
5. Verify response actions match documented patterns

### Common Test Structure
```lua
-- Setup
local aolite = require("aolite")
local json = require("json")
local PROCESS_PATH = "processes/XXX.lua"
local processId = "test-XXX"

-- Spawn process
local file = io.open(PROCESS_PATH, "r")
local processSource = file:read("*all")
file:close()
aolite.spawnProcess(processId, processSource, {})

-- Test utility
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Info handler
local response = sendMessage("Info")
assert(response.Action == "SaveState" or response.Action == "Info-Response")

-- Test 2: Main handler
-- ...
```

