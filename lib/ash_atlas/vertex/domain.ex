defmodule AshAtlas.Vertex.Domain do
  @type t() :: %__MODULE__{
          domain: Ash.Domain.t()
        }
  @enforce_keys [:domain]
  defstruct [:domain]

  defimpl AshAtlas.Vertex do
    def unique_id(%{domain: domain}), do: "domain:#{inspect(domain)}"
    def graph_id(%{domain: domain}), do: inspect(domain)
    def graph_group(_vertex), do: []
    def type_label(_vertex), do: inspect(Ash.Domain)
    def render_name(%{domain: domain}), do: inspect(domain)
    def dot_shape(_vertex), do: "folder"
  end
end
