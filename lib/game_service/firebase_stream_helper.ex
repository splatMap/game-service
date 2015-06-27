defmodule GameService.FirebaseStreamHelper do
  def setup_stream([url: url, stream_to: listener]) do
    request_headers = %{ "Accept" => "text/event-stream" }
    response = HTTPoison.get! url, request_headers
    redirect_url = elem(List.keyfind(response.headers, "Location", 0), 1)

    HTTPoison.get! redirect_url, request_headers, stream_to: listener
  end
end
