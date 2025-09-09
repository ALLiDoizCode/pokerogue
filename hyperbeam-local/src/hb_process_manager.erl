-module(hb_process_manager).
-behaviour(gen_server).
-include("../include/hb_local.hrl").

%% API
-export([start_link/0, spawn_process/2, send_to_process/2, get_process_state/1, 
         list_processes/0, terminate_process/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
    processes = #{} :: map(),
    aolite_port :: port() | undefined
}).

-record(ao_process, {
    id :: binary(),
    name :: binary(),
    code :: binary(),
    state :: term(),
    created_at :: integer(),
    last_message_at :: integer(),
    message_count = 0 :: integer()
}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

spawn_process(Name, LuaCode) ->
    gen_server:call(?SERVER, {spawn_process, Name, LuaCode}).

send_to_process(ProcessId, Message) ->
    gen_server:call(?SERVER, {send_to_process, ProcessId, Message}).

get_process_state(ProcessId) ->
    gen_server:call(?SERVER, {get_process_state, ProcessId}).

list_processes() ->
    gen_server:call(?SERVER, list_processes).

terminate_process(ProcessId) ->
    gen_server:call(?SERVER, {terminate_process, ProcessId}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    % Initialize aolite for Lua process management
    case init_aolite() of
        {ok, Port} ->
            {ok, #state{aolite_port = Port}};
        {error, Reason} ->
            io:format("Failed to initialize aolite: ~p~n", [Reason]),
            {ok, #state{}}
    end.

handle_call({spawn_process, Name, LuaCode}, _From, State) ->
    ProcessId = generate_uuid(),
    ProcessIdBin = list_to_binary(ProcessId),
    
    Process = #ao_process{
        id = ProcessIdBin,
        name = Name,
        code = LuaCode,
        state = #{},
        created_at = os:system_time(millisecond),
        last_message_at = os:system_time(millisecond)
    },
    
    % Execute process initialization in aolite if available
    case State#state.aolite_port of
        undefined ->
            % Fallback to simple state management
            NewProcesses = maps:put(ProcessIdBin, Process, State#state.processes),
            {reply, {ok, ProcessIdBin}, State#state{processes = NewProcesses}};
        Port ->
            % Use aolite for process management
            case init_lua_process(Port, ProcessId, LuaCode) of
                ok ->
                    NewProcesses = maps:put(ProcessIdBin, Process, State#state.processes),
                    {reply, {ok, ProcessIdBin}, State#state{processes = NewProcesses}};
                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end
    end;

handle_call({send_to_process, ProcessId, Message}, _From, State) ->
    case maps:get(ProcessId, State#state.processes, undefined) of
        undefined ->
            {reply, {error, process_not_found}, State};
        Process ->
            % Create AO-style message
            AOMessage = create_ao_message(Message, ProcessId),
            
            % Send message to process
            case State#state.aolite_port of
                undefined ->
                    % Simple echo response for testing
                    Response = handle_message_simple(AOMessage, Process),
                    {reply, {ok, Response}, State};
                Port ->
                    case send_lua_message(Port, ProcessId, AOMessage) of
                        {ok, Response} ->
                            % Update process statistics
                            UpdatedProcess = Process#ao_process{
                                last_message_at = os:system_time(millisecond),
                                message_count = Process#ao_process.message_count + 1
                            },
                            NewProcesses = maps:put(ProcessId, UpdatedProcess, State#state.processes),
                            {reply, {ok, Response}, State#state{processes = NewProcesses}};
                        {error, Reason} ->
                            {reply, {error, Reason}, State}
                    end
            end
    end;

handle_call({get_process_state, ProcessId}, _From, State) ->
    case maps:get(ProcessId, State#state.processes, undefined) of
        undefined ->
            {reply, {error, process_not_found}, State};
        Process ->
            ProcessInfo = #{
                id => Process#ao_process.id,
                name => Process#ao_process.name,
                created_at => Process#ao_process.created_at,
                last_message_at => Process#ao_process.last_message_at,
                message_count => Process#ao_process.message_count,
                status => running
            },
            {reply, {ok, ProcessInfo}, State}
    end;

handle_call(list_processes, _From, State) ->
    ProcessList = maps:fold(fun(Id, Process, Acc) ->
        ProcessInfo = #{
            id => Id,
            name => Process#ao_process.name,
            created_at => Process#ao_process.created_at,
            message_count => Process#ao_process.message_count,
            status => running
        },
        [ProcessInfo | Acc]
    end, [], State#state.processes),
    {reply, {ok, ProcessList}, State};

handle_call({terminate_process, ProcessId}, _From, State) ->
    case maps:get(ProcessId, State#state.processes, undefined) of
        undefined ->
            {reply, {error, process_not_found}, State};
        _Process ->
            NewProcesses = maps:remove(ProcessId, State#state.processes),
            {reply, ok, State#state{processes = NewProcesses}}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    case State#state.aolite_port of
        undefined -> ok;
        Port -> port_close(Port)
    end.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

init_aolite() ->
    % Try to initialize aolite port for Lua process management
    % This is a placeholder - actual implementation would depend on aolite integration
    try
        % Command = "lua -e \"require('aolite').start_server()\"",
        % Port = open_port({spawn, Command}, [binary, {packet, 4}]),
        % {ok, Port}
        {error, not_implemented}
    catch
        _:_ -> {error, aolite_not_available}
    end.

init_lua_process(_Port, _ProcessId, _LuaCode) ->
    % Initialize a Lua process with aolite
    % This would send the Lua code to aolite for execution
    ok.

send_lua_message(_Port, _ProcessId, _Message) ->
    % Send message to Lua process via aolite
    % This is a placeholder for aolite integration
    {ok, #{<<"status">> => <<"success">>, <<"data">> => <<"Mock response">>}}.

create_ao_message(Message, ProcessId) ->
    MessageId = generate_uuid(),
    #{
        <<"Id">> => list_to_binary(MessageId),
        <<"Target">> => ProcessId,
        <<"From">> => <<"hyperbeam-local">>,
        <<"Data">> => case Message of
            #{<<"data">> := Data} -> Data;
            Data -> Data
        end,
        <<"Action">> => case Message of
            #{<<"action">> := Action} -> Action;
            _ -> <<"Message">>
        end,
        <<"Tags">> => case Message of
            #{<<"tags">> := Tags} -> Tags;
            _ -> #{}
        end,
        <<"Timestamp">> => os:system_time(millisecond)
    }.

handle_message_simple(AOMessage, _Process) ->
    % Simple message handler for when aolite is not available
    Action = maps:get(<<"Action">>, AOMessage, <<"Unknown">>),
    Data = maps:get(<<"Data">>, AOMessage, <<"">>),
    
    Response = case Action of
        <<"Echo">> ->
            #{
                <<"status">> => <<"success">>,
                <<"action">> => <<"EchoResponse">>,
                <<"data">> => iolist_to_binary([<<"Echo: ">>, Data])
            };
        <<"Ping">> ->
            #{
                <<"status">> => <<"success">>,
                <<"action">> => <<"Pong">>,
                <<"data">> => <<"Pong!">>
            };
        _ ->
            #{
                <<"status">> => <<"success">>,
                <<"action">> => <<"GenericResponse">>,
                <<"data">> => iolist_to_binary([<<"Received ">>, Action, <<" with data: ">>, Data])
            }
    end,
    
    Response.

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