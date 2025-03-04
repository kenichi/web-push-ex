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
    {decoded, :ok, ""} = :json.decode(json, :ok, %{object_push: &object_push/3})

    struct!(__MODULE__, decoded)
  end

  @spec object_push(String.t(), :json.decode_value(), :ok) :: list()
  defp object_push(key, value, acc) do
    key = String.to_existing_atom(key)

    value =
      if key == :endpoint and is_binary(value) do
        URI.parse(value)
      else
        value
      end

    [{key, value} | acc]
  end
end
