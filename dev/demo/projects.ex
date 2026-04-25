defmodule Demo.Projects do
  @moduledoc """
  The body of work: Projects, Sprints, Tickets, and the conversational
  artefacts (Comments, Attachments, TimeEntries) attached to them.
  """

  use Ash.Domain

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
