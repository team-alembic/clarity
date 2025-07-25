defmodule AshAtlas.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args),
    do: Supervisor.start_link([AshAtlas], strategy: :one_for_one, name: AshAtlas.Supervisor)
end
