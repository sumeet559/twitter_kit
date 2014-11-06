#! /usr/bin/env escript
%% -*- erlang -*-
%%! -pa ebin

main(_Args) ->
    sample:ensure_started(),
    Api = sample:api(),
    %Resp = twitter:get(Api, "statuses/home_timeline", [{count, 1}]),
    Resp = twitter:get(Api, "statuses/user_timeline", [{screen_name, "Hurriyet"}, {count, 1}]),
    io:format("~p~n", [Resp]).
    %io:format("~n").
