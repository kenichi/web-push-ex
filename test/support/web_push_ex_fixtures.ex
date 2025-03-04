defmodule WebPushExFixtures do
  @moduledoc """
  Example data from RFC 8291, section 5.

  see: https://datatracker.ietf.org/doc/html/rfc8291/#section-5
  """

  import WebPushEx, only: [decode: 1]

  @doc """
  WebPushSubscription fixture with default `p256dh` and `auth` values from the
  RFC example.
  """
  def web_push_subscription_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      endpoint: URI.parse("https://push.example.com/123"),
      keys: %{
        p256dh:
          "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
        auth: "BTBZMqHH6r4Tts7J_aSIgg"
      }
    })
    |> then(&struct!(WebPushEx.Subscription, &1))
  end

  @doc """
  Application Server key pair, usually generated for every message. The public
  key is eventually included at the end of the body header.
  """
  def as_key_pair do
    {
      decode(
        "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8"
      ),
      decode("yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw")
    }
  end

  @doc """
  User-Agent private key (public key is p256dh value in sub).
  """
  def ua_private, do: decode("q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94")

  @doc """
  Salt, usually generated for every message. The sale is eventually included
  at the beginning of the body header.
  """
  def salt, do: decode("DGv6ra1nlYgDCS1FRnbzlw")

  @doc """
  The plaintext message encrypted in the example ciphertext below.
  """
  def plaintext, do: "When I grow up, I want to be a watermelon"

  @doc """
  The ciphertext result of encrypting the plaintext above.
  """
  def expected,
    do:
      "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27ml" <>
        "mlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPT" <>
        "pK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN"
end
