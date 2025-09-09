-module(hb_local_app).
-behaviour(application).
-include("../include/hb_local.hrl").

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    % Start HTTP server for API
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/api/message", hb_http_handler, #{action => send_message}},
            {"/api/devices", hb_http_handler, #{action => list_devices}},
            {"/api/devices/:device", hb_http_handler, #{action => device_info}},
            {"/api/processes", hb_http_handler, #{action => list_processes}},
            {"/api/processes/:process/messages", hb_http_handler, #{action => send_to_process}},
            {"/api/debug/[...]", hb_http_handler, #{action => debug}},
            {"/", cowboy_static, {priv_file, hyperbeam_local, "static/index.html"}},
            {"/static/[...]", cowboy_static, {priv_dir, hyperbeam_local, "static"}}
        ]}
    ]),
    
    HttpPort = application:get_env(hyperbeam_local, http_port, ?DEFAULT_HTTP_PORT),
    {ok, _} = cowboy:start_clear(
        hb_http_listener,
        [{port, HttpPort}],
        #{env => #{dispatch => Dispatch}}
    ),
    
    io:format("HyperBeam Local Testing Environment started on port ~p~n", [HttpPort]),
    
    % Start supervisor tree
    hb_local_sup:start_link().

stop(_State) ->
    cowboy:stop_listener(hb_http_listener),
    ok.