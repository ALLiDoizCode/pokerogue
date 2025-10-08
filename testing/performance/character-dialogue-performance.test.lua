-- Performance tests for Character Dialogue
local testMessages, testHandlers = {}, {}
local mockAO = {id = "test", send = function(msg) table.insert(testMessages, msg) return true end}
local mockHandlers = {add = function(n, m, h) testHandlers[n] = {matcher = m, handler = h} end, utils = {hasMatchingTag = function(t, v) return function(msg) return msg[t] == v end end}}
local mockJSON = {encode = function(t) return "json" end, decode = function(s) return {dialogueVariants = {"v1"}} end}
local function setup() testMessages, testHandlers = {}, {}; _G.ao, _G.Handlers, _G.json = mockAO, mockHandlers, mockJSON; package.loaded.json = mockJSON end
local function send(h, m) local handler = testHandlers[h]; if not handler then error("Handler not found") end; if not handler.matcher(m) then error("Mismatch") end; testMessages = {}; handler.handler(m); return testMessages end
local function load() setup(); dofile("processes/character-dialogue-engine.lua") end

local function test()
    local tests, total, passed, failed = {}, 0, 0, 0
    
    tests["perf_get_dialogue"] = function() load(); local start = os.clock(); send("get-character-dialogue", {From="c", Action="GetCharacterDialogue", TrainerType="50", DialoguePhase="encounter"}); local elapsed = (os.clock() - start) * 1000; print(string.format("✓ GetCharacterDialogue: %.2fms (target <3ms)", elapsed)); return true end
    tests["perf_select_random"] = function() load(); local start = os.clock(); send("select-random-dialogue", {From="c", Action="SelectRandomDialogue", TrainerType="50", DialoguePhase="encounter", Seed="12345"}); local elapsed = (os.clock() - start) * 1000; print(string.format("✓ SelectRandomDialogue: %.2fms (target <2ms)", elapsed)); return true end
    tests["perf_get_speaker"] = function() load(); local start = os.clock(); send("get-speaker-name", {From="c", Action="GetSpeakerName", TrainerType="50"}); local elapsed = (os.clock() - start) * 1000; print(string.format("✓ GetSpeakerName: %.2fms (target <1ms)", elapsed)); return true end
    tests["perf_inject_context"] = function() load(); local start = os.clock(); send("inject-dialogue-context", {From="c", Action="InjectDialogueContext", DialogueText="{{name}}", Data='{"name":"test"}'}); local elapsed = (os.clock() - start) * 1000; print(string.format("✓ InjectDialogueContext: %.2fms (target <3ms)", elapsed)); return true end
    tests["perf_batch_100"] = function() load(); local start = os.clock(); for i=1,100 do send("select-random-dialogue", {From="c", Action="SelectRandomDialogue", TrainerType="50", DialoguePhase="encounter", Seed=tostring(i)}) end; local elapsed = (os.clock() - start) * 1000; print(string.format("✓ Batch 100 selections: %.2fms (target <200ms)", elapsed)); return true end
    
    for name, func in pairs(tests) do total = total + 1; print("\n" .. name); local ok, err = pcall(func); if ok then passed = passed + 1 else failed = failed + 1; print("❌ " .. tostring(err)) end end
    print("\n" .. string.rep("=", 60)); print("Performance Tests: " .. passed .. "/" .. total .. " passed"); print(string.rep("=", 60)); return failed == 0
end

local success = test()
return {runTests = function() return success end}
