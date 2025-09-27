defmodule Demo.Accounts.Domain do
  @moduledoc """
  The Accounts domain.
  """

  use Ash.Domain

  resources do
    resource Demo.Accounts.User
  end
end
