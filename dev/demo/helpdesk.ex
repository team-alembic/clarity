defmodule Demo.Helpdesk do
  @moduledoc """
  Customer support surface. Reuses Organization and User from Accounts so
  the Application Diagram has cross-domain edges. Helpdesk Tickets can be
  linked to a Projects.Ticket to escalate a customer issue into engineering
  work.
  """

  use Ash.Domain

  resources do
    resource Demo.Helpdesk.CustomerContact
    resource Demo.Helpdesk.Ticket
    resource Demo.Helpdesk.Conversation
    resource Demo.Helpdesk.Message
    resource Demo.Helpdesk.SlaPolicy
  end
end
