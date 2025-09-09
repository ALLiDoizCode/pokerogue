#!/usr/bin/env escript

main(_) ->
    % Add the ebin paths
    code:add_path("hyperbeam-local/_build/default/lib/hyperbeam_local/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/cowboy/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/cowlib/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/ranch/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/jsx/ebin"),
    
    io:format("Testing HyperBeam NIF Functionality...~n"),
    io:format("=====================================~n"),
    
    % Test 1: Start the HyperBeam application
    io:format("~n1. Starting HyperBeam application...~n"),
    StartResult = application:ensure_all_started(hyperbeam_local),
    case StartResult of
        {ok, _Started} ->
            io:format("   ✓ HyperBeam application started successfully~n");
        {error, StartReason} ->
            io:format("   ✗ Failed to start: ~p~n", [StartReason]),
            halt(1)
    end,
    
    % Test 2: Test NIF functions directly
    io:format("~n2. Testing Rust NIF functions...~n"),
    
    % Test hello_world
    try rust_template_device:hello_world() of
        HelloResult ->
            io:format("   ✓ hello_world() = ~p~n", [HelloResult])
    catch
        HelloError ->
            io:format("   ✗ hello_world() failed: ~p~n", [HelloError])
    end,
    
    % Test add_numbers 
    try rust_template_device:add_numbers(42, 58) of
        AddResult ->
            io:format("   ✓ add_numbers(42, 58) = ~p~n", [AddResult])
    catch
        AddError ->
            io:format("   ✗ add_numbers() failed: ~p~n", [AddError])
    end,
    
    % Test echo_string
    try rust_template_device:echo_string("Test Message") of
        EchoResult ->
            io:format("   ✓ echo_string() = ~p~n", [EchoResult])
    catch
        EchoError ->
            io:format("   ✗ echo_string() failed: ~p~n", [EchoError])
    end,
    
    % Test 3: Test message routing
    io:format("~n3. Testing HyperBeam message routing...~n"),
    TestMessage = #{
        <<"target">> => <<"rust_template_device">>,
        <<"data">> => <<"NIF Integration Test">>,
        <<"action">> => <<"Echo">>
    },
    try hb_message_router:route_message(TestMessage) of
        RouteResult ->
            io:format("   ✓ Message routing successful: ~p~n", [RouteResult])
    catch
        RouteError ->
            io:format("   ✗ Message routing failed: ~p~n", [RouteError])
    end,
    
    % Test 4: Test device registry
    io:format("~n4. Testing device registry...~n"),
    try hb_device_registry:list_devices() of
        DeviceResult ->
            io:format("   ✓ Device registry: ~p~n", [DeviceResult])
    catch
        DeviceError ->
            io:format("   ✗ Device registry failed: ~p~n", [DeviceError])
    end,
    
    % Stop the application
    io:format("~n5. Stopping HyperBeam application...~n"),
    application:stop(hyperbeam_local),
    io:format("   ✓ Application stopped~n"),
    
    io:format("~n=====================================~n"),
    io:format("NIF Test Complete!~n"),
    io:format("=====================================~n").