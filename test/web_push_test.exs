defmodule WebPushTest do
  use ExUnit.Case, async: true

  import WebPushFixtures

  alias WebPush

  describe "request/3" do
    test "generates details according to example in section 5/appendix A" do
      wps = web_push_subscription_fixture()
      request = WebPush.request(wps, plaintext(), as_key_pair: as_key_pair(), salt: salt())

      assert request.headers
             |> Map.get("Authorization")
             |> String.starts_with?("vapid t=")

      assert Map.get(request.headers, "Content-Encoding") == "aes128gcm"
      refute Map.has_key?(request.headers, "Crypto-Key")
      assert Map.get(request.headers, "Urgency") == "normal"

      assert request.body == WebPush.decode(expected())

      <<salt::binary-size(16), rs::unsigned-big-integer-size(32), idlen::8,
        keyid::binary-size(idlen), _ciphertext::binary>> = request.body

      assert salt == salt()
      assert rs == 4096
      assert idlen == 65
      assert keyid == elem(as_key_pair(), 0)
    end
  end

  describe "from_json/1" do
    test "decodes to struct" do
      observed =
        WebPush.Subscription.from_json("""
        {
          "endpoint": "https://push.example.com/123",
          "keys": {
            "p256dh": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
            "auth": "BTBZMqHH6r4Tts7J_aSIgg"
          }
        }
        """)

      expected = web_push_subscription_fixture()

      assert observed.endpoint == URI.parse(expected.endpoint)
      assert observed.keys == expected.keys
    end
  end
end
