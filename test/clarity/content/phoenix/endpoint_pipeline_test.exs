with {:module, Phoenix.Endpoint} <- Code.ensure_loaded(Phoenix.Endpoint) do
  defmodule Clarity.Content.Phoenix.EndpointPipelineTest do
    use ExUnit.Case, async: true

    import Clarity.Test.OverviewHelper

    alias Clarity.Content.Phoenix.EndpointPipeline
    alias Clarity.Perspective.Lensmaker.Architect
    alias Clarity.Vertex.Phoenix.Endpoint
    alias Clarity.Vertex.Phoenix.Router
    alias Phoenix.LiveComponent.CID
    alias Phoenix.LiveView.Socket

    @endpoint_vertex %Endpoint{endpoint: DemoWeb.Endpoint}

    describe inspect(&EndpointPipeline.applies?/2) do
      test "applies to endpoints and routers" do
        assert EndpointPipeline.applies?(@endpoint_vertex, Architect.make_lens())
        assert EndpointPipeline.applies?(%Router{router: DemoWeb.Router}, Architect.make_lens())
        refute EndpointPipeline.applies?(%Clarity.Vertex.Root{}, Architect.make_lens())
      end
    end

    describe "render a router" do
      test "leads with its routes and pipelines, behind the endpoint that hands it requests" do
        html = render_overview(EndpointPipeline, %Router{router: DemoWeb.Router})

        assert text(html, ".ov-headline") ==
                 "Routes 29 paths through 3 pipelines behind DemoWeb.Endpoint"

        assert texts(html, ".ov-stat") == ["3 Pipelines", "29 Routes"]
        assert html |> LazyHTML.query("#request-pipeline") |> Enum.empty?()
      end

      test "shows its routes as code, never linking their text to names" do
        html = render_overview(EndpointPipeline, %Router{router: DemoWeb.Router})

        assert "POST /api/v1/tickets/:id/close DemoWeb.API.V1.TicketController :close after require_api_key" in texts(
                 html,
                 "#routes tbody tr"
               )

        assert html |> LazyHTML.query("#routes td.ov-routes-path a[data-phx-link]") |> Enum.empty?()
        assert ":close" in texts(html, "#routes td code.ov-muted")
      end

      test "traces a request through the endpoint's plugs too" do
        html = %Router{router: DemoWeb.Router} |> mount() |> request("GET", "/admin") |> render_html()

        assert texts(html, "#try-journey > li .ov-journey-stage") == ["Endpoint", "admin", "Handler"]
      end
    end

    describe "render" do
      test "leads with how many plugs the endpoint runs, and the router it hands requests to" do
        html = render_overview(EndpointPipeline, @endpoint_vertex)

        assert text(html, ".ov-headline") == "Runs 6 plugs then hands each request to DemoWeb.Router"
        assert text(html, ".ov-facts") =~ "Sockets /live"
        assert texts(html, ".ov-stat") == ["6 Plugs", "3 Pipelines", "29 Routes"]
      end

      test "lists each step in order, saying what the well-known plugs do, without their secrets" do
        html = render_overview(EndpointPipeline, @endpoint_vertex)
        steps = texts(html, "#request-pipeline .ov-steps > li")

        assert length(steps) == 8
        assert hd(steps) =~ "Sockets /live → Phoenix.LiveView.Socket"
        assert Enum.at(steps, 3) =~ "Plug.Parsers urlencoded multipart json Parses request bodies"
        assert Enum.at(steps, 6) =~ "Plug.Session cookie store key _live_view_key"
        assert List.last(steps) =~ "DemoWeb.Router 29 routes Matches the request to a route"
        refute text(html, "#request-pipeline") =~ "VEDsdfsffMnp5"
      end

      test "shows each router pipeline's plugs, and how many routes pass through it" do
        html = render_overview(EndpointPipeline, @endpoint_vertex)

        assert text(html, "#pipeline-api") ==
                 "api 15 routes accepts json fetch_query_params"

        assert texts(html, "#pipeline-browser .ov-chain > li") == [
                 "fetch_session",
                 "fetch_query_params",
                 "put_secure_browser_headers",
                 "accepts html"
               ]
      end

      test "groups routes by the pipelines they pass through, with the plugs their controllers run" do
        html = render_overview(EndpointPipeline, @endpoint_vertex)

        assert texts(html, "#routes .ov-route-group-head") == ["browser 12", "api 15", "admin 2"]

        rows = texts(html, "#routes-1 tbody tr")
        assert "GET /api/v1/tickets/:id DemoWeb.API.V1.TicketController :show" in rows

        assert "POST /api/v1/tickets DemoWeb.API.V1.TicketController :create after require_api_key" in rows

        assert html |> texts("#routes-0 tbody tr") |> Enum.at(2) ==
                 "GET /app/inbox DemoWeb.InboxLive live"
      end

      test "names modules within their application with short names" do
        html = render_overview(EndpointPipeline, @endpoint_vertex, name_style: :short)

        assert text(html, ".ov-headline") == "Runs 6 plugs then hands each request to Router"
      end
    end

    describe "try a request" do
      test "starts with the first GET route, traced to its handler" do
        html = @endpoint_vertex |> mount() |> render_html()

        assert attribute(html, "#try-path", "value") == "/marketing/pricing"

        assert texts(html, "#try-journey > li .ov-journey-stage") == [
                 "Endpoint",
                 "browser",
                 "Handler"
               ]

        assert text(html, "#try-journey .ov-journey-end") =~ "DemoWeb.PageController :pricing"
      end

      test "traces a request through the pipelines and its controller's plugs, with its path params" do
        html = @endpoint_vertex |> mount() |> request("post", "api/v1/tickets/42/close?x=1") |> render_html()

        assert attribute(html, "#try-path", "value") == "/api/v1/tickets/42/close"

        assert texts(html, "#try-journey > li .ov-journey-stage") == [
                 "Endpoint",
                 "api",
                 "Controller",
                 "Handler"
               ]

        assert text(html, "#try-journey") =~ "accepts › fetch_query_params"
        assert text(html, "#try-journey") =~ "require_api_key"
        assert text(html, "#try-journey .ov-journey-end") =~ "TicketController :close id = 42"
      end

      test "shows the hooks a LiveView's live session mounts" do
        html = @endpoint_vertex |> mount() |> request("GET", "/reports") |> render_html()

        assert text(html, "#try-journey") =~ "On mount Clarity.Pages.Setup"
        assert text(html, "#try-journey .ov-journey-end") =~ "Clarity.ReportLive :index live"
      end

      test "says when no route matches" do
        html = @endpoint_vertex |> mount() |> request("DELETE", "/marketing/pricing") |> render_html()

        assert text(html, "#try-journey .ov-journey-end") =~
                 "404 No route matches, so DemoWeb.Router raises Phoenix.Router.NoRouteError"
      end

      test "says when a request connects to a socket, before any plug" do
        html = @endpoint_vertex |> mount() |> request("GET", "/live/websocket") |> render_html()

        assert text(html, "#try-journey") ==
                 "Socket /live websocket → Phoenix.LiveView.Socket before any plug runs"
      end
    end

    @spec mount(Clarity.Vertex.t()) :: Socket.t()
    defp mount(vertex) do
      {:ok, socket} =
        EndpointPipeline.update(
          %{id: "overview", vertex: vertex, lens: Architect.make_lens(), prefix: "/c"},
          %Socket{}
        )

      socket
    end

    @spec request(Socket.t(), String.t(), String.t()) :: Socket.t()
    defp request(socket, method, path) do
      {:noreply, socket} =
        EndpointPipeline.handle_event("try", %{"method" => method, "path" => path}, socket)

      socket
    end

    @spec render_html(Socket.t()) :: LazyHTML.t()
    defp render_html(socket) do
      socket.assigns
      |> Map.put(:myself, %CID{cid: 1})
      |> EndpointPipeline.render()
      |> Phoenix.LiveViewTest.rendered_to_string()
      |> LazyHTML.from_fragment()
    end

    @spec attribute(LazyHTML.t(), String.t(), String.t()) :: String.t() | nil
    defp attribute(html, selector, name) do
      html |> LazyHTML.query(selector) |> LazyHTML.attribute(name) |> List.first()
    end
  end
end
