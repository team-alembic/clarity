with {:module, Phoenix.Endpoint} <- Code.ensure_loaded(Phoenix.Endpoint) do
  defmodule Clarity.Content.Phoenix.EndpointPipeline do
    @moduledoc """
    Content provider for the path a request takes through a Phoenix
    endpoint.

    Leads with how many plugs the endpoint runs before it hands a request to
    its router, then each step in order: the socket dispatch, every plug
    (with what the well-known ones do) and the router. Below are the
    router's pipelines; a box to try a request, which traces it through
    every plug, pipeline and `on_mount` hook to the controller or LiveView
    that handles it; and the routes, grouped by the pipelines they pass
    through, each of which fills in the box.

    `Clarity.Phoenix.Pipeline` reads the plugs from compiled code. Without
    debug info, the tab says so and shows the rest.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents

    alias Clarity.Phoenix.Pipeline
    alias Clarity.Tooltip
    alias Clarity.Vertex
    alias Clarity.Vertex.Phoenix.Endpoint
    alias Clarity.Vertex.Phoenix.Router, as: RouterVertex
    alias Phoenix.LiveView.Rendered
    alias Phoenix.LiveView.Socket

    @methods ~w(GET POST PUT PATCH DELETE)

    # Each method's flag: coloured for what it does to what it names.
    @method_flags %{
      "GET" => {:good, "Reads"},
      "POST" => {:key, "Creates, or acts"},
      "PUT" => {:warn, "Replaces"},
      "PATCH" => {:warn, "Updates"},
      "DELETE" => {:danger, "Deletes"}
    }

    @impl Clarity.Content
    def name, do: "Pipeline"

    @impl Clarity.Content
    def description, do: "How requests pass through this endpoint, its router and its routes"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Endpoint{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      fresh? = socket.assigns[:vertex] != assigns.vertex

      socket =
        socket
        |> assign(assigns)
        |> assign(
          links: links(assigns),
          within:
            if(Map.get(assigns, :name_style, :qualified) == :short,
              do: Application.get_application(assigns.vertex.endpoint)
            )
        )

      # Read the endpoint once; later updates keep the request being tried.
      socket =
        if fresh?,
          do:
            socket |> assign(read(assigns.vertex.endpoint, socket.assigns.links)) |> try_a_route(),
          else: socket

      {:ok, socket}
    end

    @impl Phoenix.LiveComponent
    def handle_event("try", %{"method" => method, "path" => path}, socket),
      do: {:noreply, try_request(socket, method, path)}

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content w-full" id={@id}>
        <div class="ov-page">
          <div class="ov-head">
            <.hero vertex={@vertex} kind="Endpoint">
              <:badge :if={@code_reloading?}>
                <.flag text="code reloading" />
              </:badge>
              <:headline :if={@steps != nil}>
                <span class="ov-phrase">
                  Runs <b>{plural(length(@steps), "plug")}</b>
                  <%= if @routers == [] do %>
                    on each request
                  <% else %>
                    then hands each request to
                    <.vertex_link
                      :for={router <- @routers}
                      links={@links}
                      vertex={%RouterVertex{router: router.router}}
                      label={module_label(router.router, @within)}
                    />
                  <% end %>
                </span>
              </:headline>
              <.description links={@links} text={@doc} lead />
            </.hero>

            <.facts>
              <:fact label="URL"><code class="ov-code">{@url}</code></:fact>
              <:fact :if={@app_name} label="Application">
                <.vertex_link :if={@app} links={@links} vertex={@app} />
                <code :if={!@app} class="ov-code">{inspect(@app_name)}</code>
              </:fact>
              <:fact :if={@sockets != []} label="Sockets">
                <.code_list names={Enum.map(@sockets, &elem(&1, 0))} />
              </:fact>
              <:fact :if={@error_formats != []} label="Errors render as">
                <.code_list names={@error_formats} />
              </:fact>
            </.facts>

            <.stats>
              <:stat
                :if={@steps != nil}
                label={plural_word(length(@steps), "Plug")}
                count={length(@steps)}
                href="#request-pipeline"
                icon="endpoint"
                tone="web"
              />
              <:stat
                :for={router <- @routers}
                label={plural_word(length(router.pipelines), "Pipeline")}
                count={length(router.pipelines)}
                href="#pipelines"
                icon="router"
                tone="web"
              />
              <:stat
                :for={router <- @routers}
                label={plural_word(length(router.routes), "Route")}
                count={length(router.routes)}
                href="#routes"
                icon="router"
                tone="web"
              />
            </.stats>
          </div>

          <.callout :if={@steps == nil}>
            This endpoint's build has no debug info, so its plugs can't be read. Its sockets,
            router pipelines and routes are below.
          </.callout>

          <.section
            :if={@steps != nil}
            id="request-pipeline"
            title="Request pipeline"
            icon="endpoint"
            tone="web"
            count={length(@steps)}
          >
            <ol class="ov-steps ov-pipeline">
              <li :if={@sockets != []}>
                <div class="ov-step-body">
                  <div class="ov-phrase">
                    <span class="ov-step-name">Sockets</span>
                    <span
                      :for={{{path, handler, _opts}, index} <- Enum.with_index(@sockets)}
                      class="ov-phrase"
                    >
                      <span :if={index > 0} class="ov-muted">·</span>
                      <code class="ov-code">{path}</code>
                      <span class="ov-join-arrow">→</span>
                      <.module_ref links={@links} module={handler} within={@within} />
                    </span>
                  </div>
                  <p class="ov-step-about">
                    Hands socket connections to their handlers, before any plug runs
                  </p>
                </div>
              </li>
              <li :for={plug <- @steps}>
                <div class="ov-step-body">
                  <div class="ov-phrase">
                    <.plug_name links={@links} plug={plug} within={@within} />
                    <.code_list :if={Pipeline.options(plug) != []} names={Pipeline.options(plug)} />
                    <.flag :if={Pipeline.dev?(plug)} text="dev" />
                  </div>
                  <p :if={Pipeline.about(plug)} class="ov-step-about">{Pipeline.about(plug)}</p>
                </div>
              </li>
              <li :for={router <- @routers}>
                <div class="ov-step-body">
                  <div class="ov-phrase">
                    <.vertex_link
                      links={@links}
                      vertex={%RouterVertex{router: router.router}}
                      label={module_label(router.router, @within)}
                    />
                    <span class="ov-muted">{plural(length(router.routes), "route")}</span>
                  </div>
                  <p class="ov-step-about">
                    Matches the request to a route, then runs that route's pipelines and its handler
                  </p>
                </div>
              </li>
            </ol>
          </.section>

          <.section
            :for={router <- @routers}
            :if={router.pipelines != []}
            id="pipelines"
            title="Router pipelines"
            icon="router"
            tone="web"
            count={length(router.pipelines)}
          >
            <:aside>
              <.vertex_link
                links={@links}
                vertex={%RouterVertex{router: router.router}}
                label={module_label(router.router, @within)}
              />
            </:aside>
            <div class="ov-cards">
              <div
                :for={{name, plugs} <- router.pipelines}
                id={"pipeline-#{name}"}
                class="ov-card ov-pipeline-card"
              >
                <div class="ov-phrase">
                  <.pipeline_pill name={name} />
                  <span class="ov-muted ml-auto text-xs">
                    {plural(Enum.count(router.routes, &(name in (&1.pipe_through || []))), "route")}
                  </span>
                </div>
                <ol :if={plugs not in [nil, []]} class="ov-chain">
                  <li :for={plug <- plugs}>
                    <.plug_name links={@links} plug={plug} within={@within} hint />
                    <.code_list :if={Pipeline.options(plug) != []} names={Pipeline.options(plug)} />
                  </li>
                </ol>
                <p :if={plugs == []} class="ov-muted mt-1.5 text-xs">Runs no plugs</p>
              </div>
            </div>
          </.section>

          <.section :if={@routers != []} id="try" title="Try a request" icon="endpoint" tone="web">
            <.form
              for={@try_form}
              id="try-request"
              class="ov-try"
              phx-change="try"
              phx-submit="try"
              phx-target={@myself}
            >
              <select id="try-method" name={@try_form[:method].name} aria-label="Method">
                <option :for={method <- @methods} value={method} selected={method == @request.method}>
                  {method}
                </option>
              </select>
              <input
                id="try-path"
                type="text"
                name={@try_form[:path].name}
                value={@request.path}
                aria-label="Path"
                placeholder="/path"
                autocomplete="off"
                spellcheck="false"
                phx-debounce="150"
              />
            </.form>
            <.journey
              links={@links}
              request={@request}
              steps={@steps}
              routers={@routers}
              within={@within}
            />
          </.section>

          <.section
            :for={router <- @routers}
            id="routes"
            title="Routes"
            icon="router"
            tone="web"
            count={length(router.routes)}
          >
            <p :if={router.routes == []} class="ov-muted">This router has no routes.</p>
            <div
              :for={{{pipe_through, routes}, index} <- Enum.with_index(groups(router.routes))}
              class="ov-route-group"
            >
              <div class="ov-route-group-head">
                <.pipe_through names={pipe_through} />
                <span class="ov-count">{length(routes)}</span>
              </div>
              <.overview_table id={"routes-#{index}"} rows={routes} class="ov-routes">
                <:col :let={route} label="Method" class="ov-routes-method">
                  <.method_flag verb={route.verb} />
                </:col>
                <:col :let={route} label="Path" class="ov-routes-path">
                  <a
                    href="#try"
                    class="ov-try-path"
                    phx-click={
                      JS.push("try",
                        value: %{method: method(route.verb), path: route.path},
                        target: @myself
                      )
                    }
                    {Tooltip.attrs("Try this route")}
                  >
                    <.route_path path={route.path} />
                  </a>
                </:col>
                <:col :let={route} label="Handler">
                  <.handler links={@links} handler={route.handler} within={@within} />
                </:col>
              </.overview_table>
            </div>
          </.section>
        </div>
      </div>
      """
    end

    attr :links, :map, required: true
    attr :request, :map, required: true
    attr :steps, :list, required: true
    attr :routers, :list, required: true
    attr :within, :atom, required: true, doc: "The application whose modules have short names"

    @spec journey(map()) :: Rendered.t()
    defp journey(assigns) do
      ~H"""
      <ol id="try-journey" class="ov-journey">
        <%= case @request.result do %>
          <% {:socket, socket} -> %>
            <li>
              <span class="ov-journey-stage">Socket</span>
              <div class="ov-phrase">
                <code class="ov-code">{socket.path}</code>
                <.flag>{socket.transport}</.flag>
                <span class="ov-join-arrow">→</span>
                <.module_ref links={@links} module={socket.handler} within={@within} />
                <span class="ov-muted">before any plug runs</span>
              </div>
            </li>
          <% nil -> %>
          <% {result, router, info} -> %>
            <li :if={@steps}>
              <span class="ov-journey-stage">Endpoint</span>
              <.plug_chain links={@links} plugs={@steps} within={@within} />
            </li>
            <%= if result == :route do %>
              <li :for={pipe <- info.pipe_through}>
                <span class="ov-journey-stage"><.pipeline_pill name={pipe} /></span>
                <.plug_chain
                  links={@links}
                  plugs={pipeline_plugs(router, pipe)}
                  within={@within}
                />
              </li>
              <li :if={info.handler.on_mount != []}>
                <span class="ov-journey-stage">On mount</span>
                <div class="ov-phrase">
                  <.module_ref
                    :for={hook <- info.handler.on_mount}
                    links={@links}
                    module={hook}
                    within={@within}
                  />
                </div>
              </li>
              <li :if={info.handler.plugs != []}>
                <span class="ov-journey-stage">Controller</span>
                <.plug_chain links={@links} plugs={info.handler.plugs} within={@within} />
              </li>
              <li class="ov-journey-end">
                <span class="ov-journey-stage">Handler</span>
                <div class="ov-phrase">
                  <.handler
                    links={@links}
                    handler={info.handler}
                    within={@within}
                    plugs={false}
                  />
                  <span :for={{name, value} <- info.path_params} class="ov-param-value">
                    {name} <span class="ov-muted">=</span> <code>{value}</code>
                  </span>
                </div>
              </li>
            <% else %>
              <li class="ov-journey-end">
                <span class="ov-journey-stage">Router</span>
                <div class="ov-phrase">
                  <.flag kind={:danger} hint="Not found">404</.flag>
                  No route matches, so
                  <.module_ref links={@links} module={router.router} within={@within} /> raises
                  <code class="ov-code">Phoenix.Router.NoRouteError</code>
                </div>
              </li>
            <% end %>
        <% end %>
      </ol>
      """
    end

    attr :links, :map, required: true
    attr :plugs, :list, required: true
    attr :within, :atom, required: true, doc: "The application whose modules have short names"

    @spec plug_chain(map()) :: Rendered.t()
    defp plug_chain(assigns) do
      ~H"""
      <div class="ov-phrase">
        <span :if={@plugs in [nil, []]} class="ov-muted">No plugs</span>
        <%= for {plug, index} <- Enum.with_index(@plugs || []) do %>
          <span :if={index > 0} class="ov-join-arrow">›</span>
          <.plug_name links={@links} plug={plug} within={@within} hint />
        <% end %>
      </div>
      """
    end

    attr :links, :map, required: true
    attr :plug, :map, required: true
    attr :within, :atom, required: true, doc: "The application whose modules have short names"
    attr :hint, :boolean, default: false, doc: "Whether its hover hint says what it does"

    # A module plug links to its module's page, when the graph has it; a
    # function plug names its function, and says where it's from on hover.
    @spec plug_name(map()) :: Rendered.t()
    defp plug_name(%{plug: %{kind: :module}} = assigns) do
      ~H"""
      <.module_ref
        links={@links}
        module={@plug.module}
        within={@within}
        hint={if @hint, do: plug_hint(@plug, Pipeline.about(@plug))}
      />
      """
    end

    defp plug_name(assigns) do
      assigns =
        assign(
          assigns,
          :source,
          "#{inspect(assigns.plug.module)}.#{assigns.plug.function}/2"
        )

      ~H"""
      <code
        class="ov-code ov-plug-fn"
        {Tooltip.attrs(plug_hint(@plug, if(@hint, do: Pipeline.about(@plug)), @source))}
      >
        {Pipeline.name(@plug)}
      </code>
      """
    end

    attr :links, :map, required: true
    attr :module, :atom, required: true
    attr :within, :atom, required: true, doc: "The application whose modules have short names"
    attr :hint, :string, default: nil, doc: "Its hover hint, if not the module's"

    @spec module_ref(map()) :: Rendered.t()
    defp module_ref(assigns) do
      assigns = assign(assigns, :vertex, module_vertex(assigns.links, assigns.module))

      ~H"""
      <.vertex_link
        :if={@vertex && !@hint}
        links={@links}
        vertex={@vertex}
        label={module_label(@module, @within)}
        code
      />
      <.link
        :if={@vertex && @hint}
        patch={path(@links, @vertex)}
        class="ov-link ov-code"
        {Tooltip.attrs(@hint)}
      >
        {module_label(@module, @within)}
      </.link>
      <code :if={!@vertex} class="ov-code" {Tooltip.attrs(@hint || inspect(@module))}>
        {module_label(@module, @within)}
      </code>
      """
    end

    attr :links, :map, required: true
    attr :handler, :map, required: true
    attr :within, :atom, required: true, doc: "The application whose modules have short names"
    attr :plugs, :boolean, default: true, doc: "Whether to show the controller's plugs"

    @spec handler(map()) :: Rendered.t()
    defp handler(assigns) do
      ~H"""
      <span class="ov-phrase">
        <.module_ref links={@links} module={@handler.module} within={@within} />
        <code :if={@handler.action} class="ov-code ov-muted">:{@handler.action}</code>
        <.flag :if={@handler.live?} text="live" />
        <span :if={@plugs and @handler.plugs != []} class="ov-phrase">
          <span class="ov-muted">after</span>
          <.plug_name
            :for={plug <- @handler.plugs}
            links={@links}
            plug={plug}
            within={@within}
            hint
          />
        </span>
      </span>
      """
    end

    attr :name, :atom, required: true

    @spec pipeline_pill(map()) :: Rendered.t()
    defp pipeline_pill(assigns) do
      ~H"""
      <a
        href={"#pipeline-#{@name}"}
        class="ov-pill ov-pill-link"
        data-tone="web"
        {Tooltip.attrs("The #{@name} pipeline")}
      >
        {@name}
      </a>
      """
    end

    attr :names, :list, required: true

    @spec pipe_through(map()) :: Rendered.t()
    defp pipe_through(assigns) do
      ~H"""
      <span class="ov-phrase">
        <span :if={@names == nil} class="ov-muted">Pipelines unknown</span>
        <span :if={@names == []} class="ov-muted">No pipelines</span>
        <%= for {name, index} <- Enum.with_index(@names || []) do %>
          <span :if={index > 0} class="ov-join-arrow">›</span>
          <.pipeline_pill name={name} />
        <% end %>
      </span>
      """
    end

    attr :verb, :atom, required: true

    @spec method_flag(map()) :: Rendered.t()
    defp method_flag(assigns) do
      {kind, hint} = Map.get(@method_flags, method(assigns.verb), {:muted, "Any method"})
      assigns = assign(assigns, kind: kind, hint: hint)

      ~H"""
      <span class="ov-flag ov-method" data-kind={@kind} {Tooltip.attrs(@hint)}>
        {if @verb == :*, do: "ANY", else: method(@verb)}
      </span>
      """
    end

    attr :path, :string, required: true

    # A route's path, with its parameters picked out. Kept unformatted, so
    # no whitespace falls between its parts.
    @spec route_path(map()) :: Rendered.t()
    defp route_path(assigns) do
      assigns =
        assign(
          assigns,
          :segments,
          Regex.split(~r{([:*][A-Za-z0-9_]+)}, assigns.path, include_captures: true, trim: true)
        )

      ~H"""
      <code class="ov-code ov-route-path" phx-no-format><span :for={segment <- @segments} class={String.starts_with?(segment, [":", "*"]) && "ov-param"}>{segment}</span></code>
      """
    end

    # What the tab shows of an endpoint: its plugs (nil when they can't be
    # read), sockets and routers, each with its pipelines and routes.
    @spec read(module(), map()) :: keyword()
    defp read(endpoint, links) do
      plugs = Pipeline.plugs(endpoint)
      host = endpoint.host()
      routers = endpoint |> routers(plugs) |> Enum.map(&router(&1, host))

      [
        endpoint: endpoint,
        doc: moduledoc(endpoint),
        url: endpoint.url(),
        app_name: Application.get_application(endpoint),
        app: app(endpoint, links),
        host: host,
        code_reloading?: endpoint.config(:code_reloader) == true,
        error_formats: error_formats(endpoint),
        sockets: endpoint.__sockets__(),
        steps: steps(plugs, routers),
        routers: routers,
        methods: @methods
      ]
    end

    # The endpoint's plugs, but for its socket dispatch and routers, which
    # are steps of their own.
    @spec steps({:ok, [Pipeline.plug()]} | :error, [map()]) :: [Pipeline.plug()] | nil
    defp steps(:error, _routers), do: nil

    defp steps({:ok, plugs}, routers) do
      router_modules = Enum.map(routers, & &1.router)

      Enum.reject(plugs, fn plug ->
        (plug.kind == :function and plug.function == :socket_dispatch) or
          (plug.kind == :module and plug.module in router_modules)
      end)
    end

    # The routers the endpoint plugs in, or without its plugs, its
    # application's.
    @spec routers(module(), {:ok, [Pipeline.plug()]} | :error) :: [module()]
    defp routers(_endpoint, {:ok, plugs}),
      do: for(%{kind: :module, module: module} <- plugs, router?(module), do: module)

    defp routers(endpoint, :error) do
      case :application.get_key(Application.get_application(endpoint), :modules) do
        {:ok, modules} -> Enum.filter(modules, &router?/1)
        :undefined -> []
      end
    end

    @spec router?(module()) :: boolean()
    defp router?(module),
      do: Code.ensure_loaded?(module) and function_exported?(module, :__routes__, 0)

    @spec router(module(), String.t() | nil) :: map()
    defp router(router, host) do
      routes = router.__routes__()
      controllers = controllers(routes)

      routes =
        for route <- routes do
          %{
            verb: route.verb,
            path: route.path,
            handler: handler_of(route.plug, route.plug_opts, route.metadata, controllers),
            pipe_through: pipe_through_of(router, route, host)
          }
        end

      pipelines =
        case Pipeline.pipelines(router) do
          {:ok, pipelines} ->
            pipelines

          :error ->
            routes
            |> Enum.flat_map(&(&1.pipe_through || []))
            |> Enum.uniq()
            |> Enum.map(&{&1, nil})
        end

      %{router: router, routes: routes, pipelines: pipelines, controllers: controllers}
    end

    # The plugs of each controller the routes dispatch to.
    @spec controllers([map()]) :: %{optional(module()) => [Pipeline.plug()]}
    defp controllers(routes) do
      routes
      |> Enum.map(& &1.plug)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == Phoenix.LiveView.Plug))
      |> Map.new(fn plug ->
        case Pipeline.controller(plug) do
          {:ok, plugs} -> {plug, plugs}
          :error -> {plug, []}
        end
      end)
    end

    # The pipelines a route passes through, as matching its path finds them;
    # unknown when another route matches it first.
    @spec pipe_through_of(module(), map(), String.t() | nil) :: [atom()] | nil
    defp pipe_through_of(router, route, host) do
      case Phoenix.Router.route_info(router, method(route.verb), route.path, host) do
        %{route: path, pipe_through: pipe_through} when path == route.path -> pipe_through
        _other -> nil
      end
    end

    # What handles a route: a LiveView and its live action, with the hooks
    # its live session mounts, or a plug such as a controller, its action,
    # and the controller's plugs that run for the action (`runs` is
    # `:unknown` for those whose guards need more than the action).
    @spec handler_of(module(), term(), map(), map()) :: map()
    defp handler_of(plug, plug_opts, metadata, controllers) do
      case metadata[:phoenix_live_view] do
        {view, action, _opts, live_session} ->
          on_mount =
            for %{id: {hook, _arg}} <-
                  live_session |> Map.get(:extra, %{}) |> Map.get(:on_mount, []),
                do: hook

          %{module: view, action: action, live?: true, on_mount: on_mount, plugs: []}

        _plug ->
          action = if is_atom(plug_opts) and plug_opts != nil, do: plug_opts

          %{
            module: plug,
            action: action,
            live?: false,
            on_mount: [],
            plugs: controllers |> Map.get(plug, []) |> Enum.flat_map(&running(&1, action))
          }
      end
    end

    # A controller's plug, if it runs for the action.
    @spec running(Pipeline.plug(), atom() | nil) :: [map()]
    defp running(plug, action) do
      case Pipeline.runs?(plug, action) do
        false -> []
        runs -> [Map.put(plug, :runs, runs)]
      end
    end

    @spec pipeline_plugs(map(), atom()) :: [Pipeline.plug()] | nil
    defp pipeline_plugs(router, pipe) do
      case List.keyfind(router.pipelines, pipe, 0) do
        {_name, plugs} ->
          plugs

        nil ->
          [%{kind: :module, module: pipe, function: :call, opts: [], init: :compile, guard: nil}]
      end
    end

    # Routes in groups by the pipelines they pass through, in the order the
    # router first uses each.
    @spec groups([map()]) :: [{[atom()] | nil, [map()]}]
    defp groups(routes) do
      grouped = Enum.group_by(routes, & &1.pipe_through)
      routes |> Enum.map(& &1.pipe_through) |> Enum.uniq() |> Enum.map(&{&1, grouped[&1]})
    end

    # Starts the box with the router's first GET route, or its first.
    @spec try_a_route(Socket.t()) :: Socket.t()
    defp try_a_route(socket) do
      routes = Enum.flat_map(socket.assigns.routers, & &1.routes)
      route = Enum.find(routes, &(&1.verb == :get)) || List.first(routes)

      case route do
        nil -> try_request(socket, "GET", "/")
        route -> try_request(socket, method(route.verb), route.path)
      end
    end

    @spec try_request(Socket.t(), String.t(), String.t()) ::
            Socket.t()
    defp try_request(socket, method, path) do
      method = method |> String.trim() |> String.upcase()
      path = request_path(path)

      assign(socket,
        request: %{method: method, path: path, result: trace(socket.assigns, method, path)},
        try_form: to_form(%{"method" => method, "path" => path})
      )
    end

    # Where a request goes: to a socket's handler, or through the router to
    # a route's handler, or to no route at all.
    @spec trace(map(), String.t(), String.t()) ::
            {:socket, map()} | {:route | :no_route, map(), map() | nil} | nil
    defp trace(%{sockets: sockets, routers: routers, host: host}, method, path) do
      case {socket_for(sockets, path), routers} do
        {%{} = socket, _routers} ->
          {:socket, socket}

        {nil, [router | _rest]} ->
          case Phoenix.Router.route_info(router.router, method, path, host) do
            %{} = info ->
              {:route, router,
               Map.put(
                 info,
                 :handler,
                 handler_of(info.plug, info.plug_opts, info, router.controllers)
               )}

            :error ->
              {:no_route, router, nil}
          end

        {nil, []} ->
          nil
      end
    end

    # The socket a path connects to, by one of its transports.
    @spec socket_for([{String.t(), module(), keyword()}], String.t()) :: map() | nil
    defp socket_for(sockets, path) do
      for {socket_path, handler, opts} <- sockets,
          {transport, default} <- [websocket: true, longpoll: false],
          Keyword.get(opts, transport, default) != false,
          Path.join(socket_path, Atom.to_string(transport)) == path,
          reduce: nil do
        nil -> %{path: socket_path, handler: handler, transport: transport}
        found -> found
      end
    end

    @spec request_path(String.t()) :: String.t()
    defp request_path(path) do
      [path | _query] = path |> String.trim() |> String.split(["?", "#"], parts: 2)
      if String.starts_with?(path, "/"), do: path, else: "/" <> path
    end

    @spec method(atom()) :: String.t()
    defp method(:*), do: "GET"
    defp method(verb), do: verb |> Atom.to_string() |> String.upcase()

    # What a plug's hover hint says: what it does, where it's from, and
    # whether its guard lets it run.
    @spec plug_hint(map(), String.t() | nil, String.t() | nil) :: String.t() | nil
    defp plug_hint(plug, about, source \\ nil) do
      text = [about, source] |> Enum.filter(& &1) |> Enum.join(": ")
      text = if text == "", do: nil, else: text

      case Map.get(plug, :runs) do
        :unknown -> "#{text || Pipeline.name(plug)}, when its guard passes"
        _runs -> text
      end
    end

    @spec module_vertex(map(), module()) :: Vertex.Module.t() | nil
    defp module_vertex(links, module) do
      with true <- Code.ensure_loaded?(module),
           [version] <- module.module_info(:attributes)[:vsn] do
        in_graph(links, %Vertex.Module{module: module, version: version})
      else
        _unknown -> nil
      end
    end

    # A module's name: within its application, when short names are on and
    # it's the endpoint's application, or else in full, so a library's
    # modules keep theirs (`Plug.Head`).
    @spec module_label(module(), atom()) :: String.t()
    defp module_label(module, nil), do: inspect(module)

    defp module_label(module, app) do
      if Application.get_application(module) == app,
        do: Vertex.Name.in_app(module),
        else: inspect(module)
    end

    # The endpoint's application's vertex, from the graph, which knows its
    # description and version.
    @spec app(module(), map()) :: Vertex.Application.t() | nil
    defp app(endpoint, links) do
      case Application.get_application(endpoint) do
        nil -> nil
        app -> in_graph(links, %Vertex.Application{app: app, description: nil, version: nil})
      end
    end

    @spec moduledoc(module()) :: String.t() | nil
    defp moduledoc(module) do
      case Code.fetch_docs(module) do
        {:docs_v1, _anno, _language, _format, %{"en" => doc}, _meta, _docs} -> doc
        _none -> nil
      end
    end

    @spec error_formats(module()) :: [String.t()]
    defp error_formats(endpoint) do
      case endpoint.config(:render_errors) do
        opts when is_list(opts) ->
          opts |> Keyword.get(:formats, []) |> Keyword.keys() |> Enum.map(&to_string/1)

        _none ->
          []
      end
    end

    @spec plural(non_neg_integer(), String.t()) :: String.t()
    defp plural(count, word), do: "#{count} #{plural_word(count, word)}"

    @spec plural_word(non_neg_integer(), String.t()) :: String.t()
    defp plural_word(1, word), do: word
    defp plural_word(_count, word), do: word <> "s"
  end
end
