defmodule GameService.Registry do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def lookup(server, name) do
    GenServer.call(server, {:lookup, name})
  end

  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  def init(:ok) do
    {:ok, HashDict.new}
  end

  def handle_call({:lookup, name}, _from, names) do
    {:reply, HashDict.fetch(names, name), names}
  end

  def handle_cast({:create, name}, names) do
    if HashDict.has_key?(names, name) do
      {:noreply, names}
    else
      {:ok, bucket} = GameService.Bucket.start_link
      {:noreply, HashDict.put(names, name, bucket)}
    end
  end
end
