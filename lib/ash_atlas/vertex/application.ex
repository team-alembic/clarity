defmodule AshAtlas.Vertex.Application do
  @moduledoc false
  @type t() :: %__MODULE__{
          app: Application.app(),
          description: String.t(),
          version: Version.t() | String.t()
        }
  @enforce_keys [:app, :description, :version]
  defstruct [:app, :description, :version]

  @spec from_app_tuple(
          app_tuple ::
            {app :: Application.app(), description :: charlist(), version :: charlist()}
        ) :: t()
  def from_app_tuple({app, description, version}) do
    description = List.to_string(description)
    version = List.to_string(version)

    version =
      case Version.parse(version) do
        {:ok, version} -> version
        _ -> version
      end

    %__MODULE__{app: app, description: description, version: version}
  end

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{app: app}), do: "application:#{app}"

    @impl AshAtlas.Vertex
    def graph_id(%{app: app}), do: Atom.to_string(app)

    @impl AshAtlas.Vertex
    def graph_group(_vertex), do: []

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(Application)

    @impl AshAtlas.Vertex
    def render_name(%{app: app}), do: Atom.to_string(app)

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "house"

    @impl AshAtlas.Vertex
    def markdown_overview(vertex),
      do: [
        "`",
        inspect(vertex.app),
        "`\n\n",
        vertex.description,
        "\n\n",
        "Version: `",
        to_string(vertex.version),
        "`"
      ]
  end
end
