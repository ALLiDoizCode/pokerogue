-- AO Error Handling Patterns
-- Best practices for error handling in AO processes

-- ⚠️ KEY PRINCIPLE: Avoid unnecessary pcall - only use for operations that genuinely might fail

-- ❌ FORBIDDEN: Unnecessary pcall for simple data access
local success, result = pcall(function()
    return getSpeciesById(id)  -- Simple table lookup never fails
end)

-- ❌ FORBIDDEN: Wrapping entire handler logic in pcall
Handlers.add("process-logic",
    Handlers.utils.hasMatchingTag("Action", "ProcessLogic"),
    function(msg)
        local success, response = pcall(function()
            return processLogic(msg)
        end)
        if success then
            ao.send(response)
        else
            ao.send({Target = msg.From, Action = "Error", Error = response})
        end
    end
)

-- ❌ FORBIDDEN: pcall for controlled AO message data
local success, data = pcall(json.decode, msg.Data)  -- msg.Data is controlled

-- ✅ CORRECT: Direct validation and error handling
Handlers.add("my-handler",
    Handlers.utils.hasMatchingTag("Action", "MyAction"),
    function(msg)
        -- Direct parameter validation
        if not msg.RequiredParam then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "RequiredParam missing"
            })
            return
        end

        -- Direct data access (no pcall needed for controlled inputs)
        local data = json.decode(msg.Data or "{}")
        local result = processData(data)

        -- Direct response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result)
        })
    end
)

-- ✅ ACCEPTABLE: Use pcall ONLY for genuinely risky operations
local function processUntrustedInput(externalData)
    -- Only for JSON from untrusted external sources
    local success, parsed = pcall(json.decode, externalData)
    if not success then
        return nil, "Invalid JSON format"
    end
    return parsed, nil
end

-- When to use pcall (VERY LIMITED):
-- 1. JSON parsing of untrusted external input
-- 2. File I/O operations (if available)
-- 3. Mathematical operations that might overflow/underflow
-- 4. Calling external modules that might not exist

-- When NOT to use pcall (MOST CASES):
-- 1. Simple table lookups from embedded data
-- 2. Basic parameter validation
-- 3. Accessing msg tags or known data structures
-- 4. Handler logic that should fail fast
-- 5. JSON parsing of AO message data (controlled inputs)
-- 6. Database lookups from embedded tables
