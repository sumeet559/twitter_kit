
-record(oauth, {
    token = "",
    token_secret = "",
    consumer_key = "",
    consumer_secret = "",
    app_token = ""}).


-record(twitter, {
    auth = nil,
    format = json,
    stream_domain = "stream.twitter.com",
    domain = "api.twitter.com",
    upload_domain = "upload.twitter.com",
    secure = true,
    api_version = "1.1",
    json_decode = fun jsx:decode/1}).


-record(twitter_timeline, {
    api = nil,
    path = "",
    args = [],
    key = "",
    first_id = 0,
    last_id = 0,
    count = 0}).


-record(twitter_cursor, {
    api = nil,
    path = "",
    args = [],
    key = "",
    prev = 0,
    next = 0}).
