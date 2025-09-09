#!/usr/bin/env escript

main(_) ->
    % Add the ebin paths
    code:add_path("hyperbeam-local/_build/default/lib/hyperbeam_local/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/cowboy/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/cowlib/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/ranch/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/jsx/ebin"),
    
    io:format("Testing HyperBeam NIF Integration...~n"),
    io:format("===================================~n"),
    
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
    
    % Wait a moment for initialization
    timer:sleep(1000),
    
    % Test 2: Check if devices are registered
    io:format("~n2. Checking device registration...~n"),
    try hb_device_registry:list_devices() of
        {ok, Devices} ->
            io:format("   ✓ Device registry returned: ~p~n", [Devices]);
        {error, DeviceReason} ->
            io:format("   ✗ Device registry failed: ~p~n", [DeviceReason])
    catch
        DeviceClass:DeviceError ->
            io:format("   ✗ Device registry error ~p:~p~n", [DeviceClass, DeviceError])
    end,
    
    % Test 3: Initialize the device manually to load NIF
    io:format("~n3. Manually initializing Rust device...~n"),
    try rust_template_device:init([]) of
        {ok, _State} ->
            io:format("   ✓ Rust device initialized successfully~n"),
            
            % Test 4: Now test the NIF functions
            io:format("~n4. Testing NIF functions after initialization...~n"),
            
            % Test hello_world
            try rust_template_device:hello_world() of
                HelloResult ->
                    io:format("   ✓ hello_world() = ~p~n", [HelloResult])
            catch
                HelloClass:HelloError ->
                    io:format("   ✗ hello_world() failed: ~p:~p~n", [HelloClass, HelloError])
            end,
            
            % Test add_numbers 
            try rust_template_device:add_numbers(42, 58) of
                AddResult ->
                    io:format("   ✓ add_numbers(42, 58) = ~p~n", [AddResult])
            catch
                AddClass:AddError ->
                    io:format("   ✗ add_numbers() failed: ~p:~p~n", [AddClass, AddError])
            end,
            
            % Test echo_string
            try rust_template_device:echo_string("Hello from Rust!") of
                EchoResult ->
                    io:format("   ✓ echo_string() = ~p~n", [EchoResult])
            catch
                EchoClass:EchoError ->
                    io:format("   ✗ echo_string() failed: ~p:~p~n", [EchoClass, EchoError])
            end;
            
        {error, InitReason} ->
            io:format("   ✗ Device initialization failed: ~p~n", [InitReason])
    catch
        InitClass:InitError ->
            io:format("   ✗ Device initialization error ~p:~p~n", [InitClass, InitError])
    end,
    
    % Test 5: Test message routing through the device
    io:format("~n5. Testing HyperBeam message routing...~n"),
    TestMessage = #{
        <<"target">> => <<"rust_template_device">>,
        <<"data">> => <<"Integration Test Message">>,
        <<"action">> => <<"Echo">>
    },
    try hb_message_router:route_message(TestMessage) of
        RouteResult ->
            io:format("   ✓ Message routing: ~p~n", [RouteResult])
    catch
        RouteClass:RouteError ->
            io:format("   ✗ Message routing failed: ~p:~p~n", [RouteClass, RouteError])
    end,
    
    % Stop the application
    io:format("~n6. Stopping HyperBeam application...~n"),
    application:stop(hyperbeam_local),
    io:format("   ✓ Application stopped~n"),
    
    io:format("~n===================================~n"),
    io:format("NIF Integration Test Complete!~n"),
    io:format("===================================~n").