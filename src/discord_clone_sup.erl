-module(discord_clone_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 1, period => 5},
    ChildSpecs = [
        % Define child worker processes here if needed in the future.
        % For example, if we had GenServers managing specific domains:
        % #{
        %   id => user_manager,
        %   start => {user_manager, start_link, []},
        %   restart => permanent,
        %   shutdown => 2000,
        %   type => worker,
        %   modules => [user_manager]
        % }
    ],
    {ok, {SupFlags, ChildSpecs}}.
