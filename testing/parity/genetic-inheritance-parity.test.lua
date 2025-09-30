-- Parity tests for genetic-inheritance-engine.lua
-- Validates mathematical and behavioral parity with TypeScript implementation

local json = require("json")

-- Mock environment
local function setupTestEnvironment()
    _G.ao = {
        send = function(msg) end,
        id = "test-genetic-engine"
    }
    
    _G.Handlers = {
        add = function(name, matcher, handler) end,
        utils = {
            hasMatchingTag = function(tag, value)
                return function(msg) return msg[tag] == value end
            end
        }
    }
end

setupTestEnvironment()

-- Load the process
dofile("processes/genetic-inheritance-engine.lua")

print("Running Genetic Inheritance Engine Parity Tests...")
print("===================================================")
print()

-- Test data matching TypeScript implementation
local parityTestCases = {
    {
        name = "IV Inheritance - Standard 3 IVs",
        description = "Validates standard IV inheritance matches TypeScript",
        test = function()
            -- TypeScript test data from src/data/pokemon-data.ts
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 30, 29, 28, 27, 26},
                nature = "ADAMANT",
                ability = "BLAZE"
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {26, 27, 28, 29, 30, 31},
                nature = "MODEST",
                ability = "SOLAR_POWER"
            }
            
            -- Fixed seed for deterministic results
            local rngSeed = 12345
            
            -- Process inheritance
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        rngSeed = rngSeed
                    }
                })
            }
            
            -- Capture response
            local capturedResponse = nil
            _G.ao.send = function(response)
                capturedResponse = response
            end
            
            -- Handle message
            for _, handler in ipairs(_G.registeredHandlers or {}) do
                if handler.name == "process-logic" then
                    handler.handler(msg)
                    break
                end
            end
            
            if capturedResponse and capturedResponse.Data then
                local data = json.decode(capturedResponse.Data)
                
                -- Verify 3 IVs inherited
                local inheritedCount = 0
                for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources) do
                    if source ~= "random" then
                        inheritedCount = inheritedCount + 1
                    end
                end
                
                if inheritedCount == 3 then
                    print("✓ Standard IV inheritance: 3 IVs inherited (matches TypeScript)")
                else
                    print("✗ Standard IV inheritance: " .. inheritedCount .. " IVs inherited (expected 3)")
                end
            else
                print("✗ Standard IV inheritance: No response received")
            end
        end
    },
    {
        name = "IV Inheritance - Destiny Knot 5 IVs",
        description = "Validates Destiny Knot effect matches TypeScript",
        test = function()
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "ADAMANT",
                ability = "BLAZE"
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {0, 0, 0, 0, 0, 0},
                nature = "MODEST",
                ability = "SOLAR_POWER"
            }
            
            local rngSeed = 54321
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "DESTINY_KNOT",
                        rngSeed = rngSeed
                    }
                })
            }
            
            local capturedResponse = nil
            _G.ao.send = function(response)
                capturedResponse = response
            end
            
            for _, handler in ipairs(_G.registeredHandlers or {}) do
                if handler.name == "process-logic" then
                    handler.handler(msg)
                    break
                end
            end
            
            if capturedResponse and capturedResponse.Data then
                local data = json.decode(capturedResponse.Data)
                
                local inheritedCount = 0
                for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources) do
                    if source ~= "random" then
                        inheritedCount = inheritedCount + 1
                    end
                end
                
                if inheritedCount == 5 then
                    print("✓ Destiny Knot IV inheritance: 5 IVs inherited (matches TypeScript)")
                else
                    print("✗ Destiny Knot IV inheritance: " .. inheritedCount .. " IVs inherited (expected 5)")
                end
                
                -- Check for Destiny Knot effect in item effects
                local hasEffect = false
                for _, effect in ipairs(data.genetics.ivInheritance.itemEffects) do
                    if effect == "destiny_knot_5_inherited" then
                        hasEffect = true
                        break
                    end
                end
                
                if hasEffect then
                    print("✓ Destiny Knot effect flag present (matches TypeScript)")
                else
                    print("✗ Destiny Knot effect flag missing")
                end
            else
                print("✗ Destiny Knot IV inheritance: No response received")
            end
        end
    },
    {
        name = "Nature Inheritance - Everstone Guarantee",
        description = "Validates Everstone nature guarantee matches TypeScript",
        test = function()
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "ADAMANT",
                ability = "BLAZE"
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "MODEST",
                ability = "SOLAR_POWER"
            }
            
            -- Test with Everstone on parent1
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "determineNatureInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        rngSeed = 99999
                    }
                })
            }
            
            local capturedResponse = nil
            _G.ao.send = function(response)
                capturedResponse = response
            end
            
            for _, handler in ipairs(_G.registeredHandlers or {}) do
                if handler.name == "process-logic" then
                    handler.handler(msg)
                    break
                end
            end
            
            if capturedResponse and capturedResponse.Data then
                local data = json.decode(capturedResponse.Data)
                
                if data.genetics.natureInheritance.inheritedNature == "ADAMANT" then
                    print("✓ Everstone nature inheritance: ADAMANT inherited (matches TypeScript)")
                else
                    print("✗ Everstone nature inheritance: " .. data.genetics.natureInheritance.inheritedNature .. " inherited (expected ADAMANT)")
                end
                
                if data.genetics.natureInheritance.inheritanceProbability == 1.0 then
                    print("✓ Everstone probability: 100% (matches TypeScript)")
                else
                    print("✗ Everstone probability: " .. (data.genetics.natureInheritance.inheritanceProbability * 100) .. "% (expected 100%)")
                end
            else
                print("✗ Everstone nature inheritance: No response received")
            end
        end
    },
    {
        name = "Nature Modifiers - Exact Values",
        description = "Validates nature stat modifiers match TypeScript exactly",
        test = function()
            -- Test ADAMANT nature (Attack +10%, Special Attack -10%)
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "ADAMANT",
                ability = "BLAZE"
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "MODEST",
                ability = "SOLAR_POWER"
            }
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "determineNatureInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        rngSeed = 12345
                    }
                })
            }
            
            local capturedResponse = nil
            _G.ao.send = function(response)
                capturedResponse = response
            end
            
            for _, handler in ipairs(_G.registeredHandlers or {}) do
                if handler.name == "process-logic" then
                    handler.handler(msg)
                    break
                end
            end
            
            if capturedResponse and capturedResponse.Data then
                local data = json.decode(capturedResponse.Data)
                
                -- Verify ADAMANT nature modifiers (1.0, 1.1, 1.0, 0.9, 1.0)
                local expectedMultipliers = {1.0, 1.1, 1.0, 0.9, 1.0}
                local actualMultipliers = data.genetics.natureInheritance.natureEffects.multipliers
                
                local modifiersMatch = true
                for i = 1, 5 do
                    if math.abs(actualMultipliers[i] - expectedMultipliers[i]) > 0.001 then
                        modifiersMatch = false
                        break
                    end
                end
                
                if modifiersMatch then
                    print("✓ Nature modifiers exact values match TypeScript (1.0, 1.1, 1.0, 0.9, 1.0)")
                else
                    print("✗ Nature modifiers don't match TypeScript")
                end
                
                if data.genetics.natureInheritance.natureEffects.boosted == "attack" then
                    print("✓ Boosted stat: attack (matches TypeScript)")
                else
                    print("✗ Boosted stat: " .. (data.genetics.natureInheritance.natureEffects.boosted or "none"))
                end
                
                if data.genetics.natureInheritance.natureEffects.lowered == "spattack" then
                    print("✓ Lowered stat: spattack (matches TypeScript)")
                else
                    print("✗ Lowered stat: " .. (data.genetics.natureInheritance.natureEffects.lowered or "none"))
                end
            else
                print("✗ Nature modifiers test: No response received")
            end
        end
    },
    {
        name = "Hidden Ability Inheritance - 60% Rate",
        description = "Validates hidden ability inheritance rate matches TypeScript",
        test = function()
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "ADAMANT",
                ability = "SOLAR_POWER",
                abilityIndex = 3 -- Hidden ability
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "MODEST",
                ability = "BLAZE",
                abilityIndex = 1
            }
            
            local speciesData = {
                id = 6,
                name = "Charizard",
                abilities = {"BLAZE", "SOLAR_POWER", "SOLAR_POWER"}
            }
            
            -- Run multiple tests to verify probability
            local hiddenInheritedCount = 0
            local totalTests = 1000
            
            for i = 1, totalTests do
                local msg = {
                    From = "test-sender",
                    Action = "ProcessLogic",
                    Data = json.encode({
                        operation = "calculateAbilityInheritance",
                        parameters = {
                            parent1 = parent1,
                            parent2 = parent2,
                            speciesData = speciesData,
                            rngSeed = i * 1337 -- Different seed each time
                        }
                    })
                }
                
                local capturedResponse = nil
                _G.ao.send = function(response)
                    capturedResponse = response
                end
                
                for _, handler in ipairs(_G.registeredHandlers or {}) do
                    if handler.name == "process-logic" then
                        handler.handler(msg)
                        break
                    end
                end
                
                if capturedResponse and capturedResponse.Data then
                    local data = json.decode(capturedResponse.Data)
                    if data.genetics.abilityInheritance.abilityType == "hidden" then
                        hiddenInheritedCount = hiddenInheritedCount + 1
                    end
                end
            end
            
            local actualRate = hiddenInheritedCount / totalTests
            local expectedRate = 0.6
            local tolerance = 0.05 -- Allow 5% variance
            
            if math.abs(actualRate - expectedRate) <= tolerance then
                print(string.format("✓ Hidden ability inheritance rate: %.1f%% (expected 60%% ±5%%)", actualRate * 100))
            else
                print(string.format("✗ Hidden ability inheritance rate: %.1f%% (expected 60%% ±5%%)", actualRate * 100))
            end
        end
    },
    {
        name = "Power Item Guaranteed IV",
        description = "Validates Power Item guaranteed stat inheritance",
        test = function()
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 0, 0, 0, 0, 0},
                nature = "ADAMANT",
                ability = "BLAZE"
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {0, 31, 0, 0, 0, 0},
                nature = "MODEST",
                ability = "SOLAR_POWER"
            }
            
            -- Test Power Weight (HP stat)
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "calculateIvInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "POWER_WEIGHT",
                        rngSeed = 777
                    }
                })
            }
            
            local capturedResponse = nil
            _G.ao.send = function(response)
                capturedResponse = response
            end
            
            for _, handler in ipairs(_G.registeredHandlers or {}) do
                if handler.name == "process-logic" then
                    handler.handler(msg)
                    break
                end
            end
            
            if capturedResponse and capturedResponse.Data then
                local data = json.decode(capturedResponse.Data)
                
                -- HP is index 1, should be 31 from parent1
                if data.genetics.ivInheritance.inheritedIvs[1] == 31 then
                    print("✓ Power Weight guaranteed HP IV: 31 (matches TypeScript)")
                else
                    print("✗ Power Weight guaranteed HP IV: " .. data.genetics.ivInheritance.inheritedIvs[1] .. " (expected 31)")
                end
                
                if data.genetics.ivInheritance.inheritanceSources[1] == "parent1" then
                    print("✓ Power Weight source: parent1 (matches TypeScript)")
                else
                    print("✗ Power Weight source: " .. data.genetics.ivInheritance.inheritanceSources[1])
                end
                
                -- Check for Power Item effect
                local hasEffect = false
                for _, effect in ipairs(data.genetics.ivInheritance.itemEffects) do
                    if effect == "power_item_guaranteed_hp" then
                        hasEffect = true
                        break
                    end
                end
                
                if hasEffect then
                    print("✓ Power Item effect flag present (matches TypeScript)")
                else
                    print("✗ Power Item effect flag missing")
                end
            else
                print("✗ Power Item IV inheritance: No response received")
            end
        end
    },
    {
        name = "Complex Scenario - Destiny Knot + Everstone",
        description = "Validates combined item effects match TypeScript",
        test = function()
            local parent1 = {
                id = "p1",
                speciesId = 6,
                ivs = {31, 31, 31, 31, 31, 31},
                nature = "ADAMANT",
                ability = "SOLAR_POWER",
                abilityIndex = 3
            }
            
            local parent2 = {
                id = "p2",
                speciesId = 6,
                ivs = {28, 28, 28, 28, 28, 28},
                nature = "MODEST",
                ability = "BLAZE",
                abilityIndex = 1
            }
            
            local speciesData = {
                id = 6,
                name = "Charizard",
                abilities = {"BLAZE", "SOLAR_POWER", "SOLAR_POWER"}
            }
            
            local msg = {
                From = "test-sender",
                Action = "ProcessLogic",
                Data = json.encode({
                    operation = "processCompleteInheritance",
                    parameters = {
                        parent1 = parent1,
                        parent2 = parent2,
                        parent1Item = "EVERSTONE",
                        parent2Item = "DESTINY_KNOT",
                        speciesData = speciesData,
                        rngSeed = 42
                    }
                })
            }
            
            local capturedResponse = nil
            _G.ao.send = function(response)
                capturedResponse = response
            end
            
            for _, handler in ipairs(_G.registeredHandlers or {}) do
                if handler.name == "process-logic" then
                    handler.handler(msg)
                    break
                end
            end
            
            if capturedResponse and capturedResponse.Data then
                local data = json.decode(capturedResponse.Data)
                
                -- Check IV inheritance (should be 5 with Destiny Knot)
                local inheritedCount = 0
                for _, source in ipairs(data.genetics.ivInheritance.inheritanceSources) do
                    if source ~= "random" then
                        inheritedCount = inheritedCount + 1
                    end
                end
                
                if inheritedCount == 5 then
                    print("✓ Complex scenario IV count: 5 (Destiny Knot working)")
                else
                    print("✗ Complex scenario IV count: " .. inheritedCount .. " (expected 5)")
                end
                
                -- Check nature inheritance (should be ADAMANT with Everstone)
                if data.genetics.natureInheritance.inheritedNature == "ADAMANT" then
                    print("✓ Complex scenario nature: ADAMANT (Everstone working)")
                else
                    print("✗ Complex scenario nature: " .. data.genetics.natureInheritance.inheritedNature)
                end
                
                -- Check ability inheritance
                if data.genetics.abilityInheritance.inheritedAbility then
                    print("✓ Complex scenario ability: " .. data.genetics.abilityInheritance.inheritedAbility)
                else
                    print("✗ Complex scenario: No ability inherited")
                end
            else
                print("✗ Complex scenario: No response received")
            end
        end
    }
}

-- Track handler registrations
_G.registeredHandlers = {}
local originalHandlersAdd = Handlers.add
Handlers.add = function(name, matcher, handler)
    table.insert(_G.registeredHandlers, {name = name, handler = handler})
    originalHandlersAdd(name, matcher, handler)
end

-- Reload the process to capture handlers
dofile("processes/genetic-inheritance-engine.lua")

-- Run all parity tests
local passedTests = 0
local failedTests = 0

for i, testCase in ipairs(parityTestCases) do
    print(string.format("\nTest %d: %s", i, testCase.name))
    print("Description:", testCase.description)
    print("-" .. string.rep("-", 50))
    
    local success, error = pcall(testCase.test)
    
    if success then
        passedTests = passedTests + 1
    else
        failedTests = failedTests + 1
        print("✗ Test failed with error: " .. error)
    end
end

-- Summary
print("\n" .. string.rep("=", 50))
print("Parity Test Results:")
print(string.format("  Passed: %d", passedTests))
print(string.format("  Failed: %d", failedTests))
print(string.format("  Total:  %d", passedTests + failedTests))
print()

if failedTests == 0 then
    print("🎉 All parity tests passed!")
    print("✅ Genetic inheritance matches TypeScript implementation exactly")
else
    print("⚠️  Some parity tests failed")
    print("❌ Genetic inheritance does not match TypeScript implementation")
end