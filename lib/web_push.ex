defmodule WebPushEx do
  @moduledoc """
  Web Push notifications via `aes128gcm`.

  Implementation of RFC 8291, 8188, & 5689.
  """

  alias WebPushEx.{Request, Subscription}

  @base64_options [padding: false]
  @default_exp 12 * 60 * 60
  @jwt_header %{"typ" => "JWT", "alg" => "ES256"}

  @type info :: binary()
  @type input_keying_material :: binary()
  @type length :: non_neg_integer()
  @type psuedo_random_key :: binary()
  @type salt :: binary()
  @type key :: binary()
  @type vapid_key :: :private_key | :public_key | :subject

  @doc """
  Build and return a Request struct with details ready for sending.
  """
  @spec request(Subscription.t(), String.t(), keyword()) :: Request.t()
  def request(%Subscription{} = subscription, message, options \\ []) do
    body = encrypt_payload(message, subscription, options)
    jwt = sign_jwt(subscription)
    vapid_public_key = fetch_vapid!(:public_key, false)

    %Request{
      body: body,
      endpoint: subscription.endpoint,
      headers: %{
        "Authorization" => "vapid t=#{jwt}, k=#{vapid_public_key}",
        "Content-Encoding" => "aes128gcm",
        "Content-Length" => "#{byte_size(body)}",
        "Content-Type" => "application/octet-stream",
        "TTL" => to_string(@default_exp),
        "Urgency" => "normal"
      }
    }
  end

  @spec sign_jwt(Subscription.t()) :: binary()
  defp sign_jwt(%Subscription{endpoint: %URI{} = endpoint}) do
    aud = %URI{scheme: endpoint.scheme, host: endpoint.host} |> URI.to_string()

    jwt =
      JOSE.JWT.from_map(%{aud: aud, exp: twelve_hours_from_now(), sub: fetch_vapid!(:subject)})

    jwk =
      JOSE.JWK.from_key({
        :ECPrivateKey,
        1,
        fetch_vapid!(:private_key),
        {:namedCurve, {1, 2, 840, 10_045, 3, 1, 7}},
        fetch_vapid!(:public_key),
        nil
      })

    {%{alg: :jose_jws_alg_ecdsa}, signed_jwt} =
      jwk
      |> JOSE.JWT.sign(@jwt_header, jwt)
      |> JOSE.JWS.compact()

    signed_jwt
  end

  @doc """
  Encrypt a message according to RFCs 8291, 8188, 5869.

  see: https://datatracker.ietf.org/doc/html/rfc8291/#section-3.1
  """
  @spec encrypt_payload(String.t(), Subscription.t(), keyword()) :: binary()
  def encrypt_payload(payload, %Subscription{} = subscription, options \\ []) do
    # When sending a push message, the application server also generates a
    # new ECDH key pair on the same P-256 curve.
    {as_public, as_private} =
      options[:as_key_pair] || :crypto.generate_key(:ecdh, :prime256v1)

    # An application server combines its ECDH private key with the public
    # key provided by the user agent using the process described in [ECDH]
    #
    # ecdh_secret = ECDH(as_private, ua_public)
    #
    ua_public = decode(subscription.keys.p256dh)
    ecdh_secret = :crypto.compute_key(:ecdh, ua_public, as_private, :prime256v1)

    # Use HKDF to combine the ECDH and authentication secrets

    # key_info = "WebPush: info" || 0x00 || ua_public || as_public
    info = "WebPush: info" <> <<0>> <> ua_public <> as_public

    # # HKDF-Extract(salt=auth_secret, IKM=ecdh_secret)
    # PRK_key = HMAC-SHA-256(auth_secret, ecdh_secret)
    # # HKDF-Expand(PRK_key, key_info, L_key=32)
    # IKM = HMAC-SHA-256(PRK_key, key_info || 0x01)
    ikm =
      subscription.keys.auth
      |> decode()
      |> hkdf_extract(ecdh_secret)
      |> hkdf_expand(info, 32)

    # salt = random(16)
    salt = options[:salt] || :crypto.strong_rand_bytes(16)

    # ## HKDF calculations from RFC 8188
    # # HKDF-Extract(salt, IKM)
    # PRK = HMAC-SHA-256(salt, IKM)
    prk = hkdf_extract(salt, ikm)

    # # HKDF-Expand(PRK, cek_info, L_cek=16)
    # cek_info = "Content-Encoding: aes128gcm" || 0x00
    cek_info = "Content-Encoding: aes128gcm" <> <<0>>

    # CEK = HMAC-SHA-256(PRK, cek_info || 0x01)[0..15]
    cek = hkdf_expand(prk, cek_info, 16)

    # # HKDF-Expand(PRK, nonce_info, L_nonce=12)
    # nonce_info = "Content-Encoding: nonce" || 0x00
    nonce_info = "Content-Encoding: nonce" <> <<0>>

    # NONCE = HMAC-SHA-256(PRK, nonce_info || 0x01)[0..11]
    nonce = hkdf_expand(prk, nonce_info, 12)

    # +-----------+--------+-----------+---------------+
    # | salt (16) | rs (4) | idlen (1) | keyid (idlen) |
    # +-----------+--------+-----------+---------------+
    header =
      salt <>
        <<4096::unsigned-big-integer-size(32)>> <>
        <<byte_size(as_public)>> <>
        as_public

    {out_crypto_text, out_cypto_tag} =
      :crypto.crypto_one_time_aead(
        :aes_128_gcm,
        cek,
        nonce,
        # Each record contains a single padding delimiter octet followed by any
        # number of zero octets.  The last record uses a padding delimiter
        # octet set to the value 2, all other records have a padding delimiter
        # octet value of 1.
        <<payload::binary, 2>>,
        # The additional data passed to each invocation of AEAD_AES_128_GCM is
        # a zero-length octet sequence.
        <<>>,
        true
      )

    header <> out_crypto_text <> out_cypto_tag
  end

  @doc """
  URL-safe Base64 encode a binary with @base64_options (padding: false).
  """
  @spec encode(binary()) :: String.t()
  def encode(binary), do: Base.url_encode64(binary, @base64_options)

  @doc """
  Decode a URL-safe Base64-encoded string with @base64_options (padding: false).
  """
  @spec decode(String.t()) :: binary()
  def decode(string), do: Base.url_decode64!(string, @base64_options)

  @spec hkdf_extract(salt(), input_keying_material()) :: psuedo_random_key()
  defp hkdf_extract(salt, input_keying_material) do
    :crypto.mac(:hmac, :sha256, salt, input_keying_material)
  end

  @spec hkdf_expand(psuedo_random_key(), info(), length()) :: key()
  defp hkdf_expand(psuedo_random_key, info, length) do
    :crypto.macN(:hmac, :sha256, psuedo_random_key, <<info::binary, 1>>, length)
  end

  @spec fetch_vapid!(vapid_key(), boolean()) :: String.t()
  defp fetch_vapid!(key, decode \\ true) do
    :web_push_ex
    |> Application.fetch_env!(:vapid)
    |> Keyword.fetch!(key)
    |> decode_if(key, decode)
  end

  @spec decode_if(String.t(), vapid_key(), boolean()) :: binary() | String.t()
  defp decode_if(value, :subject, _), do: value
  defp decode_if(value, _key, false), do: value
  defp decode_if(value, _, _), do: decode(value)

  @spec twelve_hours_from_now() :: integer()
  defp twelve_hours_from_now do
    DateTime.utc_now()
    |> DateTime.add(12, :hour)
    |> DateTime.to_unix()
  end
end
