defmodule GameService.Supervisor do
  use Supervisor

  @registry_name GameService.Registry

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    HTTPoison.start

    {:ok, registry} = GameService.Registry.start_link
    GameService.Registry.create(registry, "teams")
    GameService.Registry.create(registry, "players")

    children = [
      worker(GameService.CloudsWorker, [registry], function: :start),
      worker(GameService.FindTeamWorker, [registry])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
