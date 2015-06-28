defmodule GameService.ImageUploadsWorker do
  @clouds_url "https://splatmap.firebaseio.com/clouds.json"

  def start(registry) do
    process = spawn fn -> loop(registry) end
    GameService.FirebaseStreamHelper.setup_stream(url: @clouds_url, stream_to: process)
    {:ok, process}
  end

  defp report(string) do
    IO.puts "[" <> inspect(__MODULE__) <> "] " <> string
  end

  defp loop(registry) do
    receive do
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        event = GameService.Event.new(chunk)

        report("Received event: " <> event.name)
        {:ok, images} = GameService.Registry.lookup(registry, "images")

        if event.data["data"] != nil do
          if event.data["path"] == "/" do
            report("Importing all image data")
            import_all_images(images, event.data["data"])
            report("Done")
          else
            image = event.data["data"]

            if Map.has_key?(image, "gameID") do
              key = String.lstrip(event.data["path"], ?/)
              GameService.Bucket.put(images, key, image)
            end
          end

          recompute_all_points(registry)
        end
    end

    loop(registry)
  end

  defp import_all_images(images, data) do
    key = hd(Map.keys(data))
    image = data[key]

    if Map.has_key?(image, "gameID") do
      GameService.Bucket.put(images, key, image)
    end

    if Enum.count(Map.keys(data)) > 1 do
      import_all_images(images, Map.delete(data, key))
    end
  end

  defp recompute_all_points(registry) do
    {:ok, games} = GameService.Registry.lookup(registry, "games")
    {:ok, images} = GameService.Registry.lookup(registry, "images")

    games = GameService.Bucket.keys(games) |>
      Enum.reduce(%{}, fn (game_id, acc) -> (
        game = GameService.Bucket.get(games, game_id)

        GameService.Bucket.keys(images) |>
          Enum.each(fn (image_id) -> (
            image = GameService.Bucket.get(images, image_id)

            if image["gameID"] == game_id do
              team_name = image["playerTeam"]
              score = game[team_name]["score"]

              ^game = Map.put(game, team_name, Map.put(game[team_name], "score", score + 1))
            end
          ) end)

        report(game_id <> " Red=" <> game["Red"]["score"] <> ", Blue=" <> game["Blue"]["score"])
        Map.put(acc, game_id, game)
      ) end)

    case HTTPoison.patch @clouds_url, JSON.encode!(games) do
      {:ok, response} ->
        report("Done recalculation")

      {:error, response} ->
        report(inspect(response))
    end
  end
end
