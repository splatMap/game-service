defmodule GameService.PlayersWorker do
  @players_url "https://splatmap.firebaseio.com/players.json"
  @games_url "https://splatmap.firebaseio.com/games.json"

  def start_link(registry) do
    process = spawn fn -> loop(registry) end
    GameService.FirebaseStreamHelper.setup_stream(url: @players_url, stream_to: process)
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
        case event.name do
          _event_name ->
            {:ok, players} = GameService.Registry.lookup(registry, "players")

            if event.data["data"] != nil do
              if event.data["path"] == "/" do
                report("Importing all player data")
                import_all_players(players, event.data["data"])
              else
                key = String.lstrip(event.data["path"], ?/)
                player = event.data["data"]
                GameService.Bucket.put(players, key, player)

                initialize_player_if_needed(players, key, player)
              end
            end

            find_players_without_teams(players)

          "keep-alive" ->
        end

      _ ->
    end

    loop(registry)
  end

  defp import_all_players(players, all_players_map) do
    key = hd(Map.keys(all_players_map))
    player = all_players_map[key]
    initialize_player_if_needed(players, key, player)

    GameService.Bucket.put(players, key, player)
    if Enum.count(Map.keys(all_players_map)) > 1 do
      import_all_players(players, Map.delete(all_players_map, key))
    end
  end

  defp initialize_player_if_needed(players, key, player) do
    if not Map.has_key?(player, "state") do
      report("Initializing player with ID=" <> key)
      player = Map.put(player, "state", "waiting for game")
      player_json = Map.put(%{}, key, player)

      case HTTPoison.patch @players_url, JSON.encode!(player_json) do
        {:ok, response} ->
          %HTTPoison.Response{status_code: 200} = response
          GameService.Bucket.put(players, key, player)
          report("SUCCESS")

        {:error, response} ->
          report(inspect(response))
      end
    end
  end

  defp find_players_without_teams(players) do
    unassigned_player_ids = GameService.Bucket.keys(players) |>
      Enum.filter(&not Map.has_key?(GameService.Bucket.get(players, &1), "game_id"))

    if Enum.count(unassigned_player_ids) >= 4 do
      create_game(unassigned_player_ids, players)
    end
  end

  defp create_game(unassigned_player_ids, players) do
    report("Creating a new game...")

    [red_team, blue_team | _] = Enum.chunk(unassigned_player_ids, 2)
    red = {"Red Team", red_team}
    blue = {"Blue Team", blue_team}

    game_json = [red, blue] |>
      Enum.reduce(%{ "state" => "playing" }, fn ({team_name, player_ids}, acc) -> (
        Map.put(acc, team_name, %{ "player_ids" => player_ids, "score" => 0 })
      ) end)

    case HTTPoison.post @games_url, JSON.encode!(game_json) do
      {:ok, response} ->
        %HTTPoison.Response{status_code: 200} = response
        setup_players_with_game(players, [red, blue], JSON.decode!(response.body)["name"])

      {:error, response} ->
        report(inspect(response))
    end
  end

  defp setup_players_with_game(players, teams, game_id) do
    report("Successfully initialized game with ID=" <> game_id)

    players_json = teams |>
      Enum.map(fn ({team_name, player_ids}) -> (
        Enum.reduce(player_ids, %{}, fn (key, acc) -> (
          player = GameService.Bucket.get(players, key)
          player = Map.put(player, "state", "in game")
          player = Map.put(player, "game_id", game_id)
          player = Map.put(player, "team_name", team_name)

          Map.put(acc, key, player)
        ) end)
      ) end) |>
      Enum.reduce(%{}, &Map.merge(&1, &2))

      case HTTPoison.patch @players_url, JSON.encode!(players_json) do
        {:ok, response} ->
          %HTTPoison.Response{status_code: 200} = response
          Map.keys(players_json) |>
            Enum.each(&GameService.Bucket.put(players, &1, players_json[&1]))

          report("Successfully updated the players information")

        {:error, response} ->
          report(inspect(response))
      end
  end
end
