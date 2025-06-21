-module(discord_clone_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    % Initialize ETS tables here
    discord_user:ensure_table_exists(),
    discord_server:ensure_table_exists(),
    discord_channel:ensure_table_exists(),
    discord_message:ensure_table_exists(),

    io:format("User table: ~p~n", [ets:info(user_table)]),
    io:format("Server table: ~p~n", [ets:info(server_table)]),
    io:format("Channel table: ~p~n", [ets:info(channel_table)]),
    io:format("Message table: ~p~n", [ets:info(message_table)]),

    discord_clone_sup:start_link().

stop(_State) ->
    ok.
