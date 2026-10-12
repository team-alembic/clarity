defmodule Clarity.Autolink.Lookup do
  @moduledoc false

  # Names that link in text about `vertex`, settled one at a time as the text
  # mentions them (see Clarity.Autolink.lookup/2), rather than all of a graph's
  # names up front.

  @type t() :: %__MODULE__{index: map(), context: map(), vertex: Clarity.Vertex.t() | nil}

  @enforce_keys [:index, :context, :vertex]
  defstruct [:index, :context, :vertex]
end
