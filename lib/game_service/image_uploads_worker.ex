defmodule GameService.ImageUploadsWorker do
  @clouds_url "https://splatmap.firebaseio.com/clouds.json"

  def start(registry) do
    process = spawn fn -> loop(registry) end
    GameService.FirebaseStreamHelper.setup_stream(url: @clouds_url, stream_to: process)
    {:ok, process}
  end

  defp loop(registry) do
    receive do
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        event = GameService.Event.new(chunk)
        IO.puts inspect(__MODULE__) <> ":" <> event.name
    end

    loop(registry)
  end
end
