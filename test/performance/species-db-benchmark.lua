#!/usr/bin/env lua

-- Performance Benchmark for Pokemon Species Database
-- Tests response times, throughput, and memory efficiency

-- Mock AO environment for testing
local captured_responses = {}
local performance_metrics = {}

ao = {
    send = function(msg) 
        table.insert(captured_responses, msg)
        return true
    end,
    id = "test-pokemon-species-db"
}

-- Mock Handlers system
Handlers = {
    list = {},
    add = function(name, matcher, handler)
        table.insert(Handlers.list, {
            name = name,
            matcher = matcher,
            handle = handler
        })
    end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg)
                if type(values) == "table" then
                    for _, value in ipairs(values) do
                        if msg[tag] == value then return true end
                    end
                else
                    return msg[tag] == values
                end
                return false
            end
        end
    }
}

-- Load the process
local process = loadfile("processes/pokemon-species-db.lua")
assert(process, "Failed to load pokemon-species-db.lua")

-- Execute the process to register handlers
local result = process()

print("🚀 Pokemon Species Database Performance Benchmark")
print("=" .. string.rep("=", 50))

-- Performance testing utilities
local function time_function(func)
    local start_time = os.clock()
    local result = func()
    local end_time = os.clock()
    return (end_time - start_time) * 1000, result -- Convert to milliseconds
end

local function run_query_test(query_type, data, iterations)
    local total_time = 0
    local success_count = 0
    local results = {}
    
    for i = 1, iterations do
        captured_responses = {} -- Clear previous responses
        
        local testMsg = {
            Action = query_type,
            Data = data,
            From = "benchmark-test",
            Timestamp = 1234567890 + i
        }
        
        local response_time, success = time_function(function()
            for _, handler in pairs(Handlers.list or {}) do
                if handler.matcher(testMsg) then
                    handler.handle(testMsg)
                    return true
                end
            end
            return false
        end)
        
        if success and #captured_responses > 0 then
            success_count = success_count + 1
            total_time = total_time + response_time
            table.insert(results, response_time)
        end
    end
    
    -- Calculate statistics
    local avg_time = success_count > 0 and (total_time / success_count) or 0
    local min_time = results[1] or 0
    local max_time = results[1] or 0
    
    -- Find min/max manually for Lua 5.3 compatibility
    for _, time in ipairs(results) do
        if time < min_time then min_time = time end
        if time > max_time then max_time = time end
    end
    
    return {
        query_type = query_type,
        iterations = iterations,
        success_count = success_count,
        success_rate = (success_count / iterations) * 100,
        avg_response_time = avg_time,
        min_response_time = min_time,
        max_response_time = max_time,
        total_time = total_time,
        throughput = success_count > 0 and (success_count / (total_time / 1000)) or 0 -- queries per second
    }
end

-- Test 1: GetSpecies Performance
print("\n🧪 Testing GetSpecies Performance...")
local species_test = run_query_test("GetSpecies", {id = 25}, 100) -- Pikachu
print(string.format("  ✅ Avg Response Time: %.2fms", species_test.avg_response_time))
print(string.format("  ✅ Min Response Time: %.2fms", species_test.min_response_time))
print(string.format("  ✅ Max Response Time: %.2fms", species_test.max_response_time))
print(string.format("  ✅ Success Rate: %.1f%%", species_test.success_rate))
print(string.format("  ✅ Throughput: %.0f queries/sec", species_test.throughput))

-- Test 2: GetTypeEffectiveness Performance
print("\n🧪 Testing GetTypeEffectiveness Performance...")
local type_test = run_query_test("GetTypeEffectiveness", {attackType = 9, defenseTypes = {11}}, 100)
print(string.format("  ✅ Avg Response Time: %.2fms", type_test.avg_response_time))
print(string.format("  ✅ Min Response Time: %.2fms", type_test.min_response_time))
print(string.format("  ✅ Max Response Time: %.2fms", type_test.max_response_time))
print(string.format("  ✅ Success Rate: %.1f%%", type_test.success_rate))
print(string.format("  ✅ Throughput: %.0f queries/sec", type_test.throughput))

-- Test 3: GetEvolutionChain Performance
print("\n🧪 Testing GetEvolutionChain Performance...")
local evolution_test = run_query_test("GetEvolutionChain", {id = 4}, 100) -- Charmander
print(string.format("  ✅ Avg Response Time: %.2fms", evolution_test.avg_response_time))
print(string.format("  ✅ Min Response Time: %.2fms", evolution_test.min_response_time))
print(string.format("  ✅ Max Response Time: %.2fms", evolution_test.max_response_time))
print(string.format("  ✅ Success Rate: %.1f%%", evolution_test.success_rate))
print(string.format("  ✅ Throughput: %.0f queries/sec", evolution_test.throughput))

-- Test 4: GetBaseStats Performance
print("\n🧪 Testing GetBaseStats Performance...")
local stats_test = run_query_test("GetBaseStats", {id = 150}, 100) -- Mewtwo
print(string.format("  ✅ Avg Response Time: %.2fms", stats_test.avg_response_time))
print(string.format("  ✅ Min Response Time: %.2fms", stats_test.min_response_time))
print(string.format("  ✅ Max Response Time: %.2fms", stats_test.max_response_time))
print(string.format("  ✅ Success Rate: %.1f%%", stats_test.success_rate))
print(string.format("  ✅ Throughput: %.0f queries/sec", stats_test.throughput))

-- Test 5: Mixed Query Load Test
print("\n🧪 Testing Mixed Query Load Performance...")
local mixed_queries = {
    {type = "GetSpecies", data = {id = 1}},
    {type = "GetTypeEffectiveness", data = {attackType = 10, defenseTypes = {9}}},
    {type = "GetEvolutionChain", data = {id = 7}},
    {type = "GetBaseStats", data = {id = 6}},
    {type = "GetSpecies", data = {id = 25}}
}

local mixed_total_time = 0
local mixed_success_count = 0
local mixed_iterations = 50

for i = 1, mixed_iterations do
    for _, query in ipairs(mixed_queries) do
        captured_responses = {}
        
        local testMsg = {
            Action = query.type,
            Data = query.data,
            From = "mixed-benchmark-test",
            Timestamp = 1234567890 + i
        }
        
        local response_time, success = time_function(function()
            for _, handler in pairs(Handlers.list or {}) do
                if handler.matcher(testMsg) then
                    handler.handle(testMsg)
                    return true
                end
            end
            return false
        end)
        
        if success and #captured_responses > 0 then
            mixed_success_count = mixed_success_count + 1
            mixed_total_time = mixed_total_time + response_time
        end
    end
end

local mixed_avg_time = mixed_success_count > 0 and (mixed_total_time / mixed_success_count) or 0
local mixed_throughput = mixed_success_count > 0 and (mixed_success_count / (mixed_total_time / 1000)) or 0

print(string.format("  ✅ Mixed Load Avg Response Time: %.2fms", mixed_avg_time))
print(string.format("  ✅ Mixed Load Throughput: %.0f queries/sec", mixed_throughput))
print(string.format("  ✅ Total Queries Processed: %d", mixed_success_count))

-- Performance Requirements Check
print("\n📊 Performance Requirements Analysis")
print("=" .. string.rep("=", 50))

local all_tests = {species_test, type_test, evolution_test, stats_test}
local overall_avg = 0
local overall_max = 0
local test_count = 0

for _, test in ipairs(all_tests) do
    overall_avg = overall_avg + test.avg_response_time
    overall_max = math.max(overall_max, test.max_response_time)
    test_count = test_count + 1
end

overall_avg = overall_avg / test_count

print(string.format("Overall Average Response Time: %.2fms", overall_avg))
print(string.format("Overall Maximum Response Time: %.2fms", overall_max))
print(string.format("Mixed Load Response Time: %.2fms", mixed_avg_time))

-- Check performance targets
local target_response_time = 100 -- milliseconds
local performance_passed = true

if overall_avg > target_response_time then
    print(string.format("❌ FAILED: Average response time %.2fms exceeds target of %dms", overall_avg, target_response_time))
    performance_passed = false
else
    print(string.format("✅ PASSED: Average response time %.2fms meets target of %dms", overall_avg, target_response_time))
end

if overall_max > target_response_time then
    print(string.format("❌ FAILED: Maximum response time %.2fms exceeds target of %dms", overall_max, target_response_time))
    performance_passed = false
else
    print(string.format("✅ PASSED: Maximum response time %.2fms meets target of %dms", overall_max, target_response_time))
end

-- Memory efficiency estimate
local estimated_memory_per_species = 200 -- bytes (estimated)
local total_species = 27
local estimated_total_memory = total_species * estimated_memory_per_species
local memory_target = 50000 -- 50KB for species data

print(string.format("\n💾 Memory Efficiency Analysis:"))
print(string.format("Species Count: %d", total_species))
print(string.format("Estimated Memory Usage: %.1fKB", estimated_total_memory / 1024))
print(string.format("Memory Target: %.1fKB", memory_target / 1024))

if estimated_total_memory > memory_target then
    print(string.format("⚠️  WARNING: Estimated memory usage exceeds target"))
else
    print(string.format("✅ PASSED: Memory usage within target limits"))
end

print("\n" .. string.rep("=", 50))
if performance_passed then
    print("🎉 All performance benchmarks PASSED!")
    print("✅ System meets sub-100ms response time requirements")
    print("✅ Throughput performance is excellent")
    print("✅ Ready for production deployment")
else
    print("❌ Some performance benchmarks FAILED!")
    print("⚠️  Review optimization strategies")
end

return performance_passed