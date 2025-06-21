-module(discord_server).
-export([new/1, create_server/2, get_server/1, add_user_to_server/2, add_channel_to_server/2, join_server/2, is_member/2]).

-include_lib("stdlib/include/ms_transform.hrl").

-record(server, {
    id :: atom(), % Unique ID for the server
    name :: string(),
    channels = [] :: list(atom()), % List of channel IDs
    members = [] :: list(atom())  % List of user IDs
}).

-define(ETS_TABLE, server_table).

new(Name) ->
    ServerID = erlang:make_ref(), % Placeholder for a more robust ID generation
    #server{id = ServerID, name = Name}.

% Public API
create_server(CreatorUserID, ServerName) ->
    % First, ensure the user exists (optional, depends on how strict you want to be)
    % For now, we assume CreatorUserID is valid.
    % We might want to use discord_user:get_user(CreatorUserID) here.

    NewServer = new(ServerName),
    ServerWithMember = NewServer#server{members = [CreatorUserID]},
    true = ets:insert(?ETS_TABLE, ServerWithMember),

    % Add this server to the user's list of servers
    % This creates a circular dependency if called directly.
    % This should ideally be handled by a supervisor or a transactional process.
    % For now, we'll call it and acknowledge the coupling.
    % Consider returning the server and letting the caller update the user.
    % OR: emit an event that a user_manager process listens to.
    case discord_user:add_server_to_user(CreatorUserID, ServerWithMember#server.id) of
        {ok, _} -> {ok, ServerWithMember};
        Error -> Error % Propagate error if adding server to user fails
    end.

get_server(ServerID) ->
    case ets:lookup(?ETS_TABLE, ServerID) of
        [Server] -> {ok, Server};
        [] -> {error, not_found}
    end.

% Renaming add_user_to_server to a more generic name or keeping it as is,
% join_server will be the public API for users to join.
% add_user_to_server can be an internal helper or used by admins.
% For now, join_server will largely mirror add_user_to_server's logic.

join_server(UserID, ServerID) ->
    % Ensure user exists
    case discord_user:get_user(UserID) of
        {ok, _User} ->
            case get_server(ServerID) of
                {ok, Server} ->
                    IsMember = lists:member(UserID, Server#server.members),
                    if
                        IsMember -> {ok, already_member, Server};
                        true ->
                            UpdatedServer = Server#server{members = [UserID | Server#server.members]},
                            true = ets:insert(?ETS_TABLE, UpdatedServer),
                            case discord_user:add_server_to_user(UserID, ServerID) of
                                {ok, _} -> {ok, joined, UpdatedServer};
                                Error -> Error % e.g. user update failed, though get_user passed.
                            end
                    end;
                {error, not_found} ->
                    {error, server_not_found}
            end;
        {error, not_found} ->
            {error, user_not_found}
    end.

add_user_to_server(ServerID, UserID) -> % This could be an admin function or internal helper
    case get_server(ServerID) of
        {ok, Server} ->
            IsMember = lists:member(UserID, Server#server.members),
            if
                IsMember -> {ok, Server};
                true ->
                    UpdatedServer = Server#server{members = [UserID | Server#server.members]},
                    true = ets:insert(?ETS_TABLE, UpdatedServer),
                    case discord_user:add_server_to_user(UserID, ServerID) of
                         {ok, _} -> {ok, UpdatedServer};
                         Error -> Error
                    end
            end;
        {error, not_found} ->
            {error, server_not_found}
    end.

is_member(UserID, ServerID) ->
    case get_server(ServerID) of
        {ok, Server} ->
            lists:member(UserID, Server#server.members);
        {error, not_found} ->
            false
    end.

add_channel_to_server(ServerID, ChannelID) ->
     case get_server(ServerID) of
        {ok, Server} ->
            UpdatedServer = Server#server{channels = [ChannelID | Server#server.channels]},
            true = ets:insert(?ETS_TABLE, UpdatedServer),
            {ok, UpdatedServer};
        {error, not_found} ->
            {error, server_not_found}
    end.


% Helper function to initialize ETS table
ensure_table_exists() ->
    case ets:info(?ETS_TABLE) of
        undefined ->
            ets:new(?ETS_TABLE, [set, protected, named_table, {keypos, #server.id}, {read_concurrency, true}]);
        _ ->
            ok
    end.
% ensure_table_exists() function is now called by discord_clone_app during application start.
