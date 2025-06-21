-module(discord_channel_tests).
-include_lib("eunit/include/eunit.hrl").

% Setup similar to other tests
ensure_ets_setup() ->
    application:ensure_all_started(discord_clone).

ensure_ets_cleanup() ->
    application:stop(discord_clone).

channel_test_() ->
    {setup,
        fun ensure_ets_setup/0,
        fun ensure_ets_cleanup/0,
        [
            fun create_and_get_channel/0,
            fun create_channel_user_not_member/0,
            fun add_and_get_messages_in_channel/0
            % Add more: get non-existent channel, etc.
        ]
    }.

create_and_get_channel() ->
    {ok, Creator} = discord_user:create_user("channel_creator_user"),
    {ok, Server} = discord_server:create_server(Creator#user.id, "Server for Channels Test"),
    ChannelName = "General Discussion",

    {ok, Channel} = discord_channel:create_channel(Server#server.id, Creator#user.id, ChannelName),
    ?assertEqual(ChannelName, Channel#channel.name),
    ?assertEqual(Server#server.id, Channel#channel.server_id),

    {ok, FetchedChannel} = discord_channel:get_channel(Channel#channel.id),
    ?assertEqual(Channel, FetchedChannel),

    % Verify channel was added to server
    {ok, ServerAfterChannelCreation} = discord_server:get_server(Server#server.id),
    ?assert(lists:member(Channel#channel.id, ServerAfterChannelCreation#server.channels)).

create_channel_user_not_member() ->
    {ok, UserNotMember} = discord_user:create_user("not_a_server_member"),
    {ok, ServerOwner} = discord_user:create_user("server_owner_for_channel_test"),
    {ok, Server} = discord_server:create_server(ServerOwner#user.id, "Server Strict Access"),
    ChannelName = "Secret Channel",

    ?assertEqual({error, user_not_member_of_server},
                 discord_channel:create_channel(Server#server.id, UserNotMember#user.id, ChannelName)).

add_and_get_messages_in_channel() ->
    {ok, ChanCreator} = discord_user:create_user("channel_msg_user"),
    {ok, Serv} = discord_server:create_server(ChanCreator#user.id, "Msg Test Server"),
    {ok, Chan} = discord_channel:create_channel(Serv#server.id, ChanCreator#user.id, "Msg Channel"),

    % In our current implementation, channel stores message IDs.
    % We'll mock message IDs for this test.
    MsgID1 = erlang:make_ref(),
    MsgID2 = erlang:make_ref(),

    {ok, UpdatedChan1} = discord_channel:add_message_to_channel(Chan#channel.id, MsgID1),
    ?assertEqual([MsgID1], UpdatedChan1#channel.messages),

    {ok, UpdatedChan2} = discord_channel:add_message_to_channel(Chan#channel.id, MsgID2),
    ?assertEqual([MsgID2, MsgID1], UpdatedChan2#channel.messages), % Prepends

    {ok, Messages} = discord_channel:get_messages(Chan#channel.id),
    ?assertEqual([MsgID2, MsgID1], Messages),

    % Get messages from non-existent channel
    ?assertEqual({error, channel_not_found, []}, discord_channel:get_messages(erlang:make_ref())).
