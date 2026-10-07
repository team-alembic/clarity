defmodule Demo.Helpdesk do
  @moduledoc """
  Customer support surface. Reuses Organization and User from Accounts so
  the Application Diagram has cross-domain edges. Helpdesk Tickets can be
  linked to a Projects.Ticket to escalate a customer issue into engineering
  work.
  """

  use Ash.Domain

  domain do
    description """
    Customer support: a ticketing surface with conversational threads
    and per-organization SLA policies. Reuses `Organization` and `User`
    from Accounts so the Application Diagram has cross-domain edges,
    and a Helpdesk Ticket can escalate to a Projects Ticket when an
    issue becomes engineering work.
    """
  end

  resources do
    resource Demo.Helpdesk.CustomerContact
    resource Demo.Helpdesk.Ticket
    resource Demo.Helpdesk.Conversation
    resource Demo.Helpdesk.Message
    resource Demo.Helpdesk.SlaPolicy
  end
end
