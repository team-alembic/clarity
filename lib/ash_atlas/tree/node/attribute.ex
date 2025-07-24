defmodule AshAtlas.Tree.Node.Attribute do
  @type t() :: %__MODULE__{
          attribute: Ash.Resource.Attribute.t(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:attribute, :resource]
  defstruct [:attribute, :resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{attribute: %{name: name}, resource: resource}),
      do: "attribute:#{inspect(resource)}:#{name}"

    def graph_id(%{attribute: %{name: name}, resource: resource}),
      do:
        "attribute_#{resource |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}_#{name}"

    def render_name(%{attribute: %{name: name}}), do: Atom.to_string(name)

    def dot_shape(_node), do: "rectangle"
  end
end
