-module(ra_process_set).
-behaviour(ra_machine).

-export([
         init/1,
         apply/3,

         add/3,
         remove/2,
         member/2,
         consensus_member/2
        ]).

-type key() :: binary().

-record(?MODULE, {value :: #{key() => pid()}}).

%%
%% API
%%

add(Id, Pid, RaServer) ->
    case ra:process_command(RaServer, {add, Id, Pid}) of
        {ok, _, _} -> ok;
        Err        -> Err
    end.

remove(Id, RaServer) ->
    case ra:process_command(RaServer, {remove, Id}) of
        {ok, _, _} -> ok;
        Err        -> Err
    end.

member(Id, RaServer) ->
    {ok, {_, Val}, _Leader} = ra:local_query(RaServer, fun(#?MODULE{value = M}) ->
                                                               maps:is_key(Id, M)
                                                       end),
    Val.

consensus_member(Id, RaServer) ->
    case ra:process_command(RaServer, {get, Id}) of
        {ok, _, _} -> ok;
        Err        -> Err
    end.


init(_) ->
    #?MODULE{value = #{}}.

apply(_Metadata, {add, Id, Pid}, State = #?MODULE{value = M0}) ->
    case maps:take(Id, M0) of
        error         ->
            M = maps:put(Id, Pid, M0),
            {State#?MODULE{value = M}, ok, []};
        {Pid, _Rest} ->
            {State, ok, []};
        {Other, Rest} ->
            M1 = maps:put(Id, Pid, Rest),
            Effect = {send_msg, Other, {duplicate, Pid}},
            {State#?MODULE{value = M1}, ok, [Effect]}
    end;

apply(_Metadata, {remove, Id}, State = #?MODULE{value = M}) ->
    {State#?MODULE{value = maps:remove(Id, M)}, ok, []};

apply(_Metadata, {get, Id}, State = #?MODULE{value = M}) ->
    {State, maps:get(Id, M, undefined), []}.
