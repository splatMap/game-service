defmodule GameService.Event do
  defstruct name: "unknown", data: nil

  def new(event_source_chunk) do
    event_name = hd(tl(Regex.run(~r/^event: (.+)/, event_source_chunk)))

    case hd(tl(Regex.run(~r/data: (.+)/, event_source_chunk))) do
      "null" ->
        %GameService.Event{ name: event_name, data: nil }

      json_string ->
        %GameService.Event{ name: event_name, data: JSON.decode!(json_string) }
    end

  end
end
