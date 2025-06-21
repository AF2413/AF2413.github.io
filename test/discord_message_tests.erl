-module(discord_message_tests).
-include_lib("eunit/include/eunit.hrl").

% Setup similar to other tests
ensure_ets_setup() ->
    application:ensure_all_started(discord_clone).

ensure_ets_cleanup() ->
    application:stop(discord_clone).

message_test_() ->
    {setup,
        fun ensure_ets_setup/0,
        fun ensure_ets_cleanup/0,
        [
            fun send_and_get_message/0,
            fun send_message_user_not_in_server/0,
            fun send_message_channel_not_found/0
        ]
    }.

send_and_get_message() ->
    {ok, Author} = discord_user:create_user("msg_author"),
    {ok, Server} = discord_server:create_server(Author#user.id, "Message Test Server"),
    {ok, Channel} = discord_channel:create_channel(Server#server.id, Author#user.id, "Message Test Channel"),
    Content = "Hello, Erlang Discord!",

    {ok, Message} = discord_message:send_message(Channel#channel.id, Author#user.id, Content),
    ?assertEqual(Content, Message#message.content),
    ?assertEqual(Author#user.id, Message#message.author_id),
    ?assertEqual(Channel#channel.id, Message#message.channel_id),
    ?assert(is_integer(Message#message.timestamp)),

    {ok, FetchedMessage} = discord_message:get_message(Message#message.id),
    ?assertEqual(Message, FetchedMessage),

    % Verify message ID was added to channel
    {ok, ChannelAfterMessage} = discord_channel:get_channel(Channel#channel.id),
    ?assert(lists:member(Message#message.id, ChannelAfterMessage#channel.messages)).

send_message_user_not_in_server() ->
    {ok, ServerOwner} = discord_user:create_user("msg_server_owner"),
    {ok, Server} = discord_server:create_server(ServerOwner#user.id, "Strict Message Server"),
    {ok, Channel} = discord_channel:create_channel(Server#server.id, ServerOwner#user.id, "Strict Channel"),

    {ok, Outsider} = discord_user:create_user("outsider_user"),
    Content = "Trying to send a message as an outsider.",

    ?assertEqual({error, user_not_member_of_server},
                 discord_message:send_message(Channel#channel.id, Outsider#user.id, Content)).

send_message_channel_not_found() ->
    {ok, Author} = discord_user:create_user("another_msg_author"),
    NonExistentChannelID = erlang:make_ref(),
    Content = "Sending to a void.",

    ?assertEqual({error, channel_not_found},
                 discord_message:send_message(NonExistentChannelID, Author#user.id, Content)).
