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
          {:ok, %{vertex: vertex, lens: lens}} = Clarity.Content.fetch_session(session)
          {:ok, assign(socket, vertex: vertex, lens: lens)}
        end

        @impl Phoenix.LiveView
        def render(assigns) do
          ~H"\""
          <div>Interactive content for {@vertex}</div>
          "\""
        end
      end

  The session holds only plain values: the `"clarity_pid"` of the Clarity server, the
  `"lens_id"` and the `"vertex_id"`. `fetch_session/1` turns them back into the lens and
  vertex. Providers that want to read the graph or `Clarity.subscribe/2` can use
  `"clarity_pid"` directly.

  ## Configuration

  Content provider configuration is managed by `Clarity.Config`. See the documentation
  for `Clarity.Config` for detailed configuration options and examples.
  """

  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex

  @type static_content_type() :: :markdown | :mermaid | :viz
  @type theme() :: :light | :dark
  @type static_content_props() :: %{
          optional(:name_style) => Vertex.Name.style(),
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
          live_component?: boolean(),
          render_static: rendered_static_content() | nil,
          sort_priority: integer(),
          status_classes: [atom()]
        }

  @enforce_keys [:id, :name, :provider, :live_view?, :live_component?]
  defstruct [
    :id,
    :name,
    :description,
    :provider,
    :live_view?,
    :live_component?,
    :render_static,
    sort_priority: 0,
    status_classes: []
  ]

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
  """
  @callback render_static(vertex :: Vertex.t(), lens :: Lens.t()) :: static_content()

  @doc """
  Returns the sort priority for this content provider.

  Lower values sort first. The default is `0`. Use negative values to sort
  before other content (e.g., overview tabs), and positive values to sort
  after (e.g., graph navigation).
  """
  @callback sort_priority() :: integer()

  @doc """
  Returns the status classes this content explains.

  When the vertex carries a `Clarity.Status` of one of these classes (and the
  lens surfaces it), the content's tab is flagged with a severity indicator, so a
  developer can see which tab explains a flagged node. Defaults to `[]`.

  For example, the Version Status tab returns `[:hygiene]` and the Advisories tab
  returns `[:security]`.
  """
  @callback status_classes() :: [atom()]

  @optional_callbacks [render_static: 2, sort_priority: 0, status_classes: 0]

  @doc false
  @spec get_contents_for_vertex(Vertex.t(), Lens.t()) :: [t()]
  def get_contents_for_vertex(vertex, lens) do
    lens
    |> providers_for_lens()
    |> Enum.filter(&applies?(&1, vertex, lens))
    |> Enum.map(&build_content_struct(&1, vertex, lens))
    |> Enum.sort(lens.content_sorter)
  end

  @doc false
  @spec providers_for_lens(Lens.t()) :: [module()]
  def providers_for_lens(lens), do: shown_by(Clarity.Config.list_content_providers(), lens)

  # Whether any of the lens's providers (providers_for_lens/1) has a tab for the
  # vertex, without building the tabs.
  @doc false
  @spec any_applies?([module()], Vertex.t(), Lens.t()) :: boolean()
  def any_applies?(providers, vertex, lens), do: Enum.any?(providers, &applies?(&1, vertex, lens))

  # A lens may name the providers whose tabs it shows, or those it doesn't.
  @spec shown_by([module()], Lens.t()) :: [module()]
  defp shown_by(providers, %Lens{contents: :all}), do: providers

  defp shown_by(providers, %Lens{contents: {:except, hidden}}),
    do: Enum.reject(providers, &(&1 in hidden))

  defp shown_by(providers, %Lens{contents: shown}), do: Enum.filter(providers, &(&1 in shown))

  @spec applies?(module(), Vertex.t(), Lens.t()) :: boolean()
  defp applies?(provider, vertex, lens) do
    case Code.ensure_loaded(provider) do
      {:module, ^provider} ->
        if function_exported?(provider, :applies?, 2) do
          provider.applies?(vertex, lens)
        else
          false
        end

      _ ->
        false
    end
  end

  @spec build_content_struct(module(), Vertex.t(), Lens.t()) :: t()
  defp build_content_struct(provider, vertex, lens) do
    live_view? = implements_behaviour?(provider, Phoenix.LiveView)
    live_component? = implements_behaviour?(provider, Phoenix.LiveComponent)

    render_static =
      if function_exported?(provider, :render_static, 2) do
        normalize_static_content(provider.render_static(vertex, lens))
      end

    sort_priority =
      if function_exported?(provider, :sort_priority, 0),
        do: provider.sort_priority(),
        else: 0

    status_classes =
      if function_exported?(provider, :status_classes, 0),
        do: provider.status_classes(),
        else: []

    %__MODULE__{
      id: content_id(provider),
      name: provider.name(),
      description: if(function_exported?(provider, :description, 0), do: provider.description()),
      provider: provider,
      live_view?: live_view?,
      live_component?: live_component?,
      render_static: render_static,
      sort_priority: sort_priority,
      status_classes: status_classes
    }
  end

  @spec normalize_static_content(static_content()) :: rendered_static_content()
  defp normalize_static_content({type, content}) when is_binary(content) or is_list(content) do
    {type, fn _props -> content end}
  end

  defp normalize_static_content({type, content}) when is_function(content, 1) do
    {type, content}
  end

  @doc """
  Resolves a LiveView content provider's session into its vertex and lens.

  Call this from the provider's `c:Phoenix.LiveView.mount/3`. The session holds ids,
  not structs, because a LiveView session is signed and can't hold functions, and
  lenses and some vertices do.

  ## Examples

      @impl Phoenix.LiveView
      def mount(_params, session, socket) do
        {:ok, %{vertex: vertex, lens: lens}} = Clarity.Content.fetch_session(session)
        {:ok, assign(socket, vertex: vertex, lens: lens)}
      end
  """
  @spec fetch_session(map()) ::
          {:ok, %{vertex: Vertex.t(), lens: Lens.t()}}
          | {:error, :lens_not_found | :vertex_not_found}
  def fetch_session(%{
        "clarity_pid" => clarity_pid,
        "lens_id" => lens_id,
        "vertex_id" => vertex_id
      }) do
    with {:ok, lens} <- Lensmaker.get_lens_by_id(lens_id),
         vertex when not is_nil(vertex) <-
           Clarity.Graph.get_vertex(Clarity.get(clarity_pid, :partial).graph, vertex_id) do
      {:ok, %{vertex: vertex, lens: lens}}
    else
      nil -> {:error, :vertex_not_found}
      {:error, :lens_not_found} = error -> error
    end
  end

  @doc false
  @spec session(GenServer.server(), Vertex.t(), Lens.t()) :: %{String.t() => term()}
  def session(clarity_pid, vertex, lens) do
    %{"clarity_pid" => clarity_pid, "lens_id" => lens.id, "vertex_id" => Vertex.id(vertex)}
  end

  @doc false
  @spec content_id(module()) :: String.t()
  def content_id(provider) do
    provider
    |> Macro.underscore()
    |> String.replace(~r/[_\/]+/, "-")
    |> String.replace_prefix("clarity-content-", "")
  end

  @spec implements_behaviour?(module(), module()) :: boolean()
  defp implements_behaviour?(module, behaviour) do
    {:module, ^module} = Code.ensure_loaded(module)

    :attributes
    |> module.module_info()
    |> Keyword.get_values(:behaviour)
    |> Enum.concat()
    |> Enum.member?(behaviour)
  end
end
