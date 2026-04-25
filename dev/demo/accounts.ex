defmodule Demo.Accounts do
  @moduledoc """
  The Accounts domain.
  This handles user management and authentication.

  This is a second paragraph that should be ignored in the overview.

  And this is a third paragraph with more details.
  """

  use Ash.Domain

  resources do
    resource Demo.Accounts.Organization
    resource Demo.Accounts.User
    resource Demo.Accounts.Membership
    resource Demo.Accounts.ApiToken
    resource Demo.Accounts.AuditEvent
  end
end
