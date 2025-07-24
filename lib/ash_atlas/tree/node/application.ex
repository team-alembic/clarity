defmodule AshAtlas.Tree.Node.Application do
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

  defimpl AshAtlas.Tree.Node do
    def unique_id(%{app: app}), do: "application:#{app}"
    def graph_id(%{app: app}), do: "app_#{Atom.to_string(app)}"
    def render_name(%{app: app}), do: Atom.to_string(app)
    def dot_shape(_node), do: "house"
  end
end
