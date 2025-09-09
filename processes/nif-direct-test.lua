-- NIF Direct Test Process for HyperBeam Local Testing Environment
-- This process demonstrates direct ao.* NIF function calls

State = State or {
    name = "NIF-Direct-Test-Process",
    version = "1.0.0",
    direct_nif_calls = 0,
    results = {},
    start_time = 0
}

-- Initialize the process
if not State.start_time or State.start_time == 0 then
    State.start_time = os.time()
    print("NIF Direct Test Process initialized at " .. State.start_time)
end

-- Handler for testing basic NIF functions directly
Handlers.test_basic = function(msg)
    print("Testing basic NIF functions...")
    State.direct_nif_calls = State.direct_nif_calls + 1
    
    local results = {}
    
    -- Test hello_world directly
    local hello_result = ao.hello_world()
    results.hello = hello_result
    print("ao.hello_world(): " .. tostring(hello_result))
    
    -- Test add_numbers directly  
    local add_result = ao.add_numbers(42, 58)
    results.add = add_result
    print("ao.add_numbers(42, 58): " .. tostring(add_result))
    
    -- Test echo_string directly
    local echo_result = ao.echo_string("Hello from AO Process!")
    results.echo = echo_result
    print("ao.echo_string(): " .. tostring(echo_result))
    
    -- Store results
    State.results[#State.results + 1] = {
        timestamp = os.time(),
        type = "basic_test",
        results = results
    }
    
    -- Send response
    ao.send({
        Target = msg.From,
        Action = "test_basic_response",
        Data = "Basic NIF tests completed. Results: " .. 
               "hello=" .. tostring(hello_result) .. 
               ", add=" .. tostring(add_result) .. 
               ", echo=" .. tostring(echo_result)
    })
end

-- Handler for testing advanced NIF functions
Handlers.test_advanced = function(msg)
    print("Testing advanced NIF functions...")
    State.direct_nif_calls = State.direct_nif_calls + 1
    
    local results = {}
    
    -- Test hash_string directly
    local hash_result = ao.hash_string("Test data for hashing")
    results.hash = hash_result
    print("ao.hash_string(): " .. tostring(hash_result))
    
    -- Test fibonacci directly
    local fib_result = ao.fibonacci(10)
    results.fibonacci = fib_result  
    print("ao.fibonacci(10): " .. tostring(fib_result))
    
    -- Test is_prime directly
    local prime_result = ao.is_prime(97)
    results.prime = prime_result
    print("ao.is_prime(97): " .. tostring(prime_result))
    
    -- Store results
    State.results[#State.results + 1] = {
        timestamp = os.time(),
        type = "advanced_test", 
        results = results
    }
    
    -- Send response
    ao.send({
        Target = msg.From,
        Action = "test_advanced_response",
        Data = "Advanced NIF tests completed. Results: " .. 
               "hash=" .. tostring(hash_result) .. 
               ", fib=" .. tostring(fib_result) .. 
               ", prime=" .. tostring(prime_result)
    })
end

-- Handler for testing JSON-based NIF functions
Handlers.test_json = function(msg)
    print("Testing JSON-based NIF functions...")
    State.direct_nif_calls = State.direct_nif_calls + 1
    
    local results = {}
    
    -- Test advanced_calculate with JSON
    local calc_request = json.encode({
        a = 15.5,
        b = 4.2,
        operation = "multiply"
    })
    
    local calc_result = ao.advanced_calculate(calc_request)
    results.calculation = calc_result
    print("ao.advanced_calculate(): " .. tostring(calc_result))
    
    -- Test batch_operations with JSON
    local batch_request = json.encode({
        operations = {
            {type = "add", a = 10.0, b = 5.0},
            {type = "multiply", a = 3.0, b = 7.0},
            {type = "power", base = 2.0, exp = 8.0},
            {type = "echo", text = "Batch test"}
        }
    })
    
    local batch_result = ao.batch_operations(batch_request)
    results.batch = batch_result
    print("ao.batch_operations(): " .. tostring(batch_result))
    
    -- Store results
    State.results[#State.results + 1] = {
        timestamp = os.time(),
        type = "json_test",
        results = results
    }
    
    -- Send response  
    ao.send({
        Target = msg.From,
        Action = "test_json_response",
        Data = "JSON NIF tests completed. calc=" .. tostring(calc_result) .. 
               ", batch=" .. tostring(batch_result)
    })
end

-- Performance test handler
Handlers.test_performance = function(msg)
    print("Running NIF performance test...")
    local start_time = os.clock()
    local iterations = 100
    
    for i = 1, iterations do
        ao.fibonacci(i % 20)  -- Test with small fibonacci numbers
        State.direct_nif_calls = State.direct_nif_calls + 1
    end
    
    local end_time = os.clock()
    local duration = end_time - start_time
    local calls_per_sec = iterations / duration
    
    local perf_result = {
        iterations = iterations,
        duration = duration,
        calls_per_second = calls_per_sec
    }
    
    State.results[#State.results + 1] = {
        timestamp = os.time(),
        type = "performance_test",
        results = perf_result
    }
    
    print("Performance test completed: " .. iterations .. " calls in " .. 
          string.format("%.3f", duration) .. " seconds (" .. 
          string.format("%.1f", calls_per_sec) .. " calls/sec)")
    
    -- Send response
    ao.send({
        Target = msg.From,
        Action = "test_performance_response", 
        Data = "Performance test: " .. iterations .. " calls in " .. 
               string.format("%.3f", duration) .. "s (" .. 
               string.format("%.1f", calls_per_sec) .. " calls/sec)"
    })
end

-- Status handler
Handlers.status = function(msg)
    local uptime = os.time() - State.start_time
    local status = {
        name = State.name,
        version = State.version,
        uptime = uptime,
        total_nif_calls = State.direct_nif_calls,
        total_tests = #State.results,
        available_commands = {
            "test_basic",
            "test_advanced", 
            "test_json",
            "test_performance",
            "status"
        }
    }
    
    print("Process status requested - uptime: " .. uptime .. "s, NIF calls: " .. State.direct_nif_calls)
    
    ao.send({
        Target = msg.From,
        Action = "status_response",
        Data = json.encode(status)
    })
end

-- Info handler for process information
Handlers.info = function(msg)
    ao.send({
        Target = msg.From,
        Action = "info_response",
        Data = "NIF Direct Test Process - Tests ao.* functions directly without message routing. " ..
               "Commands: test_basic, test_advanced, test_json, test_performance, status"
    })
end

print("NIF Direct Test Process loaded successfully!")
print("Available handlers: test_basic, test_advanced, test_json, test_performance, status, info")
print("This process calls ao.* NIF functions directly for maximum performance.")