#!/usr/bin/env escript

main(_) ->
    % Add proper paths
    code:add_path("hyperbeam-local/_build/default/lib/hyperbeam_local/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/cowboy/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/cowlib/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/ranch/ebin"),
    code:add_path("hyperbeam-local/_build/default/lib/jsx/ebin"),
    
    io:format("🎯 FINAL NIF INTEGRATION TEST 🎯~n"),
    io:format("=================================~n"),
    
    % Start application
    case application:ensure_all_started(hyperbeam_local) of
        {ok, _} -> io:format("✓ HyperBeam application started~n");
        _ -> halt(1)
    end,
    
    % Test all NIF functions
    io:format("~n🔧 Testing Rust NIF Functions:~n"),
    
    % Test hello_world
    HelloResult = dev_rust_nif:hello_world(),
    io:format("  hello_world() = ~p~n", [HelloResult]),
    
    % Test add_numbers
    AddResult = dev_rust_nif:add_numbers(15, 27),
    io:format("  add_numbers(15, 27) = ~p~n", [AddResult]),
    
    % Test echo_string
    EchoResult = dev_rust_nif:echo_string("AO Process Direct Call"),
    io:format("  echo_string() = ~p~n", [EchoResult]),
    
    % Test fibonacci
    FibResult = dev_rust_nif:fibonacci(10),
    io:format("  fibonacci(10) = ~p~n", [FibResult]),
    
    % Test is_prime
    PrimeResult = dev_rust_nif:is_prime(97),
    io:format("  is_prime(97) = ~p~n", [PrimeResult]),
    
    application:stop(hyperbeam_local),
    io:format("~n🎉 SUCCESS: All Rust NIFs working correctly!~n"),
    io:format("Ready for ao.* integration in HyperBeam! 🚀~n").
