-module(hb_device_registry).
-behaviour(gen_server).
-include("../include/hb_local.hrl").

%% API
-export([start_link/0, register_device/1, unregister_device/1, list_devices/0, 
         get_device_info/1, route_message/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
    devices = #{} :: map(),
    device_states = #{} :: map()
}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

register_device(DeviceModule) ->
    gen_server:call(?SERVER, {register_device, DeviceModule}).

unregister_device(DeviceName) ->
    gen_server:call(?SERVER, {unregister_device, DeviceName}).

list_devices() ->
    gen_server:call(?SERVER, list_devices).

get_device_info(DeviceName) ->
    gen_server:call(?SERVER, {get_device_info, DeviceName}).

route_message(Message) ->
    gen_server:call(?SERVER, {route_message, Message}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    % Auto-register built-in devices
    self() ! auto_register_devices,
    {ok, #state{}}.

handle_call({register_device, DeviceModule}, _From, State) ->
    case load_and_init_device(DeviceModule) of
        {ok, DeviceSpec, DeviceState} ->
            DeviceName = DeviceSpec#device_spec.name,
            NewDevices = maps:put(DeviceName, DeviceSpec, State#state.devices),
            NewStates = maps:put(DeviceName, DeviceState, State#state.device_states),
            
            io:format("Device registered: ~p~n", [DeviceName]),
            {reply, {ok, DeviceName}, State#state{
                devices = NewDevices,
                device_states = NewStates
            }};
        {error, Reason} ->
            io:format("Failed to register device ~p: ~p~n", [DeviceModule, Reason]),
            {reply, {error, Reason}, State}
    end;

handle_call({unregister_device, DeviceName}, _From, State) ->
    case maps:get(DeviceName, State#state.devices, undefined) of
        undefined ->
            {reply, {error, device_not_found}, State};
        _DeviceSpec ->
            NewDevices = maps:remove(DeviceName, State#state.devices),
            NewStates = maps:remove(DeviceName, State#state.device_states),
            io:format("Device unregistered: ~p~n", [DeviceName]),
            {reply, ok, State#state{
                devices = NewDevices,
                device_states = NewStates
            }}
    end;

handle_call(list_devices, _From, State) ->
    DeviceList = maps:fold(fun(Name, Spec, Acc) ->
        DeviceInfo = #{
            name => Name,
            version => Spec#device_spec.version,
            module => Spec#device_spec.module,
            routes => Spec#device_spec.routes,
            description => Spec#device_spec.description,
            has_nif => Spec#device_spec.nif_module =/= undefined
        },
        [DeviceInfo | Acc]
    end, [], State#state.devices),
    {reply, {ok, DeviceList}, State};

handle_call({get_device_info, DeviceName}, _From, State) ->
    case maps:get(DeviceName, State#state.devices, undefined) of
        undefined ->
            {reply, {error, device_not_found}, State};
        DeviceSpec ->
            DeviceInfo = #{
                name => DeviceSpec#device_spec.name,
                version => DeviceSpec#device_spec.version,
                module => DeviceSpec#device_spec.module,
                nif_module => DeviceSpec#device_spec.nif_module,
                routes => DeviceSpec#device_spec.routes,
                description => DeviceSpec#device_spec.description
            },
            {reply, {ok, DeviceInfo}, State}
    end;

handle_call({route_message, Message}, _From, State) ->
    #hb_message{target = Target} = Message,
    
    % Extract device name from target
    DeviceName = extract_device_name(Target),
    
    case {maps:get(DeviceName, State#state.devices, undefined),
          maps:get(DeviceName, State#state.device_states, undefined)} of
        {undefined, _} ->
            {reply, {error, device_not_found}, State};
        {DeviceSpec, DeviceState} ->
            Module = DeviceSpec#device_spec.module,
            try
                case Module:handle_message(Message, DeviceState) of
                    {reply, Reply, NewState} ->
                        NewStates = maps:put(DeviceName, NewState, State#state.device_states),
                        {reply, {reply, Reply}, State#state{device_states = NewStates}};
                    {noreply, NewState} ->
                        NewStates = maps:put(DeviceName, NewState, State#state.device_states),
                        {reply, {noreply, ok}, State#state{device_states = NewStates}};
                    {stop, Reason, NewState} ->
                        NewStates = maps:put(DeviceName, NewState, State#state.device_states),
                        io:format("Device ~p stopped: ~p~n", [DeviceName, Reason]),
                        {reply, {error, {device_stopped, Reason}}, State#state{device_states = NewStates}}
                end
            catch
                ErrorType:ErrorReason:Stacktrace ->
                    io:format("Device ~p crashed: ~p:~p~n~p~n", [DeviceName, ErrorType, ErrorReason, Stacktrace]),
                    {reply, {error, {device_crashed, ErrorType, ErrorReason}}, State}
            end
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(auto_register_devices, State) ->
    % Auto-register known devices
    Devices = [
        % rust_template_device  % Disabled for now
        % Add more devices here as they are created
    ],
    
    lists:foreach(fun(DeviceModule) ->
        case load_and_init_device(DeviceModule) of
            {ok, DeviceSpec, _DeviceState} ->
                DeviceName = DeviceSpec#device_spec.name,
                io:format("Auto-registered device: ~p~n", [DeviceName]);
            {error, Reason} ->
                io:format("Failed to auto-register device ~p: ~p~n", [DeviceModule, Reason])
        end
    end, Devices),
    
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

load_and_init_device(DeviceModule) ->
    try
        % Check if module is loaded
        case code:ensure_loaded(DeviceModule) of
            {module, DeviceModule} ->
                % Get device info
                DeviceInfo = DeviceModule:device_info(),
                
                % Create device spec
                DeviceSpec = #device_spec{
                    name = maps:get(name, DeviceInfo),
                    version = maps:get(version, DeviceInfo),
                    module = DeviceModule,
                    nif_module = maps:get(nif_module, DeviceInfo, undefined),
                    routes = maps:get(routes, DeviceInfo, []),
                    description = maps:get(description, DeviceInfo, <<"No description">>)
                },
                
                % Initialize device
                case DeviceModule:init([]) of
                    {ok, DeviceState} ->
                        {ok, DeviceSpec, DeviceState};
                    {error, Reason} ->
                        {error, {init_failed, Reason}}
                end;
            {error, Reason} ->
                {error, {module_load_failed, Reason}}
        end
    catch
        ErrorType:ErrorReason ->
            {error, {device_error, ErrorType, ErrorReason}}
    end.

extract_device_name(Target) when is_binary(Target) ->
    % Handle different target formats:
    % - "device:name" -> name
    % - "name" -> name
    % - "/api/device/name" -> name
    case binary:split(Target, [<<":">>, <<"/">>], [global]) of
        [<<"device">>, DeviceName] -> 
            binary_to_atom(DeviceName, utf8);
        [DeviceName] when DeviceName =/= <<"">> -> 
            binary_to_atom(DeviceName, utf8);
        Parts ->
            % Take the last non-empty part
            case lists:reverse([P || P <- Parts, P =/= <<"">>]) of
                [DeviceName | _] -> binary_to_atom(DeviceName, utf8);
                [] -> undefined
            end
    end;
extract_device_name(Target) when is_atom(Target) ->
    Target;
extract_device_name(_) ->
    undefined.