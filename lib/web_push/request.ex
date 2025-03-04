defmodule WebPushEx.Request do
  @moduledoc """
  Request details ready for sending to the subscription endpoint.
  """

  defstruct [:body, :endpoint, :headers]

  @typedoc """
  Encrypted Content Encoding body.
  """
  @type body :: binary()

  @typedoc """
  `URI` to send the POST request to.
  """
  @type endpoint :: URI.t()

  @typedoc """
  `Map` of headers to include with the POST request.
  """
  @type headers :: %{String.t() => String.t()}

  @type t :: %__MODULE__{
          body: body(),
          endpoint: endpoint(),
          headers: headers()
        }
end
