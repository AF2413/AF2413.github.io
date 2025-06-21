-module(discord_user).
-export([new/1, create_user/1, get_user/1, add_server_to_user/2]).

-include_lib("stdlib/include/ms_transform.hrl").

-record(user, {
    id :: atom(), % Unique ID for the user
    username :: string(),
    servers = [] :: list(atom()) % List of server IDs the user is a member of
}).

-define(ETS_TABLE, user_table).

new(Username) ->
    UserID = erlang:make_ref(), % Placeholder for a more robust ID generation
    #user{id = UserID, username = Username}.

% Public API
create_user(Username) ->
    case ets:lookup(?ETS_TABLE, username_idx, Username) of
        [] ->
            NewUser = new(Username),
            true = ets:insert(?ETS_TABLE, NewUser),
            true = ets:insert_new(?ETS_TABLE, {username_idx, Username, NewUser#user.id}),
            {ok, NewUser};
        [_] ->
            {error, username_taken}
    end.

get_user(UserID) ->
    case ets:lookup(?ETS_TABLE, UserID) of
        [User] -> {ok, User};
        [] -> {error, not_found}
    end.

add_server_to_user(UserID, ServerID) ->
    case get_user(UserID) of
        {ok, User} ->
            UpdatedUser = User#user{servers = [ServerID | User#user.servers]},
            true = ets:insert(?ETS_TABLE, UpdatedUser),
            {ok, UpdatedUser};
        {error, not_found} ->
            {error, user_not_found}
    end.

% Helper function to initialize ETS table (e.g. in application start)
% For now, we can call it manually or assume it's called.
ensure_table_exists() ->
    case ets:info(?ETS_TABLE) of
        undefined ->
            ets:new(?ETS_TABLE, [set, protected, named_table, {keypos, #user.id}, {read_concurrency, true}]),
            ets:insert(?ETS_TABLE, {username_idx, nil, nil}); % for unique username check
        _ ->
            ok
    end.
% ensure_table_exists() function is now called by discord_clone_app during application start.
