defmodule GameService.FindTeamWorker do
  @find_team_queue_url "https://splatmap.firebaseio.com/finding_team_queue.json"

  def start_link(registry) do
    GameService.FirebaseStreamHelper.setup_stream(url: @find_team_queue_url, stream_to: self())
    loop(registry)
  end

  defp loop(registry) do
    receive do
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        event = GameService.Event.new(chunk)

        IO.puts inspect(__MODULE__) <> ":" <> event.name
        case event.name do
          "put" ->
            IO.puts inspect(event.data)

          _ ->
        end
    end

    loop(registry)
  end
end
