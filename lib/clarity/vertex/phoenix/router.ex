defmodule Clarity.Vertex.Phoenix.Router do
  @moduledoc """
  Vertex implementation for Phoenix routers.
  """

  alias Clarity.SourceLocation

  @type t() :: %__MODULE__{router: module()}
  @enforce_keys [:router]
  defstruct [:router]

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

    @impl Clarity.Vertex
    def id(%@for{router: module}), do: Util.id(@for, [module])

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Clarity.Vertex.Phoenix.Router"

    @impl Clarity.Vertex
    def name(%@for{router: module}), do: inspect(module)
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "foo"
  end

  defimpl Clarity.Vertex.ModuleProvider do
    @impl Clarity.Vertex.ModuleProvider
    def module(%@for{router: router}), do: router
  end

  defimpl Clarity.Vertex.SourceLocationProvider do
    @impl Clarity.Vertex.SourceLocationProvider
    def source_location(%@for{router: module}) do
      SourceLocation.from_module(module)
    end
  end

  defimpl Clarity.Vertex.TooltipProvider do
    @impl Clarity.Vertex.TooltipProvider
    def tooltip(%@for{router: module}),
      do: [
        "`",
        inspect(module),
        "`\n\n",
        "| Name | Method | Path | Plug | Action |\n",
        "| ---- | ------ | ---- | ---------- | ------ |\n",
        Enum.map(module.__routes__(), fn %{
                                           verb: verb,
                                           path: path,
                                           plug: plug,
                                           plug_opts: plug_opts
                                         } = route ->
          [
            "| ",
            case Map.fetch(route, :helper) do
              :error -> ""
              {:ok, nil} -> ""
              {:ok, helper} -> [helper, "_path"]
            end,
            " | ",
            verb |> Atom.to_string() |> String.upcase(),
            " | ",
            path,
            " | ",
            inspect(plug),
            " | ",
            inspect(plug_opts),
            " |\n"
          ]
        end)
      ]
  end
end
