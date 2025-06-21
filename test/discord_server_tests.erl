-module(discord_server_tests).
-include_lib("eunit/include/eunit.hrl").

% Setup similar to discord_user_tests
ensure_ets_setup() ->
    % Start our application, which initializes ETS tables
    application:ensure_all_started(discord_clone).

ensure_ets_cleanup() ->
    application:stop(discord_clone).
    % ets:delete(server_table), % if not handled by app stop
    % ets:delete(user_table).   % if not handled by app stop

server_test_() ->
    {setup,
        fun ensure_ets_setup/0,
        fun ensure_ets_cleanup/0,
        [
            fun create_and_get_server/0,
            fun join_server_test/0,
            fun add_channel_to_server_test/0,
            fun is_member_test/0
            % Add more tests: joining non-existent server, user not found during join, etc.
        ]
    }.

create_and_get_server() ->
    {ok, Creator} = discord_user:create_user("server_creator"),
    ServerName = "My Test Server",
    {ok, Server} = discord_server:create_server(Creator#user.id, ServerName),
    ?assertEqual(ServerName, Server#server.name),
    ?assert(lists:member(Creator#user.id, Server#server.members)),

    {ok, FetchedServer} = discord_server:get_server(Server#server.id),
    ?assertEqual(Server, FetchedServer),

    % Check if server was added to user
    {ok, UserAfterServerCreation} = discord_user:get_user(Creator#user.id),
    ?assert(lists:member(Server#server.id, UserAfterServerCreation#user.servers)).

join_server_test() ->
    {ok, UserToJoin} = discord_user:create_user("joiner_user"),
    {ok, Creator} = discord_user:create_user("join_server_creator"),
    {ok, Server} = discord_server:create_server(Creator#user.id, "Joinable Server"),

    {ok, joined, UpdatedServer} = discord_server:join_server(UserToJoin#user.id, Server#server.id),
    ?assert(lists:member(UserToJoin#user.id, UpdatedServer#server.members)),

    % Check user's server list
    {ok, UserAfterJoin} = discord_user:get_user(UserToJoin#user.id),
    ?assert(lists:member(Server#server.id, UserAfterJoin#user.servers)),

    % Try joining again
    {ok, already_member, _} = discord_server:join_server(UserToJoin#user.id, Server#server.id),

    % Try joining non-existent server
    ?assertEqual({error, server_not_found}, discord_server:join_server(UserToJoin#user.id, erlang:make_ref())),
    % Try non-existent user joining
    ?assertEqual({error, user_not_found}, discord_server:join_server(erlang:make_ref(), Server#server.id)).


add_channel_to_server_test() ->
    {ok, Creator} = discord_user:create_user("channel_adder_user"),
    {ok, Server} = discord_server:create_server(Creator#user.id, "Server For Channels"),
    ChannelID = erlang:make_ref(), % Mock channel ID

    {ok, UpdatedServer} = discord_server:add_channel_to_server(Server#server.id, ChannelID),
    ?assertEqual([ChannelID], UpdatedServer#server.channels),

    ChannelID2 = erlang:make_ref(),
    {ok, UpdatedServer2} = discord_server:add_channel_to_server(Server#server.id, ChannelID2),
    ?assertEqual([ChannelID2, ChannelID], UpdatedServer2#server.channels). % Prepends

is_member_test() ->
    {ok, MemberUser} = discord_user:create_user("member_user_for_test"),
    {ok, NonMemberUser} = discord_user:create_user("non_member_user_for_test"),
    {ok, ServerCreator} = discord_user:create_user("creator_for_is_member_test"),
    {ok, Server} = discord_server:create_server(ServerCreator#user.id, "Is Member Test Server"),

    % Creator is a member
    ?assert(discord_server:is_member(ServerCreator#user.id, Server#server.id)),
    % Non-member is not a member
    ?assertNot(discord_server:is_member(NonMemberUser#user.id, Server#server.id)),

    % Add MemberUser and check
    {ok, joined, _} = discord_server:join_server(MemberUser#user.id, Server#server.id),
    ?assert(discord_server:is_member(MemberUser#user.id, Server#server.id)),

    % Check against non-existent server
    ?assertNot(discord_server:is_member(MemberUser#user.id, erlang:make_ref())).
