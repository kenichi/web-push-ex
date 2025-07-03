# WebPushEx

This library implements
[RFC 8291](https://datatracker.ietf.org/doc/html/rfc8291/) Message Encryption
for Web Push in Elixir.

It generates request details but does not make the HTTP POST request itself. The
generated details should be enough to feed to your HTTP client of choice.

#### Features

* `aes128gcm` content encoding method
* uses `:json` (requires Erlang/OTP >=27)
* uses JOSE for handling JWT
* bring your own HTTP client
* tested using RFC examples

## Configuration

`WebPush` needs VAPID keys to work. Run `mix web_push.vapid` and adapt the
generated config to your needs:

```
$ mix web_push.vapid
# in config/config.exs:

    config :web_push_ex, :vapid,
      public_key: "<base64 encoded public key>"
      subject: "webpush-admin-email@example.com"

# in config/runtime.exs:

    config :web_push_ex, :vapid,
      private_key: System.fetch_env!("WEB_PUSH_VAPID_PRIVATE_KEY")

# in your environment:

    export WEB_PUSH_EX_VAPID_PRIVATE_KEY=<base64 encoded private key>
```

## Usage

Your application should handle getting and persisting subscription data from
browsers. The implementation is up to you but the VAPID public key is required
to be presented when calling `pushManager.subscribe()`:

```javascript
pushManager.subscribe({
  userVisibleOnly: true,
  applicationServerKey: vapidPublicKey,
}).then(...);
```

Once you have your subscription data, you may construct a `WebPushEx.Request` and
use it to make the push notification via the HTTP client of your choice.

```elixir
# create the struct from the subscription JSON data
subscription =
  WebPushEx.Subscription.from_json("""
  {"endpoint":"https://push.example.com/123","keys":{"p256dh":"user_agent_public_key","auth":"auth_secret"}}
  """)

# structured message, see example serviceWorker.js linked below
message = %{title: "Notification Title", body: "lorem ipsum etc"}

# generate request details
%WebPushEx.Request{} = request = WebPushEx.request(subscription, :json.encode(message) |> to_string())

request.endpoint
# => "https://push.example.com/123"

request.body
# => binary data

request.headers
# => %{
#   "Authorization" => "vapid t=..., k=...",
#   "Content-Encoding" => "aes128gcm",
#   "Content-Length" => "42",
#   "Content-Type" => "application/octet-stream",
#   "TTL" => "43200",
#   "Urgency" => "normal"
# }

# send web push notification via http client e.g. req
{:ok, resp} = Req.post(request.endpoint, body: request.body, headers: request.headers)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `web_push` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:web_push_ex, "~> 0.1.0"}
  ]
end
```

## tl()

#### Motivation && Inspiration

Many thanks to maintainers and contributors to all these repos 🙇

* [web-push-elixir](https://github.com/midarrlabs/web-push-elixir)
* [web-push-encryption](https://github.com/tuvistavie/elixir-web-push-encryption)
* [web-push](https://github.com/web-push-libs/web-push)
* [erl_web_push](https://github.com/truqu/erl_web_push)

#### Useful Links

* https://datatracker.ietf.org/doc/html/rfc8291/
* https://datatracker.ietf.org/doc/html/rfc8188/
* https://datatracker.ietf.org/doc/html/rfc3279/

* https://mozilla-services.github.io/WebPushDataTestPage/
* https://developer.mozilla.org/en-US/docs/Web/API/Push_API
* https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers
* https://github.com/mdn/serviceworker-cookbook/tree/master/push-payload
* https://blog.mozilla.org/services/2016/08/23/sending-vapid-identified-webpush-notifications-via-mozillas-push-service/
* https://hacks.mozilla.org/2017/05/debugging-web-push-in-mozilla-firefox/

* https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers
