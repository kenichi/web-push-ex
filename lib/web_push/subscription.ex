defmodule WebPushEx.Subscription do
  @moduledoc """
  Subscription data structure.
  """

  defstruct [:endpoint, :keys]

  @typedoc """
  Matching structure returned from User Agents with JSON import/export functions.
  """
  @type t :: %__MODULE__{
          endpoint: URI.t(),
          keys: %{
            required(:p256dh) => String.t(),
            required(:auth) => String.t()
          }
        }

  @doc """
  Build and return a new struct from a JSON string.
  """
  @spec from_json(String.t()) :: t()
  def from_json(json) do
    with decoded <- :json.decode(json),
         endpoint <- Map.fetch!(decoded, "endpoint"),
         uri <- URI.parse(endpoint),
         keys <- Map.fetch!(decoded, "keys") do
      %__MODULE__{
        endpoint: uri,
        keys: %{
          p256dh: Map.fetch!(keys, "p256dh"),
          auth: Map.fetch!(keys, "auth")
        }
      }
    end
  end
end
