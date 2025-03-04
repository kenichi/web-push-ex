import Config

# use OTP :json for testing
config :jose, :json_module, WebPushEx.JOSEjson

config :web_push_ex, :vapid,
  public_key: "",
  private_key: "",
  subject: "webpush@example.com"
