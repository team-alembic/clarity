defmodule Atlas.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args),
    do: Supervisor.start_link([Atlas], strategy: :one_for_one, name: Atlas.Supervisor)
end
