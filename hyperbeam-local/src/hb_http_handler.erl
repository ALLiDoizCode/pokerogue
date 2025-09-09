-module(hb_http_handler).
-include("../include/hb_local.hrl").

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Action = maps:get(action, State, undefined),
    
    {ok, Body, Req1} = case Method of
        <<"GET">> -> 
            handle_get(Action, Req0, State);
        <<"POST">> -> 
            handle_post(Action, Req0, State);
        <<"PUT">> -> 
            handle_put(Action, Req0, State);
        <<"DELETE">> -> 
            handle_delete(Action, Req0, State);
        _ -> 
            {ok, jsx:encode(?ERROR_RESPONSE(<<"Method not allowed">>)), 
             cowboy_req:reply(405, #{}, <<"Method not allowed">>, Req0)}
    end,
    
    Req2 = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>,
        <<"access-control-allow-origin">> => <<"*">>,
        <<"access-control-allow-methods">> => <<"GET, POST, PUT, DELETE, OPTIONS">>,
        <<"access-control-allow-headers">> => <<"content-type">>
    }, Body, Req1),
    
    {ok, Req2, State}.

%% GET handlers
handle_get(list_devices, Req, _State) ->
    case hb_device_registry:list_devices() of
        {ok, Devices} ->
            Response = ?SUCCESS_RESPONSE(Devices),
            {ok, jsx:encode(Response), Req};
        {error, Reason} ->
            Response = ?ERROR_RESPONSE(Reason),
            {ok, jsx:encode(Response), Req}
    end;

handle_get(device_info, Req, _State) ->
    DeviceName = cowboy_req:binding(device, Req),
    case DeviceName of
        undefined ->
            Response = ?ERROR_RESPONSE(<<"Device name required">>),
            {ok, jsx:encode(Response), Req};
        _ ->
            DeviceAtom = binary_to_atom(DeviceName, utf8),
            case hb_device_registry:get_device_info(DeviceAtom) of
                {ok, DeviceInfo} ->
                    Response = ?SUCCESS_RESPONSE(DeviceInfo),
                    {ok, jsx:encode(Response), Req};
                {error, Reason} ->
                    Response = ?ERROR_RESPONSE(Reason),
                    {ok, jsx:encode(Response), Req}
            end
    end;

handle_get(list_processes, Req, _State) ->
    case hb_process_manager:list_processes() of
        {ok, Processes} ->
            Response = ?SUCCESS_RESPONSE(Processes),
            {ok, jsx:encode(Response), Req};
        {error, Reason} ->
            Response = ?ERROR_RESPONSE(Reason),
            {ok, jsx:encode(Response), Req}
    end;

handle_get(debug, Req, _State) ->
    Path = cowboy_req:path_info(Req),
    handle_debug_get(Path, Req);

handle_get(_, Req, _State) ->
    Response = ?ERROR_RESPONSE(<<"Unsupported GET action">>),
    {ok, jsx:encode(Response), Req}.

%% POST handlers
handle_post(send_message, Req, _State) ->
    {ok, RequestBody, Req1} = cowboy_req:read_body(Req),
    
    Result = try
        MessageData = jsx:decode(RequestBody),
        
        % Create HyperBeam message
        Message = #hb_message{
            id = generate_uuid(),
            data = MessageData,
            target = maps:get(<<"target">>, MessageData, <<"unknown">>),
            timestamp = os:system_time(millisecond),
            from = <<"http_client">>
        },
        
        case hb_message_router:route_message(Message) of
            {ok, Reply} ->
                {success, ?SUCCESS_RESPONSE(#{
                    <<"message_id">> => list_to_binary(Message#hb_message.id),
                    <<"reply">> => format_message_for_json(Reply)
                })};
            {error, Reason} ->
                {success, ?ERROR_RESPONSE(#{
                    <<"reason">> => format_error_for_json(Reason),
                    <<"message_id">> => list_to_binary(Message#hb_message.id)
                })}
        end
    catch
        error:{badarg, _} ->
            {success, ?ERROR_RESPONSE(<<"Invalid JSON">>)};
        ErrorType:ErrorReason ->
            {success, ?ERROR_RESPONSE(#{
                <<"error">> => atom_to_binary(ErrorType, utf8),
                <<"reason">> => format_error_for_json(ErrorReason)
            })}
    end,
    
    case Result of
        {success, Response} ->
            {ok, jsx:encode(Response), Req1}
    end;

handle_post(list_processes, Req, _State) ->
    % POST to create a new process
    {ok, RequestBody, Req1} = cowboy_req:read_body(Req),
    
    Result = try
        ProcessData = jsx:decode(RequestBody),
        Name = maps:get(<<"name">>, ProcessData, <<"unnamed_process">>),
        Code = maps:get(<<"code">>, ProcessData, <<"">>),
        
        case hb_process_manager:spawn_process(Name, Code) of
            {ok, ProcessId} ->
                {success, ?SUCCESS_RESPONSE(#{
                    <<"process_id">> => ProcessId,
                    <<"name">> => Name,
                    <<"status">> => <<"created">>
                })};
            {error, Reason} ->
                {success, ?ERROR_RESPONSE(Reason)}
        end
    catch
        error:{badarg, _} ->
            {success, ?ERROR_RESPONSE(<<"Invalid JSON">>)}
    end,
    
    case Result of
        {success, Response} ->
            {ok, jsx:encode(Response), Req1}
    end;

handle_post(send_to_process, Req, _State) ->
    ProcessId = cowboy_req:binding(process, Req),
    {ok, RequestBody, Req1} = cowboy_req:read_body(Req),
    
    Result = try
        MessageData = jsx:decode(RequestBody),
        
        case hb_process_manager:send_to_process(ProcessId, MessageData) of
            {ok, ProcessResponse} ->
                {success, ?SUCCESS_RESPONSE(#{
                    <<"process_id">> => ProcessId,
                    <<"response">> => ProcessResponse
                })};
            {error, Reason} ->
                {success, ?ERROR_RESPONSE(Reason)}
        end
    catch
        error:{badarg, _} ->
            {success, ?ERROR_RESPONSE(<<"Invalid JSON">>)}
    end,
    
    case Result of
        {success, Response} ->
            {ok, jsx:encode(Response), Req1}
    end;

handle_post(_, Req, _State) ->
    Response = ?ERROR_RESPONSE(<<"Unsupported POST action">>),
    {ok, jsx:encode(Response), Req}.

%% PUT handlers
handle_put(_, Req, _State) ->
    Response = ?ERROR_RESPONSE(<<"PUT not implemented">>),
    {ok, jsx:encode(Response), Req}.

%% DELETE handlers
handle_delete(_, Req, _State) ->
    Response = ?ERROR_RESPONSE(<<"DELETE not implemented">>),
    {ok, jsx:encode(Response), Req}.

%% Debug handlers
handle_debug_get([<<"system">>, <<"status">>], Req) ->
    SystemInfo = #{
        <<"node">> => atom_to_binary(node(), utf8),
        <<"uptime">> => element(1, statistics(wall_clock)),
        <<"memory">> => #{
            <<"total">> => erlang:memory(total),
            <<"processes">> => erlang:memory(processes),
            <<"system">> => erlang:memory(system)
        },
        <<"processes">> => erlang:system_info(process_count),
        <<"erlang_version">> => list_to_binary(erlang:system_info(otp_release))
    },
    Response = ?SUCCESS_RESPONSE(SystemInfo),
    {ok, jsx:encode(Response), Req};

handle_debug_get([<<"messages">>, <<"recent">>], Req) ->
    Limit = case cowboy_req:parse_qs(Req) of
        [{<<"limit">>, LimitBin}] ->
            try binary_to_integer(LimitBin)
            catch _:_ -> 10
            end;
        _ -> 10
    end,
    
    case hb_message_router:get_message_history(Limit) of
        {ok, History} ->
            Response = ?SUCCESS_RESPONSE(History),
            {ok, jsx:encode(Response), Req};
        {error, Reason} ->
            Response = ?ERROR_RESPONSE(Reason),
            {ok, jsx:encode(Response), Req}
    end;

handle_debug_get(Path, Req) ->
    Response = ?ERROR_RESPONSE(#{
        <<"message">> => <<"Debug endpoint not found">>,
        <<"path">> => Path
    }),
    {ok, jsx:encode(Response), Req}.

%% Helper functions
format_message_for_json(#hb_message{} = Message) ->
    #{
        <<"id">> => list_to_binary(Message#hb_message.id),
        <<"data">> => Message#hb_message.data,
        <<"target">> => Message#hb_message.target,
        <<"timestamp">> => Message#hb_message.timestamp,
        <<"from">> => Message#hb_message.from
    };
format_message_for_json(Other) ->
    Other.

format_error_for_json(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason, utf8);
format_error_for_json(Reason) when is_binary(Reason) ->
    Reason;
format_error_for_json(Reason) when is_list(Reason) ->
    try
        list_to_binary(Reason)
    catch
        _:_ -> iolist_to_binary(io_lib:format("~p", [Reason]))
    end;
format_error_for_json(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).

%% Simple UUID generation (not cryptographically secure, just for testing)
generate_uuid() ->
    Timestamp = os:system_time(microsecond),
    Random = rand:uniform(16#FFFFFFFF),
    lists:flatten(io_lib:format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~8.16.0b", 
                               [Timestamp band 16#FFFFFFFF,
                                (Timestamp bsr 32) band 16#FFFF,
                                16#4000 bor ((Random bsr 16) band 16#0FFF),
                                16#8000 bor (Random band 16#3FFF),
                                rand:uniform(16#FFFFFFFF)])).