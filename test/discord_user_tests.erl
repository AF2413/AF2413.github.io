-module(discord_user_tests).
-include_lib("eunit/include/eunit.hrl").

% Setup function to ensure ETS tables are ready for each test case.
% This is important because tests might run in parallel or affect each other.
% A common pattern is to start the application or necessary parts of it.
% For simplicity, we'll ensure tables are clean and initialized.
% Note: `discord_clone_app:start/2` now handles table creation.
% We need to ensure the app is started or at least tables are set up.

ensure_ets_setup() ->
    % Ensure tables are deleted and recreated for a clean state if they exist from previous runs
    % This is a bit heavy-handed for unit tests; ideally, tests mock dependencies or use fresh tables.
    % However, since our functions directly use named ETS tables, we manage them here.
    application:ensure_all_started(discord_clone).

ensure_ets_cleanup() ->
    % Clean up tables after tests if needed, or stop the app
    application:stop(discord_clone).
    % ets:delete(user_table). % Or specific cleanup

% Test fixture for a single test or group of tests
user_test_() ->
    {setup,
        fun ensure_ets_setup/0,
        fun ensure_ets_cleanup/0,
        [
            fun create_and_get_user/0,
            fun create_duplicate_user/0,
            fun get_nonexistent_user/0,
            fun add_server_to_user_test/0
        ]
    }.

create_and_get_user() ->
    Username = "testuser1",
    {ok, User1} = discord_user:create_user(Username),
    ?assertEqual(Username, User1#user.username),

    {ok, FetchedUser} = discord_user:get_user(User1#user.id),
    ?assertEqual(User1, FetchedUser).

create_duplicate_user() ->
    Username = "testuser2",
    {ok, _} = discord_user:create_user(Username),
    ?assertEqual({error, username_taken}, discord_user:create_user(Username)).

get_nonexistent_user() ->
    NonExistentID = erlang:make_ref(),
    ?assertEqual({error, not_found}, discord_user:get_user(NonExistentID)).

add_server_to_user_test() ->
    {ok, User} = discord_user:create_user("user_for_server_test"),
    ServerID = erlang:make_ref(),
    {ok, UpdatedUser} = discord_user:add_server_to_user(User#user.id, ServerID),
    ?assertEqual([ServerID], UpdatedUser#user.servers),
    % Add another server
    ServerID2 = erlang:make_ref(),
    {ok, UpdatedUser2} = discord_user:add_server_to_user(User#user.id, ServerID2),
    ?assertEqual([ServerID2, ServerID], UpdatedUser2#user.servers), % Ensure it prepends
    % Try adding to non-existent user
    ?assertEqual({error, user_not_found}, discord_user:add_server_to_user(erlang:make_ref(), ServerID)).
