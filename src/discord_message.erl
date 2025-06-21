-module(discord_message).
-export([new/3, send_message/3, get_message/1]).

-include_lib("stdlib/include/ms_transform.hrl").

-record(message, {
    id :: atom(), % Unique ID for the message
    channel_id :: atom(), % ID of the channel this message belongs to
    author_id :: atom(), % ID of the user who sent the message
    content :: string(),
    timestamp :: integer() % Unix timestamp
}).

-define(ETS_TABLE, message_table).

new(ChannelID, AuthorID, Content) ->
    MessageID = erlang:make_ref(), % Placeholder for a more robust ID generation
    Timestamp = erlang:system_time(seconds),
    #message{id = MessageID, channel_id = ChannelID, author_id = AuthorID, content = Content, timestamp = Timestamp}.

% Public API
send_message(ChannelID, UserID, Content) ->
    % Verify channel exists and user is allowed to post (e.g. member of server)
    % For simplicity, we'll assume channel exists and user is authorized for now.
    % A more complete check:
    case discord_channel:get_channel(ChannelID) of
        {ok, Channel} ->
            % Check if user is member of the server this channel belongs to
            case discord_server:is_member(UserID, Channel#channel.server_id) of
                true ->
                    NewMessage = new(ChannelID, UserID, Content),
                    true = ets:insert(?ETS_TABLE, NewMessage),
                    % Add message ID (or the message itself) to the channel
                    % If storing only IDs, then discord_channel:add_message_to_channel(ChannelID, NewMessage#message.id)
                    % If storing full messages in channel (as currently implied by channel record):
                    % This approach simplifies get_messages but duplicates data and can be inconsistent.
                    % A better approach is to store only IDs in channel and fetch messages separately.
                    % For now, let's assume we only need to store the message in its own table,
                    % and the channel will get updated with the ID.
                    case discord_channel:add_message_to_channel(ChannelID, NewMessage#message.id) of
                        {ok, _} -> {ok, NewMessage};
                        Error -> Error % e.g. channel_not_found, though we just fetched it.
                    end;
                false ->
                    {error, user_not_member_of_server}
            end;
        {error, not_found} ->
            {error, channel_not_found}
    end.

get_message(MessageID) ->
    case ets:lookup(?ETS_TABLE, MessageID) of
        [Message] -> {ok, Message};
        [] -> {error, not_found}
    end.

% Helper function to initialize ETS table
ensure_table_exists() ->
    case ets:info(?ETS_TABLE) of
        undefined ->
            ets:new(?ETS_TABLE, [set, protected, named_table, {keypos, #message.id}, {read_concurrency, true}]);
        _ ->
            ok
    end.
% ensure_table_exists() function is now called by discord_clone_app during application start.
