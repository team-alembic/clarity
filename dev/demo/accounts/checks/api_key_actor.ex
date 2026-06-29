defmodule Demo.Accounts.Checks.ApiKeyActor do
  @moduledoc """
  Mirrors `AshAuthentication.Checks.UsingApiKey`: true when the actor was
  authenticated with an API key, flagged via `__metadata__.using_api_key?`.
  """
  use Ash.Policy.SimpleCheck

  @impl Ash.Policy.Check
  def describe(_opts), do: "actor is using an API key"

  @impl Ash.Policy.SimpleCheck
  def match?(%{__metadata__: %{using_api_key?: true}}, _context, _opts), do: true
  def match?(_actor, _context, _opts), do: false
end
