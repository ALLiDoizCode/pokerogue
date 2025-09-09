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
    case application:ensure_all_started(hyperbeam_local) of
        {ok, _Started} ->
            io:format("   ✓ HyperBeam application started successfully~n");
        {error, Reason} ->
            io:format("   ✗ Failed to start: ~p~n", [Reason]),
            halt(1)
    end,
    
    % Test 2: Load the Rust NIF device
    io:format("~n2. Testing Rust NIF device loading...~n"),
    try
        % Test if the NIF module loads
        case rust_template_device:hello_world() of
            {ok, Result} ->
                io:format("   ✓ hello_world() = ~p~n", [Result]);
            Error ->
                io:format("   ✗ hello_world() failed: ~p~n", [Error])
        end
    catch
        error:undef ->
            io:format("   ✗ NIF module not loaded or function undefined~n");
        Class:Error ->
            io:format("   ✗ NIF error ~p:~p~n", [Class, Error])
    end,
    
    % Test 3: Test NIF arithmetic function
    io:format("~n3. Testing NIF arithmetic...~n"),
    try
        case rust_template_device:add_numbers(42, 58) of
            {ok, Sum} ->
                io:format("   ✓ add_numbers(42, 58) = ~p~n", [Sum]);
            Error ->
                io:format("   ✗ add_numbers() failed: ~p~n", [Error])
        end
    catch
        error:undef ->
            io:format("   ✗ add_numbers function not available~n");
        Class:Error ->
            io:format("   ✗ add_numbers error ~p:~p~n", [Class, Error])
    end,
    
    % Test 4: Test NIF string function
    io:format("~n4. Testing NIF string handling...~n"),
    try
        TestString = "HyperBeam Rust NIF Test",
        case rust_template_device:echo_string(TestString) of
            {ok, Echo} ->
                io:format("   ✓ echo_string(\"~s\") = ~p~n", [TestString, Echo]);
            Error ->
                io:format("   ✗ echo_string() failed: ~p~n", [Error])
        end
    catch
        error:undef ->
            io:format("   ✗ echo_string function not available~n");
        Class:Error ->
            io:format("   ✗ echo_string error ~p:~p~n", [Class, Error])
    end,
    
    % Test 5: Test message routing through the device
    io:format("~n5. Testing HyperBeam message routing...~n"),
    try
        TestMessage = #{
            <<"target">> => <<"rust_template_device">>,
            <<"data">> => <<"NIF Integration Test">>,
            <<"action">> => <<"Echo">>
        },
        case hb_message_router:route_message(TestMessage) of
            {ok, Response} ->
                io:format("   ✓ Message routing successful: ~p~n", [Response]);
            {error, Reason} ->
                io:format("   ✗ Message routing failed: ~p~n", [Reason])
        end
    catch
        Class:Error ->
            io:format("   ✗ Message routing error ~p:~p~n", [Class, Error])
    end,
    
    % Test 6: Test device registry
    io:format("~n6. Testing device registry...~n"),
    try
        case hb_device_registry:list_devices() of
            {ok, Devices} ->
                io:format("   ✓ Registered devices: ~p~n", [Devices]);
            {error, Reason} ->
                io:format("   ✗ Device registry failed: ~p~n", [Reason])
        end
    catch
        Class:Error ->
            io:format("   ✗ Device registry error ~p:~p~n", [Class, Error])
    end,
    
    % Wait a bit to see any async messages
    timer:sleep(1000),
    
    % Stop the application
    io:format("~n7. Stopping HyperBeam application...~n"),
    application:stop(hyperbeam_local),
    io:format("   ✓ Application stopped~n"),
    
    io:format("~n=====================================~n"),
    io:format("NIF Functionality Test Complete!~n"),
    io:format("=====================================~n").