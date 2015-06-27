defmodule GameService.CloudsWorker do
  @clouds_url "https://splatmap.firebaseio.com/clouds.json"

  def start(registry) do
    GameService.FirebaseStreamHelper.setup_stream(url: @clouds_url, stream_to: self())
    loop(registry)
  end

  defp loop(registry) do
    receive do
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        event = GameService.Event.new(chunk)

        IO.puts inspect(__MODULE__) <> ":" <> event.name
        case event.name do
          "put" ->
            {:ok, players} = GameService.Registry.lookup(registry, "players")
            save_players_to_bucket(players, event.data["data"], Map.keys(event.data["data"]))
            # HTTPoison.put "https://splatmap.firebaseio.com/testing.json", JSON.encode!(reflection)

          _ ->
        end
    end

    loop(registry)
  end

  defp save_players_to_bucket(players, data, [key|tail]) do
    player_data = data[key]
    IO.puts inspect(__MODULE__) <> ":" <> "Updating information for player " <> player_data["id"]
    :ok = GameService.Bucket.put(players, key, player_data)
    save_players_to_bucket(players, data, tail)
  end

  defp save_players_to_bucket(_players, _data, []) do
  end
end
