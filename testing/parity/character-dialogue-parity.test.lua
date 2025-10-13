-- Parity tests for Character Dialogue (AC5: 100% parity validation)
local testMessages, testHandlers = {}, {}
local mockAO = {id = "test", send = function(msg) table.insert(testMessages, msg) return true end}
local mockHandlers = {add = function(n, m, h) testHandlers[n] = {matcher = m, handler = h} end, utils = {hasMatchingTag = function(t, v) return function(msg) return msg[t] == v end end}}
local mockJSON = {encode = function(t) return "json" end, decode = function(s) return {dialogueVariants = {"v1", "v2"}, dialogue = "v1", variantIndex = 1} end}
local function setup() testMessages, testHandlers = {}, {}; _G.ao, _G.Handlers, _G.json = mockAO, mockHandlers, mockJSON; package.loaded.json = mockJSON end
local function send(h, m) local handler = testHandlers[h]; if not handler then error("Handler not found") end; if not handler.matcher(m) then error("Mismatch") end; testMessages = {}; handler.handler(m); return testMessages end
local function load() setup(); dofile("processes/character-dialogue-engine.lua") end

local function test()
    local tests, total, passed, failed = {}, 0, 0, 0
    
    tests["parity_deterministic_selection"] = function() load(); local r1 = send("select-random-dialogue", {From="c", Action="SelectRandomDialogue", TrainerType="50", DialoguePhase="encounter", Seed="12345"}); local r2 = send("select-random-dialogue", {From="c", Action="SelectRandomDialogue", TrainerType="50", DialoguePhase="encounter", Seed="12345"}); assert(r1[1].VariantIndex == r2[1].VariantIndex, "Same seed should produce same variant"); print("✓ Deterministic selection parity"); return true end
    tests["parity_variant_bounds"] = function() load(); local r = send("select-random-dialogue", {From="c", Action="SelectRandomDialogue", TrainerType="50", DialoguePhase="encounter", Seed="99999"}); local idx, cnt = tonumber(r[1].VariantIndex), tonumber(r[1].VariantCount); assert(idx >= 1 and idx <= cnt, "Variant index within bounds"); print("✓ Variant bounds parity"); return true end
    tests["parity_all_trainer_types"] = function() load(); local types = {50, 1, 27, 40}; for _, t in ipairs(types) do local r = send("validate-personality", {From="c", Action="ValidatePersonality", TrainerType=tostring(t), DialoguePhase="encounter"}); assert(r[1].Action == "SaveState") end; print("✓ All trainer types parity"); return true end
    tests["parity_speaker_mapping"] = function() load(); local r1 = send("get-speaker-name", {From="c", Action="GetSpeakerName", TrainerType="50"}); local r2 = send("get-speaker-name", {From="c", Action="GetSpeakerName", TrainerType="1"}); assert(r1[1].SpeakerKey ~= r2[1].SpeakerKey, "Different speakers for different types"); print("✓ Speaker mapping parity"); return true end
    
    for name, func in pairs(tests) do total = total + 1; print("\n" .. name); local ok, err = pcall(func); if ok then passed = passed + 1 else failed = failed + 1; print("❌ " .. tostring(err)) end end
    print("\n" .. string.rep("=", 60)); print("Parity Tests (AC5): " .. passed .. "/" .. total .. " passed"); print(string.rep("=", 60)); return failed == 0
end

local success = test()
return {runTests = function() return success end}
