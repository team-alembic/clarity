defmodule Demo.Projects.Domain do
  @moduledoc """
  The body of work: Projects, Sprints, Tickets, and the conversational
  artefacts (Comments, Attachments, TimeEntries) attached to them.
  """

  use Ash.Domain

  domain do
    description """
    The body of work: Projects, Sprints, Tickets, and the artefacts
    attached to them — Labels, Comments, Attachments, TimeEntries.
    The richest set of relationships and lifecycle in the demo;
    Tickets in particular exercise state machines, calculations, and
    many-to-many joins.
    """
  end

  resources do
    resource Demo.Projects.Project
    resource Demo.Projects.Sprint
    resource Demo.Projects.Label
    resource Demo.Projects.Ticket
    resource Demo.Projects.TicketLabel
    resource Demo.Projects.Comment
    resource Demo.Projects.Attachment
    resource Demo.Projects.TimeEntry
  end
end
