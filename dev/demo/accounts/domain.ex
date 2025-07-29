defmodule Demo.Accounts.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource Demo.Accounts.User
  end
end
