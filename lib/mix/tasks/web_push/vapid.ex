defmodule Mix.Tasks.WebPushEx.Vapid do
  @moduledoc """
  Generate VAPID keys for config.

  Example:

      $ mix web_push.vapid

  """

  @shortdoc "Generate VAPID keys for config"

  use Mix.Task

  @impl true
  def run(_args) do
    :ecdh
    |> :crypto.generate_key(:prime256v1)
    |> encode()
    |> build_config_message()
    |> IO.puts()
  end

  defp encode({public_key, private_key}), do: {encode(public_key), encode(private_key)}

  defp encode(key), do: WebPushEx.encode(key)

  defp build_config_message({public_key, private_key}) do
    """
    # in config/config.exs:

        config :web_push_ex, :vapid,
          public_key: "#{public_key}",
          subject: "webpush-admin-email@example.com"

    # in config/runtime.exs:

        config :web_push_ex, :vapid,
          private_key: System.fetch_env!("WEB_PUSH_EX_VAPID_PRIVATE_KEY")

    # in your environment:

        export WEB_PUSH_EX_VAPID_PRIVATE_KEY=#{private_key}
    """
  end
end
