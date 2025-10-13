-- AO Handler Patterns (REQUIRED)
-- Proper handler implementation for AO processes

-- ❌ FORBIDDEN: Direct assignment
Handlers["ProcessLogic"] = function(msg) end

-- ❌ FORBIDDEN: Multi-action handlers (won't work in AO runtime)
Handlers.add("multi-handler",
    Handlers.utils.hasMatchingTag("Action", {"Action1", "Action2", "Action3"}),
    function(msg) end
)

-- ✅ REQUIRED: Individual handlers for each action
Handlers.add("action-one",
    Handlers.utils.hasMatchingTag("Action", "Action1"),
    function(msg)
        -- Validate input
        if not msg.RequiredParam then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "RequiredParam is required"
            })
            return
        end

        -- Process action
        local result = processAction1(msg)

        -- Send response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result)
        })
    end
)

Handlers.add("action-two",
    Handlers.utils.hasMatchingTag("Action", "Action2"),
    function(msg)
        local result = processAction2(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode(result)
        })
    end
)

-- ✅ REQUIRED: Info handler for ADP v1.0 compliance
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = json.encode({
                process = {
                    name = "Process Name",
                    version = "1.0.0",
                    adpVersion = "1.0",
                    capabilities = {"Action1", "Action2"}
                },
                handlers = {"action-one", "action-two", "info"}
            })
        })
    end
)
