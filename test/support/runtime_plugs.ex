defmodule Clarity.Test.RuntimePlugs do
  @moduledoc """
  A plug pipeline whose options are initialised at runtime. More follows.
  """

  use Plug.Builder, init_mode: :runtime

  plug Plug.Head
  plug Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason
end
