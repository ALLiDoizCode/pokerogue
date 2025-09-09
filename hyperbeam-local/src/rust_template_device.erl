-module(rust_template_device).
-behaviour(hb_device).
-include("../include/hb_local.hrl").

-export([init/1, handle_message/2, device_info/0]).
-export([hello_world/0, add_numbers/2, echo_string/1]).

%% Device behavior callbacks
init(_Args) ->
    NifPath = filename:join([code:priv_dir(hyperbeam_local), "native", "rust_template_device"]),
    case erlang:load_nif(NifPath, 0) of
        ok -> 
            io:format("Rust Template Device initialized successfully~n"),
            {ok, #{}};
        {error, {reload, _}} ->
            io:format("Rust Template Device NIF reloaded~n"),
            {ok, #{}};
        Error -> 
            io:format("Failed to load Rust Template Device NIF: ~p~n", [Error]),
            {error, Error}
    end.

handle_message(Message, State) ->
    #hb_message{data = Data, id = MsgId, from = From} = Message,
    
    try
        Response = case Data of
            #{<<"action">> := <<"hello">>} ->
                Result = hello_world(),
                #{<<"status">> => <<"success">>, <<"result">> => list_to_binary(Result)};
            
            #{<<"action">> := <<"add">>, <<"a">> := A, <<"b">> := B} ->
                Result = add_numbers(A, B),
                #{<<"status">> => <<"success">>, <<"result">> => Result};
            
            #{<<"action">> := <<"echo">>, <<"data">> := InputData} ->
                Result = echo_string(binary_to_list(InputData)),
                #{<<"status">> => <<"success">>, <<"result">> => list_to_binary(Result)};
            
            _ ->
                #{<<"status">> => <<"error">>, 
                  <<"error">> => <<"Unknown action or invalid data format">>,
                  <<"available_actions">> => [<<"hello">>, <<"add">>, <<"echo">>]}
        end,
        
        ReplyMessage = Message#hb_message{
            data = Response,
            target = From,
            timestamp = os:system_time(millisecond)
        },
        
        {reply, ReplyMessage, State}
        
    catch
        error:Error ->
            ErrorResponse = #{
                <<"status">> => <<"error">>,
                <<"error">> => iolist_to_binary(io_lib:format("~p", [Error]))
            },
            ErrorMessage = Message#hb_message{
                data = ErrorResponse,
                target = From,
                timestamp = os:system_time(millisecond)
            },
            {reply, ErrorMessage, State}
    end.

device_info() ->
    #{
        name => rust_template_device,
        version => <<"0.1.0">>,
        description => <<"Simple Rust NIF device for HyperBeam local testing">>,
        routes => [<<"/hello">>, <<"/add">>, <<"/echo">>],
        capabilities => [basic_operations, string_processing, arithmetic],
        runtime => rust_nif
    }.

%% NIF function declarations - these will be replaced by the Rust implementations
hello_world() ->
    erlang:nif_error(nif_not_loaded).

add_numbers(_A, _B) ->
    erlang:nif_error(nif_not_loaded).

echo_string(_Input) ->
    erlang:nif_error(nif_not_loaded).