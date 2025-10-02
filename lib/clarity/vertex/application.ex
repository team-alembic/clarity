defmodule Clarity.Vertex.Application do
  @moduledoc """
  Vertex implementation for OTP applications.
  """

  @type t() :: %__MODULE__{
          app: Application.app(),
          description: String.t(),
          version: Version.t() | String.t()
        }
  @enforce_keys [:app, :description, :version]
  defstruct [:app, :description, :version]

  @doc """
  Creates an `Clarity.Vertex.Application` from an application tuple.
  """
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

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

    @impl Clarity.Vertex
    def id(%@for{app: app}), do: Util.id(@for, [app])

    @impl Clarity.Vertex
    def type_label(_vertex), do: inspect(Application)

    @impl Clarity.Vertex
    def name(%@for{app: app}), do: Atom.to_string(app)
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "house"
  end

  defimpl Clarity.Vertex.TooltipProvider do
    @impl Clarity.Vertex.TooltipProvider
    def tooltip(vertex),
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
