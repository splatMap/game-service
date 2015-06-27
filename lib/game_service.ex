defmodule GameService do
  use Application

  def start(_type, _args) do
    GameService.Supervisor.start_link
  end
end
