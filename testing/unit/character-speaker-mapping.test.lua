-- Unit tests for Character Speaker Mapping
local testMessages, testHandlers = {}, {}
local mockAO = {id = "test", send = function(msg) table.insert(testMessages, msg) return true end}
local mockHandlers = {add = function(n, m, h) testHandlers[n] = {matcher = m, handler = h} end, utils = {hasMatchingTag = function(t, v) return function(msg) return msg[t] == v end end}}
local mockJSON = {encode = function(t) return "json" end, decode = function(s) return {} end}
local function setup() testMessages, testHandlers = {}, {}; _G.ao, _G.Handlers, _G.json = mockAO, mockHandlers, mockJSON; package.loaded.json = mockJSON end
local function send(h, m) local handler = testHandlers[h]; if not handler then error("Handler not found") end; if not handler.matcher(m) then error("Mismatch") end; testMessages = {}; handler.handler(m); return testMessages end
local function load() setup(); dofile("processes/character-dialogue-engine.lua") end

local function test()
    local tests, total, passed, failed = {}, 0, 0, 0
    
    tests["speaker_youngster"] = function() load(); local r = send("get-speaker-name", {From="c", Action="GetSpeakerName", TrainerType="50"}); assert(r[1].Action == "SaveState"); print("✓ Youngster speaker"); return true end
    tests["speaker_ace_trainer"] = function() load(); local r = send("get-speaker-name", {From="c", Action="GetSpeakerName", TrainerType="1"}); assert(r[1].Action == "SaveState"); print("✓ Ace Trainer speaker"); return true end
    tests["speaker_invalid"] = function() load(); local r = send("get-speaker-name", {From="c", Action="GetSpeakerName", TrainerType="999"}); assert(r[1].Action ~= nil); print("✓ Invalid speaker"); return true end
    
    for name, func in pairs(tests) do total = total + 1; print("\n" .. name); local ok, err = pcall(func); if ok then passed = passed + 1 else failed = failed + 1; print("❌ " .. tostring(err)) end end
    print("\n" .. string.rep("=", 60)); print("Speaker Mapping Tests: " .. passed .. "/" .. total .. " passed"); print(string.rep("=", 60)); return failed == 0
end

local success = test()
return {runTests = function() return success end}
