-module(twitter_rest).
-author("Yuce Tekol").

-export([get/3, post/3, post/4, prev/1, next/1]).
-export([make_cursor/5, make_timeline/5]).
-export([make_get_cursor/4, make_get_timeline/4]).

-include("twitter.hrl").
-include("util.hrl").
-include("def.hrl").


-spec get(#twitter{}, path(), query_args()) -> get_result().
-type get_result() :: {ok, term()}.

get(#twitter{auth=#oauth{token=Token} = Auth,
             json_decode=JsonDecode} = Twitter, Path, Args)
        when Token =/= "" ->
    BaseUrl = make_url(Twitter, Path, ""),
    Request = twitter_auth:make_get_request(Auth, BaseUrl, Args),
    {ok, Body} = request(Request),
    {ok, JsonDecode(Body)};

get(#twitter{auth=#oauth{app_token=BT} = Auth,
             json_decode=JsonDecode} = Twitter, Path, Args)
        when BT =/= "" ->
    Url = make_url(Twitter, Path, twitter_auth:encode_qry(Args)),
    Request = twitter_auth:make_app_request(Auth, Url),
    {ok, Body} = request(Request),
    {ok, JsonDecode(Body)}.


-spec post(#twitter{}, path(), query_args()) -> {ok, term()}.

post(#twitter{auth=#oauth{token=Token} = Auth,
             json_decode=JsonDecode} = Twitter, "statuses/filter", Args, Callback)
        when Token =/= "" ->
    BaseUrl = make_stream_url(Twitter, "statuses/filter", ""),
    Request = twitter_auth:make_post_request(Auth, BaseUrl, Args),
    {ok, Body} = request(post_stream, Request),
    handle_connection(Callback, Body, JsonDecode).

post(#twitter{auth=#oauth{token=Token} = Auth,
             json_decode=JsonDecode} = Twitter, Path, Args)
        when Token =/= "" ->
    BaseUrl = make_url(Twitter, Path, ""),
    Request = twitter_auth:make_post_request(Auth, BaseUrl, Args),
    {ok, Body} = request(post, Request),
    {ok, JsonDecode(Body)}.


-spec prev(#twitter_cursor{} | #twitter_timeline{}) -> pointer_return().
-type  pointer_return() :: {ok, {#twitter_cursor{}, term()}} |
                            {ok, {#twitter_timeline{}, term()}} |
                            {stop, #twitter_cursor{}} |
                            {stop, #twitter_timeline{}}.

prev(#twitter_cursor{api=Api, path=Path, args=OldArgs, prev=Prev, key=Key})
        when Prev > 0 ->
    Args = lists:keystore(cursor, 1, OldArgs, {cursor, Prev}),
    ret_cursor(Api, Path, Args, Key);

prev(#twitter_cursor{} = Cursor) ->
    {stop, Cursor};

prev(#twitter_timeline{api=Api,
                       path=Path,
                       args=OldArgs,
                       first_id=First,
                       key=Key}) when First > 0 ->
    ModArgs = lists:keydelete(since_id, 1, OldArgs),
    Args = lists:keystore(max_id, 1, ModArgs, {max_id, First - 1}),
    ret_timeline(Api, Path, Args, Key);

prev(#twitter_timeline{} = Timeline) ->
    {stop, Timeline}.


-spec next(#twitter_cursor{} | #twitter_timeline{}) -> pointer_return().

next(#twitter_cursor{api=Api, path=Path, args=OldArgs, next=Next, key=Key})
        when Next > 0 ->
    Args = lists:keystore(cursor, 1, OldArgs, {cursor, Next}),
    ret_cursor(Api, Path, Args, Key);

next(#twitter_cursor{} = Cursor) ->
    {stop, Cursor};

next(#twitter_timeline{api=Api,
                       path=Path,
                       args=OldArgs,
                       last_id=Last,
                       key=Key}) when Last > 0 ->
    ModArgs = lists:keydelete(max_id, 1, OldArgs),
    Args = lists:keystore(since_id, 1, ModArgs, {since_id, Last}),
    ret_timeline(Api, Path, Args, Key);

next(#twitter_timeline{} = Timeline) ->
    {stop, Timeline}.


-spec make_cursor(#twitter{}, path(), query_args(), list(), string())
                  -> {#twitter_cursor{}, list()}.

make_cursor(Api, Path, Args, Data, CollectionKey) ->
    {Items, Prev, Next} = get_count_prev_next(Data, CollectionKey),
    {#twitter_cursor{api = Api,
                    path = Path,
                    args = Args,
                    key = CollectionKey,
                    prev = Prev,
                    next = Next}, Items}.


-spec make_timeline(#twitter{}, path(), query_args(), list(), string())
                    -> {#twitter_timeline{}, list()}.

make_timeline(Api, Path, Args, Data, CollectionKey) ->
    {Items, Count, First, Last} =
        get_items_count_first_last_tweet_id(Data, CollectionKey),
    {#twitter_timeline{
        api = Api,
        path = Path,
        args = Args,
        key = CollectionKey,
        first_id = First,
        last_id = Last,
        count = Count}, Items}.


-spec make_get_cursor(#twitter{}, path(), query_args(), string())
                      -> {ok, {#twitter_cursor{}, term()}} |
                         {stop, #twitter_cursor{}}.

make_get_cursor(Api, Path, Args, CollectionKey) ->
    {ok, Items} = twitter_rest:get(Api, Path, Args),
    {ok, twitter_rest:make_cursor(Api, Path, Args, Items, CollectionKey)}.


-spec make_get_timeline(#twitter{}, path(), query_args(), string())
                      -> {ok, {#twitter_timeline{}, term()}} |
                         {stop, #twitter_timeline{}}.

make_get_timeline(Api, Path, Args, CollectionKey) ->
    {ok, Items} = twitter_rest:get(Api, Path, Args),
    {ok, twitter_rest:make_timeline(Api, Path, Args, Items, CollectionKey)}.


-spec ret_cursor(#twitter{}, path(), query_args(), string())
           -> {ok, {#twitter_cursor{}, term()}}.

ret_cursor(Api, Path, Args, Key) ->
    {ok, Data} = get(Api, Path, Args),
    {ok, make_cursor(Api, Path, Args, Data, Key)}.


-spec ret_timeline(#twitter{}, path(), query_args(), string())
           -> {ok, {#twitter_timeline{}, term()}} |
              {stop, #twitter_timeline{}}.

ret_timeline(Api, Path, Args, Key) ->
    {ok, Data} = get(Api, Path, Args),
    {Timeline, Items} = make_timeline(Api, Path, Args, Data, Key),
    #twitter_timeline{count=Count} = Timeline,
    ?select(Count == 0, {stop, Timeline}, {ok, {Timeline, Items}}).


-spec get_count_prev_next(list(), string())
                          -> {list(), pos_integer(), pos_integer()}.

get_count_prev_next(Data, Key) ->
    {_, Prev} = lists:keyfind(<<"previous_cursor">>, 1, Data),
    {_, Next} = lists:keyfind(<<"next_cursor">>, 1, Data),
    {_, Items} = lists:keyfind(list_to_binary(Key), 1, Data),
    {Items, Prev, Next}.


-spec get_tweet_id(list()) -> pos_integer().

get_tweet_id(Tweet) ->
    {_, Id} = lists:keyfind(<<"id">>, 1, Tweet),
    Id.


-spec get_items_count_first_last_tweet_id(list(), string()) -> {list(),
                                                                integer(),
                                                                pos_integer(),
                                                                pos_integer()}.

get_items_count_first_last_tweet_id(Data, Key)
        when Key =/= "" ->
    {_, Items} = lists:keyfind(list_to_binary(Key), 1, Data),
    get_items_count_first_last_tweet_id(Items, "");


get_items_count_first_last_tweet_id([], _Key) ->
    {[], 0, 0, 0};

get_items_count_first_last_tweet_id([H|T] = Items, _Key) ->
    F = fun(X, {Count, _Last}) -> {Count + 1, X} end,
    {Count, First} = lists:foldl(F, {1, H}, T),
    {Items, Count, get_tweet_id(First), get_tweet_id(H)}.


-spec request(request()) -> request_result().
-type request_result() :: {ok, list()} | {error, term()}.

request(Request) ->
    case httpc:request(get, Request, [], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} ->
            {ok, Body};
        {ok, {{_, Status, _}, _, Body}} ->
            {error, {Status, Body}};
        {error, _Reason} = Reply ->
            Reply end.


request(post, Request) ->
    io:format("JUST SOOOOO ~p~n",[Request]),
    case httpc:request(post, Request, [], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} ->
            {ok, Body};
        {ok, {{_, Status, _}, _, Body}} ->
            {error, {Status, Body}};
        {error, _Reason} = Reply ->
            Reply end;

request(post_stream, Request) ->
    io:format("JUST SOOOOO ~p~n",[Request]),
    case httpc:request(post, Request, [], [{sync, false}, {stream, self}]) of
        {ok, {{_, 200, _}, _, Body}} ->
            {ok, Body};
        {ok, {{_, Status, _}, _, Body}} ->
            {error, {Status, Body}};
      {ok, RequestId} ->
            {ok, RequestId};
        {error, _Reason} = Reply ->
            Reply end.


-spec make_url(#twitter{}, path(), query_string()) -> url().

make_stream_url(#twitter{stream_domain = Domain,
                  api_version = ApiVersion,
                  secure = Secure,
                  format = Format}, ApiPath, QryStr) ->
    Scheme = ?select(Secure, "https", "http"),
    Path = lists:concat([ApiVersion, "/", ApiPath, ".", Format]),
    twitter_util:make_url({Scheme, Domain, Path, QryStr}).

make_url(#twitter{domain = Domain,
                  api_version = ApiVersion,
                  secure = Secure,
                  format = Format}, ApiPath, QryStr) ->
    Scheme = ?select(Secure, "https", "http"),
    Path = lists:concat([ApiVersion, "/", ApiPath, ".", Format]),
    twitter_util:make_url({Scheme, Domain, Path, QryStr}).

% TODO maybe change {ok, stream_closed} to an error?
handle_connection(Callback, RequestId, JsonDecode) ->
    receive
        % stream opened
        {http, {RequestId, stream_start, _Headers}} ->
            handle_connection(Callback, RequestId, JsonDecode);

        % stream received data
        {http, {RequestId, stream, Data}} ->
            spawn(fun() ->
              try
                DecodedData = JsonDecode(Data),
                Callback(DecodedData)
              catch
                _:_ ->
                  Callback(Data)
              end
            end),
            handle_connection(Callback, RequestId, JsonDecode);

        % stream closed
        {http, {RequestId, stream_end, _Headers}} ->
            {ok, stream_end};

        % connected but received error cod
        % 401 unauthorised - authentication credentials rejected
        {http, {RequestId, {{_, 401, _}, _Headers, _Body}}} ->
            {error, unauthorised};

        % 406 not acceptable - invalid request to the search api
        {http, {RequestId, {{_, 406, _}, _Headers, Body}}} ->
            {error, {invalid_params, Body}};

        % connection error
        % may happen while connecting or after connected
        {http, {RequestId, {error, Reason}}} ->
            {error, {http_error, Reason}};

        % message send by us to close the connection
        terminate ->
            {ok, terminate}
    end.

