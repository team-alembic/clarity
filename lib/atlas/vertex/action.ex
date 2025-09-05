defmodule Atlas.Vertex.Action do
  @moduledoc false
  alias Ash.Resource.Actions

  @type t() :: %__MODULE__{
          action: Actions.action(),
          resource: Ash.Resource.t()
        }
  @enforce_keys [:action, :resource]
  defstruct [:action, :resource]

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(%{action: %{name: name}, resource: resource}),
      do: "action:#{inspect(resource)}:#{name}"

    @impl Atlas.Vertex
    def graph_id(%{action: %{name: name}, resource: resource}),
      do: [inspect(resource), "_", Atom.to_string(name)]

    @impl Atlas.Vertex
    def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Actions)]

    @impl Atlas.Vertex
    def type_label(%{action: %mod{}}), do: inspect(mod)

    @impl Atlas.Vertex
    def render_name(%{action: %{name: name}}), do: Atom.to_string(name)

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "cds"

    @impl Atlas.Vertex
    def markdown_overview(%{action: action, resource: resource}) do
      [
        "Action: `",
        inspect(action.name),
        "` on Resource: `",
        inspect(resource),
        "`\n\n",
        if action.description do
          [action.description, "\n\n"]
        else
          []
        end,
        case action.arguments do
          [] ->
            []

          args ->
            [
              "## Arguments\n",
              Enum.map(args, fn arg ->
                [
                  "- `",
                  inspect(arg.name),
                  "` (`",
                  inspect(arg.type),
                  "`)",
                  if arg.description do
                    [
                      ": ",
                      arg.description
                    ]
                  else
                    []
                  end,
                  "\n"
                ]
              end),
              "\n\n"
            ]
        end
      ]
    end
  end
end
