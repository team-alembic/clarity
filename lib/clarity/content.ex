defmodule Clarity.Content do
  @moduledoc """
  Behavior and struct for content providers that display information about vertices.

  Content providers decide whether they should be displayed for a given vertex and lens,
  and can provide either static content (markdown, mermaid, graphviz) or implement a
  full LiveView for interactive content.

  ## Static Content Providers

  Static content providers implement the `c:render_static/2` callback:

      defmodule MyApp.CustomContent do
        @behaviour Clarity.Content

        @impl Clarity.Content
        def name, do: "Custom Analysis"

        @impl Clarity.Content
        def description, do: "Provides custom analysis for resources"

        @impl Clarity.Content
        def applies?(%Vertex.Ash.Resource{}, _lens), do: true
        def applies?(_vertex, _lens), do: false

        @impl Clarity.Content
        def render_static(vertex, _lens) do
          {:markdown, "# Analysis for \#{inspect(vertex)}"}
        end
      end

  ## LiveView Content Providers

  Content providers can also be LiveView modules. Simply implement `Phoenix.LiveView`
  alongside the `Clarity.Content` behavior:

      defmodule MyApp.InteractiveContent do
        use Phoenix.LiveView
        @behaviour Clarity.Content

        @impl Clarity.Content
        def name, do: "Interactive Dashboard"

        @impl Clarity.Content
        def description, do: "Interactive visualization"

        @impl Clarity.Content
        def applies?(%Vertex.Ash.Resource{}, _lens), do: true
        def applies?(_vertex, _lens), do: false

        @impl Phoenix.LiveView
        def mount(_params, session, socket) do
          vertex = session["vertex"]
          lens = session["lens"]
          {:ok, assign(socket, vertex: vertex, lens: lens)}
        end

        @impl Phoenix.LiveView
        def render(assigns) do
          ~H"\""
          <div>Interactive content for {@vertex}</div>
          "\""
        end
      end

  ## Registration

  Register content providers in your application configuration:

      config :my_app, :clarity_content_providers, [
        MyApp.CustomContent,
        MyApp.InteractiveContent
      ]

  ## Built-in Content Providers

  Clarity includes several built-in content providers:
  - `Clarity.Content.Graph` - Graph visualization (always shown)
  - `Clarity.Content.Moduledoc` - Module documentation
  - `Clarity.Content.Ash.DomainOverview` - Ash domain overview
  - `Clarity.Content.Ash.ResourceOverview` - Ash resource overview
  """

  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  @type static_content_type() :: :markdown | :mermaid | :viz
  @type theme() :: :light | :dark
  @type static_content_props() :: %{
          theme: theme(),
          zoom_subgraph: Clarity.Graph.t()
        }
  @type static_content() ::
          {static_content_type(), iodata() | (static_content_props() -> iodata())}
  @type rendered_static_content() :: {static_content_type(), (static_content_props() -> iodata())}

  @typedoc "A module implementing the `Clarity.Content` behavior"
  @type provider() :: module()

  @typedoc """
  Content struct representing a content provider instance for a specific vertex and lens.
  """
  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          provider: provider(),
          live_view?: boolean(),
          render_static: rendered_static_content() | nil
        }

  @enforce_keys [:id, :name, :provider, :live_view?]
  defstruct [:id, :name, :description, :provider, :live_view?, :render_static]

  @doc """
  Returns the name of this content provider.

  This is displayed as the tab name in the UI.
  """
  @callback name() :: String.t()

  @doc """
  Returns an optional description of this content provider.

  This may be used in tooltips or help text.
  """
  @callback description() :: String.t() | nil

  @doc """
  Determines whether this content should be displayed for the given vertex and lens.

  Return `true` to show this content, `false` to hide it.
  """
  @callback applies?(vertex :: Vertex.t(), lens :: Lens.t()) :: boolean()

  @doc """
  Renders static content for the given vertex and lens.

  Returns a tuple of `{type, content}` where:
  - `:markdown` - Markdown text (iodata or function returning iodata)
  - `:mermaid` - Mermaid diagram (iodata or function returning iodata)
  - `:viz` - Graphviz DOT format (iodata or function returning iodata, or function taking theme map)

  This callback is only called for content providers that don't implement `Phoenix.LiveView`.
  """
  @callback render_static(vertex :: Vertex.t(), lens :: Lens.t()) :: static_content()

  @optional_callbacks [render_static: 2]
end
