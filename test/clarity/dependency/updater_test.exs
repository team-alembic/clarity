defmodule Clarity.Dependency.UpdaterTest do
  use ExUnit.Case, async: true

  alias Clarity.Dependency.Updater

  test "refuses to run outside the dev environment" do
    # In the test env this short-circuits before any mix task or app reload runs.
    assert Updater.update(:nonexistent_dep) == {:error, :not_dev}
  end
end
