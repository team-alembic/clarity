defmodule Demo.Accounts.Calculations.DisplayName do
  @moduledoc """
  A User's name as others see it: their full name, marked when they're an
  admin. Computed by a module rather than an expression, from what it loads.
  """
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @impl Calculation
  def load(_query, _opts, _context), do: [:full_name, :admin]

  @impl Calculation
  def calculate(users, _opts, _context) do
    Enum.map(users, fn
      %{admin: true, full_name: name} -> name <> " (admin)"
      %{full_name: name} -> name
    end)
  end
end
