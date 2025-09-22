#!/usr/bin/env lua

--[[
State Inspector for HyperBeam Testing Framework
Provides ECS world state extraction, comparison, and validation utilities
Version: 1.0.0
]]

local StateInspector = {}

-- State tracking and snapshots
local StateRegistry = {
    snapshots = {},
    watchedStates = {},
    stateHistory = {},
    validationRules = {}
}

-- State extraction utilities
function StateInspector.extractState(process)
    if not process then
        return nil
    end
    
    local extractedState = {
        processId = process.id,
        timestamp = os.clock() * 1000,
        state = {}
    }
    
    -- Deep copy the process state
    extractedState.state = StateInspector.deepCopy(process.state)
    
    -- Add process metadata
    extractedState.metadata = {
        running = process.running,
        messageCount = process.messageCount,
        errorCount = process.errorCount,
        executionTime = process.executionTime,
        queueSize = #(process.messageQueue or {})
    }
    
    return extractedState
end

function StateInspector.extractWorldState(processes)
    processes = processes or {}
    
    local worldState = {
        timestamp = os.clock() * 1000,
        processes = {},
        totalProcesses = 0,
        activeProcesses = 0
    }
    
    for processId, process in pairs(processes) do
        worldState.processes[processId] = StateInspector.extractState(process)
        worldState.totalProcesses = worldState.totalProcesses + 1
        if process.running then
            worldState.activeProcesses = worldState.activeProcesses + 1
        end
    end
    
    return worldState
end

-- Deep copy utility
function StateInspector.deepCopy(original)
    local copy
    if type(original) == "table" then
        copy = {}
        for key, value in pairs(original) do
            copy[StateInspector.deepCopy(key)] = StateInspector.deepCopy(value)
        end
    else
        copy = original
    end
    return copy
end

-- State comparison utilities
function StateInspector.compareStates(state1, state2, path)
    path = path or "root"
    local differences = {}
    
    if type(state1) ~= type(state2) then
        table.insert(differences, {
            path = path,
            type = "type_mismatch",
            expected = type(state2),
            actual = type(state1)
        })
        return differences
    end
    
    if type(state1) == "table" then
        -- Check for missing keys in state1
        for key, value2 in pairs(state2) do
            local newPath = path .. "." .. tostring(key)
            if state1[key] == nil then
                table.insert(differences, {
                    path = newPath,
                    type = "missing_key",
                    expected = value2,
                    actual = nil
                })
            else
                local subDiffs = StateInspector.compareStates(state1[key], value2, newPath)
                for _, diff in ipairs(subDiffs) do
                    table.insert(differences, diff)
                end
            end
        end
        
        -- Check for extra keys in state1
        for key, value1 in pairs(state1) do
            local newPath = path .. "." .. tostring(key)
            if state2[key] == nil then
                table.insert(differences, {
                    path = newPath,
                    type = "extra_key",
                    expected = nil,
                    actual = value1
                })
            end
        end
    else
        if state1 ~= state2 then
            table.insert(differences, {
                path = path,
                type = "value_mismatch",
                expected = state2,
                actual = state1
            })
        end
    end
    
    return differences
end

function StateInspector.statesEqual(state1, state2)
    local differences = StateInspector.compareStates(state1, state2)
    return #differences == 0, differences
end

-- State snapshots
function StateInspector.takeSnapshot(processId, label)
    local ProcessEmulator = require("./process-emulator")
    local process = ProcessEmulator.getProcess(processId)
    
    if not process then
        return nil
    end
    
    label = label or "snapshot_" .. 1234567890
    local snapshot = StateInspector.extractState(process)
    snapshot.label = label
    
    -- Store snapshot
    StateRegistry.snapshots[processId] = StateRegistry.snapshots[processId] or {}
    StateRegistry.snapshots[processId][label] = snapshot
    
    return snapshot
end

function StateInspector.getSnapshot(processId, label)
    if not StateRegistry.snapshots[processId] then
        return nil
    end
    return StateRegistry.snapshots[processId][label]
end

function StateInspector.listSnapshots(processId)
    if not StateRegistry.snapshots[processId] then
        return {}
    end
    
    local labels = {}
    for label, _ in pairs(StateRegistry.snapshots[processId]) do
        table.insert(labels, label)
    end
    return labels
end

function StateInspector.compareSnapshots(processId, label1, label2)
    local snapshot1 = StateInspector.getSnapshot(processId, label1)
    local snapshot2 = StateInspector.getSnapshot(processId, label2)
    
    if not snapshot1 or not snapshot2 then
        return nil, "One or both snapshots not found"
    end
    
    return StateInspector.compareStates(snapshot1.state, snapshot2.state)
end

-- State traversal utilities
function StateInspector.findInState(state, predicate, path)
    path = path or "root"
    local results = {}
    
    if predicate(state, path) then
        table.insert(results, {path = path, value = state})
    end
    
    if type(state) == "table" then
        for key, value in pairs(state) do
            local newPath = path .. "." .. tostring(key)
            local subResults = StateInspector.findInState(value, predicate, newPath)
            for _, result in ipairs(subResults) do
                table.insert(results, result)
            end
        end
    end
    
    return results
end

function StateInspector.getStateValue(state, path)
    local pathParts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    local current = state
    for i = 2, #pathParts do -- Skip "root"
        local key = pathParts[i]
        if type(current) == "table" and current[key] ~= nil then
            current = current[key]
        else
            return nil
        end
    end
    
    return current
end

function StateInspector.setStateValue(state, path, value)
    local pathParts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    local current = state
    for i = 2, #pathParts - 1 do -- Skip "root" and last part
        local key = pathParts[i]
        if type(current) == "table" then
            if current[key] == nil then
                current[key] = {}
            end
            current = current[key]
        else
            return false
        end
    end
    
    if type(current) == "table" then
        current[pathParts[#pathParts]] = value
        return true
    end
    
    return false
end

-- State validation
function StateInspector.addValidationRule(ruleName, validator)
    StateRegistry.validationRules[ruleName] = validator
end

function StateInspector.validateState(state, rules)
    rules = rules or StateRegistry.validationRules
    local validationResults = {}
    
    for ruleName, validator in pairs(rules) do
        local success, result = pcall(validator, state)
        
        table.insert(validationResults, {
            ruleName = ruleName,
            success = success,
            message = success and "OK" or tostring(result),
            details = result
        })
    end
    
    return validationResults
end

-- Built-in validation rules
StateInspector.addValidationRule("gameStateStructure", function(state)
    if type(state) ~= "table" then
        error("Game state must be a table")
    end
    
    -- Check for essential game state components
    local requiredComponents = {"player", "scene"}
    for _, component in ipairs(requiredComponents) do
        if state[component] == nil then
            error("Missing required component: " .. component)
        end
    end
    
    return true
end)

StateInspector.addValidationRule("playerStructure", function(state)
    if not state.player then
        return true -- Skip if no player
    end
    
    if type(state.player) ~= "table" then
        error("Player must be a table")
    end
    
    local requiredFields = {"id", "name"}
    for _, field in ipairs(requiredFields) do
        if state.player[field] == nil then
            error("Player missing required field: " .. field)
        end
    end
    
    return true
end)

StateInspector.addValidationRule("pokemonStructure", function(state)
    if not state.party then
        return true -- Skip if no party
    end
    
    if type(state.party) ~= "table" then
        error("Party must be a table")
    end
    
    for i, pokemon in ipairs(state.party) do
        if type(pokemon) ~= "table" then
            error("Pokemon " .. i .. " must be a table")
        end
        
        local requiredFields = {"speciesId", "level", "currentHp", "stats"}
        for _, field in ipairs(requiredFields) do
            if pokemon[field] == nil then
                error("Pokemon " .. i .. " missing field: " .. field)
            end
        end
        
        -- Validate stats
        if type(pokemon.stats) ~= "table" then
            error("Pokemon " .. i .. " stats must be a table")
        end
        
        local requiredStats = {"hp", "attack", "defense", "spAttack", "spDefense", "speed"}
        for _, stat in ipairs(requiredStats) do
            if type(pokemon.stats[stat]) ~= "number" then
                error("Pokemon " .. i .. " stat " .. stat .. " must be a number")
            end
        end
    end
    
    return true
end)

-- State diff reporting
function StateInspector.generateDiffReport(differences)
    if #differences == 0 then
        return "No differences found"
    end
    
    local report = "State Differences:\n"
    report = report .. string.rep("=", 50) .. "\n"
    
    for i, diff in ipairs(differences) do
        report = report .. string.format("%d. %s at %s\n", i, diff.type:upper(), diff.path)
        report = report .. string.format("   Expected: %s\n", tostring(diff.expected))
        report = report .. string.format("   Actual:   %s\n", tostring(diff.actual))
        report = report .. "\n"
    end
    
    return report
end

-- State visualization (simple text-based)
function StateInspector.visualizeState(state, maxDepth, currentDepth)
    maxDepth = maxDepth or 3
    currentDepth = currentDepth or 0
    
    if currentDepth >= maxDepth then
        return tostring(state)
    end
    
    if type(state) ~= "table" then
        return tostring(state)
    end
    
    local lines = {}
    local indent = string.rep("  ", currentDepth)
    
    for key, value in pairs(state) do
        local keyStr = tostring(key)
        if type(value) == "table" then
            table.insert(lines, indent .. keyStr .. ":")
            local subVisualization = StateInspector.visualizeState(value, maxDepth, currentDepth + 1)
            for subLine in subVisualization:gmatch("[^\n]+") do
                table.insert(lines, subLine)
            end
        else
            table.insert(lines, indent .. keyStr .. ": " .. tostring(value))
        end
    end
    
    return table.concat(lines, "\n")
end

-- State watching (for debugging)
function StateInspector.watchState(processId, callback)
    StateRegistry.watchedStates[processId] = callback
end

function StateInspector.unwatchState(processId)
    StateRegistry.watchedStates[processId] = nil
end

function StateInspector.notifyStateChange(processId, oldState, newState)
    local callback = StateRegistry.watchedStates[processId]
    if callback then
        callback(processId, oldState, newState)
    end
    
    -- Add to state history
    StateRegistry.stateHistory[processId] = StateRegistry.stateHistory[processId] or {}
    table.insert(StateRegistry.stateHistory[processId], {
        timestamp = os.clock() * 1000,
        oldState = StateInspector.deepCopy(oldState),
        newState = StateInspector.deepCopy(newState)
    })
end

-- State history management
function StateInspector.getStateHistory(processId)
    return StateRegistry.stateHistory[processId] or {}
end

function StateInspector.clearStateHistory(processId)
    if processId then
        StateRegistry.stateHistory[processId] = {}
    else
        StateRegistry.stateHistory = {}
    end
end

-- Cleanup
function StateInspector.reset()
    StateRegistry.snapshots = {}
    StateRegistry.watchedStates = {}
    StateRegistry.stateHistory = {}
    -- Keep validation rules as they're reusable
end

return StateInspector