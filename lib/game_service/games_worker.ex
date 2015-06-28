defmodule GameService.GamesWorker do
  @games_url "https://splatmap.firebaseio.com/games.json"

  def start_link(registry) do
    process = spawn fn -> loop(registry) end
    GameService.FirebaseStreamHelper.setup_stream(url: @games_url, stream_to: process)
    {:ok, process}
  end

  defp report(string) do
    IO.puts "[" <> inspect(__MODULE__) <> "] " <> string
  end

  defp loop(registry) do
    receive do
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        event = GameService.Event.new(chunk)

        report("Received event:" <> event.name)
        {:ok, games} = GameService.Registry.lookup(registry, "games")

        if event.data["data"] != nil do
          if event.data["path"] == "/" do
            report("Importing all game data")
            import_all_games(games, event.data["data"])
            report("Done")
          else
            key = String.lstrip(event.data["path"], ?/)
            GameService.Bucket.put(games, key, event.data["data"])
          end
        end
    end

    loop(registry)
  end

  defp import_all_games(games, data) do
    key = hd(Map.keys(data))

    GameService.Bucket.put(games, key, data[key])
    if Enum.count(Map.keys(data)) > 1 do
      import_all_games(games, Map.delete(data, key))
    end
  end
end
