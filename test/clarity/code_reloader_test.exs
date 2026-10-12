defmodule Clarity.CodeReloaderTest do
  use ExUnit.Case, async: false

  alias Clarity.CodeReloader
  alias Clarity.Tooltip.Hints

  setup do
    # Stand in for Clarity.Server so introspection requests arrive here as casts.
    Process.register(self(), Clarity.Server)

    %{reloader: start_supervised!(CodeReloader)}
  end

  test "introspects the modules Mix reports as compiled", %{reloader: reloader} do
    send(
      reloader,
      {:modules_compiled,
       %{
         app: :clarity,
         scm: Mix.SCM.Path,
         modules_diff: %{added: [Demo.Accounts], changed: [], removed: [], timestamp: 0},
         os_pid: System.pid()
       }}
    )

    assert_receive {:"$gen_cast",
                    {:introspect, {:incremental, :clarity, %{added: [Demo.Accounts], changed: [], removed: []}}}}
  end

  test "forgets the docs of recompiled modules, and every hint", %{reloader: reloader} do
    Code.ensure_loaded!(Demo.Accounts)
    Clarity.Docs.moduledoc(Demo.Accounts)
    assert [_kept] = :ets.lookup(Clarity.Docs, {Demo.Accounts, :moduledoc})
    :ets.insert(Hints, {"some:vertex", :stamp, %{title: "Some vertex"}})

    send(
      reloader,
      {:modules_compiled,
       %{
         app: :clarity,
         scm: Mix.SCM.Path,
         modules_diff: %{added: [], changed: [Demo.Accounts], removed: [], timestamp: 0},
         os_pid: System.pid()
       }}
    )

    assert_receive {:"$gen_cast", {:introspect, {:incremental, :clarity, _modules_diff}}}
    assert :ets.lookup(Clarity.Docs, {Demo.Accounts, :moduledoc}) == []
    assert :ets.lookup(Hints, "some:vertex") == []
  end

  test "ignores a compiled dependency, whose modules arrive as :modules_compiled", %{
    reloader: reloader
  } do
    send(
      reloader,
      {:dep_compiled, %{app: :ash_diagram, scm: Hex.SCM, manager: :mix, os_pid: System.pid()}}
    )

    _ = :sys.get_state(reloader)
    refute_received {:"$gen_cast", _request}
  end
end
