-module(hb_local_sup).
-behaviour(supervisor).
-include("../include/hb_local.hrl").

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 60
    },
    
    ChildSpecs = [
        % Device registry - manages registered devices
        #{
            id => hb_device_registry,
            start => {hb_device_registry, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hb_device_registry]
        },
        
        % Message router - routes messages between devices
        #{
            id => hb_message_router,
            start => {hb_message_router, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hb_message_router]
        },
        
        % Process manager - manages AO processes
        #{
            id => hb_process_manager,
            start => {hb_process_manager, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hb_process_manager]
        }
    ],
    
    {ok, {SupFlags, ChildSpecs}}.