defmodule WebPushEx.JOSEjson do
  @moduledoc """
  :json wrapper for JOSE.
  """

  @behaviour :jose_json

  @impl true
  def decode(binary), do: :json.decode(binary)

  @impl true
  def encode(term) do
    term
    |> :json.encode()
    |> :erlang.iolist_to_binary()
  end
end
