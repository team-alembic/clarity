defmodule Clarity.Phoenix.PipelineTest do
  use ExUnit.Case, async: true

  alias Clarity.Phoenix.Pipeline
  alias Clarity.Test.RuntimePlugs
  alias DemoWeb.API.V1.TicketController

  doctest Pipeline

  describe inspect(&Pipeline.plugs/1) do
    test "reads an endpoint's plugs in the order it runs them, from its socket dispatch to its router" do
      assert {:ok, plugs} = Pipeline.plugs(DemoWeb.Endpoint)

      assert Enum.map(plugs, &Pipeline.name/1) == [
               "socket_dispatch",
               "Plug.RequestId",
               "Plug.Telemetry",
               "Plug.Parsers",
               "Plug.MethodOverride",
               "Plug.Head",
               "Plug.Session",
               "DemoWeb.Router"
             ]

      assert %{kind: :function, module: DemoWeb.Endpoint} = hd(plugs)
    end

    test "reads options as written when they're initialised at runtime" do
      assert {:ok, [head, parsers]} = Pipeline.plugs(RuntimePlugs)

      assert %{module: Plug.Head, init: :runtime, opts: []} = head

      assert %{init: :runtime, opts: [parsers: [:json], pass: ["*/*"], json_decoder: Jason]} =
               parsers

      assert Pipeline.options(parsers) == ["json"]
    end

    test "can't read a module that isn't a plug pipeline" do
      assert Pipeline.plugs(Enum) == :error
      assert Pipeline.plugs(:lists) == :error
    end
  end

  describe inspect(&Pipeline.controller/1) do
    test "reads a controller's own plugs, with their guards, and not those every controller runs" do
      assert {:ok, [plug]} = Pipeline.controller(TicketController)
      assert %{kind: :function, function: :require_api_key, guard: guard} = plug
      assert guard

      assert Pipeline.controller(DemoWeb.PageController) == {:ok, []}
      assert Pipeline.controller(DemoWeb.Router) == :error
    end
  end

  describe inspect(&Pipeline.runs?/2) do
    test "works out from its guard whether a controller's plug runs for an action" do
      {:ok, [plug]} = Pipeline.controller(TicketController)

      assert Pipeline.runs?(plug, :create)
      assert Pipeline.runs?(plug, :delete)
      refute Pipeline.runs?(plug, :show)
      assert Pipeline.runs?(%{plug | guard: nil}, :show)
    end

    test "can't tell when its guard needs more than the action" do
      plug = %{guard: quote(do: conn.method == "GET")}

      assert Pipeline.runs?(plug, :index) == :unknown
    end
  end

  describe inspect(&Pipeline.pipelines/1) do
    test "reads a router's pipelines, in order, with their plugs" do
      assert {:ok, pipelines} = Pipeline.pipelines(DemoWeb.Router)
      assert Enum.map(pipelines, &elem(&1, 0)) == [:browser, :api, :admin]

      {:api, api} = List.keyfind(pipelines, :api, 0)
      assert Enum.map(api, &Pipeline.name/1) == ["accepts", "fetch_query_params"]
      assert Enum.map(api, &Pipeline.options/1) == [["json"], []]
      assert [%{module: Phoenix.Controller}, %{module: Plug.Conn}] = api
    end
  end

  describe inspect(&Pipeline.options/1) do
    test "summarises well-known plugs' options, initialised or not, without their secrets" do
      {:ok, plugs} = Pipeline.plugs(DemoWeb.Endpoint)
      session = Enum.find(plugs, &(&1.kind == :module and &1.module == Plug.Session))
      parsers = Enum.find(plugs, &(&1.kind == :module and &1.module == Plug.Parsers))

      assert Pipeline.options(session) == ["cookie store", "key _live_view_key"]
      assert Pipeline.options(parsers) == ["urlencoded", "multipart", "json"]

      assert Pipeline.options(%{
               kind: :module,
               module: Plug.Session,
               init: :runtime,
               opts: [store: :cookie, key: "_app", signing_salt: "secret"]
             }) == ["cookie store", "key _app"]
    end

    test "shows a function plug's options only when they're a list of names" do
      assert Pipeline.options(%{kind: :function, opts: [:json, "html"]}) == ["json", "html"]
      assert Pipeline.options(%{kind: :function, opts: [password: "secret"]}) == []
      assert Pipeline.options(%{kind: :function, opts: %{"x-frame-options" => "DENY"}}) == []
    end
  end

  describe inspect(&Pipeline.about/1) do
    test "says what well-known plugs do, and others in their docs' first sentence" do
      assert Pipeline.about(%{kind: :function, module: Plug.Conn, function: :fetch_session}) ==
               "Loads the session"

      assert Pipeline.about(%{kind: :module, module: RuntimePlugs}) ==
               "A plug pipeline whose options are initialised at runtime"

      assert Pipeline.about(%{
               kind: :function,
               module: TicketController,
               function: :require_api_key
             }) == "Rejects a request without an API key, as changing a Ticket needs one"

      assert Pipeline.about(%{kind: :module, module: DemoWeb.Router}) == nil
    end
  end
end
