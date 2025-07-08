defmodule WebPushExTest do
  use ExUnit.Case, async: true

  import WebPushExFixtures

  describe "request/3" do
    test "generates details according to example in section 5/appendix A" do
      wps = web_push_subscription_fixture()
      request = WebPushEx.request(wps, plaintext(), as_key_pair: as_key_pair(), salt: salt())

      assert request.headers
             |> Map.get("Authorization")
             |> String.starts_with?("vapid t=")

      assert Map.get(request.headers, "Content-Encoding") == "aes128gcm"
      refute Map.has_key?(request.headers, "Crypto-Key")
      assert Map.get(request.headers, "Urgency") == "normal"

      assert request.body == WebPushEx.decode(expected())

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
        WebPushEx.Subscription.from_json("""
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

    test "raises KeyError with invalid keys" do
      # auth key
      assert_raise KeyError, fn ->
        WebPushEx.Subscription.from_json("""
        {
          "endpoint": "https://push.example.com/123",
          "keys": {
            "p256dh": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
            "au": "BTBZMqHH6r4Tts7J_aSIgg"
          }
        }
        """)
      end

      # p256dh key
      assert_raise KeyError, fn ->
        WebPushEx.Subscription.from_json("""
        {
          "endpoint": "https://push.example.com/123",
          "keys": {
            "p256": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
            "auth": "BTBZMqHH6r4Tts7J_aSIgg"
          }
        }
        """)
      end

      # keys key
      assert_raise KeyError, fn ->
        WebPushEx.Subscription.from_json("""
        {
          "endpoint": "https://push.example.com/123",
          "key": {
            "p256dh": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
            "auth": "BTBZMqHH6r4Tts7J_aSIgg"
          }
        }
        """)
      end

      # endpoint key
      assert_raise KeyError, fn ->
        WebPushEx.Subscription.from_json("""
        {
          "end": "https://push.example.com/123",
          "keys": {
            "p256dh": "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
            "auth": "BTBZMqHH6r4Tts7J_aSIgg"
          }
        }
        """)
      end
    end
  end
end
