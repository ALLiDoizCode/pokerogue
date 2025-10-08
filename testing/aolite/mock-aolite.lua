-- Mock Aolite Framework for Unit Testing
-- Provides lightweight process execution without full aolite infrastructure dependencies

local MockAolite = {}

-- Storage for spawned processes
local processes = {}
local processCounter = 0

-- Mock ao global for processes
local function createAoEnvironment(processId)
    local messageQueue = {}

    return {
        id = processId,
        send = function(msg)
            table.insert(messageQueue, msg)
            return msg
        end,
        _getMessages = function()
            return messageQueue
        end,
        _clearMessages = function()
            messageQueue = {}
        end
    }
end

-- Mock Handlers global for processes
local function createHandlersEnvironment()
    local handlers = {}

    return {
        add = function(name, matcher, handler)
            table.insert(handlers, {
                name = name,
                matcher = matcher,
                handler = handler
            })
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    if type(tagValue) == "table" then
                        for _, v in ipairs(tagValue) do
                            if msg[tagName] == v then
                                return true
                            end
                        end
                        return false
                    else
                        return msg[tagName] == tagValue
                    end
                end
            end,
        },
        _getHandlers = function()
            return handlers
        end,
        _findHandler = function(msg)
            for _, h in ipairs(handlers) do
                if h.matcher(msg) then
                    return h
                end
            end
            return nil
        end,
    }
end

-- Spawn a process from file path
function MockAolite.spawnProcess(originalId, dataOrPath, tags)
    processCounter = processCounter + 1
    local processId = "mock-process-" .. processCounter

    -- Create process environment
    local processEnv = {
        ao = createAoEnvironment(processId),
        Handlers = createHandlersEnvironment(),
        json = require("json"),
        require = require,
        print = print,
        error = error,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        tonumber = tonumber,
        tostring = tostring,
        table = table,
        string = string,
        math = math,
        os = os,
        _G = _G
    }

    -- Load the process file
    local chunk, err = loadfile(dataOrPath, "t", processEnv)
    if not chunk then
        error("Failed to load process file '" .. dataOrPath .. "': " .. tostring(err))
    end

    -- Execute the process file to register handlers
    local success, result = pcall(chunk)
    if not success then
        error("Failed to execute process file '" .. dataOrPath .. "': " .. tostring(result))
    end

    -- Store process
    processes[processId] = {
        id = processId,
        originalId = originalId,
        env = processEnv,
        ao = processEnv.ao,
        handlers = processEnv.Handlers
    }

    return processId
end

-- Send a message to a process
function MockAolite.send(msg)
    local processId = msg.Target
    local process = processes[processId]

    if not process then
        error("Process not found: " .. tostring(processId))
    end

    -- Set From if not provided
    if not msg.From then
        msg.From = "mock-sender"
    end

    -- Find matching handler
    local handler = process.handlers._findHandler(msg)
    if not handler then
        return {
            Action = "Error",
            Error = "No handler found for action: " .. tostring(msg.Action),
            From = processId,
            Target = msg.From
        }
    end

    -- Clear previous messages
    process.ao._clearMessages()

    -- Execute handler
    local success, err = pcall(handler.handler, msg)
    if not success then
        return {
            Action = "Error",
            Error = "Handler execution failed: " .. tostring(err),
            From = processId,
            Target = msg.From
        }
    end

    -- Get response messages
    local messages = process.ao._getMessages()
    if #messages > 0 then
        return messages[#messages]  -- Return last message
    end

    return {
        Action = "Success",
        From = processId,
        Target = msg.From
    }
end

-- Eval code in process context
function MockAolite.eval(processId, code)
    local process = processes[processId]

    if not process then
        error("Process not found: " .. tostring(processId))
    end

    local chunk, err = load(code, "eval", "t", process.env)
    if not chunk then
        return { success = false, error = err }
    end

    local success, result = pcall(chunk)
    return { success = success, result = result }
end

-- Get process by ID
function MockAolite.getProcess(processId)
    return processes[processId]
end

-- Clear all processes
function MockAolite.clearAll()
    processes = {}
    processCounter = 0
end

return MockAolite
