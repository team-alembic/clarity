defmodule AshAtlas.Tree.Node.Action do
  @type t() :: %__MODULE__{
          action: Ash.Resource.Actions.action(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:action, :resource]
  defstruct [:action, :resource]

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{action: %{name: name}, resource: resource}),
      do: "action:#{inspect(resource)}:#{name}"

    def graph_id(%{action: %{name: name}, resource: resource}),
      do: "action_#{resource |> Macro.underscore() |> String.replace(~r/[^a-z_]/, "_")}_#{name}"

    def render_name(%{action: %{type: type, name: name}}), do: "#{name}\n(#{type})"

    def dot_shape(_node), do: "cds"
  end
end
