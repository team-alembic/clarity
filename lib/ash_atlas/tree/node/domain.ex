defmodule AshAtlas.Tree.Node.Domain do
  @type t() :: %__MODULE__{
          domain: Ash.Domain.t()
        }
  @enforce_keys [:domain]
  defstruct [:domain]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{domain: domain}), do: "domain:#{inspect(domain)}"

    def graph_id(%{domain: domain}),
      do: "domain_#{domain |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}"

    def render_name(%{domain: domain}), do: inspect(domain)

    def dot_shape(_node), do: "folder"
  end
end
