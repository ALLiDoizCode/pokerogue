-module(hb_message_router).
-behaviour(gen_server).
-include("../include/hb_local.hrl").

%% API
-export([start_link/0, route_message/1, register_route/2, unregister_route/1, 
         list_routes/0, get_message_history/1]).

%% gen_server callbacks  
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
    routes = #{} :: map(),
    message_history = [] :: list(),
    max_history = 1000 :: integer()
}).

-record(route, {
    pattern :: binary(),
    target :: atom(),
    handler :: atom()
}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

route_message(Message) ->
    gen_server:call(?SERVER, {route_message, Message}).

register_route(Pattern, Target) ->
    gen_server:call(?SERVER, {register_route, Pattern, Target}).

unregister_route(Pattern) ->
    gen_server:call(?SERVER, {unregister_route, Pattern}).

list_routes() ->
    gen_server:call(?SERVER, list_routes).

get_message_history(Limit) ->
    gen_server:call(?SERVER, {get_message_history, Limit}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    % Register default routes
    DefaultRoutes = #{
        <<"device:">> => device_registry,
        <<"process:">> => process_manager,
        <<"system:">> => system_handler
    },
    {ok, #state{routes = DefaultRoutes}}.

handle_call({route_message, Message}, _From, State) ->
    % Convert map to hb_message record if needed
    HBMessage = case Message of
        #{<<"target">> := TargetBin} ->
            % Convert map to record
            MessageId = list_to_binary(maps:get(<<"id">>, Message, generate_uuid())),
            #hb_message{
                id = MessageId,
                target = TargetBin,
                from = maps:get(<<"from">>, Message, <<"anonymous">>),
                data = maps:get(<<"data">>, Message, <<>>),
                timestamp = maps:get(<<"timestamp">>, Message, os:system_time(millisecond))
            };
        #hb_message{} ->
            Message
    end,
    
    Target = HBMessage#hb_message.target,
    
    % Log message
    LogEntry = #{
        timestamp => os:system_time(millisecond),
        message_id => HBMessage#hb_message.id,
        target => Target,
        action => extract_action(HBMessage#hb_message.data)
    },
    
    NewHistory = add_to_history(LogEntry, State#state.message_history, State#state.max_history),
    
    % Route message
    case find_route(Target, State#state.routes) of
        {ok, Handler} ->
            case route_to_handler(Handler, HBMessage) of
                {reply, Reply} ->
                    {reply, {ok, Reply}, State#state{message_history = NewHistory}};
                {error, Reason} ->
                    {reply, {error, Reason}, State#state{message_history = NewHistory}}
            end;
        {error, no_route} ->
            {reply, {error, no_route_found}, State#state{message_history = NewHistory}}
    end;

handle_call({register_route, Pattern, Target}, _From, State) ->
    NewRoutes = maps:put(Pattern, Target, State#state.routes),
    {reply, ok, State#state{routes = NewRoutes}};

handle_call({unregister_route, Pattern}, _From, State) ->
    NewRoutes = maps:remove(Pattern, State#state.routes),
    {reply, ok, State#state{routes = NewRoutes}};

handle_call(list_routes, _From, State) ->
    Routes = maps:to_list(State#state.routes),
    {reply, {ok, Routes}, State};

handle_call({get_message_history, Limit}, _From, State) ->
    History = lists:sublist(State#state.message_history, Limit),
    {reply, {ok, History}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

find_route(Target, Routes) ->
    % Try exact match first
    case maps:get(Target, Routes, undefined) of
        undefined ->
            % Try prefix matching
            find_prefix_match(Target, maps:to_list(Routes));
        Handler ->
            {ok, Handler}
    end.

find_prefix_match(_Target, []) ->
    {error, no_route};
find_prefix_match(Target, [{Pattern, Handler} | Rest]) ->
    case binary:match(Target, Pattern) of
        {0, _} -> {ok, Handler};  % Prefix match
        _ -> find_prefix_match(Target, Rest)
    end.

route_to_handler(device_registry, Message) ->
    % Route to device registry
    case hb_device_registry:route_message(Message) of
        {reply, Reply} -> {reply, Reply};
        {error, Reason} -> {error, Reason}
    end;
route_to_handler(process_manager, Message) ->
    % Route to process manager
    ProcessId = Message#hb_message.target,
    case hb_process_manager:send_to_process(ProcessId, Message#hb_message.data) of
        {ok, Response} -> 
            ReplyMessage = Message#hb_message{data = Response, target = Message#hb_message.from},
            {reply, ReplyMessage};
        {error, Reason} -> {error, Reason}
    end;
route_to_handler(system_handler, Message) ->
    % Handle system messages
    handle_system_message(Message);
route_to_handler(Handler, Message) ->
    % Try to call handler module
    try
        case Handler:handle_message(Message) of
            {reply, Reply} -> {reply, Reply};
            {error, Reason} -> {error, Reason}
        end
    catch
        error:undef ->
            {error, handler_not_found};
        ErrorType:ErrorReason ->
            {error, {handler_error, ErrorType, ErrorReason}}
    end.

handle_system_message(Message) ->
    #hb_message{data = Data} = Message,
    
    case Data of
        #{<<"action">> := <<"ping">>} ->
            Response = #{
                <<"status">> => <<"success">>,
                <<"action">> => <<"pong">>,
                <<"timestamp">> => os:system_time(millisecond),
                <<"node">> => atom_to_binary(node(), utf8)
            },
            ReplyMessage = Message#hb_message{data = Response},
            {reply, ReplyMessage};
        
        #{<<"action">> := <<"status">>} ->
            Response = #{
                <<"status">> => <<"success">>,
                <<"system_info">> => #{
                    <<"node">> => atom_to_binary(node(), utf8),
                    <<"uptime">> => element(1, statistics(wall_clock)),
                    <<"memory">> => erlang:memory(total),
                    <<"processes">> => erlang:system_info(process_count)
                }
            },
            ReplyMessage = Message#hb_message{data = Response},
            {reply, ReplyMessage};
        
        _ ->
            {error, unknown_system_action}
    end.

extract_action(Data) when is_map(Data) ->
    maps:get(<<"action">>, Data, <<"unknown">>);
extract_action(_) ->
    <<"unknown">>.

add_to_history(Entry, History, MaxSize) ->
    NewHistory = [Entry | History],
    case length(NewHistory) > MaxSize of
        true -> lists:sublist(NewHistory, MaxSize);
        false -> NewHistory
    end.

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