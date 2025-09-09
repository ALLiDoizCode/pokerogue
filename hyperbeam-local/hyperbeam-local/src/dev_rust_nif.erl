-module(dev_rust_nif).
-export([hello_world/3, add_numbers/3, echo_string/3, hash_string/3, fibonacci/3, is_prime/3]).
-export([advanced_calculate/3, batch_operations/3]).
-export([hello_world/0, add_numbers/2, echo_string/1, hash_string/1, fibonacci/1, is_prime/1]).
-export([advanced_calculate/1, batch_operations/1]).

%% Device functions that will be exposed to Lua as ao.* globals

%% Lua-callable functions (Args, State, NodeMsg)
hello_world(Args, State, _NodeMsg) ->
    try
        Result = hello_world(),
        {[Result], State}
    catch
        Class:Error:Stack ->
            io:format("Error in hello_world: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[<<"Error in hello_world">>], State}
    end.

add_numbers(Args, State, _NodeMsg) ->
    try
        [A, B] = Args,
        Result = add_numbers(trunc(A), trunc(B)),
        {[Result], State}
    catch
        Class:Error:Stack ->
            io:format("Error in add_numbers: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[0], State}
    end.

echo_string(Args, State, _NodeMsg) ->
    try
        [Input] = Args,
        InputStr = binary_to_list(Input),
        Result = echo_string(InputStr),
        {[list_to_binary(Result)], State}
    catch
        Class:Error:Stack ->
            io:format("Error in echo_string: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[<<"Error">>], State}
    end.

hash_string(Args, State, _NodeMsg) ->
    try
        [Input] = Args,
        InputStr = binary_to_list(Input),
        Result = hash_string(InputStr),
        {[list_to_binary(Result)], State}
    catch
        Class:Error:Stack ->
            io:format("Error in hash_string: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[<<"Error">>], State}
    end.

fibonacci(Args, State, _NodeMsg) ->
    try
        [N] = Args,
        Result = fibonacci(trunc(N)),
        {[Result], State}
    catch
        Class:Error:Stack ->
            io:format("Error in fibonacci: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[0], State}
    end.

is_prime(Args, State, _NodeMsg) ->
    try
        [N] = Args,
        Result = is_prime(trunc(N)),
        {[Result], State}
    catch
        Class:Error:Stack ->
            io:format("Error in is_prime: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[false], State}
    end.

advanced_calculate(Args, State, _NodeMsg) ->
    try
        [JsonInput] = Args,
        Result = advanced_calculate(binary_to_list(JsonInput)),
        {[list_to_binary(Result)], State}
    catch
        Class:Error:Stack ->
            io:format("Error in advanced_calculate: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[<<"{\"error\":\"calculation failed\"}">>], State}
    end.

batch_operations(Args, State, _NodeMsg) ->
    try
        [JsonInput] = Args,
        Result = batch_operations(binary_to_list(JsonInput)),
        {[list_to_binary(Result)], State}
    catch
        Class:Error:Stack ->
            io:format("Error in batch_operations: ~p:~p~n~p~n", [Class, Error, Stack]),
            {[<<"{\"error\":\"batch failed\"}">>], State}
    end.

%% NIF function declarations - these will be replaced by the Rust implementations
hello_world() ->
    case load_nif() of
        ok -> hello_world_nif();
        _Error -> "Hello from fallback!"
    end.

add_numbers(A, B) ->
    case load_nif() of
        ok -> add_numbers_nif(A, B);
        _Error -> A + B
    end.

echo_string(Input) ->
    case load_nif() of
        ok -> echo_string_nif(Input);
        _Error -> "Echo: " ++ Input
    end.

hash_string(Input) ->
    case load_nif() of
        ok -> hash_string_nif(Input);
        _Error -> "0x" ++ integer_to_list(erlang:phash2(Input), 16)
    end.

fibonacci(N) ->
    case load_nif() of
        ok -> fibonacci_nif(N);
        _Error -> fibonacci_fallback(N)
    end.

is_prime(N) ->
    case load_nif() of
        ok -> is_prime_nif(N);
        _Error -> is_prime_fallback(N)
    end.

advanced_calculate(JsonInput) ->
    case load_nif() of
        ok -> advanced_calculate_nif(JsonInput);
        _Error -> "{\"error\":\"NIF not loaded\"}"
    end.

batch_operations(JsonInput) ->
    case load_nif() of
        ok -> batch_operations_nif(JsonInput);
        _Error -> "{\"error\":\"NIF not loaded\"}"
    end.

%% NIF loading
load_nif() ->
    case get(nif_loaded) of
        true -> ok;
        _ -> 
            NifPath = filename:join([code:priv_dir(hyperbeam_local), "native", "dev_rust_nif"]),
            case erlang:load_nif(NifPath, 0) of
                ok -> 
                    put(nif_loaded, true),
                    ok;
                {error, {reload, _}} ->
                    put(nif_loaded, true),
                    ok;
                Error -> 
                    Error
            end
    end.

%% Actual NIF functions (will be replaced by Rust)
hello_world_nif() -> erlang:nif_error(nif_not_loaded).
add_numbers_nif(_A, _B) -> erlang:nif_error(nif_not_loaded).
echo_string_nif(_Input) -> erlang:nif_error(nif_not_loaded).
hash_string_nif(_Input) -> erlang:nif_error(nif_not_loaded).
fibonacci_nif(_N) -> erlang:nif_error(nif_not_loaded).
is_prime_nif(_N) -> erlang:nif_error(nif_not_loaded).
advanced_calculate_nif(_JsonInput) -> erlang:nif_error(nif_not_loaded).
batch_operations_nif(_JsonInput) -> erlang:nif_error(nif_not_loaded).

%% Fallback implementations
fibonacci_fallback(0) -> 0;
fibonacci_fallback(1) -> 1;
fibonacci_fallback(N) when N > 1 ->
    fibonacci_fallback(N-1) + fibonacci_fallback(N-2).

is_prime_fallback(N) when N < 2 -> false;
is_prime_fallback(2) -> true;
is_prime_fallback(N) when N rem 2 =:= 0 -> false;
is_prime_fallback(N) ->
    is_prime_check(N, 3, trunc(math:sqrt(N))).

is_prime_check(_N, I, Limit) when I > Limit -> true;
is_prime_check(N, I, Limit) when N rem I =:= 0 -> false;
is_prime_check(N, I, Limit) -> is_prime_check(N, I + 2, Limit).