defmodule Clarity.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args),
    do: Supervisor.start_link([Clarity], strategy: :one_for_one, name: Clarity.Supervisor)
end
