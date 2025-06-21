-module(discord_channel).
-export([new/2, create_channel/3, get_channel/1, add_message_to_channel/2, get_messages/1]).

-include_lib("stdlib/include/ms_transform.hrl").

-record(channel, {
    id :: atom(), % Unique ID for the channel
    server_id :: atom(), % ID of the server this channel belongs to
    name :: string(),
    messages = [] :: list(atom()) % List of message IDs (or actual message records for simplicity here)
}).

-define(ETS_TABLE, channel_table).

new(ServerID, Name) ->
    ChannelID = erlang:make_ref(), % Placeholder for a more robust ID generation
    #channel{id = ChannelID, server_id = ServerID, name = Name}.

% Public API
create_channel(ServerID, UserID, ChannelName) ->
    % Check if user is a member of the server
    case discord_server:is_member(UserID, ServerID) of
        true ->
            % Check if server exists (is_member implicitly does this, but good for clarity)
            case discord_server:get_server(ServerID) of
                {ok, Server} ->
                    NewChannel = new(ServerID, ChannelName),
                    true = ets:insert(?ETS_TABLE, NewChannel),
                    % Add channel to server's list of channels
                    case discord_server:add_channel_to_server(ServerID, NewChannel#channel.id) of
                        {ok, _} -> {ok, NewChannel};
                        Error -> Error % Should not happen if server exists
                    end;
                {error, not_found} -> % Should be caught by is_member check effectively
                    {error, server_not_found}
            end;
        false ->
            {error, user_not_member_of_server}
    end.

get_channel(ChannelID) ->
    case ets:lookup(?ETS_TABLE, ChannelID) of
        [Channel] -> {ok, Channel};
        [] -> {error, not_found}
    end.

add_message_to_channel(ChannelID, MessageID) -> % Or Message record
    case get_channel(ChannelID) of
        {ok, Channel} ->
            % Prepend new messages to keep them in reverse chronological order easily
            UpdatedChannel = Channel#channel{messages = [MessageID | Channel#channel.messages]},
            true = ets:insert(?ETS_TABLE, UpdatedChannel),
            {ok, UpdatedChannel};
        {error, not_found} ->
            {error, channel_not_found}
    end.

get_messages(ChannelID) ->
    case get_channel(ChannelID) of
        {ok, Channel} ->
            % Messages are stored with newest first.
            % If chronological order is needed for display, reverse this list.
            % For now, returning as stored.
            % If MessageIDs are stored, this would involve fetching each message.
            % Assuming actual message content/records are stored for now for simplicity.
            {ok, Channel#channel.messages};
        {error, not_found} ->
            {error, channel_not_found, []}
    end.

% Helper function to initialize ETS table
ensure_table_exists() ->
    case ets:info(?ETS_TABLE) of
        undefined ->
            ets:new(?ETS_TABLE, [set, protected, named_table, {keypos, #channel.id}, {read_concurrency, true}]);
        _ ->
            ok
    end.
% ensure_table_exists() function is now called by discord_clone_app during application start.
