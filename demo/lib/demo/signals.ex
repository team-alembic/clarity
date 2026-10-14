defmodule Demo.Signals do
  @moduledoc """
  Signals about the whole platform, not one domain. No action emits them and
  no resource listens to them yet.
  """

  use Ash.Signals

  signals do
    signal :maintenance_scheduled do
      description "A maintenance window was scheduled."
      argument :starts_at, :utc_datetime_usec, allow_nil?: false
      argument :ends_at, :utc_datetime_usec, allow_nil?: false
    end
  end
end
