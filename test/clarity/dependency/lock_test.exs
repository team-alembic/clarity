defmodule Clarity.Dependency.LockTest do
  # async: false — changes the global :lockfile config, and installs the
  # globally-named Clarity.Dependency.Registry and Clarity.Advisory.Source tables.
  use ExUnit.Case, async: false

  alias Clarity.Advisory.Source
  alias Clarity.Dependency.Lock
  alias Clarity.Dependency.Registry

  # The test lockfile is test/support/hex.lock.
  describe "hex_package/1" do
    test "is the package a Hex dependency is installed from" do
      assert Lock.hex_package(:jason) == "jason"
    end

    test "is the package's own name when it differs from the application's" do
      assert Lock.hex_package(:renamed) == "renamed_on_hex"
    end

    test "is nil for a git dependency" do
      assert Lock.hex_package(:git_dep) == nil
    end

    test "is nil for an application the lockfile doesn't list, such as the project's own" do
      assert Lock.hex_package(:clarity) == nil
      assert Lock.hex_package(:kernel) == nil
    end

    test "reads a lockfile Mix wrote, without evaluating it" do
      original = Application.fetch_env!(:clarity, :lockfile)
      Application.put_env(:clarity, :lockfile, Path.expand("../../../mix.lock", __DIR__))
      on_exit(fn -> Application.put_env(:clarity, :lockfile, original) end)

      assert Lock.hex_package(:ash) == "ash"
      assert Lock.hex_package(:clarity) == nil
    end

    @tag :tmp_dir
    test "takes a lockfile with anything but literals in it as unreadable", %{tmp_dir: dir} do
      path = Path.join(dir, "mix.lock")
      File.write!(path, ~s|%{"jason": {:hex, :jason, System.halt()}}|)

      original = Application.fetch_env!(:clarity, :lockfile)
      Application.put_env(:clarity, :lockfile, path)
      on_exit(fn -> Application.put_env(:clarity, :lockfile, original) end)

      # Unreadable, as without one: the package of its name.
      assert Lock.hex_package(:jason) == "jason"
      assert Lock.hex_package(:git_dep) == "git_dep"
    end

    test "without a lockfile, takes every application but the project's to be the package of its name" do
      original = Application.fetch_env!(:clarity, :lockfile)
      Application.put_env(:clarity, :lockfile, "/no/such/mix.lock")
      on_exit(fn -> Application.put_env(:clarity, :lockfile, original) end)

      assert Lock.hex_package(:jason) == "jason"
      assert Lock.hex_package(:clarity) == nil
    end
  end

  describe "an application named like an unrelated Hex package" do
    setup do
      :ets.new(Registry, [:named_table, :set, :public])
      :ets.new(Source, [:named_table, :set, :public])
      :ets.insert(Registry, {{:package, "clarity"}, %{latest: "4.0.0", retired: []}})

      :ets.insert(
        Source,
        {{:package, "clarity"}, [%Clarity.Advisory{id: "EEF-CVE-2026-1", package: "clarity", versions: ["0.6.0"]}]}
      )

      :ok
    end

    test "has neither that package's version status nor its advisories" do
      assert Registry.summary(:clarity) == nil
      assert Source.advisories_for(:clarity, "0.6.0") == []

      assert Registry.summary("clarity") == %{latest: "4.0.0", retired: []}
      assert [_advisory] = Source.advisories_for("clarity", "0.6.0")
    end
  end
end
