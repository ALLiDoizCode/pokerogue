%% HyperBeam Local Testing Environment Header File

%% Message record definition
-record(hb_message, {
    id :: binary(),
    data :: term(),
    target :: binary(),
    timestamp :: integer(),
    signature :: binary() | undefined,
    from :: binary() | undefined,
    tags :: map()
}).

%% Device specification record
-record(device_spec, {
    name :: atom(),
    version :: binary(),
    module :: atom(),
    nif_module :: atom() | undefined,
    routes :: [binary()],
    description :: binary()
}).

%% Process specification record
-record(process_spec, {
    id :: binary(),
    name :: binary(),
    code :: binary(),
    state :: term(),
    handlers :: [term()]
}).

%% Device behavior callback definitions
-callback init(Args :: term()) -> 
    {ok, State :: term()} | {error, Reason :: term()}.

-callback handle_message(Message :: #hb_message{}, State :: term()) ->
    {reply, Reply :: #hb_message{}, NewState :: term()} |
    {noreply, NewState :: term()} |
    {stop, Reason :: term(), NewState :: term()}.

-callback device_info() -> map().

%% API Response formats
-define(SUCCESS_RESPONSE(Data), #{status => success, data => Data}).
-define(ERROR_RESPONSE(Error), #{status => error, error => Error}).

%% Default ports and configuration
-define(DEFAULT_HTTP_PORT, 8080).
-define(DEFAULT_WEBSOCKET_PORT, 8081).
-define(MAX_MESSAGE_SIZE, 1048576). % 1MB
-define(MESSAGE_TTL, 300000). % 5 minutes in milliseconds