#!/usr/bin/env python3
"""
Build the complete passive-ability-engine.lua process file
Combines process logic with full 900+ species passive data
"""

def build_passive_process():
    """Build complete passive ability engine process"""

    # Read the passive abilities data
    with open("processes/data/starter-passive-abilities.lua", 'r') as f:
        passives_content = f.read()

    # Extract the table entries (between the braces)
    import re
    match = re.search(r'local starterPassiveAbilities = \{(.*?)\nreturn', passives_content, re.DOTALL)
    if not match:
        print("ERROR: Could not extract passives data")
        return

    passives_entries = match.group(1).strip()

    # Build the complete process file
    process_content = '''-- Passive Ability Engine Process for PokéRogue AO
-- ADP v1.0 Compliant Process for passive ability system
-- Handles passive ability unlocking, progression, triggers, and battle integration
-- Monolithic design - all dependencies embedded (no external imports)

-- ====================================
-- AO ENVIRONMENT GLOBALS
-- ====================================

-- Global declarations for AO environment
local json = json or { encode = function(t) return "encoded_json" end, decode = function(s) return {} end }
local ao = ao or { send = function(msg) return true end, id = "passive-ability-engine" }

-- Handlers global (AO runtime provides this)
if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg.Tags and msg.Tags[tag] == value
                end
            end
        }
    }
end

-- ====================================
-- PROCESS CONFIGURATION
-- ====================================

local PROCESS_INFO = {
    name = "Passive Ability Engine",
    version = "1.0.0",
    adpVersion = "1.0",
    processId = "passive-ability-engine",
    capabilities = {
        "getPassiveAbility",
        "unlockPassive",
        "upgradePassive",
        "enablePassive",
        "disablePassive",
        "canApplyPassive",
        "calculatePassiveEffect",
        "getPlayerPassives",
        "passiveTriggerValidation"
    },
    messageSchemas = {
        GetPassiveAbility = {
            required = {"Action", "SpeciesId"},
            optional = {"UpgradeLevel"},
            response = "PassiveAbilityData"
        },
        UnlockPassive = {
            required = {"Action", "PlayerId", "SpeciesId", "Cost"},
            response = "PassiveUnlocked"
        },
        UpgradePassive = {
            required = {"Action", "PlayerId", "SpeciesId", "ToTier", "Cost"},
            response = "PassiveUnlocked"
        },
        EnablePassive = {
            required = {"Action", "PokemonId", "Enable"},
            response = "PassiveStateUpdated"
        },
        CanApplyPassive = {
            required = {"Action", "PokemonId"},
            optional = {"BattleContext"},
            response = "PassiveApplicationResult"
        },
        CalculatePassiveEffect = {
            required = {"Action", "PokemonId", "AbilityId", "TriggerContext"},
            response = "PassiveEffectResult"
        },
        GetPlayerPassives = {
            required = {"Action", "PlayerId"},
            response = "PlayerPassiveData"
        },
        Info = {
            required = {"Action"},
            response = "process_metadata"
        },
        HealthCheck = {
            required = {"Action"},
            response = "status_report"
        }
    }
}

-- Performance and rate limiting
local LOGIC_OPERATION_TIMEOUT = 5000 -- 5 seconds in milliseconds
local RATE_LIMIT_MAX = 50 -- operations per minute per address
local rateLimitCounters = {}
local performanceStartTime = nil

-- ====================================
-- PLAYER PROGRESSION STATE
-- ====================================

-- In-memory storage for player passive progression
-- In production, this would be persisted to Arweave/AO storage
local playerPassiveData = {}

-- ====================================
-- POKEMON PASSIVE STATE
-- ====================================

-- In-memory storage for Pokemon passive states
-- Tracks enabled/disabled state for each Pokemon instance
local pokemonPassiveStates = {}

-- ====================================
-- EMBEDDED PASSIVE ABILITIES DATA
-- ====================================
-- Source: typescript-reference/src/data/balance/passives.ts
-- 900+ Pokemon species with passive ability mappings
-- Format: [SpeciesId] = { [upgradeLevel] = AbilityId }

local starterPassiveAbilities = {
'''

    process_content += passives_entries + "\n"

    process_content += '''-- ====================================
-- UTILITY FUNCTIONS
-- ====================================

-- Normalize species ID to uppercase with underscores
local function normalizeSpeciesId(speciesId)
    if not speciesId then return nil end
    return string.upper(string.gsub(speciesId, "-", "_"))
end

-- Get maximum upgrade tier for a species
local function getMaxUpgradeTier(speciesId)
    local normalizedId = normalizeSpeciesId(speciesId)
    local passives = starterPassiveAbilities[normalizedId]

    if not passives then return 0 end

    local maxTier = 0
    for tier, _ in pairs(passives) do
        if tier > maxTier then
            maxTier = tier
        end
    end

    return maxTier
end

-- ====================================
-- CORE PASSIVE ABILITY FUNCTIONS
-- ====================================

-- Get passive ability for a species at specific upgrade level
-- Matches TypeScript: species.getPassiveAbility(formIndex)
local function getPassiveAbility(speciesId, upgradeLevel)
    upgradeLevel = upgradeLevel or 0

    local normalizedId = normalizeSpeciesId(speciesId)
    if not normalizedId then
        return nil, "Invalid species ID"
    end

    local passives = starterPassiveAbilities[normalizedId]
    if not passives then
        return nil, "Species has no passive abilities"
    end

    local abilityId = passives[upgradeLevel]
    if not abilityId then
        -- If requested tier doesn't exist, return tier 0
        abilityId = passives[0]
        if not abilityId then
            return nil, "No passive ability at tier " .. upgradeLevel
        end
    end

    return {
        speciesId = normalizedId,
        abilityId = abilityId,
        upgradeLevel = upgradeLevel,
        maxUpgradeTier = getMaxUpgradeTier(normalizedId)
    }
end

-- Check if player has unlocked passive for species
local function hasPassiveUnlocked(playerId, speciesId)
    if not playerPassiveData[playerId] then return false end

    local normalizedId = normalizeSpeciesId(speciesId)
    return playerPassiveData[playerId].unlockedPassives[normalizedId] == true
end

-- Get player's upgrade level for species passive
local function getPlayerPassiveUpgradeLevel(playerId, speciesId)
    if not playerPassiveData[playerId] then return 0 end

    local normalizedId = normalizeSpeciesId(speciesId)
    return playerPassiveData[playerId].passiveUpgrades[normalizedId] or 0
end

-- Unlock passive for player's species
local function unlockPassive(playerId, speciesId, cost)
    -- Initialize player data if needed
    if not playerPassiveData[playerId] then
        playerPassiveData[playerId] = {
            unlockedPassives = {},
            passiveUpgrades = {}
        }
    end

    local normalizedId = normalizeSpeciesId(speciesId)

    -- Check if already unlocked
    if hasPassiveUnlocked(playerId, normalizedId) then
        return nil, "Passive already unlocked"
    end

    -- Verify species has passive
    if not starterPassiveAbilities[normalizedId] then
        return nil, "Species has no passive abilities"
    end

    -- Unlock passive
    playerPassiveData[playerId].unlockedPassives[normalizedId] = true
    playerPassiveData[playerId].passiveUpgrades[normalizedId] = 0

    return {
        success = true,
        speciesId = normalizedId,
        tier = 0,
        costApplied = cost
    }
end

-- Upgrade passive to higher tier
local function upgradePassive(playerId, speciesId, toTier, cost)
    local normalizedId = normalizeSpeciesId(speciesId)

    -- Check if passive is unlocked
    if not hasPassiveUnlocked(playerId, normalizedId) then
        return nil, "Passive not unlocked"
    end

    -- Check max tier
    local maxTier = getMaxUpgradeTier(normalizedId)
    if toTier > maxTier then
        return nil, "Max tier reached (max: " .. maxTier .. ")"
    end

    -- Check if tier exists
    if not starterPassiveAbilities[normalizedId][toTier] then
        return nil, "Invalid upgrade tier"
    end

    -- Upgrade tier
    playerPassiveData[playerId].passiveUpgrades[normalizedId] = toTier

    return {
        success = true,
        speciesId = normalizedId,
        tier = toTier,
        costApplied = cost
    }
end

-- Enable or disable passive for Pokemon instance
local function setPassiveEnabled(pokemonId, enabled)
    if not pokemonPassiveStates[pokemonId] then
        pokemonPassiveStates[pokemonId] = {
            enabled = false,
            abilityId = nil
        }
    end

    pokemonPassiveStates[pokemonId].enabled = enabled

    return {
        success = true,
        pokemonId = pokemonId,
        enabled = enabled
    }
end

-- Check if Pokemon has passive (matches TypeScript hasPassive)
local function hasPassive(pokemonId, playerId, speciesId)
    -- Check if unlocked by player
    if not hasPassiveUnlocked(playerId, speciesId) then
        return false
    end

    -- Check if species has passive
    local normalizedId = normalizeSpeciesId(speciesId)
    if not starterPassiveAbilities[normalizedId] then
        return false
    end

    return true
end

-- Check if passive can be applied (matches TypeScript canApplyAbility(passive=true))
local function canApplyPassive(pokemonId, playerId, speciesId, battleContext)
    -- Check if Pokemon has passive
    if not hasPassive(pokemonId, playerId, speciesId) then
        return false, "Passive not unlocked"
    end

    -- Check if passive is enabled
    local state = pokemonPassiveStates[pokemonId]
    if not state or not state.enabled then
        return false, "Passive not enabled"
    end

    -- Battle context validation could be added here
    -- For now, basic validation passes

    return true
end

-- ====================================
-- MESSAGE HANDLERS
-- ====================================

-- Handler: Get Passive Ability for Species
Handlers.add("get-passive-ability",
    Handlers.utils.hasMatchingTag("Action", "GetPassiveAbility"),
    function(msg)
        local speciesId = msg.SpeciesId or msg.Id
        if not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "SpeciesId required",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        local upgradeLevel = tonumber(msg.UpgradeLevel or "0")
        local result, err = getPassiveAbility(speciesId, upgradeLevel)

        if not result then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err or "Failed to get passive ability",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "PassiveAbilityData",
            SpeciesId = result.speciesId,
            AbilityId = tostring(result.abilityId),
            UpgradeLevel = tostring(result.upgradeLevel),
            MaxUpgradeTier = tostring(result.maxUpgradeTier),
            Success = "true",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Unlock Passive for Player
Handlers.add("unlock-passive",
    Handlers.utils.hasMatchingTag("Action", "UnlockPassive"),
    function(msg)
        local playerId = msg.PlayerId
        local speciesId = msg.SpeciesId
        local cost = tonumber(msg.Cost or "0")

        if not playerId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId and SpeciesId required",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        local result, err = unlockPassive(playerId, speciesId, cost)

        if not result then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err or "Failed to unlock passive",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "PassiveUnlocked",
            SpeciesId = result.speciesId,
            Success = "true",
            NewTier = tostring(result.tier),
            CostApplied = tostring(result.costApplied),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Upgrade Passive Tier
Handlers.add("upgrade-passive",
    Handlers.utils.hasMatchingTag("Action", "UpgradePassive"),
    function(msg)
        local playerId = msg.PlayerId
        local speciesId = msg.SpeciesId
        local toTier = tonumber(msg.ToTier or "0")
        local cost = tonumber(msg.Cost or "0")

        if not playerId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId and SpeciesId required",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        local result, err = upgradePassive(playerId, speciesId, toTier, cost)

        if not result then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = err or "Failed to upgrade passive",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        ao.send({
            Target = msg.From,
            Action = "PassiveUnlocked",
            SpeciesId = result.speciesId,
            Success = "true",
            NewTier = tostring(result.tier),
            CostApplied = tostring(result.costApplied),
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Enable/Disable Passive
Handlers.add("enable-passive",
    Handlers.utils.hasMatchingTag("Action", "EnablePassive"),
    function(msg)
        local pokemonId = msg.PokemonId
        local enable = msg.Enable == "true"

        if not pokemonId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId required",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        local result = setPassiveEnabled(pokemonId, enable)

        ao.send({
            Target = msg.From,
            Action = "PassiveStateUpdated",
            PokemonId = result.pokemonId,
            Enabled = tostring(result.enabled),
            Success = "true",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Can Apply Passive (battle validation)
Handlers.add("can-apply-passive",
    Handlers.utils.hasMatchingTag("Action", "CanApplyPassive"),
    function(msg)
        local pokemonId = msg.PokemonId
        local playerId = msg.PlayerId
        local speciesId = msg.SpeciesId

        if not pokemonId or not playerId or not speciesId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PokemonId, PlayerId, and SpeciesId required",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        local battleContext = nil
        if msg.BattleContext and msg.BattleContext ~= "" then
            battleContext = json.decode(msg.BattleContext)
        end

        local canApply, reason = canApplyPassive(pokemonId, playerId, speciesId, battleContext)

        ao.send({
            Target = msg.From,
            Action = "PassiveApplicationResult",
            PokemonId = pokemonId,
            CanApply = tostring(canApply),
            BlockedReason = reason or "",
            Success = "true",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Get Player Passives
Handlers.add("get-player-passives",
    Handlers.utils.hasMatchingTag("Action", "GetPlayerPassives"),
    function(msg)
        local playerId = msg.PlayerId

        if not playerId then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "PlayerId required",
                Timestamp = tostring(msg.Timestamp or 0)
            })
            return
        end

        local data = playerPassiveData[playerId] or {
            unlockedPassives = {},
            passiveUpgrades = {}
        }

        -- Count total unlocked
        local totalUnlocked = 0
        for _ in pairs(data.unlockedPassives) do
            totalUnlocked = totalUnlocked + 1
        end

        ao.send({
            Target = msg.From,
            Action = "PlayerPassiveData",
            Data = json.encode({
                unlockedPassives = data.unlockedPassives,
                passiveUpgrades = data.passiveUpgrades,
                totalUnlocked = totalUnlocked
            }),
            Success = "true",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Process Info (ADP v1.0 Compliance)
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "InfoResponse",
            Data = json.encode(PROCESS_INFO),
            Success = "true",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- Handler: Health Check
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        local speciesCount = 0
        for _ in pairs(starterPassiveAbilities) do
            speciesCount = speciesCount + 1
        end

        ao.send({
            Target = msg.From,
            Action = "HealthCheckResponse",
            Status = "healthy",
            ProcessId = ao.id,
            SpeciesWithPassives = tostring(speciesCount),
            Success = "true",
            Timestamp = tostring(msg.Timestamp or 0)
        })
    end
)

-- ====================================
-- PROCESS INITIALIZATION
-- ====================================

print("Passive Ability Engine initialized")
print("ADP v1.0 Compliant")
local speciesCount = 0
for _ in pairs(starterPassiveAbilities) do speciesCount = speciesCount + 1 end
print("Loaded " .. speciesCount .. " species with passive abilities")
'''

    # Write the complete file
    with open("processes/passive-ability-engine.lua", 'w') as f:
        f.write(process_content)

    # Check size
    import os
    file_size = os.path.getsize("processes/passive-ability-engine.lua")
    print(f"✓ Built passive-ability-engine.lua ({file_size} bytes, {file_size/1024:.1f} KB)")

if __name__ == "__main__":
    build_passive_process()
