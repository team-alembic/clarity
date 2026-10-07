defmodule Clarity.Test.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn

      alias Clarity.Test.Helper

      @endpoint DemoWeb.Endpoint

      setup tags do
        # `@tag test_graph: opts` passes options to Helper.build_test_clarity/1.
        clarity_pid =
          tags
          |> Map.get(:test_graph, [])
          |> Helper.build_test_clarity()
          |> Helper.setup_test_clarity()

        # Set up the conn with clarity_pid in the session
        conn =
          Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{
            "clarity_pid" => clarity_pid
          })

        {:ok, conn: conn, clarity_pid: clarity_pid}
      end
    end
  end
end
