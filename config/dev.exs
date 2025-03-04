import Config

# use OTP :json for development
config :jose, :json_module, WebPush.JOSEjson

config :web_push_ex, :vapid,
  public_key: "",
  private_key: "",
  subject: "webpush@example.com"
